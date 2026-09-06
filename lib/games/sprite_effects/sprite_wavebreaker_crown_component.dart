import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class WavebreakerCrownComponent extends PositionComponent {
  final double baseSize;
  double _time = 0;

  WavebreakerCrownComponent({required this.baseSize});

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
    final c = Offset(size.x / 2, size.y / 2);
    final spin = _time * math.pi * 2 / 7.2;
    final pulse = 0.94 + 0.07 * math.sin(spin * 2);

    canvas.drawCircle(
      c,
      baseSize * 1.18,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF57E7F2).withValues(alpha: 0.13),
            const Color(0xFFE4C16A).withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0.0, 0.63, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: baseSize * 1.18)),
    );

    _ring(
      c,
      canvas,
      baseSize * 0.94 * pulse,
      spin * 0.34,
      baseSize * 0.065,
      const Color(0xFFE4C16A),
    );
    _ring(
      c,
      canvas,
      baseSize * 0.73,
      -spin * 0.22,
      baseSize * 0.035,
      const Color(0xFF57E7F2),
    );

    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + spin * 0.48 + i * math.pi * 2 / 5;
      final p = Offset(
        c.dx + math.cos(a) * baseSize * 1.04,
        c.dy + math.sin(a) * baseSize * 1.04,
      );
      canvas.drawCircle(
        p,
        math.max(1.2, baseSize * 0.07),
        Paint()
          ..color =
              (i.isEven ? const Color(0xFF57E7F2) : const Color(0xFFE4C16A))
                  .withValues(alpha: 0.88)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseSize * 0.04),
      );
    }

    final y = c.dy - baseSize * 0.78;
    final crown = Path()
      ..moveTo(c.dx - baseSize * 0.34, y + baseSize * 0.14)
      ..lineTo(c.dx - baseSize * 0.20, y - baseSize * 0.09)
      ..lineTo(c.dx, y + baseSize * 0.05)
      ..lineTo(c.dx + baseSize * 0.20, y - baseSize * 0.09)
      ..lineTo(c.dx + baseSize * 0.34, y + baseSize * 0.14);
    canvas.drawPath(
      crown,
      Paint()
        ..color = const Color(0xFFFFE49A).withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, baseSize * 0.055)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _ring(
    Offset center,
    Canvas canvas,
    double radius,
    double rotation,
    double width,
    Color color,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, width)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 10; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        rotation + i * math.pi * 2 / 10,
        math.pi * 0.13,
        false,
        paint,
      );
    }
  }
}
