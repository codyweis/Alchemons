part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE HOME PLANET'S OWN BODY — its glow, its sphere, and the four
//  customizations the player liked as they were (vine tendrils, steam vents,
//  phantom phase, electric field), drawn from what the player has chosen
//  alone. Moved here out of the cosmic game so a planet can be drawn without
//  a game round it: in space (cosmic_game_home_visuals.dart) and a friend's
//  on their page (lib/widgets/home_planet_view.dart). The rest of what it
//  wears is HomeEffectsArt's.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class HomePlanetPaint {
  /// The four recipes drawn here, over the body.
  static const originals = {
    'vine_tendrils',
    'steam_vents',
    'phantom_phase',
    'electric_field',
  };

  /// The warm glow round the home planet: the blurred disc it always had,
  /// as a gradient of the same shape (a blur pass per frame is the jank
  /// source in space; this looks the same and costs a plain fill).
  static void aura(
    Canvas canvas,
    Offset pos,
    double vr,
    double t,
    String? colorId,
    Color col,
  ) {
    // The premium colors are drawn their own way.
    if (HomeEffectsArt.instance.paintPremiumAura(canvas, pos, vr, t, colorId)) {
      return;
    }
    final r = vr * 2.5 + 50;
    canvas.drawCircle(
      pos,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          pos,
          r,
          [
            col.withValues(alpha: 0.12),
            col.withValues(alpha: 0.12),
            col.withValues(alpha: 0),
          ],
          [0.0, max(0.0, (vr * 2.5 - 50) / r), 1.0],
        ),
    );
  }

  /// The home planet's body: the same glowing sphere in its color it has
  /// always been, now lit like the rest of space — a luminous rim of
  /// atmosphere, the far side falling into shadow, and a slow breath of
  /// light inside it.
  static void sphere(
    Canvas canvas,
    Offset pos,
    double vr,
    double t,
    String? colorId,
    Color col,
  ) {
    if (HomeEffectsArt.instance.paintPremiumBody(canvas, pos, vr, t, colorId)) {
      return;
    }
    final breathe = 0.5 + 0.5 * sin(t * 0.6);
    canvas.drawCircle(
      pos,
      vr,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(pos.dx - vr * 0.3, pos.dy - vr * 0.3),
          vr * 1.5,
          [
            Color.lerp(col, const Color(0xFFFFFFFF), 0.35)!,
            col,
            Color.lerp(col, const Color(0xFF000000), 0.5)!,
          ],
          [0.0, 0.5, 1.0],
        ),
    );
    // Inner light, breathing.
    final core = Offset(pos.dx - vr * 0.12, pos.dy - vr * 0.1);
    canvas.drawCircle(
      core,
      vr * 0.75,
      Paint()
        ..shader = ui.Gradient.radial(core, vr * 0.75, [
          Color.lerp(
            col,
            const Color(0xFFFFFFFF),
            0.6,
          )!.withValues(alpha: 0.16 + 0.1 * breathe),
          Color.lerp(col, const Color(0xFFFFFFFF), 0.6)!.withValues(alpha: 0),
        ]),
    );
    // The far side into shadow.
    canvas.drawCircle(
      pos,
      vr,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(pos.dx - vr * 0.55, pos.dy - vr * 0.62),
          vr * 2.2,
          [
            const Color(0x00000000),
            const Color(0x00000000),
            const Color(0xFF02030A).withValues(alpha: 0.35),
            const Color(0xFF02030A).withValues(alpha: 0.6),
          ],
          const [0.0, 0.4, 0.66, 0.86],
        ),
    );
    // A luminous rim of atmosphere, both sides of the limb.
    final rim = Color.lerp(col, const Color(0xFFFFFFFF), 0.45)!;
    final outer = vr * 1.1;
    canvas.drawCircle(
      pos,
      outer,
      Paint()
        ..shader = ui.Gradient.radial(
          pos,
          outer,
          [
            rim.withValues(alpha: 0),
            rim.withValues(alpha: 0.32 + 0.08 * breathe),
            rim.withValues(alpha: 0.1),
            rim.withValues(alpha: 0),
          ],
          [0.84, vr / outer, (vr / outer + 1) / 2, 1.0],
        ),
    );
  }

  /// The four original customizations among [active], in front of the body.
  static void paintOriginals(
    Canvas canvas,
    Offset pos,
    double vr,
    double t,
    Set<String> active,
    Map<String, String> options,
  ) {
    if (active.contains('vine_tendrils')) {
      _drawVineTendrils(canvas, pos, vr, t, options);
    }
    if (active.contains('steam_vents')) {
      _drawSteamVents(canvas, pos, vr, t, options);
    }
    if (active.contains('phantom_phase')) {
      _drawPhantomPhase(canvas, pos, vr, t, options);
    }
    if (active.contains('electric_field')) {
      _drawElectricField(canvas, pos, vr, t, options);
    }
  }

  // ── Sizing for the original painters ──────────────────────────────────────

  static double _planetEffectScale(double vr) => (vr / 80.0).clamp(0.6, 2.8);

  static double _scaledEffectPx(
    double vr,
    double base, {
    double min = 0.0,
    double? max,
  }) {
    final scaled = base * _planetEffectScale(vr);
    if (max == null) return scaled.clamp(min, double.infinity);
    return scaled.clamp(min, max);
  }

  // ── Individual front effects ──────────────────────────────────────────────

  static void _drawVineTendrils(
    Canvas canvas,
    Offset pos,
    double vr,
    double t,
    Map<String, String> customizationOptions,
  ) {
    final lenMul = switch (customizationOptions['vine_tendrils.length'] ??
        'Medium') {
      'Short' => 0.30,
      'Long' => 0.80,
      _ => 0.55,
    };
    final count = switch (customizationOptions['vine_tendrils.count'] ??
        'Some') {
      'Few' => 4,
      'Many' => 10,
      _ => 7,
    };
    final segments = 12;

    for (var i = 0; i < count; i++) {
      final baseAngle = i * pi * 2 / count + sin(t * 0.3 + i) * 0.06;
      final vineLen = vr * lenMul * (1.0 + 0.25 * sin(t * 0.5 + i * 1.7));

      final vinePath = Path();
      final leafPositions = <Offset>[];
      final leafAngles = <double>[];

      Offset prev = Offset(
        pos.dx + cos(baseAngle) * vr * 0.92,
        pos.dy + sin(baseAngle) * vr * 0.92,
      );
      vinePath.moveTo(prev.dx, prev.dy);

      for (var s = 1; s <= segments; s++) {
        final frac = s / segments;
        final sway =
            sin(t * 1.5 + i * 2.3 + s * 0.8) *
            _scaledEffectPx(vr, 8.0, min: 3.0, max: 18.0) *
            frac;
        final perpAngle = baseAngle + pi / 2;
        final dist = vr * 0.92 + vineLen * frac;
        final pt = Offset(
          pos.dx + cos(baseAngle) * dist + cos(perpAngle) * sway,
          pos.dy + sin(baseAngle) * dist + sin(perpAngle) * sway,
        );
        vinePath.lineTo(pt.dx, pt.dy);
        prev = pt;

        if (s % 3 == 0 && s < segments) {
          leafPositions.add(pt);
          leafAngles.add(baseAngle);
        }
      }

      // Vine stroke — thin outer + lighter inner like plant planet
      final vineColor = Color.lerp(
        const Color(0xFF2E7D32),
        const Color(0xFF66BB6A),
        i / count,
      )!;
      canvas.drawPath(
        vinePath,
        Paint()
          ..color = vineColor.withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledEffectPx(vr, 2.4, min: 1.4, max: 5.0)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        vinePath,
        Paint()
          ..color = const Color(0xFF81C784).withValues(alpha: 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledEffectPx(vr, 1.0, min: 0.6, max: 2.2)
          ..strokeCap = StrokeCap.round,
      );

      // Teardrop leaves at intervals
      for (var li = 0; li < leafPositions.length; li++) {
        final lp = leafPositions[li];
        final la =
            leafAngles[li] +
            pi / 2 * (li.isEven ? 1 : -1) +
            sin(t * 2 + i + li) * 0.3;
        final leafSize =
            _scaledEffectPx(vr, 6.0, min: 3.0, max: 13.0) *
            (1.0 + 0.15 * sin(t * 1.2 + li * 1.5));

        canvas.save();
        canvas.translate(lp.dx, lp.dy);
        canvas.rotate(la);

        final leafPath = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(
            leafSize * 0.6,
            -leafSize * 0.5,
            leafSize * 1.5,
            0,
          )
          ..quadraticBezierTo(leafSize * 0.6, leafSize * 0.5, 0, 0);

        canvas.drawPath(
          leafPath,
          Paint()..color = const Color(0xFF4CAF50).withValues(alpha: 0.80),
        );
        // Leaf vein
        canvas.drawLine(
          Offset.zero,
          Offset(leafSize * 1.2, 0),
          Paint()
            ..color = const Color(0xFF388E3C).withValues(alpha: 0.45)
            ..strokeWidth = _scaledEffectPx(vr, 0.5, min: 0.3, max: 1.0),
        );
        canvas.restore();
      }

      // Glowing tip bud
      final tipGlow = 0.35 + 0.25 * sin(t * 2 + i * 1.5);
      final budR = _scaledEffectPx(vr, 2.8, min: 1.6, max: 6.0);
      _drawGlow(
        canvas,
        prev,
        budR,
        const Color(0xFFA5D6A7),
        tipGlow,
        budR * 2.0,
      );
      canvas.drawCircle(
        prev,
        budR * 0.55,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: tipGlow * 0.75),
      );
    }
  }

  static void _drawSteamVents(
    Canvas canvas,
    Offset pos,
    double vr,
    double t,
    Map<String, String> customizationOptions,
  ) {
    final ventCount = switch (customizationOptions['steam_vents.jets'] ?? '4') {
      '2' => 2,
      '6' => 6,
      _ => 4,
    };
    for (var i = 0; i < ventCount; i++) {
      final a = i * pi * 2 / ventCount + 0.4;
      final bx = pos.dx + cos(a) * vr;
      final by = pos.dy + sin(a) * vr;
      // 4-step jet: radial gradient blob instead of blurred circle
      for (var j = 0; j < 4; j++) {
        final jetDist =
            _scaledEffectPx(vr, 5.0, min: 3.0, max: 12.0) +
            j * _scaledEffectPx(vr, 7.0, min: 4.0, max: 16.0) +
            _scaledEffectPx(vr, 3.0, min: 1.5, max: 8.0) * sin(t * 4 + i + j);
        final jc = Offset(bx + cos(a) * jetDist, by + sin(a) * jetDist);
        final jr =
            _scaledEffectPx(vr, 3.5, min: 2.0, max: 8.0) +
            j * _scaledEffectPx(vr, 0.6, min: 0.3, max: 1.4);
        _drawGlow(
          canvas,
          jc,
          jr,
          const Color(0xFF90A4AE),
          (0.18 - j * 0.035).clamp(0, 1),
          jr * 2.4,
        );
      }
    }
  }

  // ── Phantom Phase — planet fades translucent periodically ──────────────────

  static void _drawPhantomPhase(
    Canvas canvas,
    Offset pos,
    double vr,
    double t,
    Map<String, String> customizationOptions,
  ) {
    final intensity =
        customizationOptions['phantom_phase.intensity'] ?? 'Normal';
    // How transparent the planet becomes at peak phase
    final fadeDepth = switch (intensity) {
      'Subtle' => 0.15,
      'Deep' => 0.55,
      _ => 0.35,
    };

    // 8s cycle: 0-6s visible, 6-7s fade out, 7-8s fade back
    final cycle = t % 8.0;
    double phaseAlpha;
    if (cycle < 6.0) {
      phaseAlpha = 0.0;
    } else if (cycle < 7.0) {
      final f = cycle - 6.0;
      phaseAlpha = f * f * fadeDepth; // ease-in fade
    } else {
      final f = cycle - 7.0;
      phaseAlpha = fadeDepth * (1.0 - f * (2.0 - f)); // ease-out return
    }

    if (phaseAlpha < 0.01) return; // nothing to draw most of the time

    // Overlay a dark disc that partially hides the planet (simulates transparency)
    _drawGlow(
      canvas,
      pos,
      vr * 0.7,
      const Color(0xFF0A0014),
      phaseAlpha,
      vr * 1.1,
    );

    // Spectral shimmer at the edges during phase
    _drawRingGlow(
      canvas,
      pos,
      vr.toDouble(),
      _scaledEffectPx(vr, 8.0, min: 4.0, max: 18.0),
      const Color(0xFF7C4DFF),
      phaseAlpha * 0.6,
    );
  }

  // ── Electric Field — crackling bolts & sparks around the planet ────────────

  static void _drawElectricField(
    Canvas canvas,
    Offset pos,
    double vr,
    double t,
    Map<String, String> customizationOptions,
  ) {
    final boltCount = switch (customizationOptions['electric_field.bolts'] ??
        'Normal') {
      'Few' => 3,
      'Many' => 7,
      _ => 5,
    };
    final intensityAlpha =
        switch (customizationOptions['electric_field.intensity'] ?? 'Normal') {
          'Dim' => 0.4,
          'Bright' => 0.9,
          _ => 0.65,
        };

    final fieldR = vr + _scaledEffectPx(vr, 22.0, min: 12.0, max: 52.0);

    // ── Ambient electric haze ──
    _drawRingGlow(
      canvas,
      pos,
      fieldR,
      _scaledEffectPx(vr, 12.0, min: 6.0, max: 24.0),
      const Color(0xFFFFEB3B),
      intensityAlpha * 0.08,
    );

    // ── Lightning bolts — flickering arcs from field to surface ──
    for (var i = 0; i < boltCount; i++) {
      final seed = (pos.dx.toInt() ^ pos.dy.toInt()) + i * 137;
      final phase = t * (2.5 + i * 0.7) + seed * 0.1;
      final flash = sin(phase) * sin(phase * 3.7 + i);
      if (flash <= 0.3) continue; // bolt not visible this frame

      final boltAlpha = ((flash - 0.3) * 1.4).clamp(0.0, 1.0) * intensityAlpha;
      final startAngle =
          (seed * 0.1 + t * 0.15 * (i.isEven ? 1 : -1)) % (pi * 2);
      final boltStart = Offset(
        pos.dx + cos(startAngle) * fieldR,
        pos.dy + sin(startAngle) * fieldR,
      );
      final endAngle = startAngle + (sin(seed.toDouble()) * 0.3);
      final boltEnd = Offset(
        pos.dx + cos(endAngle) * (vr + 2),
        pos.dy + sin(endAngle) * (vr + 2),
      );

      // Draw zig-zag bolt
      final boltPath = Path();
      boltPath.moveTo(boltStart.dx, boltStart.dy);
      const segments = 4;
      for (var s = 1; s <= segments; s++) {
        final frac = s / segments;
        final mx = boltStart.dx + (boltEnd.dx - boltStart.dx) * frac;
        final my = boltStart.dy + (boltEnd.dy - boltStart.dy) * frac;
        final perpX = -(boltEnd.dy - boltStart.dy);
        final perpY = (boltEnd.dx - boltStart.dx);
        final perpLen = sqrt(perpX * perpX + perpY * perpY);
        final jag =
            sin(t * 12 + s * 3.0 + i * 7) *
            _scaledEffectPx(vr, 6.0, min: 3.0, max: 14.0);
        if (perpLen > 0 && s < segments) {
          boltPath.lineTo(
            mx + (perpX / perpLen) * jag,
            my + (perpY / perpLen) * jag,
          );
        } else {
          boltPath.lineTo(mx, my);
        }
      }

      // Glow layer
      canvas.drawPath(
        boltPath,
        Paint()
          ..color = const Color(0xFFFFEB3B).withValues(alpha: boltAlpha * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledEffectPx(vr, 3.5, min: 2.0, max: 8.0)
          ..strokeCap = StrokeCap.round,
      );
      // Core layer
      canvas.drawPath(
        boltPath,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: boltAlpha * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledEffectPx(vr, 1.2, min: 0.9, max: 3.0)
          ..strokeCap = StrokeCap.round,
      );

      // Impact glow at surface
      _drawGlow(
        canvas,
        boltEnd,
        _scaledEffectPx(vr, 3.0, min: 1.8, max: 7.0),
        const Color(0xFFFFEB3B),
        boltAlpha * 0.6,
        _scaledEffectPx(vr, 8.0, min: 4.0, max: 18.0),
      );
    }

    // ── Orbiting spark motes ──
    for (var i = 0; i < 6; i++) {
      final sparkAngle = t * (0.5 + i * 0.12) + i * pi / 3;
      final sparkDist = fieldR * (0.92 + 0.08 * sin(t * 3 + i * 2));
      final sx = pos.dx + cos(sparkAngle) * sparkDist;
      final sy = pos.dy + sin(sparkAngle) * sparkDist;
      final sparkAlpha =
          (0.3 + 0.3 * sin(t * 6 + i * 1.7)).clamp(0.0, 0.6) * intensityAlpha;
      _drawGlow(
        canvas,
        Offset(sx, sy),
        _scaledEffectPx(vr, 1.0, min: 0.8, max: 2.2),
        const Color(0xFFFFEB3B),
        sparkAlpha,
        _scaledEffectPx(vr, 4.0, min: 2.0, max: 8.0),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PRIMITIVE GLOW HELPERS  (replaces all MaskFilter.blur usage)
  //  These use radial gradients — rendered entirely on the GPU, zero blur cost.
  // ══════════════════════════════════════════════════════════════════════════

  /// Soft radial glow centred on [centre].
  /// [innerR] is the solid-ish core, [outerR] is where alpha fades to zero.
  static void _drawGlow(
    Canvas canvas,
    Offset centre,
    double innerR,
    Color color,
    double alpha,
    double outerR,
  ) {
    canvas.drawCircle(
      centre,
      outerR,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          outerR,
          [
            color.withValues(alpha: alpha.clamp(0, 1)),
            color.withValues(alpha: 0),
          ],
          [innerR / outerR, 1.0],
        ),
    );
  }

  /// Ring glow: a soft halo around a circle of radius [ringR].
  static void _drawRingGlow(
    Canvas canvas,
    Offset centre,
    double ringR,
    double spread,
    Color color,
    double alpha,
  ) {
    canvas.drawCircle(
      centre,
      ringR + spread,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          ringR + spread,
          [
            color.withValues(alpha: 0),
            color.withValues(alpha: alpha.clamp(0, 1)),
            color.withValues(alpha: 0),
          ],
          [
            ((ringR - spread * 0.5) / (ringR + spread)).clamp(0, 1),
            (ringR / (ringR + spread)).clamp(0, 1),
            1.0,
          ],
        ),
    );
  }
}
