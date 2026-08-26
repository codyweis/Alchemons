// Asking is not doing.
//
// The HINT button reads the room. It must never CHANGE it: a question that
// quietly advances a puzzle is a trap for anyone who presses it out of
// curiosity, and it makes the button impossible to reason about ("did I just
// spend something?"). Every effect a reading used to have has moved onto a
// world verb — Fire's mural now comes up when the fourth corner torch takes.
//
// This walks all seventeen dungeons and asserts that pressing HINT, twice,
// leaves the run exactly where it was.

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
  statSpeed: 5,
  statIntelligence: 5,
  statStrength: 5,
  statBeauty: 5,
  slotIndex: -1,
  staminaBars: 9,
  staminaMax: 9,
);

PlanetDungeonGame _game(String element, {String? room}) {
  final els = kCosmicPlanetEntry[element]!;
  final fams = kDungeonIdealFamilies[element]!;
  final party = [
    for (var i = 0; i < els.length; i++) _m(els[i], fams[i].toLowerCase()),
  ];
  final game = PlanetDungeonGame(
    element: element,
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  game.currentRoomId = room ?? game.layout.entranceRoomId;
  final at = game.currentRoom.bounds.center;
  for (final m in party) {
    game.creatures.add(
      DungeonCreature(member: m)
        ..position = at
        ..lastSafe = at,
    );
  }
  return game;
}

/// Everything a reading could plausibly have moved.
String _fingerprint(PlanetDungeonGame g) => [
  g.starMask,
  g.discoveredClouds.toList()..sort(),
  g.choirRevealTier,
  g.epitaphStage,
  g.sumpsRead,
  g.canalRevealTier,
  g.litMuralTorches.toList()..sort(),
  g.conduitEnergy.toString(),
  g.entryDoorRevealed,
].join('|');

void main() {
  group('pressing HINT changes nothing, in any dungeon', () {
    test('the run is identical before and after asking', () {
      for (final element in kPlanetDungeonLayouts.keys) {
        final g = _game(element);
        final before = _fingerprint(g);
        g.askForRoomHint();
        g.askForRoomHint();
        expect(
          _fingerprint(g),
          before,
          reason: '$element: asking for a hint moved the run',
        );
      }
    });

    test('asking in every room of every dungeon is still inert', () {
      // Room-specific readings are where the side effects lived, so this has
      // to visit them rather than only the entrance.
      for (final entry in kPlanetDungeonLayouts.entries) {
        for (final roomId in entry.value.rooms.keys) {
          final g = _game(entry.key, room: roomId);
          final before = _fingerprint(g);
          g.askForRoomHint();
          expect(
            _fingerprint(g),
            before,
            reason: '${entry.key}/$roomId: asking moved the run',
          );
        }
      }
    });
  });

  group("Fire's mural comes up from the torches, not from asking", () {
    final room = kPlanetDungeonLayouts['Fire']!.rooms['scriptorium']!;

    test('asking in the dark reveals nothing and lights nothing', () {
      final g = _game('Fire', room: 'scriptorium');
      g.askForRoomHint();
      expect(g.litMuralTorches, isEmpty);
      expect(g.choirRevealTier, -1);
      expect(g.epitaphStage, 0);
    });

    test('the fourth torch does the whole reading, unasked', () {
      final g = _game('Fire', room: 'scriptorium');
      final fire = g.party.indexWhere((p) => p.element == 'Fire');
      for (final t in room.muralTorches) {
        g.setActive(fire);
        for (final c in g.creatures) {
          c
            ..position = t
            ..lastSafe = t;
        }
        g.activateAbility();
      }
      expect(g.muralLit(room), isTrue);
      // Everything the old Mask press did, done by the world instead.
      expect(
        g.choirRevealTier,
        greaterThanOrEqualTo(0),
        reason: 'the soot gives up its stations when the room is lit',
      );
      expect(
        g.epitaphStage,
        1,
        reason: 'the epitaph starts writing on the light, not on a question',
      );
    });
  });
}
