@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/element_ground_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The element ground effects as the game draws them
// (lib/games/cosmic/element_ground_art.dart), enlarged three times: each
// element at a small zone (radius 45) and a large one (radius 85).
//
//   GROUND_ART_OUT=/tmp/ground_art.png [GROUND_ART_T=1.3] flutter test \
//     test/element_ground_art_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['GROUND_ART_OUT'];

  testWidgets('element ground art lineup', (tester) async {
    if (out == null) return;
    final time =
        double.tryParse(Platform.environment['GROUND_ART_T'] ?? '') ?? 1.3;
    const zoom = 3.0, cols = 6;
    const cell = Size(330, 230);
    final elements = kElementGrounds.toList();
    final rows = (elements.length / cols).ceil();
    final size = Size(cell.width * cols, cell.height * rows);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.scale(zoom);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF18242A),
    );
    for (var i = 0; i < elements.length; i++) {
      final ox = (i % cols) * cell.width, oy = (i ~/ cols) * cell.height;
      for (final (dx, r) in [(70.0, 45.0), (220.0, 85.0)]) {
        canvas.save();
        canvas.translate(ox + dx, oy + cell.height * 0.6);
        paintElementGround(canvas, elements[i], r, time, i * 1.37 + r);
        canvas.restore();
      }
    }
    final img = rec.endRecording().toImageSync(
      (size.width * zoom).round(),
      (size.height * zoom).round(),
    );
    await tester.runAsync(() async {
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
