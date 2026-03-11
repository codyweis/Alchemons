// lib/games/cosmic/cosmic_game.dart
//
// Flame game for the Cosmic Alchemy Explorer.
// Player pilots a ship through a star field, discovers element planets,
// collects particles to fill a meter, and summons creatures.

import 'dart:math';
import 'dart:ui' as ui;

import 'cosmic_contests.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/effect_size.dart';
import 'package:flame/components.dart' show Anchor;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'cosmic_data.dart';
import 'package:alchemons/systems/effects/effect.dart';
import 'package:alchemons/systems/effects/effect_loader.dart';
import 'package:alchemons/systems/effects/effect_registry.dart';

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

// ─────────────────────────────────────────────────────────
// MAIN GAME
// ─────────────────────────────────────────────────────────

class CosmicGame extends FlameGame with PanDetector {
  CosmicGame({
    required this.world_,
    required this.onMeterChanged,
    this.onPeriodicSave,
    this.onNearPlanet,
    this.onStarDustCollected,
    this.onNearRift,
    this.onHomePlanetBuilt,
    this.onAsteroidDestroyed,
    this.onNearHome,
    this.onBossSpawned,
    this.onShipDied,
    this.onLootCollected,
    this.onBossDefeated,
    this.onWhirlActivated,
    this.onWhirlWaveComplete,
    this.onWhirlComplete,
    this.onPOIDiscovered,
    this.onNearMarket,
    this.onCompanionAutoReturned,
    this.onCompanionDied,
    this.onNearNexus,
    this.onNearBattleRing,
    this.onNearBloodRing,
    this.onNearContestArena,
    this.onContestHintCollected,
    Set<String>? initialCustomizations,
    Map<String, String>? initialOptions,
    String? initialAmmoId,
  }) : activeCustomizations = initialCustomizations ?? {},
       customizationOptions = initialOptions ?? {},
       activeAmmoId = initialAmmoId;

  final CosmicWorld world_;
  final VoidCallback onMeterChanged;
  final VoidCallback? onPeriodicSave;
  final void Function(CosmicPlanet? planet)? onNearPlanet;
  final void Function(int index)? onStarDustCollected;
  final void Function(bool isNear)? onNearRift;
  final void Function(HomePlanet planet)? onHomePlanetBuilt;
  final void Function()? onAsteroidDestroyed;
  final void Function(bool isNear)? onNearHome;
  final void Function(String bossName)? onBossSpawned;
  final VoidCallback? onShipDied;
  final void Function(LootDrop drop)? onLootCollected;
  final void Function(String bossName)? onBossDefeated;
  final void Function(GalaxyWhirl whirl)? onWhirlActivated;
  final void Function(GalaxyWhirl whirl, int wave)? onWhirlWaveComplete;
  final void Function(GalaxyWhirl whirl)? onWhirlComplete;
  final void Function(SpacePOI poi)? onPOIDiscovered;
  final void Function(SpacePOI? poi)? onNearMarket;
  final VoidCallback? onCompanionAutoReturned;
  final void Function(CosmicPartyMember member)? onCompanionDied;
  final void Function(CosmicContestArena? arena)? onNearContestArena;
  final void Function(CosmicContestHintNote note)? onContestHintCollected;

  // ── state ──────────────────────────────────────────────
  final ElementMeter meter = ElementMeter();
  CosmicPlanet? nearPlanet;
  SpacePOI? nearMarket;
  int? _starDustScannerTargetIndex;
  int? _scannerCompletedDustIndex;

  late ShipComponent ship;
  // Loaded effect prototypes from assets
  List<Effect> _loadedEffectPrototypes = [];
  final List<PlanetComponent> planetComps = [];
  final List<ElementParticle> elemParticles = [];

  // Orbital alchemy chambers (floating creature bubbles around home planet)
  final List<OrbitalChamber> orbitalChambers = [];

  // Cached creature images for orbital chamber sprites
  final Map<String, ui.Image> _chamberSpriteCache = {};

  // Stars stored in spatial grid for fast rendering
  static const double _starChunkSize = 800.0;
  late int _starGridW;
  late int _starGridH;
  late List<List<_StarParticle>> _starGrid;

  // Fog: each pixel in a conceptual grid is revealed when ship is nearby.
  // We use a Set of grid-cell keys for discovered cells.
  static const double fogCellSize = 120.0;
  final Set<int> revealedCells = {};

  // Star dust collectibles
  late List<StarDust> starDusts;
  int collectedDustCount = 0;

  // Rift portals (5 permanent, one per faction)
  double _riftPulse = 0;
  RiftPortal? _nearestRift; // closest rift within interact range
  bool _wasNearRift = false;

  // Elemental Nexus (black portal easter-egg)
  late ElementalNexus elementalNexus = world_.elementalNexus;
  bool _wasNearNexus = false;
  bool _isNearNexus = false;
  void Function(bool isNear)? onNearNexus;

  // Battle Ring (octagonal arena)
  late BattleRing battleRing = world_.battleRing;
  bool _wasNearBattleRing = false;
  bool _isNearBattleRing = false;
  bool get isNearBattleRing => _isNearBattleRing;
  void Function(bool isNear)? onNearBattleRing;

  // Blood Ring (ending ritual portal)
  late BloodRing bloodRing = world_.bloodRing;
  bool _wasNearBloodRing = false;
  bool _isNearBloodRing = false;
  bool get isNearBloodRing => _isNearBloodRing;
  void Function(bool isNear)? onNearBloodRing;

  // Trait contest arenas + hint notes (separate system from battle ring)
  late List<CosmicContestArena> contestArenas = world_.contestArenas;
  late List<CosmicContestHintNote> contestHintNotes = world_.contestHintNotes;
  CosmicContestArena? nearContestArena;

  // Battle Ring opponent (in-world 1v1)
  CosmicCompanion? battleRingOpponent;
  final List<Projectile> ringOpponentProjectiles = [];
  // Lightweight minions summoned to assist the ring opponent.
  // These are local to the ring fight and only target the player's companion.
  final List<RingMinion> ringMinions = [];
  // Pending minion spawn data: we spawn helpers only once the opponent
  // drops below half health. These fields store the planned spawn so we can
  // delay visual portal emergence until the threshold is reached.
  bool _ringMinionsSpawnedForCurrentOpponent = false;
  int _pendingRingMinionCount = 0;
  int _pendingRingMinionLevel = 0;
  String? _pendingRingMinionElement;

  // Lightweight ring-minion type
  // Local to this file: small helpers that assist the ring opponent.
  // They only target the player's companion and can be shot by the ship.
  // Keep this small to avoid pulling in extra dependencies.

  SpriteAnimationTicker? _ringOpponentTicker;
  SpriteVisuals? _ringOpponentVisuals;
  double _ringOpponentSpriteScale = 1.0;
  Sprite? _ringOpponentFallbackSprite;
  double _ringOpponentFallbackScale = 1.0;
  int _ringOpponentFallbackLoadToken = 0;
  int _ringOpponentSpriteLoadToken = 0;
  double _ringOpponentSpriteRetryTimer = 0.0;
  int _ringOpponentSpriteLoadsInFlight = 0;
  VoidCallback? onBattleRingWon;
  VoidCallback? onBattleRingLost;

  // Beauty contest in-arena cinematic (non-combat showcase)
  bool _beautyContestCinematicActive = false;
  Offset _beautyContestCenter = Offset.zero;
  double _beautyContestTimer = 0;
  bool _beautyContestCompAbilityA = false;
  bool _beautyContestOppAbilityA = false;
  bool _beautyContestCompAbilityB = false;
  bool _beautyContestOppAbilityB = false;
  double _beautyContestCompHopTimer = 0;
  double _beautyContestOppHopTimer = 0;
  static const double _beautyContestHopDuration = 0.82;
  static const double _beautyContestHopHeight = 24.0;
  static const double _beautyContestOrbitSpeed = 0.82;
  static const double _beautyContestCompAbilityATime = 3.0;
  static const double _beautyContestOppAbilityATime = 6.8;
  static const double _beautyContestCompAbilityBTime = 10.6;
  static const double _beautyContestOppAbilityBTime = 14.4;
  static const double _beautyContestIntroDuration = 0.95;
  static const double _beautyContestFinalPoseTime = 16.5;
  static const double _beautyContestFinalPoseBlendDuration = 0.9;
  bool _beautyContestPlayerWon = true;
  double _beautyContestCompVisualScale = 1.0;
  double _beautyContestOppVisualScale = 1.0;
  bool _beautyContestIntroActive = false;
  double _beautyContestIntroTimer = 0;
  Offset _beautyContestShipIntroStart = Offset.zero;
  Offset _beautyContestCompIntroStart = Offset.zero;
  Offset _beautyContestOppIntroStart = Offset.zero;
  _ContestCinematicMode _contestCinematicMode = _ContestCinematicMode.beauty;
  double _speedContestRaceDuration = 11.0;
  double _speedContestCompRate = 1.0;
  double _speedContestOppRate = 1.0;
  double _speedContestCompProgress = pi * 0.5;
  double _speedContestOppProgress = pi * 0.5 - 0.18;
  double _strengthContestDuration = 11.0;
  double _strengthContestCompForce = 1.0;
  double _strengthContestOppForce = 1.0;
  double _strengthContestShift = 0.0;
  double _intelligenceContestDuration = 11.0;
  double _intelligenceContestCompFocus = 1.0;
  double _intelligenceContestOppFocus = 1.0;
  double _intelligenceContestBias = 0.0;
  double _intelligenceContestOrbit = 0.0;
  Offset _intelligenceContestOrbPos = Offset.zero;
  bool get beautyContestCinematicActive => _beautyContestCinematicActive;
  double get beautyContestIntroDuration => _beautyContestIntroDuration;
  double get speedContestIntroDuration => _beautyContestIntroDuration;
  double get strengthContestIntroDuration => _beautyContestIntroDuration;
  double get intelligenceContestIntroDuration => _beautyContestIntroDuration;

  // Nexus pocket dimension
  bool inNexusPocket = false;
  String? nearPocketPortalElement; // element of closest pocket portal in range
  void Function(String? element)? onNearPocketPortal;

  // Warp anomaly flash animation
  double _warpFlash = 0; // counts down from 1.0

  // Home planet (player-built)
  HomePlanet? homePlanet;

  // Asteroid belt
  late AsteroidBelt asteroidBelt;

  // Ship weapons
  final List<Projectile> projectiles = [];
  double _shootCooldown = 0;
  static const double shootInterval = 0.25; // seconds between shots
  bool shooting = false; // controlled by UI
  bool shootingMissiles = false; // secondary missile fire (controlled by UI)
  double _missileShootCooldown = 0;
  bool _wasNearHome = false; // for change detection

  // Active home customizations (recipe IDs)
  Set<String> activeCustomizations;
  Map<String, String> customizationOptions; // 'recipeId.paramKey' -> value
  String? activeAmmoId;
  String? activeWeaponId; // 'equip_machinegun' or null (default)
  bool hasMissiles = false; // whether missile launcher is equipped
  String? activeShipSkin; // 'skin_phantom', 'skin_solar', or null (default)

  // Power-up levels (0-5), each level adds 16% damage (80% at max)
  int ammoUpgradeLevel = 0;
  int missileUpgradeLevel = 0;

  // ── Ship equipment ──
  // Fuel & booster
  final ShipFuel shipFuel = ShipFuel();
  bool boosting = false; // controlled by UI hold
  static const double boostSpeedMultiplier = 2.5;
  static const double slowSpeedMultiplier = 0.35;

  /// When true the ship moves at ~35% speed.
  bool slowMode = false;
  static const double boostFuelPerSecond =
      8.0; // fuel consumed/sec while boosting

  // Orbital sentinels
  final List<OrbitalSentinel> orbitals = [];
  int orbitalStockpile = 0; // built sentinels not yet deployed
  double _orbitalReplenishTimer = 0;

  // Missile tracking
  int missileAmmo = 0; // consumable ammo for homing missiles
  final List<_HomingMissile> _missiles = [];

  // Boost visual state (set in update, read in render)
  bool isBoosting = false;

  // Active companion (summoned party alchemon)
  CosmicCompanion? activeCompanion;
  final List<Projectile> companionProjectiles = [];
  SpriteAnimationTicker? _companionTicker;
  SpriteVisuals? _companionVisuals;
  double _companionSpriteScale = 1.0;
  final Random _rng = Random();

  // Home garrison (stationed alchemons inside home planet)
  final List<_GarrisonCreature> _garrison = [];

  // Enemies & bosses
  final List<CosmicEnemy> enemies = [];
  CosmicBoss? activeBoss;
  final List<BossProjectile> bossProjectiles = [];

  // Loot drops on the ground
  final List<LootDrop> lootDrops = [];
  final ShipWallet shipWallet = ShipWallet();
  double _enemySpawnTimer = 0;
  int _bossesDefeated = 0;
  int _nextPackId = 0; // unique pack ID counter
  static const int _maxEnemies = 160;
  static const double _enemySpawnInterval = 1.2; // seconds between checks
  static const double _meterPickupMultiplier = 3.0;

  // Swarm cluster spawn timer
  double _swarmSpawnTimer = 0;
  static const double _swarmSpawnInterval =
      20.0; // seconds between swarm spawns
  bool _initialSwarmsSpawned = false;

  // Random boss spawn timer
  double _bossSpawnTimer = 0;
  static const double _bossSpawnInterval = 22.5;

  // Boss lairs (always at least 1 on the map)
  late List<BossLair> bossLairs;

  // Galaxy whirls (horde encounters)
  late List<GalaxyWhirl> galaxyWhirls;
  GalaxyWhirl? activeWhirl;

  // Space POIs
  late List<SpacePOI> spacePOIs;

  // Prismatic Field (aurora easter-egg)
  late PrismaticField prismaticField = world_.prismaticField;
  bool prismaticRewardClaimed = false;
  double _prismaticCelebTimer = -1; // ≥ 0 while celebration running
  Offset? _prismaticCelebCenter; // orbit centre during celebration
  static const double _prismaticCelebDuration = 3.5; // seconds
  VoidCallback? onPrismaticRewardClaimed;

  // Prismatic field cached render-to-texture (~10fps refresh, full blur beauty)
  ui.Image? _prismaticCachedImage;
  double _prismaticCacheLife = -1; // life value when cache was built
  static const int _prismaticTexSize = 512; // render target size
  static const double _prismaticCacheInterval =
      0.1; // seconds between refreshes

  // Elemental nexus cached render-to-texture (same trick as prismatic aurora)
  ui.Image? _nexusCachedImage;
  double _nexusCacheTime = -1;
  static const int _nexusTexSize = 512;
  static const double _nexusCacheInterval = 0.1;
  // World-unit radius the texture covers (gravitational well glow = 600 + margin)
  static const double _nexusTexWorldR = 750.0;

  // Pocket dimension cached render-to-texture
  ui.Image? _pocketCachedImage;
  double _pocketCacheTime = -1;
  static const int _pocketTexSize = 512;
  static const double _pocketCacheInterval = 0.1;

  // Battle Ring cached render-to-texture
  ui.Image? _battleRingCachedImage;
  double _battleRingCacheTime = -1;
  static const int _battleRingTexSize = 512;
  static const double _battleRingCacheInterval = 0.1;
  static const double _battleRingTexWorldR = 550.0;

  // Feeding-pack spawn: separate timer, spawns near asteroid belt
  double _feedingPackTimer = 0;
  static const double _feedingPackInterval = 12.5;

  // Ship health
  double shipHealth = 5.0;
  static const double shipMaxHealth = 5.0;
  double _shipInvincible = 0; // invincibility timer after hit
  bool _shipDead = false;
  double _respawnTimer = 0;

  // Visual effects
  final List<VfxParticle> vfxParticles = [];
  final List<VfxShockRing> vfxRings = [];

  // Camera offset (ship is always centred; camera follows ship)
  double get camX => ship.pos.dx - size.x / 2;
  double get camY => ship.pos.dy - size.y / 2;

  // ── lifecycle ──────────────────────────────────────────

  @override
  Color backgroundColor() => const Color(0xFF020010);

  @override
  Future<void> onLoad() async {
    // Ship starts at the center of the world
    ship = ShipComponent(
      pos: Offset(world_.worldSize.width / 2, world_.worldSize.height / 2),
    );

    // Build planet components
    for (final planet in world_.planets) {
      planetComps.add(PlanetComponent(planet: planet));
    }

    // Seed background stars (procedural, dense) — stored in spatial grid
    final rng = Random(42);
    _starGridW = (world_.worldSize.width / _starChunkSize).ceil();
    _starGridH = (world_.worldSize.height / _starChunkSize).ceil();
    _starGrid = List.generate(
      _starGridW * _starGridH,
      (_) => <_StarParticle>[],
    );
    final starCount = (world_.worldSize.width * world_.worldSize.height / 20000)
        .round();
    for (var i = 0; i < starCount; i++) {
      final sx = rng.nextDouble() * world_.worldSize.width;
      final sy = rng.nextDouble() * world_.worldSize.height;
      final gx = (sx / _starChunkSize).floor().clamp(0, _starGridW - 1);
      final gy = (sy / _starChunkSize).floor().clamp(0, _starGridH - 1);
      _starGrid[gy * _starGridW + gx].add(
        _StarParticle(
          x: sx,
          y: sy,
          brightness: 0.2 + rng.nextDouble() * 0.8,
          size: 0.5 + rng.nextDouble() * 2.0,
          twinkleSpeed: 0.5 + rng.nextDouble() * 2.0,
        ),
      );
    }

    // Generate star dust collectibles
    starDusts = StarDust.generate(
      seed: world_.planets.first.element.hashCode ^ 0xC05,
      worldSize: world_.worldSize,
      planets: world_.planets,
    );

    // Generate asteroid belt
    asteroidBelt = AsteroidBelt.generate(
      seed: world_.planets.first.element.hashCode ^ 0xBEEF,
      worldSize: world_.worldSize,
    );

    // Generate galaxy whirls (horde encounters)
    galaxyWhirls = GalaxyWhirl.generate(
      seed: world_.planets.first.element.hashCode ^ 0xAA11,
      worldSize: world_.worldSize,
      planets: world_.planets,
    );

    // Generate space POIs
    spacePOIs = SpacePOI.generate(
      seed: world_.planets.first.element.hashCode ^ 0xBB22,
      worldSize: world_.worldSize,
      planets: world_.planets,
    );
    syncStarDustScannerAvailability();

    // Generate initial boss lairs (3-4 spread around the world)
    final lairRng = Random(world_.planets.first.element.hashCode ^ 0xCC33);
    final lairCount = 3 + lairRng.nextInt(2); // 3 or 4
    bossLairs = [];
    for (int i = 0; i < lairCount; i++) {
      bossLairs.add(
        BossLair.generate(
          rng: lairRng,
          worldSize: world_.worldSize,
          planets: world_.planets,
          whirls: galaxyWhirls,
          existing: bossLairs,
        ),
      );
    }

    // Reveal initial area around ship
    _revealAround(ship.pos, 300);

    // Load effect prototypes from JSON (non-blocking for gameplay setup)
    try {
      _loadedEffectPrototypes = await loadEffectsFromAsset(
        'assets/data/effects.json',
      );
    } catch (e) {
      // ignore - optional
    }
  }

  // ── input ──────────────────────────────────────────────

  Offset? _dragTarget;

  /// Normalised steering direction from the virtual joystick (null = idle).
  Offset? joystickDirection;

  /// When true, pan gestures are ignored (tap-to-shoot handles input instead).
  bool tapToShootMode = false;

  @override
  void onPanStart(DragStartInfo info) {
    if (tapToShootMode) return;
    _dragTarget = _wrap(
      Offset(
        info.eventPosition.global.x + camX,
        info.eventPosition.global.y + camY,
      ),
    );
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (tapToShootMode) return;
    _dragTarget = _wrap(
      Offset(
        info.eventPosition.global.x + camX,
        info.eventPosition.global.y + camY,
      ),
    );
  }

  @override
  void onPanEnd(DragEndInfo info) {
    // Keep drifting toward last target — don't null it
  }

  /// Set drag target from screen coordinates (used by tap-to-shoot mode).
  void setDragTargetFromScreen(Offset screenPos) {
    _dragTarget = _wrap(Offset(screenPos.dx + camX, screenPos.dy + camY));
  }

  /// Set a world travel target and steer using shortest toroidal path.
  void setTravelTarget(Offset worldPos) {
    _dragTarget = _wrap(worldPos);
    joystickDirection = null;
  }

  /// Teleport ship directly (for mini-map clicks).
  void teleportTo(Offset worldPos) {
    ship.pos = worldPos;
    _revealAround(ship.pos, 300);
  }

  // ── Companion (party alchemon) ──

  /// Species-type scale factors for companion sprites (from survival mode).
  static const Map<String, double> _companionSpeciesScale = {
    'let': 1.0,
    'pip': 1.0,
    'mane': 1.2,
    'horn': 1.7,
    'mask': 1.5,
    'wing': 2.0,
    'kin': 2.0,
    'mystic': 2.4,
  };

  /// Place a companion at the ship's current position.
  /// [hpFraction] 0.0–1.0 sets starting HP (default 1.0 = full).
  void summonCompanion(CosmicPartyMember member, {double hpFraction = 1.0}) {
    // Block swapping companions during a ring battle — callers may not
    // always check this (UI normally does), so enforce it here.
    if (battleRing.inBattle) return;

    // If there's already a companion deployed, recall it first so the
    // newly summoned companion replaces it (UI previously handled this,
    // but other callers may not). We don't wait for the return animation
    // — that mirrors the existing immediate-swap behavior.
    if (activeCompanion != null) {
      returnCompanion();
    }

    // Build stats from SurvivalUnit formulas, but scaled DOWN for cosmic
    // mode where enemies have no DEF (survival enemies reduce damage via
    // armour — here every point of physAtk is raw damage).
    final speed = member.statSpeed.toDouble();
    final intel = member.statIntelligence.toDouble();
    final strength = member.statStrength.toDouble();
    final beauty = member.statBeauty.toDouble();

    double curve(double x) => pow(x / 2.5, 2.4).toDouble();
    final intScale = curve(intel);
    final strScale = curve(strength);
    final beaScale = curve(beauty);
    final sStr = strScale * 80;
    final sBea = beaScale * 80;
    final sInt = intScale * 70;
    final level = member.level;

    // HP stays meaningful so the companion can survive
    final maxHp = (level * 18 + sStr * 2.0).round();

    // ── Damage scaled for cosmic (no enemy DEF) ──
    // Target: Lv10 / 3.0-stat companion ≈ 4 physAtk, 5 elemAtk
    final physAtk = max(1, ((sStr * 0.015 + 1.0) * (level / 5)).round());
    final elemAtk = max(1, ((sBea * 0.06) * (level / 5)).round());

    final physDef = ((sStr + sInt) * 0.20 + level * 0.8).round();
    final elemDef = ((sBea + sInt) * 0.20 + level * 0.8).round();
    final cooldownReduction = 0.5 + (speed * 0.12);
    final critChance = (sStr / 25.0).clamp(0.0, 0.40);
    final baseRange = 150.0 + intel * 70.0;

    // Species-based scale
    final family = member.family.toLowerCase();
    final specScale = (_companionSpeciesScale[family] ?? 1.0) * 1.0;

    // Place at the ship's current position
    final placePos = Offset(ship.pos.dx, ship.pos.dy);

    final startHp = (maxHp * hpFraction.clamp(0.0, 1.0)).round().clamp(
      1,
      maxHp,
    );

    activeCompanion = CosmicCompanion(
      member: member,
      position: placePos,
      anchor: placePos,
      maxHp: maxHp,
      currentHp: startHp,
      physAtk: physAtk,
      elemAtk: elemAtk,
      physDef: physDef,
      elemDef: elemDef,
      cooldownReduction: cooldownReduction,
      critChance: critChance,
      attackRange: baseRange,
      specialAbilityRange: baseRange * 1.5,
      speciesScale: specScale,
    );

    // Attach a demo effect instance based on loaded prototypes (one per companion).
    try {
      if (_loadedEffectPrototypes.isNotEmpty) {
        final proto =
            _loadedEffectPrototypes[member.level %
                _loadedEffectPrototypes.length];
        final inst = EffectRegistry.create(proto.toJson());
        activeCompanion?.addEffect(inst);
      }
    } catch (_) {}

    // Load animated sprite for the companion
    _loadCompanionSprite(member);
  }

  Future<void> _loadCompanionSprite(CosmicPartyMember member) async {
    final sheet = member.spriteSheet;
    if (sheet == null) {
      _companionTicker = null;
      _companionVisuals = null;
      return;
    }

    try {
      final image = await images.load(sheet.path);
      final cols = (sheet.totalFrames + sheet.rows - 1) ~/ sheet.rows;
      final anim = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: sheet.totalFrames,
          amountPerRow: cols,
          textureSize: sheet.frameSize,
          stepTime: sheet.stepTime,
          loop: true,
        ),
      );
      _companionTicker = anim.createTicker();
      _companionVisuals = member.spriteVisuals;
      debugPrint(
        'Companion visuals loaded: alchemy=${_companionVisuals?.alchemyEffect} variant=${_companionVisuals?.variantFaction} tint=${_companionVisuals?.tint}',
      );
      // Fit sprite into ~48px box, then apply species + 30% scale
      final desiredSize = 48.0;
      final sx = desiredSize / sheet.frameSize.x;
      final sy = desiredSize / sheet.frameSize.y;
      final specScale = activeCompanion?.speciesScale ?? 1.3;
      _companionSpriteScale =
          min(sx, sy) * (_companionVisuals?.scale ?? 1.0) * specScale;
    } catch (e) {
      debugPrint('Failed to load companion sprite: ${sheet.path} - $e');
      _companionTicker = null;
      _companionVisuals = null;
    }
  }

  void returnCompanion() {
    if (activeCompanion != null) {
      activeCompanion!.returning = true;
      activeCompanion!.returnTimer = 0.6; // fade out over 0.6s
    }
  }

  /// Spawn a battle ring opponent at the ring center.
  void spawnBattleRingOpponent(CosmicPartyMember member) {
    final speed = member.statSpeed.toDouble();
    final intel = member.statIntelligence.toDouble();
    final strength = member.statStrength.toDouble();
    final beauty = member.statBeauty.toDouble();

    double curve(double x) => pow(x / 2.5, 2.4).toDouble();
    final intScale = curve(intel);
    final strScale = curve(strength);
    final beaScale = curve(beauty);
    final sStr = strScale * 80;
    final sBea = beaScale * 80;
    final sInt = intScale * 70;
    final level = member.level;

    final maxHp = (level * 18 + sStr * 2.0).round();
    final physAtk = max(1, ((sStr * 0.015 + 1.0) * (level / 5)).round());
    final elemAtk = max(1, ((sBea * 0.06) * (level / 5)).round());
    final physDef = ((sStr + sInt) * 0.20 + level * 0.8).round();
    final elemDef = ((sBea + sInt) * 0.20 + level * 0.8).round();
    final cooldownReduction = 0.5 + (speed * 0.12);
    final critChance = (sStr / 25.0).clamp(0.0, 0.40);
    final baseRange = 150.0 + intel * 70.0;

    final family = member.family.toLowerCase();
    final specScale = (_companionSpeciesScale[family] ?? 1.0) * 1.0;

    // Use spawnPosition if provided, else default to ring center
    final placePos = member.spawnPosition ?? battleRing.position;

    battleRingOpponent = CosmicCompanion(
      member: member,
      position: placePos,
      anchor: placePos,
      maxHp: maxHp,
      currentHp: maxHp,
      physAtk: physAtk,
      elemAtk: elemAtk,
      physDef: physDef,
      elemDef: elemDef,
      cooldownReduction: cooldownReduction,
      critChance: critChance,
      attackRange: baseRange,
      specialAbilityRange: baseRange * 1.5,
      speciesScale: specScale,
      invincibleTimer: 1.5,
      visualVariant: member.visualVariant,
    );
    ringOpponentProjectiles.clear();

    // Spawn a few small assisting wisps/minions depending on opponent level.
    // Use a gentle scale so higher levels spawn a few more helpers.
    // Schedule ring minions to spawn later when the opponent reaches
    // half health. We compute the planned count/level/element now and
    // create them on the health-threshold trigger so they appear like
    // portals mid-fight.
    _ringMinionsSpawnedForCurrentOpponent = false;
    _pendingRingMinionCount = ((level) / 2).floor().clamp(0, 6);
    _pendingRingMinionLevel = level;
    _pendingRingMinionElement = member.element;
    debugPrint(
      'Scheduled $_pendingRingMinionCount ring minions for level $level',
    );

    // Reset and preload static sprite fallback.
    _ringOpponentFallbackSprite = null;
    _ringOpponentFallbackScale = 1.0;
    _loadRingOpponentFallbackSprite(member);

    // Load sprite
    _loadRingOpponentSprite(member);
  }

  String _toBundleImageKey(String raw) {
    if (raw.startsWith('assets/')) return raw;
    if (raw.startsWith('images/')) return 'assets/$raw';
    return 'assets/images/$raw';
  }

  String _toFlameImageKey(String raw) {
    if (raw.startsWith('assets/images/')) {
      return raw.substring('assets/images/'.length);
    }
    if (raw.startsWith('assets/')) {
      return raw.substring('assets/'.length);
    }
    return raw;
  }

  Future<ui.Image> _loadUiImageFromBundle(String bundleKey) async {
    final data = await rootBundle.load(bundleKey);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _loadRingOpponentFallbackSprite(CosmicPartyMember member) async {
    final rawPath = member.imagePath;
    if (rawPath == null || rawPath.trim().isEmpty) return;
    final expectedInstanceId = member.instanceId;
    final token = ++_ringOpponentFallbackLoadToken;
    try {
      ui.Image image;
      try {
        image = await images.load(_toFlameImageKey(rawPath));
      } catch (_) {
        image = await _loadUiImageFromBundle(_toBundleImageKey(rawPath));
      }
      if (token != _ringOpponentFallbackLoadToken ||
          battleRingOpponent?.member.instanceId != expectedInstanceId) {
        return;
      }
      _ringOpponentFallbackSprite = Sprite(image);
      final desiredSize = 48.0;
      final sx = desiredSize / image.width;
      final sy = desiredSize / image.height;
      final specScale = battleRingOpponent?.speciesScale ?? 1.3;
      _ringOpponentFallbackScale =
          min(sx, sy) * (member.spriteVisuals?.scale ?? 1.0) * specScale;
    } catch (e) {
      debugPrint('Failed to load ring opponent fallback sprite: $rawPath - $e');
    }
  }

  Future<void> _loadRingOpponentSprite(CosmicPartyMember member) async {
    final loadToken = ++_ringOpponentSpriteLoadToken;
    final expectedInstanceId = member.instanceId;
    final sheet = member.spriteSheet;
    final sheetPath = sheet?.path ?? '<no-sheet>';
    _ringOpponentSpriteLoadsInFlight++;
    try {
      if (sheet == null) {
        if (loadToken == _ringOpponentSpriteLoadToken &&
            battleRingOpponent?.member.instanceId == expectedInstanceId) {
          _ringOpponentTicker = null;
          _ringOpponentVisuals = null;
        }
        return;
      }
      ui.Image image;
      try {
        image = await images.load(_toFlameImageKey(sheet.path));
      } catch (_) {
        image = await _loadUiImageFromBundle(_toBundleImageKey(sheet.path));
      }
      if (loadToken != _ringOpponentSpriteLoadToken ||
          battleRingOpponent?.member.instanceId != expectedInstanceId) {
        return;
      }
      final cols = (sheet.totalFrames + sheet.rows - 1) ~/ sheet.rows;
      final anim = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: sheet.totalFrames,
          amountPerRow: cols,
          textureSize: sheet.frameSize,
          stepTime: sheet.stepTime,
          loop: true,
        ),
      );
      _ringOpponentTicker = anim.createTicker();
      _ringOpponentVisuals = member.spriteVisuals;
      debugPrint(
        'Ring opponent visuals loaded: alchemy=${_ringOpponentVisuals?.alchemyEffect} variant=${_ringOpponentVisuals?.variantFaction} tint=${_ringOpponentVisuals?.tint}',
      );
      final desiredSize = 48.0;
      final sx = desiredSize / sheet.frameSize.x;
      final sy = desiredSize / sheet.frameSize.y;
      final specScale = battleRingOpponent?.speciesScale ?? 1.3;
      _ringOpponentSpriteScale =
          min(sx, sy) * (_ringOpponentVisuals?.scale ?? 1.0) * specScale;
      _ringOpponentSpriteRetryTimer = 0.0;
    } catch (e) {
      debugPrint('Failed to load ring opponent sprite: $sheetPath - $e');
      if (loadToken == _ringOpponentSpriteLoadToken &&
          battleRingOpponent?.member.instanceId == expectedInstanceId) {
        _ringOpponentTicker = null;
        _ringOpponentVisuals = null;
      }
    } finally {
      _ringOpponentSpriteLoadsInFlight = max(
        0,
        _ringOpponentSpriteLoadsInFlight - 1,
      );
    }
  }

  // Spawn the pending ring minions (called when opponent hits half health).
  void _spawnPendingRingMinions() {
    if (_pendingRingMinionCount <= 0 || battleRingOpponent == null) return;
    ringMinions.clear();
    final level = _pendingRingMinionLevel;
    final element =
        _pendingRingMinionElement ?? battleRingOpponent!.member.element;
    final placePos = battleRingOpponent!.anchorPosition;
    // Decide how many chargers vs shooters. Chargers are the slow, tanky
    // slam units that spawn opposite the player's companion and do high
    // contact damage. Shooters spawn around the arena and fire at the
    // companion. We aim for 3-5 chargers (depending on level) but never
    // exceed the total pending count.
    final desiredChargers = (3 + (level ~/ 5)).clamp(3, 5);
    final chargersToSpawn = min(_pendingRingMinionCount, desiredChargers);
    final shootersToSpawn = max(0, _pendingRingMinionCount - chargersToSpawn);

    // Spawn shooters around the ring center
    for (var si = 0; si < shootersToSpawn; si++) {
      final ang = _rng.nextDouble() * 2 * pi;
      final startRadius = 30.0 + _rng.nextDouble() * 20.0;
      final pos = Offset(
        placePos.dx + cos(ang) * startRadius,
        placePos.dy + sin(ang) * startRadius,
      );
      final m = RingMinion(
        position: pos,
        element: element,
        health: 10.0 + level * 1.8,
        radius: 10.0,
        speed: 70.0 + level * 4.0,
      );
      m.type = 'shooter';
      m.shootCooldown = 0.5 + _rng.nextDouble() * 1.0;
      m.orbitCenter = battleRing.position;
      m.orbitAngle = ang;
      m.orbitRadius = startRadius;
      m.orbitTime = 0.6 + _rng.nextDouble() * 0.9;
      ringMinions.add(m);
    }

    // Spawn chargers opposite the player's companion (if present), else
    // place them around the ring edge.
    final comp = activeCompanion;
    for (var ci = 0; ci < chargersToSpawn; ci++) {
      double ang;
      double spawnR = BattleRing.visualRadius - 20.0 + _rng.nextDouble() * 24.0;
      if (comp != null && comp.isAlive) {
        // Angle from ring center -> companion, then flip to opposite side
        final baseAng = atan2(
          comp.position.dy - battleRing.position.dy,
          comp.position.dx - battleRing.position.dx,
        );
        ang = baseAng + pi + ((_rng.nextDouble() - 0.5) * 0.6);
      } else {
        ang = _rng.nextDouble() * 2 * pi;
      }
      final pos = Offset(
        battleRing.position.dx + cos(ang) * spawnR,
        battleRing.position.dy + sin(ang) * spawnR,
      );
      final m = RingMinion(
        position: pos,
        element: element,
        // Slightly less tanky than before to avoid overwhelming damage
        health: 20.0 + level * 6.0,
        radius: 14.0,
        speed: 34.0 + level * 1.5,
      );
      m.type = 'charger';
      m.orbitCenter = battleRing.position;
      m.orbitAngle = ang;
      m.orbitRadius = spawnR;
      m.orbitTime = 0.6 + _rng.nextDouble() * 0.9;
      ringMinions.add(m);
    }
    _ringMinionsSpawnedForCurrentOpponent = true;
    debugPrint('Spawned ${ringMinions.length} ring minions at $placePos');
  }

  void dismissBattleRingOpponent() {
    battleRingOpponent = null;
    ringOpponentProjectiles.clear();
    ringMinions.clear();
    _ringOpponentTicker = null;
    _ringOpponentVisuals = null;
    _ringOpponentFallbackSprite = null;
    _ringOpponentFallbackScale = 1.0;
    _ringOpponentFallbackLoadToken++;
    _ringOpponentSpriteLoadToken++;
    _ringOpponentSpriteRetryTimer = 0.0;
    _ringOpponentSpriteLoadsInFlight = 0;
    // Reset pending minion spawn state
    _ringMinionsSpawnedForCurrentOpponent = false;
    _pendingRingMinionCount = 0;
    _pendingRingMinionLevel = 0;
    _pendingRingMinionElement = null;
  }

  void beginBeautyContestCinematic({
    required CosmicPartyMember opponentMember,
    required Offset arenaCenter,
    required bool playerWon,
  }) {
    if (activeCompanion == null) return;
    _beautyContestCinematicActive = true;
    _beautyContestCenter = arenaCenter;
    _beautyContestPlayerWon = playerWon;
    _beautyContestTimer = 0;
    _beautyContestCompAbilityA = false;
    _beautyContestOppAbilityA = false;
    _beautyContestCompAbilityB = false;
    _beautyContestOppAbilityB = false;
    _beautyContestCompHopTimer = 0;
    _beautyContestOppHopTimer = 0;
    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;
    _beautyContestIntroActive = true;
    _beautyContestIntroTimer = 0;
    _contestCinematicMode = _ContestCinematicMode.beauty;
    _beautyContestShipIntroStart = ship.pos;

    shooting = false;
    shootingMissiles = false;
    boosting = false;

    companionProjectiles.clear();
    ringOpponentProjectiles.clear();
    ringMinions.clear();
    vfxParticles.clear();
    vfxRings.clear();

    // Spawn real opponent sprite/visuals in arena.
    spawnBattleRingOpponent(opponentMember);
    _ringOpponentSpriteRetryTimer = 1.1;
    battleRing.inBattle = false;

    const orbitR = 170.0;
    const introOppOffset = Offset(220, -80);
    final compIntroTarget = Offset(
      _beautyContestCenter.dx + cos(pi) * orbitR,
      _beautyContestCenter.dy + sin(pi) * orbitR * 0.48,
    );
    final oppIntroTarget = Offset(
      _beautyContestCenter.dx + cos(0) * orbitR,
      _beautyContestCenter.dy + sin(0) * orbitR * 0.48,
    );

    final comp = activeCompanion!;
    _beautyContestCompIntroStart = comp.position;
    if ((_beautyContestCompIntroStart - _beautyContestCenter).distance > 900) {
      _beautyContestCompIntroStart = _toroidalLerp(
        compIntroTarget,
        _beautyContestCenter,
        0.32,
      );
      comp.position = _beautyContestCompIntroStart;
      comp.anchorPosition = comp.position;
    }
    comp.life = max(comp.life, 1.0);
    comp.returning = false;
    comp.returnTimer = 0;

    if (battleRingOpponent != null) {
      _beautyContestOppIntroStart = _wrap(
        Offset(
          oppIntroTarget.dx + introOppOffset.dx,
          oppIntroTarget.dy + introOppOffset.dy,
        ),
      );
      battleRingOpponent!.position = _beautyContestOppIntroStart;
      battleRingOpponent!.anchorPosition = battleRingOpponent!.position;
      // Beauty contest should show full sprites immediately (no summon scale-in).
      battleRingOpponent!.life = 1.0;
      battleRingOpponent!.returning = false;
      battleRingOpponent!.returnTimer = 0;
    }
  }

  void beginSpeedContestCinematic({
    required CosmicPartyMember opponentMember,
    required Offset arenaCenter,
    required bool playerWon,
    required double playerScore,
    required double opponentScore,
  }) {
    if (activeCompanion == null) return;
    _beautyContestCinematicActive = true;
    _beautyContestCenter = arenaCenter;
    _beautyContestPlayerWon = playerWon;
    _beautyContestTimer = 0;
    _beautyContestCompAbilityA = false;
    _beautyContestOppAbilityA = false;
    _beautyContestCompAbilityB = false;
    _beautyContestOppAbilityB = false;
    _beautyContestCompHopTimer = 0;
    _beautyContestOppHopTimer = 0;
    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;
    _beautyContestIntroActive = true;
    _beautyContestIntroTimer = 0;
    _contestCinematicMode = _ContestCinematicMode.speed;
    _beautyContestShipIntroStart = ship.pos;

    final scoreGap = (playerScore - opponentScore).abs().clamp(0.0, 1.5);
    final lead = 0.06 + scoreGap * 0.05;
    if (playerWon) {
      _speedContestCompRate = 1.0 + lead;
      _speedContestOppRate = 1.0 - lead * 0.65;
    } else {
      _speedContestCompRate = 1.0 - lead * 0.65;
      _speedContestOppRate = 1.0 + lead;
    }
    _speedContestRaceDuration = 11.0;
    _speedContestCompProgress = pi * 0.5;
    _speedContestOppProgress = pi * 0.5 - 0.18;

    shooting = false;
    shootingMissiles = false;
    boosting = false;

    companionProjectiles.clear();
    ringOpponentProjectiles.clear();
    ringMinions.clear();
    vfxParticles.clear();
    vfxRings.clear();

    spawnBattleRingOpponent(opponentMember);
    _ringOpponentSpriteRetryTimer = 1.1;
    battleRing.inBattle = false;

    const outerRx = 222.0;
    const outerRy = 124.0;
    const introOppOffset = Offset(240, -60);
    final compIntroTarget = Offset(
      _beautyContestCenter.dx + cos(pi * 0.5) * outerRx,
      _beautyContestCenter.dy + sin(pi * 0.5) * outerRy,
    );
    final oppIntroTarget = Offset(
      _beautyContestCenter.dx + cos(pi * 0.5 - 0.18) * (outerRx - 32),
      _beautyContestCenter.dy + sin(pi * 0.5 - 0.18) * (outerRy - 22),
    );

    final comp = activeCompanion!;
    _beautyContestCompIntroStart = comp.position;
    if ((_beautyContestCompIntroStart - _beautyContestCenter).distance > 900) {
      _beautyContestCompIntroStart = _toroidalLerp(
        compIntroTarget,
        _beautyContestCenter,
        0.30,
      );
      comp.position = _beautyContestCompIntroStart;
      comp.anchorPosition = comp.position;
    }
    comp.life = max(comp.life, 1.0);
    comp.returning = false;
    comp.returnTimer = 0;

    if (battleRingOpponent != null) {
      _beautyContestOppIntroStart = _wrap(
        Offset(
          oppIntroTarget.dx + introOppOffset.dx,
          oppIntroTarget.dy + introOppOffset.dy,
        ),
      );
      battleRingOpponent!.position = _beautyContestOppIntroStart;
      battleRingOpponent!.anchorPosition = battleRingOpponent!.position;
      battleRingOpponent!.life = 1.0;
      battleRingOpponent!.returning = false;
      battleRingOpponent!.returnTimer = 0;
    }
  }

  void beginStrengthContestCinematic({
    required CosmicPartyMember opponentMember,
    required Offset arenaCenter,
    required bool playerWon,
    required double playerScore,
    required double opponentScore,
  }) {
    if (activeCompanion == null) return;
    _beautyContestCinematicActive = true;
    _beautyContestCenter = arenaCenter;
    _beautyContestPlayerWon = playerWon;
    _beautyContestTimer = 0;
    _beautyContestCompAbilityA = false;
    _beautyContestOppAbilityA = false;
    _beautyContestCompAbilityB = false;
    _beautyContestOppAbilityB = false;
    _beautyContestCompHopTimer = 0;
    _beautyContestOppHopTimer = 0;
    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;
    _beautyContestIntroActive = true;
    _beautyContestIntroTimer = 0;
    _contestCinematicMode = _ContestCinematicMode.strength;
    _beautyContestShipIntroStart = ship.pos;

    final gap = (playerScore - opponentScore).abs().clamp(0.0, 1.8);
    final lead = 0.07 + gap * 0.06;
    if (playerWon) {
      _strengthContestCompForce = 1.0 + lead;
      _strengthContestOppForce = 1.0 - lead * 0.58;
    } else {
      _strengthContestCompForce = 1.0 - lead * 0.58;
      _strengthContestOppForce = 1.0 + lead;
    }
    _strengthContestDuration = 11.0;
    _strengthContestShift = 0.0;

    shooting = false;
    shootingMissiles = false;
    boosting = false;

    companionProjectiles.clear();
    ringOpponentProjectiles.clear();
    ringMinions.clear();
    vfxParticles.clear();
    vfxRings.clear();

    spawnBattleRingOpponent(opponentMember);
    _ringOpponentSpriteRetryTimer = 1.1;
    battleRing.inBattle = false;

    const introOppOffset = Offset(210, -42);
    final compIntroTarget = Offset(
      _beautyContestCenter.dx - 128,
      _beautyContestCenter.dy + 20,
    );
    final oppIntroTarget = Offset(
      _beautyContestCenter.dx + 128,
      _beautyContestCenter.dy + 20,
    );

    final comp = activeCompanion!;
    _beautyContestCompIntroStart = comp.position;
    if ((_beautyContestCompIntroStart - _beautyContestCenter).distance > 900) {
      _beautyContestCompIntroStart = _toroidalLerp(
        compIntroTarget,
        _beautyContestCenter,
        0.28,
      );
      comp.position = _beautyContestCompIntroStart;
      comp.anchorPosition = comp.position;
    }
    comp.life = max(comp.life, 1.0);
    comp.returning = false;
    comp.returnTimer = 0;

    if (battleRingOpponent != null) {
      _beautyContestOppIntroStart = _wrap(
        Offset(
          oppIntroTarget.dx + introOppOffset.dx,
          oppIntroTarget.dy + introOppOffset.dy,
        ),
      );
      battleRingOpponent!.position = _beautyContestOppIntroStart;
      battleRingOpponent!.anchorPosition = battleRingOpponent!.position;
      battleRingOpponent!.life = 1.0;
      battleRingOpponent!.returning = false;
      battleRingOpponent!.returnTimer = 0;
    }
  }

  void beginIntelligenceContestCinematic({
    required CosmicPartyMember opponentMember,
    required Offset arenaCenter,
    required bool playerWon,
    required double playerScore,
    required double opponentScore,
  }) {
    if (activeCompanion == null) return;
    _beautyContestCinematicActive = true;
    _beautyContestCenter = arenaCenter;
    _beautyContestPlayerWon = playerWon;
    _beautyContestTimer = 0;
    _beautyContestCompAbilityA = false;
    _beautyContestOppAbilityA = false;
    _beautyContestCompAbilityB = false;
    _beautyContestOppAbilityB = false;
    _beautyContestCompHopTimer = 0;
    _beautyContestOppHopTimer = 0;
    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;
    _beautyContestIntroActive = true;
    _beautyContestIntroTimer = 0;
    _contestCinematicMode = _ContestCinematicMode.intelligence;
    _beautyContestShipIntroStart = ship.pos;

    final gap = (playerScore - opponentScore).abs().clamp(0.0, 1.8);
    final lead = 0.08 + gap * 0.05;
    if (playerWon) {
      _intelligenceContestCompFocus = 1.0 + lead;
      _intelligenceContestOppFocus = 1.0 - lead * 0.60;
    } else {
      _intelligenceContestCompFocus = 1.0 - lead * 0.60;
      _intelligenceContestOppFocus = 1.0 + lead;
    }
    _intelligenceContestDuration = 11.0;
    _intelligenceContestBias = 0.0;
    _intelligenceContestOrbit = 0.0;
    _intelligenceContestOrbPos = _beautyContestCenter;

    shooting = false;
    shootingMissiles = false;
    boosting = false;

    companionProjectiles.clear();
    ringOpponentProjectiles.clear();
    ringMinions.clear();
    vfxParticles.clear();
    vfxRings.clear();

    spawnBattleRingOpponent(opponentMember);
    _ringOpponentSpriteRetryTimer = 1.1;
    battleRing.inBattle = false;

    const introOppOffset = Offset(230, -56);
    final compIntroTarget = Offset(
      _beautyContestCenter.dx - 144,
      _beautyContestCenter.dy + 12,
    );
    final oppIntroTarget = Offset(
      _beautyContestCenter.dx + 144,
      _beautyContestCenter.dy + 12,
    );

    final comp = activeCompanion!;
    _beautyContestCompIntroStart = comp.position;
    if ((_beautyContestCompIntroStart - _beautyContestCenter).distance > 900) {
      _beautyContestCompIntroStart = _toroidalLerp(
        compIntroTarget,
        _beautyContestCenter,
        0.28,
      );
      comp.position = _beautyContestCompIntroStart;
      comp.anchorPosition = comp.position;
    }
    comp.life = max(comp.life, 1.0);
    comp.returning = false;
    comp.returnTimer = 0;

    if (battleRingOpponent != null) {
      _beautyContestOppIntroStart = _wrap(
        Offset(
          oppIntroTarget.dx + introOppOffset.dx,
          oppIntroTarget.dy + introOppOffset.dy,
        ),
      );
      battleRingOpponent!.position = _beautyContestOppIntroStart;
      battleRingOpponent!.anchorPosition = battleRingOpponent!.position;
      battleRingOpponent!.life = 1.0;
      battleRingOpponent!.returning = false;
      battleRingOpponent!.returnTimer = 0;
    }
  }

  void endBeautyContestCinematic() {
    if (!_beautyContestCinematicActive) return;
    _beautyContestCinematicActive = false;
    _beautyContestTimer = 0;
    _beautyContestCompAbilityA = false;
    _beautyContestOppAbilityA = false;
    _beautyContestCompAbilityB = false;
    _beautyContestOppAbilityB = false;
    _beautyContestCompHopTimer = 0;
    _beautyContestOppHopTimer = 0;
    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;
    _beautyContestIntroActive = false;
    _beautyContestIntroTimer = 0;
    _contestCinematicMode = _ContestCinematicMode.beauty;
    _speedContestRaceDuration = 11.0;
    _speedContestCompRate = 1.0;
    _speedContestOppRate = 1.0;
    _speedContestCompProgress = pi * 0.5;
    _speedContestOppProgress = pi * 0.5 - 0.18;
    _strengthContestDuration = 11.0;
    _strengthContestCompForce = 1.0;
    _strengthContestOppForce = 1.0;
    _strengthContestShift = 0.0;
    _intelligenceContestDuration = 11.0;
    _intelligenceContestCompFocus = 1.0;
    _intelligenceContestOppFocus = 1.0;
    _intelligenceContestBias = 0.0;
    _intelligenceContestOrbit = 0.0;
    _intelligenceContestOrbPos = Offset.zero;
    companionProjectiles.clear();
    ringOpponentProjectiles.clear();
    dismissBattleRingOpponent();
  }

  void _updateBeautyContestCinematic(double dt) {
    final comp = activeCompanion;
    final opp = battleRingOpponent;
    if (comp == null || opp == null || !opp.isAlive) {
      endBeautyContestCinematic();
      return;
    }

    _beautyContestTimer += dt;
    _riftPulse += dt;
    _beautyContestCompHopTimer = max(0.0, _beautyContestCompHopTimer - dt);
    _beautyContestOppHopTimer = max(0.0, _beautyContestOppHopTimer - dt);
    _ringOpponentSpriteRetryTimer = max(
      0.0,
      _ringOpponentSpriteRetryTimer - dt,
    );
    _companionTicker?.update(dt);
    _ringOpponentTicker?.update(dt);

    // Retry opponent sprite load in-case an async load raced or failed.
    if (_ringOpponentTicker == null &&
        opp.member.spriteSheet != null &&
        _ringOpponentSpriteLoadsInFlight == 0 &&
        _ringOpponentSpriteRetryTimer <= 0) {
      _ringOpponentSpriteRetryTimer = 1.1;
      _loadRingOpponentSprite(opp.member);
    }

    if (_beautyContestIntroActive) {
      _beautyContestIntroTimer += dt;
      final introT = Curves.easeInOutCubic.transform(
        (_beautyContestIntroTimer / _beautyContestIntroDuration).clamp(
          0.0,
          1.0,
        ),
      );
      final compTarget = switch (_contestCinematicMode) {
        _ContestCinematicMode.speed => Offset(
          _beautyContestCenter.dx + cos(pi * 0.5) * 222.0,
          _beautyContestCenter.dy + sin(pi * 0.5) * 124.0,
        ),
        _ContestCinematicMode.strength => Offset(
          _beautyContestCenter.dx - 128,
          _beautyContestCenter.dy + 20,
        ),
        _ContestCinematicMode.intelligence => Offset(
          _beautyContestCenter.dx - 144,
          _beautyContestCenter.dy + 12,
        ),
        _ContestCinematicMode.beauty => Offset(
          _beautyContestCenter.dx + cos(pi) * 170.0,
          _beautyContestCenter.dy + sin(pi) * 170.0 * 0.48,
        ),
      };
      final oppTarget = switch (_contestCinematicMode) {
        _ContestCinematicMode.speed => Offset(
          _beautyContestCenter.dx + cos(pi * 0.5 - 0.18) * (222.0 - 32),
          _beautyContestCenter.dy + sin(pi * 0.5 - 0.18) * (124.0 - 22),
        ),
        _ContestCinematicMode.strength => Offset(
          _beautyContestCenter.dx + 128,
          _beautyContestCenter.dy + 20,
        ),
        _ContestCinematicMode.intelligence => Offset(
          _beautyContestCenter.dx + 144,
          _beautyContestCenter.dy + 12,
        ),
        _ContestCinematicMode.beauty => Offset(
          _beautyContestCenter.dx + cos(0) * 170.0,
          _beautyContestCenter.dy + sin(0) * 170.0 * 0.48,
        ),
      };
      ship.pos = _toroidalLerp(
        _beautyContestShipIntroStart,
        _beautyContestCenter,
        introT,
      );
      _revealAround(ship.pos, 220);

      comp.position = _toroidalLerp(
        _beautyContestCompIntroStart,
        compTarget,
        introT,
      );
      opp.position = _toroidalLerp(
        _beautyContestOppIntroStart,
        oppTarget,
        introT,
      );
      comp.anchorPosition = comp.position;
      opp.anchorPosition = opp.position;
      comp.angle = atan2(
        _beautyContestCenter.dy - comp.position.dy,
        _beautyContestCenter.dx - comp.position.dx,
      );
      opp.angle = atan2(
        _beautyContestCenter.dy - opp.position.dy,
        _beautyContestCenter.dx - opp.position.dx,
      );

      if (_beautyContestIntroTimer >= _beautyContestIntroDuration) {
        _beautyContestIntroActive = false;
        _beautyContestIntroTimer = 0;
        _beautyContestTimer = 0;
      }
      return;
    }

    if (_contestCinematicMode == _ContestCinematicMode.speed) {
      _updateSpeedContestCinematic(dt, comp, opp);
      return;
    }
    if (_contestCinematicMode == _ContestCinematicMode.strength) {
      _updateStrengthContestCinematic(dt, comp, opp);
      return;
    }
    if (_contestCinematicMode == _ContestCinematicMode.intelligence) {
      _updateIntelligenceContestCinematic(dt, comp, opp);
      return;
    }

    // Keep camera centered on contest arena.
    ship.pos = _beautyContestCenter;
    _revealAround(ship.pos, 220);

    final orbitA = _beautyContestTimer * _beautyContestOrbitSpeed;
    const orbitR = 170.0;
    final compPos = Offset(
      _beautyContestCenter.dx + cos(orbitA + pi) * orbitR,
      _beautyContestCenter.dy +
          sin(orbitA + pi) * orbitR * 0.48 -
          sin(
                (1 -
                        (_beautyContestCompHopTimer / _beautyContestHopDuration)
                            .clamp(0.0, 1.0)) *
                    pi,
              ) *
              _beautyContestHopHeight,
    );
    final oppPos = Offset(
      _beautyContestCenter.dx + cos(orbitA) * orbitR,
      _beautyContestCenter.dy +
          sin(orbitA) * orbitR * 0.48 -
          sin(
                (1 -
                        (_beautyContestOppHopTimer / _beautyContestHopDuration)
                            .clamp(0.0, 1.0)) *
                    pi,
              ) *
              _beautyContestHopHeight,
    );

    Offset resolvedCompPos = compPos;
    Offset resolvedOppPos = oppPos;
    if (_beautyContestTimer >= _beautyContestFinalPoseTime) {
      final finalT = Curves.easeOutCubic.transform(
        ((_beautyContestTimer - _beautyContestFinalPoseTime) /
                _beautyContestFinalPoseBlendDuration)
            .clamp(0.0, 1.0),
      );
      final winnerPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy - 124,
      );
      final loserPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy + 154,
      );
      final playerTarget = _beautyContestPlayerWon ? winnerPos : loserPos;
      final oppTarget = _beautyContestPlayerWon ? loserPos : winnerPos;
      resolvedCompPos = Offset.lerp(compPos, playerTarget, finalT)!;
      resolvedOppPos = Offset.lerp(oppPos, oppTarget, finalT)!;
      _beautyContestCompVisualScale = _beautyContestPlayerWon
          ? 1.0 + (1.18 - 1.0) * finalT
          : 1.0 + (0.64 - 1.0) * finalT;
      _beautyContestOppVisualScale = _beautyContestPlayerWon
          ? 1.0 + (0.64 - 1.0) * finalT
          : 1.0 + (1.18 - 1.0) * finalT;
      _beautyContestCompHopTimer = 0;
      _beautyContestOppHopTimer = 0;
    } else {
      _beautyContestCompVisualScale = 1.0;
      _beautyContestOppVisualScale = 1.0;
    }

    // Keep cinematic positions local to the arena center (no world wrapping),
    // otherwise one side can wrap off-screen near map edges.
    comp.position = resolvedCompPos;
    opp.position = resolvedOppPos;
    comp.anchorPosition = comp.position;
    opp.anchorPosition = opp.position;
    if (_beautyContestTimer >= _beautyContestFinalPoseTime) {
      comp.angle = -pi / 2;
      opp.angle = -pi / 2;
    } else {
      comp.angle = atan2(
        _beautyContestCenter.dy - comp.position.dy,
        _beautyContestCenter.dx - comp.position.dx,
      );
      opp.angle = atan2(
        _beautyContestCenter.dy - opp.position.dy,
        _beautyContestCenter.dx - opp.position.dx,
      );
    }

    // Timed special-ability showcases.
    if (!_beautyContestCompAbilityA &&
        _beautyContestTimer >= _beautyContestCompAbilityATime) {
      _beautyContestCompAbilityA = true;
      _beautyContestCompHopTimer = _beautyContestHopDuration;
      final result = createCosmicSpecialAbility(
        origin: comp.position,
        baseAngle: comp.angle,
        family: comp.member.family,
        element: comp.member.element,
        damage: max(6.0, comp.elemAtk * 1.5),
        maxHp: comp.maxHp,
        targetPos: opp.position,
      );
      companionProjectiles.addAll(result.projectiles);
      _spawnHitSpark(comp.position, elementColor(comp.member.element));
    }
    if (!_beautyContestOppAbilityA &&
        _beautyContestTimer >= _beautyContestOppAbilityATime) {
      _beautyContestOppAbilityA = true;
      _beautyContestOppHopTimer = _beautyContestHopDuration;
      final result = createCosmicSpecialAbility(
        origin: opp.position,
        baseAngle: opp.angle,
        family: opp.member.family,
        element: opp.member.element,
        damage: max(6.0, opp.elemAtk * 1.5),
        maxHp: opp.maxHp,
        targetPos: comp.position,
      );
      ringOpponentProjectiles.addAll(result.projectiles);
      _spawnHitSpark(opp.position, elementColor(opp.member.element));
    }
    if (!_beautyContestCompAbilityB &&
        _beautyContestTimer >= _beautyContestCompAbilityBTime) {
      _beautyContestCompAbilityB = true;
      _beautyContestCompHopTimer = _beautyContestHopDuration;
      final result = createCosmicSpecialAbility(
        origin: comp.position,
        baseAngle: comp.angle + pi * 0.18,
        family: comp.member.family,
        element: comp.member.element,
        damage: max(6.0, comp.elemAtk * 1.4),
        maxHp: comp.maxHp,
        targetPos: opp.position,
      );
      companionProjectiles.addAll(result.projectiles);
      _spawnHitSpark(comp.position, elementColor(comp.member.element));
    }
    if (!_beautyContestOppAbilityB &&
        _beautyContestTimer >= _beautyContestOppAbilityBTime) {
      _beautyContestOppAbilityB = true;
      _beautyContestOppHopTimer = _beautyContestHopDuration;
      final result = createCosmicSpecialAbility(
        origin: opp.position,
        baseAngle: opp.angle + pi * 0.16,
        family: opp.member.family,
        element: opp.member.element,
        damage: max(6.0, opp.elemAtk * 1.4),
        maxHp: opp.maxHp,
        targetPos: comp.position,
      );
      ringOpponentProjectiles.addAll(result.projectiles);
      _spawnHitSpark(opp.position, elementColor(opp.member.element));
    }

    // Move only contest showcase projectiles and vfx (no combat/collisions).
    void updateContestProjectiles(List<Projectile> list) {
      for (var i = list.length - 1; i >= 0; i--) {
        final p = list[i];
        final pSpeed = Projectile.speed * p.speedMultiplier;
        if (p.orbitCenter != null && p.orbitTime > 0) {
          p.orbitTime -= dt;
          p.orbitAngle += p.orbitSpeed * dt;
          p.orbitRadius += dt * 8.0;
          p.position = Offset(
            p.orbitCenter!.dx + cos(p.orbitAngle) * p.orbitRadius,
            p.orbitCenter!.dy + sin(p.orbitAngle) * p.orbitRadius,
          );
          if (p.orbitTime <= 0) {
            p.angle = atan2(
              p.position.dy - p.orbitCenter!.dy,
              p.position.dx - p.orbitCenter!.dx,
            );
            p.orbitCenter = null;
          }
        } else {
          p.position = Offset(
            p.position.dx + cos(p.angle) * pSpeed * dt,
            p.position.dy + sin(p.angle) * pSpeed * dt,
          );
        }
        p.life -= dt;
        if (p.life <= 0) list.removeAt(i);
      }
    }

    updateContestProjectiles(companionProjectiles);
    updateContestProjectiles(ringOpponentProjectiles);

    for (var i = vfxParticles.length - 1; i >= 0; i--) {
      vfxParticles[i].update(dt);
      if (vfxParticles[i].life <= 0) vfxParticles.removeAt(i);
    }
    for (var i = vfxRings.length - 1; i >= 0; i--) {
      vfxRings[i].update(dt);
      if (vfxRings[i].dead) vfxRings.removeAt(i);
    }
  }

  void _updateSpeedContestCinematic(
    double dt,
    CosmicCompanion comp,
    CosmicCompanion opp,
  ) {
    ship.pos = _beautyContestCenter;
    _revealAround(ship.pos, 220);

    const outerRx = 222.0;
    const outerRy = 124.0;
    const innerRx = 190.0;
    const innerRy = 102.0;
    const angularBase = 1.65;

    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;

    if (_beautyContestTimer < _speedContestRaceDuration) {
      _speedContestCompProgress += dt * angularBase * _speedContestCompRate;
      _speedContestOppProgress += dt * angularBase * _speedContestOppRate;

      final compBob = sin(_beautyContestTimer * 8.2) * 4.0;
      final oppBob = sin(_beautyContestTimer * 8.2 + 1.2) * 4.0;

      comp.position = Offset(
        _beautyContestCenter.dx + cos(_speedContestCompProgress) * outerRx,
        _beautyContestCenter.dy +
            sin(_speedContestCompProgress) * outerRy -
            compBob,
      );
      opp.position = Offset(
        _beautyContestCenter.dx + cos(_speedContestOppProgress) * innerRx,
        _beautyContestCenter.dy +
            sin(_speedContestOppProgress) * innerRy -
            oppBob,
      );

      comp.angle = atan2(
        outerRy * cos(_speedContestCompProgress),
        -outerRx * sin(_speedContestCompProgress),
      );
      opp.angle = atan2(
        innerRy * cos(_speedContestOppProgress),
        -innerRx * sin(_speedContestOppProgress),
      );
    } else {
      final finalT = Curves.easeOutCubic.transform(
        ((_beautyContestTimer - _speedContestRaceDuration) / 1.0).clamp(
          0.0,
          1.0,
        ),
      );

      final compTrackPos = Offset(
        _beautyContestCenter.dx + cos(_speedContestCompProgress) * outerRx,
        _beautyContestCenter.dy + sin(_speedContestCompProgress) * outerRy,
      );
      final oppTrackPos = Offset(
        _beautyContestCenter.dx + cos(_speedContestOppProgress) * innerRx,
        _beautyContestCenter.dy + sin(_speedContestOppProgress) * innerRy,
      );

      final winnerPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy - 124,
      );
      final loserPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy + 154,
      );
      final playerTarget = _beautyContestPlayerWon ? winnerPos : loserPos;
      final oppTarget = _beautyContestPlayerWon ? loserPos : winnerPos;

      comp.position = Offset.lerp(compTrackPos, playerTarget, finalT)!;
      opp.position = Offset.lerp(oppTrackPos, oppTarget, finalT)!;

      _beautyContestCompVisualScale = _beautyContestPlayerWon
          ? 1.0 + (1.16 - 1.0) * finalT
          : 1.0 + (0.64 - 1.0) * finalT;
      _beautyContestOppVisualScale = _beautyContestPlayerWon
          ? 1.0 + (0.64 - 1.0) * finalT
          : 1.0 + (1.16 - 1.0) * finalT;
      comp.angle = -pi / 2;
      opp.angle = -pi / 2;
    }

    comp.anchorPosition = comp.position;
    opp.anchorPosition = opp.position;

    for (var i = vfxParticles.length - 1; i >= 0; i--) {
      vfxParticles[i].update(dt);
      if (vfxParticles[i].life <= 0) vfxParticles.removeAt(i);
    }
    for (var i = vfxRings.length - 1; i >= 0; i--) {
      vfxRings[i].update(dt);
      if (vfxRings[i].dead) vfxRings.removeAt(i);
    }
  }

  void _updateStrengthContestCinematic(
    double dt,
    CosmicCompanion comp,
    CosmicCompanion opp,
  ) {
    ship.pos = _beautyContestCenter;
    _revealAround(ship.pos, 220);

    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;

    const baseHalf = 132.0;
    const baseY = 24.0;
    const laneHalfExtent = 118.0;

    if (_beautyContestTimer < _strengthContestDuration) {
      final forceDelta = (_strengthContestCompForce - _strengthContestOppForce);
      _strengthContestShift -= forceDelta * dt * 11.0;
      _strengthContestShift = _strengthContestShift.clamp(
        -laneHalfExtent,
        laneHalfExtent,
      );

      final compThump = sin(_beautyContestTimer * 9.2) * 6.0;
      final oppThump = sin(_beautyContestTimer * 9.2 + 1.1) * 6.0;
      final clashY = _beautyContestCenter.dy + baseY;

      comp.position = Offset(
        _beautyContestCenter.dx - baseHalf,
        clashY + compThump,
      );
      opp.position = Offset(
        _beautyContestCenter.dx + baseHalf,
        clashY + oppThump,
      );

      comp.angle = 0;
      opp.angle = pi;

      if ((_beautyContestTimer * 4.0).floor() !=
          ((_beautyContestTimer - dt) * 4.0).floor()) {
        final centerPulse = Offset(
          _beautyContestCenter.dx + _strengthContestShift,
          _beautyContestCenter.dy + baseY,
        );
        _spawnHitSpark(centerPulse, const Color(0xFFFFB74D));
      }
    } else {
      final finalT = Curves.easeOutCubic.transform(
        ((_beautyContestTimer - _strengthContestDuration) / 1.0).clamp(
          0.0,
          1.0,
        ),
      );
      final compClashPos = Offset(
        _beautyContestCenter.dx - baseHalf,
        _beautyContestCenter.dy + baseY,
      );
      final oppClashPos = Offset(
        _beautyContestCenter.dx + baseHalf,
        _beautyContestCenter.dy + baseY,
      );
      final winnerPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy - 124,
      );
      final loserPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy + 154,
      );
      final playerTarget = _beautyContestPlayerWon ? winnerPos : loserPos;
      final oppTarget = _beautyContestPlayerWon ? loserPos : winnerPos;
      comp.position = Offset.lerp(compClashPos, playerTarget, finalT)!;
      opp.position = Offset.lerp(oppClashPos, oppTarget, finalT)!;

      _beautyContestCompVisualScale = _beautyContestPlayerWon
          ? 1.0 + (1.20 - 1.0) * finalT
          : 1.0 + (0.62 - 1.0) * finalT;
      _beautyContestOppVisualScale = _beautyContestPlayerWon
          ? 1.0 + (0.62 - 1.0) * finalT
          : 1.0 + (1.20 - 1.0) * finalT;
      comp.angle = -pi / 2;
      opp.angle = -pi / 2;
    }

    comp.anchorPosition = comp.position;
    opp.anchorPosition = opp.position;

    for (var i = vfxParticles.length - 1; i >= 0; i--) {
      vfxParticles[i].update(dt);
      if (vfxParticles[i].life <= 0) vfxParticles.removeAt(i);
    }
    for (var i = vfxRings.length - 1; i >= 0; i--) {
      vfxRings[i].update(dt);
      if (vfxRings[i].dead) vfxRings.removeAt(i);
    }
  }

  void _updateIntelligenceContestCinematic(
    double dt,
    CosmicCompanion comp,
    CosmicCompanion opp,
  ) {
    ship.pos = _beautyContestCenter;
    _revealAround(ship.pos, 220);

    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;

    const baseHalf = 146.0;
    const baseY = 16.0;
    const orbitRx = 34.0;
    const orbitRy = 19.0;

    _intelligenceContestOrbit += dt * 1.55;

    _intelligenceContestBias = _intelligenceContestBias.clamp(-1.0, 1.0);
    var orbPos = Offset(
      _beautyContestCenter.dx +
          _intelligenceContestBias * 82.0 +
          cos(_intelligenceContestOrbit * 1.8) * 34.0,
      _beautyContestCenter.dy +
          baseY +
          sin(_intelligenceContestOrbit * 2.2 + 0.9) * 22.0,
    );

    if (_beautyContestTimer < _intelligenceContestDuration) {
      final focusDelta =
          (_intelligenceContestCompFocus - _intelligenceContestOppFocus);
      _intelligenceContestBias -= focusDelta * dt * 0.85;
      _intelligenceContestBias = _intelligenceContestBias.clamp(-1.0, 1.0);

      final compThrum = sin(_beautyContestTimer * 5.4) * 3.4;
      final oppThrum = sin(_beautyContestTimer * 5.4 + 1.4) * 3.4;

      comp.position = Offset(
        _beautyContestCenter.dx -
            baseHalf +
            cos(_intelligenceContestOrbit + pi) * orbitRx,
        _beautyContestCenter.dy +
            baseY +
            sin(_intelligenceContestOrbit + pi) * orbitRy +
            compThrum,
      );
      opp.position = Offset(
        _beautyContestCenter.dx +
            baseHalf +
            cos(_intelligenceContestOrbit) * orbitRx,
        _beautyContestCenter.dy +
            baseY +
            sin(_intelligenceContestOrbit) * orbitRy +
            oppThrum,
      );

      orbPos = Offset(
        _beautyContestCenter.dx +
            _intelligenceContestBias * 82.0 +
            cos(_intelligenceContestOrbit * 1.8) * 34.0,
        _beautyContestCenter.dy +
            baseY +
            sin(_intelligenceContestOrbit * 2.2 + 0.9) * 22.0,
      );
      comp.angle = atan2(
        orbPos.dy - comp.position.dy,
        orbPos.dx - comp.position.dx,
      );
      opp.angle = atan2(
        orbPos.dy - opp.position.dy,
        orbPos.dx - opp.position.dx,
      );

      if ((_beautyContestTimer * 3.2).floor() !=
          ((_beautyContestTimer - dt) * 3.2).floor()) {
        _spawnHitSpark(orbPos, const Color(0xFFD1C4E9));
      }
      if ((_beautyContestTimer * 1.4).floor() !=
          ((_beautyContestTimer - dt) * 1.4).floor()) {
        vfxRings.add(
          VfxShockRing(
            x: orbPos.dx,
            y: orbPos.dy,
            maxRadius: 62,
            color: const Color(0xFFB39DDB),
            expandSpeed: 160,
          ),
        );
      }
    } else {
      final finalT = Curves.easeOutCubic.transform(
        ((_beautyContestTimer - _intelligenceContestDuration) / 1.0).clamp(
          0.0,
          1.0,
        ),
      );

      final compMindPos = Offset(
        _beautyContestCenter.dx -
            baseHalf +
            cos(_intelligenceContestOrbit + pi) * orbitRx,
        _beautyContestCenter.dy +
            baseY +
            sin(_intelligenceContestOrbit + pi) * orbitRy,
      );
      final oppMindPos = Offset(
        _beautyContestCenter.dx +
            baseHalf +
            cos(_intelligenceContestOrbit) * orbitRx,
        _beautyContestCenter.dy +
            baseY +
            sin(_intelligenceContestOrbit) * orbitRy,
      );
      final winnerPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy - 124,
      );
      final loserPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy + 154,
      );
      final playerTarget = _beautyContestPlayerWon ? winnerPos : loserPos;
      final oppTarget = _beautyContestPlayerWon ? loserPos : winnerPos;
      comp.position = Offset.lerp(compMindPos, playerTarget, finalT)!;
      opp.position = Offset.lerp(oppMindPos, oppTarget, finalT)!;

      final winner = _beautyContestPlayerWon ? comp : opp;
      orbPos = Offset.lerp(orbPos, winner.position, finalT)!;

      _beautyContestCompVisualScale = _beautyContestPlayerWon
          ? 1.0 + (1.18 - 1.0) * finalT
          : 1.0 + (0.64 - 1.0) * finalT;
      _beautyContestOppVisualScale = _beautyContestPlayerWon
          ? 1.0 + (0.64 - 1.0) * finalT
          : 1.0 + (1.18 - 1.0) * finalT;
      comp.angle = -pi / 2;
      opp.angle = -pi / 2;
    }

    _intelligenceContestOrbPos = orbPos;

    comp.anchorPosition = comp.position;
    opp.anchorPosition = opp.position;

    for (var i = vfxParticles.length - 1; i >= 0; i--) {
      vfxParticles[i].update(dt);
      if (vfxParticles[i].life <= 0) vfxParticles.removeAt(i);
    }
    for (var i = vfxRings.length - 1; i >= 0; i--) {
      vfxRings[i].update(dt);
      if (vfxRings[i].dead) vfxRings.removeAt(i);
    }
  }

  // ── Garrison (home-based alchemons) ──

  /// Spawn garrison creatures around the home planet (up to beacon ring).
  void spawnGarrison(List<CosmicPartyMember> members) {
    _garrison.clear();
    if (homePlanet == null || members.isEmpty) return;
    final hp = homePlanet!;
    final vr = hp.visualRadius;
    final rng = _rng;

    for (var i = 0; i < members.length; i++) {
      final m = members[i];
      // Place between planet surface and beacon ring
      final angle = rng.nextDouble() * pi * 2;
      final dist = vr * 0.3 + rng.nextDouble() * (vr * 0.8);
      final pos = Offset(
        hp.position.dx + cos(angle) * dist,
        hp.position.dy + sin(angle) * dist,
      );
      final family = m.family.toLowerCase();
      final specScale = (_companionSpeciesScale[family] ?? 1.0) * 1.0;
      // Derive combat stats from member
      final atkDmg = 5.0 + m.statStrength * 0.5 + m.level * 0.8;
      final specialDmg = 8.0 + m.statIntelligence * 0.6 + m.level * 1.0;
      final range = 170.0 + m.statSpeed * 35.0 + m.statIntelligence * 20.0;
      final specialRange = range * 1.4;
      final garrisonHp = (80 + m.statStrength * 3 + m.level * 5).round();
      _garrison.add(
        _GarrisonCreature(
          member: m,
          position: pos,
          wanderAngle: rng.nextDouble() * pi * 2,
          speciesScale: specScale,
          attackDamage: atkDmg,
          specialDamage: specialDmg,
          attackRange: range,
          specialRange: specialRange,
          maxHp: garrisonHp,
        ),
      );
      // Load sprite
      _loadGarrisonSprite(i, m);
    }
  }

  Future<void> _loadGarrisonSprite(int index, CosmicPartyMember m) async {
    final sheet = m.spriteSheet;
    if (sheet == null) return;
    try {
      final image = await images.load(sheet.path);
      final cols = (sheet.totalFrames + sheet.rows - 1) ~/ sheet.rows;
      final anim = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: sheet.totalFrames,
          amountPerRow: cols,
          textureSize: sheet.frameSize,
          stepTime: sheet.stepTime,
          loop: true,
        ),
      );
      if (index < _garrison.length) {
        final g = _garrison[index];
        g.anim = anim;
        g.ticker = anim.createTicker();
        g.visuals = m.spriteVisuals;
        debugPrint(
          'Garrison sprite visuals[$index]: alchemy=${g.visuals?.alchemyEffect} variant=${g.visuals?.variantFaction} tint=${g.visuals?.tint}',
        );
        final desiredSize = 40.0;
        final sx = desiredSize / sheet.frameSize.x;
        final sy = desiredSize / sheet.frameSize.y;
        g.spriteScale =
            min(sx, sy) * (g.visuals?.scale ?? 1.0) * g.speciesScale;
      }
    } catch (e) {
      debugPrint('Failed to load garrison sprite: ${sheet.path} - $e');
    }
  }

  /// Wrap a position into the world bounds (toroidal).
  Offset _wrap(Offset p) {
    final w = world_.worldSize.width;
    final h = world_.worldSize.height;
    return Offset(((p.dx % w) + w) % w, ((p.dy % h) + h) % h);
  }

  /// Interpolate across toroidal bounds using shortest wrapped delta.
  Offset _toroidalLerp(Offset from, Offset to, double t) {
    final w = world_.worldSize.width;
    final h = world_.worldSize.height;
    var dx = to.dx - from.dx;
    var dy = to.dy - from.dy;
    if (dx > w / 2) dx -= w;
    if (dx < -w / 2) dx += w;
    if (dy > h / 2) dy -= h;
    if (dy < -h / 2) dy += h;
    return _wrap(Offset(from.dx + dx * t, from.dy + dy * t));
  }

  /// Returns a camera-local toroidal equivalent of [worldPos] that is nearest
  /// to the current viewport center. Useful for rendering near world edges.
  Offset _wrappedRenderPos(
    Offset worldPos,
    double camX,
    double camY,
    double screenW,
    double screenH,
  ) {
    final w = world_.worldSize.width;
    final h = world_.worldSize.height;
    final centerX = camX + screenW * 0.5;
    final centerY = camY + screenH * 0.5;

    var dx = worldPos.dx - centerX;
    var dy = worldPos.dy - centerY;
    if (dx > w / 2) dx -= w;
    if (dx < -w / 2) dx += w;
    if (dy > h / 2) dy -= h;
    if (dy < -h / 2) dy += h;
    return Offset(centerX + dx, centerY + dy);
  }

  // ── update loop ────────────────────────────────────────

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    if (_beautyContestCinematicActive) {
      _updateBeautyContestCinematic(dt);
      return;
    }

    // ── ship movement ──
    double baseSpeed = _shipDead
        ? 0.0
        : 220.0 * StarDust.speedMultiplier(collectedDustCount);

    // Apply boost if booster is equipped and player is holding boost
    isBoosting = false;
    if (boosting && !_shipDead && !shipFuel.isEmpty) {
      final fuelUsed = shipFuel.consume(boostFuelPerSecond * dt);
      if (fuelUsed > 0) {
        baseSpeed *= boostSpeedMultiplier;
        isBoosting = true;
      }
    }
    if (slowMode && !_shipDead) baseSpeed *= slowSpeedMultiplier;
    final shipSpeed = baseSpeed;

    bool shipIsIdle = false;
    // ── Joystick steering takes priority over drag-target ──
    if (joystickDirection != null) {
      final jx = joystickDirection!.dx;
      final jy = joystickDirection!.dy;
      final mag = sqrt(jx * jx + jy * jy);
      if (mag > 0.05) {
        final nx = jx / mag;
        final ny = jy / mag;
        // Use magnitude (0-1) to scale speed for analogue feel
        final move = shipSpeed * mag.clamp(0.0, 1.0) * dt;
        ship.pos = Offset(ship.pos.dx + nx * move, ship.pos.dy + ny * move);
        ship.angle = atan2(ny, nx);
        // Clear drag target so ship doesn't snap back
        _dragTarget = null;
      } else {
        shipIsIdle = true;
      }
    } else if (_dragTarget != null) {
      var dx = _dragTarget!.dx - ship.pos.dx;
      var dy = _dragTarget!.dy - ship.pos.dy;
      final ww = world_.worldSize.width;
      final wh = world_.worldSize.height;
      if (dx > ww / 2) dx -= ww;
      if (dx < -ww / 2) dx += ww;
      if (dy > wh / 2) dy -= wh;
      if (dy < -wh / 2) dy += wh;
      final dist = sqrt(dx * dx + dy * dy);

      if (dist > 5) {
        final nx = dx / dist;
        final ny = dy / dist;
        final move = min(shipSpeed * dt, dist);
        ship.pos = Offset(ship.pos.dx + nx * move, ship.pos.dy + ny * move);
        ship.angle = atan2(ny, nx);
      } else {
        shipIsIdle = true;
      }
    } else {
      shipIsIdle = true;
    }

    // ── Nexus pocket dimension mode ──
    if (inNexusPocket) {
      _updatePocketMode(dt);
      return; // skip normal world update
    }

    // ── gravity from planets ──
    double gx = 0, gy = 0;
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    CosmicPlanet? orbitPlanet;
    double orbitDist = double.infinity;
    for (final planet in world_.planets) {
      // Shortest distance accounting for wrapping
      var pdx = planet.position.dx - ship.pos.dx;
      var pdy = planet.position.dy - ship.pos.dy;
      if (pdx > ww / 2) pdx -= ww;
      if (pdx < -ww / 2) pdx += ww;
      if (pdy > wh / 2) pdy -= wh;
      if (pdy < -wh / 2) pdy += wh;
      final dist2 = pdx * pdx + pdy * pdy;
      final dist = sqrt(dist2);
      // Only apply gravity within ~600 units; prevent extreme close forces
      if (dist < 600 && dist > planet.radius * 0.5) {
        final force = planet.gravityStrength / dist2;
        gx += (pdx / dist) * force;
        gy += (pdy / dist) * force;
      }
      // Track closest planet for orbit
      if (dist < planet.radius * 3.5 && dist < orbitDist) {
        orbitPlanet = planet;
        orbitDist = dist;
      }
    }

    // ── gravity from home planet ──
    double homeOrbitR = 0;
    bool nearHomePlanet = false;
    if (homePlanet != null) {
      final hp = homePlanet!;
      final hpR = hp.visualRadius;
      var hdx = hp.position.dx - ship.pos.dx;
      var hdy = hp.position.dy - ship.pos.dy;
      if (hdx > ww / 2) hdx -= ww;
      if (hdx < -ww / 2) hdx += ww;
      if (hdy > wh / 2) hdy -= wh;
      if (hdy < -wh / 2) hdy += wh;
      final hDist2 = hdx * hdx + hdy * hdy;
      final hDist = sqrt(hDist2);
      // Gravity pull within 500 units
      if (hDist < 500 && hDist > hpR * 0.4) {
        final hForce = 25000.0 / hDist2;
        gx += (hdx / hDist) * hForce;
        gy += (hdy / hDist) * hForce;
      }
      // Home planet can be an orbit target too (prioritise over cosmic planets
      // when closer)
      homeOrbitR = hpR * 2.2;
      if (hDist < hpR * 4.0 && hDist < orbitDist) {
        nearHomePlanet = true;
        orbitDist = hDist;
        orbitPlanet = null; // clear cosmic orbit — home takes priority
      }
    }

    ship.pos = Offset(ship.pos.dx + gx * dt, ship.pos.dy + gy * dt);

    // ── ship orbit when idle near a planet ──
    if (shipIsIdle && !_shipDead && (orbitPlanet != null || nearHomePlanet)) {
      // Determine orbit centre, radius
      final Offset orbitCentre;
      final double desiredR;
      if (nearHomePlanet) {
        orbitCentre = homePlanet!.position;
        desiredR = homeOrbitR;
      } else {
        orbitCentre = orbitPlanet!.position;
        desiredR = orbitPlanet.radius * 2.0;
      }
      var pdx = orbitCentre.dx - ship.pos.dx;
      var pdy = orbitCentre.dy - ship.pos.dy;
      if (pdx > ww / 2) pdx -= ww;
      if (pdx < -ww / 2) pdx += ww;
      if (pdy > wh / 2) pdy -= wh;
      if (pdy < -wh / 2) pdy += wh;
      final dist = sqrt(pdx * pdx + pdy * pdy);
      if (dist > 1.0) {
        final dir = Offset(pdx / dist, pdy / dist);
        // Gently pull/push toward orbit radius
        final radialError = dist - desiredR;
        final radialForce = radialError.clamp(-80.0, 80.0) * 0.8;
        ship.pos = Offset(
          ship.pos.dx + dir.dx * radialForce * dt,
          ship.pos.dy + dir.dy * radialForce * dt,
        );
        // Tangential orbit drift
        final tangent = Offset(-dir.dy, dir.dx);
        final orbitSpeed = nearHomePlanet
            ? 30.0 + homePlanet!.visualRadius * 0.2
            : 35.0 + orbitPlanet!.radius * 0.25;
        ship.pos = Offset(
          ship.pos.dx + tangent.dx * orbitSpeed * dt,
          ship.pos.dy + tangent.dy * orbitSpeed * dt,
        );
        // Smoothly rotate ship to face tangent direction
        ship.angle = atan2(tangent.dy, tangent.dx);
        // Update drag target to follow orbit so ship doesn't snap back
        _dragTarget = ship.pos;
      }
    }

    // ── wrap ship position ──
    ship.pos = _wrap(ship.pos);

    // ── reveal fog ──
    _revealAround(ship.pos, 280);

    // ── discover planets ──
    for (var i = 0; i < world_.planets.length; i++) {
      final p = world_.planets[i];
      if (!p.discovered) {
        final dist = (p.position - ship.pos).distance;
        if (dist < p.radius + 200) {
          p.discovered = true;
          // Guarantee a boss on first discovery
          _spawnDiscoveryBoss(p);
        }
      }
    }

    // ── detect nearest planet for recipe HUD ──
    CosmicPlanet? closest;
    double closestDist = double.infinity;
    for (final p in world_.planets) {
      if (!p.discovered) continue;
      var pdx = p.position.dx - ship.pos.dx;
      var pdy = p.position.dy - ship.pos.dy;
      if (pdx > ww / 2) pdx -= ww;
      if (pdx < -ww / 2) pdx += ww;
      if (pdy > wh / 2) pdy -= wh;
      if (pdy < -wh / 2) pdy += wh;
      final dist = sqrt(pdx * pdx + pdy * pdy);
      if (dist < p.radius * 4 && dist < closestDist) {
        closest = p;
        closestDist = dist;
      }
    }
    if (closest != nearPlanet) {
      nearPlanet = closest;
      onNearPlanet?.call(closest);
    }

    // ── detect nearest market POI ──
    SpacePOI? closestMarket;
    double closestMarketDist = double.infinity;
    for (final poi in spacePOIs) {
      if (poi.type != POIType.harvesterMarket &&
          poi.type != POIType.riftKeyMarket &&
          poi.type != POIType.cosmicMarket &&
          poi.type != POIType.stardustScanner) {
        continue;
      }
      var mdx = poi.position.dx - ship.pos.dx;
      var mdy = poi.position.dy - ship.pos.dy;
      if (mdx > ww / 2) mdx -= ww;
      if (mdx < -ww / 2) mdx += ww;
      if (mdy > wh / 2) mdy -= wh;
      if (mdy < -wh / 2) mdy += wh;
      final dist = sqrt(mdx * mdx + mdy * mdy);
      // Discover market when ship is within visual range
      if (!poi.discovered && dist < poi.radius * 4) {
        poi.discovered = true;
      }
      if (dist < poi.radius * 2.5 && dist < closestMarketDist) {
        closestMarket = poi;
        closestMarketDist = dist;
      }
    }
    if (closestMarket != nearMarket) {
      nearMarket = closestMarket;
      onNearMarket?.call(closestMarket);
    }

    // ── detect near home planet ──
    final nearHome = isNearHome;
    if (nearHome != _wasNearHome) {
      _wasNearHome = nearHome;
      onNearHome?.call(nearHome);
    }

    // ── emit element particles from planets ──
    final rng = Random();
    const maxParticles = 600;
    for (final planet in world_.planets) {
      // Use wrapped distance for emission check
      var edx = planet.position.dx - ship.pos.dx;
      var edy = planet.position.dy - ship.pos.dy;
      if (edx > ww / 2) edx -= ww;
      if (edx < -ww / 2) edx += ww;
      if (edy > wh / 2) edy -= wh;
      if (edy < -wh / 2) edy += wh;
      final screenDist = sqrt(edx * edx + edy * edy);
      if (screenDist > 4000) continue;
      if (elemParticles.length >= maxParticles) break;

      // Emit rate scales with proximity: faster when close
      final emitRate = screenDist < 2000 ? 12.0 : 6.0;
      if (rng.nextDouble() < dt * emitRate) {
        final angle = rng.nextDouble() * pi * 2;
        final spawnDist =
            planet.radius + rng.nextDouble() * planet.particleFieldRadius;
        elemParticles.add(
          ElementParticle(
            x: planet.position.dx + cos(angle) * spawnDist,
            y: planet.position.dy + sin(angle) * spawnDist,
            vx: cos(angle) * (15 + rng.nextDouble() * 45),
            vy: sin(angle) * (15 + rng.nextDouble() * 45),
            element: planet.element,
            life: 8.0 + rng.nextDouble() * 10.0,
            size: 2.0 + rng.nextDouble() * 3.0,
          ),
        );
      }
    }

    // ── update & collect element particles ──
    for (var i = elemParticles.length - 1; i >= 0; i--) {
      final p = elemParticles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;

      if (p.life <= 0) {
        elemParticles.removeAt(i);
        continue;
      }

      // Check collection by ship
      final dx = p.x - ship.pos.dx;
      final dy = p.y - ship.pos.dy;
      if (dx * dx + dy * dy < 30 * 30) {
        // Collected!
        if (!meter.isFull) {
          meter.add(p.element, 0.5 * _meterPickupMultiplier);
          onMeterChanged();
        }
        elemParticles.removeAt(i);
      }
    }

    // ── warp flash animation ──
    if (_warpFlash > 0) {
      _warpFlash -= dt * 1.2; // ~0.85 sec total
      if (_warpFlash < 0) _warpFlash = 0;
    }

    // ── particle swarms: drift, orbit motes, collect ──
    final ww2 = world_.worldSize.width;
    final wh2 = world_.worldSize.height;
    for (final swarm in world_.particleSwarms) {
      swarm.pulse += dt;

      // Drift the swarm centre slowly (always, even off-screen)
      swarm.driftTimer -= dt;
      if (swarm.driftTimer <= 0) {
        swarm.driftAngle += (Random().nextDouble() - 0.5) * 1.2;
        swarm.driftTimer = 3.0 + Random().nextDouble() * 4.0;
      }
      swarm.center = _wrap(
        Offset(
          swarm.center.dx +
              cos(swarm.driftAngle) * ParticleSwarm.driftSpeed * dt,
          swarm.center.dy +
              sin(swarm.driftAngle) * ParticleSwarm.driftSpeed * dt,
        ),
      );

      // Distance cull: skip per-mote work if swarm centre is far from ship
      var sdx = swarm.center.dx - ship.pos.dx;
      var sdy = swarm.center.dy - ship.pos.dy;
      if (sdx > ww2 / 2) sdx -= ww2;
      if (sdx < -ww2 / 2) sdx += ww2;
      if (sdy > wh2 / 2) sdy -= wh2;
      if (sdy < -wh2 / 2) sdy += wh2;
      final swarmDist2 = sdx * sdx + sdy * sdy;
      // Only update motes within ~1200 units (cloudRadius + comfortable margin)
      const swarmCullRange = 1200.0;
      if (swarmDist2 > swarmCullRange * swarmCullRange) continue;

      // Update each mote — gentle orbit + collection
      for (final mote in swarm.motes) {
        if (mote.collected) continue;

        // Gentle orbital motion around the swarm centre
        mote.orbitPhase += mote.orbitSpeed * dt;
        final wobbleX = cos(mote.orbitPhase) * 8.0 * dt;
        final wobbleY = sin(mote.orbitPhase * 1.3) * 8.0 * dt;
        mote.offsetX += wobbleX;
        mote.offsetY += wobbleY;

        // Soft cohesion: pull back toward centre if too far
        final dist = sqrt(
          mote.offsetX * mote.offsetX + mote.offsetY * mote.offsetY,
        );
        if (dist > ParticleSwarm.cloudRadius) {
          final pull = (dist - ParticleSwarm.cloudRadius) * 0.5 * dt;
          mote.offsetX -= (mote.offsetX / dist) * pull;
          mote.offsetY -= (mote.offsetY / dist) * pull;
        }

        // World-space position of this mote
        final mx = swarm.center.dx + mote.offsetX;
        final my = swarm.center.dy + mote.offsetY;

        // Toroidal distance to ship
        var mdx = mx - ship.pos.dx;
        var mdy = my - ship.pos.dy;
        if (mdx > ww2 / 2) mdx -= ww2;
        if (mdx < -ww2 / 2) mdx += ww2;
        if (mdy > wh2 / 2) mdy -= wh2;
        if (mdy < -wh2 / 2) mdy += wh2;
        final mDist2 = mdx * mdx + mdy * mdy;

        // Magnetic pull when close
        if (mDist2 < ParticleSwarm.magnetRadius * ParticleSwarm.magnetRadius) {
          final mDist = sqrt(mDist2);
          if (mDist > 1) {
            final pull =
                180.0 * (1.0 - mDist / ParticleSwarm.magnetRadius) * dt;
            // Pull mote toward ship by adjusting its offset
            mote.offsetX -= (mdx / mDist) * pull;
            mote.offsetY -= (mdy / mDist) * pull;
          }
        }

        // Collect when very close
        if (mDist2 <
            ParticleSwarm.collectRadius * ParticleSwarm.collectRadius) {
          mote.collected = true;
          if (!meter.isFull) {
            meter.add(swarm.element, 1.0 * _meterPickupMultiplier);
            onMeterChanged();
          }
        }
      }

      // If swarm is depleted, respawn it elsewhere
      if (swarm.depleted) {
        _respawnSwarm(swarm);
      }
    }

    // ── collect star dust ──
    for (final dust in starDusts) {
      if (dust.collected) continue;
      final ddx = dust.position.dx - ship.pos.dx;
      final ddy = dust.position.dy - ship.pos.dy;
      if (ddx * ddx + ddy * ddy < 50 * 50) {
        dust.collected = true;
        collectedDustCount++;
        if (_starDustScannerTargetIndex == dust.index) {
          _starDustScannerTargetIndex = null;
          _scannerCompletedDustIndex = dust.index;
        }
        syncStarDustScannerAvailability();
        onStarDustCollected?.call(dust.index);
      }
    }

    // ── loot drops: update, magnetic pull, collection ──
    for (var i = lootDrops.length - 1; i >= 0; i--) {
      final drop = lootDrops[i];
      if (drop.collected || drop.expired) {
        lootDrops.removeAt(i);
        continue;
      }
      drop.update(dt);
      // Wrap to world
      drop.position = _wrap(drop.position);

      // Magnetic pull toward ship when close
      final ldx = ship.pos.dx - drop.position.dx;
      final ldy = ship.pos.dy - drop.position.dy;
      final ldist2 = ldx * ldx + ldy * ldy;
      if (ldist2 < LootDrop.magnetRadius * LootDrop.magnetRadius &&
          ldist2 > 1) {
        final ldist = sqrt(ldist2);
        final pullStrength = 300.0 * (1.0 - ldist / LootDrop.magnetRadius);
        drop.velocity += Offset(
          ldx / ldist * pullStrength * dt,
          ldy / ldist * pullStrength * dt,
        );
      }

      // Pickup
      if (ldist2 < LootDrop.pickupRadius * LootDrop.pickupRadius) {
        drop.collected = true;
        onLootCollected?.call(drop);
      }
    }

    // ── ship shooting (primary weapon) ──
    if (_shootCooldown > 0) _shootCooldown -= dt;
    final fireRate = activeWeaponId == 'equip_machinegun'
        ? 0.10
        : shootInterval;
    if (shooting && !_shipDead && _shootCooldown <= 0) {
      _shootCooldown = fireRate;
      projectiles.add(
        Projectile(
          position: Offset(
            ship.pos.dx + cos(ship.angle) * 20,
            ship.pos.dy + sin(ship.angle) * 20,
          ),
          angle: ship.angle,
        ),
      );
    }

    // ── missile launcher (secondary weapon, fires independently) ──
    if (_missileShootCooldown > 0) _missileShootCooldown -= dt;
    if (shootingMissiles &&
        hasMissiles &&
        !_shipDead &&
        _missileShootCooldown <= 0) {
      if (missileAmmo > 0) {
        _missileShootCooldown = 0.60;
        missileAmmo--;
        _missiles.add(
          _HomingMissile(
            position: Offset(
              ship.pos.dx + cos(ship.angle) * 20,
              ship.pos.dy + sin(ship.angle) * 20,
            ),
            angle: ship.angle,
          ),
        );
      }
    }

    // ── update homing missiles ──
    for (var i = _missiles.length - 1; i >= 0; i--) {
      final m = _missiles[i];
      // Find nearest enemy to track
      Offset? target;
      double bestDist2 = double.infinity;
      for (final e in enemies) {
        final edx = e.position.dx - m.position.dx;
        final edy = e.position.dy - m.position.dy;
        final d2 = edx * edx + edy * edy;
        if (d2 < bestDist2) {
          bestDist2 = d2;
          target = e.position;
        }
      }
      if (activeBoss != null) {
        final bdx = activeBoss!.position.dx - m.position.dx;
        final bdy = activeBoss!.position.dy - m.position.dy;
        final bd2 = bdx * bdx + bdy * bdy;
        if (bd2 < bestDist2) {
          target = activeBoss!.position;
        }
      }
      // Steer toward target
      if (target != null) {
        final desired = atan2(
          target.dy - m.position.dy,
          target.dx - m.position.dx,
        );
        var diff = desired - m.angle;
        // Normalise to -pi..pi
        while (diff > pi) {
          diff -= 2 * pi;
        }
        while (diff < -pi) {
          diff += 2 * pi;
        }
        m.angle += diff.clamp(
          -_HomingMissile.turnRate * dt,
          _HomingMissile.turnRate * dt,
        );
      }
      m.position = Offset(
        m.position.dx + cos(m.angle) * _HomingMissile.speed * dt,
        m.position.dy + sin(m.angle) * _HomingMissile.speed * dt,
      );
      m.life -= dt;
      if (m.life <= 0) {
        _missiles.removeAt(i);
        continue;
      }
      // Check collision with enemies
      final missileMult = HomeCustomizationState.damageMultiplier(
        missileUpgradeLevel,
      );
      bool missileHit = false;
      for (final e in enemies) {
        final edx = m.position.dx - e.position.dx;
        final edy = m.position.dy - e.position.dy;
        if (edx * edx + edy * edy < (e.radius + 6) * (e.radius + 6)) {
          e.health -= 5.0 * missileMult; // missiles do heavy damage
          _spawnHitSpark(m.position, const Color(0xFFFF6F00));
          missileHit = true;
          break;
        }
      }
      // Check boss
      if (!missileHit && activeBoss != null) {
        final boss = activeBoss!;
        final bdx = m.position.dx - boss.position.dx;
        final bdy = m.position.dy - boss.position.dy;
        if (bdx * bdx + bdy * bdy < (boss.radius + 6) * (boss.radius + 6)) {
          if (boss.shieldUp && boss.type == BossType.gunner) {
            boss.shieldHealth -= 5.0 * missileMult;
            _spawnHitSpark(m.position, Colors.cyanAccent);
            if (boss.shieldHealth <= 0) {
              boss.shieldUp = false;
              boss.shieldTimer = CosmicBoss.shieldCooldown;
            }
          } else {
            boss.health -= 5.0 * missileMult;
            _spawnHitSpark(m.position, const Color(0xFFFF6F00));
            if (boss.health <= 0) {
              _handleBossKill(boss);
            }
          }
          missileHit = true;
        }
      }
      if (missileHit) {
        _missiles.removeAt(i);
      }
    }

    // ── update orbital sentinels ──
    for (var i = orbitals.length - 1; i >= 0; i--) {
      orbitals[i].update(dt);
      final oPos = orbitals[i].positionAround(ship.pos);
      // Skip collision while fading in (invulnerable)
      if (!orbitals[i].invulnerable) {
        // Check collision with enemies
        for (final e in enemies) {
          final edx = oPos.dx - e.position.dx;
          final edy = oPos.dy - e.position.dy;
          if (edx * edx + edy * edy <
              (OrbitalSentinel.hitboxRadius + e.radius) *
                  (OrbitalSentinel.hitboxRadius + e.radius)) {
            // Both take damage
            orbitals[i].health -=
                0.2; // sentinel takes a hit but survives several
            e.health -= 3.5; // orbitals deal heavy damage
            _spawnHitSpark(oPos, const Color(0xFF42A5F5));
            break;
          }
        }
      }
      if (orbitals[i].dead) {
        _spawnKillVfx(oPos, const Color(0xFF42A5F5), 8, false);
        orbitals.removeAt(i);
      }
    }
    // Auto-respawn destroyed sentinels after cooldown (requires stockpile)
    if (orbitals.length < OrbitalSentinel.maxActive && orbitalStockpile > 0) {
      _orbitalReplenishTimer += dt;
      if (_orbitalReplenishTimer >= OrbitalSentinel.respawnCooldown) {
        _orbitalReplenishTimer = 0;
        orbitalStockpile--;
        final angle = orbitals.isEmpty
            ? 0.0
            : orbitals.last.angle + (2 * pi / OrbitalSentinel.maxActive);
        orbitals.add(OrbitalSentinel(angle: angle));
      }
    } else {
      _orbitalReplenishTimer = 0;
    }

    // ── update projectiles ──
    for (var i = projectiles.length - 1; i >= 0; i--) {
      final p = projectiles[i];
      p.position = Offset(
        p.position.dx + cos(p.angle) * Projectile.speed * dt,
        p.position.dy + sin(p.angle) * Projectile.speed * dt,
      );
      p.life -= dt;
      if (p.life <= 0) {
        projectiles.removeAt(i);
        continue;
      }

      // ── projectile vs asteroid collision ──
      final ammoMult = HomeCustomizationState.damageMultiplier(
        ammoUpgradeLevel,
      );
      final projDmg =
          (activeWeaponId == 'equip_machinegun' ? 0.15 : 0.34) * ammoMult;
      for (final rock in asteroidBelt.asteroids) {
        if (rock.destroyed) continue;
        final rdx = p.position.dx - rock.position.dx;
        final rdy = p.position.dy - rock.position.dy;
        if (rdx * rdx + rdy * rdy <
            (rock.radius + Projectile.radius) *
                (rock.radius + Projectile.radius)) {
          rock.health -= projDmg;
          _spawnHitSpark(p.position, const Color(0xFF8B7355));
          projectiles.removeAt(i);
          if (rock.destroyed) {
            _spawnKillVfx(
              rock.position,
              const Color(0xFF8B7355),
              rock.radius,
              false,
            );
            // ~40% chance to drop 1-2 shards
            if (Random().nextDouble() < 0.4) {
              _spawnLootDrops(
                rock.position,
                'Earth',
                Random().nextInt(2) + 1,
                0,
              );
            }
            onAsteroidDestroyed?.call();
          }
          break;
        }
      }

      // ── projectile vs enemy collision ──
      if (i < projectiles.length && projectiles[i] == p) {
        for (var ei = enemies.length - 1; ei >= 0; ei--) {
          final enemy = enemies[ei];
          if (enemy.dead) continue;
          final edx = p.position.dx - enemy.position.dx;
          final edy = p.position.dy - enemy.position.dy;
          final hitR = enemy.radius + Projectile.radius;
          if (edx * edx + edy * edy < hitR * hitR) {
            // Machine gun: lower damage per shot but rapid fire
            final eDmg =
                ((activeWeaponId == 'equip_machinegun' ? 0.35 : 1.0) *
                    HomeCustomizationState.damageMultiplier(ammoUpgradeLevel)) *
                kDamageScale;
            enemy.health -= eDmg;
            // Hit spark
            _spawnHitSpark(p.position, elementColor(enemy.element));
            // Provoke pack if passive enemy was hit
            if (!enemy.provoked &&
                (enemy.behavior == EnemyBehavior.feeding ||
                    enemy.behavior == EnemyBehavior.territorial ||
                    enemy.behavior == EnemyBehavior.drifting)) {
              _provokePackOf(enemy);
            }
            projectiles.removeAt(i);
            if (enemy.health <= 0) {
              enemy.dead = true;
              _spawnKillVfx(
                enemy.position,
                elementColor(enemy.element),
                enemy.radius,
                false,
              );
              _spawnLootDrops(
                enemy.position,
                enemy.element,
                enemy.shardDrop,
                enemy.particleDrop,
              );
            }
            break;
          }
        }
      }

      // ── projectile vs ring-minion collision (ring fight only) ──
      if (i < projectiles.length &&
          projectiles[i] == p &&
          battleRing.inBattle &&
          ringMinions.isNotEmpty) {
        for (var ri = ringMinions.length - 1; ri >= 0; ri--) {
          final rm = ringMinions[ri];
          if (rm.dead) continue;
          final rdx = p.position.dx - rm.position.dx;
          final rdy = p.position.dy - rm.position.dy;
          final rHitR = rm.radius + Projectile.radius;
          if (rdx * rdx + rdy * rdy < rHitR * rHitR) {
            final projDmg =
                ((activeWeaponId == 'equip_machinegun' ? 0.35 : 1.0) *
                    HomeCustomizationState.damageMultiplier(ammoUpgradeLevel)) *
                kDamageScale;
            rm.health -= projDmg;
            _spawnHitSpark(p.position, elementColor(rm.element));
            projectiles.removeAt(i);
            if (rm.health <= 0) {
              rm.dead = true;
              _spawnKillVfx(
                rm.position,
                elementColor(rm.element),
                rm.radius,
                false,
              );
            }
            break;
          }
        }
      }

      // ── projectile vs orbital chamber collision ──
      if (i < projectiles.length && projectiles[i] == p) {
        for (final chamber in orbitalChambers) {
          final cdx = p.position.dx - chamber.position.dx;
          final cdy = p.position.dy - chamber.position.dy;
          final cHitR = chamber.radius + Projectile.radius;
          if (cdx * cdx + cdy * cdy < cHitR * cHitR) {
            // Apply impulse in projectile direction
            final pDir = Offset(cos(p.angle), sin(p.angle));
            chamber.applyImpulse(pDir * 280.0);
            _spawnHitSpark(p.position, chamber.color);
            projectiles.removeAt(i);
            break;
          }
        }
      }

      // ── projectile vs boss collision ──
      if (activeBoss != null &&
          !activeBoss!.dead &&
          i < projectiles.length &&
          projectiles[i] == p) {
        final boss = activeBoss!;
        final bdx = p.position.dx - boss.position.dx;
        final bdy = p.position.dy - boss.position.dy;
        final bHitR = boss.radius + Projectile.radius;
        if (bdx * bdx + bdy * bdy < bHitR * bHitR) {
          // Gunner shield absorbs damage
          final projBossDmg =
              (1.0 *
                  HomeCustomizationState.damageMultiplier(ammoUpgradeLevel)) *
              kDamageScale;
          if (boss.shieldUp && boss.type == BossType.gunner) {
            boss.shieldHealth -= projBossDmg;
            _spawnHitSpark(p.position, Colors.cyanAccent);
            projectiles.removeAt(i);
            if (boss.shieldHealth <= 0) {
              boss.shieldUp = false;
              boss.shieldTimer = CosmicBoss.shieldCooldown;
            }
          } else {
            boss.health -= projBossDmg;
            _spawnHitSpark(p.position, elementColor(boss.element));
            projectiles.removeAt(i);
            if (boss.health <= 0) {
              _handleBossKill(boss);
            }
          }
        }
      }
    }

    // ── asteroid orbital drift ──
    final beltCx = asteroidBelt.center.dx;
    final beltCy = asteroidBelt.center.dy;
    for (final rock in asteroidBelt.asteroids) {
      if (rock.destroyed) continue;
      rock.orbitAngle += rock.orbitSpeed * dt;
      rock.position = Offset(
        beltCx + cos(rock.orbitAngle) * rock.orbitDist,
        beltCy + sin(rock.orbitAngle) * rock.orbitDist,
      );
    }

    // ── update companion (summoned party alchemon) ──
    if (activeCompanion != null) {
      final comp = activeCompanion!;
      comp.life += dt;
      comp.invincibleTimer = (comp.invincibleTimer - dt).clamp(0.0, 10.0);

      // Advance sprite animation
      _companionTicker?.update(dt);

      // Returning fade-out
      if (comp.returning) {
        comp.returnTimer -= dt;
        if (comp.returnTimer <= 0) {
          activeCompanion = null;
          _companionTicker = null;
          _companionVisuals = null;
        }
      } else if (comp.currentHp <= 0) {
        // Companion died — auto return
        _spawnKillVfx(
          comp.position,
          elementColor(comp.member.element),
          12,
          false,
        );
        final diedMember = comp.member;
        activeCompanion = null;
        _companionTicker = null;
        _companionVisuals = null;
        onCompanionDied?.call(diedMember);
      } else {
        // Auto-return if companion is far off screen (skip during ring battle)
        final margin = 350.0;
        final dx = (comp.position.dx - ship.pos.dx).abs();
        final dy = (comp.position.dy - ship.pos.dy).abs();
        if (!battleRing.inBattle &&
            (dx > size.x / 2 + margin || dy > size.y / 2 + margin)) {
          comp.returning = true;
          comp.returnTimer = 0.6;
          onCompanionAutoReturned?.call();
        } else {
          comp.wanderTimer -= dt;
          if (comp.wanderTimer <= 0) {
            // Pick a new wander direction every 2-3s
            comp.wanderAngle = _rng.nextDouble() * 2 * pi;
            comp.wanderTimer = 2.0 + _rng.nextDouble();
          }

          // Drift gently toward the wander target (stays within radius)
          final wanderTarget = Offset(
            comp.anchorPosition.dx +
                cos(comp.wanderAngle) * CosmicCompanion.wanderRadius * 0.6,
            comp.anchorPosition.dy +
                sin(comp.wanderAngle) * CosmicCompanion.wanderRadius * 0.6,
          );
          final toWander = wanderTarget - comp.position;
          final wanderDist = toWander.distance;
          if (wanderDist > 2.0) {
            final wanderSpeed = 40.0 * dt; // gentle drift
            comp.position +=
                (toWander / wanderDist) * min(wanderSpeed, wanderDist);
          }

          // Clamp within wander radius of anchor
          final fromAnchor = comp.position - comp.anchorPosition;
          if (fromAnchor.distance > CosmicCompanion.wanderRadius) {
            final clamped =
                (fromAnchor / fromAnchor.distance) *
                CosmicCompanion.wanderRadius;
            comp.position = comp.anchorPosition + clamped;
          }

          // Auto-attack nearest enemy
          comp.basicCooldown = (comp.basicCooldown - dt).clamp(0.0, 100.0);
          comp.specialCooldown = (comp.specialCooldown - dt).clamp(0.0, 100.0);

          // ── Horn charge: rush toward target, AoE on arrival ──
          if (comp.isCharging) {
            comp.chargeTimer -= dt;
            if (comp.chargeTarget != null) {
              final toTarget = comp.chargeTarget! - comp.position;
              final dist = toTarget.distance;
              if (dist > 10) {
                final step = CosmicCompanion.chargeSpeed * dt;
                comp.position += (toTarget / dist) * min(step, dist);
                comp.angle = atan2(toTarget.dy, toTarget.dx);
              } else {
                // Arrived — deal AoE damage to nearby enemies
                for (final e in enemies) {
                  if (e.dead) continue;
                  final d = (e.position - comp.position).distance;
                  if (d < 60) {
                    e.health -= comp.chargeDamage;
                    _spawnHitSpark(
                      e.position,
                      elementColor(comp.member.element),
                    );
                    if (!e.provoked) _provokePackOf(e);
                  }
                }
                if (activeBoss != null) {
                  final bd = (activeBoss!.position - comp.position).distance;
                  if (bd < 60) {
                    activeBoss!.health -= comp.chargeDamage;
                    _spawnHitSpark(
                      comp.position,
                      elementColor(comp.member.element),
                    );
                  }
                }
                // Ring opponent charge hit
                if (battleRingOpponent != null && battleRingOpponent!.isAlive) {
                  final rd =
                      (battleRingOpponent!.position - comp.position).distance;
                  if (rd < 60) {
                    battleRingOpponent!.takeDamage(comp.chargeDamage.round());
                    _spawnHitSpark(
                      battleRingOpponent!.position,
                      elementColor(comp.member.element),
                    );
                  }
                }
                comp.chargeTimer = 0;
                comp.chargeTarget = null;
              }
            }
            if (comp.chargeTimer <= 0) {
              comp.chargeTarget = null;
            }
          }

          // ── Kin blessing: heal over time ──
          if (comp.isBlessing) {
            comp.blessingTimer -= dt;
            // Heal a small tick each frame
            comp.currentHp = min(
              comp.maxHp,
              comp.currentHp + (comp.blessingHealPerTick * dt).round(),
            );
          }

          // Find nearest enemy in engage range (basic or special).
          final engageRange = max(comp.attackRange, comp.specialAbilityRange);
          CosmicEnemy? nearestEnemy;
          double nearestDist = engageRange;

          // During ring battle, prioritise the ring opponent
          bool targetIsRingOpponent = false;
          if (battleRingOpponent != null &&
              battleRingOpponent!.isAlive &&
              battleRing.inBattle) {
            final rd = (battleRingOpponent!.position - comp.position).distance;
            if (rd < nearestDist) {
              nearestDist = rd;
              targetIsRingOpponent = true;
            }
          }

          if (!targetIsRingOpponent) {
            for (final e in enemies) {
              if (e.dead) continue;
              final d = (e.position - comp.position).distance;
              if (d < nearestDist) {
                nearestDist = d;
                nearestEnemy = e;
              }
            }
          }

          // Also check boss
          if (!targetIsRingOpponent && activeBoss != null) {
            final bd = (activeBoss!.position - comp.position).distance;
            if (bd < nearestDist) {
              nearestEnemy = null; // handled separately below
              nearestDist = bd;
            }
          }

          if (targetIsRingOpponent ||
              nearestEnemy != null ||
              (activeBoss != null && nearestDist < engageRange)) {
            final targetPos = targetIsRingOpponent
                ? battleRingOpponent!.position
                : (nearestEnemy?.position ?? activeBoss!.position);
            // Face target (for sprite flipping & shooting direction)
            final toTarget = targetPos - comp.position;
            comp.angle = atan2(toTarget.dy, toTarget.dx);

            // If the target is out of special range, move toward it.
            final distToTarget = toTarget.distance;
            if (distToTarget > comp.specialAbilityRange) {
              final chaseSpeed = 100.0 + (comp.member.statSpeed * 10.0);
              final step = chaseSpeed * dt;
              comp.position +=
                  (toTarget / distToTarget) * min(step, distToTarget);
            }

            // Basic attack — family-specific pattern
            if (comp.basicCooldown <= 0 && distToTarget <= comp.attackRange) {
              comp.basicCooldown = comp.effectiveBasicCooldown;
              final basics = createFamilyBasicAttack(
                origin: comp.position,
                angle: comp.angle,
                element: comp.member.element,
                family: comp.member.family,
                damage: comp.physAtk.toDouble(),
              );
              companionProjectiles.addAll(basics);
            }

            // Special attack (every 30s base, scaled by cooldownReduction)
            // Each family has a unique ability, flavored by element!
            if (comp.specialCooldown <= 0 &&
                distToTarget <= comp.specialAbilityRange) {
              comp.specialCooldown = comp.effectiveSpecialCooldown;
              // Generate family+element special ability
              final result = createCosmicSpecialAbility(
                origin: comp.position,
                baseAngle: comp.angle,
                family: comp.member.family,
                element: comp.member.element,
                damage: comp.elemAtk * 2.0,
                maxHp: comp.maxHp,
                targetPos: targetPos,
              );
              companionProjectiles.addAll(result.projectiles);
              // Apply companion state changes from ability
              if (result.shieldHp > 0) comp.shieldHp = result.shieldHp;
              if (result.chargeTimer > 0) {
                comp.chargeTimer = result.chargeTimer;
                comp.chargeDamage = result.chargeDamage;
                comp.chargeTarget = targetPos;
              }
              if (result.selfHeal > 0) {
                comp.currentHp = min(
                  comp.maxHp,
                  comp.currentHp + result.selfHeal,
                );
              }
              if (result.blessingTimer > 0) {
                comp.blessingTimer = result.blessingTimer;
                comp.blessingHealPerTick = result.blessingHealPerTick;
              }
              // VFX burst
              _spawnHitSpark(comp.position, elementColor(comp.member.element));
            }
          } else {
            // No enemy — face wander direction
            comp.angle = comp.wanderAngle;
          }

          // Companion takes damage from enemies that touch it
          for (final e in enemies) {
            if (e.dead) continue;
            final d = (e.position - comp.position).distance;
            if (d < e.radius + 15) {
              final contactDmg = switch (e.tier) {
                EnemyTier.colossus => 25.0,
                EnemyTier.brute => 15.0,
                EnemyTier.phantom => 10.0,
                EnemyTier.sentinel => 8.0,
                EnemyTier.drone => 5.0,
                EnemyTier.wisp => 3.0,
              };
              final dmg = max(
                1,
                (contactDmg * 100 / (100 + comp.physDef)).round(),
              );
              comp.takeDamage(dmg);
              _spawnHitSpark(comp.position, elementColor(e.element));
            }
          }
        }
      }
    }

    // ── update battle ring opponent ──
    if (battleRingOpponent != null && battleRing.inBattle) {
      final opp = battleRingOpponent!;
      opp.life += dt;
      opp.invincibleTimer = (opp.invincibleTimer - dt).clamp(0.0, 10.0);
      _ringOpponentTicker?.update(dt);

      if (opp.currentHp <= 0) {
        // Ring opponent died — player wins
        _spawnKillVfx(
          opp.position,
          elementColor(opp.member.element),
          16,
          false,
        );
        dismissBattleRingOpponent();
        onBattleRingWon?.call();
      } else {
        // Wander near ring center
        opp.wanderTimer -= dt;
        if (opp.wanderTimer <= 0) {
          opp.wanderAngle = _rng.nextDouble() * 2 * pi;
          opp.wanderTimer = 2.0 + _rng.nextDouble();
        }
        final wanderTargetO = Offset(
          opp.anchorPosition.dx +
              cos(opp.wanderAngle) * CosmicCompanion.wanderRadius * 0.6,
          opp.anchorPosition.dy +
              sin(opp.wanderAngle) * CosmicCompanion.wanderRadius * 0.6,
        );
        final toWanderO = wanderTargetO - opp.position;
        final wanderDistO = toWanderO.distance;
        if (wanderDistO > 2.0) {
          final wanderSpeedO = 40.0 * dt;
          opp.position +=
              (toWanderO / wanderDistO) * min(wanderSpeedO, wanderDistO);
        }
        // Clamp within wander radius
        final fromAnchorO = opp.position - opp.anchorPosition;
        if (fromAnchorO.distance > CosmicCompanion.wanderRadius) {
          opp.position =
              opp.anchorPosition +
              (fromAnchorO / fromAnchorO.distance) *
                  CosmicCompanion.wanderRadius;
        }

        // Cooldowns
        opp.basicCooldown = (opp.basicCooldown - dt).clamp(0.0, 100.0);
        opp.specialCooldown = (opp.specialCooldown - dt).clamp(0.0, 100.0);

        // If we haven't spawned helper minions for this opponent yet,
        // check whether the opponent has dropped below half HP and
        // trigger the portal/orbital spawn then.
        if (!_ringMinionsSpawnedForCurrentOpponent &&
            battleRingOpponent != null &&
            battleRingOpponent!.currentHp <=
                (battleRingOpponent!.maxHp * 0.5)) {
          _spawnPendingRingMinions();
        }

        // Target the player's companion
        if (activeCompanion != null && activeCompanion!.isAlive) {
          final comp = activeCompanion!;
          final toComp = comp.position - opp.position;
          var distToComp = toComp.distance;
          opp.angle = atan2(toComp.dy, toComp.dx);

          if (opp.isBlessing) {
            opp.blessingTimer -= dt;
            opp.currentHp = min(
              opp.maxHp,
              opp.currentHp + (opp.blessingHealPerTick * dt).round(),
            );
          }

          var skipActions = false;
          if (opp.isCharging) {
            opp.chargeTimer -= dt;
            opp.chargeTarget = comp.position;
            final toTarget = opp.chargeTarget! - opp.position;
            final dist = toTarget.distance;
            if (dist > 10) {
              final step = CosmicCompanion.chargeSpeed * dt;
              opp.position += (toTarget / dist) * min(step, dist);
              opp.angle = atan2(toTarget.dy, toTarget.dx);
            } else {
              final dmg = max(
                1,
                (opp.chargeDamage * 100 / (100 + comp.physDef)).round(),
              );
              comp.takeDamage(dmg);
              _spawnHitSpark(comp.position, elementColor(opp.member.element));
              opp.chargeTimer = 0;
              opp.chargeTarget = null;
            }
            if (opp.chargeTimer > 0) {
              skipActions = true;
            } else {
              final refreshToComp = comp.position - opp.position;
              distToComp = refreshToComp.distance;
              opp.angle = atan2(refreshToComp.dy, refreshToComp.dx);
            }
          }

          if (!skipActions) {
            final engageRange = max(opp.attackRange, opp.specialAbilityRange);
            final toCompNow = comp.position - opp.position;
            distToComp = toCompNow.distance;
            // If the player's companion is out of engage range, move toward it.
            if (distToComp > engageRange) {
              final chaseSpeedOpp = 100.0 + (opp.member.statSpeed * 10.0);
              final stepOpp = chaseSpeedOpp * dt;
              opp.position +=
                  (toCompNow / distToComp) * min(stepOpp, distToComp);
            }

            // Basic attack
            if (distToComp <= opp.attackRange && opp.basicCooldown <= 0) {
              opp.basicCooldown = opp.effectiveBasicCooldown;
              final basics = createFamilyBasicAttack(
                origin: opp.position,
                angle: opp.angle,
                element: opp.member.element,
                family: opp.member.family,
                damage: opp.physAtk.toDouble(),
              );
              ringOpponentProjectiles.addAll(basics);
            }

            // Special attack
            if (distToComp <= opp.specialAbilityRange &&
                opp.specialCooldown <= 0) {
              opp.specialCooldown = opp.effectiveSpecialCooldown;
              final result = createCosmicSpecialAbility(
                origin: opp.position,
                baseAngle: opp.angle,
                family: opp.member.family,
                element: opp.member.element,
                damage: opp.elemAtk * 2.0,
                maxHp: opp.maxHp,
                targetPos: comp.position,
              );
              ringOpponentProjectiles.addAll(result.projectiles);
              if (result.shieldHp > 0) opp.shieldHp = result.shieldHp;
              if (result.chargeTimer > 0) {
                opp.chargeTimer = result.chargeTimer;
                opp.chargeDamage = result.chargeDamage;
                opp.chargeTarget = comp.position;
              }
              if (result.selfHeal > 0) {
                opp.currentHp = min(opp.maxHp, opp.currentHp + result.selfHeal);
              }
              if (result.blessingTimer > 0) {
                opp.blessingTimer = result.blessingTimer;
                opp.blessingHealPerTick = result.blessingHealPerTick;
              }
              _spawnHitSpark(opp.position, elementColor(opp.member.element));
            }
          }
        } else if (activeCompanion == null || !activeCompanion!.isAlive) {
          // Companion died during ring battle — player loses
          dismissBattleRingOpponent();
          onBattleRingLost?.call();
        }
      }
    }

    // ── update ring opponent projectiles ──
    for (var i = ringOpponentProjectiles.length - 1; i >= 0; i--) {
      final p = ringOpponentProjectiles[i];

      if (p.homing && activeCompanion != null && activeCompanion!.isAlive) {
        final target = activeCompanion!.position;
        final desired = atan2(
          target.dy - p.position.dy,
          target.dx - p.position.dx,
        );
        double diff = desired - p.angle;
        while (diff > pi) {
          diff -= 2 * pi;
        }
        while (diff < -pi) {
          diff += 2 * pi;
        }
        final maxTurn = p.homingStrength * dt;
        p.angle += diff.clamp(-maxTurn, maxTurn);
      }

      final pSpeed = Projectile.speed * p.speedMultiplier;

      // Handle orbital projectiles
      if (p.orbitCenter != null && p.orbitTime > 0) {
        p.orbitTime -= dt;
        p.orbitAngle += p.orbitSpeed * dt;
        p.orbitRadius += dt * 8.0;
        p.position = Offset(
          p.orbitCenter!.dx + cos(p.orbitAngle) * p.orbitRadius,
          p.orbitCenter!.dy + sin(p.orbitAngle) * p.orbitRadius,
        );
        if (p.orbitTime <= 0) {
          p.angle = atan2(
            p.position.dy - p.orbitCenter!.dy,
            p.position.dx - p.orbitCenter!.dx,
          );
          p.orbitCenter = null;
        }
      } else if (p.stationary) {
        // no movement
      } else {
        p.position = Offset(
          p.position.dx + cos(p.angle) * pSpeed * dt,
          p.position.dy + sin(p.angle) * pSpeed * dt,
        );
      }

      if (p.trailInterval > 0 && !p.stationary && p.orbitCenter == null) {
        p.trailTimer += dt;
        if (p.trailTimer >= p.trailInterval) {
          p.trailTimer -= p.trailInterval;
          ringOpponentProjectiles.add(
            Projectile(
              position: p.position,
              angle: 0,
              element: p.element,
              damage: p.trailDamage,
              life: p.trailLife,
              stationary: true,
              radiusMultiplier: 1.5,
              piercing: true,
              visualScale: 1.2,
            ),
          );
        }
      }

      if (p.clusterCount > 0 && !p.clustered && p.life < 0.75) {
        p.clustered = true;
        for (var ci = 0; ci < p.clusterCount; ci++) {
          final ca = ci * (pi * 2 / p.clusterCount);
          ringOpponentProjectiles.add(
            Projectile(
              position: Offset(
                p.position.dx + cos(ca) * 10,
                p.position.dy + sin(ca) * 10,
              ),
              angle: ca,
              element: p.element,
              damage: p.clusterDamage,
              life: 1.5,
              speedMultiplier: 0.7,
              radiusMultiplier: 1.5,
              piercing: true,
              visualScale: 1.0,
            ),
          );
        }
      }

      p.life -= dt;
      if (p.life <= 0) {
        ringOpponentProjectiles.removeAt(i);
        continue;
      }

      // Hit player's companion
      if (activeCompanion != null && activeCompanion!.isAlive) {
        final comp = activeCompanion!;
        final hitRadius = Projectile.radius * p.radiusMultiplier;
        final dx = p.position.dx - comp.position.dx;
        final dy = p.position.dy - comp.position.dy;
        if (dx * dx + dy * dy < (hitRadius + 15) * (hitRadius + 15)) {
          final pierceFalloff = p.piercing
              ? pow(0.7, p.pierceCount).toDouble()
              : 1.0;
          final dmg = max(
            1,
            (p.damage * pierceFalloff * 100 / (100 + comp.elemDef)).round(),
          );
          comp.takeDamage(dmg);
          _spawnHitSpark(
            p.position,
            elementColor(battleRingOpponent?.member.element ?? 'Earth'),
          );
          if (p.piercing) {
            p.pierceCount++;
          } else if (p.bounceCount > 0) {
            p.bounceCount--;
            p.pierceCount++;
            p.angle += pi * 0.65 + (_rng.nextDouble() * pi * 0.7);
          } else {
            ringOpponentProjectiles.removeAt(i);
          }
          continue;
        }
      }
    }

    _updateRingMinions(dt);

    // ── update companion projectiles ──
    for (var i = companionProjectiles.length - 1; i >= 0; i--) {
      final p = companionProjectiles[i];

      // Homing: steer toward nearest enemy
      if (p.homing) {
        double bestDist = double.infinity;
        Offset? bestTarget;
        for (final e in enemies) {
          if (e.dead) continue;
          final d = (e.position - p.position).distance;
          if (d < bestDist) {
            bestDist = d;
            bestTarget = e.position;
          }
        }
        // Also allow companion projectiles to home onto ring minions during a ring fight
        if (battleRing.inBattle) {
          for (final rm in ringMinions) {
            if (rm.dead) continue;
            final d = (rm.position - p.position).distance;
            if (d < bestDist) {
              bestDist = d;
              bestTarget = rm.position;
            }
          }
        }
        if (activeBoss != null) {
          final bd = (activeBoss!.position - p.position).distance;
          if (bd < bestDist) {
            bestTarget = activeBoss!.position;
          }
        }
        if (bestTarget != null) {
          final desired = atan2(
            bestTarget.dy - p.position.dy,
            bestTarget.dx - p.position.dx,
          );
          // Shortest-arc turn
          double diff = desired - p.angle;
          while (diff > pi) {
            diff -= 2 * pi;
          }
          while (diff < -pi) {
            diff += 2 * pi;
          }
          final maxTurn = p.homingStrength * dt;
          p.angle += diff.clamp(-maxTurn, maxTurn);
        }
      }

      final pSpeed = Projectile.speed * p.speedMultiplier;

      // Orbital projectiles: orbit their center before launching
      if (p.orbitCenter != null && p.orbitTime > 0) {
        p.orbitTime -= dt;
        p.orbitAngle += p.orbitSpeed * dt;
        p.orbitRadius += dt * 8.0; // slowly expand orbit
        p.position = Offset(
          p.orbitCenter!.dx + cos(p.orbitAngle) * p.orbitRadius,
          p.orbitCenter!.dy + sin(p.orbitAngle) * p.orbitRadius,
        );
        // When orbit time expires, launch outward
        if (p.orbitTime <= 0) {
          p.angle = p.orbitAngle; // launch in current orbital direction
          p.orbitCenter = null; // stop orbiting
        }
      } else if (p.stationary) {
        // Stationary projectiles don't move (mines, lingering clouds)
        // no position change
      } else {
        p.position = Offset(
          p.position.dx + cos(p.angle) * pSpeed * dt,
          p.position.dy + sin(p.angle) * pSpeed * dt,
        );
      }
      // Trail-dropping: spawn stationary residue projectiles periodically
      if (p.trailInterval > 0 && !p.stationary && p.orbitCenter == null) {
        p.trailTimer += dt;
        if (p.trailTimer >= p.trailInterval) {
          p.trailTimer -= p.trailInterval;
          companionProjectiles.add(
            Projectile(
              position: p.position,
              angle: 0,
              element: p.element,
              damage: p.trailDamage,
              life: p.trailLife,
              stationary: true,
              radiusMultiplier: 1.5,
              piercing: true,
              visualScale: 1.2,
            ),
          );
        }
      }

      // Cluster fragmentation: split into sub-projectiles at half-life
      if (p.clusterCount > 0 && !p.clustered) {
        // Estimate initial life by checking if we're past halfway
        // We trigger when remaining life < 50% of original
        // Since we don't store original life, trigger when life < 0.75s for meteors
        if (p.life < 0.75) {
          p.clustered = true;
          for (var ci = 0; ci < p.clusterCount; ci++) {
            final ca = ci * (pi * 2 / p.clusterCount);
            companionProjectiles.add(
              Projectile(
                position: Offset(
                  p.position.dx + cos(ca) * 10,
                  p.position.dy + sin(ca) * 10,
                ),
                angle: ca,
                element: p.element,
                damage: p.clusterDamage,
                life: 1.5,
                speedMultiplier: 0.7,
                radiusMultiplier: 1.5,
                piercing: true,
                visualScale: 1.0,
              ),
            );
          }
        }
      }

      p.life -= dt;
      if (p.life <= 0) {
        // If this is a decoy, spawn death explosion
        if (p.decoy && p.deathExplosionCount > 0) {
          _spawnDecoyExplosion(p);
        }
        companionProjectiles.removeAt(i);
        continue;
      }

      final hitRadius = Projectile.radius * p.radiusMultiplier;
      bool consumed = false;

      // Decoys/taunt traps resolve damage through the dedicated
      // enemy->decoy collision path so they persist as lures.
      if (p.decoy) {
        continue;
      }

      // Hit enemies
      for (var ei = enemies.length - 1; ei >= 0; ei--) {
        final enemy = enemies[ei];
        if (enemy.dead) continue;
        final edx = p.position.dx - enemy.position.dx;
        final edy = p.position.dy - enemy.position.dy;
        final hitR = enemy.radius + hitRadius;
        if (edx * edx + edy * edy < hitR * hitR) {
          // Piercing projectiles deal reduced damage after first hit
          final pierceFalloff = p.piercing
              ? pow(0.7, p.pierceCount).toDouble()
              : 1.0;
          enemy.health -= p.damage * pierceFalloff;
          _spawnHitSpark(p.position, elementColor(enemy.element));
          if (!enemy.provoked &&
              (enemy.behavior == EnemyBehavior.feeding ||
                  enemy.behavior == EnemyBehavior.territorial ||
                  enemy.behavior == EnemyBehavior.drifting)) {
            _provokePackOf(enemy);
          }
          if (p.piercing) {
            p.pierceCount++;
            // Don't consume — keep going
          } else if (p.bounceCount > 0) {
            // Ricochet: redirect toward nearest OTHER enemy
            p.bounceCount--;
            p.pierceCount++;
            double bestBounce = double.infinity;
            Offset? bounceTarget;
            for (final other in enemies) {
              if (other.dead || other == enemy) continue;
              final bd = (other.position - p.position).distance;
              if (bd < bestBounce && bd < 500) {
                bestBounce = bd;
                bounceTarget = other.position;
              }
            }
            if (bounceTarget != null) {
              p.angle = atan2(
                bounceTarget.dy - p.position.dy,
                bounceTarget.dx - p.position.dx,
              );
            } else {
              // No nearby target — bounce in a random direction
              p.angle += pi * 0.6 + Random().nextDouble() * pi * 0.8;
            }
            // Don't consume — keep going as a bounce
          } else {
            consumed = true;
          }
          if (enemy.health <= 0) {
            enemy.dead = true;
            _spawnKillVfx(
              enemy.position,
              elementColor(enemy.element),
              enemy.radius,
              false,
            );
            _spawnLootDrops(
              enemy.position,
              enemy.element,
              enemy.shardDrop,
              enemy.particleDrop,
            );
          }
          if (consumed) break;
        }
      }
      if (consumed) {
        companionProjectiles.removeAt(i);
        continue;
      }

      // Hit boss
      if (i < companionProjectiles.length && activeBoss != null) {
        final cp = companionProjectiles[i];
        final boss = activeBoss!;
        final bdx = cp.position.dx - boss.position.dx;
        final bdy = cp.position.dy - boss.position.dy;
        if (bdx * bdx + bdy * bdy <
            (boss.radius + hitRadius) * (boss.radius + hitRadius)) {
          final pierceFalloff = cp.piercing
              ? pow(0.7, cp.pierceCount).toDouble()
              : 1.0;
          if (boss.shieldUp && boss.type == BossType.gunner) {
            boss.shieldHealth -= cp.damage * pierceFalloff;
            _spawnHitSpark(cp.position, Colors.cyanAccent);
            if (boss.shieldHealth <= 0) {
              boss.shieldUp = false;
              boss.shieldTimer = CosmicBoss.shieldCooldown;
            }
          } else {
            boss.health -= cp.damage * pierceFalloff;
            _spawnHitSpark(cp.position, elementColor(boss.element));
            if (boss.health <= 0) {
              _handleBossKill(boss);
            }
          }
          if (cp.piercing) {
            cp.pierceCount++;
          } else {
            companionProjectiles.removeAt(i);
          }
        }
      }

      // Hit ring minions (when in a ring fight)
      if (i < companionProjectiles.length &&
          battleRing.inBattle &&
          ringMinions.isNotEmpty) {
        final cp = companionProjectiles[i];
        for (var ri = ringMinions.length - 1; ri >= 0; ri--) {
          final rm = ringMinions[ri];
          if (rm.dead) continue;
          final rdx = cp.position.dx - rm.position.dx;
          final rdy = cp.position.dy - rm.position.dy;
          final hitRadius = Projectile.radius * cp.radiusMultiplier;
          if (rdx * rdx + rdy * rdy <
              (rm.radius + hitRadius) * (rm.radius + hitRadius)) {
            final pierceFalloff = cp.piercing
                ? pow(0.7, cp.pierceCount).toDouble()
                : 1.0;
            final dmg = cp.damage * pierceFalloff;
            rm.health -= dmg;
            _spawnHitSpark(cp.position, elementColor(rm.element));
            if (cp.piercing) {
              cp.pierceCount++;
            } else {
              companionProjectiles.removeAt(i);
            }
            if (rm.health <= 0) {
              rm.dead = true;
              _spawnKillVfx(
                rm.position,
                elementColor(rm.element),
                rm.radius,
                false,
              );
            }
            break;
          }
        }
      }

      // Hit ring opponent
      if (i < companionProjectiles.length &&
          battleRingOpponent != null &&
          battleRingOpponent!.isAlive &&
          battleRing.inBattle) {
        final cp = companionProjectiles[i];
        final opp = battleRingOpponent!;
        final odx = cp.position.dx - opp.position.dx;
        final ody = cp.position.dy - opp.position.dy;
        if (odx * odx + ody * ody < (15 + hitRadius) * (15 + hitRadius)) {
          final pierceFalloff = cp.piercing
              ? pow(0.7, cp.pierceCount).toDouble()
              : 1.0;
          final dmg = max(
            1,
            (cp.damage * pierceFalloff * 100 / (100 + opp.elemDef)).round(),
          );
          opp.takeDamage(dmg);
          _spawnHitSpark(cp.position, elementColor(opp.member.element));
          if (cp.piercing) {
            cp.pierceCount++;
          } else {
            companionProjectiles.removeAt(i);
          }
        }
      }
    }

    // ── update garrison creatures (home-planet patrol & combat) ──
    if (homePlanet != null) {
      final hp = homePlanet!;
      final hpCenter = hp.position;
      // Patrol zone = beacon ring radius
      final patrolRadius = hp.visualRadius + 8.0;

      for (final g in _garrison) {
        g.ticker?.update(dt);
        g.attackCooldown = (g.attackCooldown - dt).clamp(0.0, 100.0);
        g.specialCooldown = (g.specialCooldown - dt).clamp(0.0, 100.0);

        // ── Horn charge: rush toward target, AoE on arrival ──
        if (g.chargeTimer > 0) {
          g.chargeTimer -= dt;
          if (g.chargeTarget != null) {
            final toTarget = g.chargeTarget! - g.position;
            final dist = toTarget.distance;
            if (dist > 10) {
              final step = 400.0 * dt;
              g.position += (toTarget / dist) * min(step, dist);
              g.faceAngle = atan2(toTarget.dy, toTarget.dx);
            } else {
              // AoE damage on arrival
              for (final e in enemies) {
                if (e.dead) continue;
                final d = (e.position - g.position).distance;
                if (d < 50) {
                  e.health -= g.chargeDamage;
                  _spawnHitSpark(e.position, elementColor(g.member.element));
                  if (!e.provoked) _provokePackOf(e);
                }
              }
              if (activeBoss != null) {
                final bd = (activeBoss!.position - g.position).distance;
                if (bd < 50) {
                  activeBoss!.health -= g.chargeDamage;
                  _spawnHitSpark(g.position, elementColor(g.member.element));
                }
              }
              g.chargeTimer = 0;
              g.chargeTarget = null;
            }
          }
          if (g.chargeTimer <= 0) g.chargeTarget = null;
        }

        // ── Kin blessing: heal over time ──
        if (g.blessingTimer > 0) {
          g.blessingTimer -= dt;
          g.hp = min(g.maxHp, g.hp + (g.blessingHealPerTick * dt).round());
        }

        // ── Find nearest enemy within engage range (basic or special) ──
        final engageRange = max(g.attackRange, g.specialRange);
        CosmicEnemy? nearestEnemy;
        double nearestDist = engageRange;
        for (final e in enemies) {
          if (e.dead) continue;
          final d = (e.position - g.position).distance;
          if (d < nearestDist) {
            nearestDist = d;
            nearestEnemy = e;
          }
        }
        // Also check boss
        if (activeBoss != null) {
          final bd = (activeBoss!.position - g.position).distance;
          if (bd < nearestDist) {
            nearestEnemy = null;
            nearestDist = bd;
          }
        }

        if (nearestEnemy != null ||
            (activeBoss != null && nearestDist < engageRange)) {
          // ── Chase & attack ──
          final targetPos = nearestEnemy?.position ?? activeBoss!.position;
          final toTarget = targetPos - g.position;
          g.faceAngle = atan2(toTarget.dy, toTarget.dx);

          // Move toward enemy only when outside special-cast range.
          if (toTarget.distance > g.specialRange) {
            final chaseSpeed = _GarrisonCreature.wanderSpeed * 3.5 * dt;
            g.position +=
                (toTarget / toTarget.distance) *
                min(chaseSpeed, toTarget.distance);
          }

          // Basic attack — family-specific pattern
          if (g.attackCooldown <= 0 && toTarget.distance <= g.attackRange) {
            g.attackCooldown = 1.2;
            final basics = createFamilyBasicAttack(
              origin: g.position,
              angle: g.faceAngle,
              element: g.member.element,
              family: g.member.family,
              damage: g.attackDamage,
            );
            companionProjectiles.addAll(basics);
          }

          // Special attack — family+element ability!
          if (g.specialCooldown <= 0 && toTarget.distance <= g.specialRange) {
            g.specialCooldown =
                (14.0 -
                        (g.member.statSpeed * 0.6) -
                        (g.member.statIntelligence * 0.4))
                    .clamp(6.0, 14.0);
            final result = createCosmicSpecialAbility(
              origin: g.position,
              baseAngle: g.faceAngle,
              family: g.member.family,
              element: g.member.element,
              damage: g.specialDamage,
              maxHp: g.maxHp,
              targetPos: targetPos,
            );
            companionProjectiles.addAll(result.projectiles);
            // Apply garrison state changes
            if (result.shieldHp > 0) g.shieldHp = result.shieldHp;
            if (result.chargeTimer > 0) {
              g.chargeTimer = result.chargeTimer;
              g.chargeDamage = result.chargeDamage;
              g.chargeTarget = targetPos;
            }
            if (result.selfHeal > 0) {
              g.hp = min(g.maxHp, g.hp + result.selfHeal);
            }
            if (result.blessingTimer > 0) {
              g.blessingTimer = result.blessingTimer;
              g.blessingHealPerTick = result.blessingHealPerTick;
            }
            _spawnHitSpark(g.position, elementColor(g.member.element));
          }
        } else {
          // ── No enemy — wander patrol ──
          g.faceAngle = g.wanderAngle;
          g.wanderAngle += (sin(_elapsed * 0.7 + g.position.dx) * 0.4) * dt;
          final wanderTarget = Offset(
            g.position.dx + cos(g.wanderAngle) * 40.0,
            g.position.dy + sin(g.wanderAngle) * 40.0,
          );
          final toW = wanderTarget - g.position;
          final wDist = toW.distance;
          if (wDist > 1.0) {
            final step = _GarrisonCreature.wanderSpeed * dt;
            g.position += (toW / wDist) * min(step, wDist);
          }
        }

        // Clamp within patrol zone (beacon ring) around home planet
        final fromCenter = g.position - hpCenter;
        if (fromCenter.distance > patrolRadius) {
          g.position =
              hpCenter + (fromCenter / fromCenter.distance) * patrolRadius;
        }
      }
    }

    // ── enemy spawning (random, scattered) — paused during battle ring ──
    if (!battleRing.inBattle) {
      _enemySpawnTimer += dt;
      if (_enemySpawnTimer >= _enemySpawnInterval &&
          enemies.length < _maxEnemies) {
        _enemySpawnTimer = 0;
        // ~70% chance each interval — enemies are common
        if (Random().nextDouble() < 0.7) {
          _spawnEnemy();
        }
      }

      // ── feeding pack spawn near asteroid belt ──
      _feedingPackTimer += dt;
      if (_feedingPackTimer >= _feedingPackInterval &&
          enemies.length < _maxEnemies - 2) {
        _feedingPackTimer = 0;
        // 40% chance — packs are moderately rare
        if (Random().nextDouble() < 0.4) {
          _spawnFeedingPack();
        }
      }
    } // end !battleRing.inBattle guard

    // ── enemy AI update ──
    for (var i = enemies.length - 1; i >= 0; i--) {
      final e = enemies[i];
      if (e.dead) {
        enemies.removeAt(i);
        continue;
      }
      _updateEnemyAI(e, dt);
    }

    // ── initial swarm clusters (seeded at first update) ──
    if (!_initialSwarmsSpawned) {
      _initialSwarmsSpawned = true;
      final swarmRng = Random(0x5A4E3D2C);
      // Spawn 6-8 swarm clusters scattered around the world
      final clusterCount = 6 + swarmRng.nextInt(3);
      for (int c = 0; c < clusterCount; c++) {
        final cx =
            2000.0 + swarmRng.nextDouble() * (world_.worldSize.width - 4000);
        final cy =
            2000.0 + swarmRng.nextDouble() * (world_.worldSize.height - 4000);
        _spawnSwarmCluster(center: Offset(cx, cy), rng: swarmRng);
      }
    }

    // ── periodic swarm cluster spawns ──
    _swarmSpawnTimer += dt;
    if (_swarmSpawnTimer >= _swarmSpawnInterval &&
        enemies.length < _maxEnemies) {
      _swarmSpawnTimer = 0;
      // 50% chance each interval — keeps the world populated
      if (Random().nextDouble() < 0.5) {
        _spawnSwarmCluster();
      }
    }

    // ── boss lair proximity check & respawn ──
    _updateBossLairs(dt);

    // ── random boss spawn (in addition to lairs) ──
    _bossSpawnTimer += dt;
    if (_bossSpawnTimer >= _bossSpawnInterval) {
      _bossSpawnTimer = 0;
      if (activeBoss == null && Random().nextDouble() < 0.25) {
        _spawnBoss();
      }
    }

    // ── boss AI update ──
    if (activeBoss != null) {
      if (activeBoss!.dead) {
        // Mark the lair as defeated
        for (final lair in bossLairs) {
          if (lair.state == BossLairState.fighting) {
            lair.state = BossLairState.defeated;
            lair.respawnTimer = BossLair.respawnDelay;
          }
        }
        activeBoss = null;
        bossProjectiles.clear(); // remove lingering projectiles
      } else {
        _updateBossAI(activeBoss!, dt);
      }
    }

    // ── boss projectile update ──
    _updateBossProjectiles(dt);

    // ── ship death / respawn ──
    if (_shipDead) {
      _respawnTimer -= dt;
      if (_respawnTimer <= 0) {
        _shipDead = false;
        shipHealth = shipMaxHealth;
        _shipInvincible = 3.0; // 3s invincibility on respawn
        // Clear nearby threats
        enemies.clear();
        activeBoss = null;
        bossProjectiles.clear();
        // Cancel any active whirl
        if (activeWhirl != null && activeWhirl!.state == WhirlState.active) {
          activeWhirl!.state = WhirlState.dormant;
          activeWhirl!.currentWave = 0;
          activeWhirl = null;
        }
        // Teleport home if home planet exists
        if (homePlanet != null) {
          final hp = homePlanet!;
          final hpR = hp.visualRadius;
          ship.pos = Offset(hp.position.dx + hpR + 60, hp.position.dy);
          _dragTarget = ship.pos;
          _revealAround(ship.pos, 300);
        }
      }
    }

    // ── ship invincibility cooldown ──
    if (_shipInvincible > 0) _shipInvincible -= dt;

    // ── enemy → decoy collision (enemies attack decoys) ──
    {
      final ww = world_.worldSize.width;
      final wh = world_.worldSize.height;
      for (final e in enemies) {
        if (e.dead) continue;
        // Passive enemies still engage if a taunt trap is actively luring them.
        if (!e.provoked &&
            (e.behavior == EnemyBehavior.feeding ||
                e.behavior == EnemyBehavior.drifting)) {
          var taunted = false;
          for (final cp in companionProjectiles) {
            if (!cp.decoy || cp.decoyHp <= 0 || cp.tauntRadius <= 0) continue;
            var tdx = cp.position.dx - e.position.dx;
            var tdy = cp.position.dy - e.position.dy;
            if (tdx > ww / 2) tdx -= ww;
            if (tdx < -ww / 2) tdx += ww;
            if (tdy > wh / 2) tdy -= wh;
            if (tdy < -wh / 2) tdy += wh;
            final dd = sqrt(tdx * tdx + tdy * tdy);
            if (dd <= cp.tauntRadius) {
              taunted = true;
              break;
            }
          }
          if (!taunted) continue;
        }
        for (var di = companionProjectiles.length - 1; di >= 0; di--) {
          final decoy = companionProjectiles[di];
          if (!decoy.decoy || decoy.decoyHp <= 0) continue;
          var ddx = decoy.position.dx - e.position.dx;
          var ddy = decoy.position.dy - e.position.dy;
          if (ddx > ww / 2) ddx -= ww;
          if (ddx < -ww / 2) ddx += ww;
          if (ddy > wh / 2) ddy -= wh;
          if (ddy < -wh / 2) ddy += wh;
          final hitR = e.radius + Projectile.radius * decoy.radiusMultiplier;
          if (ddx * ddx + ddy * ddy < hitR * hitR) {
            // Enemy damages the decoy
            final contactDmg = switch (e.tier) {
              EnemyTier.colossus => 5.0,
              EnemyTier.brute => 3.0,
              EnemyTier.phantom => 2.5,
              EnemyTier.sentinel => 2.0,
              EnemyTier.drone => 1.5,
              EnemyTier.wisp => 1.0,
            };
            decoy.decoyHp -= contactDmg;
            // Enemy takes damage from bumping into it
            e.health -= decoy.damage * 0.3;
            _spawnHitSpark(
              decoy.position,
              elementColor(decoy.element ?? 'Fire'),
            );
            if (e.health <= 0) {
              e.dead = true;
              _spawnKillVfx(
                e.position,
                elementColor(e.element),
                e.radius,
                false,
              );
              _spawnLootDrops(
                e.position,
                e.element,
                e.shardDrop,
                e.particleDrop,
              );
            }
            // Check if decoy died from this hit
            if (decoy.decoyHp <= 0) {
              _spawnDecoyExplosion(decoy);
              companionProjectiles.removeAt(di);
            }
            break; // one enemy hits one decoy per frame
          }
        }
      }
    }

    // ── enemy → ship collision (contact damage) ──
    if (!_shipDead && _shipInvincible <= 0) {
      for (final e in enemies) {
        if (e.dead) continue;
        // Passive enemies (feeding/drifting that aren't provoked) don't damage
        if (!e.provoked &&
            (e.behavior == EnemyBehavior.feeding ||
                e.behavior == EnemyBehavior.drifting)) {
          continue;
        }
        // Stalkers only attack when ship HP is low
        if (e.behavior == EnemyBehavior.stalking && shipHealth > 2.0) {
          continue;
        }
        final ww = world_.worldSize.width;
        final wh = world_.worldSize.height;
        var edx = ship.pos.dx - e.position.dx;
        var edy = ship.pos.dy - e.position.dy;
        if (edx > ww / 2) edx -= ww;
        if (edx < -ww / 2) edx += ww;
        if (edy > wh / 2) edy -= wh;
        if (edy < -wh / 2) edy += wh;
        final hitR = e.radius + 14; // ship collision radius ~14
        if (edx * edx + edy * edy < hitR * hitR) {
          final contactDmg = switch (e.tier) {
            EnemyTier.colossus => 4.0,
            EnemyTier.brute => 2.5,
            EnemyTier.phantom => 2.0,
            EnemyTier.sentinel => 1.5,
            EnemyTier.drone => 1.0,
            EnemyTier.wisp => 0.5,
          };
          _damageShip(contactDmg);
          e.dead = true;
          _spawnKillVfx(e.position, elementColor(e.element), e.radius, false);
          break; // only one hit per frame
        }
      }
    }

    // ── boss → ship collision ──
    if (!_shipDead &&
        _shipInvincible <= 0 &&
        activeBoss != null &&
        !activeBoss!.dead) {
      final boss = activeBoss!;
      final ww = world_.worldSize.width;
      final wh = world_.worldSize.height;
      var bdx = ship.pos.dx - boss.position.dx;
      var bdy = ship.pos.dy - boss.position.dy;
      if (bdx > ww / 2) bdx -= ww;
      if (bdx < -ww / 2) bdx += ww;
      if (bdy > wh / 2) bdy -= wh;
      if (bdy < -wh / 2) bdy += wh;
      final bHitR = boss.radius + 14;
      if (bdx * bdx + bdy * bdy < bHitR * bHitR) {
        _damageShip(2.0);
      }
    }

    // ── orbital gravity between home planet and nearby cosmic planet ──
    if (homePlanet != null && _orbitalPartner != null) {
      _orbitAngle += _orbitSpeed * dt;
      if (_homeOrbitsPartner) {
        // Home planet orbits the larger cosmic planet
        final oldHP = homePlanet!.position;
        final center = _orbitalPartner!.position;
        homePlanet!.position = _wrap(
          Offset(
            center.dx + cos(_orbitAngle) * _orbitRadius,
            center.dy + sin(_orbitAngle) * _orbitRadius,
          ),
        );
        // Shift orbital chambers by the same delta so they rigidly
        // follow the home planet's orbital motion instead of lagging.
        final hpDelta = homePlanet!.position - oldHP;
        for (final c in orbitalChambers) {
          c.position = _wrap(c.position + hpDelta);
        }
      } else {
        // Cosmic planet orbits the larger home planet
        final center = homePlanet!.position;
        _orbitalPartner!.position = _wrap(
          Offset(
            center.dx + cos(_orbitAngle) * _orbitRadius,
            center.dy + sin(_orbitAngle) * _orbitRadius,
          ),
        );
      }
    }

    // ── orbital chambers physics ──
    if (homePlanet != null && orbitalChambers.isNotEmpty) {
      final hpCentre = homePlanet!.position;
      for (final c in orbitalChambers) {
        c.update(dt, hpCentre);
        // Wrap to toroidal world
        c.position = _wrap(c.position);
      }
      // Chamber-chamber elastic collision
      for (var i = 0; i < orbitalChambers.length; i++) {
        for (var j = i + 1; j < orbitalChambers.length; j++) {
          final a = orbitalChambers[i];
          final b = orbitalChambers[j];
          final delta = b.position - a.position;
          final dist = delta.distance;
          final minDist = a.radius + b.radius;
          if (dist > 0 && dist < minDist) {
            final n = delta / dist;
            final push = (minDist - dist) * 0.6;
            a.position -= n * push * 0.5;
            b.position += n * push * 0.5;
            // Exchange velocity along normal
            final va = a.velocity.dx * n.dx + a.velocity.dy * n.dy;
            final vb = b.velocity.dx * n.dx + b.velocity.dy * n.dy;
            final impulse = (vb - va) * 0.75;
            a.velocity += n * impulse;
            b.velocity -= n * impulse;
            _spawnHitSpark(
              (a.position + b.position) / 2.0,
              Color.lerp(a.color, b.color, 0.5)!,
            );
          }
        }
      }
      // Chamber-ship collision (bounce off each other)
      if (!_shipDead) {
        for (final c in orbitalChambers) {
          final delta = ship.pos - c.position;
          final dist = delta.distance;
          final minDist = c.radius + 14.0; // ship radius ~14
          if (dist > 0 && dist < minDist) {
            final n = delta / dist;
            final push = (minDist - dist) * 0.6;
            c.position -= n * push;
            c.velocity -= n * 60.0; // gentle bounce away
            c.knocked = true;
            c.knockTimer = 0.5;
          }
        }
      }
    }

    // ── update VFX particles & rings ──
    for (var i = vfxParticles.length - 1; i >= 0; i--) {
      vfxParticles[i].update(dt);
      if (vfxParticles[i].dead) vfxParticles.removeAt(i);
    }
    for (var i = vfxRings.length - 1; i >= 0; i--) {
      vfxRings[i].update(dt);
      if (vfxRings[i].dead) vfxRings.removeAt(i);
    }

    // ── rift portal proximity ──
    _riftPulse += dt;
    {
      final ww = world_.worldSize.width;
      final wh = world_.worldSize.height;
      RiftPortal? closest;
      double closestDist = double.infinity;
      for (final rift in world_.riftPortals) {
        var rdx = rift.position.dx - ship.pos.dx;
        var rdy = rift.position.dy - ship.pos.dy;
        if (rdx > ww / 2) rdx -= ww;
        if (rdx < -ww / 2) rdx += ww;
        if (rdy > wh / 2) rdy -= wh;
        if (rdy < -wh / 2) rdy += wh;
        final d2 = rdx * rdx + rdy * rdy;
        final threshold = _wasNearRift
            ? RiftPortal.exitRadius
            : RiftPortal.interactRadius;
        if (d2 < threshold * threshold && d2 < closestDist) {
          closestDist = d2;
          closest = rift;
        }
      }
      _nearestRift = closest;
      final nowNear = closest != null;
      if (nowNear != _wasNearRift) {
        _wasNearRift = nowNear;
        onNearRift?.call(nowNear);
      }
    }

    // ── elemental nexus proximity ──
    {
      final nx = elementalNexus;
      var ndx = nx.position.dx - ship.pos.dx;
      var ndy = nx.position.dy - ship.pos.dy;
      if (ndx > ww / 2) ndx -= ww;
      if (ndx < -ww / 2) ndx += ww;
      if (ndy > wh / 2) ndy -= wh;
      if (ndy < -wh / 2) ndy += wh;
      final nd = sqrt(ndx * ndx + ndy * ndy);
      final threshold = _wasNearNexus
          ? ElementalNexus.exitRadius
          : ElementalNexus.interactRadius;
      final nowNearNexus = nd < threshold;
      if (nowNearNexus != _wasNearNexus) {
        _wasNearNexus = nowNearNexus;
        _isNearNexus = nowNearNexus;
        onNearNexus?.call(nowNearNexus);
      }
      // Discover on approach
      if (!nx.discovered && nd < ElementalNexus.interactRadius + 300) {
        nx.discovered = true;
      }
    }

    // ── battle ring proximity ──
    {
      final br = battleRing;
      var bdx = br.position.dx - ship.pos.dx;
      var bdy = br.position.dy - ship.pos.dy;
      if (bdx > ww / 2) bdx -= ww;
      if (bdx < -ww / 2) bdx += ww;
      if (bdy > wh / 2) bdy -= wh;
      if (bdy < -wh / 2) bdy += wh;
      final bd = sqrt(bdx * bdx + bdy * bdy);
      final threshold = _wasNearBattleRing
          ? BattleRing.exitRadius
          : BattleRing.interactRadius;
      final nowNearBR = bd < threshold;
      if (nowNearBR != _wasNearBattleRing) {
        _wasNearBattleRing = nowNearBR;
        _isNearBattleRing = nowNearBR;
        onNearBattleRing?.call(nowNearBR);
      }
      // Discover on approach
      if (!br.discovered && bd < BattleRing.interactRadius + 300) {
        br.discovered = true;
      }
    }

    // ── blood ring proximity ──
    {
      final ring = bloodRing;
      var bdx = ring.position.dx - ship.pos.dx;
      var bdy = ring.position.dy - ship.pos.dy;
      if (bdx > ww / 2) bdx -= ww;
      if (bdx < -ww / 2) bdx += ww;
      if (bdy > wh / 2) bdy -= wh;
      if (bdy < -wh / 2) bdy += wh;
      final bd = sqrt(bdx * bdx + bdy * bdy);
      final threshold = _wasNearBloodRing
          ? BloodRing.exitRadius
          : BloodRing.interactRadius;
      final nowNear = bd < threshold;
      if (nowNear != _wasNearBloodRing) {
        _wasNearBloodRing = nowNear;
        _isNearBloodRing = nowNear;
        onNearBloodRing?.call(nowNear);
      }
      if (!ring.discovered && bd < BloodRing.interactRadius + 300) {
        ring.discovered = true;
      }
    }

    // ── trait contest arena proximity ──
    {
      CosmicContestArena? closest;
      double closestDist = double.infinity;
      for (final arena in contestArenas) {
        var adx = arena.position.dx - ship.pos.dx;
        var ady = arena.position.dy - ship.pos.dy;
        if (adx > ww / 2) adx -= ww;
        if (adx < -ww / 2) adx += ww;
        if (ady > wh / 2) ady -= wh;
        if (ady < -wh / 2) ady += wh;
        final ad = sqrt(adx * adx + ady * ady);

        if (!arena.discovered && ad < CosmicContestArena.interactRadius + 320) {
          arena.discovered = true;
        }

        final threshold = nearContestArena == arena
            ? CosmicContestArena.exitRadius
            : CosmicContestArena.interactRadius;
        if (ad < threshold && ad < closestDist) {
          closestDist = ad;
          closest = arena;
        }
      }
      if (closest != nearContestArena) {
        nearContestArena = closest;
        onNearContestArena?.call(closest);
      }
    }

    // ── collectible contest hint notes ──
    for (final note in contestHintNotes) {
      if (note.collected) continue;
      var hdx = note.position.dx - ship.pos.dx;
      var hdy = note.position.dy - ship.pos.dy;
      if (hdx > ww / 2) hdx -= ww;
      if (hdx < -ww / 2) hdx += ww;
      if (hdy > wh / 2) hdy -= wh;
      if (hdy < -wh / 2) hdy += wh;
      final hd = sqrt(hdx * hdx + hdy * hdy);
      if (hd < CosmicContestHintNote.interactRadius) {
        note.collected = true;
        onContestHintCollected?.call(note);
      }
    }

    // ── galaxy whirl update ──
    for (final whirl in galaxyWhirls) {
      whirl.rotation += dt * 0.8;
      whirl.pulse += dt;
      if (whirl.state == WhirlState.completed) continue;

      // Check activation
      if (whirl.state == WhirlState.dormant && activeWhirl == null) {
        var wdx = whirl.position.dx - ship.pos.dx;
        var wdy = whirl.position.dy - ship.pos.dy;
        if (wdx > ww / 2) wdx -= ww;
        if (wdx < -ww / 2) wdx += ww;
        if (wdy > wh / 2) wdy -= wh;
        if (wdy < -wh / 2) wdy += wh;
        final wDist = sqrt(wdx * wdx + wdy * wdy);
        if (wDist < GalaxyWhirl.activationRadius) {
          whirl.state = WhirlState.active;
          whirl.currentWave = 0;
          whirl.enemiesSpawnedInWave = 0;
          whirl.enemiesAlive = 0;
          whirl.waveTimer = whirl.timeForWave(0);
          activeWhirl = whirl;
          onWhirlActivated?.call(whirl);
        }
      }
    }

    // Update active whirl
    if (activeWhirl != null && activeWhirl!.state == WhirlState.active) {
      final aw = activeWhirl!;
      final whirlIdx = galaxyWhirls.indexOf(aw);

      // Count living whirl enemies
      aw.enemiesAlive = enemies
          .where((e) => !e.dead && e.whirlIndex == whirlIdx)
          .length;

      // Spawn enemies for current wave
      final totalForWave = aw.enemiesForWave(aw.currentWave);
      if (aw.enemiesSpawnedInWave < totalForWave) {
        aw.spawnTimer += dt;
        if (aw.spawnTimer >= aw.waveSpawnInterval) {
          aw.spawnTimer = 0;
          _spawnWhirlEnemy(aw, whirlIdx);
          aw.enemiesSpawnedInWave++;
        }
      }

      // Count down wave timer
      aw.waveTimer -= dt;

      // Wave complete: all spawned and killed, OR timer ran out
      if ((aw.enemiesSpawnedInWave >= totalForWave && aw.enemiesAlive <= 0) ||
          aw.waveTimer <= 0) {
        onWhirlWaveComplete?.call(aw, aw.currentWave);
        aw.currentWave++;

        if (aw.currentWave >= aw.totalWaves) {
          // All waves complete — reward!
          aw.state = WhirlState.completed;
          activeWhirl = null;
          _spawnLootDrops(
            aw.position,
            aw.element,
            aw.shardReward,
            aw.particleReward,
          );
          // Item drops based on horde level
          _spawnWhirlItemDrops(aw);
          onWhirlComplete?.call(aw);
        } else {
          // Next wave
          aw.enemiesSpawnedInWave = 0;
          aw.waveTimer = aw.timeForWave(aw.currentWave);
          aw.spawnTimer = 0;
        }
      }
    }

    // ── prismatic field update ──
    prismaticField.life += dt;

    // Discover prismatic field when ship gets close
    if (!prismaticField.discovered) {
      final pfDist = (prismaticField.position - ship.pos).distance;
      if (pfDist < prismaticField.radius + 200) {
        prismaticField.discovered = true;
      }
    }

    // Check for prismatic celebration animation in progress
    if (_prismaticCelebTimer >= 0) {
      _prismaticCelebTimer += dt;
      final comp = activeCompanion;
      if (comp != null && _prismaticCelebCenter != null) {
        // Override companion movement: rapid orbit around the center
        final orbitProgress = (_prismaticCelebTimer / _prismaticCelebDuration)
            .clamp(0.0, 1.0);
        final orbitAngle = orbitProgress * pi * 6; // 3 full circles
        final orbitRadius = 80.0;
        comp.position = Offset(
          _prismaticCelebCenter!.dx + cos(orbitAngle) * orbitRadius,
          _prismaticCelebCenter!.dy + sin(orbitAngle) * orbitRadius,
        );
        comp.angle = orbitAngle + pi / 2; // face tangent direction
        comp.anchorPosition = comp.position; // prevent auto-return
        comp.invincibleTimer = 0.5; // keep invincible during celebration

        // Sparkle trail VFX along the orbit
        if (_rng.nextDouble() < 0.6) {
          final trailColor = PrismaticField
              .auroraColors[_rng.nextInt(PrismaticField.auroraColors.length)];
          vfxParticles.add(
            VfxParticle(
              x: comp.position.dx + (_rng.nextDouble() - 0.5) * 10,
              y: comp.position.dy + (_rng.nextDouble() - 0.5) * 10,
              vx: (_rng.nextDouble() - 0.5) * 40,
              vy: (_rng.nextDouble() - 0.5) * 40,
              life: 0.8,
              color: trailColor,
              size: 3 + _rng.nextDouble() * 3,
            ),
          );
        }
      }

      // Celebration complete — award 50 gold
      if (_prismaticCelebTimer >= _prismaticCelebDuration) {
        _prismaticCelebTimer = -1;
        prismaticRewardClaimed = true;
        prismaticField.rewardClaimed = true;

        final center = _prismaticCelebCenter ?? prismaticField.position;

        // Big VFX burst (gold-colored)
        for (int i = 0; i < 30; i++) {
          final a = _rng.nextDouble() * pi * 2;
          final s = 60 + _rng.nextDouble() * 120;
          vfxParticles.add(
            VfxParticle(
              x: center.dx,
              y: center.dy,
              vx: cos(a) * s,
              vy: sin(a) * s,
              life: 1.2,
              color: const Color(0xFFFFD700),
              size: 4 + _rng.nextDouble() * 5,
            ),
          );
        }
        vfxRings.add(
          VfxShockRing(
            x: center.dx,
            y: center.dy,
            maxRadius: 200,
            color: const Color(0xFFFFDD00),
          ),
        );

        _prismaticCelebCenter = null;
        onPrismaticRewardClaimed?.call();
      }
    }

    // Trigger celebration if prismatic companion enters the central ring
    if (!prismaticRewardClaimed &&
        _prismaticCelebTimer < 0 &&
        activeCompanion != null &&
        _companionVisuals?.isPrismatic == true) {
      final comp = activeCompanion!;
      final dist = (comp.position - prismaticField.position).distance;
      final ringR = prismaticField.radius * 0.12;
      if (dist < ringR + 30) {
        // Start celebration at the centre!
        _prismaticCelebTimer = 0;
        _prismaticCelebCenter = prismaticField.position;
      }
    }

    // ── space POI update ──
    for (final poi in spacePOIs) {
      poi.life += dt;

      // Hidden meteor-shower zone: encounter in-world, then relocate far away.
      if (poi.type == POIType.comet) {
        var cdx = poi.position.dx - ship.pos.dx;
        var cdy = poi.position.dy - ship.pos.dy;
        if (cdx > ww / 2) cdx -= ww;
        if (cdx < -ww / 2) cdx += ww;
        if (cdy > wh / 2) cdy -= wh;
        if (cdy < -wh / 2) cdy += wh;
        final cometDist = sqrt(cdx * cdx + cdy * cdy);

        if (!poi.discovered && cometDist < poi.radius + 300) {
          poi.discovered = true;
        }

        const encounterDuration = 10.0;
        const pulseEvery = 1.25;
        final insideShower = cometDist < poi.radius * 0.95;

        // Entering the shower starts a timed encounter (instead of instant relocate).
        if (insideShower && !poi.interacted) {
          poi.interacted = true;
          poi.speed = 0; // re-used as elapsed encounter time
          onPOIDiscovered?.call(poi);
          _spawnLootDrops(ship.pos, poi.element, 5, 5.5);
        }

        if (insideShower && poi.interacted) {
          final prevElapsed = poi.speed;
          final prevPulse = (prevElapsed / pulseEvery).floor();
          poi.speed += dt;
          final nextPulse = (poi.speed / pulseEvery).floor();

          if (nextPulse > prevPulse) {
            final burstRng = Random(
              nextPulse * 911 + poi.position.dx.toInt() ^
                  poi.position.dy.toInt(),
            );
            final a = burstRng.nextDouble() * 2 * pi;
            final r = poi.radius * (0.2 + burstRng.nextDouble() * 0.65);
            final burstPos = _wrap(
              Offset(
                poi.position.dx + cos(a) * r,
                poi.position.dy + sin(a) * r,
              ),
            );
            _spawnLootDrops(burstPos, poi.element, 4, 6.0);
          }

          if (prevElapsed < encounterDuration &&
              poi.speed >= encounterDuration) {
            _spawnLootDrops(ship.pos, poi.element, 10, 6.5);
          }
        }

        // Only relocate once the encounter has completed and the player leaves.
        if (poi.interacted &&
            !insideShower &&
            poi.speed >= encounterDuration &&
            cometDist > poi.radius * 1.2) {
          _relocateMeteorShower(poi);
        }
        continue;
      }

      if (poi.interacted) continue;

      // Markets use proximity detection (nearMarket), not one-shot interaction
      if (poi.type == POIType.harvesterMarket ||
          poi.type == POIType.riftKeyMarket ||
          poi.type == POIType.cosmicMarket ||
          poi.type == POIType.stardustScanner) {
        continue;
      }

      // Proximity check
      var pdx2 = poi.position.dx - ship.pos.dx;
      var pdy2 = poi.position.dy - ship.pos.dy;
      if (pdx2 > ww / 2) pdx2 -= ww;
      if (pdx2 < -ww / 2) pdx2 += ww;
      if (pdy2 > wh / 2) pdy2 -= wh;
      if (pdy2 < -wh / 2) pdy2 += wh;
      final poiDist = sqrt(pdx2 * pdx2 + pdy2 * pdy2);

      if (!poi.discovered && poiDist < poi.radius + 200) {
        poi.discovered = true;
      }

      // Interaction check (ship must be close)
      if (poiDist < poi.radius * 0.8) {
        poi.interacted = true;
        onPOIDiscovered?.call(poi);

        switch (poi.type) {
          case POIType.nebula:
            if (!meter.isFull) {
              meter.add(poi.element, 8.0 * _meterPickupMultiplier);
              onMeterChanged();
            }
            break;
          case POIType.derelict:
            _spawnLootDrops(poi.position, poi.element, 8, 3.0);
            break;
          case POIType.comet:
            // Handled above as meteor-shower zone.
            break;
          case POIType.harvesterMarket:
          case POIType.riftKeyMarket:
          case POIType.cosmicMarket:
          case POIType.stardustScanner:
            // Markets are handled via nearMarket proximity, not one-shot.
            break;
          case POIType.warpAnomaly:
            final warpRng = Random();
            final newPos = Offset(
              2000 + warpRng.nextDouble() * (world_.worldSize.width - 4000),
              2000 + warpRng.nextDouble() * (world_.worldSize.height - 4000),
            );
            // Trigger warp flash animation
            _warpFlash = 1.0;
            ship.pos = newPos;
            _dragTarget = newPos;
            _revealAround(ship.pos, 300);
            break;
        }
      }
    }

    // ── periodic save ──
    onPeriodicSave?.call();
  }

  // ── render ─────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Pocket dimension takes over all rendering
    if (inNexusPocket) {
      _renderPocket(canvas);
      return;
    }

    final cx = camX;
    final cy = camY;
    final screenW = size.x;
    final screenH = size.y;

    canvas.save();
    canvas.translate(-cx, -cy);

    // ── background stars (spatial grid lookup) ──
    final starPaint = Paint();
    final minCX = ((cx / _starChunkSize).floor() - 1).clamp(0, _starGridW - 1);
    final maxCX = (((cx + screenW) / _starChunkSize).floor() + 1).clamp(
      0,
      _starGridW - 1,
    );
    final minCY = ((cy / _starChunkSize).floor() - 1).clamp(0, _starGridH - 1);
    final maxCY = (((cy + screenH) / _starChunkSize).floor() + 1).clamp(
      0,
      _starGridH - 1,
    );
    for (var gy = minCY; gy <= maxCY; gy++) {
      for (var gx = minCX; gx <= maxCX; gx++) {
        for (final star in _starGrid[gy * _starGridW + gx]) {
          final twinkle =
              0.5 + 0.5 * sin(_elapsed * star.twinkleSpeed + star.x * 0.01);
          starPaint.color = Colors.white.withValues(
            alpha: star.brightness * twinkle,
          );
          canvas.drawCircle(Offset(star.x, star.y), star.size, starPaint);
        }
      }
    }

    // ── element particles ──
    for (final p in elemParticles) {
      if (p.x < cx - 20 ||
          p.x > cx + screenW + 20 ||
          p.y < cy - 20 ||
          p.y > cy + screenH + 20) {
        continue;
      }

      final alpha = (p.life / 5.0).clamp(0.0, 1.0);
      final color = elementColor(p.element).withValues(alpha: alpha * 0.9);
      final glow = elementColor(p.element).withValues(alpha: alpha * 0.3);

      canvas.drawCircle(Offset(p.x, p.y), p.size + 3, Paint()..color = glow);
      canvas.drawCircle(Offset(p.x, p.y), p.size, Paint()..color = color);
    }

    if (_beautyContestCinematicActive) {
      final introFade = _beautyContestIntroActive
          ? Curves.easeOutCubic.transform(
              (_beautyContestIntroTimer / _beautyContestIntroDuration).clamp(
                0.0,
                1.0,
              ),
            )
          : 1.0;
      final center = _beautyContestCenter;
      if (_contestCinematicMode == _ContestCinematicMode.beauty) {
        final pulse = 0.5 + 0.5 * sin(_elapsed * 1.8);
        final haloR = 300.0 + 24.0 * sin(_elapsed * 0.9);
        final sweepR = 212.0 + 12.0 * sin(_elapsed * 1.6);

        canvas.drawCircle(
          center,
          haloR,
          Paint()
            ..color = const Color(
              0xFFF06292,
            ).withValues(alpha: (0.18 + pulse * 0.10) * introFade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
        );
        canvas.drawCircle(
          center,
          220,
          Paint()
            ..color = const Color(
              0xFF80DEEA,
            ).withValues(alpha: 0.14 * introFade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38),
        );
        canvas.drawCircle(
          center,
          170,
          Paint()
            ..shader = ui.Gradient.radial(center, 170, [
              const Color(
                0xFFFFF8E1,
              ).withValues(alpha: (0.16 + pulse * 0.06) * introFade),
              Colors.transparent,
            ]),
        );
        for (var i = 0; i < 10; i++) {
          final a = _elapsed * 0.26 + i * (pi * 2 / 10);
          final p = Offset(
            center.dx + cos(a) * sweepR,
            center.dy + sin(a) * sweepR * 0.58,
          );
          canvas.drawCircle(
            p,
            7.0 + 1.2 * sin(_elapsed * 2.2 + i),
            Paint()
              ..color = const Color(
                0xFFFFE082,
              ).withValues(alpha: 0.24 * introFade)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          );
        }
      } else if (_contestCinematicMode == _ContestCinematicMode.speed) {
        final pulse = 0.5 + 0.5 * sin(_elapsed * 2.2);
        const outerRx = 246.0;
        const outerRy = 138.0;
        const innerRx = 208.0;
        const innerRy = 114.0;
        final outerRect = Rect.fromCenter(
          center: center,
          width: outerRx * 2,
          height: outerRy * 2,
        );
        final innerRect = Rect.fromCenter(
          center: center,
          width: innerRx * 2,
          height: innerRy * 2,
        );

        canvas.drawOval(
          outerRect,
          Paint()
            ..color = const Color(
              0xFF4FC3F7,
            ).withValues(alpha: (0.26 + pulse * 0.10) * introFade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawOval(
          innerRect,
          Paint()
            ..color = const Color(
              0xFFB3E5FC,
            ).withValues(alpha: (0.20 + pulse * 0.08) * introFade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        for (var i = 0; i < 16; i++) {
          final a = _elapsed * 2.8 + i * (pi * 2 / 16);
          final p = Offset(
            center.dx + cos(a) * (innerRx + 8),
            center.dy + sin(a) * (innerRy + 6),
          );
          canvas.drawCircle(
            p,
            2.6,
            Paint()
              ..color = const Color(
                0xFFE1F5FE,
              ).withValues(alpha: (0.16 + pulse * 0.08) * introFade),
          );
        }
      } else if (_contestCinematicMode == _ContestCinematicMode.strength) {
        final pulse = 0.5 + 0.5 * sin(_elapsed * 3.0);
        const laneHalfExtent = 118.0;
        final clashCenterBase = Offset(center.dx, center.dy + 24);
        final clashCenter = Offset(
          center.dx + _strengthContestShift,
          center.dy + 24,
        );
        final shiftNorm = (_strengthContestShift / laneHalfExtent).clamp(
          -1.0,
          1.0,
        );
        final markerColor = Color.lerp(
          const Color(0xFFFFAB91),
          const Color(0xFFFFCC80),
          ((shiftNorm + 1) / 2).clamp(0.0, 1.0),
        )!;
        final laneLeft = Offset(
          clashCenterBase.dx - laneHalfExtent,
          clashCenterBase.dy,
        );
        final laneRight = Offset(
          clashCenterBase.dx + laneHalfExtent,
          clashCenterBase.dy,
        );
        var markerPos = clashCenter;
        if (_beautyContestTimer >= _strengthContestDuration) {
          final revealT = Curves.easeOutCubic.transform(
            ((_beautyContestTimer - _strengthContestDuration) / 1.0).clamp(
              0.0,
              1.0,
            ),
          );
          final winner = _beautyContestPlayerWon
              ? activeCompanion
              : battleRingOpponent;
          if (winner != null) {
            markerPos = Offset.lerp(clashCenter, winner.position, revealT)!;
          }
        }

        // Strength lane + neutral alchemical center marker.
        canvas.drawLine(
          laneLeft,
          laneRight,
          Paint()
            ..color = const Color(
              0xFFFFE0B2,
            ).withValues(alpha: 0.08 * introFade)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawLine(
          laneLeft,
          laneRight,
          Paint()
            ..color = const Color(
              0xFFFFE0B2,
            ).withValues(alpha: 0.16 * introFade)
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );
        for (var i = 0; i < 8; i++) {
          final travel = (_elapsed * 0.24 + i / 8) % 1.0;
          final laneX = laneLeft.dx + (laneRight.dx - laneLeft.dx) * travel;
          final laneY = clashCenterBase.dy + sin(_elapsed * 2.8 + i) * 1.5;
          canvas.drawCircle(
            Offset(laneX, laneY),
            1.8 + (i % 2) * 0.5,
            Paint()
              ..color = const Color(
                0xFFFFF3E0,
              ).withValues(alpha: (0.10 + pulse * 0.06) * introFade)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
        canvas.drawCircle(
          clashCenterBase,
          16,
          Paint()
            ..color = const Color(
              0xFFFFF3E0,
            ).withValues(alpha: 0.24 * introFade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        final hexPath = Path();
        for (var i = 0; i < 6; i++) {
          final a = -pi / 2 + i * (pi * 2 / 6);
          final pt = Offset(
            clashCenterBase.dx + cos(a) * 8,
            clashCenterBase.dy + sin(a) * 8,
          );
          if (i == 0) {
            hexPath.moveTo(pt.dx, pt.dy);
          } else {
            hexPath.lineTo(pt.dx, pt.dy);
          }
        }
        hexPath.close();
        canvas.drawPath(
          hexPath,
          Paint()
            ..color = const Color(
              0xFFFFE0B2,
            ).withValues(alpha: 0.36 * introFade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );

        canvas.drawCircle(
          clashCenter,
          170,
          Paint()
            ..color = const Color(
              0xFFFFA65A,
            ).withValues(alpha: (0.13 + pulse * 0.08) * introFade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
        );
        canvas.drawCircle(
          clashCenter,
          108,
          Paint()
            ..color = const Color(
              0xFFFFE0B2,
            ).withValues(alpha: (0.08 + pulse * 0.06) * introFade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
        for (var i = 0; i < 12; i++) {
          final a = _elapsed * 2.4 + i * (pi * 2 / 12);
          final p = Offset(
            clashCenter.dx + cos(a) * 116,
            clashCenter.dy + sin(a) * 62,
          );
          canvas.drawCircle(
            p,
            4.0 + (i % 3) * 0.8,
            Paint()
              ..color = const Color(
                0xFFFFCC80,
              ).withValues(alpha: (0.15 + pulse * 0.06) * introFade),
          );
        }

        // Moving alchemical force marker tracks control of the center.
        canvas.drawCircle(
          markerPos,
          20,
          Paint()
            ..color = markerColor.withValues(
              alpha: (0.15 + pulse * 0.12) * introFade,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawCircle(
          markerPos,
          10.5,
          Paint()..color = markerColor.withValues(alpha: 0.92 * introFade),
        );
        canvas.drawCircle(
          markerPos,
          4,
          Paint()
            ..color = const Color(
              0xFFFFFFFF,
            ).withValues(alpha: 0.92 * introFade),
        );
      } else if (_contestCinematicMode == _ContestCinematicMode.intelligence) {
        final pulse = 0.5 + 0.5 * sin(_elapsed * 2.6);
        final latticeCenter = Offset(center.dx, center.dy + 16);
        final orbPos = _intelligenceContestOrbPos;
        final biasNorm = ((_intelligenceContestBias + 1.0) * 0.5).clamp(
          0.0,
          1.0,
        );
        final orbColor = Color.lerp(
          const Color(0xFF9FA8DA),
          const Color(0xFFD1C4E9),
          biasNorm,
        )!;

        canvas.drawCircle(
          latticeCenter,
          240,
          Paint()
            ..color = const Color(
              0xFF7E57C2,
            ).withValues(alpha: (0.14 + pulse * 0.07) * introFade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 46),
        );
        canvas.drawCircle(
          latticeCenter,
          146,
          Paint()
            ..color = const Color(
              0xFFB3E5FC,
            ).withValues(alpha: (0.08 + pulse * 0.04) * introFade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
        );

        for (var i = 0; i < 3; i++) {
          final radius = 62.0 + i * 44.0;
          canvas.drawCircle(
            latticeCenter,
            radius,
            Paint()
              ..color = const Color(
                0xFFD1C4E9,
              ).withValues(alpha: (0.09 - i * 0.02) * introFade)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }

        final nodePoints = <Offset>[];
        for (var i = 0; i < 10; i++) {
          final a = _elapsed * 0.78 + i * (pi * 2 / 10);
          final p = Offset(
            latticeCenter.dx + cos(a) * 168.0,
            latticeCenter.dy + sin(a) * 92.0,
          );
          nodePoints.add(p);
          canvas.drawCircle(
            p,
            2.8 + (i % 3) * 0.6,
            Paint()
              ..color = const Color(
                0xFFEDE7F6,
              ).withValues(alpha: (0.14 + pulse * 0.05) * introFade),
          );
          canvas.drawLine(
            p,
            orbPos,
            Paint()
              ..color = const Color(
                0xFFB39DDB,
              ).withValues(alpha: (0.08 + ((i % 4) * 0.01)) * introFade)
              ..strokeWidth = 1.0,
          );
        }
        for (var i = 0; i < nodePoints.length; i++) {
          final a = nodePoints[i];
          final b = nodePoints[(i + 2) % nodePoints.length];
          canvas.drawLine(
            a,
            b,
            Paint()
              ..color = const Color(
                0xFF9575CD,
              ).withValues(alpha: 0.06 * introFade)
              ..strokeWidth = 0.8,
          );
        }

        canvas.drawCircle(
          orbPos,
          32,
          Paint()
            ..color = orbColor.withValues(
              alpha: (0.22 + pulse * 0.09) * introFade,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
        canvas.drawCircle(
          orbPos,
          14,
          Paint()..color = orbColor.withValues(alpha: 0.95 * introFade),
        );
        canvas.drawCircle(
          orbPos,
          4.5,
          Paint()
            ..color = const Color(
              0xFFFFFFFF,
            ).withValues(alpha: 0.9 * introFade),
        );
      }
    }

    // ── particle swarms ──
    final ww3 = world_.worldSize.width;
    final wh3 = world_.worldSize.height;
    for (final swarm in world_.particleSwarms) {
      final elColor = elementColor(swarm.element);
      final pulseAlpha = 0.6 + 0.3 * sin(swarm.pulse * 1.8);

      for (final mote in swarm.motes) {
        if (mote.collected) continue;

        // World-space position
        var mx = swarm.center.dx + mote.offsetX;
        var my = swarm.center.dy + mote.offsetY;

        // Toroidal screen-space
        var relX = mx - cx;
        var relY = my - cy;
        if (relX > ww3 / 2) relX -= ww3;
        if (relX < -ww3 / 2) relX += ww3;
        if (relY > wh3 / 2) relY -= wh3;
        if (relY < -wh3 / 2) relY += wh3;
        mx = cx + relX;
        my = cy + relY;

        // Cull off-screen
        if (mx < cx - 20 ||
            mx > cx + screenW + 20 ||
            my < cy - 20 ||
            my > cy + screenH + 20) {
          continue;
        }

        // Gentle per-mote pulse using orbitPhase offset
        final moteAlpha =
            (pulseAlpha *
                    (0.7 + 0.3 * sin(swarm.pulse * 2.5 + mote.orbitPhase)))
                .clamp(0.0, 1.0);

        // Outer glow
        canvas.drawCircle(
          Offset(mx, my),
          mote.size + 4,
          Paint()
            ..color = elColor.withValues(alpha: moteAlpha * 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // Core
        canvas.drawCircle(
          Offset(mx, my),
          mote.size,
          Paint()..color = elColor.withValues(alpha: moteAlpha * 0.9),
        );
      }
    }

    // ── planets ──
    for (final pc in planetComps) {
      final planet = pc.planet;
      if ((planet.position.dx - cx - screenW / 2).abs() > screenW &&
          (planet.position.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      pc.render(canvas, _elapsed);
    }

    // ── star dust ──
    for (final dust in starDusts) {
      if (dust.collected) continue;
      final dp = dust.position;
      if ((dp.dx - cx - screenW / 2).abs() > screenW ||
          (dp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      // Outer glow
      final glowAlpha = 0.3 + 0.2 * sin(_elapsed * 2.0 + dust.index * 0.7);
      canvas.drawCircle(
        dp,
        14,
        Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: glowAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      // Core sparkle
      final coreAlpha = 0.7 + 0.3 * sin(_elapsed * 3.0 + dust.index * 1.3);
      canvas.drawCircle(
        dp,
        4,
        Paint()..color = const Color(0xFFFFFFE0).withValues(alpha: coreAlpha),
      );
      // Tiny rays
      final rayPaint = Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.25)
        ..strokeWidth = 1;
      for (var r = 0; r < 4; r++) {
        final a = _elapsed * 0.5 + r * pi / 2;
        canvas.drawLine(
          Offset(dp.dx + cos(a) * 6, dp.dy + sin(a) * 6),
          Offset(dp.dx + cos(a) * 14, dp.dy + sin(a) * 14),
          rayPaint,
        );
      }
    }

    // ── galaxy whirls ──
    for (final whirl in galaxyWhirls) {
      final wp = whirl.position;
      if ((wp.dx - cx - screenW / 2).abs() > screenW * 1.5 ||
          (wp.dy - cy - screenH / 2).abs() > screenH * 1.5) {
        continue;
      }

      final wColor = elementColor(whirl.element);
      final isActive = whirl.state == WhirlState.active;
      final isComplete = whirl.state == WhirlState.completed;
      final baseAlpha = isComplete ? 0.15 : (isActive ? 1.0 : 0.6);

      // Outer spiral arms
      for (var arm = 0; arm < 3; arm++) {
        final armOffset = arm * pi * 2 / 3;
        for (var i = 0; i < 20; i++) {
          final frac = i / 20.0;
          final spiralAngle = whirl.rotation + armOffset + frac * pi * 2.5;
          final spiralR = whirl.radius * (0.15 + frac * 0.85);
          final sx = wp.dx + cos(spiralAngle) * spiralR;
          final sy = wp.dy + sin(spiralAngle) * spiralR;
          final dotAlpha = (1.0 - frac) * 0.5 * baseAlpha;
          final dotSize = 2.5 + (1.0 - frac) * 2.0;
          canvas.drawCircle(
            Offset(sx, sy),
            dotSize,
            Paint()
              ..color = wColor.withValues(alpha: dotAlpha)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, dotSize),
          );
        }
      }

      // Core glow
      final coreSize = whirl.radius * (isActive ? 0.35 : 0.25);
      final corePulse = 0.8 + 0.2 * sin(whirl.pulse * 3);
      canvas.drawCircle(
        wp,
        coreSize * corePulse,
        Paint()
          ..color = wColor.withValues(alpha: 0.4 * baseAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, coreSize),
      );
      canvas.drawCircle(
        wp,
        coreSize * 0.4,
        Paint()..color = Colors.white.withValues(alpha: 0.5 * baseAlpha),
      );

      // Orbiting motes
      for (var m = 0; m < 8; m++) {
        final mAngle = whirl.rotation * 1.5 + m * pi / 4;
        final mR = whirl.radius * (0.5 + 0.3 * sin(whirl.pulse * 2 + m));
        canvas.drawCircle(
          Offset(wp.dx + cos(mAngle) * mR, wp.dy + sin(mAngle) * mR),
          2.0,
          Paint()..color = wColor.withValues(alpha: 0.6 * baseAlpha),
        );
      }

      // Status label / indicators
      if (isActive) {
        // Activation ring
        canvas.drawCircle(
          wp,
          GalaxyWhirl.activationRadius,
          Paint()
            ..color = wColor.withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        // Wave indicator
        final waveTp = TextPainter(
          text: TextSpan(
            text:
                'Lv${whirl.level} ${whirl.hordeTypeName} ${whirl.currentWave + 1}/${whirl.totalWaves}',
            style: TextStyle(
              color: wColor.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        waveTp.paint(
          canvas,
          Offset(wp.dx - waveTp.width / 2, wp.dy - whirl.radius - 20),
        );
        // Timer
        final timerSec = whirl.waveTimer.ceil();
        final timerTp = TextPainter(
          text: TextSpan(
            text: '${timerSec}s',
            style: TextStyle(
              color: timerSec <= 10
                  ? Colors.redAccent
                  : Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        timerTp.paint(
          canvas,
          Offset(wp.dx - timerTp.width / 2, wp.dy - whirl.radius - 34),
        );
      } else if (!isComplete) {
        final dormantTp = TextPainter(
          text: TextSpan(
            text: 'Lv${whirl.level} ${whirl.hordeTypeName}',
            style: TextStyle(
              color: wColor.withValues(alpha: 0.5),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        dormantTp.paint(
          canvas,
          Offset(wp.dx - dormantTp.width / 2, wp.dy + whirl.radius + 8),
        );
      } else {
        final completeTp = TextPainter(
          text: TextSpan(
            text: 'CLEARED',
            style: TextStyle(
              color: Colors.greenAccent.withValues(alpha: 0.6),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        completeTp.paint(
          canvas,
          Offset(wp.dx - completeTp.width / 2, wp.dy + whirl.radius + 8),
        );
      }
    }

    // ── prismatic field (aurora easter-egg) — hidden after reward claimed ──
    if (!prismaticRewardClaimed) {
      _renderPrismaticField(canvas, cx, cy, screenW, screenH);
    }

    // ── space POIs ──
    for (final poi in spacePOIs) {
      final pp = poi.position;
      if ((pp.dx - cx - screenW / 2).abs() > screenW * 1.5 ||
          (pp.dy - cy - screenH / 2).abs() > screenH * 1.5) {
        continue;
      }

      // All POI types stay visible after interaction (just dimmed)

      switch (poi.type) {
        case POIType.nebula:
          final nColor = elementColor(poi.element);
          final nAlpha = poi.interacted ? 0.24 : 0.3;
          for (var layer = 0; layer < 5; layer++) {
            final nR = poi.radius * (0.5 + layer * 0.3);
            final drift = sin(poi.life * 0.2 + layer * 0.8) * 15;
            canvas.drawCircle(
              Offset(pp.dx + drift, pp.dy + drift * 0.7),
              nR,
              Paint()
                ..color = nColor.withValues(
                  alpha: nAlpha * (1.0 - layer * 0.15),
                )
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, nR * 0.8),
            );
          }
          for (var s = 0; s < 6; s++) {
            final sa = poi.life * 0.3 + s * pi / 3;
            final sr = poi.radius * 0.4 * (0.5 + 0.5 * sin(poi.life + s));
            canvas.drawCircle(
              Offset(pp.dx + cos(sa) * sr, pp.dy + sin(sa) * sr),
              2,
              Paint()
                ..color = Colors.white.withValues(
                  alpha: 0.3 + 0.2 * sin(poi.life * 2 + s),
                ),
            );
          }
          if (!poi.interacted) {
            final nebTp = TextPainter(
              text: TextSpan(
                text: '${poi.element.toUpperCase()} NEBULA',
                style: TextStyle(
                  color: nColor.withValues(alpha: 0.6),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            nebTp.paint(
              canvas,
              Offset(pp.dx - nebTp.width / 2, pp.dy + poi.radius + 10),
            );
          }
          break;
        case POIType.derelict:
          final dAlphaScale = poi.interacted ? 0.7 : 1.0;
          // Ambient distress beacon glow
          if (!poi.interacted) {
            final beaconPulse = 0.15 + 0.1 * sin(poi.life * 2.5);
            canvas.drawCircle(
              pp,
              45,
              Paint()
                ..color = const Color(0xFFFF6F00).withValues(alpha: beaconPulse)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
            );
          }
          canvas.save();
          canvas.translate(pp.dx, pp.dy);
          canvas.rotate(sin(poi.life * 0.1) * 0.15);

          // Main hull (larger)
          final hullPath = Path()
            ..moveTo(-22, -12)
            ..lineTo(18, -10)
            ..lineTo(28, -2)
            ..lineTo(24, 6)
            ..lineTo(14, 12)
            ..lineTo(-8, 10)
            ..lineTo(-18, 8)
            ..lineTo(-26, 2)
            ..close();
          // Hull shadow
          canvas.drawPath(
            hullPath,
            Paint()
              ..color = const Color(
                0xFF37474F,
              ).withValues(alpha: 0.8 * dAlphaScale),
          );
          // Hull gradient overlay for depth
          canvas.drawPath(
            hullPath,
            Paint()
              ..shader = ui.Gradient.linear(
                const Offset(-22, -12),
                const Offset(24, 12),
                [
                  const Color(0xFF607D8B).withValues(alpha: 0.5 * dAlphaScale),
                  const Color(0xFF263238).withValues(alpha: 0.6 * dAlphaScale),
                ],
              ),
          );
          // Hull edge
          canvas.drawPath(
            hullPath,
            Paint()
              ..color = const Color(
                0xFF90A4AE,
              ).withValues(alpha: 0.5 * dAlphaScale)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );

          // Broken wing / fin piece (detached)
          final finPath = Path()
            ..moveTo(-10, -14)
            ..lineTo(-4, -20)
            ..lineTo(6, -18)
            ..lineTo(2, -12)
            ..close();
          canvas.drawPath(
            finPath,
            Paint()
              ..color = const Color(
                0xFF546E7A,
              ).withValues(alpha: 0.6 * dAlphaScale),
          );
          canvas.drawPath(
            finPath,
            Paint()
              ..color = const Color(
                0xFF90A4AE,
              ).withValues(alpha: 0.3 * dAlphaScale)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );

          // Damage scorch marks
          canvas.drawLine(
            const Offset(-5, -6),
            const Offset(8, 2),
            Paint()
              ..color = const Color(
                0xFF1B1B1B,
              ).withValues(alpha: 0.4 * dAlphaScale)
              ..strokeWidth = 1.5
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            const Offset(10, -4),
            const Offset(18, 4),
            Paint()
              ..color = const Color(
                0xFF1B1B1B,
              ).withValues(alpha: 0.3 * dAlphaScale)
              ..strokeWidth = 1.0
              ..strokeCap = StrokeCap.round,
          );

          // Flickering fire/sparks (multiple points)
          final spark1 = sin(poi.life * 5) > 0.6;
          final spark2 = sin(poi.life * 3.7 + 1.5) > 0.5;
          if (spark1) {
            canvas.drawCircle(
              const Offset(8, -3),
              4,
              Paint()
                ..color = const Color(0xFFFF6F00).withValues(alpha: 0.6)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
            );
          }
          if (spark2) {
            canvas.drawCircle(
              const Offset(-12, 4),
              3,
              Paint()
                ..color = const Color(0xFFFFAB00).withValues(alpha: 0.4)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
            );
          }

          // Floating debris pieces
          for (var d = 0; d < 6; d++) {
            final da = poi.life * 0.12 + d * pi / 3;
            final dr = 30.0 + 8 * sin(poi.life * 0.25 + d);
            final debrisSize = 1.0 + (d % 3) * 0.8;
            canvas.drawCircle(
              Offset(cos(da) * dr, sin(da) * dr),
              debrisSize,
              Paint()..color = const Color(0xFF78909C).withValues(alpha: 0.4),
            );
          }

          // Small blinking red distress light
          if (!poi.interacted && sin(poi.life * 4) > 0.8) {
            canvas.drawCircle(
              const Offset(-20, -6),
              2.5,
              Paint()
                ..color = const Color(0xFFFF1744).withValues(alpha: 0.8)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
            );
          }

          canvas.restore();
          if (!poi.interacted) {
            final derelictTp = TextPainter(
              text: const TextSpan(
                text: 'DERELICT',
                style: TextStyle(
                  color: Color(0xCC90A4AE),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            derelictTp.paint(
              canvas,
              Offset(pp.dx - derelictTp.width / 2, pp.dy + 28),
            );
          }
          break;
        case POIType.comet:
          final mColor = elementColor(poi.element);
          final zoneR = poi.radius;
          final fallAngle = poi.angle + 0.35 * sin(poi.life * 0.2);
          final baseDir = Offset(cos(fallAngle), sin(fallAngle));

          // Broad atmospheric haze so it reads like a moving storm region.
          canvas.drawCircle(
            pp,
            zoneR * 0.9,
            Paint()
              ..color = mColor.withValues(alpha: 0.05)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, zoneR * 0.22),
          );
          canvas.drawCircle(
            pp,
            zoneR * 0.45,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.03)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, zoneR * 0.15),
          );

          // Meteors fly through one-after-another (not static floating dots).
          const slots = 14;
          const cycleSeconds = 14.0;
          final spacing = cycleSeconds / slots;
          final activeWindow =
              spacing * 0.72; // leaves a short gap between meteors
          final cycleT = poi.life % cycleSeconds;

          for (var i = 0; i < slots; i++) {
            var local = cycleT - i * spacing;
            if (local < 0) local += cycleSeconds;
            if (local > activeWindow) continue;

            final t = local / activeWindow; // 0..1 for this meteor life
            final smooth = t * t * (3 - 2 * t); // smoothstep
            final fade = t < 0.2
                ? (t / 0.2)
                : (t > 0.82 ? ((1 - t) / 0.18).clamp(0.0, 1.0) : 1.0);

            final lane = ((i * 37) % 100) / 100.0 * 2 - 1; // -1..1
            final laneAngle = fallAngle + lane * 0.32;
            final dir = Offset(cos(laneAngle), sin(laneAngle));
            final perp = Offset(-dir.dy, dir.dx);

            final travel = zoneR * 2.4;
            final lateral = lane * zoneR * 0.55;
            final start = pp - dir * (travel * 0.54) + perp * lateral;
            final head = start + dir * (travel * smooth);
            final tailLen = 70.0 + (i % 4) * 18.0;
            final tail = head - dir * tailLen;
            final alpha = (0.18 + (1 - t) * 0.52) * fade;

            canvas.drawLine(
              tail,
              head,
              Paint()
                ..color = mColor.withValues(alpha: alpha * 0.95)
                ..strokeWidth = 1.6 + (i % 2) * 0.5
                ..strokeCap = StrokeCap.round
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.8),
            );

            canvas.drawLine(
              head - dir * 16,
              head,
              Paint()
                ..color = Colors.white.withValues(alpha: alpha * 0.9)
                ..strokeWidth = 0.9
                ..strokeCap = StrokeCap.round
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
            );

            canvas.drawCircle(
              head,
              1.9 + (i % 2) * 0.5,
              Paint()
                ..color = Colors.white.withValues(alpha: alpha)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
            );
          }

          // Light drifting dust behind the active stream direction.
          for (var d = 0; d < 10; d++) {
            final drift =
                poi.life * (0.16 + d * 0.011) + d * 1.23 + baseDir.dx * 1.7;
            final r = zoneR * (0.22 + (d % 7) * 0.09);
            final p = Offset(
              pp.dx + cos(drift) * r,
              pp.dy + sin(drift * 1.2) * r * 0.7,
            );
            canvas.drawCircle(
              p,
              1.2 + (d % 3) * 0.35,
              Paint()..color = mColor.withValues(alpha: 0.12),
            );
          }
          break;
        case POIType.warpAnomaly:
          final wAlphaScale = poi.interacted ? 0.8 : 1.0;
          for (var ring = 0; ring < 4; ring++) {
            final anomR =
                poi.radius * (0.3 + ring * 0.25) + sin(poi.life * 3 + ring) * 5;
            canvas.drawCircle(
              pp,
              anomR,
              Paint()
                ..color = const Color(
                  0xFF7C4DFF,
                ).withValues(alpha: (0.12 - ring * 0.02) * wAlphaScale)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
            );
          }
          canvas.drawCircle(
            pp,
            poi.radius * 0.2,
            Paint()
              ..color = const Color(
                0xFFB388FF,
              ).withValues(alpha: 0.4 + 0.2 * sin(poi.life * 4))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
          if (!poi.interacted) {
            final anomTp = TextPainter(
              text: const TextSpan(
                text: 'ANOMALY',
                style: TextStyle(
                  color: Color(0x99B388FF),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            anomTp.paint(
              canvas,
              Offset(pp.dx - anomTp.width / 2, pp.dy + poi.radius + 10),
            );
          }
          break;
        case POIType.harvesterMarket:
        case POIType.riftKeyMarket:
        case POIType.cosmicMarket:
        case POIType.stardustScanner:
          final mColor = poi.type == POIType.harvesterMarket
              ? const Color(0xFFFFB300) // amber/gold
              : poi.type == POIType.riftKeyMarket
              ? const Color(0xFF7C4DFF) // purple
              : poi.type == POIType.cosmicMarket
              ? const Color(0xFF00E5FF) // cyan/teal for cosmic
              : const Color(0xFF9CCC65); // green for scanner
          // Rotating hexagonal station
          canvas.save();
          canvas.translate(pp.dx, pp.dy);
          canvas.rotate(poi.life * 0.15);
          // Outer hex
          final hexPath = Path();
          for (var i = 0; i < 6; i++) {
            final a = i * pi / 3;
            final hx = cos(a) * poi.radius * 0.7;
            final hy = sin(a) * poi.radius * 0.7;
            if (i == 0) {
              hexPath.moveTo(hx, hy);
            } else {
              hexPath.lineTo(hx, hy);
            }
          }
          hexPath.close();
          canvas.drawPath(
            hexPath,
            Paint()
              ..color = mColor.withValues(alpha: 0.15)
              ..style = PaintingStyle.fill,
          );
          canvas.drawPath(
            hexPath,
            Paint()
              ..color = mColor.withValues(alpha: 0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
          // Inner glow
          canvas.drawCircle(
            Offset.zero,
            poi.radius * 0.3,
            Paint()
              ..color = mColor.withValues(alpha: 0.3 + 0.15 * sin(poi.life * 2))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
          // Center icon dot
          canvas.drawCircle(
            Offset.zero,
            4,
            Paint()..color = Colors.white.withValues(alpha: 0.8),
          );
          // Orbiting sparkles
          for (var s = 0; s < 4; s++) {
            final sa = poi.life * 0.5 + s * pi / 2;
            final sr = poi.radius * 0.5;
            canvas.drawCircle(
              Offset(cos(sa) * sr, sin(sa) * sr),
              1.5,
              Paint()
                ..color = mColor.withValues(
                  alpha: 0.5 + 0.3 * sin(poi.life * 3 + s),
                ),
            );
          }
          canvas.restore();
          // Label
          final marketLabel = poi.type == POIType.harvesterMarket
              ? 'HARVESTER SHOP'
              : poi.type == POIType.riftKeyMarket
              ? 'RIFT KEY SHOP'
              : poi.type == POIType.cosmicMarket
              ? 'COSMIC MARKET'
              : 'STAR DUST SCANNER';
          final mTp = TextPainter(
            text: TextSpan(
              text: marketLabel,
              style: TextStyle(
                color: mColor.withValues(alpha: 0.7),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          mTp.paint(
            canvas,
            Offset(pp.dx - mTp.width / 2, pp.dy + poi.radius * 0.8 + 8),
          );
          break;
      }
    }

    // ── rift portal ──
    // ── rift portals (all 5) ──
    for (final rift in world_.riftPortals) {
      final rp = rift.position;
      if ((rp.dx - cx - screenW / 2).abs() < screenW * 1.5 &&
          (rp.dy - cy - screenH / 2).abs() < screenH * 1.5) {
        final col = rift.color;
        final core = rift.coreColor;
        // Outer glow
        canvas.drawCircle(
          rp,
          48,
          Paint()
            ..color = col.withValues(alpha: 0.08)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );
        // Dark void core
        canvas.drawCircle(rp, 28, Paint()..color = core);
        // Pulsing rings (faction-coloured)
        for (var i = 0; i < 3; i++) {
          final ringR = 30.0 + i * 12 + 4 * sin(_riftPulse * 2 + i);
          canvas.drawCircle(
            rp,
            ringR,
            Paint()
              ..color = col.withValues(alpha: 0.3 - i * 0.08)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
        // Orbiting sparks
        for (var j = 0; j < 6; j++) {
          final a = _riftPulse * 1.2 + j * pi / 3;
          final sr = 36.0 + 8 * sin(_riftPulse * 3 + j);
          canvas.drawCircle(
            Offset(rp.dx + cos(a) * sr, rp.dy + sin(a) * sr),
            2.5,
            Paint()..color = col.withValues(alpha: 0.6),
          );
        }
      }
    }

    // ── elemental nexus (massive black portal – 5× scale, cached texture) ──
    {
      final nx = elementalNexus;
      final np = nx.position;
      if ((np.dx - cx - screenW / 2).abs() < screenW * 2.5 &&
          (np.dy - cy - screenH / 2).abs() < screenH * 2.5) {
        // Rebuild cached texture ~10 fps
        if (_nexusCachedImage == null ||
            (_riftPulse - _nexusCacheTime).abs() >= _nexusCacheInterval) {
          _nexusCachedImage?.dispose();
          _nexusCachedImage = _buildNexusTexture(_riftPulse);
          _nexusCacheTime = _riftPulse;
        }

        // Draw cached texture scaled to world coordinates
        final img = _nexusCachedImage!;
        const texR = _nexusTexWorldR;
        canvas.save();
        canvas.translate(np.dx - texR, np.dy - texR);
        canvas.scale(texR * 2 / _nexusTexSize, texR * 2 / _nexusTexSize);
        canvas.drawImage(img, Offset.zero, Paint());
        canvas.restore();

        // Label when close (cheap — drawn every frame)
        if (_isNearNexus || (np - ship.pos).distance < 400) {
          final textPainter = TextPainter(
            text: const TextSpan(
              text: 'NEXUS',
              style: TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            Offset(np.dx - textPainter.width / 2, np.dy + 70),
          );
        }
      }
    }

    // ── battle ring (octagonal arena – cached texture) ──
    {
      final br = battleRing;
      final bp = br.position;
      if ((bp.dx - cx - screenW / 2).abs() < screenW * 2.5 &&
          (bp.dy - cy - screenH / 2).abs() < screenH * 2.5) {
        // Rebuild cached texture ~10 fps
        if (_battleRingCachedImage == null ||
            (_riftPulse - _battleRingCacheTime).abs() >=
                _battleRingCacheInterval) {
          _battleRingCachedImage?.dispose();
          _battleRingCachedImage = _buildBattleRingTexture(_riftPulse);
          _battleRingCacheTime = _riftPulse;
        }

        // Draw cached texture scaled to world coordinates
        final img = _battleRingCachedImage!;
        const texR = _battleRingTexWorldR;
        canvas.save();
        canvas.translate(bp.dx - texR, bp.dy - texR);
        canvas.scale(
          texR * 2 / _battleRingTexSize,
          texR * 2 / _battleRingTexSize,
        );
        canvas.drawImage(img, Offset.zero, Paint());
        canvas.restore();

        // Label when nearby
        if (_isNearBattleRing || (bp - ship.pos).distance < 500) {
          final label = br.isCompleted ? 'BATTLE ARENA' : 'BATTLE RING';
          final textPainter = TextPainter(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            Offset(bp.dx - textPainter.width / 2, bp.dy + 80),
          );
        }
      }
    }

    // ── blood ring (ending ritual portal) ──
    {
      final ring = bloodRing;
      final rp = ring.position;
      if ((rp.dx - cx - screenW / 2).abs() < screenW * 2.5 &&
          (rp.dy - cy - screenH / 2).abs() < screenH * 2.5) {
        final pulse = 0.82 + 0.18 * sin(_riftPulse * 2.2);
        final outerR =
            BloodRing.visualRadius * (0.92 + 0.06 * sin(_riftPulse * 1.4));

        // Outer blood haze
        canvas.drawCircle(
          rp,
          outerR * 1.18,
          Paint()
            ..color = const Color(0xFF7F0000).withValues(alpha: 0.22 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
        );

        // Main ritual ring
        canvas.drawCircle(
          rp,
          outerR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10
            ..color = const Color(0xFFB71C1C).withValues(alpha: 0.8 * pulse),
        );

        // Inner ring
        canvas.drawCircle(
          rp,
          outerR * 0.72,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFFFCDD2).withValues(alpha: 0.5 * pulse),
        );

        // Orbiting ritual marks
        for (var i = 0; i < 8; i++) {
          final a = _riftPulse * 0.65 + (i * pi / 4);
          final markPos = Offset(
            rp.dx + cos(a) * (outerR + 24),
            rp.dy + sin(a) * (outerR + 24),
          );
          canvas.drawCircle(
            markPos,
            4.5,
            Paint()..color = const Color(0xFFFF8A80).withValues(alpha: 0.8),
          );
        }

        // Core state changes after ending completion.
        if (ring.ritualCompleted) {
          canvas.drawCircle(
            rp,
            outerR * 0.24,
            Paint()
              ..shader = ui.Gradient.radial(rp, outerR * 0.26, [
                const Color(0xFFB2EBF2).withValues(alpha: 0.85),
                const Color(0xFF1A0000).withValues(alpha: 0.0),
              ]),
          );
        } else {
          canvas.drawCircle(
            rp,
            outerR * 0.18,
            Paint()
              ..color = const Color(0xFF4A0000).withValues(alpha: 0.65 * pulse),
          );
        }

        if (_isNearBloodRing || (rp - ship.pos).distance < 550) {
          final label = ring.ritualCompleted ? 'BLOOD PORTAL' : 'BLOOD RING';
          final textPainter = TextPainter(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                color: Color(0x99FF8A80),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            Offset(rp.dx - textPainter.width / 2, rp.dy + outerR * 0.45),
          );
        }
      }
    }

    // ── trait contest arenas ──
    for (final arena in contestArenas) {
      final ap = arena.position;
      if ((ap.dx - cx - screenW / 2).abs() > screenW * 2.5 ||
          (ap.dy - cy - screenH / 2).abs() > screenH * 2.5) {
        continue;
      }

      final col = arena.trait.color;
      final pulse = 0.82 + 0.18 * sin(_riftPulse * 1.9 + arena.trait.index);

      canvas.drawCircle(
        ap,
        CosmicContestArena.visualRadius * 0.95,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = col.withValues(alpha: 0.42 * pulse),
      );
      canvas.drawCircle(
        ap,
        CosmicContestArena.visualRadius * 0.62,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = col.withValues(alpha: 0.76 * pulse),
      );
      canvas.drawCircle(
        ap,
        CosmicContestArena.visualRadius * 0.22,
        Paint()
          ..color = col.withValues(alpha: 0.28 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      if (nearContestArena == arena || (ap - ship.pos).distance < 520) {
        final labelPainter = TextPainter(
          text: TextSpan(
            text: arena.trait.arenaLabel.toUpperCase(),
            style: TextStyle(
              color: col.withValues(alpha: 0.86),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        labelPainter.paint(
          canvas,
          Offset(ap.dx - labelPainter.width / 2, ap.dy + 90),
        );
      }
    }

    // ── floating trait hint notes ──
    for (final note in contestHintNotes) {
      if (note.collected) continue;
      final np = note.position;
      if ((np.dx - cx - screenW / 2).abs() > screenW * 1.2 ||
          (np.dy - cy - screenH / 2).abs() > screenH * 1.2) {
        continue;
      }
      final nPulse = 0.5 + 0.5 * sin(_elapsed * 3.4 + note.id.hashCode * 0.01);
      canvas.drawCircle(
        np,
        18 + nPulse * 4,
        Paint()
          ..color = const Color(
            0xFFB3E5FC,
          ).withValues(alpha: 0.1 + nPulse * 0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        np,
        4,
        Paint()..color = const Color(0xFFE1F5FE).withValues(alpha: 0.9),
      );
    }

    // ── home planet ──
    if (homePlanet != null) {
      final hp = homePlanet!;
      final vr = hp.visualRadius;
      final hpPos = _wrappedRenderPos(hp.position, cx, cy, screenW, screenH);
      // Keep rendering longer so large outer cosmetics don't pop off-screen.
      final homeVisualMargin = vr * 4.5 + 240.0;
      if ((hpPos.dx - cx - screenW / 2).abs() < screenW + homeVisualMargin &&
          (hpPos.dy - cy - screenH / 2).abs() < screenH + homeVisualMargin) {
        final col = hp.blendedColor;

        // Warm aura
        canvas.drawCircle(
          hpPos,
          vr * 2.5,
          Paint()
            ..color = col.withValues(alpha: 0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
        );

        // ── Customization visual effects (rendered behind planet body) ──
        _renderHomeEffectsBehind(canvas, hpPos, vr, col);

        // Planet body — gradient sphere
        final bodyPaint = Paint()
          ..shader = ui.Gradient.radial(
            Offset(hpPos.dx - vr * 0.3, hpPos.dy - vr * 0.3),
            vr * 1.5,
            [
              Color.lerp(col, Colors.white, 0.35)!,
              col,
              Color.lerp(col, Colors.black, 0.5)!,
            ],
            [0.0, 0.5, 1.0],
          );
        canvas.drawCircle(hpPos, vr, bodyPaint);

        // ── Customization visual effects (rendered in front of planet) ──
        _renderHomeEffectsFront(canvas, hpPos, vr, col);

        // ── Garrison creatures inside planet ──
        for (final g in _garrison) {
          final eColor = elementColor(g.member.element);

          canvas.save();
          canvas.translate(g.position.dx, g.position.dy);

          // Subtle aura glow
          final auraPulse = 0.4 + 0.2 * sin(_elapsed * 2.5 + g.position.dx);
          canvas.drawCircle(
            Offset.zero,
            18 * g.spriteScale,
            Paint()
              ..color = eColor.withValues(alpha: auraPulse * 0.25)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );

          // ── Shield bubble (Horn special) ──
          if (g.shieldHp > 0) {
            final shieldPulse = 0.6 + 0.3 * sin(_elapsed * 5.0);
            canvas.drawCircle(
              Offset.zero,
              22 * g.spriteScale,
              Paint()
                ..color = eColor.withValues(alpha: shieldPulse * 0.35)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
            );
          }

          // ── Charge trail (Horn charging) ──
          if (g.chargeTimer > 0) {
            for (var t = 0; t < 4; t++) {
              final trailAngle = g.faceAngle + pi;
              final trailDist = 6.0 + t * 6.0;
              final tAlpha = (1.0 - t / 4.0) * 0.4;
              canvas.drawCircle(
                Offset(
                  cos(trailAngle) * trailDist,
                  sin(trailAngle) * trailDist,
                ),
                (4.0 - t) * g.spriteScale,
                Paint()
                  ..color = eColor.withValues(alpha: tAlpha)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
              );
            }
          }

          // ── Blessing aura (Kin healing) ──
          if (g.blessingTimer > 0) {
            final blessPulse = 0.5 + 0.4 * sin(_elapsed * 4.0);
            canvas.drawCircle(
              Offset.zero,
              16 * g.spriteScale,
              Paint()
                ..color = Colors.greenAccent.withValues(
                  alpha: blessPulse * 0.25,
                )
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
            );
          }

          if (g.ticker != null) {
            final sprite = g.ticker!.getSprite();
            final paint = Paint()..filterQuality = ui.FilterQuality.high;

            // Apply genetics color filter
            if (g.visuals != null) {
              final v = g.visuals!;
              final isAlbino = v.brightness == 1.45 && !v.isPrismatic;
              if (isAlbino) {
                paint.colorFilter = _albinoColorFilter(v.brightness);
              } else {
                paint.colorFilter = _geneticsColorFilter(v);
              }
            }

            // Render simple effect overlays for alchemy/variant effects (behind sprite)
            if (g.visuals?.alchemyEffect != null) {
              _drawAlchemyEffectCanvas(
                canvas: canvas,
                effect: g.visuals!.alchemyEffect!,
                spriteScale: g.spriteScale,
                baseSpriteSize: 40.0,
                variantFaction: g.visuals?.variantFaction,
                elapsed: _elapsed,
                opacity: 0.95,
              );
            }

            // Flip based on facing direction
            final facingRight = cos(g.faceAngle) > 0;
            canvas.save();
            if (facingRight) {
              canvas.scale(-g.spriteScale, g.spriteScale);
            } else {
              canvas.scale(g.spriteScale);
            }
            sprite.render(canvas, anchor: Anchor.center, overridePaint: paint);
            canvas.restore();
          } else {
            // Fallback: colored circle
            canvas.drawCircle(
              Offset.zero,
              10,
              Paint()..color = eColor.withValues(alpha: 0.8),
            );
          }

          canvas.restore();
        }

        // Home beacon ring
        final beaconAlpha = 0.3 + 0.2 * sin(_elapsed * 2.0);
        canvas.drawCircle(
          hpPos,
          vr + 8,
          Paint()
            ..color = const Color(0xFF00E5FF).withValues(alpha: beaconAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );

        // Label
        final homeLabel = TextPainter(
          text: TextSpan(
            text: 'HOME',
            style: TextStyle(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        homeLabel.paint(
          canvas,
          Offset(hpPos.dx - homeLabel.width / 2, hpPos.dy + vr + 12),
        );

        // ── Orbital path ring ──
        if (_orbitalPartner != null) {
          final center = _homeOrbitsPartner
              ? _wrappedRenderPos(
                  _orbitalPartner!.position,
                  cx,
                  cy,
                  screenW,
                  screenH,
                )
              : hpPos;
          // Dashed orbital ring
          final orbitPaint = Paint()
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawCircle(center, _orbitRadius, orbitPaint);
        }
      }
    }

    // ── orbital chambers ──
    for (final chamber in orbitalChambers) {
      // Skip empty (unassigned) chambers — no visual orb
      if (chamber.instanceId == null) continue;
      final cp = chamber.position;
      // Cull off-screen
      if ((cp.dx - cx - screenW / 2).abs() > screenW ||
          (cp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      final r = chamber.radius;
      final col = chamber.color;
      final pulse = 1.0 + sin(chamber.life * 1.5 + chamber.seed) * 0.15;

      // 1. Outer aura (pulsing glow)
      canvas.drawCircle(
        cp,
        r * 2.5 * pulse,
        Paint()
          ..color = col.withValues(alpha: 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.5),
      );

      // 2. Glass orb body — radial gradient sphere
      final bodyPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(cp.dx - r * 0.3, cp.dy - r * 0.3),
          r * 1.5,
          [
            Color.lerp(col, Colors.white, 0.25)!,
            col,
            Color.lerp(col, Colors.black, 0.4)!,
          ],
          [0.0, 0.65, 1.0],
        );
      canvas.drawCircle(cp, r, bodyPaint);

      // 2b. Creature sprite inside the orb (clipped to circle)
      if (chamber.imagePath != null &&
          _chamberSpriteCache.containsKey(chamber.imagePath)) {
        final img = _chamberSpriteCache[chamber.imagePath]!;
        canvas.save();
        final clipPath = Path()
          ..addOval(Rect.fromCircle(center: cp, radius: r * 0.85));
        canvas.clipPath(clipPath);
        // Draw creature image centered and scaled to fill the orb
        final imgSize = r * 1.7;
        final srcRect = Rect.fromLTWH(
          0,
          0,
          img.width.toDouble(),
          img.height.toDouble(),
        );
        final dstRect = Rect.fromCenter(
          center: cp,
          width: imgSize,
          height: imgSize,
        );
        canvas.drawImageRect(img, srcRect, dstRect, Paint());
        canvas.restore();
      }

      // 3. Inner core sparkle
      final coreAlpha = 0.5 + 0.3 * sin(chamber.life * 3.0 + chamber.seed * 2);
      canvas.drawCircle(
        cp,
        r * 0.25,
        Paint()..color = Colors.white.withValues(alpha: coreAlpha),
      );

      // 5. Orbit ring indicator (faint) when near home planet
      if (homePlanet != null) {
        final distToHome = (cp - homePlanet!.position).distance;
        if (distToHome < chamber.orbitDistance * 2) {
          final ringAlpha =
              (0.12 *
              (1.0 -
                  (distToHome / (chamber.orbitDistance * 2)).clamp(0.0, 1.0)));
          canvas.drawCircle(
            homePlanet!.position,
            chamber.orbitDistance,
            Paint()
              ..color = col.withValues(alpha: ringAlpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );
        }
      }
    }

    // ── asteroids ──
    // Rock colour palettes (indexed by shape for variety)
    const rockBaseColors = [
      Color(0xFF5D4037), // warm brown
      Color(0xFF616161), // grey
      Color(0xFF4E342E), // dark brown
    ];
    const rockLightColors = [
      Color(0xFF8D6E63), // light brown
      Color(0xFF9E9E9E), // light grey
      Color(0xFF795548), // medium brown
    ];
    const rockDarkColors = [
      Color(0xFF3E2723), // very dark brown
      Color(0xFF424242), // dark grey
      Color(0xFF321911), // almost black brown
    ];

    for (final rock in asteroidBelt.asteroids) {
      if (rock.destroyed) continue;
      final rp = rock.position;
      if ((rp.dx - cx - screenW / 2).abs() > screenW ||
          (rp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      canvas.save();
      canvas.translate(rp.dx, rp.dy);
      final spin = rock.rotation + _elapsed * rock.rotSpeed;
      canvas.rotate(spin);

      final si = rock.shape % 3;
      final healthFrac = rock.health.clamp(0.0, 1.0);
      final baseColor = Color.lerp(
        rockDarkColors[si],
        rockBaseColors[si],
        healthFrac,
      )!;
      final lightColor = rockLightColors[si];

      // Jagged shape
      final path = Path();
      final r = rock.radius;
      final int verts;
      switch (rock.shape) {
        case 0:
          verts = 5;
        case 1:
          verts = 6;
        default:
          verts = 8;
      }
      final offsets = <Offset>[];
      for (var i = 0; i < verts; i++) {
        final a = i * pi * 2 / verts;
        final rr =
            r *
            (0.7 +
                0.3 *
                    ((i.isEven ? 1.0 : 0.0) * 0.6 +
                        0.4 * (i % 3 == 0 ? 1.0 : 0.5)));
        final pt = Offset(cos(a) * rr, sin(a) * rr);
        offsets.add(pt);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();

      // Radial gradient fill for depth
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(r * -0.2, r * -0.25), // light source offset
            r * 1.4,
            [lightColor.withValues(alpha: 0.9), baseColor],
            [0.0, 1.0],
          ),
      );

      // Surface cracks / detail lines (for rocks radius > 8)
      if (r > 8) {
        // Two crack lines across the surface
        final crackPaint = Paint()
          ..color = rockDarkColors[si].withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round;
        // Crack 1: from vertex 0 towards center-ish
        canvas.drawLine(
          offsets[0] * 0.85,
          offsets[verts ~/ 2] * 0.3,
          crackPaint,
        );
        // Crack 2: perpendicular-ish
        canvas.drawLine(
          offsets[1] * 0.6,
          offsets[(verts * 3 ~/ 4).clamp(0, verts - 1)] * 0.5,
          crackPaint,
        );
        // Small crater dot
        canvas.drawCircle(
          Offset(r * 0.15, r * -0.1),
          r * 0.12,
          Paint()..color = rockDarkColors[si].withValues(alpha: 0.3),
        );
      }

      // Edge highlight (lit side)
      canvas.drawPath(
        path,
        Paint()
          ..color = lightColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Dark rim on shadow side (bottom-right)
      if (r > 6) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF000000).withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6,
        );
      }

      canvas.restore();
    }

    // ── loot drops ──
    for (final drop in lootDrops) {
      if (drop.collected) continue;
      final dp = drop.position;
      if ((dp.dx - cx - screenW / 2).abs() > screenW ||
          (dp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      final fadeAlpha = drop.life > LootDrop.maxLifetime - 5.0
          ? ((LootDrop.maxLifetime - drop.life) / 5.0).clamp(0.0, 1.0)
          : 1.0;
      final bob = sin(drop.life * 3.0 + drop.position.dx * 0.01) * 2.0;
      final drawPos = Offset(dp.dx, dp.dy + bob);

      switch (drop.type) {
        case LootType.astralShard:
          // Astral Shard — floating crystal with purple glow
          final shimmer = 0.6 + 0.4 * sin(drop.life * 4.0);
          final spin = drop.life * 2.5 + drop.position.dx * 0.02;
          // Outer glow
          canvas.drawCircle(
            drawPos,
            8,
            Paint()
              ..color = const Color(
                0xFF7C4DFF,
              ).withValues(alpha: 0.3 * fadeAlpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
          // Diamond shape
          canvas.save();
          canvas.translate(drawPos.dx, drawPos.dy);
          canvas.rotate(spin);
          final shardPath = Path()
            ..moveTo(0, -5)
            ..lineTo(3.5, 0)
            ..lineTo(0, 5)
            ..lineTo(-3.5, 0)
            ..close();
          canvas.drawPath(
            shardPath,
            Paint()
              ..shader =
                  ui.Gradient.linear(const Offset(-3, -5), const Offset(3, 5), [
                    Color.lerp(
                      const Color(0xFFB388FF),
                      Colors.white,
                      shimmer,
                    )!.withValues(alpha: fadeAlpha),
                    const Color(0xFF7C4DFF).withValues(alpha: fadeAlpha),
                  ]),
          );
          // Bright core
          canvas.drawCircle(
            Offset.zero,
            1.5,
            Paint()..color = Colors.white.withValues(alpha: 0.7 * fadeAlpha),
          );
          canvas.restore();
          break;
        case LootType.healthOrb:
          // Health orb — soft red glowing orb
          final hpPulse =
              0.9 + 0.2 * sin(drop.life * 4.5 + drop.position.dy * 0.02);
          canvas.drawCircle(
            drawPos,
            12,
            Paint()
              ..color = drop.color.withValues(alpha: 0.22 * fadeAlpha * hpPulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          );
          canvas.drawCircle(
            drawPos,
            6,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset(drawPos.dx - 1.0, drawPos.dy - 1.0),
                6,
                [
                  Color.lerp(
                    drop.color,
                    Colors.white,
                    0.45,
                  )!.withValues(alpha: fadeAlpha * hpPulse),
                  drop.color.withValues(alpha: fadeAlpha * hpPulse),
                ],
              ),
          );
          canvas.drawCircle(
            drawPos,
            2,
            Paint()..color = Colors.white.withValues(alpha: 0.85 * fadeAlpha),
          );
          break;
        case LootType.elementParticle:
          // Element orb — coloured glow
          final pulse =
              0.8 + 0.2 * sin(drop.life * 4.5 + drop.position.dy * 0.02);
          canvas.drawCircle(
            drawPos,
            10,
            Paint()
              ..color = drop.color.withValues(alpha: 0.25 * fadeAlpha * pulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
          canvas.drawCircle(
            drawPos,
            5,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset(drawPos.dx - 1.5, drawPos.dy - 1.5),
                6,
                [
                  Color.lerp(
                    drop.color,
                    Colors.white,
                    0.35,
                  )!.withValues(alpha: fadeAlpha * pulse),
                  drop.color.withValues(alpha: fadeAlpha * pulse),
                ],
              ),
          );
          // Tiny core
          canvas.drawCircle(
            drawPos,
            2,
            Paint()..color = Colors.white.withValues(alpha: 0.6 * fadeAlpha),
          );
          break;
        case LootType.item:
          // Item drop — pulsing hexagonal capsule with bright glow
          final pulse = 0.7 + 0.3 * sin(drop.life * 5.0);
          final spin = drop.life * 1.8;
          // Large outer glow
          canvas.drawCircle(
            drawPos,
            14,
            Paint()
              ..color = drop.color.withValues(alpha: 0.3 * fadeAlpha * pulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
          );
          // Hexagonal shape
          canvas.save();
          canvas.translate(drawPos.dx, drawPos.dy);
          canvas.rotate(spin);
          final hexPath = Path();
          for (var h = 0; h < 6; h++) {
            final ha = h * pi / 3 - pi / 6;
            final hp = Offset(cos(ha) * 6, sin(ha) * 6);
            if (h == 0) {
              hexPath.moveTo(hp.dx, hp.dy);
            } else {
              hexPath.lineTo(hp.dx, hp.dy);
            }
          }
          hexPath.close();
          canvas.drawPath(
            hexPath,
            Paint()
              ..shader =
                  ui.Gradient.linear(const Offset(-6, -6), const Offset(6, 6), [
                    Colors.white.withValues(alpha: 0.9 * fadeAlpha),
                    drop.color.withValues(alpha: fadeAlpha),
                  ]),
          );
          // Outline
          canvas.drawPath(
            hexPath,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.5 * fadeAlpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
          // Bright center star
          canvas.drawCircle(
            Offset.zero,
            2.5,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.9 * fadeAlpha * pulse),
          );
          canvas.restore();
          break;
      }
    }

    // ── enemies ──
    for (final e in enemies) {
      if (e.dead) continue;
      final ep = e.position;
      if ((ep.dx - cx - screenW / 2).abs() > screenW ||
          (ep.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      final eColor = elementColor(e.element);

      canvas.save();
      canvas.translate(ep.dx, ep.dy);

      // Outer elemental aura
      canvas.drawCircle(
        Offset.zero,
        e.radius * 2.0,
        Paint()
          ..color = eColor.withValues(alpha: 0.10)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, e.radius * 1.2),
      );

      if (e.tier == EnemyTier.wisp) {
        // Wisps: ethereal flickering orb with soft radial gradient
        final flicker = 0.7 + 0.3 * sin(_elapsed * 6 + e.angle * 5);
        final wobble = e.radius * flicker;
        canvas.drawCircle(
          Offset.zero,
          wobble,
          Paint()
            ..shader = ui.Gradient.radial(
              const Offset(-1, -1),
              wobble,
              [
                Colors.white.withValues(alpha: 0.7 * flicker),
                eColor.withValues(alpha: 0.5 * flicker),
                eColor.withValues(alpha: 0.0),
              ],
              [0.0, 0.5, 1.0],
            ),
        );
        // Tiny red dot at center — marks them as hostile
        canvas.drawCircle(
          Offset.zero,
          e.radius * 0.15,
          Paint()
            ..color = Colors.red.withValues(alpha: 0.9 * flicker)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
        );
      } else if (e.tier == EnemyTier.sentinel) {
        // Sentinels: round body with orbiting satellites
        final r = e.radius;

        // Main body — solid sphere with gradient
        canvas.drawCircle(
          Offset.zero,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(-r * 0.25, -r * 0.25),
              r * 1.2,
              [
                Color.lerp(eColor, Colors.white, 0.35)!.withValues(alpha: 0.9),
                eColor.withValues(alpha: 0.8),
                Color.lerp(eColor, Colors.black, 0.5)!.withValues(alpha: 0.7),
              ],
              [0.0, 0.5, 1.0],
            ),
        );

        // Specular highlight on sphere
        canvas.drawCircle(
          Offset(-r * 0.2, -r * 0.25),
          r * 0.3,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );

        // Orbiting ring track (faint ellipse)
        canvas.save();
        canvas.rotate(_elapsed * 0.3 + e.angle);
        final ringR = r * 1.8;
        canvas.drawCircle(
          Offset.zero,
          ringR,
          Paint()
            ..color = eColor.withValues(alpha: 0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );

        // 3 orbiting satellites at different speeds/phases
        for (var i = 0; i < 3; i++) {
          final orbitAngle = _elapsed * (1.2 + i * 0.4) + i * pi * 2 / 3;
          final ox = cos(orbitAngle) * ringR;
          final oy = sin(orbitAngle) * ringR;
          final satR = r * (0.18 + i * 0.04);

          // Satellite glow
          canvas.drawCircle(
            Offset(ox, oy),
            satR * 2,
            Paint()
              ..color = eColor.withValues(alpha: 0.2)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, satR),
          );

          // Satellite body
          canvas.drawCircle(
            Offset(ox, oy),
            satR,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset(ox - satR * 0.3, oy - satR * 0.3),
                satR,
                [
                  Colors.white.withValues(alpha: 0.7),
                  eColor.withValues(alpha: 0.8),
                ],
              ),
          );
        }
        canvas.restore();

        // Inner glow core
        canvas.drawCircle(
          Offset.zero,
          r * 0.25,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      } else if (e.tier == EnemyTier.drone) {
        // Drones: small angular hexagon, fast & twitchy
        final r = e.radius;
        final twitch = sin(_elapsed * 12 + e.angle * 7) * r * 0.08;

        // Hexagon body
        final hexPath = Path();
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3 - pi / 6; // flat-top hexagon
          final hr = r * (1.0 + (i.isEven ? twitch / r : -twitch / r));
          final hx = cos(a) * hr;
          final hy = sin(a) * hr;
          if (i == 0) {
            hexPath.moveTo(hx, hy);
          } else {
            hexPath.lineTo(hx, hy);
          }
        }
        hexPath.close();

        canvas.drawPath(
          hexPath,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, -r),
              Offset(0, r),
              [
                Color.lerp(eColor, Colors.white, 0.4)!.withValues(alpha: 0.9),
                eColor.withValues(alpha: 0.85),
                Color.lerp(eColor, Colors.black, 0.3)!.withValues(alpha: 0.7),
              ],
              [0.0, 0.5, 1.0],
            ),
        );

        // Sharp edge highlight
        canvas.drawPath(
          hexPath,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );

        // Central eye/core — bright flickering dot
        final eyePulse = 0.6 + 0.4 * sin(_elapsed * 8 + e.angle * 3);
        canvas.drawCircle(
          Offset.zero,
          r * 0.2,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9 * eyePulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );

        // Exhaust trail sparks (2 small behind)
        for (var s = 0; s < 2; s++) {
          final sparkAngle = e.angle + pi + (s - 0.5) * 0.4;
          final sparkDist = r * (1.2 + 0.3 * sin(_elapsed * 10 + s * 3));
          canvas.drawCircle(
            Offset(cos(sparkAngle) * sparkDist, sin(sparkAngle) * sparkDist),
            r * 0.12,
            Paint()
              ..color = eColor.withValues(alpha: 0.5 * eyePulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
      } else if (e.tier == EnemyTier.phantom) {
        // Phantoms: ghostly, semi-transparent with wispy tendrils
        final r = e.radius;
        final ghostPhase = _elapsed * 1.5 + e.angle * 2;
        final breathe = 1.0 + 0.12 * sin(ghostPhase);

        // Outer ghostly cloak — large soft blur
        canvas.drawCircle(
          Offset.zero,
          r * 1.6 * breathe,
          Paint()
            ..color = eColor.withValues(alpha: 0.06 + 0.03 * sin(ghostPhase))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8),
        );

        // Main body — translucent oval
        canvas.save();
        canvas.scale(0.8, 1.1 * breathe);
        canvas.drawCircle(
          Offset.zero,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(-r * 0.15, -r * 0.2),
              r * 1.2,
              [
                Colors.white.withValues(alpha: 0.25),
                eColor.withValues(alpha: 0.18),
                eColor.withValues(alpha: 0.04),
              ],
              [0.0, 0.4, 1.0],
            ),
        );
        canvas.restore();

        // Wispy tendrils trailing downward
        for (var t = 0; t < 4; t++) {
          final tAngle = t * pi / 2 + ghostPhase * 0.3;
          final tLen = r * (1.5 + 0.4 * sin(ghostPhase + t * 1.5));
          final tendril = Path()
            ..moveTo(cos(tAngle) * r * 0.4, sin(tAngle) * r * 0.4);

          final ctrlX = cos(tAngle + 0.3 * sin(ghostPhase + t)) * r * 1.0;
          final ctrlY = sin(tAngle + 0.3 * sin(ghostPhase + t)) * r * 1.0;
          tendril.quadraticBezierTo(
            ctrlX,
            ctrlY,
            cos(tAngle) * tLen,
            sin(tAngle) * tLen,
          );

          canvas.drawPath(
            tendril,
            Paint()
              ..color = eColor.withValues(
                alpha: 0.15 + 0.08 * sin(ghostPhase + t * 2),
              )
              ..strokeWidth = 1.5
              ..style = PaintingStyle.stroke
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }

        // Hollow eyes — two dim points
        final eyeSpread = r * 0.25;
        final eyeY = -r * 0.15;
        for (final ex in [-eyeSpread, eyeSpread]) {
          canvas.drawCircle(
            Offset(ex, eyeY),
            r * 0.1,
            Paint()
              ..color = Colors.white.withValues(
                alpha: 0.4 + 0.2 * sin(ghostPhase * 2),
              )
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
          );
        }
      } else if (e.tier == EnemyTier.colossus) {
        // Colossi: massive armored body with tentacle appendages + HP bar
        final r = e.radius;
        final pulse = 0.95 + 0.05 * sin(_elapsed * 1.2 + e.angle);

        // Armored core — large dark sphere with elemental tint
        canvas.drawCircle(
          Offset.zero,
          r * pulse,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(-r * 0.3, -r * 0.3),
              r * 1.5,
              [
                Color.lerp(eColor, Colors.white, 0.15)!.withValues(alpha: 0.85),
                Color.lerp(eColor, Colors.black, 0.3)!.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.7),
              ],
              [0.0, 0.4, 1.0],
            ),
        );

        // Tentacle appendages radiating outward
        for (var t = 0; t < 6; t++) {
          final baseAngle = t * pi / 3 + _elapsed * 0.08;
          final wave = sin(_elapsed * 1.5 + t * 1.2) * 0.3;
          final tentacle = Path()
            ..moveTo(cos(baseAngle) * r * 0.8, sin(baseAngle) * r * 0.8);

          final midDist = r * 1.6;
          final tipDist = r * (2.2 + 0.3 * sin(_elapsed * 0.8 + t));
          final ctrlAngle = baseAngle + wave;
          tentacle.quadraticBezierTo(
            cos(ctrlAngle) * midDist,
            sin(ctrlAngle) * midDist,
            cos(baseAngle + wave * 0.5) * tipDist,
            sin(baseAngle + wave * 0.5) * tipDist,
          );

          canvas.drawPath(
            tentacle,
            Paint()
              ..color = eColor.withValues(
                alpha: 0.35 + 0.15 * sin(_elapsed + t),
              )
              ..strokeWidth = 2.5 - t * 0.2
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }

        // Central maw — glowing core
        canvas.drawCircle(
          Offset.zero,
          r * 0.35,
          Paint()
            ..color = eColor.withValues(alpha: 0.4 + 0.2 * sin(_elapsed * 2))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.2),
        );
        canvas.drawCircle(
          Offset.zero,
          r * 0.15,
          Paint()..color = Colors.white.withValues(alpha: 0.5),
        );

        // Heavy pulsing aura
        canvas.drawCircle(
          Offset.zero,
          r * 1.5,
          Paint()
            ..color = eColor.withValues(alpha: 0.05)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
        );

        // Health bar (colossi are very tanky)
        final levHpFrac = (e.health / e.maxHealth).clamp(0.0, 1.0);
        if (levHpFrac < 1.0) {
          final barW = r * 3.0;
          final barH = 4.0;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(0, -r - 10),
                width: barW,
                height: barH,
              ),
              const Radius.circular(2),
            ),
            Paint()..color = Colors.black.withValues(alpha: 0.6),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                -barW / 2,
                -r - 10 - barH / 2,
                barW * levHpFrac,
                barH,
              ),
              const Radius.circular(2),
            ),
            Paint()..color = Color.lerp(Colors.red, eColor, levHpFrac)!,
          );
        }
      } else if (e.tier == EnemyTier.brute) {
        // Brutes: heavy armored body with elemental cracks
        final r = e.radius;

        // Dark armored body
        canvas.drawCircle(
          Offset.zero,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(-r * 0.2, -r * 0.2),
              r * 1.3,
              [
                Color.lerp(eColor, Colors.black, 0.3)!.withValues(alpha: 0.9),
                Color.lerp(eColor, Colors.black, 0.6)!.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.7),
              ],
              [0.0, 0.5, 1.0],
            ),
        );

        // Elemental cracks glowing through armor
        for (var crack = 0; crack < 5; crack++) {
          final ca = crack * pi * 2 / 5 + _elapsed * 0.2;
          final crackPath = Path()
            ..moveTo(0, 0)
            ..lineTo(cos(ca) * r * 0.9, sin(ca) * r * 0.9);
          canvas.drawPath(
            crackPath,
            Paint()
              ..color = eColor.withValues(
                alpha: 0.6 + 0.2 * sin(_elapsed * 2 + crack),
              )
              ..strokeWidth = 2.0
              ..style = PaintingStyle.stroke
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }

        // Heavy pulsing aura
        canvas.drawCircle(
          Offset.zero,
          r * 1.3,
          Paint()
            ..color = eColor.withValues(alpha: 0.08)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
        );

        // Health bar (brutes are tanky)
        final bruteHpFrac = (e.health / e.maxHealth).clamp(0.0, 1.0);
        if (bruteHpFrac < 1.0) {
          final barW = r * 2.5;
          final barH = 3.0;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(0, -r - 8),
                width: barW,
                height: barH,
              ),
              const Radius.circular(1.5),
            ),
            Paint()..color = Colors.black.withValues(alpha: 0.6),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                -barW / 2,
                -r - 8 - barH / 2,
                barW * bruteHpFrac,
                barH,
              ),
              const Radius.circular(1.5),
            ),
            Paint()..color = Color.lerp(Colors.red, eColor, bruteHpFrac)!,
          );
        }
      }

      canvas.restore();
    }

    // ── boss lairs (waiting markers) ──
    for (final lair in bossLairs) {
      if (lair.state != BossLairState.waiting) continue;
      final lp = lair.position;
      if ((lp.dx - cx - screenW / 2).abs() > screenW * 1.5 ||
          (lp.dy - cy - screenH / 2).abs() > screenH * 1.5) {
        continue;
      }

      final lColor = elementColor(lair.template.element);
      final pulse = 0.5 + 0.3 * sin(_elapsed * 2.0);

      // Ominous aura
      canvas.drawCircle(
        Offset(lp.dx, lp.dy),
        BossLair.activationRadius * 0.4,
        Paint()
          ..color = const Color(0xFFFF1744).withValues(alpha: 0.06 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );

      // Rotating diamond shape
      canvas.save();
      canvas.translate(lp.dx, lp.dy);
      canvas.rotate(_elapsed * 0.5);
      final diamondPath = Path()
        ..moveTo(0, -18)
        ..lineTo(14, 0)
        ..lineTo(0, 18)
        ..lineTo(-14, 0)
        ..close();
      canvas.drawPath(
        diamondPath,
        Paint()..color = lColor.withValues(alpha: 0.25 * pulse),
      );
      canvas.drawPath(
        diamondPath,
        Paint()
          ..color = const Color(0xFFFF1744).withValues(alpha: 0.4 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.restore();

      // Inner glow dot
      canvas.drawCircle(
        Offset(lp.dx, lp.dy),
        6,
        Paint()
          ..color = const Color(0xFFFF1744).withValues(alpha: 0.5 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        Offset(lp.dx, lp.dy),
        3,
        Paint()..color = lColor.withValues(alpha: 0.7),
      );

      // Level label
      final lairLabel = TextPainter(
        text: TextSpan(
          text: 'Lv${lair.level} ${lair.template.name}',
          style: TextStyle(
            color: const Color(0xFFFF5252).withValues(alpha: 0.7 * pulse),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      lairLabel.paint(canvas, Offset(lp.dx - lairLabel.width / 2, lp.dy + 22));
    }

    // ── boss ──
    if (activeBoss != null && !activeBoss!.dead) {
      final boss = activeBoss!;
      final bp = boss.position;
      if ((bp.dx - cx - screenW / 2).abs() < screenW * 1.2 &&
          (bp.dy - cy - screenH / 2).abs() < screenH * 1.2) {
        final bColor = elementColor(boss.element);

        canvas.save();
        canvas.translate(bp.dx, bp.dy);

        // Outer aura — breathing glow (warden enrage turns it red)
        final pulse = 0.8 + 0.2 * sin(_elapsed * 2.5);
        final auraColor = (boss.enraged)
            ? Color.lerp(bColor, Colors.red, 0.6)!
            : bColor;
        canvas.drawCircle(
          Offset.zero,
          boss.radius * 3.0 * pulse,
          Paint()
            ..color = auraColor.withValues(alpha: boss.enraged ? 0.12 : 0.06)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, boss.radius * 1.5),
        );
        // Secondary aura ring
        canvas.drawCircle(
          Offset.zero,
          boss.radius * 2.0 * pulse,
          Paint()
            ..color = auraColor.withValues(alpha: boss.enraged ? 0.15 : 0.08)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, boss.radius * 0.8),
        );

        // ── Charger: directional wedge indicator + charge trail ──
        if (boss.type == BossType.charger) {
          canvas.save();
          canvas.rotate(boss.angle);
          // Pointed wedge in front
          final wedge = Path()
            ..moveTo(boss.radius * 1.5, 0)
            ..lineTo(boss.radius * 0.4, -boss.radius * 0.5)
            ..lineTo(boss.radius * 0.4, boss.radius * 0.5)
            ..close();
          canvas.drawPath(
            wedge,
            Paint()
              ..color = bColor.withValues(alpha: boss.charging ? 0.8 : 0.3)
              ..maskFilter = boss.charging
                  ? const MaskFilter.blur(BlurStyle.normal, 4)
                  : null,
          );
          // Charge trail glow behind boss when dashing
          if (boss.charging) {
            canvas.drawCircle(
              Offset(-boss.radius * 1.5, 0),
              boss.radius * 0.8,
              Paint()
                ..color = bColor.withValues(alpha: 0.4)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
            );
          }
          canvas.restore();
        }

        // ── Gunner: shield ring ──
        if (boss.type == BossType.gunner && boss.shieldUp) {
          final shieldAlpha = (boss.shieldHealth / CosmicBoss.shieldMaxHealth)
              .clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset.zero,
            boss.radius * 1.6,
            Paint()
              ..color = Colors.cyanAccent.withValues(alpha: 0.2 * shieldAlpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
          canvas.drawCircle(
            Offset.zero,
            boss.radius * 1.4,
            Paint()
              ..color = Colors.cyanAccent.withValues(alpha: 0.5 * shieldAlpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
        }

        // Orbiting rune motes
        final moteCount = switch (boss.type) {
          BossType.charger => 4,
          BossType.gunner => 6,
          BossType.warden => 8,
        };
        for (var i = 0; i < moteCount; i++) {
          final moteA = _elapsed * 1.2 + i * pi * 2 / moteCount;
          final moteR = boss.radius * (1.3 + 0.15 * sin(_elapsed * 3 + i));
          final mp = Offset(cos(moteA) * moteR, sin(moteA) * moteR);
          canvas.drawCircle(
            mp,
            2.5,
            Paint()
              ..color = (boss.enraged ? Colors.red : bColor).withValues(
                alpha: 0.7,
              )
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }

        // Core body — radial gradient orb
        canvas.drawCircle(
          Offset.zero,
          boss.radius,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(-boss.radius * 0.2, -boss.radius * 0.2),
              boss.radius * 1.1,
              [
                Colors.white.withValues(alpha: 0.5 * pulse),
                Color.lerp(
                  bColor,
                  Colors.white,
                  0.2,
                )!.withValues(alpha: 0.8 * pulse),
                bColor.withValues(alpha: 0.6 * pulse),
                bColor.withValues(alpha: 0.0),
              ],
              [0.0, 0.25, 0.6, 1.0],
            ),
        );

        // Inner sigil — type determines complexity
        canvas.save();
        canvas.rotate(_elapsed * 0.6);
        final sigR = boss.radius * 0.55;
        canvas.drawCircle(
          Offset.zero,
          sigR,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
        // Star points scale with type
        final starPoints = switch (boss.type) {
          BossType.charger => 5,
          BossType.gunner => 7,
          BossType.warden => 9,
        };
        final sigPath = Path();
        for (var i = 0; i < starPoints; i++) {
          final a1 = i * pi * 2 / starPoints - pi / 2;
          final a2 = a1 + pi * 2 / starPoints * 3;
          final p1 = Offset(cos(a1) * sigR, sin(a1) * sigR);
          final p2 = Offset(cos(a2) * sigR, sin(a2) * sigR);
          sigPath.moveTo(p1.dx, p1.dy);
          sigPath.lineTo(p2.dx, p2.dy);
        }
        canvas.drawPath(
          sigPath,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
        // Warden: second inner inscribed ring when enraged
        if (boss.type == BossType.warden && boss.enraged) {
          canvas.drawCircle(
            Offset.zero,
            sigR * 0.6,
            Paint()
              ..color = Colors.red.withValues(alpha: 0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
        canvas.restore();

        // Health bar above boss
        final barWidth = boss.radius * 2.5;
        final barHeight = 4.0;
        final barY = -boss.radius - 14.0;
        final hpFrac = (boss.health / boss.maxHealth).clamp(0.0, 1.0);

        // Background
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(0, barY),
              width: barWidth,
              height: barHeight,
            ),
            const Radius.circular(2),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.6),
        );
        // Fill
        final fillW = barWidth * hpFrac;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              -barWidth / 2,
              barY - barHeight / 2,
              fillW,
              barHeight,
            ),
            const Radius.circular(2),
          ),
          Paint()..color = Color.lerp(Colors.red, bColor, hpFrac)!,
        );

        // Boss name + level + type
        final typeTag = switch (boss.type) {
          BossType.charger => '⚡',
          BossType.gunner => '🔫',
          BossType.warden => '👑',
        };
        final namePainter = TextPainter(
          text: TextSpan(
            text: '$typeTag Lv${boss.level} ${boss.name}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        namePainter.paint(
          canvas,
          Offset(-namePainter.width / 2, barY - barHeight - 14),
        );

        canvas.restore();
      }
    }

    // ── boss projectiles ──
    for (final bp in bossProjectiles) {
      final pp = bp.position;
      if ((pp.dx - cx - screenW / 2).abs() > screenW ||
          (pp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      final bpColor = elementColor(bp.element);
      // Glow
      canvas.drawCircle(
        pp,
        bp.radius * 2.5,
        Paint()
          ..color = bpColor.withValues(alpha: 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, bp.radius * 2),
      );
      // Core
      canvas.drawCircle(pp, bp.radius, Paint()..color = bpColor);
      // Bright center
      canvas.drawCircle(
        pp,
        bp.radius * 0.4,
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
    }

    // ── projectiles ──
    for (final p in projectiles) {
      final pp = p.position;
      if ((pp.dx - cx - screenW / 2).abs() > screenW ||
          (pp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }

      // Ammo color based on active customization
      final ammoColor = _ammoColor;
      // Glow trail
      canvas.drawCircle(
        pp,
        6,
        Paint()
          ..color = ammoColor.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Core bolt
      final tailX = pp.dx - cos(p.angle) * 10;
      final tailY = pp.dy - sin(p.angle) * 10;
      canvas.drawLine(
        Offset(tailX, tailY),
        pp,
        Paint()
          ..color = ammoColor
          ..strokeWidth = activeWeaponId == 'equip_machinegun' ? 1.5 : 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── homing missiles ──
    for (final m in _missiles) {
      final mp = m.position;
      if ((mp.dx - cx - screenW / 2).abs() > screenW ||
          (mp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }
      // Missile glow
      canvas.drawCircle(
        mp,
        10,
        Paint()
          ..color = const Color(0xFFFF6F00).withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // Missile body (small triangle)
      canvas.save();
      canvas.translate(mp.dx, mp.dy);
      canvas.rotate(m.angle + pi / 2);
      final missilePath = Path()
        ..moveTo(0, -6)
        ..lineTo(-3, 4)
        ..lineTo(3, 4)
        ..close();
      canvas.drawPath(missilePath, Paint()..color = const Color(0xFFFF8F00));
      // Exhaust trail
      canvas.drawCircle(
        const Offset(0, 6),
        3,
        Paint()
          ..color = const Color(0xFFFFAB40).withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.restore();
    }

    // ── orbital sentinels ──
    for (final o in orbitals) {
      final op = o.positionAround(ship.pos);
      final a = o.spawnOpacity; // fade-in alpha
      // Outer glow
      canvas.drawCircle(
        op,
        OrbitalSentinel.hitboxRadius,
        Paint()
          ..color = const Color(0xFF42A5F5).withValues(alpha: 0.15 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // Core
      canvas.drawCircle(
        op,
        OrbitalSentinel.hitboxRadius * 0.6,
        Paint()..color = const Color(0xFF42A5F5).withValues(alpha: 0.7 * a),
      );
      // Inner bright dot
      canvas.drawCircle(
        op,
        3,
        Paint()..color = const Color(0xFFBBDEFB).withValues(alpha: a),
      );
    }

    // ── companion projectiles ──
    for (final cp in companionProjectiles) {
      final cpp = cp.position;
      if ((cpp.dx - cx - screenW / 2).abs() > screenW ||
          (cpp.dy - cy - screenH / 2).abs() > screenH) {
        continue;
      }
      final projColor = cp.element != null
          ? elementColor(cp.element!)
          : const Color(0xFF42A5F5);
      final vs = cp.visualScale;

      if (cp.decoy && cp.decoyHp > 0) {
        // ── Decoy totem rendering (Mask decoys that enemies target) ──
        final pulse = 0.7 + 0.3 * sin(cp.life * 4.0);
        final totemR = 8.0 * vs;
        // Aggro aura: large pulsing ring that draws enemies
        canvas.drawCircle(
          cpp,
          totemR * 3.0 * pulse,
          Paint()
            ..color = projColor.withValues(alpha: 0.08)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, totemR * 2),
        );
        // Outer diamond shape (rotating)
        final rotAngle = cp.life * 2.0;
        final path = Path();
        for (var j = 0; j < 4; j++) {
          final da = rotAngle + j * (pi / 2);
          final pt = Offset(
            cpp.dx + cos(da) * totemR * 1.2,
            cpp.dy + sin(da) * totemR * 1.2,
          );
          if (j == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()..color = projColor.withValues(alpha: 0.4 * pulse),
        );
        // Inner core
        canvas.drawCircle(
          cpp,
          totemR * 0.5,
          Paint()..color = projColor.withValues(alpha: 0.85),
        );
        // Bright center pip
        canvas.drawCircle(
          cpp,
          totemR * 0.2,
          Paint()..color = Color.lerp(projColor, const Color(0xFFFFFFFF), 0.8)!,
        );
      } else if (cp.piercing && vs >= 1.5) {
        // ── Beam-style rendering (Crystal, Lightning piercing) ──
        final tailLen = 16.0 * vs;
        final tailX = cpp.dx - cos(cp.angle) * tailLen;
        final tailY = cpp.dy - sin(cp.angle) * tailLen;
        // Outer glow
        canvas.drawLine(
          Offset(tailX, tailY),
          cpp,
          Paint()
            ..color = projColor.withValues(alpha: 0.3)
            ..strokeWidth = 6.0 * vs
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        // Core beam
        canvas.drawLine(
          Offset(tailX, tailY),
          cpp,
          Paint()
            ..color = projColor
            ..strokeWidth = 3.0 * vs
            ..strokeCap = StrokeCap.round,
        );
        // Bright tip
        canvas.drawCircle(
          cpp,
          3.0 * vs,
          Paint()..color = Color.lerp(projColor, const Color(0xFFFFFFFF), 0.6)!,
        );
      } else if (cp.homing) {
        // ── Homing orb rendering (Spirit, Blood) ──
        // Pulsating outer glow
        final pulse = 0.6 + 0.4 * sin(cp.life * 8.0);
        canvas.drawCircle(
          cpp,
          10.0 * vs * pulse,
          Paint()
            ..color = projColor.withValues(alpha: 0.2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
        // Inner orb
        canvas.drawCircle(
          cpp,
          5.0 * vs,
          Paint()..color = projColor.withValues(alpha: 0.85),
        );
        // Bright center
        canvas.drawCircle(
          cpp,
          2.5 * vs,
          Paint()..color = Color.lerp(projColor, const Color(0xFFFFFFFF), 0.7)!,
        );
      } else if (vs >= 1.6 && cp.speedMultiplier < 0.5) {
        // ── Cloud/AoE rendering (Steam, Ice nova, Mud) ──
        final cloudR = 8.0 * vs;
        canvas.drawCircle(
          cpp,
          cloudR,
          Paint()
            ..color = projColor.withValues(alpha: 0.18)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, cloudR * 0.8),
        );
        canvas.drawCircle(
          cpp,
          cloudR * 0.5,
          Paint()
            ..color = projColor.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      } else if (cp.stationary) {
        // ── Mine/trap rendering (Mask specials, lingering zones) ──
        final pulse = 0.7 + 0.3 * sin(cp.life * 6.0);
        final mineR = 6.0 * vs;
        // Danger zone glow
        canvas.drawCircle(
          cpp,
          mineR * 1.5,
          Paint()
            ..color = projColor.withValues(alpha: 0.12 * pulse)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, mineR),
        );
        // Mine body
        canvas.drawCircle(
          cpp,
          mineR * 0.6,
          Paint()..color = projColor.withValues(alpha: 0.7 * pulse),
        );
        // Warning pip
        canvas.drawCircle(
          cpp,
          mineR * 0.25,
          Paint()
            ..color = Color.lerp(
              projColor,
              const Color(0xFFFFFFFF),
              0.8,
            )!.withValues(alpha: pulse),
        );
      } else if (cp.orbitCenter != null) {
        // ── Orbital rendering (Mystic/Kin orbiting projectiles) ──
        final pulse = 0.8 + 0.2 * sin(cp.orbitAngle * 3);
        // Orbit trail
        canvas.drawCircle(
          cpp,
          5.0 * vs * pulse,
          Paint()
            ..color = projColor.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // Core orb
        canvas.drawCircle(
          cpp,
          3.5 * vs,
          Paint()..color = projColor.withValues(alpha: 0.9),
        );
        // Bright center
        canvas.drawCircle(
          cpp,
          1.5 * vs,
          Paint()..color = Color.lerp(projColor, const Color(0xFFFFFFFF), 0.7)!,
        );
      } else {
        // ── Standard bolt rendering (with visual scale) ──
        final glowR = 8.0 * vs;
        final tailLen = 8.0 * vs;
        // Glow trail
        canvas.drawCircle(
          cpp,
          glowR,
          Paint()
            ..color = projColor.withValues(alpha: 0.25)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6.0 * vs),
        );
        // Core bolt
        final tailX = cpp.dx - cos(cp.angle) * tailLen;
        final tailY = cpp.dy - sin(cp.angle) * tailLen;
        canvas.drawLine(
          Offset(tailX, tailY),
          cpp,
          Paint()
            ..color = projColor
            ..strokeWidth = (cp.damage > 10 ? 3.0 : 2.0) * vs
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── companion ──
    if (activeCompanion != null && activeCompanion!.isAlive) {
      final comp = activeCompanion!;
      final compPos = comp.position;
      final eColor = elementColor(comp.member.element);

      // Animation timing
      const summonDur = 0.7; // summon animation duration
      const retreatDur = 0.6;
      final isSummoning = comp.life < summonDur && !comp.returning;
      final summonT = isSummoning
          ? (comp.life / summonDur).clamp(0.0, 1.0)
          : 1.0;
      final retreatT = comp.returning
          ? (comp.returnTimer / retreatDur).clamp(0.0, 1.0)
          : 1.0;

      // Ease curves
      final summonScale =
          (isSummoning ? Curves.elasticOut.transform(summonT) : 1.0) *
          _beautyContestCompVisualScale;
      final retreatScale = comp.returning
          ? Curves.easeInBack.transform(retreatT)
          : 1.0;
      final animScale = summonScale * retreatScale;
      final opacity = comp.returning ? retreatT : 1.0;

      canvas.save();
      canvas.translate(compPos.dx, compPos.dy);

      // ── Summon VFX: expanding ring + converging particles ──
      if (isSummoning) {
        // Expanding flash ring
        final ringRadius = 12.0 + summonT * 60.0;
        final ringAlpha = (1.0 - summonT) * 0.7;
        canvas.drawCircle(
          Offset.zero,
          ringRadius,
          Paint()
            ..color = eColor.withValues(alpha: ringAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0 * (1.0 - summonT) + 0.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // Inner flash glow
        canvas.drawCircle(
          Offset.zero,
          20 * summonT,
          Paint()
            ..color = Colors.white.withValues(alpha: (1.0 - summonT) * 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
        // Converging particle dots (6 swirling inward)
        for (var i = 0; i < 6; i++) {
          final pAngle = (i / 6) * pi * 2 + comp.life * 8;
          final pDist = 50.0 * (1.0 - summonT);
          final px = cos(pAngle) * pDist;
          final py = sin(pAngle) * pDist;
          canvas.drawCircle(
            Offset(px, py),
            2.5 * (1.0 - summonT * 0.5),
            Paint()..color = eColor.withValues(alpha: (1.0 - summonT) * 0.8),
          );
        }
      }

      // ── Retreat VFX: dispersing particles + shrinking ring ──
      if (comp.returning) {
        // Shrinking ring
        final ringRadius = 40.0 * retreatT;
        final ringAlpha = retreatT * 0.5;
        canvas.drawCircle(
          Offset.zero,
          ringRadius,
          Paint()
            ..color = eColor.withValues(alpha: ringAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 * retreatT + 0.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        // Dispersing particles (8 flying outward)
        for (var i = 0; i < 8; i++) {
          final pAngle = (i / 8) * pi * 2 + _elapsed * 3;
          final pDist = 15.0 + 60.0 * (1.0 - retreatT);
          final px = cos(pAngle) * pDist;
          final py = sin(pAngle) * pDist;
          canvas.drawCircle(
            Offset(px, py),
            2.0 * retreatT,
            Paint()..color = eColor.withValues(alpha: retreatT * 0.6),
          );
        }
      }

      // Outer aura glow
      final auraPulse = 0.5 + 0.3 * sin(_elapsed * 3.0);
      canvas.drawCircle(
        Offset.zero,
        28 * animScale,
        Paint()
          ..color = eColor.withValues(alpha: auraPulse * 0.3 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );

      // ── Shield bubble (Horn special) ──
      if (comp.hasShield) {
        final shieldPulse = 0.6 + 0.3 * sin(_elapsed * 5.0);
        // Outer shield ring
        canvas.drawCircle(
          Offset.zero,
          32 * animScale,
          Paint()
            ..color = eColor.withValues(alpha: shieldPulse * 0.4 * opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        // Inner shield fill
        canvas.drawCircle(
          Offset.zero,
          30 * animScale,
          Paint()
            ..color = eColor.withValues(alpha: 0.15 * opacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }

      // ── Charge trail (Horn charging) ──
      if (comp.isCharging) {
        for (var t = 0; t < 5; t++) {
          final trailAngle = comp.angle + pi; // behind companion
          final trailDist = 8.0 + t * 8.0;
          final tAlpha = (1.0 - t / 5.0) * 0.5 * opacity;
          canvas.drawCircle(
            Offset(cos(trailAngle) * trailDist, sin(trailAngle) * trailDist),
            (5.0 - t) * animScale,
            Paint()
              ..color = eColor.withValues(alpha: tAlpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
      }

      // ── Blessing aura (Kin healing) ──
      if (comp.isBlessing) {
        final blessingPulse = 0.5 + 0.4 * sin(_elapsed * 4.0);
        // Approximate a soft glow without MaskFilter.blur for performance by
        // drawing several concentric stroked rings with decreasing alpha and
        // increasing stroke width. This avoids expensive mask blurs on some
        // platforms while preserving a soft aura look (similar to prismatic
        // optimizations elsewhere).
        // Increase brightness: raise base alpha and widen rings for stronger
        // visual presence while still avoiding MaskFilter.blur.
        final baseAlpha = blessingPulse * 0.65 * opacity;
        final centerR = 24 * animScale;

        // When the pulse is at its brightest, draw a solid, more-inset
        // filled core to produce a very solid color. Otherwise, draw the
        // multi-ring approximation used for the softer glow.
        final isPeak = blessingPulse > 0.82;
        if (isPeak) {
          // Strong, solid core at peak
          canvas.drawCircle(
            Offset.zero,
            centerR * 0.48,
            Paint()
              ..color = Colors.greenAccent.withValues(
                alpha: (baseAlpha * 1.7).clamp(0.0, 1.0),
              ),
          );
        } else {
          // Bright core fill for punch
          canvas.drawCircle(
            Offset.zero,
            centerR * 0.22,
            Paint()
              ..color = Colors.greenAccent.withValues(alpha: baseAlpha * 0.95),
          );

          // Core thin ring (more visible)
          canvas.drawCircle(
            Offset.zero,
            centerR,
            Paint()
              ..color = Colors.greenAccent.withValues(alpha: baseAlpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0,
          );

          // Wider, stronger rings to emulate a brighter glow
          canvas.drawCircle(
            Offset.zero,
            centerR,
            Paint()
              ..color = Colors.greenAccent.withValues(alpha: baseAlpha * 0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8.0,
          );
          canvas.drawCircle(
            Offset.zero,
            centerR,
            Paint()
              ..color = Colors.greenAccent.withValues(alpha: baseAlpha * 0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 18.0,
          );
        }

        // Floating + particles
        for (var p = 0; p < 4; p++) {
          final pAng = (p / 4) * pi * 2 + _elapsed * 2;
          final pDist = 18.0 + 4 * sin(_elapsed * 3 + p);
          canvas.drawCircle(
            Offset(cos(pAng) * pDist, sin(pAng) * pDist),
            2.5,
            Paint()
              ..color = Colors.greenAccent.withValues(alpha: 0.6 * opacity),
          );
        }
      }

      // Render sprite if loaded, otherwise fallback to circles
      if (_companionTicker != null) {
        final sprite = _companionTicker!.getSprite();
        final paint = Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..filterQuality = ui.FilterQuality.high;

        // Apply genetics color filter if visuals available
        if (_companionVisuals != null) {
          final v = _companionVisuals!;
          final isAlbino = v.brightness == 1.45 && !v.isPrismatic;
          if (isAlbino) {
            paint.colorFilter = _albinoColorFilter(v.brightness);
          } else {
            paint.colorFilter = _geneticsColorFilter(v);
          }
        }

        // Simple canvas-based effect overlays for companion (behind sprite)
        if (_companionVisuals?.alchemyEffect != null) {
          final companionScale = _companionSpriteScale * animScale;
          _drawAlchemyEffectCanvas(
            canvas: canvas,
            effect: _companionVisuals!.alchemyEffect!,
            spriteScale: companionScale,
            baseSpriteSize: 48.0,
            variantFaction: _companionVisuals?.variantFaction,
            elapsed: _elapsed,
            opacity: opacity,
          );
        }

        // Flip sprite horizontally to face shooting direction
        // Default sprites face left; flip when target is to the right
        final facingRight = cos(comp.angle) > 0;
        final totalScale = _companionSpriteScale * animScale;
        canvas.save();
        if (facingRight) {
          canvas.scale(-totalScale, totalScale);
        } else {
          canvas.scale(totalScale);
        }
        sprite.render(canvas, anchor: Anchor.center, overridePaint: paint);
        canvas.restore();
      } else {
        // Fallback: colored circle
        canvas.drawCircle(
          Offset.zero,
          14 * animScale,
          Paint()..color = eColor.withValues(alpha: 0.85 * opacity),
        );
        canvas.drawCircle(
          Offset.zero,
          6 * animScale,
          Paint()..color = Colors.white.withValues(alpha: 0.9 * opacity),
        );
      }

      // Health bar above companion (only show after summon animation,
      // but hidden during contest cinematics).
      if (!isSummoning && !_beautyContestCinematicActive) {
        final hpW = 30.0;
        final hpH = 3.0;
        final hpX = -hpW / 2;
        final hpY = -30.0;
        // BG
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(hpX, hpY, hpW, hpH),
            const Radius.circular(2),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.5 * opacity),
        );
        // Fill
        final hpFill = comp.hpPercent.clamp(0.0, 1.0);
        final hpColor = hpFill > 0.5
            ? Color.lerp(Colors.yellow, Colors.green, (hpFill - 0.5) * 2)!
            : Color.lerp(Colors.red, Colors.yellow, hpFill * 2)!;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(hpX, hpY, hpW * hpFill, hpH),
            const Radius.circular(2),
          ),
          Paint()..color = hpColor.withValues(alpha: opacity),
        );
      }

      // Invincibility flash overlay
      if (comp.invincibleTimer > 0 &&
          !isSummoning &&
          !_beautyContestCinematicActive) {
        final flash = sin(_elapsed * 20) > 0 ? 0.4 : 0.0;
        canvas.drawCircle(
          Offset.zero,
          14 * animScale,
          Paint()..color = Colors.white.withValues(alpha: flash * opacity),
        );
      }

      canvas.restore();
    }

    // ── battle ring opponent ──
    if (battleRingOpponent != null && battleRingOpponent!.isAlive) {
      final opp = battleRingOpponent!;
      final oppPos = opp.position;
      final eColor = elementColor(opp.member.element);

      const summonDur = 1.0;
      final isSummoning = opp.life < summonDur;
      final summonT = isSummoning
          ? (opp.life / summonDur).clamp(0.0, 1.0)
          : 1.0;
      final summonScale =
          (isSummoning ? Curves.elasticOut.transform(summonT) : 1.0) *
          _beautyContestOppVisualScale;

      canvas.save();
      canvas.translate(oppPos.dx, oppPos.dy);

      // Summon VFX: portal-like arrival
      if (isSummoning) {
        final ringRadius = 12.0 + summonT * 80.0;
        final ringAlpha = (1.0 - summonT) * 0.7;
        canvas.drawCircle(
          Offset.zero,
          ringRadius,
          Paint()
            ..color = const Color(0xFFFF4040).withValues(alpha: ringAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0 * (1.0 - summonT) + 0.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        for (var i = 0; i < 8; i++) {
          final pAngle = (i / 8) * pi * 2 + opp.life * 6;
          final pDist = 60.0 * (1.0 - summonT);
          final px = cos(pAngle) * pDist;
          final py = sin(pAngle) * pDist;
          canvas.drawCircle(
            Offset(px, py),
            3.0 * (1.0 - summonT * 0.5),
            Paint()..color = eColor.withValues(alpha: (1.0 - summonT) * 0.8),
          );
        }
      }

      // Red-tinted aura glow (enemy)
      final auraPulse = 0.5 + 0.3 * sin(_elapsed * 3.0);
      canvas.drawCircle(
        Offset.zero,
        28 * summonScale,
        Paint()
          ..color = const Color(0xFFFF4040).withValues(alpha: auraPulse * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );

      // Render sprite
      if (_ringOpponentTicker != null) {
        final sprite = _ringOpponentTicker!.getSprite();
        final paint = Paint()
          ..color = Colors.white
          ..filterQuality = ui.FilterQuality.high;

        if (_ringOpponentVisuals != null) {
          final v = _ringOpponentVisuals!;
          final isAlbino = v.brightness == 1.45 && !v.isPrismatic;
          if (isAlbino) {
            paint.colorFilter = _albinoColorFilter(v.brightness);
          } else {
            paint.colorFilter = _geneticsColorFilter(v);
          }
        }

        // Simple effect overlays for ring opponent (behind sprite)
        if (_ringOpponentVisuals?.alchemyEffect != null) {
          final opponentScale = _ringOpponentSpriteScale * summonScale;
          _drawAlchemyEffectCanvas(
            canvas: canvas,
            effect: _ringOpponentVisuals!.alchemyEffect!,
            spriteScale: opponentScale,
            baseSpriteSize: 48.0,
            variantFaction: _ringOpponentVisuals?.variantFaction,
            elapsed: _elapsed,
            opacity: 0.95,
          );
        }

        final facingRight = cos(opp.angle) > 0;
        final totalScale = _ringOpponentSpriteScale * summonScale;
        canvas.save();
        if (facingRight) {
          canvas.scale(-totalScale, totalScale);
        } else {
          canvas.scale(totalScale);
        }
        sprite.render(canvas, anchor: Anchor.center, overridePaint: paint);
        canvas.restore();
      } else if (_ringOpponentFallbackSprite != null) {
        final paint = Paint()
          ..color = Colors.white
          ..filterQuality = ui.FilterQuality.high;
        final totalScale = _ringOpponentFallbackScale * summonScale;
        canvas.save();
        canvas.scale(totalScale);
        _ringOpponentFallbackSprite!.render(
          canvas,
          anchor: Anchor.center,
          overridePaint: paint,
        );
        canvas.restore();
      } else {
        // Fallback: red-tinted circle
        canvas.drawCircle(
          Offset.zero,
          14 * summonScale,
          Paint()..color = eColor.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          Offset.zero,
          6 * summonScale,
          Paint()..color = const Color(0xFFFF6060).withValues(alpha: 0.9),
        );
      }

      // HP bar (red-tinted for opponent), hidden during contest cinematics.
      if (!isSummoning && !_beautyContestCinematicActive) {
        final hpW = 30.0;
        final hpH = 3.0;
        final hpX = -hpW / 2;
        final hpY = -30.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(hpX, hpY, hpW, hpH),
            const Radius.circular(2),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.5),
        );
        final hpFill = opp.hpPercent.clamp(0.0, 1.0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(hpX, hpY, hpW * hpFill, hpH),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFFFF4040),
        );
      }

      // Invincibility flash
      if (opp.invincibleTimer > 0 &&
          !isSummoning &&
          !_beautyContestCinematicActive) {
        final flash = sin(_elapsed * 20) > 0 ? 0.4 : 0.0;
        canvas.drawCircle(
          Offset.zero,
          14 * summonScale,
          Paint()..color = Colors.white.withValues(alpha: flash),
        );
      }

      canvas.restore();
    }

    // ── render ring opponent projectiles ──
    for (final rp in ringOpponentProjectiles) {
      final rpPos = rp.position;
      final projColor = elementColor(
        battleRingOpponent?.member.element ?? 'Fire',
      );
      final vs = rp.radiusMultiplier.clamp(0.5, 3.0);
      // Red-tinted glow trail
      canvas.drawCircle(
        rpPos,
        8.0 * vs,
        Paint()
          ..color = projColor.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawLine(
        rpPos,
        Offset(
          rpPos.dx - cos(rp.angle) * 10 * vs,
          rpPos.dy - sin(rp.angle) * 10 * vs,
        ),
        Paint()
          ..color = projColor.withValues(alpha: 0.5)
          ..strokeWidth = 2.0 * vs
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        rpPos,
        3.0 * vs,
        Paint()..color = projColor.withValues(alpha: 0.9),
      );
    }

    // ── render ring minions (assistants) ──
    for (final m in ringMinions) {
      if (m.dead) continue;
      final mPos = m.position;
      final mColor = elementColor(m.element);
      // If still in orbit (portal), draw a shimmer ring
      if (m.orbitTime > 0 && m.orbitCenter != null) {
        final ringR = m.orbitRadius;
        canvas.drawCircle(
          mPos,
          ringR * 0.6,
          Paint()
            ..color = mColor.withValues(alpha: 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawCircle(
          mPos,
          4.0,
          Paint()..color = mColor.withValues(alpha: 0.95),
        );
        continue;
      }

      // Glow + core
      canvas.drawCircle(
        mPos,
        m.radius * 1.8,
        Paint()..color = mColor.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        mPos,
        m.radius,
        Paint()..color = mColor.withValues(alpha: 0.95),
      );
      // Small red dot if hostile (marks them as enemy)
      canvas.drawCircle(
        Offset(mPos.dx, mPos.dy),
        2.0,
        Paint()..color = Colors.black.withValues(alpha: 0.9),
      );
    }

    // ── ship ──
    if (!_shipDead) {
      // Invincibility flash
      if (_shipInvincible > 0) {
        final flash = (sin(_elapsed * 30) > 0) ? 0.4 : 1.0;
        canvas.saveLayer(
          null,
          Paint()..color = Colors.white.withValues(alpha: flash),
        );
        ship.render(canvas, _elapsed, skin: activeShipSkin);
        canvas.restore();
      } else {
        ship.render(canvas, _elapsed, skin: activeShipSkin);
      }

      // Boost exhaust trail
      if (isBoosting) {
        final exX = ship.pos.dx - cos(ship.angle) * 22;
        final exY = ship.pos.dy - sin(ship.angle) * 22;
        canvas.drawCircle(
          Offset(exX, exY),
          8 + 3 * sin(_elapsed * 15),
          Paint()
            ..color = const Color(0xFFFF6F00).withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
        canvas.drawCircle(
          Offset(exX, exY),
          4,
          Paint()..color = const Color(0xFFFFAB40).withValues(alpha: 0.8),
        );
      }

      // Ship health bar (below ship)
      if (shipHealth < shipMaxHealth) {
        final barW = 30.0;
        final barH = 3.0;
        final barX = ship.pos.dx - barW / 2;
        final barY = ship.pos.dy + 22;
        final hpFrac = (shipHealth / shipMaxHealth).clamp(0.0, 1.0);

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(barX, barY, barW, barH),
            const Radius.circular(1.5),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.6),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(barX, barY, barW * hpFrac, barH),
            const Radius.circular(1.5),
          ),
          Paint()..color = Color.lerp(Colors.red, Colors.greenAccent, hpFrac)!,
        );
      }
    } else {
      // Dead: show ghost outline pulsing
      final ghostAlpha = 0.15 + 0.1 * sin(_elapsed * 4);
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: ghostAlpha),
      );
      ship.render(canvas, _elapsed, skin: activeShipSkin);
      canvas.restore();
    }

    // ── VFX particles ──
    for (final p in vfxParticles) {
      final a = p.alpha;
      final sz = p.size * a;
      if (sz <= 0) continue;
      // Glow
      canvas.drawCircle(
        Offset(p.x, p.y),
        sz * 2,
        Paint()
          ..color = p.color.withValues(alpha: a * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sz * 2),
      );
      // Core
      canvas.drawCircle(
        Offset(p.x, p.y),
        sz,
        Paint()..color = p.color.withValues(alpha: a),
      );
    }

    // ── VFX shock rings ──
    for (final ring in vfxRings) {
      final strokeW = 3.0 * ring.alpha;
      if (strokeW <= 0) continue;
      canvas.drawCircle(
        Offset(ring.x, ring.y),
        ring.radius,
        Paint()
          ..color = ring.color.withValues(alpha: ring.alpha * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW,
      );
    }

    // Fog is tracked for the mini-map only — no overlay on the live view.

    // ── warp flash overlay ──
    if (_warpFlash > 0) {
      canvas.save();
      canvas.translate(-cx, -cy); // move to screen-space

      final t = _warpFlash; // 1.0 → 0.0
      final sw = size.x;
      final sh = size.y;
      final center = Offset(sw / 2, sh / 2);

      // Phase 1 (t > 0.5): bright purple/white flash from centre
      if (t > 0.5) {
        final flashT = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
        // Full-screen white flash
        canvas.drawRect(
          Rect.fromLTWH(0, 0, sw, sh),
          Paint()..color = Color.fromRGBO(255, 255, 255, flashT * 0.8),
        );
        // Central purple burst
        canvas.drawCircle(
          center,
          sw * 0.8 * flashT,
          Paint()
            ..color = Color.fromRGBO(124, 77, 255, flashT * 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 60 * flashT),
        );
      }

      // Phase 2 (t <= 0.5): speed-line tunnel effect fading out
      if (t <= 0.6) {
        final tunnelT = (t / 0.6).clamp(0.0, 1.0);
        // Radial streaks
        for (var i = 0; i < 32; i++) {
          final angle = (i / 32.0) * pi * 2;
          final innerR = sw * 0.05 * (1.0 - tunnelT);
          final outerR = sw * 0.9;
          final streakWidth = 1.5 + 1.5 * sin(i * 3.7);
          final alpha = tunnelT * 0.35;
          canvas.drawLine(
            Offset(
              center.dx + cos(angle) * innerR,
              center.dy + sin(angle) * innerR,
            ),
            Offset(
              center.dx + cos(angle) * outerR,
              center.dy + sin(angle) * outerR,
            ),
            Paint()
              ..color = Color.fromRGBO(179, 136, 255, alpha)
              ..strokeWidth = streakWidth
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
        // Vignette ring
        canvas.drawCircle(
          center,
          sw * 0.6,
          Paint()
            ..color = Color.fromRGBO(124, 77, 255, tunnelT * 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw * 0.4
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, sw * 0.2),
        );
      }

      canvas.restore();
    }

    canvas.restore();
  }

  // ── fog ────────────────────────────────────────────────

  void _revealAround(Offset center, double radius) {
    final cellR = (radius / fogCellSize).ceil();
    final cx = (center.dx / fogCellSize).floor();
    final cy = (center.dy / fogCellSize).floor();
    final gridW = (world_.worldSize.width / fogCellSize).ceil();
    final gridH = (world_.worldSize.height / fogCellSize).ceil();

    for (var dy = -cellR; dy <= cellR; dy++) {
      for (var dx = -cellR; dx <= cellR; dx++) {
        final gx = ((cx + dx) % gridW + gridW) % gridW;
        final gy = ((cy + dy) % gridH + gridH) % gridH;

        // Circular reveal
        final dist = sqrt((dx * dx + dy * dy).toDouble()) * fogCellSize;
        if (dist <= radius) {
          revealedCells.add(gy * gridW + gx);
        }
      }
    }
  }

  // ── enemy/boss spawning & AI ───────────────────────────

  // ── enemy/boss spawning & AI ───────────────────────────

  /// Pick a random element from discovered planets (or any if none discovered).
  String _randomEnemyElement(Random rng) {
    final discovered = world_.planets.where((p) => p.discovered).toList();
    final src = discovered.isNotEmpty
        ? discovered[rng.nextInt(discovered.length)]
        : world_.planets[rng.nextInt(world_.planets.length)];
    return src.element;
  }

  void _spawnEnemy() {
    final rng = Random();

    // Roll behavior type:
    //  30% aggressive, 25% drifting, 15% territorial, 15% stalking, 15% (solo feeding)
    final roll = rng.nextDouble();
    EnemyBehavior behavior;
    if (roll < 0.30) {
      behavior = EnemyBehavior.aggressive;
    } else if (roll < 0.55) {
      behavior = EnemyBehavior.drifting;
    } else if (roll < 0.70) {
      behavior = EnemyBehavior.territorial;
    } else if (roll < 0.85) {
      behavior = EnemyBehavior.stalking;
    } else {
      behavior = EnemyBehavior.feeding;
    }

    // Choose tier — behavior determines distribution across all 6 tiers
    final EnemyTier tier;
    switch (behavior) {
      case EnemyBehavior.aggressive:
        final roll = rng.nextDouble();
        tier = roll < 0.20
            ? EnemyTier.wisp
            : roll < 0.45
            ? EnemyTier.drone
            : roll < 0.70
            ? EnemyTier.sentinel
            : roll < 0.85
            ? EnemyTier.phantom
            : roll < 0.95
            ? EnemyTier.brute
            : EnemyTier.colossus;
        break;
      case EnemyBehavior.drifting:
        final roll = rng.nextDouble();
        tier = roll < 0.50
            ? EnemyTier.wisp
            : roll < 0.70
            ? EnemyTier.phantom
            : roll < 0.90
            ? EnemyTier.sentinel
            : EnemyTier.drone;
        break;
      case EnemyBehavior.territorial:
        final roll = rng.nextDouble();
        tier = roll < 0.15
            ? EnemyTier.wisp
            : roll < 0.35
            ? EnemyTier.drone
            : roll < 0.60
            ? EnemyTier.sentinel
            : roll < 0.78
            ? EnemyTier.phantom
            : roll < 0.92
            ? EnemyTier.brute
            : EnemyTier.colossus;
        break;
      case EnemyBehavior.stalking:
        // Stalkers: phantoms & wisps — eerie
        tier = rng.nextDouble() < 0.55 ? EnemyTier.phantom : EnemyTier.wisp;
        break;
      case EnemyBehavior.feeding:
        final roll = rng.nextDouble();
        tier = roll < 0.40
            ? EnemyTier.wisp
            : roll < 0.65
            ? EnemyTier.sentinel
            : roll < 0.85
            ? EnemyTier.phantom
            : EnemyTier.colossus;
        break;
      case EnemyBehavior.swarming:
        // Swarms: mostly drones & wisps
        tier = rng.nextDouble() < 0.55 ? EnemyTier.drone : EnemyTier.wisp;
        break;
    }
    final element = _randomEnemyElement(rng);

    // Position depends on behavior
    Offset pos;
    Offset? homePos;
    double aggroRadius = 300;

    switch (behavior) {
      case EnemyBehavior.territorial:
        // Spawn near a random planet
        final planet = world_.planets[rng.nextInt(world_.planets.length)];
        final a = rng.nextDouble() * pi * 2;
        final dist = planet.radius * 3.0 + 80 + rng.nextDouble() * 200;
        pos = _wrap(
          Offset(
            planet.position.dx + cos(a) * dist,
            planet.position.dy + sin(a) * dist,
          ),
        );
        homePos = pos;
        aggroRadius = 250 + rng.nextDouble() * 150;
        break;

      case EnemyBehavior.stalking:
        // Spawn behind the player at distance
        final behindAngle = ship.angle + pi + (rng.nextDouble() - 0.5) * 0.8;
        final stalkDist = 600 + rng.nextDouble() * 400;
        pos = _wrap(
          Offset(
            ship.pos.dx + cos(behindAngle) * stalkDist,
            ship.pos.dy + sin(behindAngle) * stalkDist,
          ),
        );
        break;

      case EnemyBehavior.feeding:
        // Solo feeder near asteroid belt
        final belt = asteroidBelt;
        final a = rng.nextDouble() * pi * 2;
        final dist =
            belt.innerRadius +
            rng.nextDouble() * (belt.outerRadius - belt.innerRadius);
        pos = _wrap(
          Offset(
            belt.center.dx + cos(a) * dist,
            belt.center.dy + sin(a) * dist,
          ),
        );
        homePos = pos;
        break;

      default:
        // Aggressive / drifting — spawn at viewport edge
        final angle = rng.nextDouble() * pi * 2;
        final edgeDist = sqrt(size.x * size.x + size.y * size.y) * 0.55;
        pos = _wrap(
          Offset(
            ship.pos.dx + cos(angle) * edgeDist,
            ship.pos.dy + sin(angle) * edgeDist,
          ),
        );
    }

    enemies.add(
      CosmicEnemy(
        position: pos,
        element: element,
        tier: tier,
        radius: switch (tier) {
          EnemyTier.drone => 6 + rng.nextDouble() * 3,
          EnemyTier.wisp => 8 + rng.nextDouble() * 4,
          EnemyTier.sentinel => 14 + rng.nextDouble() * 6,
          EnemyTier.phantom => 12 + rng.nextDouble() * 5,
          EnemyTier.brute => 20 + rng.nextDouble() * 8,
          EnemyTier.colossus => 30 + rng.nextDouble() * 12,
        },
        health: switch (tier) {
          EnemyTier.drone => 0.5,
          EnemyTier.wisp => 1.0,
          EnemyTier.sentinel => 3.0,
          EnemyTier.phantom => 4.0,
          EnemyTier.brute => 8.0,
          EnemyTier.colossus => 15.0,
        },
        speed: switch (tier) {
          EnemyTier.drone => 90 + rng.nextDouble() * 50,
          EnemyTier.wisp => 60 + rng.nextDouble() * 40,
          EnemyTier.sentinel => 35 + rng.nextDouble() * 25,
          EnemyTier.phantom => 45 + rng.nextDouble() * 30,
          EnemyTier.brute => 20 + rng.nextDouble() * 15,
          EnemyTier.colossus => 12 + rng.nextDouble() * 8,
        },
        angle: rng.nextDouble() * pi * 2,
        driftTimer: rng.nextDouble() * 4,
        behavior: behavior,
        homePos: homePos,
        aggroRadius: aggroRadius,
        stalkDistance: 400 + rng.nextDouble() * 300,
      ),
    );
  }

  /// Spawn a feeding pack: 1 sentinel alpha + 3-5 wisp minions clustered
  /// near the asteroid belt, passively eating rocks.
  void _spawnFeedingPack() {
    final rng = Random();
    final packId = _nextPackId++;
    final element = _randomEnemyElement(rng);

    // Pick a position inside the asteroid belt
    final belt = asteroidBelt;
    final centerAngle = rng.nextDouble() * pi * 2;
    final centerDist =
        belt.innerRadius +
        rng.nextDouble() * (belt.outerRadius - belt.innerRadius);
    final cx = belt.center.dx + cos(centerAngle) * centerDist;
    final cy = belt.center.dy + sin(centerAngle) * centerDist;
    final home = _wrap(Offset(cx, cy));

    // Alpha sentinel — bigger, tougher
    enemies.add(
      CosmicEnemy(
        position: home,
        element: element,
        tier: EnemyTier.sentinel,
        radius: 18 + rng.nextDouble() * 6,
        health: 5.0,
        speed: 30 + rng.nextDouble() * 20,
        angle: rng.nextDouble() * pi * 2,
        driftTimer: rng.nextDouble() * 4,
        behavior: EnemyBehavior.feeding,
        packId: packId,
        homePos: home,
        aggroRadius: 350,
      ),
    );

    // 3-5 wisp minions
    final minionCount = 3 + rng.nextInt(3);
    for (var m = 0; m < minionCount; m++) {
      final mAngle = rng.nextDouble() * pi * 2;
      final mDist = 40 + rng.nextDouble() * 80;
      final mPos = _wrap(
        Offset(cx + cos(mAngle) * mDist, cy + sin(mAngle) * mDist),
      );
      enemies.add(
        CosmicEnemy(
          position: mPos,
          element: element,
          tier: EnemyTier.wisp,
          radius: 6 + rng.nextDouble() * 4,
          health: 1.0,
          speed: 40 + rng.nextDouble() * 30,
          angle: rng.nextDouble() * pi * 2,
          driftTimer: rng.nextDouble() * 4,
          behavior: EnemyBehavior.feeding,
          packId: packId,
          homePos: mPos,
          aggroRadius: 350,
        ),
      );
    }
  }

  /// Spawn a swarm cluster of 15-25 swarming wisps at a position.
  /// If [center] is not given, picks a random spot in deep space.
  /// Respects the enemy cap — skips if already at max.
  void _spawnSwarmCluster({Offset? center, Random? rng}) {
    if (enemies.length >= _maxEnemies) return;
    rng ??= Random();
    final packId = _nextPackId++;
    const elements = ['Fire', 'Water', 'Earth', 'Air', 'Light', 'Dark'];
    final element = elements[rng.nextInt(elements.length)];
    final count = min(
      15 + rng.nextInt(11),
      _maxEnemies - enemies.length,
    ); // 15-25, capped

    // Pick center if not provided — random position in world, away from edges
    final cx =
        center?.dx ??
        (2000.0 + rng.nextDouble() * (world_.worldSize.width - 4000));
    final cy =
        center?.dy ??
        (2000.0 + rng.nextDouble() * (world_.worldSize.height - 4000));
    final home = _wrap(Offset(cx, cy));

    for (int i = 0; i < count; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final dist = 20.0 + rng.nextDouble() * 150;
      final swarmTier = rng.nextDouble() < 0.5
          ? EnemyTier.drone
          : EnemyTier.wisp;
      enemies.add(
        CosmicEnemy(
          position: _wrap(
            Offset(cx + cos(angle) * dist, cy + sin(angle) * dist),
          ),
          element: element,
          tier: swarmTier,
          radius: swarmTier == EnemyTier.drone
              ? 4 + rng.nextDouble() * 3
              : 5 + rng.nextDouble() * 4,
          health: swarmTier == EnemyTier.drone ? 0.5 : 1.0,
          speed: swarmTier == EnemyTier.drone
              ? 55 + rng.nextDouble() * 40
              : 35 + rng.nextDouble() * 35,
          angle: rng.nextDouble() * pi * 2,
          driftTimer: rng.nextDouble() * 4,
          behavior: EnemyBehavior.swarming,
          packId: packId,
          homePos: home,
        ),
      );
    }
  }

  /// Spawn an enemy from a galaxy whirl during horde mode.
  /// Behaviour varies by [HordeType].
  void _spawnWhirlEnemy(GalaxyWhirl whirl, int whirlIdx) {
    switch (whirl.hordeType) {
      case HordeType.skirmish:
        _spawnSkirmishEnemy(whirl, whirlIdx);
      case HordeType.siege:
        _spawnSiegeEnemy(whirl, whirlIdx);
      case HordeType.onslaught:
        _spawnOnslaughtEnemy(whirl, whirlIdx);
    }
  }

  // ── SKIRMISH (Lv 1-3) ───────────────────────────
  // Simple waves, mostly wisps & sentinels, moderate pacing.
  void _spawnSkirmishEnemy(GalaxyWhirl whirl, int whirlIdx) {
    final rng = Random();
    final wave = whirl.currentWave;

    // Gentle tier distribution — drones join mid waves, phantoms late
    final EnemyTier tier;
    if (wave >= 4) {
      final roll = rng.nextDouble();
      tier = roll < 0.20
          ? EnemyTier.wisp
          : roll < 0.45
          ? EnemyTier.drone
          : roll < 0.75
          ? EnemyTier.sentinel
          : EnemyTier.phantom;
    } else if (wave >= 2) {
      final roll = rng.nextDouble();
      tier = roll < 0.35
          ? EnemyTier.wisp
          : roll < 0.60
          ? EnemyTier.drone
          : EnemyTier.sentinel;
    } else {
      tier = rng.nextDouble() < 0.65 ? EnemyTier.wisp : EnemyTier.drone;
    }

    final behavior = (wave >= 3 && rng.nextDouble() < 0.3)
        ? EnemyBehavior.swarming
        : EnemyBehavior.aggressive;

    _addWhirlEnemy(whirl, whirlIdx, tier, behavior, rng);
  }

  // ── SIEGE (Lv 4-7) ──────────────────────────────
  // Formation bursts, brute tanks shield wisps, final wave has a mini-boss.
  void _spawnSiegeEnemy(GalaxyWhirl whirl, int whirlIdx) {
    final rng = Random();
    final wave = whirl.currentWave;
    final isFinalWave = wave == whirl.totalWaves - 1;

    // Final wave mini-boss: one beefy sentinel
    if (isFinalWave && !whirl.miniBossSpawned) {
      whirl.miniBossSpawned = true;
      final hpScale = whirl.enemyHealthScale;
      final spdScale = whirl.enemySpeedScale;
      final angle = rng.nextDouble() * pi * 2;
      final spawnDist = whirl.radius * 0.5 + rng.nextDouble() * 20;
      final pos = _wrap(
        Offset(
          whirl.position.dx + cos(angle) * spawnDist,
          whirl.position.dy + sin(angle) * spawnDist,
        ),
      );
      enemies.add(
        CosmicEnemy(
          position: pos,
          element: whirl.element,
          tier: EnemyTier.brute,
          radius: 28 + rng.nextDouble() * 6,
          health: 16.0 * hpScale, // double-HP brute mini-boss
          speed: (30 + rng.nextDouble() * 10) * spdScale,
          angle: rng.nextDouble() * pi * 2,
          driftTimer: rng.nextDouble() * 2,
          behavior: EnemyBehavior.aggressive,
          provoked: true,
          whirlIndex: whirlIdx,
        ),
      );
      return;
    }

    // Formation tier: brutes & colossi in later waves, drones early
    final EnemyTier tier;
    if (wave >= 3) {
      final roll = rng.nextDouble();
      tier = roll < 0.10
          ? EnemyTier.wisp
          : roll < 0.25
          ? EnemyTier.drone
          : roll < 0.50
          ? EnemyTier.sentinel
          : roll < 0.65
          ? EnemyTier.phantom
          : roll < 0.88
          ? EnemyTier.brute
          : EnemyTier.colossus;
    } else if (wave >= 1) {
      final roll = rng.nextDouble();
      tier = roll < 0.20
          ? EnemyTier.wisp
          : roll < 0.40
          ? EnemyTier.drone
          : roll < 0.75
          ? EnemyTier.sentinel
          : EnemyTier.brute;
    } else {
      final roll = rng.nextDouble();
      tier = roll < 0.35
          ? EnemyTier.wisp
          : roll < 0.60
          ? EnemyTier.drone
          : EnemyTier.sentinel;
    }

    // Siege enemies are always aggressive — disciplined formation
    _addWhirlEnemy(whirl, whirlIdx, tier, EnemyBehavior.aggressive, rng);
  }

  // ── ONSLAUGHT (Lv 8-10) ─────────────────────────
  // Relentless, mixed tiers from wave 1, swarming dominant, mini-boss brute finale.
  void _spawnOnslaughtEnemy(GalaxyWhirl whirl, int whirlIdx) {
    final rng = Random();
    final wave = whirl.currentWave;
    final isFinalWave = wave == whirl.totalWaves - 1;

    // Final wave mini-boss: terrifying colossus
    if (isFinalWave && !whirl.miniBossSpawned) {
      whirl.miniBossSpawned = true;
      final hpScale = whirl.enemyHealthScale;
      final spdScale = whirl.enemySpeedScale;
      final angle = rng.nextDouble() * pi * 2;
      final spawnDist = whirl.radius * 0.5 + rng.nextDouble() * 20;
      final pos = _wrap(
        Offset(
          whirl.position.dx + cos(angle) * spawnDist,
          whirl.position.dy + sin(angle) * spawnDist,
        ),
      );
      enemies.add(
        CosmicEnemy(
          position: pos,
          element: whirl.element,
          tier: EnemyTier.colossus,
          radius: 38 + rng.nextDouble() * 8,
          health: 30.0 * hpScale, // massive colossus mega-boss
          speed: (20 + rng.nextDouble() * 10) * spdScale,
          angle: rng.nextDouble() * pi * 2,
          driftTimer: rng.nextDouble() * 2,
          behavior: EnemyBehavior.aggressive,
          provoked: true,
          whirlIndex: whirlIdx,
        ),
      );
      return;
    }

    // Mixed tiers from the start — onslaught is chaotic, all tiers present
    final EnemyTier tier;
    final roll = rng.nextDouble();
    final levChance = (0.04 + wave * 0.03).clamp(0.04, 0.15);
    final bruteChance = (0.10 + wave * 0.05).clamp(0.10, 0.25);
    final phantomChance = (0.10 + wave * 0.03).clamp(0.10, 0.20);
    final sentinelChance = 0.20;
    final droneChance = 0.20;
    // remainder → wisps
    if (roll < droneChance) {
      tier = EnemyTier.drone;
    } else if (roll < droneChance + sentinelChance) {
      tier = EnemyTier.sentinel;
    } else if (roll < droneChance + sentinelChance + phantomChance) {
      tier = EnemyTier.phantom;
    } else if (roll <
        droneChance + sentinelChance + phantomChance + bruteChance) {
      tier = EnemyTier.brute;
    } else if (roll <
        droneChance +
            sentinelChance +
            phantomChance +
            bruteChance +
            levChance) {
      tier = EnemyTier.colossus;
    } else {
      tier = EnemyTier.wisp;
    }

    // Swarming is dominant in onslaught
    final behavior = rng.nextDouble() < 0.6
        ? EnemyBehavior.swarming
        : EnemyBehavior.aggressive;

    _addWhirlEnemy(whirl, whirlIdx, tier, behavior, rng);
  }

  /// Shared helper to add a whirl enemy with standard position & scaling.
  void _addWhirlEnemy(
    GalaxyWhirl whirl,
    int whirlIdx,
    EnemyTier tier,
    EnemyBehavior behavior,
    Random rng,
  ) {
    final hpScale = whirl.enemyHealthScale;
    final spdScale = whirl.enemySpeedScale;

    final angle = rng.nextDouble() * pi * 2;
    final spawnDist = whirl.radius * 0.5 + rng.nextDouble() * 20;
    final pos = _wrap(
      Offset(
        whirl.position.dx + cos(angle) * spawnDist,
        whirl.position.dy + sin(angle) * spawnDist,
      ),
    );

    enemies.add(
      CosmicEnemy(
        position: pos,
        element: whirl.element,
        tier: tier,
        radius: switch (tier) {
          EnemyTier.drone => 6 + rng.nextDouble() * 3,
          EnemyTier.wisp => 8 + rng.nextDouble() * 4,
          EnemyTier.sentinel => 14 + rng.nextDouble() * 6,
          EnemyTier.phantom => 12 + rng.nextDouble() * 5,
          EnemyTier.brute => 20 + rng.nextDouble() * 8,
          EnemyTier.colossus => 30 + rng.nextDouble() * 12,
        },
        health: switch (tier) {
          EnemyTier.drone => 0.5 * hpScale,
          EnemyTier.wisp => 1.0 * hpScale,
          EnemyTier.sentinel => 3.0 * hpScale,
          EnemyTier.phantom => 4.0 * hpScale,
          EnemyTier.brute => 8.0 * hpScale,
          EnemyTier.colossus => 15.0 * hpScale,
        },
        speed: switch (tier) {
          EnemyTier.drone => (100 + rng.nextDouble() * 60) * spdScale,
          EnemyTier.wisp => (70 + rng.nextDouble() * 50) * spdScale,
          EnemyTier.sentinel => (40 + rng.nextDouble() * 30) * spdScale,
          EnemyTier.phantom => (50 + rng.nextDouble() * 35) * spdScale,
          EnemyTier.brute => (25 + rng.nextDouble() * 15) * spdScale,
          EnemyTier.colossus => (15 + rng.nextDouble() * 10) * spdScale,
        },
        angle: rng.nextDouble() * pi * 2,
        driftTimer: rng.nextDouble() * 2,
        behavior: behavior,
        provoked: true,
        whirlIndex: whirlIdx,
      ),
    );
  }

  /// Provoke all enemies in the same pack as [hit].
  void _provokePackOf(CosmicEnemy hit) {
    if (hit.packId < 0) {
      // Solo enemy — just provoke itself
      hit.provoked = true;
      hit.behavior = EnemyBehavior.aggressive;
      return;
    }
    for (final e in enemies) {
      if (e.dead) continue;
      if (e.packId == hit.packId) {
        e.provoked = true;
        e.behavior = EnemyBehavior.aggressive;
      }
    }
  }

  void _updateRingMinions(double dt) {
    for (var mi = ringMinions.length - 1; mi >= 0; mi--) {
      final m = ringMinions[mi];
      if (m.dead) {
        ringMinions.removeAt(mi);
        continue;
      }
      m.life += dt;
      m.attackCooldown = (m.attackCooldown - dt).clamp(0.0, 100.0);
      // If orbitTime > 0, animate orbit (portal) until emergence
      if (m.orbitTime > 0) {
        m.orbitTime -= dt;
        // Chargers should have a much subtler portal wobble; shooters spin faster.
        if (m.type == 'charger') {
          m.orbitAngle += (0.4 + _rng.nextDouble() * 0.6) * dt;
          m.orbitRadius += dt * 1.5; // minimal expansion for chargers
        } else {
          m.orbitAngle += (1.2 + _rng.nextDouble() * 1.6) * dt; // spin
          m.orbitRadius += dt * 3.0; // reduced expansion for shooters
        }
        if (m.orbitCenter != null) {
          m.position = Offset(
            m.orbitCenter!.dx + cos(m.orbitAngle) * m.orbitRadius,
            m.orbitCenter!.dy + sin(m.orbitAngle) * m.orbitRadius,
          );
        }
        if (m.orbitTime <= 0) {
          // Emerge: small VFX to show portal spawn
          _spawnHitSpark(m.position, elementColor(m.element));
        }
        continue; // don't move toward companion until emerged
      }

      // Different behaviors per minion type after emergence
      if (m.type == 'shooter') {
        // Shooters hold position / orbit and periodically fire at the
        // player's companion.
        if (m.orbitCenter != null) {
          // gentle orbital hover
          m.orbitAngle += (0.6 + _rng.nextDouble() * 0.8) * dt;
          m.position = Offset(
            m.orbitCenter!.dx + cos(m.orbitAngle) * m.orbitRadius,
            m.orbitCenter!.dy + sin(m.orbitAngle) * m.orbitRadius,
          );
        } else if (activeCompanion != null && activeCompanion!.isAlive) {
          // small drift toward the companion but stay mostly stationary
          final comp = activeCompanion!;
          final toComp = comp.position - m.position;
          final dist = toComp.distance;
          if (dist > 2.0) {
            final step = (m.speed * 0.35) * dt;
            m.position += (toComp / dist) * min(step, dist);
          }
        }
        // Shooting
        m.shootCooldown -= dt;
        if (m.shootCooldown <= 0 &&
            activeCompanion != null &&
            activeCompanion!.isAlive) {
          m.shootCooldown = 0.6 + _rng.nextDouble() * 1.2;
          final comp = activeCompanion!;
          final ang = atan2(
            comp.position.dy - m.position.dy,
            comp.position.dx - m.position.dx,
          );
          // Use the ring opponent's family so the projectile visuals match
          final fam = battleRingOpponent?.member.family ?? 'neutral';
          final basics = createFamilyBasicAttack(
            origin: m.position,
            angle: ang,
            element: m.element,
            family: fam,
            damage: max(2.0, (m.health * 0.12)),
          );
          ringOpponentProjectiles.addAll(basics);
        }
      } else {
        // Charger: slowly move in toward the player's companion and
        // slam into it for high contact damage. They are tanky.
        if (activeCompanion != null && activeCompanion!.isAlive) {
          final comp = activeCompanion!;
          final toComp = comp.position - m.position;
          final dist = toComp.distance;
          if (dist > 2.0) {
            final step = (m.speed * 0.6) * dt; // slow, steady approach
            m.position += (toComp / dist) * min(step, dist);
          }
          // Heavy contact damage when they reach the companion
          if (dist < (m.radius + 15)) {
            if (m.attackCooldown <= 0) {
              // Slower, less devastating hits from chargers
              m.attackCooldown = 2.2;
              final contactDmg = 6.0 + (m.health / 12.0);
              final dmg = max(
                1,
                (contactDmg * 100 / (100 + comp.physDef)).round(),
              );
              comp.takeDamage(dmg);
              _spawnHitSpark(comp.position, elementColor(m.element));
            }
          }
        }
      }
    }
  }

  void _updateEnemyAI(CosmicEnemy e, double dt) {
    e.driftTimer -= dt;

    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;

    // ── Fast despawn check — skip all AI for enemies far from the player ──
    {
      var fdx = ship.pos.dx - e.position.dx;
      var fdy = ship.pos.dy - e.position.dy;
      if (fdx > ww / 2) fdx -= ww;
      if (fdx < -ww / 2) fdx += ww;
      if (fdy > wh / 2) fdy -= wh;
      if (fdy < -wh / 2) fdy += wh;
      final fastDist = fdx * fdx + fdy * fdy;
      // Enemies beyond 1800 units: just drift + despawn, skip expensive AI
      if (fastDist > 1800 * 1800) {
        e.position = _wrap(
          Offset(
            e.position.dx + cos(e.angle) * e.speed * dt * 0.3,
            e.position.dy + sin(e.angle) * e.speed * dt * 0.3,
          ),
        );
        final despawnDist = e.whirlIndex >= 0
            ? 4000.0 // whirl enemies persist a bit longer
            : (e.behavior == EnemyBehavior.feeding ||
                  e.behavior == EnemyBehavior.territorial)
            ? 2500.0 // persistent near their zone
            : 2000.0;
        if (sqrt(fastDist) > despawnDist) e.dead = true;
        return;
      }
    }

    // ── Check for nearby decoys — enemies prioritize attacking decoys ──
    Projectile? nearestDecoy;
    double nearestDecoyDist = double.infinity;
    for (final cp in companionProjectiles) {
      if (!cp.decoy || cp.decoyHp <= 0) continue;
      var ddx = cp.position.dx - e.position.dx;
      var ddy = cp.position.dy - e.position.dy;
      if (ddx > ww / 2) ddx -= ww;
      if (ddx < -ww / 2) ddx += ww;
      if (ddy > wh / 2) ddy -= wh;
      if (ddy < -wh / 2) ddy += wh;
      final dd = sqrt(ddx * ddx + ddy * ddy);
      final aggroRadius = cp.tauntRadius > 0 ? cp.tauntRadius : 500.0;
      if (dd < aggroRadius && dd < nearestDecoyDist) {
        nearestDecoy = cp;
        nearestDecoyDist = dd;
      }
    }

    // If a decoy is nearby, aggressive enemies chase it instead of the ship
    if (nearestDecoy != null &&
        (nearestDecoy.tauntRadius > 0 ||
            e.behavior == EnemyBehavior.aggressive ||
            e.behavior == EnemyBehavior.swarming ||
            e.behavior == EnemyBehavior.territorial ||
            e.provoked)) {
      if (nearestDecoy.tauntRadius > 0) {
        e.provoked = true;
        if (e.behavior == EnemyBehavior.drifting ||
            e.behavior == EnemyBehavior.feeding ||
            e.behavior == EnemyBehavior.territorial) {
          e.behavior = EnemyBehavior.aggressive;
        }
      }
      var ddx = nearestDecoy.position.dx - e.position.dx;
      var ddy = nearestDecoy.position.dy - e.position.dy;
      if (ddx > ww / 2) ddx -= ww;
      if (ddx < -ww / 2) ddx += ww;
      if (ddy > wh / 2) ddy -= wh;
      if (ddy < -wh / 2) ddy += wh;
      final toDecoy = atan2(ddy, ddx);
      var diff = toDecoy - e.angle;
      while (diff > pi) {
        diff -= pi * 2;
      }
      while (diff < -pi) {
        diff += pi * 2;
      }
      final turnRate = nearestDecoy.tauntStrength > 0
          ? nearestDecoy.tauntStrength
          : 4.0;
      e.angle += diff * turnRate * dt;
      final tauntSpeedMult =
          (nearestDecoy.tauntStrength > 0
                  ? (1.0 + nearestDecoy.tauntStrength * 0.08).clamp(1.0, 1.6)
                  : 1.0)
              .toDouble();
      // Skip normal AI — enemy is locked onto decoy
      e.position = _wrap(
        Offset(
          e.position.dx + cos(e.angle) * e.speed * tauntSpeedMult * dt,
          e.position.dy + sin(e.angle) * e.speed * tauntSpeedMult * dt,
        ),
      );
      return;
    }

    // Distance to ship (wrapped)
    var dx = ship.pos.dx - e.position.dx;
    var dy = ship.pos.dy - e.position.dy;
    if (dx > ww / 2) dx -= ww;
    if (dx < -ww / 2) dx += ww;
    if (dy > wh / 2) dy -= wh;
    if (dy < -wh / 2) dy += wh;
    final distToShip = sqrt(dx * dx + dy * dy);
    final toShip = atan2(dy, dx);

    switch (e.behavior) {
      case EnemyBehavior.aggressive:
        // Chase the player — sentinels within 700, wisps within 400
        final chaseRange = e.tier == EnemyTier.sentinel ? 700.0 : 400.0;
        if (distToShip < chaseRange) {
          // Smooth turn toward player
          var diff = toShip - e.angle;
          while (diff > pi) {
            diff -= pi * 2;
          }
          while (diff < -pi) {
            diff += pi * 2;
          }
          e.angle += diff * 3.0 * dt;
        } else if (e.driftTimer <= 0) {
          e.angle += (Random().nextDouble() - 0.5) * 1.5;
          e.driftTimer = 1.5 + Random().nextDouble() * 2;
        }
        break;

      case EnemyBehavior.drifting:
        // Wander aimlessly — gentle curves
        if (e.driftTimer <= 0) {
          e.angle += (Random().nextDouble() - 0.5) * 1.0;
          e.driftTimer = 2 + Random().nextDouble() * 4;
        }
        break;

      case EnemyBehavior.feeding:
        // Orbit slowly near homePos; if player gets very close, scatter away
        if (e.homePos != null) {
          var hx = e.homePos!.dx - e.position.dx;
          var hy = e.homePos!.dy - e.position.dy;
          if (hx > ww / 2) hx -= ww;
          if (hx < -ww / 2) hx += ww;
          if (hy > wh / 2) hy -= wh;
          if (hy < -wh / 2) hy += wh;
          final distHome = sqrt(hx * hx + hy * hy);

          // Lazy orbit near home
          if (distHome > 100) {
            // Drift back toward home
            final toHome = atan2(hy, hx);
            var diff = toHome - e.angle;
            while (diff > pi) {
              diff -= pi * 2;
            }
            while (diff < -pi) {
              diff += pi * 2;
            }
            e.angle += diff * 1.5 * dt;
          } else {
            // Gentle circular drift
            e.angle += 0.3 * dt;
          }

          // If player is very close, flee briefly (not aggro, just skittish)
          if (distToShip < 150 && !e.provoked) {
            e.angle = toShip + pi; // face away
          }
        }
        break;

      case EnemyBehavior.territorial:
        // Patrol around homePos; if player enters aggroRadius → attack
        if (distToShip < e.aggroRadius) {
          // Intruder! Chase them
          var diff = toShip - e.angle;
          while (diff > pi) {
            diff -= pi * 2;
          }
          while (diff < -pi) {
            diff += pi * 2;
          }
          e.angle += diff * 2.5 * dt;
        } else if (e.homePos != null) {
          // Patrol: orbit around homePos
          var hx = e.homePos!.dx - e.position.dx;
          var hy = e.homePos!.dy - e.position.dy;
          if (hx > ww / 2) hx -= ww;
          if (hx < -ww / 2) hx += ww;
          if (hy > wh / 2) hy -= wh;
          if (hy < -wh / 2) hy += wh;
          final distHome = sqrt(hx * hx + hy * hy);
          if (distHome > 180) {
            final toHome = atan2(hy, hx);
            var diff = toHome - e.angle;
            while (diff > pi) {
              diff -= pi * 2;
            }
            while (diff < -pi) {
              diff += pi * 2;
            }
            e.angle += diff * 2.0 * dt;
          } else {
            // Slow patrol orbit
            e.angle += 0.5 * dt;
          }
        }
        break;

      case EnemyBehavior.stalking:
        // Keep distance from player; if ship HP is low → rush in
        final lowHp = shipHealth <= 2.0;
        if (lowHp && distToShip < 800) {
          // Strike! Rush toward the wounded player
          var diff = toShip - e.angle;
          while (diff > pi) {
            diff -= pi * 2;
          }
          while (diff < -pi) {
            diff += pi * 2;
          }
          e.angle += diff * 4.0 * dt;
          // Speed boost when attacking
          e.speed = 120;
        } else if (distToShip < e.stalkDistance - 50) {
          // Too close — back off
          e.angle = toShip + pi;
        } else if (distToShip > e.stalkDistance + 100) {
          // Too far — approach
          var diff = toShip - e.angle;
          while (diff > pi) {
            diff -= pi * 2;
          }
          while (diff < -pi) {
            diff += pi * 2;
          }
          e.angle += diff * 1.5 * dt;
        } else {
          // Good distance — orbit laterally
          var diff = (toShip + pi / 2) - e.angle;
          while (diff > pi) {
            diff -= pi * 2;
          }
          while (diff < -pi) {
            diff += pi * 2;
          }
          e.angle += diff * 1.0 * dt;
        }
        break;
      case EnemyBehavior.swarming:
        // Swarm: cluster toward player and nearby swarmers
        if (distToShip < 800) {
          var diff = toShip - e.angle;
          while (diff > pi) {
            diff -= pi * 2;
          }
          while (diff < -pi) {
            diff += pi * 2;
          }
          e.angle += diff * 3.5 * dt;
        }
        // Flock: gravitate toward nearby swarmers
        double fcx = 0, fcy = 0;
        int flockN = 0;
        for (final other in enemies) {
          if (other == e ||
              other.dead ||
              other.behavior != EnemyBehavior.swarming) {
            continue;
          }
          final fdx2 = other.position.dx - e.position.dx;
          final fdy2 = other.position.dy - e.position.dy;
          if (fdx2 * fdx2 + fdy2 * fdy2 < 200 * 200) {
            fcx += other.position.dx;
            fcy += other.position.dy;
            flockN++;
          }
        }
        if (flockN > 0) {
          final cx2 = fcx / flockN;
          final cy2 = fcy / flockN;
          final toCenter = atan2(cy2 - e.position.dy, cx2 - e.position.dx);
          var fDiff = toCenter - e.angle;
          while (fDiff > pi) {
            fDiff -= pi * 2;
          }
          while (fDiff < -pi) {
            fDiff += pi * 2;
          }
          e.angle += fDiff * 1.5 * dt;
        }
        break;
    }

    // Move
    e.position = _wrap(
      Offset(
        e.position.dx + cos(e.angle) * e.speed * dt,
        e.position.dy + sin(e.angle) * e.speed * dt,
      ),
    );

    // Despawn distance depends on behavior
    final despawnDist = e.whirlIndex >= 0
        ? 4000.0 // whirl enemies persist longer
        : (e.behavior == EnemyBehavior.feeding ||
              e.behavior == EnemyBehavior.territorial)
        ? 2500.0 // persistent near their zone
        : 1500.0;
    if (distToShip > despawnDist) {
      e.dead = true;
    }
  }

  /// Boss lair proximity detection, activation, and respawn logic.
  void _updateBossLairs(double dt) {
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;

    for (final lair in bossLairs) {
      // Tick respawn timers on defeated lairs
      if (lair.state == BossLairState.defeated) {
        lair.respawnTimer -= dt;
      }

      // Check activation: player enters lair radius
      if (lair.state == BossLairState.waiting && activeBoss == null) {
        var dx = lair.position.dx - ship.pos.dx;
        var dy = lair.position.dy - ship.pos.dy;
        if (dx > ww / 2) dx -= ww;
        if (dx < -ww / 2) dx += ww;
        if (dy > wh / 2) dy -= wh;
        if (dy < -wh / 2) dy += wh;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < BossLair.activationRadius) {
          _spawnBossFromLair(lair);
        }
      }
    }

    // Remove fully expired defeated lairs
    bossLairs.removeWhere(
      (l) => l.state == BossLairState.defeated && l.respawnTimer <= 0,
    );

    // Maintain at least 3 waiting boss lairs in the world
    final waitingCount = bossLairs
        .where((l) => l.state == BossLairState.waiting)
        .length;
    if (waitingCount < 3 && activeBoss == null) {
      final needed = 3 - waitingCount;
      for (int i = 0; i < needed; i++) {
        bossLairs.add(
          BossLair.generate(
            rng: Random(),
            worldSize: world_.worldSize,
            planets: world_.planets,
            whirls: galaxyWhirls,
            existing: bossLairs,
          ),
        );
      }
    }

    // Ensure at least 1 dormant whirl exists at all times
    final hasDormant = galaxyWhirls.any((w) => w.state == WhirlState.dormant);
    if (!hasDormant && activeWhirl == null) {
      _respawnWhirl();
    }
  }

  void _spawnBossFromLair(BossLair lair) {
    lair.state = BossLairState.fighting;

    final lvl = lair.level;
    // Level scaling: Lv1=1.0x  Lv5=2.8x  Lv10=5.05x
    final levelScale = 1.0 + (lvl - 1) * 0.45;
    final healthScale = levelScale * (1.0 + _bossesDefeated * 0.08);
    // Speed scales mildly: Lv1=1.0x  Lv10=1.45x
    final speedScale = 1.0 + (lvl - 1) * 0.05;
    // Radius grows slightly with level
    final radiusBonus = (lvl - 1) * 1.5;

    activeBoss = CosmicBoss(
      position: lair.position,
      name: lair.template.name,
      element: lair.template.element,
      level: lvl,
      radius: lair.template.radius + radiusBonus,
      maxHealth: lair.template.health * healthScale,
      speed: lair.template.speed * speedScale,
      angle: Random().nextDouble() * pi * 2,
    );

    final bossTypeTag = switch (bossTypeForLevel(lvl)) {
      BossType.charger => '⚡',
      BossType.gunner => '🔫',
      BossType.warden => '👑',
    };
    onBossSpawned?.call('$bossTypeTag Lv$lvl ${lair.template.name}');
  }

  /// Respawn a single galaxy whirl at a new random position.
  void _respawnWhirl() {
    final rng = Random();
    const margin = 3000.0;
    const minPlanetDist = 2500.0;
    const minWhirlDist = 4000.0;
    final elements = kElementColors.keys.toList();

    Offset pos;
    int tries = 0;
    do {
      pos = Offset(
        margin + rng.nextDouble() * (world_.worldSize.width - margin * 2),
        margin + rng.nextDouble() * (world_.worldSize.height - margin * 2),
      );
      tries++;
    } while (tries < 200 &&
        (world_.planets.any(
              (p) => (p.position - pos).distance < minPlanetDist,
            ) ||
            galaxyWhirls.any(
              (w) => (w.position - pos).distance < minWhirlDist,
            )));

    galaxyWhirls.add(
      GalaxyWhirl(
        position: pos,
        element: elements[rng.nextInt(elements.length)],
        level: rng.nextInt(10) + 1,
        radius: 50 + rng.nextDouble() * 30,
        totalWaves: 3 + rng.nextInt(3),
      ),
    );
  }

  void _spawnBoss() {
    final rng = Random();
    final template = kBossTemplates[rng.nextInt(kBossTemplates.length)];
    final lvl = rng.nextInt(10) + 1; // random level 1-10

    // Spawn near the matching element's planet
    final matchingPlanet = world_.planets.firstWhere(
      (p) => p.element == template.element,
      orElse: () => world_.planets[rng.nextInt(world_.planets.length)],
    );
    final angle = rng.nextDouble() * pi * 2;
    final orbitDist =
        matchingPlanet.radius * 4.0 + 100 + rng.nextDouble() * 200;
    final sx = matchingPlanet.position.dx + cos(angle) * orbitDist;
    final sy = matchingPlanet.position.dy + sin(angle) * orbitDist;
    final pos = _wrap(Offset(sx, sy));

    // Level scaling
    final levelScale = 1.0 + (lvl - 1) * 0.45;
    final healthScale = levelScale * (1.0 + _bossesDefeated * 0.08);
    final speedScale = 1.0 + (lvl - 1) * 0.05;
    final radiusBonus = (lvl - 1) * 1.5;

    activeBoss = CosmicBoss(
      position: pos,
      name: template.name,
      element: template.element,
      level: lvl,
      radius: template.radius + radiusBonus,
      maxHealth: template.health * healthScale,
      speed: template.speed * speedScale,
      angle: rng.nextDouble() * pi * 2,
    );

    final bossTypeTag = switch (bossTypeForLevel(lvl)) {
      BossType.charger => '⚡',
      BossType.gunner => '🔫',
      BossType.warden => '👑',
    };
    onBossSpawned?.call('$bossTypeTag Lv$lvl ${template.name}');
  }

  /// Spawn a guaranteed boss when a planet is first discovered.
  /// Difficulty scales with total number of planets discovered.
  void _spawnDiscoveryBoss(CosmicPlanet planet) {
    if (activeBoss != null) return; // don't override an active boss

    final rng = Random();
    // Find a template matching the planet's element, fallback to random
    final matching = kBossTemplates.where((t) => t.element == planet.element);
    final template = matching.isNotEmpty
        ? matching.elementAt(rng.nextInt(matching.length))
        : kBossTemplates[rng.nextInt(kBossTemplates.length)];

    // Level = number of discovered planets (clamped 1-20)
    final discovered = world_.planets.where((p) => p.discovered).length;
    final lvl = discovered.clamp(1, 20);

    // Spawn near the discovered planet
    final angle = rng.nextDouble() * pi * 2;
    final orbitDist = planet.radius * 4.0 + 100 + rng.nextDouble() * 150;
    final sx = planet.position.dx + cos(angle) * orbitDist;
    final sy = planet.position.dy + sin(angle) * orbitDist;
    final pos = _wrap(Offset(sx, sy));

    // Scaling
    final levelScale = 1.0 + (lvl - 1) * 0.45;
    final healthScale = levelScale * (1.0 + _bossesDefeated * 0.08);
    final speedScale = 1.0 + (lvl - 1) * 0.05;
    final radiusBonus = (lvl - 1) * 1.5;

    activeBoss = CosmicBoss(
      position: pos,
      name: template.name,
      element: template.element,
      level: lvl,
      radius: template.radius + radiusBonus,
      maxHealth: template.health * healthScale,
      speed: template.speed * speedScale,
      angle: rng.nextDouble() * pi * 2,
    );

    final bossTypeTag = switch (bossTypeForLevel(lvl)) {
      BossType.charger => '⚡',
      BossType.gunner => '🔫',
      BossType.warden => '👑',
    };
    onBossSpawned?.call('$bossTypeTag Lv$lvl ${template.name}');
  }

  void _updateBossAI(CosmicBoss boss, double dt) {
    boss.phaseTimer += dt;
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;

    // Shared: wrapped distance & angle to player
    var dx = ship.pos.dx - boss.position.dx;
    var dy = ship.pos.dy - boss.position.dy;
    if (dx > ww / 2) dx -= ww;
    if (dx < -ww / 2) dx += ww;
    if (dy > wh / 2) dy -= wh;
    if (dy < -wh / 2) dy += wh;

    final toShip = atan2(dy, dx);
    final dist = sqrt(dx * dx + dy * dy);

    switch (boss.type) {
      case BossType.charger:
        _updateChargerBoss(boss, dt, toShip, dist);
      case BossType.gunner:
        _updateGunnerBoss(boss, dt, toShip, dist);
      case BossType.warden:
        _updateWardenBoss(boss, dt, toShip, dist);
    }
  }

  // ────────────────────────────────────────────────
  // CHARGER BOSS (Lv 1-3)
  //  Behaviour: approach player, then charge in a straight line,
  //  brief recovery pause, repeat. Contact damage only.
  // ────────────────────────────────────────────────
  void _updateChargerBoss(
    CosmicBoss boss,
    double dt,
    double toShip,
    double dist,
  ) {
    if (boss.charging) {
      // ── Mid-dash: fly in locked direction at high speed ──
      boss.chargeDashTimer -= dt;
      final dashSpeed = boss.baseSpeed * CosmicBoss.chargeSpeedMultiplier;
      boss.position = _wrap(
        Offset(
          boss.position.dx + cos(boss.chargeAngle) * dashSpeed * dt,
          boss.position.dy + sin(boss.chargeAngle) * dashSpeed * dt,
        ),
      );
      if (boss.chargeDashTimer <= 0) {
        boss.charging = false;
        boss.chargeTimer = CosmicBoss.chargeCooldown;
        boss.speed = boss.baseSpeed;
      }
    } else {
      // ── Approach player, turning smoothly ──
      var angleDiff = toShip - boss.angle;
      while (angleDiff > pi) {
        angleDiff -= pi * 2;
      }
      while (angleDiff < -pi) {
        angleDiff += pi * 2;
      }
      boss.angle += angleDiff * 2.5 * dt;

      // Move toward player, settle at ~180 range
      double moveAngle;
      if (dist > 220) {
        moveAngle = toShip;
      } else if (dist < 120) {
        moveAngle = toShip + pi;
      } else {
        moveAngle = toShip + pi / 2;
      }
      boss.position = _wrap(
        Offset(
          boss.position.dx + cos(moveAngle) * boss.speed * dt,
          boss.position.dy + sin(moveAngle) * boss.speed * dt,
        ),
      );

      // ── Charge cooldown ──
      boss.chargeTimer -= dt;
      if (boss.chargeTimer <= 0 && dist < 350 && dist > 80) {
        // Initiate charge!
        boss.charging = true;
        boss.chargeAngle = toShip; // lock direction
        boss.chargeDashTimer = CosmicBoss.chargeDashDuration;
        boss.speed = boss.baseSpeed * CosmicBoss.chargeSpeedMultiplier;
      }
    }
  }

  // ────────────────────────────────────────────────
  // GUNNER BOSS (Lv 4-7)
  //  Behaviour: orbit at range, fire projectiles at player,
  //  periodically raise a shield that absorbs damage.
  // ────────────────────────────────────────────────
  void _updateGunnerBoss(
    CosmicBoss boss,
    double dt,
    double toShip,
    double dist,
  ) {
    // Smooth turn
    var angleDiff = toShip - boss.angle;
    while (angleDiff > pi) {
      angleDiff -= pi * 2;
    }
    while (angleDiff < -pi) {
      angleDiff += pi * 2;
    }
    boss.angle += angleDiff * 2.0 * dt;

    // Orbit at ~280 units
    double moveAngle;
    if (dist > 330) {
      moveAngle = toShip;
    } else if (dist < 220) {
      moveAngle = toShip + pi;
    } else {
      moveAngle = toShip + pi / 2;
    }
    boss.position = _wrap(
      Offset(
        boss.position.dx + cos(moveAngle) * boss.speed * dt,
        boss.position.dy + sin(moveAngle) * boss.speed * dt,
      ),
    );

    // ── Shoot projectiles at player ──
    boss.shootTimer -= dt;
    if (boss.shootTimer <= 0 && dist < 500) {
      boss.shootTimer = CosmicBoss.shootCooldown;
      // Fire 1-2 aimed shots
      final shots = boss.level >= 6 ? 2 : 1;
      for (var s = 0; s < shots; s++) {
        final spread = (s - (shots - 1) / 2) * 0.15;
        bossProjectiles.add(
          BossProjectile(
            position: boss.position,
            angle: toShip + spread,
            element: boss.element,
            damage: 1.0,
            speed: 220 + boss.level * 8.0,
          ),
        );
      }
    }

    // ── Shield mechanic ──
    boss.shieldTimer -= dt;
    if (boss.shieldUp) {
      if (boss.shieldTimer <= 0 || boss.shieldHealth <= 0) {
        boss.shieldUp = false;
        boss.shieldTimer = CosmicBoss.shieldCooldown;
      }
    } else {
      if (boss.shieldTimer <= 0) {
        boss.shieldUp = true;
        boss.shieldHealth = CosmicBoss.shieldMaxHealth;
        boss.shieldTimer = CosmicBoss.shieldDuration;
      }
    }
  }

  // ────────────────────────────────────────────────
  // WARDEN BOSS (Lv 8-10)
  //  Behaviour: fires projectile fans, summons minion enemies,
  //  enrages below 30% HP (faster attacks, speed boost).
  // ────────────────────────────────────────────────
  void _updateWardenBoss(
    CosmicBoss boss,
    double dt,
    double toShip,
    double dist,
  ) {
    // Check for enrage transition
    if (!boss.enraged && boss.healthPct <= CosmicBoss.enrageThreshold) {
      boss.enraged = true;
      boss.speed = boss.baseSpeed * 1.6;
      boss.wardenPhase = 2;
    }

    // Smooth turn
    var angleDiff = toShip - boss.angle;
    while (angleDiff > pi) {
      angleDiff -= pi * 2;
    }
    while (angleDiff < -pi) {
      angleDiff += pi * 2;
    }
    boss.angle += angleDiff * (boss.enraged ? 3.0 : 1.8) * dt;

    // Orbit at ~250 units (closer when enraged)
    final orbitDist = boss.enraged ? 180.0 : 250.0;
    double moveAngle;
    if (dist > orbitDist + 60) {
      moveAngle = toShip;
    } else if (dist < orbitDist - 60) {
      moveAngle = toShip + pi;
    } else {
      moveAngle = toShip + pi / 2;
    }
    boss.position = _wrap(
      Offset(
        boss.position.dx + cos(moveAngle) * boss.speed * dt,
        boss.position.dy + sin(moveAngle) * boss.speed * dt,
      ),
    );

    // ── Projectile fan ──
    final spreadCd = boss.enraged
        ? CosmicBoss.spreadCooldown * 0.5
        : CosmicBoss.spreadCooldown;
    boss.spreadTimer -= dt;
    if (boss.spreadTimer <= 0 && dist < 600) {
      boss.spreadTimer = spreadCd;
      // Fire a fan of 5-8 projectiles (more when enraged)
      final count = boss.enraged ? 8 : 5;
      final arc = boss.enraged ? pi * 0.8 : pi * 0.5;
      for (var i = 0; i < count; i++) {
        final fanAngle = toShip + (i - (count - 1) / 2) * (arc / (count - 1));
        bossProjectiles.add(
          BossProjectile(
            position: boss.position,
            angle: fanAngle,
            element: boss.element,
            damage: boss.enraged ? 1.5 : 1.0,
            speed: 200 + boss.level * 10.0,
            radius: 5.0,
          ),
        );
      }
    }

    // ── Summon minions ──
    final summonCd = boss.enraged
        ? CosmicBoss.summonCooldown * 0.6
        : CosmicBoss.summonCooldown;
    boss.summonTimer -= dt;
    if (boss.summonTimer <= 0 && enemies.length < _maxEnemies) {
      boss.summonTimer = summonCd;
      _spawnWardenMinions(boss);
    }
  }

  /// Spawn 2-4 minion enemies near a Warden boss.
  void _spawnWardenMinions(CosmicBoss boss) {
    final rng = Random();
    final count = boss.enraged ? 4 : 2;
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final dist = boss.radius * 2 + 20 + rng.nextDouble() * 40;
      final pos = _wrap(
        Offset(
          boss.position.dx + cos(angle) * dist,
          boss.position.dy + sin(angle) * dist,
        ),
      );
      final tier = rng.nextDouble() < 0.3 ? EnemyTier.sentinel : EnemyTier.wisp;
      enemies.add(
        CosmicEnemy(
          position: pos,
          element: boss.element,
          tier: tier,
          radius: tier == EnemyTier.wisp
              ? 8 + rng.nextDouble() * 4
              : 14 + rng.nextDouble() * 6,
          health: tier == EnemyTier.wisp ? 2.0 : 5.0,
          speed: 60 + rng.nextDouble() * 40,
          angle: rng.nextDouble() * pi * 2,
          driftTimer: rng.nextDouble() * 2,
          behavior: EnemyBehavior.aggressive,
          provoked: true,
        ),
      );
    }
  }

  /// Update all boss projectiles — move, age, and check collisions with ship.
  void _updateBossProjectiles(double dt) {
    for (var i = bossProjectiles.length - 1; i >= 0; i--) {
      final bp = bossProjectiles[i];
      bp.position = _wrap(
        Offset(
          bp.position.dx + cos(bp.angle) * bp.speed * dt,
          bp.position.dy + sin(bp.angle) * bp.speed * dt,
        ),
      );
      bp.life -= dt;
      if (bp.life <= 0) {
        bossProjectiles.removeAt(i);
        continue;
      }

      // Hit ship?
      if (!_shipDead && _shipInvincible <= 0) {
        final sdx = ship.pos.dx - bp.position.dx;
        final sdy = ship.pos.dy - bp.position.dy;
        final hitR = bp.radius + 14;
        if (sdx * sdx + sdy * sdy < hitR * hitR) {
          _damageShip(bp.damage);
          bossProjectiles.removeAt(i);
        }
      }
    }
  }

  // ── Boss kill helper ──────────────────────────────────

  void _handleBossKill(CosmicBoss boss) {
    boss.dead = true;
    _bossesDefeated++;
    _spawnKillVfx(boss.position, elementColor(boss.element), boss.radius, true);
    _spawnLootDrops(
      boss.position,
      boss.element,
      boss.shardReward,
      boss.particleReward,
    );
    // ── Item drops based on boss level ──
    _spawnBossItemDrops(boss);
    onBossDefeated?.call('Lv${boss.level} ${boss.name}');
  }

  /// Spawn item drops from a defeated boss.
  /// Lv 4-6: small chance for a standard harvester matching boss element.
  /// Lv 7-9: higher chance for harvester + small chance for portal key.
  /// Lv 10: guaranteed harvester + portal key + chance for guaranteed harvester.
  void _spawnBossItemDrops(CosmicBoss boss) {
    final rng = Random();
    final faction = factionForElement(boss.element);
    final harvesterKey = 'item.harvest_std_$faction';
    final portalKey = 'item.portal_key.$faction';

    if (boss.level >= 10) {
      // Lv10: guaranteed standard harvester + portal key
      _spawnItemDrop(boss.position, harvesterKey);
      _spawnItemDrop(boss.position, portalKey);
      // 25% chance for a guaranteed (stabilized) harvester
      if (rng.nextDouble() < 0.25) {
        _spawnItemDrop(boss.position, 'item.harvest_guaranteed');
      }
    } else if (boss.level >= 7) {
      // Lv7-9: 60% harvester, 30% portal key
      if (rng.nextDouble() < 0.60) {
        _spawnItemDrop(boss.position, harvesterKey);
      }
      if (rng.nextDouble() < 0.30) {
        _spawnItemDrop(boss.position, portalKey);
      }
    } else if (boss.level >= 4) {
      // Lv4-6: 25% harvester
      if (rng.nextDouble() < 0.25) {
        _spawnItemDrop(boss.position, harvesterKey);
      }
    }
    // Lv1-3: no item drops (shards + particles only)
  }

  /// Spawn item drops from a completed galaxy whirl (horde).
  /// Lv 4-6: small chance for a harvester.
  /// Lv 7-9: decent chance for harvester.
  /// Lv 10: guaranteed harvester + portal key + chance for stabilized harvester.
  void _spawnWhirlItemDrops(GalaxyWhirl whirl) {
    final rng = Random();
    final faction = factionForElement(whirl.element);
    final harvesterKey = 'item.harvest_std_$faction';
    final portalKey = 'item.portal_key.$faction';

    if (whirl.level >= 10) {
      // Lv10: guaranteed harvester + portal key
      _spawnItemDrop(whirl.position, harvesterKey);
      _spawnItemDrop(whirl.position, portalKey);
      // 15% chance for stabilized harvester (slightly lower than boss)
      if (rng.nextDouble() < 0.15) {
        _spawnItemDrop(whirl.position, 'item.harvest_guaranteed');
      }
    } else if (whirl.level >= 7) {
      // Lv7-9: 40% harvester, 15% portal key
      if (rng.nextDouble() < 0.40) {
        _spawnItemDrop(whirl.position, harvesterKey);
      }
      if (rng.nextDouble() < 0.15) {
        _spawnItemDrop(whirl.position, portalKey);
      }
    } else if (whirl.level >= 4) {
      // Lv4-6: 15% harvester
      if (rng.nextDouble() < 0.15) {
        _spawnItemDrop(whirl.position, harvesterKey);
      }
    }
  }

  /// Spawn a single collectible item drop at a position.
  void _spawnItemDrop(Offset pos, String itemKey) {
    final rng = Random();
    final angle = rng.nextDouble() * pi * 2;
    final speed = 40.0 + rng.nextDouble() * 50;
    final isPortalKey = itemKey.contains('portal_key');
    final isGuaranteed = itemKey.contains('guaranteed');
    final color = isGuaranteed
        ? const Color(0xFFFFD700) // gold
        : isPortalKey
        ? const Color(0xFF00E5FF) // cyan
        : const Color(0xFF76FF03); // green
    lootDrops.add(
      LootDrop(
        position: Offset(pos.dx + cos(angle) * 12, pos.dy + sin(angle) * 12),
        velocity: Offset(cos(angle) * speed, sin(angle) * speed),
        type: LootType.item,
        amount: 1,
        itemKey: itemKey,
        color: color,
      ),
    );
  }

  // ── VFX helpers ────────────────────────────────────────

  void _spawnKillVfx(Offset pos, Color color, double radius, bool isBoss) {
    final rng = Random();
    final count = isBoss ? 40 : 14;
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final speed = (isBoss ? 150.0 : 100.0) + rng.nextDouble() * 200;
      final pSize = radius * (0.1 + rng.nextDouble() * 0.25);
      final c = rng.nextBool() ? color : Colors.white;
      vfxParticles.add(
        VfxParticle(
          x: pos.dx,
          y: pos.dy,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          size: pSize,
          life: 0.5 + rng.nextDouble() * 0.4,
          color: c,
        ),
      );
    }
    // Shock ring(s)
    final ringCount = isBoss ? 3 : 1;
    for (var r = 0; r < ringCount; r++) {
      vfxRings.add(
        VfxShockRing(
          x: pos.dx,
          y: pos.dy,
          maxRadius: radius * (isBoss ? 6.0 + r * 2 : 4.0),
          color: color,
          expandSpeed: isBoss ? 500.0 : 350.0,
        ),
      );
    }
  }

  /// Spawn loot drops at a position (from enemy/boss death).
  void _spawnLootDrops(
    Offset pos,
    String element,
    int shardAmount,
    double particleAmount,
  ) {
    final rng = Random();

    // Astral Shards — 1-3 individual crystal drops
    if (shardAmount > 0) {
      final shardDrops = shardAmount.clamp(1, 3);
      final shardPer = (shardAmount / shardDrops).ceil();
      for (var i = 0; i < shardDrops; i++) {
        final angle = rng.nextDouble() * pi * 2;
        final speed = 50.0 + rng.nextDouble() * 60;
        lootDrops.add(
          LootDrop(
            position: Offset(pos.dx + cos(angle) * 8, pos.dy + sin(angle) * 8),
            velocity: Offset(cos(angle) * speed, sin(angle) * speed),
            type: LootType.astralShard,
            amount: i < shardDrops - 1
                ? shardPer
                : shardAmount - shardPer * (shardDrops - 1),
            color: const Color(0xFF7C4DFF),
          ),
        );
      }
    }

    // Element particles — sometimes drop (40% chance from enemies, always from bosses)
    if (particleAmount > 0) {
      final shouldDrop = shardAmount >= 10 || rng.nextDouble() < 0.4;
      if (shouldDrop) {
        final elemDrops = particleAmount <= 3 ? particleAmount.ceil() : 3;
        final elemPer = (particleAmount / elemDrops).ceil();
        for (var i = 0; i < elemDrops; i++) {
          final angle = rng.nextDouble() * pi * 2;
          final speed = 60.0 + rng.nextDouble() * 70;
          lootDrops.add(
            LootDrop(
              position: Offset(
                pos.dx + cos(angle) * 10,
                pos.dy + sin(angle) * 10,
              ),
              velocity: Offset(cos(angle) * speed, sin(angle) * speed),
              type: LootType.elementParticle,
              amount: i < elemDrops - 1
                  ? elemPer
                  : particleAmount.ceil() - elemPer * (elemDrops - 1),
              element: element,
              color: elementColor(element),
            ),
          );
        }
      }
    }

    // Health recovery orb — small chance for regular enemies, higher for bosses
    // Regular enemies: ~8% chance. Bosses (large shard drops): ~50% chance.
    final hpDropChance = shardAmount >= 10 ? 0.5 : 0.08;
    if (rng.nextDouble() < hpDropChance) {
      final angle = rng.nextDouble() * pi * 2;
      final speed = 50.0 + rng.nextDouble() * 60;
      lootDrops.add(
        LootDrop(
          position: Offset(pos.dx + cos(angle) * 8, pos.dy + sin(angle) * 8),
          velocity: Offset(cos(angle) * speed, sin(angle) * speed),
          type: LootType.healthOrb,
          amount: 1,
          color: const Color(0xFFFF6D6D), // soft red for health
        ),
      );
    }
  }

  // ── prismatic field rendering (aurora / northern lights) ──
  void _renderPrismaticField(
    Canvas canvas,
    double cx,
    double cy,
    double screenW,
    double screenH,
  ) {
    final pf = prismaticField;
    final pp = pf.position;
    // Early-out if the field is fully off-screen
    if ((pp.dx - cx - screenW / 2).abs() > screenW / 2 + pf.radius + 200 ||
        (pp.dy - cy - screenH / 2).abs() > screenH / 2 + pf.radius + 200) {
      return;
    }

    final t = pf.life;

    // ── Cached render-to-texture for expensive blurred layers ──
    // Only rebuild the cached image every _prismaticCacheInterval seconds.
    if (_prismaticCachedImage == null ||
        (t - _prismaticCacheLife).abs() >= _prismaticCacheInterval) {
      _prismaticCachedImage?.dispose();
      _prismaticCachedImage = _buildPrismaticTexture(t, pf);
      _prismaticCacheLife = t;
    }

    // Draw the cached texture scaled to world coordinates
    final img = _prismaticCachedImage!;
    final texR =
        pf.radius + 80; // padding matches what _buildPrismaticTexture uses
    canvas.save();
    canvas.translate(pp.dx - texR, pp.dy - texR);
    canvas.scale(texR * 2 / _prismaticTexSize, texR * 2 / _prismaticTexSize);
    canvas.drawImage(img, Offset.zero, Paint());
    canvas.restore();

    // ── Central prismatic ring (drawn every frame at full resolution) ──
    final ringR = pf.radius * 0.12;
    final cRingRotation = t * 0.5;
    canvas.save();
    canvas.translate(pp.dx, pp.dy);
    canvas.rotate(cRingRotation);
    canvas.drawCircle(
      Offset.zero,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..shader = ui.Gradient.sweep(
          Offset.zero,
          [
            for (int i = 0; i <= 8; i++)
              PrismaticField.auroraColors[i % 8].withValues(
                alpha: 0.35 + 0.15 * sin(t * 1.2 + i * 0.9),
              ),
          ],
          [for (int i = 0; i <= 8; i++) i / 8.0],
        ),
    );
    // Inner glow fill
    canvas.drawCircle(
      Offset.zero,
      ringR,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          ringR,
          [
            PrismaticField.auroraColors[((t * 0.15).floor()) % 8].withValues(
              alpha: 0.05,
            ),
            const Color(0x00000000),
          ],
          [0.0, 1.0],
        ),
    );
    canvas.restore();
    // 3 orbiting dots around the ring
    for (int d = 0; d < 3; d++) {
      final dAngle = t * 0.8 + d * pi * 2 / 3;
      final dx2 = pp.dx + cos(dAngle) * ringR;
      final dy2 = pp.dy + sin(dAngle) * ringR;
      canvas.drawCircle(
        Offset(dx2, dy2),
        2.0,
        Paint()
          ..color = PrismaticField.auroraColors[(d * 2 + (t * 0.2).floor()) % 8]
              .withValues(alpha: 0.45),
      );
    }

    // ── Label (drawn every frame) ──
    if (!prismaticRewardClaimed) {
      final ci = ((t * 0.3).floor()) % 8;
      final labelColor = Color.lerp(
        PrismaticField.auroraColors[ci],
        PrismaticField.auroraColors[(ci + 1) % 8],
        (t * 0.3) % 1.0,
      )!.withValues(alpha: 0.7);
      final labelTp = TextPainter(
        text: TextSpan(
          text: 'PRISMATIC AURORA',
          style: TextStyle(
            color: labelColor,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelTp.paint(
        canvas,
        Offset(pp.dx - labelTp.width / 2, pp.dy + pf.radius + 14),
      );
    }
  }

  /// Renders the expensive blurred aurora layers to a [_prismaticTexSize]²
  /// off-screen image. Called ~10 times/sec, NOT every frame.
  ui.Image _buildPrismaticTexture(double t, PrismaticField pf) {
    const sz = _prismaticTexSize;
    final texR = pf.radius + 80; // world-unit radius mapped to texture
    final scale = sz / (texR * 2);
    final center = Offset(sz / 2, sz / 2);

    final recorder = ui.PictureRecorder();
    final c = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, sz.toDouble(), sz.toDouble()),
    );

    // All drawing is in texture-pixel space; center = field center.

    // ── 1. Soft radial glow with blur ──
    final glowR = pf.radius * scale;
    c.drawCircle(
      center,
      glowR,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40)
        ..shader = ui.Gradient.radial(
          center,
          glowR,
          [
            PrismaticField.auroraColors[((t * 0.08).floor()) % 8].withValues(
              alpha: 0.08,
            ),
            PrismaticField.auroraColors[((t * 0.08).floor() + 3) % 8]
                .withValues(alpha: 0.04),
            const Color(0x00000000),
          ],
          [0.0, 0.6, 1.0],
        ),
    );

    // ── 2. Aurora bands with blur (6 bands, lush look) ──
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: glowR)));
    for (int band = 0; band < 6; band++) {
      final bandPhase = band * 1.1 + t * 0.35;
      final colorIdx = ((band * 2 + (t * 0.08).floor()) % 8);
      final bandColor = PrismaticField.auroraColors[colorIdx].withValues(
        alpha: 0.06 + 0.03 * sin(t * 0.4 + band),
      );

      final path = Path();
      final bandY = center.dy - glowR * 0.7 + band * (glowR * 0.22);
      const segments = 16;
      for (int s = 0; s <= segments; s++) {
        final frac = s / segments;
        final x = center.dx - glowR + frac * glowR * 2;
        final y =
            bandY +
            sin(frac * pi * 3 + bandPhase) * glowR * 0.15 +
            sin(frac * pi * 5 + bandPhase * 1.3) * glowR * 0.06;
        if (s == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      for (int s = segments; s >= 0; s--) {
        final frac = s / segments;
        final x = center.dx - glowR + frac * glowR * 2;
        final y =
            bandY +
            glowR * 0.12 +
            sin(frac * pi * 3 + bandPhase + 0.5) * glowR * 0.08;
        path.lineTo(x, y);
      }
      path.close();
      c.drawPath(
        path,
        Paint()
          ..color = bandColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
    c.restore();

    // ── 3. Sparkles with blur ──
    final sparkRng = Random(42);
    for (int i = 0; i < 30; i++) {
      final sAngle = sparkRng.nextDouble() * pi * 2;
      final sDist = sparkRng.nextDouble() * glowR * 0.85;
      final sx = center.dx + cos(sAngle + t * 0.03 * (i % 3 + 1)) * sDist;
      final sy = center.dy + sin(sAngle + t * 0.02 * (i % 4 + 1)) * sDist;
      final sBright = (0.3 + 0.7 * sin(t * (1.0 + i * 0.15) + i)).clamp(
        0.0,
        1.0,
      );
      if (sBright < 0.2) continue;
      c.drawCircle(
        Offset(sx, sy),
        2.0 + sBright * 2.5,
        Paint()
          ..color = PrismaticField.auroraColors[i % 8].withValues(
            alpha: sBright * 0.5,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // ── 4. Edge ring with blur ──
    c.drawCircle(
      center,
      glowR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..shader = ui.Gradient.sweep(
          center,
          [
            for (int i = 0; i <= 8; i++)
              PrismaticField.auroraColors[i % 8].withValues(
                alpha: 0.15 + 0.08 * sin(t * 0.6 + i * 0.8),
              ),
          ],
          [for (int i = 0; i <= 8; i++) i / 8.0],
        ),
    );

    // ── 5. Light pillars (vertical glowing columns) ──
    for (int p = 0; p < 4; p++) {
      final px = center.dx - glowR * 0.6 + p * (glowR * 0.4);
      final pillarAlpha = 0.04 + 0.03 * sin(t * 0.3 + p * 1.5);
      c.drawRect(
        Rect.fromCenter(
          center: Offset(px, center.dy),
          width: glowR * 0.08,
          height: glowR * 1.6,
        ),
        Paint()
          ..color = PrismaticField.auroraColors[(p * 2 + (t * 0.1).floor()) % 8]
              .withValues(alpha: pillarAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(sz, sz);
    picture.dispose();
    return image;
  }

  /// Renders the expensive blurred layers of the elemental nexus portal to an
  /// off-screen texture at ~10 fps. The gravitational well glow (blur 200),
  /// orbiting elemental glows (blur 30 × 4), void core gradient, and pulsing
  /// rings (blur 15 × 4) are all drawn here.
  ui.Image _buildNexusTexture(double riftPulse) {
    const sz = _nexusTexSize;
    const worldR = _nexusTexWorldR;
    final scale = sz / (worldR * 2);
    final center = Offset(sz / 2, sz / 2);

    final recorder = ui.PictureRecorder();
    final c = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, sz.toDouble(), sz.toDouble()),
    );

    final pulse = 0.85 + 0.15 * sin(riftPulse * 1.8);

    // Huge dark gravitational well glow
    c.drawCircle(
      center,
      600 * scale,
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 200 * scale),
    );

    // Four elemental glows orbiting
    const eColors = [
      Color(0xFFFF5722), // Fire
      Color(0xFF448AFF), // Water
      Color(0xFF81D4FA), // Air
      Color(0xFF795548), // Earth
    ];
    for (var i = 0; i < 4; i++) {
      final a = riftPulse * 0.6 + i * pi / 2;
      final orbitR = (400.0 + 50 * sin(riftPulse * 2 + i)) * scale;
      final gx = center.dx + cos(a) * orbitR;
      final gy = center.dy + sin(a) * orbitR;
      c.drawCircle(
        Offset(gx, gy),
        40 * pulse * scale,
        Paint()
          ..color = eColors[i].withValues(alpha: 0.45 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 30 * scale),
      );
    }

    // Void core
    c.drawCircle(
      center,
      275 * pulse * scale,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          275 * pulse * scale,
          [
            const Color(0xFF000000),
            const Color(0xFF000000),
            const Color(0xFF0A0015),
          ],
          [0.0, 0.6, 1.0],
        ),
    );

    // Pulsing dark rings with multi-element shimmer
    for (var i = 0; i < 4; i++) {
      final ringR = (300.0 + i * 90 + 30 * sin(riftPulse * 2.5 + i)) * scale;
      c.drawCircle(
        center,
        ringR,
        Paint()
          ..color = eColors[i].withValues(alpha: 0.18 - i * 0.03)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12.5 * scale
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 * scale),
      );
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(sz, sz);
    picture.dispose();
    return image;
  }

  /// Renders the battle ring octagon + orbiting balls to an off-screen texture.
  ui.Image _buildBattleRingTexture(double riftPulse) {
    const sz = _battleRingTexSize;
    const worldR = _battleRingTexWorldR;
    final scale = sz / (worldR * 2);
    final center = Offset(sz / 2, sz / 2);

    final recorder = ui.PictureRecorder();
    final c = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, sz.toDouble(), sz.toDouble()),
    );

    final pulse = 0.85 + 0.15 * sin(riftPulse * 1.5);
    const octR = BattleRing.visualRadius; // world-unit octagon radius

    // Subtle arena floor glow
    c.drawCircle(
      center,
      octR * 0.8 * scale,
      Paint()
        ..color = const Color(0xFF1A0A2E).withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 80 * scale),
    );

    // Octagon outline with golden glow
    final octPath = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 - pi / 8; // start rotated for flat top
      final x = center.dx + cos(a) * octR * scale;
      final y = center.dy + sin(a) * octR * scale;
      if (i == 0) {
        octPath.moveTo(x, y);
      } else {
        octPath.lineTo(x, y);
      }
    }
    octPath.close();

    // Outer glow
    c.drawPath(
      octPath,
      Paint()
        ..color = const Color(0xFFFFD740).withValues(alpha: 0.25 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18 * scale
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * scale),
    );

    // Main ring stroke
    c.drawPath(
      octPath,
      Paint()
        ..color = const Color(0xFFFFD740).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * scale,
    );

    // Inner glow ring (slightly smaller octagon)
    final innerPath = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 - pi / 8;
      final x = center.dx + cos(a) * octR * 0.85 * scale;
      final y = center.dy + sin(a) * octR * 0.85 * scale;
      if (i == 0) {
        innerPath.moveTo(x, y);
      } else {
        innerPath.lineTo(x, y);
      }
    }
    innerPath.close();
    c.drawPath(
      innerPath,
      Paint()
        ..color = const Color(0xFFFF6F00).withValues(alpha: 0.15 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * scale
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * scale),
    );

    // 8 orbiting energy balls around the octagon
    const ballColors = [
      Color(0xFFFF5252), // red
      Color(0xFF448AFF), // blue
      Color(0xFF69F0AE), // green
      Color(0xFFFFD740), // gold
      Color(0xFFE040FB), // magenta
      Color(0xFF00E5FF), // cyan
      Color(0xFFFF6E40), // deep orange
      Color(0xFFB388FF), // purple
    ];
    for (var i = 0; i < 8; i++) {
      final baseAngle = i * pi / 4;
      final a = baseAngle + riftPulse * 0.8 + sin(riftPulse * 1.2 + i) * 0.15;
      final orbitR = (octR + 60 + 15 * sin(riftPulse * 2.0 + i * 0.7)) * scale;
      final bx = center.dx + cos(a) * orbitR;
      final by = center.dy + sin(a) * orbitR;
      // Glow
      c.drawCircle(
        Offset(bx, by),
        18 * pulse * scale,
        Paint()
          ..color = ballColors[i].withValues(alpha: 0.4 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * scale),
      );
      // Core
      c.drawCircle(
        Offset(bx, by),
        6 * scale,
        Paint()..color = ballColors[i].withValues(alpha: 0.9),
      );
    }

    // Corner accents at each octagon vertex
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 - pi / 8;
      final vx = center.dx + cos(a) * octR * scale;
      final vy = center.dy + sin(a) * octR * scale;
      c.drawCircle(
        Offset(vx, vy),
        8 * pulse * scale,
        Paint()
          ..color = const Color(0xFFFFD740).withValues(alpha: 0.6 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * scale),
      );
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(sz, sz);
    picture.dispose();
    return image;
  }

  /// Renders the pocket dimension blurred elements to an off-screen texture.
  ui.Image _buildPocketTexture(double riftPulse) {
    const sz = _pocketTexSize;
    // We need to cover the pocket radius + some margin
    final worldR = ElementalNexus.pocketRadius + 200;
    final scale = sz / (worldR * 2);
    final center = Offset(sz / 2, sz / 2);

    final recorder = ui.PictureRecorder();
    final c = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, sz.toDouble(), sz.toDouble()),
    );

    final pulse = 0.85 + 0.15 * sin(riftPulse * 2.0);

    // Pocket boundary glow (faint ring)
    c.drawCircle(
      center,
      ElementalNexus.pocketRadius * scale,
      Paint()
        ..color = const Color(0xFF7C4DFF).withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 40 * scale
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 30 * scale),
    );

    // 4 elemental portal glows (only the blurred outer glow + rim ring)
    final portals = ElementalNexus.pocketPortalPositions(Offset.zero);
    const portalColors = [
      Color(0xFFFF5722), // Fire
      Color(0xFF448AFF), // Water
      Color(0xFF795548), // Earth
      Color(0xFF81D4FA), // Air
    ];
    for (var i = 0; i < 4; i++) {
      final pp = Offset(
        center.dx + portals[i].dx * scale,
        center.dy + portals[i].dy * scale,
      );
      final col = portalColors[i];

      // Outer glow
      c.drawCircle(
        pp,
        80 * scale,
        Paint()
          ..color = col.withValues(alpha: 0.2 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 25 * scale),
      );

      // Rim ring with blur
      c.drawCircle(
        pp,
        50 * pulse * scale,
        Paint()
          ..color = col.withValues(alpha: 0.4 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * scale
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * scale),
      );
    }

    // Center marker glow
    c.drawCircle(
      center,
      20 * scale,
      Paint()
        ..color = const Color(0xFF7C4DFF).withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * scale),
    );

    final picture = recorder.endRecording();
    final image = picture.toImageSync(sz, sz);
    picture.dispose();
    return image;
  }

  void _spawnHitSpark(Offset pos, Color color) {
    final rng = Random();
    for (var i = 0; i < 5; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final speed = 50.0 + rng.nextDouble() * 80;
      vfxParticles.add(
        VfxParticle(
          x: pos.dx,
          y: pos.dy,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          size: 1.5 + rng.nextDouble() * 1.5,
          life: 0.2 + rng.nextDouble() * 0.15,
          color: color,
          drag: 0.88,
        ),
      );
    }
  }

  /// Spawn explosion projectiles when a decoy is destroyed.
  void _spawnDecoyExplosion(Projectile decoy) {
    final pos = decoy.position;
    final count = decoy.deathExplosionCount;
    final dmg = decoy.deathExplosionDamage;
    final color = elementColor(decoy.element ?? 'Fire');

    // VFX: big explosion effect
    _spawnKillVfx(pos, color, 20, true);

    // Spawn damage projectiles in a ring
    for (var i = 0; i < count; i++) {
      final a = i * (pi * 2 / count);
      companionProjectiles.add(
        Projectile(
          position: Offset(pos.dx + cos(a) * 8, pos.dy + sin(a) * 8),
          angle: a,
          element: decoy.element,
          damage: dmg,
          life: 1.5,
          speedMultiplier: 0.8,
          radiusMultiplier: decoy.deathExplosionRadius,
          piercing: true,
          visualScale: 1.3,
        ),
      );
    }
  }

  void _damageShip(double damage) {
    if (_shipDead || _shipInvincible > 0) return;
    shipHealth -= damage;
    _shipInvincible = 0.5; // brief invincibility after hit

    // Hit flash particles around ship
    _spawnHitSpark(ship.pos, Colors.redAccent);

    if (shipHealth <= 0) {
      shipHealth = 0;
      _shipDead = true;
      _respawnTimer = 2.5; // 2.5s respawn delay
      shooting = false;
      // Death explosion
      _spawnKillVfx(ship.pos, const Color(0xFF00E5FF), 18, true);
      // Reset meter
      meter.reset();
      onMeterChanged();
      // Lose all unbanked Astral Shards on death.
      shipWallet.depositAll();
      onShipDied?.call();
    }
  }

  /// Percentage of world discovered (for display).
  double get discoveryPct {
    final totalCells =
        (world_.worldSize.width / fogCellSize).ceil() *
        (world_.worldSize.height / fogCellSize).ceil();
    if (totalCells == 0) return 0;
    return revealedCells.length / totalCells;
  }

  /// Get fog state for persistence.
  CosmicFogState getFogState(int seed) => CosmicFogState(
    worldSeed: seed,
    discoveredIndices: world_.planets.indexed
        .where((e) => e.$2.discovered)
        .map((e) => e.$1)
        .toSet(),
    discoveredPoiIndices: spacePOIs.indexed
        .where((e) => e.$2.discovered)
        .map((e) => e.$1)
        .toSet(),
    discoveredContestArenaIndices: world_.contestArenas.indexed
        .where((e) => e.$2.discovered)
        .map((e) => e.$1)
        .toSet(),
    revealedCells: Set<int>.from(revealedCells),
    shipX: ship.pos.dx,
    shipY: ship.pos.dy,
  );

  /// Restore fog state — planets, revealed cells, and ship position.
  void restoreFogState(CosmicFogState state) {
    for (final idx in state.discoveredIndices) {
      if (idx < world_.planets.length) {
        world_.planets[idx].discovered = true;
      }
    }
    for (final idx in state.discoveredPoiIndices) {
      if (idx < spacePOIs.length) {
        spacePOIs[idx].discovered = true;
      }
    }
    for (final idx in state.discoveredContestArenaIndices) {
      if (idx < world_.contestArenas.length) {
        world_.contestArenas[idx].discovered = true;
      }
    }
    // Restore ALL revealed cells directly
    revealedCells.addAll(state.revealedCells);
    // Restore ship position
    if (state.shipX >= 0 && state.shipY >= 0) {
      ship.pos = Offset(state.shipX, state.shipY);
    }
  }

  /// Restore collected star dust from persisted set.
  void restoreStarDust(Set<int> collected) {
    for (final dust in starDusts) {
      if (collected.contains(dust.index)) {
        dust.collected = true;
      }
    }
    collectedDustCount = collected.length;
    syncStarDustScannerAvailability();
  }

  /// Restore already-collected contest hint notes from persisted IDs.
  void restoreCollectedContestHints(Set<String> collectedIds) {
    if (collectedIds.isEmpty) return;
    for (final note in contestHintNotes) {
      if (collectedIds.contains(note.id)) {
        note.collected = true;
      }
    }
  }

  bool get hasRemainingStarDust => collectedDustCount < starDusts.length;

  int? get starDustScannerTargetIndex => _starDustScannerTargetIndex;

  StarDust? get starDustScannerTarget {
    final idx = _starDustScannerTargetIndex;
    if (idx == null || idx < 0 || idx >= starDusts.length) return null;
    final dust = starDusts[idx];
    return dust.collected ? null : dust;
  }

  int? consumeCompletedScannerDustIndex() {
    final idx = _scannerCompletedDustIndex;
    _scannerCompletedDustIndex = null;
    return idx;
  }

  String? activateStarDustScanner({int shardCost = 50}) {
    syncStarDustScannerAvailability();
    final scanner = _findStarDustScannerPoi();
    if (scanner == null) {
      return 'All star dust has been collected. Scanner offline.';
    }
    if (!hasRemainingStarDust) {
      return 'All star dust has been collected. Scanner offline.';
    }
    if (_starDustScannerTargetIndex != null) {
      return 'Scanner already locked. Follow the radar beeper to your target.';
    }
    if (shipWallet.shards < shardCost) {
      return 'Not enough shards. Need $shardCost to activate the scanner.';
    }

    final target = _nearestUncollectedStarDust();
    if (target == null) {
      return 'No uncollected star dust found.';
    }

    shipWallet.shards -= shardCost;
    _starDustScannerTargetIndex = target.index;
    _relocateStarDustScanner(scanner);
    return null;
  }

  /// Get the nearest rift portal the ship is close to (if any).
  RiftPortal? get nearestRift => _nearestRift;

  /// Check if ship is near any rift portal.
  bool get isNearRift => _nearestRift != null;

  /// Check if ship is near the elemental nexus portal.
  bool get isNearNexus => _isNearNexus;

  // ─────────────────────────────────────────────────────────
  // NEXUS POCKET DIMENSION
  // ─────────────────────────────────────────────────────────

  /// Enter the pocket dimension — call from cosmic_screen.
  void enterNexusPocket() {
    final nx = elementalNexus;
    nx.prePocketShipPos = ship.pos;
    nx.inPocket = true;
    nx.phase = NexusPhase.choosingPortal;
    inNexusPocket = true;
    // Teleport ship to nexus center
    ship.pos = nx.position;
    _dragTarget = null;
    joystickDirection = null;
  }

  /// Exit the pocket dimension — returns ship to pre-pocket position.
  void exitNexusPocket() {
    final nx = elementalNexus;
    if (nx.prePocketShipPos != null) {
      ship.pos = nx.prePocketShipPos!;
    }
    nx.inPocket = false;
    nx.phase = NexusPhase.outside;
    nx.chosenElement = null;
    nx.harvesterAwarded = false;
    inNexusPocket = false;
    nearPocketPortalElement = null;
    _dragTarget = null;
    joystickDirection = null;
  }

  void _updatePocketMode(double dt) {
    _riftPulse += dt; // for animation

    final center = elementalNexus.position;
    // Clamp ship within pocket radius
    final dx = ship.pos.dx - center.dx;
    final dy = ship.pos.dy - center.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist > ElementalNexus.pocketRadius) {
      final scale = ElementalNexus.pocketRadius / dist;
      ship.pos = Offset(center.dx + dx * scale, center.dy + dy * scale);
    }

    // Check proximity to pocket portals
    final portals = ElementalNexus.pocketPortalPositions(center);
    String? closest;
    double closestDist = double.infinity;
    for (var i = 0; i < 4; i++) {
      final pd = (portals[i] - ship.pos).distance;
      if (pd < ElementalNexus.portalInteractR && pd < closestDist) {
        closestDist = pd;
        closest = ElementalNexus.pocketElements[i];
      }
    }
    if (closest != nearPocketPortalElement) {
      nearPocketPortalElement = closest;
      onNearPocketPortal?.call(closest);
    }
  }

  void _renderPocket(Canvas canvas) {
    final center = elementalNexus.position;
    final cx = camX;
    final cy = camY;
    final screenW = size.x;
    final screenH = size.y;

    canvas.save();
    canvas.translate(-cx, -cy);

    // Dark void background
    canvas.drawRect(
      Rect.fromLTWH(cx, cy, screenW, screenH),
      Paint()..color = const Color(0xFF020008),
    );

    // Subtle ambient stars
    final rng = Random(42);
    final starPaint = Paint();
    for (var i = 0; i < 60; i++) {
      final sx =
          center.dx +
          (rng.nextDouble() - 0.5) * ElementalNexus.pocketRadius * 2.5;
      final sy =
          center.dy +
          (rng.nextDouble() - 0.5) * ElementalNexus.pocketRadius * 2.5;
      final twinkle = 0.3 + 0.7 * sin(_elapsed * (0.5 + rng.nextDouble()) + i);
      starPaint.color = Colors.white.withValues(
        alpha: (0.1 + rng.nextDouble() * 0.2) * twinkle,
      );
      canvas.drawCircle(
        Offset(sx, sy),
        0.8 + rng.nextDouble() * 1.2,
        starPaint,
      );
    }

    // ── Cached blurred layers (boundary glow, portal glows, rim rings, center glow) ──
    if (_pocketCachedImage == null ||
        (_riftPulse - _pocketCacheTime).abs() >= _pocketCacheInterval) {
      _pocketCachedImage?.dispose();
      _pocketCachedImage = _buildPocketTexture(_riftPulse);
      _pocketCacheTime = _riftPulse;
    }

    final pocketWorldR = ElementalNexus.pocketRadius + 200;
    final img = _pocketCachedImage!;
    canvas.save();
    canvas.translate(center.dx - pocketWorldR, center.dy - pocketWorldR);
    canvas.scale(
      pocketWorldR * 2 / _pocketTexSize,
      pocketWorldR * 2 / _pocketTexSize,
    );
    canvas.drawImage(img, Offset.zero, Paint());
    canvas.restore();

    // ── Per-frame elements (cheap: no blur) ──
    final pulse = 0.85 + 0.15 * sin(_riftPulse * 2.0);

    // 4 elemental portals — dark cores, orbiting sparks, labels
    final portals = ElementalNexus.pocketPortalPositions(center);
    const portalColors = [
      Color(0xFFFF5722), // Fire
      Color(0xFF448AFF), // Water
      Color(0xFF795548), // Earth
      Color(0xFF81D4FA), // Air
    ];
    const portalLabels = ['FIRE', 'WATER', 'EARTH', 'AIR'];

    for (var i = 0; i < 4; i++) {
      final pp = portals[i];
      final col = portalColors[i];

      // Dark core (gradient, no blur)
      canvas.drawCircle(
        pp,
        45 * pulse,
        Paint()
          ..shader = ui.Gradient.radial(
            pp,
            45 * pulse,
            [const Color(0xFF000000), col.withValues(alpha: 0.15)],
            [0.0, 1.0],
          ),
      );

      // Orbiting sparks (tiny dots, no blur)
      for (var j = 0; j < 5; j++) {
        final a = _riftPulse * 1.2 + j * pi * 2 / 5 + i * pi / 4;
        final sr = 55.0;
        canvas.drawCircle(
          Offset(pp.dx + cos(a) * sr, pp.dy + sin(a) * sr),
          3 * pulse,
          Paint()..color = col.withValues(alpha: 0.5 * pulse),
        );
      }

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: portalLabels[i],
          style: TextStyle(
            color: col.withValues(alpha: 0.85),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pp.dx - tp.width / 2, pp.dy + 60));
    }

    // Center marker dot (no blur)
    canvas.drawCircle(
      center,
      6,
      Paint()..color = const Color(0xFF7C4DFF).withValues(alpha: 0.3),
    );

    // Ship
    if (!_shipDead) {
      ship.render(canvas, _elapsed, skin: activeShipSkin);
    }

    canvas.restore();
  }

  SpacePOI? _findStarDustScannerPoi() {
    for (final poi in spacePOIs) {
      if (poi.type == POIType.stardustScanner) return poi;
    }
    return null;
  }

  StarDust? _nearestUncollectedStarDust() {
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    StarDust? best;
    double bestDist = double.infinity;
    for (final dust in starDusts) {
      if (dust.collected) continue;
      var dx = dust.position.dx - ship.pos.dx;
      var dy = dust.position.dy - ship.pos.dy;
      if (dx > ww / 2) dx -= ww;
      if (dx < -ww / 2) dx += ww;
      if (dy > wh / 2) dy -= wh;
      if (dy < -wh / 2) dy += wh;
      final d = sqrt(dx * dx + dy * dy);
      if (d < bestDist) {
        bestDist = d;
        best = dust;
      }
    }
    return best;
  }

  void syncStarDustScannerAvailability() {
    final scanner = _findStarDustScannerPoi();
    if (!hasRemainingStarDust) {
      if (scanner != null) {
        spacePOIs.remove(scanner);
      }
      _starDustScannerTargetIndex = null;
      if (nearMarket?.type == POIType.stardustScanner) {
        nearMarket = null;
        onNearMarket?.call(null);
      }
      return;
    }

    if (scanner == null) {
      final newScanner = SpacePOI(
        position: ship.pos,
        type: POIType.stardustScanner,
        element: 'Light',
        radius: 120,
        discovered: false,
      );
      spacePOIs.add(newScanner);
      _relocateStarDustScanner(newScanner);
    }
  }

  void _relocateStarDustScanner(SpacePOI scanner) {
    final rng = Random();
    const margin = 2200.0;
    const minPlanetDist = 2600.0;
    const minPoiDist = 2200.0;
    const minShipDist = 7000.0;
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;

    Offset pos;
    int tries = 0;
    do {
      pos = Offset(
        margin + rng.nextDouble() * (ww - margin * 2),
        margin + rng.nextDouble() * (wh - margin * 2),
      );
      tries++;
    } while (tries < 500 &&
        ((pos - ship.pos).distance < minShipDist ||
            world_.planets.any(
              (p) => (p.position - pos).distance < minPlanetDist,
            ) ||
            spacePOIs.any(
              (p) => p != scanner && (p.position - pos).distance < minPoiDist,
            )));

    scanner.position = pos;
    scanner.discovered = false;
    scanner.interacted = false;
    scanner.life = 0;
  }

  /// Relocate a rift portal to a new random position far from planets and other rifts.
  void relocateRift(RiftPortal rift) {
    final rng = Random();
    const margin = 1920.0;
    const minDist = 3840.0;
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    final obstacles = <Offset>[
      ...world_.planets.map((p) => p.position),
      ...world_.riftPortals.where((r) => r != rift).map((r) => r.position),
    ];
    Offset pos;
    int tries = 0;
    do {
      pos = Offset(
        margin + rng.nextDouble() * (ww - margin * 2),
        margin + rng.nextDouble() * (wh - margin * 2),
      );
      tries++;
    } while (tries < 300 && obstacles.any((o) => (o - pos).distance < minDist));
    rift.position = pos;
    _nearestRift = null;
    _wasNearRift = false;
  }

  void _relocateMeteorShower(SpacePOI shower) {
    final rng = Random();
    const margin = 2200.0;
    const minPlanetDist = 2600.0;
    const minOtherPoiDist = 2400.0;
    const minShipDist = 9000.0;
    const minRelocateDist = 9000.0;
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    final oldPos = shower.position;

    double wrappedDist(Offset a, Offset b) {
      var dx = (a.dx - b.dx).abs();
      var dy = (a.dy - b.dy).abs();
      if (dx > ww / 2) dx = ww - dx;
      if (dy > wh / 2) dy = wh - dy;
      return sqrt(dx * dx + dy * dy);
    }

    Offset pos;
    int tries = 0;
    do {
      pos = Offset(
        margin + rng.nextDouble() * (ww - margin * 2),
        margin + rng.nextDouble() * (wh - margin * 2),
      );
      tries++;
    } while (tries < 500 &&
        (wrappedDist(pos, ship.pos) < minShipDist ||
            wrappedDist(pos, oldPos) < minRelocateDist ||
            world_.planets.any(
              (p) => wrappedDist(pos, p.position) < minPlanetDist,
            ) ||
            spacePOIs.any(
              (p) =>
                  p != shower &&
                  p.type != POIType.comet &&
                  wrappedDist(pos, p.position) < minOtherPoiDist,
            )));

    shower.position = pos;
    shower.angle = rng.nextDouble() * 2 * pi;
    shower.speed = 0;
    shower.life = 0;
    shower.discovered = false;
    shower.interacted = false;
  }

  void _respawnSwarm(ParticleSwarm swarm) {
    final rng = Random();
    const margin = 1920.0;
    const minDist = 2000.0;
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    final obstacles = <Offset>[
      ...world_.planets.map((p) => p.position),
      ...world_.riftPortals.map((r) => r.position),
      ...world_.particleSwarms.where((s) => s != swarm).map((s) => s.center),
    ];
    Offset pos;
    int tries = 0;
    do {
      pos = Offset(
        margin + rng.nextDouble() * (ww - margin * 2),
        margin + rng.nextDouble() * (wh - margin * 2),
      );
      tries++;
    } while (tries < 300 && obstacles.any((o) => (o - pos).distance < minDist));
    swarm.center = pos;
    swarm.driftAngle = rng.nextDouble() * 2 * pi;
    swarm.driftTimer = 3.0 + rng.nextDouble() * 4.0;
    swarm.pulse = 0;

    // Pick a new random element
    const elements = [
      'Fire',
      'Water',
      'Earth',
      'Air',
      'Light',
      'Dark',
      'Lightning',
      'Ice',
      'Plant',
      'Crystal',
      'Poison',
      'Lava',
      'Steam',
      'Mud',
      'Dust',
      'Spirit',
      'Blood',
    ];
    swarm.element = elements[rng.nextInt(elements.length)];

    // Regenerate motes
    final count = 80 + rng.nextInt(41); // 80-120
    swarm.motes.clear();
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final r = rng.nextDouble() * ParticleSwarm.cloudRadius;
      swarm.motes.add(
        SwarmMote(
          offsetX: cos(angle) * r,
          offsetY: sin(angle) * r,
          orbitSpeed: 0.15 + rng.nextDouble() * 0.35,
          orbitPhase: rng.nextDouble() * 2 * pi,
          size: 1.5 + rng.nextDouble() * 2.5,
        ),
      );
    }
  }

  /// Check if a position is inside any planet's particle-field boundary.
  /// Returns the offending planet or null if placement is valid.
  CosmicPlanet? _planetBlockingPlacement(Offset pos) {
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    for (final planet in world_.planets) {
      var pdx = planet.position.dx - pos.dx;
      var pdy = planet.position.dy - pos.dy;
      if (pdx > ww / 2) pdx -= ww;
      if (pdx < -ww / 2) pdx += ww;
      if (pdy > wh / 2) pdy -= wh;
      if (pdy < -wh / 2) pdy += wh;
      final dist = sqrt(pdx * pdx + pdy * pdy);
      if (dist < planet.particleFieldRadius) return planet;
    }
    return null;
  }

  /// Find the closest cosmic planet within interaction range for orbital
  /// mechanics. Returns null if none is close enough.
  CosmicPlanet? _nearestPlanetForOrbit(Offset pos) {
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    CosmicPlanet? closest;
    double closestDist = double.infinity;
    for (final planet in world_.planets) {
      var pdx = planet.position.dx - pos.dx;
      var pdy = planet.position.dy - pos.dy;
      if (pdx > ww / 2) pdx -= ww;
      if (pdx < -ww / 2) pdx += ww;
      if (pdy > wh / 2) pdy -= wh;
      if (pdy < -wh / 2) pdy += wh;
      final dist = sqrt(pdx * pdx + pdy * pdy);
      // Within 1.5× the outer ring → orbital relationship possible
      if (dist < planet.particleFieldRadius * 1.5 && dist < closestDist) {
        closest = planet;
        closestDist = dist;
      }
    }
    return closest;
  }

  // ── orbital relationship state ──
  /// If non-null, one body orbits the other near home planet.
  CosmicPlanet? _orbitalPartner;
  bool _homeOrbitsPartner =
      false; // true → home orbits partner; false → partner orbits home
  double _orbitAngle = 0;
  double _orbitRadius = 0;
  double _orbitSpeed = 0; // rad/sec

  void _setupOrbitalRelationship(Offset homePos) {
    final partner = _nearestPlanetForOrbit(homePos);
    if (partner == null) {
      _orbitalPartner = null;
      return;
    }
    _orbitalPartner = partner;
    final homeVr = homePlanet!.visualRadius;
    if (homeVr >= partner.radius) {
      // Home is bigger → partner orbits home's outer edge
      _homeOrbitsPartner = false;
      _orbitRadius = homeVr * 3.0 + partner.radius;
      _orbitSpeed = 0.02; // rad/sec (~5 min/revolution)
    } else {
      // Partner is bigger → home orbits partner's outer ring
      _homeOrbitsPartner = true;
      _orbitRadius = partner.particleFieldRadius + homeVr;
      _orbitSpeed = 0.015; // rad/sec (~7 min/revolution)
    }
    // Start angle from current relative position
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    var pdx = homePos.dx - partner.position.dx;
    var pdy = homePos.dy - partner.position.dy;
    if (pdx > ww / 2) pdx -= ww;
    if (pdx < -ww / 2) pdx += ww;
    if (pdy > wh / 2) pdy -= wh;
    if (pdy < -wh / 2) pdy += wh;
    _orbitAngle = atan2(pdy, pdx);
  }

  /// Build the home planet at the ship's current position.
  /// Returns null on success, or a warning string if placement is blocked.
  String? buildHomePlanet() {
    final pos = Offset(ship.pos.dx, ship.pos.dy);
    final blocker = _planetBlockingPlacement(pos);
    if (blocker != null) return 'Too close to another planet';
    homePlanet = HomePlanet(position: pos);
    _setupOrbitalRelationship(pos);
    onHomePlanetBuilt?.call(homePlanet!);
    return null;
  }

  /// Move the home planet to the ship's current position.
  /// Returns null on success, or a warning string if placement is blocked.
  String? moveHomePlanet() {
    if (homePlanet == null) return 'No home planet';
    final pos = Offset(ship.pos.dx, ship.pos.dy);
    final blocker = _planetBlockingPlacement(pos);
    if (blocker != null) return 'Too close to another planet';
    homePlanet!.position = pos;
    _setupOrbitalRelationship(pos);
    onHomePlanetBuilt?.call(homePlanet!);
    return null;
  }

  /// Restore a previously-saved home planet.
  void restoreHomePlanet(HomePlanet hp) {
    homePlanet = hp;
    _setupOrbitalRelationship(hp.position);
  }

  /// Spawn orbital chambers around the home planet.
  /// Each entry is: (color, instanceId?, baseCreatureId?, displayName?, imagePath?)
  void spawnOrbitalChambers(
    List<
      (
        Color color,
        String? instanceId,
        String? baseId,
        String? name,
        String? imgPath,
      )
    >
    chamberData,
  ) {
    if (homePlanet == null) return;
    orbitalChambers.clear();
    final hp = homePlanet!.position;
    final vr = homePlanet!.visualRadius;
    final rng = Random();
    for (var i = 0; i < chamberData.length; i++) {
      final (color, instId, baseId, name, imgPath) = chamberData[i];
      final angle = (i / chamberData.length) * pi * 2 + rng.nextDouble() * 0.3;
      final orbitDist = vr + 120 + rng.nextDouble() * 40;
      final pos = Offset(
        hp.dx + cos(angle) * orbitDist,
        hp.dy + sin(angle) * orbitDist,
      );
      // Initial tangential velocity for orbital motion
      final tangent = Offset(-sin(angle), cos(angle));
      final orbitalSpeed = 15.0 + rng.nextDouble() * 10;
      orbitalChambers.add(
        OrbitalChamber(
          position: pos,
          velocity: tangent * orbitalSpeed,
          radius: 18 + rng.nextDouble() * 4,
          color: color,
          seed: rng.nextDouble() * pi * 2,
          instanceId: instId,
          baseCreatureId: baseId,
          displayName: name,
          imagePath: imgPath,
          orbitDistance: orbitDist,
        ),
      );
      // Preload creature image if available
      if (imgPath != null && !_chamberSpriteCache.containsKey(imgPath)) {
        _loadChamberSprite(imgPath);
      }
    }
  }

  /// Load a creature image into the sprite cache for chamber rendering.
  Future<void> _loadChamberSprite(String path) async {
    try {
      final img = await images.load(path);
      _chamberSpriteCache[path] = img;
    } catch (_) {
      // Image not available — chamber will render without sprite.
    }
  }

  /// Check if ship is near the home planet.
  bool get isNearHome {
    if (homePlanet == null) return false;
    final dx = homePlanet!.position.dx - ship.pos.dx;
    final dy = homePlanet!.position.dy - ship.pos.dy;
    final dist2 = dx * dx + dy * dy;
    // Base interaction radius: allow the player to be further out to edit
    // ship and heal. Double the base distance here to expand the interact
    // zone while keeping the same hysteresis delta.
    final baseR = (homePlanet!.visualRadius + 80) * 2.0;
    // Hysteresis: once near, use a larger exit radius to prevent flicker
    final threshold = _wasNearHome ? (baseR + 30) : baseR;
    return dist2 < threshold * threshold;
  }

  // ── ammo colour ──
  Color get _ammoColor {
    return switch (activeAmmoId) {
      'storm_bolts' => const Color(0xFFFFEB3B),
      'plasma_bolts' => const Color(0xFFFFFFFF),
      'ice_shards' => const Color(0xFF00E5FF),
      'void_cannon' => const Color(0xFF9C27B0),
      _ => const Color(0xFF00E5FF),
    };
  }

  // ── home planet customization effects (behind planet body) ──
  void _renderHomeEffectsBehind(
    Canvas canvas,
    Offset pos,
    double vr,
    Color col,
  ) {
    final t = _elapsed;

    // Dark Void — dark-matter aura warps space
    if (activeCustomizations.contains('dark_void')) {
      final voidLayers = switch (customizationOptions['dark_void.layers'] ??
          'Normal') {
        'Thin' => 2,
        'Deep' => 6,
        _ => 4,
      };
      for (var i = 0; i < voidLayers; i++) {
        final r = vr * (2.0 + i * 0.5 + 0.2 * sin(t * 0.7 + i));
        canvas.drawCircle(
          pos,
          r,
          Paint()
            ..color = const Color(
              0xFF4A148C,
            ).withValues(alpha: 0.06 + 0.02 * sin(t + i))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
        );
      }
    }

    // Lava Moat — ring of lava inside the beacon ring
    if (activeCustomizations.contains('lava_moat')) {
      final moatWidth = switch (customizationOptions['lava_moat.width'] ??
          'Normal') {
        'Thin' => 3.0,
        'Wide' => 10.0,
        _ => 6.0,
      };
      final moatR = vr + 14;
      canvas.drawCircle(
        pos,
        moatR,
        Paint()
          ..color = const Color(
            0xFFEF6C00,
          ).withValues(alpha: 0.3 + 0.1 * sin(t * 1.2))
          ..style = PaintingStyle.stroke
          ..strokeWidth = moatWidth
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      // Inner glow
      canvas.drawCircle(
        pos,
        moatR,
        Paint()
          ..color = const Color(0xFFFF5722).withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = moatWidth + 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    // Mud Fortress — thick protective shell
    if (activeCustomizations.contains('mud_fortress')) {
      final fortThickness =
          switch (customizationOptions['mud_fortress.thickness'] ?? 'Normal') {
            'Thin' => 4.0,
            'Thick' => 14.0,
            _ => 8.0,
          };
      canvas.drawCircle(
        pos,
        vr + 6,
        Paint()
          ..color = const Color(0xFF5D4037).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = fortThickness,
      );
      canvas.drawCircle(
        pos,
        vr + 6,
        Paint()
          ..color = const Color(0xFF795548).withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = fortThickness + 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Frozen Shell — icy outer shell
    if (activeCustomizations.contains('frozen_shell')) {
      final iceThickness =
          switch (customizationOptions['frozen_shell.thickness'] ?? 'Normal') {
            'Thin' => 3.0,
            'Thick' => 9.0,
            _ => 5.0,
          };
      canvas.drawCircle(
        pos,
        vr + 4,
        Paint()
          ..color = const Color(
            0xFF00E5FF,
          ).withValues(alpha: 0.2 + 0.05 * sin(t * 1.5))
          ..style = PaintingStyle.stroke
          ..strokeWidth = iceThickness,
      );
      // Frost sparkles
      for (var i = 0; i < 8; i++) {
        final a = t * 0.3 + i * pi / 4;
        final sr = vr + 6;
        canvas.drawCircle(
          Offset(pos.dx + cos(a) * sr, pos.dy + sin(a) * sr),
          1.5,
          Paint()
            ..color = const Color(
              0xFFB3E5FC,
            ).withValues(alpha: 0.6 + 0.3 * sin(t * 3 + i)),
        );
      }
    }
  }

  // ── home planet customization effects (in front of planet body) ──
  void _renderHomeEffectsFront(
    Canvas canvas,
    Offset pos,
    double vr,
    Color col,
  ) {
    final t = _elapsed;

    // Flame Ring — blazing ring of fire
    if (activeCustomizations.contains('flame_ring')) {
      final flameIntensity =
          customizationOptions['flame_ring.intensity'] ?? 'Normal';
      final flameSpeed = customizationOptions['flame_ring.speed'] ?? 'Normal';
      final alphaBase = switch (flameIntensity) {
        'Dim' => 0.25,
        'Bright' => 0.7,
        _ => 0.5,
      };
      final speedMul = switch (flameSpeed) {
        'Slow' => 0.4,
        'Fast' => 1.5,
        _ => 0.8,
      };
      for (var i = 0; i < 8; i++) {
        final a = t * speedMul + i * pi / 4;
        final flareR = vr + 12 + 4 * sin(t * 2 + i);
        final fx = pos.dx + cos(a) * flareR;
        final fy = pos.dy + sin(a) * flareR;
        canvas.drawCircle(
          Offset(fx, fy),
          5 + 2 * sin(t * 3 + i),
          Paint()
            ..color = const Color(
              0xFFFF5722,
            ).withValues(alpha: alphaBase + 0.2 * sin(t * 2 + i))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawCircle(
        pos,
        vr + 14,
        Paint()
          ..color = const Color(
            0xFFFF6E40,
          ).withValues(alpha: (alphaBase * 0.3) + 0.05 * sin(t))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Vine Tendrils — green vines reaching out
    if (activeCustomizations.contains('vine_tendrils')) {
      final vineLength =
          customizationOptions['vine_tendrils.length'] ?? 'Medium';
      final vineCount = customizationOptions['vine_tendrils.count'] ?? 'Some';
      final lenMul = switch (vineLength) {
        'Short' => 0.25,
        'Long' => 0.8,
        _ => 0.5, // Medium
      };
      final count = switch (vineCount) {
        'Few' => 3,
        'Many' => 10,
        _ => 6, // Some
      };
      final vinePaint = Paint()
        ..color = const Color(0xFF4CAF50).withValues(alpha: 0.7)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < count; i++) {
        final baseA = i * pi * 2 / count + t * 0.1;
        final startX = pos.dx + cos(baseA) * vr;
        final startY = pos.dy + sin(baseA) * vr;
        final endLen = vr * lenMul + 8 * sin(t * 0.6 + i);
        final endX = pos.dx + cos(baseA) * (vr + endLen);
        final endY = pos.dy + sin(baseA) * (vr + endLen);
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), vinePaint);
        // Leaf dot at tip
        canvas.drawCircle(
          Offset(endX, endY),
          3,
          Paint()..color = const Color(0xFF81C784).withValues(alpha: 0.8),
        );
      }
    }

    // Crystal Spires — sparkling crystal formations
    if (activeCustomizations.contains('crystal_spires')) {
      final spireHeight =
          customizationOptions['crystal_spires.height'] ?? 'Medium';
      final spireDensity =
          customizationOptions['crystal_spires.density'] ?? 'Normal';
      final tipBase = switch (spireHeight) {
        'Short' => 8.0,
        'Tall' => 20.0,
        _ => 12.0, // Medium
      };
      final spireCount = switch (spireDensity) {
        'Sparse' => 3,
        'Dense' => 8,
        _ => 5, // Normal
      };
      final crystalPaint = Paint()
        ..color = const Color(0xFF1DE9B6).withValues(alpha: 0.7)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < spireCount; i++) {
        final a = i * pi * 2 / spireCount + 0.3;
        final baseX = pos.dx + cos(a) * vr;
        final baseY = pos.dy + sin(a) * vr;
        final tipLen = tipBase + 6 * sin(t * 1.5 + i);
        final tipX = pos.dx + cos(a) * (vr + tipLen);
        final tipY = pos.dy + sin(a) * (vr + tipLen);
        // Triangle spire
        final perpA = a + pi / 2;
        final path = Path()
          ..moveTo(baseX + cos(perpA) * 3, baseY + sin(perpA) * 3)
          ..lineTo(tipX, tipY)
          ..lineTo(baseX - cos(perpA) * 3, baseY - sin(perpA) * 3)
          ..close();
        canvas.drawPath(
          path,
          Paint()..color = const Color(0xFF1DE9B6).withValues(alpha: 0.4),
        );
        canvas.drawPath(path, crystalPaint);
        // Sparkle at tip
        if (sin(t * 4 + i * 2) > 0.7) {
          canvas.drawCircle(
            Offset(tipX, tipY),
            2,
            Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.8),
          );
        }
      }
    }

    // Radiant Halo — golden halo ring
    if (activeCustomizations.contains('radiant_halo')) {
      final haloGlow = switch (customizationOptions['radiant_halo.glow'] ??
          'Normal') {
        'Subtle' => 0.16,
        'Blinding' => 0.72,
        _ => 0.4,
      };
      final haloPosOffset =
          switch (customizationOptions['radiant_halo.position'] ?? 'Mid') {
            'Close' => 8.0,
            'Outer' => vr * 3.5,
            _ => vr * 1.5,
          };
      final haloR = vr + haloPosOffset + 3 * sin(t * 1.2);
      canvas.drawCircle(
        pos,
        haloR,
        Paint()
          ..color = const Color(
            0xFFFFE082,
          ).withValues(alpha: haloGlow + 0.1 * sin(t * 1.5))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawCircle(
        pos,
        haloR,
        Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Ocean Mist — shimmering water vapour
    if (activeCustomizations.contains('ocean_mist')) {
      final mistCount = switch (customizationOptions['ocean_mist.density'] ??
          'Normal') {
        'Light' => 3,
        'Heavy' => 10,
        _ => 6,
      };
      final mistPosOffset =
          switch (customizationOptions['ocean_mist.position'] ?? 'Mid') {
            'Close' => 2.0,
            'Outer' => vr * 3.5,
            _ => vr * 1.5,
          };
      for (var i = 0; i < mistCount; i++) {
        final a = t * 0.2 + i * pi / (mistCount / 2);
        final mr = vr + mistPosOffset + 6 * sin(t * 0.5 + i * 1.2);
        canvas.drawCircle(
          Offset(pos.dx + cos(a) * mr, pos.dy + sin(a) * mr),
          6 + 3 * sin(t * 0.8 + i),
          Paint()
            ..color = const Color(0xFF448AFF).withValues(alpha: 0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }

    // Blood Moon — deep crimson pulsing glow
    if (activeCustomizations.contains('blood_moon')) {
      final pulseIntensity = switch (customizationOptions['blood_moon.pulse'] ??
          'Normal') {
        'Gentle' => 0.08,
        'Intense' => 0.25,
        _ => 0.15,
      };
      final beat =
          pow(sin(t * pi / 0.75).clamp(0.0, 1.0), 8.0) * pulseIntensity;
      canvas.drawCircle(
        pos,
        vr * 1.3,
        Paint()
          ..color = const Color(0xFFD32F2F).withValues(alpha: 0.1 + beat)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }

    // Poison Cloud — toxic green miasma
    if (activeCustomizations.contains('poison_cloud')) {
      final cloudSpread = switch (customizationOptions['poison_cloud.spread'] ??
          'Normal') {
        'Tight' => 6.0,
        'Wide' => 14.0,
        _ => 10.0,
      };
      final cloudPosOffset =
          switch (customizationOptions['poison_cloud.position'] ?? 'Mid') {
            'Close' => 4.0,
            'Outer' => vr * 3.5,
            _ => vr * 1.5,
          };
      for (var i = 0; i < 5; i++) {
        final a = t * 0.15 + i * pi * 2 / 5;
        final cr = vr + cloudPosOffset + cloudSpread * sin(t * 0.4 + i);
        canvas.drawCircle(
          Offset(pos.dx + cos(a) * cr, pos.dy + sin(a) * cr),
          8,
          Paint()
            ..color = const Color(
              0xFF76FF03,
            ).withValues(alpha: 0.08 + 0.03 * sin(t + i))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
    }

    // Dust Storm — orbiting swirling dust particles
    if (activeCustomizations.contains('dust_storm')) {
      final dustCount = switch (customizationOptions['dust_storm.particles'] ??
          'Normal') {
        'Few' => 6,
        'Swarm' => 20,
        _ => 12,
      };
      final dustPosOffset =
          switch (customizationOptions['dust_storm.position'] ?? 'Mid') {
            'Close' => 2.0,
            'Outer' => vr * 3.5,
            _ => vr * 1.5,
          };
      for (var i = 0; i < dustCount; i++) {
        final a = t * 0.6 + i * pi / (dustCount / 2);
        final dr = vr + dustPosOffset + 15 * sin(t * 0.3 + i * 0.5);
        canvas.drawCircle(
          Offset(pos.dx + cos(a) * dr, pos.dy + sin(a) * dr),
          1.5 + sin(t + i) * 0.5,
          Paint()..color = const Color(0xFFFFCC80).withValues(alpha: 0.5),
        );
      }
    }

    // Steam Vents — erupting geyser jets
    if (activeCustomizations.contains('steam_vents')) {
      final ventCount = switch (customizationOptions['steam_vents.jets'] ??
          '4') {
        '2' => 2,
        '6' => 6,
        _ => 4,
      };
      for (var i = 0; i < ventCount; i++) {
        final a = i * pi * 2 / ventCount + 0.4;
        final baseX = pos.dx + cos(a) * vr;
        final baseY = pos.dy + sin(a) * vr;
        // Jet of steam
        for (var j = 0; j < 4; j++) {
          final jetDist = 5 + j * 7.0 + 3 * sin(t * 4 + i + j);
          final jx = baseX + cos(a) * jetDist;
          final jy = baseY + sin(a) * jetDist;
          canvas.drawCircle(
            Offset(jx, jy),
            3 + j * 0.5,
            Paint()
              ..color = const Color(
                0xFF90A4AE,
              ).withValues(alpha: 0.15 - j * 0.03)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
      }
    }

    // Lightning Rod — bolts arc down to surface
    if (activeCustomizations.contains('lightning_rod')) {
      final boltFreq =
          switch (customizationOptions['lightning_rod.frequency'] ?? 'Normal') {
            'Rare' => 1.0,
            'Frequent' => 4.0,
            _ => 2.0,
          };
      // Periodic bolts
      final boltPhase = (t * boltFreq).floor() % 6;
      final boltA = boltPhase * pi / 3 + 0.2;
      final bStartR = vr + 25;
      final bEndR = vr + 2;
      final bsx = pos.dx + cos(boltA) * bStartR;
      final bsy = pos.dy + sin(boltA) * bStartR;
      final bex = pos.dx + cos(boltA) * bEndR;
      final bey = pos.dy + sin(boltA) * bEndR;
      final boltAlpha = (sin(t * 12) > 0.5) ? 0.7 : 0.0;
      if (boltAlpha > 0) {
        canvas.drawLine(
          Offset(bsx, bsy),
          Offset(bex, bey),
          Paint()
            ..color = const Color(0xFFFFEB3B).withValues(alpha: boltAlpha)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
        // Impact glow
        canvas.drawCircle(
          Offset(bex, bey),
          4,
          Paint()
            ..color = const Color(0xFFFFEB3B).withValues(alpha: boltAlpha * 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }

    // Spirit Wisps — ethereal ghost lights
    if (activeCustomizations.contains('spirit_wisps')) {
      final wispCount = switch (customizationOptions['spirit_wisps.count'] ??
          'Some') {
        'Few' => 3,
        'Many' => 8,
        _ => 5, // Some
      };
      final wispPosOffset =
          switch (customizationOptions['spirit_wisps.position'] ?? 'Mid') {
            'Close' => 6.0,
            'Outer' => vr * 3.5,
            _ => vr * 1.5,
          };
      for (var i = 0; i < wispCount; i++) {
        final a = t * 0.4 + i * pi * 2 / wispCount;
        final wr = vr + wispPosOffset + 8 * sin(t * 0.7 + i * 1.5);
        final wx = pos.dx + cos(a) * wr;
        final wy = pos.dy + sin(a) * wr;
        canvas.drawCircle(
          Offset(wx, wy),
          3,
          Paint()
            ..color = const Color(
              0xFF3F51B5,
            ).withValues(alpha: 0.3 + 0.2 * sin(t * 2 + i))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawCircle(
          Offset(wx, wy),
          1.5,
          Paint()
            ..color = const Color(
              0xFFE8EAF6,
            ).withValues(alpha: 0.6 + 0.3 * sin(t * 3 + i)),
        );
      }
    }

    // Nature's Blessing — all element colours radiate
    if (activeCustomizations.contains('natures_blessing')) {
      final blessBrightnessOpt =
          customizationOptions['natures_blessing.brightness'] ?? 'Normal';
      final blessBrightness = switch (blessBrightnessOpt) {
        'Dim' => 0.18,
        'Bright' => 0.92,
        _ => 0.5,
      };
      final blessSize = switch (blessBrightnessOpt) {
        'Dim' => 2.6,
        'Bright' => 8.8,
        _ => 5.6,
      };
      final blessBlur = switch (blessBrightnessOpt) {
        'Dim' => 2.8,
        'Bright' => 13.0,
        _ => 7.0,
      };
      final blessPosOffset =
          switch (customizationOptions['natures_blessing.position'] ?? 'Mid') {
            'Close' => 4.0,
            'Outer' => vr * 3.5,
            _ => vr * 1.5,
          };
      final elements = kElementColors.entries.toList();
      for (var i = 0; i < elements.length; i++) {
        final a = t * 0.15 + i * pi * 2 / elements.length;
        final nr = vr + blessPosOffset;
        canvas.drawCircle(
          Offset(pos.dx + cos(a) * nr, pos.dy + sin(a) * nr),
          blessSize,
          Paint()
            ..color = elements[i].value.withValues(
              alpha: (blessBrightness + 0.2 * sin(t * 1.5 + i)).clamp(0.0, 1.0),
            )
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, blessBlur),
        );
      }
      if (blessBrightnessOpt == 'Bright') {
        canvas.drawCircle(
          pos,
          vr + blessPosOffset + 14,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
    }

    // Orbiting Moon — only visible when planet is Big (tier ≥ 3)
    if (activeCustomizations.contains('orbiting_moon') &&
        homePlanet != null &&
        homePlanet!.sizeTierIndex >= 3) {
      // Sub-customization options
      final moonSizeOpt =
          customizationOptions['orbiting_moon.size'] ?? 'Medium';
      final moonSpeedOpt =
          customizationOptions['orbiting_moon.speed'] ?? 'Normal';
      final moonR = switch (moonSizeOpt) {
        'Small' => vr * 0.12,
        'Large' => vr * 0.25,
        _ => vr * 0.18, // Medium
      };
      final moonSpeed = switch (moonSpeedOpt) {
        'Slow' => 0.3,
        'Fast' => 1.2,
        _ => 0.6, // Normal
      };
      final moonOrbitR = vr + 30 + moonR;
      final moonAngle = t * moonSpeed;
      final mx = pos.dx + cos(moonAngle) * moonOrbitR;
      final my = pos.dy + sin(moonAngle) * moonOrbitR;

      // Moon shadow
      canvas.drawCircle(
        Offset(mx + 2, my + 2),
        moonR,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      // Moon body — gradient sphere
      final moonPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(mx - moonR * 0.3, my - moonR * 0.3),
          moonR * 1.5,
          [
            const Color(0xFFE0E0E0),
            const Color(0xFF9E9E9E),
            const Color(0xFF616161),
          ],
          [0.0, 0.5, 1.0],
        );
      canvas.drawCircle(Offset(mx, my), moonR, moonPaint);
      // Moon crater dots
      for (var i = 0; i < 3; i++) {
        final ca = i * pi * 2 / 3 + 0.5;
        final cr = moonR * 0.4;
        canvas.drawCircle(
          Offset(mx + cos(ca) * cr, my + sin(ca) * cr),
          moonR * 0.1,
          Paint()..color = const Color(0xFF757575).withValues(alpha: 0.5),
        );
      }
    }
  }

  // ── Companion sprite color filter helpers ──

  ui.ColorFilter _geneticsColorFilter(SpriteVisuals v) {
    List<double> m = _identityMatrix();

    if (v.saturation != 1.0 || v.brightness != 1.0) {
      m = _mulMatrix(_bsSatMatrix(v.brightness, v.saturation), m);
    }

    final currentHue = v.isPrismatic
        ? (v.hueShiftDeg + (_elapsed * 45.0) % 360)
        : v.hueShiftDeg;
    final normalizedHue = ((currentHue % 360) + 360) % 360;
    if (normalizedHue != 0) {
      m = _mulMatrix(_hueMatrix(normalizedHue), m);
    }

    // Apply variant tint (modulate) if present and not albino
    if (v.tint != null && !(v.brightness == 1.45 && !v.isPrismatic)) {
      final tr = v.tint!.r;
      final tg = v.tint!.g;
      final tb = v.tint!.b;
      final tintMatrix = <double>[
        tr,
        0,
        0,
        0,
        0,
        0,
        tg,
        0,
        0,
        0,
        0,
        0,
        tb,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ];
      m = _mulMatrix(tintMatrix, m);
    }

    return ui.ColorFilter.matrix(m);
  }

  ui.ColorFilter _albinoColorFilter(double brightness) {
    const rLum = 0.299, gLum = 0.587, bLum = 0.114;
    return ui.ColorFilter.matrix(<double>[
      rLum * brightness,
      gLum * brightness,
      bLum * brightness,
      0,
      0,
      rLum * brightness,
      gLum * brightness,
      bLum * brightness,
      0,
      0,
      rLum * brightness,
      gLum * brightness,
      bLum * brightness,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  List<double> _identityMatrix() => <double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  List<double> _bsSatMatrix(double brightness, double saturation) {
    final r = brightness, g = brightness, b = brightness, s = saturation;
    return <double>[
      s * r,
      0,
      0,
      0,
      0,
      0,
      s * g,
      0,
      0,
      0,
      0,
      0,
      s * b,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _hueMatrix(double degrees) {
    final rad = degrees * (pi / 180.0);
    final c = cos(rad), s = sin(rad);
    return <double>[
      0.213 + c * 0.787 - s * 0.213,
      0.715 - c * 0.715 - s * 0.715,
      0.072 - c * 0.072 + s * 0.928,
      0,
      0,
      0.213 - c * 0.213 + s * 0.143,
      0.715 + c * 0.285 + s * 0.140,
      0.072 - c * 0.072 - s * 0.283,
      0,
      0,
      0.213 - c * 0.213 - s * 0.787,
      0.715 - c * 0.715 + s * 0.715,
      0.072 + c * 0.928 + s * 0.072,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _mulMatrix(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0.0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        double sum = 0.0;
        for (int k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        out[row * 5 + col] = sum;
      }
      double t = a[row * 5 + 4];
      for (int k = 0; k < 4; k++) {
        t += a[row * 5 + k] * b[k * 5 + 4];
      }
      out[row * 5 + 4] = t;
    }
    return out;
  }
}

// ─────────────────────────────────────────────────────────
// HOMING MISSILE
// ─────────────────────────────────────────────────────────

class _HomingMissile {
  Offset position;
  double angle;
  double life = 0.0;
  static const double speed = 450.0;
  static const double turnRate = 4.5; // radians/sec

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
