// lib/games/cosmic/hostile_shot_vfx.dart
//
// A hostile shot — anything an enemy or boss fires at the player — drawn
// the same in Survival and in open space, and in the bodies' own material:
// a dark bead with its element's grains lit hot round its leading face and
// one hot point at its nose, shedding a straight wake of grains that
// widens a little and thins to nothing. The party's shots are light all
// through, so the dark core is what makes fire read as hostile; the hot
// nose and the long bright wake are what make it read at all on a phone,
// and tell it from a mote, which churns and trails dim. (Drawn at its hit
// size it was a 2-pixel dark bead with a hair behind it: it is drawn half
// again as large as it hits, with a wake half as long again.)
//
// Every shot in view goes out together: the cores in two point draws, the
// grains in five per element. No blur, no shaders.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:alchemons/games/cosmic/cosmic_data.dart' show elementColor;

const _ink = Color(0xFF07060B);
const _white = Color(0xFFFFF6E4);

class _Buf {
  Float32List d = Float32List(256);
  int n = 0;

  void add(double x, double y) {
    if (n + 2 > d.length) d = Float32List(d.length * 2)..setAll(0, d);
    d[n] = x;
    d[n + 1] = y;
    n += 2;
  }
}

/// One element's grains: 0 the wake's end, 1 the wake, 2 lit, 3 hot, and
/// [nose], the one hot point each shot leads with.
class _Look {
  _Look(Color c)
    : tone = [
        Color.lerp(c, _ink, 0.45)!.withValues(alpha: 0.6),
        c,
        Color.lerp(c, _white, 0.4)!,
        Color.lerp(c, _white, 0.8)!,
      ];

  final List<Color> tone;
  final List<_Buf> pts = List.generate(4, (_) => _Buf());
  final _Buf nose = _Buf();
  bool used = false;
}

/// Collects the hostile shots in view and draws them in a handful of calls.
class HostileShotBatch {
  final Map<String, _Look> _looks = {};
  final List<_Look> _order = [];
  // The dark cores: an enemy's and a boss's, each drawn at its own size.
  final _Buf _cores = _Buf(), _heavyCores = _Buf();
  double _coreR = 0, _heavyCoreR = 0;

  static final Paint _pt = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  // Where the wake's grains sit across it, so it is a strand of sand and
  // not a ruled line.
  static const _side = [0.0, 0.5, -0.35, 0.2, -0.6, 0.4, -0.15, 0.55, -0.45];

  /// How much larger than its hit radius a shot is drawn.
  static const double drawnScale = 1.5;

  /// Adds a shot at [p] heading [angle], [radius] across. [heavy] is a
  /// boss's: larger, with a longer wake and a full ring of grains.
  void add(
    Offset p,
    double angle,
    double hitRadius,
    String element,
    double time, {
    bool heavy = false,
  }) {
    // Drawn larger than it hits: its hit size is a few units, a pixel or
    // two across at the flying zoom.
    final radius = hitRadius * drawnScale;
    final look = _looks[element] ??= _Look(elementColor(element));
    if (!look.used) {
      look.used = true;
      _order.add(look);
    }
    final hc = cos(angle), hs = sin(angle);
    if (heavy) {
      _heavyCores.add(p.dx, p.dy);
      _heavyCoreR = max(_heavyCoreR, radius);
    } else {
      _cores.add(p.dx, p.dy);
      _coreR = max(_coreR, radius);
    }
    // The grains round the bead: hot on the face it leads with, its colour
    // behind.
    final ring = heavy ? 14 : 9;
    for (var i = 0; i < ring; i++) {
      // Measured from dead ahead: an enemy's shot wears them on its
      // leading face only, a boss's all the way round.
      final a =
          ((i + 0.5) / ring - 0.5) * (heavy ? 2 * pi : 3.6) +
          0.2 * sin(time * 6 + i * 1.7);
      final lead = cos(a);
      final x = radius * 0.8 * lead, y = radius * 0.8 * sin(a);
      look.pts[lead > 0.55 ? 3 : (lead > -0.1 ? 2 : 1)].add(
        p.dx + hc * x - hs * y,
        p.dy + hs * x + hc * y,
      );
    }
    look.nose.add(p.dx + hc * radius * 0.7, p.dy + hs * radius * 0.7);
    // The wake: grains shed straight back, running down it, spreading a
    // little and thinning.
    final n = heavy ? 18 : 13;
    final len = radius * (heavy ? 7.5 : 6);
    for (var i = 0; i < n; i++) {
      final s = (i / n + time * 2.6) % 1.0;
      final back = radius * 0.9 + len * s;
      final w = radius * _side[i % _side.length] * (0.55 + 0.6 * s);
      look.pts[s < 0.3 ? 2 : (s < 0.72 ? 1 : 0)].add(
        p.dx - hc * back - hs * w,
        p.dy - hs * back + hc * w,
      );
    }
  }

  /// Draws everything added since the last flush. [grain] is a grain's
  /// diameter in world units.
  void flush(Canvas canvas, {double grain = 2.4}) {
    void cores(_Buf b, double r) {
      if (b.n == 0) return;
      canvas.drawRawPoints(
        PointMode.points,
        Float32List.sublistView(b.d, 0, b.n),
        _pt
          ..strokeWidth = r * drawnScale * 1.05
          ..color = _ink,
      );
      b.n = 0;
    }

    cores(_cores, _coreR);
    cores(_heavyCores, _heavyCoreR);
    _coreR = 0;
    _heavyCoreR = 0;
    for (final look in _order) {
      look.used = false;
      for (var t = 0; t < 4; t++) {
        final b = look.pts[t];
        if (b.n == 0) continue;
        canvas.drawRawPoints(
          PointMode.points,
          Float32List.sublistView(b.d, 0, b.n),
          _pt
            ..strokeWidth = t == 0 ? grain * 0.8 : (t == 3 ? grain * 1.25 : grain)
            ..color = look.tone[t],
        );
        b.n = 0;
      }
      if (look.nose.n > 0) {
        canvas.drawRawPoints(
          PointMode.points,
          Float32List.sublistView(look.nose.d, 0, look.nose.n),
          _pt
            ..strokeWidth = grain * 2.1
            ..color = look.tone[3],
        );
        look.nose.n = 0;
      }
    }
    _order.clear();
  }
}
