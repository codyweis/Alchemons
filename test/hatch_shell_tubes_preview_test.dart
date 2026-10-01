@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/animations/hatch_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Every family's shell as the old ribbons (top) and as stream tubes (below),
// held, forming and mid-unravel — plus what a frame costs.
//
//   SHELL_TUBES_OUT=/tmp/shell.png flutter test \
//     test/hatch_shell_tubes_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['SHELL_TUBES_OUT'];

  test('hatch shell tubes preview', () async {
    if (out == null) return;
    const size = Size(300, 420);
    const palA = [Color(0xFF1574A1), Color(0xFF38BDF8), Color(0xFF7DD3FC)];
    const palB = [Color(0xFFFF7E57), Color(0xFFFF8C00), Color(0xFFFFD700)];
    const palR = [Color(0xFF6C838E), Color(0xFF93C5FD), Color(0xFFFCA5A5)];

    Future<ui.Image> shoot(HatchShellSpecies sp, double t, bool tubes) async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF07060B));
      HatchShellPainter(
        t: t,
        clock: t * 6.6,
        model: HatchShellModel(species: sp, reduced: false, tubes: tubes),
        paletteA: palA,
        paletteB: palB,
        paletteResult: palR,
        behaviorA: ShellElementBehavior.of('T002'),
        behaviorB: ShellElementBehavior.of('T001'),
        behaviorResult: ShellElementBehavior.of('T005'),
      ).paint(c, size);
      return rec.endRecording().toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
    }

    final cols = HatchShellSpecies.values.length;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    var row = 0;
    for (final (t, tubes) in [
      (0.76, false),
      (0.76, true),
      (0.4, true),
      (0.92, true),
    ]) {
      for (var i = 0; i < cols; i++) {
        final img = await shoot(HatchShellSpecies.values[i], t, tubes);
        c.drawImage(
          img,
          Offset(i * (size.width + 4), row * (size.height + 4)),
          Paint(),
        );
      }
      row++;
    }
    final img = await rec.endRecording().toImage(
      (cols * (size.width + 4)).round(),
      (row * (size.height + 4)).round(),
    );
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(bytes!.buffer.asUint8List());

    // Cost of a held-shell frame, grains vs ribbons, for the densest family.
    double cost(bool tubes) {
      final model = HatchShellModel(
        species: HatchShellSpecies.mystic,
        reduced: false,
        tubes: tubes,
      );
      final sw = Stopwatch()..start();
      for (var i = 0; i < 120; i++) {
        final r = ui.PictureRecorder();
        HatchShellPainter(
          t: 0.6 + i / 1200,
          clock: (0.6 + i / 1200) * 6.6,
          model: model,
          paletteA: palA,
          paletteB: palB,
          paletteResult: palR,
          behaviorA: ShellElementBehavior.of('T002'),
          behaviorB: ShellElementBehavior.of('T001'),
          behaviorResult: ShellElementBehavior.of('T005'),
        ).paint(Canvas(r), size);
        r.endRecording().dispose();
      }
      return sw.elapsedMicroseconds / 120;
    }

    cost(true);
    // ignore: avoid_print
    print(
      'per frame: ribbons ${cost(false).round()}us, '
      'tubes ${cost(true).round()}us',
    );
  });
}
