// EVERY ROOM, WHOLE — for the glass-inlay pass (docs/dungeons.md §7.11).
//
// `dungeon_room_render_test.dart` frames every room at 900x600 from its
// centre, which crops the big ones and shows nothing past the middle. This
// sizes the viewport to each room, loads the glow sprites, and draws it once,
// so a planet can be looked at whole before and after it is repainted.
//
// Pick planets with `--dart-define=AUDIT=Air,Water` (default: all polished
// ones). With `build/room_audit` present it writes Whole_<Planet>_<room>.png.
// It asserts only that every room draws something: it is a camera, not a
// judge.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String _pick = String.fromEnvironment('AUDIT');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every room of the chosen planets, whole', (tester) async {
    await tester.runAsync(() async {
      final out = Directory('build/room_audit');
      final planets = _pick.isEmpty
          ? kPolishedDungeons.toList()
          : _pick.split(',').map((s) => s.trim()).toList();
      for (final element in planets) {
        final layout = kPlanetDungeonLayouts[element]!;
        final els = kCosmicPlanetEntry[element] ?? [element, 'Air', 'Fire'];
        for (final id in layout.rooms.keys) {
          final party = [
            for (var i = 0; i < els.length; i++)
              CosmicPartyMember(
                instanceId: 'i$i',
                baseId: 'b$i',
                displayName: els[i],
                element: els[i],
                family: const ['mane', 'mask', 'wing'][i % 3],
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
          await g.debugLoadFx();
          final b = layout.rooms[id]!.bounds;
          g.onGameResize(Vector2(b.width + 60, b.height + 60));
          g.entryDoorRevealed = true;
          g.currentRoomId = id;
          final stand = Offset(b.left + 60, b.bottom - 40);
          for (final m in party) {
            g.creatures.add(
              DungeonCreature(member: m)
                ..position = stand
                ..lastSafe = stand,
            );
          }
          for (var i = 0; i < 24; i++) {
            g.update(1 / 60);
          }
          final rec = ui.PictureRecorder();
          g.render(Canvas(rec));
          final img = await rec.endRecording().toImage(
            g.size.x.round(),
            g.size.y.round(),
          );
          if (out.existsSync()) {
            final png = await img.toByteData(format: ui.ImageByteFormat.png);
            File(
              'build/room_audit/Whole_${element}_$id.png',
            ).writeAsBytesSync(png!.buffer.asUint8List());
          }
          final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
          final bytes = raw!.buffer.asUint8List();
          final seen = <int>{};
          for (var i = 0; i < bytes.length; i += 4 * 61) {
            seen.add(
              bytes[i] >> 4 << 8 | bytes[i + 1] >> 4 << 4 | bytes[i + 2] >> 4,
            );
          }
          expect(
            seen.length,
            greaterThan(8),
            reason: '$element/$id drew nothing',
          );
        }
      }
    });
  });
}
