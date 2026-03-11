import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class SpeedFluxComponent extends PositionComponent {
  final double baseSize;
  double _time = 0;

  SpeedFluxComponent({required this.baseSize});

  @override
  Future<void> onLoad() async {
    size = Vector2.all(baseSize * 2.8);
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final c = Offset(size.x * 0.5, size.y * 0.5);
    final r = baseSize;
    final flow = _time * (2 * math.pi / 1.2);

    canvas.drawCircle(
      c,
      r * 1.12,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE1F5FE).withValues(alpha: 0.14),
            const Color(0xFF4FC3F7).withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.12)),
    );

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.12
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05);
    for (int i = 0; i < 3; i++) {
      final rr = r * (0.7 + i * 0.2);
      final start = flow * (1.2 + i * 0.2) + i * 0.8;
      arcPaint.shader = SweepGradient(
        transform: GradientRotation(start),
        colors: [
          Colors.transparent,
          const Color(0xFF80DEEA).withValues(alpha: 0.22 + i * 0.07),
          const Color(0xFF42A5F5).withValues(alpha: 0.48 + i * 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 0.72, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: rr));
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: rr),
        start,
        1.55,
        false,
        arcPaint,
      );
    }

    final streakPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.06;
    for (int i = 0; i < 12; i++) {
      final phase = ((_time / 1.2) * 2.7 + i / 12) % 1.0;
      final a = flow * 0.9 + (i / 12) * 2 * math.pi;
      final endR = r * (0.68 + 0.9 * phase);
      final startR = endR - r * (0.34 + 0.2 * phase);
      final p0 = Offset(
        c.dx + math.cos(a) * startR,
        c.dy + math.sin(a) * startR,
      );
      final p1 = Offset(c.dx + math.cos(a) * endR, c.dy + math.sin(a) * endR);
      streakPaint.shader = LinearGradient(
        colors: [
          const Color(0xFFB3E5FC).withValues(alpha: 0.0),
          const Color(0xFF81D4FA).withValues(alpha: 0.4),
          const Color(0xFF29B6F6).withValues(alpha: 0.8),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromPoints(p0, p1));
      canvas.drawLine(p0, p1, streakPaint);
    }
  }
}
