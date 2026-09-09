import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/progress_reset_service.dart';
import 'package:alchemons/services/save_generation_service.dart';
import 'package:alchemons/services/save_transfer_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AlchemonsDatabase db;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AlchemonsDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  test(
    'fresh game restores all purchased gold and preserves preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        'account.device_id.v1': 'device',
        'iap.pending_redeems.v1': '[]',
        'notif.extractions.enabled': false,
        'visual.cinematic_quality': 'simple',
        'campaign.progress': 12,
        'account.pending_transfer_code': 'retired',
      });
      await db.currencyDao.creditPurchasedGold(1000);
      await db.currencyDao.spendGold(700);
      await db.settingsDao.setSetting('theme_mode', 'light');
      await db.settingsDao.setSetting('audio.music_enabled', '0');
      await db.settingsDao.setSetting('campaign.progress', '12');
      await db.inventoryDao.addItemQty('test.old_item', 4);
      await ProgressResetService(db).applyLocalReset(
        operationId: 'reset-one',
        goldAmount: 1000,
        generation: 1,
        uid: 'buyer',
      );
      expect(await db.currencyDao.getGoldBalance(), 1005);
      expect(await db.currencyDao.getPurchasedGoldOutstanding(), 1000);
      expect(await db.inventoryDao.getItemQty('test.old_item'), 0);
      expect(await db.settingsDao.getSetting('campaign.progress'), isNull);
      expect(await db.settingsDao.getSetting('theme_mode'), 'light');
      expect(await db.settingsDao.getSetting('audio.music_enabled'), '0');
      expect(
        await db.settingsDao.getSetting(ProgressResetService.onboardingKey),
        '1',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('account.device_id.v1'), 'device');
      expect(prefs.getString('iap.pending_redeems.v1'), '[]');
      expect(prefs.getBool('notif.extractions.enabled'), false);
      expect(prefs.containsKey('campaign.progress'), false);
      expect(prefs.containsKey('account.pending_transfer_code'), false);
    },
  );

  test(
    'same-operation recovery and a new reset never accumulate gold',
    () async {
      final reset = ProgressResetService(db);
      await reset.applyLocalReset(
        operationId: 'one',
        goldAmount: 1000,
        generation: 1,
      );
      await reset.applyLocalReset(
        operationId: 'one',
        goldAmount: 1000,
        generation: 1,
      );
      expect(await db.currencyDao.getGoldBalance(), 1005);
      await db.currencyDao.spendGold(700);
      await reset.applyLocalReset(
        operationId: 'two',
        goldAmount: 1000,
        generation: 2,
      );
      expect(await db.currencyDao.getGoldBalance(), 1005);
      expect(await SaveGenerationService.local(db), 2);
    },
  );

  test(
    'replayed purchase included in reset grants nothing; new purchase grants once',
    () async {
      await ProgressResetService(
        db,
      ).applyLocalReset(operationId: 'one', goldAmount: 1000, generation: 1);
      for (var i = 0; i < 2; i++) {
        await db.currencyDao.settleVerifiedPurchase(
          localKey: 'iap.old',
          amount: 1000,
          includedInReset: true,
        );
        await db.currencyDao.settleVerifiedPurchase(
          localKey: 'iap.new',
          amount: 500,
          includedInReset: false,
        );
      }
      expect(await db.currencyDao.getGoldBalance(), 1505);
      expect(await db.currencyDao.getPurchasedGoldOutstanding(), 1500);
    },
  );

  test(
    'guest reset needs no account or network and retains pending receipts',
    () async {
      SharedPreferences.setMockInitialValues({
        'iap.pending_redeems.v1': '["pending"]',
      });
      final reset = ProgressResetService(
        db,
        invoke: (_, _) async => throw StateError('Network must not be used'),
      );
      await db.currencyDao.addGold(99);
      await reset.request(deviceId: 'guest');
      await reset.resume();
      expect(await db.currencyDao.getGoldBalance(), 5);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'iap.pending_redeems.v1',
        ),
        '["pending"]',
      );
    },
  );

  for (final failure in ['begin', 'finish']) {
    test(
      'lost $failure response resumes the same operation without losing gold',
      () async {
        var failOnce = true;
        final operations = <String>[];
        final reset = ProgressResetService(
          db,
          currentUid: () => 'buyer',
          invoke: (name, request) async {
            operations.add(request['operationId'] as String);
            if (failOnce && name == '${failure}ProgressReset') {
              failOnce = false;
              throw FirebaseFunctionsException(
                code: 'unavailable',
                message: 'Connection lost',
              );
            }
            if (name == 'beginProgressReset') {
              return {...request, 'generation': 1, 'goldAmount': 1000};
            }
            final payload = SaveGenerationService.payload(
              request['saveCode'] as String,
            );
            expect(payload['generation'], 1);
            expect(payload['ownerAccountId'], 'buyer');
            return {'complete': true};
          },
        );
        await reset.request(
          uid: 'buyer',
          deviceId: 'device',
          preview: {'generation': 0, 'goldAmount': 1000},
        );
        await expectLater(
          reset.resume(),
          throwsA(isA<FirebaseFunctionsException>()),
        );
        expect(
          (await SharedPreferences.getInstance()).containsKey(
            ProgressResetService.pendingKey,
          ),
          true,
        );
        await reset.resume();
        expect(operations.toSet(), hasLength(1));
        expect(await db.currencyDao.getGoldBalance(), 1005);
        expect(
          (await SharedPreferences.getInstance()).containsKey(
            ProgressResetService.pendingKey,
          ),
          false,
        );
      },
    );
  }

  test('wrong account cannot resume or wipe the save', () async {
    final reset = ProgressResetService(db, currentUid: () => 'other');
    await db.currencyDao.addGold(100);
    await reset.request(uid: 'buyer', deviceId: 'device');
    await expectLater(reset.resume(), throwsStateError);
    expect(await db.currencyDao.getGoldBalance(), 105);
  });

  test(
    'a refused reset preserves the old game and does not cancel notifications',
    () async {
      var cancelledNotifications = false;
      final reset = ProgressResetService(
        db,
        currentUid: () => 'buyer',
        beforeLocalReset: () async {
          cancelledNotifications = true;
        },
        invoke: (_, _) async => throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Quote changed',
        ),
      );
      await db.currencyDao.addGold(100);
      await reset.request(uid: 'buyer', deviceId: 'device');
      await expectLater(
        reset.resume(),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      expect(await db.currencyDao.getGoldBalance(), 105);
      expect(cancelledNotifications, false);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          ProgressResetService.pendingKey,
        ),
        false,
      );
    },
  );

  test(
    'fresh-game initialization is included in the replacement cloud backup',
    () async {
      final reset = ProgressResetService(
        db,
        currentUid: () => 'buyer',
        prepareFreshSave: () async {
          await db.settingsDao.setSetting('catalog_initialized', '1');
        },
        invoke: (name, request) async {
          if (name == 'beginProgressReset') {
            return {...request, 'generation': 1, 'goldAmount': 0};
          }
          final settings =
              SaveGenerationService.payload(
                    request['saveCode'] as String,
                  )['tables']['settings']
                  as List;
          expect(
            settings.any(
              (row) =>
                  row['key'] == 'catalog_initialized' && row['value'] == '1',
            ),
            true,
          );
          return {'complete': true};
        },
      );
      await reset.request(uid: 'buyer', deviceId: 'device');
      await reset.resume();
      expect(await db.currencyDao.getGoldBalance(), 5);
    },
  );

  test('stale save is rejected before any local data changes', () async {
    final code = await SaveTransferService(
      db,
    ).exportSaveCode(ownerAccountId: 'buyer');
    await db.currencyDao.addGold(42);
    final transfer = SaveTransferService(
      db,
      validateGeneration: (uid, generation) async {
        expect(uid, 'buyer');
        expect(generation, 0);
        throw StateError('Retired save');
      },
    );
    await expectLater(
      transfer.importSaveCode(code, ownerAccountId: 'buyer'),
      throwsStateError,
    );
    expect(await db.currencyDao.getGoldBalance(), 47);
  });

  test(
    'current-generation backup retains generation and reset recovery is device-only',
    () async {
      await ProgressResetService(db).applyLocalReset(
        operationId: 'one',
        goldAmount: 200,
        generation: 2,
        uid: 'buyer',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ProgressResetService.pendingKey,
        'device-private-marker',
      );
      final code = await SaveTransferService(
        db,
      ).exportSaveCode(ownerAccountId: 'buyer');
      expect(
        (SaveGenerationService.payload(code)['preferences'] as Map).containsKey(
          ProgressResetService.pendingKey,
        ),
        false,
      );
      final restored = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(restored.close);
      await SaveTransferService(
        restored,
        validateGeneration: (_, generation) async {
          expect(generation, 2);
        },
      ).importSaveCode(code, ownerAccountId: 'buyer');
      expect(await SaveGenerationService.local(restored), 2);
      expect(await restored.currencyDao.getGoldBalance(), 205);
      expect(
        prefs.getString(ProgressResetService.pendingKey),
        'device-private-marker',
      );
    },
  );
}
