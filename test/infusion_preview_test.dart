@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/infusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// An infusion as strips of frames: an orb (quick) and a perfect soul (long,
// big), on a real specimen read into grains — plus what a frame costs.
//
//   INFUSE_OUT=/tmp/infuse flutter test \
//     test/infusion_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['INFUSE_OUT'];

  testWidgets('infusion strips', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    late ui.Image sprite;
    late SpecimenGrains grains;
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
        File(
          'assets/images/creatures/rare/HOR01_firehorn.png',
        ).readAsBytesSync(),
        targetWidth: 340,
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
        maxGrains: 2600,
        tones: 14,
      );
    });
    const size = Size(360, 300);
    final centre = Offset(size.width / 2, size.height * 0.55);

    Future<void> strip(
      String name,
      AlchemicalPowerupType type,
      List<(double, double)> frames, {
      int? soulRoll,
      double glowBoost = 1,
      bool jackpot = false,
      String? label,
      String? delta,
    }) async {
      final body = InfusionBody(grains, centre);
      final w = (size.width * frames.length).toInt();
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      for (var i = 0; i < frames.length; i++) {
        final (p, f) = frames[i];
        canvas.save();
        canvas.translate(size.width * i, 0);
        canvas.clipRect(Offset.zero & size);
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xFF0B0D12),
        );
        // The sprite, where the screen shows it.
        final o = InfusionPainter.spriteOpacity(f);
        if (o > 0) {
          canvas.drawImageRect(
            sprite,
            Rect.fromLTWH(
              0,
              0,
              sprite.width.toDouble(),
              sprite.height.toDouble(),
            ),
            Rect.fromCenter(center: centre, width: 170, height: 170),
            Paint()..color = Color.fromRGBO(0, 0, 0, o),
          );
        }
        InfusionPainter(
          progress: p,
          flash: f,
          type: type,
          body: body,
          rollLabel: label,
          glowBoost: glowBoost,
          isJackpot: jackpot,
          orbitEndProgress: 0.72,
          soulRoll: soulRoll,
          deltaLabel: delta,
        ).paint(canvas, size);
        canvas.restore();
      }
      final image = rec.endRecording().toImageSync(w, size.height.toInt());
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await strip(
      'orb',
      AlchemicalPowerupType.speed,
      const [
        (0.15, 0),
        (0.5, 0),
        (0.9, 0),
        (1, 0.12),
        (1, 0.32),
        (1, 0.52),
        (1, 0.75),
        (1, 0.95),
      ],
      label: 'ENHANCING',
      delta: '+3%',
    );
    await strip(
      'soul',
      AlchemicalPowerupType.beauty,
      const [
        (0.12, 0),
        (0.45, 0),
        (0.7, 0),
        (0.86, 0),
        (1, 0.15),
        (1, 0.4),
        (1, 0.65),
        (1, 0.9),
      ],
      soulRoll: 5,
      glowBoost: 3.4,
      jackpot: true,
      label: 'PERFECT AWAKENING',
      delta: '+5 POTENTIAL',
    );

    final body = InfusionBody(grains, centre);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 240; i++) {
      final r = ui.PictureRecorder();
      InfusionPainter(
        progress: 1,
        flash: (i % 60) / 60,
        type: AlchemicalPowerupType.strength,
        body: body,
        rollLabel: null,
        glowBoost: 2,
        isJackpot: false,
        orbitEndProgress: 0.72,
        soulRoll: 3,
      ).paint(Canvas(r), size);
      r.endRecording().dispose();
    }
    // ignore: avoid_print
    print(
      'infusion: ${(sw.elapsedMicroseconds / 240).toStringAsFixed(0)} µs per '
      'frame (JIT, ${grains.length} body grains)',
    );
  });
}
