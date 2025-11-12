import 'dart:ui';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

// Helper function and constant from your valley scene
// to calculate battle positions
double _clampN(double x, {double min = 0.05, double max = 0.95}) =>
    x < min ? min : (x > max ? max : x);

const double kBattleOffsetX = 0.30;

Offset _nextTo(Offset p) {
  // Ensure we don't exceed normalized bounds
  final shiftedX = p.dx <= 0.5 ? p.dx + kBattleOffsetX : p.dx - kBattleOffsetX;
  return Offset(_clampN(shiftedX, max: 1.0), _clampN(p.dy, max: 1.0));
}

final skyScene = SceneDefinition(
  worldWidth: 1600,
  worldHeight: 850,
  layers: [
    LayerDefinition(
      id: SceneLayer.layer1,
      imagePath: 'backgrounds/scenes/sky/sky.png',
      parallaxFactor: 0.0,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer2,
      imagePath: 'backgrounds/scenes/sky/midground.png',
      parallaxFactor: 0.1,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer3,
      imagePath: 'backgrounds/scenes/sky/foreground.png',
      parallaxFactor: 0.7,
      widthMul: 1.0,
    ),
  ],
  spawnPoints: [
    // User's original spawn point, now with battlePos
    SpawnPoint(
      id: 'SP_sky_01', // Renamed from 'SP_volcano_01' for consistency
      normalizedPos: const Offset(0.40, 0.65), // Wild left-center
      anchor: SceneLayer.layer3,
      size: Vector2(80, 80),
      battlePos: _nextTo(const Offset(0.40, 0.65)), // -> (0.70, 0.65)
    ),
    // New spawn point: Right side, mid-ground
    SpawnPoint(
      id: 'SP_sky_02',
      normalizedPos: const Offset(0.75, 0.5), // Wild right
      anchor: SceneLayer.layer2,
      size: Vector2(70, 70),
      battlePos: _nextTo(const Offset(0.75, 0.5)), // -> (0.45, 0.5)
    ),
    // New spawn point: Left side, foreground
    SpawnPoint(
      id: 'SP_sky_03',
      normalizedPos: const Offset(0.25, 0.7), // Wild left
      anchor: SceneLayer.layer3,
      size: Vector2(90, 90),
      battlePos: _nextTo(const Offset(0.25, 0.7)), // -> (0.55, 0.7)
    ),
    // New spawn point: Center, high
    SpawnPoint(
      id: 'SP_sky_04',
      normalizedPos: const Offset(0.5, 0.3), // Wild center-high
      anchor: SceneLayer.layer2,
      size: Vector2(60, 60),
      battlePos: _nextTo(const Offset(0.5, 0.3)), // -> (0.80, 0.3)
    ),
    // New spawn point: Far right, foreground
    SpawnPoint(
      id: 'SP_sky_05',
      normalizedPos: const Offset(0.85, 0.75), // Wild far-right
      anchor: SceneLayer.layer3,
      size: Vector2(80, 80),
      battlePos: _nextTo(const Offset(0.85, 0.75)), // -> (0.55, 0.75)
    ),
  ],
);
