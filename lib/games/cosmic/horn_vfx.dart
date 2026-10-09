import 'dart:math';
import 'dart:ui' as ui;

import 'cosmic_data.dart';
import 'cosmic_projectile_vfx.dart' show ZoneVfxEmit;
import 'vfx_shapes.dart';

/// Horn's art: the wake a creature tears while it rams, the slam when it
/// lands, the ground it leaves behind, and the few effects that live on the
/// creature or its victims (Plant's root, Blood's price, Poison's reach).
/// Shared by survival, open space and dungeons so a horn looks the same in all
/// three.
///
/// Written in the Mask traps' material language, not the old vector-glyph
/// one: muted materials instead of saturated element color, filled tapered
/// shapes instead of hairlines, and light that pools on the ground through a
/// radial gradient rather than a stack of flat discs or a blur. The first
/// pass at this file drew cracks and arcs as bright strokes and read as clip
/// art; the only lines left are Lightning's, because lightning is a line.
///
/// Budget: no blur, no offscreen layers, a handful of paths per effect.

// ─────────────────────────────────────────────────────────────────────────
// Materials
// ─────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────
// Shape helpers (the chunk and the bolt live in vfx_shapes.dart — Let's
// craters throw the same stone)
// ─────────────────────────────────────────────────────────────────────────

final ui.Paint _fill = ui.Paint();

// ─────────────────────────────────────────────────────────────────────────
// The wake
// ─────────────────────────────────────────────────────────────────────────

/// The wake behind a charging horn, in the creature's local coordinates
/// (origin at the body, unrotated). [angle] is the heading.
void drawHornChargeWake({
  required ui.Canvas canvas,
  required ui.Color color,
  required double angle,
  required double sweepRadius,
  required double overshootDistance,
  String? element,
  double time = 0,
  double scale = 1,
}) {
  final m = vfxMaterial(element);
  final width = (sweepRadius / 48.0).clamp(0.75, 2.0) * scale;
  final length = (overshootDistance / 80.0).clamp(0.8, 1.9) * scale;
  final dir = vfxPolar(angle, 1);
  final perp = ui.Offset(-dir.dy, dir.dx);
  final isDark = element == 'Dark';

  // Light thrown on the ground by the thing ramming through it.
  vfxSpill(
    canvas,
    dir * 4.0 * scale,
    30 * width,
    m.light,
    isDark ? 0.10 : 0.22,
  );

  // The wake: torn from the flanks of the body to a point behind, fading
  // out along its length.
  final wakeLen = 84.0 * length;
  final half = 14.0 * width;
  final flutter = sin(time * 17.0) * 2.0 * scale;
  final tip = -dir * wakeLen + perp * flutter;
  ui.Path wakePath(double h, double len) {
    final t = -dir * len + perp * flutter;
    return ui.Path()
      ..moveTo(perp.dx * h, perp.dy * h)
      ..quadraticBezierTo(
        -dir.dx * len * 0.45 + perp.dx * h * 0.9,
        -dir.dy * len * 0.45 + perp.dy * h * 0.9,
        t.dx,
        t.dy,
      )
      ..quadraticBezierTo(
        -dir.dx * len * 0.45 - perp.dx * h * 0.9,
        -dir.dy * len * 0.45 - perp.dy * h * 0.9,
        -perp.dx * h,
        -perp.dy * h,
      )
      ..close();
  }

  final body = isDark ? m.ink : m.mid;
  _fill
    ..color = const ui.Color(0xFFFFFFFF)
    ..shader = ui.Gradient.linear(ui.Offset.zero, tip, [
      body.withValues(alpha: isDark ? 0.62 : 0.40),
      body.withValues(alpha: 0),
    ]);
  canvas.drawPath(wakePath(half, wakeLen), _fill);
  _fill.shader = ui.Gradient.linear(ui.Offset.zero, tip * 0.6, [
    m.glint.withValues(alpha: isDark ? 0.16 : 0.22),
    m.glint.withValues(alpha: 0),
  ]);
  canvas.drawPath(wakePath(half * 0.42, wakeLen * 0.6), _fill);
  _fill.shader = null;

  // Bow wave: tapered crescents shoved ahead of the body. This is what makes
  // the horn read as pushing rather than gliding.
  final bowR = 21.0 * width;
  final bowC = -dir * bowR * 0.32;
  final surge = 1.0 + 0.04 * sin(time * 22.0);
  vfxFillPath(
    canvas,
    vfxCrescent(bowC, bowR * surge, 7.5 * scale, angle, 2.3),
    m.glint,
    isDark ? 0.3 : 0.4,
  );

  _drawWakeDebris(canvas, element, m, dir, perp, wakeLen, half, time, scale);
}

void _drawWakeDebris(
  ui.Canvas canvas,
  String? element,
  VfxMaterial m,
  ui.Offset dir,
  ui.Offset perp,
  double wakeLen,
  double half,
  double time,
  double scale,
) {
  if (element == null || element == 'Air' || element == 'Light') return;
  final heading = atan2(dir.dy, dir.dx);

  if (element == 'Lightning') {
    final step = (time * 18.0).floorToDouble();
    for (var b = 0; b < 2; b++) {
      final side = b == 0 ? 1.0 : -1.0;
      vfxBolt(
        canvas,
        perp * half * 0.5 * side,
        -dir * wakeLen * 0.8 + perp * half * 0.4 * side,
        step + b * 7,
        m,
        0.9,
        jag: 0.3,
      );
    }
    return;
  }

  if (element == 'Water') {
    // Bow spray peeling off both flanks.
    for (final side in const [-1.0, 1.0]) {
      final spine = <ui.Offset>[];
      for (var k = 0; k <= 6; k++) {
        final t = k / 6;
        spine.add(
          perp * half * side * (1.0 + 1.3 * sin(t * pi * 0.6)) -
              dir * wakeLen * 0.55 * t,
        );
      }
      vfxFillPath(canvas, vfxRibbon(spine, 5.0 * scale, 0.5), m.glint, 0.30);
    }
  }

  // Pieces scrolling back down the wake, thrown outward and fading.
  const count = 5;
  for (var i = 0; i < count; i++) {
    final f = ((i / count) + time * 2.4) % 1.0;
    final side = i.isEven ? 1.0 : -1.0;
    final spread =
        half * (0.3 + f * 1.3) * side * (0.6 + 0.4 * vfxHash(i + 3.0));
    final p = -dir * (8.0 * scale + wakeLen * 0.9 * f) + perp * spread;
    final fade = 1.0 - f;
    final s = scale * (1.0 + 0.7 * fade);
    final back = heading + pi + side * 0.4;
    switch (element) {
      case 'Fire':
        vfxFillPath(canvas, vfxDrop(p, 2.6 * s, back), m.mid, 0.75 * fade);
        vfxFillPath(canvas, vfxDrop(p, 1.3 * s, back), m.glint, 0.85 * fade);
      case 'Lava':
        vfxChunk(canvas, p, 3.6 * s, i * 5.0, m, alpha: fade, rot: time * 5);
        _fill.color = m.glint.withValues(alpha: 0.85 * fade);
        canvas.drawCircle(p, 1.2 * s, _fill);
      case 'Ice':
        vfxFillPath(
          canvas,
          vfxShard(p, 6.0 * s, 1.8 * s, back),
          m.mid,
          0.8 * fade,
        );
        vfxFillPath(
          canvas,
          vfxShard(p, 4.0 * s, 0.8 * s, back),
          m.glint,
          0.6 * fade,
        );
      case 'Crystal':
        vfxChunk(
          canvas,
          p,
          3.4 * s,
          i * 3.0,
          m,
          alpha: fade,
          rot: back,
          sides: 4,
        );
      case 'Earth':
        vfxChunk(
          canvas,
          p,
          3.6 * s,
          i * 7.0,
          m,
          alpha: fade,
          rot: time * 6 + i,
        );
      case 'Dust' when i.isEven:
        vfxChunk(
          canvas,
          p,
          3.6 * s,
          i * 7.0,
          m,
          alpha: fade,
          rot: time * 6 + i,
        );
      case 'Steam' || 'Dust' || 'Spirit':
        vfxSpill(canvas, p, (4.0 + 9.0 * f) * scale, m.glint, 0.28 * fade);
      case 'Mud':
        vfxFillPath(
          canvas,
          vfxBlob(p, 3.4 * s, i * 4.0, n: 7, wobble: 0.3),
          m.mid,
          0.85 * fade,
        );
      case 'Plant':
        vfxFillPath(canvas, vfxLeaf(p, 7.0 * s, back + i), m.mid, 0.9 * fade);
      case 'Poison' || 'Blood':
        vfxFillPath(canvas, vfxDrop(p, 2.2 * s, back), m.mid, 0.9 * fade);
        _fill.color = m.glint.withValues(alpha: 0.5 * fade);
        canvas.drawCircle(p + dir * 0.6 * s, 0.8 * s, _fill);
      case 'Dark':
        vfxFillPath(
          canvas,
          vfxBlob(p, 3.0 * s, i * 2.0, n: 7, wobble: 0.3),
          m.ink,
          0.8 * fade,
        );
      default:
        break;
    }
  }

  if (element == 'Spirit') {
    // Afterimages of the ram's own head, left hanging in the air.
    for (var i = 0; i < 2; i++) {
      final f = ((i / 2) + time * 1.8) % 1.0;
      final g = -dir * (14.0 + 36.0 * f) * scale;
      vfxFillPath(
        canvas,
        vfxCrescent(g, half * 1.1, 4.0 * scale, heading, 1.8),
        m.glint,
        0.30 * (1 - f),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// One-shot effects: slam, sacrifice, siphon
// ─────────────────────────────────────────────────────────────────────────

enum HornFxKind { slam, sacrifice, siphon }

/// One short-lived horn effect. Each game owns a list; stepping and painting
/// are shared — the same arrangement as [LetSkyfallImpact].
class HornFx {
  HornFx._({
    required this.kind,
    required this.position,
    required this.element,
    required this.duration,
    this.angle = 0,
    this.radius = 0,
    this.target = ui.Offset.zero,
  }) : age = 0;

  /// A charge landing. [radius] is the final sweep — what the slam hit.
  factory HornFx.slam({
    required ui.Offset position,
    required double angle,
    required double radius,
    String? element,
  }) => HornFx._(
    kind: HornFxKind.slam,
    position: position,
    angle: angle,
    radius: radius,
    element: element,
    duration: switch (element) {
      'Earth' || 'Lava' => 0.66,
      _ => 0.5,
    },
  );

  /// Blood paying for its cast: the horn opens its own veins.
  factory HornFx.sacrifice({required ui.Offset position}) => HornFx._(
    kind: HornFxKind.sacrifice,
    position: position,
    element: 'Blood',
    duration: 0.6,
    radius: 46,
  );

  /// Blood taking it back: a kill bleeds toward the horn.
  factory HornFx.siphon({required ui.Offset from, required ui.Offset to}) =>
      HornFx._(
        kind: HornFxKind.siphon,
        position: from,
        target: to,
        element: 'Blood',
        duration: 0.5,
      );

  final HornFxKind kind;
  final ui.Offset position;
  final ui.Offset target;
  final double angle;
  final double radius;
  final String? element;
  final double duration;
  double age;

  double get t => (age / duration).clamp(0.0, 1.0);
  bool get dead => age >= duration;
}

void updateHornFx(List<HornFx> fx, double dt) {
  if (fx.isEmpty) return;
  for (final f in fx) {
    f.age += dt;
  }
  fx.removeWhere((f) => f.dead);
}

void pushHornFx(List<HornFx> fx, HornFx f, {int cap = 10}) {
  if (fx.length >= cap) fx.removeAt(0);
  fx.add(f);
}

void drawHornFx(
  ui.Canvas canvas,
  List<HornFx> fx, {
  bool reduceAmbient = false,
}) {
  for (final f in fx) {
    switch (f.kind) {
      case HornFxKind.slam:
        drawHornSlam(canvas: canvas, fx: f, reduceAmbient: reduceAmbient);
      case HornFxKind.sacrifice:
        _drawSacrifice(canvas, f);
      case HornFxKind.siphon:
        _drawSiphon(canvas, f);
    }
  }
}

/// The slam. The ground darkens where it was struck, a shock leaves it
/// heaviest in the direction of the ram, and the element is thrown forward
/// as debris. Directional on purpose: a Let meteor lands from above and
/// craters round; a horn hits something in front of it.
void drawHornSlam({
  required ui.Canvas canvas,
  required HornFx fx,
  bool reduceAmbient = false,
}) {
  final t = fx.t;
  final fade = 1.0 - t;
  if (fade <= 0.01) return;
  final m = vfxMaterial(fx.element);
  final c = fx.position;
  final r = fx.radius.clamp(40.0, 170.0);
  final a0 = fx.angle;
  final ease = 1.0 - pow(1.0 - t, 3).toDouble();
  final element = fx.element;
  final isDark = element == 'Dark';
  final seed = c.dx * 0.13 + c.dy * 0.07;

  // Struck ground: a dark bruise that settles in and fades last.
  vfxFillPath(
    canvas,
    vfxBlob(c + vfxPolar(a0, r * 0.1), r * 0.34, seed, n: 9, wobble: 0.3),
    m.ink,
    (isDark ? 0.7 : 0.38) * sqrt(fade),
  );
  // The light of the hit, gone quickly.
  final flash = fade * fade;
  vfxSpill(canvas, c + vfxPolar(a0, r * 0.2), r * 0.8, m.light, 0.26 * flash);
  if (!isDark) {
    vfxSpill(canvas, c, r * 0.28, m.glint, 0.7 * flash * fade);
  }

  // Shock: a soft ring the size of the hit, and a heavy crescent where the
  // ram was pointing.
  final shockR = r * (0.3 + 0.72 * ease);
  // Dust thrown up behind the front, then the front itself — thin, bright,
  // tapering away to nothing at its ends so it never closes into a hoop.
  vfxFillPath(
    canvas,
    vfxCrescent(c, shockR * 0.94, r * 0.2 * fade + 2, a0, 1.9),
    m.mid,
    0.26 * fade,
  );
  vfxFillPath(
    canvas,
    vfxCrescent(c, shockR, r * 0.07 * fade + 1.5, a0, 2.2),
    m.glint,
    0.6 * fade * fade,
  );

  if (element == 'Lightning') {
    final step = (fx.age * 16).floorToDouble();
    for (var i = 0; i < (reduceAmbient ? 2 : 4); i++) {
      final a = a0 + (i / 3 - 0.5) * 1.8;
      vfxBolt(
        canvas,
        c + vfxPolar(a, r * 0.1),
        c + vfxPolar(a, r * (0.35 + 0.5 * ease)),
        seed + step + i * 5,
        m,
        fade,
        jag: 0.35,
        segs: 4,
      );
    }
    return;
  }

  // Debris thrown forward. Dark runs backwards: its pieces fall in.
  final count = reduceAmbient ? 3 : 7;
  for (var i = 0; i < count; i++) {
    final spreadF = i / (count - 1) - 0.5;
    final a = a0 + spreadF * 1.9 + (vfxHash(seed + i) - 0.5) * 0.3;
    final reach = 0.7 + 0.3 * vfxHash(seed + i * 3.1);
    final travel = isDark
        ? r * (0.95 - 0.8 * ease) * reach
        : r * (0.18 + 0.72 * ease) * reach * (1 - spreadF.abs() * 0.3);
    final p = c + vfxPolar(a, travel);
    final s = r * 0.055 * (0.8 + 0.5 * vfxHash(seed + i * 7.7));
    switch (element) {
      case 'Fire':
        vfxFillPath(canvas, vfxDrop(p, s * 0.8, a), m.mid, 0.8 * fade);
        vfxFillPath(canvas, vfxDrop(p, s * 0.4, a), m.glint, 0.9 * fade);
      case 'Lava' || 'Earth' || 'Mud' || 'Dust':
        vfxChunk(
          canvas,
          p,
          s * (element == 'Dust' ? 0.7 : 1.1),
          seed + i * 5,
          m,
          alpha: fade,
          rot: a + t * 4,
        );
        if (element == 'Lava') {
          _fill.color = m.glint.withValues(alpha: 0.8 * fade);
          canvas.drawCircle(p, s * 0.35, _fill);
        }
      case 'Ice' || 'Crystal' || 'Light':
        vfxFillPath(
          canvas,
          vfxShard(p, s * 2.0, s * 0.6, a),
          m.mid,
          0.85 * fade,
        );
        vfxFillPath(
          canvas,
          vfxShard(p, s * 1.3, s * 0.25, a),
          m.glint,
          0.7 * fade,
        );
      case 'Water' || 'Poison' || 'Blood':
        vfxFillPath(canvas, vfxDrop(p, s * 0.7, a), m.mid, 0.9 * fade);
        _fill.color = m.glint.withValues(alpha: 0.5 * fade);
        canvas.drawCircle(p + vfxPolar(a, s * 0.2), s * 0.22, _fill);
      case 'Steam' || 'Spirit' || 'Air':
        vfxSpill(canvas, p, s * (1.5 + 3.0 * t), m.glint, 0.3 * fade);
      case 'Plant':
        vfxFillPath(
          canvas,
          vfxLeaf(p, s * 2.2, a + i * 0.8),
          m.mid,
          0.9 * fade,
        );
      case 'Dark':
        vfxFillPath(
          canvas,
          vfxBlob(p, s * 0.9, seed + i, n: 7, wobble: 0.3),
          m.ink,
          0.85 * fade,
        );
      default:
        _fill.color = m.glint.withValues(alpha: 0.6 * fade);
        canvas.drawCircle(p, s * 0.5, _fill);
    }
  }
}

void _drawSacrifice(ui.Canvas canvas, HornFx fx) {
  final t = fx.t;
  final fade = 1.0 - t;
  final m = vfxMaterial('Blood');
  final c = fx.position;
  final ease = 1.0 - pow(1.0 - t, 3).toDouble();
  final seed = c.dx * 0.11;
  // The wound opening around the horn.
  vfxFillPath(
    canvas,
    vfxBlob(c, fx.radius * (0.35 + 0.35 * ease), seed, wobble: 0.22),
    m.ink,
    0.55 * fade,
  );
  vfxSpill(canvas, c, fx.radius * 1.2, m.light, 0.32 * fade * fade);
  for (var i = 0; i < 8; i++) {
    final a = i * pi / 4 + vfxHash(seed + i) * 0.5;
    final p = c + vfxPolar(a, fx.radius * (0.25 + 0.75 * ease));
    vfxFillPath(canvas, vfxDrop(p, 3.4 * (1 - 0.4 * t), a), m.mid, 0.9 * fade);
  }
}

void _drawSiphon(ui.Canvas canvas, HornFx fx) {
  final t = fx.t;
  final m = vfxMaterial('Blood');
  final from = fx.position;
  final to = fx.target;
  final d = to - from;
  final len = d.distance;
  if (len < 4) return;
  final n = ui.Offset(-d.dy, d.dx) / len;
  final bow = n * len * 0.22 * (vfxHash(from.dx) > 0.5 ? 1 : -1);
  ui.Offset at(double f) {
    // Quadratic curve from the kill to the horn.
    final a = from + (from + d * 0.5 + bow - from) * f;
    final b = (from + d * 0.5 + bow) + (to - (from + d * 0.5 + bow)) * f;
    return a + (b - a) * f;
  }

  vfxSpill(canvas, from, 18, m.light, 0.3 * (1 - t));
  for (var i = 0; i < 5; i++) {
    final f = (t * 1.25 - i * 0.07).clamp(0.0, 1.0);
    if (f <= 0 || f >= 1) continue;
    final p = at(f);
    final dir = at(min(1.0, f + 0.05)) - p;
    final a = atan2(dir.dy, dir.dx);
    final s = 3.6 - i * 0.4;
    vfxFillPath(canvas, vfxDrop(p, s, a), m.mid, 0.9);
    _fill.color = m.glint.withValues(alpha: 0.6);
    canvas.drawCircle(p, s * 0.3, _fill);
  }
  if (t > 0.75) {
    vfxSpill(canvas, to, 22, m.light, 0.4 * (1 - t) * 4);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Ground: what a horn leaves behind
// ─────────────────────────────────────────────────────────────────────────

/// Paints a horn impact zone, phantom or orbiting shard. Returns false for
/// anything it does not own (moving horn projectiles fall through to
/// [drawHornMote]).
bool drawHornZoneVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required double time,
}) {
  final element = projectile.element;
  if (element == null) return false;
  final m = vfxMaterial(element);
  final c = position;
  final seed = _seedFor(projectile);
  final vs = projectile.visualScale.clamp(0.75, 4.0).toDouble();

  if (element == 'Crystal' &&
      projectile.orbitRadius > 0 &&
      projectile.holdOrbit) {
    _drawCrystalWard(canvas, c, m, seed, time, vs);
    return true;
  }
  if (element == 'Spirit' && projectile.decoy && !projectile.stationary) {
    _drawPhantom(canvas, c, m, projectile.angle, time, vs, seed);
    return true;
  }
  if (!projectile.stationary) return false;

  final effectR = projectile.effectRadius > 0
      ? projectile.effectRadius
      : projectile.radiusMultiplier * 20 + 20;
  switch (element) {
    case 'Light' when projectile.reflectsProjectiles:
      _drawBarrier(canvas, c, m, projectile, time);
    case 'Fire':
      drawVfxBurningGround(canvas, c, m, effectR * 0.8, seed, time);
    case 'Lightning':
      _drawStormScar(canvas, c, m, effectR * 0.55, seed, time);
    case 'Water':
      _drawWhirlpool(canvas, c, m, effectR * 0.75, seed, time);
    case 'Ice':
      _drawIceBlock(canvas, c, m, effectR * 0.5, seed, time);
    case 'Steam':
      _drawGeyser(canvas, c, m, effectR * 0.5, seed, time);
    case 'Earth':
      _drawCairn(canvas, c, m, seed, time, vs);
    case 'Dust':
      _drawCyclone(canvas, c, m, effectR * 0.65, seed, time);
    case 'Dark':
      drawVfxVoid(canvas, c, m, effectR * 0.55, seed, time);
    default:
      vfxSpill(canvas, c, effectR * 0.6, m.light, 0.18);
  }
  return true;
}

double _seedFor(Projectile p) =>
    (p.orbitAngle * 7.1 + p.angle * 3.3 + p.position.dx * 0.011) % 97.0 +
    identityHashCode(p) % 89;

/// A horn projectile in flight (Lava's homing flames and the like): a
/// comet of its material, never an arrowhead.
void drawHornMote({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required double time,
}) {
  final m = vfxMaterial(projectile.element);
  final vs = projectile.visualScale.clamp(0.75, 3.0).toDouble();
  final a = projectile.angle;
  vfxSpill(canvas, position, 14 * vs, m.light, 0.26);
  vfxFillPath(canvas, vfxDrop(position, 4.2 * vs, a), m.mid, 0.9);
  vfxFillPath(canvas, vfxDrop(position, 2.2 * vs, a), m.glint, 0.9);
}

/// Char with fire still in it — Horn's lane, Pip's kill pools.
void drawVfxBurningGround(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double r,
  double seed,
  double time,
) {
  final flicker = 0.85 + 0.15 * sin(time * 9 + seed);
  // Char on the stone, then the light of what is still burning in it.
  vfxFillPath(canvas, vfxBlob(c, r * 0.62, seed, wobble: 0.24), m.ink, 0.6);
  vfxSpill(canvas, c, r * 1.1, m.light, 0.2 * flicker);
  // Embers in the char: short glowing slivers, fixed where they fell.
  for (var i = 0; i < 4; i++) {
    final a = vfxHash(seed + i) * pi * 2;
    final p = c + vfxPolar(a, r * 0.35 * vfxHash(seed + i * 2.2));
    final glow = 0.5 + 0.4 * sin(time * 5 + i * 1.9);
    vfxFillPath(
      canvas,
      vfxShard(p, r * 0.12, r * 0.025, a + 1.2),
      m.glint,
      0.55 * glow,
    );
  }
  // Flame tongues, licking and leaning.
  for (var i = 0; i < 3; i++) {
    final base =
        c +
        vfxPolar(vfxHash(seed + i * 4.4) * pi * 2, r * 0.3 * vfxHash(seed + i));
    final h = r * (0.34 + 0.12 * sin(time * 7 + i * 2.1 + seed));
    final lean = sin(time * 3 + i) * 0.3;
    final a = -pi / 2 + lean;
    vfxFillPath(
      canvas,
      vfxDrop(base + vfxPolar(a, h * 0.5), h * 0.28, a),
      m.mid,
      0.6,
    );
    vfxFillPath(
      canvas,
      vfxDrop(base + vfxPolar(a, h * 0.35), h * 0.15, a),
      m.glint,
      0.65,
    );
  }
}

void _drawStormScar(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double r,
  double seed,
  double time,
) {
  final pulse = 0.75 + 0.25 * sin(time * 14 + seed);
  vfxFillPath(canvas, vfxBlob(c, r * 0.45, seed, wobble: 0.28), m.ink, 0.5);
  vfxSpill(canvas, c, r * 1.2, m.light, 0.3 * pulse);
  vfxSpill(canvas, c, r * 0.3, m.glint, 0.5 * pulse);
  final step = (time * 14).floorToDouble();
  for (var i = 0; i < 4; i++) {
    final a = seed + i * pi / 2 + vfxHash(step + i) * 0.8;
    vfxBolt(
      canvas,
      c + vfxPolar(a, r * 0.12),
      c + vfxPolar(a, r * (0.6 + 0.4 * vfxHash(step + i * 3))),
      step * 3 + i,
      m,
      0.8,
      segs: 4,
    );
  }
}

void _drawWhirlpool(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double r,
  double seed,
  double time,
) {
  // Ink-dark water, a ragged edge that breathes.
  final breathe = 1 + 0.03 * sin(time * 1.3);
  vfxFillPath(
    canvas,
    vfxBlob(c, r * breathe, seed, n: 16, wobble: 0.06),
    m.ink,
    0.74,
  );
  vfxSoftRing(canvas, c, r * 0.96 * breathe, r * 0.1, m.mid, 0.35);
  // The drain: arms winding inward, turning.
  final spin = time * 1.7;
  for (var i = 0; i < 5; i++) {
    vfxFillPath(
      canvas,
      vfxSpiralArm(c, r * 0.92, spin + i * pi * 2 / 5, 2.6, r * 0.14),
      m.mid,
      0.34,
    );
  }
  // Silver catching on the surface, riding the current.
  for (var i = 0; i < 4; i++) {
    final a = spin * 1.3 + i * pi / 2;
    vfxFillPath(
      canvas,
      vfxCrescent(c, r * (0.35 + 0.14 * i), 1.6, a, 0.5),
      m.glint,
      0.3,
    );
  }
  vfxSpill(canvas, c, r * 0.3, const ui.Color(0xFF000000), 0.6);
}

void _drawIceBlock(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double r,
  double seed,
  double time,
) {
  vfxSpill(canvas, c, r * 1.7, m.light, 0.14);
  vfxChunk(
    canvas,
    c,
    r,
    seed,
    m,
    rot: vfxHash(seed) * pi,
    sides: 7,
    faceAlpha: 0.55,
  );
  // A second, smaller spur so a run of segments reads as a jagged ridge.
  vfxChunk(
    canvas,
    c + vfxPolar(vfxHash(seed + 9) * pi * 2, r * 0.55),
    r * 0.55,
    seed + 4,
    m,
    rot: vfxHash(seed + 5) * pi,
    sides: 5,
    faceAlpha: 0.5,
  );
  // A slow cold shimmer inside the ice.
  final shimmer = 0.5 + 0.5 * sin(time * 1.4 + seed);
  vfxFillPath(
    canvas,
    vfxShard(c, r * 0.55, r * 0.07, vfxHash(seed + 2) * pi),
    m.glint,
    0.18 + 0.2 * shimmer,
  );
}

void _drawGeyser(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double r,
  double seed,
  double time,
) {
  // A wet vent in the stone.
  vfxSpill(canvas, c, r * 1.3, m.light, 0.14);
  vfxFillPath(canvas, vfxBlob(c, r * 0.42, seed, wobble: 0.2), m.ink, 0.75);
  vfxSpill(canvas, c, r * 0.6, m.mid, 0.3);
  // The plume, rising and spreading as it goes.
  for (var i = 0; i < 6; i++) {
    final ph = (time * 0.85 + i / 6 + vfxHash(seed)) % 1.0;
    final p = c + ui.Offset(sin(i * 2.1 + ph * 3) * r * 0.22, -ph * r * 0.95);
    vfxSpill(canvas, p, r * (0.2 + 0.4 * ph), m.glint, 0.34 * sin(ph * pi));
  }
}

void _drawCairn(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double seed,
  double time,
  double vs,
) {
  final r = 30.0 * (vs / 3.0).clamp(0.8, 1.3);
  // Tremor: the substitute pounds the ground on a slow beat.
  final beat = (time / 1.2 + vfxHash(seed)) % 1.0;
  vfxSoftRing(
    canvas,
    c,
    r * (1.1 + 2.4 * beat),
    r * (0.5 + 0.4 * beat),
    m.light,
    0.14 * (1 - beat),
  );
  vfxFillPath(canvas, vfxBlob(c, r * 1.7, seed, wobble: 0.18), m.ink, 0.42);
  vfxSpill(canvas, c, r * 2.0, m.light, 0.12);
  // A cairn of stacked, faceted stones — the horn's stand-in.
  for (var i = 0; i < 5; i++) {
    final a = seed + i * 2.399;
    final p = c + vfxPolar(a, r * 0.6 * (0.6 + 0.4 * vfxHash(seed + i)));
    vfxChunk(canvas, p, r * 0.42, seed + i * 3, m, rot: a);
  }
  vfxChunk(
    canvas,
    c + const ui.Offset(0, -4),
    r * 0.62,
    seed + 17,
    m,
    rot: seed,
    sides: 7,
    faceAlpha: 0.8,
  );
  // Warm light in the seams on each beat.
  vfxSpill(canvas, c, r * 0.5, m.glint, 0.3 * (1 - beat) * (1 - beat));
}

void _drawCyclone(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double r,
  double seed,
  double time,
) {
  vfxSpill(canvas, c, r * 1.15, m.light, 0.16);
  vfxFillPath(canvas, vfxBlob(c, r * 0.36, seed, wobble: 0.2), m.ink, 0.35);
  for (var layer = 0; layer < 3; layer++) {
    final spin = time * (2.6 + layer * 0.9) + layer * 1.3;
    for (var i = 0; i < 3; i++) {
      vfxFillPath(
        canvas,
        vfxSpiralArm(
          c,
          r * (1.0 - layer * 0.18),
          spin + i * pi * 2 / 3,
          1.9,
          r * (0.12 - layer * 0.02),
          reach: 0.7,
        ),
        layer == 2 ? m.glint : m.mid,
        0.22 + layer * 0.04,
      );
    }
  }
  for (var i = 0; i < 8; i++) {
    final a = time * (3.2 + vfxHash(seed + i)) + i * 0.785;
    final p = c + vfxPolar(a, r * (0.4 + 0.5 * vfxHash(seed + i * 2)));
    _fill.color = m.glint.withValues(alpha: 0.5);
    canvas.drawCircle(p, 1.2, _fill);
  }
}

/// A hole in the ground things fall into — Horn's void, Pip's black hole.
void drawVfxVoid(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double r,
  double seed,
  double time,
) {
  vfxSpill(canvas, c, r * 1.2, m.light, 0.12);
  for (var layer = 3; layer >= 0; layer--) {
    vfxFillPath(
      canvas,
      vfxBlob(
        c,
        r * (0.4 + layer * 0.16),
        seed + layer + time * 0.2,
        n: 14,
        wobble: 0.06,
      ),
      m.ink,
      0.26 + (3 - layer) * 0.14,
    );
  }
  // Wisps falling in, fading as they cross the lip.
  for (var arm = 0; arm < 5; arm++) {
    final ph = (time * 0.35 + arm * 0.618) % 1.0;
    final a = arm * 2.399 + ph * 1.4;
    vfxFillPath(
      canvas,
      vfxSpiralArm(c, r * (1.05 - ph * 0.4), a, 1.2, r * 0.05, reach: 0.6),
      m.glint,
      0.3 * sin(ph * pi),
    );
  }
}

void _drawCrystalWard(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double seed,
  double time,
  double vs,
) {
  final r = 7.0 * (vs / 1.5).clamp(0.8, 1.4);
  vfxSpill(canvas, c, r * 2.6, m.light, 0.2);
  vfxChunk(
    canvas,
    c,
    r,
    seed,
    m,
    rot: time * 1.4 + seed,
    sides: 5,
    faceAlpha: 0.75,
  );
  final catchLight = 0.5 + 0.5 * sin(time * 3 + seed);
  vfxFillPath(
    canvas,
    vfxShard(c, r * 0.8, r * 0.14, time * 1.4 + seed),
    m.glint,
    0.3 + 0.4 * catchLight,
  );
}

void _drawPhantom(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  double heading,
  double time,
  double vs,
  double seed,
) {
  final r = 7.0 * (vs / 2.0).clamp(0.8, 1.4);
  final back = heading + pi;
  // A veil trailing away from where it drifts, rippling.
  final spine = <ui.Offset>[];
  for (var k = 0; k <= 8; k++) {
    final t = k / 8;
    final sway = sin(time * 4 + t * 5 + seed) * r * 0.5 * t;
    final d = vfxPolar(back, r * 4.0 * t);
    final n = vfxPolar(back + pi / 2, sway);
    spine.add(c + d + n);
  }
  vfxSpill(canvas, c, r * 3.2, m.light, 0.16);
  vfxFillPath(canvas, vfxRibbon(spine, r * 2.0, r * 0.2), m.mid, 0.34);
  vfxFillPath(canvas, vfxRibbon(spine, r * 1.1, 0.5), m.glint, 0.22);
  // The head, brightest where it is thickest.
  vfxSpill(canvas, c, r * 1.3, m.glint, 0.75);
}

void _drawBarrier(
  ui.Canvas canvas,
  ui.Offset c,
  VfxMaterial m,
  Projectile projectile,
  double time,
) {
  // Same footprint as the gameplay perimeter it reflects at.
  final domeR = max(60.0, projectile.radiusMultiplier * 20.0 + 70.0);
  final breathe = 0.88 + 0.12 * sin(time * 2.0 + projectile.life * 1.4);
  _fill
    ..color = const ui.Color(0xFFFFFFFF)
    ..shader = ui.Gradient.radial(
      c,
      domeR,
      [
        m.glint.withValues(alpha: 0.07 * breathe),
        m.light.withValues(alpha: 0.015),
        m.light.withValues(alpha: 0.05 * breathe),
        m.glint.withValues(alpha: 0.30 * breathe),
        m.glint.withValues(alpha: 0),
      ],
      const [0.0, 0.5, 0.88, 0.975, 1.0],
    );
  canvas.drawCircle(c, domeR, _fill);
  _fill.shader = null;
  // Sheen sliding slowly over the surface.
  for (var i = 0; i < 3; i++) {
    final a = time * 0.45 + i * pi * 2 / 3;
    vfxFillPath(
      canvas,
      vfxCrescent(c, domeR * 0.97, 5.0, a, 0.9),
      m.glint,
      0.22,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// On creatures
// ─────────────────────────────────────────────────────────────────────────

/// Plant's root, wrapped around an enemy of radius [r], in the enemy's local
/// coordinates. [strength] fades it as the root runs out.
void drawHornPlantRootWrap({
  required ui.Canvas canvas,
  required double r,
  required double time,
  double seed = 0,
  double strength = 1,
}) {
  final m = vfxMaterial('Plant');
  final a = strength.clamp(0.0, 1.0);
  // Three vines climbing round the body from outside, thick at the root.
  for (var v = 0; v < 3; v++) {
    final start = seed + v * pi * 2 / 3 + sin(time * 0.8 + v) * 0.08;
    final spine = <ui.Offset>[];
    for (var k = 0; k <= 9; k++) {
      final t = k / 9;
      spine.add(vfxPolar(start + t * 2.2, r * (1.55 - 0.75 * t)));
    }
    vfxFillPath(canvas, vfxRibbon(spine, r * 0.5, r * 0.1), m.ink, 0.92 * a);
    vfxFillPath(canvas, vfxRibbon(spine, r * 0.24, r * 0.05), m.mid, 0.9 * a);
    // Thorns along the outer half.
    for (var k = 2; k <= 6; k += 2) {
      final p = spine[k];
      final out = atan2(p.dy, p.dx);
      vfxFillPath(canvas, vfxShard(p, r * 0.22, r * 0.05, out), m.ink, 0.9 * a);
    }
    vfxFillPath(
      canvas,
      vfxLeaf(spine[5], r * 0.45, start + 2.2 + pi / 2),
      m.mid,
      0.8 * a,
    );
  }
}

/// Poison's always-on reach around the horn: a low haze thickening at the
/// edge of what it poisons. Local coordinates.
void drawHornPoisonAura({
  required ui.Canvas canvas,
  required double radius,
  required double time,
  double scale = 1,
}) {
  final m = vfxMaterial('Poison');
  final r = radius * scale;
  vfxSoftRing(canvas, ui.Offset.zero, r * 0.9, r * 0.14, m.light, 0.09);
  for (var i = 0; i < 5; i++) {
    final a = time * 0.18 + i * pi * 2 / 5;
    final p = vfxPolar(a, r * (0.78 + 0.08 * sin(time * 0.7 + i)));
    vfxSpill(canvas, p, r * 0.22, m.mid, 0.12);
  }
}

/// The small patches a moving horn paints as it goes: Fire's burning lane
/// behind a charge, Mud's sludge underfoot, the puffs of Poison's aura. Many
/// of these are alive at once, so each is a blob and a pool of light.
/// [fade] runs 1 → 0 as the patch expires.
void drawHornTrailPatch({
  required ui.Canvas canvas,
  required String element,
  required ui.Offset position,
  required double radius,
  required double time,
  double fade = 1,
}) {
  final m = vfxMaterial(element);
  final c = position;
  final seed = (c.dx * 0.071 + c.dy * 0.053) % 50;
  final a = fade.clamp(0.0, 1.0);
  switch (element) {
    case 'Fire':
      final flicker = 0.8 + 0.2 * sin(time * 9 + seed);
      vfxFillPath(
        canvas,
        vfxBlob(c, radius * 0.6, seed, n: 9, wobble: 0.28),
        m.ink,
        0.42 * a,
      );
      vfxSpill(canvas, c, radius * 1.1, m.light, 0.16 * flicker * a);
      for (var i = 0; i < 2; i++) {
        final ang = vfxHash(seed + i) * pi * 2;
        final p = c + vfxPolar(ang, radius * 0.3 * vfxHash(seed + i * 3));
        vfxFillPath(
          canvas,
          vfxShard(p, radius * 0.16, radius * 0.035, ang + 1.3),
          m.glint,
          (0.3 + 0.35 * sin(time * 6 + i * 2 + seed).abs()) * a,
        );
      }
    case 'Mud':
      vfxFillPath(
        canvas,
        vfxBlob(c, radius * 0.9, seed, n: 10, wobble: 0.26),
        m.mid,
        0.30 * a,
      );
      vfxFillPath(
        canvas,
        vfxBlob(c, radius * 0.5, seed + 3, n: 8, wobble: 0.3),
        m.ink,
        0.30 * a,
      );
      // A wet sheen, not a rim.
      vfxSpill(
        canvas,
        c + vfxPolar(vfxHash(seed) * pi * 2, radius * 0.25),
        radius * 0.35,
        m.glint,
        0.12 * a,
      );
    case 'Poison':
      vfxSpill(canvas, c, radius, m.mid, 0.3 * a);
      vfxSpill(canvas, c, radius * 0.5, m.light, 0.1 * a);
      for (var i = 0; i < 2; i++) {
        final ph = (time * 0.6 + i * 0.5 + vfxHash(seed)) % 1.0;
        final p =
            c +
            vfxPolar(vfxHash(seed + i) * pi * 2, radius * 0.4) +
            ui.Offset(0, -ph * radius * 0.3);
        _fill.color = m.glint.withValues(alpha: 0.35 * sin(ph * pi) * a);
        canvas.drawCircle(p, 1.4 + radius * 0.03, _fill);
      }
    default:
      vfxSpill(canvas, c, radius, m.light, 0.14 * a);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Particles and telegraphs
//
// What a horn throws into the world while it winds up, rams, brews and
// lingers — Cosmic Survival's own emitters, lifted as they were so every game
// draws them the same. Each writes into sinks the caller supplies (its
// particle pool, its beam list) and the caller keeps its own pool gates, so
// an emitter never decides how busy a frame may get. The only lines are the
// ones survival draws as lines: Crystal's shard dashes, Lightning's and
// Dark's arcs, the Spirit ring marker and the Light barrier's arc.
// ─────────────────────────────────────────────────────────────────────────

/// A short-lived beam segment, into the caller's beam list.
typedef HornBeamEmit =
    void Function(
      ui.Offset start,
      ui.Offset end,
      ui.Color color,
      double width,
      double life,
    );

const ui.Color _white = ui.Color(0xFFFFFFFF);

/// The flash color of a Lightning discharge (and its hit spark).
ui.Color get hornLightningFlashColor =>
    ui.Color.lerp(elementColor('Lightning'), _white, 0.55)!;

/// The hit spark a Lava kill's explosion ends on.
const ui.Color kHornLavaKillSparkColor = ui.Color(0xFFFFA040);

/// Lava: embers gathering round the horn while it builds to the slam.
/// [progress] runs 0 → 1. Caller gates on its particle pool (130).
void emitHornLavaChargeTelegraph(
  ui.Offset center,
  double progress,
  Random rng,
  ZoneVfxEmit emit,
) {
  final orbR = 18.0 + 14.0 * progress;
  final lavaColor = elementColor('Lava');
  const emberColor = ui.Color(0xFFFFB050);
  final spawnCount = 1 + (progress > 0.5 ? 1 : 0);
  for (var i = 0; i < spawnCount; i++) {
    final a = rng.nextDouble() * 2 * pi;
    final r = orbR * (1.0 + rng.nextDouble() * 0.6);
    emit(
      center.dx + cos(a) * r,
      center.dy + sin(a) * r,
      -cos(a) * (20 + 60 * progress),
      -sin(a) * (20 + 60 * progress),
      1.6 + rng.nextDouble() * 1.4,
      0.35 + rng.nextDouble() * 0.30,
      i.isEven ? lavaColor : emberColor,
    );
  }
}

/// Lightning: the storm brewing round a landed horn. [brewRemaining] counts
/// down from [HornRules.postDashBrew]. Caller gates on its pool (130).
void emitHornLightningStormBrew(
  ui.Offset center,
  double brewRemaining,
  Random rng,
  ZoneVfxEmit emit,
  HornBeamEmit beam,
) {
  const total = 3.0;
  final elapsed = (total - brewRemaining).clamp(0.0, total);
  final t = elapsed / total;
  final orbR = 18.0 + 30.0 * t;
  final base = elementColor('Lightning');
  final white = hornLightningFlashColor;
  final spawnCount = 1 + (t > 0.4 ? 1 : 0) + (t > 0.75 ? 1 : 0);
  for (var i = 0; i < spawnCount; i++) {
    final a = rng.nextDouble() * 2 * pi;
    final r = orbR * (1.0 + rng.nextDouble() * 0.7);
    final spd = 35 + 80 * t;
    emit(
      center.dx + cos(a) * r,
      center.dy + sin(a) * r,
      -cos(a) * spd,
      -sin(a) * spd,
      1.3 + rng.nextDouble() * 1.4,
      0.3 + rng.nextDouble() * 0.3,
      i.isEven ? base : white,
    );
  }
  if (rng.nextDouble() < 0.30 + t * 0.45) {
    final a1 = rng.nextDouble() * 2 * pi;
    final a2 = a1 + (rng.nextDouble() - 0.5) * 2.6;
    final r1 = orbR * (0.35 + rng.nextDouble() * 0.65);
    final r2 = orbR * (0.35 + rng.nextDouble() * 0.65);
    beam(
      ui.Offset(center.dx + cos(a1) * r1, center.dy + sin(a1) * r1),
      ui.Offset(center.dx + cos(a2) * r2, center.dy + sin(a2) * r2),
      white.withValues(alpha: 0.70 + 0.25 * t),
      1.4 + t * 1.4,
      0.08,
    );
  }
}

/// Lightning: the discharge — a storm of sparks fanning out from the
/// impact, fuller for a bigger blast. Spawns at most [budget] (survival
/// passes what is left of 145). The caller adds the
/// [hornLightningFlashColor] hit spark at [center].
void emitHornLightningChainBurst(
  ui.Offset center,
  double blastRadius,
  int budget,
  Random rng,
  ZoneVfxEmit emit,
) {
  final base = elementColor('Lightning');
  final white = hornLightningFlashColor;
  final count = (blastRadius * 0.28).clamp(40, 70).round();
  final spawn = min(count, max(0, budget));
  for (var i = 0; i < spawn; i++) {
    final a = rng.nextDouble() * 2 * pi;
    final r = blastRadius * (0.15 + rng.nextDouble() * 0.85);
    final spd = 60 + rng.nextDouble() * 180;
    emit(
      center.dx + cos(a) * (r * 0.2),
      center.dy + sin(a) * (r * 0.2),
      cos(a) * spd,
      sin(a) * spd,
      1.6 + rng.nextDouble() * 1.8,
      rng.nextDouble() < 0.4
          ? 0.7 + rng.nextDouble() * 0.5
          : 0.30 + rng.nextDouble() * 0.30,
      rng.nextBool() ? white : base,
    );
  }
}

/// Lava: the fire burst where a body fell in the window. The caller gates
/// the whole effect on its pool (140) and adds a [kHornLavaKillSparkColor]
/// hit spark at [center].
void emitHornLavaKillExplosion(ui.Offset center, Random rng, ZoneVfxEmit emit) {
  const orange = kHornLavaKillSparkColor;
  const yellow = ui.Color(0xFFFFE08A);
  for (var i = 0; i < 12; i++) {
    final a = i * pi / 6 + rng.nextDouble() * 0.4;
    final spd = 140 + rng.nextDouble() * 80;
    emit(
      center.dx,
      center.dy,
      cos(a) * spd,
      sin(a) * spd,
      2.0 + rng.nextDouble() * 1.8,
      0.35 + rng.nextDouble() * 0.25,
      i.isEven ? orange : yellow,
    );
  }
}

/// Dark: the singularity brewing through the void's wind-up. Caller gates
/// on its pool (130).
void emitHornDarkVoidBrew(
  ui.Offset center,
  double windUpRemaining,
  Random rng,
  ZoneVfxEmit emit,
  HornBeamEmit beam,
) {
  const totalWindUp = 5.0;
  final elapsed = (totalWindUp - windUpRemaining).clamp(0.0, totalWindUp);
  final t = elapsed / totalWindUp;
  final orbRadius = 16.0 + 36.0 * t;
  final spawnCount = 1 + (t > 0.4 ? 1 : 0) + (t > 0.75 ? 1 : 0);
  for (var i = 0; i < spawnCount; i++) {
    final a = rng.nextDouble() * 2 * pi;
    final r = orbRadius * (1.2 + rng.nextDouble() * 0.7);
    final speed = 40 + 90 * t;
    emit(
      center.dx + cos(a) * r,
      center.dy + sin(a) * r,
      -cos(a) * speed,
      -sin(a) * speed,
      1.4 + rng.nextDouble() * 1.6,
      0.35 + rng.nextDouble() * 0.30,
      i.isEven
          ? const ui.Color(0xFF1A0A2A)
          : ui.Color.lerp(elementColor('Dark'), _white, 0.25)!,
    );
  }
  if (rng.nextDouble() < 0.20 + t * 0.40) {
    final a1 = rng.nextDouble() * 2 * pi;
    final a2 = a1 + (rng.nextDouble() - 0.5) * 2.6;
    final r1 = orbRadius * (0.30 + rng.nextDouble() * 0.70);
    final r2 = orbRadius * (0.30 + rng.nextDouble() * 0.70);
    beam(
      ui.Offset(center.dx + cos(a1) * r1, center.dy + sin(a1) * r1),
      ui.Offset(center.dx + cos(a2) * r2, center.dy + sin(a2) * r2),
      const ui.Color(0xFFB89AFF).withValues(alpha: 0.55 + 0.25 * t),
      1.2 + t * 1.0,
      0.08,
    );
  }
}

/// Crystal: six shards orbiting the horn through its wind-up, the bulwark
/// it will carry. Caller gates on its beam list (22).
void emitHornCrystalOrbit(
  ui.Offset center,
  double windUpRemaining,
  HornBeamEmit beam,
) {
  const totalWindUp = 1.2;
  final elapsed = (totalWindUp - windUpRemaining).clamp(0.0, totalWindUp);
  final t = elapsed / totalWindUp;
  final orbitR = 28.0 + 24.0 * t;
  final spinPhase = elapsed * 5.0;
  final white = ui.Color.lerp(elementColor('Crystal'), _white, 0.55)!;
  for (var i = 0; i < 6; i++) {
    final a = spinPhase + i * pi * 2 / 6;
    final shardCenter = center + ui.Offset(cos(a), sin(a)) * orbitR;
    final tangent = ui.Offset(-sin(a), cos(a));
    final half = 3.2 + 2.0 * t;
    beam(
      shardCenter - tangent * half,
      shardCenter + tangent * half,
      white.withValues(alpha: 0.55 + 0.30 * t),
      2.4 + t * 1.4,
      0.05,
    );
  }
}

/// Spirit: phantoms swarming the horn through its wind-up. Caller gates on
/// its pool (130).
void emitHornSpiritSwarm(
  ui.Offset center,
  double windUpRemaining,
  Random rng,
  ZoneVfxEmit emit,
  HornBeamEmit beam,
) {
  const totalWindUp = 2.0;
  final elapsed = (totalWindUp - windUpRemaining).clamp(0.0, totalWindUp);
  final t = elapsed / totalWindUp;
  final orbR = 14.0 + 12.0 * sin(elapsed * 4.0);
  for (var i = 0; i < 2; i++) {
    final a = rng.nextDouble() * 2 * pi;
    final startR = 40.0 + 18.0 * (1.0 - t);
    emit(
      center.dx + cos(a) * startR,
      center.dy + sin(a) * startR,
      -cos(a) * (50 + 60 * t),
      -sin(a) * (50 + 60 * t),
      1.8 + rng.nextDouble() * 1.2,
      0.4 + rng.nextDouble() * 0.25,
      ui.Color.lerp(
        elementColor('Spirit'),
        _white,
        0.55,
      )!.withValues(alpha: 0.7),
    );
  }
  beam(
    center + ui.Offset(orbR, 0),
    center + ui.Offset(-orbR, 0),
    elementColor('Spirit').withValues(alpha: 0.18 + 0.18 * t),
    1.0 + t * 0.6,
    0.05,
  );
}

/// Air: two wisps blown from the still middle out to the rim, tracing the
/// push. The caller keeps the [HornRules.airParticleInterval] cadence and
/// gates on its pool (130).
void emitHornAirWind(
  ui.Offset center,
  double inner,
  double outer,
  Random rng,
  ZoneVfxEmit emit,
) {
  const travelSpeed = 140.0;
  final travelLife = (outer - inner) / travelSpeed;
  final airColor = elementColor('Air');
  for (var i = 0; i < 2; i++) {
    final a = rng.nextDouble() * 2 * pi;
    final startR = inner + rng.nextDouble() * 6.0;
    emit(
      center.dx + cos(a) * startR,
      center.dy + sin(a) * startR,
      cos(a) * travelSpeed,
      sin(a) * travelSpeed,
      1.3 + rng.nextDouble() * 0.8,
      travelLife,
      airColor.withValues(alpha: 0.55),
    );
  }
}

/// The particles a Horn projectile trails each frame: Spirit's phantoms,
/// Crystal's shards, Lightning's discharge, and the stationary Fire, Water,
/// Dust, Ice, Steam, Dark and Light pieces. [beam] is null when the
/// caller's beam list is full (survival: 22), which only the Light
/// barrier's arc needs. Caller gates on its pool (130).
void emitHornProjectileParticles(
  Projectile p,
  Random rng,
  ZoneVfxEmit emit,
  HornBeamEmit? beam,
) {
  if (p.element == 'Spirit' && p.decoy) {
    final ghost = ui.Color.lerp(elementColor('Spirit'), _white, 0.55)!;
    for (var i = 0; i < 3; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final r = 6.0 + rng.nextDouble() * 16.0;
      emit(
        p.position.dx + cos(a) * r,
        p.position.dy + sin(a) * r,
        cos(a) * (8 + rng.nextDouble() * 24),
        sin(a) * (8 + rng.nextDouble() * 24),
        1.4 + rng.nextDouble() * 1.4,
        0.40 + rng.nextDouble() * 0.35,
        i.isEven ? ghost : _white,
      );
    }
  } else if (p.element == 'Crystal' && p.orbitRadius > 0) {
    final white = ui.Color.lerp(elementColor('Crystal'), _white, 0.55)!;
    for (var i = 0; i < 2; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final r = 4.0 + rng.nextDouble() * 12.0;
      emit(
        p.position.dx + cos(a) * r,
        p.position.dy + sin(a) * r,
        cos(a) * (12 + rng.nextDouble() * 30),
        sin(a) * (12 + rng.nextDouble() * 30),
        1.1 + rng.nextDouble() * 1.2,
        0.30 + rng.nextDouble() * 0.25,
        rng.nextBool() ? white : _white,
      );
    }
  } else if (p.element == 'Lightning' &&
      p.stationary &&
      p.tickEffect == AbilityEffectKind.chain) {
    final blastR = p.effectRadius > 0 ? p.effectRadius : 140.0;
    final base = elementColor('Lightning');
    final white = ui.Color.lerp(base, _white, 0.6)!;
    for (var i = 0; i < 4; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final r = blastR * (0.10 + rng.nextDouble() * 0.90);
      emit(
        p.position.dx + cos(a) * r,
        p.position.dy + sin(a) * r,
        cos(a) * (10 + rng.nextDouble() * 30),
        sin(a) * (10 + rng.nextDouble() * 30),
        1.4 + rng.nextDouble() * 1.4,
        0.30 + rng.nextDouble() * 0.35,
        i.isEven ? white : base,
      );
    }
  } else if (p.element == 'Fire' && p.stationary) {
    const ember = ui.Color(0xFFFFB060);
    const hot = ui.Color(0xFFFFD080);
    final a = rng.nextDouble() * 2 * pi;
    final r =
        (p.effectRadius > 0 ? p.effectRadius : 40.0) * 0.45 * rng.nextDouble();
    emit(
      p.position.dx + cos(a) * r,
      p.position.dy + sin(a) * r,
      cos(a) * (6 + rng.nextDouble() * 8),
      -22 - rng.nextDouble() * 24,
      1.2 + rng.nextDouble() * 1.0,
      0.5 + rng.nextDouble() * 0.35,
      rng.nextBool() ? ember : hot,
    );
  } else if (p.element == 'Water' && p.stationary) {
    final whirlR = max(40.0, p.radiusMultiplier * 18.0 + 20.0);
    final base = elementColor('Water').withValues(alpha: 0.65);
    final a = rng.nextDouble() * 2 * pi;
    final r = whirlR * (0.55 + rng.nextDouble() * 0.45);
    final tang = ui.Offset(-sin(a), cos(a));
    final inward = ui.Offset(-cos(a), -sin(a));
    final tangSpd = 40 + rng.nextDouble() * 30;
    final inSpd = 18 + rng.nextDouble() * 16;
    emit(
      p.position.dx + cos(a) * r,
      p.position.dy + sin(a) * r,
      tang.dx * tangSpd + inward.dx * inSpd,
      tang.dy * tangSpd + inward.dy * inSpd,
      1.2 + rng.nextDouble() * 1.0,
      0.4 + rng.nextDouble() * 0.4,
      base,
    );
  } else if (p.element == 'Dust' && p.stationary) {
    final dustR = max(36.0, p.radiusMultiplier * 18.0 + 16.0);
    final base = elementColor('Dust').withValues(alpha: 0.55);
    for (var i = 0; i < 3; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final r = dustR * (0.20 + rng.nextDouble() * 0.75);
      final tang = ui.Offset(-sin(a), cos(a));
      final outward = ui.Offset(cos(a), sin(a));
      final tangSpd = 25 + rng.nextDouble() * 30;
      final outSpd = 8 + rng.nextDouble() * 10;
      emit(
        p.position.dx + cos(a) * r,
        p.position.dy + sin(a) * r,
        tang.dx * tangSpd + outward.dx * outSpd,
        tang.dy * tangSpd + outward.dy * outSpd,
        1.1 + rng.nextDouble() * 1.0,
        0.5 + rng.nextDouble() * 0.4,
        base,
      );
    }
  } else if (p.element == 'Ice' && p.stationary) {
    final iceR = max(20.0, p.radiusMultiplier * 16.0 + 8.0);
    final base = elementColor('Ice');
    final white = ui.Color.lerp(base, _white, 0.55)!;
    final a = rng.nextDouble() * 2 * pi;
    final r = iceR * (0.30 + rng.nextDouble() * 0.70);
    emit(
      p.position.dx + cos(a) * r,
      p.position.dy + sin(a) * r,
      cos(a) * (8 + rng.nextDouble() * 12),
      sin(a) * (8 + rng.nextDouble() * 12) + 6,
      1.0 + rng.nextDouble() * 1.0,
      0.5 + rng.nextDouble() * 0.4,
      rng.nextBool() ? white : _white,
    );
  } else if (p.element == 'Steam' && p.stationary) {
    final steamR = max(38.0, p.radiusMultiplier * 18.0 + 18.0);
    final base = elementColor('Steam');
    final white = ui.Color.lerp(base, _white, 0.55)!;
    for (var i = 0; i < 2; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final r = steamR * (0.15 + rng.nextDouble() * 0.50);
      emit(
        p.position.dx + cos(a) * r,
        p.position.dy + sin(a) * r,
        cos(a) * (10 + rng.nextDouble() * 8),
        -30 - rng.nextDouble() * 30,
        2.0 + rng.nextDouble() * 1.8,
        0.6 + rng.nextDouble() * 0.4,
        i.isEven ? white : base,
      );
    }
  } else if (p.element == 'Dark' && p.stationary) {
    final voidR = max(40.0, p.radiusMultiplier * 18.0 + 24.0);
    const voidColor = ui.Color(0xFFB89AFF);
    const deepColor = ui.Color(0xFF1A0A2A);
    for (var i = 0; i < 3; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = voidR * (0.85 + rng.nextDouble() * 0.25);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        -cos(a) * (50 + rng.nextDouble() * 60),
        -sin(a) * (50 + rng.nextDouble() * 60),
        1.4 + rng.nextDouble() * 1.4,
        0.4 + rng.nextDouble() * 0.3,
        i.isEven ? voidColor : deepColor,
      );
    }
  } else if (p.element == 'Light' && p.stationary && p.reflectsProjectiles) {
    final domeR = max(60.0, p.radiusMultiplier * 20.0 + 70.0);
    final white = ui.Color.lerp(elementColor('Light'), _white, 0.55)!;
    for (var i = 0; i < 5; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = domeR * (0.88 + rng.nextDouble() * 0.20);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        -cos(a) * (12 + rng.nextDouble() * 22),
        -sin(a) * (12 + rng.nextDouble() * 22),
        1.4 + rng.nextDouble() * 1.4,
        0.5 + rng.nextDouble() * 0.4,
        i.isEven ? white : _white,
      );
    }
    for (var i = 0; i < 2; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final innerR = domeR * (0.15 + rng.nextDouble() * 0.30);
      emit(
        p.position.dx + cos(a) * innerR,
        p.position.dy + sin(a) * innerR,
        cos(a) * (20 + rng.nextDouble() * 18),
        sin(a) * (20 + rng.nextDouble() * 18),
        1.6 + rng.nextDouble() * 1.2,
        0.3 + rng.nextDouble() * 0.2,
        _white,
      );
    }
    if (rng.nextDouble() < 0.45 && beam != null) {
      final a1 = rng.nextDouble() * 2 * pi;
      final a2 = a1 + pi + (rng.nextDouble() - 0.5) * 0.6;
      final r1 = domeR * (0.70 + rng.nextDouble() * 0.25);
      final r2 = domeR * (0.70 + rng.nextDouble() * 0.25);
      beam(
        ui.Offset(p.position.dx + cos(a1) * r1, p.position.dy + sin(a1) * r1),
        ui.Offset(p.position.dx + cos(a2) * r2, p.position.dy + sin(a2) * r2),
        white.withValues(alpha: 0.65),
        1.5,
        0.08,
      );
    }
  }
}
