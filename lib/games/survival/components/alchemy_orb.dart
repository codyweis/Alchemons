// lib/games/survival/components/alchemy_orb.dart
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

class AlchemyOrb extends PositionComponent {
  final double maxHp;
  double currentHp;

  // NEW: transmutation / XP style progress (0..1)
  double transmutationProgress = 0.0;

  // Animation state
  double _time = 0;
  final Random _rng = Random();
  final List<_ManaMote> _particles = [];

  double _hitFlash = 0.0;

  // Paints
  late final Paint _corePaint;
  late final Paint _glowPaint;
  late final Paint _runePaint;
  late final Paint _hpBackgroundPaint;
  late final Paint _hpFillPaint;
  late final Paint _flashPaint;

  // NEW: transmutation circle paints
  late final Paint _transmuteBgPaint;
  late final Paint _transmuteFillPaint;

  AlchemyOrb({required this.maxHp})
    : currentHp = maxHp,
      super(size: Vector2.all(160), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    _glowPaint = Paint()..color = Colors.indigoAccent.withValues(alpha: 0.5);

    _corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.white, Colors.cyanAccent, Colors.blue],
        stops: [0.1, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));

    _runePaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    _hpBackgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    _hpFillPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    _flashPaint = Paint()..color = Colors.red.withValues(alpha: 0.0);

    // NEW transmutation paints
    _transmuteBgPaint = Paint()
      ..color = Colors.deepPurple.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    _transmuteFillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Breathing effect
    add(
      ScaleEffect.by(
        Vector2.all(1.05),
        EffectController(
          duration: 2.0,
          reverseDuration: 2.0,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    _hitFlash = (_hitFlash - dt * 4.0).clamp(0.0, 1.0).toDouble();

    if (_rng.nextDouble() < 0.1) {
      _particles.add(_ManaMote(size / 2));
    }

    for (var p in _particles) {
      p.update(dt);
    }
    _particles.removeWhere((p) => p.life <= 0);
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final particlePaint = Paint()..color = Colors.cyanAccent;

    // 1. Outer glow
    canvas.drawCircle(center, 60, _glowPaint);

    // 2. Particles
    for (var p in _particles) {
      particlePaint.color = Colors.cyanAccent.withValues(alpha: p.life);
      canvas.drawCircle(p.position, p.size, particlePaint);
    }

    // 3. Rotating runes
    _renderRuneRing(canvas, center, radius: 55, speed: 0.5, segments: 3);
    _renderRuneRing(canvas, center, radius: 70, speed: -0.3, segments: 5);

    // 4. Core
    canvas.drawCircle(center, 40, _corePaint);

    // 5. Damage flash
    if (_hitFlash > 0) {
      final opacity = 0.5 * _hitFlash;
      _flashPaint.color = Colors.red.withValues(alpha: opacity);
      canvas.drawCircle(center, 40, _flashPaint);
    }

    // 6. HP ring
    _renderCircularHp(canvas, center);

    // 7. NEW: transmutation progress ring
    _renderTransmutationCircle(canvas, center);
  }

  void _renderRuneRing(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double speed,
    required int segments,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_time * speed);

    final double gapSize = 0.2;
    final double sweepAngle = (2 * pi / segments) - gapSize;

    for (int i = 0; i < segments; i++) {
      final startAngle = i * (2 * pi / segments);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        startAngle,
        sweepAngle,
        false,
        _runePaint,
      );
    }
    canvas.restore();
  }

  void _renderCircularHp(Canvas canvas, Offset center) {
    final radius = 85.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(center, radius, _hpBackgroundPaint);

    final percent = (currentHp / maxHp).clamp(0.0, 1.0);

    if (percent > 0.5) {
      _hpFillPaint.color = Colors.cyanAccent;
      _hpFillPaint.maskFilter = null;
    } else if (percent > 0.25) {
      _hpFillPaint.color = Colors.orangeAccent;
      _hpFillPaint.maskFilter = null;
    } else {
      _hpFillPaint.color = Colors.redAccent;
      _hpFillPaint.maskFilter = null;
    }

    canvas.drawArc(rect, -pi / 2, 2 * pi * percent, false, _hpFillPaint);
  }

  // NEW: purple outer circle that shows transmutation progress
  void _renderTransmutationCircle(Canvas canvas, Offset center) {
    if (transmutationProgress <= 0 && transmutationProgress < 1e-3) {
      // still draw faint bg circle so it feels “there”
      final bgRadius = 105.0;
      canvas.drawCircle(center, bgRadius, _transmuteBgPaint);
      return;
    }

    final radius = 105.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background circle
    canvas.drawCircle(center, radius, _transmuteBgPaint);

    // Sweep gradient around the circle
    final gradient = SweepGradient(
      colors: const [
        Colors.deepPurpleAccent,
        Colors.purpleAccent,
        Colors.pinkAccent,
        Colors.amberAccent,
        Colors.deepPurpleAccent,
      ],
      stops: const [0.0, 0.3, 0.6, 0.85, 1.0],
      startAngle: 0.0,
      endAngle: 2 * pi,
    );

    _transmuteFillPaint.shader = gradient.createShader(rect);

    // rotate so progress starts at top
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-pi / 2);

    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      0,
      2 * pi * transmutationProgress.clamp(0.0, 1.0),
      false,
      _transmuteFillPaint,
    );

    canvas.restore();
  }

  /// Call this from the game to update the purple ring.
  void setTransmutationProgress({
    required int currentKills,
    required int requiredKills,
  }) {
    if (requiredKills <= 0) {
      transmutationProgress = 0.0;
    } else {
      transmutationProgress = (currentKills / requiredKills)
          .clamp(0.0, 1.0)
          .toDouble();
    }
  }

  void takeDamage(int amount) {
    if (currentHp <= 0) return;
    currentHp = max(0.0, currentHp - amount);

    add(
      MoveEffect.by(
        Vector2(5, 0),
        EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 4),
      ),
    );

    _hitFlash = 1.0;
  }

  void heal(int amount) {
    if (currentHp >= maxHp) return;
    currentHp = (currentHp + amount).clamp(0, maxHp).toDouble();

    add(
      ScaleEffect.by(
        Vector2.all(1.2),
        EffectController(duration: 0.2, reverseDuration: 0.2),
      ),
    );
  }

  bool get isDestroyed => currentHp <= 0;
}

class _ManaMote {
  Offset position;
  double life = 1.0;
  double size;
  final double speed;
  final double angle;

  _ManaMote(Vector2 origin)
    : position = Offset(origin.x, origin.y),
      size = Random().nextDouble() * 3 + 1,
      speed = Random().nextDouble() * 20 + 10,
      angle = Random().nextDouble() * 2 * pi;

  void update(double dt) {
    life -= dt * 0.5;
    position += Offset(cos(angle) * speed * dt, sin(angle) * speed * dt);
  }
}
