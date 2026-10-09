// lib/games/cosmic/poi_art.dart
//
// The lesser points of interest of open space, in the stations' material
// (obsidian_kit.dart), each drawn to say what it does:
//
//   nebula         a churning cloud of one element's matter — fly in and
//                  take some; spent, it thins
//   derelict       a wreck broken in two, its halves drifting apart, a last
//                  spark in it until it has been picked over
//   meteor zone    a dusty reach meteors fall through; while you are in its
//                  shower they fall thick, carrying what they drop
//   warp anomaly   a small, unsteady knot of space that throws you elsewhere
//   survival gate  standing stones round a turning violet deep
//   boss lair      a sealed dark heart in a crown of shards, with a faint
//                  ring of grains where whatever sleeps there will wake
//   lore note      a small lit shard with a few motes about it
//
// Stone is painted once and laid down turned; what moves is grains.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:flutter/painting.dart';

final Map<Color, StoneLight> _lights = {};
StoneLight _light(Color c) => _lights[c] ??= StoneLight(c, warm: 0.02);

// ── nebula ──────────────────────────────────────────────────────────────────

/// Grains of a nebula, in unit radius: (radius, angle, rate, tilt, size).
final List<(double, double, double, double, int)> _nebulaGrains = () {
  final r = Random(57);
  return [
    for (var i = 0; i < 520; i++)
      () {
        final rad = pow(r.nextDouble(), 0.65).toDouble();
        return (
          rad,
          r.nextDouble() * 2 * pi,
          (0.06 + 0.1 * r.nextDouble()) / (0.35 + rad),
          r.nextDouble() * 2 * pi,
          r.nextDouble() < 0.12 ? 2 : (r.nextDouble() < 0.5 ? 1 : 0),
        );
      }(),
  ];
}();

final PointBatch _nebSoft = PointBatch(520);
final PointBatch _nebMid = PointBatch(520);
final PointBatch _nebHot = PointBatch(120);

/// A nebula of [element]'s color at [at], [radius] across. Once [spent]
/// it is thin. [ship] is where the ship is, so the cloud parts round it.
void paintNebula(
  Canvas c, {
  required Offset at,
  required double radius,
  required Color color,
  required double t,
  bool spent = false,
  Offset? ship,
}) {
  final m = _light(color);
  // The cloud reaches well past where it can be taken from.
  radius *= 1.7;
  paintDisc(c, m.pool, at, radius * 1.4, spent ? 0.7 : 1.8);
  _nebSoft.clear();
  _nebMid.clear();
  _nebHot.clear();
  final keep = spent ? 180 : _nebulaGrains.length;
  for (var i = 0; i < keep; i++) {
    final (rad, a0, rate, tilt, size) = _nebulaGrains[i];
    final a = a0 + t * rate;
    // A churning, lumpy cloud: each grain on its own tipped orbit, the
    // whole breathing slowly.
    final rr = radius * rad * (0.92 + 0.08 * sin(t * 0.4 + tilt * 3));
    var p =
        at +
        Offset(cos(a) * rr, sin(a) * rr * (0.55 + 0.35 * sin(tilt))) +
        Offset(sin(t * 0.3 + tilt) * 6, 0);
    if (ship != null) {
      final d = p - ship;
      final dist = d.distance;
      if (dist < 60 && dist > 0.1) p += d / dist * (60 - dist) * 0.6;
    }
    (size == 2
            ? _nebHot
            : size == 1
            ? _nebMid
            : _nebSoft)
        .add(p.dx, p.dy);
  }
  final fade = spent ? 0.55 : 1.0;
  _nebSoft.draw(c, 5, m.essence.withValues(alpha: 0.13 * fade));
  _nebMid.draw(c, 2.2, m.grainDim.withValues(alpha: 0.75 * fade));
  _nebHot.draw(c, 1.8, m.grainHot.withValues(alpha: fade));
}

// ── derelict ────────────────────────────────────────────────────────────────

class _Wreck {
  _Wreck() : m = StoneLight(const Color(0xFFB9CCDE));
  final StoneLight m;

  /// The fore half, nose up: a pointed prow, the canopy cracked, a jagged
  /// edge where it broke.
  late final BakedArt fore = BakedArt(const Rect.fromLTRB(-20, -44, 20, 6), (
    c,
  ) {
    CutStone.gem(m, const [
      Offset(0, -42),
      Offset(5, -30),
      Offset(9, -16),
      Offset(15, -5),
      Offset(16, -1),
      Offset(9, 2),
      Offset(4, -3),
      Offset(-1, 2),
      Offset(-6, -2),
      Offset(-12, 1),
      Offset(-15, -4),
      Offset(-9, -16),
      Offset(-5, -30),
    ], const Offset(0, -16)).paint(c, 0, glow: 0);
  });

  late final BakedArt aft = BakedArt(const Rect.fromLTRB(-36, -6, 36, 34), (c) {
    for (final side in [-1.0, 1.0]) {
      CutStone.gem(m, [
        Offset(side * 2, 0),
        Offset(side * 10, 2),
        Offset(side * 32, 16),
        Offset(side * 33, 22),
        Offset(side * 14, 19),
        Offset(side * 10, 28),
        Offset(side * 2, 28),
      ], Offset(side * 10, 12)).paint(c, 0, glow: 0);
    }
    // Dead engines.
    for (final x in [-6.0, 6.0]) {
      paintDisc(c, m.orb, Offset(x, 28), 3.6, 0.6);
    }
  });

  late final BakedArt shard = BakedArt(const Rect.fromLTRB(-6, -6, 6, 6), (c) {
    CutStone.gem(m, const [
      Offset(-4, -2),
      Offset(1, -5),
      Offset(5, 1),
      Offset(-1, 4),
    ], Offset.zero).paint(c, 0, glow: 0);
  });
}

_Wreck? _wreck;

/// A wreck at [at]. Until it has been [looted], a dying spark flickers in
/// its open seam.
void paintDerelict(
  Canvas c, {
  required Offset at,
  required double t,
  bool looted = false,
}) {
  final w = _wreck ??= _Wreck();
  final drift = 5 + 3 * sin(t * 0.25);
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(0.6 + t * 0.03);
  c.scale(1.8);
  if (!looted) paintDisc(c, w.m.pool, Offset.zero, 60, 1.2);
  c.save();
  c.translate(-1, -drift);
  c.rotate(-0.06 + 0.03 * sin(t * 0.4));
  w.fore.draw(c);
  // The canopy, cracked and dark.
  paintOrb(c, w.m, const Offset(0, -22), 4.5, alpha: 0.5);
  c.restore();
  c.save();
  c.translate(1, drift);
  c.rotate(0.08 + 0.03 * sin(t * 0.33 + 1));
  w.aft.draw(c);
  c.restore();
  for (var i = 0; i < 7; i++) {
    final a = t * (0.1 + 0.03 * i) + i * 0.9;
    final rr = 30 + 14 * hash01(i, 21);
    c.save();
    c.translate(cos(a) * rr, sin(a) * rr * 0.8);
    c.rotate(t * (0.5 + i * 0.1));
    c.scale(0.6 + 0.6 * hash01(i, 22));
    w.shard.draw(c);
    c.restore();
  }
  if (!looted) {
    // The last of its power, catching and failing in the seam.
    final flick = (sin(t * 7.3) * sin(t * 2.1 + 1)).abs();
    paintDisc(
      c,
      _light(const Color(0xFFFFB45A)).spark,
      Offset.zero,
      3 + 4 * flick,
    );
  }
  c.restore();
}

// ── meteor zone ─────────────────────────────────────────────────────────────

final PointBatch _haze = PointBatch(160);
final PointBatch _tails = PointBatch(420);
final PointBatch _heads = PointBatch(30);

/// The meteor reach centred on [at], [radius] across, meteors falling along
/// [fall] (radians). [shower] (0..1) is how thick they fall: a trickle
/// normally, a storm during the encounter.
void paintMeteorZone(
  Canvas c, {
  required Offset at,
  required double radius,
  required Color color,
  required double fall,
  required double t,
  double shower = 0,
}) {
  final m = _light(color);
  final dir = Offset(cos(fall), sin(fall));
  final perp = Offset(-dir.dy, dir.dx);
  // Dust drifting the way the meteors fall.
  _haze.clear();
  for (var i = 0; i < 150; i++) {
    final u = (hash01(i, 31) + t * 0.004 * (1 + hash01(i, 32))) % 1.0;
    final v = hash01(i, 33) * 2 - 1;
    final p = at + dir * ((u * 2 - 1) * radius) + perp * (v * radius * 0.9);
    _haze.add(p.dx, p.dy);
  }
  _haze.draw(c, 1.6, m.grainDim.withValues(alpha: 0.28));

  _tails.clear();
  _heads.clear();
  final slots = 10 + (18 * shower).round();
  final cycle = 9.0 - 5 * shower;
  for (var i = 0; i < slots; i++) {
    final local = (t / cycle + hash01(i, 34)) % 1.0;
    if (local > 0.7) continue;
    final f = local / 0.7;
    final lane = (hash01(i, 35) * 2 - 1) * radius * 0.8;
    final start = at - dir * (radius * 1.1) + perp * lane;
    final head = start + dir * (radius * 2.2 * f);
    final len = 50 + 40 * hash01(i, 36);
    for (var k = 1; k <= 14; k++) {
      final q = head - dir * (len * k / 14) + perp * sin(k * 0.7 + i) * 0.8;
      _tails.add(q.dx, q.dy);
    }
    _heads.add(head.dx, head.dy);
  }
  _tails.draw(c, 2.2, m.grainHot.withValues(alpha: 0.6));
  _heads.draw(c, 4.5, m.hot);
}

// ── warp anomaly ────────────────────────────────────────────────────────────

final PointBatch _warpFar = PointBatch(180);
final PointBatch _warpNear = PointBatch(80);

/// A warp anomaly at [at], [radius] across: an unsteady knot of space.
void paintWarpAnomaly(
  Canvas c, {
  required Offset at,
  required double radius,
  required double t,
}) {
  final m = _light(const Color(0xFFA77BFF));
  radius *= 1.5;
  // It cannot hold its shape: the knot slews and pulses.
  final wobble = Offset(sin(t * 2.3) * 3, cos(t * 1.7) * 3);
  final o = at + wobble;
  paintDisc(c, m.pool, o, radius * 2.4, 1.2 + 0.4 * sin(t * 5.1));
  _warpFar.clear();
  _warpNear.clear();
  for (var i = 0; i < 220; i++) {
    final ph = (t * (0.35 + 0.3 * hash01(i, 41)) + hash01(i, 42)) % 1.0;
    final r = radius * (0.12 + (1 - ph) * 1.3);
    final a = hash01(i, 43) * 2 * pi + ph * 7 + sin(t * 3 + i) * 0.15;
    final p = o + Offset(cos(a) * r, sin(a) * r * 0.75);
    (ph > 0.7 ? _warpNear : _warpFar).add(p.dx, p.dy);
  }
  _warpFar.draw(c, 1.2, m.grainDim.withValues(alpha: 0.55));
  _warpNear.draw(c, 1.7, m.grainHot);
  paintDisc(c, _void, o, radius * 0.28);
  paintDisc(c, m.spark, o + Offset(radius * 0.18, 0), 2.6);
}

final ui.Shader _void = ui.Gradient.radial(
  Offset.zero,
  1,
  const [Color(0xFF000000), Color(0xF0020106), Color(0x00020106)],
  const [0.0, 0.7, 1.0],
);

// ── survival gate ───────────────────────────────────────────────────────────

class _Gate {
  final StoneLight m = StoneLight(const Color(0xFF9A6BFF), warm: 0.02);

  /// One standing stone, its foot toward the middle (+x outward).
  late final BakedArt stone = BakedArt(const Rect.fromLTRB(-8, -14, 50, 14), (
    c,
  ) {
    CutStone.gem(m, const [
      Offset(-4, 0),
      Offset(6, -10),
      Offset(34, -7),
      Offset(46, 0),
      Offset(34, 7),
      Offset(6, 10),
    ], const Offset(2, 0)).paint(c, 0, glow: 1, reach: 24);
  });
}

_Gate? _gate;
final PointBatch _gateFar = PointBatch(220);
final PointBatch _gateNear = PointBatch(100);

/// The way into Survival at [at]: nine standing stones round a violet deep.
/// [near] (0..1) wakes it as the ship comes alongside.
void paintSurvivalGate(
  Canvas c, {
  required Offset at,
  required double t,
  double near = 0,
}) {
  final g = _gate ??= _Gate();
  final m = g.m;
  paintDisc(c, m.pool, at, 160, 1 + 0.8 * near);
  c.save();
  c.translate(at.dx, at.dy);
  _gateFar.clear();
  _gateNear.clear();
  for (var i = 0; i < 300; i++) {
    final ph =
        (t * (0.12 + 0.1 * hash01(i, 51)) * (1 + near) + hash01(i, 52)) % 1.0;
    final r = 6 + (1 - ph) * 62;
    final a = hash01(i, 53) * 2 * pi + ph * 4.5 + t * 0.2;
    final p = Offset(cos(a) * r, sin(a) * r);
    (ph > 0.65 ? _gateNear : _gateFar).add(p.dx, p.dy);
  }
  _gateFar.draw(c, 1.3, m.grainDim.withValues(alpha: 0.6));
  paintDisc(c, _void, Offset.zero, 20);
  _gateNear.draw(c, 1.8, m.grainHot);
  for (var i = 0; i < 9; i++) {
    final a = i * 2 * pi / 9 + t * 0.02;
    c.save();
    c.rotate(a);
    c.translate(76, 0);
    g.stone.draw(c);
    c.restore();
  }
  c.restore();
}

// ── boss lair ───────────────────────────────────────────────────────────────

class _Lair {
  _Lair(Color element)
    : m = StoneLight(Color.lerp(element, const Color(0xFFFF2A3A), 0.45)!);
  final StoneLight m;

  late final BakedArt shard = BakedArt(const Rect.fromLTRB(-6, -10, 40, 10), (
    c,
  ) {
    CutStone.gem(m, const [
      Offset(-2, 0),
      Offset(6, -7),
      Offset(30, -2),
      Offset(36, 0),
      Offset(24, 5),
      Offset(6, 7),
    ], const Offset(2, 0)).paint(c, 0, glow: 0.6, reach: 20);
  });

  /// The sealed heart: a dark egg with the light deep inside.
  late final ui.Shader heart = ui.Gradient.radial(
    const Offset(-0.3, -0.35),
    1.4,
    [
      Color.lerp(m.essence, const Color(0xFF000000), 0.35)!,
      Color.lerp(m.essence, const Color(0xFF000000), 0.8)!,
      const Color(0xFF050204),
    ],
    const [0.0, 0.45, 1.0],
  );
}

final Map<Color, _Lair> _lairs = {};
final PointBatch _wakeRing = PointBatch(90);
final PointBatch _embers = PointBatch(40);

/// A boss lair at [at] for a boss of [element]'s color. [wakeRadius] is how
/// close the ship can come before it wakes, marked by a faint ring of grains.
void paintBossLair(
  Canvas c, {
  required Offset at,
  required Color element,
  required double wakeRadius,
  required double t,
}) {
  final l = _lairs[element] ??= _Lair(element);
  final m = l.m;
  // Where it wakes.
  _wakeRing.clear();
  for (var i = 0; i < 90; i++) {
    final a = i * 2 * pi / 90 + t * 0.02 + hash01(i, 61) * 0.05;
    final r = wakeRadius * (0.98 + 0.04 * hash01(i, 62));
    _wakeRing.add(at.dx + cos(a) * r, at.dy + sin(a) * r);
  }
  _wakeRing.draw(c, 1.6, m.grainDim.withValues(alpha: 0.32));

  final beat = pow(0.5 + 0.5 * sin(t * 1.4), 6).toDouble();
  paintDisc(c, m.pool, at, 110, 0.9 + 0.8 * beat);
  c.save();
  c.translate(at.dx, at.dy);
  for (var i = 0; i < 7; i++) {
    final a = i * 2 * pi / 7 + 0.3 * sin(t * 0.2 + i);
    c.save();
    c.rotate(a);
    c.translate(22 + 3 * hash01(i, 63), 0);
    c.scale(0.8 + 0.5 * hash01(i, 64));
    l.shard.draw(c);
    c.restore();
  }
  // The heart, beating slowly.
  c.save();
  c.scale(17 * (1 + 0.04 * beat));
  stonePaint
    ..shader = l.heart
    ..color = const Color(0xFFFFFFFF);
  c.drawCircle(Offset.zero, 1, stonePaint);
  stonePaint.shader = null;
  c.restore();
  paintDisc(c, m.spark, const Offset(-3, -4), 3 + 3 * beat, 0.5 + 0.5 * beat);
  _embers.clear();
  for (var i = 0; i < 26; i++) {
    final ph = (t * 0.18 + hash01(i, 65)) % 1.0;
    final p = Offset((hash01(i, 66) - 0.5) * 40, -ph * 70);
    _embers.add(p.dx, p.dy);
  }
  _embers.draw(c, 1.6, m.grainHot.withValues(alpha: 0.7));
  c.restore();
}

// ── lore note ───────────────────────────────────────────────────────────────

final StoneLight _noteLight = StoneLight(const Color(0xFFE9C77A));
final BakedArt _noteShard = BakedArt(const Rect.fromLTRB(-8, -12, 8, 12), (c) {
  CutStone.gem(_noteLight, const [
    Offset(0, -11),
    Offset(6, -2),
    Offset(3, 10),
    Offset(-4, 8),
    Offset(-6, -3),
  ], const Offset(0, -2)).paint(c, 0, glow: 1.4, reach: 12);
});
final PointBatch _noteMotes = PointBatch(8);

/// A drifting note at [at]: a small lit shard, a few motes round it.
void paintLoreNote(
  Canvas c, {
  required Offset at,
  required double t,
  int seed = 0,
}) {
  final bob = Offset(0, sin(t * 1.3 + seed) * 3);
  final p = at + bob;
  paintDisc(c, _noteLight.pool, p, 40, 1.6);
  c.save();
  c.translate(p.dx, p.dy);
  c.rotate(sin(t * 0.7 + seed) * 0.3);
  c.scale(1.6);
  _noteShard.draw(c);
  c.restore();
  paintDisc(c, _noteLight.spark, p + const Offset(-1, -2), 2.2);
  _noteMotes.clear();
  for (var i = 0; i < 6; i++) {
    final a = t * 0.9 + i * pi / 3 + seed;
    _noteMotes.add(p.dx + cos(a) * 22, p.dy + sin(a) * 14);
  }
  _noteMotes.draw(c, 1.4, _noteLight.grainHot.withValues(alpha: 0.7));
}

// ── Loot ────────────────────────────────────────────────────────────────────
//
// What a fight leaves behind: glass orbs of light (health, element), each
// with a few grains of its color circling it, and astral shards — a cut
// crystal of violet glass turning slowly. Material, like the stations' orbs.

final PointBatch _lootGrains = PointBatch(12);

/// A loot orb of [color], radius [r], at [at]; [t] its clock, [alpha] its
/// fade as it expires.
void paintLootOrb(
  Canvas c, {
  required Offset at,
  required Color color,
  required double t,
  double r = 6,
  double alpha = 1,
}) {
  final m = stoneLightFor(color);
  final pulse = 0.8 + 0.2 * sin(t * 4.5);
  paintDisc(c, m.leak, at, r * 2.6, alpha * pulse);
  paintOrb(c, m, at, r, alpha: alpha);
  paintDisc(c, m.spark, at, r * 0.75, 0.8 * alpha * pulse);
  _lootGrains.clear();
  for (var i = 0; i < 6; i++) {
    final a = t * (1.6 + 0.3 * i) + i * 2 * pi / 6;
    final rr = r * (1.6 + 0.35 * sin(t * 2 + i));
    _lootGrains.add(at.dx + cos(a) * rr, at.dy + sin(a) * rr * 0.6);
  }
  _lootGrains.draw(c, 1.6, m.grainHot.withValues(alpha: 0.8 * alpha));
}

StoneLight? _shardLight;
final List<BakedArt?> _shardTurns = List.filled(8, null);

/// An astral shard: a crystal of violet glass, turning, at [at].
void paintAstralShard(
  Canvas c, {
  required Offset at,
  required double t,
  double alpha = 1,
}) {
  final m = _shardLight ??= StoneLight(const Color(0xFF9E7BFF), warm: 0.05);
  final shimmer = 0.75 + 0.25 * sin(t * 4);
  paintDisc(c, m.leak, at, 18, alpha * shimmer);
  // The crystal turns about its long axis — read as it swapping which face
  // catches the light — so one of eight bakes, chosen by the turn.
  final k = ((t * 1.6) % 8).floor();
  final art = _shardTurns[k] ??= BakedArt(const Rect.fromLTRB(-8, -11, 8, 11), (
    cv,
  ) {
    final w = 4.6 * (0.55 + 0.45 * cos(k * pi / 8).abs());
    CutStone.gem(m, [
      const Offset(0, -10),
      Offset(w, -2),
      Offset(w * 0.8, 3),
      const Offset(0, 10),
      Offset(-w * 0.8, 3),
      Offset(-w, -2),
    ], Offset(w * 0.3 * (k < 4 ? 1 : -1), -1)).paint(
      cv,
      k * pi / 4,
      glow: 0.9,
      reach: 12,
    );
  });
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(1.4);
  art.draw(c, alpha);
  c.restore();
  paintDisc(c, m.spark, at, 4.5, alpha * shimmer);
  paintDisc(c, kGlint, at + const Offset(-2, -7), 3, 0.8 * alpha);
}
