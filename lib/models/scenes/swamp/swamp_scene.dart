import 'dart:ui';

import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';

final swampScene = SceneDefinition(
  worldWidth: 3000,
  worldHeight: 1000,
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
      parallaxFactor: 0.35,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer4,
      imagePath: 'backgrounds/scenes/swamp/fronttrees.png',
      parallaxFactor: .8,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer5,
      imagePath: 'backgrounds/scenes/swamp/foreground.png',
      parallaxFactor: 0.3,
      widthMul: 1.0,
    ),
  ],
  spawnPoints: const [
    SpawnPoint(
      id: 'SP_swamp_01',
      normalizedPos: Offset(0.40, 0.65),
      anchor: SceneLayer.layer3,
    ),
    SpawnPoint(
      id: 'SP_swamp_02',
      normalizedPos: Offset(0.58, 0.80),
      anchor: SceneLayer.layer4,
    ),
  ],
);
