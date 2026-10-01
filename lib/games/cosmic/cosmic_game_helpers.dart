part of 'cosmic_game.dart';

enum _ContestCinematicMode { beauty, speed, strength, intelligence }

double _cosmicEffectRadius({
  required double spriteScale,
  required double baseSpriteSize,
  double multiplier = 1.0,
  double minRadius = 10.0,
  double maxRadius = 38.0,
}) {
  final displayBase = baseSpriteSize * spriteScale;
  final effectDiameter = effectSizeFromDisplayBase(
    displayBase,
    multiplier: multiplier,
    minSize: minRadius * 2,
    maxSize: maxRadius * 2,
  );
  return effectDiameter * 0.5;
}

void _drawAlchemyEffectCanvas({
  required Canvas canvas,
  required String effect,
  required double spriteScale,
  required double baseSpriteSize,
  required String? auraElement,
  required double elapsed,
  required double opacity,
  bool front = false,
}) {
  // Only an effect with a near side draws over the sprite.
  if (front && !AlchemyEffectPaint.hasFront(effect)) return;
  final effectRadius = _cosmicEffectRadius(
    spriteScale: spriteScale,
    baseSpriteSize: baseSpriteSize,
  );
  // One painter, shared with the widgets and Flame.
  AlchemyEffectPaint.paint(
    canvas,
    effect,
    Offset.zero,
    effectRadius,
    elapsed,
    element: auraElement,
    opacity: opacity,
    front: front,
  );
}
