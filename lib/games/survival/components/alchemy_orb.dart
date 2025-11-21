import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class AlchemyOrb extends PositionComponent {
  final double maxHp;
  double currentHp;

  AlchemyOrb({required this.maxHp})
    : currentHp = maxHp,
      super(size: Vector2.all(120), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    // Glow
    add(
      CircleComponent(
        radius: 70,
        paint: Paint()
          ..color = Colors.cyan.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
        anchor: Anchor.center,
        position: size / 2,
      ),
    );

    // Core
    add(
      CircleComponent(
        radius: 40,
        paint: Paint()..color = Colors.cyanAccent,
        anchor: Anchor.center,
        position: size / 2,
      ),
    );
  }

  void takeDamage(int amount) {
    currentHp -= amount;
    // Flash effect
    children.whereType<CircleComponent>().last.paint.color = Colors.red;
    Future.delayed(const Duration(milliseconds: 100), () {
      children.whereType<CircleComponent>().last.paint.color =
          Colors.cyanAccent;
    });
  }

  bool get isDestroyed => currentHp <= 0;
}
