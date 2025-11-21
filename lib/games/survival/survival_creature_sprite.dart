import 'dart:math' as math;
import 'package:alchemons/games/survival/survival_enemies.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart'; // Your existing widget

class HoardGuardian extends PositionComponent
    with HasGameRef<SurvivalHoardGame> {
  final BattleCombatant combatant;

  // Action Logic
  double _cooldownTimer = 0;
  late double _abilityCooldown;
  double _attackRange = 150.0; // Default range

  // Visuals
  late PositionComponent visualContainer;
  bool _isFlipped = false;

  HoardGuardian({required this.combatant, required Vector2 position})
    : super(position: position, size: Vector2.all(100), anchor: Anchor.center) {
    // --- CORE LOGIC: SPEED STAT ---
    // Higher speed = Lower cooldown.
    // Base cooldown is 3 seconds. Speed 5.0 makes it ~1 second.
    double speedMod = math.max(0.1, combatant.statSpeed);
    _abilityCooldown = 3.0 / (1 + (speedMod * 0.4));

    // Range based on Intelligence (Ranged) vs Strength (Melee)
    if (combatant.statIntelligence > combatant.statStrength) {
      _attackRange = 400.0; // Ranged
    }
  }

  @override
  Future<void> onLoad() async {
    // Use your existing visual logic
    if (combatant.sheetDef != null && combatant.spriteVisuals != null) {
      final visual = CreatureSpriteComponent(
        sheet: combatant.sheetDef!,
        visuals: combatant.spriteVisuals!,
        desiredSize: size,
      );
      visual.anchor = Anchor.center;
      visual.position = size / 2;
      add(visual);
    } else {
      // Fallback
      add(
        CircleComponent(
          radius: 40,
          paint: Paint()..color = Colors.green,
          anchor: Anchor.center,
          position: size / 2,
        ),
      );
    }

    // HP Bar
    add(_buildHpBar());
  }

  Component _buildHpBar() {
    return RectangleComponent(
      size: Vector2(60, 6),
      position: Vector2(size.x / 2, -10),
      anchor: Anchor.center,
      paint: Paint()..color = Colors.black,
      children: [
        RectangleComponent(
          size: Vector2(60, 6),
          paint: Paint()..color = Colors.greenAccent,
          // We update scale.x in update() for HP
          key: ComponentKey.named('hp_fill'),
        ),
      ],
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (combatant.isDead) {
      removeFromParent();
      return;
    }

    // Update Cooldown
    if (_cooldownTimer > 0) _cooldownTimer -= dt;

    // Find Target
    final target = gameRef.getNearestEnemy(position, _attackRange);

    if (target != null) {
      _faceTarget(target.position);
      if (_cooldownTimer <= 0) {
        _performAbility(target);
      }
    }
  }

  void _faceTarget(Vector2 targetPos) {
    bool shouldFlip = targetPos.x < position.x;
    if (shouldFlip != _isFlipped) {
      _isFlipped = shouldFlip;
      // Flip visual horizontally
      scale.x = _isFlipped ? -1 : 1;
      // Keep HP bar correct way text-wise if you had text, but for rects it's fine
    }
  }

  void _performAbility(HoardEnemy target) {
    _cooldownTimer = _abilityCooldown;

    // Determine move type based on highest stat
    bool isSpecial =
        combatant.level >= 5 &&
        (math.Random().nextDouble() < 0.3); // 30% chance for special if leveled

    // Calculate Damage using your BattleCombatant stats
    int damage = 0;
    if (combatant.statStrength > combatant.statIntelligence) {
      damage = combatant.physAtk; // Use physical
    } else {
      damage = combatant.elemAtk; // Use elemental
    }

    if (isSpecial) damage = (damage * 1.5).round();

    // Visual Effect (Juice)
    add(
      SequenceEffect([
        ScaleEffect.by(
          Vector2.all(1.2),
          EffectController(duration: 0.1, alternate: true),
        ),
      ]),
    );

    // Create Projectile or Instant Hit
    gameRef.spawnProjectile(
      start: position,
      target: target,
      damage: damage,
      color: _getElementColor(combatant.types.firstOrNull ?? 'Normal'),
    );
  }

  Color _getElementColor(String type) {
    switch (type) {
      case 'Fire':
        return Colors.orange;
      case 'Water':
        return Colors.blue;
      case 'Plant':
        return Colors.green;
      default:
        return Colors.white;
    }
  }
}
