@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/cultivation_sphere.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A chamber's cultivation as its parents' sphere: early, nearly done, ready,
// and stirred — plus what a frame costs.
//
//   SPHERE_OUT=/tmp/sphere.png flutter test \
//     test/cultivation_sphere_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['SPHERE_OUT'];

  testWidgets('cultivation sphere preview', (tester) async {
    if (out == null) return;
    Map<String, dynamic> parent(String id, String image, String type) => {
      'baseId': id,
      'name': id,
      'types': [type],
      'rarity': 'Rare',
      'image': image,
    };
    final payload = {
      'parentage': {
        'parentA': parent('HOR01', 'creatures/rare/HOR01_firehorn.png', 'Fire'),
        'parentB': parent(
          'LET02',
          'creatures/common/LET02_waterlet.png',
          'Water',
        ),
      },
    };
    final parents = (await tester.runAsync(
      () => CultivationGrains.forPayload(payload, const ['Fire', 'Water']),
    ))!;
    final colors = const [Color(0xFFFF6B3D), Color(0xFF3FA9F5)];

    const cell = Size(180, 180);
    final frames = <ui.Image>[];
    ui.Image shoot(
      CultivationSphereField f, {
      required double spin,
      required double time,
      double ready = 0,
    }) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(Offset.zero & cell, Paint()..color = const Color(0xFF07060B));
      c.drawCircle(
        cell.center(Offset.zero),
        cell.width / 2 - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0x55FFD27A),
      );
      f.paint(
        c,
        cell.center(Offset.zero),
        cell.width * 0.36,
        spin: spin,
        time: time,
        ready: ready,
        colors: colors,
      );
      return rec.endRecording().toImageSync(
        cell.width.toInt(),
        cell.height.toInt(),
      );
    }

    final f = CultivationSphereField(parents);
    final r = cell.width * 0.36;
    for (final s in [0.0, 1.2]) {
      frames.add(shoot(f, spin: s, time: s));
    }
    // A finger held a little left of centre: it parts the grains round it.
    var spin = 1.2;
    f.pointer = Offset(-r * 0.25, -r * 0.1);
    for (var i = 0; i < 20; i++) {
      f.step(1 / 60, r, spin, 0, spin);
      spin += 1 / 60;
    }
    frames.add(shoot(f, spin: spin, time: spin));
    // Dragged across.
    for (var i = 0; i < 20; i++) {
      f.pointer = Offset(-r * 0.25 + r * 0.6 * i / 20, -r * 0.1);
      f.step(1 / 60, r, spin, 0, spin);
      spin += 1 / 60;
    }
    frames.add(shoot(f, spin: spin, time: spin));
    // Let go: it flows back.
    f.pointer = null;
    for (var i = 0; i < 20; i++) {
      f.step(1 / 60, r, spin, 0, spin);
      spin += 1 / 60;
    }
    frames.add(shoot(f, spin: spin, time: spin));
    // Ready: the sigil draws itself in, then it beats.
    for (final ready in [0.35, 0.7, 1.0]) {
      frames.add(shoot(f, spin: spin, time: 1.4, ready: ready));
    }
    frames.add(shoot(f, spin: spin, time: 2.6 * 3 + 0.05, ready: 1));
    frames.add(shoot(f, spin: spin, time: 2.6 * 3 + 0.6, ready: 1));
    // Carried into the hatch: the sigil gives way and it unwinds.
    for (final (u, ready) in [
      (0.15, 0.6),
      (0.35, 0.0),
      (0.6, 0.0),
      (0.85, 0.0),
    ]) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(Offset.zero & cell, Paint()..color = const Color(0xFF000000));
      f.paint(
        c,
        cell.center(Offset.zero),
        r,
        spin: spin + u * 4,
        time: 9,
        ready: ready,
        colors: colors,
        unwind: u,
        opacity: 1 - u * u,
      );
      frames.add(
        rec.endRecording().toImageSync(cell.width.toInt(), cell.height.toInt()),
      );
    }

    // Cost: four chambers' worth of frames.
    final sw = Stopwatch()..start();
    for (var i = 0; i < 240; i++) {
      final rec = ui.PictureRecorder();
      f.paint(
        Canvas(rec),
        cell.center(Offset.zero),
        r,
        spin: i / 60,
        time: i / 60,
        colors: colors,
      );
      rec.endRecording().dispose();
    }
    // ignore: avoid_print
    print(
      'per chamber per frame: ${(sw.elapsedMicroseconds / 240).round()}us '
      '(${f.length} grains)',
    );

    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < frames.length; i++) {
        c.drawImage(frames[i], Offset(i * (cell.width + 6), 0), Paint());
      }
      final img = rec.endRecording().toImageSync(
        (frames.length * (cell.width + 6)).round(),
        cell.height.toInt(),
      );
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
