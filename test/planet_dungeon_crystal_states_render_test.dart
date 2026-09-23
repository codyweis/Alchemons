// VITREA, RENDERED — the states, not just the rooms.
//
// `dungeon_room_render_test.dart` draws every room in its OPENING state.
// Everything this planet is ABOUT is the arrangement and what stands in a
// socket, so this renders the states side by side and asserts they are
// actually different pictures (Mud's lesson). With `build/room_audit` present
// it writes the PNGs too.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_crystal.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanetDungeonGame _game() {
  final els = kCosmicPlanetEntry['Crystal']!;
  const fams = ['mask', 'horn', 'pip'];
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
    element: 'Crystal',
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

  testWidgets('every state of the keep draws its own picture', (tester) async {
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
            'build/room_audit/CrystalState_$name.png',
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

      // THE BLACK CELL, in the corner: dark, the flaw found, crazed clear.
      const nw = 'keep_nw';
      final inside = kChamberHeart + const Offset(-40, 30);
      await shoot('nw_black_sealed', nw, inside, (g) {});
      await shoot('nw_black_flawed', nw, inside, (g) {
        g.prism.knowCrack = true;
        g.prism.knowStrikes = 1;
      });
      await shoot('nw_black_clear', nw, inside, (g) {
        g.prism.knowCrack = true;
        g.prism.knowStrikes = PrismLabyrinth.knowStrikesToClear;
      });

      // THE HEART: the hearth cold, and struck warm.
      const core = 'keep_core';
      await shoot(
        'core_hearth_cold',
        core,
        kChamberHeart + const Offset(0, 90),
        (g) {},
      );
      await shoot(
        'core_hearth_warm',
        core,
        kChamberHeart + const Offset(0, 90),
        (g) {
          g.prism.field.hearthKindled = true;
        },
      );

      // THE BEAM ROW: the lamp out, and lit through clear glass.
      const west = 'keep_w';
      await shoot('w_lamp_out', west, kChamberHeart + const Offset(0, 90), (g) {
        g.prism.field.restore([2, 5, 6, 3, 0, 4, 7, 1, kHollow]);
      });
      await shoot('w_lamp_lit', west, kChamberHeart + const Offset(0, 90), (g) {
        g.prism.field
          ..restore([2, 5, 6, 3, 0, 4, 7, 1, kHollow])
          ..lampLit = true;
      });

      // THE CHOIR: the gap in the corner, and under the mystic.
      const choir = 'prismalith_choir';
      await shoot('choir_gap_corner', choir, const Offset(450, 560), (g) {
        g.guardianAwake = true;
      });
      await shoot('choir_gap_heart', choir, const Offset(450, 560), (g) {
        g.guardianAwake = true;
        g.prism.choirHollow = kKeepHeartCell;
      });

      const groups = [
        ['nw_black_sealed', 'nw_black_flawed', 'nw_black_clear'],
        ['core_hearth_cold', 'core_hearth_warm'],
        ['w_lamp_out', 'w_lamp_lit'],
        ['choir_gap_corner', 'choir_gap_heart'],
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
