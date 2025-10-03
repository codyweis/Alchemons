// lib/widgets/fx/alchemy_tap_fx.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class AlchemyTapFX extends StatelessWidget {
  const AlchemyTapFX({
    super.key,
    required this.center, // local position inside the tube Stack
    required this.progress, // 0..1
    required this.color,
  });

  final Offset? center;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (center == null || progress <= 0) return const SizedBox.shrink();
    return CustomPaint(painter: _AlchemyTapFXPainter(center!, progress, color));
  }
}

class _AlchemyTapFXPainter extends CustomPainter {
  _AlchemyTapFXPainter(this.center, this.p, this.color);

  final Offset center;
  final double p; // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Ease in/out a bit
    final t = Curves.easeOutQuart.transform(p);
    final inv = (1.0 - t);

    // ---- 1) Expanding ripple rings (additive glow) ----
    final ringBase = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * inv
      ..blendMode = BlendMode.plus
      ..color = color.withOpacity(0.35 * inv);

    for (int i = 0; i < 3; i++) {
      final r = 18.0 + (40.0 + i * 12.0) * t;
      canvas.drawCircle(
        center,
        r,
        ringBase..color = ringBase.color.withOpacity((0.35 - i * 0.08) * inv),
      );
    }

    // ---- 2) Arcane glyph ring (hex + runes) ----
    final glyphRadius = 22.0 + 26.0 * t;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withOpacity(0.35 * inv)
      ..blendMode = BlendMode.plus;

    // Outer rotating hexagon
    final hex = Path();
    for (int i = 0; i < 6; i++) {
      final a = (i / 6.0) * math.pi * 2 + t * 3.0; // slow rotation
      final pnt = center + Offset(math.cos(a), math.sin(a)) * glyphRadius;
      if (i == 0)
        hex.moveTo(pnt.dx, pnt.dy);
      else
        hex.lineTo(pnt.dx, pnt.dy);
    }
    hex.close();
    canvas.drawPath(hex, stroke);

    // Small inner runes (little ticks)
    final runePaint = Paint()
      ..strokeWidth = 1.1
      ..color = Colors.white.withOpacity(0.5 * inv)
      ..blendMode = BlendMode.plus;
    for (int i = 0; i < 8; i++) {
      final a = (i / 8.0) * math.pi * 2 - t * 4.0;
      final r0 = glyphRadius - 6;
      final r1 = glyphRadius + 6;
      final p0 = center + Offset(math.cos(a), math.sin(a)) * r0;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * r1;
      canvas.drawLine(p0, p1, runePaint);
    }

    // ---- 3) Sparks shooting outward ----
    final sparks = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.9 * inv)
      ..blendMode = BlendMode.plus;
    const sparkCount = 10;
    for (int i = 0; i < sparkCount; i++) {
      final a = (i / sparkCount) * math.pi * 2 + t * 2.2;
      final dist = 12.0 + 58.0 * t;
      final pos = center + Offset(math.cos(a), math.sin(a)) * dist;
      final r = 1.8 + 0.8 * (1.0 - t);
      canvas.drawCircle(pos, r, sparks);
    }

    // ---- 4) Upward alchemical bubbles (tiny) ----
    final bubblePaint = Paint()
      ..color = Colors.white.withOpacity(0.35 * inv)
      ..blendMode = BlendMode.plus;
    for (int i = 0; i < 8; i++) {
      final a = (i / 8.0) * math.pi * 2;
      final r = 6.0 + 14.0 * t + (i % 3) * 2.0;
      final pos =
          center + Offset(math.cos(a), math.sin(a)) * r - Offset(0, 10.0 * t);
      canvas.drawCircle(pos, 1.2 + (i % 2) * 0.6, bubblePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AlchemyTapFXPainter old) =>
      old.center != center || old.p != p || old.color != color;
}
