import 'dart:math';
import 'dart:ui' as ui;

import 'cosmic_data.dart';
import 'horn_vfx.dart' show drawHornMote;
import 'vfx_shapes.dart';

/// Every family's auto-attack in its own material, and the material fallback
/// for whatever no family painter claims (Wing's special discs and trail
/// drops, Mane's Lightning orbs and Dust trail, Kin's Poison darts and the
/// like). Shared by survival, open space and dungeons through
/// `drawGenericProjectileVisual`.
///
/// The fallback used to be two flat saturated circles for everything — the
/// most numerous shots in the game, indistinguishable by element and frozen
/// at one size. Now each piece is sized from the radius the game actually
/// hits with, read off the projectile when it is drawn: its contact radius
/// (`Projectile.radius * radiusMultiplier`) for a moving shot, its tick zone
/// for a parked one. So the art matches the hit, and grows when it does.
///
/// Whose basic it is comes from [Projectile.basicFamily] (render-only — a
/// basic keeps `abilityFamily` empty because combat reads that as "an
/// auto-attack"); a special's piece carries `abilityFamily`.
///
/// Budget: two or three fills a shot (the old fallback was two), no Paint
/// allocation, no blur, no strokes, and no Path built per shot: every piece
/// is a unit shape cached once (vfx_shapes.dart's `vfxFillDrop` and kin, the
/// Mask shard here), drawn with the canvas moved onto it.

final ui.Paint _zoneFill = ui.Paint();
final Map<int, ui.Shader> _poolShaders = {};

/// The family whose language a piece should be drawn in.
String _familyOf(Projectile p) =>
    p.abilityFamily.isNotEmpty ? p.abilityFamily : p.basicFamily;

double _hitRadius(Projectile p) =>
    max(1.6, Projectile.radius * p.radiusMultiplier);

/// Paints a moving shot or a parked piece in its family's material. Returns
/// false only for an orbital style, which keeps its own painter.
bool drawMaterialProjectile({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required double time,
}) {
  if (projectile.stationary) {
    _drawParkedPiece(canvas, projectile, position, time);
    return true;
  }
  final m = vfxMaterial(projectile.element);
  final r = _hitRadius(projectile);
  final a = projectile.angle;
  switch (_familyOf(projectile)) {
    case 'horn':
      drawHornMote(
        canvas: canvas,
        projectile: projectile,
        position: position,
        time: time,
      );
    case 'wing':
      _drawFeather(canvas, m, position, r, a, time, projectile);
    case 'mask':
      _drawMaskShard(canvas, m, position, r, a);
    case 'mystic':
      _drawGrainOrb(canvas, m, position, r, time, projectile);
    case 'kin':
      // Kin's darts (Poison's) fly as darts; its other shots as lanterns.
      if (projectile.visualStyle == ProjectileVisualStyle.dart) {
        _drawSliver(canvas, m, position, r, a);
      } else {
        _drawLantern(canvas, m, position, r, a);
      }
    default:
      if (projectile.visualStyle == ProjectileVisualStyle.dart) {
        _drawSliver(canvas, m, position, r, a);
      } else {
        _drawDrop(canvas, m, position, r, a);
      }
  }
  return true;
}

/// Wing: a feather riding the air — a vane of the element's material with a
/// lit quill, and a faint streak of its light behind.
void _drawFeather(
  ui.Canvas canvas,
  VfxMaterial m,
  ui.Offset c,
  double r,
  double a,
  double time,
  Projectile p,
) {
  final len = r * 4.2;
  final dir = vfxPolar(a, 1);
  // A slight flutter, per feather, so a pair never moves as one stamped part.
  final flutter = sin(time * 11 + identityHashCode(p) % 13) * 0.08;
  vfxFillDrop(canvas, c - dir * r * 0.6, r * 0.9, a, m.light, 0.28);
  vfxFillLeaf(canvas, c - dir * len * 0.62, len, a + flutter, m.mid, 0.85);
  vfxFillShard(
    canvas,
    c + dir * len * 0.1,
    len * 0.42,
    r * 0.22,
    a + flutter,
    m.glint,
    0.8,
  );
}

// Mask's shard at unit size (r = 1) along +x: built once, drawn moved,
// turned and scaled onto each shot.
const double _maskLen = 2.6, _maskW = 0.85;
final ui.Path _maskBody = ui.Path()
  ..moveTo(_maskLen, 0)
  ..lineTo(0, _maskW)
  ..lineTo(-_maskLen * 0.5, _maskW * 0.2)
  ..lineTo(-_maskLen * 0.5, -_maskW * 0.35)
  ..lineTo(0, -_maskW * 0.8)
  ..close();
final ui.Path _maskShade = ui.Path()
  ..moveTo(_maskLen, 0)
  ..lineTo(0, -_maskW * 0.8)
  ..lineTo(-_maskLen * 0.5, -_maskW * 0.35)
  ..lineTo(0, 0)
  ..close();

/// Mask: a shard of a mask — a lit face, its shadowed half, a bright edge.
void _drawMaskShard(
  ui.Canvas canvas,
  VfxMaterial m,
  ui.Offset c,
  double r,
  double a,
) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(a);
  canvas.scale(r);
  // In flight against dark space the body reads in its lit tone; the
  // shadowed half is the ink.
  vfxFillPath(canvas, _maskBody, m.mid, 0.92);
  vfxFillPath(canvas, _maskShade, m.ink, 0.7);
  vfxFillShard(
    canvas,
    const ui.Offset(_maskLen * 0.35, 0),
    _maskLen * 0.55,
    0.16,
    0,
    m.glint,
    0.85,
  );
  canvas.restore();
}

/// Mystic: a small orb of grains held loosely together round a dark heart —
/// alchemy as sand, not a sigil.
void _drawGrainOrb(
  ui.Canvas canvas,
  VfxMaterial m,
  ui.Offset c,
  double r,
  double time,
  Projectile p,
) {
  final blob = identityHashCode(p) % 71;
  final seed = blob.toDouble();
  vfxFillBlob(canvas, c, r * 0.9, blob, m.mid, 0.8, n: 8, wobble: 0.2);
  vfxGrainsDiscard();
  for (var i = 0; i < 7; i++) {
    final h = vfxHash(seed + i * 1.7);
    // Each grain drifts round its own slot, never a shared orbit.
    final ang = seed + i * 2.399 + sin(time * (1.4 + h) + i) * 0.5;
    final d = r * (0.9 + 0.8 * h);
    vfxGrain(c.dx + cos(ang) * d, c.dy + sin(ang) * d);
  }
  vfxGrainsFlush(canvas, max(1.1, r * 0.42), m.glint, 0.85);
}

/// Kin: a small lantern of the element's light, its heart lit.
void _drawLantern(
  ui.Canvas canvas,
  VfxMaterial m,
  ui.Offset c,
  double r,
  double a,
) {
  vfxFillDrop(canvas, c, r * 1.05, a, m.mid, 0.88);
  vfxFillDrop(canvas, c, r * 0.5, a, m.glint, 0.9);
}

/// The fallback dart: a slim shard of the element with a lit edge.
void _drawSliver(
  ui.Canvas canvas,
  VfxMaterial m,
  ui.Offset c,
  double r,
  double a,
) {
  vfxFillShard(canvas, c, r * 2.6, r * 0.7, a, m.mid, 0.9);
  vfxFillShard(canvas, c, r * 1.6, r * 0.25, a, m.glint, 0.85);
}

/// The fallback shot: a drop of the element's material, its head lit.
void _drawDrop(
  ui.Canvas canvas,
  VfxMaterial m,
  ui.Offset c,
  double r,
  double a,
) {
  vfxFillDrop(canvas, c, r, a, m.mid, 0.9);
  vfxFillDrop(canvas, c, r * 0.48, a, m.glint, 0.9);
}

/// A parked piece no family painter claimed — a trail drop, a puff, a seed
/// zone. If it ticks an area, the light pools over exactly that area
/// (`max(24, effectRadius)`, what the tick uses); otherwise over its snare,
/// or its contact radius. A small body of its material marks the centre.
void _drawParkedPiece(
  ui.Canvas canvas,
  Projectile p,
  ui.Offset c,
  double time,
) {
  final m = vfxMaterial(p.element);
  final hitR = _hitRadius(p);
  // Fades in and out with its own life so a trail dissolves rather than
  // blinking off.
  final fade = (p.life / 0.4).clamp(0.0, 1.0);
  // A contact drop — a trail of them laid every tenth of a second — is one
  // soft pool of its light: drops that overlap make a lane, where a lit
  // pool plus a blob each made a dotted line at twice the draws.
  if (p.tickEffect == AbilityEffectKind.none && p.snareRadius <= 0) {
    vfxSpill(canvas, c, hitR * 2.2, m.light, 0.4 * fade);
    return;
  }
  final zoneR = p.tickEffect != AbilityEffectKind.none
      ? max(24.0, p.effectRadius)
      : p.snareRadius;
  // Flatter than vfxSpill, so the light holds out to the zone's edge before
  // it dissolves: the pool shows the reach, not just the centre. One unit
  // gradient per colour, drawn scaled (it was a new shader per piece per
  // frame).
  final rgb = m.light.toARGB32() & 0xFFFFFF;
  _zoneFill
    ..color = ui.Color.fromRGBO(255, 255, 255, 0.10 * fade)
    ..shader = _poolShaders[rgb] ??= ui.Gradient.radial(
      ui.Offset.zero,
      1,
      [
        ui.Color(0xFF000000 | rgb),
        ui.Color(0xB3000000 | rgb),
        ui.Color(0x00000000 | rgb),
      ],
      const [0.0, 0.62, 1.0],
    );
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(zoneR);
  canvas.drawCircle(ui.Offset.zero, 1, _zoneFill);
  canvas.restore();
  _zoneFill.shader = null;
  vfxFillBlob(
    canvas,
    c,
    hitR,
    identityHashCode(p) % 53,
    m.mid,
    0.7 * fade,
    n: 8,
    wobble: 0.24,
  );
}
