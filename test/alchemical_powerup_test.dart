import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

void main() {
  group('powerup reward rolls', () {
    test('cosmic survival has no drops before wave 10', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(rollCosmicSurvivalPowerupRewards(9, Random(seed)), isEmpty);
      }
    });

    test('cosmic survival keeps midgame powerup drops rare', () {
      var drops = 0;
      for (var seed = 0; seed < 1000; seed++) {
        if (rollCosmicSurvivalPowerupRewards(30, Random(seed)).isNotEmpty) {
          drops++;
        }
      }

      expect(drops, greaterThan(120));
      expect(drops, lessThan(240));
    });

    test('late survival drops improve without becoming guaranteed', () {
      var drops = 0;
      for (var seed = 0; seed < 1000; seed++) {
        if (rollCosmicSurvivalPowerupRewards(50, Random(seed)).isNotEmpty) {
          drops++;
        }
      }

      expect(drops, greaterThan(320));
      expect(drops, lessThan(480));
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

  group('orb enhancement economy', () {
    test('cost to max sums every remaining rank tier', () {
      // Walk the curve independently of the implementation so a rebalance of
      // orbCostForNextRank cannot silently desync the "N to max" the Stat
      // Infusion screen promises.
      for (
        var rank = 0;
        rank <= AlchemonStatSystem.maxEnhancementRank;
        rank++
      ) {
        var expected = 0;
        for (var r = rank; r < AlchemonStatSystem.maxEnhancementRank; r++) {
          expected += AlchemonStatSystem.orbCostForNextRank(r);
        }
        expect(AlchemonStatSystem.orbCostToMaxRank(rank), expected);
      }
    });

    test('a maxed stat needs nothing further', () {
      expect(
        AlchemonStatSystem.orbCostToMaxRank(
          AlchemonStatSystem.maxEnhancementRank,
        ),
        0,
      );
    });

    test('cost to max shrinks monotonically as ranks are bought', () {
      var previous = AlchemonStatSystem.orbCostToMaxRank(0);
      for (
        var rank = 1;
        rank <= AlchemonStatSystem.maxEnhancementRank;
        rank++
      ) {
        final current = AlchemonStatSystem.orbCostToMaxRank(rank);
        expect(current, lessThan(previous));
        previous = current;
      }
    });

    test('the screenshot case: rank 3 costs 24 orbs to max', () {
      expect(AlchemonStatSystem.orbCostToMaxRank(3), 24);
      expect(AlchemonStatSystem.orbCostForNextRank(3), 2);
    });
  });
}
