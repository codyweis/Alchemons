import 'package:alchemons/audio/audio.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class FloatingAlchemyOrb extends StatefulWidget {
  final double size;
  final VoidCallback onTap;

  const FloatingAlchemyOrb({super.key, this.size = 75, required this.onTap});

  @override
  State<FloatingAlchemyOrb> createState() => _FloatingAlchemyOrbState();
}

class _FloatingAlchemyOrbState extends State<FloatingAlchemyOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        final floatOffset = sin(t * 2 * pi) * 4.0;

        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: GestureDetector(
            onTap: context.soundAction(widget.onTap),
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _AlchemyOrbPainter(rotation: t * 2 * pi),
            ),
          ),
        );
      },
    );
  }
}

class _AlchemyOrbPainter extends CustomPainter {
  final double rotation;
  _AlchemyOrbPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.45;

    // Deep space background
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.black, Colors.black],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Subtle outer glow
    final outerGlowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..color = const Color(0xFF6B4FBF).withValues(alpha: 0.15);
    canvas.drawCircle(center, radius * 0.95, outerGlowPaint);

    // Stars scattered throughout
    final starPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Create depth with multiple star layers
    for (int layer = 0; layer < 3; layer++) {
      final layerOpacity = 0.4 + (layer * 0.3);
      final layerSpeed = 1.0 + (layer * 0.5);

      for (int i = 0; i < 30; i++) {
        final seed = layer * 100 + i;
        final r = Random(seed);

        // Position stars within the orb
        final angle = r.nextDouble() * 2 * pi + (rotation * layerSpeed);
        final distance = r.nextDouble() * radius * 0.85;
        final x = center.dx + cos(angle) * distance;
        final y = center.dy + sin(angle) * distance;

        // Vary star sizes - mostly tiny
        final starSize = r.nextDouble() < 0.9
            ? 0.2 + r.nextDouble() * 0.7
            : // tiny stars
              .5 + r.nextDouble() * 1; // occasional larger stars

        // Twinkle effect
        final twinkle = sin(rotation * 3 + seed) * 0.5 + 0.5;
        final opacity = layerOpacity * twinkle;

        starPaint.color = Colors.white.withValues(alpha: opacity);
        canvas.drawCircle(Offset(x, y), starSize, starPaint);
      }
    }

    // Very subtle center glow
    final centerGlowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..color = const Color(0xFF8B7FD8).withValues(alpha: 0.1);
    canvas.drawCircle(center, radius * 0.3, centerGlowPaint);

    // Faint nebula wisps
    final nebulaPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
      ..color = const Color(0xFF4A3F7F).withValues(alpha: 0.08);

    for (int i = 0; i < 3; i++) {
      final angle = (i / 3.0) * 2 * pi + rotation * 0.5;
      final distance = radius * 0.4;
      final nebulaCenter = center.translate(
        cos(angle) * distance,
        sin(angle) * distance,
      );
      canvas.drawCircle(nebulaCenter, radius * 0.25, nebulaPaint);
    }

    // A very thin gold edge, in the avatar and Upgrade medallions' gold, so
    // the way into the cosmos reads as one of the home's set pieces.
    final band = Rect.fromCircle(center: center, radius: radius);
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..shader = ui.Gradient.linear(
        band.topLeft,
        band.bottomRight,
        const [Color(0xFFF2D58A), Color(0xFF8A6420), Color(0xFFC9A04E)],
        const [0.0, 0.6, 1.0],
      );
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _AlchemyOrbPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}
