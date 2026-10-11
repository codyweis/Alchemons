import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The Chronal Catalyst, drawn as what it does to time.
///
/// A cultivation's sphere with two currents of grains running round it, face
/// on like a clock: the inner one at ordinary speed, the outer at double,
/// pulling ahead, its trail drawn out across the gap between them — what you
/// are buying is the gap. Not an hourglass: half the shop is about time.
///
/// Small enough (the countdown chip draws it at 13) it is only the core, the
/// lit gap and the two heads.
class ChronalCatalystGlyph extends StatelessWidget {
  const ChronalCatalystGlyph({
    super.key,
    required this.size,
    this.animate = true,
    this.color = const Color(0xFF7BE1E8),
  });

  final double size;
  final bool animate;
  final Color color;

  @override
  Widget build(BuildContext context) => GrainGlyph(
    size: size,
    animate: animate,
    painter: (clock) => _ChronalPainter(clock, color),
  );
}

class _ChronalPainter extends CustomPainter {
  _ChronalPainter(this.clock, this.color) : super(repaint: clock);

  final ValueListenable<double>? clock;
  final Color color;

  /// One turn of the ordinary current; the fast one makes two.
  static const double _period = 7.0;

  /// A still glyph shows the fast current a third of a turn ahead.
  static const double _still = 0.42 * _period;

  static final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = (clock?.value ?? 0) + _still;
    final o = Offset(size.width / 2, size.height / 2);
    final u = (t % _period) / _period;
    final slow = -math.pi / 2 + u * math.pi * 2;
    final gap = u * math.pi * 2;
    final fast = slow + gap;
    // The gap swells as the fast current pulls ahead and thins before it
    // laps, so the lap is not a snap.
    final gapLight =
        GrainGlass.smooth(u / 0.15) * (1 - GrainGlass.smooth((u - 0.7) / 0.28));

    final tiny = s < 30;
    final rSlow = s * (tiny ? 0.3 : 0.33);
    final rFast = s * (tiny ? 0.42 : 0.44);

    if (tiny) {
      _gap(canvas, o, rFast * 1.04, slow, gap, gapLight * 1.4);
      // The core as one lit bead.
      _p.color = const Color(0xFF000000);
      _p.shader = ui.Gradient.radial(
        o,
        s * 0.24,
        [
          Color.lerp(color, Colors.white, 0.6)!,
          color.withValues(alpha: 0.8),
          Color.lerp(color, const Color(0xFF07060B), 0.6)!.withValues(alpha: 0),
        ],
        const [0.0, 0.5, 1.0],
      );
      canvas.drawCircle(o, s * 0.24, _p);
      _p.shader = null;
      for (final (a, rr) in [(slow, rSlow), (fast, rFast)]) {
        _p.color = Color.lerp(color, Colors.white, 0.5)!;
        canvas.drawCircle(
          o + Offset(math.cos(a) * rr, math.sin(a) * rr),
          s * 0.075,
          _p,
        );
      }
      return;
    }

    _current(canvas, o, rSlow, slow, s, tail: 0.9, salt: 1, bright: 0.75);
    // The fast one's trail reaches back across the gap it has opened.
    _current(
      canvas,
      o,
      rFast,
      fast,
      s,
      tail: (gap * 0.92).clamp(0.5, 3.2),
      salt: 2,
      bright: 1,
      grains: (34 + 30 * gapLight).round(),
    );

    GrainGlass.sphere(
      canvas,
      o,
      s * 0.22,
      t,
      a: color,
      b: Color.lerp(color, const Color(0xFF9C8CFF), 0.35),
      spin: 0.7,
      density: 0.8,
      salt: 9,
    );
  }

  /// At the chip's size, the gap as a faint wedge of light: too small for
  /// the trail to read.
  void _gap(
    Canvas canvas,
    Offset o,
    double r,
    double from,
    double sweep,
    double light,
  ) {
    if (light <= 0.01 || sweep <= 0.01) return;
    _p.color = const Color(0xFF000000);
    _p.shader = ui.Gradient.radial(
      o,
      r,
      [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.2 * light),
        color.withValues(alpha: 0.0),
      ],
      const [0.25, 0.7, 1.0],
    );
    canvas.drawArc(
      Rect.fromCircle(center: o, radius: r),
      from,
      sweep,
      true,
      _p,
    );
    _p.shader = null;
    final d = (r * 0.05).clamp(0.8, 2.2);
    for (var i = 0; i < 26; i++) {
      final a = from + sweep * GrainGlass.h(i, 31);
      final rr = r * (0.45 + 0.5 * GrainGlass.h(i, 32));
      _p.color = Color.lerp(
        color,
        Colors.white,
        0.3,
      )!.withValues(alpha: 0.5 * light * (0.4 + 0.6 * GrainGlass.h(i, 33)));
      canvas.drawCircle(
        o + Offset(math.cos(a) * rr, math.sin(a) * rr),
        d * 0.5,
        _p,
      );
    }
  }

  /// A current of grains running round at radius [r], its head at [head]:
  /// dense and bright there, thinning and scattering along its tail.
  void _current(
    Canvas canvas,
    Offset o,
    double r,
    double head,
    double s, {
    required double tail,
    required int salt,
    required double bright,
    int grains = 34,
  }) {
    final d = (s * 0.026).clamp(1.2, 2.6);
    final n = grains;
    for (var i = n - 1; i >= 0; i--) {
      final k = i / (n - 1);
      final a = head - tail * math.pow(k, 1.4);
      final spread = r * 0.12 * k * (GrainGlass.h(i, salt) - 0.5) * 2;
      final rr = r + spread;
      final fade = math.pow(1 - k, 1.6).toDouble() * bright;
      _p.color = Color.lerp(
        color,
        Colors.white,
        0.55 * (1 - k),
      )!.withValues(alpha: (0.95 * fade).clamp(0.0, 1.0));
      canvas.drawCircle(
        o + Offset(math.cos(a) * rr, math.sin(a) * rr),
        d * (0.35 + 0.35 * (1 - k)),
        _p,
      );
    }
    GrainGlass.pool(
      canvas,
      o + Offset(math.cos(head) * r, math.sin(head) * r),
      s * 0.08,
      color,
      alpha: 0.8 * bright,
    );
  }

  @override
  bool shouldRepaint(covariant _ChronalPainter old) =>
      old.clock != clock || old.color != color;
}
