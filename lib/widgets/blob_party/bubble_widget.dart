// lib/widgets/blob_party/bubble_widget.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

typedef InsideBuilder = Widget Function(_BubblePublic b);

class _BubblePublic {
  _BubblePublic({required this.expanded});
  final bool expanded;
}

/// Visual & interaction layer for one bubble (no physics here).
class BubbleWidget extends StatefulWidget {
  const BubbleWidget({
    super.key,
    required this.bubble, // physics model from overlay (dynamic ok)
    required this.color,
    required this.onTap, // toggle expand/collapse (or pick)
    required this.builderInside,
    this.onDragStart, // NEW
    this.onDragUpdate, // NEW: delta Offset
    this.onDragEnd, // NEW: Velocity
    this.onLongPress, // NEW: context menu from overlay
  });

  final dynamic bubble;
  final Color color;
  final VoidCallback onTap;
  final InsideBuilder builderInside;

  // NEW
  final VoidCallback? onDragStart;
  final ValueChanged<Offset>? onDragUpdate;
  final ValueChanged<Velocity>? onDragEnd;
  final VoidCallback? onLongPress;

  @override
  State<BubbleWidget> createState() => BubbleWidgetState();
}

class BubbleWidgetState extends State<BubbleWidget>
    with TickerProviderStateMixin {
  late final AnimationController _gooCtrl;
  late final AnimationController _boopCtrl;

  // Tap-vs-drag discrimination
  double _dragDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _gooCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _boopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _gooCtrl.dispose();
    _boopCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BubbleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final expanded = widget.bubble.expanded as bool;
    if (expanded && !_gooCtrl.isAnimating) _gooCtrl.forward();
    if (!expanded && !_gooCtrl.isAnimating) _gooCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.bubble.radius as double;
    final pos = widget.bubble.pos as Offset;

    return Positioned(
      left: pos.dx - r,
      top: pos.dy - r,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // <- easier to hit
        // ✅ TAP PATH (always available even if no pan is recognized)
        onTapDown: (_) => _boopCtrl.forward(from: 0),
        onTapUp: (_) => _boopCtrl.reverse(),
        onTapCancel: () => _boopCtrl.reverse(),
        onTap: widget.onTap, // <- THIS is the important part
        // ✅ DRAG PATH (only fires once finger exceeds system slop)
        onPanStart: (_) {
          _dragDistance = 0;
          widget.onDragStart?.call();
        },
        onPanUpdate: (d) {
          _dragDistance += d.delta.distance;
          widget.onDragUpdate?.call(d.delta);
        },
        onPanEnd: (d) {
          _boopCtrl.reverse();
          // Don't attempt to treat pan as tap; if a pan won, it already moved past slop.
          widget.onDragEnd?.call(d.velocity);
        },
        onPanCancel: () => _boopCtrl.reverse(),
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: Listenable.merge([_gooCtrl, _boopCtrl]),
          builder: (_, __) {
            final goo = Curves.easeOutBack.transform(_gooCtrl.value); // 0..1
            final boop = math.sin(_boopCtrl.value * math.pi); // 0..1
            final scale = 1.0 + goo * 0.45 + boop * 0.06;
            final squish = 1.0 - boop * 0.06;

            return Transform.scale(
              scale: scale,
              child: Transform.scale(
                scaleY: squish,
                // --- THIS IS THE REPLACED WIDGET ---
                child: AlchemicalOrb(
                  color: widget.color,
                  radius: r,
                  pulseDriver: widget.bubble.life as double,
                  child: IgnorePointer(
                    ignoring: !widget.bubble.expanded,
                    child: ClipOval(
                      child: SizedBox(
                        width: r * 2,
                        height: r * 2,
                        child: Center(
                          child: widget.builderInside(
                            _BubblePublic(expanded: widget.bubble.expanded),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // --- END REPLACEMENT ---
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- NEW ALCHEMICAL ORB (MOVED FROM OTHER FILE) ---
class AlchemicalOrb extends StatelessWidget {
  /// The base color for the orb and its glow.
  final Color color;

  /// The radius of the orb's "glass" body.
  final double radius;

  /// Pass the bubble's life/seed to drive the pulse.
  final double pulseDriver;

  /// The content to display "inside" the orb.
  final Widget? child;

  const AlchemicalOrb({
    super.key,
    required this.color,
    required this.radius,
    required this.pulseDriver,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    // A slow, gentle pulse from 0.8 to 1.2
    final pulse = 1.0 + (math.sin(pulseDriver * 1.5) * 0.2);

    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Outer Aura/Glow (pulsing)
        Container(
          width: radius * 2.5 * pulse,
          height: radius * 2.5 * pulse,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withOpacity(0.2), // Inner glow
                color.withOpacity(0.0), // Fades to nothing
              ],
              stops: const [0.3, 1.0], // Glow is 30% of radius
            ),
          ),
        ),

        // 2. The "Glass" Orb Body
        Container(
          width: radius * 2.0,
          height: radius * 2.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Main body gradient (gives it 3D depth)
            gradient: RadialGradient(
              colors: [
                _lighten(color, 0.2), // Center highlight
                color,
                _darken(color, 0.4), // Darker edge
              ],
              stops: const [0.0, 0.7, 1.0],
            ),
          ),
        ),

        // 3. Child content (rendered before the highlight)
        if (child != null) Positioned.fill(child: child!),

        // 4. Specular Highlight (the "sheen")
        Container(
          width: radius * 2.0,
          height: radius * 2.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // A white gradient, offset to the top-left
            gradient: RadialGradient(
              center: const Alignment(-0.6, -0.6), // Top-left
              radius: 0.7,
              colors: [
                Colors.white.withOpacity(0.4), // Highlight
                Colors.white.withOpacity(0.0), // Fades
              ],
              stops: const [0.0, 0.6],
            ),
          ),
        ),
      ],
    );
  }

  // Helper functions to adjust color
  Color _lighten(Color c, double amount) {
    return Color.fromARGB(
      c.alpha,
      (c.red + (255 - c.red) * amount).round().clamp(0, 255),
      (c.green + (255 - c.green) * amount).round().clamp(0, 255),
      (c.blue + (255 - c.blue) * amount).round().clamp(0, 255),
    );
  }

  Color _darken(Color c, double amount) {
    return Color.fromARGB(
      c.alpha,
      (c.red * (1 - amount)).round().clamp(0, 255),
      (c.green * (1 - amount)).round().clamp(0, 255),
      (c.blue * (1 - amount)).round().clamp(0, 255),
    );
  }
}
