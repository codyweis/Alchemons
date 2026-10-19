// lib/widgets/fx/cosmetics/season_drift_art.dart
//
// What the season sheds into a home realm's air where it has trees: leaves
// coming down in autumn, tumbling as they fall and settling out of sight
// at the ground; petals drifting along on the wind in spring, barely
// falling. Summer and winter shed nothing (winter's snow lies on the land;
// falling snow is the Valley's weather, or the Athanor's Snowfall).
//
// Stateless and laid in tiles, as the ambiences are (home_ambience_art.dart):
// every grain a function of the field's clock, one atlas draw a frame.

import 'dart:math' as math;

import 'package:alchemons/games/cosmic/obsidian_kit.dart' show hash01;
import 'package:alchemons/models/home_sky.dart';
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_atlas.dart';
import 'package:alchemons/widgets/fx/cosmetics/home_ambience_art.dart';
import 'package:flutter/painting.dart';

const _leaves = [
  Color(0xFFC8742A),
  Color(0xFFA8461E),
  Color(0xFFD9A040),
  Color(0xFF8E5A2A),
];
const _petals = [Color(0xFFF6D8E2), Color(0xFFFFF0F4), Color(0xFFEBC0D2)];

/// Whether [s] sheds anything into the air.
bool seasonSheds(HomeSeason? s) =>
    s == HomeSeason.autumn || s == HomeSeason.spring;

/// Lays [s]'s falling things over the view [v], [shown] 0–1, into [over].
void paintSeasonDrift(
  HomeSeason s,
  AmbienceView v,
  double shown,
  CosmeticAtlas over, {
  double tile = kAmbienceTile,
}) {
  if (shown <= 0.004 || !seasonSheds(s)) return;
  final k0 = ((v.left - tile * 0.1) / tile).floor();
  final k1 = math.min(k0 + 4, ((v.right + tile * 0.1) / tile).floor());
  for (var k = k0; k <= k1; k++) {
    final ox = k * tile;
    if (s == HomeSeason.autumn) {
      _fallingLeaves(v, ox, tile, shown, over);
    } else {
      _driftingPetals(v, ox, tile, shown, over);
    }
  }
}

void _fallingLeaves(
  AmbienceView v,
  double ox,
  double tile,
  double shown,
  CosmeticAtlas over,
) {
  final h = v.height;
  final scale = h / 475;
  final n = (26 * tile / kAmbienceTile).round().clamp(6, 26);
  for (var i = 0; i < n; i++) {
    final near = hash01(i, 71) < 0.2;
    final fall = (16 + 14 * hash01(i, 72)) * scale * (near ? 1.4 : 1);
    final span = h * 1.15;
    final y = -h * 0.08 + (hash01(i, 73) * span + v.time * fall) % span;
    // A leaf swings side to side as it comes down, and turns over.
    final swing = math.sin(v.time * (0.9 + 0.5 * hash01(i, 74)) + i * 2.3);
    final x =
        ox +
        (hash01(i, 75) * tile + v.time * 9 * scale) % tile +
        swing * 16 * scale;
    if (x < v.left - 30 || x > v.right + 30) continue;
    final g = v.ground(x) ?? v.top + (v.bottom - v.top) * 0.95;
    final land = 1 - smoothstep(g - h * 0.03, g + h * 0.01, y);
    if (land <= 0) continue;
    final born = smoothstep(-h * 0.08, h * 0.04, y);
    final a = shown * land * born * (near ? 0.9 : 0.75);
    final c = _leaves[i % _leaves.length];
    // Seen flat it is broad; edge-on, a sliver.
    final turn = math.cos(v.time * (1.6 + hash01(i, 76)) + i);
    final size = (near ? 9.0 : 6.0) * scale;
    over.add(
      AtlasCell.plume,
      x,
      y,
      size * (0.45 + 0.55 * turn.abs()),
      atlasArgb(c, a),
      rot: swing * 0.9 + hash01(i, 77) * math.pi,
    );
  }
}

void _driftingPetals(
  AmbienceView v,
  double ox,
  double tile,
  double shown,
  CosmeticAtlas over,
) {
  final h = v.height;
  final scale = h / 475;
  final n = (48 * tile / kAmbienceTile).round().clamp(10, 48);
  for (var i = 0; i < n; i++) {
    // Carried along more than down.
    final along = (22 + 18 * hash01(i, 81)) * scale;
    final x = ox + (hash01(i, 82) * tile + v.time * along) % tile;
    if (x < v.left - 20 || x > v.right + 20) continue;
    final base = v.top + (v.bottom - v.top) * (0.15 + 0.6 * hash01(i, 83));
    final y =
        base +
        math.sin(v.time * (0.5 + 0.4 * hash01(i, 84)) + i * 1.9) * 26 * scale +
        (v.time * 3 * scale) % (h * 0.2);
    final g = v.ground(x);
    if (g != null && y > g) continue;
    final flick = 0.6 + 0.4 * math.sin(v.time * (2 + hash01(i, 85)) + i);
    final c = _petals[i % _petals.length];
    final size = (3.2 + 2.4 * hash01(i, 86)) * scale;
    over
      ..add(AtlasCell.dot, x, y, size * 2.2, atlasArgb(c, 0.25 * shown))
      ..add(
        AtlasCell.bead,
        x,
        y,
        size * (0.6 + 0.4 * flick),
        atlasArgb(c, 0.85 * shown),
      );
  }
}
