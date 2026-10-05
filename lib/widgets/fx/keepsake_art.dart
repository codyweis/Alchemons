// lib/widgets/fx/keepsake_art.dart
//
// The keepsakes of the home biome (models/home_keepsakes.dart), drawn in
// code in the game's own material: obsidian whose colour comes only from the
// light inside it, glass that holds that light, and grains for whatever
// moves. Seen from the side, standing on the ground of a field.
//
// Units: 100 is the size of a creature on the row the keepsake stands on;
// x runs right, y down, and its feet are at the origin. Each piece is two
// parts — a body painted once and baked into an image, and what lives in
// it (flame, sand, steam, a beating heart) drawn every frame, kept to a few
// hundred grains and filled shapes. No outline strokes, no hoops, no blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:flutter/painting.dart';

part 'decor_art.dart';

/// What a keepsake's living part is drawn with this frame.
class KeepsakeTime {
  KeepsakeTime({
    this.t = 0,
    this.night = 0,
    this.stir = 0,
    this.daylight = 1,
  });

  /// Seconds since it was stood there.
  double t;

  /// How deep in the night it is, 0 (day) to 1: lights tell more by night.
  double night;

  /// Something has just come to it or through it, 1 fading to 0 — up to
  /// 1.6 for a visitor of its own element.
  double stir;

  /// How open the day is, 0 (night) to 1 (full day) — the lotus opens to it.
  double daylight;
}

/// One keepsake's look.
abstract class KeepsakeArt {
  KeepsakeArt(Color light) : m = StoneLight(light, warm: 0.03);

  final StoneLight m;

  /// Its extent round its feet: where it can be taken hold of, and what is
  /// baked.
  Rect get box;

  /// The still part: stone, glass, metal. Painted once.
  void body(Canvas c);

  /// What lives in it, drawn over the body every frame.
  void live(Canvas c, KeepsakeTime k);

  /// Where a visitor can sit on it, how far above its feet; null for
  /// nowhere (see the home biome's life).
  double? get seat => null;

  /// Every place visitors sit or stand on it at [k]: along from its feet
  /// and how far up (negative down, into water), in its units. A seat that
  /// moves (a swing, a ride) is where it is this frame.
  List<Offset> seats(KeepsakeTime k) {
    final s = seat;
    return s == null ? const [] : [Offset(0, s)];
  }

  /// Whether it draws over what stands in it ([front]) — the water a
  /// bather sits in.
  bool get hasFront => false;

  /// What it draws over its visitors, with the canvas at its feet.
  void front(Canvas c, KeepsakeTime k) {}

  /// Still water that gives back whatever stands at its edge: its extent,
  /// the surface along its middle; null for none.
  Rect? get mirror => null;

  /// The light it throws on the ground and the air round it, drawn under
  /// the body every frame.
  void under(Canvas c, KeepsakeTime k) {}

  ui.Image? _image;
  static const double _ppu = 3.6;
  static final Paint _imagePaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;

  Rect get _bake => box.inflate(8);

  /// Draws the whole keepsake at its feet.
  void paint(Canvas c, KeepsakeTime k) {
    under(c, k);
    final img = _image ??= _bakeBody();
    final b = _bake;
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      b,
      _imagePaint,
    );
    live(c, k);
  }

  static final Paint _mirrorPaint = Paint()
    ..filterQuality = FilterQuality.low
    ..isAntiAlias = true;

  /// Its still part upside down under its feet at [alpha], as glass gives
  /// it back — its stone only, one draw.
  void paintReflection(Canvas c, double alpha) {
    if (alpha <= 0.004) return;
    final img = _image ??= _bakeBody();
    final b = _bake;
    _mirrorPaint.color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0));
    c
      ..save()
      ..scale(1, -1);
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      b,
      _mirrorPaint,
    );
    c.restore();
  }

  ui.Image _bakeBody() {
    final b = _bake;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)
      ..scale(_ppu)
      ..translate(-b.left, -b.top);
    body(c);
    final pic = rec.endRecording();
    final img = pic.toImageSync(
      (b.width * _ppu).ceil(),
      (b.height * _ppu).ceil(),
    );
    pic.dispose();
    return img;
  }

  void dispose() {
    _image?.dispose();
    _image = null;
  }

  /// The art for a keepsake [id]; [copy] tells a pair apart (the portals,
  /// one of each colour). Null for none such.
  static KeepsakeArt? of(String id, {int copy = 0, int style = 0}) =>
      _decorArt(id, style) ?? _keepsakeArt(id, copy);

  static KeepsakeArt? _keepsakeArt(String id, int copy) => switch (id) {
    'ember_torch' => _EmberTorch(),
    'four_winds' => _FourWinds(),
    'frozen_moon' => _FrozenMoon(),
    'giants_palm' => _GiantsPalm(),
    'fulgurite' => _Fulgurite(),
    'harmony_pipes' => _HarmonyPipes(),
    'black_glass' => _BlackGlass(),
    'the_dose' => _TheDose(),
    'mud_lotus' => _MudLotus(),
    'star_walker' => _StarWalker(),
    'hourglass' => _Hourglass(),
    'know_thyself' => _KnowThyself(),
    'opposite_flower' => _OppositeFlower(),
    'lancet_stone' => _LancetStone(),
    'twin_portals' => _Portal(copy.isOdd),
    'night_book' => _NightBook(),
    'garnet_heart' => _GarnetHeart(),
    'crown_mirror' => _CrownMirror(),
    'victory_arch' => _VictoryArch(),
    'titan_anvil' => _TitanAnvil(),
    'prism_orrery' => _PrismOrrery(),
    _ when id.startsWith('effigy:') => EffigyPlinth(),
    _ => null,
  };
}

// ── The kit: side-view obsidian ─────────────────────────────────────────────

final Paint _p = Paint()..isAntiAlias = true;

Color _a(Color c, double alpha) => c.withValues(alpha: alpha.clamp(0.0, 1.0));

/// [c] filled in solid [color].
void _solid(Canvas c, Path path, Color color) {
  _p
    ..shader = null
    ..color = color;
  c.drawPath(path, _p);
}

/// [path] filled with [shader] at [alpha].
void _shade(Canvas c, Path path, ui.Shader shader, [double alpha = 1]) =>
    paintFill(c, path, shader, alpha);

Path _poly(List<Offset> pts) => polyPath(pts);

/// The light off the key light's side of a solid: rim at the lit edge,
/// fading into the face.
ui.Shader _litAcross(StoneLight m, double x0, double x1, {double k = 0.6}) =>
    ui.Gradient.linear(Offset(x0, 0), Offset(x1, 0), [
      Color.lerp(m.face, m.rim, k * 0.32)!,
      m.face,
      m.ink,
    ], const [0.0, 0.35, 1.0]);

/// A block of stone whose front is [r]: its top a lit bevel, its left
/// flank catching the key light, its right going into shadow.
void _block(Canvas c, StoneLight m, Rect r, {double bevel = 3}) {
  _solid(c, Path()..addRect(r), m.ink);
  _shade(c, Path()..addRect(r), _litAcross(m, r.left, r.right, k: 0.35));
  final top = _poly([
    r.topLeft,
    r.topRight,
    r.topRight + Offset(-bevel * 0.6, bevel),
    r.topLeft + Offset(bevel, bevel),
  ]);
  _shade(
    c,
    top,
    ui.Gradient.linear(r.topLeft, r.topRight, [
      Color.lerp(m.face, m.rim, 0.5)!,
      Color.lerp(m.face, m.rim, 0.1)!,
    ]),
  );
  final left = _poly([
    r.topLeft + Offset(0, bevel),
    r.topLeft + Offset(bevel * 0.8, bevel),
    Offset(r.left + bevel * 0.8, r.bottom),
    r.bottomLeft,
  ]);
  _shade(
    c,
    left,
    ui.Gradient.linear(r.topLeft, r.bottomLeft, [
      Color.lerp(m.face, m.rim, 0.25)!,
      m.face,
    ]),
  );
}

/// A stepped plinth [w] wide and [h] tall standing on the ground.
void _plinth(Canvas c, StoneLight m, double w, double h, {int steps = 2}) {
  final step = h / steps;
  for (var i = 0; i < steps; i++) {
    final ww = w * (1 - 0.14 * i);
    _block(
      c,
      m,
      Rect.fromLTRB(-ww / 2, -(i + 1) * step, ww / 2, -i * step),
      bevel: math.min(3, step * 0.4),
    );
  }
}

/// A shaft of stone from [y0] (its foot) up to [y1], [w0] wide at its foot
/// and [w1] at its top, with a lean of [lean] at the top: two facets meeting
/// on a ridge, the left lit.
void _shaft(
  Canvas c,
  StoneLight m,
  double x,
  double y0,
  double y1,
  double w0,
  double w1, {
  double lean = 0,
}) {
  final bl = Offset(x - w0 / 2, y0), br = Offset(x + w0 / 2, y0);
  final tl = Offset(x - w1 / 2 + lean, y1), tr = Offset(x + w1 / 2 + lean, y1);
  final bm = Offset(x + w0 * 0.08, y0), tm = Offset(x + w1 * 0.08 + lean, y1);
  _solid(c, _poly([bl, br, tr, tl]), m.ink);
  _shade(
    c,
    _poly([bl, bm, tm, tl]),
    ui.Gradient.linear(Offset(x - w0 / 2, 0), Offset(x, 0), [
      Color.lerp(m.face, m.rim, 0.18)!,
      m.face,
    ]),
  );
  _shade(
    c,
    _poly([bm, br, tr, tm]),
    ui.Gradient.linear(Offset(x, 0), Offset(x + w0 / 2, 0), [
      Color.lerp(m.ink, m.face, 0.4)!,
      m.ink,
    ]),
  );
  // The lit edge, a sliver tapering up the left.
  _shade(
    c,
    _poly([
      bl,
      bl + Offset(w0 * 0.12, 0),
      tl + Offset(w1 * 0.1, 0),
      tl,
    ]),
    ui.Gradient.linear(Offset(0, y0), Offset(0, y1), [
      _a(m.rim, 0.1),
      _a(m.rim, 0.45),
    ]),
  );
}

/// A pane of glass holding [m]'s light, with the light pooled at [heart].
void _glass(Canvas c, StoneLight m, Path pane, Offset heart, double reach) {
  _solid(c, pane, Color.lerp(m.ink, m.essence, 0.18)!);
  c.save();
  c.clipPath(pane);
  paintDisc(c, m.leak, heart, reach, 1.0);
  paintDisc(c, m.spark, heart, reach * 0.35, 0.55);
  c.restore();
}

/// A soft pool of light on the ground at [x], [r] wide, squashed flat.
void _groundPool(
  Canvas c,
  StoneLight m,
  double x,
  double r,
  double alpha, {
  double y = 0,
}) {
  if (alpha <= 0.004) return;
  c
    ..save()
    ..translate(x, y)
    ..scale(1, 0.22);
  paintDisc(c, m.pool, Offset.zero, r, alpha);
  c.restore();
}

/// A tapering leaf or petal of cut glass, its stem at [at] pointing along
/// [angle], [len] long and [w] wide.
void _leaf(
  Canvas c,
  StoneLight m,
  Offset at,
  double angle,
  double len,
  double w, {
  double glow = 1,
}) {
  c
    ..save()
    ..translate(at.dx, at.dy)
    ..rotate(angle);
  CutStone.gem(m, [
    Offset.zero,
    Offset(len * 0.25, -w * 0.5),
    Offset(len * 0.65, -w * 0.42),
    Offset(len, 0),
    Offset(len * 0.65, w * 0.42),
    Offset(len * 0.25, w * 0.5),
  ], Offset(len * 0.4, 0)).paint(c, angle, glow: glow, reach: len * 0.6);
  c.restore();
}

/// A flame [h] tall and [w] wide rising from [base], flickering with [t].
void _flame(
  Canvas c,
  Offset base,
  double h,
  double w,
  double t,
  int seed, {
  required Color core,
  required Color body,
  double alpha = 1,
}) {
  final left = <Offset>[], right = <Offset>[];
  const n = 12;
  final lick = 0.6 + 0.4 * math.sin(t * 9.3 + seed);
  for (var i = 0; i <= n; i++) {
    final f = i / n;
    final half =
        w * 0.5 * math.pow(math.sin(math.pi * math.min(1, f * 1.35)), 0.8) *
        math.pow(1 - f, 0.55);
    final sway =
        (math.sin(t * 6.1 + f * 4 + seed) * 0.22 +
            math.sin(t * 11.7 + f * 7 + seed * 2) * 0.08) *
        w *
        f;
    final y = base.dy - h * f * (0.88 + 0.12 * lick);
    left.add(Offset(base.dx - half + sway, y));
    right.add(Offset(base.dx + half + sway, y));
  }
  final path = _poly([...left, ...right.reversed]);
  _shade(
    c,
    path,
    ui.Gradient.linear(base, base - Offset(0, h), [
      _a(core, alpha),
      _a(body, 0.9 * alpha),
      _a(body, 0),
    ], const [0.0, 0.45, 1.0]),
  );
  // The hot heart, low in it.
  final inner = <Offset>[];
  for (var i = 0; i <= n; i++) {
    final o = left[i], p = right[i];
    inner.add(Offset.lerp(o, p, 0.3)!.translate(0, h * 0.06));
  }
  final innerR = [
    for (var i = 0; i <= n; i++)
      Offset.lerp(left[i], right[i], 0.7)!.translate(0, h * 0.06),
  ];
  _shade(
    c,
    _poly([...inner.take(8), ...innerR.take(8).toList().reversed]),
    ui.Gradient.linear(base, base - Offset(0, h * 0.6), [
      _a(const Color(0xFFFFFBEA), 0.9 * alpha),
      _a(core, 0),
    ]),
  );
}

double _hash(int i, int salt) => hash01(i, salt);

/// Grains drawn in one pass per colour.
class _Grains {
  _Grains(int n) : _batch = PointBatch(n);
  final PointBatch _batch;
  void clear() => _batch.clear();
  void add(double x, double y) => _batch.add(x, y);
  void draw(Canvas c, double size, Color color) =>
      _batch.draw(c, size, color);
}

/// The champion's gold, as the crowned arenas have it.
const Color _gold = Color(0xFFF0C766);

/// A laurel of gold leaves: [count] up each side of an arc of radius [r]
/// round [centre], from the bottom up to [reach] (radians from the bottom).
void _laurel(
  Canvas c,
  StoneLight gold,
  Offset centre,
  double r,
  int count, {
  double reach = 2.4,
  double leaf = 12,
}) {
  for (final side in const [-1.0, 1.0]) {
    for (var i = 0; i < count; i++) {
      final f = (i + 0.5) / count;
      final a = math.pi / 2 + side * f * reach;
      final at = centre + polar(r, a);
      // Leaves point up the arc, a little outward.
      final tangent = a + side * (math.pi / 2) - side * 0.35;
      _leaf(c, gold, at, tangent, leaf * (1 - f * 0.35), leaf * 0.42);
    }
  }
}

// ── The maxims ──────────────────────────────────────────────────────────────

/// Fire — Ember Epitaph: tall torch-stands of obsidian, each cup holding
/// the planter's flame.
class _EmberTorch extends KeepsakeArt {
  _EmberTorch() : super(const Color(0xFFFF8A3D));

  static const _cupY = -152.0;
  final _Grains _embers = _Grains(40);

  @override
  Rect get box => const Rect.fromLTRB(-28, -232, 28, 4);

  @override
  void body(Canvas c) {
    _plinth(c, m, 34, 9);
    _shaft(c, m, 0, -9, _cupY + 6, 11, 6);
    // A collar halfway up.
    _block(c, m, const Rect.fromLTRB(-8, -86, 8, -80), bevel: 1.6);
    // The cup: a bowl of stone, its rim catching the fire inside.
    final cup = _poly(const [
      Offset(-17, _cupY - 12),
      Offset(17, _cupY - 12),
      Offset(10, _cupY + 2),
      Offset(4, _cupY + 7),
      Offset(-4, _cupY + 7),
      Offset(-10, _cupY + 2),
    ]);
    _solid(c, cup, m.ink);
    _shade(c, cup, _litAcross(m, -17, 17, k: 0.5));
    // The glass lip the fire lights from inside.
    _glass(
      c,
      m,
      _poly(const [
        Offset(-17, _cupY - 12),
        Offset(17, _cupY - 12),
        Offset(14, _cupY - 8),
        Offset(-14, _cupY - 8),
      ]),
      const Offset(0, _cupY - 12),
      22,
    );
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    final flick = 0.85 + 0.15 * math.sin(k.t * 7.7) * math.sin(k.t * 3.1);
    _groundPool(c, m, 0, 120, (0.35 + 0.65 * k.night) * flick);
    paintDisc(
      c,
      m.pool,
      const Offset(0, _cupY - 30),
      70 + 20 * k.night,
      (0.5 + 0.8 * k.night) * flick,
    );
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final grow = 1 + 0.3 * k.stir;
    _flame(
      c,
      const Offset(0, _cupY - 10),
      54 * grow,
      26,
      k.t,
      3,
      core: const Color(0xFFFFE2A0),
      body: const Color(0xFFFF7A2E),
    );
    _flame(
      c,
      const Offset(3, _cupY - 10),
      34 * grow,
      14,
      k.t * 1.3,
      7,
      core: const Color(0xFFFFF4D6),
      body: const Color(0xFFFFB04A),
      alpha: 0.8,
    );
    _embers.clear();
    for (var i = 0; i < 18; i++) {
      final life = (k.t * (0.3 + 0.2 * _hash(i, 3)) + _hash(i, 4)) % 1.0;
      final x = (_hash(i, 5) - 0.5) * 18 +
          math.sin(k.t * 2 + i) * 8 * life;
      _embers.add(x, _cupY - 30 - life * 90);
    }
    _embers.draw(c, 1.8, _a(const Color(0xFFFFB45A), 0.75));
  }
}

/// Air — The Four Winds: a mast with four glass vanes that turn to the
/// wind, and the wind going by.
class _FourWinds extends KeepsakeArt {
  _FourWinds() : super(const Color(0xFF9FD6F2));

  static const _hubY = -158.0;
  final _Grains _wind = _Grains(90);

  @override
  Rect get box => const Rect.fromLTRB(-58, -200, 58, 4);

  @override
  void body(Canvas c) {
    _plinth(c, m, 44, 12, steps: 3);
    _shaft(c, m, 0, -12, _hubY, 9, 5);
    // The compass rose's four lit points, set into the mast's collar.
    _block(c, m, const Rect.fromLTRB(-10, -100, 10, -94), bevel: 1.5);
    for (final x in const [-14.0, 14.0]) {
      paintOrb(c, m, Offset(x, -97), 2.6);
    }
    paintOrb(c, m, const Offset(0, -103), 2.2);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, const Offset(0, _hubY), 46, 0.5 + 0.4 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final turn = k.t * (0.7 + 1.8 * k.stir);
    // The vanes, back ones first: each a blade of glass seen edge-on as it
    // comes round.
    final blades = [
      for (var i = 0; i < 4; i++) turn + i * math.pi / 2,
    ]..sort((a, b) => math.sin(a).compareTo(math.sin(b)));
    void blade(double a) {
      final reach = math.cos(a) * 42;
      final depth = math.sin(a);
      final w = 9 + 3 * depth;
      final tip = Offset(reach, _hubY - 4 + depth * 3);
      final path = _poly([
        const Offset(0, _hubY - 1),
        Offset(reach * 0.35, _hubY - w * 0.7),
        Offset(tip.dx, tip.dy - w * 0.35),
        tip,
        Offset(reach * 0.35, _hubY + w * 0.25),
      ]);
      // Glass lit from the hub out — one fill, no clip, every frame.
      _shade(
        c,
        path,
        ui.Gradient.linear(Offset(0, _hubY), Offset(reach, _hubY), [
          _a(m.hot, 0.55 + 0.25 * depth),
          _a(m.essence, 0.55),
          _a(Color.lerp(m.essence, m.ink, 0.5)!, 0.7),
        ], const [0.0, 0.45, 1.0]),
      );
    }

    for (final a in blades.where((a) => math.sin(a) < 0)) {
      blade(a);
    }
    paintOrb(c, m, const Offset(0, _hubY), 5.5);
    for (final a in blades.where((a) => math.sin(a) >= 0)) {
      blade(a);
    }
    // The wind: grains streaming past, bending over the mast.
    _wind.clear();
    for (var i = 0; i < 70; i++) {
      final f = (k.t * (0.18 + 0.1 * _hash(i, 1)) + _hash(i, 2)) % 1.0;
      final x = -70 + f * 140;
      final lane = _hash(i, 3);
      final y = -40 - lane * 150 + math.sin(f * 6 + i) * 4;
      _wind.add(x, y - math.exp(-x * x / 900) * 10 * (1 - lane));
    }
    _wind.draw(c, 1.4, _a(const Color(0xFFDDF2FF), 0.35 + 0.2 * k.stir));
  }
}

/// Water — The Stilled Mirror: a moon held in a rosette of ice glass over
/// a basin of still water that holds its image.
class _FrozenMoon extends KeepsakeArt {
  _FrozenMoon() : super(const Color(0xFF8FD3FF));

  static const _moon = Offset(0, -78);
  final _Grains _frost = _Grains(50);

  @override
  Rect get box => const Rect.fromLTRB(-62, -128, 62, 4);

  @override
  void body(Canvas c) {
    // The rosette: shards of ice fanned round where the moon hangs.
    for (var i = 0; i < 9; i++) {
      final a = -math.pi * (0.08 + 0.84 * i / 8);
      final len = 30 + 12 * math.sin(i * 1.7).abs();
      _leaf(c, m, _moon + polar(16, a), a, len, 12, glow: 1.3);
    }
    // The basin.
    final basin = _poly(const [
      Offset(-58, -24),
      Offset(58, -24),
      Offset(50, -8),
      Offset(30, 0),
      Offset(-30, 0),
      Offset(-50, -8),
    ]);
    _solid(c, basin, m.ink);
    _shade(c, basin, _litAcross(m, -58, 58, k: 0.4));
    // Still water, holding the moon.
    final water = _poly(const [
      Offset(-54, -24),
      Offset(54, -24),
      Offset(46, -19),
      Offset(-46, -19),
    ]);
    _glass(c, m, water, const Offset(0, -22), 40);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, _moon, 60, 0.45 + 0.6 * k.night);
    _groundPool(c, m, 0, 80, 0.25 + 0.4 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final breathe = 0.92 + 0.08 * math.sin(k.t * 0.9);
    final pale = StoneLight(const Color(0xFFDDEFFF));
    paintOrb(c, pale, _moon, 15 * breathe);
    paintDisc(c, pale.spark, _moon, 9, 0.35 + 0.3 * k.night);
    // Its image in the water, broken by a slow ripple.
    final wob = math.sin(k.t * 1.3) * 1.5 + k.stir * 4 * math.sin(k.t * 9);
    c
      ..save()
      ..translate(wob, -21.5)
      ..scale(1, 0.18);
    paintDisc(c, pale.spark, Offset.zero, 13, 0.55);
    c.restore();
    _frost.clear();
    for (var i = 0; i < 36; i++) {
      final f = (k.t * 0.05 + _hash(i, 7)) % 1.0;
      final a = _hash(i, 8) * math.pi * 2 + k.t * 0.2;
      final r = 20 + f * 50;
      _frost.add(_moon.dx + math.cos(a) * r, _moon.dy + math.sin(a) * r * 0.7);
    }
    _frost.draw(c, 1.3, _a(const Color(0xFFE6F6FF), 0.45));
  }
}

/// Earth — The Giant's Palm: a hand of stone up out of the ground, a
/// cluster of crystal grown in it.
class _GiantsPalm extends KeepsakeArt {
  _GiantsPalm() : super(const Color(0xFF7FE0C8));

  final StoneLight _rock = StoneLight(const Color(0xFFC9A46A), warm: 0.02);
  final _Grains _motes = _Grains(40);

  @override
  Rect get box => const Rect.fromLTRB(-62, -160, 62, 4);

  /// In its palm, among the crystal.
  @override
  double? get seat => 90;

  @override
  void body(Canvas c) {
    final r = _rock;
    // The forearm, out of the ground, leaning.
    _shaft(c, r, 0, 4, -56, 40, 32, lean: -4);
    // The palm.
    final palm = _poly(const [
      Offset(-28, -52),
      Offset(24, -54),
      Offset(30, -78),
      Offset(18, -92),
      Offset(-20, -92),
      Offset(-32, -76),
    ]);
    _solid(c, palm, r.ink);
    _shade(c, palm, _litAcross(r, -32, 30, k: 0.55));
    // Fingers curling up round what it holds, and the thumb.
    void finger(double x, double h, double lean, double w) =>
        _shaft(c, r, x, -88, -88 - h, w, w * 0.7, lean: lean);
    finger(-17, 44, -6, 10);
    finger(-5, 56, -2, 10);
    finger(7, 52, 2, 10);
    finger(18, 40, 6, 9);
    _shaft(c, r, -30, -70, -104, 11, 8, lean: -10);
    // The crystal in its palm.
    for (final (x, h, lean) in const [
      (0.0, 58.0, 0.0),
      (-10.0, 40.0, -9.0),
      (10.0, 44.0, 8.0),
      (-3.0, 30.0, -16.0),
      (6.0, 28.0, 16.0),
    ]) {
      final base = Offset(x, -92);
      final tip = base + Offset(lean, -h);
      CutStone.gem(m, [
        base + const Offset(-5, 0),
        base + Offset(-5 + lean * 0.6, -h * 0.75),
        tip,
        base + Offset(5 + lean * 0.6, -h * 0.75),
        base + const Offset(5, 0),
      ], base + Offset(lean * 0.4, -h * 0.45)).paint(c, 0, glow: 1.4, reach: h);
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    final pulse = 0.85 + 0.15 * math.sin(k.t * 1.1);
    paintDisc(c, m.pool, const Offset(0, -120), 64, (0.5 + 0.6 * k.night) * pulse);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    paintDisc(
      c,
      m.spark,
      const Offset(0, -128),
      8 + 6 * k.stir,
      0.3 + 0.3 * math.sin(k.t * 1.1).abs() + 0.4 * k.stir,
    );
    _motes.clear();
    for (var i = 0; i < 26; i++) {
      final f = (k.t * (0.08 + 0.05 * _hash(i, 9)) + _hash(i, 10)) % 1.0;
      _motes.add(
        (_hash(i, 11) - 0.5) * 50 + math.sin(k.t + i) * 3,
        -100 - f * 70,
      );
    }
    _motes.draw(c, 1.5, _a(m.grainHot, 0.55));
  }
}

/// Lightning — Thunderbolt: glass a bolt made, branching up out of the
/// ground, a spark still crawling through it.
class _Fulgurite extends KeepsakeArt {
  _Fulgurite() : super(const Color(0xFFFFE36B));

  /// The branches: from, to, width at its foot.
  static const _branches = <(Offset, Offset, double)>[
    (Offset(0, 0), Offset(-6, -64), 14),
    (Offset(-6, -64), Offset(4, -118), 10),
    (Offset(4, -118), Offset(-4, -160), 6),
    (Offset(-6, -64), Offset(-34, -98), 7),
    (Offset(-34, -98), Offset(-42, -132), 4.5),
    (Offset(4, -118), Offset(30, -140), 5),
    (Offset(-2, -36), Offset(26, -70), 6),
    (Offset(26, -70), Offset(40, -104), 4),
  ];

  final _Grains _spark = _Grains(60);

  @override
  Rect get box => const Rect.fromLTRB(-52, -168, 52, 4);

  @override
  void body(Canvas c) {
    // A mound of fused sand at its foot.
    final mound = _poly(const [
      Offset(-30, 2),
      Offset(-18, -8),
      Offset(0, -12),
      Offset(20, -7),
      Offset(32, 2),
    ]);
    _solid(c, mound, m.ink);
    _shade(c, mound, _litAcross(m, -30, 32, k: 0.4));
    for (final (a, b, w) in _branches) {
      final d = b - a;
      final n = Offset(-d.dy, d.dx) / d.distance;
      // Jagged as glass a bolt drew: kinked once along its length.
      final kink = a + d * 0.5 + n * w * 0.5;
      final path = _poly([
        a + n * w / 2,
        kink + n * w * 0.4,
        b + n * w * 0.2,
        b - n * w * 0.2,
        kink - n * w * 0.4,
        a - n * w / 2,
      ]);
      _glass(c, m, path, a + d * 0.4, w * 2.2);
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, const Offset(0, -80), 70, 0.35 + 0.45 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    // A spark crawling up one branch after another, leaving a trail.
    _spark.clear();
    final speed = 0.5 + 2.5 * k.stir;
    for (var s = 0; s < 2; s++) {
      final along = (k.t * speed * 0.6 + s * 0.5) % _branches.length;
      final bi = along.floor();
      final (a, b, _) = _branches[bi];
      final f = along - bi;
      for (var j = 0; j < 14; j++) {
        final g = (f - j * 0.025).clamp(0.0, 1.0);
        final at = Offset.lerp(a, b, g)!;
        _spark.add(at.dx + (_hash(j, 3) - 0.5) * 2, at.dy);
      }
      final head = Offset.lerp(a, b, f)!;
      paintDisc(c, m.spark, head, 9 + 8 * k.stir, 0.8);
    }
    _spark.draw(c, 1.9, _a(const Color(0xFFFFF6C8), 0.8));
  }
}

/// Steam — Hidden Harmony: three pipes that breathe steam, one after
/// another, in time.
class _HarmonyPipes extends KeepsakeArt {
  _HarmonyPipes() : super(const Color(0xFFE8C88A));

  static const _pipes = <(double, double, double)>[
    (-20.0, 128.0, 14.0),
    (0.0, 168.0, 16.0),
    (20.0, 108.0, 13.0),
  ];
  final _Grains _steam = _Grains(150);

  @override
  Rect get box => const Rect.fromLTRB(-48, -230, 48, 4);

  @override
  void body(Canvas c) {
    _plinth(c, m, 76, 16);
    for (final (x, h, w) in _pipes) {
      _shaft(c, m, x, -16, -16 - h, w, w * 0.9);
      // The lip, and the mouth lit by what breathes through it.
      _block(c, m, Rect.fromLTRB(x - w * 0.62, -20 - h, x + w * 0.62, -15 - h),
          bevel: 1.2);
      _glass(
        c,
        m,
        _poly([
          Offset(x - w * 0.3, -40),
          Offset(x + w * 0.3, -40),
          Offset(x + w * 0.2, -30),
          Offset(x - w * 0.2, -30),
        ]),
        Offset(x, -35),
        12,
      );
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 70, 0.2 + 0.4 * k.night);
  }

  /// How hard pipe [i] is breathing at [t]: a chord rolled up and down.
  double _breath(int i, double t) {
    final phase = (t / 1.6) % 1;
    final which = [0, 1, 2, 1][(t / 1.6).floor() % 4];
    return which == i ? math.sin(phase * math.pi) : 0;
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    _steam.clear();
    for (var p = 0; p < 3; p++) {
      final (x, h, w) = _pipes[p];
      final top = -20 - h;
      final b = math.max(_breath(p, k.t), k.stir * 0.8);
      paintDisc(c, m.spark, Offset(x, -35), 6, 0.25 + 0.6 * b);
      for (var i = 0; i < 44; i++) {
        final f = (k.t * (0.25 + 0.15 * _hash(i, p)) + _hash(i, p + 5)) % 1.0;
        final spread = f * (8 + 26 * f);
        final dx = (_hash(i, p + 9) - 0.5) * spread + math.sin(k.t + i) * 3 * f;
        _steam.add(x + dx, top - f * (40 + 70 * (0.4 + 0.6 * b)));
      }
    }
    _steam.draw(c, 2.2, _a(const Color(0xFFE9EEF2), 0.32));
  }
}

/// Lava — Black Glass: the pour you threw away, standing as a mirror of
/// obsidian, its seams still molten.
class _BlackGlass extends KeepsakeArt {
  _BlackGlass() : super(const Color(0xFFFF6A2A));

  static const _outline = <Offset>[
    Offset(-30, 0),
    Offset(-36, -50),
    Offset(-28, -118),
    Offset(-8, -152),
    Offset(16, -140),
    Offset(34, -96),
    Offset(30, -36),
    Offset(26, 0),
  ];
  static const _seams = <List<Offset>>[
    [Offset(-30, -20), Offset(-12, -46), Offset(-16, -78), Offset(4, -104)],
    [Offset(-12, -46), Offset(14, -60), Offset(28, -88)],
    [Offset(4, -104), Offset(-6, -132)],
  ];
  final _Grains _heat = _Grains(50);

  @override
  Rect get box => const Rect.fromLTRB(-40, -160, 40, 4);

  @override
  void body(Canvas c) {
    final slab = _poly(_outline);
    CutStone.gem(m, _outline, const Offset(-4, -70)).paint(c, 0, glow: 0.6);
    // The mirror face: a darker plane catching a cold sheen.
    c.save();
    c.clipPath(slab);
    _shade(
      c,
      Path()..addRect(const Rect.fromLTRB(-40, -160, 40, 0)),
      ui.Gradient.linear(const Offset(-30, -150), const Offset(30, 0), [
        const Color(0x40E8ECF5),
        const Color(0x00000000),
        const Color(0x10E8ECF5),
      ], const [0.0, 0.5, 1.0]),
    );
    c.restore();
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 80, 0.3 + 0.5 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final glow = 0.55 + 0.25 * math.sin(k.t * 0.8) + 0.4 * k.stir;
    for (final seam in _seams) {
      for (var i = 0; i < seam.length - 1; i++) {
        final a = seam[i], b = seam[i + 1];
        final d = b - a;
        final n = Offset(-d.dy, d.dx) / d.distance;
        // A molten seam: wide in the middle, closing at both ends.
        final w = 2.4 * glow;
        final path = _poly([a, a + d * 0.5 + n * w, b, a + d * 0.5 - n * w]);
        _shade(
          c,
          path,
          ui.Gradient.linear(a, b, [
            _a(m.hot, 0.5 * glow),
            _a(m.essence, 0.95 * glow),
            _a(m.hot, 0.5 * glow),
          ], const [0.0, 0.5, 1.0]),
        );
        paintDisc(c, m.pool, a + d * 0.5, 12, 0.6 * glow);
      }
    }
    _heat.clear();
    for (var i = 0; i < 30; i++) {
      final f = (k.t * 0.22 + _hash(i, 4)) % 1.0;
      _heat.add(
        (_hash(i, 5) - 0.5) * 50 + math.sin(k.t * 2 + i) * 4,
        -150 - f * 50,
      );
    }
    _heat.draw(c, 1.6, _a(m.grainHot, 0.45 * (1 - 0.3 * k.night)));
  }
}

/// Poison — The Dose: an alembic on its stand, always working, a drop
/// falling into the vial at its spout.
class _TheDose extends KeepsakeArt {
  _TheDose() : super(const Color(0xFFB37BFF));

  static const _flask = Offset(-14, -62);
  static const _r = 26.0;
  static const _spout = Offset(44, -88);
  final _Grains _bubbles = _Grains(40);

  @override
  Rect get box => const Rect.fromLTRB(-50, -150, 62, 4);

  @override
  void body(Canvas c) {
    final s = StoneLight(const Color(0xFFCFA86A), warm: 0.02);
    // The stand: three legs and a ring under the flask.
    for (final (x, lean) in const [(-34.0, -6.0), (6.0, 6.0), (-14.0, 0.0)]) {
      _shaft(c, s, x, 0, -38, 4, 3, lean: lean);
    }
    _block(c, s, const Rect.fromLTRB(-42, -40, 14, -36), bevel: 1.2);
    // The flask: a sphere of glass, the dose low in it.
    final bowl = Path()..addOval(Rect.fromCircle(center: _flask, radius: _r));
    _solid(c, bowl, _a(Color.lerp(m.ink, m.essence, 0.2)!, 0.9));
    c.save();
    c.clipPath(bowl);
    _shade(
      c,
      Path()..addRect(Rect.fromLTRB(-50, _flask.dy - 2, 20, 0)),
      ui.Gradient.linear(Offset(0, _flask.dy), Offset(0, _flask.dy + _r), [
        _a(m.essence, 0.85),
        _a(Color.lerp(m.essence, m.ink, 0.5)!, 0.95),
      ]),
    );
    c.restore();
    paintDisc(c, kGlint, _flask + const Offset(-10, -12), 6, 0.6);
    // The neck, up and over to the spout.
    final neck = Path()
      ..moveTo(_flask.dx - 5, _flask.dy - _r + 2)
      ..lineTo(_flask.dx - 4, -112)
      ..quadraticBezierTo(_flask.dx + 6, -132, 22, -110)
      ..lineTo(_spout.dx + 2, _spout.dy - 2)
      ..lineTo(_spout.dx - 2, _spout.dy + 3)
      ..lineTo(18, -104)
      ..quadraticBezierTo(_flask.dx + 6, -122, _flask.dx + 4, -110)
      ..lineTo(_flask.dx + 5, _flask.dy - _r + 2)
      ..close();
    _glass(c, m, neck, const Offset(10, -116), 20);
    // The vial at the spout's foot.
    final vial = _poly(const [
      Offset(38, -2),
      Offset(36, -34),
      Offset(52, -34),
      Offset(50, -2),
    ]);
    _glass(c, m, vial, const Offset(44, -8), 14);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, _flask, 54, 0.45 + 0.5 * k.night);
    _groundPool(c, m, 0, 70, 0.2 + 0.4 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    _bubbles.clear();
    final boil = 1 + 1.5 * k.stir;
    for (var i = 0; i < 24; i++) {
      final f = (k.t * (0.3 + 0.2 * _hash(i, 1)) * boil + _hash(i, 2)) % 1.0;
      _bubbles.add(
        _flask.dx + (_hash(i, 3) - 0.5) * _r * 1.3,
        _flask.dy + _r * 0.85 - f * _r * 0.9,
      );
    }
    _bubbles.draw(c, 2.2, _a(m.hot, 0.55));
    // A drop gathering at the spout and falling.
    final f = (k.t / 2.4) % 1.0;
    final drop = f < 0.6
        ? _spout + Offset(0, 2 + f * 3)
        : _spout + Offset(0, 4 + math.pow((f - 0.6) / 0.4, 2) * 52);
    paintOrb(c, m, drop, 2.4);
    paintDisc(c, m.spark, const Offset(44, -12), 6, 0.3 + 0.2 * math.sin(k.t));
  }
}

/// Mud — No Mud No Lotus: a lotus of pink glass in a pool of mud, open by
/// day and closed by night.
class _MudLotus extends KeepsakeArt {
  _MudLotus() : super(const Color(0xFFF29BC0));

  final StoneLight _mud = StoneLight(const Color(0xFF8A6A4A));
  final StoneLight _pad = StoneLight(const Color(0xFF6FAF6A));
  final _Grains _pollen = _Grains(30);

  @override
  Rect get box => const Rect.fromLTRB(-58, -96, 58, 4);

  @override
  void body(Canvas c) {
    final pool = Path()
      ..addOval(const Rect.fromLTRB(-58, -14, 58, 4));
    _solid(c, pool, _mud.ink);
    _shade(
      c,
      pool,
      ui.Gradient.linear(const Offset(0, -14), const Offset(0, 4), [
        Color.lerp(_mud.face, _mud.rim, 0.25)!,
        _mud.ink,
      ]),
    );
    for (final (x, y, r) in const [
      (-34.0, -6.0, 15.0),
      (30.0, -4.0, 13.0),
      (8.0, -9.0, 10.0),
    ]) {
      final pad = Path()
        ..addOval(Rect.fromCenter(center: Offset(x, y), width: r * 2, height: r * 0.6));
      _solid(c, pad, _pad.ink);
      _shade(c, pad, _litAcross(_pad, x - r, x + r, k: 0.5));
    }
    // The stem.
    _shaft(c, _pad, 0, -8, -40, 3.4, 2.6);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, const Offset(0, -50), 48, 0.3 + 0.3 * k.daylight);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final open = (0.15 + 0.85 * k.daylight) * (1 + 0.1 * k.stir);
    const heart = Offset(0, -44);
    // Back petals, then front: each spreads from upright as it opens.
    for (final back in const [true, false]) {
      for (var i = 0; i < 4; i++) {
        final side = i.isEven ? -1.0 : 1.0;
        final rank = i ~/ 2;
        final spread = (0.12 + rank * 0.3) * open * 1.5;
        final a = -math.pi / 2 + side * spread * (back ? 0.8 : 1.15);
        final len = (back ? 30 : 34) - rank * 4.0;
        _leaf(c, m, heart, a, len, back ? 13 : 15, glow: back ? 0.9 : 1.3);
      }
    }
    paintOrb(c, StoneLight(const Color(0xFFFFD27A)), heart + const Offset(0, -6), 5 * open);
    _pollen.clear();
    for (var i = 0; i < 16; i++) {
      final f = (k.t * 0.1 + _hash(i, 3)) % 1.0;
      _pollen.add(
        heart.dx + (_hash(i, 4) - 0.5) * 40 * open + math.sin(k.t + i) * 4,
        heart.dy - 8 - f * 40,
      );
    }
    _pollen.draw(c, 1.4, _a(const Color(0xFFFFE3A6), 0.5 * open));
  }
}

/// Ice — The Star Walker: a telescope on its tripod, the stranger caught
/// in its lens as a leaded star.
class _StarWalker extends KeepsakeArt {
  _StarWalker() : super(const Color(0xFFA9E8FF));

  static const _pivot = Offset(0, -92);
  static const _angle = -0.62; // up and to the right
  final StoneLight _brass = StoneLight(const Color(0xFFD9B26A), warm: 0.02);
  final _Grains _beam = _Grains(60);

  Offset get _lens => _pivot + polar(70, _angle);

  @override
  Rect get box => const Rect.fromLTRB(-50, -165, 78, 4);

  @override
  void body(Canvas c) {
    for (final (x, lean) in const [(-22.0, 12.0), (22.0, -12.0), (0.0, 0.0)]) {
      _shaft(c, _brass, x, 0, -88, 5, 3.4, lean: lean);
    }
    // The tube: three sections narrowing to the eyepiece.
    c
      ..save()
      ..translate(_pivot.dx, _pivot.dy)
      ..rotate(_angle);
    for (final (x0, x1, h) in const [
      (-46.0, -18.0, 7.0),
      (-18.0, 30.0, 10.0),
      (30.0, 66.0, 13.0),
    ]) {
      final tube = _poly([
        Offset(x0, -h * 0.85),
        Offset(x1, -h),
        Offset(x1, h),
        Offset(x0, h * 0.85),
      ]);
      _solid(c, tube, m.ink);
      _shade(
        c,
        tube,
        ui.Gradient.linear(Offset(0, -h), Offset(0, h), [
          Color.lerp(m.face, m.rim, 0.55)!,
          m.face,
          m.ink,
        ], const [0.0, 0.4, 1.0]),
      );
      _block(c, _brass, Rect.fromLTRB(x1 - 2, -h - 1, x1 + 2, h + 1), bevel: 1);
    }
    c.restore();
    paintOrb(c, _brass, _pivot, 5);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, _lens, 34 + 20 * k.night, 0.4 + 0.7 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final lens = _lens;
    // The lens, and the star leaded in it.
    final face = Path()
      ..addOval(Rect.fromCenter(center: lens, width: 10, height: 26));
    _glass(c, m, face, lens, 18);
    final tw = 0.7 + 0.3 * math.sin(k.t * 2.3) + 0.4 * k.stir;
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + 0.2;
      _shade(
        c,
        _poly([
          lens + polar(1.6, a - math.pi / 2),
          lens + polar(9 * tw, a),
          lens + polar(1.6, a + math.pi / 2),
        ]),
        ui.Gradient.radial(lens, 9, [_a(m.hot, 1), _a(m.essence, 0.3)]),
      );
    }
    paintDisc(c, m.spark, lens, 7 * tw, 0.9);
    // By night, a faint thread of grains out along where it looks.
    if (k.night > 0.05) {
      _beam.clear();
      for (var i = 0; i < 40; i++) {
        final f = (k.t * 0.15 + _hash(i, 2)) % 1.0;
        final at = lens + polar(8 + f * 110, _angle);
        _beam.add(at.dx + (_hash(i, 3) - 0.5) * 6 * f, at.dy);
      }
      _beam.draw(c, 1.4, _a(m.grainHot, 0.35 * k.night));
    }
  }
}

/// Dust — Nothing Perishes: an hourglass that turns itself over when it
/// has run out.
class _Hourglass extends KeepsakeArt {
  _Hourglass() : super(const Color(0xFFF0CF8E));

  static const _mid = -66.0;
  static const _half = 44.0;
  static const _run = 30.0;
  final _Grains _sand = _Grains(260);
  final _Grains _stream = _Grains(40);

  @override
  Rect get box => const Rect.fromLTRB(-36, -136, 36, 4);

  @override
  void body(Canvas c) {
    _plinth(c, m, 52, 8);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, const Offset(0, _mid), 50, 0.35 + 0.5 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final cycle = k.t % (_run + 2.4);
    final turning = cycle > _run;
    final turn = turning ? (cycle - _run) / 2.4 : 0.0;
    final ease = turn * turn * (3 - 2 * turn);
    final ran = turning ? 1.0 : cycle / _run;
    c
      ..save()
      ..translate(0, _mid)
      ..rotate(ease * math.pi);
    // The frame: two discs and three posts.
    for (final y in const [-_half - 6, _half]) {
      _block(c, m, Rect.fromLTRB(-28, y, 28, y + 6), bevel: 1.6);
    }
    for (final x in const [-24.0, 24.0]) {
      _shaft(c, m, x, _half, -_half, 4, 4);
    }
    // The glass.
    Path bulb(double dir) => Path()
      ..moveTo(-3, 0)
      ..cubicTo(-4, dir * 10, -20, dir * 14, -18, dir * (_half - 4))
      ..lineTo(18, dir * (_half - 4))
      ..cubicTo(20, dir * 14, 4, dir * 10, 3, 0)
      ..close();
    for (final dir in const [-1.0, 1.0]) {
      final b = bulb(dir);
      _solid(c, b, _a(Color.lerp(m.ink, m.essence, 0.14)!, 0.75));
      paintDisc(c, kGlint, Offset(-9, dir * 24), 4, 0.35);
    }
    // The sand: what is left above, the heap below, the thread between.
    _sand.clear();
    final above = 1 - ran, below = ran;
    for (var i = 0; i < 120; i++) {
      final u = _hash(i, 1), v = _hash(i, 2);
      if (v < above) {
        final y = -4 - v / math.max(above, 1e-3) * (_half - 10) * above;
        final w = 4 + (-y / _half) * 16;
        _sand.add((u - 0.5) * w * 1.6, y);
      }
      if (v < below) {
        final h = (_half - 6) * below * 0.75;
        final y = _half - 5 - v / math.max(below, 1e-3) * h;
        final w = 16 * (1 - (_half - 5 - y) / math.max(h, 1)) + 2;
        _sand.add((u - 0.5) * w * 2, y);
      }
    }
    _sand.draw(c, 2.1, _a(m.grainHot, 0.9));
    if (!turning && ran < 0.995) {
      _stream.clear();
      for (var i = 0; i < 18; i++) {
        final f = (k.t * 1.4 + i / 18) % 1.0;
        _stream.add((_hash(i, 4) - 0.5) * 1.2, f * (_half - 6));
      }
      _stream.draw(c, 1.6, _a(m.grainHot, 0.85));
    }
    c.restore();
  }
}

/// Crystal — Know Thyself: a geode split open, its crystals round a
/// silvered eye.
class _KnowThyself extends KeepsakeArt {
  _KnowThyself() : super(const Color(0xFF6FF2D0));

  static const _eye = Offset(0, -56);
  final StoneLight _shell = StoneLight(const Color(0xFF8A8F9A));
  final StoneLight _silver = StoneLight(const Color(0xFFE6ECF5));

  @override
  Rect get box => const Rect.fromLTRB(-58, -118, 58, 4);

  @override
  void body(Canvas c) {
    final outer = <Offset>[
      for (var i = 0; i <= 16; i++)
        _eye +
            polar(
              50 + 6 * math.sin(i * 2.3),
              math.pi + i / 16 * math.pi * 2,
            ).scale(1, 1.05),
    ];
    final shell = _poly([
      ...outer.where((o) => o.dy <= 0),
      const Offset(46, 0),
      const Offset(-46, 0),
    ]);
    _solid(c, shell, _shell.ink);
    _shade(c, shell, _litAcross(_shell, -56, 56, k: 0.45));
    // The hollow, crystals pointing in from its wall.
    final hollow = Path()..addOval(Rect.fromCircle(center: _eye, radius: 38));
    _solid(c, hollow, m.ink);
    c.save();
    c.clipPath(hollow);
    for (var i = 0; i < 18; i++) {
      final a = i / 18 * math.pi * 2;
      final base = _eye + polar(40, a);
      final tip = _eye + polar(22 + 6 * math.sin(i * 1.9), a);
      final n = polar(5.5, a + math.pi / 2);
      CutStone.gem(m, [base + n, tip, base - n], Offset.lerp(base, tip, 0.4)!)
          .paint(c, a, glow: 1.2, reach: 18);
    }
    c.restore();
    // The eye: a disc of silver.
    paintOrb(c, _silver, _eye, 15);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, _eye, 62, 0.4 + 0.5 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    // Light passing across the silver, as an eye catches it.
    final sweep = math.sin(k.t * 0.55);
    paintDisc(
      c,
      kGlint,
      _eye + Offset(sweep * 8, -4 - sweep.abs() * 3),
      6 + 4 * k.stir,
      0.5 + 0.4 * k.stir,
    );
    for (var i = 0; i < 5; i++) {
      final on = math.max(0.0, math.sin(k.t * 0.9 + i * 1.7));
      paintDisc(
        c,
        m.spark,
        _eye + polar(28, i * 1.26 + 0.4),
        4,
        on * on * 0.8,
      );
    }
  }
}

/// Plant — The Seed That Wanted the Opposite: dark petals round an amber
/// heart, on a tall stem whose leaves fall upward.
class _OppositeFlower extends KeepsakeArt {
  _OppositeFlower() : super(const Color(0xFFFFB347));

  static const _heart = Offset(0, -142);
  final StoneLight _petal = StoneLight(const Color(0xFF7A4AA8));
  final StoneLight _green = StoneLight(const Color(0xFF6FAF6A));
  final _Grains _rising = _Grains(40);

  @override
  Rect get box => const Rect.fromLTRB(-42, -178, 42, 4);

  @override
  void body(Canvas c) {
    // The planter.
    final pot = _poly(const [
      Offset(-24, -30),
      Offset(24, -30),
      Offset(18, 0),
      Offset(-18, 0),
    ]);
    _solid(c, pot, m.ink);
    _shade(c, pot, _litAcross(m, -24, 24, k: 0.4));
    _block(c, m, const Rect.fromLTRB(-27, -34, 27, -28), bevel: 1.6);
    // The stem, bowing.
    final stem = Path()
      ..moveTo(-1.6, -32)
      ..quadraticBezierTo(-12, -90, _heart.dx - 1.6, _heart.dy + 10)
      ..lineTo(_heart.dx + 1.6, _heart.dy + 10)
      ..quadraticBezierTo(-8, -90, 1.6, -32)
      ..close();
    _solid(c, stem, _green.ink);
    _shade(c, stem, _litAcross(_green, -12, 4, k: 0.5));
    // Leaves on the stem — pointing up, as everything here does.
    for (final (y, side) in const [(-60.0, -1.0), (-84.0, 1.0), (-104.0, -1.0)]) {
      _leaf(c, _green, Offset(-6, y), -math.pi / 2 + side * 0.9, 24, 9);
    }
    // The dark petals.
    for (var i = 0; i < 7; i++) {
      final a = -math.pi / 2 + (i - 3) * 0.42;
      _leaf(c, _petal, _heart, a, 30, 13, glow: 0.6);
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, _heart, 50, 0.45 + 0.5 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final pulse = 0.8 + 0.2 * math.sin(k.t * 1.4) + 0.3 * k.stir;
    paintOrb(c, m, _heart, 7 * pulse);
    paintDisc(c, m.spark, _heart, 10 * pulse, 0.5);
    // Bits of leaf drifting UP from the stem.
    _rising.clear();
    for (var i = 0; i < 22; i++) {
      final f = (k.t * (0.06 + 0.04 * _hash(i, 1)) + _hash(i, 2)) % 1.0;
      _rising.add(
        -8 + (_hash(i, 3) - 0.5) * 30 + math.sin(k.t * 0.8 + i) * 6,
        -40 - f * 150,
      );
    }
    _rising.draw(c, 1.8, _a(const Color(0xFFA7D99A), 0.5));
  }
}

/// Spirit — Stuff of Dreams: the undug grave's headstone, a lancet window
/// lit inside it.
class _LancetStone extends KeepsakeArt {
  _LancetStone() : super(const Color(0xFF9FA8FF));

  final _Grains _wisps = _Grains(50);

  @override
  Rect get box => const Rect.fromLTRB(-38, -150, 38, 4);

  Path _arch(double hw, double top, double bottom) => Path()
    ..moveTo(-hw, bottom)
    ..lineTo(-hw, top + hw * 1.2)
    ..quadraticBezierTo(-hw, top + hw * 0.2, 0, top)
    ..quadraticBezierTo(hw, top + hw * 0.2, hw, top + hw * 1.2)
    ..lineTo(hw, bottom)
    ..close();

  @override
  void body(Canvas c) {
    _block(c, m, const Rect.fromLTRB(-36, -12, 36, 0), bevel: 2.4);
    final slab = _arch(30, -146, -12);
    _solid(c, slab, m.ink);
    _shade(c, slab, _litAcross(m, -30, 30, k: 0.5));
    // The lancet: leaded panes of lit glass.
    final window = _arch(12, -122, -36);
    _glass(c, m, window, const Offset(0, -70), 50);
    // The leading between the panes: dark stone bars, filled, not drawn.
    for (final y in const [-92.0, -64.0]) {
      _solid(c, Path()..addRect(Rect.fromLTRB(-12, y - 1.2, 12, y + 1.2)), m.ink);
    }
    _solid(c, Path()..addRect(const Rect.fromLTRB(-1.2, -112, 1.2, -36)), m.ink);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    final b = 0.85 + 0.15 * math.sin(k.t * 0.7);
    paintDisc(c, m.pool, const Offset(0, -80), 56, (0.4 + 0.6 * k.night) * b);
    _groundPool(c, m, 0, 70, 0.2 + 0.5 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final b = 0.75 + 0.25 * math.sin(k.t * 0.7) + 0.3 * k.stir;
    paintDisc(c, m.spark, const Offset(0, -78), 18 * b, 0.25 * b);
    // Wisps rising off it — more by night.
    _wisps.clear();
    final n = (14 + 26 * k.night).round();
    for (var i = 0; i < n; i++) {
      final f = (k.t * (0.05 + 0.03 * _hash(i, 1)) + _hash(i, 2)) % 1.0;
      _wisps.add(
        (_hash(i, 3) - 0.5) * 50 + math.sin(k.t * 0.6 + i * 1.3) * 10 * f,
        -20 - f * 160,
      );
    }
    _wisps.draw(c, 2, _a(m.grainHot, 0.35));
  }
}

/// Dark — The Abyss: one of a pair of portals, standing frames of
/// obsidian round a turning black. What walks into one walks out of the
/// other. One is lit violet, the other orange.
class _Portal extends KeepsakeArt {
  _Portal(bool orange)
    : super(orange ? const Color(0xFFFF9A3C) : const Color(0xFF9B5CFF));

  static const _c = Offset(0, -74);
  static const _rx = 30.0, _ry = 54.0;
  final _Grains _swirl = _Grains(260);
  final _Grains _swirlHot = _Grains(80);

  @override
  Rect get box => const Rect.fromLTRB(-50, -146, 50, 4);

  @override
  void body(Canvas c) {
    _plinth(c, m, 70, 10);
    // The frame: a solid band of cut stone round the opening.
    const n = 28;
    for (var i = 0; i < n; i++) {
      final a0 = i / n * math.pi * 2, a1 = (i + 1) / n * math.pi * 2;
      Offset at(double a, double k) =>
          _c + Offset(math.cos(a) * (_rx + k), math.sin(a) * (_ry + k));
      final face = _poly([at(a0, 0), at(a1, 0), at(a1, 12), at(a0, 12)]);
      final mid = (a0 + a1) / 2;
      _solid(c, face, m.ink);
      _shade(
        c,
        face,
        ui.Gradient.linear(at(mid, 0), at(mid, 12), [
          // The inner lip holds the light of what turns inside it; the
          // outer face is obsidian, lit only where it faces the key light.
          Color.lerp(m.ink, m.essence, 0.42)!,
          m.face,
          Color.lerp(m.face, m.rim, 0.06 + 0.3 * keyLit(polar(1, mid), 0))!,
        ], const [0.0, 0.35, 1.0]),
      );
    }
    // The dark inside.
    _solid(
      c,
      Path()
        ..addOval(Rect.fromCenter(center: _c, width: _rx * 2, height: _ry * 2)),
      const Color(0xFF05040A),
    );
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, _c, 66, 0.45 + 0.5 * k.night + 0.4 * k.stir);
    _groundPool(c, m, 0, 80, 0.3 + 0.5 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final spin = k.t * (0.6 + 2.4 * k.stir);
    _swirl.clear();
    _swirlHot.clear();
    for (var i = 0; i < 200; i++) {
      // Grains spiralling in to the dark heart and born again at the rim.
      final f = (k.t * (0.12 + 0.08 * _hash(i, 1)) + _hash(i, 2)) % 1.0;
      final r = 1 - f;
      final a = _hash(i, 3) * math.pi * 2 + spin + f * 4;
      final at = _c + Offset(math.cos(a) * _rx * r, math.sin(a) * _ry * r);
      (i % 4 == 0 ? _swirlHot : _swirl).add(at.dx, at.dy);
    }
    _swirl.draw(c, 1.6, _a(m.essence, 0.7));
    _swirlHot.draw(c, 1.9, _a(m.grainHot, 0.85));
    paintDisc(c, m.leak, _c, 34, 0.35 + 0.5 * k.stir);
  }
}

/// Light — Afraid of the Light: a book of night glass lying open on its
/// lectern, its lines lit.
class _NightBook extends KeepsakeArt {
  _NightBook() : super(const Color(0xFFFFE9A8));

  final StoneLight _night = StoneLight(const Color(0xFF3A4FA8));
  final _Grains _motes = _Grains(50);

  @override
  Rect get box => const Rect.fromLTRB(-48, -128, 48, 4);

  static const _pageL = [Offset(-40, -96), Offset(-2, -88), Offset(-2, -68), Offset(-40, -78)];
  static const _pageR = [Offset(2, -88), Offset(40, -96), Offset(40, -78), Offset(2, -68)];

  @override
  void body(Canvas c) {
    _plinth(c, m, 40, 8);
    _shaft(c, m, 0, -8, -66, 10, 7);
    final top = _poly(const [
      Offset(-44, -80),
      Offset(44, -80),
      Offset(40, -66),
      Offset(-40, -66),
    ]);
    _solid(c, top, m.ink);
    _shade(c, top, _litAcross(m, -44, 44, k: 0.5));
    for (final page in [_pageL, _pageR]) {
      _glass(c, _night, _poly(page), page[1], 30);
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, const Offset(0, -92), 58, 0.4 + 0.6 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    // Its lines, a word at a time lighting along each.
    // The words lit and the words dark, each gathered into one path.
    final lit = Path(), dim = Path();
    for (final (page, x0, x1) in [(_pageL, -36.0, -6.0), (_pageR, 6.0, 36.0)]) {
      for (var line = 0; line < 4; line++) {
        final y0 = page[0].dy + 4 + line * 3.4;
        final y1 = page[1].dy + 4 + line * 3.4;
        for (var w = 0; w < 5; w++) {
          final f = (w + 0.5) / 5;
          final on = math.sin(k.t * 1.3 - w * 0.5 - line * 0.9) > 0.35;
          (on ? lit : dim).addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f),
                width: 4.2,
                height: 1.3,
              ),
              const Radius.circular(0.6),
            ),
          );
        }
      }
    }
    final glow = 0.6 + 0.4 * k.night;
    _solid(c, dim, _a(m.hot, 0.35 * glow));
    _solid(c, lit, _a(m.hot, 0.95 * glow));
    _motes.clear();
    for (var i = 0; i < 30; i++) {
      final f = (k.t * (0.08 + 0.05 * _hash(i, 1)) + _hash(i, 2)) % 1.0;
      _motes.add(
        (_hash(i, 3) - 0.5) * 70 + math.sin(k.t + i) * 4,
        -90 - f * 40 * (1 + k.stir),
      );
    }
    _motes.draw(c, 1.5, _a(m.grainHot, 0.55));
  }
}

/// Blood — The Blood Is the Life: a garnet heart in its cradle, beating.
class _GarnetHeart extends KeepsakeArt {
  _GarnetHeart() : super(const Color(0xFFE0405A));

  static const _at = Offset(0, -98);

  @override
  Rect get box => const Rect.fromLTRB(-36, -136, 36, 4);

  @override
  void body(Canvas c) {
    _plinth(c, m, 46, 10);
    _shaft(c, m, 0, -10, -70, 12, 8);
    // The cradle: two arms of stone up round the heart.
    for (final side in const [-1.0, 1.0]) {
      _shaft(c, m, side * 8, -70, -94, 5, 3, lean: side * 12);
    }
  }

  /// The beat: two strokes close together, then rest.
  double _beat(double t) {
    final p = t % 1.5;
    double stroke(double at) {
      final d = (p - at) / 0.12;
      return math.exp(-d * d);
    }

    return stroke(0.1) + 0.6 * stroke(0.38);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    final b = _beat(k.t);
    paintDisc(c, m.pool, _at, 46 + 14 * b, 0.35 + 0.45 * k.night + 0.4 * b);
    _groundPool(c, m, 0, 60, 0.2 + 0.3 * b);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final b = _beat(k.t * (1 + 0.6 * k.stir));
    final s = 1 + 0.09 * b;
    c
      ..save()
      ..translate(_at.dx, _at.dy)
      ..scale(s);
    CutStone.gem(m, const [
      Offset(0, -12),
      Offset(-9, -20),
      Offset(-19, -14),
      Offset(-18, -2),
      Offset(0, 20),
      Offset(18, -2),
      Offset(19, -14),
      Offset(9, -20),
    ], const Offset(-3, -6)).paint(c, 0, glow: 1 + b, reach: 26);
    c.restore();
  }
}

// ── The contests ───────────────────────────────────────────────────────────

/// Beauty: a mirror in a gold laurel, shards of crystal at its foot.
class _CrownMirror extends KeepsakeArt {
  _CrownMirror() : super(_gold);

  final StoneLight _crystal = StoneLight(const Color(0xFFF2A6E0));
  final StoneLight _silver = StoneLight(const Color(0xFFE6ECF5));
  static const _c = Offset(0, -86);

  @override
  Rect get box => const Rect.fromLTRB(-50, -148, 50, 4);

  @override
  void body(Canvas c) {
    _shaft(c, m, 0, 0, -40, 14, 8);
    final glass = Path()
      ..addOval(Rect.fromCenter(center: _c, width: 50, height: 70));
    _solid(c, glass, _silver.ink);
    _shade(
      c,
      glass,
      ui.Gradient.linear(_c + const Offset(-25, -35), _c + const Offset(25, 35), [
        Color.lerp(_silver.face, _silver.rim, 0.7)!,
        _silver.face,
        _silver.ink,
        Color.lerp(_silver.face, _silver.rim, 0.4)!,
      ], const [0.0, 0.3, 0.7, 1.0]),
    );
    _laurel(c, m, _c, 36, 8, reach: 2.5, leaf: 13);
    for (final (x, h, lean) in const [
      (-22.0, 26.0, -8.0),
      (-12.0, 18.0, -3.0),
      (14.0, 22.0, 6.0),
      (24.0, 14.0, 10.0),
    ]) {
      final base = Offset(x, 0);
      CutStone.gem(_crystal, [
        base + const Offset(-4, 0),
        base + Offset(lean, -h),
        base + const Offset(4, 0),
      ], base + Offset(lean * 0.4, -h * 0.4)).paint(c, 0, glow: 1.2, reach: h);
    }
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, m.pool, _c, 64, 0.35 + 0.45 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    // Light sweeping across the glass.
    final f = (k.t / 5) % 1.0;
    final x = -40 + f * 80;
    c.save();
    c.clipPath(
      Path()..addOval(Rect.fromCenter(center: _c, width: 50, height: 70)),
    );
    _shade(
      c,
      _poly([
        _c + Offset(x - 6, -40),
        _c + Offset(x + 4, -40),
        _c + Offset(x - 8, 40),
        _c + Offset(x - 18, 40),
      ]),
      ui.Gradient.linear(_c + Offset(x - 12, 0), _c + Offset(x, 0), [
        const Color(0x00FFFFFF),
        _a(const Color(0xFFFFFFFF), 0.4 + 0.3 * k.stir),
        const Color(0x00FFFFFF),
      ], const [0.0, 0.5, 1.0]),
    );
    c.restore();
  }
}

/// Speed: an arch of two pylons, light running through it.
class _VictoryArch extends KeepsakeArt {
  _VictoryArch() : super(_gold);

  final StoneLight _run = StoneLight(const Color(0xFF8FE3FF));
  final _Grains _streak = _Grains(120);

  @override
  Rect get box => const Rect.fromLTRB(-56, -150, 56, 4);

  @override
  void body(Canvas c) {
    for (final x in const [-38.0, 38.0]) {
      _plinth(c, m, 22, 8);
      c.save();
      c.translate(x, 0);
      _plinth(c, _run, 22, 8);
      _shaft(c, _run, 0, -8, -112, 14, 10);
      c.restore();
    }
    // The span.
    final span = Path()
      ..moveTo(-46, -108)
      ..quadraticBezierTo(0, -150, 46, -108)
      ..lineTo(42, -100)
      ..quadraticBezierTo(0, -136, -42, -100)
      ..close();
    _solid(c, span, _run.ink);
    _shade(c, span, _litAcross(_run, -46, 46, k: 0.5));
    // The gold at its keystone.
    _laurel(c, m, const Offset(0, -128), 10, 3, reach: 1.4, leaf: 9);
    paintOrb(c, m, const Offset(0, -130), 5);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, _run.pool, const Offset(0, -60), 60, 0.35 + 0.4 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    _streak.clear();
    final speed = 1 + 2 * k.stir;
    for (var i = 0; i < 90; i++) {
      final lane = _hash(i, 1);
      final f = (k.t * (0.5 + 0.4 * _hash(i, 2)) * speed + _hash(i, 3)) % 1.0;
      _streak.add(-30 + f * 60, -16 - lane * 86);
    }
    _streak.draw(c, 1.5, _a(_run.grainHot, 0.55));
    for (final x in const [-38.0, 38.0]) {
      paintDisc(c, _run.spark, Offset(x, -100), 5, 0.5 + 0.3 * math.sin(k.t * 3 + x));
    }
  }
}

/// Strength: an anvil on its stump, the forge's glow under it, gold round
/// its foot.
class _TitanAnvil extends KeepsakeArt {
  _TitanAnvil() : super(_gold);

  final StoneLight _forge = StoneLight(const Color(0xFFFF7A3A));
  final _Grains _sparks = _Grains(40);

  @override
  Rect get box => const Rect.fromLTRB(-58, -92, 58, 4);

  /// On the anvil's face.
  @override
  double? get seat => 72;

  @override
  void body(Canvas c) {
    final dark = StoneLight(const Color(0xFF9AA3B5));
    _block(c, _forge, const Rect.fromLTRB(-24, -36, 24, 0), bevel: 2.4);
    // The anvil: waist, body, horn.
    final anvil = _poly(const [
      Offset(-16, -36),
      Offset(16, -36),
      Offset(12, -52),
      Offset(30, -60),
      Offset(34, -72),
      Offset(-28, -72),
      Offset(-52, -66),
      Offset(-30, -60),
      Offset(-12, -52),
    ]);
    _solid(c, anvil, dark.ink);
    _shade(c, anvil, _litAcross(dark, -52, 34, k: 0.45));
    _shade(
      c,
      _poly(const [
        Offset(-28, -72),
        Offset(34, -72),
        Offset(32, -69),
        Offset(-34, -69),
      ]),
      ui.Gradient.linear(const Offset(-28, 0), const Offset(34, 0), [
        Color.lerp(dark.face, dark.rim, 0.9)!,
        dark.face,
      ]),
    );
    _laurel(c, m, const Offset(0, -18), 30, 5, reach: 1.2, leaf: 11);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, _forge, 0, 90, 0.35 + 0.5 * k.night);
    paintDisc(c, _forge.pool, const Offset(0, -20), 40, 0.4 + 0.4 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    _sparks.clear();
    final n = (8 + 24 * k.stir).round();
    for (var i = 0; i < n; i++) {
      final f = (k.t * (0.4 + 0.3 * _hash(i, 1)) + _hash(i, 2)) % 1.0;
      final dir = _hash(i, 3) - 0.5;
      _sparks.add(dir * 70 * f, -72 - 40 * f + 50 * f * f);
    }
    _sparks.draw(c, 1.8, _a(_forge.grainHot, 0.8));
  }
}

/// Intelligence: a prism on a pillar, three glass nodes going round it.
class _PrismOrrery extends KeepsakeArt {
  _PrismOrrery() : super(_gold);

  final StoneLight _glassLight = StoneLight(const Color(0xFFB9A2FF));
  static const _c = Offset(0, -112);

  @override
  Rect get box => const Rect.fromLTRB(-56, -156, 56, 4);

  @override
  void body(Canvas c) {
    _plinth(c, m, 44, 10);
    _shaft(c, m, 0, -10, -88, 12, 8);
    _laurel(c, m, const Offset(0, -92), 14, 3, reach: 1.3, leaf: 10);
    CutStone.gem(_glassLight, [
      _c + const Offset(0, -26),
      _c + const Offset(17, 14),
      _c + const Offset(-17, 14),
    ], _c + const Offset(-3, 2)).paint(c, 0, glow: 1.5, reach: 30);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    paintDisc(c, _glassLight.pool, _c, 60, 0.4 + 0.5 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final nodes = [
      for (var i = 0; i < 3; i++)
        (k.t * (0.5 + 0.2 * i) * (1 + k.stir) + i * 2.1, 30.0 + i * 8, i),
    ];
    void node((double, double, int) n) {
      final (a, r, i) = n;
      final at = _c + Offset(math.cos(a) * r, math.sin(a) * r * 0.32 + 4);
      paintOrb(c, i == 1 ? m : _glassLight, at, 4.5 + math.sin(a) * 1.2);
    }

    for (final n in nodes.where((n) => math.sin(n.$1) < 0)) {
      node(n);
    }
    paintDisc(c, _glassLight.spark, _c, 9, 0.5 + 0.3 * math.sin(k.t * 1.7));
    for (final n in nodes.where((n) => math.sin(n.$1) >= 0)) {
      node(n);
    }
  }
}

// ── The effigy ──────────────────────────────────────────────────────────────

/// The plinth a species' effigy stands on: obsidian banded in gold, its
/// light the champion's. The creature itself is drawn over it in its own
/// grains (see the home biome's effigy component), standing on [top].
class EffigyPlinth extends KeepsakeArt {
  EffigyPlinth() : super(_gold);

  /// Where the effigy's feet stand.
  static const double top = -26;

  @override
  Rect get box => const Rect.fromLTRB(-44, -130, 44, 4);

  @override
  void body(Canvas c) {
    _plinth(c, StoneLight(const Color(0xFF8C96B4)), 70, 26, steps: 3);
    _block(c, m, const Rect.fromLTRB(-30, -18, 30, -14), bevel: 1);
    _laurel(c, m, const Offset(0, -9), 16, 3, reach: 1.1, leaf: 8);
  }

  @override
  void under(Canvas c, KeepsakeTime k) {
    _groundPool(c, m, 0, 70, 0.25 + 0.3 * k.night);
    paintDisc(c, m.pool, const Offset(0, -70), 60, 0.25 + 0.35 * k.night);
  }

  @override
  void live(Canvas c, KeepsakeTime k) {}
}

/// Grains for an effigy: [hx], [hy] are each grain's place (units round
/// the creature's middle), [tone] which of [tones] it is.
void paintEffigyGrains(
  Canvas c, {
  required Float32List hx,
  required Float32List hy,
  required Uint8List tone,
  required List<Color> tones,
  required double scale,
  required Offset middle,
  required double t,
  required double size,
  required List<PointBatch> batches,
}) {
  for (final b in batches) {
    b.clear();
  }
  for (var i = 0; i < hx.length; i++) {
    final shimmer = math.sin(t * 1.3 + i * 0.37) * 0.35;
    batches[tone[i] % batches.length].add(
      middle.dx + hx[i] * scale + shimmer,
      middle.dy + hy[i] * scale,
    );
  }
  for (var b = 0; b < batches.length && b < tones.length; b++) {
    batches[b].draw(c, size, tones[b]);
  }
}
