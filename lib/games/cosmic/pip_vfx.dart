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
/// five material pieces plus the bounce notches.

final ui.Paint _paint = ui.Paint();
final ui.Paint _stroke = ui.Paint()
  ..style = ui.PaintingStyle.stroke
  ..strokeCap = ui.StrokeCap.round
  ..strokeJoin = ui.StrokeJoin.round;

enum _Head { barb, heavy, needle, prism }

_Head _headFor(String element) => switch (element) {
  'Lava' || 'Earth' || 'Mud' => _Head.heavy,
  'Blood' || 'Ice' || 'Lightning' => _Head.needle,
  'Crystal' || 'Light' => _Head.prism,
  _ => _Head.barb,
};

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
  final tint = ui.Color.lerp(elementColor(element), m.mid, 0.25)!;
  final vs = projectile.visualScale.clamp(0.72, 2.3).toDouble();
  final head = _headFor(element);
  final pulse = 0.85 + 0.15 * sin(time * 6.5 + projectile.life * 2.5);

  canvas.save();
  canvas.translate(position.dx, position.dy);
  canvas.rotate(projectile.angle);

  // Light thrown ahead of and around it, stretched along travel.
  canvas.save();
  canvas.scale(2.4, 1);
  vfxSpill(
    canvas,
    const ui.Offset(-1.5, 0),
    6.5 * vs,
    tint,
    (special ? 0.34 : 0.2) * pulse,
  );
  canvas.restore();

  // The trail: a tapered streak of the dart's own light.
  final trailLen = (special ? 34.0 : 15.0) * vs;
  final trailW = (special ? 4.2 : 2.6) * vs * (head == _Head.heavy ? 1.3 : 1);
  final trail = ui.Path()
    ..moveTo(0, -trailW / 2)
    ..quadraticBezierTo(-trailW * 1.5, -trailW / 2, -trailLen, 0)
    ..quadraticBezierTo(-trailW * 1.5, trailW / 2, 0, trailW / 2)
    ..close();
  _paint
    ..color = const ui.Color(0xFFFFFFFF)
    ..shader = ui.Gradient.linear(
      ui.Offset.zero,
      ui.Offset(-trailLen, 0),
      [
        ui.Color.lerp(tint, m.glint, 0.35)!.withValues(alpha: 0.7 * pulse),
        tint.withValues(alpha: 0.3 * pulse),
        tint.withValues(alpha: 0),
      ],
      const [0.0, 0.35, 1.0],
    );
  canvas.drawPath(trail, _paint);
  _paint.shader = null;

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

  _drawHead(canvas, head, element, m, tint, vs, time);
  canvas.restore();
}

void _drawHead(
  ui.Canvas canvas,
  _Head head,
  String element,
  VfxMaterial m,
  ui.Color tint,
  double vs,
  double time,
) {
  switch (head) {
    case _Head.barb:
      // Swept barb: point, out to the barbs, back to a notched tail.
      final len = 10.0 * vs, w = 3.8 * vs;
      final body = ui.Path()
        ..moveTo(len * 0.62, 0)
        ..lineTo(-len * 0.18, -w)
        ..lineTo(-len * 0.48, -w * 0.3)
        ..lineTo(-len * 0.3, 0)
        ..lineTo(-len * 0.48, w * 0.3)
        ..lineTo(-len * 0.18, w)
        ..close();
      vfxFillPath(canvas, body, tint, 0.95);
      // Lit upper flank, shadowed lower one — a solid, not a sticker.
      final lit = ui.Path()
        ..moveTo(len * 0.62, 0)
        ..lineTo(-len * 0.18, -w)
        ..lineTo(-len * 0.1, -w * 0.25)
        ..close();
      vfxFillPath(canvas, lit, m.glint, 0.75);
      final shade = ui.Path()
        ..moveTo(len * 0.62, 0)
        ..lineTo(-len * 0.18, w)
        ..lineTo(-len * 0.3, 0)
        ..close();
      vfxFillPath(canvas, shade, m.ink, 0.35);
    case _Head.heavy:
      // A knapped head — broad, faceted, heavy. Lava's glows in its seams.
      final len = 10.5 * vs, w = 5.0 * vs;
      final pts = [
        ui.Offset(len * 0.6, 0),
        ui.Offset(len * 0.05, -w),
        ui.Offset(-len * 0.45, -w * 0.55),
        ui.Offset(-len * 0.4, w * 0.5),
        ui.Offset(len * 0.05, w),
      ];
      final body = ui.Path()..addPolygon(pts, true);
      final molten = element == 'Lava';
      vfxFillPath(
        canvas,
        body,
        molten ? m.ink : ui.Color.lerp(m.ink, tint, 0.35)!,
        0.97,
      );
      final face = ui.Path()
        ..addPolygon([pts[0], pts[1], pts[2], ui.Offset.zero], true);
      vfxFillPath(canvas, face, molten ? m.mid : tint, 0.85);
      final edge = ui.Path()
        ..addPolygon([pts[0], pts[1], ui.Offset(len * 0.15, -w * 0.45)], true);
      vfxFillPath(canvas, edge, m.glint, molten ? 0.9 : 0.5);
      if (molten) {
        final glow = 0.6 + 0.4 * sin(time * 5);
        final seam = ui.Path()
          ..moveTo(len * 0.5, 0)
          ..lineTo(-len * 0.1, w * 0.2)
          ..lineTo(-len * 0.35, -w * 0.1);
        _stroke
          ..color = m.glint.withValues(alpha: 0.85 * glow)
          ..strokeWidth = 1.1 * vs;
        canvas.drawPath(seam, _stroke);
      }
    case _Head.needle:
      // Long and slim. Blood's swells into a bead behind the point.
      final len = 13.0 * vs, w = 2.4 * vs;
      final body = ui.Path()
        ..moveTo(len * 0.62, 0)
        ..quadraticBezierTo(0, -w, -len * 0.38, -w * 0.5)
        ..lineTo(-len * 0.3, 0)
        ..lineTo(-len * 0.38, w * 0.5)
        ..quadraticBezierTo(0, w, len * 0.62, 0)
        ..close();
      vfxFillPath(canvas, body, tint, 0.95);
      final lit = ui.Path()
        ..moveTo(len * 0.62, 0)
        ..quadraticBezierTo(0, -w, -len * 0.3, -w * 0.4)
        ..quadraticBezierTo(0, -w * 0.2, len * 0.62, 0)
        ..close();
      vfxFillPath(canvas, lit, m.glint, 0.8);
      if (element == 'Blood') {
        vfxFillPath(
          canvas,
          vfxDrop(ui.Offset(-len * 0.1, 0), w * 1.2, 0),
          m.mid,
          0.95,
        );
        _dot(canvas, ui.Offset(-len * 0.02, -w * 0.4), w * 0.35, m.glint, 0.7);
      }
    case _Head.prism:
      // A cut prism: two tones meeting on the axis, light on one face only.
      final len = 11.0 * vs, w = 4.0 * vs;
      final top = ui.Path()
        ..addPolygon([
          ui.Offset(len * 0.62, 0),
          ui.Offset(-len * 0.05, -w),
          ui.Offset(-len * 0.45, 0),
        ], true);
      final bottom = ui.Path()
        ..addPolygon([
          ui.Offset(len * 0.62, 0),
          ui.Offset(-len * 0.05, w),
          ui.Offset(-len * 0.45, 0),
        ], true);
      final catchLight = 0.6 + 0.4 * sin(time * 4);
      vfxFillPath(canvas, bottom, element == 'Light' ? tint : m.ink, 0.95);
      vfxFillPath(
        canvas,
        top,
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
    final step = (time * 18).floorToDouble();
    for (var b = 0; b < 2; b++) {
      final path = ui.Path()..moveTo(-4 * vs, 0);
      for (var k = 1; k <= 4; k++) {
        path.lineTo(
          -4 * vs - trailLen * 0.7 * k / 4,
          (vfxHash(step + b * 5 + k) - 0.5) * 9 * vs,
        );
      }
      _stroke
        ..color = m.light.withValues(alpha: 0.25)
        ..strokeWidth = 3.2 * vs;
      canvas.drawPath(path, _stroke);
      _stroke
        ..color = m.glint.withValues(alpha: 0.9)
        ..strokeWidth = 1.0 * vs;
      canvas.drawPath(path, _stroke);
    }
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
        vfxFillPath(canvas, vfxDrop(p, 1.8 * s, pi), m.mid, 0.8 * f);
        vfxFillPath(canvas, vfxDrop(p, 0.9 * s, pi), m.glint, 0.9 * f);
      case 'Lava':
        vfxFillPath(
          canvas,
          vfxDrop(p, 1.7 * s, pi + side * 0.5),
          m.glint,
          0.85 * f,
        );
      case 'Blood' || 'Poison':
        vfxFillPath(canvas, vfxDrop(p, 1.6 * s, pi), m.mid, 0.9 * f);
      case 'Water':
        vfxFillPath(
          canvas,
          vfxDrop(p, 1.5 * s, pi + side * 0.3),
          m.glint,
          0.65 * f,
        );
      case 'Ice':
        vfxFillPath(
          canvas,
          vfxShard(p, 3.2 * s, 0.8 * s, side * pi / 2 + pi * 0.2 * side),
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
        vfxFillPath(
          canvas,
          vfxBlob(p, 1.7 * s, i.toDouble(), n: 5, wobble: 0.3),
          m.ink,
          0.95 * f,
        );
        _dot(
          canvas,
          p + ui.Offset(-0.4 * s, -0.5 * s),
          0.6 * s,
          m.glint,
          0.5 * f,
        );
      case 'Mud':
        vfxFillPath(
          canvas,
          vfxBlob(p, 1.9 * s, i.toDouble(), n: 6, wobble: 0.3),
          m.mid,
          0.9 * f,
        );
      case 'Dust':
        vfxFillPath(
          canvas,
          vfxBlob(p, 1.1 * s, i.toDouble(), n: 5, wobble: 0.3),
          m.glint,
          0.75 * f,
        );
      case 'Steam' || 'Spirit':
        vfxSpill(canvas, p, (2.5 + 5 * t) * vs, m.glint, 0.4 * f);
      case 'Plant':
        vfxFillPath(
          canvas,
          vfxLeaf(p, 3.6 * s, pi + side * 0.8 + time * 3),
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
