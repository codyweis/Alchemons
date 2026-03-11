// lib/models/scenes/scene_definition.dart
import 'package:alchemons/models/scenes/spawn_point.dart';

enum SceneLayer { layer1, layer2, layer3, layer4, layer5 }

class SceneDefinition {
  final double worldWidth;
  final double worldHeight;
  final List<LayerDefinition> layers;
  final List<SpawnPoint> spawnPoints; // ← only this
  final bool allowVerticalPan;
  final double encounterGroundBias;
  final double encounterMinZoom;
  final double encounterMaxZoom;

  const SceneDefinition({
    required this.worldWidth,
    required this.worldHeight,
    required this.layers,
    this.spawnPoints = const [],
    this.allowVerticalPan = true,
    this.encounterGroundBias = 60.0,
    this.encounterMinZoom = 0.9,
    this.encounterMaxZoom = 1.55,
  });

  SceneDefinition copyWith({
    double? worldWidth,
    double? worldHeight,
    List<LayerDefinition>? layers,
    List<SpawnPoint>? spawnPoints,
    bool? allowVerticalPan,
    double? encounterGroundBias,
    double? encounterMinZoom,
    double? encounterMaxZoom,
  }) {
    return SceneDefinition(
      worldWidth: worldWidth ?? this.worldWidth,
      worldHeight: worldHeight ?? this.worldHeight,
      layers: layers ?? this.layers,
      spawnPoints: spawnPoints ?? this.spawnPoints,
      allowVerticalPan: allowVerticalPan ?? this.allowVerticalPan,
      encounterGroundBias: encounterGroundBias ?? this.encounterGroundBias,
      encounterMinZoom: encounterMinZoom ?? this.encounterMinZoom,
      encounterMaxZoom: encounterMaxZoom ?? this.encounterMaxZoom,
    );
  }
}

class LayerDefinition {
  final SceneLayer id;
  final String imagePath;
  final double parallaxFactor;
  final double widthMul;

  const LayerDefinition({
    required this.id,
    required this.imagePath,
    required this.parallaxFactor,
    this.widthMul = 1.0,
  });
}
