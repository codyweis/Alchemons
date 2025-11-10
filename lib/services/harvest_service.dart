// lib/services/harvest_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/models/biome_farm_state.dart';
import 'package:alchemons/database/alchemons_db.dart' as db;

class HarvestService extends ChangeNotifier {
  final db.AlchemonsDatabase _adb;
  StreamSubscription? _biomeSub;

  final Map<Biome, BiomeFarmState> _biomes = {
    for (final b in Biome.values)
      b: BiomeFarmState(biome: b, unlocked: false, level: 1),
  };

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

  Future<bool> nudge(
    Biome biome, {
    Duration by = const Duration(seconds: 5),
  }) async {
    final ok = await _adb.biomeDao.nudgeBiomeJob(biome.id, -by.inMilliseconds);
    if (ok) {
      await _refreshOne(biome);
    }
    return ok;
  }

  /// Collect completed job
  Future<int> collect(Biome biome) async {
    final payout = await _adb.biomeDao.collectBiomeJob(biomeId: biome.id);
    if (payout > 0) await _refreshOne(biome);
    return payout;
  }

  /// Cancel current job
  Future<void> cancel(Biome biome) async {
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
    print(
      'HarvestService: refreshing ${biome.id}, hasActive=${job != null}',
    ); // DEBUG
    notifyListeners();
  }

  Biome? _biomeFromId(String id) {
    try {
      return Biome.values.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}
