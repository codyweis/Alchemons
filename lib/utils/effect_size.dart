// lib/utils/effect_size.dart

import 'dart:math' as math;

/// Helpers to compute consistent visual effect sizes.
///
/// Two common contexts:
/// - "display base": the canonical sprite display box in pixels (69.0 by default)
///   multiplied by `visuals.scale`.
/// - "widget size": when callers only know their UI slot size (e.g. shop preview)
///
/// The functions here centralize clamping and multipliers so effects look
/// consistent across screens.

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

/// When callers only have a widget slot size (e.g. shop preview `size`), use
/// this to derive a reasonable effect size. This preserves previous behaviour
/// of smaller previews while still clamping extremes.
double effectSizeFromWidgetSize(
  double widgetSize, {
  double multiplier = 0.6,
  double minSize = 24.0,
  double maxSize = 160.0,
}) {
  return math.max(minSize, math.min(widgetSize * multiplier, maxSize));
}
