import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class StrengthForgeComponent extends PositionComponent {
  final double baseSize;
  double _time = 0;

  StrengthForgeComponent({required this.baseSize});

  @override
  Future<void> onLoad() async {
    size = Vector2.all(baseSize * 3.0);
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
    final pulse = 0.9 + 0.16 * math.sin(_time * 3.2);
    final spin = _time * (2 * math.pi / 6.8);

    canvas.drawCircle(
      c,
      r * 1.14 * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFECB3).withValues(alpha: 0.2),
            const Color(0xFFFF8A65).withValues(alpha: 0.18),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.14)),
    );

    _drawHex(
      canvas,
      c,
      r * 0.92 * pulse,
      spin,
      r * 0.08,
      const Color(0xFFFF7043),
    );
    _drawHex(
      canvas,
      c,
      r * 0.68 * pulse,
      -spin * 0.72,
      r * 0.05,
      const Color(0xFFFFCC80),
    );

    for (int i = 0; i < 6; i++) {
      final a = spin + (i / 6) * 2 * math.pi;
      final p = Offset(
        c.dx + math.cos(a) * r * 0.88,
        c.dy + math.sin(a) * r * 0.88,
      );
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + math.pi / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: r * 0.14,
            height: r * 0.24,
          ),
          Radius.circular(r * 0.04),
        ),
        Paint()..color = const Color(0xFFFFAB91).withValues(alpha: 0.7),
      );
      canvas.restore();
    }
  }

  void _drawHex(
    Canvas canvas,
    Offset c,
    double radius,
    double rot,
    double stroke,
    Color color,
  ) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = rot + (i / 6) * 2 * math.pi - math.pi / 2;
      final p = Offset(
        c.dx + math.cos(a) * radius,
        c.dy + math.sin(a) * radius,
      );
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
        ..color = color.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.8),
    );
  }
}
