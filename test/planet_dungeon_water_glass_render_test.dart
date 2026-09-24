// THE MIRROR-TIDE TEMPLE, IN GLASS — the states Water's glass is meant to show
// (docs/dungeons.md §7.11), asserted to be different pictures.
//
// The rooms whole are `planet_dungeon_whole_room_audit_test.dart
// --dart-define=AUDIT=Water`; this is the STATES. The Frozen Moon is shot from
// a game where only the maxim's id is set — a found maxim's mark must stand on
// every later descent.
//
// `mkdir -p build/room_audit` and run this to get the PNGs (WaterGlass_*.png).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String roomId, {int stars = 0}) async {
  const els = ['Water', 'Ice', 'Spirit'];
  const fams = ['pip', 'mane', 'mask'];
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
    element: 'Water',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  g.starMask = stars; // applied in onLoad, which a headless game never runs
  final b = kPlanetDungeonLayouts['Water']!.rooms[roomId]!.bounds;
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

  testWidgets('every state the temple\'s glass shows', (tester) async {
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
            'build/room_audit/WaterGlass_$name.png',
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

      // The offering bowl: dry, then brimming.
      await shoot(
        'gate_dry',
        'tide_gate',
        setup: (g) => g.entryDoorRevealed = false,
      );
      await shoot('gate_filled', 'tide_gate', seconds: 2.0);

      // The tide-works: every seal shut, then every seal yielded.
      await shoot('works_shut', 'tide_works');
      await shoot(
        'works_open',
        'tide_works',
        setup: (g) {
          for (final s in g.layout.rooms['tide_works']!.tideSeals) {
            g.openedSeals.add(s.id);
          }
        },
      );

      // The reflection court: plain; the moon freezing as the rite binds;
      // and the Frozen Moon on a later descent (the id alone).
      await shoot('court', 'reflection_court');
      await shoot(
        'court_freezing',
        'reflection_court',
        setup: (g) =>
            g.beginMaximRite(kWaterFrozenMoonEggId, const Offset(320, 330)),
        seconds: 1.2,
      );
      await shoot(
        'court_frozen',
        'reflection_court',
        setup: (g) => g.discoveredClouds.add(kWaterFrozenMoonEggId),
      );

      await shoot('gallery', 'ghost_gallery');
      await shoot('mural', 'moon_hall');
      await shoot('hub_two_stars', 'drowned_court', stars: 0x3);

      for (final (a, b) in const [
        ('gate_dry', 'gate_filled'),
        ('works_shut', 'works_open'),
        ('court', 'court_freezing'),
        ('court_freezing', 'court_frozen'),
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
