// lib/database/daos/creature_dao.dart
import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/schema_tables.dart';
import 'package:alchemons/utils/instance_purity_util.dart';

part 'creature_dao.g.dart';

enum SortBy {
  newest,
  oldest,
  levelHigh,
  levelLow,
  statSpeed,
  statIntelligence,
  statStrength,
  statBeauty,
  potentialSpeed,
  potentialIntelligence,
  potentialStrength,
  potentialBeauty,
}

extension SortByX on SortBy {
  bool get isBaseStatSort => switch (this) {
    SortBy.statSpeed ||
    SortBy.statIntelligence ||
    SortBy.statStrength ||
    SortBy.statBeauty => true,
    _ => false,
  };

  bool get isPotentialSort => switch (this) {
    SortBy.potentialSpeed ||
    SortBy.potentialIntelligence ||
    SortBy.potentialStrength ||
    SortBy.potentialBeauty => true,
    _ => false,
  };

  bool get isStatSort => isBaseStatSort || isPotentialSort;

  String get shortLabel => switch (this) {
    SortBy.statSpeed => 'SPD',
    SortBy.statIntelligence => 'INT',
    SortBy.statStrength => 'STR',
    SortBy.statBeauty => 'BEA',
    SortBy.potentialSpeed => 'PSPD',
    SortBy.potentialIntelligence => 'PINT',
    SortBy.potentialStrength => 'PSTR',
    SortBy.potentialBeauty => 'PBEA',
    SortBy.levelHigh || SortBy.levelLow => 'LV',
    SortBy.newest => 'NEWEST',
    SortBy.oldest => 'OLDEST',
  };

  String? get statFamily => switch (this) {
    SortBy.statSpeed || SortBy.potentialSpeed => 'speed',
    SortBy.statIntelligence || SortBy.potentialIntelligence => 'intelligence',
    SortBy.statStrength || SortBy.potentialStrength => 'strength',
    SortBy.statBeauty || SortBy.potentialBeauty => 'beauty',
    _ => null,
  };

  double valueForInstance(CreatureInstance instance) => switch (this) {
    SortBy.statSpeed => instance.statSpeed,
    SortBy.statIntelligence => instance.statIntelligence,
    SortBy.statStrength => instance.statStrength,
    SortBy.statBeauty => instance.statBeauty,
    SortBy.potentialSpeed => instance.statSpeedPotential,
    SortBy.potentialIntelligence => instance.statIntelligencePotential,
    SortBy.potentialStrength => instance.statStrengthPotential,
    SortBy.potentialBeauty => instance.statBeautyPotential,
    _ => 0,
  };

  SortBy nextStatSort({required bool includePotential}) {
    final cycle = includePotential
        ? const [
            SortBy.statSpeed,
            SortBy.potentialSpeed,
            SortBy.statIntelligence,
            SortBy.potentialIntelligence,
            SortBy.statStrength,
            SortBy.potentialStrength,
            SortBy.statBeauty,
            SortBy.potentialBeauty,
          ]
        : const [
            SortBy.statSpeed,
            SortBy.statIntelligence,
            SortBy.statStrength,
            SortBy.statBeauty,
          ];
    final index = cycle.indexOf(this);
    if (index < 0) return cycle.first;
    return cycle[(index + 1) % cycle.length];
  }
}

@DriftAccessor(tables: [PlayerCreatures, CreatureInstances, FeedEvents])
class CreatureDao extends DatabaseAccessor<AlchemonsDatabase>
    with _$CreatureDaoMixin {
  CreatureDao(super.db);

  // Simple unique id for instances (local DB is fine with this)
  String makeInstanceId([String prefix = 'INS']) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final r = now ^ now.hashCode;
    return '${prefix}_${now}_${r & 0xFFFFFF}';
  }

  /// **NEW: Optimized filtered/sorted stream that runs in the database**
  Stream<List<CreatureInstance>> watchFilteredInstances({
    String? searchText,
    String? filterSize,
    String? filterTint,
    String? filterNature,
    bool filterPrismatic = false,
    String? filterVariant,
    bool filterFavoritesOnly = false,
    bool filterLockedOnly = false,
    SortBy sortBy = SortBy.newest,
  }) {
    // Start with base query
    var query = select(creatureInstances);

    // Apply filters at database level
    query = query
      ..where((t) {
        final conditions = <Expression<bool>>[];

        // Favorites filter
        if (filterFavoritesOnly) {
          conditions.add(t.isFavorite.equals(true));
        }

        if (filterLockedOnly) {
          conditions.add(t.locked.equals(true));
        }

        // Prismatic filter
        if (filterPrismatic) {
          conditions.add(t.isPrismaticSkin.equals(true));
        }

        // Nature filter
        if (filterNature != null && filterNature.isNotEmpty) {
          conditions.add(t.natureId.equals(filterNature));
        }

        // Variant filter
        if (filterVariant != null) {
          if (filterVariant == '__NON__') {
            conditions.add(t.variantFaction.isNull());
          } else {
            conditions.add(t.variantFaction.equals(filterVariant));
          }
        }

        // Search text - search in genetics JSON, nickname, instanceId
        if (searchText != null && searchText.trim().isNotEmpty) {
          final search = searchText.trim().toLowerCase();
          conditions.add(
            t.nickname.lower().like('%$search%') |
                t.instanceId.lower().like('%$search%') |
                t.geneticsJson.like('%$search%') |
                t.natureId.like('%$search%'),
          );
        }

        // Combine all conditions with AND
        if (conditions.isEmpty) {
          return const Constant(true);
        }
        return conditions.reduce((a, b) => a & b);
      });

    // Apply sorting at database level
    query = query
      ..orderBy([
        (t) {
          switch (sortBy) {
            case SortBy.newest:
              return OrderingTerm.desc(t.createdAtUtcMs);
            case SortBy.oldest:
              return OrderingTerm.asc(t.createdAtUtcMs);
            case SortBy.levelHigh:
              return OrderingTerm.desc(t.level);
            case SortBy.levelLow:
              return OrderingTerm.asc(t.level);
            case SortBy.statSpeed:
              return OrderingTerm.desc(t.statSpeed);
            case SortBy.statIntelligence:
              return OrderingTerm.desc(t.statIntelligence);
            case SortBy.statStrength:
              return OrderingTerm.desc(t.statStrength);
            case SortBy.statBeauty:
              return OrderingTerm.desc(t.statBeauty);
            case SortBy.potentialSpeed:
              return OrderingTerm.desc(t.statSpeedPotential);
            case SortBy.potentialIntelligence:
              return OrderingTerm.desc(t.statIntelligencePotential);
            case SortBy.potentialStrength:
              return OrderingTerm.desc(t.statStrengthPotential);
            case SortBy.potentialBeauty:
              return OrderingTerm.desc(t.statBeautyPotential);
          }
        },
      ]);

    return query.watch();
  }

  /// Inserts an instance using a *normalized* hatch payload (no override hoisting here).
  /// Returns the created instanceId, or `null` if species is full.
  Future<String?> insertInstanceFromHatchPayload({
    required String baseId,
    required Map<String, dynamic> payload,

    // Fallback lineage defaults (from caller, e.g. based on the offspring)
    required int fallbackGenerationDepth,
    required Map<String, int> fallbackFactionLineage,
    required Map<String, int> fallbackElementLineage,
    required Map<String, int> fallbackFamilyLineage,
    String? fallbackVariantFaction,
    bool fallbackIsPure = true,

    int cap = 100,
  }) async {
    // Enforce species cap
    if (!await canAddInstance(baseId, cap: cap)) {
      return null;
    }

    // Helpers
    double? asDouble(dynamic v) =>
        (v is num) ? v.toDouble() : double.tryParse('$v');
    int asInt(dynamic v, {int or = 0}) =>
        (v is num) ? v.toInt() : (int.tryParse('$v') ?? or);
    Map<String, int> normLineage(dynamic raw) {
      if (raw is! Map) return {};
      final out = <String, int>{};
      raw.forEach((k, v) {
        final n = asInt(v, or: 0);
        if (n > 0) out['$k'] = n;
      });
      return out;
    }

    // Extract payload shapes (already normalized/hoisted by the caller)
    final stats = (payload['stats'] is Map)
        ? Map<String, dynamic>.from(payload['stats'] as Map)
        : const {};
    final pots = (payload['statPotentials'] is Map)
        ? Map<String, dynamic>.from(payload['statPotentials'] as Map)
        : const {};
    final genetics = (payload['genetics'] is Map)
        ? Map<String, String>.from(
            (payload['genetics'] as Map).map((k, v) => MapEntry('$k', '$v')),
          )
        : null;

    // Lineage: prefer payload['lineage'] block; else accept flat fields; else fallback
    final lin = (payload['lineage'] is Map)
        ? Map<String, dynamic>.from(payload['lineage'] as Map)
        : payload;

    final generationDepth = asInt(
      lin['generationDepth'],
      or: fallbackGenerationDepth,
    );
    final factionLineage = normLineage(
      lin['factionLineage'] ?? fallbackFactionLineage,
    );
    final elementLineage = normLineage(
      lin['elementLineage'] ?? fallbackElementLineage,
    );
    final familyLineage = normLineage(
      lin['familyLineage'] ?? fallbackFamilyLineage,
    );

    final instanceId = makeInstanceId();

    await insertInstance(
      instanceId: instanceId,
      baseId: baseId,
      isPrismaticSkin: (payload['isPrismaticSkin'] as bool?) ?? false,
      natureId: payload['natureId'] as String?,
      source: (payload['source'] as String?) ?? 'discovery',
      genetics: genetics,
      likelihoodAnalysisJson: payload['likelihoodAnalysis'] as String?,

      // Stats (respect explicit values)
      statSpeed: asDouble(stats['speed']),
      statIntelligence: asDouble(stats['intelligence']),
      statStrength: asDouble(stats['strength']),
      statBeauty: asDouble(stats['beauty']),

      // Potentials
      statSpeedPotential: asDouble(pots['speed']),
      statIntelligencePotential: asDouble(pots['intelligence']),
      statStrengthPotential: asDouble(pots['strength']),
      statBeautyPotential: asDouble(pots['beauty']),

      // Lineage
      generationDepth: generationDepth,
      factionLineage: factionLineage.isNotEmpty
          ? factionLineage
          : fallbackFactionLineage,
      elementLineage: elementLineage.isNotEmpty
          ? elementLineage
          : fallbackElementLineage,
      familyLineage: familyLineage.isNotEmpty
          ? familyLineage
          : fallbackFamilyLineage,
      variantFaction:
          (lin['variantFaction'] as String?) ?? fallbackVariantFaction,
      isPure: (lin['isPure'] as bool?) ?? fallbackIsPure,
    );

    return instanceId;
  }

  // =================== POKEDEX ===================

  Future<void> addOrUpdateCreature(PlayerCreaturesCompanion entry) =>
      into(playerCreatures).insertOnConflictUpdate(entry);

  Future<PlayerCreature?> getCreature(String id) => (select(
    playerCreatures,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<PlayerCreature>> getAllCreatures() =>
      select(playerCreatures).get();

  Future<List<CreatureInstance>> getAllInstances() async {
    return await select(creatureInstances).get();
  }

  Future<List<CreatureInstance>> getInstancesForSpecies(
    String speciesId,
  ) async {
    return (select(
      creatureInstances,
    )..where((t) => t.baseId.equals(speciesId))).get();
  }

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

  /// Species (baseIds) that currently have ≥1 instance.
  Future<Set<String>> getSpeciesWithInstances() async {
    final rows =
        await (selectOnly(creatureInstances)
              ..addColumns([creatureInstances.baseId])
              ..groupBy([creatureInstances.baseId]))
            .get();

    return rows.map((r) => r.read<String>(creatureInstances.baseId)!).toSet();
  }

  /// Live stream of species that currently have ≥1 instance.
  /// (updates automatically when you add/sell instances)
  Stream<Set<String>> watchSpeciesWithInstances() {
    final q = (selectOnly(creatureInstances)
      ..addColumns([creatureInstances.baseId])
      ..groupBy([creatureInstances.baseId]));
    return q.watch().map(
      (rows) =>
          rows.map((r) => r.read<String>(creatureInstances.baseId)!).toSet(),
    );
  }

  /// Optional: counts per species if you want badges like "x3".
  Stream<Map<String, int>> watchInstanceCountsBySpecies() {
    final countExp = creatureInstances.instanceId.count();
    final q = (selectOnly(creatureInstances)
      ..addColumns([creatureInstances.baseId, countExp])
      ..groupBy([creatureInstances.baseId]));
    return q.watch().map((rows) {
      final m = <String, int>{};
      for (final r in rows) {
        final id = r.read<String>(creatureInstances.baseId)!;
        final n = r.read<int>(countExp) ?? 0;
        m[id] = n;
      }
      return m;
    });
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
    String source = 'discovery',
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
    double? statSpeedPotential,
    double? statIntelligencePotential,
    double? statStrengthPotential,
    double? statBeautyPotential,
    int generationDepth = 0,
    Map<String, int>? factionLineage,
    Map<String, int>? elementLineage,
    Map<String, int>? familyLineage,
    String? alchemyEffect,
    String? variantFaction,
    bool isPure = false,
  }) async {
    final nowMs =
        (createdAtUtc ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    final maxBars = staminaMax ?? 3;
    final curBars = staminaBars ?? maxBars;
    final effectiveElementLineage = elementLineage ?? const <String, int>{};
    final effectiveFamilyLineage = familyLineage ?? const <String, int>{};
    final purityStatus = classifyPurityFromLineages(
      elementLineage: effectiveElementLineage,
      speciesLineage: effectiveFamilyLineage,
    );
    final purityBonus = purityStatBonusForStatus(purityStatus);

    final effectiveSpeedPotential = statSpeedPotential ?? 4.0;
    final effectiveIntelligencePotential = statIntelligencePotential ?? 4.0;
    final effectiveStrengthPotential = statStrengthPotential ?? 4.0;
    final effectiveBeautyPotential = statBeautyPotential ?? 4.0;

    double applyBaseBonus(
      double? base,
      double potential,
      String statName,
      double fallback,
    ) {
      final boosted = (base ?? fallback) + purityBonus.forStat(statName);
      return min(boosted, potential).clamp(0.0, 5.0);
    }

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
        source: Value(source),
        parentageJson: Value(parentage == null ? null : jsonEncode(parentage)),
        geneticsJson: Value(genetics == null ? null : jsonEncode(genetics)),
        likelihoodAnalysisJson: Value(likelihoodAnalysisJson),
        staminaMax: Value(maxBars),
        staminaBars: Value(curBars),
        staminaLastUtcMs: Value(nowMs),
        createdAtUtcMs: Value(nowMs),
        statSpeed: Value(
          applyBaseBonus(statSpeed, effectiveSpeedPotential, 'speed', 3.0),
        ),
        statIntelligence: Value(
          applyBaseBonus(
            statIntelligence,
            effectiveIntelligencePotential,
            'intelligence',
            3.0,
          ),
        ),
        statStrength: Value(
          applyBaseBonus(
            statStrength,
            effectiveStrengthPotential,
            'strength',
            3.0,
          ),
        ),
        statBeauty: Value(
          applyBaseBonus(statBeauty, effectiveBeautyPotential, 'beauty', 3.0),
        ),
        statSpeedPotential: Value(effectiveSpeedPotential),
        statIntelligencePotential: Value(effectiveIntelligencePotential),
        statStrengthPotential: Value(effectiveStrengthPotential),
        statBeautyPotential: Value(effectiveBeautyPotential),
        generationDepth: Value(generationDepth),
        factionLineageJson: Value(
          factionLineage == null ? null : jsonEncode(factionLineage),
        ),
        variantFaction: Value(variantFaction),
        elementLineageJson: Value(
          elementLineage == null ? null : jsonEncode(elementLineage),
        ),
        familyLineageJson: Value(
          familyLineage == null ? null : jsonEncode(familyLineage),
        ),
        isPure: Value(isPure || purityStatus.isPure),
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

  Stream<CreatureInstance?> watchInstanceById(String instanceId) {
    final q = select(creatureInstances)
      ..where((t) => t.instanceId.equals(instanceId));
    return q.watchSingleOrNull();
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

  Future<void> setFavorite(String instanceId, bool favorite) async {
    await (update(
      creatureInstances,
    )..where((t) => t.instanceId.equals(instanceId))).write(
      CreatureInstancesCompanion(
        isFavorite: Value(favorite),
        locked: Value(favorite),
      ),
    );
  }

  /// Species (baseIds) that have at least one favorited instance.
  Future<Set<String>> getSpeciesWithFavorites() async {
    final rows =
        await (selectOnly(creatureInstances)
              ..addColumns([creatureInstances.baseId])
              ..where(creatureInstances.isFavorite.equals(true))
              ..groupBy([creatureInstances.baseId]))
            .get();
    return rows.map((r) => r.read<String>(creatureInstances.baseId)!).toSet();
  }

  Future<void> addXpAndMaybeLevel({
    required String instanceId,
    required int deltaXp,
    required int Function(int level) xpNeededForLevel,
    int maxLevel = 10,
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

  Future<void> updateAlchemyEffect({
    required String instanceId,
    String? effect,
  }) async {
    await (update(creatureInstances)
          ..where((t) => t.instanceId.equals(instanceId)))
        .write(CreatureInstancesCompanion(alchemyEffect: Value(effect)));
  }
}
