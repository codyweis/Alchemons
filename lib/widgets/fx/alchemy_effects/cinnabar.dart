part of 'alchemy_effect_paint.dart';

/// CINNABAR (the Athanor, the Red Work) — luminous vermilion smoke rising
/// round the creature from a few places at its feet, as incense smoke
/// rises: a thin laminar thread at the base that widens, twists and folds
/// as it climbs and breaks into curls higher up, a branch peeling off and
/// curling away, the whole column leaning and swaying on the air's own
/// slow currents. It is lit warm gold along the edge that faces the light
/// and cools from vermilion to a deep red as it thins toward the top.
/// Grains of cinnabar ride up with it and glint now and then; red light
/// lies on the ground where it comes from.
///
/// Each wisp lies along a streamline of a divergence-free curl flow
/// ([_Flow], [_Spine]); its smoke rides along it by age, so the wisp is
/// continuous and every part of it a smooth function of the clock. The
/// smoke is soft overlapping puffs, three across, so no one of them reads:
/// one pass for its body, one for its lit edge, one for the grains.
abstract final class _Cinnabar {
  static const int _columns = 5, _along = 36, _branch = 14, _crystals = 10;

  static final _Flow _flow = _Flow(const [
    (0.8, 0.7, 0.3, 0.9, 0.95),
    (-0.6, 1.1, -0.24, 2.6, 0.8),
    (1.9, -1.2, 0.42, 1.7, 0.3),
    (-1.1, 2.4, -0.38, 4.0, 0.22),
  ], scale: 0.42);

  static final _Spine _spine = _Spine(), _twig = _Spine();

  /// Vermilion where it leaves the ground, a deep red as it cools; warm
  /// gold on its lit edge.
  static const int _hot = 0xFF4A1E, _cool = 0xA02216, _lit = 0xFFB060;

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
    if (!front) {
      _pool(c, cx, cy + r * 0.64, r * 1.05, r * 0.22,
          const Color(0xFFE0482A), 0.36 * o);
      _pool(c, cx, cy - r * 0.1, r * 0.95, r * 0.85,
          const Color(0xFFB0301E), 0.12 * o);
    }
    _flow.prepare(t);
    // In front of the creature it is fainter, so it never washes it out.
    final layer = front ? 0.35 : 1.0;
    _nb = 0;
    _nl = 0;
    for (var k = 0; k < _columns; k++) {
      final z = _h(k, 81) * 2 - 1;
      if ((z > 0.5) != front) continue;
      final side = k.isEven ? -1.0 : 1.0;
      final sx = side * (0.3 + 0.5 * _h(k, 84));
      final sy = 0.6 + z * 0.08;
      final life = 3.4 + 0.8 * _h(k, 82);
      final ph = k * 2.3 + _h(k, 87) * 6;
      _spine.trace(_flow, sx, sy, life, 14,
          speed: 0.17, lift: 0.3, drift: side * 0.025, calm: 0.5);
      // A branch peels off part-way up and curls away.
      final s0 = 0.4 + 0.15 * _h(k, 88);
      _spine.at(s0);
      _twig.trace(_flow, _spine.x, _spine.y, life * 0.45, 8,
          speed: 0.24, lift: 0.22, drift: side * 0.1);
      _twig.roll(0.3, side * 1.4);
      _wisp(_spine, _along, life, 0, 1, t, ph, side, r, cx, cy, layer,
          0.3 * life);
      _wisp(_twig, _branch, life * 0.45, s0, 0.55, t, ph + 1.7, side, r, cx,
          cy, layer, 0.22 * life * 0.45);
    }

    _Atlas.clear();
    for (var b = 0; b < _nb; b++) {
      _Atlas.add(_bx[b], _by[b], _bs[b], _bc[b], _ba[b] * o, cell: _Atlas.puff);
    }
    _Atlas.draw(c, additive: dark);
    _Atlas.clear();
    for (var b = 0; b < _nl; b++) {
      _Atlas.add(_lx[b], _ly[b], _ls[b], _lc[b], _la[b] * o, cell: _Atlas.puff);
    }
    _Atlas.draw(c, additive: dark);

    // Grains of cinnabar rising with the smoke, glinting as they turn.
    _Atlas.clear();
    final px = _Flow._px, py = _Flow._py;
    for (var i = 0; i < _crystals; i++) {
      final a = _h(i, 91) * math.pi * 2;
      if ((math.sin(a) > 0.3) != front) continue;
      final life = 3.6 + 2 * _h(i, 92);
      final u = _frac(t / life + _h(i, 93));
      final env = _smooth(0.0, 0.1, u) * (1 - _smooth(0.55, 1.0, u));
      if (env <= 0.02) continue;
      _flow.trace(
        math.cos(a) * (0.45 + 0.4 * _h(i, 94)),
        0.62 + math.sin(a) * 0.12,
        u * life,
        6,
        speed: 0.2,
        lift: 0.36,
      );
      final x = cx + px[6] * r, y = cy + py[6] * r;
      final g = math.sin(t * (1.6 + 0.9 * _h(i, 95)) + i * 2.1);
      final glint = _smooth(0.72, 1.0, g);
      _Atlas.add(x, y, math.max(3.0, r * 0.075),
          _mix(0xD8361E, 0xFFB070, glint), (0.7 + 0.3 * glint) * env * o);
      if (glint > 0.02) {
        _Atlas.add(x, y, math.max(1.6, r * 0.032), 0xFFF2DC, glint * env * o);
      }
    }
    _Atlas.draw(c, additive: dark);
  }

  /// The smoke along [spine]: [n] samples riding up it by age over [life]
  /// seconds, its share of the column [share], starting at fraction [s0]
  /// of the column's height (a branch starts part-way up).
  static void _wisp(
    _Spine spine,
    int n,
    double life,
    double s0,
    double share,
    double t,
    double ph,
    double side,
    double r,
    double cx,
    double cy,
    double layer,
    double rise,
  ) {
    final length = spine.length;
    final ds = length / n;
    // Where the currents fold it short, the same smoke lies closer: as thin
    // as ever, not brighter.
    final spread = (length / rise).clamp(0.3, 1.0);
    for (var j = 0; j < n; j++) {
      final u = _frac(t / life + j / n + ph * 0.1);
      // Where it is up the whole column, for its width and its cooling.
      final s = s0 + (1 - s0) * u;
      final env =
          _smooth(0.0, 0.08, u) *
          (1 - _smooth(0.5, 1.0, u)) *
          share *
          layer *
          spread;
      if (env <= 0.01) continue;
      // The source breathes, and what it gave off when this rose rides up.
      final emit = 0.7 + 0.3 * math.sin((t - u * life) * 0.5 + ph);
      spine.at(u);
      // Breaking into curls higher up: the wisp ripples across itself, more
      // the higher it is, and twists so its edges cross and fold.
      final calm = _smooth(0.25, 0.85, s);
      final w = 0.02 + 0.2 * math.pow(s, 1.1);
      final ripple = w * 1.3 * calm * math.sin(11 * s - 1.6 * t + ph);
      final mx = spine.x + spine.nx * ripple, my = spine.y + spine.ny * ripple;
      final twist = math.cos(ph + 5.5 * s - 0.8 * t);
      final size = r * math.max(2.6 * ds, 2.3 * w);
      final heat = _mix(_hot, _cool, s * 0.9);
      final a = 0.11 * env * emit;
      for (var e = -1; e <= 1; e++) {
        final off = e * w * 0.55 * twist;
        final b = _nb++;
        _bx[b] = cx + (mx + spine.nx * off) * r;
        _by[b] = cy + (my + spine.ny * off) * r;
        _bs[b] = size * (e == 0 ? 1.0 : 0.82);
        _bc[b] = heat;
        _ba[b] = a * (e == 0 ? 1.0 : 0.75);
      }
      // Its lit edge: whichever edge faces the light (up and left), warm,
      // brightest where the twist turns it full on.
      final lit = twist >= 0 ? 1.0 : -1.0;
      final face = (spine.nx * lit * -0.8 + spine.ny * lit * -0.6);
      if (face > 0.05) {
        final off = lit * w * 0.6 * twist.abs();
        final l = _nl++;
        _lx[l] = cx + (mx + spine.nx * off) * r;
        _ly[l] = cy + (my + spine.ny * off) * r;
        // Never smaller than its spacing up the wisp, so its edge is one
        // line of light, not a string of points.
        _ls[l] = math.max(size * 0.48, r * ds * 2.8);
        _lc[l] = _mix(heat, _lit, 0.75 * (1 - 0.5 * s));
        _la[l] = 0.3 * env * emit * face * (0.4 + 0.6 * twist.abs());
      }
    }
  }

  static const int _maxPuffs = _columns * (_along + _branch) * 3;
  static int _nb = 0, _nl = 0;
  static final Float64List _bx = Float64List(_maxPuffs),
      _by = Float64List(_maxPuffs),
      _bs = Float64List(_maxPuffs),
      _ba = Float64List(_maxPuffs),
      _lx = Float64List(_maxPuffs ~/ 3),
      _ly = Float64List(_maxPuffs ~/ 3),
      _ls = Float64List(_maxPuffs ~/ 3),
      _la = Float64List(_maxPuffs ~/ 3);
  static final Int32List _bc = Int32List(_maxPuffs),
      _lc = Int32List(_maxPuffs ~/ 3);
}
