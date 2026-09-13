@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
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

    // Row 0b — fissures at rest and flaring, over a patch of floor, so the
    // question "does this take over the screen" can actually be looked at.
    for (var i = 0; i < 5; i++) {
      final flare = [0.0, 0.0, 0.0, 0.55, 1.0][i];
      final rng = Random(7 + i);
      for (var c = 0; c < 3; c++) {
        final mid = cell(i, 0) + Offset(-120.0 + c * 120, -40.0 + c * 70);
        final bearing = rng.nextDouble() * pi;
        final dir = Offset(cos(bearing), sin(bearing));
        final normal = Offset(-dir.dy, dir.dx);
        final length = 190.0 + rng.nextDouble() * 210.0;
        final wander = rng.nextDouble() * 6.28;
        final pts = <Offset>[
          for (var k = 0; k <= 8; k++)
            () {
              final f = k / 8 - 0.5;
              final jag =
                  sin(f * 9.0 + wander) * 17.0 + sin(f * 21.0 + wander) * 6.0;
              return mid + dir * (length * f) + normal * jag;
            }(),
        ];
        drawMysticFissure(
          canvas: canvas,
          points: pts,
          alpha: 1,
          flare: c == 1 ? flare : 0,
          seed: c * 2.1 + i,
          time: i * 0.9,
        );
      }
    }

    // Row 1b — the two spinning worlds side by side. They are the pair most
    // at risk of reading as the same effect in two colours.
    for (var i = 0; i < 3; i++) {
      drawMysticTornado(
        canvas: canvas,
        at: cell(i, 1) + const Offset(0, 150),
        radius: 96,
        phase: i * 1.3,
        travelAngle: i * 0.9,
        alpha: 1,
        time: i * 1.1,
      );
    }
    for (var i = 3; i < 5; i++) {
      drawMysticMaelstrom(
        canvas: canvas,
        centre: cell(i, 1) + const Offset(0, 60),
        radius: 150,
        phase: i * 1.1,
        alpha: 1,
        time: i * 0.7,
      );
    }

    // Row 2a — ground cover per element, so two brown worlds can be compared.
    const cover = ['Plant', 'Mud', 'Ice', 'Dust', 'Poison'];
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
