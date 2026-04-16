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

CosmicCompanion _testCompanion({required String family}) {
  return CosmicCompanion(
    member: _testMember(family: family),
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
      expect(CosmicBalance.shipDamageMultiplier(5), closeTo(1.4, 0.0001));
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
      expect(meteor.trailInterval, 0);
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

    test('let elements produce distinct siege footprints', () {
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
          family: 'let',
          element: element,
          damage: 10,
          maxHp: 100,
          targetPos: const Offset(120, 0),
        );
        final stationaries = result.projectiles.where((p) => p.stationary);
        final snares = result.projectiles.where((p) => p.snareRadius > 0);
        final trailProjectiles = result.projectiles.where(
          (p) => p.trailInterval > 0,
        );
        final orbits = result.projectiles.where((p) => p.orbitTime > 0);
        final totalClusters = result.projectiles.fold<int>(
          0,
          (sum, p) => sum + p.clusterCount,
        );
        final totalBounces = result.projectiles.fold<int>(
          0,
          (sum, p) => sum + p.bounceCount,
        );
        final totalIntercepts = result.projectiles.fold<int>(
          0,
          (sum, p) => sum + p.interceptCharges,
        );
        final maxRadius = result.projectiles
            .map((p) => p.radiusMultiplier)
            .reduce(max);
        final maxLife = result.projectiles.map((p) => p.life).reduce(max);
        final maxSnare = snares.isEmpty
            ? 0.0
            : snares.map((p) => p.snareRadius).reduce(max);

        signatures.add(
          [
            result.projectiles.length,
            stationaries.length,
            result.projectiles.where((p) => p.homing).length,
            orbits.length,
            trailProjectiles.length,
            totalClusters,
            totalBounces,
            totalIntercepts,
            maxRadius.round(),
            (maxLife * 10).round(),
            maxSnare.round(),
            result.selfHeal,
            result.shipHeal,
            (result.blessingTimer * 10).round(),
          ].join('/'),
        );
      }

      expect(signatures.length, elements.length);
      expect(
        elements.every((element) {
          final result = createCosmicSpecialAbility(
            origin: const Offset(0, 0),
            baseAngle: 0,
            family: 'let',
            element: element,
            damage: 10,
            maxHp: 100,
            targetPos: const Offset(120, 0),
          );
          return result.projectiles.every((p) => p.trailInterval == 0);
        }),
        isTrue,
      );
    });

    test('let control zones get larger and last longer from stats', () {
      final low = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'let',
        element: 'Poison',
        damage: 10,
        maxHp: 100,
        casterBeauty: 1,
        casterIntelligence: 1,
        targetPos: const Offset(120, 0),
      );
      final high = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'let',
        element: 'Poison',
        damage: 10,
        maxHp: 100,
        casterBeauty: 5,
        casterIntelligence: 5,
        targetPos: const Offset(120, 0),
      );

      final lowFallout = low.projectiles.where((p) => p.stationary).toList();
      final highFallout = high.projectiles.where((p) => p.stationary).toList();
      final lowMaxRadius = lowFallout
          .map((p) => p.radiusMultiplier)
          .reduce(max);
      final highMaxRadius = highFallout
          .map((p) => p.radiusMultiplier)
          .reduce(max);
      final lowMaxLife = lowFallout.map((p) => p.life).reduce(max);
      final highMaxLife = highFallout.map((p) => p.life).reduce(max);
      final lowMaxSnare = lowFallout.map((p) => p.snareRadius).reduce(max);
      final highMaxSnare = highFallout.map((p) => p.snareRadius).reduce(max);

      expect(highFallout.length, greaterThanOrEqualTo(lowFallout.length));
      expect(highMaxRadius, greaterThan(lowMaxRadius));
      expect(highMaxLife, greaterThan(lowMaxLife));
      expect(highMaxSnare, greaterThan(lowMaxSnare));
    });

    test('let control fields persist at mid stats', () {
      const fieldMinimums = {
        'Earth': 4.5,
        'Steam': 4.4,
        'Mud': 4.8,
        'Poison': 5.0,
        'Dark': 5.0,
      };

      for (final entry in fieldMinimums.entries) {
        final result = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'let',
          element: entry.key,
          damage: 10,
          maxHp: 100,
          casterBeauty: 3.5,
          casterIntelligence: 3.5,
          targetPos: const Offset(120, 0),
        );
        final fields = result.projectiles
            .where((p) => p.stationary && p.snareRadius > 0)
            .toList();

        expect(fields, isNotEmpty);
        expect(fields.map((p) => p.life).reduce(max), greaterThan(entry.value));
        expect(fields.map((p) => p.snareRadius).reduce(max), greaterThan(100));
      }
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

    test('pip basic payload is discounted for faster cadence', () {
      final pip = createFamilyBasicAttack(
        origin: const Offset(0, 0),
        angle: 0,
        element: 'Lightning',
        family: 'pip',
        damage: 10,
      );
      final mane = createFamilyBasicAttack(
        origin: const Offset(0, 0),
        angle: 0,
        element: 'Lightning',
        family: 'mane',
        damage: 10,
      );
      final horn = createFamilyBasicAttack(
        origin: const Offset(0, 0),
        angle: 0,
        element: 'Lightning',
        family: 'horn',
        damage: 10,
      );

      final pipPayload = pip.fold<double>(0, (sum, p) => sum + p.damage);
      final manePayload = mane.fold<double>(0, (sum, p) => sum + p.damage);
      final hornPayload = horn.fold<double>(0, (sum, p) => sum + p.damage);
      final pipCompanion = _testCompanion(family: 'pip');
      final letCompanion = _testCompanion(family: 'let');
      final let = createFamilyBasicAttack(
        origin: const Offset(0, 0),
        angle: 0,
        element: 'Lightning',
        family: 'let',
        damage: 10,
      );
      final letPayload = let.fold<double>(0, (sum, p) => sum + p.damage);

      expect(pip.length, greaterThan(mane.length));
      expect(pipPayload, lessThan(manePayload));
      expect(pipPayload, lessThan(hornPayload));
      expect(
        pipPayload / pipCompanion.effectiveBasicCooldown,
        lessThan(letPayload / letCompanion.effectiveBasicCooldown),
      );
    });

    test('pip cooldown edge over let stays controlled', () {
      final pip = _testCompanion(family: 'pip');
      final let = _testCompanion(family: 'let');

      expect(
        pip.effectiveBasicCooldown,
        greaterThan(let.effectiveBasicCooldown * 0.78),
      );
      expect(
        pip.effectiveSpecialCooldown,
        greaterThan(let.effectiveSpecialCooldown * 0.74),
      );
    });

    test('fire pip is tempo pressure rather than let-level burst', () {
      final firePip = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'pip',
        element: 'Fire',
        damage: 10,
        maxHp: 100,
        casterBeauty: 4,
        casterIntelligence: 4,
        targetPos: const Offset(120, 0),
      );
      final fireLet = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'let',
        element: 'Fire',
        damage: 10,
        maxHp: 100,
        casterBeauty: 4,
        casterIntelligence: 4,
        targetPos: const Offset(120, 0),
      );

      final firePipDamage = firePip.projectiles.fold<double>(
        0,
        (sum, p) => sum + p.damage,
      );

      expect(firePipDamage, lessThan(fireLet.projectiles.first.damage));
      expect(firePip.basicHasteTimer, lessThanOrEqualTo(1.3));
      expect(firePip.basicHasteMultiplier, greaterThanOrEqualTo(0.86));
      expect(firePip.projectiles.every((p) => p.bounceCount <= 1), isTrue);
    });

    test('pip elements produce distinct tempo signatures without residue', () {
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
          family: 'pip',
          element: element,
          damage: 10,
          maxHp: 100,
          targetPos: const Offset(120, 0),
        );
        final totalBounces = result.projectiles.fold<int>(
          0,
          (sum, p) => sum + p.bounceCount,
        );
        final snares = result.projectiles.where((p) => p.snareRadius > 0);
        final intercepts = result.projectiles.fold<int>(
          0,
          (sum, p) => sum + p.interceptCharges,
        );
        final maxSpeed = result.projectiles
            .map((p) => p.speedMultiplier)
            .reduce(max);
        final maxRadius = result.projectiles
            .map((p) => p.radiusMultiplier)
            .reduce(max);
        final maxLife = result.projectiles.map((p) => p.life).reduce(max);

        expect(result.projectiles.every((p) => p.trailInterval == 0), isTrue);
        signatures.add(
          [
            result.projectiles.length,
            result.projectiles.where((p) => p.homing).length,
            result.projectiles.where((p) => p.piercing).length,
            totalBounces,
            snares.length,
            intercepts,
            (maxSpeed * 100).round(),
            (maxRadius * 100).round(),
            (maxLife * 10).round(),
            result.basicHasteTimer > 0 ? 1 : 0,
          ].join('/'),
        );
      }

      expect(signatures.length, elements.length);
    });

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
