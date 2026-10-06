@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alchemons/widgets/fx/alchemical_party_hat.dart';

// PARTY_HAT_OUT=/tmp/party_hat flutter test test/party_hat_preview_test.dart
void main() {
  testWidgets('render alchemical party hat concept', (tester) async {
    final out = Platform.environment['PARTY_HAT_OUT'];
    if (out == null) return;
    await tester.runAsync(() async {
      Directory(out).createSync(recursive: true);
      final fontPath = Platform.environment['PARTY_HAT_FONT'];
      if (fontPath != null) {
        final loader = FontLoader('Arial')
          ..addFont(
            Future.value(
              ByteData.sublistView(File(fontPath).readAsBytesSync()),
            ),
          );
        await loader.load();
      }
      final images = <ui.Image>[];
      for (final path in [
        'common/LET02_waterlet',
        'uncommon/PIP01_firepip',
        'rare/HOR16_lighthorn',
      ]) {
        final codec = await ui.instantiateImageCodec(
          File('assets/images/creatures/$path.png').readAsBytesSync(),
        );
        images.add((await codec.getNextFrame()).image);
        codec.dispose();
      }
      for (var f = 0; f < 64; f++) {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(
          const Rect.fromLTWH(0, 0, 1050, 560),
          Paint()..color = const Color(0xFF0B101A),
        );
        void label(String text, Offset at, double size, Color color) {
          final tp = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                fontFamily: 'Arial',
                fontSize: size,
                color: color,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(c, at);
          tp.dispose();
        }

        label(
          'ALCHEMICAL PARTY HAT',
          const Offset(44, 32),
          24,
          const Color(0xFFFFD58B),
        );
        label(
          'Violet stardust · gilded spiral · a spark of celebration',
          const Offset(44, 70),
          16,
          const Color(0xFF9FAFC4),
        );
        for (var i = 0; i < 3; i++) {
          final x = 55.0 + i * 330;
          final image = images[i];
          c.drawImageRect(
            image,
            Rect.fromLTWH(
              0,
              0,
              image.width.toDouble(),
              image.height.toDouble(),
            ),
            Rect.fromLTWH(x, 230, 280, 280),
            Paint()..filterQuality = FilterQuality.medium,
          );
          AlchemicalPartyHat.paint(
            c,
            Offset(x + [140.0, 106.0, 140.0][i], [290.0, 306.0, 295.0][i]),
            84,
            f / 8,
          );
          label(
            ['Waterlet', 'Firepip', 'Lighthorn'][i],
            Offset(x + 90, 514),
            18,
            const Color(0xFFE4E7F1),
          );
        }
        final pic = rec.endRecording();
        final image = pic.toImageSync(1050, 560);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/frame_${f.toString().padLeft(3, '0')}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
        pic.dispose();
      }
      for (final image in images) {
        image.dispose();
      }
    });
  });
}
