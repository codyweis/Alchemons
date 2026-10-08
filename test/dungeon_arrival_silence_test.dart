// WALKING THROUGH A DOOR SAYS NOTHING, AND IS STILL NEVER A SECRET.
//
// History: the dungeon once went silent on arrival, a player reported
// *"sometimes I walk through doors and it's not intuitive where I am"*, and
// two fixes went in — every room got a minimap label (124 of 169 had none),
// and the room-entry line came back. Then the author, 2026-10-08: *"the
// popups are annoying when walking into rooms ... only pop them up when we
// request hints."* So the line is held for the HINT button again, and the
// minimap caption alone names where a door put you.
//
// Pinned here: no door speaks the room's own lines (only a consequence of the
// door itself, Ice's chute rides, may speak), HINT always has something to
// say in the room you just entered, and every room has its caption.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_minimap.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanetDungeonGame _game(String element) {
  final els = kCosmicPlanetEntry[element] ?? const ['Fire', 'Water', 'Air'];
  final party = [
    for (var i = 0; i < els.length; i++)
      CosmicPartyMember(
        instanceId: 'i$i',
        baseId: 'b$i',
        displayName: els[i],
        element: els[i],
        family: ['mane', 'pip', 'mask'][i % 3],
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
        ..position = const Offset(200, 300)
        ..lastSafe = const Offset(200, 300),
    );
  }
  return g;
}

/// What a door may still say as you go through it: what the door itself just
/// did to the world (Ice's rides scour a chute and reset the shaft). These
/// are consequences of the route chosen, not the room describing itself.
const _doorConsequences = ['You ride the snow down', 'The rimefall carries'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('no door in any dungeon speaks the room it opens onto', () {
    final spoke = <String>[];
    for (final element in kPlanetDungeonLayouts.keys) {
      final g = _game(element);
      for (final room in kPlanetDungeonLayouts[element]!.rooms.values) {
        for (final door in room.doors) {
          g.currentRoomId = room.id;
          g.hintText = null;
          g.passThroughDoor(door);
          final said = g.hintText;
          if (said != null && !_doorConsequences.any(said.startsWith)) {
            spoke.add('$element ${room.id} -> ${door.targetRoomId}: $said');
          }
        }
      }
    }
    expect(spoke, isEmpty, reason: spoke.join('\n'));
  });

  test('HINT answers in every room a door opens onto '
      '(Blood keeps its rooms to the reading)', () {
    final mute = <String>[];
    for (final element in kPlanetDungeonLayouts.keys) {
      // Blood's rooms never named themselves (the author, 2026-10-06), and a
      // few of its rooms have no reading to give either.
      if (element == 'Blood') continue;
      final g = _game(element);
      for (final room in kPlanetDungeonLayouts[element]!.rooms.values) {
        for (final door in room.doors) {
          g.currentRoomId = room.id;
          g.passThroughDoor(door);
          g.hintText = null;
          g.askForRoomHint();
          if ((g.hintText ?? '').trim().isEmpty) {
            mute.add('$element ${room.id} -> ${door.targetRoomId}');
          }
        }
      }
    }
    expect(mute, isEmpty, reason: mute.join('\n'));
  });

  test("a room's goal is handed over by HINT once, then the reading", () {
    final g = _game('Water');
    g.currentRoomId = 'drowned_court';
    final door = g.currentRoom.doors.firstWhere(
      (d) => d.targetRoomId == 'ghost_gallery',
    );
    g.passThroughDoor(door);
    expect(g.hintText, isNull);
    final goal = g.debugObjectiveHint('ghost_gallery');
    expect(goal, isNotNull);
    g.askForRoomHint();
    expect(g.hintText, goal);
    expect(g.hintChannel, DungeonHintChannel.objective);
    g.askForRoomHint();
    expect(g.hintText, isNot(goal));
    expect(g.hintChannel, DungeonHintChannel.insight);
  });

  test('every room carries a map label, so a doorway is never a secret', () {
    final unlabelled = <String>[];
    kPlanetDungeonLayouts.forEach((element, layout) {
      for (final id in layout.rooms.keys) {
        if (!kDungeonRoomLabels.containsKey(id)) unlabelled.add('$element/$id');
      }
    });
    expect(
      unlabelled,
      isEmpty,
      reason:
          'a room with no label shows a blank minimap caption, and the '
          'caption is the only thing that names a room as you walk in:\n'
          '${unlabelled.join("\n")}',
    );
  });
}
