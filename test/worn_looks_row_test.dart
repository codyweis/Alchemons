// The case and trail squares on a creature's details (the Athanor's):
// hidden until one of their kind is owned, they offer only what is owned,
// and what is chosen is that creature's alone.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/models/owned_cosmetics.dart';
import 'package:alchemons/services/cosmetic_wear_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/worn_looks_row.dart';
import 'package:alchemons/widgets/creature_detail/worn_strip.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late AlchemonsDatabase db;
  late CosmeticWearService wear;
  late CreatureInstance a, b;

  setUp(() async {
    db = AlchemonsDatabase(NativeDatabase.memory());
    wear = CosmeticWearService(db);
  });
  tearDown(() => db.close());

  Widget squares(String key, CreatureInstance inst, String name, Color light) =>
      SizedBox(
        key: ValueKey(key),
        height: 44,
        child: Builder(
          builder: (context) => Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in wornLookSquares(
                context,
                instance: inst,
                creatureName: name,
                light: light,
              ))
                SizedBox(width: 72, child: s),
            ],
          ),
        ),
      );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
          ChangeNotifierProvider<CosmeticWearService>.value(value: wear),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            // Squares at the end of a strip, as on the details.
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                squares('a', a, 'Firehorn', const Color(0xFFFF7A1A)),
                const SizedBox(height: 20),
                squares('b', b, 'Waterlet', const Color(0xFF2E8BD0)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // Whether the case square on [creature]'s row shows one worn.
  bool caseLit(WidgetTester tester, String creature) => tester
      .widget<WornSquare>(
        find.descendant(
          of: find.byKey(ValueKey(creature)),
          matching: find.byKey(const ValueKey('worn-case')),
        ),
      )
      .lit;

  Future<void> setUpCreatures(WidgetTester tester) => tester.runAsync(() async {
    await db.creatureDao.insertInstance(
      instanceId: 'a',
      baseId: 'HOR01',
      level: 3,
    );
    await db.creatureDao.insertInstance(
      instanceId: 'b',
      baseId: 'LET02',
      level: 3,
    );
    a = (await db.creatureDao.getInstance('a'))!;
    b = (await db.creatureDao.getInstance('b'))!;
    await wear.load();
  });

  testWidgets('nothing shows until a case or trail is owned', (tester) async {
    await setUpCreatures(tester);
    await pump(tester);
    expect(find.text('CASE'), findsNothing);
    expect(find.text('TRAIL'), findsNothing);
  });

  testWidgets('only owned cases are offered; each creature keeps its own', (
    tester,
  ) async {
    await setUpCreatures(tester);
    await tester.runAsync(() async {
      await OwnedCosmetics.grant(db, AthanorPieceKind.caseStyle, 'gilt');
      await wear.load();
    });
    await pump(tester);
    // Cases owned, no trail: only the case square.
    expect(find.text('CASE'), findsNWidgets(2));
    expect(find.text('TRAIL'), findsNothing);
    expect(caseLit(tester, 'a'), isFalse);
    expect(caseLit(tester, 'b'), isFalse);

    await tester.tap(find.text('CASE').first);
    await tester.pumpAndSettle();
    // The plain case and the one owned; nothing else.
    expect(find.byKey(const ValueKey('look-Plain')), findsOneWidget);
    expect(find.byKey(const ValueKey('look-Gold Case')), findsOneWidget);
    for (final s in CaseStyle.values.where((s) => s != CaseStyle.gilt)) {
      expect(find.byKey(ValueKey('look-${s.title}')), findsNothing);
    }
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('look-Gold Case')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(wear.caseOf('a'), CaseStyle.gilt);
    expect(wear.caseOf('b'), isNull);
    expect(caseLit(tester, 'a'), isTrue);
    expect(caseLit(tester, 'b'), isFalse);

    // It survives a reload.
    final again = CosmeticWearService(db);
    await tester.runAsync(again.load);
    expect(again.caseOf('a'), CaseStyle.gilt);
    expect(again.caseOf('b'), isNull);
  });
}
