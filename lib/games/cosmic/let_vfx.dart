import 'dart:math';
import 'dart:ui' as ui;

import 'cosmic_data.dart';
import 'cosmic_projectile_vfx.dart' show buildTumblingShardPath, drawPlumeWake;
import 'element_ground_art.dart';
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
// Before the landing: the shadow on the ground and the stone in the air
// ─────────────────────────────────────────────────────────────────────────

/// What one element's telegraph is painted with, worked out once: the pool's
/// unit gradient, the light it gathers and the grit drawn in after it.
typedef _TelegraphLook = ({ui.Shader pool, ui.Color light, ui.Color grit});

final Map<String?, _TelegraphLook> _telegraphLooks = {};

_TelegraphLook _telegraphLook(String? element) =>
    _telegraphLooks[element] ??= () {
      final m = vfxMaterial(element);
      // The element's dark, lifted toward its light just far enough to stain
      // the arena floor (about 13% grey): most inks already do, but Water's,
      // Dark's and Blood's are blacker than the floor and vanished into it.
      double lum(ui.Color c) => 0.3 * c.r + 0.59 * c.g + 0.11 * c.b;
      final lift = ((0.13 - lum(m.ink)) / (lum(m.light) - lum(m.ink)))
          .clamp(0.06, 0.24)
          .toDouble();
      final stain = ui.Color.lerp(m.ink, m.light, lift)!.toARGB32() & 0xFFFFFF;
      // Its light taken a little toward its own hue, so the pale materials
      // (Air, Steam, Spirit) do not all gather the same grey.
      final light = ui.Color.lerp(
        m.light,
        elementColor(element ?? ''),
        kVfxGlowingElements.contains(element) ? 0.3 : 0.18,
      )!;
      return (
        // Dense through the middle, easing off toward the edge and gone just
        // past it, where the irregular outline cuts across the fall.
        pool: ui.Gradient.radial(
          ui.Offset.zero,
          1.04,
          [
            ui.Color(0xFF000000 | stain),
            ui.Color(0xFF000000 | stain).withValues(alpha: 0.92),
            ui.Color(0xFF000000 | stain).withValues(alpha: 0.7),
            ui.Color(stain),
          ],
          const [0.0, 0.5, 0.84, 1.0],
        ),
        light: light,
        grit: ui.Color.lerp(m.glint, light, 0.35)!,
      );
    }();

/// The pool's outline at unit size: a few irregular rounds, built once, so a
/// field of telegraphs does not show one stamped disc over and over. Only a
/// little irregular — the edge is the blast's reach and must not mislead.
final List<ui.Path> _telegraphPools = [
  for (var i = 0; i < 6; i++)
    vfxBlob(ui.Offset.zero, 1, 17.0 + i * 5.3, n: 12, wobble: 0.07),
];

/// The ground under an incoming meteor. [progress] runs 0 at the cast to 1 at
/// the landing. [radius] is the blast the landing opens — callers pass
/// `letSkyfallBlastRadius` (or a Deadfall rock's crater) read off the falling
/// projectile — so the cue covers exactly what will be hit at every band.
///
/// A shadow and a gathering light, not a reticle. The element's dark pools
/// over the blast — an irregular round whose edge is the blast's reach,
/// filled, so the width reads without any outline — and deepens as the
/// stone closes. Over it the stone's light, cast ahead of it, starts broad
/// and faint and gathers to the heart, brightening, a little on the side the
/// stone comes in from until it is nearly down; grit is drawn in after it.
/// So the edge of the pool goes dark just as the heart lights: "something
/// lands here, this wide, soon". The telegraphs this replaced were stroked
/// hoops (then a soft band of light round the rim, which still read as one).
///
/// Three fills while the stone is high, four as it closes (one fewer with
/// [reduceAmbient], which drops the grit); gradients cached, no blur, no
/// strokes, no layers.
void drawLetTelegraphShadow({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required String? element,
  required double radius,
  required double progress,
  double time = 0,
  bool reduceAmbient = false,
}) {
  if (radius <= 1) return;
  final t = _c01(progress);
  final look = _telegraphLook(element);
  final c = centre;
  // Stable per mark: the impact point holds still for the whole fall.
  final seed = (c.dx * 0.071 + c.dy * 0.113).abs() % 97.0;
  // Registers at once — a cue that eases in over the whole fall is invisible
  // exactly while it is useful — then deepens with the fall, which speeds up.
  final presence = _easeOut(t * 4.5);
  final close = t * t;

  // The pool, spreading out to the blast as it registers and slowly turning,
  // drawn scaled from its unit outline and gradient, strength on the paint.
  _fill
    ..color = const ui.Color(
      0xFFFFFFFF,
    // Lighter than it was (0.45 to 0.87): at full strength the pool was a
    // flat disc of its colour laid over everything under it.
    ).withValues(alpha: _c01((0.26 + 0.3 * close) * presence))
    ..shader = look.pool;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(seed + time * 0.2);
  canvas.scale(radius * (0.86 + 0.14 * presence));
  canvas.drawPath(
    _telegraphPools[seed.floor() % _telegraphPools.length],
    _fill,
  );
  canvas.restore();
  _fill.shader = null;

  // The stone's light, gathering: broad and faint while it is high, drawn
  // in to the heart and brightening as it drops. It leans toward the side
  // the stone falls in from (every drop comes down the screen) and settles
  // on the centre as it lands, so the cue is lopsided, never a bullseye.
  final heart = c + ui.Offset(0, -radius * 0.16 * (1 - t) * (1 - t));
  vfxSpill(
    canvas,
    heart,
    radius * (0.95 - 0.6 * _easeOut(t)),
    look.light,
    (0.12 + 0.45 * close) * presence,
  );
  // Its hot core, coming up only in the last half of the fall: soon.
  final hot = _c01((t - 0.4) / 0.6);
  vfxSpill(
    canvas,
    heart,
    radius * (0.09 + 0.1 * hot),
    look.grit,
    0.6 * hot * hot * (3 - 2 * hot),
  );

  if (reduceAmbient) return;
  // Grit drawn in after the light: each grain lifts where it lay, is pulled
  // in on one shared curl, and slows as it collects at the heart, where the
  // light swallows it. One batch; few, so it never traces the rim.
  vfxGrainsDiscard();
  final n = (radius / 6).clamp(14.0, 40.0).round();
  for (var i = 0; i < n; i++) {
    final u = (time * 0.7 + vfxHash(seed + i * 1.7)) % 1.0;
    final e = 1 - (1 - u) * (1 - u);
    final from = radius * (0.6 + 0.34 * vfxHash(seed + i * 3.1));
    final ang = seed + i * 2.399 + 0.9 * e;
    final d = from * (1 - 0.86 * e);
    vfxGrain(heart.dx + cos(ang) * d, heart.dy + sin(ang) * d);
  }
  vfxGrainsFlush(canvas, max(1.6, radius * 0.011), look.grit, 0.7 * presence);
  // The reach, marked in loose grit where the pool's edge used to carry it:
  // a broken scatter round the blast, never a closed ring.
  final rim = (radius / 3.2).clamp(24.0, 110.0).round();
  for (var i = 0; i < rim; i++) {
    if (vfxHash(seed + i * 4.1) > 0.72) continue;
    final ang = seed + i * pi * 2 / rim + time * 0.2;
    final d = radius * (0.9 + 0.1 * vfxHash(seed + i * 2.3)) * (0.86 + 0.14 * presence);
    vfxGrain(c.dx + cos(ang) * d, c.dy + sin(ang) * d);
  }
  vfxGrainsFlush(
    canvas,
    max(1.6, radius * 0.012),
    look.light,
    (0.4 + 0.4 * close) * presence,
  );
}

/// Per-element stone and wake proportions for a falling Let:
/// (body, elongation, flatten, wake length, wake width). Earth is a slow
/// heavy boulder with a stubby wake; Lightning a small fast sliver with a
/// long thin one; Steam has almost no body at all.
const Map<String, (double, double, double, double, double)> _kMeteorBuild = {
  'Earth': (1.55, 1.04, 0.96, 0.70, 1.35),
  'Mud': (1.34, 1.02, 1.00, 0.78, 1.34),
  'Lava': (1.30, 1.14, 0.90, 0.86, 1.26),
  'Steam': (1.22, 1.10, 0.96, 0.92, 1.50),
  'Dark': (1.18, 1.08, 0.94, 1.04, 1.02),
  'Water': (1.10, 1.58, 0.76, 1.20, 1.12),
  'Plant': (1.12, 1.16, 0.90, 0.96, 1.06),
  'Poison': (1.06, 1.26, 0.84, 1.00, 1.16),
  'Dust': (1.06, 1.20, 0.86, 1.02, 1.22),
  'Blood': (1.05, 1.30, 0.80, 1.00, 1.00),
  'Fire': (1.00, 1.36, 0.78, 1.26, 1.10),
  'Crystal': (1.00, 1.32, 0.68, 1.00, 0.90),
  'Ice': (0.96, 1.50, 0.60, 1.12, 0.82),
  'Light': (0.92, 1.46, 0.70, 1.30, 0.94),
  'Air': (0.90, 1.72, 0.64, 1.32, 0.90),
  'Spirit': (0.86, 1.52, 0.70, 1.16, 0.84),
  'Lightning': (0.80, 1.92, 0.52, 1.38, 0.70),
};

/// How each element's wake moves: (wave amplitude, wave frequency). Wet heavy
/// elements billow in lazy curves, light fast ones chop, Earth barely moves.
const Map<String, (double, double)> _kMeteorFlow = {
  'Earth': (0.30, 0.55),
  'Crystal': (0.38, 0.75),
  'Ice': (0.44, 0.80),
  'Mud': (1.14, 0.50),
  'Water': (1.18, 0.62),
  'Steam': (1.26, 0.58),
  'Blood': (0.98, 0.70),
  'Lava': (1.02, 0.66),
  'Poison': (1.08, 0.78),
  'Plant': (0.90, 0.86),
  'Fire': (0.94, 1.05),
  'Dust': (1.06, 1.15),
  'Dark': (0.82, 0.68),
  'Spirit': (1.12, 0.92),
  'Light': (0.64, 1.10),
  'Air': (1.20, 1.35),
  'Lightning': (0.72, 1.80),
};

/// A Let meteor in flight — the special's falling stone, every Let basic and
/// every Deadfall rock.
///
/// A stone of the element's material: a dark tumbling body, a lit face, heat
/// on the leading edge, its light poured out behind as a plume, and grains
/// shed into the wake, some flaring white as they go — that is the sparkle.
/// The meteor this replaced wore four-point star glints, a white pip, an
/// outline stroke, Earth's squares and Lava's line fissures, and allocated
/// ~20 Paints a frame.
///
/// The stone is sized from the projectile's contact radius, read at draw
/// time, so it grows with the caster exactly as the hit does. (The old body
/// clamped visualScale at 4.8 and froze — even shrank — from Beauty ~2.6
/// while the contact radius grew x1.9.)
///
/// About 8-10 fills: plume (1-2), bloom, body (3), at most two element
/// pieces, two grain batches. No Paint allocation, no blur.
void drawLetMeteor({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required double time,
  bool reduceAmbient = false,
}) {
  final element = projectile.element;
  final m = vfxMaterial(element);
  final build = _kMeteorBuild[element ?? ''] ?? (1.0, 1.24, 0.88, 1.0, 1.0);
  final flow = _kMeteorFlow[element ?? ''] ?? (1.0, 0.9);
  // Distance is the cue that makes a drop read as a drop: the stone swells
  // through the descent while its wake stretches.
  final fall = projectile.skyfallDuration > 0
      ? projectile.skyfallProgress
      : 1.0;
  final approach = 0.62 + 0.38 * fall;
  final stretch = 0.70 + 0.62 * fall;
  final hitR = Projectile.radius * projectile.radiusMultiplier;
  // The physique leans each element a little heavier or lighter, but the
  // stone stays within ~15% of the hit it stands for.
  final bodyR = max(2.5, hitR) * (0.7 + 0.3 * build.$1) * approach;
  final elong = build.$2, flat = build.$3;
  final heading = projectile.angle;
  final dir = ui.Offset(cos(heading), sin(heading));
  final perp = ui.Offset(-dir.dy, dir.dx);
  final wakeLen = bodyR * 8.0 * build.$4 * stretch;
  // Stable per stone: remaining life changes every frame, so it cannot seed
  // anything that should hold still.
  final seed = (identityHashCode(projectile) % 89).toDouble();
  final pulse = 0.84 + 0.16 * sin(time * 6.0 + seed);
  final isDark = element == 'Dark';
  final isLight = element == 'Light';

  // The plume: the element's own light poured out behind the stone.
  drawPlumeWake(
    canvas: canvas,
    head: position,
    travelDir: dir,
    length: wakeLen,
    headWidth: bodyR * 2.0 * build.$5,
    color: isDark ? m.mid : m.light,
    hotColor: m.glint,
    time: time,
    alpha: 0.34 * pulse,
    layers: reduceAmbient ? 1 : 2,
    seed: seed,
    waveAmplitude: flow.$1,
    waveFrequency: flow.$2,
  );

  // What it throws on its surroundings: heat ahead of it — or, for Dark, the
  // light it swallows.
  if (isDark) {
    vfxSpill(canvas, position, bodyR * 2.4, _black, 0.7);
  } else {
    vfxSpill(
      canvas,
      position + dir * bodyR * 0.35,
      bodyR * (isLight ? 3.4 : 2.1),
      m.light,
      (isLight ? 0.30 : 0.20) * pulse,
    );
  }

  // The stone: dark body, lit face, heat on the leading edge.
  final spin = time * 2.2 + seed;
  vfxFillPath(
    canvas,
    buildTumblingShardPath(
      centre: position,
      radius: bodyR,
      travelDir: dir,
      spin: spin,
      elongation: elong,
      flatten: flat,
    ),
    isDark ? _black : m.ink,
    0.94,
  );
  vfxFillPath(
    canvas,
    buildTumblingShardPath(
      centre: position + dir * bodyR * 0.2 - perp * bodyR * 0.08,
      radius: bodyR * 0.64,
      travelDir: dir,
      spin: spin + 0.6,
      elongation: elong,
      flatten: flat,
    ),
    element == 'Lava' ? m.light : m.mid,
    isDark ? 0.5 : 0.82,
  );
  canvas.save();
  canvas.translate(position.dx, position.dy);
  canvas.rotate(heading);
  canvas.scale(elong, flat);
  vfxFillPath(
    canvas,
    vfxCrescent(ui.Offset.zero, bodyR * 0.9, bodyR * 0.24, 0, 2.0),
    m.glint,
    (isDark ? 0.45 : 0.55) * pulse,
  );
  canvas.restore();

  _meteorShed(canvas, element, m, position, dir, perp, bodyR, wakeLen, time);

  // Grains shed into the wake — Dark's fall into it instead — and the few
  // catching the light flare white. Two batches: the grains, then the flares.
  final grains =
      (reduceAmbient ? 10 : 16) +
      (element == 'Dust' || element == 'Earth' || element == 'Mud' ? 6 : 0);
  final flareShare = switch (element) {
    'Lightning' => 0.45,
    'Light' || 'Crystal' || 'Ice' => 0.30,
    _ => 0.18,
  };
  final grainSize = max(1.1, bodyR * 0.10);
  for (var pass = 0; pass < 2; pass++) {
    vfxGrainsDiscard();
    for (var i = 0; i < grains; i++) {
      final h = vfxHash(seed + i * 1.31);
      final h2 = vfxHash(seed + i * 2.77);
      final tw = 0.5 + 0.5 * sin(time * (5.0 + 4.0 * h) + i * 2.1);
      if ((tw > 1.0 - flareShare) != (pass == 1)) continue;
      final u = (time * (0.9 + 0.5 * h) * flow.$2 + h2) % 1.0;
      if (u > 0.8 && h2 > 0.6) continue;
      if (isDark) {
        final p = position + vfxPolar(seed + i * 2.399 + u * 2.2, bodyR * (3.2 - 2.4 * u));
        vfxGrain(p.dx, p.dy);
        continue;
      }
      final along = bodyR * 0.6 + wakeLen * 0.8 * u;
      final across =
          (h - 0.5) * bodyR * 1.8 * (0.35 + u) +
          sin(time * 2.6 + i * 1.7) * bodyR * 0.3 * u * flow.$1;
      final p = position - dir * along + perp * across;
      vfxGrain(p.dx, p.dy);
    }
    if (pass == 0) {
      vfxGrainsFlush(canvas, grainSize, m.glint, 0.62);
    } else {
      vfxGrainsFlush(canvas, grainSize * 1.8, vfxFlare(m), 0.95);
    }
  }
}

/// What each falling stone sheds besides grains, as one merged path (one
/// fill). Lightning, Dust, Dark and Light carry theirs in the grains and the
/// bloom.
void _meteorShed(
  ui.Canvas canvas,
  String? element,
  VfxMaterial m,
  ui.Offset c,
  ui.Offset dir,
  ui.Offset perp,
  double bodyR,
  double wakeLen,
  double time,
) {
  final heading = atan2(dir.dy, dir.dx);
  final back = c - dir * bodyR * 0.8;
  final shed = ui.Path();
  // u runs 0 (just shed) to 1 (gone), on a per-piece phase.
  double phase(int i, double rate) => (time * rate + i * 0.37) % 1.0;
  var color = m.mid;
  var alpha = 0.8;
  switch (element) {
    case 'Fire':
      // Flame licking back off the stone.
      for (var i = 0; i < 3; i++) {
        final u = phase(i, 1.6);
        final p =
            back -
            dir * bodyR * (0.2 + 1.4 * u) +
            perp * sin(time * 5 + i * 2.1) * bodyR * 0.35;
        shed.addPath(vfxDrop(p, bodyR * 0.34 * (1 - u * 0.7), heading), ui.Offset.zero);
      }
      alpha = 0.72;
    case 'Lava':
      // Molten drips, heavy and slow.
      for (var i = 0; i < 3; i++) {
        final u = phase(i, 0.85);
        final p =
            back -
            dir * wakeLen * 0.45 * u +
            perp * sin(time * 2 + i * 2.1) * bodyR * 0.5 * u;
        shed.addPath(
          vfxBlob(p, bodyR * 0.2 * (1 - u * 0.8) + 0.6, i + 3.0, n: 7, wobble: 0.3),
          ui.Offset.zero,
        );
      }
      color = m.glint;
      alpha = 0.78;
    case 'Earth' || 'Mud':
      // Rubble or clods breaking off the back.
      for (var i = 0; i < 4; i++) {
        final u = phase(i, element == 'Earth' ? 0.7 : 0.95);
        final p =
            back -
            dir * wakeLen * 0.4 * u +
            perp * sin(i * 2.3 + time) * bodyR * 0.7 * u;
        shed.addPath(
          vfxBlob(
            p,
            bodyR * 0.2 * (1 - u * 0.6) + 0.6,
            i * 1.7,
            n: element == 'Earth' ? 6 : 8,
            wobble: element == 'Earth' ? 0.32 : 0.36,
            squash: element == 'Mud' ? 0.75 : 1,
          ),
          ui.Offset.zero,
        );
      }
      alpha = 0.85;
    case 'Water' || 'Blood':
      // Beads peeling off both flanks.
      for (var i = 0; i < 4; i++) {
        final u = phase(i, 1.1);
        final side = i.isEven ? 1.0 : -1.0;
        final p =
            back -
            dir * wakeLen * 0.4 * u +
            perp * side * bodyR * (0.4 + 0.6 * u);
        shed.addPath(vfxDrop(p, bodyR * 0.18 * (1 - u * 0.6) + 0.5, heading), ui.Offset.zero);
      }
      color = element == 'Water' ? m.glint : m.mid;
      alpha = element == 'Water' ? 0.55 : 0.88;
    case 'Ice':
      // Frost shearing off the flanks and streaming back, points trailing.
      for (var i = 0; i < 3; i++) {
        final u = phase(i, 1.0);
        final side = i.isEven ? 1.0 : -1.0;
        final p =
            back -
            dir * wakeLen * 0.35 * u +
            perp * side * bodyR * (0.5 + 0.5 * u);
        shed.addPath(
          vfxShard(p, bodyR * 0.5 * (1 - u * 0.5), bodyR * 0.12, heading + pi),
          ui.Offset.zero,
        );
      }
      color = m.glint;
      alpha = 0.7;
    case 'Crystal':
      // Light split inside the stone: one lit inner facet.
      shed.addPath(
        vfxShard(c + dir * bodyR * 0.15, bodyR * 0.8, bodyR * 0.22, heading + 0.3),
        ui.Offset.zero,
      );
      color = m.glint;
      alpha = 0.55;
    case 'Plant':
      // Seeds and leaves shaking loose.
      for (var i = 0; i < 3; i++) {
        final u = phase(i, 1.1);
        final p =
            back -
            dir * wakeLen * 0.45 * u +
            perp * sin(time * 2.2 + i * 1.6) * bodyR * 0.8 * u;
        shed.addPath(vfxLeaf(p, bodyR * 0.55 * (1 - u * 0.5), heading + pi + i + time * 3), ui.Offset.zero);
      }
      alpha = 0.82;
    case 'Poison':
      // Bubbles clinging and shearing off.
      for (var i = 0; i < 3; i++) {
        final u = phase(i, 1.2);
        final p =
            c -
            dir * bodyR * (0.4 + 1.6 * u) +
            perp * sin(i * 2.4 + time * 3) * bodyR * 0.6;
        shed.addPath(
          vfxBlob(p, bodyR * 0.22 * (1 - u * 0.5) + 0.5, i * 2.1, n: 8, wobble: 0.2),
          ui.Offset.zero,
        );
      }
      alpha = 0.78;
    case 'Steam':
      // Pressure venting in short puffs.
      for (var i = 0; i < 2; i++) {
        final u = phase(i, 1.4);
        vfxSpill(
          canvas,
          c - dir * bodyR * (0.6 + 1.8 * u) + perp * (i.isEven ? 1 : -1) * bodyR * 0.5,
          bodyR * (0.6 + 0.8 * u),
          m.glint,
          0.26 * (1 - u),
        );
      }
      return;
    case 'Air' || 'Spirit':
      // Streams running past (Air), wisps drawn along (Spirit).
      for (var i = 0; i < 3; i++) {
        final u = phase(i, 1.35);
        final side = (i - 1).toDouble();
        final p =
            c -
            dir * (bodyR * 0.5 + wakeLen * 0.5 * u) +
            perp * side * bodyR * 0.9;
        shed.addPath(vfxDrop(p, bodyR * 0.16 * (1 - u * 0.5) + 0.5, heading), ui.Offset.zero);
      }
      color = m.glint;
      alpha = element == 'Air' ? 0.35 : 0.45;
    default:
      return;
  }
  vfxFillPath(canvas, shed, color, alpha);
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

  // The bowl the stone punched. Dark's is a hole (its filled black bowl is
  // the void, kept as it was). Every other is dark grains, densest at its
  // heart and thinning to nothing at its edge, the inner wall toward the
  // light catching it: a filled disc tinted the element's dark read as a
  // brown, navy or maroon blob.
  final bowl = bowlR * (0.82 + 0.18 * throwT);
  vfxSpill(canvas, c, bowlR * 1.7, _black, 0.28 * settle);
  if (isDark) {
    vfxFillPath(
      canvas,
      vfxBlob(c, bowl, seed, n: 13, wobble: 0.13),
      m.ink,
      0.92 * settle,
    );
  } else {
    final grain = max(2.4, r * 0.024);
    final bed = minor ? 240 : (reduceAmbient ? 400 : 680);
    for (var i = 0; i < bed; i++) {
      if (vfxHash(seed + i * 5.1) > settle * 1.15) continue;
      final rho = pow(vfxHash(seed + i * 1.3), 0.55) * bowl;
      final a = vfxHash(seed + i * 2.7) * pi * 2;
      vfxGrain(c.dx + cos(a) * rho, c.dy + sin(a) * rho * 0.92);
    }
    vfxGrainsFlush(
      canvas,
      grain,
      ui.Color.lerp(m.ink, _black, 0.6)!,
      (isAiry ? 0.45 : 0.8) * settle,
    );
    for (var i = 0; i < (minor ? 30 : 70); i++) {
      final a = pi * 0.25 + (vfxHash(seed + i * 3.3) - 0.5) * 2.2;
      final rho = bowl * (0.55 + 0.38 * vfxHash(seed + i * 4.1));
      vfxGrain(c.dx + cos(a) * rho, c.dy + sin(a) * rho * 0.92);
    }
    vfxGrainsFlush(canvas, grain, m.mid, (isAiry ? 0.3 : 0.55) * settle);
  }
  vfxSpill(canvas, c, bowlR * 0.7, _black, 0.36 * settle);
  // The lip: a band of ground thrown up round the bowl, lumped, the side
  // toward the light catching it. Grains spaced evenly round it read as a
  // dotted circle.
  if (!minor) {
    final n = reduceAmbient ? 110 : 190;
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < n; i++) {
        final a = vfxHash(seed + i * 6.7) * pi * 2;
        final lump = 0.5 + 0.5 * sin(5 * a + seed + 2 * sin(3 * a));
        if (vfxHash(seed + i * 7.9) > 0.3 + 0.7 * lump) continue;
        final lit = cos(a - pi * 1.25) > 0.2;
        if (lit != (pass == 1)) continue;
        final d = bowl * (0.9 + 0.32 * pow(vfxHash(seed + i * 3.7), 1.5));
        vfxGrain(c.dx + cos(a) * d, c.dy + sin(a) * d);
      }
      vfxGrainsFlush(
        canvas,
        max(1.8, r * 0.019),
        pass == 1 ? m.glint : m.mid,
        (pass == 1 ? 0.8 : 0.55) * settle,
      );
    }
  }

  // The light of the landing. Dark swallows its own: a hole ringed in violet.
  if (isDark) {
    vfxSpill(canvas, c, r * 0.9, m.light, 0.12 * shock);
    // A wide band, so the violet round the hole reads as bent light, not
    // as a ring drawn round it.
    vfxSoftRing(canvas, c, bowlR * 1.05, bowlR * 0.3, m.light, 0.3 * settle);
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

  // The ejecta curtain: ground thrown out of the bowl in a few broken
  // sprays, each grain flying out and thinning as the shock dies. (They were
  // filled crescents: arcs drawn round it.)
  if (!minor && !isAiry && shock > 0.02) {
    final sprays = reduceAmbient ? 3 : 5;
    final perSpray = reduceAmbient ? 26 : 44;
    for (var k = 0; k < sprays; k++) {
      final a0 = seed + k * pi * 2 / sprays + (vfxHash(seed + k) - 0.5) * 0.9;
      final width = 0.4 + 0.45 * vfxHash(seed + k * 1.9);
      final reach = 0.85 + 0.35 * vfxHash(seed + k * 4.3);
      for (var i = 0; i < perSpray; i++) {
        final h = vfxHash(seed + k * 97 + i * 1.7);
        if (h > shock * 1.2) continue;
        final a = a0 + (vfxHash(seed + k * 31 + i * 2.3) - 0.5) * width;
        final d = bowl * (0.95 + 0.9 * throwT * reach * (0.5 + 0.5 * h));
        vfxGrain(c.dx + cos(a) * d, c.dy + sin(a) * d);
      }
    }
    vfxGrainsFlush(
      canvas,
      max(1.8, r * 0.018),
      m.mid,
      (0.5 * shock).clamp(0.0, 1.0),
    );
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
      // Charge left in the bowl: a few arcs crawling across it from the lip
      // outward at uneven bearings, writhing as they go (vfxArcInto: two
      // fills for all), with grains flaring where they end — the strike's
      // afterglow, never spokes out of the stone. (These were jagged forks
      // radiating from the bowl, re-rolled at 9 Hz.)
      final alpha = pow(_c01(1 - t / 0.6), 1.4).toDouble();
      final glow = ui.Path();
      final core = ui.Path();
      final arcs = reduce ? 2 : 3;
      final reachR = bowlR * (0.8 + 0.35 * throwT);
      final at = t * kLetCraterDuration;
      vfxGrainsDiscard();
      for (var i = 0; i < arcs; i++) {
        final a0 = seed + i * 2.2 + (vfxHash(seed + i * 3.7) - 0.5) * 0.8;
        final a1 = a0 + 1.5 + 0.9 * vfxHash(seed + i * 5.1);
        final p0 = c + vfxPolar(a0, bowlR * (0.3 + 0.3 * vfxHash(seed + i)));
        final p1 =
            c +
            vfxPolar(a1, reachR * (0.6 + 0.3 * vfxHash(seed + i * 2.3)));
        vfxArcInto(
          glow,
          core,
          p0,
          p1,
          seed + i * 5,
          at,
          width: max(2.0, r * 0.022),
          amp: 0.28,
          rate: 3.0,
        );
        vfxGrain(p1.dx, p1.dy);
      }
      vfxFillPath(canvas, glow, m.light, 0.34 * alpha);
      vfxFillPath(
        canvas,
        core,
        ui.Color.lerp(m.glint, elementColor('Lightning'), 0.3)!,
        0.75 * alpha,
      );
      vfxGrainsFlush(canvas, max(1.6, r * 0.02), vfxFlare(m), 0.9 * alpha);
      vfxSpill(canvas, c, bowlR * 1.3, m.light, 0.24 * fade);
      return;

    case 'Light':
      // Radiance, not rays: the bowl blooms with light and grains of it lift
      // out and drift away, a few flaring white. (This was seven radial lens
      // blades — a starburst.)
      final alpha = pow(fade, 1.6).toDouble();
      vfxSpill(canvas, c, r * (0.4 + 0.35 * throwT), m.light, 0.30 * alpha);
      vfxSpill(canvas, c, bowlR * 0.9, m.glint, 0.45 * alpha * alpha);
      final motes = reduce ? 12 : 22;
      final flick = (t * 6).floorToDouble();
      for (var pass = 0; pass < 2; pass++) {
        vfxGrainsDiscard();
        for (var i = 0; i < motes; i++) {
          final flare = vfxHash(seed + i * 4.3 + flick) > 0.72;
          if (flare != (pass == 1)) continue;
          final h = vfxHash(seed + i * 1.9);
          final p =
              c +
              vfxPolar(
                seed + i * 2.399 + (h - 0.5) * 0.6,
                r * (0.12 + 0.75 * throwT * (0.4 + 0.6 * h)),
              ) +
              ui.Offset(0, -r * 0.18 * t * h);
          vfxGrain(p.dx, p.dy);
        }
        vfxGrainsFlush(
          canvas,
          max(1.3, r * (pass == 1 ? 0.024 : 0.014)),
          pass == 1 ? vfxFlare(m) : m.glint,
          (pass == 1 ? 0.95 : 0.6) * alpha,
        );
      }
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
            r * 0.08,
            reach: 0.7,
          ),
          m.glint,
          0.22 * fade,
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
  // Golden-angle bearings and reaches that differ a lot: thrown, never a
  // wheel of spikes.
  for (var i = 0; i < n; i++) {
    final a = seed * 0.37 + i * 2.399963 + (vfxHash(seed + i) - 0.5) * 0.4;
    final reach = 0.45 + 0.55 * vfxHash(seed + i * 3.1);
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
        final a = seed + i * 2.399963;
        final p = c +
            vfxPolar(
              a,
              bowlR * (0.9 + 0.65 * throwT * (0.6 + 0.4 * vfxHash(seed + i))),
            );
        vfxFillPath(
          canvas,
          vfxDrop(p, r * 0.016 + 1, a),
          m.glint,
          0.6 * crownA,
        );
      }
    case 'Ice':
      // Frost left standing on the lip.
      for (var i = 0; i < (reduce ? 3 : 5); i++) {
        final a = seed * 2.3 + i * 2.399963;
        final p = c + vfxPolar(a, bowlR * (0.85 + 0.2 * vfxHash(seed + i)));
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
        final a = seed * 1.1 + i * 2.399963 + 0.3;
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

  // The element's ground in grains, with no outline
  // (element_ground_art.dart), and the family's stone still at its heart.
  // It spreads out as it arrives and draws back in as it goes.
  canvas.save();
  canvas.translate(c.dx, c.dy);
  final drawn = paintElementGround(
    canvas,
    element,
    r * 1.1 * grow * (0.55 + 0.45 * alpha),
    time,
    seed,
    reduced: reduceAmbient,
  );
  canvas.restore();
  // Undrawn only while it is still too small to see (its first frames) or
  // for an element with no ground: then a little of its light.
  if (!drawn && !kElementGrounds.contains(element)) {
    vfxSpill(canvas, c, r, m.light, 0.18 * alpha);
  }
  _stone(canvas, c, r * 0.1, m, seed, stoneA);
  return true;
}

// ─────────────────────────────────────────────────────────────────────────
// Aftermath beats
// ─────────────────────────────────────────────────────────────────────────

enum LetFxKind {
  blast,
  splash,
  gust,
  drain,
  frost,
  crystal,
  soul,
  chain,
  lash,
  frostFront,
}

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

  /// Kin Ice's release: frost running out to the edge of the slow. [radius]
  /// is the release's real reach (`KinSupport.iceReleaseRadius`). Kept on
  /// this list because it is the one short-lived area beat every game that
  /// casts it already steps and paints.
  factory LetFx.frostFront({
    required ui.Offset position,
    required double radius,
  }) => LetFx._(
    kind: LetFxKind.frostFront,
    position: position,
    radius: radius,
    duration: 0.75,
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
      case LetFxKind.frostFront:
        _drawFrostFront(canvas, f, reduceAmbient);
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
  // Flame thrown on uneven bearings (an even dozen read as a starburst).
  final tongues = reduce ? 5 : 9;
  for (var i = 0; i < tongues; i++) {
    final a = seed + i * 2.399963 + (vfxHash(seed + i) - 0.5) * 0.5;
    final reach = 0.7 + 0.3 * vfxHash(seed + i * 2.3);
    final p = c + vfxPolar(a, big * (0.08 + 0.42 * ease) * reach);
    final s = big * 0.022 * (1 - 0.6 * t) + 2;
    vfxFillPath(canvas, vfxDrop(p, s, a), m.mid, 0.85 * fade);
    vfxFillPath(canvas, vfxDrop(p, s * 0.5, a), m.glint, 0.9 * fade);
  }
  if (!reduce) {
    // Embers as grains, scattered (they were eight drops at exact
    // eighth-turns: an eight-point star).
    vfxGrainsDiscard();
    for (var i = 0; i < 10; i++) {
      final a = seed * 1.7 + i * 2.399963;
      final p =
          c +
          vfxPolar(
            a,
            big * (0.15 + 0.6 * ease) * (0.5 + 0.5 * vfxHash(seed + i * 5)),
          );
      vfxGrain(p.dx, p.dy);
    }
    vfxGrainsFlush(canvas, 2.4, vfxFlare(m), 0.8 * fade);
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
  // Bearings on the golden angle and reaches all different, so the puffs
  // never line up into an even wheel of dashes; the grit they carry is one
  // grain batch (it was thirteen evenly spaced drops: a starburst).
  final lanes = reduce ? 6 : 10;
  vfxGrainsDiscard();
  for (var i = 0; i < lanes; i++) {
    final a = f.seed + i * 2.399963 + (vfxHash(f.seed + i) - 0.5) * 0.4;
    final reach = 0.5 + 0.5 * vfxHash(f.seed + i * 2.7);
    final lag = 0.12 * vfxHash(f.seed + i * 5.1);
    final e = _easeOut((t - lag) / (1 - lag));
    final p = c + vfxPolar(a + e * 0.25, big * (0.1 + 0.85 * e) * reach);
    vfxSpill(canvas, p, big * (0.07 + 0.12 * e), m.light, 0.26 * fade);
    vfxGrain(p.dx, p.dy);
  }
  vfxGrainsFlush(canvas, max(1.8, big * 0.02), m.glint, 0.6 * fade);
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

/// A chain of lightning hopping body to body: one filled writhing arc per
/// hop, the bends gliding between poses (it was a stroked zig-zag re-rolled
/// 22 times a second). All hops share two paths: two fills.
void _drawChain(ui.Canvas canvas, LetFx f) {
  if (f.points.length < 2) return;
  final m = vfxMaterial('Lightning');
  final alpha = pow(1.0 - f.t, 1.4).toDouble();
  final glow = ui.Path();
  final core = ui.Path();
  for (var i = 0; i < f.points.length - 1; i++) {
    vfxArcInto(
      glow,
      core,
      f.points[i],
      f.points[i + 1],
      i * 5.3 + 1.0,
      f.age,
      width: 2.4,
      amp: 0.2,
      segs: 6,
      rate: 3.4,
    );
  }
  vfxFillPath(canvas, glow, m.light, 0.3 * alpha);
  vfxFillPath(
    canvas,
    core,
    ui.Color.lerp(m.glint, elementColor('Lightning'), 0.3)!,
    0.88 * alpha,
  );
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

/// Kin Ice's release: a front of frost running out to the slow's real edge —
/// a broken wall of ice shards with grains flaring where it passes, over a
/// thin rime on everything it swept — never a clean expanding ring. (The
/// release was a 38-67 px puff of particles over a 220-544 px slow.)
void _drawFrostFront(ui.Canvas canvas, LetFx f, bool reduce) {
  final m = vfxMaterial('Ice');
  final t = f.t;
  final c = f.position;
  final big = f.radius;
  final front = big * (0.06 + 0.94 * _easeOutFast(_c01(t / 0.7)));
  final fade = pow(1 - t, 1.3).toDouble();
  // Rime over the swept ground, and the cold the front pushes ahead of it.
  vfxSpill(canvas, c, front, m.light, 0.17 * fade);
  vfxSoftRing(canvas, c, front, big * 0.03 + 4, m.light, 0.15 * fade);
  // The front: frost thrown up along a broken line — small shards lying
  // ALONG it at uneven depths (a crust forming, never spikes radiating from
  // the centre), carried by a dense band of grains, a few flaring white.
  final n = reduce ? 12 : 20;
  final body = ui.Path();
  final s0 = max(3.0, big * 0.022);
  for (var i = 0; i < n; i++) {
    final h = vfxHash(f.seed + i * 1.3);
    final a = f.seed + i * 2.399;
    final p = c + vfxPolar(a, front * (0.86 + 0.14 * h));
    final s = s0 * (0.6 + 0.8 * vfxHash(f.seed + i * 2.3));
    final lean = a + pi / 2 + (h - 0.5) * 1.2;
    body.addPath(vfxShard(p, s * 2.2, s * 0.5, lean), ui.Offset.zero);
  }
  vfxFillPath(canvas, body, m.mid, 0.85 * fade);
  final g = reduce ? 28 : 44;
  for (var pass = 0; pass < 2; pass++) {
    vfxGrainsDiscard();
    for (var i = 0; i < g; i++) {
      final flare = vfxHash(f.seed + i * 4.1 + (t * 8).floorToDouble()) > 0.8;
      if (flare != (pass == 1)) continue;
      final a = f.seed + i * 2.399 + 1.1;
      final depth = vfxHash(f.seed + i * 5.1);
      final p = c + vfxPolar(a, front * (0.78 + 0.22 * depth * depth));
      vfxGrain(p.dx, p.dy);
    }
    vfxGrainsFlush(
      canvas,
      pass == 1 ? max(3.2, big * 0.012) : max(2.2, big * 0.007),
      pass == 1 ? vfxFlare(m) : m.glint,
      (pass == 1 ? 0.95 : 0.6) * fade,
    );
  }
}
