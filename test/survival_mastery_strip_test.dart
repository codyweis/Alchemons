// The survival lobby's MASTERY strip: every family's points against its next
// node, the team's families lit, and a tap into that family's tree.
//
//   flutter test test/survival_mastery_strip_test.dart

import 'package:alchemons/games/cosmic_survival/cosmic_survival_base_command_screen.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'survival_lobby_harness.dart';

void main() {
  setUpAll(loadLobbyFonts);

  String points(WidgetTester tester, CreatureFamily family) => tester
      .widget<Text>(
        find.byKey(ValueKey('survival.mastery.${family.name}.points')),
      )
      .textSpan!
      .toPlainText();

  Finder cell(CreatureFamily family) =>
      find.byKey(ValueKey('survival.mastery.${family.name}'));

  bool lit(WidgetTester tester, CreatureFamily family) =>
      tester
              .widget<CustomPaint>(
                find
                    .descendant(
                      of: cell(family),
                      matching: find.byType(CustomPaint),
                    )
                    .first,
              )
              .foregroundPainter
          is BracketFramePainter;

  testWidgets('shows every family\'s points toward its next node, the '
      'team\'s lit', (tester) async {
    tester.view.physicalSize = kLobbyPhysical;
    tester.view.devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);
    // The mid-game save: Let bought three tiers of Bombardment from 260 (10
    // left, the 300 capstone next) and Pip two of Salvo from 120 (20 left,
    // 150 next). Nobody else has anything: 0 toward a first node of 25.
    final save = await LobbySave.create(tester, team: const ['own-1', 'own-3']);
    await tester.pumpWidget(save.app());
    await settleLobby(tester, 10);

    for (final family in CreatureFamily.values) {
      expect(cell(family), findsOneWidget, reason: family.name);
    }
    expect(points(tester, CreatureFamily.let), '10 / 300');
    expect(points(tester, CreatureFamily.pip), '20 / 150');
    expect(points(tester, CreatureFamily.horn), '0 / 25');
    expect(points(tester, CreatureFamily.mystic), '0 / 25');

    // Waterlet and Poisonhorn are the team.
    expect(lit(tester, CreatureFamily.let), isTrue);
    expect(lit(tester, CreatureFamily.horn), isTrue);
    expect(lit(tester, CreatureFamily.pip), isFalse);

    // A run's points arrive: the strip follows.
    await tester.runAsync(
      () => save.mastery.addPoints(const {CreatureFamily.horn: 40}),
    );
    await tester.pump();
    expect(points(tester, CreatureFamily.horn), '40 / 25');

    await save.dispose(tester);
  });

  testWidgets('a tap opens Base Command on Mastery, on that family', (
    tester,
  ) async {
    tester.view.physicalSize = kLobbyPhysical;
    tester.view.devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);
    final save = await LobbySave.create(tester, team: kLobbyTeam);
    await tester.pumpWidget(save.app());
    await settleLobby(tester, 10);

    await tester.ensureVisible(cell(CreatureFamily.horn));
    await tester.pump();
    await tester.tap(cell(CreatureFamily.horn));
    await settleLobby(tester, 20);

    final screen = tester.widget<CosmicSurvivalBaseCommandScreen>(
      find.byType(CosmicSurvivalBaseCommandScreen),
    );
    expect(screen.initialMasteryFamily, CreatureFamily.horn);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('mastery-family-caption')))
          .textSpan!
          .toPlainText(),
      startsWith('HORN'),
    );
    // The family's balance, at the top as well as in the dock.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('mastery-points-top')))
          .textSpan!
          .toPlainText(),
      '0 MASTERY',
    );
    expect(tester.takeException(), isNull);

    await save.dispose(tester);
  });

  testWidgets('fits the Fold\'s 344-wide cover screen at 1.3x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(344 * 3, 882 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final save = await LobbySave.create(tester, team: kLobbyTeam);
    await tester.pumpWidget(save.app());
    await settleLobby(tester, 10);

    await tester.ensureVisible(cell(CreatureFamily.mystic));
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final family in CreatureFamily.values) {
      final rect = tester.getRect(cell(family));
      expect(rect.left, greaterThanOrEqualTo(16), reason: family.name);
      expect(
        rect.right,
        lessThanOrEqualTo(344 - 16 + 0.5),
        reason: family.name,
      );
      // Nothing inside a cell is clipped or squeezed off its edge.
      final text = find.descendant(
        of: cell(family),
        matching: find.byType(RichText),
      );
      for (final element in text.evaluate()) {
        final box = element.renderObject! as RenderParagraph;
        expect(box.didExceedMaxLines, isFalse, reason: family.name);
      }
    }

    await save.dispose(tester);
  });
}
