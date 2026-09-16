import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_base_command_screen.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AlchemonsDatabase db;
  late FamilyMasteryService mastery;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AlchemonsDatabase(NativeDatabase.memory());
    mastery = FamilyMasteryService(db);
    await mastery.load();
  });

  tearDown(() async {
    mastery.dispose();
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester, {double height = 915}) async {
    tester.view.physicalSize = Size(412 * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          ChangeNotifierProvider<FamilyMasteryService>.value(value: mastery),
          ChangeNotifierProvider(create: (_) => SurvivalUpgradeService(db)),
          ChangeNotifierProvider(
            create: (_) => ShopService(
              db,
              ConstellationEffectsService(db),
              FactionService(db),
              TimedBoostService(db.settingsDao),
            ),
          ),
        ],
        child: const MaterialApp(
          home: CosmicSurvivalBaseCommandScreen(hideAbilities: true),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  // Drag near the top of the tree's visible area: the tree is taller than its
  // viewport, so its centre can sit under the upgrade dock.
  Future<void> dragTree(WidgetTester tester, double dy) async {
    final viewport = tester.getRect(
      find
          .ancestor(
            of: find.byKey(const ValueKey('family-skill-tree')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.dragFrom(
      viewport.topCenter + const Offset(40, 30),
      Offset(0, dy),
    );
    await tester.pumpAndSettle();
  }

  double heightOf(WidgetTester tester, String key) =>
      tester.getSize(find.byKey(ValueKey(key))).height;

  testWidgets('Mastery is the first tab', (tester) async {
    await pumpScreen(tester);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect((tabBar.tabs.first as Tab).text, 'MASTERY');
    expect(find.text('MANE MASTERY'), findsOneWidget);
  });

  testWidgets(
    'scrolling down swaps the header for a balance bar; scrolling up restores it',
    (tester) async {
      await pumpScreen(tester);

      expect(heightOf(tester, 'base-command-chrome'), greaterThan(0));
      expect(heightOf(tester, 'base-command-balance-bar'), 0);
      await dragTree(tester, -120);

      expect(heightOf(tester, 'base-command-chrome'), 0);
      expect(heightOf(tester, 'base-command-balance-bar'), 44);
      // The family selector tucks away too; the tree crown stays docked.
      expect(heightOf(tester, 'mastery-family-selector'), 0);
      expect(find.text('MANE MASTERY'), findsOneWidget);
      expect(find.text('TWIN FANG'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('family-mastery-crown')))
            .dy,
        lessThan(120),
      );

      await dragTree(tester, 120);

      expect(heightOf(tester, 'base-command-chrome'), greaterThan(0));
      expect(heightOf(tester, 'base-command-balance-bar'), 0);
      expect(heightOf(tester, 'mastery-family-selector'), greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('scrolling partway back up keeps the header hidden', (
    tester,
  ) async {
    // A shorter screen gives the tree plenty of scroll room.
    await pumpScreen(tester, height: 760);

    await dragTree(tester, -140);
    expect(heightOf(tester, 'base-command-chrome'), 0);

    await dragTree(tester, 50);
    expect(heightOf(tester, 'base-command-chrome'), 0);
    expect(heightOf(tester, 'base-command-balance-bar'), 44);

    await dragTree(tester, 300);
    expect(heightOf(tester, 'base-command-chrome'), greaterThan(0));
    expect(heightOf(tester, 'base-command-balance-bar'), 0);
  });

  testWidgets('switching tabs brings the header back', (tester) async {
    await pumpScreen(tester);

    await dragTree(tester, -120);
    expect(heightOf(tester, 'base-command-chrome'), 0);

    // Swipe the pager horizontally to the next tab.
    await tester.fling(find.byType(TabBarView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(heightOf(tester, 'base-command-chrome'), greaterThan(0));
  });
}
