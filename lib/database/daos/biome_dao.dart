// lib/database/daos/biome_dao.dart
import 'package:alchemons/services/push_notification_service.dart';
import 'package:drift/drift.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/schema_tables.dart';
import 'package:alchemons/models/biome_farm_state.dart';
import 'package:alchemons/models/harvest_biome.dart';

part 'biome_dao.g.dart';

@DriftAccessor(tables: [BiomeFarms, BiomeJobs])
class BiomeDao extends DatabaseAccessor<AlchemonsDatabase>
    with _$BiomeDaoMixin {
  BiomeDao(super.db);

  // Create instance per DAO instance instead of global
  final PushNotificationService _pushNotifications = PushNotificationService();

  int _normalizeRatePerMinute(int ratePerMinute) {
    if (ratePerMinute < 1) return 1;
    if (ratePerMinute > 5000) return 5000;
    return ratePerMinute;
  }

  // =================== BIOME HARVEST ===================

  Stream<List<BiomeFarm>> watchBiomes() =>
      (select(biomeFarms)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();

  Future<BiomeFarm?> getBiomeByBiomeId(String biomeId) => (select(
    biomeFarms,
  )..where((t) => t.biomeId.equals(biomeId))).getSingleOrNull();

  Future<bool> unlockBiome({
    required String biomeId,
    Map<String, int> cost = const {},
    bool free = false,
  }) async {
    return transaction(() async {
      final farm = await getBiomeByBiomeId(biomeId);
      if (farm == null) return false;
      if (farm.unlocked) return true;

      // Only spend if not free and there *is* a cost
      if (!free && cost.isNotEmpty) {
        final ok = await db.currencyDao.spendResources(cost);
        if (!ok) return false;
      }

      await (update(biomeFarms)..where((t) => t.id.equals(farm.id))).write(
        const BiomeFarmsCompanion(unlocked: Value(true)),
      );
      return true;
    });
  }

  Future<void> setBiomeActiveElement(String biomeId, String elementId) async {
    final farm = await getBiomeByBiomeId(biomeId);
    if (farm == null) return;

    await (update(biomeFarms)..where((t) => t.id.equals(farm.id))).write(
      BiomeFarmsCompanion(activeElementId: Value(elementId)),
    );
  }

  Future<HarvestJob?> getActiveJobForBiome(int biomeId) async {
    final q = select(biomeJobs)..where((t) => t.biomeId.equals(biomeId));
    final list = await q.get();
    if (list.isEmpty) return null;

    final job = list.last;
    return HarvestJob(
      jobId: job.jobId,
      creatureInstanceId: job.creatureInstanceId,
      startUtcMs: job.startUtcMs,
      durationMs: job.durationMs,
      ratePerMinute: _normalizeRatePerMinute(job.ratePerMinute),
    );
  }

  Future<void> syncHarvestNotifications() async {
    final nextNotification = await _nextPendingHarvestNotification();
    if (nextNotification == null) {
      await _pushNotifications.cancelHarvestScheduledNotification();
      return;
    }

    await _pushNotifications.scheduleHarvestReadyNotification(
      readyTime: nextNotification.readyTime,
      biomeId: nextNotification.biomeId,
    );
  }

  Future<({String biomeId, DateTime readyTime})?>
  _nextPendingHarvestNotification() async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    ({String biomeId, int endUtcMs})? earliestPending;

    for (final biome in Biome.values) {
      final farm = await getBiomeByBiomeId(biome.id);
      if (farm == null || !farm.unlocked) continue;

      final job = await getActiveJobForBiome(farm.id);
      if (job == null) continue;

      final endUtcMs = job.startUtcMs + job.durationMs;
      if (endUtcMs <= nowMs) {
        return null;
      }

      if (earliestPending == null || endUtcMs < earliestPending.endUtcMs) {
        earliestPending = (biomeId: biome.id, endUtcMs: endUtcMs);
      }
    }

    if (earliestPending == null) return null;

    return (
      biomeId: earliestPending.biomeId,
      readyTime: DateTime.fromMillisecondsSinceEpoch(
        earliestPending.endUtcMs,
        isUtc: true,
      ).toLocal(),
    );
  }

  Future<bool> startBiomeJob({
    required String biomeId,
    required String jobId,
    required String creatureInstanceId,
    required Duration duration,
    required int ratePerMinute,
  }) async {
    final farm = await getBiomeByBiomeId(biomeId);
    if (farm == null || !farm.unlocked) return false;

    final active = await getActiveJobForBiome(farm.id);
    if (active != null) {
      // Cancel old notification if there was somehow an active job
      await _pushNotifications.cancelHarvestNotification(biomeId: biomeId);
      return false;
    }

    // Call CreatureDao to get instance and spend stamina
    final inst = await db.creatureDao.getInstance(creatureInstanceId);
    if (inst == null || inst.staminaBars <= 0) return false;

    await db.creatureDao.updateStamina(
      instanceId: inst.instanceId,
      staminaBars: inst.staminaBars - 1,
      staminaLastUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );

    final startTime = DateTime.now().toUtc();
    final startMs = startTime.millisecondsSinceEpoch;
    final normalizedRatePerMinute = _normalizeRatePerMinute(ratePerMinute);

    await into(biomeJobs).insert(
      BiomeJobsCompanion(
        jobId: Value(jobId),
        biomeId: Value(farm.id),
        creatureInstanceId: Value(creatureInstanceId),
        startUtcMs: Value(startMs),
        durationMs: Value(duration.inMilliseconds),
        ratePerMinute: Value(normalizedRatePerMinute),
      ),
    );

    await syncHarvestNotifications();

    return true;
  }

  Future<bool> nudgeBiomeJob(String biomeId, int deltaMs) async {
    final farm = await getBiomeByBiomeId(biomeId);
    if (farm == null) return false;

    final job = await getActiveJobForBiome(farm.id);
    if (job == null) return false;

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    var newStart = job.startUtcMs + deltaMs;

    final newEnd = newStart + job.durationMs;
    if (newEnd < nowMs) {
      newStart = nowMs - job.durationMs;
    }

    if (newStart == job.startUtcMs) return false;

    await (update(biomeJobs)..where((t) => t.jobId.equals(job.jobId))).write(
      BiomeJobsCompanion(startUtcMs: Value(newStart)),
    );

    await syncHarvestNotifications();

    return true;
  }

  Future<int> collectBiomeJob({required String biomeId}) async {
    final farm = await getBiomeByBiomeId(biomeId);
    if (farm == null) return 0;

    final job = await getActiveJobForBiome(farm.id);
    if (job == null || farm.activeElementId == null) return 0;

    final endMs = job.startUtcMs + job.durationMs;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (nowMs < endMs) return 0;

    final totalMinutes = Duration(milliseconds: job.durationMs).inMinutes;
    final payout = totalMinutes * job.ratePerMinute;

    // Get resource key from biome
    final biome = Biome.values.firstWhere((b) => b.id == biomeId);
    final resKey = biome.resourceKey;

    // Call CurrencyDao to add the resource
    await db.currencyDao.addResource(resKey, payout);
    await (delete(biomeJobs)..where((t) => t.jobId.equals(job.jobId))).go();

    await syncHarvestNotifications();

    return payout;
  }

  Future<void> cancelBiomeJob(String biomeId) async {
    final farm = await getBiomeByBiomeId(biomeId);
    if (farm == null) return;

    final job = await getActiveJobForBiome(farm.id);
    if (job == null) return;

    await (delete(biomeJobs)..where((t) => t.jobId.equals(job.jobId))).go();

    await syncHarvestNotifications();
  }
}
