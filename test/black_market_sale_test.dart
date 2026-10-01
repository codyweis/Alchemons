import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/black_market_screen.dart';
import 'package:alchemons/services/black_market_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('coins are written with thousands separators', () {
    expect(formatCoins(0), '0');
    expect(formatCoins(999), '999');
    expect(formatCoins(1000), '1,000');
    expect(formatCoins(1234567), '1,234,567');
    expect(formatCoins(-4500), '-4,500');
  });

  testWidgets('selling half the volcanic resources pays two-for-a-silver', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AlchemonsDatabase(NativeDatabase.memory());
    late ConstellationEffectsService constellations;
    late BlackMarketService market;
    late int silverBefore;
    await tester.runAsync(() async {
      await db.constellationDao.unlockSkill('extraction_resource_alchemy', 0);
      await db.currencyDao.addResource('res_volcanic', 1240);
      silverBefore = (await db.currencyDao.getAllCurrencies())['silver'] ?? 0;
      constellations = ConstellationEffectsService(db);
      market = BlackMarketService(
        db,
        constellations,
        CreatureCatalog.fromList(const []),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    Future<void> settle([int frames = 6]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
            ChangeNotifierProvider<ConstellationEffectsService>.value(
              value: constellations,
            ),
            ChangeNotifierProvider<BlackMarketService>.value(value: market),
          ],
          child: const MaterialApp(
            home: BlackMarketScreen(accent: Color(0xFFFFB74D)),
          ),
        ),
      );
      await settle();

      await tester.tap(find.text('SELL'));
      await settle();
      // Half of the volcanic: 620 of 1,240, which fetches 310.
      await tester.tap(find.text('½').first);
      await settle();
      expect(find.text('620 of 1,240'), findsOneWidget);

      await tester.tap(find.text('MAKE THE TRADE'));
      await settle();
      await tester.tap(find.text('SELL').last);
      await settle(10);

      late Map<String, int> balances;
      late Map<String, int> currencies;
      await tester.runAsync(() async {
        balances = await db.currencyDao.watchResourceBalances().first;
        currencies = await db.currencyDao.getAllCurrencies();
      });
      expect(balances['res_volcanic'], 620);
      expect(currencies['silver'], silverBefore + 310);
      // The message used to be built after the table was cleared: "for 0".
      await settle(4);
      // The notification sets its message in capitals.
      expect(find.textContaining('FOR 310 SILVER'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      market.dispose();
      await tester.runAsync(db.close);
    }
  });
}
