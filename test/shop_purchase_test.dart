import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
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
}
