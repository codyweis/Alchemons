@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/dock_emblems.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The dock as it stands — Field and Survival's painted icons, then the
// Enhance and Harvest scenes — on the home screen's blue and on the dark,
// plus the two scenes big at two moments.
//
//   DOCK_OUT=/tmp/dock.png flutter test \
//     test/dock_emblems_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['DOCK_OUT'];

  testWidgets('dock emblem sheet', (tester) async {
    if (out == null) return;
    late SpecimenGrains creature;
    final pngs = <ui.Image>[];
    await tester.runAsync(() async {
      for (final name in ['fieldicon', 'trialsicon']) {
        final codec = await ui.instantiateImageCodec(
          File('assets/images/ui/$name.png').readAsBytesSync(),
          targetWidth: 280,
        );
        pngs.add((await codec.getNextFrame()).image);
      }
      final codec = await ui.instantiateImageCodec(
        File(DockEmblem.enhanceCreature).readAsBytesSync(),
        targetWidth: 96,
      );
      final image = (await codec.getNextFrame()).image;
      final rgba = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      creature = SpecimenGrains.fromRgba(
        rgba!.buffer.asUint8List(),
        image.width,
        image.height,
        pixelRatio: 1,
        maxGrains: 520,
        tones: 8,
      );
    });
    const dock = 140.0;
    const col = dock + 40;
    const w = 40 + col * 4.0;
    const h = 40 + (dock + 20) * 4.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    // Dark theme (the home screen's blue, then night), light theme (two
    // pale grounds).
    const grounds = [
      Color(0xFF2B5373),
      Color(0xFF0E0B14),
      Color(0xFFE9E4D8),
      Color(0xFFF6F3EC),
    ];
    for (var g = 0; g < 4; g++) {
      c.drawRect(
        Rect.fromLTWH(g * col + 20, 0, col, h),
        Paint()..color = grounds[g],
      );
    }
    void png(ui.Image img, Offset at) => c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(at.dx, at.dy, dock, dock),
      Paint()..filterQuality = FilterQuality.medium,
    );
    void scene(DockEmblemKind k, Offset at, double t, bool dark) {
      c.save();
      c.translate(at.dx, at.dy);
      DockEmblemPainter(
        k,
        time: t,
        creature: creature,
        dark: dark,
      ).paint(c, const Size(dock, dock));
      c.restore();
    }

    for (var g = 0; g < 4; g++) {
      final x = 40.0 + g * col;
      final dark = g < 2;
      scene(DockEmblemKind.field, Offset(x, 40), 1.1 + g * 0.6, dark);
      scene(
        DockEmblemKind.survival,
        Offset(x, 40 + (dock + 20)),
        1.1 + g * 0.9,
        dark,
      );
      scene(
        DockEmblemKind.enhance,
        Offset(x, 40 + (dock + 20) * 2),
        g.isEven ? 1.1 : 2.4,
        dark,
      );
      scene(DockEmblemKind.harvest, Offset(x, 40 + (dock + 20) * 3), 1.1, dark);
    }
    final image = rec.endRecording().toImageSync(w.toInt(), h.toInt());
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
