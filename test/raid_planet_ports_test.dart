// EACH RAID FIGHTS BY ITS PLANET'S RULE.
//
// A raid guardian used to play the same shared lull clock everywhere: the
// generated arena carried none of the things its dungeon fight reads, so its
// planet's rule found nothing and was switched off. The arena now carries
// them, and the dungeon's own code runs on them (docs/plans/raid_threat_plan.md,
// Phase 4): Frowyrm only opens while its pillar stands, Bogdrya while the
// floor is hard, Ashdjinn while the cut is clear, Wraithord while its chime
// rings, Magmara when a ring head beaches it, and the Roc reels when a bolt
// climbs the rods into it.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_crystal.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_lava.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_poison.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

import 'guardian_rule_harness.dart';

CosmicPartyMember _member(int slot, String element, String family) =>
    CosmicPartyMember(
      instanceId: 'r$slot',
      baseId: 'b$slot',
      displayName: '$element $family',
      element: element,
      family: family,
      level: 10,
      statSpeed: 3,
      statIntelligence: 3,
      statStrength: 3,
      statBeauty: 3,
      slotIndex: slot,
      staminaBars: 9,
      staminaMax: 9,
    );

/// A raid on [element] with the guardian landed. Slot 0 fights; slot 1 is
/// [key] ('Element/family'), the Alchemon that answers the planet's rule.
PlanetDungeonGame _raid(String element, String key) {
  final members = [
    _member(0, 'Fire', 'horn'),
    _member(1, key.split('/')[0], key.split('/')[1]),
    _member(2, 'Air', 'wing'),
    _member(3, 'Water', 'kin'),
    _member(4, 'Earth', 'let'),
  ];
  final g = PlanetDungeonGame(
    element: element,
    party: members,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    raid: const RaidConfig(level: 1),
    onRaidCleared: () async {},
    layoutOverride: buildRaidArenaLayout(element),
  );
  g.onGameResize(Vector2(412, 915));
  g.currentRoomId = g.layout.entranceRoomId;
  final spawn = g.layout.entranceSpawn;
  for (var i = 0; i < members.length; i++) {
    final at = spawn + Offset((i - 2) * 50.0, 0);
    g.creatures.add(
      DungeonCreature(member: members[i])
        ..position = at
        ..lastSafe = at,
    );
    g.combatCompanions.add(g.debugCreateCombatCompanion(members[i], at));
  }
  for (var i = 0; i < 60 * 4 && _boss(g) == null; i++) {
    g.update(1 / 60);
  }
  expect(_boss(g), isNotNull);
  return g;
}

dynamic _boss(PlanetDungeonGame g) =>
    g.combatEnemies.where((e) => e.isElite).firstOrNull;

/// Runs [seconds] with everyone kept alive, slot 0 fighting from outside the
/// aura and nobody pressing the utility button. Returns how many times the
/// guardian opened.
int _leaveIt(PlanetDungeonGame g, double seconds) {
  var opened = 0;
  var was = false; // a window already open counts
  for (var i = 0; i < seconds * 60; i++) {
    for (final c in g.combatCompanions) {
      c.currentHp = c.maxHp;
    }
    for (final c in g.creatures) {
      c.hp = c.maxHp;
    }
    final b = _boss(g);
    if (b != null && g.activeIndex == 0) {
      final stand = b.position + const Offset(0, 130);
      g.creatures[0]
        ..position = stand
        ..lastSafe = stand;
    }
    g.update(1 / 60);
    if (g.guardianVulnerable && !was) opened++;
    was = g.guardianVulnerable;
  }
  return opened;
}

/// Slot [slot] stands at [at] and presses the utility button, once a frame,
/// until the guardian opens or [seconds] pass. Returns whether it opened.
bool _answer(PlanetDungeonGame g, int slot, Offset at, {double seconds = 8}) {
  g.setActive(slot);
  for (var i = 0; i < seconds * 60; i++) {
    for (final c in g.combatCompanions) {
      c.currentHp = c.maxHp;
    }
    for (final c in g.creatures) {
      c.hp = c.maxHp;
    }
    g.creatures[slot]
      ..position = at
      ..lastSafe = at;
    g.activateAbility();
    g.update(1 / 60);
    if (g.guardianVulnerable) return true;
  }
  return false;
}

/// Plays Blightfang's loop until it opens or [seconds] pass.
bool _brewUntilOpen(PlanetDungeonGame g, {double seconds = 10}) {
  for (var i = 0; i < seconds * 60; i++) {
    for (final c in g.combatCompanions) {
      c.currentHp = c.maxHp;
    }
    for (final c in g.creatures) {
      c.hp = c.maxHp;
    }
    blightfangStep(g, 1, 2);
    g.update(1 / 60);
    if (g.guardianVulnerable) return true;
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Frowyrm opens only while the hoarfrost pillar stands', () {
    test('left alone, it stays shut', () {
      final g = _raid('Ice', 'Ice/pip');
      expect(g.hoarfrostWhole, isFalse);
      expect(_leaveIt(g, 20), 0);
    });

    test('an Ice Alchemon raises the pillar, and it opens', () {
      final g = _raid('Ice', 'Ice/pip');
      expect(_answer(g, 1, g.currentRoom.rime!.hoarfrost!), isTrue);
      expect(g.hoarfrostWhole, isTrue);
    });

    test('nothing else can raise it', () {
      final g = _raid('Ice', 'Fire/pip');
      expect(_answer(g, 1, g.currentRoom.rime!.hoarfrost!), isFalse);
    });
  });

  group('Bogdrya opens only while the floor is hard', () {
    test('left alone, it stays shut', () {
      final g = _raid('Mud', 'Mud/pip');
      expect(_leaveIt(g, 20), 0);
    });

    test('a Mud Alchemon hardens the anchor, and it opens', () {
      final g = _raid('Mud', 'Mud/pip');
      expect(_answer(g, 1, g.currentRoom.fen!.anchor!), isTrue);
    });

    test('nothing else can harden it', () {
      final g = _raid('Mud', 'Water/pip');
      expect(_answer(g, 1, g.currentRoom.fen!.anchor!), isFalse);
    });
  });

  group('Ashdjinn opens only while the cut is clear', () {
    test('the cut starts clear; once the storm buries it, it stays shut', () {
      final g = _raid('Dust', 'Dust/pip');
      expect(g.ruins.hollowOpen, isTrue);
      // The first window is free, then the storm fills the cut in.
      expect(_leaveIt(g, 8), 1);
      expect(g.ruins.hollowOpen, isFalse);
      expect(_leaveIt(g, 20), 0);
    });

    test('Dust or Earth digs it out, and it opens again', () {
      for (final key in const ['Dust/pip', 'Earth/pip']) {
        final g = _raid('Dust', key);
        _leaveIt(g, 8);
        expect(
          _answer(g, 1, g.currentRoom.ruins!.hollowCut!),
          isTrue,
          reason: key,
        );
      }
    });
  });

  group('Wraithord opens only when its chime rings', () {
    test('left alone, it stays shut', () {
      final g = _raid('Spirit', 'Blood/pip');
      expect(_leaveIt(g, 20), 0);
    });

    test('a Blood Pip rings the warm chime, and it opens', () {
      final g = _raid('Spirit', 'Blood/pip');
      _leaveIt(g, 6); // its first attack warms the chime
      expect(_answer(g, 1, g.currentRoom.funeral!.chime!), isTrue);
    });

    test('no other Alchemon can ring it', () {
      for (final key in const ['Blood/horn', 'Spirit/pip']) {
        final g = _raid('Spirit', key);
        _leaveIt(g, 6);
        expect(
          _answer(g, 1, g.currentRoom.funeral!.chime!),
          isFalse,
          reason: key,
        );
      }
    });
  });

  group('Magmara rides the heart ring until a head beaches it', () {
    Offset nearestHead(PlanetDungeonGame g) => kLavaHeartHeads.reduce(
      (a, b) =>
          (a - _boss(g).position).distance < (b - _boss(g).position).distance
          ? a
          : b,
    );

    test('left alone, it never opens', () {
      final g = _raid('Lava', 'Lava/pip');
      expect(_leaveIt(g, 20), 0);
    });

    test('a ring head dropped as it passes beaches it', () {
      final g = _raid('Lava', 'Fire/pip'); // any Alchemon can drop a head
      var opened = false;
      for (var i = 0; i < 30 && !opened; i++) {
        opened = _answer(g, 1, nearestHead(g), seconds: 1);
      }
      expect(opened, isTrue);
    });

    test('it cannot be held beached: the beach runs out', () {
      final g = _raid('Lava', 'Fire/pip');
      var opened = false;
      for (var i = 0; i < 30 && !opened; i++) {
        opened = _answer(g, 1, nearestHead(g), seconds: 1);
      }
      expect(opened, isTrue);
      // Keep pressing at the head the whole time: the beach still ends.
      final head = nearestHead(g);
      var shut = false;
      for (var i = 0; i < 60 * 6 && !shut; i++) {
        g.creatures[1]
          ..position = head
          ..lastSafe = head;
        g.activateAbility();
        g.update(1 / 60);
        shut = !g.guardianVulnerable;
      }
      expect(shut, isTrue);
    });
  });

  group('Prismalith opens only over the gap in the floor', () {
    // The plate beside the gap that is nearest the heart plate.
    Offset nextPlate(PlanetDungeonGame g) {
      final floor = g.currentRoom.prism!.choir!;
      int steps(int c) =>
          (c % 3 - kKeepHeartCell % 3).abs() +
          (c ~/ 3 - kKeepHeartCell ~/ 3).abs();
      final cell = keepNeighbours(
        g.prism.choirHollow,
      ).reduce((a, b) => steps(a) <= steps(b) ? a : b);
      return floor.plateCentre(cell);
    }

    test('left alone, it stays shut', () {
      final g = _raid('Crystal', 'Crystal/pip');
      expect(g.prism.choirHollow, isNot(kKeepHeartCell));
      expect(_leaveIt(g, 20), 0);
    });

    test('a Crystal Alchemon slides the gap under it, and it opens', () {
      final g = _raid('Crystal', 'Crystal/pip');
      var opened = false;
      for (var i = 0; i < 6 && !opened; i++) {
        opened = _answer(g, 1, nextPlate(g), seconds: 2);
      }
      expect(g.prism.choirHollow, kKeepHeartCell);
      expect(opened, isTrue);
    });

    test('nothing else can slide the floor', () {
      final g = _raid('Crystal', 'Fire/pip');
      final start = g.prism.choirHollow;
      _answer(g, 1, nextPlate(g), seconds: 2);
      expect(g.prism.choirHollow, start);
    });
  });

  group('Botanica opens only while its arena is right', () {
    // Water, Spirit and Crystal in one ring answer every climate it sets.
    PlanetDungeonGame plantRaid() {
      final g = _raid('Plant', 'Water/pip');
      g.creatures[2] = DungeonCreature(member: _member(2, 'Spirit', 'wing'));
      g.combatCompanions[2] = g.debugCreateCombatCompanion(
        g.creatures[2].member,
        g.creatures[1].position,
      );
      g.creatures[4] = DungeonCreature(member: _member(4, 'Crystal', 'let'));
      g.combatCompanions[4] = g.debugCreateCombatCompanion(
        g.creatures[4].member,
        g.creatures[1].position,
      );
      return g;
    }

    test('left alone, it stays shut', () {
      final g = plantRaid();
      expect(_leaveIt(g, 20), 0);
    });

    test('Water, Spirit and Crystal in a ring put it right, and it opens', () {
      final g = plantRaid();
      final ring = g.currentRoom.grove!.arenaRings.first;
      for (final (i, off) in const [(2, Offset(18, 0)), (4, Offset(-18, 0))]) {
        g.creatures[i]
          ..position = ring + off
          ..lastSafe = ring + off;
      }
      expect(_answer(g, 1, ring, seconds: 10), isTrue);
    });

    // Botanica opens on its own clock, which runs after the shared one the
    // rage aura read, so the aura burned whoever stepped in to strike for
    // half of every window (2026-10-07).
    test('nobody burns striking it in its window', () {
      final g = plantRaid();
      final ring = g.currentRoom.grove!.arenaRings.first;
      for (final (i, off) in const [(2, Offset(18, 0)), (4, Offset(-18, 0))]) {
        g.creatures[i]
          ..position = ring + off
          ..lastSafe = ring + off;
      }
      expect(_answer(g, 1, ring, seconds: 10), isTrue);
      g.setActive(0);
      final striker = g.creatures[0];
      var frames = 0;
      while (g.guardianVulnerable && frames < 60 * 10) {
        for (final c in g.combatCompanions) {
          c.invincibleTimer = 999; // only the aura writes health directly
        }
        final at = (_boss(g).position as Offset) + const Offset(0, 60);
        striker
          ..position = at
          ..lastSafe = at
          ..hp = striker.maxHp;
        g.update(1 / 60);
        if (!g.guardianVulnerable) break;
        expect(striker.hp, striker.maxHp, reason: 'burned ${frames}f in');
        frames++;
      }
      // The whole window, which outlasts the shared clock's 3 s lull.
      expect(frames, greaterThan(60 * 4));
    });
  });

  group('Blightfang opens only to a brew it is not wearing', () {
    PlanetDungeonGame poisonRaid() {
      final g = _raid('Poison', 'Poison/pip');
      g.creatures[2] = DungeonCreature(member: _member(2, 'Plant', 'wing'));
      g.combatCompanions[2] = g.debugCreateCombatCompanion(
        g.creatures[2].member,
        g.creatures[1].position,
      );
      return g;
    }

    test('left alone, it stays shut', () {
      final g = poisonRaid();
      expect(_leaveIt(g, 20), 0);
    });

    test('a brew from its pot opens it', () {
      final g = poisonRaid();
      expect(_brewUntilOpen(g), isTrue);
      expect(g.monastery.lastBrew, kPureVial.id);
    });

    test('it will not take the same brew twice running', () {
      final g = poisonRaid();
      expect(_brewUntilOpen(g), isTrue);
      _leaveIt(g, 5); // the window closes
      // Brew the Pure Vial again (Poison twice) and offer it: refused.
      final pot = g.currentRoom.apothecary!.cistern;
      g.setActive(1);
      for (var give = 0; give < 2; give++) {
        g.creatures[1]
          ..position = pot
          ..lastSafe = pot;
        g.activateAbility();
        g.update(1 / 60);
      }
      expect(g.monastery.carriedPotion, kPureVial.id);
      final boss = _boss(g).position as Offset;
      g.creatures[1]
        ..position = boss + const Offset(0, 60)
        ..lastSafe = boss + const Offset(0, 60);
      g.activateAbility();
      g.update(1 / 60);
      expect(g.guardianVulnerable, isFalse);
      expect(g.monastery.carriedPotion, kPureVial.id);
    });

    test('its pool is split across its three shells', () {
      final poison = poisonRaid();
      final ice = _raid('Ice', 'Ice/pip');
      expect(
        (_boss(poison).maxHp as double) * kPlagueBars,
        closeTo(_boss(ice).maxHp as double, 1),
      );
    });
  });

  group('Raikuma opens only when its trunk is grounded', () {
    test('left alone, it stays shut while it drinks', () {
      final g = _raid('Lightning', 'Lightning/pip');
      expect(_leaveIt(g, 20), 0);
    });

    test('a Lightning Alchemon grounds the spike, and it opens', () {
      final g = _raid('Lightning', 'Lightning/pip');
      expect(_answer(g, 1, g.currentRoom.coreBreaker!), isTrue);
    });

    test('nothing else can ground it', () {
      final g = _raid('Lightning', 'Fire/pip');
      expect(_answer(g, 1, g.currentRoom.coreBreaker!), isFalse);
    });

    test('the trunk surges back before the spike can bite again', () {
      final g = _raid('Lightning', 'Lightning/pip');
      final spike = g.currentRoom.coreBreaker!;
      expect(_answer(g, 1, spike), isTrue);
      // Keep pressing at the spike through the window and after it.
      var shutFor = 0.0;
      var reopened = false;
      for (var i = 0; i < 60 * 10 && !reopened; i++) {
        g.creatures[1]
          ..position = spike
          ..lastSafe = spike;
        g.activateAbility();
        final was = g.guardianVulnerable;
        g.update(1 / 60);
        if (!g.guardianVulnerable) shutFor += 1 / 60;
        reopened = !was && g.guardianVulnerable;
      }
      expect(reopened, isTrue);
      // Shut for about the surge, not one frame.
      expect(shutFor, greaterThan(2.0));
    });
  });

  group('Solarin opens only to a body in its shadow, two squares off', () {
    test('left alone, it stays shut', () {
      final g = _raid('Light', 'Light/pip');
      expect(_leaveIt(g, 20), 0);
    });

    test('in the pillar\'s shadow two squares off, it opens', () {
      final g = _raid('Light', 'Fire/pip'); // no element needed
      var opened = false;
      for (var i = 0; i < 40 && !opened; i++) {
        opened = _answer(g, 1, solarinShadow(g), seconds: 0.5);
      }
      expect(opened, isTrue);
    });

    test('five bodies on three names: the one you play always has one', () {
      final g = _raid('Light', 'Light/pip');
      for (var slot = 0; slot < g.creatures.length; slot++) {
        g.setActive(slot);
        g.update(1 / 60); // must not throw: its name is read every frame
        expect(g.activeIndex, slot);
      }
    });
  });

  group('the Roc reels when a bolt climbs the rods into it', () {
    test('the storm cell fires in the raid', () {
      final g = _raid('Air', 'Air/pip');
      final room = g.currentRoom;
      g.stormStrikeTimer = room.stormOrbit!.strikeInterval - 0.01;
      g.update(1 / 60);
      expect(g.stormStrikeTimer, lessThan(0.1));
    });

    test('a ranked staircase leads the bolt into the bird', () {
      final g = _raid('Air', 'Air/pip');
      final room = g.currentRoom;
      final bird = _boss(g).position as Offset;
      final rods = room.stormRods;
      // Find a cell position and a run of four rods round the ring, either
      // way, that climbs 0, 1, 2, 3 into the bird.
      Map<String, int>? staircase;
      double? atAngle;
      for (var a = 0; a < 64 && staircase == null; a++) {
        g.stormCellAngle = a * 2 * 3.14159265 / 64;
        final cell = g.stormCellPosition(room)!;
        for (var foot = 0; foot < rods.length && staircase == null; foot++) {
          for (final dir in const [1, -1]) {
            final heights = {for (final r in rods) r.id: kStormRodMaxHeight};
            for (var k = 0; k <= kStormRodMaxHeight; k++) {
              heights[rods[(foot + dir * k) % rods.length].id] = k;
            }
            final led = g.stormLeaderFrom(
              cell,
              room,
              heights: heights,
              guardianAt: bird,
            );
            if (led.isNotEmpty && led.last == 'guardian') {
              staircase = heights;
              atAngle = g.stormCellAngle;
              break;
            }
          }
        }
      }
      expect(staircase, isNotNull, reason: 'the ring can be climbed');
      g.rodHeight
        ..clear()
        ..addAll(staircase!);
      g.stormCellAngle = atAngle!;
      g.stormStrikeTimer = room.stormOrbit!.strikeInterval - 0.01;
      g.update(1 / 60);
      expect(g.lastLeaderPath.last, 'guardian');
      expect(g.guardianVulnerable, isTrue);
    });
  });
}
