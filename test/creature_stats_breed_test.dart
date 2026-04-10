import 'dart:math';

import 'package:alchemons/models/creature_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CreatureStats.breed base stat inheritance', () {
    const eliteParent = CreatureStats(
      speed: 4.0,
      intelligence: 4.0,
      strength: 4.0,
      beauty: 4.0,
      speedPotential: 5.0,
      intelligencePotential: 5.0,
      strengthPotential: 5.0,
      beautyPotential: 5.0,
    );

    const weakParent = CreatureStats(
      speed: 1.0,
      intelligence: 1.0,
      strength: 1.0,
      beauty: 1.0,
      speedPotential: 5.0,
      intelligencePotential: 5.0,
      strengthPotential: 5.0,
      beautyPotential: 5.0,
    );

    test('often produces children near the stronger parent', () {
      var strongLikeStats = 0;
      var totalStats = 0;
      var sum = 0.0;

      for (var seed = 0; seed < 250; seed++) {
        final child = CreatureStats.breed(
          eliteParent,
          weakParent,
          Random(seed),
          mutationChance: 0,
        );

        final stats = [
          child.speed,
          child.intelligence,
          child.strength,
          child.beauty,
        ];

        for (final stat in stats) {
          totalStats++;
          sum += stat;
          if (stat >= 3.0) {
            strongLikeStats++;
          }
        }
      }

      final averageStat = sum / totalStats;
      expect(averageStat, greaterThan(2.5));
      expect(strongLikeStats, greaterThan(totalStats * 0.35));
    });

    test('still allows weak-parent inheritance on some stats', () {
      var weakLikeStats = 0;

      for (var seed = 0; seed < 250; seed++) {
        final child = CreatureStats.breed(
          eliteParent,
          weakParent,
          Random(seed),
          mutationChance: 0,
        );

        final stats = [
          child.speed,
          child.intelligence,
          child.strength,
          child.beauty,
        ];

        for (final stat in stats) {
          if (stat <= 2.0) {
            weakLikeStats++;
          }
        }
      }

      expect(weakLikeStats, greaterThan(0));
    });
  });

  group('CreatureStats.breed potential protection', () {
    const swiftParentA = CreatureStats(
      speed: 2.0,
      intelligence: 4.0,
      strength: 4.0,
      beauty: 1.0,
      speedPotential: 2.0,
      intelligencePotential: 5.0,
      strengthPotential: 5.0,
      beautyPotential: 1.0,
    );

    const swiftParentB = CreatureStats(
      speed: 2.0,
      intelligence: 1.0,
      strength: 1.0,
      beauty: 4.0,
      speedPotential: 2.1,
      intelligencePotential: 1.0,
      strengthPotential: 1.0,
      beautyPotential: 5.0,
    );

    const doubleSwiftA = CreatureStats(
      speed: 4.0,
      intelligence: 2.0,
      strength: 2.0,
      beauty: 2.0,
      speedPotential: 4.6,
      intelligencePotential: 2.0,
      strengthPotential: 2.0,
      beautyPotential: 2.0,
    );

    const doubleSwiftB = CreatureStats(
      speed: 4.0,
      intelligence: 2.0,
      strength: 2.0,
      beauty: 2.0,
      speedPotential: 4.2,
      intelligencePotential: 2.0,
      strengthPotential: 2.0,
      beautyPotential: 2.0,
    );

    test('matching nature keeps the protected stat out of wildcard crashes', () {
      for (var seed = 0; seed < 250; seed++) {
        final child = CreatureStats.breed(
          swiftParentA,
          swiftParentB,
          Random(seed),
          mutationChance: 0,
          parent1NatureId: 'Swift',
        );

        expect(child.speedPotential, greaterThanOrEqualTo(1.9));
      }
    });

    test('shared matching nature floors the protected stat at weaker parent', () {
      for (var seed = 0; seed < 250; seed++) {
        final child = CreatureStats.breed(
          doubleSwiftA,
          doubleSwiftB,
          Random(seed),
          mutationChance: 0,
          parent1NatureId: 'Swift',
          parent2NatureId: 'Swift',
        );

        expect(child.speedPotential, greaterThanOrEqualTo(4.2));
      }
    });
  });
}
