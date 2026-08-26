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
      expect(
        lotus.doors.any((d) => d.targetRoomId == 'sunken_lotus'),
        isTrue,
      );
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
      expect(
        layout.familyGates.map((g) => g.objectId).toSet(),
        {'moor_black', 'plank_road'},
      );
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
      expect(r.states, 1284, reason: 'the whole (room × fen × valve) graph');
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

    test('a Mane-less party is not stranded either, it just loses the vault',
        () {
      final game = _harness(_idealTrio());
      final r = game.solveFenTerraform(plankPassable: false);
      expect(r.strandable, 0);
    });

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
      // For the record, and so a future softening shows up as a diff: 1200 of
      // 1284 states — 93% — would be dead ends without the valve.
      expect(r.strandableWithoutSough, 1200);
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
    test('hardening one crossing drowns its neighbours on the same slough',
        () {
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

    test('the black basin is a HARD gate, and refusing it stamps the chip',
        () {
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
    test('the stone will not cross anything soft', () {
      final game = _harness(_idealTrio());
      game.entryDoorRevealed = true;
      _act(game, mud, 'mire_gate', _ford('tarn_head').headIn('mire_gate')!);
      // That press DRAGGED the crossing (the drag runs first); the stone only
      // moves on the second press, now that the road stands.
      expect(game.bog.field.stateOf('tarn_head'), BogFordState.sod);
      expect(game.bog.field.sarsenKnoll, 'mire_gate');
      _act(game, mud, 'mire_gate', _ford('tarn_head').headIn('mire_gate')!);
      expect(game.bog.field.sarsenKnoll, 'sedge_knoll');
    });

    test('THE AUTHORED SOLUTION hauls the stone home and banks the star', () {
      final earned = <int>[];
      final game = _harness(_idealTrio(), onStar: earned.add);
      game.entryDoorRevealed = true;

      // The same four crossings the choir demanded: THE CHOIR TELLS YOU THE
      // ROAD. One drag each, then one haul each, knoll to knoll.
      const legs = [
        ('tarn_head', 'mire_gate', 'sedge_knoll'),
        ('cor_tail', 'sedge_knoll', 'lotus_knoll'),
        ('add_tail', 'lotus_knoll', 'cairn_knoll'),
        ('tarn_tail', 'cairn_knoll', 'altar_knoll'),
      ];
      for (final (ford, from, to) in legs) {
        _drag(game, ford, from);
        _act(game, mud, from, _ford(ford).headIn(from)!); // the haul
        expect(game.bog.field.sarsenKnoll, to, reason: ford);
      }

      final altar = game.layout.rooms['altar_knoll']!.fen!.altar!;
      // The socket's resin cap: Plant+Mud→Poison, the planet's own braid.
      _act(game, plant, 'altar_knoll', altar.cap);
      expect(game.bog.field.socketOpen, isTrue);
      _act(game, mud, 'altar_knoll', altar.socket);
      expect(game.bog.field.sarsenSeated, isTrue);
      expect(earned, contains(0));
    });

    test('the socket refuses a lone hand — the braid is the only key', () {
      final game = _harness([
        _member(0, 'Mud', 'mane'),
        _member(1, 'Water', 'mask'),
        _member(2, 'Water', 'pip'),
      ]);
      final altar = game.layout.rooms['altar_knoll']!.fen!.altar!;
      _act(game, 0, 'altar_knoll', altar.cap);
      expect(game.bog.field.socketOpen, isFalse);
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
      expect(game.isDoorLocked(cairn, plank.last), isFalse, reason: 'the plank');

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
        expect(game.isDoorLocked(room, wallow), isTrue, reason: '$k off-element');
      }
    });

    test('the sough opens the way up, and climbing it HEAVES the fen', () {
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
      expect(game.bog.field.soughFreed, isTrue);
      expect(game.isDoorLocked(fane, up), isFalse);

      game.onBogTransitForTest(fane, up);
      expect(game.bog.field.heaves, 1);
      expect(game.bog.field.hardened, isEmpty, reason: 'the price is the map');
      expect(game.bog.field.sarsenKnoll, kSarsenHomeKnoll);
      for (final ford in kBogFords) {
        expect(game.bog.field.stateOf(ford.id), BogFordState.mire);
      }
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

  group('the lost maxim — NO MUD, NO LOTUS', () {
    test('seed, water, and let it go all the way down', () {
      final found = <String>[];
      final game = _harness(_idealTrio(), onCloud: found.add);
      final pit = game.layout.rooms['drowned_fane']!.fen!.sinkPit!;
      _act(game, plant, 'drowned_fane', pit);
      _act(game, water, 'drowned_fane', pit);
      expect(found, isNot(contains(kMudLotusEggId)));
      _act(game, mud, 'drowned_fane', pit);
      expect(found, contains(kMudLotusEggId));
    });
  });
}
