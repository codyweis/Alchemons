import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/models/survival_upgrades.dart';

typedef GuardianUpgradeValue = double Function(GuardianUpgrade upgrade);

class CosmicSurvivalCompanionStats {
  const CosmicSurvivalCompanionStats({
    required this.maxHp,
    required this.physAtk,
    required this.elemAtk,
    required this.physDef,
    required this.elemDef,
    required this.cooldownReduction,
    required this.critChance,
    required this.attackRange,
    required this.specialAbilityRange,
  });

  final int maxHp;
  final int physAtk;
  final int elemAtk;
  final int physDef;
  final int elemDef;
  final double cooldownReduction;
  final double critChance;
  final double attackRange;
  final double specialAbilityRange;
}

double cosmicSurvivalFamilyAttackRange(String family, double baseRange) {
  return switch (family.toLowerCase()) {
    'horn' => baseRange * 0.58,
    'mane' => baseRange * 0.95,
    'mask' => baseRange * 1.00,
    'kin' => baseRange * 1.15,
    'wing' => baseRange * 1.30,
    'pip' => baseRange * 0.90,
    'mystic' => baseRange * 1.10,
    'let' => baseRange * 1.10,
    _ => baseRange,
  };
}

double cosmicSurvivalFamilySpecialRange(String family, double baseRange) {
  return switch (family.toLowerCase()) {
    'horn' => baseRange * 0.90,
    'mane' => baseRange * 1.10,
    'mask' => baseRange * 1.15,
    'let' => baseRange * 1.10,
    'pip' => baseRange * 1.05,
    'wing' => baseRange * 1.50,
    'kin' => baseRange * 1.20,
    'mystic' => baseRange * 1.45,
    _ => baseRange * 1.25,
  };
}

double cosmicSurvivalSpecialCooldownMultiplier(String family) {
  return family.toLowerCase() == 'kin' ? 1.6 : 1.0;
}

CosmicSurvivalCompanionStats deriveCosmicSurvivalCompanionStats({
  required CosmicPartyMember member,
  double strengthBonus = 0,
  double intelligenceBonus = 0,
  double beautyBonus = 0,
  double speedBonus = 0,
  GuardianUpgradeValue? guardianUpgradeValue,
}) {
  final level = CosmicBalance.clampCompanionLevel(member.level);
  final family = member.family.toLowerCase();
  final str = max(0.5, member.statStrength + strengthBonus);
  final intel = max(0.5, member.statIntelligence + intelligenceBonus);
  final beauty = max(0.5, member.statBeauty + beautyBonus);
  final speed = max(0.5, member.statSpeed + speedBonus);

  // Family-specific multipliers for survival mode.
  final (
    double hpMult,
    double physAtkMult,
    double elemAtkMult,
    double physDefMult,
    double elemDefMult,
    double critMult,
  ) = switch (family) {
    'horn' => (1.40, 1.10, 0.80, 1.30, 1.20, 0.90),
    'mane' => (1.05, 1.15, 1.00, 1.10, 1.00, 1.10),
    'wing' => (1.05, 0.90, 1.30, 0.85, 0.90, 1.00),
    'let' => (1.05, 1.25, 1.10, 1.15, 1.10, 0.85),
    'pip' => (0.80, 1.00, 0.95, 0.80, 0.85, 1.40),
    'mask' => (1.05, 1.10, 1.10, 1.00, 1.05, 1.20),
    'kin' => (1.35, 0.90, 0.90, 1.10, 1.15, 0.90),
    'mystic' => (1.05, 0.85, 1.45, 0.85, 0.90, 1.00),
    _ => (1.00, 1.00, 1.00, 1.00, 1.00, 1.00),
  };

  final strPow = CosmicSurvivalBalance.survivalStatPower(str);
  final intPow = CosmicSurvivalBalance.survivalStatPower(intel);
  final beautyPow = CosmicSurvivalBalance.survivalStatPower(beauty);

  final maxHp = ((110 + level * 18 + 320 * strPow + 150 * intPow) * hpMult)
      .round();

  final levelFactor = 1.04 + (level - 1) * 0.065;
  final physAtk = max(
    1,
    ((5.0 + 24.0 * strPow) * levelFactor * physAtkMult).round(),
  );
  final elemAtk = max(
    1,
    ((5.5 + 25.0 * beautyPow) * levelFactor * elemAtkMult).round(),
  );

  final physDef = ((15 + level * 2.8 + 58 * strPow + 34 * intPow) * physDefMult)
      .round();
  final elemDef =
      ((15 + level * 2.8 + 58 * beautyPow + 34 * intPow) * elemDefMult).round();

  var cooldownReduction = CosmicBalance.companionCooldownReduction(speed);
  var critChance = ((0.05 + strPow * 0.32) * critMult).clamp(0.05, 0.55);
  var baseRange = 100.0 + intel * 28.0;

  double upgrade(GuardianUpgrade u) => guardianUpgradeValue?.call(u) ?? 0.0;

  cooldownReduction *= (1 + upgrade(GuardianUpgrade.cooldown));
  final guardDefMult = 1 + upgrade(GuardianUpgrade.defense);
  final guardAtkMult = 1 + upgrade(GuardianUpgrade.attack);
  critChance = (critChance + upgrade(GuardianUpgrade.critChance)).clamp(
    0.05,
    0.65,
  );
  baseRange *= (1 + upgrade(GuardianUpgrade.range));

  return CosmicSurvivalCompanionStats(
    maxHp: maxHp,
    physAtk: (physAtk * guardAtkMult).round(),
    elemAtk: (elemAtk * guardAtkMult).round(),
    physDef: (physDef * guardDefMult).round(),
    elemDef: (elemDef * guardDefMult).round(),
    cooldownReduction: cooldownReduction,
    critChance: critChance,
    attackRange: cosmicSurvivalFamilyAttackRange(family, baseRange),
    specialAbilityRange: cosmicSurvivalFamilySpecialRange(family, baseRange),
  );
}
