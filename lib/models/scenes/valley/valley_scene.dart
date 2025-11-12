import 'dart:ui';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

// Updated _nextTo function with better clamping
double _clampN(double x, {double min = 0.05, double max = 0.95}) =>
    x < min ? min : (x > max ? max : x);

const double kBattleOffsetX = 0.30;

Offset _nextTo(Offset p) {
  // Ensure we don't exceed normalized bounds
  final shiftedX = p.dx <= 0.5 ? p.dx + kBattleOffsetX : p.dx - kBattleOffsetX;
  return Offset(_clampN(shiftedX, max: 1.0), _clampN(p.dy, max: 1.0));
}

final valleySceneCorrected = SceneDefinition(
  worldWidth: 1000,
  worldHeight: 1000,
  layers: [
    LayerDefinition(
      id: SceneLayer.layer1,
      imagePath: 'backgrounds/scenes/valley/sky.png',
      parallaxFactor: 0.0,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer2,
      imagePath: 'backgrounds/scenes/valley/clouds.png',
      parallaxFactor: 0.1,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer3,
      imagePath: 'backgrounds/scenes/valley/backhills.png',
      parallaxFactor: 0.35,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer4,
      imagePath: 'backgrounds/scenes/valley/hills.png',
      parallaxFactor: 1.0,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer5,
      imagePath: 'backgrounds/scenes/valley/foreground.png',
      parallaxFactor: 0.3,
      widthMul: 1.0,
    ),
  ],
  spawnPoints: [
    // left top in sky
    SpawnPoint(
      id: 'SP_valley_01',
      normalizedPos: const Offset(0.35, 0.3), // Wild left-center
      anchor: SceneLayer.layer3,
      size: Vector2(60, 60),
      battlePos: const Offset(0.65, 0.3), // ✅ Already correct!
    ),
    //front middle
    SpawnPoint(
      id: 'SP_valley_02',
      normalizedPos: const Offset(0.58, 0.80),
      anchor: SceneLayer.layer4,
      size: Vector2(100, 100),
      battlePos: _nextTo(const Offset(0.58, 0.80)), // -> (0.28, 0.80)
    ),
    //front middle right
    SpawnPoint(
      id: 'SP_valley_03',
      normalizedPos: const Offset(0.75, 0.8), // Wild on right
      anchor: SceneLayer.layer4,
      size: Vector2(100, 100),
      battlePos: const Offset(0.45, 0.8), // ✅ Already correct!
    ),
    // front infront of tree up
    SpawnPoint(
      id: 'SP_valley_04',
      normalizedPos: const Offset(0.8, 0.50), // Wild on right
      anchor: SceneLayer.layer4,
      size: Vector2(100, 100),
      battlePos: const Offset(0.50, 0.50), // ✅ Party to the LEFT
    ),
    //right in sky
    SpawnPoint(
      id: 'SP_valley_05',
      normalizedPos: const Offset(0.85, 0.4), // Wild on far right
      anchor: SceneLayer.layer2,
      size: Vector2(70, 70),
      battlePos: const Offset(0.55, 0.4), // ✅ Party to the LEFT (toward center)
    ),
    // far left front of tree
    SpawnPoint(
      id: 'SP_valley_06',
      normalizedPos: const Offset(0.2, 0.78), // Wild on left
      anchor: SceneLayer.layer4,
      size: Vector2(95, 95),
      battlePos: const Offset(0.50, 0.78), // ✅ Already correct!
    ),
    // middle in hills
    SpawnPoint(
      id: 'SP_valley_07',
      normalizedPos: const Offset(0.45, 0.65),
      anchor: SceneLayer.layer3,
      size: Vector2(70, 70),
      battlePos: _nextTo(const Offset(0.45, 0.65)), // -> (0.75, 0.65)
    ),
  ],
);
