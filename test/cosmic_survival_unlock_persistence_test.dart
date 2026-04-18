import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/save_transfer_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AlchemonsDatabase db;
  var dbClosed = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AlchemonsDatabase(NativeDatabase.memory());
    dbClosed = false;
  });

  tearDown(() async {
    if (!dbClosed) {
      await db.close();
    }
  });

  group('cosmic survival unlock persistence', () {
    test('accepts legacy truthy discovery values', () async {
      await db.settingsDao.setSetting(
        'cosmic_survival_portal_discovered',
        'true',
      );

      expect(await db.settingsDao.isCosmicSurvivalPortalDiscovered(), isTrue);
    });

    test(
      'recovers missing discovery flag from cosmic survival progress',
      () async {
        await db.settingsDao.setSetting('cosmic_survival_best_wave', '4');

        expect(await db.settingsDao.isCosmicSurvivalPortalDiscovered(), isTrue);

        await db.settingsDao.reconcileCosmicSurvivalPortalDiscovery();
        expect(
          await db.settingsDao.getSetting('cosmic_survival_portal_discovered'),
          '1',
        );
      },
    );

    test(
      'recovers missing discovery flag from legacy survival high score',
      () async {
        await db.saveSurvivalHighScore(wave: 3, score: 900, timeMs: 120000);

        expect(await db.settingsDao.isCosmicSurvivalPortalDiscovered(), isTrue);

        await db.settingsDao.reconcileCosmicSurvivalPortalDiscovery();
        expect(
          await db.settingsDao.getSetting('cosmic_survival_portal_discovered'),
          '1',
        );
      },
    );

    test('normalizes the recovered flag through save transfer', () async {
      await db.settingsDao.setSetting('cosmic_survival_best_wave', '7');

      final saveCode = await SaveTransferService(
        db,
      ).exportSaveCode(ownerAccountId: 'account-a');

      await db.close();
      dbClosed = true;

      final restoredDb = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(restoredDb.close);

      await SaveTransferService(
        restoredDb,
      ).importSaveCode(saveCode, ownerAccountId: 'account-a');

      expect(
        await restoredDb.settingsDao.getSetting(
          'cosmic_survival_portal_discovered',
        ),
        '1',
      );
    });
  });
}
