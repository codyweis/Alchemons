// GLACIUS, IN GLASS — the states Ice's glass is meant to show
// (docs/dungeons.md §7.11), asserted to be different pictures.
//
// The rooms whole are `planet_dungeon_whole_room_audit_test.dart
// --dart-define=AUDIT=Ice`; this is the STATES. The Star-Walker is shot from a
// game where only the maxim's id is set — a found maxim's mark must stand on
// every later descent.
//
// `mkdir -p build/room_audit` and run this to get the PNGs (IceGlass_*.png).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String roomId, {int stars = 0}) async {
  const els = ['Ice', 'Light', 'Air'];
  const fams = ['mane', 'mask', 'wing'];
  final party = [
    for (var i = 0; i < els.length; i++)
      CosmicPartyMember(
        instanceId: 'i$i',
        baseId: 'b$i',
        displayName: els[i],
        element: els[i],
        family: fams[i],
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
    element: 'Ice',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  g.starMask = stars; // applied in onLoad, which a headless game never runs
  final b = kPlanetDungeonLayouts['Ice']!.rooms[roomId]!.bounds;
  g.onGameResize(Vector2(b.width + 60, b.height + 60));
  g.entryDoorRevealed = true;
  g.currentRoomId = roomId;
  final stand = Offset(b.left + 60, b.bottom - 40);
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = stand
        ..lastSafe = stand,
    );
  }
  return g;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every state the observatory\'s glass shows', (tester) async {
    await tester.runAsync(() async {
      final out = Directory('build/room_audit');
      final shots = <String, int>{};

      Future<void> shoot(
        String name,
        String roomId, {
        int stars = 0,
        void Function(PlanetDungeonGame g)? setup,
        double seconds = 0.4,
      }) async {
        final g = await _game(roomId, stars: stars);
        setup?.call(g);
        for (var i = 0; i < (seconds * 60).round(); i++) {
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
            'build/room_audit/IceGlass_$name.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        }
        final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = raw!.buffer.asUint8List();
        var hash = 17;
        for (var i = 0; i < bytes.length; i += 97) {
          hash = (hash * 31 + bytes[i]) & 0x3FFFFFFF;
        }
        shots[name] = hash;
      }

      // The roof of the hollow: under snow, and bared pane by pane.
      const wyrm = [30, 29, 28, 37, 38];
      await shoot(
        'roof_snow',
        'star_font',
        setup: (g) => g.seedRoofForTest(wyrm),
      );
      await shoot(
        'roof_bared',
        'star_font',
        setup: (g) {
          g.seedRoofForTest(wyrm);
          g.roofBare.addAll([0, 1, 10, 19, 29, 30, 31]);
        },
      );

      // The mirror gallery, its frames leaded.
      await shoot('gallery', 'mirror_gallery');

      // The Star-Walker: the telescope; the stranger being caught as the
      // rite binds; and the star in its lens on a later descent.
      await shoot('lens', 'shelf_lens');
      await shoot(
        'lens_catching',
        'shelf_lens',
        setup: (g) {
          final at = g.layout.rooms['shelf_lens']!.rime!.telescope!;
          g.beginMaximRite(kIceStarWalkerEggId, at);
        },
        seconds: 1.2,
      );
      await shoot(
        'lens_found',
        'shelf_lens',
        setup: (g) => g.discoveredClouds.add(kIceStarWalkerEggId),
      );

      await shoot('orrery', 'orrery_floor');

      for (final (a, b) in const [
        ('roof_snow', 'roof_bared'),
        ('lens', 'lens_catching'),
        ('lens_catching', 'lens_found'),
      ]) {
        expect(
          shots[a] != shots[b],
          isTrue,
          reason: '$a and $b draw the same picture',
        );
      }
    });
  });
}
