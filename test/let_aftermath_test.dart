import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a Let leaves behind after it lands.
///
/// - Plant's kill grows vines that strike the first body to come into their
///   reach and are spent — the board's "remain until an enemy collides". They
///   replaced four overlapping damage fields that ticked a body in the middle
///   four times over.
/// - Open space spawns its zones from the same table as survival and ticks
///   them over their whole radius. Its zones used to apply on contact, every
///   frame, with a ~14px centre under a 130px drawing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Projectile meteor(String element) => createCosmicSpecialAbility(
    origin: Offset.zero,
    baseAngle: 0,
    family: 'let',
    element: element,
    damage: 10,
    maxHp: 400,
    targetPos: const Offset(200, 0),
  ).projectiles.first;

  group('shared table', () {
    test('zones are exactly the board\'s ground-leaving elements', () {
      final contact = [
        for (final e in kCosmicAbilityElements)
          if (CosmicAbilityRuntime.letContactZone(e) != null) e,
      ];
      final kill = [
        for (final e in kCosmicAbilityElements)
          if (CosmicAbilityRuntime.letKillZone(e) != null) e,
      ];
      expect(contact..sort(), ['Dust', 'Earth', 'Lava', 'Poison']);
      expect(kill..sort(), ['Light', 'Mud', 'Steam']);
    });

    test('a zone carries its effect as a tick, under the Let family', () {
      final lava = CosmicAbilityRuntime.letZone(
        meteor('Lava'),
        Offset.zero,
        'Lava',
        CosmicAbilityRuntime.letContactZone('Lava')!,
      );
      expect(lava.abilityFamily, 'let');
      expect(lava.tickEffect, AbilityEffectKind.burn);
      expect(lava.hitEffect, AbilityEffectKind.none);
      expect(lava.effectRadius, 145);
      expect(lava.stationary, isTrue);
    });

    test('vines grow apart: no two reaches overlap', () {
      final spots = CosmicAbilityRuntime.letVineSpots(Offset.zero, 0.7);
      expect(spots, hasLength(CosmicAbilityRuntime.kLetVineCount));
      for (var i = 0; i < spots.length; i++) {
        for (var j = i + 1; j < spots.length; j++) {
          expect(
            (spots[i] - spots[j]).distance,
            greaterThan(CosmicAbilityRuntime.kLetVineReach * 2),
            reason: 'vines $i and $j overlap',
          );
        }
      }
    });
  });

  group('survival', () {
    CosmicPartyMember member(String element) => CosmicPartyMember(
      instanceId: 'after',
      baseId: 'AFT01',
      displayName: 'Let $element',
      family: 'Let',
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

    /// Lands one Let on a lone parked enemy and returns the game with the
    /// meteor spent, plus a second body parked well clear of the crater.
    Future<(CosmicSurvivalGame, CosmicSurvivalEnemy)> land(
      String element, {
      required double enemyHp,
    }) async {
      final game = CosmicSurvivalGame(
        party: [member(element)],
        onGameOver: () {},
      );
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      game.startGame();
      game.summonCompanion(0);
      for (
        var i = 0;
        i < 600 && game.enemies.where((e) => !e.isDead).isEmpty;
        i++
      ) {
        game.update(1 / 60);
      }
      for (
        var i = 0;
        i < 1200 && game.enemies.where((e) => !e.isDead).length < 2;
        i++
      ) {
        game.update(1 / 60);
      }
      final spot = game.orb.position + const Offset(300, 0);
      final living = game.enemies.where((e) => !e.isDead).toList();
      final target = living[0];
      final spare = living[1];
      for (final enemy in game.enemies) {
        if (!identical(enemy, target) && !identical(enemy, spare)) {
          enemy.isDead = true;
        }
      }
      target
        ..position = spot
        ..hp = enemyHp;
      spare
        ..position = game.orb.position - const Offset(300, 0)
        ..hp = 100000;
      final cast = createCosmicSpecialAbility(
        origin: game.orb.position,
        baseAngle: 0,
        family: 'let',
        element: element,
        damage: 10,
        maxHp: 400,
        targetPos: spot,
      ).projectiles.first..sourceSlotIndex = 0;
      game.companionProjectiles.add(cast);
      for (var i = 0; i < 90 && cast.isDescending; i++) {
        game.update(1 / 60);
      }
      game.update(1 / 60);
      spare.position = game.orb.position - const Offset(300, 0);
      return (game, spare);
    }

    List<Projectile> vines(CosmicSurvivalGame game) => [
      for (final p in game.companionProjectiles)
        if (p.life > 0 && CosmicAbilityRuntime.isLetVine(p)) p,
    ];

    test('a Plant kill grows five vines', () async {
      final (game, _) = await land('Plant', enemyHp: 1);
      expect(vines(game), hasLength(CosmicAbilityRuntime.kLetVineCount));
    });

    test('a Plant hit that does not kill grows nothing', () async {
      final (game, _) = await land('Plant', enemyHp: 100000);
      expect(vines(game), isEmpty);
    });

    test('a vine strikes the first body into its reach and is spent', () async {
      final (game, walker) = await land('Plant', enemyHp: 1);
      final grown = vines(game);
      final vine = grown.first;
      walker.position = vine.position + const Offset(12, 0);
      final before = walker.hp;
      for (var i = 0; i < 3; i++) {
        game.update(1 / 60);
        walker.position = vine.position + const Offset(12, 0);
      }
      expect(
        walker.hp,
        lessThan(before),
        reason: 'the vine did not strike',
      );
      final left = vines(game);
      expect(left, isNot(contains(vine)), reason: 'the vine was not spent');
      expect(left, hasLength(grown.length - 1));
    });
  });

  group('open space', () {
    Future<CosmicGame> space() async {
      final game = CosmicGame(
        world_: CosmicWorld.generate(seed: 37),
        onMeterChanged: () {},
      );
      game.ship = ShipComponent(pos: Offset.zero);
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      game.enemies.clear();
      game.activeBoss = null;
      return game;
    }

    CosmicEnemy body(Offset at) => CosmicEnemy(
      position: at,
      element: 'Earth',
      tier: EnemyTier.sentinel,
      radius: 14,
      health: 100000,
      speed: 0,
    );

    test('a Lava zone burns a body well inside its edge, on the tick', () async {
      final game = await space();
      final centre = game.ship.pos + const Offset(160, 0);
      final spec = CosmicAbilityRuntime.letContactZone('Lava')!;
      final zone = CosmicAbilityRuntime.letZone(
        meteor('Lava'),
        centre,
        'Lava',
        spec,
      );
      game.companionProjectiles.add(zone);
      // 100px out: far outside the old ~14px contact centre, well inside the
      // 145px burning ground that is drawn.
      final target = body(centre + const Offset(100, 0));
      game.enemies.add(target);
      final before = target.health;
      for (var i = 0; i < 60; i++) {
        target.position = centre + const Offset(100, 0);
        game.update(1 / 60);
      }
      final burned = before - target.health;
      expect(burned, greaterThan(0), reason: 'the zone never reached it');
      // Ticks every 0.35s: two or three in a second, never one a frame.
      expect(burned, lessThanOrEqualTo(zone.effectPower * 4 + 0.001));
    });

    test('a vine strikes once and is spent', () async {
      final game = await space();
      final at = game.ship.pos + const Offset(160, 0);
      final vine = CosmicAbilityRuntime.letVine(meteor('Plant'), at);
      game.companionProjectiles.add(vine);
      final target = body(at + const Offset(20, 0));
      game.enemies.add(target);
      final before = target.health;
      for (var i = 0; i < 10; i++) {
        target.position = at + const Offset(20, 0);
        game.update(1 / 60);
      }
      expect(before - target.health, closeTo(vine.effectPower, 0.001));
      expect(game.companionProjectiles, isNot(contains(vine)));
    });
  });
}
