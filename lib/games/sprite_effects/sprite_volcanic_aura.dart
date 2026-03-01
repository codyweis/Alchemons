// lib/components/sprite_effects/volcanic_aura_component.dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class VolcanicAuraComponent extends PositionComponent {
  final double baseSize;
  final List<_Ember> _embers = [];
  final math.Random _random = math.Random();

  VolcanicAuraComponent({required this.baseSize});

  @override
  Future<void> onLoad() async {
    size = Vector2.all(baseSize * 2);
    anchor = Anchor.center;

    // Create ember particles
    for (int i = 0; i < 20; i++) {
      _embers.add(
        _Ember(
          position: Vector2(
            _random.nextDouble() * size.x,
            _random.nextDouble() * size.y,
          ),
          velocity: Vector2(
            (_random.nextDouble() - 0.5) * 20,
            -20 - _random.nextDouble() * 30,
          ),
          size: 2 + _random.nextDouble() * 3,
          lifetime: 1.0 + _random.nextDouble() * 2.0,
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final paint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (final ember in _embers) {
      if (ember.isAlive) {
        canvas.drawCircle(
          ember.position.toOffset(),
          ember.size * ember.opacity,
          paint,
        );
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    for (final ember in _embers) {
      ember.update(dt);

      // Respawn dead embers
      if (!ember.isAlive) {
        ember.reset(
          Vector2(_random.nextDouble() * size.x, size.y),
          Vector2(
            (_random.nextDouble() - 0.5) * 20,
            -20 - _random.nextDouble() * 30,
          ),
        );
      }
    }
  }
}

class _Ember {
  Vector2 position;
  Vector2 velocity;
  double size;
  double lifetime;
  double age = 0;

  _Ember({
    required this.position,
    required this.velocity,
    required this.size,
    required this.lifetime,
  });

  bool get isAlive => age < lifetime;
  double get opacity => 1.0 - (age / lifetime);

  void update(double dt) {
    age += dt;
    position += velocity * dt;
    velocity.y += 10 * dt; // Gravity
  }

  void reset(Vector2 newPos, Vector2 newVel) {
    position = newPos;
    velocity = newVel;
    age = 0;
  }
}
