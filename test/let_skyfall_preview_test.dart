@Tags(['preview'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders a Let meteor's whole descent — telegraph, fall, landing — by
/// actually stepping the shared skyfall runtime, so the preview shows what
/// the game shows rather than a pose someone imagined.
///
///   LET_FALL_OUT=/tmp flutter test test/let_skyfall_preview_test.dart \
///     --tags preview
void main() {
  final outDir = Platform.environment['LET_FALL_OUT'];
  final only = Platform.environment['LET_FALL_ELEMENTS'];

  String? labelFont;
  setUpAll(() async {
    const candidates = [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (!file.existsSync()) continue;
      await (FontLoader('SheetLabel')
            ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
          .load();
      labelFont = 'SheetLabel';
      return;
    }
  });

  testWidgets('let skyfall descent preview', (tester) async {
    final elements = only != null && only.isNotEmpty
        ? only.split(',')
        : List<String>.from(kCosmicAbilityElements);

    // One cell per sampled moment of the drop. The impact point sits low in
    // the cell so there is room above it for the meteor to come down through.
    const cellW = 320.0;
    const cellH = 400.0;
    const labelW = 104.0;
    const samples = [0.0, 0.32, 0.60, 0.82, 0.99];
    const impactAges = [0.12, 0.55];
    final cols = samples.length + impactAges.length;

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
      'LET SKYFALL  —  telegraph, descent, landing',
      const Offset(10, 12),
      const Color(0xFFE8E2D6),
      size: 15,
    );
    for (var c = 0; c < cols; c++) {
      final isFall = c < samples.length;
      label(
        isFall
            ? 'fall ${(samples[c] * 100).round()}%'
            : 'impact +${(impactAges[c - samples.length] * 0.42 * 1000).round()}ms',
        Offset(labelW + c * cellW + 8, 22),
        isFall ? const Color(0xFF9FB6D4) : const Color(0xFFD4B78F),
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
        cosmicSpecialAbilityName('let', element),
        Offset(10, top + cellH / 2 + 2),
        const Color(0xFF7C8798),
        size: 9,
      );

      // The impact point, placed low in each cell.
      final impactLocal = Offset(cellW * 0.5, cellH - 112);

      for (var c = 0; c < samples.length; c++) {
        final originX = labelW + c * cellW;
        canvas.save();
        canvas.translate(originX, top);
        canvas.clipRect(const Rect.fromLTWH(0, 0, cellW, cellH));

        // Fresh cast per cell, stepped forward to this sample's progress.
        final result = createCosmicSpecialAbility(
          origin: impactLocal - const Offset(260, 40),
          baseAngle: 0.2,
          family: 'let',
          element: element,
          damage: 40,
          maxHp: 400,
          targetPos: impactLocal,
        );
        final meteor = result.projectiles.first;
        final target = samples[c];
        const step = 1 / 240.0;
        var guard = 0;
        while (meteor.skyfallProgress < target && guard++ < 600) {
          CosmicAbilityRuntime.advanceSkyfall(meteor, step, null);
        }

        drawLetSkyfallTelegraph(
          canvas: canvas,
          centre: meteor.skyfallImpact,
          color: color,
          radius: letSkyfallBlastRadius(meteor),
          progress: meteor.skyfallProgress,
          time: 1.2 + c * 0.4,
        );
        drawLetElementalProjectileVisual(
          canvas: canvas,
          projectile: meteor,
          position: meteor.position,
          color: color,
          time: 1.2 + c * 0.4,
        );
        canvas.restore();
      }

      for (var c = 0; c < impactAges.length; c++) {
        final originX = labelW + (samples.length + c) * cellW;
        canvas.save();
        canvas.translate(originX, top);
        canvas.clipRect(const Rect.fromLTWH(0, 0, cellW, cellH));
        final probe = createCosmicSpecialAbility(
          origin: impactLocal - const Offset(260, 40),
          baseAngle: 0.2,
          family: 'let',
          element: element,
          damage: 40,
          maxHp: 400,
          targetPos: impactLocal,
        ).projectiles.first;
        drawLetSkyfallImpact(
          canvas: canvas,
          centre: impactLocal,
          color: color,
          radius: letSkyfallBlastRadius(probe),
          age: impactAges[c],
        );
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
      '$outDir/let_skyfall_preview.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  }, skip: outDir == null);
}
