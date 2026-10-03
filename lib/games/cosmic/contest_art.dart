// lib/games/cosmic/contest_art.dart
//
// The four trait contest arenas of open space, in the stations' material
// (obsidian_kit.dart): a ring of cut stone lit by the arena's own light, a
// dais at its heart, and a ring of drifting grains between them. Each trait
// has its own:
//
//   Beauty        leaning crystal shards round a dark mirror pool, motes of
//                 rose light rising off it
//   Speed         a racetrack of grains running round low pylons
//   Strength      heavy blocks round an anvil, embers lifting from it
//   Intelligence  glass nodes joined by threads of grains, a prism between
//
// [active] (0..1) is how far into a contest it is: the light rises, the
// grains quicken. The stones are painted once per shape and laid down
// turned; a frame costs a few dozen draws and a handful of point passes.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:flutter/painting.dart';

extension ContestTraitLight on CosmicContestTrait {
  /// The arena's light: the trait's colour, deepened so it reads as light
  /// in stone rather than as a pastel.
  Color get light => switch (this) {
    CosmicContestTrait.beauty => const Color(0xFFF07AA8),
    CosmicContestTrait.speed => const Color(0xFF58C4F2),
    CosmicContestTrait.strength => const Color(0xFFFF8048),
    CosmicContestTrait.intelligence => const Color(0xFFA585F0),
  };
}

/// Draws the [trait]'s arena centred on [at] (radius
/// CosmicContestArena.visualRadius).
void paintContestArena(
  Canvas c,
  CosmicContestTrait trait, {
  required Offset at,
  required double t,
  double active = 0,
  Offset? focus,
}) {
  final art = _arenas[trait] ??= switch (trait) {
    CosmicContestTrait.beauty => _BeautyArena(),
    CosmicContestTrait.speed => _SpeedArena(),
    CosmicContestTrait.strength => _StrengthArena(),
    CosmicContestTrait.intelligence => _IntelligenceArena(),
  };
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(kContestArenaScale);
  art.paint(
    c,
    t,
    active.clamp(0.0, 1.0),
    focus == null ? null : focus / kContestArenaScale,
  );
  c.restore();
}

final Map<CosmicContestTrait, _Arena> _arenas = {};

/// The arena's radius in its own units; it is drawn [kContestArenaScale]
/// times that in the world.
const double _r = CosmicContestArena.visualRadius / kContestArenaScale;

abstract class _Arena {
  _Arena(CosmicContestTrait trait)
    : m = StoneLight(trait.light, warm: 0.02),
      _dustA = PointBatch(_dustCount),
      _dustB = PointBatch(_dustCount);

  final StoneLight m;

  /// [focus] is where the contest is fought, from the arena's centre: the
  /// strength marker, the intelligence orb. Null while nothing is.
  void paint(Canvas c, double t, double active, Offset? focus);

  // ── the dust ring every arena has ──

  static const int _dustCount = 420;

  /// (radius, start angle, rate, size class)
  static final List<(double, double, double, int)> _dust = () {
    final r = Random(41);
    return [
      for (var i = 0; i < _dustCount; i++)
        () {
          final rad = _r * (0.66 + 0.3 * pow(r.nextDouble(), 0.8));
          return (
            rad,
            r.nextDouble() * 2 * pi,
            0.05 * pow(_r * 0.8 / rad, 1.5).toDouble(),
            r.nextInt(5) == 0 ? 1 : 0,
          );
        }(),
    ];
  }();

  final PointBatch _dustA, _dustB;

  /// The ring of grains, flattened by [flat] (1 = round), turning [speed]
  /// times its resting rate.
  void dust(
    Canvas c,
    double t,
    double active, {
    double flat = 1,
    double speed = 1,
    double alpha = 1,
  }) {
    _dustA.clear();
    _dustB.clear();
    final k = speed * (1 + 1.5 * active);
    for (final (rad, a0, rate, size) in _dust) {
      final a = a0 + t * rate * k;
      (size == 1 ? _dustB : _dustA).add(cos(a) * rad, sin(a) * rad * flat);
    }
    _dustA.draw(
      c,
      1.4,
      m.grainDim.withValues(alpha: (0.32 + 0.3 * active) * alpha),
    );
    _dustB.draw(
      c,
      2.2,
      m.grainHot.withValues(alpha: (0.45 + 0.4 * active) * alpha),
    );
  }

  /// The arena's light pooled on the dark round it.
  void pool(Canvas c, double active, [double scale = 1]) =>
      paintDisc(c, m.pool, Offset.zero, _r * 1.15 * scale, 0.9 + 1.4 * active);

  /// [stone] laid down [n] times round a ring of [radius], each turned to
  /// face the middle (its local +x points outward).
  void ring(
    Canvas c,
    BakedArt stone,
    int n,
    double radius, {
    double phase = 0,
  }) {
    for (var i = 0; i < n; i++) {
      final a = phase + i * 2 * pi / n;
      c.save();
      c.rotate(a);
      c.translate(radius, 0);
      stone.draw(c);
      c.restore();
    }
  }
}

// ── Beauty ──────────────────────────────────────────────────────────────────

class _BeautyArena extends _Arena {
  _BeautyArena() : super(CosmicContestTrait.beauty);

  /// A crystal shard, rising outward and leaning in: long and narrow.
  late final BakedArt _shard = BakedArt(
    const Rect.fromLTRB(-16, -20, 64, 20),
    (c) => CutStone.gem(m, const [
      Offset(-8, 0),
      Offset(10, -11),
      Offset(46, -6),
      Offset(58, 0),
      Offset(44, 7),
      Offset(8, 10),
    ], const Offset(4, 0)).paint(c, 0, glow: 0.8, reach: 30),
  );
  late final BakedArt _small = BakedArt(
    const Rect.fromLTRB(-10, -14, 40, 14),
    (c) => CutStone.gem(m, const [
      Offset(-5, 0),
      Offset(6, -7),
      Offset(30, -3),
      Offset(36, 0),
      Offset(28, 5),
      Offset(5, 7),
    ], const Offset(2, 0)).paint(c, 0, glow: 0.7, reach: 20),
  );

  /// The pool: a still disc of dark glass, the arena's light lying across
  /// its far side like a reflection.
  late final ui.Shader _mirror = ui.Gradient.linear(
    const Offset(-30, -46),
    const Offset(30, 46),
    [
      Color.lerp(const Color(0xFF07050B), m.essence, 0.22)!,
      const Color(0xFF050409),
      const Color(0xFF050409),
      Color.lerp(const Color(0xFF07050B), m.essence, 0.12)!,
    ],
    const [0.0, 0.35, 0.7, 1.0],
  );
  late final BakedArt _dais = BakedArt(
    const Rect.fromLTRB(-62, -62, 62, 62),
    (c) {
      CutStone.gem(m, [
        for (var i = 0; i < 12; i++) polar(56, i * 2 * pi / 12),
      ], Offset.zero).paint(c, 0, glow: 0.35, reach: 60);
      stonePaint
        ..shader = _mirror
        ..color = const Color(0xFFFFFFFF);
      c.drawCircle(Offset.zero, 46, stonePaint);
      stonePaint.shader = null;
    },
  );

  final PointBatch _motes = PointBatch(140);
  final PointBatch _motesHot = PointBatch(40);

  @override
  void paint(Canvas c, double t, double active, Offset? focus) {
    pool(c, active);
    dust(c, t, active, speed: 0.6);
    ring(c, _shard, 10, _r * 0.84, phase: t * 0.004);
    ring(c, _small, 10, _r * 0.72, phase: pi / 10 + t * 0.004);
    _dais.draw(c);
    // Motes of light lifting off the pool, drifting out and up; in a
    // contest they climb the whole arena.
    _motes.clear();
    _motesHot.clear();
    final n = 60 + (80 * active).round();
    for (var i = 0; i < n; i++) {
      final ph =
          (t * (0.07 + 0.05 * hash01(i, 3)) * (1 + active) + hash01(i, 4)) %
          1.0;
      final a = hash01(i, 5) * 2 * pi + ph * 1.2;
      final p =
          polar(12 + ph * 62 * (1 + 1.6 * active), a) +
          Offset(0, -ph * (18 + 40 * active));
      (ph < 0.25 ? _motesHot : _motes).add(p.dx, p.dy);
    }
    _motes.draw(c, 1.6, m.grainDim.withValues(alpha: 0.5 + 0.3 * active));
    _motesHot.draw(c, 2.2, m.grainHot);
    paintDisc(c, m.spark, Offset.zero, 9 + 6 * active, 0.5 + 0.5 * active);
  }
}

// ── Speed ───────────────────────────────────────────────────────────────────

class _SpeedArena extends _Arena {
  _SpeedArena() : super(CosmicContestTrait.speed);

  /// The track's flattening: the racers run ellipses of 222×124 and
  /// 190×102 (cosmic_game_companions_contests.dart).
  static const double _flat = 0.555;

  /// A low pylon by the track: a short wedge, its light on the inner face.
  late final BakedArt _pylon = BakedArt(
    const Rect.fromLTRB(-14, -14, 26, 14),
    (c) => CutStone.gem(m, const [
      Offset(-8, 0),
      Offset(2, -9),
      Offset(18, -6),
      Offset(22, 0),
      Offset(18, 6),
      Offset(2, 9),
    ], Offset.zero).paint(c, 0, glow: 1, reach: 18),
  );
  late final BakedArt _dais = BakedArt(const Rect.fromLTRB(-50, -32, 50, 32), (
    c,
  ) {
    CutStone.gem(m, [
      for (var i = 0; i < 8; i++)
        Offset(cos(i * pi / 4) * 46, sin(i * pi / 4) * 46 * _flat),
    ], Offset.zero).paint(c, 0, glow: 0.9, reach: 40);
  });

  final PointBatch _lane = PointBatch(380);
  final PointBatch _laneHot = PointBatch(90);

  @override
  void paint(Canvas c, double t, double active, Offset? focus) {
    pool(c, active);
    dust(c, t, active, flat: _flat, speed: 1.4, alpha: 0.6);
    // The racetrack: grains streaming round between the two racing lines,
    // quicker toward the inside.
    _lane.clear();
    _laneHot.clear();
    final speed = 0.35 + 1.4 * active;
    for (var i = 0; i < 420; i++) {
      final band = hash01(i, 7);
      final rad = 176 + 58 * band;
      final a = hash01(i, 8) * 2 * pi + t * speed * (1.3 - band * 0.5);
      final p = Offset(cos(a) * rad, sin(a) * rad * _flat);
      (hash01(i, 9) < 0.18 ? _laneHot : _lane).add(p.dx, p.dy);
    }
    _lane.draw(c, 1.5, m.grainDim.withValues(alpha: 0.5 + 0.35 * active));
    _laneHot.draw(c, 2.2, m.grainHot);
    // Pylons outside and inside the track.
    for (var i = 0; i < 12; i++) {
      final a = i * 2 * pi / 12;
      for (final (rad, s) in const [(252.0, 1.0), (152.0, 0.75)]) {
        final p = Offset(cos(a) * rad, sin(a) * rad * _flat);
        c.save();
        c.translate(p.dx, p.dy);
        c.rotate(atan2(p.dy / _flat, p.dx));
        c.scale(s);
        _pylon.draw(c);
        c.restore();
      }
    }
    _dais.draw(c);
    paintDisc(c, m.spark, Offset.zero, 7 + 5 * active, 0.5 + 0.5 * active);
  }
}

// ── Strength ────────────────────────────────────────────────────────────────

class _StrengthArena extends _Arena {
  _StrengthArena() : super(CosmicContestTrait.strength);

  /// Where the two strain against each other: the groove's height. The
  /// contestants stand at ±132 on it (cosmic_game_companions_contests.dart).
  static const double _y = 24;

  /// A heavy block: squat and broad, its face to the middle.
  late final BakedArt _block = BakedArt(
    const Rect.fromLTRB(-26, -34, 30, 34),
    (c) => CutStone.gem(m, const [
      Offset(-20, -16),
      Offset(-6, -28),
      Offset(18, -26),
      Offset(24, 0),
      Offset(18, 26),
      Offset(-6, 28),
      Offset(-20, 16),
    ], const Offset(-10, 0)).paint(c, 0, glow: 0.9, reach: 34),
  );

  /// The anvil: two cut stones, one either side of the groove.
  late final BakedArt _anvil = BakedArt(
    const Rect.fromLTRB(-136, -34, 136, 34),
    (c) {
      CutStone.gem(m, const [
        Offset(-128, -4),
        Offset(-112, -28),
        Offset(0, -30),
        Offset(112, -28),
        Offset(128, -4),
      ], const Offset(0, -6)).paint(c, 0, glow: 0.5, reach: 60);
      CutStone.gem(m, const [
        Offset(-128, 4),
        Offset(128, 4),
        Offset(112, 28),
        Offset(0, 30),
        Offset(-112, 28),
      ], const Offset(0, 6)).paint(c, 0, glow: 0.5, reach: 60);
    },
  );

  /// The groove between the stones, lit along its length.
  late final Path _groove = polyPath(const [
    Offset(-120, 0),
    Offset(-60, -3.4),
    Offset(60, -3.4),
    Offset(120, 0),
    Offset(60, 3.4),
    Offset(-60, 3.4),
  ]);
  late final ui.Shader _grooveLight = ui.Gradient.linear(
    const Offset(-120, 0),
    const Offset(120, 0),
    [
      m.essence.withValues(alpha: 0.1),
      m.grainHot,
      m.grainHot,
      m.essence.withValues(alpha: 0.1),
    ],
    const [0.0, 0.25, 0.75, 1.0],
  );

  final PointBatch _embers = PointBatch(130);
  final PointBatch _embersHot = PointBatch(50);

  @override
  void paint(Canvas c, double t, double active, Offset? focus) {
    pool(c, active);
    dust(c, t, active, speed: 0.4, alpha: 0.8);
    ring(c, _block, 8, _r * 0.84, phase: pi / 8);
    c.save();
    c.translate(0, _y);
    _anvil.draw(c);
    paintFill(c, _groove, _grooveLight, 0.5 + 0.5 * active);
    c.restore();
    // Embers lift off the groove; in a contest they spray from the point
    // where the two forces meet.
    final at = focus ?? const Offset(0, _y);
    _embers.clear();
    _embersHot.clear();
    final n = 50 + (80 * active).round();
    for (var i = 0; i < n; i++) {
      final ph =
          (t * (0.18 + 0.12 * hash01(i, 11)) * (1 + active) + hash01(i, 12)) %
          1.0;
      final spread = 220 * (1 - 0.7 * active);
      final x = (hash01(i, 13) - 0.5) * spread;
      final p = Offset(
        at.dx * active + x + sin(t * 1.3 + i) * 6 * ph,
        _y - ph * (40 + 70 * active),
      );
      (ph < 0.3 ? _embersHot : _embers).add(p.dx, p.dy);
    }
    _embers.draw(c, 1.5, m.grainDim.withValues(alpha: 0.45 + 0.3 * active));
    _embersHot.draw(c, 2.2, m.grainHot);
    if (focus != null) {
      // The bead of molten light the two are pushing.
      paintDisc(c, m.pool, focus, 46, 2.2);
      paintDisc(c, m.spark, focus, 11);
      paintDisc(c, kGlint, focus + const Offset(-3, -3), 3, 0.8);
    }
  }
}

// ── Intelligence ────────────────────────────────────────────────────────────

class _IntelligenceArena extends _Arena {
  _IntelligenceArena() : super(CosmicContestTrait.intelligence);

  static const int _nodes = 7;

  late final BakedArt _prism = BakedArt(
    const Rect.fromLTRB(-44, -54, 44, 54),
    (c) => CutStone.gem(m, const [
      Offset(0, -50),
      Offset(30, -16),
      Offset(36, 18),
      Offset(0, 48),
      Offset(-36, 18),
      Offset(-30, -16),
    ], const Offset(-4, -4)).paint(c, 0, glow: 1.2, reach: 44),
  );

  /// A node: a small cut crystal with the light caught in it.
  late final BakedArt _node = BakedArt(
    const Rect.fromLTRB(-16, -24, 16, 24),
    (c) => CutStone.gem(m, const [
      Offset(0, -20),
      Offset(12, -6),
      Offset(9, 14),
      Offset(0, 19),
      Offset(-9, 14),
      Offset(-12, -6),
    ], const Offset(-2, -3)).paint(c, 0, glow: 1, reach: 22),
  );

  final PointBatch _threads = PointBatch(560);
  final PointBatch _threadsHot = PointBatch(150);

  Offset _nodeAt(int i, double t) {
    final a = i * 2 * pi / _nodes - pi / 2 + t * 0.03;
    return polar(_r * (0.76 + 0.04 * sin(t * 0.6 + i)), a);
  }

  @override
  void paint(Canvas c, double t, double active, Offset? focus) {
    pool(c, active);
    dust(c, t, active, speed: 0.5, alpha: 0.6);
    // Threads of grains: round the ring node to node, and in to the prism —
    // or, in a contest, to the thought the two are pulling at.
    final into = focus ?? Offset.zero;
    _threads.clear();
    _threadsHot.clear();
    final flow = 0.25 + 0.6 * active;
    for (var i = 0; i < _nodes; i++) {
      final a = _nodeAt(i, t);
      final b = _nodeAt((i + 2) % _nodes, t);
      for (var k = 0; k < 44; k++) {
        final f =
            (t * flow * 0.6 + k / 44 + hash01(i * 31 + k, 14) * 0.02) % 1.0;
        final p =
            Offset.lerp(a, b, f)! +
            Offset(0, sin(f * pi) * 10 * (i.isEven ? 1 : -1));
        (k % 6 == 0 ? _threadsHot : _threads).add(p.dx, p.dy);
      }
      for (var k = 0; k < 26; k++) {
        final f = (t * flow + k / 26) % 1.0;
        final p = Offset.lerp(a, into, f)!;
        (k % 5 == 0 ? _threadsHot : _threads).add(p.dx, p.dy);
      }
    }
    _threads.draw(c, 1.7, m.grainDim.withValues(alpha: 0.6 + 0.35 * active));
    _threadsHot.draw(c, 2.4, m.grainHot);
    for (var i = 0; i < _nodes; i++) {
      final p = _nodeAt(i, t);
      c.save();
      c.translate(p.dx, p.dy);
      _node.draw(c);
      c.restore();
      paintDisc(c, m.spark, p + const Offset(-2, -3), 4.5 + 2 * active);
    }
    _prism.draw(c, 1 - 0.5 * active);
    paintDisc(
      c,
      m.spark,
      const Offset(-4, -4),
      8 + 4 * (1 - active),
      0.6 * (1 - active) + 0.2,
    );
    if (focus != null) {
      // The thought: a bead of glass with the light gathered into it.
      paintDisc(c, m.pool, focus, 50, 2.4);
      paintOrb(c, m, focus, 14);
      paintDisc(c, m.spark, focus, 6);
    }
  }
}
