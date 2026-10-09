// lib/widgets/fx/grain_assembly.dart
//
// A CREATURE GATHERING OUT OF GRAINS OF ITSELF — and coming apart into them.
//
// The particle language of the fusion, the harvest and the infusion, as a
// summoning: the creature is read into grains (see [SpecimenGrains]), and
// they swirl in from round where it will stand, each settling into its own
// place, hot with the creature's element as it flies and cooling to its own
// color as it lands — feet first, crown last. Recalled, it comes apart the
// other way and streams off to wherever it is going.
//
// Plain Dart, driven by a 0..1 time: a host steps nothing, it only paints.
// Cheap enough for a game loop: points in batches, no blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart';

class GrainAssembly {
  GrainAssembly(this.grains, {required this.accent}) {
    final n = grains.length;
    _a0 = Float32List(n);
    _r0 = Float32List(n);
    _start = Float32List(n);
    _spin = Float32List(n);
    _phase = Float32List(n);
    var minY = double.infinity, maxY = double.negativeInfinity, reach = 1.0;
    for (var i = 0; i < n; i++) {
      minY = math.min(minY, grains.hy[i]);
      maxY = math.max(maxY, grains.hy[i]);
      reach = math.max(
        reach,
        math.sqrt(grains.hx[i] * grains.hx[i] + grains.hy[i] * grains.hy[i]),
      );
    }
    this.reach = reach;
    final span = math.max(1.0, maxY - minY);
    final rng = math.Random(19);
    for (var i = 0; i < n; i++) {
      _a0[i] = rng.nextDouble() * math.pi * 2;
      // From a cloud round it, two body-widths out at most.
      _r0[i] = reach * (1.2 + 1.3 * math.sqrt(rng.nextDouble()));
      // Feet first, crown last, loosely.
      final rise = ((maxY - grains.hy[i]) / span).clamp(0.0, 1.0);
      _start[i] = (0.45 * rise + 0.2 * rng.nextDouble()).clamp(0.0, 0.62);
      _spin[i] = (rng.nextBool() ? 1.0 : -1.0) * (1.4 + rng.nextDouble());
      _phase[i] = rng.nextDouble();
    }
    final g = grains.tones;
    _hot = [
      for (var k = 0; k < 3; k++)
        ui.Color.lerp(accent, const ui.Color(0xFFFFFFFF), 0.15 + 0.25 * k)!,
    ];
    _toneCount = math.min(g.length, 16);
  }

  final SpecimenGrains grains;

  /// The creature's element: the heat its grains fly with.
  final ui.Color accent;

  /// How far its grains sit from its centre, at most.
  late final double reach;

  late final Float32List _a0, _r0, _start, _spin, _phase;
  late final List<ui.Color> _hot;
  late final int _toneCount;

  // Buckets: its tones, then three heats, then glints.
  final GrainBatch _b = GrainBatch(20);
  static const int _hotB = 16, _glintB = 19;

  /// How opaque the creature's sprite should be while grains are drawn over
  /// it: gone while they gather, back as they finish.
  static double spriteOpacityGathering(double u) => _smooth(0.8, 0.98, u);

  /// …and as it comes apart.
  static double spriteOpacityScattering(double u) => 1 - _smooth(0.0, 0.22, u);

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static double _easeOut(double x) => 1 - math.pow(1 - x, 3).toDouble();

  /// Paints it gathering at [at], [u] 0..1. [mirror] flips it left to right
  /// (a sprite drawn facing the other way).
  void paintGather(
    ui.Canvas canvas,
    ui.Offset at,
    double u, {
    bool mirror = false,
    double scale = 1,
  }) {
    if (u >= 1) return;
    final b = _b..clear();
    final g = grains;
    final sx = mirror ? -scale : scale;
    for (var i = 0; i < g.length; i++) {
      final v = ((u - _start[i]) / 0.38).clamp(0.0, 1.0);
      if (v <= 0) continue;
      final e = _easeOut(v);
      final hx = g.hx[i] * sx, hy = g.hy[i] * scale;
      // In along a swirl: the offset from home turns as it shrinks.
      final left = 1 - e;
      final a = _a0[i] + _spin[i] * left;
      final ox = math.cos(a) * _r0[i] * scale * left;
      final oy = math.sin(a) * _r0[i] * scale * left * 0.75;
      final x = at.dx + hx + ox, y = at.dy + hy + oy;
      if (v >= 1) {
        // Landed: its own color, the odd one catching the light.
        if (_phase[i] > 0.97 && u < 0.92) {
          b.add(_glintB, x, y);
        } else {
          b.add(math.min(g.tone[i], _toneCount - 1), x, y);
        }
      } else {
        b.add(_hotB + math.min(2, (left * 3).floor()), x, y);
      }
    }
    _draw(canvas, scale, fade: 1 - _smooth(0.9, 1.0, u));
  }

  /// Paints it coming apart at [at] and streaming off to [to] (relative to
  /// [at]), [u] 0..1 from whole to gone.
  void paintScatter(
    ui.Canvas canvas,
    ui.Offset at,
    double u, {
    ui.Offset to = const ui.Offset(0, -120),
    bool mirror = false,
    double scale = 1,
  }) {
    if (u <= 0 || u >= 1) return;
    final b = _b..clear();
    final g = grains;
    final sx = mirror ? -scale : scale;
    for (var i = 0; i < g.length; i++) {
      // Crown first, this time, so it lifts away.
      final s = (0.62 - _start[i]) * 0.6;
      final v = ((u - s) / 0.55).clamp(0.0, 1.0);
      final hx = g.hx[i] * sx, hy = g.hy[i] * scale;
      if (v <= 0) {
        b.add(math.min(g.tone[i], _toneCount - 1), at.dx + hx, at.dy + hy);
        continue;
      }
      final e = v * v;
      // Bowed, each to its own side, and landing in a little cloud at the
      // destination rather than a point.
      // A filled little cloud: on one radius it would draw a hoop.
      final land = reach * 0.22 * scale * math.sqrt(_phase[i]);
      final tx = to.dx + math.cos(_a0[i]) * land;
      final ty = to.dy + math.sin(_a0[i]) * land;
      final dx = tx - hx, dy = ty - hy;
      final bow =
          math.sin(math.pi * e) *
          (0.08 + 0.16 * _phase[i]) *
          (_spin[i] > 0 ? 1 : -1);
      final x = at.dx + hx + dx * e - dy * bow;
      final y = at.dy + hy + dy * e + dx * bow;
      b.add(_hotB + math.min(2, (v * 3).floor()), x, y);
    }
    _draw(canvas, scale, fade: 1 - _smooth(0.85, 1.0, u));
  }

  void _draw(ui.Canvas canvas, double scale, {double fade = 1}) {
    if (fade <= 0) return;
    final b = _b;
    final d = math.max(1.2, grains.step * scale * 1.15);
    ui.Color f(ui.Color c, [double k = 1]) =>
        c.withValues(alpha: (c.a * k * fade).clamp(0.0, 1.0));
    for (var k = 0; k < _toneCount; k++) {
      b.draw(canvas, k, d, f(grains.tones[k]));
    }
    for (var k = 0; k < 3; k++) {
      b.draw(canvas, _hotB + k, d * (1.15 - 0.1 * k), f(_hot[k], 0.9));
    }
    b.draw(canvas, _glintB, d * 2.2, f(const ui.Color(0x40FFFFFF)));
    b.draw(canvas, _glintB, d * 1.2, f(const ui.Color(0xFFFFFFFF)));
  }
}
