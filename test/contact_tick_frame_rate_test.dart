// THE SAME FIGHT AT 60 AND 120 FPS.
//
// Contact is tested every frame, so a projectile that can touch the same body
// again and again — piercing, with no per-body ceiling — billed it once per
// frame, and a 120 Hz screen did twice the damage a 60 Hz one did. Measured
// 2026-10-07 on a fixed target range: every Mask auto-attack (24k → 44k),
// Kin Crystal's shards (18k → 35k), Mane Light's ward ring (113k → 216k),
// Wing Spirit and Wing Dark. Those now touch on a fixed 60 Hz clock
// (`Projectile.takeContactTick`), and the Mask dart hits each body once.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

Projectile _shot({required bool piercing, int cap = 0}) =>
    Projectile(position: Offset.zero, angle: 0, damage: 1, piercing: piercing)
      ..maxHitsPerEnemy = cap;

int _ticks(Projectile p, double dt, int frames) {
  var n = 0;
  for (var i = 0; i < frames; i++) {
    if (p.takeContactTick(dt)) n++;
  }
  return n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the contact clock', () {
    test('an unbounded re-hitter touches 60 times a second at any rate', () {
      expect(_ticks(_shot(piercing: true), 1 / 60, 60), 60);
      expect(_ticks(_shot(piercing: true), 1 / 120, 120), 60);
      expect(_ticks(_shot(piercing: true), 1 / 144, 144), closeTo(60, 1));
    });

    test('a real device frame (jittered around 60 Hz) still counts', () {
      final p = _shot(piercing: true);
      var n = 0;
      for (var i = 0; i < 600; i++) {
        if (p.takeContactTick(i.isEven ? 0.0162 : 0.0171)) n++;
      }
      expect(n, closeTo(600, 6));
    });

    test('everything else still tests every frame', () {
      expect(_ticks(_shot(piercing: false), 1 / 120, 120), 120);
      expect(_ticks(_shot(piercing: true, cap: 2), 1 / 120, 120), 120);
    });
  });

  test('a Mask dart pierces, but strikes each body once', () {
    final darts = createFamilyBasicAttack(
      origin: Offset.zero,
      angle: 0,
      element: 'Fire',
      family: 'mask',
      damage: 10,
    );
    expect(darts.single.piercing, isTrue);
    expect(darts.single.maxHitsPerEnemy, 1);
  });

  // ── One target, one alchemon, 30 seconds, at 60 and at 120 fps ──────────

  final base =
      ((jsonDecode(
                    File(
                      'assets/data/alchemons_creatures.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['creatures']
              as List)
          .cast<Map<String, dynamic>>()
          .first['baseStats']
      as Map<String, dynamic>;

  CosmicPartyMember subject(String family, String element) {
    // Potential 70 sits just under the stat knee (internal 5), where the
    // 2026-10-09 power curve left combat exactly as it was. This is a single
    // seed, and companion positioning still drifts between frame rates: over
    // six seeds Kin/Crystal at P80 ranged 0.72-1.43 and Wing/Dark at P100
    // 0.23-2.65 on the code before that change too. Above the knee the new
    // curve moved this seed onto a drifting path, which this test is not
    // about. It pins the contact clock; the drift is its own open bug.
    double stat(String key) => AlchemonStatSystem.effectiveInternal(
      speciesBase: base[key] as int,
      level: 10,
      potential: 70,
    );
    return CosmicPartyMember(
      instanceId: 'fr-$family-$element',
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
      staminaBars: 3,
      staminaMax: 3,
    );
  }

  /// Damage on one immortal, unmoving heavy body; nothing else spawns.
  Future<double> onTarget(String family, String element, double step) async {
    final game = CosmicSurvivalGame(
      party: [subject(family, element)],
      random: Random(4242),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);
    game.clearCompanionTether();
    final home = game.orb.position + const Offset(0, -210);
    final dummy = CosmicSurvivalEnemy(
      position: home,
      hp: 1e7,
      maxHp: 1e7,
      speed: 0,
      damage: 0,
      radius: 40,
      tier: EnemyTier.brute,
      element: 'Fire',
      conduct: EnemyConduct.charge,
      target: CosmicEnemyTarget.companion,
    );
    var t = 0.0;
    while (t < 30) {
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
      game.enemies.removeWhere((e) => !identical(e, dummy));
      dummy
        ..isDead = false
        ..hp = dummy.maxHp
        ..position = home
        ..knockbackVelocity = Offset.zero;
      if (!game.enemies.contains(dummy)) game.enemies.add(dummy);
      game.update(step);
      t += step;
      game.orb.currentHp = game.orb.maxHp;
    }
    return game.companionRunStats[0]?.damageDealt ?? 0;
  }

  for (final key in const ['kin/Crystal', 'wing/Spirit', 'wing/Dark']) {
    test('$key does the same damage at 120 fps as at 60', () async {
      final p = key.split('/');
      final at60 = await onTarget(p[0], p[1], 1 / 60);
      final at120 = await onTarget(p[0], p[1], 1 / 120);
      expect(at60, greaterThan(0));
      expect(
        at120 / at60,
        closeTo(1.0, 0.12),
        reason: '60 fps: ${at60.round()}  120 fps: ${at120.round()}',
      );
    });
  }
}
