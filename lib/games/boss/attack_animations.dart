// lib/game/attack_animations.dart
import 'package:alchemons/services/boss_battle_engine_service.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
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

    for (int i = 0; i < 30; i++) {
      final angle = (i / 30) * 2 * pi;
      final speed = 100 + Random().nextDouble() * 50;
      final velocity = Vector2(cos(angle), sin(angle)) * speed;

      final particle = CircleComponent(
        radius: 3 + Random().nextDouble() * 3,
        position: targetPosition.clone(),
        paint: Paint()
          ..color = [
            Colors.orange,
            Colors.red,
            Colors.yellow,
          ][Random().nextInt(3)],
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          velocity * 0.006, // Convert velocity to pixels
          EffectController(duration: 0.6, curve: Curves.easeOut),
        ),
      );

      particle.add(RemoveEffect(delay: 0.6));

      container.add(particle);
    }

    return container;
  }
}

class WaterAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 40; i++) {
      final particle = CircleComponent(
        radius: 2 + Random().nextDouble() * 2,
        position:
            targetPosition + Vector2(-25 + Random().nextDouble() * 50, -50),
        paint: Paint()..color = Colors.blue.withOpacity(0.7),
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(-25 + Random().nextDouble() * 50, 100),
          EffectController(duration: 0.8, curve: Curves.easeIn),
        ),
      );

      particle.add(RemoveEffect(delay: 0.8));

      container.add(particle);
    }

    return container;
  }
}

class EarthAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 25; i++) {
      final particle = RectangleComponent(
        size: Vector2.all(4 + Random().nextDouble() * 4),
        position: targetPosition + Vector2(0, 50),
        paint: Paint()..color = Colors.brown,
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(-30 + Random().nextDouble() * 60, -40),
          EffectController(duration: 0.5, curve: Curves.easeOut),
        ),
      );

      particle.add(RemoveEffect(delay: 0.5));

      container.add(particle);
    }

    return container;
  }
}

class AirAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 50; i++) {
      final angle = Random().nextDouble() * 2 * pi;
      final distance = 150 + Random().nextDouble() * 100;

      final particle = CircleComponent(
        radius: 1 + Random().nextDouble() * 2,
        position: targetPosition.clone(),
        paint: Paint()..color = Colors.white.withOpacity(0.5),
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(cos(angle), sin(angle)) * distance,
          EffectController(duration: 0.7),
        ),
      );

      particle.add(RemoveEffect(delay: 0.7));

      container.add(particle);
    }

    return container;
  }
}

class IceAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 35; i++) {
      final particle = CircleComponent(
        radius: 2 + Random().nextDouble() * 3,
        position:
            targetPosition + Vector2(-40 + Random().nextDouble() * 80, -80),
        paint: Paint()..color = Colors.cyan.withOpacity(0.8),
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(-20 + Random().nextDouble() * 40, 80),
          EffectController(duration: 1.0, curve: Curves.easeIn),
        ),
      );

      particle.add(RemoveEffect(delay: 1.0));

      container.add(particle);
    }

    return container;
  }
}

class LightningAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    // Lightning bolt using rectangles
    final bolt = Component();

    for (int i = 0; i < 5; i++) {
      final segment = RectangleComponent(
        size: Vector2(3, 20),
        position:
            targetPosition +
            Vector2(
              -10 + Random().nextDouble() * 20,
              -40 + (i * 15).toDouble(),
            ),
        paint: Paint()..color = Colors.yellow,
        anchor: Anchor.center,
      );

      segment.add(RemoveEffect(delay: 0.3));

      bolt.add(segment);
    }

    return bolt;
  }
}

class PlantAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 30; i++) {
      final particle = RectangleComponent(
        size: Vector2(3, 6),
        position:
            targetPosition + Vector2(-30 + Random().nextDouble() * 60, -60),
        paint: Paint()..color = Colors.green,
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(-15 + Random().nextDouble() * 30, 60),
          EffectController(duration: 0.8, curve: Curves.easeIn),
        ),
      );

      particle.add(RemoveEffect(delay: 0.8));

      container.add(particle);
    }

    return container;
  }
}

class PoisonAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 40; i++) {
      final particle = CircleComponent(
        radius: 2 + Random().nextDouble() * 2,
        position:
            targetPosition + Vector2(-20 + Random().nextDouble() * 40, -30),
        paint: Paint()..color = Colors.purple.withOpacity(0.7),
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(-10 + Random().nextDouble() * 20, 30),
          EffectController(duration: 1.2, curve: Curves.easeOut),
        ),
      );

      particle.add(RemoveEffect(delay: 1.2));

      container.add(particle);
    }

    return container;
  }
}

class SteamAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 50; i++) {
      final particle = CircleComponent(
        radius: 4 + Random().nextDouble() * 6,
        position:
            targetPosition + Vector2(-30 + Random().nextDouble() * 60, -20),
        paint: Paint()..color = Colors.grey.withOpacity(0.4),
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(-15 + Random().nextDouble() * 30, -40),
          EffectController(duration: 1.0, curve: Curves.easeOut),
        ),
      );

      particle.add(RemoveEffect(delay: 1.0));

      container.add(particle);
    }

    return container;
  }
}

class LavaAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 35; i++) {
      final particle = CircleComponent(
        radius: 3 + Random().nextDouble() * 4,
        position:
            targetPosition + Vector2(-40 + Random().nextDouble() * 80, -100),
        paint: Paint()
          ..color = [
            Colors.orange,
            Colors.deepOrange,
            Colors.red,
          ][Random().nextInt(3)],
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(-20 + Random().nextDouble() * 40, 100),
          EffectController(duration: 0.8, curve: Curves.easeIn),
        ),
      );

      particle.add(RemoveEffect(delay: 0.8));

      container.add(particle);
    }

    return container;
  }
}

class MudAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 30; i++) {
      final particle = CircleComponent(
        radius: 3 + Random().nextDouble() * 4,
        position:
            targetPosition + Vector2(-50 + Random().nextDouble() * 100, -80),
        paint: Paint()..color = Color(0xFF8B7355),
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(-25 + Random().nextDouble() * 50, 80),
          EffectController(duration: 0.6, curve: Curves.easeIn),
        ),
      );

      particle.add(RemoveEffect(delay: 0.6));

      container.add(particle);
    }

    return container;
  }
}

class DustAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 60; i++) {
      final particle = CircleComponent(
        radius: 1 + Random().nextDouble() * 2,
        position:
            targetPosition + Vector2(-60 + Random().nextDouble() * 120, -20),
        paint: Paint()..color = Colors.brown.withOpacity(0.6),
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(20 - Random().nextDouble() * 40, 40),
          EffectController(duration: 1.0, curve: Curves.easeOut),
        ),
      );

      particle.add(RemoveEffect(delay: 1.0));

      container.add(particle);
    }

    return container;
  }
}

class CrystalAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 25; i++) {
      final particle = RectangleComponent(
        size: Vector2(4, 6),
        position:
            targetPosition + Vector2(-50 + Random().nextDouble() * 100, -60),
        paint: Paint()..color = Colors.cyan,
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(-25 + Random().nextDouble() * 50, 60),
          EffectController(duration: 0.7, curve: Curves.easeIn),
        ),
      );

      particle.add(RemoveEffect(delay: 0.7));

      container.add(particle);
    }

    return container;
  }
}

class SpiritAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 40; i++) {
      final particle = CircleComponent(
        radius: 2 + Random().nextDouble() * 3,
        position: targetPosition + Vector2(-30 + Random().nextDouble() * 60, 0),
        paint: Paint()..color = Colors.white.withOpacity(0.4),
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(-15 + Random().nextDouble() * 30, -60),
          EffectController(duration: 1.5, curve: Curves.easeOut),
        ),
      );

      particle.add(RemoveEffect(delay: 1.5));

      container.add(particle);
    }

    return container;
  }
}

class DarkAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 50; i++) {
      final angle = (i / 50) * 2 * pi;
      final radius = 80 + Random().nextDouble() * 60;

      final particle = CircleComponent(
        radius: 2 + Random().nextDouble() * 3,
        position: targetPosition + Vector2(cos(angle), sin(angle)) * radius,
        paint: Paint()..color = Colors.purple.shade900.withOpacity(0.8),
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.to(
          targetPosition,
          EffectController(duration: 1.0, curve: Curves.easeIn),
        ),
      );

      particle.add(RemoveEffect(delay: 1.0));

      container.add(particle);
    }

    return container;
  }
}

class LightAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 60; i++) {
      final angle = (i / 60) * 2 * pi;
      final distance = 120 + Random().nextDouble() * 80;

      final particle = CircleComponent(
        radius: 2 + Random().nextDouble() * 3,
        position: targetPosition.clone(),
        paint: Paint()..color = Colors.yellow.withOpacity(0.9),
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(cos(angle), sin(angle)) * distance,
          EffectController(duration: 0.8),
        ),
      );

      particle.add(RemoveEffect(delay: 0.8));

      container.add(particle);
    }

    return container;
  }
}

class BloodAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 30; i++) {
      final particle = CircleComponent(
        radius: 2 + Random().nextDouble() * 3,
        position:
            targetPosition + Vector2(-60 + Random().nextDouble() * 120, -80),
        paint: Paint()..color = Colors.red.shade900,
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(-30 + Random().nextDouble() * 60, 80),
          EffectController(duration: 0.7, curve: Curves.easeIn),
        ),
      );

      particle.add(RemoveEffect(delay: 0.7));

      container.add(particle);
    }

    return container;
  }
}

class GenericAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 20; i++) {
      final particle = CircleComponent(
        radius: 3,
        position:
            targetPosition + Vector2(-40 + Random().nextDouble() * 80, -60),
        paint: Paint()..color = Colors.white,
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(-20 + Random().nextDouble() * 40, 60),
          EffectController(duration: 0.5, curve: Curves.easeIn),
        ),
      );

      particle.add(RemoveEffect(delay: 0.5));

      container.add(particle);
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
    // Triple burst effect
    final baseAnimation = AttackAnimations._getElementalAnimation(
      element,
      MoveType.physical,
    );
    return baseAnimation.createEffect(targetPosition);
  }
}

class PipFuryAnimation extends AttackAnimation {
  final String element;
  PipFuryAnimation(this.element);

  @override
  Component createEffect(Vector2 targetPosition) {
    final baseAnimation = AttackAnimations._getElementalAnimation(
      element,
      MoveType.physical,
    );
    return baseAnimation.createEffect(targetPosition);
  }
}

class ManeTrickAnimation extends AttackAnimation {
  final String element;
  ManeTrickAnimation(this.element);

  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 40; i++) {
      final angle = (i / 40) * 2 * pi;
      final radius = 50.0;

      final particle = CircleComponent(
        radius: 3,
        position: targetPosition + Vector2(cos(angle), sin(angle)) * radius,
        paint: Paint()..color = Colors.purple,
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.to(
          targetPosition,
          EffectController(duration: 1.5, curve: Curves.easeIn),
        ),
      );

      particle.add(RemoveEffect(delay: 1.5));

      container.add(particle);
    }

    return container;
  }
}

class HornGuardAnimation extends AttackAnimation {
  @override
  Component createEffect(Vector2 targetPosition) {
    final shield = CircleComponent(
      radius: 10,
      position: targetPosition,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    shield.add(
      ScaleEffect.to(Vector2.all(5.0), EffectController(duration: 0.5)),
    );

    shield.add(RemoveEffect(delay: 0.5));

    return shield;
  }
}

class MaskCurseAnimation extends AttackAnimation {
  final String element;
  MaskCurseAnimation(this.element);

  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 50; i++) {
      final angle = (i / 50) * 4 * pi;
      final radius = 60.0;

      final particle = CircleComponent(
        radius: 2,
        position: targetPosition + Vector2(cos(angle), sin(angle)) * radius,
        paint: Paint()..color = Colors.purple.shade900.withOpacity(0.6),
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.to(
          targetPosition + Vector2(cos(angle + pi), sin(angle + pi)) * radius,
          EffectController(duration: 2.0),
        ),
      );

      particle.add(RemoveEffect(delay: 2.0));

      container.add(particle);
    }

    return container;
  }
}

class WingAssaultAnimation extends AttackAnimation {
  final String element;
  WingAssaultAnimation(this.element);

  @override
  Component createEffect(Vector2 targetPosition) {
    final container = Component();

    for (int i = 0; i < 100; i++) {
      final angle = (i / 100) * 2 * pi;
      final distance = 200 + Random().nextDouble() * 150;

      final particle = CircleComponent(
        radius: 3 + Random().nextDouble() * 5,
        position: targetPosition.clone(),
        paint: Paint()..color = Colors.orange,
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(cos(angle), sin(angle)) * distance,
          EffectController(duration: 1.0, curve: Curves.easeOut),
        ),
      );

      particle.add(RemoveEffect(delay: 1.0));

      container.add(particle);
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

    for (int i = 0; i < 40; i++) {
      final particle = CircleComponent(
        radius: 2 + Random().nextDouble() * 3,
        position: targetPosition + Vector2(-30 + Random().nextDouble() * 60, 0),
        paint: Paint()..color = Colors.greenAccent,
        anchor: Anchor.center,
      );

      particle.add(
        MoveEffect.by(
          Vector2(-15 + Random().nextDouble() * 30, -80),
          EffectController(duration: 1.5, curve: Curves.easeOut),
        ),
      );

      particle.add(RemoveEffect(delay: 1.5));

      container.add(particle);
    }

    return container;
  }
}

class MysticPowerAnimation extends AttackAnimation {
  final String element;
  MysticPowerAnimation(this.element);

  @override
  Component createEffect(Vector2 targetPosition) {
    // Triple layered elemental effect
    final baseEffect = AttackAnimations._getElementalAnimation(
      element,
      MoveType.elemental,
    );
    return baseEffect.createEffect(targetPosition);
  }
}
