// The portal tear a rammed wild Alchemon opens, drawn in two halves that
// must read as one shape:
//
//  * in space — [paintSpaceTearBehind] opens a white-hot slit *behind* the
//    creature (so it hangs silhouetted in the light), then
//    [paintSpaceTearOver] opens darkness inside the slit until it has
//    swallowed the screen;
//  * in the encounter — [paintTearReveal] runs the same lens the other way:
//    a slit in the dark whose middle opens onto the new scene.
//
// Filled lenses and gradient light only — no stroked rims (see the VFX
// material rules) and no blur, since all of it runs every frame.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const _tearVoid = Color(0xFF040509);
const _tearHot = Color(0xFFFFF4DC);

/// A vertical lens [lh] tall whose widest point is [lw] / 2 each side.
Path _lens(Offset c, double lw, double lh) => Path()
  ..moveTo(c.dx, c.dy - lh / 2)
  ..quadraticBezierTo(c.dx + lw, c.dy, c.dx, c.dy + lh / 2)
  ..quadraticBezierTo(c.dx - lw, c.dy, c.dx, c.dy - lh / 2)
  ..close();

/// [shape] with [hole] (which lies inside it) left open.
Path _cut(Path shape, Path? hole) => hole == null
    ? shape
    : (Path()
        ..fillType = PathFillType.evenOdd
        ..addPath(shape, Offset.zero)
        ..addPath(hole, Offset.zero));

/// A radial gradient squeezed to the lens's own proportions, so light falls
/// off evenly toward its edge instead of in a circle.
Shader _lensShader(
  Offset c,
  double lw,
  double lh,
  List<Color> colors,
  List<double> stops,
) {
  final ry = max(1.0, lh / 2);
  final sx = max(0.01, (lw / 2) / ry);
  final m = Matrix4.identity()
    ..translateByDouble(c.dx, c.dy, 0, 1)
    ..scaleByDouble(sx, 1, 1, 1)
    ..translateByDouble(-c.dx, -c.dy, 0, 1);
  return ui.Gradient.radial(c, ry, colors, stops, TileMode.clamp, m.storage);
}

/// The soft light around a tear of the given size.
void _paintGlow(
  Canvas canvas,
  Offset c,
  double w,
  double h,
  Color color,
  double a, {
  Path? hole,
}) {
  if (a <= 0 || h <= 0) return;
  final gw = w * 2.6 + 40;
  final gh = h * 1.22 + 40;
  canvas.drawPath(
    _cut(_lens(c, gw, gh), hole),
    Paint()
      ..shader = _lensShader(
        c,
        gw,
        gh,
        [
          color.withValues(alpha: 0.75 * a),
          color.withValues(alpha: 0.30 * a),
          color.withValues(alpha: 0),
        ],
        const [0.0, 0.45, 1.0],
      ),
  );
}

/// The burning slit itself: white at the heart, the element's colour at the
/// edge.
void _paintHot(
  Canvas canvas,
  Offset c,
  double w,
  double h,
  Color color,
  double a, {
  Path? hole,
}) {
  if (a <= 0 || h <= 0) return;
  canvas.drawPath(
    _cut(_lens(c, w, h), hole),
    Paint()
      ..shader = _lensShader(
        c,
        w,
        h,
        [
          _tearHot.withValues(alpha: a),
          Color.lerp(_tearHot, color, 0.45)!.withValues(alpha: a),
          color.withValues(alpha: 0.85 * a),
        ],
        const [0.0, 0.62, 1.0],
      ),
  );
}

// ── in space ────────────────────────────────────────────────────────────────

double _slitOpen(double q) =>
    Curves.easeOutCubic.transform((q / 0.5).clamp(0.0, 1.0));
double _swallow(double q) =>
    Curves.easeInCubic.transform(((q - 0.45) / 0.55).clamp(0.0, 1.0));

/// Drawn in screen space *before* the creature: the dimming, the light
/// streaming in, and the slit it hangs in front of. [q] runs 0→1 as the tear
/// opens; played backwards it closes. [clock] drives the streaming light.
void paintSpaceTearBehind(
  Canvas canvas, {
  required Size screen,
  required Offset centre,
  required double q,
  required Color color,
  required double clock,
}) {
  final c = centre;
  final longest = screen.longestSide;
  final s1 = _slitOpen(q);
  if (s1 <= 0) return;
  final slitH = screen.height * 0.34 * s1;
  final slitW = slitH * 0.11;

  // The rest of space dims toward the edges, pulling the eye in.
  canvas.drawRect(
    Offset.zero & screen,
    Paint()
      ..shader = ui.Gradient.radial(c, longest * 0.75, [
        _tearVoid.withValues(alpha: 0),
        _tearVoid.withValues(alpha: 0.6 * s1),
      ]),
  );

  // Loose light streaming into the tear — tapered filled streaks.
  final pull = s1 * (1 - _swallow(q));
  if (pull > 0.01) {
    final streak = Paint()..color = color.withValues(alpha: 0.75 * pull);
    final reach = screen.shortestSide * 0.7;
    for (var i = 0; i < 26; i++) {
      final angle = i * 2.39996 + 0.3;
      final phase = (clock * (0.9 + (i % 5) * 0.18) + i * 0.137) % 1.0;
      final r = reach * (1 - phase) + slitW;
      final dir = Offset(cos(angle), sin(angle));
      final tip = c + dir * r;
      final tail = c + dir * (r + 10 + 26 * phase);
      final side = Offset(-dir.dy, dir.dx) * (1.2 + 1.6 * phase);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tail.dx + side.dx, tail.dy + side.dy)
          ..lineTo(tail.dx - side.dx, tail.dy - side.dy)
          ..close(),
        streak,
      );
    }
  }

  _paintGlow(canvas, c, slitW, slitH, color, s1);
  _paintHot(canvas, c, slitW, slitH, color, s1);
}

/// Drawn in screen space *over* everything: darkness opening inside the
/// slit and widening, with a burning rim, until the screen is gone.
void paintSpaceTearOver(
  Canvas canvas, {
  required Size screen,
  required Offset centre,
  required double q,
  required Color color,
}) {
  final s2 = _swallow(q);
  if (s2 <= 0) return;
  final c = centre;
  final longest = screen.longestSide;
  final slitH = screen.height * 0.34 * _slitOpen(q);
  final slitW = slitH * 0.11;

  // The hole starts as a sliver inside the slit and outgrows the screen.
  final start = (s2 * 5).clamp(0.0, 1.0);
  final holeW = slitW * 0.7 * start + longest * 2.0 * s2;
  final holeH = slitH * 0.95 * start + longest * 2.8 * s2;
  final rimW = max(slitW, holeW * 1.18 + 8);
  final rimH = max(slitH, holeH * 1.06 + 8);

  _paintGlow(canvas, c, rimW, rimH, color, 1 - s2 * 0.5);
  _paintHot(canvas, c, rimW, rimH, color, 1.0);
  canvas.drawPath(_lens(c, holeW, holeH), Paint()..color = _tearVoid);

  // Seal the last frames so the hand-off is truly dark.
  if (q > 0.9) {
    canvas.drawRect(
      Offset.zero & screen,
      Paint()
        ..color = _tearVoid.withValues(
          alpha: ((q - 0.9) / 0.1).clamp(0.0, 1.0),
        ),
    );
  }
}

// ── in the encounter ────────────────────────────────────────────────────────

/// The far side: held dark while the phone turns, then the same slit opens
/// in the dark and its middle opens onto the scene. [progress] is the
/// encounter's arrival timeline (see WildSpaceEncounterScreen).
void paintTearReveal(
  Canvas canvas,
  Size size, {
  required double progress,
  required Color color,
}) {
  final screen = Offset.zero & size;
  final t = ((progress - 0.17) / 0.45).clamp(0.0, 1.0);
  if (t <= 0) {
    canvas.drawRect(screen, Paint()..color = _tearVoid);
    return;
  }
  final c = size.center(Offset.zero);
  final longest = size.longestSide;
  final slit = Curves.easeOutCubic.transform((t / 0.3).clamp(0.0, 1.0));
  final open = Curves.easeInCubic.transform(
    ((t - 0.22) / 0.78).clamp(0.0, 1.0),
  );
  final slitH = size.height * 0.62 * slit;
  final slitW = slitH * 0.11;

  final start = (open * 5).clamp(0.0, 1.0);
  final holeW = slitW * 0.7 * start + longest * 2.0 * open;
  final holeH = slitH * 0.95 * start + longest * 2.8 * open;
  final rimW = max(slitW, holeW * 1.18 + 8);
  final rimH = max(slitH, holeH * 1.06 + 8);

  // Once fully open, the burning rim lingers a moment beyond the frame.
  final edge = progress < 0.62
      ? 1.0
      : (1 - (progress - 0.62) / 0.13).clamp(0.0, 1.0);
  if (edge <= 0) return;

  // Everything is drawn around the hole, never over it: the scene shows
  // through the middle.
  final hole = holeH > 0 ? _lens(c, holeW, holeH) : null;
  if (open < 1) {
    canvas.drawPath(
      _cut(Path()..addRect(screen), hole),
      Paint()..color = _tearVoid,
    );
  }
  _paintGlow(canvas, c, rimW, rimH, color, edge * (1 - open * 0.5), hole: hole);
  _paintHot(canvas, c, rimW, rimH, color, edge, hole: hole);
}

// ── summoning ──────────────────────────────────────────────────────────────

/// A companion called into space steps out of a small tear of its element:
/// the slit opens behind it, holds while it emerges, and seals. [t] runs 0→1
/// over the summon (and is played 0→1 again as it is drawn back in).
void paintSummonTear(
  Canvas canvas, {
  required Offset centre,
  required double height,
  required double t,
  required Color color,
}) {
  final open = Curves.easeOutCubic.transform((t / 0.35).clamp(0.0, 1.0));
  final close = Curves.easeInCubic.transform(((t - 0.6) / 0.4).clamp(0.0, 1.0));
  final env = open * (1 - close);
  if (env <= 0.01) return;
  final h = height * (0.35 + 0.65 * open) * (1 - 0.6 * close);
  final w = h * 0.13 * env;
  _paintGlow(canvas, centre, w, h, color, env);
  _paintHot(canvas, centre, w, h, color, env);
}
