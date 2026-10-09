// lib/screens/cosmic/widgets/planet_descent_passage.dart
//
// The way down into a planet's dungeon (and a raid), and back up. It
// replaced a stock page push and the dungeon's own glyph-portal intro.
//
//   down   the camera falls toward the planet where it hangs in space: it
//          swells from its place to fill the screen, faster as it nears,
//          while the ship — in grains — dives on ahead of the camera and
//          vanishes into it. Inside, the screen is the planet's own air
//          rushing past in its colors, the dungeon's name quiet in the
//          middle, for as long as the dungeon takes to build
//   land   the rush slows and thins, and the dungeon comes up under it
//   up     the rush runs the other way, out of the planet; it shrinks back
//          to its place, and the ship flies up out of it onto the real one
//
// The planet is the planet's own art (games/cosmic/planets), painted where
// the camera left it, so the first frame and the last are the space view.
// Points in batches, gradients for light; no blur, no strokes.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/planets/planet_art.dart';
import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:alchemons/navigation/emblem_passage.dart';
import 'package:alchemons/widgets/cosmic_ship_emblem.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:flutter/material.dart';

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

double _smooth(double e0, double e1, double x) {
  final t = _clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
}

double _ease(double x) {
  final t = _clamp01(x);
  return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
}

double _lerpAngle(double a, double b, double t) {
  var d = (b - a) % (math.pi * 2);
  if (d > math.pi) d -= math.pi * 2;
  if (d < -math.pi) d += math.pi * 2;
  return a + d * t;
}

double _h(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

/// The dark round a planet once the camera is inside its air.
const Color _kSpace = Color(0xFF020010);

class PlanetDescentPassage extends PassageScene {
  PlanetDescentPassage({
    required this.art,
    required this.color,
    required this.planet,
    required this.ship,
    required this.skin,
    required this.planetTime,
    this.title = '',
  });

  /// The planet's own art, and its color (its air is that color).
  final PlanetArt art;
  final Color color;

  /// Where the planet hangs on the screen (global coordinates) and how big:
  /// a circle's bounds.
  final Rect planet;

  /// Where the ship stands on the screen, as the space view draws it.
  final ShipPose ship;
  final String? skin;

  /// The planet's own clock where space stopped, so it is drawn at the very
  /// moment space shows it.
  final double planetTime;

  /// The dungeon's name, quiet in the middle while it is built.
  final String title;

  @override
  Duration get inward => const Duration(milliseconds: 1250);

  @override
  Duration get outward => const Duration(milliseconds: 1250);

  @override
  Duration get landing => const Duration(milliseconds: 950);

  /// The dungeon comes up as the rush thins.
  @override
  double pageShown(double land) => _smooth(0.12, 0.85, land);

  /// Going back, the dungeon clears quickly; the climb out has the rest.
  @override
  double get backSplit => 0.7;

  double? _firstTime;
  double? _last;

  /// How far the air has rushed past (px), kept between frames.
  double _rush = 0;

  static final GrainBatch _b = GrainBatch(10);
  TextPainter? _titlePainter;

  @override
  void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  }) {
    final w = s.screen.width, h = s.screen.height;
    final centre = Offset(w / 2, h * 0.48);
    final open = s.open, land = s.land;
    final closing = s.closing;

    // How far inside its air the camera is.
    final inside = _smooth(0.38, 0.78, open);
    // How fast the air goes by: down at speed, still once the dungeon has
    // come up; going back, out of it at speed.
    final pace = closing
        ? _smooth(0.45, 1, open) * (0.4 + 0.6 * (1 - land))
        : _smooth(0.5, 1, open) * (1 - _smooth(0.0, 0.8, land));
    final airAlpha = closing
        ? _smooth(0.32, 0.7, open) * (1 - _smooth(0.5, 1, land))
        : _smooth(0.32, 0.7, open) * (1 - _smooth(0.2, 0.85, land));

    if (back) {
      if (s.ground > 0) {
        canvas.drawRect(
          Offset.zero & s.screen,
          Paint()..color = _kSpace.withValues(alpha: s.ground),
        );
      }
      if (inside > 0) _paintAir(canvas, s.screen, centre, inside);
    }
    if (!front) return;

    final t = s.time;
    _firstTime ??= t;
    final dt = _step(t);
    _rush += dt * pace * 900;

    // The planet: swelling from its place as the camera falls toward it —
    // faster as it nears, as anything you fall toward does — and coming
    // apart into its own grains as the camera reaches it, so it never
    // stands over the whole screen as a flat sheet of color.
    final r0 = planet.shortestSide / 2;
    final pr = r0 / (1 - 0.8 * _ease(open));
    final pc = Offset.lerp(planet.center, centre, _smooth(0, 0.7, open))!;
    final planetAlpha = 1 - _smooth(0.36, 0.66, open);
    if (planetAlpha > 0.004) {
      // Its own clock where space stopped, running on once the camera has
      // left — and back at that moment as it returns.
      final pt = planetTime + (t - _firstTime!) * math.min(1.0, open * 3);
      canvas.saveLayer(
        Offset.zero & s.screen,
        Paint()..color = Color.fromRGBO(0, 0, 0, planetAlpha),
      );
      art.paintBack(canvas, pc, pr, pt);
      art.paintBody(canvas, pc, pr, pt);
      art.paintFront(canvas, pc, pr, pt);
      canvas.restore();
    }

    final peel = _smooth(0.3, 0.8, open);
    final flakes = peel * (1 - _smooth(0.72, 0.95, open));
    if (flakes > 0.004) _paintFlakes(canvas, pc, pr, peel, flakes);

    if (airAlpha > 0.004) {
      _paintRush(canvas, s.screen, centre, airAlpha, pace, inward: closing);
    }

    // The dungeon's name, while it is built.
    final named = closing
        ? 0.0
        : _smooth(0.75, 1, open) * (1 - _smooth(0, 0.4, land));
    if (named > 0.01 && title.isNotEmpty) _paintTitle(canvas, centre, named);

    // The ship, diving on ahead into the planet (or climbing out of it).
    final grains = ShipGrains.now(skin);
    final u = _smooth(0, 0.55, open);
    if (u < 1) {
      final at = Offset.lerp(ship.at, pc, _ease(u))!;
      final toward = pc - ship.at;
      final way = toward.distance < 1
          ? ship.heading
          : math.atan2(toward.dx, -toward.dy) + (closing ? math.pi : 0);
      final heading = _lerpAngle(ship.heading, way, _smooth(0, 0.3, u));
      final pose = ShipPose(at, ship.scale * math.pow(1 - u, 1.3), heading);
      final alpha = 1 - _smooth(0.7, 1, u);
      if (grains != null) {
        paintShipGrains(canvas, grains, shipLight(skin), pose, t, alpha: alpha);
      } else {
        canvas.save();
        canvas.translate(pose.at.dx, pose.at.dy);
        canvas.rotate(pose.heading);
        canvas.scale(pose.scale);
        paintShipHull(canvas, skin, t);
        canvas.restore();
      }
    }
  }

  double _step(double t) {
    final last = _last;
    _last = t;
    if (last == null || t < last || t - last > 0.25) return 1 / 60;
    return t - last;
  }

  /// Inside the planet's air: its color, deepest at the edges.
  void _paintAir(Canvas canvas, Size size, Offset centre, double alpha) {
    final r = math.sqrt(size.width * size.width + size.height * size.height);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          r * 0.6,
          [
            Color.lerp(color, Colors.black, 0.64)!.withValues(alpha: alpha),
            Color.lerp(color, Colors.black, 0.85)!.withValues(alpha: alpha),
            Color.lerp(_kSpace, color, 0.06)!.withValues(alpha: alpha),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
  }

  /// The planet's surface coming apart toward the camera: grains of it, taken
  /// across its disc, spreading out past the screen's edge as [peel] grows
  /// (and, climbing out, gathering back onto it).
  void _paintFlakes(
    Canvas canvas,
    Offset pc,
    double pr,
    double peel,
    double alpha,
  ) {
    final b = _b..clear();
    for (var i = 0; i < 340; i++) {
      final angle = _h(i, 11) * math.pi * 2;
      final rho = math.sqrt(_h(i, 12)) * 0.96;
      // The near side lifts first and furthest.
      final lift = 1 + peel * (0.6 + 2.8 * rho * rho) * (0.7 + 0.6 * _h(i, 13));
      final at =
          pc + Offset(math.cos(angle), math.sin(angle)) * (pr * rho * lift);
      b.add(i % 4, at.dx, at.dy);
    }
    // Lit, so they stand off the planet's own face as they lift.
    final shades = [
      color,
      Color.lerp(color, Colors.white, 0.25)!,
      Color.lerp(color, Colors.white, 0.5)!,
      Color.lerp(color, Colors.white, 0.8)!,
    ];
    b.draw(canvas, 2, 6, color.withValues(alpha: 0.14 * alpha));
    for (var k = 0; k < 4; k++) {
      b.draw(canvas, k, 2.0 + k * 0.45, shades[k].withValues(alpha: alpha));
    }
  }

  /// The planet's air rushing past: grains in its colors coming out of the
  /// middle and drawing out into runs as they near the edge (or, climbing
  /// out, pouring back into the middle).
  void _paintRush(
    Canvas canvas,
    Size size,
    Offset centre,
    double alpha,
    double pace, {
    required bool inward,
  }) {
    final b = _b..clear();
    final far =
        math.sqrt(size.width * size.width + size.height * size.height) * 0.62;
    for (var i = 0; i < 260; i++) {
      final angle = _h(i, 1) * math.pi * 2;
      final speed = 0.5 + _h(i, 2);
      var d = (_h(i, 3) + _rush * speed / far) % 1.0;
      if (inward) d = 1 - d;
      // Nearer the edge, nearer the camera: further out and faster.
      final rr = far * math.pow(d, 1.7);
      final dir = Offset(math.cos(angle), math.sin(angle));
      final at = centre + dir * rr;
      final shade = i % 4;
      final fade = _smooth(0.0, 0.2, d) * (1 - _smooth(0.85, 1, d));
      b.add(fade > 0.5 ? shade : 4 + shade, at.dx, at.dy);
      final run = (pace * d * 7).round();
      for (var k = 1; k <= run; k++) {
        final back = at - dir * (k * (2.5 + 9 * d) * pace);
        b.add(8 + (k * 2 > run ? 1 : 0), back.dx, back.dy);
      }
    }
    final deep = Color.lerp(color, Colors.black, 0.3)!;
    final lit = Color.lerp(color, Colors.white, 0.35)!;
    final hot = Color.lerp(color, Colors.white, 0.7)!;
    final shades = [deep, color, lit, hot];
    b.draw(canvas, 9, 1.6, lit.withValues(alpha: 0.26 * alpha));
    b.draw(canvas, 8, 1.9, lit.withValues(alpha: 0.5 * alpha));
    b.draw(canvas, 3, 6, color.withValues(alpha: 0.1 * alpha));
    for (var k = 0; k < 4; k++) {
      b.draw(canvas, 4 + k, 1.8, shades[k].withValues(alpha: 0.5 * alpha));
      b.draw(canvas, k, 2.0 + k * 0.35, shades[k].withValues(alpha: alpha));
    }
  }

  void _paintTitle(Canvas canvas, Offset centre, double alpha) {
    final tp = _titlePainter ??= TextPainter(
      text: TextSpan(
        text: title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFE8DFC8),
          fontFamily: 'monospace',
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.saveLayer(
      Rect.fromCenter(center: centre, width: tp.width + 40, height: 60),
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)),
    );
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
    canvas.restore();
  }
}
