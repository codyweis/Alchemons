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
  // In SpawnPoint class, update getBattlePos():
  Offset getBattlePos() {
    if (battlePos != null) return battlePos!;

    // Auto-calculate: place party creature toward CENTER from wild
    final wx = normalizedPos.dx;
    final wy = normalizedPos.dy;

    // Distance to spawn party (in normalized units)
    const separation = 0.30; // 30% of world width apart

    // If wild is on RIGHT side (>0.6), put party on LEFT
    // If wild is on LEFT side (<0.4), put party on RIGHT
    // If wild is CENTER, default to left side of wild
    double px;
    if (wx > 0.6) {
      // Wild is right, party goes left (toward center)
      px = (wx - separation).clamp(0.08, 0.92);
    } else if (wx < 0.4) {
      // Wild is left, party goes right (toward center)
      px = (wx + separation).clamp(0.08, 0.92);
    } else {
      // Wild is center, party goes left by default
      px = (wx - separation).clamp(0.08, 0.92);
    }

    // Keep Y the same (both creatures on same ground level)
    final py = wy.clamp(0.08, 0.92);

    return Offset(px, py);
  }
}
