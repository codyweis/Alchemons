@Tags(['preview'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_cache_vfx.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders every element's seal and unsealing to PNG contact sheets so the
/// artwork can be eyeballed instead of imagined. Not an assertion test —
/// tagged `preview` so it stays out of ordinary runs.
void main() {
  // Opt-in: set CACHE_VFX_OUT to a directory to regenerate the sheets.
  //   CACHE_VFX_OUT=/tmp flutter test test/cache_vfx_contact_sheet_test.dart
  final outDir = Platform.environment['CACHE_VFX_OUT'];

  testWidgets('cache vfx contact sheet', (tester) async {
    const cell = 170.0;
    const stops = [-1.0, 0.12, 0.38, 0.62, 0.88];
    final all = kElementColors.keys.toList();
    final groups = [all.sublist(0, 6), all.sublist(6, 12), all.sublist(12)];

    for (var g = 0; g < groups.length; g++) {
      final elements = groups[g];
      final w = cell * stops.length + 130;
      final h = cell * elements.length;

      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF04030C),
      );

      for (var r = 0; r < elements.length; r++) {
        final element = elements[r];
        final y = r * cell + cell / 2;
        canvas.drawRect(
          Rect.fromLTWH(12, y - 4, 90 * (r.isEven ? 1 : 0.6), 8),
          Paint()..color = elementColor(element),
        );
        for (var c = 0; c < stops.length; c++) {
          final p = Offset(130 + c * cell + cell / 2, y);
          final t = stops[c];
          if (t < 0) {
            paintSealedCache(canvas, p, element, 2.4);
          } else {
            paintCacheUnseal(canvas, p, element, 2.4, t);
          }
        }
      }

      final pic = rec.endRecording();
      ByteData? bytes;
      await tester.runAsync(() async {
        final img = await pic.toImage(w.round(), h.round());
        bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      });
      File(
        '$outDir/cache_vfx_$g.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    }
  }, skip: outDir == null);
}
