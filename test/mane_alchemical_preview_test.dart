@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// MANE_ALCHEMY_OUT=/tmp/mane MANE_ALCHEMY_MOTION=1 flutter test
// test/mane_alchemical_preview_test.dart
void main() {
  final output = Platform.environment['MANE_ALCHEMY_OUT'];
  testWidgets('all Mane materials and overlays in motion', (tester) async {
    final file = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (file.existsSync()) {
      await (FontLoader('SheetLabel')..addFont(
            Future.value(ByteData.sublistView(file.readAsBytesSync())),
          ))
          .load();
    }
    final casts = {
      for (final e in kCosmicAbilityElements)
        e: createCosmicSpecialAbility(
          origin: Offset.zero,
          baseAngle: -0.2,
          family: 'mane',
          element: e,
          damage: 40,
          maxHp: 400,
        ).projectiles,
    };
    final frames = Platform.environment['MANE_ALCHEMY_MOTION'] == '1' ? 54 : 1;
    await tester.runAsync(() async {
      Directory('$output/frames').createSync(recursive: true);
      for (var frame = 0; frame < frames; frame++) {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawColor(const Color(0xFF090F20), BlendMode.src);
        void label(String text, double x, double y, {double size = 13}) {
          final tp = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                fontFamily: 'SheetLabel',
                fontSize: size,
                color: const Color(0xFFBDD1DA),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(c, Offset(x, y));
        }

        label('MANE / alchemical materials in motion', 20, 14, size: 19);
        label(
          'Actual renderer + overlays • representative projectile per cast • 60% scale',
          20,
          40,
          size: 11,
        );
        for (var i = 0; i < kCosmicAbilityElements.length; i++) {
          final element = kCosmicAbilityElements[i];
          final cast = casts[element]!;
          final x = (i % 4) * 220.0;
          final y = 70 + (i ~/ 4) * 180.0;
          label(
            '$element${cast.length > 1 ? '  ×${cast.length}' : ''}',
            x + 16,
            y + 6,
          );
          c.save();
          c.clipRect(Rect.fromLTWH(x, y + 25, 220, 152));
          c.translate(x + 126, y + 100);
          c.scale(0.6);
          final p = cast.first;
          expect(
            drawManeElementalProjectileVisual(
              canvas: c,
              projectile: p,
              position: Offset.zero,
              color: elementColor(element),
              time: frame / 18,
            ),
            isTrue,
          );
          drawProjectileRoleOverlay(
            canvas: c,
            projectile: p,
            position: Offset.zero,
            color: elementColor(element),
            time: frame / 18,
          );
          c.restore();
        }
        final pic = rec.endRecording();
        final img = await pic.toImage(880, 970);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$output/frames/frame_${frame.toString().padLeft(3, '0')}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        if (frame == 0) {
          File(
            '$output/mane_alchemical_preview.png',
          ).writeAsBytesSync(bytes.buffer.asUint8List());
        }
        img.dispose();
        pic.dispose();
      }
    });
  }, skip: output == null);
}
