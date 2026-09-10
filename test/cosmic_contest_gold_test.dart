// Trait-contest gold payout curve.
//
// Gold leaves the run (shards do not), so the ramp is deliberately linear:
// one gold at level 1 and one more per level. These tests pin the shape so a
// later balance pass has to break a test rather than quietly inflate the
// wallet.

import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cosmicContestGoldReward', () {
    test('level 1 pays exactly 1 gold', () {
      expect(cosmicContestGoldReward(1), 1);
    });

    test('is strictly increasing across the ladder', () {
      for (var l = 1; l < 40; l++) {
        expect(
          cosmicContestGoldReward(l + 1),
          greaterThan(cosmicContestGoldReward(l)),
        );
      }
    });

    test('pays 1/5/10/20 at levels 1/5/10/20', () {
      expect(cosmicContestGoldReward(1), 1);
      expect(cosmicContestGoldReward(5), 5);
      expect(cosmicContestGoldReward(10), 10);
      expect(cosmicContestGoldReward(20), 20);
    });

    test('stays gentle: never more than 2x the level', () {
      for (var l = 1; l <= 100; l++) {
        expect(cosmicContestGoldReward(l), lessThanOrEqualTo(l * 2));
      }
    });

    test('a nonsense level still pays the floor, never zero or negative', () {
      expect(cosmicContestGoldReward(0), 1);
      expect(cosmicContestGoldReward(-3), 1);
    });

    test('a full 5-level trait ladder is worth 15 gold', () {
      final total = kCosmicContestLevels.values.first
          .map((l) => cosmicContestGoldReward(l.level))
          .fold<int>(0, (a, b) => a + b);
      expect(total, 15);
    });
  });
}
