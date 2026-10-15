// lib/games/cosmic/works_art.dart
//
// The Works, in the stations' material (obsidian_kit.dart): stone whose
// colour is only the light inside it, glass that holds the light, grains for
// whatever moves. No outlines, no hoops, no blur.
//
//   Extractor      a rig stood on a planet's rim: a foot cut to the curve,
//                  a spine with two struts, and a glass hopper at the top.
//                  The planet's matter rises up the spine in a thin current
//                  and settles in the hopper, which fills to its level and
//                  breathes when full. Tier 2 grows a courier's ledge, tier
//                  3 a second bore with its own bulb.
//   Scavenger Bay  a horseshoe dock opening away from home, a cradle for
//                  each scavenger (lit while it rests there), its finds in
//                  small glass crates behind it, motes drifting out of the
//                  mouth while anyone is out searching.
//   Silver Press   two pillars and a beam over an anvil; a heavy ram eases
//                  down on the grains drawn in under it, and silver comes
//                  off the anvil's lip into a heap.
//   Refinery       a stone beam holding two glass flasks over a retort.
//                  Each flask turns with its input; a current pours from
//                  each into the retort, where the grains change to what
//                  they make, and what is made drips into a heap below.
//                  Tier shows as lights along the beam.
//   Armory         a gantry of two stone pylons and a beam over a pad, the
//                  player's own ship held upright in its clamps, weld
//                  sparks falling from its flank. Tier shows as lights
//                  along the beam.
//   Grain flows    matter sent from one place to another (a hopper sent
//                  home, crates emptied into home): a current of grains on a
//                  lopsided curve, each born a little after the last.
//
// Drawn about the origin in art units, scaled by the caller. The solids are
// baked once per kind (and per light for an extractor); a frame is a few
// image draws, some discs and a couple of point passes.

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';

import 'obsidian_kit.dart';
import 'ship_art.dart' show paintShipHull;

/// The Works' own lights.
const Color kScavengerBayLight = Color(0xFFE0915A);
const Color kSilverPressLight = Color(0xFFCFDCEB);
const Color kRefineryLight = Color(0xFFB9A2F2);
const Color kArmoryLight = Color(0xFFE58A5C);

/// How far each piece reaches from its origin, in art units — what a stage
/// sizes it by.
const double kExtractorReach = 64;
const double kBayReach = 46;
const double kPressReach = 44;
const double kRefineryReach = 44;
const double kArmoryReach = 44;

double _smooth(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

// ── Extractor ───────────────────────────────────────────────────────────────

/// The hopper's centre (and the second bore's), in rig units: the rig
/// stands on its foot at the origin, rising toward -y.
const Offset kHopperAt = Offset(0, -46);
const Offset kTwinHopperAt = Offset(-21, -28);
const double _hopperR = 12.5;
const double _twinR = 7.5;

/// Where the miner stands against the rig, and where a courier perches.
const Offset kMinerAt = Offset(-24, -10);
const Offset kCourierLedgeAt = Offset(19, -30);

/// Where a courier waits while it loads: off the ledge's end, clear of the
/// glass.
const Offset kCourierPerchAt = Offset(33, -40);

/// Dark glass with light inside it: a catchlight toward the key light, a
/// rim on the far side. Unit radius.
ui.Shader _glassShader(StoneLight m) => ui.Gradient.radial(
  const Offset(-0.38, -0.44),
  1.45,
  [
    m.a(m.hot, 0.32),
    m.a(m.essence, 0.1),
    m.a(m.ink, 0.92),
    m.a(m.ink, 0.92),
    m.a(m.rim, 0.55),
  ],
  const [0.0, 0.22, 0.55, 0.86, 1.0],
);

final Map<String, _ExtractorArt> _extractors = {};

/// Draws an extractor rig standing at [at] on a planet, turned by [rot]
/// (radians; 0 stands it upright, its foot toward +y). [fill] is how full
/// its hopper is (0..1), [mining] whether matter is rising into it, [wake]
/// how close the ship is.
void paintExtractor(
  Canvas c, {
  required Offset at,
  required Color essence,
  required int tier,
  required double t,
  double rot = 0,
  double scale = 1,
  double fill = 0,
  bool mining = true,
  double wake = 0,
}) {
  final key = '${essence.toARGB32()}:$tier:${(rot * 100).round()}';
  final art = _extractors[key] ??= _ExtractorArt(
    essence,
    tier.clamp(1, 3),
    rot,
  );
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(rot);
  c.scale(scale);
  art.paint(c, t, fill.clamp(0.0, 1.0), mining, wake.clamp(0.0, 1.0));
  c.restore();
}

class _ExtractorArt {
  _ExtractorArt(Color essence, this.tier, this.rot)
    : m = StoneLight(essence, warm: 0.05);

  final StoneLight m;
  final int tier;

  /// How far the rig is turned in the world, so the key light stays put.
  final double rot;

  late final ui.Shader _glass = _glassShader(m);

  CutStone _spine(double len, double w0, double w1) =>
      ridgeArm(m, 0, len, w0, w1);

  /// The foot: a crescent cut to a planet's curve, hugging it.
  late final CutStone _foot = CutStone.gem(m, [
    for (final p in crescentPoints(70, -pi / 2 - 0.36, -pi / 2 + 0.36, 9))
      p + const Offset(0, 70),
  ], const Offset(0, 2));
  late final CutStone _spineSolid = _spine(36, 6, 3.6);
  late final CutStone _strut = _spine(27, 3.2, 1.8);
  late final CutStone _twinSpine = _spine(30, 4.2, 2.6);

  /// Where the spine meets the glass: a collar the bulb sits in.
  late final CutStone _collar = CutStone.gem(m, [
    kHopperAt + const Offset(-9.5, 8.5),
    kHopperAt + const Offset(9.5, 8.5),
    kHopperAt + const Offset(6, 14.5),
    kHopperAt + const Offset(0, 16),
    kHopperAt + const Offset(-6, 14.5),
  ], kHopperAt + const Offset(0, 12));

  /// A stopper on the top of the glass.
  late final CutStone _cap = CutStone.gem(m, [
    kHopperAt + const Offset(-4.5, -11.2),
    kHopperAt + const Offset(0, -15.5),
    kHopperAt + const Offset(4.5, -11.2),
    kHopperAt + const Offset(0, -10),
  ], kHopperAt + const Offset(0, -12));

  late final CutStone _ledge = CutStone.gem(m, const [
    Offset(5, -27),
    Offset(15, -31),
    Offset(25, -30),
    Offset(22, -26),
    Offset(8, -24),
  ], const Offset(14, -28));

  /// Paints [s] stood up along -y from [base], leaning by [lean].
  void _stand(
    Canvas c,
    CutStone s,
    Offset base,
    double lean, {
    double glow = 0,
  }) {
    final a = -pi / 2 + lean;
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(a);
    s.paint(c, rot + a, glow: glow, reach: 14);
    c.restore();
  }

  late final BakedArt _body = BakedArt(const Rect.fromLTRB(-36, -66, 32, 14), (
    c,
  ) {
    if (tier >= 3) {
      _stand(c, _twinSpine, const Offset(-8, -1), -0.42);
    }
    _stand(c, _strut, const Offset(-13, 0), 0.38);
    _stand(c, _strut, const Offset(13, 0), -0.38);
    _stand(c, _spineSolid, const Offset(0, 0), 0, glow: 0.4);
    _foot.paint(c, rot, glow: 0.7, reach: 16);
    if (tier >= 2) _ledge.paint(c, rot, glow: 0.3, reach: 10);
    paintDisc(c, m.pool, kHopperAt, 22, 0.6);
    paintDisc(c, _glass, kHopperAt, _hopperR);
    if (tier >= 3) paintDisc(c, _glass, kTwinHopperAt, _twinR);
  });

  /// Stone over the glass: the collar and the stopper.
  late final BakedArt _fittings = BakedArt(
    Rect.fromCircle(center: kHopperAt, radius: _hopperR + 6),
    (c) {
      _collar.paint(c, rot, glow: 0.2, reach: 8);
      _cap.paint(c, rot, glow: 0, reach: 6);
    },
  );

  /// Grains in the hopper's glass: unit-disc positions, each turning slowly.
  static final List<(double, double, double)> _pool = () {
    final r = Random(41);
    return [
      for (var i = 0; i < 150; i++)
        (
          sqrt(r.nextDouble()),
          r.nextDouble() * 2 * pi,
          0.15 + r.nextDouble() * 0.45,
        ),
    ];
  }();

  final PointBatch _rise = PointBatch(40);
  final PointBatch _riseHot = PointBatch(12);
  final PointBatch _held = PointBatch(160);
  final PointBatch _surface = PointBatch(24);
  final PointBatch _sparks = PointBatch(16);

  void paint(Canvas c, double t, double fill, bool mining, double wake) {
    final full = fill >= 0.995;
    final beat = full ? 0.5 + 0.5 * sin(t * 3.4) : 0.0;
    paintDisc(c, m.pool, const Offset(0, -24), 60, 0.9 + 0.6 * wake);
    // The bore's light where the foot goes into the planet.
    paintDisc(c, m.leak, const Offset(0, 6), 18, mining ? 0.9 : 0.35);

    // The current: matter coming up out of the planet, along the spine and
    // into the glass. A grain's path sways a little and narrows as it rises.
    _rise.clear();
    _riseHot.clear();
    if (mining && !full) {
      final top = kHopperAt.dy + _hopperR * 0.6;
      for (var i = 0; i < 34; i++) {
        final ph = (t * 0.32 + hash01(i, 3)) % 1.0;
        final y = 10 - ph * (10 - top);
        final sway = sin(ph * 7 + hash01(i, 4) * 6) * (1 - ph) * 7;
        final x = (hash01(i, 5) - 0.5) * 14 * (1 - ph) + sway;
        (ph > 0.8 ? _riseHot : _rise).add(x, y);
      }
    }
    _body.draw(c);
    _rise.draw(c, 1.2, m.grainDim.withValues(alpha: 0.55));

    // What the hopper holds, settled to a level: a lit body of grains with
    // a brighter skin where it meets the empty glass.
    _held.clear();
    _surface.clear();
    if (fill > 0.01) {
      final r = _hopperR - 1.6;
      final level = kHopperAt.dy + r - 2 * r * fill;
      paintDisc(
        c,
        m.spark,
        Offset(kHopperAt.dx, (level + kHopperAt.dy + r) / 2 + 1),
        r * (0.45 + 0.55 * fill) * (1 + 0.15 * beat),
        0.22 + 0.36 * fill,
      );
      for (var i = 0; i < _pool.length; i++) {
        final (rr, a0, rate) = _pool[i];
        final a = a0 + t * rate * (i.isEven ? 1 : -1);
        final p = kHopperAt + polar(rr * r, a);
        if (p.dy < level) continue;
        _held.add(p.dx, p.dy);
      }
      final dy = level - kHopperAt.dy;
      final half = sqrt(max(0.0, r * r - dy * dy));
      for (var i = 0; i < 18; i++) {
        final u = (i + 0.5) / 18;
        final x = -half + 2 * half * u;
        final wave = sin(u * 9 + t * 2.1) * 0.7;
        _surface.add(x, level + wave);
      }
    }
    _held.draw(c, 1.25, m.grainDim.withValues(alpha: 0.8));
    _surface.draw(c, 1.5, m.grainHot.withValues(alpha: 0.85));
    _riseHot.draw(c, 1.5, m.grainHot);
    paintDisc(c, kGlint, kHopperAt + const Offset(-4.6, -5.4), 2.6, 0.6);
    _fittings.draw(c);

    if (tier >= 3) {
      paintDisc(
        c,
        m.spark,
        kTwinHopperAt,
        _twinR * (0.35 + 0.5 * fill),
        0.25 + 0.45 * fill,
      );
    }
    if (tier >= 2) {
      paintDisc(
        c,
        m.spark,
        kCourierLedgeAt + const Offset(3, 2),
        2.6,
        0.55 + 0.3 * wake,
      );
    }

    // Full: light rises off the stopper.
    _sparks.clear();
    if (full) {
      for (var i = 0; i < 12; i++) {
        final ph = (t * 0.4 + hash01(i, 11)) % 1.0;
        final p =
            kHopperAt +
            Offset(
              (hash01(i, 12) - 0.5) * 8 + sin(ph * 5 + i) * 2,
              -_hopperR - 3 - ph * 16,
            );
        _sparks.add(p.dx, p.dy);
      }
      _sparks.draw(
        c,
        1.4,
        m.grainHot.withValues(alpha: 0.75 * (1 - 0.3 * beat)),
      );
    }
  }
}

// ── Scavenger Bay ───────────────────────────────────────────────────────────

/// Where scavenger [i] of a [tier] bay rests, in bay units: in a cradle
/// hung under the mooring rail.
Offset bayBerthAt(int i, int tier) {
  final n = tier.clamp(1, 3);
  return Offset(-4 + (i - (n - 1) / 2) * 15, 6);
}

/// The beacon at the rail's outer end, where scavengers set out and come
/// home.
const Offset kBayMouthAt = Offset(30, -6);

final Map<int, _BayArt> _bays = {};

/// Draws the Scavenger Bay at [at], turned by [rot] so its beacon points
/// away from home. [resting] says which cradles have their scavenger home;
/// [crates] are the finds waiting (their lead colours); [searching]
/// whether anyone is out.
void paintScavengerBay(
  Canvas c, {
  required Offset at,
  required int tier,
  required double t,
  double rot = 0,
  double scale = 1,
  List<bool> resting = const [],
  List<Color> crates = const [],
  int crateCap = 6,
  bool searching = false,
  double wake = 0,
}) {
  final art = _bays[tier.clamp(1, 3)] ??= _BayArt(tier.clamp(1, 3));
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(rot);
  c.scale(scale);
  art.paint(
    c,
    t,
    rot,
    resting,
    crates,
    crateCap,
    searching,
    wake.clamp(0.0, 1.0),
  );
  c.restore();
}

class _BayArt {
  _BayArt(this.tier);
  final int tier;
  final StoneLight m = StoneLight(kScavengerBayLight, warm: 0.06);
  late final ui.Shader _glass = _glassShader(m);

  /// The mooring rail, from the hub out to the beacon.
  late final CutStone _rail = ridgeArm(m, -26, 30, 4.4, 3);

  /// The hub at the inner end, toward home.
  late final CutStone _hub = CutStone.gem(m, [
    for (var i = 0; i < 6; i++) const Offset(-30, -6) + polar(9, i * pi / 3),
  ], const Offset(-30, -6));

  /// A cradle under the rail: a cup open upward, on a short hanger.
  late final List<CutStone> _cradles = [
    for (var i = 0; i < tier; i++)
      () {
        final at = bayBerthAt(i, tier);
        return CutStone.gem(m, [
          for (final p in crescentPoints(6.5, 0.15, pi - 0.15, 3.6, n: 10))
            at + p,
        ], at + const Offset(0, 4));
      }(),
  ];
  late final CutStone _hanger = ridgeArm(m, 0, 8, 1.4, 1.1);

  /// Crates ride on top of the rail: up to six glass capsules.
  static final List<Offset> _crateSlots = [
    for (var i = 0; i < 6; i++) Offset(-17 + i * 7.6, -12.5),
  ];

  BakedArt? _bodyBaked;
  double _bakedRot = double.nan;

  BakedArt _body(double rot) {
    if (_bodyBaked == null || (rot - _bakedRot).abs() > 0.01) {
      _bakedRot = rot;
      _bodyBaked = BakedArt(const Rect.fromLTRB(-42, -22, 40, 20), (c) {
        for (var i = 0; i < tier; i++) {
          final at = bayBerthAt(i, tier);
          c.save();
          c.translate(at.dx, -6);
          c.rotate(pi / 2);
          _hanger.paint(c, rot + pi / 2, glow: 0);
          c.restore();
        }
        c.save();
        c.translate(0, -6);
        _rail.paint(c, rot, glow: 0.3, reach: 16);
        c.restore();
        _hub.paint(c, rot, glow: 0.8, reach: 12);
        for (final s in _cradles) {
          s.paint(c, rot, glow: 0.25, reach: 6);
        }
        for (final at in _crateSlots) {
          paintDisc(c, _glass, at, 3.1);
        }
        paintDisc(c, _glass, kBayMouthAt, 4.6);
      });
    }
    return _bodyBaked!;
  }

  final PointBatch _motes = PointBatch(40);

  void paint(
    Canvas c,
    double t,
    double rot,
    List<bool> resting,
    List<Color> crates,
    int crateCap,
    bool searching,
    double wake,
  ) {
    final breathe = 0.85 + 0.15 * sin(t * 2.2);
    paintDisc(c, m.pool, const Offset(-2, -2), 56, 0.9 + 0.6 * wake);

    // Searching: the beacon sweeps a fan of motes out into the dark.
    _motes.clear();
    if (searching) {
      final sweep = sin(t * 0.7) * 0.5;
      for (var i = 0; i < 30; i++) {
        final ph = (t * 0.16 + hash01(i, 21)) % 1.0;
        final spread = sweep + (hash01(i, 22) - 0.5) * (0.3 + ph * 0.7);
        final p = kBayMouthAt + polar(4 + ph * 40, spread);
        _motes.add(p.dx, p.dy);
      }
    }
    _motes.draw(c, 1.2, m.grainDim.withValues(alpha: 0.5));

    _body(rot).draw(c);
    paintDisc(c, m.spark, const Offset(-30, -6), 3.6 * breathe, 0.75);
    paintDisc(
      c,
      m.spark,
      kBayMouthAt,
      (searching ? 4.2 : 2.6) * breathe * (1 + 0.2 * wake),
      searching ? 0.9 : 0.5,
    );

    // A cradle with its scavenger home is lit.
    for (var i = 0; i < tier; i++) {
      final home = i < resting.length && resting[i];
      paintDisc(c, m.leak, bayBerthAt(i, tier), 9, home ? 0.95 : 0.22);
    }

    // Each capsule holding a find glows in what it holds.
    final shown = crateCap <= 0
        ? 0
        : (crates.length / crateCap * _crateSlots.length).ceil().clamp(
            0,
            _crateSlots.length,
          );
    for (var i = 0; i < shown; i++) {
      final col = crates.isEmpty ? m.essence : crates[i % crates.length];
      final cm = stoneLightFor(col);
      paintDisc(c, cm.leak, _crateSlots[i], 5.5, 0.9);
      paintOrb(c, cm, _crateSlots[i], 2.4 * (0.94 + 0.06 * breathe));
    }
  }
}

// ── Silver Press ────────────────────────────────────────────────────────────

final Map<int, _PressArt> _presses = {};

/// Draws the Silver Press at [at]. [pressing] while it has a presser and
/// something over the reserve; [intake] the colours going in.
void paintSilverPress(
  Canvas c, {
  required Offset at,
  required int tier,
  required double t,
  double scale = 1,
  bool pressing = false,
  List<Color> intake = const [],
  double wake = 0,
}) {
  final art = _presses[tier.clamp(1, 3)] ??= _PressArt(tier.clamp(1, 3));
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(scale);
  art.paint(c, t, pressing, intake, wake.clamp(0.0, 1.0));
  c.restore();
}

class _PressArt {
  _PressArt(this.tier);
  final int tier;
  final StoneLight m = StoneLight(kSilverPressLight, warm: 0.02);

  /// The glass column the matter is pressed in.
  static const double _colTop = -20, _colBottom = 13, _colHalf = 7.5;

  late final Path _colPath = Path()
    ..addRRect(
      RRect.fromLTRBR(
        -_colHalf,
        _colTop,
        _colHalf,
        _colBottom,
        const Radius.circular(3),
      ),
    );
  late final ui.Shader _colGlass = ui.Gradient.linear(
    const Offset(-_colHalf, 0),
    const Offset(_colHalf, 0),
    [
      m.a(m.rim, 0.42),
      m.a(m.essence, 0.08),
      m.a(m.ink, 0.88),
      m.a(m.ink, 0.88),
      m.a(m.rim, 0.3),
    ],
    const [0.0, 0.18, 0.45, 0.85, 1.0],
  );

  late final CutStone _rod = ridgeArm(m, 0, 44, 2.4, 2);
  late final CutStone _anvil = CutStone.gem(m, const [
    Offset(-17, 13),
    Offset(17, 13),
    Offset(20, 18),
    Offset(15, 23),
    Offset(-15, 23),
    Offset(-20, 18),
  ], Offset(0, 17));
  late final CutStone _crown = CutStone.gem(m, const [
    Offset(-16, -21),
    Offset(-12, -28),
    Offset(-4, -29),
    Offset(-1, -34),
    Offset(1, -34),
    Offset(4, -29),
    Offset(12, -28),
    Offset(16, -21),
  ], Offset(0, -25));
  late final CutStone _spout = CutStone.gem(m, const [
    Offset(14, 15),
    Offset(23, 17),
    Offset(16, 20),
  ], Offset(17, 17));
  late final CutStone _ram = CutStone.gem(m, const [
    Offset(-6.2, -3),
    Offset(6.2, -3),
    Offset(6.2, 2.5),
    Offset(0, 4),
    Offset(-6.2, 2.5),
  ], Offset(0, 0));
  late final CutStone _shaft = ridgeArm(m, 0, 14, 1.6, 1.6);

  late final BakedArt _frame = BakedArt(const Rect.fromLTRB(-26, -38, 30, 28), (
    c,
  ) {
    for (final x in [-13.0, 13.0]) {
      c.save();
      c.translate(x, 18);
      c.rotate(-pi / 2);
      _rod.paint(c, -pi / 2, glow: 0, reach: 8);
      c.restore();
    }
    paintFill(c, _colPath, _colGlass);
    _anvil.paint(c, 0, glow: 0.5, reach: 14);
    _spout.paint(c, 0, glow: 0.2, reach: 6);
  });

  late final BakedArt _crownBaked = BakedArt(
    const Rect.fromLTRB(-18, -36, 18, -19),
    (c) {
      _crown.paint(c, 0, glow: 0.6, reach: 12);
      for (var i = 0; i < tier; i++) {
        paintOrb(c, m, Offset(-7.0 + i * 7, -24.5), 1.7, alpha: 0.9);
      }
    },
  );

  late final BakedArt _ramBaked = BakedArt(const Rect.fromLTRB(-8, -18, 8, 6), (
    c,
  ) {
    c.save();
    c.translate(0, -3);
    c.rotate(-pi / 2);
    _shaft.paint(c, -pi / 2, glow: 0);
    c.restore();
    _ram.paint(c, 0, glow: 0.3, reach: 8);
  });

  /// The silver heap under the spout: settled grains.
  static final List<Offset> _heap = () {
    final r = Random(57);
    return [
      for (var i = 0; i < 46; i++)
        () {
          final x = (r.nextDouble() - 0.5) * 2;
          final h = 1 - x.abs();
          return Offset(25 + x * 9, 29 - r.nextDouble() * h * 6);
        }(),
    ];
  }();

  final PointBatch _in = PointBatch(30);
  final PointBatch _charge = PointBatch(60);
  final PointBatch _falling = PointBatch(24);
  final PointBatch _heapPts = PointBatch(50);

  void paint(
    Canvas c,
    double t,
    bool pressing,
    List<Color> intake,
    double wake,
  ) {
    paintDisc(c, m.pool, const Offset(0, -2), 54, 0.8 + 0.6 * wake);
    // One stroke every few seconds: the ram eases down onto the charge,
    // holds, eases back up while more matter pours in.
    const period = 3.6;
    final ph = (t % period) / period;
    final down = pressing
        ? (ph < 0.42
              ? _smooth(ph / 0.42)
              : ph < 0.58
              ? 1.0
              : 1 - _smooth((ph - 0.58) / 0.42))
        : 0.0;
    final ramY = -12 + down * 15;
    final inCol = intake.isEmpty
        ? m.grainDim
        : intake[(t / period).floor() % intake.length];

    // Matter poured in at the crown, falling into the column.
    _in.clear();
    if (pressing) {
      for (var i = 0; i < 22; i++) {
        final q = (t * 0.35 + hash01(i, 31)) % 1.0;
        final x = -26 + hash01(i, 32) * 8;
        final from = Offset(x, -40 + hash01(i, 33) * 6);
        const to = Offset(0, -24);
        final p = Offset.lerp(from, to, _smooth(q))!;
        _in.add(p.dx + sin(q * 5 + i) * 1.4, p.dy);
      }
    }
    // The charge in the column under the ram: deeper as it waits, packed
    // thin as the ram comes down.
    _charge.clear();
    if (pressing) {
      final depth = 8 - 5 * down;
      for (var i = 0; i < 46; i++) {
        final x = (hash01(i, 36) - 0.5) * (_colHalf * 2 - 3);
        final y = _colBottom - 1.5 - hash01(i, 37) * depth;
        _charge.add(x + sin(t * 2 + i) * 0.4, y);
      }
    }

    _frame.draw(c);
    paintDisc(c, m.leak, const Offset(0, 8), 12, 0.3 + 0.65 * down);
    _charge.draw(c, 1.2, inCol.withValues(alpha: 0.9));
    c.save();
    c.translate(0, ramY);
    _ramBaked.draw(c);
    c.restore();
    _crownBaked.draw(c);
    _in.draw(c, 1.3, inCol.withValues(alpha: 0.7));

    // Silver off the spout into the heap.
    _falling.clear();
    if (pressing) {
      for (var i = 0; i < 14; i++) {
        final q = (t * 0.5 + hash01(i, 41)) % 1.0;
        final p = Offset(
          22 + q * 3 + (hash01(i, 42) - 0.5) * 2.4,
          18 + q * q * 11,
        );
        _falling.add(p.dx, p.dy);
      }
    }
    _heapPts.clear();
    for (final p in _heap) {
      _heapPts.add(p.dx, p.dy);
    }
    _heapPts.draw(c, 1.3, m.grainDim.withValues(alpha: pressing ? 0.85 : 0.45));
    _falling.draw(c, 1.6, m.grainHot);
    if (pressing) {
      final g = _heap[(t * 3).floor() % _heap.length];
      paintDisc(c, kGlint, g, 2.2, 0.6);
    }
  }
}

// ── Refinery ────────────────────────────────────────────────────────────────

/// The flasks' and the retort's centres, in refinery units.
const Offset kFlaskAAt = Offset(-21, -9);
const Offset kFlaskBAt = Offset(21, -9);
const Offset kRetortAt = Offset(0, 12);
const double _flaskR = 8.5;
const double _retortR = 11.5;

final Map<int, _RefineryArt> _refineries = {};

/// Draws the Refinery at [at]. [inA] and [inB] are the colours going in and
/// [out] the colour made (null with no recipe chosen); [working] while it
/// has a refiner and both inputs to spare.
void paintRefinery(
  Canvas c, {
  required Offset at,
  required int tier,
  required double t,
  double scale = 1,
  Color? inA,
  Color? inB,
  Color? out,
  bool working = false,
  double wake = 0,
}) {
  final art = _refineries[tier.clamp(1, 3)] ??= _RefineryArt(tier.clamp(1, 3));
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(scale);
  art.paint(c, t, inA, inB, out, working, wake.clamp(0.0, 1.0));
  c.restore();
}

class _RefineryArt {
  _RefineryArt(this.tier);
  final int tier;
  final StoneLight m = StoneLight(kRefineryLight, warm: 0.04);
  late final ui.Shader _glass = _glassShader(m);

  late final CutStone _beam = ridgeArm(m, 0, 54, 4.2, 3.6);
  late final CutStone _hanger = ridgeArm(m, 0, 10, 1.8, 1.4);
  late final CutStone _spine = ridgeArm(m, 0, 26, 3, 2.2);

  /// The band round a glass's neck, where its hanger holds it: narrow, so
  /// the glass reads as a flask hung up, not a lidded eye.
  CutStone _neck(Offset top, double w) => CutStone.gem(m, [
    top + Offset(-w / 2, -3.2),
    top + Offset(w / 2, -3.2),
    top + Offset(w / 2 + 1, 0.9),
    top + Offset(-w / 2 - 1, 0.9),
  ], top + const Offset(0, -1.2));

  late final CutStone _neckA = _neck(
    kFlaskAAt + const Offset(0, -_flaskR + 0.6),
    5,
  );
  late final CutStone _neckB = _neck(
    kFlaskBAt + const Offset(0, -_flaskR + 0.6),
    5,
  );
  late final CutStone _neckRetort = _neck(
    kRetortAt + const Offset(0, -_retortR + 0.6),
    6.5,
  );

  /// The cradle the retort sits in.
  late final CutStone _cradle = CutStone.gem(m, [
    for (final p in crescentPoints(_retortR + 2, pi * 0.12, pi * 0.88, 4.4))
      kRetortAt + p,
  ], kRetortAt + const Offset(0, _retortR));

  late final BakedArt _body = BakedArt(const Rect.fromLTRB(-34, -36, 34, 34), (
    c,
  ) {
    // The spine down from the beam, holding the retort by its neck.
    c.save();
    c.translate(0, -27);
    c.rotate(pi / 2);
    _spine.paint(c, pi / 2, glow: 0.2, reach: 10);
    c.restore();
    for (final x in [kFlaskAAt.dx, kFlaskBAt.dx]) {
      c.save();
      c.translate(x, -27);
      c.rotate(pi / 2);
      _hanger.paint(c, pi / 2);
      c.restore();
    }
    c.save();
    c.translate(-27, -29);
    _beam.paint(c, 0, glow: 0.3, reach: 14);
    c.restore();
    // The tier, as beads along the beam to one side of the spine.
    for (var i = 0; i < tier; i++) {
      paintOrb(c, m, Offset(7.0 + i * 5.5, -29), 1.5, alpha: 0.9);
    }
    paintDisc(c, _glass, kFlaskAAt, _flaskR);
    paintDisc(c, _glass, kFlaskBAt, _flaskR);
    paintDisc(c, _glass, kRetortAt, _retortR);
    _neckA.paint(c, 0, glow: 0.2, reach: 5);
    _neckB.paint(c, 0, glow: 0.2, reach: 5);
    _neckRetort.paint(c, 0, glow: 0.3, reach: 6);
    _cradle.paint(c, 0, glow: 0.4, reach: 10);
  });

  /// The made heap under the retort: settled grains.
  static final List<Offset> _heap = () {
    final r = Random(71);
    return [
      for (var i = 0; i < 40; i++)
        () {
          final x = (r.nextDouble() - 0.5) * 2;
          final h = 1 - x.abs();
          return Offset(x * 10, 33 - r.nextDouble() * h * 5);
        }(),
    ];
  }();

  final PointBatch _a = PointBatch(40);
  final PointBatch _b = PointBatch(40);
  final PointBatch _made = PointBatch(70);
  final PointBatch _heapPts = PointBatch(44);

  /// Grains turning in a glass of radius [r] at [at], [n] of them.
  void _swirl(PointBatch into, Offset at, double r, double t, int n, int salt) {
    for (var i = 0; i < n; i++) {
      final rr = sqrt(hash01(i, salt)) * (r - 1.4);
      final a = hash01(i, salt + 1) * 2 * pi + t * (0.5 + hash01(i, salt + 2));
      final p = at + polar(rr, a);
      // Settled toward the bottom of the glass.
      into.add(p.dx, p.dy + (r - rr) * 0.25);
    }
  }

  /// A current from a flask's mouth to the retort's: [n] grains on an arc.
  void _pour(PointBatch into, Offset from, double t, int n, int salt) {
    final to = kRetortAt + const Offset(0, -_retortR + 2);
    final mid = Offset((from.dx + to.dx) / 2, from.dy + 4);
    for (var i = 0; i < n; i++) {
      final u = (t * 0.45 + hash01(i, salt)) % 1.0;
      final q = Offset.lerp(
        Offset.lerp(from, mid, u)!,
        Offset.lerp(mid, to, u)!,
        u,
      )!;
      into.add(q.dx + sin(u * 7 + i) * 0.8, q.dy);
    }
  }

  void paint(
    Canvas c,
    double t,
    Color? inA,
    Color? inB,
    Color? out,
    bool working,
    double wake,
  ) {
    final breathe = 0.86 + 0.14 * sin(t * 2.3);
    paintDisc(c, m.pool, const Offset(0, -2), 56, 0.85 + 0.6 * wake);
    final la = inA == null ? null : stoneLightFor(inA);
    final lb = inB == null ? null : stoneLightFor(inB);
    final lo = out == null ? null : stoneLightFor(out);
    if (la != null) paintDisc(c, la.pool, kFlaskAAt, 22, working ? 1.2 : 0.6);
    if (lb != null) paintDisc(c, lb.pool, kFlaskBAt, 22, working ? 1.2 : 0.6);
    if (lo != null) paintDisc(c, lo.pool, kRetortAt, 30, working ? 1.4 : 0.6);
    _body.draw(c);

    _a.clear();
    _b.clear();
    _made.clear();
    if (la != null) _swirl(_a, kFlaskAAt, _flaskR, t, 26, 3);
    if (lb != null) _swirl(_b, kFlaskBAt, _flaskR, t, 26, 9);
    if (working && la != null && lb != null) {
      _pour(_a, kFlaskAAt + const Offset(3, _flaskR - 1), t, 12, 15);
      _pour(_b, kFlaskBAt + const Offset(-3, _flaskR - 1), t, 12, 21);
    }
    if (lo != null) {
      _swirl(_made, kRetortAt, _retortR, t * 1.3, working ? 56 : 30, 27);
    }
    if (la != null) _a.draw(c, 1.25, la.grainHot);
    if (lb != null) _b.draw(c, 1.25, lb.grainHot);
    if (lo != null) {
      paintDisc(
        c,
        lo.spark,
        kRetortAt,
        _retortR * 0.55 * breathe,
        working ? 0.7 : 0.3,
      );
      _made.draw(c, 1.35, lo.grainHot);
    }
    paintDisc(c, kGlint, kFlaskAAt + const Offset(-4.4, -1.2), 1.4, 0.35);
    paintDisc(c, kGlint, kFlaskBAt + const Offset(-4.4, -1.2), 1.4, 0.35);
    paintDisc(c, kGlint, kRetortAt + const Offset(-4.2, -4.6), 2.3, 0.6);

    // What is made drips from the retort into its heap.
    _heapPts.clear();
    if (lo != null) {
      for (final p in _heap) {
        _heapPts.add(p.dx, p.dy);
      }
      _heapPts.draw(
        c,
        1.25,
        lo.grainDim.withValues(alpha: working ? 0.85 : 0.45),
      );
      if (working) {
        final q = (t * 0.8) % 1.0;
        paintDisc(
          c,
          lo.spark,
          Offset(0, kRetortAt.dy + _retortR + 3 + q * 6),
          1.6,
          1 - q,
        );
      }
    }
    paintDisc(c, m.spark, const Offset(0, -29), 2.6 * breathe, 0.7);
  }
}

// ── Armory ──────────────────────────────────────────────────────────────────

final Map<int, _ArmoryArt> _armories = {};

/// Draws the Armory at [at], holding the hull [skin] (null: the standard
/// hull) in its gantry.
void paintArmory(
  Canvas c, {
  required Offset at,
  required int tier,
  required double t,
  double scale = 1,
  String? skin,
  double wake = 0,
}) {
  final art = _armories[tier.clamp(1, 3)] ??= _ArmoryArt(tier.clamp(1, 3));
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(scale);
  art.paint(c, t, skin, wake.clamp(0.0, 1.0));
  c.restore();
}

class _ArmoryArt {
  _ArmoryArt(this.tier);
  final int tier;
  final StoneLight m = StoneLight(kArmoryLight, warm: 0.0);

  late final CutStone _pylon = ridgeArm(m, 0, 50, 4.6, 3.4);
  late final CutStone _beam = ridgeArm(m, 0, 52, 4.2, 3.8);
  late final CutStone _clamp = ridgeArm(m, 0, 11, 2.4, 1.8);
  late final CutStone _pad = CutStone.gem(m, const [
    Offset(-24, 18),
    Offset(24, 18),
    Offset(27, 22),
    Offset(22, 27),
    Offset(-22, 27),
    Offset(-27, 22),
  ], Offset(0, 21));

  late final BakedArt _frame = BakedArt(const Rect.fromLTRB(-32, -38, 32, 30), (
    c,
  ) {
    for (final x in [-20.0, 20.0]) {
      c.save();
      c.translate(x, 18);
      c.rotate(-pi / 2);
      _pylon.paint(c, -pi / 2, glow: 0, reach: 10);
      c.restore();
    }
    c.save();
    c.translate(-26, -32);
    _beam.paint(c, 0, glow: 0.3, reach: 12);
    c.restore();
    _pad.paint(c, 0, glow: 0.7, reach: 18);
    for (var i = 0; i < tier; i++) {
      paintOrb(c, m, Offset(-7.0 + i * 7, -32), 1.7, alpha: 0.9);
    }
  });

  /// The clamps reach in from the pylons and hold the hull: drawn over it.
  late final BakedArt _clamps = BakedArt(const Rect.fromLTRB(-22, -12, 22, 0), (
    c,
  ) {
    c.save();
    c.translate(-19, -6);
    _clamp.paint(c, 0, glow: 0);
    c.restore();
    c.save();
    c.translate(19, -6);
    c.rotate(pi);
    _clamp.paint(c, pi, glow: 0);
    c.restore();
  });

  final PointBatch _sparks = PointBatch(24);
  final PointBatch _hot = PointBatch(8);

  /// The docked hull, baked for the skin it wears: dozens of cut faces with
  /// their own light, still while it sits in the gantry. Finer than a
  /// station's bake, since the home buildings stand larger.
  BakedArt? _hullBaked;
  String? _hullSkin;

  BakedArt _hull(String? skin) {
    if (_hullBaked == null || skin != _hullSkin) {
      _hullBaked?.dispose();
      _hullSkin = skin;
      _hullBaked = BakedArt(
        const Rect.fromLTRB(-39, -37, 39, 32),
        (c) => paintShipHull(c, skin, 0, engines: 0.25),
        ppu: 8,
      );
    }
    return _hullBaked!;
  }

  void paint(Canvas c, double t, String? skin, double wake) {
    final breathe = 0.86 + 0.14 * sin(t * 2.1);
    paintDisc(c, m.pool, const Offset(0, 4), 58, 0.9 + 0.6 * wake);
    _frame.draw(c);
    // The hull, upright in the gantry, its engines banked low.
    c.save();
    c.translate(0, -3);
    c.scale(0.78);
    _hull(skin).draw(c);
    c.restore();
    _clamps.draw(c);

    // Welding on its flank: sparks spill and fall away, now and then.
    const weld = Offset(7, 2);
    final on = sin(t * 0.9) > -0.35;
    _sparks.clear();
    _hot.clear();
    if (on) {
      for (var i = 0; i < 18; i++) {
        final q = (t * 0.9 + hash01(i, 81)) % 1.0;
        final vx = (hash01(i, 82) - 0.3) * 22;
        final p = weld + Offset(vx * q, -6 * q + 30 * q * q);
        (q < 0.25 ? _hot : _sparks).add(p.dx, p.dy);
      }
      paintDisc(c, m.spark, weld, 3.2 * breathe, 0.9);
    }
    _sparks.draw(c, 1.2, m.grainDim.withValues(alpha: 0.7));
    _hot.draw(c, 1.6, m.grainHot);
  }
}

// ── Grain flows ─────────────────────────────────────────────────────────────

/// A current of grains from [from] to [to], [p] of the way through its run
/// (0..1). Grains are born over the first part of the run and each takes its
/// own lopsided path, bowing to one side, trailing two fainter points; all
/// have arrived and gone by p = 1. [colors] are what is moving.
void paintGrainFlow(
  Canvas c, {
  required Offset from,
  required Offset to,
  required double p,
  required List<Color> colors,
  int seed = 0,
  int count = 90,
  double grain = 1.6,
}) {
  if (p <= 0 || p >= 1 || colors.isEmpty) return;
  final d = to - from;
  final len = d.distance;
  if (len < 1) return;
  final n = Offset(-d.dy, d.dx) / len;
  final bow = len * 0.22 * (hash01(seed, 7) > 0.5 ? 1 : -1);
  Offset at(double u, double side) {
    final k = 4 * u * (1 - u);
    return from + d * u + n * (bow * k + side * k);
  }

  for (var ci = 0; ci < colors.length; ci++) {
    _flowHead.clear();
    _flowTail.clear();
    for (var i = ci; i < count; i += colors.length) {
      final born = hash01(i + seed * 131, 1) * 0.45;
      final u = ((p - born) / 0.55).clamp(0.0, 1.0);
      if (u <= 0 || u >= 1) continue;
      final e = _smooth(u);
      final side = (hash01(i + seed * 131, 2) - 0.5) * len * 0.08;
      final h = at(e, side);
      _flowHead.add(h.dx, h.dy);
      for (final back in const [0.03, 0.06]) {
        final q = at((e - back).clamp(0.0, 1.0), side);
        _flowTail.add(q.dx, q.dy);
      }
    }
    final col = colors[ci];
    _flowTail.draw(c, grain * 0.8, col.withValues(alpha: 0.32));
    _flowHead.draw(c, grain, Color.lerp(col, const Color(0xFFFFFFFF), 0.35)!);
  }
}

/// A faint, steady current of grains from [from] to [to]: what a building
/// beside home sends to it, or (the Armory) draws from it. Sparse and slow,
/// on a gentle bow, the grains thinning at both ends so the current seems
/// to rise out of one and settle into the other. Never a line.
void paintSupplyLine(
  Canvas c, {
  required Offset from,
  required Offset to,
  required Color color,
  required double t,
  int seed = 0,
  int count = 30,
  double grain = 2.2,
}) {
  final d = to - from;
  final len = d.distance;
  if (len < 1) return;
  final n = Offset(-d.dy, d.dx) / len;
  final bow = len * 0.07 * (hash01(seed, 3) > 0.5 ? 1 : -1);
  _flowHead.clear();
  _flowTail.clear();
  for (var i = 0; i < count; i++) {
    final u = (t * 0.12 + hash01(i + seed * 31, 4)) % 1.0;
    final k = 4 * u * (1 - u);
    final side = (hash01(i + seed * 31, 5) - 0.5) * 12;
    final p = from + d * u + n * (bow * k + side * k);
    (u > 0.18 && u < 0.82 ? _flowHead : _flowTail).add(p.dx, p.dy);
  }
  _flowTail.draw(c, grain * 0.8, color.withValues(alpha: 0.3));
  _flowHead.draw(
    c,
    grain,
    Color.lerp(color, const Color(0xFFFFFFFF), 0.2)!.withValues(alpha: 0.7),
  );
}

final PointBatch _flowHead = PointBatch(200);
final PointBatch _flowTail = PointBatch(400);

/// A small glass pod of [color] slung under a worker carrying a load: a few
/// grains turning in a bead of light. [load] 0..1 sizes it.
void paintCarriedPod(Canvas c, Offset at, Color color, double t, double load) {
  if (load <= 0.01) return;
  final m = stoneLightFor(color);
  final r = 3.5 + 3.5 * load.clamp(0.0, 1.0);
  paintDisc(c, m.pool, at, r * 3.2, 0.9);
  paintDisc(c, m.spark, at, r, 0.85);
  _pod.clear();
  for (var i = 0; i < 9; i++) {
    final a = hash01(i, 51) * 2 * pi + t * (1.2 + hash01(i, 52));
    final p = at + polar(r * (0.9 + 0.5 * hash01(i, 53)), a);
    _pod.add(p.dx, p.dy);
  }
  _pod.draw(c, 1.2, m.grainHot);
}

final PointBatch _pod = PointBatch(12);

/// A faint wake of grains behind something flying from [from] toward
/// [heading] (unit), [color].
void paintWorkerWake(
  Canvas c,
  Offset at,
  Offset heading,
  Color color,
  double t,
) {
  _wake.clear();
  for (var i = 0; i < 10; i++) {
    final ph = (t * 1.1 + hash01(i, 61)) % 1.0;
    final p =
        at -
        heading * (6 + ph * 26) +
        Offset(-heading.dy, heading.dx) * ((hash01(i, 62) - 0.5) * 6 * ph);
    _wake.add(p.dx, p.dy);
  }
  _wake.draw(c, 1.2, color.withValues(alpha: 0.4));
}

final PointBatch _wake = PointBatch(12);
