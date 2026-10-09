import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Where an achievement stands, as its sphere shows it.
enum AchievementSphereState {
  /// A story beat not reached yet: dark glass with nothing in it.
  hidden,

  /// Under way: grains still drifting in, more of them gathered the further
  /// along it is.
  underway,

  /// Done and waiting to be collected: formed, with gold rising inside it.
  ready,

  /// Collected: formed and quiet.
  sealed,
}

/// An achievement drawn as grain glass: the sphere forms as it is worked
/// towards, glows gold while its reward waits, and dims once collected.
///
/// Every sphere with something in it turns, on the shared [GlyphClock] (one
/// ticker for all of them). [animate] off holds one still on the frame the
/// clock last showed — the home bar does that when nothing is waiting. The
/// change from ready to sealed eases over [settle] rather than switching.
class AchievementSphere extends StatelessWidget {
  const AchievementSphere({
    super.key,
    required this.size,
    required this.tone,
    required this.state,
    this.progress = 0,
    this.seed = 0,
    this.gold = const Color(0xFFE4C16A),
    this.settle = const Duration(milliseconds: 900),
    this.animate = true,
  });

  final double size;
  final Color tone;
  final AchievementSphereState state;

  /// 0..1 of the way there, for [AchievementSphereState.underway].
  final double progress;

  /// Turns each sphere to its own angle, so a wall of them is not one
  /// sphere repeated.
  final int seed;

  /// The light that rises inside a ready sphere.
  final Color gold;

  final Duration settle;

  /// Whether it turns. A hidden sphere never does: there is nothing in it.
  final bool animate;

  /// A stable seed from an id.
  static int seedFor(String id) =>
      id.codeUnits.fold(0, (v, c) => (v * 31 + c) % 997);

  @override
  Widget build(BuildContext context) {
    final sealed = state == AchievementSphereState.sealed ? 1.0 : 0.0;
    return TweenAnimationBuilder<double>(
      // begin == end: a sphere built sealed starts sealed; only a change
      // after that eases.
      tween: Tween(begin: sealed, end: sealed),
      duration: settle,
      curve: Curves.easeInOutCubic,
      builder: (context, seal, _) {
        return GrainGlyph(
          size: size,
          animate: animate && state != AchievementSphereState.hidden,
          painter: (clock) => _SpherePainter(
            clock: clock,
            tone: tone,
            state: state,
            progress: progress,
            seal: seal,
            seed: seed,
            gold: gold,
          ),
        );
      },
    );
  }
}

class _SpherePainter extends CustomPainter {
  _SpherePainter({
    required this.clock,
    required this.tone,
    required this.state,
    required this.progress,
    required this.seal,
    required this.seed,
    required this.gold,
  }) : super(repaint: clock);

  final ValueListenable<double>? clock;
  final Color tone;
  final AchievementSphereState state;
  final double progress;
  final double seal;
  final int seed;
  final Color gold;

  static const _empty = Color(0xFF5A5852);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final c = size.center(Offset.zero);
    final r = s * 0.32;
    // At rest, the clock's last reading: a sphere that stops running holds
    // the frame it stopped on instead of jumping back to some fixed angle.
    final t =
        (clock?.value ?? GlyphClock.instance.seconds.value) + seed * 0.137;
    switch (state) {
      case AchievementSphereState.hidden:
        GrainGlass.sphere(
          canvas,
          c,
          r,
          t,
          a: _empty,
          gather: 0.03,
          glow: 0.2,
          fade: 0.8,
          salt: seed,
        );
      case AchievementSphereState.underway:
        GrainGlass.sphere(
          canvas,
          c,
          r,
          t,
          a: tone,
          gather: 0.12 + 0.72 * progress.clamp(0.0, 1.0),
          glow: 0.6,
          salt: seed,
        );
      case AchievementSphereState.ready:
      case AchievementSphereState.sealed:
        GrainGlass.sphere(
          canvas,
          c,
          r,
          t,
          a: tone,
          heat: 0.85 * (1 - seal),
          heatColor: gold,
          fade: 1 - 0.5 * seal,
          glow: 1 - 0.65 * seal,
          salt: seed,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _SpherePainter old) =>
      old.tone != tone ||
      old.state != state ||
      old.progress != progress ||
      old.seal != seal ||
      old.seed != seed ||
      old.gold != gold;
}
