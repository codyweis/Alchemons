// lib/games/cosmic_survival/surge_grains.dart
//
// What a kill pays into the surge. Each body leaves a few violet grains where
// it fell, carrying its share of the meter. They wait there until the ship
// passes close enough to pull them in, or until they lie inside the core's
// field, which drinks them; the meter is paid when a grain arrives. Grains
// the ship leaves stay out, wave after wave, until it gathers them. Surge
// Magnet widens the ship's pull, and at its top level a cleared wave sends
// every grain still lying out into the core. Autopilot flies a ship that is
// let go to them ([SurgeGrains.gatherTarget]).
//
// Budget: at most [SurgeGrains.cap] grains; past it a kill's value is added
// to grains already lying out instead of new ones. Heads and trails go out
// as three drawRawPoints calls. No blur.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart' show EnemyTier;
import 'package:flutter/painting.dart';

/// How far the ship pulls grains from at each Surge Magnet level (the top
/// level keeps the last reach).
const List<double> kSurgePullRange = [150, 230, 310, 390];

/// The Surge Magnet level at which a cleared wave sends the grains left out
/// into the core.
const int kSurgeMagnetMaxLevel = 4;

/// How many grains a body leaves, by size.
int surgeGrainsFor(EnemyTier tier, bool elite) =>
    switch (tier) {
      EnemyTier.wisp => 2,
      EnemyTier.drone || EnemyTier.sentinel || EnemyTier.phantom => 3,
      EnemyTier.brute => 8,
      EnemyTier.colossus => 14,
    } +
    (elite ? 5 : 0);

// The surge's own violet (SurvivalInk.surge / surgeHot / surgeDeep), so a
// grain reads as the meter it fills, and never as the brass of a Light or
// Fire wave's bodies.
const _surge = Color(0xFF9A7CEB);
const _surgeHot = Color(0xFFF0DCFF);
const _surgeDeep = Color(0xFF6B58D8);

/// Grains within this of the core's centre are taken by it.
const double _kCoreDrink = 170;

/// Grains within this of the ship are taken by it.
const double _kShipTake = 18;

/// Seconds a grain hangs where it fell before it can travel.
const double _kHang = 0.45;

class _Grain {
  _Grain(this.x, this.y, this.vx, this.vy, this.value);
  double x, y, vx, vy, value;
  double age = 0;

  /// Where it is headed once it moves: 0 lying, 1 to the ship, 2 to the core.
  int heading = 0;
  final Float32List trail = Float32List(10);
  double sample = 0;
}

class SurgeGrains {
  SurgeGrains({Random? random}) : _rng = random ?? Random(5);

  static const int cap = 900;
  final Random _rng;
  final List<_Grain> _grains = [];

  int get length => _grains.length;

  /// Meter value left by kills, and taken in, over the grains' lifetime.
  double spawnedValue = 0, takenValue = 0;

  /// Meter value lying on the field, not yet collected.
  double get valueOut => _grains.fold(0.0, (sum, g) => sum + g.value);

  /// Leaves [count] grains at [at] carrying [value] between them.
  void spawn(Offset at, int count, double value) {
    if (value <= 0 || count <= 0) return;
    spawnedValue += value;
    final room = cap - _grains.length;
    if (room <= 0) {
      // Full: the value rides on grains already out, nothing is lost.
      _grains[_rng.nextInt(_grains.length)].value += value;
      return;
    }
    final n = min(count, room);
    final each = value / n;
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final s = 14 + _rng.nextDouble() * 40;
      final g = _Grain(at.dx, at.dy, cos(a) * s, sin(a) * s, each);
      for (var k = 0; k < 10; k += 2) {
        g.trail[k] = at.dx;
        g.trail[k + 1] = at.dy;
      }
      _grains.add(g);
    }
  }

  /// Where a ship at [from] should fly to gather: the lying grain worth the
  /// most for the trip, within [reach] of the [core] and outside its field
  /// (those it drinks for itself). Grains near [prefer], the last pick, count
  /// for more, so the ship holds its course instead of dithering between two
  /// heaps. Null when there is nothing out there to fetch.
  Offset? gatherTarget(
    Offset from,
    Offset core, {
    required double reach,
    Offset? prefer,
  }) {
    _Grain? best;
    var bestScore = 0.0;
    const drink2 = _kCoreDrink * _kCoreDrink;
    final reach2 = reach * reach;
    for (final g in _grains) {
      if (g.heading != 0) continue;
      final cx = g.x - core.dx, cy = g.y - core.dy;
      final c2 = cx * cx + cy * cy;
      if (c2 < drink2 || c2 > reach2) continue;
      final sx = g.x - from.dx, sy = g.y - from.dy;
      var score = g.value / (sqrt(sx * sx + sy * sy) + 220);
      if (prefer != null) {
        final px = g.x - prefer.dx, py = g.y - prefer.dy;
        if (px * px + py * py < 80 * 80) score *= 1.6;
      }
      if (score > bestScore) {
        bestScore = score;
        best = g;
      }
    }
    return best == null ? null : Offset(best.x, best.y);
  }

  /// Sends every grain out now to the core (a cleared wave). Grains left by
  /// later kills wait as usual.
  void flushToCore() {
    for (final g in _grains) {
      g.heading = 2;
      g.age = max(g.age, _kHang);
    }
  }

  /// Moves the grains. [pull] is the ship's reach (null while it is down);
  /// [onTaken] receives each grain's value as it arrives, and whether the
  /// ship took it.
  void update(
    double dt,
    Offset core,
    Offset ship, {
    required double? pull,
    required void Function(double value, bool byShip) onTaken,
  }) {
    if (_grains.isEmpty) return;
    final drag = exp(-4 * dt);
    final steer = 1 - exp(-5 * dt);
    for (final g in _grains) {
      g.age += dt;
      final cx = g.x - core.dx, cy = g.y - core.dy;
      final toCoreDist = sqrt(cx * cx + cy * cy);
      if (g.age >= _kHang && g.heading == 0) {
        if (toCoreDist < _kCoreDrink) {
          g.heading = 2;
        } else if (pull != null) {
          final sx = ship.dx - g.x, sy = ship.dy - g.y;
          if (sx * sx + sy * sy < pull * pull) g.heading = 1;
        }
      }
      switch (g.heading) {
        case 0:
          g.vx *= drag;
          g.vy *= drag;
        case 1:
          if (pull == null) {
            g.heading = 0;
            break;
          }
          final sx = ship.dx - g.x, sy = ship.dy - g.y;
          final d = max(1.0, sqrt(sx * sx + sy * sy));
          if (d < _kShipTake) {
            onTaken(g.value, true);
            takenValue += g.value;
            g.value = 0;
            g.age = -1;
            continue;
          }
          final speed = 260 + 520 * (1 - min(1.0, d / pull));
          g.vx += (sx / d * speed - g.vx) * steer;
          g.vy += (sy / d * speed - g.vy) * steer;
        case 2:
          if (toCoreDist < _kCoreDrink - 8) {
            onTaken(g.value, false);
            takenValue += g.value;
            g.value = 0;
            g.age = -1;
            continue;
          }
          // Toward a point on the meter band a little round from here, so
          // the stream curls in rather than falling straight.
          final a = atan2(cy, cx) + 0.5;
          final tx = core.dx + cos(a) * 158, ty = core.dy + sin(a) * 158;
          final ex = tx - g.x, ey = ty - g.y;
          final el = max(1.0, sqrt(ex * ex + ey * ey));
          final u = ((g.age - _kHang) / 1.2).clamp(0.0, 1.0);
          final speed = 90 + 400 * u * u * (3 - 2 * u);
          g.vx += (ex / el * speed - g.vx) * steer;
          g.vy += (ey / el * speed - g.vy) * steer;
      }
      g.x += g.vx * dt;
      g.y += g.vy * dt;
      g.sample += dt;
      if (g.sample > 0.035) {
        g.sample = 0;
        g.trail.setRange(2, 10, g.trail, 0);
        g.trail[0] = g.x;
        g.trail[1] = g.y;
      }
    }
    _grains.removeWhere((g) => g.age < 0);
  }

  final Float32List _heads = Float32List(cap * 2);
  final Float32List _tails = Float32List(cap * 10);
  final Paint _dots = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  /// Paints the grains inside [view]: lying ones as violet points, moving
  /// ones with a short trail behind.
  void paint(Canvas c, Rect view) {
    var h = 0, t = 0;
    for (final g in _grains) {
      if (g.x < view.left ||
          g.x > view.right ||
          g.y < view.top ||
          g.y > view.bottom) {
        continue;
      }
      _heads[h++] = g.x;
      _heads[h++] = g.y;
      if (g.heading != 0) {
        for (var k = 0; k < 10; k++) {
          _tails[t++] = g.trail[k];
        }
      }
    }
    if (t > 0) {
      _dots
        ..strokeWidth = 2.0
        ..color = _surgeDeep.withValues(alpha: 0.42);
      c.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(_tails, 0, t),
        _dots,
      );
    }
    if (h == 0) return;
    final heads = Float32List.sublistView(_heads, 0, h);
    _dots
      ..strokeWidth = 3.4
      ..color = _surge.withValues(alpha: 0.92);
    c.drawRawPoints(ui.PointMode.points, heads, _dots);
    _dots
      ..strokeWidth = 1.6
      ..color = _surgeHot.withValues(alpha: 0.95);
    c.drawRawPoints(ui.PointMode.points, heads, _dots);
  }

  void clear() => _grains.clear();
}
