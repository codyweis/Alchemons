part of 'alchemy_effect_paint.dart';

/// VOID RIFT — a small black hole opening behind the creature, low, as if
/// the ground under it were giving way: the grain-rift recipe (see
/// rift_vortex.dart) at aura scale.
///
/// A tipped disk of violet grains spirals in, turning faster as it falls and
/// heating from ink to white at the core's edge, where a thin bright lip
/// hugs the black. Behind and below the centre, never a halo round the head.
abstract final class _VoidRift {
  static const int _n = 170;
  static const int _lip = 46;

  static final List<double> _speed = [
    for (var i = 0; i < _n; i++) 0.16 + 0.12 * _h(i, 71),
  ];
  static final List<double> _ph = [for (var i = 0; i < _n; i++) _h(i, 72)];

  /// Three arms, each grain a little off its arm's line.
  static final List<double> _th0 = [
    for (var i = 0; i < _n; i++)
      (i % 3) * math.pi * 2 / 3 + (_h(i, 73) - 0.5) * 0.7,
  ];
  static final List<double> _start = [
    for (var i = 0; i < _n; i++) 1.0 + 0.3 * math.pow(_h(i, 74), 3),
  ];
  static final List<double> _lipTh = [
    for (var i = 0; i < _lip; i++) _h(i, 75) * math.pi * 2,
  ];
  static final List<double> _lipRho = [
    for (var i = 0; i < _lip; i++) 0.24 + 0.06 * _h(i, 76),
  ];

  /// Ink at the cold rim to white-hot at the core.
  static const List<int> _tonesDark = [0x2A1450, 0x6A3AD0, 0xB89AFF, 0xF2EAFF];
  static const List<int> _tonesLight = [0x1A0A33, 0x3B1C80, 0x6A3AD0, 0x8F6CE8];

  static int _tone(double k, bool dark) {
    final ramp = dark ? _tonesDark : _tonesLight;
    final x = k.clamp(0.0, 0.999) * (ramp.length - 1);
    final i = x.floor();
    return _mix(ramp[i], ramp[i + 1], x - i);
  }

  static void paint(
    Canvas c,
    Offset at,
    double r,
    double t,
    double o,
    bool dark,
  ) {
    final hx = at.dx + r * 0.03, hy = at.dy + r * 0.42;
    final rx = r * 1.3, ry = r * 0.48;

    // The dark it opens in, and the violet light round it.
    _pool(
      c,
      hx,
      hy,
      rx * 1.15,
      ry * 1.3,
      const Color(0xFF120822),
      (dark ? 0.6 : 0.3) * o,
    );
    _pool(
      c,
      hx,
      hy,
      rx * 0.95,
      ry * 1.05,
      dark ? const Color(0xFF7A4DFF) : const Color(0xFF5A2FC0),
      (dark ? 0.32 : 0.18) * o,
    );

    // ── the disk, falling in ──
    _Atlas.clear();
    final g = math.max(3.4, r * 0.13);
    for (var i = 0; i < _n; i++) {
      final u = _frac(t * _speed[i] + _ph[i]);
      final rho = _start[i] - (_start[i] - 0.22) * math.pow(u, 0.8);
      final th = _th0[i] + 2.4 * math.log(1 / rho) + t * 0.55;
      final sn = math.sin(th);
      final x = math.cos(th) * rho * rx;
      final y = sn * rho * ry;
      final heat = ((1 - rho) / 0.78).clamp(0.0, 1.0);
      final env = _smooth(0.0, 0.1, u) * (1 - _smooth(0.92, 1.0, u));
      // The near side a little bigger and brighter: a disk, not a smear.
      final near = 0.8 + 0.2 * sn;
      _Atlas.add(
        hx + x,
        hy + y,
        g * (0.7 + 0.5 * rho) * near,
        _tone(heat, dark),
        (0.6 + 0.4 * heat) * env * near * o,
      );
    }
    _Atlas.draw(c, additive: dark);

    // ── the core: black, and the lip of light hugging it ──
    _pool(c, hx, hy, rx * 0.27, ry * 0.32, const Color(0xFF050507), 0.96 * o);
    _Atlas.clear();
    for (var i = 0; i < _lip; i++) {
      final rho = _lipRho[i];
      final th = _lipTh[i] + t * 2.4 / rho;
      _Atlas.add(
        hx + math.cos(th) * rho * rx,
        hy + math.sin(th) * rho * ry,
        g * 0.8,
        dark ? 0xE8DCFF : 0x7A4FE0,
        (0.55 + 0.4 * math.sin(th)) * o,
      );
    }
    _Atlas.draw(c, additive: dark);
  }
}
