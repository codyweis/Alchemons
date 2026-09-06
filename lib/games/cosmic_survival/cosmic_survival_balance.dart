import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/stat_system.dart';

class CosmicSurvivalBalance {
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
    return 1.0 + pow(wave - 1, 1.12).toDouble() * 0.042;
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
