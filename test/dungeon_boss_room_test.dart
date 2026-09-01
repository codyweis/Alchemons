// No verb button in a boss room.
//
// Raids already dropped the UTILITY control, for a reason that applies just
// as well to a planet's guardian: there is nothing to solve in the chamber,
// so the button spends the best spot on the pad answering every press with a
// shrug. This pins WHEN it goes, which is the part that is easy to get wrong
// — too eager and a puzzle room loses its verb, too shy and it hangs around
// through the fight.

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
    g.creatures.add(DungeonCreature(member: m)..position = at..lastSafe = at);
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
    expect(
      g.inGuardianFight,
      isFalse,
      reason: 'an empty roost is just a room',
    );
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
}
