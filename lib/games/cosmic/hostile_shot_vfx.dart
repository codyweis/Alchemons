// lib/games/cosmic/hostile_shot_vfx.dart
//
// A hostile shot — anything an enemy or boss fires at the player — drawn
// the same in Survival and in open space: a dark-cored bead of the
// element's material, lit hot on its leading face, trailing a wake of its
// light that fades to a point. The party's shots are light all through, so
// the dark core is what makes fire read as hostile.
//
// Budget: two fills per shot (a heavy shot adds a halo), under shaders
// cached per element. No blur.

import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart' show elementColor;
import 'package:alchemons/games/cosmic/vfx_shapes.dart';
import 'package:flutter/painting.dart';

/// A shot's wake at unit size: full width at the bead (x = 1), tapering to
/// a point behind it (x = 0).
final Path _shotWake = Path()
  ..moveTo(0, 0)
  ..quadraticBezierTo(0.6, -0.42, 1, -0.5)
  ..lineTo(1, 0.5)
  ..quadraticBezierTo(0.6, 0.42, 0, 0)
  ..close();
final Paint _shotPaint = Paint();

/// Per element: the wake's fade, the bead's lit glass, and the halo color.
final Map<String, (ui.Shader, ui.Shader, Color)> _shotLooks = {};

/// An enemy's or boss's shot at [p] heading [angle], [radius] across: a
/// bead of the element's material lit hot on its leading face, trailing a
/// wake of its light that fades to a point. Its back is dark glass — the
/// party's shots are light all through — so hostile fire reads as hostile.
void paintHostileShot(
  Canvas c,
  Offset p,
  double angle,
  double radius,
  String element, {
  bool heavy = false,
}) {
  final (wake, bead, halo) = _shotLooks[element] ??= () {
    final m = vfxMaterial(element);
    final glow = Color.lerp(elementColor(element), m.light, 0.3)!;
    return (
      ui.Gradient.linear(Offset.zero, const Offset(1, 0), [
        glow.withValues(alpha: 0),
        glow.withValues(alpha: 0.6),
      ]),
      ui.Gradient.radial(
        const Offset(0.5, 0),
        1.5,
        [Color.lerp(glow, m.glint, 0.7)!, glow, m.ink],
        const [0.0, 0.35, 0.85],
      ),
      glow,
    );
  }();
  c.save();
  c.translate(p.dx, p.dy);
  c.rotate(angle);
  final len = radius * (heavy ? 7 : 5.5);
  c.save();
  c.translate(-len, 0);
  c.scale(len, radius * 2);
  _shotPaint
    ..color = const Color(0xFFFFFFFF)
    ..shader = wake;
  c.drawPath(_shotWake, _shotPaint);
  c.restore();
  c.scale(radius);
  // Only a boss's shot gets a halo: enemy shots run to ninety at once, and
  // two fills apiece keeps a full field cheap.
  if (heavy) {
    _shotPaint
      ..shader = null
      ..color = halo.withValues(alpha: 0.2);
    c.drawCircle(Offset.zero, 1.9, _shotPaint);
  }
  _shotPaint
    ..color = const Color(0xFFFFFFFF)
    ..shader = bead;
  c.drawCircle(Offset.zero, 1, _shotPaint);
  _shotPaint.shader = null;
  c.restore();
}
