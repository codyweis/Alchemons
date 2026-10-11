// lib/widgets/fx/cosmetics/home_ambience_art.dart
//
// The Athanor's home ambiences: a light layer laid over a home realm's
// field at its own hour. It never announces itself — no message, no label
// on the field — it is only there to be seen.
//
//   Peat Mist         night: low violet mist drifting along the ground,
//                     parted where the residents stand and walk
//   Moonlit Snowfall  clear nights: fine snow falling slowly, fading as it
//                     lands
//   Sun Motes         daylight: warm dust drifting and turning in the light,
//                     with short trails; no rays
//   Ember Fall        dusk: embers drifting up off the ground, cooling from
//                     gold to red and dying out as they climb
//
// Stateless: every grain is a function of the field's clock, laid in tiles
// of [kAmbienceTile] layer units so it moves with the field when it is
// panned. A frame is one drawRawAtlas of at most a couple of hundred soft
// grains — about a tenth of what a field draws, or less.

import 'dart:math' as math;

import 'package:alchemons/games/cosmic/obsidian_kit.dart' show hash01;
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_atlas.dart';
import 'package:flutter/painting.dart';

/// The width, in layer units, that an ambience's grains repeat across.
const double kAmbienceTile = 1100;

/// How much of [a] shows at [hour] (0–24): 0 outside its hour, easing in
/// and out round it. Snow falls only when the sky is [clear].
double ambienceShows(HomeAmbience a, double hour, {bool clear = true}) {
  final h = hour % 24;
  return switch (a) {
    HomeAmbience.peatMist =>
      h >= 12 ? smoothstep(18.0, 20.4, h) : 1 - smoothstep(5.2, 7.0, h),
    HomeAmbience.moonlitSnowfall =>
      clear
          ? (h >= 12 ? smoothstep(19.4, 21.0, h) : 1 - smoothstep(5.0, 6.2, h))
          : 0,
    HomeAmbience.sunMotes =>
      smoothstep(6.6, 8.6, h) * (1 - smoothstep(17.6, 19.4, h)),
    HomeAmbience.emberFall =>
      smoothstep(16.6, 18.2, h) * (1 - smoothstep(20.6, 22.4, h)),
  };
}

/// What an ambience is laid over this frame, in one layer's units.
class AmbienceView {
  const AmbienceView({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.height,
    required this.time,
    required this.ground,
    this.feet = const [],
    this.rowSize = 100,
  });

  /// The visible window.
  final double left, right, top, bottom;

  /// The layer's full height (the screen's at zoom 1).
  final double height;

  /// The field's clock, seconds.
  final double time;

  /// Where a creature would stand at x, or null where there is no ground
  /// (between isles, over water).
  final double? Function(double x) ground;

  /// Where residents' feet are (for the mist to part round).
  final List<Offset> feet;

  /// The size of a creature on this row, layer units.
  final double rowSize;
}

/// Lays [a] at [shown] (0–1) into [over] (laid over) and [light] (added).
/// [grounded] only: the mist on a row that is not the near one (the other
/// kinds fill the whole view from the near row).
///
/// [tile] and [grain] are for a preview: its grains in a narrower tile
/// (denser) and drawn larger.
void paintHomeAmbience(
  HomeAmbience a,
  AmbienceView v,
  double shown,
  CosmeticAtlas over,
  CosmeticAtlas light, {
  bool grounded = false,
  double tile = kAmbienceTile,
  double grain = 1,
}) {
  if (shown <= 0.004) return;
  final k0 = ((v.left - tile * 0.1) / tile).floor();
  final k1 = math.min(k0 + 4, ((v.right + tile * 0.1) / tile).floor());
  final t = _Tile(tile, grain);
  for (var k = k0; k <= k1; k++) {
    final ox = k * tile;
    switch (a) {
      case HomeAmbience.peatMist:
        _mist(v, t, ox, shown, over, grounded ? 0.7 : 1);
      case HomeAmbience.moonlitSnowfall:
        if (!grounded) _snow(v, t, ox, shown, over, light);
      case HomeAmbience.sunMotes:
        if (!grounded) _motes(v, t, ox, shown, over, light);
      case HomeAmbience.emberFall:
        if (!grounded) _embers(v, t, ox, shown, over, light);
    }
  }
}

/// How wide the grains' tile is, and how much larger they are drawn.
class _Tile {
  const _Tile(this.width, this.grain);
  final double width, grain;
}

bool _offView(AmbienceView v, double x, double margin) =>
    x < v.left - margin || x > v.right + margin;

// ── Peat Mist ───────────────────────────────────────────────────────────────

const Color _mistDeep = Color(0xFF6E5A9C);
const Color _mistPale = Color(0xFFB2A2D8);

void _mist(
  AmbienceView v,
  _Tile t,
  double ox,
  double shown,
  CosmeticAtlas over,
  double strength,
) {
  // As many to a stretch of ground at any width: a preview's narrow tile
  // takes fewer.
  final puffs = (34 * t.width / kAmbienceTile).round().clamp(9, 34);
  final s = v.rowSize;
  for (var i = 0; i < puffs; i++) {
    // Each puff drifts slowly along the ground on its own breath of wind,
    // swelling and thinning as it goes; a few ride higher and thinner.
    final high = i % 4 == 3;
    final speed = 4 + 7 * hash01(i, 41);
    var x = ox + (hash01(i, 42) * t.width + v.time * speed) % t.width;
    final width = s * (1.8 + 2.0 * hash01(i, 43)) * (high ? 1.3 : 1);
    if (_offView(v, x, width)) continue;
    final g = v.ground(x);
    if (g == null) continue;
    final breath =
        0.5 + 0.5 * math.sin(v.time * (0.18 + 0.12 * hash01(i, 44)) + i * 2.1);
    var alpha = (0.17 + 0.13 * breath) * shown * strength * (high ? 0.5 : 1);
    // Parted where something stands in it: pushed aside, and thinner.
    for (final f in v.feet) {
      final dx = x - f.dx;
      if ((f.dy - g).abs() > s * 0.6 || dx.abs() > width * 0.6) continue;
      final near = 1 - dx.abs() / (width * 0.6);
      x += (dx >= 0 ? 1 : -1) * near * s * 0.35;
      alpha *= 1 - 0.6 * near;
    }
    final y =
        g -
        s * (high ? 0.26 + 0.2 * hash01(i, 45) : 0.03 + 0.1 * hash01(i, 45));
    final deep = hash01(i, 46) < 0.55;
    over.add(
      AtlasCell.pool,
      x,
      y,
      width * (0.92 + 0.16 * breath),
      atlasArgb(deep ? _mistDeep : _mistPale, alpha * (deep ? 1.15 : 0.8)),
    );
  }
}

// ── Moonlit Snowfall ────────────────────────────────────────────────────────

const Color _snowWhite = Color(0xFFEAF2FF);

void _snow(
  AmbienceView v,
  _Tile t,
  double ox,
  double shown,
  CosmeticAtlas over,
  CosmeticAtlas light,
) {
  const flakes = 120;
  final h = v.height;
  for (var i = 0; i < flakes; i++) {
    // Most fall at a distance, fine; one in eight close by, large, soft
    // and quicker.
    final close = hash01(i, 55) < 0.12;
    final depth = close ? 1.5 + 0.8 * hash01(i, 51) : 0.4 + 0.6 * hash01(i, 51);
    final fall = (10 + 14 * depth) * (h / 475);
    final span = h * 1.1;
    final y = -h * 0.05 + (hash01(i, 52) * span + v.time * fall) % span;
    final sway =
        math.sin(v.time * (0.5 + 0.4 * hash01(i, 53)) + i * 1.7) * 9 * depth;
    final x =
        ox + (hash01(i, 54) * t.width + v.time * 3 * depth) % t.width + sway;
    if (_offView(v, x, 20) || y < v.top - 20 || y > v.bottom + 20) continue;
    // It lands: fades in the last stretch above the ground.
    final g = v.ground(x) ?? v.top + (v.bottom - v.top) * 0.95;
    final land = 1 - smoothstep(g - h * 0.04, g + h * 0.01, y);
    if (land <= 0) continue;
    final born = smoothstep(-h * 0.05, h * 0.06, y);
    final a = shown * land * born;
    final size = (3.0 + 4.0 * depth) * (h / 475) * t.grain;
    if (close) {
      over.add(
        AtlasCell.dot,
        x,
        y,
        size * 2.2,
        atlasArgb(_snowWhite, 0.32 * a),
      );
      continue;
    }
    // A soft flake with a firmer heart.
    over.add(
      AtlasCell.dot,
      x,
      y,
      size * 1.7,
      atlasArgb(_snowWhite, (0.45 + 0.35 * depth) * a),
    );
    over.add(AtlasCell.bead, x, y, size * 0.5, atlasArgb(_snowWhite, 0.8 * a));
  }
}

// ── Sun Motes ───────────────────────────────────────────────────────────────

const Color _moteWarm = Color(0xFFFFE2A0);
const Color _moteHot = Color(0xFFFFEFC0);
const Color _moteGold = Color(0xFFEDB848);

void _motes(
  AmbienceView v,
  _Tile t,
  double ox,
  double shown,
  CosmeticAtlas over,
  CosmeticAtlas light,
) {
  const motes = 56;
  final h = v.height;
  for (var i = 0; i < motes; i++) {
    // Drifting slowly downwind, round the tile.
    final bx = ox + (hash01(i, 61) * t.width + v.time * 2.2) % t.width;
    final by = v.top + (v.bottom - v.top) * (0.12 + 0.7 * hash01(i, 62));
    final r = (14 + 22 * hash01(i, 63)) * (h / 475);
    Offset at(double t) => Offset(
      bx + math.sin(t * 0.21 + i * 2.3) * r * 1.6 + (t - v.time) * 2.2,
      by +
          math.sin(t * 0.29 + i * 1.1) * r +
          math.sin(t * 0.73 + i * 0.7) * r * 0.25,
    );
    final p = at(v.time);
    if (_offView(v, p.dx, 10)) continue;
    // Turning in the light: bright, then nearly gone.
    final turn =
        0.5 + 0.5 * math.sin(v.time * (0.9 + 0.8 * hash01(i, 64)) + i * 3.7);
    final a = shown * (0.25 + 0.75 * turn * turn);
    final size = (2.2 + 2.4 * hash01(i, 65)) * (h / 475) * t.grain;
    // A short trail of where it just was, fainter.
    for (var tail = 3; tail >= 1; tail--) {
      final q = at(v.time - tail * 0.16);
      light.add(
        AtlasCell.dot,
        q.dx,
        q.dy,
        size * 1.7,
        atlasArgb(_moteWarm, 0.22 * a / tail),
      );
    }
    light.add(
      AtlasCell.dot,
      p.dx,
      p.dy,
      size * 5,
      atlasArgb(_moteWarm, 0.2 * a),
    );
    // The grain itself is gold, laid over (added light on a bright day
    // sky would only whiten it).
    over.add(
      AtlasCell.dot,
      p.dx,
      p.dy,
      size * 2,
      atlasArgb(_moteGold, 0.55 * a),
    );
    over.add(
      AtlasCell.bead,
      p.dx,
      p.dy,
      size * 1.05,
      atlasArgb(_moteHot, 0.95 * a),
    );
  }
}

// ── Ember Fall ──────────────────────────────────────────────────────────────

const Color _emberHot = Color(0xFFFFC266);
const Color _emberRed = Color(0xFFE0452A);
const Color _emberCore = Color(0xFFFFE6A8);

void _embers(
  AmbienceView v,
  _Tile t,
  double ox,
  double shown,
  CosmeticAtlas over,
  CosmeticAtlas light,
) {
  const embers = 64;
  final h = v.height;
  for (var i = 0; i < embers; i++) {
    final life = 3.8 + 2.6 * hash01(i, 71);
    final period = life + 1.5 + 3 * hash01(i, 72);
    final cycle = ((v.time + hash01(i, 73) * period) / period).floor();
    final age = (v.time + hash01(i, 73) * period) % period;
    if (age > life) continue;
    // Each life of an ember rises from its own place on the ground.
    final x0 = ox + hash01(i * 13 + cycle, 74) * t.width;
    if (_offView(v, x0, h * 0.2)) continue;
    final g = v.ground(x0);
    if (g == null) continue;
    final rise = (22 + 22 * hash01(i, 75)) * (h / 475);
    Offset at(double t) => Offset(
      x0 +
          math.sin(t * (1.1 + 0.6 * hash01(i, 76)) + i) *
              10 *
              (h / 475) *
              t /
              life +
          t * 4,
      g - rise * t - 2 * t * t,
    );
    final f = age / life;
    // Kindles, then cools from gold to red and dies as it climbs.
    final a = shown * smoothstep(0, 0.1, f) * (1 - smoothstep(0.6, 1, f));
    final col = Color.lerp(_emberHot, _emberRed, smoothstep(0.1, 0.8, f))!;
    final size =
        (3.2 + 2.6 * hash01(i, 77)) * (h / 475) * (1 - 0.35 * f) * t.grain;
    for (var tail = 3; tail >= 1; tail--) {
      final q = at(math.max(0, age - tail * 0.07));
      light.add(
        AtlasCell.dot,
        q.dx,
        q.dy,
        size * 1.7,
        atlasArgb(col, 0.3 * a / tail),
      );
    }
    final p = at(age);
    light.add(AtlasCell.dot, p.dx, p.dy, size * 6, atlasArgb(col, 0.3 * a));
    light.add(AtlasCell.dot, p.dx, p.dy, size * 2.6, atlasArgb(col, 0.5 * a));
    // A hot heart, laid over, so it reads against a lit sky too.
    over.add(
      AtlasCell.bead,
      p.dx,
      p.dy,
      size * 0.85,
      atlasArgb(Color.lerp(_emberCore, col, f)!, 0.95 * a),
    );
  }
}
