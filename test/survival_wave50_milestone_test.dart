import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AlchemonsDatabase db;
  late ShopService shop;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AlchemonsDatabase(NativeDatabase.memory());
    shop = ShopService(db, ConstellationEffectsService(db), FactionService(db));
    await pumpEventQueue();
  });

  tearDown(() async {
    shop.dispose();
    await db.close();
  });

  test(
    'wave 50 bundle grants once and unlocks additional crown copies',
    () async {
      final first = await shop.grantWave50Milestone(
        portalKey: InvKeys.portalKeyVolcanic,
      );

      expect(first, isTrue);
      expect(await db.inventoryDao.getItemQty(InvKeys.potentialSoul), 1);
      expect(await db.inventoryDao.getItemQty(InvKeys.portalKeyVolcanic), 1);
      expect(
        await db.inventoryDao.getItemQty(InvKeys.alchemyWavebreakerCrown),
        1,
      );
      expect(
        shop.getAlchemyEffectOffers().map((offer) => offer.id),
        contains(ShopService.wavebreakerCrownEffectOfferId),
      );

      final second = await shop.grantWave50Milestone(
        portalKey: InvKeys.portalKeyArcane,
      );

      expect(second, isFalse);
      expect(await db.inventoryDao.getItemQty(InvKeys.potentialSoul), 1);
      expect(await db.inventoryDao.getItemQty(InvKeys.portalKeyArcane), 0);
      expect(
        await db.inventoryDao.getItemQty(InvKeys.alchemyWavebreakerCrown),
        1,
      );
    },
  );

  test('shop purchase grants Potential Souls and charges Gold', () async {
    final startingGold = await db.currencyDao.getGoldBalance();
    await db.currencyDao.addGold(300);

    final purchased = await shop.purchase(
      ShopService.potentialSoulOfferId,
      qty: 2,
    );

    expect(purchased, isTrue);
    expect(await db.currencyDao.getGoldBalance(), startingGold);
    expect(await db.inventoryDao.getItemQty(InvKeys.potentialSoul), 2);
    expect(shop.inventoryCountForOffer(ShopService.potentialSoulOfferId), 2);
  });
}
