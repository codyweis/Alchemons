part of 'alchemy_effect_paint.dart';

/// QUICKSILVER (the Athanor, the White Work) — a ball of liquid silver
/// hangs at the creature's shoulder, bobbing. It is never quite round:
/// waves run round its skin, and the sky, a hard horizon and the dark
/// ground it gives back slosh inside it. A drip sags out of its underside,
/// draws out into a neck with a bulb on the end and pinches off, and the
/// ball jiggles back round; the drop falls, quick and heavy, and breaks on
/// the ground into beads that skitter and settle. Then each bead goes back
/// up as fine silver grains, rising into the ball again, so the metal
/// keeps coming round. (User 2026-10-22: the old pool at the feet was
/// "kind of static when worn"; "removed the bottom pool part and just did
/// a cool drip ball animation instead"; then "a little more liquidy
/// looking".)
///
/// The ball's skin is laid each frame (48 points, closest at the drip) and
/// filled with unit shaders moved onto it; the beads and grains are atlas
/// sprites.
abstract final class _Quicksilver {
  /// Liquid chrome on the unit disc, as a ball of mirror gives the world
  /// back: the sky dim overhead and brightest just above a hard horizon,
  /// the horizon bowed round the ball (the gradient's middle is far above
  /// it), the dark ground under it, and that ground's light along the
  /// underside.
  static final Shader _chrome = ui.Gradient.radial(
    const Offset(0, -2.6),
    3.6,
    const [
      Color(0xFF4A5362),
      Color(0xFF5E6878),
      Color(0xFFDCE3EC),
      Color(0xFFEEF2F7),
      Color(0xFF151920),
      Color(0xFF20252C),
      Color(0xFF8D99A9),
      Color(0xFFB9C4D2),
    ],
    const [0.0, 0.444, 0.7, 0.728, 0.738, 0.85, 0.96, 1.0],
  );

  /// Its roundness: the mirror darkening toward the edge, where it turns
  /// away.
  static final Shader _depth = ui.Gradient.radial(
    Offset.zero,
    1,
    const [
      Color(0x00101318),
      Color(0x00101318),
      Color(0x30101318),
      Color(0x70101318),
    ],
    const [0.0, 0.55, 0.85, 1.0],
  );

  static final Paint _paint = Paint()..isAntiAlias = true;
  static final Path _unit = Path()
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: 1));

  /// Seconds between drips.
  static const double _period = 3.0;

  /// Where in a drip's [_period] it pinches off.
  static const double _pinch = 0.62;

  /// Seconds a drop takes to fall: heavy, so quick.
  static const double _fall = 0.42;

  /// How far below the ball's middle the bulb hangs as it lets go, and how
  /// big it is then, in the ball's radii.
  static const double _letGo = 1.85, _drop = 0.3;

  static const int _n = 48;
  static final Float64List _ux = Float64List(_n), _uy = Float64List(_n);
  static final Float64List _ex = Float64List(_n), _ey = Float64List(_n);
  static final Path _plain = Path(), _seen = Path();

  /// Where the skin's points sit round it, laid once: each one's angle, and
  /// how far that is from straight down (the drip), crowding toward it.
  static final Float64List _dist = Float64List.fromList([
    for (var i = 0; i < _n; i++)
      math.pi * math.pow((-1 + 2 * i / _n).abs(), 1.6).toDouble(),
  ]);
  static final Float64List _angle = Float64List.fromList([
    for (var i = 0; i < _n; i++)
      math.pi / 2 + (2 * i < _n ? -_dist[i] : _dist[i]),
  ]);

  /// [xs], [ys] joined into a smooth closed outline in [path].
  static Path _close(Path path, Float64List xs, Float64List ys) {
    final n = xs.length;
    path.moveTo((xs[n - 1] + xs[0]) / 2, (ys[n - 1] + ys[0]) / 2);
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      path.quadraticBezierTo(
        xs[i],
        ys[i],
        (xs[i] + xs[j]) / 2,
        (ys[i] + ys[j]) / 2,
      );
    }
    return path..close();
  }

  /// The ball's skin at [t] on the unit disc: waves running round it, the
  /// drip [sag]ging out of its underside [width] round (radians), and a
  /// [shake] that squashes it wide or tall. Laid twice: as it is
  /// ([_plain]), and as its mirror sees it, turned back by [tilt] and
  /// lowered by [lift] ([_seen]), so the reflection can slosh while the
  /// skin stays put. The points crowd toward the drip, so a thin neck is
  /// still smooth.
  static void _skin(
    double t,
    double sag,
    double width,
    double shake,
    double tilt,
    double lift,
  ) {
    final ct = math.cos(tilt), st = math.sin(tilt);
    for (var i = 0; i < _n; i++) {
      final d = _dist[i], a = _angle[i];
      var rr =
          1 +
          0.045 * math.sin(2 * a + t * 1.7) +
          0.03 * math.sin(3 * a - t * 2.3 + 1) +
          0.018 * math.sin(5 * a + t * 3.1 + 2) +
          shake * math.cos(2 * a);
      if (d < width) {
        final q = 1 - (d / width) * (d / width);
        rr += sag * q * q;
      }
      final x = math.cos(a) * rr, y = math.sin(a) * rr;
      _ux[i] = x;
      _uy[i] = y;
      _ex[i] = x * ct + y * st;
      _ey[i] = -x * st + y * ct - lift;
    }
    _close(_plain..reset(), _ux, _uy);
    _close(_seen..reset(), _ex, _ey);
  }

  /// Liquid metal [rad] round at ([x], [y]): [seen] in the chrome, its
  /// reflection turned [tilt] and raised [lift], [plain] darkened toward
  /// its edge, and the sky's highlight riding on it.
  static void _metal(
    Canvas c,
    double x,
    double y,
    double rad,
    Path plain,
    Path seen,
    double tilt,
    double lift,
    double o,
  ) {
    if (rad <= 0.3) return;
    c.save();
    c.translate(x, y);
    c.scale(rad, rad);
    c.save();
    c.rotate(tilt);
    c.translate(0, lift);
    _paint
      ..shader = _chrome
      ..color = Color.fromRGBO(0, 0, 0, o);
    c.drawPath(seen, _paint);
    c.restore();
    _paint.shader = _depth;
    c.drawPath(plain, _paint);
    c.restore();
    // The sky's highlight, high on the lit side, moving as the metal does.
    final hx = -0.36 + 0.12 * tilt, hy = -0.46 - 0.3 * lift;
    _pool(
      c,
      x + rad * hx,
      y + rad * hy,
      rad * 0.4,
      rad * 0.24,
      const Color(0xFFFFFFFF),
      0.55 * o,
    );
    _pool(
      c,
      x + rad * hx,
      y + rad * hy,
      rad * 0.15,
      rad * 0.09,
      const Color(0xFFFFFFFF),
      0.9 * o,
    );
  }

  /// A bead [br] in radius resting on the ground at ([x], [y]).
  static void _bead(double x, double y, double br, double o) {
    if (br <= 0.25) return;
    // The sprite's bead is 0.68 of its cell and sits a little above the
    // cell's middle; it settles a quarter into the ground, as a bead does.
    _Atlas.add(x, y - br * 0.57, br / 0.34, 0xFFFFFF, o, cell: _Atlas.bead);
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
    final fy = at.dy + r * 0.64;
    // The ball, beside the creature at its shoulder, bobbing.
    final bx = at.dx + r * 0.74;
    final by = at.dy - r * 0.36 + r * 0.035 * math.sin(t * 2.1);
    final br = r * 0.14;

    if (!front) {
      // The ground's faint light under the ball.
      _pool(c, bx, fy, r * 0.3, r * 0.06, const Color(0xFFB4C8E0), 0.18 * o);
      return;
    }

    final cyc = t / _period;
    final now = cyc.floor();
    final u = cyc - now;

    // The drip now: the underside sagging (to 0.45), then drawn out into
    // a neck with the bulb coming out below it (to the pinch); after, the
    // neck snapping back up, and the ball jiggling round.
    double sag, width, shake, bulbAt = 0, bulb = 0;
    if (u < 0.45) {
      final g = _smooth(0.0, 0.45, u);
      sag = 0.4 * g;
      width = 0.95 - 0.25 * g;
      shake = 0;
    } else if (u < _pinch) {
      final p = _smooth(0.45, _pinch, u);
      sag = 0.4 + 0.2 * p;
      width = 0.7 - 0.5 * p;
      shake = -0.04 * p;
      bulb = 0.34 - (0.34 - _drop) * p;
      bulbAt = 1.06 + (_letGo - 1.06) * p;
    } else {
      final s = (u - _pinch) * _period;
      sag = 0.6 * math.exp(-9 * s) * math.cos(15 * s);
      width = 0.2 + 0.5 * _smooth(0.0, 0.3, s);
      shake = -0.04 * math.exp(-4 * s) * math.cos(14 * s);
    }
    // The reflection sloshing inside it.
    final tilt = 0.25 * math.sin(t * 1.1);
    final lift = 0.08 * math.sin(t * 1.9);

    _Atlas.clear();
    // The drops already let go — falling, then beads on the ground going
    // back up as grains — from this drip and the two before it.
    for (var k = 0; k < 3; k++) {
      final n = now - k;
      final since = t - (n + _pinch) * _period;
      if (since < 0) continue;
      final seed = n * 7;
      if (since < _fall) {
        // Falling: quickening, with a faint trail above it.
        final y0 = by + br * _letGo;
        for (var j = 2; j >= 0; j--) {
          final g = (since / _fall - j * 0.06).clamp(0.0, 1.0);
          _bead(
            bx,
            y0 + (fy - y0) * g * g,
            br * _drop * (1 - j * 0.25),
            o * (1 - j * 0.35),
          );
        }
        continue;
      }
      // On the ground: it breaks into beads that skitter out and settle,
      // and after a while each goes up as grains into the ball.
      final s = since - _fall;
      if (s < 0.6) {
        _pool(
          c,
          bx,
          fy,
          r * 0.22,
          r * 0.05,
          const Color(0xFFC8D6E8),
          0.4 * (1 - s / 0.6) * o,
        );
      }
      for (var j = 0; j < 4; j++) {
        final dir = (_h(seed + j, 91) - 0.5) * 2;
        final reach = r * (0.08 + 0.22 * _h(seed + j, 92));
        final out = 1 - math.exp(-s * 5);
        final hop = s < 0.25 ? r * 0.05 * 4 * (s / 0.25) * (1 - s / 0.25) : 0.0;
        final x = bx + dir * reach * out;
        final y = fy + (_h(seed + j, 93) - 0.5) * r * 0.08 * out;
        final size = r * (0.018 + 0.02 * _h(seed + j, 94));
        // Going up from 1.4 s, each in its own time, over 1.6 s.
        final up = _smooth(0.0, 1.6, s - 1.4 - 0.4 * _h(seed + j, 95));
        _bead(x, y - hop, size * (1 - up), o);
        if (up <= 0 || up >= 1) continue;
        // Each bead's grains rise on an arc of its own, bowed out to its
        // side by its own amount, so they never stand in a column.
        final bow = r * (0.12 + 0.2 * _h(seed + j, 96)) * (dir < 0 ? -1 : 1);
        for (var q = 0; q < 3; q++) {
          final f = (up * 1.4 - q * 0.2).clamp(0.0, 1.0);
          if (f <= 0 || f >= 1) continue;
          final e = 1 - f;
          _Atlas.add(
            x * e * e +
                (x + bow) * 2 * e * f +
                bx * f * f +
                math.sin(f * 9 + q * 2.3) * r * 0.025,
            y * e * e + (y + by) * e * f + (by + br * 0.6) * f * f,
            r * 0.05,
            0xDCE4EE,
            0.7 * math.sin(math.pi * f) * o,
          );
        }
      }
    }
    _Atlas.draw(c, additive: false);

    // The bulb first, so the neck runs into it, then the ball.
    if (bulb > 0) {
      _metal(c, bx, by + br * bulbAt, br * bulb, _unit, _unit, tilt, 0, o);
    }
    _skin(t, sag, width, shake, tilt, lift);
    _metal(c, bx, by, br, _plain, _seen, tilt, lift, o);
  }
}
