import 'dart:async';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:drift/drift.dart';
import '../database/alchemons_db.dart';
import '../models/creature.dart';

class CreatureEntry {
  final Creature creature;
  final PlayerCreature player;
  const CreatureEntry({required this.creature, required this.player});
}

extension _PlayerRowsLookup on List<PlayerCreature> {
  PlayerCreature byIdOrDefault(String id) => firstWhere(
    (p) => p.id == id,
    orElse: () => PlayerCreature(id: id, discovered: false),
  );
}

class GameDataService {
  final AlchemonsDatabase db;
  final CreatureCatalog catalog;

  /// Optional: discovered variant species that aren’t in the base catalog yet.
  /// Persist later via a Drift table if you need them across restarts.
  final List<Creature> _discoveredVariants = [];

  bool _initialized = false;
  bool get isInitialized => _initialized;

  GameDataService({required this.db, required this.catalog});

  /// Call after catalog.load().
  Future<void> init() async {
    if (_initialized) return;
    if (!catalog.isLoaded) {
      throw StateError('CreatureCatalog must be loaded before init().');
    }

    // Ensure a row exists for each catalog species.
    for (final c in catalog.creatures) {
      final existing = await db.creatureDao.getCreature(c.id);
      if (existing == null) {
        await db.creatureDao.addOrUpdateCreature(
          PlayerCreaturesCompanion.insert(id: c.id),
        );
      }
    }

    // Reconcile old saves and any instances created by legacy paths with the
    // canonical Base × Level × Potential × Enhancement × Nature formula.
    // This is idempotent and only writes rows whose cached combat values differ.
    await _reconcileInstanceStats();

    _initialized = true;
  }

  Future<void> _reconcileInstanceStats() async {
    final instances = await db.creatureDao.listAllInstances();
    await db.transaction(() async {
      for (final instance in instances) {
        final species = catalog.getCreatureById(instance.baseId);
        final base =
            species?.baseStats ??
            const SpeciesBaseStats(
              speed: 60,
              intelligence: 60,
              strength: 60,
              beauty: 60,
            );

        double derive(int speciesBase, num potential, int rank, String key) =>
            AlchemonStatSystem.effectiveInternal(
              speciesBase: speciesBase,
              level: instance.level,
              potential: potential,
              enhancementRank: rank,
              additionalMultiplier: AlchemonStatSystem.natureMultiplier(
                instance.natureId,
                key,
                instance.natureId2,
              ),
            );

        final speed = derive(
          base.speed,
          instance.statSpeedPotential,
          instance.statSpeedEnhancement,
          'speed',
        );
        final intelligence = derive(
          base.intelligence,
          instance.statIntelligencePotential,
          instance.statIntelligenceEnhancement,
          'intelligence',
        );
        final strength = derive(
          base.strength,
          instance.statStrengthPotential,
          instance.statStrengthEnhancement,
          'strength',
        );
        final beauty = derive(
          base.beauty,
          instance.statBeautyPotential,
          instance.statBeautyEnhancement,
          'beauty',
        );

        bool differs(double left, double right) => (left - right).abs() > 1e-9;
        if (differs(instance.statSpeed, speed) ||
            differs(instance.statIntelligence, intelligence) ||
            differs(instance.statStrength, strength) ||
            differs(instance.statBeauty, beauty)) {
          await db.creatureDao.updateStats(
            instanceId: instance.instanceId,
            statSpeed: speed,
            statIntelligence: intelligence,
            statStrength: strength,
            statBeauty: beauty,
          );
        }
      }
    });
  }

  // ----------------------------
  // Read models
  // ----------------------------

  List<Creature> get _allCreatures => [
    ...catalog.creatures,
    ..._discoveredVariants,
  ];

  /// Live stream of all entries (base + variants) joined with player rows.
  Stream<List<CreatureEntry>> watchAllEntries() {
    return db.creatureDao.watchAllCreatures().map((playerRows) {
      return _allCreatures
          .map(
            (c) => CreatureEntry(
              creature: c,
              player: playerRows.byIdOrDefault(c.id),
            ),
          )
          .toList(growable: false);
    });
  }

  /// Live stream filtered to discovered entries only.
  Stream<List<CreatureEntry>> watchDiscoveredEntries() => watchAllEntries().map(
    (list) => list.where((e) => e.player.discovered).toList(growable: false),
  );

  /// One-shot stats (if you prefer a stream, map from watchAllEntries()).
  Future<Map<String, int>> getDiscoveryStats() async {
    final playerData = await db.creatureDao.getAllCreatures();
    final discoveredCount = playerData.where((p) => p.discovered).length;
    final total = _allCreatures.length;
    final pct = total == 0 ? 0 : ((discoveredCount * 100) / total).round();
    return {'discovered': discoveredCount, 'total': total, 'percentage': pct};
  }

  // ----------------------------
  // Queries / helpers
  // ----------------------------

  Creature? getCreatureById(String id) =>
      catalog.getCreatureById(id) ??
      _discoveredVariants.firstWhereOrNull((c) => c.id == id);

  List<Creature> getCreaturesByType(String type) => _allCreatures
      .where((c) => c.types.contains(type))
      .toList(growable: false);

  List<Creature> get baseCreatures => catalog.creatures;
  List<Creature> get discoveredVariants =>
      List.unmodifiable(_discoveredVariants);
  List<Creature> get allCreaturesIncludingVariants =>
      List.unmodifiable(_allCreatures);

  // ----------------------------
  // Mutations
  // ----------------------------

  Future<void> markDiscovered(String id) async {
    await db.creatureDao.addOrUpdateCreature(
      PlayerCreaturesCompanion(id: Value(id), discovered: const Value(true)),
    );
  }

  Future<void> markMultipleDiscovered(List<String> ids) async {
    if (ids.isEmpty) return;
    await db.transaction(() async {
      for (final id in ids) {
        await db.creatureDao.addOrUpdateCreature(
          PlayerCreaturesCompanion(
            id: Value(id),
            discovered: const Value(true),
          ),
        );
      }
    });
  }

  /// Resets the discovered flag for all known species (base + variants).
  Future<void> resetDiscoveryProgress() async {
    await db.transaction(() async {
      for (final c in _allCreatures) {
        await db.creatureDao.addOrUpdateCreature(
          PlayerCreaturesCompanion(
            id: Value(c.id),
            discovered: const Value(false),
          ),
        );
      }
    });
    _discoveredVariants.clear();
  }

  // ----------------------------
  // Variant management (optional)
  // ----------------------------

  /// Adds a variant species to the in-memory list (not persisted).
  void addDiscoveredVariant(Creature variant) {
    if (_discoveredVariants.any((c) => c.id == variant.id)) return;
    _discoveredVariants.add(variant);
    // UI will reflect this as soon as the next db change or on a manual refresh.
    // If you want an immediate push without a DB write, expose a dedicated
    // BehaviorSubject/StreamController and rebuild off that instead.
  }
}
