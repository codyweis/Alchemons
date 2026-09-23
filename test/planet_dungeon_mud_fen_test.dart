// PALUSIA — THE SINKING ALTAR, pinned.
//
// Mud's topology is a SHIFTING FIELD whose crossings the player authors
// irreversibly, and whose vault is "let the vault knoll SINK, ride it down to
// the drowned level" (docs §5.5). Irreversible map editing is a stranding
// machine, so the centrepiece of this file is the FULL REACHABILITY SEARCH:
// every state legal play can reach (room × the hardened set × the sough ×
// whether the lotus has been ridden down), and from each of them, whether
// every room the run can reach at all is still reachable.
//
// The rest pins the two star puzzles against the real rules — both are SOLVED
// here, move by move, through the shipped engine — plus the trap that makes
// the strategic question a question, the vault's induced map state, and
// Bogdrya's own weaponisation of the planet's rule.

import 'dart:math' show max;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_mud.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// The §6.8 ideal trio: Mudmane · Plantpip · Watermask.
List<CosmicPartyMember> _idealTrio() => [
  _member(0, 'Mud', 'mane'),
  _member(1, 'Plant', 'pip'),
  _member(2, 'Water', 'mask'),
];

const int mud = 0, plant = 1, water = 2;

PlanetDungeonGame _harness(
  List<CosmicPartyMember> party, {
  void Function(int)? onStar,
  void Function(String)? onCloud,
}) {
  final game = PlanetDungeonGame(
    element: 'Mud',
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
        abilityAtk: stats.elemAtk,
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

/// Stand [idx] on [at] in [room] and press the utility verb. Every fen verb
/// acts on what you are standing next to, so this is the only way the planet
/// is ever driven — in a test or on a phone.
void _act(PlanetDungeonGame g, int idx, String room, Offset at) {
  g.currentRoomId = room;
  g.setActive(idx);
  for (final c in g.creatures) {
    c
      ..position = at
      ..lastSafe = at;
  }
  g.activateAbility();
}

BogFord _ford(String id) => kBogFords.firstWhere((f) => f.id == id);

/// Drag [fordId] to sod, standing on [knoll].
void _drag(PlanetDungeonGame g, String fordId, String knoll) =>
    _act(g, mud, knoll, _ford(fordId).headIn(knoll)!);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final layout = kPlanetDungeonLayouts['Mud']!;

  group('the fen — topology', () {
    test('every crossing names real rooms, and every bank has a door', () {
      for (final f in kBogFords) {
        for (final side in [f.knollA, f.knollB]) {
          final room = layout.rooms[side];
          expect(room, isNotNull, reason: '${f.id} bank $side');
          expect(
            room!.doors.any((d) => d.targetRoomId == f.other(side)),
            isTrue,
            reason: '${f.id}: no door from $side to ${f.other(side)}',
          );
          expect(
            room.bounds.contains(f.headIn(side)!),
            isTrue,
            reason: '${f.id}: head on $side falls outside the room',
          );
        }
      }
    });

    test('no knoll is structurally undryable', () {
      // A knoll dries when every crossing that touches it is sod, and two
      // crossings adjacent on one slough can never both be sod. If a knoll
      // owned such a pair its moor could never wake, so the graph forbids it:
      // every knoll touches at most ONE crossing per slough.
      final field = BogField();
      for (final k in kBogKnollIds) {
        final mine = field.fordsOf(k);
        final sloughs = mine.map((f) => f.slough).toList();
        expect(
          sloughs.toSet().length,
          sloughs.length,
          reason: '$k touches two crossings on one watercourse',
        );
      }
    });

    test('the vault sits where only the founder can put you', () {
      final cacheRoom = layout.rooms.values.singleWhere(
        (r) => r.vaultCache != null,
      );
      expect(cacheRoom.id, 'sunken_lotus');
      // Nothing walks into the bowl: the lotus knoll's own hole is the only
      // way in, and the engine walks you through it (§5.5 vault trick).
      final lotus = layout.rooms[kLotusKnollId]!;
      expect(lotus.doors.any((d) => d.targetRoomId == 'sunken_lotus'), isTrue);
    });

    test('no STAR lives anywhere that terraforming can delete', () {
      // The whole non-strandability argument leans on this: the lotus knoll
      // can be cut adrift and ridden under, so nothing required may sit on
      // it, and the bowl below holds optional treasure only.
      expect(layout.rooms[kLotusKnollId]!.fen?.altar, isNull);
      expect(layout.rooms['sunken_lotus']!.fen?.altar, isNull);
      expect(layout.rooms['sunken_lotus']!.guardian, isNull);
    });

    test('§4: two hard gates, on two slots, and Star 0 is ungated', () {
      expect(layout.familyGates.length, 2);
      final slots = kCosmicPlanetEntry['Mud']!;
      final gated = layout.familyGates.map((g) => g.element).toSet();
      expect(gated.length, 2, reason: 'one gate per entry slot at most');
      for (final g in layout.familyGates) {
        if (g.needsElement) expect(slots, contains(g.element));
      }
      // The Sarsen Star — the star a first descent must be able to earn —
      // carries no family gate of any kind: the drag is element-only Mud
      // everywhere, always. Exactly one gate touches a star (the cairn's
      // black basin, Star 1); the other sits on optional treasure.
      expect(layout.familyGates.map((g) => g.objectId).toSet(), {
        'moor_black',
        'plank_road',
      });
    });

    test('the ideal families are index-aligned with the entry slots', () {
      expect(kCosmicPlanetEntry['Mud'], ['Mud', 'Plant', 'Water']);
      expect(kDungeonIdealFamilies['Mud'], ['Mane', 'Pip', 'Mask']);
      expect(kComingSoonDungeons, isNot(contains('Mud')));
      expect(layout.riddle.length, kCosmicPlanetEntry['Mud']!.length);
    });
  });

  group('THE NO-STRAND PROOF', () {
    test('no state reachable by legal play can strand the party', () {
      final game = _harness(_idealTrio());
      final r = game.solveFenTerraform();
      expect(r.states, 1028, reason: 'the whole (room × fen × valve) graph');
      expect(
        r.strandable,
        0,
        reason:
            'from EVERY reachable state, every room the run can reach at all '
            '— the gate, both star rooms, the rite, the hollow and the vault '
            'bowl — must still be reachable',
      );
    });

    test('the two searches agree, so neither is trusted on its own', () {
      // `strandable` is the literal two-level search (enumerate every state,
      // then a fresh forward BFS out of each). `strandableReverse` is the
      // same question answered backwards, one reverse BFS per room. A bug
      // would have to be present in both, in the same direction.
      final game = _harness(_idealTrio());
      final r = game.solveFenTerraform();
      expect(r.strandableReverse, r.strandable);
    });

    test('the exit and every star room survive every state, by name', () {
      // The audit above checks all rooms; this one says out loud which ones
      // the brief actually cares about.
      final game = _harness(_idealTrio());
      final rooms = game.layout.rooms;
      expect(rooms.containsKey('mire_gate'), isTrue); // the exit
      // Stars 0 and 1 are declared on the Sinking Altar's socket; Star 2 is
      // the guardian. Those three rooms are inside the all-rooms audit.
      expect(rooms['altar_knoll']!.fen?.altar, isNotNull);
      expect(rooms['bogdrya_hollow']!.guardian?.starIndex, 2);
      for (final k in kMoorKnollIds) {
        expect(rooms[k]!.fen?.moor, isNotNull);
      }
      expect(game.solveFenTerraform().strandable, 0);
    });

    test(
      'a Mane-less party is not stranded either, it just loses the vault',
      () {
        final game = _harness(_idealTrio());
        final r = game.solveFenTerraform(plankPassable: false);
        expect(r.strandable, 0);
      },
    );

    test('the wallow and the sough are load-bearing, not decoration', () {
      // Delete the valve and the planet becomes exactly the stranding machine
      // the design warns about. If this ever reaches zero, somebody has
      // quietly made a drag reversible and Mud has lost its identity.
      final game = _harness(_idealTrio());
      final r = game.solveFenTerraform();
      expect(
        r.strandableWithoutSough,
        greaterThan(r.states ~/ 2),
        reason: 'irreversible terraforming must actually be irreversible',
      );
      // For the record, and so a future softening shows up as a diff: 944 of
      // 1028 states — 92% — would be dead ends without the valve. (1200 of
      // 1284 before 2026-09-23, when the heave moved from climbing out to
      // pulling the plug: a freed sough and a dragged fen can no longer be
      // held at once, so 256 states simply stopped existing.)
      expect(r.strandableWithoutSough, 944);
    });

    test('the fen really can be cut in two — that is the whole question', () {
      final game = _harness(_idealTrio());
      final r = game.solveFenTerraform();
      expect(r.shapes, 125, reason: 'the legal shapes of this fen');
      expect(
        r.disconnectedShapes,
        47,
        reason:
            'shape the map you will have to live with (§5.5) — a greedy road '
            'can and does sever the bog',
      );
    });
  });

  group('the drag', () {
    test('hardening one crossing drowns its neighbours on the same slough', () {
      final f = BogField();
      expect(f.stateOf('cor_neck'), BogFordState.mire);
      final lost = f.harden('cor_neck')!;
      expect(lost.map((l) => l.id).toSet(), {'cor_head', 'cor_tail'});
      expect(f.stateOf('cor_neck'), BogFordState.sod);
      expect(f.stateOf('cor_head'), BogFordState.drowned);
      expect(f.stateOf('cor_tail'), BogFordState.drowned);
      // …and nothing on another watercourse moves.
      expect(f.stateOf('add_neck'), BogFordState.mire);
    });

    test('what already stands is safe — so ORDER is unobservable', () {
      // The deliberate distinction from Air's claimed row (§5.5): Air's
      // question IS the order; here any order of the same set lands on the
      // same fen, because sod is immune and drowned is final.
      final a = BogField()
        ..harden('cor_head')
        ..harden('add_tail');
      final b = BogField()
        ..harden('add_tail')
        ..harden('cor_head');
      for (final ford in kBogFords) {
        expect(a.stateOf(ford.id), b.stateOf(ford.id), reason: ford.id);
      }
    });

    test('drowned ground never takes a drag again', () {
      final f = BogField()..harden('cor_neck');
      expect(f.canHarden('cor_head'), isFalse);
      expect(f.harden('cor_head'), isNull);
    });

    test('the engine drags with Mud, and with the braid at a price', () {
      final game = _harness(_idealTrio());
      game.entryDoorRevealed = true;
      _drag(game, 'tarn_head', 'mire_gate');
      expect(game.bog.field.stateOf('tarn_head'), BogFordState.sod);

      // Plant+Water→Mud stands in where no Mud hand is free (§4), and pays.
      final braid = _harness([
        _member(0, 'Plant', 'pip'),
        _member(1, 'Water', 'mask'),
        _member(2, 'Plant', 'mane'),
      ]);
      braid.entryDoorRevealed = true;
      _act(braid, 0, 'mire_gate', _ford('tarn_head').headIn('mire_gate')!);
      expect(braid.bog.field.stateOf('tarn_head'), BogFordState.sod);
      expect(braid.combatEnemies, isNotEmpty, reason: 'the braid draws wisps');
    });
  });

  group('Star 1 — THE CHOIR', () {
    test('the three moor knolls demand exactly one legal shape', () {
      final need = <String>{};
      final probe = BogField();
      for (final k in kMoorKnollIds) {
        need.addAll(probe.fordsOf(k).map((f) => f.id));
      }
      expect(need, {'cor_tail', 'add_tail', 'tarn_head', 'tarn_tail'});
      final f = BogField();
      for (final id in need) {
        expect(f.harden(id), isNotNull, reason: '$id must still be draggable');
      }
      for (final k in kMoorKnollIds) {
        expect(f.isDry(k), isTrue, reason: '$k must stand drained');
      }
    });

    test('a basin will not hold on a knoll that still swims', () {
      final game = _harness(_idealTrio());
      final room = game.layout.rooms['sedge_knoll']!;
      _act(game, water, 'sedge_knoll', room.fen!.moor!.basin);
      expect(game.bog.field.moorsWoken, isEmpty);
      expect(game.hasStar(1), isFalse);
    });

    test('THE AUTHORED SOLUTION wakes all three and banks the Moor Star', () {
      final earned = <int>[];
      final game = _harness(_idealTrio(), onStar: earned.add);
      game.entryDoorRevealed = true;

      // The long southern road — the only shape the choir allows.
      _drag(game, 'tarn_head', 'mire_gate');
      _drag(game, 'cor_tail', 'sedge_knoll');
      _drag(game, 'add_tail', 'cairn_knoll');
      _drag(game, 'tarn_tail', 'altar_knoll');
      for (final k in kMoorKnollIds) {
        expect(game.bog.field.isDry(k), isTrue, reason: k);
      }

      _act(
        game,
        water,
        'sedge_knoll',
        game.layout.rooms['sedge_knoll']!.fen!.moor!.basin,
      );
      _act(
        game,
        water,
        'lotus_knoll',
        game.layout.rooms['lotus_knoll']!.fen!.moor!.basin,
      );
      expect(game.hasStar(1), isFalse, reason: 'two of three');
      // The cairn's basin lies under black water: Water MASK (§4).
      _act(
        game,
        water,
        'cairn_knoll',
        game.layout.rooms['cairn_knoll']!.fen!.moor!.basin,
      );
      expect(game.bog.field.moorsWoken.length, 3);
      expect(earned, contains(1));
      expect(game.hasStar(1), isTrue);
    });

    test('the black basin is a HARD gate, and refusing it stamps the chip', () {
      final stamped = <String>[];
      final game = _harness([
        _member(0, 'Mud', 'mane'),
        _member(1, 'Plant', 'pip'),
        _member(2, 'Water', 'horn'), // wrong family on purpose
      ], onCloud: stamped.add);
      game.entryDoorRevealed = true;
      _drag(game, 'tarn_head', 'mire_gate');
      _drag(game, 'cor_tail', 'sedge_knoll');
      _drag(game, 'add_tail', 'cairn_knoll');
      _drag(game, 'tarn_tail', 'altar_knoll');
      _act(
        game,
        water,
        'cairn_knoll',
        game.layout.rooms['cairn_knoll']!.fen!.moor!.basin,
      );
      expect(game.bog.field.moorsWoken, isEmpty);
      expect(stamped, contains('gate:water_mask'));
    });

    test('THE TRAP: the short road kills the choir, for good', () {
      // §5.5's strategic question, made real. Dragging the obvious two-ford
      // road to the altar drowns a crossing the choir needs — and drowned is
      // forever, so the Moor Star is gone until the fen is heaved.
      final game = _harness(_idealTrio());
      game.entryDoorRevealed = true;
      _drag(game, 'add_neck', 'hag_knoll');
      final f = game.bog.field;
      expect(f.stateOf('add_tail'), BogFordState.drowned);
      for (final k in ['cairn_knoll', kLotusKnollId]) {
        expect(f.isDry(k), isFalse);
        expect(
          f.fordsOf(k).any((x) => f.stateOf(x.id) == BogFordState.drowned),
          isTrue,
          reason: '$k can never be dried in this shape',
        );
      }
    });
  });

  group('Star 0 — THE SARSEN', () {
    Offset stoneAt(PlanetDungeonGame g) =>
        Offset(g.layout.rooms['mire_gate']!.bounds.center.dx, 150);
    Offset stoneAtAltar(PlanetDungeonGame g) =>
        Offset(g.layout.rooms['altar_knoll']!.bounds.center.dx, 140);

    test('THE SINKING ALTAR: no fen has both a road to it and dry ground',
        () {
      // This is what makes the star a plan instead of a press: every road to
      // the altar drowns one of the altar's own crossings, so the stone has
      // to be carried in one fen and settled in another, with the heave
      // between them. Enumerated over every legal shape, not argued.
      var shapes = 0;
      for (var h = 0; h < (1 << kBogFords.length); h++) {
        final f = BogField();
        var legal = true;
        for (var i = 0; i < kBogFords.length && legal; i++) {
          if ((h & (1 << i)) == 0) continue;
          legal = f.harden(kBogFords[i].id) != null;
        }
        if (!legal) continue;
        shapes++;
        // A road of sod from the gate to the altar?
        final seen = {'mire_gate'};
        final q = ['mire_gate'];
        while (q.isNotEmpty) {
          final k = q.removeLast();
          for (final x in f.fordsOf(k)) {
            if (f.stateOf(x.id) != BogFordState.sod) continue;
            final o = x.other(k)!;
            if (seen.add(o)) q.add(o);
          }
        }
        final road = seen.contains(kSarsenSocketKnoll);
        expect(
          road && f.isDry(kSarsenSocketKnoll),
          isFalse,
          reason: 'shape ${f.hardened} has a road AND a dry altar',
        );
      }
      expect(shapes, greaterThan(20));
    });

    test('the roots will not carry the stone over anything soft', () {
      final game = _harness(_idealTrio());
      game.entryDoorRevealed = true;
      _drag(game, 'tarn_head', 'mire_gate');
      _act(game, plant, 'mire_gate', stoneAt(game));
      expect(game.bog.field.sarsenKnoll, 'mire_gate');
      expect(game.hintHasAnswer, isTrue, reason: 'the refusal is kept');
    });

    test('only Plant carries the stone', () {
      final game = _harness(_idealTrio());
      game.entryDoorRevealed = true;
      _drag(game, 'add_head', 'mire_gate');
      _drag(game, 'cor_neck', 'reed_knoll');
      _act(game, mud, 'mire_gate', stoneAt(game));
      expect(game.bog.field.sarsenKnoll, 'mire_gate');
      _act(game, water, 'mire_gate', stoneAt(game));
      expect(game.bog.field.sarsenKnoll, 'mire_gate');
      _act(game, plant, 'mire_gate', stoneAt(game));
      expect(game.bog.field.sarsenKnoll, kSarsenSocketKnoll);
    });

    test('a carried stone waits beside a sinking altar', () {
      final earned = <int>[];
      final game = _harness(_idealTrio(), onStar: earned.add);
      game.entryDoorRevealed = true;
      _drag(game, 'add_head', 'mire_gate');
      _drag(game, 'cor_neck', 'reed_knoll');
      _act(game, plant, 'mire_gate', stoneAt(game));
      expect(game.bog.field.sarsenKnoll, kSarsenSocketKnoll);
      expect(game.bog.field.sarsenSeated, isFalse, reason: 'the knoll swims');
      expect(earned, isNot(contains(0)));
    });

    test('THE AUTHORED SOLUTION: carry, heave, drain — the star', () {
      final earned = <int>[];
      final game = _harness(_idealTrio(), onStar: earned.add);
      game.entryDoorRevealed = true;

      // 1. Any road — the choir's long one, which also dries the basins.
      _drag(game, 'tarn_head', 'mire_gate');
      _drag(game, 'cor_tail', 'sedge_knoll');
      _drag(game, 'add_tail', 'lotus_knoll');
      _drag(game, 'tarn_tail', 'cairn_knoll');
      _act(game, plant, 'mire_gate', stoneAt(game));
      expect(game.bog.field.sarsenKnoll, kSarsenSocketKnoll);
      expect(earned, isNot(contains(0)));

      // 2. The heave takes the roads back and leaves the stone.
      final fane = game.layout.rooms['drowned_fane']!;
      _act(game, mud, 'drowned_fane', fane.fen!.sough!);
      expect(game.bog.field.hardened, isEmpty);
      expect(game.bog.field.sarsenKnoll, kSarsenSocketKnoll);

      // 3. Drain the altar's knoll; the last drag seats it.
      _drag(game, 'add_neck', 'altar_knoll');
      _drag(game, 'cor_neck', 'altar_knoll');
      expect(game.bog.field.sarsenSeated, isFalse);
      _drag(game, 'tarn_tail', 'altar_knoll');
      expect(game.bog.field.sarsenSeated, isTrue);
      expect(earned, contains(0));
      expect(game.progressReadout?.label, isNot('ALTAR'));
    });

    test('pressing the waiting stone says what it waits for', () {
      final game = _harness(_idealTrio());
      game.entryDoorRevealed = true;
      _drag(game, 'add_head', 'mire_gate');
      _drag(game, 'cor_neck', 'reed_knoll');
      _act(game, plant, 'mire_gate', stoneAt(game));
      _act(game, mud, 'altar_knoll', stoneAtAltar(game));
      game.askForRoomHint();
      expect(game.hintText?.toLowerCase(), contains('dry'));
      expect(game.progressReadout?.label, 'ALTAR');
    });
  });

  group('WHAT A STAR DID STAYS DONE', () {
    test('a banked Moor Star keeps its basins through the heave and after', () {
      final game = _harness(_idealTrio());
      game.entryDoorRevealed = true;
      for (final (ford, knoll) in [
        ('tarn_head', 'mire_gate'),
        ('cor_tail', 'sedge_knoll'),
        ('add_tail', 'lotus_knoll'),
        ('tarn_tail', 'cairn_knoll'),
      ]) {
        _drag(game, ford, knoll);
      }
      for (final k in kMoorKnollIds) {
        final moor = game.layout.rooms[k]!.fen!.moor!;
        game.bog.field.moorsWoken.add(k); // (the pours; tested elsewhere)
        expect(moor, isNotNull);
      }
      game.earnStar(1);
      final fane = game.layout.rooms['drowned_fane']!;
      _act(game, mud, 'drowned_fane', fane.fen!.sough!);
      expect(game.bog.field.hardened, isEmpty, reason: 'the roads reset');
      expect(
        game.bog.field.moorsWoken,
        containsAll(kMoorKnollIds),
        reason: 'the basins do not',
      );
      // A later drag that leaves a moor knoll wet does not empty it either.
      _drag(game, 'cor_neck', 'reed_knoll');
      expect(game.bog.field.moorsWoken, containsAll(kMoorKnollIds));
    });

    test('a seated stone stays seated through the heave', () {
      final game = _harness(_idealTrio());
      game.bog.field
        ..sarsenKnoll = kSarsenSocketKnoll
        ..sarsenSeated = true;
      final fane = game.layout.rooms['drowned_fane']!;
      _act(game, mud, 'drowned_fane', fane.fen!.sough!);
      expect(game.bog.field.sarsenSeated, isTrue);
      expect(game.bog.field.sarsenKnoll, kSarsenSocketKnoll);
    });
  });

  group('THE RITE — both stars open the hollow', () {
    test('two stars wake Bogdrya and the fane door opens', () {
      final game = _harness(_idealTrio());
      final fane = game.layout.rooms['drowned_fane']!;
      final down = fane.doors.firstWhere(
        (d) => d.targetRoomId == 'bogdrya_hollow',
      );
      game.currentRoomId = 'drowned_fane';
      game.earnStar(1);
      game.update(1 / 60);
      expect(game.isDoorLocked(fane, down), isTrue, reason: 'one star');
      game.earnStar(0);
      game.update(1 / 60);
      expect(game.guardianAwake, isTrue);
      expect(
        game.isDoorLocked(fane, down),
        isFalse,
        reason: 'two stars held and the hollow still would not open — the '
            'bug from the first device run',
      );
    });
  });

  group('THE HINTS SAY "NEVER" WHEN THEY MEAN IT', () {
    test('a basin on a knoll that can never dry says so, not "not yet"', () {
      final game = _harness(_idealTrio());
      game.entryDoorRevealed = true;
      final sedge = game.layout.rooms['sedge_knoll']!.fen!.moor!.basin;

      // Not yet: the knoll is merely wet.
      _act(game, water, 'sedge_knoll', sedge);
      game.askForRoomHint();
      expect(game.hintText?.toLowerCase(), isNot(contains('never')));

      // Never: cor_neck drowns cor_tail, one of Sedge's own crossings.
      _drag(game, 'cor_neck', 'reed_knoll');
      _act(game, water, 'sedge_knoll', sedge);
      game.askForRoomHint();
      expect(game.hintText?.toLowerCase(), contains('never'));
      // And the reading, asked for again, names the way out.
      game.askForRoomHint();
      expect(game.hintText?.toLowerCase(), contains('plug'));
    });

    test('a second HINT press shows the next line at once', () {
      // HINT → the refusal; HINT again used to show NOTHING until the
      // refusal timed out, because a live refusal outranked the reading.
      final game = _harness(_idealTrio());
      game.entryDoorRevealed = true;
      final sough = game.layout.rooms['drowned_fane']!.fen!.sough!;
      _act(game, water, 'drowned_fane', sough); // refused: not Mud
      game.askForRoomHint();
      final first = game.hintText;
      expect(first, isNotNull);
      game.askForRoomHint();
      expect(game.hintText, isNotNull);
      expect(game.hintText, isNot(first));
    });
  });

  group('the vault — an induced map state', () {
    test('cutting the lotus adrift and walking the plank rides it down', () {
      final found = <String>[];
      final game = _harness(_idealTrio(), onCloud: found.add);
      game.entryDoorRevealed = true;
      final f = game.bog.field;

      // Two drags cut both of the lotus's moorings. Note they are exactly the
      // short road the choir forbids — the vault and the Moor Star are
      // opposites, and one run cannot have both without a heave.
      _drag(game, 'add_neck', 'hag_knoll');
      _drag(game, 'cor_neck', 'altar_knoll');
      expect(f.isAdrift(kLotusKnollId), isTrue);

      // The fords into the lotus are gone; only the plank road is left, and
      // only a Mud mane crosses it (§4).
      final cairn = game.layout.rooms['cairn_knoll']!;
      final plank = cairn.doors.where((d) => d.targetRoomId == kLotusKnollId);
      expect(plank.length, 2, reason: 'the ford and the boardwalk');
      game.currentRoomId = 'cairn_knoll';
      game.setActive(mud);
      expect(game.isDoorLocked(cairn, plank.first), isTrue, reason: 'the ford');
      expect(
        game.isDoorLocked(cairn, plank.last),
        isFalse,
        reason: 'the plank',
      );

      // Step onto it, and the knoll goes down under the party's weight.
      game.currentRoomId = kLotusKnollId;
      for (var t = 0.0; t < 3.0; t += 1 / 60) {
        game.bogFounderTickForTest(1 / 60);
      }
      expect(game.bog.field.lotusSunk, isTrue);
      expect(game.currentRoomId, 'sunken_lotus');
      expect(game.layout.rooms['sunken_lotus']!.vaultCache, isNotNull);
    });

    test('a moored lotus never founders', () {
      final game = _harness(_idealTrio());
      game.currentRoomId = kLotusKnollId;
      for (var t = 0.0; t < 5.0; t += 1 / 60) {
        game.bogFounderTickForTest(1 / 60);
      }
      expect(game.bog.field.lotusSunk, isFalse);
      expect(game.currentRoomId, kLotusKnollId);
    });

    test('there is no climbing back into the bowl', () {
      final game = _harness(_idealTrio());
      final bowl = game.layout.rooms['sunken_lotus']!;
      game.currentRoomId = 'sunken_lotus';
      final up = bowl.doors.firstWhere((d) => d.targetRoomId == kLotusKnollId);
      expect(game.isDoorLocked(bowl, up), isTrue);
      final out = bowl.doors.firstWhere(
        (d) => d.targetRoomId == 'drowned_fane',
      );
      expect(game.isDoorLocked(bowl, out), isFalse);
    });
  });

  group('the valve', () {
    test('a Mud hand of ANY family can always wallow down', () {
      // The valve may never depend on a family: a party without the ideal
      // trio still has to be able to get out of a fen it ruined.
      final game = _harness([
        _member(0, 'Mud', 'pip'),
        _member(1, 'Plant', 'horn'),
        _member(2, 'Water', 'kin'),
      ]);
      for (final k in kBogKnollIds) {
        final room = game.layout.rooms[k]!;
        final wallow = room.doors.firstWhere(
          (d) => d.targetRoomId == 'drowned_fane',
        );
        game.currentRoomId = k;
        game.setActive(0);
        expect(game.isDoorLocked(room, wallow), isFalse, reason: k);
        game.setActive(1);
        expect(
          game.isDoorLocked(room, wallow),
          isTrue,
          reason: '$k off-element',
        );
      }
    });

    test('pulling the plug HEAVES the fen there and then, and opens the '
        'way up', () {
      final game = _harness(_idealTrio());
      game.entryDoorRevealed = true;
      _drag(game, 'add_neck', 'hag_knoll');
      _drag(game, 'cor_neck', 'altar_knoll');
      expect(game.bog.field.hardened.length, 2);

      final fane = game.layout.rooms['drowned_fane']!;
      final up = fane.doors.firstWhere((d) => d.targetRoomId == 'mire_gate');
      game.currentRoomId = 'drowned_fane';
      game.setActive(mud);
      expect(game.isDoorLocked(fane, up), isTrue, reason: 'the roof is shut');

      _act(game, mud, 'drowned_fane', fane.fen!.sough!);
      // The reset is the plug, not the climb: still standing in the fane.
      expect(game.currentRoomId, 'drowned_fane');
      expect(game.bog.field.heaves, 1);
      expect(game.bog.field.soughFreed, isTrue);
      expect(game.isDoorLocked(fane, up), isFalse);

      game.onBogTransitForTest(fane, up);
      expect(game.bog.field.heaves, 1, reason: 'climbing out is not another');
      expect(game.bog.field.hardened, isEmpty, reason: 'the price is the map');
      expect(game.bog.field.sarsenKnoll, kSarsenHomeKnoll);
      for (final ford in kBogFords) {
        expect(game.bog.field.stateOf(ford.id), BogFordState.mire);
      }
    });

    test('THE HEAVE IS SPOKEN the moment the plug comes out', () {
      // A world-scale act the player caused has to be said when it happens,
      // not left for them to discover by looking at a map they no longer
      // have (the Ice precedent).
      final game = _harness(_idealTrio());
      game.entryDoorRevealed = true;
      game.beginRun(); // spend any one-time teach first
      _drag(game, 'add_neck', 'hag_knoll');
      final fane = game.layout.rooms['drowned_fane']!;
      game.currentRoomId = 'drowned_fane';
      game.setActive(mud);
      _act(game, mud, 'drowned_fane', fane.fen!.sough!);
      expect(game.hintText, contains('resets'));
    });

    test('THE PLUG PLAYS THE HEAVE, and each knoll settles once after it',
        () {
      final game = _harness(_idealTrio());
      game.entryDoorRevealed = true;
      final fane = game.layout.rooms['drowned_fane']!;
      game.currentRoomId = 'drowned_fane';
      _act(game, mud, 'drowned_fane', fane.fen!.sough!);
      expect(game.bog.heaveFx, greaterThanOrEqualTo(0));

      // Up onto a knoll: it settles, once.
      game.currentRoomId = 'mire_gate';
      game.update(1 / 60);
      expect(game.bog.settleRoom, 'mire_gate');
      expect(game.bog.settleFx, greaterThanOrEqualTo(0));
      for (var i = 0; i < 60 * 4; i++) {
        game.update(1 / 60);
      }
      expect(game.bog.settleFx, lessThan(0), reason: 'it finishes');
      game.currentRoomId = 'hag_knoll';
      game.update(1 / 60);
      game.currentRoomId = 'mire_gate';
      game.update(1 / 60);
      expect(
        game.bog.settleRoom,
        'hag_knoll',
        reason: 'the gate already settled; walking back does not replay it',
      );
    });

    test('a banked star survives the heave', () {
      final game = _harness(_idealTrio());
      game.earnStar(0);
      game.bog.field.heave();
      expect(game.hasStar(0), isTrue);
    });
  });

  group('the guardian', () {
    test('Bogdrya keeps its lull shut while the floor still quakes', () {
      final game = _harness(_idealTrio());
      final room = game.layout.rooms['bogdrya_hollow']!;
      game.currentRoomId = 'bogdrya_hollow';
      game.guardianAwake = true;
      game.guardianVulnerable = true;
      game.bog.field.anchorFirm = false;
      game.update(1 / 60);
      expect(game.guardianVulnerable, isFalse);

      _act(game, mud, 'bogdrya_hollow', room.fen!.anchor!);
      expect(game.bog.field.anchorFirm, isTrue);
    });

    test('every strike beat swallows one of the roads you left above', () {
      final game = _harness(_idealTrio());
      game.entryDoorRevealed = true;
      _drag(game, 'tarn_head', 'mire_gate');
      _drag(game, 'cor_tail', 'sedge_knoll');
      expect(game.bog.field.hardened.length, 2);

      game.currentRoomId = 'bogdrya_hollow';
      game.guardianAwake = true;
      game.bog.field.anchorFirm = true;
      // The lull opens…
      game.guardianVulnerable = true;
      game.update(1 / 60);
      // …and closes: the wyrm takes the anchor and a causeway with it.
      game.guardianVulnerable = false;
      game.update(1 / 60);
      expect(game.bog.field.anchorFirm, isFalse);
      expect(game.bog.field.hardened.length, 1);
    });
  });

  // ─────────────────────────────────────────────────────────
  // CAN THE PLAYER TELL WHAT IS GOING ON?
  //
  // From the first device session: *"it's not very intuitive, I'm not sure
  // what the goal is, I'm just going around tapping things."* The puzzle was
  // sound and provably unique and completely unreadable, because the rule's
  // INPUTS were hidden: which water a crossing sits on, what a drag is about
  // to cost, and what the fen looks like now. These pin the answers.
  group('the fen can be read', () {
    test('standing at a workable head names exactly what it would drown', () {
      final game = _harness(_idealTrio())..entryDoorRevealed = true;
      game.currentRoomId = 'mire_gate';
      final head = _ford('add_head').headIn('mire_gate')!;
      for (final c in game.creatures) {
        c
          ..position = head
          ..lastSafe = head;
      }
      game.setActive(mud);
      // add_head's only slough-neighbour is add_neck.
      expect(game.bogDoomedByHand, {'add_neck'});

      // …and it is the truth: dragging really does take that one.
      game.activateAbility();
      expect(game.bog.field.stateOf('add_neck'), BogFordState.drowned);
    });

    test('a crossing that cannot be dragged promises nothing', () {
      final game = _harness(_idealTrio())..entryDoorRevealed = true;
      game.bog.field.harden('add_neck'); // drowns add_head
      game.currentRoomId = 'mire_gate';
      final head = _ford('add_head').headIn('mire_gate')!;
      for (final c in game.creatures) {
        c
          ..position = head
          ..lastSafe = head;
      }
      game.setActive(mud);
      expect(
        game.bogDoomedByHand,
        isEmpty,
        reason:
            'open water has nothing left to pull on, so it costs '
            'nothing and must not say it would',
      );
    });

    test('standing nowhere near a crossing promises nothing', () {
      final game = _harness(_idealTrio())..entryDoorRevealed = true;
      game.currentRoomId = 'mire_gate';
      for (final c in game.creatures) {
        c
          ..position = const Offset(300, 500)
          ..lastSafe = const Offset(300, 500);
      }
      game.setActive(mud);
      expect(game.bogDoomedByHand, isEmpty);
    });

    test('THE STONE ANSWERS A PRESS, instead of doing nothing at all', () {
      // Walking up to the big stone and pressing is the first thing anybody
      // does on this planet. It once fell through to the wordless element
      // puff — silence, at the one object the whole star is about. A hand
      // that cannot carry it now says who can.
      final game = _harness(_idealTrio())..entryDoorRevealed = true;
      final hints = <String>[];
      game.currentRoomId = 'mire_gate';
      final stone = Offset(
        game.layout.rooms['mire_gate']!.bounds.center.dx,
        150,
      );
      for (final c in game.creatures) {
        c
          ..position = stone
          ..lastSafe = stone;
      }
      game.setActive(mud);
      game.activateAbility();
      // THE DUNGEON DOES NOT NARRATE: an unasked-for refusal is remembered
      // and flashed at the creature, and the capsule says it when the player
      // presses HINT. What matters here is that there IS an answer — before,
      // the press fell through to the wordless puff and stored nothing.
      expect(
        game.hintHasAnswer,
        isTrue,
        reason: 'the stone said nothing at all when pressed',
      );
      expect(game.refusalFlash, greaterThan(0));
      game.askForRoomHint();
      hints.add(game.hintText ?? '');
      expect(hints.single.toLowerCase(), contains('plant'));
    });

    test('the readout says whether the road is whole', () {
      final game = _harness(_idealTrio())..entryDoorRevealed = true;
      game.currentRoomId = 'mire_gate';
      expect(game.progressReadout?.label, 'ROAD');
      expect(game.progressReadout?.value, 'broken');

      _drag(game, 'tarn_head', 'mire_gate');
      _drag(game, 'tarn_tail', 'altar_knoll');
      // tarn_head joins the gate to sedge; tarn_tail joins altar to cairn.
      // Still nothing continuous between the stone and the socket.
      expect(game.progressReadout?.value, 'broken');
      _drag(game, 'cor_tail', 'sedge_knoll');
      _drag(game, 'add_tail', 'lotus_knoll');
      expect(game.progressReadout?.value, 'whole');
    });
  });

  group('THE WALLOW ARRIVALS — the carried fault, settled', () {
    // Every knoll's wallow drops you onto the fane hatch you just came
    // through: the arrival sits inside a 54x54 floor hatch, which the
    // doorway invariant exempts on the grounds that a hatch is climbed out
    // of and arriving on top of one is Mud's fiction rather than a fault.
    //
    // That exemption had never been checked, and it is only safe for a
    // reason nothing stated: a risen wallow is shut until the sough is
    // freed, and climbing one HEAVES — which re-plugs the sough behind you.
    // If either half of that ever stopped being true, landing on the hatch
    // would hand the player an unasked-for heave half a second after they
    // arrived, and every road they had dragged with it.
    test('every wallow lands you on its own hatch', () {
      final layout = kPlanetDungeonLayouts['Mud']!;
      final fane = layout.rooms['drowned_fane']!;
      for (final knollId in kBogKnollIds) {
        final down = layout.rooms[knollId]!.doors.firstWhere(
          (d) => d.targetRoomId == 'drowned_fane',
        );
        final up = fane.doors.firstWhere((d) => d.targetRoomId == knollId);
        expect(
          up.rect.contains(down.targetSpawn),
          isTrue,
          reason: '$knollId: the wallow has to put you at the foot of itself',
        );
      }
    });

    test('and standing on it costs you nothing, because it is shut', () {
      final game = _harness(_idealTrio());
      final layout = game.layout;
      final fane = layout.rooms['drowned_fane']!;

      // Down the gate's wallow, and stand exactly where it puts you.
      game.entryDoorRevealed = true;
      _drag(game, 'tarn_head', 'mire_gate');
      final down = layout.rooms['mire_gate']!.doors.firstWhere(
        (d) => d.targetRoomId == 'drowned_fane',
      );
      game.setActive(mud);
      game.passThroughDoor(down);
      expect(game.currentRoomId, 'drowned_fane');
      final onHatch = fane.doors
          .firstWhere((d) => d.targetRoomId == 'mire_gate')
          .rect
          .center;
      for (final c in game.creatures) {
        c
          ..position = onHatch
          ..lastSafe = onHatch;
      }
      // Long past the door cooldown, without moving a step.
      for (var tick = 0; tick < 240; tick++) {
        game.update(1 / 60);
      }
      expect(
        game.currentRoomId,
        'drowned_fane',
        reason: 'the hatch is shut, so standing on it is standing still',
      );
      expect(game.bog.field.heaves, 0);
      expect(game.bog.field.hardened, contains('tarn_head'));
    });

    test('CLIMBING OUT RE-PLUGS THE SOUGH, which is what makes the arrival '
        'safe at all', () {
      final game = _harness(_idealTrio());
      final fane = game.layout.rooms['drowned_fane']!;
      _act(game, mud, 'drowned_fane', fane.fen!.sough!);
      expect(game.bog.field.soughFreed, isTrue);
      game.onBogTransitForTest(
        fane,
        fane.doors.firstWhere((d) => d.targetRoomId == 'mire_gate'),
      );
      expect(
        game.bog.field.soughFreed,
        isFalse,
        reason:
            'if climbing out left the sough open, the next wallow down would '
            'drop you onto an OPEN hatch and carry you straight back up',
      );
    });
  });

  group('the lost maxim — NO MUD, NO LOTUS (the Black Lead)', () {
    /// Every legal fen shape, by construction: an independent set in each of
    /// the three slough chains, taken independently.
    List<Set<String>> allShapes() {
      final perSlough = <String, List<List<String>>>{};
      for (final sl in kSloughNames.keys) {
        final ids = [
          for (var i = 0; i < 3; i++)
            kBogFords.firstWhere((f) => f.slough == sl && f.index == i).id,
        ];
        perSlough[sl] = [
          [],
          [ids[0]],
          [ids[1]],
          [ids[2]],
          [ids[0], ids[2]],
        ];
      }
      final out = <Set<String>>[];
      for (final a in perSlough['cor']!) {
        for (final b in perSlough['add']!) {
          for (final c in perSlough['tarn']!) {
            out.add({...a, ...b, ...c});
          }
        }
      }
      return out;
    }

    test('FULL DROWN is one shape in the whole fen, and it is the three '
        'middles', () {
      final shapes = allShapes();
      expect(shapes, hasLength(125), reason: 'the fen\'s legal shapes');
      final full = <Set<String>>[];
      var maxSeen = 0;
      for (final sh in shapes) {
        final f = BogField()..hardened.addAll(sh);
        maxSeen = max(maxSeen, f.drownedCount);
        if (f.fenAtFullDrown) full.add(sh);
      }
      expect(
        maxSeen,
        kMaxDrowned,
        reason: 'six of nine is the most water this fen can carry',
      );
      expect(
        full,
        hasLength(1),
        reason: 'the secret has to demand ONE shape, not a family of them',
      );
      expect(full.single, {'cor_neck', 'add_neck', 'tarn_neck'});
    });

    test('THE SECRET IS THE SHAPE THE STARS FORBID', () {
      // The choir's four fords and the full-drown three share nothing, and
      // full drown drowns every one the choir needs. That opposition is the
      // whole design: you cannot hold the secret's fen and a star's at once,
      // and the heave is the only way between them.
      final f = BogField()
        ..hardened.addAll({'cor_neck', 'add_neck', 'tarn_neck'});
      for (final need in const [
        'cor_tail',
        'add_tail',
        'tarn_head',
        'tarn_tail',
      ]) {
        expect(
          f.stateOf(need),
          BogFordState.drowned,
          reason: '$need is what the choir wants, and full drown takes it',
        );
      }
      for (final k in kMoorKnollIds) {
        expect(f.isDry(k), isFalse);
      }
    });

    test('a choked lead answers nothing at all', () {
      final found = <String>[];
      final game = _harness(_idealTrio(), onCloud: found.add);
      final fen = game.layout.rooms['drowned_fane']!.fen!;
      // The fen as it opens: no drag anywhere, so the lead is dry.
      _act(game, water, 'drowned_fane', fen.leadHead!);
      expect(
        game.bog.cutsFound,
        isFalse,
        reason: 'the secret must not be workable before its own condition',
      );
      _act(game, plant, 'drowned_fane', fen.sinkPit!);
      expect(game.bog.seedSet, isFalse);
    });

    void fullDrown(PlanetDungeonGame g) {
      _drag(g, 'cor_neck', 'reed_knoll');
      _drag(g, 'add_neck', 'hag_knoll');
      _drag(g, 'tarn_neck', 'hag_knoll');
      expect(g.bog.field.fenAtFullDrown, isTrue);
    }

    test('THE AUTHORED CHAIN: drown the fen, read the cuts, seed the sink, '
        'and bury it three times over', () {
      final found = <String>[];
      final game = _harness(_idealTrio(), onCloud: found.add);
      final fen = game.layout.rooms['drowned_fane']!.fen!;
      fullDrown(game);

      // 2 · Water reads the cuts out of the black water. Nothing else does.
      _act(game, mud, 'drowned_fane', fen.leadHead!);
      expect(game.bog.cutsFound, isFalse);
      _act(game, water, 'drowned_fane', fen.leadHead!);
      expect(game.bog.cutsFound, isTrue);

      // 4 before 3 · a pour with nothing in the sink changes nothing.
      _act(game, mud, 'drowned_fane', fen.peatCuts![0]);
      expect(
        game.bog.poured,
        isEmpty,
        reason: 'the beats have to be a CHAIN, not three keys in a lock',
      );

      // 3 · the seed.
      _act(game, water, 'drowned_fane', fen.sinkPit!);
      expect(game.bog.seedSet, isFalse);
      _act(game, plant, 'drowned_fane', fen.sinkPit!);
      expect(game.bog.seedSet, isTrue);

      // 5 · the repeated beat, and only the last one pays.
      for (var i = 0; i < 3; i++) {
        expect(found, isNot(contains(kMudLotusEggId)));
        _act(game, mud, 'drowned_fane', fen.peatCuts![i]);
        expect(game.bog.poured, hasLength(i + 1));
      }
      // THE RITE OF THREE runs before the gold lands (see `beginMaximRite`).
      for (var tick = 0; tick < 200; tick++) {
        game.update(1 / 60);
      }
      expect(found, contains(kMudLotusEggId));
    });

    test('NOTHING IS CONSUMED — a wrong hand costs a press and no more', () {
      final game = _harness(_idealTrio());
      final fen = game.layout.rooms['drowned_fane']!.fen!;
      fullDrown(game);

      // Wrong hands at the reading, twice over — and the cuts stay hidden.
      for (var i = 0; i < 2; i++) {
        _act(game, mud, 'drowned_fane', fen.leadHead!);
        _act(game, plant, 'drowned_fane', fen.leadHead!);
      }
      expect(game.bog.cutsFound, isFalse);
      _act(game, water, 'drowned_fane', fen.leadHead!);
      expect(game.bog.cutsFound, isTrue);

      // Wrong hands at the sink, twice over — and the sink stays empty.
      for (var i = 0; i < 2; i++) {
        _act(game, water, 'drowned_fane', fen.sinkPit!);
        _act(game, mud, 'drowned_fane', fen.sinkPit!);
      }
      expect(game.bog.seedSet, isFalse);
      _act(game, plant, 'drowned_fane', fen.sinkPit!);
      expect(game.bog.seedSet, isTrue);

      // …and the chain still finishes, none the worse.
      for (var i = 0; i < 3; i++) {
        _act(game, mud, 'drowned_fane', fen.peatCuts![i]);
      }
      expect(game.bog.poured, hasLength(3));
    });

    test('the braid pours too, at its usual price', () {
      // **Plant+Water→Mud** carries the drag everywhere else on this planet,
      // so it has to carry it here: a secret that demanded a specific body
      // would be a family gate wearing a maxim's clothes.
      final game = _harness(_idealTrio());
      final fen = game.layout.rooms['drowned_fane']!.fen!;
      fullDrown(game);
      _act(game, water, 'drowned_fane', fen.leadHead!);
      _act(game, plant, 'drowned_fane', fen.sinkPit!);
      _act(game, plant, 'drowned_fane', fen.peatCuts![0]);
      expect(game.bog.poured, hasLength(1));
    });

    test('a heave washes the lead out, and it can always be done again', () {
      final game = _harness(_idealTrio());
      final fen = game.layout.rooms['drowned_fane']!.fen!;
      fullDrown(game);
      _act(game, water, 'drowned_fane', fen.leadHead!);
      _act(game, plant, 'drowned_fane', fen.sinkPit!);
      _act(game, mud, 'drowned_fane', fen.peatCuts![0]);
      expect(game.bog.poured, hasLength(1));

      // The sough, and out: the fen goes back to the shape it opened in.
      _act(game, mud, 'drowned_fane', fen.sough!);
      game.onBogTransitForTest(
        game.layout.rooms['drowned_fane']!,
        game.layout.rooms['drowned_fane']!.doors.first,
      );
      expect(game.bog.field.fenAtFullDrown, isFalse);

      // Nothing is lost: drown it again and the chain is there to be walked.
      fullDrown(game);
      _act(game, water, 'drowned_fane', fen.leadHead!);
      _act(game, plant, 'drowned_fane', fen.sinkPit!);
      for (var i = 0; i < 3; i++) {
        _act(game, mud, 'drowned_fane', fen.peatCuts![i]);
      }
      expect(game.bog.poured, hasLength(3));
    });
  });
}
