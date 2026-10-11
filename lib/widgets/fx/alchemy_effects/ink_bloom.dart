part of 'alchemy_effect_paint.dart';

/// INK BLOOM (the Athanor, the Black Work) — ink rises off the ground at
/// the creature's feet and curls up in slow plumes, as ink does dropped in
/// still water: a thin stem, a billow, a head that rolls over, a finer
/// tendril leaving the stem and curling the other way. The ink is dark at
/// its heart and lit violet round it, toward the key light most, so it
/// reads by its light and never as a dark blob; when a plume is spent it
/// lets go of the ground and thins away upward. A few lilac motes leave the
/// heads.
///
/// Every plume is soft puffs along a curling spine — no edge, no stroke —
/// in three atlas passes: the light round the ink, its dark heart laid
/// over, the motes.
abstract final class _InkBloom {
  static const int _n = 6, _pts = 14, _branchPts = 9;
  static const int _per = _pts + _branchPts;

  /// Every plume's spines, laid out [_per] points to a plume: place, half
  /// width, alpha, and the unit normal toward the lit side.
  static final Float64List _xs = Float64List(_n * _per),
      _ys = Float64List(_n * _per),
      _ws = Float64List(_n * _per),
      _as = Float64List(_n * _per),
      _nx = Float64List(_n * _per),
      _ny = Float64List(_n * _per);

  /// Each plume's strength this frame; 0 for one not drawn in this layer.
  static final Float64List _env = Float64List(_n);

  /// The violet light round the ink, lilac on its lit side, and the ink's
  /// dark heart.
  static const int _glow = 0x5A3AA0, _lit = 0xC9AEFF, _heart = 0x0C0716;

  /// A tendril of [n] points from point [at] of the buffers, walked from
  /// ([x], [y]) heading [dir], [length] long, turning [curl] radians over
  /// its upper part (so its end rolls over), [wide] at its widest.
  static void _tendril(
    int at,
    int n,
    double x,
    double y,
    double dir,
    double length,
    double curl,
    double wide,
    double alpha,
    double detach,
    double t,
    double ph,
  ) {
    final step = length / (n - 1);
    var px = x, py = y;
    for (var k = 0; k < n; k++) {
      final s = k / (n - 1);
      final top = _smooth(0.4, 1.0, s);
      final d =
          dir + curl * top * top + 0.35 * math.sin(t * 0.45 + ph + s * 3.4) * s;
      if (k > 0) {
        final len = step * (1 - 0.35 * top);
        px += math.cos(d) * len;
        py += math.sin(d) * len;
      }
      final i = at + k;
      _xs[i] = px;
      _ys[i] = py;
      // Heading d, the lit side (the key light's, up and left) is to its
      // left.
      _nx[i] = math.sin(d);
      _ny[i] = -math.cos(d);
      // A thin stem, a billow, and an end that thins into the water rather
      // than coming to a point. Never thinner than the puffs' spacing, so
      // the stem is not a string of beads.
      _ws[i] =
          math.max(step * 0.8, wide * (0.22 + 0.95 * _smooth(0.0, 0.45, s))) *
          (1 - 0.4 * _smooth(0.6, 1.0, s));
      _as[i] =
          alpha *
          _smooth(detach - 0.08, detach + 0.14, s) *
          (1 - _smooth(0.42, 1.0, s));
    }
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
    final cx = at.dx, fy = at.dy + r * 0.64;
    if (!front) {
      // Violet light lying where the ink rises, and a little behind it.
      _pool(c, cx, fy, r * 1.05, r * 0.2, const Color(0xFF6A4AB8), 0.3 * o);
      _pool(
        c,
        cx,
        at.dy - r * 0.1,
        r * 0.95,
        r * 0.85,
        const Color(0xFF4A2C80),
        0.12 * o,
      );
    }
    var any = false;
    for (var i = 0; i < _n; i++) {
      _env[i] = 0;
      // Most stand behind it; one rises in front, at its feet.
      final z = _h(i, 71) * 2 - 1;
      if ((z > 0.55) != front) continue;
      final period = 7 + 3.5 * _h(i, 72);
      final u = _frac(t / period + _h(i, 73));
      // Rising (to 0.55), then spent: it lets go of the ground and thins
      // away upward.
      final grow = _smooth(0.0, 0.55, u);
      final env = _smooth(0.0, 0.1, u) * (1 - _smooth(0.7, 1.0, u));
      if (env <= 0.01) continue;
      final side = i.isEven ? -1.0 : 1.0;
      final detach = 0.8 * _smooth(0.5, 1.0, u);
      final height = r * (0.75 + 0.5 * _h(i, 75)) * (0.3 + 0.7 * grow);
      final wide =
          r * (0.08 + 0.04 * _h(i, 77)) * (0.5 + 0.5 * grow + 0.3 * u);
      // Its head rolls over, away from the body mostly.
      final curl = (_h(i, 76) < 0.75 ? side : -side) * (0.5 + 0.5 * grow);
      final ph = i * 1.7 + _h(i, 78) * 6;
      final lean = -math.pi / 2 + side * 0.12 * grow;
      final base = i * _per;
      _tendril(
        base,
        _pts,
        cx + side * r * (0.3 + 0.55 * _h(i, 74)),
        fy + z * r * 0.08,
        lean,
        height,
        curl * 2.4,
        wide,
        env,
        detach,
        t,
        ph,
      );
      // A finer tendril leaves the stem part-way up and curls the other
      // way, so a plume is never one stroke.
      final k0 = base + (_pts * 0.4).round();
      _tendril(
        base + _pts,
        _branchPts,
        _xs[k0],
        _ys[k0],
        lean - curl * 0.35,
        height * 0.5,
        -curl * 2.6,
        wide * 0.55,
        env * 0.85,
        detach,
        t,
        ph + 2.1,
      );
      _env[i] = env;
      any = true;
    }
    if (!any) return;

    // The light round the ink: a violet glow, lilac on the lit side.
    _Atlas.clear();
    for (var i = 0; i < _n; i++) {
      if (_env[i] <= 0) continue;
      for (var p = i * _per; p < (i + 1) * _per; p++) {
        final a = _as[p];
        if (a <= 0.01) continue;
        final w = _ws[p];
        _Atlas.add(
          _xs[p],
          _ys[p],
          w * 2.8,
          _glow,
          0.38 * a * o,
          cell: _Atlas.puff,
        );
        _Atlas.add(
          _xs[p] + _nx[p] * w * 0.6,
          _ys[p] + _ny[p] * w * 0.6,
          w * 1.3,
          _lit,
          0.26 * a * o,
          cell: _Atlas.puff,
        );
      }
    }
    _Atlas.draw(c, additive: dark);

    // Its dark heart, a little toward the shaded side, laid over: ink.
    _Atlas.clear();
    for (var i = 0; i < _n; i++) {
      if (_env[i] <= 0) continue;
      for (var p = i * _per; p < (i + 1) * _per; p++) {
        final a = _as[p];
        if (a <= 0.01) continue;
        final w = _ws[p];
        _Atlas.add(
          _xs[p] - _nx[p] * w * 0.25,
          _ys[p] - _ny[p] * w * 0.25,
          w * 2.0,
          _heart,
          0.36 * a * o,
          cell: _Atlas.puff,
        );
      }
    }
    _Atlas.draw(c, additive: false);

    // Motes of it leaving the heads, drifting up and going out.
    _Atlas.clear();
    for (var i = 0; i < _n; i++) {
      final env = _env[i];
      if (env <= 0) continue;
      final head = i * _per + _pts - 5;
      for (var m = 0; m < 2; m++) {
        final mu = _frac(t / (2.6 + _h(i * 2 + m, 79)) + _h(i * 2 + m, 80));
        final fade = _smooth(0.0, 0.2, mu) * (1 - _smooth(0.5, 1.0, mu));
        _Atlas.add(
          _xs[head] + r * 0.1 * math.sin(mu * 4 + i + m),
          _ys[head] - r * 0.4 * mu,
          r * 0.09,
          _lit,
          0.6 * fade * env * o,
        );
      }
    }
    _Atlas.draw(c, additive: dark);
  }
}
