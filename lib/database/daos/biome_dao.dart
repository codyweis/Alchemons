// lib/database/daos/biome_dao.dart
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

  // =================== BIOME HARVEST ===================

  Stream<List<BiomeFarm>> watchBiomes() =>
      (select(biomeFarms)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();

  Future<BiomeFarm?> getBiomeByBiomeId(String biomeId) => (select(
    biomeFarms,
  )..where((t) => t.biomeId.equals(biomeId))).getSingleOrNull();

  Future<bool> unlockBiome({
    required String biomeId,
    required Map<String, int> cost,
  }) async {
    final farm = await getBiomeByBiomeId(biomeId);
    if (farm == null) return false;
    if (farm.unlocked) return true;

    // Call CurrencyDao to spend resources
    final ok = await db.currencyDao.spendResources(cost);
    if (!ok) return false;

    await (update(biomeFarms)..where((t) => t.id.equals(farm.id))).write(
      const BiomeFarmsCompanion(unlocked: Value(true)),
    );
    return true;
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
      ratePerMinute: job.ratePerMinute,
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
    if (active != null) return false;

    // Call CreatureDao to get instance and spend stamina
    final inst = await db.creatureDao.getInstance(creatureInstanceId);
    if (inst == null || inst.staminaBars <= 0) return false;

    await db.creatureDao.updateStamina(
      instanceId: inst.instanceId,
      staminaBars: inst.staminaBars - 1,
      staminaLastUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );

    await into(biomeJobs).insert(
      BiomeJobsCompanion(
        jobId: Value(jobId),
        biomeId: Value(farm.id),
        creatureInstanceId: Value(creatureInstanceId),
        startUtcMs: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
        durationMs: Value(duration.inMilliseconds),
        ratePerMinute: Value(ratePerMinute),
      ),
    );
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

    return payout;
  }

  Future<void> cancelBiomeJob(String biomeId) async {
    final farm = await getBiomeByBiomeId(biomeId);
    if (farm == null) return;

    final job = await getActiveJobForBiome(farm.id);
    if (job == null) return;

    await (delete(biomeJobs)..where((t) => t.jobId.equals(job.jobId))).go();
  }
}
