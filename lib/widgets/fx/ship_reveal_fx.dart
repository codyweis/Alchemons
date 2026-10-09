// lib/widgets/fx/ship_reveal_fx.dart
//
// The ship's first appearance on home, once it has been claimed in the
// wild: the screen dims round the place it will stand, light gathers there
// out of a ring of motes, and the emblem bursts in on a flash and a
// shockwave (the home shakes with it), overshoots and settles, while a line
// says what it is and what it is for. Then the dark lifts.
//
// It used to be a scale bounce on an emblem that had already popped in,
// played while home was still covered by the routes the player was coming
// back through, so it was mostly over before anyone saw it.
//
// One controller drives it; the veil, the light and the caption are drawn
// over the whole screen (an overlay the host holds), the emblem's own scale
// by the host. No blur anywhere: glows are radial gradients.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The reveal's timeline, as fractions of [duration].
abstract final class ShipReveal {
  static const duration = Duration(milliseconds: 3600);

  /// The dark comes up, and lifts.
  static const veilIn = (0.0, 0.12), veilOut = (0.82, 1.0);

  /// Motes fall into the point the emblem will stand at.
  static const gather = (0.04, 0.30);

  /// The emblem arrives: flash, shockwave, heavy haptic, the home shakes.
  static const impactAt = 0.30;

  /// The caption is up between these.
  static const captionIn = (0.44, 0.54), captionOut = (0.84, 0.94);

  static const _light = Color(0xFFE8F6FF);
  static const _accent = Color(0xFF9FD8FF);

  /// 0..1 across [span] of [t], eased by [curve].
  static double phase(
    double t,
    (double, double) span, [
    Curve curve = Curves.linear,
  ]) {
    final (a, b) = span;
    if (t <= a) return 0;
    if (t >= b) return 1;
    return curve.transform((t - a) / (b - a));
  }

  /// The emblem's scale at [t]: nothing until the impact, then out past
  /// its size and back.
  static double emblemScale(double t) {
    if (t < impactAt) return 0;
    final out = phase(t, (impactAt, impactAt + 0.10), Curves.easeOutCubic);
    if (out < 1) return 1.55 * out;
    return 1.55 - 0.55 * phase(t, (0.40, 0.58), Curves.elasticOut);
  }

  /// How dark the veil is at [t], 0..1.
  static double veil(double t) =>
      phase(t, veilIn, Curves.easeOut) *
      (1 - phase(t, veilOut, Curves.easeInOut));
}

/// Everything of the reveal but the emblem: the veil with its pool of light
/// round [centre], the gathering motes, the flash and rings, and the
/// caption beside it. Put it over the whole screen; it ignores touches.
class ShipRevealOverlay extends StatelessWidget {
  const ShipRevealOverlay({
    super.key,
    required this.progress,
    required this.centre,
  });

  final Animation<double> progress;

  /// Where the emblem stands, in this widget's coordinates. Read every
  /// frame, so it follows the emblem as it lays out.
  final Offset Function() centre;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final t = progress.value;
          final c = centre();
          final caption =
              ShipReveal.phase(t, ShipReveal.captionIn, Curves.easeOut) *
              (1 - ShipReveal.phase(t, ShipReveal.captionOut));
          return LayoutBuilder(
            builder: (context, box) => Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _RevealPainter(t, c)),
                ),
                if (caption > 0)
                  Positioned(
                    // Beside the emblem, on the side with the room: it
                    // stands at the screen's right edge.
                    right: (box.maxWidth - c.dx + 64).clamp(
                      16.0,
                      box.maxWidth - 16,
                    ),
                    top: c.dy - 22,
                    child: Opacity(
                      opacity: caption,
                      child: Transform.translate(
                        offset: Offset(12 * (1 - caption), 0),
                        child: const _Caption(),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'YOUR SHIP',
          style: TextStyle(
            fontFamily: 'monospace',
            color: ShipReveal._light,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Tap it to cross into space.',
          style: TextStyle(
            color: Color(0xCCFFFFFF),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _RevealPainter extends CustomPainter {
  _RevealPainter(this.t, this.c);

  final double t;
  final Offset c;

  static final _motes = [
    for (var i = 0; i < 30; i++)
      (
        angle: i * 2.39996 + (i % 3) * 0.21, // golden angle, a little shaken
        reach: 0.75 + ((i * 37) % 10) / 20, // 0.75..1.2
        size: 1.4 + ((i * 53) % 7) / 6, // 1.4..2.4
        lag: ((i * 29) % 10) / 40, // 0..0.225
      ),
  ];

  final _paint = Paint();

  void _disc(Canvas canvas, Offset at, double r, Color color, double alpha) {
    if (r <= 0 || alpha <= 0) return;
    _paint.shader = ui.Gradient.radial(
      at,
      r,
      [
        color.withValues(alpha: alpha.clamp(0.0, 1.0)),
        color.withValues(alpha: (alpha * 0.35).clamp(0.0, 1.0)),
        color.withValues(alpha: 0),
      ],
      const [0.0, 0.45, 1.0],
    );
    canvas.drawCircle(at, r, _paint);
    _paint.shader = null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // The veil: dark everywhere but a pool round where it stands.
    final veil = ShipReveal.veil(t);
    if (veil > 0) {
      const reach = 300.0;
      _paint.shader = ui.Gradient.radial(
        c,
        reach,
        [
          Colors.black.withValues(alpha: 0),
          Colors.black.withValues(alpha: 0.22 * veil),
          Colors.black.withValues(alpha: 0.66 * veil),
        ],
        const [0.0, 0.28, 1.0],
      );
      canvas.drawRect(Offset.zero & size, _paint);
      _paint.shader = null;
    }

    // The gather: motes fall in from a ring, and the point they fall into
    // brightens.
    final g = ShipReveal.phase(t, ShipReveal.gather);
    if (g > 0 && t < ShipReveal.impactAt + 0.02) {
      for (final m in _motes) {
        final local = ((g - m.lag) / (1 - m.lag)).clamp(0.0, 1.0);
        if (local <= 0) continue;
        final fall = Curves.easeInCubic.transform(local);
        final r = 150 * m.reach * (1 - fall);
        final at = c + Offset(math.cos(m.angle), math.sin(m.angle)) * r;
        final alpha = math.min(1.0, local * 3) * (1 - fall * 0.4);
        _disc(canvas, at, m.size * 3, ShipReveal._accent, alpha);
        _disc(canvas, at, m.size, ShipReveal._light, alpha);
      }
      _disc(canvas, c, 10 + 34 * g, ShipReveal._light, 0.25 + 0.6 * g);
    }

    if (t < ShipReveal.impactAt) return;

    // The flash.
    final flash = 1 - ShipReveal.phase(t, (ShipReveal.impactAt, 0.44));
    if (flash > 0) {
      _disc(canvas, c, 70 + 40 * (1 - flash), Colors.white, 0.95 * flash);
    }

    // Two shockwaves, the second smaller and later.
    for (final (start, end, reach, width) in const [
      (ShipReveal.impactAt, 0.64, 230.0, 7.0),
      (0.36, 0.66, 150.0, 4.0),
    ]) {
      final w = ShipReveal.phase(t, (start, end), Curves.easeOutCubic);
      if (w <= 0 || w >= 1) continue;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * (1 - w) + 0.6
        ..color = ShipReveal._accent.withValues(alpha: 0.85 * (1 - w));
      canvas.drawCircle(c, 24 + reach * w, ring);
    }

    // The light it stands in, fading as the dark lifts.
    final glow =
        ShipReveal.phase(t, (ShipReveal.impactAt, 0.40)) *
        (1 - ShipReveal.phase(t, (0.70, 0.98)));
    _disc(canvas, c, 92, ShipReveal._accent, 0.32 * glow);
  }

  @override
  bool shouldRepaint(_RevealPainter old) => old.t != t || old.c != c;
}
