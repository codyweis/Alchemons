// lib/games/cosmic/cosmic_cache_vfx.dart
//
// The artwork for sealed elemental caches: the dormant reliquary, and the
// unsealing every element performs its own way — fire rises out of it, lava
// sags through, ice and earth throw glass, crystal grows, dark pulls
// everything in. Shared by the caches in open space and the daily cache on
// home.
//
// A cache is a reliquary of near-black glass, split down the middle by a
// seam of its element's light, with six shards of the seal circling it.
// Unsealing is one eased, unbroken motion: the element is drawn in, the
// seal loosens and drifts off, the halves part and dissolve into grains,
// and the element flows out of the seam — each element its own way — and
// thins to nothing as the light swells and fades. No snaps, bursts or
// flashes, and nothing left on screen at the end. Material and grains only,
// in the language of the stations (obsidian_kit.dart): no stroked hoops or
// lines.
//
// Plain paint functions on purpose: the open-world game calls them from its
// render loop, and they can be exercised on any canvas without a game.

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'cosmic_cache_data.dart';
import 'cosmic_data.dart';
import 'obsidian_kit.dart';

const double _r = ElementalCache.visualRadius;

/// One element's reliquary, baked once: its two halves, a shard of its seal,
/// and the glass its element throws (ice, earth, crystal).
class _Reliquary {
  _Reliquary(Color c) : m = stoneLightFor(c);

  final StoneLight m;

  static const _outline = [
    Offset(0, -38),
    Offset(15, -30),
    Offset(27, -10),
    Offset(26, 12),
    Offset(14, 32),
    Offset(0, 40),
    Offset(-14, 32),
    Offset(-26, 12),
    Offset(-27, -10),
    Offset(-15, -30),
  ];

  late final CutStone _gem = CutStone.gem(m, _outline, const Offset(-5, -8));

  BakedArt _half(bool left) =>
      BakedArt(Rect.fromLTRB(left ? -30 : 0, -42, left ? 0 : 30, 42), (c) {
        c.clipRect(Rect.fromLTRB(left ? -30 : 0, -42, left ? 0 : 30, 42));
        _gem.paint(c, 0, glow: 0.7, reach: 46);
      });

  late final BakedArt left = _half(true);
  late final BakedArt right = _half(false);

  /// A shard of the seal, its long axis along x.
  late final BakedArt shard = BakedArt(const Rect.fromLTRB(-10, -5, 10, 5), (
    c,
  ) {
    CutStone.gem(m, const [
      Offset(-9, 0),
      Offset(-2, -4),
      Offset(9, -1),
      Offset(8, 2),
      Offset(-2, 4),
    ], const Offset(-1, -1)).paint(c, 0, glow: 0.4, reach: 10);
  });

  /// A long crystal, its point along +x.
  late final BakedArt crystal = BakedArt(const Rect.fromLTRB(-2, -7, 34, 7), (
    c,
  ) {
    CutStone.gem(m, const [
      Offset(0, -4),
      Offset(22, -6),
      Offset(33, 0),
      Offset(22, 6),
      Offset(0, 4),
    ], const Offset(18, -1)).paint(c, 0, glow: 0.6, reach: 16);
  });

  /// The seam's light: a lens, unit high and wide (see [_seam]).
  static final Path lens = Path()
    ..moveTo(0, -1)
    ..quadraticBezierTo(1, 0, 0, 1)
    ..quadraticBezierTo(-1, 0, 0, -1)
    ..close();
}

final Map<String, _Reliquary> _reliquaries = {};
_Reliquary _reliquary(String element) =>
    _reliquaries[element] ??= _Reliquary(elementColor(element));

final PointBatch _dim = PointBatch(60);
final PointBatch _big = PointBatch(200);

/// The seam of light down the middle, [w] wide at its waist, [h] tall.
void _seam(Canvas c, StoneLight m, Offset p, double w, double h, double a) {
  c.save();
  c.translate(p.dx, p.dy);
  c.scale(w, h);
  paintFill(c, _Reliquary.lens, m.spark, a);
  c.restore();
}

/// The two halves, parted by [gap] each side and leaning out by [lean].
void _halves(
  Canvas c,
  _Reliquary q,
  Offset p,
  double gap,
  double lean, [
  double alpha = 1,
]) {
  for (final side in const [-1.0, 1.0]) {
    c.save();
    c.translate(p.dx + side * gap, p.dy);
    c.rotate(side * lean);
    (side < 0 ? q.left : q.right).draw(c, alpha);
    c.restore();
  }
}

/// The seal: six shards circling at [radius], turned to [spin].
void _sealShards(
  Canvas c,
  _Reliquary q,
  Offset p,
  double spin,
  double radius, [
  double alpha = 1,
]) {
  if (alpha <= 0.01) return;
  for (var i = 0; i < 6; i++) {
    final a = spin + i * pi / 3;
    c.save();
    c.translate(p.dx + cos(a) * radius, p.dy + sin(a) * radius);
    c.rotate(a + pi / 2);
    c.scale(1.7);
    q.shard.draw(c, alpha);
    c.restore();
  }
}

/// The dormant construct: the reliquary, its seam breathing, its seal
/// turning slowly, a few grains of the element drifting in to it.
/// Deliberately cheap — up to 17 of these exist.
void paintSealedCache(Canvas canvas, Offset p, String element, double life) {
  final q = _reliquary(element);
  final m = q.m;
  final breathe = 0.5 + 0.5 * sin(life * 1.4);

  paintDisc(canvas, m.pool, p, _r * 1.8, 0.75 + 0.25 * breathe);
  paintDisc(canvas, m.leak, p, _r * 0.8, 0.35 + 0.3 * breathe);

  _idleGrains(canvas, m, p, life, 1);

  _halves(canvas, q, p, 0, 0);
  _seam(canvas, m, p, 2.6 + 1.6 * breathe, _r * 0.62, 0.8 + 0.2 * breathe);
  _sealShards(canvas, q, p, life * 0.25, _r * 1.02);
}

/// Paint the unsealing of an [element] cache centred on [p].
///
/// [life] is the cache's free-running clock (its idle breathing carries on
/// into the first moments, so the hand-over from [paintSealedCache] is
/// seamless); [t] is the 0 → 1 progress through the ritual.
///
/// One unbroken, eased motion: the element is drawn in to the seam, the
/// seal loosens and drifts away, the halves part and dissolve into grains,
/// and the element flows out of the seam and thins to nothing. Grains carry
/// short trails, so their paths read as currents rather than dots. Every
/// layer is gone by t = 1, so whatever cuts to the reward cuts nothing off.
void paintCacheUnseal(
  Canvas canvas,
  Offset p,
  String element,
  double life,
  double t,
) {
  final q = _reliquary(element);
  final m = q.m;
  final dark = element == 'Dark';
  final breathe = 0.5 + 0.5 * sin(life * 1.4);
  final charge = _smooth(0, 0.4, t);
  final part = _smooth(0.28, 0.82, t);
  // The idle breathing, handing over to the ritual.
  final calm = 1 - charge;
  final beat = element == 'Blood' ? _heartbeat(t) : 0.0;

  // The element's light: swells as it is drawn in, then thins away.
  paintDisc(
    canvas,
    m.pool,
    p,
    _r *
        (1.8 +
            0.7 * _smooth(0, 0.6, t) +
            0.5 * _smooth(0.5, 1, t) +
            0.25 * beat),
    (0.75 + 0.25 * (calm * breathe + charge)) * (1 - _smooth(0.6, 1, t)),
  );
  paintDisc(
    canvas,
    m.leak,
    p,
    _r * (0.8 + 0.4 * charge + 0.2 * beat),
    (0.35 + 0.3 * breathe * calm + 0.35 * charge) * (1 - _smooth(0.5, 0.9, t)),
  );
  _idleGrains(canvas, m, p, life, 1 - _smooth(0, 0.3, t));

  // The halves drift apart and fade as they come undone; the seam between
  // them widens, then its light goes out into the bloom.
  _halves(canvas, q, p, 18 * part, 0.1 * part, 1 - _smooth(0.5, 0.88, t));
  _seam(
    canvas,
    m,
    p,
    2.6 + 1.6 * breathe * calm + 5 * charge + 9 * part,
    _r * (0.62 + 0.15 * charge),
    (0.8 + 0.2 * max(breathe * calm, charge)) *
        (1 - _smooth(dark ? 0.4 : 0.55, dark ? 0.78 : 0.92, t)),
  );
  _sealDrift(canvas, q, p, life, t);

  // The glass some elements throw.
  switch (element) {
    case 'Ice':
      _drifters(canvas, q.crystal, p, t, count: 9, from: 0.28, to: 0.48);
    case 'Earth':
      _drifters(
        canvas,
        q.shard,
        p,
        t,
        count: 12,
        from: 0.3,
        to: 0.46,
        scale: 2.2,
        tumble: 3,
        settle: 0.25,
      );
    case 'Crystal':
      _crystalGrowth(canvas, q, p, t);
  }

  // The bloom: a slow swell of light out of the opened seam — or, for
  // Dark, a black that spreads and thins.
  final bloom = _bell(0.4, 0.68, 0.98, t);
  final reach = _smooth(0.4, 0.95, t);
  if (dark) {
    paintDisc(canvas, _black, p, _r * (0.3 + 1.0 * reach), 0.9 * bloom);
  } else {
    paintDisc(canvas, m.leak, p, _r * (0.6 + 1.2 * reach), 0.6 * bloom);
    paintDisc(canvas, m.spark, p, _r * (0.25 + 0.45 * reach), 0.3 * bloom);
  }

  // The grains: drawn in, shed by the halves, and the element's own flow.
  _ox = p.dx;
  _oy = p.dy;
  _clearGrains();
  if (!dark) _gather(t);
  _dissolve(t, 18 * part);
  switch (element) {
    case 'Lightning':
      _lightning(t, life);
    case 'Plant':
      _plant(t);
    case 'Crystal':
      _crystalGlints(t, life);
  }
  final stream = _streams[element];
  if (stream != null) _stream(stream, t, life);
  _drawGrains(canvas, m);
}

/// Dark's bloom: a black with no edge. Unit radius.
final Shader _black = RadialGradient(
  colors: [
    const Color(0xFF050308),
    const Color(0xFF050308).withValues(alpha: 0.8),
    const Color(0x00050308),
  ],
  stops: const [0.0, 0.55, 1.0],
).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));

// ── easing ───────────────────────────────────────────────

double _smooth(double a, double b, double x) {
  final u = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return u * u * (3 - 2 * u);
}

/// Up from nothing at [a] to full at [peak], back to nothing at [b].
double _bell(double a, double peak, double b, double x) =>
    x < peak ? _smooth(a, peak, x) : 1 - _smooth(peak, b, x);

/// Fast away, slowing as it goes: a grain released into a current.
double _out(double a) => 1 - (1 - a) * (1 - a);

/// A grain's light over its age: in quickly, out slowly.
double _env(double a) => _smooth(0, 0.15, a) * (1 - _smooth(0.5, 1, a));

/// When Blood's heart beats, through the ritual.
const List<double> _beats = [0.16, 0.36, 0.56];

/// Soft heartbeats, 0..1, peaking on [_beats].
double _heartbeat(double t) {
  var v = 0.0;
  for (final b in _beats) {
    final d = (t - b) / 0.04;
    v += exp(-d * d);
  }
  return min(v, 1.0);
}

// ── grains ───────────────────────────────────────────────

Float32List _hashes(int salt) =>
    Float32List.fromList([for (var i = 0; i < 256; i++) hash01(i, salt)]);

final Float32List _h1 = _hashes(1);
final Float32List _h2 = _hashes(2);
final Float32List _h3 = _hashes(3);
final Float32List _h4 = _hashes(4);

/// When each grain is born, leaning late so most pour once the seam opens.
final Float32List _hBorn = Float32List.fromList([
  for (var i = 0; i < 256; i++) 0.35 * hash01(i, 5) + 0.65 * sqrt(hash01(i, 5)),
]);

// Grains sorted by how lit they are, so a grain can fade in and out with
// only five draws for the lot.
final PointBatch _g0 = PointBatch(1400);
final PointBatch _g1 = PointBatch(1400);
final PointBatch _g2 = PointBatch(1400);
final PointBatch _g3 = PointBatch(1400);
final PointBatch _bigDim = PointBatch(200);

double _ox = 0, _oy = 0;

void _clearGrains() {
  _g0.clear();
  _g1.clear();
  _g2.clear();
  _g3.clear();
  _big.clear();
  _bigDim.clear();
}

/// One grain at ([x], [y]) from the cache's centre, lit by [glow] (0..1).
void _grain(double x, double y, double glow) {
  if (glow > 0.72) {
    _g0.add(_ox + x, _oy + y);
  } else if (glow > 0.48) {
    _g1.add(_ox + x, _oy + y);
  } else if (glow > 0.26) {
    _g2.add(_ox + x, _oy + y);
  } else if (glow > 0.07) {
    _g3.add(_ox + x, _oy + y);
  }
}

/// A heavy grain: a drop, a puff, a bubble, a leaf.
void _bigGrain(double x, double y, double glow) {
  if (glow > 0.5) {
    _big.add(_ox + x, _oy + y);
  } else if (glow > 0.12) {
    _bigDim.add(_ox + x, _oy + y);
  }
}

void _drawGrains(Canvas c, StoneLight m) {
  _g3.draw(c, 1.9, m.grainDim.withValues(alpha: 0.3));
  _g2.draw(c, 2.1, m.grainDim.withValues(alpha: 0.7));
  _bigDim.draw(c, 3.8, m.grainDim.withValues(alpha: 0.45));
  _big.draw(c, 4.2, m.grainHot.withValues(alpha: 0.75));
  _g1.draw(c, 2.3, m.grainHot.withValues(alpha: 0.65));
  _g0.draw(c, 2.6, m.grainHot);
}

/// The few grains that drift in to a sealed cache, at [alpha].
void _idleGrains(
  Canvas canvas,
  StoneLight m,
  Offset p,
  double life,
  double alpha,
) {
  if (alpha <= 0.01) return;
  _dim.clear();
  for (var i = 0; i < 40; i++) {
    final ph = (life * (0.08 + 0.05 * hash01(i, 2)) + hash01(i, 3)) % 1.0;
    final a = hash01(i, 1) * 2 * pi + ph * 1.4;
    final r = _r * (1.5 - 1.2 * ph);
    _dim.add(p.dx + cos(a) * r, p.dy + sin(a) * r);
  }
  _dim.draw(canvas, 2, m.grainDim.withValues(alpha: 0.6 * alpha));
}

/// The element drawn in to the seam: grains spiralling in from the ring the
/// companion circles, slow at first and quickening as they near.
void _gather(double t) {
  if (t > 0.6) return;
  for (var i = 0; i < 50; i++) {
    final j = i + 180;
    final life = 0.24 + 0.1 * _h4[j];
    final a = (t - 0.26 * _h1[j]) / life;
    for (var k = 0; k <= 2; k++) {
      final ak = a - k * 0.06;
      if (ak < 0 || ak > 1) continue;
      final th = _h2[j] * 2 * pi + (1 - ak) * 1.3;
      final rad = _r * (0.12 + 1.95 * (1 - ak * ak));
      _grain(cos(th) * rad, sin(th) * rad, 0.75 * _env(ak) * (1 - 0.3 * k));
    }
  }
}

/// The halves coming undone: grains lifting off their edges and drifting
/// away, as the glass fades.
void _dissolve(double t, double gap) {
  if (t < 0.48) return;
  const outline = _Reliquary._outline;
  for (var i = 0; i < 64; i++) {
    final j = i + 40;
    final a = (t - 0.48 - 0.3 * _h1[j]) / 0.3;
    if (a < 0) continue;
    final v = (i * 3) % outline.length;
    final from = outline[v], to = outline[(v + 1) % outline.length];
    final at = Offset.lerp(from, to, _h2[j])!;
    final side = at.dx < 0 || (at.dx == 0 && i.isEven) ? -1.0 : 1.0;
    for (var k = 0; k <= 1; k++) {
      final ak = a - k * 0.08;
      if (ak < 0 || ak > 1) continue;
      final d = _out(ak);
      _grain(
        at.dx + side * gap + side * (0.15 + 0.45 * _h3[j]) * _r * d,
        at.dy - (0.15 + 0.35 * _h4[j]) * _r * ak,
        0.7 * _env(ak) * (1 - 0.4 * k),
      );
    }
  }
}

// ── the seal and the glass ───────────────────────────────

/// The seal's six shards loosening: their turn eases a little further, each
/// drifts out to its own distance, tumbles and fades — never a burst, and
/// never one ring.
void _sealDrift(Canvas c, _Reliquary q, Offset p, double life, double t) {
  final loose = _smooth(0.18, 0.9, t);
  final spin = life * 0.25 + 0.9 * _smooth(0, 1, t);
  for (var i = 0; i < 6; i++) {
    final h = _h1[i + 7];
    final alpha = 1 - _smooth(0.42 + 0.12 * h, 0.8 + 0.12 * h, t);
    if (alpha <= 0.01) continue;
    final a = spin + i * pi / 3 + loose * (h - 0.5) * 0.9;
    final rad = _r * 1.02 * (1 + loose * (0.8 + 0.8 * h));
    c.save();
    c.translate(p.dx + cos(a) * rad, p.dy + sin(a) * rad);
    c.rotate(a + pi / 2 + loose * (h - 0.5) * 2.6);
    c.scale(1.7 * (1 - 0.25 * loose));
    q.shard.draw(c, alpha);
    c.restore();
  }
}

/// [count] pieces of glass born between [from] and [to], each drifting out
/// from the seam and slowing, turning by [tumble], sinking by [settle].
void _drifters(
  Canvas c,
  BakedArt piece,
  Offset p,
  double t, {
  required int count,
  required double from,
  required double to,
  double reach = 1.25,
  double scale = 1,
  double tumble = 0.8,
  double settle = 0,
}) {
  for (var i = 0; i < count; i++) {
    final j = i + 20;
    final a = (t - from - (to - from) * _h1[j]) / 0.5;
    if (a < 0 || a > 1) continue;
    final alpha = _smooth(0, 0.18, a) * (1 - _smooth(0.55, 1, a));
    final ang = i * 2 * pi / count + _h2[j] * 0.5;
    final rad = _r * (0.3 + reach * _out(a)) * (0.85 + 0.3 * _h3[j]);
    c.save();
    c.translate(
      p.dx + cos(ang) * rad,
      p.dy + sin(ang) * rad + settle * _r * a * a,
    );
    c.rotate(ang + tumble * (_h3[j] - 0.5) * (0.5 + a));
    c.scale(scale);
    piece.draw(c, alpha);
    c.restore();
  }
}

/// The crystals stand lopsided — uneven angles and lengths — so the growth
/// never reads as a star.
double _crystalAngle(int k) => k * 2 * pi / 8 + (_h1[k + 30] - 0.5) * 1.3;
double _crystalSize(int k) => 0.55 + 0.75 * _h3[k + 30];

double _crystalGrow(double t) =>
    Curves.easeOutCubic.transform(_smooth(0.18, 0.7, t));

/// Crystal grows out of the seam in long faceted points, then lets go of
/// them as light (see [_crystalGlints]).
void _crystalGrowth(Canvas c, _Reliquary q, Offset p, double t) {
  final grow = _crystalGrow(t);
  final fade = 1 - _smooth(0.66, 0.92, t);
  if (grow <= 0 || fade <= 0.01) return;
  for (var i = 0; i < 8; i++) {
    final j = i + 30;
    final ang = _crystalAngle(i);
    final rad = _r * (0.15 + 0.55 * grow) * (0.85 + 0.3 * _h2[j]);
    c.save();
    c.translate(p.dx + cos(ang) * rad, p.dy + sin(ang) * rad);
    c.rotate(ang);
    c.scale((0.25 + 0.85 * grow) * _crystalSize(i));
    q.crystal.draw(c, fade);
    c.restore();
  }
}

void _crystalGlints(double t, double life) {
  final grow = _crystalGrow(t);
  if (grow <= 0) return;
  final away = _smooth(0.6, 1, t);
  final fade = 1 - _smooth(0.82, 1, t);
  for (var i = 0; i < 70; i++) {
    final k = i % 8;
    final j = k + 30;
    final ang = _crystalAngle(k);
    final s = (0.25 + 0.85 * grow) * _crystalSize(k);
    final rad =
        _r * (0.15 + 0.55 * grow) * (0.85 + 0.3 * _h2[j]) +
        _h2[i] * 33 * s +
        away * (0.3 + 0.8 * _h3[i]) * _r;
    final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(life * 6 + i * 2.3));
    final th = ang + (_h4[i] - 0.5) * 0.25 * (1 + 2 * away);
    _grain(cos(th) * rad, sin(th) * rad, twinkle * grow * fade);
  }
}

// ── the elements that grow rather than pour ──────────────

/// Lightning: filaments of grain reaching out of the seam and wandering, the
/// way they do in a plasma globe, crackling along their length.
void _lightning(double t, double life) {
  final grow = _smooth(0.15, 0.6, t);
  final fade = 1 - _smooth(0.7, 0.95, t);
  if (grow <= 0 || fade <= 0) return;
  final flick = (life * 14).floor();
  for (var bolt = 0; bolt < 6; bolt++) {
    final base =
        bolt * 2 * pi / 6 + 0.8 * sin(t * 2.2 + bolt * 1.7) + _h1[bolt] * 0.6;
    final len = _r * (0.3 + 1.6 * grow) * (0.75 + 0.25 * _h2[bolt]);
    for (var k = 1; k <= 26; k++) {
      final s = k / 26;
      final th = base + 0.55 * sin(s * 3.2 + t * 6 + bolt * 2.1) * s;
      final jag = (hash01(k + bolt * 31 + flick * 131, 5) - 0.5) * 7 * s;
      final rad = s * len;
      _grain(
        cos(th) * rad - sin(th) * jag,
        sin(th) * rad + cos(th) * jag,
        fade * (1 - 0.65 * s) * (0.6 + 0.4 * grow),
      );
    }
  }
}

/// Plant: five stems curling out of the seam, leaves along them, the
/// growing tips brightest.
void _plant(double t) {
  final grow = _smooth(0.15, 0.7, t);
  final fade = 1 - _smooth(0.72, 0.97, t);
  if (grow <= 0 || fade <= 0) return;
  for (var arm = 0; arm < 5; arm++) {
    final dir = arm.isEven ? 1.0 : -1.0;
    final base = arm * 2 * pi / 5 + 0.4 + _h1[arm] * 0.5;
    for (var k = 1; k <= 34; k++) {
      final s = k / 34;
      if (s > grow) break;
      final th =
          base +
          dir * s * (1.1 + 0.5 * _h2[arm]) +
          0.25 * sin(s * 5 + arm * 1.7 + t * 2) * s;
      final rad = s * _r * 1.7;
      final x = cos(th) * rad, y = sin(th) * rad;
      final tip = s > grow - 0.08;
      _grain(x, y, fade * (tip ? 1 : 0.5 + 0.25 * (1 - s)));
      if (k % 6 == 5) {
        final side = k.isEven ? 6.0 : -6.0;
        _bigGrain(x - sin(th) * side, y + cos(th) * side, fade * 0.8);
      }
    }
  }
}

// ── the elements that pour ───────────────────────────────

/// Where a pouring grain is at age [a] (0..1): sets [_fx], [_fy] and may
/// scale its light by [_fGlow].
typedef _Flow = void Function(int i, double a, double t, double life);

double _fx = 0, _fy = 0, _fGlow = 1;

class _Stream {
  const _Stream(
    this.flow, {
    this.n = 140,
    this.trail = 3,
    this.step = 0.045,
    this.big = 0,
    this.onBeats = false,
  });

  final _Flow flow;
  final int n;

  /// How many earlier points of its path each grain trails, [step] apart.
  final int trail;
  final double step;

  /// Every [big]th grain is a heavy one, and trails nothing; 0 for none.
  final int big;

  /// Born in plumes on Blood's heartbeats rather than in a steady pour.
  final bool onBeats;
}

/// Each grain is born between t ≈ 0.06 and 0.6, lives a third of the
/// ritual, and is gone before it ends.
void _stream(_Stream s, double t, double life) {
  for (var i = 0; i < s.n; i++) {
    var span = 0.3 + 0.16 * _h4[i];
    final born = s.onBeats
        ? _beats[i % _beats.length] - 0.01 + 0.05 * _hBorn[i]
        : 0.06 + (0.9 - span) * _hBorn[i];
    span = min(span, 0.97 - born);
    final a = (t - born) / span;
    if (a < 0 || a > 1 + s.trail * s.step) continue;
    final heavy = s.big > 0 && i % s.big == 0;
    final trail = heavy ? 0 : s.trail;
    for (var k = 0; k <= trail; k++) {
      final ak = a - k * s.step;
      if (ak < 0) break;
      if (ak > 1) continue;
      _fGlow = 1;
      s.flow(i, ak, t, life);
      final glow = _env(ak) * _fGlow * (1 - 0.8 * k / (trail + 1));
      if (heavy) {
        _bigGrain(_fx, _fy, glow);
      } else {
        _grain(_fx, _fy, glow);
      }
    }
  }
}

final Map<String, _Stream> _streams = {
  'Fire': const _Stream(_fire, n: 150),
  'Lava': const _Stream(_lava, n: 110, trail: 2, big: 4),
  'Water': const _Stream(_water, n: 150, trail: 4, step: 0.04),
  'Ice': const _Stream(_ice, n: 80, trail: 1),
  'Steam': const _Stream(_steam, n: 130, trail: 2, big: 3),
  'Earth': const _Stream(_earth, n: 80, trail: 1),
  'Mud': const _Stream(_mud, n: 80, trail: 2, big: 2),
  'Dust': const _Stream(_dust, n: 160, trail: 2),
  'Air': const _Stream(_air, n: 140, trail: 5, step: 0.035),
  'Poison': const _Stream(_poison, n: 70, trail: 1, big: 2),
  'Spirit': const _Stream(_spirit, n: 120, trail: 5, step: 0.04),
  'Dark': const _Stream(_dark, n: 170),
  'Light': const _Stream(_light, n: 144, trail: 4, step: 0.04),
  'Blood': const _Stream(_blood, n: 150, onBeats: true),
};

/// Fire rises in tongues that sway and narrow as they climb.
void _fire(int i, double a, double t, double life) {
  final x0 = (_h1[i] - 0.5) * 1.1 * _r;
  final y0 = (_h2[i] - 0.1) * 0.6 * _r;
  _fx =
      x0 * (1 - 0.7 * a) +
      sin(a * 4 + _h3[i] * 2 * pi + life * 2.2) * 0.28 * _r * a;
  _fy = y0 - (0.5 * a + 0.5 * _out(a)) * 2 * _r;
}

/// Lava sags out of the parting halves and falls, slow and heavy.
void _lava(int i, double a, double t, double life) {
  final x0 = (_h1[i] - 0.5) * 0.4 * _r;
  final y0 = (_h2[i] - 0.15) * 0.6 * _r;
  _fx = x0 * (1 + 0.9 * a) + sin(a * 3 + _h3[i] * 2 * pi) * 0.06 * _r;
  _fy = y0 + (0.2 * a + 0.8 * a * a) * 1.6 * _r;
}

/// Water turns out of the seam in a widening whirl.
void _water(int i, double a, double t, double life) {
  final th = _h1[i] * 2 * pi + a * 2.6 + t * 0.9;
  final rad = (0.15 + 1.75 * _out(a)) * _r * (0.85 + 0.3 * _h2[i]);
  _fx = cos(th) * rad;
  _fy = sin(th) * rad * 0.9;
}

/// Ice: frost drifting slowly out round the shards, glittering.
void _ice(int i, double a, double t, double life) {
  final th = _h1[i] * 2 * pi + a * 0.5;
  final rad = (0.3 + 1.2 * _out(a)) * _r * (0.8 + 0.4 * _h2[i]);
  _fx = cos(th) * rad;
  _fy = sin(th) * rad - 0.1 * _r * a;
  _fGlow = 0.45 + 0.55 * (0.5 + 0.5 * sin(life * 6 + i * 1.7));
}

/// Steam billows up, widening and curling as it rises.
void _steam(int i, double a, double t, double life) {
  final d = _out(a);
  _fx =
      (_h1[i] - 0.5) * 0.4 * _r +
      (_h3[i] - 0.5) * 1.9 * _r * d +
      sin(a * 3.5 + _h1[i] * 9 + life) * 0.16 * _r * a;
  _fy = (_h2[i] - 0.5) * 0.6 * _r - d * 1.9 * _r;
}

/// Earth: grit thrown out with the chips, settling as it slows.
void _earth(int i, double a, double t, double life) {
  final th = _h1[i] * 2 * pi;
  final rad = (0.3 + 1.3 * _out(a)) * _r;
  _fx = cos(th) * rad;
  _fy = sin(th) * rad + 0.3 * _r * a * a;
}

/// Mud oozes down out of the seam in slow heavy drops.
void _mud(int i, double a, double t, double life) {
  final x0 = (_h1[i] - 0.5) * 0.32 * _r;
  final y0 = (_h2[i] - 0.1) * 0.5 * _r;
  _fx = x0 * (1 + 0.7 * a) + sin(a * 2.4 + _h3[i] * 2 * pi) * 0.06 * _r;
  _fy = y0 + (0.15 * a + 0.6 * a * a) * 1.5 * _r;
}

/// Dust: a wide cloud swirling out and drifting off.
void _dust(int i, double a, double t, double life) {
  final th = _h1[i] * 2 * pi + a * 1.7 + t * 0.7;
  final rad = (0.25 + 1.9 * _out(a)) * _r * (0.7 + 0.3 * _h2[i]);
  _fx = cos(th) * rad + 0.25 * _r * a;
  _fy = sin(th) * rad * 0.72 - 0.1 * _r * a;
}

/// Air: a vortex coming loose — streaks swept round the cache, widening,
/// and carried off downwind.
void _air(int i, double a, double t, double life) {
  final th = _h1[i] * 2 * pi + a * 2.6 + t * 1.2;
  final rad = (0.45 + 0.6 * _h3[i] + 0.6 * _out(a)) * _r;
  final tilt = (_h2[i] - 0.5) * 0.9;
  final ex = cos(th) * rad, ey = sin(th) * rad * (0.35 + 0.25 * _h4[i]);
  _fx = ex * cos(tilt) - ey * sin(tilt) + a * a * 1.3 * _r;
  _fy = ex * sin(tilt) + ey * cos(tilt) - a * a * 0.3 * _r;
}

/// Poison: bubbles rising and wobbling until they thin away.
void _poison(int i, double a, double t, double life) {
  _fx =
      (_h1[i] - 0.5) * 0.9 * _r +
      sin(a * 6 + _h3[i] * 2 * pi) * 0.12 * _r * (0.3 + a);
  _fy = (_h2[i] - 0.3) * 0.6 * _r - _out(a) * 1.7 * _r;
}

/// Spirit: pale wisps winding up, each on its own slow curl.
void _spirit(int i, double a, double t, double life) {
  _fx =
      (_h1[i] - 0.5) * 0.9 * _r +
      sin(a * 4 + _h3[i] * 2 * pi + life * 1.2) * 0.3 * _r * (0.3 + a);
  _fy = (_h2[i] - 0.3) * 0.5 * _r - _out(a) * 2.1 * _r;
}

/// Dark pulls everything in: grains from far off, slow at first, spiralling
/// faster as they fall into the seam.
void _dark(int i, double a, double t, double life) {
  final th = _h1[i] * 2 * pi + (1 - a) * 1.9 + t * 0.5;
  final rad = 2.4 * _r * (0.12 + 0.88 * (1 - a * a)) * (0.8 + 0.3 * _h2[i]);
  _fx = cos(th) * rad;
  _fy = sin(th) * rad;
}

/// Light, and anything else: dawn — light spilling out in a few soft,
/// uneven beams that slowly turn, motes drifting along them.
void _light(int i, double a, double t, double life) {
  final beam = i % 7;
  final th =
      beam * 2 * pi / 7 +
      (_h1[beam + 60] - 0.5) * 0.7 +
      t * 0.3 +
      (_h2[i] - 0.5) * 0.32;
  final rad = (0.25 + (1.1 + 0.9 * _h3[beam + 60]) * _out(a)) * _r;
  _fx = cos(th) * rad;
  _fy = sin(th) * rad;
  _fGlow = 0.55 + 0.45 * _h4[beam + 60];
}

/// Blood: each heartbeat sends out a plume that billows, curls and thins,
/// like blood let into water.
void _blood(int i, double a, double t, double life) {
  final th = _h1[i] * 2 * pi + 0.9 * sin(a * 2.6 + _h3[i] * 2 * pi) * a;
  final rad = (0.2 + (0.9 + 0.8 * _h2[i]) * _out(a)) * _r;
  _fx = cos(th) * rad;
  _fy = sin(th) * rad + 0.25 * _r * a * a;
}
