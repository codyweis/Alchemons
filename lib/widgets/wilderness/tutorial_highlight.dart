// lib/widgets/wilderness/tutorial_highlight.dart
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

/// Wraps a widget with a pulsing highlight effect for tutorials
class TutorialHighlight extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final String? label;

  const TutorialHighlight({
    super.key,
    required this.child,
    this.enabled = false,
    this.label,
  });

  @override
  State<TutorialHighlight> createState() => _TutorialHighlightState();
}

class _TutorialHighlightState extends State<TutorialHighlight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.enabled) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TutorialHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Optional label ABOVE the stack
            if (widget.label != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.label!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Highlighted content
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Glowing border effect
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(_glowAnimation.value),
                          blurRadius: 20 * _glowAnimation.value,
                          spreadRadius: 4 * _glowAnimation.value,
                        ),
                      ],
                    ),
                  ),
                ),

                // Pulsing scale effect
                Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.8),
                        width: 3,
                      ),
                    ),
                    child: child,
                  ),
                ),
              ],
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// Adds a pulsing glow effect around a wild creature in tutorial mode
class TutorialCreatureHighlight extends PositionComponent {
  final double radius;
  final Color glowColor;

  TutorialCreatureHighlight({
    required this.radius,
    this.glowColor = Colors.amber,
    Vector2? position,
  }) : super(position: position ?? Vector2.zero(), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    // Outer glow ring
    final outerRing = CircleComponent(
      radius: radius * 1.3,
      paint: Paint()
        ..color = glowColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
      anchor: Anchor.center,
      position: size / 2,
    );

    // Middle glow ring
    final middleRing = CircleComponent(
      radius: radius * 1.15,
      paint: Paint()
        ..color = glowColor.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
      anchor: Anchor.center,
      position: size / 2,
    );

    // Inner glow ring
    final innerRing = CircleComponent(
      radius: radius,
      paint: Paint()
        ..color = glowColor.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
      anchor: Anchor.center,
      position: size / 2,
    );

    add(outerRing);
    add(middleRing);
    add(innerRing);

    // Pulsing scale animation
    add(
      ScaleEffect.to(
        Vector2.all(1.15),
        EffectController(
          duration: 1.2,
          reverseDuration: 1.2,
          infinite: true,
          curve: Curves.easeInOut,
          alternate: true,
        ),
      ),
    );

    // Rotating effect for outer ring
    outerRing.add(
      RotateEffect.by(
        3.14159 * 2, // Full rotation
        EffectController(duration: 3.0, infinite: true),
      ),
    );
  }
}
