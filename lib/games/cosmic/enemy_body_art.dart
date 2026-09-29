// lib/games/cosmic/enemy_body_art.dart
//
// What an enemy is made of: dark glass shells with elemental light trapped
// inside them. The light is what you see first — it leaks through the seams
// between plates, burns in an eye, pools round the body — and the shell is
// the element's own material, dark and muted, so the light stays the one
// luminous accent (see vfx_shapes.dart's VfxMaterial).
//
// The language is the planets' (lib/games/cosmic/planets/): crisp shaded
// facets with glowing seams, soft gradient light instead of blur or flat
// translucent discs, and many small lights on real motion — the particle
// ring players liked on the Dust planet is the sentinel's ring and the
// boss's. Nothing strokes an outline, a hairline or a hoop.
//
// Every body is built on the unit disc and drawn under canvas.scale(r), so
// the geometry is built once and every gradient is a cached unit shader:
// a body costs its draw calls and nothing else. Animation only moves the
// canvas.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/enemy_mesh.dart';
import 'package:alchemons/games/cosmic/vfx_shapes.dart';
import 'package:flutter/painting.dart';

part 'boss_forms.dart';

// ── palette ─────────────────────────────────────────────────────────────────

/// One element's enemy colours and the unit shaders built from them.
class EnemyPalette {
  EnemyPalette._(this.ink, this.face, this.rim, this.essence, this.hot);

  factory EnemyPalette._of(String element, Color base) {
    final hsl = HSLColor.fromColor(base);
    final essence = hsl
        .withSaturation(hsl.saturation.clamp(0.45, 0.92))
        .withLightness(hsl.lightness.clamp(0.58, 0.70))
        .toColor();
    final m = vfxMaterial(element);
    return EnemyPalette._(
      Color.lerp(m.ink, essence, 0.06)!,
      Color.lerp(Color.lerp(m.ink, m.mid, 0.62)!, essence, 0.10)!,
      Color.lerp(m.mid, essence, 0.55)!,
      essence,
      Color.lerp(essence, const Color(0xFFFFFFFF), 0.62)!,
    );
  }

  /// The shell: dark body, lit face, the edge that catches the inner light.
  final Color ink, face, rim;

  /// The trapped light, and its white-hot centre.
  final Color essence, hot;

  Color _a(Color c, double a) => c.withValues(alpha: a);

  /// Light pooled round the body, unit radius.
  late final ui.Shader glow = ui.Gradient.radial(
    Offset.zero,
    1,
    [_a(essence, 0.22), _a(essence, 0.085), _a(essence, 0)],
    const [0.0, 0.4, 1.0],
  );

  /// A point of light: eyes, cores, sparks. Unit radius.
  late final ui.Shader spark = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      const Color(0xFFFFFFFF),
      hot,
      _a(essence, 0.75),
      _a(essence, 0),
    ],
    const [0.0, 0.2, 0.45, 1.0],
  );

  /// The light inside a shell, seen through its seams. Unit radius.
  late final ui.Shader inner = ui.Gradient.radial(
    Offset.zero,
    1,
    [hot, essence, Color.lerp(essence, ink, 0.5)!],
    const [0.0, 0.38, 1.0],
  );

  late final ui.Shader wispCore = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      const Color(0xFFFFFFFF),
      _a(hot, 0.95),
      _a(essence, 0.62),
      _a(essence, 0.2),
      _a(essence, 0),
    ],
    const [0.0, 0.1, 0.26, 0.56, 1.0],
  );

  late final ui.Shader wispTail = ui.Gradient.linear(
    const Offset(0.3, 0),
    const Offset(-2.7, 0),
    [
      _a(Color.lerp(essence, hot, 0.35)!, 0.62),
      _a(essence, 0.24),
      _a(essence, 0),
    ],
    const [0.0, 0.42, 1.0],
  );

  /// Ridge-lit hull: brightest along the spine, dark at both flanks, so it
  /// reads the same whichever way the body is turned.
  late final ui.Shader ridge = ui.Gradient.linear(
    const Offset(0, -0.8),
    const Offset(0, 0.8),
    [ink, face, Color.lerp(face, rim, 0.35)!, face, ink],
    const [0.08, 0.40, 0.5, 0.60, 0.92],
  );

  /// A thin crack of light along the x axis.
  late final ui.Shader seam = ui.Gradient.linear(
    const Offset(0, -0.1),
    const Offset(0, 0.1),
    [_a(essence, 0), hot, _a(essence, 0)],
    const [0.0, 0.5, 1.0],
  );

  late final ui.Shader exhaust = ui.Gradient.linear(
    const Offset(-0.5, 0),
    const Offset(-2.3, 0),
    [_a(essence, 0.55), _a(essence, 0)],
  );

  /// Dark glass: light deep inside, black body, a rim where the edge
  /// catches it.
  late final ui.Shader orb = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      Color.lerp(ink, essence, 0.42)!,
      ink,
      Color.lerp(ink, rim, 0.14)!,
      Color.lerp(ink, rim, 0.46)!,
      _a(Color.lerp(ink, rim, 0.5)!, 0.0),
    ],
    const [0.0, 0.5, 0.74, 0.9, 1.0],
  );

  late final ui.Shader iris = ui.Gradient.radial(
    Offset.zero,
    1,
    [hot, essence, Color.lerp(essence, ink, 0.35)!, _a(essence, 0)],
    const [0.0, 0.42, 0.82, 1.0],
  );

  /// The glow round an eclipse: nothing inside the limb, a band of light at
  /// it, fading out.
  late final ui.Shader corona = ui.Gradient.radial(
    Offset.zero,
    1.5,
    [
      _a(essence, 0),
      _a(essence, 0),
      _a(essence, 0.3),
      _a(essence, 0.1),
      _a(essence, 0),
    ],
    const [0.0, 0.5, 0.62, 0.8, 1.0],
  );

  late final ui.Shader hollow = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      const Color(0xFF000000),
      Color.lerp(const Color(0xFF000000), ink, 0.8)!,
      Color.lerp(ink, essence, 0.28)!,
    ],
    const [0.0, 0.84, 1.0],
  );

  /// The soft lanes of a particle ring, in the ring's own plane.
  late final ui.Shader lane = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      _a(essence, 0),
      _a(essence, 0),
      _a(essence, 0.08),
      _a(essence, 0.14),
      _a(essence, 0.05),
      _a(essence, 0),
    ],
    const [0.0, 0.55, 0.66, 0.78, 0.9, 1.0],
  );

  /// The hot inner rim of an accretion disk round a hole of radius 1/3.3,
  /// in the disk's plane. Unit radius.
  late final ui.Shader accretion = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      _a(hot, 0),
      _a(hot, 0),
      _a(hot, 0.4),
      _a(essence, 0.2),
      _a(essence, 0.06),
      _a(essence, 0),
    ],
    const [0.0, 0.29, 0.35, 0.5, 0.75, 1.0],
  );

  late final Color grainDim = Color.lerp(rim, essence, 0.45)!.withValues(
    alpha: 0.75,
  );
  late final Color grainLit = hot;
}

final Map<String, EnemyPalette> _palettes = {};
final Map<int, EnemyPalette> _tintedPalettes = {};

/// The palette for [element], or for [tint] in [element]'s material when a
/// body is drawn in a colour of its own.
EnemyPalette enemyPalette(String element, [Color? tint]) {
  if (tint == null) {
    return _palettes[element] ??= EnemyPalette._of(
      element,
      elementColor(element),
    );
  }
  final key = element.hashCode * 1000003 ^ tint.toARGB32();
  return _tintedPalettes[key] ??= EnemyPalette._of(element, tint);
}

// ── shared drawing state ────────────────────────────────────────────────────

final Paint _fill = Paint();
final Paint _dots = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

/// Unit-space point buffers, reused every frame.
const int _kGrainBuckets = 12;
final List<Float32List> _grain = List.generate(
  _kGrainBuckets,
  (_) => Float32List(256),
);
final List<int> _grainN = List.filled(_kGrainBuckets, 0);

void _grainReset() => _grainN.fillRange(0, _kGrainBuckets, 0);

void _grainAdd(int b, double x, double y) {
  var buf = _grain[b];
  final i = _grainN[b] * 2;
  if (i + 2 > buf.length) {
    _grain[b] = buf = Float32List(buf.length * 2)..setAll(0, buf);
  }
  buf[i] = x;
  buf[i + 1] = y;
  _grainN[b]++;
}

void _grainDraw(Canvas c, int b, double diameter, Color color) {
  final n = _grainN[b];
  if (n == 0 || color.a <= 0) return;
  _dots
    ..strokeWidth = diameter
    ..color = color;
  c.drawRawPoints(
    ui.PointMode.points,
    Float32List.sublistView(_grain[b], 0, n * 2),
    _dots,
  );
}

const Color _opaque = Color(0xFFFFFFFF);

void _shade(Canvas c, ui.Shader s, [double alpha = 1]) {
  _fill
    ..shader = s
    ..color = alpha >= 1
        ? _opaque
        : Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0));
}

void _circle(Canvas c, ui.Shader s, double radius, [double alpha = 1]) {
  if (alpha <= 0.004) return;
  _shade(c, s, alpha);
  c.drawCircle(Offset.zero, radius, _fill);
}

void _path(Canvas c, Path p, ui.Shader s, [double alpha = 1]) {
  if (alpha <= 0.004) return;
  _shade(c, s, alpha);
  c.drawPath(p, _fill);
}

void _solid(Canvas c, Path p, Color col) {
  _fill
    ..shader = null
    ..color = col;
  c.drawPath(p, _fill);
}

/// A point of light at [at], [radius] across, in unit space.
void _sparkAt(
  Canvas c,
  EnemyPalette pal,
  Offset at,
  double radius, [
  double alpha = 1,
]) {
  if (radius <= 0) return;
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(radius);
  _circle(c, pal.spark, 1, alpha);
  c.restore();
}

final ui.Shader _flash = ui.Gradient.radial(
  Offset.zero,
  1,
  const [Color(0xFFFFFFFF), Color(0xCCFFFFFF), Color(0x00FFFFFF)],
  const [0.0, 0.65, 1.0],
);

/// Being hit: the body blanches from the inside out.
void _hitFlash(Canvas c, double flash, double radius) {
  if (flash <= 0.02) return;
  _circle(c, _flash, radius, 0.75 * flash.clamp(0.0, 1.0));
}

double _frac(double x) => x - x.floorToDouble();

// ── wisp ────────────────────────────────────────────────────────────────────
//
// Loose essence with no shell at all: a hot spark with a comet tail laid out
// behind it. A horde of them streams in as light.

final Path _wispTail = Path()
  ..moveTo(0.3, 0)
  ..cubicTo(0.3, -0.52, -0.2, -0.6, -0.8, -0.34)
  ..quadraticBezierTo(-1.8, -0.07, -2.7, 0)
  ..quadraticBezierTo(-1.8, 0.07, -0.8, 0.34)
  ..cubicTo(-0.2, 0.6, 0.3, 0.52, 0.3, 0)
  ..close();

void paintWispBody(
  Canvas c,
  EnemyPalette pal, {
  required double time,
  required double seed,
  required double heading,
  double flash = 0,
}) {
  final flick =
      0.86 + 0.14 * sin(time * 9.0 + seed * 7) * sin(time * 5.3 + seed * 3);
  _circle(c, pal.glow, 2.1);
  c.save();
  c.rotate(heading + 0.08 * sin(time * 3.7 + seed * 5));
  c.scale(0.9 + 0.12 * flick, 0.88 + 0.12 * flick);
  _path(c, _wispTail, pal.wispTail);
  c.restore();
  _circle(c, pal.wispCore, 1.0 * flick);
  _hitFlash(c, flash, 0.9);
}

// ── drone ───────────────────────────────────────────────────────────────────
//
// One shard of the shell, split down its spine by a crack of light, with a
// burning eye at the nose and the essence it runs on streaming out behind.

final Path _droneHull = Path()
  ..moveTo(1.25, 0)
  ..lineTo(0.18, -0.74)
  ..lineTo(-0.58, -0.6)
  ..lineTo(-0.96, -0.24)
  ..lineTo(-0.64, 0)
  ..lineTo(-0.96, 0.24)
  ..lineTo(-0.58, 0.6)
  ..lineTo(0.18, 0.74)
  ..close();

/// The lit flank: a facet from nose to shoulder, so the shard has planes
/// rather than a single gradient.
final Path _droneFacet = Path()
  ..moveTo(1.25, 0)
  ..lineTo(0.18, -0.74)
  ..lineTo(-0.2, -0.28)
  ..lineTo(0.3, 0)
  ..close();

final Path _droneSeam = vfxLens(1.3, 0.22, 0.5, 0.55).shift(
  const Offset(-0.5, 0),
);

final Path _droneExhaust = Path()
  ..moveTo(-0.55, -0.2)
  ..quadraticBezierTo(-1.3, -0.12, -2.3, 0)
  ..quadraticBezierTo(-1.3, 0.12, -0.55, 0.2)
  ..close();

void paintDroneBody(
  Canvas c,
  EnemyPalette pal, {
  required double time,
  required double seed,
  required double heading,
  double charge = 0,
  double dash = 0,
  double flash = 0,
}) {
  final twitch = sin(time * (12 + 20 * charge) + seed * 7);
  final pulse = 0.6 + 0.4 * sin(time * 8 + seed * 3);
  _circle(c, pal.glow, 2.0 + 0.4 * dash);
  c.save();
  c.rotate(heading + twitch * (0.05 + 0.06 * charge));
  // Coiled on the wind-up, stretched on the dash.
  c.scale(1 - 0.12 * charge + 0.1 * dash, 1 + 0.06 * charge);
  c.save();
  c.scale(0.8 + 0.25 * pulse + 1.4 * dash, 1 + 0.3 * dash);
  _path(c, _droneExhaust, pal.exhaust, 0.8 + 0.2 * max(charge, dash));
  c.restore();
  _path(c, _droneHull, pal.ridge);
  _solid(c, _droneFacet, const Color(0x14FFFFFF));
  _path(c, _droneSeam, pal.seam, 0.35 + 0.35 * pulse + 0.3 * charge);
  _sparkAt(c, pal, const Offset(0.76, 0), 0.42 + 0.1 * pulse + 0.2 * charge);
  c.restore();
  _hitFlash(c, flash, 1.1);
}

// ── sentinel ────────────────────────────────────────────────────────────────
//
// The watcher: a sphere of dark glass with its light drawn toward what it
// means to shoot, inside a ring of glittering grains on real orbits — the
// Dust planet's ring, small.

const double _kSentinelFlat = 0.34;

/// A ring grain: (radius, starting angle, twinkle phase, orbital rate).
/// The rate is Kepler's 1/r^1.5, worked out once rather than per frame.
typedef _Grain = (double, double, double, double);

_Grain _orbiting(double rad, double a0, double ph) =>
    (rad, a0, ph, 1 / (rad * sqrt(rad)));

final List<_Grain> _sentinelGrains = () {
  final rng = Random(41);
  final out = <_Grain>[];
  for (var i = 0; i < 40; i++) {
    out.add(
      _orbiting(
        1.52 + (rng.nextDouble() + rng.nextDouble()) * 0.2,
        rng.nextDouble() * 2 * pi,
        rng.nextDouble() * 2 * pi,
      ),
    );
  }
  // Clumps, so the ring visibly turns.
  for (var k = 0; k < 2; k++) {
    final a = rng.nextDouble() * 2 * pi;
    for (var i = 0; i < 7; i++) {
      out.add(
        _orbiting(
          1.7 + (rng.nextDouble() - 0.5) * 0.12,
          a + (rng.nextDouble() - 0.5) * 0.45,
          rng.nextDouble() * 2 * pi,
        ),
      );
    }
  }
  return out;
}();

/// Gathers a ring's grains into buckets: 0 far-dim, 1 far-lit, 2 near-dim,
/// 3 near-lit.
void _gatherRing(
  List<_Grain> grains,
  double time,
  double seed,
  double flat,
  double speed,
) {
  _grainReset();
  for (final (rad, a0, ph, rate) in grains) {
    final a = a0 + seed + time * speed * rate;
    final s = sin(a);
    final lit = sin(time * 2.6 + ph) > 0.45;
    _grainAdd((s > 0 ? 2 : 0) + (lit ? 1 : 0), cos(a) * rad, s * rad * flat);
  }
}

void paintSentinelBody(
  Canvas c,
  EnemyPalette pal, {
  required double time,
  required double seed,
  required double heading,
  double charge = 0,
  double release = 0,
  double flash = 0,
}) {
  _circle(c, pal.glow, 2.3 + 0.3 * charge);
  final tilt = -0.5 + 0.35 * sin(seed * 3.1);
  // Winding up, the ring gathers in and quickens; firing, it is flung out.
  final spread = 1 - 0.3 * charge + 0.35 * release;
  _gatherRing(
    _sentinelGrains,
    time,
    seed + charge * 3,
    _kSentinelFlat,
    1.6,
  );
  c.save();
  c.rotate(tilt);
  c.scale(spread);
  c.save();
  c.scale(1, _kSentinelFlat);
  _circle(c, pal.lane, 2.15, 1 + charge);
  c.restore();
  _grainDraw(c, 0, 0.085, pal.grainDim);
  _grainDraw(c, 1, 0.13, pal.grainLit);
  c.restore();

  _circle(c, pal.orb, 1);
  // The light inside leans toward where the sentinel is facing, and
  // breathes.
  final breathe = 1 + 0.08 * sin(time * 2.1 + seed) + 0.25 * charge;
  final look = Offset(cos(heading), sin(heading)) * 0.2;
  c.save();
  c.translate(look.dx, look.dy);
  c.scale(0.52 * breathe);
  _circle(c, pal.iris, 1, 0.85);
  c.restore();
  _sparkAt(c, pal, look * 1.25, 0.22 * breathe);

  c.save();
  c.rotate(tilt);
  c.scale(spread);
  _grainDraw(c, 2, 0.085, pal.grainDim);
  _grainDraw(c, 3, 0.13, pal.grainLit);
  c.restore();
  _hitFlash(c, flash, 1.1);
}

// ── phantom ─────────────────────────────────────────────────────────────────
//
// A hollow: an eclipse you can see space through. One limb burns in a broad
// crescent that walks round it; a faint second crescent answers it from the
// far side; loose light spirals in and goes out.

final Path _crescentWide = vfxCrescent(Offset.zero, 1.02, 0.34, 0, 2.1);
final Path _crescentThin = vfxCrescent(Offset.zero, 0.97, 0.12, 0, 1.0);

void paintPhantomBody(
  Canvas c,
  EnemyPalette pal, {
  required double time,
  required double seed,
  required double heading,
  double fade = 0,
  double exposed = 0,
  double flash = 0,
}) {
  // [fade]: blinking out, the limb dims and races. [exposed]: back and
  // solid, the whole limb lit — the window to hit it.
  final phase = time * (1.5 + 5 * fade) + seed * 2;
  final breathe = 1.0 + 0.06 * sin(phase) + 0.1 * fade;
  final there = 1 - 0.75 * fade;
  _circle(c, pal.glow, 2.2, there);
  c.save();
  c.scale(breathe);

  // Motes spiralling in, fading into the hollow.
  _grainReset();
  for (var i = 0; i < 7; i++) {
    final u = _frac(time * 0.32 + i / 7 + seed * 0.13);
    final rr = 2.1 - 1.2 * u;
    final a = seed + i * 2 * pi / 7 + u * 2.4;
    _grainAdd(u < 0.6 ? 0 : 1, cos(a) * rr, sin(a) * rr);
  }
  _grainDraw(c, 0, 0.13, pal.grainDim);
  _grainDraw(c, 1, 0.1, pal.essence.withValues(alpha: 0.5));

  // The corona leans with the burning limb.
  final limb = heading + phase * 0.4;
  c.save();
  c.rotate(limb);
  c.translate(0.12 * (1 - exposed), 0);
  _circle(c, pal.corona, 1.5, there * (1 + 0.8 * exposed));
  c.restore();

  _circle(c, pal.hollow, 0.9, 0.35 + 0.65 * there);
  c.save();
  c.rotate(limb);
  _fill
    ..shader = null
    ..color = Color.lerp(
      pal.essence,
      pal.hot,
      0.45,
    )!.withValues(alpha: (0.78 + 0.18 * sin(phase * 0.7)) * there);
  c.drawPath(_crescentWide, _fill);
  c.rotate(pi + 0.6 * sin(phase * 0.5) * (1 - exposed));
  _fill.color = Color.lerp(pal.essence, pal.hot, 0.45 * exposed)!.withValues(
    alpha: (0.22 + 0.14 * sin(phase * 0.9 + 1) + 0.6 * exposed) * there,
  );
  // Exposed, the answering limb burns as broad as the first.
  c.drawPath(exposed > 0.3 ? _crescentWide : _crescentThin, _fill);
  c.restore();
  c.restore();
  _sparkAt(c, pal, Offset.zero, 0.26, 0.45 + 0.2 * sin(phase * 1.3));
  _hitFlash(c, flash, 1.05);
}

// ── brute ───────────────────────────────────────────────────────────────────
//
// A lava bomb: a lump of obsidian, black and glossy, tumbling slowly as it
// comes, with the furnace inside glowing through its crust in veins that
// breathe. Colour here is light, never surface — the rock is black, and
// what reads is where the heat shows, the glints as faces turn, and its own
// light catching its edge. Winding up, the crust cracks open along every
// face with the light pouring out between, and it fires.

final List<FacetMesh> _bombs = [
  for (var k = 0; k < 3; k++)
    FacetMesh.rock(
      sx: 1.22,
      sy: 0.94,
      sz: 0.94,
      jitter: 0.22,
      seed: 3 + k * 7.3,
      subdivide: true,
    ),
];
final List<Float64List> _bombVeins = [
  for (var k = 0; k < 3; k++) _bombs[k].veins(hot: 4, seed: 2 + k * 4.1),
];
final Rot3 _rot = Rot3();

void paintBruteBody(
  Canvas c,
  EnemyPalette pal, {
  required double time,
  required double seed,
  required double facing,
  double charge = 0,
  double recoil = 0,
  double flash = 0,
}) {
  _circle(c, pal.glow, 2.0 + 0.4 * charge);
  final back = Offset(cos(facing), sin(facing)) * (-recoil * 0.13);
  c.save();
  c.translate(back.dx, back.dy);

  // Embers shed behind it, more of them as it heats.
  c.save();
  c.rotate(facing);
  _grainReset();
  for (var i = 0; i < 6; i++) {
    final u = _frac(time * (0.7 + 0.5 * charge) + i / 6 + seed * 0.21);
    final side = i.isEven ? 1.0 : -1.0;
    _grainAdd(
      u < 0.45 ? 0 : 1,
      -0.95 - u * (0.9 + 0.7 * charge),
      side * (0.08 + 0.34 * u) + 0.06 * sin(time * 5 + i),
    );
  }
  _grainDraw(c, 0, 0.12, pal.hot.withValues(alpha: 0.8));
  _grainDraw(c, 1, 0.08, pal.essence.withValues(alpha: 0.45));
  c.restore();

  final which = (seed * 7).floor() % _bombs.length;
  _rot.euler(
    (time * 0.45 + seed) * (1 - 0.7 * charge),
    0.25 * sin(time * 0.4 + seed),
    facing,
  );
  final open = charge > 0.02;
  meshBatch
    ..add(
      _bombs[which],
      _rot,
      pal,
      inset: open ? 0.05 + 0.1 * charge : 0,
      explode: 0.12 * charge,
      heat: 0.08 * charge,
      seamAlpha: open ? charge : 0,
      lit: 0.3,
      rimGlow: 0.8,
      dark: 0.8,
      vertexHeat: _bombVeins[which],
      heatGlow: 0.8 + 0.2 * sin(time * 1.7 + seed) + 0.4 * charge,
    )
    ..flush(c);
  c.restore();
  _hitFlash(c, flash, 1.1);
}

// ── colossus ────────────────────────────────────────────────────────────────
//
// A ring of standing stones round a fire. The stones are dark faceted
// crystal, each turning on its own axis as the ring turns, seen from above
// and in front so the far ones stand behind the fire and the near ones
// before it — and lit by it: the faces turned to the fire burn in its
// colour, the faces turned away stay black. Embers boil up between them. Winding up, the ring closes in
// on the fire; striking, it is blown wide.

final List<FacetMesh> _stones = [
  for (var k = 0; k < 6; k++)
    FacetMesh.obelisk(
      height: 1.45 + 0.3 * sin(k * 2.3),
      base: 0.19,
      taper: 0.55,
      cap: 0.36,
      seed: 11 + k * 1.7,
    ),
];

/// The ring's tilt: its axis leans up the screen and toward the viewer.
final Rot3 _ringTilt = Rot3().setX(2.5);
final Rot3 _spinY = Rot3();
final List<(double, int, double, double)> _stoneOrder = [];

/// Embers: (angle, rate, phase, curl).
final List<(double, double, double, double)> _embers = () {
  final rng = Random(29);
  return [
    for (var i = 0; i < 64; i++)
      (
        rng.nextDouble() * 2 * pi,
        0.35 + rng.nextDouble() * 0.45,
        rng.nextDouble(),
        (rng.nextDouble() - 0.5) * 1.4,
      ),
  ];
}();

/// Fire's embers boiling off a core of radius [core], out to [reach].
void _paintEmbers(
  Canvas c,
  EnemyPalette pal,
  double time, {
  double core = 0.35,
  double reach = 1.2,
  double rate = 1,
  double seed = 0,
}) {
  _grainReset();
  for (final (a0, r, ph, curl) in _embers) {
    final u = _frac(time * r * rate + ph + seed);
    final rr = core + u * reach;
    final a = a0 + curl * u;
    // Rising: drawn a little up the screen as they climb.
    _grainAdd(
      u < 0.25 ? 0 : (u < 0.6 ? 1 : 2),
      cos(a) * rr,
      sin(a) * rr - 0.25 * u * u,
    );
  }
  _grainDraw(c, 2, 0.05, Color.lerp(pal.essence, pal.ink, 0.35)!.withValues(
    alpha: 0.5,
  ));
  _grainDraw(c, 1, 0.075, pal.essence.withValues(alpha: 0.8));
  _grainDraw(c, 0, 0.1, pal.hot);
}

void paintColossusBody(
  Canvas c,
  EnemyPalette pal, {
  required double time,
  required double seed,
  required double turn,
  double contraction = 0,
  double charge = 0,
  double flash = 0,
}) {
  _circle(c, pal.glow, 2.2 + 0.3 * charge);
  final ring = 1.02 * (1 + contraction);
  final spin = turn + time * 0.16 + seed;
  final t = _ringTilt.m;

  _stoneOrder.clear();
  for (var k = 0; k < 6; k++) {
    final a = spin + k * pi / 3;
    // On the ring, lifted a little along its axis.
    final lx = cos(a) * ring, ly = 0.22, lz = sin(a) * ring;
    _stoneOrder.add((
      t[6] * lx + t[7] * ly + t[8] * lz,
      k,
      t[0] * lx + t[1] * ly + t[2] * lz,
      t[3] * lx + t[4] * ly + t[5] * lz,
    ));
  }
  _stoneOrder.sort((a, b) => a.$1.compareTo(b.$1));

  void stones(bool near) {
    for (final (z, k, x, y) in _stoneOrder) {
      if ((z > 0) != near) continue;
      _spinY.setY(time * 0.35 + k * 1.3 + seed);
      _rot.mul(_ringTilt, _spinY);
      meshBatch.add(
        _stones[k],
        _rot,
        pal,
        ox: x,
        oy: y,
        oz: z,
        inset: 0,
        seamAlpha: 0,
        lit: 0.3,
        rimGlow: 0.6,
        dark: 0.75,
        fire: 2.6 + 1.6 * charge,
        heat: 0.1 * charge,
      );
    }
    meshBatch.flush(c);
  }

  stones(false);
  _paintEmbers(
    c,
    pal,
    time,
    core: 0.3,
    reach: 1.05 + 0.5 * charge,
    rate: 1 + charge,
    seed: seed,
  );
  _sparkAt(c, pal, Offset.zero, 0.7 + 0.25 * charge);
  _sparkAt(c, pal, Offset.zero, 0.3, 0.9);
  stones(true);
  _hitFlash(c, flash, 1.2);
}
