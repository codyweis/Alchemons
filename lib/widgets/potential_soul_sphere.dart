import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/fx/soul_wisp.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A Potential Soul, wherever one is shown — inventory, rewards, the shop and
/// Stat Infusion: a wisp of light burning up out of a white-hot heart (see
/// [SoulWispPaint]). A flame, where a power orb is a sphere.
///
/// [tint] recolors it to the stat it is set to; null keeps the canonical
/// violet. [animate] lets it burn — on the shared glyph clock, and only
/// while its screen is showing; a still one is a single frame.
class PotentialSoulSphere extends StatefulWidget {
  const PotentialSoulSphere({
    super.key,
    this.size = 48,
    this.tint,
    this.animate = false,
  });

  final double size;
  final Color? tint;
  final bool animate;

  /// The soul's own color, unset to any stat.
  static const Color canonical = Color(0xFFB66CFF);

  @override
  State<PotentialSoulSphere> createState() => _PotentialSoulSphereState();
}

class _PotentialSoulSphereState extends State<PotentialSoulSphere>
    with GlyphClockLease {
  bool _visible = true;

  @override
  bool get wantsClock => widget.animate && _visible;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      syncGlyphClock();
    }
  }

  @override
  void didUpdateWidget(covariant PotentialSoulSphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncGlyphClock();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        willChange: widget.animate,
        painter: _SoulPainter(
          widget.tint ?? PotentialSoulSphere.canonical,
          clock: glyphClock,
        ),
      ),
    );
  }
}

class _SoulPainter extends CustomPainter {
  _SoulPainter(this.tint, {required this.clock}) : super(repaint: clock);

  final Color tint;
  final ValueListenable<double>? clock;

  @override
  void paint(Canvas canvas, Size size) => SoulWispPaint.paint(
    canvas,
    size.center(Offset.zero),
    size.shortestSide,
    tint,
    // A still soul is caught mid-burn, not at the start of its cycle.
    clock?.value ?? 1.3,
  );

  @override
  bool shouldRepaint(_SoulPainter old) =>
      old.tint != tint || old.clock != clock;
}
