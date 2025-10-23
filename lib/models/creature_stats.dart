// lib/models/creature_stats.dart

import 'dart:math';

import 'package:alchemons/models/creature.dart';

class CreatureStats {
  final double speed;
  final double intelligence;
  final double strength;
  final double beauty;

  const CreatureStats({
    required this.speed,
    required this.intelligence,
    required this.strength,
    required this.beauty,
  });

  factory CreatureStats.generate(Random rng) {
    // Generate stats with normal distribution around 5
    // Using Box-Muller transform for normal distribution
    double generateNormalStat() {
      // Generate two uniform random numbers
      final u1 = rng.nextDouble();
      final u2 = rng.nextDouble();

      // Box-Muller transform for normal distribution
      // Mean = 5, StdDev = 1.5 gives good spread
      final z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
      final value = 5.0 + z0 * 1.5;

      // Clamp to 1-10 range
      return value.clamp(1.0, 10.0);
    }

    // Generate all four stats
    final stats = [
      generateNormalStat(),
      generateNormalStat(),
      generateNormalStat(),
      generateNormalStat(),
    ];

    // Special handling: if we rolled really high (9.5+) on one stat,
    // slightly reduce the chance of getting multiple 10s
    final maxStat = stats.reduce(max);
    if (maxStat >= 9.5) {
      for (int i = 0; i < stats.length; i++) {
        if (stats[i] != maxStat && stats[i] >= 9.0) {
          // Small penalty for additional high stats
          stats[i] = (stats[i] - 0.3).clamp(1.0, 10.0);
        }
      }
    }

    return CreatureStats(
      speed: stats[0],
      intelligence: stats[1],
      strength: stats[2],
      beauty: stats[3],
    );
  }

  // Blend two parent stats with mutation
  factory CreatureStats.breed(
    CreatureStats parent1,
    CreatureStats parent2,
    Random rng, {
    double mutationChance = 0.15,
    double mutationStrength = 1.0,
  }) {
    double blendStat(double s1, double s2) {
      // Average with small random variance
      final avg = (s1 + s2) / 2.0;
      final variance = (rng.nextDouble() - 0.5) * 0.5; // ±0.25
      var result = avg + variance;

      // Apply mutation
      if (rng.nextDouble() < mutationChance) {
        final mutation = (rng.nextDouble() - 0.5) * 2.0 * mutationStrength;
        result += mutation;
      }

      return result.clamp(1.0, 10.0);
    }

    return CreatureStats(
      speed: blendStat(parent1.speed, parent2.speed),
      intelligence: blendStat(parent1.intelligence, parent2.intelligence),
      strength: blendStat(parent1.strength, parent2.strength),
      beauty: blendStat(parent1.beauty, parent2.beauty),
    );
  }

  CreatureStats applyGenetics(Genetics? genetics) {
    if (genetics == null) return this;

    final size = genetics.get('size') ?? 'normal';

    switch (size) {
      case 'tiny':
        // Faster but weaker
        return copyWith(
          speed: (speed * 1.15).clamp(1.0, 10.0),
          strength: (strength * 0.85).clamp(1.0, 10.0),
        );
      case 'giant':
        // Stronger but slower
        return copyWith(
          speed: (speed * 0.85).clamp(1.0, 10.0),
          strength: (strength * 1.15).clamp(1.0, 10.0),
        );
      case 'small':
        return copyWith(
          speed: (speed * 1.08).clamp(1.0, 10.0),
          strength: (strength * 0.92).clamp(1.0, 10.0),
        );
      case 'large':
        return copyWith(
          speed: (speed * 0.92).clamp(1.0, 10.0),
          strength: (strength * 1.08).clamp(1.0, 10.0),
        );
      default: // normal
        return this;
    }
  }

  // Apply nature bonus
  CreatureStats applyNature(String? natureId) {
    if (natureId == null) return this;

    // Define stat-boosting natures
    const statBoost = 0.5;
    switch (natureId) {
      case 'Swift':
        final baseStat = speed < 5.0 ? 5.0 : speed;
        return copyWith(speed: (baseStat + statBoost).clamp(1.0, 10.0));
      case 'Clever':
        final baseStat = intelligence < 5.0 ? 5.0 : intelligence;
        return copyWith(intelligence: (baseStat + statBoost).clamp(1.0, 10.0));
      case 'Mighty':
        final baseStat = strength < 5.0 ? 5.0 : strength;
        return copyWith(strength: (baseStat + statBoost).clamp(1.0, 10.0));
      case 'Elegant':
        final baseStat = beauty < 5.0 ? 5.0 : beauty;
        return copyWith(beauty: (baseStat + statBoost).clamp(1.0, 10.0));
      default:
        return this;
    }
  }

  CreatureStats copyWith({
    double? speed,
    double? intelligence,
    double? strength,
    double? beauty,
  }) {
    return CreatureStats(
      speed: speed ?? this.speed,
      intelligence: intelligence ?? this.intelligence,
      strength: strength ?? this.strength,
      beauty: beauty ?? this.beauty,
    );
  }

  Map<String, double> toJson() => {
    'speed': speed,
    'intelligence': intelligence,
    'strength': strength,
    'beauty': beauty,
  };

  factory CreatureStats.fromJson(Map<String, dynamic> json) {
    return CreatureStats(
      speed: (json['speed'] as num?)?.toDouble() ?? 3.0,
      intelligence: (json['intelligence'] as num?)?.toDouble() ?? 3.0,
      strength: (json['strength'] as num?)?.toDouble() ?? 3.0,
      beauty: (json['beauty'] as num?)?.toDouble() ?? 3.0,
    );
  }
}

// Stat description helpers
class StatDescriptions {
  static String describeSpeed(double value) {
    if (value <= 2) return 'Sluggish';
    if (value <= 4) return 'Slow';
    if (value <= 6) return 'Average';
    if (value <= 8) return 'Fast';
    return 'Blazing';
  }

  static String describeIntelligence(double value) {
    if (value <= 2) return 'Simple';
    if (value <= 4) return 'Dim';
    if (value <= 6) return 'Average';
    if (value <= 8) return 'Smart';
    return 'Genius';
  }

  static String describeStrength(double value) {
    if (value <= 2) return 'Frail';
    if (value <= 4) return 'Weak';
    if (value <= 6) return 'Average';
    if (value <= 8) return 'Strong';
    return 'Mighty';
  }

  static String describeBeauty(double value) {
    if (value <= 2) return 'Homely';
    if (value <= 4) return 'Plain';
    if (value <= 6) return 'Average';
    if (value <= 8) return 'Attractive';
    return 'Stunning';
  }

  static String getOverallDescription(CreatureStats stats) {
    final total =
        stats.speed + stats.intelligence + stats.strength + stats.beauty;

    if (total <= 12) return 'This creature has modest abilities.';
    if (total <= 20) return 'This creature shows average potential.';
    if (total <= 28) return 'This creature has impressive capabilities.';
    if (total <= 36) return 'This creature displays remarkable prowess.';
    return 'This creature possesses legendary attributes!';
  }

  static String getHighestStatDescription(CreatureStats stats) {
    final statsMap = {
      'speed': stats.speed,
      'intelligence': stats.intelligence,
      'strength': stats.strength,
      'beauty': stats.beauty,
    };

    final highest = statsMap.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    switch (highest.key) {
      case 'speed':
        return 'Known for incredible swiftness';
      case 'intelligence':
        return 'Renowned for brilliant mind';
      case 'strength':
        return 'Famous for tremendous power';
      case 'beauty':
        return 'Celebrated for stunning appearance';
      default:
        return '';
    }
  }
}
