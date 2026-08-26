// The room's reading belongs to the room, not to the party.
//
// Insight was the one family verb that dispensed INFORMATION. Gating it behind
// bringing a Mask meant a party without one was not having a harder time —
// they had no route to the knowledge and no way to learn one existed. The HUD
// asks for it now, so these pin that asking works for anybody.

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

/// A game standing at its entrance with its party on the floor. The engine
/// spawns creatures in onLoad, which never runs headlessly, so the harness
/// places them the way every other dungeon test does.
PlanetDungeonGame _game(String element, List<CosmicPartyMember> party) {
  final game = PlanetDungeonGame(
    element: element,
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  game.currentRoomId = game.layout.entranceRoomId;
  for (final m in party) {
    game.creatures.add(
      DungeonCreature(member: m)
        ..position = game.layout.entranceSpawn
        ..lastSafe = game.layout.entranceSpawn,
    );
  }
  return game;
}

void main() {
  group('anyone can ask the room', () {
    test('a party with no Mask still gets a reading', () {
      for (final element in kPlanetDungeonLayouts.keys) {
        final els = kCosmicPlanetEntry[element]!;
        // Deliberately all 'let' — a family that gates nothing and, crucially,
        // is not the insight family anywhere in the game.
        final game = _game(element, [for (final e in els) _m(e, 'let')]);
        expect(
          game.party.any((p) => p.family == 'mask'),
          isFalse,
          reason: '$element: the test party must contain no Mask',
        );
        game.askForRoomHint();
        expect(
          game.hintText,
          isNotNull,
          reason: '$element: asking produced no reading at all',
        );
        expect(game.hintText, isNotEmpty, reason: element);
      }
    });

    test('asking twice is safe and never throws', () {
      final game = _game('Fire', [_m('Fire', 'let')]);
      game.askForRoomHint();
      game.askForRoomHint();
      expect(game.hintText, isNotNull);
    });

    test('asking with no creatures at all is a no-op, not a crash', () {
      // A wipe can leave the run with nothing active while the HUD is still up.
      final game = _game('Fire', const []);
      expect(game.active, isNull);
      expect(game.askForRoomHint, returnsNormally);
    });
  });
}
