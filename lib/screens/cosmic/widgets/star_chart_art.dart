// lib/screens/cosmic/widgets/star_chart_art.dart
//
// What the star chart, the radar and the space HUD draw things with, in the
// material of open space (obsidian_kit.dart): glass lit from inside, light as
// soft pools, grains for anything loose. No outline strokes, no hoops, no
// blur.
//
//   ChartFog         explored space as a soft haze, baked once per change
//                    into a small image and laid down scaled — its edge is
//                    rounded by the upscale, not stepped in cells
//   ChartGlyph       one mark per kind of place, drawn at a fixed screen
//                    size: stations are cut glass, nebulae a pinch of grains,
//                    a lair a dark crown, a cache a small orb
//   paintChartShip   the ship as an amber dart along its heading
//   paintDustGlyph   the star dust count's symbol: a small heap of gold grains
//   paintRaidGlyph   an overrun planet: an orb with a crimson storm round it
//
// Every shader here is built once per colour and cached; a mark is a handful
// of disc fills and at most one point pass.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:flutter/rendering.dart';

/// The chart's warm amber: the ship, home, and anything that is yours.
const Color kChartAmber = Color(0xFFE9C77A);

/// Explored space: a smoky violet just lifted off the black.
const Color kChartHaze = Color(0xFF1E1A2C);

// ── explored space ──────────────────────────────────────────────────────────

/// Explored space, baked from the revealed fog cells into an image a few
/// pixels per cell, each cell a soft dot that overlaps its neighbours, so
/// the union reads as a rounded haze. Rebuilt only when a cell is added.
class ChartFog {
  ChartFog._();

  static ui.Image? _image;
  static int _key = 0;

  /// Pixels per fog cell in the baked mask.
  static const int _ppc = 3;

  /// The mask for [cells] on a [gridW] × [gridH] grid.
  static ui.Image maskFor(Set<int> cells, int gridW, int gridH) {
    final key = Object.hash(identityHashCode(cells), cells.length, gridW);
    final cached = _image;
    if (cached != null && _key == key) return cached;
    _image?.dispose();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    // Two passes: a wide dim dot that rounds the edge off, and a tight core
    // so the interior is evenly filled.
    final xy = Float32List(cells.length * 2);
    var i = 0;
    for (final k in cells) {
      xy[i++] = (k % gridW + 0.5) * _ppc;
      xy[i++] = (k ~/ gridW + 0.5) * _ppc;
    }
    final dot = Paint()
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    c.drawRawPoints(
      ui.PointMode.points,
      xy,
      dot
        ..strokeWidth = _ppc * 2.6
        ..color = const Color(0x55FFFFFF),
    );
    c.drawRawPoints(
      ui.PointMode.points,
      xy,
      dot
        ..strokeWidth = _ppc * 1.5
        ..color = const Color(0xFFFFFFFF),
    );
    final pic = rec.endRecording();
    final img = pic.toImageSync(gridW * _ppc, gridH * _ppc);
    pic.dispose();
    _image = img;
    _key = key;
    return img;
  }

  /// Lays the haze of [cells] over [dst] (the whole world, in chart units).
  static void paint(
    Canvas c,
    Rect dst,
    Set<int> cells,
    int gridW,
    int gridH, {
    Color color = kChartHaze,
    double alpha = 0.9,
  }) {
    if (cells.isEmpty) return;
    final img = maskFor(cells, gridW, gridH);
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.mode(
          color.withValues(alpha: alpha),
          BlendMode.srcIn,
        ),
    );
  }
}

// ── grains ──────────────────────────────────────────────────────────────────

final PointBatch _grains = PointBatch(160);
final PointBatch _grainsHot = PointBatch(60);

/// A fixed scatter of [n] grains in a disc of [r] at [at], seeded by [salt].
void _scatter(PointBatch b, Offset at, double r, int n, int salt) {
  for (var i = 0; i < n; i++) {
    final rr = r * sqrt(hash01(i, salt));
    final a = hash01(i, salt + 7) * 2 * pi;
    b.add(at.dx + cos(a) * rr, at.dy + sin(a) * rr);
  }
}

// ── glyphs ──────────────────────────────────────────────────────────────────

/// The kinds of mark the chart and radar draw.
enum ChartGlyph {
  station,
  nebula,
  derelict,
  anomaly,
  portal,
  signal,
  lair,
  whirl,
  cache,
  contest,
  prismatic,
  nexus,
  bloodRing,
  bloodHint,
  home,
}

/// A unit outline per cut-glass kind, and its apex.
final Map<ChartGlyph, (List<Offset>, Offset)> _cuts = {
  ChartGlyph.station: (
    [for (var i = 0; i < 6; i++) polar(1, i * pi / 3 - pi / 2)],
    const Offset(-0.18, -0.22),
  ),
  ChartGlyph.contest: (
    [for (var i = 0; i < 8; i++) polar(i.isEven ? 1 : 0.78, i * pi / 4)],
    const Offset(-0.15, -0.2),
  ),
  ChartGlyph.lair: (
    const [
      Offset(0, -1.25),
      Offset(0.42, -0.5),
      Offset(0.9, -0.62),
      Offset(0.7, 0.2),
      Offset(0, 1),
      Offset(-0.7, 0.2),
      Offset(-0.9, -0.62),
      Offset(-0.42, -0.5),
    ],
    const Offset(0, -0.12),
  ),
  ChartGlyph.derelict: (
    const [
      Offset(-0.95, -0.35),
      Offset(0.1, -0.85),
      Offset(0.35, 0.05),
      Offset(-0.45, 0.7),
    ],
    const Offset(-0.2, -0.15),
  ),
};

final Map<(ChartGlyph, Color), CutStone> _stones = {};

CutStone _stone(ChartGlyph g, Color col) => _stones[(g, col)] ??= () {
  final (outline, apex) = _cuts[g]!;
  return CutStone.gem(stoneLightFor(col), outline, apex);
}();

/// Cut glass is a dozen faceted paths and a clip; the pin layer repaints on
/// every pan frame, so each (kind, colour, turn) is baked once into a small
/// image and stamped after that.
final Map<(ChartGlyph, Color, double), ui.Image> _baked = {};
final Paint _stamp = Paint()..filterQuality = FilterQuality.medium;

/// Baked pixels per unit radius: a mark is at most ~7 px on screen, ×3 DPR.
const double _bakeR = 24;

ui.Image _bakedCut(ChartGlyph g, Color col, double rot) =>
    _baked[(g, col, rot)] ??= () {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.translate(_bakeR * 1.5, _bakeR * 1.5);
      if (rot != 0) c.rotate(rot);
      c.scale(_bakeR);
      _stone(g, col).paint(c, rot, glow: 0.9, reach: 1.4);
      final pic = rec.endRecording();
      final img = pic.toImageSync((_bakeR * 3).ceil(), (_bakeR * 3).ceil());
      pic.dispose();
      return img;
    }();

void _cut(
  Canvas c,
  ChartGlyph g,
  Color col,
  Offset at,
  double r, {
  double rot = 0,
}) {
  final img = _bakedCut(g, col, rot);
  c.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    Rect.fromCenter(center: at, width: r * 3, height: r * 3),
    _stamp,
  );
}

final ui.Shader _voidShader = ui.Gradient.radial(
  Offset.zero,
  1,
  const [Color(0xFF000000), Color(0xF0050308), Color(0x00050308)],
  const [0.0, 0.62, 1.0],
);

/// One mark of kind [g] in [col], [r] its radius in screen pixels. [dim]
/// (0..1) fades a spent or unconfirmed place back.
void paintChartGlyph(
  Canvas c,
  ChartGlyph g,
  Offset at,
  Color col, {
  double r = 5.5,
  double dim = 1,
  int salt = 0,
}) {
  final m = stoneLightFor(col);
  switch (g) {
    case ChartGlyph.station:
    case ChartGlyph.contest:
      paintDisc(c, m.leak, at, r * 2.6, 0.55 * dim);
      _cut(c, g, col, at, r);
      paintDisc(c, m.spark, at, r * 0.55, 0.7 * dim);
    case ChartGlyph.lair:
      paintDisc(c, m.leak, at, r * 3.0, 0.7 * dim);
      _cut(c, g, col, at, r);
      paintDisc(c, m.spark, at + Offset(0, -r * 0.1), r * 0.45, 0.9 * dim);
    case ChartGlyph.derelict:
      paintDisc(c, m.leak, at, r * 1.8, 0.25 * dim);
      _cut(c, g, col, at + Offset(-r * 0.35, 0), r * 0.75, rot: 0.3);
      _cut(c, g, col, at + Offset(r * 0.55, r * 0.15), r * 0.6, rot: 2.7);
    case ChartGlyph.nebula:
      paintDisc(c, m.pool, at, r * 2.4, 1.6 * dim);
      _grains.clear();
      _grainsHot.clear();
      _scatter(_grains, at, r * 1.5, 26, 11 + salt);
      _scatter(_grainsHot, at, r * 0.7, 7, 31 + salt);
      _grains.draw(c, 1.4, m.grainDim.withValues(alpha: 0.75 * dim));
      _grainsHot.draw(c, 1.8, m.grainHot.withValues(alpha: 0.9 * dim));
    case ChartGlyph.anomaly:
      paintDisc(c, m.leak, at, r * 2.4, 0.6 * dim);
      paintDisc(c, _voidShader, at, r * 1.1, dim);
      _grains.clear();
      for (var i = 0; i < 10; i++) {
        final a = i * 2 * pi / 10 + hash01(i, 3) * 0.5;
        final rr = r * (1.05 + 0.3 * hash01(i, 9));
        _grains.add(at.dx + cos(a) * rr, at.dy + sin(a) * rr);
      }
      _grains.draw(c, 1.5, m.grainHot.withValues(alpha: 0.85 * dim));
    case ChartGlyph.portal:
      paintDisc(c, m.leak, at, r * 2.8, 0.75 * dim);
      paintDisc(c, _voidShader, at, r * 1.15, dim);
      // Standing stones round the deep.
      for (var i = 0; i < 4; i++) {
        final a = i * pi / 2 + pi / 4;
        paintOrb(c, m, at + polar(r * 1.25, a), r * 0.32, alpha: dim);
      }
      paintDisc(c, m.spark, at, r * 0.5, 0.65 * dim);
    case ChartGlyph.signal:
      // Not yet found: only its light, a faint unsteady pool.
      paintDisc(c, m.leak, at, r * 2.4, 0.45 * dim);
      paintDisc(c, m.spark, at, r * 0.45, 0.5 * dim);
    case ChartGlyph.whirl:
      paintDisc(c, m.pool, at, r * 2.2, 1.4 * dim);
      _grains.clear();
      for (var arm = 0; arm < 3; arm++) {
        for (var i = 0; i < 7; i++) {
          final f = i / 6;
          final a = arm * 2 * pi / 3 + f * 2.4;
          final rr = r * (0.25 + 1.15 * f);
          _grains.add(at.dx + cos(a) * rr, at.dy + sin(a) * rr);
        }
      }
      _grains.draw(c, 1.5, m.grainHot.withValues(alpha: 0.85 * dim));
      paintDisc(c, m.spark, at, r * 0.55, 0.8 * dim);
    case ChartGlyph.cache:
      paintDisc(c, m.leak, at, r * 2.0, 0.55 * dim);
      paintOrb(c, m, at, r * 0.75, alpha: dim);
    case ChartGlyph.prismatic:
      paintDisc(c, m.pool, at, r * 2.6, 1.6 * dim);
      const hues = [
        Color(0xFFFF6F91),
        Color(0xFFFFC75F),
        Color(0xFF9EF07A),
        Color(0xFF5BD8FF),
        Color(0xFFB98CFF),
      ];
      for (var h = 0; h < hues.length; h++) {
        _grains.clear();
        _scatter(_grains, at, r * 1.6, 7, 50 + h * 13);
        _grains.draw(c, 1.5, hues[h].withValues(alpha: 0.8 * dim));
      }
    case ChartGlyph.nexus:
      paintDisc(c, m.leak, at, r * 2.6, 0.6 * dim);
      paintDisc(c, _voidShader, at, r * 0.95, dim);
      const elements = [
        Color(0xFFFF6D00),
        Color(0xFF2196F3),
        Color(0xFF4CAF50),
        Color(0xFFCFD8DC),
      ];
      for (var i = 0; i < 4; i++) {
        paintOrb(
          c,
          stoneLightFor(elements[i]),
          at + polar(r * 1.45, i * pi / 2 - pi / 4),
          r * 0.36,
          alpha: dim,
        );
      }
    case ChartGlyph.bloodRing:
      paintDisc(c, m.leak, at, r * 3.0, 0.8 * dim);
      paintDisc(c, _voidShader, at, r * 0.9, dim);
      // The thorn crown, as two tapered crescents.
      for (final (a0, a1) in const [(-2.7, -0.5), (0.45, 2.65)]) {
        paintFill(
          c,
          polyPath([
            for (final p in crescentPoints(r * 1.15, a0, a1, r * 0.42, n: 10))
              at + p,
          ]),
          m.orb,
          dim,
        );
      }
      paintDisc(c, m.spark, at, r * 0.4, 0.7 * dim);
    case ChartGlyph.bloodHint:
      paintDisc(c, m.leak, at, r * 2.2, 0.22 * dim);
    case ChartGlyph.home:
      paintDisc(c, m.leak, at, r * 2.4, 0.6 * dim);
      paintOrb(c, m, at, r, alpha: dim);
  }
}

// ── the ship ────────────────────────────────────────────────────────────────

final StoneLight _shipLight = StoneLight(kChartAmber);

/// The dart at unit half-length, pointing along +x.
final Path _dart = Path()
  ..moveTo(1, 0)
  ..lineTo(-0.7, 0.66)
  ..lineTo(-0.32, 0)
  ..lineTo(-0.7, -0.66)
  ..close();
final ui.Shader _dartLight = ui.Gradient.linear(
  const Offset(1, 0),
  const Offset(-0.7, 0),
  const [Color(0xFFFFF4D8), kChartAmber, Color(0xFF6B5320)],
  const [0.0, 0.45, 1.0],
);
final Paint _dartInk = Paint()..color = const Color(0xFF14110B);

/// The ship as a small amber dart at [at], pointing along [angle] (radians,
/// 0 = +x), [r] its half-length.
void paintChartShip(Canvas c, Offset at, double angle, {double r = 6.5}) {
  paintDisc(c, _shipLight.leak, at, r * 2.6, 0.75);
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(angle);
  c.scale(r);
  c.drawPath(_dart, _dartInk);
  paintFill(c, _dart, _dartLight);
  c.restore();
}

// ── HUD symbols ─────────────────────────────────────────────────────────────

final StoneLight _dustLight = StoneLight(const Color(0xFFF2C96F));

/// Star dust: a small heap of gold grains in an [s]-pixel box at [at] (its
/// centre).
void paintDustGlyph(Canvas c, Offset at, double s) {
  paintDisc(c, _dustLight.leak, at, s * 0.7, 0.55);
  _grains.clear();
  _grainsHot.clear();
  // A heap: grains packed denser and higher toward the middle.
  for (var i = 0; i < 34; i++) {
    final x = (hash01(i, 5) * 2 - 1);
    final h = (1 - x * x) * hash01(i, 9);
    final p = at + Offset(x * s * 0.42, s * 0.3 - h * s * 0.55);
    (i % 4 == 0 ? _grainsHot : _grains).add(p.dx, p.dy);
  }
  _grains.draw(c, s * 0.11, _dustLight.grainDim);
  _grainsHot.draw(c, s * 0.13, _dustLight.grainHot);
  paintDisc(c, _dustLight.spark, at + Offset(0, -s * 0.12), s * 0.18, 0.8);
}

const Color _raidEmber = Color(0xFFE25544);
final StoneLight _raidLight = StoneLight(_raidEmber);

/// An overrun planet: an orb of [planet]'s colour inside a crimson storm of
/// grains, in an [s]-pixel box centred on [at].
void paintRaidGlyph(Canvas c, Offset at, double s, Color planet) {
  final r = s * 0.24;
  paintDisc(c, _raidLight.leak, at, s * 0.62, 0.8);
  paintOrb(c, stoneLightFor(planet), at, r);
  _grains.clear();
  _grainsHot.clear();
  // A ragged swarm, thicker on the side the storm is coming from, so it
  // reads as weather on the planet rather than a ring round it.
  for (var i = 0; i < 46; i++) {
    final a = hash01(i, 4) * 2 * pi;
    final lean = 0.5 + 0.5 * cos(a + 0.9);
    final rr = r * (1.05 + (0.35 + 0.75 * lean) * hash01(i, 6));
    final p = at + Offset(cos(a) * rr, sin(a) * rr * 0.8);
    (hash01(i, 8) < 0.3 ? _grainsHot : _grains).add(p.dx, p.dy);
  }
  _grains.draw(c, s * 0.04, _raidLight.grainDim);
  _grainsHot.draw(c, s * 0.055, _raidLight.grainHot);
}

/// A symbol drawn into its box. [tag] is whatever the symbol depends on, so
/// it repaints only when that changes.
class ChartSymbolPainter extends CustomPainter {
  const ChartSymbolPainter(this.paintAt, {this.tag});

  final void Function(Canvas c, Offset at, double s) paintAt;
  final Object? tag;

  @override
  void paint(Canvas canvas, Size size) => paintAt(
    canvas,
    Offset(size.width / 2, size.height / 2),
    min(size.width, size.height),
  );

  @override
  bool shouldRepaint(covariant ChartSymbolPainter old) => old.tag != tag;
}
