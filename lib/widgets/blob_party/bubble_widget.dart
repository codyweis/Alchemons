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
                child: _GooOrb(
                  size: r * 2,
                  tint: widget.color,
                  highlight: widget.color.withOpacity(0.85),
                  expanded: widget.bubble.expanded as bool,
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
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GooOrb extends StatelessWidget {
  const _GooOrb({
    required this.size,
    required this.tint,
    required this.highlight,
    required this.expanded,
    this.child,
  });
  final double size;
  final Color tint;
  final Color highlight;
  final bool expanded;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final glass = BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          tint.withOpacity(0.22),
          tint.withOpacity(expanded ? 0.34 : 0.26),
        ],
        stops: const [0.35, 1.0],
      ),
      boxShadow: [
        BoxShadow(
          color: tint.withOpacity(0.35),
          blurRadius: 16,
          spreadRadius: 1,
        ),
      ],
      border: Border.all(color: tint.withOpacity(0.6), width: 1.6),
    );

    return Container(
      width: size,
      height: size,
      decoration: glass,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(expanded ? 0.22 : 0.14),
                      Colors.transparent,
                    ],
                    radius: 0.85,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: size * 0.18,
            top: size * 0.18,
            child: Container(
              width: size * 0.28,
              height: size * 0.18,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(size),
                boxShadow: [
                  BoxShadow(
                    color: highlight.withOpacity(0.35),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          if (child != null) Positioned.fill(child: child!),
        ],
      ),
    );
  }
}
