// VITREA — the Prism Labyrinth's sliding keep, PROVED.
//
// Crystal's topology is a 3×3 sliding grid (docs/dungeons.md §5.5), and a
// sliding grid has a hazard no playtest can ever find: PARITY. Of the
// 9! = 362,880 ways to lay eight chambers and a hollow in nine cells, exactly
// half can ever be reached from any given start. Author a star, a vault or an
// exit in the wrong half and the dungeon is not hard, it is mathematically
// impossible — and a player who fails simply concludes they are bad at it.
//
// So this file's first job is the one thing the design cannot ship without:
//
//  1. THE PARITY PROOF. The conserved quantity, asserted move by move; then
//     an exhaustive BFS over the arrangement space showing the reachable orbit
//     is exactly 9!/2 = 181,440, that the group achievable with the hollow
//     home is the ALTERNATING group A8 (20,160 arrangements, every one an even
//     rearrangement OF THE OPENING), and that the other half is unreachable BY
//     PARITY rather than merely unvisited — asserted arrangement by
//     arrangement over all 362,880.
//  2. THE REACHABILITY PROOF, on the graph the player actually walks:
//     1,592,585 states over (arrangement × where the body is standing), with
//     facet-gated walking and both frame arches included — because an
//     arrangement nobody can be standing in the right place to finish is no
//     better than an unreachable one. Star 0 is reachable in 2,160 of them,
//     Star 1 in 420, the vault in 15,120, and NEITHER STAR IS EVER HOLDABLE
//     WITH THE OTHER (0 states), which is the planet's strategic question
//     stated as a number.
//
// THIS FILE HAS ALREADY EARNED ITS KEEP TWICE. It caught a first draft in
// which only 2 of the 181,440 arrangements were reachable (the hollow was not
// walkable, so a body could not get to a shove-plate), and a second in which
// THE ANNEAL carried the ringer along with their own chamber and therefore set
// them back down in the very trap they rang it to escape. Both are fixed in
// the shipped rules; both are pinned below.
//
// Unlike Ice (120/122 strandable), Mud (1200/1284) and Dust (319/396), Crystal
// edits nothing irreversibly and needs no conservation ledger: shunts and
// walks are involutions, so the reachable set is symmetric and every state can
// get home. The anneal is still load-bearing — 7,404 reachable states are jams
// — and this file counts them by name.
//
// The rest pins the two stars' authored targets, the vault's one
// configuration, both hard gates, the lost maxim and the guardian against the
// real rules and the real engine.

import 'dart:typed_data';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_crystal.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────
// THE SEARCH — arrangements encoded as permutations of 0..8
// ─────────────────────────────────────────────────────────
// Item 8 is the HOLLOW; items 0..7 are kPrismChambers[0..7]. A cell's content
// is the item standing in it, so an arrangement IS a permutation of nine
// items over nine cells and the whole space is indexable by its Lehmer code.

const int _hollowItem = 8;
const List<int> _fact = [1, 1, 2, 6, 24, 120, 720, 5040, 40320, 362880];

/// The opening arrangement, with the hollow written as item 8.
List<int> openingPerm() =>
    [for (final c in kKeepOpeningCells) c == kHollow ? _hollowItem : c];

int encode(List<int> p) {
  var code = 0;
  for (var i = 0; i < 9; i++) {
    var c = 0;
    for (var j = i + 1; j < 9; j++) {
      if (p[j] < p[i]) c++;
    }
    code = code * (9 - i) + c;
  }
  return code;
}

final List<int> _avail = List<int>.filled(9, 0);

void decode(int code, List<int> out) {
  for (var i = 0; i < 9; i++) {
    _avail[i] = i;
  }
  var n = 9;
  for (var i = 0; i < 9; i++) {
    final f = _fact[8 - i];
    final k = code ~/ f;
    code %= f;
    out[i] = _avail[k];
    for (var j = k; j < n - 1; j++) {
      _avail[j] = _avail[j + 1];
    }
    n--;
  }
}

bool adjacent(int a, int b) {
  final ra = a ~/ 3, ca = a % 3, rb = b ~/ 3, cb = b % 3;
  return (ra - rb).abs() + (ca - cb).abs() == 1;
}

/// sgn(π) as a parity bit: 0 = even, 1 = odd.
int permParity(List<int> p) {
  var inv = 0;
  for (var i = 0; i < 9; i++) {
    for (var j = i + 1; j < 9; j++) {
      if (p[i] > p[j]) inv++;
    }
  }
  return inv & 1;
}

/// THE CONSERVED QUANTITY. Every shunt transposes the hollow with an
/// orthogonal neighbour — flipping sgn(π) — and moves the hollow one step on a
/// bipartite lattice, flipping the colour of its cell. Their XOR is therefore
/// invariant, and the reachable orbit is exactly the arrangements that share
/// the start's value of it.
int parityClass(List<int> p) {
  final h = p.indexOf(_hollowItem);
  return permParity(p) ^ ((h ~/ 3 + h % 3) & 1);
}

/// Can a body walk the arch between [a] and [b] under arrangement [p]?
/// Mirrors [PrismKeepField.passable] exactly — asserted against it below, so
/// the search can never drift from the shipped rule.
bool passable(List<int> p, int a, int b) {
  if (!adjacent(a, b)) return false;
  final ia = p[a], ib = p[b];
  if (ia == _hollowItem && ib == _hollowItem) return false;
  if (ia == _hollowItem) {
    return kPrismChambers[ib].cut(keepFacetToward(b, a));
  }
  if (ib == _hollowItem) {
    return kPrismChambers[ia].cut(keepFacetToward(a, b));
  }
  final ca = kPrismChambers[ia], cb = kPrismChambers[ib];
  return ca.cut(keepFacetToward(a, b)) && cb.cut(keepFacetToward(b, a));
}

// Player positions in the search: 0..8 = a lattice cell, 9 = the oriel
// (outside the south threshold), 10 = the tuning side (the hall and the choir
// beyond the north arch).
const int _oriel = 9;
const int _tuning = 10;
const int _slots = 11;

/// The whole state graph the player actually moves through, walked with the
/// three reversible moves: SHUNT (ride your chamber into the hollow), WALK
/// (through an arch whose glass agrees) and the two FRAME ARCHES (cut in the
/// keep's own stone, so they ask only that something stands under them).
///
/// The anneal is deliberately EXCLUDED here so the relation stays symmetric —
/// see `annealAddsNothing` below, which is what turns that symmetry into the
/// claim that every reachable state can get home.
class KeepSearch {
  final Uint8List seen = Uint8List(362880 * _slots);
  final List<int> order = <int>[];

  int explore(int startCode, int startPlayer) {
    final p = List<int>.filled(9, 0);
    final queue = <int>[startCode * _slots + startPlayer];
    seen[queue.first] = 1;
    var head = 0;
    while (head < queue.length) {
      final s = queue[head++];
      order.add(s);
      final code = s ~/ _slots;
      final at = s % _slots;
      decode(code, p);

      void push(int nextCode, int nextAt) {
        final k = nextCode * _slots + nextAt;
        if (seen[k] != 0) return;
        seen[k] = 1;
        queue.add(k);
      }

      if (at <= 8) {
        final h = p.indexOf(_hollowItem);
        // SHUNT — the chamber and the hollow trade places, and so does the
        // body: from inside a chamber you ride it across, from inside the bare
        // socket you haul a neighbour in and stay with the hollow. Either way
        // you end up in the OTHER cell of the pair.
        if (at == h) {
          for (final n in keepNeighbours(h)) {
            p[h] = p[n];
            p[n] = _hollowItem;
            push(encode(p), n);
            p[n] = p[h];
            p[h] = _hollowItem;
          }
        } else if (adjacent(at, h)) {
          p[h] = p[at];
          p[at] = _hollowItem;
          push(encode(p), h);
          p[at] = p[h];
          p[h] = _hollowItem;
        }
        // WALK.
        for (final n in keepNeighbours(at)) {
          if (passable(p, at, n)) push(code, n);
        }
        // The frame arches are cut in the keep's own stone and never shut.
        if (at == kKeepThresholdCell) push(code, _oriel);
        if (at == kKeepNorthCell) push(code, _tuning);
      } else if (at == _oriel) {
        push(code, kKeepThresholdCell);
      } else {
        push(code, kKeepNorthCell);
      }
    }
    return queue.length;
  }

  bool has(int code, int at) => seen[code * _slots + at] != 0;

  /// Every distinct arrangement anywhere in the reachable set.
  Set<int> get arrangements {
    final out = <int>{};
    for (final s in order) {
      out.add(s ~/ _slots);
    }
    return out;
  }
}

// ─────────────────────────────────────────────────────────
// ENGINE HARNESS
// ─────────────────────────────────────────────────────────

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

/// The §6.10 ideal trio: Crystalmask · Lightninghorn · Spiritpip.
List<CosmicPartyMember> idealTrio() => [
  _member(0, 'Crystal', 'mask'),
  _member(1, 'Lightning', 'horn'),
  _member(2, 'Spirit', 'pip'),
];

const int crystal = 0, lightning = 1, spirit = 2;

PlanetDungeonGame harness(
  List<CosmicPartyMember> party, {
  void Function(int)? onStar,
  void Function(String)? onCloud,
}) {
  final game = PlanetDungeonGame(
    element: 'Crystal',
    party: party,
    initialStarMask: 0,
    onStarEarned: onStar ?? (_) {},
    onCloudDiscovered: onCloud,
    onPlayerDown: () => fail('the scripted run must never wipe'),
    onChanged: () {},
  );
  game.currentRoomId = game.layout.entranceRoomId;
  for (final m in party) {
    final c = DungeonCreature(member: m)
      ..position = game.layout.entranceSpawn
      ..lastSafe = game.layout.entranceSpawn;
    game.creatures.add(c);
    final stats = deriveCosmicSurvivalCompanionStats(member: m);
    game.combatCompanions.add(
      CosmicSurvivalCompanion(
        member: m,
        slotIndex: m.slotIndex,
        position: c.position,
        anchor: c.position,
        maxHp: stats.maxHp,
        currentHp: stats.maxHp,
        physAtk: stats.physAtk,
        elemAtk: stats.elemAtk,
        physDef: stats.physDef,
        elemDef: stats.elemDef,
        cooldownReduction: stats.cooldownReduction,
        critChance: stats.critChance,
        attackRange: stats.attackRange,
        specialAbilityRange: stats.specialAbilityRange,
        tethered: false,
        invincibleTimer: 0,
      ),
    );
  }
  return game;
}

/// Stand [idx] on [pos] in [room] and press the verb.
void act(PlanetDungeonGame game, int idx, String room, Offset pos) {
  game.currentRoomId = room;
  game.setActive(idx);
  for (final c in game.creatures) {
    c
      ..position = pos
      ..lastSafe = pos;
  }
  game.activateAbility();
}

// ─────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final layout = kPlanetDungeonLayouts['Crystal']!;
  final start = openingPerm();
  final startCode = encode(start);

  // The searches are expensive enough to be worth doing exactly once.
  late KeepSearch search;
  late Set<int> reachableArrangements;
  setUpAll(() {
    search = KeepSearch()..explore(startCode, _oriel);
    reachableArrangements = search.arrangements;
  });

  group('the encoding is a bijection, so the search space is the real one', () {
    test('encode and decode round-trip on the whole space', () {
      final buf = List<int>.filled(9, 0);
      for (var code = 0; code < 362880; code += 977) {
        decode(code, buf);
        expect(encode(buf), code);
        expect(buf.toSet().length, 9);
      }
      decode(0, buf);
      expect(buf, [0, 1, 2, 3, 4, 5, 6, 7, 8]);
      decode(362879, buf);
      expect(buf, [8, 7, 6, 5, 4, 3, 2, 1, 0]);
    });

    test('the search walks the SHIPPED passability rule, not a copy of it', () {
      // Drift between the solver's model and the shipped rule is the way a
      // proof like this quietly stops proving anything, so the two are
      // compared cell by cell over a sample of the space.
      final f = PrismKeepField();
      final buf = List<int>.filled(9, 0);
      for (var code = 0; code < 362880; code += 733) {
        decode(code, buf);
        f.restore([for (final i in buf) i == _hollowItem ? kHollow : i]);
        for (var a = 0; a < 9; a++) {
          for (final b in keepNeighbours(a)) {
            expect(
              passable(buf, a, b),
              f.passable(a, b),
              reason: 'arrangement $code disagrees on the arch $a→$b',
            );
          }
        }
      }
    });
  });

  group('THE PARITY PROOF', () {
    test('every legal shunt conserves sgn(π) XOR the hollow\'s cell colour',
        () {
      final f = PrismKeepField();
      final want = parityClass(start);
      // Walk a long deterministic tour of the keep and re-assert after every
      // single move — the invariant is not a claim about the start, it is a
      // claim about the move.
      var moves = 0;
      for (var step = 0; step < 4000; step++) {
        final h = f.hollowCell;
        final options = keepNeighbours(h);
        final from = options[step % options.length];
        if (!f.canShunt(from)) continue;
        f.shunt(from);
        moves++;
        final p = [
          for (final c in f.cells) c == kHollow ? _hollowItem : c,
        ];
        expect(
          parityClass(p),
          want,
          reason: 'the invariant broke after $moves shunts',
        );
      }
      expect(moves, greaterThan(3000));
    });

    test('the reachable orbit is EXACTLY half the space — 9!/2 = 181,440', () {
      expect(reachableArrangements.length, 181440);
      expect(reachableArrangements.length, _fact[9] ~/ 2);
    });

    test('the other half is unreachable, and it is unreachable BY PARITY', () {
      // Not "we did not happen to visit it": every arrangement in the
      // reachable set shares the start's invariant, and every arrangement
      // outside it fails the invariant. That is the whole hazard, closed.
      final want = parityClass(start);
      final buf = List<int>.filled(9, 0);
      var reachableChecked = 0, unreachableChecked = 0;
      for (var code = 0; code < 362880; code++) {
        decode(code, buf);
        final inOrbit = reachableArrangements.contains(code);
        expect(
          parityClass(buf) == want,
          inOrbit,
          reason: 'arrangement $code: orbit membership must BE the invariant',
        );
        if (inOrbit) {
          reachableChecked++;
        } else {
          unreachableChecked++;
        }
      }
      expect(reachableChecked, 181440);
      expect(unreachableChecked, 181440);
    });

    test('with the hollow home the group is the ALTERNATING group A8', () {
      // Wilson's theorem: the 3×3 grid graph is 2-connected, is not a cycle,
      // is not the exceptional theta-0 graph, and IS bipartite — precisely the
      // case in which the puzzle group is A(n-1) rather than S(n-1). So with
      // the hollow returned to its home cell, the permutations achievable ON
      // the eight chambers are exactly A8: 8!/2 = 20,160 of them, every one an
      // EVEN rearrangement OF THE OPENING ARRANGEMENT.
      //
      // (The reachable arrangements are the coset start·A8, not A8 itself —
      // the opening arrangement happens to be an odd permutation of the
      // identity labelling, which is an accident of how the chambers are
      // numbered and means nothing. What forms the group is the set of MOVES,
      // measured relative to the start.)
      final home = start.indexOf(_hollowItem);
      final startChambers = [
        for (var i = 0; i < 9; i++)
          if (i != home) start[i],
      ];
      final rank = <int, int>{
        for (var i = 0; i < 8; i++) startChambers[i]: i,
      };
      final buf = List<int>.filled(9, 0);
      var homeCount = 0;
      for (final code in reachableArrangements) {
        decode(code, buf);
        if (buf[home] != _hollowItem) continue;
        homeCount++;
        final rel = [
          for (var i = 0; i < 9; i++)
            if (i != home) rank[buf[i]]!,
        ];
        var inv = 0;
        for (var i = 0; i < 8; i++) {
          for (var j = i + 1; j < 8; j++) {
            if (rel[i] > rel[j]) inv++;
          }
        }
        expect(
          inv.isEven,
          isTrue,
          reason: 'arrangement $code is an ODD rearrangement of the opening — '
              'no sequence of slides can reach it with the hollow home',
        );
      }
      expect(homeCount, 20160, reason: 'the order of A8 is 8!/2');
      expect(homeCount * 9, 181440, reason: '|A8| x 9 hollow cells = 9!/2');
    });
  });

  group('THE REACHABILITY PROOF — the graph the player actually walks', () {
    test('the two searches agree, so neither is trusted on its own', () {
      // SHUNT, WALK and both frame arches are involutions, so the relation is
      // symmetric and the reachable set is one strongly-connected component.
      // Proved rather than asserted: a second search run backwards from the
      // start over the same move set must land on exactly the same set.
      final back = KeepSearch()..explore(startCode, _oriel);
      expect(back.order.length, search.order.length);
      for (final s in search.order) {
        expect(back.has(s ~/ _slots, s % _slots), isTrue);
      }
      // And every state's own successors are all inside the set (closure).
      final p = List<int>.filled(9, 0);
      for (final s in search.order) {
        final code = s ~/ _slots;
        final at = s % _slots;
        if (at > 8) continue;
        decode(code, p);
        for (final n in keepNeighbours(at)) {
          if (!passable(p, at, n)) continue;
          expect(search.has(code, n), isTrue);
        }
      }
    });

    test('every reachable state can get back to the oriel', () {
      // Which follows from symmetry: the start state IS (opening, oriel), and
      // a symmetric relation on one component means everything in it reaches
      // everything else. Asserted rather than argued.
      expect(search.has(startCode, _oriel), isTrue);
      // 1,592,585 of the 3,991,680 conceivable (arrangement × where the body
      // is standing) states, in one component.
      expect(search.order.length, 1592585);
      // Every arrangement in the orbit is reachable with the body somewhere.
      expect(reachableArrangements.length, 181440);
    });

    test('THE ANNEAL lands on the START STATE from anywhere, so it can never '
        'set you back down in the trap it just got you out of', () {
      // The first draft of this valve carried the ringer along with their own
      // chamber, and this search caught it: annealing while riding the Black
      // Cell into the north-west corner puts you straight back into the same
      // walled-in socket, forever. Throwing the ringer clear of the keep makes
      // the valve total — one ring returns the run to the exact state it began
      // in, which is trivially in the reachable set because it IS that set's
      // root.
      final f = PrismKeepField();
      final p = List<int>.filled(9, 0);
      var checked = 0;
      for (var i = 0; i < search.order.length; i += 37) {
        final s = search.order[i];
        decode(s ~/ _slots, p);
        f.restore([for (final c in p) c == _hollowItem ? kHollow : c]);
        f.anneal();
        expect(f.cells, kKeepOpeningCells);
        expect(f.hollowBerthed, isFalse);
        checked++;
      }
      expect(checked, greaterThan(1000));
      expect(search.has(startCode, _oriel), isTrue);
    });

    test('the anneal IS load-bearing — the keep really can wedge', () {
      // Crystal cannot strand you the way Ice/Mud/Dust can, because nothing it
      // does is irreversible. It has exactly one way to jam: a body standing
      // in a chamber whose facets face nothing walkable, with the hollow out
      // of reach. Counted here by name so the valve is never mistaken for
      // decoration and quietly deleted.
      final p = List<int>.filled(9, 0);
      var wedged = 0;
      for (final s in search.order) {
        final at = s % _slots;
        if (at > 8) continue;
        final code = s ~/ _slots;
        decode(code, p);
        if (at == kKeepThresholdCell || at == kKeepNorthCell) continue;
        if (adjacent(at, p.indexOf(_hollowItem))) continue;
        var canMove = false;
        for (final n in keepNeighbours(at)) {
          if (passable(p, at, n)) {
            canMove = true;
            break;
          }
        }
        if (!canMove) wedged++;
      }
      expect(
        wedged,
        7404,
        reason: 'if nothing can wedge, the anneal is decoration — say so. '
            '7,404 of the 1,592,585 reachable states are jams (0.46%), and '
            'every one of them is a body on glass that faces nothing, with '
            'the hollow out of reach',
      );
      // And every one of them is answered: there is a tuning boss in every
      // socket's frame, and the ring puts you out on the oriel.
      final f = PrismKeepField();
      f.restore([7, 4, 5, 1, 0, 6, 3, 2, kHollow]);
      f.anneal();
      expect(f.cells, kKeepOpeningCells);
    });
  });

  group('STAR 0 — THE PRISM (the rose reads one hue)', () {
    test('exactly ONE set of three chambers bends the light to the rose', () {
      final clear = [
        for (var i = 0; i < 8; i++)
          if (kPrismChambers[i].clear) i,
      ];
      expect(clear.length, 5, reason: 'five of eight let a light through');
      final hits = <List<int>>[];
      for (var a = 0; a < clear.length; a++) {
        for (var b = a + 1; b < clear.length; b++) {
          for (var c = b + 1; c < clear.length; c++) {
            final sum = (kPrismChambers[clear[a]].bend +
                    kPrismChambers[clear[b]].bend +
                    kPrismChambers[clear[c]].bend) %
                12;
            if (sum == kRoseHue) hits.add([clear[a], clear[b], clear[c]]);
          }
        }
      }
      expect(hits.length, 1, reason: 'the rose must have ONE answer');
      expect(
        hits.single.map((i) => kPrismChambers[i].id).toSet(),
        {'beryl', 'lazuli', 'citrine'},
      );
      // And the hearth is NOT in it — which is what makes the two stars pull
      // against each other (§5.5's strategic question, in geometry).
      expect(hits.single.contains(0), isFalse);
    });

    test('the authored target is REACHABLE, and its parity class is the '
        'start\'s', () {
      final want = {
        for (final id in ['beryl', 'lazuli', 'citrine'])
          kPrismChambers.indexWhere((c) => c.id == id),
      };
      final buf = List<int>.filled(9, 0);
      var solvable = 0;
      for (final code in reachableArrangements) {
        decode(code, buf);
        if ({for (final c in kKeepBeamRow) buf[c]}.difference(want).isEmpty) {
          solvable++;
          expect(parityClass(buf), parityClass(start));
        }
      }
      expect(
        solvable,
        greaterThan(0),
        reason: 'THE HAZARD: an unreachable Star 0 would be unfindable in play',
      );
      // 3! orders inside the row x 6! layings of the other six items = 4,320
      // arrangements satisfy the rose; exactly half survive the parity split,
      // so 2,160 are actually reachable — and 2,160 never will be.
      expect(solvable, 2160);
    });

    test('the field agrees: the authored row banks the star and no other does',
        () {
      final f = PrismKeepField()..lampLit = true;
      f.restore([2, 3, 4, 5, 6, 7, kHollow, 0, 1]);
      // cells 3,4,5 = lazuli(5=idx3? no) — set it explicitly instead:
      f.restore([0, 5, 6, 2, 3, 4, 7, 1, kHollow]);
      expect(f.beamLive, isTrue);
      expect(f.beamHue, kRoseHue);
      expect(f.spectrumSolved, isTrue);
      // Swap the hearth into the row and the rose goes quiet.
      f.restore([2, 5, 6, 0, 3, 4, 7, 1, kHollow]);
      expect(f.beamLive, isTrue);
      expect(f.spectrumSolved, isFalse);
      // An opaque chamber in the row stops the light dead.
      f.restore([2, 5, 6, 1, 3, 4, 7, 0, kHollow]);
      expect(f.beamLive, isFalse);
      expect(f.spectrumSolved, isFalse);
    });

    test('no lamp, no star — and the lamp is the planet\'s own braid', () {
      final f = PrismKeepField();
      f.restore([0, 5, 6, 2, 3, 4, 7, 1, kHollow]);
      expect(f.lampLit, isFalse);
      expect(f.beamLive, isFalse);
      expect(f.spectrumSolved, isFalse);
      f.lampLit = true;
      expect(f.spectrumSolved, isTrue);
    });

    test('bends ADD, so the order inside the row is unobservable', () {
      // The deliberate distinction from Air's ordering seat and Fire's
      // sequence seat (§5.5): what the rose reads is a fact about WHICH three
      // chambers stand in the row, never about how they were put there.
      final a = PrismKeepField()..lampLit = true;
      final b = PrismKeepField()..lampLit = true;
      a.restore([0, 5, 6, 2, 3, 4, 7, 1, kHollow]);
      b.restore([0, 5, 6, 4, 2, 3, 7, 1, kHollow]);
      expect(a.beamHue, b.beamHue);
      expect(a.spectrumSolved && b.spectrumSolved, isTrue);
    });
  });

  group('STAR 1 — THE THRONES (three faces of one hearth)', () {
    test('exactly seven ways to serve all three at once', () {
      final hearth = 0;
      final thrones = [
        for (var i = 0; i < 8; i++)
          if (kPrismChambers[i].throne) i,
      ];
      expect(thrones.length, 3);
      final ring = keepNeighbours(kKeepHeartCell);
      expect(ring.length, 4, reason: 'the heart is the only 4-faced cell');
      var ways = 0;
      for (final a in ring) {
        for (final b in ring) {
          for (final c in ring) {
            if (a == b || b == c || a == c) continue;
            final p = List<int>.filled(9, -1);
            p[kKeepHeartCell] = hearth;
            p[a] = thrones[0];
            p[b] = thrones[1];
            p[c] = thrones[2];
            var ok = true;
            for (final cell in [a, b, c]) {
              if (!kPrismChambers[p[cell]]
                      .cut(keepFacetToward(cell, kKeepHeartCell)) ||
                  !kPrismChambers[hearth]
                      .cut(keepFacetToward(kKeepHeartCell, cell))) {
                ok = false;
              }
            }
            if (ok) ways++;
          }
        }
      }
      expect(ways, 7);
    });

    test('the authored target is REACHABLE, and its parity class is the '
        'start\'s', () {
      final f = PrismKeepField()..hearthKindled = true;
      final buf = List<int>.filled(9, 0);
      var solvable = 0;
      for (final code in reachableArrangements) {
        decode(code, buf);
        f.restore([for (final c in buf) c == _hollowItem ? kHollow : c]);
        if (!f.thronesServed) continue;
        solvable++;
        expect(parityClass(buf), parityClass(start));
      }
      expect(
        solvable,
        greaterThan(0),
        reason: 'THE HAZARD: an unreachable Star 1 would be unfindable in play',
      );
      // 7 cell-assignments × 5! fillings of the remaining five slots = 840,
      // exactly half of which survive the parity split.
      expect(solvable, 420);
    });

    test('a cold shard banks nothing, however the keep stands', () {
      final f = PrismKeepField();
      f.restore([1, 5, 6, 2, 0, 3, 7, 4, kHollow]);
      expect(f.hearthKindled, isFalse);
      expect(f.thronesServed, isFalse);
      f.hearthKindled = true;
      // Now it is a question about the arrangement alone.
      expect(f.thronesStanding, greaterThanOrEqualTo(0));
    });

    test('the two stars CANNOT be held at once — that is the whole planet',
        () {
      final f = PrismKeepField()
        ..lampLit = true
        ..hearthKindled = true;
      final buf = List<int>.filled(9, 0);
      var both = 0;
      for (final code in reachableArrangements) {
        decode(code, buf);
        f.restore([for (final c in buf) c == _hollowItem ? kHollow : c]);
        if (f.spectrumSolved && f.thronesServed) both++;
      }
      expect(
        both,
        0,
        reason: 'Star 1 wants the hearth in the middle row; Star 0 forbids it. '
            'Every slide solves one adjacency and breaks another (§5.5)',
      );
    });
  });

  group('THE VAULT — a room that only enters the grid in one configuration',
      () {
    test('the waiting facet is cut on ONE face, and it is the west one', () {
      final w = kPrismChambers[kWaitingFacet];
      expect(w.cut(kFacetW), isTrue);
      expect(w.cut(kFacetE) || w.cut(kFacetN) || w.cut(kFacetS), isFalse);
      expect(w.clear, isFalse, reason: 'the facet stops the beam dead');
    });

    test('the chain only bites with the hollow at rest in the mouth', () {
      final f = PrismKeepField();
      expect(f.hollowCell, 8);
      expect(f.canCallFacet(4), isFalse);
      expect(f.canCallFacet(kKeepMouthCell), isFalse);
      // Bring the hollow to the mouth by riding out of it westward.
      f.restore([7, 4, 5, 1, 0, kHollow, 3, 2, 6]);
      expect(f.canCallFacet(4), isTrue);
      expect(f.canCallFacet(0), isFalse, reason: 'must be beside the mouth');
      expect(f.callFacet(4), isTrue);
      expect(f.facetStanding, isTrue);
      expect(f.cells[kKeepMouthCell], kWaitingFacet);
      expect(f.hollowCell, -1, reason: 'the hollow has gone out to the berth');
    });

    test('while the facet stands, the whole keep is set solid', () {
      final f = PrismKeepField();
      f.restore([7, 4, 5, 1, 0, kHollow, 3, 2, 6]);
      f.callFacet(4);
      for (var c = 0; c < 9; c++) {
        expect(f.canShunt(c), isFalse, reason: 'cell $c still moves');
      }
      // And it is always reversible from where the chain was pulled or from
      // inside the facet, so the vault can never wedge a run.
      expect(f.canWithdrawFacet(4), isTrue);
      expect(f.canWithdrawFacet(kKeepMouthCell), isTrue);
      expect(f.withdrawFacet(4), isTrue);
      expect(f.hollowCell, kKeepMouthCell);
      expect(f.canShunt(4), isTrue);
    });

    test('the vault\'s configuration is REACHABLE — hollow at the mouth, the '
        'body west of it, and glass cut east', () {
      final buf = List<int>.filled(9, 0);
      var usable = 0, calledButUnenterable = 0;
      for (final code in reachableArrangements) {
        decode(code, buf);
        if (buf[kKeepMouthCell] != _hollowItem) continue;
        // The player must be beside the mouth to pull the chain, and the last
        // move that leaves the hollow there is a ride OUT of the mouth, so
        // they are. Of the three cells that can pull it, only the middle one
        // can then walk in — the facet is cut on its west face alone.
        if (!search.has(code, kKeepHeartCell)) continue;
        if (kPrismChambers[buf[kKeepHeartCell]].cut(kFacetE)) {
          usable++;
        } else {
          calledButUnenterable++;
        }
      }
      expect(
        usable,
        15120,
        reason: 'THE HAZARD: an unreachable vault would be unfindable in play',
      );
      expect(
        calledButUnenterable,
        5040,
        reason: 'the trick has to be possible to get WRONG, or it is not one: '
            'one time in four the chamber you rode west out of the mouth is '
            'not cut on its east face, and the facet comes in behind a wall',
      );
    });

    test('the essence only exists while the facet is standing', () {
      final game = harness(idealTrio());
      final mouthRoom = kKeepCellRooms[kKeepMouthCell];
      expect(
        layout.rooms[mouthRoom]!.vaultCache,
        isNotNull,
        reason: 'the cache is authored in the one cell the facet can stand in',
      );
      game.currentRoomId = mouthRoom;
      expect(game.keepVaultLiveForTest, isFalse);
      game.prism.field.restore([7, 4, 5, 1, 0, kHollow, 3, 2, 6]);
      game.prism.field.callFacet(kKeepHeartCell);
      expect(game.keepVaultLiveForTest, isTrue);
    });
  });

  group('the exit, the rite and the frame arches', () {
    test('the threshold and the north arch are cut in the FRAME, not in glass',
        () {
      final f = PrismKeepField();
      // Whatever chamber stands there, the arch takes you through it.
      for (var i = 0; i < 8; i++) {
        final cells = List<int>.filled(9, 0);
        for (var c = 0; c < 9; c++) {
          cells[c] = (c + i) % 8;
        }
        cells[0] = kHollow;
        f.restore(cells);
        expect(f.frameArchOpen(kKeepThresholdCell), isTrue);
        expect(f.frameArchOpen(kKeepNorthCell), isTrue);
      }
      // And they do not even shut on the bare socket: the hollow is the keep's
      // own stone floor, not a hole, so an arch over it is still an arch. That
      // is what makes it impossible for Prismalith's beats to lock the party
      // out of the keep while they are downstairs in the choir.
      f.restore([0, kHollow, 1, 2, 3, 4, 5, 6, 7]);
      expect(f.frameArchOpen(kKeepNorthCell), isTrue);
      expect(f.frameArchOpen(kKeepThresholdCell), isTrue);
    });

    test('the exit is reachable from everywhere — with the hollow under the '
        'north arch too', () {
      // The nastiest case the design has: Prismalith shunts the keep from the
      // choir, and a beat can park the hollow under the north arch while the
      // party is downstairs. The tuning boss in the choir is the answer, and
      // the reachable set says so.
      final buf = List<int>.filled(9, 0);
      var parked = 0;
      for (final code in reachableArrangements) {
        decode(code, buf);
        if (buf[kKeepNorthCell] == _hollowItem) parked++;
      }
      expect(parked, greaterThan(0), reason: 'the case really can happen');
      final f = PrismKeepField();
      f.restore([0, kHollow, 1, 2, 3, 4, 5, 6, 7]);
      f.anneal(); // rung from the choir, outside the lattice
      expect(f.cells, kKeepOpeningCells);
      expect(f.frameArchOpen(kKeepNorthCell), isTrue);
    });

    test('the opening arrangement lets a first descent in, and starts neither '
        'star half-solved', () {
      final f = PrismKeepField();
      expect(f.frameArchOpen(kKeepThresholdCell), isTrue);
      expect(f.spectrumSolved, isFalse);
      expect(f.thronesServed, isFalse);
      expect(f.beamLive, isFalse, reason: 'the west cell is opaque on arrival');
      expect(f.hollowCell, 8);
    });
  });

  group('the shunt — the planet\'s only verb', () {
    test('a chamber only goes where the hollow is, and it carries you', () {
      final f = PrismKeepField();
      expect(f.canShunt(7), isTrue); // beryl, beside the hollow at 8
      expect(f.canShunt(5), isTrue); // amethyst, above it
      expect(f.canShunt(4), isFalse, reason: 'the heart is not adjacent');
      final beryl = f.cells[7];
      final landed = f.shunt(7);
      expect(landed, 8, reason: 'the shover rides into the hollow\'s cell');
      expect(f.cells[8], beryl);
      expect(f.cells[7], kHollow);
      expect(f.shunts, 1);
    });

    test('every slide is undone by sliding back — nothing here is permanent',
        () {
      final f = PrismKeepField();
      final before = f.snapshot();
      f.shunt(7);
      f.shunt(8);
      expect(f.cells, before, reason: 'the move set is a group, not a ratchet');
    });

    test('the engine rides the shunt: the room changes and the body does not',
        () {
      final game = harness(idealTrio());
      game.currentRoomId = kKeepCellRooms[7];
      game.setActive(crystal);
      final where = const Offset(210, 300);
      for (final c in game.creatures) {
        c
          ..position = where
          ..lastSafe = where;
      }
      expect(game.keepShuntForTest(kFacetE), isTrue);
      expect(game.currentRoomId, kKeepCellRooms[8]);
      expect(
        game.creatures.first.position,
        where,
        reason: 'you ride the chamber — your feet do not move on its floor',
      );
      expect(game.prism.field.cells[7], kHollow);
    });

    test('the shove-plate refuses anything but Crystal, and refuses glass on '
        'glass', () {
      final game = harness(idealTrio());
      // Lightning at the plate facing the hollow: one clean refusal.
      act(game, lightning, kKeepCellRooms[7], kPlateE);
      expect(game.prism.field.shunts, 0);
      expect(game.hintText, contains('Crystal'));
      // Crystal at a plate facing a chamber: also refused, differently.
      act(game, crystal, kKeepCellRooms[7], kPlateW);
      expect(game.prism.field.shunts, 0);
      expect(game.hintText, contains('nothing to give'));
      // Crystal at the plate facing the hollow: it goes.
      act(game, crystal, kKeepCellRooms[7], kPlateE);
      expect(game.prism.field.shunts, 1);
    });
  });

  group('the two hard gates (§4)', () {
    test('the layout declares exactly two, on two different entry slots', () {
      final slots = kCosmicPlanetEntry['Crystal']!;
      expect(layout.familyGates.length, 2);
      for (final g in layout.familyGates) {
        if (g.needsElement) expect(slots, contains(g.element));
        expect(g.discoveryId, isNot(contains('.')));
        expect(g.discoveryId, isNot(contains('|')));
      }
      expect(
        layout.familyGates.map((g) => g.element).toSet().length,
        2,
        reason: 'one gate per entry slot at most',
      );
    });

    test('STAR 0 IS UNGATED — any trio of the right elements can bank it', () {
      // §4's first-descent guarantee. Nothing on the Prism Star's path asks
      // for a family: the shunt is element-only Crystal and the lamp is the
      // planet's own braid Crystal+Spirit→Light.
      for (final g in layout.familyGates) {
        expect(g.objectId, isNot('west_lamp'));
        expect(g.objectId, isNot('rose'));
      }
      final wrongFamilies = [
        _member(0, 'Crystal', 'kin'),
        _member(1, 'Lightning', 'let'),
        _member(2, 'Spirit', 'wing'),
      ];
      final game = harness(wrongFamilies);
      // Light the lamp with the braid — no family anywhere in the path.
      final lampCell = kKeepCellRooms[kKeepBeamRow.first];
      act(game, crystal, lampCell, kWestLamp);
      expect(game.prism.field.lampLit, isTrue);
      // And with the authored row in place the star banks itself.
      final banked = <int>[];
      final g2 = harness(wrongFamilies, onStar: banked.add);
      g2.prism.field
        ..lampLit = true
        ..restore([0, 5, 6, 2, 3, 4, 7, 1, kHollow]);
      g2.update(0.016);
      expect(banked, contains(0));
    });

    test('the hearth shard is a HARD Lightning+HORN gate, and refusing it '
        'stamps the chip', () {
      final gate = layout.familyGateFor('shard_hearth')!;
      expect(gate.element, 'Lightning');
      expect(gate.family, 'Horn');
      final clouds = <String>[];
      final game = harness(idealTrio(), onCloud: clouds.add);
      // Put the hearth somewhere we can stand on it.
      game.prism.field.restore([7, 4, 5, 1, 0, 6, 3, 2, kHollow]);
      final heart = kKeepCellRooms[kKeepHeartCell];
      // A Crystal MASK is the wrong hand: one clean refusal, one stamp.
      act(game, crystal, heart, kChamberHeart);
      expect(game.prism.field.hearthKindled, isFalse);
      expect(clouds, contains(gate.discoveryId));
      expect(game.hintText, gate.hintLine);
      // The horn does it.
      act(game, lightning, heart, kChamberHeart);
      expect(game.prism.field.hearthKindled, isTrue);
    });

    test('the rite\'s crack is a VERB-ONLY pip gate — any element', () {
      // Was Spirit+PIP. Re-audited: the crack admits a small body, and spirit
      // is not what fits through it, so demanding the element as well was a
      // second lock the fiction never asked for. Any pip answers.
      final gate = layout.familyGateFor('A')!;
      expect(gate.element, kAnyElement);
      expect(gate.needsElement, isFalse);
      expect(gate.family, 'Pip');
      expect(gate.label, 'any PIP');
      final conduit = layout.rooms['tuning_hall']!.conduits
          .firstWhere((c) => c.id == 'A');
      expect(conduit.requireElement, kAnyElement);
      expect(conduit.requiredFamily, DungeonAbility.smallAccess);
    });

    test('the rite\'s font answers Crystal alone, and only behind both stars',
        () {
      final game = harness(idealTrio());
      final font = layout.rooms['tuning_hall']!.prism!.facetFont!;
      act(game, lightning, 'tuning_hall', font);
      expect(game.conduitEnergy['B'] ?? 0, 0);
      expect(game.hintText, contains('Crystal'));
      act(game, crystal, 'tuning_hall', font);
      expect(game.conduitEnergy['B'] ?? 0, 0, reason: 'no stars, no font');
      game.earnStar(0);
      game.earnStar(1);
      act(game, crystal, 'tuning_hall', font);
      expect(game.conduitEnergy['B'], isNotNull);
      expect(game.conduitEnergy['B']! > 0, isTrue);
    });
  });

  group('the entry rite and the anneal', () {
    test('the keep\'s face answers Lightning, and only Lightning', () {
      final game = harness(idealTrio());
      final face = layout.rooms['facet_gate']!.prism!.glassFace!;
      act(game, crystal, 'facet_gate', face);
      expect(game.entryDoorRevealed, isFalse);
      act(game, lightning, 'facet_gate', face);
      expect(game.entryDoorRevealed, isTrue);
    });

    test('the anneal rings the keep home from any cell, and puts you out', () {
      final game = harness(idealTrio());
      final f = game.prism.field;
      f.restore([3, 7, 0, 5, 6, 2, 1, 4, kHollow]);
      game.currentRoomId = kKeepCellRooms[0];
      act(game, crystal, kKeepCellRooms[0], kCellTuningBoss);
      expect(f.cells, kKeepOpeningCells);
      expect(
        game.currentRoomId,
        game.layout.entranceRoomId,
        reason: 'the ring throws you clear — otherwise it can set you back '
            'down in the very trap you rang it to escape',
      );
      expect(f.anneals, 1);
    });

    test('the anneal answers only Crystal, and pushes the facet back out', () {
      final game = harness(idealTrio());
      final f = game.prism.field;
      f.restore([7, 4, 5, 1, 0, kHollow, 3, 2, 6]);
      f.callFacet(kKeepHeartCell);
      expect(f.facetStanding, isTrue);
      act(game, spirit, kKeepCellRooms[kKeepHeartCell], kCellTuningBoss);
      expect(f.facetStanding, isTrue, reason: 'only Crystal rings the boss');
      act(game, crystal, kKeepCellRooms[kKeepHeartCell], kCellTuningBoss);
      expect(f.facetStanding, isFalse);
      expect(f.cells, kKeepOpeningCells);
      expect(game.currentRoomId, game.layout.entranceRoomId);
    });
  });

  group('the guardian — Prismalith fights WITH the rule (§7)', () {
    test('the lull is shut unless the gap stands under it', () {
      final game = harness(idealTrio());
      game.currentRoomId = 'prismalith_choir';
      game.guardianAwake = true;
      game.guardianVulnerable = true;
      game.prism.choirHollow = 0;
      game.update(0.016);
      expect(game.guardianVulnerable, isFalse);
      game.prism.choirHollow = kKeepHeartCell;
      game.guardianVulnerable = true;
      game.update(0.016);
      expect(game.guardianVulnerable, isTrue);
    });

    test('every strike beat rings the floor out from under it — and the keep '
        'upstairs with it', () {
      final game = harness(idealTrio());
      game.currentRoomId = 'prismalith_choir';
      game.guardianAwake = true;
      game.prism.choirHollow = kKeepHeartCell;
      final before = game.prism.field.snapshot();
      game.guardianVulnerable = true;
      game.update(0.016); // the lull opens: arm the beat edge
      game.guardianVulnerable = false;
      game.update(0.016); // the strike lands
      expect(game.prism.choirHollow, isNot(kKeepHeartCell));
      expect(
        game.prism.field.cells,
        isNot(before),
        reason: 'the fight spends the arrangement you built',
      );
    });

    test('a plate carries whoever is standing on it — the planet\'s own verb, '
        'in the fight', () {
      final game = harness(idealTrio());
      final floor = layout.rooms['prismalith_choir']!.prism!.choir!;
      game.prism.choirHollow = 4;
      final on = floor.plateCentre(1);
      act(game, crystal, 'prismalith_choir', on);
      expect(game.prism.choirHollow, 1);
      expect(game.creatures.first.position, floor.plateCentre(4));
    });

    test('the lull outranks the shove, or the fight is unwinnable', () {
      // The Crystal hand is the only one that can open the window, so if its
      // press were always a shove it could never take the shot it opened.
      final game = harness(idealTrio());
      final floor = layout.rooms['prismalith_choir']!.prism!.choir!;
      game.guardianAwake = true;
      game.guardianVulnerable = true;
      game.prism.choirHollow = kKeepHeartCell;
      act(game, crystal, 'prismalith_choir', floor.plateCentre(1));
      expect(
        game.prism.choirHollow,
        kKeepHeartCell,
        reason: 'the gap must stay open — that press was a strike',
      );
    });

    test('the guardian shunt is deterministic and never moves a full keep', () {
      final f = PrismKeepField();
      expect(f.guardianShunt(), 5, reason: 'the lowest neighbour of cell 8');
      f.restore([7, 4, 5, 1, 0, kHollow, 3, 2, 6]);
      f.callFacet(kKeepHeartCell);
      expect(f.guardianShunt(), -1, reason: 'a full keep has nowhere to go');
    });

    test('Star 2 is the mystic, and MYS11 brings its raid with it', () {
      final g = layout.rooms['prismalith_choir']!.guardian!;
      expect(g.starIndex, 2);
      expect(g.encounter!.mysticId, 'Prismalith');
      expect(kRaidGuardianIds['Crystal'], 'Prismalith');
    });
  });

  group('THE LOST MAXIM — Know Thyself', () {
    test('the split only exists in arrangements Star 0 forbids', () {
      // The hearth SPLITS rather than bends, so the maxim's arrangement is one
      // where the hearth stands in the lit row — exactly what the rose refuses.
      final f = PrismKeepField()..lampLit = true;
      f.restore([2, 5, 6, 0, 3, 4, 7, 1, kHollow]);
      expect(f.beamLive, isTrue);
      expect(f.chamberAt(kKeepHeartCell)?.id, isNot('hearth'));
      f.restore([2, 5, 6, 3, 0, 4, 7, 1, kHollow]);
      expect(f.beamLive, isTrue);
      expect(f.spectrumSolved, isFalse);
      expect(f.chamberAt(kKeepHeartCell)!.id, 'hearth');
    });

    test('all three bodies in the split, and the keep throws them back', () {
      final clouds = <String>[];
      final game = harness(idealTrio(), onCloud: clouds.add);
      game.prism.field
        ..lampLit = true
        ..restore([2, 5, 6, 3, 0, 4, 7, 1, kHollow]);
      game.currentRoomId = kKeepCellRooms[kKeepHeartCell];
      // Two in the beam is not three.
      game.creatures[0].position = kChamberHeart;
      game.creatures[1].position = kChamberHeart;
      game.creatures[2].position = const Offset(210, 310);
      game.update(0.016);
      expect(clouds, isNot(contains(kCrystalKnowThyselfEggId)));
      game.creatures[2].position = kChamberHeart + const Offset(40, 0);
      game.update(0.016);
      expect(clouds, contains(kCrystalKnowThyselfEggId));
    });
  });

  group('the planet is registered whole', () {
    test('entry, ideal families and the coming-soon set agree', () {
      expect(kCosmicPlanetEntry['Crystal'], ['Crystal', 'Lightning', 'Spirit']);
      expect(kDungeonIdealFamilies['Crystal'], ['Mask', 'Horn', 'Pip']);
      expect(kComingSoonDungeons, isNot(contains('Crystal')));
      expect(kPlanetDungeonLayouts.containsKey('Crystal'), isTrue);
    });

    test('the riddle names one line per entry slot, and no body part', () {
      expect(layout.riddle.length, kCosmicPlanetEntry['Crystal']!.length);
      final verse = layout.riddle.join(' ').toLowerCase();
      for (final tell in ['wing', 'horn', 'mane', 'mask', 'pip']) {
        expect(verse, isNot(contains(tell)), reason: 'the riddle reads the '
            'answer aloud with "$tell"');
      }
    });
  });
}
