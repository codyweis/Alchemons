@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/widgets/fx/soul_wisp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The Potential Soul at the sizes it is drawn — inventory, tray, shop, big —
// in its own violet and set to each stat, at three moments, and charged.
//
//   SOUL_OUT=/tmp/soul.png flutter test \
//     test/soul_wisp_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['SOUL_OUT'];

  testWidgets('soul wisp sheet', (tester) async {
    if (out == null) return;
    const sizes = [40.0, 62.0, 150.0];
    const times = [0.4, 1.3, 2.6];
    const cell = 170.0;
    final tints = [
      const Color(0xFFB66CFF),
      for (final t in AlchemicalPowerupType.values) t.color,
    ];
    final cols = sizes.length * times.length + 1;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(
      Rect.fromLTWH(0, 0, cell * cols, cell * tints.length),
      Paint()..color = const Color(0xFF0B0D12),
    );
    for (var k = 0; k < tints.length; k++) {
      for (var ti = 0; ti < times.length; ti++) {
        for (var s = 0; s < sizes.length; s++) {
          final col = ti * sizes.length + s;
          SoulWispPaint.paint(
            c,
            Offset(cell * col + cell / 2, cell * k + cell / 2),
            sizes[s],
            tints[k],
            times[ti],
          );
        }
      }
      SoulWispPaint.paint(
        c,
        Offset(cell * (cols - 1) + cell / 2, cell * k + cell / 2),
        120,
        tints[k],
        1.3,
        charge: 1,
      );
    }
    final image = rec.endRecording().toImageSync(
      (cell * cols).toInt(),
      (cell * tints.length).toInt(),
    );
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
