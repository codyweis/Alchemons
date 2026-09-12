@Tags(['preview'])
library;

import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a Mystic cast costs per frame, and how many projectiles it leaves on
/// the field.
///
/// Mystics are the single-slot pick — one at a time, so each cast has to carry
/// the whole family — and they are by far the densest: four to twenty
/// projectiles a cast, most of them carrying turrets that spawn more over
/// time, on top of a full-screen environment overlay.
///
/// Reporting harness, not a gate. Tagged `preview` so a slow machine never
/// fails a build.
///
/// Lessons already paid for by the Pip version of this, all of which produced
/// impossible numbers before they were fixed:
///   - power-up selection PAUSES the game and a paused update() returns at
///     once, so the menu has to be cleared every frame;
///   - update() early-returns once the orb falls, so the orb must be held up;
///   - the JIT needs warming or whichever case runs first looks slowest.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember mystic(String element) => CosmicPartyMember(
    instanceId: 'mys',
    baseId: 'MYS01',
    displayName: '$element Mystic',
    family: 'Mystic',
    element: element,
    level: 10,
    slotIndex: 0,
    statSpeed: 4,
    statIntelligence: 4,
    statStrength: 4,
    statBeauty: 4,
    statSpeedPotential: 80,
    statIntelligencePotential: 80,
    statStrengthPotential: 80,
    statBeautyPotential: 80,
    staminaBars: 3,
    staminaMax: 3,
  );

  Future<void> measure(String element) async {
    final game = CosmicSurvivalGame(
      party: [mystic(element)],
      random: Random(11),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);

    void clearMenu() {
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
    }

    void keepAlive() {
      game.orb.currentHp = game.orb.maxHp;
      game.ship.currentHp = game.ship.maxHp;
      for (final e in game.enemies) {
        e.hp = 1e9;
      }
    }

    // Build a field to cast into.
    for (var i = 0;
        i < 6000 && game.enemies.where((e) => !e.isDead).length < 20;
        i++) {
      keepAlive();
      clearMenu();
      game.update(1 / 60);
    }

    // Warm the JIT.
    for (var f = 0; f < 300; f++) {
      keepAlive();
      clearMenu();
      game.update(1 / 60);
    }

    final comp = game.activeCompanions[0]!;
    // Clear the field before the measured cast. The build-up above lets the
    // companion cast freely, so without this the "peak" is whatever was
    // already lying around and not the footprint of the cast being measured.
    game.companionProjectiles.clear();
    var peakProjectiles = 0;
    final peakMix = <String, int>{};
    var peakFrame = -1;
    var worstFrameUs = 0;
    final sw = Stopwatch();
    var totalUs = 0;
    const frames = 900;

    for (var f = 0; f < frames; f++) {
      keepAlive();
      clearMenu();
      // Cast ONCE, then let the natural cooldown run. Forcing a cast every
      // frame pegged every element at the 220-projectile cap, which says
      // nothing about the game: Mystic carries the longest cooldown in the
      // roster (family multiplier 1.90), so what matters is the footprint of
      // a single ultimate and how long it lingers.
      if (f == 0) comp.specialCooldown = 0;
      sw
        ..reset()
        ..start();
      game.update(1 / 60);
      sw.stop();
      totalUs += sw.elapsedMicroseconds;
      if (sw.elapsedMicroseconds > worstFrameUs) {
        worstFrameUs = sw.elapsedMicroseconds;
      }
      if (game.companionProjectiles.length > peakProjectiles) {
        peakProjectiles = game.companionProjectiles.length;
        peakMix.clear();
        for (final pr in game.companionProjectiles) {
          final k = '${pr.element}/${pr.abilityFamily}/'
              '${pr.stationary ? "static" : "moving"}'
              '/${pr.visualStyle.name}/life${pr.life.toStringAsFixed(1)}';
          peakMix[k] = (peakMix[k] ?? 0) + 1;
        }
        peakFrame = f;
      }
    }

    expect(game.isGameOver, isFalse, reason: 'run ended mid-benchmark');
    expect(game.gamePaused, isFalse, reason: 'benchmark ran while paused');

    // ignore: avoid_print
    print('MYSPEAK $element frame=$peakFrame $peakMix');
    final byKind = <String, int>{};
    for (final pr in game.companionProjectiles) {
      final k = '${pr.abilityFamily}/${pr.element}/'
          '${pr.stationary ? "static" : "moving"}'
          '${pr.turretInterval > 0 ? "+turret" : ""}';
      byKind[k] = (byKind[k] ?? 0) + 1;
    }
    // ignore: avoid_print
    print('MYSMIX $element $byKind');
    // ignore: avoid_print
    print(
      'MYSCOST ${element.padRight(10)} '
      'avg=${(totalUs / frames).toStringAsFixed(1)}us '
      'worst=${worstFrameUs}us '
      'peakProjectiles=$peakProjectiles '
      'enemies=${game.enemies.where((e) => !e.isDead).length}',
    );
  }

  test('mystic per-frame cost', () async {
    // The densest casts by projectile count, plus a light one for contrast.
    for (final element in ['Plant', 'Dust', 'Fire', 'Lightning', 'Earth']) {
      await measure(element);
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
