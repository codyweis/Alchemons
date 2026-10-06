// FAMILY SIZES IN A DUNGEON — one creature of each family standing in a row
// in a room, at the folded phone's view, so their sizes can be judged
// against the room's 64-unit squares. They follow the same family table as
// survival and space (kCompanionSpeciesScale), scaled so a Kin or a Wing
// stands about one square (kDungeonFamilyBox). With `build/room_audit`
// present it writes DungeonFamilySizes.png.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _families = ['let', 'pip', 'mane', 'mask', 'horn', 'kin', 'wing'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('each family stands its own size, as in survival and space', (tester) async {
    await tester.runAsync(() async {
      final all = [
        for (final c in ((jsonDecode(File('assets/data/alchemons_creatures.json').readAsStringSync())
                as Map<String, dynamic>)['creatures'] as List)
            .cast<Map<String, dynamic>>())
          Creature.fromJson(c),
      ];
      final party = <CosmicPartyMember>[];
      for (final f in _families) {
        final c = all.firstWhere(
          (c) => c.spriteData != null && (c.mutationFamily ?? '').toLowerCase() == f && c.types.first == 'Fire',
          orElse: () => all.firstWhere((c) => c.spriteData != null && (c.mutationFamily ?? '').toLowerCase() == f),
        );
        party.add(debugMemberFromCreature(c));
      }
      final g = PlanetDungeonGame(
        element: 'Fire',
        party: party,
        initialStarMask: 0,
        onStarEarned: (_) {},
        onPlayerDown: () {},
        onChanged: () {},
      );
      g.currentRoomId = g.layout.entranceRoomId;
      g.onGameResize(Vector2(916, 265));
      final at = g.layout.entranceSpawn;
      final heights = <String, double>{};
      for (var i = 0; i < party.length; i++) {
        final pos = at + Offset((i - 3) * 64.0, 0);
        final c = DungeonCreature(member: party[i])
          ..position = pos
          ..lastSafe = pos;
        g.creatures.add(c);
        await g.debugLoadSprite(c);
        final f = c.ticker?.getSprite().srcSize;
        if (f != null) heights[_families[i]] = max(f.x, f.y) * c.spriteScale;
      }
      g.update(1 / 60);
      // Each stands its family's box (times its own visual scale).
      for (final f in _families) {
        final h = heights[f];
        if (h == null) continue;
        final want = kDungeonFamilyBox * kCompanionSpeciesScale[f]!;
        expect(h, closeTo(want, want * .5), reason: '$f stands about $want');
      }
      expect(heights['kin']!, greaterThan(heights['pip']!), reason: 'a Kin is bigger than a Pip');
      if (Directory('build/room_audit').existsSync()) {
        final rec = ui.PictureRecorder();
        g.render(Canvas(rec));
        final img = await rec.endRecording().toImage(916, 265);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('build/room_audit/DungeonFamilySizes.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
  });
}
