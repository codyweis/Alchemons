// lib/games/constellations/constellation_art.dart
//
// What the star chart is made of.
//
// A skill is a stone cut from obsidian: a dark hexagonal crown of facets
// round a flat table, its colour coming only from light — the edge that
// catches it, the core that burns once the skill is owned. Nothing strokes an
// outline or a hoop. A link between two skills is a stream of grains, poured
// from the parent into the child; unlocking a skill is that pour arriving and
// the stone igniting.
//
// Each tree has one light (verdigris, amber, ember), and that light is the
// only colour the tree uses: its stones, its grains, its patch of sky and its
// tab on the screen all read it from [treeLight].
//
// The glyphs are inked here as filled shapes, one per kind of skill, instead
// of Material icons drawn through a font.
//
// Everything built here is built once and shared — every node is the same
// size, so its geometry and gradients are the same for all of them.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:flutter/rendering.dart';

// ── light ───────────────────────────────────────────────────────────────────

/// What one tree's stones are cut from and the light inside them.
class TreeLight {
  const TreeLight(this.ink, this.face, this.rim, this.essence, this.hot);

  /// The obsidian: its dark body, the face nearest the light, the edge that
  /// catches it.
  final Color ink, face, rim;

  /// The light, and its white-hot centre.
  final Color essence, hot;
}

const Map<ConstellationTree, TreeLight> kTreeLights = {
  // Verdigris — the alchemist's own colour.
  ConstellationTree.breeder: TreeLight(
    Color(0xFF040909),
    Color(0xFF0E1C1C),
    Color(0xFF9AE6D6),
    Color(0xFF4FC6B0),
    Color(0xFFE4FFF8),
  ),
  // Amber — trade and the road.
  ConstellationTree.extraction: TreeLight(
    Color(0xFF090704),
    Color(0xFF1E170C),
    Color(0xFFF2D08A),
    Color(0xFFE5AC4A),
    Color(0xFFFFF5DA),
  ),
  // Ember — the arena.
  ConstellationTree.combat: TreeLight(
    Color(0xFF0A0504),
    Color(0xFF20110D),
    Color(0xFFF4A487),
    Color(0xFFDE6747),
    Color(0xFFFFE6D8),
  ),
};

TreeLight treeLight(ConstellationTree tree) => kTreeLights[tree]!;

/// The parchment the chart's words are written in, and its quieter shade.
const Color kChartInk = Color(0xFFE6E2DA);
const Color kChartMuted = Color(0xFF8E8C88);

/// Deeper than any stone: the ink a glyph is cut into a lit table with.
const Color kChartVoid = Color(0xFF07080B);

// ── glyphs ──────────────────────────────────────────────────────────────────

/// The mark inked on a skill's table.
enum ChartSigil {
  merge,
  lineage,
  helix,
  rise,
  hourglass,
  leaf,
  bolt,
  eye,
  star,
  chevrons,
  ascent,
  flask,
  spark,
  coin,
  stack,
  tag,
  tree,
  infinity,
  flame,
}

/// Which glyph a skill wears — the same reading of its id that chose its
/// icon (see [ConstellationSkill.identityIcon]), so a skill keeps its
/// meaning, only drawn rather than typed.
ChartSigil sigilFor(ConstellationSkill skill) {
  final lid = skill.id.toLowerCase();
  if (lid.contains('cross')) return ChartSigil.merge;
  if (lid.contains('lineage')) return ChartSigil.lineage;
  if (lid.contains('gene')) return ChartSigil.helix;
  if (lid.contains('potential')) return ChartSigil.rise;
  if (lid.contains('accelerated') || lid.contains('gestation')) {
    return ChartSigil.hourglass;
  }
  if (lid.contains('harvesting')) return ChartSigil.leaf;
  if (lid.contains('atk')) return ChartSigil.bolt;
  if (lid.contains('int')) return ChartSigil.eye;
  if (lid.contains('beauty')) return ChartSigil.star;
  if (lid.contains('speed')) return ChartSigil.chevrons;
  if (lid.contains('xp')) return ChartSigil.ascent;
  if (lid.contains('alchemon')) return ChartSigil.flask;
  if (lid.contains('instant')) return ChartSigil.spark;
  if (lid.contains('marketplace')) return ChartSigil.coin;
  if (lid.contains('resource')) return ChartSigil.stack;
  if (lid.contains('sale')) return ChartSigil.tag;
  if (lid.contains('wilderness')) return ChartSigil.tree;
  if (lid.contains('all')) return ChartSigil.infinity;
  return switch (skill.tree) {
    ConstellationTree.breeder => ChartSigil.flask,
    ConstellationTree.combat => ChartSigil.flame,
    ConstellationTree.extraction => ChartSigil.leaf,
  };
}

final Map<ChartSigil, Path> _sigilUnit = {};
final Map<(ChartSigil, double, double, double), Path> _sigilScaled = {};

/// [sigil] inside a circle of radius 1 about the origin.
Path sigilPath(ChartSigil sigil) =>
    _sigilUnit.putIfAbsent(sigil, () => _buildSigil(sigil));

/// [sigil] at [radius] about [center], built once per size.
Path sigilPathAt(ChartSigil sigil, Offset center, double radius) =>
    _sigilScaled.putIfAbsent((sigil, radius, center.dx, center.dy), () {
      final m = Float64List(16)
        ..[0] = radius
        ..[5] = radius
        ..[10] = 1
        ..[12] = center.dx
        ..[13] = center.dy
        ..[15] = 1;
      return sigilPath(sigil).transform(m);
    });

Path _poly(List<double> xy) {
  final p = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    p.lineTo(xy[i], xy[i + 1]);
  }
  return p..close();
}

Path _disc(double x, double y, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

Path _ring(double x, double y, double r, double w) =>
    Path.combine(PathOperation.difference, _disc(x, y, r), _disc(x, y, r - w));

/// A bar from a to b, [wa] wide at a and [wb] at b.
Path _bar(Offset a, Offset b, double wa, [double? wb]) {
  final d = b - a;
  final n = Offset(-d.dy, d.dx) / d.distance;
  final ha = n * (wa / 2), hb = n * ((wb ?? wa) / 2);
  return _poly([
    (a + ha).dx,
    (a + ha).dy,
    (b + hb).dx,
    (b + hb).dy,
    (b - hb).dx,
    (b - hb).dy,
    (a - ha).dx,
    (a - ha).dy,
  ]);
}

Path _union(List<Path> parts) {
  var out = parts.first;
  for (final p in parts.skip(1)) {
    out = Path.combine(PathOperation.union, out, p);
  }
  return out;
}

Path _minus(Path a, Path b) => Path.combine(PathOperation.difference, a, b);

/// A four-pointed star: points at [r], waist at [waist].
Path _fourStar(double x, double y, double r, double waist, [double turn = 0]) {
  final pts = <double>[];
  for (var i = 0; i < 8; i++) {
    final a = turn - math.pi / 2 + i * math.pi / 4;
    final rr = i.isEven ? r : waist;
    pts
      ..add(x + math.cos(a) * rr)
      ..add(y + math.sin(a) * rr);
  }
  return _poly(pts);
}

/// A triangle of circumradius [r] about (x, y), point up (or down).
Path _tri(double x, double y, double r, {bool down = false}) {
  final pts = <double>[];
  for (var i = 0; i < 3; i++) {
    final a = (down ? math.pi / 2 : -math.pi / 2) + i * 2 * math.pi / 3;
    pts
      ..add(x + math.cos(a) * r)
      ..add(y + math.sin(a) * r);
  }
  return _poly(pts);
}

/// A lens: two arcs meeting at (±w, 0), [h] tall at the middle.
Path _lens(double w, double h) => Path()
  ..moveTo(-w, 0)
  ..quadraticBezierTo(0, -h * 2, w, 0)
  ..quadraticBezierTo(0, h * 2, -w, 0)
  ..close();

Path _buildSigil(ChartSigil s) {
  switch (s) {
    case ChartSigil.merge:
      // Two lineages overlapping.
      return _union([_ring(-0.34, 0, 0.6, 0.2), _ring(0.34, 0, 0.6, 0.2)]);
    case ChartSigil.lineage:
      return _union([
        _disc(0, -0.6, 0.24),
        _disc(-0.58, 0.58, 0.22),
        _disc(0.58, 0.58, 0.22),
        _bar(const Offset(0, -0.6), const Offset(-0.58, 0.58), 0.18, 0.12),
        _bar(const Offset(0, -0.6), const Offset(0.58, 0.58), 0.18, 0.12),
      ]);
    case ChartSigil.helix:
      // Two strands twisting, thinning where each turns away.
      Path strand(double phase) {
        final left = <double>[], right = <double>[];
        for (var i = 0; i <= 24; i++) {
          final t = -0.95 + i * 1.9 / 24;
          final a = t * math.pi * 1.25 + phase;
          final x = math.sin(a) * 0.48;
          final w = 0.06 + 0.1 * (0.5 + 0.5 * math.cos(a));
          left
            ..add(x - w)
            ..add(t);
          right
            ..add(x + w)
            ..add(t);
        }
        final pts = <double>[...left];
        for (var i = right.length - 2; i >= 0; i -= 2) {
          pts
            ..add(right[i])
            ..add(right[i + 1]);
        }
        return _poly(pts);
      }
      return _union([
        strand(0),
        strand(math.pi),
        for (final y in const [-0.62, 0.0, 0.62])
          _bar(Offset(-0.34, y), Offset(0.34, y), 0.09),
      ]);
    case ChartSigil.rise:
      // Fire's triangle with a mark climbing inside it.
      return _union([
        _minus(_tri(0, 0.12, 0.98), _tri(0, 0.22, 0.6)),
        _disc(0, 0.2, 0.14),
      ]);
    case ChartSigil.hourglass:
      return _union([
        _poly([-0.56, -0.74, 0.56, -0.74, 0.07, 0, -0.07, 0]),
        _poly([-0.07, 0, 0.07, 0, 0.56, 0.74, -0.56, 0.74]),
        _bar(const Offset(-0.74, -0.84), const Offset(0.74, -0.84), 0.16),
        _bar(const Offset(-0.74, 0.84), const Offset(0.74, 0.84), 0.16),
      ]);
    case ChartSigil.leaf:
      final m = Float64List(16)
        ..[0] = math.cos(-math.pi / 4)
        ..[1] = math.sin(-math.pi / 4)
        ..[4] = -math.sin(-math.pi / 4)
        ..[5] = math.cos(-math.pi / 4)
        ..[10] = 1
        ..[15] = 1;
      final blade = _lens(0.95, 0.34).transform(m);
      return _minus(
        blade,
        _bar(const Offset(-0.48, 0.48), const Offset(0.46, -0.46), 0.08),
      );
    case ChartSigil.bolt:
      return _poly([
        0.16,
        -0.98,
        -0.5,
        0.12,
        -0.04,
        0.12,
        -0.2,
        0.98,
        0.5,
        -0.16,
        0.04,
        -0.16,
      ]);
    case ChartSigil.eye:
      return _union([
        _minus(_lens(0.98, 0.42), _lens(0.72, 0.26)),
        _disc(0, 0, 0.24),
      ]);
    case ChartSigil.star:
      return _union([
        _fourStar(0, 0, 0.98, 0.22),
        _disc(0.62, -0.62, 0.11),
        _disc(-0.62, 0.62, 0.11),
      ]);
    case ChartSigil.chevrons:
      Path chevron(double x) => _poly([
        x - 0.34,
        -0.72,
        x + 0.12,
        -0.72,
        x + 0.52,
        0,
        x + 0.12,
        0.72,
        x - 0.34,
        0.72,
        x + 0.06,
        0,
      ]);
      return _union([chevron(-0.46), chevron(0.3)]);
    case ChartSigil.ascent:
      // Air's triangle, its bar across.
      return _union([
        _minus(_tri(0, 0.1, 0.98), _tri(0, 0.2, 0.58)),
        _bar(const Offset(-0.86, 0.12), const Offset(0.86, 0.12), 0.15),
      ]);
    case ChartSigil.flask:
      final body = _union([
        _disc(0, 0.34, 0.6),
        _poly([-0.18, -0.74, 0.18, -0.74, 0.2, 0, -0.2, 0]),
        _bar(const Offset(-0.32, -0.8), const Offset(0.32, -0.8), 0.14),
      ]);
      return _minus(body, _disc(0.16, 0.24, 0.16));
    case ChartSigil.spark:
      return _union([
        _fourStar(0, 0, 0.98, 0.2),
        _fourStar(0, 0, 0.58, 0.16, math.pi / 4),
      ]);
    case ChartSigil.coin:
      return _minus(
        _disc(0, 0, 0.9),
        _poly([0, -0.32, 0.32, 0, 0, 0.32, -0.32, 0]),
      );
    case ChartSigil.stack:
      Path lozenge(double y) =>
          _poly([-0.74, y, 0, y - 0.26, 0.74, y, 0, y + 0.26]);
      return _union([lozenge(-0.56), lozenge(0), lozenge(0.56)]);
    case ChartSigil.tag:
      return _minus(
        _poly([0, -0.98, 0.72, 0, 0, 0.98, -0.72, 0]),
        _disc(0, -0.4, 0.16),
      );
    case ChartSigil.tree:
      return _union([
        _tri(0, -0.12, 0.84),
        _bar(const Offset(0, 0.2), const Offset(0, 0.96), 0.2),
      ]);
    case ChartSigil.infinity:
      return _union([_ring(-0.44, 0, 0.46, 0.17), _ring(0.44, 0, 0.46, 0.17)]);
    case ChartSigil.flame:
      return Path()
        ..moveTo(0, -0.98)
        ..cubicTo(0.3, -0.5, 0.72, -0.18, 0.62, 0.34)
        ..cubicTo(0.54, 0.76, 0.24, 0.98, 0, 0.98)
        ..cubicTo(-0.24, 0.98, -0.54, 0.76, -0.62, 0.34)
        ..cubicTo(-0.68, 0.02, -0.4, -0.2, -0.3, -0.46)
        ..cubicTo(-0.14, -0.2, 0.04, -0.4, 0, -0.98)
        ..close();
  }
}

/// A sigil as a widget, for the lists and dialogs that sit over the chart.
class SigilPainter extends CustomPainter {
  const SigilPainter(this.sigil, this.color);
  final ChartSigil sigil;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(r);
    canvas.drawPath(sigilPath(sigil), Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SigilPainter old) =>
      old.sigil != sigil || old.color != color;
}

// ── the stone ───────────────────────────────────────────────────────────────

/// How a stone is lit.
enum StoneState { locked, open, owned }

/// A pointy-topped hexagon of circumradius [r] about [c].
Path hexPath(Offset c, double r) {
  final p = Path();
  for (var i = 0; i < 6; i++) {
    final a = -math.pi / 2 + i * math.pi / 3;
    final x = c.dx + math.cos(a) * r, y = c.dy + math.sin(a) * r;
    i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
  }
  return p..close();
}

/// One stone's geometry and gradients, shared by every node of its size,
/// tree and state.
class StoneArt {
  StoneArt._(this.center, this.radius, this.light, this.state)
    : crown = hexPath(center, radius),
      table = hexPath(center, radius * 0.52) {
    rim = Path.combine(
      PathOperation.difference,
      crown,
      hexPath(center + Offset(radius * 0.07, radius * 0.11), radius * 0.95),
    );
    final c = center, r = radius;
    final l = light;

    // The body: dark through, warmed at its heart by whatever light it holds.
    body = Paint()
      ..shader = switch (state) {
        StoneState.owned => ui.Gradient.radial(
          c,
          r,
          [
            l.essence.withValues(alpha: 0.95),
            Color.lerp(l.face, l.essence, 0.45)!,
            l.face,
            l.ink,
          ],
          const [0.0, 0.3, 0.62, 1.0],
        ),
        StoneState.open => ui.Gradient.radial(
          c,
          r,
          [Color.lerp(l.face, l.essence, 0.42)!, l.face, l.ink],
          const [0.0, 0.5, 1.0],
        ),
        StoneState.locked => ui.Gradient.radial(
          c - Offset(r * 0.3, r * 0.4),
          r * 1.4,
          [Color.lerp(l.face, const Color(0xFF15181D), 0.6)!, l.ink],
          const [0.0, 1.0],
        ),
      };

    // The crown's facets, each turned to the light by its own amount: the
    // upper left catches it, the lower right falls away. One sweep, hard
    // stops at the hexagon's corners.
    final hi = state == StoneState.locked ? 0.05 : 0.09;
    final sh = state == StoneState.owned ? 0.16 : 0.3;
    const white = Color(0xFFFFFFFF), black = Color(0xFF000000);
    final facetColors = [
      black.withValues(alpha: sh * 0.6), // 330→30, facing right
      black.withValues(alpha: sh * 0.6),
      black.withValues(alpha: sh), // 30→90, lower right
      black.withValues(alpha: sh),
      black.withValues(alpha: sh * 0.45), // 90→150, lower left
      black.withValues(alpha: sh * 0.45),
      white.withValues(alpha: hi * 0.5), // 150→210, left
      white.withValues(alpha: hi * 0.5),
      white.withValues(alpha: hi), // 210→270, upper left
      white.withValues(alpha: hi),
      white.withValues(alpha: hi * 0.3), // 270→330, upper right
      white.withValues(alpha: hi * 0.3),
      black.withValues(alpha: sh * 0.6), // 330→360
      black.withValues(alpha: sh * 0.6),
    ];
    const deg = 1 / 360;
    facets = Paint()
      ..shader = ui.Gradient.sweep(c, facetColors, const [
        0.0,
        30 * deg,
        30 * deg,
        90 * deg,
        90 * deg,
        150 * deg,
        150 * deg,
        210 * deg,
        210 * deg,
        270 * deg,
        270 * deg,
        330 * deg,
        330 * deg,
        1.0,
      ]);

    // The table: where the light pools.
    tablePaint = Paint()
      ..shader = switch (state) {
        StoneState.owned => ui.Gradient.radial(
          c - Offset(0, r * 0.05),
          r * 0.56,
          [l.hot, Color.lerp(l.hot, l.essence, 0.5)!, l.essence],
          const [0.0, 0.55, 1.0],
        ),
        StoneState.open => ui.Gradient.radial(
          c,
          r * 0.56,
          [
            l.essence.withValues(alpha: 0.5),
            Color.lerp(l.face, l.essence, 0.25)!,
          ],
          const [0.0, 1.0],
        ),
        StoneState.locked => ui.Gradient.linear(
          c - Offset(0, r * 0.52),
          c + Offset(0, r * 0.52),
          [Color.lerp(l.face, const Color(0xFF1A1D22), 0.5)!, l.ink],
        ),
      };

    // The edge that catches the light, brightest at the upper left.
    final rimAlpha = switch (state) {
      StoneState.owned => 0.95,
      StoneState.open => 0.75,
      StoneState.locked => 0.46,
    };
    final rimColor = state == StoneState.locked
        ? Color.lerp(l.rim, kChartMuted, 0.65)!
        : l.rim;
    rimPaint = Paint()
      ..shader = ui.Gradient.linear(
        c - Offset(r * 0.75, r * 0.9),
        c + Offset(r * 0.55, r * 0.7),
        [
          rimColor.withValues(alpha: rimAlpha),
          rimColor.withValues(alpha: rimAlpha * 0.35),
          rimColor.withValues(alpha: 0),
        ],
        const [0.0, 0.5, 1.0],
      );

    sigilColor = switch (state) {
      StoneState.owned => kChartVoid.withValues(alpha: 0.86),
      StoneState.open => kChartInk,
      StoneState.locked => kChartMuted.withValues(alpha: 0.6),
    };

    if (state == StoneState.owned) {
      pool = Paint()
        ..shader = ui.Gradient.radial(
          c,
          r * 2.1,
          [
            l.essence.withValues(alpha: 0.26),
            l.essence.withValues(alpha: 0.08),
            l.essence.withValues(alpha: 0),
          ],
          const [0.3, 0.6, 1.0],
        );
    }
  }

  static final Map<(ConstellationTree, StoneState, double, Offset), StoneArt>
  _cache = {};

  /// The shared art for a stone of [radius] in [tree] when [state], centred
  /// at [center] in its node's own space.
  static StoneArt of(
    ConstellationTree tree,
    StoneState state,
    double radius,
    Offset center,
  ) => _cache.putIfAbsent((
    tree,
    state,
    radius,
    center,
  ), () => StoneArt._(center, radius, treeLight(tree), state));

  final Offset center;
  final double radius;
  final TreeLight light;
  final StoneState state;

  final Path crown;
  final Path table;
  late final Path rim;
  late final Paint body;
  late final Paint facets;
  late final Paint tablePaint;
  late final Paint rimPaint;
  late final Color sigilColor;

  /// Light spilled round an owned stone.
  Paint? pool;

  /// An open stone's breath, in [steps] quantised strengths — a slow pulse
  /// reads the same in a dozen steps and reuses a dozen shaders.
  static const int breathSteps = 10;
  final Map<int, Paint> _breath = {};

  Paint breath(int step) => _breath.putIfAbsent(step, () {
    final k = step / (breathSteps - 1);
    return Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius * (1.9 + 0.3 * k),
        [
          light.essence.withValues(alpha: 0.12 + 0.16 * k),
          light.essence.withValues(alpha: 0.04 + 0.05 * k),
          light.essence.withValues(alpha: 0),
        ],
        const [0.3, 0.62, 1.0],
      );
  });

  /// The stone, without its glyph.
  void paint(Canvas canvas, {Paint? halo}) {
    if (halo != null) {
      canvas.drawCircle(center, radius * 2.2, halo);
    } else if (pool != null) {
      canvas.drawCircle(center, radius * 2.1, pool!);
    }
    canvas
      ..drawPath(crown, body)
      ..drawPath(crown, facets)
      ..drawPath(table, tablePaint)
      ..drawPath(rim, rimPaint);
  }
}

/// The flash of a stone igniting, by how far through it is. Shared.
final Map<(ConstellationTree, int), Paint> _flashes = {};

Paint igniteFlash(ConstellationTree tree, Offset c, double r, double fade) {
  final step = (fade.clamp(0.0, 1.0) * 8).round();
  return _flashes.putIfAbsent((tree, step), () {
    final l = treeLight(tree);
    final k = step / 8;
    return Paint()
      ..shader = ui.Gradient.radial(
        c,
        r * 1.6,
        [
          l.hot.withValues(alpha: 0.85 * k),
          l.essence.withValues(alpha: 0.35 * k),
          l.essence.withValues(alpha: 0),
        ],
        const [0.0, 0.4, 1.0],
      );
  });
}

// ── grains ──────────────────────────────────────────────────────────────────

/// Many grains drawn as few calls: each grain goes into a class (a tree and
/// a brightness), and each class is drawn once — a wide faint pass under a
/// narrow bright one, which at this size reads as a soft point of light.
class GrainBatch {
  GrainBatch(int classes)
    : _pts = List.generate(classes, (_) => Float32List(128)),
      _n = List.filled(classes, 0);

  final List<Float32List> _pts;
  final List<int> _n;

  static final Paint _paint = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void clear() => _n.fillRange(0, _n.length, 0);

  void add(int cls, double x, double y) {
    var buf = _pts[cls];
    final i = _n[cls] * 2;
    if (i + 2 > buf.length) {
      final grown = Float32List(buf.length * 2)..setAll(0, buf);
      _pts[cls] = buf = grown;
    }
    buf[i] = x;
    buf[i + 1] = y;
    _n[cls]++;
  }

  int count(int cls) => _n[cls];

  void dots(Canvas c, int cls, double diameter, Color color) {
    final n = _n[cls];
    if (n == 0 || color.a <= 0) return;
    _paint
      ..strokeWidth = diameter
      ..color = color;
    c.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(_pts[cls], 0, n * 2),
      _paint,
    );
  }

  /// The class's points taken in pairs as segments, [width] wide — the soft
  /// band of light under a stream of grains.
  void lines(Canvas c, int cls, double width, Color color) {
    final n = _n[cls] & ~1;
    if (n == 0 || color.a <= 0) return;
    _paint
      ..strokeWidth = width
      ..color = color;
    c.drawRawPoints(
      ui.PointMode.lines,
      Float32List.sublistView(_pts[cls], 0, n * 2),
      _paint,
    );
  }

  /// A soft grain: [diameter] across with a halo [glow] times as wide.
  void glow(Canvas c, int cls, double diameter, double glow, Color color) {
    dots(c, cls, diameter * glow, color.withValues(alpha: color.a * 0.16));
    dots(c, cls, diameter, color);
  }
}

final Map<(double, double, double), Path> _costStars = {};

/// The four-pointed star a price is counted in, at [r] about [c].
Path costStarPath(Offset c, double r) => _costStars.putIfAbsent((
  c.dx,
  c.dy,
  r,
), () => _fourStar(c.dx, c.dy, r, r * 0.3));
