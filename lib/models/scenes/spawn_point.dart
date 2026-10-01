import 'dart:ui';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:flame/components.dart';

/// What a spawn point's creature is held up by.
enum SpawnPerch {
  /// Standing on something: ground, a slope, a rock. Anything may spawn.
  ground,

  /// In the open air. Only a creature that can fly or float may spawn here
  /// (see [speciesCanFloat]).
  air,
}

/// Whether a species may be shown in the air rather than standing on
/// something: anything with wings, and the elements of the air — Air, Steam
/// and Lightning (wind, vapour and the storm). Species ids are a family
/// code and an element number, `WNG04`.
bool speciesCanFloat(String speciesId) {
  if (speciesId.startsWith('WNG')) return true;
  final m = RegExp(r'^[A-Z]{3}(\d{2})').firstMatch(speciesId);
  if (m == null) return false;
  final element = int.parse(m.group(1)!);
  return element == 4 || element == 5 || element == 7;
}

class SpawnPoint {
  final String id;
  final Offset normalizedPos;
  final SceneLayer anchor;
  final Vector2 size;
  final bool enabled;

  /// What holds the creature up; an [SpawnPerch.air] point only ever rolls
  /// creatures that can float.
  final SpawnPerch perch;

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
    this.perch = SpawnPerch.ground,
  });

  bool get aloft => perch == SpawnPerch.air;

  /// Which side of the wild creature its encounter partner stands in a
  /// field that loops: 1 to the right, -1 to the left.
  double get partnerSide => getBattlePos().dx >= normalizedPos.dx ? 1.0 : -1.0;

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
