// GLACIUS, RENDERED — the states, not just the rooms.
//
// `dungeon_room_render_test.dart` draws every room in its OPENING state,
// which for Ice is the least interesting frame of every one of them: both
// holes in the mouth are capped, every flue is drift, the pool is dead black
// and the boss room's pillar is down. Everything this planet is ABOUT is a
// change of state, and a state that draws the same as its neighbour is a
// state the player cannot read.
//
// So this renders the states side by side and asserts they are actually
// different pictures (Mud's lesson — a checksum over a drag that changed a
// few hundred bytes passed happily while the screen said nothing). With
// `build/room_audit` present it writes the PNGs too.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_ice.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanetDungeonGame _game() {
  final els = kCosmicPlanetEntry['Ice']!;
  const fams = ['mane', 'mask', 'wing'];
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
    element: 'Ice',
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

  testWidgets('every state of the shaft draws its own picture', (tester) async {
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
            'build/room_audit/IceState_$name.png',
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

      void openTheFloor(PlanetDungeonGame g) {
        g.entryDoorRevealed = true;
        for (final f in kRimeFlues.where((f) => f.headRoom == 'rime_head')) {
          g.meltedCaps.add('${f.id}:shaft');
          if (f.chutePos != null) g.meltedCaps.add('${f.id}:chute');
        }
      }

      const headStand = Offset(380, 300);
      await shoot('head_capped', 'rime_head', headStand, (g) {});
      await shoot('head_one_plate', 'rime_head', headStand, (g) {
        // One plate drunk, the rest still black: the floor's first lesson.
        g.entryDoorRevealed = true;
        g.meltedCaps.add('flue_a:shaft');
      });
      await shoot('head_open', 'rime_head', headStand, openTheFloor);
      await shoot('head_stair', 'rime_head', headStand, (g) {
        openTheFloor(g);
        g.flueState['flue_a'] = RimeFlueState.stair;
      });
      await shoot('head_scoured', 'rime_head', headStand, (g) {
        openTheFloor(g);
        g.flueState['flue_a'] = RimeFlueState.scoured;
      });
      await shoot('head_chute_spent', 'rime_head', headStand, (g) {
        openTheFloor(g);
        g.spentChutes.add('flue_a');
      });

      final ring =
          kPlanetDungeonLayouts['Ice']!.rooms['mirror_gallery']!.rime!.mirrors!;
      await shoot('pool_dead', 'mirror_gallery', ring.frameAt(2), (g) {});
      // The anchor alone in the water: one stretch of chart and nothing else.
      // The water reads for the LIGHT hand wherever it stands, so the shots
      // park it on the rim — which is how the room is actually worked.
      void asLight(PlanetDungeonGame g) {
        final r = g.layout.rooms['mirror_gallery']!.rime!.mirrors!;
        g.creatures[1].position = r.frameAt(6);
      }

      await shoot('chart_anchor', 'mirror_gallery', ring.frameAt(6), (g) {
        g.lodestoneLit = true;
        g.update(1 / 60);
        asLight(g);
        g.silveredFrames
          ..clear()
          ..add(0);
      });
      // Built out, and joining: the anchor and its true neighbours.
      await shoot('chart_joined', 'mirror_gallery', ring.frameAt(6), (g) {
        g.lodestoneLit = true;
        g.update(1 / 60);
        asLight(g);
        for (var i = 0; i < 12; i++) {
          g.frameOffset[i] = 0;
        }
        g.silveredFrames
          ..clear()
          ..addAll([0, 1, 2, 11, 10]);
      });
      // And forking, because one of those frames is hung false.
      await shoot('chart_forked', 'mirror_gallery', ring.frameAt(6), (g) {
        g.lodestoneLit = true;
        g.update(1 / 60);
        asLight(g);
        for (var i = 0; i < 12; i++) {
          g.frameOffset[i] = 0;
        }
        g.frameOffset[11] = 2;
        g.silveredFrames
          ..clear()
          ..addAll([0, 1, 2, 11, 10]);
      });
      // Read from somewhere else on the rim: a different stretch of water.
      await shoot('chart_other_side', 'mirror_gallery', ring.frameAt(2), (g) {
        g.lodestoneLit = true;
        g.update(1 / 60);
        g.creatures[1].position = ring.frameAt(2);
        for (var i = 0; i < 12; i++) {
          g.frameOffset[i] = 0;
        }
        g.silveredFrames
          ..clear()
          ..addAll([0, 1, 2, 11, 10]);
      });

      // THE LIGHT-UP, mid-sweep: the whole chart taking the fire.
      await shoot('chart_triumph', 'mirror_gallery', ring.frameAt(6), (g) {
        g.lodestoneLit = true;
        g.update(1 / 60);
        for (var i = 0; i < 12; i++) {
          g.frameOffset[i] = 0;
        }
        g.silveredFrames
          ..clear()
          ..addAll([for (var i = 0; i < 12; i++) i]);
        g.chartTriumph = 1.4;
      });

      final grid0 =
          kPlanetDungeonLayouts['Ice']!.rooms['orrery_floor']!.rime!.orrery!;
      await shoot(
        'orrery_bare',
        'orrery_floor',
        const Offset(450, 300),
        (g) {},
      );
      // Standing behind a block, in reach: the ring says you can take hold.
      await shoot('orrery_in_reach', 'orrery_floor', grid0.centerAt(0, 2), (g) {
        for (final cr in g.creatures) {
          cr
            ..angle = 0
            ..aimAngle = 0;
        }
      });
      await shoot('orrery_road', 'orrery_floor', const Offset(450, 300), (g) {
        final grid = g.layout.rooms['orrery_floor']!.rime!.orrery!;
        for (final c in [2, 3, 4, 5]) {
          g.orreryGlass.add(2 * grid.cols + c);
        }
      });
      // THE PREVIEW: stand west of the west block, facing east, with a road
      // laid — the floor draws the run and where it would stop.
      final grid =
          kPlanetDungeonLayouts['Ice']!.rooms['orrery_floor']!.rime!.orrery!;
      await shoot('orrery_preview', 'orrery_floor', grid.centerAt(0, 2), (g) {
        for (final c in [2, 3]) {
          g.orreryGlass.add(2 * grid.cols + c);
        }
        for (final cr in g.creatures) {
          cr
            ..angle = 0
            ..aimAngle = 0;
        }
      });
      // And the seating run: straight into the kerb on the bottom row.
      await shoot('orrery_preview_seats', 'orrery_floor', grid.centerAt(2, 4), (
        g,
      ) {
        for (final cr in g.creatures) {
          cr
            ..angle = 0
            ..aimAngle = 0;
        }
      });

      await shoot('hollow_down', 'frowyrm_hollow', const Offset(450, 300), (g) {
        g.guardianAwake = true;
      });
      await shoot('hollow_standing', 'frowyrm_hollow', const Offset(450, 300), (
        g,
      ) {
        g.guardianAwake = true;
        g.hoarfrostWhole = true;
      });

      // Every pair inside a room must be a different picture. This is the
      // whole point: a flue's three states, a pool that is dead or reading,
      // a road laid, a pillar up or down.
      const groups = [
        [
          'head_capped',
          'head_one_plate',
          'head_open',
          'head_stair',
          'head_scoured',
          'head_chute_spent',
        ],
        [
          'pool_dead',
          'chart_anchor',
          'chart_joined',
          'chart_forked',
          'chart_other_side',
          'chart_triumph',
        ],
        [
          'orrery_bare',
          'orrery_road',
          'orrery_preview',
          'orrery_preview_seats',
        ],
        ['hollow_down', 'hollow_standing'],
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
