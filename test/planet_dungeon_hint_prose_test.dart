// WHAT THE HINT BUTTON SAYS, READ BACK.
//
// Objective lines are written once and then never read again by anything —
// not by another test, not by the analyzer, and not by the author after the
// planet has been reworked twice. Poison's still described a triage that had
// been deleted: a still standing cold, a phial drawn, physic for three wards.
//
// So this reads every room's line on every POLISHED planet and holds it to
// the two rules that can be checked mechanically: no em dashes, and no words
// from a vocabulary the planet no longer uses.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// The planets that have been through a polish pass. Unpolished ones are
/// still being written and their copy is not final.
const _polished = [
  'Fire',
  'Air',
  'Water',
  'Earth',
  'Lightning',
  'Steam',
  'Lava',
  'Poison',
];

PlanetDungeonGame _game(String element) {
  final trio = kCosmicPlanetEntry[element]!;
  final party = [
    for (var i = 0; i < trio.length; i++)
      CosmicPartyMember(
        instanceId: 'i$i',
        baseId: 'b$i',
        displayName: trio[i],
        element: trio[i],
        family: 'mask',
        level: 10,
        statSpeed: 3,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: i,
        staminaBars: 3,
        staminaMax: 3,
      ),
  ];
  final g = PlanetDungeonGame(
    element: element,
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.onGameResize(Vector2(900, 600));
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = const Offset(100, 100)
        ..lastSafe = const Offset(100, 100),
    );
  }
  return g;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hint prose on the polished planets', () {
    for (final element in _polished) {
      test('$element: no em dashes in any objective line', () {
        final g = _game(element);
        for (final roomId in g.layout.rooms.keys) {
          g.currentRoomId = roomId;
          final line = g.roomObjectiveLine(roomId);
          if (line == null) continue;
          expect(
            line.contains('—'),
            isFalse,
            reason: '$element/$roomId: $line',
          );
          expect(
            line.contains('--'),
            isFalse,
            reason: '$element/$roomId: $line',
          );
        }
      });
    }

    test('Poison says nothing about the triage it no longer has', () {
      final g = _game('Poison');
      const gone = ['phial', 'physic for three', 'leaded', 'draught'];
      for (final roomId in g.layout.rooms.keys) {
        g.currentRoomId = roomId;
        final line = g.roomObjectiveLine(roomId)?.toLowerCase();
        if (line == null) continue;
        for (final dead in gone) {
          expect(line.contains(dead), isFalse, reason: '$roomId: $line');
        }
      }
    });
  });
}
