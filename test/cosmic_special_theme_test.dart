import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cosmic special themes', () {
    test('mask trap persistence scales up with intelligence', () {
      final lowResult = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mask',
        element: 'Mud',
        damage: 10,
        maxHp: 100,
        casterIntelligence: 1,
        targetPos: const Offset(90, 0),
      );
      final highResult = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mask',
        element: 'Mud',
        damage: 10,
        maxHp: 100,
        casterIntelligence: 5,
        targetPos: const Offset(90, 0),
      );

      final lowTrapLife = lowResult.projectiles
          .where((p) => p.stationary && p.decoy)
          .map((p) => p.life)
          .reduce((a, b) => a > b ? a : b);
      final highTrapLife = highResult.projectiles
          .where((p) => p.stationary && p.decoy)
          .map((p) => p.life)
          .reduce((a, b) => a > b ? a : b);

      expect(highTrapLife, greaterThan(lowTrapLife));
    });

    test('let core reads as a meteor and dark let carries void aftermath', () {
      final result = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'let',
        element: 'Dark',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(120, 0),
      );

      expect(
        result.projectiles.any(
          (p) => p.visualStyle == ProjectileVisualStyle.meteor,
        ),
        isTrue,
      );
      expect(
        result.projectiles.any(
          (p) =>
              p.spawnLetElementalOnImpact &&
              p.killEffect == AbilityEffectKind.blackHole,
        ),
        isTrue,
      );
    });

    test('poison let defers anchored contamination until impact follow-up', () {
      final result = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'let',
        element: 'Poison',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(120, 0),
      );

      final meteor = result.projectiles.single;
      expect(meteor.spawnLetElementalOnImpact, isTrue);
      expect(meteor.hitEffect, AbilityEffectKind.poison);
    });

    test('mask trap families keep snaring control in the payload', () {
      final result = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mask',
        element: 'Mud',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(90, 0),
      );

      expect(
        result.projectiles.any(
          (p) => p.stationary && p.decoy && p.snareRadius > 0,
        ),
        isTrue,
      );
      expect(
        result.projectiles.where((p) => p.homing).length,
        lessThanOrEqualTo(6),
      );
    });

    test('pip air reads as ricochet clean-up instead of heavy homing', () {
      final result = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'pip',
        element: 'Air',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(90, 0),
      );

      expect(result.projectiles, isNotEmpty);
      // Air pip ricochets but is no longer the bouncy-king — that's
      // Lightning's "double the ricochet" identity per the design doc.
      // Air's role is "ricochet shots that push back survivors".
      expect(result.projectiles.every((p) => p.bounceCount >= 2), isTrue);
      expect(result.projectiles.every((p) => !p.homing), isTrue);
    });

    test('pip lightning owns the high-bounce ricochet niche', () {
      final lightning = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'pip',
        element: 'Lightning',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(90, 0),
      );
      final crystal = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'pip',
        element: 'Crystal',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(90, 0),
      );
      final lightningMaxBounce = lightning.projectiles
          .map((p) => p.bounceCount)
          .fold<int>(0, (a, b) => a > b ? a : b);
      final crystalMaxBounce = crystal.projectiles
          .map((p) => p.bounceCount)
          .fold<int>(0, (a, b) => a > b ? a : b);
      expect(lightningMaxBounce, greaterThan(crystalMaxBounce));
      expect(lightningMaxBounce, greaterThanOrEqualTo(4));
    });

    test('five planned families expose shared ability effect descriptors', () {
      final let = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'let',
        element: 'Lightning',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(90, 0),
      );
      final pip = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'pip',
        element: 'Spirit',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(90, 0),
      );
      final mane = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mane',
        element: 'Plant',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(90, 0),
      );
      final mask = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mask',
        element: 'Dark',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(90, 0),
      );
      final wing = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'wing',
        element: 'Light',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(90, 0),
      );

      expect(let.projectiles.first.abilityFamily, 'let');
      expect(let.projectiles.first.hitEffect, AbilityEffectKind.chain);
      expect(
        pip.projectiles.any((p) => p.killEffect == AbilityEffectKind.buff),
        isTrue,
      );
      expect(mane.projectiles.every((p) => p.piercing), isTrue);
      expect(
        mane.projectiles.any((p) => p.pierceEffect == AbilityEffectKind.root),
        isTrue,
      );
      expect(
        mask.projectiles.any((p) => p.hitEffect == AbilityEffectKind.pull),
        isTrue,
      );
      expect(wing.beams, isNotEmpty);
      expect(wing.beams.first.refractionCount, greaterThan(0));
    });

    test('authored ability contract covers every species element payload', () {
      expect(
        kCosmicAbilityContractElementsByFamily.keys,
        containsAll(kCosmicAuthoredAbilityFamilies),
      );
      expect(
        kCosmicTranscribedAbilityFamilies.every(
          isCosmicTranscribedAbilityFamily,
        ),
        isTrue,
      );

      for (final family in kCosmicAuthoredAbilityFamilies) {
        final elements = kCosmicAbilityContractElementsByFamily[family];
        expect(elements, kCosmicAbilityElements, reason: family);

        for (final element in elements!) {
          final result = createCosmicSpecialAbility(
            origin: const Offset(0, 0),
            baseAngle: 0,
            family: family,
            element: element,
            damage: 10,
            maxHp: 100,
            casterPower: 5,
            casterBeauty: 5,
            casterIntelligence: 5,
            casterStrength: 5,
            targetPos: const Offset(90, 0),
            survivalMode: true,
          );
          final hasSupportPayload =
              result.beams.isNotEmpty ||
              result.shieldHp > 0 ||
              result.chargeTimer > 0 ||
              result.selfHeal > 0 ||
              result.shipHeal > 0 ||
              result.blessingTimer > 0 ||
              result.basicHasteTimer > 0;

          expect(
            result.projectiles.isNotEmpty || hasSupportPayload,
            isTrue,
            reason: '$family $element produced no authored payload',
          );
          if (result.projectiles.isNotEmpty) {
            expect(
              result.projectiles.any(
                preservesAuthoredCosmicAbilityVisualIdentity,
              ),
              isTrue,
              reason: '$family $element can be flattened by old render paths',
            );
          }
        }
      }
    });

    test('mane poison carries a haste burst with the barrage', () {
      final result = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mane',
        element: 'Poison',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(90, 0),
      );

      expect(result.basicHasteTimer, greaterThan(0));
      expect(result.basicHasteMultiplier, lessThan(1.0));
    });

    test('kin escort control pieces persist longer with intelligence', () {
      final lowResult = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'kin',
        element: 'Steam',
        damage: 10,
        maxHp: 100,
        casterIntelligence: 1,
        targetPos: const Offset(120, 0),
      );
      final highResult = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'kin',
        element: 'Steam',
        damage: 10,
        maxHp: 100,
        casterIntelligence: 5,
        targetPos: const Offset(120, 0),
      );

      final lowEscort = lowResult.projectiles.firstWhere((p) => p.holdOrbit);
      final highEscort = highResult.projectiles.firstWhere((p) => p.holdOrbit);

      expect(highEscort.life, greaterThan(lowEscort.life));
      expect(highEscort.orbitTime, greaterThan(lowEscort.orbitTime));
    });

    test('mystic spirit now stages a brief chorus orbit before release', () {
      final result = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mystic',
        element: 'Spirit',
        damage: 10,
        maxHp: 100,
        targetPos: const Offset(120, 0),
      );

      expect(result.projectiles.any((p) => p.orbitTime > 0), isTrue);
      expect(result.projectiles.any((p) => p.homing && p.piercing), isTrue);
    });

    test('mystic control zones gain extra uptime from intelligence', () {
      final lowResult = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mystic',
        element: 'Steam',
        damage: 10,
        maxHp: 100,
        casterIntelligence: 1,
        targetPos: const Offset(120, 0),
      );
      final highResult = createCosmicSpecialAbility(
        origin: const Offset(0, 0),
        baseAngle: 0,
        family: 'mystic',
        element: 'Steam',
        damage: 10,
        maxHp: 100,
        casterIntelligence: 5,
        targetPos: const Offset(120, 0),
      );

      final lowNodeLife = lowResult.projectiles
          .where((p) => p.stationary && p.snareRadius > 0)
          .map((p) => p.life)
          .reduce((a, b) => a > b ? a : b);
      final highNodeLife = highResult.projectiles
          .where((p) => p.stationary && p.snareRadius > 0)
          .map((p) => p.life)
          .reduce((a, b) => a > b ? a : b);

      expect(highNodeLife, greaterThan(lowNodeLife));
    });
  });
}
