@Tags(['preview'])
library;

import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  test('Light charge and Plant growth render at combat scale', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const width = 1440, height = 880;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1440, 880),
      Paint()..color = const Color(0xFF080A12),
    );
    void label(String text, Offset at) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Color(0xFFC7C4B6),
            fontSize: 18,
            fontFamily: 'Preview',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, at);
    }

    const names = [
      'LIGHT · gathering',
      'LIGHT · charging',
      'LIGHT · ready',
      'LIGHT · healing release',
    ];
    for (var i = 0; i < 4; i++) {
      label(names[i], Offset(360.0 * i + 30, 24));
      canvas.save();
      canvas.translate(360.0 * i + 180, 225);
      canvas.scale(0.72);
      drawMysticDawnStar(
        canvas: canvas,
        at: Offset.zero,
        charge: [0.0, 0.45, 1.0, 1.0][i],
        flare: i == 3 ? 0.65 : 0,
        alpha: 1,
        time: 3,
      );
      canvas.restore();
    }
    label('PLANT · old growth', const Offset(30, 440));
    for (var i = 0; i < 7; i++) {
      drawMysticFlora(
        canvas: canvas,
        at: Offset(65 + i * 43.0, 650),
        element: 'Plant',
        size: 1.3,
        bloom: 0.4 + i * 0.1,
        seed: i * 2.1,
        time: 3,
        tint: const Color(0xFF4CAF50),
      );
    }
    label('PLANT · lashing vine', const Offset(420, 440));
    label('PLANT · spitting vine', const Offset(1000, 440));
    for (var i = 0; i < 2; i++) {
      drawMysticGroveVine(
        canvas: canvas,
        root: Offset(550.0 + i * 540, 790),
        lashes: i == 0,
        growth: 1,
        swing: 0.65,
        aimAngle: -0.4,
        reach: 210,
        seed: 1.5,
        alpha: 1,
        time: 3,
        plant: const Color(0xFF4CAF50),
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);
    final out = Platform.environment['MYSTIC_WORLD_OUT'];
    if (out != null) {
      Directory(out).createSync(recursive: true);
      File(
        '$out/mystic_light_plant.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    }
    image.dispose();
    picture.dispose();
  });
}
