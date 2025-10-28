// lib/models/creature_stats.dart

import 'dart:math';

import 'package:alchemons/models/creature.dart';

class CreatureStats {
  final double speed;
  final double intelligence;
  final double strength;
  final double beauty;

  // Potential caps for each stat (max value each stat can reach)
  final double speedPotential;
  final double intelligencePotential;
  final double strengthPotential;
  final double beautyPotential;

  const CreatureStats({
    required this.speed,
    required this.intelligence,
    required this.strength,
    required this.beauty,
    required this.speedPotential,
    required this.intelligencePotential,
    required this.strengthPotential,
    required this.beautyPotential,
  });

  factory CreatureStats.generate(Random rng) {
    // Generate stats with normal distribution around 3 (midpoint of 1-5)
    // Using Box-Muller transform for normal distribution
    double generateNormalStat() {
      // Generate two uniform random numbers
      final u1 = rng.nextDouble();
      final u2 = rng.nextDouble();

      // Box-Muller transform for normal distribution
      // Mean = 3, StdDev = 0.75 gives good spread for 1-5 range
      final z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
      final value = 3.0 + z0 * 0.75;

      // Clamp to 1-5 range
      return value.clamp(1.0, 5.0);
    }

    // Generate potential for each stat
    // Higher potential = rarer, with anti-correlation to prevent all-max creatures
    double generatePotential(int statIndex, List<double> previousPotentials) {
      final u1 = rng.nextDouble();
      final u2 = rng.nextDouble();

      // Base potential generation (normal distribution around 4.0)
      final z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
      var potential = 4.0 + z0 * 0.6;

      // Anti-correlation: if we already have high potentials, reduce chance of another
      final maxPrevious = previousPotentials.isEmpty
          ? 0.0
          : previousPotentials.reduce(max);

      if (maxPrevious >= 4.7) {
        // Already have one very high potential stat
        // Significantly reduce this stat's potential
        potential -= 0.8;
      } else if (maxPrevious >= 4.4) {
        // Have a high potential stat
        potential -= 0.4;
      }

      // Count how many high potentials we already have
      final highPotentialCount = previousPotentials
          .where((p) => p >= 4.3)
          .length;
      if (highPotentialCount >= 2) {
        // Already have 2 high potentials, make this one lower
        potential -= 0.6;
      }

      return potential.clamp(3.0, 5.0);
    }

    // Generate all four base stats
    final stats = [
      generateNormalStat(),
      generateNormalStat(),
      generateNormalStat(),
      generateNormalStat(),
    ];

    // Special handling: if we rolled really high (4.75+) on one stat,
    // slightly reduce the chance of getting multiple perfect stats
    final maxStat = stats.reduce(max);
    if (maxStat >= 4.75) {
      for (int i = 0; i < stats.length; i++) {
        if (stats[i] != maxStat && stats[i] >= 4.5) {
          // Small penalty for additional high stats
          stats[i] = (stats[i] - 0.15).clamp(1.0, 5.0);
        }
      }
    }

    // Generate potentials with anti-correlation
    final potentials = <double>[];
    for (int i = 0; i < 4; i++) {
      potentials.add(generatePotential(i, potentials));
    }

    // Ensure starting stats don't exceed potential
    stats[0] = min(stats[0], potentials[0]);
    stats[1] = min(stats[1], potentials[1]);
    stats[2] = min(stats[2], potentials[2]);
    stats[3] = min(stats[3], potentials[3]);

    return CreatureStats(
      speed: stats[0],
      intelligence: stats[1],
      strength: stats[2],
      beauty: stats[3],
      speedPotential: potentials[0],
      intelligencePotential: potentials[1],
      strengthPotential: potentials[2],
      beautyPotential: potentials[3],
    );
  }

  // Blend two parent stats with mutation
  factory CreatureStats.breed(
    CreatureStats parent1,
    CreatureStats parent2,
    Random rng, {
    double mutationChance = 0.15,
    double mutationStrength = 0.5,
  }) {
    double blendStat(double s1, double s2) {
      // Average with small random variance
      final avg = (s1 + s2) / 2.0;
      final variance = (rng.nextDouble() - 0.5) * 0.25; // ±0.125
      var result = avg + variance;

      // Apply mutation
      if (rng.nextDouble() < mutationChance) {
        final mutation = (rng.nextDouble() - 0.5) * mutationStrength;
        result += mutation;
      }

      return result.clamp(1.0, 5.0);
    }

    // Blend potentials with inheritance bias toward higher values
    double blendPotential(double p1, double p2) {
      // If either parent has high potential (4.5+), 70% chance child gets high potential too
      final hasHighPotential = (p1 >= 4.5) || (p2 >= 4.5);

      if (hasHighPotential && rng.nextDouble() < 0.70) {
        // Inherit the higher potential with small variance
        final higher = max(p1, p2);
        final variance = (rng.nextDouble() - 0.5) * 0.2;
        return (higher + variance).clamp(3.0, 5.0);
      }

      // Otherwise blend normally with bias toward higher value
      final avg = (p1 + p2) / 2.0;
      final higher = max(p1, p2);
      final biasedAvg = (avg * 0.6 + higher * 0.4); // 40% bias toward higher
      final variance = (rng.nextDouble() - 0.5) * 0.3;
      return (biasedAvg + variance).clamp(3.0, 5.0);
    }

    final newStats = [
      blendStat(parent1.speed, parent2.speed),
      blendStat(parent1.intelligence, parent2.intelligence),
      blendStat(parent1.strength, parent2.strength),
      blendStat(parent1.beauty, parent2.beauty),
    ];

    final newPotentials = [
      blendPotential(parent1.speedPotential, parent2.speedPotential),
      blendPotential(
        parent1.intelligencePotential,
        parent2.intelligencePotential,
      ),
      blendPotential(parent1.strengthPotential, parent2.strengthPotential),
      blendPotential(parent1.beautyPotential, parent2.beautyPotential),
    ];

    // Ensure starting stats don't exceed potential
    newStats[0] = min(newStats[0], newPotentials[0]);
    newStats[1] = min(newStats[1], newPotentials[1]);
    newStats[2] = min(newStats[2], newPotentials[2]);
    newStats[3] = min(newStats[3], newPotentials[3]);

    return CreatureStats(
      speed: newStats[0],
      intelligence: newStats[1],
      strength: newStats[2],
      beauty: newStats[3],
      speedPotential: newPotentials[0],
      intelligencePotential: newPotentials[1],
      strengthPotential: newPotentials[2],
      beautyPotential: newPotentials[3],
    );
  }

  CreatureStats applyGenetics(Genetics? genetics) {
    if (genetics == null) return this;

    final size = genetics.get('size') ?? 'normal';

    switch (size) {
      case 'tiny':
        // Faster but weaker
        return copyWith(
          speed: (speed * 1.15).clamp(1.0, speedPotential),
          strength: (strength * 0.85).clamp(1.0, 5.0),
          // Adjust potentials slightly
          speedPotential: (speedPotential * 1.1).clamp(3.0, 5.0),
          strengthPotential: (strengthPotential * 0.95).clamp(3.0, 5.0),
        );
      case 'giant':
        // Stronger but slower
        return copyWith(
          speed: (speed * 0.85).clamp(1.0, 5.0),
          strength: (strength * 1.15).clamp(1.0, strengthPotential),
          speedPotential: (speedPotential * 0.95).clamp(3.0, 5.0),
          strengthPotential: (strengthPotential * 1.1).clamp(3.0, 5.0),
        );
      case 'small':
        return copyWith(
          speed: (speed * 1.08).clamp(1.0, speedPotential),
          strength: (strength * 0.92).clamp(1.0, 5.0),
          speedPotential: (speedPotential * 1.05).clamp(3.0, 5.0),
          strengthPotential: (strengthPotential * 0.98).clamp(3.0, 5.0),
        );
      case 'large':
        return copyWith(
          speed: (speed * 0.92).clamp(1.0, 5.0),
          strength: (strength * 1.08).clamp(1.0, strengthPotential),
          speedPotential: (speedPotential * 0.98).clamp(3.0, 5.0),
          strengthPotential: (strengthPotential * 1.05).clamp(3.0, 5.0),
        );
      default: // normal
        return this;
    }
  }

  // Apply nature bonus
  CreatureStats applyNature(String? natureId) {
    if (natureId == null) return this;

    // Define stat-boosting natures
    const statBoost = 0.25;
    switch (natureId) {
      case 'Swift':
        final baseStat = speed < 2.5 ? 2.5 : speed;
        return copyWith(
          speed: (baseStat + statBoost).clamp(1.0, speedPotential),
          speedPotential: (speedPotential + 0.2).clamp(3.0, 5.0),
        );
      case 'Clever':
        final baseStat = intelligence < 2.5 ? 2.5 : intelligence;
        return copyWith(
          intelligence: (baseStat + statBoost).clamp(
            1.0,
            intelligencePotential,
          ),
          intelligencePotential: (intelligencePotential + 0.2).clamp(3.0, 5.0),
        );
      case 'Mighty':
        final baseStat = strength < 2.5 ? 2.5 : strength;
        return copyWith(
          strength: (baseStat + statBoost).clamp(1.0, strengthPotential),
          strengthPotential: (strengthPotential + 0.2).clamp(3.0, 5.0),
        );
      case 'Elegant':
        final baseStat = beauty < 2.5 ? 2.5 : beauty;
        return copyWith(
          beauty: (baseStat + statBoost).clamp(1.0, beautyPotential),
          beautyPotential: (beautyPotential + 0.2).clamp(3.0, 5.0),
        );
      default:
        return this;
    }
  }

  CreatureStats copyWith({
    double? speed,
    double? intelligence,
    double? strength,
    double? beauty,
    double? speedPotential,
    double? intelligencePotential,
    double? strengthPotential,
    double? beautyPotential,
  }) {
    return CreatureStats(
      speed: speed ?? this.speed,
      intelligence: intelligence ?? this.intelligence,
      strength: strength ?? this.strength,
      beauty: beauty ?? this.beauty,
      speedPotential: speedPotential ?? this.speedPotential,
      intelligencePotential:
          intelligencePotential ?? this.intelligencePotential,
      strengthPotential: strengthPotential ?? this.strengthPotential,
      beautyPotential: beautyPotential ?? this.beautyPotential,
    );
  }

  Map<String, double> toJson() => {
    'speed': speed,
    'intelligence': intelligence,
    'strength': strength,
    'beauty': beauty,
    'speedPotential': speedPotential,
    'intelligencePotential': intelligencePotential,
    'strengthPotential': strengthPotential,
    'beautyPotential': beautyPotential,
  };

  factory CreatureStats.fromJson(Map<String, dynamic> json) {
    return CreatureStats(
      speed: (json['speed'] as num?)?.toDouble() ?? 3.0,
      intelligence: (json['intelligence'] as num?)?.toDouble() ?? 3.0,
      strength: (json['strength'] as num?)?.toDouble() ?? 3.0,
      beauty: (json['beauty'] as num?)?.toDouble() ?? 3.0,
      speedPotential: (json['speedPotential'] as num?)?.toDouble() ?? 4.0,
      intelligencePotential:
          (json['intelligencePotential'] as num?)?.toDouble() ?? 4.0,
      strengthPotential: (json['strengthPotential'] as num?)?.toDouble() ?? 4.0,
      beautyPotential: (json['beautyPotential'] as num?)?.toDouble() ?? 4.0,
    );
  }
}

// Stat description helpers
class StatDescriptions {
  static String describeSpeed(double value) {
    if (value <= 1.5) return 'Sluggish';
    if (value <= 2.5) return 'Slow';
    if (value <= 3.5) return 'Average';
    if (value <= 4.5) return 'Fast';
    return 'Blazing';
  }

  static String describeIntelligence(double value) {
    if (value <= 1.5) return 'Simple';
    if (value <= 2.5) return 'Dim';
    if (value <= 3.5) return 'Average';
    if (value <= 4.5) return 'Smart';
    return 'Genius';
  }

  static String describeStrength(double value) {
    if (value <= 1.5) return 'Frail';
    if (value <= 2.5) return 'Weak';
    if (value <= 3.5) return 'Average';
    if (value <= 4.5) return 'Strong';
    return 'Mighty';
  }

  static String describeBeauty(double value) {
    if (value <= 1.5) return 'Homely';
    if (value <= 2.5) return 'Plain';
    if (value <= 3.5) return 'Average';
    if (value <= 4.5) return 'Attractive';
    return 'Stunning';
  }

  static String describePotential(double value) {
    if (value <= 3.5) return 'Limited';
    if (value <= 4.0) return 'Good';
    if (value <= 4.3) return 'Great';
    if (value <= 4.6) return 'Exceptional';
    return 'Legendary';
  }

  static String getOverallDescription(CreatureStats stats) {
    final total =
        stats.speed + stats.intelligence + stats.strength + stats.beauty;

    if (total <= 8) return 'This creature has modest abilities.';
    if (total <= 12) return 'This creature shows average potential.';
    if (total <= 16) return 'This creature has impressive capabilities.';
    if (total <= 18) return 'This creature displays remarkable prowess.';
    return 'This creature possesses legendary attributes!';
  }

  static String getPotentialDescription(CreatureStats stats) {
    final totalPotential =
        stats.speedPotential +
        stats.intelligencePotential +
        stats.strengthPotential +
        stats.beautyPotential;

    if (totalPotential <= 15.0) return 'Limited growth potential.';
    if (totalPotential <= 16.5) return 'Average growth potential.';
    if (totalPotential <= 18.0) return 'Excellent growth potential!';
    if (totalPotential <= 19.0) return 'Exceptional growth potential!';
    return 'Legendary growth potential!!';
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

  static String getHighestPotentialDescription(CreatureStats stats) {
    final potentialMap = {
      'speed': stats.speedPotential,
      'intelligence': stats.intelligencePotential,
      'strength': stats.strengthPotential,
      'beauty': stats.beautyPotential,
    };

    final highest = potentialMap.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    switch (highest.key) {
      case 'speed':
        return 'Natural talent for speed';
      case 'intelligence':
        return 'Gifted with mental prowess';
      case 'strength':
        return 'Born for physical might';
      case 'beauty':
        return 'Blessed with natural elegance';
      default:
        return '';
    }
  }
}
