part of 'alchemy_effect_paint.dart';

/// PRISMATIC CASCADE — the dearest effect, and it should look it.
///
/// White light broken into every color round the creature:
///   * an iridescent glow behind it, three hues drifting through each other
///   * two tipped rings of rainbow grains crossing round it like an
///     armillary, turning opposite ways, each passing behind and then in
///     front, its colors running round as it turns, a grain now and then
///     flaring white
///   * the spectrum pooled at its feet
///
/// The hues cycle through the whole wheel. No blur: gradient pools and one
/// atlas call per layer for both rings' grains.
abstract final class _Prismatic {
  /// Seconds for the colors to go once round the wheel.
  static const double _cycle = 12;

  /// Pool colors by hue, quantised so a cycling hue reuses a color.
  static const int _hueSteps = 48;

  /// A pool color by hue.
  static Color _poolColor(double hue, bool dark) {
    final q = ((hue - hue.floorToDouble()) * _hueSteps).floor() % _hueSteps;
    return Color(0xFF000000 | _hueRgb(q / _hueSteps, dark));
  }

  /// Bright and airy over the dark plate; deeper and richer over parchment,
  /// where pastel washes out.
  static int _hueRgb(double hue, bool dark) =>
      dark ? _hsv(hue, 0.62, 1.0) : _hsv(hue, 0.85, 0.82);

  // ── the rings ──
  /// The first ring, leaning a little, never square to the screen.
  static final _PrismaticRing _first = _PrismaticRing(
    count: 190,
    salt: 31,
    reach: 1.0,
    spread: 0.26,
    tilt: -0.2,
    squash: 0.3,
    spin: 0.55,
    hueShift: 0,
  );

  /// The second, tipped steeply the other way so the two cross, turning
  /// back against the first, half the wheel round from it.
  static final _PrismaticRing _second = _PrismaticRing(
    count: 150,
    salt: 41,
    reach: 0.94,
    spread: 0.18,
    tilt: 0.5,
    squash: 0.34,
    spin: -0.7,
    hueShift: 0.5,
  );

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
    final hue0 = t / _cycle;

    if (!front) {
      // ── the glow: three hues drifting through each other ──
      for (var k = 0; k < 3; k++) {
        final a = t * 0.35 + k * math.pi * 2 / 3;
        _pool(
          c,
          cx + math.cos(a) * r * 0.2,
          cy - r * 0.06 + math.sin(a) * r * 0.15,
          r * 1.25,
          r * 1.15,
          _poolColor(hue0 + k / 3, dark),
          (dark ? 0.3 : 0.22) * o,
        );
      }

      // ── the spectrum at its feet ──
      _pool(
        c,
        cx,
        cy + r * 0.67,
        r * 0.86,
        r * 0.2,
        _poolColor(hue0 + 0.5, dark),
        (dark ? 0.3 : 0.24) * o,
      );
    }

    // ── the rings: one atlas call for this layer ──
    _Atlas.clear();
    final ringY = cy + r * 0.06;
    _first.add(cx, ringY, r, t, o, hue0, dark, front);
    _second.add(cx, ringY, r, t, o, hue0, dark, front);
    _Atlas.draw(c, additive: dark);
  }
}

/// One tipped ring of rainbow grains round the creature.
final class _PrismaticRing {
  _PrismaticRing({
    required this.count,
    required int salt,
    required double reach,
    required double spread,
    required double tilt,
    required this.squash,
    required this.spin,
    required this.hueShift,
  }) : _rho = [
         for (var i = 0; i < count; i++)
           reach + spread * math.pow(_h(i, salt), 1.6).toDouble(),
       ],
       _th0 = [for (var i = 0; i < count; i++) _h(i, salt + 1) * math.pi * 2],
       _lift = [for (var i = 0; i < count; i++) (_h(i, salt + 2) - 0.5) * 0.07],
       _gSize = [for (var i = 0; i < count; i++) 0.1 + 0.06 * _h(i, salt + 3)],
       _tw = [for (var i = 0; i < count; i++) _h(i, salt + 4)],
       _ct = math.cos(tilt),
       _st = math.sin(tilt);

  final int count;

  /// How flat the ring looks: its depth over its width.
  final double squash;

  /// Radians a second at radius 1; the outer grains lag behind.
  final double spin;

  /// Where on the wheel its colors start.
  final double hueShift;

  final List<double> _rho, _th0, _lift, _gSize, _tw;
  final double _ct, _st;

  /// Never smaller than this, in pixels, or a HUD slot loses them.
  static const double _minGrain = 3.4;

  /// Queues this ring's grains for the [front] or back layer.
  void add(
    double cx,
    double ringY,
    double r,
    double t,
    double o,
    double hue0,
    bool dark,
    bool front,
  ) {
    final n = (count * (r / 44).clamp(0.55, 1.0)).round();
    for (var i = 0; i < n; i++) {
      final rho = _rho[i];
      final th = _th0[i] + t * spin / rho;
      final sn = math.sin(th);
      // The near side is in front of the creature.
      if ((sn > 0) != front) continue;
      final x = math.cos(th) * rho * r;
      final y = sn * rho * r * squash + _lift[i] * r;
      final px = cx + x * _ct - y * _st;
      final py = ringY + x * _st + y * _ct;
      final near = 0.55 + 0.45 * (sn * 0.5 + 0.5);
      var size = math.max(_minGrain, _gSize[i] * r) * (0.75 + 0.25 * near);
      final hue = th / (math.pi * 2) + hue0 + hueShift;
      var rgb = _Prismatic._hueRgb(hue, dark);
      var alpha = (dark ? 0.85 : 0.9) * near * o;
      // Now and then a grain flares white.
      if (_frac(t * 0.45 + _tw[i] * 9) < 0.035) {
        rgb = dark ? 0xFFFFFF : _Prismatic._hueRgb(hue, true);
        size *= 1.7;
        alpha = o;
      }
      _Atlas.add(px, py, size, rgb, alpha);
    }
  }
}
