// lib/games/sprite_effects/alchemy_effect_component.dart
//
// An alchemy effect in a Flame world: the same painter the widgets and space
// use, driven by the game's clock. Its origin is the creature's centre. An
// effect with a near side takes two: one under the sprite, one over it, on
// the same seed so they stay in step.

import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:flame/components.dart';

class AlchemyEffectComponent extends PositionComponent {
  AlchemyEffectComponent({
    required this.effectKey,
    required this.radius,
    this.element,
    this.front = false,
    double? seed,
  }) : seed = seed ?? math.Random().nextDouble() * 10;

  final String effectKey;

  /// Half the creature's drawn box.
  final double radius;

  /// The Elemental Aura's element or variant faction.
  final String? element;

  /// The layer over the sprite (see [AlchemyEffectPaint.hasFront]).
  final bool front;

  /// Where its clock starts: random, so two creatures wearing the same
  /// effect are not in step; shared by a twin layer, so the two are.
  final double seed;
  late double _t = seed;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    AlchemyEffectPaint.paint(
      canvas,
      effectKey,
      Offset.zero,
      radius,
      _t,
      element: element,
      front: front,
    );
  }
}
