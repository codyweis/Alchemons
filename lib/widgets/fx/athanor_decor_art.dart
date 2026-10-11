part of 'keepsake_art.dart';

// The Athanor's home decor (docs/crucible/cosmetics_concepts.md): drawn from
// a batch at the furnace and found nowhere else. The same units and kit as
// the bought decor (decor_art.dart) — 100 is a creature's size on its row
// before the field's ×0.62, so a creature is about 140 of these; feet at the
// origin, y down. Each batch is one material:
//
//   the Black Work    black glass and ink, lit violet
//   the White Work    moonstone, silver, frost
//   the Yellow Work   pale brass, gold leaf, honey glass
//   the Red Work      garnet glass and embers
//   the Still-Room    ink, brass and clear glass: the workshop

KeepsakeArt? _athanorDecorArt(String id) => switch (id) {
  // The Black Work
  'moth_lantern' => _MothLantern(),
  'inkcap_cluster' => _InkcapCluster(),
  'ash_brazier' => _AshBrazier(),
  'nightbloom_bed' => _NightbloomBed(),
  // The White Work
  'moonstone_cairn' => _MoonstoneCairn(),
  'salt_pillar' => _SaltPillar(),
  'moon_font' => _MoonFont(),
  'snow_globe' => _SnowGlobe(),
  // The Yellow Work
  'sundial' => _Sundial(),
  'honey_lamp' => _HoneyLamp(),
  'storm_coil' => _StormCoil(),
  'gilded_throne' => _GildedThrone(),
  // The Red Work
  'glass_rose' => _GlassRose(),
  'ember_bowl' => _EmberBowl(),
  'ember_nest' => _EmberNest(),
  'pomegranate_tree' => _PomegranateTree(),
  // The Still-Room
  'herb_rack' => _HerbRack(),
  'retort_shelf' => _RetortShelf(),
  'alembic' => _Alembic(),
  'bell_jar' => _BellJar(),
  'music_box' => _MusicBox(),
  'great_alembic' => _GreatAlembic(),
  _ => null,
};

// ── The kit's additions ─────────────────────────────────────────────────────

double _frac(double x) => x - x.floorToDouble();

double _smooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Pale brass, the palette's accent (ForgeTokens.amberBright).
const Color _kBrass = Color(0xFFCDB07A);

/// The bought decor's plain obsidian, lit a little blue-grey.
const Color _kStone = Color(0xFF8C96B4);

/// Polished brass across [x0] to [x1]: bright where it turns to the key
/// light, dark where it turns away — trim that should read as metal.
ui.Shader _polishedBrass(double x0, double x1) => ui.Gradient.linear(
  Offset(x0, 0),
  Offset(x1, 0),
  const [
    Color(0xFF5E4A24),
    Color(0xFFE6CB8A),
    Color(0xFF9A7A40),
    Color(0xFF3E3018),
    Color(0xFF6E5A30),
  ],
  const [0.0, 0.22, 0.5, 0.8, 1.0],
);

/// An ARGB int from 0xRRGGBB and an alpha.
int _argb(int rgb, double alpha) =>
    ((alpha.clamp(0.0, 1.0) * 255).round() << 24) | (rgb & 0xFFFFFF);

/// Between two 0xRRGGBB colors.
int _mix(int a, int b, double t) {
  final k = t.clamp(0.0, 1.0);
  int ch(int s) {
    final x = (a >> s) & 0xFF, y = (b >> s) & 0xFF;
    return (x + (y - x) * k).round() & 0xFF;
  }

  return (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// Clear glass over whatever is in it: faint through the middle, catching
/// the light toward its edge, and the window it gives back, a soft crescent
/// on its upper left.
void _clearGlass(
  Canvas c,
  Path glass,
  Rect bounds, {
  double alpha = 1,
  bool window = true,
}) {
  _shade(
    c,
    glass,
    ui.Gradient.radial(
      bounds.center + Offset(-bounds.width * 0.18, -bounds.height * 0.2),
      math.max(bounds.width, bounds.height) * 0.7,
      const [
        Color(0x10FFFFFF),
        Color(0x0AB6E2FF),
        Color(0x30B6E2FF),
        Color(0x60DDF2FF),
      ],
      const [0.0, 0.6, 0.88, 1.0],
    ),
    alpha,
  );
  if (!window) return;
  final r = bounds.width / 2;
  _solid(
    c,
    vfxCrescent(bounds.center, r * 0.86, r * 0.16, -2.3, 1.1),
    _a(const Color(0xFFFFFFFF), 0.25 * alpha),
  );
}

/// Triangles with a color at every corner, gathered over a frame and drawn
/// with one drawVertices: many small filled shapes (petals) for one draw.
class _Tris {
  _Tris(int cap) : _xy = Float32List(cap * 6), _col = Int32List(cap * 3);
  final Float32List _xy;
  final Int32List _col;
  int _n = 0;

  static final Paint _paint = Paint()..isAntiAlias = true;

  void clear() => _n = 0;

  void add(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
    int ca,
    int cb,
    int cc,
  ) {
    if ((_n + 1) * 6 > _xy.length) return;
    final i = _n * 6;
    _xy[i] = ax;
    _xy[i + 1] = ay;
    _xy[i + 2] = bx;
    _xy[i + 3] = by;
    _xy[i + 4] = cx;
    _xy[i + 5] = cy;
    final j = _n * 3;
    _col[j] = ca;
    _col[j + 1] = cb;
    _col[j + 2] = cc;
    _n++;
  }

  /// A quad a-b-c-d as two triangles, each corner its own ARGB.
  void quad(
    Offset a,
    Offset b,
    Offset cc,
    Offset d,
    int ca,
    int cb,
    int ccol,
    int cd,
  ) {
    add(a.dx, a.dy, b.dx, b.dy, cc.dx, cc.dy, ca, cb, ccol);
    add(a.dx, a.dy, cc.dx, cc.dy, d.dx, d.dy, ca, ccol, cd);
  }

  void draw(Canvas c) {
    if (_n == 0) return;
    final v = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.sublistView(_xy, 0, _n * 6),
      colors: Int32List.sublistView(_col, 0, _n * 3),
    );
    c.drawVertices(v, BlendMode.dst, _paint);
    v.dispose();
    _n = 0;
  }
}

/// A cupped flower seen from the side, its petals into [tris]: shut it is a
/// bud pointing up, open ([open] 1) its petals part into a cup and their
/// tips curl out. Each flower leans its own way, so none is a star.
void _cupFlower(
  _Tris tris,
  Offset head,
  double up,
  double size,
  double open,
  int seed, {
  required int heart,
  required int face,
  required int tip,
  required int shade,
  List<double> spreads = const [0.0, -0.32, 0.36, -0.72, 0.78],
  List<double> lengths = const [0.78, 0.92, 0.95, 1.0, 0.96],
  double length = 34,
  double width = 6,
  double widen = 5,
}) {
  for (var p = 0; p < spreads.length; p++) {
    final skew = (_hash(seed * 7 + p, 21) - 0.5) * 0.25;
    final a = up + (spreads[p] + skew) * (0.12 + 0.88 * open);
    final len = length * size * lengths[p] * (0.8 + 0.25 * open);
    final w = (width + widen * open) * size * (p == 0 ? 0.8 : 1.0);
    final curl = (spreads[p] == 0 ? 0 : spreads[p].sign) * 0.55 * open;
    final far = p == 0 ? 0.0 : (p < 3 ? 0.55 : 1.0);
    final heartRgb = _mix(shade, heart, open * (0.5 + 0.35 * far));
    final faceRgb = _mix(shade, face, 0.3 + 0.5 * far);
    final tipRgb = _mix(shade, tip, 0.2 + 0.55 * open * far + 0.25 * far);
    Offset spine(double g) {
      final aa = a + curl * g * g;
      return head +
          Offset(math.cos(a), math.sin(a)) * len * g * 0.6 +
          Offset(math.cos(aa), math.sin(aa)) * len * g * 0.4;
    }

    Offset side(double g, double sgn) {
      final q = spine(g), nq = spine(math.min(1.0, g + 0.05));
      var d = nq - q;
      d = d / math.max(d.distance, 1e-4);
      final hw = w * math.sin(math.pi * math.pow(g, 0.75)) * (1 - 0.25 * g);
      return q + Offset(-d.dy, d.dx) * hw * sgn;
    }

    // Lit along its left edge (the key light's side), shadowed along its
    // right.
    int colAt(double g, double sgn) {
      final along = g < 0.5
          ? _mix(heartRgb, faceRgb, g / 0.5)
          : _mix(faceRgb, tipRgb, (g - 0.5) / 0.5);
      return _argb(
        sgn > 0 ? _mix(along, 0x05030A, 0.35) : _mix(along, tipRgb, 0.25 * g),
        1,
      );
    }

    const gs = [0.0, 0.33, 0.66, 1.0];
    for (var j = 0; j < 3; j++) {
      final g0 = gs[j], g1 = gs[j + 1];
      tris.quad(
        side(g0, 1),
        side(g1, 1),
        side(g1, -1),
        side(g0, -1),
        colAt(g0, 1),
        colAt(g1, 1),
        colAt(g1, -1),
        colAt(g0, -1),
      );
    }
  }
}

// ═══ THE BLACK WORK ═══════════════════════════════════════════════════════

/// A dim violet lamp hung from a crooked post. At night moths come in to
/// it, settle on the glass a while, and lift away again.
class _MothLantern extends KeepsakeArt {
  _MothLantern() : super(const Color(0xFFB48CFF));

  static const _lamp = Offset(24, -140);
  final StoneLight _post = StoneLight(_kStone);
  final Path _wings = Path();

  /// Where a moth comes to rest: on the glass, the cap, the post.
  static const _spots = [
    Offset(18, -150),
    Offset(30, -132),
    Offset(22, -164),
    Offset(-4, -112),
    Offset(28, -146),
    Offset(16, -128),
    Offset(-8, -150),
  ];

  @override
  Rect get box => const Rect.fromLTRB(-30, -192, 46, 4);

  static final Path _glassPath = _poly(const [
    Offset(17, -158),
    Offset(31, -158),
    Offset(34, -140),
    Offset(30, -124),
    Offset(18, -124),
    Offset(14, -140),
  ]);

  @override
  void body(Canvas c) {
    _plinth(c, _post, 30, 8);
    // The post, crooked: leaning one way below its knuckle, the other above.
    _shaft(c, _post, 0, -8, -96, 13, 10, lean: -7);
    _shaft(c, _post, -7, -94, -172, 10, 8, lean: 9);
    _block(c, _post, const Rect.fromLTRB(-13, -100, -1, -92), bevel: 1.2);
    // The crook it hangs from, out over the lamp.
    final crook = vfxRibbon(
      const [
        Offset(0, -172),
        Offset(12, -180),
        Offset(22, -178),
        Offset(25, -170),
      ],
      7,
      4.6,
    );
    _solid(c, crook, _post.ink);
    _shade(c, crook, _litAcross(_post, 0, 26, k: 0.6));
    // The lamp's cap and foot.
    final cap = _poly(const [
      Offset(12, -158),
      Offset(36, -158),
      Offset(30, -166),
      Offset(18, -166),
    ]);
    _solid(c, cap, _post.ink);
    _shade(c, cap, _litAcross(_post, 12, 36, k: 0.5));
    _block(c, _post, const Rect.fromLTRB(16, -124, 32, -119), bevel: 1.2);
    _block(c, _post, const Rect.fromLTRB(22, -170, 26, -166), bevel: 0.8);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    final on = 0.2 + 0.8 * k.night;
    paintDisc(c, m.pool, _lamp, 64, 0.75 * on);
    _groundPool(c, m, 10, 64, 0.5 * on);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final on = 0.25 + 0.75 * k.night;
    final flick = 0.88 + 0.12 * math.sin(k.t * 5.1) * math.sin(k.t * 1.7);
    _glass(c, m, _glassPath, _lamp, 24 * (0.6 + 0.4 * on));
    paintDisc(c, m.spark, _lamp, 8 * flick, 0.85 * on);
    if (k.night < 0.05) return;
    _moths(c, k);
  }

  /// Moths, each on its own clock: in from the dark, a while on the lamp
  /// with its wings slowly opening and closing, then away.
  void _moths(Canvas c, KeepsakeTime k) {
    for (var i = 0; i < _spots.length; i++) {
      final period = 9 + 6 * _hash(i, 1);
      final f = _frac(k.t / period + _hash(i, 2));
      final spot = _spots[i];
      final away =
          _lamp +
          polar(110 + 50 * _hash(i, 3), -math.pi * (0.15 + 0.7 * _hash(i, 4)));
      final away2 =
          _lamp +
          polar(110 + 50 * _hash(i, 5), -math.pi * (0.1 + 0.8 * _hash(i, 6)));
      Offset at;
      double spread;
      if (f < 0.3) {
        final e = _smooth(0, 1, f / 0.3);
        at =
            Offset.lerp(away, spot, e)! +
            Offset(
              math.sin(k.t * 3.1 + i) * 16 * (1 - e),
              math.cos(k.t * 2.3 + i * 2) * 10 * (1 - e),
            );
        spread = 0.5 + 0.5 * math.sin(k.t * 34 + i);
      } else if (f < 0.78) {
        at = spot;
        spread = 0.2 + 0.25 * (0.5 + 0.5 * math.sin(k.t * 1.3 + i * 2));
      } else {
        final e = _smooth(0, 1, (f - 0.78) / 0.22);
        at =
            Offset.lerp(spot, away2, e)! +
            Offset(math.sin(k.t * 2.7 + i) * 14 * e, 0);
        spread = 0.5 + 0.5 * math.sin(k.t * 31 + i * 3);
      }
      final alpha = k.night * _smooth(0, 0.06, f) * (1 - _smooth(0.94, 1, f));
      if (alpha < 0.02) continue;
      // Two wings off a small body, lit by the lamp on the side toward it.
      final s = 5.5 + 2 * _hash(i, 7);
      _wings.reset();
      for (final side in const [-1.0, 1.0]) {
        final tip =
            at +
            Offset(side * s * (0.6 + 0.7 * spread), -s * (0.9 - 0.6 * spread));
        final back = at + Offset(side * s * (0.5 + 0.4 * spread), s * 0.35);
        _wings.addPolygon([
          at + Offset(0, -s * 0.2),
          tip,
          back,
          at + Offset(0, s * 0.3),
        ], true);
      }
      _solid(c, _wings, _a(const Color(0xFFB9AACF), 0.8 * alpha));
      _solid(
        c,
        Path()..addOval(
          Rect.fromCenter(center: at, width: s * 0.36, height: s * 0.9),
        ),
        _a(const Color(0xFF2A2238), alpha),
      );
    }
  }
}

/// Tall ink-cap mushrooms of dark glass. Their caps' ragged edges drip ink
/// — more by night — into small pools that spread and fade.
class _InkcapCluster extends KeepsakeArt {
  _InkcapCluster() : super(const Color(0xFF9A7CFF));

  /// (x, height to the cap's top, cap width, lean).
  static const _caps = <(double, double, double, double)>[
    (-38, 46, 11, -0.22),
    (-22, 78, 15, -0.08),
    (-2, 112, 18, 0.02),
    (18, 90, 16, 0.1),
    (34, 56, 12, 0.2),
  ];

  final StoneLight _stem = StoneLight(const Color(0xFFB9B0CC));
  final StoneLight _ink = StoneLight(const Color(0xFF9A7CFF));
  final _Grains _drips = _Grains(20);
  final _Grains _lit = _Grains(20);

  @override
  Rect get box => const Rect.fromLTRB(-54, -122, 52, 6);

  Offset _top(int i) {
    final (x, h, _, lean) = _caps[i];
    return Offset(x + lean * h, -h);
  }

  /// The ragged foot of cap [i]'s bell, where the ink gathers.
  Offset _foot(int i, double side) {
    final (_, _, w, _) = _caps[i];
    final t = _top(i);
    return t + Offset(side * w * 0.62, w * 2.5);
  }

  @override
  void body(Canvas c) {
    for (var i = 0; i < _caps.length; i++) {
      final (x, h, w, lean) = _caps[i];
      final t = _top(i);
      final stem = vfxRibbon(
        [
          Offset(x, 2),
          Offset(x + lean * h * 0.5, -h * 0.5),
          t + Offset(0, w * 2),
        ],
        w * 0.42,
        w * 0.3,
      );
      _solid(c, stem, _stem.ink);
      _shade(c, stem, _litAcross(_stem, x - w * 0.4, x + w * 0.4, k: 0.9));
      // The bell: a tall dome, its foot torn into drips.
      final bh = w * 2.5;
      final bell = Path()..moveTo(t.dx - w * 0.62, t.dy + bh);
      bell.cubicTo(
        t.dx - w * 0.7,
        t.dy + bh * 0.3,
        t.dx - w * 0.45,
        t.dy - 2,
        t.dx,
        t.dy,
      );
      bell.cubicTo(
        t.dx + w * 0.45,
        t.dy - 2,
        t.dx + w * 0.7,
        t.dy + bh * 0.3,
        t.dx + w * 0.62,
        t.dy + bh,
      );
      const n = 7;
      for (var j = n; j >= 0; j--) {
        final fx = -0.62 + 1.24 * j / n;
        final down = j.isOdd ? 3.0 + 3 * _hash(i * 9 + j, 4) : 0.0;
        bell.lineTo(t.dx + fx * w, t.dy + bh + down);
      }
      bell.close();
      _solid(c, bell, _ink.ink);
      _shade(
        c,
        bell,
        ui.Gradient.linear(
          t + Offset(-w * 0.7, 0),
          t + Offset(w * 0.7, 0),
          [Color.lerp(_ink.face, _ink.rim, 0.42)!, _ink.face, _ink.ink],
          const [0.0, 0.4, 1.0],
        ),
      );
      // Its scales: a few darker flecks in rows down the bell.
      for (var j = 0; j < 6; j++) {
        final fy = 0.25 + 0.12 * j;
        final fx = (j.isEven ? -0.25 : 0.15) + 0.1 * _hash(i, j);
        _solid(
          c,
          vfxCrescent(
            t + Offset(fx * w, fy * bh),
            w * 0.16,
            w * 0.08,
            0.6,
            1.6,
          ),
          _a(const Color(0xFF05030A), 0.55),
        );
      }
      // The lit top of the dome.
      _solid(
        c,
        vfxCrescent(t + Offset(0, w * 0.9), w * 0.62, w * 0.12, -2.4, 1.1),
        _a(_ink.rim, 0.35),
      );
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 70, 0.15 + 0.4 * k.night);
    for (var i = 0; i < _caps.length; i++) {
      paintDisc(
        c,
        m.leak,
        _top(i) + Offset(0, _caps[i].$3 * 1.2),
        _caps[i].$3 * 2.2,
        0.1 + 0.35 * k.night,
      );
    }
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    _drips.clear();
    _lit.clear();
    // Two drips a cap, each on its own clock; by day most are idle.
    for (var i = 0; i < _caps.length; i++) {
      for (var j = 0; j < 2; j++) {
        final seed = i * 2 + j;
        if (_hash(seed, 9) > 0.3 + 0.7 * k.night + 0.4 * k.stir) continue;
        final period = 4.5 + 3 * _hash(seed, 1);
        final f = _frac(k.t / period + _hash(seed, 2));
        final from = _foot(i, j == 0 ? -0.7 : 0.55);
        if (f < 0.55) {
          // Gathering at the edge: a bead swelling.
          final r = 1.6 + 3.4 * _smooth(0, 1, f / 0.55);
          _solid(
            c,
            vfxDrop(from + Offset(0, r * 0.6), r, math.pi / 2),
            _a(const Color(0xFF120A1E), 0.95),
          );
          _lit.add(from.dx - r * 0.3, from.dy + r * 0.3);
        } else if (f < 0.7) {
          // Falling.
          final g = (f - 0.55) / 0.15;
          final y = from.dy + (0 - from.dy) * g * g;
          _solid(
            c,
            vfxDrop(Offset(from.dx, y), 4, math.pi / 2),
            _a(const Color(0xFF120A1E), 0.95),
          );
          _lit.add(from.dx - 1, y - 1);
        } else {
          // A small pool, spreading and fading.
          final g = (f - 0.7) / 0.3;
          final w = 6 + 16 * _smooth(0, 1, g * 2);
          final fade = 1 - _smooth(0.4, 1, g);
          _solid(
            c,
            Path()..addOval(
              Rect.fromCenter(
                center: Offset(from.dx, 1),
                width: w,
                height: w * 0.22,
              ),
            ),
            _a(const Color(0xFF0C0716), 0.9 * fade),
          );
          _solid(
            c,
            Path()..addOval(
              Rect.fromCenter(
                center: Offset(from.dx - w * 0.1, 0.4),
                width: w * 0.5,
                height: w * 0.07,
              ),
            ),
            _a(m.rim, 0.35 * fade),
          );
        }
      }
    }
    _lit.draw(c, 2.2, _a(m.rim, 0.85));
  }
}

/// A low bowl of obsidian holding a cold violet flame, ash rising off it.
/// The residents warm themselves at it, and by night sleep beside it.
class _AshBrazier extends KeepsakeArt {
  _AshBrazier() : super(const Color(0xFF9A6CFF));

  static const _rim = -58.0;
  final StoneLight _stone = StoneLight(_kStone);
  final _Grains _ash = _Grains(40);
  final _Grains _ashHi = _Grains(40);

  @override
  Rect get box => const Rect.fromLTRB(-70, -176, 70, 4);

  /// Where those warming themselves stand, clear of the bowl.
  @override
  List<Offset> seats(KeepsakeTime k) => const [Offset(-118, 0), Offset(118, 0)];

  @override
  void body(Canvas c) {
    _plinth(c, _stone, 64, 9);
    _shaft(c, _stone, 0, -9, -26, 26, 18);
    final bowl = _poly(const [
      Offset(-66, _rim),
      Offset(66, _rim),
      Offset(54, -38),
      Offset(30, -24),
      Offset(-30, -24),
      Offset(-54, -38),
    ]);
    _solid(c, bowl, m.ink);
    _shade(c, bowl, _litAcross(m, -66, 66, k: 0.55));
    _glass(
      c,
      m,
      _poly(const [
        Offset(-66, _rim),
        Offset(66, _rim),
        Offset(58, _rim + 6),
        Offset(-58, _rim + 6),
      ]),
      const Offset(0, _rim),
      60,
    );
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    final flick = 0.88 + 0.12 * math.sin(k.t * 5.3) * math.sin(k.t * 2.2);
    _groundPool(c, m, 0, 130, (0.3 + 0.55 * k.night) * flick);
    paintDisc(
      c,
      m.pool,
      const Offset(0, -112),
      90 + 20 * k.night,
      (0.45 + 0.6 * k.night) * flick,
    );
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final grow = 1 + 0.35 * math.min(1.0, k.stir);
    // Tongues of one fire, overlapping, each its own height and time.
    for (final (x, h, w, seed) in const [
      (-34.0, 46.0, 30.0, 3),
      (30.0, 54.0, 32.0, 7),
      (-12.0, 86.0, 40.0, 11),
      (12.0, 70.0, 36.0, 5),
    ]) {
      _flame(
        c,
        Offset(x, _rim + 4),
        h * grow,
        w,
        k.t * 0.8,
        seed,
        core: const Color(0xFFEDE6FF),
        body: const Color(0xFF6A40E8),
        alpha: 0.8,
      );
    }
    paintDisc(c, m.spark, const Offset(0, _rim - 8), 26, 0.35);
    // Ash lifting off it, thinning as it goes.
    _ash.clear();
    _ashHi.clear();
    for (var i = 0; i < 34; i++) {
      final f = _frac(k.t * (0.07 + 0.05 * _hash(i, 1)) + _hash(i, 2));
      final x = (_hash(i, 3) - 0.5) * 90 + math.sin(k.t * 0.6 + i) * 12 * f;
      final y = _rim - 10 - f * 120;
      (f < 0.45 ? _ash : _ashHi).add(x, y);
    }
    _ash.draw(c, 2.4, _a(const Color(0xFFD9CFEA), 0.45));
    _ashHi.draw(c, 2, _a(const Color(0xFFD9CFEA), 0.2));
  }
}

/// A low bed of dark glass leaves ringed with black lilies. By day the
/// lilies are shut buds; at dusk they open, their violet hearts lit and
/// pollen drifting up, and by night a resident who can reach it sleeps
/// curled in the hollow among them. A few leaves lie over the sleeper.
class _NightbloomBed extends KeepsakeArt {
  _NightbloomBed() : super(const Color(0xFFB48CFF));

  /// (x, stem height, size, lean): the lilies round the hollow, back row
  /// first. The front pair are drawn over the sleeper.
  static const List<(double, double, double, double)> _lilies = [
    (-118, 54, 1.0, -0.35),
    (-62, 74, 1.15, -0.12),
    (14, 82, 1.25, 0.05),
    (82, 66, 1.05, 0.22),
    (132, 46, 0.9, 0.4),
    (-96, 30, 0.85, -0.5),
    (106, 26, 0.8, 0.55),
  ];
  static const int _back = 5;

  final StoneLight _leafLight = StoneLight(const Color(0xFF6A5A9A));
  final _Tris _petals = _Tris(240);
  final _Grains _pollen = _Grains(60);

  @override
  Rect get box => const Rect.fromLTRB(-170, -150, 170, 8);

  /// The hollow in the middle of the bed.
  @override
  List<Offset> seats(KeepsakeTime k) => const [Offset(0, 6)];

  @override
  bool get hasFront => true;

  @override
  void body(Canvas c) {
    // A low mound of dark leaves, lying flat from the hollow outward.
    final mound = Path()
      ..moveTo(-160, 2)
      ..quadraticBezierTo(-150, -28, -90, -32)
      ..quadraticBezierTo(0, -18, 90, -32)
      ..quadraticBezierTo(150, -28, 160, 2)
      ..close();
    _solid(c, mound, _leafLight.ink);
    _shade(c, mound, _litAcross(_leafLight, -160, 160, k: 0.5));
    for (var i = 0; i < 9; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final x = side * (40 + 14.0 * i);
      _leafPane(
        c,
        Offset(x, -6),
        side < 0 ? -math.pi + 0.25 : -0.25,
        60 - i * 2.0,
      );
    }
  }

  /// A long leaf of dark glass from [at] along [angle], its vein lit.
  void _leafPane(Canvas c, Offset at, double angle, double len) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(angle);
    final leaf = vfxLeaf(Offset.zero, len, 0);
    _solid(c, leaf, _leafLight.ink);
    _shade(
      c,
      leaf,
      ui.Gradient.linear(
        Offset.zero,
        Offset(len, 0),
        [
          Color.lerp(_leafLight.face, _leafLight.rim, 0.35)!,
          _leafLight.face,
          _leafLight.ink,
        ],
        const [0.0, 0.5, 1.0],
      ),
    );
    _solid(
      c,
      vfxRibbon(
        [const Offset(2, 0), Offset(len * 0.5, -1), Offset(len * 0.9, 0)],
        1.6,
        0.4,
      ),
      _a(_leafLight.rim, 0.28),
    );
    c.restore();
  }

  /// How open the lilies are: shut by day, open by night.
  double _open(KeepsakeTime k) => _smooth(0.15, 0.85, k.night);

  @override
  void under(Canvas c, KeepsakeTime k) {
    final o = _open(k);
    _groundPool(c, m, 0, 190, 0.12 + 0.45 * o);
    paintDisc(c, m.pool, const Offset(0, -70), 150, 0.1 + 0.4 * o);
  }

  Offset _head(KeepsakeTime k, int i) {
    final (x, h, _, lean) = _lilies[i];
    final sway = math.sin(k.t * 0.7 + i * 1.3) * 0.04 * (1 + k.stir);
    return Offset(x + lean * h * 0.6 + sway * h, -h);
  }

  /// Lilies [from] to [to]: stems, then every petal in one draw, then the
  /// lit hearts.
  void _drawLilies(Canvas c, KeepsakeTime k, int from, int to) {
    final open = _open(k);
    for (var i = from; i < to; i++) {
      final (x, h, s, lean) = _lilies[i];
      final head = _head(k, i);
      _solid(
        c,
        vfxRibbon(
          [Offset(x, -8), Offset(x + lean * h * 0.3, -h * 0.55), head],
          4.2 * s,
          2.4 * s,
        ),
        _leafLight.face,
      );
      final sway = math.sin(k.t * 0.7 + i * 1.3) * 0.04 * (1 + k.stir);
      _cupFlower(
        _petals,
        head,
        -math.pi / 2 + lean * 0.5 + sway,
        s,
        open,
        i,
        heart: 0xB48CFF,
        face: 0x3A2462,
        tip: 0xA088D8,
        shade: 0x0E0818,
      );
    }
    _petals.draw(c);
    for (var i = from; i < to; i++) {
      final (_, _, s, lean) = _lilies[i];
      final up = Offset(
        math.cos(-math.pi / 2 + lean * 0.5),
        math.sin(-math.pi / 2 + lean * 0.5),
      );
      paintDisc(c, m.spark, _head(k, i) + up * 7 * s, 10 * s, 0.1 + 0.8 * open);
    }
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    _drawLilies(c, k, 0, _back);
    // Pollen drifting up off the open flowers.
    final open = _open(k);
    if (open > 0.05) {
      _pollen.clear();
      for (var i = 0; i < 40; i++) {
        final (x, h, _, lean) = _lilies[i % _back];
        final f = _frac(k.t * (0.06 + 0.05 * _hash(i, 1)) + _hash(i, 2));
        final px =
            x +
            lean * h * 0.6 +
            math.sin(k.t * 0.5 + i) * 10 * f +
            (_hash(i, 3) - 0.5) * 20;
        _pollen.add(px, -h - 6 - f * 90);
      }
      _pollen.draw(c, 2.4, _a(m.grainHot, 0.55 * open));
    }
  }

  @override
  void front(Canvas c, KeepsakeTime k) {
    // Leaves over the sleeper's feet, then the near lilies.
    for (final (x, a, len) in const [
      (-70.0, -0.18, 70.0),
      (64.0, -math.pi + 0.2, 76.0),
      (-14.0, -0.05, 54.0),
    ]) {
      _leafPane(c, Offset(x, 4), a, len);
    }
    _drawLilies(c, k, _back, _lilies.length);
  }
}

// ═══ THE WHITE WORK ═══════════════════════════════════════════════════════

/// Moonstones stacked by hand: dark, a milky blue moving in them, and by
/// night a light pooled inside each.
class _MoonstoneCairn extends KeepsakeArt {
  _MoonstoneCairn() : super(const Color(0xFFCFE0FF));

  /// (centre, rx, ry, tilt), the bottom stone first.
  static const _stones = <(Offset, double, double, double)>[
    (Offset(0, -16), 36, 16, 0.04),
    (Offset(-5, -43), 29, 12, -0.08),
    (Offset(3, -64), 23, 10, 0.1),
    (Offset(-2, -82), 16, 8.5, -0.07),
    (Offset(1, -96), 10, 6.5, 0.05),
  ];

  final StoneLight _sheen = StoneLight(const Color(0xFFB8D0FF));

  late final List<Path> _paths = [
    for (var i = 0; i < _stones.length; i++) _stone(i),
  ];

  Path _stone(int i) {
    final (at, rx, ry, tilt) = _stones[i];
    final pts = <Offset>[];
    const n = 20;
    for (var j = 0; j < n; j++) {
      final a = j / n * math.pi * 2;
      // A stone, not an egg: flatter underneath, a little lumpy.
      final lump = 1 + 0.06 * math.sin(a * 3 + i * 1.7);
      final under = math.sin(a) > 0 ? 0.82 : 1.0;
      final p = Offset(
        math.cos(a) * rx * lump,
        math.sin(a) * ry * lump * under,
      );
      pts.add(at + Offset(p.dx - p.dy * tilt, p.dy + p.dx * tilt));
    }
    return Path()..addPolygon(pts, true);
  }

  @override
  Rect get box => const Rect.fromLTRB(-42, -108, 42, 4);

  @override
  void body(Canvas c) {
    for (var i = 0; i < _stones.length; i++) {
      final (at, rx, ry, _) = _stones[i];
      final path = _paths[i];
      // Grey-blue stone, lit on its upper left.
      _shade(
        c,
        path,
        ui.Gradient.radial(
          at + Offset(-rx * 0.4, -ry * 0.55),
          rx * 1.5,
          const [
            Color(0xFF8E98AC),
            Color(0xFF4C5464),
            Color(0xFF242934),
            Color(0xFF11141A),
          ],
          const [0.0, 0.35, 0.75, 1.0],
        ),
      );
      // The milky blue that moves in moonstone, floating inside it.
      c.save();
      c.clipPath(path);
      paintDisc(
        c,
        _sheen.leak,
        at + Offset(rx * 0.25, -ry * 0.15),
        rx * 0.95,
        0.7,
      );
      c.restore();
      // Where it rests on the one below: a little shadow.
      if (i > 0) {
        _solid(
          c,
          Path()..addOval(
            Rect.fromCenter(
              center: at + Offset(0, ry * 0.82),
              width: rx * 1.5,
              height: ry * 0.5,
            ),
          ),
          const Color(0x40000000),
        );
      }
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 70, 0.08 + 0.45 * k.night);
    paintDisc(c, m.pool, const Offset(0, -56), 64, 0.1 + 0.45 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final glow = k.night + 0.4 * math.min(1.0, k.stir);
    if (glow < 0.03) return;
    for (var i = 0; i < _stones.length; i++) {
      final (at, rx, ry, _) = _stones[i];
      final breathe = 0.6 + 0.4 * math.sin(k.t * 0.5 - i * 0.9);
      c.save();
      c.clipPath(_paths[i]);
      paintDisc(
        c,
        m.leak,
        at + Offset(rx * 0.15, ry * 0.2),
        rx * 1.2,
        glow * breathe,
      );
      paintDisc(
        c,
        m.spark,
        at + Offset(rx * 0.2, 0),
        rx * 0.5,
        0.3 * glow * breathe,
      );
      c.restore();
    }
  }
}

/// A column of salt crystal, rose-white, catching the light by day and
/// faintly lit from within by night.
class _SaltPillar extends KeepsakeArt {
  _SaltPillar() : super(const Color(0xFFF6D6E0));

  static const _column = [
    Offset(-15, -2),
    Offset(-18, -104),
    Offset(-9, -134),
    Offset(1, -148),
    Offset(12, -128),
    Offset(16, -100),
    Offset(14, -2),
  ];

  @override
  Rect get box => const Rect.fromLTRB(-40, -156, 40, 4);

  /// Salt is milky, not dark glass: pale toward the light above it.
  static final ui.Shader _milk = ui.Gradient.linear(
    const Offset(0, -150),
    const Offset(0, 0),
    const [Color(0x88FFF2F6), Color(0x40F2D2DC), Color(0x08C8A0B0)],
    const [0.0, 0.45, 1.0],
  );

  @override
  void body(Canvas c) {
    // A crust of salt round its foot.
    final crust = _poly(const [
      Offset(-38, 2),
      Offset(-30, -8),
      Offset(-12, -14),
      Offset(10, -12),
      Offset(30, -7),
      Offset(38, 2),
    ]);
    _solid(c, crust, const Color(0xFF3A3236));
    _shade(c, crust, _litAcross(m, -38, 38, k: 0.9));
    for (final (x, h, lean, w) in const [
      (-24.0, 48.0, -10.0, 6.0),
      (24.0, 62.0, 9.0, 7.0),
      (6.0, 34.0, 5.0, 5.0),
    ]) {
      final b = Offset(x, -6);
      final outline = [
        b + Offset(-w, 0),
        b + Offset(-w + lean * 0.6, -h * 0.74),
        b + Offset(lean, -h),
        b + Offset(w + lean * 0.6, -h * 0.74),
        b + Offset(w, 0),
      ];
      CutStone.gem(
        m,
        outline,
        b + Offset(lean * 0.4, -h * 0.5),
      ).paint(c, 0, glow: 1.2, reach: h);
      _shade(c, _poly(outline), _milk, 0.8);
    }
    CutStone.gem(
      m,
      _column,
      const Offset(-2, -92),
    ).paint(c, 0, glow: 1.4, reach: 120);
    _shade(c, _poly(_column), _milk);
    // The long facet edge catching the light.
    _solid(
      c,
      _poly(const [
        Offset(-17, -100),
        Offset(-14, -100),
        Offset(-6, -134),
        Offset(-9, -134),
      ]),
      const Color(0x77FFFFFF),
    );
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, const Offset(0, -76), 64, 0.15 + 0.45 * k.night);
    _groundPool(c, m, 0, 60, 0.1 + 0.35 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    // By day, glints climbing its facets; by night, a light inside.
    for (var i = 0; i < 4; i++) {
      final f = _frac(k.t / (5 + i * 1.3) + i * 0.29);
      final along = _smooth(0, 1, f);
      final at = Offset(-12 + i * 7.0, -20 - along * 110 + i * 6);
      final on = math.sin(math.pi * f);
      paintDisc(
        c,
        kGlint,
        at,
        5 + 2 * k.stir,
        (0.15 + 0.7 * k.daylight) * on * on,
      );
    }
    paintDisc(c, m.leak, const Offset(-1, -80), 36, 0.1 + 0.5 * k.night);
  }
}

/// A low silver basin on a stone foot. Its water holds the moon by night;
/// the residents come to drink from it.
class _MoonFont extends KeepsakeArt {
  _MoonFont() : super(const Color(0xFFCADCFF));

  static const _water = Rect.fromLTRB(-58, -72, 58, -58);
  final StoneLight _stone = StoneLight(_kStone);
  final StoneLight _silver = StoneLight(const Color(0xFFDCE4F0));

  /// Silver, light and dark in bands as it turns.
  static final ui.Shader _silverBands = ui.Gradient.linear(
    const Offset(-72, 0),
    const Offset(72, 0),
    const [
      Color(0xFF5A6270),
      Color(0xFFB4BECC),
      Color(0xFF4A5260),
      Color(0xFF1E2128),
      Color(0xFF3A414E),
    ],
    const [0.0, 0.2, 0.45, 0.78, 1.0],
  );

  @override
  Rect get box => const Rect.fromLTRB(-76, -88, 76, 4);

  @override
  void body(Canvas c) {
    _plinth(c, _stone, 56, 9);
    _shaft(c, _stone, 0, -9, -38, 20, 14);
    _block(c, _stone, const Rect.fromLTRB(-16, -44, 16, -38), bevel: 1.4);
    // The basin: a shallow silver bowl, its lip a bright band.
    final bowl = Path()
      ..moveTo(-72, -66)
      ..cubicTo(-68, -50, -38, -42, 0, -42)
      ..cubicTo(38, -42, 68, -50, 72, -66)
      ..close();
    _solid(c, bowl, _silver.ink);
    _shade(c, bowl, _silverBands);
    final lip = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(const Rect.fromLTRB(-74, -76, 74, -56))
      ..addOval(_water);
    _shade(c, lip, _silverBands);
    _shade(
      c,
      lip,
      ui.Gradient.linear(const Offset(0, -76), const Offset(0, -56), const [
        Color(0x40FFFFFF),
        Color(0x00FFFFFF),
      ]),
    );
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 90, 0.1 + 0.4 * k.night);
    paintDisc(c, m.pool, const Offset(0, -84), 76, 0.1 + 0.5 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final water = Path()..addOval(_water);
    c.save();
    c.clipPath(water);
    final day = k.daylight;
    _solid(
      c,
      water,
      Color.lerp(const Color(0xFF070A14), const Color(0xFF243652), day * 0.8)!,
    );
    _shade(
      c,
      Path()..addRect(_water),
      ui.Gradient.linear(const Offset(0, -72), const Offset(0, -58), [
        _a(const Color(0xFFB9CCE8), 0.35 + 0.2 * day),
        _a(const Color(0xFFB9CCE8), 0.02),
      ]),
    );
    // The moon held in it: a soft round of light, broken up when it is
    // stirred.
    final wob = math.sin(k.t * 3.1) * 4 * k.stir;
    if (k.night > 0.03) {
      final at = Offset(16 + wob, -65);
      paintDisc(c, m.spark, at, 18, 0.5 * k.night);
      paintDisc(c, kGlint, at, 8, 0.95 * k.night);
      _solid(
        c,
        Path()..addOval(
          Rect.fromCenter(
            center: at + const Offset(0, 4),
            width: 30,
            height: 1.6,
          ),
        ),
        _a(const Color(0xFFE8F0FF), 0.35 * k.night),
      );
    }
    // Rings of light from where it was drunk, widening and fading.
    if (k.stir > 0.02) {
      for (var j = 0; j < 2; j++) {
        final age = _frac(k.t * 0.6 + j * 0.5);
        final r = 6 + 40 * age;
        final band = Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(
            Rect.fromCenter(
              center: const Offset(-8, -64),
              width: r * 2,
              height: r * 0.3,
            ),
          )
          ..addOval(
            Rect.fromCenter(
              center: const Offset(-8, -63.7),
              width: r * 2 - 4,
              height: r * 0.3 - 1.6,
            ),
          );
        _solid(
          c,
          band,
          _a(const Color(0xFFE8F0FF), 0.35 * (1 - age) * math.min(1.0, k.stir)),
        );
      }
    }
    c.restore();
  }
}

/// A great glass globe of snow on a brass-bound plinth. A resident climbs
/// in and sits on the drift at the bottom; tapping it (a stir) shakes it,
/// and the snow swirls up round whoever sits inside and settles again. The
/// back glass and the snow behind the sitter are drawn under it; the snow
/// in front and the near glass over it.
class _SnowGlobe extends KeepsakeArt {
  _SnowGlobe() : super(const Color(0xFFBFE4FF));

  static const double _base = 58; // plinth height
  static const double _r = 150; // the globe's radius
  static const Offset _c = Offset(0, -(_base + _r - 22));
  static const double _drift = -_base - 14; // the snow floor's top, y

  final StoneLight _plinthStone = StoneLight(_kStone);
  final StoneLight _brassLight = StoneLight(_kBrass);
  final _Grains _far = _Grains(220);
  final _Grains _farLit = _Grains(80);
  final _Grains _near = _Grains(220);
  final _Grains _nearLit = _Grains(80);

  /// How shaken it is: stir lingers a while as swirl. Kept between frames
  /// so the snow settles over seconds, not as fast as stir decays.
  double _swirl = 0;
  double _lastT = -1;

  static final ui.Shader _backGlass = ui.Gradient.radial(
    Offset.zero,
    1,
    const [
      Color(0x2A9FCBE8),
      Color(0x1A6A90B0),
      Color(0x223C5470),
      Color(0x667FA9CC),
      Color(0x00BFE4FF),
    ],
    const [0.0, 0.62, 0.86, 0.97, 1.0],
  );

  /// The near glass: clear, catching the light only toward its edge.
  static final ui.Shader _nearGlass = ui.Gradient.radial(
    const Offset(0.1, 0.12),
    1.04,
    const [
      Color(0x00FFFFFF),
      Color(0x00FFFFFF),
      Color(0x18CFE8FF),
      Color(0x55DDF0FF),
      Color(0x00DDF0FF),
    ],
    const [0.0, 0.7, 0.88, 0.97, 1.0],
  );

  @override
  Rect get box => const Rect.fromLTRB(-190, -(_base + _r * 2 - 10), 190, 6);

  /// On the drift, at the bottom of the globe.
  @override
  List<Offset> seats(KeepsakeTime k) => const [Offset(0, -_drift - 4)];

  @override
  bool get hasFront => true;

  @override
  void body(Canvas c) {
    // The plinth: obsidian steps, a band of brass round its top.
    _plinth(c, _plinthStone, 250, 36, steps: 3);
    final collar = _poly(const [
      Offset(-118, -36),
      Offset(118, -36),
      Offset(108, -_base),
      Offset(-108, -_base),
    ]);
    _solid(c, collar, _brassLight.ink);
    _shade(c, collar, _litAcross(_brassLight, -118, 118, k: 0.9));
    final lip = Path()
      ..addOval(
        Rect.fromCenter(
          center: const Offset(0, -_base),
          width: 216,
          height: 16,
        ),
      );
    _shade(
      c,
      lip,
      ui.Gradient.linear(const Offset(-108, 0), const Offset(108, 0), [
        Color.lerp(_brassLight.face, _brassLight.rim, 0.7)!,
        Color.lerp(_brassLight.face, _brassLight.rim, 0.2)!,
      ]),
    );
    // The back of the globe: dark glass, lit at its rim.
    c.save();
    c.translate(_c.dx, _c.dy);
    c.scale(_r);
    _p
      ..shader = _backGlass
      ..color = const Color(0xFFFFFFFF);
    c.drawCircle(Offset.zero, 1, _p);
    c.restore();
    // The drift it holds, a mound of snow lit from above.
    final drift = Path()
      ..moveTo(-128, -_base + 2)
      ..quadraticBezierTo(-120, _drift - 8, -40, _drift - 4)
      ..quadraticBezierTo(10, _drift - 10, 70, _drift - 2)
      ..quadraticBezierTo(124, _drift + 2, 128, -_base + 2)
      ..close();
    _shade(
      c,
      drift,
      ui.Gradient.linear(
        const Offset(0, _drift - 10),
        const Offset(0, -_base),
        const [Color(0xFFE8F4FF), Color(0xFF9DB9D6), Color(0xFF5C7690)],
        const [0.0, 0.4, 1.0],
      ),
    );
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 220, 0.25 + 0.45 * k.night);
    paintDisc(c, m.pool, _c, _r * 1.25, 0.35 + 0.5 * k.night);
  }

  void _settle(KeepsakeTime k) {
    final dt = _lastT < 0 ? 0.0 : (k.t - _lastT).clamp(0.0, 0.1);
    _lastT = k.t;
    // A shake sets it swirling at once; it settles over about six seconds.
    _swirl = math.max(_swirl * math.exp(-dt / 2.2), k.stir.clamp(0.0, 1.0));
  }

  /// Snow, split into what lies behind the sitter and what falls in front.
  void _snow(KeepsakeTime k, bool front) {
    final far = front ? _near : _far, lit = front ? _nearLit : _farLit;
    far.clear();
    lit.clear();
    final s = _smooth(0.0, 1.0, _swirl);
    const n = 300;
    for (var i = 0; i < n; i++) {
      final isFront = _hash(i, 9) < 0.42;
      if (isFront != front) continue;
      // Falling: each flake down through the globe on its own loop,
      // drifting a little side to side.
      final fall = 0.025 + 0.03 * _hash(i, 2);
      final f = _frac(k.t * fall + _hash(i, 3));
      final x0 = (_hash(i, 1) - 0.5) * 2 * _r * 0.86;
      final fy = (_c.dy - _r * 0.88) + f * (_drift - 6 - (_c.dy - _r * 0.88));
      final fx = x0 + math.sin(k.t * 0.5 + i) * 7;
      // Swirling: each flake somewhere through the whole globe, carried in
      // its own small loops by the stirred water — a flurry, never one
      // ring going round.
      final ra = _hash(i, 4) * math.pi * 2;
      final rr = _r * 0.86 * math.sqrt(_hash(i, 6));
      final hx = math.cos(ra) * rr, hy = _c.dy + math.sin(ra) * rr * 0.9;
      final loop = 26 + 30 * _hash(i, 5);
      final sp = 1.1 + 1.4 * _hash(i, 10);
      final sx =
          hx +
          math.sin(k.t * sp + hy * 0.03 + i) * loop -
          (hy - _c.dy) * 0.25 * math.sin(k.t * 0.7);
      final sy =
          hy + math.cos(k.t * sp * 0.8 + hx * 0.03 + i * 0.7) * loop * 0.8;
      var x = fx + (sx - fx) * s, y = fy + (sy - fy) * s;
      // Kept inside the glass.
      final d = Offset(x, y) - _c;
      if (d.distance > _r * 0.93) {
        final q = _c + d / d.distance * _r * 0.93;
        x = q.dx;
        y = q.dy;
      }
      if (y > _drift - 2) y = _drift - 2 - _hash(i, 7) * 4;
      if (_hash(i, 8) < 0.2) {
        lit.add(x, y);
      } else {
        far.add(x, y);
      }
    }
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    _settle(k);
    // A little lamp in the plinth lights the snow from below by night.
    paintDisc(c, m.leak, const Offset(0, _drift), 120, 0.25 + 0.55 * k.night);
    _snow(k, false);
    _far.draw(c, 3.2, _a(const Color(0xFFDCEBFA), 0.55));
    _farLit.draw(c, 4.2, _a(const Color(0xFFFFFFFF), 0.8));
  }

  @override
  void front(Canvas c, KeepsakeTime k) {
    _snow(k, true);
    _near.draw(c, 3.6, _a(const Color(0xFFE6F1FC), 0.7));
    _nearLit.draw(c, 4.8, _a(const Color(0xFFFFFFFF), 0.9));
    // The near glass: clear in the middle, bright where it turns away.
    c.save();
    c.translate(_c.dx, _c.dy);
    c.scale(_r);
    _p
      ..shader = _nearGlass
      ..color = const Color(0xFFFFFFFF);
    c.drawCircle(Offset.zero, 1, _p);
    // The window it gives back, up on the left: a soft filled crescent.
    _solid(
      c,
      vfxCrescent(Offset.zero, 0.86, 0.13, -2.25, 1.2),
      const Color(0x36FFFFFF),
    );
    _solid(
      c,
      vfxCrescent(Offset.zero, 0.8, 0.05, -2.45, 0.5),
      const Color(0x55FFFFFF),
    );
    paintDisc(c, kGlint, const Offset(-0.5, -0.6), 0.07, 0.8);
    c.restore();
    // Where the glass meets the brass, the near lip over the drift.
    final lip = Path()
      ..moveTo(-112, -_base - 2)
      ..quadraticBezierTo(0, -_base + 12, 112, -_base - 2)
      ..lineTo(108, -_base + 4)
      ..quadraticBezierTo(0, -_base + 18, -108, -_base + 4)
      ..close();
    _shade(
      c,
      lip,
      ui.Gradient.linear(const Offset(-112, 0), const Offset(112, 0), [
        Color.lerp(_brassLight.face, _brassLight.rim, 0.75)!,
        _brassLight.face,
      ]),
    );
  }
}

// ═══ THE YELLOW WORK ══════════════════════════════════════════════════════

/// A sundial: a drum of stone, its face marked in brass, a brass gnomon on
/// it. The shadow follows the field's hour — toward the front in the
/// morning, along the gnomon at noon, toward the back by evening — and is
/// gone by night.
class _Sundial extends KeepsakeArt {
  _Sundial() : super(const Color(0xFFFFD27A));

  static const _mid = Offset(0, -62);
  static const double _rx = 46, _ry = 15;
  final StoneLight _stone = StoneLight(_kStone);

  static final Rect _face = Rect.fromCenter(
    center: _mid,
    width: _rx * 2,
    height: _ry * 2,
  );
  static final Rect _inner = Rect.fromCenter(
    center: _mid,
    width: _rx * 1.78,
    height: _ry * 1.7,
  );

  @override
  Rect get box => const Rect.fromLTRB(-54, -98, 54, 4);

  @override
  void body(Canvas c) {
    _plinth(c, _stone, 46, 8);
    _shaft(c, _stone, 0, -8, -48, 24, 18);
    // The drum: its side, then its face seen from a little above.
    final side = Path()
      ..addRect(Rect.fromLTRB(-_rx, _mid.dy, _rx, _mid.dy + 10))
      ..addOval(
        Rect.fromCenter(
          center: _mid + const Offset(0, 10),
          width: _rx * 2,
          height: _ry * 2,
        ),
      );
    _solid(c, side, _stone.ink);
    _shade(c, side, _litAcross(_stone, -_rx, _rx, k: 0.8));
    _shade(
      c,
      Path()..addOval(_face),
      ui.Gradient.linear(
        const Offset(-_rx, 0),
        const Offset(_rx, 0),
        const [Color(0xFF6E7484), Color(0xFF3E434E), Color(0xFF22252C)],
        const [0.0, 0.45, 1.0],
      ),
    );
    // A band of brass round its edge, and the hours marked inside it.
    final band = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(_face)
      ..addOval(_inner);
    _shade(c, band, _polishedBrass(-_rx, _rx));
    for (var h = 0; h <= 12; h++) {
      final dir = _shadowDir(6.0 + h);
      final o = _mid + Offset(dir.dx * _rx * 0.82, dir.dy * _ry * 0.8);
      final i = _mid + Offset(dir.dx * _rx * 0.68, dir.dy * _ry * 0.64);
      final n = Offset(-dir.dy, dir.dx) * (h % 3 == 0 ? 1.5 : 0.9);
      _solid(
        c,
        _poly([o - n, o + n, i + n * 0.6, i - n * 0.6]),
        const Color(0xFFC9AC6E),
      );
    }
    // The gnomon, in brass: its tall edge to the north (left), its slope
    // down to the dial's middle.
    final fin = _poly(const [
      Offset(-26, -63),
      Offset(-26, -92),
      Offset(-21, -92),
      Offset(8, -63),
    ]);
    _shade(c, fin, _polishedBrass(-26, 8));
    _solid(
      c,
      _poly(const [
        Offset(-26, -63),
        Offset(8, -63),
        Offset(5, -60),
        Offset(-26, -60),
      ]),
      const Color(0xFF3A2E18),
    );
  }

  /// Which way the shadow falls at [hour], on the dial seen from above:
  /// x right, y toward the viewer.
  static Offset _shadowDir(double hour) {
    final a = math.pi * (hour - 6) / 12;
    return Offset(-math.sin(a), math.cos(a));
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 60, 0.15 * k.daylight + 0.1 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final day = k.daylight;
    if (day < 0.02) return;
    c.save();
    c.clipPath(Path()..addOval(_inner));
    // Sunlight lying on the face.
    paintDisc(c, m.pool, _mid + const Offset(-10, 0), 50, 0.9 * day);
    // The shadow, from the gnomon's foot away from the sun: long morning
    // and evening, short at noon.
    final h = k.hour.clamp(6.0, 18.0);
    final dir = _shadowDir(h);
    final long = 0.55 + 0.4 * math.cos(math.pi * (h - 6) / 12).abs();
    final foot = _mid + const Offset(-8, 0);
    final tip =
        foot + Offset(dir.dx * _rx * 0.85 * long, dir.dy * _ry * 0.85 * long);
    final d = tip - foot;
    final n = Offset(-d.dy, d.dx) / math.max(d.distance, 1e-3);
    _solid(
      c,
      _poly([foot - n * 4, foot + n * 4, tip + n * 0.8, tip - n * 0.8]),
      _a(const Color(0xFF0A0806), 0.65 * day),
    );
    c.restore();
    // The gnomon catching the sun.
    paintDisc(c, kGlint, const Offset(-23, -88), 4.5, 0.6 * day);
  }
}

/// A lamp of honey-colored glass on a brass foot, pollen drifting slowly
/// in its light.
class _HoneyLamp extends KeepsakeArt {
  _HoneyLamp() : super(const Color(0xFFFFB84A));

  static const _heart = Offset(0, -62);
  final StoneLight _stone = StoneLight(_kStone);
  final StoneLight _brassL = StoneLight(_kBrass);
  final _Grains _pollen = _Grains(30);
  final _Grains _bright = _Grains(10);

  static final Path _jar = Path()
    ..moveTo(-11, -26)
    ..cubicTo(-34, -32, -36, -88, -12, -98)
    ..lineTo(12, -98)
    ..cubicTo(36, -88, 34, -32, 11, -26)
    ..close();

  @override
  Rect get box => const Rect.fromLTRB(-36, -118, 36, 4);

  @override
  void body(Canvas c) {
    _plinth(c, _stone, 42, 8);
    final foot = _poly(const [
      Offset(-15, -8),
      Offset(15, -8),
      Offset(9, -22),
      Offset(-9, -22),
    ]);
    _solid(c, foot, _brassL.ink);
    _shade(c, foot, _litAcross(_brassL, -15, 15, k: 0.9));
    _block(c, _brassL, const Rect.fromLTRB(-14, -27, 14, -21), bevel: 1.2);
    // The cap and its ring.
    _block(c, _brassL, const Rect.fromLTRB(-14, -104, 14, -98), bevel: 1.2);
    final dome = _poly(const [
      Offset(-10, -104),
      Offset(10, -104),
      Offset(5, -111),
      Offset(-5, -111),
    ]);
    _solid(c, dome, _brassL.ink);
    _shade(c, dome, _litAcross(_brassL, -10, 10, k: 0.9));
    paintOrb(c, _brassL, const Offset(0, -114), 3.4);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, _heart, 74, 0.45 + 0.6 * k.night);
    _groundPool(c, m, 0, 72, 0.3 + 0.5 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final on = 0.55 + 0.45 * k.night;
    _glass(c, m, _jar, _heart, 40 * on);
    // Pollen turning slowly in it, each grain in its own small loop.
    _pollen.clear();
    _bright.clear();
    final stir = 1 + 2 * math.min(1.0, k.stir);
    for (var i = 0; i < 26; i++) {
      final a = k.t * (0.15 + 0.12 * _hash(i, 1)) * stir + _hash(i, 2) * 6.28;
      final x = (_hash(i, 3) - 0.5) * 30 + math.sin(a) * 6;
      final y = -40 - _hash(i, 4) * 48 + math.cos(a * 0.8 + i) * 7;
      (i % 5 == 0 ? _bright : _pollen).add(x, y);
    }
    _pollen.draw(c, 2.2, _a(const Color(0xFFFFE6A8), 0.7));
    _bright.draw(c, 3, _a(const Color(0xFFFFF6DA), 0.9));
    _clearGlass(c, _jar, const Rect.fromLTRB(-30, -98, 30, -26), alpha: 0.8);
  }
}

/// A tall brass coil that gathers sparks at its crown and throws them —
/// short crackles into the air by itself, long arcs to the ground when a
/// resident hops by it. The arcs are lightning: a lit core over a faint
/// glow.
class _StormCoil extends KeepsakeArt {
  _StormCoil() : super(const Color(0xFFFFE08A));

  static const _crown = Offset(0, -262);
  final StoneLight _stone = StoneLight(_kStone);
  final StoneLight _brassL = StoneLight(_kBrass);
  final Path _glow = Path(), _core = Path();
  final _Grains _sparks = _Grains(30);

  @override
  Rect get box => const Rect.fromLTRB(-64, -300, 64, 4);

  @override
  void body(Canvas c) {
    _plinth(c, _stone, 66, 14, steps: 3);
    _block(c, _stone, const Rect.fromLTRB(-26, -40, 26, -14), bevel: 2);
    // The column, and brass wound round it, each turn a lit band.
    _shaft(c, _stone, 0, -40, -238, 30, 24);
    for (var y = -48.0; y > -230; y -= 8.5) {
      final w = 15 - (y + 40) / -198 * 3;
      final band = _poly([
        Offset(-w - 1, y + 1.5),
        Offset(w + 1, y - 2.5),
        Offset(w + 1, y - 6.5),
        Offset(-w - 1, y - 2.5),
      ]);
      _solid(c, band, _brassL.ink);
      _shade(c, band, _litAcross(_brassL, -w, w, k: 1.4));
    }
    _block(c, _brassL, const Rect.fromLTRB(-16, -244, 16, -236), bevel: 1.4);
    // The crown: a ring of brass seen from a little above.
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCenter(center: _crown, width: 92, height: 34))
      ..addOval(
        Rect.fromCenter(
          center: _crown + const Offset(0, -3),
          width: 44,
          height: 10,
        ),
      );
    _solid(c, ring, _brassL.ink);
    _shade(
      c,
      ring,
      ui.Gradient.radial(
        _crown + const Offset(-24, -12),
        60,
        [
          Color.lerp(_brassL.face, _brassL.rim, 0.95)!,
          Color.lerp(_brassL.face, _brassL.rim, 0.35)!,
          _brassL.face,
          _brassL.ink,
        ],
        const [0.0, 0.3, 0.7, 1.0],
      ),
    );
    paintOrb(c, _brassL, _crown + const Offset(0, -20), 7);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    final s = math.min(1.0, k.stir);
    paintDisc(c, m.pool, _crown, 90, 0.2 + 0.3 * k.night + 0.5 * s);
    _groundPool(c, m, 0, 80, 0.15 + 0.3 * k.night + 0.3 * s);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final s = math.min(1.0, k.stir);
    _glow.reset();
    _core.reset();
    var bright = 0.0;
    // Four arcs, each on its own clock. Alone, a short crackle now and
    // then; stirred, long arcs, more of them, more often.
    for (var i = 0; i < 4; i++) {
      final period = (1.9 + 1.3 * _hash(i, 1)) * (1 - 0.55 * s);
      final cycle = (k.t / period + _hash(i, 2)).floor();
      final f = _frac(k.t / period + _hash(i, 2));
      final life = 0.1 + 0.3 * s;
      if (f > life) continue;
      if (i >= 1 + (3 * s).round()) continue;
      final a = -math.pi * _hash(cycle * 4 + i, 3) * 1.2 + math.pi * 0.1;
      final from = _crown + Offset(math.cos(a) * 44, math.sin(a) * 15);
      final Offset to;
      if (s > 0.3 && _hash(cycle * 4 + i, 4) < 0.7) {
        // To the ground beside it.
        final side = _hash(cycle * 4 + i, 5) < 0.5 ? -1.0 : 1.0;
        to = Offset(side * (50 + 40 * _hash(cycle * 4 + i, 6)), -4);
        paintDisc(c, m.spark, to, 12, 0.6 * (1 - f / life));
      } else {
        to =
            from +
            polar(
              36 + 50 * _hash(cycle * 4 + i, 7),
              a - 0.3 + 0.6 * _hash(cycle, 8),
            );
      }
      final fade = 1 - f / life;
      bright = math.max(bright, fade);
      vfxArcInto(
        _glow,
        _core,
        from,
        to,
        i * 7.3 + cycle * 1.9,
        k.t,
        width: 1.8,
        amp: 0.2,
        segs: 6,
        rate: 9,
      );
    }
    if (bright > 0) {
      _solid(c, _glow, _a(const Color(0xFFFFD98A), 0.32 * bright));
      _solid(c, _core, _a(const Color(0xFFFFF8E2), 0.95 * bright));
    }
    paintDisc(
      c,
      m.spark,
      _crown + const Offset(0, -20),
      14 + 6 * s,
      0.25 + 0.4 * bright + 0.2 * k.night,
    );
    // Charge creeping up the coil.
    _sparks.clear();
    for (var i = 0; i < 10; i++) {
      final f = _frac(k.t * (0.25 + 0.35 * s) + _hash(i, 9));
      final y = -48 - f * 182;
      final x = math.sin(f * 40 + i) * 13;
      _sparks.add(x, y);
    }
    _sparks.draw(c, 2.4, _a(m.grainHot, 0.35 + 0.4 * s));
  }
}

/// A throne of obsidian edged in gold leaf, on a stepped dais: its back a
/// pointed arch with a gilt sun set in it. One resident holds court on it;
/// the others come and bow.
class _GildedThrone extends KeepsakeArt {
  _GildedThrone() : super(const Color(0xFFF0C766));

  static const _seatY = -78.0;
  final StoneLight _stone = StoneLight(_kStone);
  final StoneLight _goldL = StoneLight(_gold);
  final StoneLight _amber = StoneLight(const Color(0xFFFFB45A));

  /// The back's outline, [inset] in from its edge.
  static Path _arch(double inset) {
    final w = 62 - inset;
    final top = -300 + inset * 1.6;
    return Path()
      ..moveTo(-w, _seatY)
      ..lineTo(-w, -228)
      ..quadraticBezierTo(-w, -276, 0, top)
      ..quadraticBezierTo(w, -276, w, -228)
      ..lineTo(w, _seatY)
      ..close();
  }

  static final Path _back = _arch(0);
  static final Path _panel = _arch(11);
  static final Path _band = Path.combine(
    PathOperation.difference,
    _back,
    _panel,
  );
  static const _sun = Offset(0, -206);

  /// Gold leaf lit from a lamp above it.
  static final ui.Shader _gilt = ui.Gradient.linear(
    const Offset(-30, -300),
    const Offset(20, -60),
    const [
      Color(0xFFF6DD98),
      Color(0xFFD4AC56),
      Color(0xFF8E6C2E),
      Color(0xFF4A3816),
    ],
    const [0.0, 0.3, 0.7, 1.0],
  );

  @override
  Rect get box => const Rect.fromLTRB(-180, -312, 180, 4);

  /// The one holding court, on its cushion; those who come to bow, either
  /// side of the dais.
  @override
  List<Offset> seats(KeepsakeTime k) => const [
    Offset(0, -_seatY + 6),
    Offset(-236, 0),
    Offset(236, 0),
  ];

  @override
  bool get hasFront => true;

  @override
  void body(Canvas c) {
    // The dais: three steps, each edged in brass.
    for (final (w, y0, y1) in const [
      (176.0, 0.0, -16.0),
      (144.0, -16.0, -32.0),
      (112.0, -32.0, -46.0),
    ]) {
      _block(c, _stone, Rect.fromLTRB(-w, y1, w, y0), bevel: 3);
      _shade(
        c,
        Path()..addRect(Rect.fromLTRB(-w, y1, w, y1 + 2.6)),
        _polishedBrass(-w, w),
      );
    }
    // The back: obsidian, the gold band round it, the sun set in it.
    _solid(c, _back, _stone.ink);
    _shade(c, _panel, _litAcross(_stone, -50, 50, k: 0.5));
    _shade(c, _band, _gilt);
    _shade(
      c,
      Path()..addOval(Rect.fromCircle(center: _sun, radius: 24)),
      ui.Gradient.radial(
        _sun + const Offset(-8, -9),
        30,
        const [Color(0xFFFBE7AE), Color(0xFFD9B25A), Color(0xFF7A5A22)],
        const [0.0, 0.5, 1.0],
      ),
    );
    paintOrb(c, _amber, _sun, 9);
    paintOrb(c, _goldL, const Offset(0, -304), 7);
    // The seat: a box with gold let into its front, a cushion on it.
    _block(c, _stone, const Rect.fromLTRB(-66, _seatY, 66, -46), bevel: 2.4);
    _shade(
      c,
      Path()..addRect(const Rect.fromLTRB(-54, _seatY + 8, 54, -54)),
      _gilt,
      0.8,
    );
    final cushion = Path()
      ..moveTo(-60, _seatY + 1)
      ..quadraticBezierTo(-60, _seatY - 7, -40, _seatY - 7)
      ..lineTo(40, _seatY - 7)
      ..quadraticBezierTo(60, _seatY - 7, 60, _seatY + 1)
      ..close();
    _shade(
      c,
      cushion,
      ui.Gradient.linear(
        const Offset(-60, 0),
        const Offset(60, 0),
        const [Color(0xFF8A5A26), Color(0xFF4E3012), Color(0xFF24160A)],
        const [0.0, 0.4, 1.0],
      ),
    );
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 220, 0.2 + 0.4 * k.night);
    paintDisc(c, m.pool, const Offset(0, -210), 150, 0.25 + 0.35 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    // A lamp above lighting the panel, and glints moving slowly round the
    // gold.
    c.save();
    c.clipPath(_panel);
    paintDisc(c, m.leak, const Offset(0, -270), 90, 0.3 + 0.25 * k.stir);
    c.restore();
    c.save();
    c.clipPath(_band);
    for (var i = 0; i < 2; i++) {
      final f = _frac(k.t / (8 + i * 5) + i * 0.5);
      final y = _seatY - f * (300 + _seatY);
      paintDisc(
        c,
        kGlint,
        Offset(i == 0 ? -56 : 56, y),
        18,
        0.5 * math.sin(math.pi * f),
      );
    }
    c.restore();
    paintDisc(
      c,
      _amber.spark,
      _sun,
      12,
      0.35 + 0.25 * k.night + 0.3 * math.min(1.0, k.stir),
    );
    paintDisc(
      c,
      kGlint,
      _sun + const Offset(-7, -8),
      6,
      0.4 + 0.3 * math.sin(k.t * 0.7),
    );
  }

  @override
  void front(Canvas c, KeepsakeTime k) {
    // The arms, over whoever sits in it, gold-scrolled at their ends.
    for (final x0 in const [-82.0, 58.0]) {
      _block(c, _stone, Rect.fromLTRB(x0, -124, x0 + 24, -46), bevel: 2);
      final roll = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(x0 - 3, -132, x0 + 27, -120),
            const Radius.circular(6),
          ),
        );
      _shade(c, roll, _gilt);
      paintOrb(c, _goldL, Offset(x0 < 0 ? x0 - 1 : x0 + 25, -126), 6.5);
    }
  }
}

// ═══ THE RED WORK ═════════════════════════════════════════════════════════

/// Red glass roses that open at dusk and close at dawn, lit from inside
/// while they are open.
class _GlassRose extends KeepsakeArt {
  _GlassRose() : super(const Color(0xFFFF4A5E));

  /// (x, height, size, lean).
  static const _roses = <(double, double, double, double)>[
    (-20, 66, 0.95, -0.2),
    (6, 94, 1.1, 0.04),
    (27, 54, 0.85, 0.24),
  ];
  final StoneLight _stem = StoneLight(const Color(0xFF7FA070));

  /// A petal from its base at the origin, up to (0, -1), one unit wide.
  static final Path _unitPetal = Path()
    ..moveTo(0, 0)
    ..cubicTo(-0.62, -0.15, -0.55, -0.9, 0, -1)
    ..cubicTo(0.55, -0.9, 0.62, -0.15, 0, 0)
    ..close();
  static final ui.Shader _petalBack = ui.Gradient.linear(
    Offset.zero,
    const Offset(0, -1),
    const [Color(0xFF2A040C), Color(0xFF7A1024), Color(0xFFD84458)],
    const [0.0, 0.5, 1.0],
  );
  static final ui.Shader _petalFront = ui.Gradient.linear(
    const Offset(0, 8),
    const Offset(0, -12),
    const [Color(0xFF2A040C), Color(0xFF8A1428), Color(0xFFE8606E)],
    const [0.0, 0.55, 1.0],
  );

  @override
  Rect get box => const Rect.fromLTRB(-42, -124, 46, 4);

  Offset _head(int i, KeepsakeTime k) {
    final (x, h, _, lean) = _roses[i];
    final sway = math.sin(k.t * 0.6 + i * 2.1) * 1.6 * (1 + k.stir);
    return Offset(x + lean * h * 0.5 + sway, -h);
  }

  @override
  void body(Canvas c) {
    // A low mound of dark earth they grow from.
    final mound = Path()
      ..moveTo(-40, 2)
      ..quadraticBezierTo(-30, -12, 0, -12)
      ..quadraticBezierTo(32, -12, 44, 2)
      ..close();
    _solid(c, mound, const Color(0xFF0E0B0C));
    _shade(c, mound, _litAcross(_stem, -40, 44, k: 0.3));
    for (var i = 0; i < _roses.length; i++) {
      final (x, h, s, lean) = _roses[i];
      final top = Offset(x + lean * h * 0.5, -h + 4);
      final stem = vfxRibbon(
        [Offset(x * 0.6, -8), Offset(x + lean * h * 0.2, -h * 0.5), top],
        4 * s,
        2.6 * s,
      );
      _solid(c, stem, _stem.ink);
      _shade(c, stem, _litAcross(_stem, x - 4, x + 4, k: 0.7));
      final side = i.isEven ? -1.0 : 1.0;
      final at = Offset(x + lean * h * 0.25, -h * 0.45);
      final leaf = vfxLeaf(at, 20 * s, -math.pi / 2 + side * 1.05);
      _solid(c, leaf, _stem.ink);
      _shade(
        c,
        leaf,
        ui.Gradient.linear(at, at + Offset(side * 16 * s, -8 * s), [
          Color.lerp(_stem.face, _stem.rim, 0.45)!,
          _stem.face,
        ]),
      );
    }
  }

  double _open(KeepsakeTime k) => _smooth(0.1, 0.8, k.night);

  @override
  void under(Canvas c, KeepsakeTime k) {
    final o = _open(k);
    _groundPool(c, m, 0, 70, 0.08 + 0.4 * o);
    paintDisc(c, m.pool, const Offset(4, -80), 70, 0.08 + 0.45 * o);
  }

  /// One rose at [head]: shut, a bud; open, a cup of petals, its back
  /// petals parted, its front ones curled out at their rims, its heart lit.
  void _rose(Canvas c, Offset head, double s, double o, double tilt) {
    c.save();
    c.translate(head.dx, head.dy);
    c.rotate(tilt);
    c.scale(s);
    for (final (a, len, w) in const [
      (-0.95, 18.0, 13.0),
      (0.9, 18.0, 13.0),
      (-0.35, 21.0, 14.0),
      (0.3, 21.0, 14.0),
    ]) {
      c.save();
      c.rotate(a * (0.12 + 0.88 * o));
      c.scale(w * (0.75 + 0.25 * o), len * (0.78 + 0.22 * o));
      _shade(c, _unitPetal, _petalBack);
      c.restore();
    }
    // The heart, lit from inside as it opens.
    paintDisc(c, m.leak, const Offset(0, -8), 14, 0.3 + 0.7 * o);
    paintDisc(c, m.spark, const Offset(0, -9), 5, 0.1 + 0.45 * o);
    // The cup of front petals, its rim curling out.
    final hw = 8 + 6 * o;
    final cup = Path()
      ..moveTo(-hw, -5)
      ..cubicTo(-hw, 9, hw, 9, hw, -5)
      ..quadraticBezierTo(hw + 3.5 * o, -9 - 2 * o, hw * 0.45, -7.5 + 1.5 * o)
      ..quadraticBezierTo(0, -5 + 2 * o, -hw * 0.45, -7.5 + 1.5 * o)
      ..quadraticBezierTo(-hw - 3.5 * o, -9 - 2 * o, -hw, -5)
      ..close();
    _shade(c, cup, _petalFront);
    // Two sepals under it.
    for (final side in const [-1.0, 1.0]) {
      _solid(
        c,
        vfxLeaf(const Offset(0, 6), 9, math.pi / 2 - side * (0.9 + 0.5 * o)),
        _stem.face,
      );
    }
    c.restore();
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final open = _open(k);
    for (var i = 0; i < _roses.length; i++) {
      final (_, _, s, lean) = _roses[i];
      _rose(c, _head(i, k), s * 1.15, open, lean * 0.4);
    }
  }
}

/// A low obsidian bowl heaped with embers, glowing brighter and dimmer as
/// if it breathed.
class _EmberBowl extends KeepsakeArt {
  _EmberBowl() : super(const Color(0xFFFF6A2E));

  final StoneLight _stone = StoneLight(_kStone);
  final _Grains _sparks = _Grains(12);

  /// The heap, and the coals it is made of.
  static final Path _heap = Path()
    ..moveTo(-42, -28)
    ..cubicTo(-34, -40, -14, -46, 2, -46)
    ..cubicTo(20, -46, 36, -40, 42, -28)
    ..close();
  static final List<Path> _coals = [for (var i = 0; i < 17; i++) _coal(i)];
  static final Path _allCoals = () {
    final p = Path();
    for (final c in _coals) {
      p.addPath(c, Offset.zero);
    }
    return p;
  }();

  static Path _coal(int i) {
    final u = hash01(i, 1) * 2 - 1;
    final x = u * 34;
    final top = -30 - 13 * (1 - u * u);
    final y = -29 + (top + 29) * (0.35 + 0.6 * hash01(i, 2));
    final r = 6 + 4 * hash01(i, 3);
    final pts = <Offset>[];
    const n = 6;
    for (var j = 0; j < n; j++) {
      final a = j / n * math.pi * 2 + hash01(i, 4) * 2;
      final rr = r * (0.7 + 0.4 * hash01(i * 7 + j, 5));
      pts.add(Offset(x + math.cos(a) * rr, y + math.sin(a) * rr * 0.7));
    }
    return Path()..addPolygon(pts, true);
  }

  @override
  Rect get box => const Rect.fromLTRB(-48, -64, 48, 4);

  @override
  void body(Canvas c) {
    final bowl = _poly(const [
      Offset(-46, -30),
      Offset(46, -30),
      Offset(36, -12),
      Offset(20, -2),
      Offset(-20, -2),
      Offset(-36, -12),
    ]);
    _solid(c, bowl, _stone.ink);
    _shade(c, bowl, _litAcross(_stone, -46, 46, k: 0.6));
    _block(c, _stone, const Rect.fromLTRB(-18, -4, 18, 2), bevel: 1);
  }

  double _breath(KeepsakeTime k) =>
      0.5 + 0.5 * math.sin(k.t * 1.1) + 0.5 * math.min(1.0, k.stir);

  @override
  void under(Canvas c, KeepsakeTime k) {
    final b = _breath(k);
    _groundPool(c, m, 0, 72, (0.25 + 0.45 * k.night) * (0.7 + 0.3 * b));
    paintDisc(
      c,
      m.pool,
      const Offset(0, -40),
      64,
      (0.3 + 0.45 * k.night) * (0.7 + 0.3 * b),
    );
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final b = _breath(k);
    // The fire in the heap, showing between the coals.
    _shade(
      c,
      _heap,
      ui.Gradient.radial(
        const Offset(0, -30),
        46,
        [
          _a(const Color(0xFFFFC27A), 0.55 + 0.4 * b),
          _a(const Color(0xFFE0501A), 0.9),
          const Color(0xFF5A1606),
        ],
        const [0.0, 0.45, 1.0],
      ),
    );
    // The coals: dark, their undersides lit by it.
    _solid(c, _allCoals, const Color(0xFF140A08));
    _shade(
      c,
      _allCoals,
      ui.Gradient.linear(const Offset(0, -26), const Offset(0, -46), [
        _a(const Color(0xFFB8401A), 0.55 + 0.35 * b),
        const Color(0x00B8401A),
      ]),
    );
    // A few coals glowing through, each in its own time.
    for (var i = 0; i < _coals.length; i += 3) {
      final heat =
          0.5 + 0.5 * math.sin(k.t * (0.5 + 0.4 * _hash(i, 6)) + i * 1.7);
      _solid(
        c,
        _coals[i],
        _a(const Color(0xFFFF7A34), 0.6 * heat * (0.5 + 0.5 * b)),
      );
    }
    // The lip of the bowl over the heap's foot.
    _glass(
      c,
      m,
      _poly(const [
        Offset(-46, -30),
        Offset(46, -30),
        Offset(42, -26),
        Offset(-42, -26),
      ]),
      const Offset(0, -32),
      40,
    );
    _sparks.clear();
    for (var i = 0; i < 6; i++) {
      final f = _frac(k.t * (0.2 + 0.1 * _hash(i, 5)) + _hash(i, 6));
      _sparks.add(
        (_hash(i, 7) - 0.5) * 50 + math.sin(k.t + i) * 4,
        -44 - f * 50,
      );
    }
    _sparks.draw(c, 2, _a(const Color(0xFFFFB46A), 0.5 * b));
  }
}

/// A nest woven of dark glass twigs, embers glowing in its hollow, slow as
/// a sleeper's breath; the twigs catch their light. At night a resident
/// sleeps in it.
class _EmberNest extends KeepsakeArt {
  _EmberNest() : super(const Color(0xFFFF7A3D));

  final _Grains _embers = _Grains(30);
  final _Grains _hot = _Grains(30);

  @override
  Rect get box => const Rect.fromLTRB(-100, -66, 100, 6);

  /// Down in its hollow, the near wall over its feet.
  @override
  List<Offset> seats(KeepsakeTime k) => const [Offset(0, 34)];

  @override
  bool get hasFront => true;

  /// Twigs woven round the bowl: arcs of it, the far side's ([front]
  /// false) or the near side's.
  static Path _weave(int n, int seed, bool front) {
    final p = Path();
    for (var i = 0; i < n; i++) {
      final rx = 70 + 24 * hash01(i, seed);
      final ry = front
          ? 12 + 14 * hash01(i, seed + 1)
          : 8 + 8 * hash01(i, seed + 1);
      final cy = front
          ? -38 + 10 * hash01(i, seed + 2)
          : -40 + 8 * hash01(i, seed + 2);
      final span = 0.7 + 0.8 * hash01(i, seed + 3);
      final a0 =
          (front ? 0.0 : math.pi) + (math.pi - span) * hash01(i, seed + 4);
      final pts = <Offset>[
        for (var j = 0; j <= 7; j++)
          Offset(
            math.cos(a0 + span * j / 7) * rx,
            cy +
                math.sin(a0 + span * j / 7) * ry +
                (hash01(i * 9 + j, seed + 5) - 0.5) * 3,
          ),
      ];
      p.addPath(
        vfxRibbon(pts, 0, 3.4 + 1.8 * hash01(i, seed + 6), taperIn: true),
        Offset.zero,
      );
    }
    return p;
  }

  /// Twig ends poking out past its rim, the far side's or the near side's:
  /// a nest is never a smooth bowl.
  static Path _strays(int n, int seed, bool front) {
    final p = Path();
    for (var i = 0; i < n; i++) {
      final a =
          (front ? 0.15 : math.pi + 0.15) + (math.pi - 0.3) * hash01(i, seed);
      final at = Offset(
        math.cos(a) * 82,
        -40 + math.sin(a) * (front ? 20 : 12),
      );
      final out = a + (hash01(i, seed + 1) - 0.5) * 1.6;
      final len = 16 + 18 * hash01(i, seed + 2);
      final tip =
          at + Offset(math.cos(out) * len, math.sin(out) * len * 0.6 - 4);
      p.addPath(
        vfxRibbon([at, Offset.lerp(at, tip, 0.5)!, tip], 3.6, 1.2),
        Offset.zero,
      );
    }
    return p;
  }

  static final Path _far = _weave(26, 10, false)
    ..addPath(_strays(9, 70, false), Offset.zero);
  static final Path _near = _weave(34, 40, true)
    ..addPath(_strays(8, 80, true), Offset.zero);

  /// The body of it under the twigs, and the hollow in its top.
  static final Path _mass = Path()
    ..moveTo(-96, -40)
    ..quadraticBezierTo(-94, 4, 0, 4)
    ..quadraticBezierTo(94, 4, 96, -40)
    ..quadraticBezierTo(80, -56, 0, -56)
    ..quadraticBezierTo(-80, -56, -96, -40)
    ..close();
  static final Path _hollow = Path()
    ..addOval(const Rect.fromLTRB(-74, -52, 74, -30));

  /// Dark glass, lit from the hollow: the far twigs from below, the near
  /// ones along their tops.
  static final ui.Shader _farLit = ui.Gradient.linear(
    const Offset(0, -58),
    const Offset(0, -32),
    const [Color(0xFF2A1810), Color(0xFF9A4A26)],
  );
  static final ui.Shader _nearLit = ui.Gradient.linear(
    const Offset(0, -40),
    const Offset(0, 4),
    const [Color(0xFF8A4224), Color(0xFF3A2016), Color(0xFF120A08)],
    const [0.0, 0.35, 1.0],
  );

  @override
  void body(Canvas c) {
    _solid(c, _mass, const Color(0xFF0E0807));
    _solid(c, _hollow, const Color(0xFF080404));
    _shade(c, _far, _farLit);
  }

  double _breath(KeepsakeTime k) =>
      0.5 + 0.5 * math.sin(k.t * 1.2) + 0.6 * math.min(1.0, k.stir);

  @override
  void under(Canvas c, KeepsakeTime k) {
    final b = _breath(k);
    _groundPool(c, m, 0, 120, (0.25 + 0.4 * k.night) * (0.7 + 0.3 * b));
    paintDisc(
      c,
      m.pool,
      const Offset(0, -50),
      90,
      (0.2 + 0.35 * k.night) * (0.7 + 0.3 * b),
    );
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final b = _breath(k);
    // The hollow, lit from the embers in it.
    c.save();
    c.clipPath(_hollow);
    paintDisc(c, m.leak, const Offset(0, -38), 80, 0.7 + 0.3 * b);
    paintDisc(c, m.spark, const Offset(0, -36), 36, 0.2 + 0.2 * b);
    c.restore();
    _embers.clear();
    _hot.clear();
    for (var i = 0; i < 26; i++) {
      final a = _hash(i, 1) * math.pi * 2;
      final r = math.sqrt(_hash(i, 2));
      final x = math.cos(a) * 66 * r, y = -41 + math.sin(a) * 9 * r;
      final heat = (0.5 + 0.5 * math.sin(k.t * 1.2 + _hash(i, 3) * 3)) * b;
      (heat > 0.6 ? _hot : _embers).add(x, y);
    }
    _embers.draw(c, 3.2, const Color(0xFFB8401A));
    _hot.draw(c, 3, const Color(0xFFFFB46A));
  }

  /// Its near wall, up to the rim, over whoever sleeps in it.
  static final Path _wall = Path()
    ..moveTo(-96, -40)
    ..quadraticBezierTo(0, -22, 96, -40)
    ..quadraticBezierTo(94, 4, 0, 4)
    ..quadraticBezierTo(-94, 4, -96, -40)
    ..close();

  @override
  void front(Canvas c, KeepsakeTime k) {
    final b = _breath(k);
    _solid(c, _wall, const Color(0xFF0E0807));
    _solid(c, _near, const Color(0xFF120A08));
    _shade(c, _near, _nearLit, 0.7 + 0.3 * b);
  }
}

/// A small tree of dark glass leaves hung with glowing garnet fruit. The
/// residents climb into its branches; flyers rest at its top.
class _PomegranateTree extends KeepsakeArt {
  _PomegranateTree() : super(const Color(0xFFE8405A));

  final StoneLight _bark = StoneLight(const Color(0xFF9A7A5A));

  /// Each branch as a curve: foot, bend, tip; and its width at its foot.
  static const _branches = <(Offset, Offset, Offset, double)>[
    (Offset(-10, -140), Offset(-60, -160), Offset(-126, -186), 15),
    (Offset(0, -190), Offset(56, -206), Offset(118, -236), 13),
    (Offset(-4, -244), Offset(-30, -282), Offset(-70, -306), 10),
    (Offset(2, -252), Offset(22, -290), Offset(52, -322), 9),
  ];

  /// Clumps of leaves: (centre, rx, ry, count).
  static const _clumps = <(Offset, double, double, int)>[
    (Offset(-120, -206), 52, 34, 30),
    (Offset(116, -256), 54, 34, 30),
    (Offset(-66, -322), 52, 36, 30),
    (Offset(50, -336), 50, 34, 28),
    (Offset(-6, -298), 58, 40, 34),
    (Offset(-64, -244), 36, 24, 16),
    (Offset(62, -290), 36, 24, 16),
  ];

  /// The fruit: where it hangs, and how big.
  static const _fruit = <(Offset, double)>[
    (Offset(-140, -176), 13),
    (Offset(-100, -190), 11),
    (Offset(96, -228), 12),
    (Offset(136, -242), 13),
    (Offset(-78, -296), 12),
    (Offset(-34, -278), 11),
    (Offset(58, -310), 13),
    (Offset(22, -286), 11),
    (Offset(-54, -226), 10),
  ];

  @override
  Rect get box => const Rect.fromLTRB(-176, -380, 176, 8);

  /// On its two low branches.
  @override
  List<Offset> seats(KeepsakeTime k) => const [
    Offset(-80, 172),
    Offset(74, 220),
  ];

  @override
  void body(Canvas c) {
    final trunk = Path()
      ..moveTo(-36, 4)
      ..quadraticBezierTo(-12, -40, -18, -140)
      ..quadraticBezierTo(-10, -220, -6, -262)
      ..lineTo(8, -262)
      ..quadraticBezierTo(14, -200, 16, -140)
      ..quadraticBezierTo(14, -40, 40, 4)
      ..close();
    _solid(c, trunk, _bark.ink);
    _shade(c, trunk, _litAcross(_bark, -36, 40, k: 0.5));
    for (final (a, b, tip, w) in _branches) {
      final branch = vfxRibbon(vfxQuadSpine(a, b, tip), w * 2, w * 0.5);
      _solid(c, branch, _bark.ink);
      _shade(
        c,
        branch,
        _litAcross(
          _bark,
          math.min(a.dx, tip.dx),
          math.max(a.dx, tip.dx),
          k: 0.45,
        ),
      );
    }
    // The crown: a dark mass under each clump, then its leaves of glass —
    // lit on their upper left, dark underneath.
    for (final (mid, rx, ry, _) in _clumps) {
      c.save();
      c.translate(mid.dx, mid.dy);
      c.scale(rx, ry);
      paintDisc(c, _crownShade, Offset.zero, 1, 0.9);
      c.restore();
    }
    var seed = 0;
    for (final (mid, rx, ry, count) in _clumps) {
      for (var i = 0; i < count; i++) {
        seed++;
        final a = _hash(seed, 1) * math.pi * 2;
        final r = math.sqrt(_hash(seed, 2));
        final at = mid + Offset(math.cos(a) * rx * r, math.sin(a) * ry * r);
        final lit = (-math.cos(a) * 0.55 - math.sin(a) * 0.8) * r;
        final angle = a + (_hash(seed, 3) - 0.5) * 1.4;
        final len = 22 + 10 * _hash(seed, 4);
        final leaf = vfxLeaf(at, len, angle);
        final rgb = _mix(
          0x0B140D,
          0x4E8050,
          (0.25 + 0.6 * lit).clamp(0.0, 1.0),
        );
        _solid(c, leaf, Color(_argb(rgb, 1)));
        _solid(
          c,
          vfxRibbon(
            [at, at + Offset(math.cos(angle), math.sin(angle)) * len * 0.8],
            1.2,
            0.3,
          ),
          Color(_argb(_mix(rgb, 0x9FD49A, 0.3), 0.6)),
        );
      }
    }
  }

  static final ui.Shader _crownShade = ui.Gradient.radial(
    Offset.zero,
    1,
    const [Color(0xCC0A120B), Color(0x660A120B), Color(0x000A120B)],
    const [0.0, 0.6, 1.0],
  );

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, const Offset(0, -260), 170, 0.15 + 0.35 * k.night);
    _groundPool(c, m, 0, 150, 0.12 + 0.3 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    for (var i = 0; i < _fruit.length; i++) {
      final (at, r) = _fruit[i];
      final sway = math.sin(k.t * 0.8 + i * 1.7) * 2 * (1 + 1.5 * k.stir);
      final p = at + Offset(sway, sway.abs() * 0.3);
      paintDisc(c, m.pool, p, r * 3, 0.15 + 0.5 * k.night);
      // A short stalk, the fruit, and the little crown at its top.
      _solid(
        c,
        _poly([
          p + Offset(-1.4, -r),
          p + Offset(1.4, -r),
          at + const Offset(1, -18),
          at + const Offset(-1, -18),
        ]),
        _bark.face,
      );
      paintOrb(c, m, p, r);
      paintDisc(
        c,
        m.spark,
        p + Offset(r * 0.1, r * 0.15),
        r * 0.9,
        0.35 * k.night,
      );
      _solid(
        c,
        _poly([
          p + Offset(-r * 0.42, -r * 0.82),
          p + Offset(-r * 0.3, -r * 1.3),
          p + Offset(-r * 0.1, -r * 0.95),
          p + Offset(r * 0.1, -r * 1.32),
          p + Offset(r * 0.28, -r * 0.95),
          p + Offset(r * 0.42, -r * 1.25),
          p + Offset(r * 0.46, -r * 0.8),
        ]),
        Color.lerp(m.ink, m.essence, 0.45)!,
      );
    }
  }
}

// ═══ THE STILL-ROOM ═══════════════════════════════════════════════════════

/// Bundles of dried herbs hung upside down from an obsidian frame, swaying
/// a little.
class _HerbRack extends KeepsakeArt {
  _HerbRack() : super(const Color(0xFFD8C27A));

  static const _barY = -132.0;

  /// (x, length, spread, color): each bundle — sage, lavender, tansy,
  /// rosemary, a rusty dock.
  static const _bundles = <(double, double, double, int)>[
    (-36, 62, 22, 0x6E7E50),
    (-15, 74, 20, 0x7A6E94),
    (5, 58, 24, 0x9A8448),
    (25, 70, 20, 0x5E7860),
    (44, 52, 18, 0x8A6448),
  ];

  final StoneLight _stone = StoneLight(_kStone);
  late final List<(Path, Path)> _shapes = [
    for (var i = 0; i < _bundles.length; i++) _bundle(i),
  ];

  /// A bundle hung from its tie at the origin: its stems, gathered at the
  /// top and fanning down, and its leaves, hanging down off them.
  (Path, Path) _bundle(int i) {
    final (_, len, spread, _) = _bundles[i];
    final stems = Path(), leaves = Path();
    const n = 6;
    for (var j = 0; j < n; j++) {
      final f = j / (n - 1) - 0.5;
      final seed = i * 13 + j;
      final end = Offset(
        f * spread + (_hash(seed, 1) - 0.5) * 5,
        len * (0.78 + 0.22 * _hash(seed, 2)),
      );
      final mid = Offset(f * spread * 0.35, len * 0.4);
      stems.addPath(
        vfxRibbon([const Offset(0, 6), mid, end], 2.2, 1.2),
        Offset.zero,
      );
      for (var q = 0; q < 5; q++) {
        final g = 0.22 + 0.19 * q;
        final at = Offset.lerp(mid, end, g)!;
        final out =
            (q.isEven ? -1 : 1) * (0.45 + 0.45 * _hash(seed * 5 + q, 3));
        final a = math.pi / 2 + f * 0.9 + out;
        leaves.addPath(
          vfxLeaf(at, 9 + 6 * _hash(seed * 5 + q, 4), a),
          Offset.zero,
        );
      }
      leaves.addPath(
        vfxLeaf(end - const Offset(0, 4), 10, math.pi / 2 + f * 0.6),
        Offset.zero,
      );
    }
    return (stems, leaves);
  }

  @override
  Rect get box => const Rect.fromLTRB(-60, -152, 64, 4);

  @override
  void body(Canvas c) {
    for (final x in const [-52.0, 56.0]) {
      c.save();
      c.translate(x, 0);
      _plinth(c, _stone, 22, 7);
      c.restore();
      _shaft(c, _stone, x, -7, _barY, 10, 8);
    }
    _block(
      c,
      _stone,
      const Rect.fromLTRB(-60, _barY - 8, 64, _barY),
      bevel: 1.8,
    );
    for (final (x, _, _, _) in _bundles) {
      _solid(
        c,
        _poly([
          Offset(x - 1.2, _barY),
          Offset(x + 1.2, _barY),
          Offset(x + 1.2, _barY + 8),
          Offset(x - 1.2, _barY + 8),
        ]),
        const Color(0xFF6E6250),
      );
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) =>
      _groundPool(c, m, 0, 70, 0.1 + 0.2 * k.night);

  @override
  void live(Canvas c, KeepsakeTime k) {
    // Dried herbs are lit by the day, not from inside: dimmer by night.
    final lit = 0.35 + 0.65 * k.daylight;
    for (var i = 0; i < _bundles.length; i++) {
      final (x, _, spread, rgb) = _bundles[i];
      final (stems, leaves) = _shapes[i];
      final sway = math.sin(k.t * 0.9 + i * 1.7) * 0.05 * (1 + 2.5 * k.stir);
      c.save();
      c.translate(x, _barY + 7);
      c.rotate(sway);
      _solid(c, stems, Color(_argb(_mix(0x0A0A08, rgb, 0.2 + 0.3 * lit), 1)));
      _solid(
        c,
        leaves,
        Color(_argb(_mix(0x080806, rgb, 0.25 + 0.45 * lit), 1)),
      );
      _shade(
        c,
        leaves,
        ui.Gradient.linear(Offset(-spread * 0.6, 0), Offset(spread * 0.6, 0), [
          Color(_argb(_mix(rgb, 0xFFF2D8, 0.35), 0.45 * lit)),
          Color(_argb(rgb, 0.0)),
        ]),
      );
      // The twine it is tied with.
      _solid(
        c,
        Path()..addRect(const Rect.fromLTRB(-3, 3, 3, 7)),
        Color.lerp(
          const Color(0xFF2A2218),
          const Color(0xFF9A8458),
          0.2 + 0.3 * lit,
        )!,
      );
      c.restore();
    }
  }
}

/// A shelf of glass flasks, each lit its own color and bubbling slowly.
class _RetortShelf extends KeepsakeArt {
  _RetortShelf() : super(const Color(0xFFBFE9FF));

  static const _low = -60.0, _high = -128.0;
  final StoneLight _stone = StoneLight(_kStone);
  final _Grains _bubbles = _Grains(60);

  /// (glass, liquid, its light's centre, color, the glass's main body).
  late final List<(Path, Path, Offset, Color, Rect)> _flasks = _make();

  static Path _round(Offset base, double r, double neck) => Path()
    ..addOval(Rect.fromCircle(center: base + Offset(0, -r), radius: r))
    ..addRect(
      Rect.fromLTRB(
        base.dx - r * 0.28,
        base.dy - r * 2 - neck,
        base.dx + r * 0.28,
        base.dy - r * 1.6,
      ),
    );

  List<(Path, Path, Offset, Color, Rect)> _make() {
    (Path, Path, Offset, Color, Rect) flask(
      Path glass,
      Rect body,
      double level,
      Color col,
    ) {
      final liquid = Path.combine(
        PathOperation.intersect,
        glass,
        Path()..addRect(
          Rect.fromLTRB(
            body.left - 1,
            body.bottom - body.height * level,
            body.right + 1,
            body.bottom + 1,
          ),
        ),
      );
      return (
        glass,
        liquid,
        Offset(body.center.dx, body.bottom - body.height * level * 0.5),
        col,
        body,
      );
    }

    final cone = _poly(const [
      Offset(-26, _low),
      Offset(2, _low),
      Offset(-8, _low - 26),
      Offset(-8, _low - 40),
      Offset(-16, _low - 40),
      Offset(-16, _low - 26),
    ]);
    final vial = Path()
      ..addRRect(
        RRect.fromLTRBR(14, _low - 46, 26, _low, const Radius.circular(5)),
      );
    final retort = Path()
      ..addOval(
        Rect.fromCircle(center: const Offset(-38, _high - 15), radius: 15),
      )
      ..addPath(
        vfxRibbon(
          const [
            Offset(-30, _high - 26),
            Offset(-18, _high - 38),
            Offset(-2, _high - 36),
            Offset(8, _high - 28),
          ],
          7,
          3,
        ),
        Offset.zero,
      );
    final bottle = Path()
      ..addRRect(
        RRect.fromLTRBR(14, _high - 34, 34, _high, const Radius.circular(4)),
      )
      ..addRect(const Rect.fromLTRB(20, _high - 44, 28, _high - 33));
    return [
      flask(
        _round(const Offset(-50, _low), 15, 10),
        Rect.fromCircle(center: const Offset(-50, _low - 15), radius: 15),
        0.55,
        const Color(0xFF5FE0C8),
      ),
      flask(
        cone,
        const Rect.fromLTRB(-26, _low - 40, 2, _low),
        0.45,
        const Color(0xFFB48CFF),
      ),
      flask(
        vial,
        const Rect.fromLTRB(14, _low - 46, 26, _low),
        0.6,
        const Color(0xFFFFB45A),
      ),
      flask(
        _round(const Offset(46, _low), 11, 8),
        Rect.fromCircle(center: const Offset(46, _low - 11), radius: 11),
        0.5,
        const Color(0xFFF29BC0),
      ),
      flask(
        retort,
        Rect.fromCircle(center: const Offset(-38, _high - 15), radius: 15),
        0.42,
        const Color(0xFF9FE07A),
      ),
      flask(
        bottle,
        const Rect.fromLTRB(14, _high - 34, 34, _high),
        0.62,
        const Color(0xFF7FB0FF),
      ),
      flask(
        _round(const Offset(54, _high), 10, 7),
        Rect.fromCircle(center: const Offset(54, _high - 10), radius: 10),
        0.5,
        const Color(0xFFFFD27A),
      ),
    ];
  }

  @override
  Rect get box => const Rect.fromLTRB(-76, -176, 76, 4);

  @override
  void body(Canvas c) {
    for (final x in const [-66.0, 66.0]) {
      _shaft(c, _stone, x, 2, -150, 10, 8);
    }
    _block(c, _stone, const Rect.fromLTRB(-74, _low, 74, _low + 8), bevel: 2);
    _block(c, _stone, const Rect.fromLTRB(-74, _high, 74, _high + 8), bevel: 2);
    _block(c, _stone, const Rect.fromLTRB(-72, -10, 72, 0), bevel: 1.6);
    for (final (glass, liquid, _, col, body) in _flasks) {
      final lit = StoneLight(col);
      _solid(c, glass, const Color(0x2A0C1018));
      // The liquid: deep at its foot, lit toward its surface.
      _solid(c, liquid, Color.lerp(lit.ink, col, 0.3)!);
      final lb = liquid.getBounds();
      _shade(
        c,
        liquid,
        ui.Gradient.linear(lb.topCenter, lb.bottomCenter, [
          _a(Color.lerp(col, lit.hot, 0.3)!, 0.75),
          _a(col, 0.15),
        ]),
      );
      _clearGlass(c, glass, body);
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 80, 0.1 + 0.3 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    _bubbles.clear();
    for (var i = 0; i < _flasks.length; i++) {
      final (_, liquid, heart, col, _) = _flasks[i];
      final breathe = 0.7 + 0.3 * math.sin(k.t * 0.7 + i * 1.9);
      paintDisc(
        c,
        stoneLightFor(col).leak,
        heart,
        28,
        (0.35 + 0.6 * k.night) * breathe,
      );
      final b = liquid.getBounds();
      for (var j = 0; j < 3; j++) {
        final f = _frac(
          k.t * (0.25 + 0.2 * _hash(i * 3 + j, 1)) * (1 + k.stir) +
              _hash(i * 3 + j, 2),
        );
        _bubbles.add(
          b.left + b.width * (0.3 + 0.4 * _hash(i * 3 + j, 3)),
          b.bottom - 2 - f * (b.height - 3),
        );
      }
    }
    _bubbles.draw(c, 2, _a(const Color(0xFFEFFAFF), 0.6));
  }
}

/// A glass still over a small flame: the liquid in its boiler simmers, its
/// vapour climbs into the head as grains, and drops run down the beak into
/// a flask that fills with their light. A resident who comes to it bows
/// over the flask; one of Water, Steam or Fire stirs it, and it boils hard.
class _Alembic extends KeepsakeArt {
  _Alembic() : super(const Color(0xFF7FE0C8));

  static const Offset _boiler = Offset(-48, -108); // its centre
  static const double _br = 40;
  static const Offset _head = Offset(-48, -166);
  static const Offset _flask = Offset(82, -46);
  static const double _fr = 26;

  final StoneLight _stone = StoneLight(_kStone);
  final StoneLight _brassLight = StoneLight(_kBrass);
  final StoneLight _glassLight = StoneLight(const Color(0xFFBFE9FF));
  final StoneLight _fire = StoneLight(const Color(0xFFFF8A3D));
  final _Grains _bubbles = _Grains(60);
  final _Grains _vapour = _Grains(80);
  final _Grains _drops = _Grains(16);

  /// The beak: from the head's lip, down to the flask's neck.
  static const List<Offset> _beak = [
    Offset(-26, -170),
    Offset(10, -152),
    Offset(46, -120),
    Offset(72, -88),
    Offset(80, -76),
  ];

  static final Path _boilerPath = Path()
    ..addOval(Rect.fromCircle(center: _boiler, radius: _br));
  static final Path _headPath = Path()
    ..addOval(Rect.fromCenter(center: _head, width: 58, height: 44));
  static final Path _neck = _poly([
    _boiler + const Offset(-10, -_br + 4),
    _boiler + const Offset(10, -_br + 4),
    _head + const Offset(9, 18),
    _head + const Offset(-9, 18),
  ]);
  static final Path _flaskPath = Path()
    ..addOval(Rect.fromCircle(center: _flask, radius: _fr))
    ..addRect(
      Rect.fromLTRB(
        _flask.dx - 7,
        _flask.dy - _fr - 16,
        _flask.dx + 7,
        _flask.dy - _fr + 6,
      ),
    );

  @override
  Rect get box => const Rect.fromLTRB(-104, -204, 118, 4);

  /// Where a visitor stands to bow over it: beyond the stove, or beyond
  /// the flask.
  @override
  List<Offset> seats(KeepsakeTime k) => const [Offset(-158, 0), Offset(176, 0)];

  @override
  void body(Canvas c) {
    // The stove: a block of stone with its fire door, the boiler's ring.
    _block(c, _stone, const Rect.fromLTRB(-88, -62, -8, 0), bevel: 3);
    _block(c, _stone, const Rect.fromLTRB(-92, -68, -4, -60), bevel: 2);
    final door = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          const Rect.fromLTRB(-62, -40, -34, -8),
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
        ),
      );
    _solid(c, door, const Color(0xFF07070A));
    // The receiver's stand: a short brass tripod seen from the side.
    for (final (x0, x1) in const [(66.0, 58.0), (98.0, 106.0)]) {
      _shaft(c, _brassLight, (x0 + x1) / 2, 0, -24, 5, 4, lean: x0 - x1);
    }
    _block(c, _brassLight, const Rect.fromLTRB(56, -26, 108, -20), bevel: 1.5);
    // The beak, a tapering tube of glass from head to flask.
    final beak = vfxRibbon(_beak, 13, 7);
    _glass(c, _glassLight, beak, const Offset(20, -140), 60);
    _shade(
      c,
      vfxRibbon([for (final p in _beak) p + const Offset(-1, -3.2)], 3.2, 1.6),
      ui.Gradient.linear(_beak.first, _beak.last, [
        _a(_glassLight.rim, 0.55),
        _a(_glassLight.rim, 0.2),
      ]),
    );
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    final flick = 0.85 + 0.15 * math.sin(k.t * 7.3) * math.sin(k.t * 2.9);
    _groundPool(c, _fire, -48, 110, (0.3 + 0.55 * k.night) * flick);
    paintDisc(c, m.pool, _boiler, 90, 0.35 + 0.45 * k.night);
    paintDisc(c, m.pool, _flask, 60, 0.3 + 0.5 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final boil = 0.35 + 0.65 * math.min(1.0, k.stir);
    _flame(
      c,
      const Offset(-48, -60),
      22 + 16 * boil,
      22,
      k.t,
      5,
      core: const Color(0xFFFFE2A0),
      body: const Color(0xFFFF7A2E),
    );
    paintDisc(c, _fire.spark, const Offset(-48, -18), 18, 0.45 + 0.3 * boil);

    // The boiler: round glass, the liquid filling its lower part.
    final level = _boiler.dy - 4 + math.sin(k.t * 3.1) * 1.4 * boil;
    c.save();
    c.clipPath(_boilerPath);
    _solid(
      c,
      Path()..addRect(Rect.fromLTRB(-100, level, 0, _boiler.dy + _br)),
      Color.lerp(m.ink, m.essence, 0.55)!,
    );
    paintDisc(
      c,
      m.leak,
      _boiler + const Offset(0, 22),
      50,
      0.9 + 0.3 * k.night,
    );
    _solid(
      c,
      Path()..addOval(
        Rect.fromCenter(
          center: Offset(_boiler.dx, level),
          width: _br * 1.9,
          height: 5,
        ),
      ),
      _a(m.hot, 0.35),
    );
    c.restore();
    _bubbles.clear();
    final nb = (14 + 26 * boil).round();
    for (var i = 0; i < nb; i++) {
      final f = _frac(k.t * (0.7 + 0.6 * _hash(i, 1)) + _hash(i, 2));
      final x = _boiler.dx + (_hash(i, 3) - 0.5) * _br * 1.3;
      final y = _boiler.dy + _br * 0.85 - f * (_boiler.dy + _br * 0.85 - level);
      _bubbles.add(x + math.sin(k.t * 4 + i) * 1.5, y);
    }
    _bubbles.draw(c, 2.6, _a(m.hot, 0.7));
    _clearGlass(c, _boilerPath, Rect.fromCircle(center: _boiler, radius: _br));

    // The neck and the head: vapour climbs into it and gathers.
    _vapour.clear();
    final nv = (20 + 40 * boil).round();
    for (var i = 0; i < nv; i++) {
      final f = _frac(k.t * (0.18 + 0.12 * _hash(i, 5)) + _hash(i, 6));
      final Offset at;
      if (f < 0.45) {
        final g = f / 0.45;
        at = Offset(
          _boiler.dx + (_hash(i, 7) - 0.5) * 12,
          level - g * (level - _head.dy - 14),
        );
      } else {
        final g = (f - 0.45) / 0.55;
        final a = -math.pi / 2 + (_hash(i, 8) - 0.5) * 2.4 + g * 1.2;
        at = _head + Offset(math.cos(a) * 20 * g, 6 + math.sin(a) * 12 * g);
      }
      _vapour.add(at.dx, at.dy);
    }
    _vapour.draw(c, 2.2, _a(const Color(0xFFE6FFF8), 0.4 + 0.25 * boil));
    _clearGlass(
      c,
      _neck,
      Rect.fromCenter(center: _head, width: 30, height: 30),
    );
    _clearGlass(
      c,
      _headPath,
      Rect.fromCenter(center: _head, width: 58, height: 58),
    );
    _block(
      c,
      _brassLight,
      Rect.fromCenter(
        center: _head + const Offset(0, 22),
        width: 24,
        height: 6,
      ),
      bevel: 1.4,
    );

    // Drops running down the beak.
    _drops.clear();
    for (var i = 0; i < 4; i++) {
      final f = _frac(k.t * (0.22 + 0.25 * boil) + i / 4);
      final seg = f * (_beak.length - 1);
      final j = seg.floor().clamp(0, _beak.length - 2);
      final p = Offset.lerp(_beak[j], _beak[j + 1], seg - j)!;
      _drops.add(p.dx, p.dy + 1);
    }
    _drops.draw(c, 4, _a(m.hot, 0.85));

    // The receiving flask: its light grows as it fills, then it is
    // emptied (a slow loop), so it is never just full.
    final fill = 0.25 + 0.6 * _frac(k.t / 40);
    c.save();
    c.clipPath(_flaskPath);
    final top = _flask.dy + _fr - fill * _fr * 2;
    _solid(
      c,
      Path()..addRect(
        Rect.fromLTRB(_flask.dx - _fr, top, _flask.dx + _fr, _flask.dy + _fr),
      ),
      Color.lerp(m.ink, m.essence, 0.7)!,
    );
    paintDisc(
      c,
      m.spark,
      Offset(_flask.dx, _flask.dy + 8),
      22 * fill + 6,
      0.4 + 0.4 * k.night,
    );
    c.restore();
    _clearGlass(c, _flaskPath, Rect.fromCircle(center: _flask, radius: _fr));
  }
}

/// A tall glass bell jar on a brass-bound base. A resident sits inside it
/// on a cushion, under glass like a specimen.
class _BellJar extends KeepsakeArt {
  _BellJar() : super(const Color(0xFFCFE6FF));

  static const _seatY = -46.0;
  static const double _w = 92, _shoulder = -214, _top = -296;
  final StoneLight _stone = StoneLight(_kStone);
  final StoneLight _brassL = StoneLight(_kBrass);
  final StoneLight _velvet = StoneLight(const Color(0xFF6A7ACF));
  final StoneLight _knob = StoneLight(const Color(0xFFCFE6FF));
  final _Grains _motes = _Grains(24);

  static final Path _jar = Path()
    ..moveTo(-_w, -38)
    ..lineTo(-_w, _shoulder)
    ..cubicTo(-_w, _top + 10, -_w * 0.5, _top, 0, _top)
    ..cubicTo(_w * 0.5, _top, _w, _top + 10, _w, _shoulder)
    ..lineTo(_w, -38)
    ..close();

  /// The back of the glass: dark, catching the light down both sides as
  /// a cylinder does.
  static final ui.Shader _backGlass = ui.Gradient.linear(
    const Offset(-_w, 0),
    const Offset(_w, 0),
    const [
      Color(0x5A7FA9CC),
      Color(0x1E3C5470),
      Color(0x0A2A3A50),
      Color(0x1E3C5470),
      Color(0x447FA9CC),
    ],
    const [0.0, 0.1, 0.5, 0.9, 1.0],
  );

  @override
  Rect get box => const Rect.fromLTRB(-112, -312, 112, 4);

  @override
  List<Offset> seats(KeepsakeTime k) => const [Offset(0, -_seatY)];

  @override
  bool get hasFront => true;

  @override
  void body(Canvas c) {
    _plinth(c, _stone, 224, 26, steps: 2);
    _block(c, _brassL, const Rect.fromLTRB(-100, -38, 100, -26), bevel: 1.6);
    _shade(c, _jar, _backGlass);
    // The cushion it sits on.
    final cushion = Path()
      ..moveTo(-66, -38)
      ..quadraticBezierTo(-62, _seatY - 6, 0, _seatY - 4)
      ..quadraticBezierTo(62, _seatY - 6, 66, -38)
      ..close();
    _solid(c, cushion, _velvet.ink);
    _shade(c, cushion, _litAcross(_velvet, -66, 66, k: 0.9));
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 130, 0.15 + 0.35 * k.night);
    paintDisc(c, m.pool, const Offset(0, -170), 120, 0.15 + 0.3 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    // A lamp's light from above, and dust turning in it.
    paintDisc(c, m.leak, const Offset(0, -250), 80, 0.2 + 0.25 * k.night);
    _motes.clear();
    for (var i = 0; i < 18; i++) {
      final a = k.t * (0.08 + 0.06 * _hash(i, 1)) + _hash(i, 2) * 6.28;
      _motes.add(
        (_hash(i, 3) - 0.5) * 150 + math.sin(a) * 10,
        -80 - _hash(i, 4) * 190 + math.cos(a * 0.7) * 12,
      );
    }
    _motes.draw(c, 2, _a(const Color(0xFFE6F0FF), 0.35));
  }

  @override
  void front(Canvas c, KeepsakeTime k) {
    // The near glass: clear, its edges bright, the window it gives back
    // in a long soft band down its left and over its shoulder.
    _shade(
      c,
      _jar,
      ui.Gradient.linear(
        const Offset(-_w, 0),
        const Offset(_w, 0),
        const [
          Color(0x55DDF0FF),
          Color(0x10CFE8FF),
          Color(0x00FFFFFF),
          Color(0x00FFFFFF),
          Color(0x10CFE8FF),
          Color(0x40DDF0FF),
        ],
        const [0.0, 0.08, 0.2, 0.8, 0.92, 1.0],
      ),
    );
    final band = Path()
      ..moveTo(-_w + 12, -60)
      ..lineTo(-_w + 12, _shoulder + 6)
      ..quadraticBezierTo(-_w + 16, _top + 26, -_w * 0.36, _top + 10)
      ..quadraticBezierTo(-_w + 26, _top + 34, -_w + 24, _shoulder + 10)
      ..lineTo(-_w + 24, -60)
      ..close();
    _shade(
      c,
      band,
      ui.Gradient.linear(
        const Offset(0, -60),
        const Offset(0, _top),
        const [Color(0x00FFFFFF), Color(0x30FFFFFF), Color(0x50FFFFFF)],
        const [0.0, 0.6, 1.0],
      ),
    );
    // The knob on its crown, and the brass it stands in.
    paintOrb(c, _knob, const Offset(0, _top - 8), 10);
    _block(c, _brassL, const Rect.fromLTRB(-100, -44, 100, -36), bevel: 1.4);
  }
}

/// A music box of dark lacquer bound in brass, its lid open: a drum of
/// pins turns and plucks a steel comb, lit warm from inside. The residents
/// hop to its tune.
class _MusicBox extends KeepsakeArt {
  _MusicBox() : super(const Color(0xFFE6C88A));

  static const _drum = Rect.fromLTRB(-44, -88, 30, -70);
  final StoneLight _lacquer = StoneLight(const Color(0xFF8A5A4A));
  final StoneLight _brassL = StoneLight(_kBrass);
  final _Grains _pins = _Grains(60);
  final _Grains _tune = _Grains(20);
  double _turn = 0, _lastT = -1;

  @override
  Rect get box => const Rect.fromLTRB(-84, -132, 96, 4);

  /// Where those hopping to it stand, clear of the box.
  @override
  List<Offset> seats(KeepsakeTime k) => const [Offset(-138, 0), Offset(146, 0)];

  @override
  void body(Canvas c) {
    // Its lid, open behind it, brass let into it.
    final lid = _poly(const [
      Offset(-74, -64),
      Offset(74, -64),
      Offset(84, -126),
      Offset(-62, -126),
    ]);
    _solid(c, lid, _lacquer.ink);
    _shade(c, lid, _litAcross(_lacquer, -74, 84, k: 0.9));
    final inlay = _poly(const [
      Offset(-56, -74),
      Offset(58, -74),
      Offset(66, -118),
      Offset(-46, -118),
    ]);
    _shade(c, inlay, _polishedBrass(-56, 66), 0.55);
    _shade(
      c,
      _poly(const [
        Offset(-74, -64),
        Offset(74, -64),
        Offset(84, -126),
        Offset(80, -126),
        Offset(70, -66),
        Offset(-70, -66),
      ]),
      _polishedBrass(-74, 84),
    );
    // The box on its four brass feet, bound in brass.
    for (final x in const [-70.0, -40.0, 38.0, 64.0]) {
      _shade(
        c,
        Path()..addRect(Rect.fromLTRB(x - 4, -6, x + 6, 0)),
        _polishedBrass(x - 4, x + 6),
      );
    }
    _block(c, _lacquer, const Rect.fromLTRB(-76, -64, 76, -6), bevel: 3);
    _shade(
      c,
      Path()..addRect(const Rect.fromLTRB(-76, -64, 76, -60)),
      _polishedBrass(-76, 76),
    );
    _shade(
      c,
      Path()..addRect(const Rect.fromLTRB(-76, -10, 76, -6)),
      _polishedBrass(-76, 76),
    );
    for (final x in const [-76.0, 70.0]) {
      _shade(
        c,
        Path()..addRect(Rect.fromLTRB(x, -64, x + 6, -6)),
        _polishedBrass(x, x + 6),
      );
    }
    // A band of brass let into its front.
    _shade(
      c,
      Path()..addRect(const Rect.fromLTRB(-64, -38, 64, -34)),
      _polishedBrass(-64, 64),
      0.85,
    );
    // The drum's cheeks.
    for (final x in const [-50.0, 30.0]) {
      _shade(
        c,
        Path()..addRect(Rect.fromLTRB(x, -92, x + 6, -64)),
        _polishedBrass(x, x + 6),
      );
    }
    // The drum: a brass cylinder lying along it.
    _shade(
      c,
      Path()..addRect(_drum),
      ui.Gradient.linear(
        _drum.topCenter,
        _drum.bottomCenter,
        const [
          Color(0xFF3E3018),
          Color(0xFFE6CB8A),
          Color(0xFF9A7A40),
          Color(0xFF2E2412),
        ],
        const [0.0, 0.3, 0.7, 1.0],
      ),
    );
    _shade(
      c,
      Path()..addRect(const Rect.fromLTRB(-46, -70, 32, -64)),
      _polishedBrass(-46, 32),
    );
    // The comb: steel teeth up against the drum.
    for (var i = 0; i < 9; i++) {
      final x = -42 + i * 8.4;
      final tooth = _poly([
        Offset(x, -70),
        Offset(x + 5, -70),
        Offset(x + 4.4, -80),
        Offset(x + 0.6, -80),
      ]);
      _shade(
        c,
        tooth,
        ui.Gradient.linear(
          Offset(x, 0),
          Offset(x + 5, 0),
          const [Color(0xFFE2E8F0), Color(0xFF7A8290), Color(0xFF3A3E48)],
          const [0.0, 0.5, 1.0],
        ),
      );
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 100, 0.15 + 0.35 * k.night);
    paintDisc(
      c,
      m.pool,
      const Offset(-6, -82),
      80,
      0.2 + 0.35 * k.night + 0.3 * math.min(1.0, k.stir),
    );
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final dt = _lastT < 0 ? 0.0 : (k.t - _lastT).clamp(0.0, 0.1);
    _lastT = k.t;
    final play = math.min(1.0, k.stir);
    // It turns slowly by itself, and plays when a resident is by it.
    _turn += dt * (0.25 + 2.2 * play);
    // Lamplight from inside it, warm on the drum.
    paintDisc(
      c,
      m.leak,
      const Offset(-6, -78),
      44,
      0.4 + 0.3 * k.night + 0.3 * play,
    );
    // Its pins, coming over the top of the drum toward the comb.
    _pins.clear();
    for (var i = 0; i < 26; i++) {
      final a = _turn + _hash(i, 1) * math.pi * 2;
      if (math.cos(a) < 0) continue;
      final y = _drum.center.dy - math.sin(a) * _drum.height * 0.46;
      _pins.add(_drum.left + 3 + _hash(i, 2) * (_drum.width - 6), y);
    }
    _pins.draw(c, 2.4, _a(const Color(0xFF3A2A10), 0.9));
    // A tooth catching the light as a pin plucks it.
    for (var i = 0; i < 9; i++) {
      final f = _frac(_turn * 0.5 + _hash(i, 3));
      if (f > 0.12) continue;
      paintDisc(
        c,
        kGlint,
        Offset(-39.5 + i * 8.4, -79),
        5,
        (1 - f / 0.12) * (0.3 + 0.6 * play),
      );
    }
    // The winding key at its side, turning as it runs down.
    const key = Offset(84, -36);
    _shade(
      c,
      Path()..addRect(const Rect.fromLTRB(76, -39, 84, -33)),
      _polishedBrass(76, 84),
    );
    final a = _turn * 0.4;
    for (final s in const [-1.0, 1.0]) {
      final d = Offset(math.cos(a) * s, math.sin(a) * s * 0.35);
      final n = Offset(-d.dy, d.dx);
      final lobe = Path()
        ..addPolygon([
          key,
          key + d * 8 + n * 5,
          key + d * 14 + n * 3,
          key + d * 14 - n * 3,
          key + d * 8 - n * 5,
        ], true);
      _shade(c, lobe, _polishedBrass(key.dx - 14, key.dx + 14));
    }
    paintOrb(c, _brassL, key, 3);
    // While it plays, motes of brass lift off it and fade.
    if (play > 0.02) {
      _tune.clear();
      for (var i = 0; i < 14; i++) {
        final f = _frac(k.t * (0.3 + 0.2 * _hash(i, 5)) + _hash(i, 6));
        _tune.add(
          -40 + _hash(i, 7) * 70 + math.sin(k.t * 1.3 + i) * 8 * f,
          -90 - f * 80,
        );
      }
      _tune.draw(c, 2.4, _a(m.grainHot, 0.6 * play));
    }
  }
}

/// The Still-Room's capstone: a tall glass still. A resident steps up to
/// its mouth and comes apart into its own grains; they pour into the
/// boiler, rise up the neck, run down the coil, and spill out at the far
/// end, where they gather into it again. (Its passenger is set by the
/// home's life, see [KeepsakeArt.passenger].)
class _GreatAlembic extends KeepsakeArt {
  _GreatAlembic() : super(const Color(0xFF7FE0C8));

  static const Offset _boiler = Offset(-84, -186);
  static const double _br = 70;
  static const Offset _head = Offset(-70, -404);
  static const Rect _tub = Rect.fromLTRB(36, -350, 146, -86);
  static const double _coilX = 91, _coilR = 34;
  static const double _coilTop = -322, _coilBottom = -112;
  static const double _turns = 4.5;
  static const Offset _mouth = Offset(-166, -246);
  static const Offset _spout = Offset(182, -100);
  static const Offset _flask = Offset(190, -32);
  static const double _fr = 22;

  /// Where it goes in (on the step), and where it comes out.
  static const Offset _inlet = Offset(-200, 30);
  static const Offset _outlet = Offset(216, 0);

  final StoneLight _stone = StoneLight(_kStone);
  final StoneLight _brassL = StoneLight(_kBrass);
  final StoneLight _glassL = StoneLight(const Color(0xFFBFE9FF));
  final StoneLight _fire = StoneLight(const Color(0xFFFF8A3D));
  final _Grains _bubbles = _Grains(60);
  final _Grains _vapour = _Grains(70);
  final _Grains _drops = _Grains(16);

  /// The coil, as points from its top to its foot.
  static final List<Offset> _coil = [
    for (var j = 0; j <= 90; j++)
      Offset(
        _coilX + math.sin(j / 90 * _turns * math.pi * 2) * _coilR,
        _coilTop +
            (_coilBottom - _coilTop) * j / 90 +
            math.cos(j / 90 * _turns * math.pi * 2) * 7,
      ),
  ];

  /// The whole way through it, mouth to spout, and how far along each
  /// point is (0 to 1).
  static final List<Offset> _way = [
    _mouth,
    const Offset(-150, -228),
    const Offset(-136, -210),
    const Offset(-112, -186),
    const Offset(-96, -154),
    const Offset(-64, -150),
    const Offset(-52, -180),
    const Offset(-70, -214),
    const Offset(-84, -244),
    const Offset(-82, -290),
    const Offset(-78, -340),
    const Offset(-74, -382),
    const Offset(-64, -404),
    const Offset(-40, -404),
    const Offset(-10, -392),
    const Offset(30, -376),
    const Offset(70, -356),
    const Offset(91, -340),
    ..._coil,
    const Offset(150, -110),
    const Offset(170, -108),
    _spout,
  ];
  static final List<double> _along = () {
    final d = <double>[0];
    for (var i = 1; i < _way.length; i++) {
      d.add(d.last + (_way[i] - _way[i - 1]).distance);
    }
    return [for (final x in d) x / d.last];
  }();

  /// The point [f] (0 to 1) along the way through it.
  static Offset _at(double f) {
    if (f <= 0) return _way.first;
    if (f >= 1) return _way.last;
    var lo = 0, hi = _along.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_along[mid] <= f) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final g = (f - _along[lo]) / math.max(1e-9, _along[hi] - _along[lo]);
    return Offset.lerp(_way[lo], _way[hi], g)!;
  }

  static final Path _boilerPath = Path()
    ..addOval(Rect.fromCircle(center: _boiler, radius: _br));

  /// The funnel on the boiler's shoulder: a flared mouth narrowing to a
  /// short neck into it.
  static final Path _funnel = () {
    const axis = Offset(0.62, 0.78), n = Offset(-0.78, 0.62);
    const neck = Offset(-136, -214);
    final throat = _mouth + axis * 22;
    return Path()
      ..moveTo(_mouth.dx + n.dx * 24, _mouth.dy + n.dy * 24)
      ..quadraticBezierTo(
        throat.dx + n.dx * 8,
        throat.dy + n.dy * 8,
        neck.dx + n.dx * 7,
        neck.dy + n.dy * 7,
      )
      ..lineTo(neck.dx - n.dx * 7, neck.dy - n.dy * 7)
      ..quadraticBezierTo(
        throat.dx - n.dx * 8,
        throat.dy - n.dy * 8,
        _mouth.dx - n.dx * 24,
        _mouth.dy - n.dy * 24,
      )
      ..close();
  }();
  static final Path _neck = _poly([
    _boiler + const Offset(-14, -_br + 4),
    _boiler + const Offset(14, -_br + 4),
    _head + const Offset(10, 20),
    _head + const Offset(-10, 20),
  ]);
  static final Path _headPath = Path()
    ..addOval(Rect.fromCenter(center: _head, width: 76, height: 54));
  static final Path _arm = vfxRibbon(
    const [
      Offset(-40, -408),
      Offset(-6, -394),
      Offset(34, -376),
      Offset(70, -358),
      Offset(91, -344),
    ],
    15,
    10,
  );
  static final Path _tubPath = Path()
    ..addRRect(RRect.fromRectAndRadius(_tub, const Radius.circular(10)));
  static final Path _flaskPath = Path()
    ..addOval(Rect.fromCircle(center: _flask, radius: _fr))
    ..addRect(
      Rect.fromLTRB(
        _flask.dx - 6,
        _flask.dy - _fr - 14,
        _flask.dx + 6,
        _flask.dy - _fr + 6,
      ),
    );

  /// Copper, bright where the coil turns to the key light.
  static final ui.Shader _copper = ui.Gradient.linear(
    const Offset(_coilX - _coilR - 6, 0),
    const Offset(_coilX + _coilR + 6, 0),
    const [
      Color(0xFF8A5434),
      Color(0xFFE0A274),
      Color(0xFFA0623C),
      Color(0xFF4A2A18),
      Color(0xFF6A3E24),
    ],
    const [0.0, 0.25, 0.5, 0.82, 1.0],
  );

  @override
  Rect get box => const Rect.fromLTRB(-256, -440, 240, 6);

  @override
  List<Offset> seats(KeepsakeTime k) => const [_inlet, _outlet];

  @override
  bool get hasFront => true;

  /// The coil's tube, its far half or its near half: each run of it on
  /// that side as one ribbon.
  Path _coilHalf(bool near) {
    final p = Path();
    var run = <Offset>[];
    void flush() {
      if (run.length > 1) p.addPath(vfxRibbon(run, 11, 11), Offset.zero);
      run = <Offset>[];
    }

    for (var j = 0; j < _coil.length; j++) {
      final a = j / 90 * _turns * math.pi * 2;
      if ((math.cos(a) > -0.05) == near) {
        run.add(_coil[j]);
      } else {
        flush();
      }
    }
    flush();
    return p;
  }

  @override
  void body(Canvas c) {
    // The step it is gone into from.
    _block(c, _stone, const Rect.fromLTRB(-252, -30, -150, 0), bevel: 3);
    _block(c, _brassL, const Rect.fromLTRB(-252, -30, -150, -27), bevel: 1);
    // The furnace, its fire door, the brass ring the boiler sits in.
    _block(c, _stone, const Rect.fromLTRB(-150, -112, -18, 0), bevel: 3);
    _block(c, _stone, const Rect.fromLTRB(-156, -122, -12, -110), bevel: 2.4);
    final door = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          const Rect.fromLTRB(-110, -74, -60, -12),
          topLeft: const Radius.circular(25),
          topRight: const Radius.circular(25),
        ),
      );
    _solid(c, door, const Color(0xFF07070A));
    // The tub's stand and the receiver's.
    _block(c, _stone, const Rect.fromLTRB(26, -86, 156, 0), bevel: 3);
    for (final (x0, x1) in const [(176.0, 168.0), (204.0, 212.0)]) {
      _shaft(c, _brassL, (x0 + x1) / 2, 0, -10, 5, 4, lean: x0 - x1);
    }
    _block(c, _brassL, const Rect.fromLTRB(166, -12, 214, -7), bevel: 1.2);
    // Glass: the funnel at its mouth, the neck, the head, the arm.
    _glass(c, _glassL, _funnel, const Offset(-160, -232), 40);
    _glass(c, _glassL, _neck, _head + const Offset(0, 60), 70);
    _glass(c, _glassL, _arm, const Offset(20, -380), 80);
    _clearGlass(c, _funnel, _funnel.getBounds(), window: false);
    _clearGlass(c, _neck, _neck.getBounds(), window: false);
    _clearGlass(c, _headPath, _headPath.getBounds());
    _shade(
      c,
      vfxRibbon(
        const [
          Offset(-40, -411),
          Offset(-6, -397),
          Offset(34, -379),
          Offset(70, -361),
        ],
        3.4,
        1.8,
      ),
      ui.Gradient.linear(const Offset(-40, 0), const Offset(70, 0), [
        _a(_glassL.rim, 0.55),
        _a(_glassL.rim, 0.15),
      ]),
    );
    _block(
      c,
      _brassL,
      Rect.fromCenter(
        center: _head + const Offset(0, 24),
        width: 30,
        height: 7,
      ),
      bevel: 1.4,
    );
    // The tub of water the coil runs down through: its back, the coil's far
    // half, the water, the near half, and the glass over it all.
    _shade(
      c,
      _tubPath,
      ui.Gradient.linear(
        _tub.centerLeft,
        _tub.centerRight,
        const [
          Color(0x507FA9CC),
          Color(0x1A3C5470),
          Color(0x102A3A50),
          Color(0x1A3C5470),
          Color(0x407FA9CC),
        ],
        const [0.0, 0.1, 0.5, 0.9, 1.0],
      ),
    );
    final copper = StoneLight(const Color(0xFFE0A070));
    final far = _coilHalf(false);
    _solid(c, far, const Color(0xFF2E1A10));
    _shade(c, far, _copper, 0.45);
    _solid(c, Path()..addRect(_tub.deflate(4)), const Color(0x183A7AA0));
    final near = _coilHalf(true);
    _solid(c, near, const Color(0xFF2E1A10));
    _shade(c, near, _copper);
    _clearGlass(c, _tubPath, _tub, window: false);
    // The window it gives back: a soft band down its left side.
    _shade(
      c,
      Path()..addRRect(
        RRect.fromLTRBR(
          _tub.left + 8,
          _tub.top + 14,
          _tub.left + 18,
          _tub.bottom - 14,
          const Radius.circular(5),
        ),
      ),
      ui.Gradient.linear(
        Offset(0, _tub.top),
        Offset(0, _tub.bottom),
        const [Color(0x40FFFFFF), Color(0x14FFFFFF), Color(0x00FFFFFF)],
        const [0.0, 0.5, 1.0],
      ),
    );
    _block(
      c,
      _brassL,
      Rect.fromLTRB(_tub.left - 4, _tub.top - 6, _tub.right + 4, _tub.top + 2),
      bevel: 1.4,
    );
    _block(
      c,
      _brassL,
      Rect.fromLTRB(
        _tub.left - 4,
        _tub.bottom - 4,
        _tub.right + 4,
        _tub.bottom + 2,
      ),
      bevel: 1.4,
    );
    // The spout out of the tub's foot.
    final spout = vfxRibbon(
      const [Offset(140, -110), Offset(166, -110), Offset(180, -104), _spout],
      8,
      6,
    );
    _glass(c, copper, spout, const Offset(160, -108), 30);
    _shade(c, spout, _litAcross(copper, 140, 184, k: 1), 0.7);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    final flick = 0.85 + 0.15 * math.sin(k.t * 7.3) * math.sin(k.t * 2.9);
    _groundPool(c, _fire, -84, 150, (0.3 + 0.55 * k.night) * flick);
    paintDisc(c, m.pool, _boiler, 130, 0.35 + 0.45 * k.night);
    paintDisc(c, m.pool, _tub.center, 130, 0.2 + 0.35 * k.night);
    paintDisc(c, m.pool, _flask, 50, 0.3 + 0.4 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final passing = passenger != null ? 1.0 : 0.0;
    final boil = 0.35 + 0.65 * math.max(math.min(1.0, k.stir), passing);
    // The fire through its door.
    _flame(
      c,
      const Offset(-85, -14),
      28 + 18 * boil,
      34,
      k.t,
      9,
      core: const Color(0xFFFFE2A0),
      body: const Color(0xFFFF7A2E),
    );
    paintDisc(c, _fire.spark, const Offset(-85, -30), 30, 0.4 + 0.3 * boil);
    // The boiler, its liquid lit, simmering.
    final level = _boiler.dy + 4 + math.sin(k.t * 3.1) * 2 * boil;
    c.save();
    c.clipPath(_boilerPath);
    _solid(
      c,
      Path()..addRect(
        Rect.fromLTRB(
          _boiler.dx - _br,
          level,
          _boiler.dx + _br,
          _boiler.dy + _br,
        ),
      ),
      Color.lerp(m.ink, m.essence, 0.5)!,
    );
    paintDisc(
      c,
      m.leak,
      _boiler + const Offset(0, 36),
      80,
      0.9 + 0.3 * k.night,
    );
    _solid(
      c,
      Path()..addOval(
        Rect.fromCenter(
          center: Offset(_boiler.dx, level),
          width: _br * 1.95,
          height: 7,
        ),
      ),
      _a(m.hot, 0.35),
    );
    c.restore();
    _bubbles.clear();
    final nb = (16 + 30 * boil).round();
    for (var i = 0; i < nb; i++) {
      final f = _frac(k.t * (0.6 + 0.6 * _hash(i, 1)) + _hash(i, 2));
      final x = _boiler.dx + (_hash(i, 3) - 0.5) * _br * 1.4;
      final y = _boiler.dy + _br * 0.85 - f * (_boiler.dy + _br * 0.85 - level);
      _bubbles.add(x + math.sin(k.t * 4 + i) * 2, y);
    }
    _bubbles.draw(c, 3, _a(m.hot, 0.65));
    _clearGlass(c, _boilerPath, Rect.fromCircle(center: _boiler, radius: _br));
    _block(
      c,
      _brassL,
      Rect.fromCenter(
        center: _boiler + const Offset(0, _br - 6),
        width: 96,
        height: 8,
      ),
      bevel: 1.6,
    );
    // Vapour up the neck into the head.
    _vapour.clear();
    for (var i = 0; i < (18 + 30 * boil).round(); i++) {
      final f = _frac(k.t * (0.14 + 0.1 * _hash(i, 5)) + _hash(i, 6));
      final Offset at;
      if (f < 0.55) {
        final g = f / 0.55;
        at = Offset(
          _boiler.dx + (_hash(i, 7) - 0.5) * 16 + g * 12,
          level - g * (level - _head.dy - 16),
        );
      } else {
        final g = (f - 0.55) / 0.45;
        final a = -math.pi / 2 + (_hash(i, 8) - 0.5) * 2.6 + g * 1.2;
        at = _head + Offset(math.cos(a) * 26 * g, 6 + math.sin(a) * 14 * g);
      }
      _vapour.add(at.dx, at.dy);
    }
    _vapour.draw(c, 2.4, _a(const Color(0xFFE6FFF8), 0.35 + 0.25 * boil));
    // Drops of what it makes running down the arm and the coil, and out of
    // the spout into the flask.
    _drops.clear();
    const from = 0.47;
    for (var i = 0; i < 6; i++) {
      final f = _frac(k.t * (0.035 + 0.03 * boil) + i / 6);
      final p = _at(from + (1 - from) * f);
      _drops.add(p.dx, p.dy);
    }
    final dripF = _frac(k.t * 0.5);
    _drops.add(
      _spout.dx,
      _spout.dy + 4 + dripF * (_flask.dy - _fr - 10 - _spout.dy),
    );
    _drops.draw(c, 4, _a(m.hot, 0.85));
    // The receiver, filling slowly and emptied again.
    final fill = 0.3 + 0.5 * _frac(k.t / 50);
    c.save();
    c.clipPath(_flaskPath);
    final top = _flask.dy + _fr - fill * _fr * 2;
    _solid(
      c,
      Path()..addRect(
        Rect.fromLTRB(_flask.dx - _fr, top, _flask.dx + _fr, _flask.dy + _fr),
      ),
      Color.lerp(m.ink, m.essence, 0.7)!,
    );
    paintDisc(
      c,
      m.spark,
      _flask + const Offset(0, 8),
      20 * fill + 6,
      0.4 + 0.4 * k.night,
    );
    c.restore();
    _clearGlass(c, _flaskPath, Rect.fromCircle(center: _flask, radius: _fr));
  }

  @override
  void front(Canvas c, KeepsakeTime k) {
    final p = passenger;
    if (p != null) _carry(c, p);
  }

  /// The passenger as grains: lifting off it into the mouth, through the
  /// way, and out of the spout into its shape again at the far end.
  void _carry(Canvas c, KeepsakePassenger p) {
    final g = p.grains;
    final prog = p.progress.clamp(0.0, 1.0);
    final inMid = Offset(_inlet.dx, -_inlet.dy - p.rise);
    final outMid = Offset(_outlet.dx, -_outlet.dy - p.rise);
    final s = p.scale;
    // The top of it lets go first.
    var top = 0.0, bottom = 0.0;
    for (var i = 0; i < g.length; i++) {
      top = math.min(top, g.hy[i]);
      bottom = math.max(bottom, g.hy[i]);
    }
    final span = math.max(1e-3, bottom - top);
    for (final b in p.batches) {
      b.clear();
    }
    final fade = 1 - _smooth(0.9, 1.0, prog);
    if (fade <= 0.01) return;
    for (var i = 0; i < g.length; i++) {
      final low = (g.hy[i] - top) / span;
      final delay = 0.15 * low + 0.06 * _hash(i, 1);
      final u = ((prog - delay) / 0.79).clamp(0.0, 1.0);
      final sIn =
          inMid + Offset(g.hx[i] * s * (p.mirrorIn ? -1 : 1), g.hy[i] * s);
      final sOut =
          outMid + Offset(g.hx[i] * s * (p.mirrorOut ? -1 : 1), g.hy[i] * s);
      Offset at;
      if (u < 0.16) {
        // Up off it and into the mouth: a curve, rising first.
        final e = _smooth(0, 1, u / 0.16);
        final ctrl = Offset(
          sIn.dx + (_mouth.dx - sIn.dx) * 0.2,
          _mouth.dy + 50,
        );
        // Each grain curling its own way as it goes, so it rises as a
        // current, not a cone.
        final curl = math.sin(e * math.pi) * (14 + 16 * _hash(i, 4));
        final turn = _hash(i, 5) * math.pi * 2 + e * 5;
        at =
            _bez(sIn, ctrl, _mouth, e) +
            Offset(math.cos(turn) * curl, math.sin(turn) * curl * 0.5);
      } else if (u < 0.85) {
        final f = (u - 0.16) / 0.69;
        at = _at(f) + Offset((_hash(i, 2) - 0.5) * 7, (_hash(i, 3) - 0.5) * 7);
      } else {
        // Out of the spout: falling, then gathering into its shape.
        final e = _smooth(0, 1, (u - 0.85) / 0.15);
        final ctrl = Offset(
          _spout.dx + (sOut.dx - _spout.dx) * 0.1,
          sOut.dy + 30,
        );
        at = _bez(_spout, ctrl, sOut, e);
      }
      p.batches[g.tone[i]].add(at.dx, at.dy);
    }
    final size = g.step * s * 1.1;
    for (var t = 0; t < p.batches.length; t++) {
      p.batches[t].draw(c, size, _a(g.tones[t], fade));
    }
  }

  static Offset _bez(Offset a, Offset b, Offset c, double t) {
    final u = 1 - t;
    return a * (u * u) + b * (2 * u * t) + c * (t * t);
  }
}
