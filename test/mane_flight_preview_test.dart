@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders Mane casts with the projectiles actually FLOWN rather than posed at
/// their spawn offsets.
///
/// The static contact sheet draws every projectile of a cast on top of itself
/// at t=0, which makes a four-projectile fan look like a bundle of sticks and a
/// wide fan look like a starburst — neither of which is what the player sees
/// once the things separate. Judging the art off that sheet would be redesigning
/// an artifact of the preview.
///
///   MANE_FLIGHT_OUT=/tmp flutter test test/mane_flight_preview_test.dart \
///     --tags preview
void main() {
  final outDir = Platform.environment['MANE_FLIGHT_OUT'];
  final only = Platform.environment['MANE_FLIGHT_ELEMENTS'];

  String? labelFont;
  setUpAll(() async {
    const candidates = [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (!file.existsSync()) continue;
      await (FontLoader('SheetLabel')..addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)),
          ))
          .load();
      labelFont = 'SheetLabel';
      return;
    }
  });

  testWidgets('mane flight preview', (tester) async {
    final elements = only != null && only.isNotEmpty
        ? only.split(',')
        : List<String>.from(kCosmicAbilityElements);

    const cellW = 420.0;
    const cellH = 260.0;
    const labelW = 104.0;
    // Seconds of flight simulated before each column is drawn.
    const moments = [0.04, 0.12, 0.24, 0.40];
    final cols = moments.length;

    final w = labelW + cellW * cols;
    final h = 40.0 + cellH * elements.length;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF06050E),
    );

    void label(String s, Offset at, Color c, {double size = 11}) {
      TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: c,
            fontSize: size,
            fontWeight: FontWeight.w700,
            fontFamily: labelFont,
          ),
        ),
        textDirection: TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, at);
    }

    label(
      'MANE  —  in flight (projectiles actually moved, not posed at spawn)',
      const Offset(10, 12),
      const Color(0xFFE8E2D6),
      size: 15,
    );
    for (var c = 0; c < cols; c++) {
      label(
        't = ${moments[c]}s',
        Offset(labelW + c * cellW + 8, 24),
        const Color(0xFF9FB6D4),
        size: 10,
      );
    }

    for (var r = 0; r < elements.length; r++) {
      final element = elements[r];
      final color = elementColor(element);
      final top = 40.0 + r * cellH;
      if (r.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(0, top, w, cellH),
          Paint()..color = const Color(0x0AFFFFFF),
        );
      }
      label(element, Offset(10, top + cellH / 2 - 14), color, size: 13);
      label(
        cosmicSpecialAbilityName('mane', element),
        Offset(10, top + cellH / 2 + 2),
        const Color(0xFF7C8798),
        size: 9,
      );
      final castLabelShown = <String>{};

      for (var c = 0; c < cols; c++) {
        final originX = labelW + c * cellW;
        canvas.save();
        canvas.translate(originX, top);
        canvas.clipRect(const Rect.fromLTWH(0, 0, cellW, cellH));

        // Cast from the left edge, flying right — the reading direction, so
        // the fan opens across the cell.
        const origin = Offset(28, cellH / 2);
        final result = createCosmicSpecialAbility(
          origin: origin,
          baseAngle: 0,
          family: 'mane',
          element: element,
          damage: 40,
          maxHp: 400,
          casterBeauty: 4.5,
          casterIntelligence: 4.5,
          targetPos: origin + const Offset(240, 0),
        );

        // Fly them. Straight-line integration at the projectile's own speed,
        // which is what the games do for a non-homing, non-orbiting shot.
        const step = 1 / 120.0;
        for (var t = 0.0; t < moments[c]; t += step) {
          for (final p in result.projectiles) {
            if (p.stationary || p.orbitCenter != null) continue;
            final spd = Projectile.speed * p.speedMultiplier;
            p.position += Offset(cos(p.angle), sin(p.angle)) * spd * step;
          }
        }

        for (final p in result.projectiles) {
          final drawn = drawManeElementalProjectileVisual(
            canvas: canvas,
            projectile: p,
            position: p.position,
            color: color,
            time: 1.0 + moments[c],
          );
          if (!drawn) {
            drawGenericProjectileVisual(
              canvas: canvas,
              projectile: p,
              position: p.position,
              color: color,
              time: 1.0 + moments[c],
            );
          }
        }
        if (castLabelShown.add(element)) {
          label(
            '${result.projectiles.length} projectiles',
            const Offset(8, 8),
            const Color(0xFF55606E),
            size: 9,
          );
        }
        canvas.restore();
      }
    }

    final pic = rec.endRecording();
    ByteData? bytes;
    await tester.runAsync(() async {
      final img = await pic.toImage(w.round(), h.round());
      bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    });
    File(
      '$outDir/mane_flight_preview.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  }, skip: outDir == null);
}
