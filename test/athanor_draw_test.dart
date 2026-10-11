// The Athanor's odds and draw are honest (docs/athanor_design.md).
//
// The odds sheet and the draw are one function, so these pin what that
// function promises: the odds of the next pour sum to one over exactly the
// pieces left, a pour never repeats a piece, a batch of N is done in N
// pours, and the piece a pour gives is the one the shown odds put under
// the roll. Then the saved state's decoding, which must never throw.

import 'dart:math';

import 'package:alchemons/models/athanor.dart';
import 'package:flutter_test/flutter_test.dart';

AthanorPiece _piece(String id, AthanorRarity rarity) => AthanorPiece(
  id: id,
  name: id,
  description: 'A test piece.',
  kind: AthanorPieceKind.alchemyEffect,
  rarity: rarity,
  grantRef: 'alchemy.$id',
);

final _batch = AthanorBatch(
  id: 'test',
  name: 'Test',
  description: 'A test batch.',
  pieces: [
    for (var i = 0; i < 5; i++) _piece('c$i', AthanorRarity.common),
    for (var i = 0; i < 3; i++) _piece('r$i', AthanorRarity.rare),
    for (var i = 0; i < 2; i++) _piece('e$i', AthanorRarity.epic),
  ],
  capstone: _piece('cap', AthanorRarity.epic),
);

/// A Random whose nextDouble is [u], for walking the odds by hand.
class _FixedRandom implements Random {
  _FixedRandom(this.u);
  final double u;
  @override
  double nextDouble() => u;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  group('odds of the next pour', () {
    test('sum to 1 over exactly the pieces left, at every step', () {
      final rng = Random(7);
      final drawn = <String>{};
      for (var step = 0; step < _batch.pieces.length; step++) {
        final odds = athanorNextPourOdds(_batch, drawn);
        expect(odds.map((o) => o.$1.id).toSet(), {
          for (final p in _batch.pieces)
            if (!drawn.contains(p.id)) p.id,
        });
        final sum = odds.fold<double>(0, (s, o) => s + o.$2);
        expect(sum, closeTo(1, 1e-9));
        drawn.add(athanorDraw(_batch, drawn, rng)!.id);
      }
    });

    test('weigh common 10, rare 5, epic 2', () {
      final odds = {
        for (final (p, c) in athanorNextPourOdds(_batch, const {})) p.id: c,
      };
      const total = 5 * 10 + 3 * 5 + 2 * 2;
      expect(odds['c0'], closeTo(10 / total, 1e-12));
      expect(odds['r0'], closeTo(5 / total, 1e-12));
      expect(odds['e0'], closeTo(2 / total, 1e-12));
    });

    test('never include the capstone', () {
      final ids = athanorNextPourOdds(_batch, const {}).map((o) => o.$1.id);
      expect(ids, isNot(contains('cap')));
    });

    test('are empty once the batch is done, and the draw is null', () {
      final all = {for (final p in _batch.pieces) p.id};
      expect(athanorNextPourOdds(_batch, all), isEmpty);
      expect(athanorDraw(_batch, all, Random(1)), isNull);
    });
  });

  group('the draw', () {
    test('never repeats, and a batch of N is done in N pours', () {
      for (var seed = 0; seed < 200; seed++) {
        final rng = Random(seed);
        final drawn = <String>{};
        for (var i = 0; i < _batch.pieces.length; i++) {
          final piece = athanorDraw(_batch, drawn, rng);
          expect(piece, isNotNull);
          expect(drawn.add(piece!.id), isTrue, reason: 'seed $seed repeated');
        }
        expect(drawn, hasLength(_batch.pieces.length));
        expect(athanorDraw(_batch, drawn, rng), isNull);
      }
    });

    test('gives the piece the shown odds put under the roll', () {
      final drawn = {'c0', 'r1'};
      final odds = athanorNextPourOdds(_batch, drawn);
      var acc = 0.0;
      for (final (piece, chance) in odds) {
        // Just inside this piece's share of [0, 1).
        final u = acc + chance * 0.5;
        expect(athanorDraw(_batch, drawn, _FixedRandom(u))!.id, piece.id);
        acc += chance;
      }
    });

    test('lands on each piece about as often as its odds say', () {
      const n = 60000;
      final counts = <String, int>{};
      final rng = Random(42);
      for (var i = 0; i < n; i++) {
        final id = athanorDraw(_batch, const {}, rng)!.id;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      for (final (piece, chance) in athanorNextPourOdds(_batch, const {})) {
        expect((counts[piece.id] ?? 0) / n, closeTo(chance, 0.01));
      }
    });
  });

  group('earning tincture', () {
    test('survival pays waves cleared ÷ 5', () {
      expect(athanorSurvivalTincture(0), 0);
      expect(athanorSurvivalTincture(4), 0);
      expect(athanorSurvivalTincture(10), 2);
      expect(athanorSurvivalTincture(30), 6);
      expect(athanorSurvivalTincture(50), 10);
      expect(athanorSurvivalTincture(-3), 0);
    });

    test('raids pay 3 / 5 / 8 by level', () {
      expect(athanorRaidTincture(1), 3);
      expect(athanorRaidTincture(2), 5);
      expect(athanorRaidTincture(3), 8);
    });

    test('a contest win pays twice its level', () {
      expect(athanorContestTincture(1), 2);
      expect(athanorContestTincture(5), 10);
    });

    test('first fire is 30 plus 3 per unpaid claim, back-pay capped at 90', () {
      int fire(int a, int s) =>
          athanorFirstFireTincture(unpaidAchievements: a, unpaidStars: s);
      expect(fire(0, 0), 30);
      expect(fire(4, 3), 30 + 21);
      expect(fire(30, 0), 120);
      expect(fire(25, 26), 120);
      expect(fire(-2, -5), 30);
    });
  });

  group('saved state', () {
    test('round-trips', () {
      final state = const AthanorState(
        capstones: {'a'},
        dailyKey: '2026-10-10',
        firstFire: true,
      ).withDrawn('a', 'a.1').withDrawn('a', 'a.2').withDrawn('b', 'b.1');
      final back = AthanorState.decode(state.encode());
      expect(back.drawnIn('a'), {'a.1', 'a.2'});
      expect(back.drawnIn('b'), {'b.1'});
      expect(back.capstones, {'a'});
      expect(back.dailyKey, '2026-10-10');
      expect(back.firstFire, isTrue);
    });

    test('reads anything it cannot use as a fresh state, never throwing', () {
      for (final raw in [
        null,
        '',
        'not json',
        '{',
        '[]',
        '42',
        'null',
        '"text"',
        '{"drawn": 5, "capstones": "x", "dailyKey": 7, "firstFire": "yes"}',
      ]) {
        final s = AthanorState.decode(raw);
        expect(s.drawn, isEmpty, reason: '$raw');
        expect(s.capstones, isEmpty, reason: '$raw');
        expect(s.dailyKey, isNull, reason: '$raw');
        expect(s.firstFire, isFalse, reason: '$raw');
      }
    });

    test('keeps what it can read beside what it cannot', () {
      final s = AthanorState.decode(
        '{"drawn": {"a": ["a.1", 3, null, ""], "b": "x", "c": []},'
        ' "capstones": ["a", 9], "dailyKey": "2026-10-09", "firstFire": true}',
      );
      expect(s.drawn.keys, ['a']);
      expect(s.drawnIn('a'), {'a.1'});
      expect(s.capstones, {'a'});
      expect(s.dailyKey, '2026-10-09');
      expect(s.firstFire, isTrue);
    });

    test('the day key is the UTC day', () {
      expect(athanorDayKey(DateTime.utc(2026, 10, 10, 23, 59)), '2026-10-10');
      expect(athanorDayKey(DateTime.utc(2026, 10, 11)), '2026-10-11');
    });
  });
}
