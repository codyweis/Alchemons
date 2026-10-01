part of 'alchemy_effect_paint.dart';

/// PRISMATIC CASCADE — the dearest effect, and it should look it.
///
/// White light broken into every colour round the creature:
///   * an iridescent glow behind it, three hues drifting through each other
///   * soft shafts of coloured light turning slowly out from behind it
///   * a tipped ring of rainbow grains orbiting it, passing behind and then
///     in front, its colours running round as it turns, a grain now and
///     then flaring white
///   * the spectrum pooled at its feet
///
/// The hues cycle through the whole wheel. No blur: gradient pools, lit
/// blades and one atlas call per layer for the grains.
abstract final class _Prismatic {
  /// Seconds for the colours to go once round the wheel.
  static const double _cycle = 12;

  // ── the rays ──
  static const int _rays = 7;
  static final List<double> _rayJit = [
    for (var j = 0; j < _rays; j++) (_h(j, 21) - 0.5) * 0.5,
  ];
  static final List<double> _rayLen = [
    for (var j = 0; j < _rays; j++) 1.1 + 0.65 * _h(j, 22),
  ];
  static final List<double> _rayW = [
    for (var j = 0; j < _rays; j++) 0.17 + 0.13 * _h(j, 23),
  ];
  static final Path _blade = vfxLens(1, 1, 0.12, 0.8);
  static final Paint _bladePaint = Paint();

  /// Lit blades by hue, quantised so a cycling hue reuses a shader.
  static const int _hueSteps = 48;
  static final List<Shader?> _bladeShaders = List.filled(_hueSteps * 2, null);
  static Shader _bladeShader(double hue, bool dark) {
    final q = ((hue - hue.floorToDouble()) * _hueSteps).floor() % _hueSteps;
    return _bladeShaders[q + (dark ? 0 : _hueSteps)] ??= () {
      final c = Color(0xFF000000 | _hueRgb(q / _hueSteps, dark));
      return ui.Gradient.linear(
        const Offset(0, -0.5),
        const Offset(0, 0.5),
        [
          c.withValues(alpha: 0),
          c.withValues(alpha: 0.22),
          c,
          c.withValues(alpha: 0.22),
          c.withValues(alpha: 0),
        ],
        const [0.0, 0.25, 0.5, 0.75, 1.0],
      );
    }();
  }

  /// A pool colour by hue, quantised the same way.
  static Color _poolColor(double hue, bool dark) {
    final q = ((hue - hue.floorToDouble()) * _hueSteps).floor() % _hueSteps;
    return Color(0xFF000000 | _hueRgb(q / _hueSteps, dark));
  }

  /// Bright and airy over the dark plate; deeper and richer over parchment,
  /// where pastel washes out.
  static int _hueRgb(double hue, bool dark) =>
      dark ? _hsv(hue, 0.62, 1.0) : _hsv(hue, 0.85, 0.82);

  // ── the ring ──
  static const int _ringN = 190;
  static final List<double> _rho = [
    for (var i = 0; i < _ringN; i++)
      1.0 + 0.26 * math.pow(_h(i, 31), 1.6).toDouble(),
  ];
  static final List<double> _th0 = [
    for (var i = 0; i < _ringN; i++) _h(i, 32) * math.pi * 2,
  ];
  static final List<double> _lift = [
    for (var i = 0; i < _ringN; i++) (_h(i, 33) - 0.5) * 0.07,
  ];
  static final List<double> _gSize = [
    for (var i = 0; i < _ringN; i++) 0.1 + 0.06 * _h(i, 34),
  ];
  static final List<double> _tw = [for (var i = 0; i < _ringN; i++) _h(i, 35)];

  /// The ring's tip: leaning a little, never square to the screen.
  static const double _tilt = -0.2;
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

      // ── the shafts, turning slowly out from behind it ──
      final turn = t * 0.09;
      for (var j = 0; j < _rays; j++) {
        final a = turn + (j + _rayJit[j]) * math.pi * 2 / _rays;
        final breathe = 0.5 + 0.5 * math.sin(t * 0.7 + j * 2.3);
        final len = _rayLen[j] * (0.85 + 0.15 * breathe) * r;
        c.save();
        c.translate(cx, cy - r * 0.05);
        c.rotate(a);
        c.scale(len, _rayW[j] * r);
        _bladePaint
          ..shader = _bladeShader(hue0 + j / _rays, dark)
          ..color = Color.fromRGBO(
            0,
            0,
            0,
            (0.2 + 0.16 * breathe) * (dark ? 1 : 0.85) * o,
          );
        c.drawPath(_blade, _bladePaint);
        c.restore();
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

    // ── the ring: one atlas call for this layer ──
    _Atlas.clear();
    final ringY = cy + r * 0.06;
    final n = (_ringN * (r / 44).clamp(0.55, 1.0)).round();
    // Never smaller than this, in pixels, or a HUD slot loses them.
    const minGrain = 3.4;
    for (var i = 0; i < n; i++) {
      final rho = _rho[i];
      final th = _th0[i] + t * 0.55 / rho;
      final sn = math.sin(th);
      // The near side is in front of the creature.
      if ((sn > 0) != front) continue;
      final x = math.cos(th) * rho * r;
      final y = sn * rho * r * 0.3 + _lift[i] * r;
      final px = cx + x * _ct - y * _st;
      final py = ringY + x * _st + y * _ct;
      final near = 0.55 + 0.45 * (sn * 0.5 + 0.5);
      var size = math.max(minGrain, _gSize[i] * r) * (0.75 + 0.25 * near);
      var rgb = _hueRgb(th / (math.pi * 2) + hue0, dark);
      var alpha = (dark ? 0.85 : 0.9) * near * o;
      // Now and then a grain flares white.
      if (_frac(t * 0.45 + _tw[i] * 9) < 0.035) {
        rgb = dark ? 0xFFFFFF : _hueRgb(th / (math.pi * 2) + hue0, true);
        size *= 1.7;
        alpha = o;
      }
      _Atlas.add(px, py, size, rgb, alpha);
    }

    _Atlas.draw(c, additive: dark);
  }
}
