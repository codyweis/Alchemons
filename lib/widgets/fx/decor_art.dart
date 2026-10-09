part of 'keepsake_art.dart';

// The home decor (models/home_decor.dart), in the keepsakes' material and
// units. A creature on its row stands about 140 of these tall and wide, so
// what the residents sit in, climb or bathe in is sized to them.

KeepsakeArt? _decorArt(String id, int style) => switch (id) {
  'lantern_post' => _LanternPost(style),
  'candles' => _Candles(),
  'geode' => _Geode(style),
  'rune_stone' => _RuneStone(style),
  'banner' => _Banner(style),
  'planter' => _Planter(style),
  'sky_lanterns' => _SkyLanterns(style),
  'wind_chimes' => _WindChimes(),
  'fountain' => _Fountain(),
  'rest_nest' => _RestNest(),
  'flyer_perch' => _FlyerPerch(),
  'swing' => _Swing(),
  'canopy' => _Canopy(),
  'mushroom_ring' => _MushroomRing(),
  'hot_spring' => _HotSpring(),
  'elder_tree' => _ElderTree(),
  'stage' => _Stage(),
  'orrery' => _Orrery(),
  'reflecting_pool' => _ReflectingPool(),
  _ => null,
};

Color _pick(List<Color> colors, int style) =>
    colors[style.clamp(0, colors.length - 1)];

const _lampColors = [Color(0xFFFFB45A), Color(0xFFA9E8FF), Color(0xFFB48CFF)];

// ── Curios ─────────────────────────────────────────────────────────────────

/// A glass lamp on an obsidian post, lit by dusk.
class _LanternPost extends KeepsakeArt {
  _LanternPost(int style) : super(_pick(_lampColors, style));

  static const _lamp = Offset(0, -150);

  @override
  Rect get box => const Rect.fromLTRB(-24, -186, 24, 4);

  @override
  void body(Canvas c) {
    _plinth(c, m, 34, 10);
    _shaft(c, m, 0, -8, -128, 13, 9);
    // The cage round the glass: a cap and a foot of stone.
    _block(c, m, const Rect.fromLTRB(-13, -132, 13, -126), bevel: 1.4);
    final cap = _poly(const [
      Offset(-15, -172),
      Offset(15, -172),
      Offset(4, -184),
      Offset(-4, -184),
    ]);
    _solid(c, cap, m.ink);
    _shade(c, cap, _litAcross(m, -15, 15, k: 0.5));
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    final on = 0.25 + 0.75 * k.night;
    paintDisc(c, m.pool, _lamp, 60, 0.8 * on);
    _groundPool(c, m, 0, 70, 0.6 * on);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final on = 0.3 + 0.7 * k.night;
    final glass = _poly(const [
      Offset(-11, -170),
      Offset(11, -170),
      Offset(9, -132),
      Offset(-9, -132),
    ]);
    _glass(c, m, glass, _lamp, 26 * (0.6 + 0.4 * on));
    final flick = 0.85 + 0.15 * math.sin(k.t * 6.3) * math.sin(k.t * 2.1);
    paintDisc(c, m.spark, _lamp, 9 * flick, on);
  }
}

/// A few candles in the grass, each its own flame.
class _Candles extends KeepsakeArt {
  _Candles() : super(const Color(0xFFFFB45A));

  static const _candles = <(double, double, double)>[
    (-16.0, 30.0, 6.0),
    (-4.0, 44.0, 7.0),
    (9.0, 24.0, 5.5),
    (20.0, 36.0, 6.0),
  ];

  @override
  Rect get box => const Rect.fromLTRB(-30, -70, 30, 4);

  @override
  void body(Canvas c) {
    final wax = StoneLight(const Color(0xFFEFD9B0));
    for (final (x, h, w) in _candles) {
      final stick = _poly([
        Offset(x - w / 2, 0),
        Offset(x - w / 2, -h),
        Offset(x + w / 2, -h - 1),
        Offset(x + w / 2, 0),
      ]);
      _solid(c, stick, wax.ink);
      _shade(c, stick, _litAcross(wax, x - w / 2, x + w / 2, k: 0.7));
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) =>
      _groundPool(c, m, 0, 60, 0.35 + 0.55 * k.night);

  @override
  void live(Canvas c, KeepsakeTime k) {
    for (var i = 0; i < _candles.length; i++) {
      final (x, h, _) = _candles[i];
      _flame(
        c,
        Offset(x, -h - 1),
        16 + 4 * k.stir,
        6,
        k.t * (1 + i * 0.13),
        i * 5,
        core: const Color(0xFFFFF1C8),
        body: const Color(0xFFFF9A3C),
      );
    }
  }
}

/// Crystals breaking out of the ground.
class _Geode extends KeepsakeArt {
  _Geode(int style)
    : super(
        _pick(const [
          Color(0xFF6FF2D0),
          Color(0xFFB48CFF),
          Color(0xFFF29BC0),
          Color(0xFFFFC46B),
        ], style),
      );

  @override
  Rect get box => const Rect.fromLTRB(-40, -86, 40, 4);

  @override
  void body(Canvas c) {
    final rock = StoneLight(const Color(0xFF8A8F9A));
    final base = _poly(const [
      Offset(-38, 2),
      Offset(-28, -14),
      Offset(-6, -20),
      Offset(18, -16),
      Offset(36, 2),
    ]);
    _solid(c, base, rock.ink);
    _shade(c, base, _litAcross(rock, -38, 36, k: 0.4));
    for (final (x, h, lean) in const [
      (-14.0, 54.0, -10.0),
      (0.0, 80.0, 2.0),
      (14.0, 60.0, 12.0),
      (-26.0, 32.0, -16.0),
      (26.0, 36.0, 18.0),
    ]) {
      final b = Offset(x, -12);
      final tip = b + Offset(lean, -h);
      CutStone.gem(m, [
        b + const Offset(-6, 0),
        b + Offset(-6 + lean * 0.6, -h * 0.72),
        tip,
        b + Offset(6 + lean * 0.6, -h * 0.72),
        b + const Offset(6, 0),
      ], b + Offset(lean * 0.4, -h * 0.4)).paint(c, 0, glow: 1.3, reach: h);
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) =>
      paintDisc(c, m.pool, const Offset(0, -40), 50, 0.3 + 0.5 * k.night);

  @override
  void live(Canvas c, KeepsakeTime k) {
    for (var i = 0; i < 4; i++) {
      final on = math.max(0.0, math.sin(k.t * 0.8 + i * 1.9));
      paintDisc(
        c,
        kGlint,
        Offset(-14 + i * 10.0, -40 - 14.0 * (i % 2)),
        4,
        on * on * 0.8,
      );
    }
  }
}

/// A small stone with an alchemical sign lit in it.
class _RuneStone extends KeepsakeArt {
  _RuneStone(this.sign)
    : super(
        _pick(const [
          Color(0xFFFF8A3D),
          Color(0xFF7FC4FF),
          Color(0xFFCFE8FF),
          Color(0xFFC9A46A),
          Color(0xFFFFD76B),
          Color(0xFFD8E0FF),
        ], sign),
      );

  /// Fire, Water, Air, Earth, the Sun, the Moon.
  final int sign;
  static const _at = Offset(0, -52);

  @override
  Rect get box => const Rect.fromLTRB(-30, -96, 30, 4);

  @override
  void body(Canvas c) {
    final stone = StoneLight(const Color(0xFF8A8F9A));
    final slab = _poly(const [
      Offset(-26, 2),
      Offset(-28, -60),
      Offset(-14, -90),
      Offset(10, -94),
      Offset(26, -70),
      Offset(24, 2),
    ]);
    _solid(c, slab, stone.ink);
    _shade(c, slab, _litAcross(stone, -28, 26, k: 0.5));
  }

  /// The sign: the classical triangles, the Sun's disc, the Moon's
  /// crescent — filled, not drawn.
  Path _sign() {
    const r = 15.0;
    Path tri(bool up) => _poly([
      _at + Offset(0, up ? -r : r),
      _at + Offset(r * 0.95, up ? r * 0.6 : -r * 0.6),
      _at + Offset(-r * 0.95, up ? r * 0.6 : -r * 0.6),
    ]);
    Path hole(bool up) => _poly([
      _at + Offset(0, up ? -r * 0.45 : r * 0.45),
      _at + Offset(r * 0.48, up ? r * 0.32 : -r * 0.32),
      _at + Offset(-r * 0.48, up ? r * 0.32 : -r * 0.32),
    ]);
    Path bar() => Path()
      ..addRect(Rect.fromCenter(center: _at, width: r * 1.5, height: 2.6));
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: _at, radius: r * 0.9))
      ..addOval(Rect.fromCircle(center: _at, radius: r * 0.62));
    return switch (sign) {
      0 => Path.combine(PathOperation.difference, tri(true), hole(true)),
      1 => Path.combine(PathOperation.difference, tri(false), hole(false)),
      2 => Path.combine(
        PathOperation.union,
        Path.combine(PathOperation.difference, tri(true), hole(true)),
        bar(),
      ),
      3 => Path.combine(
        PathOperation.union,
        Path.combine(PathOperation.difference, tri(false), hole(false)),
        bar(),
      ),
      4 => ring
        ..addOval(Rect.fromCircle(center: _at, radius: r * 0.2)),
      _ => _poly(crescentPoints(r * 0.8, -2.2, 2.2, r * 0.7))
          .shift(_at),
    };
  }

  late final Path _glyph = _sign();

  @override
  void under(Canvas c, KeepsakeTime k) =>
      paintDisc(c, m.pool, _at, 40, 0.3 + 0.5 * k.night);

  @override
  void live(Canvas c, KeepsakeTime k) {
    final b = 0.65 + 0.2 * math.sin(k.t * 0.9) + 0.3 * k.stir;
    _solid(c, _glyph, _a(m.hot, b));
    paintDisc(c, m.spark, _at, 10, 0.25 * b);
  }
}

/// A banner in a faction's colors on a tall pole, moving with the wind.
class _Banner extends KeepsakeArt {
  _Banner(int style)
    : super(
        _pick(const [
          Color(0xFFE0603A),
          Color(0xFF4F8FE0),
          Color(0xFF5FB37A),
          Color(0xFFC08A4E),
        ], style),
      );

  @override
  Rect get box => const Rect.fromLTRB(-20, -270, 90, 4);

  @override
  void body(Canvas c) {
    final pole = StoneLight(const Color(0xFF8C96B4));
    _plinth(c, pole, 24, 8);
    _shaft(c, pole, 0, -8, -262, 12, 8);
    paintOrb(c, StoneLight(_gold), const Offset(0, -266), 4.5);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    // The cloth: hung from the pole's head, waving along its length.
    const top = -252.0, h = 110.0, w = 78.0;
    final wave = 1 + 0.6 * k.stir;
    Offset at(double u, double v) {
      final ripple = math.sin(k.t * 2.2 - u * 4) * 5 * u * wave;
      return Offset(
        3 + u * w,
        top + v * h * (1 - u * 0.12) + ripple + u * 4,
      );
    }

    const n = 10;
    final topEdge = [for (var i = 0; i <= n; i++) at(i / n, 0)];
    final bottom = [for (var i = n; i >= 0; i--) at(i / n, 1)];
    // A swallowtail cut at the free end.
    final tail = at(0.82, 0.5);
    final cloth = _poly([...topEdge, tail, ...bottom]);
    // Cloth is lit by the day, not from inside: darker by night.
    final dark = 0.4 + 0.35 * k.night;
    _shade(
      c,
      cloth,
      ui.Gradient.linear(at(0, 0), at(1, 1), [
        Color.lerp(m.essence, const Color(0xFF05060B), dark)!,
        Color.lerp(m.essence, const Color(0xFF05060B), dark + 0.25)!,
      ]),
    );
    // Its fold catching the light, in a band along the ripple.
    final fold = _poly([
      for (var i = 0; i <= n; i++) at(i / n, 0.05),
      for (var i = n; i >= 0; i--) at(i / n, 0.22),
    ]);
    _shade(
      c,
      fold,
      ui.Gradient.linear(at(0, 0), at(1, 0), [
        _a(m.rim, 0.35),
        _a(m.rim, 0.05),
      ]),
    );
    // A gold sigil on it.
    paintOrb(c, StoneLight(_gold), at(0.4, 0.5), 7);
  }
}

/// An obsidian planter of glowing flowers.
class _Planter extends KeepsakeArt {
  _Planter(int style)
    : super(
        _pick(const [
          Color(0xFFF29BC0),
          Color(0xFFFFD27A),
          Color(0xFF8FD3FF),
          Color(0xFFB48CFF),
        ], style),
      );

  final StoneLight _green = StoneLight(const Color(0xFF6FAF6A));
  static const _blooms = <(double, double)>[(-16, -70), (0, -84), (15, -66)];

  @override
  Rect get box => const Rect.fromLTRB(-34, -100, 34, 4);

  @override
  void body(Canvas c) {
    final pot = StoneLight(const Color(0xFF8C96B4));
    final bowl = _poly(const [
      Offset(-30, -36),
      Offset(30, -36),
      Offset(22, 0),
      Offset(-22, 0),
    ]);
    _solid(c, bowl, pot.ink);
    _shade(c, bowl, _litAcross(pot, -30, 30, k: 0.4));
    _block(c, pot, const Rect.fromLTRB(-33, -40, 33, -34), bevel: 1.6);
    for (final (x, y) in _blooms) {
      _shaft(c, _green, x * 0.4, -38, y + 6, 2.6, 2, lean: x * 0.6);
    }
    for (final (a, side) in const [(-0.6, -1.0), (0.5, 1.0), (-0.2, -1.0)]) {
      _leaf(c, _green, Offset(side * 6, -42), -math.pi / 2 + a, 26, 9);
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) =>
      paintDisc(c, m.pool, const Offset(0, -74), 46, 0.3 + 0.5 * k.night);

  @override
  void live(Canvas c, KeepsakeTime k) {
    for (var i = 0; i < _blooms.length; i++) {
      final (x, y) = _blooms[i];
      final at = Offset(x, y + math.sin(k.t * 0.8 + i) * 1.5);
      for (var p = 0; p < 5; p++) {
        _leaf(c, m, at, p * math.pi * 2 / 5 + i, 10, 6, glow: 1.1);
      }
      paintOrb(c, StoneLight(const Color(0xFFFFE6A0)), at, 3);
    }
  }
}

/// Lanterns hanging in the air on nothing, drifting. Their point is in the
/// air, not on the ground.
class _SkyLanterns extends KeepsakeArt {
  _SkyLanterns(int style) : super(_pick(const [
    Color(0xFFFFB45A),
    Color(0xFFF29BC0),
    Color(0xFFA9E8FF),
  ], style));

  static const _hung = <(double, double, double)>[
    (-44, 0, 1.5),
    (8, -36, 1.2),
    (50, 10, 1.35),
  ];

  @override
  Rect get box => const Rect.fromLTRB(-84, -96, 86, 56);

  @override
  void body(Canvas c) {}

  @override
  void live(Canvas c, KeepsakeTime k) {
    for (var i = 0; i < _hung.length; i++) {
      final (x, y, s) = _hung[i];
      final at = Offset(
        x + math.sin(k.t * 0.3 + i * 2) * 6,
        y + math.sin(k.t * 0.5 + i) * 7,
      );
      paintDisc(c, m.pool, at, 34 * s, 0.6 + 0.6 * k.night);
      final body = _poly([
        at + Offset(-10 * s, -16 * s),
        at + Offset(10 * s, -16 * s),
        at + Offset(13 * s, 6 * s),
        at + Offset(7 * s, 15 * s),
        at + Offset(-7 * s, 15 * s),
        at + Offset(-13 * s, 6 * s),
      ]);
      _glass(c, m, body, at + Offset(0, 4 * s), 22 * s);
      final flick = 0.8 + 0.2 * math.sin(k.t * 5.7 + i * 2);
      paintDisc(c, m.spark, at + Offset(0, 6 * s), 7 * s * flick, 0.9);
    }
  }
}

// ── Living Pieces ──────────────────────────────────────────────────────────

/// Glass rods hung from a bough, swinging in the wind and when brushed.
class _WindChimes extends KeepsakeArt {
  _WindChimes() : super(const Color(0xFFBFE6FF));

  static const _rods = <(double, double)>[
    (-24, 46),
    (-12, 62),
    (0, 54),
    (12, 70),
    (24, 50),
  ];

  @override
  Rect get box => const Rect.fromLTRB(-46, -236, 46, 4);

  @override
  void body(Canvas c) {
    final post = StoneLight(const Color(0xFF8C96B4));
    _plinth(c, post, 30, 8);
    _shaft(c, post, -30, -8, -224, 13, 9);
    // The bough out over them.
    final bough = _poly(const [
      Offset(-34, -226),
      Offset(34, -222),
      Offset(36, -216),
      Offset(-34, -218),
    ]);
    _solid(c, bough, post.ink);
    _shade(c, bough, _litAcross(post, -34, 36, k: 0.4));
  }

  @override
  void under(Canvas c, KeepsakeTime k) =>
      paintDisc(c, m.pool, const Offset(0, -170), 50, 0.25 + 0.4 * k.night);

  @override
  void live(Canvas c, KeepsakeTime k) {
    final push = 0.25 + 1.4 * k.stir;
    for (var i = 0; i < _rods.length; i++) {
      final (x, len) = _rods[i];
      final swing =
          math.sin(k.t * (1.6 + i * 0.21) + i) * 0.12 * push +
          math.sin(k.t * 0.4) * 0.04;
      final top = Offset(x, -218);
      final dir = Offset(math.sin(swing), math.cos(swing));
      final hang = top + dir * 18;
      final end = hang + dir * len;
      final n = Offset(-dir.dy, dir.dx) * 4.2;
      _glass(c, m, _poly([hang - n, hang + n, end + n * 0.8, end - n * 0.8]),
          end, 14);
      // Its thread, a sliver of stone.
      _solid(c, _poly([top - n * 0.2, top + n * 0.2, hang + n * 0.2, hang - n * 0.2]),
          m.ink);
      paintDisc(c, m.spark, end, 3, 0.4 + 0.5 * k.stir);
    }
  }
}

/// A basin whose water rises in grains and falls back.
class _Fountain extends KeepsakeArt {
  _Fountain() : super(const Color(0xFF8FD3FF));

  final _Grains _water = _Grains(170);

  @override
  Rect get box => const Rect.fromLTRB(-84, -150, 84, 4);

  @override
  void body(Canvas c) {
    final stone = StoneLight(const Color(0xFF8C96B4));
    final basin = _poly(const [
      Offset(-82, -40),
      Offset(82, -40),
      Offset(70, -10),
      Offset(40, 0),
      Offset(-40, 0),
      Offset(-70, -10),
    ]);
    _solid(c, basin, stone.ink);
    _shade(c, basin, _litAcross(stone, -82, 82, k: 0.4));
    _glass(
      c,
      m,
      _poly(const [
        Offset(-76, -40),
        Offset(76, -40),
        Offset(66, -33),
        Offset(-66, -33),
      ]),
      const Offset(0, -38),
      60,
    );
    _shaft(c, stone, 0, -38, -96, 14, 8);
    _block(c, stone, const Rect.fromLTRB(-16, -102, 16, -96), bevel: 1.4);
  }

  @override
  void under(Canvas c, KeepsakeTime k) =>
      paintDisc(c, m.pool, const Offset(0, -80), 80, 0.25 + 0.4 * k.night);

  @override
  void live(Canvas c, KeepsakeTime k) {
    _water.clear();
    final rise = 1 + 0.4 * k.stir;
    for (var i = 0; i < 120; i++) {
      final f = (k.t * (0.45 + 0.2 * _hash(i, 1)) + _hash(i, 2)) % 1.0;
      final side = _hash(i, 3) < 0.5 ? -1.0 : 1.0;
      final reach = (18 + 34 * _hash(i, 4)) * side;
      // Up out of the spout and over in an arc into the basin.
      final x = reach * f;
      final y = -102 - 48 * rise * 4 * f * (1 - f) + 64 * f * f;
      _water.add(x, y);
    }
    _water.draw(c, 3.4, _a(const Color(0xFFDDF2FF), 0.7));
  }
}

/// A woven nest of dark reeds. At night a resident sleeps in it.
class _RestNest extends KeepsakeArt {
  _RestNest() : super(const Color(0xFFE8C88A));

  @override
  Rect get box => const Rect.fromLTRB(-88, -44, 88, 4);

  @override
  double? get seat => 18;

  @override
  void body(Canvas c) {
    final reed = StoneLight(const Color(0xFFB08A5A));
    // Back rim, then the bowl, the lining lit warm.
    final bowl = Path()
      ..moveTo(-86, -30)
      ..quadraticBezierTo(-80, 2, 0, 2)
      ..quadraticBezierTo(80, 2, 86, -30)
      ..quadraticBezierTo(0, -14, -86, -30)
      ..close();
    _solid(c, bowl, reed.ink);
    _shade(c, bowl, _litAcross(reed, -86, 86, k: 0.45));
    // Reeds woven across it: thin filled strands.
    for (var i = 0; i < 9; i++) {
      final y = -26 + i * 2.8;
      final strand = _poly([
        Offset(-82 + i * 3, y),
        Offset(82 - i * 3, y - 2),
        Offset(82 - i * 3, y - 0.6),
        Offset(-82 + i * 3, y + 1.4),
      ]);
      _shade(
        c,
        strand,
        ui.Gradient.linear(const Offset(-80, 0), const Offset(80, 0), [
          _a(reed.rim, 0.22),
          _a(reed.rim, 0.05),
        ]),
      );
    }
    final lining = _poly(const [
      Offset(-70, -30),
      Offset(70, -30),
      Offset(50, -22),
      Offset(-50, -22),
    ]);
    _glass(c, m, lining, const Offset(0, -26), 50);
  }

  @override
  void under(Canvas c, KeepsakeTime k) =>
      _groundPool(c, m, 0, 90, 0.2 + 0.35 * k.night);

  @override
  void live(Canvas c, KeepsakeTime k) {}
}

/// A tall perch with a crossbar. Flyers land on it.
class _FlyerPerch extends KeepsakeArt {
  _FlyerPerch() : super(const Color(0xFF9FD6F2));

  @override
  Rect get box => const Rect.fromLTRB(-40, -320, 40, 4);

  @override
  double? get seat => 300;

  @override
  void body(Canvas c) {
    final post = StoneLight(const Color(0xFF8C96B4));
    _plinth(c, post, 36, 10, steps: 3);
    _shaft(c, post, 0, -10, -296, 16, 11);
    _block(c, post, const Rect.fromLTRB(-36, -302, 36, -296), bevel: 1.6);
    for (final x in const [-36.0, 36.0]) {
      paintOrb(c, m, Offset(x, -299), 3.6);
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) =>
      paintDisc(c, m.pool, const Offset(0, -300), 40, 0.3 + 0.4 * k.night);

  @override
  void live(Canvas c, KeepsakeTime k) {}
}

/// A seat between two posts. A resident climbs on and swings.
class _Swing extends KeepsakeArt {
  _Swing() : super(const Color(0xFFE8C88A));

  static const _top = -250.0, _rope = 180.0;

  /// How far it is swinging at [k], in radians.
  double _angle(KeepsakeTime k) =>
      math.sin(k.t * 1.6) * (0.06 + 0.34 * math.min(1.0, k.stir));

  @override
  Rect get box => const Rect.fromLTRB(-96, -262, 96, 4);

  @override
  List<Offset> seats(KeepsakeTime k) {
    final a = _angle(k);
    final seatAt = Offset(math.sin(a) * _rope, _top + math.cos(a) * _rope);
    return [Offset(seatAt.dx, -seatAt.dy + 2)];
  }

  @override
  void body(Canvas c) {
    final post = StoneLight(const Color(0xFF8C96B4));
    for (final x in const [-82.0, 82.0]) {
      c.save();
      c.translate(x, 0);
      _plinth(c, post, 20, 8);
      c.restore();
      _shaft(c, post, x, -8, _top, 16, 12, lean: -x * 0.04);
    }
    _block(c, post, const Rect.fromLTRB(-90, _top - 8, 90, _top), bevel: 1.6);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final a = _angle(k);
    final dir = Offset(math.sin(a), math.cos(a));
    final n = Offset(dir.dy, -dir.dx);
    final seatAt = Offset(0, _top) + dir * _rope;
    final rope = StoneLight(const Color(0xFFB08A5A));
    for (final side in const [-22.0, 22.0]) {
      final top = Offset(side, _top);
      final end = seatAt + n * side;
      final w = n * 1.3;
      _solid(c, _poly([top - w, top + w, end + w, end - w]), rope.face);
    }
    final board = _poly([
      seatAt + n * 30 - dir * 2,
      seatAt + n * 30 + dir * 4,
      seatAt - n * 30 + dir * 4,
      seatAt - n * 30 - dir * 2,
    ]);
    _solid(c, board, rope.ink);
    _shade(c, board, _litAcross(rope, seatAt.dx - 30, seatAt.dx + 30, k: 0.5));
  }
}

/// A cloth roof on four posts. Under weather, the residents shelter here.
class _Canopy extends KeepsakeArt {
  _Canopy() : super(const Color(0xFFE8C88A));

  @override
  Rect get box => const Rect.fromLTRB(-150, -250, 150, 4);

  /// Where those sheltering stand, under it.
  @override
  List<Offset> seats(KeepsakeTime k) => const [
    Offset(-80, 0),
    Offset(0, 0),
    Offset(80, 0),
  ];

  @override
  void body(Canvas c) {
    final post = StoneLight(const Color(0xFF8C96B4));
    for (final x in const [-136.0, -96.0, 96.0, 136.0]) {
      _shaft(c, post, x, 2, -196, 14, 10);
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 150, 0.15 + 0.4 * k.night);
    paintDisc(c, m.pool, const Offset(0, -170), 90, 0.2 + 0.3 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    // The roof: cloth sagging between the posts, lifting in the wind.
    final lift = math.sin(k.t * 1.1) * 3 * (1 + k.stir);
    final roof = Path()
      ..moveTo(-148, -196)
      ..quadraticBezierTo(-74, -246 + lift, 0, -240 + lift)
      ..quadraticBezierTo(74, -246 + lift, 148, -196)
      ..quadraticBezierTo(74, -206 - lift, 0, -200 - lift)
      ..quadraticBezierTo(-74, -206 - lift, -148, -196)
      ..close();
    final cloth = StoneLight(const Color(0xFF9A6A4A));
    _solid(c, roof, cloth.ink);
    _shade(c, roof, _litAcross(cloth, -148, 148, k: 0.6));
    // A lantern hung under its ridge.
    paintDisc(c, m.pool, const Offset(0, -186), 40, 0.4 + 0.5 * k.night);
    paintOrb(c, m, Offset(0, -186 + lift * 0.5), 6);
  }
}

/// Mushrooms whose caps light as a resident hops across them.
class _MushroomRing extends KeepsakeArt {
  _MushroomRing() : super(const Color(0xFF9FF2C8));

  static const _caps = <(double, double, double)>[
    (-70, 34, 15),
    (-36, 48, 19),
    (0, 40, 16),
    (34, 54, 20),
    (68, 32, 14),
  ];

  @override
  Rect get box => const Rect.fromLTRB(-90, -80, 90, 4);

  @override
  void body(Canvas c) {
    final stalk = StoneLight(const Color(0xFFE6DCC8));
    for (final (x, h, w) in _caps) {
      _shaft(c, stalk, x, 0, -h + 4, w * 0.45, w * 0.32);
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) =>
      _groundPool(c, m, 0, 100, 0.25 + 0.45 * k.night);

  @override
  void live(Canvas c, KeepsakeTime k) {
    for (var i = 0; i < _caps.length; i++) {
      final (x, h, w) = _caps[i];
      // A light running along them, brighter as they are hopped.
      final run = (k.t * 0.6 - i * 0.2) % 1.0;
      final on = 0.35 + 0.65 * math.exp(-run * run * 30) + 0.5 * k.stir;
      final cap = Path()
        ..moveTo(x - w, -h + 6)
        ..quadraticBezierTo(x - w * 0.9, -h - w * 0.8, x, -h - w * 0.75)
        ..quadraticBezierTo(x + w * 0.9, -h - w * 0.8, x + w, -h + 6)
        ..quadraticBezierTo(x, -h + 1, x - w, -h + 6)
        ..close();
      _glass(c, m, cap, Offset(x, -h - w * 0.2), w * 2 * on.clamp(0.4, 1.6));
    }
  }
}

// ── Wonders ────────────────────────────────────────────────────────────────

/// A steaming pool in a ring of rocks. Up to three residents bathe in it,
/// sunk to their chests — the near water is drawn over them, faint enough
/// that what is under it still shows.
class _HotSpring extends KeepsakeArt {
  _HotSpring() : super(const Color(0xFF6FC4CC));

  final StoneLight _rock = StoneLight(const Color(0xFF8A8F9A));
  final _Grains _mist = _Grains(120);

  /// The water's surface, seen from a little above.
  static const _surface = Rect.fromLTRB(-182, -30, 182, 24);

  /// Milky turquoise: deep, the body of it, and where light lies on it.
  static const _deep = Color(0xFF0B2A31);
  static const _body = Color(0xFF2A6E74);
  static const _sheen = Color(0xFFB8E2DE);

  /// A soft round of steam, unit radius.
  static final ui.Shader _puff = ui.Gradient.radial(
    Offset.zero,
    1,
    const [Color(0x40F2FAF9), Color(0x18F2FAF9), Color(0x00F2FAF9)],
    const [0.0, 0.5, 1.0],
  );

  @override
  Rect get box => const Rect.fromLTRB(-200, -110, 200, 80);

  /// Where the bathers sit, down in the water to their chests.
  @override
  List<Offset> seats(KeepsakeTime k) => const [
    Offset(-100, -62),
    Offset(0, -68),
    Offset(100, -62),
  ];

  @override
  bool get hasFront => true;

  @override
  void body(Canvas c) {
    // The far rim of rocks, and the basin the water lies in.
    for (var i = 0; i < 8; i++) {
      final x = -178 + i * 51.0;
      _boulder(c, Offset(x, -22), 36 + 8 * math.sin(i * 1.7).abs(),
          18 + 9 * math.sin(i * 2.3).abs());
    }
    _solid(c, Path()..addOval(_surface.inflate(4)), _rock.ink);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 230, 0.3 + 0.5 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final water = Path()..addOval(_surface);
    c.save();
    c.clipPath(water);
    // The water: the far part giving back the light, the near part deep.
    _shade(
      c,
      Path()..addRect(_surface),
      ui.Gradient.linear(const Offset(0, -30), const Offset(0, 24), [
        _a(Color.lerp(_body, _sheen, 0.45 + 0.2 * k.daylight)!, 1),
        _a(_body, 1),
        _a(_deep, 1),
      ], const [0.0, 0.42, 1.0]),
    );
    // Its warmth showing from under it, more by night.
    paintDisc(c, m.pool, const Offset(0, -2), 170, 0.5 + 0.6 * k.night);
    // Light lying along it in slow bands.
    for (var i = 0; i < 4; i++) {
      final f = (k.t / (11 + i * 4) + i * 0.31) % 1.0;
      _solid(
        c,
        Path()
          ..addOval(Rect.fromCenter(
            center: Offset(-210 + f * 420, -20 + i * 10.0),
            width: 90 - i * 12,
            height: 3.2,
          )),
        _a(_sheen, 0.22 - 0.03 * i),
      );
    }
    // Ripples spreading from where the bathers sit (when someone is in
    // it), and now and then from a bubble coming up: crescents of light
    // that widen and fade — filled, never a drawn ring.
    void ripple(Offset at, double age, double strength) {
      if (age < 0 || age > 1) return;
      final r = 10 + 70 * age;
      final fade = (1 - age) * (1 - age) * strength;
      final band = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCenter(center: at, width: r * 2, height: r * 0.5))
        ..addOval(Rect.fromCenter(
          center: at + const Offset(0, 0.6),
          width: r * 2 - 5,
          height: r * 0.5 - 2.4,
        ));
      _solid(c, band, _a(_sheen, 0.22 * fade));
    }

    final busy = math.min(1.0, k.stir);
    for (final seat in const [-100.0, 0.0, 100.0]) {
      for (var j = 0; j < 3; j++) {
        ripple(Offset(seat, -2), ((k.t * 0.5 + j / 3 + seat * 0.003) % 1.0),
            busy);
      }
    }
    for (var i = 0; i < 3; i++) {
      final cycle = 4.2 + _hash(i, 4) * 3;
      final age = ((k.t + _hash(i, 5) * cycle) % cycle) / 1.2;
      final at = Offset((_hash(i, 6) - 0.5) * 300, -18 + _hash(i, 7) * 30);
      ripple(at, age, 0.45);
      // The bubble itself breaking, just before its ripple.
      if (age < 0.12) paintDisc(c, kGlint, at, 3.5, 0.6 * (1 - age / 0.12));
    }
    c.restore();
    _steam(c, k);
  }

  /// Steam rising off it in soft plumes that widen and lean as they go,
  /// a little fine mist in them.
  void _steam(Canvas c, KeepsakeTime k) {
    for (var i = 0; i < 12; i++) {
      final life = 4.5 + _hash(i, 1) * 2;
      final f = ((k.t + _hash(i, 2) * life) % life) / life;
      final x0 = (_hash(i, 3) - 0.5) * 320;
      final at = Offset(
        x0 + math.sin(k.t * 0.4 + i) * 10 * f + 30 * f * f,
        -14 - f * 170,
      );
      final rise = math.sin(math.pi * math.min(1.0, f * 1.2));
      paintDisc(c, _puff, at, 22 + 60 * f, (0.8 + 0.4 * k.night) * rise);
    }
    _mist.clear();
    for (var i = 0; i < 80; i++) {
      final f = (k.t * (0.07 + 0.05 * _hash(i, 1)) + _hash(i, 2)) % 1.0;
      final x = (_hash(i, 3) - 0.5) * 340 + math.sin(k.t * 0.6 + i) * 14 * f;
      _mist.add(x, -10 - f * 150);
    }
    _mist.draw(c, 2.2, _a(const Color(0xFFE9F4F4), 0.22));
  }

  @override
  void front(Canvas c, KeepsakeTime k) {
    // The near water over the bathers, down to the stone: clear enough at
    // its top that what is under it shows, deeper as it goes down; its edge
    // lit where it laps round them.
    final lap = math.sin(k.t * 1.3) * 1.2;
    final near = Path()
      ..moveTo(-182, -2)
      ..quadraticBezierTo(0, 30 + lap, 182, -2)
      ..lineTo(176, 40)
      ..quadraticBezierTo(0, 70, -176, 40)
      ..close();
    _shade(
      c,
      near,
      ui.Gradient.linear(const Offset(0, -4), const Offset(0, 60), [
        _a(_body, 0.6),
        _a(_deep, 0.96),
      ], const [0.0, 0.7]),
    );
    // The waterline, where it meets them: a lit edge that moves with it.
    final edge = Path()
      ..moveTo(-182, -2)
      ..quadraticBezierTo(0, 30 + lap, 182, -2)
      ..quadraticBezierTo(0, 33 + lap, -182, 1.2)
      ..close();
    _solid(c, edge, _a(_sheen, 0.45));
    // The near wall of the basin: stones set to the water's front, down
    // over whatever sits in it.
    for (var i = 0; i < 7; i++) {
      final x = -162 + i * 54.0 + (i.isEven ? 0 : 6);
      _boulder(c, Offset(x, 74), 50 + 8 * math.sin(i * 1.3).abs(),
          40 + 8 * math.sin(i * 2.1).abs());
    }
  }

  /// A rounded rock sitting at [foot], [w] across and [h] high.
  void _boulder(Canvas c, Offset foot, double w, double h) {
    final rock = Path()
      ..moveTo(foot.dx - w / 2, foot.dy)
      ..cubicTo(foot.dx - w / 2, foot.dy - h * 0.9, foot.dx - w * 0.2,
          foot.dy - h * 1.05, foot.dx + w * 0.08, foot.dy - h)
      ..cubicTo(foot.dx + w * 0.4, foot.dy - h * 0.95, foot.dx + w / 2,
          foot.dy - h * 0.5, foot.dx + w / 2, foot.dy)
      ..close();
    _solid(c, rock, _rock.ink);
    _shade(c, rock, _litAcross(_rock, foot.dx - w / 2, foot.dx + w / 2, k: 0.45));
  }
}

/// A great tree of grains: a trunk of dark bark, its crown grains of
/// leaf that shimmer. The residents climb into its branches and sleep
/// there; flyers roost at its top.
class _ElderTree extends KeepsakeArt {
  _ElderTree() : super(const Color(0xFFB8E68A));

  final StoneLight _bark = StoneLight(const Color(0xFF9A7A5A));
  final _Grains _leaves = _Grains(900);
  final _Grains _under = _Grains(900);
  final _Grains _lit = _Grains(320);

  static const _branches = <(Offset, Offset, double)>[
    (Offset(-6, -200), Offset(-120, -250), 16),
    (Offset(4, -270), Offset(112, -318), 14),
    (Offset(-2, -340), Offset(-60, -400), 11),
  ];

  @override
  Rect get box => const Rect.fromLTRB(-210, -560, 210, 8);

  /// On each branch, and at the top.
  @override
  List<Offset> seats(KeepsakeTime k) => const [
    Offset(-100, 246),
    Offset(96, 314),
    Offset(-50, 398),
  ];

  @override
  void body(Canvas c) {
    // Roots, the trunk, and the branches.
    final trunk = Path()
      ..moveTo(-44, 4)
      ..quadraticBezierTo(-20, -60, -24, -200)
      ..quadraticBezierTo(-12, -330, -4, -430)
      ..lineTo(10, -430)
      ..quadraticBezierTo(18, -330, 22, -200)
      ..quadraticBezierTo(22, -60, 48, 4)
      ..close();
    _solid(c, trunk, _bark.ink);
    _shade(c, trunk, _litAcross(_bark, -44, 48, k: 0.5));
    for (final (a, b, w) in _branches) {
      final d = b - a;
      final n = Offset(-d.dy, d.dx) / d.distance;
      final branch = _poly([a + n * w, b + n * w * 0.35, b - n * w * 0.35, a - n * w]);
      _solid(c, branch, _bark.ink);
      _shade(c, branch, _litAcross(_bark, math.min(a.dx, b.dx), math.max(a.dx, b.dx), k: 0.4));
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, const Offset(0, -380), 200, 0.25 + 0.3 * k.night);
    _groundPool(c, m, 0, 200, 0.15 + 0.3 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    _leaves.clear();
    _under.clear();
    _lit.clear();
    // The crown: grains in soft masses over the branches, dense enough to
    // be a crown — shaded under, lit toward the key light, a few glowing.
    const masses = <(Offset, double, double)>[
      (Offset(-120, -290), 120, 78),
      (Offset(110, -360), 120, 78),
      (Offset(-30, -450), 170, 100),
      (Offset(30, -390), 110, 70),
    ];
    for (var i = 0; i < 1500; i++) {
      final (mid, rx, ry) = masses[i % 4];
      final a = _hash(i, 1) * math.pi * 2;
      final r = math.sqrt(_hash(i, 2));
      final sway = math.sin(k.t * 0.9 + i * 0.05) * 3 * (1 + k.stir);
      final at =
          mid + Offset(math.cos(a) * rx * r + sway * r, math.sin(a) * ry * r);
      // Lit on its upper left, shaded under.
      final lit = -math.cos(a) * 0.55 - math.sin(a) * 0.8;
      if (_hash(i, 3) < 0.14) {
        _lit.add(at.dx, at.dy);
      } else if (lit * r > 0.1) {
        _leaves.add(at.dx, at.dy);
      } else {
        _under.add(at.dx, at.dy);
      }
    }
    _under.draw(c, 7, const Color(0xFF22381F));
    _leaves.draw(c, 6.5, const Color(0xFF3F6A36));
    final glow = 0.55 + 0.35 * k.night;
    _lit.draw(c, 4.5, _a(m.grainHot, glow));
  }
}

/// A low stage of obsidian, a lit sign in its floor and a lamp at each
/// end. One resident performs; the others gather to watch.
class _Stage extends KeepsakeArt {
  _Stage() : super(const Color(0xFFFFD27A));

  @override
  Rect get box => const Rect.fromLTRB(-200, -170, 200, 4);

  /// The performer on it; those watching stand either side, on the ground.
  @override
  List<Offset> seats(KeepsakeTime k) => const [
    Offset(0, 46),
    Offset(-250, 0),
    Offset(250, 0),
  ];

  @override
  void body(Canvas c) {
    final stone = StoneLight(const Color(0xFF8C96B4));
    _block(c, stone, const Rect.fromLTRB(-180, -46, 180, 0), bevel: 4);
    _block(c, stone, const Rect.fromLTRB(-196, -14, 196, 0), bevel: 2);
    for (final x in const [-170.0, 170.0]) {
      _shaft(c, stone, x, -46, -156, 13, 9);
    }
    // The sign in its floor: a ring and its four points, filled.
    final sign = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCenter(center: const Offset(0, -44), width: 150, height: 10))
      ..addOval(Rect.fromCenter(center: const Offset(0, -44), width: 120, height: 6));
    _solid(c, sign, _a(m.hot, 0.7));
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 220, 0.25 + 0.45 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    for (final x in const [-170.0, 170.0]) {
      paintDisc(c, m.pool, Offset(x, -160), 46, 0.5 + 0.5 * k.night);
      _flame(
        c,
        Offset(x, -158),
        22 + 8 * k.stir,
        10,
        k.t,
        x.toInt(),
        core: const Color(0xFFFFF1C8),
        body: const Color(0xFFFFB04A),
      );
    }
    // The light on the boards, warmer when someone is on them.
    paintDisc(c, m.leak, const Offset(0, -50), 120, 0.15 + 0.35 * k.stir);
  }
}

/// A ring of glass and gold turning slowly about a pillar, a seat on it
/// that a resident rides round.
class _Orrery extends KeepsakeArt {
  _Orrery() : super(_gold);

  static const _hub = Offset(0, -150);
  static const _rx = 160.0, _ry = 42.0;
  final StoneLight _glassLight = StoneLight(const Color(0xFFB9A2FF));

  double _turn(KeepsakeTime k) => k.t * (0.32 + 0.4 * math.min(1.0, k.stir));

  @override
  Rect get box => const Rect.fromLTRB(-196, -250, 196, 4);

  /// The rider's seat, where the ring has carried it.
  @override
  List<Offset> seats(KeepsakeTime k) {
    final a = _turn(k);
    final at = _hub + Offset(math.cos(a) * _rx, math.sin(a) * _ry);
    return [Offset(at.dx, -at.dy + 2)];
  }

  @override
  void body(Canvas c) {
    _plinth(c, m, 80, 16, steps: 3);
    _shaft(c, StoneLight(const Color(0xFF8C96B4)), 0, -16, -150, 18, 10);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, _hub, 180, 0.25 + 0.35 * k.night);
  }

  void _ringHalf(Canvas c, KeepsakeTime k, bool back) {
    const n = 22;
    for (var i = 0; i < n; i++) {
      final a0 = i / n * math.pi * 2, a1 = (i + 1) / n * math.pi * 2;
      final mid = (a0 + a1) / 2;
      if ((math.sin(mid) < 0) != back) continue;
      Offset at(double a, double k) =>
          _hub + Offset(math.cos(a) * (_rx + k), math.sin(a) * (_ry + k * 0.3));
      final seg = _poly([at(a0, -5), at(a1, -5), at(a1, 5), at(a0, 5)]);
      _solid(c, seg, m.ink);
      _shade(
        c,
        seg,
        ui.Gradient.linear(at(mid, -5), at(mid, 5), [
          Color.lerp(m.face, m.rim, back ? 0.25 : 0.6)!,
          m.face,
        ]),
      );
    }
    // The glass worlds on it, turning with it.
    for (var j = 0; j < 3; j++) {
      final a = _turn(k) + 1.3 + j * 1.6;
      if ((math.sin(a) < 0) != back) continue;
      paintOrb(
        c,
        j == 1 ? m : _glassLight,
        _hub + Offset(math.cos(a) * _rx, math.sin(a) * _ry - 10),
        9 + math.sin(a) * 2,
      );
    }
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    _ringHalf(c, k, true);
    paintOrb(c, m, _hub + const Offset(0, -14), 16);
  }

  @override
  bool get hasFront => true;

  @override
  void front(Canvas c, KeepsakeTime k) {
    _ringHalf(c, k, false);
    // The seat, a little gold cradle where the ring carries it.
    final a = _turn(k);
    final at = _hub + Offset(math.cos(a) * _rx, math.sin(a) * _ry);
    final cradle = _poly([
      at + const Offset(-24, 2),
      at + const Offset(24, 2),
      at + const Offset(16, 10),
      at + const Offset(-16, 10),
    ]);
    _solid(c, cradle, m.ink);
    _shade(c, cradle, _litAcross(m, at.dx - 24, at.dx + 24, k: 0.7));
  }
}

/// Still water in a low rim of stone, giving back the sky — brightest at
/// its far edge, where water gives back most — and whoever stands at its
/// edge, upside down.
class _ReflectingPool extends KeepsakeArt {
  _ReflectingPool() : super(const Color(0xFFB8C8F0));

  final _Grains _stars = _Grains(40);
  static const _water = Rect.fromLTRB(-176, -8, 176, 56);
  static const _rim = Rect.fromLTRB(-196, -20, 196, 68);

  @override
  Rect get box => const Rect.fromLTRB(-200, -36, 200, 72);

  /// Where a looker stands: at either end, on the rim, looking in.
  @override
  List<Offset> seats(KeepsakeTime k) => const [
    Offset(-226, 0),
    Offset(226, 0),
  ];

  @override
  Rect get mirror => _water;

  @override
  void body(Canvas c) {
    final stone = StoneLight(const Color(0xFF8C96B4));
    final rim = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(_rim)
      ..addOval(_water);
    _solid(c, rim, stone.ink);
    _shade(c, rim, _litAcross(stone, -196, 196, k: 0.45));
    // The rim's far lip catching the light.
    final lip = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(const Rect.fromLTRB(-194, -20, 194, 32))
      ..addOval(const Rect.fromLTRB(-178, -10, 178, 38));
    c.save();
    c.clipRect(const Rect.fromLTRB(-200, -28, 200, 8));
    _shade(
      c,
      lip,
      ui.Gradient.linear(const Offset(-180, 0), const Offset(180, 0), [
        _a(stone.rim, 0.35),
        _a(stone.rim, 0.08),
      ]),
    );
    c.restore();
  }

  @override
  void under(Canvas c, KeepsakeTime k) =>
      _groundPool(c, m, 0, 200, 0.15 + 0.3 * k.night);

  @override
  void live(Canvas c, KeepsakeTime k) {
    final water = Path()..addOval(_water);
    c.save();
    c.clipPath(water);
    // Deep water, and the sky in it: day blue-white, night the moon's grey
    // violet — strongest at the far edge.
    final day = k.daylight;
    final sky = Color.lerp(const Color(0xFF6E7FB8), const Color(0xFFB9D3F0), day)!;
    _solid(c, water, Color.lerp(const Color(0xFF070A14), const Color(0xFF16263A), day)!);
    _shade(
      c,
      Path()..addRect(_water),
      ui.Gradient.linear(const Offset(0, -8), const Offset(0, 56), [
        _a(sky, 0.55 + 0.15 * day),
        _a(sky, 0.18),
        _a(sky, 0.04),
      ], const [0.0, 0.45, 1.0]),
    );
    // Reflected light drifting across in long slow streaks, broken by a
    // ripple when something stirs it.
    for (var i = 0; i < 4; i++) {
      final f = (k.t / (14 + i * 3) + i * 0.27) % 1.0;
      final y = 4 + i * 11.0;
      final wob = math.sin(k.t * 2.4 + i) * 3 * k.stir;
      _solid(
        c,
        Path()
          ..addOval(Rect.fromCenter(
            center: Offset(-200 + f * 400 + wob, y),
            width: 70 - i * 8,
            height: 3.4,
          )),
        _a(const Color(0xFFFFFFFF), 0.08 + 0.1 * day),
      );
    }
    // At night, the stars given back, and the moon's glint.
    if (k.night > 0.05) {
      _stars.clear();
      for (var i = 0; i < 30; i++) {
        final x = (_hash(i, 1) - 0.5) * 320;
        final y = -4 + _hash(i, 2) * 56;
        if (math.sin(k.t * (0.8 + _hash(i, 3)) + i) > 0.2) _stars.add(x, y);
      }
      _stars.draw(c, 1.8, _a(const Color(0xFFDDE6FF), 0.6 * k.night));
      paintDisc(c, kGlint, const Offset(40, 10), 12, 0.35 * k.night);
    }
    c.restore();
  }
}
