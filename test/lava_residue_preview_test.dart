@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// LAVA_RESIDUE_VFX_OUT=/tmp flutter test test/lava_residue_vfx_preview_test.dart
// Render the actual shared special at multiple camera scales and at expiry.
void main() {
  final output = Platform.environment['LAVA_RESIDUE_VFX_OUT'];
  testWidgets('Lava residue material and fade preview', (tester) async {
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

    label('LAVA_RESIDUE / shared in-game renderer', 24, 18, size: 21);
    const scales = [1.0, 0.6, 0.35];
    const times = [0.2, 0.5, 0.8, 1.1];
    for (var row = 0; row < scales.length; row++) {
      label(
        '${(scales[row] * 100).round()}% camera scale',
        24,
        62 + row * 155.0,
      );
      for (var col = 0; col < times.length; col++) {
        final p = Projectile(
          position: Offset.zero,
          angle: 0,
          element: 'Lava',
          damage: 0,
          life: 3.6,
          stationary: true,
          abilityFamily: 'mane',
          visualStyle: ProjectileVisualStyle.sigil,
          effectRadius: 60,
          tickEffect: AbilityEffectKind.burn,
        );
        if (col == 3) p.life = 0.11;
        canvas.save();
        canvas.translate(180 + col * 220.0, 144 + row * 155.0);
        canvas.scale(scales[row]);
        expect(
          drawMaskElementalProjectileVisual(
            canvas: canvas,
            projectile: p,
            position: Offset.zero,
            color: elementColor('Lava'),
            time: times[col],
          ),
          isTrue,
        );
        drawProjectileRoleOverlay(
          canvas: canvas,
          projectile: p,
          position: Offset.zero,
          color: elementColor('Lava'),
          time: times[col],
        );
        canvas.restore();
      }
    }
    label('molten pool / convection', 120, 535);
    label('cooling / fade', 730, 535);
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final image = await picture.toImage(width, height);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(output!).createSync(recursive: true);
      File(
        '$output/lava_residue_vfx_preview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    picture.dispose();
  }, skip: output == null);
  testWidgets(
    'Lava residue motion preview',
    (tester) async {
      final frames = Directory('$output/lava_residue_frames')
        ..createSync(recursive: true);
      final p = Projectile(
        position: Offset.zero,
        angle: 0,
        element: 'Lava',
        damage: 0,
        life: 3.6,
        stationary: true,
        abilityFamily: 'mane',
        visualStyle: ProjectileVisualStyle.sigil,
        effectRadius: 60,
        tickEffect: AbilityEffectKind.burn,
      );
      await tester.runAsync(() async {
        for (var frame = 0; frame < 72; frame++) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawColor(const Color(0xFF090F20), BlendMode.src);
          // Fixed position makes the material motion easy to inspect. The lower
          // sample checks readability at the gameplay camera scale.
          for (var row = 0; row < 2; row++) {
            canvas.save();
            canvas.translate(300, row == 0 ? 125 : 270);
            canvas.scale(row == 0 ? 1.0 : 0.45);
            drawMaskElementalProjectileVisual(
              canvas: canvas,
              projectile: p,
              position: Offset.zero,
              color: elementColor('Lava'),
              time: frame / 24,
            );
            drawProjectileRoleOverlay(
              canvas: canvas,
              projectile: p,
              position: Offset.zero,
              color: elementColor('Lava'),
              time: frame / 24,
            );
            canvas.restore();
          }
          final picture = recorder.endRecording();
          final image = await picture.toImage(540, 340);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${frames.path}/frame_${frame.toString().padLeft(3, '0')}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
          picture.dispose();
        }
      });
    },
    skip: output == null || Platform.environment['LAVA_RESIDUE_MOTION'] != '1',
  );
}
