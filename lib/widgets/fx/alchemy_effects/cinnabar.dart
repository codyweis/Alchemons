part of 'alchemy_effect_paint.dart';

/// CINNABAR (the Athanor, the Red Work) — vermilion smoke curls up from the
/// ground round the creature: soft puffs born at its feet, swelling and
/// cooling from vermilion to a deep red as they climb a slow curling path,
/// each lit warm on the side toward the light; grains of cinnabar rise with
/// it, glinting now and then, and go out. Red light lies on the ground
/// where it comes from.
///
/// Smoke reads as soft gradient puffs, not lines: every puff and grain is
/// an atlas sprite, all in one pass per layer.
abstract final class _Cinnabar {
  static const int _columns = 5, _puffs = 11;

  /// Vermilion where it leaves the ground, a deep red as it cools; its lit
  /// side warm gold.
  static const int _hot = 0xEC4C24, _cool = 0xA82C1A, _lit = 0xFFA868;

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
      _pool(c, cx, fy, r * 1.05, r * 0.22, const Color(0xFFE0482A), 0.36 * o);
      _pool(
        c,
        cx,
        at.dy - r * 0.1,
        r * 0.95,
        r * 0.85,
        const Color(0xFFB0301E),
        0.1 * o,
      );
    }
    _Atlas.clear();
    // The smoke: a few columns round the feet, each a stream of puffs of
    // every size along a path that sways more the higher it goes, and
    // swings over time, so it curls rather than standing as a pillar.
    for (var k = 0; k < _columns; k++) {
      final z = _h(k, 81) * 2 - 1;
      if ((z > 0.5) != front) continue;
      final side = k.isEven ? -1.0 : 1.0;
      final fx = cx + side * r * (0.32 + 0.5 * _h(k, 84));
      final footY = fy + z * r * 0.08;
      final height = r * (0.85 + 0.45 * _h(k, 85));
      final period = 5.5 + 2.5 * _h(k, 82);
      final ph = k * 2.3 + _h(k, 87) * 6;
      // The column waxes and wanes, so the smoke comes and goes.
      final wax = 0.7 + 0.3 * math.sin(t * 0.21 + ph);
      for (var j = 0; j < _puffs; j++) {
        final seed = k * _puffs + j;
        final u = _frac(t / period + j / _puffs + _h(k, 83));
        // Breaths: the stream thins between them.
        final breath =
            0.6 + 0.4 * math.max(0.0, math.sin(u * 7 - t * 0.9 + ph));
        final env =
            _smooth(0.0, 0.14, u) * (1 - _smooth(0.4, 1.0, u)) * wax * breath;
        if (env <= 0.01) continue;
        final x =
            fx +
            side * r * 0.2 * u * u +
            r * 0.28 * math.sin(t * 0.5 + ph + u * 3.6) * u +
            r * 0.08 * (_h(seed, 88) - 0.5) * u;
        final y = footY - height * u;
        final size = r * (0.12 + 0.42 * u) * (0.75 + 0.5 * _h(seed, 89));
        _Atlas.add(
          x,
          y,
          size,
          _mix(_hot, _cool, u),
          0.3 * env * o,
          cell: _Atlas.puff,
        );
        // The side toward the light, warm.
        _Atlas.add(
          x - size * 0.2,
          y - size * 0.18,
          size * 0.5,
          _lit,
          0.12 * env * (1 - 0.6 * u) * o,
          cell: _Atlas.puff,
        );
      }
    }
    // Grains of cinnabar rising with it.
    for (var i = 0; i < 16; i++) {
      final a = _h(i, 91) * math.pi * 2;
      final near = math.sin(a) > 0.3;
      if (near != front) continue;
      final period = 3.8 + 2.6 * _h(i, 92);
      final u = _frac(t / period + _h(i, 93));
      final env = _smooth(0.0, 0.12, u) * (1 - _smooth(0.55, 1.0, u));
      if (env <= 0.01) continue;
      final gx = cx + math.cos(a) * r * (0.45 + 0.45 * _h(i, 94));
      final gy = fy + math.sin(a) * r * 0.12;
      final rise = r * (0.6 + 0.5 * _h(i, 95));
      final flare = math.max(0.0, math.sin(t * 2.1 + i * 1.3) - 0.8) / 0.2;
      final rgb = _mix(0xF0582E, 0xFFD8A8, flare);
      for (var tr = 3; tr >= 0; tr--) {
        final uu = (u - tr * 0.025).clamp(0.0, 1.0);
        _Atlas.add(
          gx + math.sin(t * 0.7 + i) * r * 0.06 * uu,
          gy - rise * uu,
          math.max(4.0, r * 0.12) * (1 - tr * 0.18),
          rgb,
          (tr == 0 ? 0.85 + 0.15 * flare : 0.3 - tr * 0.06) * env * o,
        );
      }
    }
    _Atlas.draw(c, additive: dark);
  }
}
