import 'package:flutter/material.dart';

class PulsingDebugHitbox extends StatefulWidget {
  const PulsingDebugHitbox({
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

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // fade 0.12 -> 0.32 -> 0.12 for a soft breathing glow
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.12,
          end: 0.32,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.32,
          end: 0.12,
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
    Widget box = AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) {
        return ColoredBox(color: widget.color.withOpacity(_opacity.value));
      },
    );

    // shape
    if (widget.clipOval) {
      box = ClipOval(child: box);
    } else if (widget.borderRadius != null) {
      box = ClipRRect(borderRadius: widget.borderRadius!, child: box);
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: IgnorePointer(
        ignoring: true, // so taps still go through to GestureDetector parent
        child: box,
      ),
    );
  }
}
