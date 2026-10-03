// lib/screens/cosmic/widgets/coach_mark.dart
//
// The one way cosmic space points at a control: a short line in a bracket
// frame set beside the control, and the control itself framed by bracket
// corners that breathe in and out over a soft pool of its accent — the
// same halo the home Field tutorial puts on its dock (side_dock_widget's
// _TutorialHaloPainter). No blur anywhere: the glow is a radial gradient.
//
// The mark finds its control by GlobalKey, so it follows the real button
// wherever the HUD lays it out (safe area, collapsed HUD, joystick size)
// instead of guessing at offsets. One animation controller drives the halo,
// which repaints alone behind a RepaintBoundary; the label is rebuilt only
// when the control moves.

import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

import 'cosmic_panel_kit.dart';

/// Where the label sits against its control. [auto] puts it on the side of
/// the control with more room.
enum CoachMarkSide { auto, left, right, above, below }

/// A coach mark over the whole screen: put it in a [Positioned.fill]. It
/// ignores touches, so the control it frames still answers them.
class CosmicCoachMark extends StatefulWidget {
  const CosmicCoachMark({
    super.key,
    required this.text,
    this.target,
    this.accent = const Color(0xFF00E5FF),
    this.side = CoachMarkSide.auto,
  });

  /// What to do, in a line or two.
  final String text;

  /// The control to frame. Without one, the label sits at the top of the
  /// screen on its own.
  final GlobalKey? target;

  final Color accent;
  final CoachMarkSide side;

  @override
  State<CosmicCoachMark> createState() => _CosmicCoachMarkState();
}

class _CosmicCoachMarkState extends State<CosmicCoachMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  Rect? _target;

  @override
  void initState() {
    super.initState();
    _pulse.addListener(_track);
    WidgetsBinding.instance.addPostFrameCallback((_) => _track());
  }

  @override
  void didUpdateWidget(CosmicCoachMark old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _track());
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Where the control is now, in this mark's own coordinates.
  Rect? _measure() {
    final me = context.findRenderObject();
    final it = widget.target?.currentContext?.findRenderObject();
    if (me is! RenderBox || it is! RenderBox) return null;
    if (!me.attached || !it.attached || !me.hasSize || !it.hasSize) {
      return null;
    }
    return it.localToGlobal(Offset.zero, ancestor: me) & it.size;
  }

  void _track() {
    if (!mounted) return;
    final r = _measure();
    final old = _target;
    final moved =
        (r == null) != (old == null) ||
        (r != null &&
            old != null &&
            ((r.left - old.left).abs() > 0.5 ||
                (r.top - old.top).abs() > 0.5 ||
                (r.width - old.width).abs() > 0.5 ||
                (r.height - old.height).abs() > 0.5));
    if (moved) setState(() => _target = r);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final target = _target;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          final safe = Rect.fromLTRB(
            pad.left + 10,
            pad.top + 10,
            size.width - pad.right - 10,
            size.height - pad.bottom - 10,
          );
          return Stack(
            children: [
              if (target != null)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: CoachHaloPainter(
                        pulse: _pulse,
                        target: target,
                        accent: widget.accent,
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: CustomSingleChildLayout(
                  delegate: _LabelPlacement(
                    target: target,
                    safe: safe,
                    side: widget.side,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (size.width * 0.42).clamp(180.0, 300.0),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: CoachMarkLabel(
                        key: ValueKey(widget.text),
                        text: widget.text,
                        accent: widget.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The label alone: a line of plain text in a dark bracket frame, with a
/// fleck of the accent at its head.
class CoachMarkLabel extends StatelessWidget {
  const CoachMarkLabel({super.key, required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const palette = BracketPalette.dark;
    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: accent.withValues(alpha: 0.85),
        bracketSize: 7,
        strokeWidth: 1.2,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color.alphaBlend(
                accent.withValues(alpha: 0.10),
                palette.bg0.withValues(alpha: 0.94),
              ),
              palette.bg0.withValues(alpha: 0.92),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 9, 13, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: SizedBox.square(
                  dimension: 5,
                  child: ColoredBox(color: accent),
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: panelMono,
                    color: palette.ink,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sets the label beside its control, on the side with room, inside the
/// safe area; at the top of the screen when there is no control.
class _LabelPlacement extends SingleChildLayoutDelegate {
  _LabelPlacement({
    required this.target,
    required this.safe,
    required this.side,
  });

  final Rect? target;
  final Rect safe;
  final CoachMarkSide side;

  static const double _gap = 18;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    double clampX(double x) =>
        x.clamp(safe.left, (safe.right - child.width).clamp(safe.left, 1e9));
    double clampY(double y) =>
        y.clamp(safe.top, (safe.bottom - child.height).clamp(safe.top, 1e9));
    final t = target;
    if (t == null) {
      return Offset(
        clampX((size.width - child.width) / 2),
        clampY(safe.top + 4),
      );
    }
    var s = side;
    if (s == CoachMarkSide.auto) {
      final roomLeft = t.left - _gap - safe.left;
      final roomRight = safe.right - t.right - _gap;
      if (child.width <= roomLeft || child.width <= roomRight) {
        s = roomRight >= roomLeft ? CoachMarkSide.right : CoachMarkSide.left;
      } else {
        s = t.center.dy > size.height / 2
            ? CoachMarkSide.above
            : CoachMarkSide.below;
      }
    }
    return switch (s) {
      CoachMarkSide.left => Offset(
        clampX(t.left - _gap - child.width),
        clampY(t.center.dy - child.height / 2),
      ),
      CoachMarkSide.right => Offset(
        clampX(t.right + _gap),
        clampY(t.center.dy - child.height / 2),
      ),
      CoachMarkSide.above => Offset(
        clampX(t.center.dx - child.width / 2),
        clampY(t.top - _gap - child.height),
      ),
      _ => Offset(
        clampX(t.center.dx - child.width / 2),
        clampY(t.bottom + _gap),
      ),
    };
  }

  @override
  bool shouldRelayout(_LabelPlacement old) =>
      old.target != target || old.safe != safe || old.side != side;
}

/// The halo round a control: a soft pool of its accent just outside it and
/// bracket corners that ease out and back. Blur-free.
class CoachHaloPainter extends CustomPainter {
  CoachHaloPainter({
    required this.pulse,
    required this.target,
    required this.accent,
  }) : super(repaint: pulse);

  final Animation<double> pulse;
  final Rect target;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeInOut.transform(pulse.value);
    final c = target.center;
    final inner = target.shortestSide * 0.5;
    final r = target.longestSide * 0.95 + 10 + 6 * t;
    // A ring of light, clear over the control so its glyph stays legible.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0),
            accent.withValues(alpha: 0.06 + 0.05 * t),
            accent.withValues(alpha: 0.22 + 0.12 * t),
            accent.withValues(alpha: 0),
          ],
          stops: [0, inner / r * 0.8, (inner / r + 1) / 2 * 0.92, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final frame = target.inflate(6 + 5 * t);
    canvas.save();
    canvas.translate(frame.left, frame.top);
    BracketFramePainter(
      color: accent.withValues(alpha: 0.6 + 0.4 * t),
      bracketSize: 11,
      strokeWidth: 1.6,
    ).paint(canvas, frame.size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CoachHaloPainter old) =>
      old.target != target || old.accent != accent || old.pulse != pulse;
}
