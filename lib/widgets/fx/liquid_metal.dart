// lib/widgets/fx/liquid_metal.dart
//
// Liquid metal — quicksilver — as the Quicksilver aura first drew it, for
// everything that is made of it: the aura's drip ball, and the home's
// Silverlite decor (decor_silverlite_art.dart).
//
// A body of it is a skin laid each frame round a unit disc (waves running
// round it, a drip sagging out of its underside, a shake that squashes it
// wide or tall), filled with liquid chrome: the world given back as a ball
// of mirror gives it — dim sky overhead, brightest just above a hard
// horizon bowed round the ball, the dark ground, that ground's light along
// the underside — darkened toward the edge where it turns away, with the
// sky's highlight riding on it. The reflection can slosh inside it (turned
// and raised) while the skin stays put. No outline strokes, no blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

abstract final class LiquidMetal {
  /// Liquid chrome on the unit disc, as a ball of mirror gives the world
  /// back: the sky dim overhead and brightest just above a hard horizon,
  /// the horizon bowed round the ball (the gradient's middle is far above
  /// it), the dark ground under it, and that ground's light along the
  /// underside.
  static final ui.Shader _chrome = ui.Gradient.radial(
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
  static final ui.Shader _depth = ui.Gradient.radial(
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

  /// The sky's highlight: soft from its middle out, no edge.
  static final ui.Shader _shine = ui.Gradient.radial(
    Offset.zero,
    1,
    const [
      Color(0xFFFFFFFF),
      Color(0x73FFFFFF),
      Color(0x1FFFFFFF),
      Color(0x00FFFFFF),
    ],
    const [0.0, 0.38, 0.72, 1.0],
  );

  static final Paint _paint = Paint()..isAntiAlias = true;

  /// A round body of it, on the unit disc.
  static final Path unit = Path()
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: 1));

  static const int _n = 48;
  static final Float64List _ux = Float64List(_n), _uy = Float64List(_n);
  static final Float64List _ex = Float64List(_n), _ey = Float64List(_n);

  /// The skin [skin] laid last: as it is, and as its mirror sees it.
  static final Path plain = Path(), seen = Path();

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

  /// Lays a body's skin at [t] on the unit disc into [plain] and [seen]:
  /// waves running round it ([waves] of their size), the drip [sag]ging out
  /// of its underside [width] round (radians), and a [shake] that squashes
  /// it wide (positive) or tall. [seen] is the same skin as its mirror sees
  /// it, turned back by [tilt] and lowered by [lift], so the reflection can
  /// slosh while the skin stays put. The points crowd toward the drip, so a
  /// thin neck is still smooth.
  static void skin(
    double t, {
    double sag = 0,
    double width = 0.7,
    double shake = 0,
    double tilt = 0,
    double lift = 0,
    double waves = 1,
  }) {
    final ct = math.cos(tilt), st = math.sin(tilt);
    for (var i = 0; i < _n; i++) {
      final d = _dist[i], a = _angle[i];
      var rr =
          1 +
          waves *
              (0.045 * math.sin(2 * a + t * 1.7) +
                  0.03 * math.sin(3 * a - t * 2.3 + 1) +
                  0.018 * math.sin(5 * a + t * 3.1 + 2)) +
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
    _close(plain..reset(), _ux, _uy);
    _close(seen..reset(), _ex, _ey);
  }

  /// A body of it [rad] round at [at]: [seen] in the chrome, its reflection
  /// turned [tilt] and raised [lift], [plain] darkened toward its edge and
  /// by [dim] all over (the night), and the sky's highlight riding on it.
  /// A part that runs between bodies (a neck, a column) leaves out its
  /// [round]ness and its [shine], so it flows on from them.
  static void paint(
    Canvas c,
    Offset at,
    double rad,
    Path plain,
    Path seen, {
    double tilt = 0,
    double lift = 0,
    double opacity = 1,
    double dim = 0,
    bool round = true,
    bool shine = true,
  }) {
    if (rad <= 0.3 || opacity <= 0) return;
    final o = opacity.clamp(0.0, 1.0);
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(rad, rad);
    c.save();
    c.rotate(tilt);
    c.translate(0, lift);
    _paint
      ..shader = _chrome
      ..color = Color.fromRGBO(0, 0, 0, o);
    c.drawPath(seen, _paint);
    c.restore();
    if (round) {
      _paint.shader = _depth;
      c.drawPath(plain, _paint);
    }
    if (dim > 0.004) {
      _paint
        ..shader = null
        ..color = Color.fromRGBO(6, 8, 14, (dim * o).clamp(0.0, 1.0));
      c.drawPath(plain, _paint);
    }
    c.restore();
    if (!shine) return;
    // The sky's highlight, high on the lit side, moving as the metal does.
    final h =
        at + Offset(rad * (-0.36 + 0.12 * tilt), rad * (-0.46 - 0.3 * lift));
    _highlight(c, h, rad * 0.4, rad * 0.24, 0.55 * o);
    _highlight(c, h, rad * 0.15, rad * 0.09, 0.9 * o);
  }

  /// Fills whatever is clipped with the metal's light about the unit disc
  /// of the canvas as it stands: its chrome (the reflection turned [tilt]
  /// and raised [lift]), its roundness, and [dim]. For a body whose outline
  /// is laid by its maker and whose halves are lit about different middles
  /// (two drops running into one).
  static void shade(
    Canvas c, {
    double tilt = 0,
    double lift = 0,
    double opacity = 1,
    double dim = 0,
  }) {
    if (opacity <= 0) return;
    final o = opacity.clamp(0.0, 1.0);
    const all = Rect.fromLTRB(-8, -8, 8, 8);
    c.save();
    c.rotate(tilt);
    c.translate(0, lift);
    _paint
      ..shader = _chrome
      ..color = Color.fromRGBO(0, 0, 0, o);
    c.drawRect(all, _paint);
    c.restore();
    _paint.shader = _depth;
    c.drawRect(all, _paint);
    if (dim > 0.004) {
      _paint
        ..shader = null
        ..color = Color.fromRGBO(6, 8, 14, (dim * o).clamp(0.0, 1.0));
      c.drawRect(all, _paint);
    }
  }

  /// The sky's highlight on a body [rad] round at [at], placed as [paint]
  /// places it.
  static void shine(
    Canvas c,
    Offset at,
    double rad, {
    double tilt = 0,
    double lift = 0,
    double opacity = 1,
  }) {
    final o = opacity.clamp(0.0, 1.0);
    final h =
        at + Offset(rad * (-0.36 + 0.12 * tilt), rad * (-0.46 - 0.3 * lift));
    _highlight(c, h, rad * 0.4, rad * 0.24, 0.55 * o);
    _highlight(c, h, rad * 0.15, rad * 0.09, 0.9 * o);
  }

  /// A round drop of it, [rad] round at [at] — a bulb, a bead.
  static void sphere(
    Canvas c,
    Offset at,
    double rad, {
    double tilt = 0,
    double opacity = 1,
    double dim = 0,
  }) => paint(c, at, rad, unit, unit, tilt: tilt, opacity: opacity, dim: dim);

  static void _highlight(
    Canvas c,
    Offset at,
    double rx,
    double ry,
    double alpha,
  ) {
    if (alpha <= 0.004 || rx <= 0 || ry <= 0) return;
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(rx, ry);
    _paint
      ..shader = _shine
      ..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
    c.drawCircle(Offset.zero, 1, _paint);
    c.restore();
  }
}
