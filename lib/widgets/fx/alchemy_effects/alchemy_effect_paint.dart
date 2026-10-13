// lib/widgets/fx/alchemy_effects/alchemy_effect_paint.dart
//
// THE SHOP'S ALCHEMY EFFECTS, painted once for every place a creature wears
// one: its details, the party slots, the wilderness and space.
//
//   Each effect is plain Dart driven by the time alone, so the widget, the
//   Flame component and the space renderer all draw the same thing, and a
//   test can scrub it. Grains in batches and radial-gradient pools: no blur,
//   nothing allocated per grain, and everything weighted behind the creature
//   and at its feet — light on the ground, things rising off it — rather than
//   rings orbiting it.
//
// One file per effect, as parts of this library, sharing the kit below.

library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/vfx_shapes.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/widgets/fx/costume_paint.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:flutter/painting.dart';

part 'alchemy_glow.dart';
part 'beauty_radiance.dart';
part 'blood_aura.dart';
part 'cinnabar.dart';
part 'dust_ring.dart';
part 'elemental_aura.dart';
part 'gold_leaf.dart';
part 'ink_bloom.dart';
part 'intelligence_halo.dart';
part 'peacock_tail.dart';
part 'prismatic_cascade.dart';
part 'quicksilver.dart';
part 'ritual_gold.dart';
part 'speed_flux.dart';
part 'spotlight.dart';
part 'strength_forge.dart';
part 'void_rift.dart';
part 'volcanic_aura.dart';
part 'wavebreaker_crown.dart';
part 'will_o_wisps.dart';

/// Paints an alchemy effect by the key stored on the creature.
abstract final class AlchemyEffectPaint {
  static const String alchemyGlow = 'alchemy_glow';
  static const String elementalAura = 'elemental_aura';
  static const String volcanicAura = 'volcanic_aura';
  static const String voidRift = 'void_rift';
  static const String prismaticCascade = 'prismatic_cascade';
  static const String ritualGold = 'ritual_gold';
  static const String bloodAura = 'blood_aura';
  static const String wavebreakerCrown = 'wavebreaker_crown';
  static const String beautyRadiance = 'beauty_radiance';
  static const String speedFlux = 'speed_flux';
  static const String strengthForge = 'strength_forge';
  static const String intelligenceHalo = 'intelligence_halo';
  static const String willOWisps = 'will_o_wisps';
  static const String dustRing = 'dust_ring';

  // The Athanor's: drawn from its batches, never sold
  // (docs/athanor/pieces_wearables.md).
  static const String inkBloom = 'ink_bloom';
  static const String peacockTail = 'peacock_tail';
  static const String quicksilver = 'quicksilver';
  static const String goldLeaf = 'gold_leaf';
  static const String cinnabar = 'cinnabar';

  // The Trials': one for each cup won, never sold.
  static const String copperSpotlight = 'copper_spotlight';
  static const String silverSpotlight = 'silver_spotlight';
  static const String goldSpotlight = 'gold_spotlight';
  static const String rubySpotlight = 'ruby_spotlight';
  static const String sapphireSpotlight = 'sapphire_spotlight';
  static const String emeraldSpotlight = 'emerald_spotlight';

  /// The effects only the Trials give, in cup order: the races', then the
  /// gems'.
  static const List<String> trialsKeys = [
    copperSpotlight,
    silverSpotlight,
    goldSpotlight,
    rubySpotlight,
    sapphireSpotlight,
    emeraldSpotlight,
  ];

  /// The effects only the Athanor gives.
  static const Set<String> athanorKeys = {
    inkBloom,
    peacockTail,
    quicksilver,
    goldLeaf,
    cinnabar,
  };

  /// Every effect there is: the shop's and the Athanor's. These strings are
  /// what owned effects are saved as: never change one.
  static const Set<String> keys = {
    FamilyCostume.hatPreview,
    FamilyCostume.nosePreview,
    FamilyCostume.sunglassesPreview,
    FamilyCostume.crownPreview,
    FamilyCostume.monoclePreview,
    alchemyGlow,
    elementalAura,
    volcanicAura,
    voidRift,
    prismaticCascade,
    ritualGold,
    bloodAura,
    wavebreakerCrown,
    beautyRadiance,
    speedFlux,
    strengthForge,
    intelligenceHalo,
    willOWisps,
    dustRing,
    inkBloom,
    peacockTail,
    quicksilver,
    goldLeaf,
    cinnabar,
    copperSpotlight,
    silverSpotlight,
    goldSpotlight,
    rubySpotlight,
    sapphireSpotlight,
    emeraldSpotlight,
  };

  /// Whether [key] paints round a creature. A worn family costume does
  /// not: it is part of the sprite (see `CostumePaint.paintWorn`).
  static bool has(String? key) => keys.contains(key);

  /// Whether [key] also draws a layer over the creature — Prismatic's and
  /// the Dust Ring's rings, Speed's comets, Intelligence's disk and the
  /// wisps pass in front of it. Hosts paint that with `front: true` after
  /// the sprite.
  static bool hasFront(String? key) =>
      FamilyCostume.ofPreview(key) != null ||
      key == prismaticCascade ||
      key == speedFlux ||
      key == intelligenceHalo ||
      key == willOWisps ||
      key == dustRing ||
      athanorKeys.contains(key) ||
      trialsKeys.contains(key);

  /// Paints [key] behind a creature centred on [center].
  ///
  /// [r] is half the creature's drawn box: its body fills roughly the inner
  /// 0.7 of it, its feet stand near `center.dy + 0.62 * r` and its head
  /// tops out near `center.dy - 0.62 * r`. [t] is in seconds. [element]
  /// picks the Elemental Aura's and the Dust Ring's element — an element
  /// name ('Fire') or a faction ('Volcanic'); anything else is Arcane. [opacity] is the host's
  /// fade. [dark] is false over the light theme's parchment, where pale
  /// light washes out. [front] paints the layer over the creature instead,
  /// for keys that have one (see [hasFront]).
  static void paint(
    Canvas canvas,
    String key,
    Offset center,
    double r,
    double t, {
    String? element,
    double opacity = 1,
    bool dark = true,
    bool front = false,
  }) {
    if (r <= 0 || opacity <= 0) return;
    if (front && !hasFront(key)) return;
    final o = opacity.clamp(0.0, 1.0);
    // A family costume on its own, for a card: only ever over the creature.
    final preview = FamilyCostume.ofPreview(key);
    if (preview != null) {
      if (front) {
        CostumePaint.paintPreview(canvas, preview, center, r, t, opacity: o);
      }
      return;
    }
    switch (key) {
      case alchemyGlow:
        _Resonance.paint(canvas, center, r, t, o, dark);
      case elementalAura:
        _ElementalAura.paint(
          canvas,
          center,
          r,
          t,
          _ElementalAura.resolve(element),
          o,
          dark,
        );
      case volcanicAura:
        _Volcanic.paint(canvas, center, r, t, o, dark);
      case voidRift:
        _VoidRift.paint(canvas, center, r, t, o, dark);
      case prismaticCascade:
        _Prismatic.paint(canvas, center, r, t, o, dark, front);
      case ritualGold:
        _GoldenRite.paint(canvas, center, r, t, o, dark);
      case bloodAura:
        _BloodAura.paint(canvas, center, r, t, o, dark);
      case wavebreakerCrown:
        _Wavebreaker.paint(canvas, center, r, t, o, dark);
      case beautyRadiance:
        _Beauty.paint(canvas, center, r, t, o, dark);
      case speedFlux:
        _Speed.paint(canvas, center, r, t, o, dark, front);
      case strengthForge:
        _Strength.paint(canvas, center, r, t, o, dark);
      case intelligenceHalo:
        _Intelligence.paint(canvas, center, r, t, o, dark, front);
      case willOWisps:
        _Wisps.paint(canvas, center, r, t, o, dark, front);
      case dustRing:
        _DustRing.paint(
          canvas,
          center,
          r,
          t,
          _ElementalAura.resolve(element),
          o,
          dark,
          front,
        );
      case inkBloom:
        _InkBloom.paint(canvas, center, r, t, o, dark, front, element);
      case peacockTail:
        _PeacockTail.paint(canvas, center, r, t, o, dark, front);
      case quicksilver:
        _Quicksilver.paint(canvas, center, r, t, o, dark, front);
      case goldLeaf:
        _GoldLeaf.paint(canvas, center, r, t, o, dark, front);
      case cinnabar:
        _Cinnabar.paint(canvas, center, r, t, o, dark, front);
      case copperSpotlight ||
          silverSpotlight ||
          goldSpotlight ||
          rubySpotlight ||
          sapphireSpotlight ||
          emeraldSpotlight:
        _Spotlight.paint(
          canvas,
          center,
          r,
          t,
          o,
          dark,
          front,
          trialsKeys.indexOf(key),
        );
    }
  }
}

// ── the kit ─────────────────────────────────────────────────────────────────

/// One batch for every effect: they paint one at a time.
final GrainBatch _batch = GrainBatch(12);

double _h(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

double _frac(double x) => x - x.floorToDouble();

double _smooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Per-grain seeds, laid out once: `_seeds[k][i]` in 0..1.
final List<Float64List> _seeds = [
  for (var k = 0; k < 8; k++)
    Float64List.fromList([for (var i = 0; i < 40; i++) _h(i, k + 11)]),
];

double _q(int k, int i) => _seeds[k][i];

final Paint _poolPaint = Paint();
final Map<int, Shader> _poolShaders = {};

/// Light lying on the ground: an ellipse [rx] by [ry] round ([x], [y]),
/// soft from the middle out, with no edge. One gradient at unit radius per
/// color, stretched by the canvas, so no size ever makes a new shader.
void _pool(
  Canvas c,
  double x,
  double y,
  double rx,
  double ry,
  Color col,
  double alpha,
) {
  if (alpha <= 0.004 || rx <= 0 || ry <= 0) return;
  final key = col.toARGB32() | 0xFF000000;
  final shader = _poolShaders[key] ??= ui.Gradient.radial(
    Offset.zero,
    1,
    [
      col.withValues(alpha: 1),
      col.withValues(alpha: 0.45),
      col.withValues(alpha: 0.12),
      col.withValues(alpha: 0),
    ],
    const [0.0, 0.38, 0.72, 1.0],
  );
  c.save();
  c.translate(x, y);
  c.scale(rx, ry);
  _poolPaint
    ..shader = shader
    ..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
  c.drawCircle(Offset.zero, 1, _poolPaint);
  c.restore();
}

final Paint _shapePaint = Paint();

/// [path], drawn at ([x], [y]) turned by [a] and scaled [sx] by [sy].
void _shape(
  Canvas c,
  Path path,
  double x,
  double y,
  double a,
  double sx,
  double sy,
  Color col,
) {
  if (col.a <= 0.004) return;
  c.save();
  c.translate(x, y);
  c.rotate(a);
  c.scale(sx, sy);
  c.drawPath(path, _shapePaint..color = col);
  c.restore();
}

Color _fade(Color c, double k) =>
    c.withValues(alpha: (c.a * k).clamp(0.0, 1.0));

/// A color as 0xRRGGBB, for the atlas.
int _rgb(Color c) => c.toARGB32() & 0xFFFFFF;

/// Between two 0xRRGGBB colors.
int _mix(int a, int b, double t) {
  final k = t.clamp(0.0, 1.0);
  int ch(int s) {
    final x = (a >> s) & 0xFF, y = (b >> s) & 0xFF;
    return (x + (y - x) * k).round() & 0xFF;
  }

  return (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

final Paint _ripplePaint = Paint();
final Map<int, Shader> _rippleShaders = {};

/// A soft band of light at the edge of an ellipse [rx] by [ry] round
/// ([x], [y]) — a ripple across a pool, not an outline. Unit-sized and
/// stretched, like [_pool].
void _ripple(
  Canvas c,
  double x,
  double y,
  double rx,
  double ry,
  Color col,
  double alpha,
) {
  if (alpha <= 0.004 || rx <= 0 || ry <= 0) return;
  final key = col.toARGB32() | 0xFF000000;
  final shader = _rippleShaders[key] ??= ui.Gradient.radial(
    Offset.zero,
    1,
    [
      col.withValues(alpha: 0),
      col.withValues(alpha: 0),
      col.withValues(alpha: 1),
      col.withValues(alpha: 0),
    ],
    const [0.0, 0.62, 0.86, 1.0],
  );
  c.save();
  c.translate(x, y);
  c.scale(rx, ry);
  _ripplePaint
    ..shader = shader
    ..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
  c.drawCircle(Offset.zero, 1, _ripplePaint);
  c.restore();
}

/// A color from a hue in turns (0..1 round the wheel), as 0xRRGGBB.
int _hsv(double hue, double s, double v) {
  final h = (hue - hue.floorToDouble()) * 6;
  final i = h.floor();
  final f = h - i;
  final p = v * (1 - s), q = v * (1 - s * f), u = v * (1 - s * (1 - f));
  final (r, g, b) = switch (i) {
    0 => (v, u, p),
    1 => (q, v, p),
    2 => (p, v, u),
    3 => (p, q, v),
    4 => (u, p, v),
    _ => (v, p, q),
  };
  return ((r * 255).round() << 16) |
      ((g * 255).round() << 8) |
      (b * 255).round();
}

/// Soft sprites in one drawRawAtlas call, each its own color, size and
/// turn: glowing grains, petals of light, beads of liquid metal (drawn laid
/// over, in white, so they keep their own shading), and puffs of smoke (soft
/// all through, no bright heart, so many overlapping read as one body). Buffers are
/// preallocated; the atlas image is drawn once, on first use.
abstract final class _Atlas {
  static const double _cell = 64;
  static const int dot = 0, petal = 1, bead = 2, puff = 3;
  static const int _cap = 768;

  static final Float32List _xf = Float32List(_cap * 4);
  static final Float32List _rects = Float32List(_cap * 4);
  static final Int32List _colors = Int32List(_cap);
  static int _n = 0;
  static ui.Image? _image;
  static final Paint _paint = Paint()..filterQuality = FilterQuality.low;

  static void clear() => _n = 0;

  /// A sprite centred on ([x], [y]), [size] across, in [rgb] at [alpha]:
  /// a grain, or another [cell] turned by [rot].
  static void add(
    double x,
    double y,
    double size,
    int rgb,
    double alpha, {
    int cell = dot,
    double rot = 0,
  }) {
    if (_n >= _cap || alpha <= 0.01 || size < 0.6) return;
    final scale = size / _cell;
    final sc = math.cos(rot) * scale, ss = math.sin(rot) * scale;
    const half = _cell / 2;
    final i = _n * 4;
    _xf[i] = sc;
    _xf[i + 1] = ss;
    _xf[i + 2] = x - sc * half + ss * half;
    _xf[i + 3] = y - ss * half - sc * half;
    final l = cell * _cell;
    _rects[i] = l;
    _rects[i + 1] = 0;
    _rects[i + 2] = l + _cell;
    _rects[i + 3] = _cell;
    _colors[_n] = ((alpha.clamp(0.0, 1.0) * 255).round() << 24) | rgb;
    _n++;
  }

  /// Draws what was added: light adding up on the dark plate, laid over the
  /// light one, where adding light to parchment shows nothing.
  static void draw(Canvas c, {required bool additive}) {
    if (_n == 0) return;
    _paint.blendMode = additive ? BlendMode.plus : BlendMode.srcOver;
    c.drawRawAtlas(
      _image ??= _build(),
      Float32List.sublistView(_xf, 0, _n * 4),
      Float32List.sublistView(_rects, 0, _n * 4),
      Int32List.sublistView(_colors, 0, _n),
      BlendMode.modulate,
      null,
      _paint,
    );
  }

  static ui.Image _build() {
    const c = _cell;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    const white = Color(0xFFFFFFFF);
    // A grain: a bright heart in a soft light, no edge.
    canvas.drawCircle(
      const Offset(c / 2, c / 2),
      c / 2,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(c / 2, c / 2),
          c / 2,
          [
            white,
            white.withValues(alpha: 0.85),
            white.withValues(alpha: 0.3),
            white.withValues(alpha: 0.08),
            white.withValues(alpha: 0),
          ],
          const [0.0, 0.13, 0.3, 0.6, 1.0],
        ),
    );
    // A petal of light: a soft glow round a filled leaf, lit at its heart.
    canvas.save();
    canvas.translate(c * 1.5, c / 2);
    canvas.drawCircle(
      Offset.zero,
      c * 0.42,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, c * 0.42, [
          white.withValues(alpha: 0.28),
          white.withValues(alpha: 0),
        ]),
    );
    canvas.drawPath(
      vfxLeaf(const Offset(-c * 0.34, 0), c * 0.68, 0),
      Paint()
        ..shader = ui.Gradient.radial(const Offset(-c * 0.04, 0), c * 0.36, [
          white,
          white.withValues(alpha: 0.55),
        ]),
    );
    canvas.restore();
    // A bead of quicksilver: the sky on its lit cap, its dark body, the
    // pool's light along its underside, and the faint light it lays on the
    // ground under it. Its own colors, so it is added in white.
    canvas.save();
    canvas.translate(c * 2.5, c * 0.44);
    canvas.save();
    canvas.translate(0, c * 0.36);
    canvas.scale(1, 0.22);
    canvas.drawCircle(
      Offset.zero,
      c * 0.48,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          c * 0.48,
          const [Color(0x66C8D6E8), Color(0x22C8D6E8), Color(0x00C8D6E8)],
          const [0.0, 0.5, 1.0],
        ),
    );
    canvas.restore();
    const br = c * 0.34;
    canvas.drawCircle(
      Offset.zero,
      br,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.radial(
          const Offset(-br * 0.32, -br * 0.38),
          br * 1.45,
          const [
            Color(0xFFFFFFFF),
            Color(0xFFC8D0DC),
            Color(0xFF586070),
            Color(0xFF1E2229),
            Color(0xFF9AA6B6),
          ],
          const [0.0, 0.12, 0.42, 0.74, 1.0],
        ),
    );
    canvas.restore();
    canvas.drawCircle(
      const Offset(c * 3.5, c / 2),
      c / 2,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(c * 3.5, c / 2),
          c / 2,
          [
            white.withValues(alpha: 0.9),
            white.withValues(alpha: 0.72),
            white.withValues(alpha: 0.36),
            white.withValues(alpha: 0.1),
            white.withValues(alpha: 0),
          ],
          const [0.0, 0.3, 0.6, 0.82, 1.0],
        ),
    );
    final picture = rec.endRecording();
    final image = picture.toImageSync((c * 4).toInt(), c.toInt());
    picture.dispose();
    return image;
  }
}

/// Triangles with a color at every corner, gathered over a frame and drawn
/// with one drawVertices: many small filled shapes (leaves, ribbons, a
/// mesh) for the cost of one. Each user keeps its own, sized once.
class _Tris {
  _Tris(int cap) : _xy = Float32List(cap * 6), _col = Int32List(cap * 3);
  final Float32List _xy;
  final Int32List _col;
  int _n = 0;

  static final Paint _paint = Paint()..isAntiAlias = true;

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
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
    double dx,
    double dy,
    int ca,
    int cb,
    int cc,
    int cd,
  ) {
    add(ax, ay, bx, by, cx, cy, ca, cb, cc);
    add(ax, ay, cx, cy, dx, dy, ca, cc, cd);
  }

  /// Draws what was added, and empties it.
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

/// An ARGB int from 0xRRGGBB and an alpha.
int _argb(int rgb, double alpha) =>
    ((alpha.clamp(0.0, 1.0) * 255).round() << 24) | (rgb & 0xFFFFFF);

/// The air or water an effect's grains move in: the curl of a few octaves
/// of slow travelling waves, so it is divergence-free (grains crowd and thin
/// along curling filaments, never bunching to a point) and smooth in space
/// and time. Laid on a small lattice once per clock time ([prepare]) and
/// sampled bilinearly ([sample]), in an effect's unit space: the creature's
/// half box is 1, its middle the origin, up is −y. After `InkFlow`
/// (fusion_style_kit.dart), sized for an aura and kept here so the effects
/// stand on their own.
///
/// A grain is never stepped from frame to frame: [trace] walks it from
/// where it was born, for its age, along the flow as it is now. So its
/// place is a smooth function of the clock, the same for every host, and a
/// test can scrub it.
class _Flow {
  _Flow(
    this.waves, {
    this.scale = 0.5,
    this.x0 = -2.2,
    this.x1 = 2.2,
    this.y0 = -2.6,
    this.y1 = 1.4,
    this.n = 18,
  }) : _vx = Float64List((n + 1) * (n + 1)),
       _vy = Float64List((n + 1) * (n + 1)),
       _ca = Float64List((n + 1) * waves.length),
       _sa = Float64List((n + 1) * waves.length),
       _cb = Float64List((n + 1) * waves.length),
       _sb = Float64List((n + 1) * waves.length);

  /// Per wave: kx, ky (per [scale]), angular speed, phase, amplitude.
  final List<(double, double, double, double, double)> waves;

  /// The flow's largest curl, in unit space.
  final double scale;
  final double x0, x1, y0, y1;
  final int n;

  final Float64List _vx, _vy, _ca, _sa, _cb, _sb;
  double _at = double.nan;

  /// The velocity [sample] found, about 1 at the flow's strongest.
  double vx = 0, vy = 0;

  /// Lays the flow at [t] seconds; once per [t].
  void prepare(double t) {
    if (t == _at) return;
    _at = t;
    final w = waves.length;
    for (var c = 0; c <= n; c++) {
      final x = (x0 + (x1 - x0) * c / n) / scale;
      for (var k = 0; k < w; k++) {
        final a = waves[k].$1 * x;
        _ca[c * w + k] = math.cos(a);
        _sa[c * w + k] = math.sin(a);
      }
    }
    for (var r = 0; r <= n; r++) {
      final y = (y0 + (y1 - y0) * r / n) / scale;
      for (var k = 0; k < w; k++) {
        final (_, ky, om, ph, _) = waves[k];
        final b = ky * y + om * t + ph;
        _cb[r * w + k] = math.cos(b);
        _sb[r * w + k] = math.sin(b);
      }
    }
    for (var r = 0; r <= n; r++) {
      for (var c = 0; c <= n; c++) {
        var vx = 0.0, vy = 0.0;
        for (var k = 0; k < w; k++) {
          final (kx, ky, _, _, amp) = waves[k];
          final cosArg =
              _ca[c * w + k] * _cb[r * w + k] - _sa[c * w + k] * _sb[r * w + k];
          // The curl of amp·sin(arg): (∂ψ/∂y, −∂ψ/∂x).
          vx += amp * ky * cosArg;
          vy -= amp * kx * cosArg;
        }
        _vx[r * (n + 1) + c] = vx;
        _vy[r * (n + 1) + c] = vy;
      }
    }
  }

  /// The velocity at ([x], [y]) into [vx], [vy]; still outside the lattice,
  /// stilling toward its edge so nothing jumps crossing it.
  void sample(double x, double y) {
    final fx = (x - x0) / (x1 - x0) * n, fy = (y - y0) / (y1 - y0) * n;
    if (fx < 0 || fy < 0 || fx >= n || fy >= n) {
      vx = 0;
      vy = 0;
      return;
    }
    final c = fx.floor(), r = fy.floor();
    final u = fx - c, v = fy - r;
    final i = r * (n + 1) + c, j = i + n + 1;
    final a = (1 - u) * (1 - v), b = u * (1 - v), cc = (1 - u) * v, d = u * v;
    final mx = math.min(fx, n - fx), my = math.min(fy, n - fy);
    final edge = n * 0.12;
    final fade =
        (mx >= edge ? 1.0 : _smooth(0, edge, mx)) *
        (my >= edge ? 1.0 : _smooth(0, edge, my));
    vx = (_vx[i] * a + _vx[i + 1] * b + _vx[j] * cc + _vx[j + 1] * d) * fade;
    vy = (_vy[i] * a + _vy[i + 1] * b + _vy[j] * cc + _vy[j + 1] * d) * fade;
  }

  /// The path [_px], [_py] (point 0 the birth, point [steps] now) of a grain
  /// born at ([x], [y]) [age] seconds ago, carried by the flow at [speed]
  /// plus a steady [lift] up (buoyancy: a uniform drift, so still
  /// divergence-free) and [drift] across. The flow is slow beside its
  /// steps, so plain steps follow it closely.
  static final Float64List _px = Float64List(24), _py = Float64List(24);

  ///
  /// With [calm] > 0 the flow takes hold only as the grain rises: still air
  /// carries it straight up at first (smoke's laminar thread), and the
  /// currents have it fully once it has risen [calm].
  void trace(
    double x,
    double y,
    double age,
    int steps, {
    double speed = 0.3,
    double lift = 0,
    double drift = 0,
    double calm = 0,
  }) {
    final dt = age / steps;
    var px = x, py = y;
    _px[0] = px;
    _py[0] = py;
    for (var k = 1; k <= steps; k++) {
      sample(px, py);
      final hold = calm <= 0 ? 1.0 : _smooth(0, calm, y - py);
      px += (vx * speed * hold + drift * hold) * dt;
      py += (vy * speed * hold - lift) * dt;
      _px[k] = px;
      _py[k] = py;
    }
  }
}

/// A wisp of smoke or ink: the path it takes from its source, traced along
/// a [_Flow] as the flow is now (a streamline, which is where a steady
/// source's smoke lies while the flow changes slowly), so the wisp leans
/// and sways as the flow does. Its material rides along it by age, so it
/// is continuous: [at] reads the point a fraction of the way up, with its
/// direction's normal.
class _Spine {
  final Float64List _x = Float64List(25), _y = Float64List(25);
  int _n = 0;

  /// The point [at] found, and the unit normal to the left of the way up.
  double x = 0, y = 0, nx = 0, ny = 0;

  /// The path from ([x0], [y0]) for [age] seconds in [steps] steps.
  void trace(
    _Flow flow,
    double x0,
    double y0,
    double age,
    int steps, {
    double speed = 0.2,
    double lift = 0.3,
    double drift = 0,
    double calm = 0,
  }) {
    flow.trace(
      x0,
      y0,
      age,
      steps,
      speed: speed,
      lift: lift,
      drift: drift,
      calm: calm,
    );
    _n = steps;
    for (var k = 0; k <= steps; k++) {
      _x[k] = _Flow._px[k];
      _y[k] = _Flow._py[k];
    }
  }

  /// Rolls the path over from fraction [from] on, by up to [angle] radians
  /// at its end, about the point at [from]: a head curling over.
  void roll(double from, double angle) {
    final k0 = (from * _n).floor().clamp(0, _n);
    final ox = _x[k0], oy = _y[k0];
    for (var k = k0 + 1; k <= _n; k++) {
      final f = (k - k0) / (_n - k0);
      final a = angle * math.pow(f, 1.5);
      final dx = _x[k] - ox, dy = _y[k] - oy;
      final ca = math.cos(a), sa = math.sin(a);
      _x[k] = ox + dx * ca - dy * sa;
      _y[k] = oy + dx * sa + dy * ca;
    }
  }

  /// The point a fraction [s] of the way along, into [x], [y], [nx], [ny].
  void at(double s) {
    final f = s.clamp(0.0, 1.0) * _n;
    final k = math.min(f.floor(), _n - 1);
    final u = f - k;
    x = _x[k] + (_x[k + 1] - _x[k]) * u;
    y = _y[k] + (_y[k + 1] - _y[k]) * u;
    var tx = _x[k + 1] - _x[k], ty = _y[k + 1] - _y[k];
    final l = math.sqrt(tx * tx + ty * ty);
    if (l < 1e-9) {
      tx = 0;
      ty = -1;
    } else {
      tx /= l;
      ty /= l;
    }
    nx = ty;
    ny = -tx;
  }

  /// How long it is, in unit space.
  double get length {
    var sum = 0.0;
    for (var k = 0; k < _n; k++) {
      final dx = _x[k + 1] - _x[k], dy = _y[k + 1] - _y[k];
      sum += math.sqrt(dx * dx + dy * dy);
    }
    return sum;
  }
}
