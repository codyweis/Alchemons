// SOLARIN, RENDERED — the states, not just the rooms.
//
// `dungeon_room_render_test.dart` draws every room in its OPENING state,
// which for Light is the keepers' blaze and nothing pressed. Everything this
// planet is ABOUT is what the beacons are set to, and a state that draws the
// same as its neighbour is a state the player cannot read. So this renders
// the states side by side and asserts they are actually different pictures
// (Mud's lesson). With `build/room_audit` present it writes the PNGs too.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanetDungeonGame _game() {
  final els = kCosmicPlanetEntry['Light']!;
  const fams = ['mask', 'mask', 'pip'];
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
    element: 'Light',
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

  testWidgets('every state of the beacon archive draws its own picture', (
    tester,
  ) async {
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
            'build/room_audit/LightState_$name.png',
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

      final layout = kPlanetDungeonLayouts['Light']!;
      void blaze(PlanetDungeonGame g) {
        g.archive.lamp['bc_narthex'] = 4;
        g.archive.lamp['bc_oriel'] = 4;
        g.archive.lamp['bc_ledger'] = 4;
      }

      void douse(PlanetDungeonGame g) {
        g.archive.lamp['bc_narthex'] = 0;
        g.archive.lamp['bc_oriel'] = 0;
        g.archive.lamp['bc_ledger'] = 0;
      }

      // THE DOORWAY: shutter folded; the keepers' blaze; dark.
      const doorStand = Offset(200, 300);
      await shoot('door_shut', 'lumen_threshold', doorStand, (g) {
        g.entryDoorRevealed = false;
      });
      await shoot('door_keepers_blaze', 'lumen_threshold', doorStand, (g) {});
      await shoot('door_dark', 'lumen_threshold', doorStand, douse);

      // THE COURT: the shadow of a readable effigy, and two read.
      const courtStand = Offset(330, 380);
      await shoot('court_keepers_blaze', 'shadow_court', courtStand, (g) {});
      await shoot('court_low_fan', 'shadow_court', courtStand, (g) {
        g.archive.lamp['bc_narthex'] = 1; // low: the court's shelf dark
      });
      await shoot('court_two_read', 'shadow_court', courtStand, (g) {
        g.archive.lamp['bc_narthex'] = 1;
        g.archive.effigiesRead.addAll(['ef_moth', 'ef_key']);
      });

      // THE CATALOGUE: panes as the hall stands; whole; read.
      final cat = layout.rooms['catalogue_walk']!.hall!.catalogue!;
      final catStand = cat + const Offset(0, 120);
      await shoot(
        'catalogue_keepers_blaze',
        'catalogue_walk',
        catStand,
        (g) {},
      );
      await shoot('catalogue_whole', 'catalogue_walk', catStand, blaze);
      await shoot('catalogue_read', 'catalogue_walk', catStand, (g) {
        blaze(g);
        g.archive.indexSocket = 2;
        g.archive.indexRead = true;
      });

      // THE OCULUS STAIR: slabs unread in the dark; the named one glowing.
      const stairStand = Offset(360, 400);
      await shoot('stair_dark_unread', 'oculus_stair', stairStand, douse);
      await shoot('stair_dark_named', 'oculus_stair', stairStand, (g) {
        douse(g);
        g.archive.indexSocket = 2;
        g.archive.indexRead = true;
      });

      // THE ARENA: the glare with its three bites.
      await shoot('arena_glare', 'solarin_oculus', const Offset(200, 470), (g) {
        g.guardianAwake = true;
        g.archive.glare = 1.2;
      });

      const groups = [
        ['door_shut', 'door_keepers_blaze', 'door_dark'],
        ['court_keepers_blaze', 'court_low_fan', 'court_two_read'],
        ['catalogue_keepers_blaze', 'catalogue_whole', 'catalogue_read'],
        ['stair_dark_unread', 'stair_dark_named'],
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
      expect(shots, contains('arena_glare'));
    });
  });
}
