import 'dart:math';

/// Rules for the rare item that permanently improves one chosen Potential.
abstract final class PotentialSoulRules {
  static const int minGain = 1;
  static const int maxGain = 5;

  static int rollGain(Random rng) => minGain + rng.nextInt(maxGain);

  /// Potential Souls begin appearing only in serious Survival runs and stay
  /// much rarer than Power Orbs because they improve inheritable genetics.
  static bool rollsFromSurvival(int wave, Random rng) {
    final chance = wave >= 50
        ? 0.10
        : wave >= 40
        ? 0.06
        : wave >= 30
        ? 0.03
        : 0.0;
    return chance > 0 && rng.nextDouble() < chance;
  }

  /// Raids are time-gated and are the primary repeatable source of Souls.
  static bool rollsFromRaid(Random rng) => rng.nextDouble() < 0.50;
}
