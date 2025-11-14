// lib/games/boss/battle_game.dart
import 'dart:async';
import 'dart:math';
import 'package:alchemons/games/boss/attack_animations.dart';
import 'package:alchemons/games/boss/sprite_battle_adapter.dart';
import 'package:alchemons/services/boss_battle_engine_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

final _rng = Random();

extension ShakeExt on PositionComponent {
  void shake({double intensity = 8.0, int repeats = 3, double segment = 0.05}) {
    add(
      MoveEffect.by(
        Vector2(
          _rng.nextDouble() * intensity - intensity / 2,
          _rng.nextDouble() * intensity - intensity / 2,
        ),
        EffectController(
          duration: segment,
          reverseDuration: segment,
          repeatCount: repeats,
        ),
      ),
    );
  }
}

/// Main Flame game for battle scene
class BattleGame extends FlameGame with TapCallbacks {
  final BattleCombatant boss;
  final List<BattleCombatant> playerTeam;
  final Function(BattleGameEvent) onGameEvent;

  late BossSprite bossSprite;
  late List<CreatureBattleSpriteWithVisuals> playerSprites;

  BattleState state = BattleState.playerTurn;
  int currentPlayerIndex = 0;

  // Command queue to safely handle mutations from Flutter UI
  final _pending = <void Function()>[];

  BattleGame({
    required this.boss,
    required this.playerTeam,
    required this.onGameEvent,
  });

  /// Queue a command to run on the game thread during the next update
  void post(void Function() action) => _pending.add(action);

  @override
  void update(double dt) {
    super.update(dt);

    // Drain command queue - use snapshot to avoid reentrancy
    final toRun = List<void Function()>.from(_pending);
    _pending.clear();

    for (final fn in toRun) {
      try {
        fn();
      } catch (e, st) {
        print('Error executing queued command: $e\n$st');
      }
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await add(BattleBackground());

    // Preload all needed textures once
    final paths = <String>[];
    for (final bc in playerTeam) {
      final sheet = bc.sheetDef;
      if (sheet != null) paths.add(sheet.path);
    }
    try {
      await images.loadAll(paths);
    } catch (e) {
      print('Error preloading images: $e');
    }

    // Players - evenly spaced and centered as a group
    playerSprites = [];
    final totalWidth = size.x;
    final teamCount = playerTeam.length;

    // Calculate spacing to center the entire team
    final spacing = totalWidth / (teamCount + 1);

    for (int i = 0; i < playerTeam.length; i++) {
      final bc = playerTeam[i];
      final sheet = bc.sheetDef;
      final visuals = bc.spriteVisuals;

      if (sheet == null || visuals == null) {
        continue;
      }

      // Position each creature with equal spacing
      final xPos = spacing * (i + 1);
      final sprite = CreatureBattleSpriteWithVisuals(
        combatant: bc,
        position: Vector2(xPos, size.y * 0.7),
        index: i,
        sheet: sheet,
        visuals: visuals,
        alchemyEffect: bc.instanceRef?.alchemyEffect,
      );
      playerSprites.add(sprite);
      await add(sprite);

      // Play spawn animation with staggered delay
      Future.delayed(Duration(milliseconds: 100 * i), () {
        sprite.playSpawnAnimation();
      });
    }

    // Boss - perfectly centered
    bossSprite = BossSprite(
      combatant: boss,
      position: Vector2(size.x / 2, size.y * 0.3),
    );
    await add(bossSprite);

    // Play boss fade-in animation after a slight delay
    Future.delayed(Duration(milliseconds: 300 + (100 * teamCount)), () {
      bossSprite.playSpawnAnimation();
    });
  }

  void selectCreature(int index) {
    if (state != BattleState.playerTurn) return;
    if (index >= playerTeam.length) return; // Safety: index out of bounds
    if (playerTeam[index].isDead) return;

    // Deselect previous
    if (currentPlayerIndex < playerSprites.length) {
      playerSprites[currentPlayerIndex].setSelected(false);
    }

    currentPlayerIndex = index;
    playerSprites[currentPlayerIndex].setSelected(true);
    onGameEvent(CreatureSelectedEvent(index));
  }

  // Camera shake effect
  void shakeCamera({double intensity = 10.0}) {
    camera.viewfinder.add(
      MoveEffect.by(
        Vector2(
          Random().nextDouble() * intensity - intensity / 2,
          Random().nextDouble() * intensity - intensity / 2,
        ),
        EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 3),
      ),
    );
  }

  Future<void> executePlayerAttack(BattleMove move) async {
    if (state != BattleState.playerTurn) return;
    if (currentPlayerIndex >= playerTeam.length) return; // Safety check

    final attacker = playerTeam[currentPlayerIndex];

    // Safety check: don't attack if creature is dead
    if (attacker.isDead) {
      state = BattleState.playerTurn;
      return;
    }

    state = BattleState.animating;
    final attackerSprite = playerSprites[currentPlayerIndex];

    // Play attack animation
    await attackerSprite.playAttackAnimation(move, bossSprite);

    // Calculate damage
    final action = BattleAction(actor: attacker, move: move, target: boss);
    final result = BattleEngine.executeAction(action);

    // Shake camera on hit
    shakeCamera(intensity: result.damage / 5.0);

    // Show damage numbers
    bossSprite.showDamage(result.damage, result.typeMultiplier);

    // Send result to UI
    onGameEvent(AttackExecutedEvent(result));

    // Wait then update icons
    await Future.delayed(Duration(milliseconds: 200));
    bossSprite.updateStatusIcons();

    // Check if boss defeated
    if (boss.isDead) {
      await Future.delayed(Duration(seconds: 1));
      onGameEvent(VictoryEvent());
      return;
    }

    // Boss turn
    await Future.delayed(Duration(milliseconds: 500));
    await executeBossAttack();
  }

  Future<void> executeBossAttack() async {
    state = BattleState.bossTurn;

    // Boss picks random alive creature
    final aliveCreatures = playerTeam
        .asMap()
        .entries
        .where((e) => e.value.isAlive)
        .toList();

    if (aliveCreatures.isEmpty) {
      onGameEvent(DefeatEvent());
      return;
    }

    final targetEntry =
        aliveCreatures[DateTime.now().millisecondsSinceEpoch %
            aliveCreatures.length];
    final targetIndex = targetEntry.key;
    final target = targetEntry.value;

    // Safety check: ensure sprite still exists
    if (targetIndex >= playerSprites.length) {
      state = BattleState.playerTurn;
      return;
    }

    final targetSprite = playerSprites[targetIndex];

    // Play boss attack animation
    await bossSprite.playAttackAnimation(
      BattleMove(
        name: 'Boss Attack',
        type: MoveType.physical,
        scalingStat: 'statStrength',
      ),
      targetSprite,
    );

    // Calculate damage
    final action = BattleAction(
      actor: boss,
      move: BattleMove(
        name: 'Attack',
        type: MoveType.physical,
        scalingStat: 'statStrength',
      ),
      target: target,
    );
    final result = BattleEngine.executeAction(action);

    // Shake camera
    shakeCamera(intensity: result.damage / 5.0);

    // Show damage (with safety check)
    if (!target.isDead) {
      targetSprite.showDamage(result.damage, result.typeMultiplier);
    }

    // Send result
    onGameEvent(BossAttackExecutedEvent(result, targetIndex));

    // Wait then update icons
    await Future.delayed(Duration(milliseconds: 200));
    for (final sprite in playerSprites) {
      sprite.updateStatusIcons();
    }

    // Check for death and start the sinking animation
    if (target.isDead) {
      targetSprite.playDeathAnimation();

      // Wait long enough for the player to see the sinking start
      await Future.delayed(Duration(milliseconds: 750));
    }

    // Check if all defeated
    if (playerTeam.every((c) => c.isDead)) {
      await Future.delayed(Duration(seconds: 1));
      onGameEvent(DefeatEvent());
      return;
    }

    // Process end of turn effects
    await processEndOfTurn();

    // Back to player turn
    state = BattleState.playerTurn;
  }

  Future<void> processEndOfTurn() async {
    // Process DoT, regen, etc for all combatants
    for (final combatant in [...playerTeam, boss]) {
      final messages = BattleEngine.processEndOfTurnEffects(combatant);
      if (messages.isNotEmpty) {
        onGameEvent(StatusEffectEvent(messages));
        await Future.delayed(Duration(milliseconds: 800));
      }
    }

    // Wait a frame before updating icons
    await Future.delayed(Duration(milliseconds: 100));

    // Update all status icons and HP
    bossSprite.updateStatusIcons();
    bossSprite.updateHpBar();
    for (final sprite in playerSprites) {
      sprite.updateStatusIcons();
      sprite.updateHpBar();
    }
  }
}

enum BattleState { playerTurn, bossTurn, animating, gameOver }

/// Background component
class BattleBackground extends PositionComponent with HasGameRef<BattleGame> {
  @override
  Future<void> onLoad() async {
    size = gameRef.size;

    // Gradient background
    final gradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromARGB(255, 255, 255, 255),
          Color(0xFF16213e),
          Color.fromARGB(255, 255, 255, 255),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));

    add(RectangleComponent(size: size, paint: gradient));
  }
}

/// Boss sprite component with text-based status indicators
class BossSprite extends PositionComponent with HasGameRef<BattleGame> {
  final BattleCombatant combatant;
  late TextComponent nameLabel;
  late TextComponent hpText;
  late RectangleComponent hpBarFill;
  late PositionComponent statusIconContainer;
  late CircleComponent bossVisual;

  BossSprite({required this.combatant, required Vector2 position})
    : super(position: position, size: Vector2(150, 150));

  @override
  Future<void> onLoad() async {
    // Boss visual placeholder (large circle) - start invisible
    bossVisual = CircleComponent(
      radius: 60,
      paint: Paint()..color = Colors.red.withOpacity(0.0),
      anchor: Anchor.center,
    );
    add(bossVisual);

    // Boss name - start invisible
    nameLabel = TextComponent(
      text: combatant.name,
      position: Vector2(0, -size.y * 0.7),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white.withOpacity(0.0),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      ),
    );
    add(nameLabel);

    // HP text - start invisible
    hpText = TextComponent(
      text: '${combatant.currentHp}/${combatant.maxHp}',
      position: Vector2(0, -size.y * 0.55),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white.withOpacity(0.0),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(hpText);

    // HP bar background - start invisible
    add(
      RectangleComponent(
        size: Vector2(140, 12),
        position: Vector2(0, -size.y * 0.45),
        paint: Paint()..color = Colors.black.withOpacity(0.0),
        anchor: Anchor.center,
      ),
    );

    // HP bar fill - start invisible
    hpBarFill = RectangleComponent(
      size: Vector2(136 * combatant.hpPercent, 8),
      position: Vector2(-68, -size.y * 0.45),
      paint: Paint()..color = _getHpColor(combatant.hpPercent).withOpacity(0.0),
      anchor: Anchor.centerLeft,
    );
    add(hpBarFill..priority = 1);

    // Status icon container - above the boss name
    statusIconContainer = PositionComponent(
      position: Vector2(0, -size.y * 0.85),
    );
    add(statusIconContainer);
  }

  /// Boss spawn animation - fade in with scale effect
  void playSpawnAnimation() {
    // Scale up the boss visual
    bossVisual.add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(0.1), EffectController(duration: 0.0)),
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

    // Fade in boss visual by changing paint color
    Future.delayed(Duration(milliseconds: 0), () {
      bossVisual.paint.color = Colors.red.withOpacity(0.6);
    });

    // Fade in name by changing text color
    Future.delayed(Duration(milliseconds: 300), () {
      nameLabel.textRenderer = TextPaint(
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      );
    });

    // Fade in HP text
    Future.delayed(Duration(milliseconds: 400), () {
      hpText.textRenderer = TextPaint(
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
    });

    // Fade in HP bar
    Future.delayed(Duration(milliseconds: 500), () {
      hpBarFill.paint.color = _getHpColor(combatant.hpPercent);
    });
  }

  Color _getHpColor(double percent) {
    if (percent > 0.5) return Colors.green;
    if (percent > 0.25) return Colors.yellow;
    return Colors.red;
  }

  void updateHpBar() {
    hpText.text = '${combatant.currentHp}/${combatant.maxHp}';

    // Animate HP bar size change
    final targetSize = Vector2(136 * combatant.hpPercent, 8);
    hpBarFill.add(
      SizeEffect.to(
        targetSize,
        EffectController(duration: 0.3, curve: Curves.easeOut),
      ),
    );

    // Update color
    hpBarFill.paint.color = _getHpColor(combatant.hpPercent);
  }

  void updateStatusIcons() {
    // Safe way to clear - schedule removal
    final toRemove = statusIconContainer.children.toList();
    for (final child in toRemove) {
      child.removeFromParent();
    }

    // Separate status effects and stat modifiers for better organization
    final effects = combatant.statusEffects.values.toList();
    final modifiers = combatant.statModifiers.values.toList();

    if (effects.isEmpty && modifiers.isEmpty) return;

    // Layout configuration
    const double iconWidth = 50.0;
    const double rowSpacing = 24.0;

    // Create effects row if any
    if (effects.isNotEmpty) {
      final effectsRow = PositionComponent(position: Vector2(0, 0));

      for (int i = 0; i < effects.length; i++) {
        final icon = _createStatusIcon(effects[i].type);
        icon.position = Vector2(
          (i - effects.length / 2 + 0.5) * (iconWidth + 4),
          0,
        );
        effectsRow.add(icon);
      }

      statusIconContainer.add(effectsRow);
    }

    // Create modifiers row if any
    if (modifiers.isNotEmpty) {
      final modifiersRow = PositionComponent(
        position: Vector2(0, effects.isEmpty ? 0 : rowSpacing),
      );

      for (int i = 0; i < modifiers.length; i++) {
        final icon = _createStatModifierIcon(modifiers[i].type);
        icon.position = Vector2(
          (i - modifiers.length / 2 + 0.5) * (iconWidth + 4),
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
        bgColor = Colors.orange.withOpacity(0.8);
        textColor = Colors.white;
        text = 'BURN';
        break;
      case 'poison':
        bgColor = Colors.purple.withOpacity(0.8);
        textColor = Colors.white;
        text = 'PSN';
        break;
      case 'freeze':
        bgColor = Colors.cyan.withOpacity(0.8);
        textColor = Colors.black;
        text = 'FRZ';
        break;
      case 'curse':
        bgColor = Colors.purple.shade900.withOpacity(0.8);
        textColor = Colors.white;
        text = 'CURSE';
        break;
      case 'regen':
        bgColor = Colors.green.withOpacity(0.8);
        textColor = Colors.white;
        text = 'REGEN';
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.8);
        textColor = Colors.white;
        text = '???';
    }

    final container = PositionComponent(
      size: Vector2(48, 18),
      anchor: Anchor.center,
    );

    // Background pill shape
    final bg = RectangleComponent(
      size: Vector2(48, 18),
      paint: Paint()..color = bgColor,
      anchor: Anchor.center,
    )..position = Vector2(24, 9);

    container.add(bg);

    // Text
    final textComponent = TextComponent(
      text: text,
      anchor: Anchor.center,
      position: Vector2(24, 9),
      textRenderer: TextPaint(
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    container.add(textComponent);

    return container;
  }

  PositionComponent _createStatModifierIcon(String modifierType) {
    Color bgColor;
    Color textColor;
    String text;

    switch (modifierType) {
      case 'attack_up':
        bgColor = Colors.red.withOpacity(0.8);
        textColor = Colors.white;
        text = 'ATK ↑';
        break;
      case 'attack_down':
        bgColor = Colors.red.shade300.withOpacity(0.8);
        textColor = Colors.white;
        text = 'ATK ↓';
        break;
      case 'defense_up':
        bgColor = Colors.blue.withOpacity(0.8);
        textColor = Colors.white;
        text = 'DEF ↑';
        break;
      case 'defense_down':
        bgColor = Colors.blue.shade300.withOpacity(0.8);
        textColor = Colors.white;
        text = 'DEF ↓';
        break;
      case 'speed_up':
        bgColor = Colors.yellow.withOpacity(0.8);
        textColor = Colors.black;
        text = 'SPD ↑';
        break;
      case 'speed_down':
        bgColor = Colors.yellow.shade700.withOpacity(0.8);
        textColor = Colors.white;
        text = 'SPD ↓';
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.8);
        textColor = Colors.white;
        text = '???';
    }

    final container = PositionComponent(
      size: Vector2(48, 18),
      anchor: Anchor.center,
    );

    // Background pill shape
    final bg = RectangleComponent(
      size: Vector2(48, 18),
      paint: Paint()..color = bgColor,
      anchor: Anchor.center,
    )..position = Vector2(24, 9);

    container.add(bg);

    // Text
    final textComponent = TextComponent(
      text: text,
      anchor: Anchor.center,
      position: Vector2(24, 9),
      textRenderer: TextPaint(
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    container.add(textComponent);

    return container;
  }

  Future<void> playAttackAnimation(
    BattleMove move,
    PositionComponent target,
  ) async {
    final originalPos = position.clone();
    final isPhysical = move.type == MoveType.physical;

    final forwardPos = isPhysical
        ? target.position + Vector2(0, 40)
        : position + Vector2(0, 10);

    // Spawn attack FX immediately
    final fx = AttackAnimations.getAnimation(
      move,
      combatant.types.first,
    ).createEffect(target.position);
    gameRef.post(() => gameRef.add(fx));

    // Chain forward + back as a single sequence
    final completer = Completer<void>();

    final seq = SequenceEffect([
      MoveEffect.to(
        forwardPos,
        EffectController(duration: 0.20, curve: Curves.easeOut),
      ),
      MoveEffect.to(
        originalPos,
        EffectController(duration: 0.20, curve: Curves.easeIn),
      ),
    ]);

    seq.onComplete = () => completer.complete();

    add(seq);

    await completer.future;
  }

  void showDamage(int damage, double typeMultiplier) {
    final color = typeMultiplier > 1.0
        ? Colors.orange
        : typeMultiplier < 1.0
        ? Colors.grey
        : Colors.white;

    final damageText = TextComponent(
      text: '-$damage',
      position: position + Vector2(0, -40),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 36,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(blurRadius: 8, color: Colors.black),
            Shadow(blurRadius: 4, color: Colors.black),
          ],
        ),
      ),
    );

    gameRef.post(() {
      gameRef.add(damageText);

      damageText.add(
        MoveEffect.by(
          Vector2(0, -60),
          EffectController(duration: 1.0, curve: Curves.easeOut),
        ),
      );
      damageText.add(RemoveEffect(delay: 1.0));
    });

    shake(intensity: 12, repeats: 3);
  }
}

// Events for communication with Flutter UI
abstract class BattleGameEvent {}

class CreatureSelectedEvent extends BattleGameEvent {
  final int index;
  CreatureSelectedEvent(this.index);
}

class AttackExecutedEvent extends BattleGameEvent {
  final BattleResult result;
  AttackExecutedEvent(this.result);
}

class BossAttackExecutedEvent extends BattleGameEvent {
  final BattleResult result;
  final int targetIndex;
  BossAttackExecutedEvent(this.result, this.targetIndex);
}

class StatusEffectEvent extends BattleGameEvent {
  final List<String> messages;
  StatusEffectEvent(this.messages);
}

class VictoryEvent extends BattleGameEvent {}

class DefeatEvent extends BattleGameEvent {}
