// lib/widgets/fx/soul_wisp.dart
//
// A POTENTIAL SOUL, as a soul: a wisp of light burning upward out of a
// white-hot heart — grains rising off the core, widest just above it and
// drawn up into a swaying point, with an ember now and then breaking free
// above. Nothing drawn in lines: grains, and two gradients for its light.
//
// It is a flame where a power orb is a sphere, so the two never read as the
// same kind of thing. [tint] is its colour: the soul's canonical violet, or
// the stat it has been set to.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;

abstract final class SoulWispPaint {
  static const int _n = 300;
  static double _h(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  static final List<double> _phase = [for (var i = 0; i < _n; i++) _h(i, 1)];
  static final List<double> _side = [
    for (var i = 0; i < _n; i++) _h(i, 2) * 2 - 1,
  ];
  static final List<double> _speed = [
    for (var i = 0; i < _n; i++) 0.32 + 0.22 * _h(i, 3),
  ];

  // Buckets: by height, hot to cool (5), embers, glints.
  static const int _emberB = 5, _glintB = 6;
  static final GrainBatch _b = GrainBatch(7);
  static final ui.Paint _p = ui.Paint();

  static ui.Color _lerp(ui.Color a, ui.Color b, double t) =>
      ui.Color.lerp(a, b, t)!;

  /// Paints a soul whose heart sits at [c], [s] tall (its box), at time [t].
  /// [charge] 0..1 makes it burn taller and brighter (a soul about to be
  /// spent). [fade] scales every alpha.
  static void paint(
    ui.Canvas canvas,
    ui.Offset c,
    double s,
    ui.Color tint,
    double t, {
    double charge = 0,
    double fade = 1,
  }) {
    if (s <= 0 || fade <= 0) return;
    final f = fade.clamp(0.0, 1.0);
    final height = s * (0.62 + 0.18 * charge);
    final width = s * 0.15;
    // The heart sits low in the box, so the flame has room above it.
    final heart = ui.Offset(c.dx, c.dy + s * 0.2);
    final b = _b..clear();

    // ── its light ──
    final glowC = ui.Offset(c.dx, c.dy + s * 0.02);
    final glowR = s * (0.5 + 0.08 * charge);
    _p.shader = ui.Gradient.radial(
      glowC,
      glowR,
      [
        tint.withValues(alpha: (0.3 + 0.15 * charge) * f),
        tint.withValues(alpha: 0.1 * f),
        tint.withValues(alpha: 0),
      ],
      const [0.0, 0.5, 1.0],
    );
    canvas.drawCircle(glowC, glowR, _p);

    // ── its body: three tongues of light, wide and faint outside, narrow
    // and bright within, each swaying on its own — soft, a flame, not a
    // drop ──
    for (var k = 0; k < 3; k++) {
      final w = width * (1.15 - 0.3 * k);
      final h = height * (1.05 - 0.12 * k);
      final flick = t * (2.1 + 0.6 * k) + k * 1.3;
      final tip = ui.Offset(
        heart.dx + math.sin(flick + 3.4) * width * (0.6 - 0.15 * k),
        heart.dy - h,
      );
      final lean = math.sin(flick + 1.6) * width * 0.4;
      final mid = heart.dy - h * 0.38;
      final body = ui.Path()
        ..moveTo(heart.dx, heart.dy + s * 0.04)
        ..cubicTo(
          heart.dx - w * 1.2,
          heart.dy - s * 0.01,
          heart.dx - w * 0.75 + lean,
          mid,
          tip.dx,
          tip.dy,
        )
        ..cubicTo(
          heart.dx + w * 0.75 + lean,
          mid,
          heart.dx + w * 1.2,
          heart.dy - s * 0.01,
          heart.dx,
          heart.dy + s * 0.04,
        )
        ..close();
      final inner = _lerp(tint, const ui.Color(0xFFFFFFFF), 0.25 + 0.25 * k);
      _p.shader = ui.Gradient.linear(
        ui.Offset(heart.dx, heart.dy + s * 0.04),
        tip,
        [
          inner.withValues(alpha: (0.22 + 0.16 * k) * f),
          tint.withValues(alpha: (0.14 + 0.08 * k + 0.08 * charge) * f),
          tint.withValues(alpha: 0),
        ],
        const [0.0, 0.42, 0.92],
      );
      canvas.drawPath(body, _p);
    }

    // ── sparks rising through it ──
    for (var i = 0; i < _n; i++) {
      final p = (t * _speed[i] * (1 + 0.6 * charge) + _phase[i]) % 1.0;
      // Widest just above the heart, drawn up into a point.
      final profile =
          math.pow(math.sin(math.pi * (0.08 + 0.92 * p)), 0.7).toDouble() *
          math.pow(1 - p, 0.55).toDouble();
      // The tip sways; the base holds.
      final sway =
          math.sin(t * 2.1 + p * 3.4) * width * 0.45 * p +
          math.sin(t * 3.3 + _phase[i] * 6) * width * 0.08;
      final x = heart.dx + _side[i] * width * profile + sway;
      final y = heart.dy - p * height;
      if (p > 0.9) {
        b.add(_emberB, x, y - (p - 0.9) * height * 0.8);
        continue;
      }
      if ((t * 0.4 + _phase[i] * 9.1) % 1.0 < 0.012) {
        b.add(_glintB, x, y);
        continue;
      }
      b.add(math.min(4, (p * 5).floor()), x, y);
    }
    // Its heart, white-hot.
    final coreR = s * (0.13 + 0.03 * charge);
    _p.shader = ui.Gradient.radial(
      heart,
      coreR,
      [
        const ui.Color(0xFFFFFFFF).withValues(alpha: f),
        _lerp(
          tint,
          const ui.Color(0xFFFFFFFF),
          0.55,
        ).withValues(alpha: 0.75 * f),
        tint.withValues(alpha: 0),
      ],
      const [0.0, 0.4, 1.0],
    );
    canvas.drawCircle(heart, coreR, _p);
    _p.shader = null;

    final d = math.max(0.9, s * 0.017);
    // Hot at the base, its colour through the body, deep at the tip.
    final ramp = [
      _lerp(tint, const ui.Color(0xFFFFFFFF), 0.75),
      _lerp(tint, const ui.Color(0xFFFFFFFF), 0.45),
      _lerp(tint, const ui.Color(0xFFFFFFFF), 0.18),
      tint,
      _lerp(tint, const ui.Color(0xFF07060B), 0.3),
    ];
    for (var k = 0; k < 5; k++) {
      b.draw(
        canvas,
        k,
        d * (1.15 - 0.08 * k),
        ramp[k].withValues(alpha: (1 - 0.14 * k) * f),
      );
    }
    b.draw(canvas, _emberB, d * 0.85, ramp[2].withValues(alpha: 0.6 * f));
    b.draw(
      canvas,
      _glintB,
      d * 2.2,
      const ui.Color(0x40FFFFFF).withValues(alpha: 0.25 * f),
    );
    b.draw(
      canvas,
      _glintB,
      d * 1.2,
      const ui.Color(0xFFFFFFFF).withValues(alpha: f),
    );
  }
}
