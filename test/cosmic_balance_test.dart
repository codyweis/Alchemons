import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _testMember({required String family}) {
  return CosmicPartyMember(
    instanceId: 'test-$family',
    baseId: 'base-$family',
    displayName: 'Test $family',
    element: 'Light',
    family: family,
    level: 5,
    statSpeed: 3.0,
    statIntelligence: 3.0,
    statStrength: 3.0,
    statBeauty: 3.0,
    slotIndex: 0,
    staminaBars: 5,
    staminaMax: 5,
  );
}

void main() {
  group('Cosmic balance', () {
    test('companion combat still respects real level', () {
      final lowLevelAtk = CosmicBalance.companionPhysAtk(
        level: 1,
        strength: 2.5,
      );
      final maxLevelAtk = CosmicBalance.companionPhysAtk(
        level: 5,
        strength: 2.5,
      );
      final lowLevelHp = CosmicBalance.companionMaxHp(
        level: 1,
        strength: 2.5,
        intelligence: 2.5,
      );
      final maxLevelHp = CosmicBalance.companionMaxHp(
        level: 5,
        strength: 2.5,
        intelligence: 2.5,
      );

      expect(maxLevelAtk, greaterThan(lowLevelAtk));
      expect(maxLevelHp, greaterThan(lowLevelHp));
    });

    test('space combat is balanced around level 10 stat quality', () {
      final averageAtk = CosmicBalance.companionPhysAtk(
        level: 10,
        strength: 2.5,
      );
      final exceptionalAtk = CosmicBalance.companionPhysAtk(
        level: 10,
        strength: 4.5,
      );
      final averageHp = CosmicBalance.companionMaxHp(
        level: 10,
        strength: 2.5,
        intelligence: 2.5,
      );
      final exceptionalHp = CosmicBalance.companionMaxHp(
        level: 10,
        strength: 4.5,
        intelligence: 4.5,
      );

      expect(exceptionalAtk - averageAtk, greaterThanOrEqualTo(5));
      expect(exceptionalHp, greaterThan(averageHp * 1.5));
    });

    test('stat quality is worth more than late-level progression', () {
      final weakMaxLevelAtk = CosmicBalance.companionPhysAtk(
        level: 5,
        strength: 2.0,
      );
      final strongMidLevelAtk = CosmicBalance.companionPhysAtk(
        level: 3,
        strength: 4.0,
      );
      final weakMaxLevelHp = CosmicBalance.companionMaxHp(
        level: 5,
        strength: 2.0,
        intelligence: 2.0,
      );
      final strongMidLevelHp = CosmicBalance.companionMaxHp(
        level: 3,
        strength: 4.0,
        intelligence: 4.0,
      );

      expect(strongMidLevelAtk, greaterThan(weakMaxLevelAtk));
      expect(strongMidLevelHp, greaterThan(weakMaxLevelHp));
    });

    test('arena stat rolls stay inside the 1.0 to 5.0 combat band', () {
      final rng = Random(42);
      for (var level = 1; level <= CosmicBalance.maxCombatLevel; level++) {
        for (var i = 0; i < 50; i++) {
          final roll = CosmicBalance.rollArenaStat(level, rng);
          expect(roll, inInclusiveRange(1.0, 5.0));
          expect(roll, greaterThanOrEqualTo(CosmicBalance.arenaMinStat(level)));
          expect(roll, lessThanOrEqualTo(CosmicBalance.arenaMaxStat(level)));
        }
      }
    });

    test('arena rolls treat 2-3 as average and 4-5 as exceptional', () {
      expect(CosmicBalance.arenaMinStat(1), closeTo(2.0, 0.001));
      expect(CosmicBalance.arenaMaxStat(3), inInclusiveRange(3.5, 3.9));
      expect(CosmicBalance.arenaMinStat(5), closeTo(4.0, 0.001));
      expect(CosmicBalance.arenaMaxStat(5), closeTo(5.0, 0.001));
    });

    test('ship upgrades stay meaningful but bounded', () {
      expect(CosmicBalance.shipDamageMultiplier(0), closeTo(1.0, 0.0001));
      expect(CosmicBalance.shipDamageMultiplier(5), closeTo(1.6, 0.0001));
    });

    test('boss scaling stays within the level 5 combat ceiling', () {
      expect(CosmicBalance.clampLevel(20), CosmicBalance.maxCombatLevel);
      expect(
        CosmicBalance.bossHealthScale(5),
        greaterThan(CosmicBalance.bossHealthScale(1)),
      );
      expect(
        CosmicBalance.bossCollisionDamage(level: 5, type: BossType.warden),
        greaterThan(
          CosmicBalance.bossCollisionDamage(level: 2, type: BossType.gunner),
        ),
      );
    });

    test('let specials read as meteor artillery', () {
      final result = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'let',
        element: 'Fire',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(120, 0),
      );

      final meteor = result.projectiles.firstWhere(
        (p) => p.visualStyle == ProjectileVisualStyle.meteor,
      );
      expect(meteor.radiusMultiplier, greaterThanOrEqualTo(3.0));
      expect(meteor.trailInterval, greaterThan(0));
      expect(meteor.clusterCount, greaterThan(0));
    });

    test('let light and dark payloads diverge into distinct bombardments', () {
      final light = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'let',
        element: 'Light',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(120, 0),
      );
      final dark = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'let',
        element: 'Dark',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(120, 0),
      );

      expect(light.projectiles.any((p) => p.orbitCenter != null), isTrue);
      expect(dark.projectiles.any((p) => p.stationary), isTrue);
      expect(
        dark.projectiles.where((p) => p.stationary).length,
        greaterThanOrEqualTo(3),
      );
    });

    test(
      'water ice mud poison and lightning lets now use authored impact patterns',
      () {
        final water = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'let',
          element: 'Water',
          damage: 10,
          maxHp: 120,
          targetPos: const Offset(120, 0),
        );
        final ice = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'let',
          element: 'Ice',
          damage: 10,
          maxHp: 120,
          targetPos: const Offset(120, 0),
        );
        final mud = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'let',
          element: 'Mud',
          damage: 10,
          maxHp: 120,
          targetPos: const Offset(120, 0),
        );
        final poison = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'let',
          element: 'Poison',
          damage: 10,
          maxHp: 120,
          targetPos: const Offset(120, 0),
        );
        final lightning = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'let',
          element: 'Lightning',
          damage: 10,
          maxHp: 120,
          targetPos: const Offset(120, 0),
        );

        expect(
          water.projectiles.where((p) => p.homing).length,
          greaterThanOrEqualTo(10),
        );
        expect(
          ice.projectiles.where((p) => p.speedMultiplier <= 0.25).length,
          4,
        );
        expect(mud.projectiles.where((p) => p.stationary).length, 5);
        expect(poison.projectiles.where((p) => p.stationary).length, 3);
        expect(
          lightning.projectiles.where((p) => p.bounceCount > 0).length,
          greaterThanOrEqualTo(3),
        );
      },
    );

    test(
      'water ice steam mud and poison wings now use authored beam aftermaths',
      () {
        final water = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'wing',
          element: 'Water',
          damage: 10,
          maxHp: 120,
        );
        final ice = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'wing',
          element: 'Ice',
          damage: 10,
          maxHp: 120,
        );
        final steam = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'wing',
          element: 'Steam',
          damage: 10,
          maxHp: 120,
        );
        final mud = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'wing',
          element: 'Mud',
          damage: 10,
          maxHp: 120,
        );
        final poison = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'wing',
          element: 'Poison',
          damage: 10,
          maxHp: 120,
        );

        expect(water.projectiles.where((p) => p.homing).length, 8);
        expect(
          ice.projectiles
              .where(
                (p) =>
                    p.piercing &&
                    p.speedMultiplier <= 0.3 &&
                    p.radiusMultiplier >= 2.1,
              )
              .length,
          3,
        );
        expect(
          steam.projectiles.where((p) => p.stationary && p.piercing).length,
          6,
        );
        expect(mud.projectiles.where((p) => p.stationary).length, 3);
        expect(
          mud.projectiles
              .where((p) => !p.stationary && p.speedMultiplier <= 0.38)
              .length,
          4,
        );
        expect(poison.projectiles.where((p) => p.stationary).length, 3);
        expect(
          poison.projectiles
              .where((p) => !p.stationary && p.speedMultiplier <= 0.55)
              .length,
          5,
        );
      },
    );

    test('wing output budgets stay bounded after the creativity pass', () {
      final dark = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'wing',
        element: 'Dark',
        damage: 10,
        maxHp: 120,
      );
      final poison = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'wing',
        element: 'Poison',
        damage: 10,
        maxHp: 120,
      );
      final lava = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'wing',
        element: 'Lava',
        damage: 10,
        maxHp: 120,
      );
      final ice = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'wing',
        element: 'Ice',
        damage: 10,
        maxHp: 120,
      );

      expect(dark.projectiles.where((p) => p.stationary).length, 6);
      expect(poison.projectiles.first.trailDamage, lessThanOrEqualTo(4.5));
      expect(lava.projectiles.first.trailDamage, lessThanOrEqualTo(5.5));
      expect(
        ice.projectiles
            .where((p) => p.piercing && p.speedMultiplier <= 0.3)
            .every((p) => p.damage <= 13.5),
        isTrue,
      );
    });

    test(
      'water ice steam air dust and light horns use forward impact geometry',
      () {
        final water = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'horn',
          element: 'Water',
          damage: 10,
          maxHp: 120,
        );
        final ice = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'horn',
          element: 'Ice',
          damage: 10,
          maxHp: 120,
        );
        final steam = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'horn',
          element: 'Steam',
          damage: 10,
          maxHp: 120,
        );
        final air = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'horn',
          element: 'Air',
          damage: 10,
          maxHp: 120,
        );
        final dust = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'horn',
          element: 'Dust',
          damage: 10,
          maxHp: 120,
        );
        final light = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'horn',
          element: 'Light',
          damage: 10,
          maxHp: 120,
        );

        expect(water.projectiles.length, 6);
        expect(water.projectiles.every((p) => p.position.dx > 0), isTrue);
        expect(water.projectiles.any((p) => p.position.dy > 0), isTrue);
        expect(water.projectiles.any((p) => p.position.dy < 0), isTrue);
        expect(ice.projectiles.length, 5);
        expect(ice.projectiles.every((p) => p.piercing), isTrue);
        expect(steam.projectiles.length, 6);
        expect(steam.projectiles.every((p) => p.piercing), isTrue);
        expect(air.projectiles.length, 6);
        expect(air.projectiles.every((p) => p.position.dx > 0), isTrue);
        expect(dust.projectiles.length, 14);
        expect(light.projectiles.length, 6);
        expect(light.projectiles.every((p) => p.homing), isTrue);
      },
    );

    test('horn output budgets stay bounded after the authored pass', () {
      final earth = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'horn',
        element: 'Earth',
        damage: 10,
        maxHp: 120,
      );
      final dark = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'horn',
        element: 'Dark',
        damage: 10,
        maxHp: 120,
      );
      final lava = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'horn',
        element: 'Lava',
        damage: 10,
        maxHp: 120,
      );
      final blood = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'horn',
        element: 'Blood',
        damage: 10,
        maxHp: 120,
      );

      expect(earth.chargeDamage, lessThanOrEqualTo(36));
      expect(earth.shieldHp, lessThanOrEqualTo((120 * 0.75).round()));
      expect(dark.chargeDamage, lessThanOrEqualTo(31));
      expect(lava.chargeDamage, lessThanOrEqualTo(30));
      expect(blood.chargeDamage, lessThanOrEqualTo(28));
      expect(blood.selfHeal, greaterThan(0));
    });

    test('pip specials are fast homing ricochet pressure', () {
      final result = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'pip',
        element: 'Lightning',
        damage: 10,
        maxHp: 100,
      );

      expect(result.projectiles, isNotEmpty);
      expect(result.projectiles.every((p) => p.homing), isTrue);
      expect(result.projectiles.any((p) => p.bounceCount > 0), isTrue);
      expect(
        result.projectiles.every(
          (p) => p.visualStyle == ProjectileVisualStyle.dart,
        ),
        isTrue,
      );
    });

    test(
      'water steam earth poison and light pips use distinct dart patterns',
      () {
        final water = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'pip',
          element: 'Water',
          damage: 10,
          maxHp: 120,
        );
        final steam = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'pip',
          element: 'Steam',
          damage: 10,
          maxHp: 120,
        );
        final earth = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'pip',
          element: 'Earth',
          damage: 10,
          maxHp: 120,
        );
        final poison = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'pip',
          element: 'Poison',
          damage: 10,
          maxHp: 120,
        );
        final light = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'pip',
          element: 'Light',
          damage: 10,
          maxHp: 120,
        );

        expect(water.projectiles.length, 6);
        expect(water.projectiles.every((p) => p.bounceCount == 2), isTrue);
        expect(steam.projectiles.length, 6);
        expect(steam.projectiles.any((p) => p.position.dy > 0), isTrue);
        expect(steam.projectiles.any((p) => p.position.dy < 0), isTrue);
        expect(earth.projectiles.length, 4);
        expect(earth.projectiles.every((p) => p.visualScale > 1.0), isTrue);
        expect(
          poison.projectiles.every((p) => p.homingStrength >= 4.8),
          isTrue,
        );
        expect(light.projectiles.length, 6);
        expect(light.projectiles.every((p) => p.bounceCount == 2), isTrue);
      },
    );

    test('mane specials stay as forward barrages instead of full rings', () {
      const baseAngle = 1.0;
      final result = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: baseAngle,
        family: 'mane',
        element: 'Fire',
        damage: 10,
        maxHp: 100,
      );

      expect(result.projectiles.length, lessThanOrEqualTo(9));
      for (final projectile in result.projectiles) {
        expect((projectile.angle - baseAngle).abs(), lessThan(pi / 2 + 0.05));
        expect(projectile.visualStyle, ProjectileVisualStyle.slash);
      }
    });

    test(
      'water steam plant poison air and light manes use distinct barrage lanes',
      () {
        final water = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'mane',
          element: 'Water',
          damage: 10,
          maxHp: 120,
        );
        final steam = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'mane',
          element: 'Steam',
          damage: 10,
          maxHp: 120,
        );
        final plant = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'mane',
          element: 'Plant',
          damage: 10,
          maxHp: 120,
        );
        final poison = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'mane',
          element: 'Poison',
          damage: 10,
          maxHp: 120,
        );
        final air = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'mane',
          element: 'Air',
          damage: 10,
          maxHp: 120,
        );
        final light = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'mane',
          element: 'Light',
          damage: 10,
          maxHp: 120,
        );

        expect(water.projectiles.length, 6);
        expect(water.projectiles.any((p) => p.position.dy > 0), isTrue);
        expect(water.projectiles.any((p) => p.position.dy < 0), isTrue);
        expect(steam.projectiles.length, 6);
        expect(steam.projectiles.every((p) => p.life >= 2.6), isTrue);
        expect(plant.projectiles.length, 6);
        expect(plant.projectiles.any((p) => p.position.dy > 0), isTrue);
        expect(plant.projectiles.any((p) => p.position.dy < 0), isTrue);
        expect(poison.projectiles.length, 5);
        expect(
          poison.projectiles.map((p) => p.position.dy).toSet().length,
          greaterThanOrEqualTo(5),
        );
        expect(air.projectiles.length, 7);
        expect(light.projectiles.length, 6);
        expect(light.projectiles.every((p) => p.piercing), isTrue);
      },
    );

    test('mane output budgets stay bounded after the authored pass', () {
      final earth = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mane',
        element: 'Earth',
        damage: 10,
        maxHp: 120,
      );
      final dark = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mane',
        element: 'Dark',
        damage: 10,
        maxHp: 120,
      );
      final blood = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mane',
        element: 'Blood',
        damage: 10,
        maxHp: 120,
      );

      expect(earth.projectiles.every((p) => p.damage <= 24), isTrue);
      expect(dark.projectiles.every((p) => p.damage <= 22), isTrue);
      expect(blood.projectiles.every((p) => p.damage <= 22), isTrue);
    });

    test('mask specials keep battlefield-control traps in the payload', () {
      final result = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mask',
        element: 'Earth',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(90, 0),
      );

      expect(
        result.projectiles.any(
          (p) => p.stationary && p.decoy && p.tauntRadius > 0,
        ),
        isTrue,
      );
      expect(
        result.projectiles.any((p) => !p.stationary && (p.decoy || p.homing)),
        isTrue,
      );
    });

    test('kin specials keep the cycling guardian-orb feel', () {
      final result = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'kin',
        element: 'Light',
        damage: 10,
        maxHp: 120,
        casterPower: 3.0,
      );

      expect(result.projectiles, isNotEmpty);
      expect(
        result.projectiles.every(
          (p) =>
              p.visualStyle == ProjectileVisualStyle.kinOrbital &&
              p.orbitCenter != null &&
              p.orbitTime > 0,
        ),
        isTrue,
      );
    });

    test('light kin and dark kin now express different guardian roles', () {
      final light = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'kin',
        element: 'Light',
        damage: 10,
        maxHp: 120,
        casterPower: 5.0,
      );
      final dark = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'kin',
        element: 'Dark',
        damage: 10,
        maxHp: 120,
        casterPower: 5.0,
      );

      expect(light.selfHeal, greaterThan(dark.selfHeal));
      expect(light.blessingTimer, greaterThan(dark.blessingTimer));
      expect(
        light.projectiles
            .where(
              (p) =>
                  p.transferToShipOrbit &&
                  p.holdOrbit &&
                  p.interceptCharges > 0 &&
                  p.shipOrbitDelay > 0 &&
                  p.orbitRadius >= 80 &&
                  !p.homing,
            )
            .length,
        5,
      );
      expect(light.projectiles.every((p) => p.shipOrbitDelay >= 1.7), isTrue);
      expect(light.projectiles.every((p) => p.life >= 11.0), isTrue);
      expect(
        dark.projectiles
            .where(
              (p) =>
                  p.piercing &&
                  p.turretInterval > 0 &&
                  p.transferOrbitCenter != null,
            )
            .length,
        greaterThanOrEqualTo(2),
      );

      final lightAverageRadius =
          light.projectiles.map((p) => p.orbitRadius).reduce((a, b) => a + b) /
          light.projectiles.length;
      final darkAverageRadius =
          dark.projectiles.map((p) => p.orbitRadius).reduce((a, b) => a + b) /
          dark.projectiles.length;
      expect(lightAverageRadius, greaterThan(darkAverageRadius));
    });

    test('crystal kin can deploy escort sentry turrets around the ship', () {
      final crystal = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'kin',
        element: 'Crystal',
        damage: 10,
        maxHp: 120,
        casterPower: 3.0,
      );

      expect(
        crystal.projectiles.where(
          (p) =>
              p.transferToShipOrbit &&
              p.holdOrbit &&
              p.shipOrbitDelay > 0 &&
              p.turretInterval > 0 &&
              p.turretDamage > 0,
        ),
        isNotEmpty,
      );
      expect(crystal.projectiles.length, 3);
    });

    test('air kin can transfer into enemy wind snares', () {
      const target = Offset(140, 20);
      final air = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'kin',
        element: 'Air',
        damage: 10,
        maxHp: 120,
        casterPower: 3.0,
        targetPos: target,
      );

      expect(air.projectiles.length, 3);
      expect(
        air.projectiles.every(
          (p) =>
              p.transferOrbitCenter == target &&
              p.holdOrbit &&
              p.decoy &&
              p.snareRadius > 0 &&
              p.tauntRadius > 0 &&
              p.shipOrbitDelay > 0,
        ),
        isTrue,
      );
    });

    test('kin elements now produce distinct guardian payload signatures', () {
      const elements = [
        'Fire',
        'Lava',
        'Lightning',
        'Water',
        'Ice',
        'Steam',
        'Earth',
        'Mud',
        'Dust',
        'Crystal',
        'Air',
        'Plant',
        'Poison',
        'Spirit',
        'Dark',
        'Light',
        'Blood',
      ];

      final signatures = <String>{};
      for (final element in elements) {
        final result = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'kin',
          element: element,
          damage: 10,
          maxHp: 120,
          casterPower: 4.0,
          targetPos: const Offset(120, 0),
        );
        final intercepts = result.projectiles.fold<int>(
          0,
          (sum, p) => sum + p.interceptCharges,
        );
        final turrets = result.projectiles.where((p) => p.turretInterval > 0);
        final decoys = result.projectiles.where((p) => p.decoy).length;
        final snares = result.projectiles
            .where((p) => p.snareRadius > 0)
            .length;
        final transfers = result.projectiles
            .where(
              (p) => p.transferToShipOrbit || p.transferOrbitCenter != null,
            )
            .length;
        final piercing = result.projectiles.where((p) => p.piercing).length;
        final homing = result.projectiles.where((p) => p.homing).length;
        final orbitSum = result.projectiles
            .map((p) => p.orbitRadius.round())
            .fold<int>(0, (sum, r) => sum + r);
        final turretKey = turrets
            .map(
              (p) =>
                  '${(p.turretInterval * 100).round()}:${(p.turretDamage * 100).round()}:${(p.turretSpeedMultiplier * 100).round()}',
            )
            .join('|');

        signatures.add(
          [
            result.projectiles.length,
            intercepts,
            decoys,
            snares,
            transfers,
            piercing,
            homing,
            orbitSum,
            result.selfHeal,
            (result.blessingTimer * 10).round(),
            turretKey,
          ].join('/'),
        );
      }

      expect(signatures.length, elements.length);
    });

    test(
      'fire kin no longer carries the highest sustained kin output budget',
      () {
        final fire = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'kin',
          element: 'Fire',
          damage: 10,
          maxHp: 120,
          casterPower: 4.0,
          targetPos: const Offset(120, 0),
        );

        expect(fire.projectiles.length, 4);
        expect(fire.projectiles.every((p) => p.turretInterval >= 0.78), isTrue);
        expect(
          fire.projectiles.every((p) => p.turretDamage <= 10 * 0.34 + 0.001),
          isTrue,
        );
        expect(fire.projectiles.every((p) => p.life <= 8.2), isTrue);
      },
    );

    test('mystic elements diverge into premium guardian ultimates', () {
      final fire = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mystic',
        element: 'Fire',
        damage: 10,
        maxHp: 120,
      );
      final crystal = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mystic',
        element: 'Crystal',
        damage: 10,
        maxHp: 120,
      );

      expect(
        fire.projectiles.every(
          (p) => p.visualStyle == ProjectileVisualStyle.mysticOrbital,
        ),
        isTrue,
      );
      expect(
        crystal.projectiles.every(
          (p) => p.visualStyle == ProjectileVisualStyle.mysticOrbital,
        ),
        isTrue,
      );
      expect(fire.projectiles.first.trailInterval, greaterThan(0));
      expect(crystal.projectiles.first.clusterCount, greaterThan(0));
      expect(crystal.projectiles.first.bounceCount, greaterThan(0));
      expect(
        fire.projectiles.map((p) => p.orbitRadius).toSet(),
        isNot(crystal.projectiles.map((p) => p.orbitRadius).toSet()),
      );
      expect(
        fire.projectiles.map((p) => p.damage).reduce(max),
        isNot(crystal.projectiles.map((p) => p.damage).reduce(max)),
      );
    });

    test('mystic elements now produce unique ultimate payload signatures', () {
      const elements = [
        'Fire',
        'Lava',
        'Lightning',
        'Water',
        'Ice',
        'Steam',
        'Earth',
        'Mud',
        'Dust',
        'Crystal',
        'Air',
        'Plant',
        'Poison',
        'Spirit',
        'Dark',
        'Light',
        'Blood',
      ];

      final signatures = <String>{};
      for (final element in elements) {
        final result = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'mystic',
          element: element,
          damage: 10,
          maxHp: 120,
        );
        final signatureParts =
            result.projectiles
                .map(
                  (p) => [
                    p.orbitRadius.round(),
                    (p.damage * 10).round(),
                    (p.orbitTime * 100).round(),
                    (p.orbitSpeed * 10).round(),
                    (p.speedMultiplier * 100).round(),
                    (p.homingStrength * 10).round(),
                    (p.visualScale * 100).round(),
                    p.bounceCount,
                    p.clusterCount,
                    p.piercing ? 1 : 0,
                    (p.trailInterval * 100).round(),
                  ].join(':'),
                )
                .toList()
              ..sort();
        signatures.add(
          '${result.projectiles.length}|${signatureParts.join("|")}',
        );
      }

      expect(signatures.length, elements.length);
    });

    test('mystic specials stay on the long-cooldown end of family balance', () {
      final mystic = CosmicCompanion(
        member: _testMember(family: 'mystic'),
        position: const Offset(0, 0),
        maxHp: 100,
        currentHp: 100,
        physAtk: 5,
        elemAtk: 5,
        physDef: 5,
        elemDef: 5,
        cooldownReduction: 1.0,
        critChance: 0.1,
        attackRange: 180,
        specialAbilityRange: 220,
      );
      final wing = CosmicCompanion(
        member: _testMember(family: 'wing'),
        position: const Offset(0, 0),
        maxHp: 100,
        currentHp: 100,
        physAtk: 5,
        elemAtk: 5,
        physDef: 5,
        elemDef: 5,
        cooldownReduction: 1.0,
        critChance: 0.1,
        attackRange: 180,
        specialAbilityRange: 220,
      );

      expect(
        mystic.effectiveSpecialCooldown,
        greaterThan(wing.effectiveSpecialCooldown),
      );
    });

    test('companions get a brief grace window after taking damage', () {
      final member = _testMember(family: 'horn');
      final companion = CosmicCompanion(
        member: member,
        position: const Offset(0, 0),
        maxHp: 100,
        currentHp: 100,
        physAtk: 5,
        elemAtk: 5,
        physDef: 5,
        elemDef: 5,
        cooldownReduction: 1.0,
        critChance: 0.1,
        attackRange: 120,
        specialAbilityRange: 160,
      )..invincibleTimer = 0;

      companion.takeDamage(20);
      final hpAfterFirstHit = companion.currentHp;
      companion.takeDamage(20);

      expect(hpAfterFirstHit, 80);
      expect(companion.currentHp, hpAfterFirstHit);
      expect(companion.invincibleTimer, greaterThan(0));
    });
  });
}
