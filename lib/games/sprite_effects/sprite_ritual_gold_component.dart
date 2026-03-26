import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class RitualGoldComponent extends PositionComponent {
  RitualGoldComponent({required this.baseSize});

  final double baseSize;
  double _time = 0;

  @override
  Future<void> onLoad() async {
    size = Vector2.all(baseSize * 2.9);
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
    final center = Offset(size.x * 0.5, size.y * 0.5);
    final r = baseSize;
    final orbit = _time * (2 * math.pi / 5.6);
    final pulse = 0.93 + 0.11 * math.sin(_time * 3.4);

    canvas.drawCircle(
      center,
      r * 1.24 * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE4A3).withValues(alpha: 0.22),
            const Color(0xFFC99B2E).withValues(alpha: 0.14),
            Colors.transparent,
          ],
          stops: const [0.0, 0.56, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.24)),
    );

    for (final factor in [0.98, 0.74]) {
      canvas.drawCircle(
        center,
        r * factor,
        Paint()
          ..color = const Color(0xFFE9C76B).withValues(alpha: 0.46)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * (factor > 0.9 ? 0.05 : 0.032)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.028),
      );
    }

    _drawRuneRing(canvas, center, r * 0.88, orbit, 14);
    _drawRuneRing(canvas, center, r * 0.60, -orbit * 0.82, 10);
  }

  void _drawRuneRing(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
    int count,
  ) {
    for (var i = 0; i < count; i++) {
      final angle = rotation + (i / count) * math.pi * 2;
      final p = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(angle + math.pi * 0.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: baseSize * 0.058,
            height: baseSize * 0.15,
          ),
          Radius.circular(baseSize * 0.02),
        ),
        Paint()
          ..color = const Color(0xFFF5D989).withValues(alpha: 0.34)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseSize * 0.012),
      );
      canvas.restore();
    }
  }
}
