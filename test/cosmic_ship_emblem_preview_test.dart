@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:alchemons/widgets/cosmic_ship_emblem.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The cosmic ship emblem: every hull flying its figure of eight, shot
// through the loop at the icon's size (×3, the phone's density), and the
// passage into space and back, frame by frame over a stand-in of space with
// the real hull where the cosmic screen puts it.
//
//   SHIPEMBLEM_OUT=/tmp/ship flutter test \
//     test/cosmic_ship_emblem_preview_test.dart --tags preview
//
// Writes icons.png and passage.png.
void main() {
  final out = Platform.environment['SHIPEMBLEM_OUT'];
  const skins = <String?>[
    null,
    'skin_phantom',
    'skin_solar',
    'skin_inferno',
    'skin_crystal',
  ];

  Future<void> save(ui.Image image, String name) async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  testWidgets('cosmic ship emblem icons', (tester) async {
    if (out == null) return;
    final grains = <String?, ShipGrains>{};
    await tester.runAsync(() async {
      for (final s in skins) {
        grains[s] = await ShipGrains.of(s);
      }
    });
    const icon = 75.0, dpr = 3.0, cols = 6;
    const cell = icon + 20;
    final w = (cell * cols + 20) * dpr, h = (cell * skins.length + 20) * dpr;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF0B0A0E),
    );
    c.scale(dpr);
    for (var r = 0; r < skins.length; r++) {
      for (var k = 0; k < cols; k++) {
        final box = Rect.fromLTWH(20 + k * cell, 20 + r * cell, icon, icon);
        paintCosmicShipIcon(c, box, 0.4 + k * 1.5, grains[skins[r]], skins[r]);
      }
    }
    final image = rec.endRecording().toImageSync(w.round(), h.round());
    await tester.runAsync(() => save(image, 'icons.png'));
  });

  testWidgets('cosmic ship passage', (tester) async {
    if (out == null) return;
    const skin = 'skin_solar';
    await tester.runAsync(() => ShipGrains.of(skin));
    const screen = Size(390, 844);
    const box = Rect.fromLTWH(300, 170, 75, 75);
    final target = ValueNotifier<ShipPassageTarget?>(
      const ShipPassageTarget(
        centre: Offset(195, 422),
        scale: 0.72,
        heading: 0,
      ),
    );
    CosmicShipEmblem.skin.value = skin;
    final scene = CosmicShipPassage(target: target);

    // The route's own timings, as the passage veil drives them.
    final inward = scene.inward.inMilliseconds / 1000;
    final landing = scene.landing.inMilliseconds / 1000;
    final outward = scene.outward.inMilliseconds / 1000;
    const hold = 0.6;
    final shots = <double>[
      0.12,
      0.3,
      0.5,
      0.75,
      1.0,
      1.3,
      1.75,
      2.0,
      2.2,
      2.45,
      2.8,
    ];
    final backShots = <double>[0.1, 0.3, 0.5, 0.7, 0.9, 1.05];
    const dpr = 1.0;
    final cols = shots.length + backShots.length;
    const thumb = 0.5;
    final cw = screen.width * thumb + 8;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final W = (cw * cols + 8) * dpr, H = (screen.height * thumb + 16) * dpr;
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = Colors.black);

    void frame(int col, EmblemStage s, double pageShown) {
      canvas.save();
      canvas.translate(8 + col * cw, 8);
      canvas.scale(thumb);
      canvas.clipRect(Offset.zero & screen);
      // Home under it all: a dark ground with the icon's box marked faintly.
      canvas.drawRect(
        Offset.zero & screen,
        Paint()..color = const Color(0xFF15161C),
      );
      scene.paint(canvas, s, back: true, front: false);
      if (pageShown > 0) {
        // Space, as the cosmic screen opens on it: dark, a few stars, the
        // real hull at the middle at the camera's zoom.
        canvas.saveLayer(
          Offset.zero & screen,
          Paint()..color = Color.fromRGBO(0, 0, 0, pageShown),
        );
        canvas.drawRect(
          Offset.zero & screen,
          Paint()..color = const Color(0xFF020010),
        );
        final rng = math.Random(2);
        for (var i = 0; i < 90; i++) {
          canvas.drawCircle(
            Offset(
              rng.nextDouble() * screen.width,
              rng.nextDouble() * screen.height,
            ),
            0.8,
            Paint()..color = const Color(0x99C8D0F0),
          );
        }
        canvas.save();
        canvas.translate(195, 422);
        canvas.scale(0.72);
        paintShipHull(canvas, skin, s.time);
        canvas.restore();
        canvas.restore();
      }
      scene.paint(canvas, s, back: false, front: true);
      canvas.restore();
    }

    // In: grow, hold, land; stepping every frame so the wake and the
    // stars run as they would.
    var col = 0;
    const dt = 1 / 60;
    final end = inward + hold + landing;
    var next = 0;
    for (var t = 0.0; t <= end + 1e-6 && next < shots.length; t += dt) {
      final open = (t / inward).clamp(0.0, 1.0);
      final land = ((t - inward - hold) / landing).clamp(0.0, 1.0);
      final s = EmblemStage(
        box: box,
        screen: screen,
        time: 10 + t,
        open: open,
        land: land,
      );
      if (t + dt / 2 >= shots[next]) {
        frame(col++, s, scene.pageShown(land));
        next++;
      } else {
        scene.paint(Canvas(ui.PictureRecorder()), s, back: false, front: true);
      }
    }
    // Back: space clears, then the flight home.
    next = 0;
    final split = scene.backSplit;
    for (var t = 0.0; t <= outward + 1e-6 && next < backShots.length; t += dt) {
      final v = 1 - t / outward;
      final open = (v / split).clamp(0.0, 1.0);
      final land = ((v - split) / (1 - split)).clamp(0.0, 1.0);
      final s = EmblemStage(
        box: box,
        screen: screen,
        time: 40 + t,
        open: open,
        land: land,
        closing: true,
      );
      if (t + dt / 2 >= backShots[next]) {
        frame(col++, s, scene.pageShown(land));
        next++;
      } else {
        scene.paint(Canvas(ui.PictureRecorder()), s, back: false, front: true);
      }
    }
    final image = rec.endRecording().toImageSync(W.round(), H.round());
    await tester.runAsync(() => save(image, 'passage.png'));
  });
}
