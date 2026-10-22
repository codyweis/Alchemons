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
/// The ball is liquid metal (liquid_metal.dart), shared with the home's
/// Silverlite decor; the beads and grains are atlas sprites.
abstract final class _Quicksilver {
  /// Seconds between drips.
  static const double _period = 3.0;

  /// Where in a drip's [_period] it pinches off.
  static const double _pinch = 0.62;

  /// Seconds a drop takes to fall: heavy, so quick.
  static const double _fall = 0.42;

  /// How far below the ball's middle the bulb hangs as it lets go, and how
  /// big it is then, in the ball's radii.
  static const double _letGo = 1.85, _drop = 0.3;

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
      LiquidMetal.sphere(
        c,
        Offset(bx, by + br * bulbAt),
        br * bulb,
        tilt: tilt,
        opacity: o,
      );
    }
    LiquidMetal.skin(
      t,
      sag: sag,
      width: width,
      shake: shake,
      tilt: tilt,
      lift: lift,
    );
    LiquidMetal.paint(
      c,
      Offset(bx, by),
      br,
      LiquidMetal.plain,
      LiquidMetal.seen,
      tilt: tilt,
      lift: lift,
      opacity: o,
    );
  }
}
