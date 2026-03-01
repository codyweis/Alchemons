// lib/components/sprite_effects/alchemy_glow_component.dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class AlchemyGlowComponent extends PositionComponent {
  final double baseSize;
  late final CircleComponent _glow1;
  late final CircleComponent _glow2;
  double _time = 0;

  AlchemyGlowComponent({required this.baseSize});

  @override
  Future<void> onLoad() async {
    size = Vector2.all(baseSize * 2); // Larger than sprite for overflow
    anchor = Anchor.center;

    // Inner glow
    _glow1 = CircleComponent(
      radius: baseSize * 0.6,
      paint: Paint()
        ..color = Colors.purple.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      anchor: Anchor.center,
      position: size / 2,
    );

    // Outer glow
    _glow2 = CircleComponent(
      radius: baseSize * 0.8,
      paint: Paint()
        ..color = Colors.blue.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      anchor: Anchor.center,
      position: size / 2,
    );

    add(_glow1);
    add(_glow2);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    // Pulsing animation
    final pulse = 0.9 + math.sin(_time * 2) * 0.1;
    _glow1.scale = Vector2.all(pulse);
    _glow2.scale = Vector2.all(pulse * 1.1);

    // Rotate glows
    _glow1.angle = _time * 0.5;
    _glow2.angle = -_time * 0.3;
  }
}
