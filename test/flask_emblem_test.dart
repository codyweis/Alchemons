import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/extraction_vessel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The harvest flask paints at any level. A nearly empty flask's liquid is
// thinner than a grain, and the grains' clamp there once had its bounds the
// wrong way round — the passage from home threw mid-paint.
void main() {
  void paint(double radius, double level) {
    final rec = ui.PictureRecorder();
    paintFlaskEmblem(
      Canvas(rec),
      Offset(radius * 2, radius * 2),
      radius,
      3.7,
      ink: const Color(0xFFE0A040),
      level: level,
    );
    rec.endRecording().dispose();
  }

  test('a nearly empty flask paints, small or large', () {
    for (final radius in [12.0, 30.0, 90.0, 300.0, 420.0]) {
      for (var level = 0.0; level <= 0.06; level += 0.0005) {
        expect(
          () => paint(radius, level),
          returnsNormally,
          reason: 'radius $radius, level $level',
        );
      }
    }
  });

  test('empty and full flasks paint', () {
    for (final level in [0.0, 1.0]) {
      expect(() => paint(30, level), returnsNormally);
    }
  });
}
