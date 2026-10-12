// ALCHEMY FOR TWO, proved — the rules for taking turns, and every board
// against what the search kept it for: a draw played perfectly, both words
// the same number of moves away, a first move that loses, and two racers
// settling it.

import 'package:alchemons/games/heart_puzzle/alchemy_duel_boards.dart';
import 'package:alchemons/games/heart_puzzle/alchemy_duel_match.dart';
import 'package:alchemons/games/heart_puzzle/alchemy_duel_rules.dart';
import 'package:alchemons/games/heart_puzzle/heart_puzzle_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/alchemy_duel_search.dart' as search;

void main() {
  // Fire + Water → Steam; Air + Fire → Lightning; Earth + Lightning → Crystal.
  const board = DuelBoard(
    goal: 'Steam',
    rival: 'Crystal',
    first: ['Water'],
    second: ['Air', 'Earth'],
    middle: ['Fire'],
    columns: [[]],
  );

  test('each side fuses only its own creatures and the middle\'s', () {
    final p = duelStart(board);
    for (final s in duelSteps(board, p)) {
      final (a, b) = s.pair!;
      for (final u in [a, b]) {
        expect(p.sideOf(u), anyOf(0, kDuelMiddle), reason: s.name);
      }
    }
    final p1 = DuelPosition(p.stage, p.side, turns: 1);
    for (final s in duelSteps(board, p1)) {
      final (a, b) = s.pair!;
      for (final u in [a, b]) {
        expect(p1.sideOf(u), anyOf(1, kDuelMiddle), reason: s.name);
      }
    }
  });

  test('the first to make their word wins, and it stays on the circle', () {
    final p = duelStart(board);
    final steam = duelSteps(
      board,
      p,
    ).firstWhere((s) => s.fusion?.made.el == 'Steam');
    expect(steam.fusion!.rose, isFalse, reason: 'a word made does not rise');
    expect(duelOutcome(board, steam.next), DuelEnd.firstWins);
  });

  test('what a move makes is the mover\'s', () {
    final p = duelStart(board);
    final p1 = DuelPosition(p.stage, p.side, turns: 1);
    final lightning = duelSteps(
      board,
      p1,
    ).firstWhere((s) => s.fusion?.landed.el == 'Lightning');
    final q = lightning.next;
    final made = q.stage.units.firstWhere((u) => u.el == 'Lightning');
    expect(q.sideOf(made), 1);
    expect(q.toMove, 0);
    // The Fire is gone from the middle: the first side has nothing to fuse.
    expect(duelSteps(board, q).single.pass, isTrue);
    final passed = duelSteps(board, q).single.next;
    expect(passed.toMove, 1);
    final crystal = duelSteps(
      board,
      passed,
    ).firstWhere((s) => s.fusion?.made.el == 'Crystal');
    expect(duelOutcome(board, crystal.next), DuelEnd.secondWins);
  });

  test('a split gives both halves to the one who split it', () {
    const b = DuelBoard(
      goal: 'Mud',
      rival: 'Ice',
      first: ['Fire', 'Water'],
      second: ['Air'],
      columns: [[]],
      split: true,
    );
    final p = duelStart(b);
    final steam = duelSteps(
      b,
      p,
    ).firstWhere((s) => s.fusion?.landed.el == 'Steam');
    // The second side can't take the first's Steam apart.
    final p1 = steam.next;
    expect(duelSteps(b, p1).any((s) => s.split != null), isFalse);
    final back = DuelPosition(p1.stage, p1.side, turns: 2);
    final split = duelSteps(b, back).firstWhere((s) => s.split != null);
    for (final u in split.next.stage.units) {
      if (u.el != 'Air') expect(split.next.sideOf(u), 0, reason: u.name);
    }
  });

  test('neither side able to move, or the moves run out, is a draw', () {
    const stuck = DuelBoard(
      goal: 'Steam',
      rival: 'Mud',
      first: ['Air'],
      second: ['Light'],
      columns: [[]],
    );
    expect(duelOutcome(stuck, duelStart(stuck)), DuelEnd.draw);
    final p = duelStart(board);
    final late = DuelPosition(p.stage, p.side, turns: kDuelMoveCap);
    expect(duelOutcome(board, late), DuelEnd.draw);
  });

  test('a rematch swaps who moves first and keeps the score', () {
    const m = DuelMatch(number: 1);
    final won = m.scored(DuelEnd.secondWins);
    expect(won.wins, [0, 1]);
    final again = won.following();
    expect(again.firstPlayer, 1);
    expect(again.playerAt(0), 1, reason: 'PLAYER 2 sits first');
    expect(again.scored(DuelEnd.firstWins).wins, [0, 2]);
    expect(again.following().firstPlayer, 0);
    final last = kDuelSets.first.last;
    expect(DuelMatch(number: last).nextNumber, kDuelSets.first.first);
  });

  test('the sets cover every board, in order', () {
    var n = 1;
    for (final s in kDuelSets) {
      expect(s.first, n);
      expect(s.last, greaterThanOrEqualTo(s.first));
      n = s.last + 1;
    }
    expect(n - 1, kDuelBoards.length);
  });

  for (var i = 0; i < kDuelBoards.length; i++) {
    final b = kDuelBoards[i];
    test('board ${i + 1} (${b.goal} vs ${b.rival}) is fair and worth thinking about', () {
      expect(duelOutcome(b, duelStart(b)), isNull);
      final d0 = search.distanceOf(b, 0), d1 = search.distanceOf(b, 1);
      expect(d0, isNotNull);
      expect(d0, d1, reason: 'both words the same number of moves away');
      expect(d0, greaterThanOrEqualTo(2));
      final p = search.prove(b)!;
      expect(p.value, 0, reason: 'a draw played perfectly');
      expect(search.sharp(p), isTrue, reason:
          'losing ${p.losing}, racers ${p.casual}, shortest ${p.shortest}');
      // No two families breeding has no recipe for ever meet.
      for (final own in [b.first, b.second]) {
        final r = search.explore(
          AltarLevel(
            goal: 'x',
            hand: [...own, ...b.middle],
            columns: b.columns,
            split: b.split,
            species: b.species,
            par: 0,
          ),
        );
        expect(r.cut, isFalse);
        expect(r.nullPairs, isEmpty);
      }
    });
  }
}
