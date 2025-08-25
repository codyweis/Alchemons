import 'dart:ui';

import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';

final volcanoScene = SceneDefinition(
  worldWidth: 1425,
  worldHeight: 850,
  layers: [
    // LayerDefinition(
    //   id: SceneLayer.layer1,
    //   imagePath: 'backgrounds/scenes/volcano/sky.png',
    //   parallaxFactor: 0.0,
    //   widthMul: 1.0,
    // ),
    LayerDefinition(
      id: SceneLayer.layer2,
      imagePath: 'backgrounds/scenes/volcano/background.png',
      parallaxFactor: 0.1,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer3,
      imagePath: 'backgrounds/scenes/volcano/mountains.png',
      parallaxFactor: 0.35,
      widthMul: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer4,
      imagePath: 'backgrounds/scenes/volcano/foreground.png',
      parallaxFactor: 1.0,
      widthMul: 1.0,
    ),
  ],
  spawnPoints: const [
    SpawnPoint(
      id: 'SP_volcano_01',
      normalizedPos: Offset(0.40, 0.65),
      anchor: SceneLayer.layer4,
    ),
    SpawnPoint(
      id: 'SP_volcano_02',
      normalizedPos: Offset(0.58, 0.80),
      anchor: SceneLayer.layer4,
    ),
  ],
);
