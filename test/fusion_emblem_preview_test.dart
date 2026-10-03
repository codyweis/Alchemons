@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fusion_emblem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

//   FUSION_OUT=/tmp/fusion.png flutter test \
//     test/fusion_emblem_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['FUSION_OUT'];
  testWidgets('fusion emblem sheet', (tester) async {
    if (out == null) return;
    const big = 200.0, small = 55.0, pad = 20.0;
    const times = [0.4, 1.1, 2.3, 3.6];
    final w = pad + (big + pad) * times.length;
    const h = pad * 4 + big * 2 + small * 2;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Rect.fromLTWH(0, 0, w, h / 2 + 10), Paint()..color = const Color(0xFF1B2433));
    c.drawRect(Rect.fromLTWH(0, h / 2 + 10, w, h), Paint()..color = const Color(0xFFE9E4D8));
    for (var row = 0; row < 2; row++) {
      final dark = row == 0;
      final y0 = row * (h / 2 + 10) + pad;
      for (var i = 0; i < times.length; i++) {
        final x = pad + i * (big + pad);
        c.save();
        c.translate(x, y0);
        FusionEmblemPainter(time: times[i], dark: dark).paint(c, const Size(big, big));
        c.restore();
        c.save();
        c.translate(x + 60, y0 + big + pad);
        FusionEmblemPainter(time: times[i], dark: dark).paint(c, const Size(small, small));
        c.restore();
      }
    }
    final image = rec.endRecording().toImageSync(w.toInt(), h.toInt());
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
