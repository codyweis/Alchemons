import 'dart:ui';

import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

final valleyScene = SceneDefinition(
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
      id: SceneLayer.layer5,
      imagePath: 'backgrounds/scenes/valley/foreground.png',
      parallaxFactor: 0.3,
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
  ],
  spawnPoints: [
    SpawnPoint(
      id: 'SP_valley_01',
      normalizedPos: const Offset(0.35, 0.65), // Wild creature on left
      anchor: SceneLayer.layer3,
      size: Vector2(100, 100),
      battlePos: const Offset(0.65, 0.65), // Party creature on right
    ),
    SpawnPoint(
      id: 'SP_valley_02',
      normalizedPos: const Offset(0.58, 0.80), // Wild creature right-center
      anchor: SceneLayer.layer4,
      size: Vector2(100, 100),
      battlePos: const Offset(0.28, 0.80), // Party creature left-center
    ),
  ],
);
