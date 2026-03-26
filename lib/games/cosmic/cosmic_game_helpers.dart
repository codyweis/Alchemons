part of 'cosmic_game.dart';

enum _ContestCinematicMode { beauty, speed, strength, intelligence }

// In-world prismatic cascade painter helper.
void _drawPrismaticCascadeCanvas(
  Canvas canvas,
  double baseR,
  double spriteScale,
  double elapsed,
  double opacity,
) {
  final r = baseR * spriteScale;

  // Outer hue-cycling blurred glow layers
  for (int i = 0; i < 3; i++) {
    final layerHue = (elapsed * 120.0 + i * 60.0) % 360.0;
    final layerR = r * (1.6 - i * 0.35);
    final layerAlpha = (0.20 - i * 0.05).clamp(0.0, 1.0) * opacity;
    final paint = Paint()
      ..color = HSLColor.fromAHSL(layerAlpha, layerHue, 0.8, 0.6).toColor()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, layerR * 0.45);
    canvas.drawCircle(Offset.zero, layerR, paint);
  }

  // Rainbow sweep ring
  final ringR = r * 1.45;
  final ringThickness = max(2.0, r * 0.28);
  final colors = List.generate(
    12,
    (i) => HSLColor.fromAHSL(
      1.0,
      (elapsed * 90 + i * 30) % 360,
      0.75,
      0.6,
    ).toColor(),
  );
  final stops = List.generate(colors.length, (i) => i / (colors.length - 1));
  final shader = SweepGradient(
    colors: [...colors, colors.first],
    stops: [...stops, 1.0],
    transform: GradientRotation(elapsed * 2 * pi),
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: ringR));
  final ringPaint = Paint()
    ..shader = shader
    ..style = PaintingStyle.stroke
    ..strokeWidth = ringThickness
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, ringThickness * 0.6);
  canvas.drawCircle(Offset.zero, ringR, ringPaint);

  // Orbiting shards (two rings)
  for (int ring = 0; ring < 2; ring++) {
    final shardCount = ring == 0 ? 6 : 6;
    final orbitR = r * (ring == 0 ? 0.85 : 1.25);
    final shardLen = r * (ring == 0 ? 0.16 : 0.12);
    final shardWidth = shardLen * 0.45;
    for (int i = 0; i < shardCount; i++) {
      final ang =
          elapsed * (ring == 0 ? 1.8 : -1.2) + (i / shardCount) * 2 * pi;
      final hue = (elapsed * 90 + i * (360 / shardCount) + ring * 18) % 360;
      final px = cos(ang) * orbitR;
      final py = sin(ang) * orbitR;
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(ang + pi / 4);
      final path = Path()
        ..moveTo(0, -shardLen)
        ..lineTo(shardWidth, 0)
        ..lineTo(0, shardLen)
        ..lineTo(-shardWidth, 0)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = HSLColor.fromAHSL(opacity * 0.9, hue, 0.78, 0.64).toColor(),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = HSLColor.fromAHSL(opacity * 0.6, hue, 0.95, 0.9).toColor()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      canvas.restore();
    }
  }

  // Sparkles
  for (int i = 0; i < 14; i++) {
    final phase = (elapsed * 1.6 + i / 14) % 1.0;
    final dist = r * 0.45 + r * 0.9 * (sin(phase * pi));
    final a = elapsed * 1.2 + (i / 14) * 2 * pi;
    final hue = (elapsed * 80 + i * (360 / 14)) % 360;
    final px = cos(a) * dist;
    final py = sin(a) * dist;
    final starR = (1.2 + (1 - phase) * 2.2) * (0.9 + 0.1 * spriteScale);
    final starPaint = Paint()
      ..color = HSLColor.fromAHSL(opacity * 0.95, hue, 0.85, 0.75).toColor()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, starR * 0.4);
    canvas.drawCircle(Offset(px, py), starR, starPaint);
  }
}

void _drawRitualGoldCanvas(
  Canvas canvas,
  double radius,
  double elapsed,
  double opacity,
) {
  final orbit = elapsed * (2 * pi / 5.6);
  final pulse = 0.94 + 0.10 * sin(elapsed * 3.2);

  canvas.drawCircle(
    Offset.zero,
    radius * 1.34 * pulse,
    Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFE4A3).withValues(alpha: 0.22 * opacity),
              const Color(0xFFC99B2E).withValues(alpha: 0.14 * opacity),
              Colors.transparent,
            ],
            stops: const [0.0, 0.56, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: radius * 1.34),
          ),
  );

  for (final factor in [1.02, 0.76]) {
    canvas.drawCircle(
      Offset.zero,
      radius * factor,
      Paint()
        ..color = const Color(0xFFE9C76B).withValues(alpha: 0.42 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * (factor > 0.9 ? 0.08 : 0.05)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.04),
    );
  }

  void drawRuneRing(double ringRadius, double rotation, int count) {
    for (var i = 0; i < count; i++) {
      final angle = rotation + (i / count) * pi * 2;
      final p = Offset(cos(angle) * ringRadius, sin(angle) * ringRadius);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(angle + pi * 0.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * 0.08,
            height: radius * 0.20,
          ),
          Radius.circular(radius * 0.025),
        ),
        Paint()
          ..color = const Color(0xFFF5D989).withValues(alpha: 0.34 * opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.018),
      );
      canvas.restore();
    }
  }

  drawRuneRing(radius * 0.92, orbit, 14);
  drawRuneRing(radius * 0.62, -orbit * 0.84, 10);
}

double _cosmicEffectRadius({
  required double spriteScale,
  required double baseSpriteSize,
  double multiplier = 1.0,
  double minRadius = 10.0,
  double maxRadius = 38.0,
}) {
  final displayBase = baseSpriteSize * spriteScale;
  final effectDiameter = effectSizeFromDisplayBase(
    displayBase,
    multiplier: multiplier,
    minSize: minRadius * 2,
    maxSize: maxRadius * 2,
  );
  return effectDiameter * 0.5;
}

double _cosmicPrismaticBaseRadius({
  required double spriteScale,
  required double baseSpriteSize,
}) {
  final displayBase = baseSpriteSize * spriteScale;
  final prismaticSize = prismaticCascadeSizeFromDisplayBase(
    displayBase,
  ).clamp(34.0, 86.0);
  return prismaticSize * 0.5;
}

void _drawAlchemyGlowCanvas(
  Canvas canvas,
  double radius,
  double elapsed,
  double opacity,
) {
  final pulse = 0.85 + 0.2 * sin(elapsed * 4.0);
  final outerR = radius * 2.0 * pulse;
  final midR = radius * 1.45 * pulse;
  final coreR = radius * 0.9 * pulse;

  canvas.drawCircle(
    Offset.zero,
    outerR,
    Paint()
      ..color = const Color(0xFF6A5CFF).withValues(alpha: 0.20 * opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, outerR * 0.35),
  );
  canvas.drawCircle(
    Offset.zero,
    midR,
    Paint()
      ..color = const Color(0xFF25D1FF).withValues(alpha: 0.26 * opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, midR * 0.26),
  );
  canvas.drawCircle(
    Offset.zero,
    coreR,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.12 * opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, coreR * 0.18),
  );
}

void _drawElementalAuraCanvas(
  Canvas canvas,
  double radius,
  Color essence,
  double elapsed,
  double opacity,
) {
  final orbitR = radius * (1.10 + 0.06 * sin(elapsed * 2.0));
  canvas.drawCircle(
    Offset.zero,
    radius * 1.25,
    Paint()
      ..color = essence.withValues(alpha: 0.30 * opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.32),
  );
  canvas.drawCircle(
    Offset.zero,
    radius * 0.72,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.14 * opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.20),
  );
  for (int i = 0; i < 5; i++) {
    final a = elapsed * 2.0 + (i / 5) * pi * 2;
    final p = Offset(cos(a) * orbitR, sin(a) * orbitR);
    final flicker = 0.55 + 0.45 * sin(elapsed * 8.0 + i * 0.9);
    final pr = radius * (0.09 + 0.04 * flicker);
    canvas.drawCircle(
      p,
      pr,
      Paint()
        ..color = essence.withValues(alpha: (0.70 + 0.45 * flicker) * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, pr * 0.9),
    );
  }
}

void _drawVolcanicAuraCanvas(
  Canvas canvas,
  double radius,
  double elapsed,
  double opacity,
) {
  final spin = elapsed * 0.9;
  final ringR = radius * 1.5;
  final ringStroke = max(2.0, radius * 0.22);
  final shader = SweepGradient(
    colors: [
      const Color(0xFFFF7A18).withValues(alpha: 0.44 * opacity),
      const Color(0xFFFF3D00).withValues(alpha: 0.34 * opacity),
      const Color(0xFF8E24AA).withValues(alpha: 0.30 * opacity),
      const Color(0xFFFF7A18).withValues(alpha: 0.44 * opacity),
    ],
    stops: const [0.0, 0.35, 0.7, 1.0],
    transform: GradientRotation(spin),
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: ringR));
  canvas.drawCircle(
    Offset.zero,
    ringR,
    Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringStroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, ringStroke * 0.65),
  );

  final coreR = radius * 1.15;
  canvas.drawCircle(
    Offset.zero,
    coreR,
    Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.40 * opacity),
          Colors.amber.withValues(alpha: 0.32 * opacity),
          const Color(0xFFFF6D00).withValues(alpha: 0.24 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.28, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: coreR)),
  );

  for (int i = 0; i < 6; i++) {
    final a = elapsed * 3.0 + (i / 6) * pi * 2;
    final d = radius * 1.25;
    final p = Offset(cos(a) * d, sin(a) * d);
    canvas.drawCircle(
      p,
      radius * 0.10,
      Paint()
        ..color = Colors.amber.withValues(alpha: 0.65 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.12),
    );
  }
}

void _drawVoidRiftCanvas(
  Canvas canvas,
  double radius,
  double elapsed,
  double opacity,
) {
  final rotA = elapsed * 0.52;
  final rotB = -elapsed * 0.8;
  final outerR = radius * 2.1;
  final midR = radius * 1.5;
  final coreR = radius * 0.95;

  final outerShader = SweepGradient(
    colors: [
      const Color(0xFF4B0082).withValues(alpha: 0.0),
      const Color(0xFF6A0DAD).withValues(alpha: 0.46 * opacity),
      Colors.black.withValues(alpha: 0.58 * opacity),
      const Color(0xFF9400D3).withValues(alpha: 0.36 * opacity),
      Colors.black.withValues(alpha: 0.52 * opacity),
      const Color(0xFF4B0082).withValues(alpha: 0.0),
    ],
    stops: const [0.0, 0.18, 0.38, 0.58, 0.78, 1.0],
    transform: GradientRotation(rotA),
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: outerR));
  canvas.drawCircle(Offset.zero, outerR, Paint()..shader = outerShader);

  final midShader = SweepGradient(
    colors: [
      Colors.transparent,
      const Color(0xFFBB00FF).withValues(alpha: 0.45 * opacity),
      Colors.transparent,
      Colors.black.withValues(alpha: 0.60 * opacity),
      const Color(0xFFBB00FF).withValues(alpha: 0.25 * opacity),
      Colors.transparent,
    ],
    stops: const [0.0, 0.14, 0.34, 0.56, 0.76, 1.0],
    transform: GradientRotation(rotB),
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: midR));
  canvas.drawCircle(Offset.zero, midR, Paint()..shader = midShader);

  canvas.drawCircle(
    Offset.zero,
    coreR,
    Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.82 * opacity),
          const Color(0xFF3D0070).withValues(alpha: 0.62 * opacity),
          const Color(0xFF6A0DAD).withValues(alpha: 0.24 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 0.74, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: coreR))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.22),
  );
}

void _drawBeautyRadianceCanvas(
  Canvas canvas,
  double radius,
  double elapsed,
  double opacity,
) {
  final orbit = elapsed * 1.2;
  final pulse = 0.95 + 0.12 * sin(elapsed * 3.4);
  final haloR = radius * 1.35 * pulse;
  canvas.drawCircle(
    Offset.zero,
    haloR,
    Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF3E0).withValues(alpha: 0.18 * opacity),
          const Color(0xFFF8BBD0).withValues(alpha: 0.13 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: haloR)),
  );

  final ringR = radius * 1.03;
  final ringStroke = max(0.9, radius * 0.06);
  final ringShader = SweepGradient(
    transform: GradientRotation(orbit * 0.6),
    colors: [
      Colors.transparent,
      const Color(0xFFFFE082).withValues(alpha: 0.24 * opacity),
      const Color(0xFFF48FB1).withValues(alpha: 0.20 * opacity),
      const Color(0xFFFFE082).withValues(alpha: 0.24 * opacity),
      Colors.transparent,
    ],
    stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: ringR));
  canvas.drawCircle(
    Offset.zero,
    ringR,
    Paint()
      ..shader = ringShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringStroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, ringStroke * 0.36),
  );

  for (int i = 0; i < 14; i++) {
    final a = orbit + (i / 14) * 2 * pi;
    final p = Offset(cos(a) * radius * 0.92, sin(a) * radius * 0.92);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(a + pi / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 0.07,
          height: radius * 0.28,
        ),
        Radius.circular(radius * 0.04),
      ),
      Paint()
        ..color =
            Color.lerp(
              const Color(0xFFF8BBD0),
              const Color(0xFFFFE082),
              i / 14.0,
            )!.withValues(
              alpha:
                  (0.20 + 0.16 * (0.5 + 0.5 * sin(elapsed * 3 + i))) * opacity,
            ),
    );
    canvas.restore();
  }
}

void _drawSpeedFluxCanvas(
  Canvas canvas,
  double radius,
  double elapsed,
  double opacity,
) {
  final flow = elapsed * 4.6;

  canvas.drawCircle(
    Offset.zero,
    radius * 1.18,
    Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFE1F5FE).withValues(alpha: 0.14 * opacity),
              const Color(0xFF4FC3F7).withValues(alpha: 0.12 * opacity),
              Colors.transparent,
            ],
            stops: const [0.0, 0.62, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: radius * 1.18),
          ),
  );

  final arcPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = max(1.4, radius * 0.13)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.06);
  for (int i = 0; i < 3; i++) {
    final rr = radius * (0.75 + i * 0.22);
    final start = flow * (1.2 + i * 0.2) + i * 0.8;
    arcPaint.shader = SweepGradient(
      transform: GradientRotation(start),
      colors: [
        Colors.transparent,
        const Color(0xFF80DEEA).withValues(alpha: (0.22 + i * 0.07) * opacity),
        const Color(0xFF42A5F5).withValues(alpha: (0.48 + i * 0.10) * opacity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.42, 0.72, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: rr));
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: rr),
      start,
      1.58,
      false,
      arcPaint,
    );
  }

  final streakPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = max(1.0, radius * 0.07);
  for (int i = 0; i < 12; i++) {
    final phase = ((elapsed * 2.2) + i / 12.0) % 1.0;
    final a = flow * 0.9 + (i / 12) * 2 * pi;
    final endR = radius * (0.70 + 0.94 * phase);
    final startR = endR - radius * (0.34 + 0.2 * phase);
    final p0 = Offset(cos(a) * startR, sin(a) * startR);
    final p1 = Offset(cos(a) * endR, sin(a) * endR);
    streakPaint.shader = LinearGradient(
      colors: [
        const Color(0xFFB3E5FC).withValues(alpha: 0.0),
        const Color(0xFF81D4FA).withValues(alpha: 0.42 * opacity),
        const Color(0xFF29B6F6).withValues(alpha: 0.82 * opacity),
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromPoints(p0, p1));
    canvas.drawLine(p0, p1, streakPaint);
  }
}

void _drawStrengthForgeCanvas(
  Canvas canvas,
  double radius,
  double elapsed,
  double opacity,
) {
  final pulse = 0.9 + 0.16 * sin(elapsed * 3.2);
  final spin = elapsed * (2 * pi / 6.8);

  canvas.drawCircle(
    Offset.zero,
    radius * 1.15 * pulse,
    Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFECB3).withValues(alpha: 0.20 * opacity),
              const Color(0xFFFF8A65).withValues(alpha: 0.18 * opacity),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: radius * 1.15 * pulse),
          ),
  );

  void drawHex(double rr, double stroke, double rot, Color col) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = rot + (i / 6.0) * 2 * pi - pi / 2;
      final p = Offset(cos(a) * rr, sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = col.withValues(alpha: 0.75 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.8),
    );
  }

  drawHex(
    radius * 0.92 * pulse,
    max(1.6, radius * 0.09),
    spin,
    const Color(0xFFFF7043),
  );
  drawHex(
    radius * 0.68 * pulse,
    max(1.2, radius * 0.06),
    -spin * 0.72,
    const Color(0xFFFFCC80),
  );

  for (int i = 0; i < 6; i++) {
    final a = spin + (i / 6.0) * 2 * pi;
    final p = Offset(cos(a) * radius * 0.9, sin(a) * radius * 0.9);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(a + pi / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 0.14,
          height: radius * 0.24,
        ),
        Radius.circular(radius * 0.04),
      ),
      Paint()
        ..color = const Color(0xFFFFAB91).withValues(alpha: 0.72 * opacity),
    );
    canvas.restore();
  }
}

void _drawIntelligenceHaloCanvas(
  Canvas canvas,
  double radius,
  double elapsed,
  double opacity,
) {
  final spin = elapsed * (2 * pi / 5.6);
  final pulse = 0.92 + 0.14 * sin(elapsed * 2.8);
  canvas.drawCircle(
    Offset.zero,
    radius * 1.2 * pulse,
    Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFEDE7F6).withValues(alpha: 0.14 * opacity),
              const Color(0xFFB39DDB).withValues(alpha: 0.14 * opacity),
              Colors.transparent,
            ],
            stops: const [0.0, 0.58, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: radius * 1.2 * pulse),
          ),
  );

  void drawSegmentRing(
    double rr,
    double rot,
    Color a,
    Color b,
    double thickness,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = thickness
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness * 0.45);
    for (int i = 0; i < 6; i++) {
      paint.color = (i.isEven ? a : b).withValues(alpha: opacity);
      final start = rot + (i / 6.0) * 2 * pi;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: rr),
        start,
        0.72,
        false,
        paint,
      );
    }
  }

  drawSegmentRing(
    radius * 0.9,
    spin,
    const Color(0xFFB39DDB).withValues(alpha: 0.68),
    const Color(0xFF80DEEA).withValues(alpha: 0.68),
    max(1.4, radius * 0.08),
  );
  drawSegmentRing(
    radius * 0.64,
    -spin * 0.72,
    const Color(0xFF90CAF9).withValues(alpha: 0.56),
    const Color(0xFFCE93D8).withValues(alpha: 0.52),
    max(1.0, radius * 0.05),
  );

  final nodes = <Offset>[];
  for (int i = 0; i < 6; i++) {
    final a = spin + (i / 6.0) * 2 * pi;
    nodes.add(Offset(cos(a) * radius * 0.82, sin(a) * radius * 0.82));
  }
  final link = Paint()
    ..color = const Color(0xFFB39DDB).withValues(alpha: 0.26 * opacity)
    ..strokeWidth = max(0.8, radius * 0.02)
    ..style = PaintingStyle.stroke;
  for (int i = 0; i < nodes.length; i++) {
    canvas.drawLine(nodes[i], nodes[(i + 2) % nodes.length], link);
  }
  for (final n in nodes) {
    canvas.drawCircle(
      n,
      max(1.6, radius * 0.04),
      Paint()
        ..color = const Color(0xFFC5CAE9).withValues(alpha: 0.82 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.04),
    );
  }
}

void _drawAlchemyEffectCanvas({
  required Canvas canvas,
  required String effect,
  required double spriteScale,
  required double baseSpriteSize,
  required String? variantFaction,
  required double elapsed,
  required double opacity,
}) {
  final effectRadius = _cosmicEffectRadius(
    spriteScale: spriteScale,
    baseSpriteSize: baseSpriteSize,
  );
  switch (effect) {
    case 'alchemy_glow':
      _drawAlchemyGlowCanvas(canvas, effectRadius, elapsed, opacity);
      break;
    case 'elemental_aura':
      _drawElementalAuraCanvas(
        canvas,
        effectRadius,
        FactionColors.of(variantFaction ?? 'Arcane'),
        elapsed,
        opacity,
      );
      break;
    case 'volcanic_aura':
      _drawVolcanicAuraCanvas(canvas, effectRadius, elapsed, opacity);
      break;
    case 'void_rift':
      _drawVoidRiftCanvas(canvas, effectRadius * 0.88, elapsed, opacity);
      break;
    case 'prismatic_cascade':
      _drawPrismaticCascadeCanvas(
        canvas,
        _cosmicPrismaticBaseRadius(
          spriteScale: spriteScale,
          baseSpriteSize: baseSpriteSize,
        ),
        1.0,
        elapsed,
        opacity,
      );
      break;
    case 'ritual_gold':
      _drawRitualGoldCanvas(canvas, effectRadius, elapsed, opacity);
      break;
    case 'beauty_radiance':
      _drawBeautyRadianceCanvas(canvas, effectRadius, elapsed, opacity);
      break;
    case 'speed_flux':
      _drawSpeedFluxCanvas(canvas, effectRadius, elapsed, opacity);
      break;
    case 'strength_forge':
      _drawStrengthForgeCanvas(canvas, effectRadius, elapsed, opacity);
      break;
    case 'intelligence_halo':
      _drawIntelligenceHaloCanvas(canvas, effectRadius, elapsed, opacity);
      break;
    default:
      break;
  }
}

// Lightweight ring-minion type (top-level)
class RingMinion {
  Offset position;
  String element;
  double health;
  double radius;
  double speed;
  String type = 'shooter'; // 'shooter' or 'charger'
  double shootCooldown = 0.0;
  // Orbital spawn (portal) fields
  Offset? orbitCenter;
  double orbitAngle = 0;
  double orbitRadius = 0;
  double orbitTime = 0;
  double life = 0;
  double attackCooldown = 0;
  bool dead = false;

  RingMinion({
    required this.position,
    required this.element,
    required this.health,
    required this.radius,
    required this.speed,
  });
}
