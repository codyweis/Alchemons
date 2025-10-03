import 'dart:ui';

import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

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
    SpawnPoint(
      id: 'SP_volcano_01',
      normalizedPos: const Offset(0.40, 0.65),
      anchor: SceneLayer.layer3,
      size: Vector2(80, 80),
    ),
  ],
);
