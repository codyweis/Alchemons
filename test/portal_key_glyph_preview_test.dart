@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/widgets/portal_key_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The five rift keys at the sizes they are drawn — inventory row, shop card,
// space market, the rift threshold, and big — at three moments, plus what a
// frame costs.
//
//   KEY_OUT=/tmp/keys.png flutter test \
//     test/portal_key_glyph_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['KEY_OUT'];

  testWidgets('portal key glyph sheet', (tester) async {
    if (out == null) return;
    const sizes = [24.0, 48.0, 56.0, 120.0];
    const times = [0.0, 1.3, 2.9];
    const cell = 140.0;
    final biomes = [for (final e in ElementResources.all) e.biomeId];
    final w = cell * sizes.length * times.length;
    final h = cell * biomes.length;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF0B0D12));
    for (var b = 0; b < biomes.length; b++) {
      final color = ElementResources.byBiomeId[biomes[b]]!.color;
      for (var t = 0; t < times.length; t++) {
        for (var s = 0; s < sizes.length; s++) {
          final col = t * sizes.length + s;
          PortalKeyGlyph.paintGlyph(
            c,
            Offset(cell * col + cell / 2, cell * b + cell / 2),
            sizes[s],
            color,
            times[t],
          );
        }
      }
    }
    final image = rec.endRecording().toImageSync(w.toInt(), h.toInt());
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    final sw = Stopwatch()..start();
    for (var i = 0; i < 600; i++) {
      final r = ui.PictureRecorder();
      PortalKeyGlyph.paintGlyph(
        Canvas(r),
        const Offset(28, 28),
        56,
        const Color(0xFF4ECDC4),
        i / 60,
      );
      r.endRecording().dispose();
    }
    // ignore: avoid_print
    print(
      'portal key: ${(sw.elapsedMicroseconds / 600).toStringAsFixed(1)} µs '
      'per glyph per frame (JIT)',
    );
  });
}
