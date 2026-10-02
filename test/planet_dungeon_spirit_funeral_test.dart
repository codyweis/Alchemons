// REQUIA — THE UNFINISHED FUNERAL, walked by the engine.
//
// docs/dungeons.md, "SPIRIT — THE UNFINISHED FUNERAL: BUILD SPEC". One loop —
// watch, crystallize, fit, pulse — taught at the bell and used everywhere
// after it. These pin the loop's promises (every craft works, crystals are
// never lost or duplicated, clues never change anything), each star's
// deduction, the rite, the chime, the vault, the maxim and persistence.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_spirit.dart';
import 'package:flutter/material.dart';
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

/// The ideal trio: Spiritmask · Bloodpip · Dustwing.
List<CosmicPartyMember> idealTrio() => [
  _member(0, 'Spirit', 'mask'),
  _member(1, 'Blood', 'pip'),
  _member(2, 'Dust', 'wing'),
];

const int spirit = 0, blood = 1, dust = 2;

PlanetDungeonGame harness(
  List<CosmicPartyMember> party, {
  int stars = 0,
  void Function(int)? onStar,
  void Function(String)? onCloud,
  Set<String> clouds = const {},
}) {
  final game = PlanetDungeonGame(
    element: 'Spirit',
    party: party,
    initialStarMask: stars,
    onStarEarned: onStar ?? (_) {},
    onCloudDiscovered: onCloud,
    onPlayerDown: () => fail('the scripted run must never wipe'),
    onChanged: () {},
  );
  game.starMask = stars;
  game.discoveredClouds.addAll(clouds);
  game.debugResetPuzzleState();
  game.entryDoorRevealed = true;
  game.currentRoomId = game.layout.entranceRoomId;
  for (final m in party) {
    final c = DungeonCreature(member: m)
      ..position = game.layout.entranceSpawn
      ..lastSafe = game.layout.entranceSpawn;
    game.creatures.add(c);
    final stats = deriveAlchemonCombatStats(member: m);
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
        attackRange: stats.attackRange,
        specialAbilityRange: stats.specialAbilityRange,
        tethered: false,
        invincibleTimer: 0,
      ),
    );
  }
  return game;
}

final DungeonLayout layout = kPlanetDungeonLayouts['Spirit']!;
FuneralRoom fr(String room) => layout.rooms[room]!.funeral!;

/// The stone each of the ideal trio's slots kneels at: its own mourner's.
List<int> rightStones() => [
  for (final m in idealTrio())
    kMournerAt.entries.firstWhere((e) => e.value == m.element).key,
];

/// Stand everyone on [pos] in [room] and press the verb with [idx].
void act(PlanetDungeonGame game, int idx, String room, Offset pos) {
  game.currentRoomId = room;
  game.funeral.lastRoom = room;
  game.setActive(idx);
  for (final c in game.creatures) {
    c
      ..position = pos
      ..lastSafe = pos;
  }
  game.activateAbility();
}

/// Press with [idx] standing on [pos], the others left where they are.
void actAlone(PlanetDungeonGame game, int idx, String room, Offset pos) {
  game.currentRoomId = room;
  game.funeral.lastRoom = room;
  game.setActive(idx);
  game.creatures[idx]
    ..position = pos
    ..lastSafe = pos;
  game.activateAbility();
}

void run(PlanetDungeonGame game, double seconds) {
  for (var t = 0.0; t < seconds; t += 1 / 30) {
    game.update(1 / 30);
  }
}

/// Crystallize [room]'s urn, carry it to the socket and fit it.
void craftAndFit(PlanetDungeonGame game, String room) {
  final f = fr(room);
  act(game, dust, room, f.urn!);
  act(game, spirit, room, f.urn!); // pick it up
  act(game, spirit, room, f.socket!.at);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the planet is registered whole', () {
    test('party, ideal families, and one hard gate on Star 3', () {
      expect(kCosmicPlanetEntry['Spirit'], ['Spirit', 'Blood', 'Dust']);
      expect(kDungeonIdealFamilies['Spirit'], ['Mask', 'Pip', 'Wing']);
      expect(layout.familyGates, hasLength(1));
      final gate = layout.familyGateFor('vigil_chime')!;
      expect(gate.element, 'Blood');
      expect(gate.family, 'Pip');
      expect(layout.rooms['wraithord_vigil']!.guardian!.starIndex, 2);
    });

    test('the riddle names each slot\'s element', () {
      final els = kCosmicPlanetEntry['Spirit']!;
      for (var i = 0; i < els.length; i++) {
        expect(layout.riddle[i].toLowerCase(), contains(els[i].toLowerCase()));
      }
    });

    test('Dust + Spirit make Crystal, every time', () {
      for (var i = 0; i < 40; i++) {
        expect(funeralPairReady(['Dust', 'Spirit']), isTrue);
        expect(funeralPairReady(['Spirit', 'Dust', 'Blood']), isTrue);
      }
      expect(funeralPairReady(['Dust', 'Blood']), isFalse);
      expect(funeralPairReady(['Spirit']), isFalse);
    });
  });

  group('the entry rite', () {
    test('only Dust shifts the drift, and only in the present', () {
      final game = harness(idealTrio());
      game.entryDoorRevealed = false;
      final at = fr('memorial').drift!;
      act(game, spirit, 'memorial', at);
      expect(game.entryDoorRevealed, isFalse);
      game.funeral.run.world = FuneralWorld.ghost;
      act(game, dust, 'memorial', at);
      expect(game.entryDoorRevealed, isFalse);
      game.funeral.run.world = FuneralWorld.living;
      act(game, dust, 'memorial', at);
      expect(game.entryDoorRevealed, isTrue);
    });
  });

  group('the loop — crystallize, carry, fit', () {
    test('the right pair makes the crystal on the first press, every time', () {
      for (var i = 0; i < 20; i++) {
        final game = harness(idealTrio());
        act(game, dust, 'bell_court', fr('bell_court').urn!);
        expect(game.funeral.run.crystals, contains('urn_keeper'));
      }
    });

    test('a lone body, or the wrong pair, stirs nothing', () {
      final game = harness(idealTrio());
      final urn = fr('bell_court').urn!;
      final far = urn + const Offset(0, 300);
      game.currentRoomId = 'bell_court';
      for (final c in game.creatures) {
        c.position = far;
      }
      actAlone(game, dust, 'bell_court', urn);
      expect(game.funeral.run.crystals, isEmpty);
      actAlone(game, blood, 'bell_court', urn);
      expect(game.funeral.run.crystals, isEmpty);
      act(game, blood, 'bell_court', urn); // all three here, Blood presses
      expect(game.funeral.run.crystals, isEmpty);
    });

    test('nothing moves in the past', () {
      final game = harness(idealTrio());
      game.funeral.run.world = FuneralWorld.ghost;
      act(game, dust, 'bell_court', fr('bell_court').urn!);
      expect(game.funeral.run.crystals, isEmpty);
    });

    test('carried across a creature switch; returned to its urn on leaving '
        'the room; never duplicated', () {
      final game = harness(idealTrio());
      final f = fr('bell_court');
      act(game, dust, 'bell_court', f.urn!);
      act(game, spirit, 'bell_court', f.urn!);
      expect(game.funeral.run.held, 'urn_keeper');
      game.setActive(blood);
      expect(game.funeral.run.held, 'urn_keeper');
      // Pressing the urn again cannot make a second one.
      act(game, dust, 'bell_court', f.urn!);
      expect(game.funeral.run.crystals, {'urn_keeper'});
      // Leave the room: it goes back to its urn, still made.
      game.currentRoomId = 'memorial';
      game.update(1 / 30);
      expect(game.funeral.run.held, isNull);
      expect(game.funeral.run.crystalAtUrn('urn_keeper'), isTrue);
    });

    test('a memory fits only its own socket', () {
      final game = harness(idealTrio(), stars: 0x1);
      final f = fr('bearers_court');
      // The keeper's crystal is already fitted (Star 1 banked); make the
      // bearers' and try it in the bell court's socket.
      act(game, dust, 'bearers_court', f.urn!);
      act(game, spirit, 'bearers_court', f.urn!);
      game.funeral.lastRoom = 'bell_court';
      game.currentRoomId = 'bell_court';
      game.funeral.run.fitted.remove('sk_treadle');
      game.setActive(spirit);
      for (final c in game.creatures) {
        c.position = fr('bell_court').socket!.at;
      }
      game.activateAbility();
      expect(game.funeral.run.fitted, isNot(contains('sk_treadle')));
    });

    test('readiness and hints never change anything', () {
      final game = harness(idealTrio());
      game.currentRoomId = 'bell_court';
      for (final c in game.creatures) {
        c.position = fr('bell_court').urn!;
      }
      for (var i = 0; i < 30; i++) {
        game.update(1 / 30);
        game.puzzlePreview;
        game.debugObjectiveHint('bell_court');
      }
      expect(game.funeral.run.crystals, isEmpty);
      expect(game.funeral.run.held, isNull);
    });
  });

  group('STAR 1 — the bell keeper', () {
    test('Blood pulses the fitted crystal: treadle, lever, bell, gate', () {
      final stars = <int>[];
      final game = harness(idealTrio(), onStar: stars.add);
      final room = layout.rooms['bell_court']!;
      final gate = room.doors.firstWhere(
        (d) => d.targetRoomId == 'bearers_court',
      );
      expect(game.isDoorLocked(room, gate), isTrue);
      craftAndFit(game, 'bell_court');
      expect(game.funeral.run.fitted, contains('sk_treadle'));
      act(game, dust, 'bell_court', fr('bell_court').socket!.at);
      expect(game.funeral.bellT, -1, reason: 'only Blood pulses it');
      act(game, blood, 'bell_court', fr('bell_court').socket!.at);
      expect(game.funeral.bellT, greaterThanOrEqualTo(0));
      run(game, 3.5);
      expect(stars, contains(0));
      expect(game.funeral.run.bellRung, isTrue);
      expect(game.isDoorLocked(room, gate), isFalse);
    });
  });

  group('STAR 2 — the bearers\' walk', () {
    /// Apply the presses in [mask] (bit f = press flag f) to a fresh court.
    BearerFlags pressed(int mask) {
      final flags = BearerFlags();
      for (var f = 0; f < 9; f++) {
        if (mask >> f & 1 == 1) flags.press(f);
      }
      return flags;
    }

    final routeMask = kBearerRoute.fold(0, (m, f) => m | 1 << f);

    test('copying the route can never lay it: an off-route press is needed',
        () {
      // Exhaustively: every combination of route-flag presses leaves the
      // route unlaid, because both of its pairs are tied by a beam.
      for (var mask = 0; mask < 1 << 9; mask++) {
        if (mask & ~routeMask != 0) continue;
        expect(pressed(mask).routeClear, isFalse, reason: 'mask $mask');
      }
      // And the obvious copy — press each tipped route flag once — fails.
      final start = BearerFlags();
      final copy = BearerFlags();
      for (final f in kBearerRoute) {
        if (!start.isLevel(f)) copy.press(f);
      }
      expect(copy.routeClear, isFalse);
    });

    test('three presses is the fewest, and every shortest one leaves the '
        'route', () {
      final best = bearerSolveFrom(kBearerStartLevel)!;
      expect(best, hasLength(3));
      var shortest = 0;
      for (var mask = 0; mask < 1 << 9; mask++) {
        final n = mask.toRadixString(2).replaceAll('0', '').length;
        if (!pressed(mask).routeClear) continue;
        expect(n, greaterThanOrEqualTo(3));
        if (n == 3) {
          shortest++;
          expect(mask & ~routeMask, isNot(0), reason: 'needs a flag off it');
        }
      }
      expect(shortest, lessThanOrEqualTo(2));
    });

    test('the start does not already show the answer', () {
      final flags = BearerFlags();
      expect(flags.routeClear, isFalse);
      expect(flags.tippedOnRoute, greaterThanOrEqualTo(2));
    });

    test('a failed walk stops at the doorstep, not at the wrong flag', () {
      final game = harness(idealTrio(), stars: 0x1);
      final f = fr('bearers_court');
      craftAndFit(game, 'bearers_court');
      final stops = <double?>{};
      for (final mask in [0, 1 << 0, 1 << 5, 1 << 0 | 1 << 3]) {
        game.funeral.run.flags.reset();
        for (var g = 0; g < 9; g++) {
          if (mask >> g & 1 == 1) game.funeral.run.flags.press(g);
        }
        if (game.funeral.run.flags.routeClear) continue;
        act(game, blood, 'bearers_court', f.socket!.at);
        stops.add(game.funeral.walkStop);
        run(game, 4);
      }
      expect(stops, hasLength(1), reason: 'every miss looks the same');
    });

    test('an unlaid route stops the echo; the laid route finishes the walk', () {
      final stars = <int>[];
      final game = harness(idealTrio(), stars: 0x1, onStar: stars.add);
      final f = fr('bearers_court');
      final room = layout.rooms['bearers_court']!;
      final door = room.doors.firstWhere(
        (d) => d.targetRoomId == 'vigil_chapel',
      );
      craftAndFit(game, 'bearers_court');
      act(game, blood, 'bearers_court', f.socket!.at);
      expect(game.funeral.walkStop, isNotNull);
      run(game, 12);
      expect(stars, isNot(contains(1)));
      expect(game.funeral.walkDist, -1, reason: 'back to the doorstep');
      expect(game.isDoorLocked(room, door), isTrue);
      // Lay the route: the three presses the beams demand.
      for (final flag in bearerSolveFrom(game.funeral.run.flags.level)!) {
        act(game, dust, 'bearers_court', f.flagCentre(flag));
      }
      expect(game.funeral.run.flags.routeClear, isTrue);
      act(game, blood, 'bearers_court', f.socket!.at);
      expect(game.funeral.walkStop, isNull);
      run(game, 12);
      expect(stars, contains(1));
      expect(game.isDoorLocked(room, door), isFalse);
    });

    test('flags answer any body, and only in the present', () {
      final game = harness(idealTrio(), stars: 0x1);
      final f = fr('bearers_court');
      final before = {...game.funeral.run.flags.level};
      game.funeral.run.world = FuneralWorld.ghost;
      act(game, spirit, 'bearers_court', f.flagCentre(3));
      expect(game.funeral.run.flags.level, before);
      game.funeral.run.world = FuneralWorld.living;
      act(game, blood, 'bearers_court', f.flagCentre(3));
      expect(game.funeral.run.flags.level, isNot(before));
    });
  });

  group('THE RITE — the three mourners', () {
    PlanetDungeonGame chapel() {
      final game = harness(idealTrio(), stars: 0x3);
      craftAndFit(game, 'vigil_chapel');
      return game;
    }

    void kneel(PlanetDungeonGame game, List<int> stones) {
      final f = fr('vigil_chapel');
      for (var i = 0; i < 3; i++) {
        game.creatures[i]
          ..position = f.stones[stones[i]]
          ..lastSafe = f.stones[stones[i]];
      }
    }

    test('the right stones with the wrong bodies: nothing lifts', () {
      final game = chapel();
      // Every arrangement of the party over the mourners' three stones but
      // the one that matches each mourner's element.
      final stones = kMournerStones.toList();
      final right = rightStones();
      for (final perm in [
        [stones[0], stones[1], stones[2]],
        [stones[0], stones[2], stones[1]],
        [stones[1], stones[0], stones[2]],
        [stones[1], stones[2], stones[0]],
        [stones[2], stones[0], stones[1]],
        [stones[2], stones[1], stones[0]],
      ]) {
        final isRight = List.generate(3, (i) => perm[i] == right[i]).every((b) => b);
        if (isRight) continue;
        game.funeral.riteT = -1;
        kneel(game, perm);
        game.setActive(blood);
        game.activateAbility();
        expect(game.funeral.riteT, -1, reason: 'perm $perm lifted');
      }
    });

    test('a miss says nothing about which place was right', () {
      final game = chapel();
      final right = rightStones();
      // Two of three right, and none right: the same answer.
      kneel(game, [right[0], right[1], 4]);
      game.setActive(blood);
      final hintA = () {
        game.activateAbility();
        return game.hintText;
      }();
      kneel(game, [1, right[1], 4]);
      game.activateAbility();
      expect(game.hintText, hintA);
    });

    test('wrong stones: nothing lifts', () {
      final game = chapel();
      final f = fr('vigil_chapel');
      kneel(game, [0, 1, 2]);
      game.setActive(blood);
      game.activateAbility();
      run(game, 4);
      expect(game.guardianAwake, isFalse);
      expect(game.funeral.run.riteDone, isFalse);
      expect(f.stones, hasLength(5));
    });

    test('the mourners\' three: the bier is carried and Wraithord wakes', () {
      final game = chapel();
      kneel(game, rightStones());
      game.setActive(blood);
      game.activateAbility();
      expect(game.funeral.riteT, greaterThanOrEqualTo(0));
      run(game, 4);
      expect(game.funeral.run.riteDone, isTrue);
      expect(game.guardianAwake, isTrue);
    });

    test('without the mourners\' crystal the stones do nothing', () {
      final game = harness(idealTrio(), stars: 0x3);
      kneel(game, rightStones());
      game.currentRoomId = 'vigil_chapel';
      game.funeral.lastRoom = 'vigil_chapel';
      game.setActive(blood);
      game.activateAbility();
      expect(game.funeral.riteT, -1);
    });

    test('idle bodies hold on a kneeling stone', () {
      final game = chapel();
      kneel(game, rightStones());
      final before = [for (final c in game.creatures) c.position];
      game.setActive(spirit);
      run(game, 2);
      for (var i = 1; i < 3; i++) {
        expect(
          (game.creatures[i].position - before[i]).distance,
          lessThan(8),
        );
      }
    });
  });

  group('STAR 3 — the vigil chime', () {
    PlanetDungeonGame arena(List<CosmicPartyMember> party) {
      final game = harness(party, stars: 0x3);
      game.currentRoomId = 'wraithord_vigil';
      game.funeral.lastRoom = 'wraithord_vigil';
      game.guardianAwake = true;
      // The arrival owns the room first; the vigil's clock waits for it.
      run(game, PlanetDungeonGame.kGuardianArrivalSeconds + 0.2);
      game.funeral
        ..attackT = 0
        ..chimeWarm = false;
      return game;
    }

    test('a cold chime refuses; a finished attack warms it', () {
      final game = arena(idealTrio());
      final at = fr('wraithord_vigil').chime!;
      actAlone(game, blood, 'wraithord_vigil', at);
      expect(game.funeral.chimeHeld, isFalse);
      game.funeral.attackT = 4.99;
      game.update(0.02);
      expect(game.funeral.chimeWarm, isTrue);
      expect(game.guardianVulnerable, isFalse);
      actAlone(game, blood, 'wraithord_vigil', at);
      expect(game.funeral.chimeHeld, isTrue);
      game.update(0.02);
      expect(game.guardianVulnerable, isTrue);
    });

    test('one pulse, one window — never a refresh — then it cools', () {
      final game = arena(idealTrio());
      final at = fr('wraithord_vigil').chime!;
      game.funeral.chimeWarm = true;
      actAlone(game, blood, 'wraithord_vigil', at);
      game.update(0.5);
      final left = game.funeral.chimeWindow;
      actAlone(game, blood, 'wraithord_vigil', at);
      expect(game.funeral.chimeWindow, left);
      for (var i = 0; i < 40; i++) {
        game.update(0.1);
      }
      expect(game.funeral.chimeHeld, isFalse);
      expect(game.funeral.chimeWarm, isFalse);
      expect(game.guardianVulnerable, isFalse);
    });

    test('the chime is the Blood Pip\'s: any other hand stamps the gate', () {
      final party = [
        _member(0, 'Spirit', 'mask'),
        _member(1, 'Blood', 'horn'),
        _member(2, 'Dust', 'wing'),
      ];
      final clouds = <String>[];
      final game = harness(party, stars: 0x3, onCloud: clouds.add);
      game.currentRoomId = 'wraithord_vigil';
      game.funeral.lastRoom = 'wraithord_vigil';
      game.guardianAwake = true;
      game.funeral.chimeWarm = true;
      actAlone(game, blood, 'wraithord_vigil', fr('wraithord_vigil').chime!);
      expect(game.funeral.chimeHeld, isFalse);
      expect(clouds, contains(layout.familyGateFor('vigil_chime')!.discoveryId));
    });
  });

  group('the vault and the maxim', () {
    test('Dust clears the keeper\'s niche, and only then is the cache there',
        () {
      final game = harness(idealTrio());
      expect(game.funeralVaultLiveForTest, isFalse);
      act(game, blood, 'bell_court', fr('bell_court').niche!.translate(40, 0));
      expect(game.funeralVaultLiveForTest, isFalse);
      act(game, dust, 'bell_court', fr('bell_court').niche!.translate(40, 0));
      expect(game.funeralVaultLiveForTest, isTrue);
    });

    /// Place the three creatures by slot, then press with [who].
    void place(PlanetDungeonGame g, List<Offset> at, int who) {
      g.currentRoomId = 'quiet_alcove';
      g.funeral.lastRoom = 'quiet_alcove';
      for (var i = 0; i < 3; i++) {
        g.creatures[i]
          ..position = at[i]
          ..lastSafe = at[i];
      }
      g.setActive(who);
      g.activateAbility();
    }

    // Spirit at the memorial stone is also kneeling at the west kneeler.
    final k = kAlcoveKneelers;
    final atStone = Offset.lerp(fr('quiet_alcove').memorialStone!, k[3], 0.5)!;

    test('three bodies can never hold six kneelers', () {
      final game = harness(idealTrio());
      place(game, [k[0], k[1], k[2]], blood);
      expect(game.funeral.run.urnFilled, isFalse);
    });

    test('the alcove keeps your past, and only the alcove', () {
      final game = harness(idealTrio());
      // Elsewhere, passing over records nothing.
      act(game, spirit, 'memorial', fr('memorial').memorialStone!);
      expect(game.funeral.run.echoes, isEmpty);
      act(game, spirit, 'memorial', fr('memorial').memorialStone!);
      // In the alcove, passing INTO the past keeps where the party stands.
      place(game, [atStone, k[0], k[1]], spirit);
      expect(game.funeral.run.isGhost, isTrue);
      expect(game.funeral.run.echoes, hasLength(3));
      expect(
        kneelersHeld(k, const [], [
          for (final (p, _) in game.funeral.run.echoes) p,
        ]),
        {0, 1, 3},
      );
      // Coming back to the present keeps them; passing in again replaces.
      place(game, [atStone, k[0], k[1]], spirit);
      expect(game.funeral.run.isGhost, isFalse);
      expect(game.funeral.run.echoes, hasLength(3));
      place(game, [atStone, k[2], k[2]], spirit);
      expect(
        kneelersHeld(k, const [], [
          for (final (p, _) in game.funeral.run.echoes) p,
        ]),
        {2, 3},
      );
    });

    test('THE EMPTY URN: your echoes and you hold all six, and the urn is '
        'yours', () {
      final clouds = <String>[];
      final game = harness(idealTrio(), onCloud: clouds.add);
      final f = fr('quiet_alcove');
      // Record: Spirit at the stone (the west kneeler), Blood and Dust on
      // two more. Pass into the past, then back.
      place(game, [atStone, k[0], k[1]], spirit);
      place(game, [atStone, k[0], k[1]], spirit);
      expect(game.funeral.run.isGhost, isFalse);
      // The pair alone stirs nothing yet: the urn is empty.
      act(game, dust, 'quiet_alcove', f.urn!);
      expect(game.funeral.run.crystals, isEmpty);
      // Now kneel on the other three, and Blood wakes the stones.
      place(game, [k[4], k[5], k[2]], blood);
      expect(game.funeral.run.urnFilled, isTrue);
      craftAndFit(game, 'quiet_alcove');
      expect(game.funeral.run.fitted, contains('sk_name'));
      act(game, blood, 'quiet_alcove', f.socket!.at);
      run(game, 6);
      expect(clouds, contains(kSpiritEmptyUrnEggId));
    });
  });

  group('persistence', () {
    test('a banked star restores its finished scene', () {
      final game = harness(idealTrio(), stars: 0x3);
      final r = game.funeral.run;
      expect(r.bellRung, isTrue);
      expect(r.fitted, containsAll(['sk_treadle', 'sk_doorstep']));
      expect(r.flags.routeClear, isTrue);
      expect(r.bierArrived, isTrue);
      final bell = layout.rooms['bell_court']!;
      expect(
        game.isDoorLocked(
          bell,
          bell.doors.firstWhere((d) => d.targetRoomId == 'bearers_court'),
        ),
        isFalse,
      );
    });

    test('an unbanked run starts clean', () {
      final game = harness(idealTrio());
      final r = game.funeral.run;
      expect(r.crystals, isEmpty);
      expect(r.fitted, isEmpty);
      expect(r.flags.routeClear, isFalse);
    });

    test('passing between worlds is free and draws nothing', () {
      final game = harness(idealTrio());
      for (var i = 0; i < 10; i++) {
        act(game, spirit, 'memorial', fr('memorial').memorialStone!);
      }
      expect(game.funeral.run.passings, 10);
      expect(game.combatEnemies, isEmpty);
    });
  });

  group('the whole descent, walked with the ideal trio', () {
    test('Spiritmask · Bloodpip · Dustwing take all three stars\' puzzles, '
        'the vault and the maxim', () {
      final stars = <int>[];
      final clouds = <String>[];
      final game = harness(idealTrio(), onStar: stars.add, onCloud: clouds.add);
      game.entryDoorRevealed = false;
      act(game, dust, 'memorial', fr('memorial').drift!);
      expect(game.entryDoorRevealed, isTrue);

      // Star 1.
      craftAndFit(game, 'bell_court');
      act(game, blood, 'bell_court', fr('bell_court').socket!.at);
      run(game, 3.5);
      expect(stars, contains(0));
      // The vault.
      act(game, dust, 'bell_court', fr('bell_court').niche!.translate(40, 0));
      game.currentRoomId = 'bell_court';
      for (final c in game.creatures) {
        c.position = layout.rooms['bell_court']!.vaultCache!;
      }
      game.update(1 / 30);
      expect(clouds, contains('cache:spirit_vault'));

      // Star 2.
      final bf = fr('bearers_court');
      craftAndFit(game, 'bearers_court');
      for (final flag in bearerSolveFrom(game.funeral.run.flags.level)!) {
        act(game, dust, 'bearers_court', bf.flagCentre(flag));
      }
      act(game, blood, 'bearers_court', bf.socket!.at);
      run(game, 12);
      expect(stars, contains(1));

      // The rite.
      craftAndFit(game, 'vigil_chapel');
      final cf = fr('vigil_chapel');
      final right = rightStones();
      for (var i = 0; i < 3; i++) {
        game.creatures[i].position = cf.stones[right[i]];
      }
      game.setActive(blood);
      game.activateAbility();
      run(game, 4);
      expect(game.guardianAwake, isTrue);

      // The maxim.
      final af = fr('quiet_alcove');
      final kk = kAlcoveKneelers;
      final stoneK = Offset.lerp(af.memorialStone!, kk[3], 0.5)!;
      void kneelAll(List<Offset> at, int who) {
        game.currentRoomId = 'quiet_alcove';
        game.funeral.lastRoom = 'quiet_alcove';
        for (var i = 0; i < 3; i++) {
          game.creatures[i].position = at[i];
        }
        game.setActive(who);
        game.activateAbility();
      }

      kneelAll([stoneK, kk[0], kk[1]], spirit);
      kneelAll([stoneK, kk[0], kk[1]], spirit);
      kneelAll([kk[4], kk[5], kk[2]], blood);
      craftAndFit(game, 'quiet_alcove');
      act(game, blood, 'quiet_alcove', af.socket!.at);
      run(game, 6);
      expect(clouds, contains(kSpiritEmptyUrnEggId));
    });
  });
}
