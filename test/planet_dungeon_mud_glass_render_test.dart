// PALUSIA, IN GLASS — the states Mud's glass is meant to show
// (docs/dungeons.md §7.11), asserted to be different pictures.
//
// The rooms whole are `planet_dungeon_whole_room_audit_test.dart
// --dart-define=AUDIT=Mud`; this is the STATES. The lotus is shot from a game
// where only the maxim's id is set — a found maxim's mark must stand on
// every later descent.
//
// `mkdir -p build/room_audit` and run this to get the PNGs (MudGlass_*.png).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_mud.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String roomId, {int stars = 0}) async {
  const els = ['Mud', 'Water', 'Plant'];
  const fams = ['mane', 'mask', 'horn'];
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
    element: 'Mud',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  g.starMask = stars; // applied in onLoad, which a headless game never runs
  final b = kPlanetDungeonLayouts['Mud']!.rooms[roomId]!.bounds;
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

  testWidgets('every state the fen\'s glass shows', (tester) async {
    await tester.runAsync(() async {
      final out = Directory('build/room_audit');
      final shots = <String, int>{};

      Future<void> shoot(
        String name,
        String roomId, {
        int stars = 0,
        void Function(PlanetDungeonGame g)? setup,
        void Function(PlanetDungeonGame g)? midway,
        double seconds = 0.4,
      }) async {
        final g = await _game(roomId, stars: stars);
        setup?.call(g);
        final frames = (seconds * 60).round();
        for (var i = 0; i < frames; i++) {
          if (i == frames ~/ 2) midway?.call(g);
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
            'build/room_audit/MudGlass_$name.png',
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

      await shoot('knoll', 'reed_knoll');
      await shoot('gate', 'mire_gate');

      // A crossing's glass: dragged to sod (clear), caught mid-drag (the
      // panes setting from the head outward), and its neighbour drowned.
      await shoot(
        'gate_sod',
        'mire_gate',
        setup: (g) => g.bog.field.hardened.add('cor_head'),
      );
      await shoot(
        'gate_setting',
        'mire_gate',
        midway: (g) => g.bog.field.hardened.add('cor_head'),
        seconds: 1.2,
      );
      await shoot(
        'knoll_drowned',
        'reed_knoll',
        setup: (g) => g.bog.field.hardened.add('cor_head'),
      );

      // The drowned fane: the pit; the lotus opening as the rite binds; and
      // the lotus on a later descent (the id alone).
      await shoot('fane', 'drowned_fane');
      await shoot(
        'fane_opening',
        'drowned_fane',
        setup: (g) {
          final pit = g.layout.rooms['drowned_fane']!.fen!.sinkPit!;
          g.beginMaximRite(kMudLotusEggId, pit);
        },
        seconds: 1.4,
      );
      await shoot(
        'fane_lotus',
        'drowned_fane',
        setup: (g) => g.discoveredClouds.add(kMudLotusEggId),
      );

      for (final (a, b) in const [
        ('gate', 'gate_sod'),
        ('gate_sod', 'gate_setting'),
        ('knoll', 'knoll_drowned'),
        ('fane', 'fane_opening'),
        ('fane_opening', 'fane_lotus'),
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
