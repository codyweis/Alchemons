// lib/screens/heart_puzzle/altar_stage_art.dart
//
// THE ALTARS' stage, in the app's own language (the author, 2026-10-08:
// "redesign this entire stage, it feels outdated"): lit grains on black,
// ink and pale brass — no carved stone. Everything here is plain drawing,
// scrubbed by the screen's clock; how bright a thing is comes in eased, so
// nothing on the stage ever pops.
//
//   · A SEAT is a ring of sand grains on the ground, turning slowly; it
//     brightens when something stands on it or a creature is carried over.
//   · An ALTAR is its two seats over one pool of floor light, warming with
//     the colors of the pair on it.
//   · Its COLUMN is a faint shaft up to the goal, a few motes rising in it.
//   · The SPLIT stage is a sand ring cut in two, its halves breathing apart.
//   · The GOAL hangs at the top as its word in grains: unlit ash until it
//     is made, then lit in its element's shades from where it arrives.
//
// No blur, no strokes: points in batches and radial gradients.

import 'dart:math' as math;
import 'package:alchemons/games/cosmic/vfx_shapes.dart';
import 'package:alchemons/games/planet_dungeon/blood_heart_fx.dart';
import 'package:alchemons/games/planet_dungeon/blood_rite_fx.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:flutter/painting.dart';

/// Pale brass (the app's accent) and the ash of an unlit grain.
const Color kAltarBrass = Color(0xFFCDB07A);
const Color kAltarBrassDeep = Color(0xFF6B5A36);
const Color kAltarAsh = Color(0xFF8E8A82);

double _hash(int n) {
  final s = math.sin(n * 127.1 + 311.7) * 43758.5453;
  return s - s.floorToDouble();
}

double _ease(double t) {
  final c = t.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}

/// A soft ellipse of shade on the ground, so what stands there reads over
/// a bright realm.
void paintFloorShade(
  Canvas canvas,
  Offset c,
  double rx,
  double ry,
  double strength,
) => paintFloorPool(canvas, c, rx, ry, const Color(0xFF000000), strength);

/// A soft ellipse of light on the ground.
void paintFloorPool(
  Canvas canvas,
  Offset c,
  double rx,
  double ry,
  Color color,
  double strength,
) {
  if (strength <= .004) return;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(1, ry / rx);
  canvas.drawCircle(
    Offset.zero,
    rx,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: strength.clamp(0.0, 1.0)),
          color.withValues(alpha: (strength * .35).clamp(0.0, 1.0)),
          color.withValues(alpha: 0),
        ],
        stops: const [0, .5, 1],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: rx)),
  );
  canvas.restore();
}

/// A seat: a ring of sand grains lying on the ground round [c], turning.
/// [glow] 0–1 brightens it (something on it, or carried over it); [tint]
/// colors the lit grains toward an element.
void paintSeatRing(
  RiteGrainBatch batch,
  Offset c,
  double time, {
  double glow = 0,
  double fade = 1,
  Color? tint,
  int salt = 0,
  double rx = 16,
  double ry = 5.5,
  int grains = 46,
}) {
  if (fade <= .01) return;
  final lit = tint == null ? kAltarBrass : Color.lerp(kAltarBrass, tint, .55)!;
  for (var i = 0; i < grains; i++) {
    final h = _hash(i * 13 + salt * 97);
    final a =
        i / grains * math.pi * 2 + time * (.32 + .05 * (salt % 3)) + h * .2;
    final r = 1 + (h - .5) * .14;
    final x = c.dx + math.cos(a) * rx * r, y = c.dy + math.sin(a) * ry * r;
    // The near half of the ring (below its centre) catches more light.
    final near = math.sin(a) > 0 ? 1.0 : .6;
    final tw = .8 + .2 * math.sin(time * 2.1 + i * 1.7);
    final alpha = (.42 + .55 * glow) * near * tw * fade;
    // Lit sand, with a white-hot grain here and there so the ring holds
    // over bright ground.
    final col = h > .86
        ? Color.lerp(lit, const Color(0xFFFFF4DC), .5)!
        : Color.lerp(kAltarBrassDeep, lit, .55 + .45 * glow)!;
    batch.add(x, y, x, y, col, alpha: alpha, width: h > .86 ? 2.6 : 2.2);
  }
}

/// The split stage: a ring of sand cut in two, its halves breathing apart.
void paintSplitRing(
  RiteGrainBatch batch,
  Offset c,
  double time, {
  double glow = 0,
  double fade = 1,
}) {
  if (fade <= .01) return;
  const n = 40;
  final apart = 3.5 + 1.5 * math.sin(time * 1.3);
  for (final side in const [-1.0, 1.0]) {
    for (var i = 0; i < n; i++) {
      final h = _hash(i * 7 + (side > 0 ? 400 : 0));
      // Each half spans its side of the ring, a little short of the cut.
      final a =
          math.pi / 2 +
          side * (math.pi / 2) +
          (i / (n - 1) - .5) * math.pi * .86;
      final x = c.dx + side * apart + math.cos(a) * 17 * (1 + (h - .5) * .12);
      final y = c.dy + math.sin(a) * 6;
      final near = math.sin(a) > 0 ? 1.0 : .55;
      final tw = .75 + .25 * math.sin(time * 1.8 + i * 2.3);
      batch.add(
        x,
        y,
        x,
        y,
        h > .8
            ? kAltarBrass
            : Color.lerp(kAltarBrassDeep, kAltarBrass, .4 + .6 * glow)!,
        alpha: (.22 + .6 * glow) * near * tw * fade,
        width: 2,
      );
    }
  }
}

/// An altar's column: a faint shaft of light from its seats up toward the
/// goal, with a few motes rising in it. [lift] brightens it while something
/// rises.
void paintColumn(
  Canvas canvas,
  RiteGrainBatch batch,
  double x,
  double bottom,
  double top,
  double time, {
  double lift = 0,
  double fade = 1,
  int salt = 0,
}) {
  if (fade <= .01 || bottom <= top) return;
  // Soft on every side: an upright ellipse of light standing on the seats,
  // brightest at its foot, gone by the top (no edge anywhere).
  final span = bottom - top;
  canvas.save();
  canvas.clipRect(Rect.fromLTRB(x - 40, top, x + 40, bottom));
  canvas.translate(x, bottom);
  canvas.scale(1, span / 30);
  canvas.drawCircle(
    Offset.zero,
    30,
    Paint()
      ..shader = RadialGradient(
        colors: [
          kAltarBrass.withValues(alpha: (.07 + .08 * lift) * fade),
          kAltarBrass.withValues(alpha: (.025 + .04 * lift) * fade),
          kAltarBrass.withValues(alpha: 0),
        ],
        stops: const [0, .45, 1],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 30)),
  );
  canvas.restore();
  for (var i = 0; i < 9; i++) {
    final h = _hash(i * 31 + salt * 53);
    final ph = (time / (7 + 4 * h) + h) % 1.0;
    final y = bottom - ph * span;
    final x0 = x + (h - .5) * 30 + math.sin(time * .7 + i) * 3;
    final a = math.sin(math.pi * ph) * (.35 + .3 * lift) * fade;
    batch.add(x0, y + 1.5, x0, y, kAltarBrass, alpha: a, width: 2);
  }
}

/// A star as a grain sparkle: a bright grain and four arms [arm] long, and
/// on a big one four short ones between. Unwon it is ash; [lit] runs the
/// light out from its heart to its tips, each grain lifting a little as the
/// light reaches it, as the goal's word lights. Pass [canvas] for its glow.
void paintGrainStar(
  RiteGrainBatch batch,
  Offset c,
  double arm, {
  double lit = 0,
  double alpha = 1,
  Canvas? canvas,
  int salt = 0,
}) {
  if (alpha <= .01) return;
  if (canvas != null && lit > 0) {
    vfxSpill(canvas, c, arm * 2.4, kAltarBrass, .28 * _ease(lit) * alpha);
  }
  // How lit a grain [frac] of the way out is.
  double at(double frac) => ((lit * 1.5 - frac * .5)).clamp(0.0, 1.0);
  void grain(Offset p, double frac, double fall, double width, {bool hot = false}) {
    final k = at(frac);
    final q = p - Offset(0, arm * .12 * math.sin(math.pi * k));
    final col = Color.lerp(
      kAltarAsh,
      hot ? const Color(0xFFFFF1D0) : kAltarBrass,
      k,
    )!;
    final a = (.26 + .74 * k) * fall * alpha;
    batch.add(q.dx, q.dy, q.dx, q.dy, col, alpha: a, width: width);
  }

  grain(c, 0, 1, 2.6, hot: true);
  // A big star has a bead of a heart, and arms that taper from it.
  final big = arm >= 8;
  if (big) {
    for (var i = 0; i < 12; i++) {
      final a = i / 6 * math.pi + (i >= 6 ? math.pi / 6 : 0);
      final r = arm * (i < 6 ? .13 : .24);
      grain(
        c + Offset(math.cos(a), math.sin(a)) * r,
        r / arm,
        i < 6 ? 1 : .8,
        2.6,
        hot: i < 6,
      );
    }
  }
  final n = math.max(2, (arm / 3).round());
  for (var d = 0; d < 4; d++) {
    final dir = Offset(math.cos(d * math.pi / 2), math.sin(d * math.pi / 2));
    final side = Offset(-dir.dy, dir.dx);
    for (var j = 1; j <= n; j++) {
      final frac = j / n;
      final h = _hash(d * 31 + j * 7 + salt * 113);
      // A grain or so off true, so a big star is grains and not a cross.
      final p = c + dir * (arm * frac) + side * ((h - .5) * arm * .05);
      final fall = .95 - .4 * frac;
      grain(p, frac, fall, frac < .5 ? 2.6 : 2);
      // Thick near the heart: a grain either side.
      if (big && frac < .5) {
        final w = arm * .07 * (1 - frac * 1.6);
        grain(p + side * w, frac, fall * .8, 2);
        grain(p - side * w, frac, fall * .8, 2);
      }
    }
    if (big) {
      final diag = Offset(
        math.cos(d * math.pi / 2 + math.pi / 4),
        math.sin(d * math.pi / 2 + math.pi / 4),
      );
      for (var j = 1; j <= 2; j++) {
        final frac = .2 + j * .14;
        grain(c + diag * (arm * frac), frac, .7 - .4 * frac, 2);
      }
    }
  }
}

/// The goal, hung at the top of the stage as its word in grains: the
/// element, or from species on the species' own name, as one word
/// ("Poisonmane" — the author, 2026-10-08: "it's one species").
///
/// It gathers in from below when the level opens; it stays unlit ash, with a
/// faint breath of its element's color, until the goal is made — then the
/// light runs through it from where the made thing arrives ([lightFrom]).
class AltarGoalWord {
  AltarGoalWord(this.el, this.word, this.family)
    : ramp = essenceRamp(EssenceElement.of(el)),
      pool = essencePool(EssenceElement.of(el));

  final String el;
  final HeartWord word;
  final HeartWord? family;
  final List<Color> ramp;
  final Color pool;

  /// When it began to gather (screen clock), and when the light began, from
  /// which x (relative to its centre). Null: unlit.
  double bornAt = -1;
  double? litAt;
  double litX = 0;

  /// How tall its element word stands, for laying out under it.
  static const double size = 30, familySize = 14;

  /// How much it is drawn at, so a long name fits the stage (see the
  /// painter, which sets it from the room it has).
  double fit = 1;

  double get height =>
      (size * 1.25 + (family == null ? 0 : familySize * 1.4)) * fit;
  double get width => math.max(word.width, family?.width ?? 0) * fit;
  double get naturalWidth => math.max(word.width, family?.width ?? 0);

  void lightFrom(double x, double time) {
    litAt = time;
    litX = x;
  }

  void paint(
    Canvas canvas,
    RiteGrainBatch batch,
    Offset centre,
    double time, {
    double lit = 1,
    double held = 0,
  }) {
    if (bornAt < 0) bornAt = time;
    final age = time - bornAt;
    final la = litAt;
    final litSince = la == null ? -1.0 : time - la;
    final litAll = la == null ? 0.0 : _ease(litSince / 1.1) * lit;
    // The light it gives: a breath of its color while it waits, full once
    // it is made.
    vfxSpill(
      canvas,
      centre,
      width * .62 + 26,
      pool,
      (.05 * _ease(age / 1.2) + .08 * held + .2 * litAll).clamp(0.0, 1.0),
    );

    void grains(HeartWord w, Offset at, int salt) {
      final n = w.letters;
      for (var i = 0; i < w.length; i++) {
        final h = _hash(i * 7 + 3 + salt);
        final home = at + Offset(w.x[i], w.y[i]) * fit;
        // In: from below, letter by letter, along a slight bow.
        final leave = .45 * w.letter[i] / n + .2 * h;
        final u = ((age - leave) / .9).clamp(0.0, 1.0);
        if (u <= 0) continue;
        final e = 1 - (1 - u) * (1 - u) * (1 - u);
        final start =
            home + Offset((_hash(i + 5 + salt) - .5) * 30, 46 + 30 * h);
        var p = Offset.lerp(start, home, e)!;
        p += Offset(
          math.sin(time * .9 + i * .7) * .5 * e,
          math.cos(time * 1.1 + i) * .5 * e,
        );
        // Lit: from where it arrived, outward, each grain lifting a little
        // as the light reaches it.
        var k = 0.0;
        if (la != null) {
          final reach =
              (litSince - (w.x[i] * fit - litX).abs() / 260 - .08 * h) / .4;
          k = reach.clamp(0.0, 1.0) * lit;
          p += Offset(0, -5 * math.sin(math.pi * k) * (1 - k * .4));
        }
        final shimmer = .82 + .18 * math.sin(time * 1.6 + i * 2.1);
        // Made but not yet done (an orb still hangs): warmed toward its
        // color, not lit.
        final ash = Color.lerp(kAltarAsh, ramp[2], .12 + .38 * held)!;
        final shade = h > .88 ? ramp[3] : ramp[2];
        final col = k <= 0 ? ash : Color.lerp(ash, shade, k)!;
        final a =
            (.5 + .15 * held + .5 * k).clamp(0.0, 1.0) *
            _ease(u * 1.4) *
            shimmer;
        final q = p + const Offset(0, .8);
        batch.add(
          q.dx,
          q.dy,
          p.dx,
          p.dy,
          col,
          alpha: a,
          width: k > .5 && h > .7 ? 2.6 : 2.1,
        );
      }
    }

    final top = centre - Offset(0, height / 2 - size * .62 * fit);
    grains(word, top, 0);
    final f = family;
    if (f != null) {
      grains(f, top + Offset(0, (size * 1.05 + familySize * .7) * fit), 900);
    }
    batch.paint(canvas);
  }
}

/// A creature leaving the stage without a moment to carry it (undo, start
/// again): it thins and rises a little as it goes.
class AltarGhost {
  AltarGhost(this.draw, this.at, this.t0);
  final void Function(Canvas canvas, Offset centre, double alpha) draw;
  final Offset at;
  final double t0;
  static const double life = .5;

  bool paint(Canvas canvas, double time) {
    final k = ((time - t0) / life).clamp(0.0, 1.0);
    if (k >= 1) return false;
    draw(canvas, at - Offset(0, 10 * _ease(k)), 1 - _ease(k));
    return true;
  }
}
