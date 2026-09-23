// VERDANTHOS, RENDERED — the states, not just the rooms.
//
// Everything this planet is ABOUT is the size you are and what a bed holds,
// so this renders the states side by side and asserts they are actually
// different pictures (Mud's lesson). With `build/room_audit` present it
// writes the PNGs too.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_plant.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanetDungeonGame _game() {
  final els = kCosmicPlanetEntry['Plant']!;
  const fams = ['mane', 'mask', 'pip'];
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
    element: 'Plant',
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

  testWidgets('every state of the crypt draws its own picture', (tester) async {
    await tester.runAsync(() async {
      final out = Directory('build/room_audit');
      final shots = <String, int>{};

      Future<void> shoot(
        String name,
        String roomId,
        Offset stand,
        void Function(PlanetDungeonGame g) setup,
      ) async {
        final g = _game();
        g.currentRoomId = roomId;
        g.entryDoorRevealed = true;
        setup(g);
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
            'build/room_audit/PlantState_$name.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        }
        final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final b = raw!.buffer.asUint8List();
        var h = 17;
        for (var i = 0; i < b.length; i += 97) {
          h = (h * 31 + b[i]) & 0x3FFFFFFF;
        }
        shots[name] = h;
      }

      final layout = kPlanetDungeonLayouts['Plant']!;

      // THE PORCH: knotted, open, and small.
      const porchStand = Offset(350, 300);
      await shoot('porch_knotted', 'root_porch', porchStand, (g) {
        g.entryDoorRevealed = false;
      });
      await shoot('porch_open_huge', 'root_porch', porchStand, (g) {});
      await shoot('porch_open_tiny', 'root_porch', porchStand, (g) {
        g.crypt.scale = PlantScale.tiny;
      });

      // THE GALLERY: the bed bare; a creeper; the trunk and its shade, with
      // the seed tended once, and tended whole.
      const galleryStand = Offset(520, 200);
      await shoot('gallery_bare', 'fern_gallery', galleryStand, (g) {});
      await shoot('gallery_creeper', 'fern_gallery', galleryStand, (g) {
        g.crypt.bed['b_root'] = VineState.creeper;
      });
      await shoot('gallery_trunk_shade_tiny', 'fern_gallery', galleryStand, (
        g,
      ) {
        g.crypt.scale = PlantScale.tiny;
        g.crypt.bed['b_root'] = VineState.trunk;
      });
      await shoot('gallery_shade_tended', 'fern_gallery', galleryStand, (g) {
        g.crypt.scale = PlantScale.tiny;
        g.crypt.bed['b_root'] = VineState.trunk;
        g.crypt.shadeStep = 3;
      });
      await shoot('gallery_shade_risen', 'fern_gallery', galleryStand, (g) {
        g.crypt.bed['b_root'] = VineState.trunk;
        g.crypt.shadeStep = 3;
        g.crypt.shadeRisen = true;
      });

      // THE MOSS WALK: the sconce dead and lit.
      const walkStand = Offset(450, 300);
      await shoot('walk_lamp_dead', 'mosswalk', walkStand, (g) {});
      await shoot('walk_lamp_lit', 'mosswalk', walkStand, (g) {
        g.crypt.lampsLit.add('lamp_walk');
      });

      // THE ISLET: the bowl dry, and the seed woken.
      const isletStand = Offset(380, 420);
      await shoot('islet_dry', 'islet', isletStand, (g) {});
      await shoot('islet_woken', 'islet', isletStand, (g) {
        g.crypt.bloomStep = 3;
      });

      expect(layout.rooms['fern_gallery']!.grove!.shadeSeed, isNotNull);

      const groups = [
        ['porch_knotted', 'porch_open_huge', 'porch_open_tiny'],
        [
          'gallery_bare',
          'gallery_creeper',
          'gallery_trunk_shade_tiny',
          'gallery_shade_tended',
          'gallery_shade_risen',
        ],
        ['walk_lamp_dead', 'walk_lamp_lit'],
        ['islet_dry', 'islet_woken'],
      ];
      for (final g in groups) {
        for (var i = 0; i < g.length; i++) {
          for (var j = i + 1; j < g.length; j++) {
            expect(
              shots[g[i]],
              isNot(shots[g[j]]),
              reason: '${g[i]} and ${g[j]} draw the same room',
            );
          }
        }
      }
    });
  });
}
