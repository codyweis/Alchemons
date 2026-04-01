import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Economy balance', () {
    test('battle ring only grants gold on first clears', () {
      final ring = BattleRing(position: const Offset(0, 0));

      expect(ring.goldReward, 1);

      ring.currentLevel = 6;
      expect(ring.goldReward, 2);

      ring.currentLevel = 9;
      expect(ring.goldReward, 5);

      ring.currentLevel = BattleRing.maxLevels;
      expect(ring.goldReward, 0);
    });

    test('boss rematch gold stays scarce even at top difficulty', () {
      var totalGold = 0;
      for (var i = 0; i < 5000; i++) {
        totalGold +=
            LootBoxConfig.rollBossRematchBonusCurrency(17, Random(i))['gold'] ??
            0;
      }

      final avgGold = totalGold / 5000.0;
      expect(avgGold, lessThan(0.10));
    });

    test('survival gold stays scarce for repeatable late runs', () {
      var totalGold = 0;
      for (var i = 0; i < 5000; i++) {
        totalGold +=
            LootBoxConfig.rollSurvivalBonusCurrency(30, Random(i))['gold'] ?? 0;
      }

      final avgGold = totalGold / 5000.0;
      expect(avgGold, lessThan(0.08));
    });

    test('survival guarantees the smallest loot pool through wave 20', () {
      for (final wave in [10, 15, 20]) {
        final reward = LootBoxConfig.rollSurvivalLootBoxReward(
          wave,
          Random(wave),
        );
        expect(reward, isNotNull, reason: 'wave $wave should always award loot');
        expect(reward!.quantity, 1, reason: 'wave $wave should stay on the smallest loot tier');
      }

      var lootDrops = 0;
      for (var i = 0; i < 1000; i++) {
        if (LootBoxConfig.rollSurvivalLootBoxReward(21, Random(i)) != null) {
          lootDrops++;
        }
      }

      expect(lootDrops, greaterThan(400));
      expect(lootDrops, lessThan(600));
    });
  });
}
