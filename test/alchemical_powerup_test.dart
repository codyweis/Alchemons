import 'package:alchemons/models/alchemical_powerup.dart';
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
}
