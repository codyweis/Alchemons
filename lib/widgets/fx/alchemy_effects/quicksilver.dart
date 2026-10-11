part of 'alchemy_effect_paint.dart';

/// QUICKSILVER (the Athanor, the White Work) — the creature stands in a
/// pool of liquid silver. Its far edge gives back the sky, its body is dark
/// mirror, and a highlight slides slowly over it; beads of it roll in from
/// round the pool and are taken back into it, and now and then a drop
/// lifts off the surface, hangs, and falls back with a ripple. Mercury is
/// known by its beads, so they lead: a few big ones only shiver where they
/// lie.
///
/// The pools are cached unit outlines; the beads are atlas sprites (one
/// pass behind the creature, one in front).
abstract final class _Quicksilver {
  /// A mirror lying flat: its far half gives back the sky (bright, cool),
  /// a hard horizon, then the dark of the ground it reflects, lightening
  /// again toward the near edge where it gives back the sky at a slant.
  static final Shader _surface = ui.Gradient.linear(
    const Offset(0, -1),
    const Offset(0, 1),
    const [
      Color(0xFFF2F5FA),
      Color(0xFFC4CDD9),
      Color(0xFF8C97A6),
      Color(0xFF2C323C),
      Color(0xFF20252D),
      Color(0xFF5E6876),
      Color(0xFFB4BECB),
    ],
    const [0.0, 0.18, 0.4, 0.47, 0.7, 0.9, 1.0],
  );

  static final Paint _paint = Paint()..isAntiAlias = true;
  static final Paint _flat = Paint()..isAntiAlias = true;

  /// A pool's outline on the unit disc, lobed where it has run.
  static Path _pond(int seed, double lobes) {
    const n = 28;
    final k = seed * 1.7;
    final xs = Float64List(n), ys = Float64List(n);
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2;
      final rr =
          1 +
          lobes *
              (0.13 * math.sin(2 * a + 0.6 + k) +
                  0.08 * math.sin(3 * a + 2.1 + k) +
                  0.04 * math.sin(5 * a));
      xs[i] = math.cos(a) * rr;
      ys[i] = math.sin(a) * rr;
    }
    final path = Path()
      ..moveTo((xs[n - 1] + xs[0]) / 2, (ys[n - 1] + ys[0]) / 2);
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      path.quadraticBezierTo(
        xs[i],
        ys[i],
        (xs[i] + xs[j]) / 2,
        (ys[i] + ys[j]) / 2,
      );
    }
    return path..close();
  }

  /// The main pool, then the three little ones that have run off it.
  static final List<Path> _ponds = [
    _pond(0, 1.5),
    _pond(3, 0.6),
    _pond(5, 0.5),
    _pond(7, 0.4),
  ];

  /// The near edge's bright meniscus, on the unit pool.
  static final Path _meniscus = vfxCrescent(
    const Offset(0, -0.2),
    1.12,
    0.16,
    math.pi / 2,
    2.3,
  );

  /// A ripple's near and far halves, at unit radius.
  static final Path _rippleNear = vfxCrescent(
    Offset.zero,
    1,
    0.11,
    math.pi / 2,
    math.pi * 1.5,
  );
  static final Path _rippleFar = vfxCrescent(
    Offset.zero,
    1,
    0.08,
    -math.pi / 2,
    math.pi * 0.9,
  );

  /// One pool of the metal, centred at ([x], [y]), [rx] by [ry]. Its edge
  /// shivers a little as the metal does.
  static void _puddle(
    Canvas c,
    int which,
    double x,
    double y,
    double rx,
    double ry,
    double t,
    double o, {
    int streaks = 0,
    bool meniscus = false,
  }) {
    final shiver = 1 + 0.018 * math.sin(t * 2.3 + which * 1.9);
    c.save();
    c.translate(x, y);
    c.scale(rx * shiver, ry * (2 - shiver));
    final pond = _ponds[which];
    _paint
      ..shader = _surface
      ..color = Color.fromRGBO(0, 0, 0, o);
    c.drawPath(pond, _paint);
    if (streaks > 0 || meniscus) {
      c.clipPath(pond);
      // Light sliding over it, and the near edge's bright meniscus.
      for (var i = 0; i < streaks; i++) {
        final f = _frac(t / (9 + i * 5) + i * 0.43);
        c.drawOval(
          Rect.fromCenter(
            center: Offset(-1.4 + f * 2.8, -0.5 + i * 0.62),
            width: 0.8 - i * 0.3,
            height: 0.09,
          ),
          _flat..color = Color.fromRGBO(255, 255, 255, (0.7 - i * 0.3) * o),
        );
      }
      if (meniscus) {
        c.drawPath(
          _meniscus,
          _flat..color = Color.fromRGBO(235, 242, 252, 0.5 * o),
        );
      }
    }
    c.restore();
  }

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
    final cx = at.dx, fy = at.dy + r * 0.64;
    final rx = r * 0.64, ry = r * 0.15;
    if (!front) {
      // Cold light round it, then the pool and the little ones that have
      // run off it.
      _pool(c, cx, fy, r * 1.15, ry * 2.6, const Color(0xFFB4C8E0), 0.2 * o);
      _puddle(c, 1, cx + rx * 1.25, fy + ry * 0.6, rx * 0.2, ry * 0.36, t, o);
      _puddle(c, 2, cx - rx * 1.32, fy + ry * 0.25, rx * 0.15, ry * 0.3, t, o);
      _puddle(c, 3, cx - rx * 0.9, fy + ry * 1.25, rx * 0.1, ry * 0.22, t, o);
      _puddle(c, 0, cx, fy, rx, ry, t, o, streaks: 2, meniscus: true);
    }

    // Drops lifting off the surface and falling back, and the ripple where
    // each lands (on the silver, so always behind).
    _Atlas.clear();
    for (var i = 0; i < 3; i++) {
      final period = 6 + 3 * _h(i, 51);
      final u = _frac(t / period + _h(i, 52));
      final a = _h(i, 53) * math.pi * 2;
      final near = math.sin(a) > 0;
      final bx = cx + math.cos(a) * rx * 0.62;
      final by = fy + math.sin(a) * ry * 0.62;
      if (near == front && u < 0.75) {
        // Up slowly (0–0.5), hanging (–0.62), falling (–0.75).
        final double lift;
        if (u < 0.5) {
          lift = _smooth(0.0, 0.5, u);
        } else if (u < 0.62) {
          lift = 1 + 0.03 * math.sin((u - 0.5) * 50);
        } else {
          final g = (u - 0.62) / 0.13;
          lift = 1 - g * g;
        }
        final br = r * 0.045 * _smooth(0.0, 0.12, u);
        _bead(bx, by - lift * r * 0.55, br, o);
      }
      if (!front && u > 0.75 && u < 0.98) {
        final g = (u - 0.75) / 0.23;
        final fade = (1 - g) * (1 - g);
        final rr = r * (0.04 + 0.22 * g);
        c.save();
        c.translate(bx, by);
        c.scale(rr, rr * 0.26);
        c.drawPath(
          _rippleNear,
          _flat..color = Color.fromRGBO(235, 242, 250, 0.5 * fade * o),
        );
        c.drawPath(
          _rippleFar,
          _flat..color = Color.fromRGBO(235, 242, 250, 0.3 * fade * o),
        );
        c.restore();
      }
    }

    // Beads all round on the ground, rolling slowly in and taken back into
    // the pool. A few big ones only shiver where they lie.
    for (var i = 0; i < 16; i++) {
      final big = i < 4;
      final a = _h(i, 41) * math.pi * 2 + t * 0.04 * (_h(i, 42) - 0.5);
      final near = math.sin(a) > 0;
      if (near != front) continue;
      final double d, grow;
      if (big) {
        d = 1.3 + 0.4 * _h(i, 46);
        grow = 1 + 0.04 * math.sin(t * 3 + i);
      } else {
        final period = 6 + 5 * _h(i, 43);
        final u = _frac(t / period + _h(i, 44));
        d = 2.1 - 1.1 * _smooth(0.0, 0.9, u);
        grow = _smooth(0.0, 0.12, u) * (1 - _smooth(0.85, 1.0, u));
      }
      final br =
          r * (big ? 0.06 + 0.03 * _h(i, 45) : 0.022 + 0.03 * _h(i, 45)) * grow;
      // The ground is seen at a slant: the far side of it close behind the
      // pool, so no bead seems to hang in the air beside the creature.
      final sa = math.sin(a);
      _bead(
        cx + math.cos(a) * rx * d,
        fy + sa * ry * d * (sa < 0 ? 0.8 : 1.3),
        br,
        o,
      );
    }
    _Atlas.draw(c, additive: false);
  }
}
