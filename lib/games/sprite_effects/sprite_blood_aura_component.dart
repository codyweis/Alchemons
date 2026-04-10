import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BloodAuraComponent extends PositionComponent {
  BloodAuraComponent({required this.baseSize});

  final double baseSize;

  late final CircleComponent _outerGlow;
  late final CircleComponent _innerRing;
  final List<CircleComponent> _motes = [];
  double _time = 0;

  @override
  Future<void> onLoad() async {
    size = Vector2.all(baseSize * 2.1);
    anchor = Anchor.center;

    _outerGlow = CircleComponent(
      radius: baseSize * 0.72,
      paint: Paint()
        ..color = const Color(0x55FF1744)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
      anchor: Anchor.center,
      position: size / 2,
    );

    _innerRing = CircleComponent(
      radius: baseSize * 0.5,
      paint: Paint()
        ..color = const Color(0x00FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, baseSize * 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = const Color(0x99FF8A80),
      anchor: Anchor.center,
      position: size / 2,
    );

    add(_outerGlow);
    add(_innerRing);

    for (var i = 0; i < 6; i++) {
      final mote = CircleComponent(
        radius: baseSize * (0.04 + ((i % 3) * 0.008)),
        paint: Paint()
          ..color = const Color(0xCCFF5252)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        anchor: Anchor.center,
        position: size / 2,
      );
      _motes.add(mote);
      add(mote);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    final pulse = 0.95 + (math.sin(_time * 3.0) * 0.08);
    _outerGlow.scale = Vector2.all(1.0 + (math.cos(_time * 2.4) * 0.05));
    _innerRing.scale = Vector2.all(pulse);
    _innerRing.angle = _time * 0.5;

    for (var i = 0; i < _motes.length; i++) {
      final orbit = (_time * 0.55) + (i * 0.85);
      final radius = baseSize * (0.48 + (0.08 * math.sin(orbit * 1.7)));
      _motes[i].position = (size / 2) +
          Vector2(
            math.cos(orbit) * radius,
            math.sin(orbit) * radius * 0.72,
          );
    }
  }
}
