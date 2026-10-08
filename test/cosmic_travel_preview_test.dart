@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A star chart flight, frame by frame: the ship swinging round and pulling
// away, crossing under the dark, and gliding into the planet's orbit.
//
//   TRAVEL_OUT=/tmp/travel flutter test \
//     test/cosmic_travel_preview_test.dart --tags preview
//
// Writes travel.png (a strip of frames) and frame_<n>.png for each.
void main() {
  final out = Platform.environment['TRAVEL_OUT'];
  const w = 390.0, h = 844.0;

  testWidgets('cosmic chart travel', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final game = CosmicGame(
      world_: CosmicWorld.generate(seed: 1),
      onMeterChanged: () {},
    );
    await game.onLoad();
    game.onGameResize(Vector2(w, h));
    for (final p in game.world_.planets) {
      p.discovered = true;
    }
    final planet = game.world_.planets[2];
    // Somewhere well away from it, heading off at an angle to it.
    game.teleportTo(
      Offset(
        (planet.position.dx + 9000) % game.world_.worldSize.width,
        (planet.position.dy + 5000) % game.world_.worldSize.height,
      ),
    );
    game.ship.angle = 0.6;
    for (var i = 0; i < 40; i++) {
      game.update(1 / 60);
    }
    game.travelTo(planet.position, orbitRadius: planet.radius * 2.0);

    final shots = [0.0, 0.25, 0.5, 0.7, 0.86, 0.98, 1.2, 1.45, 1.75, 2.2, 2.6];
    const dpr = 1.0, thumb = 0.5;
    final strip = ui.PictureRecorder();
    final sc = Canvas(strip);
    final cw = w * thumb + 6;
    sc.drawRect(
      Rect.fromLTWH(0, 0, cw * shots.length + 6, h * thumb + 12),
      Paint()..color = Colors.black,
    );
    var t = 0.0, k = 0;
    while (k < shots.length) {
      if (t + 1e-6 >= shots[k]) {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(
          const Rect.fromLTWH(0, 0, w, h),
          Paint()..color = const Color(0xFF020010),
        );
        game.render(c);
        final pic = rec.endRecording();
        final img = pic.toImageSync((w * dpr).round(), (h * dpr).round());
        sc.save();
        sc.translate(6 + k * cw, 6);
        sc.scale(thumb);
        sc.drawImage(img, Offset.zero, Paint());
        sc.restore();
        await tester.runAsync(() async {
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/frame_$k.png').writeAsBytesSync(
            bytes!.buffer.asUint8List(),
          );
        });
        k++;
        continue;
      }
      game.update(1 / 60);
      t += 1 / 60;
    }
    expect(game.isTravelling, isFalse);
    final img = strip.endRecording().toImageSync(
      (cw * shots.length + 6).round(),
      (h * thumb + 12).round(),
    );
    await tester.runAsync(() async {
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/travel.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
