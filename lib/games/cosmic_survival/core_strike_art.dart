// lib/games/cosmic_survival/core_strike_art.dart
//
// WHERE THE CORE WAS STRUCK.
//
// A body strikes the core at its glass (cosmic_survival_game.dart,
// _applyEnemyContactDamage), and until now nothing showed on the glass: the
// body burst, the health ring lost a cell, and which side of the core was
// leaking had to be guessed. A strike now runs round the glass from where it
// landed, a wash of the body's own colour in grains going both ways and
// thinning, with a few knocked inward; embers of that colour stay on the
// spot for a couple of seconds after, going out one by one.
//
// No dice (every grain is read off the strike's own seed), no blur, at most
// [CoreStrikes.cap] strikes at once and three point draws for all of them.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

class _Strike {
  double angle = 0;
  double born = -1e9;
  double strength = 1;
  int seed = 0;
  Color tint = const Color(0xFFFFFFFF);
}

double _h(int i, int salt) {
  final x = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

class CoreStrikes {
  /// Strikes shown at once: past this the oldest gives way.
  static const int cap = 18;

  /// How long the wash runs round the glass, and how long a strike shows at
  /// all (the rest is its bruise fading).
  static const double washSeconds = 0.55;
  static const double life = 2.6;

  final List<_Strike> _strikes = List.generate(cap, (_) => _Strike());
  int _next = 0;

  /// Strikes still showing at [time] (for tests and the frame budget).
  int showing(double time) =>
      _strikes.where((s) => time - s.born < life && time >= s.born).length;

  /// A strike on the glass at [angle] round the core (radians, as atan2 of
  /// the body's place from the core's), [strength] 1 for a light body up to
  /// about 3 for a heavy one that bursts.
  void add(double angle, double strength, Color tint, double time) {
    final s = _strikes[_next];
    _next = (_next + 1) % cap;
    s
      ..angle = angle
      ..born = time
      ..strength = strength.clamp(0.6, 3.0)
      ..seed = (angle * 1000).round() ^ (time * 60).round()
      ..tint = tint;
  }

  void clear() {
    for (final s in _strikes) {
      s.born = -1e9;
    }
  }

  static final Float32List _hot = Float32List(cap * 2 * 40);
  static final Float32List _wash = Float32List(cap * 2 * 80);
  static final Float32List _bruise = Float32List(cap * 2 * 30);
  static final Paint _paint = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  /// Draws every live strike round the origin, on a core [radius] across.
  void paint(Canvas canvas, double radius, double time) {
    // One colour for a frame's washes: the newest strike's. Bodies of one
    // wave share an element, so this is nearly always every strike's own.
    Color? tint;
    var newest = -1e9;
    var hotN = 0, washN = 0, bruiseN = 0;
    for (final s in _strikes) {
      final age = time - s.born;
      if (age < 0 || age >= life) continue;
      if (s.born > newest) {
        newest = s.born;
        tint = s.tint;
      }
      final ca = cos(s.angle), sa = sin(s.angle);
      if (age < washSeconds) {
        final t = age / washSeconds;
        // Eased out: it leaves the spot fast and slows as it thins.
        final run = 1 - (1 - t) * (1 - t);
        final reach = (0.34 + 0.16 * s.strength) * run;
        final grains = (22 * s.strength).round();
        for (var i = 0; i < grains; i++) {
          // Fewer survive the further round they have gone.
          final u = _h(i, s.seed);
          if (_h(i, s.seed + 3) < t * 0.75 * u) continue;
          final side = i.isEven ? 1.0 : -1.0;
          final a = s.angle + side * reach * (0.15 + 0.85 * u);
          final r = radius * (0.955 + 0.05 * _h(i, s.seed + 1));
          _wash[washN++] = cos(a) * r;
          _wash[washN++] = sin(a) * r;
        }
        // The heart of it, on the spot, and a few knocked into the glass.
        final hot = (5 + 5 * s.strength * (1 - t)).round();
        for (var i = 0; i < hot; i++) {
          final spread = (_h(i, s.seed + 5) - 0.5) * 0.16;
          final inward = radius * (0.98 - 0.42 * t * _h(i, s.seed + 7));
          final c = cos(s.angle + spread), d = sin(s.angle + spread);
          _hot[hotN++] = c * inward;
          _hot[hotN++] = d * inward;
        }
      } else {
        // What is left: embers of the body's colour where it landed, going
        // out one by one. (Dark grains were tried: the glass's rim is dark.)
        final t = (age - washSeconds) / (life - washSeconds);
        final grains = (11 * s.strength).round();
        for (var i = 0; i < grains; i++) {
          if (_h(i, s.seed + 11) < t) continue;
          final along = (_h(i, s.seed + 13) - 0.5) * 0.22 * s.strength;
          final r = radius * (0.90 + 0.09 * _h(i, s.seed + 17));
          final c = ca * cos(along) - sa * sin(along);
          final d = sa * cos(along) + ca * sin(along);
          _bruise[bruiseN++] = c * r;
          _bruise[bruiseN++] = d * r;
        }
      }
    }
    if (tint == null) return;
    final unit = radius / 72;
    if (bruiseN > 0) {
      canvas.drawRawPoints(
        PointMode.points,
        Float32List.sublistView(_bruise, 0, bruiseN),
        _paint
          ..strokeWidth = 2.0 * unit
          ..color = Color.lerp(
            tint,
            const Color(0xFF07060B),
            0.3,
          )!.withValues(alpha: 0.8),
      );
    }
    if (washN > 0) {
      canvas.drawRawPoints(
        PointMode.points,
        Float32List.sublistView(_wash, 0, washN),
        _paint
          ..strokeWidth = 2.2 * unit
          ..color = Color.lerp(tint, const Color(0xFFFFF6E4), 0.35)!,
      );
    }
    if (hotN > 0) {
      canvas.drawRawPoints(
        PointMode.points,
        Float32List.sublistView(_hot, 0, hotN),
        _paint
          ..strokeWidth = 3.0 * unit
          ..color = const Color(0xFFFFF6E4),
      );
    }
  }
}
