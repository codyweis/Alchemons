import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/account_cloud_save_service.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/account_session_service.dart';
import 'package:alchemons/services/save_transfer_service.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the account's cloud save current without a button. The game itself
/// is saved on the device the moment anything happens; this copy is for a
/// lost phone or a new one. It goes up when the game leaves the screen, and on
/// the next launch when that upload didn't make it. Only the account's active
/// device saves (the Firestore rules allow no other), and an unchanged game is
/// not sent again.
class CloudAutosaveService extends ChangeNotifier with WidgetsBindingObserver {
  CloudAutosaveService({
    required AlchemonsDatabase db,
    required AccountService account,
    required AccountSessionService session,
    required AccountCloudSaveService cloudSave,
  }) : _db = db,
       _account = account,
       _session = session,
       _cloudSave = cloudSave {
    WidgetsBinding.instance.addObserver(this);
    _session.addListener(_onSession);
    unawaited(_loadSavedAt());
    _onSession();
  }

  static const fingerprintKey = 'account.autosave_fingerprint.v1';
  static const savedAtKey = 'account.autosave_at.v1';

  /// Launch is busy; the catch-up save waits for the game to settle.
  static const _catchUpDelay = Duration(seconds: 20);

  final AlchemonsDatabase _db;
  final AccountService _account;
  final AccountSessionService _session;
  final AccountCloudSaveService _cloudSave;

  Future<bool>? _running;
  Timer? _catchUp;
  bool _wasActive = false;
  String? _lastUid;
  int _holds = 0;
  DateTime? _savedAt;
  String? _error;
  bool _disposed = false;

  /// Whether this device saves to the signed-in account.
  bool get enabled =>
      _account.isSignedIn && _session.state.activeOnThisDevice && _holds == 0;
  bool get saving => _running != null;
  DateTime? get savedAt => _savedAt;
  String? get error => _error;

  /// Runs [body] with autosave held, for a sign-in or restore that changes
  /// the game or the active device under it. An upload already going
  /// finishes first.
  Future<T> hold<T>(Future<T> Function() body) async {
    _holds++;
    try {
      await _running;
      return await body();
    } finally {
      _holds--;
      // Whatever the account looks like now is a fresh start for catch-up.
      _wasActive = false;
      _onSession();
    }
  }

  /// Uploads the game if it changed since the last upload, or even if not
  /// when [force]. True when the account's save is current afterwards.
  Future<bool> save({bool force = false}) {
    final running = _running;
    if (running != null) return running;
    if (!enabled) return Future.value(false);
    final next = _running = _save(force).whenComplete(() {
      _running = null;
      _notify();
    });
    _notify();
    return next;
  }

  Future<bool> _save(bool force) async {
    final uid = _account.user?.uid;
    final deviceId = _session.deviceId;
    if (uid == null || deviceId == null) return false;
    try {
      final export = await SaveTransferService(
        _db,
      ).exportSave(ownerAccountId: uid);
      final prefs = await SharedPreferences.getInstance();
      final fingerprint = '$uid:${export.fingerprint}';
      if (!force && prefs.getString(fingerprintKey) == fingerprint) {
        _error = null;
        return true;
      }
      // Signed out, or the device stopped being the active one, while it
      // was packing.
      if (_account.user?.uid != uid || !enabled) return false;
      await _cloudSave.uploadSave(
        uid: uid,
        sourceDeviceId: deviceId,
        saveCode: export.saveCode,
      );
      final savedAt = DateTime.now();
      await prefs.setString(fingerprintKey, fingerprint);
      await prefs.setString(savedAtKey, savedAt.toIso8601String());
      _savedAt = savedAt;
      _error = null;
      return true;
    } catch (error) {
      debugPrint('Autosave failed: $error');
      _error =
          error is AccountCloudSaveException || error is SaveTransferException
          ? error.toString()
          : 'Could not save to your account.';
      return false;
    }
  }

  void _onSession() {
    final uid = _account.user?.uid;
    if (_lastUid != null && uid != _lastUid) {
      // Another account, or none: the last save time isn't theirs.
      _savedAt = null;
      _error = null;
      unawaited(_forgetLastSave());
    }
    _lastUid = uid;
    final active = enabled;
    if (active && !_wasActive) _scheduleCatchUp();
    if (!active) _catchUp?.cancel();
    _wasActive = active;
    _notify();
  }

  void _scheduleCatchUp() {
    _catchUp?.cancel();
    _catchUp = Timer(_catchUpDelay, () => unawaited(save()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _catchUp?.cancel();
        unawaited(save());
      case AppLifecycleState.resumed when _error != null && enabled:
        // The last one didn't make it (no signal, or the app was suspended
        // mid-upload).
        _scheduleCatchUp();
      default:
        break;
    }
  }

  Future<void> _loadSavedAt() async {
    final prefs = await SharedPreferences.getInstance();
    _savedAt ??= DateTime.tryParse(prefs.getString(savedAtKey) ?? '');
    _notify();
  }

  Future<void> _forgetLastSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(fingerprintKey);
    await prefs.remove(savedAtKey);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _catchUp?.cancel();
    _session.removeListener(_onSession);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
