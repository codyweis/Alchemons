@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/extraction_vessel.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The harvest chamber's flask in each of its states, with a real creature in
// it: locked, empty, filling, a tap's splash, full, and pouring out.
//
//   VESSEL_OUT=/tmp/vessel.png flutter test \
//     test/extraction_vessel_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['VESSEL_OUT'];

  testWidgets('extraction vessel preview', (tester) async {
    if (out == null) return;
    const side = 300.0;
    final (ui.Image sprite, SpecimenGrains grains) = (await tester.runAsync(
      () async {
        final bytes = File(
          'assets/images/creatures/rare/HOR01_firehorn.png',
        ).readAsBytesSync();
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: 150,
        );
        final img = (await codec.getNextFrame()).image;
        final data = await img.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        final g = SpecimenGrains.fromRgba(
          data!.buffer.asUint8List(),
          img.width,
          img.height,
          pixelRatio: 1,
          maxGrains: 900,
          tones: 12,
        );
        return (img, g);
      },
    ))!;

    final cases = <(String, VesselMode, double, Color, bool, bool, bool)>[
      ('locked', VesselMode.locked, 0, const Color(0xFF4ECDC4), false, false, false),
      ('empty', VesselMode.empty, 0, const Color(0xFF4ECDC4), false, false, false),
      ('running 15%', VesselMode.running, 0.15, const Color(0xFFFF6B35), true, false, false),
      ('running 55%', VesselMode.running, 0.55, const Color(0xFFFF6B35), true, false, false),
      ('tap', VesselMode.running, 0.55, const Color(0xFFFF6B35), true, true, false),
      ('running 90%', VesselMode.running, 0.9, const Color(0xFFB388FF), true, false, false),
      ('ready', VesselMode.ready, 1, const Color(0xFF6BCF7F), true, false, false),
      ('collect', VesselMode.ready, 0.45, const Color(0xFF6BCF7F), true, false, true),
    ];

    final frames = <ui.Image>[];
    for (final (_, mode, level, accent, creature, tap, vent) in cases) {
      final f = ExtractionVesselField()
        ..accent = accent
        ..mode = mode
        ..level = level
        ..occupied = creature;
      f.layout(const Size.square(side));
      final g = f.geometry!;
      if (creature) f.setSpecimen(grains, g.creatureCenter);
      // Run it in so the motes are in flight and the surface has caught up.
      for (var i = 0; i < 150; i++) {
        f.step(1 / 60);
      }
      if (vent) {
        f
          ..venting = true
          ..level = level;
        for (var i = 0; i < 24; i++) {
          f.step(1 / 60);
        }
      }
      if (tap) {
        f.splash(Offset(g.center.dx + 30, g.center.dy));
        for (var i = 0; i < 14; i++) {
          f.step(1 / 60);
        }
      }
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        const Offset(0, 0) & const Size.square(side),
        Paint()..color = const Color(0xFF0B0C10),
      );
      f.paintBack(c);
      if (creature) {
        final cs = g.creatureSize * 0.86;
        final dst = Rect.fromCenter(
          center: g.creatureCenter,
          width: cs,
          height: cs * sprite.height / sprite.width,
        );
        c.drawImageRect(
          sprite,
          Offset.zero & Size(sprite.width.toDouble(), sprite.height.toDouble()),
          dst,
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
      f.paintFront(c);
      frames.add(rec.endRecording().toImageSync(side.toInt(), side.toInt()));
    }

    const cols = 4;
    final rows = (frames.length / cols).ceil();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(
      Rect.fromLTWH(0, 0, side * cols, (side + 22) * rows),
      Paint()..color = const Color(0xFF06070A),
    );
    for (var i = 0; i < frames.length; i++) {
      final x = (i % cols) * side, y = (i ~/ cols) * (side + 22);
      c.drawImage(frames[i], Offset(x, y + 22), Paint());
      final tp = TextPainter(
        text: TextSpan(
          text: cases[i].$1,
          style: const TextStyle(color: Color(0xFFE8DCC8), fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(x + 8, y + 4));
    }
    final sheet = rec.endRecording().toImageSync(
      (side * cols).toInt(),
      ((side + 22) * rows).toInt(),
    );
    await tester.runAsync(() async {
      final png = await sheet.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(png!.buffer.asUint8List());
    });

    // What a full frame costs on the CPU (JIT, so a ceiling).
    final f = ExtractionVesselField()
      ..accent = const Color(0xFFFF6B35)
      ..mode = VesselMode.running
      ..level = 0.7
      ..occupied = true;
    f.layout(const Size.square(side));
    f.setSpecimen(grains, f.geometry!.creatureCenter);
    for (var i = 0; i < 200; i++) {
      f.step(1 / 60);
    }
    final sw = Stopwatch()..start();
    for (var i = 0; i < 200; i++) {
      f.step(1 / 60);
      final rec2 = ui.PictureRecorder();
      final c2 = Canvas(rec2);
      f.paintBack(c2);
      f.paintFront(c2);
      rec2.endRecording().dispose();
    }
    // ignore: avoid_print
    print('vessel frame: ${(sw.elapsedMicroseconds / 200).toStringAsFixed(0)} µs');
  });
}
