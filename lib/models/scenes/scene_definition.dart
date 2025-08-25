// lib/models/scenes/scene_definition.dart
import 'package:alchemons/models/scenes/spawn_point.dart';

enum SceneLayer { layer1, layer2, layer3, layer4, layer5 }

class SceneDefinition {
  final double worldWidth;
  final double worldHeight;
  final List<LayerDefinition> layers;
  final List<SpawnPoint> spawnPoints; // ← only this

  const SceneDefinition({
    required this.worldWidth,
    required this.worldHeight,
    required this.layers,
    this.spawnPoints = const [],
  });

  SceneDefinition copyWith({
    double? worldWidth,
    double? worldHeight,
    List<LayerDefinition>? layers,
    List<SpawnPoint>? spawnPoints,
  }) {
    return SceneDefinition(
      worldWidth: worldWidth ?? this.worldWidth,
      worldHeight: worldHeight ?? this.worldHeight,
      layers: layers ?? this.layers,
      spawnPoints: spawnPoints ?? this.spawnPoints,
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
