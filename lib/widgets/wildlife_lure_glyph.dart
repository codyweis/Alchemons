import 'dart:math' as math;

import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The Wildlife Lure: bait that gives off a scent, and something wild that
/// follows it in.
///
/// The bait is a small warm sphere of glass. Its scent leaves it as a drift
/// of grains, wandering out to the edge; a wild Alchemon — loose grains, the
/// same as the wild one in [WildFusionGlyph] — comes in from the far end
/// along that same drift, slowing as it nears, and circles the bait once it
/// is there. Nothing catches it: that is the harvester's job, not this one.
class WildlifeLureGlyph extends StatelessWidget {
  const WildlifeLureGlyph({super.key, required this.size, this.animate = true});

  final double size;

  /// Off for a still frame; a shop card scrolling past does not need to run.
  final bool animate;

  @override
  Widget build(BuildContext context) => GrainGlyph(
    size: size,
    animate: animate,
    painter: (clock) => _WildlifeLurePainter(clock),
  );
}

class _WildlifeLurePainter extends CustomPainter {
  _WildlifeLurePainter(this.clock) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// One arrival: in along the scent, round the bait, gone.
  static const double _period = 6.4;

  /// A still glyph shows it come in and circling.
  static const double _still = 0.62 * _period;

  static const Color _bait = Color(0xFFF5C863);
  static const Color _bloom = Color(0xFF6BCF7F);
  static const Color _wild = Color(0xFF4FD1C5);

  static const int _scent = 64;
  static final GrainBatch _b = GrainBatch(4);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = (clock?.value ?? 0) + _still;
    final cycle = (t / _period).floor();
    final p = (t % _period) / _period;
    final bait = Offset(size.width / 2 - s * 0.09, size.height / 2 + s * 0.08);
    final baitR = s * 0.17;

    // The drift, from the bait out to the edge: upper right, wandering, and
    // not quite the same way twice.
    final phi = -0.62 + 0.28 * math.sin(cycle * 2.1);
    final along = Offset(math.cos(phi), math.sin(phi));
    final across = Offset(-along.dy, along.dx);
    final reach = s * 0.52;
    Offset drift(double u) =>
        bait +
        along * (reach * u) +
        across * (math.sin(u * math.pi * 2.1 + 0.4) * s * 0.075 * u);

    // ── the scent ──
    final come = GrainGlass.smooth((p - 0.06) / 0.5);
    final circling = GrainGlass.smooth((p - 0.52) / 0.1);
    final leave = GrainGlass.smooth((p - 0.86) / 0.14);
    final scent = 0.5 + 0.5 * (1 - circling) + 0.5 * leave;
    final b = _b..clear();
    final d = (s * 0.017).clamp(1.0, 2.4);
    for (var i = 0; i < _scent; i++) {
      final q = (t * 0.13 + GrainGlass.h(i, 31)) % 1.0;
      final u = 0.12 + 0.88 * q;
      final sway =
          (GrainGlass.h(i, 32) - 0.5) * s * (0.03 + 0.07 * u) +
          math.sin(t * 0.9 + i * 1.3) * s * 0.012 * u;
      final pos = drift(u) + across * sway;
      // Thick near the bait, thinning out to nothing at the edge.
      final band = q < 0.15 ? 0 : (q < 0.55 ? 1 : (q < 0.85 ? 2 : 3));
      b.add(band, pos.dx, pos.dy);
    }
    final warm = Color.lerp(_bait, _bloom, 0.45)!;
    const fades = [0.36, 0.56, 0.34, 0.14];
    for (var k = 0; k < 4; k++) {
      b.draw(
        canvas,
        k,
        d * (1.15 - k * 0.15),
        Color.lerp(
          warm,
          Colors.white,
          0.25,
        )!.withValues(alpha: (fades[k] * scent).clamp(0.0, 1.0)),
      );
    }

    // ── what comes ──
    // In along the drift, slowing as it nears; then round the bait.
    final inU = 1.08 - 0.8 * Curves.easeOutCubic.transform(come);
    final arrivedAt = drift(0.28);
    final start = arrivedAt - bait;
    final startA = math.atan2(start.dy / 0.8, start.dx);
    final orbitA = startA - 1.5 * math.max(0.0, p - 0.56) / 0.44 * math.pi;
    final orbitR = start.distance + (s * 0.27 - start.distance) * circling;
    final round =
        bait + Offset(math.cos(orbitA), math.sin(orbitA) * 0.8) * orbitR;
    final at = Offset.lerp(drift(inU), round, circling)!;
    final behind = circling > 0.5 && math.sin(orbitA) < -0.15;
    final enter = GrainGlass.smooth((p - 0.04) / 0.14);

    void wild() => GrainGlass.sphere(
      canvas,
      at,
      s * 0.125,
      t,
      a: _wild,
      b: Color.lerp(_wild, Colors.white, 0.35),
      spin: 1.1,
      glass: 0,
      gather: 0.78 * enter * (1 - 0.7 * leave),
      fade: enter * (1 - leave),
      glow: 0.8,
      salt: 21,
    );

    if (behind) wild();

    // ── the bait ──
    final breathe = 0.5 + 0.5 * math.sin(t * 1.6);
    GrainGlass.sphere(
      canvas,
      bait,
      baitR,
      t,
      a: _bait,
      b: Color.lerp(_bait, _bloom, 0.4),
      spin: 0.45,
      heat: 0.2 + 0.25 * breathe,
      heatColor: _bait,
      salt: 22,
    );

    if (!behind) wild();
  }

  @override
  bool shouldRepaint(covariant _WildlifeLurePainter old) => old.clock != clock;
}
