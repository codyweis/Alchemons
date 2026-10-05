import 'dart:ui';

import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

final tidalScene = SceneDefinition(
  // The Tidal Shelf wraps round like the Valley: the shelf (which scrolls at
  // twice the camera) comes round again every 2800 units.
  worldWidth: 1400,
  worldHeight: 1000,
  loop: true,
  // Drawn in code (lib/games/wilderness/field/tidal_field.dart). The sky is
  // the camera's backdrop; the sea runs to its horizon.
  art: TidalField.new,
  layers: const [
    LayerDefinition(id: SceneLayer.layer2, imagePath: '', parallaxFactor: 0.1),
    LayerDefinition(id: SceneLayer.layer3, imagePath: '', parallaxFactor: 0.35),
    LayerDefinition(id: SceneLayer.layer4, imagePath: '', parallaxFactor: 1.0),
    LayerDefinition(id: SceneLayer.layer5, imagePath: '', parallaxFactor: 1.6),
  ],
  // Every point says what holds its creature up. The two over the sea only
  // take creatures that can float, the two in it only Water ones; every other stands on a stand of basalt
  // columns built at its feet — on the reef, or on the shelf over the flat
  // the tide comes and goes on — and so does each one's encounter partner.
  //
  // x is a share of the point's own layer's loop.
  spawnPoints: [
    // on the shelf, first thing in view (the tutorial's)
    SpawnPoint(
      id: 'SP_tidal_01',
      normalizedPos: const Offset(0.12, 0.80),
      anchor: SceneLayer.layer4,
      size: Vector2(100, 100),
      battlePos: const Offset(0.22, 0.80),
    ),
    // on the reef, first thing in view
    SpawnPoint(
      id: 'SP_tidal_02',
      normalizedPos: const Offset(0.2, 0.635),
      anchor: SceneLayer.layer3,
      size: Vector2(70, 70),
      battlePos: const Offset(0.3, 0.635),
    ),
    // on the shelf, before the pools
    SpawnPoint(
      id: 'SP_tidal_03',
      normalizedPos: const Offset(0.38, 0.80),
      anchor: SceneLayer.layer4,
      size: Vector2(95, 95),
      battlePos: const Offset(0.28, 0.80),
    ),
    // over the sea, midway round
    SpawnPoint(
      id: 'SP_tidal_04',
      normalizedPos: const Offset(0.44, 0.36),
      anchor: SceneLayer.layer3,
      size: Vector2(64, 64),
      battlePos: const Offset(0.34, 0.62),
      perch: SpawnPerch.air,
    ),
    // on a tall stand of columns, high off the flat
    SpawnPoint(
      id: 'SP_tidal_05',
      normalizedPos: const Offset(0.6, 0.6),
      anchor: SceneLayer.layer4,
      size: Vector2(95, 95),
      battlePos: const Offset(0.66, 0.80),
    ),
    // on the reef, past the stacks
    SpawnPoint(
      id: 'SP_tidal_06',
      normalizedPos: const Offset(0.68, 0.625),
      anchor: SceneLayer.layer3,
      size: Vector2(70, 70),
      battlePos: const Offset(0.58, 0.625),
    ),
    // on the shelf, late in the loop
    SpawnPoint(
      id: 'SP_tidal_07',
      normalizedPos: const Offset(0.84, 0.79),
      anchor: SceneLayer.layer4,
      size: Vector2(95, 95),
      battlePos: const Offset(0.8, 0.79),
    ),
    // over the sea, late in the loop
    SpawnPoint(
      id: 'SP_tidal_08',
      normalizedPos: const Offset(0.9, 0.32),
      anchor: SceneLayer.layer3,
      size: Vector2(60, 60),
      battlePos: const Offset(0.8, 0.62),
      perch: SpawnPerch.air,
    ),
    // Out in the sea between the reef's rocks: only a Water creature,
    // swimming, the sea over its lower half. Its partner gets a rock.
    SpawnPoint(
      id: 'SP_tidal_09',
      normalizedPos: const Offset(0.26, 0.69),
      anchor: SceneLayer.layer3,
      size: Vector2(76, 76),
      battlePos: const Offset(0.36, 0.62),
      perch: SpawnPerch.wade,
    ),
    SpawnPoint(
      id: 'SP_tidal_10',
      normalizedPos: const Offset(0.62, 0.655),
      anchor: SceneLayer.layer3,
      size: Vector2(62, 62),
      battlePos: const Offset(0.52, 0.62),
      perch: SpawnPerch.wade,
    ),
  ],
);
