// Mane's design board: "Mud — first enemy hit, ball breaks apart and goes in
// 10 different ways." The shared mane shape is ONE big projectile in a line.
//
// Mud was generating a six-lane 90-degree fan instead, so aiming at a boss
// sprayed +-45 degrees either side of it. Most lanes missed, the ten-way
// shatter went off nowhere near what you aimed at, and it read as the special
// simply not firing at the target.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicSpecialResult _cast(String element, {double stat = 3.0}) =>
    createCosmicSpecialAbility(
      origin: Offset.zero,
      baseAngle: 0,
      family: 'mane',
      element: element,
      damage: 100,
      maxHp: 500,
      targetPos: const Offset(200, 0),
      casterPower: stat,
      casterBeauty: stat,
      casterIntelligence: stat,
      casterStrength: stat,
    );

void main() {
  test('Mud fires a single ball, not a fan', () {
    final r = _cast('Mud');
    expect(
      r.projectiles.length,
      1,
      reason: 'the shatter is the spread — the cast itself is one ball',
    );
  });

  test('that ball goes where you aimed', () {
    final r = _cast('Mud');
    expect(r.projectiles.single.angle, closeTo(0, 1e-9));
  });

  test('it carries the family piercing flag, which the shatter overrides', () {
    // Every mane projectile is built piercing ("slow piercing catapults").
    // For Mud that never applies: the collision handler marks the ball
    // consumed the moment it hits, which is what spawns the ten fragments.
    expect(_cast('Mud').projectiles.single.piercing, isTrue);
  });

  test('it stays a single ball across the stat range', () {
    for (final stat in [0.5, 2.0, 3.0, 4.5, 5.0]) {
      expect(_cast('Mud', stat: stat).projectiles.length, 1, reason: '$stat');
    }
  });

  test('it is a heavy ball, not a scaled-down lane', () {
    final mud = _cast('Mud').projectiles.single;
    // Comparable single-projectile manes for reference.
    expect(mud.visualScale, greaterThan(1.3));
    expect(mud.radiusMultiplier, greaterThan(1.3));
  });

  test('other mane elements are untouched', () {
    // Fire is authored as (3-8) fireballs and must stay a fan.
    expect(_cast('Fire').projectiles.length, greaterThan(1));
    expect(_cast('Ice').projectiles.length, greaterThan(1));
  });
}
