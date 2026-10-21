import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/stat_system.dart';

class CosmicSurvivalBalance {
  /// Applied once at the common grant boundary, after source/passive bonuses.
  static const double alchemicalRewardMultiplier = 0.5;

  /// Most extra bodies are slow chaff. Progression adds density, not sponges.
  static int hordeCountForWave(int wave) =>
      ((16 + wave * 6 + pow(max(0, wave - 4), 1.55) * 5) *
              hordeDensity(wave))
          .round()
          .clamp(24, hordeWaveTotalCeiling);

  /// How many more bodies a wave sends than it did before the 2026-10-20
  /// family rebuild: none through wave [hordeDensityWave], then a growing
  /// share, 80% more ([hordeDensityGain]) from wave 33 on.
  ///
  /// The rebuild's gains were mostly bodies per cast and a front held off
  /// the orb (Wing's focus beams, Mane's longer catapults, Mask traps on the
  /// orb's approach). A team at its wall now got through about twice the
  /// horde health a wave it used to: P70 held to wave 61, P90 to 76, a
  /// perfect team past 110. More bodies answer most of that without making
  /// each one a sponge, so every family meets the bodies it was balanced
  /// against; [pressureLead] does the rest. The meter's capacity follows
  /// the count, so the draft still opens about once a wave. The field holds
  /// what it held, so a wall wave runs longer instead of fuller: 50–85 s for
  /// a team near its wall, about 40 s before the rebuild.
  static const int hordeDensityWave = 25;
  static const double hordeDensityGain = 0.8;

  static double hordeDensity(int wave) =>
      1.0 + hordeDensityGain * ((wave - hordeDensityWave) / 8).clamp(0.0, 1.0);

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

  /// Menders per wave: one from wave 12, one more every ten waves, four at
  /// most. They walk in spread through the wave, not all with its first band.
  static int menderCountForWave(int wave) =>
      wave < 12 ? 0 : (1 + (wave - 12) ~/ 10).clamp(1, 4);

  /// How far from the orb a mender stops: behind the front, inside the ring
  /// the Manes and Masks patrol, so something has to go out and get it.
  static const double menderHoldRange = 440;

  /// A mender's health, as a share of its phantom body's. The same as
  /// artillery's: a target to pick, not a wall.
  static const double menderHp = 1.5;

  /// Seconds between a mender's pulses.
  static const double menderPulseInterval = 2.5;

  /// How far a mender reaches the wounded.
  static const double menderHealRange = 260;

  /// The most wounded a pulse mends.
  static const int menderTargetsPerPulse = 3;

  /// What one pulse gives a wounded body, as a share of its own maximum
  /// health. Half while it burns (games/shared/burn_healing.dart).
  static const double menderHealShare = 0.12;

  /// Seconds the mend takes to flow from the mender into the body; the heal
  /// lands when it arrives.
  static const double menderMendTravel = 0.8;

  /// How far past the arena rim a walking body appears.
  static const double hordeSpawnBeyondRim = 70;

  /// Most bodies one wave can send in total. It was 9,000, reached around
  /// wave 125; with [hordeDensity] it would bite from wave 85, where the
  /// perfect team's wall is measured, so it grew with the density. The field
  /// itself stays at [hordeActiveCeilingForWave]: a bigger wave lasts longer,
  /// it never puts more bodies on screen.
  static const int hordeWaveTotalCeiling = 16000;

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
        bossHealthStretch(wave) *
        (1.0 + max(0, wave - 10) * 0.018) *
        (titanic
            ? 3.2
            : wave == 5
            ? 1.2
            : 1.0);
  }

  /// Bosses died in 3–8 s to a P70–P100 team at any wave, and a titan in
  /// 4–15 (test/survival_boss_ttk_report_test.dart). Twice the health
  /// through wave 10, where a fresh team meets its first bosses, climbing
  /// to four times by wave 25, so a team near its wall fights a boss for
  /// 20–30 s.
  static double bossHealthStretch(int wave) =>
      2.0 + 2.0 * ((wave - 10) / 15).clamp(0.0, 1.0);

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
  /// The climb reads [_fieldCeilingPressure], so it starts at wave 60 and
  /// reaches 3,000 at wave 160. Wave 100 holds 1,800, under the 2,000
  /// measured as sustainable on the Fold.
  static int hordeActiveCeilingForWave(int wave) {
    final w = _fieldCeilingPressure(wave);
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
  /// It reads [latePressure]: ahead of the wave count from wave 25, at half
  /// pace past wave 40.
  static double enemyWaveHpScale(int wave) {
    if (wave <= 1) return 1.0;
    final w = latePressure(wave);
    final base = 1.0 + pow(w - 1, 1.12).toDouble() * 0.032;
    return base * (1.0 + max(0.0, w - 10) * 0.004);
  }

  /// Where the run turns into the grinder's endgame.
  ///
  /// A decent team (about Potential 70) meets its wall around this wave.
  /// Beyond it, every wave a team survives is paid for by its stats: breeding
  /// and Enhancement are the only way further. Measured on the benchmark
  /// party (docs/survival_stat_walls.md): with the wave curves at full pace
  /// past here, P90 walled at wave 48 and a perfect team at 63. At half pace
  /// the walls spread toward roughly P90 60, P100 70, perfect 80.
  static const int latePressureWave = 40;
  static const double latePressureRate = 0.5;

  /// From here to [latePressureWave] the world presses ahead of the wave
  /// count, [pressureLead] waves ahead by wave 40.
  ///
  /// Half of the answer to the 2026-10-20 family rebuild, with
  /// [hordeDensity]: the bodies themselves are a little tougher and hit a
  /// little harder (x1.25 at wave 40, x1.18 at 80), so health and damage
  /// keep climbing together. Alone it is a weak lever (health grows about 2%
  /// a pressure wave near wave 50): an eleven-wave lead moved P90's wall
  /// only from 76 to 71. With the density the walls are back on their targets
  /// (docs/survival_stat_walls.md). Waves 1–25, where a fresh team meets its
  /// limit, are untouched.
  static const int pressureLeadWave = 25;
  static const double pressureLead = 11;

  /// The wave number the pressure curves read: the real wave through
  /// [pressureLeadWave], then gaining on it until it is [pressureLead] ahead
  /// at [latePressureWave], then half a wave for every wave past that. Wave
  /// 30 presses like 33.7, wave 40 like 51 and wave 80 like 71 (before the
  /// lead they pressed like 30, 40 and 60).
  static double latePressure(int wave) {
    if (wave <= pressureLeadWave) return wave.toDouble();
    if (wave <= latePressureWave) {
      return wave +
          pressureLead *
              (wave - pressureLeadWave) /
              (latePressureWave - pressureLeadWave);
    }
    return latePressureWave +
        pressureLead +
        (wave - latePressureWave) * latePressureRate;
  }

  /// The pressure the field's ceiling climbs by: [latePressure] without the
  /// lead. The ceiling is a frame budget measured on the Fold, not a
  /// difficulty knob, so it keeps the climb it was measured against.
  static double _fieldCeilingPressure(int wave) => wave <= latePressureWave
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
  /// It reads [latePressure], with health, so the two keep rising together.
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
  /// falling share: 0.88 at wave 12, 0.59 at 20, 0.38 at 30, 0.26 at 40, 0.19
  /// at 80 (it reads [latePressure], so it hardens with the pressure lead and
  /// a hit at a given wave costs the orb about what it did before). That
  /// put the level-10 walls back within a wave or two of where they were
  /// (docs/survival_stat_walls.md) and leaves the opening waves alone.
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
