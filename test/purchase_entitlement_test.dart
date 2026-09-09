import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/mobile_store_service.dart';
import 'package:alchemons/services/save_transfer_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('purchased gold tracking', () {
    test('credited purchase raises both the balance and the outstanding '
        'counter', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final start = await db.currencyDao.getGoldBalance();
      await db.currencyDao.addGold(40);
      await db.currencyDao.creditPurchasedGold(500);

      expect(await db.currencyDao.getGoldBalance(), start + 540);
      expect(await db.currencyDao.getPurchasedGoldOutstanding(), 500);
    });

    test('gameplay gold does not count as purchased', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final start = await db.currencyDao.getGoldBalance();
      await db.currencyDao.addGold(120);

      expect(await db.currencyDao.getGoldBalance(), start + 120);
      expect(await db.currencyDao.getPurchasedGoldOutstanding(), 0);
    });

    test('a non-positive credit is ignored', () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final start = await db.currencyDao.getGoldBalance();
      await db.currencyDao.creditPurchasedGold(0);
      await db.currencyDao.creditPurchasedGold(-75);

      expect(await db.currencyDao.getGoldBalance(), start);
      expect(await db.currencyDao.getPurchasedGoldOutstanding(), 0);
    });

    test('the outstanding counter survives a backup and restore, so a '
        'restore can reconcile it against the account entitlement', () async {
      final source = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      final start = await source.currencyDao.getGoldBalance();
      await source.currencyDao.creditPurchasedGold(200);

      final saveCode = await SaveTransferService(
        source,
      ).exportSaveCode(ownerAccountId: 'buyer');

      final restored = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(restored.close);
      await SaveTransferService(
        restored,
        validateGeneration: (_, _) async {},
      ).importSaveCode(saveCode, ownerAccountId: 'buyer');

      expect(await restored.currencyDao.getGoldBalance(), start + 200);
      expect(await restored.currencyDao.getPurchasedGoldOutstanding(), 200);
    });
  });

  group('pending purchase queue', () {
    test('is left out of an exported save', () async {
      SharedPreferences.setMockInitialValues({
        MobileStoreService.pendingRedeemsKey: '[{"productId":"secret"}]',
        'some.game.preference': 7,
      });

      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final saveCode = await SaveTransferService(
        db,
      ).exportSaveCode(ownerAccountId: 'buyer');

      expect(saveCode, isNot(contains(MobileStoreService.pendingRedeemsKey)));
    });

    test('survives a restore instead of being wiped with the rest of the '
        'preferences', () async {
      final source = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      SharedPreferences.setMockInitialValues({'some.game.preference': 7});
      final saveCode = await SaveTransferService(
        source,
      ).exportSaveCode(ownerAccountId: 'buyer');

      // The receiving device is mid-purchase: it has paid for something the
      // server has not confirmed yet. Restoring a save must not lose it.
      const queued = '[{"productId":"alchemons_gold_vault"}]';
      SharedPreferences.setMockInitialValues({
        MobileStoreService.pendingRedeemsKey: queued,
      });

      final restored = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(restored.close);
      await SaveTransferService(
        restored,
        validateGeneration: (_, _) async {},
      ).importSaveCode(saveCode, ownerAccountId: 'buyer');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MobileStoreService.pendingRedeemsKey), queued);
      expect(prefs.getInt('some.game.preference'), 7);
    });
  });
}
