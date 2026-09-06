import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/potential_soul.dart';
import 'package:alchemons/models/stat_system.dart';
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

  static Map<String, double> _deriveStats({
    required db.CreatureInstance instance,
    required CreatureCatalog repo,
    int? level,
    int? speedEnhancement,
    int? intelligenceEnhancement,
    int? strengthEnhancement,
    int? beautyEnhancement,
    num? speedPotential,
    num? intelligencePotential,
    num? strengthPotential,
    num? beautyPotential,
  }) {
    final species = repo.getCreatureById(instance.baseId);
    final base =
        species?.baseStats ??
        const SpeciesBaseStats(
          speed: 60,
          intelligence: 60,
          strength: 60,
          beauty: 60,
        );
    final resolvedLevel = level ?? instance.level;
    return {
      'speed': AlchemonStatSystem.effectiveInternal(
        speciesBase: base.speed,
        level: resolvedLevel,
        potential: speedPotential ?? instance.statSpeedPotential,
        enhancementRank: speedEnhancement ?? instance.statSpeedEnhancement,
        additionalMultiplier: AlchemonStatSystem.natureMultiplier(
          instance.natureId,
          'speed',
          instance.natureId2,
        ),
      ),
      'intelligence': AlchemonStatSystem.effectiveInternal(
        speciesBase: base.intelligence,
        level: resolvedLevel,
        potential: intelligencePotential ?? instance.statIntelligencePotential,
        enhancementRank:
            intelligenceEnhancement ?? instance.statIntelligenceEnhancement,
        additionalMultiplier: AlchemonStatSystem.natureMultiplier(
          instance.natureId,
          'intelligence',
          instance.natureId2,
        ),
      ),
      'strength': AlchemonStatSystem.effectiveInternal(
        speciesBase: base.strength,
        level: resolvedLevel,
        potential: strengthPotential ?? instance.statStrengthPotential,
        enhancementRank:
            strengthEnhancement ?? instance.statStrengthEnhancement,
        additionalMultiplier: AlchemonStatSystem.natureMultiplier(
          instance.natureId,
          'strength',
          instance.natureId2,
        ),
      ),
      'beauty': AlchemonStatSystem.effectiveInternal(
        speciesBase: base.beauty,
        level: resolvedLevel,
        potential: beautyPotential ?? instance.statBeautyPotential,
        enhancementRank: beautyEnhancement ?? instance.statBeautyEnhancement,
        additionalMultiplier: AlchemonStatSystem.natureMultiplier(
          instance.natureId,
          'beauty',
          instance.natureId2,
        ),
      ),
    };
  }

  /// Call this when an Egg finishes hatching or breeding returns a Creature.
  /// - baseId: the species/catalog id (e.g., "CR001")
  /// - natureId/genetics/parentage: serialized models from your breeding result
  Future<InstanceFinalizeResult> finalizeInstance({
    required String baseId,
    required String rarity, // optional to use for reward logic
    String? natureId,
    String? natureId2,
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
          natureId2: natureId2,
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

class PowerupApplyResult {
  final bool ok;
  final double delta;
  final double newValue;
  final String statKey;
  final double rolledDelta;
  final String rollLabel;
  final bool isRareRoll;
  final bool isJackpotRoll;
  final Duration animationDuration;
  final Duration flashDuration;
  final double glowBoost;
  final String? error;

  const PowerupApplyResult({
    required this.ok,
    required this.delta,
    required this.newValue,
    required this.statKey,
    required this.rolledDelta,
    required this.rollLabel,
    required this.isRareRoll,
    required this.isJackpotRoll,
    required this.animationDuration,
    required this.flashDuration,
    required this.glowBoost,
    this.error,
  });

  factory PowerupApplyResult.fail(String statKey, String message) =>
      PowerupApplyResult(
        ok: false,
        delta: 0,
        newValue: 0,
        statKey: statKey,
        rolledDelta: 0,
        rollLabel: 'FAILED ROLL',
        isRareRoll: false,
        isJackpotRoll: false,
        animationDuration: const Duration(milliseconds: 1500),
        flashDuration: const Duration(milliseconds: 500),
        glowBoost: 1.0,
        error: message,
      );
}

class PotentialSoulApplyResult {
  final bool ok;
  final String statKey;
  final int rolledGain;
  final int appliedGain;
  final int newPotential;
  final int silverCost;
  final String? error;

  const PotentialSoulApplyResult({
    required this.ok,
    required this.statKey,
    required this.rolledGain,
    required this.appliedGain,
    required this.newPotential,
    required this.silverCost,
    this.error,
  });

  factory PotentialSoulApplyResult.fail(String statKey, String message) =>
      PotentialSoulApplyResult(
        ok: false,
        statKey: statKey,
        rolledGain: 0,
        appliedGain: 0,
        newPotential: 0,
        silverCost: 0,
        error: message,
      );
}

class _PotentialSoulApplyAbort implements Exception {
  const _PotentialSoulApplyAbort(this.message);
  final String message;
}

extension CreatureInstanceServiceFeeding on CreatureInstanceService {
  static const Map<String, List<int>> _xpCurveByRarity = {
    'common': [20, 24, 28, 34, 60, 75, 95, 125, 159],
    'uncommon': [25, 30, 36, 42, 78, 99, 123, 150, 192],
    'rare': [30, 36, 43, 51, 93, 118, 147, 180, 232],
    'legendary': [40, 48, 58, 67, 125, 160, 200, 245, 297],
    'epic': [35, 42, 50, 58, 108, 137, 171, 209, 270],
    'mythic': [45, 54, 65, 76, 141, 180, 225, 276, 338],
  };

  static String normalizeRarity(String? rarity) {
    final trimmed = rarity?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'common';
    return trimmed.toLowerCase();
  }

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
  /// Front-loads progress through level 5, then steepens levels 6-10 with
  /// rarity-specific totals so common breeders are much easier to raise.
  static int xpNeededForLevel(int level, {String rarity = 'Common'}) {
    final xpTable =
        _xpCurveByRarity[normalizeRarity(rarity)] ??
        _xpCurveByRarity['common']!;
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
    var natureMult = 1.0;
    for (final id in [target.natureId, target.natureId2]) {
      if (id == null || id.isEmpty) continue;
      natureMult *=
          NatureCatalog.byId(
            id,
          )?.effect.getDouble('xp_gain_mult', fallback: 1) ??
          1;
    }
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

  /// Feeding now grants XP only. Effective stats are derived from species,
  /// level, Potential, and Enhancement after the level change.
  static Map<String, double> calculateStatGains({
    required db.CreatureInstance target,
    required List<db.CreatureInstance> fodders,
    ConstellationEffectsService? constellationEffects,
  }) => const {
    'speed': 0.0,
    'intelligence': 0.0,
    'strength': 0.0,
    'beauty': 0.0,
  };

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

    const cappedGains = <String, double>{
      'speed': 0.0,
      'intelligence': 0.0,
      'strength': 0.0,
      'beauty': 0.0,
    };

    // Simulate level-ups using APPLIED XP
    final targetBase = repo.getCreatureById(target.baseId);
    final targetRarity = targetBase?.rarity ?? 'Common';
    int level = target.level;
    int xp = target.xp + appliedXp;
    while (level < maxLevel &&
        xp >= xpNeededForLevel(level, rarity: targetRarity)) {
      xp -= xpNeededForLevel(level, rarity: targetRarity);
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

    const cappedGains = <String, double>{
      'speed': 0.0,
      'intelligence': 0.0,
      'strength': 0.0,
      'beauty': 0.0,
    };

    await _db.transaction(() async {
      final targetBase = repo.getCreatureById(target.baseId);
      final targetRarity = targetBase?.rarity ?? 'Common';

      // Apply XP & level ups using APPLIED XP
      await _db.creatureDao.addXpAndMaybeLevel(
        instanceId: target.instanceId,
        deltaXp: appliedXp,
        xpNeededForLevel: (level) =>
            xpNeededForLevel(level, rarity: targetRarity),
        maxLevel: maxLevel,
      );

      final leveled = await _db.creatureDao.getInstance(target.instanceId);
      if (leveled != null) {
        final derived = CreatureInstanceService._deriveStats(
          instance: leveled,
          repo: repo,
        );
        await _db.creatureDao.updateStats(
          instanceId: leveled.instanceId,
          statSpeed: derived['speed']!,
          statIntelligence: derived['intelligence']!,
          statStrength: derived['strength']!,
          statBeauty: derived['beauty']!,
        );
      }

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

  Future<PowerupApplyResult> applyAlchemicalPowerup({
    required String targetInstanceId,
    required AlchemicalPowerupType powerup,
    required CreatureCatalog repo,
  }) async {
    final target = await _db.creatureDao.getInstance(targetInstanceId);
    if (target == null) {
      return PowerupApplyResult.fail(powerup.statKey, 'Target not found');
    }
    if (target.level < AlchemonStatSystem.maxLevel) {
      return PowerupApplyResult.fail(
        powerup.statKey,
        'Reach level ${AlchemonStatSystem.maxLevel} before enhancing stats.',
      );
    }

    final currentRank = switch (powerup) {
      AlchemicalPowerupType.speed => target.statSpeedEnhancement,
      AlchemicalPowerupType.intelligence => target.statIntelligenceEnhancement,
      AlchemicalPowerupType.strength => target.statStrengthEnhancement,
      AlchemicalPowerupType.beauty => target.statBeautyEnhancement,
    };
    if (currentRank >= AlchemonStatSystem.maxEnhancementRank) {
      return PowerupApplyResult.fail(
        powerup.statKey,
        '${powerup.name} is already fully enhanced.',
      );
    }

    final cost = AlchemonStatSystem.orbCostForNextRank(currentRank);
    final nextRank = currentRank + 1;
    final speedRank = powerup == AlchemicalPowerupType.speed
        ? nextRank
        : target.statSpeedEnhancement;
    final intelligenceRank = powerup == AlchemicalPowerupType.intelligence
        ? nextRank
        : target.statIntelligenceEnhancement;
    final strengthRank = powerup == AlchemicalPowerupType.strength
        ? nextRank
        : target.statStrengthEnhancement;
    final beautyRank = powerup == AlchemicalPowerupType.beauty
        ? nextRank
        : target.statBeautyEnhancement;
    final derived = CreatureInstanceService._deriveStats(
      instance: target,
      repo: repo,
      speedEnhancement: speedRank,
      intelligenceEnhancement: intelligenceRank,
      strengthEnhancement: strengthRank,
      beautyEnhancement: beautyRank,
    );
    final hadItem = await _db.transaction(() async {
      final consumed = await _db.inventoryDao.consumeItem(
        powerup.inventoryKey,
        qty: cost,
      );
      if (!consumed) return false;
      await _db.creatureDao.updateStatProgression(
        instanceId: target.instanceId,
        statSpeed: derived['speed']!,
        statIntelligence: derived['intelligence']!,
        statStrength: derived['strength']!,
        statBeauty: derived['beauty']!,
        statSpeedEnhancement: speedRank,
        statIntelligenceEnhancement: intelligenceRank,
        statStrengthEnhancement: strengthRank,
        statBeautyEnhancement: beautyRank,
      );
      return true;
    });
    if (!hadItem) {
      return PowerupApplyResult.fail(
        powerup.statKey,
        'Rank $nextRank requires $cost ${powerup.name}${cost == 1 ? '' : 's'}.',
      );
    }

    final newValue = derived[powerup.statKey]!;

    return PowerupApplyResult(
      ok: true,
      delta: 3.0,
      newValue: newValue,
      statKey: powerup.statKey,
      rolledDelta: 3.0,
      rollLabel: 'ENHANCED $nextRank/10',
      isRareRoll: false,
      isJackpotRoll: nextRank == AlchemonStatSystem.maxEnhancementRank,
      animationDuration: const Duration(milliseconds: 1500),
      flashDuration: const Duration(milliseconds: 500),
      glowBoost: nextRank == AlchemonStatSystem.maxEnhancementRank ? 1.5 : 1.0,
    );
  }

  Future<PotentialSoulApplyResult> applyPotentialSoul({
    required String targetInstanceId,
    required AlchemicalPowerupType stat,
    required CreatureCatalog repo,
    Random? random,
  }) async {
    final target = await _db.creatureDao.getInstance(targetInstanceId);
    if (target == null) {
      return PotentialSoulApplyResult.fail(stat.statKey, 'Target not found');
    }

    final currentPotential = switch (stat) {
      AlchemicalPowerupType.speed => target.statSpeedPotential.round(),
      AlchemicalPowerupType.intelligence =>
        target.statIntelligencePotential.round(),
      AlchemicalPowerupType.strength => target.statStrengthPotential.round(),
      AlchemicalPowerupType.beauty => target.statBeautyPotential.round(),
    };
    if (currentPotential >= AlchemonStatSystem.maxPotential) {
      return PotentialSoulApplyResult.fail(
        stat.statKey,
        '${stat.statKey} Potential is already 100.',
      );
    }

    final silverCost = AlchemonStatSystem.potentialSoulSilverCost(
      currentPotential,
    );
    if (await _db.inventoryDao.getItemQty(InvKeys.potentialSoul) < 1) {
      return PotentialSoulApplyResult.fail(
        stat.statKey,
        'A Potential Soul is required.',
      );
    }
    final silverBalance = await _db.currencyDao.getSilverBalance();
    if (silverBalance < silverCost) {
      return PotentialSoulApplyResult.fail(
        stat.statKey,
        '$silverCost Silver is required for this Potential infusion.',
      );
    }

    final rolledGain = PotentialSoulRules.rollGain(random ?? Random());
    final newPotential = min(
      AlchemonStatSystem.maxPotential,
      currentPotential + rolledGain,
    );
    final appliedGain = newPotential - currentPotential;
    final speedPotential = stat == AlchemicalPowerupType.speed
        ? newPotential.toDouble()
        : target.statSpeedPotential;
    final intelligencePotential = stat == AlchemicalPowerupType.intelligence
        ? newPotential.toDouble()
        : target.statIntelligencePotential;
    final strengthPotential = stat == AlchemicalPowerupType.strength
        ? newPotential.toDouble()
        : target.statStrengthPotential;
    final beautyPotential = stat == AlchemicalPowerupType.beauty
        ? newPotential.toDouble()
        : target.statBeautyPotential;
    final derived = CreatureInstanceService._deriveStats(
      instance: target,
      repo: repo,
      speedPotential: speedPotential,
      intelligencePotential: intelligencePotential,
      strengthPotential: strengthPotential,
      beautyPotential: beautyPotential,
    );

    try {
      await _db.transaction(() async {
        final consumed = await _db.inventoryDao.consumeItem(
          InvKeys.potentialSoul,
          qty: 1,
        );
        if (!consumed) {
          throw const _PotentialSoulApplyAbort('A Potential Soul is required.');
        }
        final paid = await _db.currencyDao.spendSilver(silverCost);
        if (!paid) {
          throw _PotentialSoulApplyAbort(
            '$silverCost Silver is required for this Potential infusion.',
          );
        }
        await _db.creatureDao.updatePotentialProgression(
          instanceId: target.instanceId,
          statSpeed: derived['speed']!,
          statIntelligence: derived['intelligence']!,
          statStrength: derived['strength']!,
          statBeauty: derived['beauty']!,
          statSpeedPotential: speedPotential,
          statIntelligencePotential: intelligencePotential,
          statStrengthPotential: strengthPotential,
          statBeautyPotential: beautyPotential,
        );
      });
    } on _PotentialSoulApplyAbort catch (failure) {
      return PotentialSoulApplyResult.fail(stat.statKey, failure.message);
    }

    return PotentialSoulApplyResult(
      ok: true,
      statKey: stat.statKey,
      rolledGain: rolledGain,
      appliedGain: appliedGain,
      newPotential: newPotential,
      silverCost: silverCost,
    );
  }
}
