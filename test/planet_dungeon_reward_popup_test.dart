// Layout regression tests for the End Run reward popup. The Star-3 choice
// row once stretched into an unbounded Column ("BoxConstraints forces an
// infinite height"), which broke the ENTIRE popup the first time a guardian
// reward was claimed — these pump every star combination on a phone-sized
// surface and require zero layout exceptions.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_reward_popup.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlchemonsDatabase db;

  setUp(() {
    db = AlchemonsDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpPopup(WidgetTester tester, List<int> stars) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              DungeonRewardPopup(
                element: 'Fire',
                stars: stars,
                db: db,
                onContinue: () {},
              ),
            ],
          ),
        ),
      ),
    );
    // Let the intro animation + async grants settle.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  testWidgets('stars 1+2 popup lays out cleanly', (tester) async {
    await pumpPopup(tester, const [0, 1]);
  });

  testWidgets('star 3 popup (relic + choice cards) lays out cleanly', (
    tester,
  ) async {
    await pumpPopup(tester, const [2]);
    // The three choice cards are on screen and tappable.
    expect(find.text('25 Gold'), findsOneWidget);
    expect(find.text('10 Powerups'), findsOneWidget);
    expect(find.text('10 Fusion Extractors'), findsOneWidget);
    // Highlight then confirm a choice — still no layout exceptions.
    await tester.tap(find.text('25 Gold'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('25 Gold'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('full 3-star popup lays out cleanly', (tester) async {
    await pumpPopup(tester, const [0, 1, 2]);
  });
}
