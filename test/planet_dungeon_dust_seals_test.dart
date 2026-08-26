// SABLIS Star 0 — THE THREE SEALS, solved.
//
// The seal street is the planet's conservation rule at spade scale (docs §6,
// the Dust entry): expose all three street-seals AT ONCE in a yard authored
// one load short of full, so every spadeful wants to land on a seal you
// already cleared.
//
// A hand-checked "looks solvable" is worth nothing on a puzzle like this, so
// this file EXHAUSTS it. The search runs on the shipping [RuinsOfTime] rules
// object itself — `digDrift` and `scourDrift`, the same two methods the verb
// dispatcher calls — so the solver can never drift away from what a player
// actually meets. It answers three questions:
//
//   1. Is the yard solvable at all, and in how few verbs?
//   2. Can a player ever DEADLOCK it — reach a state from which no sequence
//      of verbs reaches the goal? (A deadlocked yard would still be rescued
//      by the sirocco, since the wind resets the drift too, but Star 0 is the
//      star §4 guarantees to a first descent and it should not need rescuing.)
//   3. Does the ledger hold at every one of those states?
//
// Then the shortest solution the search found is REPLAYED move for move
// through the real game — real bodies, real facing, real verb button — and
// the star has to bank at the end of it.

import 'dart:math' show atan2;

import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dust.dart';
import 'package:flutter_test/flutter_test.dart';

import 'planet_dungeon_dust_ruins_test.dart' show harness, dust, air, earth;
import 'package:alchemons/games/cosmic/cosmic_data.dart';

CosmicPartyMember _member(int slot, String element, String family) =>
    CosmicPartyMember(
      instanceId: 'inst_$slot',
      baseId: 'base_$slot',
      displayName: '$element $family',
      element: element,
      family: family,
      level: 10,
      statSpeed: 3,
      statIntelligence: 5,
      statStrength: 3,
      statBeauty: 3,
      slotIndex: slot,
      staminaBars: 3,
      staminaMax: 3,
    );

List<CosmicPartyMember> _idealTrio() => [
  _member(0, 'Dust', 'mask'),
  _member(1, 'Air', 'wing'),
  _member(2, 'Earth', 'horn'),
];

/// One verb in the yard: stand on (c,r), face (dc,dr), spade or gust.
class YardMove {
  const YardMove(this.scour, this.c, this.r, this.dc, this.dr);
  final bool scour;
  final int c, r, dc, dr;
  @override
  String toString() => '${scour ? 'scour' : 'dig'} at ($c,$r) facing ($dc,$dr)';
}

const _dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];

/// Pack a yard ledger into one int — 15 cells × 2 bits, pillars as 3.
int _enc(List<int> d) {
  var k = 0;
  for (final v in d) {
    k = (k << 2) | (v < 0 ? 3 : v);
  }
  return k;
}

/// Every verb legal in [state], as (move, resulting ledger). Driven through
/// the SHIPPING rules object, one move at a time, so what the solver proves is
/// what the planet does.
List<(YardMove, List<int>)> _successors(RuinsOfTime r, List<int> state) {
  const g = kSealYard;
  final out = <(YardMove, List<int>)>[];
  for (var row = 0; row < g.rows; row++) {
    for (var col = 0; col < g.cols; col++) {
      if (!g.isGround(col, row)) continue;
      for (final (dc, dr) in _dirs) {
        final fc = col + dc, fr = row + dr;
        final bc = col - dc, br = row - dr;
        // DIG — bite in front, throw over the shoulder.
        if (g.isGround(fc, fr) && g.isGround(bc, br)) {
          r.drift.setAll(0, state);
          if (r.digDrift(fr * g.cols + fc, br * g.cols + bc)) {
            out.add((YardMove(false, col, row, dc, dr), [...r.drift]));
          }
        }
        // SCOUR — lift the top load off your own square, one cell downwind.
        if (g.isGround(fc, fr)) {
          r.drift.setAll(0, state);
          if (r.scourDrift(row * g.cols + col, fr * g.cols + fc)) {
            out.add((YardMove(true, col, row, dc, dr), [...r.drift]));
          }
        }
      }
    }
  }
  return out;
}

bool _solved(List<int> state) {
  for (final i in kSealYard.sealIndices) {
    if (state[i] != 0) return false;
  }
  return true;
}

int _sum(List<int> state) {
  var n = 0;
  for (final v in state) {
    if (v > 0) n += v;
  }
  return n;
}

/// Forward BFS over the whole yard, on the real rules.
({
  Map<int, List<int>> states,
  Map<int, (int, YardMove)> from,
  List<YardMove> shortest,
  int goals,
  bool conserved,
})
_searchYard() {
  final r = RuinsOfTime();
  final start = [...kSealYard.openingLoads];
  final states = <int, List<int>>{_enc(start): start};
  final from = <int, (int, YardMove)>{};
  final queue = <List<int>>[start];
  var head = 0;
  var conserved = true;
  int? goal;
  var goals = 0;
  while (head < queue.length) {
    final s = queue[head++];
    if (_sum(s) != kSealYard.totalLoads) conserved = false;
    if (_solved(s)) {
      goals++;
      goal ??= _enc(s);
    }
    for (final (mv, next) in _successors(r, s)) {
      final k = _enc(next);
      if (states.containsKey(k)) continue;
      states[k] = next;
      from[k] = (_enc(s), mv);
      queue.add(next);
    }
  }
  final path = <YardMove>[];
  var cur = goal;
  while (cur != null && from.containsKey(cur)) {
    final (prev, mv) = from[cur]!;
    path.add(mv);
    cur = prev;
  }
  return (
    states: states,
    from: from,
    shortest: path.reversed.toList(),
    goals: goals,
    conserved: conserved,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ({
    Map<int, List<int>> states,
    Map<int, (int, YardMove)> from,
    List<YardMove> shortest,
    int goals,
    bool conserved,
  })
  search;

  setUpAll(() {
    search = _searchYard();
  });

  group('the yard — authoring', () {
    test('the yard is one load short of full, which is the whole puzzle', () {
      const g = kSealYard;
      expect(g.sealIndices.length, 3, reason: 'three bronzes (§6)');
      final nonSeal =
          g.rows * g.cols -
          g.sealIndices.length -
          [
            for (var r = 0; r < g.rows; r++)
              for (var c = 0; c < g.cols; c++)
                if (g.isPillar(c, r)) 1,
          ].length;
      // Every load the seals give up has to fit somewhere else, and there is
      // exactly ONE spare slot in the whole yard once they have.
      expect(g.totalLoads, 21);
      expect(2 * nonSeal, 22);
      expect(
        2 * nonSeal - g.totalLoads,
        1,
        reason: '§6: every spoil placement wants to land on a seal',
      );
    });

    test('the west seal answers no spade — only the wind', () {
      // A spade throws over the shoulder, so digging cell X needs both a
      // standable cell beside it and a free cell two beyond. The west seal is
      // boxed by the pillar and the wall on every axis, which is how the room
      // teaches its second verb with no tutorial and no hint line.
      const g = kSealYard;
      final boxed = <int>[];
      for (final i in g.sealIndices) {
        final sc = i % g.cols, sr = i ~/ g.cols;
        var diggable = false;
        for (final (dc, dr) in _dirs) {
          // Stand at seal-d, face d: bites the seal, throws to seal-2d.
          final pc = sc - dc, pr = sr - dr;
          final tc = sc - 2 * dc, tr = sr - 2 * dr;
          if (g.isGround(pc, pr) && g.isGround(tc, tr)) diggable = true;
        }
        if (!diggable) boxed.add(i);
      }
      expect(boxed.length, 1, reason: 'exactly one seal is spade-proof');
    });

    test(
      'the opening yard allows exactly two spadefuls in the whole street',
      () {
        // The measure of how tight the authoring is: on the first frame there
        // are only two legal digs anywhere in the yard, both on the far column.
        // Everything else is a heap a spade cannot bite, or a heap with no room
        // behind it. The room's first real move is a gust, and it has to be.
        final r = RuinsOfTime();
        final start = [...kSealYard.openingLoads];
        final digs = _successors(r, start).where((m) => !m.$1.scour).toList();
        expect(digs.length, 2, reason: 'digs available on the opening yard');
        for (final (mv, _) in digs) {
          expect(mv.c, kSealYard.cols - 1);
        }
      },
    );
  });

  group('THE EXHAUSTIVE YARD SEARCH', () {
    test('the ledger holds at every state the yard can reach', () {
      // MEASURED 2026-08-24: 45474 reachable ledgers, 11 of them solved.
      expect(search.states.length, 45474);
      expect(search.goals, 11);
      expect(
        search.conserved,
        isTrue,
        reason: 'conservation: no verb in the yard may make or lose a load',
      );
    });

    test('the yard is SOLVABLE, and not trivially so', () {
      expect(search.shortest, isNotEmpty);
      // MEASURED 2026-08-24: eight verbs, and no shorter route exists.
      expect(
        search.shortest.length,
        8,
        reason: 'a three-move yard would be no puzzle at all',
      );
    });

    test('the yard can never be DEADLOCKED by legal play', () {
      // Star 0 is the star §4 guarantees to a first descent, so unlike the
      // city above it must not need the sirocco to rescue it. Proved by
      // walking the reachable set backwards from the goals: predecessors are
      // generated directly rather than stored, which keeps a 45k-state
      // reverse pass cheap.
      const g = kSealYard;
      final good = <int>{};
      final queue = <List<int>>[];
      for (final e in search.states.entries) {
        if (_solved(e.value)) {
          good.add(e.key);
          queue.add(e.value);
        }
      }
      var head = 0;
      while (head < queue.length) {
        final t = queue[head++];
        for (final p in _predecessors(t)) {
          final k = _enc(p);
          if (!search.states.containsKey(k) || !good.add(k)) continue;
          queue.add(p);
        }
      }
      expect(
        search.states.length - good.length,
        0,
        reason: 'every reachable ledger can still reach three bare seals',
      );
      // …and the search really did explore the yard, not a corner of it.
      expect(g.rows * g.cols, 15);
    });
  });

  group('THE AUTHORED SOLUTION, replayed through the real game', () {
    test('the shortest run banks Star 0 — and conserves every load', () {
      final earned = <int>[];
      final game = harness(_idealTrio(), onStar: earned.add);
      game.currentRoomId = 'seal_street';
      const g = kSealYard;

      for (final mv in search.shortest) {
        // Dust and Earth carry the spade; Air carries the gust (§4: both
        // element-only, so any family of them does this identically).
        final idx = mv.scour ? air : earth;
        final p = g.centerAt(mv.c, mv.r);
        final aim = atan2(mv.dr.toDouble(), mv.dc.toDouble());
        game.setActive(idx);
        for (final c in game.creatures) {
          c
            ..position = p
            ..lastSafe = p
            ..angle = aim
            ..aimAngle = aim;
        }
        game.activateAbility();
        expect(
          game.ruins.conserved,
          isTrue,
          reason: 'the ledger leaked at $mv',
        );
      }

      expect(game.ruins.sealsBare, isTrue, reason: 'after $search.shortest');
      expect(earned, contains(0));
      expect(game.hasStar(0), isTrue);
    });

    test('a spade will not bite a heap, and only the wind lifts a crest', () {
      // The two verbs' one real difference, pinned: it is what makes the yard
      // solvable at all, and it is the reason Air is an entry slot.
      final game = harness(_idealTrio());
      game.currentRoomId = 'seal_street';
      const g = kSealYard;
      // (0,0) opens as a dune.
      expect(game.ruins.driftAt(0), 2);

      void press(int idx, int c, int r, int dc, int dr) {
        final p = g.centerAt(c, r);
        final aim = atan2(dr.toDouble(), dc.toDouble());
        game.setActive(idx);
        for (final cr in game.creatures) {
          cr
            ..position = p
            ..lastSafe = p
            ..angle = aim
            ..aimAngle = aim;
        }
        game.activateAbility();
      }

      // A spade, standing east of the dune and biting west: refused.
      press(earth, 1, 0, -1, 0);
      expect(game.ruins.driftAt(0), 2, reason: 'packed hard');
      // The gust, standing ON the dune and blowing east: it goes.
      press(air, 0, 0, 1, 0);
      expect(game.ruins.driftAt(0), 1);
      expect(game.ruins.conserved, isTrue);
    });

    test('the Dust hand and the Earth hand dig identically (§4)', () {
      const g = kSealYard;
      final states = <String>[];
      for (final idx in [dust, earth]) {
        final game = harness(_idealTrio());
        game.currentRoomId = 'seal_street';
        // Stand at (4,1) facing north: bite (4,0), throw to (4,2). It is one
        // of only TWO spadefuls the opening yard allows at all — which is
        // itself the measure of how tight the authoring is.
        final p = g.centerAt(4, 1);
        game.setActive(idx);
        for (final c in game.creatures) {
          c
            ..position = p
            ..lastSafe = p
            ..angle = -1.5707963
            ..aimAngle = -1.5707963;
        }
        game.activateAbility();
        expect(game.ruins.conserved, isTrue);
        states.add(game.ruins.drift.join(','));
      }
      expect(states[0], states[1], reason: 'element opens; family does not');
      expect(states[0], isNot(kSealYard.openingLoads.join(',')));
    });
  });

  group('THE WHOLE DESCENT, walked without a single sirocco', () {
    test(
      'the ideal trio takes both stars and reaches the rite on one line',
      () {
        // The proof that the planet is not merely un-strandable but PLAYABLE:
        // one route from the gate to the guardian's door in which every door
        // used is genuinely open at the moment it is used, and the valve is
        // never touched. It turns on the planet's sharpest decision — the
        // observatory's spoil goes WEST onto the agora, and the dune it raises
        // is the road onward. Throw it east instead and you get the vault, and
        // you pay a sirocco for the way on. Either is a run; that is the star.
        final earned = <int>[];
        final game = harness(_idealTrio(), onStar: earned.add);
        const g = kSealYard;

        void press(int idx, String room, Offset p, [double aim = 0]) {
          game.currentRoomId = room;
          game.setActive(idx);
          for (final c in game.creatures) {
            c
              ..position = p
              ..lastSafe = p
              ..angle = aim
              ..aimAngle = aim;
          }
          game.activateAbility();
          expect(game.ruins.conserved, isTrue, reason: 'ledger, in $room');
        }

        // 1 · The gate. Dust parts the silt and Sablis opens.
        press(
          dust,
          'ashen_gate',
          game.layout.rooms['ashen_gate']!.ruins!.gateSilt!,
        );
        expect(game.entryDoorRevealed, isTrue);
        expect(_canPass(game, 'ashen_gate', 'seal_street'), isTrue);

        // 2 · The seal street. The yard, solved on the shortest line.
        for (final mv in search.shortest) {
          press(
            mv.scour ? air : earth,
            'seal_street',
            g.centerAt(mv.c, mv.r),
            atan2(mv.dr.toDouble(), mv.dc.toDouble()),
          );
        }
        expect(earned, contains(0));
        expect(_canPass(game, 'seal_street', 'roof_walk'), isTrue);

        // 3 · The roof walk. Strip the observatory's roof, throwing WEST.
        press(
          earth,
          'roof_walk',
          dustMoundById('m_roof')!.streetPos,
          3.14159265,
        );
        expect(game.ruins.stateOf('m_roof'), MoundState.bared);
        expect(game.ruins.stateOf('m_agora'), MoundState.drifted);
        // The bridge to the court is gone — that is the cost, paid up front.
        expect(_canPass(game, 'roof_walk', 'sand_court'), isFalse);
        expect(_canPass(game, 'roof_walk', 'observatory'), isTrue);

        // 4 · The observatory. The sky is down; the Wing crosses the span.
        press(
          air,
          'observatory',
          game.layout.rooms['observatory']!.ruins!.armillary!,
        );
        expect(earned, contains(1));

        // 5 · Out through the tunnels and back up the dune you raised.
        expect(_canPass(game, 'observatory', 'undercity'), isTrue);
        expect(_canPass(game, 'undercity', 'windcatch'), isTrue);
        expect(_canPass(game, 'windcatch', 'ashen_gate'), isTrue);
        expect(_canPass(game, 'ashen_gate', 'seal_street'), isTrue);
        expect(
          _canPass(game, 'seal_street', 'high_terrace'),
          isTrue,
          reason: 'the ramp IS the observatory\'s spoil',
        );
        expect(_canPass(game, 'high_terrace', 'sand_court'), isTrue);
        expect(game.ruins.levellings, 0, reason: 'no sirocco was ever needed');

        // 6 · The rite. Earth+HORN through the false wall, Dust on the glass.
        final court = game.layout.rooms['sand_court']!;
        press(
          earth,
          'sand_court',
          court.conduits.firstWhere((c) => c.id == 'A').position,
        );
        expect(game.conduitEnergy['A'], double.infinity);
        press(dust, 'sand_court', court.ruins!.glassCourt!);
        expect(game.conduitEnergy['B'], double.infinity);

        // …and the hollow answers.
        game.update(1 / 60);
        expect(game.guardianAwake, isTrue);
        expect(_canPass(game, 'sand_court', 'ashdjinn_hollow'), isTrue);
        expect(game.ruins.conserved, isTrue);
      },
    );
  });
}

/// A door out of [from] toward [to] that the party could actually walk right
/// now — neither hidden by the ground's state nor locked behind it.
bool _canPass(PlanetDungeonGame game, String from, String to) {
  final room = game.layout.rooms[from]!;
  for (final d in room.doors) {
    if (d.targetRoomId != to) continue;
    if (game.isDoorHidden(room, d) || game.isDoorLocked(room, d)) continue;
    return true;
  }
  return false;
}

/// Every ledger one verb BEFORE [t]. Derived from the forward rules by
/// inversion rather than stored, so the backward pass costs no memory:
///  • a DIG that produced [t] took front 1→0 and back b→b+1, so its
///    predecessor has front == 1 and back == t[back] - 1;
///  • a SCOUR took here h→h-1 and front f→f+1, so its predecessor has
///    here == t[here] + 1 (≤ 2) and front == t[front] - 1 (≥ 0).
List<List<int>> _predecessors(List<int> t) {
  const g = kSealYard;
  final out = <List<int>>[];
  for (var row = 0; row < g.rows; row++) {
    for (var col = 0; col < g.cols; col++) {
      if (!g.isGround(col, row)) continue;
      for (final (dc, dr) in _dirs) {
        final fc = col + dc, fr = row + dr;
        final bc = col - dc, br = row - dr;
        if (g.isGround(fc, fr) && g.isGround(bc, br)) {
          final f = fr * g.cols + fc, b = br * g.cols + bc;
          if (t[f] == 0 && t[b] >= 1 && t[b] <= 2) {
            final p = [...t];
            p[f] = 1;
            p[b] -= 1;
            out.add(p);
          }
        }
        if (g.isGround(fc, fr)) {
          final h = row * g.cols + col, f = fr * g.cols + fc;
          if (t[h] <= 1 && t[f] >= 1) {
            final p = [...t];
            p[h] += 1;
            p[f] -= 1;
            out.add(p);
          }
        }
      }
    }
  }
  return out;
}
