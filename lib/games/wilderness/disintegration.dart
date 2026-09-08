import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart';

/// A specimen coming apart into motes, shared by every place in the wild that
/// takes one out of the world.
///
/// This is the Flame-side twin of the nursery's `_DisintegrationPainter`, and
/// it deliberately matches it beat for beat: the wild fusion and the breeding
/// chamber are the same event happening in two different renderers, and they
/// looked like two unrelated effects when each grew its own particles.
///
/// Everything is seeded off the mote index rather than a random source, so the
/// cloud holds still frame to frame instead of boiling — per-frame randomness
/// reads as television static, not as pieces of one body.
class Disintegration {
  const Disintegration._();

  /// Golden angle: spreads the motes without them landing on visible spokes.
  static const _goldenAngle = 2.39996;

  /// Reused across every call and every frame. These effects run inside a
  /// game loop, where allocating a Paint per mote per frame is real garbage.
  static final Paint _halo = Paint();
  static final Paint _core = Paint();

  /// Draws the cloud centred on [centre], sized against [unit] (use the
  /// creature's cage or half-extent).
  ///
  /// [breakUp] drives the release, [gather] pulls the cloud back together as
  /// it is carried somewhere, so it arrives as one thing rather than as a
  /// scattering that never resolves.
  static void paint(
    Canvas canvas, {
    required Offset centre,
    required double unit,
    required double breakUp,
    required Color color,
    double gather = 0,
    int count = 46,
  }) {
    if (breakUp <= 0 || unit <= 0) return;

    final gatherK = 1.0 - 0.55 * Curves.easeInCubic.transform(gather);
    final bright = Color.lerp(color, const Color(0xFFFFFFFF), 0.45)!;

    for (var i = 0; i < count; i++) {
      // Staggered release, so the body flakes apart progressively instead of
      // detonating all at once on a single frame.
      final stagger = (i % 9) / 9.0 * 0.42;
      final p = ((breakUp - stagger) / (1.0 - stagger)).clamp(0.0, 1.0);
      if (p <= 0) continue;

      final ang = (i * _goldenAngle) % (math.pi * 2);
      final dx = math.cos(ang);
      final dy = math.sin(ang);

      // Start spread inside the silhouette, not all from a single point.
      final inner = unit * (0.04 + ((i * 17) % 10) / 10.0 * 0.20);
      final reach = unit * (0.14 + ((i * 29) % 10) / 10.0 * 0.34);
      final out = Curves.easeOutCubic.transform(p);
      final r = (inner + reach * out) * gatherK;

      // A slight lift, so it reads as matter coming off rather than debris.
      final pos = Offset(
        centre.dx + dx * r,
        centre.dy + dy * r - unit * 0.14 * out,
      );

      // In fast on release, then thinning as the mote spends itself.
      final appear = (p / 0.18).clamp(0.0, 1.0);
      final alpha = (appear * (1.0 - 0.75 * p)).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;

      // A few larger fragments among the dust reads as a body coming apart;
      // an even spray just reads as sparkle.
      final chunk = (i % 11 == 0) ? 2.1 : 1.0;
      final rad = (0.9 + 1.9 * (1.0 - out)) * chunk;

      canvas.drawCircle(
        pos,
        rad * 2.0,
        _halo..color = color.withValues(alpha: alpha * 0.20),
      );
      canvas.drawCircle(pos, rad, _core..color = bright.withValues(alpha: alpha));
    }
  }
}
