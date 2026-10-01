part of 'alchemy_effect_paint.dart';

/// ELEMENTAL DUST RING — Cindrath's ring (the planet dust ring, the
/// player's favourite of the planet work) round a creature, in its
/// element's colours.
///
/// Soft lanes of dust in a tipped plane, and a few hundred grains on their
/// orbits over them — inner grains faster than outer, the way a real ring
/// shears, so clumps draw out into arcs as they go — each twinkling on its
/// own beat. The far half is drawn behind the creature and the near half
/// across it, so it stands inside the ring.
abstract final class _DustRing {
  /// Lanes as (centre, half-width, weight), in creature radii.
  static const List<(double, double, double)> _lanes = [
    (1.04, 0.06, 3.0),
    (1.23, 0.09, 4.0),
    (1.42, 0.05, 1.5),
  ];

  /// How far the lanes' gradient reaches.
  static const double _reach = 1.6;

  static const double _tilt = -0.2;
  static const double _flat = 0.3;
  static const double _speed = 0.5;

  /// The lanes' soft profile: gradient stops and alphas out to [_reach].
  static final (List<double>, List<double>) _profile = () {
    const n = 28;
    final stops = <double>[], alphas = <double>[];
    for (var i = 0; i <= n; i++) {
      final rad = _reach * i / n;
      var a = 0.0;
      for (final (c, w, peak) in _lanes) {
        final u = (rad - c) / w;
        a = math.max(a, (peak / 4) * math.exp(-u * u));
      }
      stops.add(i / n);
      alphas.add(i == n ? 0 : a);
    }
    return (stops, alphas);
  }();

  // The grains: (radius, starting angle, size class, twinkle phase), most
  // strewn by the lanes' weight and some gathered into clumps.
  static final List<double> _rad = [];
  static final List<double> _a0 = [];
  static final List<bool> _big = [];
  static final List<double> _phase = [];
  static bool _strewn = false;

  static void _strew() {
    if (_strewn) return;
    _strewn = true;
    final total = _lanes.fold(0.0, (s, l) => s + l.$3);
    var seed = 0;
    double rnd() => _h(seed++, 151);
    double laneRadius() {
      var pick = rnd() * total;
      for (final (c, w, weight) in _lanes) {
        pick -= weight;
        if (pick <= 0) return c + (rnd() + rnd() - 1) * w;
      }
      return _lanes.last.$1;
    }

    for (var i = 0; i < 300; i++) {
      _rad.add(laneRadius());
      _a0.add(rnd() * math.pi * 2);
      _big.add(rnd() > 0.65);
      _phase.add(rnd() * math.pi * 2);
    }
    for (var k = 0; k < 8; k++) {
      final a = rnd() * math.pi * 2;
      final rad = laneRadius();
      for (var i = 0; i < 18; i++) {
        _rad.add(rad + (rnd() - 0.5) * 0.06);
        _a0.add(a + (rnd() - 0.5) * 0.35);
        _big.add(rnd() > 0.45);
        _phase.add(rnd() * math.pi * 2);
      }
    }
  }

  static final Map<int, Shader> _laneShaders = {};
  static final Paint _lanePaint = Paint();

  static void paint(
    Canvas c,
    Offset at,
    double r,
    double t,
    EssenceElement e,
    double o,
    bool dark,
    bool front,
  ) {
    _strew();
    final sh = _ElementalAura._shades(e, dark);
    final ramp = essenceRamp(e);
    var laneCol = essencePool(e);
    if (!dark) laneCol = Color.lerp(laneCol, ramp[1], 0.45)!;
    // Dark's own light is black; its lanes take its violet instead.
    if (e == EssenceElement.dark) laneCol = dark ? ramp[3] : ramp[1];

    c.save();
    c.translate(at.dx, at.dy + r * 0.06);
    c.rotate(_tilt);
    // The near half is the lower one in the ring's plane.
    final far = r * 3;
    c.clipRect(
      front
          ? Rect.fromLTRB(-far, 0, far, far)
          : Rect.fromLTRB(-far, -far, far, 0),
    );

    // ── the lanes ──
    final key = laneCol.toARGB32() | 0xFF000000;
    final (stops, alphas) = _profile;
    final shader = _laneShaders[key] ??= ui.Gradient.radial(
      Offset.zero,
      _reach,
      [for (final a in alphas) laneCol.withValues(alpha: a)],
      stops,
    );
    c.save();
    c.scale(r, r * _flat);
    _lanePaint
      ..shader = shader
      ..color = Color.fromRGBO(
        0,
        0,
        0,
        ((dark ? 0.85 : 1.0) * (0.85 + 0.15 * math.sin(t * 0.4)) * o)
            .clamp(0.0, 1.0),
      );
    c.drawCircle(Offset.zero, _reach, _lanePaint);
    c.restore();

    // ── the grains: bucket = lit × 2 + size ──
    final b = _batch..clear();
    for (var i = 0; i < _rad.length; i++) {
      final rad = _rad[i];
      final a = _a0[i] + t * _speed / (rad * math.sqrt(rad));
      final sy = math.sin(a);
      if ((sy > 0) != front) continue;
      final lit = math.sin(t * 2.2 + _phase[i]) > 0.55;
      b.add(
        (lit ? 2 : 0) + (_big[i] ? 1 : 0),
        math.cos(a) * rad * r,
        sy * rad * r * _flat,
      );
    }
    // Fine, crisp dust, as on the planet: never beads.
    final d = math.max(1.2, r * 0.026);
    // The far half a touch dimmer: it is further off.
    final k = (front ? 1.0 : 0.8) * o;
    b.draw(c, 0, d * 1.2, _fade(sh[2], 0.65 * k));
    b.draw(c, 1, d * 1.9, _fade(sh[2], 0.65 * k));
    b.draw(c, 2, d * 1.2, _fade(sh[3], 0.95 * k));
    b.draw(c, 3, d * 1.9, _fade(sh[3], 0.95 * k));
    c.restore();
  }
}
