import 'dart:ui';

import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

/// Arcane Portal scene — a void realm unlocked when all altar relics are placed.
/// Uses a solid black background. The visual backdrop is
/// provided by the AlchemicalParticleBackground widget in the scene page.
final arcaneScene = SceneDefinition(
  worldWidth: 1000,
  worldHeight: 1500,
  layers: [
    // No layer images — pure black background.
    // The ScenePage background colour (black) handles the backdrop,
    // and AlchemicalParticleBackground renders floating particles.
    const LayerDefinition(
      id: SceneLayer.layer1,
      imagePath: '',
      parallaxFactor: 0.0,
      widthMul: 1.0,
    ),
  ],
  spawnPoints: [
    SpawnPoint(
      id: 'SP_arcane_01',
      normalizedPos: const Offset(0.28, 0.58),
      anchor: SceneLayer.layer1,
      size: Vector2(80, 80),
      battlePos: const Offset(0.54, 0.58),
    ),
    SpawnPoint(
      id: 'SP_arcane_02',
      normalizedPos: const Offset(0.50, 0.58),
      anchor: SceneLayer.layer1,
      size: Vector2(80, 80),
      battlePos: const Offset(0.30, 0.58),
    ),
    SpawnPoint(
      id: 'SP_arcane_03',
      normalizedPos: const Offset(0.72, 0.58),
      anchor: SceneLayer.layer1,
      size: Vector2(80, 80),
      battlePos: const Offset(0.46, 0.58),
    ),
  ],
);
