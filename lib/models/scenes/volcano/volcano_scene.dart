import 'dart:ui';

import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

final volcanoScene = SceneDefinition(
  // The Volcano wraps round like the Valley: the near lava field (which
  // scrolls at twice the camera) comes round again every 3000 units, about
  // four screens.
  worldWidth: 1500,
  worldHeight: 850,
  loop: true,
  // Drawn in code (lib/games/wilderness/field/volcano_field.dart). The sky
  // is the camera's backdrop, so it has no layer; nearest moves fastest.
  art: VolcanoField.new,
  // The cone's moods, visit by visit: quiet twice, smoking twice, then it
  // erupts — and round again.
  stages: const [
    VolcanoField.still,
    VolcanoField.still,
    VolcanoField.smoking,
    VolcanoField.smoking,
    VolcanoField.erupting,
  ],
  layers: const [
    LayerDefinition(id: SceneLayer.layer2, imagePath: '', parallaxFactor: 0.1),
    LayerDefinition(id: SceneLayer.layer3, imagePath: '', parallaxFactor: 0.35),
    LayerDefinition(id: SceneLayer.layer4, imagePath: '', parallaxFactor: 1.0),
    LayerDefinition(id: SceneLayer.layer5, imagePath: '', parallaxFactor: 1.6),
  ],
  // Every point says what holds its creature up. The ash perch over the
  // steam vent only takes creatures that can float; the field builds a
  // shelf of basalt or a bank of cinder under each of the others, and one
  // where each point's encounter partner stands (a pace to the side its
  // battle position names), so a partner that cannot float has rock too —
  // unless another creature's rock or another partner's is there already,
  // which it stands on instead. Only Lava Alchemons stand in the lava, in
  // the pools of it open at the two lava points.
  //
  // x is a share of the point's own layer's loop.
  spawnPoints: [
    // on basalt, first thing in view (the tutorial's)
    SpawnPoint(
      id: 'SP_volcano_02',
      normalizedPos: const Offset(0.12, 0.70),
      anchor: SceneLayer.layer4,
      size: Vector2(85, 85),
      battlePos: const Offset(0.22, 0.70),
    ),
    // on basalt past the second dead tree
    SpawnPoint(
      id: 'SP_volcano_01',
      normalizedPos: const Offset(0.35, 0.70),
      anchor: SceneLayer.layer4,
      size: Vector2(90, 90),
      battlePos: const Offset(0.45, 0.70),
    ),
    // the airborne ash perch: in the steam over the vent, midway round
    SpawnPoint(
      id: 'SP_volcano_03',
      normalizedPos: const Offset(0.52, 0.40),
      anchor: SceneLayer.layer4,
      size: Vector2(72, 72),
      battlePos: const Offset(0.62, 0.68),
      perch: SpawnPerch.air,
    ),
    // on basalt late in the loop
    SpawnPoint(
      id: 'SP_volcano_04',
      normalizedPos: const Offset(0.72, 0.70),
      anchor: SceneLayer.layer4,
      size: Vector2(80, 80),
      battlePos: const Offset(0.82, 0.70),
    ),
    // on a bank of cinder, last before the loop comes round
    SpawnPoint(
      id: 'SP_volcano_06',
      normalizedPos: const Offset(0.88, 0.71),
      anchor: SceneLayer.layer4,
      size: Vector2(88, 88),
      battlePos: const Offset(0.95, 0.70),
    ),
    // on basalt in the lava lake, first thing in view
    SpawnPoint(
      id: 'SP_volcano_05',
      normalizedPos: const Offset(0.22, 0.575),
      anchor: SceneLayer.layer3,
      size: Vector2(66, 66),
      battlePos: const Offset(0.32, 0.575),
    ),
    // on basalt in the lake, midway round
    SpawnPoint(
      id: 'SP_volcano_07',
      normalizedPos: const Offset(0.52, 0.565),
      anchor: SceneLayer.layer3,
      size: Vector2(64, 64),
      battlePos: const Offset(0.62, 0.565),
    ),
    // on basalt in the lake, late in the loop
    SpawnPoint(
      id: 'SP_volcano_08',
      normalizedPos: const Offset(0.80, 0.58),
      anchor: SceneLayer.layer3,
      size: Vector2(66, 66),
      battlePos: const Offset(0.88, 0.57),
    ),
    // on a bank of cinder where SP_volcano_02's partner stands, and each
    // one's partner on the other's rock
    SpawnPoint(
      id: 'SP_volcano_09',
      normalizedPos: const Offset(0.2067, 0.70),
      anchor: SceneLayer.layer4,
      size: Vector2(85, 85),
      battlePos: const Offset(0.1067, 0.70),
    ),
    // on a bank of cinder where SP_volcano_01's partner stands, and each
    // one's partner on the other's rock
    SpawnPoint(
      id: 'SP_volcano_10',
      normalizedPos: const Offset(0.4367, 0.70),
      anchor: SceneLayer.layer4,
      size: Vector2(90, 90),
      battlePos: const Offset(0.3367, 0.70),
    ),
    // on a bank of cinder in the lake where SP_volcano_05's partner stands,
    // and each one's partner on the other's rock
    SpawnPoint(
      id: 'SP_volcano_11',
      normalizedPos: const Offset(0.3484, 0.575),
      anchor: SceneLayer.layer3,
      size: Vector2(66, 66),
      battlePos: const Offset(0.2484, 0.575),
    ),
    // on a bank of cinder in the lake where SP_volcano_07's partner stands,
    // and each one's partner on the other's rock
    SpawnPoint(
      id: 'SP_volcano_12',
      normalizedPos: const Offset(0.6484, 0.565),
      anchor: SceneLayer.layer3,
      size: Vector2(64, 64),
      battlePos: const Offset(0.5484, 0.565),
    ),
    // standing in a pool of open lava short of SP_volcano_01's shelf, its
    // partner on that shelf
    SpawnPoint(
      id: 'SP_volcano_13',
      normalizedPos: const Offset(0.2633, 0.83),
      anchor: SceneLayer.layer4,
      size: Vector2(80, 80),
      battlePos: const Offset(0.3633, 0.70),
      perch: SpawnPerch.lava,
    ),
    // standing in a pool of open lava short of SP_volcano_04's shelf, its
    // partner on that shelf
    SpawnPoint(
      id: 'SP_volcano_14',
      normalizedPos: const Offset(0.6333, 0.83),
      anchor: SceneLayer.layer4,
      size: Vector2(80, 80),
      battlePos: const Offset(0.7333, 0.70),
      perch: SpawnPerch.lava,
    ),
  ],
);
