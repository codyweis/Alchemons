import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Every planet. A room that draws nothing is invisible to a green suite and
// obvious in one picture, and that has been true of every polish pass so far
// — the faults that mattered came out of a screenshot or a device session and
// none of them out of a test that already existed.
//
// `mkdir -p build/room_audit` and run this to get the pictures; CI has no
// such directory and writes none (the Poison precedent — `flutter test`
// passes neither --dart-define nor the environment through to the isolate).
// It also prints an INK RANKING: edge pixels and distinct colours per room.
//
// READ IT AS A SMOKE ALARM, NOT A SCORE. It was originally captioned as an
// "emptiness ranking" with the note that under ~600 is a box, and eight
// parallel art passes duly optimised for it — rooms went from 400 edge
// pixels to eleven thousand, and the player's verdict was that the detail
// "crowds things and makes it hard to know what to do". A metric that
// rewards ink gets you ink.
//
// What the number can tell you is that a room drew almost NOTHING. It cannot
// tell you a room is good, and a falling number is not a regression: Ice's
// orrery floor went from 10,518 to 6,934 by sinking its decorative orbits
// into the floor, and it is better, because the sockets you actually use are
// now the brightest brass in the room.
//
// The standard is hierarchy, not density: THE THINGS YOU CAN ACT ON ARE THE
// LOUDEST THINGS IN THE ROOM, and everything else is texture behind them.

PlanetDungeonGame _game(String element) {
  final els = kCosmicPlanetEntry[element] ?? const ['Fire', 'Water', 'Air'];
  final fams = ['mane', 'pip', 'mask'];
  final party = [
    for (var i = 0; i < els.length; i++)
      CosmicPartyMember(
        instanceId: 'i$i',
        baseId: 'b$i',
        displayName: els[i],
        element: els[i],
        family: fams[i % 3],
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
  g.entryDoorRevealed = true;
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
  testWidgets('how bare is every room', (tester) async {
    await tester.runAsync(() async {
      final out = Directory('build/room_audit');
      final rows = <(String, String, int, int)>[];
      for (final element in kPlanetDungeonLayouts.keys) {
        final layout = kPlanetDungeonLayouts[element]!;
        final g = _game(element);
        for (final id in layout.rooms.keys) {
          g.currentRoomId = id;
          final stand = layout.rooms[id]!.bounds.center;
          for (final c in g.creatures) {
            c
              ..position = stand
              ..lastSafe = stand;
          }
          for (var i = 0; i < 24; i++) {
            g.update(1 / 60);
          }
          final rec = ui.PictureRecorder();
          g.render(Canvas(rec));
          final img = await rec.endRecording().toImage(900, 600);
          if (out.existsSync()) {
            final png = await img.toByteData(format: ui.ImageByteFormat.png);
            File(
              'build/room_audit/${element}_$id.png',
            ).writeAsBytesSync(png!.buffer.asUint8List());
          }
          final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
          final b = raw!.buffer.asUint8List();
          // Distinct quantised colours = how much is actually drawn, and
          // "edge" pixels = how much of it has shape rather than wash.
          final palette = <int>{};
          var edges = 0;
          for (var y = 0; y < 600; y += 2) {
            for (var x = 0; x < 900; x += 2) {
              final i = (y * 900 + x) * 4;
              palette.add(
                (b[i] >> 4 << 8) | (b[i + 1] >> 4 << 4) | b[i + 2] >> 4,
              );
              final j = (y * 900 + x + 2) * 4;
              if (x < 896 &&
                  (b[i] - b[j]).abs() + (b[i + 1] - b[j + 1]).abs() > 22) {
                edges++;
              }
            }
          }
          expect(
            palette.length,
            greaterThan(8),
            reason: '$element/$id drew almost nothing at all',
          );
          rows.add((element, id, palette.length, edges));
        }
      }
      rows.sort((a, b) => a.$4.compareTo(b.$4));
      // Low end first: those are the rooms that may genuinely be boxes. The
      // high end is not a leaderboard.
      for (final r in rows) {
        // ignore: avoid_print
        print(
          '${r.$4.toString().padLeft(6)} edges  ${r.$3.toString().padLeft(4)} cols  ${r.$1}/${r.$2}',
        );
      }
    });
  });
}
