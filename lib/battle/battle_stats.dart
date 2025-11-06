// lib/battle/battle_stats.dart
// Stat-based battle mechanics: throw speed, damage, fusion chance, HP

import 'dart:math' as math;
import 'package:alchemons/battle/battle_game_core.dart';

class BattleStats {
  // ============================================================================
  // THROW MECHANICS (Speed stat)
  // ============================================================================

  /// Calculate throw speed multiplier based on creature's Speed stat
  /// Speed stat typically ranges from 1-10
  /// Returns a multiplier for the base throw speed
  static double throwSpeedMultiplier(BattleCreature creature) {
    final speed = creature.instance.statSpeed;
    // Speed 1 = 0.6x, Speed 5 = 1.0x, Speed 10 = 1.5x
    return 0.6 + (speed * 0.09);
  }

  /// Calculate actual throw velocity based on aim, power, and creature stats
  static double calculateThrowSpeed(
    BattleCreature creature,
    double power,
    double baseMaxSpeed,
  ) {
    final speedMult = throwSpeedMultiplier(creature);
    return power * baseMaxSpeed * speedMult;
  }

  // ============================================================================
  // DAMAGE MECHANICS (Strength stat)
  // ============================================================================

  /// Calculate damage dealt from one creature to another
  /// Factors: Strength stat, elemental effectiveness, rarity
  static int calculateDamage(BattleCreature attacker, BattleCreature defender) {
    final baseRaw = 15.0;
    final strength = attacker.instance.statStrength;
    final rarityMult = _rarityMultiplier(attacker.rarity);
    final effectiveness = elementalEffectiveness(
      attacker.element,
      defender.element,
    );

    // Formula: (15 + Strength * 3) * RarityMult * Effectiveness
    final damage = (baseRaw + strength * 3.0) * rarityMult * effectiveness;
    return damage.round().clamp(1, 999);
  }

  /// Elemental type effectiveness chart
  /// Returns damage multiplier: 1.0 = neutral, 1.3 = super effective, 0.7 = not very effective
  static double elementalEffectiveness(
    String attackElement,
    String defendElement,
  ) {
    // Super effective (1.3x damage)
    final superEffective = {
      'Fire': ['Plant', 'Ice'],
      'Water': ['Fire', 'Lava'],
      'Earth': ['Lightning', 'Air'],
      'Air': ['Earth'],
      'Ice': ['Air', 'Plant'],
      'Lightning': ['Water', 'Ice'],
      'Plant': ['Water', 'Earth', 'Mud'],
      'Poison': ['Plant', 'Water'],
      'Dark': ['Light', 'Spirit'],
      'Light': ['Dark', 'Poison'],
      'Lava': ['Ice', 'Plant'],
      'Steam': ['Ice'],
      'Crystal': ['Dark'],
      'Dust': ['Fire'],
    };

    // Not very effective (0.7x damage)
    final notVeryEffective = {
      'Fire': ['Water', 'Lava'],
      'Water': ['Plant', 'Lightning'],
      'Earth': ['Air'],
      'Air': ['Lightning'],
      'Ice': ['Fire', 'Lava'],
      'Lightning': ['Earth', 'Crystal'],
      'Plant': ['Fire', 'Poison', 'Ice'],
      'Poison': ['Earth', 'Crystal'],
      'Dark': ['Crystal'],
      'Light': ['Dark'],
    };

    if (superEffective[attackElement]?.contains(defendElement) ?? false) {
      return 1.3;
    }
    if (notVeryEffective[attackElement]?.contains(defendElement) ?? false) {
      return 0.7;
    }
    return 1.0; // Neutral
  }

  // ============================================================================
  // FUSION MECHANICS (Intelligence stat)
  // ============================================================================

  /// Calculate fusion success chance based on parent creatures' Intelligence
  /// Intelligence typically ranges from 1-10
  /// Returns probability between 0.5 and 0.95
  static double fusionSuccessChance(
    BattleCreature parent1,
    BattleCreature parent2,
  ) {
    final int1 = parent1.instance.statIntelligence;
    final int2 = parent2.instance.statIntelligence;
    final avgInt = (int1 + int2) / 2.0;

    // Intelligence 1 = 50%, Intelligence 5 = 75%, Intelligence 10 = 95%
    final chance = 0.5 + (avgInt * 0.045);
    return chance.clamp(0.5, 0.95);
  }

  /// Roll for fusion success
  static bool rollFusion(
    BattleCreature parent1,
    BattleCreature parent2,
    math.Random rng,
  ) {
    final chance = fusionSuccessChance(parent1, parent2);
    return rng.nextDouble() < chance;
  }

  // ============================================================================
  // HP MECHANICS (Beauty stat)
  // ============================================================================

  /// Calculate max HP based on Beauty stat and level
  /// Beauty typically ranges from 1-10
  static int calculateMaxHP(BattleCreature creature) {
    final level = creature.instance.level;
    final beauty = creature.instance.statBeauty;
    final stamina = creature.instance.staminaMax;

    // Formula: 80 + (Level * 20) + (Beauty * 12) + (Stamina * 8)
    final hp = 80 + (level * 20) + (beauty * 12) + (stamina * 8);
    return hp.clamp(50, 999).toInt();
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  static double _rarityMultiplier(String rarity) {
    switch (rarity) {
      case 'Legendary':
        return 1.35;
      case 'Rare':
        return 1.20;
      case 'Uncommon':
        return 1.10;
      default: // Common
        return 1.0;
    }
  }

  /// Get a human-readable stat summary for UI
  static String getStatSummary(BattleCreature creature) {
    final speed = throwSpeedMultiplier(creature);
    final hp = calculateMaxHP(creature);
    return '''
Speed: ${(speed * 100).toInt()}% throw velocity
HP: $hp
Strength: ${creature.instance.statStrength.toStringAsFixed(1)} (damage)
Intelligence: ${creature.instance.statIntelligence.toStringAsFixed(1)} (fusion)
Beauty: ${creature.instance.statBeauty.toStringAsFixed(1)} (vitality)
''';
  }
}



//tuning

// // Throw speed range
// return 0.6 + (speed * 0.09);  // Change 0.6 (min) or 0.09 (per point)

// // Damage formula
// final damage = (baseRaw + strength * 3.0) * rarityMult * effectiveness;
// // Change baseRaw (15), or strength multiplier (3.0)

// // Fusion chance
// final chance = 0.5 + (avgInt * 0.045);
// // Change 0.5 (min) or 0.045 (per point)

// // HP formula
// final hp = 80 + (level * 20) + (beauty * 12) + (stamina * 8);
// // Adjust any of these multipliers