import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/stat_system.dart';

class CosmicSurvivalBalance {
  /// Applied once at the common grant boundary, after source/passive bonuses.
  static const double alchemicalRewardMultiplier = 0.5;

  /// Most extra bodies are slow chaff. Progression adds density, not sponges.
  static int hordeCountForWave(int wave) =>
      (16 + wave * 6 + pow(max(0, wave - 4), 1.55) * 5).round().clamp(
        24,
        hordeWaveTotalCeiling,
      );
  static int hordeBatchSize(int wave) => (6 + wave).clamp(6, 48);

  /// Plain horde bodies move at this share of their tier speed: a wisp takes
  /// ~20 s to cross from the rim to the orb, long enough to read a front and
  /// choose where to break it.
  static const double hordeBodySpeedMultiplier = 0.6;
  static const double hordeSpawnGap = pi / 3;

  /// How much of the usable rim the wave's fronts are allowed to occupy.
  ///
  /// The per-band smear is wave-size-independent: 24 bodies always stretch
  /// across the same slice of a front. That reads as a wall at wave 40 and as
  /// a picket line at wave 2, where a whole wave is one or two bands. Opening
  /// waves therefore arrive inside a narrow wedge you can stand in front of,
  /// and the rim opens to its full width by wave 11 — clumping is a ramp, not
  /// a difficulty cut.
  static double hordeFrontOpenness(int wave) =>
      (0.38 + (wave - 1) * 0.062).clamp(0.38, 1.0);

  /// Siege artillery per wave: walks in with the front, parks past companion
  /// reach and shells the orb. Something with range (a Wing beam, a Let
  /// skyfall) or a trip out to it has to answer these.
  static int artilleryCountForWave(int wave) =>
      wave < 6 ? 0 : (2 + (wave - 6) ~/ 5).clamp(2, 14);

  /// Broodmothers per wave: tough, slow bodies that keep feeding the front
  /// until they are cut out of it.
  static int broodCountForWave(int wave) =>
      wave < 8 ? 0 : (1 + (wave - 8) ~/ 9).clamp(1, 6);

  /// A broodmother's burst cadence and size.
  static const double broodInterval = 3.4;
  static const int broodBurst = 4;

  /// How far past the arena rim a walking body appears.
  static const double hordeSpawnBeyondRim = 70;

  /// Most bodies one wave can send in total.
  static const int hordeWaveTotalCeiling = 9000;

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

  /// Most bodies on the field at once. Device-measured (Galaxy Fold, profile,
  /// docs/horde_stress/README.md): after the round-2 fixes a sustained 2,000
  /// with five companions forcing specials held ~15 ms build / ~13 ms raster;
  /// 1,000 held ~8-10 ms. Through wave 50 the field holds at 1,000, leaving
  /// margin for everything a real run adds (bosses, sprites, HUD). Past 50 the
  /// run is meant to become an endurance spectacle: the ceiling climbs to
  /// 3,000 at wave 100. Waves still total more; they arrive as the field thins.
  static const int hordeActiveCeiling = 1000;
  static const int hordeLateActiveCeiling = 3000;

  static int hordeActiveCeilingForWave(int wave) => wave <= 50
      ? hordeActiveCeiling
      : (hordeActiveCeiling +
                (hordeLateActiveCeiling - hordeActiveCeiling) *
                    (wave - 50) /
                    50)
            .round()
            .clamp(hordeActiveCeiling, hordeLateActiveCeiling);

  static int activeEnemyLimit(int wave, {required bool bossWave}) => bossWave
      ? 24
      : (48 + wave * 14 + pow(max(0, wave - 6), 1.4) * 3).round().clamp(
          64,
          hordeActiveCeilingForWave(wave),
        );

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

  /// Enemy health by wave.
  ///
  /// Health used to outrun damage by roughly two to one — x5.65 against x2.96
  /// at wave 50 — which is the shape of a game that gets LONGER rather than
  /// harder. Late waves were sponges: no more likely to kill you, just slower
  /// to clear, and a fight you cannot lose is a fight that stops mattering
  /// however big its numbers get.
  ///
  /// Flattened to about x4 at wave 50, with the post-wave-10 compounding
  /// halved. The danger is moved onto the damage curve instead, where it can
  /// actually be felt.
  static double enemyWaveHpScale(int wave) {
    if (wave <= 1) return 1.0;
    final base = 1.0 + pow(wave - 1, 1.12).toDouble() * 0.032;
    return base * (1.0 + max(0, wave - 10) * 0.004);
  }

  /// Enemy damage by wave.
  ///
  /// Steepened to meet the flattened health curve: about x4 at wave 50 rather
  /// than x3, so the two now rise together instead of health running away.
  ///
  /// The early half of this curve is doing a second job. A five-minute
  /// autopilot run at wave 1 took ZERO damage to the orb and sat at full
  /// health the whole time — the party out-killed the spawn rate outright, so
  /// the thing you lose the run by was never in the fight. More damage per
  /// body is the honest lever for that: it costs the player something when one
  /// gets through, without spawning more of them.
  static double enemyWaveDamageScale(int wave) {
    if (wave <= 1) return 1.0;
    return 1.0 + pow(wave - 1, 1.22).toDouble() * 0.026;
  }

  static double enemyWaveSpeedScale(int wave) {
    if (wave <= 1) return 1.0;
    return 1.0 + pow(wave - 1, 0.85).toDouble() * 0.006;
  }
}
