// lib/database/alchemons_db.dart
import 'dart:convert';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/models/biome_farm_state.dart';
import 'package:drift/drift.dart';

part 'alchemons_db.g.dart';

// =================== TABLES ===================

class PlayerCreatures extends Table {
  TextColumn get id => text()();
  BoolColumn get discovered => boolean().withDefault(const Constant(false))();
  TextColumn get natureId => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class IncubatorSlots extends Table {
  IntColumn get id => integer()();
  BoolColumn get unlocked => boolean().withDefault(const Constant(true))();
  TextColumn get eggId => text().nullable()();
  TextColumn get resultCreatureId => text().nullable()();
  TextColumn get bonusVariantId => text().nullable()();
  TextColumn get rarity => text().nullable()();
  IntColumn get hatchAtUtcMs => integer().nullable()();
  TextColumn get payloadJson => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Eggs extends Table {
  TextColumn get eggId => text()();
  TextColumn get resultCreatureId => text()();
  TextColumn get rarity => text()();
  TextColumn get bonusVariantId => text().nullable()();
  IntColumn get remainingMs => integer()();
  TextColumn get payloadJson => text().nullable()();
  @override
  Set<Column> get primaryKey => {eggId};
}

class BiomeFarms extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get biomeId => text()(); // 'volcanic', 'oceanic', etc
  BoolColumn get unlocked => boolean().withDefault(const Constant(false))();
  IntColumn get level => integer().withDefault(const Constant(1))();
  TextColumn get activeElementId => text().nullable()(); // T001, T002, etc
}

class BiomeJobs extends Table {
  TextColumn get jobId => text()();
  IntColumn get biomeId => integer()(); // FK -> BiomeFarms.id
  TextColumn get creatureInstanceId => text()();
  IntColumn get startUtcMs => integer()();
  IntColumn get durationMs => integer()();
  IntColumn get ratePerMinute => integer()();
  @override
  Set<Column> get primaryKey => {jobId};
}

class CompetitionProgress extends Table {
  TextColumn get biome => text()(); // 'oceanic', 'volcanic', etc.
  IntColumn get highestLevelCompleted =>
      integer().withDefault(const Constant(0))();
  IntColumn get totalWins => integer().withDefault(const Constant(0))();
  IntColumn get totalLosses => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastCompletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {biome};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class CreatureInstances extends Table {
  TextColumn get instanceId => text()();
  TextColumn get baseId => text()();
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get xp => integer().withDefault(const Constant(0))();
  BoolColumn get locked => boolean().withDefault(const Constant(false))();
  TextColumn get nickname => text().nullable()();
  BoolColumn get isPrismaticSkin =>
      boolean().withDefault(const Constant(false))();
  TextColumn get natureId => text().nullable()();
  TextColumn get parentageJson => text().nullable()();
  TextColumn get geneticsJson => text().nullable()();
  TextColumn get likelihoodAnalysisJson => text().nullable()();
  IntColumn get staminaMax => integer().withDefault(const Constant(3))();
  IntColumn get staminaBars => integer().withDefault(const Constant(3))();
  IntColumn get staminaLastUtcMs => integer().withDefault(const Constant(0))();
  IntColumn get createdAtUtcMs => integer().withDefault(const Constant(0))();

  // NEW STAT COLUMNS
  RealColumn get statSpeed => real().withDefault(const Constant(3.0))();
  RealColumn get statIntelligence => real().withDefault(const Constant(3.0))();
  RealColumn get statStrength => real().withDefault(const Constant(3.0))();
  RealColumn get statBeauty => real().withDefault(const Constant(3.0))();
  @override
  Set<Column> get primaryKey => {instanceId};
}

class FeedEvents extends Table {
  TextColumn get eventId => text()();
  TextColumn get targetInstanceId => text()();
  TextColumn get fodderInstanceId => text()();
  IntColumn get xpGained => integer()();
  IntColumn get createdAtUtcMs => integer()();
  @override
  Set<Column> get primaryKey => {eventId};
}

// =================== DATABASE ===================

@DriftDatabase(
  tables: [
    PlayerCreatures,
    IncubatorSlots,
    Eggs,
    Settings,
    CreatureInstances,
    FeedEvents,
    BiomeFarms,
    BiomeJobs,
    CompetitionProgress,
  ],
)
class AlchemonsDatabase extends _$AlchemonsDatabase {
  AlchemonsDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedInitialData();
    },
    onUpgrade: (m, from, to) async {
      if (from < 13) {
        // Create new biome tables
        await m.createTable(biomeFarms);
        await m.createTable(biomeJobs);
        await _seedBiomes();

        // Ensure all resource keys exist
        for (final k in ElementResources.settingsKeys) {
          final v = await getSetting(k);
          if (v == null) await setSetting(k, '0');
        }
      }
      if (from < 14) {
        // Add stat columns to existing instances
        await m.addColumn(creatureInstances, creatureInstances.statSpeed);
        await m.addColumn(
          creatureInstances,
          creatureInstances.statIntelligence,
        );
        await m.addColumn(creatureInstances, creatureInstances.statStrength);
        await m.addColumn(creatureInstances, creatureInstances.statBeauty);
      }
    },
  );

  Future<void> _seedInitialData() async {
    // Seed incubator slots
    final slotsToInsert = [
      IncubatorSlotsCompanion(id: const Value(0), unlocked: const Value(true)),
      IncubatorSlotsCompanion(id: const Value(1), unlocked: const Value(true)),
      IncubatorSlotsCompanion(id: const Value(2), unlocked: const Value(false)),
    ];
    for (final slot in slotsToInsert) {
      await into(incubatorSlots).insert(slot);
    }

    // Seed settings
    await setSetting('blob_slots_unlocked', '2');
    await setSetting('blob_instances', '[]');
    await setSetting('wallet_soft', '100');
    await setSetting('shop_show_purchased', '0');

    // Seed biomes
    await _seedBiomes();

    // Seed resource balances
    for (final k in ElementResources.settingsKeys) {
      await setSetting(k, '0');
    }
  }

  Future<void> _seedBiomes() async {
    final existing = await select(biomeFarms).get();
    if (existing.isNotEmpty) return;

    final rows = [
      BiomeFarmsCompanion(biomeId: const Value('volcanic')),
      BiomeFarmsCompanion(biomeId: const Value('oceanic')),
      BiomeFarmsCompanion(biomeId: const Value('earthen')),
      BiomeFarmsCompanion(biomeId: const Value('verdant')),
      BiomeFarmsCompanion(biomeId: const Value('arcane')),
    ];

    for (final r in rows) {
      await into(biomeFarms).insert(r);
    }
  }

  // =================== SETTINGS ===================

  Future<String?> getSetting(String key) async {
    final row = await (select(
      settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion(key: Value(key), value: Value(value)),
    );
  }

  // =================== WALLET ===================

  Future<int> getSoftBalance() async =>
      int.tryParse(await getSetting('wallet_soft') ?? '0') ?? 0;

  Future<void> addSoft(int amount) async {
    final cur = await getSoftBalance();
    await setSetting('wallet_soft', (cur + amount).toString());
  }

  Future<bool> spendSoft(int amount) async {
    final cur = await getSoftBalance();
    if (cur < amount) return false;
    await setSetting('wallet_soft', (cur - amount).toString());
    return true;
  }

  // =================== RESOURCES ===================

  Future<int> getResource(String key) async =>
      int.tryParse(await getSetting(key) ?? '0') ?? 0;

  Future<void> addResource(String key, int delta) async {
    final cur = await getResource(key);
    await setSetting(key, (cur + delta).toString());
  }

  Future<bool> spendResources(Map<String, int> costMap) async {
    // Verify all resources available
    for (final e in costMap.entries) {
      if (await getResource(e.key) < e.value) return false;
    }
    // Deduct
    for (final e in costMap.entries) {
      await addResource(e.key, -e.value);
    }
    return true;
  }

  Stream<Map<String, int>> watchResourceBalances() {
    final q = select(settings)
      ..where((t) => t.key.isIn(ElementResources.settingsKeys));
    return q.watch().map((rows) {
      final m = {for (final k in ElementResources.settingsKeys) k: 0};
      for (final r in rows) {
        m[r.key] = int.tryParse(r.value) ?? 0;
      }
      return m;
    });
  }

  // =================== INCUBATOR ===================

  Stream<List<IncubatorSlot>> watchSlots() => (select(
    incubatorSlots,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();

  Future<IncubatorSlot?> firstFreeSlot() {
    final q = (select(incubatorSlots)
      ..where((t) => t.unlocked.equals(true) & t.eggId.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.id)])
      ..limit(1));
    return q.getSingleOrNull();
  }

  Future<void> placeEgg({
    required int slotId,
    required String eggId,
    required String resultCreatureId,
    String? bonusVariantId,
    required String rarity,
    required DateTime hatchAtUtc,
    String? payloadJson,
  }) async {
    await (update(incubatorSlots)..where((t) => t.id.equals(slotId))).write(
      IncubatorSlotsCompanion(
        eggId: Value(eggId),
        resultCreatureId: Value(resultCreatureId),
        bonusVariantId: Value(bonusVariantId),
        rarity: Value(rarity),
        hatchAtUtcMs: Value(hatchAtUtc.toUtc().millisecondsSinceEpoch),
        payloadJson: Value(payloadJson),
      ),
    );
  }

  Future<void> clearEgg(int slotId) async {
    await (update(incubatorSlots)..where((t) => t.id.equals(slotId))).write(
      const IncubatorSlotsCompanion(
        eggId: Value(null),
        resultCreatureId: Value(null),
        bonusVariantId: Value(null),
        rarity: Value(null),
        hatchAtUtcMs: Value(null),
      ),
    );
  }

  Future<void> unlockSlot(int slotId) async {
    await (update(incubatorSlots)..where((t) => t.id.equals(slotId))).write(
      const IncubatorSlotsCompanion(unlocked: Value(true)),
    );
  }

  Future<DateTime?> speedUpSlot({
    required int slotId,
    required Duration delta,
    required DateTime safeNowUtc,
  }) async {
    final row = await (select(
      incubatorSlots,
    )..where((t) => t.id.equals(slotId))).getSingle();
    if (row.eggId == null || row.hatchAtUtcMs == null) return null;

    final current = DateTime.fromMillisecondsSinceEpoch(
      row.hatchAtUtcMs!,
      isUtc: true,
    );
    final target = current.subtract(delta).isBefore(safeNowUtc)
        ? safeNowUtc
        : current.subtract(delta);

    await (update(incubatorSlots)..where((t) => t.id.equals(slotId))).write(
      IncubatorSlotsCompanion(
        hatchAtUtcMs: Value(target.millisecondsSinceEpoch),
      ),
    );
    return target;
  }

  // =================== EGG INVENTORY ===================

  Stream<List<Egg>> watchInventory() =>
      (select(eggs)..orderBy([(t) => OrderingTerm.asc(t.rarity)])).watch();

  Future<void> enqueueEgg({
    required String eggId,
    required String resultCreatureId,
    String? bonusVariantId,
    required String rarity,
    required Duration remaining,
    String? payloadJson,
  }) async {
    await into(eggs).insertOnConflictUpdate(
      EggsCompanion(
        eggId: Value(eggId),
        resultCreatureId: Value(resultCreatureId),
        bonusVariantId: Value(bonusVariantId),
        rarity: Value(rarity),
        remainingMs: Value(remaining.inMilliseconds),
        payloadJson: Value(payloadJson),
      ),
    );
  }

  Future<void> removeFromInventory(String eggId) async {
    await (delete(eggs)..where((t) => t.eggId.equals(eggId))).go();
  }

  // =================== POKEDEX ===================

  Future<void> addOrUpdateCreature(PlayerCreaturesCompanion entry) =>
      into(playerCreatures).insertOnConflictUpdate(entry);

  Future<PlayerCreature?> getCreature(String id) => (select(
    playerCreatures,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<PlayerCreature>> getAllCreatures() =>
      select(playerCreatures).get();

  Stream<List<PlayerCreature>> watchAllCreatures() => (select(
    playerCreatures,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();

  Stream<List<PlayerCreature>> watchDiscovered() => (select(
    playerCreatures,
  )..where((t) => t.discovered.equals(true))).watch();

  // =================== INSTANCES ===================

  static const int defaultSpeciesCap = 100;

  Future<int> countBySpecies(String baseId) async {
    final countExp = creatureInstances.baseId.count();
    final row =
        await (selectOnly(creatureInstances)
              ..addColumns([countExp])
              ..where(creatureInstances.baseId.equals(baseId)))
            .getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<bool> canAddInstance(
    String baseId, {
    int cap = defaultSpeciesCap,
  }) async {
    final n = await countBySpecies(baseId);
    return n < cap;
  }

  Future<String> insertInstance({
    required String instanceId,
    required String baseId,
    int level = 1,
    int xp = 0,
    bool locked = false,
    String? nickname,
    bool isPrismaticSkin = false,
    String? natureId,
    Map<String, dynamic>? parentage,
    Map<String, String>? genetics,
    String? likelihoodAnalysisJson,
    DateTime? createdAtUtc,
    int? staminaMax,
    int? staminaBars,
    double? statSpeed,
    double? statIntelligence,
    double? statStrength,
    double? statBeauty,
  }) async {
    final nowMs =
        (createdAtUtc ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    final maxBars = staminaMax ?? 3;
    final curBars = staminaBars ?? maxBars;

    await into(creatureInstances).insert(
      CreatureInstancesCompanion(
        instanceId: Value(instanceId),
        baseId: Value(baseId),
        level: Value(level),
        xp: Value(xp),
        locked: Value(locked),
        nickname: Value(nickname),
        isPrismaticSkin: Value(isPrismaticSkin),
        natureId: Value(natureId),
        parentageJson: Value(parentage == null ? null : jsonEncode(parentage)),
        geneticsJson: Value(genetics == null ? null : jsonEncode(genetics)),
        likelihoodAnalysisJson: Value(likelihoodAnalysisJson),
        staminaMax: Value(maxBars),
        staminaBars: Value(curBars),
        staminaLastUtcMs: Value(nowMs),
        createdAtUtcMs: Value(nowMs),
        statSpeed: Value(statSpeed ?? 3.0),
        statIntelligence: Value(statIntelligence ?? 3.0),
        statStrength: Value(statStrength ?? 3.0),
        statBeauty: Value(statBeauty ?? 3.0),
      ),
    );

    await addOrUpdateCreature(
      PlayerCreaturesCompanion(
        id: Value(baseId),
        discovered: const Value(true),
        natureId: Value(natureId),
      ),
    );
    return instanceId;
  }

  Future<void> updateStamina({
    required String instanceId,
    required int staminaBars,
    required int staminaLastUtcMs,
  }) async {
    await (update(
      creatureInstances,
    )..where((t) => t.instanceId.equals(instanceId))).write(
      CreatureInstancesCompanion(
        staminaBars: Value(staminaBars),
        staminaLastUtcMs: Value(staminaLastUtcMs),
      ),
    );
  }

  Future<void> updateLikelihoodAnalysis({
    required String instanceId,
    String? likelihoodAnalysisJson,
  }) async {
    await (update(
      creatureInstances,
    )..where((t) => t.instanceId.equals(instanceId))).write(
      CreatureInstancesCompanion(
        likelihoodAnalysisJson: Value(likelihoodAnalysisJson),
      ),
    );
  }

  Future<CreatureInstance?> getInstance(String instanceId) => (select(
    creatureInstances,
  )..where((t) => t.instanceId.equals(instanceId))).getSingleOrNull();

  Future<List<CreatureInstance>> listInstancesBySpecies(String baseId) =>
      (select(creatureInstances)..where((t) => t.baseId.equals(baseId))).get();

  Stream<List<CreatureInstance>> watchInstancesBySpecies(String baseId) =>
      (select(
        creatureInstances,
      )..where((t) => t.baseId.equals(baseId))).watch();

  Future<List<CreatureInstance>> listAllInstances() =>
      select(creatureInstances).get();

  Stream<List<CreatureInstance>> watchAllInstances() =>
      select(creatureInstances).watch();

  // AlchemonsDatabase
  Stream<CreatureInstance?> watchInstanceById(String instanceId) {
    final q = select(creatureInstances)
      ..where((t) => t.instanceId.equals(instanceId));
    return q
        .watchSingleOrNull(); // or q.watch().map((r) => r.isEmpty ? null : r.first);
  }

  Future<void> deleteInstances(List<String> instanceIds) async {
    if (instanceIds.isEmpty) return;
    await (delete(
      creatureInstances,
    )..where((t) => t.instanceId.isIn(instanceIds))).go();
  }

  Future<void> setLocked(String instanceId, bool lock) async {
    await (update(creatureInstances)
          ..where((t) => t.instanceId.equals(instanceId)))
        .write(CreatureInstancesCompanion(locked: Value(lock)));
  }

  Future<void> setNickname(String instanceId, String? nickname) async {
    await (update(creatureInstances)
          ..where((t) => t.instanceId.equals(instanceId)))
        .write(CreatureInstancesCompanion(nickname: Value(nickname)));
  }

  Future<void> addXpAndMaybeLevel({
    required String instanceId,
    required int deltaXp,
    required int Function(int level) xpNeededForLevel,
    int maxLevel = 100,
  }) async {
    final row = await getInstance(instanceId);
    if (row == null) return;

    var newXp = row.xp + deltaXp;
    var level = row.level;

    while (level < maxLevel && newXp >= xpNeededForLevel(level)) {
      newXp -= xpNeededForLevel(level);
      level++;
    }

    await (update(
      creatureInstances,
    )..where((t) => t.instanceId.equals(instanceId))).write(
      CreatureInstancesCompanion(level: Value(level), xp: Value(newXp)),
    );
  }

  // NEW STAT UPDATES
  Future<void> updateStats({
    required String instanceId,
    required double statSpeed,
    required double statIntelligence,
    required double statStrength,
    required double statBeauty,
  }) async {
    await (update(
      creatureInstances,
    )..where((t) => t.instanceId.equals(instanceId))).write(
      CreatureInstancesCompanion(
        statSpeed: Value(statSpeed),
        statIntelligence: Value(statIntelligence),
        statStrength: Value(statStrength),
        statBeauty: Value(statBeauty),
      ),
    );
  }

  // =================== FEED LOG ===================

  Future<void> logFeed({
    required String eventId,
    required String targetInstanceId,
    required String fodderInstanceId,
    required int xpGained,
    DateTime? createdAtUtc,
  }) async {
    await into(feedEvents).insert(
      FeedEventsCompanion(
        eventId: Value(eventId),
        targetInstanceId: Value(targetInstanceId),
        fodderInstanceId: Value(fodderInstanceId),
        xpGained: Value(xpGained),
        createdAtUtcMs: Value(
          (createdAtUtc ?? DateTime.now().toUtc()).millisecondsSinceEpoch,
        ),
      ),
    );
  }

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

    final ok = await spendResources(cost);
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

    // Spend stamina
    final inst = await getInstance(creatureInstanceId);
    if (inst == null || inst.staminaBars <= 0) return false;

    await updateStamina(
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
    final resKey = biome.resourceKeyForElement(farm.activeElementId!);

    await addResource(resKey, payout);
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

  // =================== BLOB PARTY (OVERLAY) ===================

  Future<int> getBlobSlotsUnlocked() async {
    final v = await getSetting('blob_slots_unlocked');
    if (v == null) {
      await setSetting('blob_slots_unlocked', '1');
      return 1;
    }
    final n = int.tryParse(v) ?? 1;
    return n.clamp(1, 3);
  }

  Future<void> setBlobSlotsUnlocked(int n) async {
    final clamped = n.clamp(1, 3);
    await setSetting('blob_slots_unlocked', clamped.toString());
  }

  Future<List<String?>> getBlobInstanceSlots() async {
    final keys = ['blob_slot_0', 'blob_slot_1', 'blob_slot_2'];
    final vals = <String?>[];
    for (final k in keys) {
      final v = await getSetting(k);
      vals.add(v == '' ? null : v);
    }
    return vals;
  }

  Future<void> setBlobSlotInstance(int index, String? instanceId) async {
    if (index < 0 || index > 2) return;
    final key = 'blob_slot_$index';
    await setSetting(key, instanceId ?? '');
  }

  // =================== SHOP PREFS ===================

  Future<bool> getShopShowPurchased() async {
    final v = await getSetting('shop_show_purchased');
    if (v == null) {
      await setSetting('shop_show_purchased', '0');
      return false;
    }
    return v == '1' || v.toLowerCase() == 'true';
  }

  Future<void> setShopShowPurchased(bool value) async {
    await setSetting('shop_show_purchased', value ? '1' : '0');
  }
}
