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

    test('let core reads as a meteor and dark let keeps anchored wells', () {
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
        result.projectiles.where((p) => p.stationary).length,
        greaterThanOrEqualTo(3),
      );
    });

    test(
      'poison let establishes anchored contamination before guided follow-up',
      () {
        final result = createCosmicSpecialAbility(
          origin: const Offset(0, 0),
          baseAngle: 0,
          family: 'let',
          element: 'Poison',
          damage: 10,
          maxHp: 100,
          targetPos: const Offset(120, 0),
        );

        expect(result.projectiles.any((p) => p.stationary), isTrue);
        expect(result.projectiles.any((p) => p.homing), isTrue);
      },
    );

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
      expect(result.projectiles.every((p) => p.bounceCount >= 4), isTrue);
      expect(result.projectiles.every((p) => !p.homing), isTrue);
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
