// lib/widgets/wilderness/tutorial_highlight.dart
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';

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
                      color: _kLabelAccent.withValues(alpha: 0.35),
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
                          color: Color(0xFFE8DCC8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
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
                // Bracket corners round the thing, breathing in opacity:
                // the game's pointer everywhere else (cosmic coach marks,
                // the home Field halo). They were two amber outline rings,
                // which read loud on a panel already full of light.
                Positioned(
                  left: -7,
                  right: -7,
                  top: -6,
                  bottom: -6,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: BracketFramePainter(
                        color: _kLabelAccent.withValues(
                          alpha: 0.35 + 0.4 * _breathe.value,
                        ),
                        bracketSize: 10,
                        strokeWidth: 1.4,
                      ),
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

/// The wilderness tutorial's pointer at a wild creature: a soft pool of warm
/// light under it that slowly breathes. It used to be three amber hoops,
/// scaling and spinning, which read as a target painted on the creature;
/// "material, not lines" — a light, not a ring. Its owner removes it once
/// the creature has been tapped.
class TutorialCreatureHighlight extends PositionComponent {
  final double radius;
  final Color glowColor;

  TutorialCreatureHighlight({
    required this.radius,
    this.glowColor = _kLabelAccent,
    Vector2? position,
  }) : super(position: position ?? Vector2.zero(), anchor: Anchor.center);

  double _t = 0;
  final Paint _paint = Paint();

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    // 0..1, a slow breath (about four seconds a cycle).
    final b = 0.5 + 0.5 * math.sin(_t * 1.6);
    final r = radius * (1.25 + 0.06 * b);
    // Centred a little low: light pooling where the creature stands.
    final c = Offset(0, radius * 0.18);
    _paint.shader = RadialGradient(
      colors: [
        glowColor.withValues(alpha: 0.16 + 0.08 * b),
        glowColor.withValues(alpha: 0.06 + 0.03 * b),
        glowColor.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, _paint);
  }
}
