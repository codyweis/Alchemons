// ALCHEMY FOR TWO, played by hand on one phone: each move dragged onto a
// circle and fused, the turn going over, the other player's creatures not
// to be picked up, the word made going up into its own word, and AGAIN
// putting the other player first.

import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/heart_puzzle/alchemy_duel_boards.dart';
import 'package:alchemons/games/heart_puzzle/alchemy_duel_match.dart';
import 'package:alchemons/games/heart_puzzle/alchemy_duel_rules.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/heart_puzzle/altar_play_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A match where the first side plays perfectly and the second loses the
/// first time it can: the moves, and how it ends.
(List<DuelStep>, DuelEnd) _line(DuelBoard b) {
  final solver = DuelSolver(b);
  var p = duelStart(b);
  final out = <DuelStep>[];
  while (duelOutcome(b, p) == null) {
    final g = solver.graded(p);
    final win = g.where((x) => x.$2 == 1).firstOrNull;
    final step = win?.$1 ??
        (p.toMove == 0 ? g.firstWhere((x) => x.$2 == 0).$1 : g.first.$1);
    out.add(step);
    p = step.next;
  }
  return (out, duelOutcome(b, p)!);
}

void main() {
  testWidgets('a match for two, move by move, to PLAYER 1 WINS', (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    // A board where that line is a win, with no turn passing on the way.
    late int number;
    late List<DuelStep> moves;
    for (var n = 1; n <= kDuelBoards.length; n++) {
      final (line, end) = _line(kDuelBoards[n - 1]);
      if (end == DuelEnd.firstWins && line.every((s) => !s.pass)) {
        number = n;
        moves = line;
        break;
      }
    }

    late CreatureCatalog catalog;
    await tester.runAsync(() async {
      final json =
          jsonDecode(File('assets/data/alchemons_creatures.json').readAsStringSync())
              as Map<String, dynamic>;
      catalog = CreatureCatalog.fromList([
        for (final c in json['creatures'] as List)
          Creature.fromJson(c as Map<String, dynamic>),
      ]);
    });

    Future<void> settle([int frames = 6]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CreatureCatalog>.value(value: catalog),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
        ],
        child: MaterialApp(
          home: AltarPlayScreen.duel(duel: DuelMatch(number: number)),
        ),
      ),
    );
    await settle(12);
    var s = tester.state<AltarPlayScreenState>(find.byType(AltarPlayScreen));

    Future<void> drag(String id, Offset to) async {
      final from = s.debugUnit(id);
      final g = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 16));
      for (var k = 1; k <= 8; k++) {
        await g.moveTo(Offset.lerp(from, to, k / 8)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await settle(8);
    }

    Future<void> playOut() async {
      for (var i = 0; i < 600 && s.debugBusy; i++) {
        await settle(1);
      }
      await settle(8);
    }

    expect(find.text('PLAYER 1 TO MOVE'), findsOneWidget);
    expect(s.debugNote, contains('First to make their word wins'));
    // PLAYER 2's creatures can't be picked up on PLAYER 1's turn.
    final theirs = s.debugDuel!.stage.units.firstWhere(
      (u) => s.debugDuel!.sideOf(u) == 1,
    );
    await drag(theirs.id, s.debugSeat(0, 0));
    expect(s.debugNote, "That one is PLAYER 2's.");
    expect(s.debugDuel!.turns, 0);

    for (final step in moves) {
      final seat = s.debugDuel!.toMove;
      expect(s.debugShownSeat, seat);
      if (step.split != null) {
        await drag(step.split!.id, s.debugSplit);
        await tester.tapAt(s.debugSplitButton);
      } else {
        final (a, b) = step.pair!;
        await drag(a.id, s.debugSeat(step.altar, 0));
        await drag(b.id, s.debugSeat(step.altar, 1));
        await tester.tapAt(s.debugFuse(step.altar));
      }
      await settle(4);
      expect(s.debugDuel!.board, step.next.board, reason: step.name);
      await playOut();
      if (!s.debugWon) {
        expect(s.debugShownSeat, 1 - seat, reason: 'the turn goes over');
        expect(find.text('PLAYER ${2 - seat} TO MOVE'), findsOneWidget);
      }
    }
    expect(s.debugWon, isTrue);
    await settle(40);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
    expect(find.text('PLAYER 2 moves first next.'), findsOneWidget);

    await tester.tap(find.text('AGAIN'));
    await settle(30);
    s = tester.state<AltarPlayScreenState>(find.byType(AltarPlayScreen));
    expect(s.debugDuel!.turns, 0);
    // PLAYER 2 sits first now: their creatures are the first side's.
    expect(s.widget.duel!.firstPlayer, 1);
    expect(s.widget.duel!.wins, [1, 0]);

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
