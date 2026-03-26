import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:uuid/uuid.dart';

/// What to do when species cap is reached.
enum InstanceFinalizeStatus {
  created, // instance inserted
  speciesFull, // hit per-species cap; caller should ask player to Feed/Release
  failed, // any unexpected failure
}

class InstanceFinalizeResult {
  final InstanceFinalizeStatus status;
  final String? instanceId; // present when status==created
  InstanceFinalizeResult(this.status, {this.instanceId});
}

class CreatureInstanceService {
  final db.AlchemonsDatabase _db;
  final int speciesCap;
  final Uuid _uuid = const Uuid();

  CreatureInstanceService(this._db, {this.speciesCap = 100});

  /// Call this when an Egg finishes hatching or breeding returns a Creature.
  /// - baseId: the species/catalog id (e.g., "CR001")
  /// - natureId/genetics/parentage: serialized models from your breeding result
  Future<InstanceFinalizeResult> finalizeInstance({
    required String baseId,
    required String rarity, // optional to use for reward logic
    String? natureId,
    Map<String, String>? genetics, // track -> variantId
    Map<String, dynamic>? parentage, // Parentage.toJson()
    bool isPrismaticSkin = false,
    String? nickname,
    int level = 1,
    String? likelihoodAnalysisJson,
    String source = 'discovery',
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
    bool isPure = false,
    String? variantFaction,
    Map<String, int>? elementLineage,
    Map<String, int>? familyLineage,
  }) async {
    try {
      bool inserted = false;
      String? instanceId;

      // Wrap in a transaction to reduce (though not totally eliminate)
      // races around the per-species cap. True hard cap should be enforced
      // at the DB level with a constraint.
      await _db.transaction(() async {
        final canAdd = await _db.creatureDao.canAddInstance(
          baseId,
          cap: speciesCap,
        );
        if (!canAdd) {
          return; // species full; exit transaction without inserting
        }

        instanceId = _uuid.v4(); // ULID/UUID; v4 is fine here
        await _db.creatureDao.insertInstance(
          instanceId: instanceId!,
          baseId: baseId,
          level: level,
          xp: 0,
          locked: false,
          nickname: nickname,
          isPrismaticSkin: isPrismaticSkin,
          natureId: natureId,
          source: source,
          genetics: genetics,
          parentage: parentage,
          createdAtUtc: DateTime.now().toUtc(),
          likelihoodAnalysisJson: likelihoodAnalysisJson,
          statSpeed: statSpeed,
          statIntelligence: statIntelligence,
          statStrength: statStrength,
          statBeauty: statBeauty,
          statSpeedPotential: statSpeedPotential,
          statIntelligencePotential: statIntelligencePotential,
          statStrengthPotential: statStrengthPotential,
          statBeautyPotential: statBeautyPotential,
          generationDepth: generationDepth,
          factionLineage: factionLineage,
          variantFaction: variantFaction,
          isPure: isPure,
          elementLineage: elementLineage,
          familyLineage: familyLineage,
        );

        inserted = true;
      });

      if (!inserted) {
        return InstanceFinalizeResult(InstanceFinalizeStatus.speciesFull);
      }

      return InstanceFinalizeResult(
        InstanceFinalizeStatus.created,
        instanceId: instanceId,
      );
    } catch (e) {
      // TODO: log error + stack trace somewhere
      return InstanceFinalizeResult(InstanceFinalizeStatus.failed);
    }
  }
}

class FeedResult {
  final bool ok;
  final int totalXpGained; // AFTER nature/constellation multipliers
  final int newLevel;
  final int newXpRemainder; // xp into current level
  final int fodderConsumed;
  final String? error;
  final Map<String, double>? statGains;

  const FeedResult({
    required this.ok,
    required this.totalXpGained,
    required this.newLevel,
    required this.newXpRemainder,
    required this.fodderConsumed,
    this.error,
    this.statGains,
  });

  factory FeedResult.fail(String msg) => FeedResult(
    ok: false,
    totalXpGained: 0,
    newLevel: 0,
    newXpRemainder: 0,
    fodderConsumed: 0,
    error: msg,
    statGains: null,
  );
}

class EnhancementTransferProfile {
  final String highestStatName;
  final double highestStatValue;
  final String lowestStatName;
  final double lowestStatValue;

  const EnhancementTransferProfile({
    required this.highestStatName,
    required this.highestStatValue,
    required this.lowestStatName,
    required this.lowestStatValue,
  });
}

extension CreatureInstanceServiceFeeding on CreatureInstanceService {
  // ---------------------------------------------------------------------------
  // Feeding rules & XP helpers
  // ---------------------------------------------------------------------------

  static bool canFeed({
    required db.CreatureInstance target,
    required db.CreatureInstance fodder,
    required CreatureCatalog repo,
    bool strictSpecies = true,
    int maxLevel = 10,
  }) {
    final tb = repo.getCreatureById(target.baseId);
    final fb = repo.getCreatureById(fodder.baseId);
    if (tb == null || fb == null) return false;

    // Can't feed if already at max level
    if (target.level >= maxLevel) return false;

    if (strictSpecies) {
      return fb.id == tb.id;
    }

    final sameFamily = (fb.mutationFamily ?? '') == (tb.mutationFamily ?? '');
    final samePrimaryType = (fb.types.isNotEmpty && tb.types.isNotEmpty)
        ? fb.types.first == tb.types.first
        : false;
    return sameFamily && samePrimaryType;
  }

  /// XP curve for level cap 10.
  ///
  /// Front-loads progress through level 5, then steepens levels 6-10 while
  /// preserving the overall cost of 42 level-1 same-species fodders.
  static int xpNeededForLevel(int level) {
    const xpTable = <int>[42, 50, 60, 70, 130, 165, 205, 250, 318];
    final index = max(0, level - 1);
    if (index >= xpTable.length) {
      return xpTable.last;
    }
    return xpTable[index];
  }

  /// Computes XP provided by a single fodder instance (base, before species/family).
  static int xpFromFodder({
    required db.CreatureInstance fodder,
    required CreatureCatalog repo,
  }) {
    // XP is based purely on the fodder's level (and prismatic)
    const baseXp = 25.0;

    // Level factor: +200% per level beyond 1
    final levelFactor = 1.0 + 2 * (fodder.level - 1);

    // Prismatic bonus
    final prismaticMult = fodder.isPrismaticSkin ? 1.5 : 1.0;

    return (baseXp * levelFactor * prismaticMult).round();
  }

  /// Base XP for a single fodder AFTER same-species / same-family multipliers,
  /// but BEFORE nature / constellation multipliers.
  static int _baseXpForFodder({
    required db.CreatureInstance target,
    required db.CreatureInstance fodder,
    required CreatureCatalog repo,
  }) {
    final raw = xpFromFodder(fodder: fodder, repo: repo);

    final targetBase = repo.getCreatureById(target.baseId);
    final targetFamily = targetBase?.mutationFamily ?? 'Unknown';
    final fb = repo.getCreatureById(fodder.baseId);

    final sameSpecies = (fb?.id == targetBase?.id);
    final sameFamily =
        !sameSpecies && (fb?.mutationFamily ?? '') == targetFamily;

    final mult = sameSpecies ? 1.25 : (sameFamily ? 1.10 : 1.0);
    return (raw * mult).round();
  }

  /// Total base XP (after species/family) from all fodders.
  static int _computeBaseTotalXp({
    required db.CreatureInstance target,
    required List<db.CreatureInstance> fodders,
    required CreatureCatalog repo,
  }) {
    var total = 0;
    for (final f in fodders) {
      total += _baseXpForFodder(target: target, fodder: f, repo: repo);
    }
    return total;
  }

  /// Overall XP multiplier from nature + constellation.
  static double _computeXpMultiplier({
    required db.CreatureInstance target,
    ConstellationEffectsService? constellationEffects,
  }) {
    final n = target.natureId != null
        ? NatureCatalog.byId(target.natureId!)
        : null;
    final natureMult = (n?.effect['xp_gain_mult'])?.toDouble() ?? 1.0;
    final constellationMult =
        constellationEffects?.getXpBoostMultiplier() ?? 1.0;
    return natureMult * constellationMult;
  }

  static EnhancementTransferProfile analyzeEnhancementMaterial(
    db.CreatureInstance material,
  ) {
    final materialStats = {
      'speed': material.statSpeed,
      'intelligence': material.statIntelligence,
      'strength': material.statStrength,
      'beauty': material.statBeauty,
    };

    var highestStatName = 'speed';
    var highestStatValue = material.statSpeed;
    var lowestStatName = 'speed';
    var lowestStatValue = material.statSpeed;

    materialStats.forEach((name, value) {
      if (value > highestStatValue) {
        highestStatValue = value;
        highestStatName = name;
      }
      if (value < lowestStatValue) {
        lowestStatValue = value;
        lowestStatName = name;
      }
    });

    return EnhancementTransferProfile(
      highestStatName: highestStatName,
      highestStatValue: highestStatValue,
      lowestStatName: lowestStatName,
      lowestStatValue: lowestStatValue,
    );
  }

  /// Calculate stat gains from feeding.
  /// - Grants +0.1 to the sacrificed specimen's highest stat
  /// - Applies -0.01 to the sacrificed specimen's lowest stat
  /// - Uses 0.01 increments for fine control
  /// - CONSTELLATION BONUSES: add per-fodder bonuses
  /// - All stats & potentials are hard-capped in [0, 5].
  static Map<String, double> calculateStatGains({
    required db.CreatureInstance target,
    required List<db.CreatureInstance> fodders,
    ConstellationEffectsService? constellationEffects,
  }) {
    final gains = <String, double>{
      'speed': 0.0,
      'intelligence': 0.0,
      'strength': 0.0,
      'beauty': 0.0,
    };

    var currentTargetStats = {
      'speed': target.statSpeed,
      'intelligence': target.statIntelligence,
      'strength': target.statStrength,
      'beauty': target.statBeauty,
    };

    for (final fodder in fodders) {
      final profile = analyzeEnhancementMaterial(fodder);

      // Always grant +0.1 to fodder's highest stat
      const double gain = 0.1;
      gains[profile.highestStatName] =
          (gains[profile.highestStatName] ?? 0) + gain;

      // Apply -0.01 to the sacrificed specimen's lowest stat
      const double penalty = 0.01;
      gains[profile.lowestStatName] =
          (gains[profile.lowestStatName] ?? 0) - penalty;

      // Update current stats for next iteration (simulate the change)
      currentTargetStats[profile.highestStatName] =
          (currentTargetStats[profile.highestStatName]! + gain).clamp(0.0, 5.0);
      currentTargetStats[profile.lowestStatName] =
          (currentTargetStats[profile.lowestStatName]! - penalty).clamp(
            0.0,
            5.0,
          );
    }

    // Apply constellation bonuses
    if (constellationEffects != null) {
      // Each fodder consumed grants the constellation bonus
      final bonusPerFodder = {
        'speed': constellationEffects.getStatBoostMultiplier('speed'),
        'intelligence': constellationEffects.getStatBoostMultiplier(
          'intelligence',
        ),
        'strength': constellationEffects.getStatBoostMultiplier('strength'),
        'beauty': constellationEffects.getStatBoostMultiplier('beauty'),
      };

      bonusPerFodder.forEach((stat, bonus) {
        if (bonus > 0) {
          // Apply bonus per fodder consumed
          gains[stat] = (gains[stat] ?? 0) + (bonus * fodders.length);
        }
      });
    }

    return gains;
  }

  // ---------------------------------------------------------------------------
  // Preview feed
  // ---------------------------------------------------------------------------

  Future<FeedResult> previewFeed({
    required String targetInstanceId,
    required List<String> fodderInstanceIds,
    required CreatureCatalog repo,
    ConstellationEffectsService? constellationEffects,
    int maxLevel = 10,
    bool strictSpecies = true,
  }) async {
    final target = await _db.creatureDao.getInstance(targetInstanceId);
    if (target == null) return FeedResult.fail('Target not found');

    final fodders = <db.CreatureInstance>[];
    for (final id in fodderInstanceIds) {
      if (id == targetInstanceId) continue; // don't allow self as fodder
      final f = await _db.creatureDao.getInstance(id);
      if (f != null &&
          !f.locked &&
          canFeed(
            target: target,
            fodder: f,
            repo: repo,
            strictSpecies: strictSpecies,
            maxLevel: maxLevel,
          )) {
        fodders.add(f);
      }
    }
    if (fodders.isEmpty) {
      return FeedResult.fail('No compatible enhancement material');
    }

    // Base XP (after species/family)
    final baseTotalXp = _computeBaseTotalXp(
      target: target,
      fodders: fodders,
      repo: repo,
    );

    // Applied XP (after nature + constellation)
    final xpMult = _computeXpMultiplier(
      target: target,
      constellationEffects: constellationEffects,
    );
    final appliedXp = (baseTotalXp * xpMult).round();

    // Stat gains
    final statGains = calculateStatGains(
      target: target,
      fodders: fodders,
      constellationEffects: constellationEffects,
    );

    // Cap gains so we don't exceed potentials; potentials are 0–5.
    final cappedGains = <String, double>{};
    cappedGains['speed'] = min(
      statGains['speed'] ?? 0.0,
      target.statSpeedPotential - target.statSpeed,
    ).clamp(-10.0, 10.0);

    cappedGains['intelligence'] = min(
      statGains['intelligence'] ?? 0.0,
      target.statIntelligencePotential - target.statIntelligence,
    ).clamp(-10.0, 10.0);

    cappedGains['strength'] = min(
      statGains['strength'] ?? 0.0,
      target.statStrengthPotential - target.statStrength,
    ).clamp(-10.0, 10.0);

    cappedGains['beauty'] = min(
      statGains['beauty'] ?? 0.0,
      target.statBeautyPotential - target.statBeauty,
    ).clamp(-10.0, 10.0);

    // Simulate level-ups using APPLIED XP
    int level = target.level;
    int xp = target.xp + appliedXp;
    while (level < maxLevel && xp >= xpNeededForLevel(level)) {
      xp -= xpNeededForLevel(level);
      level++;
    }

    return FeedResult(
      ok: true,
      totalXpGained: appliedXp,
      newLevel: level,
      newXpRemainder: xp,
      fodderConsumed: fodders.length,
      statGains: cappedGains,
    );
  }

  // ---------------------------------------------------------------------------
  // Commit feed
  // ---------------------------------------------------------------------------

  Future<FeedResult> feedInstances({
    required String targetInstanceId,
    required List<String> fodderInstanceIds,
    required CreatureCatalog repo,
    ConstellationEffectsService? constellationEffects,
    int maxLevel = 10,
    bool strictSpecies = true,
  }) async {
    final target = await _db.creatureDao.getInstance(targetInstanceId);
    if (target == null) return FeedResult.fail('Target not found');

    final fodders = <db.CreatureInstance>[];
    for (final id in fodderInstanceIds) {
      if (id == targetInstanceId) continue; // don't allow self as fodder
      final f = await _db.creatureDao.getInstance(id);
      if (f != null &&
          !f.locked &&
          canFeed(
            target: target,
            fodder: f,
            repo: repo,
            strictSpecies: strictSpecies,
            maxLevel: maxLevel,
          )) {
        fodders.add(f);
      }
    }
    if (fodders.isEmpty) {
      return FeedResult.fail('No compatible enhancement material');
    }

    // Base XP (after species/family)
    final baseTotalXp = _computeBaseTotalXp(
      target: target,
      fodders: fodders,
      repo: repo,
    );

    // Applied XP (after nature + constellation)
    final xpMult = _computeXpMultiplier(
      target: target,
      constellationEffects: constellationEffects,
    );
    final appliedXp = (baseTotalXp * xpMult).round();

    // Stat gains
    final statGains = calculateStatGains(
      target: target,
      fodders: fodders,
      constellationEffects: constellationEffects,
    );

    final cappedGains = <String, double>{};
    cappedGains['speed'] = min(
      statGains['speed'] ?? 0.0,
      target.statSpeedPotential - target.statSpeed,
    ).clamp(-10.0, 10.0);

    cappedGains['intelligence'] = min(
      statGains['intelligence'] ?? 0.0,
      target.statIntelligencePotential - target.statIntelligence,
    ).clamp(-10.0, 10.0);

    cappedGains['strength'] = min(
      statGains['strength'] ?? 0.0,
      target.statStrengthPotential - target.statStrength,
    ).clamp(-10.0, 10.0);

    cappedGains['beauty'] = min(
      statGains['beauty'] ?? 0.0,
      target.statBeautyPotential - target.statBeauty,
    ).clamp(-10.0, 10.0);

    await _db.transaction(() async {
      // Apply XP & level ups using APPLIED XP
      await _db.creatureDao.addXpAndMaybeLevel(
        instanceId: target.instanceId,
        deltaXp: appliedXp,
        xpNeededForLevel: xpNeededForLevel,
        maxLevel: maxLevel,
      );

      // Apply stat gains; stats & potentials are 0–5, so clamp to potential.
      final newStats = {
        'speed': (target.statSpeed + cappedGains['speed']!).clamp(
          0.0,
          target.statSpeedPotential,
        ),
        'intelligence': (target.statIntelligence + cappedGains['intelligence']!)
            .clamp(0.0, target.statIntelligencePotential),
        'strength': (target.statStrength + cappedGains['strength']!).clamp(
          0.0,
          target.statStrengthPotential,
        ),
        'beauty': (target.statBeauty + cappedGains['beauty']!).clamp(
          0.0,
          target.statBeautyPotential,
        ),
      };

      await _db.creatureDao.updateStats(
        instanceId: target.instanceId,
        statSpeed: newStats['speed']!,
        statIntelligence: newStats['intelligence']!,
        statStrength: newStats['strength']!,
        statBeauty: newStats['beauty']!,
      );

      await _db.creatureDao.deleteInstances(
        fodders.map((e) => e.instanceId).toList(),
      );

      // Log base XP per fodder (after species/family) for analytics.
      for (final f in fodders) {
        final baseXpForThisFodder = _baseXpForFodder(
          target: target,
          fodder: f,
          repo: repo,
        );

        await _db.creatureDao.logFeed(
          eventId:
              'feed_${DateTime.now().millisecondsSinceEpoch}_${f.instanceId}',
          targetInstanceId: target.instanceId,
          fodderInstanceId: f.instanceId,
          xpGained: baseXpForThisFodder,
        );
      }
    });

    final updated = await _db.creatureDao.getInstance(target.instanceId);
    if (updated == null) {
      return FeedResult.fail('Target disappeared after feed');
    }

    return FeedResult(
      ok: true,
      totalXpGained: appliedXp,
      newLevel: updated.level,
      newXpRemainder: updated.xp,
      fodderConsumed: fodders.length,
      statGains: cappedGains,
    );
  }
}
