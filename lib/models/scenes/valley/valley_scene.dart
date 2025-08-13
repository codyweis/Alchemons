import 'dart:ui';

import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/trophy_slot.dart';

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
  slots: [
    TrophySlot(
      id: 'CR045',
      normalizedPos: const Offset(0.4, 0.65),
      isUnlocked: true,
      spritePath: 'creatures/rare/CR045_lightmane_spritesheet.png',
      displayName: 'LightMane',
      rarity: 'Rare',
      anchor: SceneLayer.layer3,
      frameWidth: 35,
      frameHeight: 35,
      sheetColumns: 2,
      sheetRows: 2,
      imagePath: 'creatures/rare/CR045_lightmane.png',
    ),
    TrophySlot(
      id: 'CR046',
      normalizedPos: const Offset(0.58, 0.8),
      isUnlocked: true,
      spritePath: 'creatures/rare/CR046_darkmane_spritesheet.png',
      displayName: 'DarkMane',
      rarity: 'Rare',
      anchor: SceneLayer.layer4,
      frameWidth: 80,
      frameHeight: 80,
      sheetColumns: 2,
      sheetRows: 3,
      imagePath: 'creatures/rare/CR046_darkmane.png',
    ),
  ],
);
