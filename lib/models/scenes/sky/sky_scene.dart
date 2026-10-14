import 'dart:ui';
import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';

final skyScene = SceneDefinition(
  // Skyward Reach wraps round like the Valley: the near isles (which scroll
  // at twice the camera) come round again every 3200 units, about four
  // screens.
  worldWidth: 1600,
  worldHeight: 850,
  loop: true,
  // Drawn in code (lib/games/wilderness/field/sky_field.dart). The sky is
  // the camera's backdrop, so it has no layer; nearest moves fastest.
  art: SkyField.new,
  layers: const [
    LayerDefinition(id: SceneLayer.layer2, imagePath: '', parallaxFactor: 0.1),
    LayerDefinition(id: SceneLayer.layer3, imagePath: '', parallaxFactor: 0.35),
    LayerDefinition(id: SceneLayer.layer4, imagePath: '', parallaxFactor: 1.0),
    LayerDefinition(id: SceneLayer.layer5, imagePath: '', parallaxFactor: 1.6),
  ],
  // Every point says what holds its creature up. The open-air points only
  // take creatures that can float; each of the others stands on an isle the
  // field builds under it. The field also builds an isle where each point's
  // encounter partner stands (a pace to the side its battle position
  // names), so a partner that cannot float has ground too — unless another
  // creature's isle or another partner's is there already, which it stands
  // on instead. A battle position's height is where a floating partner
  // hangs, just over that isle.
  //
  // x is a share of the point's own layer's loop.
  spawnPoints: [
    // on the first isle, first thing in view (the tutorial's)
    SpawnPoint(
      id: 'SP_sky_01',
      normalizedPos: const Offset(0.09, 0.58),
      anchor: SceneLayer.layer4,
      size: Vector2(90, 90),
      battlePos: const Offset(0.19, 0.60),
    ),
    // high over the far sea, first thing in view
    SpawnPoint(
      id: 'SP_sky_02',
      normalizedPos: const Offset(0.20, 0.24),
      anchor: SceneLayer.layer3,
      size: Vector2(60, 60),
      battlePos: const Offset(0.30, 0.46),
      perch: SpawnPerch.air,
    ),
    // in the open air between the near isles
    SpawnPoint(
      id: 'SP_sky_03',
      normalizedPos: const Offset(0.30, 0.30),
      anchor: SceneLayer.layer4,
      size: Vector2(70, 70),
      battlePos: const Offset(0.40, 0.55),
      perch: SpawnPerch.air,
    ),
    // on a far isle
    SpawnPoint(
      id: 'SP_sky_04',
      normalizedPos: const Offset(0.47, 0.42),
      anchor: SceneLayer.layer3,
      size: Vector2(65, 65),
      battlePos: const Offset(0.57, 0.44),
    ),
    // on a near isle, midway round
    SpawnPoint(
      id: 'SP_sky_05',
      normalizedPos: const Offset(0.55, 0.62),
      anchor: SceneLayer.layer4,
      size: Vector2(90, 90),
      battlePos: const Offset(0.45, 0.56),
    ),
    // high over the far sea, midway round
    SpawnPoint(
      id: 'SP_sky_06',
      normalizedPos: const Offset(0.68, 0.22),
      anchor: SceneLayer.layer3,
      size: Vector2(60, 60),
      battlePos: const Offset(0.78, 0.47),
      perch: SpawnPerch.air,
    ),
    // in the open air, late in the loop
    SpawnPoint(
      id: 'SP_sky_07',
      normalizedPos: const Offset(0.80, 0.34),
      anchor: SceneLayer.layer4,
      size: Vector2(70, 70),
      battlePos: const Offset(0.90, 0.60),
      perch: SpawnPerch.air,
    ),
    // on a far isle, late in the loop
    SpawnPoint(
      id: 'SP_sky_08',
      normalizedPos: const Offset(0.90, 0.45),
      anchor: SceneLayer.layer3,
      size: Vector2(65, 65),
      battlePos: const Offset(0.96, 0.47),
    ),
    // on a near isle past the open air (SP_sky_03's partner stands on it),
    // its partner on the isle SP_sky_05's partner stands on
    SpawnPoint(
      id: 'SP_sky_09',
      normalizedPos: const Offset(0.3875, 0.55),
      anchor: SceneLayer.layer4,
      size: Vector2(85, 85),
      battlePos: const Offset(0.4875, 0.56),
    ),
    // on a near isle under the open air late in the loop, its partner on
    // the isle SP_sky_07's partner stands on
    SpawnPoint(
      id: 'SP_sky_10',
      normalizedPos: const Offset(0.80, 0.60),
      anchor: SceneLayer.layer4,
      size: Vector2(80, 80),
      battlePos: const Offset(0.90, 0.60),
    ),
    // on a far isle under the high air, first thing in view, its partner on
    // the isle SP_sky_02's partner stands on
    SpawnPoint(
      id: 'SP_sky_11',
      normalizedPos: const Offset(0.20, 0.44),
      anchor: SceneLayer.layer3,
      size: Vector2(62, 62),
      battlePos: const Offset(0.30, 0.46),
    ),
    // in the open air over the isle between SP_sky_09 and SP_sky_05, its
    // partner on SP_sky_09's isle
    SpawnPoint(
      id: 'SP_sky_12',
      normalizedPos: const Offset(0.46875, 0.25),
      anchor: SceneLayer.layer4,
      size: Vector2(70, 70),
      battlePos: const Offset(0.36875, 0.55),
      perch: SpawnPerch.air,
    ),
    // in the open air past SP_sky_05, short of the great tree, its partner
    // on SP_sky_05's isle
    SpawnPoint(
      id: 'SP_sky_13',
      normalizedPos: const Offset(0.63125, 0.40),
      anchor: SceneLayer.layer4,
      size: Vector2(70, 70),
      battlePos: const Offset(0.53125, 0.62),
      perch: SpawnPerch.air,
    ),
  ],
);
