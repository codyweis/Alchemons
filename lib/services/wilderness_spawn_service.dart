// lib/services/wilderness_spawn_service.dart

import 'dart:async' as async;
import 'dart:math';
import 'package:alchemons/models/encounters/pools/valley_pool.dart';
import 'package:alchemons/services/encounter_service.dart';
import 'package:alchemons/services/push_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:drift/drift.dart';

/// Service that manages active wild creature spawns across all scenes.
/// Spawns are persisted to the database so they survive app restarts.
class WildernessSpawnService extends ChangeNotifier {
  final PushNotificationService _pushNotifications = PushNotificationService();
  final AlchemonsDatabase _db;
  final Random _rng = Random();
  async.Timer? _tick;

  // sceneId -> spawnPointId -> roll
  final Map<String, Map<String, EncounterRoll>> _activeSpawns = {};

  // in-memory cache of schedules (sceneId -> dueAt)
  final Map<String, int> _nextDueUtcMs = {};

  // Track which scenes are currently being visited (should not auto-spawn)
  final Set<String> _activeScenes = {};

  int? getNextSpawnTime(String sceneId) {
    return _nextDueUtcMs[sceneId];
  }

  /// Get all scheduled spawn times
  Map<String, int> getAllScheduledTimes() {
    return Map.from(_nextDueUtcMs);
  }

  // ------------------------------------------------------------
  // SCENE ACTIVE STATE
  // ------------------------------------------------------------

  /// Check if a scene is currently being visited
  bool isSceneActive(String sceneId) => _activeScenes.contains(sceneId);

  // ------------------------------------------------------------
  // GLOBAL CONFIG (for testing and customization)
  // ------------------------------------------------------------
  final Duration _defaultWindowMin;
  final Duration _defaultWindowMax;

  Duration? _overrideWindowMin;
  Duration? _overrideWindowMax;

  /// The current effective spawn window max for scheduling.
  Duration get windowMax => _overrideWindowMax ?? _defaultWindowMax;

  /// The current effective spawn window min for scheduling.
  Duration get windowMin => _overrideWindowMin ?? _defaultWindowMin;

  WildernessSpawnService(
    this._db, {
    Duration defaultWindowMin = const Duration(minutes: 1),
    Duration defaultWindowMax = const Duration(hours: 4),
  }) : _defaultWindowMin = defaultWindowMin,
       _defaultWindowMax = defaultWindowMax {
    assert(
      _defaultWindowMax >= _defaultWindowMin,
      'Default spawn window max must be >= min',
    );
  }

  void startTick({
    Duration interval = const Duration(seconds: 10),
    // 💡 UPDATED SIGNATURE
    required Map<
      String,
      ({
        SceneDefinition scene,
        EncounterPool sceneWide,
        Map<String, EncounterPool> perSpawn,
      })
    >
    scenes,
  }) {
    _tick?.cancel();
    _tick = async.Timer.periodic(interval, (_) async {
      try {
        await processDueScenes(scenes);
      } catch (e, st) {
        debugPrint('processDueScenes error: $e\n$st');
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Override the global spawn window (e.g., for tests).
  void setGlobalSpawnWindow(Duration min, Duration max) {
    assert(max >= min, 'Spawn window max must be >= min');
    _overrideWindowMin = min;
    _overrideWindowMax = max;
    notifyListeners();
  }

  /// Clear any override and revert to the default.
  void clearGlobalSpawnWindow() {
    _overrideWindowMin = null;
    _overrideWindowMax = null;
    notifyListeners();
  }

  /// Re-schedule every known scene using the current global window.
  Future<void> rescheduleAllScenes() async {
    for (final sceneId in _nextDueUtcMs.keys) {
      await scheduleNextSpawnTime(sceneId);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------
  // INIT
  // ------------------------------------------------------------
  Future<void> initializeActiveSpawns({
    required Map<
      String,
      ({
        SceneDefinition scene,
        EncounterPool sceneWide,
        Map<String, EncounterPool> perSpawn,
      })
    >
    scenes,
  }) async {
    // 1) Clear interrupted scene
    final activeEntry = await _db
        .select(_db.activeSceneEntry)
        .getSingleOrNull();
    if (activeEntry != null) {
      await clearSceneSpawns(activeEntry.sceneId);
      await _db.delete(_db.activeSceneEntry).go();
    }

    // 2) Load active spawns
    final stored = await _db.select(_db.activeSpawns).get();
    for (final s in stored) {
      final rarity = EncounterRarity.values.firstWhere(
        (r) => r.name == s.rarity,
        orElse: () => EncounterRarity.common,
      );
      _activeSpawns.putIfAbsent(
        s.sceneId,
        () => {},
      )[s.spawnPointId] = EncounterRoll(
        speciesId: s.speciesId,
        rarity: rarity,
        spawnId: s.spawnPointId,
      );
    }

    // 3) Load schedules
    final scheduled = await _db.select(_db.spawnSchedule).get();
    for (final row in scheduled) {
      _nextDueUtcMs[row.sceneId] = row.dueAtUtcMs;
    }

    // 4) Ensure every known scene has either:
    //    - at least one active spawn, OR
    //    - a scheduled time in the future
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final entry in scenes.entries) {
      final sceneId = entry.key;
      final hasSpawns = hasAnySpawnsInScene(sceneId);
      final due = _nextDueUtcMs[sceneId];

      if (!hasSpawns && (due == null || due <= now)) {
        await scheduleNextSpawnTime(sceneId);
      }
    }

    // 5) Immediately process any scenes whose due time has already passed
    await processDueScenes(scenes);

    notifyListeners();
  }

  // ------------------------------------------------------------
  // SCHEDULING (time only)
  // ------------------------------------------------------------
  Future<void> scheduleNextSpawnTime(
    String sceneId, {
    Duration? windowMin,
    Duration? windowMax,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    final maxMs = (windowMax ?? this.windowMax).inMilliseconds;
    final minMs = (windowMin ?? this.windowMin).inMilliseconds;

    final effectiveMin = min(minMs, maxMs);
    final range = max(0, maxMs - effectiveMin);
    final extraMs = (range == 0) ? 0 : _rng.nextInt(range + 1);

    final dueAt = now + effectiveMin + extraMs;

    final dueDate = DateTime.fromMillisecondsSinceEpoch(dueAt, isUtc: true);
    debugPrint(
      '⏱ Scheduled next spawn for scene $sceneId at $dueDate '
      '(in ${(dueAt - now) ~/ 60000} minutes)',
    );

    _nextDueUtcMs[sceneId] = dueAt;
    await _db
        .into(_db.spawnSchedule)
        .insertOnConflictUpdate(
          SpawnScheduleCompanion.insert(sceneId: sceneId, dueAtUtcMs: dueAt),
        );

    // NEW: Schedule push notification
    await _pushNotifications.scheduleWildernessSpawnNotification(
      spawnTime: dueDate.toLocal(),
      biomeId: sceneId,
    );
  }

  // ------------------------------------------------------------
  // PROCESS: turn due schedules into a single spawn
  // ------------------------------------------------------------
  Future<void> processDueScenes(
    Map<
      String,
      ({
        SceneDefinition scene,
        EncounterPool sceneWide,
        Map<String, EncounterPool> perSpawn,
      })
    >
    scenes,
  ) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    for (final entry in scenes.entries) {
      final sceneId = entry.key;

      // Skip scenes that are currently being visited
      if (isSceneActive(sceneId)) {
        continue;
      }

      final due = _nextDueUtcMs[sceneId];

      // Only start a new spawn event when the scene is empty.
      if (due != null && due <= now && !hasAnySpawnsInScene(sceneId)) {
        final scene = entry.value.scene;
        final sceneWide = entry.value.sceneWide;
        final perSpawn = entry.value.perSpawn;

        final spawned = await _spawnBatchAtRandomFreePoints(
          sceneId,
          scene,
          sceneWide,
          perSpawn,
        );

        // Schedule the next event time using the global window
        if (spawned) {
          await scheduleNextSpawnTime(sceneId);
        } else {
          debugPrint('⏱️ Skipping reschedule for $sceneId; no spawns created.');
        }
      }
    }
  }

  Future<bool> _spawnBatchAtRandomFreePoints(
    String sceneId,
    SceneDefinition scene,
    EncounterPool sceneWide,
    Map<String, EncounterPool> perSpawn,
  ) async {
    // Double-check: don't spawn if scene is active
    if (isSceneActive(sceneId)) {
      debugPrint('⚠️ Skipping spawn for $sceneId - scene is currently active');
      return false;
    }

    final freePoints = scene.spawnPoints
        .where((sp) => sp.enabled && !hasSpawnAt(sceneId, sp.id))
        .toList();

    if (freePoints.isEmpty) {
      debugPrint('⚠️  No available spawn points in $sceneId for due spawn');
      return false;
    }

    // Roll how many to spawn: 1..freePoints.length
    // ensure no more than 4
    final spawnCount = 1 + _rng.nextInt(min(freePoints.length, 5));

    // Shuffle to sample distinct points without repetition
    freePoints.shuffle(_rng);
    final selected = freePoints.take(spawnCount);

    for (final point in selected) {
      final finalPool = poolForSpawn(
        spawnId: point.id,
        sceneWide: sceneWide,
        perSpawn: perSpawn,
        unique: true,
      );

      final encounter = _rollEncounter(finalPool, point.id);

      _activeSpawns.putIfAbsent(sceneId, () => {})[point.id] = encounter;

      final id = '${sceneId}_${point.id}';
      await _db
          .into(_db.activeSpawns)
          .insert(
            ActiveSpawnsCompanion.insert(
              id: id,
              sceneId: sceneId,
              spawnPointId: point.id,
              speciesId: encounter.speciesId,
              rarity: encounter.rarity.name,
              spawnedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
            mode: InsertMode.insertOrReplace,
          );

      debugPrint('✨ Spawned ${encounter.speciesId} at $sceneId/${point.id}');
    }

    // After spawning, show notification if this is the first spawn
    if (!hasAnySpawnsInScene(sceneId)) {
      final totalSpawns = _activeSpawns.values.fold<int>(
        0,
        (sum, spawns) => sum + spawns.length,
      );
      final scenesWithSpawns = _activeSpawns.keys.length;

      await _pushNotifications.showWildernessSpawnNotification(
        spawnCount: totalSpawns,
        locationCount: scenesWithSpawns,
      );
    }

    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------
  // REMOVE / CLEAR
  // ------------------------------------------------------------
  Future<void> removeSpawn(String sceneId, String spawnPointId) async {
    final removed = _activeSpawns[sceneId]?.remove(spawnPointId);
    if (removed == null) return;

    final id = '${sceneId}_$spawnPointId';
    await (_db.delete(_db.activeSpawns)..where((t) => t.id.equals(id))).go();
    debugPrint('❌ Removed spawn: $sceneId/$spawnPointId');

    if (!hasAnySpawnsInScene(sceneId)) {
      // Cancel notification if no spawns anywhere
      if (!hasAnyActiveSpawns) {
        await _pushNotifications.cancelWildernessNotifications();
      }
    }

    notifyListeners();
  }

  Future<void> clearSceneSpawns(String sceneId) async {
    _activeSpawns.remove(sceneId);
    await (_db.delete(
      _db.activeSpawns,
    )..where((t) => t.sceneId.equals(sceneId))).go();

    debugPrint('🧹 Cleared spawns from $sceneId');

    // Only schedule next spawn if scene is NOT currently active
    if (!isSceneActive(sceneId)) {
      await scheduleNextSpawnTime(sceneId);
    }
    notifyListeners();
  }

  /// Check if a specific spawn point has an active spawn
  bool hasSpawnAt(String sceneId, String spawnPointId) {
    return _activeSpawns[sceneId]?.containsKey(spawnPointId) ?? false;
  }

  /// Check if a scene has any active spawns
  bool hasAnySpawnsInScene(String sceneId) {
    final spawns = _activeSpawns[sceneId];
    return spawns != null && spawns.isNotEmpty;
  }

  /// Get the encounter at a specific spawn point (if any)
  EncounterRoll? getSpawnAt(String sceneId, String spawnPointId) {
    return _activeSpawns[sceneId]?[spawnPointId];
  }

  /// Check if ANY scene has active spawns
  bool get hasAnyActiveSpawns {
    return _activeSpawns.values.any((spawns) => spawns.isNotEmpty);
  }

  /// Get count of active spawns in a scene
  int getSceneSpawnCount(String sceneId) {
    return _activeSpawns[sceneId]?.length ?? 0;
  }

  /// Get all spawn points that have active spawns in a scene
  List<String> getActiveSpawnPoints(String sceneId) {
    return _activeSpawns[sceneId]?.keys.toList() ?? [];
  }

  /// Force a specific encounter at a spawn point
  void forceSpawnAt(
    String sceneId,
    String spawnPointId,
    EncounterRoll encounter,
  ) {
    _activeSpawns.putIfAbsent(sceneId, () => {})[spawnPointId] = encounter;
    notifyListeners();
  }

  // ============================================================
  // ENCOUNTER ROLLING
  // ============================================================
  EncounterRoll _rollEncounter(EncounterPool pool, String spawnId) {
    final rarityRoll = _rng.nextDouble();
    final weights = pool.rarityWeights;

    EncounterRarity rarity;
    if (rarityRoll < weights.legendary) {
      rarity = EncounterRarity.legendary;
    } else if (rarityRoll < weights.rare) {
      rarity = EncounterRarity.rare;
    } else if (rarityRoll < weights.uncommon) {
      rarity = EncounterRarity.uncommon;
    } else {
      rarity = EncounterRarity.common;
    }

    final speciesList = pool.speciesByRarity[rarity] ?? [];
    final speciesId = speciesList.isEmpty
        ? 'fallback_creature'
        : speciesList[_rng.nextInt(speciesList.length)];

    return EncounterRoll(
      speciesId: speciesId,
      rarity: rarity,
      spawnId: spawnId,
    );
  }

  // ============================================================
  // DEBUG
  // ============================================================
  Map<String, dynamic> getDebugInfo() {
    final sceneInfo = <String, dynamic>{};

    for (final entry in _activeSpawns.entries) {
      sceneInfo[entry.key] = {
        'count': entry.value.length,
        'active': isSceneActive(entry.key),
        'spawns': entry.value.entries.map((spawn) {
          return {
            'point': spawn.key,
            'species': spawn.value.speciesId,
            'rarity': spawn.value.rarity.name,
          };
        }).toList(),
      };
    }

    return {
      'total_spawns': _activeSpawns.values.fold<int>(
        0,
        (sum, spawns) => sum + spawns.length,
      ),
      'scenes_with_spawns': _activeSpawns.keys.length,
      'active_scenes': _activeScenes.toList(),
      'scenes': sceneInfo,
    };
  }

  void printDebugInfo() {
    final info = getDebugInfo();
    debugPrint('🌲 SPAWN DEBUG INFO:');
    debugPrint('  Total spawns: ${info['total_spawns']}');
    debugPrint('  Scenes with spawns: ${info['scenes_with_spawns']}');
    debugPrint('  Active scenes: ${info['active_scenes']}');

    final scenes = info['scenes'] as Map<String, dynamic>;
    for (final entry in scenes.entries) {
      final sceneInfo = entry.value as Map<String, dynamic>;
      final activeMarker = sceneInfo['active'] == true ? ' [ACTIVE]' : '';
      debugPrint(
        '  📍 ${entry.key}: ${sceneInfo['count']} spawn(s)$activeMarker',
      );

      final spawns = sceneInfo['spawns'] as List;
      for (final spawn in spawns) {
        debugPrint(
          '     - ${spawn['point']}: ${spawn['species']} (${spawn['rarity']})',
        );
      }
    }
  }
}
