@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/grain_assembly.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A companion summoned in space and recalled, as strips of frames at the
// size it flies at, over the dark — plus what a frame costs.
//
//   SUMMON_OUT=/tmp/summon flutter test \
//     test/grain_assembly_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['SUMMON_OUT'];

  testWidgets('summon strips', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    late ui.Image sprite;
    late SpecimenGrains grains;
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
        File(
          'assets/images/creatures/rare/HOR02_waterhorn.png',
        ).readAsBytesSync(),
        targetWidth: 150,
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
        maxGrains: 1100,
        tones: 12,
      );
    });
    final assembly = GrainAssembly(grains, accent: const Color(0xFF3FA9F5));
    const cell = Size(200, 200);
    final at = cell.center(Offset.zero);

    Future<void> strip(String name, List<double> us, bool gather) async {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      for (var i = 0; i < us.length; i++) {
        final u = us[i];
        canvas.save();
        canvas.translate(cell.width * i, 0);
        canvas.clipRect(Offset.zero & cell);
        canvas.drawRect(
          Offset.zero & cell,
          Paint()..color = const Color(0xFF05060C),
        );
        final o = gather
            ? GrainAssembly.spriteOpacityGathering(u)
            : GrainAssembly.spriteOpacityScattering(u);
        if (o > 0) {
          canvas.drawImageRect(
            sprite,
            Rect.fromLTWH(
              0,
              0,
              sprite.width.toDouble(),
              sprite.height.toDouble(),
            ),
            Rect.fromCenter(center: at, width: 75, height: 75),
            Paint()..color = Color.fromRGBO(0, 0, 0, o),
          );
        }
        if (gather) {
          assembly.paintGather(canvas, at, u);
        } else {
          assembly.paintScatter(canvas, at, u, to: const Offset(60, 80));
        }
        canvas.restore();
      }
      final image = rec.endRecording().toImageSync(
        (cell.width * us.length).toInt(),
        cell.height.toInt(),
      );
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await strip('gather', const [
      0.05,
      0.15,
      0.3,
      0.45,
      0.6,
      0.75,
      0.88,
      0.98,
    ], true);
    await strip('scatter', const [
      0.05,
      0.2,
      0.35,
      0.5,
      0.65,
      0.8,
      0.95,
    ], false);

    final sw = Stopwatch()..start();
    for (var i = 0; i < 240; i++) {
      final r = ui.PictureRecorder();
      assembly.paintGather(Canvas(r), at, (i % 60) / 60);
      r.endRecording().dispose();
    }
    // ignore: avoid_print
    print(
      'summon: ${(sw.elapsedMicroseconds / 240).toStringAsFixed(0)} µs per '
      'companion per frame (JIT, ${grains.length} grains)',
    );
  });
}
