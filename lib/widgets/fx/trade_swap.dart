// lib/widgets/fx/trade_swap.dart
//
// TWO ALCHEMONS TRADING PLACES, IN GRAINS OF THEMSELVES.
//
// Each comes apart crown first and streams to the other's stage along its
// own current; the two currents bow to opposite sides of the table's sigil,
// unevenly, so they pass round each other rather than through. Each grain
// warms with its creature's element in flight, trailing a little, and cools
// to its own color as it lands, feet first, where the same grain sat on the
// creature — so the creature stands up whole at the other stage. One eased
// motion, nothing bursting; every layer is gone by t = 1, when the host
// shows the two sprites in their new places.
//
// And the table's sigil: the ringed octagram {8/3} (fusion_burst.dart's
// octagramLine) laid in brass grains. Each side's confirmation lights its
// half.
//
// Plain Dart, driven by a 0..1 time; points in batches, no blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_burst.dart' show octagramLine;
import 'package:alchemons/widgets/fx/fusion_particles.dart';

double _smooth(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// One creature's grains on their way from one stage to the other.
class _Current {
  _Current(
    this.grains,
    ui.Color accent, {
    required this.side,
    required this.bowK,
    required int seed,
  }) {
    final n = grains.length;
    _start = Float32List(n);
    _land = Float32List(n);
    _lane = Float32List(n);
    _wob = Float32List(n);
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      minY = math.min(minY, grains.hy[i]);
      maxY = math.max(maxY, grains.hy[i]);
    }
    final span = math.max(1.0, maxY - minY);
    final rng = math.Random(seed);
    for (var i = 0; i < n; i++) {
      // 0 at the crown, 1 at the feet.
      final r = ((grains.hy[i] - minY) / span).clamp(0.0, 1.0);
      // Crown leaves first; feet land first. Spread wide, so each creature
      // pours out as a stream rather than flying over in one clump.
      _start[i] = 0.05 + 0.28 * r + 0.1 * rng.nextDouble();
      _land[i] = (0.8 - 0.18 * r + 0.08 * (rng.nextDouble() - 0.5)).clamp(
        _start[i] + 0.18,
        0.86,
      );
      // Where across the current it flies: most near its middle.
      final g = rng.nextDouble() + rng.nextDouble() - 1;
      _lane[i] = g;
      _wob[i] = rng.nextDouble() * math.pi * 2;
    }
    _hot = [
      for (var k = 0; k < 3; k++)
        ui.Color.lerp(accent, const ui.Color(0xFFFFFFFF), 0.12 + 0.22 * k)!,
    ];
    _tones = math.min(grains.tones.length, 16);
  }

  final SpecimenGrains grains;

  /// Which way it bows round the sigil (1 or -1, along its own heading: the
  /// two going opposite ways with the same side pass round each other), and
  /// how far, as a share of the way.
  final double side, bowK;

  late final Float32List _start, _land, _lane, _wob;
  late final List<ui.Color> _hot;
  late final int _tones;

  // Buckets: its tones, three heats, two trail fades, glints.
  final GrainBatch _b = GrainBatch(22);
  static const int _hotB = 16, _trailB = 19, _glintB = 21;

  /// Where grain [i] is at [v] (0..1 of its own flight) from [p0] to [p1],
  /// its home offset scaled by [s0] at the start and [s1] at the end.
  ui.Offset _at(
    int i,
    double v,
    ui.Offset p0,
    ui.Offset p1,
    double s0,
    double s1,
    double width,
  ) {
    final g = grains;
    final from = p0 + ui.Offset(g.hx[i] * s0, g.hy[i] * s0);
    final to = p1 + ui.Offset(g.hx[i] * s1, g.hy[i] * s1);
    final d = p1 - p0;
    final len = math.max(1.0, d.distance);
    final n = ui.Offset(-d.dy / len, d.dx / len);
    // Lopsided: a wide early bow that straightens late.
    final bow = len * bowK;
    final lane = _lane[i] * width;
    final c1 = p0 + d * 0.28 + n * (side * bow + lane);
    final c2 = p0 + d * 0.74 + n * (side * bow * 0.42 + lane * 0.6);
    final e = v * v * (3 - 2 * v);
    final u = 1 - e;
    // A cubic from the grain's place on the one stage to its place on the
    // other, through the current's two bends.
    final b =
        from * (u * u * u) +
        c1 * (3 * u * u * e) +
        c2 * (3 * u * e * e) +
        to * (e * e * e);
    // A little stir across the current, none at either end.
    final stir = math.sin(math.pi * v) * width * 0.18;
    return b + n * (math.sin(_wob[i] + v * 7) * stir);
  }

  void paint(
    ui.Canvas canvas,
    double t, {
    required ui.Offset from,
    required ui.Offset to,
    required double fromScale,
    required double toScale,
    required double width,
    required double restAlpha,
    required double fade,
  }) {
    final b = _b..clear();
    final g = grains;
    for (var i = 0; i < g.length; i++) {
      final s = _start[i], l = _land[i];
      final tone = math.min(g.tone[i], _tones - 1);
      if (t <= s) {
        if (restAlpha > 0) {
          b.add(
            tone,
            from.dx + g.hx[i] * fromScale,
            from.dy + g.hy[i] * fromScale,
          );
        }
        continue;
      }
      if (t >= l) {
        final p = ui.Offset(
          to.dx + g.hx[i] * toScale,
          to.dy + g.hy[i] * toScale,
        );
        // Just landed, the odd one still catching the light.
        if (t - l < 0.05 && _wob[i] > 5.9) {
          b.add(_glintB, p.dx, p.dy);
        } else {
          b.add(tone, p.dx, p.dy);
        }
        continue;
      }
      final v = (t - s) / (l - s);
      final p = _at(i, v, from, to, fromScale, toScale, width);
      final heat = math.sin(math.pi * v);
      b.add(_hotB + math.min(2, (heat * 3).floor()), p.dx, p.dy);
      for (var k = 1; k <= 2; k++) {
        final vk = v - 0.035 * k;
        if (vk <= 0) break;
        final q = _at(i, vk, from, to, fromScale, toScale, width);
        b.add(_trailB + k - 1, q.dx, q.dy);
      }
    }
    if (fade <= 0) return;
    final d = math.max(1.2, g.step * math.max(fromScale, toScale) * 1.15);
    ui.Color f(ui.Color c, [double k = 1]) =>
        c.withValues(alpha: (c.a * k * fade).clamp(0.0, 1.0));
    for (var k = 0; k < _tones; k++) {
      b.draw(canvas, k, d, f(g.tones[k]));
    }
    for (var k = 0; k < 3; k++) {
      b.draw(canvas, _hotB + k, d * (1.1 - 0.08 * k), f(_hot[k], 0.92));
    }
    b.draw(canvas, _trailB, d * 0.9, f(_hot[0], 0.42));
    b.draw(canvas, _trailB + 1, d * 0.75, f(_hot[0], 0.2));
    b.draw(canvas, _glintB, d * 2.2, f(const ui.Color(0x40FFFFFF)));
    b.draw(canvas, _glintB, d * 1.2, f(const ui.Color(0xFFFFFFFF)));
  }
}

/// The two creatures of a trade, as grains: [a] stands at the one stage and
/// goes to the other, [b] the other way.
class TradeSwap {
  TradeSwap({
    required SpecimenGrains a,
    required SpecimenGrains b,
    required ui.Color accentA,
    required ui.Color accentB,
  }) : _a = _Current(a, accentA, side: 1, bowK: 0.34, seed: 23),
       _b = _Current(b, accentB, side: 1, bowK: 0.24, seed: 41);

  final _Current _a, _b;

  static const Duration duration = Duration(milliseconds: 4800);

  /// How opaque the two sprites are where they stood before: gone as their
  /// grains take over.
  static double leavingOpacity(double t) => 1 - _smooth(0.02, 0.1, t);

  /// …and the two in their new places, as the grains give way to them.
  static double arrivedOpacity(double t) => _smooth(0.84, 0.94, t);

  /// The light under the stages and at the sigil: swells, then thins to
  /// nothing.
  static double light(double t) =>
      _smooth(0.0, 0.18, t) * (1 - _smooth(0.5, 0.9, t));

  /// Paints both at [t] (0..1): [a] from [posA] to [posB], [b] back.
  void paint(
    ui.Canvas canvas,
    double t, {
    required ui.Offset posA,
    required ui.Offset posB,
    double scaleA = 1,
    double scaleB = 1,
  }) {
    if (t <= 0 || t >= 1) return;
    final width = (posB - posA).distance * 0.11;
    final rest = 1 - leavingOpacity(t);
    final fade = 1 - _smooth(0.86, 0.97, t);
    _a.paint(
      canvas,
      t,
      from: posA,
      to: posB,
      fromScale: scaleA,
      toScale: scaleB,
      width: width,
      restAlpha: rest,
      fade: fade,
    );
    _b.paint(
      canvas,
      t,
      from: posB,
      to: posA,
      fromScale: scaleB,
      toScale: scaleA,
      width: width,
      restAlpha: rest,
      fade: fade,
    );
  }
}

/// The table's sigil — the ringed octagram — in brass grains. [lower] and
/// [upper] (0..1) light each half: the player's own side is the lower.
class TradeSigil {
  TradeSigil({int grains = 900}) {
    final pts = <ui.Offset>[];
    // The star: one unbroken line, each point to the third along.
    final star = octagramLine(0.86);
    var total = 0.0;
    for (var k = 1; k < star.length; k++) {
      total += (star[k] - star[k - 1]).distance;
    }
    final ring = 2 * math.pi;
    final starShare = total / (total + ring);
    final rng = math.Random(7);
    final nStar = (grains * starShare).round();
    for (var i = 0; i < nStar; i++) {
      var d = rng.nextDouble() * total;
      for (var k = 1; k < star.length; k++) {
        final seg = (star[k] - star[k - 1]).distance;
        if (d <= seg) {
          final p = ui.Offset.lerp(star[k - 1], star[k], d / seg)!;
          pts.add(p + _jitter(rng, 0.012));
          break;
        }
        d -= seg;
      }
    }
    for (var i = nStar; i < grains; i++) {
      final a = rng.nextDouble() * ring;
      pts.add(ui.Offset(math.cos(a), math.sin(a)) + _jitter(rng, 0.012));
    }
    _x = Float32List.fromList([for (final p in pts) p.dx]);
    _y = Float32List.fromList([for (final p in pts) p.dy]);
    _lit = Float32List.fromList([for (final _ in pts) rng.nextDouble()]);
  }

  static ui.Offset _jitter(math.Random rng, double r) => ui.Offset(
    (rng.nextDouble() - 0.5) * r * 2,
    (rng.nextDouble() - 0.5) * r * 2,
  );

  late final Float32List _x, _y, _lit;
  final GrainBatch _b = GrainBatch(4);

  static const ui.Color brass = ui.Color(0xFFB89656);
  static const ui.Color brassBright = ui.Color(0xFFE4C16A);

  /// Paints it at [c], radius [r]. [lower]/[upper]: how lit each half is.
  /// [scatter] (0..1) loosens it into a drifting cloud, for the trade.
  void paint(
    ui.Canvas canvas,
    ui.Offset c,
    double r, {
    double lower = 0,
    double upper = 0,
    double scatter = 0,
    double opacity = 1,
  }) {
    if (opacity <= 0) return;
    final b = _b..clear();
    for (var i = 0; i < _x.length; i++) {
      var x = _x[i], y = _y[i];
      if (scatter > 0) {
        // Each grain drifts off round the ring, the further the later.
        final a = math.atan2(y, x) + scatter * (0.6 + _lit[i]);
        final rr = math.sqrt(x * x + y * y) * (1 + scatter * 0.5 * _lit[i]);
        x = math.cos(a) * rr;
        y = math.sin(a) * rr;
      }
      final lit = y > 0 ? lower : upper;
      // Lights grain by grain, not all at once.
      final on = lit > _lit[i] ? 1 : 0;
      b.add(
        on == 1 ? (_lit[i] > 0.93 ? 3 : 2) : (_lit[i] > 0.5 ? 1 : 0),
        c.dx + x * r,
        c.dy + y * r,
      );
    }
    final fade = opacity * (1 - scatter);
    ui.Color f(ui.Color col, double a) =>
        col.withValues(alpha: (a * fade).clamp(0.0, 1.0));
    const d = 1.6;
    b.draw(canvas, 0, d, f(brass, 0.16));
    b.draw(canvas, 1, d, f(brass, 0.26));
    b.draw(canvas, 2, d * 1.1, f(brassBright, 0.85));
    b.draw(canvas, 3, d * 1.6, f(const ui.Color(0xFFFFF1CF), 0.95));
  }
}

/// A pool of [color] light at [c], radius [r] (a radial gradient, no blur).
void paintLightPool(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  ui.Color color,
  double strength, {
  double squash = 0.42,
}) {
  if (strength <= 0) return;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(1, squash);
  final paint = ui.Paint()
    ..shader = ui.Gradient.radial(
      ui.Offset.zero,
      r,
      [
        color.withValues(alpha: 0.42 * strength),
        color.withValues(alpha: 0.12 * strength),
        color.withValues(alpha: 0),
      ],
      const [0, 0.45, 1],
    );
  canvas.drawCircle(ui.Offset.zero, r, paint);
  canvas.restore();
}
