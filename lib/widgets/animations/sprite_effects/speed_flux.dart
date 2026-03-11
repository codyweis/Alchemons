import 'dart:math' as math;

import 'package:flutter/material.dart';

class SpeedFlux extends StatefulWidget {
  final double size;
  const SpeedFlux({super.key, required this.size});

  @override
  State<SpeedFlux> createState() => _SpeedFluxState();
}

class _SpeedFluxState extends State<SpeedFlux> with TickerProviderStateMixin {
  late final AnimationController _flow;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _flow = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flow.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flow, _pulse]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size * 2.1, widget.size * 2.1),
          painter: _SpeedFluxPainter(
            t: _flow.value,
            pulse: _pulse.value,
            sizeScale: widget.size,
          ),
        );
      },
    );
  }
}

class _SpeedFluxPainter extends CustomPainter {
  final double t;
  final double pulse;
  final double sizeScale;

  const _SpeedFluxPainter({
    required this.t,
    required this.pulse,
    required this.sizeScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = sizeScale;
    final flow = t * 2 * math.pi;
    final breath = 0.9 + 0.16 * pulse;

    canvas.drawCircle(
      c,
      r * 1.2 * breath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE1F5FE).withValues(alpha: 0.16),
            const Color(0xFF4FC3F7).withValues(alpha: 0.14),
            Colors.transparent,
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.2)),
    );

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.14
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06);
    for (int i = 0; i < 3; i++) {
      final radius = r * (0.72 + i * 0.22);
      final start = flow * (1.2 + i * 0.2) + i * 0.8;
      arcPaint.shader = SweepGradient(
        transform: GradientRotation(start),
        colors: [
          Colors.transparent,
          const Color(0xFF80DEEA).withValues(alpha: 0.22 + i * 0.07),
          const Color(0xFF42A5F5).withValues(alpha: 0.50 + i * 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 0.72, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: radius));
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: radius),
        start,
        1.6,
        false,
        arcPaint,
      );
    }

    final streakPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.07;
    for (int i = 0; i < 12; i++) {
      final phase = (t * 2.8 + i / 12) % 1.0;
      final a = flow * 0.9 + (i / 12) * 2 * math.pi;
      final endR = r * (0.72 + 0.95 * phase);
      final startR = endR - r * (0.34 + 0.2 * phase);
      final p0 = Offset(
        c.dx + math.cos(a) * startR,
        c.dy + math.sin(a) * startR,
      );
      final p1 = Offset(c.dx + math.cos(a) * endR, c.dy + math.sin(a) * endR);
      streakPaint.shader = LinearGradient(
        colors: [
          const Color(0xFFB3E5FC).withValues(alpha: 0.0),
          const Color(0xFF81D4FA).withValues(alpha: 0.42),
          const Color(0xFF29B6F6).withValues(alpha: 0.86),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromPoints(p0, p1));
      canvas.drawLine(p0, p1, streakPaint);
    }

    for (int i = 0; i < 9; i++) {
      final phase = (t * 1.7 + i / 9) % 1.0;
      final a = flow * 1.3 + (i / 9) * 2 * math.pi;
      final d = r * (0.34 + 1.2 * phase);
      final p = Offset(c.dx + math.cos(a) * d, c.dy + math.sin(a) * d);
      final rr = r * (0.03 + (1 - phase) * 0.03);
      canvas.drawCircle(
        p,
        rr,
        Paint()
          ..color = Color.lerp(
            const Color(0xFFB3E5FC),
            const Color(0xFFFFFFFF),
            phase,
          )!.withValues(alpha: (0.35 + 0.6 * (1 - phase)).clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rr * 1.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedFluxPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.pulse != pulse ||
        oldDelegate.sizeScale != sizeScale;
  }
}
