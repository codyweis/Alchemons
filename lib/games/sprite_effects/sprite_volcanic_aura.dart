import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Flame version of the shop's VolcanicAura:
/// - breathing pulse
/// - rotating mystical ring
/// - orbiting ember particles
/// - bright inner core
class VolcanicAuraComponent extends PositionComponent {
  final double baseSize;
  final math.Random _random = math.Random();

  double _time = 0;
  final List<_OrbitEmber> _embers = [];

  VolcanicAuraComponent({required this.baseSize});

  @override
  Future<void> onLoad() async {
    size = Vector2.all(baseSize * 3.2);
    anchor = Anchor.center;

    for (int i = 0; i < 8; i++) {
      _embers.add(
        _OrbitEmber(
          angle: _random.nextDouble() * math.pi * 2,
          speed: 0.7 + _random.nextDouble() * 1.2,
          radiusFactor: 0.75 + _random.nextDouble() * 0.4,
          phase: _random.nextDouble() * math.pi * 2,
          size: 1.6 + _random.nextDouble() * 1.8,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    for (final e in _embers) {
      e.angle += dt * e.speed;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center = Offset(size.x / 2, size.y / 2);
    final pulse = 1.0 + math.sin(_time * 2.2) * 0.12;
    final glowPulse = 0.75 + math.sin(_time * 2.2 + 0.8) * 0.25;
    final r = baseSize * pulse;

    // Rotating outer mystical ring (shop-like sweep)
    final ringRect = Rect.fromCircle(center: center, radius: r * 0.95);
    final ringShader = SweepGradient(
      colors: [
        Colors.deepOrange.withValues(alpha: 0.34 * glowPulse),
        Colors.red.withValues(alpha: 0.26 * glowPulse),
        Colors.purple.withValues(alpha: 0.28 * glowPulse),
        Colors.deepOrange.withValues(alpha: 0.34 * glowPulse),
      ],
      stops: const [0.0, 0.33, 0.66, 1.0],
      transform: GradientRotation(_time * 0.85),
    ).createShader(ringRect);
    canvas.drawCircle(
      center,
      r * 0.95,
      Paint()
        ..shader = ringShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.20
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.22),
    );

    // Fiery radial core
    canvas.drawCircle(
      center,
      r * 1.15,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.54 * glowPulse),
            Colors.amber.withValues(alpha: 0.48 * glowPulse),
            Colors.deepOrange.withValues(alpha: 0.34 * glowPulse),
            Colors.red.withValues(alpha: 0.20 * glowPulse),
            Colors.purple.withValues(alpha: 0.12 * glowPulse),
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.4, 0.6, 0.82, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.15))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18),
    );

    // Bright inner alchemical core
    canvas.drawCircle(
      center,
      r * 0.68,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.78 * glowPulse),
            Colors.yellow.withValues(alpha: 0.62 * glowPulse),
            Colors.orange.withValues(alpha: 0.34 * glowPulse),
            Colors.transparent,
          ],
          stops: const [0.0, 0.28, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 0.68)),
    );

    // Orbiting embers/runes
    for (final e in _embers) {
      final orbitR = r * e.radiusFactor;
      final ox = math.cos(e.angle) * orbitR;
      final oy = math.sin(e.angle) * orbitR;
      final twinkle = (math.sin(_time * 4.0 + e.phase) + 1) * 0.5;
      final alpha = 0.28 + twinkle * 0.72;
      final emberPos = Offset(center.dx + ox, center.dy + oy);
      final emberSize = e.size * (0.9 + twinkle * 0.5);

      canvas.drawCircle(
        emberPos,
        emberSize,
        Paint()
          ..color = Colors.amber.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, emberSize * 1.2),
      );
      canvas.drawCircle(
        emberPos,
        emberSize * 0.55,
        Paint()..color = Colors.orange.withValues(alpha: alpha * 0.85),
      );
    }
  }
}

class _OrbitEmber {
  double angle;
  final double speed;
  final double radiusFactor;
  final double phase;
  final double size;

  _OrbitEmber({
    required this.angle,
    required this.speed,
    required this.radiusFactor,
    required this.phase,
    required this.size,
  });
}
