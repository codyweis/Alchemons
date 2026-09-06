import 'dart:math';
import 'package:alchemons/helpers/nature_loader.dart';

/// Fixed, species-level stat ratings. These describe what a species is good at
/// and are shared by every individual of that species.
class SpeciesBaseStats {
  final int speed;
  final int intelligence;
  final int strength;
  final int beauty;

  const SpeciesBaseStats({
    required this.speed,
    required this.intelligence,
    required this.strength,
    required this.beauty,
  });

  factory SpeciesBaseStats.fromJson(Map<String, dynamic> json) {
    int read(String key) => ((json[key] as num?)?.round() ?? 50).clamp(1, 100);
    return SpeciesBaseStats(
      speed: read('speed'),
      intelligence: read('intelligence'),
      strength: read('strength'),
      beauty: read('beauty'),
    );
  }

  Map<String, int> toJson() => {
    'speed': speed,
    'intelligence': intelligence,
    'strength': strength,
    'beauty': beauty,
  };
}

/// The canonical rules for Alchemon stats.
///
/// Combat still consumes the historical 0-5-ish values. New progression is
/// calculated here and converted to that internal scale, while player-facing
/// ratings use larger whole numbers (`internal * 100`) so Power cannot be
/// confused with the separate 1-100 Potential score. Keeping presentation
/// separate lets combat retain its proven scale without imposing a stat cap.
abstract final class AlchemonStatSystem {
  static const int maxLevel = 10;
  static const int maxPotential = 100;
  static const int maxEnhancementRank = 10;
  static const double potentialBonusPerPoint = 0.003;
  static const double enhancementBonusPerRank = 0.03;
  static const double matchingNatureBonus = 0.05;
  static const double speciesPointsPerInternalPoint = 20.0;
  static const double displayPointsPerInternalPoint = 100.0;
  static const double legacyCombatCeiling = 5.0;

  /// Legacy-authored reference for encounter thresholds. This is not a clamp
  /// on stored or displayed player stats.
  static const double authoredStatReference = 9.0;

  static int normalizePotential(num value, {bool legacyScale = false}) {
    final raw = value.toDouble();
    final scaled = legacyScale ? raw * 20.0 : raw;
    return scaled.round().clamp(1, maxPotential);
  }

  /// Old payloads stored all four potentials on a 0-5 scale. Detecting the
  /// complete set avoids mistaking a legitimate new 1-5 roll for old data.
  static bool usesLegacyPotentialScale(Iterable<num> values) {
    final list = values.toList(growable: false);
    return list.isNotEmpty && list.every((value) => value <= 5.0);
  }

  static int rollPotential(Random rng) => 1 + rng.nextInt(maxPotential);

  /// Substantial Silver sink for permanent, inheritable Potential growth.
  /// Costs rise sharply as a stat approaches perfection.
  static int potentialSoulSilverCost(num currentPotential) {
    final potential = normalizePotential(currentPotential);
    if (potential < 60) return 10000;
    if (potential < 80) return 20000;
    if (potential < 90) return 35000;
    return 50000;
  }

  /// Independent four-stat inheritance: 35% parent A, 35% parent B, and 30%
  /// a fresh genetic roll. The extra parental weight offsets the difficulty of
  /// assembling four excellent Potentials while preserving genetic surprises.
  static int inheritPotential(Random rng, num parentA, num parentB) {
    final roll = rng.nextDouble();
    if (roll < 0.35) return normalizePotential(parentA);
    if (roll < 0.70) return normalizePotential(parentB);
    return rollPotential(rng);
  }

  static double levelMultiplier(int level) {
    final safeLevel = level.clamp(1, maxLevel);
    return 0.55 + ((safeLevel - 1) * 0.05);
  }

  static double potentialMultiplier(num potential) =>
      1.0 + normalizePotential(potential) * potentialBonusPerPoint;

  static double enhancementMultiplier(int rank) =>
      1.0 + rank.clamp(0, maxEnhancementRank) * enhancementBonusPerRank;

  static double natureMultiplier(
    String? natureId,
    String statKey, [
    String? natureId2,
  ]) {
    final key = 'stat_${statKey}_bonus';
    var bonus = 0.0;
    for (final id in {natureId, natureId2}) {
      if (id == null || id.isEmpty) continue;
      bonus += NatureCatalog.byId(id)?.effect.getDouble(key, fallback: 0) ?? 0;
    }
    return 1.0 + bonus;
  }

  static double effectiveInternal({
    required int speciesBase,
    required int level,
    required num potential,
    int enhancementRank = 0,
    double additionalMultiplier = 1.0,
  }) {
    return (speciesBase / speciesPointsPerInternalPoint) *
        levelMultiplier(level) *
        potentialMultiplier(potential) *
        enhancementMultiplier(enhancementRank) *
        additionalMultiplier;
  }

  static int displayRating(num internalValue) =>
      max(0, (internalValue * displayPointsPerInternalPoint).round());

  /// A soft, uncapped visual scale. It approaches a full bar without any
  /// numeric rating ever hitting a ceiling.
  static double displayFraction(num internalValue) {
    final rating = displayRating(internalValue).toDouble();
    return rating <= 0 ? 0 : rating / (rating + 250.0);
  }

  /// Normalized strength for gameplay systems authored around the former
  /// 1-5 stat band. Values through 5 retain their exact old curve; Power above
  /// 100 earns up to 30% overcap strength instead of being silently discarded.
  static double combatProgress(num internalValue) {
    final value = max(1.0, internalValue.toDouble());
    final legacy = value.clamp(1.0, legacyCombatCeiling);
    final legacyProgress = (legacy - 1.0) / (legacyCombatCeiling - 1.0);
    return legacyProgress * (1.0 + 0.30 * combatOvercapProgress(value));
  }

  static double combatOvercapProgress(num internalValue) {
    final value = max(legacyCombatCeiling, internalValue.toDouble());
    if (value <= 9.0) return (value - legacyCombatCeiling) / 4.0;
    // Preserve the old curve exactly through internal 9, then continue
    // forever with diminishing returns rather than imposing a hard ceiling.
    return 1.0 + log(1.0 + (value - 9.0) / 4.0);
  }

  /// Converts a current stat back into the old 1-5 gameplay band, including
  /// the controlled overcap. This is useful for scored activities whose
  /// authored thresholds are expressed as legacy ratings rather than as a
  /// multiplier.
  static double legacyGameplayRating(num internalValue) =>
      1.0 + combatProgress(internalValue) * 4.0;

  static int orbCostForNextRank(int currentRank) {
    final next = currentRank + 1;
    final baseCost = switch (next) {
      <= 3 => 1,
      <= 6 => 2,
      <= 9 => 4,
      _ => 6,
    };
    return baseCost;
  }
}
