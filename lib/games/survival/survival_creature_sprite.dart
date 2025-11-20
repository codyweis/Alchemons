// lib/game/survival_creature_sprite.dart
import 'dart:ui';
import 'dart:math' as math;

import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import 'survival_game.dart';

final _rng = math.Random();

class SurvivalCreatureSprite extends PositionComponent
    with HasGameRef<SurvivalGame> {
  final BattleCombatant combatant;
  final bool isPlayer;

  late CreatureSpriteComponent<SurvivalGame> creatureVisual;
  late PositionComponent statusIconContainer;

  SurvivalCreatureSprite({required this.combatant, required this.isPlayer})
    : super(size: Vector2(100, 120), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    final sheet = combatant.sheetDef;
    final visuals = combatant.spriteVisuals;

    if (sheet != null && visuals != null) {
      creatureVisual =
          CreatureSpriteComponent(
              sheet: sheet,
              visuals: visuals,
              desiredSize: Vector2(80, 80),
            )
            ..position = size / 2
            ..anchor = Anchor.center;
      add(creatureVisual);
    } else {
      // Fallback circle
      add(
        CircleComponent(
          radius: 40,
          anchor: Anchor.center,
          position: size / 2,
          paint: Paint()
            ..color = isPlayer
                ? const Color(0xFF4CAF50)
                : const Color(0xFFF44336),
        ),
      );
    }

    statusIconContainer = PositionComponent(
      position: Vector2(0, -45),
      anchor: Anchor.center,
    );
    add(statusIconContainer);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // HP bar
    final hp = combatant.hpPercent.clamp(0.0, 1.0);
    const barHeight = 4.0;
    final barWidth = 80.0;
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    final fgPaint = Paint()
      ..color = Colors.lightGreenAccent
      ..style = PaintingStyle.fill;

    final barTop = size.y - 10;
    final barLeft = (size.x - barWidth) / 2;

    canvas.drawRect(
      Rect.fromLTWH(barLeft, barTop, barWidth, barHeight),
      bgPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(barLeft, barTop, barWidth * hp, barHeight),
      fgPaint,
    );
  }

  void updateStatusIcons() {
    final toRemove = statusIconContainer.children.toList();
    for (final child in toRemove) {
      child.removeFromParent();
    }

    final effects = combatant.statusEffects.values.toList();
    final modifiers = combatant.statModifiers.values.toList();

    if (effects.isEmpty && modifiers.isEmpty) return;

    const double iconWidth = 34.0;
    const double rowSpacing = 16.0;

    if (effects.isNotEmpty) {
      final effectsRow = PositionComponent(anchor: Anchor.center);
      for (int i = 0; i < effects.length; i++) {
        final icon = _createStatusIcon(effects[i].type);
        icon.position = Vector2(
          (i - effects.length / 2 + 0.5) * (iconWidth + 2),
          0,
        );
        effectsRow.add(icon);
      }
      statusIconContainer.add(effectsRow);
    }

    if (modifiers.isNotEmpty) {
      final modifiersRow = PositionComponent(
        anchor: Anchor.center,
        position: Vector2(0, rowSpacing),
      );
      for (int i = 0; i < modifiers.length; i++) {
        final icon = _createStatModifierIcon(modifiers[i].type);
        icon.position = Vector2(
          (i - modifiers.length / 2 + 0.5) * (iconWidth + 2),
          0,
        );
        modifiersRow.add(icon);
      }
      statusIconContainer.add(modifiersRow);
    }
  }

  PositionComponent _createStatusIcon(String statusType) {
    Color bgColor;
    Color textColor;
    String text;

    switch (statusType) {
      case 'burn':
        bgColor = Colors.orange.withOpacity(0.85);
        textColor = Colors.white;
        text = 'BRN';
        break;
      case 'poison':
        bgColor = Colors.purple.withOpacity(0.85);
        textColor = Colors.white;
        text = 'PSN';
        break;
      case 'freeze':
        bgColor = Colors.cyan.withOpacity(0.85);
        textColor = Colors.black;
        text = 'FRZ';
        break;
      case 'curse':
        bgColor = Colors.purple.shade900.withOpacity(0.85);
        textColor = Colors.white;
        text = 'CRS';
        break;
      case 'regen':
        bgColor = Colors.green.withOpacity(0.85);
        textColor = Colors.white;
        text = 'REG';
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.85);
        textColor = Colors.white;
        text = '???';
    }

    final container = PositionComponent(
      size: Vector2(36, 14),
      anchor: Anchor.center,
    );

    final bg = RectangleComponent(
      size: Vector2(36, 14),
      anchor: Anchor.center,
      paint: Paint()..color = bgColor,
    )..position = Vector2(18, 7);

    container.add(bg);
    container.add(
      TextComponent(
        text: text,
        anchor: Anchor.center,
        position: Vector2(18, 7),
        textRenderer: TextPaint(
          style: TextStyle(
            color: textColor, // <- fixed to use computed color
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    return container;
  }

  PositionComponent _createStatModifierIcon(String type) {
    Color bgColor;
    Color textColor = Colors.white;
    String text;

    switch (type) {
      case 'attack_up':
        bgColor = Colors.red.withOpacity(0.85);
        text = 'ATK↑';
        break;
      case 'attack_down':
        bgColor = Colors.red.shade300.withOpacity(0.85);
        text = 'ATK↓';
        break;
      case 'defense_up':
        bgColor = Colors.blue.withOpacity(0.85);
        text = 'DEF↑';
        break;
      case 'defense_down':
        bgColor = Colors.blue.shade300.withOpacity(0.85);
        text = 'DEF↓';
        break;
      case 'speed_up':
        bgColor = Colors.yellow.withOpacity(0.85);
        textColor = Colors.black;
        text = 'SPD↑';
        break;
      case 'speed_down':
        bgColor = Colors.yellow.shade700.withOpacity(0.85);
        text = 'SPD↓';
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.85);
        text = '???';
    }

    final container = PositionComponent(
      size: Vector2(36, 14),
      anchor: Anchor.center,
    );

    final bg = RectangleComponent(
      size: Vector2(36, 14),
      anchor: Anchor.center,
      paint: Paint()..color = bgColor,
    )..position = Vector2(18, 7);

    container.add(bg);
    container.add(
      TextComponent(
        text: text,
        anchor: Anchor.center,
        position: Vector2(18, 7),
        textRenderer: TextPaint(
          style: TextStyle(
            color: textColor,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    return container;
  }

  void playSpawnAnimation() {
    final startY = position.y + 100;
    position.y = startY;
    scale = Vector2.zero();

    add(
      MoveEffect.by(
        Vector2(0, -100),
        EffectController(duration: 0.5, curve: Curves.easeOut),
      ),
    );

    add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.2),
          EffectController(duration: 0.3, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.2, curve: Curves.easeIn),
        ),
      ]),
    );
  }

  void playDeathAnimation() {
    final offScreenY = gameRef.size.y + size.y;
    const duration = 1.2;

    add(
      MoveEffect.to(
        Vector2(position.x, offScreenY),
        EffectController(duration: duration, curve: Curves.easeIn),
      ),
    );

    add(RotateEffect.by(math.pi / 4, EffectController(duration: duration)));

    add(RemoveEffect(delay: duration + 0.1));
  }

  void showDamage(int damage, double typeMultiplier) {
    if (combatant.isDead) return;

    final color = typeMultiplier > 1.0
        ? Colors.orange
        : typeMultiplier < 1.0
        ? Colors.grey
        : Colors.white;

    final container = PositionComponent(
      position: position + Vector2(0, -50),
      anchor: Anchor.center,
    );

    final damageText = TextComponent(
      text: '-$damage',
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(blurRadius: 8, color: Colors.black),
            Shadow(blurRadius: 4, color: Colors.black),
          ],
        ),
      ),
    );

    container.add(damageText);
    gameRef.add(container);

    container.add(
      SequenceEffect([
        MoveEffect.by(
          Vector2(0, -40),
          EffectController(duration: 0.7, curve: Curves.easeOut),
        ),
        RemoveEffect(),
      ]),
    );

    add(
      MoveEffect.by(
        Vector2(_rng.nextDouble() * 16 - 8, _rng.nextDouble() * 16 - 8),
        EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 3),
      ),
    );
  }
}
