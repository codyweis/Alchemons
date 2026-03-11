import 'dart:math' as math;

import 'package:flutter/material.dart';

class IntelligenceHalo extends StatefulWidget {
  final double size;
  const IntelligenceHalo({super.key, required this.size});

  @override
  State<IntelligenceHalo> createState() => _IntelligenceHaloState();
}

class _IntelligenceHaloState extends State<IntelligenceHalo>
    with TickerProviderStateMixin {
  late final AnimationController _orbit;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      duration: const Duration(milliseconds: 5600),
      vsync: this,
    )..repeat();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbit.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_orbit, _pulse]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size * 2.3, widget.size * 2.3),
          painter: _IntelligenceHaloPainter(
            t: _orbit.value,
            pulse: _pulse.value,
            sizeScale: widget.size,
          ),
        );
      },
    );
  }
}

class _IntelligenceHaloPainter extends CustomPainter {
  final double t;
  final double pulse;
  final double sizeScale;

  const _IntelligenceHaloPainter({
    required this.t,
    required this.pulse,
    required this.sizeScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = sizeScale;
    final spin = t * 2 * math.pi;
    final breath = 0.92 + 0.14 * pulse;

    canvas.drawCircle(
      c,
      r * 1.3 * breath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFEDE7F6).withValues(alpha: 0.16),
            const Color(0xFFB39DDB).withValues(alpha: 0.16),
            const Color(0xFF81D4FA).withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.3)),
    );

    _drawSegmentRing(
      canvas: canvas,
      center: c,
      radius: r * 0.94,
      rotation: spin,
      colorA: const Color(0xFFB39DDB).withValues(alpha: 0.7),
      colorB: const Color(0xFF80DEEA).withValues(alpha: 0.7),
      thickness: r * 0.1,
    );
    _drawSegmentRing(
      canvas: canvas,
      center: c,
      radius: r * 0.66,
      rotation: -spin * 0.7,
      colorA: const Color(0xFF90CAF9).withValues(alpha: 0.6),
      colorB: const Color(0xFFCE93D8).withValues(alpha: 0.55),
      thickness: r * 0.06,
    );

    final nodePaint = Paint()
      ..color = const Color(0xFFC5CAE9).withValues(alpha: 0.85)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05);
    final nodes = <Offset>[];
    for (int i = 0; i < 6; i++) {
      final a = spin + (i / 6) * 2 * math.pi;
      nodes.add(
        Offset(c.dx + math.cos(a) * r * 0.86, c.dy + math.sin(a) * r * 0.86),
      );
    }

    final linkPaint = Paint()
      ..color = const Color(0xFFB39DDB).withValues(alpha: 0.28)
      ..strokeWidth = r * 0.022
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < nodes.length; i++) {
      final a = nodes[i];
      final b = nodes[(i + 2) % nodes.length];
      canvas.drawLine(a, b, linkPaint);
    }
    for (final n in nodes) {
      canvas.drawCircle(n, r * 0.045, nodePaint);
    }

    canvas.drawCircle(
      c,
      r * 0.34,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.62),
            const Color(0xFFB3E5FC).withValues(alpha: 0.35),
            Colors.transparent,
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.34)),
    );
  }

  void _drawSegmentRing({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double rotation,
    required Color colorA,
    required Color colorB,
    required double thickness,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = thickness
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness * 0.45);
    for (int i = 0; i < 6; i++) {
      final start = rotation + (i / 6) * 2 * math.pi;
      paint.color = i.isEven ? colorA : colorB;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        0.72,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IntelligenceHaloPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.pulse != pulse ||
        oldDelegate.sizeScale != sizeScale;
  }
}
