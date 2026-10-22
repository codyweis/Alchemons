// lib/widgets/fx/rift_mutation_roll.dart
//
// A RIFT'S MUTATION, ROLLED.
//
// Every rift's Alchemon carries a mutation, an even pick of the six. Once it
// has poured out of the disk, the rift rolls which:
//
//   0.0 – 1.0   grains peel off the disk beside the Alchemon and gather into
//               a turning ball
//   1.0 – 4.0   the ball rolls through the six materials, each washing over
//               it from a new side: quick at first, slowing, settling on one
//   then        it holds a moment, settled, unnamed: the material says it
//   then        (RiftTransmute) the ball pours into the Alchemon, and the
//               material spreads through its body from where it went in; the
//               mutated sprite takes over from the grains
//
// Grains go through drawRawPoints in batches; the only gradients are the
// dark pocket the ball turns in and its glow. No blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/widgets/animations/hatch_shell.dart'
    show ShellMutationLook;
import 'package:alchemons/widgets/creature_sprite.dart' show hueRotationMatrix;
import 'package:alchemons/widgets/fx/fusion_particles.dart'
    show GrainBatch, SpecimenGrains;
import 'package:alchemons/widgets/fx/mutation_sheets.dart' show mutationAccent;
import 'package:alchemons/widgets/fx/rift_vortex.dart';
import 'package:flutter/material.dart';

/// Where a rift's ball turns, round the rift's centre: beside its Alchemon,
/// over the disk, clear of a sprite standing in a core of [coreR].
({Offset centre, double radius}) riftBallOf(double coreR) =>
    (centre: Offset(coreR * 1.9, -coreR * 0.12), radius: coreR * 0.42);

double _smooth(double x) {
  final u = x.clamp(0.0, 1.0);
  return u * u * (3 - 2 * u);
}

double _lum(Color c) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;

/// The order the ball turns through them in, like the faces of a reel.
const List<AlchemonMutation> _reel = [
  AlchemonMutation.transmuted,
  AlchemonMutation.prismatic,
  AlchemonMutation.silverlite,
  AlchemonMutation.starlit,
  AlchemonMutation.obsidian,
  AlchemonMutation.alchemized,
];

/// [c] read into [m]'s material, the way an extraction's shell reads it: by
/// its lightness onto the material's ramp, its [accent] grains lit. [band]
/// (0..1) is where a Prismatic's rainbow is at this grain.
Color riftMaterialOf(
  AlchemonMutation m,
  Color c, {
  double shade = 0.5,
  bool accent = false,
  double band = 0,
}) {
  switch (m) {
    case AlchemonMutation.transmuted:
      return ShellMutationLook.gilt(c, accent: accent, shade: shade);
    case AlchemonMutation.silverlite:
    case AlchemonMutation.starlit:
    case AlchemonMutation.obsidian:
      return ShellMutationLook.materialOf(m)!(c, accent, shade);
    case AlchemonMutation.prismatic:
      final l = _lum(c);
      return HSVColor.fromAHSV(
        1,
        (band % 1) * 360,
        accent ? 0.25 : 0.55,
        (0.38 + 0.6 * l).clamp(0.0, 1.0),
      ).toColor();
    case AlchemonMutation.alchemized:
      // Its own colors kept, lifted toward the pale violet of loose grains.
      return Color.lerp(
        c,
        mutationAccent(AlchemonMutation.alchemized),
        accent ? 0.7 : 0.32,
      )!;
  }
}

/// A material as the ball wears it: a few colors and which one a grain is.
class _BallLook {
  _BallLook(this.m) : colors = _colorsOf(m);

  final AlchemonMutation m;
  final List<Color> colors;

  static const int _levels = 7;
  static const int _bands = 10;

  static Color _grey(double v) {
    final g = (v.clamp(0.0, 1.0) * 255).round();
    return Color.fromARGB(255, g, g, g);
  }

  static List<Color> _colorsOf(AlchemonMutation m) {
    if (m == AlchemonMutation.prismatic) {
      return [
        for (var b = 0; b < _bands; b++)
          for (final v in const [0.3, 0.6, 0.92])
            riftMaterialOf(m, _grey(v), band: (b + 0.5) / _bands),
      ];
    }
    final out = <Color>[
      for (var k = 0; k < _levels; k++)
        riftMaterialOf(m, _grey(0.12 + 0.82 * k / (_levels - 1))),
    ];
    final lit = riftMaterialOf(m, _grey(0.9), accent: true);
    out
      ..add(lit) // 7: a glint, a star, a vein
      ..add(Color.lerp(lit, out[2], 0.55)!); // 8: a dim one
    return out;
  }

  /// Which color grain [h] is: lit [lit] (0..1, toward the light), facing
  /// [ny] (up is negative), [band] round the body, on a [vein], at [t].
  int pick(
    double lit,
    double ny,
    double band,
    double h,
    double vein,
    double t,
  ) {
    int level(double s) => (s.clamp(0.0, 0.999) * _levels).floor();
    switch (m) {
      case AlchemonMutation.prismatic:
        final b = ((band % 1) * _bands).floor() % _bands;
        final l = lit < 0.3 ? 0 : (lit < 0.7 ? 1 : 2);
        return b * 3 + l;
      case AlchemonMutation.transmuted:
        if (math.pow(lit, 14) > 0.5) return 7;
        return level(0.1 + 0.9 * lit);
      case AlchemonMutation.silverlite:
        // Chrome: it shows the world round it, not its own shading — sky
        // above, a dark horizon, the ground below.
        if (math.pow(lit, 18) > 0.45) return 7;
        final up = -ny;
        final s = up > 0.12
            ? 0.55 + 0.45 * up
            : (up > -0.18 ? 0.06 : 0.32 + 0.3 * -up);
        return level(s);
      case AlchemonMutation.starlit:
        if (h < 0.075) return math.sin(t * 2.6 + h * 97) > 0.15 ? 7 : 8;
        return level(0.04 + 0.62 * lit);
      case AlchemonMutation.obsidian:
        if (vein > 0) return lit > 0.25 ? 7 : 8;
        return level(0.02 + 0.55 * lit);
      case AlchemonMutation.alchemized:
        if (h < 0.05) return 7;
        return level(0.2 + 0.8 * lit);
    }
  }
}

/// The roll: which mutation the ball lands on, how it turns, and when.
/// Plain Dart — the screen keeps its clock and [paint]s it.
class RiftMutationRoll {
  RiftMutationRoll(this.landing, {int seed = 0})
    : _sx = Float32List(grains),
      _sy = Float32List(grains),
      _sz = Float32List(grains),
      _h = Float32List(grains),
      _vein = Float32List(grains),
      _gTheta = Float32List(grains),
      _gRho = Float32List(grains),
      _gDelay = Float32List(grains) {
    final rng = math.Random(seed);
    // A Fibonacci sphere: grains evenly over it, no poles bunched.
    const golden = 2.399963229728653;
    final planes = [for (var k = 0; k < 3; k++) _unit(rng)];
    for (var i = 0; i < grains; i++) {
      final y = 1 - 2 * (i + 0.5) / grains;
      final r = math.sqrt(1 - y * y);
      final a = golden * i;
      _sx[i] = math.cos(a) * r;
      _sy[i] = y;
      _sz[i] = math.sin(a) * r;
      _h[i] = rng.nextDouble();
      // Obsidian's lines: grains lying on one of three great circles.
      var vein = 0.0;
      for (final p in planes) {
        final d = (_sx[i] * p.$1 + _sy[i] * p.$2 + _sz[i] * p.$3).abs();
        if (d < 0.045 + 0.03 * _h[i]) vein = 1;
      }
      _vein[i] = vein;
      // Off the inner disk on the ball's side of the rift.
      _gTheta[i] = (rng.nextDouble() - 0.5) * 2.2;
      _gRho[i] = 0.27 + 0.2 * rng.nextDouble();
      _gDelay[i] = 0.42 * rng.nextDouble();
    }

    // Enough washes, and a start far enough round the reel, that the first
    // face says nothing about the last.
    final washes = 9 + rng.nextInt(_reel.length);
    final end = _reel.indexOf(landing);
    final start = ((end - washes) % _reel.length + _reel.length) % _reel.length;
    order = [
      for (var k = 0; k <= washes; k++) _reel[(start + k) % _reel.length],
    ];
    // Gaps that grow sixfold from first to last and fill [rollSeconds].
    final q = math.pow(6.0, 1 / (washes - 2)).toDouble();
    var sum = 0.0;
    for (var k = 0; k < washes - 1; k++) {
      sum += math.pow(q, k);
    }
    final first = rollSeconds / sum;
    final at = <double>[];
    final dur = <double>[];
    var t = gather - 0.05;
    var angle = rng.nextDouble() * math.pi * 2;
    final dirs = <Offset>[];
    for (var k = 0; k < washes; k++) {
      at.add(t);
      final gap = k < washes - 1 ? first * math.pow(q, k) : 0.0;
      dur.add(k < washes - 1 ? (0.8 * gap).clamp(0.06, 0.55) : 0.7);
      dirs.add(Offset(math.cos(angle), math.sin(angle)));
      // Each from a new side, never straight back.
      angle += 1.1 + rng.nextDouble() * 2.0;
      t += gap;
    }
    washAt = at;
    _washDur = dur;
    _washDir = dirs;
    _looks = {for (final m in _reel) m: _BallLook(m)};
  }

  /// The mutation it lands on.
  final AlchemonMutation landing;

  static const int grains = 1400;

  /// Grains off the disk into the ball.
  static const double gather = 1.0;

  /// From the first wash to the last one's start.
  static const double rollSeconds = 3.0;

  /// Settled, before it pours.
  static const double hold = 0.6;

  /// The material the ball wears from the start, then after each wash.
  late final List<AlchemonMutation> order;

  /// When each wash sets off.
  late final List<double> washAt;
  late final List<double> _washDur;
  late final List<Offset> _washDir;
  late final Map<AlchemonMutation, _BallLook> _looks;

  final Float32List _sx, _sy, _sz, _h, _vein;
  final Float32List _gTheta, _gRho, _gDelay;

  /// When the last wash has crossed it.
  double get landed => washAt.last + _washDur.last;

  /// When it pours into the Alchemon.
  double get pourAt => landed + hold;

  static (double, double, double) _unit(math.Random rng) {
    final z = rng.nextDouble() * 2 - 1;
    final a = rng.nextDouble() * math.pi * 2;
    final r = math.sqrt(1 - z * z);
    return (math.cos(a) * r, z, math.sin(a) * r);
  }

  /// How far it has turned by [t]: fast while gathering and rolling, slowing
  /// to an idle as it lands.
  double _spin(double t) {
    const fast = 4.0, idle = 0.5;
    const t0 = gather;
    final t1 = landed;
    if (t <= t0) return fast * t;
    final d = t1 - t0;
    final p = math.min(1.0, (t - t0) / d);
    final rolled =
        fast * t0 +
        idle * (math.min(t, t1) - t0) +
        (fast - idle) * d / 3 * (1 - math.pow(1 - p, 3));
    return t <= t1 ? rolled : rolled + idle * (t - t1);
  }

  static const double _tilt = 0.38;
  static final double _tc = math.cos(_tilt), _ts = math.sin(_tilt);
  static const double _lx = -0.45, _ly = -0.55, _lz = 0.70;
  static final double _ll = math.sqrt(_lx * _lx + _ly * _ly + _lz * _lz);

  /// Grain [i] on the turning ball at [t]: its place on a unit ball (view
  /// space, y down) and its depth toward the viewer.
  (double, double, double) _onBall(int i, double t) {
    final phi = _spin(t);
    final c = math.cos(phi), s = math.sin(phi);
    final x = _sx[i] * c + _sz[i] * s;
    final z0 = -_sx[i] * s + _sz[i] * c;
    final y = _sy[i] * _tc - z0 * _ts;
    final z = _sy[i] * _ts + z0 * _tc;
    return (x, y, z);
  }

  /// Which material grain [i], at ([x], [y]) on the ball, wears while wash
  /// [k] is [p] of the way across it.
  AlchemonMutation _materialAt(int i, double x, double y, int k, double p) {
    if (k < 0) return order.first;
    if (p >= 1) return order[k + 1];
    final dir = _washDir[k];
    // A ragged front, not a line.
    final along = x * dir.dx + y * dir.dy + (_h[i] - 0.5) * 0.32;
    final edge = -1.25 + 2.5 * _smooth(p);
    return along < edge ? order[k + 1] : order[k];
  }

  /// How far across it the wash at [t] is.
  double _washProgress(int k, double t) =>
      k < 0 ? 0 : (t - washAt[k]) / _washDur[k];

  double _band(int i, double t) =>
      math.atan2(_sz[i], _sx[i]) / (math.pi * 2) + 0.5 + t * 0.06;

  final GrainBatch _b = GrainBatch(_bucketCount);
  static const int _bucketCount = 2 * 2 * 32 + 3;
  static const int _hotB = 128, _trailB = 129;

  /// How much there is of the ball at [t]: gathering in, there.
  double presence(double t) => _smooth(t / (gather * 0.8));

  /// Where grain [i] of a settled ball is at [t], round the rift's centre,
  /// with the ball at [ball], [radius] wide.
  Offset ballPoint(int i, double t, Offset ball, double radius) {
    final (x, y, _) = _onBall(i, t);
    return ball +
        Offset(x, y) * (radius * _breath(t) * _looseOf(i, t, landing));
  }

  double _breath(double t) {
    final u = (t - landed) / 0.9;
    if (u <= 0 || u >= 1) return 1;
    return 1 + 0.05 * math.sin(math.pi * u);
  }

  /// Alchemized is made of loose grains, drifting off the ball and back.
  double _looseOf(int i, double t, AlchemonMutation m) =>
      m == AlchemonMutation.alchemized
      ? 1 + 0.1 * math.sin(t * 2.3 + _h[i] * 31)
      : 1;

  /// The ball at [t], on a canvas already moved to the rift's centre.
  /// [launched], when given, says when each grain left for the Alchemon
  /// (RiftTransmute): those are drawn there, not here.
  void paint(
    Canvas canvas,
    double t, {
    required Offset ball,
    required double radius,
    required double rr,
    required RiftPalette palette,
    Float32List? launched,
    double drained = 0,
  }) {
    if (t <= 0) return;
    final here = presence(t) * (1 - drained);
    if (here > 0.01) _paintPocket(canvas, t, ball, radius, here);

    final b = _b..clear();
    final r = radius * _breath(t);
    final l = _ll;
    final k = _washAt(t);
    final p = _washProgress(k, t);
    final turn = RiftVortexField.turn;
    final tc = math.cos(turn), ts = math.sin(turn);
    for (var i = 0; i < grains; i++) {
      if (launched != null && launched[i] <= t) continue;
      final (x, y, z) = _onBall(i, t);
      // On its way in from the disk.
      final u = (t - _gDelay[i]) / 0.58;
      if (u <= 0) continue;
      if (u < 1) {
        Offset at(double v) {
          final a = _gTheta[i] + 1.2 * v;
          final rho = rr * _gRho[i] * (1 - 0.25 * v);
          final dx = math.cos(a) * rho;
          final dy = math.sin(a) * rho * RiftVortexField.flat;
          final d = Offset(dx * tc - dy * ts, dx * ts + dy * tc);
          final w = _smooth((v - 0.15) / 0.85);
          final home = ball + Offset(x, y) * r;
          return Offset.lerp(d, home, w)!;
        }

        final p = at(u);
        b.add(_hotB, p.dx, p.dy);
        for (var k = 1; k <= 2; k++) {
          final v = u - 0.06 * k;
          if (v <= 0) break;
          final q = at(v);
          b.add(_trailB + k - 1, q.dx, q.dy);
        }
        continue;
      }
      final m = _materialAt(i, x, y, k, p);
      final lit = math.max(0.0, (x * _lx + y * _ly + z * _lz) / l);
      final idx = _looks[m]!.pick(
        z < 0 ? 0.12 : lit,
        y,
        _band(i, t),
        _h[i],
        _vein[i],
        t,
      );
      // 1 for the material a wash is bringing on, 0 for the one going.
      final newer = k >= 0 && m == order[k + 1] ? 1 : 0;
      final face = z < 0 ? 0 : 1;
      final loose = _looseOf(i, t, m);
      b.add(
        (newer * 2 + face) * 32 + idx,
        ball.dx + x * r * loose,
        ball.dy + y * r * loose,
      );
    }

    final d = math.max(1.6, radius * 0.06);
    b.draw(
      canvas,
      _trailB + 1,
      d * 0.8,
      palette.tones[3].withValues(alpha: 0.18),
    );
    b.draw(canvas, _trailB, d * 0.85, palette.tones[3].withValues(alpha: 0.36));
    b.draw(canvas, _hotB, d, palette.tones[4]);
    for (final face in const [0, 1]) {
      for (var slot = 0; slot < 2; slot++) {
        final m = _slotMaterial(slot, t);
        if (m == null) continue;
        final colors = _looks[m]!.colors;
        for (var k = 0; k < colors.length; k++) {
          b.draw(
            canvas,
            (slot * 2 + face) * 32 + k,
            face == 0 ? d * 0.85 : d,
            colors[k].withValues(alpha: face == 0 ? 0.3 : 1),
          );
        }
      }
    }
  }

  /// The wash under way at [t] (or the last one), -1 before the first.
  int _washAt(double t) {
    var k = -1;
    for (var j = 0; j < washAt.length; j++) {
      if (washAt[j] <= t) k = j;
    }
    return k;
  }

  /// The material in [slot] at [t]: 0 the one a wash is taking off, 1 the
  /// one it is bringing on.
  AlchemonMutation? _slotMaterial(int slot, double t) {
    final k = _washAt(t);
    if (k < 0) return slot == 0 ? order.first : null;
    return slot == 1 ? order[k + 1] : order[k];
  }

  /// The material it shows most of at [t].
  AlchemonMutation showing(double t) {
    final k = _washAt(t);
    if (k < 0) return order.first;
    return _washProgress(k, t) >= 0.5 ? order[k + 1] : order[k];
  }

  /// A small dark pocket for the ball to turn in, over the bright disk, and
  /// its material's light round it.
  void _paintPocket(
    Canvas canvas,
    double t,
    Offset ball,
    double radius,
    double here,
  ) {
    final pocket = Paint()
      ..shader = ui.Gradient.radial(
        ball,
        radius * 1.7,
        [
          kRiftPocket.withValues(alpha: 0.88 * here),
          kRiftPocket.withValues(alpha: 0.6 * here),
          kRiftPocket.withValues(alpha: 0),
        ],
        const [0, 0.6, 1],
      );
    canvas.drawCircle(ball, radius * 1.7, pocket);
    final glow = mutationAccent(showing(t));
    final light = Paint()
      ..shader = ui.Gradient.radial(
        ball,
        radius * 1.55,
        [
          glow.withValues(alpha: 0.13 * here),
          glow.withValues(alpha: 0.05 * here),
          glow.withValues(alpha: 0),
        ],
        const [0, 0.65, 1],
      );
    canvas.drawCircle(ball, radius * 1.55, light);
  }
}

/// The dark a ball turns in.
const Color kRiftPocket = Color(0xFF050507);

/// The rolled ball poured into the Alchemon, and the mutation spreading
/// through its body from where it went in.
///
/// [body] is the Alchemon read into grains just before; it stands in for the
/// sprite until the mutated sprite takes over. Without one the ball pours
/// into the middle of the sprite, which simply changes when it is in.
class RiftTransmute {
  RiftTransmute(
    this.roll,
    this.body, {
    required this.ball,
    required this.radius,
    required this.startedAt,
  }) : launched = Float32List(RiftMutationRoll.grains),
       _arrive = Float32List(RiftMutationRoll.grains),
       _target = Int32List(RiftMutationRoll.grains),
       _curl = Float32List(RiftMutationRoll.grains),
       _fromX = Float32List(RiftMutationRoll.grains),
       _fromY = Float32List(RiftMutationRoll.grains) {
    final rng = math.Random(11);
    final n = body?.length ?? 0;
    // Where it goes in: the body's grain nearest the ball.
    var entry = Offset.zero;
    if (n > 0) {
      var best = double.infinity;
      for (var j = 0; j < n; j++) {
        final d = (Offset(body!.hx[j], body!.hy[j]) - ball).distanceSquared;
        if (d < best) {
          best = d;
          entry = Offset(body!.hx[j], body!.hy[j]);
        }
      }
    } else {
      entry = Offset(ball.dx.sign * 24, 0);
    }
    this.entry = entry;
    _turnAt = Float32List(n);
    _h = Float32List(n);
    var far = 1.0;
    for (var j = 0; j < n; j++) {
      far = math.max(far, (Offset(body!.hx[j], body!.hy[j]) - entry).distance);
    }
    for (var j = 0; j < n; j++) {
      _h[j] = rng.nextDouble();
      final d = (Offset(body!.hx[j], body!.hy[j]) - entry).distance / far;
      _turnAt[j] = _waveStart + _waveSeconds * d + 0.1 * _h[j];
    }
    for (var i = 0; i < RiftMutationRoll.grains; i++) {
      // Its grains leave a few at a time, front ones first.
      final leave = startedAt + 0.6 * rng.nextDouble();
      launched[i] = leave;
      _curl[i] = (rng.nextDouble() - 0.5) * radius * 1.4;
      // Where on the ball it leaves from.
      final from = roll.ballPoint(i, leave, ball, radius);
      _fromX[i] = from.dx;
      _fromY[i] = from.dy;
      if (n > 0) {
        final j = rng.nextInt(n);
        _target[i] = j;
        // In with the front: each lands where the mutation is just reaching.
        _arrive[i] = math.max(leave + 0.34, startedAt + _turnAt[j]) - startedAt;
      } else {
        _target[i] = -1;
        _arrive[i] = leave - startedAt + 0.5 + 0.3 * rng.nextDouble();
      }
    }
    _b = GrainBatch(32 + 33 + _BallLook._bands * 3 + 6 + 32);
    final m = roll.landing;
    final tones = body?.tones ?? const <Color>[];
    _own = tones;
    _turned = [for (final c in tones) riftMaterialOf(m, c)];
    _bandColors = _BallLook(m).colors;
    _lit = riftMaterialOf(m, const Color(0xFFE6E6E6), accent: true);
    _front = Color.lerp(mutationAccent(m), const Color(0xFFFFF4E6), 0.35)!;
    _stream = riftMaterialOf(m, const Color(0xFFB0B0B0), band: 0.3);
  }

  final RiftMutationRoll roll;
  final SpecimenGrains? body;

  /// The ball's centre and size, round the body's centre.
  final Offset ball;
  final double radius;

  /// The roll's clock when this began.
  final double startedAt;

  /// When each of the ball's grains leaves it, on the roll's clock.
  final Float32List launched;
  final Float32List _arrive, _curl, _fromX, _fromY;
  final Int32List _target;
  late final Float32List _turnAt, _h;
  late final Offset entry;
  late final GrainBatch _b;
  late final List<Color> _own, _turned, _bandColors;
  late final Color _lit, _front, _stream;

  static const double _waveStart = 0.35, _waveSeconds = 1.15;

  /// From the first grain leaving the ball to the last of the body turned.
  double get seconds => body == null ? 1.3 : _waveStart + _waveSeconds + 0.35;

  /// Each body grain's color in the mutated sprite, as an index into
  /// [_dressed]; -1 where the mutated sprite had nothing there.
  Int16List? _dress;
  List<Color> _dressed = const [];

  /// The mutated sprite, read into grains: the wave turns each grain of the
  /// body into the color the mutated sprite has there, so the sprite takes
  /// over from grains that already wear it. Until then (or where it has
  /// nothing) a grain is the body's color read into the material.
  void dress(SpecimenGrains mutated) {
    final spec = body;
    if (spec == null || mutated.length == 0) return;
    final step = math.max(0.5, mutated.step);
    final at = <int, int>{};
    int keyOf(int qx, int qy) => (qx + 2048) * 4096 + (qy + 2048);
    for (var k = 0; k < mutated.length; k++) {
      at[keyOf(
            (mutated.hx[k] / step).round(),
            (mutated.hy[k] / step).round(),
          )] =
          k;
    }
    final dress = Int16List(spec.length);
    for (var j = 0; j < spec.length; j++) {
      final qx = (spec.hx[j] / step).round();
      final qy = (spec.hy[j] / step).round();
      var best = -1;
      var bestD = double.infinity;
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          final k = at[keyOf(qx + dx, qy + dy)];
          if (k == null) continue;
          final d =
              (mutated.hx[k] - spec.hx[j]) * (mutated.hx[k] - spec.hx[j]) +
              (mutated.hy[k] - spec.hy[j]) * (mutated.hy[k] - spec.hy[j]);
          if (d < bestD) {
            bestD = d;
            best = mutated.tone[k];
          }
        }
      }
      dress[j] = best;
    }
    _dress = dress;
    _dressed = mutated.tones;
  }

  /// Grains [u] seconds in, on a canvas moved to the body's centre; [fade]
  /// takes the body away as the mutated sprite takes over. [hue] turns the
  /// dressed colors, for a Prismatic whose sprite has turned since it was
  /// read.
  void paint(Canvas canvas, double u, {double fade = 1, double hue = 0}) {
    final b = _b..clear();
    final m = roll.landing;
    final t = startedAt + u;
    final tones = _own.length;
    // Buckets: own tones, then turned tones, then a Prismatic's bands, then
    // the front, the stream and its trails, lit grains, and dressed tones.
    final turnedB = 32, bandB = 65, frontB = bandB + _BallLook._bands * 3;
    final streamB = frontB + 1, trailB = frontB + 2, litB = frontB + 4;
    final dressB = litB + 2;
    final dress = _dress;
    final spec = body;
    if (spec != null && fade > 0) {
      var top = double.infinity, foot = -double.infinity;
      for (var j = 0; j < spec.length; j++) {
        top = math.min(top, spec.hy[j]);
        foot = math.max(foot, spec.hy[j]);
      }
      final tall = math.max(1.0, foot - top);
      for (var j = 0; j < spec.length; j++) {
        var x = spec.hx[j], y = spec.hy[j];
        final since = u - _turnAt[j];
        if (since < 0) {
          b.add(spec.tone[j], x, y);
          continue;
        }
        if (m == AlchemonMutation.alchemized) {
          // Loosened: its grains drift and never quite settle.
          final w = _smooth(since / 0.5) * 1.6;
          x += w * math.sin(t * 2.1 + _h[j] * 40);
          y += w * math.cos(t * 1.7 + _h[j] * 31);
        }
        if (since < 0.12) {
          b.add(frontB, x, y);
        } else if (dress != null && dress[j] >= 0) {
          b.add(dressB + dress[j], x, y);
        } else if (_h[j] < 0.035) {
          b.add(litB, x, y);
        } else if (m == AlchemonMutation.prismatic) {
          // A rainbow running down the body.
          final band = ((y - top) / tall * 0.9 + t * 0.12) % 1;
          final l = _lum(_own[spec.tone[j]]);
          b.add(
            bandB +
                (band * _BallLook._bands).floor() % _BallLook._bands * 3 +
                (l < 0.33 ? 0 : (l < 0.66 ? 1 : 2)),
            x,
            y,
          );
        } else {
          b.add(turnedB + spec.tone[j], x, y);
        }
      }
    }

    // The ball's grains in flight.
    for (var i = 0; i < RiftMutationRoll.grains; i++) {
      final leave = launched[i] - startedAt;
      final arrive = _arrive[i];
      if (u < leave || u >= arrive) continue;
      Offset at(double v) {
        final from = Offset(_fromX[i], _fromY[i]);
        final j = _target[i];
        final to = j < 0 ? entry * 0.4 : Offset(spec!.hx[j], spec.hy[j]);
        // Bent through the way in, curling a little.
        final side = Offset(-(to - from).dy, (to - from).dx);
        final sl = side.distance;
        final ctrl =
            entry +
            (ball - entry) * 0.3 +
            (sl > 0 ? side / sl * _curl[i] : Offset.zero);
        final e = Curves.easeInOut.transform(v.clamp(0.0, 1.0));
        final a = Offset.lerp(from, ctrl, e)!;
        final c = Offset.lerp(ctrl, to, e)!;
        return Offset.lerp(a, c, e)!;
      }

      final v = (u - leave) / (arrive - leave);
      final p = at(v);
      b.add(streamB, p.dx, p.dy);
      for (var k = 1; k <= 2; k++) {
        final w = v - 0.07 * k;
        if (w <= 0) break;
        final q = at(w);
        b.add(trailB + k - 1, q.dx, q.dy);
      }
    }

    final d = spec == null ? 1.6 : math.max(1.0, spec.step * 1.12);
    final ds = math.max(1.6, radius * 0.06);
    b.draw(canvas, trailB + 1, ds * 0.8, _stream.withValues(alpha: 0.2));
    b.draw(canvas, trailB, ds * 0.85, _stream.withValues(alpha: 0.4));
    b.draw(canvas, streamB, ds, _stream);
    if (fade <= 0) return;
    for (var k = 0; k < tones; k++) {
      b.draw(canvas, k, d, _own[k].withValues(alpha: fade));
      b.draw(canvas, turnedB + k, d, _turned[k].withValues(alpha: fade));
    }
    if (m == AlchemonMutation.prismatic) {
      for (var k = 0; k < _bandColors.length; k++) {
        b.draw(canvas, bandB + k, d, _bandColors[k].withValues(alpha: fade));
      }
    }
    b.draw(canvas, litB, d, _lit.withValues(alpha: fade));
    final dressed = hue == 0 ? _dressed : hueTurned(_dressed, hue);
    for (var k = 0; k < dressed.length; k++) {
      b.draw(canvas, dressB + k, d, dressed[k].withValues(alpha: fade));
    }
    b.draw(canvas, frontB, d * 1.1, _front.withValues(alpha: fade));
  }
}

/// [tones] turned [degrees] round the hue circle, the way a sprite's hue
/// filter turns them ([hueRotationMatrix]).
List<Color> hueTurned(List<Color> tones, double degrees) {
  final m = hueRotationMatrix(degrees % 360);
  int ch(int row, Color c) =>
      (m[row] * c.r * 255 +
              m[row + 1] * c.g * 255 +
              m[row + 2] * c.b * 255 +
              m[row + 4])
          .round()
          .clamp(0, 255);
  return [
    for (final c in tones)
      Color.fromARGB((c.a * 255).round(), ch(0, c), ch(5, c), ch(10, c)),
  ];
}
