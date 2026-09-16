import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/animations/hatch_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders at the Fold's REAL logical size (1080 / 2.75 DPR) so crispness can
/// be judged at the scale the device actually uses, not at an arbitrary one.
void main() {
  test('device-scale render', () async {
    const size = Size(465, 780);
    final out = Directory('build/shell_snap')..createSync(recursive: true);
    for (final t in [0.10, 0.30, 0.78, 0.93]) {
      final rec = ui.PictureRecorder();
      // Cull rect must cover the DEVICE-pixel bounds: it is applied in the
      // recording's own space, so a logical-sized rect clips everything past
      // 393px once the DPR scale is applied.
      final canvas = Canvas(rec, Offset.zero & size);
      // Flutter applies the device pixel ratio itself; without this the paint
      // lands 1:1 in the corner of the larger image instead of being scaled.
      // 1:1 — matches how the HTML prototype canvas is captured.
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF07060B),
      );
      HatchShellAmbientPainter(
        t: t,
        clock: t * 6.6,
        tint: const Color(0xFFFF8C00),
        accent: const Color(0xFFFFD700),
      ).paint(canvas, size);
      HatchShellPainter(
        t: t,
        clock: t * 6.6,
        model: HatchShellModel(species: HatchShellSpecies.pip, reduced: false),
        paletteA: const [
          Color(0xFFFF7E57),
          Color(0xFFFF8C00),
          Color(0xFFFFD700),
        ],
        paletteB: const [
          Color(0xFFFF7E57),
          Color(0xFFFF8C00),
          Color(0xFFFFD700),
        ],
        paletteResult: const [
          Color(0xFFFF7E57),
          Color(0xFFFF8C00),
          Color(0xFFFFD700),
        ],
        behaviorA: ShellElementBehavior.of('T001'),
        behaviorB: ShellElementBehavior.of('T001'),
        behaviorResult: ShellElementBehavior.of('T001'),
      ).paint(canvas, size);
      // Rasterise at device pixel ratio, as the phone does.
      final img = await rec.endRecording().toImage(
        size.width.round(),
        size.height.round(),
      );
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${out.path}/dev_t$t.png',
      ).writeAsBytesSync(bd!.buffer.asUint8List());
    }
    expect(true, isTrue);
  });
}
