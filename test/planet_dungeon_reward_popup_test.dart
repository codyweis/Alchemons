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

  Future<void> pumpPopup(
    WidgetTester tester,
    List<int> stars, {
    List<String> starNames = const [],
    Size logical = const Size(390, 844),
  }) async {
    tester.view.physicalSize = Size(logical.width * 3, logical.height * 3);
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
                starNames: starNames,
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

  // The popup is offered the moment a star banks, mid-run — not at the end of
  // the expedition. It used to say 'EXPEDITION COMPLETE' over '1 star secured
  // this run', which claimed the run was over while the player was still
  // standing in the dungeon, and named nothing they had actually done.
  group('the heading answers "what did I just get?"', () {
    testWidgets('one star names itself and claims nothing about the run', (
      tester,
    ) async {
      await pumpPopup(tester, const [0], starNames: const ['Ember Star']);
      expect(find.text('EMBER STAR'), findsOneWidget);
      expect(find.text('EXPEDITION COMPLETE'), findsNothing);
      expect(find.textContaining('secured this run'), findsNothing);
    });

    testWidgets('several stars fall back to a count', (tester) async {
      // Only reachable when a run ends holding more than one unbanked star,
      // and the count is the useful thing there.
      await pumpPopup(
        tester,
        const [0, 1],
        starNames: const ['Ember Star', 'Ash Star'],
      );
      expect(find.text('STARS SECURED'), findsOneWidget);
      expect(find.text('2 stars secured this run'), findsOneWidget);
    });

    testWidgets('an unnamed star still reads', (tester) async {
      // starNames is optional; a caller that omits it must not render a blank
      // heading where the title should be.
      await pumpPopup(tester, const [0]);
      expect(find.text('STAR SECURED'), findsOneWidget);
    });

    testWidgets('a blank name is treated as no name, not an empty title', (
      tester,
    ) async {
      await pumpPopup(tester, const [0], starNames: const ['   ']);
      expect(find.text('STAR SECURED'), findsOneWidget);
    });
  });

  group('the design of the choice row', () {
    testWidgets('it fits a small phone without overflowing', (tester) async {
      // The panel was pinned at 400 logical points wide. A 412pt phone left
      // six points of air each side; a 375pt one ran off the screen.
      await pumpPopup(tester, const [2], logical: const Size(320, 640));
      expect(tester.takeException(), isNull);
      final panel = tester.getSize(
        find.byType(DungeonRewardPopup),
      );
      expect(panel.width, lessThanOrEqualTo(320));
    });

    testWidgets('the heading asks for a choice instead of repeating the star',
        (tester) async {
      // "STAR 3" sat directly under a title that already named the star in
      // inch-high letters, beside a cyan "CONFIRM BELOW" pointing at a button
      // that says the same thing in its own words.
      await pumpPopup(tester, const [2], starNames: const ['Pyre Star']);
      expect(find.text('CHOOSE YOUR REWARD'), findsOneWidget);
      expect(find.text('STAR 3'), findsNothing);
      expect(find.text('CONFIRM BELOW'), findsNothing);
      expect(find.text('PICK ONE'), findsNothing);
    });

    testWidgets('a granted star still says which star it was', (tester) async {
      // The heading only changes for the block that needs a decision; a
      // multi-star claim still has to label its lists.
      await pumpPopup(tester, const [0, 1]);
      expect(find.text('STAR 1'), findsOneWidget);
      expect(find.text('STAR 2'), findsOneWidget);
      expect(find.text('CHOOSE YOUR REWARD'), findsNothing);
    });

    testWidgets('the three cards are one row, at one height', (tester) async {
      // "10 Fusion Extractors" wraps and the other two titles do not, so the
      // card contents used to sit at three different heights.
      await pumpPopup(tester, const [2]);
      final cards = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .length;
      expect(cards, greaterThanOrEqualTo(3));
      final boxes = [
        for (final t in ['25 Gold', '10 Powerups', '10 Fusion Extractors'])
          tester.getRect(find.text(t)),
      ];
      for (final b in boxes.skip(1)) {
        expect(
          (b.top - boxes.first.top).abs(),
          lessThan(1.0),
          reason: 'card titles must start on the same line: $boxes',
        );
      }
    });
  });
}
