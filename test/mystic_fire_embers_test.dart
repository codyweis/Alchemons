import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fire Mystic's world: a drifting ember field that exists for as long as its
/// caster is alive and deployed, cast once per deployment.
///
/// The mechanic only exists across a sequence of events — cast, survive,
/// recall, redeploy, die — so nothing that looks at a single frame would catch
/// it breaking.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember fireMystic() => CosmicPartyMember(
    instanceId: 'ember',
    baseId: 'EMB01',
    displayName: 'Fire Mystic',
    family: 'Mystic',
    element: 'Fire',
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

  Future<CosmicSurvivalGame> boot() async {
    final game = CosmicSurvivalGame(
      party: [fireMystic()],
      random: Random(9),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);
    for (var i = 0; i < 900 && game.enemies.where((e) => !e.isDead).isEmpty; i++) {
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
      game.update(1 / 60);
    }
    return game;
  }

  /// Runs until the Mystic casts, holding a target in range so it will.
  Future<void> castOnce(CosmicSurvivalGame game) async {
    final comp = game.activeCompanions[0]!;
    final target = game.enemies.firstWhere((e) => !e.isDead);
    comp.specialCooldown = 0;
    for (var f = 0; f < 900; f++) {
      target
        ..isDead = false
        ..hp = 1e9
        ..position = comp.position + const Offset(70, 0);
      game.orb.currentHp = game.orb.maxHp;
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
      game.update(1 / 60);
      if (game.isMysticFieldSpent(0)) return;
    }
    fail('the Mystic never cast');
  }

  test('casting lights a field across the map and spends the ability', () async {
    final game = await boot();
    expect(game.mysticEmberCount(0), isZero);

    await castOnce(game);

    final lit = game.mysticEmberCount(0);
    expect(lit, inInclusiveRange(20, 50), reason: 'brief asks for 20-50 embers');
    expect(
      game.isMysticFieldSpent(0),
      isTrue,
      reason: 'the world is cast once per deployment',
    );

    // Spread across the arena rather than bunched on the caster — it is the
    // map's weather, not an aura the Mystic wears.
    final comp = game.activeCompanions[0]!;
    final spread = game.mysticEmberSpreadFrom(0, comp.position);
    expect(
      spread,
      greaterThan(200),
      reason: 'embers should cover the arena, not orbit the caster',
    );
  });

  test('the field outlives the cast and keeps drifting', () async {
    final game = await boot();
    await castOnce(game);
    final lit = game.mysticEmberCount(0);

    // Long past any ability duration in the game.
    for (var f = 0; f < 1800; f++) {
      game.orb.currentHp = game.orb.maxHp;
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
      game.update(1 / 60);
    }

    expect(
      game.mysticEmberCount(0),
      lit,
      reason: 'embers persist while their caster is alive and deployed',
    );
  });

  test('the world holds as long as the caster does, then closes', () async {
    final game = await boot();
    await castOnce(game);
    expect(game.mysticWorldStrength(0), greaterThan(0));

    // Far past the eighteen-second timer the world used to run on. The world
    // is the point of the family — it should not expire while its caster is
    // still standing in it.
    for (var f = 0; f < 2400; f++) {
      game.orb.currentHp = game.orb.maxHp;
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
      game.update(1 / 60);
    }
    expect(
      game.mysticWorldStrength(0),
      greaterThan(0.9),
      reason: 'the world expired while its Mystic was alive and deployed',
    );

    // Pulled out, it closes — and closes visibly rather than blinking off.
    game.returnCompanion(0);
    game.update(1 / 60);
    final midClose = game.mysticWorldStrength(0);
    expect(midClose, greaterThan(0), reason: 'it should fade, not vanish');
    for (var f = 0; f < 180; f++) {
      game.update(1 / 60);
    }
    expect(game.mysticWorldStrength(0), isZero);
  });

  test('embers never touch the shared projectile budget', () async {
    final game = await boot();
    final before = game.companionProjectiles.length;
    await castOnce(game);
    // The cast's own projectiles land in that list; the embers must not.
    final added = game.companionProjectiles.length - before;
    expect(
      added,
      lessThan(20),
      reason:
          'a field of ${game.mysticEmberCount(0)} embers must live in its own '
          'list, not in the 220-slot list shared with every trap and ward',
    );
  });

  test('recalling the Mystic puts the world out and hands the cast back', () async {
    final game = await boot();
    await castOnce(game);
    expect(game.mysticEmberCount(0), greaterThan(0));

    game.returnCompanion(0);
    expect(
      game.isMysticFieldSpent(0),
      isFalse,
      reason: 'recall frees the cast — that trade is the mechanic',
    );

    // The embers fade rather than blinking out.
    for (var f = 0; f < 240; f++) {
      game.update(1 / 60);
    }
    expect(game.mysticEmberCount(0), isZero, reason: 'the world goes out');
  });
}
