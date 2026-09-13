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
  const scenarios = <({String name, int wave, SurvivalWavePattern? pattern, bool boss})>[
    // Many small bodies at once: the test of clear rate and area coverage.
    (name: 'horde', wave: 22, pattern: SurvivalWavePattern.wispHorde, boss: false),
    // Standoff shooters at range: the test of reach and of closing distance.
    (name: 'shooters', wave: 22, pattern: SurvivalWavePattern.shooterScreen, boss: false),
    // Heavy bodies walking in: the test of single-target damage and of holding
    // ground.
    (name: 'siege', wave: 22, pattern: SurvivalWavePattern.siegePush, boss: false),
    // One enormous health pool that does not die to area damage at all.
    (name: 'boss', wave: 25, pattern: null, boss: true),
  ];

  Future<({double damage, int kills, double healing, double orbLost})> measure(
    String family,
    String element, {
    required int wave,
    required double seconds,
    SurvivalWavePattern? pattern,
    required bool boss,
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
    game.summonCompanion(0);
    game.clearCompanionTether();

    var orbLost = 0.0;
    var prevOrb = game.orb.currentHp;
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
      final now = game.orb.currentHp;
      if (now < prevOrb) orbLost += prevOrb - now;
      game.orb.currentHp = game.orb.maxHp;
      game.ship.currentHp = game.ship.maxHp;
      prevOrb = game.orb.currentHp;
      final comp = game.activeCompanions[0];
      if (comp != null && comp.isDead) {
        comp
          ..isDead = false
          ..currentHp = comp.maxHp;
      }
    }

    final s = game.companionRunStats[0];
    return (
      damage: s?.damageDealt ?? 0,
      kills: s?.kills ?? 0,
      healing: s?.healingDone ?? 0,
      orbLost: orbLost,
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

    // family/element -> scenario -> damage
    final byScenario = <String, Map<String, double>>{};
    final killsByScenario = <String, Map<String, int>>{};
    for (final family in families) {
      for (final element in kCosmicAbilityElements) {
        final key = '$family/$element';
        byScenario[key] = {};
        killsByScenario[key] = {};
        for (final s in scenarios) {
          final r = await measure(
            family,
            element,
            wave: s.wave,
            seconds: seconds,
            pattern: s.pattern,
            boss: s.boss,
          );
          byScenario[key]![s.name] = r.damage;
          killsByScenario[key]![s.name] = r.kills;
        }
      }
    }

    // ignore: avoid_print
    print('TESTBED \u2014 one alchemon alone, ${seconds.round()}s per fight, '
        'identical enemy stream (${byScenario.length} subjects x '
        '${scenarios.length} fights)');
    // ignore: avoid_print
    print('subject              ${scenarios.map((s) => s.name.padLeft(9)).join()}   best');
    for (final entry in byScenario.entries) {
      final best = entry.value.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      // ignore: avoid_print
      print(
        '${entry.key.padRight(20)} '
        '${scenarios.map((s) => entry.value[s.name]!.round().toString().padLeft(9)).join()}'
        '   ${best.key}',
      );
    }

    // The question that matters is not "who is lowest in one fight" but "is
    // there any fight this alchemon is FOR". Scored per scenario against that
    // scenario's own median, so specialists are credited where they specialise.
    // ignore: avoid_print
    print('TESTBED \u2014 specialists and the genuinely weak');
    final medians = <String, double>{};
    for (final s in scenarios) {
      final all = byScenario.values.map((m) => m[s.name]!).toList()..sort();
      medians[s.name] = all[all.length ~/ 2];
    }
    final noGoodFight = <String>[];
    for (final entry in byScenario.entries) {
      final ratios = {
        for (final s in scenarios)
          s.name: entry.value[s.name]! / max(1.0, medians[s.name]!),
      };
      final bestRatio = ratios.values.reduce(max);
      if (bestRatio >= 1.6) {
        // ignore: avoid_print
        print(
          '  SPECIALIST ${entry.key.padRight(18)} '
          '${ratios.entries.where((e) => e.value >= 1.6).map((e) => "${e.key} x${e.value.toStringAsFixed(1)}").join(", ")}',
        );
      } else if (bestRatio < 0.55) {
        noGoodFight.add(
          '${entry.key.padRight(18)} best is ${ratios.entries.reduce((a, b) => a.value >= b.value ? a : b).key} '
          'at x${bestRatio.toStringAsFixed(2)} of median',
        );
      }
    }
    // ignore: avoid_print
    print('TESTBED \u2014 no fight they are good at '
        '(under 55% of the median in EVERY scenario)');
    for (final n in noGoodFight) {
      // ignore: avoid_print
      print('  $n');
    }
    // ignore: avoid_print
    print('  ${noGoodFight.length} of ${byScenario.length} subjects have no '
        'fight of their own');

    expect(
      byScenario,
      hasLength(families.length * kCosmicAbilityElements.length),
    );
  }, timeout: const Timeout(Duration(minutes: 45)));
}
