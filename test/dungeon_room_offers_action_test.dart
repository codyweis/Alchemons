// A room you can work is a room with a button in it.
//
// `roomOffersAction` gates the whole action pad, and it read `DungeonRoom`
// data only. Several planets do not keep their interactables there:
//
//   Lava's production line is ONE global object indexed by room id;
//   Dust's mounds are a const table indexed by room id;
//   Water's moon glint is computed from the tide, not authored;
//   Earth's open palm is a bare `const Offset` inside a method.
//
// Every one of those rooms reported "nothing here", so the pad never appeared
// and the room could not be worked at all — four of Lava's seven among them.
//
// It never showed up in a test because `activateAbility()` does not consult
// this: the gate belongs to the HUD, so only a human holding the phone hits
// it. That is exactly why this file asserts on the getter directly.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dust.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _m(String e, String f) => CosmicPartyMember(
  instanceId: '$e$f',
  baseId: 'b',
  displayName: '$e $f',
  imagePath: null,
  element: e,
  family: f,
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
  for (final m in party) {
    g.creatures.add(DungeonCreature(member: m));
  }
  g.onGameResize(Vector2(412, 915));
  return g;
}

bool _offersIn(PlanetDungeonGame g, String roomId) {
  g.currentRoomId = roomId;
  final at = g.currentRoom.bounds.center;
  for (final c in g.creatures) {
    c
      ..position = at
      ..lastSafe = at;
  }
  return g.roomOffersAction;
}

void main() {
  test('Water: the reflection court can be worked', () {
    // It holds the Frozen Moon and NOTHING else — no authored furniture at
    // all — so the pad never appeared and the secret was unreachable, exactly
    // as Air's hub was.
    final g = _game('Water');
    expect(_offersIn(g, 'reflection_court'), isTrue);
  });

  test('Earth: the palm hollow can be worked', () {
    // The open fossil hand is a `const Offset` in a method. The room data
    // knows nothing about it.
    final g = _game('Earth');
    expect(_offersIn(g, 'palm_hollow'), isTrue);
  });

  test('Lava: every room the production line reaches can be worked', () {
    // Four of seven were dead: the line is one object, indexed by room.
    final g = _game('Lava');
    for (final id in const [
      'tap_head',
      'switch_yard',
      'chill_house',
      'stamp_mill',
      'mold_floor',
      'slag_reliquary',
    ]) {
      expect(_offersIn(g, id), isTrue, reason: id);
    }
  });

  test('Dust: every room with a mound in it can be worked', () {
    final g = _game('Dust');
    for (final room in kPlanetDungeonLayouts['Dust']!.rooms.values) {
      if (dustMoundsIn(room.id).isEmpty) continue;
      expect(_offersIn(g, room.id), isTrue, reason: room.id);
    }
  });

  test('Lightning: the hub can throw its trunk breakers', () {
    // The four breakers ring the hub dynamo and are the planet's signature
    // verb — the zero-sum switch that powers one wing and darkens the rest.
    // They live on the LAYOUT, not the room, so `hasVerbs` could never see
    // them: the hub had no action pad, the run starts with every star wing
    // dark, and there was no way to light one. Lightning was unfinishable on
    // a phone and finishable in every test, because the tests call
    // `activateAbility()` straight past the gate.
    final g = _game('Lightning');
    final layout = kPlanetDungeonLayouts['Lightning']!;
    expect(layout.dynamoTrunks, isNotEmpty);
    expect(_offersIn(g, layout.dynamoRoomId!), isTrue);
  });

  test('and a corridor still has no button', () {
    // The other half of the rule: a dead control in the best spot on the pad
    // teaches that pressing does nothing, so this must not become "always".
    final g = _game('Water');
    expect(
      _offersIn(g, 'moon_hall'),
      isFalse,
      reason: 'the reading room is read with the HINT button, not worked',
    );
  });
}
