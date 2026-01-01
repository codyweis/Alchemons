// lib/games/survival/survival_enemy_visuals.dart
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'survival_enemy_types.dart';

/// Main body / visuals for enemies and bosses.
class AlchemicalBlobBody extends PositionComponent {
  final SurvivalEnemyTemplate template;
  final EnemyRole role;
  final Color color;
  final bool isBoss;
  final double radius;
  final BossArchetype? bossArchetype;
  double _currentOpacity = 1.0;

  // Visual state, driven by HoardEnemy
  double hitFlash = 0.0;
  double phaseTintStrength = 0.0;
  Color phaseTint = Colors.transparent;

  final int hydraGeneration;

  // Boss HP - set externally by HoardEnemy
  double hpPercent = 1.0;
  double _displayedHp = 1.0;

  late final Paint _corePaint;
  late final Paint _shellPaint;
  late final Paint _outlinePaint;

  double _time = 0;
  double _rotationSpeed = 0;

  AlchemicalBlobBody({
    required this.template,
    required this.role,
    required this.color,
    required this.isBoss,
    required this.radius,
    this.bossArchetype,
    this.hydraGeneration = 0,
  }) : super(size: Vector2.all(radius * 2), anchor: Anchor.center) {
    _rotationSpeed =
        (1.0 + Random().nextDouble()) * (Random().nextBool() ? 1 : -1);
  }

  set bodyOpacity(double value) {
    _currentOpacity = value.clamp(0.0, 1.0);
  }

  @override
  Future<void> onLoad() async {
    _corePaint = Paint()
      ..color = color.withOpacity(_currentOpacity)
      ..style = PaintingStyle.fill;

    _shellPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    _outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isBoss ? 3.0 : 1.5
      ..strokeCap = StrokeCap.round;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    if (isBoss) {
      final lerpSpeed = 5.0 * dt;
      _displayedHp += (hpPercent - _displayedHp) * lerpSpeed;
    }
  }

  @override
  void render(Canvas canvas) {
    final center = size.toOffset() / 2;

    Color finalColor = color;

    if (hitFlash > 0) {
      finalColor = Color.lerp(finalColor, Colors.white, hitFlash) ?? finalColor;
    }

    if (phaseTintStrength > 0 && phaseTint.opacity > 0) {
      finalColor =
          Color.lerp(finalColor, phaseTint, phaseTintStrength) ?? finalColor;
    }

    _corePaint.color = finalColor.withOpacity(_currentOpacity);
    _shellPaint.color = finalColor.withOpacity(_currentOpacity * 0.2);
    _outlinePaint.color = Colors.white.withOpacity(_currentOpacity * 0.9);

    final pulseSpeed = isBoss ? 2.0 : 4.0;
    final pulseAmount = isBoss ? 0.1 : 0.05;
    final scale = 1.0 + sin(_time * pulseSpeed) * pulseAmount;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    if (isBoss) {
      _renderBoss(canvas);
    } else {
      _renderMinion(canvas);
    }

    canvas.restore();
  }

  void _renderMinion(Canvas canvas) {
    final coreSize = radius * 0.4;
    canvas.drawCircle(Offset.zero, coreSize, _corePaint);

    canvas.save();
    canvas.rotate(_time * _rotationSpeed);

    switch (role) {
      case EnemyRole.charger:
        _renderChargerShape(canvas);
        break;
      case EnemyRole.shooter:
        _renderShooterShape(canvas);
        break;
      case EnemyRole.bomber:
        _renderBomberShape(canvas);
        break;
      case EnemyRole.leecher:
        _renderLeecherShape(canvas);
        break;
    }

    canvas.restore();
  }

  void _renderHydraHeadsAlchemical(Canvas canvas) {
    final headCount = 4 - hydraGeneration.clamp(0, 3);
    final headRadius = radius * (0.32 - hydraGeneration * 0.05);
    final headDistance = radius * 0.75;

    final headPaint = Paint()..color = _corePaint.color.withOpacity(0.85);

    final outline = Paint()
      ..color = _outlinePaint.color.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.035; // THIN, clean

    for (int i = 0; i < headCount; i++) {
      final angle = (i / headCount) * 2 * pi + _time * 0.3;
      final offset = Offset(
        cos(angle) * headDistance,
        sin(angle) * headDistance,
      );

      // ──────────────────────────────────────────────────────────────
      //  ALCHEMICAL HEAD SHAPE: SOFT BODY + thin outline + inner sigil
      // ──────────────────────────────────────────────────────────────

      // Soft glow halo
      canvas.drawCircle(
        offset,
        headRadius * 1.2,
        Paint()..color = _corePaint.color.withOpacity(0.18),
      );

      // Head body
      canvas.drawCircle(offset, headRadius, headPaint);

      // Thin alchemical outline
      canvas.drawCircle(offset, headRadius, outline);

      // Rotating sigil inside the head (small rune spin)
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(_time * 0.8);

      final sigilPaint = Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.02;

      // Simple runic triangle sigil
      final r = headRadius * 0.55;
      final p1 = Offset(0, -r);
      final p2 = Offset(r * 0.87, r * 0.5);
      final p3 = Offset(-r * 0.87, r * 0.5);

      canvas.drawPath(
        Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close(),
        sigilPaint,
      );

      canvas.restore();

      // Subtle white “eye” dot (tiny + clean)
      final eyeOffset = Offset(
        cos(angle) * (headRadius * 0.25),
        sin(angle) * (headRadius * 0.25),
      );

      canvas.drawCircle(
        offset + eyeOffset,
        headRadius * 0.13,
        Paint()..color = Colors.white.withOpacity(0.9),
      );
    }

    // ────────────────────────────────────────────────────────────────
    // Clean alchemical lines linking heads → center (thin geometric)
    // ────────────────────────────────────────────────────────────────
    final linkPaint = Paint()
      ..color = _outlinePaint.color.withOpacity(0.35)
      ..strokeWidth = radius * 0.028;

    for (int i = 0; i < headCount; i++) {
      final angle = (i / headCount) * 2 * pi + _time * 0.3;
      final offset = Offset(
        cos(angle) * headDistance,
        sin(angle) * headDistance,
      );
      canvas.drawLine(Offset.zero, offset, linkPaint);
    }
  }

  void _renderChargerShape(Canvas canvas) {
    final size = radius * 0.8;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size,
      height: size,
    );
    canvas.drawRect(rect, _shellPaint);
    canvas.drawRect(rect, _outlinePaint);

    if (template.tier.index >= EnemyTier.elite.index) {
      canvas.drawCircle(
        Offset.zero,
        size * 0.8,
        _outlinePaint..strokeWidth = 1,
      );
    }
  }

  void _renderShooterShape(Canvas canvas) {
    final r = radius * 0.7;
    canvas.drawCircle(Offset.zero, r, _outlinePaint);

    final bracketSize = r * 0.6;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: bracketSize,
      height: bracketSize,
    );
    canvas.drawRect(rect, _shellPaint);

    canvas.drawPoints(PointMode.points, [
      Offset(-bracketSize / 2, -bracketSize / 2),
      Offset(bracketSize / 2, -bracketSize / 2),
      Offset(-bracketSize / 2, bracketSize / 2),
      Offset(bracketSize / 2, bracketSize / 2),
    ], _outlinePaint..strokeWidth = 3);
  }

  void _renderBomberShape(Canvas canvas) {
    final size = radius * 0.8;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size,
      height: size,
    );
    canvas.drawRect(rect, _outlinePaint);

    canvas.save();
    canvas.rotate(pi / 4);
    canvas.drawRect(rect, _outlinePaint);
    canvas.drawRect(rect, _shellPaint);
    canvas.restore();

    final warningPulse = (sin(_time * 10) + 1) / 2;
    final warningPaint = Paint()
      ..color = Colors.white.withOpacity(warningPulse * 0.8);
    canvas.drawCircle(Offset.zero, radius * 0.3, warningPaint);
  }

  void _renderLeecherShape(Canvas canvas) {
    final r = radius * 0.4;
    canvas.drawCircle(Offset.zero, r, _shellPaint);
    canvas.drawCircle(Offset.zero, r, _outlinePaint);
    canvas.drawCircle(Offset(radius * 0.8, 0), r * 0.5, _corePaint);
    canvas.drawCircle(Offset(-radius * 0.8, 0), r * 0.5, _corePaint);
  }

  void _renderBoss(Canvas canvas) {
    canvas.drawCircle(Offset.zero, radius * 0.5, _corePaint);

    canvas.save();
    canvas.rotate(_time * 0.5);
    _drawRuneRing(canvas, radius * 0.7, 4);
    canvas.restore();

    _renderBossHpRing(canvas);

    if (bossArchetype == BossArchetype.juggernaut) {
      _drawPolygon(canvas, 6, radius * 1.1);
    } else if (bossArchetype == BossArchetype.artillery) {
      canvas.save();
      canvas.rotate(_time);
      _drawPolygon(canvas, 3, radius * 1.2);
      canvas.restore();
    } else if (bossArchetype == BossArchetype.hydra) {
      _renderHydraSigilBody(canvas);
    }
  }

  void _renderHydraSigilBody(Canvas canvas) {
    // 1. Central soft alchemical glow (not a thick outline)
    final glowPaint = Paint()..color = _corePaint.color.withOpacity(0.25);

    canvas.drawCircle(Offset.zero, radius * 0.8, glowPaint);

    // 2. Light geometric inner circle
    final ringPaint = Paint()
      ..color = _outlinePaint.color.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.045; // MUCH thinner than before

    canvas.drawCircle(Offset.zero, radius * 0.65, ringPaint);

    // 3. Draw the heads (alchemical style)
    _renderHydraHeadsAlchemical(canvas);
  }

  void _renderBossHpRing(Canvas canvas) {
    final hpRingRadius = radius * 0.95;
    final ringThickness = radius * 0.12;

    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringThickness
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset.zero, hpRingRadius, bgPaint);

    final hpAngle = _displayedHp * 2 * pi;

    Color hpColor;
    if (_displayedHp > 0.6) {
      hpColor = Color.lerp(
        Colors.yellow,
        Colors.green,
        (_displayedHp - 0.6) / 0.4,
      )!;
    } else if (_displayedHp > 0.3) {
      hpColor = Color.lerp(
        Colors.orange,
        Colors.yellow,
        (_displayedHp - 0.3) / 0.3,
      )!;
    } else {
      hpColor = Color.lerp(Colors.red, Colors.orange, _displayedHp / 0.3)!;
    }

    final hpPaint = Paint()
      ..color = hpColor.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringThickness - 2
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: Offset.zero, radius: hpRingRadius);

    canvas.drawArc(rect, -pi / 2, hpAngle, false, hpPaint);

    final glowPaint = Paint()
      ..color = hpColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringThickness + 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawArc(rect, -pi / 2, hpAngle, false, glowPaint);

    _drawHpTickMarks(canvas, hpRingRadius, ringThickness);

    if (_displayedHp > 0.02 && _displayedHp < 0.98) {
      final notchAngle = -pi / 2 + hpAngle;
      final notchX = cos(notchAngle) * hpRingRadius;
      final notchY = sin(notchAngle) * hpRingRadius;

      final notchPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(notchX, notchY),
        ringThickness * 0.4,
        notchPaint,
      );
    }
  }

  void _drawHpTickMarks(Canvas canvas, double r, double thickness) {
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final percent in [0.75, 0.5, 0.25]) {
      final angle = -pi / 2 + percent * 2 * pi;
      final innerR = r - thickness / 2 - 2;
      final outerR = r + thickness / 2 + 2;

      canvas.drawLine(
        Offset(cos(angle) * innerR, sin(angle) * innerR),
        Offset(cos(angle) * outerR, sin(angle) * outerR),
        tickPaint,
      );
    }
  }

  void _drawRuneRing(Canvas canvas, double r, int segments) {
    final arcSize = (2 * pi) / segments;
    final gap = 0.2;
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);

    for (int i = 0; i < segments; i++) {
      canvas.drawArc(
        rect,
        (i * arcSize) + gap / 2,
        arcSize - gap,
        false,
        _outlinePaint,
      );
    }
  }

  void _drawPolygon(Canvas canvas, int sides, double r) {
    final path = Path();
    final anglePerSide = (2 * pi) / sides;

    for (int i = 0; i < sides; i++) {
      final x = cos(i * anglePerSide) * r;
      final y = sin(i * anglePerSide) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, _outlinePaint..strokeWidth = 3);
  }
}

class AlchemicalTrail extends PositionComponent {
  final Color color;
  final double radius;
  final int maxParticles;
  final List<_TrailParticle> _particles = [];
  double _spawnTimer = 0;

  AlchemicalTrail({
    required this.color,
    required this.radius,
    this.maxParticles = 10,
  }) : super(anchor: Anchor.center, position: Vector2.zero());

  @override
  void update(double dt) {
    super.update(dt);

    if (parent is! PositionComponent) return;
    final parentPc = parent as PositionComponent;

    _spawnTimer += dt;
    if (_spawnTimer > 0.1) {
      _spawnTimer = 0;
      _particles.add(
        _TrailParticle(
          position: Vector2(
            -cos(parentPc.angle) * (radius * 0.5),
            -sin(parentPc.angle) * (radius * 0.5),
          ),
          life: 1.0,
          scale: 1.0,
          angle: parentPc.angle,
        ),
      );
    }

    for (int i = _particles.length - 1; i >= 0; i--) {
      final particle = _particles[i];
      particle.life -= dt * 1.5;

      final driftDir = Vector2(cos(particle.angle), sin(particle.angle));
      particle.position -= driftDir * (dt * 40);
      particle.scale = particle.life;

      if (particle.life <= 0) {
        _particles.removeAt(i);
      }
    }

    if (_particles.length > maxParticles) {
      _particles.removeAt(0);
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = color;

    for (final particle in _particles) {
      paint.color = color.withOpacity(0.4 * particle.life);
      canvas.drawCircle(
        particle.position.toOffset(),
        radius * 0.6 * particle.scale,
        paint,
      );
    }
  }
}

class _TrailParticle {
  Vector2 position;
  double life;
  double scale;
  double angle;

  _TrailParticle({
    required this.position,
    required this.life,
    required this.scale,
    required this.angle,
  });
}
