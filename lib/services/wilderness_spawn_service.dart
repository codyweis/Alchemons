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
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:drift/drift.dart';

/// Service that manages active wild creature spawns across all scenes.
/// Spawns are persisted to the database so they survive app restarts.
class WildernessSpawnService extends ChangeNotifier {
  static const Set<String> _coreSceneIds = {
    'valley',
    'sky',
    'volcano',
    'swamp',
  };

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

  // Stored scenes config for on-demand spawn generation
  Map<
    String,
    ({
      SceneDefinition scene,
      EncounterPool sceneWide,
      Map<String, EncounterPool> perSpawn,
    })
  >?
  _scenes;

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

  Future<bool> _isSceneEligible(String sceneId) async {
    if (_coreSceneIds.contains(sceneId)) return true;
    if (sceneId == 'arcane') {
      return (await _db.settingsDao.getSetting('arcane_portal_unlocked')) ==
          '1';
    }
    return false;
  }

  Future<Set<String>> _eligibleSceneIds(Iterable<String> sceneIds) async {
    final eligible = <String>{};
    for (final sceneId in sceneIds) {
      if (await _isSceneEligible(sceneId)) {
        eligible.add(sceneId);
      }
    }
    return eligible;
  }

  Future<bool> _purgeIneligibleSceneData(Set<String> eligibleSceneIds) async {
    var changed = false;

    final staleSpawnSceneIds = _activeSpawns.keys
        .where((sceneId) => !eligibleSceneIds.contains(sceneId))
        .toList();
    for (final sceneId in staleSpawnSceneIds) {
      changed = true;
      _activeSpawns.remove(sceneId);
      await (_db.delete(
        _db.activeSpawns,
      )..where((t) => t.sceneId.equals(sceneId))).go();
      debugPrint('🧹 Removed stale active spawns for scene $sceneId');
    }

    final staleScheduleSceneIds = _nextDueUtcMs.keys
        .where((sceneId) => !eligibleSceneIds.contains(sceneId))
        .toList();
    for (final sceneId in staleScheduleSceneIds) {
      changed = true;
      _nextDueUtcMs.remove(sceneId);
      await (_db.delete(
        _db.spawnSchedule,
      )..where((t) => t.sceneId.equals(sceneId))).go();
      debugPrint('🧹 Removed stale spawn schedule for scene $sceneId');
    }

    final activeSceneCount = _activeScenes.length;
    _activeScenes.removeWhere((sceneId) => !eligibleSceneIds.contains(sceneId));
    if (_activeScenes.length != activeSceneCount) {
      changed = true;
    }

    return changed;
  }

  Future<void> _refreshScheduledNotifications(
    Set<String> eligibleSceneIds,
  ) async {
    await _pushNotifications.cancelWildernessNotifications();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    for (final entry in _nextDueUtcMs.entries) {
      final sceneId = entry.key;
      final dueAt = entry.value;
      if (!eligibleSceneIds.contains(sceneId) || dueAt <= now) continue;
      if (hasAnySpawnsInScene(sceneId)) continue;
      await _pushNotifications.scheduleWildernessSpawnNotification(
        spawnTime: DateTime.fromMillisecondsSinceEpoch(
          dueAt,
          isUtc: true,
        ).toLocal(),
        biomeId: sceneId,
      );
    }
  }

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
    _scenes = scenes;
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
    final knownSceneIds = _nextDueUtcMs.keys.toList(growable: false);
    final eligibleSceneIds = await _eligibleSceneIds(knownSceneIds);
    final stale = knownSceneIds
        .where((sceneId) => !eligibleSceneIds.contains(sceneId))
        .toList();
    for (final sceneId in stale) {
      _nextDueUtcMs.remove(sceneId);
      await (_db.delete(
        _db.spawnSchedule,
      )..where((t) => t.sceneId.equals(sceneId))).go();
    }

    for (final sceneId in eligibleSceneIds) {
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
      // Preserve persisted wilderness spawns across app interruption.
      // We only clear the "currently active scene" marker.
      await _db.delete(_db.activeSceneEntry).go();
    }

    final eligibleSceneIds = await _eligibleSceneIds(scenes.keys);

    // 2) Load active spawns
    final stored = await _db.select(_db.activeSpawns).get();
    for (final s in stored) {
      if (!eligibleSceneIds.contains(s.sceneId)) {
        await (_db.delete(
          _db.activeSpawns,
        )..where((t) => t.id.equals(s.id))).go();
        continue;
      }
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
      if (!eligibleSceneIds.contains(row.sceneId)) {
        await (_db.delete(
          _db.spawnSchedule,
        )..where((t) => t.sceneId.equals(row.sceneId))).go();
        continue;
      }
      _nextDueUtcMs[row.sceneId] = row.dueAtUtcMs;
    }

    // 3b) Drop stale data left from removed/locked scenes (e.g. poison).
    await _purgeIneligibleSceneData(eligibleSceneIds);
    await _refreshScheduledNotifications(eligibleSceneIds);

    // 4) Ensure every known scene has either:
    //    - at least one active spawn, OR
    //    - a scheduled time in the future
    for (final entry in scenes.entries) {
      final sceneId = entry.key;
      if (!eligibleSceneIds.contains(sceneId)) continue;
      final hasSpawns = hasAnySpawnsInScene(sceneId);
      final due = _nextDueUtcMs[sceneId];

      // Only schedule a next time if the scene has no spawns and there is
      // currently no scheduled time. If there's an existing due time that
      // has already passed, leave it alone so `processDueScenes`
      // can immediately create the spawns instead of resetting the timer.
      if (!hasSpawns && due == null) {
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
  Future<void> _syncScheduledWildernessNotification(
    String sceneId, {
    required int dueAtUtcMs,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (hasAnySpawnsInScene(sceneId) || dueAtUtcMs <= now) {
      await _pushNotifications.cancelWildernessSpawnNotification(
        biomeId: sceneId,
      );
      return;
    }

    await _pushNotifications.scheduleWildernessSpawnNotification(
      spawnTime: DateTime.fromMillisecondsSinceEpoch(
        dueAtUtcMs,
        isUtc: true,
      ).toLocal(),
      biomeId: sceneId,
    );
  }

  Future<void> scheduleNextSpawnTime(
    String sceneId, {
    Duration? windowMin,
    Duration? windowMax,
    bool force = false,
  }) async {
    if (!await _isSceneEligible(sceneId)) {
      _nextDueUtcMs.remove(sceneId);
      await (_db.delete(
        _db.spawnSchedule,
      )..where((t) => t.sceneId.equals(sceneId))).go();
      return;
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    // If there's already a scheduled time in the future, don't overwrite it
    // unless the caller explicitly requests a force-reschedule.
    final existing = _nextDueUtcMs[sceneId];
    if (!force && existing != null && existing > now) {
      debugPrint(
        '⏱ Keeping existing spawn for $sceneId at ${DateTime.fromMillisecondsSinceEpoch(existing, isUtc: true)}',
      );
      await _syncScheduledWildernessNotification(sceneId, dueAtUtcMs: existing);
      return;
    }

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

    await _syncScheduledWildernessNotification(sceneId, dueAtUtcMs: dueAt);
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
    final eligibleSceneIds = await _eligibleSceneIds(scenes.keys);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final hadAnyActiveSpawnsBeforeTick = hasAnyActiveSpawns;
    var spawnedAnyScene = false;

    for (final entry in scenes.entries) {
      final sceneId = entry.key;
      if (!eligibleSceneIds.contains(sceneId)) continue;

      // Skip scenes that are currently being visited
      if (isSceneActive(sceneId)) {
        continue;
      }

      final due = _nextDueUtcMs[sceneId];

      // If this scene has no schedule yet (e.g. Arcane was just unlocked),
      // create one now.
      if (due == null && !hasAnySpawnsInScene(sceneId)) {
        await scheduleNextSpawnTime(sceneId);
        continue;
      }

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
          emitSummaryNotification: false,
        );

        // Schedule the next event time using the global window
        if (spawned) {
          spawnedAnyScene = true;
          await scheduleNextSpawnTime(sceneId);
        } else {
          debugPrint('⏱️ Skipping reschedule for $sceneId; no spawns created.');
        }
      }
    }

    if (spawnedAnyScene) {
      await _showActiveWildernessSummaryNotification(
        silentUpdate: hadAnyActiveSpawnsBeforeTick,
      );
    }
  }

  void markSceneActive(String sceneId) {
    _activeScenes.add(sceneId);
    debugPrint('🎯 Scene $sceneId marked ACTIVE - spawning disabled');
  }

  void markSceneInactive(String sceneId) {
    _activeScenes.remove(sceneId);
    debugPrint('🎯 Scene $sceneId marked INACTIVE');
  }

  /// Immediately generate spawns for [sceneId] if it has none.
  /// Called when the player enters a scene that is empty (e.g. first visit).
  /// Bypasses the active-scene guard because we *want* spawns right now.
  Future<void> ensureSpawnsForScene(String sceneId) async {
    if (!await _isSceneEligible(sceneId)) return;
    if (hasAnySpawnsInScene(sceneId)) return; // already populated

    final config = _scenes?[sceneId];
    if (config == null) {
      debugPrint('⚠️ ensureSpawnsForScene: no config for $sceneId');
      return;
    }

    debugPrint('🌀 ensureSpawnsForScene: force-spawning for empty $sceneId');

    // Temporarily remove "active" flag so _spawnBatchAtRandomFreePoints works
    final wasActive = _activeScenes.remove(sceneId);

    await _spawnBatchAtRandomFreePoints(
      sceneId,
      config.scene,
      config.sceneWide,
      config.perSpawn,
      emitSummaryNotification: false,
    );

    // Re-mark active if it was before
    if (wasActive) _activeScenes.add(sceneId);
  }

  Future<bool> _spawnBatchAtRandomFreePoints(
    String sceneId,
    SceneDefinition scene,
    EncounterPool sceneWide,
    Map<String, EncounterPool> perSpawn, {
    bool emitSummaryNotification = true,
  }) async {
    if (!await _isSceneEligible(sceneId)) {
      debugPrint('⚠️ Skipping spawn for $sceneId - scene is not eligible');
      return false;
    }

    final hadAnyActiveSpawnsBeforeSpawn = hasAnyActiveSpawns;

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

    // Prefer points that are safely inside the camera area (avoid edge spawns).
    final cameraSafePoints = freePoints
        .where((sp) => _isCameraSafePoint(sp, scene))
        .toList();
    final candidatePoints = cameraSafePoints.isNotEmpty
        ? cameraSafePoints
        : freePoints;

    // Roll how many to spawn: 1..freePoints.length
    // ensure no more than 4
    final spawnCount = 1 + _rng.nextInt(min(candidatePoints.length, 5));

    // Shuffle to sample distinct points without repetition
    candidatePoints.shuffle(_rng);

    // Enforce spacing so active encounters don't overlap each other.
    final selected = <SpawnPoint>[];
    for (final point in candidatePoints) {
      if (!_hasSafeDistanceFromAll(point, selected, scene)) {
        continue;
      }
      selected.add(point);
      if (selected.length >= spawnCount) break;
    }

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

    if (selected.isEmpty) {
      debugPrint('⚠️ No valid spawn points selected in $sceneId');
      return false;
    }

    // Scene now has active spawns; suppress stale "next spawn" scheduled push.
    await _pushNotifications.cancelWildernessSpawnNotification(
      biomeId: sceneId,
    );

    // After spawning, show consolidated notification of active wilderness state.
    // Callers can disable this to batch multiple spawn operations into one push.
    if (emitSummaryNotification && hasAnySpawnsInScene(sceneId)) {
      await _showActiveWildernessSummaryNotification(
        silentUpdate: hadAnyActiveSpawnsBeforeSpawn,
      );
    }

    notifyListeners();
    return true;
  }

  bool _isCameraSafePoint(SpawnPoint point, SceneDefinition scene) {
    // Keep points away from extreme edges where framing can feel cramped.
    const minX = 0.10;
    const maxX = 0.90;
    const minY = 0.10;
    final maxY = scene.allowVerticalPan ? 0.88 : 0.38;
    return point.normalizedPos.dx >= minX &&
        point.normalizedPos.dx <= maxX &&
        point.normalizedPos.dy >= minY &&
        point.normalizedPos.dy <= maxY;
  }

  bool _hasSafeDistanceFromAll(
    SpawnPoint point,
    List<SpawnPoint> others,
    SceneDefinition scene,
  ) {
    final px = point.normalizedPos.dx * scene.worldWidth;
    final py = point.normalizedPos.dy * scene.worldHeight;
    for (final other in others) {
      final ox = other.normalizedPos.dx * scene.worldWidth;
      final oy = other.normalizedPos.dy * scene.worldHeight;
      final dx = px - ox;
      final dy = py - oy;
      final dist = sqrt(dx * dx + dy * dy);

      final minDist = ((point.size.x + other.size.x) * 0.75) + 40.0;
      if (dist < minDist) return false;
    }
    return true;
  }

  // ------------------------------------------------------------
  // REMOVE / CLEAR
  // ------------------------------------------------------------
  Future<void> _showActiveWildernessSummaryNotification({
    bool silentUpdate = false,
  }) async {
    final eligibleSceneIds = await _eligibleSceneIds(_activeSpawns.keys);
    final totalSpawns = eligibleSceneIds.fold<int>(
      0,
      (sum, sceneId) => sum + (_activeSpawns[sceneId]?.length ?? 0),
    );
    final scenesWithSpawns = eligibleSceneIds.where((sceneId) {
      return (_activeSpawns[sceneId]?.isNotEmpty ?? false);
    }).length;

    if (totalSpawns <= 0 || scenesWithSpawns <= 0) {
      await _pushNotifications.cancelWildernessSummaryNotification();
      return;
    }

    await _pushNotifications.showWildernessSpawnNotification(
      spawnCount: totalSpawns,
      locationCount: scenesWithSpawns,
      silentUpdate: silentUpdate,
    );
  }

  Future<void> removeSpawn(String sceneId, String spawnPointId) async {
    final removed = _activeSpawns[sceneId]?.remove(spawnPointId);
    if (removed == null) return;

    final id = '${sceneId}_$spawnPointId';
    await (_db.delete(_db.activeSpawns)..where((t) => t.id.equals(id))).go();
    debugPrint('❌ Removed spawn: $sceneId/$spawnPointId');

    if (!hasAnySpawnsInScene(sceneId)) {
      // Cancel notification if no spawns anywhere
      if (!hasAnyActiveSpawns) {
        await _pushNotifications.cancelWildernessSummaryNotification();
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

    // Only schedule next spawn if scene is active in the current wilderness set.
    if (!isSceneActive(sceneId) && await _isSceneEligible(sceneId)) {
      await scheduleNextSpawnTime(sceneId);
    } else {
      _nextDueUtcMs.remove(sceneId);
      await (_db.delete(
        _db.spawnSchedule,
      )..where((t) => t.sceneId.equals(sceneId))).go();
    }
    if (!hasAnyActiveSpawns) {
      await _pushNotifications.cancelWildernessSummaryNotification();
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
