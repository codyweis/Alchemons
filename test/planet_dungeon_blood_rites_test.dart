// The Blood Rites' rules, held to the prototype's proofs
// (docs/prototypes/blood_rites/proofs.txt). Every plan here was found by the
// prototype's solver; replaying it against the Dart rules is how the two
// stay the same rules.

import 'package:alchemons/games/planet_dungeon/planet_dungeon_blood_rites.dart';
import 'package:flutter_test/flutter_test.dart';

int _dir(String c) => 'NESW'.indexOf(c);

void main() {
  group('Earth — the tendril floor', () {
    final f = TendrilFloor(kRiteEarthMap);

    test('two plates; impossible as it starts', () {
      expect(f.plates.length, 2);
      expect(tendrilRoute(f, const [0, 0]), isNull);
    });

    test('exactly one of the sixteen plate settings works, and it turns both',
        () {
      final good = <List<int>>[];
      for (var a = 0; a < 4; a++) {
        for (var b = 0; b < 4; b++) {
          if (tendrilRoute(f, [a, b]) != null) good.add([a, b]);
        }
      }
      expect(good, [
        [2, 1],
      ]);
    });

    test('the route replays through the play rules: turn, then lead', () {
      var s = TendrilState.start(f);
      for (var i = 0; i < 2; i++) {
        for (var k = 0; k < [2, 1][i]; k++) {
          final r = tendrilTurn(f, s, i);
          expect(r.ok, isTrue);
          s = r.state!;
        }
      }
      final paths = tendrilRoute(f, s.turns)!;
      for (final e in paths.entries) {
        for (final c in e.value.skip(1)) {
          final r = tendrilExtend(f, s, e.key, c.x, c.y);
          expect(r.ok, isTrue, reason: '${e.key} to $c: ${r.why}');
          s = r.state!;
        }
      }
      expect(tendrilSolved(f, s), isTrue);
    });

    test('a plate will not turn while a tendril lies on it; tendrils never '
        'cross', () {
      var s = TendrilState.start(f);
      // Lead a from its west root along row 1 and down onto the east plate.
      for (final c in const [(1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (7, 2)]) {
        s = tendrilExtend(f, s, 'a', c.$1, c.$2).state!;
      }
      expect(tendrilTurn(f, s, 0).why, 'A tendril lies across that plate.');
      // b from its west root (0,3) up into a's line. (Its other root is the
      // stump on the east plate: a pair is led from whichever root you take.)
      s = tendrilExtend(f, s, 'b', 1, 3, from: (x: 0, y: 3)).state!;
      s = tendrilExtend(f, s, 'b', 1, 2).state!;
      expect(tendrilExtend(f, s, 'b', 1, 1).why, 'Tendrils never cross.');
      // Pulling a back off the plate frees it again.
      s = tendrilExtend(f, s, 'a', 7, 1).state!;
      expect(tendrilTurn(f, s, 0).ok, isTrue);
    });
  });

  test('Earth: a pair is joined led from either root', () {
    final f = TendrilFloor(const ['#####', 'a...a', '#####']);
    var s = TendrilState.start(f);
    for (final x in [3, 2, 1, 0]) {
      s = tendrilExtend(f, s, 'a', x, 1, from: (x: 4, y: 1)).state!;
    }
    expect(tendrilSolved(f, s), isTrue);
  });

  group('Water — the turning room', () {
    final r = FlipRoom(kRiteWaterMap);
    FlipState play(String plan) {
      var s = flipStart(r);
      for (final m in plan.split(' ')) {
        final st = m == 'flip' ? flipTurn(r, s) : flipStep(r, s, _dir(m));
        expect(st.ok, isTrue, reason: 'refused at $m');
        s = st.state!;
      }
      return s;
    }

    test('the room is still at the start: no water, every fire lit', () {
      final s = flipStart(r);
      expect(s.loose.values.where((v) => v == '~'), isEmpty);
      expect(s.cells.expand((c) => c).where((c) => c == 'f'), isEmpty);
    });

    test('the proved plan solves it (three flips)', () {
      final s = play('N N N N W W N W flip S S S W W flip W flip N');
      expect(flipSolved(s), isTrue);
    });

    test('flipping first without thinking does not', () {
      expect(flipSolved(flipTurn(r, flipStart(r)).state!), isFalse);
    });

    test('the graph: 1892 states, half of them dead ends', () {
      final g = flipLiveStates(r);
      expect(g.states, 1892);
      expect(((1 - g.live.length / g.states) * 100).round(), 50);
    });

    test('THE VAULT: flip, flip back, two steps, and Blood is beside a '
        'flooded pit', () {
      final s = play('flip flip N W');
      expect(flipDiveFrom(s), greaterThanOrEqualTo(0));
      expect(s.cells.expand((c) => c).contains('p'), isTrue);
    });

    test('ice in a pit is floor; water in a pit is a pool', () {
      final t = FlipRoom(const ['#####', '#.I.#', '#.~.#', '#._.#', '#B..#', '#####']);
      var s = flipStart(t); // gravity south: the water drops into the pit
      expect(s.cells[3][2], 'p');
      final u = FlipRoom(const ['#####', '#.I.#', '#...#', '#._.#', '#B..#', '#####']);
      s = flipStart(u);
      expect(s.cells[3][2], '.');
    });
  });

  group('Fire — the twin', () {
    final r = TwinRoom(kRiteFireMap);

    test('the proved plan solves it: 21 steps', () {
      var s = twinStart(r);
      var single = 0;
      for (final c in 'EESSSSENNNSWWWSSSSEEE'.split('')) {
        final st = twinStep(r, s, _dir(c));
        expect(st.ok, isTrue);
        if (st.bMoved != st.tMoved) single++;
        s = st.state!;
      }
      expect(twinSolved(r, s), isTrue);
      expect(single, 17);
      expect(twinSolve(r)!.length, 21);
    });

    test('impossible with every gate shut, and with no plates or gates', () {
      final shut = TwinRoom([
        for (final row in kRiteFireMap) row.replaceAll(RegExp('[abc]'), '#'),
      ]);
      expect(twinSolve(shut), isNull);
      final bare = TwinRoom([
        for (final row in kRiteFireMap)
          row.replaceAll(RegExp('[abc123]'), '.'),
      ]);
      expect(twinSolve(bare), isNull);
    });

    test('the twin starts as Blood\'s mirror, across the pool', () {
      expect(r.t0.x, r.w - 1 - r.b0.x);
      expect(r.t0.y, r.b0.y);
    });
  });

  group('Air — the weightless room', () {
    final r = DriftRoom(kRiteAirMap, need: kRiteAirNeed);

    test('the proved plan solves it: 19 pushes', () {
      var s = driftStart(r);
      for (final c in 'NNWWENWSSWNESEENESS'.split('')) {
        final p = driftPush(r, s, _dir(c));
        expect(p.ok, isTrue, reason: 'refused at $c');
        s = p.state!;
      }
      expect(driftSolved(r, s), isTrue);
    });

    test('the graph: 5040 states, fewest 19 pushes, 74% dead ends', () {
      final g = driftGraph(r);
      expect(g.states, 5040);
      expect(g.plan.length, 19);
      expect(((1 - g.live.length / g.states) * 100).round(), 74);
    });
  });

  group('The Circle', () {
    const all = {'Air', 'Fire', 'Earth', 'Water'};

    test('home sends every stream to its cup', () {
      expect(riteCentre(all, 0, 0).kind, RiteCentreKind.none);
    });

    test('never one or three in the middle; the quintessence needs both '
        'rings turned', () {
      var quint = 0;
      for (var a = 0; a < 8; a++) {
        for (var b = 0; b < 8; b++) {
          final c = riteCentre(all, a, b);
          expect(c.kind, isNot(RiteCentreKind.one));
          expect(c.kind, isNot(RiteCentreKind.churn));
          if (c.kind == RiteCentreKind.quintessence) {
            quint++;
            expect(a, isNot(0));
            expect(b, isNot(0));
          }
        }
      }
      expect(quint, 16);
    });

    test('the four fusions you can find', () {
      final found = <String>{};
      for (var a = 0; a < 8; a++) {
        for (var b = 0; b < 8; b++) {
          final c = riteCentre(all, a, b);
          if (c.kind == RiteCentreKind.fusion) found.add(c.result!);
        }
      }
      expect(found, {'Lightning', 'Lava', 'Mud', 'Ice'});
    });
  });

  group('Sanguorath\'s shells', () {
    test('a shell only ever shows an element someone standing can break', () {
      for (final standing in [
        {'Fire'},
        {'Water', 'Air'},
        {'Earth', 'Air', 'Fire', 'Water'},
      ]) {
        for (var i = 0; i < 4; i++) {
          final el = riteShellElement(standing, (n) => i % n);
          expect(standing, contains(kRiteOpposite[el]));
        }
      }
    });
  });
}
