part of 'alchemy_effect_paint.dart';

/// GOLD LEAF (the Athanor, the Yellow Work) — flakes of beaten gold
/// drifting down round the creature, tumbling as they fall, so each flashes
/// when it turns to the light and goes dark edge-on; they settle on the
/// ground at its feet, glint there a while and fade. Warm light lies where
/// they land.
///
/// The flakes are ragged quads in one drawVertices per layer, colored per
/// corner by how they face the light; their warmth and flashes are atlas
/// grains. They keep to the flanks: the sprite covers the middle.
abstract final class _GoldLeaf {
  static const int _n = 22;
  static final _Tris _tris = _Tris(_n * 4 + 4);

  /// Old gold, so a leaf turned away is still metal, never a brown chip.
  static const int _shadow = 0x7A4A0E, _face = 0xF2BE4A, _flash = 0xFFF4D2;

  /// Each leaf: a long ragged sheet with a crease across it, so its two
  /// halves catch the light differently (unit size, the crease p1–p4).
  static final List<Float64List> _shapes = [
    for (var i = 0; i < _n; i++)
      Float64List.fromList([
        -1.25, -0.5 + 0.35 * _h(i, 31), //
        -0.1 + 0.3 * _h(i, 32), -0.75 - 0.2 * _h(i, 33),
        1.2, -0.45 + 0.3 * _h(i, 34),
        1.1 - 0.2 * _h(i, 35), 0.55 + 0.2 * _h(i, 36),
        0.1 - 0.3 * _h(i, 37), 0.7 + 0.2 * _h(i, 38),
        -1.2 + 0.2 * _h(i, 39), 0.45 + 0.2 * _h(i, 40),
      ]),
  ];

  /// The six corners of the leaf being drawn, placed.
  static final Float64List _q = Float64List(12);

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
      _pool(c, cx, fy, r * 1.0, r * 0.22, const Color(0xFFE0A84A), 0.34 * o);
      _pool(
        c,
        cx,
        at.dy - r * 0.15,
        r * 0.95,
        r * 0.85,
        const Color(0xFFB8862E),
        0.09 * o,
      );
    }
    _Atlas.clear();
    for (var i = 0; i < _n; i++) {
      final z = _h(i, 6) * 2 - 1;
      if ((z > 0.15) != front) continue;
      final period = 7.5 + 4 * _h(i, 1);
      final u = _frac(t / period + _h(i, 2));
      // Falling for most of its life, then lying on the ground.
      const fallEnd = 0.74;
      final y0 = at.dy - r * (0.55 + 0.45 * _h(i, 3));
      final yGround = fy + z * r * 0.07;
      // Down the flanks and either side, not over the body.
      final side = _h(i, 5) < 0.5 ? -1.0 : 1.0;
      final x0 = cx + side * r * (0.42 + 0.5 * _h(i, 10));
      final size = r * (0.05 + 0.03 * _h(i, 4));
      // Its fall at fraction f of the way down, at time tt: drifting down
      // and side to side, as leaf does, never straight, tumbling as it
      // goes.
      final swayRate = 0.55 + 0.3 * _h(i, 7), flipRate = 1.3 + 1.2 * _h(i, 9);
      double swayAt(double tt) => math.sin(tt * swayRate + i * 2.1);
      double xAt(double f, double tt) =>
          x0 + swayAt(tt) * r * 0.16 * (0.4 + f) + r * 0.06 * math.sin(i + f * 3);
      double x, y, spin, flip, flatten, alpha, settle;
      if (u < fallEnd) {
        final f = u / fallEnd;
        // Easing onto the ground over the last of its fall.
        final down = f < 0.9 ? f : 0.9 + 0.1 * _smooth(0.0, 1.0, (f - 0.9) / 0.1);
        y = y0 + (yGround - y0) * down;
        x = xAt(f, t);
        spin = 0.5 * swayAt(t) + i;
        flip = t * flipRate + i * 1.7;
        flatten = 1;
        alpha = _smooth(0.0, 0.1, f);
        settle = 0;
      } else {
        // Lying where it landed, settling flat face up: everything carries
        // on from the moment it touched down, so nothing jumps.
        final f = (u - fallEnd) / (1 - fallEnd);
        final landed = t - (u - fallEnd) * period;
        y = yGround;
        x = xAt(1, landed);
        spin = 0.5 * swayAt(landed) + i;
        final flipLand = landed * flipRate + i * 1.7;
        final rest = 0.3 + 0.6 * _h(i, 9);
        var turn = (rest - flipLand) % (math.pi * 2);
        if (turn > math.pi) turn -= math.pi * 2;
        settle = _smooth(0.0, 0.16, f);
        flip = flipLand + turn * settle;
        flatten = 1 - 0.68 * settle;
        alpha = 1 - _smooth(0.5, 1.0, f);
      }
      if (alpha <= 0.01) continue;
      // How each half faces the light: the crease turns one a little more.
      final face = math.cos(flip);
      double litAt(double off) =>
          (0.5 + 0.5 * math.cos(flip + off - 0.7)).clamp(0.0, 1.0);
      final litA = litAt(0.35), litB = litAt(-0.35);
      var flash = math.pow(math.max(litA, litB), 14).toDouble();
      if (settle > 0) {
        // Lying still, it glints now and then as the light moves.
        final g = math.sin(t * 0.8 + i * 2.7);
        final glint = _smooth(0.86, 1.0, g);
        flash += (glint - flash) * settle;
      }
      int col(double lit, double edge) {
        final base = _mix(_shadow, _face, 0.4 + 0.6 * lit + edge);
        return _argb(_mix(base, _flash, flash * (0.6 + 0.4 * lit)), alpha * o);
      }

      final cs = math.cos(spin), sn = math.sin(spin);
      final shape = _shapes[i], q = _q;
      for (var k = 0; k < 12; k += 2) {
        final px = shape[k] * size, py = shape[k + 1] * size * face;
        q[k] = x + px * cs - py * sn;
        q[k + 1] = y + (px * sn + py * cs) * flatten;
      }
      // Half A (p5, p0, p1, p4), half B (p1, p2, p3, p4).
      _tris.quad(
        q[10], q[11], q[0], q[1], q[2], q[3], q[8], q[9], //
        col(litA, -0.08), col(litA, 0.05), col(litA, 0.12), col(litA, 0),
      );
      _tris.quad(
        q[2], q[3], q[4], q[5], q[6], q[7], q[8], q[9], //
        col(litB, 0.12), col(litB, 0.02), col(litB, -0.1), col(litB, 0),
      );
      // Its warmth: a faint glow round every leaf, the flash over it.
      _Atlas.add(
        x,
        y,
        size * 5.5,
        0xE8A83A,
        (0.16 + 0.18 * math.max(litA, litB)) * alpha * o,
      );
      if (flash > 0.05) {
        _Atlas.add(x, y, size * 5.5, 0xFFE6B0, 0.55 * flash * alpha * o);
        _Atlas.add(x, y, size * 1.8, 0xFFFFFF, 0.85 * flash * alpha * o);
      }
    }
    _Atlas.draw(c, additive: dark);
    _tris.draw(c);
  }
}
