import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pip places two different kinds of thing and they want opposite treatment.
///
/// The moving dart ricochets and is spent by doing so. The stationary
/// placements — Mud's trail puffs, Fire's pools, Poison's line — are supposed
/// to sit there and keep working. The consume rule tested only
/// `abilityFamily == 'pip'`, so it caught both, and every stationary placement
/// was retired after `kPipMaxPierceHits` contacts like a dart out of bounces.
///
/// A mud puff is dropped directly onto the enemy trailing it, so both contacts
/// landed within a frame or two and the puff died on spawn. Mud's whole line on
/// the design board is "affected enemies permanently leave mud trails that slow
/// other enemies", and the trails were never surviving to slow anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember mudPip() => CosmicPartyMember(
    instanceId: 'mud',
    baseId: 'MUD01',
    displayName: 'Mud Pip',
    family: 'Pip',
    element: 'Mud',
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
      party: [mudPip()],
      random: Random(3),
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

  /// A stationary Mud trail puff, exactly as the trail emitter builds one.
  Projectile mudPuff(Offset at) => Projectile(
    position: at,
    angle: 0,
    element: 'Mud',
    damage: 0,
    life: 5.5,
    speedMultiplier: 0,
    stationary: true,
    piercing: true,
    radiusMultiplier: 1.1,
    visualScale: 1.0,
    visualStyle: ProjectileVisualStyle.sigil,
    abilityFamily: 'pip',
    tickEffect: AbilityEffectKind.slow,
    effectPower: 1.0,
    effectRadius: 38,
    effectDuration: 1.2,
  );

  test('a mud puff survives an enemy standing on it', () async {
    final game = await boot();
    final target = game.enemies.firstWhere((e) => !e.isDead);
    final spot = game.orb.position + const Offset(220, 0);

    final puff = mudPuff(spot);
    game.companionProjectiles.add(puff);

    // Park an enemy on the puff for a full second — many more than the two
    // contacts that used to retire it.
    for (var f = 0; f < 60; f++) {
      target
        ..isDead = false
        ..hp = 1e9
        ..position = spot;
      game.orb.currentHp = game.orb.maxHp;
      game.update(1 / 60);
    }

    expect(
      game.companionProjectiles.contains(puff),
      isTrue,
      reason:
          'the puff was consumed by contact. Stationary pip placements are not '
          'ricochet darts and must not be spent like one.',
    );
    expect(puff.life, greaterThan(0));
  });

  test('the ricochet dart is still spent by its bounces', () async {
    final game = await boot();
    final target = game.enemies.firstWhere((e) => !e.isDead);
    final spot = game.orb.position + const Offset(200, 0);

    // A dart with no bounces left should not survive contact — the narrowing
    // must not have turned pip darts into piercing projectiles.
    final dart = Projectile(
      position: spot,
      angle: 0,
      element: 'Mud',
      damage: 1,
      life: 5.0,
      speedMultiplier: 0.01,
      piercing: true,
      bounceCount: 0,
      visualStyle: ProjectileVisualStyle.dart,
      abilityFamily: 'pip',
      sourceSlotIndex: 0,
    );
    game.companionProjectiles.add(dart);

    for (var f = 0; f < 120; f++) {
      target
        ..isDead = false
        ..hp = 1e9
        ..position = spot;
      game.orb.currentHp = game.orb.maxHp;
      game.update(1 / 60);
      if (!game.companionProjectiles.contains(dart)) break;
    }

    expect(
      game.companionProjectiles.contains(dart),
      isFalse,
      reason: 'a spent pip dart should still be consumed on contact',
    );
  });

  test('the trail cannot own the shared placement list', () async {
    final game = await boot();
    final spot = game.orb.position;

    // Far more puffs than the budget, as a wave of tagged enemies would
    // produce, then let the emitter keep running.
    for (var i = 0; i < kPipMudTrailBudget * 3; i++) {
      game.companionProjectiles.add(
        mudPuff(spot + Offset(i * 3.0, 0)),
      );
    }
    for (final e in game.enemies) {
      e.pipMudTrail = true;
    }

    var peak = 0;
    for (var f = 0; f < 400; f++) {
      for (final e in game.enemies) {
        e.hp = 1e9;
        e.pipMudTrail = true;
      }
      game.orb.currentHp = game.orb.maxHp;
      game.update(1 / 60);
      final live = game.companionProjectiles
          .where((p) => p.abilityFamily == 'pip' && p.element == 'Mud' && p.stationary)
          .length;
      if (live > peak) peak = live;
    }

    // The pre-seeded flood ages out and the emitter never rebuilds past the
    // budget, so the list is left with room for every other placement.
    final settled = game.companionProjectiles
        .where((p) => p.abilityFamily == 'pip' && p.element == 'Mud' && p.stationary)
        .length;
    // ignore: avoid_print
    print('PIPMUD peak=$peak settled=$settled budget=$kPipMudTrailBudget');
    expect(
      settled,
      lessThanOrEqualTo(kPipMudTrailBudget),
      reason:
          'the trail settled at $settled puffs, past its $kPipMudTrailBudget '
          'budget, on a list of 220 shared with every trap, ward and pool.',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
