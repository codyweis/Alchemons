import 'dart:ui';

import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

final dunesScene = SceneDefinition(
  // The Dunes wrap round like the Valley: the sand floor (which scrolls at
  // twice the camera) comes round again every 2800 units, about 3.7
  // screens.
  worldWidth: 1400,
  worldHeight: 1000,
  loop: true,
  // Drawn in code (lib/games/wilderness/field/dunes_field.dart). The sky is
  // the camera's backdrop, so it has no layer; nearest moves fastest.
  art: DunesField.new,
  layers: const [
    LayerDefinition(id: SceneLayer.layer2, imagePath: '', parallaxFactor: 0.1),
    LayerDefinition(id: SceneLayer.layer3, imagePath: '', parallaxFactor: 0.35),
    LayerDefinition(id: SceneLayer.layer4, imagePath: '', parallaxFactor: 1.0),
    LayerDefinition(id: SceneLayer.layer5, imagePath: '', parallaxFactor: 1.6),
  ],
  // Every point says what holds its creature up. The points over the great
  // dunes only take creatures that can float; the dunes rise under the
  // points on them, and a rock of wind-cut sandstone stands under the high
  // point on the floor.
  //
  // x is a share of the point's own layer's loop.
  spawnPoints: [
    // in the sand, first thing in view (the tutorial's)
    SpawnPoint(
      id: 'SP_dunes_01',
      normalizedPos: const Offset(0.12, 0.80),
      anchor: SceneLayer.layer4,
      size: Vector2(100, 100),
      battlePos: const Offset(0.22, 0.80),
    ),
    // on the great dunes, first thing in view
    SpawnPoint(
      id: 'SP_dunes_02',
      normalizedPos: const Offset(0.2, 0.635),
      anchor: SceneLayer.layer3,
      size: Vector2(70, 70),
      battlePos: const Offset(0.3, 0.635),
    ),
    // in the sand, between the two pillars
    SpawnPoint(
      id: 'SP_dunes_03',
      normalizedPos: const Offset(0.38, 0.80),
      anchor: SceneLayer.layer4,
      size: Vector2(95, 95),
      battlePos: const Offset(0.28, 0.80),
    ),
    // over the great dunes, midway round
    SpawnPoint(
      id: 'SP_dunes_04',
      normalizedPos: const Offset(0.46, 0.36),
      anchor: SceneLayer.layer3,
      size: Vector2(64, 64),
      battlePos: const Offset(0.36, 0.62),
      perch: SpawnPerch.air,
    ),
    // on a rock of sandstone, high off the floor
    SpawnPoint(
      id: 'SP_dunes_05',
      normalizedPos: const Offset(0.6, 0.6),
      anchor: SceneLayer.layer4,
      size: Vector2(95, 95),
      battlePos: const Offset(0.7, 0.80),
    ),
    // on the great dunes, past the pillars
    SpawnPoint(
      id: 'SP_dunes_06',
      normalizedPos: const Offset(0.7, 0.625),
      anchor: SceneLayer.layer3,
      size: Vector2(70, 70),
      battlePos: const Offset(0.6, 0.625),
    ),
    // in the sand, late in the loop
    SpawnPoint(
      id: 'SP_dunes_07',
      normalizedPos: const Offset(0.86, 0.79),
      anchor: SceneLayer.layer4,
      size: Vector2(95, 95),
      battlePos: const Offset(0.95, 0.79),
    ),
    // high over the great dunes, late in the loop
    SpawnPoint(
      id: 'SP_dunes_08',
      normalizedPos: const Offset(0.9, 0.32),
      anchor: SceneLayer.layer3,
      size: Vector2(60, 60),
      battlePos: const Offset(0.8, 0.62),
      perch: SpawnPerch.air,
    ),
  ],
);
