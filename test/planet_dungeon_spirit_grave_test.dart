// REQUIA — the Echo Grave's two worlds, PROVED.
//
// Spirit's topology is two overlaid worlds over one geometry
// (docs/dungeons.md §5.5), and its verb is a DEATH: telling a revenant opens
// the living crossing it died at and closes the ghost one. That is an
// irreversible world-edit, and irreversible world-edits are stranding
// machines — Ice measured 120/122 strandable as specced, Mud 1200/1284, Dust
// 319/396, Plant 142/448, and every one of them shipped a costly full-reset
// valve to buy its way out.
//
// Requia ships no valve, so this file's first job is to earn that:
//
//  1. THE NO-STRAND PROOF, on the graph the player actually walks:
//     **2,276 states over (room × world × finished deaths × the frozen cut),
//     and 0 of them strandable.** From EVERY state a legal run can reach, the
//     lych gate is still reachable ALIVE, the Cold Road is still openable, the
//     mere is still reachable ALIVE, and Wraithord's grave is still reachable.
//     The search walks the SHIPPED rules ([EchoGraveField]) and the SHIPPED
//     crossing list, never a model of them.
//  2. THE COUNTERFACTUAL. The proof rests on two geometric rules — the ghost
//     spine, and every revenant being told from a barrow ON it. Move the six
//     tellings to the pendant side of their own crossings and the same search
//     measures **54 strandable of the 369** states such a run can still reach.
//     The rules are load-bearing, and this pins them so they cannot be quietly
//     edited away later.
//  3. THE COST IS REAL, AND IT IS THE VAULT. 544 of the 2,276 states have lost
//     the hollow grave for good — that is the greedy player's punishment for
//     finishing both of the mere's dead, and it is the design (Mud's precedent
//     of a losable vault).
//
// The rest pins the two non-guardian stars' authored solutions, the sigil's
// uniqueness, both hard gates, the vault's one world, the lost maxim, the
// guardian's phase, and the planet's registration.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_spirit.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────
// THE SEARCH
// ─────────────────────────────────────────────────────────
// A state is (room, world, finished deaths, frozen cut). Everything about
// reachability is derived from the shipped [EchoGraveField], so the search and
// the engine cannot drift.

const List<String> _revIds = [
  'r_bellman',
  'r_chandler',
  'r_keener',
  'r_sexton',
  'r_wright',
  'r_watcher',
];

/// The barrow each death is heard out in. Read from the SHIPPED roster for the
/// real proof; overridden for the counterfactual.
Map<String, String> shippedTellings() => {
  for (final r in kGraveRevenants) r.id: r.toldAt,
};

/// Every telling moved to the far side of its own crossing — i.e. off the
/// ghost spine. This is the design Requia deliberately does NOT have.
Map<String, String> pendantTellings() {
  final out = <String, String>{};
  for (final r in kGraveRevenants) {
    final x = graveCrossingById(r.crossingId)!;
    out[r.id] = x.from == r.toldAt ? x.to : x.from;
  }
  return out;
}

class GraveState {
  final String room;
  final GraveWorld world;
  final int rested; // bitmask over _revIds
  final bool frozen;

  const GraveState(this.room, this.world, this.rested, this.frozen);

  @override
  bool operator ==(Object other) =>
      other is GraveState &&
      other.room == room &&
      other.world == world &&
      other.rested == rested &&
      other.frozen == frozen;

  @override
  int get hashCode => Object.hash(room, world, rested, frozen);

  @override
  String toString() => '$room/${worldWord(world)}/$rested/$frozen';
}

/// Build the shipped rules object for a state, so every question the search
/// asks is answered by the code the game runs.
EchoGraveField fieldFor(GraveState s) {
  final f = EchoGraveField()
    ..world = s.world
    ..cutFrozen = s.frozen;
  for (var i = 0; i < _revIds.length; i++) {
    if (s.rested >> i & 1 == 1) f.tell(_revIds[i]);
  }
  return f;
}

/// Rooms the party can pass over in — read off the authored layout, because
/// their placement is half the no-strand argument and a test that hard-coded
/// them would not notice one being moved.
final Set<String> lychRooms = {
  for (final e in kPlanetDungeonLayouts['Spirit']!.rooms.entries)
    if (e.value.grave?.lychStone != null || e.value.grave?.wraithStone != null)
      e.key,
};

/// Rooms the drowned cut can be settled from.
final Set<String> brinkRooms = {
  for (final e in kPlanetDungeonLayouts['Spirit']!.rooms.entries)
    if (e.value.grave?.drownedBrink != null) e.key,
};

List<GraveState> successors(GraveState s, Map<String, String> tellings) {
  final f = fieldFor(s);
  final out = <GraveState>[];
  for (final x in kGraveCrossings) {
    if (x.from != s.room && x.to != s.room) continue;
    if (!f.crossingOpen(x)) continue;
    out.add(
      GraveState(x.from == s.room ? x.to : x.from, s.world, s.rested, s.frozen),
    );
  }
  if (lychRooms.contains(s.room)) {
    out.add(GraveState(s.room, otherWorld(s.world), s.rested, s.frozen));
  }
  if (s.world == GraveWorld.ghost) {
    for (var i = 0; i < _revIds.length; i++) {
      if (s.rested >> i & 1 == 1) continue;
      if (tellings[_revIds[i]] != s.room) continue;
      out.add(GraveState(s.room, s.world, s.rested | (1 << i), s.frozen));
    }
  }
  if (!s.frozen && brinkRooms.contains(s.room)) {
    out.add(GraveState(s.room, s.world, s.rested, true));
  }
  return out;
}

Set<GraveState> flood(GraveState from, Map<String, String> tellings) {
  final seen = <GraveState>{from};
  final stack = <GraveState>[from];
  while (stack.isNotEmpty) {
    final s = stack.removeLast();
    for (final n in successors(s, tellings)) {
      if (seen.add(n)) stack.add(n);
    }
  }
  return seen;
}

const GraveState kStart = GraveState('lych_gate', GraveWorld.living, 0, false);

class GraveVerdict {
  final int reachable;
  final int strandable;
  final int noExit;
  final int noColdRoad;
  final int noSigil;
  final int noGuardian;
  final int noVault;
  const GraveVerdict(
    this.reachable,
    this.strandable,
    this.noExit,
    this.noColdRoad,
    this.noSigil,
    this.noGuardian,
    this.noVault,
  );
}

GraveVerdict judge(Map<String, String> tellings) {
  final all = flood(kStart, tellings);
  var strand = 0, noExit = 0, noRoad = 0, noSigil = 0, noGuard = 0, noVault = 0;
  for (final s in all) {
    final f = flood(s, tellings);
    var exitOk = false, road = false, sigil = false, guard = false;
    var vault = false;
    for (final t in f) {
      if (t.room == 'lych_gate' && t.world == GraveWorld.living) exitOk = true;
      // Star 1's mark takes only from a warm hand, in one barrow.
      if (t.room == kGraveSigilBarrow && t.world == GraveWorld.living) {
        sigil = true;
      }
      if (t.room == 'wraithord_grave') guard = true;
      if (t.room == 'hollow_grave' && t.world == GraveWorld.ghost) {
        vault = true;
      }
      if (!road && fieldFor(t).coldRoadOpen) road = true;
    }
    if (!exitOk) noExit++;
    if (!road) noRoad++;
    if (!sigil) noSigil++;
    if (!guard) noGuard++;
    if (!vault) noVault++;
    if (!(exitOk && road && sigil && guard)) strand++;
  }
  return GraveVerdict(
    all.length,
    strand,
    noExit,
    noRoad,
    noSigil,
    noGuard,
    noVault,
  );
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

/// The §6.14 ideal trio: Spiritmask · Waterpip · Crystalwing.
List<CosmicPartyMember> idealTrio() => [
  _member(0, 'Spirit', 'mask'),
  _member(1, 'Water', 'pip'),
  _member(2, 'Crystal', 'wing'),
];

const int spirit = 0, water = 1, crystal = 2;

PlanetDungeonGame harness(
  List<CosmicPartyMember> party, {
  void Function(int)? onStar,
  void Function(String)? onCloud,
}) {
  final game = PlanetDungeonGame(
    element: 'Spirit',
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

/// Pass the party over at [room]'s stone (the engine's own verb).
void passOver(PlanetDungeonGame game, String room) {
  final g = game.layout.rooms[room]!.grave!;
  act(game, spirit, room, g.lychStone ?? g.wraithStone!);
}

/// Hear out [id] with the engine, standing in the ghost world where it died.
void tell(PlanetDungeonGame game, String id) {
  final r = graveRevenantById(id)!;
  act(game, spirit, r.toldAt, r.seat);
}

// ─────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final layout = kPlanetDungeonLayouts['Spirit']!;

  late GraveVerdict shipped;
  late GraveVerdict pendant;
  setUpAll(() {
    shipped = judge(shippedTellings());
    pendant = judge(pendantTellings());
  });

  group('the field is one geometry read twice', () {
    test('every crossing is exactly one authored door pair, both ways', () {
      // The doors the player walks and the edges the proof walks must be the
      // same objects, or the proof proves nothing (Plant's precedent).
      final pairs = <String>{};
      for (final room in layout.rooms.values) {
        for (final door in room.doors) {
          final x = graveCrossingBetween(room.id, door.targetRoomId);
          expect(
            x,
            isNotNull,
            reason: '${room.id} → ${door.targetRoomId} has no crossing',
          );
          pairs.add(([room.id, door.targetRoomId]..sort()).join('|'));
        }
      }
      expect(pairs.length, kGraveCrossings.length);
      for (final x in kGraveCrossings) {
        expect(
          pairs,
          contains(([x.from, x.to]..sort()).join('|')),
          reason: '${x.id} has no door',
        );
      }
    });

    test('NOTHING IS EVER LOST — every crossing stays crossable in some '
        'world, in every state', () {
      // This is the sentence that separates Requia from Mud (which destroys
      // edges) and from Ice (which consumes them). A telling MOVES a crossing
      // between the worlds; it never deletes one.
      for (var mask = 0; mask < 64; mask++) {
        for (final frozen in const [false, true]) {
          final f = fieldFor(GraveState('x', GraveWorld.living, mask, frozen));
          for (final x in kGraveCrossings) {
            expect(
              f.crossableSomewhere(x),
              isTrue,
              reason: '${x.id} vanished at mask $mask',
            );
          }
        }
      }
    });

    test('a restless death holds the ghost road and blocks the living one; '
        'finishing it swaps exactly that pair', () {
      final f = EchoGraveField();
      for (final r in kGraveRevenants) {
        final x = graveCrossingById(r.crossingId)!;
        expect(f.openToGhost(x), isTrue);
        expect(f.openToLiving(x), isFalse);
      }
      f.tell('r_keener');
      final mere = graveCrossingById('x_mere')!;
      expect(f.openToLiving(mere), isTrue);
      expect(f.openToGhost(mere), isFalse);
      // …and nothing else moved.
      for (final r in kGraveRevenants) {
        if (r.id == 'r_keener') continue;
        final x = graveCrossingById(r.crossingId)!;
        expect(f.openToGhost(x), isTrue);
        expect(f.openToLiving(x), isFalse);
      }
    });

    test('ORDER IS UNOBSERVABLE — telling A then B lands on the same field '
        'as B then A', () {
      // The ordering seat belongs to Air (§5.5). Requia's question is WHICH
      // crossings, never in what sequence, and this pins it for all 30 pairs.
      for (final a in kGraveRevenants) {
        for (final b in kGraveRevenants) {
          if (a.id == b.id) continue;
          final ab = EchoGraveField()
            ..tell(a.id)
            ..tell(b.id);
          final ba = EchoGraveField()
            ..tell(b.id)
            ..tell(a.id);
          for (final x in kGraveCrossings) {
            expect(ab.openToLiving(x), ba.openToLiving(x));
            expect(ab.openToGhost(x), ba.openToGhost(x));
          }
        }
      }
    });

    test('the freeze only ever GIVES the living a road', () {
      // Purely additive edits cannot strand, which is why the drowned cut is
      // safe to make irreversible.
      for (var mask = 0; mask < 64; mask++) {
        final cold = fieldFor(GraveState('x', GraveWorld.living, mask, false));
        final warm = fieldFor(GraveState('x', GraveWorld.living, mask, true));
        for (final x in kGraveCrossings) {
          if (cold.openToLiving(x)) expect(warm.openToLiving(x), isTrue);
          if (cold.openToGhost(x)) expect(warm.openToGhost(x), isTrue);
        }
      }
    });
  });

  group('THE NO-STRAND PROOF', () {
    test('RULE 1 — the ghost spine survives every state, by name', () {
      const spine = [
        'lych_gate',
        'barrow_urn',
        'barrow_veil',
        'barrow_cairn',
        'mourners_walk',
        'wraithord_grave',
      ];
      for (var mask = 0; mask < 64; mask++) {
        final f = fieldFor(GraveState('x', GraveWorld.ghost, mask, false));
        final reach = f.ghostReach('lych_gate');
        for (final r in spine) {
          expect(reach, contains(r), reason: '$r fell off the spine at $mask');
        }
      }
    });

    test('RULE 2 — every death is heard out from a spine barrow', () {
      const spine = {'barrow_urn', 'barrow_veil', 'barrow_cairn'};
      for (final r in kGraveRevenants) {
        expect(
          spine,
          contains(r.toldAt),
          reason: '${r.id} is told off the spine — the proof breaks',
        );
        final x = graveCrossingById(r.crossingId)!;
        expect(
          [x.from, x.to],
          contains(r.toldAt),
          reason: '${r.id} must stand at its own crossing',
        );
      }
    });

    test('the spine carries a lych-stone, and the field carries three', () {
      expect(
        lychRooms,
        containsAll(['lych_gate', 'barrow_urn', 'barrow_cairn']),
      );
      final inField = lychRooms
          .where((r) => layout.rooms[r]!.grave?.barrow == true)
          .length;
      expect(inField, 2, reason: 'the urn and the cairn, and nowhere else');
    });

    test('0 STRANDABLE of 2,276 — the whole space, walked by the shipped '
        'rules', () {
      expect(shipped.reachable, 2276);
      expect(shipped.strandable, 0);
      expect(shipped.noExit, 0);
      expect(shipped.noColdRoad, 0);
      expect(shipped.noSigil, 0);
      expect(shipped.noGuardian, 0);
    });

    test('THE COUNTERFACTUAL — told from the pendant side it strands 54 of '
        '369', () {
      // The two rules are the design, not a coincidence. Moving each telling
      // to the far side of its own crossing lets a body close the last ghost
      // road out of the barrow it is standing in.
      expect(pendant.reachable, 369);
      expect(pendant.strandable, 54);
      expect(pendant.noExit, 54);
    });

    test('THE COST IS THE VAULT — 544 states have lost the hollow grave for '
        'good', () {
      // By design, and the only thing a greedy run can permanently lose:
      // finish BOTH of the mere's dead and no dead body ever stands there
      // again. (Mud's precedent — a losable vault is not a strand.)
      expect(shipped.noVault, 544);
      final both = EchoGraveField()
        ..world = GraveWorld.ghost
        ..tell('r_keener')
        ..tell('r_sexton');
      expect(both.ghostReach('lych_gate'), isNot(contains('barrow_mere')));
      expect(both.ghostReach('lych_gate'), isNot(contains('hollow_grave')));
      // …and the intended play keeps both worlds of the mere: open the Cold
      // Road round the far side, finish ONE of the mere's dead for the warm
      // road in, and leave the other restless for the cold road out.
      final one = EchoGraveField()
        ..tell('r_watcher')
        ..tell('r_wright')
        ..tell('r_sexton');
      expect(one.livingReach(), contains('barrow_mere'));
      expect(one.ghostReach('lych_gate'), contains('hollow_grave'));
    });

    test('a lych-stone is never spendable, so the way down is never lost', () {
      // The prompt's nastiest edge: a layer transition that can itself be
      // spent. Requia's cannot — the passing has no state at all beyond a
      // counter.
      final f = EchoGraveField();
      for (var i = 0; i < 50; i++) {
        f.passOver();
      }
      expect(f.passings, 50);
      expect(f.world, GraveWorld.living);
    });
  });

  group('Star 0 — THE COLD ROAD (ungated)', () {
    test('the funeral cannot leave on arrival', () {
      final f = EchoGraveField();
      expect(f.coldRoadOpen, isFalse);
      expect(f.livingReach(), {'lych_gate', 'barrow_urn'});
    });

    test('THE AUTHORED SOLUTION — two deaths open the road, and neither is '
        'the mere\'s', () {
      final f = EchoGraveField()
        ..tell('r_watcher')
        ..tell('r_wright');
      expect(f.coldRoadOpen, isTrue);
      // The point of the cheapest road: it leaves the mere untouched, so the
      // vault is still there to be had.
      expect(f.ghostReach('lych_gate'), contains('hollow_grave'));
    });

    test('the braid is a real second road, not a decoration', () {
      final f = EchoGraveField()
        ..tell('r_bellman')
        ..tell('r_chandler');
      expect(f.coldRoadOpen, isFalse, reason: 'the cut is still water');
      f.cutFrozen = true;
      expect(f.coldRoadOpen, isTrue);
    });

    test('no single death opens it — every road wants at least two', () {
      for (final r in kGraveRevenants) {
        for (final frozen in const [false, true]) {
          final f = EchoGraveField()
            ..cutFrozen = frozen
            ..tell(r.id);
          expect(
            f.coldRoadOpen,
            isFalse,
            reason: '${r.id} alone opened the road (frozen: $frozen)',
          );
        }
      }
    });

    test('the engine banks it, and the telling is element-only Spirit', () {
      final stars = <int>[];
      final game = harness(idealTrio(), onStar: stars.add);
      game.wake.field.world = GraveWorld.ghost;
      // A Water hand hears nothing.
      final r = graveRevenantById('r_watcher')!;
      act(game, water, r.toldAt, r.seat);
      expect(game.wake.field.isRested('r_watcher'), isFalse);
      tell(game, 'r_watcher');
      tell(game, 'r_wright');
      expect(game.wake.field.told, 2);
      expect(stars, contains(0));
      expect(game.hasStar(0), isTrue);
    });

    test('a warm hand hears nobody out — the telling is the cold world\'s', () {
      final game = harness(idealTrio());
      expect(game.wake.field.isGhost, isFalse);
      tell(game, 'r_watcher');
      expect(game.wake.field.isRested('r_watcher'), isFalse);
    });

    test('the passing works both ways, at a stone and nowhere else', () {
      final game = harness(idealTrio());
      passOver(game, 'lych_gate');
      expect(game.wake.field.isGhost, isTrue);
      passOver(game, 'lych_gate');
      expect(game.wake.field.isGhost, isFalse);
      // The bell barrow has no stone: standing where one would be does nothing.
      act(game, spirit, 'barrow_bell', const Offset(230, 250));
      expect(game.wake.field.isGhost, isFalse);
    });
  });

  group('Star 1 — THE PHANTOM HOURGLASS', () {
    test('exactly one barrow closes the ring', () {
      final closing = kBarrowSigilHalf.keys.where(graveSigilCloses).toList();
      expect(closing, hasLength(1));
      expect(closing.single, 'barrow_mere');
      expect(kGraveSigilBarrow, 'barrow_mere');
      // Every barrow carries a half, so the deduction has seven candidates.
      final barrows = layout.rooms.values
          .where((r) => r.grave?.barrow == true)
          .map((r) => r.id)
          .toSet();
      expect(kBarrowSigilHalf.keys.toSet(), barrows);
      for (final id in barrows) {
        expect(layout.rooms[id]!.grave!.sigilStone, isNotNull);
      }
    });

    test(
      'the mark is a HARD Water+Pip gate, and refusing it stamps the chip',
      () {
        final clouds = <String>[];
        final game = harness(idealTrio(), onCloud: clouds.add);
        final gate = layout.familyGateFor('grave_sigil')!;
        expect(gate.element, 'Water');
        expect(gate.family, 'Pip');
        final pos = layout.rooms['barrow_mere']!.grave!.sigilStone!;
        act(game, spirit, 'barrow_mere', pos); // right place, wrong hand
        expect(game.wake.field.sigilStamped, isFalse);
        expect(clouds, contains(gate.discoveryId));
      },
    );

    test('a dead hand leaves no mark, and a wrong barrow refuses for free', () {
      final game = harness(idealTrio());
      passOver(game, 'lych_gate');
      act(
        game,
        water,
        'barrow_mere',
        layout.rooms['barrow_mere']!.grave!.sigilStone!,
      );
      expect(game.wake.field.sigilStamped, isFalse);
      expect(game.wake.field.stampsTried, 0, reason: 'the dead never tried');
      passOver(game, 'lych_gate');
      act(
        game,
        water,
        'barrow_bell',
        layout.rooms['barrow_bell']!.grave!.sigilStone!,
      );
      expect(game.wake.field.sigilStamped, isFalse);
      expect(game.wake.field.stampsTried, 1, reason: 'a free wrong answer');
    });

    test('THE AUTHORED SOLUTION — the warm hand at the mere banks it', () {
      final stars = <int>[];
      final game = harness(idealTrio(), onStar: stars.add);
      act(
        game,
        water,
        'barrow_mere',
        layout.rooms['barrow_mere']!.grave!.sigilStone!,
      );
      expect(game.wake.field.sigilStamped, isTrue);
      expect(stars, contains(1));
    });

    test('the star is never lost, whatever has been told', () {
      // Living reachability only ever grows and every death stays tellable
      // from the spine, so no commitment can put the mere out of a warm body's
      // reach forever — measured over the whole reachable space.
      expect(shipped.noSigil, 0);
      // And the mere IS livingly reachable once its own sill is finished.
      final f = EchoGraveField()
        ..tell('r_watcher')
        ..tell('r_wright')
        ..tell('r_sexton');
      expect(f.livingReach(), contains(kGraveSigilBarrow));
    });
  });

  group('the vault — a room only one world contains', () {
    test('the hollow grave has no living door at all', () {
      final x = graveCrossingBetween('barrow_mere', 'hollow_grave')!;
      expect(x.cut, GraveCut.ghostOnly);
      expect(x.freezable, isFalse, reason: 'the cold must not open it');
      final f = EchoGraveField();
      expect(f.openToLiving(x), isFalse);
      f.cutFrozen = true;
      expect(f.openToLiving(x), isFalse);
    });

    test('the mark is in the OTHER world — the mere carries the sigil stone '
        'a dead hand cannot read', () {
      // §5.5: "exists only in the ghost layer, marked only in the living one".
      expect(layout.rooms['barrow_mere']!.grave!.sigilStone, isNotNull);
      expect(layout.rooms['hollow_grave']!.vaultCache, isNotNull);
      final caches = layout.rooms.values.where((r) => r.vaultCache != null);
      expect(caches, hasLength(1));
    });

    test('the essence is only there for the dead', () {
      final game = harness(idealTrio());
      game.currentRoomId = 'hollow_grave';
      expect(game.graveVaultLiveForTest, isFalse);
      game.wake.field.world = GraveWorld.ghost;
      expect(game.graveVaultLiveForTest, isTrue);
    });

    test('a pocket you walked into dead, you can always walk out of dead', () {
      // Only the states you could actually BE standing in it are asked: the
      // hollow grave is enterable exactly while the mere is ghost-reachable,
      // and in every one of those the way back out runs all the way home.
      var checked = 0;
      for (var mask = 0; mask < 64; mask++) {
        final f = fieldFor(GraveState('x', GraveWorld.ghost, mask, false));
        if (!f.ghostReach('lych_gate').contains('hollow_grave')) continue;
        checked++;
        final from = f.ghostReach('hollow_grave');
        expect(from, contains('barrow_mere'));
        expect(from, contains('lych_gate'));
      }
      expect(
        checked,
        48,
        reason: 'the vault survives 48 of the 64 commitments',
      );
    });
  });

  group('the rite and the guardian', () {
    test('the name stone is ELEMENT-ONLY Spirit; the one gate is the sigil',
        () {
      // WAS a Spirit MASK gate. The cold world itself is what answers at the
      // name stone, and any Spirit hand stands in it — the family was a
      // second lock on the rite of a planet that already gates its sigil.
      expect(layout.familyGateFor('A'), isNull);
      final conduit = layout.rooms['mourners_walk']!.conduits.single;
      expect(conduit.requireElement, 'Spirit');
      expect(conduit.requiredFamily, isNull);
      expect(conduit.struckByStorm, isFalse,
          reason: 'no family does NOT mean the storm lights it');
      // §4: max one gate per star, and Star 0 carries none.
      expect(layout.familyGates, hasLength(1));
      expect(layout.familyGateFor('grave_sigil'), isNotNull);
    });

    test('the lamp answers Crystal alone, and only after both stars', () {
      final game = harness(idealTrio());
      final pos = layout.rooms['mourners_walk']!.grave!.graveLamp!;
      act(game, spirit, 'mourners_walk', pos);
      expect(game.conduitEnergy['B'] ?? 0, 0, reason: 'wrong element');
      act(game, crystal, 'mourners_walk', pos);
      expect(game.conduitEnergy['B'] ?? 0, 0, reason: 'no stars, no lamp');
      game.earnStar(0);
      game.earnStar(1);
      act(game, crystal, 'mourners_walk', pos);
      expect(game.conduitEnergy['B']! > 0, isTrue);
    });

    test('Wraithord crosses over on its own beat, and the lull only opens in '
        'phase', () {
      final game = harness(idealTrio());
      game.currentRoomId = 'wraithord_grave';
      game.guardianAwake = true;
      game.wake.wraithWorld = GraveWorld.ghost;
      game.guardianVulnerable = true;
      game.update(0.016);
      expect(
        game.guardianVulnerable,
        isFalse,
        reason: 'a warm party cannot open a lull on a cold mystic',
      );
      // Match it, and the lull is allowed to stand.
      game.wake.field.world = GraveWorld.ghost;
      game.guardianVulnerable = true;
      game.update(0.016);
      expect(game.guardianVulnerable, isTrue);
    });

    test('the beat flips its world, and the arena carries the only stone', () {
      final game = harness(idealTrio());
      game.currentRoomId = 'wraithord_grave';
      game.guardianAwake = true;
      final before = game.wake.wraithWorld;
      game.update(5.0);
      expect(game.wake.wraithWorld, isNot(before));
      expect(layout.rooms['wraithord_grave']!.grave!.wraithStone, isNotNull);
    });

    test('Star 2 is the mystic, and MYS14 brings its raid with it', () {
      final g = layout.rooms['wraithord_grave']!.guardian!;
      expect(g.starIndex, 2);
      expect(g.encounter!.mysticId, 'Wraithord');
      expect(kRaidGuardianIds['Spirit'], 'Wraithord');
    });
  });

  group('THE LOST MAXIM — Stuff of Dreams', () {
    test('all three bodies in the unmarked grave, as the dead', () {
      final clouds = <String>[];
      final game = harness(idealTrio(), onCloud: clouds.add);
      game.wake.field.world = GraveWorld.ghost;
      game.currentRoomId = 'hollow_grave';
      // Two of three is not three.
      game.creatures[2].hp = 0;
      game.setActive(spirit);
      for (final c in game.creatures) {
        c.position = const Offset(210, 150);
      }
      game.activateAbility();
      expect(clouds, isNot(contains(kSpiritStuffOfDreamsEggId)));
      game.creatures[2].hp = 10;
      game.creatures[2].position = const Offset(210, 150);
      game.setActive(spirit);
      game.activateAbility();
      expect(clouds, contains(kSpiritStuffOfDreamsEggId));
    });

    test('a warm party writes nothing', () {
      final clouds = <String>[];
      final game = harness(idealTrio(), onCloud: clouds.add);
      game.currentRoomId = 'hollow_grave';
      act(game, spirit, 'hollow_grave', const Offset(210, 150));
      expect(clouds, isNot(contains(kSpiritStuffOfDreamsEggId)));
    });
  });

  group('the planet is registered whole', () {
    test('entry, ideal families and the coming-soon set agree', () {
      expect(kCosmicPlanetEntry['Spirit'], ['Spirit', 'Water', 'Crystal']);
      expect(kDungeonIdealFamilies['Spirit'], ['Mask', 'Pip', 'Wing']);
      expect(kComingSoonDungeons, isNot(contains('Spirit')));
      expect(kPlanetDungeonLayouts.containsKey('Spirit'), isTrue);
    });

    test('the coming-soon set holds only genuinely unbuilt planets', () {
      // The known rebase trap: resolving a conflict here by keeping BOTH sides
      // silently restores an element a merged dungeon already deleted.
      for (final e in kComingSoonDungeons) {
        expect(
          kPlanetDungeonLayouts.containsKey(e),
          isFalse,
          reason: '$e is built and must not be "coming soon"',
        );
      }
      // Deliberately NOT an equality pin on {Dark, Light, Blood}: those three
      // are the planets still to author, so pinning the set makes the next
      // build fail a Spirit test for doing exactly the right thing. The
      // invariant above is the one that matters, and it keeps holding as the
      // set shrinks to empty.
      expect(
        kComingSoonDungeons.length + kPlanetDungeonLayouts.length,
        17,
        reason: 'every planet is either built or coming soon, never neither',
      );
    });

    test('the riddle names each slot outright — element and family', () {
      // Family naming is now CONDITIONAL — a line names one only where a gate
      // actually demands it, so an ungated slot names its element and nothing
      // more. That rule spans all seventeen planets and lives in
      // dungeon_riddle_naming_test.dart; this only pins Spirit's elements.
      final els = kCosmicPlanetEntry['Spirit']!;
      expect(layout.riddle.length, els.length);
      for (var i = 0; i < layout.riddle.length; i++) {
        expect(layout.riddle[i].toLowerCase(), contains(els[i].toLowerCase()));
      }
    });
  });

  group('the whole descent, walked with the ideal trio', () {
    test('Spiritmask · Waterpip · Crystalwing earn all three stars and take '
        'both secrets', () {
      final stars = <int>[];
      final clouds = <String>[];
      final game = harness(idealTrio(), onStar: stars.add, onCloud: clouds.add);

      // The gate arch is full of black water.
      act(
        game,
        water,
        'lych_gate',
        layout.rooms['lych_gate']!.grave!.graveMouth!,
      );
      expect(game.entryDoorRevealed, isTrue);

      // Down into the cold world, and hear out the two the road wants.
      passOver(game, 'lych_gate');
      tell(game, 'r_watcher');
      tell(game, 'r_wright');
      expect(game.hasStar(0), isTrue);

      // The mere: one of its dead only, so both worlds of it stay open.
      tell(game, 'r_sexton');
      expect(game.wake.field.ghostReach('lych_gate'), contains('hollow_grave'));

      // The vault, and the maxim, taken as the dead.
      game.currentRoomId = 'hollow_grave';
      for (final c in game.creatures) {
        c.position = layout.rooms['hollow_grave']!.vaultCache!;
      }
      game.update(0.016);
      expect(clouds, contains('cache:spirit_vault'));
      game.setActive(spirit);
      game.activateAbility();
      expect(clouds, contains(kSpiritStuffOfDreamsEggId));

      // Back warm, and set the mark where the ring closes.
      passOver(game, 'barrow_cairn');
      expect(game.wake.field.isGhost, isFalse);
      act(
        game,
        water,
        'barrow_mere',
        layout.rooms['barrow_mere']!.grave!.sigilStone!,
      );
      expect(game.hasStar(1), isTrue);

      // The rite, then the mystic.
      expect(game.guardianRiteUnlocked, isTrue);
      act(
        game,
        crystal,
        'mourners_walk',
        layout.rooms['mourners_walk']!.grave!.graveLamp!,
      );
      expect(game.conduitEnergy['B']! > 0, isTrue);
      expect(stars, containsAll([0, 1]));
      expect(layout.rooms['wraithord_grave']!.guardian!.starIndex, 2);
    });
  });
}
