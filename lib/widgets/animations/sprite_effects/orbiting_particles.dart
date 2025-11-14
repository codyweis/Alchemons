import 'dart:math' as math;

import 'package:alchemons/utils/color_util.dart'; // Assuming this is your color file
import 'package:flutter/material.dart';

class ElementalAura extends StatefulWidget {
  final double size;
  final String? element;
  const ElementalAura({super.key, required this.size, this.element});

  @override
  State<ElementalAura> createState() => _ElementalAuraState();
}

class _ElementalAuraState extends State<ElementalAura>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4), // A good, mystical pace
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We shall divine the proper essence for this element
    final Color essenceColor = _getElementColor(widget.element);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          // Use our new, more potent painter
          painter: _AlchemicAuraPainter(
            transmutationProgress: _controller.value, // Renamed for flair
            essenceColor: essenceColor, // Renamed for flair
          ),
        );
      },
    );
  }

  Color _getElementColor(String? element) {
    // The cauldron of FactionColors provides the essence
    return FactionColors.of(element ?? 'Neutral');
  }
}

/// A painter that draws a more mystical, "living" aura.
/// This is where the magic (and math) happens.
class _AlchemicAuraPainter extends CustomPainter {
  final double transmutationProgress; // Our 0.0 to 1.0 animation value
  final Color essenceColor;

  _AlchemicAuraPainter({
    required this.transmutationProgress,
    required this.essenceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const quintessenceCount = 5; // The fifth element!

    // --- 2. Draw the Orbiting Quintessences ---
    final particlePaint = Paint()
      ..color = essenceColor
      ..style = PaintingStyle.fill;

    // The main orbit "breathes" in and out slowly
    final orbitPulse = 0.1 * math.sin(transmutationProgress * 2 * math.pi);
    final mainRadius = size.width * (0.35 + orbitPulse);

    for (int i = 0; i < quintessenceCount; i++) {
      // Base angle for this particle
      final angle =
          (transmutationProgress * 2 * math.pi) +
          (i * 2 * math.pi / quintessenceCount);

      // This makes each particle "flicker" individually
      // We use a faster sine wave ( * 8 ) and offset it by 'i'
      final flicker = math.sin(
        transmutationProgress * 8 * math.pi + (i * math.pi / 2),
      );

      // Use the flicker to vary particle size (from 1.5 to 4.5)
      final particleSize = 3.0 + (flicker * 1.5);

      // Use the flicker to vary particle opacity (from 0.4 to 1.0)
      particlePaint.color = essenceColor.withOpacity(0.7 + (flicker * 0.3));

      // Standard trig to find the particle's position on the breathing orbit
      final x = center.dx + mainRadius * math.cos(angle);
      final y = center.dy + mainRadius * math.sin(angle);

      canvas.drawCircle(Offset(x, y), particleSize, particlePaint);
    }
  }

  @override
  bool shouldRepaint(_AlchemicAuraPainter oldDelegate) {
    // We must repaint if the progress has changed
    return oldDelegate.transmutationProgress != transmutationProgress;
  }
}
