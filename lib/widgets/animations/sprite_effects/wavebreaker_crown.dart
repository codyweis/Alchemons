import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The creature cosmetic earned by clearing Cosmic Survival wave 50.
///
/// Five orbiting shards mark the ten-wave gauntlets, while the broken double
/// ring uses Survival's amber-and-cyan visual language.
class WavebreakerCrown extends StatefulWidget {
  final double size;

  const WavebreakerCrown({super.key, required this.size});

  @override
  State<WavebreakerCrown> createState() => _WavebreakerCrownState();
}

class _WavebreakerCrownState extends State<WavebreakerCrown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    )..repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      builder: (_, _) => CustomPaint(
        size: Size.square(widget.size * 2.5),
        painter: _WavebreakerCrownPainter(
          radius: widget.size,
          phase: _motion.value,
        ),
      ),
    );
  }
}

class _WavebreakerCrownPainter extends CustomPainter {
  final double radius;
  final double phase;

  const _WavebreakerCrownPainter({required this.radius, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final spin = phase * math.pi * 2;
    final pulse = 0.94 + 0.07 * math.sin(spin * 2);

    canvas.drawCircle(
      c,
      radius * 1.18,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF57E7F2).withValues(alpha: 0.13),
            const Color(0xFFE4C16A).withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0.0, 0.63, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: radius * 1.18)),
    );

    _drawBrokenRing(
      canvas,
      c,
      radius * 0.94 * pulse,
      spin * 0.34,
      radius * 0.065,
      const Color(0xFFE4C16A),
    );
    _drawBrokenRing(
      canvas,
      c,
      radius * 0.73,
      -spin * 0.22,
      radius * 0.035,
      const Color(0xFF57E7F2),
    );

    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + spin * 0.48 + i * math.pi * 2 / 5;
      final p = Offset(
        c.dx + math.cos(a) * radius * 1.04,
        c.dy + math.sin(a) * radius * 1.04,
      );
      final shardPulse = 0.75 + 0.25 * math.sin(spin * 2 + i * math.pi * 2 / 5);
      _drawShard(canvas, p, a, radius * 0.16 * shardPulse);
    }

    // Three crown points remain readable above creatures of every silhouette.
    final crownY = c.dy - radius * 0.78;
    final crown = Path()
      ..moveTo(c.dx - radius * 0.34, crownY + radius * 0.14)
      ..lineTo(c.dx - radius * 0.20, crownY - radius * 0.09)
      ..lineTo(c.dx, crownY + radius * 0.05)
      ..lineTo(c.dx + radius * 0.20, crownY - radius * 0.09)
      ..lineTo(c.dx + radius * 0.34, crownY + radius * 0.14);
    canvas.drawPath(
      crown,
      Paint()
        ..color = const Color(0xFFFFE49A).withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, radius * 0.055)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.025),
    );
  }

  void _drawBrokenRing(
    Canvas canvas,
    Offset center,
    double ringRadius,
    double rotation,
    double width,
    Color color,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, width)
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.35);
    for (var i = 0; i < 10; i++) {
      final start = rotation + i * math.pi * 2 / 10;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        start,
        math.pi * 0.13,
        false,
        paint,
      );
    }
  }

  void _drawShard(
    Canvas canvas,
    Offset center,
    double angle,
    double shardSize,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle + math.pi / 2);
    final path = Path()
      ..moveTo(0, -shardSize)
      ..lineTo(shardSize * 0.58, 0)
      ..lineTo(0, shardSize)
      ..lineTo(-shardSize * 0.58, 0)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader =
            const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFF57E7F2), Color(0xFFE4C16A)],
            ).createShader(
              Rect.fromCenter(
                center: Offset.zero,
                width: shardSize,
                height: shardSize * 2,
              ),
            )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shardSize * 0.16),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WavebreakerCrownPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.phase != phase;
}
