import 'dart:ui';

import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

final swampScene = SceneDefinition(
  worldWidth: 1000,
  worldHeight: 1500,
  layers: [
    LayerDefinition(
      id: SceneLayer.layer1,
      imagePath: 'backgrounds/scenes/swamp/sky.png',
      parallaxFactor: 0.0,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer2,
      imagePath: 'backgrounds/scenes/swamp/background.png',
      parallaxFactor: 0.1,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer3,
      imagePath: 'backgrounds/scenes/swamp/backtrees.png',
      parallaxFactor: 0.2,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer4,
      imagePath: 'backgrounds/scenes/swamp/fronttrees.png',
      parallaxFactor: .5,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer5,
      imagePath: 'backgrounds/scenes/swamp/foreground.png',
      parallaxFactor: 1,
      widthMul: 1.0,
    ),
  ],
  spawnPoints: [
    SpawnPoint(
      id: 'SP_swamp_01',
      normalizedPos: const Offset(0.50, 0.65),
      anchor: SceneLayer.layer5,
      size: Vector2(80, 80),
    ),
    SpawnPoint(
      id: 'SP_swamp_02',
      normalizedPos: const Offset(0.35, 0.30),
      anchor: SceneLayer.layer3,
      size: Vector2(80, 80),
    ),
  ],
);
