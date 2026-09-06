// lib/models/creature_stats.dart

import 'dart:math';

import 'package:alchemons/models/stat_system.dart';

class CreatureStats {
  final double speed;
  final double intelligence;
  final double strength;
  final double beauty;

  // Immutable 1-100 genetic quality ratings for each stat.
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
    final potentials = List<int>.generate(
      4,
      (_) => AlchemonStatSystem.rollPotential(rng),
    );
    return CreatureStats(
      // Species-specific current values are calculated once the offspring
      // species is known. These neutral values are only fallback snapshots.
      speed: 1.0,
      intelligence: 1.0,
      strength: 1.0,
      beauty: 1.0,
      speedPotential: potentials[0].toDouble(),
      intelligencePotential: potentials[1].toDouble(),
      strengthPotential: potentials[2].toDouble(),
      beautyPotential: potentials[3].toDouble(),
    );
  }

  /// Only genetic Potential is inherited. Species base stats, level, Nature,
  /// and Enhancement belong to the child and are never copied from a parent.
  factory CreatureStats.breed(
    CreatureStats parent1,
    CreatureStats parent2,
    Random rng,
  ) {
    return CreatureStats(
      speed: 1.0,
      intelligence: 1.0,
      strength: 1.0,
      beauty: 1.0,
      speedPotential: AlchemonStatSystem.inheritPotential(
        rng,
        parent1.speedPotential,
        parent2.speedPotential,
      ).toDouble(),
      intelligencePotential: AlchemonStatSystem.inheritPotential(
        rng,
        parent1.intelligencePotential,
        parent2.intelligencePotential,
      ).toDouble(),
      strengthPotential: AlchemonStatSystem.inheritPotential(
        rng,
        parent1.strengthPotential,
        parent2.strengthPotential,
      ).toDouble(),
      beautyPotential: AlchemonStatSystem.inheritPotential(
        rng,
        parent1.beautyPotential,
        parent2.beautyPotential,
      ).toDouble(),
    );
  }

  CreatureStats applyNature(String? natureId) => applyNatures(natureId, null);

  CreatureStats applyNatures(String? natureId, String? natureId2) => copyWith(
    speed:
        speed *
        AlchemonStatSystem.natureMultiplier(natureId, 'speed', natureId2),
    intelligence:
        intelligence *
        AlchemonStatSystem.natureMultiplier(
          natureId,
          'intelligence',
          natureId2,
        ),
    strength:
        strength *
        AlchemonStatSystem.natureMultiplier(natureId, 'strength', natureId2),
    beauty:
        beauty *
        AlchemonStatSystem.natureMultiplier(natureId, 'beauty', natureId2),
  );

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

  Map<String, dynamic> toJson() => {
    'statScaleVersion': 2,
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
    final potentialValues = <num>[
      (json['speedPotential'] as num?) ?? 50,
      (json['intelligencePotential'] as num?) ?? 50,
      (json['strengthPotential'] as num?) ?? 50,
      (json['beautyPotential'] as num?) ?? 50,
    ];
    final scaleVersion = (json['statScaleVersion'] as num?)?.toInt() ?? 1;
    final legacyScale =
        scaleVersion < 2 &&
        AlchemonStatSystem.usesLegacyPotentialScale(potentialValues);
    return CreatureStats(
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      intelligence: (json['intelligence'] as num?)?.toDouble() ?? 1.0,
      strength: (json['strength'] as num?)?.toDouble() ?? 1.0,
      beauty: (json['beauty'] as num?)?.toDouble() ?? 1.0,
      speedPotential: AlchemonStatSystem.normalizePotential(
        potentialValues[0],
        legacyScale: legacyScale,
      ).toDouble(),
      intelligencePotential: AlchemonStatSystem.normalizePotential(
        potentialValues[1],
        legacyScale: legacyScale,
      ).toDouble(),
      strengthPotential: AlchemonStatSystem.normalizePotential(
        potentialValues[2],
        legacyScale: legacyScale,
      ).toDouble(),
      beautyPotential: AlchemonStatSystem.normalizePotential(
        potentialValues[3],
        legacyScale: legacyScale,
      ).toDouble(),
    );
  }
}

// Stat description helpers. Current combat values remain internally normalized;
// Potential is a 1-100 genetic rating.
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
    final potential = AlchemonStatSystem.normalizePotential(value);
    if (potential <= 20) return 'Limited';
    if (potential <= 40) return 'Good';
    if (potential <= 60) return 'Great';
    if (potential <= 85) return 'Exceptional';
    return 'Legendary';
  }

  static String getOverallDescription(CreatureStats stats) {
    final total =
        stats.speed + stats.intelligence + stats.strength + stats.beauty;

    if (total <= 4.0) return 'This creature has modest abilities.';
    if (total <= 8.0) return 'This creature has solid capabilities.';
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

    if (totalPotential <= 80.0) return 'Limited genetic potential.';
    if (totalPotential <= 160.0) return 'Average genetic potential.';
    if (totalPotential <= 240.0) return 'Excellent genetic potential!';
    if (totalPotential <= 340.0) return 'Exceptional genetic potential!';
    return 'Legendary genetic potential!!';
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
