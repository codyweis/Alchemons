part of 'alchemy_effect_paint.dart';

/// INK BLOOM (the Athanor, the Black Work) — ink rising off the ground at
/// the creature's feet as ink rises in still water: a thick dark-violet
/// plume that climbs straight at first, then leans and sways on the
/// water's slow currents and rolls over at its head like a sheet folding,
/// a finer tongue of it peeling off and curling the other way. Its heart is
/// dark and thick; its edges catch the light, lilac on the side facing it;
/// where it thins it takes on a little of the creature's own element. When
/// its source falters the plume lets go of the ground and thins upward
/// into wisps.
///
/// Each plume lies along a streamline of a divergence-free curl flow
/// ([_Flow], [_Spine]); its ink rides along it by age, so the plume is
/// continuous and every part of it a smooth function of the clock. Three
/// layers of soft overlapping puffs, none of which reads on its own: the
/// ink's violet body, its dark heart laid over, its lit edges.
abstract final class _InkBloom {
  static const int _plumes = 5, _along = 34, _branch = 14;

  static final _Flow _flow = _Flow(const [
    (0.9, 0.55, 0.26, 0.4, 0.9),
    (-0.55, 1.05, -0.2, 2.1, 0.85),
    (2.0, -0.95, 0.36, 1.3, 0.3),
    (0.75, 2.2, -0.32, 4.4, 0.26),
  ], scale: 0.42);

  static final _Spine _spine = _Spine(), _tongue = _Spine();

  /// The ink's body (a deep violet that its element tints), its dark heart,
  /// and the lilac light its edges catch.
  static const int _body = 0x4A2C8C, _heart = 0x0B0614, _lit = 0xD2BCFF;

  static final Map<String?, (int, int)> _tints = {};

  /// The body and the lit edge, a little of [element] in each.
  static (int, int) _tint(String? element) =>
      _tints[element] ??= element == null
      ? (_body, _lit)
      : () {
          final ramp = essenceRamp(_ElementalAura.resolve(element));
          return (
            _mix(_body, _rgb(ramp[2]), 0.3),
            _mix(_lit, _rgb(ramp[3]), 0.28),
          );
        }();

  static void paint(
    Canvas c,
    Offset at,
    double r,
    double t,
    double o,
    bool dark,
    bool front,
    String? element,
  ) {
    final cx = at.dx, cy = at.dy;
    final (body, lit) = _tint(element);
    if (!front) {
      // Light lying where the ink rises, and a little behind it.
      _pool(c, cx, cy + r * 0.64, r * 1.05, r * 0.2,
          Color(0xFF000000 | _mix(0x6A4AB8, body, 0.4)), 0.3 * o);
      _pool(c, cx, cy - r * 0.1, r * 0.95, r * 0.85,
          Color(0xFF000000 | body), 0.14 * o);
    }
    _flow.prepare(t);
    // In front of the creature it is gentler, so it never buries it.
    final layer = front ? 0.45 : 1.0;
    _nb = 0;
    _nl = 0;
    for (var p = 0; p < _plumes; p++) {
      final z = _h(p, 71) * 2 - 1;
      if ((z > 0.55) != front) continue;
      final side = p.isEven ? -1.0 : 1.0;
      final sx = side * (0.3 + 0.55 * _h(p, 74));
      final sy = 0.62 + z * 0.08;
      final life = 4.8 + 1.2 * _h(p, 72);
      final ph = p * 1.7 + _h(p, 78) * 6;
      // Its head rolls over, away from the body mostly.
      final curl = _h(p, 76) < 0.75 ? side : -side;
      _spine.trace(_flow, sx, sy, life, 16,
          speed: 0.16, lift: 0.2, drift: side * 0.02, calm: 0.3);
      _spine.roll(0.5, curl * (1.0 + 0.3 * math.sin(t * 0.3 + ph)));
      final s0 = 0.38 + 0.12 * _h(p, 79);
      _spine.at(s0);
      _tongue.trace(_flow, _spine.x, _spine.y, life * 0.42, 8,
          speed: 0.18, lift: 0.14, drift: -curl * 0.07);
      _tongue.roll(0.25, -curl * 1.3);
      _plume(_spine, _along, life, 0, 1, t, ph, r, cx, cy, layer, body, lit,
          0.2 * life);
      _plume(_tongue, _branch, life * 0.42, s0, 0.6, t, ph + 2.1, r, cx, cy,
          layer, body, lit, 0.14 * life * 0.42);
    }
    if (_nb == 0) return;

    // The ink's body: soft and wide, so it is one substance.
    _Atlas.clear();
    for (var b = 0; b < _nb; b++) {
      _Atlas.add(_bx[b], _by[b], _bs[b], _bc[b], _ba[b] * o, cell: _Atlas.puff);
    }
    _Atlas.draw(c, additive: dark);
    // Its heart, dark and thick, laid over along the middle: what is left
    // bright is its edge.
    _Atlas.clear();
    for (var b = 1; b < _nb; b += 3) {
      _Atlas.add(_bx[b], _by[b], _bs[b] * 0.62, _heart, _ha[b ~/ 3] * o,
          cell: _Atlas.puff);
    }
    _Atlas.draw(c, additive: false);
    // Its edges, catching the light.
    _Atlas.clear();
    for (var l = 0; l < _nl; l++) {
      _Atlas.add(_lx[l], _ly[l], _ls[l], lit, _la[l] * o, cell: _Atlas.puff);
    }
    _Atlas.draw(c, additive: dark);
  }

  /// The ink along [spine]: [n] samples riding up it by age over [life]
  /// seconds, its share [share], starting at fraction [s0] of the plume's
  /// height (a tongue starts part-way up).
  static void _plume(
    _Spine spine,
    int n,
    double life,
    double s0,
    double share,
    double t,
    double ph,
    double r,
    double cx,
    double cy,
    double layer,
    int body,
    int lit,
    double rise,
  ) {
    final length = spine.length;
    final ds = length / n;
    // Where the currents fold it short, the same ink lies closer: as thin
    // as ever, not brighter.
    final spread = (length / rise).clamp(0.3, 1.0);
    for (var j = 0; j < n; j++) {
      final u = _frac(t / life + j / n + ph * 0.1);
      final s = s0 + (1 - s0) * u;
      // The source falters now and then, and the gap rides up the plume:
      // it lets go of the ground and thins away.
      final emit = _smooth(-0.35, 0.45, math.sin((t - u * life) * 0.33 + ph));
      final env =
          _smooth(0.0, 0.06, u) *
          (1 - _smooth(0.5, 1.0, u)) *
          share *
          layer *
          emit *
          spread;
      if (env <= 0.01) continue;
      spine.at(u);
      final w = 0.03 + 0.17 * math.pow(s, 0.8);
      // The sheet turns as it climbs, so its edges cross and fold over.
      final twist = math.cos(ph + 4 * s - 0.6 * t);
      final size = r * math.max(2.7 * ds, 2.3 * w);
      final thin = _smooth(0.4, 1.0, s);
      final tone = _mix(body, _mix(body, lit, 0.35), thin);
      for (var e = -1; e <= 1; e++) {
        final off = e * w * 0.5 * twist;
        final b = _nb++;
        _bx[b] = cx + (spine.x + spine.nx * off) * r;
        _by[b] = cy + (spine.y + spine.ny * off) * r;
        _bs[b] = size * (e == 0 ? 1.0 : 0.85);
        _bc[b] = tone;
        _ba[b] = 0.17 * env * (e == 0 ? 1.0 : 0.8);
      }
      // Thick in its heart until it thins.
      _ha[(_nb - 3) ~/ 3] =
          0.34 * env * (1 - 0.6 * thin) * (layer < 1 ? 0.15 : 1.0);
      // Its edges: the one facing the light (up and left) lit, the other
      // faintly.
      for (final e in const [-1.0, 1.0]) {
        final off = e * w * 0.62 * twist;
        final nx = spine.nx * e * twist.sign, ny = spine.ny * e * twist.sign;
        final face = (-0.6 * nx - 0.8 * ny).clamp(0.0, 1.0);
        final l = _nl++;
        _lx[l] = cx + (spine.x + spine.nx * off) * r;
        _ly[l] = cy + (spine.y + spine.ny * off) * r;
        _ls[l] = math.max(size * 0.5, r * ds * 2.8);
        _la[l] = env * (0.06 + 0.34 * face) * (0.5 + 0.5 * twist.abs());
      }
    }
  }

  static const int _max = _plumes * (_along + _branch);
  static int _nb = 0, _nl = 0;
  static final Float64List _bx = Float64List(_max * 3),
      _by = Float64List(_max * 3),
      _bs = Float64List(_max * 3),
      _ba = Float64List(_max * 3),
      _ha = Float64List(_max),
      _lx = Float64List(_max * 2),
      _ly = Float64List(_max * 2),
      _ls = Float64List(_max * 2),
      _la = Float64List(_max * 2);
  static final Int32List _bc = Int32List(_max * 3);
}
