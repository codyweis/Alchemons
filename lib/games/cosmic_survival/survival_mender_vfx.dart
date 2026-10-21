// lib/games/cosmic_survival/survival_mender_vfx.dart
//
// How a mender looks (EnemyTrait.mender). Its body is the phantom's eclipse,
// drawn by the shared enemy pass; this adds what makes it a mender. While it
// gathers a pulse, a mantle of its element's grains draws in toward it, fuller
// the closer the pulse is. When it pulses, a soft current of those grains
// flows out into each body it mends and sinks into it, and the body's light
// swells and thins as the heal lands. A burning body's current gutters: half
// its grains burn off on the way, which is the half of the heal it loses.
//
// Budget: no blur, no allocation per grain per frame. A mantle is worked out
// from the clock, so it has no state. Flows are a capped pool of streams.
// Grains go out as drawRawPoints batches, five per colour on screen, plus one
// soft light per body being mended.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/enemy_body_art.dart' show enemyPalette;
import 'package:alchemons/games/cosmic/vfx_shapes.dart' show vfxSpill;
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:flutter/painting.dart';

/// Grains in a mender's mantle when it is fully gathered.
const int kMenderMantleGrains = 42;

/// Grains in one stream of a mend.
const int kMenderFlowGrains = 20;

/// The most streams in the air at once; the oldest gives way.
const int kMenderFlowCap = 24;

// What a burning grain turns to as it gutters: an ember, not the element.
const _ember = Color(0xFFE2793F);

double _frac(double x) => x - x.floorToDouble();

/// A stable 0..1 from two numbers, for per-grain variety without a stream of
/// random numbers.
double _hash(double a, double b) =>
    _frac(sin(a * 12.9898 + b * 78.233) * 43758.5453);

double _smooth(double t) {
  final u = t.clamp(0.0, 1.0);
  return u * u * (3 - 2 * u);
}

/// How gathered a mender's next pulse is: 0 just after a pulse, 1 ready.
double menderCharge(CosmicSurvivalEnemy mender) =>
    (1 - mender.menderPulseTimer / CosmicSurvivalBalance.menderPulseInterval)
        .clamp(0.0, 1.0);

// ── Batches ─────────────────────────────────────────────────────────────────

class _Buf {
  Float32List xy = Float32List(256);
  int n = 0;

  void add(double x, double y) {
    if (n + 2 > xy.length) {
      xy = Float32List(xy.length * 2)..setAll(0, xy);
    }
    xy[n++] = x;
    xy[n++] = y;
  }
}

/// One colour's grains, in the buckets they are painted from: trail, faint,
/// lit, hot, and guttering embers.
class _Group {
  int argb = 0;
  Color essence = const Color(0xFFFFFFFF);
  Color hot = const Color(0xFFFFFFFF);
  final trail = _Buf(), faint = _Buf(), lit = _Buf(), core = _Buf();
  final ember = _Buf(), ash = _Buf();

  bool get isEmpty =>
      trail.n == 0 &&
      faint.n == 0 &&
      lit.n == 0 &&
      core.n == 0 &&
      ember.n == 0 &&
      ash.n == 0;
}

final Paint _dots = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

void _points(Canvas c, _Buf b, double size, Color color) {
  if (b.n == 0) return;
  _dots
    ..strokeWidth = size
    ..color = color;
  c.drawRawPoints(
    ui.PointMode.points,
    Float32List.sublistView(b.xy, 0, b.n),
    _dots,
  );
  b.n = 0;
}

class _Batches {
  final List<_Group> _groups = List.generate(4, (_) => _Group());
  int _used = 0;

  _Group groupFor(Canvas c, String element, Color color) {
    final argb = color.toARGB32();
    for (var i = 0; i < _used; i++) {
      if (_groups[i].argb == argb) return _groups[i];
    }
    // Four colours on screen at once is already unusual; a fifth paints
    // what the last slot holds and takes it over.
    if (_used == _groups.length) {
      _paint(c, _groups[_used - 1]);
      _used--;
    }
    final g = _groups[_used++];
    final pal = enemyPalette(element, color);
    g
      ..argb = argb
      ..essence = pal.essence
      ..hot = pal.hot;
    return g;
  }

  void _paint(Canvas c, _Group g) {
    if (g.isEmpty) return;
    _points(c, g.trail, 1.8, g.essence.withValues(alpha: 0.3));
    _points(c, g.faint, 2.3, g.essence.withValues(alpha: 0.5));
    _points(c, g.lit, 3.0, g.essence.withValues(alpha: 0.9));
    _points(c, g.core, 1.4, g.hot.withValues(alpha: 0.95));
    _points(c, g.ash, 1.6, _ember.withValues(alpha: 0.32));
    _points(c, g.ember, 2.4, _ember.withValues(alpha: 0.72));
  }

  void flush(Canvas c) {
    for (var i = 0; i < _used; i++) {
      _paint(c, _groups[i]);
    }
    _used = 0;
  }
}

final _Batches _batches = _Batches();

// ── The mantle ──────────────────────────────────────────────────────────────

/// Paints the mantle of every mender in [menders] that is inside [view].
///
/// Each grain rides a slow inward spiral from about three body-widths out to
/// the body's edge, quickening as it nears, and fades in and out along it so
/// none of them pops. The mantle leans to one side and that side turns slowly,
/// so it reads as being drawn in rather than as a ring. How many grains are
/// out follows the charge: thin after a pulse, full when the next is ready.
void paintMenderMantles(
  Canvas c,
  List<CosmicSurvivalEnemy> menders,
  Rect view,
  double time,
) {
  if (menders.isEmpty) return;
  for (final m in menders) {
    if (m.isDead) continue;
    final reach = m.radius * 4.2;
    final p = m.position;
    if (p.dx < view.left - reach ||
        p.dx > view.right + reach ||
        p.dy < view.top - reach ||
        p.dy > view.bottom + reach) {
      continue;
    }
    final color = m.visualColor ?? _elementColor(m.element);
    final g = _batches.groupFor(c, m.element, color);
    _addMantle(g, m, time, menderCharge(m));
  }
  _batches.flush(c);
}

void _addMantle(_Group g, CosmicSurvivalEnemy m, double time, double charge) {
  final seed = (identityHashCode(m) & 1023) / 1023;
  final r = m.radius;
  final lean = seed * 2 * pi + time * 0.21;
  for (var j = 0; j < kMenderMantleGrains; j++) {
    final h1 = _hash(j.toDouble(), seed);
    final h2 = _hash(seed * 7.1, j + 0.5);
    final h3 = _hash(j * 1.7 + 3.0, seed * 3.3);
    // Born over the gather: each grain has its own share of the charge at
    // which it comes out, and swells in over the next quarter.
    final present = _smooth((charge * 1.25 - h3 * 0.95) / 0.25);
    if (present <= 0.02) continue;
    final period = 2.6 + 1.6 * h1;
    final s = _frac(time / period + h2);
    final a0 = j * 2.39996 + seed * 6.0;
    final env = pow(sin(pi * s), 0.7) * present;
    if (env <= 0.12) continue;
    final (x, y) = _mantleAt(m.position, r, a0, lean, s, time);
    if (env > 0.45) {
      g.lit.add(x, y);
      if (s > 0.6) g.core.add(x, y);
    } else {
      g.faint.add(x, y);
    }
    if (env > 0.25) {
      for (var k = 1; k <= 3; k++) {
        final sk = s - 0.035 * k;
        if (sk <= 0) break;
        final (tx, ty) = _mantleAt(m.position, r, a0, lean, sk, time);
        g.trail.add(tx, ty);
      }
    }
  }
}

/// Where a mantle grain is at [s] along its way in: from about three body
/// widths out to the body's edge, turning faster as it nears, further out on
/// the side the mantle leans to.
(double, double) _mantleAt(
  Offset c,
  double r,
  double a0,
  double lean,
  double s,
  double time,
) {
  final d = r * (1.05 + 2.4 * pow(1 - s, 1.4));
  final a = a0 + 2.3 * s * s + time * 0.12;
  final lop = 1 + 0.3 * cos(a - lean);
  return (c.dx + cos(a) * d * lop, c.dy + sin(a) * d * lop);
}

// ── The flow ────────────────────────────────────────────────────────────────

class _Stream {
  _Stream(
    this.from,
    this.body,
    this.element,
    this.color,
    this.travel,
    int seed,
  ) {
    // A current, not a spray: the grains share a side to bow toward and
    // keep close to one path, braiding about it, and leave over the first
    // third of the trip.
    final side = _hash(seed.toDouble(), 1.3) < 0.5 ? -1.0 : 1.0;
    for (var i = 0; i < kMenderFlowGrains; i++) {
      final h = _hash(i.toDouble(), seed * 0.37);
      final k = _hash(seed * 0.91, i + 2.0);
      delay[i] = travel * 0.34 * (i / (kMenderFlowGrains - 1)) + 0.03 * h;
      dur[i] = travel * (0.74 + 0.1 * k);
      bend[i] = side * (0.2 + 0.1 * h) + (k - 0.5) * 0.06;
      weave[i] = (h - 0.5) * 2;
      startA[i] = 2 * pi * _hash(i * 3.1, seed + 0.2);
      landX[i] = (h - 0.5) * 0.6;
      landY[i] = (k - 0.5) * 0.6;
    }
  }

  final Offset from;
  final CosmicSurvivalEnemy body;
  final String element;
  final Color color;
  final double travel;
  double age = 0;

  final Float32List delay = Float32List(kMenderFlowGrains);
  final Float32List dur = Float32List(kMenderFlowGrains);
  final Float32List bend = Float32List(kMenderFlowGrains);
  final Float32List weave = Float32List(kMenderFlowGrains);
  final Float32List startA = Float32List(kMenderFlowGrains);
  final Float32List landX = Float32List(kMenderFlowGrains);
  final Float32List landY = Float32List(kMenderFlowGrains);

  /// Seconds the light on the body takes to swell and thin once the grains
  /// are in.
  static const double glowTail = 0.55;

  bool get done => age > travel * 1.25 + glowTail;
}

/// The heal flowing out of menders into the bodies they mend. Visual only:
/// the heal itself lands on the game's own clock.
class MenderFlows {
  final List<_Stream> _streams = [];
  int _sent = 0;

  /// Streams in the air.
  int get length => _streams.length;

  /// Starts a stream of [from]'s grains toward [to], arriving over [travel]
  /// seconds.
  void send(
    CosmicSurvivalEnemy from,
    CosmicSurvivalEnemy to,
    Color color,
    double travel,
  ) {
    if (_streams.length >= kMenderFlowCap) _streams.removeAt(0);
    _streams.add(
      _Stream(
        from.position,
        to,
        from.element,
        from.visualColor ?? color,
        travel,
        (identityHashCode(from) ^ (_sent++ * 7919)) & 0xFFFF,
      ),
    );
  }

  void update(double dt) {
    if (_streams.isEmpty) return;
    for (final s in _streams) {
      s.age += dt;
    }
    _streams.removeWhere((s) => s.done);
  }

  void clear() => _streams.clear();

  /// Paints the streams inside [view], and the light on each body as its
  /// heal lands.
  void paint(Canvas c, Rect view) {
    if (_streams.isEmpty) return;
    for (final s in _streams) {
      final to = s.body.position;
      final reach = s.body.radius * 3;
      final inView =
          !(max(s.from.dx, to.dx) < view.left - reach ||
              min(s.from.dx, to.dx) > view.right + reach ||
              max(s.from.dy, to.dy) < view.top - reach ||
              min(s.from.dy, to.dy) > view.bottom + reach);
      if (!inView) continue;
      final burning = s.body.burnTimer > 0;
      // The light swells as the grains sink in and thins after; half as
      // much on a burning body, as the heal is.
      final glowT =
          (s.age - s.travel * 0.6) / (s.travel * 0.65 + _Stream.glowTail);
      if (glowT > 0 && glowT < 1 && !s.body.isDead) {
        final swell = sin(pi * glowT) * (burning ? 0.5 : 1.0);
        vfxSpill(c, to, s.body.radius * 2.3, s.color, 0.34 * swell);
      }
    }
    for (final s in _streams) {
      _addStream(c, s);
    }
    _batches.flush(c);
  }

  void _addStream(Canvas c, _Stream s) {
    if (s.age > s.travel * 1.25) return;
    final g = _batches.groupFor(c, s.element, s.color);
    final burning = s.body.burnTimer > 0;
    final from = s.from;
    // Where the grains land: inside the body, wherever it has got to.
    final to = s.body.position;
    final dx = to.dx - from.dx, dy = to.dy - from.dy;
    final len = max(1.0, sqrt(dx * dx + dy * dy));
    final nx = -dy / len, ny = dx / len;
    // The grains leave from round the mender, about where its mantle sits.
    const rFrom = 18.0;
    final rTo = s.body.radius;
    for (var i = 0; i < kMenderFlowGrains; i++) {
      final u0 = (s.age - s.delay[i]) / s.dur[i];
      if (u0 <= 0 || u0 >= 1) continue;
      final gutters = burning && i.isOdd;
      if (gutters && u0 > 0.8) continue;
      // Leaves from its place in the mantle, lands inside the body.
      final sx = from.dx + cos(s.startA[i]) * rFrom;
      final sy = from.dy + sin(s.startA[i]) * rFrom;
      final ex = to.dx + s.landX[i] * rTo;
      final ey = to.dy + s.landY[i] * rTo;
      final cx = (sx + ex) / 2 + nx * len * s.bend[i];
      final cy = (sy + ey) / 2 + ny * len * s.bend[i];
      final weave = s.weave[i] * min(12.0, len * 0.06);
      final u = _smooth(u0);
      // Braided about the path, widest mid-way, gathered at both ends.
      final w = sin(pi * u) * weave;
      var x = _bez(sx, cx, ex, u) + nx * w;
      var y = _bez(sy, cy, ey, u) + ny * w;
      if (gutters && u0 > 0.3) {
        // Burns off: loosens from the current, lifts and goes to embers.
        final k = (u0 - 0.3) / 0.5;
        final away = s.bend[i] >= 0 ? 1.0 : -1.0;
        x += nx * 16 * k * away;
        y += ny * 16 * k * away - 12 * k;
        if (k > 0.2) {
          // Lit as it catches, then dimming to nothing before it is gone.
          (k < 0.6 ? g.ember : g.ash).add(x, y);
          continue;
        }
      }
      if (u0 < 0.1) {
        g.faint.add(x, y);
      } else if (u0 > 0.86) {
        // Sinking in: only the hot centre is left.
        g.core.add(x, y);
      } else {
        g.lit.add(x, y);
        if (u0 > 0.4 && u0 < 0.8) g.core.add(x, y);
      }
      for (var k = 1; k <= 4; k++) {
        final back = u0 - 0.045 * k;
        if (back <= 0) break;
        final uk = _smooth(back);
        final wk = sin(pi * uk) * weave;
        g.trail.add(
          _bez(sx, cx, ex, uk) + nx * wk,
          _bez(sy, cy, ey, uk) + ny * wk,
        );
      }
    }
  }
}

/// One coordinate of the quadratic curve from [a] through [b] to [c].
double _bez(double a, double b, double c, double u) =>
    (1 - u) * (1 - u) * a + 2 * (1 - u) * u * b + u * u * c;

Color _elementColor(String element) => enemyPalette(element).essence;
