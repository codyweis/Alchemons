// lib/services/harvest_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alchemons/models/farm_element.dart';
import 'package:alchemons/database/alchemons_db.dart' as db;

class HarvestService extends ChangeNotifier {
  final db.AlchemonsDatabase _adb;
  StreamSubscription<List<db.HarvestFarm>>? _farmSub;

  final Map<FarmElement, HarvestFarmState> _farms = {
    for (final e in FarmElement.values) e: HarvestFarmState(element: e),
  };

  HarvestService(this._adb) {
    // Keep local cache in sync with DB
    _farmSub = _adb.watchFarms().listen(
      (rows) async => _syncFromDb(rows),
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _farmSub?.cancel();
    super.dispose();
  }

  // -------- Public API (same shape as before) --------

  List<HarvestFarmState> get farms =>
      FarmElement.values.map((e) => _farms[e]!).toList();

  HarvestFarmState farm(FarmElement e) => _farms[e]!;

  /// Unlock via DB, deducting resources there (all-or-nothing).
  Future<bool> unlock(
    FarmElement e, {
    required Map<String, int> cost, // e.g. {'res_embers':50, 'res_droplets':20}
  }) async {
    final ok = await _adb.unlockFarm(element: _elStr(e), cost: cost);
    if (ok) await _refreshOne(e);
    return ok;
  }

  /// Starts a harvest job in DB (also spends 1 stamina there).
  Future<bool> startJob({
    required FarmElement element,
    required String creatureInstanceId,
    required Duration duration,
    required int ratePerMinute,
  }) async {
    final ok = await _adb.startHarvest(
      element: _elStr(element),
      jobId: 'job_${DateTime.now().toUtc().millisecondsSinceEpoch}',
      creatureInstanceId: creatureInstanceId,
      duration: duration,
      ratePerMinute: ratePerMinute,
    );
    if (ok) await _refreshOne(element);
    return ok;
  }

  Future<bool> nudge(
    FarmElement element, {
    Duration by = const Duration(seconds: 1),
  }) async {
    final ok = await _adb.nudgeHarvest(
      element: _elStr(element),
      deltaMs: -by.inMilliseconds, // negative = speed up
    );
    if (ok) {
      await _refreshOne(element); // pull fresh job (keeps UI honest)
    }
    return ok;
  }

  /// Collects when ready; returns payout amount (0 if not ready).
  Future<int> collect(FarmElement element) async {
    final payout = await _adb.collectHarvest(element: _elStr(element));
    if (payout > 0) await _refreshOne(element);
    return payout;
  }

  /// Cancels current job (no payout).
  Future<void> cancel(FarmElement element) async {
    await _adb.cancelHarvest(element: _elStr(element));
    await _refreshOne(element);
  }

  // -------- Internal sync helpers --------

  Future<void> _syncFromDb(List<db.HarvestFarm> rows) async {
    // Update farm basics
    for (final r in rows) {
      final e = _elFromStr(r.element);
      final state = _farms[e]!;
      state.unlocked = r.unlocked;
      state.level = r.level;
    }

    // Fetch active jobs for each farm in parallel
    final futures = <Future<void>>[];
    for (final r in rows) {
      futures.add(() async {
        final e = _elFromStr(r.element);
        final j = await _adb.getActiveJobForFarm(r.id);
        _farms[e]!.active = j;
      }());
    }
    await Future.wait(futures);

    notifyListeners();
  }

  Future<void> _refreshOne(FarmElement e) async {
    final farm = await _adb.getFarmByElement(_elStr(e));
    if (farm == null) return;
    final j = await _adb.getActiveJobForFarm(farm.id);
    final state = _farms[e]!;
    state.unlocked = farm.unlocked;
    state.level = farm.level;
    state.active = j;
    notifyListeners();
  }

  // -------- Mapping helpers --------

  String _elStr(FarmElement e) {
    switch (e) {
      case FarmElement.fire:
        return 'fire';
      case FarmElement.water:
        return 'water';
      case FarmElement.air:
        return 'air';
      case FarmElement.earth:
        return 'earth';
    }
  }

  FarmElement _elFromStr(String s) {
    switch (s.toLowerCase()) {
      case 'fire':
        return FarmElement.fire;
      case 'water':
        return FarmElement.water;
      case 'air':
        return FarmElement.air;
      case 'earth':
        return FarmElement.earth;
      default:
        return FarmElement.fire; // sane default
    }
  }
}
