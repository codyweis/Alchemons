import 'dart:math';

import 'package:alchemons/models/inventory.dart';
import 'package:flutter/material.dart';

enum AlchemicalPowerupType { speed, intelligence, strength, beauty }

extension AlchemicalPowerupTypeX on AlchemicalPowerupType {
  String get statKey => switch (this) {
    AlchemicalPowerupType.speed => 'speed',
    AlchemicalPowerupType.intelligence => 'intelligence',
    AlchemicalPowerupType.strength => 'strength',
    AlchemicalPowerupType.beauty => 'beauty',
  };

  String get inventoryKey => switch (this) {
    AlchemicalPowerupType.speed => InvKeys.powerupSpeed,
    AlchemicalPowerupType.intelligence => InvKeys.powerupIntelligence,
    AlchemicalPowerupType.strength => InvKeys.powerupStrength,
    AlchemicalPowerupType.beauty => InvKeys.powerupBeauty,
  };

  String get shopOfferId => switch (this) {
    AlchemicalPowerupType.speed => 'boost.powerup.speed',
    AlchemicalPowerupType.intelligence => 'boost.powerup.intelligence',
    AlchemicalPowerupType.strength => 'boost.powerup.strength',
    AlchemicalPowerupType.beauty => 'boost.powerup.beauty',
  };

  String get name => switch (this) {
    AlchemicalPowerupType.speed => 'Velocity Orb',
    AlchemicalPowerupType.intelligence => 'Insight Orb',
    AlchemicalPowerupType.strength => 'Forge Orb',
    AlchemicalPowerupType.beauty => 'Radiance Orb',
  };

  String get categoryLabel => 'Alchemical Powerup';

  String get description => switch (this) {
    AlchemicalPowerupType.speed =>
      'A quicksilver orb that accelerates Speed growth up to the specimen\'s potential.',
    AlchemicalPowerupType.intelligence =>
      'A lucid orb that sharpens Intelligence up to the specimen\'s potential.',
    AlchemicalPowerupType.strength =>
      'A dense forged orb that empowers Strength up to the specimen\'s potential.',
    AlchemicalPowerupType.beauty =>
      'A luminous orb that enhances Beauty up to the specimen\'s potential.',
  };

  IconData get icon => switch (this) {
    AlchemicalPowerupType.speed => Icons.bolt_rounded,
    AlchemicalPowerupType.intelligence => Icons.psychology_rounded,
    AlchemicalPowerupType.strength => Icons.fitness_center_rounded,
    AlchemicalPowerupType.beauty => Icons.auto_awesome_rounded,
  };

  Color get color => switch (this) {
    AlchemicalPowerupType.speed => const Color(0xFF59E3FF),
    AlchemicalPowerupType.intelligence => const Color(0xFFB58CFF),
    AlchemicalPowerupType.strength => const Color(0xFFFF8A4C),
    AlchemicalPowerupType.beauty => const Color(0xFFFF6FAE),
  };

  Color get glowColor => switch (this) {
    AlchemicalPowerupType.speed => const Color(0xAA59E3FF),
    AlchemicalPowerupType.intelligence => const Color(0xAAB58CFF),
    AlchemicalPowerupType.strength => const Color(0xAAFFB067),
    AlchemicalPowerupType.beauty => const Color(0xAAFF9BCC),
  };
}

AlchemicalPowerupType? alchemicalPowerupTypeFromInventoryKey(String key) {
  for (final type in AlchemicalPowerupType.values) {
    if (type.inventoryKey == key) return type;
  }
  return null;
}

enum AlchemicalPowerupRollTier { fizzle, steady, surge, overcharge, jackpot }

class AlchemicalPowerupRoll {
  final AlchemicalPowerupRollTier tier;
  final double rolledDelta;
  final double appliedDelta;

  const AlchemicalPowerupRoll({
    required this.tier,
    required this.rolledDelta,
    required this.appliedDelta,
  });

  bool get isRare => switch (tier) {
    AlchemicalPowerupRollTier.fizzle => true,
    AlchemicalPowerupRollTier.jackpot => true,
    _ => false,
  };

  bool get isJackpot => tier == AlchemicalPowerupRollTier.jackpot;

  String get label => switch (tier) {
    AlchemicalPowerupRollTier.fizzle => 'VOLATILE',
    AlchemicalPowerupRollTier.steady => 'STEADY',
    AlchemicalPowerupRollTier.surge => 'SURGE',
    AlchemicalPowerupRollTier.overcharge => 'OVERCHARGE',
    AlchemicalPowerupRollTier.jackpot => 'ALCHEMICAL',
  };

  Duration get animationDuration => switch (tier) {
    AlchemicalPowerupRollTier.fizzle => const Duration(milliseconds: 2100),
    AlchemicalPowerupRollTier.steady => const Duration(milliseconds: 1500),
    AlchemicalPowerupRollTier.surge => const Duration(milliseconds: 1750),
    AlchemicalPowerupRollTier.overcharge => const Duration(milliseconds: 1950),
    AlchemicalPowerupRollTier.jackpot => const Duration(milliseconds: 2450),
  };

  Duration get flashDuration => switch (tier) {
    AlchemicalPowerupRollTier.fizzle => const Duration(milliseconds: 800),
    AlchemicalPowerupRollTier.steady => const Duration(milliseconds: 500),
    AlchemicalPowerupRollTier.surge => const Duration(milliseconds: 620),
    AlchemicalPowerupRollTier.overcharge => const Duration(milliseconds: 720),
    AlchemicalPowerupRollTier.jackpot => const Duration(milliseconds: 950),
  };

  double get glowBoost => switch (tier) {
    AlchemicalPowerupRollTier.fizzle => 1.15,
    AlchemicalPowerupRollTier.steady => 1.0,
    AlchemicalPowerupRollTier.surge => 1.08,
    AlchemicalPowerupRollTier.overcharge => 1.18,
    AlchemicalPowerupRollTier.jackpot => 1.35,
  };

  double get orbitTurns => switch (tier) {
    AlchemicalPowerupRollTier.fizzle => 2.0,
    AlchemicalPowerupRollTier.steady => 2.2,
    AlchemicalPowerupRollTier.surge => 2.8,
    AlchemicalPowerupRollTier.overcharge => 3.8,
    AlchemicalPowerupRollTier.jackpot => 5.2,
  };

  double get orbitEndProgress => switch (tier) {
    AlchemicalPowerupRollTier.fizzle => 0.68,
    AlchemicalPowerupRollTier.steady => 0.72,
    AlchemicalPowerupRollTier.surge => 0.76,
    AlchemicalPowerupRollTier.overcharge => 0.82,
    AlchemicalPowerupRollTier.jackpot => 0.86,
  };
}

double alchemicalPowerupMinDelta({
  required double currentValue,
  required double potentialValue,
}) {
  final remaining = max(0.0, potentialValue - currentValue);
  if (remaining <= 0) return 0.0;
  return min(0.05, remaining);
}

double alchemicalPowerupMaxDelta({
  required double currentValue,
  required double potentialValue,
}) {
  final remaining = max(0.0, potentialValue - currentValue);
  if (remaining <= 0) return 0.0;
  return min(0.25, remaining);
}

String alchemicalPowerupDeltaRangeLabel({
  required double currentValue,
  required double potentialValue,
}) {
  final minDelta = alchemicalPowerupMinDelta(
    currentValue: currentValue,
    potentialValue: potentialValue,
  );
  final maxDelta = alchemicalPowerupMaxDelta(
    currentValue: currentValue,
    potentialValue: potentialValue,
  );
  if (maxDelta <= 0) return '—';
  if ((minDelta - maxDelta).abs() < 0.0001) {
    return '+${maxDelta.toStringAsFixed(2)}';
  }
  return '+${minDelta.toStringAsFixed(2)} to +${maxDelta.toStringAsFixed(2)}';
}

AlchemicalPowerupRoll rollAlchemicalPowerup({
  required double currentValue,
  required double potentialValue,
  Random? rng,
}) {
  final remaining = max(0.0, potentialValue - currentValue);
  if (remaining <= 0) {
    return const AlchemicalPowerupRoll(
      tier: AlchemicalPowerupRollTier.fizzle,
      rolledDelta: 0.0,
      appliedDelta: 0.0,
    );
  }

  final roll = (rng ?? Random()).nextDouble();
  final tier = switch (roll) {
    < 0.05 => AlchemicalPowerupRollTier.fizzle,
    < 0.55 => AlchemicalPowerupRollTier.steady,
    < 0.80 => AlchemicalPowerupRollTier.surge,
    < 0.98 => AlchemicalPowerupRollTier.overcharge,
    _ => AlchemicalPowerupRollTier.jackpot,
  };

  final rolledDelta = switch (tier) {
    AlchemicalPowerupRollTier.fizzle => 0.05,
    AlchemicalPowerupRollTier.steady => 0.10,
    AlchemicalPowerupRollTier.surge => 0.15,
    AlchemicalPowerupRollTier.overcharge => 0.20,
    AlchemicalPowerupRollTier.jackpot => 0.25,
  };

  return AlchemicalPowerupRoll(
    tier: tier,
    rolledDelta: rolledDelta,
    appliedDelta: min(rolledDelta, remaining),
  );
}

List<MapEntry<String, int>> rollCosmicSurvivalPowerupRewards(
  int wave,
  Random rng,
) {
  final dropChance = wave >= 50
      ? 1.0
      : wave >= 30
      ? 0.50
      : wave >= 20
      ? 0.20
      : wave >= 10
      ? 0.10
      : 0.0;
  if (dropChance <= 0 || rng.nextDouble() > dropChance) return const [];

  final out = <String, int>{};
  final picked = AlchemicalPowerupType
      .values[rng.nextInt(AlchemicalPowerupType.values.length)];
  out.update(picked.inventoryKey, (value) => value + 1, ifAbsent: () => 1);
  return out.entries.toList();
}

List<MapEntry<String, int>> rollBossRiftPowerupRewards(Random rng) {
  final out = <String, int>{};
  for (final powerup in AlchemicalPowerupType.values) {
    if (rng.nextDouble() <= 0.50) {
      out.update(powerup.inventoryKey, (value) => value + 1, ifAbsent: () => 1);
    }
  }
  return out.entries.toList();
}
