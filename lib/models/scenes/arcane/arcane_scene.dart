import 'dart:ui';

import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

/// Arcane Portal scene — the void behind the portal, unlocked when all the
/// altar relics are placed.
final arcaneScene = SceneDefinition(
  // The Arcane wraps round like the other fields: the near ground (which
  // scrolls at twice the camera) comes round again every 2000 units, under
  // three screens.
  worldWidth: 1000,
  worldHeight: 850,
  loop: true,
  // Drawn in code (lib/games/wilderness/field/arcane_field.dart). The void
  // is the camera's backdrop, so it has no layer; nearest moves fastest.
  art: ArcaneField.new,
  layers: const [
    LayerDefinition(id: SceneLayer.layer2, imagePath: '', parallaxFactor: 0.1),
    LayerDefinition(id: SceneLayer.layer3, imagePath: '', parallaxFactor: 0.35),
    LayerDefinition(id: SceneLayer.layer4, imagePath: '', parallaxFactor: 1.0),
  ],
  // Every point stands on the glass, which runs out to the dust band under
  // every creature and every encounter's partner alike. There is no
  // open-air point: the glass gives back what stands on it, mirrored about
  // its feet, so a creature hung in the void would have its image hung
  // there too. Its floaters — the legendary wings and the Spirits — stand
  // on the glass with the rest.
  //
  // x is a share of the point's own layer's loop.
  spawnPoints: [
    // near, first thing in view
    SpawnPoint(
      id: 'SP_arcane_01',
      normalizedPos: const Offset(0.14, 0.70),
      anchor: SceneLayer.layer4,
      size: Vector2(80, 80),
      battlePos: const Offset(0.24, 0.70),
    ),
    // far off, midway along
    SpawnPoint(
      id: 'SP_arcane_02',
      normalizedPos: const Offset(0.47, 0.575),
      anchor: SceneLayer.layer3,
      size: Vector2(66, 66),
      battlePos: const Offset(0.37, 0.575),
    ),
    // near, past the halfway point
    SpawnPoint(
      id: 'SP_arcane_03',
      normalizedPos: const Offset(0.64, 0.71),
      anchor: SceneLayer.layer4,
      size: Vector2(80, 80),
      battlePos: const Offset(0.54, 0.71),
    ),
    // near, short of the middle stone
    SpawnPoint(
      id: 'SP_arcane_04',
      normalizedPos: const Offset(0.36, 0.70),
      anchor: SceneLayer.layer4,
      size: Vector2(80, 80),
      battlePos: const Offset(0.26, 0.70),
    ),
    // near, short of the great stone, late in the loop
    SpawnPoint(
      id: 'SP_arcane_05',
      normalizedPos: const Offset(0.87, 0.70),
      anchor: SceneLayer.layer4,
      size: Vector2(80, 80),
      battlePos: const Offset(0.77, 0.70),
    ),
    // far off, early in the loop
    SpawnPoint(
      id: 'SP_arcane_06',
      normalizedPos: const Offset(0.25, 0.58),
      anchor: SceneLayer.layer3,
      size: Vector2(64, 64),
      battlePos: const Offset(0.15, 0.58),
    ),
    // far off, late in the loop
    SpawnPoint(
      id: 'SP_arcane_07',
      normalizedPos: const Offset(0.76, 0.57),
      anchor: SceneLayer.layer3,
      size: Vector2(66, 66),
      battlePos: const Offset(0.86, 0.57),
    ),
  ],
);
