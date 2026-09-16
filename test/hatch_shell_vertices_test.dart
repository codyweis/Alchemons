import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which BlendMode makes `drawVertices` honour per-vertex colours (including
/// their alpha) is the one thing the shell painter cannot be reasoned about
/// from the docs — the vertex colours are the *source* and the paint is the
/// destination, which is the opposite of the intuitive reading. This pins it.
Future<ui.Image> _render(BlendMode mode, Color paintColor) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, 8, 8));
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 8, 8),
    Paint()..color = const Color(0xFF000000),
  );

  // One full-quad pair of triangles, every vertex opaque green.
  final positions = Float32List.fromList([
    0, 0, 8, 0, 0, 8, //
    8, 0, 8, 8, 0, 8,
  ]);
  final colors = Int32List.fromList(List.filled(6, 0xFF00FF00));
  final verts = ui.Vertices.raw(
    ui.VertexMode.triangles,
    positions,
    colors: colors,
  );
  canvas.drawVertices(verts, mode, Paint()..color = paintColor);
  final pic = rec.endRecording();
  return pic.toImage(8, 8);
}

Future<Color> _centerPixel(ui.Image img) async {
  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final o = (4 * 8 + 4) * 4; // pixel (4,4)
  return Color.fromARGB(
    bd!.getUint8(o + 3),
    bd.getUint8(o),
    bd.getUint8(o + 1),
    bd.getUint8(o + 2),
  );
}

void main() {
  const green = Color(0xFF00FF00);
  const red = Color(0xFFFF0000); // paint colour, must be ignored

  test('drawVertices: which blend mode yields the vertex colours', () async {
    final results = <BlendMode, Color>{};
    for (final mode in [
      BlendMode.src,
      BlendMode.dst,
      BlendMode.srcOver,
      BlendMode.modulate,
    ]) {
      results[mode] = await _centerPixel(await _render(mode, red));
    }
    // Printed so the answer is visible even when the expectation below is
    // what changes.
    // ignore: avoid_print
    print('drawVertices blend probe (vertex=green, paint=red): $results');

    // Finding: with a paint that has no SHADER, every blend mode yields the
    // vertex colours — the paint's plain colour does not participate. The
    // shell painter therefore only needs its paint to stay shader-less.
    for (final e in results.entries) {
      expect(
        e.value,
        green,
        reason: 'vertex colours must survive ${e.key} with a shader-less '
            'paint; the shell painter depends on this',
      );
    }
    expect(results[BlendMode.srcOver], green);
  });

  test('drawVertices honours per-vertex alpha', () async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, 8, 8));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 8, 8),
      Paint()..color = const Color(0xFF000000),
    );
    final positions = Float32List.fromList([0, 0, 8, 0, 0, 8, 8, 0, 8, 8, 0, 8]);
    // Half-transparent white over black should land near mid grey.
    final colors = Int32List.fromList(List.filled(6, 0x80FFFFFF));
    final verts = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      colors: colors,
    );
    canvas.drawVertices(verts, BlendMode.srcOver, Paint());
    final img = await rec.endRecording().toImage(8, 8);
    final px = await _centerPixel(img);
    // ignore: avoid_print
    print('per-vertex alpha probe (0x80FFFFFF over black): $px');
    expect(
      (px.r * 255).round(),
      inInclusiveRange(100, 160),
      reason: 'per-vertex alpha must blend, not render fully opaque',
    );
  });
}
