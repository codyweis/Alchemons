import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic_survival/components/family_mastery_panel.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late AlchemonsDatabase db;
  late FamilyMasteryService mastery;

  setUp(() async {
    db = AlchemonsDatabase(NativeDatabase.memory());
    mastery = FamilyMasteryService(db);
    await mastery.load();
  });

  tearDown(() async {
    mastery.dispose();
    await db.close();
  });

  Widget buildPanel() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FamilyMasteryService>.value(value: mastery),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: FamilyMasteryPanel(
            silverBalance: 20000,
            goldBalance: 20,
            onCurrencyChanged: () async {},
          ),
        ),
      ),
    );
  }

  testWidgets('opens on Mane with a connected family skill tree', (
    tester,
  ) async {
    await tester.pumpWidget(buildPanel());
    await tester.pumpAndSettle();

    expect(find.text('MANE MASTERY'), findsOneWidget);
    expect(find.text('TWIN FANG'), findsOneWidget);
    expect(find.text('ALL MANES'), findsOneWidget);
    expect(find.byKey(const ValueKey('family-skill-tree')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mastery-node-inspector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mastery-node-mane.assault.honed_pair')),
      findsOneWidget,
    );
  });

  testWidgets('family rail switches to another mastery tree', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mastery-family-pip')));
    await tester.pumpAndSettle();

    expect(find.text('PIP MASTERY'), findsOneWidget);
    expect(find.text('NEEDLEPOINT'), findsOneWidget);
    expect(find.text('ALL PIPS'), findsOneWidget);
  });
}
