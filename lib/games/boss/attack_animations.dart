// lib/game/attack_animations.dart
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'dart:math';

/// Registry of all attack animations by element and move type
class AttackAnimations {
  static AttackAnimation getAnimation(BattleMove move, String element) {
    // Special moves get enhanced animations
    if (move.isSpecial) {
      return _getSpecialAnimation(move.family!, element);
    }

    // Basic moves get elemental animations
    return _getElementalAnimation(element, move.type);
  }

  static AttackAnimation _getElementalAnimation(
    String element,
    MoveType moveType,
  ) {
    switch (element) {
      case 'Fire':
        return FireAnimation();
      case 'Water':
        return WaterAnimation();
      case 'Earth':
        return EarthAnimation();
      case 'Air':
        return AirAnimation();
      case 'Ice':
        return IceAnimation();
      case 'Lightning':
        return LightningAnimation();
      case 'Plant':
        return PlantAnimation();
      case 'Poison':
        return PoisonAnimation();
      case 'Steam':
        return SteamAnimation();
      case 'Lava':
        return LavaAnimation();
      case 'Mud':
        return MudAnimation();
      case 'Dust':
        return DustAnimation();
      case 'Crystal':
        return CrystalAnimation();
      case 'Spirit':
        return SpiritAnimation();
      case 'Dark':
        return DarkAnimation();
      case 'Light':
        return LightAnimation();
      case 'Blood':
        return BloodAnimation();
      default:
        return GenericAnimation();
    }
  }

  static AttackAnimation _getSpecialAnimation(String family, String element) {
    switch (family) {
      case 'Let':
        return SpritestrikAnimation(element);
      case 'Pip':
        return PipFuryAnimation(element);
      case 'Mane':
        return ManeTrickAnimation(element);
      case 'Horn':
        return HornGuardAnimation();
      case 'Mask':
        return MaskCurseAnimation(element);
      case 'Wing':
        return WingAssaultAnimation(element);
      case 'Kin':
        return KinBlessingAnimation(element);
      case 'Mystic':
        return MysticPowerAnimation(element);
      default:
        return _getElementalAnimation(element, MoveType.elemental);
    }
  }
}

/// Base class for attack animations
abstract class AttackAnimation {
  Component createEffect(Vector2 targetPosition);
}

// Helper to create circular particles
Component createCircleParticle(
  Vector2 position,
  Color color,
  double radius,
  double lifespan,
) {
  final circle = CircleComponent(
    radius: radius,
    position: position,
    paint: Paint()..color = color,
    anchor: Anchor.center,
  );

  circle.add(RemoveEffect(delay: lifespan));

  return circle;
}

// ============================================
// ELEMENTAL ANIMATIONS (17 types)
// ============================================

class FireAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Central impact flash
    final flash = CircleComponent(
      radius: 20,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.deepOrange.withValues(alpha: 0.7),
    );
    flash.add(
      ScaleEffect.to(
        Vector2.all(3.5),
        EffectController(duration: 0.35, curve: Curves.easeOut),
      ),
    );
    flash.add(RemoveEffect(delay: 0.35));
    container.add(flash);

    // Flame tongues: narrow rects that erupt upward from base
    final tongueColors = [
      Colors.orange,
      Colors.deepOrange,
      Colors.red.shade400,
      Colors.yellow.shade600,
    ];
    for (int i = 0; i < 7; i++) {
      final xOff = -50.0 + (i / 6) * 100;
      final h = 55.0 + rng.nextDouble() * 55;
      final w = 5.0 + rng.nextDouble() * 7;
      final tongue = RectangleComponent(
        size: Vector2(w, h),
        position: targetPosition + Vector2(xOff, 10),
        anchor: Anchor.bottomCenter,
        paint: Paint()..color = tongueColors[i % tongueColors.length],
      );
      tongue.add(
        MoveEffect.by(
          Vector2(xOff * 0.08, -h * 0.7),
          EffectController(
            duration: 0.3 + rng.nextDouble() * 0.15,
            curve: Curves.easeOut,
          ),
        ),
      );
      tongue.add(
        ScaleEffect.to(
          Vector2(0.1, 0.1),
          EffectController(duration: 0.5, curve: Curves.easeIn),
        ),
      );
      tongue.add(RemoveEffect(delay: 0.5));
      container.add(tongue);
    }

    // Embers scatter outward in upper semicircle
    for (int i = 0; i < 24; i++) {
      final angle = -pi + rng.nextDouble() * pi;
      final dist = 35.0 + rng.nextDouble() * 80;
      final ember = CircleComponent(
        radius: 1.5 + rng.nextDouble() * 2.5,
        position: targetPosition.clone(),
        anchor: Anchor.center,
        paint: Paint()
          ..color = [Colors.orange, Colors.yellow, Colors.red][rng.nextInt(3)],
      );
      ember.add(
        MoveEffect.by(
          Vector2(cos(angle) * dist, sin(angle) * dist - 18),
          EffectController(
            duration: 0.4 + rng.nextDouble() * 0.3,
            curve: Curves.easeOut,
          ),
        ),
      );
      ember.add(RemoveEffect(delay: 0.7));
      container.add(ember);
    }

    return container;
  }
}

class WaterAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Expanding ripple rings (3 staggered)
    for (int r = 0; r < 3; r++) {
      final ring = CircleComponent(
        radius: 12.0,
        position: targetPosition,
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.lightBlue.withValues(alpha: 0.65 - r * 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 - r * 0.5,
      );
      ring.add(
        ScaleEffect.to(
          Vector2.all(4.5 + r * 1.5),
          EffectController(duration: 0.5 + r * 0.1, curve: Curves.easeOut),
        ),
      );
      ring.add(RemoveEffect(delay: 0.6 + r * 0.1));
      container.add(ring);
    }

    // Droplets arc up then fall back down
    for (int i = 0; i < 24; i++) {
      final horizAngle = (i / 24) * 2 * pi;
      final xDist = cos(horizAngle) * (20 + rng.nextDouble() * 55);
      final drop = CircleComponent(
        radius: 2 + rng.nextDouble() * 2.5,
        position: targetPosition.clone(),
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.blue,
            Colors.lightBlue,
            Colors.cyan,
          ][rng.nextInt(3)].withValues(alpha: 0.85),
      );
      drop.add(
        SequenceEffect([
          MoveEffect.by(
            Vector2(xDist * 0.45, -48 - rng.nextDouble() * 28),
            EffectController(duration: 0.25, curve: Curves.easeOut),
          ),
          MoveEffect.by(
            Vector2(xDist * 0.55, 58 + rng.nextDouble() * 20),
            EffectController(duration: 0.28, curve: Curves.easeIn),
          ),
        ]),
      );
      drop.add(RemoveEffect(delay: 0.53));
      container.add(drop);
    }

    // Splash streaks at base
    for (int i = 0; i < 10; i++) {
      final angle = (i / 10) * 2 * pi;
      final len = 18.0 + rng.nextDouble() * 20;
      final streak = RectangleComponent(
        size: Vector2(len, 2),
        position: targetPosition.clone(),
        angle: angle,
        anchor: Anchor.centerLeft,
        paint: Paint()..color = Colors.cyan.withValues(alpha: 0.7),
      );
      streak.add(
        MoveEffect.by(
          Vector2(cos(angle) * 35, sin(angle) * 35),
          EffectController(duration: 0.28, curve: Curves.easeOut),
        ),
      );
      streak.add(RemoveEffect(delay: 0.28));
      container.add(streak);
    }

    return container;
  }
}

class EarthAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Ground crack ring expanding from impact
    final crackRing = CircleComponent(
      radius: 8,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()
        ..color = const Color(0xFF8B6914).withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    crackRing.add(
      ScaleEffect.to(
        Vector2.all(5.5),
        EffectController(duration: 0.4, curve: Curves.easeOut),
      ),
    );
    crackRing.add(RemoveEffect(delay: 0.4));
    container.add(crackRing);

    // Rock chunks erupt upward then fall with gravity
    final rockColors = [
      Colors.brown,
      Colors.brown.shade700,
      const Color(0xFF8B7355),
      Colors.grey.shade600,
    ];
    for (int i = 0; i < 14; i++) {
      final horizAngle = -pi + rng.nextDouble() * pi;
      final dist = 40.0 + rng.nextDouble() * 65;
      final sz = 5.0 + rng.nextDouble() * 9;
      final chunk = RectangleComponent(
        size: Vector2(sz, sz),
        position: targetPosition + Vector2(0, 8),
        anchor: Anchor.center,
        paint: Paint()..color = rockColors[i % rockColors.length],
      );
      chunk.add(
        SequenceEffect([
          MoveEffect.by(
            Vector2(cos(horizAngle) * dist, sin(horizAngle) * dist - 10),
            EffectController(duration: 0.3, curve: Curves.easeOut),
          ),
          MoveEffect.by(
            Vector2(cos(horizAngle) * 15, 55),
            EffectController(duration: 0.28, curve: Curves.easeIn),
          ),
        ]),
      );
      chunk.add(RemoveEffect(delay: 0.58));
      container.add(chunk);
    }

    // Dirt dust
    for (int i = 0; i < 18; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dust = CircleComponent(
        radius: 2 + rng.nextDouble() * 3,
        position: targetPosition.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.brown.withValues(alpha: 0.5),
      );
      dust.add(
        MoveEffect.by(
          Vector2(
            cos(angle) * (15 + rng.nextDouble() * 50),
            sin(angle) * (10 + rng.nextDouble() * 40),
          ),
          EffectController(duration: 0.5, curve: Curves.easeOut),
        ),
      );
      dust.add(RemoveEffect(delay: 0.5));
      container.add(dust);
    }

    return container;
  }
}

class AirAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Expanding wind rings – 4, staggered in time
    for (int r = 0; r < 4; r++) {
      final ring = CircleComponent(
        radius: 10,
        position: targetPosition,
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.white.withValues(alpha: 0.45 - r * 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 - r * 0.3,
      );
      ring.add(
        ScaleEffect.to(
          Vector2.all(5.5 + r * 2.0),
          EffectController(duration: 0.5 + r * 0.07, curve: Curves.easeOut),
        ),
      );
      ring.add(RemoveEffect(delay: 0.57 + r * 0.07));
      container.add(ring);
    }

    // Razor wind streaks slicing through target
    for (int i = 0; i < 6; i++) {
      final blade = (i / 6) * pi;
      final len = 90.0 + rng.nextDouble() * 60;
      final streak = RectangleComponent(
        size: Vector2(len, 2),
        position:
            targetPosition +
            Vector2(cos(blade + pi) * len / 2, sin(blade + pi) * len / 2),
        angle: blade,
        anchor: Anchor.centerLeft,
        paint: Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
      streak.add(
        ScaleEffect.to(
          Vector2.all(0),
          EffectController(duration: 0.4, curve: Curves.easeIn),
        ),
      );
      streak.add(RemoveEffect(delay: 0.4));
      container.add(streak);
    }

    // Debris flung in all directions
    for (int i = 0; i < 28; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist = 55.0 + rng.nextDouble() * 90;
      final debris = CircleComponent(
        radius: 1 + rng.nextDouble() * 1.5,
        position: targetPosition.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.white.withValues(alpha: 0.4),
      );
      debris.add(
        MoveEffect.by(
          Vector2(cos(angle) * dist, sin(angle) * dist),
          EffectController(duration: 0.55, curve: Curves.easeOut),
        ),
      );
      debris.add(RemoveEffect(delay: 0.55));
      container.add(debris);
    }

    return container;
  }
}

class IceAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Central freeze flash
    final flash = CircleComponent(
      radius: 15,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.lightBlue.withValues(alpha: 0.8),
    );
    flash.add(
      ScaleEffect.to(
        Vector2.all(2.5),
        EffectController(duration: 0.2, curve: Curves.easeOut),
      ),
    );
    flash.add(RemoveEffect(delay: 0.2));
    container.add(flash);

    // Frost ring
    final frostRing = CircleComponent(
      radius: 8,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.cyan.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    frostRing.add(
      ScaleEffect.to(
        Vector2.all(5.5),
        EffectController(duration: 0.55, curve: Curves.easeOut),
      ),
    );
    frostRing.add(RemoveEffect(delay: 0.55));
    container.add(frostRing);

    // Ice shards star-burst in 8 directions
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi;
      final len = 32.0 + rng.nextDouble() * 22;
      final shard = RectangleComponent(
        size: Vector2(4, len),
        position: targetPosition,
        angle: angle, // long axis along movement direction
        anchor: Anchor.center,
        paint: Paint()
          ..color = [Colors.cyan, Colors.lightBlue, Colors.white][i % 3],
      );
      shard.add(
        MoveEffect.by(
          Vector2(cos(angle) * (len + 28), sin(angle) * (len + 28)),
          EffectController(duration: 0.35, curve: Curves.easeOut),
        ),
      );
      shard.add(
        ScaleEffect.to(
          Vector2.all(0),
          EffectController(duration: 0.5, curve: Curves.easeIn),
        ),
      );
      shard.add(RemoveEffect(delay: 0.5));
      container.add(shard);
    }

    // Snowflakes/crystals drift down from above
    for (int i = 0; i < 22; i++) {
      final snow = CircleComponent(
        radius: 1.5 + rng.nextDouble() * 2,
        position:
            targetPosition +
            Vector2(-55 + rng.nextDouble() * 110, -65 - rng.nextDouble() * 30),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
      snow.add(
        MoveEffect.by(
          Vector2(-10 + rng.nextDouble() * 20, 80 + rng.nextDouble() * 30),
          EffectController(duration: 0.7, curve: Curves.easeIn),
        ),
      );
      snow.add(RemoveEffect(delay: 0.7));
      container.add(snow);
    }

    return container;
  }
}

class LightningAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final bolt = PositionComponent();
    final rng = Random();

    // Build a jagged bolt from above the target down to it
    const int segments = 7;
    final startY = targetPosition.y - 160.0;
    var prevX = targetPosition.x;
    var prevY = startY;

    for (int i = 0; i < segments; i++) {
      final progress = (i + 1) / segments;
      final nextY = startY + (targetPosition.y - startY) * progress;
      // Last segment points straight to target for a clean landing
      final nextX = (i == segments - 1)
          ? targetPosition.x
          : targetPosition.x + (rng.nextDouble() * 70 - 35);

      final dx = nextX - prevX;
      final dy = nextY - prevY;
      final length = sqrt(dx * dx + dy * dy);
      final angle = atan2(dy, dx);

      // Outer glow (yellow, wide)
      final glow = RectangleComponent(
        size: Vector2(length, 4),
        position: Vector2(prevX, prevY),
        angle: angle,
        anchor: Anchor.centerLeft,
        paint: Paint()..color = Colors.yellow.withValues(alpha: 0.7),
      );
      glow.add(RemoveEffect(delay: 0.25));
      bolt.add(glow);

      // Bright white core (narrow)
      final core = RectangleComponent(
        size: Vector2(length, 1.5),
        position: Vector2(prevX, prevY),
        angle: angle,
        anchor: Anchor.centerLeft,
        paint: Paint()..color = Colors.white,
      );
      core.add(RemoveEffect(delay: 0.25));
      bolt.add(core);

      prevX = nextX;
      prevY = nextY;
    }

    // Impact flash at landing point
    final impactFlash = CircleComponent(
      radius: 18,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.yellow.withValues(alpha: 0.75),
    );
    impactFlash.add(
      ScaleEffect.to(
        Vector2.all(2.5),
        EffectController(duration: 0.28, curve: Curves.easeOut),
      ),
    );
    impactFlash.add(RemoveEffect(delay: 0.28));
    bolt.add(impactFlash);

    // Scatter sparks outward from impact
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi;
      final spark = RectangleComponent(
        size: Vector2(8 + rng.nextDouble() * 10, 2),
        position: targetPosition.clone(),
        angle: angle,
        anchor: Anchor.centerLeft,
        paint: Paint()..color = Colors.yellow,
      );
      spark.add(
        MoveEffect.by(
          Vector2(cos(angle), sin(angle)) * (30 + rng.nextDouble() * 30),
          EffectController(duration: 0.3, curve: Curves.easeOut),
        ),
      );
      spark.add(RemoveEffect(delay: 0.3));
      bolt.add(spark);
    }

    return bolt;
  }
}

class PlantAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Vine spikes burst upward from below at varied angles
    for (int i = 0; i < 7; i++) {
      final angle = -pi + (i / 6) * pi;
      final len = 45.0 + rng.nextDouble() * 40;
      final vine = RectangleComponent(
        size: Vector2(4 + rng.nextDouble() * 3, len),
        position: targetPosition + Vector2(0, 14),
        angle: angle + pi / 2,
        anchor: Anchor.bottomCenter,
        paint: Paint()
          ..color = [
            Colors.green.shade700,
            Colors.green.shade500,
            const Color(0xFF228B22),
          ][i % 3],
      );
      vine.add(
        MoveEffect.by(
          Vector2(cos(angle) * len * 0.5, sin(angle) * len * 0.5),
          EffectController(duration: 0.3, curve: Curves.easeOut),
        ),
      );
      vine.add(
        ScaleEffect.to(
          Vector2.all(0),
          EffectController(duration: 0.55, curve: Curves.easeIn),
        ),
      );
      vine.add(RemoveEffect(delay: 0.55));
      container.add(vine);
    }

    // Leaf/petal burst scattered outward
    for (int i = 0; i < 20; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist = 35.0 + rng.nextDouble() * 60;
      final leaf = RectangleComponent(
        size: Vector2(6 + rng.nextDouble() * 5, 3 + rng.nextDouble() * 3),
        position: targetPosition.clone(),
        angle: angle,
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.green,
            Colors.lightGreen,
            Colors.lime.shade600,
          ][rng.nextInt(3)].withValues(alpha: 0.85),
      );
      leaf.add(
        MoveEffect.by(
          Vector2(cos(angle) * dist, sin(angle) * dist - 20),
          EffectController(duration: 0.5, curve: Curves.easeOut),
        ),
      );
      leaf.add(RemoveEffect(delay: 0.5));
      container.add(leaf);
    }

    // Ground glow
    final glow = CircleComponent(
      radius: 10,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.green.withValues(alpha: 0.4),
    );
    glow.add(
      ScaleEffect.to(
        Vector2.all(4),
        EffectController(duration: 0.3, curve: Curves.easeOut),
      ),
    );
    glow.add(RemoveEffect(delay: 0.3));
    container.add(glow);

    return container;
  }
}

class PoisonAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Toxic orb impact flash
    final orb = CircleComponent(
      radius: 18,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.purple.withValues(alpha: 0.55),
    );
    orb.add(
      ScaleEffect.to(
        Vector2.all(2.8),
        EffectController(duration: 0.3, curve: Curves.easeOut),
      ),
    );
    orb.add(RemoveEffect(delay: 0.3));
    container.add(orb);

    // Bubbles rising and popping (circles that grow then vanish)
    for (int i = 0; i < 14; i++) {
      final xOff = -40.0 + rng.nextDouble() * 80;
      final bubble = CircleComponent(
        radius: 3 + rng.nextDouble() * 5,
        position: targetPosition + Vector2(xOff, 10),
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.purple,
            Colors.green.shade700,
            Colors.lime.shade800,
          ][rng.nextInt(3)].withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      bubble.add(
        MoveEffect.by(
          Vector2(xOff * 0.15, -50 - rng.nextDouble() * 40),
          EffectController(
            duration: 0.6 + rng.nextDouble() * 0.3,
            curve: Curves.easeOut,
          ),
        ),
      );
      bubble.add(
        ScaleEffect.to(
          Vector2.all(1.8),
          EffectController(duration: 0.5 + rng.nextDouble() * 0.3),
        ),
      );
      bubble.add(RemoveEffect(delay: 0.85));
      container.add(bubble);
    }

    // Toxic gas drip particles
    for (int i = 0; i < 20; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist = 20.0 + rng.nextDouble() * 50;
      final drop = CircleComponent(
        radius: 2 + rng.nextDouble() * 2,
        position: targetPosition + Vector2(-25 + rng.nextDouble() * 50, -15),
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.purple.shade600,
            Colors.green.shade600,
            Colors.lime,
          ][rng.nextInt(3)].withValues(alpha: 0.65),
      );
      drop.add(
        MoveEffect.by(
          Vector2(cos(angle) * dist, sin(angle) * dist + 15),
          EffectController(duration: 0.7, curve: Curves.easeOut),
        ),
      );
      drop.add(RemoveEffect(delay: 0.7));
      container.add(drop);
    }

    return container;
  }
}

class SteamAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Heat shimmer rings
    for (int r = 0; r < 2; r++) {
      final ring = CircleComponent(
        radius: 10,
        position: targetPosition,
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      ring.add(
        ScaleEffect.to(
          Vector2.all(4.0 + r * 2),
          EffectController(duration: 0.45, curve: Curves.easeOut),
        ),
      );
      ring.add(RemoveEffect(delay: 0.45));
      container.add(ring);
    }

    // Scalding steam jets shooting upward in columns
    for (int i = 0; i < 6; i++) {
      final xOff = -55.0 + (i / 5) * 110;
      final colHeight = 60.0 + rng.nextDouble() * 55;
      for (int j = 0; j < 5; j++) {
        final puff = CircleComponent(
          radius: 5 + rng.nextDouble() * 7,
          position:
              targetPosition +
              Vector2(xOff + rng.nextDouble() * 12 - 6, -j * (colHeight / 5)),
          anchor: Anchor.center,
          paint: Paint()
            ..color = [
              Colors.grey.shade300,
              Colors.blueGrey.shade200,
              Colors.white70,
            ][rng.nextInt(3)].withValues(alpha: 0.45 - j * 0.07),
        );
        puff.add(
          MoveEffect.by(
            Vector2(rng.nextDouble() * 18 - 9, -colHeight * 0.55),
            EffectController(
              duration: 0.6 + rng.nextDouble() * 0.25,
              curve: Curves.easeOut,
            ),
          ),
        );
        puff.add(RemoveEffect(delay: 0.85));
        container.add(puff);
      }
    }

    return container;
  }
}

class LavaAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Lava pool glow at base
    final pool = CircleComponent(
      radius: 14,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.deepOrange.withValues(alpha: 0.55),
    );
    pool.add(
      ScaleEffect.to(
        Vector2.all(3.0),
        EffectController(duration: 0.35, curve: Curves.easeOut),
      ),
    );
    pool.add(RemoveEffect(delay: 0.35));
    container.add(pool);

    // Molten blobs arc inward from above
    for (int i = 0; i < 10; i++) {
      final xStart = -70.0 + rng.nextDouble() * 140;
      final blob = CircleComponent(
        radius: 4 + rng.nextDouble() * 5,
        position: targetPosition + Vector2(xStart, -90 - rng.nextDouble() * 40),
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.orange,
            Colors.deepOrange,
            Colors.red.shade800,
          ][rng.nextInt(3)],
      );
      blob.add(
        MoveEffect.by(
          Vector2(-xStart * 0.7, 90 + rng.nextDouble() * 45),
          EffectController(
            duration: 0.4 + rng.nextDouble() * 0.15,
            curve: Curves.easeIn,
          ),
        ),
      );
      blob.add(RemoveEffect(delay: 0.55));
      container.add(blob);
    }

    // Splatter on impact: short radial streaks
    for (int i = 0; i < 10; i++) {
      final angle = (i / 10) * 2 * pi;
      final len = 14.0 + rng.nextDouble() * 18;
      final splat = RectangleComponent(
        size: Vector2(len, 3),
        position: targetPosition.clone(),
        angle: angle,
        anchor: Anchor.centerLeft,
        paint: Paint()..color = Colors.orange.withValues(alpha: 0.75),
      );
      splat.add(
        MoveEffect.by(
          Vector2(cos(angle) * 45, sin(angle) * 45),
          EffectController(duration: 0.28, curve: Curves.easeOut),
        ),
      );
      splat.add(RemoveEffect(delay: 0.28));
      container.add(splat);
    }

    return container;
  }
}

class MudAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Heavy splat circle flattening horizontally
    final splat = RectangleComponent(
      size: Vector2(60, 18),
      position: targetPosition + Vector2(0, 10),
      anchor: Anchor.center,
      paint: Paint()..color = const Color(0xFF8B7355).withValues(alpha: 0.8),
    );
    splat.add(
      ScaleEffect.to(
        Vector2(2.8, 1.2),
        EffectController(duration: 0.25, curve: Curves.easeOut),
      ),
    );
    splat.add(
      ScaleEffect.to(
        Vector2.all(0),
        EffectController(duration: 0.4, curve: Curves.easeIn),
      ),
    );
    splat.add(RemoveEffect(delay: 0.65));
    container.add(splat);

    // Mud chunks fling outward at low angles
    for (int i = 0; i < 14; i++) {
      final angle = -pi * 0.2 + (i / 13) * pi * 1.4;
      final dist = 35.0 + rng.nextDouble() * 65;
      final sz = 4.0 + rng.nextDouble() * 7;
      final chunk = CircleComponent(
        radius: sz / 2,
        position: targetPosition.clone(),
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            const Color(0xFF8B7355),
            Colors.brown.shade600,
            Colors.brown.shade800,
          ][rng.nextInt(3)],
      );
      chunk.add(
        SequenceEffect([
          MoveEffect.by(
            Vector2(cos(angle) * dist, sin(angle) * dist - 12),
            EffectController(duration: 0.25, curve: Curves.easeOut),
          ),
          MoveEffect.by(
            Vector2(cos(angle) * 15, 30),
            EffectController(duration: 0.2, curve: Curves.easeIn),
          ),
        ]),
      );
      chunk.add(RemoveEffect(delay: 0.45));
      container.add(chunk);
    }

    // Mud drips from above
    for (int i = 0; i < 10; i++) {
      final drip = CircleComponent(
        radius: 3 + rng.nextDouble() * 3,
        position:
            targetPosition +
            Vector2(-45 + rng.nextDouble() * 90, -70 - rng.nextDouble() * 30),
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xFF8B7355).withValues(alpha: 0.7),
      );
      drip.add(
        MoveEffect.by(
          Vector2(-8 + rng.nextDouble() * 16, 80 + rng.nextDouble() * 25),
          EffectController(duration: 0.5, curve: Curves.easeIn),
        ),
      );
      drip.add(RemoveEffect(delay: 0.5));
      container.add(drip);
    }

    return container;
  }
}

class DustAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Swirling vortex: particles spawn in ring and spiral inward
    for (int i = 0; i < 40; i++) {
      final startAngle = (i / 40) * 2 * pi;
      final startRadius = 80.0 + rng.nextDouble() * 40;
      final startPos =
          targetPosition +
          Vector2(cos(startAngle) * startRadius, sin(startAngle) * startRadius);

      final particle = CircleComponent(
        radius: 1.5 + rng.nextDouble() * 2,
        position: startPos,
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.brown.shade300,
            Colors.orange.shade200,
            Colors.yellow.shade200,
          ][rng.nextInt(3)].withValues(alpha: 0.65),
      );

      // Spiral toward target
      final endAngle = startAngle + pi * 1.5;
      final endRadius = 10.0 + rng.nextDouble() * 15;
      particle.add(
        MoveEffect.to(
          targetPosition +
              Vector2(cos(endAngle) * endRadius, sin(endAngle) * endRadius),
          EffectController(
            duration: 0.55 + rng.nextDouble() * 0.2,
            curve: Curves.easeIn,
          ),
        ),
      );
      particle.add(RemoveEffect(delay: 0.75));
      container.add(particle);
    }

    // Outward burst after implosion
    for (int i = 0; i < 20; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final burst = CircleComponent(
        radius: 1 + rng.nextDouble() * 2,
        position: targetPosition.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.brown.shade200.withValues(alpha: 0.55),
      );
      burst.add(
        MoveEffect.by(
          Vector2(
            cos(angle) * (40 + rng.nextDouble() * 60),
            sin(angle) * (25 + rng.nextDouble() * 40),
          ),
          EffectController(duration: 0.35, curve: Curves.easeOut),
        ),
      );
      burst.add(RemoveEffect(delay: 0.35));
      container.add(burst);
    }

    return container;
  }
}

class CrystalAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Bright crystalline flash
    final flash = CircleComponent(
      radius: 12,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    flash.add(
      ScaleEffect.to(
        Vector2.all(3.0),
        EffectController(duration: 0.2, curve: Curves.easeOut),
      ),
    );
    flash.add(RemoveEffect(delay: 0.2));
    container.add(flash);

    // Crystal shard star: 10 shards at even angles
    for (int i = 0; i < 10; i++) {
      final angle = (i / 10) * 2 * pi;
      final len = 28.0 + rng.nextDouble() * 22;
      final shard = RectangleComponent(
        size: Vector2(3, len),
        position: targetPosition,
        angle: angle,
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.cyan,
            Colors.lightBlue,
            const Color(0xFFE0F7FA),
            Colors.pinkAccent.shade100,
          ][i % 4],
      );
      shard.add(
        MoveEffect.by(
          Vector2(cos(angle) * (len + 35), sin(angle) * (len + 35)),
          EffectController(duration: 0.38, curve: Curves.easeOut),
        ),
      );
      shard.add(
        ScaleEffect.to(
          Vector2.all(0),
          EffectController(duration: 0.55, curve: Curves.easeIn),
        ),
      );
      shard.add(RemoveEffect(delay: 0.55));
      container.add(shard);
    }

    // Shimmering sparkles orbiting briefly
    for (int i = 0; i < 16; i++) {
      final angle = (i / 16) * 2 * pi;
      final r2 = 30.0 + rng.nextDouble() * 25;
      final sparkle = CircleComponent(
        radius: 1.5 + rng.nextDouble() * 1.5,
        position: targetPosition + Vector2(cos(angle) * r2, sin(angle) * r2),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
      sparkle.add(
        MoveEffect.by(
          Vector2(cos(angle + pi) * r2 * 0.5, sin(angle + pi) * r2 * 0.5),
          EffectController(duration: 0.5, curve: Curves.easeOut),
        ),
      );
      sparkle.add(RemoveEffect(delay: 0.5));
      container.add(sparkle);
    }

    return container;
  }
}

class SpiritAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Ghostly wisps converge from surrounding area
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * pi;
      final startR = 80.0 + rng.nextDouble() * 40;
      final wisp = CircleComponent(
        radius: 4 + rng.nextDouble() * 5,
        position:
            targetPosition + Vector2(cos(angle) * startR, sin(angle) * startR),
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.white,
            Colors.indigo.shade100,
            Colors.deepPurple.shade100,
          ][i % 3].withValues(alpha: 0.6),
      );
      wisp.add(
        MoveEffect.to(
          targetPosition + Vector2(cos(angle) * 8, sin(angle) * 8),
          EffectController(duration: 0.45, curve: Curves.easeIn),
        ),
      );
      wisp.add(RemoveEffect(delay: 0.45));
      container.add(wisp);
    }

    // Impact flash then dissipate upward
    final impactFlash = CircleComponent(
      radius: 22,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
    impactFlash.add(
      ScaleEffect.to(Vector2.all(2.0), EffectController(duration: 0.2)),
    );
    impactFlash.add(RemoveEffect(delay: 0.5));
    container.add(impactFlash);

    // Spirit trails rising and fading
    for (int i = 0; i < 18; i++) {
      final xOff = -40.0 + rng.nextDouble() * 80;
      final trail = CircleComponent(
        radius: 2.5 + rng.nextDouble() * 3,
        position: targetPosition + Vector2(xOff, rng.nextDouble() * 10),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.white.withValues(alpha: 0.5),
      );
      trail.add(
        MoveEffect.by(
          Vector2(xOff * 0.1, -55 - rng.nextDouble() * 40),
          EffectController(duration: 0.8, curve: Curves.easeOut),
        ),
      );
      trail.add(RemoveEffect(delay: 0.8));
      container.add(trail);
    }

    return container;
  }
}

class DarkAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Phase 1: Void implosion — particles race inward
    for (int i = 0; i < 36; i++) {
      final angle = (i / 36) * 2 * pi;
      final startR = 90.0 + rng.nextDouble() * 50;
      final particle = CircleComponent(
        radius: 2 + rng.nextDouble() * 3,
        position:
            targetPosition + Vector2(cos(angle) * startR, sin(angle) * startR),
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.purple.shade900,
            Colors.deepPurple.shade700,
            Colors.black87,
          ][rng.nextInt(3)].withValues(alpha: 0.85),
      );
      particle.add(
        MoveEffect.to(
          targetPosition,
          EffectController(duration: 0.38, curve: Curves.easeIn),
        ),
      );
      particle.add(RemoveEffect(delay: 0.38));
      container.add(particle);
    }

    // Phase 2: Dark nova burst outward
    for (int i = 0; i < 30; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist = 60.0 + rng.nextDouble() * 90;
      final nova = CircleComponent(
        radius: 3 + rng.nextDouble() * 4,
        position: targetPosition.clone(),
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.deepPurple,
            Colors.purple.shade800,
            Colors.indigo.shade900,
          ][rng.nextInt(3)].withValues(alpha: 0.8),
      );
      nova.add(
        MoveEffect.by(
          Vector2(cos(angle) * dist, sin(angle) * dist),
          EffectController(duration: 0.45, curve: Curves.easeOut),
        ),
      );
      nova.add(RemoveEffect(delay: 0.8));
      container.add(nova);
    }

    // Void ring expanding
    final voidRing = CircleComponent(
      radius: 10,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.deepPurple.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    voidRing.add(
      ScaleEffect.to(
        Vector2.all(5.0),
        EffectController(duration: 0.45, curve: Curves.easeOut),
      ),
    );
    voidRing.add(RemoveEffect(delay: 0.45));
    container.add(voidRing);

    return container;
  }
}

class LightAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Blinding central flash
    final flash = CircleComponent(
      radius: 20,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    flash.add(
      ScaleEffect.to(
        Vector2.all(3.5),
        EffectController(duration: 0.25, curve: Curves.easeOut),
      ),
    );
    flash.add(RemoveEffect(delay: 0.25));
    container.add(flash);

    // 4 cardinal beams + 4 diagonal = 8 beams total
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi;
      final isDiag = i % 2 == 1;
      final beamLen = isDiag
          ? 55.0 + rng.nextDouble() * 30
          : 80.0 + rng.nextDouble() * 30;
      final beam = RectangleComponent(
        size: Vector2(isDiag ? 3 : 5, beamLen),
        position: targetPosition,
        angle: angle,
        anchor: Anchor.bottomCenter,
        paint: Paint()
          ..color = (isDiag ? Colors.yellow.shade300 : Colors.white)
              .withValues(alpha: 0.85),
      );
      beam.add(
        SequenceEffect([
          ScaleEffect.to(Vector2(1.0, 1.0), EffectController(duration: 0.0)),
          MoveEffect.by(
            Vector2(cos(angle) * beamLen * 0.4, sin(angle) * beamLen * 0.4),
            EffectController(duration: 0.3, curve: Curves.easeOut),
          ),
        ]),
      );
      beam.add(
        ScaleEffect.to(
          Vector2.all(0),
          EffectController(duration: 0.45, curve: Curves.easeIn),
        ),
      );
      beam.add(RemoveEffect(delay: 0.45));
      container.add(beam);
    }

    // Scatter sparkles
    for (int i = 0; i < 22; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist = 40.0 + rng.nextDouble() * 80;
      final sparkle = CircleComponent(
        radius: 1.5 + rng.nextDouble() * 2,
        position: targetPosition.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.yellow.withValues(alpha: 0.8),
      );
      sparkle.add(
        MoveEffect.by(
          Vector2(cos(angle) * dist, sin(angle) * dist),
          EffectController(duration: 0.5, curve: Curves.easeOut),
        ),
      );
      sparkle.add(RemoveEffect(delay: 0.5));
      container.add(sparkle);
    }

    return container;
  }
}

class BloodAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Arterial spray arcs (3 distinct streams)
    for (int s = 0; s < 3; s++) {
      final baseAngle = -pi * 0.3 + s * (pi * 0.3);
      for (int i = 0; i < 10; i++) {
        final angle = baseAngle + (rng.nextDouble() - 0.5) * 0.4;
        final dist = 35.0 + rng.nextDouble() * 75;
        final droplet = CircleComponent(
          radius: 2 + rng.nextDouble() * 3.5,
          position: targetPosition.clone(),
          anchor: Anchor.center,
          paint: Paint()
            ..color = [
              Colors.red.shade900,
              Colors.red.shade700,
              Colors.red.shade800,
            ][rng.nextInt(3)],
        );
        droplet.add(
          SequenceEffect([
            MoveEffect.by(
              Vector2(cos(angle) * dist, sin(angle) * dist - 12),
              EffectController(duration: 0.22, curve: Curves.easeOut),
            ),
            MoveEffect.by(
              Vector2(cos(angle) * 15, 35 + rng.nextDouble() * 20),
              EffectController(duration: 0.2, curve: Curves.easeIn),
            ),
          ]),
        );
        droplet.add(RemoveEffect(delay: 0.42));
        container.add(droplet);
      }
    }

    // Splatter pattern at base
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi;
      final len = 10.0 + rng.nextDouble() * 14;
      final splat = RectangleComponent(
        size: Vector2(len, 2.5),
        position: targetPosition.clone(),
        angle: angle,
        anchor: Anchor.centerLeft,
        paint: Paint()..color = Colors.red.shade900.withValues(alpha: 0.75),
      );
      splat.add(
        MoveEffect.by(
          Vector2(cos(angle) * 30, sin(angle) * 30),
          EffectController(duration: 0.22, curve: Curves.easeOut),
        ),
      );
      splat.add(RemoveEffect(delay: 0.22));
      container.add(splat);
    }

    return container;
  }
}

class GenericAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Expanding energy ring
    final ring = CircleComponent(
      radius: 12,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    ring.add(
      ScaleEffect.to(
        Vector2.all(4.0),
        EffectController(duration: 0.35, curve: Curves.easeOut),
      ),
    );
    ring.add(RemoveEffect(delay: 0.35));
    container.add(ring);

    // Radiating sparks
    for (int i = 0; i < 16; i++) {
      final angle = (i / 16) * 2 * pi;
      final dist = 40.0 + rng.nextDouble() * 50;
      final spark = CircleComponent(
        radius: 2 + rng.nextDouble() * 2,
        position: targetPosition.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
      spark.add(
        MoveEffect.by(
          Vector2(cos(angle) * dist, sin(angle) * dist),
          EffectController(duration: 0.4, curve: Curves.easeOut),
        ),
      );
      spark.add(RemoveEffect(delay: 0.4));
      container.add(spark);
    }

    return container;
  }
}

// ============================================
// SPECIAL ABILITY ANIMATIONS (8 families)
// ============================================

class SpritestrikAnimation extends AttackAnimation {
  final String element;
  SpritestrikAnimation(this.element);

  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Three rapid slash marks in quick succession at different angles
    final slashAngles = [pi * 0.8, pi * 1.0, pi * 1.2];
    for (int s = 0; s < 3; s++) {
      final slashAngle = slashAngles[s];
      final slashLen = 70.0 + rng.nextDouble() * 30;
      final offset = Vector2(-12.0 + s * 12, -8.0 + s * 8);

      // Outer glow slash
      final glowSlash = RectangleComponent(
        size: Vector2(slashLen, 6),
        position: targetPosition + offset,
        angle: slashAngle,
        anchor: Anchor.center,
        paint: Paint()..color = Colors.white.withValues(alpha: 0.5),
      );
      glowSlash.add(
        ScaleEffect.to(Vector2(1.0, 3.0), EffectController(duration: 0.05)),
      );
      glowSlash.add(
        ScaleEffect.to(
          Vector2.all(0),
          EffectController(duration: 0.2, curve: Curves.easeIn),
        ),
      );
      glowSlash.add(RemoveEffect(delay: 0.25));
      container.add(glowSlash);

      // Sharp core slash
      final coreSlash = RectangleComponent(
        size: Vector2(slashLen, 2),
        position: targetPosition + offset,
        angle: slashAngle,
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.white,
            Colors.cyan.shade200,
            Colors.yellow.shade200,
          ][s],
      );
      coreSlash.add(
        ScaleEffect.to(
          Vector2.all(0),
          EffectController(duration: 0.22, curve: Curves.easeIn),
        ),
      );
      coreSlash.add(RemoveEffect(delay: 0.22));
      container.add(coreSlash);
    }

    // Impact sparks from the hits
    for (int i = 0; i < 16; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist = 25.0 + rng.nextDouble() * 45;
      final spark = CircleComponent(
        radius: 1.5 + rng.nextDouble() * 2,
        position: targetPosition.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
      spark.add(
        MoveEffect.by(
          Vector2(cos(angle) * dist, sin(angle) * dist),
          EffectController(duration: 0.3, curve: Curves.easeOut),
        ),
      );
      spark.add(RemoveEffect(delay: 0.3));
      container.add(spark);
    }

    return container;
  }
}

class PipFuryAnimation extends AttackAnimation {
  final String element;
  PipFuryAnimation(this.element);

  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();
    final elementColor = _elementColor(element);

    // 5-hit rapid fire: small projectile bursts converging on target
    for (int burst = 0; burst < 5; burst++) {
      final spreadX = -30.0 + burst * 15;
      final startPos =
          targetPosition + Vector2(spreadX, -80 - rng.nextDouble() * 30);

      final projectile = CircleComponent(
        radius: 4 + rng.nextDouble() * 3,
        position: startPos,
        anchor: Anchor.center,
        paint: Paint()..color = elementColor.withValues(alpha: 0.9),
      );
      projectile.add(
        MoveEffect.to(
          targetPosition + Vector2(spreadX * 0.2, 0),
          EffectController(duration: 0.18, curve: Curves.easeIn),
        ),
      );
      projectile.add(RemoveEffect(delay: 0.18));
      container.add(projectile);

      // Mini-impact on landing
      final impact = CircleComponent(
        radius: 8,
        position: targetPosition + Vector2(spreadX * 0.2, 0),
        anchor: Anchor.center,
        paint: Paint()..color = elementColor.withValues(alpha: 0.55),
      );
      impact.add(
        ScaleEffect.to(
          Vector2.all(2.2),
          EffectController(duration: 0.18, curve: Curves.easeOut),
        ),
      );
      impact.add(RemoveEffect(delay: 0.18));
      container.add(impact);
    }

    // Final explosive burst combining all hits
    final finalFlash = CircleComponent(
      radius: 15,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()..color = elementColor.withValues(alpha: 0.7),
    );
    finalFlash.add(
      ScaleEffect.to(
        Vector2.all(3.5),
        EffectController(duration: 0.3, curve: Curves.easeOut),
      ),
    );
    finalFlash.add(RemoveEffect(delay: 0.3));
    container.add(finalFlash);

    // Scatter shrapnel
    for (int i = 0; i < 20; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist = 30.0 + rng.nextDouble() * 55;
      final shard = CircleComponent(
        radius: 1.5 + rng.nextDouble() * 2,
        position: targetPosition.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = elementColor.withValues(alpha: 0.75),
      );
      shard.add(
        MoveEffect.by(
          Vector2(cos(angle) * dist, sin(angle) * dist),
          EffectController(duration: 0.35, curve: Curves.easeOut),
        ),
      );
      shard.add(RemoveEffect(delay: 0.35));
      container.add(shard);
    }

    return container;
  }

  Color _elementColor(String element) {
    switch (element) {
      case 'Fire':
        return Colors.orange;
      case 'Water':
        return Colors.cyan;
      case 'Earth':
        return Colors.brown.shade400;
      case 'Air':
        return Colors.white;
      case 'Ice':
        return Colors.lightBlue;
      case 'Lightning':
        return Colors.yellow;
      case 'Plant':
        return Colors.green;
      case 'Poison':
        return Colors.purple;
      case 'Dark':
        return Colors.deepPurple;
      case 'Light':
        return Colors.yellow.shade200;
      case 'Blood':
        return Colors.red.shade700;
      default:
        return Colors.white;
    }
  }
}

class ManeTrickAnimation extends AttackAnimation {
  final String element;
  ManeTrickAnimation(this.element);

  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Illusion trick: three ghost-images offset around the real hit
    final offsets = [Vector2(-28, -14), Vector2(28, -14), Vector2(0, 0)];

    for (int g = 0; g < 3; g++) {
      final ghostPos = targetPosition + offsets[g];
      final isReal = g == 2;
      final alpha = isReal ? 0.85 : 0.35;

      // Ghost silhouette ring
      final ghost = CircleComponent(
        radius: 22,
        position: ghostPos,
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.purple.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      ghost.add(
        ScaleEffect.to(
          Vector2.all(isReal ? 2.0 : 1.5),
          EffectController(duration: 0.35, curve: Curves.easeOut),
        ),
      );
      ghost.add(RemoveEffect(delay: 0.35));
      container.add(ghost);

      // Ghost scatter particles
      for (int i = 0; i < (isReal ? 16 : 8); i++) {
        final angle = rng.nextDouble() * 2 * pi;
        final dist = 20.0 + rng.nextDouble() * 45;
        final particle = CircleComponent(
          radius: 2 + rng.nextDouble() * 2,
          position: ghostPos.clone(),
          anchor: Anchor.center,
          paint: Paint()
            ..color = [
              Colors.purple,
              Colors.deepPurple.shade300,
              Colors.pinkAccent.shade100,
            ][rng.nextInt(3)].withValues(alpha: alpha * 0.8),
        );
        particle.add(
          MoveEffect.by(
            Vector2(cos(angle) * dist, sin(angle) * dist),
            EffectController(duration: 0.4, curve: Curves.easeOut),
          ),
        );
        particle.add(RemoveEffect(delay: 0.4));
        container.add(particle);
      }
    }

    // Confusion swirl rings connecting the three ghosts
    for (int r = 0; r < 3; r++) {
      final swirl = CircleComponent(
        radius: 6,
        position: targetPosition,
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.purple.shade300.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      swirl.add(
        ScaleEffect.to(
          Vector2.all(6.0 + r * 2.5),
          EffectController(duration: 0.45 + r * 0.05, curve: Curves.easeOut),
        ),
      );
      swirl.add(RemoveEffect(delay: 0.5 + r * 0.05));
      container.add(swirl);
    }

    return container;
  }
}

class HornGuardAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Shield barrier: 3 expanding rings, bright blue
    for (int r = 0; r < 3; r++) {
      final shield = CircleComponent(
        radius: 15,
        position: targetPosition,
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.lightBlue,
            Colors.cyan,
            Colors.blue.shade300,
          ][r].withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 - r * 1.0,
      );
      shield.add(
        ScaleEffect.to(
          Vector2.all(3.5 + r * 1.2),
          EffectController(duration: 0.4 + r * 0.08, curve: Curves.easeOut),
        ),
      );
      shield.add(RemoveEffect(delay: 0.45 + r * 0.08));
      container.add(shield);
    }

    // Defensive spikes radiating outward
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi;
      final spikeLen = 35.0 + rng.nextDouble() * 20;
      final spike = RectangleComponent(
        size: Vector2(3, spikeLen),
        position: targetPosition + Vector2(cos(angle) * 28, sin(angle) * 28),
        angle: angle,
        anchor: Anchor.bottomCenter,
        paint: Paint()..color = Colors.lightBlue.withValues(alpha: 0.8),
      );
      spike.add(
        MoveEffect.by(
          Vector2(cos(angle) * spikeLen * 0.7, sin(angle) * spikeLen * 0.7),
          EffectController(duration: 0.3, curve: Curves.easeOut),
        ),
      );
      spike.add(
        ScaleEffect.to(
          Vector2.all(0),
          EffectController(duration: 0.4, curve: Curves.easeIn),
        ),
      );
      spike.add(RemoveEffect(delay: 0.4));
      container.add(spike);
    }

    // Solid shield flash
    final fill = CircleComponent(
      radius: 22,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.cyan.withValues(alpha: 0.3),
    );
    fill.add(
      ScaleEffect.to(Vector2.all(2.5), EffectController(duration: 0.25)),
    );
    fill.add(RemoveEffect(delay: 0.25));
    container.add(fill);

    return container;
  }
}

class MaskCurseAnimation extends AttackAnimation {
  final String element;
  MaskCurseAnimation(this.element);

  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Dark tendrils spiral inward from a wide ring
    for (int i = 0; i < 12; i++) {
      final startAngle = (i / 12) * 2 * pi;
      final startR = 95.0 + rng.nextDouble() * 30;

      // The tendril: a thin rect that travels inward
      final tendril = RectangleComponent(
        size: Vector2(2.5, 20 + rng.nextDouble() * 12),
        position:
            targetPosition +
            Vector2(cos(startAngle) * startR, sin(startAngle) * startR),
        angle: startAngle + pi / 2,
        anchor: Anchor.center,
        paint: Paint()..color = Colors.purple.shade900.withValues(alpha: 0.85),
      );
      tendril.add(
        MoveEffect.to(
          targetPosition + Vector2(cos(startAngle) * 6, sin(startAngle) * 6),
          EffectController(duration: 0.5, curve: Curves.easeIn),
        ),
      );
      tendril.add(RemoveEffect(delay: 0.5));
      container.add(tendril);

      // End-point particle at the tendril tip
      final dot = CircleComponent(
        radius: 2 + rng.nextDouble() * 2,
        position:
            targetPosition +
            Vector2(cos(startAngle) * startR, sin(startAngle) * startR),
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.purple.shade900,
            Colors.deepPurple.shade800,
            Colors.black87,
          ][rng.nextInt(3)].withValues(alpha: 0.8),
      );
      dot.add(
        MoveEffect.to(
          targetPosition,
          EffectController(duration: 0.5, curve: Curves.easeIn),
        ),
      );
      dot.add(RemoveEffect(delay: 0.5));
      container.add(dot);
    }

    // Soul-drain nova at center after tendrils arrive
    final nova = CircleComponent(
      radius: 12,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.deepPurple.shade900.withValues(alpha: 0.8),
    );
    nova.add(
      ScaleEffect.to(
        Vector2.all(3.2),
        EffectController(duration: 0.35, curve: Curves.easeOut),
      ),
    );
    nova.add(RemoveEffect(delay: 0.55));
    container.add(nova);

    // Curse ring
    final curseRing = CircleComponent(
      radius: 10,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.purple.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    curseRing.add(
      ScaleEffect.to(
        Vector2.all(4.5),
        EffectController(duration: 0.45, curve: Curves.easeOut),
      ),
    );
    curseRing.add(RemoveEffect(delay: 0.45));
    container.add(curseRing);

    return container;
  }
}

class WingAssaultAnimation extends AttackAnimation {
  final String element;
  WingAssaultAnimation(this.element);

  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Feather barrage: fan of feather-shaped streak lines
    for (int i = 0; i < 9; i++) {
      final fanAngle = -pi * 0.55 + (i / 8) * pi * 1.1;
      final featherLen = 50.0 + rng.nextDouble() * 35;
      final startPos =
          targetPosition +
          Vector2(
            cos(fanAngle) * (featherLen + 20),
            sin(fanAngle) * (featherLen + 20),
          );

      // Feather shaft
      final shaft = RectangleComponent(
        size: Vector2(2.5, featherLen),
        position: startPos,
        angle: fanAngle + pi / 2,
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.orange.shade300,
            Colors.amber,
            Colors.yellow.shade600,
          ][i % 3].withValues(alpha: 0.85),
      );
      shaft.add(
        MoveEffect.to(
          targetPosition + Vector2(cos(fanAngle) * 8, sin(fanAngle) * 8),
          EffectController(duration: 0.28, curve: Curves.easeIn),
        ),
      );
      shaft.add(RemoveEffect(delay: 0.28));
      container.add(shaft);

      // Feather barb (shorter perpendicular rect)
      final barb = RectangleComponent(
        size: Vector2(featherLen * 0.4, 1.5),
        position: startPos + Vector2(cos(fanAngle) * 10, sin(fanAngle) * 10),
        angle: fanAngle,
        anchor: Anchor.center,
        paint: Paint()..color = Colors.orange.shade100.withValues(alpha: 0.6),
      );
      barb.add(
        MoveEffect.to(
          targetPosition + Vector2(cos(fanAngle) * 10, sin(fanAngle) * 10),
          EffectController(duration: 0.28, curve: Curves.easeIn),
        ),
      );
      barb.add(RemoveEffect(delay: 0.28));
      container.add(barb);
    }

    // Wind impact burst at landing
    final windBurst = CircleComponent(
      radius: 16,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.orange.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    windBurst.add(
      ScaleEffect.to(
        Vector2.all(3.5),
        EffectController(duration: 0.35, curve: Curves.easeOut),
      ),
    );
    windBurst.add(RemoveEffect(delay: 0.35));
    container.add(windBurst);

    // Scatter sparks
    for (int i = 0; i < 18; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist = 35.0 + rng.nextDouble() * 70;
      final spark = CircleComponent(
        radius: 2 + rng.nextDouble() * 2.5,
        position: targetPosition.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.orange.withValues(alpha: 0.75),
      );
      spark.add(
        MoveEffect.by(
          Vector2(cos(angle) * dist, sin(angle) * dist),
          EffectController(duration: 0.4, curve: Curves.easeOut),
        ),
      );
      spark.add(RemoveEffect(delay: 0.4));
      container.add(spark);
    }

    return container;
  }
}

class KinBlessingAnimation extends AttackAnimation {
  final String element;
  KinBlessingAnimation(this.element);

  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Healing aura: 3 expanding green rings
    for (int r = 0; r < 3; r++) {
      final ring = CircleComponent(
        radius: 12,
        position: targetPosition,
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.green,
            Colors.lightGreen,
            Colors.greenAccent,
          ][r].withValues(alpha: 0.6 - r * 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 - r * 0.8,
      );
      ring.add(
        ScaleEffect.to(
          Vector2.all(4.5 + r * 1.5),
          EffectController(duration: 0.45 + r * 0.08, curve: Curves.easeOut),
        ),
      );
      ring.add(RemoveEffect(delay: 0.5 + r * 0.08));
      container.add(ring);
    }

    // Radiant fill
    final fill = CircleComponent(
      radius: 20,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.green.withValues(alpha: 0.25),
    );
    fill.add(ScaleEffect.to(Vector2.all(3), EffectController(duration: 0.3)));
    fill.add(RemoveEffect(delay: 0.3));
    container.add(fill);

    // Plus/cross symbol: two rects
    for (int axis = 0; axis < 2; axis++) {
      final crossBar = RectangleComponent(
        size: axis == 0 ? Vector2(40, 4) : Vector2(4, 40),
        position: targetPosition,
        anchor: Anchor.center,
        paint: Paint()..color = Colors.lightGreen.withValues(alpha: 0.85),
      );
      crossBar.add(
        ScaleEffect.to(
          Vector2.all(0),
          EffectController(duration: 0.4, curve: Curves.easeIn),
        ),
      );
      crossBar.add(RemoveEffect(delay: 0.4));
      container.add(crossBar);
    }

    // Sparkles floating upward
    for (int i = 0; i < 22; i++) {
      final xOff = -45.0 + rng.nextDouble() * 90;
      final sparkle = CircleComponent(
        radius: 2 + rng.nextDouble() * 2.5,
        position: targetPosition + Vector2(xOff, rng.nextDouble() * 10),
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.greenAccent,
            Colors.lightGreen,
            Colors.yellow.shade400,
          ][rng.nextInt(3)].withValues(alpha: 0.8),
      );
      sparkle.add(
        MoveEffect.by(
          Vector2(xOff * 0.1, -55 - rng.nextDouble() * 40),
          EffectController(
            duration: 0.7 + rng.nextDouble() * 0.25,
            curve: Curves.easeOut,
          ),
        ),
      );
      sparkle.add(RemoveEffect(delay: 0.95));
      container.add(sparkle);
    }

    return container;
  }
}

class MysticPowerAnimation extends AttackAnimation {
  final String element;
  MysticPowerAnimation(this.element);

  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();
    final rng = Random();

    // Double elemental burst
    final base1 = AttackAnimations._getElementalAnimation(
      element,
      MoveType.elemental,
    );
    container.add(base1.createEffect(targetPosition));

    // Second displaced burst for scale
    final offset = Vector2(
      rng.nextDouble() * 20 - 10,
      rng.nextDouble() * 20 - 10,
    );
    final base2 = AttackAnimations._getElementalAnimation(
      element,
      MoveType.elemental,
    );
    container.add(base2.createEffect(targetPosition + offset));

    // Arcane magic circles: 3 concentric rings in gold/white
    for (int r = 0; r < 3; r++) {
      final circle = CircleComponent(
        radius: 14,
        position: targetPosition,
        anchor: Anchor.center,
        paint: Paint()
          ..color = [
            Colors.amber,
            Colors.white,
            Colors.yellow.shade300,
          ][r].withValues(alpha: 0.55 - r * 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      circle.add(
        ScaleEffect.to(
          Vector2.all(5.0 + r * 2.0),
          EffectController(duration: 0.5 + r * 0.1, curve: Curves.easeOut),
        ),
      );
      circle.add(RemoveEffect(delay: 0.6 + r * 0.1));
      container.add(circle);
    }

    // Arcane rune sparks: 8-pointed burst
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi;
      final len = 30.0 + rng.nextDouble() * 20;
      final rune = RectangleComponent(
        size: Vector2(2.5, len),
        position: targetPosition,
        angle: angle,
        anchor: Anchor.center,
        paint: Paint()..color = Colors.amber.withValues(alpha: 0.8),
      );
      rune.add(
        MoveEffect.by(
          Vector2(cos(angle) * (len + 30), sin(angle) * (len + 30)),
          EffectController(duration: 0.35, curve: Curves.easeOut),
        ),
      );
      rune.add(
        ScaleEffect.to(Vector2.all(0), EffectController(duration: 0.45)),
      );
      rune.add(RemoveEffect(delay: 0.45));
      container.add(rune);
    }

    return container;
  }
}
