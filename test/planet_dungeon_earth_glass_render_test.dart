// THE BURIED GIANT, IN GLASS — the states Earth's glass is meant to show
// (docs/dungeons.md §7.11), asserted to be different pictures.
//
// The rooms whole are `planet_dungeon_whole_room_audit_test.dart
// --dart-define=AUDIT=Earth`; this is the STATES. The Palm is shot from a game
// where only the maxim's id is set — a found maxim's mark must stand on
// every later descent.
//
// `mkdir -p build/room_audit` and run this to get the PNGs (EarthGlass_*.png).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String roomId, {int stars = 0}) async {
  const els = ['Earth', 'Lightning', 'Crystal'];
  const fams = ['horn', 'mane', 'mask'];
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
    element: 'Earth',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  g.starMask = stars; // applied in onLoad, which a headless game never runs
  final b = kPlanetDungeonLayouts['Earth']!.rooms[roomId]!.bounds;
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

  testWidgets('every state the barrow\'s glass shows', (tester) async {
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
            'build/room_audit/EarthGlass_$name.png',
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

      // The crypt: pillars risen, then a socket bared, one locked (its
      // crystal growing) and one sealed.
      await shoot('crypt_risen', 'pillar_crypt', setup: (g) => g.cryptRise = 1);
      await shoot(
        'crypt_worked',
        'pillar_crypt',
        setup: (g) {
          g.cryptRise = 1;
          g.pillarBared.add('pillar_nw');
          g.lockedPillars.add('pillar_ne');
          g.pillarSealed.add('pillar_sw');
        },
      );

      // The eye: blind, then seeing through its prism.
      await shoot('eye_blind', 'eye_chamber', stars: 0x3);
      await shoot(
        'eye_seeing',
        'eye_chamber',
        stars: 0x3,
        setup: (g) => g.prismStage = 2,
        seconds: 2.0,
      );

      // The Palm: open and empty; the crystal taking root while the rite
      // binds; and the cluster on a later descent (the id alone).
      await shoot('palm_empty', 'palm_hollow');
      await shoot(
        'palm_growing',
        'palm_hollow',
        setup: (g) =>
            g.beginMaximRite(kEarthGiantsPalmEggId, const Offset(320, 310)),
        seconds: 1.4,
      );
      await shoot(
        'palm_found',
        'palm_hollow',
        setup: (g) => g.discoveredClouds.add(kEarthGiantsPalmEggId),
      );

      await shoot('mural', 'skull_antechamber');

      // The scale, with two of the giant's tablets read.
      await shoot(
        'scale_memory',
        'eye_chamber',
        setup: (g) => g.scaleCluesRead.addAll(['w_skull', 'w_spine']),
      );

      for (final (a, b) in const [
        ('crypt_risen', 'crypt_worked'),
        ('eye_blind', 'eye_seeing'),
        ('palm_empty', 'palm_growing'),
        ('palm_growing', 'palm_found'),
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
