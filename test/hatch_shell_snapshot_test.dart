import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/animations/hatch_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Writes PNGs of the Dart shell so its output can be compared against the
/// HTML prototype by eye. Not an assertion — a visual diff aid.
void main() {
  test('write shell snapshots', () async {
    const size = Size(360, 640);
    final out = Directory('build/shell_snap')..createSync(recursive: true);
    for (final sp in HatchShellSpecies.values) {
      final model = HatchShellModel(species: sp, reduced: false);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF07060B),
      );
      HatchShellPainter(
        t: 0.76,
        clock: 0.76 * 6.6,
        model: model,
        paletteA: const [
          Color(0xFF1574A1),
          Color(0xFF38BDF8),
          Color(0xFF7DD3FC),
        ],
        paletteB: const [
          Color(0xFFFF7E57),
          Color(0xFFFF8C00),
          Color(0xFFFFD700),
        ],
        paletteResult: const [
          Color(0xFF6C838E),
          Color(0xFF93C5FD),
          Color(0xFFFCA5A5),
        ],
        behaviorA: ShellElementBehavior.of('T002'),
        behaviorB: ShellElementBehavior.of('T001'),
        behaviorResult: ShellElementBehavior.of('T005'),
      ).paint(canvas, size);
      final img = await rec.endRecording().toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${out.path}/${sp.name}.png',
      ).writeAsBytesSync(bd!.buffer.asUint8List());
    }
    // Assert on the files this test wrote, not on how many entries the
    // directory happens to hold. hatch_shell_device_scale_test writes its
    // dev_t*.png frames into build/shell_snap too, so counting entries made
    // this fail with 14 vs 8 purely because the other test had also run.
    for (final sp in HatchShellSpecies.values) {
      expect(
        File('${out.path}/${sp.name}.png').existsSync(),
        isTrue,
        reason: 'missing snapshot for ${sp.name}',
      );
    }
  });
}
