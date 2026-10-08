@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/planets/planet_art.dart';
import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:alchemons/screens/cosmic/widgets/planet_descent_passage.dart';
import 'package:alchemons/widgets/cosmic_ship_emblem.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The way down into a planet and back up, frame by frame, over a stand-in
// of space (the planet where it hangs, the real hull at the middle) and of
// the dungeon's first room.
//
//   DESCENT_OUT=/tmp/descent [DESCENT_ELEMENT=Fire] flutter test \
//     test/planet_descent_preview_test.dart --tags preview
//
// Writes descent.png (down, then up) and frame_<n>.png.
void main() {
  final out = Platform.environment['DESCENT_OUT'];
  final element = Platform.environment['DESCENT_ELEMENT'] ?? 'Fire';

  testWidgets('planet descent passage', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const skin = 'skin_inferno';
    await tester.runAsync(() => ShipGrains.of(skin));
    const screen = Size(390, 844);
    final art = PlanetArt.of(element, 7);
    final color = elementColor(element);
    const zoom = 0.72;
    // The ship in the planet's orbit, the planet up and to the left of it.
    const shipAt = Offset(195, 422);
    final planetAt = Rect.fromCircle(
      center: const Offset(195 - 170, 422 - 210),
      radius: 210 * zoom,
    );
    final ship = ShipPose(shipAt, zoom, 0.9);
    final scene = PlanetDescentPassage(
      art: art,
      color: color,
      planet: planetAt,
      ship: ship,
      skin: skin,
      planetTime: 12,
      title: 'Pyrathis Forge',
    );

    final inward = scene.inward.inMilliseconds / 1000;
    final landing = scene.landing.inMilliseconds / 1000;
    final outward = scene.outward.inMilliseconds / 1000;
    const hold = 0.6;
    final down = <double>[0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.25, 1.6, 2.0, 2.3,
      2.8];
    final up = <double>[0.15, 0.35, 0.55, 0.75, 0.95, 1.15, 1.25];
    const thumb = 0.5;
    final cw = screen.width * thumb + 6;
    final cols = down.length + up.length;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cw * cols + 6, screen.height * thumb + 12),
      Paint()..color = Colors.black,
    );

    void space(Canvas c, double t) {
      c.drawRect(Offset.zero & screen, Paint()..color = const Color(0xFF020010));
      final rng = math.Random(4);
      for (var i = 0; i < 120; i++) {
        c.drawCircle(
          Offset(rng.nextDouble() * screen.width,
              rng.nextDouble() * screen.height),
          0.7,
          Paint()..color = const Color(0x88C8D0F0),
        );
      }
      art.paintBack(c, planetAt.center, planetAt.width / 2, 12);
      art.paintBody(c, planetAt.center, planetAt.width / 2, 12);
      art.paintFront(c, planetAt.center, planetAt.width / 2, 12);
    }

    void room(Canvas c, double alpha) {
      c.saveLayer(Offset.zero & screen,
          Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
      c.drawRect(Offset.zero & screen, Paint()..color = const Color(0xFF15110E));
      c.drawRect(
        const Rect.fromLTWH(40, 160, 310, 420),
        Paint()..color = const Color(0xFF2A221C),
      );
      for (var i = 0; i < 3; i++) {
        c.drawCircle(
          Offset(150 + i * 45.0, 470),
          14,
          Paint()..color = Color.lerp(color, Colors.white, 0.3)!,
        );
      }
      c.restore();
    }

    var col = 0;
    Future<void> frame(EmblemStage s, {required bool spaceUnder}) async {
      final r = ui.PictureRecorder();
      final c = Canvas(r);
      if (spaceUnder) space(c, s.time);
      scene.paint(c, s, back: true, front: false);
      final shown = scene.pageShown(s.land);
      if (shown > 0) room(c, shown);
      scene.paint(c, s, back: false, front: true);
      final img = r.endRecording().toImageSync(
        screen.width.round(),
        screen.height.round(),
      );
      canvas.save();
      canvas.translate(6 + col * cw, 6);
      canvas.scale(thumb);
      canvas.drawImage(img, Offset.zero, Paint());
      canvas.restore();
      await tester.runAsync(() async {
        final b = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/frame_$col.png').writeAsBytesSync(b!.buffer.asUint8List());
      });
      col++;
    }

    const dt = 1 / 60;
    var next = 0;
    for (var t = 0.0; next < down.length; t += dt) {
      final s = EmblemStage(
        box: planetAt,
        screen: screen,
        time: 30 + t,
        open: (t / inward).clamp(0.0, 1.0),
        land: ((t - inward - hold) / landing).clamp(0.0, 1.0),
      );
      if (t + dt / 2 >= down[next]) {
        await frame(s, spaceUnder: s.open < 0.75);
        next++;
      } else {
        scene.paint(Canvas(ui.PictureRecorder()), s, back: false, front: true);
      }
    }
    next = 0;
    final split = scene.backSplit;
    for (var t = 0.0; next < up.length; t += dt) {
      final v = (1 - t / outward).clamp(0.0, 1.0);
      final s = EmblemStage(
        box: planetAt,
        screen: screen,
        time: 60 + t,
        open: (v / split).clamp(0.0, 1.0),
        land: ((v - split) / (1 - split)).clamp(0.0, 1.0),
        closing: true,
      );
      if (t + dt / 2 >= up[next]) {
        await frame(s, spaceUnder: s.open < 0.75);
        next++;
      } else {
        scene.paint(Canvas(ui.PictureRecorder()), s, back: false, front: true);
      }
    }
    // The real hull where the passage hands back, for the last frame.
    paintShipHull(Canvas(ui.PictureRecorder()), skin, 0);
    final img = rec.endRecording().toImageSync(
      (cw * cols + 6).round(),
      (screen.height * thumb + 12).round(),
    );
    await tester.runAsync(() async {
      final b = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/descent.png').writeAsBytesSync(b!.buffer.asUint8List());
    });
  });
}
