part of 'alchemy_effect_paint.dart';

/// STRENGTH FORGE — the strength orb's heartbeat at aura scale: a slow,
/// heavy throb of warm light at the creature's core and under its feet, and
/// on every beat a burst of forge sparks flung up from the ground in arcs,
/// as off an anvil, cooling as they fall. Embers drift between beats. No
/// hexagons.
abstract final class _Strength {
  static const double _period = 1.9;
  static const int _sparks = 14;

  static const List<int> _hotDark = [0xFFF0C0, 0xFFB050, 0xFF6A2A, 0xA02A10];
  static const List<int> _hotLight = [0xE89A30, 0xD0601A, 0xA8380E, 0x6A1A08];

  static int _heat(double k, bool dark) {
    final ramp = dark ? _hotDark : _hotLight;
    final x = k.clamp(0.0, 0.999) * (ramp.length - 1);
    final i = x.floor();
    return _mix(ramp[i], ramp[i + 1], x - i);
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
    final m = t % _period;
    final thump = math.exp(-m * 5);
    final warm = dark ? const Color(0xFFFF8A4C) : const Color(0xFFC0501A);
    final white = dark ? const Color(0xFFFFC07A) : const Color(0xFFD87A20);

    // The throb: at its core, and under its feet.
    _pool(
      c,
      cx,
      cy + r * 0.02,
      r * 0.86 * (1 + 0.05 * thump),
      r * 0.8 * (1 + 0.05 * thump),
      warm,
      (0.1 + 0.26 * thump) * o,
    );
    final w = r * 0.86 * (1 + 0.07 * thump);
    _pool(c, cx, cy + r * 0.66, w, r * 0.21, warm, (0.32 + 0.26 * thump) * o);
    _pool(
      c,
      cx,
      cy + r * 0.665,
      w * 0.45,
      r * 0.09,
      white,
      (0.24 + 0.36 * thump) * o,
    );

    _Atlas.clear();
    final g = math.max(4.2, r * 0.16);
    // ── sparks flung up on the beat, falling in arcs ──
    final beat = (t / _period).floor();
    for (var k = 0; k < _sparks; k++) {
      final seed = beat * _sparks + k;
      final life = 0.85 + 0.45 * _h(seed, 121);
      if (m > life) continue;
      final side = _h(seed, 122) < 0.5 ? -1.0 : 1.0;
      final x0 = side * (0.12 + 0.42 * _h(seed, 123));
      final vx = side * (0.35 + 0.8 * _h(seed, 124));
      final vy = -(1.3 + 0.8 * _h(seed, 125));
      const grav = 2.6;
      // The head, and two behind it: a streak, not a dot.
      for (var s = 0; s < 3; s++) {
        final tau = m - s * 0.025;
        if (tau < 0) break;
        final x = x0 + vx * tau;
        final y = 0.62 + vy * tau + 0.5 * grav * tau * tau;
        final heat = tau / life;
        _Atlas.add(
          cx + x * r,
          cy + y * r,
          g * (1.1 - 0.5 * heat) * (s == 0 ? 1 : 0.7),
          _heat(heat, dark),
          (1 - heat) * (s == 0 ? 1 : 0.5) * o,
        );
      }
    }
    // ── embers drifting up between beats ──
    for (var i = 0; i < 12; i++) {
      final p = 2.4 + 1.2 * _h(i, 126);
      final u = _frac(t / p + _h(i, 127));
      final side = i.isEven ? -1.0 : 1.0;
      final x = side * (0.32 + 0.36 * _h(i, 128)) +
          0.05 * math.sin(t * 1.1 + i * 1.7);
      final y = 0.3 - 1.1 * u;
      _Atlas.add(
        cx + x * r,
        cy + y * r,
        g,
        _heat(0.3 + 0.6 * u, dark),
        0.85 * math.sin(math.pi * u) * o,
      );
    }
    _Atlas.draw(c, additive: dark);
  }
}
