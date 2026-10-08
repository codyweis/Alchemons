// lib/screens/shop/gold_vault.dart
//
// THE GOLD VAULT — gold for real money, as the alchemist keeps it: a dark
// case, a small sun of molten gold grains hanging in it, and four heaps of
// grains on the shelf below. Choosing a heap pours it up into the sun, which
// swells to match — the more gold, the bigger and brighter the sun, and the
// top packs gather a dust ring and a corona. The buy button is the only
// bright surface in the case, so the eye ends on it.
//
// One ticker, one painter, no blur: the grains are point batches (see
// [GrainBatch]) and every glow is a radial gradient.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/services/mobile_store_service.dart'
    show GoldPackDefinition;
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// One gold pack as the vault shows it.
class GoldVaultOffer {
  const GoldVaultOffer({
    required this.pack,
    this.price,
    this.rawPrice,
    this.pending = false,
  });

  final GoldPackDefinition pack;

  /// The store's localised price, or null while the store has not said.
  final String? price;

  /// [price] as a number, for comparing packs.
  final double? rawPrice;

  /// A purchase of this pack is in flight.
  final bool pending;

  /// How much more gold per unit of money each pack gives than the smallest
  /// pack does, as a whole percentage. Null for a pack with no store price,
  /// and for all of them when the smallest has none — a bonus is only shown
  /// when it is true.
  static List<int?> bonuses(List<GoldVaultOffer> offers) {
    GoldVaultOffer? base;
    for (final o in offers) {
      final p = o.rawPrice;
      if (p == null || p <= 0) continue;
      if (base == null || o.pack.goldAmount < base.pack.goldAmount) base = o;
    }
    if (base == null) return List.filled(offers.length, null);
    final baseRate = base.pack.goldAmount / base.rawPrice!;
    return [
      for (final o in offers)
        (o.rawPrice == null || o.rawPrice! <= 0)
            ? null
            : ((o.pack.goldAmount / o.rawPrice!) / baseRate * 100 - 100)
                  .round(),
    ];
  }
}

// ── palette ──────────────────────────────────────────────────────────────────
//
// The case is dark in both themes: it is a vault, and gold needs the dark to
// glow against. So its colours are its own, not the theme's.

abstract final class _V {
  static const caseTop = Color(0xFF100C07);
  static const caseBottom = Color(0xFF060504);
  static const edge = Color(0xFF4A3618);
  static const edgeLit = Color(0xFFC79A48);
  static const gold = Color(0xFFE4C16A);
  static const goldBright = Color(0xFFF6DD94);
  static const goldDeep = Color(0xFFA9813F);
  static const parchment = Color(0xFFE6E2DA);
  static const muted = Color(0xFF85827C);
  static const verdigris = Color(0xFF8CC9A8);
  static const danger = Color(0xFFE07A66);
  static const ink = Color(0xFF1B1205);

  /// Molten gold, darkest first: umber, bronze, amber, gold, pale gold.
  static const tones = [
    Color(0xFF3A2006),
    Color(0xFF5E3610),
    Color(0xFF8C5618),
    Color(0xFFB97A20),
    Color(0xFFD99D30),
    Color(0xFFEFBF4C),
    Color(0xFFF9D97C),
    Color(0xFFFFF0BE),
  ];
  static const glint = Color(0xFFFFFBEA);
}

// ── layout ───────────────────────────────────────────────────────────────────

/// Where everything in the case sits, shared by the painter and the widgets
/// laid over it so the grains and the text agree.
class GoldVaultLayout {
  GoldVaultLayout(this.width, this.count) {
    sunZone = (width * 0.44).clamp(150.0, 280.0);
    sun = Offset(sunZone / 2 + 4, heroHeight / 2 + 4);
    sunRadius = math.min(heroHeight * 0.27, sunZone * 0.28);
    final inner = width - 2 * pad;
    tabletWidth = (inner - gap * (count - 1)) / count;
    tablets = [
      for (var i = 0; i < count; i++)
        Rect.fromLTWH(
          pad + i * (tabletWidth + gap),
          heroHeight,
          tabletWidth,
          tabletHeight,
        ),
    ];
  }

  final double width;
  final int count;

  static const double heroHeight = 172;
  static const double tabletHeight = 112;
  static const double heapZone = 50;
  static const double pad = 10;
  static const double gap = 6;

  late final double sunZone;
  late final Offset sun;

  /// The sun's radius at the biggest pack.
  late final double sunRadius;
  late final double tabletWidth;
  late final List<Rect> tablets;

  /// Where tablet [i]'s heap stands.
  Offset heapBase(int i) =>
      Offset(tablets[i].center.dx, tablets[i].top + heapZone - 2);

  /// Half the width and the height of a heap holding [g] of the biggest
  /// pack's gold — sized in px, not by the tablet, so a wide tablet does not
  /// spread its heap thin.
  (double, double) heapSize(double g) => (
    math.min(tabletWidth * 0.42, 14 + 26 * math.sqrt(g)),
    9 + 26 * math.sqrt(g),
  );
}

// ── the grains ───────────────────────────────────────────────────────────────

class _Pour {
  _Pour(
    this.tablet,
    this.grain,
    this.start,
    this.duration,
    this.angle,
    this.reach,
    this.bow, {
    this.back = false,
  });
  final int tablet, grain;
  final double start, duration, angle, reach, bow;

  /// Sun to heap: gold given back when a smaller pack is chosen.
  final bool back;
}

/// Everything in the case that is made of grains: the sun, its ring and
/// corona, the motes rising through the case, the heaps, and the pours from
/// a heap into the sun. Plain Dart: [step] advances it, [paint] draws it.
class GoldVaultField {
  GoldVaultField(List<int> golds, {int selected = 0})
    : golds = List.unmodifiable(golds) {
    final rng = math.Random(11);

    // The sun: grains through a sphere, most towards its shell so it reads
    // as a ball, turning faster at its equator than its poles as the real
    // one does.
    for (var i = 0; i < maxSun; i++) {
      final lat = math.asin(rng.nextDouble() * 2 - 1);
      _lat[i] = lat;
      _lon0[i] = rng.nextDouble() * math.pi * 2;
      _r[i] = 0.42 + 0.58 * math.pow(rng.nextDouble(), 0.4);
      final s = math.sin(lat);
      _omega[i] = (1 - 0.34 * s * s) * (0.9 + 0.2 * rng.nextDouble());
      _ph[i] = rng.nextDouble();
    }

    // The dust ring, in two lanes; its last grains gather into clumps, so
    // only the biggest pack's ring has them.
    const lanes = [(1.42, 0.05, 1.0), (1.66, 0.1, 0.9)];
    double laneRadius() {
      var pick = rng.nextDouble() * 1.9;
      for (final (c, w, weight) in lanes) {
        pick -= weight;
        if (pick <= 0) return c + (rng.nextDouble() + rng.nextDouble() - 1) * w;
      }
      return lanes.last.$1;
    }

    const clumped = 64;
    for (var i = 0; i < maxRing - clumped; i++) {
      _ringRad[i] = laneRadius();
      _ringA0[i] = rng.nextDouble() * math.pi * 2;
      _ringSize[i] = 0.5 + rng.nextDouble() * 0.9;
      _ringPh[i] = rng.nextDouble() * math.pi * 2;
    }
    for (var k = 0; k < 4; k++) {
      final a = rng.nextDouble() * math.pi * 2;
      final rad = laneRadius();
      for (var j = 0; j < clumped ~/ 4; j++) {
        final i = maxRing - clumped + k * (clumped ~/ 4) + j;
        _ringRad[i] = rad + (rng.nextDouble() - 0.5) * 0.08;
        _ringA0[i] = a + (rng.nextDouble() - 0.5) * 0.4;
        _ringSize[i] = 0.7 + rng.nextDouble() * 0.9;
        _ringPh[i] = rng.nextDouble() * math.pi * 2;
      }
    }

    for (var i = 0; i < corona; i++) {
      _corA[i] = rng.nextDouble() * math.pi * 2;
      _corPh[i] = rng.nextDouble();
      _corSpeed[i] = 0.22 + rng.nextDouble() * 0.22;
    }

    for (var i = 0; i < motes; i++) {
      _moteX[i] = rng.nextDouble();
      _motePh[i] = rng.nextDouble();
      _moteSpeed[i] = 0.05 + rng.nextDouble() * 0.07;
      _moteBig[i] = rng.nextDouble() < 0.3 ? 1 : 0;
    }

    // The heaps: a mound per pack, bigger with the gold in it. Each grain
    // is kept as (across, up) in the mound's own units, and lit by how near
    // the crust it is and which side it is on.
    final maxGold = golds.fold<int>(1, math.max);
    for (final gold in golds) {
      final g = gold / maxGold;
      final n = (18 + 220 * math.pow(g, 0.75)).round();
      final hu = Float32List(n), hv = Float32List(n);
      final tone = Uint8List(n);
      final ph = Float32List(n);
      var k = 0;
      while (k < n) {
        final u = rng.nextDouble() * 2 - 1;
        final v = rng.nextDouble();
        final p = _mound(u);
        if (v > p) continue;
        hu[k] = u;
        hv[k] = v;
        final crust = v / p;
        final b = (0.18 + 0.55 * math.pow(crust, 2.2) + 0.25 * v - 0.16 * u)
            .clamp(0.0, 1.0);
        tone[k] = (b * 7.99).floor();
        ph[k] = rng.nextDouble();
        k++;
      }
      _heapU.add(hu);
      _heapV.add(hv);
      _heapTone.add(tone);
      _heapPh.add(ph);
      _heapSize.add(g);
    }

    select(selected, pour: false);
  }

  static const int maxSun = 1150;
  static const int maxRing = 360;
  static const int corona = 120;
  static const int motes = 38;

  final List<int> golds;

  final _lat = Float32List(maxSun),
      _lon0 = Float32List(maxSun),
      _r = Float32List(maxSun),
      _omega = Float32List(maxSun),
      _ph = Float32List(maxSun);
  final _ringRad = Float32List(maxRing),
      _ringA0 = Float32List(maxRing),
      _ringSize = Float32List(maxRing),
      _ringPh = Float32List(maxRing);
  final _corA = Float32List(corona),
      _corPh = Float32List(corona),
      _corSpeed = Float32List(corona);
  final _moteX = Float32List(motes),
      _motePh = Float32List(motes),
      _moteSpeed = Float32List(motes);
  final _moteBig = Uint8List(motes);
  final List<Float32List> _heapU = [], _heapV = [], _heapPh = [];
  final List<Uint8List> _heapTone = [];
  final List<double> _heapSize = [];

  /// A mound's height across it, 0..1 for -1..1.
  static double _mound(double u) =>
      math.pow(math.max(0.0, 1 - math.pow(u.abs(), 1.7)), 0.85).toDouble();

  final math.Random _rng = math.Random(29);
  final List<_Pour> _pours = [];

  int selected = 0;
  double time = 0;
  double _spin = 0, _spinRate = _restSpin;
  double _heat = 0;

  // Where the sun is heading, and where it is.
  double _sunTarget = 0, _sunCount = 0;
  double _radiusTarget = 1, _radius = 1;
  double _ringTarget = 0, _ring = 0;
  double _coronaTarget = 0, _corona = 0;

  static const double _restSpin = 0.3, _busySpin = 2.4;

  /// Whether a pour is still in the air.
  bool get pouring => _pours.isNotEmpty;

  /// Grains the sun is showing now.
  int get sunGrains => _sunCount.round();

  /// Chooses heap [i]: the sun heads for its size, and unless [pour] is
  /// false the heap pours up into it.
  void select(int i, {bool pour = true}) {
    final was = selected;
    final wasG = _heapSize.isEmpty ? 1.0 : _heapSize[was];
    selected = i.clamp(0, golds.length - 1);
    final g = _heapSize.isEmpty ? 1.0 : _heapSize[selected];
    _sunTarget = 330 + (maxSun - 330) * math.pow(g, 0.6).toDouble();
    _radiusTarget = 0.62 + 0.38 * math.sqrt(g);
    // No ring at all below the middle packs: a few dozen grains round a
    // small sun read as fuzz, not as a ring.
    _ringTarget = g < 0.3
        ? 0
        : maxRing * (0.4 + 0.6 * ((g - 0.4) / 0.6).clamp(0.0, 1.0));
    _coronaTarget = ((g - 0.3) / 0.7).clamp(0.0, 1.0);
    if (!pour) {
      _sunCount = _sunTarget;
      _radius = _radiusTarget;
      _ring = _ringTarget;
      _corona = _coronaTarget;
      return;
    }
    if (g < wasG) {
      // A smaller pack: the sun gives back what it holds over it, and the
      // gold leaves its shell and pours down onto the heap it came from.
      final heap = _heapU[was];
      final n = (26 + 90 * (math.sqrt(wasG) - math.sqrt(g))).round();
      for (var k = 0; k < n; k++) {
        var grain = _rng.nextInt(heap.length);
        for (var tries = 0; tries < 3; tries++) {
          final cand = _rng.nextInt(heap.length);
          if (_heapV[was][cand] > _heapV[was][grain]) grain = cand;
        }
        _pours.add(
          _Pour(
            was,
            grain,
            time + _rng.nextDouble() * 0.55,
            0.75 + _rng.nextDouble() * 0.25,
            _rng.nextDouble() * math.pi * 2,
            // From the shell: the outside is what comes away.
            0.8 + 0.2 * _rng.nextDouble(),
            0.1 + (_rng.nextDouble() - 0.5) * 0.12,
            back: true,
          ),
        );
      }
      return;
    }
    final heap = _heapU[selected];
    final n = (34 + 70 * math.sqrt(g)).round();
    for (var k = 0; k < n; k++) {
      // From the top of the heap, mostly: the crust is what lifts first.
      var grain = _rng.nextInt(heap.length);
      for (var tries = 0; tries < 3; tries++) {
        final cand = _rng.nextInt(heap.length);
        if (_heapV[selected][cand] > _heapV[selected][grain]) grain = cand;
      }
      _pours.add(
        _Pour(
          selected,
          grain,
          time + _rng.nextDouble() * 0.55,
          0.75 + _rng.nextDouble() * 0.25,
          _rng.nextDouble() * math.pi * 2,
          0.2 + 0.7 * math.sqrt(_rng.nextDouble()),
          // Nearly one path, so the grains go up as a stream.
          0.1 + (_rng.nextDouble() - 0.5) * 0.12,
        ),
      );
    }
  }

  void step(double dt, {bool busy = false}) {
    time += dt;
    double ease(double rate) => 1 - math.exp(-dt * rate);
    _spinRate += ((busy ? _busySpin : _restSpin) - _spinRate) * ease(2.2);
    _spin += dt * _spinRate;
    _heat += ((busy ? 1.0 : 0.0) - _heat) * ease(2.0);
    // While a pour is landing the sun fills as the grains arrive.
    _sunCount += (_sunTarget - _sunCount) * ease(pouring ? 1.9 : 4);
    _radius += (_radiusTarget - _radius) * ease(2.4);
    _ring += (_ringTarget - _ring) * ease(2.0);
    _corona += (_coronaTarget - _corona) * ease(2.0);
    _pours.removeWhere((p) => time > p.start + p.duration);
  }

  // ── the look ────────────────────────────────────────────────────────────

  // Buckets: the sun's near tones, far tones and glints; the ring's
  // near/far × dim/bright; the corona; the motes; each heap tone lit and
  // dimmed; heap glints; pours and their trails.
  static const int _farB = 8;
  static const int _sunGlintB = 12;
  static const int _ringB = 13; // + far*2 + bright
  static const int _coronaB = 17; // 3 ages
  static const int _moteB = 20; // small, big
  static const int _heapB = 22; // lit 8, dim 8
  static const int _heapGlintB = 38;
  final GrainBatch _b = GrainBatch(39);
  final GrainBatch _pourBatch = GrainBatch(2);

  static const double _tip = 0.36;
  static final double _lx = -0.45 / _lLen,
      _ly = -0.6 / _lLen,
      _lz = 0.66 / _lLen;
  static final double _lLen = math.sqrt(0.45 * 0.45 + 0.6 * 0.6 + 0.66 * 0.66);

  void paint(Canvas canvas, GoldVaultLayout l) {
    final b = _b..clear();
    final c = l.sun;
    final r = l.sunRadius * _radius;
    final d = math.max(1.6, r * 0.05);
    final t = time;

    // ── the motes, rising through the case ──
    final h = GoldVaultLayout.heroHeight + 30;
    for (var i = 0; i < motes; i++) {
      final p = (t * _moteSpeed[i] + _motePh[i]) % 1.0;
      final x = _moteX[i] * l.width + math.sin(t * 0.7 + _motePh[i] * 9) * 7;
      final y = h - p * (h + 8);
      // Only the middle of each climb, so they fade in and out.
      if (p < 0.08 || p > 0.92) continue;
      b.add(_moteB + _moteBig[i], x, y);
    }

    // ── the sun's light on the case ──
    final pool = Color.lerp(
      const Color(0xFFE2A23C),
      const Color(0xFFFFD27A),
      _heat,
    )!;
    canvas.drawCircle(
      c,
      r * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            pool.withValues(alpha: 0.20 + 0.08 * _heat),
            pool.withValues(alpha: 0.07),
            pool.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 2.6)),
    );

    // ── the sun ──
    final cosT = math.cos(_tip), sinT = math.sin(_tip);
    final count = _sunCount.round().clamp(0, maxSun);
    final glintRate = 0.009 + 0.03 * _heat;
    for (var i = 0; i < count; i++) {
      final lon = _lon0[i] + _omega[i] * _spin;
      final cl = math.cos(_lat[i]);
      final rr = _r[i] * r;
      final px = rr * cl * math.cos(lon);
      final py = rr * math.sin(_lat[i]);
      final pz = rr * cl * math.sin(lon);
      final x = px;
      final y = py * cosT + pz * sinT;
      final z = pz * cosT - py * sinT;
      final lam = (x * _lx + y * _ly + z * _lz) / r;
      var lit = lam * 0.5 + 0.5;
      // A slow shimmer through it, grain by grain: molten, not still.
      lit =
          (lit * lit * (3 - 2 * lit) +
                  0.07 * math.sin(t * 1.3 + _ph[i] * 40) +
                  0.12 * _heat)
              .clamp(0.0, 1.0);
      if (z < 0) {
        b.add(_farB + (lit * 3.99).floor(), c.dx + x, c.dy + y);
        continue;
      }
      if ((t * 0.27 + _ph[i] * 7.3) % 1.0 < glintRate && lit > 0.45) {
        b.add(_sunGlintB, c.dx + x, c.dy + y);
        continue;
      }
      b.add((lit * 7.99).floor(), c.dx + x, c.dy + y);
    }

    // ── the ring, tipped like the sun ──
    final ringCount = _ring.round().clamp(0, maxRing);
    const flat = 0.27, ringTurn = -0.2;
    final rc = math.cos(ringTurn), rs = math.sin(ringTurn);
    for (var i = 0; i < ringCount; i++) {
      final rad = _ringRad[i];
      final a = _ringA0[i] + t * 0.42 / (rad * math.sqrt(rad));
      final sa = math.sin(a);
      final ox = math.cos(a) * rad * r, oy = sa * rad * r * flat;
      final x = c.dx + ox * rc - oy * rs, y = c.dy + ox * rs + oy * rc;
      final bright = math.sin(t * 2.1 + _ringPh[i]) > 0.6 ? 1 : 0;
      b.add(_ringB + (sa > 0 ? 0 : 2) + bright, x, y);
    }

    // ── the corona: grains lifting off the limb, cooling as they go ──
    final coronaCount = (_corona * corona).round();
    for (var i = 0; i < coronaCount; i++) {
      final p = (t * _corSpeed[i] + _corPh[i]) % 1.0;
      final a = _corA[i] + p * 0.35;
      final rad = r * (0.96 + 0.62 * p);
      final x = c.dx + math.cos(a) * rad;
      final y = c.dy + math.sin(a) * rad - p * r * 0.22;
      b.add(_coronaB + math.min(2, (p * 3).floor()), x, y);
    }

    // ── the heaps ──
    for (var i = 0; i < _heapU.length && i < l.tablets.length; i++) {
      final base = l.heapBase(i);
      final (halfW, height) = l.heapSize(_heapSize[i]);
      final hu = _heapU[i], hv = _heapV[i], tone = _heapTone[i];
      final ph = _heapPh[i];
      final lit = i == selected;
      for (var k = 0; k < hu.length; k++) {
        final x = base.dx + hu[k] * halfW;
        final y = base.dy - hv[k] * height;
        if (lit && tone[k] >= 5 && (t * 0.31 + ph[k] * 5.1) % 1.0 < 0.012) {
          b.add(_heapGlintB, x, y);
          continue;
        }
        b.add(_heapB + (lit ? 0 : 8) + tone[k], x, y);
      }
    }

    // ── drawing, back to front ──
    b.draw(
      canvas,
      _moteB,
      1.3,
      const Color(0xFFF2C766).withValues(alpha: 0.32),
    );
    b.draw(
      canvas,
      _moteB + 1,
      2.0,
      const Color(0xFFF6D88A).withValues(alpha: 0.4),
    );

    // The far half of the ring, and the corona, go behind the sun.
    final ringD = math.max(1.1, r * 0.032);
    b.draw(canvas, _ringB + 2, ringD * 0.9, const Color(0xFF8A6428));
    b.draw(canvas, _ringB + 3, ringD, const Color(0xFFD8AE5C));
    b.draw(
      canvas,
      _coronaB,
      d * 0.95,
      const Color(0xFFFFE6A6).withValues(alpha: 0.85),
    );
    b.draw(
      canvas,
      _coronaB + 1,
      d * 0.85,
      const Color(0xFFE9A746).withValues(alpha: 0.6),
    );
    b.draw(
      canvas,
      _coronaB + 2,
      d * 0.75,
      const Color(0xFFB0581C).withValues(alpha: 0.35),
    );

    for (var k = 0; k < 4; k++) {
      b.draw(
        canvas,
        _farB + k,
        d * 0.85,
        Color.lerp(_V.tones[k * 2], const Color(0xFF000000), 0.35)!,
      );
    }
    // Its own light, from inside: a sun, not a ball of sand.
    canvas.drawCircle(
      c,
      r * 1.02,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF3C4).withValues(alpha: 0.42 + 0.2 * _heat),
            const Color(0xFFF2B544).withValues(alpha: 0.24),
            const Color(0xFFB8701C).withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.02)),
    );
    for (var k = 0; k < 8; k++) {
      b.draw(canvas, k, d, _V.tones[k]);
    }
    b.draw(canvas, _sunGlintB, d * 2.4, _V.glint.withValues(alpha: 0.2));
    b.draw(canvas, _sunGlintB, d * 1.3, _V.glint.withValues(alpha: 0.95));

    b.draw(canvas, _ringB, ringD * 0.9, const Color(0xFFB98A3E));
    b.draw(canvas, _ringB + 1, ringD * 1.1, const Color(0xFFFFE3A0));

    // The chosen heap stands in its own light.
    final sel = selected.clamp(0, l.tablets.length - 1);
    final under = l.heapBase(sel);
    canvas.save();
    canvas.translate(under.dx, under.dy - 6);
    canvas.scale(1, 0.55);
    final poolR = l.tabletWidth * 0.62;
    canvas.drawCircle(
      Offset.zero,
      poolR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE9B04A).withValues(alpha: 0.26),
            const Color(0xFFE9B04A).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: poolR)),
    );
    canvas.restore();

    const heapD = 1.9;
    for (var k = 0; k < 8; k++) {
      b.draw(canvas, _heapB + k, heapD, _V.tones[k]);
      b.draw(
        canvas,
        _heapB + 8 + k,
        heapD,
        Color.lerp(_V.tones[k], const Color(0xFF0A0703), 0.42)!,
      );
    }
    b.draw(canvas, _heapGlintB, heapD * 2.2, _V.glint.withValues(alpha: 0.2));
    b.draw(canvas, _heapGlintB, heapD * 1.2, _V.glint);
  }

  /// The pours, heap to sun (or sun back to heap) — drawn over the text, as
  /// a quick flourish, so the stream reads unbroken between shelf and sun.
  void paintPours(Canvas canvas, GoldVaultLayout l) {
    if (_pours.isEmpty) return;
    final b = _pourBatch..clear();
    final c = l.sun;
    final r = l.sunRadius * _radius;
    final d = math.max(1.6, r * 0.05);
    for (final p in _pours) {
      final u = (time - p.start) / p.duration;
      if (u < 0) continue;
      final base = l.heapBase(p.tablet);
      final (halfW, height) = l.heapSize(_heapSize[p.tablet]);
      final grain = Offset(
        base.dx + _heapU[p.tablet][p.grain] * halfW,
        base.dy - _heapV[p.tablet][p.grain] * height,
      );
      final shell =
          c + Offset(math.cos(p.angle), math.sin(p.angle)) * r * p.reach;
      final (from, to) = p.back ? (shell, grain) : (grain, shell);
      final mid = (from + to) / 2;
      final span = to - from;
      final ctrl =
          mid +
          Offset(-span.dy, span.dx) * p.bow +
          Offset(0, -span.distance * 0.3);
      for (var s = 0; s < 3; s++) {
        final e = _easeInOut((u - s * 0.04).clamp(0.0, 1.0));
        if (s > 0 && e <= 0) break;
        final m = 1 - e;
        final x = m * m * from.dx + 2 * m * e * ctrl.dx + e * e * to.dx;
        final y = m * m * from.dy + 2 * m * e * ctrl.dy + e * e * to.dy;
        b.add(s == 0 ? 0 : 1, x, y);
      }
    }
    b.draw(canvas, 1, d * 0.8, const Color(0xFFE9A746).withValues(alpha: 0.45));
    b.draw(canvas, 0, d * 1.05, const Color(0xFFFBE19A));
  }

  static double _easeInOut(double x) =>
      x < 0.5 ? 2 * x * x : 1 - math.pow(-2 * x + 2, 2) / 2;
}

class _VaultPainter extends CustomPainter {
  _VaultPainter(
    this.field,
    this.layout, {
    this.pours = false,
    required super.repaint,
  });

  final GoldVaultField field;
  final GoldVaultLayout layout;

  /// The layer over the text, which only ever holds the pours.
  final bool pours;

  @override
  void paint(Canvas canvas, Size size) =>
      pours ? field.paintPours(canvas, layout) : field.paint(canvas, layout);

  @override
  bool shouldRepaint(_VaultPainter old) =>
      old.field != field ||
      old.layout.width != layout.width ||
      old.pours != pours;
}

// ── the widget ───────────────────────────────────────────────────────────────

class GoldVaultDeck extends StatefulWidget {
  const GoldVaultDeck({
    super.key,
    required this.offers,
    required this.onBuy,
    required this.onSignIn,
    this.needsAccount = false,
    this.loading = false,
    this.awaitingVerification = 0,
    this.error,
  });

  final List<GoldVaultOffer> offers;
  final void Function(String productId) onBuy;

  /// Gold is credited to an account, so without one the button leads to
  /// signing in instead.
  final VoidCallback onSignIn;
  final bool needsAccount;

  /// The store is still being asked for prices.
  final bool loading;

  /// Purchases paid for but not yet confirmed by the server.
  final int awaitingVerification;
  final String? error;

  @override
  State<GoldVaultDeck> createState() => _GoldVaultDeckState();
}

class _GoldVaultDeckState extends State<GoldVaultDeck>
    with SingleTickerProviderStateMixin {
  late GoldVaultField _field;
  late int _selected;
  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier(0);
  Duration _last = Duration.zero;

  /// The pack the vault opens on: the one marked popular, if there is one.
  int get _initial {
    final i = widget.offers.indexWhere((o) => o.pack.badge == 'POPULAR');
    return i < 0 ? 0 : i;
  }

  List<int> get _golds => [for (final o in widget.offers) o.pack.goldAmount];

  @override
  void initState() {
    super.initState();
    _selected = _initial;
    _field = GoldVaultField(_golds, selected: _selected);
    // From the TickerProvider, so the shop's TickerMode (and its
    // ViewportTickerGate) stops it when it is covered or scrolled away.
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(GoldVaultDeck old) {
    super.didUpdateWidget(old);
    final golds = _golds;
    if (golds.length != _field.golds.length ||
        !Iterable.generate(
          golds.length,
        ).every((i) => golds[i] == _field.golds[i])) {
      _selected = _selected.clamp(0, math.max(0, golds.length - 1));
      _field = GoldVaultField(golds, selected: _selected);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    // Clamped so a ticker muted off-screen does not jump on its return.
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final busy = widget.offers.isNotEmpty && widget.offers[_selected].pending;
    _field.step(dt, busy: busy);
    _clock.value = _field.time;
  }

  void _choose(int i) {
    if (i == _selected) return;
    setState(() => _selected = i);
    _field.select(i);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) return const SizedBox.shrink();
    final bonuses = GoldVaultOffer.bonuses(widget.offers);
    var best = -1;
    for (var i = 0; i < bonuses.length; i++) {
      final v = bonuses[i];
      if (v != null && v >= 5 && (best < 0 || v > bonuses[best]!)) best = i;
    }
    final offer = widget.offers[_selected];

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = GoldVaultLayout(
          constraints.maxWidth,
          widget.offers.length,
        );
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _V.edge, width: 1),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_V.caseTop, _V.caseBottom],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _VaultPainter(_field, layout, repaint: _clock),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: GoldVaultLayout.heroHeight,
                    child: Row(
                      children: [
                        SizedBox(width: layout.sunZone),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 340),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  4,
                                  14,
                                  14,
                                  12,
                                ),
                                child: _Hero(
                                  offer: offer,
                                  needsAccount: widget.needsAccount,
                                  loading: widget.loading,
                                  onBuy: () =>
                                      widget.onBuy(offer.pack.productId),
                                  onSignIn: widget.onSignIn,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: GoldVaultLayout.tabletHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < widget.offers.length; i++)
                          Positioned.fromRect(
                            rect: layout.tablets[i].translate(
                              0,
                              -GoldVaultLayout.heroHeight,
                            ),
                            child: _Tablet(
                              offer: widget.offers[i],
                              selected: i == _selected,
                              bonus: bonuses[i],
                              tag: i == best
                                  ? 'BEST VALUE'
                                  : widget.offers[i].pack.badge == 'POPULAR'
                                  ? 'POPULAR'
                                  : null,
                              onTap: () => _choose(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _Footer(
                    needsAccount: widget.needsAccount,
                    awaitingVerification: widget.awaitingVerification,
                    error: widget.error,
                  ),
                ],
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _VaultPainter(
                      _field,
                      layout,
                      pours: true,
                      repaint: _clock,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const _mono = 'monospace';

class _Hero extends StatelessWidget {
  const _Hero({
    required this.offer,
    required this.needsAccount,
    required this.loading,
    required this.onBuy,
    required this.onSignIn,
  });

  final GoldVaultOffer offer;
  final bool needsAccount, loading;
  final VoidCallback onBuy, onSignIn;

  @override
  Widget build(BuildContext context) {
    final pack = offer.pack;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pack.title.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: _mono,
            color: _V.goldDeep,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.6,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Counts to the new amount, as the pour fills the sun.
            TweenAnimationBuilder<double>(
              tween: Tween(end: pack.goldAmount.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                '${v.round()}',
                style: const TextStyle(
                  fontFamily: _mono,
                  color: _V.goldBright,
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 7),
            const CoinIcon.gold(size: 20),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topLeft,
              children: [...previous, ?current],
            ),
            child: Text(
              pack.subtitle,
              key: ValueKey(pack.productId),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _V.muted,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        _BuyButton(
          offer: offer,
          needsAccount: needsAccount,
          loading: loading,
          onBuy: onBuy,
          onSignIn: onSignIn,
        ),
      ],
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({
    required this.offer,
    required this.needsAccount,
    required this.loading,
    required this.onBuy,
    required this.onSignIn,
  });

  final GoldVaultOffer offer;
  final bool needsAccount, loading;
  final VoidCallback onBuy, onSignIn;

  @override
  Widget build(BuildContext context) {
    final price = offer.price;
    final (String label, VoidCallback? action, bool solid) = needsAccount
        ? ('SIGN IN TO BUY', onSignIn, false)
        : offer.pending
        ? ('CONFIRMING…', null, true)
        : price == null
        ? (loading ? 'LOADING…' : 'UNAVAILABLE', null, false)
        : ('BUY · $price', onBuy, true);
    final enabled = action != null || offer.pending;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(action),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          // Gold leaf: the one bright surface in the case.
          gradient: solid
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF4D684),
                    Color(0xFFD9A443),
                    Color(0xFFA9711F),
                  ],
                  stops: [0.0, 0.5, 1.0],
                )
              : null,
          color: solid ? null : const Color(0xFF15100A),
          border: Border.all(
            color: solid
                ? const Color(0xFFFFE9A8).withValues(alpha: 0.55)
                : (enabled ? _V.edgeLit : _V.edge),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (offer.pending) ...[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  valueColor: AlwaysStoppedAnimation(_V.ink),
                ),
              ),
              const SizedBox(width: 8),
            ] else if (needsAccount) ...[
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _mono,
                  color: solid ? _V.ink : (enabled ? _V.gold : _V.muted),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tablet extends StatelessWidget {
  const _Tablet({
    required this.offer,
    required this.selected,
    required this.bonus,
    required this.tag,
    required this.onTap,
  });

  final GoldVaultOffer offer;
  final bool selected;
  final int? bonus;
  final String? tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                // Translucent, so the heap painted beneath shows through.
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: selected
                      ? [
                          _V.gold.withValues(alpha: 0.02),
                          _V.gold.withValues(alpha: 0.09),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.025),
                        ],
                ),
                border: Border.all(
                  color: selected
                      ? _V.edgeLit.withValues(alpha: 0.85)
                      : _V.edge.withValues(alpha: 0.7),
                  width: selected ? 1.2 : 0.8,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Column(
              children: [
                const SizedBox(height: GoldVaultLayout.heapZone + 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CoinIcon.gold(size: 11),
                    const SizedBox(width: 4),
                    Text(
                      '${offer.pack.goldAmount}',
                      style: TextStyle(
                        fontFamily: _mono,
                        color: selected ? _V.goldBright : _V.gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  offer.price ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? _V.parchment : _V.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (bonus != null && bonus! >= 5) ...[
                  const SizedBox(height: 2),
                  Text(
                    '+$bonus% GOLD',
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: _mono,
                      color: _V.verdigris,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (tag != null)
            Positioned(
              top: -7,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF120D07),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: (selected ? _V.edgeLit : _V.goldDeep).withValues(
                        alpha: 0.9,
                      ),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    tag!,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: _mono,
                      color: _V.gold,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.needsAccount,
    required this.awaitingVerification,
    required this.error,
  });

  final bool needsAccount;
  final int awaitingVerification;
  final String? error;

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(
      color: _V.muted,
      fontSize: 10.5,
      height: 1.4,
      fontWeight: FontWeight.w600,
    );
    final waiting = awaitingVerification == 1
        ? 'A purchase is waiting to be confirmed. It will be added as soon '
              'as you are back online.'
        : '$awaitingVerification purchases are waiting to be confirmed. '
              'They will be added as soon as you are back online.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (awaitingVerification > 0) ...[
            Text(waiting, style: small.copyWith(color: _V.gold)),
            const SizedBox(height: 6),
          ],
          if (error != null) ...[
            Text(error!, style: small.copyWith(color: _V.danger)),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  needsAccount
                      ? 'Gold is kept on your account, so sign in first — '
                            'then it follows you to any device.'
                      : 'Kept on your account — your gold follows you to '
                            'any device.',
                  style: small,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
