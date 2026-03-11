import 'dart:ui';

import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

/// Poison pathway scene: intentionally empty/void backdrop.
/// ScenePage overlays particles to create the mystical atmosphere.
final poisonScene = SceneDefinition(
  worldWidth: 1600,
  worldHeight: 1000,
  allowVerticalPan: true,
  encounterGroundBias: 0,
  encounterMinZoom: 0.85,
  encounterMaxZoom: 1.30,
  layers: [
    const LayerDefinition(
      id: SceneLayer.layer1,
      imagePath: '',
      parallaxFactor: 0.0,
      widthMul: 1.0,
    ),
  ],
  spawnPoints: [
    SpawnPoint(
      id: 'SP_poison_01',
      normalizedPos: const Offset(0.18, 0.26),
      anchor: SceneLayer.layer1,
      size: Vector2(84, 84),
      battlePos: const Offset(0.36, 0.26),
    ),
    SpawnPoint(
      id: 'SP_poison_02',
      normalizedPos: const Offset(0.32, 0.30),
      anchor: SceneLayer.layer1,
      size: Vector2(86, 86),
      battlePos: const Offset(0.50, 0.30),
    ),
    SpawnPoint(
      id: 'SP_poison_03',
      normalizedPos: const Offset(0.48, 0.28),
      anchor: SceneLayer.layer1,
      size: Vector2(84, 84),
      battlePos: const Offset(0.30, 0.28),
    ),
    SpawnPoint(
      id: 'SP_poison_04',
      normalizedPos: const Offset(0.64, 0.30),
      anchor: SceneLayer.layer1,
      size: Vector2(92, 92),
      battlePos: const Offset(0.46, 0.30),
    ),
    SpawnPoint(
      id: 'SP_poison_05',
      normalizedPos: const Offset(0.80, 0.34),
      anchor: SceneLayer.layer1,
      size: Vector2(96, 96),
      battlePos: const Offset(0.62, 0.34),
    ),
    SpawnPoint(
      id: 'SP_poison_06',
      normalizedPos: const Offset(0.28, 0.34),
      anchor: SceneLayer.layer1,
      size: Vector2(90, 90),
      battlePos: const Offset(0.46, 0.34),
    ),
    SpawnPoint(
      id: 'SP_poison_07',
      normalizedPos: const Offset(0.62, 0.36),
      anchor: SceneLayer.layer1,
      size: Vector2(96, 96),
      battlePos: const Offset(0.44, 0.36),
    ),
  ],
);
