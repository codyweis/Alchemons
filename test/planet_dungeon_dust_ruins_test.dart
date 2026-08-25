// SABLIS — the Ruins of Time, pinned.
//
// Dust's topology is a BURIED CITY on two Z-layers whose ground is mutable and
// whose every edit is irreversible (docs §5.5), so this file carries the two
// proofs the design cannot ship without:
//
//  1. CONSERVATION. Dust's claimed mechanic is the ledger: nothing perishes,
//     every verb is a transfer, and the total never moves. A leak in it
//     silently voids every puzzle stacked on top, so it is asserted after
//     EVERY verb of a long scripted run, inside the exhaustive search, and at
//     the boundaries (the sirocco, the guardian's storm).
//  2. THE NO-STRAND PROOF. A full reachability search over (room × every
//     mound's load count), enumerated under player moves AND Ashdjinn's storm,
//     audited using only the moves the player controls.
//
// The rest pins the mound trade, the two hard gates, the vault trick and the
// guardian against the real rules.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dust.dart';
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

/// The §6 ideal trio: Dustmask · Airwing · Earthhorn.
List<CosmicPartyMember> _idealTrio() => [
  _member(0, 'Dust', 'mask'),
  _member(1, 'Air', 'wing'),
  _member(2, 'Earth', 'horn'),
];

const int dust = 0, air = 1, earth = 2;

PlanetDungeonGame harness(
  List<CosmicPartyMember> party, {
  void Function(int)? onStar,
  void Function(String)? onCloud,
}) {
  final game = PlanetDungeonGame(
    element: 'Dust',
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

/// Point [idx] at [aim] radians as well — the mound verbs decide WHERE the
/// spoil lands from the body's facing, so a test has to face too.
void actFacing(
  PlanetDungeonGame game,
  int idx,
  String room,
  Offset pos,
  double aim,
) {
  game.currentRoomId = room;
  game.setActive(idx);
  for (final c in game.creatures) {
    c
      ..position = pos
      ..lastSafe = pos
      ..angle = aim
      ..aimAngle = aim;
  }
  game.activateAbility();
}

const double east = 0.0;
const double west = 3.14159265;
const double north = -1.5707963;
const double south = 1.5707963;

Offset crownOf(String moundId) => dustMoundById(moundId)!.streetPos;
String roomOf(String moundId) => dustMoundById(moundId)!.roomId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final layout = kPlanetDungeonLayouts['Dust']!;

  group('the city — topology', () {
    test('every mound names real rooms, and every leg has a door', () {
      for (final m in kDustMounds) {
        expect(layout.rooms[m.roomId], isNotNull, reason: '${m.id} room');
        expect(
          layout.rooms[m.roomId]!.bounds.contains(m.streetPos),
          isTrue,
          reason: '${m.id} crown must stand inside its own room',
        );
        if (m.crossFrom != null) {
          final a = layout.rooms[m.crossFrom]!;
          final b = layout.rooms[m.crossTo]!;
          expect(
            a.doors.any((d) => d.targetRoomId == m.crossTo),
            isTrue,
            reason: '${m.id}: no crossing out of ${m.crossFrom}',
          );
          expect(
            b.doors.any((d) => d.targetRoomId == m.crossFrom),
            isTrue,
            reason: '${m.id}: no crossing back from ${m.crossTo}',
          );
        }
        if (m.cellarRoomId != null) {
          expect(
            layout.rooms[m.roomId]!.doors.any(
              (d) => d.targetRoomId == m.cellarRoomId,
            ),
            isTrue,
            reason: '${m.id}: no hole down into ${m.cellarRoomId}',
          );
        }
        if (m.rampRoomId != null) {
          expect(
            layout.rooms[m.roomId]!.doors.any(
              (d) => d.targetRoomId == m.rampRoomId,
            ),
            isTrue,
            reason: '${m.id}: no climb up onto ${m.rampRoomId}',
          );
        }
        for (final n in m.neighbours) {
          final other = dustMoundById(n);
          expect(other, isNotNull, reason: '${m.id} → $n');
          expect(
            other!.neighbours,
            contains(m.id),
            reason: 'a spadeful must reach both ways: ${m.id} ↔ $n',
          );
        }
      }
    });

    test('the vault is a pocket you can always crawl out of', () {
      // §5.5's vault trick is the whole reason the search comes out clean:
      // entry needs the bump HEAPED, but the crack you came through is never
      // blocked behind you. Ice's shelf rule, and without it the sunken house
      // is a trap in 10 of the 396 states.
      final cacheRoom = layout.rooms.values.singleWhere(
        (r) => r.vaultCache != null,
      );
      expect(cacheRoom.doors.length, 1, reason: 'the vault must be a pocket');
      final bump = kDustMounds.singleWhere((m) => m.pressedRoomId != null);
      expect(bump.pressedRoomId, cacheRoom.id);
      expect(
        bump.crossFrom,
        isNull,
        reason: 'the roof bump carries no street — it is only a swell',
      );
      expect(
        bump.cellarRoomId,
        isNull,
        reason: 'baring the bump must show tiles and nothing else: the vault '
            'is the one thing you get by burying HARDER',
      );
    });

    test('no star hides behind a mound that can be lost', () {
      // The seal street is a street; the observatory hangs off the undercity's
      // permanent tunnels. Neither can be dug away from you.
      for (final room in layout.rooms.values) {
        final idx = room.ruins?.starIndex;
        if (idx == null) continue;
        final permanent = room.doors.any((d) {
          for (final m in kDustMounds) {
            if (m.crossFrom == room.id && m.crossTo == d.targetRoomId) {
              return false;
            }
            if (m.crossTo == room.id && m.crossFrom == d.targetRoomId) {
              return false;
            }
            if (m.roomId == room.id && m.cellarRoomId == d.targetRoomId) {
              return false;
            }
            if (m.roomId == room.id && m.rampRoomId == d.targetRoomId) {
              return false;
            }
          }
          return true;
        });
        expect(
          permanent || room.id == 'seal_street',
          isTrue,
          reason: '${room.id} holds star $idx and every way out is mutable',
        );
      }
    });

    test('§4: two hard gates, on different slots, and Star 0 is ungated', () {
      expect(layout.familyGates.length, 2);
      final slots = kCosmicPlanetEntry['Dust']!;
      final gated = layout.familyGates.map((g) => g.element).toSet();
      expect(gated.length, 2, reason: 'one gate per entry slot at most');
      for (final g in layout.familyGates) {
        expect(slots, contains(g.element));
      }
      // The three seals — the star a first descent must be able to earn —
      // carry no family gate of any kind, and the yard's two verbs are the
      // planet's own element and Air, both element-only.
      expect(gated, isNot(contains('Dust')));
    });

    test('the ideal trio is index-aligned with the entry slots', () {
      expect(kCosmicPlanetEntry['Dust'], ['Dust', 'Air', 'Earth']);
      expect(kDungeonIdealFamilies['Dust'], ['Mask', 'Wing', 'Horn']);
      expect(kComingSoonDungeons, isNot(contains('Dust')));
      // The raid registry is DERIVED — Ashdjinn must arrive for free.
      expect(kRaidGuardianIds['Dust'], 'Ashdjinn');
    });
  });

  group('THE CONSERVATION INVARIANT', () {
    test('the opening ledger is exactly what the constants claim', () {
      final r = RuinsOfTime();
      expect(r.dustTotal, kDustTotalLoads);
      expect(r.cityLoads, kDustCityLoads);
      expect(r.driftLoads, kSealYard.totalLoads);
      expect(r.hollowLoads, kHollowLoads);
      expect(r.conserved, isTrue);
      // Every mound starts plainly buried: the city as its dead left it.
      for (final m in kDustMounds) {
        expect(r.stateOf(m.id), MoundState.buried);
      }
    });

    test('no sequence of verbs can create or destroy a load', () {
      final r = RuinsOfTime();
      void check(String what) =>
          expect(r.conserved, isTrue, reason: 'the ledger leaked at $what');

      // Every city verb, legal and illegal.
      expect(r.dig('m_gate', 'm_agora'), isTrue);
      check('a dig');
      expect(r.dig('m_gate', 'm_agora'), isFalse, reason: 'already bared');
      check('a refused re-dig');
      expect(r.dig('m_roof', 'm_agora'), isFalse, reason: 'agora is full');
      check('a refused over-heap');
      expect(r.dig('m_roof', 'm_bump'), isTrue);
      check('the vault dig');
      expect(r.dig('m_bump', 'm_kiln'), isFalse, reason: 'drifted is packed');
      check('a refused spade on a dune');
      expect(r.undoOneDig(), isNotNull);
      check('the storm undoing a dig');

      // Every yard verb.
      final cols = kSealYard.cols;
      expect(r.scourDrift(0, 1), isTrue); // (0,0) → (1,0), a seal
      check('a scour');
      expect(r.digDrift(1, 3), isFalse, reason: 'the seal is a dune now');
      check('a refused spade on a heaped seal');
      expect(r.scourDrift(1, 2), isFalse, reason: '(2,0) is already full');
      check('a refused over-scour');
      expect(r.scourDrift(cols, cols + 1), isFalse, reason: 'that is a pillar');
      check('a refused throw at a pillar');

      // The hollow.
      expect(r.buryHollow(), isTrue);
      check('the storm burying the cut');
      expect(r.clearHollow(), isTrue);
      check('a hand clearing the cut');
      for (var i = 0; i < kHollowLoads + 3; i++) {
        r.buryHollow();
      }
      check('the storm running the bank dry');
      expect(r.hollowBank, 0);

      // And the sirocco, which is a permutation of the same multiset.
      r.levelCity();
      check('the sirocco');
      expect(r.cityLoads, kDustCityLoads);
      expect(r.driftLoads, kSealYard.totalLoads);
      expect(
        r.hollowLoads,
        kHollowLoads,
        reason: 'the wind blows through the streets, not the hollow',
      );
    });

    test('the sirocco puts every load back where the city keeps it', () {
      final r = RuinsOfTime();
      r.dig('m_gate', 'm_agora');
      r.dig('m_roof', 'm_bump');
      r.scourDrift(0, 1);
      expect(r.isLevelled, isFalse);
      r.levelCity();
      expect(r.isLevelled, isTrue);
      expect(r.conserved, isTrue);
      expect(r.levellings, 1);
      for (final m in kDustMounds) {
        expect(r.stateOf(m.id), MoundState.buried, reason: 'the price is all');
      }
    });
  });

  group('THE NO-STRAND PROOF', () {
    late ({
      int states,
      int arrangements,
      int strandable,
      int strandableWithoutWind,
      int vaultLosable,
      bool conserved,
    })
    r;

    setUpAll(() {
      r = harness(_idealTrio()).solveBuriedCity();
    });

    test('the search is real, and the ledger holds across all of it', () {
      // MEASURED 2026-08-24: 396 states over 51 distinct arrangements of the
      // five mounds. Pinned exactly, so that re-authoring the city has to come
      // back through this file and re-state its numbers.
      expect(r.states, 396, reason: 'the search must be real');
      expect(r.arrangements, 51);
      expect(
        r.conserved,
        isTrue,
        reason: 'every arrangement the world can reach still holds '
            '$kDustCityLoads loads',
      );
    });

    test('no state reachable by legal play — or by the storm — can strand '
        'the party', () {
      expect(
        r.strandable,
        0,
        reason: 'from EVERY reachable state, every room — the exit, both star '
            'rooms, the rite, the vault and both optional cellars — must '
            'still be reachable',
      );
    });

    test('the sirocco is load-bearing, not decoration', () {
      // Delete the vanes and the planet becomes exactly the stranding machine
      // the design warns about (Ice measured 120/122, Mud 1200/1284). If this
      // ever reaches zero somebody has quietly made a dig reversible and Dust
      // has lost its identity.
      // MEASURED 2026-08-24: 319 of the same 396 states (81%) are strandable
      // with the vanes deleted — the same wall Ice hit at 120/122 and Mud at
      // 1200/1284, and answered the same way: a costly full reset rather than
      // a softened mechanic.
      expect(
        r.strandableWithoutWind,
        319,
        reason: 'a dig must really be irreversible',
      );
    });

    test('the vault CAN be put out of reach — that is the trick', () {
      // MEASURED 2026-08-24: 209 of 396.
      expect(
        r.vaultLosable,
        209,
        reason: 'the sunken house only opens under a heaped bump: from most '
            'arrangements it costs a sirocco to get back to one',
      );
    });
  });

  group('the mound trade', () {
    test('one spadeful bares one square, buries another, and shuts two '
        'crossings', () {
      final game = harness(_idealTrio());
      final gate = game.layout.rooms['ashen_gate']!;
      // The arch is silted: nothing here is even visible yet.
      for (final d in gate.doors) {
        expect(game.isDoorHidden(gate, d), isTrue);
      }
      act(game, dust, 'ashen_gate', gate.ruins!.gateSilt!);
      expect(game.entryDoorRevealed, isTrue);

      final street = gate.doors.firstWhere(
        (d) => d.targetRoomId == 'seal_street',
      );
      final hole = gate.doors.firstWhere((d) => d.targetRoomId == 'granary');
      expect(game.isDoorHidden(gate, street), isFalse);
      expect(game.isDoorLocked(gate, street), isFalse);
      expect(game.isDoorHidden(gate, hole), isTrue, reason: 'no hole yet');

      // Dig the gate square, throwing east onto the agora.
      actFacing(game, earth, 'ashen_gate', crownOf('m_gate'), east);
      expect(game.ruins.stateOf('m_gate'), MoundState.bared);
      expect(game.ruins.stateOf('m_agora'), MoundState.drifted);
      expect(game.ruins.conserved, isTrue);

      // The crossing is a trench now, and the granary is open.
      expect(game.isDoorLocked(gate, street), isTrue);
      expect(game.isDoorHidden(gate, hole), isFalse);

      // …and out on the agora, the street east is a dune and the terrace ramp
      // stands: one spadeful, both consequences.
      final seal = game.layout.rooms['seal_street']!;
      final onward = seal.doors.firstWhere(
        (d) => d.targetRoomId == 'roof_walk',
      );
      final ramp = seal.doors.firstWhere(
        (d) => d.targetRoomId == 'high_terrace',
      );
      expect(game.isDoorLocked(seal, onward), isTrue);
      expect(game.isDoorHidden(seal, ramp), isFalse);
    });

    test('a bared square has nothing left and a dune is packed — both edits '
        'are for the run', () {
      final game = harness(_idealTrio());
      game.entryDoorRevealed = true;
      actFacing(game, earth, 'ashen_gate', crownOf('m_gate'), east);
      // Re-dig the trench: nothing there.
      actFacing(game, earth, 'ashen_gate', crownOf('m_gate'), east);
      expect(game.ruins.stateOf('m_gate'), MoundState.bared);
      // Dig the dune: a spade will not bite it.
      actFacing(game, earth, 'seal_street', crownOf('m_agora'), west);
      expect(game.ruins.stateOf('m_agora'), MoundState.drifted);
      expect(game.ruins.stateOf('m_gate'), MoundState.bared);
      expect(game.ruins.conserved, isTrue);
    });

    test('aim decides who gets buried — the trade is made with the body', () {
      // The observatory's spoil goes either onto the bump (the vault) or back
      // onto the agora (the terrace ramp). That is the planet's sharpest
      // decision, and it is one flick of the stick.
      final vaultWay = harness(_idealTrio())..entryDoorRevealed = true;
      actFacing(vaultWay, earth, 'roof_walk', crownOf('m_roof'), east);
      expect(vaultWay.ruins.stateOf('m_bump'), MoundState.drifted);
      expect(vaultWay.ruins.stateOf('m_agora'), MoundState.buried);

      final rampWay = harness(_idealTrio())..entryDoorRevealed = true;
      actFacing(rampWay, earth, 'roof_walk', crownOf('m_roof'), west);
      expect(rampWay.ruins.stateOf('m_agora'), MoundState.drifted);
      expect(rampWay.ruins.stateOf('m_bump'), MoundState.buried);
    });

    test('the vault opens by burying it HARDER, and never shuts you in', () {
      final game = harness(_idealTrio())..entryDoorRevealed = true;
      final under = game.layout.rooms['undercity']!;
      final crack = under.doors.firstWhere(
        (d) => d.targetRoomId == 'sunken_house',
      );
      expect(game.isDoorHidden(under, crack), isTrue);

      // Baring the bump shows tiles and nothing else.
      actFacing(game, earth, 'roof_walk', crownOf('m_bump'), west);
      expect(game.ruins.stateOf('m_bump'), MoundState.bared);
      expect(game.isDoorHidden(under, crack), isTrue);

      // Heap it instead, and the party wall gives below.
      final g2 = harness(_idealTrio())..entryDoorRevealed = true;
      actFacing(g2, earth, 'roof_walk', crownOf('m_roof'), east);
      expect(g2.ruins.stateOf('m_bump'), MoundState.drifted);
      expect(g2.isDoorHidden(under, crack), isFalse);

      // And the way back out is never blocked, whatever the bump does next.
      final house = g2.layout.rooms['sunken_house']!;
      final out = house.doors.single;
      g2.ruins.levelCity();
      expect(g2.isDoorHidden(house, out), isFalse);
      expect(g2.isDoorLocked(house, out), isFalse);
    });

    test('the levelling wind takes two touches, and Air of any family does '
        'it', () {
      // The valve may never depend on a family: a party without the ideal trio
      // still has to be able to undo itself.
      final game = harness([
        _member(0, 'Dust', 'pip'),
        _member(1, 'Air', 'kin'),
        _member(2, 'Earth', 'let'),
      ])..entryDoorRevealed = true;
      actFacing(game, earth, 'ashen_gate', crownOf('m_gate'), east);
      expect(game.ruins.isLevelled, isFalse);

      final vane = game.layout.rooms['ashen_gate']!.ruins!.windVane!;
      act(game, dust, 'ashen_gate', vane);
      expect(game.ruins.armedVaneRoom, isNull, reason: 'only Air turns it');

      act(game, air, 'ashen_gate', vane);
      expect(game.ruins.armedVaneRoom, 'ashen_gate');
      expect(game.ruins.isLevelled, isFalse, reason: 'one touch only winds it');

      act(game, air, 'ashen_gate', vane);
      expect(game.ruins.isLevelled, isTrue);
      expect(game.ruins.levellings, 1);
      expect(game.ruins.conserved, isTrue);
    });

    test('there is a vane in every street room and at the tower foot', () {
      // The valve's whole job is to be reachable from anywhere: the search
      // rests on it, so its placement is pinned here rather than trusted.
      const streets = [
        'ashen_gate',
        'seal_street',
        'roof_walk',
        'high_terrace',
        'sand_court',
        'windcatch',
      ];
      for (final id in streets) {
        expect(
          layout.rooms[id]!.ruins?.windVane,
          isNotNull,
          reason: '$id has no vane — the valve is unreachable from it',
        );
      }
    });
  });

  group('Star 1 — THE OBSERVATORY', () {
    test('the rings will not turn while the roof is on', () {
      final game = harness(_idealTrio());
      final room = game.layout.rooms['observatory']!;
      act(game, air, 'observatory', room.ruins!.armillary!);
      expect(game.hasStar(1), isFalse, reason: 'this room has no sky yet');
    });

    test('the roof is the bridge: taking it banks the star and deletes the '
        'street to the court', () {
      final earned = <int>[];
      final game = harness(_idealTrio(), onStar: earned.add)
        ..entryDoorRevealed = true;
      final walk = game.layout.rooms['roof_walk']!;
      final bridge = walk.doors.firstWhere(
        (d) => d.targetRoomId == 'sand_court',
      );
      final down = walk.doors.firstWhere(
        (d) => d.targetRoomId == 'observatory',
      );
      expect(game.isDoorLocked(walk, bridge), isFalse);
      expect(game.isDoorHidden(walk, down), isTrue);

      actFacing(game, earth, 'roof_walk', crownOf('m_roof'), east);
      expect(game.isDoorLocked(walk, bridge), isTrue, reason: 'the bridge WAS '
          'the roof');
      expect(game.isDoorHidden(walk, down), isFalse);

      final obs = game.layout.rooms['observatory']!;
      act(game, air, 'observatory', obs.ruins!.armillary!);
      expect(earned, contains(1));
      expect(game.hasStar(1), isTrue);
    });

    test('the armillary is a HARD gate: no Dust hand, no other family', () {
      final stamped = <String>[];
      final game = harness([
        _member(0, 'Dust', 'mask'),
        _member(1, 'Air', 'pip'), // wrong family on purpose
        _member(2, 'Earth', 'horn'),
      ], onCloud: stamped.add)..entryDoorRevealed = true;
      actFacing(game, earth, 'roof_walk', crownOf('m_roof'), east);
      final obs = game.layout.rooms['observatory']!;

      // Dust cannot turn it at all.
      act(game, dust, 'observatory', obs.ruins!.armillary!);
      expect(game.hasStar(1), isFalse);

      // An Air PIP is refused — and the refusal stamps the chip (§4).
      act(game, air, 'observatory', obs.ruins!.armillary!);
      expect(game.hasStar(1), isFalse);
      expect(stamped, contains('gate:air_wing'));
    });

    test('the roofless span really has no floor under it', () {
      final obs = layout.rooms['observatory']!;
      final rings = obs.ruins!.armillary!;
      expect(obs.gaps, isNotEmpty);
      // The island itself is solid, and it is ringed by void on all four
      // sides — walking to it is geometrically impossible.
      expect(obs.gaps.any((g) => g.rect.contains(rings)), isFalse);
      for (final probe in [
        rings + const Offset(0, -140),
        rings + const Offset(0, 140),
        rings + const Offset(-140, 0),
        rings + const Offset(140, 0),
      ]) {
        expect(
          obs.gaps.any((g) => g.rect.contains(probe)),
          isTrue,
          reason: 'the moat must close all the way round $probe',
        );
      }
    });
  });

  group('the rite and the guardian', () {
    test('the glass refuses until both stars are banked, then turns', () {
      final game = harness(_idealTrio());
      final court = game.layout.rooms['sand_court']!;
      act(game, dust, 'sand_court', court.ruins!.glassCourt!);
      expect(game.conduitEnergy['B'] ?? 0, 0);

      game.earnStar(0);
      game.earnStar(1);
      act(game, dust, 'sand_court', court.ruins!.glassCourt!);
      expect(game.conduitEnergy['B'], double.infinity);
    });

    test('conduit A is the Earth+HORN gate and stamps its own chip', () {
      final stamped = <String>[];
      final game = harness([
        _member(0, 'Dust', 'mask'),
        _member(1, 'Air', 'wing'),
        _member(2, 'Earth', 'pip'), // wrong family
      ], onCloud: stamped.add);
      final court = game.layout.rooms['sand_court']!;
      game.earnStar(0);
      game.earnStar(1);
      act(
        game,
        earth,
        'sand_court',
        court.conduits.firstWhere((c) => c.id == 'A').position,
      );
      expect(game.conduitEnergy['A'] ?? 0, 0);
      expect(stamped, contains('gate:earth_horn'));
    });

    test('Ashdjinn keeps its lull shut while the cut is drifted over', () {
      final game = harness(_idealTrio());
      final hollow = game.layout.rooms['ashdjinn_hollow']!;
      game.currentRoomId = 'ashdjinn_hollow';
      game.guardianAwake = true;
      game.guardianVulnerable = true;
      game.ruins.buryHollow();
      game.update(1 / 60);
      expect(game.guardianVulnerable, isFalse);
      expect(game.ruins.conserved, isTrue);

      act(game, earth, 'ashdjinn_hollow', hollow.ruins!.hollowCut!);
      expect(game.ruins.hollowOpen, isTrue);
      expect(game.ruins.conserved, isTrue);
    });

    test('the storm re-buries your work — and the ledger still balances', () {
      final game = harness(_idealTrio())..entryDoorRevealed = true;
      actFacing(game, earth, 'ashen_gate', crownOf('m_gate'), east);
      expect(game.ruins.stateOf('m_gate'), MoundState.bared);
      expect(game.ruins.stateOf('m_agora'), MoundState.drifted);

      final undone = game.ruins.undoOneDig();
      expect(undone, ('m_gate', 'm_agora'));
      expect(game.ruins.stateOf('m_gate'), MoundState.buried);
      expect(game.ruins.stateOf('m_agora'), MoundState.buried);
      expect(game.ruins.conserved, isTrue);
      // …and with nothing left to shovel back it declines cleanly.
      expect(game.ruins.undoOneDig(), isNull);
      expect(game.ruins.conserved, isTrue);
    });
  });

  group('the Lost Maxim — NOTHING PERISHES', () {
    test('conservation itself is what makes it hard', () {
      // A print shows only while its mound is bared, and #bared == #drifted,
      // so with five mounds you can never have more than two open at once —
      // four prints cannot be swept without paying at least one sirocco.
      final printed = kDustMounds.where((m) => m.footprintPos != null).length;
      expect(printed, greaterThan(2));
      final r = RuinsOfTime();
      var mostOpen = 0;
      // Every arrangement two digs can produce.
      for (final a in kDustMounds) {
        for (final an in a.neighbours) {
          for (final b in kDustMounds) {
            for (final bn in b.neighbours) {
              r.reset();
              r.dig(a.id, an);
              r.dig(b.id, bn);
              expect(r.conserved, isTrue);
              final open = kDustMounds
                  .where((m) => r.stateOf(m.id) == MoundState.bared)
                  .length;
              if (open > mostOpen) mostOpen = open;
            }
          }
        }
      }
      expect(
        mostOpen,
        lessThan(printed),
        reason: 'the ledger caps how much of the city can be open at once',
      );
    });

    test('a print is swept by Air, and only while its ground is open', () {
      final game = harness(_idealTrio())..entryDoorRevealed = true;
      final print = dustMoundById('m_gate')!.footprintPos!;
      // Buried ground: nothing to see.
      act(game, air, 'ashen_gate', print);
      expect(game.ruins.sweptPrints, isEmpty);

      actFacing(game, earth, 'ashen_gate', crownOf('m_gate'), east);
      act(game, earth, 'ashen_gate', print);
      expect(game.ruins.sweptPrints, isEmpty, reason: 'a spade is not a broom');
      act(game, air, 'ashen_gate', print);
      expect(game.ruins.sweptPrints, contains('m_gate'));
      expect(game.ruins.conserved, isTrue);
    });
  });
}
