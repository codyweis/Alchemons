// THE MOLTEN RELIQUARY, IN GLASS — every room of the works whole, and every
// change of state its glass is meant to show (docs/dungeons.md §7.11).
//
// Like the Fire glass test: the viewport is sized to each room, the glow
// sprites are loaded (a headless game has none), and the states the glass
// claims to show are asserted to be different pictures. The Black Glass is
// shot from a game where the maxim's id is the ONLY thing set — the rule is
// that a found maxim's piece stands on every later descent.
//
// `mkdir -p build/room_audit` and run this to get the PNGs (LavaGlass_*.png).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_lava.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String roomId, {int stars = 0}) async {
  const els = ['Lava', 'Earth', 'Ice'];
  const fams = ['horn', 'mask', 'mane'];
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
    element: 'Lava',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  g.starMask = stars; // applied in onLoad, which a headless game never runs
  final b = kPlanetDungeonLayouts['Lava']!.rooms[roomId]!.bounds;
  g.onGameResize(Vector2(b.width + 60, b.height + 60));
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

  testWidgets('every room of the works, in every state its glass shows', (
    tester,
  ) async {
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
        final w = g.size.x.round(), h = g.size.y.round();
        final rec = ui.PictureRecorder();
        g.render(Canvas(rec));
        final img = await rec.endRecording().toImage(w, h);
        if (out.existsSync()) {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            'build/room_audit/LavaGlass_$name.png',
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

      void woken(PlanetDungeonGame g) {
        g.works.line.tapWoken = true;
        g.entryDoorRevealed = true;
      }

      // The tap: sealed, then woken (the sight-glass lit, the door split open).
      await shoot('tap_cold', 'tap_head');
      await shoot('tap_woken', 'tap_head', setup: woken, seconds: 2.0);

      // The switch yard, before and after a lever is thrown.
      await shoot('yard', 'switch_yard', setup: woken);
      await shoot(
        'yard_thrown',
        'switch_yard',
        setup: (g) {
          woken(g);
          g.works.line.switches['y_yard'] = 0; // from MILL to CHILL
        },
      );

      // The chill house: the hood up and down, the slag thrown away, the
      // Black Glass setting, and the Black Glass from a later descent.
      await shoot('chill', 'chill_house', setup: woken);
      await shoot(
        'chill_hood_down',
        'chill_house',
        setup: (g) {
          woken(g);
          g.works.line.switches['chiller'] = 1;
        },
      );
      await shoot(
        'chill_slag_taken',
        'chill_house',
        setup: (g) {
          woken(g);
          g.works.line.slagTaken = true;
        },
      );
      await shoot(
        'chill_black_glass_setting',
        'chill_house',
        setup: (g) {
          woken(g);
          g.works.line.slagTaken = true;
          g.discoveredClouds.add(kLavaBlackGlassEggId);
          g.works.blackGlass = 0; // seen, and not yet set: watch it take
        },
        seconds: 1.2,
      );
      await shoot(
        'chill_black_glass',
        'chill_house',
        setup: (g) => g.discoveredClouds.add(kLavaBlackGlassEggId),
      );

      // The stamp mill: the die dead, then charged with the damper open.
      await shoot('mill', 'stamp_mill', setup: woken);
      await shoot(
        'mill_woken',
        'stamp_mill',
        setup: (g) {
          woken(g);
          g.works.line.dieWoken = true;
          g.works.line.switches['damper'] = 1;
        },
      );

      // The mold floor: the forms waiting, then one holding a good span and
      // one spoiled.
      await shoot('molds_empty', 'mold_floor', setup: woken);
      await shoot(
        'molds_cast',
        'mold_floor',
        setup: (g) {
          woken(g);
          final s = g.works.line;
          s.molds['mold_span_a'] = 'span_a';
          s.castings['cast:span_a'] = const FoundryCasting(
            id: 'cast:span_a',
            roomId: 'mold_floor',
            rect: Rect.zero,
            channelId: '',
          );
          s.molds['mold_key'] = 'gantry';
          s.castings['cast:gantry'] = const FoundryCasting(
            id: 'cast:gantry',
            roomId: 'mold_floor',
            rect: Rect.zero,
            channelId: '',
            spoiled: true,
          );
        },
      );

      // The reliquary's ward: locked, and with its key in hand.
      await shoot('reliquary', 'slag_reliquary', setup: woken);
      await shoot(
        'mold_floor_key_in_hand',
        'mold_floor',
        setup: (g) {
          woken(g);
          g.works.line.carried = 'reliquary';
        },
      );

      await shoot('heart', 'pour_heart', stars: 0x3, setup: woken);

      for (final (a, b) in const [
        ('tap_cold', 'tap_woken'),
        ('yard', 'yard_thrown'),
        ('chill', 'chill_hood_down'),
        ('chill', 'chill_slag_taken'),
        ('chill_slag_taken', 'chill_black_glass_setting'),
        ('chill_black_glass_setting', 'chill_black_glass'),
        ('mill', 'mill_woken'),
        ('molds_empty', 'molds_cast'),
        ('molds_empty', 'mold_floor_key_in_hand'),
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
