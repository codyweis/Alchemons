import 'dart:math';
import 'dart:ui' as ui;

import 'ability_grains.dart' show abilityElementOfColor, abilityMaterialTint;
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

void _dot(ui.Canvas canvas, ui.Offset c, double r, ui.Color color, double a) {
  if (a <= 0.004) return;
  _paint
    ..shader = null
    ..color = color.withValues(alpha: a.clamp(0.0, 1.0));
  canvas.drawCircle(c, r, _paint);
}

/// A faceted stone — dark body, one lit face, a glint on its edge — added to
/// the three paths of a pile, so a pile of stones costs three fills.
void _stone(
  ui.Offset c,
  double r,
  double seed, {
  required ui.Path body,
  required ui.Path face,
  required ui.Path glint,
  double squash = 0.8,
}) {
  final pts = <ui.Offset>[];
  for (var k = 0; k < 6; k++) {
    final a = k * pi / 3 + (vfxHash(seed + k) - 0.5) * 0.5;
    final rr = r * (0.75 + 0.35 * vfxHash(seed + k * 2.3));
    pts.add(c + ui.Offset(cos(a) * rr, sin(a) * rr * squash));
  }
  body.addPolygon(pts, true);
  face.addPolygon([c, pts[3], pts[4], pts[5]], true);
  glint.addPolygon([pts[4], pts[5], c + (pts[5] - c) * 0.5], true);
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
    // A stone of the material turning slowly (it was a two-triangle prism),
    // its face catching more light while it still has charges.
    final charged = p.interceptCharges > 0 ? 1.0 : 0.45;
    final r = 10.0 * vs;
    vfxSpill(canvas, c, r * 2.6, m.light, 0.22 * charged);
    // Lit crystal, a step up Crystal's material: its dark body on black
    // read as a hole, not a refractor.
    vfxChunk(
      canvas,
      c,
      r,
      seed,
      VfxMaterial(m.mid, m.light, m.glint, m.light),
      rot: time * 0.7 + seed,
      sides: 6,
      faceAlpha: 0.45 + 0.4 * charged,
    );
    vfxFillPath(
      canvas,
      vfxShard(c, r * 0.8, r * 0.12, time * 0.7 + seed + 0.5),
      vfxFlare(m),
      (0.2 + 0.35 * (0.5 + 0.5 * sin(time * 2.4 + seed))) * charged,
    );
    return;
  }
  // A lantern: a pointed flame of light with healing motes lifting off it.
  final r = 8.5 * vs;
  final tint = ui.Color.lerp(elementColor(element), m.glint, 0.3)!;
  // A flame of light (round below, drawn up to a point that sways) over
  // its own pool, motes of it lifting off as grains — not a four-point gem.
  final breathe = 0.85 + 0.15 * sin(time * 3 + seed);
  final lean = pi / 2 + sin(time * 1.7 + seed) * 0.12;
  vfxSpill(canvas, c, r * 3.0, tint, 0.3 * breathe);
  vfxFillPath(canvas, vfxDrop(c, r * 0.62 * breathe, lean), tint, 0.9);
  vfxFillPath(
    canvas,
    vfxDrop(c + const ui.Offset(0, 1), r * 0.34, lean),
    vfxFlare(m),
    0.85,
  );
  for (var i = 0; i < 2; i++) {
    final t = (time * 0.8 + i * 0.5 + seed) % 1.0;
    vfxGrain(c.dx + sin(i * 3 + seed) * r, c.dy - r - t * r * 2.5);
  }
  vfxGrainsFlush(canvas, 2.4, m.glint, 0.6);
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
  // The three stones as one pile: bodies, faces and glints a fill each
  // (they were three fills a stone, nine a section).
  final body = ui.Path(), face = ui.Path(), glint = ui.Path();
  _stone(ui.Offset(-4, 2 * rise), 15, seed, body: body, face: face, glint: glint);
  _stone(
    ui.Offset(7, 4 * rise),
    12,
    seed + 5,
    body: body,
    face: face,
    glint: glint,
  );
  _stone(
    ui.Offset(1, -10 * rise),
    11,
    seed + 9,
    body: body,
    face: face,
    glint: glint,
    squash: 0.9,
  );
  vfxFillPath(canvas, body, m.ink, 0.95);
  vfxFillPath(canvas, face, m.mid, 0.8);
  vfxFillPath(canvas, glint, m.glint, 0.35);
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
  // The ground it draws on, out to the edge of what it lifts.
  vfxSpill(canvas, c, r, const ui.Color(0xFF05080B), 0.2 * fade);
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
  // Arms that wind well in, so the foot reads as a swirl drawing air up,
  // not as arcs round the ship. One fill.
  final arms = ui.Path();
  for (var i = 0; i < 3; i++) {
    arms.addPath(
      vfxSpiralArm(
        ui.Offset.zero,
        r * 0.9,
        spin + i * pi * 2 / 3,
        2.6,
        r * 0.1,
        reach: 0.88,
      ),
      ui.Offset.zero,
    );
  }
  vfxFillPath(canvas, arms, m.glint, 0.15 * fade);
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
    // Frost condensing onto the kin as the charge fills: grains of it drawn
    // in out of the air on curving paths, and a crust of ice growing over
    // the ground under it, its lit face swelling. (It was a wheel of seven
    // shards pointing in, turning round the body: radiating blades.) One
    // grain batch and two fills.
    vfxSpill(canvas, ui.Offset.zero, 26 + 16 * iceT, m.light, 0.25 * iceT);
    vfxFillPath(
      canvas,
      vfxBlob(
        const ui.Offset(0, 6),
        (10 + 12 * iceT),
        4.7,
        n: 9,
        wobble: 0.22,
        squash: 0.45,
      ),
      m.mid,
      0.3 + 0.4 * iceT,
    );
    vfxFillPath(
      canvas,
      vfxBlob(
        const ui.Offset(-2, 4),
        (5 + 8 * iceT),
        2.3,
        n: 8,
        wobble: 0.25,
        squash: 0.35,
      ),
      m.light,
      0.2 + 0.35 * iceT,
    );
    vfxGrainsDiscard();
    for (var i = 0; i < 12; i++) {
      final ph = (time * (0.5 + 0.7 * iceT) + i / 12) % 1.0;
      final u = ph * ph;
      final a = i * 2.399963 + u * 1.4;
      final g = vfxPolar(a, 42 * (1 - u) + 6 * u);
      vfxGrain(g.dx, g.dy);
    }
    vfxGrainsFlush(canvas, 2.2, m.glint, 0.35 + 0.5 * iceT);
  }
  if (element == 'Lightning' && lightningActive) {
    // A charged coil: bolts arcing round the body. Each arc writhes, easing
    // from one hashed pose to the next a couple of times a second instead of
    // re-rolling sixteen times a second, and is a filled lens ribbon: all
    // three share a faint wide band and a lit core, two fills in all. The
    // arcs are kept short of each other so the three never close a ring.
    final pulse = 0.8 + 0.2 * sin(time * 14);
    vfxSpill(canvas, ui.Offset.zero, 36, m.light, 0.3 * pulse);
    final glow = ui.Path();
    final core = ui.Path();
    final corners = <ui.Offset>[];
    final spine = <ui.Offset>[];
    for (var i = 0; i < 3; i++) {
      final a0 = i * pi * 2 / 3 + (vfxGlide(i * 1.9, time, 2.2) - 0.5) * 0.6;
      final a1 = a0 + 0.7 + vfxGlide(i * 3.3 + 0.5, time, 2.2) * 0.6;
      corners.clear();
      for (var k = 0; k <= 5; k++) {
        corners.add(
          vfxPolar(
            a0 + (a1 - a0) * k / 5,
            23 + (vfxGlide(i * 7.0 + k + 0.3, time, 2.6) - 0.5) * 8,
          ),
        );
      }
      vfxCurveSpine(corners, perSegment: 3, into: spine..clear());
      vfxLensRibbon(spine, 4.4, taper: 0.4, into: glow);
      vfxLensRibbon(spine, 1.8, taper: 0.4, into: core);
    }
    vfxFillPath(canvas, glow, m.light, 0.22 * pulse);
    vfxFillPath(canvas, core, m.glint, 0.75 * pulse);
  }
  if (element == 'Fire' && fireOrbitalActive) {
    // The reborn phoenix flame: a crown of fire standing up off the body,
    // its heat pooled out to the reach it burns and embers lifting all
    // through that reach. Nothing circles the kin (three flames used to
    // orbit it at three radians a second).
    final reach = 32 * (fireOrbitalRadius / 70);
    vfxSpill(canvas, ui.Offset.zero, reach * 1.15, m.light, 0.2);
    final body = ui.Path();
    final hot = ui.Path();
    for (var i = 0; i < 3; i++) {
      final x = (i - 1) * 7.0;
      final lick = 0.8 + 0.2 * sin(time * 7 + i * 2.1);
      final lean = pi / 2 + sin(time * 2.6 + i) * 0.16 + (i - 1) * 0.2;
      final base = ui.Offset(x, -8 + (i == 1 ? -3 : 0));
      body.addPath(vfxDrop(base, 5.5 * lick, lean), ui.Offset.zero);
      hot.addPath(vfxDrop(base, 3.0 * lick, lean), ui.Offset.zero);
    }
    vfxFillPath(canvas, body, m.mid, 0.82);
    vfxFillPath(canvas, hot, m.glint, 0.9);
    for (var i = 0; i < 7; i++) {
      final ph = (time * 0.55 + i * 0.37) % 1.0;
      final a = i * 2.399963;
      final g = vfxPolar(a, reach * (0.3 + 0.65 * vfxHash(i * 3.3))) +
          ui.Offset(0, -ph * 14);
      vfxGrain(g.dx, g.dy);
    }
    vfxGrainsFlush(canvas, 2.4, m.glint, 0.65);
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
    // Puffs rising off the body and billowing as they go, never thrown out
    // at the four quarters (that read as a cross).
    final p = steamPressure.clamp(0.0, 1.0);
    for (var i = 0; i < 4; i++) {
      final ph = (time * (0.6 + 0.8 * p) + i / 4) % 1.0;
      final c = ui.Offset(
        (i - 1.5) * 6.0 + sin(time * 1.3 + i * 2.1) * 3.0,
        2.0 - ph * 30.0,
      );
      vfxSpill(
        canvas,
        c,
        7 + ph * (9 + 9 * p),
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
  // Material first: the element's light tinted toward its hue, its glint at
  // the heart (it was the raw Material colour with a 60%-white heart).
  final (light, glint, mid) = _kinLaserTones(color);
  vfxSpill(canvas, ui.Offset.zero, 18 + 12 * t, light, 0.18 + 0.22 * t);
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

/// The laser's and the charge's light, glint and body for an element
/// [color]: the element's material light tinted toward its hue, its glint,
/// its lit face. A colour that is no element's keeps the old derivation.
(ui.Color, ui.Color, ui.Color) _kinLaserTones(ui.Color color) {
  // A Crystal refractor's counter-shot (KinSupport.refractColor) is light
  // bent through crystal: Crystal's material, not a bare cream wire.
  final element = color.toARGB32() == _kRefractCream
      ? 'Crystal'
      : abilityElementOfColor(color);
  if (element == null) {
    return (
      color,
      ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.6)!,
      ui.Color.lerp(color, const ui.Color(0xFF000000), 0.2)!,
    );
  }
  final m = vfxMaterial(element);
  final light = abilityMaterialTint(color);
  return (
    light,
    ui.Color.lerp(m.glint, light, 0.2)!,
    ui.Color.lerp(m.mid, light, 0.35)!,
  );
}

/// KinSupport.refractColor (kin_support_runtime.dart), the colour a Crystal
/// refractor's counter-shot is pushed with.
const int _kRefractCream = 0xFFFFF3C8;

/// A kin's laser: the same lit, tapered construction as a Wing beam but
/// slim and bare — the kin's is a support tool, not a signature. Slim, but
/// never a wire: the body is at least ~4 px and the glow carries it.
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
  // A Crystal refractor's counter-shot is light bent through crystal: a
  // fuller beam than the kin's own laser, with chips of light running down
  // it (it read as a thin grey wire from the shard).
  final refract = color.toARGB32() == _kRefractCream;
  final w = refract ? max(4.6, width * 1.8) : max(2.4, width);
  // Material first, as the charge (it was the raw Material colour).
  final (light, glint, mid) = _kinLaserTones(color);

  vfxSpill(canvas, end, w * 4.0, light, 0.42 * a);
  vfxSpill(canvas, start, w * 2.6, light, 0.35 * a);
  canvas.save();
  canvas.translate(start.dx, start.dy);
  canvas.rotate(atan2(end.dy - start.dy, end.dx - start.dx));
  vfxCrossLit(
    canvas,
    vfxLens(len, w * 4.2, w * 2.5, w * 1.5),
    w * 2.1,
    light,
    light,
    0.34 * a,
    plateau: 0.1,
  );
  vfxCrossLit(
    canvas,
    vfxLens(len, w * 1.7, w * 2, w),
    w * 0.85,
    mid,
    ui.Color.lerp(light, glint, 0.35)!,
    0.92 * a,
    plateau: 0.4,
  );
  vfxFillPath(
    canvas,
    vfxLens(len, max(1.4, w * 0.5), w * 1.5, w * 0.8),
    ui.Color.lerp(glint, light, 0.25)!,
    0.9 * a,
  );
  canvas.restore();
  if (refract) {
    final d = end - start;
    vfxGrainsDiscard();
    for (var i = 0; i < 5; i++) {
      final f = (i + 0.5) / 5 + 0.08 * (1 - a);
      if (f >= 1) continue;
      final p = start + d * f;
      vfxGrain(p.dx, p.dy);
    }
    vfxGrainsFlush(canvas, w * 0.9, vfxMaterial('Crystal').glint, 0.8 * a);
  }
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

// ─────────────────────────────────────────────────────────────────────────
// What a running Kin support shows on the ship and between allies. Lifted
// out of survival's render so open space paints the same thing.
// ─────────────────────────────────────────────────────────────────────────

/// Dark kin's veil drawn over the core it hides (survival): darkness pooled
/// over it and smoke banks closing round it, slowly turning, in Dark's own
/// material — no stroked purple hoop. [radius] is what it covers. Five fills.
void drawKinDarkVeil({
  required ui.Canvas canvas,
  required ui.Offset center,
  required double radius,
  required double time,
}) {
  final m = vfxMaterial('Dark');
  final breathe = 0.9 + 0.1 * sin(time * 1.4);
  vfxSpill(canvas, center, radius * 1.25, m.ink, 0.62);
  vfxFillPath(
    canvas,
    vfxBlob(center, radius * 0.95 * breathe, 5.3, n: 16, wobble: 0.08),
    m.ink,
    0.38,
  );
  final banks = ui.Path();
  for (var i = 0; i < 3; i++) {
    banks.addPath(
      vfxCrescent(
        center,
        radius * (0.98 + 0.04 * sin(time * 0.9 + i)),
        radius * 0.16,
        time * 0.22 + i * 2.1,
        1.5,
      ),
      ui.Offset.zero,
    );
  }
  vfxFillPath(canvas, banks, m.mid, 0.4);
  vfxSpill(canvas, center, radius * 0.5, m.light, 0.06 * breathe);
}

/// Lava kin's plate on the ship: the heat of it pooled round the hull in
/// Lava's own light (it was two flat discs of raw orange).
void drawKinLavaShipGlow({required ui.Canvas canvas, required double time}) {
  final pulse = 0.78 + 0.22 * sin(time * 3);
  final m = vfxMaterial('Lava');
  vfxSpill(canvas, ui.Offset.zero, 34, m.light, 0.3 * pulse);
  vfxSpill(canvas, ui.Offset.zero, 18, m.glint, 0.2 * pulse);
}

/// Lightning's light pulled 30% toward its own yellow, as the glowing
/// elements' art is.
final ui.Color _teslaLight = ui.Color.lerp(
  vfxMaterial('Lightning').light,
  elementColor('Lightning'),
  0.3,
)!;

/// Lightning kin's tesla channel on the ship: charge pooled round the hull
/// and three arcs crawling over its skin, rim to rim at bearings that
/// glide (they were four random spokes a frame on two flat discs). Local
/// coordinates, at the ship's centre, not rotated with its heading. Three
/// fills.
void drawKinTeslaShip({required ui.Canvas canvas, required double time}) {
  final m = vfxMaterial('Lightning');
  final pulse = 0.8 + 0.2 * sin(time * 9);
  vfxSpill(canvas, ui.Offset.zero, 38, _teslaLight, 0.3 * pulse);
  final glow = ui.Path();
  final core = ui.Path();
  // Arcs run along the hull's rim (short chords that hug it, bowing a
  // little either way), at uneven bearings so they never make a figure.
  for (var i = 0; i < 3; i++) {
    final a0 = i * 2.6 + 0.9 * vfxHash(i * 5.1) +
        (vfxGlide(i * 2.9, time, 1.2) - 0.5) * 2.2;
    final a1 = a0 + 0.7 + vfxGlide(i * 4.3 + 0.7, time, 1.6) * 0.6;
    vfxArcInto(
      glow,
      core,
      vfxPolar(a0, 24 + 3 * vfxGlide(i * 1.3, time, 2.1)),
      vfxPolar(a1, 25),
      i * 7.0 + 1.0,
      time,
      width: 1.6,
      amp: 0.14,
    );
  }
  vfxFillPath(canvas, glow, _teslaLight, 0.3 * pulse);
  vfxFillPath(
    canvas,
    core,
    ui.Color.lerp(m.glint, elementColor('Lightning'), 0.3)!,
    0.85 * pulse,
  );
}

/// Blood kin's pact: every living ally (ship included) tied to the next by
/// a vein that sags between them and beats — dark filled ribbons in one
/// path, with drops of light running along them as one batch of grains
/// (they were ruled 1.2 px lines between every pair, a Paint each). World
/// coordinates. Two draws plus the grains.
void drawKinBloodThreads({
  required ui.Canvas canvas,
  required List<ui.Offset> allies,
  required double time,
}) {
  final n = allies.length;
  if (n < 2) return;
  final m = vfxMaterial('Blood');
  final beat = pow(max(0.0, sin(time * 3)), 4).toDouble();
  final veins = ui.Path();
  final spine = <ui.Offset>[];
  // A closed loop round the party (a chain for two): n veins, not n².
  final links = n == 2 ? 1 : n;
  for (var i = 0; i < links; i++) {
    final a = allies[i], b = allies[(i + 1) % n];
    final d = b - a;
    final len = d.distance;
    if (len < 4) continue;
    // Hanging between them, as a thread does: it sags down, never in toward
    // the middle of the party (a loop of inward bows read as a star).
    final mid = (a + b) / 2 + ui.Offset(0, 10 + len * 0.1);
    vfxQuadSpine(a, mid, b, n: 10, into: spine..clear());
    vfxLensRibbon(spine, 4.0 + 1.6 * beat, taper: 0.2, into: veins);
    // Drops of light running along it toward the next ally.
    for (var k = 0; k < 2; k++) {
      final t = (time * 0.6 + k * 0.5 + i * 0.27) % 1.0;
      final u = 1 - t;
      final g =
          a * (u * u) + mid * (2 * u * t) + b * (t * t);
      vfxGrain(g.dx, g.dy);
    }
  }
  vfxFillPath(canvas, veins, m.light, 0.5 + 0.25 * beat);
  vfxGrainsFlush(canvas, 3.4, m.glint, 0.85);
}

/// Steam kin's boiler: how full it is, floating above the kin while it
/// boils, so the player can see when it is at full pressure — ten beads of
/// steam in a shallow arc, one lit for each stack (the lit ones breathing),
/// the rest a faint condensate. No text, no blurred shadow: two grain draws.
/// Local coordinates, at the kin's centre.
void drawKinSteamBadge({
  required ui.Canvas canvas,
  required int stacks,
  double time = 0,
}) {
  const badgeY = -34.0;
  final m = vfxMaterial('Steam');
  final lit = stacks.clamp(0, 10);
  ui.Offset bead(int i) {
    final u = (i - 4.5) / 4.5;
    return ui.Offset(u * 15, badgeY + u * u * 4);
  }

  for (var i = lit; i < 10; i++) {
    final p = bead(i);
    vfxGrain(p.dx, p.dy);
  }
  vfxGrainsFlush(canvas, 2.6, m.mid, 0.5);
  for (var i = 0; i < lit; i++) {
    final p = bead(i) + ui.Offset(0, -0.8 * sin(time * 3 + i * 0.7));
    vfxGrain(p.dx, p.dy);
  }
  vfxGrainsFlush(
    canvas,
    3.0,
    lit >= 10 ? vfxFlare(m) : m.glint,
    0.95,
  );
}
