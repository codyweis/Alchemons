part of 'alchemy_effect_paint.dart';

/// INTELLIGENCE HALO — the intelligence orb's disk at aura scale: a small
/// tipped disk of fine grains orbiting over the creature's head like a
/// planet's ring, its near side passing in front of the head, round a soft
/// light; and a few motes rising off the head into it. No segmented rings,
/// no hexagram lines.
abstract final class _Intelligence {
  static const int _n = 120;

  static final List<double> _rho = [
    for (var i = 0; i < _n; i++)
      0.7 + 0.3 * math.pow(_h(i, 131), 1.3).toDouble(),
  ];
  static final List<double> _th0 = [
    for (var i = 0; i < _n; i++) _h(i, 132) * math.pi * 2,
  ];
  static final List<double> _tw = [for (var i = 0; i < _n; i++) _h(i, 133)];

  static const double _tilt = -0.16;
  static final double _ct = math.cos(_tilt), _st = math.sin(_tilt);

  static void paint(
    Canvas c,
    Offset at,
    double r,
    double t,
    double o,
    bool dark,
    bool front,
  ) {
    final hx = at.dx + r * 0.02, hy = at.dy - r * 0.84;
    final rx = r * 0.6, ry = r * 0.15;
    final violet = dark ? const Color(0xFFB58CFF) : const Color(0xFF6A3AD0);

    if (!front) {
      // The light the disk turns round.
      _pool(c, hx, hy, r * 0.56, r * 0.32, violet, (dark ? 0.12 : 0.1) * o);
      _pool(c, hx, hy, r * 0.22, r * 0.16, violet, (dark ? 0.3 : 0.24) * o);
    }

    _Atlas.clear();
    final inner = dark ? 0xDCC8FF : 0x6A3AD0;
    final outer = dark ? 0x8FB0FF : 0x3A5AC8;
    final g = math.max(2.4, r * 0.065);
    final n = (_n * (r / 44).clamp(0.55, 1.0)).round();
    for (var i = 0; i < n; i++) {
      final rho = _rho[i];
      final th = _th0[i] + t * 0.9 / rho;
      final sn = math.sin(th);
      if ((sn > 0) != front) continue;
      final x = math.cos(th) * rho * rx;
      final y = sn * rho * ry;
      final near = 0.6 + 0.4 * (sn * 0.5 + 0.5);
      final flare = _frac(t * 0.4 + _tw[i] * 9) < 0.03;
      _Atlas.add(
        hx + x * _ct - y * _st,
        hy + x * _st + y * _ct,
        g * near * (flare ? 1.7 : 1),
        flare
            ? (dark ? 0xFFFFFF : inner)
            : _mix(inner, outer, (rho - 0.7) / 0.3),
        (dark ? 0.85 : 0.9) * near * o,
      );
    }
    if (!front) {
      // Motes rising off the head into the disk.
      for (var i = 0; i < 6; i++) {
        final p = 2.6 + 1.2 * _h(i, 134);
        final u = _frac(t / p + _h(i, 135));
        final x = (-0.26 + 0.52 * _h(i, 136)) * r;
        final y = -0.5 + (-0.84 + 0.5) * u;
        _Atlas.add(
          at.dx + x,
          at.dy + y * r,
          g * 1.1,
          inner,
          0.7 * math.sin(math.pi * u) * o,
        );
      }
    }
    _Atlas.draw(c, additive: dark);
  }
}
