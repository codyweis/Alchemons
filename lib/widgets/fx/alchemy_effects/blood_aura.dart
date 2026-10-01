part of 'alchemy_effect_paint.dart';

/// BLOOD AURA — Blood's essence: a deep red pool at the creature's feet that
/// beats lub-dub, a ripple running out across it on each beat, droplets
/// gathering on its body and falling in, and a dark warmth behind it that
/// swells with the pulse. Dark, never a red coin.
abstract final class _BloodAura {
  static const double _period = 1.05;

  /// Lub-dub: 0 at rest, 1 on the beat.
  static double _beat(double t) {
    final m = t % _period;
    double pulse(double x) => math.exp(-(x * x) / 0.003);
    return (pulse(m - 0.04) + 0.65 * pulse(m - 0.23)).clamp(0.0, 1.0);
  }

  static void paint(
    Canvas c,
    Offset at,
    double r,
    double t,
    double o,
    bool dark,
  ) {
    final cx = at.dx, cy = at.dy;
    final fy = cy + r * 0.65;
    final beat = _beat(t);
    final deep = dark ? const Color(0xFFA00C1C) : const Color(0xFF6A0610);
    final bright = dark ? const Color(0xFFE8283A) : const Color(0xFFA8101C);

    // A dark warmth behind it, swelling with the pulse.
    _pool(
      c,
      cx + r * 0.05,
      cy - r * 0.02,
      r * 0.95,
      r * 0.9,
      deep,
      (0.1 + 0.18 * beat) * o,
    );
    // The pool, beating.
    final w = r * 0.95 * (1 + 0.05 * beat);
    _pool(c, cx, fy, w, r * 0.21, deep, (0.48 + 0.16 * beat) * o);
    _pool(
      c,
      cx - r * 0.03,
      fy,
      w * 0.48,
      r * 0.09,
      bright,
      (0.3 + 0.32 * beat) * o,
    );
    // A ripple out across it on each beat: the lub, then the dub.
    final m = t % _period;
    for (final (start, strength) in const [(0.04, 1.0), (0.23, 0.7)]) {
      final age = m - start;
      if (age <= 0 || age > 0.62) continue;
      final k = age / 0.62;
      _ripple(
        c,
        cx,
        fy,
        w * (0.35 + 0.75 * k),
        r * 0.2 * (0.35 + 0.75 * k),
        bright,
        0.6 * strength * (1 - k) * o,
      );
    }

    _Atlas.clear();
    final drop = dark ? 0xD81E30 : 0x8A0A14;
    final shine = dark ? 0xFF8080 : 0xC0141F;
    final g = math.max(4.0, r * 0.15);
    // Droplets gathering on its flanks and falling in.
    for (var i = 0; i < 5; i++) {
      final p = 2.4 + 1.0 * _h(i, 91);
      final s = _frac(t / p + _h(i, 92));
      final side = i.isEven ? -1.0 : 1.0;
      final x = side * (0.3 + 0.26 * _h(i, 93));
      final y0 = 0.05 + 0.25 * _h(i, 94);
      if (s < 0.38) {
        final grow = s / 0.38;
        final y = y0 + 0.04 * grow;
        _Atlas.add(cx + x * r, cy + y * r, g * (0.5 + 0.6 * grow), drop, o);
        _Atlas.add(
          cx + (x - 0.015) * r,
          cy + (y - 0.02) * r,
          g * 0.35 * grow,
          shine,
          0.8 * o,
        );
      } else if (s < 0.62) {
        final u = (s - 0.38) / 0.24;
        final y = y0 + 0.04 + (0.65 - y0 - 0.04) * u * u;
        _Atlas.add(cx + x * r, cy + y * r, g * 1.1, drop, o);
        _Atlas.add(cx + x * r, cy + (y - 0.05) * r, g * 0.7, drop, 0.6 * o);
        _Atlas.add(cx + x * r, cy + (y - 0.1) * r, g * 0.45, drop, 0.35 * o);
      } else if (s < 0.74) {
        // It lands: two flecks thrown up and out of the pool.
        final u = (s - 0.62) / 0.12;
        final hop = 0.07 * math.sin(math.pi * u);
        for (final dir in const [-1.0, 1.0]) {
          _Atlas.add(
            cx + (x + dir * 0.06 * u) * r,
            fy - hop * r,
            g * 0.55,
            shine,
            (1 - u) * o,
          );
        }
      }
    }
    // A few dark motes lifting off the pool, swelling on the beat.
    for (var i = 0; i < 10; i++) {
      final p = 3.2 + 1.6 * _h(i, 95);
      final u = _frac(t / p + _h(i, 96));
      final x = (-0.6 + 1.2 * _h(i, 97)) + 0.05 * math.sin(t + i * 2.3);
      final y = 0.62 - 0.7 * u;
      _Atlas.add(
        cx + x * r,
        cy + y * r,
        g * (0.75 + 0.3 * beat),
        beat > 0.4 ? shine : drop,
        0.8 * math.sin(math.pi * u) * o,
      );
    }
    // Laid over, not added: blood is a liquid, not a light.
    _Atlas.draw(c, additive: false);
  }
}
