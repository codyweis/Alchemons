// lib/games/survival/components/black_hole_spawner.dart
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A dramatic black hole spawn effect that enemies emerge from.
///
/// Lifecycle:
/// 1. FORMING - Black hole swirls into existence (grows from nothing)
/// 2. ACTIVE - Pulsing, swirling vortex - enemies spawn from center
/// 3. COLLAPSING - Shrinks and fades out
class BlackHoleSpawner extends PositionComponent {
  final Color accentColor;
  final double radius;
  final double formDuration;
  final double activeDuration;
  final double collapseDuration;
  final void Function(Vector2 position)? onSpawnEnemy;
  final int enemyCount;
  final double spawnInterval;

  double _time = 0;
  double _phase = 0; // 0 = forming, 1 = active, 2 = collapsing
  double _spawnTimer = 0;
  int _enemiesSpawned = 0;
  double _currentScale = 0;
  double _rotationAngle = 0;

  // Visual layers
  final List<_AccretionRing> _rings = [];
  final List<_VortexParticle> _particles = [];
  final Random _rng = Random();

  BlackHoleSpawner({
    required Vector2 position,
    this.accentColor = Colors.deepPurple,
    this.radius = 80.0,
    this.formDuration = 1.2,
    this.activeDuration = 3.0,
    this.collapseDuration = 0.8,
    this.onSpawnEnemy,
    this.enemyCount = 5,
    this.spawnInterval = 0.4,
  }) : super(
         position: position,
         size: Vector2.all(radius * 2),
         anchor: Anchor.center,
       );

  @override
  Future<void> onLoad() async {
    // Create accretion disk rings
    for (int i = 0; i < 4; i++) {
      _rings.add(
        _AccretionRing(
          radiusRatio: 0.5 + i * 0.18,
          rotationSpeed: (2.0 - i * 0.3) * (i.isEven ? 1 : -1),
          thickness: 3.0 - i * 0.5,
          opacity: 0.8 - i * 0.15,
        ),
      );
    }

    // Initial particle burst
    _spawnVortexParticles(20);
  }

  void _spawnVortexParticles(int count) {
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * pi * 2;
      final dist = radius * (0.8 + _rng.nextDouble() * 0.6);
      _particles.add(
        _VortexParticle(
          position: Vector2(cos(angle), sin(angle)) * dist,
          angle: angle,
          distance: dist,
          speed: 1.5 + _rng.nextDouble() * 2.0,
          size: 2.0 + _rng.nextDouble() * 3.0,
          life: 1.0,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _rotationAngle += dt * 3.0;

    // Phase transitions
    if (_phase == 0 && _time >= formDuration) {
      _phase = 1;
      _time = 0;
    } else if (_phase == 1 && _time >= activeDuration) {
      _phase = 2;
      _time = 0;
    } else if (_phase == 2 && _time >= collapseDuration) {
      removeFromParent();
      return;
    }

    // Update scale based on phase
    if (_phase == 0) {
      // Forming: ease out from 0 to 1
      final t = (_time / formDuration).clamp(0.0, 1.0);
      _currentScale = Curves.easeOutBack.transform(t);
    } else if (_phase == 1) {
      // Active: subtle pulse
      _currentScale = 1.0 + sin(_time * 4) * 0.05;
    } else {
      // Collapsing: ease in to 0
      final t = (_time / collapseDuration).clamp(0.0, 1.0);
      _currentScale = 1.0 - Curves.easeInBack.transform(t);
    }

    // Spawn enemies during active phase
    if (_phase == 1 && _enemiesSpawned < enemyCount) {
      _spawnTimer += dt;
      if (_spawnTimer >= spawnInterval) {
        _spawnTimer = 0;
        _enemiesSpawned++;
        onSpawnEnemy?.call(position.clone());

        // Visual burst when spawning
        _spawnVortexParticles(8);
      }
    }

    // Update particles (spiral inward)
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.life -= dt * 0.8;
      p.angle += dt * p.speed * 2;
      p.distance -= dt * 40 * p.speed;

      if (p.life <= 0 || p.distance < 5) {
        _particles.removeAt(i);
      } else {
        p.position = Vector2(cos(p.angle), sin(p.angle)) * p.distance;
      }
    }

    // Continuously spawn new particles during forming/active
    if (_phase < 2 && _particles.length < 30) {
      _spawnVortexParticles(2);
    }
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(_currentScale);

    // 1. Outer glow
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.3 * _currentScale);
    canvas.drawCircle(Offset.zero, radius * 0.9, glowPaint);

    // 2. Accretion disk rings
    for (final ring in _rings) {
      _renderRing(canvas, ring);
    }

    // 3. Vortex particles
    final particlePaint = Paint();
    for (final p in _particles) {
      particlePaint.color = accentColor.withValues(alpha: p.life * 0.8);
      canvas.drawCircle(p.position.toOffset(), p.size * p.life, particlePaint);
    }

    // 4. Event horizon (black center)
    final horizonGradient = RadialGradient(
      colors: [
        Colors.black,
        Colors.black,
        accentColor.withValues(alpha: 0.5),
        accentColor.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.5, 0.7, 1.0],
    );
    final horizonPaint = Paint()
      ..shader = horizonGradient.createShader(
        Rect.fromCircle(center: Offset.zero, radius: radius * 0.5),
      );
    canvas.drawCircle(Offset.zero, radius * 0.5, horizonPaint);

    // 5. Core singularity with bright ring
    final corePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, radius * 0.15, corePaint);

    // Bright inner ring (photon sphere)
    final photonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset.zero, radius * 0.2, photonPaint);

    canvas.restore();
  }

  void _renderRing(Canvas canvas, _AccretionRing ring) {
    final ringRadius = radius * ring.radiusRatio;
    final rotation = _rotationAngle * ring.rotationSpeed;

    canvas.save();
    canvas.rotate(rotation);

    // Draw as dashed arc for visual interest
    final ringPaint = Paint()
      ..color = accentColor.withValues(alpha: ring.opacity * _currentScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ring.thickness;

    final rect = Rect.fromCircle(center: Offset.zero, radius: ringRadius);

    // Draw multiple arc segments
    const segments = 6;
    const gapRatio = 0.15;
    final segmentAngle = (2 * pi / segments) * (1 - gapRatio);
    final gapAngle = (2 * pi / segments) * gapRatio;

    for (int i = 0; i < segments; i++) {
      final startAngle = i * (segmentAngle + gapAngle);
      canvas.drawArc(rect, startAngle, segmentAngle, false, ringPaint);
    }

    canvas.restore();
  }
}

class _AccretionRing {
  final double radiusRatio;
  final double rotationSpeed;
  final double thickness;
  final double opacity;

  _AccretionRing({
    required this.radiusRatio,
    required this.rotationSpeed,
    required this.thickness,
    required this.opacity,
  });
}

class _VortexParticle {
  Vector2 position;
  double angle;
  double distance;
  double speed;
  double size;
  double life;

  _VortexParticle({
    required this.position,
    required this.angle,
    required this.distance,
    required this.speed,
    required this.size,
    required this.life,
  });
}

/// Convenience extension to spawn black holes from the spawner
extension BlackHoleSpawning on Component {
  /// Creates a black hole at the given position that will spawn enemies
  BlackHoleSpawner createBlackHole({
    required Vector2 position,
    required void Function(Vector2 position) onSpawnEnemy,
    Color? color,
    int enemyCount = 5,
    double radius = 80.0,
  }) {
    return BlackHoleSpawner(
      position: position,
      accentColor: color ?? Colors.deepPurple,
      onSpawnEnemy: onSpawnEnemy,
      enemyCount: enemyCount,
      radius: radius,
    );
  }
}
