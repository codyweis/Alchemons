// lib/widgets/fx/stage_arrival.dart
//
// ONTO THE STAGE — an Alchemon chosen from a grid, carried to where it will
// stand as grains of itself.
//
//   The card's creature is read into grains where it sits. It lifts a
//   little out of its card and runs out of it from the feet up: the grains
//   rise in one lopsided current, lit as they go, and come down onto the
//   stage from above, settling into the creature at its full size, feet
//   first, while the floor under it brightens. Then the sprite takes over
//   beneath them and the grains are gone.
//
// Plain Dart and no blur: the screen reads the card, says where the stage
// sprite stands, and drives [StageArrivalPainter] with one controller. Every
// time here is a fraction of that controller.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';

double _smooth(double e0, double e1, double x) {
  final u = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return u * u * (3 - 2 * u);
}

/// Where every grain starts, when it leaves, and the way it goes.
class StageArrival {
  StageArrival({
    required this.grains,
    required this.from,
    required this.to,
    required this.scale,
  }) : _readWidth = to.width {
    final n = grains.length;
    _leave = Float32List(n);
    _rise = Float32List(n);
    _swing = Float32List(n);
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      minY = math.min(minY, grains.hy[i]);
      maxY = math.max(maxY, grains.hy[i]);
    }
    top = minY;
    bottom = maxY;
    final span = math.max(1.0, maxY - minY);
    final rng = math.Random(23);
    for (var i = 0; i < n; i++) {
      // 0 at its feet, 1 at its crown: it runs out of the card and settles
      // onto the stage in that order.
      final order = ((maxY - grains.hy[i]) / span).clamp(0.0, 1.0);
      _leave[i] = 0.03 + order * 0.28 + rng.nextDouble() * 0.07;
      _rise[i] = rng.nextDouble();
      // One current, leaning one way: most grains bow out on the same side.
      _swing[i] = 0.35 + (rng.nextDouble() - 0.5) * 1.6;
    }
  }

  /// The creature, read at its size on the stage: logical px from the
  /// centre of the stage sprite's box.
  final SpecimenGrains grains;

  /// The card sprite's centre, on the painter's canvas.
  final Offset from;

  /// The stage sprite's box, on the painter's canvas. The screen keeps it
  /// current: a keyboard going down, say, moves the stage mid-flight.
  Rect to;

  /// [to]'s width when [grains] were read.
  final double _readWidth;

  /// Stage size over card size: a grain at the card sits at its stage place
  /// divided by this.
  final double scale;

  /// Its crown and feet, in [grains]' px.
  late final double top, bottom;

  late final Float32List _leave, _rise, _swing;

  /// How long one grain is in the air; the last of them lands by 0.84.
  static const double travel = 0.46;

  /// The stage sprite, under the grains, once they have all landed.
  static double spriteOpacity(double t) => _smooth(0.8, 0.95, t);

  /// The grains, gone by the end.
  static double grainOpacity(double t) => 1 - _smooth(0.86, 1.0, t);

  /// The floor's light, as a share of its usual: dark while the stage is
  /// empty, swelling as the creature settles onto it, then its usual self.
  static double floorLight(double t) =>
      _smooth(0.15, 0.6, t) *
      (1 + 0.9 * math.sin(math.pi * _smooth(0.45, 1.0, t)));
}

/// Paints one frame of an arrival.
class StageArrivalPainter extends CustomPainter {
  StageArrivalPainter({
    required this.arrival,
    required this.t,
    required this.light,
  });

  final StageArrival arrival;

  /// 0..1 over the whole arrival.
  final double t;

  /// What the grains are lit with while they travel.
  final Color light;

  // Buckets, by tone (up to 14 each): at the card, landed, in the air,
  // just landed; then the two trail strengths.
  static const int _tc = 14;
  static const int _cardB = 0, _stageB = 14, _airB = 28, _settleB = 42;
  static const int _trailNear = 56, _trailFar = 57;
  static final GrainBatch _b = GrainBatch(58);
  static final Paint _p = Paint();

  /// A grain [v] of the way along its cubic from (x0, y0) to (x3, y3),
  /// eased so it lifts off gently and settles gently.
  static void _along(
    GrainBatch b,
    int bucket,
    double v,
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    final e = Curves.easeInOutCubic.transform(v.clamp(0.0, 1.0));
    final m = 1 - e;
    final w0 = m * m * m, w1 = 3 * m * m * e, w2 = 3 * m * e * e;
    final w3 = e * e * e;
    b.add(
      bucket,
      w0 * x0 + w1 * x1 + w2 * x2 + w3 * x3,
      w0 * y0 + w1 * y1 + w2 * y2 + w3 * y3,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final a = arrival;
    final g = a.grains;
    final fade = StageArrival.grainOpacity(t);
    if (g.length == 0 || fade <= 0) return;
    final b = _b..clear();
    final tones = g.tones;
    final tc = math.min(tones.length, _tc);
    final s = a.scale;
    final from = a.from;
    final to = a.to.center;
    // The stage as it stands now, against the size the grains were read at.
    final k = a.to.width / a._readWidth;
    final travel = StageArrival.travel;
    var landed = 0;

    for (var i = 0; i < g.length; i++) {
      final hx = g.hx[i], hy = g.hy[i];
      final tone = math.min(g.tone[i], tc - 1);
      final leave = a._leave[i];
      // At the card it lifts a little out of it, all of a piece, and loosens.
      final l = _smooth(0, 0.12, math.min(t, leave));
      final spread = (1 + 0.06 * l) / s;
      final sx = from.dx + hx * spread;
      final sy = from.dy + hy * spread - 7 * l;
      if (t <= leave) {
        b.add(_cardB + tone, sx, sy);
        continue;
      }
      final dx = to.dx + hx * k, dy = to.dy + hy * k;
      final u = (t - leave) / travel;
      if (u >= 1) {
        // Settled: lit for a moment as it comes to rest, then itself.
        b.add(((u - 1) * travel < 0.05 ? _settleB : _stageB) + tone, dx, dy);
        landed++;
        continue;
      }
      // Out of the card in one arc bowed to its upper side, and down onto
      // the stage from above. Every grain bows the same way by its own
      // amount, so the current is a ribbon, pinched at both ends.
      final vx = dx - sx, vy = dy - sy;
      final dist = math.max(1.0, math.sqrt(vx * vx + vy * vy));
      var nx = -vy / dist, ny = vx / dist;
      if (ny > 0) {
        nx = -nx;
        ny = -ny;
      }
      final bow =
          math.max(50.0, dist * (0.2 + 0.14 * a._rise[i])) *
          (0.55 + 0.45 * a._swing[i]);
      final p1x = sx + vx * 0.2 + nx * bow;
      final p1y = sy + vy * 0.2 + ny * bow - 24;
      final p2x = sx + vx * 0.8 + nx * bow * 0.8;
      final p2y = sy + vy * 0.8 + ny * bow * 0.8 - 40 - 50 * a._rise[i];

      _along(b, _airB + tone, u, sx, sy, p1x, p1y, p2x, p2y, dx, dy);
      // A short trail behind every other grain, so the paths read as a
      // current rather than a swarm.
      if (i.isEven && u > 0.06 && u < 0.94) {
        _along(b, _trailNear, u - 0.04, sx, sy, p1x, p1y, p2x, p2y, dx, dy);
        if (u > 0.12) {
          _along(b, _trailFar, u - 0.09, sx, sy, p1x, p1y, p2x, p2y, dx, dy);
        }
      }
    }

    // The creature taking shape: a faint light in it while it lands.
    final soak = landed / g.length;
    final glow = math.sin(math.pi * soak) * 0.85 * fade;
    if (glow > 0.01) {
      final r = math.max(60.0, (a.bottom - a.top) * 0.6 * k);
      final c = Offset(to.dx, to.dy + (a.top + a.bottom) / 2 * k);
      canvas.drawCircle(
        c,
        r,
        _p
          ..shader = ui.Gradient.radial(
            c,
            r,
            [
              light.withValues(alpha: 0.16 * glow),
              light.withValues(alpha: 0.05 * glow),
              light.withValues(alpha: 0),
            ],
            const [0.0, 0.5, 1.0],
          ),
      );
      _p.shader = null;
    }

    final stageDot = math.max(1.4, g.step * 1.15 * k);
    final cardDot = math.max(0.9, stageDot / s);
    final airDot = math.max(1.2, (cardDot + stageDot) * 0.45);
    final mid = tones[tc ~/ 2];
    final trail = Color.lerp(mid, light, 0.55)!;
    b.draw(
      canvas,
      _trailFar,
      airDot * 0.8,
      trail.withValues(alpha: 0.16 * fade),
    );
    b.draw(
      canvas,
      _trailNear,
      airDot * 0.9,
      trail.withValues(alpha: 0.34 * fade),
    );
    for (var k = 0; k < tc; k++) {
      final own = tones[k].withValues(alpha: fade);
      final lit = Color.lerp(tones[k], light, 0.4)!.withValues(alpha: fade);
      b.draw(canvas, _cardB + k, cardDot, own);
      b.draw(canvas, _stageB + k, stageDot, own);
      b.draw(canvas, _airB + k, airDot, lit);
      b.draw(canvas, _settleB + k, stageDot * 1.1, lit);
    }
  }

  @override
  bool shouldRepaint(StageArrivalPainter old) =>
      old.t != t || old.arrival != arrival || old.light != light;
}
