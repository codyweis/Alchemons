import 'dart:ui';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:flame/components.dart';

class SpawnPoint {
  final String id;
  final Offset normalizedPos;
  final SceneLayer anchor;
  final Vector2 size;
  final bool enabled;

  /// Normalized position for the player's creature during battle/breeding
  /// If null, defaults to mirrored position (1.0 - normalizedPos.dx)
  final Offset? battlePos;

  const SpawnPoint({
    required this.id,
    required this.normalizedPos,
    required this.anchor,
    required this.size,
    this.enabled = true,
    this.battlePos,
  });

  /// Get the battle position, either explicit or auto-mirrored
  Offset getBattlePos() {
    if (battlePos != null) return battlePos!;
    // Mirror horizontally with some spacing
    final dx = normalizedPos.dx;
    final mirroredDx = dx < 0.5
        ? dx +
              0.3 // wild on left, party on right
        : dx - 0.3; // wild on right, party on left
    return Offset(mirroredDx, normalizedPos.dy);
  }
}
