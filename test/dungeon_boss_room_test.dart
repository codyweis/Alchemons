// What the pad carries in a boss room.
//
// Dropping the UTILITY control for every guardian fight was too broad a rule
// and it cost a real fight: Air's Star 3 IS its altar, its conduits are worked
// with the utility, and hiding the button walled the boss off behind a control
// the player no longer had. So the rule is now about the ROOM, not the fight —
// a bare arena still loses the button, a chamber with furniture in it keeps
// every verb that furniture offers.
//
// Both halves are pinned here, because both failure modes are silent: a dead
// button teaches that pressing does nothing, and a missing one is a wall.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _m(String element, String family) => CosmicPartyMember(
  instanceId: '$element$family',
  baseId: 'b',
  displayName: '$element $family',
  imagePath: null,
  element: element,
  family: family,
  level: 10,
  statSpeed: 4,
  statIntelligence: 4,
  statStrength: 4,
  statBeauty: 4,
  slotIndex: -1,
  staminaBars: 9,
  staminaMax: 9,
);

PlanetDungeonGame _game(String element) {
  final els = kCosmicPlanetEntry[element]!;
  final fams = kDungeonIdealFamilies[element]!;
  final party = [
    for (var i = 0; i < els.length; i++) _m(els[i], fams[i].toLowerCase()),
  ];
  final g = PlanetDungeonGame(
    element: element,
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = g.layout.entranceRoomId;
  final at = g.currentRoom.bounds.center;
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = at
        ..lastSafe = at,
    );
  }
  g.onGameResize(Vector2(412, 915));
  return g;
}

String _lairOf(PlanetDungeonGame g) =>
    g.layout.rooms.values.firstWhere((r) => r.guardian != null).id;

void main() {
  test('a puzzle room keeps its verb', () {
    final g = _game('Fire');
    expect(g.inGuardianFight, isFalse, reason: 'the entrance is not a lair');
    g.currentRoomId = 'cloister';
    expect(g.inGuardianFight, isFalse, reason: 'the garth needs its verb');
  });

  test('the lair alone is not the fight — the guardian has to be up', () {
    final g = _game('Fire');
    g.currentRoomId = _lairOf(g);
    expect(g.inGuardianFight, isFalse, reason: 'an empty roost is just a room');
  });

  test('it goes while the guardian is up', () {
    final g = _game('Fire');
    g.currentRoomId = _lairOf(g);
    g.guardianAwake = true;
    expect(g.inGuardianFight, isTrue);
  });

  test('and comes back once the guardian is down', () {
    // The star banks on the kill, and after that the chamber is just a room
    // again — with a relic in it, and a way out.
    final g = _game('Fire');
    g.currentRoomId = _lairOf(g);
    g.guardianAwake = true;
    g.earnStar(g.currentRoom.guardian!.starIndex);
    expect(g.inGuardianFight, isFalse);
  });

  test('every dungeon can answer the question', () {
    // The getter reads currentRoom.guardian, so a layout with no lair at all
    // must not throw or claim a fight.
    for (final element in kPlanetDungeonLayouts.keys) {
      final g = _game(element);
      expect(g.inGuardianFight, isFalse, reason: '$element at its entrance');
    }
  });

  group('you do not walk out of a fight you started', () {
    /// Wake the guardian and let it land.
    PlanetDungeonGame engaged() {
      final g = _game('Fire');
      g.currentRoomId = _lairOf(g);
      g.guardianAwake = true;
      g.altarOpen = true;
      var guard = 0;
      while (g.combatEnemies.isEmpty && guard++ < 1200) {
        g.update(1 / 60);
      }
      expect(g.combatEnemies, isNotEmpty, reason: 'the guardian has landed');
      return g;
    }

    bool anyDoorOpen(PlanetDungeonGame g, DungeonRoom room) =>
        room.doors.any((d) => !g.isDoorLocked(room, d));

    test('the lair seals while the guardian stands', () {
      final g = engaged();
      final lair = g.currentRoom;
      expect(lair.doors, isNotEmpty, reason: 'there is a way out to seal');
      expect(anyDoorOpen(g, lair), isFalse);
    });

    test('and opens again the moment it falls', () {
      final g = engaged();
      final lair = g.currentRoom;
      for (final e in g.combatEnemies) {
        e.hp = 0;
      }
      // The kill banks the star, which is what unseals it for good.
      g.earnStar(lair.guardian!.starIndex);
      expect(anyDoorOpen(g, lair), isTrue);
    });

    test('it seals the LAIR and nothing else', () {
      // A seal that leaked into other rooms would strand a player mid-run
      // with no way back to the gate.
      final g = engaged();
      for (final room in g.layout.rooms.values) {
        if (room.guardian != null) continue;
        if (room.doors.isEmpty) continue;
        expect(
          anyDoorOpen(g, room),
          isTrue,
          reason: '${room.id} must stay passable',
        );
      }
    });

    test('an unwoken lair is not sealed', () {
      // Walking in and back out before rousing it is allowed — the way IN is
      // what gates the encounter, and it has its own lock.
      final g = _game('Fire');
      g.currentRoomId = _lairOf(g);
      final lair = g.currentRoom;
      expect(anyDoorOpen(g, lair), isTrue);
    });
  });

  group('the utility follows the room, not the fight', () {
    test('a puzzle room always has it', () {
      final g = _game('Fire');
      expect(g.utilityAvailable, isTrue);
      g.currentRoomId = 'cloister';
      expect(g.utilityAvailable, isTrue);
    });

    test('a lair with furniture in it keeps the verb mid-fight', () {
      // Air's guardian shares its chamber with the storm rods, and ranking
      // them is the fight — they are worked with the utility.
      final g = _game('Air');
      g.currentRoomId = _lairOf(g);
      expect(
        g.currentRoom.stormRods,
        isNotEmpty,
        reason: 'the Air lair holds the rods — this test is about that',
      );
      g.guardianAwake = true;
      expect(g.inGuardianFight, isTrue);
      expect(
        g.utilityAvailable,
        isTrue,
        reason:
            'the rods are worked with the utility; without the button '
            'the boss cannot be fought at all',
      );
    });

    test('a bare arena drops it', () {
      // The original complaint: nothing to press, in the best spot on the pad.
      for (final element in kPlanetDungeonLayouts.keys) {
        final g = _game(element);
        g.currentRoomId = _lairOf(g);
        if (g.currentRoom.hasVerbsBesidesGuardian) continue;
        g.guardianAwake = true;
        expect(
          g.utilityAvailable,
          isFalse,
          reason: '$element\'s lair holds nothing but the guardian',
        );
      }
    });

    test('the guardian alone never counts as furniture', () {
      // The whole distinction rests on this: `hasVerbs` counts the boss (it
      // IS a verb), and the fight has to ask the question without it.
      for (final layout in kPlanetDungeonLayouts.values) {
        for (final room in layout.rooms.values) {
          if (room.guardian == null) continue;
          if (room.hasVerbsBesidesGuardian) continue;
          expect(
            room.hasVerbs,
            isTrue,
            reason: 'a lair still has a verb — striking the thing in it',
          );
        }
      }
    });

    test('and it comes back when the guardian goes down', () {
      final g = _game('Fire');
      g.currentRoomId = _lairOf(g);
      g.guardianAwake = true;
      g.earnStar(g.currentRoom.guardian!.starIndex);
      expect(g.utilityAvailable, isTrue);
    });
  });
}
