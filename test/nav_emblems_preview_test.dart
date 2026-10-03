@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/faction.dart';
import 'package:alchemons/widgets/daily_reliquary.dart';
import 'package:alchemons/widgets/fusion_emblem.dart';
import 'package:alchemons/widgets/nav_emblems.dart';
import 'package:alchemons/widgets/particle_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The dock's five emblems on the dock, closed (55) and open (80, three
// moments), and large enough to judge their drawing; then home's daily
// reliquary for each division, and Earthen's (crystal) unsealing.
//
//   NAV_EMBLEMS_OUT=/tmp/nav.png flutter test \
//     test/nav_emblems_preview_test.dart --tags preview
//
// The reliquary sheet lands beside it, as nav_reliquary.png.
void main() {
  final out = Platform.environment['NAV_EMBLEMS_OUT'];

  testWidgets('nav emblem sheet', (tester) async {
    if (out == null) return;
    late TitleSamples title;
    await tester.runAsync(() async {
      title = await TitleSamples.of(kTitleAsset);
    });

    const order = [
      NavEmblemKind.inventory,
      NavEmblemKind.creatures,
      NavEmblemKind.home,
      null, // fusion
      NavEmblemKind.shop,
    ];
    CustomPainter painter(NavEmblemKind? kind, double t) => kind == null
        ? FusionEmblemPainter(time: t)
        : NavEmblemPainter(kind: kind, time: t, title: title);

    const cell = 110.0;
    final rows = <(double, List<double>)>[
      (55, [NavEmblemPainter.restTime]),
      (80, [0.0, 1.4, 2.8]),
      (200, [NavEmblemPainter.restTime]),
    ];
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    var height = 0.0;
    for (final (size, times) in rows) {
      height += (size > cell ? size + 20 : cell) * times.length;
    }
    const width = cell * 5 * 2.2;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, 2000),
      Paint()..color = const Color(0xFF07090C),
    );
    var y = 0.0;
    for (final (size, times) in rows) {
      final rowH = size > cell ? size + 20 : cell;
      for (final t in times) {
        // The dock's own strip behind the small rows.
        if (size <= 80) {
          canvas.drawRect(
            Rect.fromLTWH(0, y + 10, width, rowH - 20),
            Paint()..color = const Color(0xFF0C0F0B),
          );
        }
        for (var i = 0; i < order.length; i++) {
          final slot = width / order.length;
          canvas.save();
          canvas.translate(slot * i + (slot - size) / 2, y + (rowH - size) / 2);
          painter(order[i], t).paint(canvas, Size.square(size));
          canvas.restore();
        }
        y += rowH;
      }
    }
    final image = await tester.runAsync(
      () => rec.endRecording().toImage(width.toInt(), height.toInt()),
    );
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
  });

  testWidgets('daily reliquary sheet', (tester) async {
    if (out == null) return;
    const box = 160.0;
    final frames = <(String, double)>[
      for (final f in FactionId.values) (dailyCacheElementFor(f), 0),
      ('Crystal', 0.2),
      ('Crystal', 0.45),
      ('Crystal', 0.7),
      ('Crystal', 0.9),
    ];
    const cell = box * 1.6;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    const width = cell * 4;
    const height = cell * 2;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFF07090C),
    );
    for (var i = 0; i < frames.length; i++) {
      final (element, t) = frames[i];
      canvas.save();
      canvas.translate(
        (i % 4) * cell + (cell - box) / 2,
        (i ~/ 4) * cell + (cell - box) / 2,
      );
      DailyReliquaryPainter(
        element: element,
        life: 2.0,
        open: t,
      ).paint(canvas, const Size.square(box));
      canvas.restore();
    }
    final image = await tester.runAsync(
      () => rec.endRecording().toImage(width.toInt(), height.toInt()),
    );
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    File(
      out.replaceFirst(RegExp(r'\.png$'), '_reliquary.png'),
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
