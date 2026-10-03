// lib/games/cosmic/cosmic_cache_vfx.dart
//
// The artwork for sealed elemental caches: the dormant reliquary, and the
// three-second unsealing every element performs its own way — fire rises
// out of it, lava drips through, ice and crystal throw glass, dark pulls
// everything in.
//
// A cache is a reliquary of near-black glass, split down the middle by a
// seam of its element's light, with six shards of the seal circling it.
// Unsealing, the seal spins up and flies loose, the two halves part, and
// the element pours out of the seam as grains — each element's grains move
// their own way — before the light blooms. Material and grains only, in
// the language of the stations (obsidian_kit.dart): no stroked hoops or
// lines.
//
// Plain paint functions on purpose: the open-world game calls them from its
// render loop, and they can be exercised on any canvas without a game.

import 'dart:math';

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

final PointBatch _hot = PointBatch(260);
final PointBatch _dim = PointBatch(260);
final PointBatch _big = PointBatch(80);

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

  _dim.clear();
  for (var i = 0; i < 40; i++) {
    final ph = (life * (0.08 + 0.05 * hash01(i, 2)) + hash01(i, 3)) % 1.0;
    final a = hash01(i, 1) * 2 * pi + ph * 1.4;
    final r = _r * (1.5 - 1.2 * ph);
    _dim.add(p.dx + cos(a) * r, p.dy + sin(a) * r);
  }
  _dim.draw(canvas, 2, m.grainDim.withValues(alpha: 0.6));

  _halves(canvas, q, p, 0, 0);
  _seam(canvas, m, p, 2.6 + 1.6 * breathe, _r * 0.62, 0.8 + 0.2 * breathe);
  _sealShards(canvas, q, p, life * 0.25, _r * 1.02);
}

/// Paint the unsealing of an [element] cache centred on [p].
///
/// [life] is the cache's free-running clock (drives idle wobble); [t] is the
/// 0 → 1 progress through the three-second ritual.
void paintCacheUnseal(
  Canvas canvas,
  Offset p,
  String element,
  double life,
  double t,
) {
  final q = _reliquary(element);
  final m = q.m;
  // Overlapping phases: the seal is already cracking while the element is
  // still pouring in, and the bloom starts before the crack finishes.
  final charge = (t / 0.35).clamp(0.0, 1.0);
  final crack = ((t - 0.30) / 0.45).clamp(0.0, 1.0);
  final bloom = ((t - 0.70) / 0.30).clamp(0.0, 1.0);
  final part = Curves.easeOutCubic.transform(crack);
  final e = Curves.easeOutCubic.transform(bloom);
  final dark = element == 'Dark';

  // The element's light swelling under it, then flaring as it opens.
  paintDisc(canvas, m.pool, p, _r * (1.8 + 0.6 * charge + 1.6 * e), 1);
  paintDisc(
    canvas,
    m.leak,
    p,
    _r * (0.8 + 0.6 * charge + 0.8 * e),
    0.6 + 0.4 * charge - 0.6 * e,
  );

  // The halves part; the seal spins up and flies loose.
  _halves(canvas, q, p, 30 * part, 0.28 * part, 1 - e);
  _seam(
    canvas,
    m,
    p,
    3 + 7 * charge + 16 * part,
    _r * (0.62 + 0.2 * charge),
    dark ? 0.9 * (1 - part) : 1 - 0.6 * e,
  );
  _sealShards(
    canvas,
    q,
    p,
    life * 0.25 + 5 * t * t,
    _r * 1.02 + 120 * crack * crack,
    1 - crack,
  );

  // The element itself, poured out as grains.
  final energy = (t / 0.25).clamp(0.0, 1.0) * (1 - 0.7 * e);
  _motif(canvas, q, p, element, life, t, charge, crack, energy);

  // The bloom: light opening out of the seam — or, for Dark, a black that
  // swallows it.
  if (bloom > 0) {
    if (dark) {
      stonePaint
        ..shader = null
        ..color = const Color(0xFF050308).withValues(alpha: 1 - e * e);
      canvas.drawCircle(p, _r * (0.15 + 0.6 * e), stonePaint);
    } else {
      paintDisc(canvas, m.spark, p, _r * (0.35 + 1.1 * e), 1 - e);
    }
  }
}

// ── the elements ─────────────────────────────────────────

/// Each element's grains, moving their own way out of the seam. [energy]
/// is how much of the element is pouring (0..1).
void _motif(
  Canvas c,
  _Reliquary q,
  Offset p,
  String element,
  double life,
  double t,
  double charge,
  double crack,
  double energy,
) {
  if (energy <= 0.01) return;
  final m = q.m;
  _hot.clear();
  _dim.clear();
  _big.clear();
  const n = 160;
  final reach = 0.5 + 0.6 * charge + 1.2 * crack;

  void put(PointBatch b, double x, double y) => b.add(p.dx + x, p.dy + y);

  switch (element) {
    // Fire rises in tongues out of the seam.
    case 'Fire':
      for (var i = 0; i < n; i++) {
        final ph = (life * (0.9 + 0.5 * hash01(i, 2)) + hash01(i, 3)) % 1.0;
        final x =
            (hash01(i, 1) - 0.5) * _r * 0.9 * (1 - 0.6 * ph) +
            sin(life * 6 + i) * 3;
        final y = _r * 0.3 - ph * _r * 1.4 * reach;
        put(ph < 0.45 ? _hot : _dim, x, y);
      }
    // Lava drips heavy through the parting halves.
    case 'Lava':
      for (var i = 0; i < n; i++) {
        final ph = (life * (0.3 + 0.2 * hash01(i, 2)) + hash01(i, 3)) % 1.0;
        final x = (hash01(i, 1) - 0.5) * _r * (0.4 + 0.9 * crack);
        final y = -_r * 0.2 + ph * ph * _r * 1.5 * reach;
        put(i % 4 == 0 ? _big : (ph < 0.5 ? _hot : _dim), x, y);
      }
    // Lightning: bolts of grain that jump to new paths many times a second.
    case 'Lightning':
      final flick = (life * 9).floor();
      for (var i = 0; i < n; i++) {
        final bolt = i % 5;
        final s = (i ~/ 5) / (n / 5);
        final a = bolt * 2 * pi / 5 + hash01(flick * 7 + bolt, 4) * 1.2;
        final jag = (hash01(i + flick * 131, 5) - 0.5) * 16 * s;
        final r = s * _r * 1.3 * reach;
        put(
          s < 0.5 ? _hot : _dim,
          cos(a) * r - sin(a) * jag,
          sin(a) * r + cos(a) * jag,
        );
      }
    // Water turns in a whirlpool round the cache.
    case 'Water':
      for (var i = 0; i < n; i++) {
        final ph = (hash01(i, 1) + t * 1.2) % 1.0;
        final a = hash01(i, 2) * 2 * pi + ph * 5 + t * 6;
        final r = _r * (0.25 + 1.2 * ph) * reach;
        put(ph < 0.4 ? _hot : _dim, cos(a) * r, sin(a) * r);
      }
    // Ice throws slow shards of glass, and frost glitters where they were.
    case 'Ice':
      _shardsOut(c, q.crystal, p, 10, 0.4 + 1.5 * crack, 0.6, 1);
      for (var i = 0; i < n ~/ 2; i++) {
        final a = hash01(i, 1) * 2 * pi;
        final r = _r * (0.4 + 1.1 * hash01(i, 2)) * reach;
        final on = sin(life * 5 + i * 1.7) > 0.2;
        put(on ? _hot : _dim, cos(a) * r, sin(a) * r);
      }
    // Steam billows up and widens as it rises.
    case 'Steam':
      for (var i = 0; i < n; i++) {
        final ph = (life * (0.35 + 0.2 * hash01(i, 2)) + hash01(i, 3)) % 1.0;
        final x = (hash01(i, 1) - 0.5) * _r * (0.5 + 2 * ph) * reach;
        final y = -ph * _r * 1.6 * reach + _r * 0.2;
        put(i % 3 == 0 ? _big : _dim, x, y);
      }
    // Earth bursts into chips of stone that fall as they fly.
    case 'Earth':
      _shardsOut(
        c,
        q.shard,
        p,
        14,
        0.5 + 1.4 * crack,
        1.6,
        2.4,
        fall: 40 * crack * crack,
      );
      for (var i = 0; i < n ~/ 2; i++) {
        final a = hash01(i, 1) * 2 * pi;
        final r = _r * (0.3 + 1.2 * hash01(i, 2) * reach);
        put(_dim, cos(a) * r, sin(a) * r + 30 * crack * crack);
      }
    // Mud oozes down out of the seam in slow heavy drops.
    case 'Mud':
      for (var i = 0; i < n ~/ 2; i++) {
        final ph = (life * (0.15 + 0.1 * hash01(i, 2)) + hash01(i, 3)) % 1.0;
        final x = (hash01(i, 1) - 0.5) * _r * (0.5 + 0.9 * crack);
        final y = _r * 0.1 + ph * _r * 0.9 * reach;
        put(i.isEven ? _big : _dim, x, y);
      }
    // Dust: a wide cloud, swirling out.
    case 'Dust':
      for (var i = 0; i < n; i++) {
        final ph = (hash01(i, 1) + t * 0.6) % 1.0;
        final a = hash01(i, 2) * 2 * pi + t * 3 + ph * 2;
        final r = _r * (0.3 + 1.5 * ph) * reach;
        put(i % 5 == 0 ? _hot : _dim, cos(a) * r, sin(a) * r);
      }
    // Crystal grows out of it in long faceted points.
    case 'Crystal':
      _shardsOut(
        c,
        q.crystal,
        p,
        8,
        0.25 + 0.6 * crack,
        0,
        0.6 + charge,
        grow: true,
      );
      for (var i = 0; i < n ~/ 2; i++) {
        final a = hash01(i, 1) * 2 * pi;
        final r = _r * (0.3 + 1.3 * hash01(i, 2)) * reach;
        if (sin(life * 7 + i * 2.3) > 0.4) put(_hot, cos(a) * r, sin(a) * r);
      }
    // Air: gusts — streaks of grain racing round on three orbits.
    case 'Air':
      for (var i = 0; i < n; i++) {
        final ring = i % 3;
        final a = hash01(i, 1) * 1.8 + ring * 2.1 + t * (9 + ring * 2);
        final r =
            _r * (0.6 + 0.35 * ring + (hash01(i, 2) - 0.5) * 0.22) * reach;
        put(i % 6 == 0 ? _hot : _dim, cos(a) * r, sin(a) * r);
      }
    // Plant grows out in curling stems, leaves along them.
    case 'Plant':
      final grow = (0.3 * charge + 0.9 * crack).clamp(0.0, 1.0);
      for (var i = 0; i < n; i++) {
        final arm = i % 5;
        final s = hash01(i, 1);
        if (s > grow) continue;
        final a = arm * 2 * pi / 5 + s * 2.4 + 0.3;
        final r = s * _r * 1.8;
        final side = (hash01(i, 2) - 0.5) * 9 * (0.4 + s);
        put(
          i % 7 == 0 ? _big : (s > grow - 0.1 ? _hot : _dim),
          cos(a) * r - sin(a) * side,
          sin(a) * r + cos(a) * side,
        );
      }
    // Poison: bubbles rising and popping.
    case 'Poison':
      for (var i = 0; i < n ~/ 2; i++) {
        final ph = (life * (0.4 + 0.3 * hash01(i, 2)) + hash01(i, 3)) % 1.0;
        if (ph > 0.85) continue;
        final x = (hash01(i, 1) - 0.5) * _r * 1.2 + sin(ph * 6 + i) * 6;
        final y = _r * 0.3 - ph * _r * 1.6 * reach;
        put(ph > 0.7 ? _hot : _big, x, y);
      }
    // Spirit: pale wisps winding up in slow columns.
    case 'Spirit':
      for (var i = 0; i < n; i++) {
        final col = i % 5;
        final ph = (life * 0.25 + hash01(i, 3)) % 1.0;
        final x = (col - 2) * _r * 0.32 + sin(ph * 7 + col * 1.3) * 12;
        final y = _r * 0.4 - ph * _r * 1.9 * reach;
        put(ph < 0.5 ? _hot : _dim, x, y);
      }
    // Dark pulls everything in: grains fall from far off into the seam.
    case 'Dark':
      for (var i = 0; i < n; i++) {
        final ph = (hash01(i, 1) + t * 1.4) % 1.0;
        final a = hash01(i, 2) * 2 * pi + ph * 2.2;
        final r = _r * 2.3 * (1 - ph);
        put(ph > 0.7 ? _hot : _dim, cos(a) * r, sin(a) * r);
      }
    // Blood beats: the grains swell outward with each pulse.
    case 'Blood':
      final beat = pow(0.5 + 0.5 * sin(t * 26), 6).toDouble();
      for (var i = 0; i < n; i++) {
        final a = hash01(i, 1) * 2 * pi + t * 2;
        final r = _r * (0.4 + 0.8 * hash01(i, 2)) * (1 + 0.4 * beat) * reach;
        put(hash01(i, 2) < 0.3 ? _hot : _dim, cos(a) * r, sin(a) * r);
      }
    // Light, and anything else: straight rays of grain.
    default:
      for (var i = 0; i < n; i++) {
        final ray = i % 12;
        final s = ((i ~/ 12) / (n / 12) + t * 1.5) % 1.0;
        final a = ray * pi / 6 + t * 0.4;
        final r = _r * (0.3 + s * 1.8 * reach);
        put(s < 0.4 ? _hot : _dim, cos(a) * r, sin(a) * r);
      }
  }

  _dim.draw(c, 2.2, m.grainDim.withValues(alpha: 0.85 * energy));
  _big.draw(c, 4.2, m.grainHot.withValues(alpha: 0.75 * energy));
  _hot.draw(c, 2.6, m.grainHot.withValues(alpha: energy));
}

/// [count] pieces of glass thrown out round the cache to [reach] radii,
/// each turned by [twist] and sized by [scale]. [grow] means [scale] is
/// their growth from nothing; [fall] drops them as they go.
void _shardsOut(
  Canvas c,
  BakedArt piece,
  Offset p,
  int count,
  double reach,
  double twist,
  double scale, {
  bool grow = false,
  double fall = 0,
}) {
  for (var i = 0; i < count; i++) {
    final a = i * 2 * pi / count + hash01(i, 9) * 0.4;
    final r = _r * reach * (0.8 + 0.4 * hash01(i, 10));
    c.save();
    c.translate(p.dx + cos(a) * r, p.dy + sin(a) * r + fall);
    c.rotate(a + twist * (hash01(i, 11) - 0.5));
    c.scale(grow ? scale : 1.2 * scale);
    piece.draw(c);
    c.restore();
  }
}
