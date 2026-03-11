// lib/components/sprite_effects/elemental_aura_component.dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/utils/color_util.dart';
import 'dart:math' as math;

class ElementalAuraComponent extends PositionComponent {
  final double baseSize;
  final String? element;
  final List<CircleComponent> _particles = [];
  double _time = 0;

  ElementalAuraComponent({required this.baseSize, this.element});

  @override
  Future<void> onLoad() async {
    size = Vector2.all(baseSize * 2);
    anchor = Anchor.center;

    final color = element != null ? FactionColors.of(element!) : Colors.white;

    // Create orbiting particles
    for (int i = 0; i < 8; i++) {
      final particle = CircleComponent(
        radius: 3,
        paint: Paint()
          ..color = color.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        anchor: Anchor.center,
      );
      _particles.add(particle);
      add(particle);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    final center = size / 2;
    final radius = baseSize * 0.5;

    for (int i = 0; i < _particles.length; i++) {
      final angle =
          (_time + i * (2 * math.pi / _particles.length)) % (2 * math.pi);
      final x = center.x + math.cos(angle) * radius;
      final y = center.y + math.sin(angle) * radius;

      _particles[i].position = Vector2(x, y);

      // Pulsing
      final pulse = 0.8 + math.sin(_time * 3 + i) * 0.2;
      _particles[i].scale = Vector2.all(pulse);
    }
  }
}
