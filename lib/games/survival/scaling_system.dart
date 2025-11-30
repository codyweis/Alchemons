import 'dart:math';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_enemies.dart';

/// Scaling tuned to guardian stat progression:
/// Wave 10: 4x Lv10 @ 2.5 stats
/// Wave 20: 4x Lv10 @ 3.0 stats
/// Wave 30: 4x Lv10 @ 3.5 stats
/// Wave 40+: 4x Lv10 @ 4.0+ stats
class ImprovedScalingSystem {
  static const double _baseEnemyHpScale = 0.6;
  static const double _baseEnemyDmgScale = 1.0;
  static const double _baseShooterDmgScale = 0.4;
  static const double _baseGuardianHpScale = 1.0;
  static const double _baseGuardianDmgScale = 1.0;

  // ============================================================================
  // ENEMY SCALING
  // ============================================================================

  static SurvivalUnit buildScaledEnemy({
    required SurvivalEnemyTemplate template,
    required int tier,
    required int wave,
    bool isShooter = false,
  }) {
    final baseLevel = _getEnemyLevel(tier, wave);
    final baseStats = _getEnemyBaseStats(tier);

    final unit = SurvivalUnit(
      id: '${template.id}_${DateTime.now().microsecondsSinceEpoch}',
      name: template.name,
      types: [template.element],
      family: template.creatureFamily.name,
      statSpeed: baseStats['speed']!.clamp(0.0, 5.0),
      statIntelligence: baseStats['intelligence']!.clamp(0.0, 5.0),
      statStrength: baseStats['strength']!.clamp(0.0, 5.0),
      statBeauty: baseStats['beauty']!.clamp(0.0, 5.0),
      level: baseLevel,
    );

    final enemyTier = template.tier;
    unit.maxHp = (unit.maxHp * enemyTier.hpMultiplier * _baseEnemyHpScale)
        .round();
    unit.currentHp = unit.maxHp;

    final dmgScale = isShooter ? _baseShooterDmgScale : _baseEnemyDmgScale;
    unit.physAtk = (unit.physAtk * enemyTier.statMultiplier * dmgScale).round();
    unit.elemAtk = (unit.elemAtk * enemyTier.statMultiplier * dmgScale).round();

    final scaledStats = _applyWaveScaling(
      hp: unit.maxHp,
      physAtk: unit.physAtk,
      elemAtk: unit.elemAtk,
      tier: tier,
      wave: wave,
    );

    unit.maxHp = scaledStats['hp']!;
    unit.currentHp = unit.maxHp;
    unit.physAtk = scaledStats['physAtk']!;
    unit.elemAtk = scaledStats['elemAtk']!;

    return unit;
  }

  /// Build a mini-boss (wave 5, 15, 25...)
  /// Should be challenging but beatable in ~8-12 seconds
  static SurvivalUnit buildMiniBoss({
    required SurvivalEnemyTemplate template,
    required int wave,
  }) {
    final unit = buildScaledEnemy(
      template: template,
      tier: template.tier.tier,
      wave: wave,
    );

    // Mini-boss multipliers scale with wave
    final waveBlock = (wave / 10).floor();
    final hpMult = 10 + waveBlock * 0.4;
    final dmgMult = 1.2 + waveBlock * 0.08;

    unit.maxHp = (unit.maxHp * hpMult).round();
    unit.currentHp = unit.maxHp;
    unit.physAtk = (unit.physAtk * dmgMult).round();
    unit.elemAtk = (unit.elemAtk * dmgMult).round();

    return unit;
  }

  /// Build a mega-boss (wave 10, 20, 30...)
  /// Balanced against expected guardian stats at that wave
  static SurvivalUnit buildMegaBoss({
    required SurvivalEnemyTemplate template,
    required int wave,
  }) {
    final unit = buildScaledEnemy(
      template: template,
      tier: template.tier.tier,
      wave: wave,
    );

    final expectedStats = 2.5 + ((wave - 10) / 20).clamp(0.0, 2.0);
    final expectedGuardianDps = _estimateGuardianDps(expectedStats);
    final totalPartyDps = expectedGuardianDps * 4;

    final targetFightDuration = 16.0 + (wave / 25);
    var targetHp = (totalPartyDps * targetFightDuration).round();

    // 🔧 NEW: toughness factor (try 2.0–3.0)
    const toughnessFactor = 3;
    targetHp = (targetHp * toughnessFactor).round();

    unit.maxHp = targetHp.clamp(2000, 80000);
    unit.currentHp = unit.maxHp;

    final expectedGuardianHp = 180 + expectedStats * 40;
    final targetBossDps = expectedGuardianHp / 12;

    final bossAttackInterval = 2.0;
    final damagePerHit = (targetBossDps * bossAttackInterval).round();
    unit.physAtk = damagePerHit.clamp(15, 180);
    unit.elemAtk = (damagePerHit * 0.7).round().clamp(10, 130);

    return unit;
  }

  static double _estimateGuardianDps(double avgStats) {
    final estimatedAtk = avgStats * 12 + 30;
    final attacksPerSecond = 0.7;
    return estimatedAtk * attacksPerSecond;
  }

  static int _getEnemyLevel(int tier, int wave) {
    switch (tier) {
      case 1:
        return max(1, 1 + wave ~/ 6);
      case 2:
        return max(2, 2 + wave ~/ 5);
      case 3:
        return max(4, 4 + wave ~/ 4);
      case 4:
        return max(6, 6 + wave ~/ 3);
      case 5:
        return max(8, 8 + wave ~/ 3);
      default:
        return 1;
    }
  }

  static Map<String, double> _getEnemyBaseStats(int tier) {
    final rng = Random();

    switch (tier) {
      case 1:
        return {
          'speed': 0.5 + rng.nextDouble() * 0.3,
          'intelligence': 0.3 + rng.nextDouble() * 0.2,
          'strength': 0.4 + rng.nextDouble() * 0.3,
          'beauty': 0.3 + rng.nextDouble() * 0.2,
        };
      case 2:
        return {
          'speed': 0.7 + rng.nextDouble() * 0.4,
          'intelligence': 0.5 + rng.nextDouble() * 0.3,
          'strength': 0.8 + rng.nextDouble() * 0.4,
          'beauty': 0.5 + rng.nextDouble() * 0.3,
        };
      case 3:
        return {
          'speed': 1.0 + rng.nextDouble() * 0.4,
          'intelligence': 0.8 + rng.nextDouble() * 0.4,
          'strength': 1.2 + rng.nextDouble() * 0.4,
          'beauty': 0.8 + rng.nextDouble() * 0.4,
        };
      case 4:
        return {
          'speed': 1.3 + rng.nextDouble() * 0.4,
          'intelligence': 1.1 + rng.nextDouble() * 0.4,
          'strength': 1.5 + rng.nextDouble() * 0.4,
          'beauty': 1.1 + rng.nextDouble() * 0.4,
        };
      case 5:
        return {
          'speed': 1.6 + rng.nextDouble() * 0.4,
          'intelligence': 1.4 + rng.nextDouble() * 0.4,
          'strength': 1.8 + rng.nextDouble() * 0.4,
          'beauty': 1.4 + rng.nextDouble() * 0.4,
        };
      default:
        return {
          'speed': 1.0,
          'intelligence': 1.0,
          'strength': 1.0,
          'beauty': 1.0,
        };
    }
  }

  static Map<String, int> _applyWaveScaling({
    required int hp,
    required int physAtk,
    required int elemAtk,
    required int tier,
    required int wave,
  }) {
    double waveProgress = (wave / 100.0).clamp(0.0, 1.0);
    double hpScale = 1.0 + (waveProgress * 0.6);
    double dmgScale = 1.0 + (waveProgress * 0.3);

    final tierBonus = (tier - 1) * 0.04;
    hpScale *= (1.0 + tierBonus);
    dmgScale *= (1.0 + tierBonus * 0.5);

    return {
      'hp': (hp * hpScale).round(),
      'physAtk': (physAtk * dmgScale).round(),
      'elemAtk': (elemAtk * dmgScale).round(),
    };
  }

  // ============================================================================
  // GUARDIAN SCALING
  // ============================================================================

  static GuardianScaling calculateGuardianScaling({
    required int baseLevel,
    required int strUpgrades,
    required int intUpgrades,
    required int beautyUpgrades,
    required int hpUpgrades,
    required int abilityRank,
  }) {
    final levelMultiplier = 1.0 + (baseLevel * 0.05);
    final strMultiplier = 1.0 + (strUpgrades * 0.08);
    final intMultiplier = 1.0 + (intUpgrades * 0.08);
    final beautyMultiplier = 1.0 + (beautyUpgrades * 0.08);
    final hpMultiplier = 1.0 + (hpUpgrades * 0.12);
    final abilityMultiplier = 1.0 + (abilityRank * 0.15);

    return GuardianScaling(
      levelMultiplier: levelMultiplier,
      hpMultiplier: hpMultiplier,
      physDamageMultiplier: strMultiplier,
      elemDamageMultiplier: beautyMultiplier,
      rangeMultiplier: intMultiplier,
      cooldownReduction: intMultiplier,
      abilityPowerMultiplier: abilityMultiplier,
    );
  }

  static void applyGuardianScaling(SurvivalUnit unit, GuardianScaling scaling) {
    unit.maxHp = (unit.maxHp * scaling.levelMultiplier * _baseGuardianHpScale)
        .round();
    unit.physAtk =
        (unit.physAtk * scaling.levelMultiplier * _baseGuardianDmgScale)
            .round();
    unit.elemAtk =
        (unit.elemAtk * scaling.levelMultiplier * _baseGuardianDmgScale)
            .round();

    unit.maxHp = (unit.maxHp * scaling.hpMultiplier).round();
    unit.currentHp = unit.maxHp;
    unit.physAtk = (unit.physAtk * scaling.physDamageMultiplier).round();
    unit.elemAtk = (unit.elemAtk * scaling.elemDamageMultiplier).round();

    unit.calculateCombatStats();
  }

  static Map<String, int> getSuggestedStatAllocation(
    int totalUpgrades,
    String family,
  ) {
    final allocation = <String, int>{
      'strength': 0,
      'intelligence': 0,
      'beauty': 0,
      'maxHp': 0,
    };
    final perStat = totalUpgrades ~/ 4;
    allocation['strength'] = perStat;
    allocation['intelligence'] = perStat;
    allocation['beauty'] = perStat;
    allocation['maxHp'] = totalUpgrades - (perStat * 3);
    return allocation;
  }
}

class GuardianScaling {
  final double levelMultiplier;
  final double hpMultiplier;
  final double physDamageMultiplier;
  final double elemDamageMultiplier;
  final double rangeMultiplier;
  final double cooldownReduction;
  final double abilityPowerMultiplier;

  const GuardianScaling({
    required this.levelMultiplier,
    required this.hpMultiplier,
    required this.physDamageMultiplier,
    required this.elemDamageMultiplier,
    required this.rangeMultiplier,
    required this.cooldownReduction,
    required this.abilityPowerMultiplier,
  });
}
