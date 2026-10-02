// Precision Runes sold critical-hit chance and no attack ever rolled a crit.
// It is retired; a save that bought levels gets the silver back, once.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlchemonsDatabase db;

  setUp(() => db = AlchemonsDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('the refund is what the levels cost', () {
    expect(SurvivalUpgradeService.retiredCritRefund(0), 0);
    expect(SurvivalUpgradeService.retiredCritRefund(3), 16000);
    expect(SurvivalUpgradeService.retiredCritRefund(5), 86000);
    expect(SurvivalUpgradeService.retiredCritRefund(9), 86000);
  });

  test(
    'a save with Precision Runes is paid back once and forgets them',
    () async {
      final start = await db.currencyDao.getSilverBalance();
      await db.settingsDao.setSetting('survival.guardian.critChance', '3');
      await db.settingsDao.setSetting('survival.guardian.attack', '2');

      final svc = SurvivalUpgradeService(db);
      await svc.load();
      expect(await db.currencyDao.getSilverBalance(), start + 16000);
      expect(
        await db.settingsDao.getSetting('survival.guardian.critChance'),
        isNull,
      );
      // The other Guardian upgrades are untouched.
      expect(svc.state.getGuardianLevel(GuardianUpgrade.attack), 2);
      expect(
        GuardianUpgrade.values.map((u) => u.name),
        isNot(contains('critChance')),
      );

      await svc.load();
      expect(
        await db.currencyDao.getSilverBalance(),
        start + 16000,
        reason: 'paid twice',
      );
    },
  );

  test('a save that never bought them is left alone', () async {
    final start = await db.currencyDao.getSilverBalance();
    await SurvivalUpgradeService(db).load();
    expect(await db.currencyDao.getSilverBalance(), start);
  });
}
