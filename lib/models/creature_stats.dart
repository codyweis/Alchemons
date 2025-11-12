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

  factory CreatureStats.generate(Random rng, {String rarity = 'Common'}) {
    // Generate stats with normal distribution
    double generateNormalStat(double mean, double stddev) {
      final u1 = rng.nextDouble();
      final u2 = rng.nextDouble();

      // Box-Muller transform for normal distribution
      final z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
      final value = mean + z0 * stddev;

      return value.clamp(0.0, 5.0);
    }

    final statParams = _getStatParamsByRarity(rarity);

    // Generate all four base stats
    final stats = [
      generateNormalStat(statParams.baseMean, statParams.baseStddev),
      generateNormalStat(statParams.baseMean, statParams.baseStddev),
      generateNormalStat(statParams.baseMean, statParams.baseStddev),
      generateNormalStat(statParams.baseMean, statParams.baseStddev),
    ];

    // Generate potentials - fully independent, no anti-correlation
    final potentials = [
      _generatePotential(rng, statParams, stats[0]),
      _generatePotential(rng, statParams, stats[1]),
      _generatePotential(rng, statParams, stats[2]),
      _generatePotential(rng, statParams, stats[3]),
    ];

    // Ensure starting stats don't exceed potential
    for (int i = 0; i < 4; i++) {
      stats[i] = min(stats[i], potentials[i]);
    }

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

  static _StatParams _getStatParamsByRarity(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'mythic':
        return _StatParams(
          baseMean: 2.0,
          baseStddev: 0.8,
          potentialMean: 3.0,
          potentialStddev: 0.7,
        );
      case 'legendary':
        return _StatParams(
          baseMean: 1.8,
          baseStddev: 0.7,
          potentialMean: 2.8,
          potentialStddev: 0.7,
        );
      case 'epic':
        return _StatParams(
          baseMean: 1.5,
          baseStddev: 0.6,
          potentialMean: 2.5,
          potentialStddev: 0.7,
        );
      case 'rare':
        return _StatParams(
          baseMean: 1.2,
          baseStddev: 0.6,
          potentialMean: 2.2,
          potentialStddev: 0.6,
        );
      case 'uncommon':
        return _StatParams(
          baseMean: 1.0,
          baseStddev: 0.5,
          potentialMean: 2.0,
          potentialStddev: 0.6,
        );
      default: // common
        return _StatParams(
          baseMean: 0.8,
          baseStddev: 0.5,
          potentialMean: 1.8,
          potentialStddev: 0.5,
        );
    }
  }

  static double _generatePotential(
    Random rng,
    _StatParams params,
    double baseStat,
  ) {
    final u1 = rng.nextDouble();
    final u2 = rng.nextDouble();

    // Normal distribution for potential
    final z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
    var potential = params.potentialMean + z0 * params.potentialStddev;

    // Ensure potential is at least slightly above base stat
    final minPotential = baseStat + 0.2;
    potential = max(potential, minPotential);

    return potential.clamp(1.0, 5.0);
  }

  // Blend two parent stats with mutation and nature awareness
  factory CreatureStats.breed(
    CreatureStats parent1,
    CreatureStats parent2,
    Random rng, {
    double mutationChance = 0.15,
    double mutationStrength = 0.3,
    String? parent1NatureId,
    String? parent2NatureId,
    String? childNatureId,
  }) {
    // Helper to determine if a nature boosts a specific stat
    bool natureBoostsStat(String? natureId, String statName) {
      if (natureId == null) return false;
      switch (statName) {
        case 'speed':
          return natureId == 'Swift';
        case 'intelligence':
          return natureId == 'Clever';
        case 'strength':
          return natureId == 'Mighty';
        case 'beauty':
          return natureId == 'Elegant';
        default:
          return false;
      }
    }

    // Blend base stats with nature-aware weighting
    double blendBaseStat(double s1, double s2, String statName) {
      final p1Boosted = natureBoostsStat(parent1NatureId, statName);
      final p2Boosted = natureBoostsStat(parent2NatureId, statName);

      double weight1 = 0.5;
      double weight2 = 0.5;

      if (p1Boosted && !p2Boosted) {
        weight1 = 0.65;
        weight2 = 0.35;
      } else if (p2Boosted && !p1Boosted) {
        weight1 = 0.35;
        weight2 = 0.65;
      } else if (p1Boosted && p2Boosted) {
        if (s1 > s2) {
          weight1 = 0.6;
          weight2 = 0.4;
        } else {
          weight1 = 0.4;
          weight2 = 0.6;
        }
      } else {
        if (s1 > s2) {
          weight1 = 0.55;
          weight2 = 0.45;
        } else {
          weight1 = 0.45;
          weight2 = 0.55;
        }
      }

      final avg = (s1 * weight1) + (s2 * weight2);
      final variance = (rng.nextDouble() - 0.5) * 0.15;
      var result = avg + variance;

      if (rng.nextDouble() < mutationChance) {
        final mutation = (rng.nextDouble() - 0.5) * mutationStrength;
        result += mutation;
      }

      return result.clamp(0.0, 5.0);
    }

    // Blend potentials with breakthrough mechanics (for stable stats)
    double blendPotentialStable(double p1, double p2, String statName) {
      final p1Boosted = natureBoostsStat(parent1NatureId, statName);
      final p2Boosted = natureBoostsStat(parent2NatureId, statName);
      final childBoosted = natureBoostsStat(childNatureId, statName);

      final higher = max(p1, p2);
      final lower = min(p1, p2);

      double baseBlend = (lower * 0.3) + (higher * 0.7);

      final bothHigh = p1 >= 3.5 && p2 >= 3.5;
      final bothNatureBoosted = p1Boosted && p2Boosted;

      double breakthroughChance = 0.0;
      if (bothHigh && bothNatureBoosted) {
        breakthroughChance = 0.25;
      } else if (bothHigh) {
        breakthroughChance = 0.15;
      } else if (bothNatureBoosted) {
        breakthroughChance = 0.10;
      }

      var result = baseBlend;

      if (rng.nextDouble() < breakthroughChance) {
        final breakthroughBonus = 0.1 + (rng.nextDouble() * 0.2);
        result = higher + breakthroughBonus;
      } else {
        final variance = (rng.nextDouble() - 0.5) * 0.3;
        result = baseBlend + variance;
      }

      if (childBoosted) {
        result += 0.15;
      }

      return result.clamp(1.0, 5.0);
    }

    // Calculate which stats are highest for each parent
    final p1Potentials = [
      ('speed', parent1.speedPotential),
      ('intelligence', parent1.intelligencePotential),
      ('strength', parent1.strengthPotential),
      ('beauty', parent1.beautyPotential),
    ];

    final p2Potentials = [
      ('speed', parent2.speedPotential),
      ('intelligence', parent2.intelligencePotential),
      ('strength', parent2.strengthPotential),
      ('beauty', parent2.beautyPotential),
    ];

    p1Potentials.sort((a, b) => b.$2.compareTo(a.$2));
    p2Potentials.sort((a, b) => b.$2.compareTo(a.$2));

    final p1High = {p1Potentials[0].$1, p1Potentials[1].$1};
    final p2High = {p2Potentials[0].$1, p2Potentials[1].$1};

    final stableStats = {...p1High, ...p2High};

    if (stableStats.length == 4) {
      final avgPotentials = <String, double>{};
      for (final statName in ['speed', 'intelligence', 'strength', 'beauty']) {
        final p1Val = statName == 'speed'
            ? parent1.speedPotential
            : statName == 'intelligence'
            ? parent1.intelligencePotential
            : statName == 'strength'
            ? parent1.strengthPotential
            : parent1.beautyPotential;
        final p2Val = statName == 'speed'
            ? parent2.speedPotential
            : statName == 'intelligence'
            ? parent2.intelligencePotential
            : statName == 'strength'
            ? parent2.strengthPotential
            : parent2.beautyPotential;
        avgPotentials[statName] = (p1Val + p2Val) / 2.0;
      }

      final lowestStat = avgPotentials.entries
          .reduce((a, b) => a.value < b.value ? a : b)
          .key;
      stableStats.remove(lowestStat);
    }

    // Find the TRUE lowest stat (the 4th one) - this becomes our wildcard
    final allStats = ['speed', 'intelligence', 'strength', 'beauty'];
    final wildcardStat = allStats.firstWhere(
      (stat) => !stableStats.contains(stat),
      orElse: () => 'beauty',
    );

    print('=== WILDCARD STAT: $wildcardStat ===');

    // Generate base stats normally
    final newStats = [
      blendBaseStat(parent1.speed, parent2.speed, 'speed'),
      blendBaseStat(parent1.intelligence, parent2.intelligence, 'intelligence'),
      blendBaseStat(parent1.strength, parent2.strength, 'strength'),
      blendBaseStat(parent1.beauty, parent2.beauty, 'beauty'),
    ];

    // Generate potentials with THREE types: stable, volatile, and WILDCARD
    final statNames = ['speed', 'intelligence', 'strength', 'beauty'];
    final parentPotentials = [
      (parent1.speedPotential, parent2.speedPotential),
      (parent1.intelligencePotential, parent2.intelligencePotential),
      (parent1.strengthPotential, parent2.strengthPotential),
      (parent1.beautyPotential, parent2.beautyPotential),
    ];

    final newPotentials = <double>[];

    for (int i = 0; i < 4; i++) {
      final statName = statNames[i];
      final p1Val = parentPotentials[i].$1;
      final p2Val = parentPotentials[i].$2;

      double potential;

      if (statName == wildcardStat) {
        // 🔥 WILDCARD: Weighted random 0.0 to 5.0
        // Jackpot (4.5-5.0) is SUPER rare: 1/50 (2%)
        final roll = rng.nextDouble();

        if (roll < 0.02) {
          // 2% chance (1/50): JACKPOT!!! (4.5 to 5.0)
          potential = 4.5 + (rng.nextDouble() * 0.5);
          print(
            '  $statName: 🎰 JACKPOT WILDCARD = ${potential.toStringAsFixed(2)}',
          );
        } else if (roll < 0.12) {
          // 10% chance: TERRIBLE (0.0 to 1.0)
          potential = rng.nextDouble() * 1.0;
        } else if (roll < 0.32) {
          // 20% chance: Low (1.0 to 2.0)
          potential = 1.0 + (rng.nextDouble() * 1.0);
        } else if (roll < 0.72) {
          // 40% chance: Average (2.0 to 4.0)
          potential = 2.0 + (rng.nextDouble() * 2.0);
        } else {
          // 28% chance: High (4.0 to 4.5)
          potential = 4.0 + (rng.nextDouble() * 0.5);
        }

        print('  $statName: WILDCARD ROLL = ${potential.toStringAsFixed(2)}');
      } else if (stableStats.contains(statName)) {
        // STABLE: Top 2-3 stats blend normally
        potential = blendPotentialStable(p1Val, p2Val, statName);
      } else {
        // VOLATILE: Remaining low stat has wild variance
        final avg = (p1Val + p2Val) / 2.0;
        final volatility = rng.nextDouble();

        if (volatility < 0.30) {
          // 30% chance: BIG SPIKE (+0.5 to +1.2)
          potential = avg + 0.5 + (rng.nextDouble() * 0.7);
        } else if (volatility < 0.40) {
          // 10% chance: moderate gain (+0.2 to +0.5)
          potential = avg + 0.2 + (rng.nextDouble() * 0.3);
        } else if (volatility < 0.60) {
          // 20% chance: slight drop (-0.1 to -0.3)
          potential = avg - 0.1 - (rng.nextDouble() * 0.2);
        } else {
          // 40% chance: BIG DROP (-0.5 to -1.4)
          potential = avg - 0.5 - (rng.nextDouble() * 0.9);
        }

        // Still apply nature bonus for volatile
        final childBoosted = natureBoostsStat(childNatureId, statName);
        if (childBoosted) {
          potential += 0.15;
        }

        potential = potential.clamp(1.0, 5.0);
      }

      newPotentials.add(potential);
    }

    // Ensure starting stats don't exceed potential
    for (int i = 0; i < 4; i++) {
      newStats[i] = min(newStats[i], newPotentials[i]);
    }

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

    final size = genetics.get('size') ?? 'Normal';

    switch (size) {
      case 'tiny':
        return copyWith(
          speed: (speed * 1.10).clamp(0.0, speedPotential),
          strength: (strength * 0.90).clamp(0.0, 5.0),
          speedPotential: (speedPotential * 1.05).clamp(1.0, 5.0),
          strengthPotential: (strengthPotential * 0.98).clamp(1.0, 5.0),
        );
      case 'giant':
        return copyWith(
          speed: (speed * 0.90).clamp(0.0, 5.0),
          strength: (strength * 1.10).clamp(0.0, strengthPotential),
          speedPotential: (speedPotential * 0.98).clamp(1.0, 5.0),
          strengthPotential: (strengthPotential * 1.05).clamp(1.0, 5.0),
        );
      case 'small':
        return copyWith(
          speed: (speed * 1.05).clamp(0.0, speedPotential),
          strength: (strength * 0.95).clamp(0.0, 5.0),
          speedPotential: (speedPotential * 1.02).clamp(1.0, 5.0),
          strengthPotential: (strengthPotential * 0.99).clamp(1.0, 5.0),
        );
      case 'large':
        return copyWith(
          speed: (speed * 0.95).clamp(0.0, 5.0),
          strength: (strength * 1.05).clamp(0.0, strengthPotential),
          speedPotential: (speedPotential * 0.99).clamp(1.0, 5.0),
          strengthPotential: (strengthPotential * 1.02).clamp(1.0, 5.0),
        );
      default: // normal
        return this;
    }
  }

  CreatureStats applyNature(String? natureId) {
    if (natureId == null) return this;

    const statBoost = 0.25;
    const potentialBoost = 0.2;

    switch (natureId) {
      case 'Swift':
        return copyWith(
          speed: (speed + statBoost).clamp(0.0, speedPotential),
          speedPotential: (speedPotential + potentialBoost).clamp(1.0, 5.0),
        );
      case 'Clever':
        return copyWith(
          intelligence: (intelligence + statBoost).clamp(
            0.0,
            intelligencePotential,
          ),
          intelligencePotential: (intelligencePotential + potentialBoost).clamp(
            1.0,
            5.0,
          ),
        );
      case 'Mighty':
        return copyWith(
          strength: (strength + statBoost).clamp(0.0, strengthPotential),
          strengthPotential: (strengthPotential + potentialBoost).clamp(
            1.0,
            5.0,
          ),
        );
      case 'Elegant':
        return copyWith(
          beauty: (beauty + statBoost).clamp(0.0, beautyPotential),
          beautyPotential: (beautyPotential + potentialBoost).clamp(1.0, 5.0),
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
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      intelligence: (json['intelligence'] as num?)?.toDouble() ?? 1.0,
      strength: (json['strength'] as num?)?.toDouble() ?? 1.0,
      beauty: (json['beauty'] as num?)?.toDouble() ?? 1.0,
      speedPotential: (json['speedPotential'] as num?)?.toDouble() ?? 2.0,
      intelligencePotential:
          (json['intelligencePotential'] as num?)?.toDouble() ?? 2.0,
      strengthPotential: (json['strengthPotential'] as num?)?.toDouble() ?? 2.0,
      beautyPotential: (json['beautyPotential'] as num?)?.toDouble() ?? 2.0,
    );
  }
}

class _StatParams {
  final double baseMean;
  final double baseStddev;
  final double potentialMean;
  final double potentialStddev;

  _StatParams({
    required this.baseMean,
    required this.baseStddev,
    required this.potentialMean,
    required this.potentialStddev,
  });
}

// Stat description helpers (updated for 0-5 scale)
class StatDescriptions {
  static String describeSpeed(double value) {
    if (value <= 1.0) return 'Sluggish';
    if (value <= 2.0) return 'Slow';
    if (value <= 3.0) return 'Average';
    if (value <= 4.0) return 'Fast';
    return 'Blazing';
  }

  static String describeIntelligence(double value) {
    if (value <= 1.0) return 'Simple';
    if (value <= 2.0) return 'Dim';
    if (value <= 3.0) return 'Average';
    if (value <= 4.0) return 'Smart';
    return 'Genius';
  }

  static String describeStrength(double value) {
    if (value <= 1.0) return 'Frail';
    if (value <= 2.0) return 'Weak';
    if (value <= 3.0) return 'Average';
    if (value <= 4.0) return 'Strong';
    return 'Mighty';
  }

  static String describeBeauty(double value) {
    if (value <= 1.0) return 'Homely';
    if (value <= 2.0) return 'Plain';
    if (value <= 3.0) return 'Average';
    if (value <= 4.0) return 'Attractive';
    return 'Stunning';
  }

  static String describePotential(double value) {
    if (value <= 1.5) return 'Limited';
    if (value <= 2.5) return 'Good';
    if (value <= 3.5) return 'Great';
    if (value <= 4.3) return 'Exceptional';
    return 'Legendary';
  }

  static String getOverallDescription(CreatureStats stats) {
    final total =
        stats.speed + stats.intelligence + stats.strength + stats.beauty;

    if (total <= 4.0) return 'This creature has modest abilities.';
    if (total <= 8.0) return 'This creature shows average potential.';
    if (total <= 12.0) return 'This creature has impressive capabilities.';
    if (total <= 16.0) return 'This creature displays remarkable prowess.';
    return 'This creature possesses legendary attributes!';
  }

  static String getPotentialDescription(CreatureStats stats) {
    final totalPotential =
        stats.speedPotential +
        stats.intelligencePotential +
        stats.strengthPotential +
        stats.beautyPotential;

    if (totalPotential <= 8.0) return 'Limited growth potential.';
    if (totalPotential <= 10.0) return 'Average growth potential.';
    if (totalPotential <= 13.0) return 'Excellent growth potential!';
    if (totalPotential <= 16.0) return 'Exceptional growth potential!';
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
