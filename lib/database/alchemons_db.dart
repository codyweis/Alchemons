// lib/database/alchemons_db.dart
import 'dart:convert';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/models/farm_element.dart';
import 'package:drift/drift.dart';

part 'alchemons_db.g.dart';

class PlayerCreatures extends Table {
  TextColumn get id => text()(); // species / catalog id
  BoolColumn get discovered => boolean().withDefault(const Constant(false))();
  TextColumn get natureId => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

// Existing: active incubators
class IncubatorSlots extends Table {
  IntColumn get id => integer()(); // 0,1,2...
  BoolColumn get unlocked => boolean().withDefault(const Constant(true))();

  TextColumn get eggId => text().nullable()(); // unique instance id
  TextColumn get resultCreatureId => text().nullable()();
  TextColumn get bonusVariantId => text().nullable()();
  TextColumn get rarity => text().nullable()();
  IntColumn get hatchAtUtcMs => integer().nullable()(); // absolute UTC ms
  TextColumn get payloadJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// NEW: queued eggs (not progressing). Store remainingMs snapshot.
class Eggs extends Table {
  TextColumn get eggId => text()(); // unique instance id
  TextColumn get resultCreatureId => text()(); // CRxxx (baseId)
  TextColumn get rarity => text()(); // "Common", ...
  TextColumn get bonusVariantId => text().nullable()();
  IntColumn get remainingMs => integer()(); // doesn't tick while queued
  TextColumn get payloadJson => text().nullable()();
  @override
  Set<Column> get primaryKey => {eggId};
}

// ---------- Harvest: farms & active jobs ----------
class HarvestFarms extends Table {
  IntColumn get id => integer()(); // 0=fire,1=water,2=air,3=earth
  TextColumn get element => text()(); // "fire" | "water" | "air" | "earth"
  BoolColumn get unlocked => boolean().withDefault(const Constant(false))();
  IntColumn get level => integer().withDefault(const Constant(1))();
  @override
  Set<Column> get primaryKey => {id};
}

class HarvestJobs extends Table {
  TextColumn get jobId => text()(); // ULID/uuid
  IntColumn get farmId => integer()(); // FK -> HarvestFarms.id
  TextColumn get creatureInstanceId =>
      text()(); // FK -> CreatureInstances.instanceId
  IntColumn get startUtcMs => integer()(); // absolute UTC ms
  IntColumn get durationMs => integer()(); // total duration
  IntColumn get ratePerMinute => integer()(); // fixed snapshot
  @override
  Set<Column> get primaryKey => {jobId};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

// ---------- New: player-owned instances ----------
class CreatureInstances extends Table {
  TextColumn get instanceId => text()();
  TextColumn get baseId => text()();

  // Core state
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get xp => integer().withDefault(const Constant(0))();
  BoolColumn get locked => boolean().withDefault(const Constant(false))();
  TextColumn get nickname => text().nullable()();

  // Cosmetics and inheritance (serialized)
  BoolColumn get isPrismaticSkin =>
      boolean().withDefault(const Constant(false))();
  TextColumn get natureId => text().nullable()();
  TextColumn get parentageJson => text().nullable()();
  TextColumn get geneticsJson => text().nullable()();

  // Breeding analysis (NEW)
  TextColumn get likelihoodAnalysisJson => text().nullable()();

  // Stamina (NEW)
  IntColumn get staminaMax => integer().withDefault(const Constant(3))();
  IntColumn get staminaBars => integer().withDefault(const Constant(3))();
  IntColumn get staminaLastUtcMs => integer().withDefault(const Constant(0))();

  // Book-keeping
  IntColumn get createdAtUtcMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {instanceId};
}

// ---------- New: feeding audit log (optional) ----------
class FeedEvents extends Table {
  TextColumn get eventId => text()(); // ULID
  TextColumn get targetInstanceId => text()();
  TextColumn get fodderInstanceId => text()();
  IntColumn get xpGained => integer()();
  IntColumn get createdAtUtcMs => integer()();

  @override
  Set<Column> get primaryKey => {eventId};
}

@DriftDatabase(
  tables: [
    PlayerCreatures,
    IncubatorSlots,
    Eggs,
    Settings,
    CreatureInstances, // <-- registered
    FeedEvents, // <-- registered
    HarvestFarms, // ← add
    HarvestJobs, // ← add
  ],
)
class AlchemonsDatabase extends _$AlchemonsDatabase {
  AlchemonsDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();

      // seed nests
      final slotsToInsert = [
        IncubatorSlotsCompanion(
          id: const Value(0),
          unlocked: const Value(true),
        ),
        IncubatorSlotsCompanion(
          id: const Value(1),
          unlocked: const Value(true),
        ),
        IncubatorSlotsCompanion(
          id: const Value(2),
          unlocked: const Value(false),
        ),
      ];
      await setSetting('blob_slots_unlocked', '2');
      await setSetting('blob_instances', '[]');
      // Seed harvest farms
      await _seedHarvestFarms();
      // Optional: seed resource balances
      for (final k in ElementResources.settingsKeys) {
        await setSetting(k, '0');
      }
      for (final slot in slotsToInsert) {
        await into(incubatorSlots).insert(slot);
      }

      // seed wallet
      await setSetting('wallet_soft', '100'); // starter soft currency
    },
    onUpgrade: (m, from, to) async {
      // Existing migrations you already had
      if (from < 2) {
        await m.createTable(incubatorSlots);
        await m.createTable(settings);
        final existing = await select(incubatorSlots).get();
        if (existing.isEmpty) {
          final slotsToInsert = [
            IncubatorSlotsCompanion(
              id: const Value(0),
              unlocked: const Value(true),
            ),
            IncubatorSlotsCompanion(
              id: const Value(1),
              unlocked: const Value(true),
            ),
            IncubatorSlotsCompanion(
              id: const Value(2),
              unlocked: const Value(false),
            ),
          ];
          for (final slot in slotsToInsert) {
            await into(incubatorSlots).insert(slot);
          }
        }
      }
      if (from < 3) {
        await m.createTable(eggs);
        final w = await getSetting('wallet_soft');
        if (w == null) await setSetting('wallet_soft', '100');
      }
      // New: v4 – instances table
      if (from < 4) {
        await m.createTable(creatureInstances);
      }
      // New: v5 – feed log
      if (from < 5) {
        await m.createTable(feedEvents);
      }
      if (from < 6) {
        await m.addColumn(incubatorSlots, incubatorSlots.payloadJson);
        await m.addColumn(eggs, eggs.payloadJson);
      }
      if (from < 7) {
        await m.addColumn(creatureInstances, creatureInstances.staminaMax);
        await m.addColumn(creatureInstances, creatureInstances.staminaBars);
        await m.addColumn(
          creatureInstances,
          creatureInstances.staminaLastUtcMs,
        );

        // Optionally backfill sane values for existing rows
        final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        await customStatement(
          '''
      UPDATE creature_instances
      SET stamina_max = COALESCE(stamina_max, 3),
          stamina_bars = CASE
            WHEN COALESCE(stamina_bars, 0) = 0 THEN 3
            ELSE MIN(stamina_bars, COALESCE(stamina_max, 3))
          END,
          stamina_last_utc_ms = CASE
            WHEN COALESCE(stamina_last_utc_ms, 0) = 0 THEN ?
            ELSE stamina_last_utc_ms
          END
    ''',
          [nowMs],
        );
      }
      if (from < 8) {
        final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        // Normalize stamina to your new rules:
        // - Metabolic => +1 max bar (4)
        // - Others => 3
        // - Clamp current bars to the new max
        // - Ensure regen anchor is set
        await customStatement(
          '''
    UPDATE creature_instances
    SET stamina_max = CASE
          WHEN LOWER(COALESCE(nature_id, '')) = 'metabolic' THEN 4
          ELSE 3
        END,
        stamina_bars = MIN(
          COALESCE(stamina_bars, 0),
          CASE
            WHEN LOWER(COALESCE(nature_id, '')) = 'metabolic' THEN 4
            ELSE 3
          END
        ),
        stamina_last_utc_ms = CASE
          WHEN COALESCE(stamina_last_utc_ms, 0) = 0 THEN ?
          ELSE stamina_last_utc_ms
        END
    ''',
          [nowMs],
        );
      }
      // NEW: v9 - Add likelihood analysis column
      if (from < 9) {
        await m.addColumn(
          creatureInstances,
          creatureInstances.likelihoodAnalysisJson,
        );
      }
      if (from < 10) {
        await m.createTable(harvestFarms);
        await m.createTable(harvestJobs);
        await _seedHarvestFarms();
        // Backfill resource keys if missing
        for (final k in [
          'res_embers',
          'res_droplets',
          'res_breeze',
          'res_shards',
        ]) {
          final v = await getSetting(k);
          if (v == null) await setSetting(k, '0');
        }
      }
      if (from < 11) {
        // backfill farms if table exists but empty
        final rows = await select(harvestFarms).get();
        if (rows.isEmpty) {
          await _seedHarvestFarms();
        }
        // ensure resource keys exist
        for (final k in _kResourceKeys) {
          final v = await getSetting(k);
          if (v == null) await setSetting(k, '0');
        }
      }
      if (from < 12) {
        // Legacy -> new naming
        final breeze = await getSetting('res_breeze');
        if (breeze != null) {
          await setSetting('res_wisps', breeze);
          // optional: clear the legacy key
          // await setSetting('res_breeze', '0');
        }
        final earthShards = await getSetting('res_shards'); // previously Earth
        if (earthShards != null) {
          await setSetting(
            'res_pebbles',
            earthShards,
          ); // move to Earth's new key
          // keep Ice shards at 0 unless you want to retain the old number for Ice
          await setSetting('res_shards', '0');
        }
        // Make sure ALL keys exist
        for (final k in ElementResources.settingsKeys) {
          final v = await getSetting(k);
          if (v == null) await setSetting(k, '0');
        }
      }
    },
  );

  // -------------------- Settings helpers --------------------

  Future<void> _seedHarvestFarms() async {
    final existing = await select(harvestFarms).get();
    if (existing.isNotEmpty) return;
    final rows = [
      HarvestFarmsCompanion(id: const Value(0), element: const Value('fire')),
      HarvestFarmsCompanion(id: const Value(1), element: const Value('water')),
      HarvestFarmsCompanion(id: const Value(2), element: const Value('air')),
      HarvestFarmsCompanion(id: const Value(3), element: const Value('earth')),
    ];
    for (final r in rows) {
      await into(harvestFarms).insert(r);
    }
  }

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

  // wallet (soft currency)
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

  // -------------------- Incubator helpers (existing + new) --------------------
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
    String? payloadJson, // NEW
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
    required DateTime safeNowUtc, // pass your clamped now
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

  // -------------------- Egg inventory helpers --------------------
  Stream<List<Egg>> watchInventory() =>
      (select(eggs)..orderBy([(t) => OrderingTerm.asc(t.rarity)])).watch();

  Future<void> enqueueEgg({
    required String eggId,
    required String resultCreatureId,
    String? bonusVariantId,
    required String rarity,
    required Duration remaining, // snapshot; doesn't tick while queued
    String? payloadJson, // NEW
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

  // -------------------- Pokedex / discovery helpers --------------------
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

  // -------------------- Instances: caps & CRUD --------------------
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

  /// Inserts a new instance row. Returns the inserted instanceId.
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
    String? likelihoodAnalysisJson, // NEW
    DateTime? createdAtUtc,
    int? staminaMax, // ← NEW (optional override)
    int? staminaBars, // ← NEW (optional override)
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
        likelihoodAnalysisJson: Value(likelihoodAnalysisJson), // NEW
        staminaMax: Value(maxBars),
        staminaBars: Value(curBars),
        staminaLastUtcMs: Value(nowMs),
        createdAtUtcMs: Value(nowMs),
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

  // -------------------- Feeding audit --------------------
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

  Future<List<CreatureInstance>> listAllInstances() =>
      select(creatureInstances).get();

  Stream<List<CreatureInstance>> watchAllInstances() =>
      select(creatureInstances).watch();

  // ---------- Resources (using Settings as KV) ----------
  Future<int> getResource(String key) async =>
      int.tryParse(await getSetting(key) ?? '0') ?? 0;

  Future<void> addResource(String key, int delta) async {
    final cur = await getResource(key);
    await setSetting(key, (cur + delta).toString());
  }

  Future<bool> spendResources(Map<String, int> costMap) async {
    // All-or-nothing: verify
    for (final e in costMap.entries) {
      if (await getResource(e.key) < e.value) return false;
    }
    // Deduct
    for (final e in costMap.entries) {
      await addResource(e.key, -e.value);
    }
    return true;
  }

  /// Live stream of resource balances {key -> amount}
  Stream<Map<String, int>> watchResourceBalances() {
    final q = select(settings)..where((t) => t.key.isIn(_kResourceKeys));
    return q.watch().map((rows) {
      final m = {for (final k in _kResourceKeys) k: 0};
      for (final r in rows) {
        m[r.key] = int.tryParse(r.value) ?? 0;
      }
      return m;
    });
  }

  static final _kResourceKeys = ElementResources.settingsKeys;

  String resourceKeyForElement(String element) =>
      ElementResources.keyForElement(element);

  // ---------- Harvest operations ----------
  Stream<List<HarvestFarm>> watchFarms() =>
      (select(harvestFarms)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();

  Future<HarvestFarm?> getFarmByElement(String element) => (select(
    harvestFarms,
  )..where((t) => t.element.equals(element))).getSingleOrNull();

  Future<bool> unlockFarm({
    required String element,
    required Map<String, int> cost, // e.g. {'res_embers':50, 'res_droplets':20}
  }) async {
    final farm = await getFarmByElement(element);
    if (farm == null) return false;
    if (farm.unlocked) return true;
    final ok = await spendResources(cost);
    if (!ok) return false;
    await (update(harvestFarms)..where((t) => t.id.equals(farm.id))).write(
      const HarvestFarmsCompanion(unlocked: Value(true)),
    );
    return true;
  }

  /// Move the active job's start time earlier by `deltaMs` (negative speeds up).
  /// Clamps so the job can't end in the past—at most to "now".
  Future<bool> nudgeHarvest({
    required String element, // 'fire' | 'water' | 'air' | 'earth'
    required int deltaMs, // e.g. -1000 per tap
  }) async {
    final farm = await getFarmByElement(element);
    if (farm == null) return false;
    final job = await getActiveJobForFarm(farm.id);
    if (job == null) return false;

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    // Original finish time
    final oldEnd = job.startUtcMs + job.durationMs;

    // We "pull" the start earlier by |deltaMs|
    var newStart = job.startUtcMs + deltaMs;

    // Clamp so end time never goes before now (let it be exactly now at max)
    final newEnd = newStart + job.durationMs;
    if (newEnd < nowMs) {
      newStart = nowMs - job.durationMs;
    }

    // No-op?
    if (newStart == job.startUtcMs) return false;

    await (update(harvestJobs)..where((t) => t.jobId.equals(job.jobId))).write(
      HarvestJobsCompanion(startUtcMs: Value(newStart)),
    );
    return true;
  }

  Future<HarvestJob?> getActiveJobForFarm(int farmId) async {
    final q = select(harvestJobs)..where((t) => t.farmId.equals(farmId));
    final list = await q.get();
    // Only one job per farm; keep last if any
    return list.isEmpty ? null : list.last;
  }

  Future<bool> startHarvest({
    required String element, // 'fire'|'water'|'air'|'earth'
    required String jobId, // ULID/uuid
    required String creatureInstanceId,
    required Duration duration,
    required int ratePerMinute,
  }) async {
    final farm = await getFarmByElement(element);
    if (farm == null || !farm.unlocked) return false;
    final active = await getActiveJobForFarm(farm.id);
    if (active != null) return false;

    // Spend stamina: -1 bar now (simple rule)
    final inst = await getInstance(creatureInstanceId);
    if (inst == null || inst.staminaBars <= 0) return false;
    await updateStamina(
      instanceId: inst.instanceId,
      staminaBars: inst.staminaBars - 1,
      staminaLastUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );

    await into(harvestJobs).insert(
      HarvestJobsCompanion(
        jobId: Value(jobId),
        farmId: Value(farm.id),
        creatureInstanceId: Value(creatureInstanceId),
        startUtcMs: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
        durationMs: Value(duration.inMilliseconds),
        ratePerMinute: Value(ratePerMinute),
      ),
    );
    return true;
  }

  Future<int> collectHarvest({required String element}) async {
    final farm = await getFarmByElement(element);
    if (farm == null) return 0;
    final job = await getActiveJobForFarm(farm.id);
    if (job == null) return 0;

    final endMs = job.startUtcMs + job.durationMs;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (nowMs < endMs) return 0; // not ready

    final totalMinutes = Duration(milliseconds: job.durationMs).inMinutes;
    final payout = totalMinutes * job.ratePerMinute;

    // Credit resource
    final resKey = resourceKeyForElement(element);
    await addResource(resKey, payout);

    // Clear job
    await (delete(harvestJobs)..where((t) => t.jobId.equals(job.jobId))).go();
    return payout;
  }

  Future<void> cancelHarvest({required String element}) async {
    final farm = await getFarmByElement(element);
    if (farm == null) return;
    final job = await getActiveJobForFarm(farm.id);
    if (job == null) return;
    await (delete(harvestJobs)..where((t) => t.jobId.equals(job.jobId))).go();
  }

  // ---------- Blob party (overlay) helpers ----------
  // ---------- Floating bubble slots (Settings-backed) ----------
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

  /// Return up to 3 instance ids (nullable) for slots 0..2
  Future<List<String?>> getBlobInstanceSlots() async {
    final keys = ['blob_slot_0', 'blob_slot_1', 'blob_slot_2'];
    final vals = <String?>[];
    for (final k in keys) {
      vals.add(await getSetting(k));
    }
    return vals;
  }

  Future<void> setBlobSlotInstance(int index, String? instanceId) async {
    if (index < 0 || index > 2) return;
    final key = 'blob_slot_$index';
    await setSetting(key, instanceId ?? '');
    // store empty as "" then normalize reads above ("" -> null)
    if ((await getSetting(key)) == '') {
      // interpret "" as null
      await into(settings).insertOnConflictUpdate(
        SettingsCompanion(key: Value(key), value: const Value('')),
      );
    }
  }

  Future<void> setBlobInstanceSlots(List<String?> slots) async {
    await setSetting('blob_instances', jsonEncode(slots));
  }

  // ---------- Shop prefs ----------
  Future<bool> getShopShowPurchased() async {
    final v = await getSetting('shop_show_purchased');
    if (v == null) {
      // default: HIDE purchased (false)
      await setSetting('shop_show_purchased', '0');
      return false;
    }
    return v == '1' || v.toLowerCase() == 'true';
  }

  Future<void> setShopShowPurchased(bool value) async {
    await setSetting('shop_show_purchased', value ? '1' : '0');
  }

  //“shop” can just call setBlobSlotsUnlocked(2 or 3)
}
