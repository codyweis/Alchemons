import 'package:alchemons/models/trophy_slot.dart';

enum SceneLayer { layer1, layer2, layer3, layer4, layer5 }

class SceneDefinition {
  final double worldWidth;
  final double worldHeight;
  final List<LayerDefinition> layers;
  final List<TrophySlot> slots;

  SceneDefinition({
    required this.worldWidth,
    required this.worldHeight,
    required this.layers,
    required this.slots,
  });
}

class LayerDefinition {
  final SceneLayer id;
  final String imagePath;
  final double parallaxFactor;
  final double widthMul;

  LayerDefinition({
    required this.id,
    required this.imagePath,
    required this.parallaxFactor,
    this.widthMul = 1.0,
  });
}

extension SceneDefinitionCopy on SceneDefinition {
  SceneDefinition copyWith({List<TrophySlot>? slots}) {
    return SceneDefinition(
      worldWidth: worldWidth,
      worldHeight: worldHeight,
      layers: layers,
      slots: slots ?? this.slots,
    );
  }
}
