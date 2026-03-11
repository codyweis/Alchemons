import 'dart:math' as math;

import 'package:flutter/material.dart';

class StrengthForge extends StatefulWidget {
  final double size;
  const StrengthForge({super.key, required this.size});

  @override
  State<StrengthForge> createState() => _StrengthForgeState();
}

class _StrengthForgeState extends State<StrengthForge>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _rotate;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _rotate = AnimationController(
      duration: const Duration(milliseconds: 6800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _rotate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _rotate]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size * 2.2, widget.size * 2.2),
          painter: _StrengthForgePainter(
            pulse: _pulse.value,
            t: _rotate.value,
            sizeScale: widget.size,
          ),
        );
      },
    );
  }
}

class _StrengthForgePainter extends CustomPainter {
  final double pulse;
  final double t;
  final double sizeScale;

  const _StrengthForgePainter({
    required this.pulse,
    required this.t,
    required this.sizeScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = sizeScale;
    final beat = 0.88 + 0.2 * pulse;
    final spin = t * 2 * math.pi;

    canvas.drawCircle(
      c,
      r * 1.18 * beat,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFECB3).withValues(alpha: 0.22),
            const Color(0xFFFF8A65).withValues(alpha: 0.20),
            Colors.transparent,
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.18)),
    );

    _drawHexRing(
      canvas: canvas,
      center: c,
      radius: r * 0.98 * beat,
      rotation: spin,
      stroke: r * 0.1,
      color: const Color(0xFFFF7043).withValues(alpha: 0.74),
    );
    _drawHexRing(
      canvas: canvas,
      center: c,
      radius: r * 0.72 * beat,
      rotation: -spin * 0.7,
      stroke: r * 0.06,
      color: const Color(0xFFFFCC80).withValues(alpha: 0.64),
    );

    for (int i = 0; i < 6; i++) {
      final a = spin + (i / 6) * 2 * math.pi;
      final p = Offset(
        c.dx + math.cos(a) * r * 0.95,
        c.dy + math.sin(a) * r * 0.95,
      );
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + math.pi / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: r * 0.16,
            height: r * 0.28,
          ),
          Radius.circular(r * 0.04),
        ),
        Paint()..color = const Color(0xFFFFAB91).withValues(alpha: 0.75),
      );
      canvas.restore();
    }

    final wave = r * (0.52 + pulse * 0.48);
    canvas.drawCircle(
      c,
      wave,
      Paint()
        ..color = const Color(0xFFFF7043).withValues(alpha: 0.0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFAB91).withValues(alpha: 0.0),
            const Color(0xFFFF7043).withValues(alpha: 0.45 - pulse * 0.3),
            const Color(0xFFFF7043).withValues(alpha: 0.0),
          ],
          stops: const [0.4, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: wave)),
    );

    canvas.drawCircle(
      c,
      r * 0.34,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.6),
            const Color(0xFFFFCC80).withValues(alpha: 0.45),
            const Color(0xFFFF8A65).withValues(alpha: 0.22),
            Colors.transparent,
          ],
          stops: const [0.0, 0.36, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.34)),
    );
  }

  void _drawHexRing({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double rotation,
    required double stroke,
    required Color color,
  }) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = rotation + (i / 6) * 2 * math.pi - math.pi / 2;
      final p = Offset(
        center.dx + math.cos(a) * radius,
        center.dy + math.sin(a) * radius,
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
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _StrengthForgePainter oldDelegate) {
    return oldDelegate.pulse != pulse ||
        oldDelegate.t != t ||
        oldDelegate.sizeScale != sizeScale;
  }
}
