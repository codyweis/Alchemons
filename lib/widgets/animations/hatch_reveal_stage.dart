import 'package:flutter/material.dart';

/// The specimen's moment: it is scanned large in the middle of the card, then
/// carried to its dock in the corner.
///
/// The scan used to happen at dock size in the top-left, which is where the
/// specimen *lives*, not where it should be revealed — the reveal is the point
/// of the screen and it was being played at thumbnail scale off to one side.
///
/// This owns the flight because the extraction dialog is a StatefulBuilder
/// with no ticker of its own.
class HatchRevealStage extends StatefulWidget {
  const HatchRevealStage({
    super.key,
    required this.dockKey,
    required this.heroSize,
    required this.dockSize,
    required this.scanComplete,
    required this.onLanded,
    required this.child,
  });

  /// The box in the card the specimen flies to.
  final GlobalKey dockKey;

  /// How large the specimen is drawn while it is being revealed.
  final double heroSize;

  /// Its size once docked, used to scale the flight.
  final double dockSize;

  /// Flips true when the scan finishes; that starts the flight.
  final bool scanComplete;

  /// Fired once it has landed, so the card can hand the sprite back to the
  /// dock and stop drawing this stage.
  final VoidCallback onLanded;

  final Widget child;

  @override
  State<HatchRevealStage> createState() => _HatchRevealStageState();
}

class _HatchRevealStageState extends State<HatchRevealStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 620),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onLanded();
      });

  /// Where the dock is, in this stage's own coordinates. Resolved when the
  /// flight starts rather than up front, because the card is still laying out
  /// while the scan runs.
  Rect? _target;

  @override
  void didUpdateWidget(covariant HatchRevealStage old) {
    super.didUpdateWidget(old);
    if (widget.scanComplete && !old.scanComplete) {
      // A beat to let the reveal land before it is taken away.
      Future<void>.delayed(const Duration(milliseconds: 620), _startFlight);
    }
  }

  void _startFlight() {
    if (!mounted || _ctrl.isAnimating || _ctrl.isCompleted) return;
    setState(() => _target = _resolveTarget());
    _ctrl.forward();
  }

  Rect? _resolveTarget() {
    final dockCtx = widget.dockKey.currentContext;
    final stage = context.findRenderObject();
    if (dockCtx == null || stage is! RenderBox || !stage.hasSize) return null;
    final dock = dockCtx.findRenderObject();
    if (dock is! RenderBox || !dock.hasSize) return null;
    final topLeft = stage.globalToLocal(dock.localToGlobal(Offset.zero));
    return topLeft & dock.size;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, c) {
            final hero = Rect.fromCenter(
              center: Offset(c.maxWidth / 2, c.maxHeight / 2),
              width: widget.heroSize,
              height: widget.heroSize,
            );
            // Without a measured dock the specimen simply stays centred and
            // fades, which is a worse reveal but never a broken one.
            final target = _target;
            final t = Curves.easeInOutCubic.transform(_ctrl.value);
            final rect = target == null ? hero : Rect.lerp(hero, target, t)!;

            return Stack(
              children: [
                // The card behind is dimmed while the specimen is centre
                // stage, and clears as it is put away.
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.55 * (1 - t)),
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: rect,
                  child: IgnorePointer(
                    child: FittedBox(fit: BoxFit.contain, child: child),
                  ),
                ),
              ],
            );
          },
        );
      },
      child: SizedBox(
        width: widget.heroSize,
        height: widget.heroSize,
        child: widget.child,
      ),
    );
  }
}
