// lib/database/alchemons_db.dart
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/database/daos/constellation_dao.dart';
import 'package:drift/drift.dart';

// Schema and Model Imports
import 'package:alchemons/database/schema_tables.dart';

// DAO Imports
import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/database/daos/currency_dao.dart';
import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/database/daos/incubator_dao.dart';
import 'package:alchemons/database/daos/inventory_dao.dart';
import 'package:alchemons/database/daos/biome_dao.dart';
import 'package:alchemons/database/daos/shop_dao.dart';
import 'package:alchemons/database/daos/altar_dao.dart';

part 'alchemons_db.g.dart';

// =================== DATABASE ===================

@DriftDatabase(
  tables: [
    // existing
    PlayerCreatures,
    IncubatorSlots,
    Eggs,
    Settings,
    CreatureInstances,
    FeedEvents,
    BiomeFarms,
    BiomeJobs,
    CompetitionProgress,
    ShopPurchases,
    InventoryItems,

    // NEW wilderness tables
    ActiveSpawns,
    ActiveSceneEntry,
    SpawnSchedule,

    // Notification dismissals
    NotificationDismissals,

    ConstellationPoints,
    ConstellationTransactions,
    ConstellationUnlocks,
    BreedingStatistics,
    AltarPlacements,
    SurvivalHighScore,
  ],
  daos: [
    SettingsDao,
    CurrencyDao,
    CreatureDao,
    IncubatorDao,
    InventoryDao,
    BiomeDao,
    ShopDao,
    ConstellationDao,
    AltarDao,
  ],
)
class AlchemonsDatabase extends _$AlchemonsDatabase {
  AlchemonsDatabase(super.e);

  @override
  int get schemaVersion => 35;

  // This helper is used *only* during migration/seeding
  Future<void> _setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion(key: Value(key), value: Value(value)),
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedInitialData();
    },
    onUpgrade: (m, from, to) async {
      // NOTE: Your getSetting/setSetting calls in here must be
      // replaced with direct `select` or `_setSetting` calls,
      // as DAOs are not available during migration.

      if (from < 13) {
        await m.createTable(biomeFarms);
        await m.createTable(biomeJobs);
        await _seedBiomes();

        for (final k in ElementResources.settingsKeys) {
          final row = await (select(
            settings,
          )..where((t) => t.key.equals(k))).getSingleOrNull();
          if (row == null) await _setSetting(k, '0');
        }
      }
      if (from < 14) {
        await m.addColumn(creatureInstances, creatureInstances.statSpeed);
        await m.addColumn(
          creatureInstances,
          creatureInstances.statIntelligence,
        );
        await m.addColumn(creatureInstances, creatureInstances.statStrength);
        await m.addColumn(creatureInstances, creatureInstances.statBeauty);
      }
      if (from < 15) {
        await customUpdate(
          'UPDATE creature_instances SET stat_speed = 3.0, stat_intelligence = 3.0, stat_strength = 3.0, stat_beauty = 3.0',
        );
      }
      if (from < 16) {
        await m.addColumn(
          creatureInstances,
          creatureInstances.statSpeedPotential,
        );
        await m.addColumn(
          creatureInstances,
          creatureInstances.statIntelligencePotential,
        );
        await m.addColumn(
          creatureInstances,
          creatureInstances.statStrengthPotential,
        );
        await m.addColumn(
          creatureInstances,
          creatureInstances.statBeautyPotential,
        );
      }
      if (from < 17) {
        final goldExists = await (select(
          settings,
        )..where((t) => t.key.equals('wallet_gold'))).getSingleOrNull();
        if (goldExists == null) await _setSetting('wallet_gold', '0');

        final silverExists = await (select(
          settings,
        )..where((t) => t.key.equals('wallet_silver'))).getSingleOrNull();
        if (silverExists == null) await _setSetting('wallet_silver', '100');
      }
      if (from < 18) {
        await m.createTable(shopPurchases);
      }
      if (from < 19) {
        await m.addColumn(creatureInstances, creatureInstances.generationDepth);
        await m.addColumn(
          creatureInstances,
          creatureInstances.factionLineageJson,
        );
        await m.addColumn(creatureInstances, creatureInstances.variantFaction);
      }
      if (from < 20) {
        await m.addColumn(creatureInstances, creatureInstances.isPure);
      }
      if (from < 21) {
        await m.addColumn(
          creatureInstances,
          creatureInstances.elementLineageJson,
        );
        await m.addColumn(
          creatureInstances,
          creatureInstances.familyLineageJson,
        );
      }
      if (from < 22) {
        await m.createTable(inventoryItems);
      }
      // NEW: add wilderness persistence
      if (from < 23) {
        await m.createTable(activeSpawns);
        await m.createTable(activeSceneEntry);
      }
      if (from < 24) {
        await m.createTable(spawnSchedule);
      }
      if (from < 25) {
        await m.createTable(notificationDismissals);
      }
      if (from < 27) {
        await m.addColumn(creatureInstances, creatureInstances.source);
      }
      if (from < 28) {
        await m.addColumn(creatureInstances, creatureInstances.alchemyEffect);
      }
      if (from < 29) {
        await m.createTable(breedingStatistics);
        await m.createTable(constellationUnlocks);
        await m.createTable(constellationTransactions);
        await m.createTable(constellationPoints);

        final pointsExist =
            await (select(settings)
                  ..where((t) => t.key.equals('constellation_points')))
                .getSingleOrNull();
        if (pointsExist == null) {
          await _setSetting('constellation_points', '0');
        }
      } else if (from < 30) {
        // Only runs for from == 29
        await m.addColumn(
          constellationPoints,
          constellationPoints.hasSeenFinale,
        );
      }
      if (from < 31) {
        await m.createTable(altarPlacements);
      }
      if (from < 32) {
        // Guard against "duplicate column" if the column was already added
        // by a partially-committed prior migration run.
        try {
          await m.addColumn(altarPlacements, altarPlacements.snapshotJson);
        } catch (_) {}
      }
      if (from < 33) {
        await m.createTable(survivalHighScore);
      }
      if (from < 34) {
        await m.addColumn(creatureInstances, creatureInstances.isFavorite);
      }
      if (from < 35) {
        await customUpdate(
          "DELETE FROM inventory_items WHERE key IN ('item.cosmic_ship', 'item.elemental_creator')",
        );
      }
    },
  );

  // ── Survival Highscore helpers ────────────────────────────────────────────

  /// Returns the single highscore row, or null if never played.
  Future<SurvivalHighScoreData?> getSurvivalHighScore() async {
    return (select(
      survivalHighScore,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
  }

  /// Saves [wave], [score], [timeMs] only when they beat the stored records.
  /// Creates the row if it doesn't exist yet.
  Future<void> saveSurvivalHighScore({
    required int wave,
    required int score,
    required int timeMs,
  }) async {
    final existing = await getSurvivalHighScore();
    final newBestWave = existing == null
        ? wave
        : (wave > existing.bestWave ? wave : existing.bestWave);
    final newBestScore = existing == null
        ? score
        : (score > existing.bestScore ? score : existing.bestScore);
    final newBestTimeMs = existing == null
        ? timeMs
        : (timeMs > existing.bestTimeMs ? timeMs : existing.bestTimeMs);
    await into(survivalHighScore).insertOnConflictUpdate(
      SurvivalHighScoreCompanion(
        id: const Value(1),
        bestWave: Value(newBestWave),
        bestScore: Value(newBestScore),
        bestTimeMs: Value(newBestTimeMs),
      ),
    );
  }

  Future<void> resetToNewGame() async {
    await transaction(() async {
      await customStatement('PRAGMA foreign_keys = OFF');
      try {
        for (final table in allTables.toList().reversed) {
          await delete(table).go();
        }
        await _seedInitialData();
      } finally {
        await customStatement('PRAGMA foreign_keys = ON');
      }
    });
  }

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

    await _setSetting('wallet_gold', '5');
    await _setSetting('wallet_silver', '1000');

    // Seed settings
    await _setSetting('blob_slots_unlocked', '1');
    await _setSetting('blob_instances', '[]');
    await _setSetting('wallet_soft', '100');
    await _setSetting('shop_show_purchased', '0');

    // Seed biomes
    await _seedBiomes();

    await _setSetting('theme_mode', 'dark');

    // Seed resource balances
    for (final k in ElementResources.settingsKeys) {
      await _setSetting(k, '0');
    }

    // Seed initial inventory items
    await _seedInitialInventory();
  }

  Future<void> _seedInitialInventory() async {
    // Give 1 constellation point in the proper table
    await into(constellationPoints).insert(
      ConstellationPointsCompanion(
        currentBalance: const Value(1),
        totalEarned: const Value(1),
        totalSpent: const Value(0),
        hasSeenFinale: const Value(false),
        lastUpdatedUtc: Value(DateTime.now().toUtc()),
      ),
      mode: InsertMode.insertOrReplace,
    );

    // Give one of each harvester
    final inventoryItemsToSeed = [
      ('item.harvest_std_volcanic', 1),
      ('item.harvest_std_oceanic', 1),
      ('item.harvest_std_verdant', 1),
      ('item.harvest_std_earthen', 1),
      ('item.instant_hatch', 1), // Instant Fusion Extractor
      ('item.stamina_potion', 1), // Stamina Elixir
    ];

    for (final (key, qty) in inventoryItemsToSeed) {
      await into(
        inventoryItems,
      ).insert(InventoryItemsCompanion(key: Value(key), qty: Value(qty)));
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
}
