import 'dart:ui' as ui;
import 'package:alchemons/widgets/animations/hatch_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('genesis mote beat actually renders pixels', () async {
    const size = Size(360, 640);
    // t = 0.10 is inside moteHold (0.17): every strand is still a dot.
    for (final t in [0.10, 0.25]) {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec, Offset.zero & size);
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF000000));
      HatchShellPainter(
        t: t,
        clock: t * 6.6,
        model: HatchShellModel(species: HatchShellSpecies.meteor, reduced: false),
        paletteA: const [Color(0xFF1574A1), Color(0xFF38BDF8), Color(0xFF7DD3FC)],
        paletteB: const [Color(0xFFFF7E57), Color(0xFFFF8C00), Color(0xFFFFD700)],
        paletteResult: const [Color(0xFF6C838E), Color(0xFF93C5FD), Color(0xFFFCA5A5)],
        behaviorA: ShellElementBehavior.of('T002'),
        behaviorB: ShellElementBehavior.of('T001'),
        behaviorResult: ShellElementBehavior.of('T005'),
      ).paint(canvas, size);
      final img = await rec.endRecording().toImage(360, 640);
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      var lit = 0;
      for (int i = 0; i < bd!.lengthInBytes; i += 4) {
        if (bd.getUint8(i) > 12 || bd.getUint8(i + 1) > 12 || bd.getUint8(i + 2) > 12) lit++;
      }
      print('t=$t lit pixels: $lit');
      expect(lit, greaterThan(200),
          reason: 'the mote/string beat at t=$t drew almost nothing');
    }
  });
}
