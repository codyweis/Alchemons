@Tags(['preview'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders every Let (meteor) element variant to a PNG contact sheet so the
/// artwork can be eyeballed instead of imagined: the falling meteor core at
/// several animation phases, then the ground fallout zone it leaves behind.
/// Not an assertion test — tagged `preview` so it stays out of ordinary runs.
///
///   LET_VFX_OUT=docs flutter test test/let_family_vfx_contact_sheet_test.dart \
///     --tags preview
void main() {
  final outDir = Platform.environment['LET_VFX_OUT'];

  testWidgets('let family vfx contact sheet', (tester) async {
    const cell = 168.0;
    const labelW = 96.0;
    // Four falling-meteor phases, then three fallout-zone phases.
    const fallTimes = [0.30, 0.72, 1.15, 1.58];
    const zoneTimes = [0.35, 1.60, 3.10];
    final cols = fallTimes.length + zoneTimes.length;

    final elements = List<String>.from(kCosmicAbilityElements);
    final w = labelW + cell * cols;
    final h = 34.0 + cell * elements.length;

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF06050E),
    );

    void label(String s, Offset at, Color c, {double size = 11}) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: c,
            fontSize: size,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at);
    }

    for (var c = 0; c < cols; c++) {
      final isFall = c < fallTimes.length;
      label(
        isFall ? 'fall t=${fallTimes[c]}' : 'zone t=${zoneTimes[c - 4]}',
        Offset(labelW + c * cell + 8, 12),
        isFall ? const Color(0xFF9FB6D4) : const Color(0xFFD4B78F),
        size: 10,
      );
    }

    for (var r = 0; r < elements.length; r++) {
      final element = elements[r];
      final color = elementColor(element);
      final top = 34.0 + r * cell;
      if (r.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(0, top, w, cell),
          Paint()..color = const Color(0x0AFFFFFF),
        );
      }
      label(element, Offset(10, top + cell / 2 - 14), color, size: 13);
      label(
        cosmicSpecialAbilityName('let', element),
        Offset(10, top + cell / 2 + 2),
        const Color(0xFF7C8798),
        size: 9,
      );

      final result = createCosmicSpecialAbility(
        origin: Offset.zero,
        baseAngle: 1.05,
        family: 'let',
        element: element,
        damage: 40,
        maxHp: 400,
      );
      final meteor = result.projectiles.first;

      for (var c = 0; c < fallTimes.length; c++) {
        final centre = Offset(labelW + c * cell + cell / 2, top + cell / 2);
        drawLetElementalProjectileVisual(
          canvas: canvas,
          projectile: meteor,
          position: centre,
          color: color,
          time: fallTimes[c],
        );
      }

      final zone = Projectile(
        position: Offset.zero,
        angle: 0,
        element: element,
        damage: 0,
        life: 4.0,
        speedMultiplier: 0,
        stationary: true,
        piercing: true,
        radiusMultiplier: 4.4,
        visualScale: 1.5,
        visualStyle: ProjectileVisualStyle.letShard,
        abilityFamily: 'let',
        effectRadius: 60,
        effectDuration: 4.0,
      );
      for (var c = 0; c < zoneTimes.length; c++) {
        final centre = Offset(
          labelW + (fallTimes.length + c) * cell + cell / 2,
          top + cell / 2,
        );
        drawLetElementalProjectileVisual(
          canvas: canvas,
          projectile: zone,
          position: centre,
          color: color,
          time: zoneTimes[c],
        );
      }
    }

    final pic = rec.endRecording();
    ByteData? bytes;
    await tester.runAsync(() async {
      final img = await pic.toImage(w.round(), h.round());
      bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    });
    File(
      '$outDir/let_family_vfx_contact_sheet.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  }, skip: outDir == null);
}
