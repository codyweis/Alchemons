// Fire's scriptorium: four corners, then the soot speaks.
//
// The mural used to reveal itself the moment anyone read the room. It is soot
// on a dark wall in a windowless scriptorium, so now the room has to be lit
// first — four corner torches, any Fire hand, and the fourth one brings up the
// first station the soot kept.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _m(String element, String family) => CosmicPartyMember(
  instanceId: '$element$family',
  baseId: 'b',
  displayName: '$element $family',
  imagePath: '',
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

PlanetDungeonGame _game(List<CosmicPartyMember> party) {
  final game = PlanetDungeonGame(
    element: 'Fire',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  game.currentRoomId = 'scriptorium';
  for (final m in party) {
    game.creatures.add(
      DungeonCreature(member: m)..position = const Offset(320, 260),
    );
  }
  return game;
}

/// Walk [index] of the party to [at] and use its action there.
void act(PlanetDungeonGame game, int index, Offset at) {
  game.setActive(index);
  for (final c in game.creatures) {
    c
      ..position = at
      ..lastSafe = at;
  }
  game.activateAbility();
}

void main() {
  final room = kPlanetDungeonLayouts['Fire']!.rooms['scriptorium']!;

  test('the scriptorium authors four torches, one per corner', () {
    expect(room.muralTorches.length, 4);
    final b = room.bounds;
    final corners = {
      for (final t in room.muralTorches)
        '${t.dx < b.center.dx ? 'L' : 'R'}${t.dy < b.center.dy ? 'T' : 'B'}',
    };
    expect(corners, {
      'LT',
      'RT',
      'LB',
      'RB',
    }, reason: 'one torch in each corner, not four along one wall');
  });

  test('no other room has torches', () {
    // The feature belongs to the mural; a stray list elsewhere would light a
    // room that has nothing to reveal.
    for (final r in kPlanetDungeonLayouts['Fire']!.rooms.values) {
      if (r.id == 'scriptorium') continue;
      expect(r.muralTorches, isEmpty, reason: r.id);
    }
  });

  test('a Fire hand lights a corner; the mural stays dark until all four', () {
    final game = _game([_m('Fire', 'mask')]);
    for (var i = 0; i < 3; i++) {
      act(game, 0, room.muralTorches[i]);
      expect(game.litMuralTorches.length, i + 1);
      expect(game.muralLit(room), isFalse, reason: 'only ${i + 1} lit');
      expect(game.choirRevealTier, -1, reason: 'nothing shows yet');
    }
    act(game, 0, room.muralTorches[3]);
    expect(game.muralLit(room), isTrue);
    expect(
      game.choirRevealTier,
      greaterThanOrEqualTo(0),
      reason: 'the fourth corner brings up the first station',
    );
  });

  test('a non-Fire hand is refused, and the torch stays cold', () {
    final game = _game([_m('Air', 'wing')]);
    act(game, 0, room.muralTorches[0]);
    expect(game.litMuralTorches, isEmpty);
    game.askForRoomHint();
    expect(game.hintText, contains('Fire'));
  });

  test('reading the room in the dark says so instead of revealing', () {
    final game = _game([_m('Fire', 'mask')]);
    game.askForRoomHint();
    expect(game.choirRevealTier, -1, reason: 'a dark mural cannot be read');
    game.askForRoomHint();
    expect(game.hintText, contains('dark'));
  });

  test('reading it lit still deepens the reading past the first station', () {
    final game = _game([_m('Fire', 'mask')]);
    for (final t in room.muralTorches) {
      act(game, 0, t);
    }
    final fromLight = game.choirRevealTier;
    game.askForRoomHint();
    expect(
      game.choirRevealTier,
      greaterThanOrEqualTo(fromLight),
      reason: 'insight still adds to what the light gave',
    );
  });

  test('light does not survive a restart, but knowledge does', () {
    final game = _game([_m('Fire', 'mask')]);
    for (final t in room.muralTorches) {
      act(game, 0, t);
    }
    game.askForRoomHint();
    final known = game.choirRevealTier;
    expect(known, greaterThanOrEqualTo(0));

    // debugResetDungeon runs the same puzzle-state reset a death does.
    game.debugResetDungeon();
    expect(game.litMuralTorches, isEmpty, reason: 'the torches burn out');
    expect(
      game.choirRevealTier,
      known,
      reason: 'what you already read stays read',
    );
  });

  test('relighting an already-lit torch does not consume the action', () {
    // A lit torch is not an obstacle — the action should fall through to the
    // creature's own verb rather than being swallowed.
    final game = _game([_m('Fire', 'mask')]);
    act(game, 0, room.muralTorches[0]);
    expect(game.litMuralTorches.length, 1);
    act(game, 0, room.muralTorches[0]);
    expect(game.litMuralTorches.length, 1);
  });
}
