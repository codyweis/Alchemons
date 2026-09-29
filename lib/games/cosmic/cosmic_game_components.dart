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

  /// Whether this frame paints the blurred halos. Survival flies with it
  /// off: its arena already paints hundreds of things a frame and blur is
  /// the jank source there. The big halos are skipped rather than drawn
  /// sharp — unblurred they read as hard discs — and the small flares stay.
  bool _glow = true;

  void render(Canvas canvas, double elapsed, {String? skin, bool glow = true}) {
    _glow = glow;
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle + pi / 2); // adjust so 0 = up

    switch (skin) {
      case 'skin_phantom':
        _renderPhantom(canvas, elapsed);
      case 'skin_inferno':
        _renderInferno(canvas, elapsed);
      case 'skin_solar':
        _renderSolar(canvas, elapsed);
      case 'skin_crystal':
        _renderCrystal(canvas, elapsed);
      default:
        _renderDefault(canvas, elapsed);
    }

    canvas.restore();
  }

  // ── Default ship ──
  void _renderDefault(Canvas canvas, double elapsed) {
    final enginePulse = 0.85 + 0.15 * sin(elapsed * 9);

    // Engine glow
    if (_glow) {
      paintSoftCircle(
        canvas,
        const Offset(0, 18),
        9,
        const Color(0x7000CFFF).withValues(alpha: 0.55 * enginePulse),
        14,
      );
    }

    // Twin engine plumes
    for (final x in const [-5.5, 5.5]) {
      canvas.drawCircle(
        Offset(x, 15.5),
        3.2,
        Paint()..color = const Color(0xCC8AF7FF),
      );
    }

    // Trail particles
    for (var i = 1; i <= 4; i++) {
      final wobble = sin(elapsed * 8 + i * 1.35) * (2.2 + i * 0.15);
      final trailPaint = Paint()
        ..color = const Color(0xFF5ED8FF).withValues(alpha: 0.24 - i * 0.04);
      canvas.drawCircle(
        Offset(wobble, 18.0 + i * 7.5),
        4.2 - i * 0.65,
        trailPaint,
      );
    }

    // Broad silhouette with wings, intakes, and a defined tail.
    final wingPath = Path()
      ..moveTo(0, -21)
      ..lineTo(-7, -13)
      ..lineTo(-14, -5)
      ..lineTo(-19, 10)
      ..lineTo(-9, 8)
      ..lineTo(-4, 18)
      ..lineTo(0, 15)
      ..lineTo(4, 18)
      ..lineTo(9, 8)
      ..lineTo(19, 10)
      ..lineTo(14, -5)
      ..lineTo(7, -13)
      ..close();

    final fuselagePath = Path()
      ..moveTo(0, -24)
      ..lineTo(-4.5, -11)
      ..lineTo(-5.5, -1)
      ..lineTo(-3.5, 13)
      ..lineTo(0, 18)
      ..lineTo(3.5, 13)
      ..lineTo(5.5, -1)
      ..lineTo(4.5, -11)
      ..close();

    final wingPaint = Paint()
      ..shader = ui.Gradient.linear(const Offset(0, -21), const Offset(0, 18), [
        const Color(0xFF4FC3F7),
        const Color(0xFF0C5C86),
      ]);
    canvas.drawPath(wingPath, wingPaint);

    final fuselagePaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -24),
        const Offset(0, 18),
        [
          const Color(0xFFDDFBFF),
          const Color(0xFF90E8FF),
          const Color(0xFF0D79AB),
        ],
        const [0.0, 0.42, 1.0],
      );
    canvas.drawPath(fuselagePath, fuselagePaint);

    final canopyPath = Path()
      ..moveTo(0, -14)
      ..quadraticBezierTo(5.5, -11, 4.5, -2)
      ..quadraticBezierTo(0, 2.5, -4.5, -2)
      ..quadraticBezierTo(-5.5, -11, 0, -14)
      ..close();
    final canopyPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -14),
        const Offset(0, 2),
        [
          const Color(0xFFF6FEFF),
          const Color(0xFF6FE8FF),
          const Color(0xFF007EA7),
        ],
        const [0.0, 0.48, 1.0],
      );
    canvas.drawPath(canopyPath, canopyPaint);

    final intakePaint = Paint()
      ..color = const Color(0x6615334A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(-9, -3), const Offset(-12, 8), intakePaint);
    canvas.drawLine(const Offset(9, -3), const Offset(12, 8), intakePaint);

    final hullHighlight = Paint()
      ..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawLine(const Offset(0, -19), const Offset(0, 11), hullHighlight);

    final outlinePaint = Paint()
      ..color = const Color(0xAA00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(wingPath, outlinePaint);
    canvas.drawPath(fuselagePath, outlinePaint);

    // Running lights at the wing roots help sell the scale.
    canvas.drawCircle(
      const Offset(-10.5, 3.5),
      1.7,
      Paint()..color = const Color(0x99A8FFFF),
    );
    canvas.drawCircle(
      const Offset(10.5, 3.5),
      1.7,
      Paint()..color = const Color(0x9959D8FF),
    );

    // Cockpit glow
    canvas.drawCircle(
      const Offset(0, -5),
      3.6,
      Paint()..color = const Color(0xCC00E5FF),
    );
  }

  // ── Phantom Viper: angular stealth hull, violet exhaust ──
  void _renderPhantom(Canvas canvas, double elapsed) {
    final phase = sin(elapsed * 4.6);

    // Dark-matter exhaust glow
    if (_glow) {
      paintSoftCircle(
        canvas,
        const Offset(0, 18),
        8,
        const Color(0x708B00FF).withValues(alpha: 0.55 + phase * 0.06),
        16,
      );
    }

    for (final x in const [-5.0, 5.0]) {
      canvas.drawCircle(
        Offset(x, 15.5),
        2.8,
        Paint()..color = const Color(0xFFB56CFF),
      );
    }

    // Ghostly trail
    for (var i = 1; i <= 5; i++) {
      final wobble = sin(elapsed * 10 + i * 1.15) * (2.0 + i * 0.22);
      final alpha = (0.34 - i * 0.05).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(wobble, 18.0 + i * 6.5),
        3.8 - i * 0.5,
        Paint()..color = Color.fromRGBO(139, 0, 255, alpha),
      );
    }

    final wingPath = Path()
      ..moveTo(0, -26)
      ..lineTo(-7, -18)
      ..lineTo(-13, -7)
      ..lineTo(-20, 6)
      ..lineTo(-11, 5)
      ..lineTo(-6, 15)
      ..lineTo(0, 11)
      ..lineTo(6, 15)
      ..lineTo(11, 5)
      ..lineTo(20, 6)
      ..lineTo(13, -7)
      ..lineTo(7, -18)
      ..close();

    final fuselagePath = Path()
      ..moveTo(0, -29)
      ..lineTo(-3.5, -18)
      ..lineTo(-5, -2)
      ..lineTo(-2.8, 12)
      ..lineTo(0, 17)
      ..lineTo(2.8, 12)
      ..lineTo(5, -2)
      ..lineTo(3.5, -18)
      ..close();

    final wingPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -26),
        const Offset(0, 15),
        [
          const Color(0xFF3D2478),
          const Color(0xFF19122F),
          const Color(0xFF07070F),
        ],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawPath(wingPath, wingPaint);

    final fuselagePaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -29),
        const Offset(0, 17),
        [
          const Color(0xFF8E6CFF),
          const Color(0xFF32205F),
          const Color(0xFF090912),
        ],
        const [0.0, 0.32, 1.0],
      );
    canvas.drawPath(fuselagePath, fuselagePaint);

    final canopyPath = Path()
      ..moveTo(0, -18)
      ..quadraticBezierTo(4.2, -15.5, 3.8, -6.5)
      ..quadraticBezierTo(0, -2, -3.8, -6.5)
      ..quadraticBezierTo(-4.2, -15.5, 0, -18)
      ..close();
    final canopyPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -18),
        const Offset(0, -2),
        [
          const Color(0xFFE9D9FF),
          const Color(0xFFB56CFF),
          const Color(0xFF461A7B),
        ],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawPath(canopyPath, canopyPaint);

    final bladePaint = Paint()
      ..color = const Color(0x883F2A6D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(const Offset(-12, -4), const Offset(-16, 7), bladePaint);
    canvas.drawLine(const Offset(12, -4), const Offset(16, 7), bladePaint);

    final hullGlow = Paint()
      ..color = const Color(0x66D2A7FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    if (_glow) {
      canvas.drawLine(const Offset(0, -23), const Offset(0, 9), hullGlow);
    }

    final outlinePaint = Paint()
      ..color = const Color(0x889945FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(wingPath, outlinePaint);
    canvas.drawPath(fuselagePath, outlinePaint);

    // Twin cockpit eyes and blade tips sell the stealth-upgrade silhouette.
    final eyeGlow = 0.72 + 0.28 * sin(elapsed * 4);
    canvas.drawCircle(
      const Offset(-3.2, -10),
      2.2,
      Paint()..color = Color.fromRGBO(180, 80, 255, eyeGlow),
    );
    canvas.drawCircle(
      const Offset(3.2, -10),
      2.2,
      Paint()..color = Color.fromRGBO(180, 80, 255, eyeGlow),
    );
    canvas.drawCircle(
      const Offset(-14.5, 6),
      1.3,
      Paint()..color = const Color(0x99C59BFF),
    );
    canvas.drawCircle(
      const Offset(14.5, 6),
      1.3,
      Paint()..color = const Color(0x99C59BFF),
    );
  }

  // ── Solar Dragoon: blazing golden hull, solar flares ──
  void _renderSolar(Canvas canvas, double elapsed) {
    final phase = sin(elapsed * 3.2);

    // Solar halo behind the ship gives it a radiant capital-ship profile.
    if (_glow) {
      paintSoftRing(
        canvas,
        const Offset(0, -1),
        18.5,
        const Color(0x66FFD54F).withValues(alpha: 0.34 + phase * 0.05),
        2.4,
        6,
      );
    }
    canvas.drawCircle(
      const Offset(0, -1),
      12.5,
      Paint()
        ..color = const Color(0x55FFF3B0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Triple engine array
    if (_glow) {
      paintSoftCircle(
        canvas,
        const Offset(0, 18),
        12,
        const Color(0x85FF9A00).withValues(alpha: 0.62 + phase * 0.07),
        18,
      );
    }
    for (final x in const [-8.0, 0.0, 8.0]) {
      canvas.drawCircle(
        Offset(x, 16),
        x == 0 ? 4.4 : 3.2,
        Paint()..color = const Color(0xFFFFD15C),
      );
    }

    // Trailing fire particles
    for (var i = 1; i <= 5; i++) {
      final wobble = sin(elapsed * 12 + i * 1.55) * (2.8 + i * 0.35);
      final alpha = (0.52 - i * 0.08).clamp(0.0, 1.0);
      final hue = i.isEven ? const Color(0xFFFF6F00) : const Color(0xFFFFC107);
      canvas.drawCircle(
        Offset(wobble, 18.0 + i * 7),
        5.0 - i * 0.72,
        Paint()..color = hue.withValues(alpha: alpha),
      );
    }

    // Floating solar motes
    for (var w = 0; w < 4; w++) {
      final flareAngle = elapsed * 1.3 + w * pi * 2 / 4;
      final flareLen = 7 + 4 * sin(elapsed * 4.2 + w * 1.7);
      final fx = cos(flareAngle) * (13 + flareLen);
      final fy = sin(flareAngle) * (13 + flareLen) * 0.42;
      if (_glow) {
        paintSoftCircle(
          canvas,
          Offset(fx, fy),
          3.2,
          const Color(0x55FFD95C),
          7,
        );
      } else {
        canvas.drawCircle(
          Offset(fx, fy),
          3.2,
          Paint()..color = const Color(0x55FFD95C),
        );
      }
    }

    // This skin is intentionally not a sleek dart; it's a radiant war-barge.
    final leftPodPath = Path()
      ..moveTo(-6, -15)
      ..lineTo(-12, -13)
      ..lineTo(-17, -6)
      ..lineTo(-21, 8)
      ..lineTo(-16, 12)
      ..lineTo(-11, 10)
      ..lineTo(-8, 17)
      ..lineTo(-4, 14)
      ..lineTo(-5, -2)
      ..close();
    final rightPodPath = Path()
      ..moveTo(6, -15)
      ..lineTo(12, -13)
      ..lineTo(17, -6)
      ..lineTo(21, 8)
      ..lineTo(16, 12)
      ..lineTo(11, 10)
      ..lineTo(8, 17)
      ..lineTo(4, 14)
      ..lineTo(5, -2)
      ..close();
    final coreHullPath = Path()
      ..moveTo(0, -30)
      ..lineTo(-4.5, -19)
      ..lineTo(-8, -9)
      ..lineTo(-7.2, 9)
      ..lineTo(-4.2, 20)
      ..lineTo(0, 24)
      ..lineTo(4.2, 20)
      ..lineTo(7.2, 9)
      ..lineTo(8, -9)
      ..lineTo(4.5, -19)
      ..close();
    final noseCrestPath = Path()
      ..moveTo(0, -34)
      ..lineTo(-3.5, -25)
      ..lineTo(0, -20)
      ..lineTo(3.5, -25)
      ..close();

    final podPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -16),
        const Offset(0, 17),
        [
          const Color(0xFFFFE999),
          const Color(0xFFFFA726),
          const Color(0xFFE65100),
        ],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawPath(leftPodPath, podPaint);
    canvas.drawPath(rightPodPath, podPaint);

    final corePaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -30),
        const Offset(0, 24),
        [
          const Color(0xFFFFFBE4),
          const Color(0xFFFFE082),
          const Color(0xFFFF8F00),
        ],
        const [0.0, 0.38, 1.0],
      );
    canvas.drawPath(coreHullPath, corePaint);

    final crestPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -34),
        const Offset(0, -20),
        [const Color(0xFFFFFFFF), const Color(0xFFFFD54F)],
      );
    canvas.drawPath(noseCrestPath, crestPaint);

    final canopyPath = Path()
      ..moveTo(0, -18)
      ..quadraticBezierTo(4.8, -15, 4.2, -4.5)
      ..quadraticBezierTo(0, 0.5, -4.2, -4.5)
      ..quadraticBezierTo(-4.8, -15, 0, -18)
      ..close();
    final canopyPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -18),
        const Offset(0, 1),
        [
          const Color(0xFFFFFFFF),
          const Color(0xFFFFF176),
          const Color(0xFFFFA000),
        ],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawPath(canopyPath, canopyPaint);

    final panelPaint = Paint()
      ..color = const Color(0x88A84300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawLine(const Offset(-10.5, -8), const Offset(-14, 9), panelPaint);
    canvas.drawLine(const Offset(10.5, -8), const Offset(14, 9), panelPaint);
    canvas.drawLine(const Offset(0, -20), const Offset(0, 16), panelPaint);

    final outlinePaint = Paint()
      ..color = const Color(0xAAFFB300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    canvas.drawPath(leftPodPath, outlinePaint);
    canvas.drawPath(rightPodPath, outlinePaint);
    canvas.drawPath(coreHullPath, outlinePaint);
    canvas.drawPath(noseCrestPath, outlinePaint);

    // Radiant cockpit and bright pod markers keep it readable at small size.
    final cockpitGlow = 0.82 + 0.18 * sin(elapsed * 3);
    canvas.drawCircle(
      const Offset(0, -8),
      4.4,
      Paint()..color = Color.fromRGBO(255, 214, 0, cockpitGlow),
    );
    canvas.drawCircle(
      const Offset(0, -8),
      1.9,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawCircle(
      const Offset(-14.5, 4.5),
      1.7,
      Paint()..color = const Color(0xFFFFE082),
    );
    canvas.drawCircle(
      const Offset(14.5, 4.5),
      1.7,
      Paint()..color = const Color(0xFFFFE082),
    );
  }

  // ── Inferno Raptor: aggressive flame-carved striker ──
  void _renderInferno(Canvas canvas, double elapsed) {
    final phase = sin(elapsed * 5.8);

    if (_glow) {
      paintSoftCircle(
        canvas,
        const Offset(0, 19),
        12,
        const Color(0x88FF5A1F).withValues(alpha: 0.58 + phase * 0.07),
        18,
      );
    }

    for (final x in const [-6.5, 6.5]) {
      canvas.drawCircle(
        Offset(x, 15.5),
        3.0,
        Paint()..color = const Color(0xFFFFB74D),
      );
    }

    // Flame lash exhaust
    for (var i = 1; i <= 5; i++) {
      final wobble = sin(elapsed * 13 + i * 1.25) * (2.8 + i * 0.45);
      final alpha = (0.48 - i * 0.07).clamp(0.0, 1.0);
      final ember = i.isEven
          ? const Color(0xFFFF3D00)
          : const Color(0xFFFFC400);
      canvas.drawCircle(
        Offset(wobble, 18.0 + i * 6.8),
        4.7 - i * 0.65,
        Paint()..color = ember.withValues(alpha: alpha),
      );
    }

    // Flickering fire tongues off the wings.
    for (final dir in const [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        final t = elapsed * 3.8 + i * 0.8;
        final flare = Path()
          ..moveTo(9 * dir, -2 + i * 4)
          ..quadraticBezierTo(
            (15 + i * 2) * dir,
            2 + sin(t) * 3,
            (11 + i) * dir,
            8 + i * 3,
          )
          ..quadraticBezierTo(
            (7 + i * 0.5) * dir,
            6 + i * 2,
            9 * dir,
            -2 + i * 4,
          );
        canvas.drawPath(
          flare,
          Paint()
            ..color = const Color(0x55FF8A00)
            ..maskFilter = _glow
                ? const MaskFilter.blur(BlurStyle.normal, 5)
                : null,
        );
      }
    }

    final wingPath = Path()
      ..moveTo(0, -28)
      ..lineTo(-5, -18)
      ..lineTo(-13, -10)
      ..lineTo(-21, 3)
      ..lineTo(-12, 5)
      ..lineTo(-8, 18)
      ..lineTo(0, 11)
      ..lineTo(8, 18)
      ..lineTo(12, 5)
      ..lineTo(21, 3)
      ..lineTo(13, -10)
      ..lineTo(5, -18)
      ..close();
    final fuselagePath = Path()
      ..moveTo(0, -31)
      ..lineTo(-3.2, -20)
      ..lineTo(-4.8, -2)
      ..lineTo(-2.8, 12)
      ..lineTo(0, 21)
      ..lineTo(2.8, 12)
      ..lineTo(4.8, -2)
      ..lineTo(3.2, -20)
      ..close();
    final bellyBladePath = Path()
      ..moveTo(0, 22)
      ..lineTo(-3.5, 13)
      ..lineTo(0, 16)
      ..lineTo(3.5, 13)
      ..close();

    canvas.drawPath(
      wingPath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -28),
          const Offset(0, 18),
          [
            const Color(0xFFFFB74D),
            const Color(0xFFFF6F00),
            const Color(0xFFB71C1C),
          ],
          const [0.0, 0.42, 1.0],
        ),
    );
    canvas.drawPath(
      fuselagePath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -31),
          const Offset(0, 21),
          [
            const Color(0xFFFFF3E0),
            const Color(0xFFFF8F00),
            const Color(0xFFD84315),
          ],
          const [0.0, 0.33, 1.0],
        ),
    );
    canvas.drawPath(bellyBladePath, Paint()..color = const Color(0xFFFF7043));

    final canopyPath = Path()
      ..moveTo(0, -19)
      ..quadraticBezierTo(4.2, -16, 3.6, -5)
      ..quadraticBezierTo(0, -0.5, -3.6, -5)
      ..quadraticBezierTo(-4.2, -16, 0, -19)
      ..close();
    canvas.drawPath(
      canopyPath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -19),
          const Offset(0, 0),
          [
            const Color(0xFFFFFFF8),
            const Color(0xFFFFD54F),
            const Color(0xFFFF5722),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    final ventPaint = Paint()
      ..color = const Color(0x88551B00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawLine(const Offset(-10, -5), const Offset(-14, 9), ventPaint);
    canvas.drawLine(const Offset(10, -5), const Offset(14, 9), ventPaint);
    canvas.drawLine(const Offset(0, -23), const Offset(0, 14), ventPaint);

    final outline = Paint()
      ..color = const Color(0xAAFFAB40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(wingPath, outline);
    canvas.drawPath(fuselagePath, outline);

    final cockpitGlow = 0.8 + 0.2 * sin(elapsed * 4.5);
    canvas.drawCircle(
      const Offset(0, -8),
      3.8,
      Paint()..color = Color.fromRGBO(255, 196, 0, cockpitGlow),
    );
    canvas.drawCircle(
      const Offset(-12.5, 3.5),
      1.6,
      Paint()..color = const Color(0xFFFFAB40),
    );
    canvas.drawCircle(
      const Offset(12.5, 3.5),
      1.6,
      Paint()..color = const Color(0xFFFF7043),
    );
  }

  // ── Crystal Bastion: faceted shard frigate with prismatic core ──
  void _renderCrystal(Canvas canvas, double elapsed) {
    final phase = sin(elapsed * 3.7);

    if (_glow) {
      paintSoftCircle(
        canvas,
        const Offset(0, 18),
        10,
        const Color(0x6698F5FF).withValues(alpha: 0.48 + phase * 0.05),
        16,
      );
    }

    // Floating shard motes
    for (var i = 0; i < 5; i++) {
      final angle = elapsed * 1.4 + i * pi * 2 / 5;
      final dist = 10.5 + (i.isEven ? 2.5 : 0.0);
      final p = Offset(cos(angle) * dist, sin(angle) * dist * 0.65 - 2);
      final shard = Path()
        ..moveTo(p.dx, p.dy - 2.5)
        ..lineTo(p.dx - 1.8, p.dy + 0.5)
        ..lineTo(p.dx, p.dy + 3)
        ..lineTo(p.dx + 1.8, p.dy + 0.5)
        ..close();
      canvas.drawPath(shard, Paint()..color = const Color(0x66C6F7FF));
    }

    for (final x in const [-5.0, 5.0]) {
      canvas.drawCircle(
        Offset(x, 15.5),
        2.8,
        Paint()..color = const Color(0xFFB3F0FF),
      );
    }

    // Icy shard exhaust
    for (var i = 1; i <= 5; i++) {
      final wobble = sin(elapsed * 9 + i * 1.4) * (1.6 + i * 0.18);
      final alpha = (0.34 - i * 0.05).clamp(0.0, 1.0);
      final shard = Path()
        ..moveTo(wobble, 18.0 + i * 6.8 - 3)
        ..lineTo(wobble - 2.1, 18.0 + i * 6.8 + 1)
        ..lineTo(wobble, 18.0 + i * 6.8 + 4)
        ..lineTo(wobble + 2.1, 18.0 + i * 6.8 + 1)
        ..close();
      canvas.drawPath(
        shard,
        Paint()..color = const Color(0xFF8DEBFF).withValues(alpha: alpha),
      );
    }

    final outerShardPath = Path()
      ..moveTo(0, -27)
      ..lineTo(-8, -18)
      ..lineTo(-16, -8)
      ..lineTo(-19, 5)
      ..lineTo(-10, 9)
      ..lineTo(-6, 20)
      ..lineTo(0, 15)
      ..lineTo(6, 20)
      ..lineTo(10, 9)
      ..lineTo(19, 5)
      ..lineTo(16, -8)
      ..lineTo(8, -18)
      ..close();
    final coreShardPath = Path()
      ..moveTo(0, -31)
      ..lineTo(-4.5, -18)
      ..lineTo(-6.5, -2)
      ..lineTo(-3, 14)
      ..lineTo(0, 22)
      ..lineTo(3, 14)
      ..lineTo(6.5, -2)
      ..lineTo(4.5, -18)
      ..close();
    final noseShardPath = Path()
      ..moveTo(0, -35)
      ..lineTo(-3, -27)
      ..lineTo(0, -22)
      ..lineTo(3, -27)
      ..close();

    canvas.drawPath(
      outerShardPath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -27),
          const Offset(0, 20),
          [
            const Color(0xFFE1FBFF),
            const Color(0xFF8BE9FF),
            const Color(0xFF5E7CE2),
          ],
          const [0.0, 0.42, 1.0],
        ),
    );
    canvas.drawPath(
      coreShardPath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -31),
          const Offset(0, 22),
          [
            const Color(0xFFFFFFFF),
            const Color(0xFFC6F7FF),
            const Color(0xFF6B8CFF),
          ],
          const [0.0, 0.36, 1.0],
        ),
    );
    canvas.drawPath(noseShardPath, Paint()..color = const Color(0xFFF2FEFF));

    final facetPaint = Paint()
      ..color = const Color(0x8878B7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(const Offset(0, -24), const Offset(0, 16), facetPaint);
    canvas.drawLine(const Offset(-10, -6), const Offset(-6, 11), facetPaint);
    canvas.drawLine(const Offset(10, -6), const Offset(6, 11), facetPaint);

    final outline = Paint()
      ..color = const Color(0xAACFF8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;
    canvas.drawPath(outerShardPath, outline);
    canvas.drawPath(coreShardPath, outline);
    canvas.drawPath(noseShardPath, outline);

    final coreGlow = 0.78 + 0.22 * sin(elapsed * 3.2);
    canvas.drawCircle(
      const Offset(0, -8),
      4.0,
      Paint()..color = Color.fromRGBO(190, 245, 255, coreGlow),
    );
    canvas.drawCircle(
      const Offset(0, -8),
      1.8,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawCircle(
      const Offset(-12.5, 4.5),
      1.5,
      Paint()..color = const Color(0xFFA8EEFF),
    );
    canvas.drawCircle(
      const Offset(12.5, 4.5),
      1.5,
      Paint()..color = const Color(0xFFA7C4FF),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PLANET COMPONENT
// ─────────────────────────────────────────────────────────

/// The art for [planet], built once and shared (space, encounter backdrop,
/// map card). Seeded by position so a planet always looks like itself.
PlanetArt planetArtFor(CosmicPlanet planet) => PlanetArt.of(
  planet.element,
  planet.position.dx.toInt() ^ planet.position.dy.toInt(),
);

class PlanetComponent {
  // The art is built here, at world load, rather than on the frame the
  // planet first scrolls into view.
  PlanetComponent({required this.planet}) : art = planetArtFor(planet);

  final CosmicPlanet planet;

  /// How it is drawn — see lib/games/cosmic/planets/.
  final PlanetArt art;

  void render(Canvas canvas, double elapsed, {bool drawLabel = true}) {
    final pos = planet.position;
    final r = planet.radius;
    final color = planet.color;

    // ── particle field ring ──
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(pos, planet.particleFieldRadius, ringPaint);

    art.paintBack(canvas, pos, r, elapsed);
    art.paintBody(canvas, pos, r, elapsed);
    art.paintFront(canvas, pos, r, elapsed);

    // ── element label ──
    if (!drawLabel) return;
    final tp = TextPainter(
      text: TextSpan(
        text: planetName(planet.element).toUpperCase(),
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
// PARALLAX STAR LAYER
// ─────────────────────────────────────────────────────────

class _ParallaxStar {
  _ParallaxStar({
    required this.x,
    required this.y,
    required this.brightness,
    required this.size,
    required this.twinkleSpeed,
  });

  final double x, y, brightness, size, twinkleSpeed;
}

class _ParallaxLayer {
  _ParallaxLayer({
    required this.factor,
    required int count,
    required double tile,
    required double maxSize,
    required double maxBrightness,
    required int seed,
  }) {
    final rng = Random(seed);
    for (var i = 0; i < count; i++) {
      stars.add(
        _ParallaxStar(
          x: rng.nextDouble() * tile,
          y: rng.nextDouble() * tile,
          brightness: maxBrightness * (0.4 + rng.nextDouble() * 0.6),
          size: 0.5 + rng.nextDouble() * (maxSize - 0.5),
          twinkleSpeed: 0.3 + rng.nextDouble() * 1.2,
        ),
      );
    }
  }

  // Fraction of camera movement this layer scrolls at (0 = fixed, 1 = world).
  final double factor;
  final List<_ParallaxStar> stars = [];
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
  double chargeSpeedMultiplier = 1.0;
  double chargeSweepRadius = 48.0;
  double chargeOvershootDistance = 80.0;
  double chargeFinalSweepRadius = 68.0;

  // Blessing state (Kin special)
  double blessingTimer = 0;
  double blessingHealPerTick = 0;

  // Kin support state. Garrison defenders cast the same specials as deployed
  // companions, so their non-projectile paths must survive beyond the cast
  // frame too.
  bool kinFireOrbitalFlameActive = false;
  double kinLavaPlateTimer = 0;
  double kinIceChargeTimer = 0;
  double kinIceChargeTotal = 0;
  double kinSteamBoilerTimer = 0;
  int kinSteamBoilerStacks = 0;
  double kinSteamStackDecayTimer = 0;
  double kinSteamStackCarry = 0;
  double kinLightningChargeTimer = 0;
  double kinDarkCloakTimer = 0;
  double kinBloodPactTimer = 0;
  double kinMudShipEnchantTimer = 0;
  int kinSpiritWispKills = 0;

  // Temporary basic-attack haste granted by some specials.
  double basicHasteTimer = 0;
  double basicHasteMultiplier = 1.0;
  double damageAmpTimer = 0;
  double damageAmpMultiplier = 1.0;

  int abilityKillStacks = 0;
  double pipSpiritEmpowerTimer = 0;
  double pipSteamWindowTimer = 0;
  Offset? lastPipPoisonHitPos;
  List<Projectile>? pendingChargeBurst;
  Offset? pendingChargeOrigin;
  double pendingChargeAngle = 0;

  // Movement
  static const double wanderSpeed = 14.0;
}
