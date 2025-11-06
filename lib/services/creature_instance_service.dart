import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
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
  final AlchemonsDatabase _db;
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
      final canAdd = await _db.creatureDao.canAddInstance(
        baseId,
        cap: speciesCap,
      );
      if (!canAdd) {
        return InstanceFinalizeResult(InstanceFinalizeStatus.speciesFull);
      }

      final instanceId = _uuid.v4(); // ULID/UUID; v4 is fine here
      await _db.creatureDao.insertInstance(
        instanceId: instanceId,
        baseId: baseId,
        level: level,
        xp: 0,
        locked: false,
        nickname: nickname,
        isPrismaticSkin: isPrismaticSkin,
        natureId: natureId,
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

      return InstanceFinalizeResult(
        InstanceFinalizeStatus.created,
        instanceId: instanceId,
      );
    } catch (_) {
      return InstanceFinalizeResult(InstanceFinalizeStatus.failed);
    }
  }
}

class FeedResult {
  final bool ok;
  final int totalXpGained;
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

extension CreatureInstanceServiceFeeding on CreatureInstanceService {
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

    // NEW: Can't feed if already at max level
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

  /// XP curve for level cap 10
  static int xpNeededForLevel(int level) {
    // Tuned so ~100 level-1 creatures reaches level 10
    const base = 100.0;
    const growth = 1.25; // 25% per level
    return (base * pow(growth, max(0, level - 1))).round();
  }

  /// Computes XP provided by a single fodder instance.
  static int xpFromFodder({
    required db.CreatureInstance fodder,
    required CreatureCatalog repo,
  }) {
    // XP is based purely on the fodder's level, not rarity
    // Since you can only feed same-species anyway!
    const baseXp = 25.0;

    // Level factor: +10% per level beyond 1
    final levelFactor = 1.0 + 0.10 * (fodder.level - 1);

    // Prismatic bonus
    final prismaticMult = fodder.isPrismaticSkin ? 1.5 : 1.0;

    return (baseXp * levelFactor * prismaticMult).round();
  }

  /// Calculate stat gains from feeding WITH REDUCED SPECIALIZATION PRESSURE
  /// - Grants +0.1 to fodder's highest stat
  /// - Applies -0.01 penalty to target's lowest stat (much gentler)
  /// - Uses 0.01 increments for fine control
  static Map<String, double> calculateStatGains({
    required db.CreatureInstance target,
    required List<db.CreatureInstance> fodders,
  }) {
    final gains = <String, double>{
      'speed': 0.0,
      'intelligence': 0.0,
      'strength': 0.0,
      'beauty': 0.0,
    };

    // Current target stats for finding lowest
    var currentTargetStats = {
      'speed': target.statSpeed,
      'intelligence': target.statIntelligence,
      'strength': target.statStrength,
      'beauty': target.statBeauty,
    };

    for (final fodder in fodders) {
      // Find highest stat in this fodder
      final fodderStats = {
        'speed': fodder.statSpeed,
        'intelligence': fodder.statIntelligence,
        'strength': fodder.statStrength,
        'beauty': fodder.statBeauty,
      };

      String highestStatName = 'speed';
      double highestStatValue = fodder.statSpeed;

      fodderStats.forEach((name, value) {
        if (value > highestStatValue) {
          highestStatValue = value;
          highestStatName = name;
        }
      });

      // Always grant +0.1 to fodder's highest stat
      const double gain = 0.1;
      gains[highestStatName] = (gains[highestStatName] ?? 0) + gain;

      // REDUCED SPECIALIZATION PRESSURE: Find lowest stat and apply small penalty
      String lowestStatName = 'speed';
      double lowestStatValue = currentTargetStats['speed']!;

      currentTargetStats.forEach((name, value) {
        if (value < lowestStatValue) {
          lowestStatValue = value;
          lowestStatName = name;
        }
      });

      // Apply -0.01 penalty to lowest stat (much gentler than before)
      const double penalty = 0.01;
      gains[lowestStatName] = (gains[lowestStatName] ?? 0) - penalty;

      // Update current stats for next iteration (simulate the change)
      currentTargetStats[highestStatName] =
          (currentTargetStats[highestStatName]! + gain).clamp(0.0, 5.0);
      currentTargetStats[lowestStatName] =
          (currentTargetStats[lowestStatName]! - penalty).clamp(0.0, 5.0);
    }

    return gains;
  }

  Future<FeedResult> previewFeed({
    required String targetInstanceId,
    required List<String> fodderInstanceIds,
    required CreatureCatalog repo,
    int maxLevel = 10,
    bool strictSpecies = true,
  }) async {
    final target = await _db.creatureDao.getInstance(targetInstanceId);
    if (target == null) return FeedResult.fail('Target not found');

    final fodders = <db.CreatureInstance>[];
    for (final id in fodderInstanceIds) {
      final f = await _db.creatureDao.getInstance(id);
      if (f != null &&
          !f.locked &&
          canFeed(
            target: target,
            fodder: f,
            repo: repo,
            strictSpecies: strictSpecies,
          )) {
        fodders.add(f);
      }
    }
    if (fodders.isEmpty) return FeedResult.fail('No compatible fodder');

    final targetBase = repo.getCreatureById(target.baseId);
    final targetFamily = targetBase?.mutationFamily ?? 'Unknown';

    int totalXp = 0;
    for (final f in fodders) {
      final raw = xpFromFodder(fodder: f, repo: repo);
      final fb = repo.getCreatureById(f.baseId);
      final sameSpecies = (fb?.id == targetBase?.id);
      final sameFamily =
          !sameSpecies && (fb?.mutationFamily ?? '') == targetFamily;
      final mult = sameSpecies ? 1.25 : (sameFamily ? 1.10 : 1.0);
      totalXp += (raw * mult).round();
    }

    final statGains = calculateStatGains(target: target, fodders: fodders);

    final cappedGains = <String, double>{};
    cappedGains['speed'] = min(
      statGains['speed']!,
      target.statSpeedPotential - target.statSpeed,
    ).clamp(-10.0, 10.0);

    cappedGains['intelligence'] = min(
      statGains['intelligence']!,
      target.statIntelligencePotential - target.statIntelligence,
    ).clamp(-10.0, 10.0);

    cappedGains['strength'] = min(
      statGains['strength']!,
      target.statStrengthPotential - target.statStrength,
    ).clamp(-10.0, 10.0);

    cappedGains['beauty'] = min(
      statGains['beauty']!,
      target.statBeautyPotential - target.statBeauty,
    ).clamp(-10.0, 10.0);

    // Simulate level-ups
    int level = target.level;
    int xp = target.xp + totalXp;
    while (level < maxLevel && xp >= xpNeededForLevel(level)) {
      xp -= xpNeededForLevel(level);
      level++;
    }

    return FeedResult(
      ok: true,
      totalXpGained: totalXp,
      newLevel: level,
      newXpRemainder: xp,
      fodderConsumed: fodders.length,
      statGains: cappedGains,
    );
  }

  Future<FeedResult> feedInstances({
    required String targetInstanceId,
    required List<String> fodderInstanceIds,
    required CreatureCatalog repo,
    required FactionService factions,
    int maxLevel = 10,
    bool strictSpecies = true,
  }) async {
    final target = await _db.creatureDao.getInstance(targetInstanceId);
    if (target == null) return FeedResult.fail('Target not found');

    final fodders = <db.CreatureInstance>[];
    for (final id in fodderInstanceIds) {
      if (id == targetInstanceId) continue;
      final f = await _db.creatureDao.getInstance(id);
      if (f != null &&
          !f.locked &&
          canFeed(
            target: target,
            fodder: f,
            repo: repo,
            strictSpecies: strictSpecies,
          )) {
        fodders.add(f);
      }
    }
    if (fodders.isEmpty) return FeedResult.fail('No compatible fodder');

    final targetBase = repo.getCreatureById(target.baseId);
    final targetFamily = targetBase?.mutationFamily ?? 'Unknown';

    int totalXp = 0;
    for (final f in fodders) {
      final raw = xpFromFodder(fodder: f, repo: repo);
      final fb = repo.getCreatureById(f.baseId);
      final sameSpecies = (fb?.id == targetBase?.id);
      final sameFamily =
          !sameSpecies && (fb?.mutationFamily ?? '') == targetFamily;
      final mult = sameSpecies ? 1.25 : (sameFamily ? 1.10 : 1.0);
      totalXp += (raw * mult).round();
    }

    final n = target.natureId != null
        ? NatureCatalog.byId(target.natureId!)
        : null;
    final xpMult = (n?.effect['xp_gain_mult'])?.toDouble() ?? 1.0;
    final appliedXp =
        ((totalXp * xpMult) * factions.fireXpMultiplierOnLevelGain()).round();

    final statGains = calculateStatGains(target: target, fodders: fodders);

    final cappedGains = <String, double>{};
    cappedGains['speed'] = min(
      statGains['speed']!,
      target.statSpeedPotential - target.statSpeed,
    ).clamp(-10.0, 10.0);

    cappedGains['intelligence'] = min(
      statGains['intelligence']!,
      target.statIntelligencePotential - target.statIntelligence,
    ).clamp(-10.0, 10.0);

    cappedGains['strength'] = min(
      statGains['strength']!,
      target.statStrengthPotential - target.statStrength,
    ).clamp(-10.0, 10.0);

    cappedGains['beauty'] = min(
      statGains['beauty']!,
      target.statBeautyPotential - target.statBeauty,
    ).clamp(-10.0, 10.0);

    await _db.transaction(() async {
      await _db.creatureDao.addXpAndMaybeLevel(
        instanceId: target.instanceId,
        deltaXp: appliedXp,
        xpNeededForLevel: xpNeededForLevel,
        maxLevel: maxLevel,
      );

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

      for (final f in fodders) {
        await _db.creatureDao.logFeed(
          eventId:
              'feed_${DateTime.now().millisecondsSinceEpoch}_${f.instanceId}',
          targetInstanceId: target.instanceId,
          fodderInstanceId: f.instanceId,
          xpGained: xpFromFodder(fodder: f, repo: repo),
        );
      }
    });

    final updated = await _db.creatureDao.getInstance(target.instanceId);
    if (updated == null) {
      return FeedResult.fail('Target disappeared after feed');
    }

    return FeedResult(
      ok: true,
      totalXpGained: totalXp,
      newLevel: updated.level,
      newXpRemainder: updated.xp,
      fodderConsumed: fodders.length,
      statGains: cappedGains,
    );
  }
}
