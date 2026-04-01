import 'dart:ui';

import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

final volcanoScene = SceneDefinition(
  worldWidth: 1500,
  worldHeight: 850,
  layers: [
    LayerDefinition(
      id: SceneLayer.layer1,
      imagePath: 'backgrounds/scenes/volcano/background.png',
      parallaxFactor: 0.0,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer2,
      imagePath: 'backgrounds/scenes/volcano/volcano.png',
      parallaxFactor: 0.1,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer3,
      imagePath: 'backgrounds/scenes/volcano/midground.png',
      parallaxFactor: 0.4,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer4,
      imagePath: 'backgrounds/scenes/volcano/foreground.png',
      parallaxFactor: 0.7,
      widthMul: 1.0,
    ),
  ],
  spawnPoints: [
    SpawnPoint(
      id: 'SP_volcano_01',
      normalizedPos: const Offset(0.24, 0.72),
      anchor: SceneLayer.layer4,
      size: Vector2(80, 80),
      battlePos: const Offset(0.54, 0.72),
    ),
    SpawnPoint(
      id: 'SP_volcano_02',
      normalizedPos: const Offset(0.60, 0.78),
      anchor: SceneLayer.layer4,
      size: Vector2(80, 80),
      battlePos: const Offset(0.34, 0.78),
    ),
    // airborne ash perch above the lava shelf for wings/floating mons
    SpawnPoint(
      id: 'SP_volcano_03',
      normalizedPos: const Offset(0.72, 0.58),
      anchor: SceneLayer.layer3,
      size: Vector2(72, 72),
      battlePos: const Offset(0.44, 0.58),
    ),
  ],
);
