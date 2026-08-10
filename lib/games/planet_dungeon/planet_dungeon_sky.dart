// lib/games/planet_dungeon/planet_dungeon_sky.dart
//
// Dungeon background shader registry + component. One elemental background
// shader is active per dungeon, all sharing the same uniform contract and this
// same loader. Visual-only: nothing here owns gameplay or collision. Falls
// back to a gradient if the shader can't load or low-perf mode is on.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Per-element shader configuration (palette + flow params). The shader file is
/// `assets/shaders/dungeon/built/<el>.frag` (assembled by
/// tool/build_dungeon_shaders.dart). Elements absent here fall back to the
/// gradient until their shader + config are added.
class DungeonSkyConfig {
  final Color colorA; // zenith / base
  final Color colorB; // horizon / mid
  final Color colorC; // highlight / energy
  final double intensity;
  final double noiseScale;
  final double flowSpeed;
  final double seed;

  const DungeonSkyConfig({
    required this.colorA,
    required this.colorB,
    required this.colorC,
    this.intensity = 1.0,
    this.noiseScale = 2.4,
    this.flowSpeed = 0.6,
    this.seed = 7.0,
  });
}

const Map<String, DungeonSkyConfig> kDungeonSkyConfigs = {
  // Air (GAS family) — cool twilight sky, pale cloud highlights.
  'Air': DungeonSkyConfig(
    colorA: Color(0xFF16223A),
    colorB: Color(0xFF35577E),
    colorC: Color(0xFFBFD2E6),
    intensity: 1.0,
    noiseScale: 2.6,
    flowSpeed: 0.6,
    seed: 7.0,
  ),
  // Fire (Cinder Cathedral) — soot vault lit from below; ember highlights.
  'Fire': DungeonSkyConfig(
    colorA: Color(0xFF140A07), // soot-black vault
    colorB: Color(0xFF452010), // ember dusk pooling low
    colorC: Color(0xFFFFB46B), // flame highlight
    intensity: 1.0,
    noiseScale: 2.3,
    flowSpeed: 0.55,
    seed: 13.0,
  ),
  // Water (Mirror-Tide Temple) — drowned hall: caustics, god-rays, bubbles.
  'Water': DungeonSkyConfig(
    colorA: Color(0xFF050E18), // abyssal ceiling
    colorB: Color(0xFF0E3644), // deep teal
    colorC: Color(0xFF8FE0EC), // caustic highlight
    intensity: 1.0,
    noiseScale: 2.2,
    flowSpeed: 0.6,
    seed: 21.0,
  ),
  // Earth (Buried Giant) — sediment strata, seismic pulse, crystal glints.
  'Earth': DungeonSkyConfig(
    colorA: Color(0xFF0C0905), // packed dark earth
    colorB: Color(0xFF2E2214), // strata mid
    colorC: Color(0xFFD8B878), // bone-amber highlight
    intensity: 1.0,
    noiseScale: 2.4,
    flowSpeed: 0.55,
    seed: 34.0,
  ),
  // Lightning (Storm Circuit) — charged storm-dark veined with electric blue
  // and arc-white; branching veins, sheet-flashes, rising charge motes.
  'Lightning': DungeonSkyConfig(
    colorA: Color(0xFF070C16), // packed storm-dark
    colorB: Color(0xFF1E3A66), // charged blue
    colorC: Color(0xFFBFE6FF), // arc-white highlight
    intensity: 1.05,
    noiseScale: 2.5,
    flowSpeed: 0.7,
    seed: 47.0,
  ),
  // Steam (Pressure Cathedral) — iron boiler gloom, rising mist, furnace embers.
  'Steam': DungeonSkyConfig(
    colorA: Color(0xFF0E1418), // iron dark
    colorB: Color(0xFF8FA6B0), // steam grey-white
    colorC: Color(0xFFFFB46B), // furnace ember
    intensity: 1.0,
    noiseScale: 2.3,
    flowSpeed: 0.6,
    seed: 58.0,
  ),
  // Other 11 elements: add config + built/<el>.frag to enable. Until then they
  // use the gradient fallback automatically.
};

class DungeonSky {
  /// When true, the shader is skipped entirely (gradient fallback). Wire this
  /// to a low-performance / accessibility setting if desired.
  static bool lowPerfMode = false;

  ui.FragmentShader? _shader;
  DungeonSkyConfig? _config;

  bool get ready => _shader != null && _config != null;

  Future<void> load(String element) async {
    if (lowPerfMode) return;
    final cfg = kDungeonSkyConfigs[element];
    if (cfg == null) return; // no shader for this element → gradient fallback
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/dungeon/built/${element.toLowerCase()}.frag',
      );
      _shader = program.fragmentShader();
      _config = cfg;
    } catch (_) {
      _shader = null;
      _config = null; // any failure → gradient fallback
    }
  }

  /// Paint the full-screen background shader. Caller should only invoke when
  /// [ready] is true; otherwise draw the gradient fallback.
  ///
  /// [mood] (0..1, 0.5 = authored baseline) shifts the palette per room:
  /// below 0.5 the sky bruises toward storm-dark, above it brightens toward
  /// summit dawn — same shader, host-side color shaping.
  void paint(Canvas canvas, Size size, double time, {double mood = 0.5}) {
    final s = _shader;
    final c = _config;
    if (s == null || c == null) return;
    final w = size.width <= 0 ? 1.0 : size.width;
    final h = size.height <= 0 ? 1.0 : size.height;
    Color shade(Color base) {
      if (mood > 0.5) {
        return Color.lerp(base, const Color(0xFFFFFFFF), (mood - 0.5) * 0.5)!;
      }
      return Color.lerp(base, const Color(0xFF000000), (0.5 - mood) * 0.75)!;
    }

    final a = shade(c.colorA);
    final b = shade(c.colorB);
    final cc = shade(c.colorC);
    s
      ..setFloat(0, w)
      ..setFloat(1, h)
      ..setFloat(2, time)
      ..setFloat(3, a.r)
      ..setFloat(4, a.g)
      ..setFloat(5, a.b)
      ..setFloat(6, b.r)
      ..setFloat(7, b.g)
      ..setFloat(8, b.b)
      ..setFloat(9, cc.r)
      ..setFloat(10, cc.g)
      ..setFloat(11, cc.b)
      ..setFloat(12, c.intensity * (0.75 + mood * 0.5))
      ..setFloat(13, c.noiseScale)
      ..setFloat(14, c.flowSpeed)
      ..setFloat(15, c.seed);
    canvas.drawRect(Offset.zero & size, Paint()..shader = s);
  }
}
