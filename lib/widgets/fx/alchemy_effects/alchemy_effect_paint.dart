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
part 'dust_ring.dart';
part 'elemental_aura.dart';
part 'intelligence_halo.dart';
part 'prismatic_cascade.dart';
part 'ritual_gold.dart';
part 'speed_flux.dart';
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

  /// Every effect the shop sells. These strings are what owned effects are
  /// saved as: never change one.
  static const Set<String> keys = {
    FamilyCostume.hatPreview,
    FamilyCostume.nosePreview,
    FamilyCostume.sunglassesPreview,
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
      key == dustRing;

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
/// colour, stretched by the canvas, so no size ever makes a new shader.
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

/// A colour as 0xRRGGBB, for the atlas.
int _rgb(Color c) => c.toARGB32() & 0xFFFFFF;

/// Between two 0xRRGGBB colours.
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

/// A colour from a hue in turns (0..1 round the wheel), as 0xRRGGBB.
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

/// Soft sprites in one drawRawAtlas call, each its own colour, size and
/// turn: glowing grains, and petals of light. Buffers are preallocated; the
/// atlas image is drawn once, on first use.
abstract final class _Atlas {
  static const double _cell = 64;
  static const int dot = 0, petal = 1;
  static const int _cap = 360;

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
    final picture = rec.endRecording();
    final image = picture.toImageSync((c * 2).toInt(), c.toInt());
    picture.dispose();
    return image;
  }
}
