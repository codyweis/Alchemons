// A FALLEN GUARDIAN'S RING. Back up out of a planet whose guardian has just
// fallen, the ring forms in front of the player: the camera goes over to the
// planet and out until the ring fits, the world holds still while it forms,
// then the camera comes back to the ship. Every other fallen guardian's
// planet simply wears its ring.
//
//   RING_OUT=/tmp/ring flutter test test/cleared_ring_shot_test.dart
//
// also writes the shot as frames, ring_<n>.png, to judge it.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _w = 915, _h = 412;

void main() {
  final outDir = Platform.environment['RING_OUT'];

  Future<CosmicGame> boot({Set<String> fallen = const {}}) async {
    final game = CosmicGame(
      world_: CosmicWorld.generate(seed: 1),
      onMeterChanged: () {},
      fallenGuardians: fallen,
    );
    await game.onLoad();
    game.onGameResize(Vector2(_w, _h));
    for (final p in game.world_.planets) {
      p.discovered = true;
    }
    return game;
  }

  PlanetComponent comp(CosmicGame game, String element) =>
      game.planetComps.firstWhere((pc) => pc.planet.element == element);

  Offset cameraCentre(CosmicGame game) => Offset(
    game.camX + _w / (2 * game.cameraZoom),
    game.camY + _h / (2 * game.cameraZoom),
  );

  void run(CosmicGame game, double seconds) {
    for (var i = 0; i < (seconds * 30).round(); i++) {
      game.update(1 / 30);
    }
  }

  testWidgets('a planet whose guardian fell before wears its ring', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final game = await boot(fallen: {'Fire', 'Dust'});
      expect(comp(game, 'Fire').cleared, isNotNull);
      expect(comp(game, 'Dust').cleared, isNotNull);
      expect(comp(game, 'Water').cleared, isNull);
      // Already there: nothing forms, and the camera stays on the ship.
      expect(comp(game, 'Fire').formingFrom, isNull);
      final zoom = game.cameraZoom;
      run(game, 1);
      expect(game.cameraZoom, zoom);
    });
  });

  testWidgets('the guardian that just fell has its ring form in shot', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final game = await boot();
      final fire = comp(game, 'Fire');
      // Where the ship comes back up: just off the planet.
      final start = fire.planet.position + Offset(fire.planet.radius * 2, 0);
      game.teleportTo(start);
      final zoom = game.cameraZoom;

      game.syncFallenGuardians({'Fire'}, justFell: 'Fire');
      expect(fire.cleared, isNotNull);
      expect(fire.formingFrom, isNotNull);

      var frame = 0;
      Future<void> shoot() async {
        if (outDir == null) return;
        Directory(outDir).createSync(recursive: true);
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, _w, _h),
          Paint()..color = const Color(0xFF020010),
        );
        game.render(canvas);
        final pic = rec.endRecording();
        final img = pic.toImageSync(_w.round(), _h.round());
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$outDir/ring_${(frame++).toString().padLeft(2, '0')}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        img.dispose();
        pic.dispose();
      }

      // The hold: the camera comes round to the planet, the world (the
      // ship with it) holds still, and the ring has room to be seen.
      for (var i = 0; i < 8; i++) {
        run(game, 0.5);
        await shoot();
        expect(game.ship.pos, start, reason: 'held still at ${i / 2 + 0.5}s');
      }
      expect(
        (cameraCentre(game) - fire.planet.position).distance,
        lessThan(fire.planet.radius * 0.1),
        reason: 'framed on the planet',
      );
      final ringWidth = 2 * fire.cleared!.reach * fire.planet.radius;
      expect(ringWidth * game.cameraZoom, lessThanOrEqualTo(_w));

      // Then it lets go: back on the ship, at the player's own zoom.
      for (var i = 0; i < 6; i++) {
        run(game, 0.5);
        await shoot();
      }
      expect(game.cameraZoom, closeTo(zoom, 1e-9));
      expect((cameraCentre(game) - game.ship.pos).distance, lessThan(1e-6));
    });
  });

  testWidgets('a wiped planet loses its ring', (tester) async {
    await tester.runAsync(() async {
      final game = await boot(fallen: {'Fire'});
      game.syncFallenGuardians(const {});
      expect(comp(game, 'Fire').cleared, isNull);
    });
  });
}
