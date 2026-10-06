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

/// A worn family costume over [sprite], just drawn centred on the origin
/// in the same transform (its turn and scale), at frame [index]'s fit.
void _drawCostumeOnSprite(
  Canvas canvas,
  String? effect,
  Sprite sprite,
  int index,
  double elapsed,
  double opacity,
) {
  CostumePaint.paintWorn(
    canvas,
    effect,
    Rect.fromCenter(
      center: Offset.zero,
      width: sprite.srcSize.x,
      height: sprite.srcSize.y,
    ),
    index,
    elapsed,
    opacity: opacity,
  );
}

/// One side of Darklet's galaxy ring about [sprite], centred on the origin
/// in the same transform; nothing for any other sprite.
void _drawDarkletRing(
  Canvas canvas,
  Sprite sprite,
  int index,
  double elapsed,
  double opacity, {
  required bool front,
}) {
  if (!DarkletRing.matches(sprite.srcSize.x, sprite.srcSize.y)) return;
  DarkletRing.paint(
    canvas,
    Rect.fromCenter(
      center: Offset.zero,
      width: sprite.srcSize.x,
      height: sprite.srcSize.y,
    ),
    index,
    elapsed,
    front: front,
    opacity: opacity,
  );
}
