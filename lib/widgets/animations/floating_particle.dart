import 'dart:math' as math;

import 'package:flutter/material.dart';

class FloatingParticle extends StatelessWidget {
  final AnimationController controller;
  final int index;

  const FloatingParticle({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    final offset = (index * 0.33);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress = (controller.value + offset) % 1.0;
        final angle = progress * 2 * math.pi;
        final radius = 25.0 + (progress * 10);

        final x = math.cos(angle) * radius;
        final y = math.sin(angle) * radius;
        final opacity = (1.0 - progress) * 0.6;

        return Transform.translate(
          offset: Offset(x, y),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD8BFD8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B4789).withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
