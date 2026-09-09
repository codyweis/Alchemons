import 'dart:convert';
import 'dart:math';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/save_generation_service.dart';
import 'package:alchemons/services/save_transfer_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressResetService {
  ProgressResetService(
    this.db, {
    this.invoke = _invoke,
    this.currentUid = _currentUid,
    this.beforeLocalReset = _noOp,
    this.prepareFreshSave = _noOp,
  });
  final AlchemonsDatabase db;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  invoke;
  final String? Function() currentUid;
  final Future<void> Function() beforeLocalReset;
  final Future<void> Function() prepareFreshSave;
  static Future<void> _noOp() async {}
  static String? _currentUid() => FirebaseAuth.instance.currentUser?.uid;
  static Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> data,
  ) async =>
      (await FirebaseFunctions.instance
              .httpsCallable(name)
              .call<Map<String, dynamic>>(data))
          .data;
  static const pendingKey = 'account.reset_pending.v1';
  static const appliedKey = 'account.reset_applied';
  static const onboardingKey = 'account.reset_onboarding';
  static final requests = ValueNotifier<int>(0);

  static bool preservePreference(String key) =>
      key == pendingKey ||
      key == 'account.device_id.v1' ||
      key == 'iap.pending_redeems.v1' ||
      key.startsWith('audio.') ||
      key.startsWith('notif.') ||
      key.startsWith('visual.') ||
      key.startsWith('accessibility.');

  Future<Map<String, dynamic>> preview(String deviceId) async {
    final quote = await invoke('previewProgressReset', {'deviceId': deviceId});
    if (quote['generation'] != await SaveGenerationService.local(db)) {
      throw StateError(
        'Restore the latest account backup on this device before resetting.',
      );
    }
    return quote;
  }

  Future<void> request({
    String? uid,
    required String deviceId,
    Map<String, dynamic>? preview,
    bool signOut = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(pendingKey)) {
      throw StateError('A reset is already pending.');
    }
    final operationId = base64UrlEncode(
      List.generate(24, (_) => Random.secure().nextInt(256)),
    ).replaceAll('=', '');
    await prefs.setString(
      pendingKey,
      jsonEncode({
        'uid': uid,
        'deviceId': deviceId,
        'operationId': operationId,
        'generation': preview?['generation'] ?? 0,
        'goldAmount': preview?['goldAmount'] ?? 0,
        'signOut': signOut,
      }),
    );
    requests.value++;
  }

  Future<bool> resume() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(pendingKey);
    if (raw == null) return false;
    final request = jsonDecode(raw) as Map<String, dynamic>;
    final uid = request['uid'] as String?;
    Map<String, dynamic> result = request;
    if (uid != null) {
      if (currentUid() != uid) {
        throw StateError(
          'Sign back into the purchasing account to finish this reset.',
        );
      }
      try {
        result = await invoke('beginProgressReset', request);
      } on FirebaseFunctionsException catch (error) {
        // A definitive refusal happens before this operation changes the save.
        // An uncertain/network failure keeps the marker and retries the same ID.
        if (['failed-precondition', 'invalid-argument'].contains(error.code) &&
            await db.settingsDao.getSetting(appliedKey) !=
                request['operationId']) {
          await prefs.remove(pendingKey);
        }
        rethrow;
      }
    }
    await beforeLocalReset();
    await applyLocalReset(
      operationId: request['operationId'] as String,
      goldAmount: (result['goldAmount'] as num).toInt(),
      generation: (result['generation'] as num).toInt(),
      uid: uid,
    );
    await prepareFreshSave();
    if (uid != null) {
      final saveCode = await SaveTransferService(
        db,
      ).exportSaveCode(ownerAccountId: uid);
      await invoke('finishProgressReset', {...request, 'saveCode': saveCode});
    } else if (request['signOut'] == true) {
      await FirebaseAuth.instance.signOut();
    }
    await prefs.remove(pendingKey);
    return true;
  }

  /// The database marker is committed with the fresh wallet, so recovery can
  /// repeat preference cleanup without ever granting the gold twice.
  Future<void> applyLocalReset({
    required String operationId,
    required int goldAmount,
    required int generation,
    String? uid,
  }) async {
    if (goldAmount < 0 || generation < 0) {
      throw StateError('Invalid reset amount.');
    }
    await db.transaction(() async {
      if (await db.settingsDao.getSetting(appliedKey) == operationId) return;
      final preferences = <String, String>{};
      for (final key in [
        'theme_mode',
        'app_font',
        'audio.master_enabled',
        'audio.music_enabled',
        'audio.sounds_enabled',
      ]) {
        final value = await db.settingsDao.getSetting(key);
        if (value != null) preferences[key] = value;
      }
      await db.resetToNewGame();
      for (final entry in preferences.entries) {
        await db.settingsDao.setSetting(entry.key, entry.value);
      }
      await db.currencyDao.creditPurchasedGold(goldAmount);
      await db.settingsDao.setSetting(
        SaveGenerationService.settingKey,
        '$generation',
      );
      if (uid != null) {
        await db.settingsDao.setSetting(SaveGenerationService.ownerKey, uid);
      }
      await db.settingsDao.setSetting(appliedKey, operationId);
      await db.settingsDao.setSetting(onboardingKey, '1');
    });
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (!preservePreference(key)) await prefs.remove(key);
    }
  }
}
