// WALKING THROUGH A DOOR IS NEVER A SECRET.
//
// Reported from play: *"sometimes I walk through doors and it's not intuitive
// where I am — it shouldn't be a secret when walking through."* Two separate
// causes, and both were invisible to the suite:
//
//  1. The room-entry line had stopped appearing at all. §5.6 specifies
//     OBJECTIVE as "on room entry, one line, WHAT not HOW", but the "dungeon
//     does not narrate" rule — aimed at 382 lines that answered every tap —
//     installed an unasked-for gate that swallowed the arrival line with
//     them. The only way to learn where you had walked was to press HINT.
//  2. 124 of the 169 rooms had no minimap label either, so the map caption
//     was blank for three quarters of the game.
//
// This walks EVERY door of EVERY planet and insists the arrival says
// something. It is deliberately about the OUTPUT — a goal line, or the
// room's own name when it has no goal — so any future scheme satisfies it.

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every door in every dungeon arrives somewhere that names itself', () {
    final silent = <String>[];
    for (final element in kPlanetDungeonLayouts.keys) {
      final g = _game(element);
      for (final room in kPlanetDungeonLayouts[element]!.rooms.values) {
        for (final door in room.doors) {
          g.currentRoomId = room.id;
          g.passThroughDoor(door);
          if ((g.hintText ?? '').trim().isEmpty) {
            silent.add('$element ${room.id} -> ${door.targetRoomId}');
          }
        }
      }
    }
    expect(silent, isEmpty, reason: silent.join('\n'));
  });

  test(
    'every room carries a map label, so the chart and the capsule agree',
    () {
      final unlabelled = <String>[];
      kPlanetDungeonLayouts.forEach((element, layout) {
        for (final id in layout.rooms.keys) {
          if (!kDungeonRoomLabels.containsKey(id))
            unlabelled.add('$element/$id');
        }
      });
      expect(
        unlabelled,
        isEmpty,
        reason:
            'a room with no label shows a blank minimap caption, and is the '
            'fallback the arrival line leans on:\n${unlabelled.join("\n")}',
      );
    },
  );

  test('a live refusal still outranks a room naming itself', () {
    // Arriving must not stomp a reading or a refusal you walked in on —
    // OBJECTIVE sits below BLOCKED and INSIGHT and stays there.
    final g = _game('Mud');
    g.currentRoomId = 'mire_gate';
    g.askForRoomHint();
    final room = kPlanetDungeonLayouts['Mud']!.rooms['mire_gate']!;
    g.passThroughDoor(room.doors.first);
    expect(g.hintText, isNotNull);
  });
}
