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
  // Lava (Molten Reliquary) — foundry dark, molten runnels, white-hot pours.
  'Lava': DungeonSkyConfig(
    colorA: Color(0xFF0B0705), // cold basalt
    colorB: Color(0xFFC2400C), // molten orange
    colorC: Color(0xFFFFE0A3), // white-hot metal
    intensity: 1.05,
    noiseScale: 2.1,
    flowSpeed: 0.7,
    seed: 33.0,
  ),
  // Poison (Venom Monastery) — settled miasma, spore pallor, rot beneath.
  'Poison': DungeonSkyConfig(
    colorA: Color(0xFF0A1207), // rot dark
    colorB: Color(0xFF3E6B2A), // venous green
    colorC: Color(0xFFC8E39A), // spore pallor
    intensity: 0.95,
    noiseScale: 2.0,
    flowSpeed: 0.45, // gas settles; nothing here hurries
    seed: 41.0,
  ),
  // Ice (Frozen Observatory) — stars through the ice, aurora, faceted frost.
  'Ice': DungeonSkyConfig(
    colorA: Color(0xFF060B16), // night beyond the ice
    colorB: Color(0xFF3E7FA8), // glacier blue
    colorC: Color(0xFFDFF2FF), // frost white
    intensity: 1.0,
    noiseScale: 2.4,
    flowSpeed: 0.5,
    seed: 52.0,
  ),
  // Mud (Sinking Altar) — standing water, silt, ground mist, swamp gas.
  'Mud': DungeonSkyConfig(
    colorA: Color(0xFF0C0A06), // peat dark
    colorB: Color(0xFF4A3A20), // silt brown
    colorC: Color(0xFFB9AE93), // pale mist
    intensity: 0.9,
    noiseScale: 2.2,
    flowSpeed: 0.35, // the fen is the slowest sky in the set
    seed: 64.0,
  ),
  // Dust (Ruins of Time) — strata, wind sheets, suspended grit, dry haze.
  'Dust': DungeonSkyConfig(
    colorA: Color(0xFF120D08), // buried dark
    colorB: Color(0xFF8A6A3C), // ochre
    colorC: Color(0xFFE4D6BA), // bleached bone
    intensity: 0.95,
    noiseScale: 2.3,
    flowSpeed: 0.6,
    seed: 75.0,
  ),
  // Crystal (Prism Labyrinth) — cut facets and split light.
  'Crystal': DungeonSkyConfig(
    colorA: Color(0xFF0A0814), // stone dark
    colorB: Color(0xFF6B4FA8), // lattice violet
    colorC: Color(0xFFF2ECFF), // white refraction
    intensity: 1.0,
    noiseScale: 2.2,
    flowSpeed: 0.5,
    seed: 86.0,
  ),
  // Plant (Verdant Crypt) — canopy dapple, green-gold shafts, pollen.
  'Plant': DungeonSkyConfig(
    colorA: Color(0xFF08120A), // loam dark
    colorB: Color(0xFF2F6B34), // leaf green
    colorC: Color(0xFFF0DC96), // sun gold
    intensity: 1.0,
    noiseScale: 2.3,
    flowSpeed: 0.5,
    seed: 97.0,
  ),
  // Spirit (Echo Grave) — one field doubled, ghost fringe, drifting wisps.
  'Spirit': DungeonSkyConfig(
    colorA: Color(0xFF080A10), // grave dark
    colorB: Color(0xFF4E7C86), // spectral cyan
    colorC: Color(0xFFD6EEF2), // wisp white
    intensity: 0.95,
    noiseScale: 2.1,
    flowSpeed: 0.45,
    seed: 108.0,
  ),
  // Dark (Eclipse Vault) — totality: black disc, corona, shadow bands.
  'Dark': DungeonSkyConfig(
    colorA: Color(0xFF040407), // void
    colorB: Color(0xFF2A2450), // umbral indigo
    colorC: Color(0xFFFFF3D0), // corona
    intensity: 1.0,
    noiseScale: 2.0,
    flowSpeed: 0.4,
    seed: 119.0,
  ),
  // Light (Beacon Archive) — soft volumetric god-rays and dust in the beams.
  'Light': DungeonSkyConfig(
    colorA: Color(0xFF14100A), // hall shadow
    colorB: Color(0xFF8A7248), // warm stone
    colorC: Color(0xFFFFF6DC), // beam white
    intensity: 1.0,
    noiseScale: 2.0,
    flowSpeed: 0.4, // the light sweeps slowly; the player aims it
    seed: 130.0,
  ),
  // Blood (Sanguine Orrery) — the sky itself beats.
  'Blood': DungeonSkyConfig(
    colorA: Color(0xFF12040A), // venous dark
    colorB: Color(0xFF9E1B2F), // arterial red
    colorC: Color(0xFFFFC9BC), // oxygenated highlight
    intensity: 1.0,
    noiseScale: 2.0,
    flowSpeed: 0.8, // drives the pulse — see blood.src.frag
    seed: 141.0,
  ),
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
