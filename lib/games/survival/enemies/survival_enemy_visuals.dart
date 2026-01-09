// lib/games/survival/survival_enemy_visuals_v2.dart
//
// IMPROVED ENEMY VISUALS - Beefier, more distinctive, satisfying to kill
//
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import 'survival_enemy_types.dart';

// ════════════════════════════════════════════════════════════════════════════
// SIZE CONSTANTS - Much beefier than before
// ════════════════════════════════════════════════════════════════════════════

class EnemySizeConfig {
  // Base radii per tier (was 12 + tier*1.5, now MUCH bigger)
  static const Map<EnemyTier, double> baseRadius = {
    EnemyTier.swarm: 18.0, // Was ~13.5, now 18 - visible fodder
    EnemyTier.grunt: 20.0, // Was ~15, now 28 - chunky brutes
    EnemyTier.elite: 25.0, // Was ~16.5, now 38 - scary elites
    EnemyTier.champion: 15.0, // Mini-boss territory
    EnemyTier.titan: 15.0, // Boss base (before archetype scaling)
  };

  // Family-specific size modifiers
  static const Map<CreatureFamily, double> familySizeScale = {
    // Swarm families - varied sizes for visual interest
    CreatureFamily.gloop: 1.1, // Blobby, slightly bigger
    CreatureFamily.skitter: 0.85, // Fast bugs, smaller
    CreatureFamily.wisp: 0.9, // Ethereal, medium-small
    CreatureFamily.mote: 0.75, // Tiny sparks
    CreatureFamily.speck: 0.7, // Smallest fodder
    // Grunt families - beefier
    CreatureFamily.crawler: 1.15,
    CreatureFamily.shambler: 1.25, // Big slow blobs
    CreatureFamily.lurker: 1.0,
    CreatureFamily.creep: 1.1,

    // Elite families - imposing
    CreatureFamily.ravager: 1.2,
    CreatureFamily.stalker: 0.95,
    CreatureFamily.howler: 1.1,
    CreatureFamily.shade: 1.0,

    // Champion/Boss families
    CreatureFamily.brute: 1.3,
    CreatureFamily.terror: 1.15,
    CreatureFamily.dread: 1.2,
    CreatureFamily.blight: 1.1,
    CreatureFamily.colossus: 1.4,
    CreatureFamily.leviathan: 1.3,
    CreatureFamily.behemoth: 1.5,
    CreatureFamily.apex: 1.35,
  };

  static double getRadius(SurvivalEnemyTemplate template, double sizeScale) {
    final base = baseRadius[template.tier] ?? 18.0;
    final familyMod = familySizeScale[template.creatureFamily] ?? 1.0;
    return base * familyMod * sizeScale;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FAMILY VISUAL SHAPES - Each creature family has a distinct silhouette
// ════════════════════════════════════════════════════════════════════════════

enum FamilyShape {
  blob, // Gloop, Shambler - amorphous, jiggly
  insectoid, // Skitter, Crawler - segmented, angular
  ethereal, // Wisp, Shade, Mote - glowy, translucent
  spiky, // Ravager, Brute - aggressive, sharp edges
  serpentine, // Lurker, Stalker - sinuous, flowing
  crystalline, // Terror, Dread - geometric, faceted
  amorphous, // Blight, Creep - chaotic, shifting
  titanic, // Colossus, Behemoth, Leviathan, Apex - massive, imposing
}

const Map<CreatureFamily, FamilyShape> familyShapes = {
  CreatureFamily.gloop: FamilyShape.blob,
  CreatureFamily.skitter: FamilyShape.insectoid,
  CreatureFamily.wisp: FamilyShape.ethereal,
  CreatureFamily.mote: FamilyShape.ethereal,
  CreatureFamily.speck: FamilyShape.ethereal,
  CreatureFamily.crawler: FamilyShape.insectoid,
  CreatureFamily.shambler: FamilyShape.blob,
  CreatureFamily.lurker: FamilyShape.serpentine,
  CreatureFamily.creep: FamilyShape.amorphous,
  CreatureFamily.ravager: FamilyShape.spiky,
  CreatureFamily.stalker: FamilyShape.serpentine,
  CreatureFamily.howler: FamilyShape.amorphous,
  CreatureFamily.shade: FamilyShape.ethereal,
  CreatureFamily.brute: FamilyShape.spiky,
  CreatureFamily.terror: FamilyShape.crystalline,
  CreatureFamily.dread: FamilyShape.crystalline,
  CreatureFamily.blight: FamilyShape.amorphous,
  CreatureFamily.colossus: FamilyShape.titanic,
  CreatureFamily.leviathan: FamilyShape.titanic,
  CreatureFamily.behemoth: FamilyShape.titanic,
  CreatureFamily.apex: FamilyShape.titanic,
};

// ════════════════════════════════════════════════════════════════════════════
// MAIN ENEMY BODY COMPONENT
// ════════════════════════════════════════════════════════════════════════════

class ImprovedBlobBody extends PositionComponent {
  final SurvivalEnemyTemplate template;
  final EnemyRole role;
  final Color color;
  final bool isBoss;
  final double radius;
  final BossArchetype? bossArchetype;
  final int hydraGeneration;

  double _currentOpacity = 1.0;
  double hitFlash = 0.0;
  double phaseTintStrength = 0.0;
  Color phaseTint = Colors.transparent;
  double hpPercent = 1.0;
  double _displayedHp = 1.0;

  late final Paint _corePaint;
  late final Paint _shellPaint;
  late final Paint _outlinePaint;
  late final Paint _glowPaint;

  double _time = 0;
  double _rotationSpeed = 0;
  final Random _rng = Random();

  // Blob wobble state
  final List<double> _wobblePhases = [];
  final List<double> _wobbleSpeeds = [];

  // Family shape
  late final FamilyShape _shape;

  ImprovedBlobBody({
    required this.template,
    required this.role,
    required this.color,
    required this.isBoss,
    required this.radius,
    this.bossArchetype,
    this.hydraGeneration = 0,
  }) : super(size: Vector2.all(radius * 2.4), anchor: Anchor.center) {
    _rotationSpeed =
        (0.8 + _rng.nextDouble() * 0.6) * (_rng.nextBool() ? 1 : -1);
    _shape = familyShapes[template.creatureFamily] ?? FamilyShape.blob;

    // Initialize wobble for organic feel
    final wobbleCount = _shape == FamilyShape.blob ? 8 : 6;
    for (int i = 0; i < wobbleCount; i++) {
      _wobblePhases.add(_rng.nextDouble() * pi * 2);
      _wobbleSpeeds.add(1.5 + _rng.nextDouble() * 2.0);
    }
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
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    _outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isBoss ? 3.5 : 2.0
      ..strokeCap = StrokeCap.round;

    _glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    // Update wobble phases
    for (int i = 0; i < _wobblePhases.length; i++) {
      _wobblePhases[i] += dt * _wobbleSpeeds[i];
    }

    if (isBoss) {
      _displayedHp += (hpPercent - _displayedHp) * 5.0 * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final center = size.toOffset() / 2;

    // Apply visual effects
    Color finalColor = color;
    if (hitFlash > 0) {
      finalColor = Color.lerp(finalColor, Colors.white, hitFlash) ?? finalColor;
    }
    if (phaseTintStrength > 0 && phaseTint.opacity > 0) {
      finalColor =
          Color.lerp(finalColor, phaseTint, phaseTintStrength) ?? finalColor;
    }

    _corePaint.color = finalColor.withOpacity(_currentOpacity);
    _shellPaint.color = finalColor.withOpacity(_currentOpacity * 0.25);
    _outlinePaint.color = Colors.white.withOpacity(_currentOpacity * 0.85);
    _glowPaint.color = finalColor.withOpacity(_currentOpacity * 0.3);

    // Pulse animation
    final pulseSpeed = isBoss ? 2.0 : 3.5;
    final pulseAmount = isBoss ? 0.08 : 0.05;
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
    // Outer glow for visibility
    canvas.drawCircle(Offset.zero, radius * 1.15, _glowPaint);

    // Render shape based on family
    switch (_shape) {
      case FamilyShape.blob:
        _renderBlobShape(canvas);
        break;
      case FamilyShape.insectoid:
        _renderInsectoidShape(canvas);
        break;
      case FamilyShape.ethereal:
        _renderEtherealShape(canvas);
        break;
      case FamilyShape.spiky:
        _renderSpikyShape(canvas);
        break;
      case FamilyShape.serpentine:
        _renderSerpentineShape(canvas);
        break;
      case FamilyShape.crystalline:
        _renderCrystallineShape(canvas);
        break;
      case FamilyShape.amorphous:
        _renderAmorphousShape(canvas);
        break;
      case FamilyShape.titanic:
        _renderTitanicShape(canvas);
        break;
    }

    // Role indicator overlay
    _renderRoleIndicator(canvas);
  }

  /// Blob shape - organic, wobbly circle
  void _renderBlobShape(Canvas canvas) {
    final path = Path();
    final points = _wobblePhases.length;

    for (int i = 0; i <= points; i++) {
      final angle = (i / points) * 2 * pi;
      final wobbleIndex = i % points;
      final wobble = sin(_wobblePhases[wobbleIndex]) * radius * 0.12;
      final r = radius * 0.85 + wobble;

      final x = cos(angle) * r;
      final y = sin(angle) * r;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Smooth curve
        final prevAngle = ((i - 1) / points) * 2 * pi;
        final prevWobble = sin(_wobblePhases[(i - 1) % points]) * radius * 0.12;
        final prevR = radius * 0.85 + prevWobble;

        final cx = cos((angle + prevAngle) / 2) * (r + prevR) * 0.55;
        final cy = sin((angle + prevAngle) / 2) * (r + prevR) * 0.55;

        path.quadraticBezierTo(cx, cy, x, y);
      }
    }
    path.close();

    canvas.drawPath(path, _shellPaint);
    canvas.drawPath(path, _outlinePaint);

    // Inner core
    canvas.drawCircle(Offset.zero, radius * 0.35, _corePaint);
  }

  /// Insectoid shape - segmented body with legs
  void _renderInsectoidShape(Canvas canvas) {
    canvas.save();
    canvas.rotate(_time * _rotationSpeed * 0.3);

    // Main body segments
    final segmentCount = 3;
    for (int i = 0; i < segmentCount; i++) {
      final segR = radius * (0.5 - i * 0.1);
      final segY = (i - 1) * radius * 0.35;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, segY),
          width: segR * 2,
          height: segR * 1.4,
        ),
        _shellPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, segY),
          width: segR * 2,
          height: segR * 1.4,
        ),
        _outlinePaint..strokeWidth = 1.5,
      );
    }

    // Legs
    final legPaint = Paint()
      ..color = _outlinePaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int side = -1; side <= 1; side += 2) {
      for (int leg = 0; leg < 3; leg++) {
        final baseY = (leg - 1) * radius * 0.3;
        final legAngle = sin(_time * 4 + leg) * 0.3;

        final path = Path()
          ..moveTo(side * radius * 0.3, baseY)
          ..quadraticBezierTo(
            side * radius * 0.7,
            baseY + sin(legAngle) * radius * 0.2,
            side * radius * 0.9,
            baseY + cos(_time * 3 + leg) * radius * 0.15,
          );
        canvas.drawPath(path, legPaint);
      }
    }

    canvas.restore();

    // Eyes
    final eyeR = radius * 0.12;
    canvas.drawCircle(Offset(-radius * 0.2, -radius * 0.3), eyeR, _corePaint);
    canvas.drawCircle(Offset(radius * 0.2, -radius * 0.3), eyeR, _corePaint);
  }

  /// Ethereal shape - glowing, translucent wisp
  void _renderEtherealShape(Canvas canvas) {
    // Multiple layered circles for glow effect
    for (int layer = 3; layer >= 0; layer--) {
      final layerR = radius * (0.5 + layer * 0.2);
      final layerOpacity = 0.15 - layer * 0.03;
      canvas.drawCircle(
        Offset(sin(_time * 2 + layer) * 3, cos(_time * 1.5 + layer) * 3),
        layerR,
        Paint()..color = color.withOpacity(layerOpacity * _currentOpacity),
      );
    }

    // Core with sparkle
    final coreR = radius * 0.4;
    final sparkle = 0.8 + sin(_time * 6) * 0.2;
    canvas.drawCircle(
      Offset.zero,
      coreR,
      Paint()..color = Colors.white.withOpacity(sparkle * _currentOpacity),
    );

    // Orbiting particles
    for (int i = 0; i < 4; i++) {
      final angle = _time * 2 + (i / 4) * 2 * pi;
      final orbitR = radius * 0.7;
      final particlePos = Offset(cos(angle) * orbitR, sin(angle) * orbitR);
      canvas.drawCircle(
        particlePos,
        radius * 0.08,
        Paint()..color = color.withOpacity(0.6 * _currentOpacity),
      );
    }
  }

  /// Spiky shape - aggressive, with protruding spines
  void _renderSpikyShape(Canvas canvas) {
    final path = Path();
    final spikeCount = 8;

    for (int i = 0; i < spikeCount; i++) {
      final angle = (i / spikeCount) * 2 * pi;
      final nextAngle = ((i + 1) / spikeCount) * 2 * pi;
      final midAngle = (angle + nextAngle) / 2;

      // Spike tip
      final spikeExtend = radius * (0.95 + sin(_time * 3 + i) * 0.1);
      final spikeX = cos(angle) * spikeExtend;
      final spikeY = sin(angle) * spikeExtend;

      // Valley between spikes
      final valleyR = radius * 0.55;
      final valleyX = cos(midAngle) * valleyR;
      final valleyY = sin(midAngle) * valleyR;

      if (i == 0) {
        path.moveTo(spikeX, spikeY);
      } else {
        path.lineTo(spikeX, spikeY);
      }
      path.lineTo(valleyX, valleyY);
    }
    path.close();

    canvas.drawPath(path, _shellPaint);
    canvas.drawPath(path, _outlinePaint);

    // Angry core
    canvas.drawCircle(Offset.zero, radius * 0.3, _corePaint);

    // Glowing eyes
    final eyeGlow = 0.5 + sin(_time * 5) * 0.3;
    final eyePaint = Paint()
      ..color = Colors.red.withOpacity(eyeGlow * _currentOpacity);
    canvas.drawCircle(
      Offset(-radius * 0.15, -radius * 0.1),
      radius * 0.08,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(radius * 0.15, -radius * 0.1),
      radius * 0.08,
      eyePaint,
    );
  }

  /// Serpentine shape - sinuous, flowing form
  void _renderSerpentineShape(Canvas canvas) {
    canvas.save();
    canvas.rotate(_time * _rotationSpeed * 0.2);

    final path = Path();
    final segments = 12;
    final waveAmp = radius * 0.25;

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final angle = t * 2 * pi;
      final wave = sin(_time * 3 + t * 4 * pi) * waveAmp;
      final r = radius * 0.7 + wave;

      final x = cos(angle) * r;
      final y = sin(angle) * r;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, _shellPaint);
    canvas.drawPath(path, _outlinePaint..strokeWidth = 1.5);

    // Head
    final headAngle = _time * 0.5;
    final headPos = Offset(
      cos(headAngle) * radius * 0.3,
      sin(headAngle) * radius * 0.3,
    );
    canvas.drawCircle(headPos, radius * 0.25, _corePaint);

    canvas.restore();
  }

  /// Crystalline shape - geometric, faceted
  void _renderCrystallineShape(Canvas canvas) {
    canvas.save();
    canvas.rotate(_time * _rotationSpeed * 0.15);

    // Outer hexagon
    _drawPolygon(canvas, 6, radius * 0.9, _shellPaint);
    _drawPolygon(canvas, 6, radius * 0.9, _outlinePaint);

    // Inner rotated hexagon
    canvas.rotate(pi / 6);
    _drawPolygon(canvas, 6, radius * 0.6, _shellPaint);
    _drawPolygon(canvas, 6, radius * 0.6, _outlinePaint..strokeWidth = 1.5);

    // Core crystal
    canvas.rotate(-pi / 6);
    _drawPolygon(canvas, 4, radius * 0.3, _corePaint);

    canvas.restore();
  }

  /// Amorphous shape - chaotic, shifting form
  void _renderAmorphousShape(Canvas canvas) {
    // Multiple overlapping blobs
    for (int blob = 0; blob < 4; blob++) {
      final blobOffset = Offset(
        sin(_time * 2 + blob * 1.5) * radius * 0.2,
        cos(_time * 1.7 + blob * 1.5) * radius * 0.2,
      );
      final blobR = radius * (0.5 - blob * 0.08);

      canvas.drawCircle(
        blobOffset,
        blobR,
        Paint()
          ..color = color.withOpacity((0.3 - blob * 0.05) * _currentOpacity),
      );
    }

    // Chaotic tendrils
    final tendrilPaint = Paint()
      ..color = color.withOpacity(0.4 * _currentOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int t = 0; t < 5; t++) {
      final path = Path();
      final startAngle = (t / 5) * 2 * pi + _time * 0.5;
      path.moveTo(0, 0);

      double x = 0, y = 0;
      for (int seg = 0; seg < 4; seg++) {
        final segAngle = startAngle + sin(_time * 3 + t + seg) * 0.8;
        final segLen = radius * 0.25;
        x += cos(segAngle) * segLen;
        y += sin(segAngle) * segLen;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, tendrilPaint);
    }

    // Core
    canvas.drawCircle(Offset.zero, radius * 0.25, _corePaint);
  }

  /// Titanic shape - massive, imposing presence
  void _renderTitanicShape(Canvas canvas) {
    // Outer aura
    for (int ring = 2; ring >= 0; ring--) {
      canvas.drawCircle(
        Offset.zero,
        radius * (1.0 + ring * 0.15),
        Paint()
          ..color = color.withOpacity((0.1 - ring * 0.02) * _currentOpacity),
      );
    }

    // Main body with layered armor plates
    final plateCount = 6;
    canvas.save();
    canvas.rotate(_time * 0.2);

    for (int plate = 0; plate < plateCount; plate++) {
      final plateAngle = (plate / plateCount) * 2 * pi;
      final plateOffset = Offset(
        cos(plateAngle) * radius * 0.15,
        sin(plateAngle) * radius * 0.15,
      );

      canvas.save();
      canvas.translate(plateOffset.dx, plateOffset.dy);
      canvas.rotate(plateAngle);

      final plateRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 0.7,
          height: radius * 0.5,
        ),
        Radius.circular(radius * 0.1),
      );
      canvas.drawRRect(plateRect, _shellPaint);
      canvas.drawRRect(plateRect, _outlinePaint..strokeWidth = 2);

      canvas.restore();
    }

    canvas.restore();

    // Central eye/core
    final eyePulse = 0.7 + sin(_time * 4) * 0.3;
    canvas.drawCircle(
      Offset.zero,
      radius * 0.35,
      Paint()..color = Colors.white.withOpacity(eyePulse * _currentOpacity),
    );
    canvas.drawCircle(Offset.zero, radius * 0.2, _corePaint);
  }

  /// Role-specific visual indicator
  void _renderRoleIndicator(Canvas canvas) {
    switch (role) {
      case EnemyRole.shooter:
        // Targeting reticle
        final reticlePaint = Paint()
          ..color = Colors.cyan.withOpacity(0.6 * _currentOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(Offset.zero, radius * 1.1, reticlePaint);

        // Crosshairs
        for (int i = 0; i < 4; i++) {
          final angle = (i / 4) * 2 * pi;
          canvas.drawLine(
            Offset(cos(angle) * radius * 0.9, sin(angle) * radius * 0.9),
            Offset(cos(angle) * radius * 1.2, sin(angle) * radius * 1.2),
            reticlePaint,
          );
        }
        break;

      case EnemyRole.bomber:
        // Warning pulse
        final warningPulse = (sin(_time * 8) + 1) / 2;
        final warningPaint = Paint()
          ..color = Colors.orange.withOpacity(
            warningPulse * 0.5 * _currentOpacity,
          );
        canvas.drawCircle(Offset.zero, radius * 1.2, warningPaint);

        // Fuse spark
        final sparkPos = Offset(0, -radius * 0.8);
        canvas.drawCircle(
          sparkPos,
          radius * 0.12,
          Paint()
            ..color = Colors.yellow.withOpacity(warningPulse * _currentOpacity),
        );
        break;

      case EnemyRole.leecher:
        // Drain tendrils hint
        final drainPaint = Paint()
          ..color = Colors.purple.withOpacity(0.4 * _currentOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        for (int i = 0; i < 3; i++) {
          final angle = _time + (i / 3) * 2 * pi;
          final path = Path()
            ..moveTo(cos(angle) * radius * 0.5, sin(angle) * radius * 0.5)
            ..quadraticBezierTo(
              cos(angle + 0.3) * radius * 0.9,
              sin(angle + 0.3) * radius * 0.9,
              cos(angle + 0.5) * radius * 1.3,
              sin(angle + 0.5) * radius * 1.3,
            );
          canvas.drawPath(path, drainPaint);
        }
        break;

      case EnemyRole.charger:
        // Subtle momentum lines when moving fast would go here
        // For now, just a slight forward emphasis
        break;
    }
  }

  void _drawPolygon(Canvas canvas, int sides, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final angle = (i / sides) * 2 * pi - pi / 2;
      final x = cos(angle) * r;
      final y = sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOSS RENDERING
  // ══════════════════════════════════════════════════════════════════════════

  void _renderBoss(Canvas canvas) {
    // Massive outer glow
    for (int glow = 2; glow >= 0; glow--) {
      canvas.drawCircle(
        Offset.zero,
        radius * (1.3 + glow * 0.2),
        Paint()
          ..color = color.withOpacity((0.15 - glow * 0.04) * _currentOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    // Core body
    canvas.drawCircle(Offset.zero, radius * 0.55, _corePaint);

    // Rotating rune ring
    canvas.save();
    canvas.rotate(_time * 0.5);
    _drawRuneRing(canvas, radius * 0.75, 5);
    canvas.restore();

    // HP ring
    _renderBossHpRing(canvas);

    // Archetype-specific visuals
    switch (bossArchetype) {
      case BossArchetype.juggernaut:
        _renderJuggernautDetails(canvas);
        break;
      case BossArchetype.artillery:
        _renderArtilleryDetails(canvas);
        break;
      case BossArchetype.summoner:
        _renderSummonerDetails(canvas);
        break;
      case BossArchetype.hydra:
        _renderHydraDetails(canvas);
        break;
      default:
        break;
    }
  }

  void _renderJuggernautDetails(Canvas canvas) {
    // Heavy armor plates
    _drawPolygon(canvas, 6, radius * 1.15, _outlinePaint..strokeWidth = 4);

    // Impact cracks/scars
    final scarPaint = Paint()
      ..color = Colors.white.withOpacity(0.3 * _currentOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 3; i++) {
      final angle = (i / 3) * 2 * pi + 0.3;
      final path = Path()
        ..moveTo(cos(angle) * radius * 0.4, sin(angle) * radius * 0.4)
        ..lineTo(cos(angle) * radius * 0.8, sin(angle) * radius * 0.8);
      canvas.drawPath(path, scarPaint);
    }
  }

  void _renderArtilleryDetails(Canvas canvas) {
    canvas.save();
    canvas.rotate(_time);

    // Targeting rings
    _drawPolygon(canvas, 3, radius * 1.25, _outlinePaint..strokeWidth = 2);

    canvas.rotate(pi);
    _drawPolygon(canvas, 3, radius * 1.1, _outlinePaint..strokeWidth = 1.5);

    canvas.restore();

    // Cannon barrels hint
    for (int i = 0; i < 3; i++) {
      final angle = (i / 3) * 2 * pi + _time * 0.3;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cos(angle) * radius * 0.7, sin(angle) * radius * 0.7),
          width: radius * 0.15,
          height: radius * 0.4,
        ),
        Radius.circular(radius * 0.05),
      );
      canvas.save();
      canvas.translate(cos(angle) * radius * 0.7, sin(angle) * radius * 0.7);
      canvas.rotate(angle + pi / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * 0.15,
            height: radius * 0.4,
          ),
          Radius.circular(radius * 0.05),
        ),
        _shellPaint,
      );
      canvas.restore();
    }
  }

  void _renderSummonerDetails(Canvas canvas) {
    // Summoning circles
    for (int ring = 0; ring < 3; ring++) {
      canvas.save();
      canvas.rotate(_time * (0.3 + ring * 0.2) * (ring.isEven ? 1 : -1));

      final ringR = radius * (0.9 + ring * 0.25);
      final dashPaint = Paint()
        ..color = color.withOpacity((0.5 - ring * 0.1) * _currentOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final segments = 8 + ring * 2;
      final arcLen = (2 * pi / segments) * 0.6;

      for (int i = 0; i < segments; i++) {
        final startAngle = (i / segments) * 2 * pi;
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: ringR),
          startAngle,
          arcLen,
          false,
          dashPaint,
        );
      }

      canvas.restore();
    }

    // Arcane symbols at cardinal points
    final symbolPaint = Paint()
      ..color = Colors.white.withOpacity(0.6 * _currentOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * 2 * pi + _time * 0.2;
      final pos = Offset(cos(angle) * radius * 1.1, sin(angle) * radius * 1.1);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);

      // Simple rune shape
      canvas.drawLine(
        Offset(-radius * 0.08, 0),
        Offset(radius * 0.08, 0),
        symbolPaint,
      );
      canvas.drawLine(
        Offset(0, -radius * 0.08),
        Offset(0, radius * 0.08),
        symbolPaint,
      );

      canvas.restore();
    }
  }

  void _renderHydraDetails(Canvas canvas) {
    // Central sigil glow
    canvas.drawCircle(
      Offset.zero,
      radius * 0.8,
      Paint()..color = _corePaint.color.withOpacity(0.25),
    );

    // Inner ring
    canvas.drawCircle(
      Offset.zero,
      radius * 0.65,
      Paint()
        ..color = _outlinePaint.color.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.045,
    );

    // Hydra heads
    _renderHydraHeads(canvas);
  }

  void _renderHydraHeads(Canvas canvas) {
    final headCount = 4 - hydraGeneration.clamp(0, 3);
    final headRadius = radius * (0.32 - hydraGeneration * 0.05);
    final headDistance = radius * 0.75;

    final headPaint = Paint()..color = _corePaint.color.withOpacity(0.85);
    final outline = Paint()
      ..color = _outlinePaint.color.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.035;

    for (int i = 0; i < headCount; i++) {
      final angle = (i / headCount) * 2 * pi + _time * 0.3;
      final offset = Offset(
        cos(angle) * headDistance,
        sin(angle) * headDistance,
      );

      // Glow halo
      canvas.drawCircle(
        offset,
        headRadius * 1.2,
        Paint()..color = _corePaint.color.withOpacity(0.18),
      );

      // Head body
      canvas.drawCircle(offset, headRadius, headPaint);
      canvas.drawCircle(offset, headRadius, outline);

      // Rotating sigil
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(_time * 0.8);

      final sigilPaint = Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.02;

      final r = headRadius * 0.55;
      final path = Path()
        ..moveTo(0, -r)
        ..lineTo(r * 0.87, r * 0.5)
        ..lineTo(-r * 0.87, r * 0.5)
        ..close();
      canvas.drawPath(path, sigilPaint);

      canvas.restore();

      // Eye
      final eyeOffset = Offset(
        cos(angle) * headRadius * 0.25,
        sin(angle) * headRadius * 0.25,
      );
      canvas.drawCircle(
        offset + eyeOffset,
        headRadius * 0.13,
        Paint()..color = Colors.white.withOpacity(0.9),
      );
    }

    // Connecting lines
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

  void _renderBossHpRing(Canvas canvas) {
    final hpRingRadius = radius * 0.95;
    final ringThickness = radius * 0.12;

    // Background
    canvas.drawCircle(
      Offset.zero,
      hpRingRadius,
      Paint()
        ..color = Colors.black.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringThickness
        ..strokeCap = StrokeCap.round,
    );

    // HP arc
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

    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: hpRingRadius),
      -pi / 2,
      hpAngle,
      false,
      Paint()
        ..color = hpColor.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringThickness - 2
        ..strokeCap = StrokeCap.round,
    );

    // Glow
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: hpRingRadius),
      -pi / 2,
      hpAngle,
      false,
      Paint()
        ..color = hpColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringThickness + 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Tick marks
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final percent in [0.75, 0.5, 0.25]) {
      final angle = -pi / 2 + percent * 2 * pi;
      final innerR = hpRingRadius - ringThickness / 2 - 2;
      final outerR = hpRingRadius + ringThickness / 2 + 2;
      canvas.drawLine(
        Offset(cos(angle) * innerR, sin(angle) * innerR),
        Offset(cos(angle) * outerR, sin(angle) * outerR),
        tickPaint,
      );
    }

    // Notch at current HP
    if (_displayedHp > 0.02 && _displayedHp < 0.98) {
      final notchAngle = -pi / 2 + hpAngle;
      canvas.drawCircle(
        Offset(cos(notchAngle) * hpRingRadius, sin(notchAngle) * hpRingRadius),
        ringThickness * 0.4,
        Paint()..color = Colors.white,
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
        i * arcSize + gap / 2,
        arcSize - gap,
        false,
        _outlinePaint,
      );
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// IMPROVED TRAIL SYSTEM - More particles, better performance via pooling
// ════════════════════════════════════════════════════════════════════════════

class ImprovedTrail extends PositionComponent {
  final Color color;
  final double radius;
  final int maxParticles;
  final bool isElite;

  final List<_TrailParticle> _particles = [];
  double _spawnTimer = 0;

  ImprovedTrail({
    required this.color,
    required this.radius,
    this.maxParticles = 12,
    this.isElite = false,
  }) : super(anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    if (parent is! PositionComponent) return;

    final parentPc = parent as PositionComponent;

    // Spawn new particles
    _spawnTimer += dt;
    final spawnRate = isElite ? 0.06 : 0.08;

    if (_spawnTimer > spawnRate && _particles.length < maxParticles) {
      _spawnTimer = 0;

      final size = radius * (0.4 + Random().nextDouble() * 0.3);
      _particles.add(
        _TrailParticle(
          position: Vector2.zero(),
          life: 1.0,
          maxLife: 1.0,
          size: size,
          velocity: Vector2(
            (Random().nextDouble() - 0.5) * 20,
            (Random().nextDouble() - 0.5) * 20,
          ),
        ),
      );
    }

    // Update existing particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.life -= dt * 1.8;
      p.position += p.velocity * dt;
      p.velocity *= 0.95; // Drag

      if (p.life <= 0) {
        _particles.removeAt(i);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint();

    for (final p in _particles) {
      final alpha = (p.life / p.maxLife).clamp(0.0, 1.0);
      paint.color = color.withOpacity(0.5 * alpha);

      final currentSize = p.size * alpha;
      canvas.drawCircle(p.position.toOffset(), currentSize, paint);

      // Elite enemies get extra glow
      if (isElite && alpha > 0.5) {
        paint.color = color.withOpacity(0.2 * alpha);
        canvas.drawCircle(p.position.toOffset(), currentSize * 1.5, paint);
      }
    }
  }
}

class _TrailParticle {
  Vector2 position;
  double life;
  double maxLife;
  double size;
  Vector2 velocity;

  _TrailParticle({
    required this.position,
    required this.life,
    required this.maxLife,
    required this.size,
    required this.velocity,
  });
}

// ════════════════════════════════════════════════════════════════════════════
// DEATH CASCADE SYSTEM - Satisfying chain explosions
// ════════════════════════════════════════════════════════════════════════════

class DeathCascadeManager extends Component {
  final List<_DeathEvent> _recentDeaths = [];
  static const double cascadeWindow = 0.5; // Seconds to count as "chain kill"
  static const int cascadeThreshold = 3; // Kills needed to trigger cascade

  int _currentChain = 0;
  double _chainTimer = 0;

  void registerDeath(
    Vector2 position,
    Color color,
    double radius,
    bool isBoss,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    _recentDeaths.add(
      _DeathEvent(
        position: position,
        color: color,
        radius: radius,
        timestamp: now,
        isBoss: isBoss,
      ),
    );

    // Clean old deaths
    _recentDeaths.removeWhere((d) => now - d.timestamp > cascadeWindow);

    // Check for cascade
    if (_recentDeaths.length >= cascadeThreshold) {
      _currentChain = _recentDeaths.length;
      _chainTimer = 0.3;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_chainTimer > 0) {
      _chainTimer -= dt;
      if (_chainTimer <= 0) {
        _currentChain = 0;
      }
    }

    // Clean old deaths
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    _recentDeaths.removeWhere((d) => now - d.timestamp > cascadeWindow);
  }

  int get currentChainCount => _currentChain;
  bool get isChaining => _currentChain >= cascadeThreshold;
}

class _DeathEvent {
  final Vector2 position;
  final Color color;
  final double radius;
  final double timestamp;
  final bool isBoss;

  _DeathEvent({
    required this.position,
    required this.color,
    required this.radius,
    required this.timestamp,
    required this.isBoss,
  });
}

/// Dramatic death explosion effect
class DeathExplosion extends PositionComponent {
  final Color color;
  final double radius;
  final bool isBoss;
  final int chainMultiplier;

  final List<_ExplosionParticle> _particles = [];
  final List<_ShockRing> _rings = [];
  double _time = 0;
  final Random _rng = Random();

  DeathExplosion({
    required Vector2 position,
    required this.color,
    required this.radius,
    this.isBoss = false,
    this.chainMultiplier = 1,
  }) : super(position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    // Spawn particles
    final particleCount = isBoss
        ? 40
        : (12 + chainMultiplier * 4).clamp(12, 30);

    for (int i = 0; i < particleCount; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = (100 + _rng.nextDouble() * 200) * (isBoss ? 1.5 : 1.0);
      final size = radius * (0.1 + _rng.nextDouble() * 0.2);

      _particles.add(
        _ExplosionParticle(
          position: Vector2.zero(),
          velocity: Vector2(cos(angle), sin(angle)) * speed,
          size: size,
          life: 0.5 + _rng.nextDouble() * 0.3,
          color: _rng.nextBool() ? color : Colors.white,
        ),
      );
    }

    // Spawn shock rings
    final ringCount = isBoss ? 3 : 1 + (chainMultiplier > 2 ? 1 : 0);
    for (int i = 0; i < ringCount; i++) {
      _rings.add(
        _ShockRing(
          radius: radius * 0.5,
          maxRadius: radius * (2.5 + i * 0.5),
          thickness: 4.0 - i,
          delay: i * 0.1,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    // Update particles
    for (final p in _particles) {
      p.life -= dt;
      p.position += p.velocity * dt;
      p.velocity *= 0.92; // Drag
    }
    _particles.removeWhere((p) => p.life <= 0);

    // Update rings
    for (final r in _rings) {
      if (_time > r.delay) {
        r.radius += dt * 400;
        r.opacity = 1.0 - (r.radius / r.maxRadius);
      }
    }
    _rings.removeWhere((r) => r.radius >= r.maxRadius);

    // Remove when done
    if (_particles.isEmpty && _rings.isEmpty) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    // Draw rings first (behind particles)
    for (final r in _rings) {
      if (_time > r.delay && r.opacity > 0) {
        canvas.drawCircle(
          Offset.zero,
          r.radius,
          Paint()
            ..color = color.withOpacity(r.opacity * 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r.thickness,
        );
      }
    }

    // Draw particles
    for (final p in _particles) {
      final alpha = (p.life * 2).clamp(0.0, 1.0);
      canvas.drawCircle(
        p.position.toOffset(),
        p.size * alpha,
        Paint()..color = p.color.withOpacity(alpha),
      );
    }

    // Central flash
    if (_time < 0.15) {
      final flashAlpha = 1.0 - (_time / 0.15);
      canvas.drawCircle(
        Offset.zero,
        radius * (0.8 + _time * 3),
        Paint()..color = Colors.white.withOpacity(flashAlpha * 0.8),
      );
    }
  }
}

class _ExplosionParticle {
  Vector2 position;
  Vector2 velocity;
  double size;
  double life;
  Color color;

  _ExplosionParticle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.life,
    required this.color,
  });
}

class _ShockRing {
  double radius;
  final double maxRadius;
  final double thickness;
  final double delay;
  double opacity = 1.0;

  _ShockRing({
    required this.radius,
    required this.maxRadius,
    required this.thickness,
    required this.delay,
  });
}
