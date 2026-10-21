import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/kin_support_runtime.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Four abilities that worked against the player (user 2026-10-20: "any
/// abilities you see that need a change?"). Each keeps its board effect;
/// only the way it pushes, or what it does to the ship, changed. Driven
/// through the real survival game.
///
/// - Air Horn blew bodies away from the horn, and the horn stands by the
///   orb, so a body between them was blown into the orb.
/// - Air Pip pushed its survivors along the dart's flight, so a dart coming
///   in toward the orb pushed them at it.
/// - Steam geysers threw bodies up the screen, which below the orb is at it.
/// - A Dark Kin's veil sent the horde at the ship, which died in a second.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember member(String family, String element) => CosmicPartyMember(
    instanceId: '$family-$element',
    baseId: 'DIR01',
    displayName: '$family $element',
    family: family,
    element: element,
    level: 10,
    slotIndex: 0,
    statSpeed: 4.25,
    statIntelligence: 4.25,
    statStrength: 4.25,
    statBeauty: 4.25,
    statSpeedPotential: 50,
    statIntelligencePotential: 50,
    statStrengthPotential: 50,
    statBeautyPotential: 50,
    staminaBars: 3,
    staminaMax: 3,
  );

  /// A quiet arena: the one companion is out, nothing is spawned, the
  /// special is held.
  Future<CosmicSurvivalGame> arena(String family, String element) async {
    final game = CosmicSurvivalGame(
      party: [member(family, element)],
      onGameOver: () {},
      random: Random(5),
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);
    game.clearCompanionTether();
    game.activeCompanions[0]!.specialCooldown = 99999;
    game.enemies.clear();
    game.orb.shieldHp = 0;
    return game;
  }

  CosmicSurvivalEnemy body(
    Offset at, {
    double damage = 0,
    EnemyConduct conduct = EnemyConduct.charge,
  }) => CosmicSurvivalEnemy(
    position: at,
    hp: 1e6,
    maxHp: 1e6,
    speed: 0,
    damage: damage,
    radius: 10,
    tier: EnemyTier.drone,
    element: 'Earth',
    conduct: conduct,
    target: CosmicEnemyTarget.orb,
    retargetTimer: 0,
  );

  /// One frame with nothing the spawner sent on the field.
  void quietFrame(CosmicSurvivalGame game) {
    game.enemies.removeWhere((e) => e.hp < 1e5);
    game.update(1 / 60);
    game.enemies.removeWhere((e) => e.hp < 1e5);
  }

  test('an Air Horn blows a body between it and the orb away from the orb, '
      'not into it', () async {
    final game = await arena('Horn', 'Air');
    final horn = game.activeCompanions[0]!;
    final orb = game.orb.position;
    // The horn out on the +x side; the body between it and the orb, past
    // the still middle and inside the rim.
    final between = body(orb + const Offset(80, 0));
    // And one on the horn's far side, which both rules blow outward.
    final beyond = body(orb + const Offset(380, 0));
    game.enemies.addAll([between, beyond]);
    for (var i = 0; i < 20; i++) {
      horn.position = orb + const Offset(220, 0);
      horn.steeringVelocity = Offset.zero;
      quietFrame(game);
    }
    expect(
      between.position.dx - orb.dx,
      greaterThan(80),
      reason: 'the body between horn and orb was blown toward the orb',
    );
    expect(beyond.position.dx - orb.dx, greaterThan(380));
  });

  test('an Air Pip pushes the body its dart leaves alive away from the orb',
      () async {
    final game = await arena('Pip', 'Air');
    final orb = game.orb.position;
    final survivor = body(orb + const Offset(300, 0));
    game.enemies.add(survivor);
    // A dart coming in from the rim toward the orb, as a ricochet off a
    // body further out sends it: it meets the survivor on its outer side.
    final dart = Projectile(
      position: orb + const Offset(312, 0),
      angle: pi,
      element: 'Air',
      damage: 1,
      abilityFamily: 'pip',
      hitEffect: AbilityEffectKind.knockback,
      effectPower: 10,
      sourceSlotIndex: 0,
    );
    game.resolveAbilityHit(dart, survivor, killed: false);
    expect(
      survivor.knockbackVelocity.dx,
      greaterThan(0),
      reason: 'the survivor was pushed along the dart, at the orb',
    );
    expect(
      survivor.knockbackVelocity.distance,
      closeTo(CosmicAbilityRuntime.knockbackImpulse(10), 1e-6),
      reason: 'the push keeps its strength',
    );
  });

  test('a Steam geyser below the orb throws bodies away from it', () async {
    final game = await arena('Let', 'Steam');
    final orb = game.orb.position;
    // Survival's +y is down the screen: the geyser stands below the orb.
    final vent = Projectile(
      position: orb + const Offset(0, 200),
      angle: 0,
      element: 'Steam',
      damage: 0,
      speedMultiplier: 0,
      stationary: true,
      piercing: true,
      life: 9,
      abilityFamily: 'let',
      tickEffect: AbilityEffectKind.geyser,
      effectPower: 1,
      effectRadius: 115,
      effectDuration: 9,
      sourceSlotIndex: 0,
    );
    game.companionProjectiles.add(vent);
    // One on the orb side of the vent, one beyond it: up the screen, both
    // were thrown at the orb.
    final near = body(orb + const Offset(0, 160));
    final far = body(orb + const Offset(30, 260));
    game.enemies.addAll([near, far]);
    game.debugRebuildEnemyGrid();
    game.updatePersistentAbilityEffects(0.4);
    for (final b in [near, far]) {
      final away = b.position - orb;
      final push = b.knockbackVelocity;
      expect(
        push.dx * away.dx + push.dy * away.dy,
        greaterThan(0),
        reason: 'a geyser threw a body toward the orb',
      );
      expect(
        push.distance,
        closeTo(CosmicAbilityRuntime.geyserKnockbackSpeed, 1e-6),
      );
    }
  });

  test('a Dark Kin veil draws the horde onto the ship without letting it '
      'die there in seconds', () async {
    final game = await arena('Kin', 'Dark');
    final kin = game.activeCompanions[0]!;
    kin.kinDarkCloakTimer = 30;
    game.ship.position = game.orb.position + const Offset(400, 0);
    // A crowd on the ship. Unshrouded, 6 × 20 × 0.75 = 90 a second ground
    // a hundred-point ship down in about a second.
    final crowd = [
      for (var i = 0; i < 6; i++) body(game.ship.position, damage: 20),
    ];
    game.enemies.addAll(crowd);
    quietFrame(game);
    expect(crowd.every((b) => b.target == CosmicEnemyTarget.ship), isTrue);
    expect(game.debugKinDarkVeilDraws, isTrue);

    var lowest = game.ship.currentHp;
    for (var i = 0; i < 60 * 6; i++) {
      for (final b in crowd) {
        b.position = game.ship.position;
      }
      quietFrame(game);
      lowest = min(lowest, game.ship.currentHp);
    }
    expect(game.ship.isDead, isFalse, reason: 'the veil fed the ship to it');
    // It lifted once the ship fell low, and the bodies went back to the orb.
    expect(game.debugKinDarkVeilDraws, isFalse);
    expect(crowd.every((b) => b.target == CosmicEnemyTarget.orb), isTrue);
    expect(
      lowest,
      greaterThan(game.ship.maxHp * (KinSupport.darkVeilLiftFraction - 0.05)),
    );
    // The companions stay hidden for the rest of the cast.
    expect(kin.kinDarkCloakTimer, greaterThan(0));

    // The next cast, with the ship mended, draws them onto it again (held
    // off the ship here, so that they are only drawn and do not grind it).
    game.ship.currentHp = game.ship.maxHp;
    for (final b in crowd) {
      b.position = game.ship.position + const Offset(300, 0);
    }
    kin.kinDarkCloakTimer = 0;
    kin.specialCooldown = 0;
    // Something in reach to cast at.
    game.enemies.add(body(game.orb.position + const Offset(0, -150)));
    for (var i = 0; i < 60 * 8 && kin.kinDarkCloakTimer <= 0; i++) {
      quietFrame(game);
    }
    expect(kin.kinDarkCloakTimer, greaterThan(0), reason: 'the kin never cast');
    // Each body turns at its next look round (under 2.6 s).
    for (var i = 0; i < 60 * 3; i++) {
      quietFrame(game);
    }
    expect(game.debugKinDarkVeilDraws, isTrue);
    expect(crowd.every((b) => b.target == CosmicEnemyTarget.ship), isTrue);
  });

  test('the veiled ship takes a share of a body\'s blows', () async {
    Future<double> grind({required bool veil}) async {
      final game = await arena('Kin', 'Dark');
      if (veil) game.activeCompanions[0]!.kinDarkCloakTimer = 30;
      game.ship.position = game.orb.position + const Offset(400, 0);
      final stalker = body(
        game.ship.position,
        damage: 20,
        conduct: EnemyConduct.stalk,
      )..target = CosmicEnemyTarget.ship;
      stalker.retargetTimer = 99;
      game.enemies.add(stalker);
      final before = game.ship.currentHp;
      for (var i = 0; i < 60; i++) {
        stalker.position = game.ship.position;
        quietFrame(game);
      }
      return before - game.ship.currentHp;
    }

    final bare = await grind(veil: false);
    final veiled = await grind(veil: true);
    expect(bare, greaterThan(10));
    expect(
      veiled / bare,
      closeTo(KinSupport.darkVeilShipDamageTaken, 0.02),
    );
  });

  test('an enemy beam that empties the ship brings it down', () async {
    // Beams and shockwaves were the one hit that never checked: a beam left
    // the ship flying at -200, and a downed ship kept being hit
    // (2026-10-20).
    final game = await arena('Horn', 'Earth');
    final ship = game.ship;
    ship.position = game.orb.position + const Offset(0, 400);
    ship.currentHp = 10;
    SurvivalEnemyHazard beamAt(Offset at) => SurvivalEnemyHazard(
      kind: EnemyHazardKind.beam,
      origin: at + const Offset(-300, 0),
      angle: 0,
      element: 'Fire',
      damage: 500,
      life: 0.4,
      maxLife: 0.4,
      length: 600,
      width: 20,
    );
    game.enemyHazards.add(beamAt(ship.position));
    game.update(1 / 60);
    expect(ship.isDead, isTrue);
    final downAt = ship.currentHp;
    game.enemyHazards.add(beamAt(ship.position));
    game.update(1 / 60);
    expect(ship.currentHp, downAt, reason: 'a downed ship is not hit again');
  });
}
