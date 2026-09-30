import 'dart:math';
import 'dart:ui' as ui;

import 'cosmic_data.dart';
import 'vfx_shapes.dart';

/// Let's art after the landing: the crater a meteor punches, what it leaves
/// on the ground, and the short beats that make each element's aftermath
/// visible (Fire's second blast, Water's splash, Air's gust, Blood's drain,
/// Ice and Crystal closing on the body that was struck, Spirit taking a soul).
/// Shared by survival, open space and dungeons so a Let lands the same way in
/// all three.
///
/// Written in the material language the other families moved to in
/// September: muted element materials, filled tapered shapes, light that
/// pools through a radial gradient. The crater this replaced was two stroked
/// hoops and a white flash, identical for all seventeen elements, and the
/// zones were flat saturated polygons and bullseyes — the look the rest of
/// the ability art had already left behind.
///
/// Family motif: every Let leaves its stone. The crater has the spent meteor
/// sitting in the bowl, and every zone keeps it at its heart — molten in
/// Lava, sunk in Mud and Poison, a pale star-stone in Light — so a Let's
/// ground reads as "something fell here" rather than as another trap.
///
/// Budget: no blur, no layers. A crater is ~30 fills for 0.9s, a zone ~20-40
/// fills, a beat ~10-25; all are capped by the lists that hold them.

final ui.Paint _fill = ui.Paint();
const ui.Color _black = ui.Color(0xFF000000);

double _c01(double v) => v.clamp(0.0, 1.0).toDouble();
double _easeOut(double t) => 1.0 - pow(1.0 - _c01(t), 3).toDouble();

/// Fast out of the gate, long tail — impact energy is spent at once.
double _easeOutFast(double t) {
  final u = 1.0 - _c01(t);
  return 1.0 - u * u * u * u;
}

void _dot(ui.Canvas canvas, ui.Offset p, double r, ui.Color c, double alpha) {
  if (alpha <= 0.004 || r <= 0.2) return;
  _fill
    ..shader = null
    ..color = c.withValues(alpha: _c01(alpha));
  canvas.drawCircle(p, r, _fill);
}

/// A jagged spine from [from] to [to], for seams and fissures.
List<ui.Offset> _jagSpine(
  ui.Offset from,
  ui.Offset to,
  double seed, {
  int n = 6,
  double jag = 0.16,
}) {
  final d = to - from;
  final len = d.distance;
  if (len < 0.5) return [from, to];
  final nrm = ui.Offset(-d.dy, d.dx) / len;
  return [
    for (var k = 0; k <= n; k++)
      from +
          d * (k / n) +
          nrm *
              ((k == 0 || k == n)
                  ? 0.0
                  : (vfxHash(seed + k * 2.7) - 0.5) * len * jag),
  ];
}

/// The spent meteor, sitting where it fell.
void _stone(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  VfxMaterial m,
  double seed,
  double alpha, {
  double heat = 0,
  double faceAlpha = 0.8,
}) {
  if (alpha <= 0.01) return;
  vfxSpill(canvas, c + const ui.Offset(0, 2), r * 1.9, _black, 0.45 * alpha);
  vfxChunk(
    canvas,
    c,
    r,
    seed,
    m,
    alpha: alpha,
    rot: seed * 1.3,
    sides: 7,
    faceAlpha: faceAlpha,
  );
  if (heat > 0.01) vfxSpill(canvas, c, r * 2.2, m.glint, 0.5 * heat * alpha);
}

// ─────────────────────────────────────────────────────────────────────────
// The crater
// ─────────────────────────────────────────────────────────────────────────

/// Seconds a crater stays on the ground. The flash and the shock are spent in
/// the first third; the bowl, its lip and the stone settle and fade over the
/// rest, handing the spot over to whatever zone the element leaves.
const double kLetCraterDuration = 0.9;

/// A meteor's landing. [t] runs 0 at touchdown to 1 when the crater is gone.
///
/// Round, never squashed — the arena is seen from overhead. The shock is a
/// soft band, not a stroked hoop; the ejecta curtain is broken crescents so
/// it never closes into a ring; and each element throws its own material out
/// of the bowl, which is where the seventeen stop looking like one asset.
///
/// [minor] is the quiet version for Let mastery's auto-attack rocks: a bowl,
/// a lip and a stone, no element throw.
void drawLetCrater({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required String? element,
  required double radius,
  required double t,
  bool reduceAmbient = false,
  bool minor = false,
}) {
  final tt = _c01(t);
  if (tt >= 1.0) return;
  final m = vfxMaterial(element);
  final c = centre;
  final r = radius;
  final seed = (c.dx * 0.071 + c.dy * 0.113).abs() % 97.0;
  final isDark = element == 'Dark';
  final isAiry = element == 'Air' || element == 'Spirit' || element == 'Light';

  final flash = pow(_c01(1 - tt / 0.16), 2).toDouble();
  final shockT = _c01(tt / 0.32);
  final shock = 1.0 - shockT;
  final throwT = _easeOut(tt / 0.55);
  final settle = tt < 0.5 ? 1.0 : 1.0 - (tt - 0.5) / 0.5;
  final bowlR = r * (minor ? 0.34 : 0.46);

  // The bowl the stone punched, darkest at its heart.
  vfxSpill(canvas, c, bowlR * 1.7, _black, 0.28 * settle);
  vfxFillPath(
    canvas,
    vfxBlob(c, bowlR * (0.82 + 0.18 * throwT), seed, n: 13, wobble: 0.13),
    m.ink,
    (isDark ? 0.92 : (isAiry ? 0.42 : 0.66)) * settle,
  );
  vfxSpill(canvas, c, bowlR * 0.7, _black, 0.36 * settle);

  // The light of the landing. Dark swallows its own: a hole ringed in violet.
  if (isDark) {
    vfxSpill(canvas, c, r * 0.9, m.light, 0.12 * shock);
    vfxSoftRing(canvas, c, bowlR * 1.02, bowlR * 0.16, m.light, 0.4 * settle);
  } else {
    vfxSpill(canvas, c, r * 0.95, m.light, 0.30 * shock * shock);
    vfxSpill(canvas, c, r * 0.42, m.glint, 0.85 * flash);
  }

  // The shock leaving it: a wide pressure front, out fast and gone. Wide
  // and faint on purpose — a narrow band reads as a hoop.
  vfxSoftRing(
    canvas,
    c,
    r * (0.3 + 0.8 * _easeOutFast(shockT)),
    r * (0.12 + 0.1 * shock),
    isDark ? m.mid : m.light,
    (isDark ? 0.2 : 0.26) * pow(shock, 2.5).toDouble(),
  );

  // The ejecta curtain: ground thrown up round the bowl, in broken arcs.
  if (!minor && !isAiry) {
    final arcs = reduceAmbient ? 3 : 5;
    for (var i = 0; i < arcs; i++) {
      final a = seed + i * pi * 2 / arcs + (vfxHash(seed + i) - 0.5) * 0.9;
      final spread = 0.85 + 0.35 * vfxHash(seed + i * 4.3);
      vfxFillPath(
        canvas,
        vfxCrescent(
          c,
          bowlR * (0.95 + 0.9 * throwT * spread),
          r * (0.05 + 0.06 * vfxHash(seed + i * 2.9)) * shock + 1.2,
          a,
          0.4 + 0.45 * vfxHash(seed + i * 1.9),
        ),
        m.mid,
        0.3 * shock,
      );
    }
  }

  // Rubble on the lip: the one part of the crater that stays a while.
  if (!isAiry) {
    final lip = minor ? 4 : (reduceAmbient ? 5 : 8);
    final lipIn = _c01(tt * 7);
    for (var i = 0; i < lip; i++) {
      final a = seed * 1.7 + i * pi * 2 / lip + (vfxHash(seed + i) - 0.5) * 0.5;
      vfxChunk(
        canvas,
        c + vfxPolar(a, bowlR * (0.92 + 0.18 * vfxHash(seed + i * 3.3))),
        r * (minor ? 0.032 : 0.042) * (0.7 + 0.6 * vfxHash(seed + i * 5.1)),
        seed + i * 3,
        m,
        alpha: lipIn * settle,
        rot: a,
      );
    }
  }

  // The stone itself, still hot for a moment.
  _stone(
    canvas,
    c,
    r * (minor ? 0.05 : 0.068),
    m,
    seed + 41,
    settle,
    heat: isDark ? 0 : shock,
  );

  if (minor) return;
  _craterThrow(
    canvas,
    c,
    r,
    bowlR,
    element,
    m,
    seed,
    tt,
    throwT,
    reduceAmbient,
  );
}

/// What each element throws out of the crater.
void _craterThrow(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  double bowlR,
  String? element,
  VfxMaterial m,
  double seed,
  double t,
  double throwT,
  bool reduce,
) {
  final fade = 1.0 - t;
  final settle = t < 0.5 ? 1.0 : 1.0 - (t - 0.5) / 0.5;
  final n = reduce ? 5 : 9;

  switch (element) {
    case 'Lightning':
      // Lightning is a line; it is the one element that keeps them.
      final step = (t * 18).floorToDouble();
      final alpha = pow(_c01(1 - t / 0.55), 1.5).toDouble();
      final bolts = reduce ? 3 : 6;
      for (var i = 0; i < bolts; i++) {
        final a = seed + i * pi * 2 / bolts + vfxHash(step + i) * 0.5;
        vfxBolt(
          canvas,
          c + vfxPolar(a, bowlR * 0.3),
          c +
              vfxPolar(
                a,
                r * (0.45 + 0.55 * throwT) * (0.7 + 0.3 * vfxHash(seed + i)),
              ),
          step * 3 + i,
          m,
          alpha,
          jag: 0.3,
        );
      }
      vfxSpill(canvas, c, bowlR * 1.3, m.light, 0.24 * fade);
      return;

    case 'Light':
      // Rays, lens-shaped and cross-lit, not lines.
      final rays = reduce ? 4 : 7;
      final alpha = 0.55 * pow(fade, 3).toDouble();
      for (var i = 0; i < rays; i++) {
        final a =
            seed + i * pi * 2 / rays + (vfxHash(seed + i * 3) - 0.5) * 0.4;
        final len = r * (0.2 + 0.42 * throwT) * (0.6 + 0.4 * vfxHash(seed + i));
        final h = r * 0.11 * (1 - t) + 2;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(a);
        canvas.translate(bowlR * 0.25, 0);
        vfxCrossLit(
          canvas,
          vfxLens(len, h, len * 0.25, len * 0.6),
          h / 2,
          m.light,
          m.glint,
          alpha,
        );
        canvas.restore();
      }
      vfxSpill(canvas, c, r * 0.6, m.light, 0.22 * fade);
      return;

    case 'Dark':
      // It runs backwards: the ground falls in rather than out.
      for (var i = 0; i < n; i++) {
        final a = seed + i * pi * 2 / n + throwT * 0.7;
        final start = r * 0.95 * (0.7 + 0.3 * vfxHash(seed + i));
        final d = start * (1 - throwT) + bowlR * 0.2 * throwT;
        final p = c + vfxPolar(a, d);
        final s = r * 0.03 * (0.7 + 0.6 * vfxHash(seed + i * 2.1));
        vfxFillPath(
          canvas,
          vfxBlob(p, s, seed + i, n: 7, wobble: 0.3),
          m.ink,
          0.9 * fade,
        );
        _dot(canvas, p - vfxPolar(a, s * 0.4), s * 0.35, m.glint, 0.5 * fade);
      }
      for (var arm = 0; arm < (reduce ? 2 : 4); arm++) {
        vfxFillPath(
          canvas,
          vfxSpiralArm(
            c,
            r * (0.95 - 0.35 * throwT),
            seed + arm * pi / 2 + t * 3.2,
            1.6,
            r * 0.05,
            reach: 0.7,
          ),
          m.glint,
          0.3 * fade,
        );
      }
      return;

    case 'Air':
      // Wind leaving the bowl, seen in what it carries: puffs and grit
      // streaming outward, curling a little as they go.
      final gusts = reduce ? 5 : 10;
      for (var i = 0; i < gusts; i++) {
        final a = seed + i * pi * 2 / gusts + throwT * 0.7;
        final d = r * (0.2 + 0.75 * throwT) * (0.7 + 0.3 * vfxHash(seed + i));
        final p = c + vfxPolar(a, d);
        vfxSpill(canvas, p, r * (0.08 + 0.1 * throwT), m.light, 0.26 * fade);
        vfxFillPath(
          canvas,
          vfxDrop(p, r * 0.022 * fade + 1.2, a + 0.5),
          m.glint,
          0.55 * fade,
        );
      }
      vfxSpill(canvas, c, r * 0.5, m.light, 0.2 * fade);
      return;

    case 'Steam':
      // It bores a vent: the plume goes up, not out.
      final puffs = reduce ? 3 : 6;
      for (var i = 0; i < puffs; i++) {
        final ph = _c01(t * 1.25 - i * 0.07);
        final p =
            c +
            vfxPolar(seed + i * 1.3, bowlR * 0.3) +
            ui.Offset(sin(seed + i * 2.1) * bowlR * 0.5 * ph, -ph * r * 0.85);
        vfxSpill(
          canvas,
          p,
          r * (0.12 + 0.24 * ph),
          m.glint,
          0.32 * sin(ph * pi),
        );
      }
      for (var i = 0; i < n; i++) {
        final a = seed + i * pi * 2 / n;
        final p = c + vfxPolar(a, r * (0.15 + 0.6 * throwT));
        vfxFillPath(canvas, vfxDrop(p, r * 0.016 + 1, a), m.mid, 0.7 * fade);
      }
      return;

    case 'Spirit':
      // Wisps: out a little, then up, unhurried.
      for (var i = 0; i < n; i++) {
        final a = seed + i * pi * 2 / n;
        final p =
            c +
            vfxPolar(a, r * (0.2 + 0.45 * throwT)) +
            ui.Offset(0, -r * 0.25 * t);
        final dir = atan2(sin(a) * 0.6 - 0.8, cos(a) * 0.6);
        vfxFillPath(
          canvas,
          vfxDrop(p, r * 0.03 * (1 - 0.4 * t), dir),
          m.glint,
          0.55 * fade,
        );
      }
      vfxSpill(canvas, c, r * 0.55, m.light, 0.24 * fade);
      return;
  }

  // Everything solid or liquid: thrown out of the bowl.
  for (var i = 0; i < n; i++) {
    final a = seed * 0.37 + i * pi * 2 / n + (vfxHash(seed + i) - 0.5) * 0.55;
    final reach = 0.65 + 0.35 * vfxHash(seed + i * 3.1);
    final heavy = element == 'Earth' || element == 'Mud';
    final d = r * (0.18 + 0.82 * throwT) * reach * (heavy ? 0.82 : 1.0);
    final p = c + vfxPolar(a, d);
    final s = r * 0.04 * (0.8 + 0.5 * vfxHash(seed + i * 7.7));
    // Pieces that land stay visible a little longer than spray does.
    final landed = pow(fade, 0.5).toDouble();
    switch (element) {
      case 'Fire':
        vfxFillPath(canvas, vfxDrop(p, s * 0.8, a), m.mid, 0.85 * fade);
        vfxFillPath(canvas, vfxDrop(p, s * 0.4, a), m.glint, 0.9 * fade);
      case 'Lava':
        vfxFillPath(
          canvas,
          vfxBlob(p, s * 0.75, seed + i, n: 7, wobble: 0.3),
          m.mid,
          0.9 * landed,
        );
        _dot(canvas, p, s * 0.32, m.glint, 0.85 * landed);
      case 'Earth':
        vfxChunk(
          canvas,
          p,
          s * 1.5,
          seed + i * 5,
          m,
          alpha: landed,
          rot: a + t * 3,
        );
      case 'Mud':
        vfxFillPath(
          canvas,
          vfxBlob(
            p,
            s * (0.8 + 0.5 * throwT),
            seed + i,
            n: 8,
            wobble: 0.35,
            squash: 0.72,
          ),
          m.mid,
          0.85 * landed,
        );
      case 'Dust':
        vfxSpill(canvas, p, s * (1.5 + 3.5 * throwT), m.glint, 0.3 * fade);
        _dot(canvas, p, s * 0.2, m.glint, 0.6 * fade);
      case 'Water':
        vfxFillPath(canvas, vfxDrop(p, s * 0.7, a), m.mid, 0.9 * fade);
        _dot(canvas, p + vfxPolar(a, s * 0.2), s * 0.22, m.glint, 0.5 * fade);
      case 'Poison':
        vfxFillPath(canvas, vfxDrop(p, s * 0.65, a), m.mid, 0.9 * fade);
        vfxSpill(canvas, p, s * 2.6, m.light, 0.14 * fade);
      case 'Blood':
        vfxFillPath(canvas, vfxDrop(p, s * 0.65, a), m.mid, 0.9 * fade);
        _dot(canvas, p, s * 0.25, m.glint, 0.45 * fade);
      case 'Ice':
        vfxFillPath(
          canvas,
          vfxShard(p, s * 2.0, s * 0.5, a),
          m.mid,
          0.85 * fade,
        );
        vfxFillPath(
          canvas,
          vfxShard(p, s * 1.2, s * 0.2, a),
          m.glint,
          0.7 * fade,
        );
      case 'Crystal':
        if (i.isOdd) {
          vfxFillPath(
            canvas,
            vfxShard(p, s * 2.4, s * 0.7, a),
            m.mid,
            0.85 * landed,
          );
          vfxFillPath(
            canvas,
            vfxShard(p, s * 1.5, s * 0.25, a),
            m.glint,
            0.6 * landed,
          );
        }
      case 'Plant':
        vfxFillPath(
          canvas,
          vfxLeaf(p, s * 2.3, a + i * 0.8 + t * 4),
          m.mid,
          0.9 * fade,
        );
        if (i.isEven) _dot(canvas, p, s * 0.35, m.ink, 0.9 * fade);
      default:
        _dot(canvas, p, s * 0.5, m.glint, 0.6 * fade);
    }
  }

  // The few elements with a second gesture.
  switch (element) {
    case 'Water':
      // The crown: a rim of spray standing up round the bowl.
      final crownA = pow(_c01(1 - t / 0.5), 1.2).toDouble();
      final crown = reduce ? 8 : 14;
      for (var i = 0; i < crown; i++) {
        final a = seed + i * pi * 2 / crown;
        final p = c + vfxPolar(a, bowlR * (1.0 + 0.55 * throwT));
        vfxFillPath(
          canvas,
          vfxDrop(p, r * 0.016 + 1, a),
          m.glint,
          0.6 * crownA,
        );
      }
    case 'Ice':
      // Frost left standing on the lip.
      for (var i = 0; i < (reduce ? 4 : 7); i++) {
        final a = seed * 2.3 + i * pi * 2 / 7;
        final p = c + vfxPolar(a, bowlR * 0.98);
        vfxFillPath(
          canvas,
          vfxShard(p, r * 0.07 * _c01(t * 5), r * 0.018, a),
          m.glint,
          0.55 * settle,
        );
      }
    case 'Crystal':
      // Crystal grows out of the rim where the stone struck.
      for (var i = 0; i < (reduce ? 3 : 5); i++) {
        final a = seed * 1.1 + i * pi * 2 / 5 + 0.3;
        final grow = _easeOut(t / 0.35);
        final p = c + vfxPolar(a, bowlR * 0.9);
        vfxFillPath(
          canvas,
          vfxShard(p, r * 0.11 * grow, r * 0.03 * grow, a),
          m.mid,
          0.85 * settle,
        );
        vfxFillPath(
          canvas,
          vfxShard(p, r * 0.07 * grow, r * 0.012 * grow, a),
          m.glint,
          0.55 * settle,
        );
      }
    case 'Fire':
      // Flame standing in the bowl for a breath.
      for (var i = 0; i < 3; i++) {
        final base = c + vfxPolar(seed + i * 2.1, bowlR * 0.35);
        final h = r * 0.2 * (1 - t) * (0.8 + 0.3 * sin(t * 20 + i));
        vfxFillPath(
          canvas,
          vfxDrop(base + ui.Offset(0, -h * 0.5), h * 0.3, -pi / 2),
          m.mid,
          0.7 * fade,
        );
        vfxFillPath(
          canvas,
          vfxDrop(base + ui.Offset(0, -h * 0.35), h * 0.16, -pi / 2),
          m.glint,
          0.75 * fade,
        );
      }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// What stays on the ground
// ─────────────────────────────────────────────────────────────────────────

/// Paints a Let ground zone — the burning ground, dust pall, sump, rubble,
/// mire, well of light, vent or vine a meteor leaves behind — sized to the
/// radius it actually affects. Returns false for anything that is not one.
bool drawLetGroundZone({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required double time,
  bool reduceAmbient = false,
}) {
  if (!projectile.stationary ||
      projectile.visualStyle != ProjectileVisualStyle.letShard) {
    return false;
  }
  final element = projectile.element;
  if (element == null) return false;
  final m = vfxMaterial(element);
  final c = position;
  final seed = (identityHashCode(projectile) % 997) * 0.37;
  final total = projectile.effectDuration > 0
      ? projectile.effectDuration
      : projectile.life;
  final age = max(0.0, total - projectile.life);
  final grow = _easeOut(age / 0.45);
  final alpha = _c01(age / 0.3) * _c01(projectile.life / 0.8);
  // The crater's own stone is still fading when the zone arrives; this one
  // takes over from it rather than doubling it.
  final stoneA = alpha * _c01((age - 0.35) / 0.4);
  final r = projectile.effectRadius > 0 ? projectile.effectRadius : 60.0;

  switch (element) {
    case 'Lava':
      _moltenGround(
        canvas,
        c,
        r,
        m,
        seed,
        time,
        grow,
        alpha,
        stoneA,
        reduceAmbient,
      );
    case 'Dust':
      _dustPall(
        canvas,
        c,
        r,
        m,
        seed,
        time,
        grow,
        alpha,
        stoneA,
        reduceAmbient,
      );
    case 'Poison':
      _sump(canvas, c, r, m, seed, time, grow, alpha, stoneA, reduceAmbient);
    case 'Earth':
      _rubble(canvas, c, r, m, seed, time, grow, alpha, stoneA, reduceAmbient);
    case 'Mud':
      _mire(canvas, c, r, m, seed, time, grow, alpha, stoneA, reduceAmbient);
    case 'Light':
      _wellOfLight(
        canvas,
        c,
        r,
        m,
        seed,
        time,
        grow,
        alpha,
        stoneA,
        reduceAmbient,
      );
    case 'Steam':
      _vent(canvas, c, r, m, seed, time, grow, alpha, stoneA, reduceAmbient);
    case 'Plant':
      _vine(canvas, c, r, m, seed, time, grow, alpha, reduceAmbient);
    default:
      vfxSpill(canvas, c, r, m.light, 0.18 * alpha);
      _stone(canvas, c, r * 0.1, m, seed, stoneA);
  }
  return true;
}

/// Lava: a crust gone dark over the crater, split by seams that still run
/// from the stone. The burn covers the whole glow.
void _moltenGround(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  VfxMaterial m,
  double seed,
  double time,
  double grow,
  double a,
  double stoneA,
  bool reduce,
) {
  final breathe = 0.85 + 0.15 * sin(time * 2.2 + seed);
  vfxSpill(canvas, c, r * 1.05, m.light, 0.17 * a * breathe);
  vfxFillPath(
    canvas,
    vfxBlob(c, r * 0.8 * grow, seed, n: 16, wobble: 0.12),
    m.ink,
    0.74 * a,
  );
  final seams = reduce ? 5 : 8;
  for (var i = 0; i < seams; i++) {
    final ang = seed + i * pi * 2 / seams + (vfxHash(seed + i) - 0.5) * 0.5;
    final reach = r * (0.55 + 0.28 * vfxHash(seed + i * 2.3)) * grow;
    final spine = _jagSpine(
      c + vfxPolar(ang, r * 0.08),
      c + vfxPolar(ang + (vfxHash(seed + i * 4.1) - 0.5) * 0.35, reach),
      seed + i * 7,
      n: 6,
      jag: 0.22,
    );
    final flick = 0.7 + 0.3 * sin(time * 3.1 + i * 1.7 + seed);
    vfxFillPath(
      canvas,
      vfxRibbon(spine, r * 0.05, 0.6),
      m.light,
      0.5 * a * flick,
    );
    vfxFillPath(
      canvas,
      vfxRibbon(spine, r * 0.022, 0.3),
      m.glint,
      0.7 * a * flick,
    );
    if (!reduce && i.isEven) {
      // A branch off the seam.
      final fork = spine[3];
      final fa = ang + (i % 4 == 0 ? 0.7 : -0.7);
      final branch = _jagSpine(
        fork,
        fork + vfxPolar(fa, reach * 0.35),
        seed + i * 11,
        n: 3,
        jag: 0.25,
      );
      vfxFillPath(
        canvas,
        vfxRibbon(branch, r * 0.025, 0.4),
        m.light,
        0.45 * a * flick,
      );
    }
  }
  // Heat coming off it.
  for (var i = 0; i < (reduce ? 2 : 4); i++) {
    final ph = (time * 0.55 + vfxHash(seed + i * 3)) % 1.0;
    final base =
        c +
        vfxPolar(vfxHash(seed + i) * pi * 2, r * 0.45 * vfxHash(seed + i * 5));
    _dot(
      canvas,
      base + ui.Offset(0, -ph * r * 0.35),
      1.6 + r * 0.008,
      m.glint,
      0.7 * sin(ph * pi) * a,
    );
  }
  _stone(canvas, c, r * 0.09, m, seed, stoneA, heat: 0.7 * breathe);
}

/// Dust: a pall hanging over the crater, turning slowly, grains riding it.
void _dustPall(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  VfxMaterial m,
  double seed,
  double time,
  double grow,
  double a,
  double stoneA,
  bool reduce,
) {
  vfxFillPath(
    canvas,
    vfxBlob(c, r * 0.7 * grow, seed, n: 14, wobble: 0.2),
    m.ink,
    0.28 * a,
  );
  _stone(canvas, c, r * 0.085, m, seed, stoneA * 0.7);
  final veils = reduce ? 4 : 6;
  for (var i = 0; i < veils; i++) {
    final dir = i.isEven ? 1.0 : -0.7;
    final ang = seed + i * pi * 2 / veils + time * 0.22 * dir;
    final d = r * (0.3 + 0.14 * sin(time * 0.7 + i * 1.3)) * grow;
    vfxSpill(canvas, c + vfxPolar(ang, d), r * 0.46, m.light, 0.13 * a);
  }
  for (var i = 0; i < 3; i++) {
    final ang = seed * 2 + i * pi * 2 / 3 - time * 0.35;
    vfxSpill(canvas, c + vfxPolar(ang, r * 0.18), r * 0.34, m.mid, 0.16 * a);
  }
  final grains = reduce ? 6 : 12;
  for (var i = 0; i < grains; i++) {
    final speed = 0.3 + 0.5 * vfxHash(seed + i * 1.7);
    final ang = seed + i * 2.399 + time * speed * (i.isEven ? 1 : -1);
    final p =
        c + vfxPolar(ang, r * (0.2 + 0.7 * vfxHash(seed + i * 3.9)) * grow);
    _dot(canvas, p, 1.1 + 0.8 * vfxHash(seed + i), m.glint, 0.42 * a);
  }
}

/// Poison: the crater filled with something that should not be touched.
void _sump(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  VfxMaterial m,
  double seed,
  double time,
  double grow,
  double a,
  double stoneA,
  bool reduce,
) {
  vfxSpill(canvas, c, r * 1.05, m.light, 0.15 * a);
  vfxFillPath(
    canvas,
    vfxBlob(c, r * 0.74 * grow, seed, n: 16, wobble: 0.1),
    m.ink,
    0.8 * a,
  );
  vfxFillPath(
    canvas,
    vfxBlob(
      c + const ui.Offset(-2, -3),
      r * 0.6 * grow,
      seed + 3,
      n: 14,
      wobble: 0.12,
    ),
    m.mid,
    0.26 * a,
  );
  for (var i = 0; i < 2; i++) {
    vfxFillPath(
      canvas,
      vfxCrescent(
        c,
        r * (0.48 - i * 0.16) * grow,
        r * 0.03,
        seed + i * 2.4 + time * 0.12,
        1.1,
      ),
      m.glint,
      0.2 * a,
    );
  }
  _stone(canvas, c + const ui.Offset(3, 2), r * 0.075, m, seed, stoneA * 0.85);
  // Bubbles rising and breaking at fixed spots in the pool.
  final bubbles = reduce ? 4 : 7;
  for (var i = 0; i < bubbles; i++) {
    final ph = (time * 0.6 + vfxHash(seed + i * 2.2)) % 1.0;
    final p =
        c +
        vfxPolar(
          vfxHash(seed + i) * pi * 2,
          r * 0.55 * vfxHash(seed + i * 4.4) * grow,
        );
    if (ph < 0.86) {
      final br = r * (0.018 + 0.04 * ph / 0.86);
      _dot(canvas, p, br, m.mid, 0.75 * a);
      _dot(
        canvas,
        p + ui.Offset(-br * 0.35, -br * 0.35),
        br * 0.3,
        m.glint,
        0.6 * a,
      );
    } else {
      final pop = (ph - 0.86) / 0.14;
      vfxSpill(
        canvas,
        p,
        r * (0.05 + 0.08 * pop),
        m.glint,
        0.35 * (1 - pop) * a,
      );
    }
  }
  // Fumes lifting off it.
  for (var i = 0; i < (reduce ? 2 : 3); i++) {
    final ph = (time * 0.35 + i / 3 + vfxHash(seed)) % 1.0;
    final p =
        c + vfxPolar(seed + i * 2.1, r * 0.3) + ui.Offset(0, -ph * r * 0.5);
    vfxSpill(canvas, p, r * (0.2 + 0.2 * ph), m.light, 0.12 * sin(ph * pi) * a);
  }
}

/// Earth: the ground broken round the stone, fissures running out of it, a
/// tremor still going through it. The stun covers the whole field.
void _rubble(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  VfxMaterial m,
  double seed,
  double time,
  double grow,
  double a,
  double stoneA,
  bool reduce,
) {
  vfxSpill(canvas, c, r, m.light, 0.2 * a);
  vfxFillPath(
    canvas,
    vfxBlob(c, r * 0.82 * grow, seed, n: 14, wobble: 0.2),
    m.ink,
    0.5 * a,
  );
  // The tremor that holds anything standing in it.
  final beat = (time / 1.1 + vfxHash(seed)) % 1.0;
  vfxSoftRing(
    canvas,
    c,
    r * (0.25 + 0.65 * beat),
    r * 0.16,
    m.light,
    0.2 * (1 - beat) * a,
  );
  final fissures = reduce ? 4 : 6;
  for (var i = 0; i < fissures; i++) {
    final ang = seed + i * pi * 2 / fissures + (vfxHash(seed + i) - 0.5) * 0.6;
    final spine = _jagSpine(
      c + vfxPolar(ang, r * 0.1),
      c + vfxPolar(ang, r * (0.6 + 0.25 * vfxHash(seed + i * 3)) * grow),
      seed + i * 5,
      n: 5,
      jag: 0.2,
    );
    vfxFillPath(
      canvas,
      vfxRibbon(
        [for (final p in spine) p + const ui.Offset(-1.5, -1.5)],
        r * 0.05,
        0.6,
      ),
      m.glint,
      0.3 * a,
    );
    vfxFillPath(canvas, vfxRibbon(spine, r * 0.045, 0.5), _black, 0.75 * a);
  }
  final rocks = reduce ? 6 : 10;
  for (var i = 0; i < rocks; i++) {
    final ang = seed * 1.9 + i * 2.399;
    final p =
        c + vfxPolar(ang, r * (0.3 + 0.55 * vfxHash(seed + i * 2.6)) * grow);
    vfxChunk(
      canvas,
      p,
      r * (0.04 + 0.04 * vfxHash(seed + i * 1.3)),
      seed + i * 4,
      m,
      alpha: a,
      rot: ang,
      faceAlpha: 0.9,
    );
  }
  _stone(canvas, c, r * 0.12, m, seed, stoneA, faceAlpha: 0.85);
}

/// Mud: the stone half sunk in a pool that closes over whatever wades in.
void _mire(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  VfxMaterial m,
  double seed,
  double time,
  double grow,
  double a,
  double stoneA,
  bool reduce,
) {
  vfxFillPath(
    canvas,
    vfxBlob(c, r * 0.82 * grow, seed, n: 18, wobble: 0.08),
    m.ink,
    0.84 * a,
  );
  vfxFillPath(
    canvas,
    vfxBlob(
      c + const ui.Offset(-3, -2),
      r * 0.66 * grow,
      seed + 2,
      n: 16,
      wobble: 0.1,
    ),
    m.mid,
    0.3 * a,
  );
  // Slow rings from the stone, soft bands on the surface.
  final ripple = (time * 0.38 + vfxHash(seed)) % 1.0;
  vfxSoftRing(
    canvas,
    c,
    r * (0.12 + 0.55 * ripple) * grow,
    r * 0.06,
    m.glint,
    0.1 * (1 - ripple) * a,
  );
  for (var i = 0; i < 3; i++) {
    vfxFillPath(
      canvas,
      vfxCrescent(
        c,
        r * (0.62 - i * 0.17) * grow,
        r * 0.028,
        seed + i * 2.1 + 0.8,
        0.9,
      ),
      m.glint,
      0.15 * a,
    );
  }
  // Clods thrown onto the rim.
  final clods = reduce ? 4 : 7;
  for (var i = 0; i < clods; i++) {
    final ang = seed + i * pi * 2 / clods + (vfxHash(seed + i) - 0.5) * 0.4;
    vfxFillPath(
      canvas,
      vfxBlob(
        c + vfxPolar(ang, r * 0.8 * grow),
        r * 0.05,
        seed + i,
        n: 8,
        wobble: 0.3,
        squash: 0.7,
      ),
      m.mid,
      0.7 * a,
    );
  }
  _stone(canvas, c, r * 0.07, m, seed, stoneA * 0.9);
  // The mud closing round the stone's foot.
  vfxFillPath(
    canvas,
    vfxBlob(
      c + ui.Offset(0, r * 0.035),
      r * 0.085,
      seed + 9,
      n: 10,
      wobble: 0.2,
      squash: 0.55,
    ),
    m.ink,
    0.9 * stoneA,
  );
}

/// Light: a well of warm light round a pale star-stone, motes rising off it.
void _wellOfLight(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  VfxMaterial m,
  double seed,
  double time,
  double grow,
  double a,
  double stoneA,
  bool reduce,
) {
  final breathe = 0.88 + 0.12 * sin(time * 1.6 + seed);
  vfxSpill(canvas, c, r * grow, m.light, 0.26 * a * breathe);
  vfxSpill(canvas, c, r * 0.45 * grow, m.glint, 0.3 * a * breathe);
  if (!reduce) {
    // Warmer patches drifting through the pool.
    for (var i = 0; i < 5; i++) {
      final ang = seed + i * pi * 2 / 5 + time * 0.18;
      final d = r * (0.25 + 0.12 * sin(time * 0.6 + i * 1.9)) * grow;
      vfxSpill(canvas, c + vfxPolar(ang, d), r * 0.34, m.glint, 0.09 * a);
    }
  }
  final motes = reduce ? 5 : 9;
  for (var i = 0; i < motes; i++) {
    final ph = (time * 0.42 + vfxHash(seed + i * 1.9)) % 1.0;
    final base =
        c +
        vfxPolar(
          vfxHash(seed + i) * pi * 2,
          r * 0.75 * vfxHash(seed + i * 2.8) * grow,
        );
    final p = base + ui.Offset(0, -ph * r * 0.45);
    vfxFillPath(
      canvas,
      vfxDrop(p, 2.2 * (1 - ph * 0.4), -pi / 2),
      m.glint,
      0.75 * sin(ph * pi) * a,
    );
  }
  _stone(
    canvas,
    c,
    r * 0.08,
    m,
    seed,
    stoneA,
    heat: 0.6 * breathe,
    faceAlpha: 0.95,
  );
}

/// Steam: the stone bored a vent, and the vent is still going — a surge every
/// breath that the push rides on.
void _vent(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  VfxMaterial m,
  double seed,
  double time,
  double grow,
  double a,
  double stoneA,
  bool reduce,
) {
  final cyc = (time / 1.4 + vfxHash(seed)) % 1.0;
  final surge = pow(1.0 - cyc, 2).toDouble();
  vfxSpill(canvas, c, r, m.light, 0.12 * a);
  vfxFillPath(
    canvas,
    vfxBlob(c, r * 0.76 * grow, seed, n: 14, wobble: 0.15),
    m.ink,
    0.46 * a,
  );
  vfxSpill(canvas, c, r * 0.5, m.mid, 0.2 * a);
  _stone(canvas, c + vfxPolar(seed, r * 0.26), r * 0.075, m, seed, stoneA);
  vfxFillPath(
    canvas,
    vfxBlob(c, r * 0.18, seed + 4, n: 10, wobble: 0.25),
    _black,
    0.72 * a,
  );
  vfxSoftRing(
    canvas,
    c,
    r * (0.22 + 0.62 * cyc),
    r * 0.16,
    m.light,
    0.16 * surge * a,
  );
  if (!reduce) {
    for (var i = 0; i < 5; i++) {
      final ang = seed + i * pi * 2 / 5;
      final p = c + vfxPolar(ang, r * (0.2 + 0.5 * cyc));
      vfxFillPath(
        canvas,
        vfxDrop(p, 1.2 + r * 0.012, ang),
        m.glint,
        0.5 * surge * a,
      );
    }
  }
  final puffs = reduce ? 4 : 8;
  for (var i = 0; i < puffs; i++) {
    final ph = (time * 0.6 + i / puffs + vfxHash(seed)) % 1.0;
    final drift = sin(i * 2.1 + ph * 2.4) * r * (0.12 + 0.3 * ph);
    final p = c + ui.Offset(drift, -ph * r * 0.95);
    vfxSpill(
      canvas,
      p,
      r * (0.22 + 0.45 * ph),
      i.isEven ? m.glint : m.light,
      (0.14 + 0.12 * surge) * sin(ph * pi) * a,
    );
  }
}

/// Plant: one vine, coiled where it grew and waiting. [r] is the reach it
/// strikes at, and it is spent the first time something comes into it.
void _vine(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  VfxMaterial m,
  double seed,
  double time,
  double grow,
  double a,
  bool reduce,
) {
  vfxSpill(canvas, c, r * 1.25, m.light, 0.13 * a);
  // Turned soil where it came up.
  vfxFillPath(
    canvas,
    vfxBlob(c, r * 0.62 * grow, seed + 2, n: 10, wobble: 0.3),
    m.ink,
    0.5 * a,
  );
  vfxFillPath(
    canvas,
    vfxBlob(c, r * 0.3, seed, n: 9, wobble: 0.3),
    m.ink,
    0.82 * a,
  );
  final tendrils = reduce ? 3 : 4;
  for (var i = 0; i < tendrils; i++) {
    final sway = sin(time * 1.6 + i * 1.3 + seed) * 0.14;
    final ang =
        seed +
        i * pi * 2 / tendrils +
        (vfxHash(seed + i * 5.3) - 0.5) * 0.6 +
        sway;
    final curl = (i.isEven ? 1.0 : -1.0) * (0.45 + 0.35 * vfxHash(seed + i));
    final len = r * (0.75 + 0.4 * vfxHash(seed + i * 2.2)) * grow;
    final base = c + vfxPolar(ang, r * 0.1);
    final spine = <ui.Offset>[
      for (var k = 0; k <= 7; k++)
        base + vfxPolar(ang + curl * pow(k / 7, 1.8), len * k / 7),
    ];
    vfxFillPath(canvas, vfxRibbon(spine, r * 0.2, 0.8), m.mid, 0.92 * a);
    vfxFillPath(canvas, vfxRibbon(spine, r * 0.06, 0.3), m.glint, 0.22 * a);
    // Thorns on the outside of the curl.
    for (final k in const [4]) {
      final p = spine[k];
      final tan = spine[k + 1] - spine[k - 1];
      final ta = atan2(tan.dy, tan.dx);
      vfxFillPath(
        canvas,
        vfxShard(
          p + vfxPolar(ta - pi / 2 * curl.sign, r * 0.05),
          r * 0.09,
          r * 0.025,
          ta - pi / 2 * curl.sign,
        ),
        m.ink,
        0.9 * a,
      );
    }
    if (i.isOdd) {
      vfxFillPath(
        canvas,
        vfxLeaf(spine[3], r * 0.32, ang + curl * 1.2),
        m.mid,
        0.75 * a,
      );
    }
    // The tip, lit — this is what strikes.
    final pulse = 0.6 + 0.4 * sin(time * 3 + i * 1.7);
    _dot(canvas, spine.last, r * 0.05, m.glint, 0.55 * pulse * a);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Aftermath beats
// ─────────────────────────────────────────────────────────────────────────

enum LetFxKind { blast, splash, gust, drain, frost, crystal, soul, chain, lash }

/// One short-lived Let aftermath effect. Each game owns a list; stepping and
/// painting are shared — the same arrangement as [HornFx].
class LetFx {
  LetFx._({
    required this.kind,
    required this.position,
    required this.duration,
    this.radius = 0,
    this.target = ui.Offset.zero,
    this.points = const [],
    this.anchor,
  }) : age = 0,
       seed = (position.dx * 0.13 + position.dy * 0.07).abs() % 89.0;

  /// Fire's kill explosion. [radius] is the reach it actually damages.
  factory LetFx.blast({required ui.Offset position, required double radius}) =>
      LetFx._(
        kind: LetFxKind.blast,
        position: position,
        radius: radius,
        duration: 0.8,
      );

  /// Water's splash. [radius] is the splash's damage reach.
  factory LetFx.splash({required ui.Offset position, required double radius}) =>
      LetFx._(
        kind: LetFxKind.splash,
        position: position,
        radius: radius,
        duration: 0.62,
      );

  /// Air's knockback, leaving the crater.
  factory LetFx.gust({required ui.Offset position, required double radius}) =>
      LetFx._(
        kind: LetFxKind.gust,
        position: position,
        radius: radius,
        duration: 0.5,
      );

  /// Blood leeching one body toward the kill.
  factory LetFx.drain({required ui.Offset from, required ui.Offset to}) =>
      LetFx._(
        kind: LetFxKind.drain,
        position: from,
        target: to,
        duration: 0.55,
      );

  /// Ice holding the struck body. Follows [anchor] while it returns a
  /// position; shatters early when it returns null.
  factory LetFx.frost({
    required ui.Offset position,
    required double bodyRadius,
    required double duration,
    ui.Offset? Function()? anchor,
  }) => LetFx._(
    kind: LetFxKind.frost,
    position: position,
    radius: bodyRadius,
    duration: duration,
    anchor: anchor,
  );

  /// Crystal growing over the struck body while the slow holds.
  factory LetFx.crystal({
    required ui.Offset position,
    required double bodyRadius,
    required double duration,
    ui.Offset? Function()? anchor,
  }) => LetFx._(
    kind: LetFxKind.crystal,
    position: position,
    radius: bodyRadius,
    duration: duration,
    anchor: anchor,
  );

  /// Spirit's execute: the soul leaving the body.
  factory LetFx.soul({
    required ui.Offset position,
    required double bodyRadius,
  }) => LetFx._(
    kind: LetFxKind.soul,
    position: position,
    radius: bodyRadius,
    duration: 0.85,
  );

  /// A chain of lightning through [points], in order.
  factory LetFx.chain({required List<ui.Offset> points}) => LetFx._(
    kind: LetFxKind.chain,
    position: points.isEmpty ? ui.Offset.zero : points.first,
    points: List.unmodifiable(points),
    duration: 0.34,
  );

  /// A vine striking whatever came into its reach.
  factory LetFx.lash({required ui.Offset from, required ui.Offset to}) =>
      LetFx._(kind: LetFxKind.lash, position: from, target: to, duration: 0.42);

  final LetFxKind kind;
  ui.Offset position;
  final ui.Offset target;
  final List<ui.Offset> points;
  final double radius;
  final double seed;
  double duration;
  double age;

  /// Where the thing this effect sits on is now, or null once it is gone.
  final ui.Offset? Function()? anchor;

  double get t => (age / duration).clamp(0.0, 1.0);
  bool get dead => age >= duration;
}

/// How long a held effect takes to break once its hold ends.
const double _kLetFxBreak = 0.28;

void updateLetFx(List<LetFx> fx, double dt) {
  if (fx.isEmpty) return;
  for (final f in fx) {
    f.age += dt;
    final anchor = f.anchor;
    if (anchor == null) continue;
    final at = anchor();
    if (at != null) {
      f.position = at;
    } else if (f.age < f.duration - _kLetFxBreak) {
      // The body is gone: break now rather than hang in the air.
      f.duration = f.age + _kLetFxBreak;
    }
  }
  fx.removeWhere((f) => f.dead);
}

void pushLetFx(List<LetFx> fx, LetFx f, {int cap = 28}) {
  if (fx.length >= cap) fx.removeAt(0);
  fx.add(f);
}

void drawLetFx(ui.Canvas canvas, List<LetFx> fx, {bool reduceAmbient = false}) {
  for (final f in fx) {
    switch (f.kind) {
      case LetFxKind.blast:
        _drawBlast(canvas, f, reduceAmbient);
      case LetFxKind.splash:
        _drawSplash(canvas, f, reduceAmbient);
      case LetFxKind.gust:
        _drawGust(canvas, f, reduceAmbient);
      case LetFxKind.drain:
        _drawDrain(canvas, f);
      case LetFxKind.frost:
        _drawHold(canvas, f, vfxMaterial('Ice'), crystal: false);
      case LetFxKind.crystal:
        _drawHold(canvas, f, vfxMaterial('Crystal'), crystal: true);
      case LetFxKind.soul:
        _drawSoul(canvas, f);
      case LetFxKind.chain:
        _drawChain(canvas, f);
      case LetFxKind.lash:
        _drawLash(canvas, f);
    }
  }
}

/// Fire's second blast: a fireball out of the kill, flame thrown to the
/// reach it damages, and a shock that marks that reach.
void _drawBlast(ui.Canvas canvas, LetFx f, bool reduce) {
  final m = vfxMaterial('Fire');
  final t = f.t;
  final fade = 1.0 - t;
  final c = f.position;
  final big = f.radius;
  final ease = _easeOut(t / 0.5);
  final seed = f.seed;
  vfxSpill(canvas, c, big * (0.5 + 0.5 * ease), m.light, 0.2 * fade * fade);
  final shockT = _c01(t / 0.55);
  vfxSoftRing(
    canvas,
    c,
    big * (0.12 + 0.88 * _easeOutFast(shockT)),
    big * (0.1 + 0.06 * (1 - shockT)),
    m.light,
    0.3 * pow(1 - shockT, 2.5).toDouble(),
  );
  final fb = big * 0.15 * (0.45 + ease);
  // Smoke rolling off the outside, flame under it, white heat at the heart.
  vfxFillPath(
    canvas,
    vfxBlob(c, fb * (1.3 + 0.5 * t), seed + t * 2, n: 12, wobble: 0.24),
    m.ink,
    0.55 * sin(t * pi),
  );
  vfxFillPath(
    canvas,
    vfxBlob(c, fb * 1.05, seed + 1 + t * 3, n: 12, wobble: 0.22),
    m.mid,
    0.75 * fade,
  );
  vfxFillPath(
    canvas,
    vfxBlob(c, fb * 0.7, seed + 2 - t * 3, n: 10, wobble: 0.25),
    m.light,
    0.8 * fade * fade,
  );
  vfxSpill(canvas, c, fb * 0.8, m.glint, 0.95 * _c01(1 - t / 0.5));
  final tongues = reduce ? 6 : 12;
  for (var i = 0; i < tongues; i++) {
    final a = seed + i * pi * 2 / tongues + (vfxHash(seed + i) - 0.5) * 0.4;
    final reach = 0.7 + 0.3 * vfxHash(seed + i * 2.3);
    final p = c + vfxPolar(a, big * (0.08 + 0.42 * ease) * reach);
    final s = big * 0.022 * (1 - 0.6 * t) + 2;
    vfxFillPath(canvas, vfxDrop(p, s, a), m.mid, 0.85 * fade);
    vfxFillPath(canvas, vfxDrop(p, s * 0.5, a), m.glint, 0.9 * fade);
  }
  if (!reduce) {
    for (var i = 0; i < 8; i++) {
      final a = seed * 1.7 + i * pi / 4;
      final p =
          c +
          vfxPolar(
            a,
            big * (0.15 + 0.6 * ease) * (0.6 + 0.4 * vfxHash(seed + i * 5)),
          );
      vfxFillPath(canvas, vfxDrop(p, 2.2, a), m.glint, 0.8 * fade);
    }
  }
}

/// Water's splash: a wet stain, a sheet running out to the splash's reach,
/// and a crown of drops thrown over it.
void _drawSplash(ui.Canvas canvas, LetFx f, bool reduce) {
  final m = vfxMaterial('Water');
  final t = f.t;
  final fade = 1.0 - t;
  final c = f.position;
  final big = f.radius;
  final ease = _easeOut(t / 0.6);
  vfxFillPath(
    canvas,
    vfxBlob(c, big * (0.3 + 0.15 * ease), f.seed, n: 14, wobble: 0.16),
    m.ink,
    0.45 * fade,
  );
  // The sheet of water running out, broken into waves of its own lengths so
  // it never closes into a ring.
  final sheet = big * (0.2 + 0.8 * _easeOutFast(t));
  final waves = reduce ? 4 : 7;
  for (var i = 0; i < waves; i++) {
    final a =
        f.seed * 1.9 + i * pi * 2 / waves + (vfxHash(f.seed + i) - 0.5) * 0.5;
    final rr = sheet * (0.85 + 0.2 * vfxHash(f.seed + i * 3.3));
    final sweep = 0.55 + 0.4 * vfxHash(f.seed + i * 1.7);
    vfxFillPath(
      canvas,
      vfxCrescent(c, rr, big * 0.09 * fade + 2, a, sweep),
      m.mid,
      0.5 * fade,
    );
    vfxFillPath(
      canvas,
      vfxCrescent(c, rr, big * 0.03 * fade + 1, a, sweep * 0.8),
      m.glint,
      0.35 * fade,
    );
  }
  final drops = reduce ? 8 : 16;
  for (var i = 0; i < drops; i++) {
    final a = f.seed + i * pi * 2 / drops + (vfxHash(f.seed + i) - 0.5) * 0.35;
    final reach = 0.6 + 0.4 * vfxHash(f.seed + i * 3.7);
    final p = c + vfxPolar(a, big * (0.12 + 0.78 * ease) * reach);
    final s = big * 0.022 * (1 - 0.5 * t) + 1.2;
    vfxFillPath(canvas, vfxDrop(p, s, a), m.mid, 0.9 * fade);
    _dot(canvas, p + vfxPolar(a, s * 0.2), s * 0.3, m.glint, 0.55 * fade);
  }
  if (!reduce) {
    for (var i = 0; i < 4; i++) {
      final p = c + vfxPolar(f.seed + i * pi / 2, big * 0.35 * ease);
      vfxSpill(canvas, p, big * 0.22, m.light, 0.14 * fade);
    }
  }
}

/// Air's knockback: wind leaving the crater, out to the reach it shoves.
void _drawGust(ui.Canvas canvas, LetFx f, bool reduce) {
  final m = vfxMaterial('Air');
  final t = f.t;
  final fade = 1.0 - t;
  final c = f.position;
  final big = f.radius;
  vfxSpill(canvas, c, big * 0.45, m.light, 0.2 * fade);
  // The shove, seen in the air it moves: puffs pushed out along every
  // line from the crater, each one leaning into its own curl. Streaming,
  // never tangential — a ring of arcs reads as a shield, not a blast.
  final lanes = reduce ? 7 : 13;
  for (var i = 0; i < lanes; i++) {
    final a = f.seed + i * pi * 2 / lanes + (vfxHash(f.seed + i) - 0.5) * 0.3;
    final reach = 0.6 + 0.4 * vfxHash(f.seed + i * 2.7);
    final lag = 0.08 * vfxHash(f.seed + i * 5.1);
    final e = _easeOut((t - lag) / (1 - lag));
    final p = c + vfxPolar(a + e * 0.25, big * (0.1 + 0.85 * e) * reach);
    vfxSpill(canvas, p, big * (0.06 + 0.1 * e), m.light, 0.28 * fade);
    vfxFillPath(
      canvas,
      vfxDrop(p, big * 0.02 * fade + 1.5, a + e * 0.25),
      m.glint,
      0.6 * fade,
    );
  }
}

/// Blood: a body bleeding toward the kill, in drops along a bowed path.
void _drawDrain(ui.Canvas canvas, LetFx f) {
  final m = vfxMaterial('Blood');
  final t = f.t;
  final from = f.position;
  final to = f.target;
  final d = to - from;
  final len = d.distance;
  if (len < 4) return;
  final n = ui.Offset(-d.dy, d.dx) / len;
  final bow = n * len * 0.2 * (vfxHash(f.seed) > 0.5 ? 1 : -1);
  final mid = from + d * 0.5 + bow;
  ui.Offset at(double s) {
    final a = from + (mid - from) * s;
    final b = mid + (to - mid) * s;
    return a + (b - a) * s;
  }

  vfxSpill(canvas, from, 16, m.light, 0.3 * (1 - t));
  for (var i = 0; i < 5; i++) {
    final s = (t * 1.3 - i * 0.07).clamp(0.0, 1.0);
    if (s <= 0 || s >= 1) continue;
    final p = at(s);
    final dir = at(min(1.0, s + 0.05)) - p;
    final size = 3.4 - i * 0.4;
    vfxFillPath(canvas, vfxDrop(p, size, atan2(dir.dy, dir.dx)), m.mid, 0.9);
    _dot(canvas, p, size * 0.3, m.glint, 0.6);
  }
  if (t > 0.75) vfxSpill(canvas, to, 20, m.light, 0.4 * (1 - t) * 4);
}

/// Ice and Crystal holding the body they struck: a crust closes over it,
/// holds, and breaks when the hold ends. Lopsided on purpose — a symmetric
/// ring of spikes reads as a star badge, not as something grown over a body.
void _drawHold(
  ui.Canvas canvas,
  LetFx f,
  VfxMaterial m, {
  required bool crystal,
}) {
  final c = f.position;
  final br = max(8.0, f.radius);
  final formT = _easeOut(f.age / 0.2);
  final left = f.duration - f.age;
  final breakT = _c01(1 - left / _kLetFxBreak);
  final hold = 1.0 - breakT;
  final fly = br * 3.0 * _easeOut(breakT);
  vfxSpill(canvas, c, br * 2.6, m.light, 0.22 * formT * hold);
  if (!crystal) {
    // A shell of ice over the body: translucent, faceted, one lit face.
    final pts = <ui.Offset>[
      for (var k = 0; k < 7; k++)
        c +
            vfxPolar(
              f.seed + k * pi * 2 / 7 + (vfxHash(f.seed + k) - 0.5) * 0.5,
              br * (1.15 + 0.35 * vfxHash(f.seed + k * 2.3)) * formT,
            ),
    ];
    vfxFillPath(canvas, ui.Path()..addPolygon(pts, true), m.mid, 0.42 * hold);
    vfxFillPath(
      canvas,
      ui.Path()..addPolygon([c, pts[0], pts[1], pts[2]], true),
      m.glint,
      0.3 * hold,
    );
  }
  final spikes = crystal ? 4 : 3;
  for (var i = 0; i < spikes; i++) {
    // Clustered on one side of the body, the side the stone came from.
    final a =
        f.seed * 2 +
        (i / (spikes - 1) - 0.5) * (crystal ? 2.2 : 3.4) +
        (vfxHash(f.seed + i) - 0.5) * 0.4;
    final grow = _easeOut((f.age - i * 0.05) / 0.22);
    final p = c + vfxPolar(a, br * (crystal ? 0.55 : 0.95) + fly);
    final len =
        br * (crystal ? 1.5 + 0.6 * vfxHash(f.seed + i * 2) : 0.8) * grow;
    final w = br * (crystal ? 0.5 : 0.3) * grow;
    final alpha = hold + (1 - hold) * (1 - breakT);
    vfxFillPath(
      canvas,
      vfxShard(p, len, w, a),
      crystal ? m.mid : m.glint,
      (crystal ? 0.88 : 0.6) * alpha,
    );
    vfxFillPath(
      canvas,
      vfxShard(p, len * 0.6, w * 0.35, a),
      m.glint,
      (crystal ? 0.6 : 0.4) * alpha,
    );
  }
  if (crystal && hold > 0) {
    final shimmer = 0.5 + 0.5 * sin(f.age * 5 + f.seed);
    _dot(
      canvas,
      c + vfxPolar(f.seed * 2, br * 0.9),
      br * 0.2,
      m.glint,
      0.5 * shimmer * formT * hold,
    );
  }
}

/// Spirit's execute: the soul drawn up out of the body.
void _drawSoul(ui.Canvas canvas, LetFx f) {
  final m = vfxMaterial('Spirit');
  final t = f.t;
  final fade = 1.0 - t;
  final c = f.position;
  final br = max(8.0, f.radius);
  final rise = _easeOut(t);
  vfxSpill(canvas, c, br * 2.4, m.light, 0.32 * fade);
  vfxFillPath(
    canvas,
    vfxBlob(c, br * 0.9, f.seed, n: 8, wobble: 0.25),
    m.ink,
    0.5 * fade,
  );
  final p = c + ui.Offset(sin(t * 6) * br * 0.3, -rise * br * 4.5);
  vfxSpill(canvas, p, br * 2.2, m.light, 0.3 * fade);
  vfxFillPath(
    canvas,
    vfxDrop(p, br * 1.0 * (1 - 0.3 * t), -pi / 2),
    m.mid,
    0.65 * fade,
  );
  vfxFillPath(
    canvas,
    vfxDrop(p, br * 0.55 * (1 - 0.3 * t), -pi / 2),
    m.glint,
    0.9 * fade,
  );
  for (var i = 0; i < 2; i++) {
    final side = i == 0 ? -1.0 : 1.0;
    final lag = _easeOut((t - 0.12).clamp(0.0, 1.0));
    final q = c + ui.Offset(side * br * (0.6 + 0.3 * lag), -lag * br * 3.2);
    vfxFillPath(
      canvas,
      vfxDrop(q, br * 0.28, -pi / 2 + side * 0.3),
      m.glint,
      0.5 * fade,
    );
  }
}

/// A chain of lightning hopping body to body.
void _drawChain(ui.Canvas canvas, LetFx f) {
  if (f.points.length < 2) return;
  final m = vfxMaterial('Lightning');
  final alpha = pow(1.0 - f.t, 1.4).toDouble();
  final step = (f.age * 22).floorToDouble();
  for (var i = 0; i < f.points.length - 1; i++) {
    vfxBolt(
      canvas,
      f.points[i],
      f.points[i + 1],
      step * 5 + i,
      m,
      alpha,
      jag: 0.26,
      segs: 6,
    );
  }
  for (final p in f.points) {
    vfxSpill(canvas, p, 18, m.light, 0.35 * alpha);
  }
}

/// A vine lashing out: the tendril reaches the body, then whips back.
void _drawLash(ui.Canvas canvas, LetFx f) {
  final m = vfxMaterial('Plant');
  final t = f.t;
  final from = f.position;
  final to = f.target;
  final d = to - from;
  final len = d.distance;
  if (len < 2) return;
  final reach = t < 0.45
      ? _easeOut(t / 0.45)
      : 1.0 - _easeOut((t - 0.45) / 0.55) * 0.9;
  final n = ui.Offset(-d.dy, d.dx) / len;
  final spine = <ui.Offset>[
    for (var k = 0; k <= 7; k++)
      from + d * (reach * k / 7) + n * sin(k / 7 * pi) * len * 0.18 * (1 - t),
  ];
  final alpha = t < 0.45 ? 1.0 : 1.0 - (t - 0.45) / 0.55;
  vfxFillPath(canvas, vfxRibbon(spine, 10, 1.6), m.mid, 0.92 * alpha);
  vfxFillPath(canvas, vfxRibbon(spine, 3.2, 0.5), m.glint, 0.3 * alpha);
  for (final k in const [2, 4, 6]) {
    final tan = spine[k + 1] - spine[k - 1];
    final ta = atan2(tan.dy, tan.dx) + (k == 4 ? -pi / 2 : pi / 2);
    vfxFillPath(
      canvas,
      vfxShard(spine[k] + vfxPolar(ta, 3), 5, 1.6, ta),
      m.ink,
      0.9 * alpha,
    );
  }
  if (t > 0.35) {
    final burst = _c01((t - 0.35) / 0.65);
    vfxSpill(canvas, to, 22, m.light, 0.35 * (1 - burst));
    for (var i = 0; i < 4; i++) {
      final a = f.seed + i * pi / 2;
      vfxFillPath(
        canvas,
        vfxLeaf(to + vfxPolar(a, 6 + 18 * burst), 7, a + burst * 3),
        m.mid,
        0.85 * (1 - burst),
      );
    }
  }
}
