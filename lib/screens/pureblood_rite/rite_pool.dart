// lib/screens/pureblood_rite/rite_pool.dart
//
// THE POOL: the Pureblood Rite's own altar — a still pool of blood in
// grains, tipped toward you, turning slowly on itself, with souls rising off
// it. Everything given to the rite goes into it.
//
// Three things draw it, and they draw it the same way so one can hand over
// to the next without a seam: home's RITE emblem (its drop falls and floods
// into exactly this pool), the rite screen's stage, and the offering.
// Each grain's place in the pool is fixed by its index; only the clock moves
// them, and everyone reads the shared GlyphClock.
//
// Points in batches and gradients for light; no blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/painting.dart';

/// The rite screen's top bar and the stage under it, where the pool lies.
const double kRiteHeaderHeight = 56;
const double kRiteStageHeight = 300;

/// Where the pool lies on a screen of [size] with [pad] safe area: low on
/// the stage, nearly the screen's width across. Home's RITE emblem floods
/// into exactly this.
({Offset centre, double radius}) ritePoolFor(Size size, EdgeInsets pad) => (
  centre: Offset(
    size.width / 2,
    pad.top + kRiteHeaderHeight + kRiteStageHeight * 0.8,
  ),
  radius: size.width * 0.44,
);

class RitePool {
  RitePool._();

  /// How far the pool is tipped: its depth over its width.
  static const double flat = 0.26;

  static const int count = 2600;

  /// Blood, dark to light.
  static const List<Color> blood = [
    Color(0xFF2A0508),
    Color(0xFF6E0E16),
    Color(0xFFB0202C),
    Color(0xFFE2414B),
    Color(0xFFFF9C9C),
    Color(0xFFFFEDE0),
  ];

  static const Color soulBlue = Color(0xFF5BC8E8);
  static const Color soulGold = Color(0xFFC4A35A);

  static late final Float32List _a, _r, _ph;
  static bool _seeded = false;

  static void _seed() {
    if (_seeded) return;
    _seeded = true;
    final rng = math.Random(29);
    _a = Float32List(count);
    _r = Float32List(count);
    _ph = Float32List(count);
    for (var i = 0; i < count; i++) {
      _a[i] = rng.nextDouble() * math.pi * 2;
      _r[i] = math.sqrt(rng.nextDouble());
      _ph[i] = rng.nextDouble();
    }
  }

  static double _h(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// Grain [i]'s angle and share of the radius at time [t]: the pool turns
  /// slowly, its middle a little faster than its rim, and its edge is never
  /// quite round.
  static (double angle, double share) grain(int i, double t) {
    _seed();
    final r = _r[i];
    final a = _a[i] + t * 0.05 / (r + 0.35);
    final wob = 1 + 0.05 * math.sin(a * 3 + t * 0.6 + _ph[i] * 6);
    return (a, r * wob);
  }

  /// Grain [i] in a pool at [centre], [radius] across, at time [t].
  static Offset grainAt(int i, Offset centre, double radius, double t) {
    final (a, u) = grain(i, t);
    return Offset(
      centre.dx + math.cos(a) * radius * u,
      centre.dy + math.sin(a) * radius * u * flat,
    );
  }

  /// Grain [i]'s tone (an index into [blood]): its front, running brighter
  /// round the rim, and a shimmer that moves through the rest. [lit] (0..1)
  /// is the pool answering a worthy offering: more of it shimmers.
  static int toneAt(int i, double t, {double lit = 0}) {
    final (_, u) = grain(i, t);
    final shimmer = (t * 0.3 + _ph[i] * 5 + u * 2) % 1.0 < 0.22 + 0.2 * lit;
    if (u > 0.86) return shimmer ? 4 : 3;
    return shimmer ? 2 : 1;
  }

  static final GrainBatch _b = GrainBatch(10);
  static final Paint _p = Paint();

  /// The pool's light: low and wide, under it.
  static void paintGlow(
    Canvas canvas,
    Offset centre,
    double radius, {
    double alpha = 1,
    double lit = 0,
  }) {
    if (alpha <= 0) return;
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(1, flat * 1.6);
    final glow = Color.lerp(blood[2], soulGold, 0.35 * lit)!;
    _p.shader = ui.Gradient.radial(
      Offset.zero,
      radius * 0.95,
      [
        glow.withValues(alpha: (0.24 + 0.1 * lit) * alpha),
        glow.withValues(alpha: 0.08 * alpha),
        glow.withValues(alpha: 0),
      ],
      const [0.0, 0.5, 1.0],
    );
    canvas.drawCircle(Offset.zero, radius * 0.95, _p);
    _p.shader = null;
    canvas.restore();
  }

  /// The pool's grains. [count] of them (fewer for a small pool), faded by
  /// [alpha], shimmering more as [lit] rises.
  static void paintGrains(
    Canvas canvas,
    Offset centre,
    double radius,
    double t, {
    int? grains,
    double alpha = 1,
    double lit = 0,
    double dot = 1.6,
  }) {
    if (alpha <= 0) return;
    final b = _b..clear();
    final n = math.min(grains ?? count, count);
    for (var i = 0; i < n; i++) {
      final p = grainAt(i, centre, radius, t);
      final tone = toneAt(i, t, lit: lit);
      // Worthy: some of the shimmer turns to gold.
      if (lit > 0 && tone >= 2 && _h(i, 7) < 0.25 * lit) {
        b.add(6, p.dx, p.dy);
      } else {
        b.add(tone, p.dx, p.dy);
      }
    }
    for (var k = 1; k < 6; k++) {
      b.draw(canvas, k, dot, blood[k].withValues(alpha: alpha));
    }
    b.draw(canvas, 6, dot * 1.1, soulGold.withValues(alpha: alpha));
  }

  /// Souls rising off the pool, each with a short wake, up to [top].
  static void paintSouls(
    Canvas canvas,
    Offset centre,
    double radius,
    double top,
    double t, {
    int souls = 40,
    double alpha = 1,
    double dot = 1.6,
  }) {
    if (alpha <= 0) return;
    final b = _b..clear();
    final rise = centre.dy - top;
    for (var i = 0; i < souls; i++) {
      final speed = 0.08 + 0.06 * _h(i, 100);
      final x0 = (_h(i, 102) * 2 - 1) * radius * 0.85;
      final y0 = centre.dy + (_h(i, 104) * 2 - 1) * radius * flat * 0.6;
      final gold = _h(i, 103) >= 0.7;
      for (var j = 0; j < 3; j++) {
        final life = (t * speed + _h(i, 101) - j * 0.012) % 1.0;
        final bright = math.sin(math.pi * life);
        if (bright < 0.2) continue;
        final x = centre.dx + x0 + math.sin(life * 5 + i) * radius * 0.08;
        final y = y0 - rise * life;
        b.add(j == 0 ? (gold ? 8 : 7) : 9, x, y);
      }
    }
    b.draw(canvas, 9, dot * 0.9, soulBlue.withValues(alpha: 0.3 * alpha));
    b.draw(canvas, 7, dot * 1.4, soulBlue.withValues(alpha: 0.85 * alpha));
    b.draw(canvas, 8, dot * 1.4, soulGold.withValues(alpha: 0.85 * alpha));
  }
}
