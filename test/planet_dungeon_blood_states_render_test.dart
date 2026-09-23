// HEMAVORN, RENDERED — the states, not just the rooms.
//
// Everything this planet is ABOUT is what time it is, so this renders the
// same chambers across the beat and the fixtures across their states, and
// asserts they are actually different pictures (Mud's lesson). With
// `build/room_audit` present it writes the PNGs too.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_blood.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanetDungeonGame _game() {
  final els = kCosmicPlanetEntry['Blood']!;
  const fams = ['mane', 'mask', 'mask'];
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
    element: 'Blood',
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

  testWidgets('every state of the orrery draws its own picture', (
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
        // Hold the clock: the shots are of PHASES, so the frames run but the
        // beat is pinned where the setup put it.
        final clock = g.heart.clock;
        for (var i = 0; i < 24; i++) {
          g.update(1 / 60);
          g.heart.clock = clock;
          g.heart.phase = pulsePhaseAt(clock);
        }
        final rec = ui.PictureRecorder();
        g.render(Canvas(rec));
        final img = await rec.endRecording().toImage(900, 600);
        if (out.existsSync()) {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            'build/room_audit/BloodState_$name.png',
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

      void at(PlanetDungeonGame g, PulsePhase p) {
        g.heart.clock = pulsePhaseStart(p) + 0.5;
        g.heart.phase = p;
      }

      final layout = kPlanetDungeonLayouts['Blood']!;

      // THE GATE across the beat: the mouth shut, dilated on its phase, primed.
      const gateStand = Offset(150, 300);
      await shoot('gate_flatline', 'pericard_gate', gateStand, (g) {
        at(g, PulsePhase.flatline);
      });
      await shoot('gate_systole_mouth_open', 'pericard_gate', gateStand, (g) {
        at(g, PulsePhase.systole);
      });
      await shoot('gate_mouth_primed', 'pericard_gate', gateStand, (g) {
        at(g, PulsePhase.diastole);
        g.heart.ostiaPrimed.add('os_gate');
      });

      // THE ARCH: two cocks shut; one flagged sound and one flagged dead; the
      // dead one turned and its clot shown, on the pause.
      const archStand = Offset(390, 150);
      await shoot('arch_cocks_shut', 'aortic_arch', archStand, (g) {
        at(g, PulsePhase.diastole);
      });
      await shoot('arch_cocks_flagged', 'aortic_arch', archStand, (g) {
        at(g, PulsePhase.diastole);
        g.heart.soundCollaterals
          ..clear()
          ..addAll(['co_diagonal', 'co_shortcut', 'co_bypass']);
        g.heart.flagged.addAll(['co_diagonal', 'co_shunt']);
      });
      await shoot('arch_thrombus_shown_pause', 'aortic_arch', archStand, (g) {
        at(g, PulsePhase.flatline);
        g.heart.soundCollaterals
          ..clear()
          ..addAll(['co_diagonal', 'co_shortcut', 'co_bypass']);
        g.heart.cocksTurned.add('co_shunt');
        g.heart.clotSeen.add('co_shunt');
      });
      await shoot('arch_both_carrying', 'aortic_arch', archStand, (g) {
        at(g, PulsePhase.diastole);
        g.heart.soundCollaterals
          ..clear()
          ..addAll(['co_diagonal', 'co_shortcut', 'co_bypass']);
        g.heart.cocksTurned.addAll(['co_diagonal', 'co_shunt']);
        g.heart.grafted.addAll(['co_diagonal', 'co_shunt']);
      });

      // THE MYOCARDIUM: the balance tilted, and level.
      const heartStand = Offset(410, 400);
      await shoot('myocardium_tilted', 'myocardium', heartStand, (g) {
        at(g, PulsePhase.systole);
      });
      await shoot('myocardium_level', 'myocardium', heartStand, (g) {
        at(g, PulsePhase.systole);
        g.conduitEnergy['B'] = double.infinity;
      });

      // THE ARENA: the node ready, and spent.
      const arenaStand = Offset(450, 400);
      await shoot('arena_node_ready', 'sanguorath_systole', arenaStand, (g) {
        at(g, PulsePhase.systole);
        g.guardianAwake = true;
      });
      await shoot('arena_node_spent', 'sanguorath_systole', arenaStand, (g) {
        at(g, PulsePhase.systole);
        g.guardianAwake = true;
        g.heart.vagalCooldown = 5;
      });

      expect(layout.rooms['aortic_arch']!.sanguine, isNotNull);

      const groups = [
        ['gate_flatline', 'gate_systole_mouth_open', 'gate_mouth_primed'],
        [
          'arch_cocks_shut',
          'arch_cocks_flagged',
          'arch_thrombus_shown_pause',
          'arch_both_carrying',
        ],
        ['myocardium_tilted', 'myocardium_level'],
        ['arena_node_ready', 'arena_node_spent'],
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
