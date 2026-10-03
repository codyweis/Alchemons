part of 'alchemy_effect_paint.dart';

/// WILL-O'-WISPS — four soft lights wandering lazily about the creature,
/// as marsh lights do: each a pale heart in a wide soft glow, trailing a
/// short wisp of itself, drifting on slow unrepeating paths that carry it
/// round in front of the creature and back behind it, flickering now and
/// then. Each lights the ground beneath it as it passes.
abstract final class _Wisps {
  static const int _n = 4;

  // Per wisp: where it keeps to, how far and how slowly it wanders, and its
  // tint (cyan, sea green, pale violet, cyan).
  static const List<(double, double)> _home = [
    (-0.55, -0.25),
    (0.6, 0.05),
    (0.1, -0.85),
    (-0.2, 0.35),
  ];
  static const List<int> _tintDark = [0xA8F0FF, 0x9CFFD8, 0xD2C2FF, 0xB8F4FF];
  static const List<int> _tintLight = [0x1A8A9A, 0x1A8A6A, 0x6A4AB8, 0x1A7A9A];
  static final List<double> _ph = [
    for (var i = 0; i < _n * 6; i++) _h(i, 141) * math.pi * 2,
  ];
  static final List<double> _fq = [
    for (var i = 0; i < _n * 6; i++) 0.17 + 0.22 * _h(i, 142),
  ];

  /// Where wisp [i] is at [t]: x, y in radii, and z — in front of the
  /// creature when positive.
  static (double, double, double) _at(int i, double t) {
    final (hx, hy) = _home[i];
    final k = i * 6;
    final x =
        hx +
        0.42 * math.sin(t * _fq[k] + _ph[k]) +
        0.16 * math.sin(t * _fq[k + 1] * 2.3 + _ph[k + 1]);
    final y =
        hy +
        0.22 * math.sin(t * _fq[k + 2] + _ph[k + 2]) +
        0.08 * math.sin(t * _fq[k + 3] * 2.7 + _ph[k + 3]);
    final z = math.sin(t * _fq[k + 4] * 0.8 + _ph[k + 4]);
    return (x, y, z);
  }

  static void paint(
    Canvas c,
    Offset at,
    double r,
    double t,
    double o,
    bool dark,
    bool front,
  ) {
    final cx = at.dx, cy = at.dy;
    final tints = dark ? _tintDark : _tintLight;

    if (!front) {
      // The ground each one lights as it goes over, brighter the lower it
      // floats.
      for (var i = 0; i < _n; i++) {
        final (x, y, _) = _at(i, t);
        final near = (1 - (0.62 - y) / 1.6).clamp(0.0, 1.0);
        _pool(
          c,
          cx + x * r,
          cy + r * 0.66,
          r * (0.36 + 0.16 * near),
          r * 0.09,
          Color(0xFF000000 | tints[i]),
          (dark ? 0.26 : 0.18) * near * o,
        );
      }
    }

    _Atlas.clear();
    final glow = math.max(10.0, r * 0.62);
    for (var i = 0; i < _n; i++) {
      final (x, y, z) = _at(i, t);
      // Each wisp is drawn in one layer: in front, or behind and a little
      // dimmer and smaller for the distance.
      if ((z > 0) != front) continue;
      final depth = 1 + 0.18 * z;
      final flicker =
          (0.82 +
              0.12 * math.sin(t * 5.3 + i * 1.9) +
              0.06 * math.sin(t * 11.7 + i)) *
          (_frac(t * 0.13 + i * 0.29) < 0.04 ? 0.45 : 1.0);
      final tint = tints[i];
      // Its wisp: where it was a moment ago, thinning.
      for (var k = 5; k >= 1; k--) {
        final (tx, ty, _) = _at(i, t - k * 0.11);
        _Atlas.add(
          cx + tx * r,
          cy + ty * r,
          glow * 0.32 * (1 - k * 0.12) * depth,
          tint,
          0.4 * (1 - k / 6) * flicker * o,
        );
      }
      final px = cx + x * r, py = cy + y * r;
      _Atlas.add(px, py, glow * depth, tint, 0.34 * flicker * o);
      _Atlas.add(px, py, glow * 0.48 * depth, tint, 0.8 * flicker * o);
      _Atlas.add(
        px,
        py,
        glow * 0.19 * depth,
        dark ? 0xFFFFFF : _mix(tint, 0x000000, 0.25),
        flicker * o,
      );
    }
    _Atlas.draw(c, additive: dark);
  }
}
