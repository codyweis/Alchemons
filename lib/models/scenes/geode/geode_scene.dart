import 'dart:ui';

import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

final geodeScene = SceneDefinition(
  // Geode Hollow wraps round like the Valley: the floor (which scrolls at
  // twice the camera) comes round again every 2800 units.
  worldWidth: 1400,
  worldHeight: 1000,
  loop: true,
  // Drawn in code (lib/games/wilderness/field/geode_field.dart). The sky is
  // the camera's backdrop, seen only through the cracks in the roof.
  art: GeodeField.new,
  layers: const [
    LayerDefinition(id: SceneLayer.layer2, imagePath: '', parallaxFactor: 0.1),
    LayerDefinition(id: SceneLayer.layer3, imagePath: '', parallaxFactor: 0.35),
    LayerDefinition(id: SceneLayer.layer4, imagePath: '', parallaxFactor: 1.0),
    LayerDefinition(id: SceneLayer.layer5, imagePath: '', parallaxFactor: 1.6),
  ],
  // Every point says what holds its creature up. The two in the air under
  // the roof only take creatures that can float; the ledge rises under the
  // points on it, and a split geode stands under the high point on the
  // floor.
  //
  // x is a share of the point's own layer's loop.
  spawnPoints: [
    // on the floor, first thing in view (the tutorial's)
    SpawnPoint(
      id: 'SP_geode_01',
      normalizedPos: const Offset(0.12, 0.80),
      anchor: SceneLayer.layer4,
      size: Vector2(100, 100),
      battlePos: const Offset(0.22, 0.80),
    ),
    // on the ledge, first thing in view
    SpawnPoint(
      id: 'SP_geode_02',
      normalizedPos: const Offset(0.2, 0.635),
      anchor: SceneLayer.layer3,
      size: Vector2(70, 70),
      battlePos: const Offset(0.3, 0.635),
    ),
    // on the floor, before the quartz
    SpawnPoint(
      id: 'SP_geode_03',
      normalizedPos: const Offset(0.38, 0.80),
      anchor: SceneLayer.layer4,
      size: Vector2(95, 95),
      battlePos: const Offset(0.28, 0.80),
    ),
    // in the air under the roof, midway round
    SpawnPoint(
      id: 'SP_geode_04',
      normalizedPos: const Offset(0.44, 0.42),
      anchor: SceneLayer.layer3,
      size: Vector2(64, 64),
      battlePos: const Offset(0.34, 0.62),
      perch: SpawnPerch.air,
    ),
    // on a split geode, high off the floor
    SpawnPoint(
      id: 'SP_geode_05',
      normalizedPos: const Offset(0.6, 0.6),
      anchor: SceneLayer.layer4,
      size: Vector2(95, 95),
      battlePos: const Offset(0.66, 0.80),
    ),
    // on the ledge, past the ice
    SpawnPoint(
      id: 'SP_geode_06',
      normalizedPos: const Offset(0.68, 0.625),
      anchor: SceneLayer.layer3,
      size: Vector2(70, 70),
      battlePos: const Offset(0.58, 0.625),
    ),
    // on the floor, late in the loop
    SpawnPoint(
      id: 'SP_geode_07',
      normalizedPos: const Offset(0.84, 0.79),
      anchor: SceneLayer.layer4,
      size: Vector2(95, 95),
      battlePos: const Offset(0.8, 0.79),
    ),
    // in the air under the roof, late in the loop
    SpawnPoint(
      id: 'SP_geode_08',
      normalizedPos: const Offset(0.9, 0.4),
      anchor: SceneLayer.layer3,
      size: Vector2(60, 60),
      battlePos: const Offset(0.8, 0.62),
      perch: SpawnPerch.air,
    ),
  ],
);
