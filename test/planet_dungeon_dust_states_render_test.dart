// SABLIS, RENDERED — the states, not just the rooms.
//
// `dungeon_room_render_test.dart` draws every room in its OPENING state,
// which for Dust is the least interesting frame of each: every mound buried,
// the yard as authored, the observatory's roof on, the granary's pits dark.
// Everything this planet is ABOUT is a change of load count, and a state that
// draws the same as its neighbour is a state the player cannot read.
//
// So this renders the states side by side and asserts they are actually
// different pictures (Mud's lesson — a checksum over a change nobody can see
// passed happily while the screen said nothing). With `build/room_audit`
// present it writes the PNGs too.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dust.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanetDungeonGame _game() {
  final els = kCosmicPlanetEntry['Dust']!;
  const fams = ['mask', 'wing', 'horn'];
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
    element: 'Dust',
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

  testWidgets('every state of the buried city draws its own picture', (
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
            ..lastSafe = stand
            ..angle = 0
            ..aimAngle = 0;
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
            'build/room_audit/DustState_$name.png',
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

      final layout = kPlanetDungeonLayouts['Dust']!;

      // THE GATE: silted, open, and the vane wound.
      const gateStand = Offset(360, 300);
      await shoot('gate_silted', 'ashen_gate', gateStand, (g) {
        g.entryDoorRevealed = false;
      });
      await shoot('gate_open', 'ashen_gate', gateStand, (g) {});
      await shoot('gate_vane_armed', 'ashen_gate', gateStand, (g) {
        g.ruins.armedVaneRoom = 'ashen_gate';
        g.ruins.armedVaneTimer = 4;
      });

      // THE ROOF WALK: two mounds, in the three heights a mound can have.
      const walkStand = Offset(420, 420);
      await shoot('walk_buried', 'roof_walk', walkStand, (g) {});
      await shoot('walk_roof_bared_bump_heaped', 'roof_walk', walkStand, (g) {
        g.ruins.dig('m_roof', 'm_bump');
      });
      await shoot('walk_roof_heaped', 'roof_walk', walkStand, (g) {
        g.ruins.dig('m_agora', 'm_roof');
      });

      // THE YARD: as authored (with the press preview under a body standing
      // on it), and with the boxed west seal scraped bare.
      const g0 = kSealYard;
      await shoot('yard_opening', 'seal_street', g0.centerAt(2, 1), (g) {});
      await shoot('yard_west_seal_bare', 'seal_street', g0.centerAt(2, 1), (g) {
        // The west seal's load blown east onto the cell beside the pillar.
        g.ruins.drift[1 * g0.cols + 0] = 0;
        g.ruins.drift[1 * g0.cols + 2] = 2;
      });

      // THE OBSERVATORY: roof on, roof off.
      const obsStand = Offset(150, 300);
      await shoot('observatory_roof_on', 'observatory', obsStand, (g) {});
      await shoot('observatory_roof_off', 'observatory', obsStand, (g) {
        g.ruins.dig('m_roof', 'm_agora');
      });

      // THE GRANARY: the count unread, one pit answering, five answering.
      const granaryStand = Offset(230, 120);
      await shoot('granary_unread', 'granary', granaryStand, (g) {});
      await shoot('granary_one_lit', 'granary', granaryStand, (g) {
        g.ruins.tallyLit.add('m_gate');
      });
      await shoot('granary_all_lit', 'granary', granaryStand, (g) {
        g.ruins.dig('m_kiln', 'm_bump');
        g.ruins.dig('m_agora', 'm_roof');
        g.ruins.tallyLit.addAll(kDustTally.keys);
      });

      // THE HOLLOW: the cut open, and the storm's spoil in it.
      const hollowStand = Offset(450, 300);
      await shoot('hollow_open', 'ashdjinn_hollow', hollowStand, (g) {
        g.guardianAwake = true;
      });
      await shoot('hollow_buried', 'ashdjinn_hollow', hollowStand, (g) {
        g.guardianAwake = true;
        g.ruins.buryHollow();
        g.ruins.buryHollow();
      });

      expect(layout.rooms['granary']!.ruins!.tallyPits, hasLength(5));

      // Every pair inside a room must be a different picture.
      const groups = [
        ['gate_silted', 'gate_open', 'gate_vane_armed'],
        ['walk_buried', 'walk_roof_bared_bump_heaped', 'walk_roof_heaped'],
        ['yard_opening', 'yard_west_seal_bare'],
        ['observatory_roof_on', 'observatory_roof_off'],
        ['granary_unread', 'granary_one_lit', 'granary_all_lit'],
        ['hollow_open', 'hollow_buried'],
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
