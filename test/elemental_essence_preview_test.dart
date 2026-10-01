@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Every element's Horn coming apart into its element and back, as one strip
// per element at the details hero's size — plus what a frame costs.
//
//   ESSENCE_OUT=/tmp/essence flutter test \
//     test/elemental_essence_preview_test.dart --tags preview
//
// ESSENCE_ONLY=fire,dark limits it to some elements; ESSENCE_LIGHT=1 paints
// over the light theme's plate.
void main() {
  final out = Platform.environment['ESSENCE_OUT'];
  final only = Platform.environment['ESSENCE_ONLY']?.split(',');
  final light = Platform.environment['ESSENCE_LIGHT'] == '1';

  const horns = {
    'fire': 'HOR01_firehorn',
    'water': 'HOR02_waterhorn',
    'earth': 'HOR03_earthhorn',
    'air': 'HOR04_airhorn',
    'steam': 'HOR05_steamhorn',
    'lava': 'HOR06_lavahorn',
    'lightning': 'HOR07_lightninghorn',
    'mud': 'HOR08_mudhorn',
    'ice': 'HOR09_icehorn',
    'dust': 'HOR10_dusthorn',
    'crystal': 'HOR11_crystalhorn',
    'plant': 'HOR12_planthorn',
    'poison': 'HOR13_poisonhorn',
    'spirit': 'HOR14_spirithorn',
    'dark': 'HOR15_darkhorn',
    'light': 'HOR16_lighthorn',
    'blood': 'HOR17_bloodhorn',
  };
  const times = [0.12, 0.35, 0.6, 0.9, 1.25, 1.6, 1.85, 2.1, 2.4];
  const cell = Size(230, 230);
  const spriteSide = 162.0;

  testWidgets('essence strips', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final strips = <ui.Image>[];
    for (final entry in horns.entries) {
      if (only != null && !only.contains(entry.key)) continue;
      late ui.Image sprite;
      late SpecimenGrains grains;
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(
          File(
            'assets/images/creatures/rare/${entry.value}.png',
          ).readAsBytesSync(),
          targetWidth: (spriteSide * 2).round(),
        );
        sprite = (await codec.getNextFrame()).image;
        final data = await sprite.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        grains = SpecimenGrains.fromRgba(
          data!.buffer.asUint8List(),
          sprite.width,
          sprite.height,
          pixelRatio: 2,
          maxGrains: 2200,
          tones: 16,
        );
      });
      final field = EssenceField(grains, EssenceElement.of(entry.key));

      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      for (var i = 0; i < times.length; i++) {
        final t = times[i];
        canvas.save();
        canvas.translate(cell.width * i, 0);
        canvas.clipRect(Offset.zero & cell);
        canvas.drawRect(
          Offset.zero & cell,
          Paint()
            ..color = light ? const Color(0xFFEDE6D8) : const Color(0xFF0B0A10),
        );
        final at = cell.center(Offset.zero);
        final o = EssenceField.spriteOpacity(t);
        if (o > 0) {
          canvas.drawImageRect(
            sprite,
            Rect.fromLTWH(
              0,
              0,
              sprite.width.toDouble(),
              sprite.height.toDouble(),
            ),
            Rect.fromCenter(center: at, width: spriteSide, height: spriteSide),
            Paint()..color = Color.fromRGBO(0, 0, 0, o),
          );
        }
        field.paint(canvas, at, t, dark: !light);
        canvas.restore();
      }
      final image = rec.endRecording().toImageSync(
        (cell.width * times.length).toInt(),
        cell.height.toInt(),
      );
      strips.add(image);
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/${entry.key}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });

      final sw = Stopwatch()..start();
      for (var f = 0; f < 120; f++) {
        final r = ui.PictureRecorder();
        field.paint(
          Canvas(r),
          cell.center(Offset.zero),
          (f / 120) * EssenceField.duration,
        );
        r.endRecording().dispose();
      }
      // ignore: avoid_print
      print(
        '${entry.key}: ${(sw.elapsedMicroseconds / 120).toStringAsFixed(0)} '
        'µs per frame (JIT, ${grains.length} grains)',
      );
    }

    // Every strip at once, in the order above, at half size.
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)..scale(0.5);
    for (var i = 0; i < strips.length; i++) {
      canvas.drawImage(strips[i], Offset(0, cell.height * i), Paint());
    }
    final sheet = rec.endRecording().toImageSync(
      (cell.width * times.length / 2).round(),
      (cell.height * strips.length / 2).round(),
    );
    await tester.runAsync(() async {
      final bytes = await sheet.toByteData(format: ui.ImageByteFormat.png);
      File('$out/all.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
