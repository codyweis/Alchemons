import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

class PulsingDebugHitbox extends StatefulWidget {
  const PulsingDebugHitbox({
    super.key, // Added key for best practice
    this.size = 140,
    this.color = Colors.red,
    this.borderRadius,
    this.clipOval = true,
  });

  /// square size (width = height)
  final double size;

  /// base color to pulse
  final Color color;

  /// if you want rounded rect instead of oval, pass a radius
  final BorderRadius? borderRadius;

  /// if true we clip to an oval; if false and borderRadius == null,
  /// it's just a square.
  final bool clipOval;

  @override
  State<PulsingDebugHitbox> createState() => _PulsingDebugHitboxState();
}

class _PulsingDebugHitboxState extends State<PulsingDebugHitbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  // 1. Declare a new Animation for scale
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Fade animation (stays the same)
    // fade 0.15 -> 0.40 -> 0.15 for a soft breathing glow
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.15,
          end: 0.40,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.40,
          end: 0.15,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_ctrl);

    // 2. Initialize the new scale animation
    // Scales from 1.0 (original size) to 1.1 (10% bigger) and back
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: .8,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: .8,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 3. Use AnimatedBuilder to listen to both animations
    return AnimatedBuilder(
      animation: _ctrl, // Listen to the controller directly
      builder: (context, child) {
        // The core box for color/opacity
        Widget box = ColoredBox(
          color: widget.color.withOpacity(_opacity.value),
        );

        // Apply clipping shape
        if (widget.clipOval) {
          box = ClipOval(child: box);
        } else if (widget.borderRadius != null) {
          box = ClipRRect(borderRadius: widget.borderRadius!, child: box);
        }

        // 4. Wrap the result in a Transform.scale widget
        box = Transform.scale(
          scale: _scale.value, // Apply the scaling animation
          child: box,
        );

        // This is necessary to maintain the original size for layout purposes
        // while the child is scaled *inside* its bounds.
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: IgnorePointer(ignoring: true, child: box),
        );
      },
    );
  }
}
