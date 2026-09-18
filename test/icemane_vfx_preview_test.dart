@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ICEMANE_VFX_OUT=/tmp flutter test test/icemane_vfx_preview_test.dart
// Render the actual shared special at multiple camera scales and at expiry.
void main() {
  final output = Platform.environment['ICEMANE_VFX_OUT'];
  testWidgets('Icemane silhouette and breakup preview', (tester) async {
    final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (font.existsSync()) {
      await (FontLoader('Preview')..addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())),
          ))
          .load();
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const width = 960;
    const height = 560;
    canvas.drawColor(const Color(0xFF090F20), BlendMode.src);
    void label(String text, double x, double y, {double size = 13}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'Preview',
            fontSize: size,
            color: const Color(0xFFB9D5EA),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(x, y));
    }

    label('ICEMANE / shared in-game renderer', 24, 18, size: 21);
    const scales = [1.0, 0.6, 0.35];
    const times = [0.2, 0.5, 0.8, 1.1];
    for (var row = 0; row < scales.length; row++) {
      label(
        '${(scales[row] * 100).round()}% camera scale',
        24,
        62 + row * 155.0,
      );
      for (var col = 0; col < times.length; col++) {
        final p = createCosmicSpecialAbility(
          origin: Offset.zero,
          baseAngle: -0.3,
          family: 'mane',
          element: 'Ice',
          damage: 40,
          maxHp: 400,
        ).projectiles.single;
        if (col == 3) p.life = 0.11;
        canvas.save();
        canvas.translate(180 + col * 220.0, 144 + row * 155.0);
        canvas.scale(scales[row]);
        expect(
          drawManeElementalProjectileVisual(
            canvas: canvas,
            projectile: p,
            position: Offset.zero,
            color: elementColor('Ice'),
            time: times[col],
          ),
          isTrue,
        );
        drawProjectileRoleOverlay(
          canvas: canvas,
          projectile: p,
          position: Offset.zero,
          color: elementColor('Ice'),
          time: times[col],
        );
        canvas.restore();
      }
    }
    label('flight / frost chips', 120, 535);
    label('expiry / separating facets', 730, 535);
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final image = await picture.toImage(width, height);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(output!).createSync(recursive: true);
      File(
        '$output/icemane_vfx_preview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    picture.dispose();
  }, skip: output == null);
}
