@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
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

  Future<({double damage, int kills, double healing, double orbLost})> measure(
    String family,
    String element, {
    required int wave,
    required double seconds,
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

  test('every alchemon ability, measured in the same fight', () async {
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
    const wave = 20;
    const seconds = 60.0;

    final results =
        <({String family, String element, double damage, int kills, double healing, double orbLost})>[];
    for (final family in families) {
      for (final element in kCosmicAbilityElements) {
        final r = await measure(family, element, wave: wave, seconds: seconds);
        results.add((
          family: family,
          element: element,
          damage: r.damage,
          kills: r.kills,
          healing: r.healing,
          orbLost: r.orbLost,
        ));
      }
    }

    // ignore: avoid_print
    print('TESTBED — one alchemon alone, wave $wave, ${seconds.round()}s, '
        'identical enemy stream (${results.length} subjects)');
    // ignore: avoid_print
    print('family   element     damage  kills  healing  orbLost');
    for (final r in results) {
      // ignore: avoid_print
      print(
        '${r.family.padRight(8)} ${r.element.padRight(10)} '
        '${r.damage.round().toString().padLeft(7)}  '
        '${r.kills.toString().padLeft(5)}  '
        '${r.healing.round().toString().padLeft(7)}  '
        '${r.orbLost.round().toString().padLeft(7)}',
      );
    }

    // Family summaries, then the outliers inside each.
    // ignore: avoid_print
    print('TESTBED — by family');
    // ignore: avoid_print
    print('family   medianDmg  minDmg(element)     maxDmg(element)     spread');
    for (final family in families) {
      final fam = results.where((r) => r.family == family).toList()
        ..sort((a, b) => a.damage.compareTo(b.damage));
      final median = fam[fam.length ~/ 2].damage;
      // ignore: avoid_print
      print(
        '${family.padRight(8)} '
        '${median.round().toString().padLeft(9)}  '
        '${fam.first.damage.round().toString().padLeft(6)} (${fam.first.element.padRight(9)})  '
        '${fam.last.damage.round().toString().padLeft(6)} (${fam.last.element.padRight(9)})  '
        'x${(fam.last.damage / max(1.0, fam.first.damage)).toStringAsFixed(1)}',
      );
    }

    // ignore: avoid_print
    print('TESTBED — outside half-to-double their family median');
    for (final family in families) {
      final fam = results.where((r) => r.family == family).toList()
        ..sort((a, b) => a.damage.compareTo(b.damage));
      final median = fam[fam.length ~/ 2].damage;
      for (final r in fam) {
        final ratio = r.damage / max(1.0, median);
        if (ratio >= 2.0 || ratio <= 0.5) {
          // ignore: avoid_print
          print(
            '  ${r.family}/${r.element}: ${r.damage.round()} vs median '
            '${median.round()} (x${ratio.toStringAsFixed(1)})',
          );
        }
      }
    }

    expect(results, hasLength(families.length * kCosmicAbilityElements.length));
  }, timeout: const Timeout(Duration(minutes: 45)));
}
