import 'dart:math' as math;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Changing faction, drawn as what it is: one core, and the four factions'
/// essences drifting round it, taking turns to be the one it answers to.
///
/// An essence is a loose swarm of its element's grains. When its turn comes
/// it streams into the core, its colour sweeps through the core's grains from
/// the side it came in, and it gathers again where it was — so the icon is
/// never showing one faction, which is the whole point of the offer.
class FactionEssenceGlyph extends StatelessWidget {
  const FactionEssenceGlyph({
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
    painter: (clock) => _FactionEssencePainter(clock),
  );
}

class _FactionEssencePainter extends CustomPainter {
  _FactionEssencePainter(this.clock) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// One essence's turn; four make the loop.
  static const double _turn = 2.4;

  /// A still glyph sits just after a handover: the core one faction's colour
  /// through, the essence that gave it gathered again.
  static const double _still = 0.96 * _turn;

  /// The four playable factions, in their own colours — the same ones the
  /// harvest strip and the exchange use.
  static final List<Color> _colors = [
    for (final f in Factions.all)
      ElementResources.byBiomeId[f.id.name]?.color ?? const Color(0xFFE4C16A),
  ];

  /// Where each essence drifts: uneven angles and distances, not a ring.
  static const List<(double, double)> _homes = [
    (-2.55, 0.39),
    (-0.62, 0.41),
    (0.98, 0.37),
    (2.72, 0.4),
  ];

  static const int _grains = 18;
  static final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = (clock?.value ?? 0) + _still;
    final n = _colors.length;
    final turnNo = (t / _turn).floor();
    final k = turnNo % n;
    final u = (t % _turn) / _turn;
    final o = Offset(size.width / 2 + s * 0.015, size.height / 2 + s * 0.02);
    final coreR = s * 0.23;

    Offset home(int i) {
      final (a, d) = _homes[i];
      // Each drifts on its own slow loop.
      final w = t * 0.5 + i * 1.9;
      return o +
          Offset(math.cos(a) * d * s, math.sin(a) * d * s) +
          Offset(math.cos(w) * s * 0.02, math.sin(w * 1.3) * s * 0.016);
    }

    final before = _colors[(k - 1) % n];
    final now = _colors[k];

    // The colour front sweeps through the core from where the essence came.
    final (ha, _) = _homes[k];
    final ux = math.cos(ha), uy = math.sin(ha);
    final front = 1.25 - 2.5 * GrainGlass.smooth((u - 0.28) / 0.5);

    GrainGlass.sphere(
      canvas,
      o,
      coreR,
      t,
      a: before,
      b: now,
      inB: (x, y) => (x * ux + y * uy) / coreR > front,
      spin: 0.6,
      salt: 4,
    );

    for (var i = 0; i < n; i++) {
      final h = home(i);
      if (i != k) {
        _swarm(canvas, h, s, t, _colors[i], 1, i);
        continue;
      }
      // Its turn: streams in over the first half, gathers again after.
      final back = GrainGlass.smooth((u - 0.55) / 0.4);
      if (back > 0.01) _swarm(canvas, h, s, t, _colors[i], back, i);
      _stream(canvas, h, o, coreR, s, t, u, _colors[i], i);
    }
  }

  /// An essence at rest: a loose swarm of its grains over a little light.
  void _swarm(
    Canvas canvas,
    Offset c,
    double s,
    double t,
    Color color,
    double alpha,
    int salt,
  ) {
    GrainGlass.pool(canvas, c, s * 0.12, color, alpha: 0.8 * alpha);
    final d = (s * 0.026).clamp(1.1, 2.6);
    for (var j = 0; j < _grains; j++) {
      final a = GrainGlass.h(j, 40 + salt) * math.pi * 2 + t * 0.9;
      final rr = s * 0.065 * math.sqrt(GrainGlass.h(j, 41 + salt));
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr * 0.85);
      final lift = GrainGlass.h(j, 42 + salt);
      _p.color = Color.lerp(color, Colors.white, 0.15 + 0.5 * lift)!
          .withValues(alpha: (0.55 + 0.45 * lift) * alpha);
      canvas.drawCircle(p, d * (0.4 + 0.25 * lift), _p);
    }
  }

  /// The essence on its way in: its grains, one after another, along a
  /// curve into the core, each with a short trail.
  void _stream(
    Canvas canvas,
    Offset from,
    Offset core,
    double coreR,
    double s,
    double t,
    double u,
    Color color,
    int salt,
  ) {
    final d = (s * 0.022).clamp(0.9, 2.4);
    // Bowed to one side, so it reads as a current and not a spoke.
    final mid = Offset.lerp(from, core, 0.5)!;
    final dir = core - from;
    final ctrl = mid + Offset(-dir.dy, dir.dx) * 0.35;
    Offset at(double q) {
      final a = Offset.lerp(from, ctrl, q)!;
      final b = Offset.lerp(ctrl, core, q)!;
      return Offset.lerp(a, b, q)!;
    }

    for (var j = 0; j < _grains; j++) {
      final delay = j / _grains * 0.22;
      final q = GrainGlass.smooth((u - delay) / 0.34);
      if (q <= 0 || q >= 1) continue;
      final fade = math.min(1.0, (1 - q) * 4);
      for (var k = 0; k < 3; k++) {
        final qq = (q - k * 0.04).clamp(0.0, 1.0);
        final jitter = (GrainGlass.h(j, 50 + salt) - 0.5) * s * 0.04 * (1 - qq);
        final p = at(qq) + Offset(jitter, jitter * 0.6);
        _p.color = Color.lerp(color, Colors.white, 0.35 - k * 0.1)!
            .withValues(alpha: (0.85 - k * 0.28) * fade);
        canvas.drawCircle(p, d * (0.5 - k * 0.1), _p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FactionEssencePainter old) =>
      old.clock != clock;
}
