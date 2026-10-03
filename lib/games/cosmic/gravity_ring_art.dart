// GRAVITY RINGS IN GRAINS. A planet's pull is drawn as loose matter caught
// on slow orbits round it — the dust-ring recipe of planet_art.dart's
// _ParticleRing, at the scale of the planet's whole field.
//
// The rings are huge (twelve planet radii, 1 400–5 800 world units), so
// nothing is stored per grain. Each lane is a lattice of slots spaced along
// the ring that turns rigidly at its own speed (inner lanes faster, as an
// orbit is); a slot's jitter, scatter, size and twinkle come from a hash of
// its index, so a grain is the same grain every frame. Only the slots on
// the arc in view are visited, so the cost follows the screen, not the ring,
// and every grain goes into one of nine batched point draws.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// One lane of a [GrainRingStyle]: grains a little in from or out from the
/// ring's radius, scattered round that line, turning at their own pace.
class GrainLane {
  const GrainLane({
    required this.offset,
    required this.scatter,
    required this.speed,
    required this.spacing,
    this.alpha = 1,
    this.fine = false,
  });

  /// From the ring's radius, outward positive (world units, × spread).
  final double offset;

  /// Half-width of the scatter round [offset] (world units, × spread).
  final double scatter;

  /// Along the ring, world units a second.
  final double speed;

  /// World units between slots along the lane.
  final double spacing;

  /// The lane's share of the ring's brightness.
  final double alpha;

  /// A lane of dust: the finest grains, none of the larger ones.
  final bool fine;
}

/// How a ring of grains looks: its lanes, grain sizes and brightness, and
/// the soft light under them.
class GrainRingStyle {
  const GrainRingStyle({
    required this.lanes,
    this.fineSize = 1.1,
    this.dimSize = 1.7,
    this.brightSize = 2.6,
    this.grainAlpha = 0.6,
    this.glowAlpha = 0.18,
    this.laneWidth = 0,
    this.laneAlpha = 0,
    this.keep = 1,
    this.clump = 0.6,
    this.clumpLength = 900,
  });

  final List<GrainLane> lanes;

  /// Grain diameters, world units: dust, most grains, and the larger few.
  final double fineSize, dimSize, brightSize;

  /// Peak alpha of a fully lit grain.
  final double grainAlpha;

  /// Alpha of the faint halo round lit grains.
  final double glowAlpha;

  /// Half-width of the soft lane of light under the grains (world units,
  /// × spread); 0 for none.
  final double laneWidth;

  /// Peak alpha of that lane.
  final double laneAlpha;

  /// Share of slots that hold a grain (0..1): thins a ring without changing
  /// its lattice.
  final double keep;

  /// How strongly the grains gather into clumps along the ring (0..1), and
  /// roughly how far apart the clumps are, world units.
  final double clump, clumpLength;

  /// A planet's pull: a lane of dust through the middle, grains through
  /// and either side of it.
  static const pull = GrainRingStyle(
    lanes: [
      GrainLane(offset: -64, scatter: 24, speed: 11, spacing: 22, alpha: 0.5),
      GrainLane(offset: -28, scatter: 13, speed: 9, spacing: 13, alpha: 0.8),
      GrainLane(
        offset: 0,
        scatter: 34,
        speed: 7.5,
        spacing: 4.5,
        alpha: 0.7,
        fine: true,
      ),
      GrainLane(offset: 2, scatter: 7, speed: 7, spacing: 11),
      GrainLane(offset: 30, scatter: 13, speed: 6, spacing: 15, alpha: 0.8),
      GrainLane(offset: 70, scatter: 26, speed: 4.5, spacing: 26, alpha: 0.45),
    ],
    fineSize: 1.4,
    dimSize: 1.9,
    brightSize: 2.9,
    grainAlpha: 0.85,
    glowAlpha: 0.2,
    laneWidth: 110,
    laneAlpha: 0.07,
  );

  /// The outer edge of the pull, shown while a home is being placed: the
  /// same matter, thinner and fainter.
  static const captureEdge = GrainRingStyle(
    lanes: [
      GrainLane(offset: -34, scatter: 20, speed: 5, spacing: 26, alpha: 0.7),
      GrainLane(
        offset: 0,
        scatter: 26,
        speed: 4,
        spacing: 7,
        alpha: 0.6,
        fine: true,
      ),
      GrainLane(offset: 2, scatter: 8, speed: 4, spacing: 18),
      GrainLane(offset: 38, scatter: 24, speed: 3, spacing: 32, alpha: 0.6),
    ],
    fineSize: 1.4,
    grainAlpha: 0.7,
    glowAlpha: 0.16,
    laneWidth: 80,
    laneAlpha: 0.05,
    clump: 0.75,
  );

  /// Loose matter between the field's edge and the capture edge, so the
  /// band reads as a place and not a pair of lines. Offsets are in units of
  /// the band's half-width (pass it as spread).
  static const captureWash = GrainRingStyle(
    lanes: [
      GrainLane(offset: -0.7, scatter: 0.24, speed: 7, spacing: 16, fine: true),
      GrainLane(offset: -0.3, scatter: 0.26, speed: 6, spacing: 30, alpha: 0.8),
      GrainLane(offset: 0.1, scatter: 0.24, speed: 5, spacing: 18, fine: true),
      GrainLane(offset: 0.5, scatter: 0.26, speed: 4, spacing: 34, alpha: 0.8),
      GrainLane(offset: 0.8, scatter: 0.2, speed: 4, spacing: 18, fine: true),
    ],
    fineSize: 1.6,
    dimSize: 1.9,
    brightSize: 2.6,
    grainAlpha: 0.75,
    glowAlpha: 0.08,
    laneWidth: 1,
    laneAlpha: 0.05,
    clump: 0.7,
    clumpLength: 1400,
  );

  /// The path an orbiting body leaves behind it.
  static const trail = GrainRingStyle(
    lanes: [
      GrainLane(offset: 0, scatter: 16, speed: 3, spacing: 4, fine: true),
      GrainLane(offset: -4, scatter: 7, speed: 3, spacing: 9),
      GrainLane(offset: 6, scatter: 11, speed: 2, spacing: 14, alpha: 0.7),
    ],
    dimSize: 1.8,
    brightSize: 2.6,
    grainAlpha: 0.75,
    glowAlpha: 0.16,
    clump: 0.3,
    clumpLength: 300,
  );
}

/// Draws rings of grains. Holds its scratch buffers; one is enough for a
/// whole frame of rings.
class GrainRingPainter {
  GrainRingPainter();

  /// Most slots one lane visits in a frame; past it the lattice is strided.
  static const int maxSlots = 2400;

  // Bucket = size class (dust, grain, large grain) × 3 + brightness.
  final List<Float32List> _pts = List.generate(9, (_) => Float32List(256));
  final List<int> _n = List.filled(9, 0);
  final Paint _dot = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final Paint _lane = Paint()..style = PaintingStyle.stroke;

  /// Grains put down by the last [paint] (for tests and the audit).
  int lastCount = 0;

  void _add(int b, double x, double y) {
    var buf = _pts[b];
    final i = _n[b] * 2;
    if (i + 2 > buf.length) {
      final grown = Float32List(buf.length * 2)..setAll(0, buf);
      _pts[b] = buf = grown;
    }
    buf[i] = x;
    buf[i + 1] = y;
    _n[b]++;
  }

  static int _hash(int a) {
    a = (a ^ 61) ^ (a >> 16);
    a = (a + (a << 3)) & 0xffffffff;
    a ^= a >> 4;
    a = (a * 0x27d4eb2d) & 0xffffffff;
    a ^= a >> 15;
    return a;
  }

  /// The ring of grains round [centre] at [radius] in [style], the part of
  /// it inside [view] (world space) only. [t] is the clock in seconds;
  /// [seed] keeps two rings from sharing grains; [spread] scales the lanes'
  /// offsets and scatter.
  ///
  /// [sizeScale] grows the grains (the camera pulled back keeps them from
  /// shrinking to nothing).
  ///
  /// With [trailHead] (an angle, radians) only the arc behind it is drawn,
  /// [trailSpan] radians long and fading away from the head — the wake of
  /// something going round the ring (angles increasing).
  void paint(
    Canvas canvas, {
    required Offset centre,
    required double radius,
    required Rect view,
    required Color color,
    required double t,
    required GrainRingStyle style,
    int seed = 0,
    double alpha = 1,
    double spread = 1,
    double? trailHead,
    double trailSpan = 0.6,
    double sizeScale = 1,
  }) {
    lastCount = 0;
    if (alpha <= 0.004 || radius <= 0) return;
    var reach = style.laneWidth * spread;
    for (final l in style.lanes) {
      reach = max(reach, (l.offset.abs() + l.scatter * 1.2) * spread);
    }
    reach += style.brightSize * 3;
    final inner = max(0.0, radius - reach), outer = radius + reach;

    // Is any of the band in view?
    final nx = centre.dx.clamp(view.left, view.right);
    final ny = centre.dy.clamp(view.top, view.bottom);
    final near2 =
        (nx - centre.dx) * (nx - centre.dx) +
        (ny - centre.dy) * (ny - centre.dy);
    if (near2 > outer * outer) return;
    final fx = max(
      (view.left - centre.dx).abs(),
      (view.right - centre.dx).abs(),
    );
    final fy = max(
      (view.top - centre.dy).abs(),
      (view.bottom - centre.dy).abs(),
    );
    if (fx * fx + fy * fy < inner * inner) return;

    // The arc in view, as an angle range (unwrapped).
    double a0, a1;
    final grown = view.inflate(reach);
    if (trailHead != null) {
      a0 = trailHead - trailSpan;
      a1 = trailHead;
    } else if (grown.contains(centre)) {
      a0 = 0;
      a1 = 2 * pi;
    } else {
      final mid = atan2(
        grown.center.dy - centre.dy,
        grown.center.dx - centre.dx,
      );
      var lo = 0.0, hi = 0.0;
      for (final p in [
        grown.topLeft,
        grown.topRight,
        grown.bottomLeft,
        grown.bottomRight,
      ]) {
        var d = atan2(p.dy - centre.dy, p.dx - centre.dx) - mid;
        while (d > pi) {
          d -= 2 * pi;
        }
        while (d < -pi) {
          d += 2 * pi;
        }
        lo = min(lo, d);
        hi = max(hi, d);
      }
      a0 = mid + lo;
      a1 = mid + hi;
    }

    _n.fillRange(0, 9, 0);
    final cull = view.inflate(style.brightSize * 3);
    final keepCut = (style.keep * 1024).round();
    final clumpF = 2 * pi / style.clumpLength;
    var lane = 0;
    for (final l in style.lanes) {
      lane++;
      final lr = radius + l.offset * spread;
      if (lr <= 0) continue;
      final n = max(24, (2 * pi * lr / l.spacing).round());
      final step = 2 * pi / n;
      final phase = t * l.speed / lr;
      final k0 = ((a0 - phase) / step).floor() - 1;
      final k1 = ((a1 - phase) / step).ceil() + 1;
      // Culled slots are cheap; only a lane longer than any screen arc is
      // strided.
      final stride = max(1, ((k1 - k0) / maxSlots).ceil());
      final scatter = l.scatter * spread;
      final laneSeed = seed * 7919 + lane * 104729;
      for (var k = k0; k <= k1; k += stride) {
        final idx = k % n;
        final h = _hash(laneSeed + idx);
        if (style.clump > 0) {
          // Gathered into clumps that travel with the lane.
          final u = idx * step * lr * clumpF + seed;
          final g = (0.5 + 0.5 * sin(u) + 0.3 * sin(u * 2.37 + 1.3)).clamp(
            0.0,
            1.0,
          );
          final dens = 1 - style.clump + style.clump * g;
          if ((h & 1023) >= keepCut * dens) continue;
        } else if ((h & 1023) >= keepCut) {
          continue;
        }
        final h2 = _hash(h + 0x9e37);
        final ja = ((h >> 10) & 1023) / 1023.0 - 0.5;
        final jr = (((h >> 20) & 511) / 511.0 + (h2 & 511) / 511.0 - 1);
        final a = phase + (k + ja * 0.9) * step;
        var fade = 1.0;
        if (trailHead != null) {
          final behind = (trailHead - a) / trailSpan;
          if (behind < 0 || behind > 1) continue;
          fade = (1 - behind) * (1 - behind);
        }
        final r = lr + jr * scatter;
        final x = centre.dx + cos(a) * r;
        final y = centre.dy + sin(a) * r;
        if (x < cull.left ||
            x > cull.right ||
            y < cull.top ||
            y > cull.bottom) {
          continue;
        }
        // Twinkle: each grain on its own slow beat.
        final tw = sin(
          t * (0.6 + ((h2 >> 9) & 255) / 255.0 * 1.6) +
              ((h2 >> 17) & 1023) * 0.00614,
        );
        final v = tw * 0.5 + 0.5;
        final lvl = v * l.alpha * fade;
        final bright = lvl > 0.72 ? 2 : (lvl > 0.38 ? 1 : 0);
        if (lvl < 0.08) continue;
        final cls = l.fine ? 0 : (((h2 >> 27) & 7) == 0 ? 2 : 1);
        _add(cls * 3 + bright, x, y);
      }
    }

    // The lane: one soft gradient under the arc, no edge to it.
    if (style.laneAlpha > 0 && style.laneWidth > 0 && trailHead == null) {
      final w = style.laneWidth * spread;
      final ro = radius + w;
      if (radius - w > 0) {
        final c0 = color.withValues(alpha: 0);
        final full = a1 - a0 >= 2 * pi - 1e-6;
        _lane
          ..strokeWidth = w * 2
          ..shader = ui.Gradient.radial(
            centre,
            ro,
            [
              c0,
              color.withValues(alpha: style.laneAlpha * alpha * 0.45),
              color.withValues(alpha: style.laneAlpha * alpha),
              color.withValues(alpha: style.laneAlpha * alpha * 0.45),
              c0,
            ],
            [
              (radius - w) / ro,
              (radius - w * 0.45) / ro,
              radius / ro,
              (radius + w * 0.45) / ro,
              1,
            ],
          );
        final rect = Rect.fromCircle(center: centre, radius: radius);
        if (full) {
          canvas.drawCircle(centre, radius, _lane);
        } else {
          canvas.drawArc(rect, a0, a1 - a0, false, _lane);
        }
        _lane.shader = null;
      }
    }

    // The grains: halos under the lit ones, then up to nine point draws.
    final lit = Color.lerp(color, const Color(0xFFFFFFFF), 0.55)!;
    for (var b = 0; b < 9; b++) {
      final cnt = _n[b];
      if (cnt == 0) continue;
      lastCount += cnt;
      final level = b % 3;
      final size =
          sizeScale *
          switch (b ~/ 3) {
            0 => style.fineSize,
            1 => style.dimSize,
            _ => style.brightSize,
          };
      final pts = Float32List.sublistView(_pts[b], 0, cnt * 2);
      if (level == 2 && style.glowAlpha > 0) {
        _dot
          ..strokeWidth = size * 3.2
          ..color = color.withValues(alpha: style.glowAlpha * alpha);
        canvas.drawRawPoints(ui.PointMode.points, pts, _dot);
      }
      final a = style.grainAlpha * alpha * const [0.35, 0.65, 1.0][level];
      _dot
        ..strokeWidth = size
        ..color = (level == 2 ? lit : color).withValues(alpha: a);
      canvas.drawRawPoints(ui.PointMode.points, pts, _dot);
    }
  }
}
