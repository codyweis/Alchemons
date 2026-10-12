import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Sparks, the Furnace's reagent (in code still "tincture"), drawn as a
/// bead of embers giving off sparks.
///
/// A bead of dark glass with ember and gold grains turning hot in it, the
/// same sphere as the shop's other item glyphs ([GrainGlass]), over a pool
/// of its light, and a few sparks drifting up off its top, each bright as it
/// leaves and dying out as it climbs, as they rise off the Furnace's flue.
class TinctureGlyph extends StatelessWidget {
  const TinctureGlyph({super.key, required this.size, this.animate = true});

  final double size;

  /// Off for a still frame; a list row scrolling past does not need to run.
  final bool animate;

  @override
  Widget build(BuildContext context) => GrainGlyph(
    size: size,
    animate: animate,
    painter: (clock) => _SparksPainter(clock),
  );
}

class _SparksPainter extends CustomPainter {
  _SparksPainter(this.clock) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// How long one spark takes to rise and die.
  static const double _period = 2.2;

  /// The sparks in the air at once, each on its own offset of the period.
  static const int _sparks = 7;

  /// A still glyph shows them spread through their rise.
  static const double _still = 0.37 * _period;

  static const Color _ember = Color(0xFFD9532B);
  static const Color _gold = Color(0xFFE8B84A);

  static final Paint _p = Paint();

  /// A spark's warm light at unit size; its strength rides the alpha.
  static final Paint _glow = Paint()
    ..shader = ui.Gradient.radial(
      Offset.zero,
      1,
      [
        _ember.withValues(alpha: 0.7),
        _ember.withValues(alpha: 0.22),
        _ember.withValues(alpha: 0),
      ],
      const [0.0, 0.45, 1.0],
    );

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = (clock?.value ?? 0) + _still;
    final o = Offset(size.width / 2, size.height / 2);
    final r = s * 0.28;
    final bead = o + Offset(0, s * 0.14);
    final poolAt = bead + Offset(0, r * 1.25);
    final d = (s * 0.024).clamp(0.8, 2.8);

    GrainGlass.pool(canvas, poolAt, r * 1.05, _ember, alpha: 0.5);
    GrainGlass.sphere(
      canvas,
      bead,
      r,
      t,
      a: _ember,
      b: _gold,
      spin: 0.6,
      heat: 0.55,
      heatColor: _gold,
      salt: 9,
    );
    for (var k = 0; k < _sparks; k++) {
      _spark(canvas, bead, r, d, t / _period + k / _sparks, k);
    }
  }

  /// Spark [k] at [phase] of its rise: each has its own bearing in a fan
  /// above the bead, so together they spray up and out off its crown,
  /// bright as they leave and dying out as they climb, with a short tail.
  void _spark(
    Canvas canvas,
    Offset bead,
    double r,
    double d,
    double phase,
    int k,
  ) {
    final p = phase % 1.0;
    final cycle = (phase - p).floor();
    final life = math.sin(math.pi * math.min(1.0, p * 1.2));
    if (life <= 0.02) return;
    // Bearings spread evenly over the fan (in a mixed order, so neighbours
    // in time are not neighbours in space), nudged a little each time round.
    final slot = (k * 3) % _sparks;
    final bearing =
        (-0.62 + 1.24 * slot / (_sparks - 1)) +
        (GrainGlass.h(k * 7 + cycle, 41) - 0.5) * 0.18;
    final reach = r * (1.5 + 0.8 * GrainGlass.h(k * 5 + cycle, 43));
    final size = 0.75 + 0.6 * GrainGlass.h(k * 3 + cycle, 47);
    final from = bead + Offset(math.sin(bearing) * r * 0.55, -r * 0.8);
    for (var tail = 0; tail < 2; tail++) {
      final q = math.max(0.0, p - tail * 0.05);
      // Out along its bearing, the climb easing as it cools.
      final go = reach * (1 - (1 - q) * (1 - q));
      final at =
          from +
          Offset(math.sin(bearing), -math.cos(bearing)) * go +
          Offset(0, -r * 0.25 * q);
      final a = life * (1 - tail * 0.55) * (1 - 0.5 * q);
      if (tail == 0) {
        // Its heat round it: a soft warm light under the hot core, fading
        // to nothing at its edge (a cached unit gradient, scaled).
        final g = d * size * 2.6;
        canvas
          ..save()
          ..translate(at.dx, at.dy)
          ..scale(g);
        _glow.color = Color.fromRGBO(255, 255, 255, 0.55 * a);
        canvas.drawCircle(Offset.zero, 1, _glow);
        canvas.restore();
      }
      _p.color = Color.lerp(
        tail == 0 ? _gold : _ember,
        Colors.white,
        tail == 0 ? 0.55 : 0.1,
      )!.withValues(alpha: a);
      canvas.drawCircle(at, d * size * (1 - tail * 0.4), _p);
    }
  }

  @override
  bool shouldRepaint(covariant _SparksPainter old) => old.clock != clock;
}
