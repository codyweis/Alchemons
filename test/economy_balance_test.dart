import 'dart:math';

import 'package:alchemons/constants/black_market_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/economy_balance.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadNatures);

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
        expect(
          reward,
          isNotNull,
          reason: 'wave $wave should always award loot',
        );
        expect(
          reward!.quantity,
          1,
          reason: 'wave $wave should stay on the smallest loot tier',
        );
      }

      var lootDrops = 0;
      for (var i = 0; i < 1000; i++) {
        if (LootBoxConfig.rollSurvivalLootBoxReward(21, Random(i)) != null) {
          lootDrops++;
        }
      }

      expect(lootDrops, greaterThan(550));
      expect(lootDrops, lessThan(750));
    });

    test('survival late clears can occasionally tier up loot boxes', () {
      var doubled = 0;
      for (var i = 0; i < 2000; i++) {
        final reward = LootBoxConfig.rollSurvivalLootBoxReward(45, Random(i));
        if (reward != null && reward.quantity == 2) {
          doubled++;
        }
      }

      expect(doubled, greaterThan(450));
      expect(doubled, lessThan(900));
    });
  });

  test('shop currency exchanges use the canonical economy anchors', () {
    final silverToGold = ShopService.allOffers.firstWhere(
      (offer) => offer.id == 'fx.silver_to_gold.unit',
    );
    final goldToSilver = ShopService.allOffers.firstWhere(
      (offer) => offer.id == 'fx.gold_to_silver.unit',
    );

    expect(silverToGold.cost, const {
      'silver': EconomyBalance.standardGoldBundleSilverCost,
    });
    expect(silverToGold.reward, const {
      'gold': EconomyBalance.standardGoldBundle,
    });
    expect(goldToSilver.cost, const {'gold': 1});
    expect(goldToSilver.reward, const {
      'silver': EconomyBalance.silverPerGoldPayout,
    });
  });

  test('every survival orb offer uses its catalog Gold price', () {
    for (final definition in kOrbBases.where((orb) => orb.cost > 0)) {
      final offer = ShopService.allOffers.firstWhere(
        (candidate) => candidate.id == definition.shopId,
      );
      expect(offer.cost, {'gold': definition.cost}, reason: definition.name);
    }
  });

  test('Wild Fusion is an unlimited Silver consumable', () {
    final offer = ShopService.allOffers.firstWhere(
      (candidate) => candidate.id == 'boost.wild_fusion',
    );

    expect(offer.inventoryKey, InvKeys.wildFusion);
    expect(offer.cost, const {'silver': 1250});
    expect(offer.limit, PurchaseLimit.unlimited);
  });

  test(
    'direct survival orb purchase spends Gold and preserves Silver',
    () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.settingsDao.setSetting('wallet_gold', '25');
      await db.settingsDao.setSetting('wallet_silver', '12000');
      final service = SurvivalUpgradeService(db);
      await service.load();

      expect(await service.purchaseOrbSkin(OrbBaseSkin.voidforgeOrb), isTrue);
      expect(await db.currencyDao.getGoldBalance(), 0);
      expect(await db.currencyDao.getSilverBalance(), 12000);
    },
  );

  test('Alchemon sale values respect rarity and legacy spellings', () {
    int value(String rarity, {int level = 1}) =>
        BlackMarketConstants.calculateSellPrice(
          rarity: rarity,
          level: level,
          isPrismatic: false,
        );

    expect(value('common'), 125);
    expect(value('uncommon'), 200);
    expect(value('rare'), 350);
    expect(value('legendary'), 700);
    expect(value('Mystic'), 1500);
    expect(value('mythic'), 1500);
    expect(value('Variant'), 2000);
    expect(value('Mystic', level: 10), 2175);
    expect(value('Variant'), greaterThan(value('Mystic')));
  });

  test('Potential and Coveted Nature add bounded specimen value', () {
    final baseline = BlackMarketConstants.calculateSellPrice(
      rarity: 'common',
      level: 1,
      isPrismatic: false,
      averagePotential: 20,
    );
    final highPotential = BlackMarketConstants.calculateSellPrice(
      rarity: 'common',
      level: 1,
      isPrismatic: false,
      averagePotential: 90,
    );
    final coveted = BlackMarketConstants.calculateSellPrice(
      rarity: 'common',
      level: 1,
      isPrismatic: false,
      natureId: 'Coveted',
    );
    final combined = BlackMarketConstants.calculateSellPrice(
      rarity: 'common',
      level: 1,
      isPrismatic: false,
      natureId: 'Coveted',
      averagePotential: 90,
    );

    expect(baseline, 125);
    expect(highPotential, 188);
    expect(coveted, 188);
    expect(combined, 281);
  });

  test('bulk Alchemon sales pay the normal per-specimen amount', () {
    final prices = List.generate(
      100,
      (_) => BlackMarketConstants.calculateSellPrice(
        rarity: 'common',
        level: 1,
        isPrismatic: false,
      ),
    );

    expect(prices.fold<int>(0, (sum, price) => sum + price), 12500);
  });

  test('Potential Souls remain a substantial endgame Silver sink', () {
    final commonLevel1 = BlackMarketConstants.calculateSellPrice(
      rarity: 'common',
      level: 1,
      isPrismatic: false,
    );
    final mysticLevel10 = BlackMarketConstants.calculateSellPrice(
      rarity: 'Mystic',
      level: 10,
      isPrismatic: false,
    );
    final firstSoulCost = AlchemonStatSystem.potentialSoulSilverCost(1);

    expect((firstSoulCost / commonLevel1).ceil(), 80);
    expect((firstSoulCost / mysticLevel10).ceil(), 5);
  });
}
