import 'dart:convert';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';

class ColdStorageService {
  ColdStorageService._();

  static const int slowdownFactor = 5;
  static const String introSeenSettingKey = 'cold_storage_intro_seen_v1';
  static const String capacitySettingKey = 'cold_storage_capacity';
  static const int baseCapacity = 5;
  static const List<int> upgradeCapSteps = [10, 15, 20];

  static const String _payloadKey = 'coldStorage';
  static const String _enteredAtUtcMsKey = 'enteredAtUtcMs';
  static const String _activeRemainingAtEntryMsKey = 'activeRemainingAtEntryMs';
  static const String _slowdownFactorKey = 'slowdownFactor';

  static int normalizeCapacity(int value) {
    return value.clamp(baseCapacity, upgradeCapSteps.last);
  }

  static Future<int> getCapacity(AlchemonsDatabase db) async {
    final raw = await db.settingsDao.getSetting(capacitySettingKey);
    final parsed = int.tryParse(raw ?? '');
    final capacity = normalizeCapacity(parsed ?? baseCapacity);

    if (raw == null || parsed == null || capacity != parsed) {
      await db.settingsDao.setSetting(capacitySettingKey, capacity.toString());
    }

    return capacity;
  }

  static Future<void> setCapacity(AlchemonsDatabase db, int capacity) async {
    final normalized = normalizeCapacity(capacity);
    await db.settingsDao.setSetting(capacitySettingKey, normalized.toString());
  }

  static Future<int> getStoredCount(AlchemonsDatabase db) async {
    final eggs = await db.select(db.eggs).get();
    return eggs.length;
  }

  static Future<(int used, int capacity)> getUsage(AlchemonsDatabase db) async {
    final used = await getStoredCount(db);
    final capacity = await getCapacity(db);
    return (used, capacity);
  }

  static Future<bool> hasCapacity(
    AlchemonsDatabase db, {
    int additional = 1,
  }) async {
    final (used, capacity) = await getUsage(db);
    return used + additional <= capacity;
  }

  static Future<String> buildFullMessage(AlchemonsDatabase db) async {
    final (used, capacity) = await getUsage(db);
    return 'Cold storage full ($used/$capacity). Free up space or buy a storage upgrade in Special Items.';
  }

  static Egg normalizeEggForDisplay(Egg egg, {DateTime? nowUtc}) {
    final normalizedPayloadJson = ensureColdStoragePayload(
      egg.payloadJson,
      activeRemaining: Duration(milliseconds: egg.remainingMs),
      enteredAtUtc: nowUtc ?? DateTime.now().toUtc(),
    );

    if (normalizedPayloadJson == egg.payloadJson) {
      return egg;
    }

    return Egg(
      eggId: egg.eggId,
      resultCreatureId: egg.resultCreatureId,
      rarity: egg.rarity,
      bonusVariantId: egg.bonusVariantId,
      remainingMs: egg.remainingMs,
      payloadJson: normalizedPayloadJson,
    );
  }

  static String? ensureColdStoragePayload(
    String? payloadJson, {
    required Duration activeRemaining,
    DateTime? enteredAtUtc,
  }) {
    final payload = _decodePayload(payloadJson);
    final coldStorage = payload[_payloadKey];
    if (coldStorage is Map) {
      final activeRemainingAtEntryMs = _asInt(
        coldStorage[_activeRemainingAtEntryMsKey],
      );
      final storedEnteredAtUtcMs = _asInt(coldStorage[_enteredAtUtcMsKey]);
      if (activeRemainingAtEntryMs != null && storedEnteredAtUtcMs != null) {
        return payloadJson ?? _encodePayload(payload);
      }
    }

    payload[_payloadKey] = {
      _enteredAtUtcMsKey:
          (enteredAtUtc ?? DateTime.now().toUtc()).millisecondsSinceEpoch,
      _activeRemainingAtEntryMsKey: math.max(0, activeRemaining.inMilliseconds),
      _slowdownFactorKey: slowdownFactor,
    };

    return _encodePayload(payload);
  }

  static String? clearColdStoragePayload(String? payloadJson) {
    final payload = _decodePayload(payloadJson);
    if (!payload.containsKey(_payloadKey)) {
      return payloadJson;
    }
    payload.remove(_payloadKey);
    return _encodePayload(payload);
  }

  static Duration activeRemainingFromEgg(Egg egg, {DateTime? nowUtc}) {
    final payload = _decodePayload(egg.payloadJson);
    return activeRemainingFromPayload(
      payload,
      fallbackActiveRemaining: Duration(milliseconds: egg.remainingMs),
      nowUtc: nowUtc,
    );
  }

  static Duration activeRemainingFromPayload(
    Map<String, dynamic> payload, {
    required Duration fallbackActiveRemaining,
    DateTime? nowUtc,
  }) {
    final coldStorage = payload[_payloadKey];
    if (coldStorage is! Map) {
      return _clampToZero(fallbackActiveRemaining);
    }

    final enteredAtUtcMs = _asInt(coldStorage[_enteredAtUtcMsKey]);
    final activeRemainingAtEntryMs = _asInt(
      coldStorage[_activeRemainingAtEntryMsKey],
    );
    final factor = _slowdownFactorFromColdStorage(coldStorage);

    if (enteredAtUtcMs == null || activeRemainingAtEntryMs == null) {
      return _clampToZero(fallbackActiveRemaining);
    }

    final elapsedMs = math.max(
      0,
      (nowUtc ?? DateTime.now().toUtc()).millisecondsSinceEpoch -
          enteredAtUtcMs,
    );
    final cultivatedActiveMs = elapsedMs ~/ factor;
    final remainingMs = math.max(
      0,
      activeRemainingAtEntryMs - cultivatedActiveMs,
    );

    return Duration(milliseconds: remainingMs);
  }

  static Duration coldStorageRemainingFromEgg(Egg egg, {DateTime? nowUtc}) {
    final payload = _decodePayload(egg.payloadJson);
    final factor = slowdownFactorFromPayload(payload);
    final activeRemaining = activeRemainingFromPayload(
      payload,
      fallbackActiveRemaining: Duration(milliseconds: egg.remainingMs),
      nowUtc: nowUtc,
    );
    return Duration(milliseconds: activeRemaining.inMilliseconds * factor);
  }

  static int? totalDisplayDurationMs(Egg egg) {
    final payload = _decodePayload(egg.payloadJson);
    final totalActiveMs = _extractTotalActiveDurationMs(payload);
    if (totalActiveMs == null) return null;
    return totalActiveMs * slowdownFactorFromPayload(payload);
  }

  static int slowdownFactorFromPayload(Map<String, dynamic> payload) {
    final coldStorage = payload[_payloadKey];
    if (coldStorage is! Map) return slowdownFactor;
    return _slowdownFactorFromColdStorage(coldStorage);
  }

  static bool isReady(Egg egg, {DateTime? nowUtc}) {
    return activeRemainingFromEgg(egg, nowUtc: nowUtc) <= Duration.zero;
  }

  static Map<String, dynamic> _decodePayload(String? payloadJson) {
    if (payloadJson == null || payloadJson.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  static String? _encodePayload(Map<String, dynamic> payload) {
    return jsonEncode(payload);
  }

  static int _slowdownFactorFromColdStorage(Map coldStorage) {
    final factor = _asInt(coldStorage[_slowdownFactorKey]) ?? slowdownFactor;
    return factor <= 0 ? slowdownFactor : factor;
  }

  static Duration _clampToZero(Duration value) {
    return value.isNegative ? Duration.zero : value;
  }

  static int? _extractTotalActiveDurationMs(Map<String, dynamic> payload) {
    final candidates = [
      payload['totalMs'],
      payload['durationMs'],
      payload['hatchDurationMs'],
      (payload['incubation'] is Map
          ? (payload['incubation'] as Map)['durationMs']
          : null),
    ];

    for (final candidate in candidates) {
      final value = _asInt(candidate);
      if (value != null && value > 0) return value;
    }

    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
