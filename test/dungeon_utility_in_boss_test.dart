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
}
