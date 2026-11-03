// lib/games/cosmic_survival/survival_death_vfx.dart
//
// A body coming apart. A kill used to take the body off the field on the
// frame it died and throw six grains a pixel or two across, out of the same
// 150-grain pool every ability shares — in a horde most deaths drew nothing
// at all, and a colossus died exactly like a wisp. Now the body's light goes
// out where it fell, and it loosens into grains of its own material that
// carry on a little the way it was moving, curl, and cool as they go. Size
// sets how long that takes and how much of it there is.
//
// A death that is also a blast — Elemental Fury's splash, a volatile elite,
// a body bursting on the core, a rooted Mane+Plant mark — throws its grains
// out as far as the blast reaches, in lopsided clumps over a short wide pool
// of light, so the bodies it kills are seen to be inside it. No rings: the
// reach is shown by where the grains land.
//
// Budget: at most [SurvivalDeaths.cap] deaths live; past a crowd of them a
// new death loosens fewer grains. Each grain is a closed-form path from its
// death's seed, so nothing is stored per grain, and every grain goes out in
// the game's one ability-grain atlas draw. Never touches the run's random
// stream: a seeded run plays out the same with or without it.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/ability_grains.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart' show EnemyTier;
import 'package:alchemons/games/cosmic/enemy_body_art.dart';

/// One body coming apart.
class SurvivalDeath {
  SurvivalDeath._({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.radius,
    required this.grains,
    required this.life,
    required this.hot,
    required this.essence,
    required this.rim,
    required this.seed,
    required this.pool,
    required this.blast,
    required this.blastGrains,
    required this.blastRgb,
    required this.blastLight,
  });

  /// Where it fell.
  final double x, y;

  /// How far its momentum carries the grains, in world units.
  final double dx, dy;
  final double radius;
  final int grains;
  final double life;

  /// Its light, white-hot to edge (0xRRGGBB).
  final int hot, essence, rim;
  final int seed;

  /// Strength of the light a heavy body leaves on the ground (0 for chaff).
  final double pool;

  /// How far its blast reaches (0: none), the grains that show it, their
  /// colour and the strength of its light.
  final double blast;
  final int blastGrains;
  final int blastRgb;
  final double blastLight;

  double age = 0;
}

/// The deaths on the field.
class SurvivalDeaths {
  /// Most deaths drawn at once; the oldest give way.
  static const int cap = 220;

  /// Past this many live deaths, a new one loosens proportionally fewer
  /// grains (never fewer than three).
  static const int crowd = 70;

  /// Reduced quality: half the grains.
  bool thin = false;

  final List<SurvivalDeath> _live = [];
  int _seq = 0;
  int _drawn = 0;

  int get length => _live.length;

  /// Grains the last [paint] drew.
  int get lastDrawn => _drawn;
  void clear() => _live.clear();

  /// A body of [tier] and [radius] dies at [at], moving at [velocity].
  /// [blast] > 0 when its death is also a blast that far across, drawn in
  /// [blastTint] (its own light if null) at [blastLight].
  void add({
    required ui.Offset at,
    required ui.Offset velocity,
    required double radius,
    required EnemyTier tier,
    required EnemyPalette palette,
    bool elite = false,
    double blast = 0,
    ui.Color? blastTint,
    double blastLight = 0.1,
  }) {
    final (count, life, carry) = switch (tier) {
      EnemyTier.wisp => (7, 0.42, 0.16),
      EnemyTier.drone => (10, 0.5, 0.18),
      EnemyTier.sentinel => (14, 0.58, 0.2),
      EnemyTier.phantom => (12, 0.55, 0.2),
      EnemyTier.brute => (30, 0.85, 0.24),
      EnemyTier.colossus => (46, 1.1, 0.26),
    };
    final heavy = tier == EnemyTier.brute || tier == EnemyTier.colossus;
    var scale = thin ? 0.5 : 1.0;
    if (_live.length > crowd) scale *= crowd / _live.length;
    int thinned(int n) => max(3, (n * scale).round());
    final blasting = blast > 0;
    if (_live.length >= cap) _live.removeRange(0, _live.length - cap + 1);
    _live.add(
      SurvivalDeath._(
        x: at.dx,
        y: at.dy,
        dx: velocity.dx * carry,
        dy: velocity.dy * carry,
        radius: radius,
        grains: thinned(count + (elite ? 8 : 0)),
        life: blasting ? max(life, 0.6) : life,
        hot: _rgb(palette.hot),
        essence: _rgb(palette.essence),
        rim: _rgb(palette.rim),
        seed: _seq++,
        pool: heavy ? (tier == EnemyTier.colossus ? 0.2 : 0.15) : 0,
        blast: blast,
        // A faint blast (Fury erupts on every kill) throws half the grains.
        blastGrains: blasting
            ? thinned(
                ((blast / 5).round().clamp(10, 28) *
                        (blastLight < 0.12 ? 0.5 : 1))
                    .round(),
              )
            : 0,
        blastRgb: _rgb(blastTint ?? palette.essence),
        blastLight: blastLight,
      ),
    );
  }

  void update(double dt) {
    if (_live.isEmpty) return;
    for (final d in _live) {
      d.age += dt;
    }
    _live.removeWhere((d) => d.age >= d.life);
  }

  /// Adds every death in [view] to [batch] and flushes it.
  void paint(ui.Canvas canvas, ui.Rect view, AbilityGrainBatch batch) {
    _drawn = 0;
    if (_live.isEmpty) return;
    for (final d in _live) {
      final reach = max(d.radius * 3, d.blast) + 16;
      if (d.x + reach < view.left ||
          d.x - reach > view.right ||
          d.y + reach < view.top ||
          d.y - reach > view.bottom) {
        continue;
      }
      _paintOne(d, batch);
    }
    _drawn = batch.length;
    batch.flush(canvas);
  }

  static void _paintOne(SurvivalDeath d, AbilityGrainBatch batch) {
    final t = (d.age / d.life).clamp(0.0, 1.0);
    final r = d.radius;
    final carried = _out(t);
    final cx = d.x + d.dx * carried;
    final cy = d.y + d.dy * carried;

    // The light it stood in, left on the ground by a heavy body.
    if (d.pool > 0) {
      batch.add(d.x, d.y, r * 1.5, d.essence, d.pool * (1 - _ease(0.15, 1, t)));
    }
    // A blast's light: wide, faint, gone before its grains settle.
    if (d.blast > 0) {
      batch.add(
        d.x,
        d.y,
        d.blast * 0.72,
        d.blastRgb,
        d.blastLight * (1 - _ease(0.05, 0.65, t)),
      );
    }
    // Its own light going out: a soft glow and a white-hot heart that
    // gutter in the first part of the death.
    batch.add(cx, cy, r * 0.95, d.essence, 0.55 * (1 - _ease(0, 0.45, t)));
    batch.add(cx, cy, r * 0.42, d.hot, 0.75 * (1 - _ease(0, 0.28, t)));

    // The body's grains: loosened from inside it over the first part of the
    // death, then eased out on a slow curl, cooling and dimming.
    final s = d.seed * 53;
    for (var i = 0; i < d.grains; i++) {
      final k = s + i * 7;
      final born = _r(k) * 0.3;
      if (t < born) continue;
      final g = ((t - born) / (1 - born)).clamp(0.0, 1.0);
      final e = _out(g);
      final start = r * 0.85 * sqrt(_r(k + 1));
      final reach = r * (0.7 + 1.5 * _r(k + 2));
      final turn = (_r(k + 3) - 0.5) * 1.6 * e;
      final a = _r(k + 4) * 2 * pi + turn;
      final dist = start + reach * e;
      final x = cx + cos(a) * dist;
      final y = cy + sin(a) * dist;
      // Fine grains whatever the body's size: a colossus loosens into more
      // of them, not bigger ones.
      final size = (1.1 + r * 0.05) * (0.75 + 0.5 * _r(k + 5)) * (1 - 0.5 * g);
      final from = i % 4 == 0 ? d.hot : d.essence;
      final rgb = _lerpRgb(d.rim, from, (1 - g) * (1 - g));
      batch.add(x, y, size, rgb, 0.9 * (1 - _ease(0.35, 1, g)));
    }

    // A blast's grains: out in lopsided clumps to where it reached, fast at
    // first and settling, so the reach reads from where they come to rest.
    // Each trails two fainter grains a little behind it while it is moving,
    // so the throw reads as a current rather than a scatter of dots.
    if (d.blastGrains > 0) {
      final lobe0 = _r(s + 900) * 2 * pi;
      // Faint blasts throw faint grains; one that hurts the party is bright.
      final fade = (1 - _ease(0.45, 1, t)) * min(1.0, 0.45 + d.blastLight * 2);
      final rgb = _lerpRgb(d.rim, d.blastRgb, 1 - t * t);
      for (var i = 0; i < d.blastGrains; i++) {
        final k = s + 400 + i * 5;
        final lobe = lobe0 + (i % 3) * (2 * pi / 3) + (_r(k) - 0.5) * 1.5;
        final far = d.blast * (0.45 + 0.55 * sqrt(_r(k + 1)));
        final ca = cos(lobe), sa = sin(lobe);
        final size = (1.8 + 1.8 * _r(k + 2)) * (1 - 0.35 * t);
        for (var j = 2; j >= 0; j--) {
          final e = _out((t * 1.5 - j * 0.06).clamp(0.0, 1.0));
          if (j > 0 && e <= 0) continue;
          final dist = far * e;
          batch.add(
            d.x + ca * dist,
            d.y + sa * dist,
            size * (1 - 0.25 * j),
            rgb,
            0.9 * fade * (j == 0 ? 1 : 0.32 / j) * (j > 0 ? 1 - e : 1),
          );
        }
      }
    }
  }

  static int _rgb(ui.Color c) => c.toARGB32() & 0xFFFFFF;
}

/// Fixed random values, so a death's grains are a pure function of its seed
/// and nothing draws from the run's own stream.
final Float32List _table = () {
  final r = Random(4409);
  return Float32List.fromList([for (var i = 0; i < 1024; i++) r.nextDouble()]);
}();

double _r(int k) => _table[k & 1023];

double _out(double t) {
  final u = 1 - t;
  return 1 - u * u * u;
}

double _ease(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

int _lerpRgb(int a, int b, double t) {
  int ch(int s) {
    final x = (a >> s) & 0xFF, y = (b >> s) & 0xFF;
    return (x + (y - x) * t).round().clamp(0, 255);
  }

  return (ch(16) << 16) | (ch(8) << 8) | ch(0);
}
