import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class IntelligenceHaloComponent extends PositionComponent {
  final double baseSize;
  double _time = 0;

  IntelligenceHaloComponent({required this.baseSize});

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
    final spin = _time * (2 * math.pi / 5.6);
    final pulse = 0.92 + 0.14 * math.sin(_time * 2.8);

    canvas.drawCircle(
      c,
      r * 1.2 * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFEDE7F6).withValues(alpha: 0.14),
            const Color(0xFFB39DDB).withValues(alpha: 0.14),
            Colors.transparent,
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.2)),
    );

    _drawSegmentRing(
      canvas,
      c,
      r * 0.9,
      spin,
      const Color(0xFFB39DDB).withValues(alpha: 0.68),
      const Color(0xFF80DEEA).withValues(alpha: 0.68),
      r * 0.08,
    );
    _drawSegmentRing(
      canvas,
      c,
      r * 0.64,
      -spin * 0.72,
      const Color(0xFF90CAF9).withValues(alpha: 0.56),
      const Color(0xFFCE93D8).withValues(alpha: 0.52),
      r * 0.05,
    );

    final nodes = <Offset>[];
    for (int i = 0; i < 6; i++) {
      final a = spin + (i / 6) * 2 * math.pi;
      nodes.add(
        Offset(c.dx + math.cos(a) * r * 0.82, c.dy + math.sin(a) * r * 0.82),
      );
    }
    final link = Paint()
      ..color = const Color(0xFFB39DDB).withValues(alpha: 0.26)
      ..strokeWidth = r * 0.02
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < nodes.length; i++) {
      canvas.drawLine(nodes[i], nodes[(i + 2) % nodes.length], link);
    }
    final nodePaint = Paint()
      ..color = const Color(0xFFC5CAE9).withValues(alpha: 0.82)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04);
    for (final n in nodes) {
      canvas.drawCircle(n, r * 0.04, nodePaint);
    }
  }

  void _drawSegmentRing(
    Canvas canvas,
    Offset c,
    double radius,
    double rotation,
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
      paint.color = i.isEven ? a : b;
      final start = rotation + (i / 6) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: radius),
        start,
        0.72,
        false,
        paint,
      );
    }
  }
}
