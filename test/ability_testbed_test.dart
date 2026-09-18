@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// One alchemon, alone, in an identical fight. All 136 of them.
///
/// The other two instruments cannot answer "is this ability balanced":
///
///  - the payload table reads what a cast RETURNS, so it is blind to Horn
///    (damage lives in charge sweeps), most of Mask (effects, not damage) and
///    Kin (support that flips state);
///  - run-level sims put five companions in one fight, so no single ability is
///    separable from the four beside it.
///
/// This measures OUTCOMES instead — damage dealt, kills, healing done, and
/// what the orb lost while that alchemon was the only thing defending it — so
/// every family is measured the same way whatever shape its ability takes.
///
/// Every run shares one seed and one starting wave, so the enemy stream is
/// identical for all 136. Orb and ship are held up: the question is what an
/// alchemon PRODUCES in a fixed window, not how long it survives.
///
///   flutter test test/ability_testbed_test.dart --tags preview
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final creatures =
      (jsonDecode(
                File('assets/data/alchemons_creatures.json').readAsStringSync(),
              )
              as Map<String, dynamic>)['creatures']
          as List;

  /// A stand-in alchemon of this family and element with fixed stats, so the
  /// comparison is between ABILITIES and not between species stat blocks.
  CosmicPartyMember subject(String family, String element) {
    // Borrow a real species' base stats so the numbers sit in the game's own
    // range, but hold them identical across every subject.
    final row = (creatures.cast<Map<String, dynamic>>()).first;
    final base = row['baseStats'] as Map<String, dynamic>;
    double stat(String key) => AlchemonStatSystem.effectiveInternal(
      speciesBase: base[key] as int,
      level: 10,
      potential: 80,
    );
    return CosmicPartyMember(
      instanceId: 'bed-$family-$element',
      baseId: 'BED01',
      displayName: '$family $element',
      family: family,
      element: element,
      level: 10,
      slotIndex: 0,
      statSpeed: stat('speed'),
      statIntelligence: stat('intelligence'),
      statStrength: stat('strength'),
      statBeauty: stat('beauty'),
      statSpeedPotential: 80,
      statIntelligencePotential: 80,
      statStrengthPotential: 80,
      statBeautyPotential: 80,
      staminaBars: 3,
      staminaMax: 3,
    );
  }

  /// The fights an alchemon has to be judged across.
  ///
  /// One mixed wave is not an audit. A family is supposed to answer SOME part
  /// of survival, and an ability that looks weak against a swarm may be the
  /// one thing that answers a boss — measuring a single scenario and calling
  /// the low numbers "weak" would quietly punish every specialist in the
  /// roster for being specialised.
  const scenarios =
      <({String name, int wave, SurvivalWavePattern? pattern, bool boss})>[
        // Many small bodies at once: the test of clear rate and area coverage.
        (
          name: 'horde',
          wave: 22,
          pattern: SurvivalWavePattern.wispHorde,
          boss: false,
        ),
        // Standoff shooters at range: the test of reach and of closing distance.
        (
          name: 'shooters',
          wave: 22,
          pattern: SurvivalWavePattern.shooterScreen,
          boss: false,
        ),
        // Heavy bodies walking in: the test of single-target damage and of holding
        // ground.
        (
          name: 'siege',
          wave: 22,
          pattern: SurvivalWavePattern.siegePush,
          boss: false,
        ),
        // One enormous health pool that does not die to area damage at all.
        (name: 'boss', wave: 25, pattern: null, boss: true),
      ];

  /// One fight. With [deploy] false nothing is summoned, which gives the
  /// control: what the orb and ship lose with no alchemon helping at all.
  /// Every defensive number here is a difference against that.
  Future<
    ({
      double damage,
      int kills,
      double healing,
      double lost,
      double controlUptime,
    })
  >
  measure(
    String family,
    String element, {
    required int wave,
    required double seconds,
    SurvivalWavePattern? pattern,
    required bool boss,
    bool deploy = true,
  }) async {
    final game = CosmicSurvivalGame(
      party: [subject(family, element)],
      random: Random(4242),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    for (var w = 1; w < wave; w++) {
      game.spawner.resumeAfterIntermission();
    }
    // Hold the fight in the shape being tested. Left to itself the spawner
    // rolls a pattern per wave, which would give each subject a different
    // fight and make the whole comparison meaningless.
    if (pattern != null) {
      game.spawner.currentPattern = pattern;
      game.spawner.isBossWave = false;
    }
    if (deploy) {
      game.summonCompanion(0);
      game.clearCompanionTether();
    }

    var lost = 0.0;
    var prevOrb = game.orb.currentHp;
    var prevShip = game.ship.currentHp;
    // Enemy-frames spent under crowd control, over enemy-frames total. This is
    // the axis that makes a tank or a support legible: an ability that roots,
    // slows, blocks or taunts produces no damage and no kills, and on a damage
    // column looks identical to an ability that does nothing.
    var ccFrames = 0.0;
    var enemyFrames = 0.0;
    const step = 1 / 60;
    while (game.stats.timeElapsed < seconds) {
      // Orb and ship held up so the window is fixed for everyone. What the orb
      // LOSES is still recorded first — for the defensive families that is the
      // ability working, and it would be invisible in a damage column.
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
      game.update(step);
      final orbNow = game.orb.currentHp;
      final shipNow = game.ship.currentHp;
      if (orbNow < prevOrb) lost += prevOrb - orbNow;
      if (shipNow < prevShip) lost += prevShip - shipNow;
      for (final e in game.enemies) {
        if (e.isDead) continue;
        enemyFrames += 1;
        if (e.slowTimer > 0 ||
            e.maneRootTimer > 0 ||
            e.hornPlantRootTimer > 0 ||
            e.blizzardMultiplier < 1.0 ||
            e.disorientTimer > 0) {
          ccFrames += 1;
        }
      }
      game.orb.currentHp = game.orb.maxHp;
      game.ship.currentHp = game.ship.maxHp;
      game.ship.isDead = false;
      prevOrb = game.orb.currentHp;
      prevShip = game.ship.currentHp;
      final comp = game.activeCompanions[0];
      if (comp != null && comp.isDead) {
        comp
          ..isDead = false
          ..currentHp = comp.maxHp;
      }
    }

    final st = game.companionRunStats[0];
    return (
      damage: st?.damageDealt ?? 0,
      kills: st?.kills ?? 0,
      // Run-wide healing, not just what is attributed to the caster: a Kin's
      // blessing and its signature piece heal allies without either being
      // credited to a slot.
      healing: game.healingStats.total,
      lost: lost,
      controlUptime: enemyFrames == 0 ? 0.0 : ccFrames / enemyFrames,
    );
  }

  test('every alchemon ability, across every kind of fight', () async {
    const families = [
      'horn',
      'wing',
      'let',
      'pip',
      'mane',
      'mask',
      'kin',
      'mystic',
    ];
    const seconds = 45.0;

    // The control: the same four fights with nothing summoned. Every defensive
    // number below is a difference against this, because "the orb lost 900"
    // means nothing until you know what it loses with no help at all.
    final control = <String, double>{};
    for (final sc in scenarios) {
      final r = await measure(
        'horn',
        'Fire',
        wave: sc.wave,
        seconds: seconds,
        pattern: sc.pattern,
        boss: sc.boss,
        deploy: false,
      );
      control[sc.name] = r.lost;
    }
    // ignore: avoid_print
    print(
      'TESTBED \u2014 control (nothing deployed): '
      '${scenarios.map((s) => "${s.name} ${control[s.name]!.round()}").join(", ")}',
    );

    final dmg = <String, Map<String, double>>{};
    final prevented = <String, Map<String, double>>{};
    final healed = <String, Map<String, double>>{};
    final control01 = <String, Map<String, double>>{};
    for (final family in families) {
      for (final element in kCosmicAbilityElements) {
        final key = '$family/$element';
        dmg[key] = {};
        prevented[key] = {};
        healed[key] = {};
        control01[key] = {};
        for (final sc in scenarios) {
          final r = await measure(
            family,
            element,
            wave: sc.wave,
            seconds: seconds,
            pattern: sc.pattern,
            boss: sc.boss,
          );
          dmg[key]![sc.name] = r.damage;
          prevented[key]![sc.name] = control[sc.name]! - r.lost;
          healed[key]![sc.name] = r.healing;
          control01[key]![sc.name] = r.controlUptime;
        }
      }
    }

    double best(Map<String, double> m) => m.values.reduce(max);
    double sum(Map<String, double> m) => m.values.reduce((a, b) => a + b);

    /// A subject's standing on one axis, against the median of every subject
    /// on that same axis in that same fight.
    Map<String, double> medianPer(Map<String, Map<String, double>> src) {
      final out = <String, double>{};
      for (final sc in scenarios) {
        final all = src.values.map((m) => m[sc.name]!).toList()..sort();
        out[sc.name] = all[all.length ~/ 2];
      }
      return out;
    }

    final medDmg = medianPer(dmg);
    final medPrev = medianPer(prevented);

    // ignore: avoid_print
    print(
      'TESTBED \u2014 four axes, best-of-four-fights, against each axis median',
    );
    // ignore: avoid_print
    print(
      'subject              bestDmg  bestPrevented  healing  ccUptime  reads as',
    );
    final verdicts = <String, String>{};
    for (final key in dmg.keys) {
      final dRatio = best({
        for (final sc in scenarios)
          sc.name: dmg[key]![sc.name]! / max(1.0, medDmg[sc.name]!),
      });
      final pRatio = best({
        for (final sc in scenarios)
          sc.name:
              prevented[key]![sc.name]! / max(1.0, medPrev[sc.name]!.abs()),
      });
      final heal = sum(healed[key]!);
      final cc = best(control01[key]!);

      // An alchemon earns its place on ANY axis. Only one that is unremarkable
      // on all four has nothing to offer.
      final verdict = dRatio >= 1.6
          ? 'damage'
          : pRatio >= 1.6
          ? 'defence'
          : heal >= 400
          ? 'sustain'
          : cc >= 0.55
          ? 'control'
          : dRatio >= 0.8 || pRatio >= 0.8
          ? 'solid'
          : 'NOTHING';
      verdicts[key] = verdict;
      // ignore: avoid_print
      print(
        '${key.padRight(20)} '
        '${dRatio.toStringAsFixed(1).padLeft(7)}  '
        '${pRatio.toStringAsFixed(1).padLeft(13)}  '
        '${heal.round().toString().padLeft(7)}  '
        '${(cc * 100).round().toString().padLeft(7)}%  '
        '$verdict',
      );
    }

    // ignore: avoid_print
    print('TESTBED \u2014 summary');
    final tally = <String, int>{};
    for (final v in verdicts.values) {
      tally[v] = (tally[v] ?? 0) + 1;
    }
    // ignore: avoid_print
    print('  ${tally.entries.map((e) => "${e.key} ${e.value}").join(", ")}');
    // Subjects this harness structurally cannot score, with the reason. They
    // are not failures — they are abilities whose payoff is gated behind a
    // state these scenarios never reach.
    const dormant = {
      'kin/Fire':
          'phoenix guard is a reactive one-shot; its flame and rebirth buff '
          'only unlock when the orb actually dies, which never happens here',
    };
    // ignore: avoid_print
    print('TESTBED \u2014 nothing on any axis');
    for (final e in verdicts.entries.where((e) => e.value == 'NOTHING')) {
      final why = dormant[e.key];
      // ignore: avoid_print
      print(why == null ? '  ${e.key}' : '  ${e.key} — by design: $why');
    }

    expect(dmg, hasLength(families.length * kCosmicAbilityElements.length));
  }, timeout: const Timeout(Duration(minutes: 45)));
}
