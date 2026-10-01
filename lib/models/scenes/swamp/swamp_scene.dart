import 'dart:ui';

import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

final swampScene = SceneDefinition(
  // The Swamp wraps round like the Valley: the near water (which scrolls at
  // twice the camera) comes round again every 2800 units, about four
  // screens.
  worldWidth: 1400,
  worldHeight: 1000,
  loop: true,
  // Drawn in code (lib/games/wilderness/field/swamp_field.dart). The sky is
  // the camera's backdrop, so it has no layer; nearest moves fastest.
  art: SwampField.new,
  layers: const [
    LayerDefinition(id: SceneLayer.layer2, imagePath: '', parallaxFactor: 0.1),
    LayerDefinition(id: SceneLayer.layer3, imagePath: '', parallaxFactor: 0.35),
    LayerDefinition(id: SceneLayer.layer4, imagePath: '', parallaxFactor: 1.0),
    LayerDefinition(id: SceneLayer.layer5, imagePath: '', parallaxFactor: 1.6),
  ],
  // Every point says what holds its creature up. The marsh pocket over the
  // open water only takes creatures that can float; the field builds a
  // stone or a bank of peat under each of the others, and one where each
  // point's encounter partner stands (a pace to the side its battle
  // position names), so a partner that cannot float has ground too. Nothing
  // stands on the water.
  //
  // x is a share of the point's own layer's loop.
  spawnPoints: [
    // on a stone, first thing in view (the tutorial's)
    SpawnPoint(
      id: 'SP_swamp_01',
      normalizedPos: const Offset(0.10, 0.68),
      anchor: SceneLayer.layer4,
      size: Vector2(90, 90),
      battlePos: const Offset(0.20, 0.68),
    ),
    // on a bank of peat past the first great cypress
    SpawnPoint(
      id: 'SP_swamp_02',
      normalizedPos: const Offset(0.31, 0.69),
      anchor: SceneLayer.layer4,
      size: Vector2(95, 95),
      battlePos: const Offset(0.41, 0.68),
    ),
    // the marsh pocket: over the open water by the second great cypress
    SpawnPoint(
      id: 'SP_swamp_03',
      normalizedPos: const Offset(0.475, 0.36),
      anchor: SceneLayer.layer4,
      size: Vector2(72, 72),
      battlePos: const Offset(0.57, 0.66),
      perch: SpawnPerch.air,
    ),
    // on a stone midway round
    SpawnPoint(
      id: 'SP_swamp_04',
      normalizedPos: const Offset(0.665, 0.68),
      anchor: SceneLayer.layer4,
      size: Vector2(100, 100),
      battlePos: const Offset(0.765, 0.68),
    ),
    // on a stone among the back cypresses, first thing in view
    SpawnPoint(
      id: 'SP_swamp_05',
      normalizedPos: const Offset(0.20, 0.575),
      anchor: SceneLayer.layer3,
      size: Vector2(66, 66),
      battlePos: const Offset(0.30, 0.575),
    ),
    // on a bank of peat late in the loop
    SpawnPoint(
      id: 'SP_swamp_06',
      normalizedPos: const Offset(0.86, 0.70),
      anchor: SceneLayer.layer4,
      size: Vector2(90, 90),
      battlePos: const Offset(0.89, 0.69),
    ),
    // on a bank of peat among the back cypresses, midway round
    SpawnPoint(
      id: 'SP_swamp_07',
      normalizedPos: const Offset(0.52, 0.565),
      anchor: SceneLayer.layer3,
      size: Vector2(64, 64),
      battlePos: const Offset(0.62, 0.565),
    ),
    // on a stone among the back cypresses, late in the loop
    SpawnPoint(
      id: 'SP_swamp_08',
      normalizedPos: const Offset(0.80, 0.58),
      anchor: SceneLayer.layer3,
      size: Vector2(66, 66),
      battlePos: const Offset(0.86, 0.57),
    ),
  ],
);
