import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/stat_system.dart';

class CosmicSurvivalBalance {
  /// Encounter budgets belong to the wave, not to each independently rolled boss.
  static int bossCountForWave(int wave) {
    if (wave <= 0 || wave % 5 != 0) return 0;
    if (wave % 25 == 0 || const [20, 30, 40, 50].contains(wave)) return 1;
    if (wave < 15) return 1;
    return wave <= 50 ? 2 : 3;
  }

  static double bossHealthForWave(int wave, {required bool titanic}) {
    final base = 42.0 * 16 * 1.55 * enemyWaveHpScale(wave);
    // The old titanic multiplier was almost seven ordinary bosses' health.
    // Three bodies' worth leaves time to manage the outbreak and escorts.
    // Strong breeding accelerates late-wave kills. Extend boss encounters
    // gradually after wave 10, keeping opening waves and orb damage intact.
    return base *
        (1.0 + max(0, wave - 10) * 0.018) *
        (titanic
            ? 3.2
            : wave == 5
            ? 1.2
            : 1.0);
  }

  static double alchemicalMeterCapacity(int wave) {
    final steps = max(0, wave - 1);
    // Keep the early curve, then continue gently beyond the old wave-31 cap.
    return 100 * (1 + min(steps, 30) * 0.08 + max(0, steps - 30) * 0.025);
  }

  static double bossAlchemyReward(int wave) {
    final count = bossCountForWave(wave);
    if (count == 0) return 0;
    final waveBudget =
        alchemicalMeterCapacity(wave) * (wave % 25 == 0 ? 0.70 : 0.55);
    return waveBudget / count;
  }

  static int bossEscortCount(int wave) =>
      (8 + wave * 0.36).round().clamp(8, 30);
  static double bossEscortInterval(int wave) =>
      (1.25 - wave * 0.008).clamp(0.75, 1.25);
  static int activeEnemyLimit(int wave, {required bool bossWave}) =>
      bossWave ? 24 : (24 + wave * 0.65).round().clamp(24, 56);

  /// Layered elite/body/trait multipliers must not turn one leaked enemy into
  /// an instant loss. Several missed intercepts remain dangerous.
  static double orbContactDamage(
    double raw,
    double maxHp, {
    required bool heavy,
    required bool breaker,
  }) => min(raw, maxHp * (heavy ? 0.22 : 0.10) * (breaker ? 1.2 : 1.0));

  static double survivalStatPower(double stat) {
    final legacy = CosmicBalance.legacyStat(stat);
    final normalized = ((legacy - 1.0) / 4.0).clamp(0.0, 1.0);
    var power = pow(normalized, 0.95).toDouble();
    if (legacy >= 2.0) power += 0.06;
    if (legacy >= 3.0) power += 0.10;
    if (legacy >= 4.0) power += 0.16;
    if (legacy >= 4.5) power += 0.12;
    final overcap = AlchemonStatSystem.combatOvercapProgress(stat);
    return power * (1.0 + overcap * 0.30);
  }

  static double qualityScore(double stat) {
    final power = survivalStatPower(stat);
    final normalized = AlchemonStatSystem.combatProgress(stat);
    return 0.35 + power * 0.9 + normalized * 0.75;
  }

  static int estimatedWaveReach({
    required double averageStat,
    int teamSize = 1,
    int extraCompanionSlots = 0,
    int perkLevels = 0,
  }) {
    final safeTeamSize = teamSize.clamp(1, 5);
    final activeCompanions = min(
      5,
      max(1, safeTeamSize + extraCompanionSlots),
    ).toDouble();
    final quality = qualityScore(averageStat);
    final teamFactor = 0.90 + pow(activeCompanions, 0.55).toDouble() * 0.45;
    final perkFactor = 1.0 + perkLevels * 0.025;
    final raw =
        3.0 + pow(quality, 1.55).toDouble() * 8.8 * teamFactor * perkFactor;
    return raw.round().clamp(1, 99);
  }

  static double enemyWaveHpScale(int wave) {
    if (wave <= 1) return 1.0;
    final base = 1.0 + pow(wave - 1, 1.12).toDouble() * 0.042;
    return base * (1.0 + max(0, wave - 10) * 0.008);
  }

  static double enemyWaveDamageScale(int wave) {
    if (wave <= 1) return 1.0;
    // Steeper damage curve so late-wave enemies (especially big slow ones)
    // stay genuinely threatening rather than becoming damage sponges.
    return 1.0 + pow(wave - 1, 1.22).toDouble() * 0.017;
  }

  static double enemyWaveSpeedScale(int wave) {
    if (wave <= 1) return 1.0;
    return 1.0 + pow(wave - 1, 0.85).toDouble() * 0.006;
  }
}
