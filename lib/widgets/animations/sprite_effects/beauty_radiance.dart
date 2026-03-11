import 'dart:math' as math;

import 'package:flutter/material.dart';

class BeautyRadiance extends StatefulWidget {
  final double size;
  const BeautyRadiance({super.key, required this.size});

  @override
  State<BeautyRadiance> createState() => _BeautyRadianceState();
}

class _BeautyRadianceState extends State<BeautyRadiance>
    with TickerProviderStateMixin {
  late final AnimationController _orbit;
  late final AnimationController _twinkle;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      duration: const Duration(milliseconds: 5200),
      vsync: this,
    )..repeat();
    _twinkle = AnimationController(
      duration: const Duration(milliseconds: 1700),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbit.dispose();
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_orbit, _twinkle]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size * 2.2, widget.size * 2.2),
          painter: _BeautyRadiancePainter(
            t: _orbit.value,
            pulse: _twinkle.value,
            sizeScale: widget.size,
          ),
        );
      },
    );
  }
}

class _BeautyRadiancePainter extends CustomPainter {
  final double t;
  final double pulse;
  final double sizeScale;

  const _BeautyRadiancePainter({
    required this.t,
    required this.pulse,
    required this.sizeScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final r = sizeScale;
    final orbit = t * 2 * math.pi;
    final breath = 0.92 + 0.14 * pulse;

    canvas.drawCircle(
      center,
      r * 1.18 * breath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF3E0).withValues(alpha: 0.18),
            const Color(0xFFF8BBD0).withValues(alpha: 0.14),
            const Color(0xFFFCE4EC).withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.18)),
    );

    final ringRect = Rect.fromCircle(center: center, radius: r * 0.94);
    canvas.drawCircle(
      center,
      r * 0.94,
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
        ..strokeWidth = r * 0.065
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04),
    );

    const petals = 14;
    for (int i = 0; i < petals; i++) {
      final a = orbit + (i / petals) * 2 * math.pi;
      final px = center.dx + math.cos(a) * r * 0.86;
      final py = center.dy + math.sin(a) * r * 0.86;
      final alpha = 0.20 + 0.16 * (0.5 + 0.5 * math.sin(orbit * 2 + i));
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(a + math.pi / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: r * 0.07,
            height: r * 0.29,
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

    for (int i = 0; i < 14; i++) {
      final phase = (t * 1.7 + i / 14) % 1.0;
      final dist = r * (0.35 + 0.8 * math.sin(phase * math.pi));
      final a = orbit * 0.72 + (i / 14) * 2 * math.pi;
      final p = Offset(
        center.dx + math.cos(a) * dist,
        center.dy + math.sin(a) * dist,
      );
      final starR = (0.6 + (1 - phase) * 1.1) * (0.88 + 0.12 * pulse);
      _drawStar(
        canvas,
        p,
        starR,
        const Color(
          0xFFFFF8E1,
        ).withValues(alpha: 0.42 * math.sin(phase * math.pi)),
      );
    }

    canvas.drawCircle(
      center,
      r * 0.22,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.45),
            const Color(0xFFFFECB3).withValues(alpha: 0.24),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 0.22)),
    );
  }

  void _drawStar(Canvas canvas, Offset c, double radius, Color color) {
    final path = Path();
    const points = 4;
    for (int i = 0; i < points * 2; i++) {
      final rr = i.isEven ? radius : radius * 0.32;
      final a = (i / (points * 2)) * 2 * math.pi - math.pi / 4;
      final p = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
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
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _BeautyRadiancePainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.pulse != pulse ||
        oldDelegate.sizeScale != sizeScale;
  }
}
