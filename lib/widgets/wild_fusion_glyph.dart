import 'dart:math' as math;

import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The Wild Fusion catalyst, drawn as the fusion it makes.
///
/// Two Alchemons as grains, the way every fusion draws them: the wild one
/// loose and ragged, the party one gathered. They circle each other, closing
/// and quickening, until they run together into one cultivation — a glass
/// sphere of both lineages turning against each other — which holds, then
/// drifts apart into grains for the next. One gold grain rides in with the
/// wild one and stays at the heart of what it makes: the wild's best
/// Potential always passes.
class WildFusionGlyph extends StatelessWidget {
  const WildFusionGlyph({super.key, this.size = 48, this.animate = true});

  final double size;

  /// Grids render many of these at once; leave it off there and the glyph
  /// settles on a legible resting frame instead of running.
  final bool animate;

  @override
  Widget build(BuildContext context) => GrainGlyph(
    size: size,
    animate: animate,
    painter: (clock) => _WildFusionPainter(clock),
  );
}

class _WildFusionPainter extends CustomPainter {
  _WildFusionPainter(this.clock) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// Gather, circle in, run together, hold, let go.
  static const double _period = 6.0;

  /// A still glyph shows the two close and about to meet: two becoming one
  /// reads better than either alone.
  static const double _still = 0.32 * _period;

  static const Color _wild = Color(0xFF4FD1C5);
  static const Color _party = Color(0xFFFFA94D);
  static const Color _gold = Color(0xFFE8B84A);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = (clock?.value ?? 0) + _still;
    final p = (t % _period) / _period;
    final o = Offset(size.width / 2, size.height / 2);

    // The next pair starts gathering while the last cultivation lets go, so
    // the glyph is never empty: their timeline runs a tenth ahead.
    final ahead = p >= 0.9;
    final q = ahead ? p - 1 : p;
    final cycle = (t / _period).floor() + (ahead ? 1 : 0);

    // ── the approach: closing and quickening, falling together ──
    final a = (q / 0.5).clamp(0.0, 1.0);
    final fall = a * a;
    final sep = s * 0.25 * (1 - fall);
    final theta = cycle * 1.9 + 0.6 + 2.4 * a + 3.0 * a * a * a;
    final arrive = GrainGlass.smooth((q + 0.1) / 0.24);
    final meet = GrainGlass.smooth((q - 0.4) / 0.14);

    // ── the cultivation they make ──
    final form = GrainGlass.smooth((p - 0.38) / 0.24);
    final loosen = GrainGlass.smooth((p - 0.9) / 0.1);
    final merged = form * (1 - loosen);

    final dir = Offset(math.cos(theta), math.sin(theta) * 0.5);
    final wildAt = o + dir * sep;
    final partyAt = o - dir * sep;
    // The nearer one is drawn last and a little larger.
    final wildNear = math.sin(theta) >= 0;
    final swarmR = s * 0.165;
    final pair = 1 - meet;

    void wild() => GrainGlass.sphere(
      canvas,
      wildAt,
      swarmR * (wildNear ? 1.06 : 0.94),
      t,
      a: _wild,
      b: Color.lerp(_wild, Colors.white, 0.35),
      spin: 1.1,
      glass: 0,
      // Never quite gathered: it is still wild.
      gather: 0.8 * arrive,
      squeeze: 1 - 0.4 * meet,
      fade: pair * arrive,
      glow: 0.9,
      salt: 11,
    );
    void party() => GrainGlass.sphere(
      canvas,
      partyAt,
      swarmR * (wildNear ? 0.94 : 1.06),
      t,
      a: _party,
      b: Color.lerp(_party, Colors.white, 0.35),
      spin: -0.8,
      glass: 0,
      gather: arrive,
      squeeze: 1 - 0.4 * meet,
      fade: pair * arrive,
      glow: 0.9,
      salt: 12,
    );

    if (merged > 0.01) {
      GrainGlass.sphere(
        canvas,
        o,
        s * 0.28,
        t,
        a: _wild,
        b: _party,
        spin: 0.8,
        // Its heart runs gold: the wild's best, carried in.
        heat: 0.45 * merged,
        heatColor: _gold,
        glass: GrainGlass.smooth((p - 0.46) / 0.16) * (1 - loosen),
        gather: form * (1 - 0.6 * loosen),
        fade: merged,
        salt: 13,
      );
    }
    if (pair > 0.01 && arrive > 0.01) {
      if (wildNear) {
        party();
        wild();
      } else {
        wild();
        party();
      }
    }

    // ── the wild's best, carried in on the wild one ──
    final gold = arrive * pair;
    if (gold > 0.01) {
      final at = Offset.lerp(wildAt, o, meet)!;
      final beat = 0.5 + 0.5 * math.sin(t * 2.4);
      GrainGlass.pool(
        canvas,
        at,
        s * (0.07 + 0.025 * beat),
        _gold,
        alpha: gold * 0.9,
      );
      GrainGlass.pool(
        canvas,
        at,
        s * 0.026,
        const Color(0xFFFFF4D6),
        alpha: gold,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WildFusionPainter old) => old.clock != clock;
}
