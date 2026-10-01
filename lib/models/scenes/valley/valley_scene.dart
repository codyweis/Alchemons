import 'dart:ui';
import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

final valleySceneCorrected = SceneDefinition(
  // The Valley wraps round: pan either way for ever. A world width of 1400
  // makes the meadow (which scrolls at twice the camera) about 3.7 screens
  // round before it repeats.
  worldWidth: 1400,
  worldHeight: 1000,
  loop: true,
  // Drawn in code (lib/games/wilderness/field/valley_field.dart). The sky is
  // the camera's backdrop, so it has no layer; nearest moves fastest.
  art: ValleyField.new,
  layers: const [
    LayerDefinition(id: SceneLayer.layer2, imagePath: '', parallaxFactor: 0.1),
    LayerDefinition(id: SceneLayer.layer3, imagePath: '', parallaxFactor: 0.35),
    LayerDefinition(id: SceneLayer.layer4, imagePath: '', parallaxFactor: 1.0),
    LayerDefinition(id: SceneLayer.layer5, imagePath: '', parallaxFactor: 1.6),
  ],
  // Every point says what holds its creature up. The sky points only take
  // creatures that can float; the field builds something under each of the
  // others (the hill lifts under the hillside point, a boulder stands under
  // the high meadow point). Sky points sit on the hill layer, so a partner
  // that cannot float has ground beneath it.
  //
  // In a looping field x is a share of the point's own layer's loop, spread
  // round it; a battle position only says which side the partner stands
  // and at what height.
  spawnPoints: [
    // high over the hills, first thing in view
    SpawnPoint(
      id: 'SP_valley_01',
      normalizedPos: const Offset(0.18, 0.30),
      anchor: SceneLayer.layer3,
      size: Vector2(60, 60),
      battlePos: const Offset(0.28, 0.30),
      perch: SpawnPerch.air,
    ),
    // in the meadow, first thing in view (the tutorial's)
    SpawnPoint(
      id: 'SP_valley_02',
      normalizedPos: const Offset(0.12, 0.80),
      anchor: SceneLayer.layer4,
      size: Vector2(100, 100),
      battlePos: const Offset(0.22, 0.80),
    ),
    // in the meadow, before the middle great tree
    SpawnPoint(
      id: 'SP_valley_03',
      normalizedPos: const Offset(0.37, 0.80),
      anchor: SceneLayer.layer4,
      size: Vector2(100, 100),
      battlePos: const Offset(0.27, 0.80),
    ),
    // on the boulder in the meadow
    SpawnPoint(
      id: 'SP_valley_04',
      normalizedPos: const Offset(0.86, 0.50),
      anchor: SceneLayer.layer4,
      size: Vector2(100, 100),
      battlePos: const Offset(0.76, 0.50),
    ),
    // over the hills, midway round
    SpawnPoint(
      id: 'SP_valley_05',
      normalizedPos: const Offset(0.46, 0.40),
      anchor: SceneLayer.layer3,
      size: Vector2(70, 70),
      battlePos: const Offset(0.36, 0.40),
      perch: SpawnPerch.air,
    ),
    // in the meadow, before the far great tree
    SpawnPoint(
      id: 'SP_valley_06',
      normalizedPos: const Offset(0.62, 0.78),
      anchor: SceneLayer.layer4,
      size: Vector2(95, 95),
      battlePos: const Offset(0.72, 0.78),
    ),
    // on the near hill
    SpawnPoint(
      id: 'SP_valley_07',
      normalizedPos: const Offset(0.72, 0.65),
      anchor: SceneLayer.layer3,
      size: Vector2(70, 70),
      battlePos: const Offset(0.62, 0.65),
    ),
    // high over the hills, late in the loop
    SpawnPoint(
      id: 'SP_valley_08',
      normalizedPos: const Offset(0.80, 0.34),
      anchor: SceneLayer.layer3,
      size: Vector2(60, 60),
      battlePos: const Offset(0.70, 0.34),
      perch: SpawnPerch.air,
    ),
  ],
);
