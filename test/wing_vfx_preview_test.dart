@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// WING_VFX_OUT=/tmp/wing-vfx flutter test test/wing_vfx_preview_test.dart
// Uses the actual shared renderers at two animation phases and reduced detail.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (font.existsSync()) {
      await (FontLoader('Preview')..addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())),
          ))
          .load();
    }
  });
  const groups = {
    'first-four': ['Lightning', 'Ice', 'Water', 'Dark'],
    'remaining': [
      'Air',
      'Dust',
      'Lava',
      'Blood',
      'Earth',
      'Light',
      'Spirit',
      'Crystal',
      'Steam',
      'Mud',
      'Plant',
      'Fire',
      'Poison',
    ],
  };
  for (final group in groups.entries) {
    test('Wing ${group.key} materials at normal and reduced detail', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFF090E1C), BlendMode.src);
      void label(String text, double x, double y) {
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: const TextStyle(
              color: Color(0xFFC9D8EE),
              fontSize: 17,
              fontFamily: 'Preview',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x, y));
      }

      label('WING / ${group.key} / shared Survival + Cosmic visuals', 28, 22);
      label('Full detail / 0.2s', 170, 67);
      label('Full detail / 1.0s', 500, 67);
      label('Zoomed out / fewer effects', 830, 67);
      for (var row = 0; row < group.value.length; row++) {
        final element = group.value[row];
        final y = 155.0 + row * 118;
        label(element, 28, y - 10);
        for (var col = 0; col < 3; col++) {
          final time = col == 1 ? 1.0 : 0.2;
          canvas.save();
          canvas.translate(170 + col * 330.0, y);
          if (col == 2) canvas.scale(0.55);
          if (element == 'Fire' || element == 'Poison') {
            drawAdvancedWingBeamRing(
              canvas: canvas,
              center: const Offset(132, 0),
              radius: 40,
              width: 5,
              color: elementColor(element),
              element: element,
              alpha: 1,
              time: time,
              details: col != 2,
            );
          } else {
            drawAdvancedAbilityBeam(
              canvas: canvas,
              start: Offset.zero,
              end: const Offset(265, 0),
              color: elementColor(element),
              width: element == 'Lightning' ? 19 : 10,
              alpha: 1,
              time: time,
              wingElement: element,
              particles: col != 2,
            );
          }
          canvas.restore();
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(1160, 110 + group.value.length * 118);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      final output = Platform.environment['WING_VFX_OUT'];
      if (output != null) {
        await Directory(output).create(recursive: true);
        await File(
          '$output/wing-${group.key}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      }
      image.dispose();
      picture.dispose();
    });
  }
}
