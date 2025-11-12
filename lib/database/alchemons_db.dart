// lib/database/alchemons_db.dart
import 'dart:convert';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/models/biome_farm_state.dart';
import 'package:drift/drift.dart';

// Schema and Model Imports
import 'package:alchemons/database/schema_tables.dart';
import 'package:alchemons/database/models/stored_theme_mode.dart';

// DAO Imports
import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/database/daos/currency_dao.dart';
import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/database/daos/incubator_dao.dart';
import 'package:alchemons/database/daos/inventory_dao.dart';
import 'package:alchemons/database/daos/biome_dao.dart';
import 'package:alchemons/database/daos/shop_dao.dart';

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
  ],
  daos: [
    SettingsDao,
    CurrencyDao,
    CreatureDao,
    IncubatorDao,
    InventoryDao,
    BiomeDao,
    ShopDao,
  ],
)
class AlchemonsDatabase extends _$AlchemonsDatabase {
  AlchemonsDatabase(super.e);

  @override
  int get schemaVersion => 27;

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

    await _setSetting('wallet_gold', '5');
    await _setSetting('wallet_silver', '100');

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
