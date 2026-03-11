import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BeautyRadianceComponent extends PositionComponent {
  final double baseSize;
  double _time = 0;

  BeautyRadianceComponent({required this.baseSize});

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
    final center = Offset(size.x * 0.5, size.y * 0.5);
    final r = baseSize;
    final orbit = _time * (2 * math.pi / 5.2);
    final pulse = 0.95 + 0.12 * math.sin(_time * 3.7);

    canvas.drawCircle(
      center,
      r * 1.16 * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF3E0).withValues(alpha: 0.18),
            const Color(0xFFF8BBD0).withValues(alpha: 0.13),
            Colors.transparent,
          ],
          stops: const [0.0, 0.56, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.16)),
    );

    final ringRect = Rect.fromCircle(center: center, radius: r * 0.90);
    canvas.drawCircle(
      center,
      r * 0.90,
      Paint()
        ..shader = SweepGradient(
          transform: GradientRotation(orbit * 0.6),
          colors: [
            Colors.transparent,
            const Color(0xFFFFE082).withValues(alpha: 0.24),
            const Color(0xFFF48FB1).withValues(alpha: 0.20),
            const Color(0xFFFFE082).withValues(alpha: 0.24),
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
        ).createShader(ringRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.035),
    );

    const petals = 14;
    for (int i = 0; i < petals; i++) {
      final a = orbit + (i / petals) * 2 * math.pi;
      final p = Offset(
        center.dx + math.cos(a) * r * 0.84,
        center.dy + math.sin(a) * r * 0.84,
      );
      final alpha = 0.20 + 0.16 * (0.5 + 0.5 * math.sin(_time * 3.4 + i));
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + math.pi / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: r * 0.07,
            height: r * 0.27,
          ),
          Radius.circular(r * 0.04),
        ),
        Paint()
          ..color = Color.lerp(
            const Color(0xFFF8BBD0),
            const Color(0xFFFFE082),
            i / petals,
          )!.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }
}
