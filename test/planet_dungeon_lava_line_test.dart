// THE MOLTEN RELIQUARY — the foundry line, pinned, and the pour budget PROVED.
//
// Two jobs, in the shape `burn_field_test.dart` set:
//
//  1. Every claim the design makes, checked against the real rules module:
//     the arms make different metal, a mold takes one form, cold metal is a
//     road AND a plug, a re-melt undoes the world but never refunds a charge,
//     and the tail switch cannot be thrown from the floor.
//
//  2. THE PROOF. A breadth-first walk of the WHOLE reachable state space of
//     the line — every pour programme (48 switch settings × every channel an
//     Ice mane could set it in), every re-melt, every key, every ward —
//     deduplicated by state signature. From that we take:
//       · the minimum number of pours that banks Stars 1 and 2  (must be 4),
//       · that the crucible's 5 therefore leaves exactly one spare,
//       · that no 3-pour run exists, so the budget really does bite,
//       · that MORE THAN ONE order of the same four works (the §5.5 ledger
//         forbids Lava handing the player a sequence — Fire owns that seat),
//       · that both ways onto the catwalk are real,
//       · and that a party with no Ice mane still takes Star 1 and cannot
//         take Star 2 (the one declared hard gate, doing exactly its job).
//
//     The search model is deliberately PERMISSIVE about where a mane may
//     stand, which makes its minimum a sound LOWER bound; the explicit
//     four-pour script below, walked against the real geometry, is the
//     matching upper bound.
//
//  3. And the geometry itself: a flood fill over each room proves the star,
//     the tail lever and the hidden mold are genuinely unreachable until the
//     casting that opens them exists — the puzzle cannot be walked around.

import 'dart:ui';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_lava.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ─────────────────────────────────────────────────

FoundryState _fresh() => FoundryState(kLavaLine)..wakeTap();

/// Every switch setting a player could leave the line in.
Iterable<Map<String, int>> _allConfigs() sync* {
  for (var arm = 0; arm < 2; arm++) {
    for (var shroud = 0; shroud < 2; shroud++) {
      for (var damper = 0; damper < 2; damper++) {
        for (var sluice = 0; sluice < 3; sluice++) {
          for (var tail = 0; tail < 2; tail++) {
            yield {
              'y_yard': arm,
              'chiller': shroud,
              'damper': damper,
              'y_sluice': sluice,
              'y_return': tail,
            };
          }
        }
      }
    }
  }
}

/// Channels a mane could plausibly reach from walkable ground. Permissive on
/// purpose (see the header): extra options can only ever make the solver's
/// minimum smaller, so a minimum of four is a floor, not a guess.
const List<String?> _freezeSpots = [
  null,
  'ch_tap',
  'ch_sump',
  'ch_north',
  'ch_chill_out',
  'ch_mill_in',
  'ch_mill_mid',
  'ch_damper_clean',
  'ch_runner_a',
  'ch_tail',
];

/// One reachable point of the search: the world, and how it was got to.
class _Step {
  const _Step(this.state, this.trail);
  final FoundryState state;
  final List<String> trail;
}

/// Breadth-first over the whole line. [maneAllowed] false models a party with
/// no Ice mane (nothing may be set by hand).
List<_Step> _explore({
  bool maneAllowed = true,
  int maxPours = kLavaPourBudget,
}) {
  final start = _fresh();
  final seen = <String>{start.signature};
  final out = <_Step>[_Step(start, const [])];
  final queue = <_Step>[out.first];

  void push(FoundryState s, List<String> trail) {
    if (!seen.add(s.signature)) return;
    final step = _Step(s, trail);
    out.add(step);
    queue.add(step);
  }

  while (queue.isNotEmpty) {
    final step = queue.removeAt(0);
    final s = step.state;

    // FREE MOVES — they cost no charge, so they never bound the answer.
    if (!s.dieWoken) {
      push(s.clone()..dieWoken = true, [...step.trail, 'wake-die']);
    }
    for (final id in s.castings.keys.toList()) {
      final c = s.clone()..remelt(id);
      push(c, [...step.trail, 'melt:$id']);
    }
    for (final mold in ['mold_key', 'mold_reliquary']) {
      if (s.molds[mold] == null || s.carried != null) continue;
      final c = s.clone();
      if (c.takeKey(mold)) push(c, [...step.trail, 'take:$mold']);
    }
    for (final ward in ['gantry', 'reliquary']) {
      if (s.carried != ward) continue;
      final c = s.clone();
      if (c.turnWard(ward)) push(c, [...step.trail, 'turn:$ward']);
    }

    // POURS — the only move that costs.
    if (s.poursLeft <= 0 || kLavaPourBudget - s.poursLeft >= maxPours) continue;
    for (final cfg in _allConfigs()) {
      for (final freeze in _freezeSpots) {
        if (freeze != null && !maneAllowed) continue;
        final c = s.clone();
        final ev = runFoundryPlan(c, FoundryPlan(cfg, freezeOn: freeze));
        push(c, [
          ...step.trail,
          'pour:${cfg.values.join()}:${freeze ?? '-'}:${ev.name}',
        ]);
      }
    }
  }
  return out;
}

int _poursUsed(FoundryState s) => kLavaPourBudget - s.poursLeft;

void main() {
  group('the line', () {
    test('the north arm runs PLAIN and the south arm WARDS it', () {
      final north = _fresh();
      runFoundryPlan(
        north,
        const FoundryPlan({'y_yard': 0, 'chiller': 0, 'y_sluice': 0}),
      );
      expect(
        north.cast('span_a'),
        isTrue,
        reason: 'a plain pour fills the span form',
      );

      final south = _fresh()..dieWoken = true;
      runFoundryPlan(
        south,
        const FoundryPlan({'y_yard': 1, 'damper': 0, 'y_sluice': 1}),
      );
      expect(
        south.cast('gantry'),
        isTrue,
        reason: 'the die wards it, and only warded metal makes a key',
      );
    });

    test('the die is dead until it is driven, and then never sleeps', () {
      final s = _fresh();
      runFoundryPlan(
        s,
        const FoundryPlan({'y_yard': 1, 'damper': 0, 'y_sluice': 1}),
      );
      expect(
        s.cast('gantry'),
        isFalse,
        reason: 'plain metal cannot take a ward',
      );
      expect(
        s.molds['mold_key'],
        isNotNull,
        reason: 'and the ruined casting is sitting in the form',
      );
    });

    test('the purge gasses whatever takes it, and gas fills nothing', () {
      final s = _fresh()..dieWoken = true;
      runFoundryPlan(
        s,
        const FoundryPlan({'y_yard': 1, 'damper': 1, 'y_sluice': 1}),
      );
      expect(s.cast('gantry'), isFalse);
    });

    test('a mold takes ONE form, and a spoiled one must be melted out', () {
      final s = _fresh()..dieWoken = true;
      // Warded metal into the span form: wrong, and it ruins the form.
      runFoundryPlan(
        s,
        const FoundryPlan({'y_yard': 1, 'damper': 0, 'y_sluice': 0}),
      );
      expect(s.cast('span_a'), isFalse);
      // A second, correct pour cannot take: the form is full of junk.
      runFoundryPlan(
        s,
        const FoundryPlan({'y_yard': 0, 'chiller': 0, 'y_sluice': 0}),
      );
      expect(s.cast('span_a'), isFalse);
      // Melt it out and the form is a form again.
      s.remelt('cast:span_a');
      runFoundryPlan(
        s,
        const FoundryPlan({'y_yard': 0, 'chiller': 0, 'y_sluice': 0}),
      );
      expect(s.cast('span_a'), isTrue);
      expect(
        _poursUsed(s),
        3,
        reason: 'the world came back; the charges did not',
      );
    });

    test('COLD METAL IS A PLUG: the chiller kills its own arm', () {
      final s = _fresh();
      runFoundryPlan(s, const FoundryPlan({'y_yard': 0, 'chiller': 1}));
      expect(s.plugged('ch_north'), isTrue);
      expect(s.access, contains('catwalk'));
      // Everything after it congeals against the slug.
      runFoundryPlan(
        s,
        const FoundryPlan({'y_yard': 0, 'chiller': 0, 'y_sluice': 0}),
      );
      expect(
        s.cast('span_a'),
        isFalse,
        reason: 'the plain arm is shut for the rest of the run',
      );
      // ...until a Lava heart takes it back out.
      s.remelt('plug:ch_north');
      expect(s.access, isNot(contains('catwalk')));
      runFoundryPlan(
        s,
        const FoundryPlan({'y_yard': 0, 'chiller': 0, 'y_sluice': 0}),
      );
      expect(s.cast('span_a'), isTrue);
    });

    test('THE ORDER FALLS OUT OF THAT: a plugged sump refuses the key', () {
      final s = _fresh()
        ..dieWoken = true
        ..wardsTurned.add('gantry'); // catwalk reached the cheap way
      // Lay the road first — the mistake the planet is about.
      runFoundryPlan(
        s,
        const FoundryPlan({
          'y_yard': 1,
          'damper': 0,
          'y_sluice': 2,
          'y_return': 1,
        }, freezeOn: 'ch_sump'),
      );
      expect(s.access, contains('sump'));
      runFoundryPlan(
        s,
        const FoundryPlan({
          'y_yard': 1,
          'damper': 0,
          'y_sluice': 2,
          'y_return': 1,
        }),
      );
      expect(
        s.cast('reliquary'),
        isFalse,
        reason: 'the key pour congeals against your own road',
      );
    });

    test('the tail switch cannot be thrown from the floor', () {
      final s = _fresh();
      expect(s.canSet('y_return'), isFalse);
      expect(s.cycleSwitch('y_return'), isFalse);
      s.wardsTurned.add('gantry');
      expect(s.canSet('y_return'), isTrue);
    });

    test('the crucible never refills', () {
      final s = _fresh();
      for (var i = 0; i < kLavaPourBudget; i++) {
        expect(s.tap(), isTrue);
        s.pour = null;
      }
      expect(s.tap(), isFalse);
      expect(s.poursLeft, 0);
    });
  });

  group('THE PROOF — the pour budget', () {
    final reachable = _explore();
    final solved = reachable.where((s) => foundryWorksDone(s.state)).toList();

    test(
      'the works CAN be finished, and the cheapest way costs four pours',
      () {
        expect(
          solved,
          isNotEmpty,
          reason: 'an unsolvable dungeon is unshippable',
        );
        final min = solved
            .map((s) => _poursUsed(s.state))
            .reduce((a, b) => a < b ? a : b);
        expect(min, 4, reason: 'the tightest full plan is four pours');
        expect(
          min,
          lessThan(kLavaPourBudget),
          reason: 'the crucible must fund the works',
        );
        expect(
          kLavaPourBudget - min,
          1,
          reason: 'exactly one spare: a blunder is survivable, two are not',
        );
      },
    );

    test('and it CANNOT be done in three — the budget really is scarce', () {
      final cheap = _explore(
        maxPours: 3,
      ).where((s) => foundryWorksDone(s.state)).toList();
      expect(
        cheap,
        isEmpty,
        reason: 'four separate castings, and no pour can do two jobs',
      );
    });

    test(
      'more than one ORDER works — the player authors it, is not handed it',
      () {
        // §5.5 ledger: Fire owns sequence-execution. Lava may not hand out an
        // order, so the same four pours must land in more than one arrangement.
        final orders = <String>{};
        for (final s in solved) {
          if (_poursUsed(s.state) != 4) continue;
          orders.add(s.trail.where((m) => m.startsWith('pour:')).join('>'));
        }
        expect(
          orders.length,
          greaterThan(1),
          reason: 'a single legal sequence would be an order-memory puzzle',
        );
      },
    );

    test('both ways onto the catwalk are real (bridge OR key)', () {
      var viaChill = false, viaGantry = false;
      for (final s in solved) {
        if (_poursUsed(s.state) != 4) continue;
        if (s.state.plugged('ch_north')) viaChill = true;
        if (s.state.wardsTurned.contains('gantry')) viaGantry = true;
      }
      expect(viaChill, isTrue, reason: 'freeze the north arm and walk it');
      expect(viaGantry, isTrue, reason: 'or cast the gantry key instead');
    });

    test('every full plan pays for exactly the four things it must', () {
      for (final s in solved) {
        if (_poursUsed(s.state) != 4) continue;
        expect(s.state.cast('span_a'), isTrue);
        expect(s.state.access, contains('sump'));
        // (Catwalk access is not asserted on the END state: melting the
        // north plug back out is free, and a player may well do it after the
        // tail switch is set. That it was HELD at some point is guaranteed by
        // the tail switch's own access check — see 'the tail switch cannot be
        // thrown from the floor'.)
      }
    });

    test('the Black Glass maxim and the works cannot share one run', () {
      // §6 egg 8 wants three quenched pours. That is the sacrifice, and the
      // budget is authored so it reads as one.
      expect(kLavaPourBudget - kLavaBlackGlassQuenches, lessThan(4));
    });
  });

  group('THE ONE HARD GATE (§4)', () {
    test('with no Ice mane, Star 1 still stands and Star 2 does not', () {
      final maneless = _explore(maneAllowed: false);
      expect(
        maneless.any((s) => s.state.cast('span_a')),
        isTrue,
        reason: 'Star 1 must be earnable by ANY correct-element trio',
      );
      expect(
        maneless.any((s) => foundryWorksDone(s.state)),
        isFalse,
        reason: 'only the sump crossing is gated — and it is the gate',
      );
      // And the gate is declared where the descent panel can find it.
      final gate = kLavaLayout.familyGateFor('hand_chill');
      expect(gate, isNotNull);
      expect(gate!.discoveryId, 'gate:ice_mane');
      expect(kLavaLayout.familyGates.length, 1);
    });
  });

  _engineRun();

  group('the geometry cannot be walked around', () {
    /// Flood-fill [room] on a coarse grid, honouring the channels.
    Set<int> reachFrom(FoundryState s, DungeonRoom room, Offset from) {
      const step = 10.0;
      final b = room.bounds;
      final cols = (b.width / step).floor();
      int key(int c, int r) => r * cols + c;
      bool open(int c, int r) {
        final p = Offset(
          b.left + c * step + step / 2,
          b.top + r * step + step / 2,
        );
        if (!b.deflate(14).contains(p)) return false;
        for (final w in room.walls) {
          if (w.contains(p)) return false;
        }
        return !foundryBlocks(s, room.id, p);
      }

      final rows = (b.height / step).floor();
      final start = (
        ((from.dx - b.left) / step).floor().clamp(0, cols - 1),
        ((from.dy - b.top) / step).floor().clamp(0, rows - 1),
      );
      final seen = <int>{};
      final queue = <(int, int)>[];
      if (open(start.$1, start.$2)) {
        seen.add(key(start.$1, start.$2));
        queue.add(start);
      }
      while (queue.isNotEmpty) {
        final (c, r) = queue.removeLast();
        for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final nc = c + d.$1, nr = r + d.$2;
          if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
          if (!seen.add(key(nc, nr))) continue;
          if (!open(nc, nr)) {
            seen.remove(key(nc, nr));
            continue;
          }
          queue.add((nc, nr));
        }
      }
      return seen;
    }

    bool canWalk(FoundryState s, String roomId, Offset from, Offset to) {
      final room = kLavaLayout.rooms[roomId]!;
      const step = 10.0;
      final b = room.bounds;
      final cols = (b.width / step).floor();
      final seen = reachFrom(s, room, from);
      final c = ((to.dx - b.left) / step).floor();
      final r = ((to.dy - b.top) / step).floor();
      return seen.contains(r * cols + c);
    }

    test('the Ember Star is across the runner and nowhere else', () {
      final entry = kLavaLayout.rooms['stamp_mill']!.doors
          .firstWhere((d) => d.targetRoomId == 'mold_floor')
          .targetSpawn;
      final star = kLavaLayout.rooms['mold_floor']!.foundryStar!.position;
      final s = _fresh();
      expect(
        canWalk(s, 'mold_floor', entry, star),
        isFalse,
        reason: 'without the span there is no way over the runner',
      );
      runFoundryPlan(
        s,
        const FoundryPlan({'y_yard': 0, 'chiller': 0, 'y_sluice': 0}),
      );
      expect(s.cast('span_a'), isTrue);
      expect(
        canWalk(s, 'mold_floor', entry, star),
        isTrue,
        reason: 'and with it, one crossing, right at the sluice',
      );
    });

    test('the tail lever hangs beyond the north channel', () {
      final entry = kLavaLayout.rooms['switch_yard']!.doors
          .firstWhere((d) => d.targetRoomId == 'chill_house')
          .targetSpawn;
      final lever = kLavaLine.node('y_return').leverAt!;
      final s = _fresh();
      expect(canWalk(s, 'chill_house', entry, lever), isFalse);
      runFoundryPlan(s, const FoundryPlan({'y_yard': 0, 'chiller': 1}));
      expect(
        canWalk(s, 'chill_house', entry, lever),
        isTrue,
        reason: 'the frozen pour IS the catwalk stair',
      );
    });

    test('the hidden mold sits across the sump, unreachable on arrival', () {
      final spawn = kLavaLayout.entranceSpawn;
      final mold = kLavaLine.node('mold_reliquary').position;
      final s = _fresh();
      expect(
        canWalk(s, 'tap_head', spawn, mold),
        isFalse,
        reason: 'you can see it from the first room and never touch it',
      );
      // A pour set by hand in the sump channel is the only way over.
      s.pour = LivePour(channelId: 'ch_sump', form: PourForm.plain)..t = 0.5;
      s.freezeHere();
      expect(canWalk(s, 'tap_head', spawn, mold), isTrue);
    });

    test('a channel that crosses a doorway MEETS that doorway', () {
      // Reported from play, twice, from two different rooms: *"in tap head
      // there are two flowing pipes, then I come out of the door and they're
      // both gone and there's one right above me."* The metal was leaving by
      // the correct WALL and arriving on the correct wall — and still made no
      // sense, because it met that wall a long way from the door you walked
      // through. Worst case was 466px; the tap head's own feed ran along the
      // ceiling and entered the yard just above the doorway, so it appeared
      // to jump as you crossed.
      //
      // The fix in every case is the one the report suggested: bring the run
      // DOWN to the door before it leaves. Which is only possible because a
      // channel is no longer an absolute wall (see `FoundryBridge`).
      double gapTo(Rect a, Rect b) {
        final dx = a.right < b.left
            ? b.left - a.right
            : (b.right < a.left ? a.left - b.right : 0.0);
        final dy = a.bottom < b.top
            ? b.top - a.bottom
            : (b.bottom < a.top ? a.top - b.bottom : 0.0);
        return dx > dy ? dx : dy;
      }

      Rect? doorBetween2(String from, String to) {
        for (final d in kLavaLayout.rooms[from]!.doors) {
          if (d.targetRoomId == to) return d.rect;
        }
        return null;
      }

      const tolerance = 100.0;
      for (final ch in kLavaLine.channels) {
        for (var i = 0; i < ch.segments.length - 1; i++) {
          final a = ch.segments[i], b = ch.segments[i + 1];
          if (a.roomId == b.roomId) continue;
          final out = doorBetween2(a.roomId, b.roomId);
          final into = doorBetween2(b.roomId, a.roomId);
          if (out != null) {
            expect(
              gapTo(a.rect, out),
              lessThanOrEqualTo(tolerance),
              reason:
                  '${ch.id} leaves ${a.roomId} ${gapTo(a.rect, out).toInt()}px '
                  'from the door it crosses — the metal will look like it '
                  'jumps when you walk through',
            );
          }
          if (into != null) {
            expect(
              gapTo(b.rect, into),
              lessThanOrEqualTo(tolerance),
              reason:
                  '${ch.id} arrives in ${b.roomId} ${gapTo(b.rect, into).toInt()}px '
                  'from the door you came through',
            );
          }
        }
      }
    });

    test('no channel cuts a room in half — every arrival can reach every '
        'lever and every door in the room it lands in', () {
      // THE RISK IN MOVING METAL AROUND. A channel is a wall, so re-routing
      // one to line up with a door can quietly strand the party on the wrong
      // side of the room it lands in — and nothing else in this file would
      // notice, because the pour still runs and the solver still solves.
      //
      // Fixtures being out of the channel (the test below) is not the same
      // question: a lever can stand on perfectly good floor that you cannot
      // walk to.
      final s = _fresh();
      for (final room in kLavaLayout.rooms.values) {
        // Every way you can arrive here.
        bool wardedPair(String a, String b) {
          final pair = {a, b};
          return pair.containsAll({'chill_house', 'mold_floor'}) ||
              pair.containsAll({'mold_floor', 'slag_reliquary'});
        }

        // Arrivals you did NOT have to earn. Coming through a warded door
        // lands you on ground you bought — the gantry puts you on the
        // catwalk, above the north channel — and what is reachable from
        // there is the puzzle rather than a severed room.
        final arrivals = <Offset>[
          if (room.id == kLavaLayout.entranceRoomId) kLavaLayout.entranceSpawn,
          for (final other in kLavaLayout.rooms.values)
            for (final d in other.doors)
              // …and not out of the guardian's room either: you only stand
              // in there having crossed the runner, so coming back is an
              // earned arrival like the warded ones.
              if (d.targetRoomId == room.id &&
                  !wardedPair(other.id, room.id) &&
                  other.guardian == null)
                d.targetSpawn,
        ];
        for (final from in arrivals) {
          expect(
            foundryBlocks(s, room.id, from),
            isFalse,
            reason: '${room.id}: you arrive at $from inside a channel',
          );
          for (final n in kLavaLine.nodesIn(room.id)) {
            final lever = n.leverAt;
            if (lever == null) continue;
            // A lever with `leverAccess` is DELIBERATELY out of reach until
            // you have earned the token — the tail switch hangs beyond the
            // north channel and wants the catwalk. That is the puzzle, not a
            // severed room; the test above it guards that one on purpose.
            if (n.leverAccess != null) continue;
            expect(
              canWalk(s, room.id, from, lever),
              isTrue,
              reason:
                  '${room.id}: arriving at $from you cannot reach '
                  '${n.id}\'s lever at $lever',
            );
          }
          for (final d in room.doors) {
            // A WARDED door is earned, and on this planet the way TO it is
            // often part of what you earn: the gantry hangs beyond the north
            // channel and wants a road frozen across before you can even
            // stand at it. Those are gates, not severed rooms.
            if (wardedPair(room.id, d.targetRoomId)) continue;
            // The finale door is star-gated and stands beyond the runner on
            // purpose — the Ember Star and the way to the guardian are the
            // same side of the same gap, which is the room's whole design.
            if (kLavaLayout.rooms[d.targetRoomId]!.guardian != null) continue;
            expect(
              canWalk(s, room.id, from, d.rect.center),
              isTrue,
              reason:
                  '${room.id}: arriving at $from you cannot reach the door '
                  'to ${d.targetRoomId}',
            );
          }
        }
      }
    });

    test('the metal and the party leave a room by the same side', () {
      // REPORTED FROM PLAY. In the switch yard you set the lever to the mill
      // arm, the channel running EAST lit up, you followed it east — and
      // arrived in the chill house, which is fed by the OTHER arm and was
      // therefore dark. Three crossings were like this: the metal left by one
      // wall and the door to the room it fed was in another.
      //
      // On a planet whose entire puzzle is following metal, that is not a
      // blemish, it is the puzzle lying. A channel that crosses between two
      // rooms must leave by the side their door is on, and arrive by the side
      // the door on the far end is on.
      String sideOf(Rect bounds, Rect r) {
        final d = <String, double>{
          'W': (r.left - bounds.left).abs(),
          'E': (bounds.right - r.right).abs(),
          'N': (r.top - bounds.top).abs(),
          'S': (bounds.bottom - r.bottom).abs(),
        };
        return d.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
      }

      Rect? doorBetween(String from, String to) {
        for (final d in kLavaLayout.rooms[from]!.doors) {
          if (d.targetRoomId == to) return d.rect;
        }
        return null;
      }

      for (final ch in kLavaLine.channels) {
        // Walk the segments in flow order and find each room hand-off.
        for (var i = 0; i < ch.segments.length - 1; i++) {
          final a = ch.segments[i];
          final b = ch.segments[i + 1];
          if (a.roomId == b.roomId) continue;
          final ra = kLavaLayout.rooms[a.roomId]!;
          final rb = kLavaLayout.rooms[b.roomId]!;
          final out = sideOf(ra.bounds, a.rect);
          final into = sideOf(rb.bounds, b.rect);

          final doorOut = doorBetween(a.roomId, b.roomId);
          final doorIn = doorBetween(b.roomId, a.roomId);
          expect(
            doorOut,
            isNotNull,
            reason:
                '${ch.id} runs ${a.roomId} → ${b.roomId} with no door between '
                'them — metal can get somewhere the party cannot',
          );
          expect(
            sideOf(ra.bounds, doorOut!),
            out,
            reason:
                '${ch.id} leaves ${a.roomId} by $out but the door to '
                '${b.roomId} is on ${sideOf(ra.bounds, doorOut)}',
          );
          if (doorIn != null) {
            expect(
              sideOf(rb.bounds, doorIn),
              into,
              reason:
                  '${ch.id} enters ${b.roomId} by $into but the door back to '
                  '${a.roomId} is on ${sideOf(rb.bounds, doorIn)}',
            );
          }
        }
      }
    });

    test('every fixture a player must touch stands on walkable ground', () {
      final s = _fresh();
      for (final n in kLavaLine.nodes) {
        final lever = n.leverAt;
        if (lever == null) continue;
        expect(
          foundryBlocks(s, n.roomId, lever),
          isFalse,
          reason: '${n.id}\'s lever stands in the channel',
        );
      }
      for (final room in kLavaLayout.rooms.values) {
        final star = room.foundryStar;
        if (star != null) {
          expect(foundryBlocks(s, room.id, star.position), isFalse);
        }
        final cache = room.vaultCache;
        if (cache != null) expect(foundryBlocks(s, room.id, cache), isFalse);
        for (final d in room.doors) {
          expect(
            foundryBlocks(s, d.targetRoomId, d.targetSpawn),
            isFalse,
            reason: '${room.id} → ${d.targetRoomId} spawns in running metal',
          );
        }
      }
    });
  });
}

// ── The run, played against the real engine ─────────────────
//
// The state-space proof above walks the RULES. This walks the GAME: the real
// verbs, the real refusals, the real doors, the real guardian — so a line
// that solves on paper and does not answer the UTILITY button cannot ship.

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

/// The §6.2 ideal trio: Lavahorn · Earthmask · Icemane.
List<CosmicPartyMember> _idealTrio() => [
  _member(0, 'Lava', 'horn'),
  _member(1, 'Earth', 'mask'),
  _member(2, 'Ice', 'mane'),
];

PlanetDungeonGame _harness(
  List<CosmicPartyMember> party, {
  void Function(int)? onStar,
  void Function(String)? onCloud,
}) {
  final game = PlanetDungeonGame(
    element: 'Lava',
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

void _engineRun() {
  group('the run, played against the real engine', () {
    const lava = 0, ice = 2;
    const earth = 1;

    /// Stand the trio at [pos] in [roomId] and press UTILITY as [idx].
    void actAt(PlanetDungeonGame g, String roomId, int idx, Offset pos) {
      g.currentRoomId = roomId;
      for (final c in g.creatures) {
        c
          ..position = pos
          ..lastSafe = pos;
      }
      g.setActive(idx);
      g.activateAbility();
      g.update(1 / 60);
    }

    void standIn(PlanetDungeonGame g, String roomId, Offset pos) {
      g.currentRoomId = roomId;
      for (final c in g.creatures) {
        c
          ..position = pos
          ..lastSafe = pos;
      }
    }

    /// Let the works run until the charge is spent.
    void runOut(PlanetDungeonGame g, [double limit = 90]) {
      var t = 0.0;
      while (g.works.line.pour != null && t < limit) {
        g.update(1 / 60);
        t += 1 / 60;
      }
      g.update(1 / 60);
    }

    /// Let the works run until the charge reaches [channelId].
    void runTo(PlanetDungeonGame g, String channelId, [double limit = 90]) {
      var t = 0.0;
      while (g.works.line.pour != null &&
          g.works.line.pour!.channelId != channelId &&
          t < limit) {
        g.update(1 / 60);
        t += 1 / 60;
      }
    }

    /// Throw a lever, as the switchman, until it reads [want].
    void setLever(PlanetDungeonGame g, String nodeId, int want) {
      final n = kLavaLine.node(nodeId);
      for (var i = 0; i < 4 && g.works.line.settingOf(nodeId) != want; i++) {
        actAt(g, n.roomId, earth, n.leverAt!);
      }
      expect(
        g.works.line.settingOf(nodeId),
        want,
        reason: '$nodeId would not sit at $want',
      );
    }

    final tapAt = kLavaLine.node('tap').position + const Offset(0, 60);

    test('the ideal trio earns all three Lava stars end-to-end', () {
      final earned = <int>[];
      final found = <String>[];
      final g = _harness(_idealTrio(), onStar: earned.add, onCloud: found.add);
      final s = g.works.line;

      // ── Entry rite: only Lava's own heat breaks the crucible seal.
      expect(g.entryDoorRevealed, isFalse);
      actAt(g, 'tap_head', ice, tapAt);
      expect(s.tapWoken, isFalse, reason: 'cold hands do not open a crucible');
      actAt(g, 'tap_head', lava, tapAt);
      expect(s.tapWoken, isTrue);
      expect(g.entryDoorRevealed, isTrue);
      expect(
        s.poursLeft,
        kLavaPourBudget,
        reason: 'waking the line is not a charge',
      );

      // ── The tail switch hangs over the north channel: not from here.
      expect(s.canSet('y_return'), isFalse);

      // ── POUR 1 — the line as the last shift left it: north arm, shroud up,
      //    sluice on the span form. A blind first charge casts the road.
      actAt(g, 'tap_head', lava, tapAt);
      expect(s.pour, isNotNull);
      standIn(g, 'mold_floor', const Offset(300, 300));
      runOut(g);
      expect(s.cast('span_a'), isTrue, reason: 'the span form filled');
      expect(s.poursLeft, kLavaPourBudget - 1);

      // ── STAR 1: the road is the only way across the runner.
      standIn(
        g,
        'mold_floor',
        g.layout.rooms['mold_floor']!.foundryStar!.position,
      );
      g.update(1 / 60);
      expect(g.hasStar(0), isTrue);

      // ── The mill's die is dead iron until steam drives it, and the braid
      //    is TWO bodies at the accumulator (Ice+Lava→Steam).
      standIn(g, 'stamp_mill', kLavaAccumulator);
      g.creatures[lava].position = const Offset(20, 20); // send the heat away
      g.setActive(ice);
      g.activateAbility();
      g.update(1 / 60);
      expect(s.dieWoken, isFalse, reason: 'one body is not a braid');
      actAt(g, 'stamp_mill', ice, kLavaAccumulator);
      expect(s.dieWoken, isTrue);

      // ── The points are Earth's: element-only, and nothing else shifts them.
      final yard = kLavaLine.node('y_yard');
      actAt(g, 'switch_yard', ice, yard.leverAt!);
      expect(s.settingOf('y_yard'), 0, reason: 'slag-seized against cold');

      // ── POUR 2 — shroud DOWN: the charge sets in the north channel. That
      //    is the catwalk stair, and it kills the plain arm for good.
      setLever(g, 'chiller', 1);
      actAt(g, 'tap_head', lava, tapAt);
      standIn(g, 'chill_house', const Offset(430, 470));
      runOut(g);
      expect(s.plugged('ch_north'), isTrue);
      expect(s.access, contains('catwalk'));
      expect(s.canSet('y_return'), isTrue);

      // ── POUR 3 — the long way round: south arm, purge shut, sluice ON,
      //    tail to the sump. Warded metal, into the hidden mold.
      setLever(g, 'y_return', 1);
      setLever(g, 'y_yard', 1);
      setLever(g, 'damper', 0);
      setLever(g, 'y_sluice', 2);
      actAt(g, 'tap_head', lava, tapAt);
      standIn(g, 'tap_head', const Offset(400, 300));
      runOut(g);
      expect(
        s.cast('reliquary'),
        isTrue,
        reason: 'the key stands cast at the far end of the works',
      );

      // ── POUR 4 — and now the crossing. THE ONE HARD GATE: an Ice mane
      //    sets the running metal where it stands.
      actAt(g, 'tap_head', lava, tapAt);
      runTo(g, 'ch_sump');
      expect(s.pour, isNotNull, reason: 'the charge reached the sump');
      var beside = kLavaLine.channel('ch_sump').pointAt(s.pour!.t).$2;
      standIn(g, 'tap_head', beside + const Offset(0, -60));
      g.setActive(lava);
      g.activateAbility();
      expect(s.pour, isNotNull, reason: 'a molten hand cannot chill anything');
      beside = kLavaLine.channel('ch_sump').pointAt(s.pour!.t).$2;
      standIn(g, 'tap_head', beside + const Offset(0, -60));
      g.setActive(ice);
      g.activateAbility();
      expect(s.pour, isNull, reason: 'the mane set it where it ran');
      expect(s.access, contains('sump'));
      expect(s.poursLeft, kLavaPourBudget - 4, reason: 'four charges, no more');

      // ── The key, and the ward it was cut for.
      final mold = kLavaLine.node('mold_reliquary');
      actAt(g, 'tap_head', lava, mold.position + const Offset(0, 40));
      expect(s.carried, 'reliquary');

      final floor = g.layout.rooms['mold_floor']!;
      final ward = floor.doors.firstWhere(
        (d) => d.targetRoomId == 'slag_reliquary',
      );
      expect(g.isDoorLocked(floor, ward), isTrue);
      actAt(g, 'mold_floor', lava, ward.rect.center + const Offset(-40, 0));
      expect(s.wardsTurned, contains('reliquary'));
      expect(g.isDoorLocked(floor, ward), isFalse);

      // ── STAR 2, and the vault behind the same door.
      standIn(
        g,
        'slag_reliquary',
        g.layout.rooms['slag_reliquary']!.foundryStar!.position,
      );
      g.update(1 / 60);
      expect(g.hasStar(1), isTrue);
      expect(earned, containsAllInOrder([0, 1]));
      standIn(
        g,
        'slag_reliquary',
        g.layout.rooms['slag_reliquary']!.vaultCache!,
      );
      g.update(1 / 60);
      expect(found, contains('cache:lava_vault'));

      // ── The rite is the works: both stars, and the heart gate draws back.
      expect(g.guardianAwake, isTrue);
      final heart = g.layout.rooms['pour_heart']!;
      expect(
        g.isDoorLocked(
          floor,
          floor.doors.firstWhere((d) => d.targetRoomId == 'pour_heart'),
        ),
        isFalse,
      );

      // ── MAGMARA rides the ring, and no clock bares it (§7).
      final beast = heart.guardian!.position;
      standIn(g, 'pour_heart', kLavaHeartHeads[1]);
      g.setActive(lava);
      g.activateAbility();
      expect(
        g.guardianVulnerable,
        isFalse,
        reason: 'the far head falls on empty channel',
      );
      g.works.headCool = 0;
      standIn(g, 'pour_heart', kLavaHeartHeads[0]);
      g.setActive(lava);
      g.activateAbility();
      expect(
        g.guardianVulnerable,
        isTrue,
        reason: 'the near head catches it — the cast IS the lull',
      );
      expect(g.works.beached, greaterThan(0));
      expect((g.works.beachedAt - beast).distance, lessThan(1));
    });

    test('a wasted charge costs a pour and never the run', () {
      final g = _harness(_idealTrio());
      final s = g.works.line;
      actAt(g, 'tap_head', lava, tapAt);

      // The purge is standing open, so the south arm gasses what it takes.
      setLever(g, 'y_yard', 1);
      setLever(g, 'y_sluice', 0);
      expect(s.settingOf('damper'), 1, reason: 'the works died mid-purge');
      actAt(g, 'tap_head', lava, tapAt);
      standIn(g, 'stamp_mill', const Offset(200, 150));
      runOut(g);
      expect(s.cast('span_a'), isFalse);
      expect(g.works.firedamp, greaterThan(0), reason: 'and gas in the room');
      expect(s.molds['mold_span_a'], isNotNull, reason: 'the form is fouled');

      // A Lava heart melts the ruin out; the form takes again. The charge,
      // though, is gone forever — that is the whole economy.
      actAt(g, 'mold_floor', lava, kLavaLine.node('mold_span_a').position);
      expect(s.molds['mold_span_a'], isNull);
      setLever(g, 'y_yard', 0);
      setLever(g, 'damper', 0);
      actAt(g, 'tap_head', lava, tapAt);
      standIn(g, 'mold_floor', const Offset(300, 300));
      runOut(g);
      expect(s.cast('span_a'), isTrue);
      expect(s.poursLeft, kLavaPourBudget - 2);
    });

    test('the Black Glass rite spends the run on purpose', () {
      final found = <String>[];
      final g = _harness(_idealTrio(), onCloud: found.add);
      actAt(g, 'tap_head', lava, tapAt); // the first press wakes the line
      for (var i = 0; i < kLavaBlackGlassQuenches; i++) {
        actAt(g, 'tap_head', lava, tapAt);
        expect(g.works.line.pour, isNotNull);
        actAt(g, 'tap_head', ice, tapAt);
        g.works.line.remelt('plug:ch_tap'); // clear the spoil and go again
      }
      expect(g.works.line.quenches, kLavaBlackGlassQuenches);
      // THE RITE OF THREE runs before the gold lands (see `beginMaximRite`).
      for (var tick = 0; tick < 200; tick++) {
        g.update(1 / 60);
      }
      expect(found, contains(kLavaBlackGlassEggId));
      expect(g.works.line.poursLeft, kLavaPourBudget - kLavaBlackGlassQuenches);
      expect(
        g.works.line.poursLeft,
        lessThan(4),
        reason: 'and the works cannot be finished on what is left',
      );
    });
  });
}
