import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/games/boss/attack_animations.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
// ^ Adjust path: this is the file where your CreatureSpriteComponent lives

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Endless survival auto-battler using your BattleEngine + SurvivalEngine.
class SurvivalGame extends FlameGame {
  final List<BattleCombatant> team;

  late SurvivalEngine _engine;
  late SurvivalWave _currentWave;

  late TextComponent _waveText;
  late TextComponent _scoreText;

  double _roundTimer = 0;
  final double _roundInterval = 0.8; // seconds per “round”

  /// Combatant.id -> visual sprite
  final Map<String, SurvivalCreatureSprite> _sprites = {};

  SurvivalGame({required this.team});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _engine = SurvivalEngine(team: team);
    _currentWave = _engine.startNextWave();

    _waveText = TextComponent(
      text: 'Wave 1',
      position: Vector2(8, 8),
      anchor: Anchor.topLeft,
    );

    _scoreText = TextComponent(
      text: 'Score 0',
      position: Vector2(size.x - 8, 8),
      anchor: Anchor.topRight,
    );

    add(_waveText);
    add(_scoreText);

    _layoutField();
  }

  /// Lay out player creatures at bottom and enemies at top.
  void _layoutField() {
    // Remove old creature sprites
    final oldSprites = children.whereType<SurvivalCreatureSprite>().toList();
    removeAll(oldSprites);
    _sprites.clear();

    // Player row (up to 4)
    final spacing = size.x / (team.length + 1);
    for (var i = 0; i < team.length; i++) {
      final c = team[i];
      final sprite = SurvivalCreatureSprite(combatant: c, isPlayer: true)
        ..position = Vector2(spacing * (i + 1), size.y - 90)
        ..anchor = Anchor.center;

      _sprites[c.id] = sprite;
      add(sprite);
      sprite.playSpawnAnimation();
    }

    // Enemies row
    final enemies = _currentWave.enemies;
    final enemySpacing = size.x / (enemies.length + 1);
    for (var i = 0; i < enemies.length; i++) {
      final e = enemies[i];
      final sprite = SurvivalCreatureSprite(combatant: e, isPlayer: false)
        ..position = Vector2(enemySpacing * (i + 1), 110)
        ..anchor = Anchor.center;

      _sprites[e.id] = sprite;
      add(sprite);
      sprite.playSpawnAnimation();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_engine.isGameOver) {
      // TODO: overlay / summary screen
      return;
    }

    _roundTimer += dt;
    if (_roundTimer >= _roundInterval) {
      _roundTimer = 0;

      final events = _engine.runOneRound(_currentWave);

      for (final ev in events) {
        final action = ev.action;
        final result = ev.result;

        final attacker = action.actor;
        final target = action.target;

        // Only animate direct damage events
        if (result.damage > 0) {
          _handleDamage(
            move: action.move,
            attacker: attacker,
            target: target,
            result: result,
          );
        }

        // Status icons (burn/poison/buffs)
        _sprites[attacker.id]?.updateStatusIcons();
        _sprites[target.id]?.updateStatusIcons();

        // Death animation
        if (target.isDead) {
          _sprites[target.id]?.playDeathAnimation();
        }
      }

      // Wave cleared?
      if (_currentWave.allEnemiesDefeated) {
        _engine.completeWave(_currentWave);
        _engine.state.recoverBetweenWaves();

        _currentWave = _engine.startNextWave();
        _waveText.text = 'Wave ${_engine.state.waveNumber}';
        _scoreText.text = 'Score ${_engine.state.score}';
        _layoutField();
      }
    }
  }

  void _handleDamage({
    required BattleMove move,
    required BattleCombatant attacker,
    required BattleCombatant target,
    required BattleResult result,
  }) {
    final targetSprite = _sprites[target.id];
    if (targetSprite == null) return;

    // Damage popup + shake
    targetSprite.showDamage(result.damage, result.typeMultiplier);

    // Element for particle FX
    final element = attacker.types.isNotEmpty
        ? attacker.types.first
        : 'Generic';

    final animation = AttackAnimations.getAnimation(move, element);

    // World-space center of target sprite
    final center = targetSprite.absoluteCenter;

    final effect = animation.createEffect(center.clone());
    add(effect);
  }
}

/// Wrapper that uses your CreatureSpriteComponent for visuals,
/// plus HP bar, status icons, damage popups, and spawn/death anims.
class SurvivalCreatureSprite extends PositionComponent
    with HasGameRef<SurvivalGame> {
  final BattleCombatant combatant;
  final bool isPlayer;

  late PositionComponent statusIconContainer;
  double get radius => 40;
  final _rng = math.Random();

  SurvivalCreatureSprite({required this.combatant, required this.isPlayer})
    : super(size: Vector2(100, 120), anchor: Anchor.center);

  /// Convenience: world-space center
  Vector2 get absoluteCenter => (absolutePosition ?? position) + size / 2;

  @override
  Future<void> onLoad() async {
    final sheet = combatant.sheetDef;
    final visuals = combatant.spriteVisuals;

    if (sheet != null && visuals != null) {
      // Use your existing sprite component here
      final creatureVisual =
          CreatureSpriteComponent<SurvivalGame>(
              sheet: sheet,
              visuals: visuals,
              desiredSize: Vector2(80, 80),
            )
            ..position = size / 2
            ..anchor = Anchor.center;

      add(creatureVisual);
    } else {
      // Fallback: colored circle
      add(
        CircleComponent(
          radius: radius,
          anchor: Anchor.center,
          position: size / 2,
          paint: Paint()
            ..color = isPlayer
                ? const Color(0xFF4CAF50)
                : const Color(0xFFF44336),
        ),
      );
    }

    // Status effect & buff icons above head
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

  // ------------ Status icons (burn/poison/buffs) ------------

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
            color: textColor,
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

  // ------------ Animations ------------

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
