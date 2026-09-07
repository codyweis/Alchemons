import 'dart:math';

import 'package:alchemons/models/inventory.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/app_icons.dart';

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
      'A quicksilver orb used for permanent Speed Enhancement.',
    AlchemicalPowerupType.intelligence =>
      'A lucid orb used for permanent Intelligence Enhancement.',
    AlchemicalPowerupType.strength =>
      'A dense forged orb used for permanent Strength Enhancement.',
    AlchemicalPowerupType.beauty =>
      'A luminous orb used for permanent Beauty Enhancement.',
  };

  IconData get icon => switch (this) {
    AlchemicalPowerupType.speed => AppIcons.bolt_rounded,
    AlchemicalPowerupType.intelligence => AppIcons.psychology_rounded,
    AlchemicalPowerupType.strength => AppIcons.fitness_center_rounded,
    AlchemicalPowerupType.beauty => AppIcons.auto_awesome_rounded,
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

List<MapEntry<String, int>> rollCosmicSurvivalPowerupRewards(
  int wave,
  Random rng,
) {
  final dropChance = wave >= 50
      ? 0.40
      : wave >= 40
      ? 0.28
      : wave >= 30
      ? 0.18
      : wave >= 20
      ? 0.10
      : wave >= 10
      ? 0.05
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
    if (rng.nextDouble() <= 0.25) {
      out.update(powerup.inventoryKey, (value) => value + 1, ifAbsent: () => 1);
    }
  }
  return out.entries.toList();
}
