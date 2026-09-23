@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/components/mystic_world_ambience.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final file = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (file.existsSync()) {
      await (FontLoader('Preview')..addFont(
            Future.value(ByteData.sublistView(file.readAsBytesSync())),
          ))
          .load();
    }
  });
  test('all seventeen worlds have an authored atmosphere', () {
    expect(mysticAtmosphereColors.keys.toSet(), kCosmicAbilityElements.toSet());
  });
  Future<ui.Image> render(
    String element, {
    double strength = 1,
    bool reduced = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFF080A12), BlendMode.src);
    drawMysticWorldAmbience(
      canvas: canvas,
      viewport: const Rect.fromLTWH(0, 0, 400, 260),
      element: element,
      time: 4,
      strength: strength,
      reducedDetail: reduced,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(400, 260);
    picture.dispose();
    return image;
  }

  test(
    'worlds stay distinct, leave the combat center clear and support reduced detail',
    () async {
      final signatures = <int>{};
      for (final element in kCosmicAbilityElements) {
        for (final reduced in [false, true]) {
          final image = await render(element, reduced: reduced);
          final bytes = (await image.toByteData())!;
          final center = (130 * 400 + 200) * 4;
          // The arena center cannot become an opaque atmospheric sheet.
          expect(bytes.getUint8(center), lessThan(25), reason: element);
          expect(bytes.getUint8(center + 1), lessThan(27), reason: element);
          if (!reduced) {
            var hash = 17;
            for (var i = 0; i < bytes.lengthInBytes; i += 4) {
              hash =
                  (hash * 31 +
                      bytes.getUint8(i) * 3 +
                      bytes.getUint8(i + 1) * 5 +
                      bytes.getUint8(i + 2)) &
                  0x7fffffff;
            }
            signatures.add(hash);
          }
          image.dispose();
        }
      }
      expect(signatures.length, 17);
      final faded = await render('Light', strength: 0);
      final bytes = (await faded.toByteData())!;
      expect(bytes.getUint8(0), 8);
      expect(bytes.getUint8(1), 10);
      faded.dispose();
    },
  );
  for (final time in [4.0, 11.0]) {
    test('ambience contact sheet at $time seconds', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFF080A12), BlendMode.src);
      final elements = mysticAtmosphereColors.keys.toList();
      for (var i = 0; i < 20; i++) {
        final left = (i % 4) * 400.0, top = (i ~/ 4) * 300.0;
        final rect = Rect.fromLTWH(left + 10, top + 35, 380, 250);
        final name = i < 17
            ? elements[i]
            : ['Fire + Ice', 'Plant + Spirit + Light', 'Dark · reduced'][i -
                  17];
        final label = TextPainter(
          text: TextSpan(
            text: name,
            style: const TextStyle(
              fontFamily: 'Preview',
              color: Color(0xFFC5C5BB),
              fontSize: 17,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(left + 14, top + 10));
        canvas.save();
        canvas.clipRect(rect);
        // Identical stars and arena markers provide a readability reference.
        for (var k = 0; k < 65; k++) {
          final p = Offset(
            rect.left + (k * 79 % 380),
            rect.top + (k * 113 % 250),
          );
          canvas.drawCircle(p, 0.55, Paint()..color = const Color(0xFF596071));
        }
        final worlds = i < 17
            ? [elements[i]]
            : i == 17
            ? ['Fire', 'Ice']
            : i == 18
            ? ['Plant', 'Spirit', 'Light']
            : ['Dark'];
        for (final world in worlds) {
          drawMysticWorldAmbience(
            canvas: canvas,
            viewport: rect,
            element: world,
            time: time,
            strength: 1 / worlds.length,
            reducedDetail: i == 19 || worlds.length > 2,
          );
        }
        canvas.drawCircle(
          rect.center,
          67,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5
            ..color = const Color(0xFF28323F),
        );
        canvas.drawCircle(
          rect.center,
          5,
          Paint()..color = const Color(0xFFB5C2CE),
        );
        for (var k = 0; k < 3; k++) {
          final p = rect.center + Offset(35.0 + k * 14, -32.0 + k * 25);
          canvas.drawCircle(p, 2.5, Paint()..color = const Color(0xFFC18F86));
        }
        canvas.restore();
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(1600, 1500);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      final out = Platform.environment['MYSTIC_WORLD_OUT'];
      if (out != null) {
        Directory(out).createSync(recursive: true);
        File(
          '$out/mystic_ambience_${time.toInt()}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      }
      image.dispose();
      picture.dispose();
    });
  }
}
