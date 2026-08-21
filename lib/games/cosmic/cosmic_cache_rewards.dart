// lib/games/cosmic/cosmic_cache_rewards.dart
//
// What a sealed elemental cache pays out, and how it is rolled.
//
// Kept free of Flame/rendering imports so the payout table can be exercised
// directly in tests.

import 'dart:math';

import 'package:alchemons/models/inventory.dart';

/// The four alchemical powerup orbs a cache can contain.
const List<String> kCachePowerupKeys = [
  InvKeys.powerupSpeed,
  InvKeys.powerupIntelligence,
  InvKeys.powerupStrength,
  InvKeys.powerupBeauty,
];

/// Chance that a cache also holds an Instant Fusion Extractor.
const double kCacheExtractorChance = 0.20;

/// A rolled payout, ready to be committed to the wallet + inventory.
class ElementalCacheReward {
  ElementalCacheReward({
    required this.element,
    required this.gold,
    required this.powerups,
    required this.staminaElixirs,
    required this.stabilizedHarvesters,
    required this.fusionExtractors,
  });

  final String element;
  final int gold;

  /// Powerup orb key → quantity. Total across all keys is 1–5.
  final Map<String, int> powerups;

  final int staminaElixirs;
  final int stabilizedHarvesters;
  final int fusionExtractors;

  int get powerupTotal =>
      powerups.values.fold(0, (sum, qty) => sum + qty);

  /// Every inventory grant this reward implies, collapsed into one map.
  Map<String, int> get itemGrants => {
    ...powerups,
    if (staminaElixirs > 0) InvKeys.staminaPotion: staminaElixirs,
    if (stabilizedHarvesters > 0)
      InvKeys.harvesterGuaranteed: stabilizedHarvesters,
    if (fusionExtractors > 0) InvKeys.instantHatch: fusionExtractors,
  };

  /// Roll a payout:
  ///   • 1–5 gold
  ///   • 1–5 alchemical powerup orbs, spread across the four types
  ///   • 1 Stabilized Harvester
  ///   • 1–5 Stamina Elixirs
  ///   • 20% chance of an Instant Fusion Extractor
  factory ElementalCacheReward.roll(String element, Random rng) {
    final powerupCount = 1 + rng.nextInt(5);
    final powerups = <String, int>{};
    for (var i = 0; i < powerupCount; i++) {
      final key = kCachePowerupKeys[rng.nextInt(kCachePowerupKeys.length)];
      powerups[key] = (powerups[key] ?? 0) + 1;
    }

    return ElementalCacheReward(
      element: element,
      gold: 1 + rng.nextInt(5),
      powerups: powerups,
      staminaElixirs: 1 + rng.nextInt(5),
      stabilizedHarvesters: 1,
      fusionExtractors: rng.nextDouble() < kCacheExtractorChance ? 1 : 0,
    );
  }
}
