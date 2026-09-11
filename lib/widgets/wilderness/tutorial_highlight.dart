// lib/widgets/wilderness/tutorial_highlight.dart
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/app_icons.dart';

/// Wraps a widget with a pulsing highlight effect for tutorials
/// The amber the rest of the game's chrome is drawn in.
const Color _kLabelAccent = Color(0xFFE4C16A);

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
  late Animation<double> _breathe;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _breathe = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

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
          // The party strip sits in the screen's right corner inside a box
          // sized to its cards, so anything wider than them has to hug that
          // same edge rather than centre over it and hang off the screen.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Optional label ABOVE the stack.
            //
            // Scaled down rather than clipped. This points at things pinned
            // to a screen edge inside boxes sized to them, so the label is
            // routinely wider than the room it is given — it used to run off
            // the screen leaving one visible word. Shrinking cannot overflow
            // and cannot disturb the layout of the thing being pointed at,
            // which an OverflowBox here very much could.
            if (widget.label != null) ...[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  // The forge plate the rest of the game uses, not a
                  // Material pill: this sits beside bracketed frames and
                  // monospace labels and used to look borrowed.
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0F14).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _kLabelAccent.withValues(alpha: 0.75),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        AppIcons.touch_app_rounded,
                        color: _kLabelAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        widget.label!.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: _kLabelAccent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Clears the outer rule, which is laid outside the child's box
              // and so reaches up into this gap.
              const SizedBox(height: 13),
            ],

            // Highlighted content.
            //
            // A ring around the thing, not a wash over it. This used to be a
            // 20px saturated-amber box shadow at alpha 0.8 plus a 3px amber
            // border plus a 1.05 scale — around a full-width analysis panel
            // (sometimes three at once) that read as the whole sheet turning
            // yellow rather than as a pointer at one panel. It is now two
            // hairline rules stepped outward, breathing in opacity only:
            // no blur in the paint path, no scale, and — because the rules
            // are laid outside the child's box rather than around it — no
            // layout shift in whatever is being pointed at.
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Isolated so the ring's per-frame repaint does not drag the
                // highlighted panel's own painting along with it.
                RepaintBoundary(child: child),
                Positioned(
                  left: -5,
                  right: -5,
                  top: -4,
                  bottom: -4,
                  child: IgnorePointer(
                    child: _Rule(
                      radius: 12,
                      width: 1.3,
                      alpha: 0.34 + 0.30 * _breathe.value,
                    ),
                  ),
                ),
                Positioned(
                  left: -10,
                  right: -10,
                  top: -9,
                  bottom: -9,
                  child: IgnorePointer(
                    child: _Rule(
                      radius: 16,
                      width: 1,
                      alpha: 0.07 + 0.13 * _breathe.value,
                    ),
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

/// One hairline amber rule of the highlight ring.
class _Rule extends StatelessWidget {
  final double radius;
  final double width;
  final double alpha;

  const _Rule({
    required this.radius,
    required this.width,
    required this.alpha,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: _kLabelAccent.withValues(alpha: alpha),
          width: width,
        ),
      ),
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
        ..color = glowColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
      anchor: Anchor.center,
      position: size / 2,
    );

    // Middle glow ring
    final middleRing = CircleComponent(
      radius: radius * 1.15,
      paint: Paint()
        ..color = glowColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
      anchor: Anchor.center,
      position: size / 2,
    );

    // Inner glow ring
    final innerRing = CircleComponent(
      radius: radius,
      paint: Paint()
        ..color = glowColor.withValues(alpha: 0.7)
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
