// THE WIND-CROWN SPIRE, IN GLASS — the states Air's glass is meant to show
// (docs/dungeons.md §7.11), asserted to be different pictures.
//
// The rooms whole are `planet_dungeon_whole_room_audit_test.dart
// --dart-define=AUDIT=Air`; this is the STATES. The First Wind is shot from a
// game where only the maxim's id is set — a found maxim's mark must stand on
// every later descent.
//
// `mkdir -p build/room_audit` and run this to get the PNGs (AirGlass_*.png).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String roomId, {int stars = 0}) async {
  const els = ['Air', 'Lightning', 'Fire'];
  const fams = ['wing', 'horn', 'mask'];
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
    element: 'Air',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  g.starMask = stars; // applied in onLoad, which a headless game never runs
  final b = kPlanetDungeonLayouts['Air']!.rooms[roomId]!.bounds;
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

  testWidgets('every state the spire\'s glass shows', (tester) async {
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
            'build/room_audit/AirGlass_$name.png',
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

      // The hub's rose: empty, two stars banked, and the First Wind found.
      await shoot('hub_empty', 'hub');
      await shoot('hub_two_stars', 'hub', stars: 0x3);
      await shoot(
        'hub_first_wind',
        'hub',
        stars: 0x7,
        setup: (g) => g.discoveredClouds.add(kAirFirstWindEggId),
        seconds: 1.0,
      );

      // The spire: shrines asleep, then one gale woken.
      await shoot('spire_asleep', 'lower_spire');
      await shoot(
        'spire_woken',
        'lower_spire',
        setup: (g) {
          g.wokenGales.add('g_thermal');
          g.galeRamp['g_thermal'] = 1.0;
        },
      );

      // The gale eye: every vent shut, then two jets open.
      await shoot('eye_shut', 'spiral_cloud');
      await shoot(
        'eye_two_open',
        'spiral_cloud',
        setup: (g) {
          for (final v in ['v_north', 'v_dawn']) {
            g.spiralOpenJets.add(v);
            g.spiralJetRamp[v] = 1.0;
          }
        },
      );

      // The rod field, flat and then ranked into a stair.
      await shoot('rods_flat', 'twin_conduit');
      await shoot(
        'rods_ranked',
        'twin_conduit',
        setup: (g) {
          g.rodHeight['rod_low'] = 1;
          g.rodHeight['rod_axis'] = 2;
          g.rodHeight['rod_north'] = 3;
        },
        seconds: 1.0,
      );

      // The altar, cold and open; the mural, partial and read.
      await shoot('altar_cold', 'storm_altar', stars: 0x3);
      await shoot(
        'altar_open',
        'storm_altar',
        stars: 0x3,
        setup: (g) {
          g.altarOpen = true;
        },
        seconds: 2.4,
      );
      await shoot('mural_partial', 'storm_rune_hall', stars: 0x3);
      await shoot(
        'mural_read',
        'storm_rune_hall',
        stars: 0x3,
        setup: (g) => g.revealTier = 1,
      );

      // The loom, empty and with two echoes laid in.
      await shoot('loom_empty', 'sky_loom');
      await shoot(
        'loom_two',
        'sky_loom',
        setup: (g) {
          g.filledAnchors['a_spiral'] = 'Spiral';
          g.filledAnchors['a_ring'] = 'Ring';
        },
      );

      for (final (a, b) in const [
        ('hub_empty', 'hub_two_stars'),
        ('hub_two_stars', 'hub_first_wind'),
        ('spire_asleep', 'spire_woken'),
        ('eye_shut', 'eye_two_open'),
        ('rods_flat', 'rods_ranked'),
        ('altar_cold', 'altar_open'),
        ('mural_partial', 'mural_read'),
        ('loom_empty', 'loom_two'),
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
