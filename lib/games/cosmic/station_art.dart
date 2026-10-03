// lib/games/cosmic/station_art.dart
//
// The six stations of open space, in the ship's material: obsidian plates
// whose colour comes only from the light inside them, glass that holds that
// light, and grains for anything that moves. Nothing strokes an outline or a
// hoop. Each one is shaped by what it does:
//
//   Harvester Shop     a foundry hub with five harvester pods docked on arms,
//                      one per elemental group
//   Rift Key Shop      an obsidian monolith with a keyhole cut through it and
//                      a small rift turning inside, five keys circling it
//   Cosmic Market      a lantern spire with four crescent berths, a specimen
//                      capsule in each, trade grains running to the lantern
//   Gold Conversion    a crucible pouring molten gold into a sphere that
//                      gives off the violet grains of astral shards
//   Star Dust Scanner  three glass lenses turning round a core, sweeping the
//                      dark with a fan of motes; it locks on while tracking
//   Planet Scanner     a glass globe inside tilted rings of grains, with an
//                      obsidian needle that swings to its target
//
// Drawn centred on the origin in station units (about 60 across the body,
// a little more with what orbits it), then scaled by the caller. Plates and
// their gradients are built once per station; a frame costs about thirty
// draws and a handful of point passes.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart' show POIType;
import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:flutter/painting.dart';

enum StationKind {
  harvester,
  riftKey,
  market,
  goldConversion,
  starDustScanner,
  planetScanner,
}

StationKind? stationKindFor(POIType type) => switch (type) {
  POIType.harvesterMarket => StationKind.harvester,
  POIType.riftKeyMarket => StationKind.riftKey,
  POIType.cosmicMarket => StationKind.market,
  POIType.goldConversion => StationKind.goldConversion,
  POIType.stardustScanner => StationKind.starDustScanner,
  POIType.planetScanner => StationKind.planetScanner,
  _ => null,
};

extension StationKindX on StationKind {
  /// The station's light, which is also its colour on the map and the HUD.
  Color get accent => switch (this) {
    StationKind.harvester => const Color(0xFFFFB300),
    StationKind.riftKey => const Color(0xFF8C62FF),
    StationKind.market => const Color(0xFF3FE0F0),
    StationKind.goldConversion => const Color(0xFFFFD34A),
    StationKind.starDustScanner => const Color(0xFFA8D86E),
    StationKind.planetScanner => const Color(0xFF6CB8F6),
  };

  String get title => switch (this) {
    StationKind.harvester => 'HARVESTER SHOP',
    StationKind.riftKey => 'RIFT KEY SHOP',
    StationKind.market => 'COSMIC MARKET',
    StationKind.goldConversion => 'GOLD CONVERSION',
    StationKind.starDustScanner => 'STAR DUST SCANNER',
    StationKind.planetScanner => 'PLANET SCANNER',
  };

  /// How far its art reaches from the centre, in station units.
  double get reach => switch (this) {
    StationKind.starDustScanner => 96,
    StationKind.planetScanner => 58,
    _ => 62,
  };
}

/// The five elemental groups' colours, in harvester/key order.
const List<Color> kStationGroupColors = [
  Color(0xFFEF5350), // volcanic
  Color(0xFF42A5F5), // oceanic
  Color(0xFF8D6E63), // earthen
  Color(0xFF66BB6A), // verdant
  Color(0xFFAB47BC), // arcane
];

const Color _shardViolet = Color(0xFFC77DFF);

/// Draws the station [kind] centred on [at].
///
/// [t] is the station's own clock in seconds. [scale] maps station units to
/// world units. [wake] (0..1) is how close the ship is: the light inside
/// rises to meet it. [aim] is the world angle a scanner is tracking toward,
/// or null while it searches. [highlight] lights one docked thing (a pod, a
/// key, a berth) for the shop that is showing it.
void paintStation(
  Canvas c,
  StationKind kind, {
  required Offset at,
  required double t,
  double scale = 1,
  double wake = 0,
  double? aim,
  int? highlight,
}) {
  final art = _stations[kind] ??= switch (kind) {
    StationKind.harvester => _Foundry(),
    StationKind.riftKey => _Keywright(),
    StationKind.market => _Market(),
    StationKind.goldConversion => _Crucible(),
    StationKind.starDustScanner => _DustScanner(),
    StationKind.planetScanner => _PlanetScanner(),
  };
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(scale);
  art.paint(c, t, wake.clamp(0.0, 1.0), aim, highlight);
  c.restore();
}

final Map<StationKind, _Station> _stations = {};

abstract class _Station {
  void paint(Canvas c, double t, double wake, double? aim, int? highlight);
}

// ── Harvester Foundry ───────────────────────────────────────────────────────

class _Foundry extends _Station {
  final StoneLight m = StoneLight(StationKind.harvester.accent, warm: 0.02);

  static double _armAngle(int g) => g * 2 * pi / 5 - pi / 2;

  late final CutStone _hub = CutStone.gem(m, [
    for (var i = 0; i < 6; i++) polar(23, i * pi / 3 - pi / 2),
  ], Offset.zero);
  late final CutStone _armSolid = ridgeArm(m, 16, 41, 5, 3);

  /// A clasp at the end of each arm, under the pod.
  late final CutStone _clasp = CutStone.gem(m, [
    const Offset(36, 0),
    const Offset(42, -7.5),
    const Offset(50, -9),
    const Offset(46, 0),
    const Offset(50, 9),
    const Offset(42, 7.5),
  ], const Offset(43, 0));

  late final BakedArt _body = BakedArt(
    Rect.fromCircle(center: Offset.zero, radius: 72),
    (c) {
      for (var g = 0; g < 5; g++) {
        final a = _armAngle(g);
        c.save();
        c.rotate(a);
        _armSolid.paint(c, a);
        _clasp.paint(c, a, glow: 0);
        c.restore();
      }
      _hub.paint(c, 0, glow: 0.9, reach: 26);
      paintOrb(c, m, Offset.zero, 8.5);
      for (var g = 0; g < 5; g++) {
        final pm = stoneLightFor(kStationGroupColors[g]);
        final pod = polar(50, _armAngle(g));
        paintDisc(c, pm.pool, pod, 18, 1.1);
        paintOrb(c, pm, pod, 9);
      }
    },
  );

  final PointBatch _motes = PointBatch(48);
  final PointBatch _hot = PointBatch(16);
  final PointBatch _podGrains = PointBatch(60);

  @override
  void paint(Canvas c, double t, double wake, double? aim, int? highlight) {
    final breathe = 0.86 + 0.14 * sin(t * 2.4);
    paintDisc(c, m.pool, Offset.zero, 80, 1 + 0.6 * wake);

    // Motes vented from the hub between the arms, drifting out.
    _motes.clear();
    _hot.clear();
    for (var i = 0; i < 44; i++) {
      final ph = (t * 0.2 + hash01(i, 1)) % 1.0;
      final a = _armAngle(i % 5) + pi / 5 + (hash01(i, 2) - 0.5) * 0.7;
      final p = polar(22 + ph * 48, a + ph * 0.35);
      (ph < 0.2 ? _hot : _motes).add(p.dx, p.dy);
    }
    _motes.draw(c, 1.1, m.grainDim.withValues(alpha: 0.42));

    if (highlight != null && highlight >= 0 && highlight < 5) {
      final pm = stoneLightFor(kStationGroupColors[highlight]);
      paintDisc(c, pm.pool, polar(50, _armAngle(highlight)), 32, 2.4);
    }
    _body.draw(c);
    paintDisc(c, m.spark, Offset.zero, 4.2 * breathe * (1 + 0.25 * wake), 0.8);
    _hot.draw(c, 1.5, m.grainHot);

    // The harvesters' mechanisms turning inside their glass.
    _podGrains.clear();
    for (var g = 0; g < 5; g++) {
      final pod = polar(50, _armAngle(g));
      for (var k = 0; k < 7; k++) {
        final ka = t * (1.2 + g * 0.13) + k * 0.9;
        final kr = 2 + 4.4 * ((k * 0.37 + t * 0.1) % 1.0);
        final q = pod + polar(kr, ka);
        _podGrains.add(q.dx, q.dy);
      }
    }
    _podGrains.draw(c, 1.2, const Color(0xFFFFF4DC).withValues(alpha: 0.7));
  }
}

// ── Keywright (rift keys) ───────────────────────────────────────────────────

class _Keywright extends _Station {
  final StoneLight m = StoneLight(StationKind.riftKey.accent, warm: 0.02);

  static const Offset _eye = Offset(0, -9);

  /// The monolith, cut like a gem whose facets all fall away from the
  /// keyhole.
  late final CutStone _monolith = CutStone.gem(m, const [
    Offset(0, -46),
    Offset(14, -39),
    Offset(24, -18),
    Offset(25, 6),
    Offset(19, 30),
    Offset(8, 42),
    Offset(-8, 42),
    Offset(-19, 30),
    Offset(-25, 6),
    Offset(-24, -18),
    Offset(-14, -39),
  ], const Offset(0, -2));

  /// The keyhole through it: a round eye above a flared slot.
  late final Path _aperture = Path()
    ..addOval(Rect.fromCircle(center: _eye, radius: 10))
    ..addPath(
      polyPath(const [
        Offset(-4.4, -3),
        Offset(4.4, -3),
        Offset(8, 22),
        Offset(-8, 22),
      ]),
      Offset.zero,
    );

  late final ui.Shader _apertureLight = ui.Gradient.radial(
    const Offset(0, 1),
    26,
    [
      const Color(0xFF000000),
      const Color(0xFF040209),
      m.essence.withValues(alpha: 0.9),
      m.hot,
    ],
    const [0.0, 0.5, 0.86, 1.0],
  );

  late final BakedArt _body = BakedArt(const Rect.fromLTRB(-30, -50, 30, 46), (
    c,
  ) {
    _monolith.paint(c, 0, glow: 1.1, reach: 34);
    paintFill(c, _aperture, _apertureLight);
  });

  /// A key, bit down, bow up.
  late final Path _keyShaft = polyPath(const [
    Offset(-1.2, -1.5),
    Offset(1.2, -1.5),
    Offset(0.8, 9),
    Offset(3.6, 9.5),
    Offset(3.6, 12),
    Offset(0.6, 12),
    Offset(0, 13.5),
    Offset(-1.2, 11.5),
  ]);

  /// A key's bow: a little cut stone, the key's light inside it.
  late final CutStone _keyBow = CutStone.gem(m, const [
    Offset(0, -10),
    Offset(4.4, -6.5),
    Offset(4.4, -3),
    Offset(0, -0.5),
    Offset(-4.4, -3),
    Offset(-4.4, -6.5),
  ], const Offset(0, -5));

  /// One baked key per elemental group.
  late final List<BakedArt> _keys = [
    for (final col in kStationGroupColors)
      BakedArt(const Rect.fromLTRB(-16, -18, 16, 20), (c) {
        final km = stoneLightFor(col);
        paintDisc(c, km.pool, const Offset(0, 2), 14);
        paintFill(c, _keyShaft, km.glassBar, 0.9);
        _keyBow.paint(c, 0, glow: 0);
      }),
  ];

  final PointBatch _swirlFar = PointBatch(90);
  final PointBatch _swirlNear = PointBatch(70);

  @override
  void paint(Canvas c, double t, double wake, double? aim, int? highlight) {
    final breathe = 0.85 + 0.15 * sin(t * 2.0);
    paintDisc(c, m.pool, const Offset(0, -2), 82, 1 + 0.6 * wake);

    void keys(bool front) {
      for (var g = 0; g < 5; g++) {
        final a = t * 0.3 + g * 2 * pi / 5;
        final depth = sin(a);
        if ((depth > 0) != front) continue;
        final km = stoneLightFor(kStationGroupColors[g]);
        final lit = highlight == g;
        final p = Offset(cos(a) * 52, sin(a) * 16 + 4);
        final s = 1.05 + 0.2 * depth + (lit ? 0.35 : 0);
        final alpha = 0.5 + 0.5 * (depth + 1) / 2;
        c.save();
        c.translate(p.dx, p.dy);
        c.scale(s);
        c.rotate(0.3 * cos(a));
        if (lit) paintDisc(c, km.pool, const Offset(0, 2), 26, 1.6);
        _keys[g].draw(c, alpha);
        paintDisc(c, km.spark, const Offset(0, -5), 1.8, alpha);
        c.restore();
      }
    }

    keys(false);
    _body.draw(c);
    if (wake > 0) paintDisc(c, m.leak, const Offset(0, -2), 22, 0.5 * wake);

    // The rift in the keyhole: grains spiralling into the eye, and up the
    // slot into it.
    c.save();
    c.clipPath(_aperture);
    _swirlFar.clear();
    _swirlNear.clear();
    for (var i = 0; i < 150; i++) {
      final ph = (t * (0.16 + 0.12 * hash01(i, 3)) + hash01(i, 4)) % 1.0;
      final slot = i % 3 == 0;
      final r = 2.5 + (1 - ph) * 13;
      final a = hash01(i, 5) * 2 * pi + ph * 6;
      final p = slot
          ? Offset((hash01(i, 6) - 0.5) * 12 * (1 - ph), 22 - ph * 30)
          : _eye + Offset(cos(a) * r, sin(a) * r);
      (ph > 0.65 ? _swirlNear : _swirlFar).add(p.dx, p.dy);
    }
    _swirlFar.draw(c, 1.0, m.grainDim.withValues(alpha: 0.55));
    _swirlNear.draw(c, 1.4, m.grainHot);
    c.restore();
    paintDisc(c, m.spark, _eye, 2.4 * breathe, 0.9);

    keys(true);
  }
}

// ── Cosmic Market ───────────────────────────────────────────────────────────

class _Market extends _Station {
  final StoneLight m = StoneLight(StationKind.market.accent, warm: 0.02);

  static double _berthAngle(int b) => b * pi / 2 + pi / 4;

  late final CutStone _spire = CutStone.gem(m, [
    for (var i = 0; i < 8; i++) polar(19, i * pi / 4 + pi / 8),
  ], Offset.zero);
  late final CutStone _armSolid = ridgeArm(m, 14, 31, 4, 2.6);

  /// The two prongs of a berth that cup its capsule.
  late final List<CutStone> _prongs = [
    for (final side in [-1.0, 1.0])
      CutStone.gem(m, [
        Offset(29, side * 2),
        Offset(36, side * 10.5),
        Offset(45, side * 12.5),
        Offset(38, side * 7.5),
      ], Offset(35, side * 7.5)),
  ];

  StoneLight _capsuleMat(int b) =>
      stoneLightFor(kStationGroupColors[(b * 2 + 1) % 5]);

  late final BakedArt _body = BakedArt(
    Rect.fromCircle(center: Offset.zero, radius: 64),
    (c) {
      for (var b = 0; b < 4; b++) {
        final a = _berthAngle(b);
        c.save();
        c.rotate(a);
        _armSolid.paint(c, a);
        for (final p in _prongs) {
          p.paint(c, a, glow: 0);
        }
        c.restore();
        final cap = polar(42, a);
        paintDisc(c, _capsuleMat(b).pool, cap, 15, 0.9);
        paintOrb(c, m, cap, 8);
      }
      _spire.paint(c, 0, glow: 1, reach: 22);
      paintOrb(c, m, Offset.zero, 7.5);
    },
  );

  final PointBatch _trade = PointBatch(80);
  final PointBatch _capsule = PointBatch(60);

  static const Color _specimen = Color(0xFFEFFBFF);

  @override
  void paint(Canvas c, double t, double wake, double? aim, int? highlight) {
    final breathe = 0.86 + 0.14 * sin(t * 1.8);
    paintDisc(c, m.pool, Offset.zero, 76, 1 + 0.6 * wake);

    // Trade: grains running from each berth in to the lantern.
    _trade.clear();
    for (var i = 0; i < 72; i++) {
      final b = i % 4;
      final ph = (t * 0.35 + hash01(i, 6)) % 1.0;
      final a =
          _berthAngle(b) +
          (1 - ph) * 0.5 * (b.isEven ? 1 : -1) +
          (hash01(i, 7) - 0.5) * 0.1;
      final p = polar(38 - ph * 30, a);
      _trade.add(p.dx, p.dy);
    }
    _trade.draw(c, 1.05, m.grainDim.withValues(alpha: 0.5));

    if (highlight != null && highlight >= 0 && highlight < 4) {
      paintDisc(
        c,
        _capsuleMat(highlight).pool,
        polar(42, _berthAngle(highlight)),
        28,
        2.2,
      );
    }
    _body.draw(c);

    // A specimen asleep in each capsule: a slow curl of its own grains.
    _capsule.clear();
    for (var b = 0; b < 4; b++) {
      final cap = polar(42, _berthAngle(b));
      for (var k = 0; k < 12; k++) {
        final ka = t * 0.9 + k * 0.62;
        final kr = 1 + 4.2 * (k / 12);
        final q = cap + Offset(cos(ka) * kr, sin(ka) * kr * 0.8);
        _capsule.add(q.dx, q.dy);
      }
    }
    _capsule.draw(c, 1.15, _specimen.withValues(alpha: 0.85));
    paintDisc(c, m.spark, Offset.zero, 3.6 * breathe * (1 + 0.25 * wake), 0.8);
  }
}

// ── Crucible (gold conversion) ──────────────────────────────────────────────

class _Crucible extends _Station {
  final StoneLight m = StoneLight(
    StationKind.goldConversion.accent,
    warm: 0.05,
  );
  final StoneLight shard = StoneLight(_shardViolet);

  static const Offset _bowlAt = Offset(-21, -14);
  static const Offset _sphereAt = Offset(15, 10);

  /// The crucible from above: a heavy cup cut in eight faces.
  late final CutStone _cup = CutStone.gem(m, [
    for (var i = 0; i < 8; i++)
      Offset(cos(i * pi / 4 + pi / 8) * 16, sin(i * pi / 4 + pi / 8) * 13),
  ], Offset.zero);
  late final Path _melt = Path()
    ..addOval(
      Rect.fromCenter(center: const Offset(1, 0.5), width: 19, height: 14),
    );
  late final ui.Shader _molten = ui.Gradient.radial(
    const Offset(2.5, 1.5),
    10.5,
    [
      const Color(0xFFFFFBEA),
      m.hot,
      m.essence,
      Color.lerp(m.essence, const Color(0xFF3A1D00), 0.7)!,
    ],
    const [0.0, 0.18, 0.55, 1.0],
  );
  late final CutStone _spout = CutStone.gem(m, const [
    Offset(9, 5),
    Offset(19, 8),
    Offset(13, 12.5),
  ], const Offset(12, 8));

  late final BakedArt _cupBaked = BakedArt(
    const Rect.fromLTRB(-19, -16, 22, 16),
    (c) {
      _cup.paint(c, 0.22, glow: 0.6, reach: 18);
      _spout.paint(c, 0.22, glow: 0);
    },
  );

  /// Two bands of the alembic's cage round the sphere: one behind it, one
  /// in front.
  late final List<BakedArt> _cage = [
    for (final (a0, a1) in [(-pi * 0.2, pi * 0.58), (pi * 0.8, pi * 1.58)])
      () {
        final band = CutStone.gem(
          m,
          crescentPoints(21, a0, a1, 4.2),
          polar(17, (a0 + a1) / 2),
        );
        return BakedArt(Rect.fromCircle(center: _sphereAt, radius: 25), (c) {
          c.save();
          c.translate(_sphereAt.dx, _sphereAt.dy);
          band.paint(c, 0, glow: 0);
          c.restore();
        });
      }(),
  ];

  /// Sphere grains: (radius, start angle, tilt, rate).
  static final List<(double, double, double, double)> _orbits = () {
    final r = Random(23);
    return [
      for (var i = 0; i < 110; i++)
        () {
          final rad = 2.5 + pow(r.nextDouble(), 0.7).toDouble() * 12;
          return (
            rad,
            r.nextDouble() * 2 * pi,
            r.nextDouble() * pi,
            1.3 * pow(6 / rad, 1.2).toDouble(),
          );
        }(),
    ];
  }();

  final PointBatch _pour = PointBatch(40);
  final PointBatch _sphereBack = PointBatch(70);
  final PointBatch _sphereFront = PointBatch(70);
  final PointBatch _shards = PointBatch(48);

  @override
  void paint(Canvas c, double t, double wake, double? aim, int? highlight) {
    final breathe = 0.86 + 0.14 * sin(t * 2.6);
    final tilt = 0.22 + 0.07 * sin(t * 0.7);
    paintDisc(c, m.pool, const Offset(0, -2), 80, 1 + 0.6 * wake);

    // Astral shards leaving the sphere: violet grains on a slow arc out.
    _shards.clear();
    for (var i = 0; i < 44; i++) {
      final ph = (t * 0.18 + hash01(i, 8)) % 1.0;
      final a = 0.2 + ph * 2.6 + (hash01(i, 9) - 0.5) * 0.5;
      final p = _sphereAt + polar(16 + ph * 40, a);
      _shards.add(p.dx, p.dy);
    }
    _shards.draw(c, 1.3, shard.grainHot.withValues(alpha: 0.7));

    _cage[0].draw(c);

    // The sphere of gold.
    _sphereBack.clear();
    _sphereFront.clear();
    for (final (rad, a0, ph, rate) in _orbits) {
      final a = a0 + t * rate;
      final z = sin(a);
      final x = cos(a) * rad;
      final y = z * rad * cos(ph) * 0.75;
      final q = _sphereAt + Offset(x * 0.96 - y * 0.28, y * 0.96 + x * 0.28);
      (z < 0 ? _sphereBack : _sphereFront).add(q.dx, q.dy);
    }
    paintDisc(c, m.pool, _sphereAt, 34, 1.7 + 0.5 * wake);
    _sphereBack.draw(c, 1.1, m.grainDim.withValues(alpha: 0.5));
    paintDisc(c, m.spark, _sphereAt, 6.5 * breathe * (1 + 0.2 * wake));
    _sphereFront.draw(c, 1.5, m.grainHot);

    _cage[1].draw(c);

    // The pour, from the spout into the sphere.
    _pour.clear();
    final lip =
        _bowlAt +
        Offset(
          cos(tilt) * 17 - sin(tilt) * 10,
          sin(tilt) * 17 + cos(tilt) * 10,
        );
    for (var i = 0; i < 36; i++) {
      final ph = (t * 0.9 + i / 36) % 1.0;
      final q =
          Offset.lerp(lip, _sphereAt, ph)! +
          Offset(0, -sin(ph * pi) * 5) +
          Offset((hash01(i, 10) - 0.5) * 2, (hash01(i, 11) - 0.5) * 2);
      _pour.add(q.dx, q.dy);
    }
    _pour.draw(c, 1.6, m.grainHot);

    c.save();
    c.translate(_bowlAt.dx, _bowlAt.dy);
    c.rotate(tilt);
    _cupBaked.draw(c);
    paintFill(c, _melt, _molten, 0.92 * breathe + 0.08);
    paintDisc(c, kGlint, const Offset(-2.5, -3), 1.8, 0.7);
    c.restore();
  }
}

// ── Star Dust Scanner ───────────────────────────────────────────────────────

class _DustScanner extends _Station {
  final StoneLight m = StoneLight(
    StationKind.starDustScanner.accent,
    warm: 0.02,
  );
  final StoneLight glass = StoneLight(const Color(0xFFD8F7B0));

  late final CutStone _hub = CutStone.gem(m, [
    for (var i = 0; i < 5; i++) polar(24, i * 2 * pi / 5 - pi / 2),
  ], Offset.zero);
  late final CutStone _armSolid = ridgeArm(m, 18, 38, 4.4, 2.8);

  late final BakedArt _hubBaked = BakedArt(
    Rect.fromCircle(center: Offset.zero, radius: 27),
    (c) {
      _hub.paint(c, 0, glow: 1, reach: 26);
      paintOrb(c, m, Offset.zero, 8);
    },
  );

  /// One arm with its lens, along +x; drawn turned three ways.
  late final BakedArt _armBaked = BakedArt(
    const Rect.fromLTRB(14, -20, 64, 20),
    (c) {
      _armSolid.paint(c, 0);
      paintDisc(c, m.pool, const Offset(44, 0), 18, 1.2);
      // A lens seen side on: a disc of glass turned to face outward.
      c.save();
      c.translate(44, 0);
      c.scale(0.5, 1);
      paintOrb(c, glass, Offset.zero, 11, alpha: 0.95);
      c.restore();
    },
  );

  final PointBatch _sweep = PointBatch(130);
  final PointBatch _sweepHot = PointBatch(40);

  @override
  void paint(Canvas c, double t, double wake, double? aim, int? highlight) {
    final tracking = aim != null;
    final heading = aim ?? t * 0.55;
    final breathe = 0.86 + 0.14 * sin(t * (tracking ? 5 : 2.2));
    paintDisc(c, m.pool, Offset.zero, 76, 1 + 0.6 * wake);

    // The sweep: motes thrown out along the heading in a narrow fan, each
    // keeping the heading it left with, so the fan trails as it turns.
    _sweep.clear();
    _sweepHot.clear();
    final speed = tracking ? 1.1 : 0.6;
    for (var i = 0; i < 120; i++) {
      final ph = (t * speed + hash01(i, 12)) % 1.0;
      final born =
          (aim ?? (t - ph / speed) * 0.55) + (hash01(i, 13) - 0.5) * 0.3;
      final p = polar(26 + ph * 70, born);
      (ph < 0.1 ? _sweepHot : _sweep).add(p.dx, p.dy);
    }
    _sweep.draw(c, 1.15, m.grainDim.withValues(alpha: tracking ? 0.65 : 0.45));

    final spin = t * 0.2;
    for (var k = 0; k < 3; k++) {
      c.save();
      c.rotate(spin + k * 2 * pi / 3);
      _armBaked.draw(c);
      paintDisc(c, m.spark, const Offset(44, 0), 2.2 * breathe, 0.6);
      c.restore();
    }
    _hubBaked.draw(c);
    c.save();
    c.rotate(heading);
    paintDisc(c, m.spark, const Offset(15, 0), 2.8 * breathe);
    c.restore();
    _sweepHot.draw(c, 1.6, m.grainHot);
  }
}

// ── Planet Scanner ──────────────────────────────────────────────────────────

class _PlanetScanner extends _Station {
  final StoneLight m = StoneLight(StationKind.planetScanner.accent, warm: 0.02);

  /// Ring grains: (ring, radius, start angle, rate).
  static final List<(int, double, double, double)> _ring = () {
    final r = Random(31);
    return [
      for (var i = 0; i < 200; i++)
        () {
          final ring = i % 3;
          final rad = [27.0, 35.0, 43.0][ring] + (r.nextDouble() - 0.5) * 3.2;
          return (
            ring,
            rad,
            r.nextDouble() * 2 * pi,
            0.5 * pow(27 / rad, 1.5).toDouble() * (ring == 1 ? -1 : 1),
          );
        }(),
    ];
  }();

  /// Each ring's tilt: (flattening, roll).
  static const List<(double, double)> _tilts = [
    (0.32, 0.35),
    (0.5, -0.6),
    (0.24, 1.2),
  ];

  late final CutStone _needle = CutStone.ridge(m, const [
    Offset(16, -1.2),
    Offset(25, -2.8),
    Offset(50, -0.4),
  ]);
  late final CutStone _counter = CutStone.ridge(m, const [
    Offset(-27, -0.4),
    Offset(-21, -2.4),
    Offset(-15, -1),
  ]);
  late final BakedArt _needleBaked = BakedArt(
    const Rect.fromLTRB(-29, -4, 52, 4),
    (c) {
      _counter.paint(c, 0);
      _needle.paint(c, 0);
    },
  );
  late final ui.Shader _globe = ui.Gradient.radial(
    const Offset(-4.5, -5.5),
    17,
    [
      Color.lerp(m.hot, m.essence, 0.3)!,
      m.essence,
      Color.lerp(m.essence, const Color(0xFF020814), 0.65)!,
      const Color(0xFF020611),
    ],
    const [0.0, 0.25, 0.7, 1.0],
  );

  final PointBatch _back = PointBatch(110);
  final PointBatch _front = PointBatch(110);
  final PointBatch _lit = PointBatch(30);

  @override
  void paint(Canvas c, double t, double wake, double? aim, int? highlight) {
    final tracking = aim != null;
    final heading = aim ?? (t * 0.4 + 0.6 * sin(t * 0.9));
    final breathe = 0.86 + 0.14 * sin(t * (tracking ? 4.5 : 1.9));
    paintDisc(c, m.pool, Offset.zero, 66, 1 + 0.6 * wake);

    _back.clear();
    _front.clear();
    _lit.clear();
    for (final (ring, rad, a0, rate) in _ring) {
      final a = a0 + t * rate;
      final (flat, roll) = _tilts[ring];
      final x0 = cos(a) * rad;
      final y0 = sin(a) * rad * flat;
      final x = x0 * cos(roll) - y0 * sin(roll);
      final y = x0 * sin(roll) + y0 * cos(roll);
      if (sin(t * 2.4 + a0 * 7) > 0.9) {
        _lit.add(x, y);
      } else if (sin(a) < 0) {
        _back.add(x, y);
      } else {
        _front.add(x, y);
      }
    }
    _back.draw(c, 1.1, m.grainDim.withValues(alpha: 0.4));

    c.save();
    c.rotate(heading);
    _needleBaked.draw(c);
    paintDisc(
      c,
      m.spark,
      const Offset(50, 0),
      (tracking ? 3.4 : 2.2) * breathe,
    );
    c.restore();

    paintDisc(c, m.pool, Offset.zero, 28, 1.4);
    stonePaint
      ..shader = _globe
      ..color = const Color(0xFFFFFFFF);
    c.drawCircle(Offset.zero, 14, stonePaint);
    stonePaint.shader = null;
    paintDisc(c, kGlint, const Offset(-5, -6), 2.6, 0.75);
    paintDisc(c, m.spark, Offset.zero, 3 * breathe * (1 + 0.3 * wake), 0.55);

    _front.draw(c, 1.4, m.grainDim);
    _lit.draw(c, 1.9, m.grainHot);
  }
}
