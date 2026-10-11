import 'dart:math' as math;

import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Tincture, the Athanor's reagent, drawn as one drop of it.
///
/// A bead of dark glass with ember and gold grains turning in it — the same
/// sphere as the shop's other item glyphs ([GrainGlass]) — drawn up at the
/// top into the drop's point, a short taper of grains. Under it a pool of
/// its light, and a grain gathering at its foot that falls into the pool
/// and is gone, the way a tincture is measured out a drop at a time.
class TinctureGlyph extends StatelessWidget {
  const TinctureGlyph({super.key, required this.size, this.animate = true});

  final double size;

  /// Off for a still frame; a list row scrolling past does not need to run.
  final bool animate;

  @override
  Widget build(BuildContext context) => GrainGlyph(
    size: size,
    animate: animate,
    painter: (clock) => _TincturePainter(clock),
  );
}

class _TincturePainter extends CustomPainter {
  _TincturePainter(this.clock) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// One drop: gathering at the bead's foot, falling, lost in the pool.
  static const double _period = 3.2;

  /// A still glyph shows the drop full and about to fall.
  static const double _still = 0.5 * _period;

  static const Color _ember = Color(0xFFD9532B);
  static const Color _gold = Color(0xFFE8B84A);

  static final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = (clock?.value ?? 0) + _still;
    final p = (t % _period) / _period;
    final o = Offset(size.width / 2, size.height / 2);
    final r = s * 0.28;
    final bead = o + Offset(0, s * 0.08);
    final poolAt = bead + Offset(0, r * 1.35);
    final d = (s * 0.022).clamp(0.8, 2.6);

    GrainGlass.pool(canvas, poolAt, r * 1.05, _ember, alpha: 0.5);

    _point(canvas, bead, r, d);
    GrainGlass.sphere(
      canvas,
      bead,
      r,
      t,
      a: _ember,
      b: _gold,
      spin: 0.6,
      heat: 0.25,
      heatColor: _gold,
      salt: 9,
    );
    _drip(canvas, bead, r, poolAt, d, p);
  }

  /// The drop's point: a cone of grains drawn up out of the top of the
  /// bead, wide where it leaves the glass and narrowing to one grain,
  /// brighter at its root.
  void _point(Canvas canvas, Offset bead, double r, double d) {
    const rows = 13;
    var salt = 0;
    for (var row = 0; row < rows; row++) {
      final q = row / (rows - 1);
      final y = bead.dy - r * (0.7 + 0.85 * q);
      final half = r * 0.5 * (1 - q) * (1 - q * 0.35);
      final count = (1 + 6 * (1 - q)).round();
      for (var k = 0; k < count; k++) {
        final across = count == 1 ? 0.0 : k / (count - 1) * 2 - 1;
        final jitter = (GrainGlass.h(salt++, 31) - 0.5) * r * 0.1;
        final x = bead.dx + across * half + jitter + r * 0.05 * q;
        _p.color = Color.lerp(
          _ember,
          _gold,
          0.35 + 0.5 * q,
        )!.withValues(alpha: 0.8 * (1 - 0.5 * q));
        canvas.drawCircle(Offset(x, y), d * (0.7 - 0.25 * q), _p);
      }
    }
  }

  /// A grain swelling at the bead's foot, then falling into the pool with a
  /// short trail, and fading there.
  void _drip(
    Canvas canvas,
    Offset bead,
    double r,
    Offset poolAt,
    double d,
    double p,
  ) {
    final foot = bead + Offset(0, r * 0.98);
    if (p < 0.55) {
      // Gathering.
      final grow = GrainGlass.smooth(p / 0.55);
      _p.color = Color.lerp(_ember, _gold, 0.5)!.withValues(alpha: 0.9 * grow);
      canvas.drawCircle(
        foot + Offset(0, d * 1.2 * grow),
        d * (0.4 + 0.8 * grow),
        _p,
      );
      return;
    }
    // Falling, quickening, and lost in the pool's light.
    final f = ((p - 0.55) / 0.3).clamp(0.0, 1.0);
    final fade = 1 - GrainGlass.smooth((p - 0.8) / 0.2);
    if (fade <= 0.01) return;
    final fall = f * f;
    final from = foot + Offset(0, d * 1.2);
    final to = poolAt;
    for (var k = 0; k < 3; k++) {
      final back = math.max(0.0, fall - k * 0.08);
      final at = Offset.lerp(from, to, back)!;
      _p.color = Color.lerp(
        _gold,
        Colors.white,
        0.2,
      )!.withValues(alpha: (0.9 - k * 0.28) * fade);
      canvas.drawCircle(at, d * (1.1 - k * 0.25), _p);
    }
  }

  @override
  bool shouldRepaint(covariant _TincturePainter old) => old.clock != clock;
}
