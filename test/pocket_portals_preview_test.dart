@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/rift_vortex.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The Nexus pocket's four portals at game scale (orbit 250, rift radius 140).
//   POCKET_OUT=/tmp/pocket.png flutter test test/pocket_portals_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['POCKET_OUT'];
  test('pocket portals preview', () async {
    if (out == null) return;
    const w = 900.0, h = 900.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF020008));
    const cols = [Color(0xFFFF5722), Color(0xFF448AFF), Color(0xFFB08968), Color(0xFF81D4FA)];
    const centre = Offset(w / 2, h / 2);
    final pos = [
      centre + const Offset(0, -250),
      centre + const Offset(250, 0),
      centre + const Offset(0, 250),
      centre + const Offset(-250, 0),
    ];
    for (var i = 0; i < 4; i++) {
      final f = RiftVortexField(grains: 900, ringGrains: 160, motes: 40, core: 0.27, grainSize: 2.8)..open = 1;
      for (var k = 0; k < 120; k++) {
        f.step(1 / 60);
      }
      f.paint(c, Size.zero, pos[i], 165, RiftPalette(cols[i]), backdrop: false);
    }
    final img = await rec.endRecording().toImage(w.round(), h.round());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(data!.buffer.asUint8List());
  });
}
