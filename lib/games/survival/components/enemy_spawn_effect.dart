// lib/games/survival/components/enemy_spawn_effect.dart
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

// ============================================================================
// BOSS SPAWN PORTAL - Only used for bosses, dramatic effect
// ============================================================================

class BossSpawnPortal extends PositionComponent {
  final Color color;
  final double radius;
  final double duration;

  double _time = 0;
  double _opacity = 0;
  double _rotation = 0;
  final Random _rng = Random();

  // Lightning bolts
  final List<_LightningBolt> _bolts = [];
  double _boltTimer = 0;

  BossSpawnPortal({
    required Vector2 position,
    required this.color,
    this.radius = 100.0,
    this.duration = 2.5,
  }) : super(
         position: position,
         size: Vector2.all(radius * 2.5),
         anchor: Anchor.center,
       );

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _rotation += dt * 2.0;

    // Opacity curve: quick fade in, hold, fade out
    final t = _time / duration;
    if (t < 0.15) {
      _opacity = (t / 0.15).clamp(0.0, 1.0);
    } else if (t < 0.7) {
      _opacity = 1.0;
    } else {
      _opacity = ((1.0 - t) / 0.3).clamp(0.0, 1.0);
    }

    // Spawn lightning bolts periodically
    _boltTimer += dt;
    if (_boltTimer > 0.08 && _opacity > 0.3) {
      _boltTimer = 0;
      _bolts.add(
        _LightningBolt(
          angle: _rng.nextDouble() * pi * 2,
          length: radius * (0.6 + _rng.nextDouble() * 0.5),
          life: 0.15,
        ),
      );
    }

    // Update bolts
    for (int i = _bolts.length - 1; i >= 0; i--) {
      _bolts[i].life -= dt;
      if (_bolts[i].life <= 0) {
        _bolts.removeAt(i);
      }
    }

    if (_time >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // 1. Outer glow pulse
    final pulseScale = 1.0 + sin(_time * 8) * 0.1;
    final glowPaint = Paint()
      ..color = color.withOpacity(_opacity * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
    canvas.drawCircle(Offset.zero, radius * pulseScale, glowPaint);

    // 2. Spinning outer ring
    canvas.save();
    canvas.rotate(_rotation);
    final outerRingPaint = Paint()
      ..color = color.withOpacity(_opacity * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    _drawDashedCircle(canvas, radius * 0.9, outerRingPaint, 8);
    canvas.restore();

    // 3. Counter-spinning inner ring
    canvas.save();
    canvas.rotate(-_rotation * 1.5);
    final innerRingPaint = Paint()
      ..color = Colors.white.withOpacity(_opacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    _drawDashedCircle(canvas, radius * 0.5, innerRingPaint, 12);
    canvas.restore();

    // 4. Dark vortex center
    final vortexGradient = RadialGradient(
      colors: [
        Colors.black.withOpacity(_opacity),
        Colors.black.withOpacity(_opacity * 0.8),
        color.withOpacity(_opacity * 0.4),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    );
    final vortexPaint = Paint()
      ..shader = vortexGradient.createShader(
        Rect.fromCircle(center: Offset.zero, radius: radius * 0.6),
      );
    canvas.drawCircle(Offset.zero, radius * 0.6, vortexPaint);

    // 5. Lightning bolts
    final boltPaint = Paint()
      ..color = Colors.white.withOpacity(_opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (final bolt in _bolts) {
      boltPaint.color = Colors.white.withOpacity(bolt.life / 0.15 * _opacity);
      _drawLightningBolt(canvas, bolt, boltPaint);
    }

    // 6. Core bright point
    final corePaint = Paint()..color = Colors.white.withOpacity(_opacity * 0.9);
    canvas.drawCircle(Offset.zero, 4, corePaint);

    canvas.restore();
  }

  void _drawDashedCircle(Canvas canvas, double r, Paint paint, int segments) {
    final arcLength = (2 * pi / segments) * 0.7;
    final gap = (2 * pi / segments) * 0.3;
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);

    for (int i = 0; i < segments; i++) {
      canvas.drawArc(rect, i * (arcLength + gap), arcLength, false, paint);
    }
  }

  void _drawLightningBolt(Canvas canvas, _LightningBolt bolt, Paint paint) {
    final path = Path();
    final startX = cos(bolt.angle) * radius * 0.3;
    final startY = sin(bolt.angle) * radius * 0.3;
    final endX = cos(bolt.angle) * bolt.length;
    final endY = sin(bolt.angle) * bolt.length;

    path.moveTo(startX, startY);

    // Jagged line
    const segments = 4;
    for (int i = 1; i <= segments; i++) {
      final t = i / segments;
      final x = startX + (endX - startX) * t;
      final y = startY + (endY - startY) * t;
      final jitter = (i < segments) ? (_rng.nextDouble() - 0.5) * 15 : 0.0;
      path.lineTo(x + jitter, y + jitter);
    }

    canvas.drawPath(path, paint);
  }
}

class _LightningBolt {
  double angle;
  double length;
  double life;

  _LightningBolt({
    required this.angle,
    required this.length,
    required this.life,
  });
}
