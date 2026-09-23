// NYTHRALOR, RENDERED — the states, not just the rooms.
//
// `dungeon_room_render_test.dart` draws every room in its OPENING state,
// which for Dark is one arrangement of the eclipse and nothing pressed: the
// pall hung, no stone seated, every ring rusted, every lamp lit, the abyss a
// hole with no bottom. Everything this planet is ABOUT is the vault turning
// over, and a state that draws the same as its neighbour is a state the
// player cannot read.
//
// So this renders the states side by side and asserts they are actually
// different pictures (Mud's lesson). With `build/room_audit` present it
// writes the PNGs too.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dark.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanetDungeonGame _game() {
  final els = kCosmicPlanetEntry['Dark']!;
  const fams = ['mask', 'pip', 'mane'];
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
    element: 'Dark',
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

  testWidgets('every state of the eclipse vault draws its own picture', (
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
            'build/room_audit/DarkState_$name.png',
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

      final layout = kPlanetDungeonLayouts['Dark']!;
      final porchGnomon = vaultGnomonById('gn_porch')!;

      // THE PORCH: the pall hung and drawn; the gnomon holding each quarter,
      // with the night-hand in reach so the ghost wedge shows.
      await shoot('porch_pall_hung', 'pall_porch', const Offset(200, 300), (g) {
        g.entryDoorRevealed = false;
      });
      await shoot('porch_shadow_on_pall', 'pall_porch', porchGnomon.shaft, (g) {
        g.vault.shadow['gn_porch'] = EclipseLeaf.pall;
      });
      await shoot('porch_shadow_on_gallery', 'pall_porch', porchGnomon.shaft, (
        g,
      ) {
        g.vault.shadow['gn_porch'] = EclipseLeaf.gallery;
      });

      // THE COURT: nothing seated; two seated, with the available ones ringed.
      final dial = layout.rooms['analemma_court']!.eclipse!.analemma!;
      await shoot(
        'court_bare',
        'analemma_court',
        dial + const Offset(0, 90),
        (g) {},
      );
      await shoot(
        'court_two_seated',
        'analemma_court',
        dial + const Offset(0, 90),
        (g) {
          g.vault.stonesSeated.addAll(['stone_pall', 'stone_gallery']);
        },
      );

      // THE RING: rusted; eaten clean; a hole that is actually through.
      final anCourt = vaultAnchorById('an_court')!;
      await shoot(
        'ring_rusted',
        'ossuary_ring',
        const Offset(400, 400),
        (g) {},
      );
      await shoot('ring_clean', 'ossuary_ring', const Offset(400, 400), (g) {
        g.vault.anchorsOpen.add(anCourt.id);
        g.vault.shadow['gn_porch'] = EclipseLeaf.gallery; // the far end lit
      });
      await shoot('ring_through', 'ossuary_ring', const Offset(400, 400), (g) {
        g.vault.anchorsOpen.add(anCourt.id);
        // pall dark (porch gnomon), ossuary dark (walk gnomon): both ends.
        g.vault.shadow['gn_porch'] = EclipseLeaf.pall;
        g.vault.shadow['gn_walk'] = EclipseLeaf.ossuary;
      });

      // THE NAVE: lamps lit, and put out.
      await shoot(
        'nave_lamps_lit',
        'eclipse_nave',
        const Offset(400, 400),
        (g) {},
      );
      await shoot('nave_lamps_out', 'eclipse_nave', const Offset(400, 400), (
        g,
      ) {
        g.conduitEnergy['B'] = double.infinity;
      });

      // THE ABYSS: a hole in the dark; a well with a bottom in the light; the
      // chain read and freed; the finger hauled halfway; standing.
      final well = layout.rooms['abyssal_font']!.eclipse!.abyss!;
      final stand = well + const Offset(0, 110);
      await shoot('abyss_dark', 'abyssal_font', stand, (g) {
        g.vault.shadow['gn_stair'] = EclipseLeaf.deep;
      });
      await shoot('abyss_lit', 'abyssal_font', stand, (g) {
        g.vault.shadow['gn_stair'] = EclipseLeaf.ossuary;
      });
      await shoot('abyss_read_and_free', 'abyssal_font', stand, (g) {
        g.vault.shadow['gn_stair'] = EclipseLeaf.ossuary;
        g.vault.abyssRead = true;
        g.vault.abyssChainFree = true;
      });
      await shoot('abyss_hauled_twice', 'abyssal_font', stand, (g) {
        g.vault.shadow['gn_stair'] = EclipseLeaf.ossuary;
        g.vault.abyssRead = true;
        g.vault.abyssChainFree = true;
        g.vault.abyssHauls = 2;
      });
      await shoot('abyss_raised', 'abyssal_font', stand, (g) {
        g.vault.shadow['gn_stair'] = EclipseLeaf.ossuary;
        g.vault.abyssRead = true;
        g.vault.abyssChainFree = true;
        g.vault.abyssHauls = EclipseVault.abyssChainLengths;
      });

      // THE ARENA: the vane holding the Deep dark, and lit.
      await shoot(
        'arena_vane_deep_dark',
        'noctryos_totality',
        const Offset(450, 400),
        (g) {
          g.vault.shadow['gn_stair'] = EclipseLeaf.deep;
        },
      );
      await shoot(
        'arena_vane_deep_lit',
        'noctryos_totality',
        const Offset(450, 400),
        (g) {
          g.vault.shadow['gn_stair'] = EclipseLeaf.ossuary;
        },
      );

      const groups = [
        ['porch_pall_hung', 'porch_shadow_on_pall', 'porch_shadow_on_gallery'],
        ['court_bare', 'court_two_seated'],
        ['ring_rusted', 'ring_clean', 'ring_through'],
        ['nave_lamps_lit', 'nave_lamps_out'],
        [
          'abyss_dark',
          'abyss_lit',
          'abyss_read_and_free',
          'abyss_hauled_twice',
          'abyss_raised',
        ],
        ['arena_vane_deep_dark', 'arena_vane_deep_lit'],
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
