// Every planet's raid through the game's real onLoad, then a few seconds of
// fight and a frame drawn. The other raid tests skip onLoad and wire the
// party by hand, so a planet hook that runs on entry (Dark's Black Sun put
// the squad on its porch, a room the raid arena does not have, and every
// frame after threw) went unseen there.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalog = [
    for (final c
        in ((jsonDecode(
                      File(
                        'assets/data/alchemons_creatures.json',
                      ).readAsStringSync(),
                    )
                    as Map<String, dynamic>)['creatures']
                as List)
            .cast<Map<String, dynamic>>())
      Creature.fromJson(c),
  ];
  Creature pick(String family, String element) {
    bool ofFamily(Creature c) =>
        c.spriteData != null &&
        (c.mutationFamily ?? '').toLowerCase() == family;
    return catalog.firstWhere(
      (c) => ofFamily(c) && c.types.first == element,
      orElse: () => catalog.firstWhere(ofFamily),
    );
  }

  for (final element in kRaidGuardianIds.keys) {
    testWidgets('$element raid loads, fights and draws', (tester) async {
      await tester.runAsync(() async {
        const families = ['horn', 'wing', 'kin', 'mane', 'pip'];
        final game = PlanetDungeonGame(
          element: element,
          party: [
            for (final f in families)
              debugMemberFromCreature(pick(f, element), statTier: 3),
          ],
          initialStarMask: 0,
          onStarEarned: (_) {},
          onPlayerDown: () {},
          onChanged: () {},
          raid: const RaidConfig(level: 1),
          layoutOverride: buildRaidArenaLayout(element),
        );
        game.onGameResize(Vector2(1460, 960));
        await game.onLoad();
        expect(game.currentRoomId, 'raid_arena');
        expect(game.creatures, hasLength(families.length));

        for (var i = 0; i < 180; i++) {
          game.update(1 / 60);
        }
        final recorder = ui.PictureRecorder();
        game.render(Canvas(recorder));
        recorder.endRecording().dispose();
        expect(game.currentRoomId, 'raid_arena');
      });
    });
  }
}
