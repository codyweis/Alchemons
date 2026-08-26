@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders every authored cosmic ability — all 8 families x 17 elements — to
/// one PNG contact sheet per family, so the artwork can be eyeballed instead of
/// imagined.
///
/// Each row is an element; each column is a later moment in the cast. Every
/// projectile the ability actually spawns is drawn, laid out at its own spawn
/// offset, through the same renderer chain the game uses. Not an assertion
/// test — tagged `preview` so it stays out of ordinary runs.
///
///   VFX_SHEET_OUT=docs/ability_sheets flutter test \
///     test/family_vfx_contact_sheet_test.dart --tags preview
void main() {
  final outDir = Platform.environment['VFX_SHEET_OUT'];

  // flutter_test substitutes Ahem for every font, which renders each glyph as
  // a filled box — the sheet's labels would be unreadable. Borrow a real font
  // off the host so the labels are legible; if none is found the sheet still
  // renders, just with boxed text.
  String? labelFont;
  setUpAll(() async {
    const candidates = [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/System/Library/Fonts/Supplemental/Verdana.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final bytes = file.readAsBytesSync();
      await (FontLoader(
        'SheetLabel',
      )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
      labelFont = 'SheetLabel';
      return;
    }
  });

  /// The survival draw order, verbatim: each authored family renderer gets a
  /// chance to claim the projectile by its visual style, and whatever none of
  /// them claims falls through to the shared generic silhouette.
  void drawOne(
    Canvas canvas,
    Projectile p,
    Offset at,
    Color color,
    double time,
  ) {
    final claimed =
        drawMaskElementalProjectileVisual(
          canvas: canvas,
          projectile: p,
          position: at,
          color: color,
          time: time,
        ) ||
        drawLetElementalProjectileVisual(
          canvas: canvas,
          projectile: p,
          position: at,
          color: color,
          time: time,
        ) ||
        drawPipElementalProjectileVisual(
          canvas: canvas,
          projectile: p,
          position: at,
          color: color,
          time: time,
        ) ||
        drawManeElementalProjectileVisual(
          canvas: canvas,
          projectile: p,
          position: at,
          color: color,
          time: time,
        ) ||
        drawHornElementalProjectileVisual(
          canvas: canvas,
          projectile: p,
          position: at,
          color: color,
          time: time,
        );
    if (!claimed) {
      drawGenericProjectileVisual(
        canvas: canvas,
        projectile: p,
        position: at,
        color: color,
        time: time,
      );
    }
    drawProjectileRoleOverlay(
      canvas: canvas,
      projectile: p,
      position: at,
      color: color,
      time: time,
    );
  }

  /// One-line description of what a cast does when it spawns no projectiles at
  /// all (charges, shields, heals), so those cells say why they are empty.
  String nonProjectileNote(CosmicSpecialResult r) {
    final parts = <String>[];
    if (r.beams.isNotEmpty) parts.add('${r.beams.length} beam');
    if (r.shieldHp > 0) parts.add('shield ${r.shieldHp}');
    if (r.chargeTimer > 0) parts.add('charge ${r.chargeTimer}s');
    if (r.windUpTime > 0) parts.add('wind-up ${r.windUpTime}s');
    if (r.selfHeal > 0) parts.add('self-heal ${r.selfHeal}');
    if (r.shipHeal > 0) parts.add('ship-heal ${r.shipHeal}');
    if (r.blessingTimer > 0) parts.add('blessing ${r.blessingTimer}s');
    if (r.basicHasteTimer > 0) parts.add('haste ${r.basicHasteTimer}s');
    return parts.isEmpty ? 'no visual payload' : parts.join('  ·  ');
  }

  Future<void> renderFamily(WidgetTester tester, String family) async {
    const cell = 190.0;
    const labelW = 132.0;
    const headerH = 64.0;
    const times = [0.20, 0.60, 1.10, 1.70, 2.40, 3.20];

    final elements = List<String>.from(
      kCosmicAbilityContractElementsByFamily[family] ?? kCosmicAbilityElements,
    );
    final w = labelW + cell * times.length;
    final h = headerH + cell * elements.length;

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF06050E),
    );

    void label(
      String s,
      Offset at,
      Color c, {
      double size = 11,
      FontWeight weight = FontWeight.w700,
      double maxWidth = double.infinity,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: c,
            fontSize: size,
            fontWeight: weight,
            fontFamily: labelFont,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      tp.paint(canvas, at);
    }

    label(
      '${family.toUpperCase()}  —  cosmic special, all ${elements.length} elements',
      const Offset(12, 8),
      const Color(0xFFE8DCC0),
      size: 15,
    );
    label(
      'projectiles only — beams and charge/aura payloads are drawn by the game, not the shared VFX layer',
      const Offset(12, 28),
      const Color(0xFF6B7688),
      size: 9,
      weight: FontWeight.w500,
    );
    for (var c = 0; c < times.length; c++) {
      label(
        't = ${times[c].toStringAsFixed(2)}s',
        Offset(labelW + c * cell + 8, 47),
        const Color(0xFF8C99AB),
        size: 10,
      );
    }

    for (var r = 0; r < elements.length; r++) {
      final element = elements[r];
      final color = elementColor(element);
      final top = headerH + r * cell;
      if (r.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(0, top, w, cell),
          Paint()..color = const Color(0x0AFFFFFF),
        );
      }
      canvas.drawLine(
        Offset(0, top),
        Offset(w, top),
        Paint()..color = const Color(0x14FFFFFF),
      );

      final result = createCosmicSpecialAbility(
        origin: Offset.zero,
        baseAngle: -1.05,
        family: family,
        element: element,
        damage: 40,
        maxHp: 400,
      );
      final projectiles = result.projectiles;

      label(
        element,
        Offset(10, top + 14),
        color,
        size: 14,
        maxWidth: labelW - 16,
      );
      label(
        cosmicSpecialAbilityName(family, element),
        Offset(10, top + 34),
        const Color(0xFF9AA6B8),
        size: 9,
        weight: FontWeight.w600,
        maxWidth: labelW - 16,
      );
      label(
        projectiles.isEmpty
            ? nonProjectileNote(result)
            : '${projectiles.length} projectile'
                  '${projectiles.length == 1 ? '' : 's'}'
                  '${result.beams.isEmpty ? '' : ' + ${result.beams.length} beam'}',
        Offset(10, top + 68),
        const Color(0xFF6B7688),
        size: 8,
        weight: FontWeight.w500,
        maxWidth: labelW - 16,
      );

      if (projectiles.isEmpty) continue;

      // Lay the cast out at its real spawn offsets, scaled down only if the
      // spread would overflow the cell — so scattered traps read as scattered
      // and a single meteor stays centred.
      var maxOffset = 0.0;
      for (final p in projectiles) {
        final d = p.position.distance;
        if (d > maxOffset) maxOffset = d;
      }
      const fitRadius = cell * 0.34;
      final scale = maxOffset > fitRadius ? fitRadius / maxOffset : 1.0;
      if (scale < 1.0) {
        label(
          'shown at ${(scale * 100).round()}% scale',
          Offset(10, top + cell - 18),
          const Color(0xFF556070),
          size: 8,
          weight: FontWeight.w500,
          maxWidth: labelW - 16,
        );
      }

      for (var c = 0; c < times.length; c++) {
        final centre = Offset(labelW + c * cell + cell / 2, top + cell / 2);
        // Clip to the cell: several abilities (the kin auras, the mask fields)
        // paint far wider than their spawn point, and unclipped they smear
        // across neighbouring rows and hide them.
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(labelW + c * cell, top, cell, cell));
        // Scale the canvas, not just the spawn offsets: shrinking positions
        // while drawing at full size would jam a wide cast together and make
        // it look far more overlapped than it is in game.
        canvas.translate(centre.dx, centre.dy);
        canvas.scale(scale);
        for (final p in projectiles) {
          drawOne(canvas, p, p.position, color, times[c]);
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
    Directory(outDir!).createSync(recursive: true);
    File(
      '$outDir/${family}_ability_vfx_sheet.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  for (final family in kCosmicAuthoredAbilityFamilies) {
    testWidgets(
      '$family ability vfx contact sheet',
      (tester) => renderFamily(tester, family),
      skip: outDir == null,
    );
  }
}
