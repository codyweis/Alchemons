import 'dart:async';

import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/device_identity_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AccountSessionException implements Exception {
  final String message;

  const AccountSessionException(this.message);

  @override
  String toString() => message;
}

class AccountSessionState {
  final bool initialized;
  final bool activeOnThisDevice;
  final bool hasRemoteActiveDevice;
  final String? activeDeviceId;
  final String status;
  final String? pendingTransferId;
  final DateTime? updatedAt;

  const AccountSessionState({
    required this.initialized,
    required this.activeOnThisDevice,
    required this.hasRemoteActiveDevice,
    this.activeDeviceId,
    required this.status,
    this.pendingTransferId,
    this.updatedAt,
  });

  const AccountSessionState.idle()
    : initialized = false,
      activeOnThisDevice = false,
      hasRemoteActiveDevice = false,
      activeDeviceId = null,
      status = 'idle',
      pendingTransferId = null,
      updatedAt = null;

  const AccountSessionState.inactive({
    this.activeDeviceId,
    this.status = 'active',
    this.pendingTransferId,
    this.updatedAt,
  }) : initialized = true,
       activeOnThisDevice = false,
       hasRemoteActiveDevice = true;

  const AccountSessionState.active({
    required this.activeDeviceId,
    this.status = 'active',
    this.pendingTransferId,
    this.updatedAt,
  }) : initialized = true,
       activeOnThisDevice = true,
       hasRemoteActiveDevice = false;

  bool get transferPendingOnThisDevice =>
      activeOnThisDevice && status == 'transfer_pending';
}

class AccountSessionService extends ChangeNotifier {
  AccountSessionService(this._accountService, this._deviceIdentityService) {
    _accountListener = _handleAccountChanged;
    _accountService.addListener(_accountListener!);
    unawaited(_handleAccountChanged());
  }

  final AccountService _accountService;
  final DeviceIdentityService _deviceIdentityService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  VoidCallback? _accountListener;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _sessionSubscription;
  AccountSessionState _state = const AccountSessionState.idle();
  String? _deviceId;
  String? _currentUid;

  AccountSessionState get state => _state;
  String? get deviceId => _deviceId;

  Future<String> rotateCurrentDeviceId() async {
    _deviceId = await _deviceIdentityService.rotateDeviceId();
    notifyListeners();
    return _deviceId!;
  }

  Future<void> _handleAccountChanged() async {
    final user = _accountService.user;
    if (user == null) {
      await _sessionSubscription?.cancel();
      _sessionSubscription = null;
      _currentUid = null;
      _state = const AccountSessionState.idle();
      notifyListeners();
      return;
    }

    _currentUid = user.uid;
    _deviceId ??= await _deviceIdentityService.getDeviceId();
    await _bindSessionStream(user.uid);
  }

  Future<void> refresh() async {
    final uid = _currentUid;
    if (uid == null) {
      _state = const AccountSessionState.idle();
      notifyListeners();
      return;
    }

    try {
      final doc = await _doc(uid).get();
      _applySnapshot(doc);
    } on FirebaseException catch (error) {
      throw AccountSessionException(_friendlyFirestoreError(error));
    }
  }

  Future<void> claimCurrentDevice({bool force = false}) async {
    final user = _accountService.user;
    if (user == null) {
      throw const AccountSessionException('Sign in first.');
    }

    _deviceId ??= await _deviceIdentityService.getDeviceId();
    final uid = user.uid;

    try {
      await _firestore.runTransaction((transaction) async {
        final ref = _doc(uid);
        final snapshot = await transaction.get(ref);
        final existing = snapshot.data();
        final activeDeviceId = existing?['activeDeviceId'] as String?;

        if (!force &&
            activeDeviceId != null &&
            activeDeviceId.isNotEmpty &&
            activeDeviceId != _deviceId) {
          throw const AccountSessionException(
            'This account is already active on another device.',
          );
        }

        transaction.set(ref, _sessionDocData(
          activeDeviceId: _deviceId!,
          activeEmail: user.email,
          activeDisplayName: user.displayName,
          status: 'active',
        ));
      });
    } on FirebaseException catch (error) {
      throw AccountSessionException(_friendlyFirestoreError(error));
    }

    await refresh();
  }

  Future<void> _bindSessionStream(String uid) async {
    await _sessionSubscription?.cancel();
    _sessionSubscription = _doc(uid).snapshots().listen(
      _applySnapshot,
      onError: (Object error) {
        if (error is FirebaseException) {
          debugPrint(
            'AccountSessionService stream error: ${_friendlyFirestoreError(error)}',
          );
          return;
        }
        debugPrint('AccountSessionService stream error: $error');
      },
    );
    await refresh();
  }

  void _applySnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      _state = const AccountSessionState.inactive();
      notifyListeners();
      return;
    }

    final activeDeviceId = data['activeDeviceId'] as String?;
    final status = (data['status'] as String?) ?? 'active';
    final pendingTransferId = data['pendingTransferId'] as String?;
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
    if (activeDeviceId == _deviceId) {
      _state = AccountSessionState.active(
        activeDeviceId: activeDeviceId,
        status: status,
        pendingTransferId: pendingTransferId,
        updatedAt: updatedAt,
      );
    } else {
      _state = AccountSessionState.inactive(
        activeDeviceId: activeDeviceId,
        status: status,
        pendingTransferId: pendingTransferId,
        updatedAt: updatedAt,
      );
    }
    notifyListeners();
  }

  Map<String, Object?> _sessionDocData({
    required String activeDeviceId,
    required String? activeEmail,
    required String? activeDisplayName,
    required String status,
    String? pendingTransferId,
  }) {
    return <String, Object?>{
      'activeDeviceId': activeDeviceId,
      'activeEmail': activeEmail,
      'activeDisplayName': activeDisplayName,
      'status': status,
      'pendingTransferId': pendingTransferId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String _friendlyFirestoreError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Account session update was blocked by Firestore rules. Deploy the latest rules, then try again.';
      case 'unavailable':
        return 'Account session service is temporarily unavailable.';
      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        return 'Account session request failed (${error.code}).';
    }
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid) {
    return _firestore.collection('account_sessions').doc(uid);
  }

  @override
  void dispose() {
    final listener = _accountListener;
    if (listener != null) {
      _accountService.removeListener(listener);
    }
    unawaited(_sessionSubscription?.cancel());
    super.dispose();
  }
}
