import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/save_generation_service.dart';
import 'package:alchemons/services/save_transfer_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A game on a device belongs to one account. Without that, signing into (or
/// creating) a second account let it back up the first account's game, gold
/// included, as its own: one purchase, any number of accounts.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AlchemonsDatabase freshDb() {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  group('claimFor', () {
    test('ties a guest game to the first account that claims it', () async {
      final db = freshDb();
      expect(await SaveGenerationService.owner(db), isNull);

      await SaveGenerationService.claimFor(db, 'account-a');

      expect(await SaveGenerationService.owner(db), 'account-a');
    });

    test('lets the owner claim its own game again', () async {
      final db = freshDb();
      await SaveGenerationService.claimFor(db, 'account-a');

      await SaveGenerationService.claimFor(db, 'account-a');

      expect(await SaveGenerationService.owner(db), 'account-a');
    });

    test('refuses another account and leaves the owner alone', () async {
      final db = freshDb();
      await SaveGenerationService.claimFor(db, 'account-a');

      await expectLater(
        SaveGenerationService.claimFor(db, 'account-b'),
        throwsA(isA<SaveOwnershipException>()),
      );
      expect(await SaveGenerationService.owner(db), 'account-a');
    });

    test('a new game is a guest game again, free for any account', () async {
      final db = freshDb();
      await SaveGenerationService.claimFor(db, 'account-a');

      await db.resetToNewGame();

      expect(await SaveGenerationService.owner(db), isNull);
      await SaveGenerationService.claimFor(db, 'account-b');
      expect(await SaveGenerationService.owner(db), 'account-b');
    });
  });

  group('backups', () {
    test('another account cannot back up this account\'s game', () async {
      final db = freshDb();
      await db.currencyDao.creditPurchasedGold(500);
      await SaveTransferService(db).exportSaveCode(ownerAccountId: 'buyer');

      await expectLater(
        SaveTransferService(db).exportSaveCode(ownerAccountId: 'second'),
        throwsA(isA<SaveTransferException>()),
      );
    });

    test('backing up a guest game makes it that account\'s', () async {
      final db = freshDb();

      await SaveTransferService(db).exportSaveCode(ownerAccountId: 'buyer');

      expect(await SaveGenerationService.owner(db), 'buyer');
    });

    test('restoring a backup hands the device to that account', () async {
      final source = freshDb();
      final code = await SaveTransferService(
        source,
      ).exportSaveCode(ownerAccountId: 'account-b');

      // This device was playing account A's game; account B restores its own
      // backup over it.
      final device = freshDb();
      await SaveGenerationService.claimFor(device, 'account-a');
      await SaveTransferService(
        device,
        validateGeneration: (_, _) async {},
      ).importSaveCode(code, ownerAccountId: 'account-b');

      expect(await SaveGenerationService.owner(device), 'account-b');
    });

    test('a backup can only be restored into the account it belongs to', () async {
      final source = freshDb();
      final code = await SaveTransferService(
        source,
      ).exportSaveCode(ownerAccountId: 'buyer');

      await expectLater(
        SaveTransferService(
          freshDb(),
          validateGeneration: (_, _) async {},
        ).importSaveCode(code, ownerAccountId: 'second'),
        throwsA(isA<SaveTransferException>()),
      );
    });
  });
}
