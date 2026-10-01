part of 'alchemy_effect_paint.dart';

/// VOLCANIC AURA — the creature as a vent.
///
/// Embers lift off its shoulders, white-hot to red as they climb, with ash
/// drifting up slower among them; a molten glow pools at its feet and lights
/// its back; and over its shoulders a few faint grains waver in columns, the
/// air shimmering with the heat. No disc.
abstract final class _Volcanic {
  static const int _embers = 30;
  static const int _ash = 10;

  static final List<double> _ep = [
    for (var i = 0; i < _embers; i++) 1.4 + 1.0 * _h(i, 61),
  ];
  static final List<double> _eph = [
    for (var i = 0; i < _embers; i++) _h(i, 62),
  ];
  static final List<double> _ex = [
    for (var i = 0; i < _embers; i++)
      (i.isEven ? -1.0 : 1.0) * (0.24 + 0.42 * _h(i, 63)),
  ];
  static final List<double> _ey = [
    for (var i = 0; i < _embers; i++) -0.42 + 0.6 * _h(i, 64),
  ];
  static final List<double> _rise = [
    for (var i = 0; i < _embers; i++) 0.8 + 0.6 * _h(i, 65),
  ];

  /// White-hot, orange, red, ember-dark: an ember cooling as it rises.
  static const List<int> _hotDark = [0xFFE8A8, 0xFFA23A, 0xE8501A, 0x8A1E0A];
  static const List<int> _hotLight = [0xE88A1A, 0xC8400F, 0x8A1E0A, 0x4A1008];

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
    final flicker =
        0.85 + 0.15 * math.sin(t * 7.3) * math.sin(t * 3.1 + 1.3);

    // ── the molten glow at its feet, and on its back ──
    final molten = dark ? const Color(0xFFFF5A12) : const Color(0xFFD2400C);
    _pool(
      c,
      cx,
      cy + r * 0.3,
      r * 0.85,
      r * 0.62,
      molten,
      (dark ? 0.2 : 0.14) * flicker * o,
    );
    _pool(
      c,
      cx,
      cy + r * 0.66,
      r * 0.9,
      r * 0.22,
      molten,
      0.46 * flicker * o,
    );
    _pool(
      c,
      cx - r * 0.04,
      cy + r * 0.665,
      r * 0.42,
      r * 0.09,
      dark ? const Color(0xFFFFC46B) : const Color(0xFFE07A10),
      0.42 * flicker * o,
    );

    // ── ash: dark flecks rising slower, laid over rather than added ──
    final b = _batch..clear();
    for (var i = 0; i < _ash; i++) {
      final p = 3.2 + 1.6 * _h(i, 66);
      final u = _frac(t / p + _h(i, 67));
      if (u > 0.92) continue;
      final side = i.isEven ? 1.0 : -1.0;
      final x = side * (0.3 + 0.4 * _h(i, 68)) +
          0.08 * math.sin(t * 0.9 + i * 2.1) * u;
      final y = -0.3 - 0.95 * u;
      b.add(0, cx + x * r, cy + y * r);
    }
    b.draw(
      c,
      0,
      (r * 0.065).clamp(1.8, 3.8),
      _fade(
        dark ? const Color(0xFF6E5A52) : const Color(0xFF4A3A34),
        0.75 * o,
      ),
    );

    _Atlas.clear();
    // ── embers ──
    final emberSize = math.max(4.5, r * 0.2);
    for (var i = 0; i < _embers; i++) {
      final u = _frac(t / _ep[i] + _eph[i]);
      final x =
          _ex[i] * (1 - 0.25 * u) + math.sin(u * 6 + i * 1.3) * 0.06 * u;
      final y = _ey[i] - _rise[i] * u;
      final env = _smooth(0.0, 0.06, u) * (1 - _smooth(0.75, 1.0, u));
      _Atlas.add(
        cx + x * r,
        cy + y * r,
        emberSize * (1.15 - 0.5 * u),
        _heat(u * 1.1, dark),
        env * o,
      );
    }

    // ── the heat shimmer: faint grains wavering in columns ──
    const cols = [-0.36, 0.08, 0.42];
    final shimmer = dark ? 0xFFB070 : 0xC86A2A;
    for (var k = 0; k < cols.length; k++) {
      for (var j = 0; j < 7; j++) {
        final u = _frac(t * 0.35 + j / 7 + k * 0.31);
        final y = -0.5 - 0.75 * u;
        final x = cols[k] + 0.05 * math.sin(y * 14 - t * 5 + k * 2);
        _Atlas.add(
          cx + x * r,
          cy + y * r,
          math.max(3.2, r * 0.11),
          shimmer,
          0.34 * math.sin(math.pi * u) * o,
        );
      }
    }
    _Atlas.draw(c, additive: dark);
  }
}
