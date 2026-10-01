@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/widgets/fx/power_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The four power orbs at the sizes they are drawn — inventory, shop, the
// Enhance tray, and big — at three moments, dimmed, plus a frame's cost.
//
//   ORB_OUT=/tmp/orbs.png flutter test \
//     test/power_orb_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['ORB_OUT'];

  testWidgets('power orb sheet', (tester) async {
    if (out == null) return;
    const sizes = [40.0, 56.0, 68.0, 150.0];
    const times = [0.0, 0.9, 2.3];
    const cell = 170.0;
    const types = AlchemicalPowerupType.values;
    final cols = sizes.length * times.length + 1;
    final w = cell * cols;
    final h = cell * types.length;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF0B0D12),
    );
    for (var k = 0; k < types.length; k++) {
      for (var ti = 0; ti < times.length; ti++) {
        for (var s = 0; s < sizes.length; s++) {
          final col = ti * sizes.length + s;
          PowerOrbPaint.paint(
            c,
            Offset(cell * col + cell / 2, cell * k + cell / 2),
            sizes[s] * 0.34,
            types[k],
            times[ti] + k * 1.7,
          );
        }
      }
      // Dimmed: cannot be used.
      PowerOrbPaint.paint(
        c,
        Offset(cell * (cols - 1) + cell / 2, cell * k + cell / 2),
        68 * 0.34,
        types[k],
        1,
        lit: 0.35,
      );
    }
    final image = rec.endRecording().toImageSync(w.toInt(), h.toInt());
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    final sw = Stopwatch()..start();
    for (var i = 0; i < 600; i++) {
      final r = ui.PictureRecorder();
      PowerOrbPaint.paint(
        Canvas(r),
        const Offset(34, 34),
        23,
        types[i % 4],
        i / 60,
      );
      r.endRecording().dispose();
    }
    // ignore: avoid_print
    print(
      'power orb: ${(sw.elapsedMicroseconds / 600).toStringAsFixed(1)} µs '
      'per orb per frame (JIT)',
    );
  });
}
