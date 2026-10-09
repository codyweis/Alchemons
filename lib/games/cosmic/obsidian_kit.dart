// lib/games/cosmic/obsidian_kit.dart
//
// The material the stations and the contest arenas of open space are cut
// from — the ship's material (ship_art.dart) for things that stand still:
// obsidian whose color comes only from the light inside it, glass that holds
// that light, and grains for anything that moves.
//
//   StoneLight   a light and the stone and glass round it, with its shaders
//   CutStone     a solid cut into facets, each lit by how it faces the key
//                light (a gem fanned from an apex, or a ridge along +x)
//   BakedArt     stone that never moves, painted once into an image
//   PointBatch   grains gathered over a frame and drawn in one pass
//
// No outline strokes, no hoops, no blur.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

// ── light and material ──────────────────────────────────────────────────────

/// The direction the key light comes from (up and to the left, as on the
/// planets). A face turned toward it is lit; one turned away keeps only the
/// station's own light.
const Offset kToLight = Offset(-0.55, -0.835);

/// How much a face whose outward normal is [n] (after [rot]) catches the
/// key light, 0..1.
double keyLit(Offset n, double rot) {
  final c = cos(rot), s = sin(rot);
  final x = n.dx * c - n.dy * s;
  final y = n.dx * s + n.dy * c;
  final d = x * kToLight.dx + y * kToLight.dy;
  return ((d + 0.35) / 1.35).clamp(0.0, 1.0);
}

/// What a station is cut from and the light inside it.
class StoneLight {
  StoneLight(this.essence, {double warm = 0})
    : ink = Color.lerp(const Color(0xFF040509), essence, 0.035 + warm)!,
      face = Color.lerp(const Color(0xFF0C0E14), essence, 0.09 + warm)!,
      rim = Color.lerp(essence, const Color(0xFFFFFFFF), 0.3)!,
      hot = Color.lerp(essence, const Color(0xFFFFFFFF), 0.78)!;

  final Color essence, ink, face, rim, hot;

  Color a(Color c, double alpha) => c.withValues(alpha: alpha);

  late final ui.Shader pool = ui.Gradient.radial(
    Offset.zero,
    1,
    [a(essence, 0.2), a(essence, 0.07), a(essence, 0)],
    const [0.0, 0.45, 1.0],
  );

  late final ui.Shader spark = ui.Gradient.radial(
    Offset.zero,
    1,
    [const Color(0xFFFFFFFF), hot, a(essence, 0.7), a(essence, 0)],
    const [0.0, 0.22, 0.5, 1.0],
  );

  /// A glass sphere with light inside, lit from the key light's side.
  /// Unit radius.
  late final ui.Shader orb = ui.Gradient.radial(
    const Offset(-0.36, -0.42),
    1.5,
    [
      a(hot, 0.95),
      a(essence, 0.9),
      Color.lerp(essence, ink, 0.66)!,
      Color.lerp(ink, essence, 0.06)!,
      Color.lerp(ink, rim, 0.22)!,
    ],
    const [0.0, 0.12, 0.42, 0.82, 1.0],
  );

  /// Light from inside, leaking through the stone round [at]. Unit radius.
  late final ui.Shader leak = ui.Gradient.radial(
    Offset.zero,
    1,
    [a(essence, 0.5), a(essence, 0.16), a(essence, 0)],
    const [0.0, 0.4, 1.0],
  );

  /// A bar of glass lit along its length: a key's shaft. Origin to (0, 14).
  late final ui.Shader glassBar = ui.Gradient.linear(
    const Offset(-1.5, 0),
    const Offset(1.5, 0),
    [rim, essence, Color.lerp(essence, ink, 0.6)!],
    const [0.0, 0.4, 1.0],
  );

  late final Color grainHot = Color.lerp(essence, hot, 0.55)!;
  late final Color grainDim = a(Color.lerp(rim, essence, 0.5)!, 0.8);
}

final Map<Color, StoneLight> _stoneLights = {};
StoneLight stoneLightFor(Color c) =>
    _stoneLights[c] ??= StoneLight(c, warm: 0.04);

final Paint _fill = Paint()..isAntiAlias = true;
final Paint stonePaint = Paint()..isAntiAlias = true;
final Paint _pts = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

void _shade(ui.Shader s, double alpha) {
  _fill
    ..shader = s
    ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0));
}

void paintFill(Canvas c, Path p, ui.Shader s, [double alpha = 1]) {
  if (alpha <= 0.004) return;
  _shade(s, alpha);
  c.drawPath(p, _fill);
}

/// A unit-radius shader as a disc of [radius] at [at].
void paintDisc(
  Canvas c,
  ui.Shader s,
  Offset at,
  double radius, [
  double alpha = 1,
]) {
  if (alpha <= 0.004 || radius <= 0) return;
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(radius);
  _shade(s, alpha);
  c.drawCircle(Offset.zero, 1, _fill);
  c.restore();
}

final ui.Shader kGlint = ui.Gradient.radial(
  Offset.zero,
  1,
  const [Color(0xE6FFFFFF), Color(0x40FFFFFF), Color(0x00FFFFFF)],
  const [0.0, 0.4, 1.0],
);

/// A glass orb of [m]'s light, radius [r], with its glint.
void paintOrb(Canvas c, StoneLight m, Offset at, double r, {double alpha = 1}) {
  paintDisc(c, m.orb, at, r, alpha);
  paintDisc(
    c,
    kGlint,
    at + Offset(-r * 0.38, -r * 0.44),
    r * 0.2,
    0.65 * alpha,
  );
}

// ── shapes ──────────────────────────────────────────────────────────────────

Path polyPath(List<Offset> pts) {
  final p = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (final q in pts.skip(1)) {
    p.lineTo(q.dx, q.dy);
  }
  return p..close();
}

Offset polar(double r, double a) => Offset(cos(a) * r, sin(a) * r);

Offset unitOffset(Offset o) => o / max(o.distance, 1e-6);

/// One face of a cut solid: dark stone under it, and over it the face's
/// light — brighter toward the station's own light at [inner].
class StoneFacet {
  StoneFacet(this.path, this.normal, this.light);
  final Path path;
  final Offset normal;
  final ui.Shader light;
}

/// A solid cut into facets. Each facet is laid in ink and then lit by how
/// it faces the key light, so the solid keeps its shape as it turns.
class CutStone {
  CutStone(this.m, this.facets, this.outline, {this.core});

  /// A gem: the outline fanned into triangles from [apex].
  factory CutStone.gem(StoneLight m, List<Offset> outline, Offset apex) {
    final facets = <StoneFacet>[];
    for (var i = 0; i < outline.length; i++) {
      final a = outline[i], b = outline[(i + 1) % outline.length];
      final mid = (a + b) / 2;
      facets.add(
        StoneFacet(
          polyPath([apex, a, b]),
          unitOffset(mid - apex),
          ui.Gradient.linear(
            apex,
            mid,
            [
              Color.lerp(m.ink, m.essence, 0.42)!,
              m.face,
              m.ink,
              Color.lerp(m.face, m.rim, 0.55)!,
            ],
            const [0.0, 0.32, 0.8, 1.0],
          ),
        ),
      );
    }
    return CutStone(m, facets, polyPath(outline), core: apex);
  }

  /// A ridge along +x: [top] traces the upper edge from the base to the
  /// tip (y ≤ 0); the lower edge mirrors it. Two faces meet on the spine.
  factory CutStone.ridge(StoneLight m, List<Offset> top) {
    final base = Offset(top.first.dx, 0), tip = Offset(top.last.dx, 0);
    final upper = polyPath([base, ...top, tip]);
    final lower = polyPath([base, ...top.map((p) => Offset(p.dx, -p.dy)), tip]);
    ui.Shader light(double side) => ui.Gradient.linear(
      Offset(base.dx, 0),
      Offset(base.dx, side * top.map((p) => p.dy.abs()).reduce(max)),
      [m.face, m.ink, Color.lerp(m.face, m.rim, 0.55)!],
      const [0.0, 0.7, 1.0],
    );
    return CutStone(m, [
      StoneFacet(upper, const Offset(0, -1), light(-1)),
      StoneFacet(lower, const Offset(0, 1), light(1)),
    ], polyPath([...top, ...top.reversed.map((p) => Offset(p.dx, -p.dy))]));
  }

  final StoneLight m;
  final List<StoneFacet> facets;
  final Path outline;
  final Offset? core;

  /// [rot] is how far the canvas has been turned, so the key light stays
  /// put in the world. [glow] is the light inside leaking out round [core].
  void paint(Canvas c, double rot, {double glow = 1, double reach = 20}) {
    stonePaint.color = m.ink;
    for (final f in facets) {
      c.drawPath(f.path, stonePaint);
      paintFill(c, f.path, f.light, 0.12 + 0.88 * keyLit(f.normal, rot));
    }
    final at = core;
    if (at != null && glow > 0) {
      c.save();
      c.clipPath(outline);
      paintDisc(c, m.leak, at, reach * 0.62, glow * 0.7);
      c.restore();
    }
  }
}

/// A crescent that tapers to points at both ends: the arc from [a0] to [a1]
/// at radius [r], [width] at its middle.
List<Offset> crescentPoints(
  double r,
  double a0,
  double a1,
  double width, {
  int n = 18,
}) {
  final outer = <Offset>[];
  final inner = <Offset>[];
  for (var i = 0; i <= n; i++) {
    final f = i / n;
    final a = a0 + (a1 - a0) * f;
    final h = width / 2 * sin(pi * f);
    outer.add(polar(r + h, a));
    inner.add(polar(r - h, a));
  }
  return [...outer, ...inner.reversed];
}

/// Grains gathered over a frame and drawn as one point pass.
class PointBatch {
  PointBatch(int capacity) : _xy = Float32List(capacity * 2);
  final Float32List _xy;
  int _n = 0;

  void clear() => _n = 0;

  void add(double x, double y) {
    if (_n * 2 >= _xy.length) return;
    _xy[_n * 2] = x;
    _xy[_n * 2 + 1] = y;
    _n++;
  }

  void draw(Canvas c, double size, Color col) {
    if (_n == 0 || col.a <= 0.004) return;
    _pts
      ..strokeWidth = size
      ..color = col;
    c.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(_xy, 0, _n * 2),
      _pts,
    );
  }
}

/// A hash in [0, 1) — stable per index, so grains keep their paths.
double hash01(int i, int salt) {
  final x = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

/// The usual arm: a ridge out along +x from [from] to [to].
CutStone ridgeArm(StoneLight m, double from, double to, double w0, double w1) =>
    CutStone.ridge(m, [
      Offset(from, -w0 * 0.7),
      Offset(from + 2, -w0),
      Offset(to - 3, -w1),
      Offset(to, -w1 * 0.4),
    ]);

/// Stone that never moves, painted once into an image and laid down with a
/// single draw: a station's cut solids are dozens of faces, and only its
/// light and grains change from frame to frame.
class BakedArt {
  BakedArt(this.bounds, this.paint);

  /// The image's extent in station units.
  final Rect bounds;
  final void Function(Canvas c) paint;
  ui.Image? _image;

  /// Pixels per station unit: a little over the most a station is ever
  /// magnified on a phone (the closest zoom, ×1.6, ×3 screen ≈ 4).
  static const double _ppu = 4.5;

  static final Paint _imagePaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;

  void draw(Canvas c, [double alpha = 1]) {
    final img = _image ??= _bake();
    _imagePaint.color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0));
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      bounds,
      _imagePaint,
    );
  }

  ui.Image _bake() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.scale(_ppu);
    c.translate(-bounds.left, -bounds.top);
    paint(c);
    final pic = rec.endRecording();
    final img = pic.toImageSync(
      (bounds.width * _ppu).ceil(),
      (bounds.height * _ppu).ceil(),
    );
    pic.dispose();
    return img;
  }
}
