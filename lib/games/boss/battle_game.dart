// lib/games/boss/battle_game.dart
import 'dart:async';
import 'dart:math';
import 'package:alchemons/games/boss/attack_animations.dart';
import 'package:alchemons/games/boss/sprite_battle_adapter.dart';
import 'package:alchemons/models/boss/boss_model.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
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
  int _bossTurnCount = 0;

  // Command queue to safely handle mutations from Flutter UI
  final _pending = <void Function()>[];

  BattleGame({
    required this.boss,
    required this.playerTeam,
    required this.onGameEvent,
  });

  @override
  Color backgroundColor() => const Color(0x00000000);

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

    // Preload all needed textures once
    final paths = <String>[];
    for (final bc in playerTeam) {
      final sheet = bc.sheetDef;
      if (sheet != null) paths.add(sheet.path);
    }
    final bossSheet = boss.sheetDef;
    if (bossSheet != null) {
      paths.add(bossSheet.path);
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
      position: Vector2(size.x / 2, size.y * 0.38),
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

    final blocked = BattleEngine.resolveTurnBlock(attacker, move);
    if (blocked != null) {
      await attackerSprite.playSkipTurnAnimation();
      onGameEvent(AttackExecutedEvent(blocked));

      // Boss still gets a turn when player action is skipped
      await Future.delayed(Duration(milliseconds: 350));
      await executeBossAttack();
      return;
    }

    // Play attack animation
    await attackerSprite.playAttackAnimation(move, bossSprite);

    // Calculate damage
    final action = BattleAction(actor: attacker, move: move, target: boss);
    final result = BattleEngine.executeAction(action);

    // Shake camera on hit
    shakeCamera(intensity: result.damage / 5.0);

    // Show damage numbers + hit feedback
    bossSprite.showDamage(
      result.damage,
      result.typeMultiplier,
      isCritical: result.isCritical,
    );
    bossSprite.playHitFlash(isCrit: result.isCritical);
    _showTypeEffectivenessText(bossSprite.position, result.typeMultiplier);
    bossSprite.updateHpBar();
    bossSprite.updateStatusIcons();

    // Send result to UI
    onGameEvent(AttackExecutedEvent(result));

    // Check if boss defeated
    if (boss.isDead) {
      await bossSprite.playDeathAnimation();
      await Future.delayed(Duration(milliseconds: 400));
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

    final moveSelection = _selectBossMove();
    final bossMove = moveSelection.move;
    final selectedType = moveSelection.sourceMove?.type;

    final blocked = BattleEngine.resolveTurnBlock(boss, bossMove);
    if (blocked != null) {
      await bossSprite.playSkipTurnAnimation();
      onGameEvent(BossAttackExecutedEvent(blocked, targetIndex));

      // Process end-of-turn effects and continue flow
      await processEndOfTurn();
      state = BattleState.playerTurn;
      return;
    }

    // Play boss attack animation
    await bossSprite.playAttackAnimation(bossMove, targetSprite);

    // Typed boss moveset actions
    if (selectedType == BossMoveType.aoe) {
      await _executeBossAoeAttack(bossMove);
      if (playerTeam.every((c) => c.isDead)) {
        return;
      }
      _bossTurnCount++;
      await processEndOfTurn();
      state = BattleState.playerTurn;
      return;
    }

    if (selectedType == BossMoveType.buff) {
      final result = _executeBossBuffMove(bossMove);
      _bossTurnCount++;
      onGameEvent(BossAttackExecutedEvent(result, targetIndex));

      await Future.delayed(Duration(milliseconds: 200));
      bossSprite.updateStatusIcons();
      for (final sprite in playerSprites) {
        sprite.updateStatusIcons();
      }

      await processEndOfTurn();
      state = BattleState.playerTurn;
      return;
    }

    if (selectedType == BossMoveType.debuff) {
      final result = _executeBossDebuffMove(bossMove, target);
      _bossTurnCount++;
      onGameEvent(BossAttackExecutedEvent(result, targetIndex));

      await Future.delayed(Duration(milliseconds: 200));
      bossSprite.updateStatusIcons();
      for (final sprite in playerSprites) {
        sprite.updateStatusIcons();
      }

      await processEndOfTurn();
      state = BattleState.playerTurn;
      return;
    }

    if (selectedType == BossMoveType.heal) {
      final result = _executeBossHealMove(bossMove);
      _bossTurnCount++;
      onGameEvent(BossAttackExecutedEvent(result, targetIndex));

      await Future.delayed(Duration(milliseconds: 200));
      bossSprite.updateStatusIcons();
      bossSprite.updateHpBar();

      await processEndOfTurn();
      state = BattleState.playerTurn;
      return;
    }

    // Calculate damage
    final action = BattleAction(actor: boss, move: bossMove, target: target);
    final result = BattleEngine.executeAction(action);
    _bossTurnCount++;

    // Shake camera
    if (result.damage > 0) {
      shakeCamera(intensity: result.damage / 5.0);
    }

    // Show damage + hit feedback (with safety check)
    if (result.damage > 0 && !target.isDead) {
      targetSprite.showDamage(
        result.damage,
        result.typeMultiplier,
        isCritical: result.isCritical,
      );
      targetSprite.playHitFlash(isCrit: result.isCritical);
      _showTypeEffectivenessText(targetSprite.position, result.typeMultiplier);
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

  _BossMoveSelection _selectBossMove() {
    final family = boss.family == 'Boss' ? 'Mystic' : boss.family;
    final basicMove = BattleMove.getBasicMove(family);
    final bossMoveset = boss.bossMoveset;

    if (bossMoveset.isNotEmpty) {
      final options = <_WeightedBossMove>[];
      final aliveCount = playerTeam.where((c) => c.isAlive).length;

      for (final move in bossMoveset) {
        final weight = _weightForMoveType(move.type, aliveCount: aliveCount);
        if (weight <= 0) continue;
        options.add(_WeightedBossMove(move: move, weight: weight));
      }

      if (options.isNotEmpty) {
        final selected = _rollWeightedMove(options);
        final translated = _battleMoveFromBossMove(selected, family, basicMove);
        return _BossMoveSelection(move: translated, sourceMove: selected);
      }
    }

    final canUseSpecial = boss.level >= 5 && !boss.needsRecharge;
    final shouldUseSpecial =
        canUseSpecial &&
        (_bossTurnCount % 3 == 2 || Random().nextDouble() < 0.25);

    if (shouldUseSpecial) {
      return _BossMoveSelection(move: BattleMove.getSpecialMove(family));
    }

    return _BossMoveSelection(move: basicMove);
  }

  double _weightForMoveType(BossMoveType type, {required int aliveCount}) {
    switch (type) {
      case BossMoveType.singleTarget:
        return 3.6;
      case BossMoveType.aoe:
        return aliveCount >= 3 ? 2.4 : 1.2;
      case BossMoveType.buff:
        return boss.statModifiers.isEmpty ? 1.5 : 0.7;
      case BossMoveType.debuff:
        return 1.5;
      case BossMoveType.heal:
        if (boss.hpPercent <= 0.35) return 2.8;
        if (boss.hpPercent <= 0.6) return 1.4;
        if (boss.hpPercent <= 0.85) return 0.4;
        return 0.0;
      case BossMoveType.special:
        if (boss.level < 5 || boss.needsRecharge) return 0.0;
        return 2.2;
    }
  }

  BossMove _rollWeightedMove(List<_WeightedBossMove> options) {
    final total = options.fold<double>(0, (sum, e) => sum + e.weight);
    var ticket = Random().nextDouble() * total;
    for (final option in options) {
      ticket -= option.weight;
      if (ticket <= 0) return option.move;
    }
    return options.last.move;
  }

  BattleMove _battleMoveFromBossMove(
    BossMove source,
    String family,
    BattleMove basicMove,
  ) {
    if (source.type == BossMoveType.special) {
      final special = BattleMove.getSpecialMove(family);
      return BattleMove(
        name: source.name,
        type: special.type,
        scalingStat: special.scalingStat,
        isSpecial: true,
        family: special.family,
      );
    }

    return BattleMove(
      name: source.name,
      type: basicMove.type,
      scalingStat: basicMove.scalingStat,
      isSpecial: false,
      family: basicMove.family,
    );
  }

  BattleResult _executeBossBuffMove(BattleMove move) {
    boss.applyStatModifier(StatModifier(type: 'attack_up', duration: 2));
    boss.applyStatModifier(StatModifier(type: 'defense_up', duration: 2));

    return BattleResult(
      damage: 0,
      isCritical: false,
      typeMultiplier: 1.0,
      messages: [
        '${boss.name} used ${move.name}!',
        '${boss.name} raised its attack and defense!',
      ],
      targetDefeated: false,
    );
  }

  BattleResult _executeBossDebuffMove(BattleMove move, BattleCombatant target) {
    target.applyStatModifier(StatModifier(type: 'defense_down', duration: 2));
    target.applyStatModifier(StatModifier(type: 'speed_down', duration: 2));

    return BattleResult(
      damage: 0,
      isCritical: false,
      typeMultiplier: 1.0,
      messages: [
        '${boss.name} used ${move.name} on ${target.name}!',
        '${target.name} had defense and speed reduced!',
      ],
      targetDefeated: false,
    );
  }

  BattleResult _executeBossHealMove(BattleMove move) {
    final before = boss.currentHp;
    final healAmount = max(1, (boss.maxHp * 0.18).round());
    boss.heal(healAmount);
    final recovered = boss.currentHp - before;

    return BattleResult(
      damage: 0,
      isCritical: false,
      typeMultiplier: 1.0,
      messages: [
        '${boss.name} used ${move.name}!',
        '${boss.name} restored $recovered HP!',
      ],
      targetDefeated: false,
    );
  }

  Future<void> _executeBossAoeAttack(BattleMove move) async {
    final aliveTargets = playerTeam
        .asMap()
        .entries
        .where((entry) => entry.value.isAlive)
        .toList();

    if (aliveTargets.isEmpty) return;

    var maxDamage = 0;
    final defeatedIndexes = <int>[];

    for (final entry in aliveTargets) {
      final targetIndex = entry.key;
      final target = entry.value;
      final sprite = playerSprites[targetIndex];

      final result = BattleEngine.executeAction(
        BattleAction(actor: boss, move: move, target: target),
      );

      maxDamage = max(maxDamage, result.damage);
      if (result.damage > 0 && !target.isDead) {
        sprite.showDamage(result.damage, result.typeMultiplier);
        sprite.playHitFlash();
      }

      if (target.isDead) {
        defeatedIndexes.add(targetIndex);
      }

      onGameEvent(BossAttackExecutedEvent(result, targetIndex));
      await Future.delayed(Duration(milliseconds: 90));
    }

    if (maxDamage > 0) {
      shakeCamera(intensity: maxDamage / 5.0);
    }

    await Future.delayed(Duration(milliseconds: 200));
    for (final sprite in playerSprites) {
      sprite.updateStatusIcons();
    }

    for (final targetIndex in defeatedIndexes) {
      if (targetIndex < playerSprites.length) {
        playerSprites[targetIndex].playDeathAnimation();
      }
    }

    if (defeatedIndexes.isNotEmpty) {
      await Future.delayed(Duration(milliseconds: 750));
    }

    if (playerTeam.every((c) => c.isDead)) {
      await Future.delayed(Duration(seconds: 1));
      onGameEvent(DefeatEvent());
    }
  }

  void _showTypeEffectivenessText(Vector2 pos, double multiplier) {
    if (multiplier >= 0.8 && multiplier <= 1.4) return; // neutral range, skip

    final isSuperEffective = multiplier > 1.4;
    final text = isSuperEffective
        ? 'SUPER EFFECTIVE!'
        : 'Not very effective...';
    final color = isSuperEffective ? Colors.orangeAccent : Colors.grey.shade400;
    final fontSize = isSuperEffective ? 15.0 : 12.0;

    final label = TextComponent(
      text: text,
      position: pos + Vector2(0, -95),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: isSuperEffective ? FontWeight.w900 : FontWeight.normal,
          letterSpacing: isSuperEffective ? 0.5 : 0.0,
          shadows: [Shadow(blurRadius: 6, color: Colors.black)],
        ),
      ),
    );

    add(label);
    label.add(
      MoveEffect.by(
        Vector2(0, -30),
        EffectController(duration: 0.9, curve: Curves.easeOut),
      ),
    );
    label.add(RemoveEffect(delay: 0.9));
  }

  Future<void> processEndOfTurn() async {
    // Process DoT, regen, etc for all combatants
    for (final combatant in [...playerTeam, boss]) {
      final messages = BattleEngine.processEndOfTurnEffects(combatant);
      if (messages.isNotEmpty) {
        onGameEvent(
          StatusEffectEvent(messages, isBossSource: identical(combatant, boss)),
        );
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
  late PositionComponent statusIconContainer;
  CircleComponent? bossVisual;
  CreatureSpriteComponentBattle? creatureVisual;
  late final Color _auraColor;

  BossSprite({required this.combatant, required Vector2 position})
    : super(position: position, size: Vector2(150, 150), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    // Keep boss fully hidden until playSpawnAnimation() runs.
    scale = Vector2.all(0.0);

    _auraColor = _getAuraColor();
    final center = size / 2;

    final sheet = combatant.sheetDef;
    final visuals = combatant.spriteVisuals;

    if (sheet != null && visuals != null) {
      creatureVisual =
          CreatureSpriteComponentBattle(
              sheet: sheet,
              visuals: visuals,
              desiredSize: Vector2(150, 150),
            )
            ..position = center
            ..anchor = Anchor.center
            ..priority = 1;
      add(creatureVisual!);
    } else {
      // Fallback placeholder only if sprite data is unavailable
      bossVisual = CircleComponent(
        radius: 60,
        paint: Paint()
          ..color = _auraColor.withOpacity(0.0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
        anchor: Anchor.center,
        position: center,
      )..priority = -1;
      add(bossVisual!);
    }

    // Status icon container - anchored near the boss sprite (right/top)
    statusIconContainer = PositionComponent(
      anchor: Anchor.center,
      position: center + Vector2(size.x * 0.62, -size.y * 0.22),
    );
    add(statusIconContainer);
  }

  /// Boss spawn animation - fade in with scale effect
  void playSpawnAnimation() {
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(0.1), EffectController(duration: 0.0)),
        ScaleEffect.to(
          Vector2.all(1.15),
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
      if (bossVisual != null) {
        bossVisual!.paint.color = _auraColor.withOpacity(0.35);
      }
    });
  }

  Future<void> playDeathAnimation() async {
    final completer = Completer<void>();

    // Remove status badges immediately
    statusIconContainer.removeFromParent();

    // Rapid white flash bursts
    for (int f = 0; f < 4; f++) {
      Future.delayed(Duration(milliseconds: f * 90), () {
        final flash = RectangleComponent(
          size: size * 1.2,
          paint: Paint()..color = Colors.white.withOpacity(0.65),
          anchor: Anchor.center,
          position: size / 2,
          priority: 30,
        );
        add(flash);
        flash.add(OpacityEffect.fadeOut(EffectController(duration: 0.10)));
        flash.add(RemoveEffect(delay: 0.12));
      });
    }

    await Future.delayed(const Duration(milliseconds: 430));

    // Explosion: briefly scale up then collapse to zero
    add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.5),
          EffectController(duration: 0.12, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2.all(0.0),
          EffectController(duration: 0.35, curve: Curves.easeIn),
        ),
      ], onComplete: () => completer.complete()),
    );

    // Scatter 18 particles outward from the boss position
    for (int i = 0; i < 18; i++) {
      final angle = (i / 18.0) * pi * 2;
      final dist = 70.0 + Random().nextDouble() * 110;
      final colors = [_auraColor, Colors.white, Colors.orangeAccent];
      final particle = CircleComponent(
        radius: 3 + Random().nextDouble() * 8,
        paint: Paint()..color = colors[i % colors.length],
        anchor: Anchor.center,
        position: position.clone(),
        priority: 50,
      );
      gameRef.add(particle);
      particle.add(
        MoveEffect.by(
          Vector2(cos(angle) * dist, sin(angle) * dist),
          EffectController(duration: 0.65, curve: Curves.easeOut),
        ),
      );
      particle.add(OpacityEffect.fadeOut(EffectController(duration: 0.65)));
      particle.add(RemoveEffect(delay: 0.7));
    }

    await completer.future;
    removeFromParent();
  }

  Color _getAuraColor() {
    if (combatant.types.isEmpty) return Colors.deepPurple;
    switch (combatant.types.first.toLowerCase()) {
      case 'fire':
        return Colors.deepOrange;
      case 'water':
        return Colors.blue;
      case 'earth':
        return Colors.brown;
      case 'air':
        return Colors.cyan;
      case 'plant':
        return Colors.green;
      case 'ice':
        return Colors.lightBlue;
      case 'lightning':
        return Colors.yellow;
      case 'poison':
        return Colors.purple;
      case 'steam':
        return Colors.teal;
      case 'lava':
        return Colors.deepOrangeAccent;
      case 'mud':
        return Colors.brown.shade700;
      case 'dust':
        return Colors.orange.shade300;
      case 'crystal':
        return Colors.pinkAccent;
      case 'spirit':
        return Colors.indigo.shade200;
      case 'dark':
        return Colors.deepPurple.shade700;
      case 'light':
        return Colors.amber;
      case 'blood':
        return Colors.red.shade900;
      default:
        return Colors.deepPurple;
    }
  }

  void updateHpBar() {
    // Boss HP UI is handled by Flutter header HUD.
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

  Future<void> playSkipTurnAnimation() async {
    // Small shake + slight squash/stretch to indicate a skipped turn.
    shake(intensity: 7, repeats: 3, segment: 0.05);

    add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2(1.06, 0.94),
          EffectController(duration: 0.08, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.10, curve: Curves.easeIn),
        ),
      ]),
    );

    await Future.delayed(Duration(milliseconds: 220));
  }

  void playHitFlash({bool isCrit = false}) {
    final flashColor = isCrit ? Colors.yellow : Colors.white;
    final flash = CircleComponent(
      radius: 88,
      position: size / 2,
      anchor: Anchor.center,
      paint: Paint()..color = flashColor.withOpacity(0.50),
      priority: 20,
    );
    flash.add(RemoveEffect(delay: 0.15));
    add(flash);
  }

  void showDamage(
    int damage,
    double typeMultiplier, {
    bool isCritical = false,
  }) {
    final color = isCritical
        ? Colors.yellow
        : typeMultiplier > 1.0
        ? Colors.orange
        : typeMultiplier < 1.0
        ? Colors.grey
        : Colors.white;

    final fontSize = isCritical ? 46.0 : 36.0;

    if (isCritical) {
      final critLabel = TextComponent(
        text: 'CRIT!',
        position: position + Vector2(0, -70),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: Colors.yellow,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            shadows: [Shadow(blurRadius: 6, color: Colors.black)],
          ),
        ),
      );
      gameRef.post(() {
        gameRef.add(critLabel);
        critLabel.add(
          MoveEffect.by(Vector2(0, -25), EffectController(duration: 0.6)),
        );
        critLabel.add(RemoveEffect(delay: 0.6));
      });
    }

    final damageText = TextComponent(
      text: '-$damage',
      position: position + Vector2(0, -40),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: fontSize,
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
  final bool isBossSource;
  StatusEffectEvent(this.messages, {required this.isBossSource});
}

class VictoryEvent extends BattleGameEvent {}

class DefeatEvent extends BattleGameEvent {}

class _BossMoveSelection {
  final BattleMove move;
  final BossMove? sourceMove;

  const _BossMoveSelection({required this.move, this.sourceMove});
}

class _WeightedBossMove {
  final BossMove move;
  final double weight;

  const _WeightedBossMove({required this.move, required this.weight});
}
