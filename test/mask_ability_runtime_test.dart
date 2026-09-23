import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember member(String element) => CosmicPartyMember(
  instanceId: 'mask-runtime',
  baseId: 'MSK01',
  displayName: 'Mask $element',
  family: 'Mask',
  element: element,
  level: 10,
  slotIndex: 0,
  statSpeed: 4,
  statIntelligence: 4,
  statStrength: 4,
  statBeauty: 4,
  staminaBars: 5,
  staminaMax: 5,
);

List<Projectile> cast(String element, {Offset at = Offset.zero}) =>
    createCosmicSpecialAbility(
      origin: at,
      baseAngle: 0,
      family: 'mask',
      element: element,
      damage: 40,
      maxHp: 100,
      casterPower: 4,
      casterBeauty: 4,
      casterIntelligence: 4,
      casterStrength: 4,
      targetPos: at,
    ).projectiles..forEach((p) => p.sourceSlotIndex = 0);

CosmicEnemy openEnemy(Offset at, {double hp = 1000}) => CosmicEnemy(
  position: at,
  element: 'Fire',
  tier: EnemyTier.drone,
  radius: 10,
  health: hp,
  speed: 0,
);

CosmicSurvivalEnemy survivalEnemy(
  Offset at, {
  double hp = 1000,
  EliteAffix? affix,
}) => CosmicSurvivalEnemy(
  position: at,
  hp: hp,
  maxHp: hp,
  speed: 0,
  damage: 0,
  radius: 10,
  tier: EnemyTier.drone,
  element: 'Fire',
  conduct: EnemyConduct.charge,
  target: CosmicEnemyTarget.orb,
  eliteAffix: affix,
);

CosmicGame openArena() {
  final game = CosmicGame(
    world_: CosmicWorld.generate(seed: 7),
    onMeterChanged: () {},
  );
  game.ship = ShipComponent(pos: Offset.zero);
  game.activeCompanions[0] = CosmicCompanion(
    member: member('Ice'),
    position: Offset.zero,
    maxHp: 100,
    currentHp: 50,
    physAtk: 5,
    elemAtk: 5,
    physDef: 5,
    elemDef: 5,
    cooldownReduction: 1,
    critChance: 0,
    attackRange: 180,
    specialAbilityRange: 220,
  );
  return game;
}

Future<CosmicSurvivalGame> survivalArena([String element = 'Ice']) async {
  final game = CosmicSurvivalGame(
    party: [member(element)],
    onGameOver: () {},
    random: Random(5),
  );
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();
  game.startGame();
  game.summonCompanion(0);
  game.activeCompanions[0]!.specialCooldown = 99999;
  game.activeCompanions[0]!.basicCooldown = 99999;
  game.enemies.clear();
  game.companionProjectiles.clear();
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cosmic Mask runtime', () {
    for (final element in ['Crystal', 'Fire']) {
      test('$element parent triggers once; children never reproduce', () {
        final game = openArena();
        final p = cast(element).first;
        final enemy = openEnemy(p.position);
        game.enemies.add(enemy);
        game.resolveMaskContact(p, enemy);
        final expected = element == 'Crystal' ? 3 : 1;
        expect(game.companionProjectiles.length, expected);
        for (var i = 0; i < 60; i++) {
          game.resolveMaskContact(p, enemy);
          for (final child in game.companionProjectiles.toList()) {
            game.resolveMaskContact(child, enemy);
          }
        }
        expect(game.companionProjectiles.length, expected);
        expect(
          enemy.health,
          1000,
          reason: 'dispatcher must not apply contact damage twice',
        );
      });
    }
    test('Light consumes only one victim', () {
      final game = openArena();
      final p = cast('Light').single;
      final a = openEnemy(p.position), b = openEnemy(p.position);
      game.enemies.addAll([a, b]);
      game.resolveMaskContact(p, a);
      game.resolveMaskContact(p, b);
      expect(a.dead, isTrue);
      expect(b.dead, isFalse);
      expect(b.health, 1000);
    });
    test(
      'Dark ejects unharmed and cannot execute distant low-health enemies',
      () {
        final game = openArena();
        final p = cast('Dark').single;
        final near = openEnemy(p.position, hp: 1);
        final far = openEnemy(p.position + const Offset(1000, 0), hp: 1);
        game.enemies.addAll([near, far]);
        game.tickMaskPlacement(p);
        expect(near.health, 1);
        expect(near.dead, isFalse);
        expect(
          (near.position - p.position).distance,
          greaterThan(p.effectRadius),
        );
        expect(far.health, 1);
        expect(far.position, p.position + const Offset(1000, 0));
      },
    );
    test('Earth heals only allies inside the pool, without any enemies', () {
      final game = openArena()..shipHealth = 20;
      final p = cast('Earth').first..position = Offset.zero;
      game.activeCompanions[0]!.position = const Offset(1000, 0);
      game.tickMaskPlacement(p);
      expect(game.shipHealth, greaterThan(20));
      expect(game.activeCompanions[0]!.currentHp, 50);
      game.ship.pos = const Offset(1000, 0);
      game.activeCompanions[0]!.position = Offset.zero;
      final before = game.shipHealth;
      game.tickMaskPlacement(p);
      expect(game.shipHealth, before);
      expect(game.activeCompanions[0]!.currentHp, greaterThan(50));
    });
    test(
      'Ice buffs nearby allies and ship without enemies, not distant allies',
      () {
        final game = openArena();
        final p = cast('Ice').single..position = Offset.zero;
        game.companionProjectiles.add(p);
        game.tickMaskPlacement(p);
        expect(game.activeCompanions[0]!.damageAmp, 2.4);
        expect(game.maskShipDamageAmp, 2.4);
        game.ship.pos = const Offset(1000, 0);
        expect(game.maskShipDamageAmp, 1);
        final comp = game.activeCompanions[0]!;
        comp.position = const Offset(1000, 0);
        comp.damageAmpTimer = 0;
        game.tickMaskPlacement(p);
        expect(comp.damageAmp, 1);
      },
    );
    test(
      'Lightning damages a lone enemy throughout the field and grows once per body',
      () {
        final game = openArena();
        final p = cast('Lightning').single;
        final enemy = openEnemy(p.position + const Offset(80, 0));
        game.enemies.add(enemy);
        final radius = p.effectRadius;
        game.tickMaskPlacement(p);
        expect(enemy.health, 1000 - p.effectPower);
        expect(p.effectRadius, radius + 14);
        game.tickMaskPlacement(p);
        expect(enemy.health, 1000 - 2 * p.effectPower);
        expect(p.effectRadius, radius + 14);
      },
    );
    test('Plant recasts feed one vine and increase damage and radius', () {
      final game = openArena();
      game.activateMaskPlacements(cast('Plant'));
      final vine = game.companionProjectiles.single;
      final power = vine.effectPower, radius = vine.effectRadius;
      for (var i = 0; i < 12; i++) {
        game.activateMaskPlacements(cast('Plant'));
      }
      expect(game.companionProjectiles.length, 1);
      expect(vine.effectPower, greaterThan(power));
      expect(vine.effectRadius, greaterThan(radius));
      final enemy = openEnemy(vine.position);
      game.enemies.add(enemy);
      game.tickMaskPlacement(vine);
      expect(enemy.health, lessThan(1000));
    });
    test(
      'Dust shields attach, refresh without stacking, and follow allies',
      () {
        final game = openArena();
        game.activateMaskPlacements(cast('Dust'));
        expect(game.companionProjectiles.length, 2);
        game.activateMaskPlacements(cast('Dust'));
        expect(game.companionProjectiles.length, 2);
        game.ship.pos = const Offset(40, 30);
        game.activeCompanions[0]!.position = const Offset(80, 10);
        game.updateMaskRuntime(0.1);
        expect(game.companionProjectiles.first.position, game.ship.pos);
        expect(
          game.companionProjectiles.last.position,
          game.activeCompanions[0]!.position,
        );
        expect(
          game.companionProjectiles.every((p) => p.interceptCharges == 5),
          isTrue,
        );
      },
    );
    test('Spirit collects at the ship and clears enemies only at six', () {
      final game = openArena();
      final enemy = openEnemy(const Offset(500, 0));
      game.enemies.add(enemy);
      for (var i = 0; i < 6; i++) {
        final p = cast('Spirit').first..position = game.ship.pos;
        game.companionProjectiles.add(p);
        game.updateMaskRuntime(0.01);
        expect(p.life, 0);
        expect(enemy.dead, i == 5);
      }
    });
    for (final element in [
      'Lava',
      'Poison',
      'Plant',
      'Lightning',
      'Steam',
      'Dust',
      'Fire',
    ]) {
      test(
        '$element field damages nearby enemies and bosses, not distant ones',
        () {
          final game = openArena();
          var p = cast(element).first..position = Offset.zero;
          if (element == 'Fire') {
            game.resolveMaskContact(p, openEnemy(Offset.zero));
            p = game.companionProjectiles.single;
          } else if (element == 'Dust') {
            game.activateMaskPlacements([p]);
            p = game.companionProjectiles.first;
          }
          final near = openEnemy(const Offset(30, 0));
          final far = openEnemy(const Offset(1000, 0));
          game.enemies.addAll([near, far]);
          final boss = CosmicBoss(
            position: const Offset(30, 0),
            name: 'Test',
            element: 'Water',
            level: 1,
            radius: 20,
            maxHealth: 1000,
            speed: 0,
          );
          game.activeBoss = boss;
          game.tickMaskPlacement(p);
          expect(near.health, lessThan(1000));
          expect(far.health, 1000);
          expect(boss.health, lessThan(1000));
          final hp = boss.health;
          boss.position = const Offset(2000, 0);
          game.tickMaskPlacement(p);
          expect(boss.health, hp);
        },
      );
    }
    test('Spirit clear never kills or damages the active boss', () {
      final game = openArena();
      final boss = CosmicBoss(
        position: Offset.zero,
        name: 'Test',
        element: 'Fire',
        level: 1,
        radius: 20,
        maxHealth: 1000,
        speed: 0,
      );
      game.activeBoss = boss;
      for (var i = 0; i < 6; i++) {
        game.companionProjectiles.add(
          cast('Spirit').first..position = Offset.zero,
        );
        game.updateMaskRuntime(0.01);
      }
      expect(boss.health, 1000);
      expect(boss.dead, isFalse);
      game.tickMaskPlacement(cast('Light').single);
      expect(boss.health, 1000);
    });
    test(
      'real Cosmic collision caps Water contact across frames and splashes neighbors',
      () async {
        final game = openArena();
        game.onGameResize(Vector2(900, 700));
        await game.onLoad();
        game.activeCompanions.clear();
        game.enemies.clear();
        final at = game.ship.pos + const Offset(500, 0);
        final p = cast('Water').first..position = at;
        final enemy = openEnemy(at);
        final neighbor = openEnemy(at + const Offset(50, 0));
        game.enemies.addAll([enemy, neighbor]);
        game.companionProjectiles.add(p);
        game.update(1 / 60);
        final after = enemy.health, splashAfter = neighbor.health;
        expect(after, lessThan(1000));
        expect(splashAfter, lessThan(1000));
        for (var i = 0; i < 8; i++) {
          game.update(1 / 60);
        }
        expect(enemy.health, after);
        expect(neighbor.health, splashAfter);
      },
    );
    test(
      'Blood drains after leaving the blob and heals companions at 60fps',
      () {
        final game = openArena();
        final p = cast('Blood').single;
        final enemy = openEnemy(p.position);
        game.enemies.add(enemy);
        game.resolveMaskContact(p, enemy);
        enemy.position = const Offset(1000, 0);
        for (var i = 0; i < 300; i++) {
          game.updateMaskRuntime(1 / 60);
        }
        expect(enemy.health, lessThan(1000));
        expect(game.activeCompanions[0]!.currentHp, greaterThan(50));
      },
    );
  });

  group('Survival Mask runtime', () {
    test(
      'normal Earth cast places healing at injured allies instead of its enemy target',
      () async {
        final game = await survivalArena('Earth');
        final comp = game.activeCompanions[0]!;
        comp.position = Offset.zero;
        comp.specialCooldown = 0;
        game.ship.position = const Offset(-200, 0);
        game.ship.currentHp = game.ship.maxHp * 0.2;
        game.enemies.add(survivalEnemy(const Offset(100, 0)));
        game.update(0.01);
        final pools = game.companionProjectiles
            .where((p) => p.abilityFamily == 'mask' && p.element == 'Earth')
            .toList();
        expect(pools, isNotEmpty);
        expect(
          (pools.first.position - game.ship.position).distance,
          lessThan(5),
        );
      },
    );

    test(
      'Ice Double Cast positions its pillar to cover allies far from the enemy',
      () async {
        final game = await survivalArena('Ice');
        final comp = game.activeCompanions[0]!;
        comp.position = const Offset(100, 0);
        game.ship.position = const Offset(-100, 0);
        comp.doubleCastTargetPos = const Offset(900, 0);
        comp.doubleCastTimer = 0.001;
        game.update(0.002);
        final pillar = game.companionProjectiles.singleWhere(
          (p) => p.abilityFamily == 'mask',
        );
        expect(
          (pillar.position - game.ship.position).distance,
          lessThanOrEqualTo(pillar.effectRadius),
        );
        expect(
          (pillar.position - comp.position).distance,
          lessThanOrEqualTo(pillar.effectRadius),
        );
      },
    );

    for (final element in ['Crystal', 'Fire']) {
      test(
        '$element parent triggers once and offspring cannot chain',
        () async {
          final game = await survivalArena(element);
          final p = cast(element).first;
          final enemy = survivalEnemy(p.position);
          game.enemies.add(enemy);
          game.resolveAbilityHit(p, enemy, killed: false);
          final count = element == 'Crystal' ? 3 : 1;
          expect(game.companionProjectiles.length, count);
          for (var i = 0; i < 60; i++) {
            game.resolveAbilityHit(p, enemy, killed: false);
            for (final child in game.companionProjectiles.toList()) {
              game.resolveAbilityHit(child, enemy, killed: false);
            }
          }
          expect(game.companionProjectiles.length, count);
          expect(enemy.hp, 1000);
        },
      );
    }
    test('Light kills an armored enemy but cannot consume a second', () async {
      final game = await survivalArena('Light');
      final p = cast('Light').single;
      final a = survivalEnemy(p.position, affix: EliteAffix.bulwarked);
      final b = survivalEnemy(p.position);
      game.enemies.addAll([a, b]);
      game.resolveAbilityHit(p, a, killed: false);
      game.resolveAbilityHit(p, b, killed: false);
      expect(a.isDead, isTrue);
      expect(b.isDead, isFalse);
    });
    test('Earth heals by position and Ice buffs without enemies', () async {
      final game = await survivalArena();
      final comp = game.activeCompanions[0]!;
      comp.position = const Offset(1000, 0);
      comp.currentHp = comp.maxHp ~/ 2;
      final before = comp.currentHp;
      game.ship.currentHp = game.ship.maxHp / 2;
      final hp = game.ship.currentHp;
      final earth = cast('Earth').first..position = game.ship.position;
      game.companionProjectiles.add(earth);
      game.updatePersistentAbilityEffects(0.35);
      expect(game.ship.currentHp, greaterThan(hp));
      expect(comp.currentHp, before);
      final ice = cast('Ice').single..position = comp.position;
      game.companionProjectiles.add(ice);
      game.updatePersistentAbilityEffects(0.35);
      expect(comp.damageAmp, 2.4);
      expect(game.maskShipDamageAmp, 1);
      ice.position = game.ship.position;
      expect(game.maskShipDamageAmp, 2.4);
    });
    test(
      'Lightning damages a lone enemy in the field on repeated ticks',
      () async {
        final game = await survivalArena('Lightning');
        final p = cast('Lightning').single..position = const Offset(250, 0);
        final enemy = survivalEnemy(p.position + const Offset(80, 0));
        game.enemies.add(enemy);
        game.update(0); // Rebuild the real collision grid.
        game.companionProjectiles.add(p);
        final radius = p.effectRadius;
        game.updatePersistentAbilityEffects(0.35);
        expect(enemy.hp, lessThan(1000));
        expect(p.effectRadius, radius + 14);
        final after = enemy.hp;
        game.updatePersistentAbilityEffects(0.35);
        expect(enemy.hp, lessThan(after));
        expect(p.effectRadius, radius + 14);
      },
    );
    for (final element in [
      'Lava',
      'Poison',
      'Plant',
      'Lightning',
      'Steam',
      'Fire',
    ]) {
      test(
        '$element field damages a boss in range and stops outside',
        () async {
          final game = await survivalArena(element);
          var p = cast(element).first..position = const Offset(250, 0);
          if (element == 'Fire') {
            game.resolveAbilityHit(p, survivalEnemy(p.position), killed: false);
            p = game.companionProjectiles.single;
          } else {
            game.companionProjectiles.add(p);
          }
          final boss = game.spawner.createBossForWave(5, p.position)!;
          boss.shieldUp = false;
          game.activeBoss = boss;
          final before = boss.hp;
          game.updatePersistentAbilityEffects(0.35);
          expect(boss.hp, lessThan(before));
          expect(boss.isDead, isFalse);
          final after = boss.hp;
          boss.position = const Offset(2000, 0);
          game.updatePersistentAbilityEffects(0.35);
          expect(boss.hp, after);
        },
      );
    }
    test(
      'real Water collision applies contact damage once across frames',
      () async {
        final game = await survivalArena('Water');
        final p = cast('Water').first..position = const Offset(300, 0);
        final enemy = survivalEnemy(p.position);
        game.enemies.add(enemy);
        game.companionProjectiles.add(p);
        game.update(1 / 60);
        final after = enemy.hp;
        expect(after, lessThan(1000));
        for (var i = 0; i < 8; i++) {
          game.update(1 / 60);
        }
        expect(enemy.hp, after);
      },
    );
    for (final element in ['Plant', 'Dust']) {
      test(
        '$element Double Cast uses the same persistent placement lifecycle',
        () async {
          final game = await survivalArena(element);
          final comp = game.activeCompanions[0]!;
          void echo() {
            comp.doubleCastTargetPos = const Offset(100, 0);
            comp.doubleCastTimer = 0.01;
            game.update(0.02);
          }

          echo();
          final fixtures = game.companionProjectiles
              .where((p) => p.abilityFamily == 'mask')
              .toList();
          expect(fixtures.length, element == 'Plant' ? 1 : 2);
          final initialPower = fixtures.first.effectPower;
          for (var i = 0; i < 5; i++) {
            echo();
          }
          final after = game.companionProjectiles
              .where((p) => p.abilityFamily == 'mask')
              .toList();
          expect(after.length, fixtures.length);
          if (element == 'Plant') {
            expect(after.single.effectPower, greaterThan(initialPower));
            expect(after.single.effectStacks, 6);
          } else {
            expect(
              after.every(
                (p) => p.interceptCharges > 0 && p.attachedToSlot != -2,
              ),
              isTrue,
            );
          }
        },
      );
    }
    test(
      'Spirit echo creates pickups and sixth collection kills armored enemies, not bosses',
      () async {
        final game = await survivalArena('Spirit');
        final comp = game.activeCompanions[0]!;
        comp.doubleCastTargetPos = const Offset(250, 0);
        comp.doubleCastTimer = 0.01;
        game.update(0.02);
        expect(game.debugMaskSpiritWispPositions, isNotEmpty);
        expect(
          game.companionProjectiles.where(
            (p) => p.element == 'Spirit' && p.stationary,
          ),
          isEmpty,
        );
        final enemy = survivalEnemy(
          const Offset(400, 0),
          affix: EliteAffix.bulwarked,
        );
        game.enemies.add(enemy);
        final boss = game.spawner.createBossForWave(5, const Offset(-400, 0))!;
        game.activeBoss = boss;
        final hp = boss.hp;
        comp.maskSpiritWispBank = 5;
        game.ship.position = game.debugMaskSpiritWispPositions.first;
        game.update(0.001);
        expect(enemy.isDead, isTrue);
        expect(boss.isDead, isFalse);
        expect(boss.hp, hp);
      },
    );
    test('Air pushes enemies and Mud slows enemies within the pool', () async {
      final game = await survivalArena('Air');
      final air = cast('Air').first..position = const Offset(250, 0);
      final enemy = survivalEnemy(const Offset(255, 0));
      game.enemies.add(enemy);
      game.update(0);
      game.resolveAbilityHit(air, enemy, killed: false);
      expect(enemy.knockbackVelocity.distance, greaterThan(0));
      final mud = cast('Mud').first..position = enemy.position;
      game.companionProjectiles.add(mud);
      game.updatePersistentAbilityEffects(0.35);
      expect(enemy.slowTimer, greaterThan(0));
      expect(enemy.slowMultiplier, lessThan(1));
    });
    test(
      'Blood heals integer companion HP through many tiny drain ticks',
      () async {
        final game = await survivalArena('Blood');
        final comp = game.activeCompanions[0]!;
        comp.currentHp = comp.maxHp ~/ 2;
        final before = comp.currentHp;
        final enemy = survivalEnemy(const Offset(300, 0), hp: 50)
          ..maskBloodDrainSlot = 0;
        game.enemies.add(enemy);
        for (var i = 0; i < 180; i++) {
          game.update(1 / 60);
        }
        expect(enemy.hp, lessThan(50));
        expect(comp.currentHp, greaterThan(before));
      },
    );
  });
}
