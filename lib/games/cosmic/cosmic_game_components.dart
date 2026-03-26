part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────
// HOMING MISSILE
// ─────────────────────────────────────────────────────────

class _HomingMissile {
  Offset position;
  double angle;
  static const double maxLife = 3.0;
  double life = maxLife;
  static const double speed = 400.0;
  static const double turnRate = 3.6; // radians/sec

  _HomingMissile({required this.position, required this.angle});
}

// ─────────────────────────────────────────────────────────
// SHIP COMPONENT
// ─────────────────────────────────────────────────────────

class ShipComponent {
  ShipComponent({required this.pos});

  Offset pos;
  double angle = -pi / 2; // pointing up initially

  void render(Canvas canvas, double elapsed, {String? skin}) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle + pi / 2); // adjust so 0 = up

    switch (skin) {
      case 'skin_phantom':
        _renderPhantom(canvas, elapsed);
      case 'skin_solar':
        _renderSolar(canvas, elapsed);
      default:
        _renderDefault(canvas, elapsed);
    }

    canvas.restore();
  }

  // ── Default ship ──
  void _renderDefault(Canvas canvas, double elapsed) {
    // Engine glow
    final glowPaint = Paint()
      ..color = const Color(0x6000BFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(const Offset(0, 14), 8, glowPaint);

    // Trail particles (simple)
    final trailPaint = Paint()..color = const Color(0x4000BFFF);
    for (var i = 1; i <= 3; i++) {
      final wobble = sin(elapsed * 8 + i * 1.5) * 3;
      canvas.drawCircle(
        Offset(wobble, 14.0 + i * 8),
        4.0 - i * 0.8,
        trailPaint,
      );
    }

    // Ship body — a sleek triangle
    final bodyPath = Path()
      ..moveTo(0, -18)
      ..lineTo(-10, 14)
      ..lineTo(0, 8)
      ..lineTo(10, 14)
      ..close();

    // Hull gradient
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(const Offset(0, -18), const Offset(0, 14), [
        const Color(0xFF80DEEA),
        const Color(0xFF0077B6),
      ]);
    canvas.drawPath(bodyPath, bodyPaint);

    // Outline
    final outlinePaint = Paint()
      ..color = const Color(0xAA00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(bodyPath, outlinePaint);

    // Cockpit glow
    canvas.drawCircle(
      const Offset(0, -4),
      3,
      Paint()..color = const Color(0xCC00E5FF),
    );
  }

  // ── Phantom Viper: angular stealth hull, violet exhaust ──
  void _renderPhantom(Canvas canvas, double elapsed) {
    // Dark-matter exhaust glow
    final glowPaint = Paint()
      ..color = const Color(0x608B00FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(const Offset(0, 16), 7, glowPaint);

    // Ghostly trail
    for (var i = 1; i <= 4; i++) {
      final wobble = sin(elapsed * 10 + i * 1.2) * 2.5;
      final alpha = (0.35 - i * 0.07).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(wobble, 16.0 + i * 7),
        3.5 - i * 0.6,
        Paint()..color = Color.fromRGBO(139, 0, 255, alpha),
      );
    }

    // Angular stealth body — sharp diamond profile
    final bodyPath = Path()
      ..moveTo(0, -20) // nose (sharp)
      ..lineTo(-6, -8) // left shoulder notch
      ..lineTo(-12, 10) // left wingtip
      ..lineTo(-4, 6) // left inner
      ..lineTo(0, 12) // tail center
      ..lineTo(4, 6) // right inner
      ..lineTo(12, 10) // right wingtip
      ..lineTo(6, -8) // right shoulder notch
      ..close();

    // Dark hull gradient
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(const Offset(0, -20), const Offset(0, 12), [
        const Color(0xFF2D1B69), // deep violet
        const Color(0xFF0D0D1A), // near-black
      ]);
    canvas.drawPath(bodyPath, bodyPaint);

    // Faint violet outline
    final outlinePaint = Paint()
      ..color = const Color(0x889945FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(bodyPath, outlinePaint);

    // Twin cockpit eyes (menacing)
    final eyeGlow = 0.7 + 0.3 * sin(elapsed * 4);
    canvas.drawCircle(
      const Offset(-3, -6),
      2,
      Paint()..color = Color.fromRGBO(180, 80, 255, eyeGlow),
    );
    canvas.drawCircle(
      const Offset(3, -6),
      2,
      Paint()..color = Color.fromRGBO(180, 80, 255, eyeGlow),
    );
  }

  // ── Solar Dragoon: blazing golden hull, solar flares ──
  void _renderSolar(Canvas canvas, double elapsed) {
    // Solar flare exhaust
    final flarePaint = Paint()
      ..color = const Color(0x70FF8F00)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(const Offset(0, 14), 10, flarePaint);

    // Trailing fire particles
    for (var i = 1; i <= 4; i++) {
      final wobble = sin(elapsed * 12 + i * 1.8) * 3;
      final alpha = (0.5 - i * 0.1).clamp(0.0, 1.0);
      final hue = i.isEven ? const Color(0xFFFF6F00) : const Color(0xFFFFAB00);
      canvas.drawCircle(
        Offset(wobble, 14.0 + i * 7),
        4.5 - i * 0.8,
        Paint()..color = hue.withValues(alpha: alpha),
      );
    }

    // Solar flare wings (animated outward flickers)
    for (var w = 0; w < 3; w++) {
      final flareAngle = elapsed * 1.5 + w * pi * 2 / 3;
      final flareLen = 5 + 3 * sin(elapsed * 5 + w * 2);
      final fx = cos(flareAngle) * (10 + flareLen);
      final fy = sin(flareAngle) * (10 + flareLen) * 0.4;
      canvas.drawCircle(
        Offset(fx, fy),
        3,
        Paint()
          ..color = const Color(0x40FFD600)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Ship body — broad arrowhead with swept wings
    final bodyPath = Path()
      ..moveTo(0, -18) // nose
      ..lineTo(-8, -2) // left shoulder
      ..lineTo(-14, 12) // left wingtip (wider)
      ..lineTo(-3, 8) // left inner
      ..lineTo(0, 14) // tail
      ..lineTo(3, 8) // right inner
      ..lineTo(14, 12) // right wingtip
      ..lineTo(8, -2) // right shoulder
      ..close();

    // Golden hull gradient
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(const Offset(0, -18), const Offset(0, 14), [
        const Color(0xFFFFE082), // bright gold
        const Color(0xFFE65100), // deep orange
      ]);
    canvas.drawPath(bodyPath, bodyPaint);

    // Warm amber outline
    final outlinePaint = Paint()
      ..color = const Color(0xAAFFAB00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(bodyPath, outlinePaint);

    // Radiant cockpit
    final cockpitGlow = 0.8 + 0.2 * sin(elapsed * 3);
    canvas.drawCircle(
      const Offset(0, -4),
      3.5,
      Paint()..color = Color.fromRGBO(255, 214, 0, cockpitGlow),
    );
    // Inner cockpit core
    canvas.drawCircle(
      const Offset(0, -4),
      1.5,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PLANET COMPONENT
// ─────────────────────────────────────────────────────────

class PlanetComponent {
  PlanetComponent({required this.planet});

  final CosmicPlanet planet;

  void render(Canvas canvas, double elapsed) {
    final pos = planet.position;
    final r = planet.radius;
    final color = planet.color;
    final elem = planet.element;

    // ── outer aura (all planets) ──
    final auraPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(pos, r * 2.5, auraPaint);

    // ── particle field ring ──
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(pos, planet.particleFieldRadius, ringPaint);

    // ── per‑element unique body ──
    switch (elem) {
      case 'Fire':
        _drawFirePlanet(canvas, pos, r, color, elapsed);
      case 'Lava':
        _drawLavaPlanet(canvas, pos, r, color, elapsed);
      case 'Lightning':
        _drawLightningPlanet(canvas, pos, r, color, elapsed);
      case 'Water':
        _drawWaterPlanet(canvas, pos, r, color, elapsed);
      case 'Ice':
        _drawIcePlanet(canvas, pos, r, color, elapsed);
      case 'Steam':
        _drawSteamPlanet(canvas, pos, r, color, elapsed);
      case 'Earth':
        _drawEarthPlanet(canvas, pos, r, color, elapsed);
      case 'Mud':
        _drawMudPlanet(canvas, pos, r, color, elapsed);
      case 'Dust':
        _drawDustPlanet(canvas, pos, r, color, elapsed);
      case 'Crystal':
        _drawCrystalPlanet(canvas, pos, r, color, elapsed);
      case 'Air':
        _drawAirPlanet(canvas, pos, r, color, elapsed);
      case 'Plant':
        _drawPlantPlanet(canvas, pos, r, color, elapsed);
      case 'Poison':
        _drawPoisonPlanet(canvas, pos, r, color, elapsed);
      case 'Spirit':
        _drawSpiritPlanet(canvas, pos, r, color, elapsed);
      case 'Dark':
        _drawDarkPlanet(canvas, pos, r, color, elapsed);
      case 'Light':
        _drawLightPlanet(canvas, pos, r, color, elapsed);
      case 'Blood':
        _drawBloodPlanet(canvas, pos, r, color, elapsed);
      default:
        _drawDefault(canvas, pos, r, color);
    }

    // ── element label ──
    final tp = TextPainter(
      text: TextSpan(
        text: planetName(elem).toUpperCase(),
        style: TextStyle(
          color: color.withValues(alpha: planet.discovered ? 0.9 : 0.0),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + r + 10));
  }

  void _drawSphere(
    Canvas canvas,
    Offset pos,
    double r,
    Color color, {
    double highlight = 0.4,
    double shadow = 0.6,
  }) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(pos.dx - r * 0.3, pos.dy - r * 0.3),
        r * 1.5,
        [
          Color.lerp(color, Colors.white, highlight)!,
          color,
          Color.lerp(color, Colors.black, shadow)!,
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(pos, r, paint);
  }

  // ─── FIRE: corona flares ───
  void _drawFirePlanet(Canvas c, Offset p, double r, Color col, double t) {
    for (var i = 0; i < 6; i++) {
      final a = t * 0.4 + i * pi / 3;
      final flareLen = r * (0.4 + 0.2 * sin(t * 2 + i));
      final fx = p.dx + cos(a) * (r + flareLen * 0.5);
      final fy = p.dy + sin(a) * (r + flareLen * 0.5);
      c.drawCircle(
        Offset(fx, fy),
        flareLen * 0.3,
        Paint()
          ..color = const Color(0x50FF6600)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    _drawSphere(c, p, r, col);
  }

  // ─── LAVA: tectonic dark sphere with subsurface magma ───
  void _drawLavaPlanet(Canvas c, Offset p, double r, Color col, double t) {
    final rng = Random(p.dx.toInt() ^ p.dy.toInt());

    // ── Deep subsurface magma glow — warm light bleeding through crust ──
    c.drawCircle(
      p,
      r * 1.3,
      Paint()
        ..color = const Color(
          0xFFBF360C,
        ).withValues(alpha: 0.08 + 0.03 * sin(t * 0.4))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
    );

    // ── Dark volcanic crust sphere ──
    final crustPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(p.dx - r * 0.3, p.dy - r * 0.3),
        r * 1.5,
        [
          const Color(0xFF4E342E), // lighter crust highlight
          const Color(0xFF3E2723), // dark basalt
          const Color(0xFF1B0000), // deep shadow
        ],
        [0.0, 0.5, 1.0],
      );
    c.drawCircle(p, r, crustPaint);

    // ── Clip all surface detail to the planet disc ──
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: p, radius: r)));

    // ── Tectonic plate boundaries — curved fissures with magma below ──
    for (var i = 0; i < 5; i++) {
      final startAngle = rng.nextDouble() * pi * 2;
      final startDist = rng.nextDouble() * r * 0.3;
      final fissurePath = Path();
      var fx = p.dx + cos(startAngle) * startDist;
      var fy = p.dy + sin(startAngle) * startDist;
      fissurePath.moveTo(fx, fy);

      final segs = 4 + rng.nextInt(3);
      var curAngle = startAngle + rng.nextDouble() * pi - pi / 2;
      for (var s = 0; s < segs; s++) {
        curAngle += (rng.nextDouble() - 0.5) * 0.8;
        final segLen = r * (0.12 + rng.nextDouble() * 0.15);
        final cx = fx + cos(curAngle) * segLen * 0.5;
        final cy = fy + sin(curAngle) * segLen * 0.5;
        fx += cos(curAngle) * segLen;
        fy += sin(curAngle) * segLen;
        fissurePath.quadraticBezierTo(cx, cy, fx, fy);
      }

      // Deep magma glow underneath
      final glowPulse = 0.12 + 0.06 * sin(t * 0.3 + i * 1.7);
      c.drawPath(
        fissurePath,
        Paint()
          ..color = const Color(0xFFFF6D00).withValues(alpha: glowPulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Mid glow — orange
      c.drawPath(
        fissurePath,
        Paint()
          ..color = const Color(
            0xFFFF8F00,
          ).withValues(alpha: 0.18 + 0.08 * sin(t * 0.5 + i * 0.9))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      // Hot core — yellow-white
      c.drawPath(
        fissurePath,
        Paint()
          ..color = const Color(
            0xFFFFD54F,
          ).withValues(alpha: 0.2 + 0.1 * sin(t * 0.6 + i * 1.3))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // ── Lava pools — subsurface magma showing through thin crust ──
    for (var i = 0; i < 4; i++) {
      final poolAngle = rng.nextDouble() * pi * 2;
      final poolDist = rng.nextDouble() * r * 0.65;
      final px = p.dx + cos(poolAngle) * poolDist;
      final py = p.dy + sin(poolAngle) * poolDist;
      final poolR = r * (0.06 + rng.nextDouble() * 0.08);
      final poolPulse = sin(t * (0.4 + i * 0.15) + i * 2.5);
      final poolAlpha = (0.1 + 0.08 * poolPulse).clamp(0.0, 0.25);

      // Radial gradient from hot center to dark edge
      c.drawCircle(
        Offset(px, py),
        poolR * 2.5,
        Paint()
          ..color = const Color(0xFFE65100).withValues(alpha: poolAlpha * 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, poolR * 1.5),
      );
      c.drawCircle(
        Offset(px, py),
        poolR,
        Paint()..color = const Color(0xFFFFAB00).withValues(alpha: poolAlpha),
      );
    }

    // ── Crustal texture — subtle darker patches (cooled lava fields) ──
    for (var i = 0; i < 6; i++) {
      final cAngle = rng.nextDouble() * pi * 2;
      final cDist = rng.nextDouble() * r * 0.75;
      final cSize = r * (0.1 + rng.nextDouble() * 0.15);
      c.drawCircle(
        Offset(p.dx + cos(cAngle) * cDist, p.dy + sin(cAngle) * cDist),
        cSize,
        Paint()
          ..color = const Color(0xFF1A0000).withValues(alpha: 0.15)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cSize * 0.6),
      );
    }

    c.restore();

    // ── Terminator gradient — darken the shadow side of the sphere ──
    c.drawCircle(
      Offset(p.dx + r * 0.35, p.dy + r * 0.25),
      r,
      Paint()
        ..color = const Color(0xFF0A0000).withValues(alpha: 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4),
    );

    // ── Subtle rim light from magma ──
    c.drawCircle(
      p,
      r,
      Paint()
        ..color = const Color(
          0xFFFF6D00,
        ).withValues(alpha: 0.06 + 0.03 * sin(t * 0.5))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  // ─── LIGHTNING: crackling electric planet with bolt flashes ───
  void _drawLightningPlanet(Canvas c, Offset p, double r, Color col, double t) {
    final rng = Random(p.dx.toInt() ^ p.dy.toInt());

    // ── Outer electric field haze (gravitational radius) ──
    final gravR = r * 2.2;
    c.drawCircle(
      p,
      gravR,
      Paint()
        ..color = col.withValues(alpha: 0.04 + 0.02 * sin(t * 4))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, gravR * 0.3),
    );

    // ── Lightning bolt flashes around gravitational radius ──
    // 4 bolts that flicker on/off with random timing
    for (var i = 0; i < 4; i++) {
      final seed = rng.nextInt(10000);
      // Each bolt has its own flicker cycle
      final phase = t * (2.5 + i * 0.7) + seed;
      final flash = sin(phase) * sin(phase * 3.7 + i);
      if (flash > 0.3) {
        // Bolt is visible
        final boltAlpha = ((flash - 0.3) * 1.4).clamp(0.0, 1.0);
        final startAngle =
            (seed * 0.1 + t * 0.15 * (i.isEven ? 1 : -1)) % (pi * 2);
        final boltStart = Offset(
          p.dx + cos(startAngle) * gravR * (0.85 + 0.15 * sin(t * 2 + i)),
          p.dy + sin(startAngle) * gravR * (0.85 + 0.15 * sin(t * 2 + i)),
        );
        // Bolt zig-zags inward toward planet surface
        final endAngle = startAngle + (rng.nextDouble() - 0.5) * 0.6;
        final boltEnd = Offset(
          p.dx + cos(endAngle) * r * 1.1,
          p.dy + sin(endAngle) * r * 1.1,
        );

        final boltPath = Path();
        boltPath.moveTo(boltStart.dx, boltStart.dy);
        const segments = 5;
        for (var s = 1; s <= segments; s++) {
          final frac = s / segments;
          final mx = boltStart.dx + (boltEnd.dx - boltStart.dx) * frac;
          final my = boltStart.dy + (boltEnd.dy - boltStart.dy) * frac;
          // Random lateral jag
          final perpX = -(boltEnd.dy - boltStart.dy);
          final perpY = (boltEnd.dx - boltStart.dx);
          final perpLen = sqrt(perpX * perpX + perpY * perpY);
          final jag = sin(t * 12 + s * 3.0 + i * 7) * r * 0.12;
          if (perpLen > 0 && s < segments) {
            boltPath.lineTo(
              mx + (perpX / perpLen) * jag,
              my + (perpY / perpLen) * jag,
            );
          } else {
            boltPath.lineTo(mx, my);
          }
        }

        // Glow layer (thick, blurred)
        c.drawPath(
          boltPath,
          Paint()
            ..color = col.withValues(alpha: boltAlpha * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // Core layer (thin, bright)
        c.drawPath(
          boltPath,
          Paint()
            ..color = Colors.white.withValues(alpha: boltAlpha * 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round,
        );

        // Flash point at bolt origin
        c.drawCircle(
          boltStart,
          3.0 + 2.0 * boltAlpha,
          Paint()
            ..color = Colors.white.withValues(alpha: boltAlpha * 0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }

    // ── Arc discharges between random surface points ──
    for (var i = 0; i < 3; i++) {
      final arcPhase = t * (3.0 + i * 1.3) + rng.nextInt(1000);
      final arcFlash = sin(arcPhase) * sin(arcPhase * 2.1);
      if (arcFlash > 0.5) {
        final arcAlpha = ((arcFlash - 0.5) * 2.0).clamp(0.0, 1.0);
        final a1 = (rng.nextDouble() * pi * 2 + t * 0.3 * (i + 1)) % (pi * 2);
        final a2 = a1 + 0.8 + rng.nextDouble() * 1.2;
        final s1 = Offset(p.dx + cos(a1) * r * 0.95, p.dy + sin(a1) * r * 0.95);
        final s2 = Offset(p.dx + cos(a2) * r * 0.95, p.dy + sin(a2) * r * 0.95);
        final arcPath = Path();
        arcPath.moveTo(s1.dx, s1.dy);
        // Arc outward then back
        final midAngle = (a1 + a2) / 2;
        final arcBulge = r * (0.3 + 0.15 * sin(t * 5 + i));
        final mid = Offset(
          p.dx + cos(midAngle) * (r + arcBulge),
          p.dy + sin(midAngle) * (r + arcBulge),
        );
        arcPath.quadraticBezierTo(mid.dx, mid.dy, s2.dx, s2.dy);

        c.drawPath(
          arcPath,
          Paint()
            ..color = col.withValues(alpha: arcAlpha * 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        c.drawPath(
          arcPath,
          Paint()
            ..color = Colors.white.withValues(alpha: arcAlpha * 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── Planet sphere (dark electric blue) ──
    _drawSphere(c, p, r, const Color(0xFF1A237E), highlight: 0.5);

    // ── Pulsing electric core glow ──
    final corePulse = 0.12 + 0.08 * sin(t * 4.5);
    c.drawCircle(
      Offset(p.dx - r * 0.15, p.dy - r * 0.15),
      r * 0.4,
      Paint()
        ..color = Colors.white.withValues(alpha: corePulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3),
    );

    // ── Flickering electric aura (close to surface) ──
    c.drawCircle(
      p,
      r * 1.3,
      Paint()
        ..color = col.withValues(alpha: 0.06 + 0.04 * sin(t * 6))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
    );

    // ── Spark particles orbiting at gravitational radius ──
    for (var i = 0; i < 8; i++) {
      final sparkAngle = t * (0.5 + i * 0.12) + i * pi / 4;
      final sparkDist = gravR * (0.9 + 0.1 * sin(t * 3 + i * 2));
      final sx = p.dx + cos(sparkAngle) * sparkDist;
      final sy = p.dy + sin(sparkAngle) * sparkDist;
      final sparkAlpha = (0.3 + 0.4 * sin(t * 6 + i * 1.7)).clamp(0.0, 0.7);
      c.drawCircle(
        Offset(sx, sy),
        1.5 + sin(t * 4 + i) * 0.5,
        Paint()..color = col.withValues(alpha: sparkAlpha),
      );
    }
  }

  // ─── WATER: glossy blue sphere ───
  void _drawWaterPlanet(Canvas c, Offset p, double r, Color col, double t) {
    // Deep ocean base
    _drawSphere(c, p, r, const Color(0xFF0D47A1), highlight: 0.3, shadow: 0.5);

    // Clip to planet circle so waves stay inside
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: p, radius: r)));

    // Animated wave bands — horizontal liquid stripes flowing across the surface
    const waveLayers = 5;
    for (var w = 0; w < waveLayers; w++) {
      final waveY = p.dy - r + (2 * r) * (w + 0.5) / waveLayers;
      final waveColor = Color.lerp(
        const Color(0xFF1565C0),
        const Color(0xFF42A5F5),
        w / waveLayers,
      )!;
      final wavePath = Path();
      final amplitude = r * (0.06 + 0.03 * sin(t * 0.7 + w));
      final freq = 3.0 + w * 0.5;
      final speed = 1.2 + w * 0.3;

      wavePath.moveTo(p.dx - r - 10, waveY);
      for (var x = -r - 10; x <= r + 10; x += 4) {
        final wx = p.dx + x;
        final wy =
            waveY +
            sin(x / r * freq * pi + t * speed) * amplitude +
            cos(x / r * (freq + 1) * pi + t * speed * 0.7 + w) *
                amplitude *
                0.5;
        wavePath.lineTo(wx, wy);
      }
      wavePath.lineTo(p.dx + r + 10, p.dy + r + 10);
      wavePath.lineTo(p.dx - r - 10, p.dy + r + 10);
      wavePath.close();

      c.drawPath(
        wavePath,
        Paint()..color = waveColor.withValues(alpha: 0.25 + 0.05 * w),
      );
    }

    // Surface caustics — shimmering light patterns
    final rng = Random(p.dx.toInt() ^ p.dy.toInt());
    for (var i = 0; i < 8; i++) {
      final cx = p.dx + (rng.nextDouble() - 0.5) * r * 1.4;
      final cy = p.dy + (rng.nextDouble() - 0.5) * r * 1.4;
      final phase = t * 1.5 + i * 0.9;
      final causticR = r * (0.06 + 0.04 * sin(phase));
      final alpha = (0.15 + 0.1 * sin(phase + 1.0)).clamp(0.0, 1.0);
      c.drawCircle(
        Offset(
          cx + sin(phase * 0.6) * r * 0.05,
          cy + cos(phase * 0.8) * r * 0.05,
        ),
        causticR,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, causticR),
      );
    }

    c.restore();

    // Specular highlight — glassy reflection
    final specX = p.dx - r * 0.3;
    final specY = p.dy - r * 0.3;
    final specR = r * 0.35;
    c.drawOval(
      Rect.fromCenter(
        center: Offset(specX, specY),
        width: specR * 1.6,
        height: specR * 0.8,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18 + 0.05 * sin(t * 0.8))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, specR * 0.4),
    );

    // Subtle atmospheric glow
    c.drawCircle(
      p,
      r * 1.25,
      Paint()
        ..color = const Color(
          0xFF1E88E5,
        ).withValues(alpha: 0.05 + 0.02 * sin(t * 0.6))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4),
    );
  }

  // ─── ICE: frozen world with glacial surface detail ───
  void _drawIcePlanet(Canvas c, Offset p, double r, Color col, double t) {
    final rng = Random(p.dx.toInt() ^ p.dy.toInt());

    // ── Thin cryogenic atmosphere ──
    c.drawCircle(
      p,
      r * 1.4,
      Paint()
        ..color = const Color(
          0xFF80DEEA,
        ).withValues(alpha: 0.04 + 0.015 * sin(t * 0.3))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4),
    );

    // ── Base sphere — cold blue-white gradient ──
    final icePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(p.dx - r * 0.25, p.dy - r * 0.25),
        r * 1.5,
        [
          const Color(0xFFE0F7FA), // bright ice highlight
          const Color(0xFF80DEEA), // mid cyan
          const Color(0xFF26627A), // deep shadow
        ],
        [0.0, 0.45, 1.0],
      );
    c.drawCircle(p, r, icePaint);

    // ── Clip surface details to the planet ──
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: p, radius: r)));

    // ── Glacial bands — horizontal ice strata with subtle color variation ──
    for (var i = 0; i < 5; i++) {
      final bandY = p.dy - r + (i + 0.5) * (2 * r / 5);
      final bandPath = Path();
      final amp = r * 0.03 * (1 + sin(t * 0.15 + i * 0.7));
      bandPath.moveTo(p.dx - r - 5, bandY);
      for (var x = -r - 5; x <= r + 5; x += 3) {
        final bx = p.dx + x;
        final by = bandY + sin(x / r * 4 + i * 1.3) * amp;
        bandPath.lineTo(bx, by);
      }
      bandPath.lineTo(p.dx + r + 5, bandY + r * 0.3);
      bandPath.lineTo(p.dx - r - 5, bandY + r * 0.3);
      bandPath.close();
      final bandAlpha = i.isEven ? 0.06 : 0.04;
      c.drawPath(
        bandPath,
        Paint()
          ..color = Colors.white.withValues(alpha: bandAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // ── Crevasses — deep fracture lines in the ice sheet ──
    for (var i = 0; i < 4; i++) {
      final startAngle = rng.nextDouble() * pi * 2;
      final startDist = rng.nextDouble() * r * 0.3;
      final crevPath = Path();
      var cx = p.dx + cos(startAngle) * startDist;
      var cy = p.dy + sin(startAngle) * startDist;
      crevPath.moveTo(cx, cy);

      var curAngle = startAngle + rng.nextDouble() * pi - pi / 2;
      final segs = 3 + rng.nextInt(3);
      for (var s = 0; s < segs; s++) {
        curAngle += (rng.nextDouble() - 0.5) * 0.6;
        final segLen = r * (0.1 + rng.nextDouble() * 0.15);
        final mx = cx + cos(curAngle) * segLen * 0.5;
        final my = cy + sin(curAngle) * segLen * 0.5;
        cx += cos(curAngle) * segLen;
        cy += sin(curAngle) * segLen;
        crevPath.quadraticBezierTo(mx, my, cx, cy);
      }

      // Deep shadow line
      c.drawPath(
        crevPath,
        Paint()
          ..color = const Color(0xFF004D66).withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      // Bright edge (refracted light at crack lip)
      c.drawPath(
        crevPath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Polar caps — brighter white regions ──
    c.drawOval(
      Rect.fromCenter(
        center: Offset(p.dx, p.dy - r * 0.6),
        width: r * 1.2,
        height: r * 0.5,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );
    c.drawOval(
      Rect.fromCenter(
        center: Offset(p.dx + r * 0.05, p.dy + r * 0.65),
        width: r * 0.9,
        height: r * 0.35,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.1),
    );

    c.restore();

    // ── Terminator shadow — darken the unlit side ──
    c.drawCircle(
      Offset(p.dx + r * 0.35, p.dy + r * 0.3),
      r,
      Paint()
        ..color = const Color(0xFF0D2B36).withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
    );

    // ── Specular highlight — glassy reflection on the sunlit side ──
    c.drawOval(
      Rect.fromCenter(
        center: Offset(p.dx - r * 0.3, p.dy - r * 0.3),
        width: r * 0.5,
        height: r * 0.25,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14 + 0.04 * sin(t * 0.6))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.1),
    );

    // ── Subtle rim light ──
    c.drawCircle(
      p,
      r,
      Paint()
        ..color = const Color(0xFF80DEEA).withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  // ─── STEAM: dense fog + violent geysers erupting ───
  void _drawSteamPlanet(Canvas c, Offset p, double r, Color col, double t) {
    final rng = Random(p.dx.toInt() ^ p.dy.toInt());

    // ── Thick ambient fog blanket ──
    for (var ring = 0; ring < 4; ring++) {
      final fogR = r * (2.2 + ring * 0.5) + sin(t * 0.15 + ring) * r * 0.15;
      final fogAlpha = (0.04 - ring * 0.008).clamp(0.005, 0.06);
      c.drawCircle(
        Offset(
          p.dx + cos(t * 0.08 + ring * 1.7) * r * 0.2,
          p.dy + sin(t * 0.1 + ring * 2.1) * r * 0.15,
        ),
        fogR,
        Paint()
          ..color = col.withValues(alpha: fogAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
      );
    }

    // ── Rolling fog clouds (mid-layer) ──
    for (var i = 0; i < 8; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final dist = r * (0.8 + rng.nextDouble() * 1.2);
      final drift = t * (0.12 + rng.nextDouble() * 0.08);
      final cx = p.dx + cos(angle + drift) * dist;
      final cy = p.dy + sin(angle + drift * 0.7) * dist;
      final cr = r * (0.3 + 0.2 * sin(t * 0.3 + i * 0.9));
      final a = (0.08 + 0.04 * sin(t * 0.4 + i * 1.1)).clamp(0.0, 0.15);
      c.drawCircle(
        Offset(cx, cy),
        cr,
        Paint()
          ..color = Color.lerp(col, Colors.white, 0.15)!.withValues(alpha: a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3),
      );
    }

    // ── Inner mist swirl ──
    for (var i = 0; i < 5; i++) {
      final cx = p.dx + cos(t * 0.3 + i * 1.2) * r * 0.4;
      final cy = p.dy + sin(t * 0.4 + i * 1.5) * r * 0.3;
      final cr = r * (0.5 + 0.2 * sin(t * 0.5 + i));
      c.drawCircle(
        Offset(cx, cy),
        cr,
        Paint()
          ..color = col.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    // ── Core sphere ──
    _drawSphere(c, p, r, col, highlight: 0.5, shadow: 0.2);

    // ── Surface cracks (hot vents) ──
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: p, radius: r)));
    for (var i = 0; i < 4; i++) {
      final va = rng.nextDouble() * pi * 2;
      final vd = rng.nextDouble() * r * 0.6;
      final vx = p.dx + cos(va) * vd;
      final vy = p.dy + sin(va) * vd;
      final glow = (0.25 + 0.15 * sin(t * 1.5 + i * 2.0)).clamp(0.0, 0.5);
      c.drawCircle(
        Offset(vx, vy),
        r * 0.06,
        Paint()
          ..color = Colors.orangeAccent.withValues(alpha: glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    c.restore();

    // ── Geysers erupting from the surface ──
    for (var g = 0; g < 5; g++) {
      final gAngle = rng.nextDouble() * pi * 2;
      // Each geyser has its own phase so they don't all fire simultaneously
      final phase = (t * (0.6 + rng.nextDouble() * 0.4) + g * 1.8) % (pi * 2);
      final intensity = sin(phase).clamp(0.0, 1.0); // 0 = dormant, 1 = peak
      if (intensity < 0.15) continue; // skip dormant geysers

      // Geyser origin on planet surface
      final gx = p.dx + cos(gAngle) * r * 0.85;
      final gy = p.dy + sin(gAngle) * r * 0.85;
      // Direction outward from planet center
      final ndx = cos(gAngle);
      final ndy = sin(gAngle);
      final height = r * (0.6 + intensity * 1.0);

      // Draw geyser plume (series of fading circles)
      for (var s = 0; s < 6; s++) {
        final frac = s / 6.0;
        final sx = gx + ndx * height * frac;
        final sy = gy + ndy * height * frac;
        final sr = r * (0.04 + 0.08 * frac) * intensity;
        final sa = ((0.35 - frac * 0.3) * intensity).clamp(0.0, 0.4);
        // Steam color goes from warm white to translucent
        final steamCol = Color.lerp(
          Colors.white,
          col.withValues(alpha: 0),
          frac,
        )!;
        c.drawCircle(
          Offset(sx, sy),
          sr,
          Paint()
            ..color = steamCol.withValues(alpha: sa)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, sr * 1.5),
        );
      }

      // Small orange flash at the vent base when intense
      if (intensity > 0.5) {
        c.drawCircle(
          Offset(gx, gy),
          r * 0.05,
          Paint()
            ..color = Colors.orangeAccent.withValues(
              alpha: (intensity - 0.5) * 0.6,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }

    // ── Top-layer wispy fog tendrils that drift slowly ──
    for (var i = 0; i < 6; i++) {
      final tAngle = rng.nextDouble() * pi * 2 + t * 0.05;
      final tDist = r * (1.0 + rng.nextDouble() * 0.6);
      final tw = r * (0.15 + 0.1 * sin(t * 0.25 + i));
      final th = r * 0.06;
      final tx = p.dx + cos(tAngle) * tDist;
      final ty = p.dy + sin(tAngle) * tDist;
      c.save();
      c.translate(tx, ty);
      c.rotate(tAngle);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: tw * 2, height: th * 2),
        Paint()
          ..color = col.withValues(alpha: 0.06 + 0.03 * sin(t * 0.3 + i * 0.7))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.15),
      );
      c.restore();
    }
  }

  // ─── EARTH: large solid sphere ───
  void _drawEarthPlanet(Canvas c, Offset p, double r, Color col, double t) {
    final rng = Random(p.dx.toInt() ^ p.dy.toInt());

    // ── Deep-core glow — warm orange pulsing from below ──
    final coreAlpha = 0.08 + 0.03 * sin(t * 0.5);
    c.drawCircle(
      p,
      r * 1.6,
      Paint()
        ..color = const Color(0xFFFF6B00).withValues(alpha: coreAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8),
    );

    // ── Dusty atmosphere halo ──
    c.drawCircle(
      p,
      r * 2.0,
      Paint()
        ..color = col.withValues(alpha: 0.04 + 0.015 * sin(t * 0.3))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7),
    );
    c.drawCircle(
      p,
      r * 1.4,
      Paint()
        ..color = col.withValues(alpha: 0.06 + 0.02 * sin(t * 0.6))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
    );

    // ── Base sphere — rich earthy gradient ──
    _drawSphere(c, p, r, col, shadow: 0.55, highlight: 0.25);

    // ── Clip surface details to the planet ──
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: p, radius: r)));

    // ── Continental masses — irregular darker patches ──
    for (var i = 0; i < 6; i++) {
      final cAngle = rng.nextDouble() * pi * 2;
      final cDist = rng.nextDouble() * r * 0.7;
      final cSize = r * (0.15 + rng.nextDouble() * 0.2);
      final cx2 = p.dx + cos(cAngle + t * 0.015) * cDist;
      final cy2 = p.dy + sin(cAngle + t * 0.015) * cDist;

      // Irregular shape with 6 control points
      final contPath = Path();
      for (var v = 0; v <= 6; v++) {
        final va = v / 6.0 * pi * 2;
        final vr = cSize * (0.7 + rng.nextDouble() * 0.6);
        final vx = cx2 + cos(va) * vr;
        final vy = cy2 + sin(va) * vr;
        if (v == 0) {
          contPath.moveTo(vx, vy);
        } else {
          contPath.lineTo(vx, vy);
        }
      }
      contPath.close();

      final shade = Color.lerp(
        col,
        Colors.black,
        0.25 + rng.nextDouble() * 0.15,
      )!;
      c.drawPath(
        contPath,
        Paint()
          ..color = shade.withValues(alpha: 0.25 + 0.05 * sin(t * 0.2 + i))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // ── Seismic pulse — concentric rings that expand outward slowly ──
    for (var i = 0; i < 3; i++) {
      final pulsePhase = (t * 0.3 + i * 2.1) % (pi * 2);
      final pulseFrac = pulsePhase / (pi * 2);
      final pulseR = r * (0.3 + pulseFrac * 0.7);
      final pulseAlpha = (0.1 * (1.0 - pulseFrac)).clamp(0.0, 1.0);
      c.drawCircle(
        p,
        pulseR,
        Paint()
          ..color = col.withValues(alpha: pulseAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    c.restore();

    // ── Orbiting rock debris — chunks of stone circling the planet ──
    for (var i = 0; i < 8; i++) {
      final orbitR = r * (1.3 + 0.25 * sin(i * 2.3));
      final speed = (0.2 + rng.nextDouble() * 0.15) * (i.isEven ? 1 : -1);
      final a = t * speed + i * pi * 2 / 8;
      final bob = sin(t * 1.5 + i * 0.7) * r * 0.05;
      final rx = p.dx + cos(a) * orbitR;
      final ry = p.dy + sin(a) * orbitR * 0.4 + bob;
      final rockSize = 2.0 + rng.nextDouble() * 2.5;
      final rockAlpha = (0.4 + 0.15 * sin(t * 2 + i)).clamp(0.0, 1.0);

      // Shadow
      c.drawCircle(
        Offset(rx, ry),
        rockSize * 2.5,
        Paint()
          ..color = col.withValues(alpha: rockAlpha * 0.15)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rockSize * 1.5),
      );
      // Rock body — slightly angular look via rect
      c.save();
      c.translate(rx, ry);
      c.rotate(t * 0.8 + i * 1.5);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: rockSize * 2,
            height: rockSize * 1.4,
          ),
          Radius.circular(rockSize * 0.3),
        ),
        Paint()
          ..color = Color.lerp(
            col,
            Colors.white,
            0.15,
          )!.withValues(alpha: rockAlpha),
      );
      c.restore();
    }

    // ── Gravitational dust haze — faint particles drifting near surface ──
    for (var i = 0; i < 12; i++) {
      final da = t * 0.1 * (i.isEven ? 1 : -1) + i * pi / 6;
      final dr = r * (1.05 + 0.15 * sin(t * 0.8 + i * 0.5));
      final dx2 = p.dx + cos(da) * dr;
      final dy2 = p.dy + sin(da) * dr;
      final dustAlpha = (0.12 + 0.06 * sin(t * 1.5 + i)).clamp(0.0, 1.0);
      c.drawCircle(
        Offset(dx2, dy2),
        1.0 + rng.nextDouble(),
        Paint()..color = col.withValues(alpha: dustAlpha),
      );
    }
  }

  // ─── MUD: bubbling, murky swamp planet with gas vents & mudflows ───
  void _drawMudPlanet(Canvas c, Offset p, double r, Color col, double t) {
    final rng = Random(p.dx.toInt() ^ p.dy.toInt());

    // ── Thick murky atmosphere halo ──
    c.drawCircle(
      p,
      r * 2.2,
      Paint()
        ..color = col.withValues(alpha: 0.05 + 0.02 * sin(t * 0.25))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.9),
    );
    c.drawCircle(
      p,
      r * 1.5,
      Paint()
        ..color = col.withValues(alpha: 0.08 + 0.03 * sin(t * 0.4))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4),
    );

    // ── Subsurface methane glow — greenish pulse from below ──
    final methaneAlpha = 0.06 + 0.03 * sin(t * 0.35);
    c.drawCircle(
      p,
      r * 1.3,
      Paint()
        ..color = const Color(0xFF5D6B2A).withValues(alpha: methaneAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
    );

    // ── Base sphere — dark muddy brown ──
    _drawSphere(c, p, r, col, shadow: 0.65, highlight: 0.12);

    // ── Clip surface details to the planet ──
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: p, radius: r)));

    // ── Mudflow bands — horizontal streaks of darker/lighter mud ──
    const flowLayers = 6;
    for (var w = 0; w < flowLayers; w++) {
      final bandY = p.dy - r + (2 * r) * (w + 0.5) / flowLayers;
      final bandColor = Color.lerp(
        const Color(0xFF3E2723),
        const Color(0xFF6D4C41),
        w / flowLayers,
      )!;
      final bandPath = Path();
      final amplitude = r * (0.04 + 0.025 * sin(t * 0.3 + w));
      final freq = 2.0 + w * 0.4;
      final speed = 0.25 + w * 0.08; // slow viscous flow

      bandPath.moveTo(p.dx - r - 10, bandY);
      for (var x = -r - 10; x <= r + 10; x += 4) {
        final bx = p.dx + x;
        final by =
            bandY +
            sin(x / r * freq * pi + t * speed) * amplitude +
            cos(x / r * (freq + 0.5) * pi + t * speed * 0.5 + w) *
                amplitude *
                0.6;
        bandPath.lineTo(bx, by);
      }
      bandPath.lineTo(p.dx + r + 10, p.dy + r + 10);
      bandPath.lineTo(p.dx - r - 10, p.dy + r + 10);
      bandPath.close();

      c.drawPath(
        bandPath,
        Paint()..color = bandColor.withValues(alpha: 0.18 + 0.04 * w),
      );
    }

    // ── Mud patches — irregular darker blotches ──
    for (var i = 0; i < 5; i++) {
      final pAngle = rng.nextDouble() * pi * 2;
      final pDist = rng.nextDouble() * r * 0.65;
      final pSize = r * (0.12 + rng.nextDouble() * 0.18);
      final px = p.dx + cos(pAngle + t * 0.01) * pDist;
      final py = p.dy + sin(pAngle + t * 0.01) * pDist;

      final patchPath = Path();
      for (var v = 0; v <= 7; v++) {
        final va = v / 7.0 * pi * 2;
        final vr = pSize * (0.6 + rng.nextDouble() * 0.8);
        final vx = px + cos(va) * vr;
        final vy = py + sin(va) * vr;
        if (v == 0) {
          patchPath.moveTo(vx, vy);
        } else {
          patchPath.lineTo(vx, vy);
        }
      }
      patchPath.close();

      c.drawPath(
        patchPath,
        Paint()
          ..color = Color.lerp(
            col,
            Colors.black,
            0.35,
          )!.withValues(alpha: 0.2 + 0.04 * sin(t * 0.15 + i))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // ── Bubbles — rising gas pockets on the surface ──
    for (var i = 0; i < 10; i++) {
      final bubblePhase =
          (t * (0.4 + rng.nextDouble() * 0.3) + i * 1.7) % (pi * 2);
      final bubbleFrac = bubblePhase / (pi * 2);
      final bx = p.dx + (rng.nextDouble() - 0.5) * r * 1.2;
      final by = p.dy + r * 0.4 - bubbleFrac * r * 1.0;
      final bubbleR =
          r * (0.02 + 0.02 * sin(bubblePhase)) * (1.0 - bubbleFrac * 0.6);
      final bubbleAlpha = (0.3 * (1.0 - bubbleFrac)).clamp(0.0, 1.0);

      c.drawCircle(
        Offset(bx, by),
        bubbleR,
        Paint()
          ..color = Color.lerp(
            col,
            Colors.white,
            0.3,
          )!.withValues(alpha: bubbleAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, bubbleR * 0.5),
      );
    }

    // ── Mud ripple rings — slow concentric expanding circles ──
    for (var i = 0; i < 3; i++) {
      final ripplePhase = (t * 0.2 + i * 2.1) % (pi * 2);
      final rippleFrac = ripplePhase / (pi * 2);
      final rippleR = r * (0.15 + rippleFrac * 0.5);
      final rippleAlpha = (0.12 * (1.0 - rippleFrac)).clamp(0.0, 1.0);
      final rcx = p.dx + (rng.nextDouble() - 0.5) * r * 0.5;
      final rcy = p.dy + (rng.nextDouble() - 0.5) * r * 0.5;
      c.drawCircle(
        Offset(rcx, rcy),
        rippleR,
        Paint()
          ..color = col.withValues(alpha: rippleAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    c.restore();

    // ── Gas vent plumes — wispy columns rising above the surface ──
    for (var i = 0; i < 4; i++) {
      final ventAngle = rng.nextDouble() * pi * 2;
      final ventX = p.dx + cos(ventAngle) * r * 0.6;
      final ventY = p.dy + sin(ventAngle) * r * 0.6;
      for (var j = 0; j < 3; j++) {
        final plumeY =
            ventY -
            r * (0.3 + j * 0.15) -
            sin(t * 0.5 + i * 1.3 + j) * r * 0.08;
        final plumeX = ventX + cos(t * 0.3 + i * 2.0 + j * 0.8) * r * 0.06;
        final plumeAlpha = (0.08 - j * 0.02).clamp(0.0, 1.0);
        final plumeR = r * (0.04 + j * 0.02);
        c.drawCircle(
          Offset(plumeX, plumeY),
          plumeR,
          Paint()
            ..color = const Color(0xFF8D8D6A).withValues(alpha: plumeAlpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, plumeR * 2),
        );
      }
    }

    // ── Orbiting mud clumps — chunky debris in slow orbit ──
    for (var i = 0; i < 6; i++) {
      final orbitR = r * (1.25 + 0.2 * sin(i * 1.8));
      final speed = (0.12 + rng.nextDouble() * 0.08) * (i.isEven ? 1 : -1);
      final a = t * speed + i * pi * 2 / 6;
      final bob = sin(t * 0.8 + i * 0.9) * r * 0.04;
      final mx = p.dx + cos(a) * orbitR;
      final my = p.dy + sin(a) * orbitR * 0.35 + bob;
      final clumpSize = 1.5 + rng.nextDouble() * 2.0;
      final clumpAlpha = (0.35 + 0.1 * sin(t * 1.2 + i)).clamp(0.0, 1.0);

      // Glow
      c.drawCircle(
        Offset(mx, my),
        clumpSize * 2.0,
        Paint()
          ..color = col.withValues(alpha: clumpAlpha * 0.12)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, clumpSize * 1.2),
      );
      // Clump body — rounded blob
      c.save();
      c.translate(mx, my);
      c.rotate(t * 0.4 + i * 1.1);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: clumpSize * 2.2,
            height: clumpSize * 1.6,
          ),
          Radius.circular(clumpSize * 0.6),
        ),
        Paint()
          ..color = Color.lerp(
            col,
            Colors.white,
            0.1,
          )!.withValues(alpha: clumpAlpha),
      );
      c.restore();
    }

    // ── Surface sheen — dull matte highlight ──
    c.drawOval(
      Rect.fromCenter(
        center: Offset(p.dx - r * 0.25, p.dy - r * 0.3),
        width: r * 0.7,
        height: r * 0.35,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06 + 0.02 * sin(t * 0.5))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.2),
    );
  }

  // ─── DUST: tiny, hazy, with orbiting debris ring ───
  void _drawDustPlanet(Canvas c, Offset p, double r, Color col, double t) {
    // Debris ring
    final ringPaint = Paint()
      ..color = col.withValues(alpha: 0.25)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(1.0, 0.3); // flatten into ellipse
    c.drawCircle(Offset.zero, r * 2.2, ringPaint);
    c.restore();
    _drawSphere(c, p, r, col, shadow: 0.4);
    // Dust motes orbiting
    for (var i = 0; i < 8; i++) {
      final a = t * 0.6 + i * pi / 4;
      final ox = p.dx + cos(a) * r * 2.0;
      final oy = p.dy + sin(a) * r * 0.6;
      c.drawCircle(
        Offset(ox, oy),
        2.0,
        Paint()..color = col.withValues(alpha: 0.5),
      );
    }
  }

  // ─── CRYSTAL: bright refractive sphere ───
  void _drawCrystalPlanet(Canvas c, Offset p, double r, Color col, double t) {
    _drawSphere(c, p, r, col, highlight: 0.6, shadow: 0.3);
  }

  // ─── AIR: ethereal wind sphere with swirling currents ───
  void _drawAirPlanet(Canvas c, Offset p, double r, Color col, double t) {
    // Outer atmospheric glow — large, barely visible halo
    c.drawCircle(
      p,
      r * 2.5,
      Paint()
        ..color = col.withValues(alpha: 0.04 + 0.02 * sin(t * 0.4))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.2),
    );
    c.drawCircle(
      p,
      r * 1.8,
      Paint()
        ..color = col.withValues(alpha: 0.06 + 0.02 * sin(t * 0.7))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
    );

    // Base sphere — very translucent
    _drawSphere(c, p, r, col, highlight: 0.5, shadow: 0.15);

    // Save for clipped surface details
    c.save();
    final clipPath = Path()..addOval(Rect.fromCircle(center: p, radius: r));
    c.clipPath(clipPath);

    // Swirling wind bands — horizontal streaks that drift
    final rng = Random(p.dx.toInt() ^ p.dy.toInt());
    for (var i = 0; i < 7; i++) {
      final bandY = p.dy - r + (i + 0.5) * (2 * r / 7);
      final drift = t * (0.8 + rng.nextDouble() * 0.6) * (i.isEven ? 1 : -1);
      final waveAmp = r * 0.08 * sin(t * 1.2 + i * 1.1);
      final bandWidth = r * (0.15 + rng.nextDouble() * 0.1);

      final bandPath = Path();
      for (var s = 0; s <= 20; s++) {
        final frac = s / 20.0;
        final x = p.dx - r * 1.1 + frac * r * 2.2;
        final y =
            bandY +
            sin(frac * pi * 3 + drift) * waveAmp +
            cos(frac * pi * 2 + drift * 0.7) * waveAmp * 0.5;
        if (s == 0) {
          bandPath.moveTo(x, y - bandWidth / 2);
        }
        bandPath.lineTo(x, y - bandWidth / 2);
      }
      for (var s = 20; s >= 0; s--) {
        final frac = s / 20.0;
        final x = p.dx - r * 1.1 + frac * r * 2.2;
        final y =
            bandY +
            sin(frac * pi * 3 + drift) * waveAmp +
            cos(frac * pi * 2 + drift * 0.7) * waveAmp * 0.5;
        bandPath.lineTo(x, y + bandWidth / 2);
      }
      bandPath.close();

      final alpha = (0.06 + 0.03 * sin(t * 0.9 + i)).clamp(0.0, 1.0);
      c.drawPath(
        bandPath,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, bandWidth * 0.6),
      );
    }

    // Cyclone eye — a soft spiral near the center
    final eyeX = p.dx + cos(t * 0.15) * r * 0.15;
    final eyeY = p.dy + sin(t * 0.2) * r * 0.1;
    for (var ring = 0; ring < 4; ring++) {
      final ringR = r * (0.08 + ring * 0.06);
      final ringAngle = t * (1.5 - ring * 0.3);
      final spiralPath = Path();
      for (var s = 0; s <= 30; s++) {
        final frac = s / 30.0;
        final a = ringAngle + frac * pi * 2;
        final sr = ringR * (0.6 + frac * 0.4);
        final sx = eyeX + cos(a) * sr;
        final sy = eyeY + sin(a) * sr;
        if (s == 0) {
          spiralPath.moveTo(sx, sy);
        } else {
          spiralPath.lineTo(sx, sy);
        }
      }
      c.drawPath(
        spiralPath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12 - ring * 0.02)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    c.restore();

    // Orbiting zephyr wisps — small bright motes riding the wind
    for (var i = 0; i < 10; i++) {
      final orbitR = r * (1.1 + 0.3 * sin(i * 1.7));
      final speed = (0.4 + rng.nextDouble() * 0.3) * (i.isEven ? 1 : -1);
      final a = t * speed + i * pi * 2 / 10;
      // Slight vertical bob
      final bob = sin(t * 2.0 + i * 0.9) * r * 0.1;
      final wx = p.dx + cos(a) * orbitR;
      final wy = p.dy + sin(a) * orbitR * 0.35 + bob;
      final moteR = 1.5 + rng.nextDouble() * 1.5;
      final moteAlpha = (0.3 + 0.2 * sin(t * 3 + i)).clamp(0.0, 1.0);

      // Glow
      c.drawCircle(
        Offset(wx, wy),
        moteR * 3,
        Paint()
          ..color = col.withValues(alpha: moteAlpha * 0.2)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, moteR * 2),
      );
      // Core
      c.drawCircle(
        Offset(wx, wy),
        moteR,
        Paint()..color = Colors.white.withValues(alpha: moteAlpha),
      );
    }

    // Wind streaks — faint curved lines radiating outward
    for (var i = 0; i < 5; i++) {
      final streakAngle = t * 0.2 + i * pi * 2 / 5;
      final streakPath = Path();
      final startR = r * 1.05;
      final endR = r * 1.6 + sin(t * 0.8 + i) * r * 0.2;
      for (var s = 0; s <= 12; s++) {
        final frac = s / 12.0;
        final sr = startR + (endR - startR) * frac;
        final curve = sin(frac * pi * 1.5 + t * 1.5) * 0.15;
        final sa = streakAngle + curve * frac;
        final sx = p.dx + cos(sa) * sr;
        final sy = p.dy + sin(sa) * sr;
        if (s == 0) {
          streakPath.moveTo(sx, sy);
        } else {
          streakPath.lineTo(sx, sy);
        }
      }
      c.drawPath(
        streakPath,
        Paint()
          ..color = col.withValues(alpha: 0.08 + 0.04 * sin(t + i))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  // ─── PLANT: deep green sphere ───
  void _drawPlantPlanet(Canvas c, Offset p, double r, Color col, double t) {
    // Base green sphere
    _drawSphere(c, p, r, const Color(0xFF33691E), shadow: 0.5);

    // Lichen patches on the surface
    final rng = Random(p.dx.toInt() ^ p.dy.toInt());
    for (var i = 0; i < 6; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final dist = r * (0.3 + rng.nextDouble() * 0.45);
      final patchR = r * (0.08 + rng.nextDouble() * 0.12);
      c.drawCircle(
        Offset(p.dx + cos(angle) * dist, p.dy + sin(angle) * dist),
        patchR,
        Paint()
          ..color = const Color(0xFF558B2F).withValues(alpha: 0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, patchR * 0.5),
      );
    }

    // Animated vines extending outward
    const vineCount = 7;
    for (var v = 0; v < vineCount; v++) {
      final baseAngle =
          v * pi * 2 / vineCount + sin(t * 0.3 + v) * 0.08; // subtle base sway
      final vineLen = r * (1.2 + 0.6 * sin(t * 0.5 + v * 1.7));
      final segments = 12;

      final vinePath = Path();
      final leafPositions = <Offset>[];

      Offset prev = Offset(
        p.dx + cos(baseAngle) * r * 0.9,
        p.dy + sin(baseAngle) * r * 0.9,
      );
      vinePath.moveTo(prev.dx, prev.dy);

      for (var s = 1; s <= segments; s++) {
        final frac = s / segments;
        // Vine curves outward with sinusoidal sway
        final sway = sin(t * 1.5 + v * 2.3 + s * 0.8) * r * 0.15 * frac;
        final perpAngle = baseAngle + pi / 2;
        final dist = r * 0.9 + vineLen * frac;
        final pt = Offset(
          p.dx + cos(baseAngle) * dist + cos(perpAngle) * sway,
          p.dy + sin(baseAngle) * dist + sin(perpAngle) * sway,
        );
        vinePath.lineTo(pt.dx, pt.dy);
        prev = pt;

        // Mark leaf positions at intervals
        if (s % 3 == 0 && s < segments) {
          leafPositions.add(pt);
        }
      }

      // Vine stroke — thicker at base, thinner at tip (draw twice)
      final vineColor = Color.lerp(
        const Color(0xFF2E7D32),
        const Color(0xFF66BB6A),
        v / vineCount,
      )!;
      c.drawPath(
        vinePath,
        Paint()
          ..color = vineColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      // Inner lighter stroke
      c.drawPath(
        vinePath,
        Paint()
          ..color = const Color(0xFF81C784).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round,
      );

      // Leaves at intervals — small teardrop shapes
      for (var li = 0; li < leafPositions.length; li++) {
        final lp = leafPositions[li];
        final leafAngle =
            baseAngle +
            pi / 2 * (li.isEven ? 1 : -1) +
            sin(t * 2 + v + li) * 0.3;
        final leafSize = r * (0.08 + 0.04 * sin(t * 1.2 + li * 1.5));

        c.save();
        c.translate(lp.dx, lp.dy);
        c.rotate(leafAngle);

        final leafPath = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(
            leafSize * 0.6,
            -leafSize * 0.5,
            leafSize * 1.5,
            0,
          )
          ..quadraticBezierTo(leafSize * 0.6, leafSize * 0.5, 0, 0);

        c.drawPath(
          leafPath,
          Paint()..color = const Color(0xFF4CAF50).withValues(alpha: 0.85),
        );
        // Leaf vein
        c.drawLine(
          Offset.zero,
          Offset(leafSize * 1.2, 0),
          Paint()
            ..color = const Color(0xFF388E3C).withValues(alpha: 0.5)
            ..strokeWidth = 0.5,
        );
        c.restore();
      }

      // Glowing tip (bud / flower)
      final tipGlow = 0.4 + 0.3 * sin(t * 2 + v * 1.5);
      c.drawCircle(
        prev,
        r * 0.04,
        Paint()
          ..color = const Color(0xFFA5D6A7).withValues(alpha: tipGlow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06),
      );
      c.drawCircle(
        prev,
        r * 0.02,
        Paint()..color = Colors.white.withValues(alpha: tipGlow * 0.8),
      );
    }

    // Soft green atmospheric glow
    c.drawCircle(
      p,
      r * 1.5,
      Paint()
        ..color = const Color(
          0xFF4CAF50,
        ).withValues(alpha: 0.06 + 0.02 * sin(t))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
    );
  }

  // ─── POISON: sphere with toxic haze & purple fog ───
  void _drawPoisonPlanet(Canvas c, Offset p, double r, Color col, double t) {
    final rng = Random(p.dx.toInt() ^ p.dy.toInt());
    final fieldR = r * 12.0; // particleFieldRadius

    // ── Scattered purple fog clouds out to particle field ring ──
    for (var i = 0; i < 10; i++) {
      final fogAngle =
          rng.nextDouble() * pi * 2 + t * 0.05 * (i.isEven ? 1 : -1);
      final fogDist = r * 1.5 + rng.nextDouble() * (fieldR - r * 1.5) * 0.85;
      final fogX = p.dx + cos(fogAngle + i * 0.63) * fogDist;
      final fogY = p.dy + sin(fogAngle + i * 0.63) * fogDist;
      final fogSize = r * (0.4 + 0.25 * sin(t * 0.4 + i * 1.3));
      final fogAlpha = (0.06 + 0.03 * sin(t * 0.6 + i * 2.1)).clamp(0.0, 0.12);
      c.drawCircle(
        Offset(fogX, fogY),
        fogSize,
        Paint()
          ..color = const Color(0xFF9C27B0).withValues(alpha: fogAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fogSize * 0.7),
      );
    }

    _drawSphere(c, p, r, col, shadow: 0.5);
    // Haze around
    c.drawCircle(
      p,
      r * 1.3,
      Paint()
        ..color = const Color(0x1576FF03)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );
  }

  // ─── SPIRIT: ethereal pulsing sphere ───
  void _drawSpiritPlanet(Canvas c, Offset p, double r, Color col, double t) {
    // Pulsing translucent aura
    final pulseR = r * (1.0 + 0.08 * sin(t * 2));
    c.drawCircle(
      p,
      pulseR,
      Paint()
        ..color = col.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    _drawSphere(c, p, r * 0.8, col, highlight: 0.5, shadow: 0.3);
  }

  // ─── DARK: void with accretion disk ───
  void _drawDarkPlanet(Canvas c, Offset p, double r, Color col, double t) {
    // Accretion disk
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(1.0, 0.35);
    for (var i = 3; i >= 0; i--) {
      final dr = r * (1.8 + i * 0.3);
      c.drawCircle(
        Offset.zero,
        dr,
        Paint()
          ..color = Color.lerp(
            col,
            Colors.deepPurple,
            i * 0.2,
          )!.withValues(alpha: 0.08 + 0.03 * sin(t * 1.5 + i)),
      );
    }
    c.restore();
    // Black core
    c.drawCircle(p, r, Paint()..color = const Color(0xFF0A0010));
    // Edge glow
    c.drawCircle(
      p,
      r + 2,
      Paint()
        ..color = col.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  // ─── LIGHT: radiant sun with pulsing rays ───
  void _drawLightPlanet(Canvas c, Offset p, double r, Color col, double t) {
    // Rays
    final rayPaint = Paint()
      ..color = col.withValues(alpha: 0.12)
      ..strokeWidth = 3;
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6 + t * 0.2;
      final rayLen = r * (1.5 + 0.3 * sin(t * 2 + i * 0.8));
      c.drawLine(
        Offset(p.dx + cos(a) * r, p.dy + sin(a) * r),
        Offset(p.dx + cos(a) * rayLen, p.dy + sin(a) * rayLen),
        rayPaint,
      );
    }
    // Bright core
    c.drawCircle(
      p,
      r * 1.2,
      Paint()
        ..color = col.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );
    _drawSphere(c, p, r, col, highlight: 0.7, shadow: 0.15);
  }

  // ─── BLOOD: pulsing crimson sphere ───
  void _drawBloodPlanet(Canvas c, Offset p, double r, Color col, double t) {
    // Heartbeat pulse (brief expand every ~1.5s)
    final beat = pow(sin(t * pi / 0.75).clamp(0.0, 1.0), 8.0) * 0.06;
    final pr = r * (1.0 + beat);
    _drawSphere(c, p, pr, col, shadow: 0.6);
  }

  void _drawDefault(Canvas c, Offset p, double r, Color col) {
    _drawSphere(c, p, r, col);
  }
}

// ─────────────────────────────────────────────────────────
// STAR PARTICLE (background decoration)
// ─────────────────────────────────────────────────────────

class _StarParticle {
  _StarParticle({
    required this.x,
    required this.y,
    required this.brightness,
    required this.size,
    required this.twinkleSpeed,
  });

  final double x, y, brightness, size, twinkleSpeed;
}

// ─────────────────────────────────────────────────────────
// ELEMENT PARTICLE (collectible)
// ─────────────────────────────────────────────────────────

class ElementParticle {
  ElementParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.element,
    required this.life,
    required this.size,
  });

  double x, y, vx, vy, life, size;
  final String element;
}

// ─────────────────────────────────────────────────────────
// GARRISON CREATURE (stationed at home planet)
// ─────────────────────────────────────────────────────────

class _GarrisonCreature {
  _GarrisonCreature({
    required this.member,
    required this.position,
    required this.wanderAngle,
    required this.guardAngle,
    required this.guardRadius,
    required this.guardPhase,
    required this.speciesScale,
    required this.attackDamage,
    required this.specialDamage,
    required this.attackRange,
    required this.specialRange,
    required this.maxHp,
  }) : hp = maxHp;

  final CosmicPartyMember member;
  Offset position;
  double wanderAngle;
  final double guardAngle;
  final double guardRadius;
  final double guardPhase;
  double faceAngle = 0;
  final double speciesScale;

  // Health (for abilities that heal/shield)
  final int maxHp;
  int hp;

  // Sprite animation
  SpriteAnimation? anim;
  SpriteAnimationTicker? ticker;
  SpriteVisuals? visuals;
  double spriteScale = 1.0;

  // Combat
  final double attackDamage;
  final double specialDamage;
  final double attackRange;
  final double specialRange;
  double attackCooldown = 0;
  double specialCooldown = 8.0;

  // Shield/Charge state (Horn special)
  int shieldHp = 0;
  double chargeTimer = 0;
  Offset? chargeTarget;
  double chargeDamage = 0;

  // Blessing state (Kin special)
  double blessingTimer = 0;
  double blessingHealPerTick = 0;

  // Movement
  static const double wanderSpeed = 14.0;
}
