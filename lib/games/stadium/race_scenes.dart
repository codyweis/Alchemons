// lib/games/stadium/race_scenes.dart
//
// The country a course runs through once it is out of the stadium (the
// author, 2026-10-12: "more diversity ... like chao gardens all the obstacles
// were different and different maps"). Each scene is a sky, two ranges of
// silhouette — dark masses with a lit rim of grains and a few grains in
// them, the far one moving slower — a ground the track is made of, things
// close by that pass faster than the track, and something drifting in the
// air. Drawn as everything in the game is: lit grains on black, no models.
//
//   meadow   rolling green hills under a low night sky, pollen drifting
//   volcano  black ridges lit red from below, a cone glowing, embers
//   cliffs   tall jagged cliffs, cold light, a storm overhead
//   hills    layered downs at dusk, gold light low in the sky
//   forest   a moonlit treeline, fireflies
//   caves    stalactites over a crystal floor, glints
//   space    stars and a far world; the track floats over nothing
//
// The stadium itself is drawn by the race painter (its stands).

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart' show elementColor;
import 'package:alchemons/games/cosmic/obsidian_kit.dart' show hash01;
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';

enum SceneRange { none, rolling, jagged, volcano, trees, stalactites, crystals }

enum SceneAir { none, pollen, embers, fireflies, sparkle, stars }

/// How a scene looks.
class SceneLook {
  const SceneLook({
    required this.skyTop,
    required this.skyLow,
    required this.far,
    required this.near,
    required this.farTone,
    required this.nearTone,
    required this.rim,
    required this.surface,
    required this.surfaceGrain,
    required this.face,
    required this.faceGrain,
    required this.air,
    required this.airTone,
    this.glow,
    this.glowAt = const Offset(0.7, 0.3),
    this.floats = false,
  });

  /// The sky, top to the horizon, and a light low in it (a lava glow, the
  /// moon, the sun going down).
  final Color skyTop, skyLow;
  final Color? glow;
  final Offset glowAt;

  /// The far and near ranges, their tones, and the light along their rims.
  final SceneRange far, near;
  final Color farTone, nearTone, rim;

  /// The track's ground: its top, and the face of the earth under it.
  final Color surface, surfaceGrain, face, faceGrain;

  /// What drifts in the air.
  final SceneAir air;
  final Color airTone;

  /// The track floats over nothing (no face under it).
  final bool floats;
}

const Map<RaceScene, SceneLook> kSceneLooks = {
  RaceScene.meadow: SceneLook(
    skyTop: Color(0xFF080B0E),
    skyLow: Color(0xFF13201F),
    glow: Color(0xFF9FC8B0),
    glowAt: Offset(0.22, 0.18),
    far: SceneRange.rolling,
    near: SceneRange.rolling,
    farTone: Color(0xFF0A110E),
    nearTone: Color(0xFF0D1611),
    rim: Color(0xFF8DBE8A),
    surface: Color(0xFF17251B),
    surfaceGrain: Color(0xFF7FA672),
    face: Color(0xFF0E1611),
    faceGrain: Color(0xFF3F5A3A),
    air: SceneAir.pollen,
    airTone: Color(0xFFDDEBA8),
  ),
  RaceScene.volcano: SceneLook(
    skyTop: Color(0xFF0C0706),
    skyLow: Color(0xFF26100A),
    glow: Color(0xFFE8642C),
    glowAt: Offset(0.72, 0.34),
    far: SceneRange.volcano,
    near: SceneRange.jagged,
    farTone: Color(0xFF120A08),
    nearTone: Color(0xFF170D0A),
    rim: Color(0xFFE8743C),
    surface: Color(0xFF221513),
    surfaceGrain: Color(0xFF9A5A40),
    face: Color(0xFF140B09),
    faceGrain: Color(0xFF6A2E1E),
    air: SceneAir.embers,
    airTone: Color(0xFFF5A060),
  ),
  RaceScene.cliffs: SceneLook(
    skyTop: Color(0xFF08090F),
    skyLow: Color(0xFF191B28),
    far: SceneRange.jagged,
    near: SceneRange.jagged,
    farTone: Color(0xFF0C0D15),
    nearTone: Color(0xFF10121A),
    rim: Color(0xFFAFA6CC),
    surface: Color(0xFF1C1E26),
    surfaceGrain: Color(0xFF8E92A6),
    face: Color(0xFF101117),
    faceGrain: Color(0xFF474B5E),
    air: SceneAir.none,
    airTone: Color(0xFFB9C7FF),
  ),
  RaceScene.hills: SceneLook(
    skyTop: Color(0xFF0B0C09),
    skyLow: Color(0xFF262418),
    glow: Color(0xFFE2C98F),
    glowAt: Offset(0.3, 0.3),
    far: SceneRange.rolling,
    near: SceneRange.rolling,
    farTone: Color(0xFF10120C),
    nearTone: Color(0xFF14170F),
    rim: Color(0xFFD2C080),
    surface: Color(0xFF26261A),
    surfaceGrain: Color(0xFFA49C6C),
    face: Color(0xFF17170F),
    faceGrain: Color(0xFF4E4A32),
    air: SceneAir.pollen,
    airTone: Color(0xFFE2C98F),
  ),
  RaceScene.forest: SceneLook(
    skyTop: Color(0xFF05070C),
    skyLow: Color(0xFF101824),
    glow: Color(0xFFC8D8F0),
    glowAt: Offset(0.26, 0.12),
    far: SceneRange.trees,
    near: SceneRange.trees,
    farTone: Color(0xFF070B10),
    nearTone: Color(0xFF0A0F15),
    rim: Color(0xFF8EA6C8),
    surface: Color(0xFF131B1D),
    surfaceGrain: Color(0xFF5E7E84),
    face: Color(0xFF0B1113),
    faceGrain: Color(0xFF2C3E46),
    air: SceneAir.fireflies,
    airTone: Color(0xFFD8F0A0),
  ),
  RaceScene.caves: SceneLook(
    skyTop: Color(0xFF06070B),
    skyLow: Color(0xFF0F121A),
    glow: Color(0xFF7FD8E8),
    glowAt: Offset(0.6, 0.45),
    far: SceneRange.stalactites,
    near: SceneRange.crystals,
    farTone: Color(0xFF0A0C13),
    nearTone: Color(0xFF0D111A),
    rim: Color(0xFF9FE8F2),
    surface: Color(0xFF151A22),
    surfaceGrain: Color(0xFF86C2D0),
    face: Color(0xFF0D0F15),
    faceGrain: Color(0xFF3A4E5C),
    air: SceneAir.sparkle,
    airTone: Color(0xFFBFF2FA),
  ),
  RaceScene.space: SceneLook(
    skyTop: Color(0xFF030306),
    skyLow: Color(0xFF0A0A16),
    glow: Color(0xFF9C8FB0),
    glowAt: Offset(0.78, 0.22),
    far: SceneRange.none,
    near: SceneRange.none,
    farTone: Color(0xFF0E0E1A),
    nearTone: Color(0xFF12121F),
    rim: Color(0xFFB8AEDC),
    surface: Color(0xFF14142A),
    surfaceGrain: Color(0xFFA89CD0),
    face: Color(0xFF000000),
    faceGrain: Color(0xFF6A5E9A),
    air: SceneAir.stars,
    airTone: Color(0xFFE6E2F4),
    floats: true,
  ),
};

final GrainBatch _batch = GrainBatch(8);
final Paint _fill = Paint();

/// The height of a range at world x [x] (its own units, 0..1-ish).
double _rangeAt(SceneRange r, double x, int seed) {
  final s = seed * 1.37;
  switch (r) {
    case SceneRange.none:
      return 0;
    case SceneRange.rolling:
      return 0.5 +
          0.28 * sin(x * 0.0042 + s) +
          0.16 * sin(x * 0.0113 + 2.1 * s) +
          0.05 * sin(x * 0.031 + s);
    case SceneRange.jagged:
      double tri(double v) => (2 * (v - (v + 0.5).floorToDouble())).abs();
      return 0.35 +
          0.4 * tri(x * 0.0021 + s) +
          0.18 * tri(x * 0.0067 + 0.3 * s) +
          0.07 * tri(x * 0.019 + s);
    case SceneRange.volcano:
      // Low ridges, and every so far along a cone with a flat crater.
      final base =
          0.3 + 0.12 * sin(x * 0.005 + s) + 0.06 * sin(x * 0.017 + 2 * s);
      const period = 1500.0;
      final d = ((x + 400 + seed * 300) % period) - period / 2;
      final cone = max(0.0, 1 - d.abs() / 340);
      return max(base, min(1.05, cone * 1.25));
    case SceneRange.trees:
      // A treeline: a low line of crowns with narrow tops standing out.
      final cell = (x / 18).floor();
      final f = x / 18 - cell;
      final h = 0.45 + 0.4 * hash01(cell, 300 + seed);
      final peak = 1 - (f - 0.5).abs() * 2;
      return 0.32 + 0.08 * sin(x * 0.01 + s) + h * 0.55 * pow(peak, 1.6);
    case SceneRange.stalactites:
    case SceneRange.crystals:
      final cell = (x / 26).floor();
      final f = x / 26 - cell;
      final h = hash01(cell, 310 + seed);
      final lean = (hash01(cell, 311 + seed) - 0.5) * 0.6;
      final peak = max(0.0, 1 - (f - 0.5 - lean * 0.3).abs() * 2.4);
      return 0.12 + (h * h) * 0.9 * peak + 0.05 * sin(x * 0.02 + s);
  }
}

/// The sky, a light low in it, and the two ranges, for track x [camX] seen
/// at [k] (world px to screen px); the ranges stand on [horizon] (screen y)
/// and rise at most [reach]. [amount] fades the whole of it in over the
/// stadium.
void paintSceneBackdrop(
  Canvas c,
  Size size,
  SceneLook look, {
  required double camX,
  required double camY,
  required double k,
  required double horizon,
  required double reach,
  required double t,
  double amount = 1,
}) {
  if (amount <= 0.01) return;
  final w = size.width;
  // The sky.
  _fill.shader = ui.Gradient.linear(Offset.zero, Offset(0, horizon), [
    look.skyTop.withValues(alpha: amount),
    look.skyLow.withValues(alpha: amount),
  ]);
  c.drawRect(Rect.fromLTRB(0, 0, w, horizon + 2), _fill);
  _fill.shader = null;
  final glow = look.glow;
  if (glow != null) {
    final at = Offset(
      w * look.glowAt.dx,
      horizon * look.glowAt.dy + horizon * 0.4,
    );
    final r = horizon * 0.9;
    _fill.shader = ui.Gradient.radial(at, r, [
      glow.withValues(alpha: 0.16 * amount),
      glow.withValues(alpha: 0),
    ]);
    c.drawCircle(at, r, _fill);
    _fill.shader = null;
    if (look.air == SceneAir.fireflies || look.glowAt.dy < 0.2) {
      // The moon: a small disc of grains.
      final b = _batch..clear();
      for (var i = 0; i < 60; i++) {
        final a = hash01(i, 401) * pi * 2;
        final rr = sqrt(hash01(i, 402)) * 7 * (k / max(k, 1));
        b.add(0, at.dx + cos(a) * rr, at.dy - horizon * 0.25 + sin(a) * rr);
      }
      b.draw(c, 0, 1.6, glow.withValues(alpha: 0.75 * amount));
    }
  }

  // Stars over the space scene.
  if (look.air == SceneAir.stars) {
    final b = _batch..clear();
    for (var i = 0; i < 140; i++) {
      final par = 0.05 + hash01(i, 420) * 0.12;
      final x = (hash01(i, 421) * (w + 200) - camX * k * par) % (w + 200) - 100;
      final y = hash01(i, 422) * horizon * 1.1;
      b.add(hash01(i, 423) < 0.15 ? 1 : 0, x, y);
    }
    b.draw(c, 0, 1.1, look.airTone.withValues(alpha: 0.45 * amount));
    b.draw(c, 1, 1.8, look.airTone.withValues(alpha: 0.9 * amount));
    // A far world, low and huge, in grains.
    final world = Offset(w * 0.78 - camX * k * 0.02, horizon * 0.62);
    final wr = horizon * 0.42;
    for (var i = 0; i < 520; i++) {
      final a = hash01(i, 430) * pi * 2;
      final rr = sqrt(hash01(i, 431)) * wr;
      final p = world + Offset(cos(a) * rr, sin(a) * rr);
      final lit =
          ((p.dx - world.dx) / wr * -0.6 + (p.dy - world.dy) / wr * -0.5).clamp(
            -1.0,
            1.0,
          );
      b.add(lit > 0.2 ? 3 : (lit > -0.3 ? 2 : 4), p.dx, p.dy);
    }
    b.draw(c, 4, 1.4, const Color(0xFF2A2440).withValues(alpha: 0.8 * amount));
    b.draw(c, 2, 1.5, const Color(0xFF5A4C80).withValues(alpha: 0.7 * amount));
    b.draw(c, 3, 1.6, const Color(0xFFB0A0DC).withValues(alpha: 0.8 * amount));
  }

  _range(
    c,
    w,
    look,
    look.far,
    look.farTone,
    0.22,
    camX,
    camY,
    k,
    horizon,
    reach * 0.95,
    1,
    amount * 0.85,
    t,
  );
  _range(
    c,
    w,
    look,
    look.near,
    look.nearTone,
    0.48,
    camX,
    camY,
    k,
    horizon,
    reach * 0.62,
    2,
    amount,
    t,
  );
}

/// One range: a dark mass along its height line, filled down to the
/// horizon (or hung from the top for stalactites), a rim of lit grains
/// along its edge and a few grains in it.
void _range(
  Canvas c,
  double w,
  SceneLook look,
  SceneRange r,
  Color tone,
  double par,
  double camX,
  double camY,
  double k,
  double horizon,
  double reach,
  int seed,
  double amount,
  double t,
) {
  if (r == SceneRange.none || amount <= 0.01) return;
  final hanging = r == SceneRange.stalactites;
  const step = 4.0;
  final shift = camY * k * par * 0.5;
  double edge(double sx) {
    final wx = (sx - w / 2) / k + camX * par;
    final v = _rangeAt(r, wx, seed);
    return hanging ? v * reach * 0.8 - shift : horizon - v * reach + shift;
  }

  final path = Path();
  final base = hanging ? 0.0 : horizon + 2;
  path.moveTo(-step, base);
  for (var sx = -step; sx <= w + step; sx += step) {
    path.lineTo(sx, edge(sx));
  }
  path.lineTo(w + step, base);
  path.close();
  final top = hanging ? 0.0 : horizon - reach;
  _fill.shader = ui.Gradient.linear(
    Offset(0, hanging ? reach : top),
    Offset(0, hanging ? 0 : horizon),
    [
      tone.withValues(alpha: amount),
      Color.lerp(tone, Colors.black, 0.35)!.withValues(alpha: amount),
    ],
  );
  c.drawPath(path, _fill);
  _fill.shader = null;

  final b = _batch..clear();
  // The rim, lit; and grains scattered in the mass, thinning into it. Laid
  // on the range's own ground (world x), so they hold still as it passes.
  double screenOf(double wx) => (wx - camX * par) * k + w / 2;
  final rimStep = 2.6 / k, fillStep = 7 / k;
  final left = camX * par - w / 2 / k;
  for (var xi = (left / rimStep).floor(); ; xi++) {
    final sx = screenOf(xi * rimStep);
    if (sx > w) break;
    final h = hash01(xi, 450 + seed);
    if (h < 0.75) {
      b.add(
        h < 0.2 ? 1 : 0,
        sx + (h - 0.5) * 1.5,
        edge(sx) + (hanging ? -1 : 1),
      );
    }
  }
  for (var xi = (left / fillStep).floor(); ; xi++) {
    final sx = screenOf(xi * fillStep);
    if (sx > w) break;
    final y = edge(sx);
    for (var d = 6.0; d < reach; d += 9) {
      final h = hash01(xi * 31 + d.round(), 460 + seed);
      if (h > 0.34 - d / reach * 0.3) continue;
      final yy = hanging ? y - d : y + d;
      if (!hanging && yy > horizon) break;
      if (hanging && yy < 0) break;
      b.add(2, sx + (h - 0.2) * 6, yy);
    }
  }
  b.draw(
    c,
    2,
    1.3,
    Color.lerp(tone, look.rim, 0.35)!.withValues(alpha: 0.5 * amount),
  );
  b.draw(
    c,
    0,
    1.5,
    look.rim.withValues(alpha: (seed == 1 ? 0.35 : 0.55) * amount),
  );
  b.draw(
    c,
    1,
    2.0,
    Color.lerp(look.rim, Colors.white, 0.35)!.withValues(alpha: 0.75 * amount),
  );
}

/// What drifts in the air over the scene: pollen, embers rising, fireflies
/// blinking, glints, nothing.
void paintSceneAir(
  Canvas c,
  Size size,
  SceneLook look, {
  required double camX,
  required double k,
  required double t,
  double amount = 1,
}) {
  if (amount <= 0.01 ||
      look.air == SceneAir.none ||
      look.air == SceneAir.stars) {
    return;
  }
  final w = size.width, h = size.height;
  final b = _batch..clear();
  const n = 46;
  for (var i = 0; i < n; i++) {
    final h1 = hash01(i, 470), h2 = hash01(i, 471), h3 = hash01(i, 472);
    final par = 0.6 + h3 * 0.6;
    double x = (h1 * (w + 120) - camX * k * par) % (w + 120) - 60;
    double y;
    var lit = 1.0;
    switch (look.air) {
      case SceneAir.embers:
        final life = (t * (0.08 + h2 * 0.06) + h1) % 1.0;
        y = h * (1 - life);
        x += sin(life * 9 + i) * 10;
        lit = sin(pi * life);
      case SceneAir.fireflies:
        y = h * (0.25 + h2 * 0.6) + sin(t * 0.7 + i) * 8;
        x += cos(t * 0.5 + i * 2) * 10;
        lit = max(0.0, sin(t * (0.8 + h3) + i * 1.9));
      case SceneAir.sparkle:
        y = h * (0.15 + h2 * 0.7);
        lit = pow(max(0.0, sin(t * (1.2 + h3) + i * 2.3)), 6).toDouble();
      default:
        y = h * (0.2 + h2 * 0.65) + sin(t * 0.4 + i) * 6;
        x += sin(t * 0.3 + i) * 12;
        lit = 0.6 + 0.4 * sin(t + i);
    }
    if (lit < 0.1) continue;
    b.add(lit > 0.6 ? 1 : 0, x, y);
  }
  b.draw(c, 0, 1.4, look.airTone.withValues(alpha: 0.3 * amount));
  b.draw(c, 1, 2.0, look.airTone.withValues(alpha: 0.75 * amount));
}

/// Things close by that pass faster than the track, along the bottom of the
/// screen from [top]: clumps of grass, rocks, ferns, crystals.
void paintSceneNear(
  Canvas c,
  Size size,
  SceneLook look, {
  required double camX,
  required double k,
  required double top,
  double amount = 1,
}) {
  if (amount <= 0.01 || look.floats) return;
  const par = 1.4;
  final w = size.width, h = size.height;
  final b = _batch..clear();
  final camR = camX * par;
  final viewL = camR - w * 0.5 / k - 40, viewR = camR + w * 0.5 / k + 40;
  double sx(double x) => w * 0.5 + (x - camR) * k;
  const cell = 46.0;
  for (var xi = (viewL / cell).floor(); xi <= (viewR / cell).ceil(); xi++) {
    final h1 = hash01(xi, 480), h2 = hash01(xi, 481);
    if (h1 > 0.55) continue;
    final x0 = sx(xi * cell + h2 * cell);
    final tall = (8 + h2 * 16) * k;
    final base = top + (h - top) * (0.35 + h1 * 0.5);
    final blades = 5 + (h2 * 6).floor();
    for (var j = 0; j < blades; j++) {
      final lean = (hash01(xi * 7 + j, 482) - 0.5) * 0.8;
      final len = tall * (0.5 + 0.5 * hash01(xi * 7 + j, 483));
      for (var s = 0.0; s < 1; s += 0.18) {
        b.add(
          s > 0.8 ? 1 : 0,
          x0 + j * 2.2 * k + lean * len * s,
          base - len * s,
        );
      }
    }
  }
  b.draw(c, 0, 1.6 * k, look.faceGrain.withValues(alpha: 0.55 * amount));
  b.draw(c, 1, 1.8 * k, look.rim.withValues(alpha: 0.45 * amount));
}

/// The colour a leg is marked in on the course's strip and map.
Color raceLegTint(RaceLeg leg) => switch (leg.kind) {
  RaceLegKind.sprint => const Color(0xFFE6E2DA),
  RaceLegKind.hill => const Color(0xFFB8AE9C),
  RaceLegKind.pond => const Color(0xFF5BC8E8),
  RaceLegKind.gap => const Color(0xFF6E6A80),
  RaceLegKind.ice => const Color(0xFFCFEFF8),
  RaceLegKind.mud => const Color(0xFF9A7650),
  RaceLegKind.fuse => elementColor(leg.element!),
  RaceLegKind.crowd => const Color(0xFFCDB07A),
};

/// What a scene is called, plainly, for the course's card.
String raceSceneName(RaceScene scene) => switch (scene) {
  RaceScene.stadium => 'THE ARENA',
  RaceScene.meadow => 'MEADOW',
  RaceScene.volcano => 'VOLCANO',
  RaceScene.cliffs => 'CLIFFS',
  RaceScene.hills => 'HILLS',
  RaceScene.forest => 'FOREST',
  RaceScene.caves => 'CRYSTAL CAVES',
  RaceScene.space => 'OPEN SPACE',
};
