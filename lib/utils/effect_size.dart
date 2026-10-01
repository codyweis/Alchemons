// lib/utils/effect_size.dart

import 'dart:math' as math;

/// Helpers to size an alchemy effect from the sprite it sits round: the
/// "display base" is the sprite's display box in pixels (69.0 by default)
/// multiplied by `visuals.scale`. The widgets size effects from their own
/// box instead (see AlchemyEffectView); the Flame and space hosts use these.

double displayBaseFromVisuals({
  double baseBox = 69.0,
  double visualsScale = 1.0,
}) {
  return baseBox * visualsScale;
}

double effectSizeFromDisplayBase(
  double displayBase, {
  double multiplier = 1.25,
  double minSize = 36.0,
  double maxSize = 160.0,
}) {
  return math.max(minSize, math.min(displayBase * multiplier, maxSize));
}
