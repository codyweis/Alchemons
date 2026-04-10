import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

void main() {
  group('alchemicalPowerup ranges', () {
    test('uses 0.05 as the minimum roll when room remains', () {
      expect(
        alchemicalPowerupMinDelta(currentValue: 3.9, potentialValue: 5.0),
        0.05,
      );
    });

    test('uses 0.25 as the maximum roll when room remains', () {
      expect(
        alchemicalPowerupMaxDelta(currentValue: 4.0, potentialValue: 5.0),
        0.25,
      );
    });

    test('caps minimum and maximum ranges to remaining potential', () {
      expect(
        alchemicalPowerupMinDelta(currentValue: 4.96, potentialValue: 5.0),
        closeTo(0.04, 0.0001),
      );
      expect(
        alchemicalPowerupMaxDelta(currentValue: 4.96, potentialValue: 5.0),
        closeTo(0.04, 0.0001),
      );
    });

    test('returns zero at cap', () {
      expect(
        alchemicalPowerupMinDelta(currentValue: 5.0, potentialValue: 5.0),
        0.0,
      );
      expect(
        alchemicalPowerupMaxDelta(currentValue: 5.0, potentialValue: 5.0),
        0.0,
      );
    });
  });

  group('rollAlchemicalPowerup', () {
    test('maps the 5% low roll bucket to +0.05', () {
      final roll = rollAlchemicalPowerup(
        currentValue: 2.0,
        potentialValue: 5.0,
        rng: _FixedRandom(0.01),
      );
      expect(roll.tier, AlchemicalPowerupRollTier.fizzle);
      expect(roll.rolledDelta, 0.05);
      expect(roll.appliedDelta, 0.05);
      expect(roll.isRare, isTrue);
    });

    test('maps the 50% steady bucket to +0.10', () {
      final roll = rollAlchemicalPowerup(
        currentValue: 2.0,
        potentialValue: 5.0,
        rng: _FixedRandom(0.40),
      );
      expect(roll.tier, AlchemicalPowerupRollTier.steady);
      expect(roll.appliedDelta, 0.10);
    });

    test('maps the 25% surge bucket to +0.15', () {
      final roll = rollAlchemicalPowerup(
        currentValue: 2.0,
        potentialValue: 5.0,
        rng: _FixedRandom(0.70),
      );
      expect(roll.tier, AlchemicalPowerupRollTier.surge);
      expect(roll.appliedDelta, 0.15);
    });

    test('maps the remaining bucket to +0.20', () {
      final roll = rollAlchemicalPowerup(
        currentValue: 2.0,
        potentialValue: 5.0,
        rng: _FixedRandom(0.90),
      );
      expect(roll.tier, AlchemicalPowerupRollTier.overcharge);
      expect(roll.appliedDelta, 0.20);
    });

    test('maps the 5% jackpot bucket to +0.25', () {
      final roll = rollAlchemicalPowerup(
        currentValue: 2.0,
        potentialValue: 5.0,
        rng: _FixedRandom(0.99),
      );
      expect(roll.tier, AlchemicalPowerupRollTier.jackpot);
      expect(roll.appliedDelta, 0.25);
      expect(roll.isJackpot, isTrue);
    });

    test('caps a jackpot roll to remaining potential', () {
      final roll = rollAlchemicalPowerup(
        currentValue: 4.90,
        potentialValue: 5.0,
        rng: _FixedRandom(0.99),
      );
      expect(roll.rolledDelta, 0.25);
      expect(roll.appliedDelta, closeTo(0.10, 0.0001));
    });
  });

  group('powerup reward rolls', () {
    test('cosmic survival has no drops before wave 10', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(rollCosmicSurvivalPowerupRewards(9, Random(seed)), isEmpty);
      }
    });

    test('cosmic survival guarantees a drop at wave 50+', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(rollCosmicSurvivalPowerupRewards(50, Random(seed)), isNotEmpty);
      }
    });

    test('boss rift rolls at most one of each orb type', () {
      for (var seed = 0; seed < 50; seed++) {
        final rewards = rollBossRiftPowerupRewards(Random(seed));
        final keys = rewards.map((e) => e.key).toList();
        expect(keys.toSet().length, keys.length);
        for (final reward in rewards) {
          expect(reward.value, 1);
        }
      }
    });
  });
}

class _FixedRandom implements Random {
  final double _value;

  _FixedRandom(this._value);

  @override
  bool nextBool() => _value >= 0.5;

  @override
  double nextDouble() => _value;

  @override
  int nextInt(int max) => 0;
}
