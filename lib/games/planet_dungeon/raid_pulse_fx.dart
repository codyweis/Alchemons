import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;

/// The raid guardian's squad hit, in grains.
///
/// The beats, in seconds:
///  * 0.0 – 1.5  GATHER. Grains drift in from round the guardian on slow
///               easing spirals, staggered, and pack into its body. They
///               brighten as they arrive. This is the telegraph.
///  * 1.5 – 2.5  WASH. The hit lands; the same grains run back out through
///               the whole arena as a soft widening band, still turning the
///               way they came in, and go out as they travel.
///
/// Plain Dart driven by time alone: the dungeon ticks [t] and paints it, and
/// a test can scrub it. At most ~420 round points in one batch, no blur (the
/// halo is the same points drawn wide and faint).
class RaidPulseFx {
  RaidPulseFx({required this.color});

  /// The guardian's element color.
  final Color color;

  static const double telegraph = 1.5;
  static const double wash = 1.0;
  static const double duration = telegraph + wash;

  /// How far the wash runs: past the corners of the raid arena (1400 × 900)
  /// from the guardian's perch.
  static const double reach = 860;

  static const int _grains = 140;
  static const double _swirl = 1.4;
  static const int _bands = 4;

  double t = 0;

  /// Where the hit landed. Null while gathering: the grains follow the
  /// guardian in, then run out from the spot it struck from.
  Offset? washFrom;

  bool get gathering => washFrom == null;
  bool get done => t >= duration;

  // Buckets: [0, _bands) the element color by alpha band, then the same
  // bands in the brightened color for grains packed into the body.
  final GrainBatch _batch = GrainBatch(_bands * 2);

  static double _hash(int i, int k) {
    final x = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// Where grain [i] sits once packed into the guardian's body.
  static double _packedRadius(int i) => 14 + 34 * _hash(i, 3);

  static double _easeInOut(double x) =>
      x < 0.5 ? 2 * x * x : 1 - math.pow(-2 * x + 2, 2) / 2;

  void _add(Offset at, double angle, double r, double alpha, bool bright) {
    if (alpha <= 0.02) return;
    final band = (alpha * _bands).ceil().clamp(1, _bands) - 1;
    _batch.add(
      band + (bright ? _bands : 0),
      at.dx + math.cos(angle) * r,
      at.dy + math.sin(angle) * r,
    );
  }

  /// Paints at [guardian] (where it stands now) while gathering, and from
  /// [washFrom] once the hit has landed.
  void paint(Canvas canvas, Offset guardian) {
    _batch.clear();
    final from = washFrom;
    if (from == null) {
      // GATHER: in from a loose ring round it, packing into the body.
      final p = (t / telegraph).clamp(0.0, 1.0);
      for (var i = 0; i < _grains; i++) {
        final delay = 0.45 * _hash(i, 0);
        final local = ((p - delay) / (1 - delay)).clamp(0.0, 1.0);
        if (local <= 0) continue;
        final e = _easeInOut(local);
        final r0 = 180 + 160 * _hash(i, 1);
        final rEnd = _packedRadius(i);
        final r = rEnd + (r0 - rEnd) * (1 - e);
        final angle = i * 2.39996 + _swirl * e + 0.6 * p;
        final alpha = (local * 4).clamp(0.0, 1.0) * (0.45 + 0.55 * e);
        _add(guardian, angle, r, alpha, e > 0.8);
      }
    } else {
      // WASH: back out as a soft, thick band that widens and goes out.
      final q = ((t - telegraph) / wash).clamp(0.0, 1.0);
      final eq = 1 - math.pow(1 - q, 3).toDouble();
      final fade = math.pow(1 - q, 1.5).toDouble() * 0.9;
      for (var i = 0; i < _grains; i++) {
        // Each grain leaves from where it packed into the body, so the
        // sphere swells straight out of itself rather than snapping to a
        // ring.
        final rEnd = _packedRadius(i);
        final angle = i * 2.39996 + _swirl + 0.6 + 0.3 * eq;
        for (var k = 0; k < 3; k++) {
          final depth = 0.5 + 0.5 * _hash(i, 4 + k);
          final r = rEnd + reach * eq * depth;
          final spin = angle + 0.05 * (k - 1);
          _add(from, spin, r, fade * (0.45 + 0.55 * depth), q < 0.12);
        }
      }
    }
    final bright = Color.lerp(color, const Color(0xFFFFFFFF), 0.45)!;
    // A soft halo first, the same grains drawn wide and faint (no blur),
    // then the grains themselves.
    for (var b = 0; b < _bands; b++) {
      final a = (b + 1) / _bands;
      _batch.draw(canvas, b, 7.5, color.withValues(alpha: 0.06 * a));
      _batch.draw(canvas, b + _bands, 9.0, bright.withValues(alpha: 0.08 * a));
    }
    for (var b = 0; b < _bands; b++) {
      final a = (b + 1) / _bands;
      _batch.draw(canvas, b, 2.4, color.withValues(alpha: a));
      _batch.draw(canvas, b + _bands, 3.0, bright.withValues(alpha: a));
    }
  }
}
