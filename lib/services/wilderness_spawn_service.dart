// lib/services/wilderness_spawn_service.dart

import 'dart:math';
import 'package:alchemons/services/encounter_service.dart';
import 'package:flutter/foundation.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:drift/drift.dart';

/// Service that manages active wild creature spawns across all scenes.
/// Spawns are persisted to the database so they survive app restarts.
class WildernessSpawnService extends ChangeNotifier {
  final AlchemonsDatabase _db;
  final Random _rng = Random();

  // sceneId -> spawnPointId -> roll
  final Map<String, Map<String, EncounterRoll>> _activeSpawns = {};

  // in-memory cache of schedules (sceneId -> dueAt)
  final Map<String, int> _nextDueUtcMs = {};

  // ------------------------------------------------------------
  // GLOBAL CONFIG (for testing and customization)
  // ------------------------------------------------------------
  final Duration _defaultWindowMin; // 💡 NEW
  final Duration _defaultWindowMax;

  Duration? _overrideWindowMin; // 💡 NEW
  Duration? _overrideWindowMax;

  /// The current effective spawn window max for scheduling.
  Duration get windowMax => _overrideWindowMax ?? _defaultWindowMax;

  /// The current effective spawn window min for scheduling.
  Duration get windowMin => _overrideWindowMin ?? _defaultWindowMin; // 💡 NEW

  WildernessSpawnService(
    this._db, {
    Duration defaultWindowMin = const Duration(minutes: 1), // 💡 NEW DEFAULT
    Duration defaultWindowMax = const Duration(hours: 4),
  }) : _defaultWindowMin = defaultWindowMin, // 💡 NEW
       _defaultWindowMax = defaultWindowMax {
    assert(
      _defaultWindowMax >= _defaultWindowMin,
      'Default spawn window max must be >= min',
    );
  }

  /// Override the global spawn window (e.g., for tests).
  void setGlobalSpawnWindow(Duration min, Duration max) {
    // 💡 UPDATED
    assert(max >= min, 'Spawn window max must be >= min');
    _overrideWindowMin = min;
    _overrideWindowMax = max;
    notifyListeners();
  }

  /// Clear any override and revert to the default.
  void clearGlobalSpawnWindow() {
    _overrideWindowMin = null; // 💡 NEW
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
    required Map<String, ({SceneDefinition scene, EncounterPool pool})> scenes,
  }) async {
    // ... (rest of this function is fine)
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
    Duration? windowMin, // 💡 NEW
    Duration? windowMax,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    final maxMs = (windowMax ?? this.windowMax).inMilliseconds;
    final minMs = (windowMin ?? this.windowMin).inMilliseconds;

    // Ensure min is never > max
    final effectiveMin = min(minMs, maxMs);

    // Calculate the random *additional* time *on top of* the minimum.
    final range = max(0, maxMs - effectiveMin);

    // Add 1 to range so the upper bound (maxMs) is inclusive
    final extraMs = (range == 0) ? 0 : _rng.nextInt(range + 1);

    final dueAt = now + effectiveMin + extraMs; // 💡 UPDATED LOGIC

    // print readable time for debug
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
  }

  // ------------------------------------------------------------
  // PROCESS: turn due schedules into a single spawn
  // ------------------------------------------------------------
  Future<void> processDueScenes(
    Map<String, ({SceneDefinition scene, EncounterPool pool})> scenes,
  ) async {
    // ... (rest of the file is fine)
    // ... (rest of file)
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    for (final entry in scenes.entries) {
      final sceneId = entry.key;
      final due = _nextDueUtcMs[sceneId];

      // Only start a new spawn event when the scene is empty.
      if (due != null && due <= now && !hasAnySpawnsInScene(sceneId)) {
        final scene = entry.value.scene;
        final pool = entry.value.pool;

        // Spawn a random count across available points
        await _spawnBatchAtRandomFreePoints(sceneId, scene, pool);

        // Schedule the next event time using the global window
        await scheduleNextSpawnTime(sceneId);
      }
    }
  }

  Future<void> _spawnBatchAtRandomFreePoints(
    String sceneId,
    SceneDefinition scene,
    EncounterPool pool,
  ) async {
    final freePoints = scene.spawnPoints
        .where((sp) => sp.enabled && !hasSpawnAt(sceneId, sp.id))
        .toList();

    if (freePoints.isEmpty) {
      debugPrint('⚠️  No available spawn points in $sceneId for due spawn');
      return;
    }

    // Roll how many to spawn: 1..freePoints.length
    final spawnCount = 1 + _rng.nextInt(freePoints.length);

    // Shuffle to sample distinct points without repetition
    freePoints.shuffle(_rng);
    final selected = freePoints.take(spawnCount);

    for (final point in selected) {
      final encounter = _rollEncounter(pool, point.id);

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

    notifyListeners();
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
      await scheduleNextSpawnTime(sceneId);
    }

    notifyListeners();
  }

  Future<void> clearSceneSpawns(String sceneId) async {
    _activeSpawns.remove(sceneId);
    await (_db.delete(
      _db.activeSpawns,
    )..where((t) => t.sceneId.equals(sceneId))).go();

    debugPrint('🧹 Cleared spawns from $sceneId');

    await scheduleNextSpawnTime(sceneId);
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
      'scenes': sceneInfo,
    };
  }

  void printDebugInfo() {
    final info = getDebugInfo();
    debugPrint('🌲 SPAWN DEBUG INFO:');
    debugPrint('  Total spawns: ${info['total_spawns']}');
    debugPrint('  Scenes with spawns: ${info['scenes_with_spawns']}');

    final scenes = info['scenes'] as Map<String, dynamic>;
    for (final entry in scenes.entries) {
      final sceneInfo = entry.value as Map<String, dynamic>;
      debugPrint('  📍 ${entry.key}: ${sceneInfo['count']} spawn(s)');

      final spawns = sceneInfo['spawns'] as List;
      for (final spawn in spawns) {
        debugPrint(
          '     - ${spawn['point']}: ${spawn['species']} (${spawn['rarity']})',
        );
      }
    }
  }
}
