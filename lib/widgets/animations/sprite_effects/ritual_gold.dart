import 'dart:math' as math;

import 'package:flutter/material.dart';

class RitualGold extends StatefulWidget {
  const RitualGold({super.key, required this.size});

  final double size;

  @override
  State<RitualGold> createState() => _RitualGoldState();
}

class _RitualGoldState extends State<RitualGold> with TickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ringCtrl, _pulseCtrl]),
      builder: (context, _) {
        return CustomPaint(
          size: Size.square(widget.size * 2.4),
          painter: _RitualGoldPainter(
            t: _ringCtrl.value,
            pulse: _pulseCtrl.value,
            sizeScale: widget.size,
          ),
        );
      },
    );
  }
}

class _RitualGoldPainter extends CustomPainter {
  const _RitualGoldPainter({
    required this.t,
    required this.pulse,
    required this.sizeScale,
  });

  final double t;
  final double pulse;
  final double sizeScale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final r = sizeScale;
    final orbit = t * 2 * math.pi;
    final breath = 0.92 + pulse * 0.14;

    canvas.drawCircle(
      center,
      r * 1.28 * breath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE4A3).withValues(alpha: 0.24),
            const Color(0xFFC99B2E).withValues(alpha: 0.16),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.28)),
    );

    for (final factor in [1.02, 0.78]) {
      canvas.drawCircle(
        center,
        r * factor,
        Paint()
          ..color = const Color(0xFFE9C76B).withValues(alpha: 0.50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * (factor > 1 ? 0.055 : 0.035)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.03),
      );
    }

    _drawRuneRing(canvas, center, r * 0.90, orbit, 14);
    _drawRuneRing(canvas, center, r * 0.62, -orbit * 0.85, 10);

    for (var i = 0; i < 10; i++) {
      final a = orbit * 1.2 + (i / 10) * math.pi * 2;
      final p = Offset(
        center.dx + math.cos(a) * r * 1.06,
        center.dy + math.sin(a) * r * 1.06,
      );
      final sparkR = r * (0.035 + ((i % 3) * 0.01));
      canvas.drawCircle(
        p,
        sparkR,
        Paint()
          ..color = const Color(0xFFFFF2C7).withValues(alpha: 0.42)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sparkR * 1.2),
      );
    }

    canvas.drawCircle(
      center,
      r * 0.18,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF7D8).withValues(alpha: 0.36),
            const Color(0xFFE0B650).withValues(alpha: 0.16),
            Colors.transparent,
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 0.18)),
    );
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
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: sizeScale * 0.06,
          height: sizeScale * 0.16,
        ),
        Radius.circular(sizeScale * 0.02),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = const Color(0xFFF5D989).withValues(alpha: 0.34)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sizeScale * 0.012),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RitualGoldPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.pulse != pulse ||
        oldDelegate.sizeScale != sizeScale;
  }
}
