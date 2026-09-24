import 'dart:math';
import 'dart:ui' as ui;

import 'horn_vfx.dart';
import 'mask_trap_vfx.dart';
import 'vfx_shapes.dart';

/// The Mystic worlds' art — the maw, the maelstrom, the tornado, the dawn
/// star's corona, the revenants, the storm's gathering, the quake and the
/// vent, the Miasma's patches, the Vein's shards, the Fissures' meteors and
/// scorches, and the ground cover that grows under a world.
///
/// These are the loudest things in the game, one Mystic at a time, and several
/// were still drawn in the vocabulary the other families have left behind:
/// stroked hoops round the maw, hairline spirals, a dashed "loading ring" and
/// tick marks round the dawn star, a spoked wheel for the storm, a bead ring
/// for the vent. Everything here is filled, tapered and lit through gradients
/// (vfx_shapes.dart); no piece is outlined.
///
/// Signatures mirror the `drawMystic*` entry points in
/// cosmic_projectile_vfx.dart, which hand straight off to these.

final ui.Paint _paint = ui.Paint();

void _disc(ui.Canvas canvas, ui.Offset c, double r, ui.Color color, double a) {
  if (a <= 0.004 || r <= 0.2) return;
  _paint
    ..shader = null
    ..color = color.withValues(alpha: a.clamp(0.0, 1.0));
  canvas.drawCircle(c, r, _paint);
}

/// A tall soft light, for columns and beams from above.
void _column(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  double stretch,
  ui.Color color,
  double a,
) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(1 / stretch, stretch);
  vfxSpill(canvas, ui.Offset.zero, r, color, a);
  canvas.restore();
}

// ─────────────────────────────────────────────────────────────────────────
// Dark — The Maw
// ─────────────────────────────────────────────────────────────────────────

void paintMysticMaw({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double horizonRadius,
  required double open,
  required double spin,
  required double alpha,
  required double time,
}) {
  final a = alpha.clamp(0.0, 1.0);
  if (a <= 0.01 || open <= 0.01) return;
  final m = vfxMaterial('Dark');
  final h = horizonRadius * open;
  final pulse = 1.0 + 0.075 * sin(time * 0.62) + 0.035 * sin(time * 1.63 + 1.1);
  final bend = 0.5 + 0.5 * sin(time * 0.62);

  // Space darkened round it: the pull, felt rather than outlined.
  vfxSpill(canvas, centre, h * 5.5, m.ink, 0.5 * a);
  vfxSpill(canvas, centre, h * 3.2, m.light, 0.1 * a);
  // Accretion: material falling in along spiral arms, tapered, shearing.
  for (var i = 0; i < 4; i++) {
    final start = spin * (1 + i * 0.25) + i * pi / 2;
    vfxFillPath(
      canvas,
      vfxSpiralArm(centre, h * 3.4, start, 2.3, h * 0.42, reach: 0.68),
      m.mid,
      0.34 * a,
    );
    vfxFillPath(
      canvas,
      vfxSpiralArm(centre, h * 3.2, start + 0.1, 2.1, h * 0.14, reach: 0.66),
      m.glint,
      (0.2 + 0.2 * bend) * a,
    );
  }
  // The absence itself, with light bent round its lip.
  vfxSoftRing(
    canvas,
    centre,
    h * 1.04 * pulse,
    h * 0.22,
    m.light,
    (0.4 + 0.25 * bend) * a,
  );
  _disc(canvas, centre, h * pulse, const ui.Color(0xFF000000), 0.97 * a);
  for (var i = 0; i < 2; i++) {
    vfxFillPath(
      canvas,
      vfxCrescent(
        centre,
        h * 1.12 * pulse,
        h * (0.1 + 0.1 * bend),
        -spin * 0.8 + i * pi,
        1.2 + 0.6 * bend,
      ),
      m.glint,
      (0.35 + 0.4 * bend) * a,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Water — The Maelstrom, and Air — the tornado
// ─────────────────────────────────────────────────────────────────────────

void paintMysticMaelstrom({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required double phase,
  required double alpha,
  required double time,
}) {
  final a = alpha.clamp(0.0, 1.0);
  if (a <= 0.01) return;
  final m = vfxMaterial('Water');
  // Still faint on purpose — the fight happens on this and the crowd being
  // carried round is the loud signal — but made of water, not of lines.
  vfxSpill(canvas, centre, radius, m.light, 0.08 * a);
  vfxSpill(canvas, centre, radius * 0.45, m.ink, 0.35 * a);
  for (var i = 0; i < 3; i++) {
    final start = phase + i * (pi * 2 / 3);
    vfxFillPath(
      canvas,
      vfxSpiralArm(
        centre,
        radius * 0.98,
        start,
        3.6,
        radius * 0.07,
        reach: 0.86,
      ),
      m.mid,
      0.16 * a,
    );
    vfxFillPath(
      canvas,
      vfxSpiralArm(
        centre,
        radius * 0.94,
        start + 0.05,
        3.4,
        radius * 0.022,
        reach: 0.84,
      ),
      m.glint,
      0.14 * a,
    );
  }
  // Foam riding the current near the eye.
  for (var i = 0; i < 12; i++) {
    final f = 0.12 + (i % 6) / 6.0 * 0.36;
    final ang = phase * (0.6 + f) + i * 1.47;
    final p = centre + vfxPolar(ang, radius * f);
    vfxFillPath(
      canvas,
      vfxDrop(p, 1.6 + 0.8 * sin(time * 3 + i), ang + pi / 2),
      m.glint,
      0.3 * a,
    );
  }
  // The eye: dark, with light catching one side of its lip.
  vfxSpill(canvas, centre, radius * 0.11, const ui.Color(0xFF02080E), 0.8 * a);
  vfxFillPath(
    canvas,
    vfxCrescent(centre, radius * 0.085, radius * 0.02, -phase, 1.6),
    m.glint,
    0.35 * a,
  );
}

void paintMysticTornado({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double radius,
  required double phase,
  required double travelAngle,
  required double alpha,
  required double time,
}) {
  final a = alpha.clamp(0.0, 1.0);
  if (a <= 0.01) return;
  final m = vfxMaterial('Air');
  final lean = vfxPolar(travelAngle, 1);
  // The ground it scours: a pressed hollow and dust thrown off the foot.
  vfxSpill(canvas, at, radius * 0.9, const ui.Color(0xFF05080B), 0.45 * a);
  vfxSpill(canvas, at, radius, m.light, 0.08 * a);
  // The funnel, seen from above: wind bands stacked up the column, each one
  // wider and further along the lean than the last — that offset is height.
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.scale(1, 0.6);
  for (var k = 0; k < 5; k++) {
    final f = k / 4;
    final c = lean * radius * 0.22 * f;
    final r = radius * (0.26 + 0.6 * f);
    final turn = phase * (2.4 - f) + k * 1.3;
    for (var j = 0; j < 2; j++) {
      vfxFillPath(
        canvas,
        vfxCrescent(c, r, radius * (0.16 - 0.05 * f), turn + j * pi, 2.4),
        m.mid,
        (0.16 - 0.03 * f) * a,
      );
      vfxFillPath(
        canvas,
        vfxCrescent(c, r * 0.97, radius * 0.05, turn + j * pi + 0.1, 1.7),
        m.glint,
        (f > 0.6 ? 0.18 : 0.0) * a,
      );
    }
  }
  canvas.restore();
  // Debris caught in it, swept round and up.
  for (var i = 0; i < 14; i++) {
    final f = (i % 6) / 6.0;
    final ang = phase * 3.4 + i * 1.29;
    final r = radius * (0.24 + 0.66 * f);
    final p =
        at +
        lean * radius * 0.22 * f +
        ui.Offset(cos(ang) * r, sin(ang) * r * 0.6);
    vfxFillPath(
      canvas,
      vfxLeaf(p, 5.0 - 2.0 * f, ang * 2 + time * 4),
      m.glint,
      (0.7 - 0.3 * f) * a,
    );
  }
  vfxSpill(canvas, at, radius * 0.16, const ui.Color(0xFF0A1018), 0.7 * a);
}

// ─────────────────────────────────────────────────────────────────────────
// Light — the dawn star's corona and release
// ─────────────────────────────────────────────────────────────────────────

void paintMysticDawnStar({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double charge,
  required double flare,
  required double alpha,
  required double time,
}) {
  final a = alpha.clamp(0.0, 1.0);
  if (a <= 0.01) return;
  final t = charge.clamp(0.0, 1.0);
  final release = flare.clamp(0.0, 1.0);
  final r = (55 + 73 * t) * (0.985 + 0.015 * sin(time * 0.9));
  const gold = ui.Color(0xFFD6B975);
  const ivory = ui.Color(0xFFFFF0CC);
  // Halo.
  final halo = r * (1.8 + release * 0.8);
  _paint
    ..color = const ui.Color(0xFFFFFFFF)
    ..shader = ui.Gradient.radial(
      at,
      halo,
      [
        gold.withValues(alpha: 0),
        gold.withValues(alpha: (0.18 + t * 0.18 + release * 0.22) * a),
        gold.withValues(alpha: 0),
      ],
      const [0.25, 0.56, 1],
    );
  canvas.drawCircle(at, halo, _paint);
  // The sealed solar body.
  _paint.shader = ui.Gradient.radial(
    at - ui.Offset(r * 0.25, r * 0.2),
    r * 1.4,
    [
      const ui.Color(0xFF292431).withValues(alpha: a),
      const ui.Color(0xFF0A0812).withValues(alpha: a),
      const ui.Color(0xFF6E5638).withValues(alpha: a),
    ],
    const [0, 0.68, 1],
  );
  canvas.drawCircle(at, r, _paint);
  _paint.shader = null;
  // The limb lighting up as the charge fills — light gathered at the edge,
  // not a ring drawn round it.
  vfxSoftRing(canvas, at, r, r * (0.06 + 0.07 * t), gold, (0.3 + 0.5 * t) * a);
  // Corona: tongues of light licking off the limb, longer as it charges.
  for (var i = 0; i < 11; i++) {
    final ang = i * pi * 2 / 11 + time * 0.03 + sin(i * 2.3) * 0.2;
    final lick = 0.6 + 0.4 * sin(time * 1.3 + i * 1.7);
    final len = r * (0.05 + 0.16 * t) * lick;
    final base = at + vfxPolar(ang, r * 1.0);
    vfxFillPath(
      canvas,
      vfxShard(base, len * 1.4, len * 0.16, ang),
      gold,
      (0.3 + 0.35 * t) * a,
    );
    vfxFillPath(
      canvas,
      vfxShard(base, len, len * 0.06, ang),
      ivory,
      (0.25 + 0.45 * t) * a,
    );
  }
  if (release > 0.01) {
    // Dawn breaking: a bloom of light rolling outward, and the body opening.
    vfxSoftRing(
      canvas,
      at,
      r * (1.1 + (1 - release) * 1.6),
      r * (0.25 + 0.4 * release),
      ivory,
      release * 0.55 * a,
    );
    _paint
      ..color = const ui.Color(0xFFFFFFFF)
      ..shader = ui.Gradient.radial(
        at,
        r,
        [
          ivory.withValues(alpha: release * 0.5 * a),
          gold.withValues(alpha: release * 0.12 * a),
          gold.withValues(alpha: 0),
        ],
        const [0, 0.6, 1],
      );
    canvas.drawCircle(at, r, _paint);
    _paint.shader = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Spirit — revenants
// ─────────────────────────────────────────────────────────────────────────

/// A body that died and got back up on your side: its own shape gone pale
/// and hollow, a veil trailing it, cold light where the colour was.
void paintMysticRevenant({
  required ui.Canvas canvas,
  required ui.Offset position,
  required ui.Offset velocity,
  required double radius,
  required double rise,
  required double life,
  required double alpha,
  required double time,
  required double seed,
}) {
  final a = alpha * (life < 1.5 ? (life / 1.5).clamp(0.0, 1.0) : 1.0);
  if (a <= 0.01) return;
  final m = vfxMaterial('Spirit');
  final rr = radius * (0.55 + 0.45 * rise);
  final back = velocity.distance > 1
      ? -velocity / velocity.distance
      : const ui.Offset(0, 1);
  final n = ui.Offset(-back.dy, back.dx);
  vfxSpill(canvas, position, rr * 2.6, m.light, 0.22 * a);
  // The veil it drags.
  final spine = [
    for (var k = 0; k <= 8; k++)
      position +
          back * (rr * 3.2 * k / 8) +
          n * (sin(time * 4 + k * 0.8 + seed) * rr * 0.35 * k / 8),
  ];
  vfxFillPath(canvas, vfxRibbon(spine, rr * 1.7, rr * 0.15), m.mid, 0.4 * a);
  // Its own body, pale.
  vfxFillPath(
    canvas,
    vfxBlob(position, rr, seed, n: 9, wobble: 0.12),
    const ui.Color(0xFFCAD6EE),
    0.7 * a,
  );
  vfxFillPath(
    canvas,
    vfxBlob(
      position + back * rr * 0.2,
      rr * 0.62,
      seed + 3,
      n: 8,
      wobble: 0.14,
    ),
    m.mid,
    0.45 * a,
  );
  vfxSpill(canvas, position - back * rr * 0.25, rr * 0.7, m.glint, 0.8 * a);
  if (rise < 1) {
    // Getting up: a column of cold light it stands up out of.
    _column(
      canvas,
      position - ui.Offset(0, rr * 1.2),
      rr * 1.8,
      2.2,
      m.glint,
      (1 - rise) * 0.5 * a,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Lightning — the gathering and the strike
// ─────────────────────────────────────────────────────────────────────────

void paintMysticStormCharge({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double progress,
  required double seed,
  required double time,
}) {
  final t = progress.clamp(0.0, 1.0);
  final a = (t * 3.2).clamp(0.0, 1.0);
  final m = vfxMaterial('Lightning');
  final reach = 96.0 * (1.0 - 0.62 * t);
  // The ground under the strike point lighting up.
  vfxSpill(canvas, at, reach, m.light, (0.22 + 0.45 * t) * a);
  // Light coming down onto it from above.
  _column(canvas, at - ui.Offset(0, 70), 60, 2.8, m.glint, 0.25 * t * a);
  // Charge drawn in from all round, faster as it builds.
  for (var i = 0; i < 9; i++) {
    final ph = (time * (0.8 + 1.8 * t) + i / 9 + seed) % 1.0;
    final ang = seed + i * 2.399;
    final d = reach * (1 - ph) + 6;
    vfxFillPath(
      canvas,
      vfxDrop(at + vfxPolar(ang, d), 2.4 + 1.6 * t, ang + pi),
      m.glint,
      0.9 * sin(ph * pi) * a,
    );
  }
  if (t > 0.82) {
    final snap = (t - 0.82) / 0.18;
    vfxSpill(
      canvas,
      at,
      6 + 14 * snap,
      const ui.Color(0xFFFFFFFF),
      0.85 * snap,
    );
  }
}

/// Where the bolt lands: light and a scorch rather than flat discs. The bolt
/// itself stays a line — lightning is a line.
void paintMysticBoltImpact({
  required ui.Canvas canvas,
  required ui.Offset strike,
  required double t,
  required double a,
  required bool onBoss,
}) {
  final m = vfxMaterial('Lightning');
  final flash = (onBoss ? 58.0 : 38.0) * (1.0 + (1.0 - t) * 1.6);
  vfxFillPath(
    canvas,
    vfxBlob(strike, flash * 0.32, strike.dx * 0.1, n: 9, wobble: 0.3),
    m.ink,
    0.5 * a,
  );
  vfxSpill(canvas, strike, flash, m.light, 0.4 * a);
  vfxSpill(canvas, strike, flash * 0.36, const ui.Color(0xFFFFFFFF), 0.75 * a);
}

// ─────────────────────────────────────────────────────────────────────────
// Earth — the quake; Steam — the vent
// ─────────────────────────────────────────────────────────────────────────

void paintMysticQuake({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required double progress,
  required ui.Color earth,
}) {
  final t = progress.clamp(0.0, 1.0);
  if (t >= 1) return;
  final eased = 1.0 - (1.0 - t) * (1.0 - t);
  final a = (1.0 - t) * (1.0 - t);
  final r = radius * eased;
  final m = vfxMaterial('Earth');
  // Dust thrown up along the front.
  vfxSoftRing(canvas, centre, r, 44 * a + 14, m.light, 0.42 * a);
  // Rubble heaved up on the front — spaced by distance, so a wide quake and a
  // tight one are equally dense.
  final n = (2 * pi * r / 34).floor().clamp(10, 72);
  for (var i = 0; i < n; i++) {
    final ang = i * pi * 2 / n + vfxHash(i.toDouble()) * 0.1;
    final d = r * (0.97 + 0.06 * vfxHash(i * 3.1));
    final c = centre + vfxPolar(ang, d);
    final s = (4 + 4 * vfxHash(i * 5.7)) * (0.5 + 0.5 * a);
    vfxFillPath(
      canvas,
      vfxBlob(c, s, i.toDouble(), n: 6, wobble: 0.3),
      m.ink,
      0.9 * a,
    );
    vfxFillPath(
      canvas,
      vfxBlob(
        c + ui.Offset(-s * 0.2, -s * 0.3),
        s * 0.5,
        i * 2.0,
        n: 5,
        wobble: 0.2,
      ),
      m.glint,
      0.4 * a,
    );
  }
  // The ground split behind it.
  for (var i = 0; i < 10; i++) {
    final ang = i * pi * 2 / 10 + 0.21;
    final spine = [
      for (var k = 0; k <= 5; k++)
        centre +
            vfxPolar(ang + sin(i * 2.7 + k) * 0.03, r * (0.68 + 0.3 * k / 5)),
    ];
    vfxFillPath(
      canvas,
      vfxRibbon(spine, 7 * a + 1, 0.5),
      const ui.Color(0xFF140E09),
      0.6 * a,
    );
  }
}

void paintMysticVent({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required double progress,
  required double time,
}) {
  final t = progress.clamp(0.0, 1.0);
  if (t >= 1) return;
  final eased = 1.0 - (1.0 - t) * (1.0 - t);
  final a = (1.0 - t) * (1.0 - t);
  final r = radius * eased;
  final m = vfxMaterial('Steam');
  // The exhale: a soft pale front, billowing — pressure, not fracture.
  vfxSoftRing(canvas, centre, r, 38 * a + 12, m.glint, 0.22 * a);
  final n = (2 * pi * r / 40).floor().clamp(12, 48);
  for (var i = 0; i < n; i++) {
    final ang = i * pi * 2 / n + sin(time * 0.8 + i) * 0.06;
    final wob = 1.0 + sin(i * 2.3 + time * 3.0) * 0.05;
    vfxSpill(
      canvas,
      centre + vfxPolar(ang, r * wob),
      (22.0 + 26.0 * t) * a + 6.0,
      m.glint,
      0.26 * a,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Poison — the Miasma's patches; Crystal — the Vein's shards
// ─────────────────────────────────────────────────────────────────────────

void paintMysticPoisonPatch({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required double alpha,
  required double seed,
  required double time,
}) {
  final a = alpha.clamp(0.0, 1.0);
  if (a <= 0.01) return;
  final m = vfxMaterial('Poison');
  vfxSpill(canvas, centre, radius * 1.15, m.light, 0.16 * a);
  vfxFillPath(
    canvas,
    vfxBlob(centre, radius * 0.7, seed, n: 11, wobble: 0.2),
    m.ink,
    0.5 * a,
  );
  for (var i = 0; i < 4; i++) {
    final ang = seed + i * 1.57 + time * 0.06;
    final c = centre + vfxPolar(ang, radius * 0.3);
    final cr = radius * (0.34 + 0.08 * sin(time * 0.7 + i + seed));
    vfxFillPath(
      canvas,
      vfxBlob(c, cr, seed + i + time * 0.15, n: 9, wobble: 0.14),
      m.mid,
      0.34 * a,
    );
    vfxFillPath(
      canvas,
      vfxBlob(
        c + ui.Offset(0, -cr * 0.18),
        cr * 0.66,
        seed + i * 3 + time * 0.15,
        n: 8,
        wobble: 0.16,
      ),
      m.glint,
      0.12 * a,
    );
  }
  for (var i = 0; i < 4; i++) {
    final ph = (time * 0.6 + seed + i * 0.37) % 1.0;
    final p =
        centre +
        vfxPolar(seed * 2.1 + i * 1.57, radius * 0.42) +
        ui.Offset(0, -ph * radius * 0.35);
    _disc(canvas, p, 1.2 + 1.8 * sin(ph * pi), m.glint, 0.6 * sin(ph * pi) * a);
  }
}

void paintMysticCrystalShard({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double alpha,
  required double seed,
  required double time,
}) {
  final a = alpha.clamp(0.0, 1.0);
  if (a <= 0.01) return;
  final m = vfxMaterial('Crystal');
  final spin = time * 1.1 + seed;
  final facet = 0.6 + 0.4 * sin(time * 2.6 + seed);
  final c = at + ui.Offset(0, sin(time * 2.2 + seed) * 2.0);
  vfxSpill(canvas, at, 18, m.light, 0.28 * facet * a);
  // A cut gem turning: dark on one side, catching the light on the other.
  final d = vfxPolar(spin, 1), s = ui.Offset(-d.dy, d.dx);
  const h = 10.0, w = 6.0;
  final tip = c + d * h, tail = c - d * h;
  vfxFillPath(
    canvas,
    ui.Path()..addPolygon([tip, c - s * w, tail], true),
    m.ink,
    0.95 * a,
  );
  vfxFillPath(
    canvas,
    ui.Path()..addPolygon([tip, c + s * w, tail], true),
    ui.Color.lerp(m.mid, m.glint, 0.6 * facet)!,
    0.95 * a,
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Lava — meteors and scorches
// ─────────────────────────────────────────────────────────────────────────

void paintMysticLavaMeteor({
  required ui.Canvas canvas,
  required ui.Offset impact,
  required double progress,
  required double seed,
}) {
  final t = progress.clamp(0.0, 1.0);
  final m = vfxMaterial('Lava');
  const height = 560.0;
  final at = impact - ui.Offset(0, height * (1.0 - t * t));
  // The warning: a shadow tightening and a glow growing where it will land.
  vfxSpill(
    canvas,
    impact,
    46.0 - 26.0 * t,
    const ui.Color(0xFF000000),
    0.3 + 0.35 * t,
  );
  vfxSpill(canvas, impact, 30.0 - 12.0 * t, m.light, 0.15 + 0.35 * t);
  // What burns off it, streaming up behind.
  canvas.save();
  canvas.translate(at.dx, at.dy - 26);
  canvas.scale(0.45, 1.6);
  vfxFillPath(canvas, vfxDrop(ui.Offset.zero, 12, pi / 2), m.mid, 0.55);
  vfxFillPath(canvas, vfxDrop(const ui.Offset(0, 4), 6, pi / 2), m.glint, 0.7);
  canvas.restore();
  // The rock: crust with heat showing through it.
  vfxFillPath(canvas, vfxBlob(at, 8, seed, n: 7, wobble: 0.22), m.ink, 1);
  vfxSpill(canvas, at + ui.Offset(cos(seed) * 2, 2), 5, m.glint, 0.9);
}

void paintMysticScorch({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double age,
  required double maxAge,
  required double seed,
}) {
  final t = (age / maxAge).clamp(0.0, 1.0);
  final a = t > 0.72 ? ((1.0 - t) / 0.28).clamp(0.0, 1.0) : 1.0;
  final heat = (1.0 - t) * (1.0 - t);
  final m = vfxMaterial('Lava');
  final r = 34.0 + 14.0 * t;
  vfxFillPath(
    canvas,
    vfxBlob(at, r, seed, n: 11, wobble: 0.22),
    m.ink,
    0.6 * a,
  );
  vfxSpill(canvas, at, r * 1.1, m.light, 0.3 * heat * a);
  // Seams cooling in the crust.
  for (var i = 0; i < 5; i++) {
    final ang = seed + i * 1.26;
    final p = at + vfxPolar(ang, r * 0.4 * vfxHash(seed + i));
    vfxFillPath(
      canvas,
      vfxShard(p, r * 0.3, r * 0.05, ang + 1.2),
      m.glint,
      (0.15 + 0.7 * heat) * a,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Ground cover
// ─────────────────────────────────────────────────────────────────────────

/// Fire, Poison, Ice and Spirit's ground cover. Returns false for the
/// elements whose cover is drawn by the original painter (Plant, Mud, Dust).
bool paintMysticFlora({
  required ui.Canvas canvas,
  required ui.Offset at,
  required String element,
  required double size,
  required double bloom,
  required double seed,
  required double time,
}) {
  if (bloom <= 0.02)
    return element == 'Fire' ||
        element == 'Poison' ||
        element == 'Ice' ||
        element == 'Spirit';
  final grow = bloom * size;
  final m = vfxMaterial(element);
  switch (element) {
    case 'Fire':
      // A cinder patch still burning.
      drawVfxBurningGround(canvas, at, m, 20 * grow, seed, time);
    case 'Poison':
      // A toxic bloom: a stain with blisters swelling on it.
      vfxSpill(canvas, at, 16 * grow, m.light, 0.2);
      vfxFillPath(
        canvas,
        vfxBlob(at, 10 * grow, seed, n: 9, wobble: 0.22, squash: 0.6),
        m.ink,
        0.8,
      );
      for (var i = 0; i < 3; i++) {
        final ph = (time * 0.5 + i * 0.33 + seed) % 1.0;
        final c = at + ui.Offset((i - 1) * 5.0 * grow, -2.0 * grow);
        final br = grow * (2.0 + 2.4 * ph);
        _disc(canvas, c, br, m.mid, 0.9 * (1 - ph * 0.6));
        _disc(
          canvas,
          c + ui.Offset(-br * 0.3, -br * 0.35),
          br * 0.35,
          m.glint,
          0.6 * (1 - ph),
        );
      }
    case 'Ice':
      // Rime: a few shards standing up out of the frost.
      vfxSpill(canvas, at, 16 * grow, m.light, 0.2);
      for (var i = 0; i < 4; i++) {
        final x = (i - 1.5) * 4.0 * grow + (vfxHash(seed + i) - 0.5) * 3 * grow;
        final h =
            grow *
            (7 + 7 * vfxHash(seed + i * 2.7)) *
            (i == 1 || i == 2 ? 1.3 : 0.9);
        final base = at + ui.Offset(x, 2 * grow);
        final tip =
            base + ui.Offset((vfxHash(seed + i * 4.1) - 0.5) * 4 * grow, -h);
        final w = 2.2 * grow;
        vfxFillPath(
          canvas,
          ui.Path()..addPolygon([
            base + ui.Offset(-w, 0),
            tip,
            base + ui.Offset(w, 0),
          ], true),
          m.ink,
          0.95,
        );
        vfxFillPath(
          canvas,
          ui.Path()..addPolygon([base, tip, base + ui.Offset(w, 0)], true),
          m.mid,
          0.85,
        );
      }
    case 'Spirit':
      drawMaskSpiritRemnant(
        canvas: canvas,
        position: at,
        radius: 26 * grow,
        time: time + seed,
        alpha: bloom.clamp(0.0, 1.0),
      );
    default:
      return false;
  }
  return true;
}
