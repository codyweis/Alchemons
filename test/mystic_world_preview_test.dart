@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the Mystic worlds' painters straight out of the shared module, so
/// what this shows is what the game draws.
///
///   MYSTIC_WORLD_OUT=/tmp flutter test test/mystic_world_preview_test.dart \
///     --tags preview
void main() {
  final outDir = Platform.environment['MYSTIC_WORLD_OUT'];

  // A plain test, not testWidgets: this draws to a PictureRecorder and never
  // builds a widget, and the widget binding's settle machinery was leaving the
  // test alive for its full ten-minute timeout after the PNG was already
  // written — which failed the whole suite for a preview harness.
  test('mystic world preview', () async {
    const cellW = 460.0;
    const cellH = 520.0;
    const cols = 5;
    const rows = 3;
    const w = cellW * cols;
    const h = cellH * rows;

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF060412),
    );

    Offset cell(int col, int row) =>
        Offset(cellW * col + cellW / 2, cellH * row + cellH / 2);

    // Row 0 — the grove growing, then lashing through a swing.
    for (var i = 0; i < cols; i++) {
      final grow = [0.25, 0.6, 1.0, 1.0, 1.0][i];
      final swing = [0.0, 0.0, 0.0, 1.0, 0.45][i];
      final at = cell(i, 0) + const Offset(-40, 200);
      drawMysticGroveVine(
        canvas: canvas,
        root: at,
        lashes: true,
        growth: grow,
        swing: swing,
        aimAngle: -0.5,
        reach: 200,
        seed: 1.3,
        alpha: 1,
        time: 3.0 + i * 0.7,
        plant: elementColor('Plant'),
      );
    }

    // Row 1 — the spitter, closed through firing.
    for (var i = 0; i < cols; i++) {
      final grow = [0.25, 0.6, 1.0, 1.0, 1.0][i];
      final fire = [0.0, 0.0, 0.0, 1.0, 0.5][i];
      final at = cell(i, 1) + const Offset(-40, -200);
      drawMysticGroveVine(
        canvas: canvas,
        root: at,
        lashes: false,
        growth: grow,
        swing: fire,
        aimAngle: 0.6,
        reach: 620,
        seed: 4.1,
        alpha: 1,
        time: 3.0 + i * 0.7,
        plant: elementColor('Plant'),
      );
    }

    // Row 2a — ground cover per element, so two brown worlds can be compared.
    const cover = ['Plant', 'Mud', 'Earth', 'Fire', 'Poison'];
    for (var i = 0; i < cover.length; i++) {
      for (var k = 0; k < 3; k++) {
        drawMysticFlora(
          canvas: canvas,
          at: cell(i, 2) + Offset(-70.0 + k * 70, -150),
          element: cover[i],
          size: 1.4,
          bloom: [0.4, 1.0, 1.0][k],
          seed: k * 2.1,
          time: k * 1.7,
          tint: elementColor(cover[i]),
        );
      }
    }

    // Row 2 — the maw opening and holding, and a pair of revenants.
    for (var i = 0; i < 4; i++) {
      final open = [0.3, 0.65, 1.0, 1.0][i];
      drawMysticMaw(
        canvas: canvas,
        centre: cell(i, 2),
        pullRadius: 150,
        horizonRadius: 26,
        open: open,
        spin: i * 0.9,
        alpha: 1,
        time: i * 1.9,
      );
    }
    for (var i = 0; i < 3; i++) {
      drawMysticRevenant(
        canvas: canvas,
        position: cell(4, 2) + Offset(0, -60.0 + i * 60),
        velocity: const Offset(90, 0),
        radius: 13,
        rise: [0.2, 0.6, 1.0][i],
        life: 9,
        alpha: 1,
        time: i * 1.1,
        seed: i * 2.0,
      );
    }

    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    expect(png, isNotNull);
    if (outDir != null && outDir.isNotEmpty) {
      final file = File('$outDir/mystic_worlds.png')
        ..writeAsBytesSync(png!.buffer.asUint8List());
      // ignore: avoid_print
      print('MYSTIC_WORLD_PREVIEW ${file.path}');
    }
    img.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
