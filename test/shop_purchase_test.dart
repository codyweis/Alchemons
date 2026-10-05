import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/home_decor.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/shop_scenes.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlchemonsDatabase db;
  late ShopService shop;
  late int initialWildFusion;

  setUp(() async {
    db = AlchemonsDatabase(NativeDatabase.memory());
    shop = ShopService(
      db,
      ConstellationEffectsService(db),
      FactionService(db),
      TimedBoostService(db.settingsDao),
    );
    await shop.reloadFromStorage();
    initialWildFusion = await db.inventoryDao.getItemQty(InvKeys.wildFusion);
    await db.settingsDao.setSetting('wallet_gold', '100');
    await db.settingsDao.setSetting('wallet_silver', '1000');
  });

  tearDown(() async {
    await db.close();
    shop.dispose();
  });

  test(
    'free Wild Fusion is one item, then bulk purchases cost silver',
    () async {
      final offer = ShopService.allOffers.firstWhere(
        (o) => o.id == ShopService.wildFusionOfferId,
      );
      expect(shop.allowsQuantity(offer), isFalse);
      expect(await shop.purchase(offer.id, qty: 3), isFalse);
      expect(
        await db.inventoryDao.getItemQty(InvKeys.wildFusion),
        initialWildFusion,
      );
      expect(shop.getPurchaseCount(offer.id), 0);
      expect(await shop.purchase(offer.id), isTrue);
      expect(
        await db.inventoryDao.getItemQty(InvKeys.wildFusion),
        initialWildFusion + 1,
      );
      expect((await db.currencyDao.getAllCurrencies())['silver'], 1000);
      expect(shop.allowsQuantity(offer), isTrue);
      expect(await shop.purchase(offer.id, qty: 3), isTrue);
      expect(
        await db.inventoryDao.getItemQty(InvKeys.wildFusion),
        initialWildFusion + 4,
      );
      expect((await db.currencyDao.getAllCurrencies())['silver'], 700);
    },
  );

  test(
    'debug FREE SHOP charges nothing, and only while the tools are on',
    () async {
      addTearDown(() {
        DebugSettingsService.enabledNotifier.value = false;
        DebugSettingsService.freeShopNotifier.value = false;
      });
      final offer = ShopService.allOffers.firstWhere(
        (o) => o.id == 'effects.prismatic_cascade',
      );
      // The switch alone does nothing with the developer tools off.
      DebugSettingsService.freeShopNotifier.value = true;
      expect(shop.getEffectiveCost(offer), offer.cost);

      DebugSettingsService.enabledNotifier.value = true;
      expect(shop.getEffectiveCost(offer), {'gold': 0});
      expect(await shop.purchase(offer.id), isTrue);
      expect(
        await db.inventoryDao.getItemQty(InvKeys.alchemyPrismaticCascade),
        1,
      );
      expect((await db.currencyDao.getAllCurrencies())['gold'], 100);
      expect(DebugSettingsService.priced(const {'gold': 25}), {'gold': 0});

      // Tools off again: real prices, and they are charged.
      DebugSettingsService.enabledNotifier.value = false;
      expect(DebugSettingsService.priced(const {'gold': 25}), {'gold': 25});
      expect(await shop.purchase(offer.id), isTrue);
      expect((await db.currencyDao.getAllCurrencies())['gold'], 0);
    },
  );

  test('overlapping free purchases cannot grant two free catalysts', () async {
    final results = await Future.wait([
      shop.purchase(ShopService.wildFusionOfferId),
      shop.purchase(ShopService.wildFusionOfferId),
    ]);
    expect(results.where((ok) => ok).length, 1);
    expect(
      await db.inventoryDao.getItemQty(InvKeys.wildFusion),
      initialWildFusion + 1,
    );
  });

  for (final type in AlchemicalPowerupType.values) {
    test('${type.name} grants selected quantity and charges gold', () async {
      expect(await shop.purchase(type.shopOfferId, qty: 3), isTrue);
      expect(await db.inventoryDao.getItemQty(type.inventoryKey), 3);
      expect((await db.currencyDao.getAllCurrencies())['gold'], 70);
      expect(shop.getPurchaseCount(type.shopOfferId), 1);
    });

    test('${type.name} cannot be bought with insufficient gold', () async {
      await db.settingsDao.setSetting('wallet_gold', '9');
      expect(await shop.purchase(type.shopOfferId), isFalse);
      expect(await db.inventoryDao.getItemQty(type.inventoryKey), 0);
      expect((await db.currencyDao.getAllCurrencies())['gold'], 9);
      expect(shop.getPurchaseCount(type.shopOfferId), 0);
    });
  }

  test(
    'home decor: bought into the inventory, up to what a realm stands',
    () async {
      await db.settingsDao.setSetting('wallet_silver', '10000');
      final lantern = HomeDecor.byId('lantern_post')!;
      expect(
        shop.allowsQuantity(
          ShopService.allOffers.firstWhere((o) => o.id == lantern.offerId),
        ),
        isTrue,
      );
      // More than the cap asked for: only the cap is bought, and paid for.
      expect(await shop.purchase(lantern.offerId, qty: 20), isTrue);
      expect(
        await db.inventoryDao.getItemQty(lantern.inventoryKey),
        lantern.max,
      );
      expect(
        (await db.currencyDao.getAllCurrencies())['silver'],
        10000 - lantern.silver * lantern.max,
      );
      expect(shop.canPurchase(lantern.offerId), isFalse, reason: 'at the cap');
      expect(shop.getPurchaseStatus(lantern.offerId), 'MAX');

      // A Wonder is bought once, for 150 gold.
      await db.settingsDao.setSetting('wallet_gold', '300');
      final spring = HomeDecor.byId('hot_spring')!;
      expect(spring.gold, 150);
      expect(await shop.purchase(spring.offerId), isTrue);
      expect(shop.canPurchase(spring.offerId), isFalse);
      expect((await db.currencyDao.getAllCurrencies())['gold'], 150);
      expect(await db.inventoryDao.getItemQty(spring.inventoryKey), 1);

      // Every Wonder costs the same, and every piece has a grant.
      for (final d in HomeDecor.all) {
        if (d.tier == DecorTier.wonder) expect(d.gold, 150, reason: d.id);
        expect(d.cost, isNotEmpty, reason: d.id);
      }
    },
  );

  test('a scene is bought once, for 500 gold, and opens its realm', () async {
    final scene = shopSceneOf('dunes')!;
    expect(
      ShopService.allOffers.where((o) => o.id == scene.offerId),
      hasLength(1),
    );
    expect(await shopSceneOpen(db.settingsDao, 'dunes'), isFalse);
    // Not enough gold: nothing taken, nothing opened.
    expect(await shop.purchase(scene.offerId), isFalse);
    expect(await shopSceneOpen(db.settingsDao, 'dunes'), isFalse);

    await db.settingsDao.setSetting('wallet_gold', '600');
    expect(await shop.purchase(scene.offerId), isTrue);
    expect((await db.currencyDao.getAllCurrencies())['gold'], 100);
    expect(await shopSceneOpen(db.settingsDao, 'dunes'), isTrue);
    expect(await ownedShopScenes(db.settingsDao), {'dunes'});
    // Once only.
    expect(shop.canPurchase(scene.offerId), isFalse);
    expect(await shop.purchase(scene.offerId), isFalse);
    expect((await db.currencyDao.getAllCurrencies())['gold'], 100);
  });
}
