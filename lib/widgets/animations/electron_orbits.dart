import 'dart:math' as math;

import 'package:flutter/material.dart';

class _ElectronOrbits extends StatefulWidget {
  final Color color;
  const _ElectronOrbits({required this.color});
  @override
  State<_ElectronOrbits> createState() => _ElectronOrbitsState();
}

class _ElectronOrbitsState extends State<_ElectronOrbits>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        size: const Size.square(44),
        painter: _OrbitPainter(_c.value, widget.color),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final double t;
  final Color color;
  _OrbitPainter(this.t, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Two tilted orbits
    for (final rot in [0.0, 0.6]) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rot);
      final r = size.width * 0.34;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.2),
        paint,
      );

      // Electron (dot) moving along the orbit
      final angle = t * 2 * 3.1415926 * (rot == 0.0 ? 1.0 : 1.3);
      final x = r * Math.cos(angle);
      final y = r * 0.6 * Math.sin(angle);
      final dot = Paint()..color = color;
      canvas.drawCircle(Offset(x, y), 2.2, dot);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => true;
}

class Math {
  static double sin(double x) => Math._s(x);
  static double cos(double x) => Math._c(x);
  static double _s(double x) => math.sin(x);
  static double _c(double x) => math.cos(x);
}
