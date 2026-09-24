import 'dart:math';
import 'dart:ui' as ui;

import 'cosmic_data.dart';
import 'horn_vfx.dart';
import 'vfx_shapes.dart';

/// Kin's art: each kin's signature piece, what shows on the kin while its
/// support is running, the kin laser and its charge, and the blessing and
/// shield every family shares. Used by survival, open space and dungeons.
///
/// Kin are the rarest creatures and each is build-defining, but their pieces
/// were drawn as whatever generic ground zone they happened to fall into: an
/// Earth wall as a dotted arc, a rain cloud as a pool, an updraft as a flat
/// disc, the growing Spirit wisp as the same stack of circles at every tier.
/// Everything here is the same material language as the other families — muted
/// materials, filled tapered shapes, light pooled through gradients — and each
/// piece is drawn as the thing it is.

final ui.Paint _paint = ui.Paint();
final ui.Paint _stroke = ui.Paint()
  ..style = ui.PaintingStyle.stroke
  ..strokeCap = ui.StrokeCap.round
  ..strokeJoin = ui.StrokeJoin.round;

void _dot(ui.Canvas canvas, ui.Offset c, double r, ui.Color color, double a) {
  if (a <= 0.004) return;
  _paint
    ..shader = null
    ..color = color.withValues(alpha: a.clamp(0.0, 1.0));
  canvas.drawCircle(c, r, _paint);
}

/// A faceted stone: dark body, one lit face, a glint on its edge.
void _stone(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  double seed,
  VfxMaterial m, {
  double squash = 0.8,
}) {
  final pts = <ui.Offset>[];
  for (var k = 0; k < 6; k++) {
    final a = k * pi / 3 + (vfxHash(seed + k) - 0.5) * 0.5;
    final rr = r * (0.75 + 0.35 * vfxHash(seed + k * 2.3));
    pts.add(c + ui.Offset(cos(a) * rr, sin(a) * rr * squash));
  }
  vfxFillPath(canvas, ui.Path()..addPolygon(pts, true), m.ink, 0.95);
  vfxFillPath(
    canvas,
    ui.Path()..addPolygon([c, pts[3], pts[4], pts[5]], true),
    m.mid,
    0.8,
  );
  vfxFillPath(
    canvas,
    ui.Path()..addPolygon([pts[4], pts[5], c + (pts[5] - c) * 0.5], true),
    m.glint,
    0.35,
  );
}

double _seed(Projectile p, ui.Offset at) =>
    (at.dx * 0.031 + at.dy * 0.017 + p.orbitAngle * 3.1) % 53;

// ─────────────────────────────────────────────────────────────────────────
// Signature pieces
// ─────────────────────────────────────────────────────────────────────────

/// Paints a kin's signature piece — the Spirit wisp, the Light and Crystal
/// escorts, the Earth wall, rain cloud, updraft, dust banks and mud tracks.
/// Returns false for anything that isn't one (Plant's garden and Poison's
/// darts keep their own art).
bool drawKinPieceVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required double time,
}) {
  if (projectile.abilityFamily != 'kin') {
    // Kin escorts are also recognised by style alone: older spawns leave
    // the family blank.
    if (projectile.visualStyle != ProjectileVisualStyle.kinOrbital) {
      return false;
    }
  }
  final element = projectile.element;
  if (element == null) return false;
  final m = vfxMaterial(element);
  final seed = _seed(projectile, position);

  if (element == 'Spirit' &&
      projectile.followSourceCompanion &&
      projectile.abilityFamily == 'kin') {
    _drawWisp(
      canvas,
      position,
      m,
      projectile.effectCount.clamp(1, 4),
      time,
      seed,
    );
    return true;
  }
  if (projectile.visualStyle == ProjectileVisualStyle.kinOrbital) {
    _drawEscort(canvas, projectile, position, m, element, time, seed);
    return true;
  }
  if (!projectile.stationary ||
      projectile.visualStyle != ProjectileVisualStyle.sigil) {
    return false;
  }
  final fade = (projectile.life / 0.6).clamp(0.0, 1.0);
  final r = projectile.effectRadius > 0 ? projectile.effectRadius : 40.0;
  switch (element) {
    case 'Earth':
      _drawWallSection(canvas, position, m, seed, fade);
    case 'Water':
      _drawRainCloud(canvas, position, m, r, seed, time, fade);
    case 'Air':
      _drawUpdraft(canvas, position, m, r, seed, time, fade);
    case 'Dust':
      _drawDustBank(canvas, position, m, r, seed, time, fade);
    case 'Mud':
      drawHornTrailPatch(
        canvas: canvas,
        element: 'Mud',
        position: position,
        radius: r * 0.7,
        time: time,
        fade: fade,
      );
    default:
      return false;
  }
  return true;
}

/// The Spirit wisp, visibly growing in form — not just in size — tier by
/// tier: a flicker, then a veiled soul that draws the eye (taunt), then one
/// with motes it throws (attack), then a crowned one that feeds its kin.
void _drawWisp(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  int tier,
  double time,
  double seed,
) {
  final s = 1.0 + 0.28 * (tier - 1);
  final bob = sin(time * 1.7 + seed) * 2.0;
  final at = c + ui.Offset(0, bob);
  vfxSpill(canvas, c, 16 * s, m.light, 0.18 + 0.05 * tier);
  if (tier >= 2) {
    // A veil trailing off it — the lure.
    final spine = [
      for (var k = 0; k <= 8; k++)
        at +
            ui.Offset(
              sin(time * 3 + k * 0.7 + seed) * 3.0 * k / 8,
              5 * s + 20 * s * k / 8,
            ),
    ];
    vfxFillPath(canvas, vfxRibbon(spine, 9 * s, 0.6), m.mid, 0.32);
    vfxFillPath(canvas, vfxRibbon(spine, 4 * s, 0.4), m.glint, 0.22);
    // Slow pull of light toward it: the taunt.
    final beat = (time * 0.6 + seed) % 1.0;
    vfxSoftRing(
      canvas,
      c,
      (46 - 30 * beat) * s,
      8 * s,
      m.light,
      0.06 * sin(beat * pi),
    );
  }
  // The flame itself.
  final lean = pi / 2 + sin(time * 2.3 + seed) * 0.12;
  final flicker = 0.9 + 0.1 * sin(time * 7.1 + seed);
  vfxFillPath(canvas, vfxDrop(at, 5.5 * s * flicker, lean), m.mid, 0.55);
  vfxFillPath(
    canvas,
    vfxDrop(at + ui.Offset(0, 1), 3.2 * s * flicker, lean),
    m.glint,
    0.85,
  );
  _dot(
    canvas,
    at + ui.Offset(0, 1.5),
    1.3 * s,
    const ui.Color(0xFFFFFFFF),
    0.9,
  );
  if (tier >= 3) {
    // Motes it throws.
    for (var i = 0; i < 2; i++) {
      final a = time * 2.4 + i * pi + seed;
      final p = at + ui.Offset(cos(a) * 11 * s, sin(a) * 5 * s);
      vfxFillPath(canvas, vfxDrop(p, 1.8 * s, a + pi / 2), m.glint, 0.75);
    }
  }
  if (tier >= 4) {
    // A crown of light over it.
    vfxFillPath(
      canvas,
      vfxCrescent(at + ui.Offset(0, -2 * s), 8 * s, 2.2 * s, -pi / 2, 2.0),
      m.glint,
      0.55,
    );
    vfxSpill(canvas, at, 8 * s, m.glint, 0.35);
  }
}

/// Light's lanterns and Crystal's refractors, big enough to read as guards.
void _drawEscort(
  ui.Canvas canvas,
  Projectile p,
  ui.Offset c,
  VfxMaterial m,
  String element,
  double time,
  double seed,
) {
  final vs = p.visualScale.clamp(0.8, 2.4).toDouble();
  if (element == 'Crystal') {
    // A faceted refractor shard, turning; brighter while it still has
    // charges to throw back.
    final charged = p.interceptCharges > 0 ? 1.0 : 0.45;
    final r = 10.0 * vs;
    final spin = time * 1.6 + seed;
    vfxSpill(canvas, c, r * 2.6, m.light, 0.22 * charged);
    final top = <ui.Offset>[
      c + vfxPolar(spin, r * 1.2),
      c + vfxPolar(spin + 2.2, r * 0.7),
      c + vfxPolar(spin + pi, r * 1.0),
    ];
    final bottom = <ui.Offset>[
      c + vfxPolar(spin, r * 1.2),
      c + vfxPolar(spin - 2.2, r * 0.7),
      c + vfxPolar(spin + pi, r * 1.0),
    ];
    vfxFillPath(canvas, ui.Path()..addPolygon(bottom, true), m.ink, 0.95);
    vfxFillPath(
      canvas,
      ui.Path()..addPolygon(top, true),
      ui.Color.lerp(m.mid, m.glint, 0.45 * charged)!,
      0.95,
    );
    return;
  }
  // A lantern: a pointed flame of light with healing motes lifting off it.
  final r = 8.5 * vs;
  final tint = ui.Color.lerp(elementColor(element), m.glint, 0.3)!;
  final breathe = 0.85 + 0.15 * sin(time * 3 + seed);
  vfxSpill(canvas, c, r * 3.0, tint, 0.28 * breathe);
  final lantern = ui.Path()
    ..addPolygon([
      c + ui.Offset(0, -r * 1.5),
      c + ui.Offset(r * 0.7, 0),
      c + ui.Offset(0, r * 0.9),
      c + ui.Offset(-r * 0.7, 0),
    ], true);
  vfxFillPath(canvas, lantern, tint, 0.9);
  vfxFillPath(
    canvas,
    ui.Path()..addPolygon([
      c + ui.Offset(0, -r * 1.5),
      c + ui.Offset(r * 0.7, 0),
      c,
    ], true),
    m.glint,
    0.8,
  );
  for (var i = 0; i < 2; i++) {
    final t = (time * 0.8 + i * 0.5 + seed) % 1.0;
    _dot(
      canvas,
      c + ui.Offset(sin(i * 3 + seed) * r, -r - t * r * 2.5),
      1.1,
      m.glint,
      0.7 * sin(t * pi),
    );
  }
}

/// One section of Earth's wall: heavy stones stacked two high over their
/// own shadow. Sections overlap along the arc into a continuous wall.
void _drawWallSection(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double seed,
  double fade,
) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(1, 1);
  final rise = 1 - pow(1 - fade, 3).toDouble();
  vfxFillPath(
    canvas,
    vfxBlob(const ui.Offset(0, 6), 20, seed, n: 9, wobble: 0.2, squash: 0.45),
    const ui.Color(0xFF000000),
    0.35 * fade,
  );
  _stone(canvas, ui.Offset(-4, 2 * rise), 15, seed, m);
  _stone(canvas, ui.Offset(7, 4 * rise), 12, seed + 5, m);
  _stone(canvas, ui.Offset(1, -10 * rise), 11, seed + 9, m, squash: 0.9);
  canvas.restore();
}

/// A dark raincloud riding above the ship with rain falling out of it, and
/// the ground under it wet with the healing.
void _drawRainCloud(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double r,
  double seed,
  double time,
  double fade,
) {
  final cloudC = c + ui.Offset(0, -r * 0.55);
  // Wet ground where it lands, faintly lit.
  vfxSpill(canvas, c, r * 0.9, m.light, 0.16 * fade);
  // Rain: short falling drops, elongated along the fall.
  for (var i = 0; i < 12; i++) {
    final t = (time * 1.6 + i * 0.37 + vfxHash(seed + i)) % 1.0;
    final x = (vfxHash(seed + i * 3.1) - 0.5) * r * 1.0;
    final y = cloudC.dy + r * 0.12 + t * r * 0.55;
    canvas.save();
    canvas.translate(c.dx + x, y);
    canvas.scale(0.5, 1.6);
    vfxFillPath(
      canvas,
      vfxDrop(ui.Offset.zero, 1.8, pi / 2),
      m.glint,
      0.5 * sin(t * pi) * fade,
    );
    canvas.restore();
  }
  // The cloud: heavy dark underside, lit tops.
  for (var i = 0; i < 5; i++) {
    final x = (i - 2) * r * 0.22 + sin(time * 0.4 + i) * 3;
    final pr = r * (0.26 + 0.1 * vfxHash(seed + i));
    final pc = cloudC + ui.Offset(x, (i.isEven ? 0.0 : -0.1) * r);
    vfxFillPath(
      canvas,
      vfxBlob(pc, pr, seed + i + time * 0.1, n: 9, wobble: 0.1, squash: 0.7),
      m.ink,
      0.72 * fade,
    );
  }
  for (var i = 0; i < 4; i++) {
    final x = (i - 1.5) * r * 0.24;
    final pc = cloudC + ui.Offset(x, -r * 0.1);
    vfxFillPath(
      canvas,
      vfxBlob(
        pc,
        r * 0.18,
        seed + i * 3 + time * 0.1,
        n: 8,
        wobble: 0.12,
        squash: 0.6,
      ),
      m.mid,
      0.55 * fade,
    );
  }
}

/// A column of rising wind: a hollow at its foot, gusts winding upward and
/// debris lifted inside it.
void _drawUpdraft(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double r,
  double seed,
  double time,
  double fade,
) {
  vfxSpill(canvas, c, r * 0.55, const ui.Color(0xFF05080B), 0.2 * fade);
  // The column's body, a tall soft light.
  canvas.save();
  canvas.translate(c.dx, c.dy - r * 0.35);
  canvas.scale(0.55, 1.4);
  vfxSpill(canvas, ui.Offset.zero, r * 0.6, m.glint, 0.14 * fade);
  canvas.restore();
  // Gusts spiralling round the foot and up.
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(1, 0.55);
  final spin = time * 2.2 + seed;
  for (var i = 0; i < 3; i++) {
    vfxFillPath(
      canvas,
      vfxSpiralArm(
        ui.Offset.zero,
        r * 0.6,
        spin + i * pi * 2 / 3,
        1.7,
        r * 0.07,
        reach: 0.7,
      ),
      m.glint,
      0.2 * fade,
    );
  }
  canvas.restore();
  // Debris lifted up the column, spinning as it rises.
  for (var i = 0; i < 7; i++) {
    final t = (time * 0.7 + i / 7 + vfxHash(seed + i)) % 1.0;
    final a = time * 3 + i * 0.9;
    final p =
        c +
        ui.Offset(
          cos(a) * r * 0.35 * (1 - t * 0.5),
          sin(a) * r * 0.12 - t * r * 1.1,
        );
    vfxFillPath(
      canvas,
      vfxLeaf(p, 5.5, a * 2),
      m.glint,
      0.7 * sin(t * pi) * fade,
    );
  }
}

/// A drifting bank of dust — big and soft, grit turning inside it.
void _drawDustBank(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double r,
  double seed,
  double time,
  double fade,
) {
  vfxSpill(canvas, c, r, m.light, 0.12 * fade);
  for (var i = 0; i < 7; i++) {
    final a = i * 2.399 + seed + time * 0.05;
    final p = c + vfxPolar(a, r * 0.45 * (0.4 + 0.6 * vfxHash(seed + i)));
    final pr = r * (0.28 + 0.08 * sin(time * 0.5 + i));
    vfxFillPath(
      canvas,
      vfxBlob(p, pr, seed + i + time * 0.08, n: 10, wobble: 0.12, squash: 0.75),
      m.mid,
      0.14 * fade,
    );
  }
  for (var i = 0; i < 14; i++) {
    final a = time * (0.4 + 0.3 * vfxHash(seed + i)) + i * 0.45;
    _dot(
      canvas,
      c + vfxPolar(a, r * (0.15 + 0.7 * vfxHash(seed + i * 2))),
      1.2,
      m.glint,
      0.4 * fade,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// On the kin
// ─────────────────────────────────────────────────────────────────────────

/// What shows on a kin while its support is running, in its local
/// coordinates. Every effect is sized to a ~14px body.
void drawKinSupportEffects({
  required ui.Canvas canvas,
  required String element,
  required double time,
  double iceChargeProgress = 0,
  bool lightningActive = false,
  bool fireOrbitalActive = false,
  double fireOrbitalRadius = 70,
  bool lavaPlateActive = false,
  bool darkCloakActive = false,
  double steamPressure = 0,
}) {
  final m = vfxMaterial(element);
  final iceT = iceChargeProgress.clamp(0.0, 1.0);
  if (element == 'Ice' && iceT > 0) {
    // Frost drawn in from all round as the charge fills.
    vfxSpill(canvas, ui.Offset.zero, 26 + 16 * iceT, m.light, 0.25 * iceT);
    for (var i = 0; i < 7; i++) {
      final a = i * pi * 2 / 7 + time * 0.4;
      final d = 36 - 18 * iceT + sin(time * 3 + i) * 2;
      vfxFillPath(
        canvas,
        vfxShard(vfxPolar(a, d), 6 + 4 * iceT, 1.6, a + pi),
        m.glint,
        0.3 + 0.55 * iceT,
      );
    }
  }
  if (element == 'Lightning' && lightningActive) {
    // A charged coil: bolts arcing round the body.
    final pulse = 0.8 + 0.2 * sin(time * 14);
    vfxSpill(canvas, ui.Offset.zero, 36, m.light, 0.3 * pulse);
    final step = (time * 16).floorToDouble();
    for (var i = 0; i < 3; i++) {
      final a0 = vfxHash(step + i) * pi * 2;
      final a1 = a0 + 1.2 + vfxHash(step + i * 3) * 1.4;
      final path = ui.Path();
      for (var k = 0; k <= 5; k++) {
        final t = k / 5;
        final p = vfxPolar(
          a0 + (a1 - a0) * t,
          23 + (vfxHash(step + i * 7 + k) - 0.5) * 9,
        );
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      _stroke
        ..color = m.light.withValues(alpha: 0.25 * pulse)
        ..strokeWidth = 3.5;
      canvas.drawPath(path, _stroke);
      _stroke
        ..color = m.glint.withValues(alpha: 0.9 * pulse)
        ..strokeWidth = 1.1;
      canvas.drawPath(path, _stroke);
    }
  }
  if (element == 'Fire' && fireOrbitalActive) {
    // The reborn phoenix flames, circling at the reach they burn.
    final orbit = 32 * (fireOrbitalRadius / 70);
    for (var i = 0; i < 3; i++) {
      final a = time * 3.2 + i * pi * 2 / 3;
      final p = vfxPolar(a, orbit);
      final back = a - pi / 2;
      vfxSpill(canvas, p, 12, m.light, 0.3);
      vfxFillPath(canvas, vfxDrop(p, 5.5, a + pi / 2), m.mid, 0.8);
      vfxFillPath(canvas, vfxDrop(p, 3.0, a + pi / 2), m.glint, 0.9);
      for (var k = 1; k <= 2; k++) {
        _dot(
          canvas,
          p + vfxPolar(back, k * 5.0),
          1.6 - k * 0.4,
          m.glint,
          0.6 - k * 0.2,
        );
      }
    }
  }
  if (element == 'Lava' && lavaPlateActive) {
    drawKinLavaPlate(canvas: canvas, time: time);
  }
  if (element == 'Dark' && darkCloakActive) {
    // A shadow drawn round it, wisps lifting off.
    vfxFillPath(
      canvas,
      vfxBlob(ui.Offset.zero, 27, time * 0.3, n: 12, wobble: 0.1),
      m.ink,
      0.5,
    );
    for (var i = 0; i < 3; i++) {
      final ph = (time * 0.5 + i / 3) % 1.0;
      vfxFillPath(
        canvas,
        vfxSpiralArm(
          ui.Offset.zero,
          32 - ph * 6,
          i * 2.1 + time * 0.6,
          1.0,
          3.0,
          reach: 0.4,
        ),
        m.glint,
        0.3 * sin(ph * pi),
      );
    }
  }
  if (element == 'Steam' && steamPressure > 0) {
    // Pressure venting off it, thicker the more stacks it holds.
    final p = steamPressure.clamp(0.0, 1.0);
    for (var i = 0; i < 4; i++) {
      final ph = (time * (0.8 + p) + i / 4) % 1.0;
      final a = i * pi / 2 + 0.5;
      vfxSpill(
        canvas,
        vfxPolar(a, 18 + ph * 18),
        6 + ph * (9 + 9 * p),
        m.glint,
        (0.18 + 0.25 * p) * sin(ph * pi),
      );
    }
  }
}

/// Lava kin's molten plate — reactive armour on every companion while it
/// holds. Local coordinates, sized to a ~14px body.
void drawKinLavaPlate({
  required ui.Canvas canvas,
  required double time,
  double scale = 1,
}) {
  final m = vfxMaterial('Lava');
  final glow = 0.7 + 0.3 * sin(time * 3);
  vfxSpill(canvas, ui.Offset.zero, 30 * scale, m.light, 0.24 * glow);
  for (var i = 0; i < 5; i++) {
    final a = i * pi * 2 / 5 + time * 0.25;
    final c = vfxPolar(a, 21 * scale);
    final plate = ui.Path()
      ..addPolygon([
        c + vfxPolar(a - 1.1, 8 * scale),
        c + vfxPolar(a, 5 * scale),
        c + vfxPolar(a + 1.1, 8 * scale),
        c + vfxPolar(a + pi, 4 * scale),
      ], true);
    vfxFillPath(canvas, plate, m.ink, 0.9);
    vfxFillPath(
      canvas,
      vfxCrescent(ui.Offset.zero, 21 * scale - 1, 1.8 * scale, a, 0.35),
      m.glint,
      0.7 * glow,
    );
  }
}

/// A kin gathering light before it fires its laser. [aimDirection] (world
/// delta toward the target) places the focus.
void drawKinCharge({
  required ui.Canvas canvas,
  required ui.Color color,
  required double progress,
  required double time,
  ui.Offset? aimDirection,
}) {
  final t = progress.clamp(0.0, 1.0);
  final glint = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.6)!;
  final mid = ui.Color.lerp(color, const ui.Color(0xFF000000), 0.2)!;
  vfxSpill(canvas, ui.Offset.zero, 18 + 12 * t, color, 0.18 + 0.22 * t);
  for (var i = 0; i < 6; i++) {
    final ph = (time * (1.0 + 1.5 * t) + i / 6) % 1.0;
    final a = i * 2.399 + time * 0.7;
    final d = (30 - 12 * t) * (1 - ph) + 8;
    vfxFillPath(
      canvas,
      vfxDrop(vfxPolar(a, d), 1.4 + 1.2 * t, a + pi),
      mid,
      0.65 * sin(ph * pi),
    );
  }
  vfxSpill(canvas, ui.Offset.zero, 5 + 6 * t, glint, 0.35 + 0.45 * t);
  if (aimDirection == null || aimDirection.distance <= 0.01) return;
  final dir = aimDirection / aimDirection.distance;
  vfxSpill(canvas, dir * (16 + 10 * t), 3 + 4 * t, glint, 0.5 + 0.4 * t);
}

/// A kin's laser: the same lit, tapered construction as a Wing beam but
/// slim and bare — the kin's is a support tool, not a signature.
void drawKinLaser({
  required ui.Canvas canvas,
  required ui.Offset start,
  required ui.Offset end,
  required ui.Color color,
  double width = 3.4,
  double alpha = 1,
}) {
  final len = (end - start).distance;
  if (len < 0.5 || alpha <= 0) return;
  final a = alpha.clamp(0.0, 1.0);
  final w = max(1.2, width);
  final glint = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.65)!;
  vfxSpill(canvas, end, w * 3.2, color, 0.4 * a);
  vfxSpill(canvas, start, w * 2.2, color, 0.35 * a);
  canvas.save();
  canvas.translate(start.dx, start.dy);
  canvas.rotate(atan2(end.dy - start.dy, end.dx - start.dx));
  vfxCrossLit(
    canvas,
    vfxLens(len, w * 3, w * 2.5, w * 1.5),
    w * 1.5,
    color,
    color,
    0.32 * a,
    plateau: 0.1,
  );
  vfxCrossLit(
    canvas,
    vfxLens(len, w * 1.1, w * 2, w),
    w * 0.55,
    color,
    ui.Color.lerp(color, glint, 0.4)!,
    0.9 * a,
    plateau: 0.4,
  );
  vfxFillPath(
    canvas,
    vfxLens(len, max(1.0, w * 0.34), w * 1.5, w * 0.8),
    glint,
    0.95 * a,
  );
  canvas.restore();
}

// ─────────────────────────────────────────────────────────────────────────
// Shared by every family
// ─────────────────────────────────────────────────────────────────────────

/// A blessing on a creature: warm healing light welling up round it and
/// motes lifting off. Local coordinates.
void drawBlessing({
  required ui.Canvas canvas,
  required double time,
  double scale = 1,
  double opacity = 1,
}) {
  const heal = ui.Color(0xFF9CD08A);
  const gold = ui.Color(0xFFE8E0B0);
  final o = opacity.clamp(0.0, 1.0);
  final breathe = 0.75 + 0.25 * sin(time * 3.0);
  vfxSpill(
    canvas,
    ui.Offset(0, 4 * scale),
    26 * scale,
    heal,
    0.22 * breathe * o,
  );
  for (var i = 0; i < 5; i++) {
    final t = (time * 0.7 + i / 5) % 1.0;
    final x = sin(i * 2.7 + time * 0.5) * 13 * scale;
    final p = ui.Offset(x, (8 - t * 34) * scale);
    vfxFillPath(
      canvas,
      vfxDrop(p, 1.8 * scale, -pi / 2),
      i.isEven ? gold : heal,
      0.75 * sin(t * pi) * o,
    );
  }
}

/// A creature's shield: a glassy ward with its light gathered at the rim and
/// a sheen sliding over it — no outline. Local coordinates.
void drawShieldWard({
  required ui.Canvas canvas,
  required double time,
  double scale = 1,
}) {
  const ward = ui.Color(0xFF9EC8E0);
  const sheen = ui.Color(0xFFE6F2F8);
  final r = 22 * scale;
  vfxSoftRing(canvas, ui.Offset.zero, r, r * 0.22, ward, 0.34);
  _paint
    ..color = const ui.Color(0xFFFFFFFF)
    ..shader = ui.Gradient.radial(ui.Offset.zero, r, [
      ward.withValues(alpha: 0),
      ward.withValues(alpha: 0.08),
    ]);
  canvas.drawCircle(ui.Offset.zero, r, _paint);
  _paint.shader = null;
  for (var i = 0; i < 2; i++) {
    vfxFillPath(
      canvas,
      vfxCrescent(ui.Offset.zero, r * 0.94, r * 0.12, time * 0.8 + i * pi, 1.1),
      sheen,
      0.3,
    );
  }
}
