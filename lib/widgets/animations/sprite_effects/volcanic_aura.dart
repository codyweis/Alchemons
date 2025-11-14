import 'package:flutter/material.dart';
import 'dart:math' as math;

class VolcanicAura extends StatefulWidget {
  final double size;
  const VolcanicAura({super.key, required this.size});

  @override
  State<VolcanicAura> createState() => _VolcanicAuraState();
}

class _VolcanicAuraState extends State<VolcanicAura>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late Animation<double> _breathAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Breathing pulse effect
    _breathController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _breathAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutCubic),
    );

    // Mystical rotation
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    // Particle shimmer
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _breathController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _breathAnimation,
        _rotationController,
        _particleController,
      ]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer mystical ring
            Transform.rotate(
              angle: _rotationController.value * 2 * math.pi,
              child: Transform.scale(
                scale: _breathAnimation.value,
                child: Container(
                  width: widget.size * 1.5,
                  height: widget.size * 1.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.deepOrange.withOpacity(
                          0.4 * _glowAnimation.value,
                        ),
                        Colors.red.withOpacity(0.3 * _glowAnimation.value),
                        Colors.purple.withOpacity(0.35 * _glowAnimation.value),
                        Colors.deepOrange.withOpacity(
                          0.4 * _glowAnimation.value,
                        ),
                      ],
                      stops: const [0.0, 0.33, 0.66, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Floating particles/runes effect
            ...List.generate(6, (index) {
              final angle =
                  (index / 6) * 2 * math.pi +
                  (_particleController.value * 2 * math.pi);
              final distance = widget.size * 1 * _breathAnimation.value;
              final x = math.cos(angle) * distance;
              final y = math.sin(angle) * distance;
              final opacity =
                  (math.sin(_particleController.value * 2 * math.pi + index) +
                      1) /
                  2;

              return Transform.translate(
                offset: Offset(x, y),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.withOpacity(0.8 * opacity),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.6 * opacity),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            }),
            // Inner flame core with counter-rotation
            Transform.rotate(
              angle: -_rotationController.value * 1.5 * math.pi,
              child: Transform.scale(
                scale: _breathAnimation.value,
                child: Container(
                  width: widget.size * 1.8,
                  height: widget.size * 1.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.6 * _glowAnimation.value),
                        Colors.amber.withOpacity(0.5 * _glowAnimation.value),
                        Colors.deepOrange.withOpacity(
                          0.4 * _glowAnimation.value,
                        ),
                        Colors.red.withOpacity(0.25 * _glowAnimation.value),
                        Colors.purple.withOpacity(0.15 * _glowAnimation.value),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Bright alchemical core
            Transform.scale(
              scale: _breathAnimation.value * 0.95,
              child: Container(
                width: widget.size * 1.2,
                height: widget.size * 1.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.7 * _glowAnimation.value),
                      Colors.yellow.withOpacity(0.6 * _glowAnimation.value),
                      Colors.orange.withOpacity(0.3 * _glowAnimation.value),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
