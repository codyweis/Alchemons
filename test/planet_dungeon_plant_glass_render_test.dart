// VERDANTHOS, IN GLASS — the states Plant's glass is meant to show
// (docs/dungeons.md §7.11), asserted to be different pictures.
//
// The rooms whole are `planet_dungeon_whole_room_audit_test.dart
// --dart-define=AUDIT=Plant`; this is the STATES. The kept shade tree is shot from a
// game where only the maxim's id is set — a found maxim's mark must stand on
// every later descent.
//
// `mkdir -p build/room_audit` and run this to get the PNGs (PlantGlass_*.png).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String roomId, {int stars = 0}) async {
  const els = ['Plant', 'Mud', 'Light'];
  const fams = ['horn', 'mask', 'wing'];
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
    element: 'Plant',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  g.starMask = stars; // applied in onLoad, which a headless game never runs
  final b = kPlanetDungeonLayouts['Plant']!.rooms[roomId]!.bounds;
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

  testWidgets('every state the crypt\'s glass shows', (tester) async {
    await tester.runAsync(() async {
      final out = Directory('build/room_audit');
      final shots = <String, int>{};

      Future<void> shoot(
        String name,
        String roomId, {
        void Function(PlanetDungeonGame g)? setup,
        double seconds = 0.4,
      }) async {
        final g = await _game(roomId);
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
            'build/room_audit/PlantGlass_$name.png',
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

      // A grave-lamp, dead and lit.
      await shoot('lamp_dead', 'lantern_court');
      await shoot(
        'lamp_lit',
        'lantern_court',
        setup: (g) => g.crypt.lampsLit.add('lamp_court'),
      );

      // The growth altar: cold, two steps laid, woken.
      await shoot('altar', 'islet');
      await shoot('altar_two', 'islet', setup: (g) => g.crypt.bloomStep = 2);
      await shoot('altar_woken', 'islet', setup: (g) => g.crypt.bloomStep = 3);

      // The shade: the gallery bare, the tree growing as the rite binds, and
      // the tree on a later descent.
      await shoot('gallery', 'fern_gallery');
      await shoot(
        'gallery_rite',
        'fern_gallery',
        setup: (g) {
          g.crypt.shadeRisen = true;
          g.beginMaximRite(
            kPlantUnseenShadeEggId,
            g.layout.rooms['fern_gallery']!.grove!.shadeSeed!,
          );
        },
        seconds: 1.4,
      );
      await shoot(
        'gallery_kept',
        'fern_gallery',
        setup: (g) => g.discoveredClouds.add(kPlantUnseenShadeEggId),
      );

      for (final (a, b) in const [
        ('lamp_dead', 'lamp_lit'),
        ('altar', 'altar_two'),
        ('altar_two', 'altar_woken'),
        ('gallery', 'gallery_rite'),
        ('gallery_rite', 'gallery_kept'),
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
