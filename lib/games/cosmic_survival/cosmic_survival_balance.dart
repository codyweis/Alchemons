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
  /// and the rim opens to its full width by wave 40 — clumping is a ramp, not
  /// a difficulty cut.
  ///
  /// It used to be full by wave 11. Fronts from every side at once are a
  /// test of being in three places, which no amount of breeding passes: a
  /// level-5 team fell on the same waves (12–13) as a level-1 team.
  static double hordeFrontOpenness(int wave) =>
      (0.38 + (wave - 1) * 0.62 / 39).clamp(0.38, 1.0);

  /// Siege artillery per wave: walks in with the front, parks at
  /// [artilleryHoldRange] and shells the orb until something kills it.
  static int artilleryCountForWave(int wave) =>
      wave < 6 ? 0 : (2 + (wave - 6) ~/ 5).clamp(2, 14);

  /// A shell's damage, as a share of the artillery body's own.
  ///
  /// Shells land from past every companion's reach, so they cost a weak and a
  /// strong team the same. At 1.9 they were 50–85% of the orb's damage in
  /// waves 6–12 of a real run, and the reason level barely mattered there.
  static const double artilleryShellDamage = 1.14;

  /// Where artillery parks and shells from, measured from the orb.
  ///
  /// It parked at 820 (kSiegeHoldRange), past every companion working the
  /// orb, so only the pilot could answer it and it drained a level-10 orb as
  /// fast as a level-1 one. At 520 it sits in the middle ring the Manes and
  /// Masks patrol, with [artilleryHp] to make reaching it a test of what the
  /// team can kill.
  static const double artilleryHoldRange = 520;

  /// Artillery health, as a share of its sentinel body's (was 0.85).
  static const double artilleryHp = 2.55;

  /// Opening bodies' health: double through wave 8, back to normal by wave
  /// 11. The opening waves are where a fresh team should meet its limit, and
  /// HP there is something only the team's damage answers.
  static double openingBodyHp(int wave) =>
      1.0 + ((11 - wave) / 3).clamp(0.0, 1.0);

  /// A brute's siege beam, as a share of the brute's own damage, by wave.
  ///
  /// The beam is 900 long and crosses the whole line: it took more off a
  /// level-10 team's companions in waves 16–20 than every body they touched.
  /// It comes in at 0.57 and builds to its full 1.9 over waves 24–31, where
  /// the stat walls are measured (docs/survival_stat_walls.md).
  static double bruteBeamDamage(int wave) =>
      1.9 * (0.3 + 0.7 * ((wave - 24) / 7).clamp(0.0, 1.0));

  /// What a cleared wave gives back, as a share of the orb's and each
  /// fielded companion's maximum health: nothing through wave 10, then 5%
  /// more each wave to 60% from wave 22.
  ///
  /// A team that holds a wave keeps going; one that leaks more than this
  /// each wave still runs out. Waves 1–10 stay without it, so a fresh team
  /// is judged on what it can kill there.
  static double waveRestShare(int wave) =>
      0.6 * ((wave - 10) / 12).clamp(0.0, 1.0);

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

  /// The meter is budgeted per wave: a cleared ordinary wave fills it about
  /// once, so the upgrade draft opens roughly once a wave instead of every
  /// 8-15 s. Income is per body (a wisp pays 3 x 0.96 x 0.5, then the kill
  /// pacing multiplier that settles near 0.7), so capacity follows the wave's
  /// body count. The pre-horde curve stays as a floor: waves 1-9 send too few
  /// bodies to fill it, which is the slow opening they always had.
  ///
  /// Measured by test/survival_meter_pacing_test.dart.
  static const double alchemicalMeterPerBody = 1.25;

  static double alchemicalMeterCapacity(int wave) {
    final steps = max(0, wave - 1);
    final legacy =
        100 * (1 + min(steps, 30) * 0.08 + max(0, steps - 30) * 0.025);
    return max(legacy, hordeCountForWave(wave) * alchemicalMeterPerBody);
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

  ///
  /// The climb reads [latePressure], so it starts at wave 60 and reaches
  /// 3,000 at wave 160. Wave 100 holds 1,800, under the 2,000 measured as
  /// sustainable on the Fold.
  static int hordeActiveCeilingForWave(int wave) {
    final w = latePressure(wave);
    return w <= 50
        ? hordeActiveCeiling
        : (hordeActiveCeiling +
                  (hordeLateActiveCeiling - hordeActiveCeiling) * (w - 50) / 50)
              .round()
              .clamp(hordeActiveCeiling, hordeLateActiveCeiling);
  }

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
    return power * (1.0 + overcap * statPowerPastKnee);
  }

  /// How much power a stat keeps buying past internal 5 — about Potential 70
  /// on an average species, where the authored 1-5 curve ends.
  ///
  /// This was 0.30, and it made the top of the grind worth almost nothing:
  /// P70 to P100 with full Enhancement doubled the stat on screen (504 to
  /// 1056) but added about 35% damage, and moved the survival wall from
  /// wave 37 to 47. At 1.17 the curve keeps the slope it had below the knee
  /// (about +0.42 power per internal point) up to 9, then tapers on
  /// [AlchemonStatSystem.combatOvercapProgress]'s log tail, so a perfect
  /// creature is roughly 2.4x an average one and nothing runs away. Below the
  /// knee nothing changes: everyday creatures, wilds and the arena band
  /// (capped at 5) hit exactly as hard as before.
  static const double statPowerPastKnee = 1.17;

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
  ///
  /// Past [latePressureWave] it climbs at half pace — see [latePressure].
  static double enemyWaveHpScale(int wave) {
    if (wave <= 1) return 1.0;
    final w = latePressure(wave);
    final base = 1.0 + pow(w - 1, 1.12).toDouble() * 0.032;
    return base * (1.0 + max(0.0, w - 10) * 0.004);
  }

  /// Where the run turns into the grinder's endgame.
  ///
  /// Until here the curves are what they always were, and a decent team
  /// (about Potential 70) meets its wall around this wave. Beyond it, every
  /// wave a team survives is paid for by its stats: breeding and Enhancement
  /// are the only way further. Measured on the benchmark party
  /// (docs/survival_stat_walls.md): with the wave curves at full pace past
  /// here, P90 walled at wave 48 and a perfect team at 63. At half pace the
  /// walls spread toward roughly P90 60, P100 70, perfect 80.
  static const int latePressureWave = 40;
  static const double latePressureRate = 0.5;

  /// The wave number the pressure curves read: the real wave up to
  /// [latePressureWave], then half a wave for every wave past it. Wave 80
  /// presses like wave 60 used to.
  static double latePressure(int wave) => wave <= latePressureWave
      ? wave.toDouble()
      : latePressureWave + (wave - latePressureWave) * latePressureRate;

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
  ///
  /// Past [latePressureWave] it climbs at half pace, with health, so the two
  /// keep rising together.
  static double enemyWaveDamageScale(int wave) {
    if (wave <= 1) return 1.0;
    return 1.0 + pow(latePressure(wave) - 1, 1.22).toDouble() * 0.026;
  }

  /// The share of each hit the orb actually takes, by wave.
  ///
  /// Every Horn and Kin shield used to be copied onto the orb as well (70%,
  /// up to 45% of the orb), a second health bar that refilled on every cast.
  /// A fresh level-1 team rode it from wave 9 to wave 12, and on the stat-wall
  /// benchmark it was worth about 7 waves at P50 and 10 at P100 + E10. With
  /// the copy gone the orb hardens as the run goes on instead: every point
  /// lands through wave [orbHardeningWave], where a weak team falls, then a
  /// falling share: 0.88 at wave 12, 0.59 at 20, 0.42 at 30, 0.32 at 40, 0.22
  /// at 80 (it reads [latePressure]). That puts the level-10 walls back
  /// within a wave or two of where they were (docs/survival_stat_walls.md)
  /// and leaves the opening waves alone.
  static const int orbHardeningWave = 10;
  static const double orbHardeningRate = 0.07;

  static double orbWaveDamageShare(int wave) {
    final past = latePressure(wave) - orbHardeningWave;
    return past <= 0 ? 1.0 : 1.0 / (1.0 + past * orbHardeningRate);
  }

  static double enemyWaveSpeedScale(int wave) {
    if (wave <= 1) return 1.0;
    return 1.0 + pow(latePressure(wave) - 1, 0.85).toDouble() * 0.006;
  }
}
