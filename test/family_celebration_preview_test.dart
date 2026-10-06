@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';

// CELEBRATION_OUT=/tmp/party_hat flutter test test/family_celebration_preview_test.dart
void main() {
  testWidgets('render family celebration concept', (tester) async {
    final out = Platform.environment['CELEBRATION_OUT'];
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
        'legendary/WNG04_airwing',
        'uncommon/PIP01_firepip',
      ]) {
        final codec = await ui.instantiateImageCodec(
          File(
            'assets/images/creatures/${path}_spritesheet.png',
          ).readAsBytesSync(),
        );
        images.add((await codec.getNextFrame()).image);
        codec.dispose();
      }
      for (var f = 0; f < 64; f++) {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(
          const Rect.fromLTWH(0, 0, 940, 630),
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
          'ALCHEMICAL CELEBRATION',
          const Offset(44, 32),
          24,
          const Color(0xFFFFD58B),
        );
        label(
          'One celebration. A little personality for every family.',
          const Offset(44, 70),
          16,
          const Color(0xFF9FAFC4),
        );
        for (var i = 0; i < 2; i++) {
          final x = 60.0 + i * 460;
          final image = images[i];
          c.drawImageRect(
            image,
            Rect.fromLTWH(
              (f % 4) * image.width / 4,
              0,
              image.width / 4,
              image.height.toDouble(),
            ),
            Rect.fromLTWH(x, 205, 360, 360),
            Paint()..filterQuality = FilterQuality.medium,
          );
          AlchemyEffectPaint.paint(
            c,
            FamilyCostume.effectFor(i == 0 ? 'WNG04' : 'PIP01')!,
            Offset(x + 180, 385),
            180,
            f / 8,
            front: true,
          );
          label(
            ['WING · Stardust party hat', 'PIP · Ruby bubble nose'][i],
            Offset(x + 40, 581),
            18,
            const Color(0xFFE4E7F1),
          );
        }
        final pic = rec.endRecording();
        final image = pic.toImageSync(940, 630);
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
  testWidgets('all celebration species fit their animation frames', (
    tester,
  ) async {
    final out = Platform.environment['CELEBRATION_OUT'];
    if (out == null) return;
    await tester.runAsync(() async {
      Directory(out).createSync(recursive: true);
      final paths = Directory('assets/images/creatures')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                !f.path.contains('/old/') &&
                f.path.endsWith('_spritesheet.png'),
          )
          .toList();
      for (final family in ['WNG', 'PIP']) {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(
          const Rect.fromLTWH(0, 0, 1440, 1200),
          Paint()..color = const Color(0xFF182030),
        );
        var i = 0;
        for (final species in FamilyCostume.placements.keys.where(
          (k) => k.startsWith(family),
        )) {
          final file = paths.singleWhere(
            (f) => f.path.split('/').last.startsWith('${species}_'),
          );
          final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
          final image = (await codec.getNextFrame()).image;
          codec.dispose();
          for (var frame = 0; frame < 2; frame++) {
            final x = (i % 4) * 360.0 + frame * 175;
            final y = (i ~/ 4) * 240.0 + 40;
            c.drawImageRect(
              image,
              Rect.fromLTWH(
                frame * 3 * image.width / 4,
                0,
                image.width / 4,
                image.height.toDouble(),
              ),
              Rect.fromLTWH(x, y, 170, 170),
              Paint()..filterQuality = FilterQuality.medium,
            );
            AlchemyEffectPaint.paint(
              c,
              FamilyCostume.effectFor(species)!,
              Offset(x + 85, y + 85),
              85,
              1.7,
              front: true,
            );
          }
          final tp = TextPainter(
            text: TextSpan(
              text: species,
              style: const TextStyle(
                fontFamily: 'Arial',
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(c, Offset((i % 4) * 360 + 130, (i ~/ 4) * 240 + 215));
          tp.dispose();
          image.dispose();
          i++;
        }
        final pic = rec.endRecording();
        final img = pic.toImageSync(1440, 1200);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$family.png').writeAsBytesSync(data!.buffer.asUint8List());
        img.dispose();
        pic.dispose();
      }
    });
  });
}
