// lib/services/harvest_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/models/biome_farm_state.dart';
import 'package:alchemons/database/alchemons_db.dart' as db;

class HarvestService extends ChangeNotifier {
  final db.AlchemonsDatabase _adb;
  StreamSubscription? _biomeSub;
  static const Duration tapBoostStep = Duration(seconds: 5);
  static const Duration tapBoostThrottle = Duration(milliseconds: 250);
  static const Duration _nudgeDebounce = Duration(milliseconds: 400);

  final Map<Biome, BiomeFarmState> _biomes = {
    for (final b in Biome.values)
      b: BiomeFarmState(biome: b, unlocked: false, level: 1),
  };
  final Map<Biome, Timer> _pendingNudgeTimers = {};
  final Map<Biome, int> _pendingNudgeMs = {};
  final Map<Biome, List<Completer<bool>>> _pendingNudgeCompleters = {};
  final Map<Biome, Future<bool>> _inFlightNudgeFlushes = {};

  HarvestService(this._adb) {
    // Watch biome changes
    _biomeSub = _adb.biomeDao.watchBiomes().listen(
      (rows) async => _syncFromDb(rows),
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _biomeSub?.cancel();
    for (final timer in _pendingNudgeTimers.values) {
      timer.cancel();
    }
    for (final completers in _pendingNudgeCompleters.values) {
      for (final completer in completers) {
        if (!completer.isCompleted) completer.complete(false);
      }
    }
    _pendingNudgeTimers.clear();
    _pendingNudgeMs.clear();
    _pendingNudgeCompleters.clear();
    _inFlightNudgeFlushes.clear();
    super.dispose();
  }

  // -------- Public API --------

  List<BiomeFarmState> get biomes =>
      Biome.values.map((b) => _biomes[b]!).toList();

  BiomeFarmState biome(Biome b) => _biomes[b]!;

  /// Unlock biome via DB
  Future<bool> unlock(Biome biome, {required Map<String, int> cost}) async {
    final ok = await _adb.biomeDao.unlockBiome(biomeId: biome.id, cost: cost);
    if (ok) await _refreshOne(biome);
    return ok;
  }

  /// Set which element is active for this biome
  Future<bool> setActiveElement(Biome biome, String elementId) async {
    await _adb.biomeDao.setBiomeActiveElement(biome.id, elementId);
    await _refreshOne(biome);
    return true;
  }

  /// Start harvest job
  Future<bool> startJob({
    required Biome biome,
    required String creatureInstanceId,
    required Duration duration,
    required int ratePerMinute,
  }) async {
    final farm = this.biome(biome);
    if (!farm.unlocked || farm.activeElementId == null) return false;

    final ok = await _adb.biomeDao.startBiomeJob(
      biomeId: biome.id,
      jobId: 'job_${DateTime.now().toUtc().millisecondsSinceEpoch}',
      creatureInstanceId: creatureInstanceId,
      duration: duration,
      ratePerMinute: ratePerMinute,
    );
    if (ok) await _refreshOne(biome);
    return ok;
  }

  Future<bool> nudge(Biome biome, {Duration by = tapBoostStep}) async {
    _applyOptimisticNudge(biome, -by.inMilliseconds);
    final completer = Completer<bool>();
    _pendingNudgeMs[biome] = (_pendingNudgeMs[biome] ?? 0) - by.inMilliseconds;
    _pendingNudgeCompleters.putIfAbsent(biome, () => []).add(completer);

    _pendingNudgeTimers[biome]?.cancel();
    _pendingNudgeTimers[biome] = Timer(
      _nudgeDebounce,
      () => _flushPendingNudge(biome),
    );

    return completer.future;
  }

  /// Collect completed job
  Future<int> collect(Biome biome) async {
    await _flushPendingNudge(biome);
    final payout = await _adb.biomeDao.collectBiomeJob(biomeId: biome.id);
    if (payout > 0) await _refreshOne(biome);
    return payout;
  }

  /// Cancel current job
  Future<void> cancel(Biome biome) async {
    await _flushPendingNudge(biome);
    await _adb.biomeDao.cancelBiomeJob(biome.id);
    await _refreshOne(biome);
  }

  // -------- Internal sync --------

  Future<void> _syncFromDb(List<db.BiomeFarm> rows) async {
    for (final r in rows) {
      final biome = _biomeFromId(r.biomeId);
      if (biome == null) continue;

      final job = await _adb.biomeDao.getActiveJobForBiome(r.id);

      _biomes[biome] = BiomeFarmState(
        biome: biome,
        unlocked: r.unlocked,
        level: r.level,
        activeElementId: r.activeElementId,
        activeJob: job,
      );
    }
    notifyListeners();
  }

  Future<void> _refreshOne(Biome biome) async {
    final farm = await _adb.biomeDao.getBiomeByBiomeId(biome.id);
    if (farm == null) return;
    final job = await _adb.biomeDao.getActiveJobForBiome(farm.id);

    _biomes[biome] = BiomeFarmState(
      biome: biome,
      unlocked: farm.unlocked,
      level: farm.level,
      activeElementId: farm.activeElementId,
      activeJob: job,
    );
    debugPrint(
      'HarvestService: refreshing ${biome.id}, hasActive=${job != null}',
    ); // DEBUG
    notifyListeners();
  }

  void _applyOptimisticNudge(Biome biome, int deltaMs) {
    final farm = _biomes[biome];
    final job = farm?.activeJob;
    if (farm == null || job == null) return;

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    var newStart = job.startUtcMs + deltaMs;
    final newEnd = newStart + job.durationMs;
    if (newEnd < nowMs) {
      newStart = nowMs - job.durationMs;
    }

    if (newStart == job.startUtcMs) return;

    _biomes[biome] = farm.copyWith(
      activeJob: job.copyWith(startUtcMs: newStart),
    );
    notifyListeners();
  }

  Future<bool> _flushPendingNudge(Biome biome) async {
    final inFlight = _inFlightNudgeFlushes[biome];
    if (inFlight != null) {
      return inFlight;
    }

    final flushFuture = _performPendingNudgeFlush(biome);
    _inFlightNudgeFlushes[biome] = flushFuture;

    try {
      return await flushFuture;
    } finally {
      if (identical(_inFlightNudgeFlushes[biome], flushFuture)) {
        _inFlightNudgeFlushes.remove(biome);
      }
    }
  }

  Future<bool> _performPendingNudgeFlush(Biome biome) async {
    final timer = _pendingNudgeTimers.remove(biome);
    timer?.cancel();

    final deltaMs = _pendingNudgeMs.remove(biome);
    final completers = _pendingNudgeCompleters.remove(biome) ?? [];

    if (deltaMs == null || deltaMs == 0) {
      for (final completer in completers) {
        if (!completer.isCompleted) completer.complete(false);
      }
      return false;
    }

    try {
      final ok = await _adb.biomeDao.nudgeBiomeJob(biome.id, deltaMs);
      if (ok) {
        await _refreshOne(biome);
      }
      for (final completer in completers) {
        if (!completer.isCompleted) completer.complete(ok);
      }
      return ok;
    } catch (error, stackTrace) {
      for (final completer in completers) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
      rethrow;
    }
  }

  Biome? _biomeFromId(String id) {
    try {
      return Biome.values.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}
