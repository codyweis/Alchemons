import 'dart:ui';
import 'package:alchemons/widgets/fx/rift_vortex.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a crossing portal rift paints and dives without error', () {
    final f = RiftVortexField(grains: 520, ringGrains: 90, motes: 22)..open = 1;
    for (var i = 0; i < 30; i++) {
      f.step(1 / 60);
    }
    final rec = PictureRecorder();
    final c = Canvas(rec);
    f.paint(c, const Size(132, 132), const Offset(66, 66), 60,
        RiftPalette(Colors.orange), backdrop: false);
    f
      ..charge = 1
      ..dive = 1;
    f.paint(c, const Size(800, 400), const Offset(400, 200), 240,
        RiftPalette(Colors.orange), backdrop: false);
    rec.endRecording();
  });
}
