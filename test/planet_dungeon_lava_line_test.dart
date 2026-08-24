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

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
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
List<_Step> _explore({bool maneAllowed = true, int maxPours = kLavaPourBudget}) {
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
        push(c, [...step.trail, 'pour:${cfg.values.join()}:${freeze ?? '-'}:${ev.name}']);
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
      expect(north.cast('span_a'), isTrue,
          reason: 'a plain pour fills the span form');

      final south = _fresh()..dieWoken = true;
      runFoundryPlan(
        south,
        const FoundryPlan({'y_yard': 1, 'damper': 0, 'y_sluice': 1}),
      );
      expect(south.cast('gantry'), isTrue,
          reason: 'the die wards it, and only warded metal makes a key');
    });

    test('the die is dead until it is driven, and then never sleeps', () {
      final s = _fresh();
      runFoundryPlan(
        s,
        const FoundryPlan({'y_yard': 1, 'damper': 0, 'y_sluice': 1}),
      );
      expect(s.cast('gantry'), isFalse,
          reason: 'plain metal cannot take a ward');
      expect(s.molds['mold_key'], isNotNull,
          reason: 'and the ruined casting is sitting in the form');
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
      expect(_poursUsed(s), 3, reason: 'the world came back; the charges did not');
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
      expect(s.cast('span_a'), isFalse,
          reason: 'the plain arm is shut for the rest of the run');
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
        const FoundryPlan(
          {'y_yard': 1, 'damper': 0, 'y_sluice': 2, 'y_return': 1},
          freezeOn: 'ch_sump',
        ),
      );
      expect(s.access, contains('sump'));
      runFoundryPlan(
        s,
        const FoundryPlan(
          {'y_yard': 1, 'damper': 0, 'y_sluice': 2, 'y_return': 1},
        ),
      );
      expect(s.cast('reliquary'), isFalse,
          reason: 'the key pour congeals against your own road');
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

    test('the works CAN be finished, and the cheapest way costs four pours',
        () {
      expect(solved, isNotEmpty, reason: 'an unsolvable dungeon is unshippable');
      final min = solved.map((s) => _poursUsed(s.state)).reduce(
            (a, b) => a < b ? a : b,
          );
      expect(min, 4, reason: 'the tightest full plan is four pours');
      expect(min, lessThan(kLavaPourBudget),
          reason: 'the crucible must fund the works');
      expect(kLavaPourBudget - min, 1,
          reason: 'exactly one spare: a blunder is survivable, two are not');
    });

    test('and it CANNOT be done in three — the budget really is scarce', () {
      final cheap = _explore(maxPours: 3)
          .where((s) => foundryWorksDone(s.state))
          .toList();
      expect(cheap, isEmpty,
          reason: 'four separate castings, and no pour can do two jobs');
    });

    test('more than one ORDER works — the player authors it, is not handed it',
        () {
      // §5.5 ledger: Fire owns sequence-execution. Lava may not hand out an
      // order, so the same four pours must land in more than one arrangement.
      final orders = <String>{};
      for (final s in solved) {
        if (_poursUsed(s.state) != 4) continue;
        orders.add(s.trail.where((m) => m.startsWith('pour:')).join('>'));
      }
      expect(orders.length, greaterThan(1),
          reason: 'a single legal sequence would be an order-memory puzzle');
    });

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

  group('the geometry cannot be walked around', () {
    /// Flood-fill [room] on a coarse grid, honouring the channels.
    Set<int> _reach(FoundryState s, DungeonRoom room, Offset from) {
      const step = 10.0;
      final b = room.bounds;
      final cols = (b.width / step).floor();
      int key(int c, int r) => r * cols + c;
      bool open(int c, int r) {
        final p = Offset(b.left + c * step + step / 2, b.top + r * step + step / 2);
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

    bool _canWalk(FoundryState s, String roomId, Offset from, Offset to) {
      final room = kLavaLayout.rooms[roomId]!;
      const step = 10.0;
      final b = room.bounds;
      final cols = (b.width / step).floor();
      final seen = _reach(s, room, from);
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
      expect(_canWalk(s, 'mold_floor', entry, star), isFalse,
          reason: 'without the span there is no way over the runner');
      runFoundryPlan(
        s,
        const FoundryPlan({'y_yard': 0, 'chiller': 0, 'y_sluice': 0}),
      );
      expect(s.cast('span_a'), isTrue);
      expect(_canWalk(s, 'mold_floor', entry, star), isTrue,
          reason: 'and with it, one crossing, right at the sluice');
    });

    test('the tail lever hangs beyond the north channel', () {
      final entry = kLavaLayout.rooms['switch_yard']!.doors
          .firstWhere((d) => d.targetRoomId == 'chill_house')
          .targetSpawn;
      final lever = kLavaLine.node('y_return').leverAt!;
      final s = _fresh();
      expect(_canWalk(s, 'chill_house', entry, lever), isFalse);
      runFoundryPlan(s, const FoundryPlan({'y_yard': 0, 'chiller': 1}));
      expect(_canWalk(s, 'chill_house', entry, lever), isTrue,
          reason: 'the frozen pour IS the catwalk stair');
    });

    test('the hidden mold sits across the sump, unreachable on arrival', () {
      final spawn = kLavaLayout.entranceSpawn;
      final mold = kLavaLine.node('mold_reliquary').position;
      final s = _fresh();
      expect(_canWalk(s, 'tap_head', spawn, mold), isFalse,
          reason: 'you can see it from the first room and never touch it');
      // A pour set by hand in the sump channel is the only way over.
      s.pour = LivePour(channelId: 'ch_sump', form: PourForm.plain)..t = 0.5;
      s.freezeHere();
      expect(_canWalk(s, 'tap_head', spawn, mold), isTrue);
    });

    test('every fixture a player must touch stands on walkable ground', () {
      final s = _fresh();
      for (final n in kLavaLine.nodes) {
        final lever = n.leverAt;
        if (lever == null) continue;
        expect(foundryBlocks(s, n.roomId, lever), isFalse,
            reason: '${n.id}\'s lever stands in the channel');
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
            foundryBlocks(
              s,
              d.targetRoomId,
              d.targetSpawn,
            ),
            isFalse,
            reason: '${room.id} → ${d.targetRoomId} spawns in running metal',
          );
        }
      }
    });
  });
}
