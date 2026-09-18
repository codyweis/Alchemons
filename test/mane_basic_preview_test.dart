@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/mane_alchemical_vfx.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// MANE_BASIC_OUT=/tmp/mane MANE_BASIC_MOTION=1 flutter test
// test/mane_basic_preview_test.dart
void main() {
  test('basic renderer claims every twin slash but leaves specials alone', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final element in kCosmicAbilityElements) {
      final basics = createFamilyBasicAttack(
        origin: Offset.zero,
        angle: 0,
        family: 'mane',
        element: element,
        damage: 10,
      );
      expect(basics.length, 2);
      for (final p in basics) {
        expect(
          drawAlchemicalManeBasicVisual(
            canvas: canvas,
            projectile: p,
            position: p.position,
            time: 0.5,
          ),
          isTrue,
          reason: element,
        );
      }
      for (final p in createCosmicSpecialAbility(
        origin: Offset.zero,
        baseAngle: 0,
        family: 'mane',
        element: element,
        damage: 10,
        maxHp: 100,
      ).projectiles) {
        expect(
          drawAlchemicalManeBasicVisual(
            canvas: canvas,
            projectile: p,
            position: p.position,
            time: 0.5,
          ),
          isFalse,
          reason: element,
        );
      }
    }
    recorder.endRecording().dispose();
  });
  final output = Platform.environment['MANE_BASIC_OUT'];
  testWidgets('Mane twin basic attacks in motion', (tester) async {
    final file = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (file.existsSync()) {
      await (FontLoader('SheetLabel')..addFont(
            Future.value(ByteData.sublistView(file.readAsBytesSync())),
          ))
          .load();
    }
    final casts = {
      for (final e in kCosmicAbilityElements)
        e: createFamilyBasicAttack(
          origin: Offset.zero,
          angle: -0.2,
          family: 'mane',
          element: e,
          damage: 40,
        ),
    };
    final frames = Platform.environment['MANE_BASIC_MOTION'] == '1' ? 54 : 1;
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

        label('MANE / quieter twin auto-attacks', 20, 14, size: 19);
        label(
          'Actual renderer + overlays • both basic slashes • 60% scale',
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
          for (final p in cast) {
            expect(
              drawManeElementalProjectileVisual(
                canvas: c,
                projectile: p,
                position: p.position + Offset(cos(p.angle), sin(p.angle)) * 80,
                color: elementColor(element),
                time: frame / 18,
              ),
              isTrue,
            );
            drawProjectileRoleOverlay(
              canvas: c,
              projectile: p,
              position: p.position + Offset(cos(p.angle), sin(p.angle)) * 80,
              color: elementColor(element),
              time: frame / 18,
            );
          }
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
            '$output/mane_basic_preview.png',
          ).writeAsBytesSync(bytes.buffer.asUint8List());
        }
        img.dispose();
        pic.dispose();
      }
    });
  }, skip: output == null);
}
