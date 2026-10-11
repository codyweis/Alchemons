@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// How every special ability SCALES — the same one-alchemon real fight as
/// test/ability_testbed_test.dart, run at four stat bands, each at a wave near
/// that band's own survival wall (docs/survival_stat_walls.md).
///
/// A report, not a gate. docs/ability_pass/README.md has the method, the
/// findings and how to read the output; this file only measures.
///
/// What one run records, per ability × band × fight:
///  - damage the alchemon dealt, split into its auto attacks and everything
///    else (the special, its zones, its passives) via the mastery telemetry;
///  - kills, healing (run-wide, by recipient), what the orb and ship lost,
///    and control uptime (enemy-frames under slow/root/freeze/disorient/shove,
///    which the aggregate turns into body-seconds);
///  - special casts, the real time between them, and the formula interval;
///  - how many of its persistent pieces (zones, orbitals, traps, decoys,
///    turrets) were alive at once — the stacking check;
///  - non-auto damage in each third of the window — the in-run ramp check.
///
/// With MODE=auto the special is held on cooldown for the whole fight, which
/// gives each element's auto-attack-only baseline; full minus auto is what the
/// special adds, including what it adds THROUGH the autos (Pip Steam's haste,
/// Mask Ice's pillar, Kin Steam's boiler).
///
/// The special is ready at the start: a companion is deployed for a whole run,
/// so the steady state is what matters, not the first cooldown. Orb and ship
/// are held at 60% so heals have room to land and nothing dies (a frame that
/// takes more than that has its game-over undone); the companion is revived if
/// it falls. A simple pilot flies the ship at the nearest threat, as in the
/// stat-wall report, so pickups (flowers, wisps, shards) and ship-borne
/// effects (trails, the rain cloud) get collected. A wave that is cleared is
/// run again, so a strong ability is measured on its power, not on supply.
///
/// Env (all optional):
///   FAMS=horn,wing       families (default all 8)
///   ELEMS=Fire,Ice       elements (default all 17)
///   BANDS=P50,P100E10    bands (default P50,P70,P90,P100E10)
///   SCENS=horde,boss     fights (default horde,siege,shooters,boss)
///   MODE=full|auto|both  (default full)
///   CONTROL=1            run only the nothing-deployed control fights
///   SECONDS=45           window
///   SEEDS=4242,7,19,31   seeds (default 4242,7,19)
///   OUT=/path/file.jsonl append one JSON line per run (default: stdout only)
///   BOSS_HOLD=1          keep the boss alive (refilled below 60%) so the boss
///                        fight measures boss damage per second, not kill time
///
///   FAMS=horn,wing OUT=/tmp/hw.jsonl \
///   flutter test test/ability_scaling_report_test.dart --tags preview \
///     --plain-name 'measure'
///
/// Aggregation into docs/ability_pass/profiles.csv (main pass, optional
/// held-boss pass and 120 s long pass; see the README for the full recipe):
///   AGG_IN=/tmp/scale/main AGG_BOSS=/tmp/scale/boss AGG_LONG=/tmp/scale/long \
///   AGG_OUT=docs/ability_pass \
///   flutter test test/ability_scaling_report_test.dart --tags preview \
///     --plain-name 'aggregate'
///
/// The static per-cast scan: PAYLOAD_OUT=/path/file.jsonl ... --plain-name
/// 'payload'.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('measure', () async {
    // The survival game prints a spatial-grid line every two seconds in debug
    // builds; across thousands of fights that is the whole log.
    debugPrint = (String? message, {int? wrapWidth}) {};
    final env = Platform.environment;
    List<String> list(String key, List<String> fallback) {
      final raw = env[key];
      if (raw == null || raw.trim().isEmpty) return fallback;
      return raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final fams = list('FAMS', kScalingFamilies);
    final elems = list('ELEMS', kCosmicAbilityElements);
    final bandNames = list('BANDS', kScalingBands.keys.toList());
    final scenNames = list('SCENS', kScalingScenarios.keys.toList());
    final mode = env['MODE'] ?? 'full';
    final seconds = double.tryParse(env['SECONDS'] ?? '') ?? 45.0;
    final seeds = list('SEEDS', const [
      '4242',
      '7',
      '19',
    ]).map(int.parse).toList();
    final outPath = env['OUT'];
    final out = outPath == null ? null : File(outPath);
    final clock = Stopwatch()..start();

    void emit(Map<String, Object?> row) {
      final line = jsonEncode(row);
      // Written as it goes, so a long sweep that is stopped keeps its rows.
      out?.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
      // ignore: avoid_print
      print(
        'SCALE ${row['family']}/${row['element']} ${row['band']} '
        '${row['scen']} s${row['seed']} ${row['mode']} dmg=${(row['damage'] as num).round()} '
        'spec=${(row['nonBasic'] as num).round()} casts=${row['casts']} '
        'conc=${row['concMax']} t=${clock.elapsed.inSeconds}s',
      );
    }

    if (env['CONTROL'] == '1') {
      for (final b in bandNames) {
        for (final s in scenNames) {
          for (final seed in seeds) {
            emit(
              await runScalingFight(
                family: 'horn',
                element: 'Fire',
                band: b,
                scen: s,
                seconds: seconds,
                seed: seed,
                deploy: false,
                holdBoss: env['BOSS_HOLD'] == '1',
              ),
            );
          }
        }
      }
    } else {
      final modes = mode == 'both' ? ['full', 'auto'] : [mode];
      for (final f in fams) {
        for (final e in elems) {
          for (final b in bandNames) {
            for (final s in scenNames) {
              for (final seed in seeds) {
                for (final m in modes) {
                  emit(
                    await runScalingFight(
                      family: f,
                      element: e,
                      band: b,
                      scen: s,
                      seconds: seconds,
                      seed: seed,
                      suppressSpecial: m == 'auto',
                      holdBoss: env['BOSS_HOLD'] == '1',
                    ),
                  );
                }
              }
            }
          }
        }
      }
    }
  }, timeout: const Timeout(Duration(hours: 6)));

  // What a single cast RETURNS at each band, without a fight: counts,
  // damage, lifetimes, radii. Blind to Horn sweeps, Kin state and Mystic
  // worlds, but it shows which authored numbers move with stats and which
  // are flat or clamped. PAYLOAD_OUT=/path/file.jsonl.
  test('payload', () {
    final outPath = Platform.environment['PAYLOAD_OUT'];
    final out = StringBuffer();
    for (final f in kScalingFamilies) {
      for (final e in kCosmicAbilityElements) {
        for (final band in kScalingBands.keys) {
          final b = kScalingBands[band]!;
          final m = scalingSubject(f, e, b.potential, b.enhancement);
          final cs = deriveAlchemonCombatStats(member: m);
          final r = createCosmicSpecialAbility(
            origin: Offset.zero,
            baseAngle: 0,
            family: f,
            element: e,
            damage: cs.abilityAtk * 1.15,
            maxHp: cs.maxHp,
            casterPower: m.statIntelligence,
            casterBeauty: m.statBeauty,
            casterIntelligence: m.statIntelligence,
            casterStrength: m.statStrength,
            casterBeautyPotential: m.statBeautyPotential,
            targetPos: const Offset(220, 0),
          );
          double sum(double Function(Projectile p) g) =>
              r.projectiles.fold<double>(0.0, (a, p) => a + g(p));
          double maxOf(double Function(Projectile p) g) =>
              r.projectiles.fold<double>(0.0, (a, p) => max(a, g(p)));
          final row = <String, Object?>{
            'family': f,
            'element': e,
            'band': band,
            'stats': {
              'str': m.statStrength,
              'int': m.statIntelligence,
              'beauty': m.statBeauty,
              'speed': m.statSpeed,
            },
            'abilityAtk': cs.abilityAtk,
            'elemAtk': cs.elemAtk,
            'specialCdr': cs.specialCooldownReduction,
            'interval': alchemonSpecialInterval(
              family: f,
              element: e,
              specialCooldownReduction: cs.specialCooldownReduction,
              abilityAtk: cs.abilityAtk,
            ),
            'n': r.projectiles.length,
            'dmg': sum((p) => p.damage),
            'effectPower': sum((p) => p.effectPower),
            'maxLife': maxOf((p) => p.life),
            'maxRadius': maxOf((p) => p.radiusMultiplier),
            'maxEffectRadius': maxOf((p) => p.effectRadius),
            'maxEffectDuration': maxOf((p) => p.effectDuration),
            'effectCount': sum((p) => p.effectCount.toDouble()),
            'bounces': sum((p) => p.bounceCount.toDouble()),
            'intercepts': sum((p) => p.interceptCharges.toDouble()),
            'decoyHp': sum((p) => p.decoyHp),
            'taunt': maxOf((p) => p.tauntRadius),
            'snare': maxOf((p) => p.snareRadius),
            'turret': sum((p) => p.turretDamage),
            'trail': sum((p) => p.trailDamage),
            'deathBoom': sum(
              (p) => p.deathExplosionDamage * p.deathExplosionCount,
            ),
            'cluster': sum((p) => p.clusterDamage * p.clusterCount),
            'stationary': r.projectiles.where((p) => p.stationary).length,
            'beams': r.beams.length,
            'beamDmg': r.beams.fold<double>(
              0.0,
              (a, w) =>
                  a +
                  w.damagePerTick * (w.duration / max(0.01, w.tickInterval)),
            ),
            'beamHeal': r.beams.fold<double>(
              0.0,
              (a, w) =>
                  a + w.healPerTick * (w.duration / max(0.01, w.tickInterval)),
            ),
            'beamDuration': r.beams.fold<double>(
              0.0,
              (a, w) => max(a, w.duration),
            ),
            'beamEffectPower': r.beams.fold<double>(
              0.0,
              (a, w) => a + w.effectPower,
            ),
            'shieldHp': r.shieldHp,
            'chargeDamage': r.chargeDamage,
            'chargeSweep': r.chargeSweepRadius,
            'selfHeal': r.selfHeal,
            'shipHeal': r.shipHeal,
            'blessingTimer': r.blessingTimer,
            'blessingHeal': r.blessingHealPerTick,
            'hasteTimer': r.basicHasteTimer,
            'hasteMult': r.basicHasteMultiplier,
            'windUp': r.windUpTime,
          };
          out.writeln(jsonEncode(row));
        }
      }
    }
    if (outPath != null) File(outPath).writeAsStringSync(out.toString());
  });

  // Turns the fights into docs/ability_pass/profiles.csv. The authored
  // columns (line, role, intended, basis, why, mechanism, notes) are read
  // back from the existing CSV, so an edited intent survives a rerun; every
  // measured column is recomputed.
  //   AGG_IN=<main pass dir> [AGG_BOSS=<held-boss pass dir>]
  //   [AGG_LONG=<long pass dir>] [AGG_OUT=docs/ability_pass]
  test('aggregate', () {
    final env = Platform.environment;
    final inDir = env['AGG_IN'];
    if (inDir == null) return;
    final outDir = env['AGG_OUT'] ?? 'docs/ability_pass';
    final csv = aggregateScalingReport(
      mainRows: [
        // A held-boss pass (BOSS_HOLD=1) replaces the main pass's boss fights.
        for (final r in readScalingRows(inDir))
          if (env['AGG_BOSS'] == null || r['scen'] != 'boss') r,
        if (env['AGG_BOSS'] != null)
          for (final r in readScalingRows(env['AGG_BOSS']!))
            if (r['scen'] == 'boss') r,
      ],
      longRows: env['AGG_LONG'] == null
          ? const []
          : readScalingRows(env['AGG_LONG']!),
      authored: readAuthoredProfiles('$outDir/profiles.csv'),
    );
    Directory(outDir).createSync(recursive: true);
    File('$outDir/profiles.csv').writeAsStringSync(csv);
  });
}

const List<String> kScalingFamilies = [
  'horn',
  'wing',
  'let',
  'pip',
  'mane',
  'mask',
  'kin',
  'mystic',
];

/// The four stat bands and the waves they are fought at: each band's normal
/// wave sits a little under its benchmark-party wall, its boss wave is the
/// nearest multiple of five.
const Map<String, ({int potential, int enhancement, int wave, int bossWave})>
kScalingBands = {
  'P50': (potential: 50, enhancement: 0, wave: 28, bossWave: 30),
  'P70': (potential: 70, enhancement: 0, wave: 34, bossWave: 35),
  'P90': (potential: 90, enhancement: 0, wave: 46, bossWave: 45),
  'P100E10': (potential: 100, enhancement: 10, wave: 68, bossWave: 70),
};

/// The testbed's four fights.
const Map<String, ({SurvivalWavePattern? pattern, bool boss})>
kScalingScenarios = {
  'horde': (pattern: SurvivalWavePattern.wispHorde, boss: false),
  'siege': (pattern: SurvivalWavePattern.siegePush, boss: false),
  'shooters': (pattern: SurvivalWavePattern.shooterScreen, boss: false),
  'boss': (pattern: null, boss: true),
};

/// Median species base stats across the roster (speed/int/str/beauty), so the
/// comparison is between abilities and not between species stat blocks.
const Map<String, int> kScalingSpeciesBase = {
  'speed': 63,
  'intelligence': 68,
  'strength': 64,
  'beauty': 69,
};

CosmicPartyMember scalingSubject(
  String family,
  String element,
  int potential,
  int enhancement,
) {
  double stat(String key) => AlchemonStatSystem.effectiveInternal(
    speciesBase: kScalingSpeciesBase[key]!,
    level: 10,
    potential: potential,
    enhancementRank: enhancement,
  );
  return CosmicPartyMember(
    instanceId: 'scale-$family-$element',
    baseId: 'SCALE01',
    displayName: '$family $element',
    family: family,
    element: element,
    level: 10,
    slotIndex: 0,
    statSpeed: stat('speed'),
    statIntelligence: stat('intelligence'),
    statStrength: stat('strength'),
    statBeauty: stat('beauty'),
    statSpeedPotential: potential.toDouble(),
    statIntelligencePotential: potential.toDouble(),
    statStrengthPotential: potential.toDouble(),
    statBeautyPotential: potential.toDouble(),
    staminaBars: 3,
    staminaMax: 3,
  );
}

/// One fight. Returns one JSON-able row.
Future<Map<String, Object?>> runScalingFight({
  required String family,
  required String element,
  required String band,
  required String scen,
  required double seconds,
  int seed = 4242,
  bool deploy = true,
  bool suppressSpecial = false,
  bool primeSpecial = true,
  bool holdBoss = false,
}) async {
  final b = kScalingBands[band]!;
  final sc = kScalingScenarios[scen]!;
  final wave = sc.boss ? b.bossWave : b.wave;
  final game = CosmicSurvivalGame(
    party: [scalingSubject(family, element, b.potential, b.enhancement)],
    random: Random(seed),
    onGameOver: () {},
  );
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();
  game.startGame();
  for (var w = 1; w < wave; w++) {
    game.spawner.resumeAfterIntermission();
  }
  void holdPattern() {
    if (sc.pattern != null) {
      game.spawner.currentPattern = sc.pattern!;
      game.spawner.isBossWave = false;
      game.spawner.currentMutator = null;
    }
  }

  holdPattern();
  if (deploy) {
    game.summonCompanion(0);
    game.clearCompanionTether();
  }
  final comp0 = game.activeCompanions[0];
  final formulaInterval = comp0?.effectiveSpecialCooldown ?? 0;
  // Special ready at the start, as in the role scorecard: a companion is
  // deployed for a whole run, so the steady state is what matters, not the
  // first cooldown. Without this a 22-80 s Mask or a 60 s Mystic spends most
  // of the window waiting for its first cast.
  if (comp0 != null && primeSpecial && !suppressSpecial) {
    comp0.specialCooldown = 0;
  }

  const holdFrac = 0.6;
  void holdUp() {
    game.orb.currentHp = game.orb.maxHp * holdFrac;
    game.ship.currentHp = game.ship.maxHp * holdFrac;
    game.ship.isDead = false;
  }

  holdUp();
  var lost = 0.0;
  var prevOrb = game.orb.currentHp;
  var prevShip = game.ship.currentHp;
  var ccFrames = 0.0;
  var enemyFrames = 0.0;
  var concMax = 0;
  var concSum = 0.0;
  var liveMax = 0;
  var frames = 0;
  final castTimes = <double>[];
  var lastCasts = 0;
  final thirdsNonBasic = <double>[0, 0, 0];
  final thirdsTotal = <double>[0, 0, 0];
  SurvivalBoss? boss;
  double? bossSpawnT;
  double? bossDeathT;
  var bossHpRemoved = 0.0;
  var bossMaxHp = 0.0;
  var bossFightDamage = 0.0;
  double? prevBossHp;
  double? firstClearT;
  var restarts = 0;
  var maxKillStacks = 0;
  var maxBoiler = 0;
  var maxWispBank = 0;
  var maxAmp = 1.0;
  const step = 1 / 60;
  final wall = Stopwatch()..start();

  double totalDamage() => game.companionRunStats[0]?.damageDealt ?? 0;
  double basicDamage() => game.mastery.telemetryFor(0).basicDamage;

  // A frame budget as well as a clock: if the game ever stops advancing its
  // own clock (a pause, a modal), the fight still ends.
  final frameBudget = (seconds * 60 * 1.5).ceil();
  var stalled = false;
  var orbDeaths = 0;
  while (game.stats.timeElapsed < seconds) {
    if (frames >= frameBudget) {
      stalled = true;
      break;
    }
    // Pilot: the stat-wall report's — fly at what is nearest the orb, circle
    // at 170.
    Offset? target;
    var best = double.infinity;
    for (final enemy in game.enemies) {
      if (enemy.isDead) continue;
      final orbDistance = (enemy.position - game.orb.position).distance;
      final score = orbDistance < 300 ? orbDistance - 2000 : orbDistance;
      if (score < best) {
        best = score;
        target = enemy.position;
      }
    }
    target ??= game.activeBoss?.position ?? game.orb.position;
    final delta = target - game.ship.position;
    final tangent = delta.distance > 0
        ? Offset(-delta.dy, delta.dx) / delta.distance
        : Offset.zero;
    game.setJoystickInput(
      delta.distance > 170 ? delta / delta.distance : tangent,
    );
    if (game.showingPowerUpSelection) {
      game.alchemicalMeter = 0;
      game.dismissPowerUpSelection();
    }
    final comp = game.activeCompanions[0];
    if (suppressSpecial && comp != null) {
      comp.specialCooldown = max(comp.specialCooldown, 1e6);
    }
    final dmgBefore = totalDamage();
    final basicBefore = basicDamage();
    final t0 = game.stats.timeElapsed;
    game.update(step);
    frames++;
    final third = min(2, (t0 / seconds * 3).floor());
    final dTotal = totalDamage() - dmgBefore;
    final dBasic = basicDamage() - basicBefore;
    thirdsTotal[third] += dTotal;
    thirdsNonBasic[third] += max(0.0, dTotal - dBasic);

    final orbNow = game.orb.currentHp;
    final shipNow = game.ship.currentHp;
    // A deep horde can take more than the held 60% in one frame. The run is
    // not over — the orb is being held up — so undo the game over, or the
    // game's clock stops and the window never ends.
    if (game.isGameOver) {
      orbDeaths++;
      game.isGameOver = false;
    }
    if (orbNow < prevOrb) lost += prevOrb - orbNow;
    if (shipNow < prevShip) lost += prevShip - shipNow;
    for (final e in game.enemies) {
      if (e.isDead) continue;
      enemyFrames += 1;
      if (e.slowTimer > 0 ||
          e.maneRootTimer > 0 ||
          e.hornPlantRootTimer > 0 ||
          e.blizzardMultiplier < 1.0 ||
          e.disorientTimer > 0 ||
          e.knockbackVelocity.distance > 40) {
        ccFrames += 1;
      }
    }
    var conc = 0;
    var live = 0;
    for (final p in game.companionProjectiles) {
      if (p.sourceSlotIndex != 0 || p.abilityFamily.isEmpty || p.life <= 0) {
        continue;
      }
      live++;
      if (p.stationary ||
          p.orbitCenter != null ||
          p.followSourceCompanion ||
          p.followShipOrbit ||
          p.holdOrbit ||
          p.decoy ||
          p.turretInterval > 0) {
        conc++;
      }
    }
    concMax = max(concMax, conc);
    liveMax = max(liveMax, live);
    concSum += conc;
    if (comp != null) {
      maxKillStacks = max(maxKillStacks, comp.abilityKillStacks);
      maxBoiler = max(maxBoiler, comp.kinSteamBoilerStacks);
      maxWispBank = max(maxWispBank, comp.maskSpiritWispBank);
      maxAmp = max(maxAmp, comp.damageAmp);
    }

    final casts = game.mastery.telemetryFor(0).specialCasts;
    if (casts > lastCasts) {
      for (var i = lastCasts; i < casts; i++) {
        castTimes.add(game.stats.timeElapsed);
      }
      lastCasts = casts;
    }

    if (sc.boss) {
      bossFightDamage += dTotal;
      final live = game.activeBoss;
      if (boss == null && live != null && !live.isDead) {
        boss = live;
        bossSpawnT = game.stats.timeElapsed;
        bossMaxHp = live.maxHp;
        prevBossHp = live.hp;
      } else if (boss != null && bossDeathT == null) {
        if (boss.isDead || boss.hp <= 0 || !identical(game.activeBoss, boss)) {
          bossDeathT = game.stats.timeElapsed;
          bossHpRemoved += max(0.0, prevBossHp ?? 0);
        } else {
          if (boss.hp < prevBossHp!) bossHpRemoved += prevBossHp - boss.hp;
          // Held boss: topped back up before it can die, so the window
          // measures boss damage per second for its whole length. A boss
          // that dies early ends a kill-time measurement in a few seconds
          // and makes the strong look no better than the decent.
          if (holdBoss && boss.hp < boss.maxHp * 0.6) boss.hp = boss.maxHp;
          prevBossHp = boss.hp;
        }
      }
    } else if (game.spawner.intermission || game.spawner.currentWave != wave) {
      // Cleared: run the same wave again so a strong ability is measured on
      // its power, not on how many bodies the wave happened to hold.
      firstClearT ??= game.stats.timeElapsed;
      restarts++;
      game.spawner.currentWave = wave - 1;
      game.spawner.resumeAfterIntermission();
      holdPattern();
    }

    holdUp();
    prevOrb = game.orb.currentHp;
    prevShip = game.ship.currentHp;
    if (comp != null && comp.isDead) {
      comp
        ..isDead = false
        ..currentHp = comp.maxHp;
    }
  }

  final st = game.companionRunStats[0];
  final tel = game.mastery.telemetryFor(0);
  final c = game.activeCompanions[0];
  final gaps = <double>[
    for (var i = 1; i < castTimes.length; i++) castTimes[i] - castTimes[i - 1],
  ];
  final bossWindow = bossSpawnT == null
      ? null
      : (bossDeathT ?? game.stats.timeElapsed) - bossSpawnT;
  return {
    'family': family,
    'element': element,
    'band': band,
    'scen': scen,
    'seed': seed,
    'mode': deploy ? (suppressSpecial ? 'auto' : 'full') : 'control',
    'wave': wave,
    'seconds': seconds,
    'damage': st?.damageDealt ?? 0,
    'basic': tel.basicDamage,
    'nonBasic': (st?.damageDealt ?? 0) - tel.basicDamage,
    'kills': st?.kills ?? 0,
    'healTotal': game.healingStats.total,
    'healOrb': game.healingStats.toOrb,
    'healShip': game.healingStats.toShip,
    'healMons': game.healingStats.toMons,
    'healAttributed': st?.healingDone ?? 0,
    'lost': lost,
    'ccUptime': enemyFrames == 0 ? 0.0 : ccFrames / enemyFrames,
    'enemiesPerFrame': frames == 0 ? 0.0 : enemyFrames / frames,
    'casts': tel.specialCasts,
    'basicCasts': tel.basicCasts,
    'castTimes': castTimes,
    'meanGap': gaps.isEmpty ? null : gaps.reduce((a, b) => a + b) / gaps.length,
    'formulaInterval': formulaInterval,
    'abilityAtk': c?.abilityAtk ?? 0,
    'elemAtk': c?.elemAtk ?? 0,
    'physAtk': c?.physAtk ?? 0,
    'maxHp': c?.maxHp ?? 0,
    'specialCdr': c?.specialCooldownReduction ?? 0,
    'specialRange': c?.specialAbilityRange ?? 0,
    'concMax': concMax,
    'concMean': frames == 0 ? 0.0 : concSum / frames,
    'liveMax': liveMax,
    'thirdsNonBasic': thirdsNonBasic,
    'thirdsTotal': thirdsTotal,
    'bossSpawnT': bossSpawnT,
    'bossDeathT': bossDeathT,
    'bossWindow': bossWindow,
    'bossHpRemoved': bossHpRemoved,
    'bossMaxHp': bossMaxHp,
    'bossRate': (bossWindow == null || bossWindow <= 0)
        ? 0.0
        : bossHpRemoved / bossWindow,
    'bossFightDamage': bossFightDamage,
    'holdBoss': holdBoss,
    'firstClearT': firstClearT,
    'restarts': restarts,
    'maxKillStacks': maxKillStacks,
    'maxBoiler': maxBoiler,
    'maxWispBank': maxWispBank,
    'maxAmp': maxAmp,
    'wallMs': wall.elapsedMilliseconds,
    'frames': frames,
    'stalled': stalled,
    'orbDeaths': orbDeaths,
    'simSeconds': game.stats.timeElapsed,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
//  AGGREGATION
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _nonBoss = ['horde', 'siege', 'shooters'];

/// Abilities with no cast at all: their whole effect is on in both modes, so
/// they are measured against their family's median auto-only fight instead.
const Set<String> kPassiveAbilities = {
  'horn/Air',
  'horn/Mud',
  'pip/Dark',
  'kin/Fire',
};

List<Map<String, dynamic>> readScalingRows(String dir) => [
  for (final f in Directory(dir).listSync().whereType<File>())
    if (f.path.endsWith('.jsonl'))
      for (final line in f.readAsLinesSync())
        if (line.trim().isNotEmpty) jsonDecode(line) as Map<String, dynamic>,
];

List<String> _csvSplit(String line) {
  final out = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      out.add(cell.toString());
      cell.clear();
    } else {
      cell.write(ch);
    }
  }
  out.add(cell.toString());
  return out;
}

String _csvCell(Object? v) {
  final s = v == null ? '' : '$v';
  return s.contains(',') || s.contains('"') || s.contains('\n')
      ? '"${s.replaceAll('"', '""')}"'
      : s;
}

/// The hand-written columns of an existing profiles.csv, keyed family/Element.
Map<String, Map<String, String>> readAuthoredProfiles(String path) {
  final f = File(path);
  if (!f.existsSync()) return {};
  final lines = f.readAsLinesSync();
  if (lines.isEmpty) return {};
  final head = _csvSplit(lines.first);
  final out = <String, Map<String, String>>{};
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final cells = _csvSplit(line);
    final row = <String, String>{
      for (var i = 0; i < head.length && i < cells.length; i++)
        head[i]: cells[i],
    };
    out['${row['family']}/${row['element']}'] = row;
  }
  return out;
}

double _mean(Iterable<double> v) =>
    v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

double _median(Iterable<double> v) {
  final l = v.toList()..sort();
  if (l.isEmpty) return 0;
  return l.length.isOdd
      ? l[l.length ~/ 2]
      : (l[l.length ~/ 2 - 1] + l[l.length ~/ 2]) / 2;
}

double _num(Object? v) => v == null ? 0 : (v as num).toDouble();

/// A row's field, plus the derived ones: `ccSeconds` is body-seconds spent
/// under control (uptime is a share of every body on the field, and a deep
/// wave holds a thousand of them, most nowhere near one alchemon).
double _field(Map<String, dynamic> r, String name) => switch (name) {
  'ccSeconds' =>
    _num(r['ccUptime']) *
        _num(r['enemiesPerFrame']) *
        _num(r['simSeconds'] ?? r['seconds']),
  _ => _num(r[name]),
};

/// One ability at one band in one fight, averaged over seeds: what the
/// special adds over the same alchemon with its special held on cooldown.
class _Cell {
  _Cell(this.pairs, {this.baseline});
  final List<(Map<String, dynamic>, Map<String, dynamic>)> pairs;

  /// For passives: the family's median auto-only fight, per field.
  final Map<String, double>? baseline;

  double added(String field) => _mean([
    for (final (f, a) in pairs)
      _field(f, field) - (baseline?[field] ?? _field(a, field)),
  ]);
  double saved(String field) => _mean([
    for (final (f, a) in pairs)
      (baseline?[field] ?? _field(a, field)) - _field(f, field),
  ]);
  double full(String field) =>
      _mean([for (final (f, _) in pairs) _field(f, field)]);
  double thirdsRatio() {
    final t = [
      for (var i = 0; i < 3; i++)
        _mean([
          for (final (f, a) in pairs)
            _num((f['thirdsTotal'] as List)[i]) -
                _num((a['thirdsTotal'] as List)[i]),
        ]),
    ];
    return t[0] <= 0 ? double.nan : t[2] / t[0];
  }
}

Map<String, _Cell> _cells(List<Map<String, dynamic>> rows) {
  final full = <String, Map<int, Map<String, dynamic>>>{};
  final auto = <String, Map<int, Map<String, dynamic>>>{};
  for (final r in rows) {
    if (r['mode'] == 'control') continue;
    final k = '${r['family']}/${r['element']}|${r['band']}|${r['scen']}';
    (r['mode'] == 'full' ? full : auto).putIfAbsent(
      k,
      () => {},
    )[r['seed'] as int] = r;
  }
  // Family auto baselines for the passives.
  final famAuto = <String, List<Map<String, dynamic>>>{};
  for (final e in auto.entries) {
    final ability = e.key.split('|').first;
    if (kPassiveAbilities.contains(ability)) continue;
    final fam = ability.split('/').first;
    final rest = e.key.split('|').skip(1).join('|');
    famAuto.putIfAbsent('$fam|$rest', () => []).addAll(e.value.values);
  }
  final out = <String, _Cell>{};
  for (final e in full.entries) {
    final ability = e.key.split('|').first;
    final a = auto[e.key] ?? const {};
    final pairs = [
      for (final s in e.value.keys)
        if (a[s] != null) (e.value[s]!, a[s]!),
    ];
    Map<String, double>? baseline;
    if (kPassiveAbilities.contains(ability)) {
      final fam = ability.split('/').first;
      final rest = e.key.split('|').skip(1).join('|');
      final base = famAuto['$fam|$rest'] ?? const [];
      baseline = {
        for (final field in [
          'damage',
          'lost',
          'healTotal',
          'ccSeconds',
          'bossRate',
        ])
          field: _median([for (final r in base) _field(r, field)]),
      };
    }
    out[e.key] = _Cell(pairs, baseline: baseline);
  }
  return out;
}

String aggregateScalingReport({
  required List<Map<String, dynamic>> mainRows,
  required List<Map<String, dynamic>> longRows,
  required Map<String, Map<String, String>> authored,
}) {
  final bands = kScalingBands.keys.toList();
  final cells = _cells(mainRows);
  final longCells = _cells(longRows);
  final control = <String, double>{};
  for (final b in bands) {
    for (final s in kScalingScenarios.keys) {
      control['$b|$s'] = _mean([
        for (final r in mainRows)
          if (r['mode'] == 'control' && r['band'] == b && r['scen'] == s)
            _num(r['lost']),
      ]);
    }
  }
  final abilities = [
    for (final f in kScalingFamilies)
      for (final e in kCosmicAbilityElements) '$f/$e',
  ];
  _Cell? cell(String a, String b, String s) => cells['$a|$b|$s'];

  double medianOf(String b, String s, double Function(_Cell c) g) => _median([
    for (final a in abilities)
      if (cell(a, b, s) != null) g(cell(a, b, s)!),
  ]);
  final medDmg = {
    for (final b in bands)
      for (final s in _nonBoss)
        '$b|$s': medianOf(b, s, (c) => c.added('damage')),
  };
  final medBoss = {
    for (final b in bands) b: medianOf(b, 'boss', (c) => c.added('bossRate')),
  };
  final medRamp = {
    for (final b in bands)
      b: _median([
        for (final a in abilities)
          if (longCells['$a|$b|horde'] != null &&
              !longCells['$a|$b|horde']!.thirdsRatio().isNaN)
            longCells['$a|$b|horde']!.thirdsRatio(),
      ]),
  };

  String f2(double v) => v.isNaN ? '' : v.toStringAsFixed(2);
  String f1(double v) => v.isNaN ? '' : v.toStringAsFixed(1);

  final head = [
    'family',
    'element',
    'name',
    'line',
    'role',
    'intended',
    'intended_is_proposed',
    'why',
    'axis',
    for (final b in bands) 'share_$b',
    for (final b in bands) 'boss_share_$b',
    for (final b in bands) 'heal_frac_$b',
    for (final b in bands) 'protect_frac_$b',
    for (final b in bands) 'cc_body_seconds_$b',
    for (final b in bands) 'interval_formula_$b',
    for (final b in bands) 'interval_measured_$b',
    for (final b in bands) 'concurrency_$b',
    for (final b in bands) 'concurrency_long_$b',
    for (final b in bands) 'ramp_index_$b',
    'trend',
    'measured_profile',
    'verdict',
    'review',
    'mechanism',
    'notes',
  ];
  final lines = <String>[head.map(_csvCell).join(',')];
  for (final a in abilities) {
    final parts = a.split('/');
    final fam = parts[0];
    final el = parts[1];
    final auth = authored[a] ?? const {};
    final role = auth['role'] ?? '';
    final intended = auth['intended'] ?? '';
    final share = <String, double>{};
    final boss = <String, double>{};
    final heal = <String, double>{};
    final prot = <String, double>{};
    final cc = <String, double>{};
    final formula = <String, double>{};
    final gap = <String, double>{};
    final conc = <String, double>{};
    final concLong = <String, double>{};
    final ramp = <String, double>{};
    var castsTotal = 0.0;
    for (final b in bands) {
      final nb = [
        for (final s in _nonBoss) cell(a, b, s),
      ].whereType<_Cell>().toList();
      if (nb.length < _nonBoss.length) continue;
      share[b] = _mean([
        for (final s in _nonBoss)
          cell(a, b, s)!.added('damage') / max(1.0, medDmg['$b|$s']!),
      ]);
      final bc = cell(a, b, 'boss');
      boss[b] = bc == null
          ? double.nan
          : bc.added('bossRate') / max(1.0, medBoss[b]!);
      final lostBase = _mean([for (final s in _nonBoss) control['$b|$s']!]);
      heal[b] =
          _mean([for (final c in nb) c.added('healTotal')]) /
          max(1.0, lostBase);
      prot[b] =
          _mean([for (final c in nb) c.saved('lost')]) / max(1.0, lostBase);
      cc[b] = _mean([for (final c in nb) c.added('ccSeconds')]);
      formula[b] = nb.first.full('formulaInterval');
      final gaps = [
        for (final c in nb)
          for (final (f, _) in c.pairs)
            if (f['meanGap'] != null) _num(f['meanGap']),
      ];
      gap[b] = gaps.isEmpty ? double.nan : _mean(gaps);
      conc[b] = _mean([for (final c in nb) c.full('concMean')]);
      castsTotal += _mean([for (final c in nb) c.full('casts')]);
      final lc = longCells['$a|$b|horde'];
      concLong[b] = lc == null ? double.nan : lc.full('concMean');
      final r = lc?.thirdsRatio() ?? double.nan;
      ramp[b] = r.isNaN || medRamp[b]! <= 0 ? double.nan : r / medRamp[b]!;
    }
    if (share.length < bands.length) continue;

    // The axis the role is judged on.
    // The axis it is judged on: the authored `axis` column, else its role.
    // A damage ability with a control rider is judged on damage, because
    // its kills drown its control in a body-count metric.
    final axis = switch (auth['axis']) {
      'damage' || 'heal' || 'protect' || 'cc' => auth['axis']!,
      _ => switch (role) {
        'support-heal' => 'heal',
        'support-protect' => 'protect',
        'control' => 'cc',
        _ => 'damage',
      },
    };
    final primary = switch (axis) {
      'heal' => heal,
      'protect' => prot,
      'cc' => cc,
      _ => share,
    };
    final lo = primary[bands.first]!;
    final hi = primary[bands.last]!;
    // Below this the axis reads as "nothing here", not as a tiny number to
    // take a ratio of.
    final eps = switch (axis) {
      'cc' => 5.0,
      'damage' => 0.05,
      _ => 0.01,
    };
    final trend = lo.abs() < eps && hi.abs() < eps
        ? double.nan
        : hi / max(eps, lo);
    final measured = trend.isNaN
        ? 'NONE'
        : trend >= 1.5
        ? 'SCALER'
        : trend <= 0.67
        ? 'EARLY'
        : 'STEADY';
    // An in-run ramp only reads where the special does real damage; on a
    // trickle the thirds are noise.
    for (final b in bands) {
      if (axis != 'damage' || share[b]! < 0.3) ramp[b] = double.nan;
    }
    final rampVals = [
      for (final v in ramp.values)
        if (!v.isNaN) v,
    ];
    final ramps = rampVals.isNotEmpty && _median(rampVals) >= 1.3;

    final verdict = <String>[];
    final passive = kPassiveAbilities.contains(a);
    if (!passive && castsTotal == 0) verdict.add('broken: never casts');
    if (share.values.every((v) => v.abs() < 0.1) &&
        heal.values.every((v) => v.abs() < 0.02) &&
        prot.values.every((v) => v.abs() < 0.03) &&
        cc.values.every((v) => v.abs() < 20)) {
      verdict.add('does nothing measurable');
    }
    final peak = primary.values.reduce(max);
    if (peak > eps * 10) {
      for (final b in bands) {
        if (primary[b]! < peak * 0.1) verdict.add('collapses at $b');
      }
    }
    for (final b in bands) {
      if (share[b]! > 3.3) {
        verdict.add('too strong at $b (${f1(share[b]!)}x)');
      }
      if (heal[b]! > 1.0) {
        verdict.add('out-heals all incoming at $b (${f1(heal[b]!)}x)');
      }
      final weak = switch (axis) {
        'damage' => share[b]! < 0.3,
        'heal' => heal[b]! < 0.05,
        'protect' => prot[b]! < 0.03,
        _ => cc[b]! < 50,
      };
      if (weak) verdict.add('too weak at $b');
    }
    final curveOk = switch (intended) {
      'SCALER' => measured == 'SCALER',
      'STEADY' => measured == 'STEADY',
      'EARLY' => measured == 'EARLY' || (measured == 'STEADY' && trend < 1.0),
      'RAMP' => ramps,
      'SUPPORT' => measured == 'SCALER' || measured == 'STEADY',
      _ => true,
    };
    if (!curveOk && measured != 'NONE') {
      verdict.add(
        'wrong curve ($intended, measured $measured'
        '${intended == 'RAMP' ? ', no in-run ramp' : ''})',
      );
    }
    // One entry per kind, listing its bands.
    final merged = <String, List<String>>{};
    final order = <String>[];
    for (final v in verdict) {
      final m = RegExp(r'^(too weak|collapses) at (\S+)$').firstMatch(v);
      final key = m == null ? v : m.group(1)!;
      if (!merged.containsKey(key)) order.add(key);
      merged.putIfAbsent(key, () => []).add(m?.group(2) ?? '');
    }
    verdict
      ..clear()
      ..addAll([
        for (final k in order)
          merged[k]!.first.isEmpty ? k : '$k at ${merged[k]!.join('/')}',
      ]);
    if (verdict.isEmpty) verdict.add('OK');

    lines.add(
      [
        fam,
        el,
        cosmicSpecialAbilityName(fam, el),
        auth['line'] ?? '',
        role,
        intended,
        auth['intended_is_proposed'] ?? '',
        auth['why'] ?? '',
        axis,
        for (final b in bands) f2(share[b]!),
        for (final b in bands) f2(boss[b]!),
        for (final b in bands) f2(heal[b]!),
        for (final b in bands) f2(prot[b]!),
        for (final b in bands) f1(cc[b]!),
        for (final b in bands) f1(formula[b]!),
        for (final b in bands) f1(gap[b]!),
        for (final b in bands) f1(conc[b]!),
        for (final b in bands) f1(concLong[b]!),
        for (final b in bands) f2(ramp[b]!),
        f2(trend),
        '$measured${ramps ? '+RAMP' : ''}',
        verdict.join('; '),
        auth['review'] ?? '',
        auth['mechanism'] ?? '',
        auth['notes'] ?? '',
      ].map(_csvCell).join(','),
    );
  }
  return '${lines.join('\n')}\n';
}
