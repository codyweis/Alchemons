import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Mystic worlds that are not Fire: Spirit, Blood, Dark, Plant, Lightning,
/// Poison, Mud and Earth. (Fire's ember field has its own file.)
///
/// Each is a rule that only exists across a sequence — cast, hold, recall — so
/// a single-frame assertion would catch none of them breaking. What is tested
/// first is the shape they all share: a world is lit once, holds while its
/// caster stands, and goes out when that caster leaves. The per-element tests
/// below then cover what makes each one different, which is the whole point of
/// the family.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember mystic(String element) => CosmicPartyMember(
    instanceId: 'w-$element',
    baseId: 'MYW01',
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

  void keepAlive(CosmicSurvivalGame game) {
    game.orb.currentHp = game.orb.maxHp;
    game.ship.currentHp = game.ship.maxHp;
    if (game.showingPowerUpSelection) {
      game.alchemicalMeter = 0;
      game.dismissPowerUpSelection();
    }
  }

  Future<CosmicSurvivalGame> boot(String element) async {
    final game = CosmicSurvivalGame(
      party: [mystic(element)],
      random: Random(5),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);
    for (var i = 0;
        i < 1200 && game.enemies.where((e) => !e.isDead).isEmpty;
        i++) {
      keepAlive(game);
      game.update(1 / 60);
    }
    return game;
  }

  /// Holds a target in range until the Mystic spends its cast.
  Future<void> castOnce(CosmicSurvivalGame game) async {
    final comp = game.activeCompanions[0]!;
    final target = game.enemies.firstWhere((e) => !e.isDead);
    comp.specialCooldown = 0;
    for (var f = 0; f < 1200; f++) {
      target
        ..isDead = false
        ..hp = 1e9
        ..position = comp.position + const Offset(70, 0);
      keepAlive(game);
      game.update(1 / 60);
      if (game.isMysticFieldSpent(0)) return;
    }
    fail('the Mystic never cast');
  }

  void run(CosmicSurvivalGame game, int frames) {
    for (var f = 0; f < frames; f++) {
      keepAlive(game);
      game.update(1 / 60);
    }
  }

  for (final element in [
    'Spirit',
    'Blood',
    'Dark',
    'Plant',
    'Lightning',
    'Poison',
    'Mud',
    'Earth',
  ]) {
    test('$element lights a world once per deployment', () async {
      final game = await boot(element);
      expect(game.mysticWorldStrength(0), isZero);
      await castOnce(game);
      expect(
        game.isMysticFieldSpent(0),
        isTrue,
        reason: 'a world is cast once and paid for with the deployment',
      );
      expect(game.mysticWorldStrength(0), greaterThan(0));
    });

    test('$element holds while its caster stands, then closes', () async {
      final game = await boot(element);
      await castOnce(game);
      // Far past any ability duration in the game.
      run(game, 2400);
      expect(
        game.mysticWorldStrength(0),
        greaterThan(0.9),
        reason: 'the world expired while its Mystic was alive and deployed',
      );

      game.returnCompanion(0);
      expect(
        game.isMysticFieldSpent(0),
        isFalse,
        reason: 'recall frees the cast — that trade is the mechanic',
      );
      run(game, 240);
      expect(game.mysticWorldStrength(0), isZero);
      expect(
        game.mysticWorldEntityCount(0),
        isZero,
        reason: 'nothing the world placed may outlive it',
      );
    });
  }

  test('Dark opens one hole, north of the orb, and holds position', () async {
    final game = await boot('Dark');
    await castOnce(game);
    final maw = game.mysticMawPosition(0);
    expect(maw, isNotNull);
    expect(
      maw!.dy,
      lessThan(game.orb.position.dy - 100),
      reason: 'the brief puts the hole at the top of the arena',
    );
    run(game, 600);
    expect(
      game.mysticMawPosition(0),
      maw,
      reason: 'it is a landmark the player fights around, not a drifting zone',
    );
  });

  test('Dark throws what it swallows back out instead of eating it', () async {
    final game = await boot('Dark');
    await castOnce(game);
    final maw = game.mysticMawPosition(0)!;

    final victim = game.enemies.firstWhere((e) => !e.isDead);
    victim
      ..hp = 1e9
      ..isDead = false
      ..position = maw;
    run(game, 30);
    expect(
      victim.isDead,
      isFalse,
      reason: 'the maw displaces, it does not execute',
    );

    // Clear of the mouth, or it is eaten again on landing and spends the rest
    // of the run in a loop at the top of the screen.
    expect(
      (victim.position - maw).distance,
      greaterThan(game.mysticMawRadius(0)!),
      reason: 'it landed back inside the pull',
    );

    // And put back where bodies come IN from, not at the arena's outer edge.
    // Thrown to the rim it was off-screen for an age, which reads as deletion
    // rather than as displacement.
    final walkBack = (victim.position - game.orb.position).distance;
    expect(
      walkBack,
      lessThan(900),
      reason:
          'ejected far outside the lane enemies actually approach through — '
          'the player never sees it come back',
    );
  });

  test('Plant grows exactly two vines and they do different jobs', () async {
    final game = await boot('Plant');
    await castOnce(game);
    expect(game.mysticVineCount(0), 2);
    expect(
      game.mysticVineLashCount(0),
      1,
      reason: 'one lashes and one spits — two ranges, not one turret twice',
    );

    // Rooted east and west of the ORB, evenly, and set well back. Anchoring to
    // the caster put the grove wherever that companion had drifted to at cast
    // time; stacking them north and south hung a canopy over the orb.
    final roots = game.mysticVineRoots(0);
    expect(roots, hasLength(2));
    final orb = game.orb.position;
    final west = roots.firstWhere((r) => r.dx < orb.dx);
    final east = roots.firstWhere((r) => r.dx > orb.dx);
    expect(west.dy, closeTo(orb.dy, 0.001));
    expect(east.dy, closeTo(orb.dy, 0.001));
    expect(
      orb.dx - west.dx,
      closeTo(east.dx - orb.dx, 0.001),
      reason: 'the two vines are not evenly spaced around the orb',
    );
    expect(
      orb.dx - west.dx,
      greaterThanOrEqualTo(250),
      reason: 'the grove should stand well back from the orb, not on top of it',
    );
  });

  test('a Plant world dresses the ground, and stops when it ends', () async {
    final game = await boot('Plant');
    await castOnce(game);
    run(game, 240);
    expect(
      game.mysticFloraCount(0),
      greaterThan(0),
      reason:
          'a tint and a particle storm sit in FRONT of the fight; the ground '
          'has to change too or the map is the same map',
    );

    // Withers rather than blinking out, then the map is back to normal.
    game.returnCompanion(0);
    run(game, 600);
    expect(game.mysticFloraCount(0), isZero);
  });

  test('a world is lit once even with developer tools re-arming', () async {
    // The switch collapses the FIRST cast's wait so a world can be judged
    // without waiting out the longest cadence in the game. It used to re-arm
    // the cast as well, which meant the world tore itself down and rebuilt
    // every five seconds — the one thing none of these abilities are.
    DebugSettingsService.enabledNotifier.value = true;
    addTearDown(() => DebugSettingsService.enabledNotifier.value = false);

    final game = await boot('Dark');
    await castOnce(game);
    expect(game.mysticWorldIgnitions(0), 1);
    final maw = game.mysticMawPosition(0);

    // Well past several debug cooldowns.
    run(game, 1800);
    expect(
      game.mysticWorldIgnitions(0),
      1,
      reason: 'the world re-lit itself while its caster just stood there',
    );
    expect(game.mysticMawPosition(0), maw);
  });

  test('Spirit raises the small dead and only the small dead', () async {
    final game = await boot('Spirit');
    await castOnce(game);

    // Wait for a body bigger than a drone to exist. The tier gate is the whole
    // balance of the mechanic, so the test must not quietly skip it when the
    // early waves happen to be all chaff.
    CosmicSurvivalEnemy? big;
    for (var f = 0; f < 12000 && big == null; f++) {
      keepAlive(game);
      game.update(1 / 60);
      for (final e in game.enemies) {
        if (e.isDead) continue;
        if (e.tier != EnemyTier.wisp && e.tier != EnemyTier.drone) {
          big = e;
          break;
        }
      }
    }
    expect(big, isNotNull, reason: 'no large body ever spawned to test against');

    final small = game.enemies.firstWhere(
      (e) => !e.isDead && (e.tier == EnemyTier.wisp || e.tier == EnemyTier.drone),
    );
    final beforeSmall = game.mysticRevenantCount(0);
    game.debugKillEnemy(small);
    expect(
      game.mysticRevenantCount(0),
      greaterThan(beforeSmall),
      reason: 'the chaff turns',
    );

    final beforeBig = game.mysticRevenantCount(0);
    game.debugKillEnemy(big!);
    expect(
      game.mysticRevenantCount(0),
      beforeBig,
      reason: 'a brute getting back up on our side would win the fight alone',
    );
  });

  test('Blood tithes from auto attacks and from nothing else', () async {
    final game = await boot('Blood');
    await castOnce(game);

    final target = game.enemies.firstWhere((e) => !e.isDead);
    target.hp = 1e9;
    game.orb.currentHp = game.orb.maxHp * 0.5;

    final before = game.orb.currentHp;
    game.debugAutoAttackDamage(target, 400);
    expect(
      game.orb.currentHp,
      greaterThan(before),
      reason: 'an auto attack landing inside a Blood world feeds the orb',
    );

    final afterAuto = game.orb.currentHp;
    game.debugAbilityDamage(target, 400);
    expect(
      game.orb.currentHp,
      afterAuto,
      reason:
          'abilities must not tithe — the world rewards the fire the player '
          'never stops putting out, not the cooldowns they were pressing anyway',
    );
  });

  test('a world never leaks into the shared projectile budget', () async {
    for (final element in [
      'Spirit',
        'Blood',
        'Dark',
        'Plant',
        'Lightning',
        'Poison',
        'Mud',
        'Earth',
    ]) {
      final game = await boot(element);
      final before = game.companionProjectiles.length;
      await castOnce(game);
      run(game, 300);
      expect(
        game.companionProjectiles.length - before,
        lessThan(20),
        reason:
            '$element replaces its salvo with a world; it should not be '
            'holding slots in the 220-slot list shared with every trap and ward',
      );
    }
  });

  test('Lightning strikes on its own clock, not on the players', () async {
    final game = await boot('Lightning');
    await castOnce(game);
    expect(
      game.mysticStrikeCount(0),
      isZero,
      reason: 'the cast is the sky changing, not a bolt thrown',
    );

    // Just under one interval: nothing yet.
    run(game, (CosmicSurvivalGame.kMysticStrikeInterval * 60).round() - 20);
    expect(game.mysticStrikeCount(0), isZero);

    // Three intervals in, three bolts — a fixed rhythm the player can count on
    // and play around, which is why the interval does not scale with stats.
    run(game, (CosmicSurvivalGame.kMysticStrikeInterval * 60 * 3).round());
    expect(game.mysticStrikeCount(0), inInclusiveRange(3, 4));

    // It stops with its caster, though it left nothing standing to fade — a
    // world on a clock has to end the same way a world made of things does.
    game.returnCompanion(0);
    final settled = game.mysticStrikeCount(0);
    run(game, 900);
    expect(
      game.mysticStrikeCount(0),
      settled,
      reason: 'the storm kept striking after its Mystic was pulled out',
    );
  });

  test('Earth quakes put every enemy on the floor at once', () async {
    final game = await boot('Earth');
    await castOnce(game);

    for (var f = 0;
        f < (CosmicSurvivalGame.kMysticQuakeInterval * 60).round() + 60;
        f++) {
      for (final e in game.enemies) {
        e.hp = 1e9;
      }
      keepAlive(game);
      game.update(1 / 60);
    }
    expect(game.mysticStrikeCount(0), greaterThanOrEqualTo(1));

    final live = game.enemies.where((e) => !e.isDead).toList();
    expect(live, isNotEmpty);
    expect(
      live.every((e) => e.effectiveSpeed == 0),
      isTrue,
      reason:
          'a quake takes the whole arena off its feet; a radius would just be '
          'another big explosion, which the roster is not short of',
    );
  });

  test('Poison lays its trail where the ship has actually flown', () async {
    final game = await boot('Poison');
    await castOnce(game);
    run(game, 420);
    expect(game.mysticPoolCount(0), greaterThan(1), reason: 'no trail was laid');

    // A fresh patch arrives unfinished and spreads. Forced by moving the ship
    // far enough to guarantee a drop on the next frame, rather than hoping the
    // most recent patch happens to be young — spacing is by distance flown, so
    // a slow-moving ship can leave the newest patch already fully spread.
    game.ship.position = game.ship.position + const Offset(400, 0);
    keepAlive(game);
    game.update(1 / 60);
    expect(
      game.mysticNewestPoolSpread(0),
      lessThan(0.5),
      reason: 'the patch laid this instant arrived already spread',
    );
    run(game, 60);
    expect(
      game.mysticOldestPoolSpread(0),
      1.0,
      reason: 'a patch never finished spreading',
    );

    // Spaced by distance flown, so a parked ship does not stack a tower of
    // patches on one spot.
    final parked = game.ship.position;
    for (var f = 0; f < 300; f++) {
      game.ship.position = parked;
      keepAlive(game);
      game.update(1 / 60);
    }
    final held = game.mysticPoolCount(0);
    for (var f = 0; f < 120; f++) {
      game.ship.position = parked;
      keepAlive(game);
      game.update(1 / 60);
    }
    expect(
      game.mysticPoolCount(0),
      lessThanOrEqualTo(held),
      reason: 'a stationary ship kept spawning patches where it sat',
    );
  });

  test('Mud bogs down what the ship hits, and nothing else', () async {
    final game = await boot('Mud');
    await castOnce(game);

    final live = game.enemies.where((e) => !e.isDead).toList();
    expect(live.length, greaterThan(1));
    final shipHit = live.first..hp = 1e9;
    final partyHit = live.last..hp = 1e9;

    game.debugShipAttackDamage(shipHit, 5);
    // The floor of the range is 70%, rising to 90% with stats and further with
    // surges. Pinned rather than checked loosely, because the whole pitch of a
    // Mud world is a specific number: nothing crosses the field.
    expect(
      shipHit.effectiveSpeed,
      lessThanOrEqualTo(shipHit.speed * 0.30 + 0.001),
      reason: "the ship's guns are supposed to be the brake",
    );

    game.debugAutoAttackDamage(partyHit, 5);
    expect(
      partyHit.effectiveSpeed,
      greaterThan(partyHit.speed * 0.30),
      reason:
          'a companion basic must not carry the mire — this world hands the '
          "PLAYER a tool, which is what keeps it distinct from Blood's tithe",
    );
  });
}
