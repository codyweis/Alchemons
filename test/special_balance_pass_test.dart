// THE 2026-10-07 SPECIALS BALANCE PASS, pinned.
//
// Every one of the 136 abilities was run alone through the ability testbed's
// four fights. The worst outliers were not numbers but MECHANISMS — an effect
// feeding itself, or a projectile billing a body once a frame — so those are
// what is pinned here, each in the shape that made it run away:
//
//   Horn Lava    12.8x → 1.8x   flames from flame kills threw more flames
//   Pip Dark      6.0x → 1.5x   a black hole's own execute opened the next
//   Kin Poison    4.7x → 0.7x   piercing + homing darts circled one body
//   Pip Water     4.0x → 1.9x   basic kills erupted the ricochet's splash
//   Mane Fire     8.1x → 4.1x   eight fireballs each carried a Mane's payload
//   Mane Spirit / Mane Dust     the stream and the trail billed once a frame
//
// (ratios: best-of-four-fights damage against the median ability.)

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/mane_runtime.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicSpecialResult _cast(String family, String element, {double beauty = 4}) =>
    createCosmicSpecialAbility(
      origin: Offset.zero,
      baseAngle: 0,
      family: family,
      element: element,
      damage: 100,
      maxHp: 500,
      casterBeauty: beauty,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the shapes', () {
    test('Kin Poison darts are spent on the body they reach', () {
      final darts = _cast('kin', 'Poison').projectiles;
      expect(darts, isNotEmpty);
      for (final d in darts) {
        expect(d.homing, isTrue, reason: 'each dart still seeks a body');
        expect(d.piercing, isFalse, reason: 'a pierce + homing dart circles');
      }
    });

    test('Mane Spirit\'s stream keeps the Mane per-body ceiling', () {
      final base = _cast('mane', 'Spirit').projectiles.first;
      expect(base.maxHitsPerEnemy, kManeSpecialMaxHitsPerEnemy);
      final (stream, _) = ManeRuntime.spiritStream(base, 0, 9, 0);
      expect(stream, hasLength(10));
      for (final slash in stream) {
        expect(slash.maxHitsPerEnemy, kManeSpecialMaxHitsPerEnemy);
      }
    });

    test('Mane Dust\'s trail disorients and does no damage', () {
      final shot = _cast('mane', 'Dust').projectiles.first;
      expect(shot.trailInterval, greaterThan(0), reason: 'it still lays one');
      expect(shot.trailDamage, 0);
    });

    test('Mane Fire shares one payload across its fireballs', () {
      // Every other Mane is ONE shot carrying 2.2–3.9x; Dust's 3.6x is the
      // reference. The fan carries Dust's payload at eight fireballs and
      // grows with the square root of the count — measured through the same
      // pipeline (impact and tempo scaling apply to both alike).
      for (final beauty in const [2.0, 3.0, 4.0, 5.0]) {
        final fan = _cast('mane', 'Fire', beauty: beauty).projectiles;
        final payload = fan.fold(0.0, (sum, p) => sum + p.damage);
        final dustShot = _cast('mane', 'Dust', beauty: beauty).projectiles
            .first
            .damage;
        expect(
          payload / dustShot,
          closeTo(sqrt(fan.length / 8), 0.02),
          reason: '${fan.length} fireballs at Beauty $beauty',
        );
      }
    });
  });

  // ── The runaways, measured the way the testbed measures them ──────────

  final creatures =
      (jsonDecode(
                File('assets/data/alchemons_creatures.json').readAsStringSync(),
              )
              as Map<String, dynamic>)['creatures']
          as List;

  CosmicPartyMember subject(String family, String element) {
    final base =
        (creatures.cast<Map<String, dynamic>>()).first['baseStats']
            as Map<String, dynamic>;
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

  /// Damage one alchemon deals alone in 45s of a wave-22 wisp horde — the
  /// testbed's horde fight, where every one of the runaways ran away.
  Future<double> horde(String family, String element) async {
    final game = CosmicSurvivalGame(
      party: [subject(family, element)],
      random: Random(4242),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    for (var w = 1; w < 22; w++) {
      game.spawner.resumeAfterIntermission();
    }
    game.spawner.currentPattern = SurvivalWavePattern.wispHorde;
    game.spawner.isBossWave = false;
    game.summonCompanion(0);
    game.clearCompanionTether();
    while (game.stats.timeElapsed < 45) {
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
      game.update(1 / 60);
      game.orb.currentHp = game.orb.maxHp;
      game.ship
        ..currentHp = game.ship.maxHp
        ..isDead = false;
      final comp = game.activeCompanions[0];
      if (comp != null && comp.isDead) {
        comp
          ..isDead = false
          ..currentHp = comp.maxHp;
      }
    }
    return game.companionRunStats[0]?.damageDealt ?? 0;
  }

  test('no runaway leads the horde by more than 3x a typical ability', () async {
    // The yardstick: one ordinary damage ability per family, chosen from the
    // middle of the testbed's table, so a family-wide change moves it too.
    const yardstick = [
      'horn/Fire',
      'wing/Fire',
      'let/Water',
      'pip/Fire',
      'mane/Water',
      'mask/Fire',
    ];
    final ruler = <double>[];
    for (final key in yardstick) {
      final p = key.split('/');
      ruler.add(await horde(p[0], p[1]));
    }
    ruler.sort();
    final typical = (ruler[2] + ruler[3]) / 2;

    const runaways = ['horn/Lava', 'horn/Steam', 'pip/Dark', 'pip/Water',
      'kin/Poison'];
    final over = <String>[];
    for (final key in runaways) {
      final p = key.split('/');
      final ratio = await horde(p[0], p[1]) / typical;
      if (ratio > 3.0) over.add('$key ${ratio.toStringAsFixed(1)}x');
    }
    expect(over, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
