import 'dart:ui';
import 'dart:math' as math;

import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import 'survival_game.dart';

final _rng = math.Random();

enum CombatBehavior { ranged, melee, balanced }

/// Base combat sprite class
abstract class CombatSprite extends PositionComponent
    with HasGameRef<SurvivalGame> {
  final BattleCombatant combatant;
  final bool isPlayer;
  final Vector2 homePosition;

  late PositionComponent statusIconContainer;

  CombatBehavior behavior = CombatBehavior.balanced;
  CombatSprite? currentTarget;
  bool isDying = false;
  bool isMovingToTarget = false;

  double idleTimer = 0;
  double attackCooldown = 0;

  CombatSprite({
    required this.combatant,
    required this.isPlayer,
    required this.homePosition,
    required Vector2 size,
  }) : super(size: size, anchor: Anchor.center) {
    _determineBehavior();
  }

  void _determineBehavior() {
    final hasRanged = combatant.level >= 5;
    final intBased = combatant.statIntelligence > combatant.statStrength;

    if (hasRanged && intBased) {
      behavior = CombatBehavior.ranged;
    } else if (combatant.statStrength > combatant.statIntelligence * 1.3) {
      behavior = CombatBehavior.melee;
    } else {
      behavior = CombatBehavior.balanced;
    }
  }

  @override
  Future<void> onLoad() async {
    statusIconContainer = PositionComponent(
      position: Vector2(0, -50),
      anchor: Anchor.center,
    );
    add(statusIconContainer);
  }

  void updateCombatAI(List<CombatSprite> allSprites, double dt) {
    if (isDying || combatant.isDead) return;

    idleTimer += dt;
    if (attackCooldown > 0) attackCooldown -= dt;

    final enemies = allSprites
        .where(
          (s) => s.isPlayer != isPlayer && s.combatant.isAlive && !s.isDying,
        )
        .toList();

    if (enemies.isEmpty) {
      returnToFormation();
      return;
    }

    enemies.sort(
      (a, b) => position
          .distanceTo(a.position)
          .compareTo(position.distanceTo(b.position)),
    );
    currentTarget = enemies.first;

    switch (behavior) {
      case CombatBehavior.ranged:
        _executeRangedBehavior(dt);
        break;
      case CombatBehavior.melee:
        _executeMeleeBehavior(dt);
        break;
      case CombatBehavior.balanced:
        _executeBalancedBehavior(dt);
        break;
    }

    if (idleTimer >= 2.0) {
      idleTimer = 0;
      _playIdleAnimation();
    }
  }

  void _executeRangedBehavior(double dt) {
    if (currentTarget == null) {
      returnToFormation();
      return;
    }

    final distance = position.distanceTo(currentTarget!.position);
    final attackRange = _getAttackRange();

    // Move closer if out of range
    if (distance > attackRange) {
      _moveToward(currentTarget!.position, dt, attackRange);
    } else {
      // In range - stay in formation and attack
      returnToFormation();
    }

    _faceTarget(currentTarget!);
  }

  void _executeMeleeBehavior(double dt) {
    if (currentTarget == null) return;

    final distance = position.distanceTo(currentTarget!.position);

    if (distance > SurvivalGame.meleeEngageDistance) {
      _moveToward(
        currentTarget!.position,
        dt,
        SurvivalGame.meleeEngageDistance,
      );
    } else {
      _faceTarget(currentTarget!);
      if (attackCooldown <= 0 && _rng.nextDouble() < 0.05) {
        _playAttackBob();
        attackCooldown = 0.5;
      }

      if (!isMovingToTarget && position.distanceTo(homePosition) > 50) {
        returnToFormation();
      }
    }
  }

  void _executeBalancedBehavior(double dt) {
    if (currentTarget == null) return;

    final distance = position.distanceTo(currentTarget!.position);
    final attackRange = _getAttackRange();

    if (distance > attackRange * 1.2) {
      // Too far - move closer
      _moveToward(currentTarget!.position, dt, attackRange * 0.9);
      _faceTarget(currentTarget!);
    } else if (distance < attackRange * 0.6) {
      // Too close - back up to formation
      returnToFormation();
      _faceTarget(currentTarget!);
    } else {
      // Good distance - maintain position
      _faceTarget(currentTarget!);
    }
  }

  void _moveToward(Vector2 targetPos, double dt, double stopDistance) {
    final distance = position.distanceTo(targetPos);

    if (distance <= stopDistance) {
      isMovingToTarget = false;
      return;
    }

    final direction = (targetPos - position).normalized();
    final moveSpeed = 100.0 * dt;
    position += direction * moveSpeed;
    isMovingToTarget = true;
  }

  void returnToFormation({bool forced = false}) {
    final distance = position.distanceTo(homePosition);

    if (distance > 10) {
      if (forced || children.whereType<MoveEffect>().isEmpty) {
        add(
          MoveEffect.to(
            homePosition,
            EffectController(duration: 1.2, curve: Curves.easeInOut),
            onComplete: () => isMovingToTarget = false,
          ),
        );
      }
    } else {
      position = homePosition;
      isMovingToTarget = false;
    }
  }

  void _faceTarget(CombatSprite target) {
    scale.x = (target.position.x < position.x ? -1 : 1) * scale.y.abs();
  }

  /// Get attack range based on combatant level/power
  /// Weaker units (low level) need to get closer
  /// Stronger units (high level) can attack from further away
  double _getAttackRange() {
    if (behavior == CombatBehavior.melee) {
      return SurvivalGame.meleeEngageDistance;
    }

    // Ranged attack distance scales with level
    // Level 1-3: 120px (VERY close - almost melee)
    // Level 4-6: 180px (close)
    // Level 7-10: 250px (medium)
    // Level 11-15: 350px (good range)
    // Level 16+: 450px (long range)

    if (combatant.level <= 3) {
      return 120.0; // Tier 1 - must get extremely close
    } else if (combatant.level <= 6) {
      return 180.0; // Early tier 2
    } else if (combatant.level <= 10) {
      return 250.0; // Tier 2-3
    } else if (combatant.level <= 15) {
      return 350.0; // Tier 4
    } else {
      return 450.0; // Tier 5 - respectable range
    }
  }

  void _playIdleAnimation() {
    add(
      SequenceEffect([
        MoveEffect.by(
          Vector2(0, -6),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
        MoveEffect.by(
          Vector2(0, 6),
          EffectController(duration: 0.25, curve: Curves.easeIn),
        ),
      ]),
    );
  }

  void _playAttackBob() {
    final direction = isPlayer ? 15.0 : -15.0;
    add(
      SequenceEffect([
        MoveEffect.by(Vector2(direction, 0), EffectController(duration: 0.08)),
        MoveEffect.by(Vector2(-direction, 0), EffectController(duration: 0.08)),
      ]),
    );
  }

  void updateStatusIcons() {
    statusIconContainer.children.toList().forEach((c) => c.removeFromParent());

    final effects = combatant.statusEffects.values.toList();
    final modifiers = combatant.statModifiers.values.toList();

    if (effects.isEmpty && modifiers.isEmpty) return;

    const iconWidth = 38.0;
    const rowSpacing = 18.0;

    if (effects.isNotEmpty) {
      final row = PositionComponent(anchor: Anchor.center);
      for (var i = 0; i < effects.length; i++) {
        final icon = _createStatusIcon(effects[i].type);
        icon.position = Vector2(
          (i - effects.length / 2 + 0.5) * (iconWidth + 2),
          0,
        );
        row.add(icon);
      }
      statusIconContainer.add(row);
    }

    if (modifiers.isNotEmpty) {
      final row = PositionComponent(
        anchor: Anchor.center,
        position: Vector2(0, rowSpacing),
      );
      for (var i = 0; i < modifiers.length; i++) {
        final icon = _createStatModifierIcon(modifiers[i].type);
        icon.position = Vector2(
          (i - modifiers.length / 2 + 0.5) * (iconWidth + 2),
          0,
        );
        row.add(icon);
      }
      statusIconContainer.add(row);
    }
  }

  PositionComponent _createStatusIcon(String type) {
    final data = _getStatusData(type);
    return _createIcon(data['bg']!, data['text']!, data['label']!);
  }

  PositionComponent _createStatModifierIcon(String type) {
    final data = _getModifierData(type);
    return _createIcon(data['bg']!, data['text']!, data['label']!);
  }

  PositionComponent _createIcon(Color bg, Color text, String label) {
    final container = PositionComponent(
      size: Vector2(38, 16),
      anchor: Anchor.center,
    );
    container.add(
      RectangleComponent(
        size: Vector2(38, 16),
        anchor: Anchor.center,
        paint: Paint()..color = bg,
      )..position = Vector2(19, 8),
    );
    container.add(
      TextComponent(
        text: label,
        anchor: Anchor.center,
        position: Vector2(19, 8),
        textRenderer: TextPaint(
          style: TextStyle(
            color: text,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
    return container;
  }

  Map<String, dynamic> _getStatusData(String type) {
    switch (type) {
      case 'burn':
        return {
          'bg': Colors.orange.withOpacity(0.9),
          'text': Colors.white,
          'label': 'BRN',
        };
      case 'poison':
        return {
          'bg': Colors.purple.withOpacity(0.9),
          'text': Colors.white,
          'label': 'PSN',
        };
      case 'freeze':
        return {
          'bg': Colors.cyan.withOpacity(0.9),
          'text': Colors.black,
          'label': 'FRZ',
        };
      case 'curse':
        return {
          'bg': Colors.purple.shade900.withOpacity(0.9),
          'text': Colors.white,
          'label': 'CRS',
        };
      case 'regen':
        return {
          'bg': Colors.green.withOpacity(0.9),
          'text': Colors.white,
          'label': 'REG',
        };
      default:
        return {
          'bg': Colors.grey.withOpacity(0.9),
          'text': Colors.white,
          'label': '???',
        };
    }
  }

  Map<String, dynamic> _getModifierData(String type) {
    switch (type) {
      case 'attack_up':
        return {
          'bg': Colors.red.withOpacity(0.9),
          'text': Colors.white,
          'label': 'ATK↑',
        };
      case 'attack_down':
        return {
          'bg': Colors.red.shade300.withOpacity(0.9),
          'text': Colors.white,
          'label': 'ATK↓',
        };
      case 'defense_up':
        return {
          'bg': Colors.blue.withOpacity(0.9),
          'text': Colors.white,
          'label': 'DEF↑',
        };
      case 'defense_down':
        return {
          'bg': Colors.blue.shade300.withOpacity(0.9),
          'text': Colors.white,
          'label': 'DEF↓',
        };
      case 'speed_up':
        return {
          'bg': Colors.yellow.withOpacity(0.9),
          'text': Colors.black,
          'label': 'SPD↑',
        };
      case 'speed_down':
        return {
          'bg': Colors.yellow.shade700.withOpacity(0.9),
          'text': Colors.white,
          'label': 'SPD↓',
        };
      default:
        return {
          'bg': Colors.grey.withOpacity(0.9),
          'text': Colors.white,
          'label': '???',
        };
    }
  }

  void playSpawnAnimation();
  void playDeathAnimation();
  void showDamage(int damage, double typeMultiplier);
}

/// Player creature sprite with actual visuals
class SurvivalCreatureSprite extends CombatSprite {
  final int formationIndex;
  late CreatureSpriteComponent<SurvivalGame> creatureVisual;

  SurvivalCreatureSprite({
    required super.combatant,
    required super.isPlayer,
    required super.homePosition,
    required this.formationIndex,
  }) : super(size: Vector2(100, 120));

  double _getSpeciesScale() {
    // Whatever you use to identify species; here I use family as a fallback.
    final key = combatant.family;

    switch (key.toLowerCase()) {
      case 'let': // small, bouncy guys
        return 0.8;
      case 'pip':
        return 1.0;
      case 'mane':
        return 1.0;
      case 'mask':
        return 0.9;
      case 'horn': // big, chunky
        return 1.2;
      case 'wing':
        return 1.6;
      case 'mystic':
        return 1.0;
      // add real species IDs here
      default:
        return 1.0;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final sheet = combatant.sheetDef;
    final visuals = combatant.spriteVisuals;

    if (sheet != null && visuals != null) {
      final scaleFactor = _getSpeciesScale();
      final baseSize = Vector2(80, 80);
      creatureVisual =
          CreatureSpriteComponent(
              sheet: sheet,
              visuals: visuals,
              desiredSize: baseSize * scaleFactor,
            )
            ..position = size / 2
            ..anchor = Anchor.center;
      add(creatureVisual);
    } else {
      add(
        CircleComponent(
          radius: 40,
          anchor: Anchor.center,
          position: size / 2,
          paint: Paint()
            ..color = (isPlayer ? Colors.green : Colors.red).withOpacity(0.8),
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (isDying || combatant.isDead) return;

    final hp = combatant.hpPercent.clamp(0.0, 1.0);
    const barH = 5.0;
    const barW = 85.0;

    final barY = size.y - 12;
    final barX = (size.x - barW) / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW, barH),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.black.withOpacity(0.7),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW * hp, barH),
        const Radius.circular(2),
      ),
      Paint()
        ..color = hp > 0.6
            ? Colors.lightGreen
            : (hp > 0.3 ? Colors.orange : Colors.red),
    );
  }

  @override
  void playSpawnAnimation() {
    position.y += 100;
    scale = Vector2.zero();
    add(
      MoveEffect.by(
        Vector2(0, -100),
        EffectController(duration: 0.6, curve: Curves.easeOut),
      ),
    );
    add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.2),
          EffectController(duration: 0.4, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.2, curve: Curves.easeIn),
        ),
      ]),
    );
  }

  @override
  void playDeathAnimation() {
    if (isDying) return;
    isDying = true;

    add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(1.3), EffectController(duration: 0.2)),
        MoveEffect.by(
          Vector2(0, 500),
          EffectController(duration: 1.5, curve: Curves.easeIn),
        ),
        RemoveEffect(),
      ]),
    );

    add(RotateEffect.by(math.pi * 2, EffectController(duration: 1.5)));

    // Fade by scaling down
    add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 1.5, startDelay: 0.5),
      ),
    );
  }

  @override
  void showDamage(int damage, double typeMultiplier) {
    if (combatant.isDead || isDying) return;

    final color = typeMultiplier > 1.0
        ? Colors.orange
        : (typeMultiplier < 1.0 ? Colors.grey : Colors.white);

    final text = TextComponent(
      text: '-$damage',
      anchor: Anchor.center,
      position: absoluteCenter + Vector2(0, -60),
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(blurRadius: 10, color: Colors.black)],
        ),
      ),
    );

    gameRef.add(text);

    text.add(
      MoveEffect.by(
        Vector2(_rng.nextDouble() * 40 - 20, -60),
        EffectController(duration: 1.0, curve: Curves.easeOut),
      ),
    );

    // Fade by scaling to zero
    text.add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.4, startDelay: 0.6),
      ),
    );
    text.add(RemoveEffect(delay: 1.0));

    add(
      SequenceEffect(
        List.generate(
          4,
          (_) => MoveEffect.by(
            Vector2(_rng.nextDouble() * 20 - 10, _rng.nextDouble() * 20 - 10),
            EffectController(duration: 0.05, reverseDuration: 0.05),
          ),
        ),
      ),
    );
  }
}
