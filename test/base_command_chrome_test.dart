import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_base_command_screen.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
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

  Future<void> pumpScreen(
    WidgetTester tester, {
    double width = 412,
    double height = 915,
    CreatureFamily? family,
  }) async {
    tester.view.physicalSize = Size(width * 3, height * 3);
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
        child: MaterialApp(
          home: CosmicSurvivalBaseCommandScreen(
            hideAbilities: true,
            initialMasteryFamily: family,
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  String caption(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('mastery-family-caption')))
      .textSpan!
      .toPlainText();

  testWidgets('Mastery is the first tab', (tester) async {
    await pumpScreen(tester);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect((tabBar.tabs.first as Tab).text, 'MASTERY');
    expect(caption(tester), startsWith('MANE'));
  });

  testWidgets('opens on the family it was asked for', (tester) async {
    await pumpScreen(tester, family: CreatureFamily.let);
    expect(caption(tester), startsWith('LET'));
  });

  // The whole tree, capstones included, sits between the header and the
  // dock on a phone and on both faces of a Fold, so nothing has to scroll.
  for (final (name, size) in const [
    ('phone', Size(412, 915)),
    ('Fold cover', Size(357, 850)),
    ('Fold inner', Size(716, 800)),
  ]) {
    testWidgets('every family\'s whole tree fits on the $name', (tester) async {
      await pumpScreen(tester, width: size.width, height: size.height);
      final dockTop = tester
          .getTopLeft(find.byKey(const ValueKey('mastery-node-inspector')))
          .dy;
      for (final tree in kFamilyMasteryTrees) {
        await tester.tap(
          find.byKey(ValueKey('mastery-family-${tree.family.name}')),
        );
        await tester.pumpAndSettle();
        for (final path in tree.paths) {
          final capstone = tester.getRect(
            find.byKey(ValueKey('mastery-node-${path.nodes.last.id}')),
          );
          expect(
            capstone.bottom,
            lessThanOrEqualTo(dockTop),
            reason: '${path.nodes.last.id} on the $name',
          );
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
}
