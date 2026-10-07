import 'dart:math' as math;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The Instant Fusion Extractor, drawn as the wait it skips.
///
/// One chamber's cultivation: its grains spin up the way a chamber's do as
/// extraction nears, a current of loose grains is drawn in round it, and it
/// tightens and runs gold — ready — in a moment. It is the same sphere as
/// [FusionChamberGlyph]'s chambers, so the two read as related: one buys a
/// chamber, this finishes what is in one.
class InstantExtractorGlyph extends StatelessWidget {
  const InstantExtractorGlyph({
    super.key,
    required this.size,
    this.animate = true,
  });

  final double size;

  /// Off for a still frame; a shop card scrolling past does not need to run.
  final bool animate;

  @override
  Widget build(BuildContext context) => GrainGlyph(
    size: size,
    animate: animate,
    painter: (clock) => _InstantExtractorPainter(clock),
  );
}

class _InstantExtractorPainter extends CustomPainter {
  _InstantExtractorPainter(this.clock) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// One spin-up, ready, and settle.
  static const double _period = 3.6;

  /// A still glyph shows it ready: tight, hot and gold.
  static const double _still = 0.74 * _period;

  static const _gold = Color(0xFFE8B84A);
  static final Color _a = ElementResources.byBiomeId['arcane']!.color;
  static final Color _b = ElementResources.byBiomeId['oceanic']!.color;

  static final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = (clock?.value ?? 0) + _still;
    final cycle = (t / _period).floorToDouble();
    final p = (t % _period) / _period;
    final o = Offset(size.width / 2, size.height / 2);
    final r = s * 0.33;

    // The turn: slow, then faster and faster, easing off once it is done.
    // Integrated, so the speed-up never jumps the grains backwards.
    double turn(double x) {
      final ramp = math.min(x, 0.7);
      final after = math.max(0.0, x - 0.7);
      return 1.2 * ramp + 7.0 * ramp * ramp * ramp + 3.2 * after;
    }

    final angle = turn(p) + cycle * turn(1.0);

    // Ready: drawn tight and running gold, then letting go.
    final ready =
        GrainGlass.smooth((p - 0.5) / 0.2) *
        (1 - GrainGlass.smooth((p - 0.86) / 0.14));
    final squeeze = 1 - 0.16 * ready;

    _current(canvas, o, r, s, p);

    GrainGlass.sphere(
      canvas,
      o,
      r,
      angle,
      a: _a,
      b: _b,
      spin: 1,
      squeeze: squeeze,
      heat: ready,
      heatColor: _gold,
      salt: 5,
    );
  }

  /// Loose grains drawn in round it while it spins up: one lopsided current
  /// from the upper right, each grain a short trail.
  void _current(Canvas canvas, Offset o, double r, double s, double p) {
    final strength =
        GrainGlass.smooth(p / 0.15) * (1 - GrainGlass.smooth((p - 0.55) / 0.2));
    if (strength <= 0.01) return;
    final d = (s * 0.02).clamp(0.9, 2.4);
    for (var i = 0; i < 22; i++) {
      final q = (p * 1.8 + GrainGlass.h(i, 21)) % 1.0;
      // In from 1.5r to the glass, winding a third of a turn.
      final a = -0.7 + GrainGlass.h(i, 22) * 1.3 + q * 2.0;
      final fade = math.sin(q * math.pi) * strength;
      for (var k = 0; k < 3; k++) {
        final back = k * 0.035;
        final rr = r * (1.5 - 0.5 * (q - back));
        final aa = a - back * 2.0;
        _p.color = Color.lerp(_b, Colors.white, 0.4)!.withValues(
          alpha: (0.7 - k * 0.22) * fade,
        );
        canvas.drawCircle(
          o + Offset(math.cos(aa) * rr, math.sin(aa) * rr * 0.9),
          d * (0.55 - k * 0.12),
          _p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _InstantExtractorPainter old) =>
      old.clock != clock;
}
