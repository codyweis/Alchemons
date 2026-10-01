@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The fusion chamber's particle merge, frame by frame, with real sprites laid
// out the way the breed tab lays them out — plus what a frame costs.
//
//   FUSION_OUT=/tmp/fusion.png flutter test \
//     test/fusion_particles_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['FUSION_OUT'];

  testWidgets('fusion particles preview', (tester) async {
    if (out == null) return;
    // On the phone: a 140 box captured at the device ratio, the sprite
    // painted 69 × 1.4 across in the middle of it.
    const ratio = 2.6;
    const box = 140.0;
    const spriteSize = 69 * 1.4;

    final pairs = [
      ('HOR01_firehorn', 'rare', 'Fire', 'LET02_waterlet', 'common', 'Water'),
      (
        'WNG03_earthwing',
        'legendary',
        'Earth',
        'PIP04_airpip',
        'uncommon',
        'Air',
      ),
    ];

    late List<List<(ui.Image, SpecimenGrains)>> loaded;
    await tester.runAsync(() async {
      Future<(ui.Image, SpecimenGrains)> read(
        String name,
        String rarity,
      ) async {
        final data = await rootBundle.load(
          'assets/images/creatures/$rarity/${name}_spritesheet.png',
        );
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final sheet = (await codec.getNextFrame()).image;
        final frame = sheet.height.toDouble();
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        const px = box * ratio;
        const s = spriteSize * ratio;
        c.drawImageRect(
          sheet,
          Rect.fromLTWH(0, 0, frame, frame),
          Rect.fromCenter(
            center: const Offset(px / 2, px / 2),
            width: s,
            height: s,
          ),
          Paint()..filterQuality = FilterQuality.medium,
        );
        final img = rec.endRecording().toImageSync(px.round(), px.round());
        final bytes = await img.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        final grains = SpecimenGrains.fromRgba(
          bytes!.buffer.asUint8List(),
          img.width,
          img.height,
          pixelRatio: ratio,
        );
        return (img, grains);
      }

      loaded = [
        for (final p in pairs) [await read(p.$1, p.$2), await read(p.$4, p.$5)],
      ];
    });

    // The parent-slot stack on a ~360 wide phone.
    const stack = Size(300, 220);
    const centres = [Offset(67, 79.5), Offset(233, 79.5)];
    const core = Offset(150, 110);
    const slotScale = 1.03;

    // As the breed tab has it: fed a little as the grains arrive, then
    // swelling as the cloud falls in.
    double orbScale(double t) {
      final v = t / FusionParticleField.duration;
      double ease(double a, double b) {
        final x = ((v - a) / (b - a)).clamp(0.0, 1.0);
        return x * x * (3 - 2 * x);
      }

      return 1 + 0.25 * ease(0.30, 0.65) + 0.75 * ease(0.80, 0.95);
    }

    final frames = <(String, ui.Image)>[];
    const scale = 2.0;

    ui.Image shoot(
      FusionParticleField f,
      double t,
      List<ui.Image> sprites,
      List<Color> colors,
    ) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, stack.width * scale, stack.height * scale),
        Paint()..color = const Color(0xFF14111D),
      );
      c.scale(scale);
      // The sprites, cut away behind the crest.
      for (var s = 0; s < 2; s++) {
        final cut = f.cutY(s, t);
        if (cut == double.infinity) continue;
        c.save();
        c.translate(centres[s].dx, centres[s].dy);
        c.scale(slotScale);
        if (cut.isFinite) {
          c.clipRect(Rect.fromLTRB(-box, cut, box, box));
        }
        c.drawImageRect(
          sprites[s],
          Rect.fromLTWH(
            0,
            0,
            sprites[s].width.toDouble(),
            sprites[s].height.toDouble(),
          ),
          Rect.fromCenter(center: Offset.zero, width: box, height: box),
          Paint()..filterQuality = FilterQuality.medium,
        );
        c.restore();
      }
      f.paint(c, t, back: true);
      // The orb, between the far side of the ring and the near.
      final r = 26 * orbScale(t);
      c.drawCircle(
        core,
        r,
        Paint()
          ..shader = ui.Gradient.linear(
            core - Offset(r, r),
            core + Offset(r, r),
            [colors[0], colors[1]],
          ),
      );
      f.paint(c, t, back: false);
      return rec.endRecording().toImageSync(
        (stack.width * scale).round(),
        (stack.height * scale).round(),
      );
    }

    final times = [
      0.0,
      0.18,
      0.34,
      0.7,
      0.98,
      1.15,
      1.35,
      1.6,
      1.95,
      2.12,
      2.3,
      2.45,
    ];
    for (var p = 0; p < pairs.length; p++) {
      final colors = [
        BreedConstants.getTypeColor(pairs[p].$3),
        BreedConstants.getTypeColor(pairs[p].$6),
      ];
      final f = FusionParticleField(
        specimens: [loaded[p][0].$2, loaded[p][1].$2],
        centres: centres,
        scales: const [slotScale, slotScale],
        core: core,
        coreRadius: 26 * 1.7,
        colors: colors,
      );
      // ignore: avoid_print
      print(
        '${pairs[p].$1}: ${loaded[p][0].$2.length} grains, '
        '${loaded[p][0].$2.tones.length} tones, step '
        '${loaded[p][0].$2.step.toStringAsFixed(2)}; '
        '${pairs[p].$4}: ${loaded[p][1].$2.length} grains',
      );
      for (final t in times) {
        frames.add((
          '${pairs[p].$1.split('_').last} + ${pairs[p].$4.split('_').last}  t=$t',
          shoot(f, t, [loaded[p][0].$1, loaded[p][1].$1], colors),
        ));
      }

      // Cost: a frame's layout + both layers, recorded.
      double cost(double from, double to) {
        const n = 240;
        final sw = Stopwatch()..start();
        for (var i = 0; i < n; i++) {
          final t = from + (to - from) * i / n;
          final rec = ui.PictureRecorder();
          final c = Canvas(rec);
          f.paint(c, t, back: true);
          f.paint(c, t, back: false);
          rec.endRecording().dispose();
        }
        return sw.elapsedMicroseconds / n;
      }

      // Warm up first.
      cost(0, FusionParticleField.duration);
      // ignore: avoid_print
      print(
        'cost per frame: standing ${cost(0.3, 0.85).round()}us, '
        'pouring ${cost(0.9, 2.15).round()}us, '
        'closing ${cost(2.15, 2.55).round()}us',
      );
    }

    await tester.runAsync(() async {
      final w = stack.width * scale;
      final h = stack.height * scale;
      const cols = 3;
      final rows = (frames.length / cols).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < frames.length; i++) {
        final (label, img) = frames[i];
        final at = Offset((i % cols) * (w + 6), (i ~/ cols) * (h + 6));
        c.drawImage(img, at, Paint());
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Color(0xFF8A8AA0), fontSize: 16),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, at + const Offset(8, 4));
      }
      final img = rec.endRecording().toImageSync(
        (cols * (w + 6)).round(),
        (rows * (h + 6)).round(),
      );
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
