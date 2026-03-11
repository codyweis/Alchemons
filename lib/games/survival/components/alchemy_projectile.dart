// lib/games/survival/components/alchemy_projectile.dart
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

enum ProjectileShape {
  orb, // Earth, Horn (Heavy)
  shard, // Fire, Let (Aggressive)
  blade, // Air, Wing (Fast)
  star, // Spirit, Mystic (Magic)
  thorn, // Plant, Mane (Tricky)
  bolt, // Lightning (Jagged)
}

class AlchemyProjectile extends PositionComponent {
  final Vector2 start;
  final Vector2 end;
  final Color color;
  final VoidCallback onHit;
  final ProjectileShape shape;
  final double speedMultiplier;

  double _t = 0;
  late Path _drawPath;
  late Paint _glowPaint;
  late Paint _corePaint;

  AlchemyProjectile({
    required this.start,
    required this.end,
    required this.color,
    required this.onHit,
    this.shape = ProjectileShape.orb,
    this.speedMultiplier = 1.0,
  }) : super(position: start, size: Vector2.all(20), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    // 1. Pre-calculate the Shape Path (Performance Optimization)
    _drawPath = _buildPath();

    // 2. Setup Paints (Cache them)
    // Outer Glow (The "Mystical" part)
    _glowPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Inner Core (The "Elemental" part)
    _corePaint = Paint()
      ..color = Colors.white
          .withValues(alpha: 0.9) // Hot core
      ..style = PaintingStyle.fill;

    // 3. Orientation
    // Rotate blades/bolts to face target
    if (shape == ProjectileShape.blade ||
        shape == ProjectileShape.bolt ||
        shape == ProjectileShape.shard) {
      final angle = atan2(end.y - start.y, end.x - start.x);
      this.angle = angle + pi / 2;
    }

    // Spin stars/shards for kinetic feel
    if (shape == ProjectileShape.star || shape == ProjectileShape.orb) {
      add(
        RotateEffect.by(
          pi * 4,
          EffectController(duration: 1.0, infinite: true),
        ),
      );
    }

    // 4. Trail Effect (Simple Echo)
    add(
      TimerComponent(
        period: 0.08, // Don't spawn too often (Performance)
        repeat: true,
        onTick: () {
          if (parent != null) {
            parent!.add(_createTrail());
          }
        },
      ),
    );
  }

  Path _buildPath() {
    final path = Path();
    switch (shape) {
      case ProjectileShape.blade: // Crescent Moon
        path.moveTo(0, -12);
        path.quadraticBezierTo(8, 0, 0, 12);
        path.quadraticBezierTo(4, 0, 0, -12);
        break;
      case ProjectileShape.shard: // Diamond
        path.moveTo(0, -10);
        path.lineTo(6, 0);
        path.lineTo(0, 10);
        path.lineTo(-6, 0);
        break;
      case ProjectileShape.star: // 4-Point Spark
        path.moveTo(0, -10);
        path.quadraticBezierTo(2, -2, 10, 0);
        path.quadraticBezierTo(2, 2, 0, 10);
        path.quadraticBezierTo(-2, 2, -10, 0);
        path.quadraticBezierTo(-2, -2, 0, -10);
        break;
      case ProjectileShape.thorn: // Spike
        path.moveTo(0, -10);
        path.lineTo(4, 8);
        path.lineTo(-4, 8);
        break;
      case ProjectileShape.bolt: // Jagged Line
        path.moveTo(0, -12);
        path.lineTo(4, -4);
        path.lineTo(-4, 4);
        path.lineTo(0, 12);
        break;
      case ProjectileShape.orb: // Circle
        path.addOval(Rect.fromCircle(center: Offset.zero, radius: 6));
        break;
    }
    path.close();
    return path;
  }

  @override
  void render(Canvas canvas) {
    // Draw Glow
    canvas.drawPath(_drawPath, _glowPaint);
    // Draw Core (White-hot center)
    canvas.drawPath(_drawPath, _corePaint);
  }

  Component _createTrail() {
    // Very cheap visual echo. No physics, just a fading circle.
    return CircleComponent(
      radius: 4,
      position: position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = color.withValues(alpha: 0.3),
    )..add(
      SequenceEffect([
        ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.3)),
        RemoveEffect(),
      ]),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Base speed = 3.0. Multiplier adjusts for "Speed" stat.
    _t += dt * (3.0 * speedMultiplier);

    if (_t >= 1.0) {
      onHit();
      removeFromParent();
    } else {
      // Linear interpolation from Start to End
      position = start + (end - start) * _t;

      // Jitter for lightning
      if (shape == ProjectileShape.bolt) {
        position.x += (Random().nextDouble() - 0.5) * 5;
        position.y += (Random().nextDouble() - 0.5) * 5;
      }
    }
  }
}
