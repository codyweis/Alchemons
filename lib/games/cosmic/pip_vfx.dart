import 'dart:math';
import 'dart:ui' as ui;

import 'cosmic_data.dart';
import 'horn_vfx.dart';
import 'vfx_shapes.dart';

/// Pip's darts and what they leave behind. Shared by every game mode.
///
/// A pip is a small, fast, ricocheting thing, so the dart has one job: read
/// as a keen point travelling somewhere, and say how many bounces it has
/// left. The old art hung symbols on it — spoked frost circles, orbiting
/// "atom" dots, a clock face of sparks, hollow rings — and flew Lava, Blood
/// and Earth as round balls. Here every element is a dart; the element is its
/// material (a molten head, a flint head, a blood needle, a crystal prism)
/// and what streams off it, drawn as filled pieces, never as glyphs.
///
/// Budget per dart: a gradient trail, a stretched bloom, the head, and at most
/// five material pieces plus the bounce notches. A basic fires three at a
/// time, all the time, so nothing a dart draws is built per frame: the trail
/// and the heads are unit paths cached once (drawn scaled by the dart's
/// size), and the trail's gradient is cached per element at unit length with
/// its pulse on the paint's alpha.

final ui.Paint _paint = ui.Paint();

enum _Head { barb, heavy, needle, prism }

_Head _headFor(String element) => switch (element) {
  'Lava' || 'Earth' || 'Mud' => _Head.heavy,
  'Blood' || 'Ice' || 'Lightning' => _Head.needle,
  'Crystal' || 'Light' => _Head.prism,
  _ => _Head.barb,
};

/// Pip Steam's cloud, worn on the pip (canvas at its centre) while its
/// attack-speed ramp climbs: puffs rising off the body and billowing as
/// they go — never circling it — each a soft pool with a lit top, thicker
/// and brighter as [progress] (0 → 1, the ramp toward its +300% peak)
/// climbs, and vapour grains lifting through them. Shared by survival and
/// open space. (It was four faint pools of steam's light at 0.16 alpha: on
/// the dark arena the pip looked bare.)
void drawPipSteamCloud({
  required ui.Canvas canvas,
  required double progress,
  required double time,
}) {
  final p = progress.clamp(0.0, 1.0);
  final m = vfxMaterial('Steam');
  vfxSpill(canvas, const ui.Offset(0, -6), 22 + 10 * p, m.light, 0.1 + 0.12 * p);
  // Puffs leave from the flanks and roll up and outward, so they show round
  // the body rather than hiding behind it.
  for (var i = 0; i < 4; i++) {
    final ph = (time * 0.45 + i * 0.25) % 1.0;
    final side = i.isEven ? -1.0 : 1.0;
    final c = ui.Offset(
      side * (16.0 + 12.0 * ph + 2.0 * i) + sin(time * 1.1 + i * 2.3) * 3.0,
      -2.0 - ph * 38.0,
    );
    final r = 10.0 + 8.0 * ph + p * 5.0;
    final a = sin(ph * pi);
    vfxSpill(canvas, c, r, m.light, (0.36 + 0.3 * p) * a);
    vfxSpill(
      canvas,
      c - ui.Offset(0, r * 0.3),
      r * 0.5,
      m.glint,
      (0.16 + 0.2 * p) * a,
    );
  }
  vfxGrainsDiscard();
  for (var i = 0; i < 5; i++) {
    final ph = (time * 0.6 + i * 0.2 + vfxHash(i * 3.1)) % 1.0;
    vfxGrain((vfxHash(i * 5.7) - 0.5) * 22 + sin(time + i) * 2, 2 - ph * 30);
  }
  vfxGrainsFlush(canvas, 2.0, m.glint, 0.3 + 0.35 * p);
}

/// A unit-length trail (it runs from the head at the origin back to x = -1)
/// [w] wide at the head.
ui.Path _unitTrail(double w) => ui.Path()
  ..moveTo(0, -w / 2)
  ..quadraticBezierTo(-w * 1.5, -w / 2, -1, 0)
  ..quadraticBezierTo(-w * 1.5, w / 2, 0, w / 2)
  ..close();

/// The trails' width over their length: basic, basic heavy, special,
/// special heavy (the dart's size scales both alike).
final List<ui.Path> _trailPaths = [
  _unitTrail(2.6 / 15.0),
  _unitTrail(2.6 * 1.3 / 15.0),
  _unitTrail(5.0 / 52.0),
  _unitTrail(5.0 * 1.3 / 52.0),
];

final Map<String, ui.Shader> _trailShaders = {};

/// The trail's light along a unit length, at full strength, per element.
ui.Shader _trailShader(String element, VfxMaterial m, ui.Color tint) {
  final hit = _trailShaders[element];
  if (hit != null) return hit;
  if (_trailShaders.length >= 32) _trailShaders.clear();
  return _trailShaders[element] = ui.Gradient.linear(
    ui.Offset.zero,
    const ui.Offset(-1, 0),
    [
      ui.Color.lerp(tint, m.glint, 0.35)!.withValues(alpha: 0.7),
      tint.withValues(alpha: 0.3),
      tint.withValues(alpha: 0),
    ],
    const [0.0, 0.35, 1.0],
  );
}

/// One pip dart at [position]. [special] darts get the long trail and the
/// bounce notches; basics share the silhouette but stay light.
void drawPipDart({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required double time,
  required bool special,
}) {
  final element = projectile.element ?? 'Fire';
  final m = vfxMaterial(element);
  // The material's lit colour leaned toward the element colour: ~30% for
  // the glowing elements so they don't go pale, less for the rest.
  final tint = ui.Color.lerp(
    m.light,
    elementColor(element),
    kVfxGlowingElements.contains(element) ? 0.30 : 0.18,
  )!;
  final vs = projectile.visualScale.clamp(0.72, 2.3).toDouble();
  final head = _headFor(element);
  final pulse = 0.85 + 0.15 * sin(time * 6.5 + projectile.life * 2.5);

  canvas.save();
  canvas.translate(position.dx, position.dy);
  canvas.rotate(projectile.angle);

  // Light thrown ahead of and around it, stretched along travel.
  // A basic fires three at a time, all the time: it keeps the silhouette and
  // the streak and leaves the spill to the special.
  // A special is still one small dart (its hit is the dart), so its
  // presence comes from what it carries, not a bigger head: a brighter pool
  // of light stretched along its flight and a long wake of its own light
  // that shows the line it ricochets along.
  if (special) {
    canvas.save();
    canvas.scale(2.6, 1);
    vfxSpill(canvas, const ui.Offset(-2.5, 0), 8.5 * vs, tint, 0.42 * pulse);
    canvas.restore();
  }

  // The trail: a tapered streak of the dart's own light, trailLen long. Its
  // width is a fixed share of its length per kind of dart, so it is one of
  // four unit streaks drawn scaled; the pulse rides on the paint's alpha.
  final trailLen = (special ? 52.0 : 15.0) * vs;
  final heavy = head == _Head.heavy;
  canvas.save();
  canvas.scale(trailLen);
  _paint
    ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: pulse)
    ..shader = _trailShader(element, m, tint);
  canvas.drawPath(_trailPaths[(special ? 2 : 0) + (heavy ? 1 : 0)], _paint);
  _paint.shader = null;
  canvas.restore();

  if (special) {
    _drawTrailMaterial(
      canvas,
      element,
      m,
      tint,
      trailLen,
      vs,
      time,
      projectile.life,
    );
    // How much ricochet is left: filled notches behind the head, one per
    // banked bounce, spent as it chains.
    final banked = projectile.bounceCount.clamp(0, 5);
    for (var i = 0; i < banked; i++) {
      final x = -(8.0 + i * 4.4) * vs;
      vfxFillPath(
        canvas,
        vfxCrescent(
          ui.Offset(x - 3.2 * vs, 0),
          (3.4 - i * 0.25) * vs,
          1.1 * vs,
          0,
          1.9,
        ),
        m.glint,
        (0.7 - i * 0.1) * pulse,
      );
    }
  }

  // The head is drawn from unit paths, so the canvas carries the size.
  canvas.scale(vs);
  _drawHead(canvas, head, element, m, tint, time);
  canvas.restore();
}

// The heads at unit size (vs = 1), built once: [_drawHead] draws them with
// the canvas already scaled by the dart's size.

// Swept barb: point, out to the barbs, back to a notched tail.
const double _barbLen = 10.0, _barbW = 3.8;
final ui.Path _barbBody = ui.Path()
  ..moveTo(_barbLen * 0.62, 0)
  ..lineTo(-_barbLen * 0.18, -_barbW)
  ..lineTo(-_barbLen * 0.48, -_barbW * 0.3)
  ..lineTo(-_barbLen * 0.3, 0)
  ..lineTo(-_barbLen * 0.48, _barbW * 0.3)
  ..lineTo(-_barbLen * 0.18, _barbW)
  ..close();
final ui.Path _barbLit = ui.Path()
  ..moveTo(_barbLen * 0.62, 0)
  ..lineTo(-_barbLen * 0.18, -_barbW)
  ..lineTo(-_barbLen * 0.1, -_barbW * 0.25)
  ..close();
final ui.Path _barbShade = ui.Path()
  ..moveTo(_barbLen * 0.62, 0)
  ..lineTo(-_barbLen * 0.18, _barbW)
  ..lineTo(-_barbLen * 0.3, 0)
  ..close();

// A knapped head — broad, faceted, heavy.
const double _heavyLen = 10.5, _heavyW = 5.0;
const List<ui.Offset> _heavyPts = [
  ui.Offset(_heavyLen * 0.6, 0),
  ui.Offset(_heavyLen * 0.05, -_heavyW),
  ui.Offset(-_heavyLen * 0.45, -_heavyW * 0.55),
  ui.Offset(-_heavyLen * 0.4, _heavyW * 0.5),
  ui.Offset(_heavyLen * 0.05, _heavyW),
];
final ui.Path _heavyBody = ui.Path()..addPolygon(_heavyPts, true);
final ui.Path _heavyFace = ui.Path()
  ..addPolygon([
    _heavyPts[0],
    _heavyPts[1],
    _heavyPts[2],
    ui.Offset.zero,
  ], true);
final ui.Path _heavyEdge = ui.Path()
  ..addPolygon([
    _heavyPts[0],
    _heavyPts[1],
    const ui.Offset(_heavyLen * 0.15, -_heavyW * 0.45),
  ], true);
// Lava's seam: a filled sliver of molten light that swells in the middle
// and pinches out at both ends, not a stroked line.
final ui.Path _heavySeam = vfxLensRibbon(
  vfxPolylineSpine(const [
    ui.Offset(_heavyLen * 0.5, 0),
    ui.Offset(-_heavyLen * 0.1, _heavyW * 0.2),
    ui.Offset(-_heavyLen * 0.35, -_heavyW * 0.1),
  ]),
  1.5,
  taper: 0.4,
);

// Long and slim.
const double _needleLen = 13.0, _needleW = 2.4;
final ui.Path _needleBody = ui.Path()
  ..moveTo(_needleLen * 0.62, 0)
  ..quadraticBezierTo(0, -_needleW, -_needleLen * 0.38, -_needleW * 0.5)
  ..lineTo(-_needleLen * 0.3, 0)
  ..lineTo(-_needleLen * 0.38, _needleW * 0.5)
  ..quadraticBezierTo(0, _needleW, _needleLen * 0.62, 0)
  ..close();
final ui.Path _needleLit = ui.Path()
  ..moveTo(_needleLen * 0.62, 0)
  ..quadraticBezierTo(0, -_needleW, -_needleLen * 0.3, -_needleW * 0.4)
  ..quadraticBezierTo(0, -_needleW * 0.2, _needleLen * 0.62, 0)
  ..close();

// A cut prism: two tones meeting on the axis.
const double _prismLen = 11.0, _prismW = 4.0;
final ui.Path _prismTop = ui.Path()
  ..addPolygon(const [
    ui.Offset(_prismLen * 0.62, 0),
    ui.Offset(-_prismLen * 0.05, -_prismW),
    ui.Offset(-_prismLen * 0.45, 0),
  ], true);
final ui.Path _prismBottom = ui.Path()
  ..addPolygon(const [
    ui.Offset(_prismLen * 0.62, 0),
    ui.Offset(-_prismLen * 0.05, _prismW),
    ui.Offset(-_prismLen * 0.45, 0),
  ], true);

/// The head, in unit coordinates (the caller has scaled the canvas).
void _drawHead(
  ui.Canvas canvas,
  _Head head,
  String element,
  VfxMaterial m,
  ui.Color tint,
  double time,
) {
  switch (head) {
    case _Head.barb:
      vfxFillPath(canvas, _barbBody, tint, 0.95);
      // Lit upper flank, shadowed lower one — a solid, not a sticker.
      vfxFillPath(canvas, _barbLit, m.glint, 0.75);
      vfxFillPath(canvas, _barbShade, m.ink, 0.35);
    case _Head.heavy:
      // Lava's glows in its seams.
      final molten = element == 'Lava';
      vfxFillPath(
        canvas,
        _heavyBody,
        molten ? m.ink : ui.Color.lerp(m.ink, tint, 0.35)!,
        0.97,
      );
      vfxFillPath(canvas, _heavyFace, molten ? m.mid : tint, 0.85);
      vfxFillPath(canvas, _heavyEdge, m.glint, molten ? 0.9 : 0.5);
      if (molten) {
        final glow = 0.6 + 0.4 * sin(time * 5);
        vfxFillPath(canvas, _heavySeam, m.glint, 0.85 * glow);
      }
    case _Head.needle:
      // Blood's swells into a bead behind the point.
      vfxFillPath(canvas, _needleBody, tint, 0.95);
      vfxFillPath(canvas, _needleLit, m.glint, 0.8);
      if (element == 'Blood') {
        vfxFillDrop(
          canvas,
          const ui.Offset(-_needleLen * 0.1, 0),
          _needleW * 1.2,
          0,
          m.mid,
          0.95,
        );
        _dot(
          canvas,
          const ui.Offset(-_needleLen * 0.02, -_needleW * 0.4),
          _needleW * 0.35,
          m.glint,
          0.7,
        );
      }
    case _Head.prism:
      // Light on one face only.
      final catchLight = 0.6 + 0.4 * sin(time * 4);
      vfxFillPath(
        canvas,
        _prismBottom,
        element == 'Light' ? tint : m.ink,
        0.95,
      );
      vfxFillPath(
        canvas,
        _prismTop,
        ui.Color.lerp(tint, m.glint, 0.5 * catchLight)!,
        0.95,
      );
  }
}

void _dot(ui.Canvas canvas, ui.Offset c, double r, ui.Color color, double a) {
  if (a <= 0.004) return;
  _paint
    ..shader = null
    ..color = color.withValues(alpha: a.clamp(0.0, 1.0));
  canvas.drawCircle(c, r, _paint);
}

/// What streams off a special dart: its material, carried back along the
/// trail and shed as it goes.
void _drawTrailMaterial(
  ui.Canvas canvas,
  String element,
  VfxMaterial m,
  ui.Color tint,
  double trailLen,
  double vs,
  double time,
  double life,
) {
  if (element == 'Lightning') {
    // Two arcs streaming off the needle. Their bends ease from one hashed
    // pose to the next a couple of times a second instead of snapping
    // eighteen times a second, the path curves through them rather than
    // zig-zagging, and both are filled lens ribbons sharing a faint wide
    // band and a lit core: two fills.
    final glow = ui.Path();
    final core = ui.Path();
    final corners = <ui.Offset>[];
    final arc = <ui.Offset>[];
    // One arc per dart: a volley of seven arrives bunched, and two bright
    // arcs each read as a fan of white hairlines.
    corners
      ..clear()
      ..add(ui.Offset(-4 * vs, 0));
    for (var k = 1; k <= 4; k++) {
      corners.add(
        ui.Offset(
          -4 * vs - trailLen * 0.7 * k / 4,
          (vfxGlide(k * 1.0, time, 2.6) - 0.5) * 7 * vs,
        ),
      );
    }
    vfxCurveSpine(corners, perSegment: 3, into: arc..clear());
    vfxLensRibbon(arc, 5.0 * vs, taper: 0.15, taperEnd: 0.6, into: glow);
    vfxLensRibbon(arc, 1.9 * vs, taper: 0.15, taperEnd: 0.6, into: core);
    vfxFillPath(canvas, glow, m.light, 0.26);
    vfxFillPath(canvas, core, ui.Color.lerp(m.glint, tint, 0.35)!, 0.8);
    return;
  }
  const n = 5;
  for (var i = 0; i < n; i++) {
    final t = (time * 2.2 + i / n + life * 0.37) % 1.0;
    final side = i.isEven ? 1.0 : -1.0;
    final x = -(6.0 * vs + trailLen * 0.85 * t);
    final y = side * vs * (1.0 + 4.5 * t) * (0.5 + 0.5 * vfxHash(i * 1.3));
    final p = ui.Offset(x, y);
    final f = 1 - t;
    final s = vs * (0.8 + 0.5 * f);
    switch (element) {
      case 'Fire':
        vfxFillDrop(canvas, p, 1.8 * s, pi, m.mid, 0.8 * f);
        vfxFillDrop(canvas, p, 0.9 * s, pi, m.glint, 0.9 * f);
      case 'Lava':
        vfxFillDrop(canvas, p, 1.7 * s, pi + side * 0.5, m.glint, 0.85 * f);
      case 'Blood' || 'Poison':
        vfxFillDrop(canvas, p, 1.6 * s, pi, m.mid, 0.9 * f);
      case 'Water':
        vfxFillDrop(canvas, p, 1.5 * s, pi + side * 0.3, m.glint, 0.65 * f);
      case 'Ice':
        vfxFillShard(
          canvas,
          p,
          3.2 * s,
          0.8 * s,
          side * pi / 2 + pi * 0.2 * side,
          m.glint,
          0.75 * f,
        );
      case 'Crystal' || 'Light':
        final gem = ui.Path()
          ..addPolygon([
            p + ui.Offset(2 * s, 0),
            p + ui.Offset(0, -1.3 * s),
            p + ui.Offset(-2 * s, 0),
            p + ui.Offset(0, 1.3 * s),
          ], true);
        vfxFillPath(canvas, gem, m.glint, 0.7 * f);
      case 'Earth':
        vfxFillBlob(canvas, p, 1.7 * s, i, m.ink, 0.95 * f, n: 5, wobble: 0.3);
        _dot(
          canvas,
          p + ui.Offset(-0.4 * s, -0.5 * s),
          0.6 * s,
          m.glint,
          0.5 * f,
        );
      case 'Mud':
        vfxFillBlob(canvas, p, 1.9 * s, i, m.mid, 0.9 * f, n: 6, wobble: 0.3);
      case 'Dust':
        vfxFillBlob(
          canvas,
          p,
          1.1 * s,
          i,
          m.glint,
          0.75 * f,
          n: 5,
          wobble: 0.3,
        );
      case 'Steam' || 'Spirit':
        vfxSpill(canvas, p, (2.5 + 5 * t) * vs, m.glint, 0.4 * f);
      case 'Plant':
        vfxFillLeaf(
          canvas,
          p,
          3.6 * s,
          pi + side * 0.8 + time * 3,
          m.mid,
          0.9 * f,
        );
      case 'Air':
        vfxFillPath(
          canvas,
          vfxCrescent(p, 3.2 * s, 0.9 * s, 0, 1.6),
          m.glint,
          0.5 * f,
        );
      default:
        _dot(canvas, p, 1.0 * s, m.glint, 0.6 * f);
    }
  }
}

/// Pip's leftovers on the ground: Fire's kill pool, Dust's slowing cloud,
/// Crystal's taunt beacon, Dark's black hole, Poison's vein between hits and
/// the mud a tagged enemy trails. Returns false for anything else.
bool drawPipGroundVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required double time,
}) {
  if (projectile.abilityFamily != 'pip' || !projectile.stationary) return false;
  final element = projectile.element;
  if (element == null) return false;
  final m = vfxMaterial(element);
  final seed = (position.dx * 0.037 + position.dy * 0.021) % 61;
  final fade = (projectile.life / 0.5).clamp(0.0, 1.0);
  final r = projectile.effectRadius > 0 ? projectile.effectRadius : 40.0;
  switch (element) {
    case 'Fire':
      drawVfxBurningGround(canvas, position, m, r * 1.1, seed, time);
    case 'Dark':
      drawVfxVoid(canvas, position, m, r * 0.5, seed, time);
    case 'Poison' || 'Mud':
      drawHornTrailPatch(
        canvas: canvas,
        element: element,
        position: position,
        radius: r * (element == 'Poison' ? 0.95 : 0.75),
        time: time,
        fade: fade,
      );
    case 'Dust':
      _drawDustCloud(canvas, position, m, r * 0.7, seed, time, fade);
    case 'Crystal':
      _drawBeacon(canvas, position, m, projectile, seed, time);
    default:
      return false;
  }
  return true;
}

void _drawDustCloud(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double r,
  double seed,
  double time,
  double fade,
) {
  vfxSpill(canvas, c, r * 1.15, m.light, 0.14 * fade);
  for (var i = 0; i < 5; i++) {
    final a = i * 2.399 + seed + time * 0.12;
    final p = c + vfxPolar(a, r * 0.38);
    final pr = r * (0.34 + 0.1 * sin(time * 0.8 + i));
    vfxFillPath(
      canvas,
      vfxBlob(p, pr, seed + i + time * 0.15, n: 9, wobble: 0.14),
      m.mid,
      0.2 * fade,
    );
    vfxFillPath(
      canvas,
      vfxBlob(
        p + ui.Offset(0, -pr * 0.15),
        pr * 0.7,
        seed + i * 3 + time * 0.15,
        n: 8,
        wobble: 0.16,
      ),
      m.glint,
      0.09 * fade,
    );
  }
  for (var i = 0; i < 9; i++) {
    final a = time * (0.9 + vfxHash(seed + i)) + i * 0.7;
    _dot(
      canvas,
      c + vfxPolar(a, r * (0.2 + 0.6 * vfxHash(seed + i * 2))),
      1.1,
      m.glint,
      0.45 * fade,
    );
  }
}

void _drawBeacon(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  Projectile p,
  double seed,
  double time,
) {
  final r = max(14.0, p.effectRadius * 0.55);
  // The pull: light drawing in toward the crystal on a slow beat, so the
  // taunt reads as a lure without a ring drawn round it.
  final beat = (time * 0.7 + seed) % 1.0;
  vfxSoftRing(
    canvas,
    c,
    r * (3.2 - 2.4 * beat),
    r * 0.5,
    m.light,
    0.1 * sin(beat * pi),
  );
  vfxSpill(canvas, c, r * 1.8, m.light, 0.22);
  // A small cluster of upright shards.
  for (var i = 0; i < 4; i++) {
    final x = (i - 1.5) * r * 0.32 + (vfxHash(seed + i) - 0.5) * r * 0.2;
    final h =
        r *
        (0.7 + 0.6 * vfxHash(seed + i * 2.7)) *
        (i == 1 || i == 2 ? 1.3 : 0.9);
    final lean = (vfxHash(seed + i * 4.1) - 0.5) * r * 0.3;
    final base = c + ui.Offset(x, r * 0.3);
    final tip = base + ui.Offset(lean, -h);
    final w = r * 0.16;
    final shard = ui.Path()
      ..addPolygon([
        base + ui.Offset(-w, 0),
        tip,
        base + ui.Offset(w, 0),
      ], true);
    vfxFillPath(canvas, shard, m.ink, 0.95);
    final face = ui.Path()
      ..addPolygon([base, tip, base + ui.Offset(w, 0)], true);
    final glint = 0.5 + 0.5 * sin(time * 2.2 + i * 1.7);
    vfxFillPath(
      canvas,
      face,
      ui.Color.lerp(m.mid, m.glint, 0.4 * glint)!,
      0.85,
    );
  }
}
