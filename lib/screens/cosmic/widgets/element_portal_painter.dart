// lib/screens/cosmic/widgets/element_portal_painter.dart
//
// The four gateways offered at the cosmic prologue's crossing.
//
// Performance notes, because these run four-up at 60fps:
//   • No MaskFilter.blur anywhere. Every glow is a radial gradient shader,
//     which the raster cache handles far better than a per-frame blur.
//   • The accretion disc is three continuous logarithmic-spiral paths rather
//     than a pile of drawArc calls — richer to look at and fewer draw calls.
//   • `t` must be a MONOTONIC clock. Anything that wraps (a repeating 0→1
//     controller) makes every rotation below snap backwards once per cycle.

import 'dart:math';

import 'package:flutter/material.dart';

/// A gateway torn open in space: an accretion disc winding inward, a dark
/// event horizon with a doppler-bright rim, and matter falling in along the
/// disc plane.
///
/// [open] runs 0 → 1 as the portal tears itself open — the disc spins down from
/// a blur, the horizon widens, and the rim settles.
class ElementPortalPainter extends CustomPainter {
  const ElementPortalPainter({
    required this.color,
    required this.t,
    required this.open,
  });

  final Color color;
  final double t;
  final double open;

  /// Vertical squash of the disc — we are looking at it slightly edge-on.
  static const double _tilt = 0.86;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.27 * open;
    if (r <= 0.5) return;

    // Muddy element colours (Earth, Mud) vanish against near-black, so every
    // portal is lifted toward white a touch before it is drawn.
    final tint = Color.lerp(color, Colors.white, 0.22)!;
    final hot = Color.lerp(tint, Colors.white, 0.55)!;

    final breathe = 0.94 + 0.06 * sin(t * 1.1);
    // Fast while tearing open, settling into a lazy turn.
    final spin = t * (0.55 + (1 - open) * 7.0);

    _glow(canvas, c, r * 2.35 * breathe, tint, 0.22 * open);
    _disc(canvas, c, r, tint, spin, breathe, open);
    _horizon(canvas, c, r * breathe, tint, hot, spin, open);
    _infall(canvas, c, r, tint, spin, open);
  }

  /// Radial-gradient halo. Cheaper than a blur and it scales cleanly.
  void _glow(Canvas canvas, Offset c, double radius, Color tint, double alpha) {
    final rect = Rect.fromCircle(center: c, radius: radius);
    canvas.drawOval(
      Rect.fromCenter(
        center: c,
        width: radius * 2,
        height: radius * 2 * _tilt,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            tint.withValues(alpha: alpha),
            tint.withValues(alpha: alpha * 0.45),
            tint.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );
  }

  /// Three logarithmic spirals winding into the horizon, each turning at its
  /// own rate so the disc shears the way a real one would.
  ///
  /// Each arm is stroked with a SweepGradient keyed to its own angular span, so
  /// it fades up out of nothing and fades back into nothing at the tail. A flat
  /// alpha here reads as a hard line switching on — which is exactly what it
  /// looked like before.
  void _disc(
    Canvas canvas,
    Offset c,
    double r,
    Color tint,
    double spin,
    double breathe,
    double open,
  ) {
    const arms = 3;
    const steps = 30;
    const span = 3.4;

    for (var arm = 0; arm < arms; arm++) {
      final path = Path();
      final phase = arm * (pi * 2 / arms) + spin * 0.9;

      for (var i = 0; i <= steps; i++) {
        final f = i / steps;
        final a = phase + f * span;
        final rr = r * (1.72 - f * 0.74) * breathe;
        final pt = Offset(c.dx + cos(a) * rr, c.dy + sin(a) * rr * _tilt);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }

      // Doppler: the arm sweeping toward the viewer runs brighter.
      final facing = 0.5 + 0.5 * sin(phase);
      final peak = (0.14 + facing * 0.30) * open;
      final rect = Rect.fromCircle(center: c, radius: r * 1.8);

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 + facing * 1.9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = SweepGradient(
            // startAngle/endAngle describe the ramp in the gradient's own
            // frame; GradientRotation then puts that frame on the arm. Setting
            // both to `phase` would rotate it twice and slide the ramp off the
            // path entirely.
            startAngle: 0,
            endAngle: span,
            tileMode: TileMode.decal,
            colors: [
              tint.withValues(alpha: 0),
              tint.withValues(alpha: peak),
              tint.withValues(alpha: peak * 0.75),
              tint.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.30, 0.62, 1.0],
            transform: GradientRotation(phase),
          ).createShader(rect),
      );
    }
  }

  /// Dark core, hot rim, and rings falling down the throat.
  void _horizon(
    Canvas canvas,
    Offset c,
    double r,
    Color tint,
    Color hot,
    double spin,
    double open,
  ) {
    // Core, with a faint inner gradient so it is not a flat black hole.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            tint.withValues(alpha: 0.16 * open),
            const Color(0xFF04030B),
            const Color(0xFF04030B),
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Rings falling inward.
    for (var i = 0; i < 3; i++) {
      final f = ((t * 0.5 + i * 0.3333) % 1.0);
      // sin envelope: a ring that blinks out at full alpha reads as a pop.
      canvas.drawCircle(
        c,
        r * (1 - f) * 0.92,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = tint.withValues(alpha: 0.32 * sin(f * pi) * open),
      );
    }

    // Rim: a full cool ring plus a hot arc that travels around it.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = tint.withValues(alpha: 0.42 * open),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      spin * 0.5,
      pi * 0.75,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = hot.withValues(alpha: 0.62 * open),
    );
  }

  /// Matter falling in, each mote dragging a short tail along its own arc.
  void _infall(
    Canvas canvas,
    Offset c,
    double r,
    Color tint,
    double spin,
    double open,
  ) {
    final tail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 9; i++) {
      final f = ((t * 0.42 + i * 0.1111) % 1.0);
      final a = spin * 1.3 + i * (pi * 2 / 9) + f * 2.6;
      final rr = r * (1.9 - f * 1.0);
      final p = Offset(c.dx + cos(a) * rr, c.dy + sin(a) * rr * _tilt);

      final a2 = a - 0.22;
      final rr2 = rr + r * 0.10;
      final env = sin(f * pi);
      tail.color = tint.withValues(alpha: 0.26 * env * open);
      canvas.drawLine(
        Offset(c.dx + cos(a2) * rr2, c.dy + sin(a2) * rr2 * _tilt),
        p,
        tail,
      );

      canvas.drawCircle(
        p,
        1.3 + (1 - f) * 1.5,
        Paint()..color = tint.withValues(alpha: 0.7 * env * open),
      );
    }
  }

  @override
  bool shouldRepaint(ElementPortalPainter old) =>
      old.t != t || old.open != open || old.color != color;
}
