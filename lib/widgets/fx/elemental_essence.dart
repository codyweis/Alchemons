// lib/widgets/fx/elemental_essence.dart
//
// A SPECIMEN COMING APART INTO ITS ELEMENT — and back.
//
//   Tap an Alchemon on its details and it is read into grains of itself
//   (see [SpecimenGrains]): at rest they ARE the sprite. Then they come
//   loose, heat into its element's colours, and do what that element does —
//   a Fire one burns up into a flame, an Earth one crumbles to a heap at its
//   feet, a Dark one spirals into a point, a Crystal one cracks into facets —
//   and gather back into it, feet first, crown last.
//
//   The grains keep the creature's own shading as they turn: each takes the
//   element shade of its own brightness, so for a moment it is the creature
//   drawn in fire, or water, or light.
//
// Plain Dart and time-driven, like the fusion's merge: [ElementalEssence]
// captures the sprite and steps [EssenceField] with one controller, and a
// test can scrub it. Points in batches, no blur, and nothing at all while it
// is not playing.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// The seventeen elements, each with its own way of coming apart.
enum EssenceElement {
  fire,
  water,
  earth,
  air,
  steam,
  lava,
  lightning,
  mud,
  ice,
  dust,
  crystal,
  plant,
  poison,
  spirit,
  dark,
  light,
  blood;

  /// From a creature type name ('Fire', 'lava'…). Unknown types come apart
  /// as spirit: the least particular of them.
  static EssenceElement of(String? type) {
    final t = type?.toLowerCase();
    for (final e in values) {
      if (e.name == t) return e;
    }
    return spirit;
  }
}

/// How an element looks as grains.
class _Look {
  const _Look(
    this.ramp, {
    required this.pool,
    this.poolAlpha = 0.1,
    this.glow = 0.035,
    this.size = 1.0,
    this.alpha = 1.0,
    this.twinkle = 0.006,
    this.sparkEvery = 0,
  });

  /// Shadow, body, lit, glint: the element shades are spread across these.
  final List<Color> ramp;

  /// The light the creature gives off while it is its element: a soft pool,
  /// never a ring.
  final Color pool;
  final double poolAlpha;

  /// The soft halo under every third grain.
  final double glow;

  /// Grain size and opacity, against the creature's own.
  final double size, alpha;

  /// How often a grain catches the light.
  final double twinkle;

  /// One grain in this many also throws a spark (0: none).
  final int sparkEvery;
}

const Map<EssenceElement, _Look> _looks = {
  EssenceElement.fire: _Look(
    [
      Color(0xFF5A1405),
      Color(0xFFB8300A),
      Color(0xFFEE7A12),
      Color(0xFFFFD27A),
    ],
    pool: Color(0xFFFF7A1A),
    poolAlpha: 0.24,
    glow: 0.075,
    twinkle: 0.0,
    sparkEvery: 7,
  ),
  EssenceElement.water: _Look(
    [
      Color(0xFF0B2A4A),
      Color(0xFF1D6FA3),
      Color(0xFF4FB3E8),
      Color(0xFFD6F3FF),
    ],
    pool: Color(0xFF2E8BD0),
    poolAlpha: 0.12,
    glow: 0.04,
    twinkle: 0.01,
    sparkEvery: 11,
  ),
  EssenceElement.earth: _Look(
    [
      Color(0xFF2E1C10),
      Color(0xFF6E4626),
      Color(0xFFA9794A),
      Color(0xFFE3C9A0),
    ],
    pool: Color(0xFFB07A44),
    poolAlpha: 0.06,
    glow: 0.0,
    twinkle: 0.0,
  ),
  EssenceElement.air: _Look(
    [
      Color(0xFF3D5A66),
      Color(0xFF86AEBB),
      Color(0xFFC9E6EC),
      Color(0xFFFFFFFF),
    ],
    pool: Color(0xFFA8E3F0),
    poolAlpha: 0.08,
    glow: 0.035,
    alpha: 0.85,
    twinkle: 0.004,
    sparkEvery: 8,
  ),
  EssenceElement.steam: _Look(
    [
      Color(0xFF4A5560),
      Color(0xFF8A97A6),
      Color(0xFFC8D0DA),
      Color(0xFFF6E9EE),
    ],
    pool: Color(0xFFC9D3E0),
    poolAlpha: 0.1,
    glow: 0.06,
    size: 1.35,
    alpha: 0.7,
    twinkle: 0.0,
  ),
  EssenceElement.lava: _Look(
    [
      Color(0xFF240805),
      Color(0xFF7A1A0B),
      Color(0xFFF0570E),
      Color(0xFFFFC56B),
    ],
    pool: Color(0xFFFF5A12),
    poolAlpha: 0.26,
    glow: 0.07,
    size: 1.1,
    twinkle: 0.0,
  ),
  EssenceElement.lightning: _Look(
    [
      Color(0xFF3A3210),
      Color(0xFFB89A1E),
      Color(0xFFF7DC4A),
      Color(0xFFFFFBD8),
    ],
    pool: Color(0xFFFFE45C),
    poolAlpha: 0.2,
    glow: 0.07,
    size: 0.85,
    twinkle: 0.0,
    sparkEvery: 5,
  ),
  EssenceElement.mud: _Look(
    [
      Color(0xFF241810),
      Color(0xFF4F3828),
      Color(0xFF85664E),
      Color(0xFFC2A486),
    ],
    pool: Color(0xFF8D6E55),
    poolAlpha: 0.05,
    glow: 0.0,
    size: 1.1,
    twinkle: 0.004,
  ),
  EssenceElement.ice: _Look(
    [
      Color(0xFF1E3A56),
      Color(0xFF6FA8D6),
      Color(0xFFB9E2F7),
      Color(0xFFF2FCFF),
    ],
    pool: Color(0xFF9FD8F5),
    poolAlpha: 0.12,
    glow: 0.045,
    twinkle: 0.02,
  ),
  EssenceElement.dust: _Look(
    [
      Color(0xFF5A4A36),
      Color(0xFF9C8A6C),
      Color(0xFFD2C2A2),
      Color(0xFFF3EBDA),
    ],
    pool: Color(0xFFD6C6AC),
    poolAlpha: 0.05,
    glow: 0.0,
    size: 0.9,
    alpha: 0.9,
    twinkle: 0.0,
  ),
  EssenceElement.crystal: _Look(
    [
      Color(0xFF3A2E6E),
      Color(0xFF8673D6),
      Color(0xFFC9B8FF),
      Color(0xFFF5F0FF),
    ],
    pool: Color(0xFFB6A6FF),
    poolAlpha: 0.14,
    glow: 0.04,
    twinkle: 0.02,
  ),
  EssenceElement.plant: _Look(
    [
      Color(0xFF173A1E),
      Color(0xFF3F8A47),
      Color(0xFF86CF7E),
      Color(0xFFE2F7B5),
    ],
    pool: Color(0xFF7FD08A),
    poolAlpha: 0.1,
    glow: 0.035,
    twinkle: 0.004,
    sparkEvery: 10,
  ),
  EssenceElement.poison: _Look(
    [
      Color(0xFF241046),
      Color(0xFF5B2FA8),
      Color(0xFF3FC48A),
      Color(0xFFC6F6D5),
    ],
    pool: Color(0xFF4ADE80),
    poolAlpha: 0.12,
    glow: 0.045,
    twinkle: 0.0,
  ),
  EssenceElement.spirit: _Look(
    [
      Color(0xFF3A2E5C),
      Color(0xFF8C7CC8),
      Color(0xFFD6CCFF),
      Color(0xFFFFFFFF),
    ],
    pool: Color(0xFFD9CCFF),
    poolAlpha: 0.14,
    glow: 0.06,
    size: 1.1,
    alpha: 0.72,
    twinkle: 0.012,
  ),
  EssenceElement.dark: _Look(
    [
      Color(0xFF07050C),
      Color(0xFF241B3A),
      Color(0xFF55408A),
      Color(0xFFA68BEB),
    ],
    pool: Color(0xFF000000),
    poolAlpha: 0.6,
    glow: 0.04,
    twinkle: 0.008,
  ),
  EssenceElement.light: _Look(
    [
      Color(0xFF7A5E22),
      Color(0xFFD4AA42),
      Color(0xFFFFE89A),
      Color(0xFFFFFFF4),
    ],
    pool: Color(0xFFFFE08A),
    poolAlpha: 0.3,
    glow: 0.07,
    twinkle: 0.04,
    sparkEvery: 8,
  ),
  EssenceElement.blood: _Look(
    [
      Color(0xFF3A0609),
      Color(0xFF961420),
      Color(0xFFDC2F3A),
      Color(0xFFFFA3A3),
    ],
    pool: Color(0xFFD01E2A),
    poolAlpha: 0.16,
    glow: 0.05,
    twinkle: 0.0,
  ),
};

/// An element's grain shades — shadow, body, lit, glint — for painters that
/// draw it smaller than a whole specimen (the Elemental Aura).
List<Color> essenceRamp(EssenceElement e) => _looks[e]!.ramp;

/// The light an element pools on the ground.
Color essencePool(EssenceElement e) => _looks[e]!.pool;

/// When an element lets go and gathers back, in seconds.
class _Timing {
  const _Timing({
    this.relSpan = 0.42,
    this.relJit = 0.06,
    this.inDur = 0.4,
    this.retStart = 1.45,
    this.retSpan = 0.3,
    this.outDur = 0.5,
    this.swirl = 0.6,
  });

  /// Grains let go over [relSpan] (in the element's own order), each a
  /// little early or late by up to [relJit], and ease into the form over
  /// [inDur].
  final double relSpan, relJit, inDur;

  /// They start home from [retStart] over [retSpan] and take [outDur].
  final double retStart, retSpan, outDur;
  double get retJit => 0.05;

  /// How far the way home turns, in radians at its start: in along a swirl,
  /// not a straight line, which reads as a slide.
  final double swirl;
}

const _Timing _defaultTiming = _Timing();
const Map<EssenceElement, _Timing> _timings = {
  EssenceElement.earth: _Timing(
    inDur: 0.1,
    retStart: 1.4,
    retSpan: 0.4,
    swirl: 0.3,
  ),
  EssenceElement.lightning: _Timing(
    relSpan: 0.1,
    relJit: 0.03,
    inDur: 0.06,
    retStart: 1.55,
    retSpan: 0.22,
    outDur: 0.42,
    swirl: 0,
  ),
  EssenceElement.crystal: _Timing(
    relSpan: 0.06,
    relJit: 0.04,
    inDur: 0.05,
    retStart: 1.6,
    retSpan: 0.18,
    outDur: 0.42,
    swirl: 0,
  ),
  EssenceElement.dust: _Timing(swirl: 0.15),
  EssenceElement.mud: _Timing(swirl: 0.2),
  EssenceElement.dark: _Timing(retSpan: 0.18, outDur: 0.55, swirl: -1.1),
  EssenceElement.light: _Timing(swirl: 0.25),
  EssenceElement.blood: _Timing(swirl: 0.3),
};

/// A specimen as grains, coming apart into its element and back.
///
/// The timeline, in seconds ([duration] in all):
///  * 0 – 0.12     the sprite gives way to its grains, which are it
///  * 0.02 – 0.5   they let go in the element's order (Fire from its feet,
///                 Earth from its crown, Dark from its edges…), heating into
///                 the element's shades as they go
///  * to ~1.5      the element's form: the flame, the heap, the void
///  * 1.45 – 2.3   home again along a swirl, feet first, cooling to its own
///                 colours as each lands
///  * 2.28 – 2.6   the sprite comes back under them and they go out
class EssenceField {
  EssenceField(this.grains, this.element)
    : _look = _looks[element]!,
      _time = _timings[element] ?? _defaultTiming {
    _seed();
  }

  final SpecimenGrains grains;
  final EssenceElement element;
  final _Look _look;
  final _Timing _time;

  static const double duration = 2.6;

  /// Where a reveal starts playing: the element's form is up, and from here
  /// it gathers into the creature. See [ElementalEssence.reveal].
  static const double revealStart = 1.05;

  /// Set when this field plays only as a reveal: the grains fade in at
  /// [revealStart] instead of coming out of a sprite that was never shown.
  bool reveal = false;

  /// The sprite under the grains: gone while they are loose, back as they
  /// land, so the change between the two never shows.
  static double spriteOpacity(double t) =>
      (1 - _smooth(0.0, 0.12, t) + _smooth(duration - 0.32, duration - 0.1, t))
          .clamp(0.0, 1.0);

  // The body, from its grains' centroid.
  late double _cx, _cy, _reach, _top, _bot, _halfW;

  // Per grain: home relative to the centroid, height (0 crown..1 feet),
  // distance (0..1 of reach) and angle from the centroid, three dice, when
  // it lets go and when it starts home, and its element shade at rest.
  late final Float32List _x0, _y0, _u, _d, _a, _p1, _p2, _p3;
  late final Float32List _rel, _ret, _shade;

  // Element extras: Earth's landing place and fall time, Ice's lattice
  // snap, chunk membership (Crystal's facets, Poison's bubbles).
  Float32List? _ex, _ey, _ez;
  Uint8List? _chunk, _edge;
  Float32List? _cDirX, _cDirY, _cDist, _cRot, _cRand, _cRelX, _cRelY;

  int get length => grains.length;

  static double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

  static double _smooth(double e0, double e1, double x) {
    final t = _clamp01((x - e0) / (e1 - e0));
    return t * t * (3 - 2 * t);
  }

  static double _ramp(double tau, double dur) {
    final t = _clamp01(tau / dur);
    return t * t * (3 - 2 * t);
  }

  static double _easeOut(double x) {
    final y = 1 - x;
    return 1 - y * y * y;
  }

  static double _easeInOut(double x) =>
      x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

  /// Cheap per-grain dice for a moment [k]: the same grain and moment
  /// always roll the same, so a held frame does not shimmer.
  static double _hash(int a, int k) {
    var x = (a * 0x27d4eb2d) ^ (k * 0x165667b1);
    x &= 0xffffffff;
    x = ((x ^ (x >> 15)) * 0x85ebca6b) & 0xffffffff;
    x ^= x >> 13;
    return (x & 0xffffff) / 0x1000000;
  }

  void _seed() {
    final g = grains;
    final n = g.length;
    _x0 = Float32List(n);
    _y0 = Float32List(n);
    _u = Float32List(n);
    _d = Float32List(n);
    _a = Float32List(n);
    _p1 = Float32List(n);
    _p2 = Float32List(n);
    _p3 = Float32List(n);
    _rel = Float32List(n);
    _ret = Float32List(n);
    _shade = Float32List(n);

    var sx = 0.0, sy = 0.0;
    var top = double.infinity, bot = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      sx += g.hx[i];
      sy += g.hy[i];
      top = math.min(top, g.hy[i]);
      bot = math.max(bot, g.hy[i]);
    }
    if (n == 0) top = bot = 0;
    _cx = n == 0 ? 0 : sx / n;
    _cy = n == 0 ? 0 : sy / n;
    _top = top;
    _bot = bot;
    var reach = 1.0, halfW = 1.0;
    for (var i = 0; i < n; i++) {
      final dx = g.hx[i] - _cx, dy = g.hy[i] - _cy;
      reach = math.max(reach, math.sqrt(dx * dx + dy * dy));
      halfW = math.max(halfW, dx.abs());
    }
    _reach = reach;
    _halfW = halfW;
    final span = math.max(1.0, bot - top);
    final tones = math.max(1, g.tones.length - 1);
    final rng = math.Random(23);

    for (var i = 0; i < n; i++) {
      final x0 = g.hx[i] - _cx, y0 = g.hy[i] - _cy;
      _x0[i] = x0;
      _y0[i] = y0;
      _u[i] = _clamp01((g.hy[i] - top) / span);
      _d[i] = math.sqrt(x0 * x0 + y0 * y0) / reach;
      _a[i] = math.atan2(y0, x0);
      _p1[i] = rng.nextDouble();
      _p2[i] = rng.nextDouble();
      _p3[i] = rng.nextDouble();
      // Its own brightness, as an element shade.
      _shade[i] = g.tone[i] / tones * (_shadeCount - 1);
    }

    final t = _time;
    for (var i = 0; i < n; i++) {
      _rel[i] = 0.02 + t.relSpan * _releaseKey(i) + t.relJit * _p3[i];
      _ret[i] = t.retStart + t.retSpan * _returnKey(i) + t.retJit * _p2[i];
    }

    switch (element) {
      case EssenceElement.earth:
        _seedHeap();
      case EssenceElement.ice:
        _seedLattice();
      case EssenceElement.plant:
        _seedVines();
      case EssenceElement.crystal:
        _seedChunks(9, 0x2f);
      case EssenceElement.poison:
        _seedChunks(15, 0x51);
      default:
        break;
    }
  }

  /// 0..1: the order the element lets go in.
  double _releaseKey(int i) {
    final u = _u[i], d = _d[i];
    switch (element) {
      // Burns, freezes, grows and bubbles from the feet up.
      case EssenceElement.fire:
      case EssenceElement.ice:
      case EssenceElement.poison:
      case EssenceElement.air:
        return 1 - u;
      // Crumbles, melts and lifts away from the crown down.
      case EssenceElement.earth:
      case EssenceElement.steam:
      case EssenceElement.lava:
      case EssenceElement.mud:
      case EssenceElement.water:
      case EssenceElement.spirit:
        return u;
      // Struck from above, all but at once.
      case EssenceElement.lightning:
        return u * 0.6 + _p1[i] * 0.4;
      case EssenceElement.crystal:
        return _p1[i];
      // Blown from the windward side.
      case EssenceElement.dust:
        return _clamp01((_x0[i] + _halfW) / (2 * _halfW));
      // Swallowed from the edges in.
      case EssenceElement.dark:
        return 1 - d;
      // From the heart out.
      case EssenceElement.plant:
      case EssenceElement.light:
      case EssenceElement.blood:
        return d;
    }
  }

  /// 0..1: the order it gathers back in. Feet first, crown last, unless the
  /// element has a better one.
  double _returnKey(int i) {
    switch (element) {
      case EssenceElement.dust:
        return _clamp01((_x0[i] + _halfW) / (2 * _halfW));
      case EssenceElement.dark:
        return _p1[i];
      case EssenceElement.lightning:
      case EssenceElement.crystal:
        return _p2[i];
      case EssenceElement.light:
        return 1 - _d[i];
      default:
        return 1 - _u[i];
    }
  }

  // Earth: where each grain lands in the heap at its feet, and how long it
  // falls.
  static const double _gravity = 1500;

  void _seedHeap() {
    final n = length;
    final ex = _ex = Float32List(n);
    final ey = _ey = Float32List(n);
    final ez = _ez = Float32List(n);
    final h = _bot - _top;
    for (var i = 0; i < n; i++) {
      final hy = grains.hy[i];
      final xl = _x0[i] * 1.3 + (_p2[i] - 0.5) * _halfW * 0.35;
      final w = xl / (_halfW * 1.55);
      final heap = h * 0.32 * _clamp01(1 - w * w) * (0.25 + 0.75 * _p1[i]);
      var yl = _bot - heap;
      // Already in the heap's height: it settles a little, no more.
      if (yl < hy) yl = hy + (_bot - hy) * 0.3;
      ex[i] = xl - _x0[i];
      ey[i] = yl - hy;
      ez[i] = math.sqrt(2 * math.max(0.0, ey[i]) / _gravity);
    }
  }

  // Ice: the snap of each grain onto a frost lattice.
  void _seedLattice() {
    final n = length;
    final ex = _ex = Float32List(n);
    final ey = _ey = Float32List(n);
    final q = math.max(4.0, grains.step * 2.6);
    final rowH = q * 0.866;
    for (var i = 0; i < n; i++) {
      final hx = grains.hx[i], hy = grains.hy[i];
      final row = (hy / rowH).round();
      final off = row.isOdd ? q / 2 : 0.0;
      final col = ((hx - off) / q).round();
      ex[i] = col * q + off - hx;
      ey[i] = row * rowH - hy;
    }
  }

  // Plant: the body sprouts into curling stems with leaves. Each grain is
  // given a seat on one: a stem, how far up it (0 base..1 tip), and where
  // it sits off the stem there, in the stem's own frame (along, across) —
  // so the seats follow the stems when they sway.
  static const int _stemPts = 28;
  int _stems = 0;
  Float32List? _stemX0, _stemY0, _stemX, _stemY, _stemTx, _stemTy;
  double _stemsAt = double.nan;

  void _seedVines() {
    final n = length;
    if (n == 0) return;
    final rng = math.Random(0x7a);
    final r = _reach;
    final stems = _stems = n > 700 ? 4 : 3;
    const m = _stemPts;
    final sx = _stemX0 = Float32List(stems * m);
    final sy = _stemY0 = Float32List(stems * m);
    _stemX = Float32List(stems * m);
    _stemY = Float32List(stems * m);
    _stemTx = Float32List(stems * m);
    _stemTy = Float32List(stems * m);
    final lean = stems == 4
        ? const [-0.78, -0.24, 0.3, 0.8]
        : const [-0.62, 0.05, 0.66];
    final lengths = Float64List(stems);
    for (var k = 0; k < stems; k++) {
      final side = lean[k] >= 0 ? 1.0 : -1.0;
      final len = r * (1.25 - 0.3 * lean[k].abs() + 0.2 * rng.nextDouble());
      lengths[k] = len;
      var x = lean[k] * _halfW * 0.22, y = _bot - _cy;
      var h = -math.pi / 2 + lean[k] + (rng.nextDouble() - 0.5) * 0.12;
      final ds = len / (m - 1);
      for (var j = 0; j < m; j++) {
        sx[k * m + j] = x;
        sy[k * m + j] = y;
        final s = j / (m - 1);
        // Leaning out as it grows, and the tip curled back in on itself:
        // a fiddlehead.
        h += side * 0.45 / (m - 1) - side * 7.5 * _smooth(0.58, 1, s) / (m - 1);
        x += math.cos(h) * ds;
        y += math.sin(h) * ds;
      }
    }

    // The seats: a third along the stems, the rest in their leaves.
    final seatK = Uint8List(n);
    final seatS = Float32List(n),
        seatA = Float32List(n),
        seatB = Float32List(n);
    final seatShade = Float32List(n);
    var totalLen = 0.0;
    for (final l in lengths) {
      totalLen += l;
    }
    final stemSeats = (n * 0.3).round();
    const leafAt = [0.24, 0.4, 0.55, 0.7];
    final leaves = stems * leafAt.length;
    var q = 0;
    final unit = r / 80;
    for (var k = 0; k < stems && q < stemSeats; k++) {
      final c = k == stems - 1
          ? stemSeats - q
          : (stemSeats * lengths[k] / totalLen).round();
      for (var j = 0; j < c && q < stemSeats; j++, q++) {
        final s = (j + rng.nextDouble()) / c;
        final thick = (2.8 - 1.9 * s) * unit;
        seatK[q] = k;
        seatS[q] = s;
        seatA[q] = 0;
        seatB[q] = (rng.nextDouble() - 0.5) * 2 * thick;
        seatShade[q] = 1.2 + 2.2 * s + (s > 0.8 ? 1.5 : 0);
      }
    }
    final perLeaf = math.max(1, (n - q) ~/ leaves);
    for (var lf = 0; lf < leaves && q < n; lf++) {
      final k = lf % stems;
      final li = lf ~/ stems;
      final s0 = leafAt[li];
      final side = (li + k).isEven ? 1.0 : -1.0;
      final len = r * 0.36 * (1 - 0.3 * s0) * (0.85 + 0.3 * rng.nextDouble());
      final wid = len * 0.34;
      const phi = 0.8;
      final lx = math.cos(phi), ly = side * math.sin(phi);
      final c = lf == leaves - 1 ? n - q : perLeaf;
      for (var j = 0; j < c && q < n; j++, q++) {
        final al = math.sqrt(rng.nextDouble());
        final across = (rng.nextDouble() - 0.5) * 2;
        final w = wid * math.sin(math.pi * math.pow(al, 0.75));
        final b = across * w;
        seatK[q] = k;
        seatS[q] = s0;
        // Along the leaf's axis, and across it.
        seatA[q] = al * len * lx - b * ly;
        seatB[q] = al * len * ly + b * lx;
        seatShade[q] =
            2.2 +
            2.6 * al +
            (across.abs() < 0.18 ? 1.4 : 0) -
            0.8 * across.abs();
      }
    }

    // Grains to seats: in bands from the feet up (grains) and the stems'
    // bases out (seats), left to right within each band, so a grain goes
    // somewhere near it and the stems grow from where it stands.
    final grainOrder = List<int>.generate(n, (i) => i)
      ..sort((a, b) => _u[b].compareTo(_u[a]));
    final seatOrder = List<int>.generate(n, (i) => i)
      ..sort((a, b) => seatS[a].compareTo(seatS[b]));
    double seatX(int s) {
      final k = seatK[s];
      final j = (seatS[s] * (m - 1)).round().clamp(0, m - 1);
      return sx[k * m + j] + seatA[s];
    }

    const bands = 10;
    final ex = _ex = Float32List(n);
    final ey = _ey = Float32List(n);
    final ez = _ez = Float32List(n);
    final chunk = _chunk = Uint8List(n);
    for (var bnd = 0; bnd < bands; bnd++) {
      final lo = n * bnd ~/ bands, hi = n * (bnd + 1) ~/ bands;
      final gs = grainOrder.sublist(lo, hi)
        ..sort((a, b) => _x0[a].compareTo(_x0[b]));
      final ss = seatOrder.sublist(lo, hi)
        ..sort((a, b) => seatX(a).compareTo(seatX(b)));
      for (var j = 0; j < gs.length; j++) {
        final i = gs[j], st = ss[j];
        chunk[i] = seatK[st];
        ez[i] = seatS[st];
        ex[i] = seatA[st];
        ey[i] = seatB[st];
        _shade[i] = seatShade[st].clamp(0, _shadeCount - 1).toDouble();
      }
    }
    // It grows: base first out, tips first home.
    final t = _time;
    for (var i = 0; i < n; i++) {
      _rel[i] = 0.02 + t.relSpan * 1.25 * ez[i] + t.relJit * _p3[i];
      _ret[i] = t.retStart + t.retSpan * (1 - ez[i]) + t.retJit * _p2[i];
    }
  }

  /// The stems at [t]: swaying, bending more toward the tips.
  void _layStems(double t) {
    if (t == _stemsAt) return;
    _stemsAt = t;
    const m = _stemPts;
    final x0 = _stemX0!, y0 = _stemY0!;
    final x = _stemX!, y = _stemY!, tx = _stemTx!, ty = _stemTy!;
    final grow = _smooth(0.2, 0.9, t);
    for (var k = 0; k < _stems; k++) {
      final bx = x0[k * m], by = y0[k * m];
      final sway = (0.13 * math.sin(t * 1.9 + k * 1.3) + 0.05) * grow;
      for (var j = 0; j < m; j++) {
        final s = j / (m - 1);
        final a = sway * s * s;
        final cs = math.cos(a), sn = math.sin(a);
        final dx = x0[k * m + j] - bx, dy = y0[k * m + j] - by;
        x[k * m + j] = bx + dx * cs - dy * sn;
        y[k * m + j] = by + dx * sn + dy * cs;
      }
      for (var j = 0; j < m; j++) {
        final a = math.max(0, j - 1), b = math.min(m - 1, j + 1);
        var dx = x[k * m + b] - x[k * m + a];
        var dy = y[k * m + b] - y[k * m + a];
        final l = math.sqrt(dx * dx + dy * dy);
        if (l > 0) {
          dx /= l;
          dy /= l;
        }
        tx[k * m + j] = dx;
        ty[k * m + j] = dy;
      }
    }
  }

  // Crystal facets and Poison bubbles: the body split into [k] chunks round
  // seeds spread farthest-first, so every chunk is a fair size.
  void _seedChunks(int k, int seed) {
    final n = length;
    if (n == 0) return;
    k = math.min(k, n);
    final rng = math.Random(seed);
    final sxs = Float32List(k), sys = Float32List(k);
    final minD = Float32List(n)..fillRange(0, n, double.infinity);
    var pick = rng.nextInt(n);
    for (var c = 0; c < k; c++) {
      sxs[c] = _x0[pick];
      sys[c] = _y0[pick];
      var far = 0;
      var farD = -1.0;
      for (var i = 0; i < n; i++) {
        final dx = _x0[i] - sxs[c], dy = _y0[i] - sys[c];
        final dd = dx * dx + dy * dy;
        if (dd < minD[i]) minD[i] = dd;
        if (minD[i] > farD) {
          farD = minD[i];
          far = i;
        }
      }
      pick = far;
    }
    final chunk = _chunk = Uint8List(n);
    final edge = _edge = Uint8List(n);
    final ccx = Float64List(k), ccy = Float64List(k);
    final cn = Int32List(k);
    final edgeGap = grains.step * 1.6;
    for (var i = 0; i < n; i++) {
      var best = 0, second = 0;
      var bd = double.infinity, sd = double.infinity;
      for (var c = 0; c < k; c++) {
        final dx = _x0[i] - sxs[c], dy = _y0[i] - sys[c];
        final dd = math.sqrt(dx * dx + dy * dy);
        if (dd < bd) {
          sd = bd;
          second = best;
          bd = dd;
          best = c;
        } else if (dd < sd) {
          sd = dd;
          second = c;
        }
      }
      chunk[i] = best;
      edge[i] = (sd - bd < edgeGap && second != best) ? 1 : 0;
      ccx[best] += _x0[i];
      ccy[best] += _y0[i];
      cn[best]++;
    }
    final dirX = _cDirX = Float32List(k);
    final dirY = _cDirY = Float32List(k);
    final dist = _cDist = Float32List(k);
    final rot = _cRot = Float32List(k);
    final rand = _cRand = Float32List(k);
    for (var c = 0; c < k; c++) {
      if (cn[c] > 0) {
        ccx[c] /= cn[c];
        ccy[c] /= cn[c];
      }
      final l = math.sqrt(ccx[c] * ccx[c] + ccy[c] * ccy[c]);
      final a = l < 1 ? rng.nextDouble() * math.pi * 2 : 0.0;
      dirX[c] = l < 1 ? math.cos(a) : ccx[c] / l;
      dirY[c] = l < 1 ? math.sin(a) : ccy[c] / l;
      rand[c] = rng.nextDouble();
      dist[c] = _reach * (0.14 + 0.12 * rand[c]);
      rot[c] = (rng.nextBool() ? 1 : -1) * (0.18 + 0.26 * rng.nextDouble());
    }
    final rx = _cRelX = Float32List(n);
    final ry = _cRelY = Float32List(n);
    // A bubble's size, for its skin.
    final cr = Float64List(k);
    for (var i = 0; i < n; i++) {
      final c = chunk[i];
      rx[i] = _x0[i] - ccx[c];
      ry[i] = _y0[i] - ccy[c];
      cr[c] = math.max(cr[c], math.sqrt(rx[i] * rx[i] + ry[i] * ry[i]));
    }
    if (element == EssenceElement.poison) {
      // Poison wants the skin, not the cracks: the outer ring of a bubble.
      for (var i = 0; i < n; i++) {
        final c = chunk[i];
        final r = math.sqrt(rx[i] * rx[i] + ry[i] * ry[i]);
        edge[i] = cr[c] > 0 && r / cr[c] > 0.78 ? 1 : 0;
      }
    }
  }

  // ── the forms ─────────────────────────────────────────────────────────

  // The form writes these: the grain's offset from home at full strength,
  // its shade shift, and a glint flag. Fields, not a record, so a frame of
  // two thousand grains allocates nothing.
  double _fx = 0, _fy = 0, _shift = 0;
  bool _glint = false;

  void _form(int i, double tau) {
    final x0 = _x0[i], y0 = _y0[i], u = _u[i];
    final p1 = _p1[i], p2 = _p2[i], p3 = _p3[i];
    final r = _reach;
    _shift = 0;
    _glint = false;
    switch (element) {
      case EssenceElement.fire:
        // Up into a flame: the higher it was the further it goes, pulled
        // in to a tip, with tongues licking sideways; white-hot at the
        // base, red at the tips.
        final k = _ramp(tau, 0.8);
        final up = 1 - u;
        final lift =
            r * (0.1 + 0.5 * up * up) * (0.75 + 0.5 * p1) * k + r * 0.07 * tau;
        _fx =
            -x0 * 0.6 * up * k +
            math.sin(tau * 8 + y0 * 0.08 + p2 * 1.5) *
                r *
                0.1 *
                k *
                (0.3 + 0.7 * up);
        _fy = -lift + math.sin(tau * 11 + p1 * 6.28) * r * 0.015;
        _shift = (u * 5.5 - 3.4) * k;
        if (_hash(i, (tau * 12).floor()) > 0.94) _shift += 3;

      case EssenceElement.water:
        // Liquid: waves roll across it, every grain turning on its own
        // little orbit as they pass (as water does), biggest at the top;
        // the body sways on a slower swell and slumps at its foot. Crests
        // catch the light.
        final k = _ramp(tau, 0.6);
        final up = 1 - u;
        final ph = x0 * 0.075 - tau * 6.5 + y0 * 0.02;
        final orbit = r * (0.04 + 0.13 * up);
        final swell = math.sin(tau * 3.1 - u * 3.2 + 0.4 * p3);
        _fx =
            (orbit * math.cos(ph) +
                _halfW * 0.2 * swell * (0.3 + 0.7 * up) +
                x0 * 0.14 * u) *
            k;
        _fy = (orbit * math.sin(ph) + r * 0.1 * u * u) * k;
        _shift = (1.2 - 2.4 * math.sin(ph)) * up * k;

      case EssenceElement.earth:
        // Crumbles: falls to a heap at its feet, a small bounce, stays.
        final ex = _ex![i], ey = _ey![i], tf = _ez![i];
        if (tau < tf) {
          final f = tf <= 0 ? 1.0 : tau / tf;
          _fx = ex * f;
          _fy = 0.5 * _gravity * tau * tau;
        } else {
          final k = tau - tf;
          final bounce = ey * 0.1 * (math.sin(k * 14).abs()) * math.exp(-k * 7);
          _fx = ex;
          _fy = ey - bounce;
          _shift = -1;
          if (k < 0.05 && p1 < 0.06) _glint = true;
        }

      case EssenceElement.air:
        // A whirlwind: round its own axis, wide at the top, rising.
        final k = _ramp(tau, 0.7);
        final up = 1 - u;
        final rr = (x0.abs() * 0.6 + r * 0.1) * (0.45 + 0.85 * up);
        final th0 = (x0 >= 0 ? 0.0 : math.pi) + (p1 - 0.5) * 0.6;
        final th = th0 + (5.5 + 3 * up) * tau;
        final depth = math.sin(th);
        _fx = (rr * math.cos(th) - x0) * k;
        _fy = (-r * 0.22 * (0.6 + 0.4 * up) + math.sin(th + p2) * r * 0.03) * k;
        _shift = (depth * 2 - 1) * k;

      case EssenceElement.steam:
        // Billows: swells out and up, soft, drifting.
        final k = _ramp(tau, 1.1);
        _fx = x0 * 0.35 * k + math.sin(tau * 2.2 + p1 * 6.28) * r * 0.07 * k;
        _fy =
            y0 * 0.15 * k -
            r * (0.26 + 0.2 * p2) * k * (0.5 + 0.5 * (1 - u)) -
            r * 0.08 * tau;
        _shift = (1 - u) * k;

      case EssenceElement.lava:
        // Melts: sags and spreads, a few drips run off its underside; a
        // dark crust with the heat breaking through it.
        final k = _ramp(tau, 0.9);
        var fy = r * 0.18 * u * k;
        final drip = p1 < 0.16 && u > 0.45;
        if (drip) fy += r * (0.35 + 0.4 * p2) * _ramp(tau - 0.25, 0.9);
        _fy = fy;
        _fx =
            x0 * 0.22 * u * k + math.sin(tau * 1.6 + y0 * 0.05) * r * 0.025 * k;
        final crack = math.sin(tau * 3 + p3 * 20) > 0.55;
        _shift = (crack || drip ? 2.5 : -2) * k;

      case EssenceElement.lightning:
        // Crackles: every few frames each grain jumps to somewhere new
        // round its place, hardest at the strike.
        final q = (tau / 0.075 + p3).floor();
        final amp =
            r * (0.03 + 0.08 * _hash(i + 31, q)) * (tau < 0.15 ? 2.2 : 1);
        _fx = (_hash(i, q) - 0.5) * 2 * amp;
        _fy = (_hash(i + 7919, q) - 0.5) * 2 * amp;
        _shift = _hash(i + 17, q) > 0.72 ? 3 : -1;
        if (tau < 0.07 && p1 < 0.12) _glint = true;

      case EssenceElement.mud:
        // Slumps into a puddle at its feet, rippling, the odd plop.
        final k = _ramp(tau, 0.8);
        final hy = grains.hy[i];
        var fy = (_bot - hy) * 0.72 * k;
        fy += math.sin(x0 * 0.09 - tau * 5) * r * 0.03 * k;
        if (p1 < 0.05) {
          fy -=
              r *
              0.25 *
              math.sin(math.pi * _clamp01((tau - 0.4 - p2 * 0.5) / 0.5));
        }
        _fy = fy;
        _fx = x0 * 0.5 * k * (1 - u * 0.4);
        _shift = -1 * k;

      case EssenceElement.ice:
        // Freezes onto a frost lattice, then drifts off it as a flurry,
        // swaying, sparkling.
        final kf = _ramp(tau, 0.2);
        final k = _ramp(tau - 0.35, 0.9);
        _fx =
            _ex![i] * kf +
            x0 * 0.22 * k +
            math.sin(tau * 3 + p1 * 6.28) * r * 0.06 * k;
        _fy = _ey![i] * kf + r * (0.08 + 0.18 * p2) * k + y0 * 0.1 * k;
        _shift = 0;
        if (tau < 0.07 && p1 < 0.1) _glint = true;

      case EssenceElement.dust:
        // Blown away downwind, streaming, turning over.
        final k = _ramp(tau, 0.9);
        _fx =
            r * (0.45 + 0.55 * p1) * k +
            math.sin(tau * 5 + p2 * 6.28) * r * 0.04 * k;
        _fy =
            -r * 0.12 * p2 * k +
            math.sin(tau * 4 + p3 * 6.28 + x0 * 0.05) * r * 0.06 * k;
        _shift = -0.5 * k;

      case EssenceElement.crystal:
        // Cracks into facets that stand off it, each turning a little and
        // lit its own way, the cracks bright.
        final c = _chunk![i];
        final k = _easeOutBack(_clamp01(tau / 0.22));
        final drift = k * (1 + 0.55 * _ramp(tau - 0.2, 1.2));
        final phi = _cRot![c] * drift;
        final rx = _cRelX![i], ry = _cRelY![i];
        final cs = math.cos(phi), sn = math.sin(phi);
        final bob = math.sin(tau * 2 + c * 1.7) * r * 0.012 * k;
        _fx = _cDirX![c] * _cDist![c] * drift + (rx * cs - ry * sn - rx);
        _fy = _cDirY![c] * _cDist![c] * drift + (rx * sn + ry * cs - ry) + bob;
        _shift = ((_cRand![c] - 0.5) * 5 + math.sin(phi * 4) * 1.5) * k;
        if (_edge![i] == 1 && p2 < 0.6) _shift = 6;
        if (tau < 0.06 && p1 < 0.1) _glint = true;

      case EssenceElement.plant:
        // Sprouts: the grains climb into curling stems and leaves,
        // base first, which sway as they stand.
        final k = _ramp(tau, 0.5);
        _layStems(tau + _rel[i]);
        const m = _stemPts;
        final js = _ez![i] * (m - 1);
        final j0 = js.floor().clamp(0, m - 2);
        final fr = js - j0;
        final o = _chunk![i] * m + j0;
        final px = _stemX![o] + (_stemX![o + 1] - _stemX![o]) * fr;
        final py = _stemY![o] + (_stemY![o + 1] - _stemY![o]) * fr;
        final tx = _stemTx![o], ty = _stemTy![o];
        final sa = _ex![i], sb = _ey![i];
        // T along the stem, N across it.
        final wx = px + tx * sa - ty * sb, wy = py + ty * sa + tx * sb;
        _fx = (wx - x0) * k;
        _fy = (wy - y0) * k;
        _shift = 0;

      case EssenceElement.poison:
        // Bubbles: the body swells into blisters that rise and burst, and
        // what is left drips.
        final c = _chunk![i];
        final cr = _cRand![c];
        final k = _ramp(tau, 0.6);
        final pop = 0.55 + 0.6 * cr;
        final burst = _ramp(tau - pop, 0.16);
        final swell = 0.45 * k + 1.3 * burst;
        final rise = r * (0.16 + 0.22 * cr) * k;
        final wob = math.sin(tau * 6 + c * 2.1) * r * 0.025 * k;
        _fx = _cRelX![i] * swell + wob;
        _fy =
            _cRelY![i] * swell -
            rise +
            r * 0.25 * burst * _ramp(tau - pop, 0.9) * (0.4 + p2);
        _shift = burst > 0 ? -1.5 : (_edge![i] == 1 ? 2.5 : -0.5);

      case EssenceElement.spirit:
        // Rises as a ghost: a waving column narrowing to a tail.
        final k = _ramp(tau, 0.9);
        _fy = -r * (0.26 + 0.22 * (1 - u)) * k - r * 0.07 * tau;
        _fx =
            math.sin(y0 * 0.07 - tau * 4.2 + p1 * 0.6) *
                r *
                0.2 *
                k *
                (0.3 + 0.7 * u) -
            x0 * 0.35 * u * k;
        _shift = 1;

      case EssenceElement.dark:
        // Swallowed: spirals into a point at its heart, the inside
        // turning faster, and keeps turning there.
        final s = _clamp01(tau / 0.85);
        final k = s * s;
        final d = _d[i];
        final rr = d * r * (1 - 0.86 * k);
        final a = _a[i] + k * (1.6 + 2.2 * (1 - d)) + tau * 2.5 * k;
        _fx = rr * math.cos(a) - x0;
        _fy = rr * math.sin(a) * 0.85 - y0;
        _shift = (1 - d) * 2 * k + 1.5;

      case EssenceElement.light:
        // Radiates: opens outward and gathers into rays.
        // Uneven rays, each its own length: an even ring of spokes reads
        // as a badge.
        final k = _ramp(tau, 0.8);
        const rays = 9;
        const step = math.pi * 2 / rays;
        final a0 = _a[i];
        final ri = (a0 / step).round();
        final ray = ri * step + (_hash(ri + 40, 3) - 0.5) * step * 0.7;
        final len = 0.2 + 0.45 * _hash(ri + 90, 5);
        final a = a0 + (ray - a0) * 0.3 * k;
        final rr = _d[i] * r * (1 + len * k) + r * 0.06 * k * p1;
        _fx = rr * math.cos(a) - x0;
        _fy = rr * math.sin(a) - y0;
        _shift = 3 * k;

      case EssenceElement.blood:
        // A heartbeat: lub-dub, the pulse spreading out from the heart,
        // and a few drops running down.
        final k = _ramp(tau, 0.5);
        final m = (tau - _d[i] * 0.2) % 0.72;
        double beat(double x) => math.exp(-(x * x) / 0.003);
        final b = beat(m) + 0.65 * beat(m - 0.19);
        // Loose between beats, gathered tight on each, so the beat shows
        // as a jolt rather than a breath.
        final swell = (0.12 + 0.3 * b) * k;
        final churn = math.sin(tau * 2.2 + _a[i] * 2) * r * 0.02 * k;
        _fx = x0 * swell - y0 * 0.12 * k + churn;
        var fy = y0 * swell + x0 * 0.12 * k;
        if (p1 < 0.16 && u > 0.45) {
          fy += r * (0.3 + 0.25 * p2) * _ramp(tau - 0.25 - p2 * 0.4, 0.8);
        }
        _fy = fy;
        _shift = (4 * b + 1.2) * k;
    }
  }

  static double _easeOutBack(double x) {
    const c1 = 1.9, c3 = c1 + 1;
    final y = x - 1;
    return 1 + c3 * y * y * y + c1 * y * y;
  }

  // Sparks: some grains throw one as they let go — embers, droplets, bolts,
  // pollen, motes. Writes where it is into [_fx]/[_fy] (absolute, from the
  // centroid) and returns its strength, 0 once it is spent.
  double _spark(int i, double tau, double gx, double gy) {
    final r = _reach;
    final p1 = _p1[i], p2 = _p2[i];
    switch (element) {
      case EssenceElement.fire:
        const life = 0.9;
        final s = (tau - 0.15 - p2 * 0.5) / life;
        if (s <= 0 || s >= 1) return 0;
        _fx = gx + math.sin(s * 5 + p1 * 6.28) * r * 0.1 * s;
        _fy = gy - r * (0.5 + 0.6 * p1) * s;
        return 1 - s;
      case EssenceElement.water:
        const life = 0.7;
        final s = (tau - 0.25 - p2 * 0.6) / life;
        if (s <= 0 || s >= 1) return 0;
        final dir = _x0[i] >= 0 ? 1.0 : -1.0;
        final ts = s * life;
        _fx = gx + dir * r * 0.5 * ts;
        _fy = gy - r * 0.5 * ts + 0.5 * 900 * ts * ts;
        return 1 - s;
      case EssenceElement.air:
        const life = 0.6;
        final s = (tau - 0.2 - p2 * 0.7) / life;
        if (s <= 0 || s >= 1) return 0;
        final dir = p1 > 0.5 ? 1.0 : -1.0;
        _fx = gx + dir * r * 0.75 * s;
        _fy = gy - r * 0.45 * s;
        return 1 - s;
      case EssenceElement.lightning:
        // Bolts: thrown straight out from the heart, again and again.
        const life = 0.18;
        final m = (tau + p2 * 0.4) % 0.42;
        final s = m / life;
        if (s >= 1 || tau > 1.2) return 0;
        final a = _a[i];
        final rr = r * (0.45 + 0.75 * s) * (0.7 + 0.4 * p1);
        _fx = math.cos(a) * rr;
        _fy = math.sin(a) * rr;
        return 1 - s;
      case EssenceElement.plant:
        const life = 1.2;
        final s = (tau - 0.3 - p2 * 0.5) / life;
        if (s <= 0 || s >= 1) return 0;
        _fx = gx + math.sin(s * 6 + p1 * 6.28) * r * 0.1;
        _fy = gy - r * 0.35 * s;
        return math.sin(math.pi * s);
      case EssenceElement.light:
        const life = 0.8;
        final s = (tau - 0.2 - p2 * 0.6) / life;
        if (s <= 0 || s >= 1) return 0;
        final a = _a[i];
        final rr = r * (1.0 + 0.5 * s);
        _fx = math.cos(a) * rr * (0.6 + 0.4 * p1);
        _fy = math.sin(a) * rr * (0.6 + 0.4 * p1);
        return 1 - s;
      default:
        return 0;
    }
  }

  // ── the look ──────────────────────────────────────────────────────────

  static const int _shadeCount = 8;
  static const int _ownB = 0, _blendB = 16, _elemB = 32;
  static const int _glowB = 40, _sparkB = 41, _haloB = 42, _glintB = 43;
  static final GrainBatch _batch = GrainBatch(44);

  List<Color>? _shades;
  List<Color>? _blends;

  List<Color> get _elementShades => _shades ??= [
    for (var k = 0; k < _shadeCount; k++) _rampAt(k / (_shadeCount - 1)),
  ];

  /// Half its own tone, half the element shade of its brightness: the step
  /// between the two, so the turn is never one hard swap.
  List<Color> get _blendTones => _blends ??= [
    for (var k = 0; k < math.min(16, grains.tones.length); k++)
      Color.lerp(
        grains.tones[k],
        _elementShades[(k /
                math.max(1, grains.tones.length - 1) *
                (_shadeCount - 1))
            .round()],
        0.5,
      )!,
  ];

  Color _rampAt(double t) {
    final ramp = _look.ramp;
    final x = t * (ramp.length - 1);
    final i = x.floor().clamp(0, ramp.length - 2);
    return Color.lerp(ramp[i], ramp[i + 1], x - i)!;
  }

  /// The light under the creature while it is its element: 0..1.
  static double _presence(double t) =>
      _smooth(0.12, 0.6, t) * (1 - _smooth(1.6, 2.35, t));

  /// Paints the field centred on [at] (the centre of the box the grains
  /// were read from) at time [t] seconds.
  void paint(Canvas canvas, Offset at, double t, {bool dark = true}) {
    if (t <= 0 || t >= duration || length == 0) return;
    final b = _batch..clear();
    final g = grains;
    final look = _look;
    final tm = _time;
    final nt = math.min(16, g.tones.length);
    final ox = at.dx + _cx, oy = at.dy + _cy;
    final twinkleQ = (t * 9).floor();
    // On the light theme's plate the pale shades wash out: a step darker.
    final themeShift = dark ? 0.0 : -1.6;

    _paintPool(canvas, Offset(ox, oy), t, dark);

    for (var i = 0; i < length; i++) {
      final hx = _x0[i], hy = _y0[i];
      final rel = _rel[i];
      final ret = _ret[i];
      final own = math.min(g.tone[i], nt - 1);
      if (t < rel || t >= ret + tm.outDur) {
        // At home, its own colour: still the sprite, or the sprite again.
        final landed = t >= ret + tm.outDur;
        if (landed && t < ret + tm.outDur + 0.05 && _p1[i] < 0.05) {
          b.add(_glintB, ox + hx, oy + hy);
        } else {
          b.add(_ownB + own, ox + hx, oy + hy);
        }
        continue;
      }
      final tau = t - rel;
      final ein = _easeOut(_clamp01(tau / tm.inDur));
      final eoutT = _clamp01((t - ret) / tm.outDur);
      final eout = _easeInOut(eoutT);
      final env = ein * (1 - eout);
      _form(i, tau);
      var fx = _fx, fy = _fy;
      if (tm.swirl != 0 && eout > 0) {
        // Home along a swirl: the offset turns as it shrinks.
        final phi = tm.swirl * (_p3[i] > 0.5 ? 1 : -0.6) * eout;
        final cs = math.cos(phi), sn = math.sin(phi);
        final rx = fx * cs - fy * sn;
        fy = fx * sn + fy * cs;
        fx = rx;
      }
      final x = ox + hx + fx * env;
      final y = oy + hy + fy * env;

      // How far into the element it has turned.
      final heat = _smooth(0.0, 0.22, tau) * (1 - _smooth(0.35, 0.9, eoutT));
      if (_glint ||
          (tau < 0.03 && _p1[i] < 0.06) ||
          (look.twinkle > 0 &&
              heat > 0.7 &&
              _hash(i, twinkleQ) < look.twinkle)) {
        b.add(_glintB, x, y);
      } else if (heat < 0.33) {
        b.add(_ownB + own, x, y);
      } else if (heat < 0.7) {
        b.add(_blendB + own, x, y);
      } else {
        final s = (_shade[i] + _shift + themeShift).round().clamp(
          0,
          _shadeCount - 1,
        );
        b.add(_elemB + s, x, y);
        if (look.glow > 0 && i % 3 == 0) b.add(_glowB, x, y);
      }

      if (look.sparkEvery > 0 && i % look.sparkEvery == 0 && eout < 0.5) {
        final st = _spark(i, tau, hx + fx * env, hy + fy * env);
        if (st > 0) {
          b.add(st > 0.5 ? _sparkB : _haloB, ox + _fx, oy + _fy);
        }
      }
    }

    final d = math.max(1.2, g.step * 1.22);
    final fade = (1 - _smooth(duration - 0.16, duration, t)) * _revealIn(t);
    Color f(Color c, [double k = 1]) =>
        c.withValues(alpha: (c.a * k * fade).clamp(0.0, 1.0));
    final ea = look.alpha;
    final de = d * look.size;

    if (look.glow > 0) {
      b.draw(
        canvas,
        _glowB,
        de * 3.4,
        f(look.ramp[2], look.glow * (dark ? 1 : 0.55)),
      );
    }
    for (var k = 0; k < nt; k++) {
      b.draw(canvas, _ownB + k, d, f(g.tones[k]));
    }
    final blends = _blendTones;
    for (var k = 0; k < nt; k++) {
      b.draw(canvas, _blendB + k, (d + de) / 2, f(blends[k], (1 + ea) / 2));
    }
    final shades = _elementShades;
    for (var k = 0; k < _shadeCount; k++) {
      b.draw(canvas, _elemB + k, de, f(shades[k], ea));
    }
    b.draw(canvas, _sparkB, de * 1.05, f(look.ramp[3]));
    b.draw(canvas, _haloB, de * 0.9, f(look.ramp[2], 0.7));
    const glint = Color(0xFFFFFBEA);
    b.draw(canvas, _glintB, d * 2.2, f(glint, dark ? 0.16 : 0.24));
    b.draw(canvas, _glintB, d * 1.25, f(glint, 0.9));
  }

  /// A reveal's grains coming up out of nothing: 0..1.
  double _revealIn(double t) =>
      reveal ? _smooth(revealStart, revealStart + 0.3, t) : 1.0;

  void _paintPool(Canvas canvas, Offset c, double t, bool dark) {
    final look = _look;
    var a = _presence(t) * look.poolAlpha * (dark ? 1 : 0.6) * _revealIn(t);
    if (element == EssenceElement.lightning) {
      // The strike's flash, then flickers.
      final flash = 1 - _smooth(0.0, 0.25, t);
      a *=
          0.35 +
          0.65 * math.max(flash, _hash(7, (t * 14).floor()) > 0.8 ? 1 : 0);
    }
    if (a <= 0.004) return;
    if (element == EssenceElement.dark) {
      // The void it falls into: dark at the heart, a violet bloom about it.
      final r = _reach * (0.5 - 0.18 * _smooth(0.3, 1.0, t));
      canvas.drawCircle(
        c,
        r * 1.8,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            r * 1.8,
            [
              Color.fromRGBO(0, 0, 0, a),
              Color.fromRGBO(0, 0, 0, a * 0.7),
              const Color(0xFF6D4BC8).withValues(alpha: a * 0.28),
              const Color(0x006D4BC8),
            ],
            const [0.0, 0.28, 0.55, 1.0],
          ),
      );
      return;
    }
    final r = _reach * 1.25;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          [
            look.pool.withValues(alpha: a),
            look.pool.withValues(alpha: a * 0.35),
            look.pool.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
  }
}

/// Paints an [EssenceField] at its controller's time.
class EssencePainter extends CustomPainter {
  EssencePainter(this.field, this.progress, {this.dark = true})
    : super(repaint: progress);

  final EssenceField field;

  /// 0..1 over [EssenceField.duration].
  final Animation<double> progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) => field.paint(
    canvas,
    size.center(Offset.zero),
    progress.value * EssenceField.duration,
    dark: dark,
  );

  @override
  bool shouldRepaint(EssencePainter old) =>
      old.field != field || old.dark != dark;
}

/// A ticket to play an [ElementalEssence]'s reveal.
///
/// [once] is spent by the first essence to mount with it: the same view built
/// again (a tab coming back, a list scrolling it back in) just shows the
/// sprite. Hand an essence a new one to reveal it again.
class EssenceReveal {
  EssenceReveal.once() : _once = true;

  /// Every essence that mounts with this reveals.
  EssenceReveal.always() : _once = false;

  final bool _once;
  bool _spent = false;

  bool claim() {
    if (_spent) return false;
    if (_once) _spent = true;
    return true;
  }
}

/// Wraps a creature's sprite: a tap turns it into its element and back.
///
/// [captureScale] is for a sprite drawn bigger than its slot (in an
/// OverflowBox): the capture reads that much round the slot so none of it is
/// cut off. [onLongPress] is passed through, since this owns the gestures.
///
/// With a [reveal] the creature first appears this way: the sprite is held
/// out of sight until it has loaded (it says so with a
/// [SpriteReadyNotification]), read, and then its element gathers into it.
/// Key the essence by the creature it shows, so a new one gets a fresh state.
class ElementalEssence extends StatefulWidget {
  const ElementalEssence({
    super.key,
    required this.element,
    required this.child,
    this.onLongPress,
    this.captureScale = 1,
    this.dark = true,
    this.maxGrains = 2200,
    this.reveal,
    this.hold = false,
    this.tappable = true,
  });

  /// The creature's type name ('Fire'…): see [EssenceElement.of].
  final String? element;
  final Widget child;
  final VoidCallback? onLongPress;
  final double captureScale;
  final bool dark;
  final int maxGrains;
  final EssenceReveal? reveal;

  /// Keeps a reveal waiting, its sprite out of sight, until this goes false:
  /// a page built ahead of being swiped to, say.
  final bool hold;

  /// False where a tap on the sprite already means something else.
  final bool tappable;

  @override
  State<ElementalEssence> createState() => _ElementalEssenceState();
}

class _ElementalEssenceState extends State<ElementalEssence>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundary = GlobalKey();
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (EssenceField.duration * 1000).round()),
  )..addStatusListener(_onStatus);
  late final Animation<double> _spriteOpacity = _c.drive(_SpriteFade());
  EssenceField? _field;
  bool _reading = false;
  bool _landed = false;

  /// Waiting to reveal: the sprite is drawn, so it can be read, but too
  /// faintly to see.
  bool _awaitingReveal = false;

  /// The sprite under it has loaded and drawn.
  bool _spriteReady = false;
  Timer? _revealTimeout;

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && mounted) {
      setState(() => _field = null);
    }
  }

  void _onTick() {
    // A small knock as it lands back together.
    if (!_landed && _c.value * EssenceField.duration > 2.2) {
      _landed = true;
      HapticFeedback.lightImpact();
    }
  }

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    if (widget.reveal?.claim() ?? false) _armReveal();
  }

  @override
  void didUpdateWidget(ElementalEssence old) {
    super.didUpdateWidget(old);
    if (widget.reveal != old.reveal && (widget.reveal?.claim() ?? false)) {
      setState(_armReveal);
    } else if (old.hold && !widget.hold) {
      if (_awaitingReveal) {
        _released();
      } else if (!_c.isAnimating && _field != null) {
        // Stopped part-way while it was out of view: never leave it there.
        setState(_showPlain);
      }
    } else if (!old.hold && widget.hold) {
      // Out of view: the give-up timer is for a card someone is looking at.
      _revealTimeout?.cancel();
    }
  }

  /// No reveal after all: the sprite, plainly, and the controller at rest
  /// — stopped part-way, it would hold the sprite faded out for good.
  void _showPlain() {
    _revealTimeout?.cancel();
    _c.stop();
    _c.value = 0;
    _field = null;
    _awaitingReveal = false;
  }

  @override
  void dispose() {
    _revealTimeout?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _armReveal() {
    if (_c.isAnimating) {
      // Re-armed mid-play (a page swiped away before it finished): it is out
      // of sight, so it can just stop — at rest, not part-way.
      _c.stop();
      _c.value = 0;
      _field = null;
    }
    _awaitingReveal = true;
    _revealTimeout?.cancel();
    if (!widget.hold) _released();
  }

  /// Free to reveal: now, if the sprite is already up.
  void _released() {
    _revealTimeout?.cancel();
    // A sprite that never says it is ready (it failed to load, or the child
    // is not a sprite) is shown plainly rather than kept hidden.
    _revealTimeout = Timer(const Duration(milliseconds: 1600), () {
      if (mounted && _awaitingReveal && !_reading && !widget.hold) {
        setState(_showPlain);
      }
    });
    // Already loaded (the same creature, revealed again): read it now.
    if (_spriteReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startReveal());
    }
  }

  bool _onSpriteReady(SpriteReadyNotification n) {
    _spriteReady = true;
    if (_awaitingReveal && !_reading) _startReveal();
    return false;
  }

  Future<void> _startReveal() async {
    if (!mounted || !_awaitingReveal || _reading || widget.hold) return;
    // Between frames, so nothing in the box is waiting to be repainted.
    // Asked for outright: called from a post-frame callback, waiting on the
    // end of a frame would not schedule one, and a still sprite would wait
    // for ever.
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_awaitingReveal || widget.hold) return;
    final grains = await _read();
    if (!mounted) return;
    _revealTimeout?.cancel();
    if (grains == null) {
      setState(_showPlain);
      return;
    }
    _landed = false;
    final field = EssenceField(grains, EssenceElement.of(widget.element))
      ..reveal = true;
    // The controller first, so the frame that stops hiding the sprite
    // already has it faded out by the reveal's own curve.
    unawaited(
      _c.forward(from: EssenceField.revealStart / EssenceField.duration),
    );
    setState(() {
      _field = field;
      _awaitingReveal = false;
    });
  }

  /// Reads the sprite, as it is drawn now, into grains. Null if there is
  /// nothing there yet.
  Future<SpecimenGrains?> _read() async {
    final boundary = _boundary.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.attached) return null;
    _reading = true;
    final ratio = math.min(MediaQuery.devicePixelRatioOf(context), 2.0);
    try {
      final image = await boundary.toImage(pixelRatio: ratio);
      try {
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        if (data == null) return null;
        final grains = SpecimenGrains.fromRgba(
          data.buffer.asUint8List(),
          image.width,
          image.height,
          pixelRatio: ratio,
          maxGrains: widget.maxGrains,
          tones: 16,
        );
        // Not loaded yet, or nothing there to read.
        return grains.length < 60 ? null : grains;
      } finally {
        image.dispose();
      }
    } catch (_) {
      // A failed read just means no effect this time.
      return null;
    } finally {
      _reading = false;
    }
  }

  Future<void> _play() async {
    if (_reading || _c.isAnimating || _awaitingReveal) return;
    HapticFeedback.lightImpact();
    final grains = await _read();
    if (!mounted || grains == null) return;
    setState(
      () => _field = EssenceField(grains, EssenceElement.of(widget.element)),
    );
    _landed = false;
    unawaited(_c.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final field = _field;
    final body = NotificationListener<SpriteReadyNotification>(
      onNotification: _onSpriteReady,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          final k = widget.captureScale;
          Widget sprite = RepaintBoundary(
            key: _boundary,
            child: k == 1
                ? widget.child
                : SizedBox(
                    width: w * k,
                    height: h * k,
                    child: Center(
                      child: SizedBox(width: w, height: h, child: widget.child),
                    ),
                  ),
          );
          if (k != 1) {
            sprite = OverflowBox(
              maxWidth: w * k,
              maxHeight: h * k,
              child: sprite,
            );
          }
          return Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              // Held faint rather than at zero: at zero it would not be
              // painted at all, and so could not be read.
              Opacity(
                opacity: _awaitingReveal ? 0.01 : 1,
                // Only an essence that is playing fades the sprite: at rest
                // it is whole, whatever the controller was left at.
                child: FadeTransition(
                  opacity: field != null
                      ? _spriteOpacity
                      : kAlwaysCompleteAnimation,
                  child: sprite,
                ),
              ),
              if (field != null)
                IgnorePointer(
                  child: CustomPaint(
                    painter: EssencePainter(field, _c, dark: widget.dark),
                  ),
                ),
            ],
          );
        },
      ),
    );
    if (!widget.tappable && widget.onLongPress == null) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.tappable ? _play : null,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: body,
    );
  }
}

class _SpriteFade extends Animatable<double> {
  @override
  double transform(double t) =>
      EssenceField.spriteOpacity(t * EssenceField.duration);
}
