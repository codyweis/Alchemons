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
  // three screens — it has only three creatures to show.
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
  // Spirit, Dark, Light, Blood and Crystal don't float, and the only
  // floaters the Arcane rolls are its legendary wings — an open-air point
  // would roll nothing else — so every point stands on the glass, which
  // runs out to the dust band under every creature and every encounter's
  // partner alike.
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
  ],
);
