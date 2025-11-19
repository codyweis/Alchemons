// lib/database/schema_tables.dart
import 'package:drift/drift.dart';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/models/biome_farm_state.dart';

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

class InventoryItems extends Table {
  TextColumn get key => text()(); // e.g. 'item.instant_hatch'
  IntColumn get qty => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {key};
}

class ShopPurchases extends Table {
  TextColumn get offerId => text()();
  IntColumn get purchaseCount => integer().withDefault(const Constant(0))();
  IntColumn get lastPurchaseUtcMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {offerId};
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
  TextColumn get source => text().withDefault(const Constant('discovery'))();
  TextColumn get parentageJson => text().nullable()();
  TextColumn get geneticsJson => text().nullable()();
  TextColumn get likelihoodAnalysisJson => text().nullable()();
  IntColumn get staminaMax => integer().withDefault(const Constant(3))();
  IntColumn get staminaBars => integer().withDefault(const Constant(3))();
  IntColumn get staminaLastUtcMs => integer().withDefault(const Constant(0))();
  IntColumn get createdAtUtcMs => integer().withDefault(const Constant(0))();

  TextColumn get alchemyEffect => text().nullable()();

  // STAT COLUMNS
  RealColumn get statSpeed => real().withDefault(const Constant(3.0))();
  RealColumn get statIntelligence => real().withDefault(const Constant(3.0))();
  RealColumn get statStrength => real().withDefault(const Constant(3.0))();
  RealColumn get statBeauty => real().withDefault(const Constant(3.0))();

  // POTENTIAL COLUMNS (max each stat can reach)
  RealColumn get statSpeedPotential =>
      real().withDefault(const Constant(4.0))();
  RealColumn get statIntelligencePotential =>
      real().withDefault(const Constant(4.0))();
  RealColumn get statStrengthPotential =>
      real().withDefault(const Constant(4.0))();
  RealColumn get statBeautyPotential =>
      real().withDefault(const Constant(4.0))();

  IntColumn get generationDepth => integer().withDefault(const Constant(0))();

  // running tally of faction ancestry as JSON
  TextColumn get factionLineageJson => text().nullable()();

  // cosmetic variant pigment applied (like 'oceanic' tint on a volcanic body)
  TextColumn get variantFaction => text().nullable()();
  BoolColumn get isPure => boolean().withDefault(const Constant(false))();
  TextColumn get elementLineageJson => text().nullable()();
  TextColumn get familyLineageJson => text().nullable()();

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

/// Stores active wilderness spawns that persist across app restarts.
/// Each spawn is uniquely identified by sceneId + spawnPointId.
class ActiveSpawns extends Table {
  /// Composite primary key: "sceneId_spawnPointId"
  /// Example: "valley_spawn_1", "volcano_spawn_3"
  TextColumn get id => text()();

  /// The scene/biome where this spawn exists
  /// Example: "valley", "volcano", "sky", "swamp"
  TextColumn get sceneId => text()();

  /// The specific spawn point ID within the scene
  /// Example: "spawn_1", "spawn_2", etc.
  TextColumn get spawnPointId => text()();

  /// The species ID of the spawned creature
  /// Example: "aetherwing", "emberfox"
  TextColumn get speciesId => text()();

  /// The rarity of this encounter
  /// Values: "common", "uncommon", "rare", "epic", "legendary", "mythic"
  TextColumn get rarity => text()();

  /// When this spawn was created (UTC milliseconds)
  /// Used for potential future features like spawn expiry
  IntColumn get spawnedAtUtcMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tracks when user has entered a scene but hasn't left yet.
/// Single row table - only one scene can be active at a time.
/// Used to detect interrupted sessions and clear spawns on restart.
class ActiveSceneEntry extends Table {
  /// The scene ID the user is currently in
  /// Example: "valley", "volcano", "sky", "swamp"
  TextColumn get sceneId => text()();

  /// When the user entered this scene (UTC milliseconds)
  IntColumn get enteredAtUtcMs => integer()();

  @override
  Set<Column> get primaryKey => {sceneId};
}

// drift table suggestion
class SpawnSchedule extends Table {
  TextColumn get sceneId => text()(); // "valley", etc
  IntColumn get dueAtUtcMs => integer()(); // next spawn time
  @override
  Set<Column> get primaryKey => {sceneId};
}

// Tracks which notifications have been dismissed by the user
class NotificationDismissals extends Table {
  TextColumn get notificationType =>
      text()(); // e.g., 'eggReady', 'harvestReady'
  IntColumn get dismissedAtUtcMs => integer()(); // When it was dismissed

  @override
  Set<Column> get primaryKey => {notificationType};
}

class BreedingStatistics extends Table {
  TextColumn get speciesId => text()(); // e.g., "LET01"
  IntColumn get totalBred => integer().withDefault(const Constant(0))();
  IntColumn get lastMilestoneAwarded => integer().withDefault(
    const Constant(0),
  )(); // Last milestone number (1, 2, 3...)
  DateTimeColumn get lastBredAtUtc => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {speciesId};
}

/// Tracks which constellation skills have been unlocked
class ConstellationUnlocks extends Table {
  TextColumn get skillId => text()(); // e.g., "breeder_lineage_analyzer"
  DateTimeColumn get unlockedAtUtc => dateTime()();
  IntColumn get pointsCost => integer()(); // Historical record of what it cost

  @override
  Set<Column> get primaryKey => {skillId};
}

/// Tracks constellation point balance and history
class ConstellationPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get currentBalance => integer().withDefault(const Constant(0))();
  IntColumn get totalEarned => integer().withDefault(const Constant(0))();
  IntColumn get totalSpent => integer().withDefault(const Constant(0))();
  BoolColumn get hasSeenFinale =>
      boolean().withDefault(const Constant(false))(); // ADD THIS LINE
  DateTimeColumn get lastUpdatedUtc => dateTime()();
}

/// Optional: Detailed point transaction log for debugging/history
class ConstellationTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get transactionType =>
      text()(); // 'earned_breeding', 'earned_boss', 'spent_skill'
  IntColumn get amount => integer()(); // Positive for earn, negative for spend
  TextColumn get sourceId =>
      text().nullable()(); // Species ID or skill ID or boss ID
  TextColumn get description => text()(); // Human-readable description
  DateTimeColumn get createdAtUtc => dateTime()();
}
