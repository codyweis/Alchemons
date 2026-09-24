// THE STORM CIRCUIT, IN GLASS — the states Lightning's glass is meant to show
// (docs/dungeons.md §7.11), asserted to be different pictures.
//
// The rooms whole are `planet_dungeon_whole_room_audit_test.dart
// --dart-define=AUDIT=Lightning`; this is the STATES. The Thunderbolt is shot
// from a game where only the maxim's id is set — a found maxim's mark must stand on
// every later descent.
//
// `mkdir -p build/room_audit` and run this to get the PNGs (LightningGlass_*.png).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String roomId, {int stars = 0}) async {
  const els = ['Lightning', 'Air', 'Fire'];
  const fams = ['horn', 'wing', 'mask'];
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
    element: 'Lightning',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  g.starMask = stars; // applied in onLoad, which a headless game never runs
  final b = kPlanetDungeonLayouts['Lightning']!.rooms[roomId]!.bounds;
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

  testWidgets('every state the circuit\'s glass shows', (tester) async {
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
            'build/room_audit/LightningGlass_$name.png',
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

      // The way in: the dead bus, then lit.
      await shoot(
        'gate_dead',
        'arc_gate',
        setup: (g) => g.entryDoorRevealed = false,
      );
      await shoot('gate_lit', 'arc_gate', seconds: 2.0);
      // The storm outside: the first flash lands at the very start of the
      // clock, so two frames in the works are lit white-blue.
      await shoot('gate_flash', 'arc_gate', seconds: 0.03);

      // The dynamo: idle, feeding a wing, and the Thunderbolt's fulgurite
      // from a later descent.
      await shoot(
        'dynamo_idle',
        'dynamo_court',
        setup: (g) => g.activeTrunk = null,
      );
      await shoot(
        'dynamo_feeding',
        'dynamo_court',
        setup: (g) => g.activeTrunk = 'trunk_pylon',
        seconds: 1.0,
      );
      await shoot(
        'dynamo_thunderbolt',
        'dynamo_court',
        setup: (g) => g.discoveredClouds.add(kLightningThunderboltEggId),
      );

      // The pylon hall, fed, with Air on the viable vent (the beam runs).
      await shoot(
        'hall',
        'pylon_hall',
        setup: (g) => g.activeTrunk = 'trunk_pylon',
      );
      await shoot(
        'hall_vent',
        'pylon_hall',
        setup: (g) {
          g.activeTrunk = 'trunk_pylon';
          final air = g.creatures.firstWhere((c) => c.member.element == 'Air');
          air.position = const Offset(150, 150);
        },
      );

      // The cloud works: a socket singing.
      await shoot('works', 'cloud_works');
      await shoot(
        'works_socket',
        'cloud_works',
        setup: (g) => g.energizedSockets.add('sock_a'),
      );

      for (final (a, b) in const [
        ('gate_dead', 'gate_lit'),
        ('gate_flash', 'gate_lit'),
        ('dynamo_idle', 'dynamo_feeding'),
        ('dynamo_feeding', 'dynamo_thunderbolt'),
        ('hall', 'hall_vent'),
        ('works', 'works_socket'),
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
