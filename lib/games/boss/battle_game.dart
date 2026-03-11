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
  bool _bossChargedAttack = false;
  bool _mudSinkPendingStrike = false;
  int _dustMirageCharges = 0;
  int _darkBanishCooldownTurns = 0;
  bool _lightAegisTriggered = false;

  // Command queue to safely handle mutations from Flutter UI
  final _pending = <void Function()>[];

  BattleGame({
    required this.boss,
    required this.playerTeam,
    required this.onGameEvent,
  });

  @override
  Color backgroundColor() => const Color(0x00000000);

  void _setBattleState(BattleState newState) {
    state = newState;
    onGameEvent(TurnStateChangedEvent(newState));
  }

  CreatureBattleSpriteWithVisuals? _spriteForTeamIndex(int index) {
    for (final sprite in playerSprites) {
      if (sprite.index == index) return sprite;
    }
    return null;
  }

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
        debugPrint('Error executing queued command: $e\n$st');
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
      debugPrint('Error preloading images: $e');
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

    // Keep UI and game state aligned from the first frame.
    _autoSelectNextCreature();
    _setBattleState(BattleState.playerTurn);
  }

  void selectCreature(int index) {
    if (state != BattleState.playerTurn) return;
    if (index >= playerTeam.length) return; // Safety: index out of bounds
    if (!playerTeam[index].canAct) return; // On cooldown or dead

    // Deselect previous
    _spriteForTeamIndex(currentPlayerIndex)?.setSelected(false);

    currentPlayerIndex = index;
    _spriteForTeamIndex(currentPlayerIndex)?.setSelected(true);
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

  String get _bossElement =>
      boss.types.isNotEmpty ? boss.types.first : 'Normal';
  String get _bossElementLower => _bossElement.toLowerCase();

  Future<void> executePlayerAttack(BattleMove move) async {
    if (state != BattleState.playerTurn) return;
    if (currentPlayerIndex >= playerTeam.length) return; // Safety check

    final attacker = playerTeam[currentPlayerIndex];

    // Safety check: don't attack if creature is dead or on cooldown
    if (attacker.isDead || !attacker.canAct) {
      _recoverPlayerTurnSelection();
      _setBattleState(BattleState.playerTurn);
      return;
    }

    _setBattleState(BattleState.animating);
    final attackerSprite = _spriteForTeamIndex(currentPlayerIndex);

    final blocked = BattleEngine.resolveTurnBlock(attacker, move);
    if (blocked != null) {
      if (attackerSprite != null) {
        await attackerSprite.playSkipTurnAnimation();
      }
      onGameEvent(AttackExecutedEvent(blocked));

      // Set action cooldown even if blocked
      attacker.actionCooldown = 2;

      // Boss still gets a turn when player action is skipped
      await Future.delayed(Duration(milliseconds: 350));
      await executeBossAttack();
      return;
    }

    // Play attack animation
    if (attackerSprite != null) {
      await attackerSprite.playAttackAnimation(move, bossSprite);
    }

    final prevented = _resolveBossDefensiveReaction(attacker, move);
    if (prevented != null) {
      attacker.actionCooldown = 2;
      onGameEvent(AttackExecutedEvent(prevented));
      await Future.delayed(Duration(milliseconds: 350));
      await executeBossAttack();
      return;
    }

    // Calculate damage — pass ally team for team-affecting specials
    final action = BattleAction(actor: attacker, move: move, target: boss);
    var result = BattleEngine.executeAction(action, allyTeam: playerTeam);

    if (result.damage > 0) {
      attacker.totalDamageDealt += result.damage;
    }

    final reactiveMessages = <String>[];
    final reflectedDamage = _applyBossReactiveDefenses(
      attacker: attacker,
      move: move,
      dealtDamage: result.damage,
      messages: reactiveMessages,
    );
    if (reactiveMessages.isNotEmpty) {
      result = BattleResult(
        damage: result.damage,
        isCritical: result.isCritical,
        typeMultiplier: result.typeMultiplier,
        messages: [...result.messages, ...reactiveMessages],
        targetDefeated: result.targetDefeated,
      );
    }

    // Set action cooldown after acting
    attacker.actionCooldown = 2;

    // Shake camera on hit
    if (result.damage > 0) {
      shakeCamera(intensity: result.damage / 5.0);
    }

    // Show damage numbers + hit feedback
    if (result.damage > 0) {
      bossSprite.showDamage(
        result.damage,
        result.typeMultiplier,
        isCritical: result.isCritical,
      );
      bossSprite.playHitFlash(isCrit: result.isCritical);
      _showTypeEffectivenessText(bossSprite.position, result.typeMultiplier);
    }
    if (reflectedDamage > 0) {
      attackerSprite?.showDamage(reflectedDamage, 1.0);
      attackerSprite?.playHitFlash();
    }
    bossSprite.updateHpBar();
    bossSprite.updateStatusIcons();

    // Update all player sprites (shields, regen, etc. from team specials)
    for (final sprite in playerSprites) {
      sprite.updateStatusIcons();
      sprite.updateHpBar();
    }

    // Send result to UI
    onGameEvent(AttackExecutedEvent(result));

    // Check if boss defeated
    if (boss.isDead) {
      await bossSprite.playDeathAnimation();
      await Future.delayed(Duration(milliseconds: 400));
      onGameEvent(VictoryEvent());
      return;
    }

    if (attacker.isDead) {
      attackerSprite?.playDeathAnimation();
      if (playerTeam.every((c) => c.isDead)) {
        await Future.delayed(Duration(milliseconds: 400));
        onGameEvent(DefeatEvent());
        return;
      }
    }

    // Boss turn
    await Future.delayed(Duration(milliseconds: 500));
    await executeBossAttack();
  }

  Future<void> executeBossAttack() async {
    _setBattleState(BattleState.bossTurn);

    if (_darkBanishCooldownTurns > 0) {
      _darkBanishCooldownTurns--;
    }

    final targetableCreatures = playerTeam
        .asMap()
        .entries
        .where((e) => e.value.canBeTargeted)
        .toList();

    if (_mudSinkPendingStrike) {
      if (targetableCreatures.isEmpty) {
        await processEndOfTurn();
        _setBattleState(BattleState.playerTurn);
        return;
      }

      final ambushTarget = targetableCreatures.first;
      final sinkAmbushMove = BattleMove(
        name: 'Sink Ambush',
        type: MoveType.elemental,
        scalingStat: 'statIntelligence',
        isSpecial: false,
        family: boss.family,
      );
      final ambushSprite = _spriteForTeamIndex(ambushTarget.key);
      if (ambushSprite != null) {
        await bossSprite.playAttackAnimation(sinkAmbushMove, ambushSprite);
      }
      await _executeBossAoeAttack(sinkAmbushMove, damageMultiplier: 1.45);
      _mudSinkPendingStrike = false;
      _bossTurnCount++;
      await processEndOfTurn();
      _setBattleState(BattleState.playerTurn);
      return;
    }

    // Boss picks target — check for taunt first
    final aliveCreatures = targetableCreatures;

    if (aliveCreatures.isEmpty) {
      if (playerTeam.every((c) => c.isDead)) {
        onGameEvent(DefeatEvent());
        return;
      }

      onGameEvent(
        StatusEffectEvent([
          '${boss.name} cannot find a target outside the void...',
        ], isBossSource: true),
      );
      await Future.delayed(Duration(milliseconds: 350));
      await processEndOfTurn();
      _recoverPlayerTurnSelection();

      if (!playerTeam.any((c) => c.canAct) &&
          playerTeam.any((c) => c.isAlive && c.isBanished)) {
        await Future.delayed(Duration(milliseconds: 300));
        await executeBossAttack();
        return;
      }

      _setBattleState(BattleState.playerTurn);
      return;
    }

    // If boss is taunted, try to target the taunting creature
    MapEntry<int, BattleCombatant>? targetEntry;
    if (boss.tauntTargetId != null) {
      targetEntry = aliveCreatures
          .cast<MapEntry<int, BattleCombatant>?>()
          .firstWhere(
            (e) => e!.value.id == boss.tauntTargetId,
            orElse: () => null,
          );
    }
    // Fallback to random alive creature
    targetEntry ??=
        aliveCreatures[DateTime.now().millisecondsSinceEpoch %
            aliveCreatures.length];
    final targetIndex = targetEntry.key;
    final target = targetEntry.value;

    final targetSprite = _spriteForTeamIndex(targetIndex);

    final moveSelection = _selectBossMove();
    final bossMove = moveSelection.move;
    final selectedType = moveSelection.sourceMove?.type;
    final selectedName = (moveSelection.sourceMove?.name ?? bossMove.name)
        .toLowerCase();
    final isUtilitySpecial = selectedName == 'sink' || selectedName == 'mirage';
    final usesChargedStrike =
        _bossChargedAttack &&
        (selectedType == BossMoveType.singleTarget ||
            selectedType == BossMoveType.aoe ||
            (selectedType == BossMoveType.special && !isUtilitySpecial));
    final damageMultiplier = usesChargedStrike ? 2.0 : 1.0;

    final blocked = BattleEngine.resolveTurnBlock(boss, bossMove);
    if (blocked != null) {
      await bossSprite.playSkipTurnAnimation();
      onGameEvent(BossAttackExecutedEvent(blocked, targetIndex));

      // Process end-of-turn effects and continue flow
      await processEndOfTurn();
      _setBattleState(BattleState.playerTurn);
      return;
    }

    if (usesChargedStrike) {
      _bossChargedAttack = false;
    }

    // Play boss attack animation
    if (targetSprite != null) {
      await bossSprite.playAttackAnimation(bossMove, targetSprite);
    }

    // Typed boss moveset actions
    if (selectedType == BossMoveType.aoe) {
      await _executeBossAoeAttack(bossMove, damageMultiplier: damageMultiplier);
      if (playerTeam.every((c) => c.isDead)) {
        return;
      }
      _bossTurnCount++;
      await processEndOfTurn();
      _setBattleState(BattleState.playerTurn);
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
      _setBattleState(BattleState.playerTurn);
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
      _setBattleState(BattleState.playerTurn);
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
      _setBattleState(BattleState.playerTurn);
      return;
    }

    if (selectedType == BossMoveType.special) {
      var result = _executeBossSpecialMove(bossMove, target);
      if (result.damage > 0) {
        result = _applyBossMoveRiders(
          move: bossMove,
          target: target,
          baseResult: result,
          damageMultiplier: damageMultiplier,
        );
      }
      _bossTurnCount++;
      onGameEvent(BossAttackExecutedEvent(result, targetIndex));

      if (result.damage > 0) {
        shakeCamera(intensity: result.damage / 5.0);
        targetSprite?.showDamage(
          result.damage,
          result.typeMultiplier,
          isCritical: result.isCritical,
        );
        targetSprite?.playHitFlash(isCrit: result.isCritical);
      }

      await Future.delayed(Duration(milliseconds: 200));
      bossSprite.updateStatusIcons();
      for (final sprite in playerSprites) {
        sprite.updateStatusIcons();
      }

      if (target.isDead) {
        targetSprite?.playDeathAnimation();
        await Future.delayed(Duration(milliseconds: 750));
      }

      if (playerTeam.every((c) => c.isDead)) {
        await Future.delayed(Duration(seconds: 1));
        onGameEvent(DefeatEvent());
        return;
      }

      await processEndOfTurn();
      _setBattleState(BattleState.playerTurn);
      return;
    }

    // Calculate damage
    final action = BattleAction(actor: boss, move: bossMove, target: target);
    var result = BattleEngine.executeAction(action);
    result = _applyBossMoveRiders(
      move: bossMove,
      target: target,
      baseResult: result,
      damageMultiplier: damageMultiplier,
    );
    _bossTurnCount++;

    // Shake camera
    if (result.damage > 0) {
      shakeCamera(intensity: result.damage / 5.0);
    }

    // Show damage + hit feedback (with safety check)
    if (result.damage > 0) {
      targetSprite?.showDamage(
        result.damage,
        result.typeMultiplier,
        isCritical: result.isCritical,
      );
      targetSprite?.playHitFlash(isCrit: result.isCritical);
      if (targetSprite != null) {
        _showTypeEffectivenessText(
          targetSprite.position,
          result.typeMultiplier,
        );
      }
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
      targetSprite?.playDeathAnimation();

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
    _setBattleState(BattleState.playerTurn);
  }

  _BossMoveSelection _selectBossMove() {
    final family = boss.family == 'Boss' ? 'Mystic' : boss.family;
    final basicMove = BattleMove.getBasicMove(family);
    final bossMoveset = boss.bossMoveset;

    if (bossMoveset.isNotEmpty) {
      final options = <_WeightedBossMove>[];
      final aliveCount = playerTeam.where((c) => c.canBeTargeted).length;

      for (final move in bossMoveset) {
        final weight = _weightForBossMove(move, aliveCount: aliveCount);
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
      return _BossMoveSelection(
        move: BattleMove.getSpecialMoveForCombatant(boss),
      );
    }

    return _BossMoveSelection(move: basicMove);
  }

  double _weightForBossMove(BossMove move, {required int aliveCount}) {
    var weight = _weightForMoveType(move.type, aliveCount: aliveCount);
    if (weight <= 0) return 0;

    final moveName = move.name.toLowerCase();
    switch (moveName) {
      case 'harden':
      case 'fortify':
      case 'ice-shield':
      case 'refract':
        if (boss.statModifiers.containsKey('defense_up')) {
          weight *= 0.45;
        } else {
          weight *= 1.25;
        }
        break;
      case 'evade':
      case 'mist-shroud':
        if (boss.statModifiers.containsKey('speed_up')) {
          weight *= 0.5;
        }
        break;
      case 'charge-up':
        if (_bossChargedAttack) {
          return 0.1;
        }
        weight *= boss.hpPercent <= 0.7 ? 1.8 : 1.2;
        break;
      case 'regen':
      case 'genesis':
        if (boss.hpPercent <= 0.55) {
          weight *= 1.7;
        } else if (boss.hpPercent >= 0.9) {
          weight *= 0.25;
        }
        break;
      case 'empower':
        if (boss.hpPercent <= 0.25) {
          weight *= 0.3;
        } else {
          weight *= 1.6;
        }
        break;
      case 'sink':
        if (_mudSinkPendingStrike ||
            boss.statusEffects.containsKey('submerged')) {
          return 0.0;
        }
        weight *= 1.35;
        break;
      case 'mirage':
        if (_dustMirageCharges > 0) {
          weight *= 0.3;
        } else {
          weight *= 1.5;
        }
        break;
      case 'eclipse':
        if (_darkBanishCooldownTurns <= 0 &&
            playerTeam.where((c) => c.canBeTargeted).length > 1) {
          weight *= 1.9;
        } else {
          weight *= 0.85;
        }
        break;
      default:
        break;
    }

    // Encourage AoE/debuff when multiple targets are available.
    if (move.type == BossMoveType.aoe && aliveCount >= 3) {
      weight *= 1.2;
    }
    if (move.type == BossMoveType.debuff && aliveCount <= 1) {
      weight *= 0.7;
    }

    return max(weight, 0);
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
      final special = BattleMove.getSpecialMoveForCombatant(boss);
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
    final messages = <String>['${boss.name} used ${move.name}!'];
    final moveName = move.name.toLowerCase();

    switch (moveName) {
      case 'harden':
        boss.applyStatModifier(StatModifier(type: 'defense_up', duration: 3));
        messages.add('${boss.name} hardened its armor!');
        break;
      case 'fortify':
        boss.applyStatModifier(StatModifier(type: 'defense_up', duration: 3));
        boss.shieldHp =
            (boss.shieldHp ?? 0) + max(1, (boss.maxHp * 0.12).round());
        messages.add('${boss.name} fortified itself with stone.');
        break;
      case 'evade':
        boss.applyStatModifier(StatModifier(type: 'speed_up', duration: 3));
        messages.add('${boss.name} rides the wind and becomes evasive.');
        break;
      case 'ice-shield':
        boss.applyStatModifier(StatModifier(type: 'defense_up', duration: 2));
        boss.shieldHp =
            (boss.shieldHp ?? 0) + max(1, (boss.maxHp * 0.20).round());
        messages.add('A frozen barrier forms around ${boss.name}!');
        break;
      case 'charge-up':
        _bossChargedAttack = true;
        boss.applyStatModifier(StatModifier(type: 'attack_up', duration: 2));
        messages.add('${boss.name} is fully charged for the next strike!');
        break;
      case 'mist-shroud':
        boss.applyStatModifier(StatModifier(type: 'speed_up', duration: 2));
        boss.applyStatModifier(StatModifier(type: 'attack_up', duration: 1));
        messages.add('${boss.name} vanishes into scalding mist.');
        break;
      case 'molten-armor':
        boss.applyStatModifier(StatModifier(type: 'defense_up', duration: 3));
        boss.applyStatusEffect(
          StatusEffect(type: 'molten_armor', damagePerTurn: 0, duration: 3),
        );
        messages.add('${boss.name} is wreathed in molten armor.');
        break;
      case 'refract':
        boss.applyStatModifier(StatModifier(type: 'defense_up', duration: 2));
        boss.shieldHp =
            (boss.shieldHp ?? 0) + max(1, (boss.maxHp * 0.25).round());
        messages.add('${boss.name} refracted light into a crystal shield.');
        break;
      case 'cleanse':
        for (final type in ['burn', 'poison', 'freeze', 'curse', 'bleed']) {
          boss.statusEffects.remove(type);
        }
        for (final type in ['attack_down', 'defense_down', 'speed_down']) {
          boss.statModifiers.remove(type);
        }
        messages.add('${boss.name} cleansed all impairments.');
        break;
      case 'empower':
        final selfDamage = max(1, (boss.maxHp * 0.10).round());
        boss.takeDamage(selfDamage);
        boss.applyStatModifier(StatModifier(type: 'attack_up', duration: 4));
        messages.add('${boss.name} sacrificed $selfDamage HP to gain power!');
        break;
      default:
        boss.applyStatModifier(StatModifier(type: 'attack_up', duration: 2));
        boss.applyStatModifier(StatModifier(type: 'defense_up', duration: 2));
        messages.add('${boss.name} raised its attack and defense!');
    }

    return BattleResult(
      damage: 0,
      isCritical: false,
      typeMultiplier: 1.0,
      messages: messages,
      targetDefeated: false,
    );
  }

  BattleResult _executeBossDebuffMove(BattleMove move, BattleCombatant target) {
    final messages = <String>['${boss.name} used ${move.name}!'];
    final moveName = move.name.toLowerCase();

    switch (moveName) {
      case 'slow':
        target.applyStatModifier(StatModifier(type: 'speed_down', duration: 3));
        messages.add('${target.name} was drenched and slowed.');
        break;
      case 'corrode':
        final targets = playerTeam.where((c) => c.canBeTargeted).toList();
        for (final t in targets) {
          t.applyStatModifier(StatModifier(type: 'defense_down', duration: 3));
        }
        messages.add('Corrosion spread across the whole party!');
        break;
      case 'quagmire':
        final targets = playerTeam.where((c) => c.canBeTargeted).toList();
        for (final t in targets) {
          t.applyStatModifier(StatModifier(type: 'speed_down', duration: 3));
          t.applyStatModifier(StatModifier(type: 'defense_down', duration: 1));
        }
        messages.add('The team sank into a crippling quagmire.');
        break;
      case 'eclipse':
        final targets = playerTeam.where((c) => c.canBeTargeted).toList();
        for (final t in targets) {
          t.applyStatModifier(StatModifier(type: 'attack_down', duration: 2));
          t.applyStatModifier(StatModifier(type: 'speed_down', duration: 1));
        }
        messages.add('A total eclipse dimmed your party\'s power.');
        _attemptDarkBanish(messages);
        break;
      default:
        target.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 2),
        );
        target.applyStatModifier(StatModifier(type: 'speed_down', duration: 2));
        messages.add('${target.name} had defense and speed reduced!');
    }

    return BattleResult(
      damage: 0,
      isCritical: false,
      typeMultiplier: 1.0,
      messages: messages,
      targetDefeated: false,
    );
  }

  BattleResult _executeBossHealMove(BattleMove move) {
    final moveName = move.name.toLowerCase();
    final messages = <String>['${boss.name} used ${move.name}!'];
    final before = boss.currentHp;

    var healScale = 0.18;
    if (moveName == 'regen') {
      healScale = 0.12;
      boss.applyStatusEffect(
        StatusEffect(
          type: 'regen',
          damagePerTurn: -max(1, (boss.maxHp * 0.06).round()),
          duration: 3,
        ),
      );
      messages.add('${boss.name} began regenerating over time.');
    } else if (moveName == 'genesis') {
      healScale = 0.25;
      boss.applyStatModifier(StatModifier(type: 'attack_up', duration: 2));
      boss.applyStatModifier(StatModifier(type: 'defense_up', duration: 2));
      boss.applyStatModifier(StatModifier(type: 'speed_up', duration: 2));
      messages.add('${boss.name} gained a radiant boon.');
    }

    final healAmount = max(1, (boss.maxHp * healScale).round());
    boss.heal(healAmount);
    final recovered = boss.currentHp - before;
    messages.add('${boss.name} restored $recovered HP!');

    return BattleResult(
      damage: 0,
      isCritical: false,
      typeMultiplier: 1.0,
      messages: messages,
      targetDefeated: false,
    );
  }

  BattleResult _executeBossSpecialMove(
    BattleMove move,
    BattleCombatant target,
  ) {
    final moveName = move.name.toLowerCase();
    final messages = <String>['${boss.name} used ${move.name}!'];

    switch (moveName) {
      case 'sink':
        _mudSinkPendingStrike = true;
        boss.applyStatusEffect(
          StatusEffect(type: 'submerged', damagePerTurn: 0, duration: 2),
        );
        messages.add('${boss.name} sank into the depths!');
        messages.add('An ambush strike is coming next turn.');
        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );
      case 'mirage':
        _dustMirageCharges = max(_dustMirageCharges, 1);
        boss.applyStatusEffect(
          StatusEffect(type: 'mirage', damagePerTurn: 0, duration: 2),
        );
        boss.applyStatModifier(StatModifier(type: 'speed_up', duration: 2));
        messages.add('${boss.name} split into illusory copies.');
        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );
      default:
        return BattleEngine.executeAction(
          BattleAction(actor: boss, move: move, target: target),
        );
    }
  }

  Future<void> _executeBossAoeAttack(
    BattleMove move, {
    double damageMultiplier = 1.0,
  }) async {
    final aliveTargets = playerTeam
        .asMap()
        .entries
        .where((entry) => entry.value.canBeTargeted)
        .toList();

    if (aliveTargets.isEmpty) return;

    var maxDamage = 0;
    var totalDamage = 0;
    final defeatedIndexes = <int>[];

    for (final entry in aliveTargets) {
      final targetIndex = entry.key;
      final target = entry.value;
      final sprite = _spriteForTeamIndex(targetIndex);

      var result = BattleEngine.executeAction(
        BattleAction(actor: boss, move: move, target: target),
      );
      result = _applyBossMoveRiders(
        move: move,
        target: target,
        baseResult: result,
        damageMultiplier: damageMultiplier,
      );

      maxDamage = max(maxDamage, result.damage);
      totalDamage += result.damage;

      if (result.damage > 0) {
        sprite?.showDamage(result.damage, result.typeMultiplier);
        sprite?.playHitFlash();
      }

      if (target.isDead) {
        defeatedIndexes.add(targetIndex);
      }

      onGameEvent(BossAttackExecutedEvent(result, targetIndex));
      await Future.delayed(Duration(milliseconds: 90));
    }

    if (move.name.toLowerCase() == 'void-pulse' && totalDamage > 0) {
      final heal = max(1, (totalDamage * 0.35).round());
      boss.heal(heal);
      onGameEvent(
        StatusEffectEvent([
          '${boss.name} drained $heal HP from the entire party!',
        ], isBossSource: true),
      );
    }

    if (maxDamage > 0) {
      shakeCamera(intensity: maxDamage / 5.0);
    }

    await Future.delayed(Duration(milliseconds: 200));
    for (final sprite in playerSprites) {
      sprite.updateStatusIcons();
    }

    for (final targetIndex in defeatedIndexes) {
      _spriteForTeamIndex(targetIndex)?.playDeathAnimation();
    }

    if (defeatedIndexes.isNotEmpty) {
      await Future.delayed(Duration(milliseconds: 750));
    }

    if (playerTeam.every((c) => c.isDead)) {
      await Future.delayed(Duration(seconds: 1));
      onGameEvent(DefeatEvent());
    }
  }

  BattleResult _applyBossMoveRiders({
    required BattleMove move,
    required BattleCombatant target,
    required BattleResult baseResult,
    double damageMultiplier = 1.0,
  }) {
    var damage = baseResult.damage;
    final messages = List<String>.from(baseResult.messages);
    final moveName = move.name.toLowerCase();

    if (damage > 0 && damageMultiplier > 1.0) {
      final extra = max(1, (damage * (damageMultiplier - 1)).round());
      target.takeDamage(extra);
      damage += extra;
      messages.add('${boss.name} released stored charge for +$extra damage!');
    }

    if (damage > 0 &&
        _bossElementLower == 'fire' &&
        target.statusEffects.containsKey('burn')) {
      final extra = damage;
      target.takeDamage(extra);
      damage += extra;
      messages.add('Inferno execution! Burned target took double damage.');
    }

    if (damage > 0 &&
        _bossElementLower == 'poison' &&
        target.statusEffects.containsKey('poison')) {
      final extra = max(1, (damage * 0.5).round());
      target.takeDamage(extra);
      damage += extra;
      messages.add('Venom surge punished the poisoned target.');
    }

    if (damage > 0 &&
        _bossElementLower == 'ice' &&
        target.statusEffects.containsKey('freeze')) {
      final extra = max(1, (damage * 0.5).round());
      target.takeDamage(extra);
      damage += extra;
      messages.add('Shatter bonus! Frozen target took extra damage.');
    }

    if (damage > 0 && _bossElementLower == 'blood') {
      final missingHpRatio = max(0.0, 1.0 - boss.hpPercent);
      final bonusRatio = 0.15 + (missingHpRatio * 0.5);
      final extra = max(1, (damage * bonusRatio).round());
      target.takeDamage(extra);
      damage += extra;
      messages.add('Blood frenzy amplified the strike.');
    }

    switch (moveName) {
      case 'fireball':
      case 'eruption':
        if (_rng.nextDouble() < (moveName == 'fireball' ? 0.65 : 0.45)) {
          target.applyStatusEffect(
            StatusEffect(
              type: 'burn',
              damagePerTurn: max(1, (target.maxHp * 0.06).round()),
              duration: 3,
            ),
          );
          messages.add('${target.name} was burned!');
        }
        break;
      case 'aqua-jet':
        if (damage > 0 && target.statModifiers.containsKey('speed_down')) {
          final extra = max(1, (damage * 0.25).round());
          target.takeDamage(extra);
          damage += extra;
          messages.add('Aqua-jet exploited the speed debuff.');
        }
        break;
      case 'tidal wave':
      case 'tornado':
      case 'overgrow':
        if (_rng.nextDouble() < 0.4) {
          target.applyStatModifier(
            StatModifier(type: 'speed_down', duration: 2),
          );
          messages.add('${target.name} was slowed.');
        }
        break;
      case 'earthquake':
      case 'rock-throw':
        if (_rng.nextDouble() < 0.35) {
          target.applyStatModifier(
            StatModifier(type: 'defense_down', duration: 2),
          );
          messages.add('${target.name} had defense reduced.');
        }
        break;
      case 'icicle-spear':
      case 'blizzard':
        final freezeChance = moveName == 'icicle-spear' ? 0.35 : 0.15;
        if (_rng.nextDouble() < freezeChance) {
          target.applyStatusEffect(
            StatusEffect(type: 'freeze', damagePerTurn: 0, duration: 2),
          );
          messages.add('${target.name} was frozen solid!');
        }
        break;
      case 'zap-cannon':
      case 'thunderstorm':
        if (_rng.nextDouble() < 0.45) {
          target.applyStatModifier(
            StatModifier(type: 'speed_down', duration: 1),
          );
          messages.add('${target.name} was jolted by lightning.');
        }
        break;
      case 'toxin-spit':
      case 'plague-mist':
        if (_rng.nextDouble() < (moveName == 'toxin-spit' ? 0.75 : 0.60)) {
          target.applyStatusEffect(
            StatusEffect(
              type: 'poison',
              damagePerTurn: max(1, (target.maxHp * 0.08).round()),
              duration: 3,
            ),
          );
          messages.add('${target.name} was poisoned!');
        }
        break;
      case 'scald':
      case 'geyser-field':
        if (_rng.nextDouble() < 0.5) {
          target.applyStatusEffect(
            StatusEffect(
              type: 'burn',
              damagePerTurn: max(1, (target.maxHp * 0.05).round()),
              duration: 2,
            ),
          );
          messages.add('${target.name} was scalded.');
        }
        break;
      case 'lava-plume':
      case 'volcano':
      case 'sink ambush':
      case 'mud-bomb':
        if (_rng.nextDouble() < 0.55) {
          target.applyStatModifier(
            StatModifier(type: 'defense_down', duration: 2),
          );
          target.applyStatModifier(
            StatModifier(type: 'speed_down', duration: 2),
          );
          messages.add('${target.name} was bogged down by molten sludge.');
        }
        break;
      case 'sand-vortex':
      case 'sandstorm':
        if (_rng.nextDouble() < 0.6) {
          target.applyStatModifier(
            StatModifier(type: 'attack_down', duration: 2),
          );
          messages.add('${target.name} was blinded by sand!');
        }
        break;
      case 'gem-shard':
      case 'crystal-nova':
        if ((boss.shieldHp ?? 0) > 0 && damage > 0) {
          final extra = max(1, (damage * 0.25).round());
          target.takeDamage(extra);
          damage += extra;
          messages.add('Refracted crystals intensified the impact.');
        }
        break;
      case 'ecto-ball':
      case 'phantom-wail':
        if (_rng.nextDouble() < 0.45) {
          target.applyStatusEffect(
            StatusEffect(
              type: 'curse',
              damagePerTurn: max(1, (target.maxHp * 0.06).round()),
              duration: 2,
            ),
          );
          messages.add('${target.name} was haunted.');
        }
        break;
      case 'night-slash':
        if (_rng.nextDouble() < 0.35 && damage > 0) {
          final extra = max(1, (damage * 0.4).round());
          target.takeDamage(extra);
          damage += extra;
          messages.add('Night-slash landed a devastating critical line!');
        }
        break;
      case 'holy-smite':
        final vulnerable = target.types.any(
          (t) => t == 'Dark' || t == 'Spirit' || t == 'Poison',
        );
        if (vulnerable && damage > 0) {
          final extra = max(1, (damage * 0.4).round());
          target.takeDamage(extra);
          damage += extra;
          messages.add('Holy-smite punished darkness-aligned types.');
        }
        break;
      case 'life-drain':
        if (damage > 0) {
          final heal = max(1, (damage * 0.35).round());
          boss.heal(heal);
          messages.add('${boss.name} drained $heal HP.');
        }
        break;
      case 'blood-boil':
        if (_rng.nextDouble() < 0.6) {
          target.applyStatusEffect(
            StatusEffect(
              type: 'bleed',
              damagePerTurn: max(1, (target.maxHp * 0.06).round()),
              duration: 3,
            ),
          );
          messages.add('${target.name} started bleeding.');
        }
        break;
      default:
        break;
    }

    return BattleResult(
      damage: damage,
      isCritical: baseResult.isCritical,
      typeMultiplier: baseResult.typeMultiplier,
      messages: messages,
      targetDefeated: target.isDead,
    );
  }

  BattleResult? _resolveBossDefensiveReaction(
    BattleCombatant attacker,
    BattleMove move,
  ) {
    if (boss.statusEffects.containsKey('submerged')) {
      return BattleResult(
        damage: 0,
        isCritical: false,
        typeMultiplier: 1.0,
        messages: [
          '${attacker.name} used ${move.name}!',
          'But ${boss.name} is submerged and cannot be hit.',
        ],
        targetDefeated: false,
      );
    }

    if (_dustMirageCharges > 0) {
      _dustMirageCharges--;
      if (_dustMirageCharges <= 0) {
        boss.statusEffects.remove('mirage');
      }
      return BattleResult(
        damage: 0,
        isCritical: false,
        typeMultiplier: 1.0,
        messages: [
          '${attacker.name} used ${move.name}!',
          '${boss.name}\'s mirage absorbed the attack.',
        ],
        targetDefeated: false,
      );
    }

    if (_bossElementLower == 'air' &&
        boss.statModifiers.containsKey('speed_up') &&
        _rng.nextDouble() < 0.25) {
      return BattleResult(
        damage: 0,
        isCritical: false,
        typeMultiplier: 1.0,
        messages: [
          '${attacker.name} used ${move.name}!',
          '${boss.name} evaded with wind current shift.',
        ],
        targetDefeated: false,
      );
    }

    return null;
  }

  int _applyBossReactiveDefenses({
    required BattleCombatant attacker,
    required BattleMove move,
    required int dealtDamage,
    required List<String> messages,
  }) {
    var reflectedDamage = 0;

    if (dealtDamage > 0 && boss.statusEffects.containsKey('molten_armor')) {
      attacker.applyStatusEffect(
        StatusEffect(
          type: 'burn',
          damagePerTurn: max(1, (attacker.maxHp * 0.05).round()),
          duration: 3,
        ),
      );
      messages.add('Molten armor burned ${attacker.name}.');
    }

    if (dealtDamage > 0 &&
        boss.id == 'boss_013' &&
        (boss.shieldHp ?? 0) > 0 &&
        move.type == MoveType.elemental) {
      reflectedDamage = max(1, (dealtDamage * 0.35).round());
      attacker.takeDamage(reflectedDamage);
      messages.add('Crystal refraction reflected $reflectedDamage damage.');
    }

    if (boss.id == 'boss_016' &&
        !_lightAegisTriggered &&
        boss.hpPercent <= 0.5) {
      _lightAegisTriggered = true;
      boss.shieldHp =
          (boss.shieldHp ?? 0) + max(1, (boss.maxHp * 0.25).round());
      boss.applyStatModifier(StatModifier(type: 'defense_up', duration: 3));
      messages.add('Radiant Aegis awakened around ${boss.name}!');
    }

    return reflectedDamage;
  }

  void _attemptDarkBanish(List<String> messages) {
    if (_darkBanishCooldownTurns > 0) {
      messages.add(
        'The void has not stabilized enough for another banish yet.',
      );
      return;
    }

    final candidates = playerTeam.where((c) => c.canBeTargeted).toList();
    if (candidates.length <= 1) {
      messages.add(
        'The void searched for prey but found no safe banish target.',
      );
      return;
    }

    candidates.sort((a, b) {
      final dmgCompare = b.totalDamageDealt.compareTo(a.totalDamageDealt);
      if (dmgCompare != 0) return dmgCompare;
      return b.currentHp.compareTo(a.currentHp);
    });

    final topDamage = candidates.first.totalDamageDealt;
    final topThreats = candidates
        .where((c) => c.totalDamageDealt == topDamage)
        .toList();
    final selected = topThreats[_rng.nextInt(topThreats.length)];
    selected.applyStatusEffect(
      StatusEffect(type: 'banished', damagePerTurn: 0, duration: 6),
    );
    selected.actionCooldown = max(selected.actionCooldown, 1);
    _darkBanishCooldownTurns = 4;
    messages.add(
      '${selected.name} was banished into the void for 5 turns (highest damage threat).',
    );
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
      final wasBanished = combatant.isBanished;
      final wasSubmerged = combatant.statusEffects.containsKey('submerged');
      final messages = List<String>.from(
        BattleEngine.processEndOfTurnEffects(combatant),
      );
      if (wasBanished && !combatant.isBanished && combatant.isAlive) {
        messages.add('${combatant.name} returned from the void!');
      }
      if (wasSubmerged && !combatant.statusEffects.containsKey('submerged')) {
        messages.add('${combatant.name} resurfaced!');
      }

      if (messages.isNotEmpty) {
        onGameEvent(
          StatusEffectEvent(messages, isBossSource: identical(combatant, boss)),
        );
        await Future.delayed(Duration(milliseconds: 800));
      }
    }

    // Tick cooldowns for all player creatures
    for (final creature in playerTeam) {
      creature.tickActionCooldown();
      creature.tickSpecialCooldown();
    }

    // Safety: if all non-banished allies are on cooldown, reset their action cooldowns.
    if (!playerTeam.any((c) => c.canAct) &&
        playerTeam.any((c) => c.isAlive && !c.isBanished)) {
      for (final c in playerTeam) {
        if (c.isAlive && !c.isBanished) c.actionCooldown = 0;
      }
    }

    // Auto-select next available creature
    _autoSelectNextCreature();

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

  /// Auto-select the next available creature (one not on cooldown and alive).
  void _autoSelectNextCreature() {
    // If current creature can still act, keep selection
    if (currentPlayerIndex < playerTeam.length &&
        playerTeam[currentPlayerIndex].canAct) {
      return;
    }

    // Find first available creature — bypass state guard since this is internal
    for (int i = 0; i < playerTeam.length; i++) {
      if (playerTeam[i].canAct) {
        // Direct selection (don't use selectCreature which checks BattleState)
        _spriteForTeamIndex(currentPlayerIndex)?.setSelected(false);
        currentPlayerIndex = i;
        _spriteForTeamIndex(i)?.setSelected(true);
        onGameEvent(CreatureSelectedEvent(i));
        return;
      }
    }

    // Fallback: keep selection on first alive creature so UI never deadlocks
    // with a null/invalid selection state.
    for (int i = 0; i < playerTeam.length; i++) {
      if (playerTeam[i].isAlive) {
        _spriteForTeamIndex(currentPlayerIndex)?.setSelected(false);
        currentPlayerIndex = i;
        _spriteForTeamIndex(i)?.setSelected(true);
        onGameEvent(CreatureSelectedEvent(i));
        return;
      }
    }
  }

  /// Recovers from stale selection/cooldown states that can otherwise leave
  /// the player without a valid acting creature.
  void _recoverPlayerTurnSelection() {
    if (playerTeam.any((c) => c.canAct)) {
      _autoSelectNextCreature();
      return;
    }

    for (final c in playerTeam) {
      if (c.isAlive) c.actionCooldown = 0;
    }
    _autoSelectNextCreature();
  }
}

enum BattleState { playerTurn, bossTurn, animating, gameOver }

/// Background component
class BattleBackground extends PositionComponent
    with HasGameReference<BattleGame> {
  @override
  Future<void> onLoad() async {
    size = game.size;

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
class BossSprite extends PositionComponent with HasGameReference<BattleGame> {
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
          ..color = _auraColor.withValues(alpha: 0.0)
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
        bossVisual!.paint.color = _auraColor.withValues(alpha: 0.35);
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
          paint: Paint()..color = Colors.white.withValues(alpha: 0.65),
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
      game.add(particle);
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
        bgColor = Colors.orange.withValues(alpha: 0.8);
        textColor = Colors.white;
        text = 'BURN';
        break;
      case 'poison':
        bgColor = Colors.purple.withValues(alpha: 0.8);
        textColor = Colors.white;
        text = 'PSN';
        break;
      case 'freeze':
        bgColor = Colors.cyan.withValues(alpha: 0.8);
        textColor = Colors.black;
        text = 'FRZ';
        break;
      case 'curse':
        bgColor = Colors.purple.shade900.withValues(alpha: 0.8);
        textColor = Colors.white;
        text = 'CURSE';
        break;
      case 'regen':
        bgColor = Colors.green.withValues(alpha: 0.8);
        textColor = Colors.white;
        text = 'REGEN';
        break;
      case 'taunt':
        bgColor = Colors.red.withValues(alpha: 0.8);
        textColor = Colors.white;
        text = 'TAUNT';
        break;
      case 'bleed':
        bgColor = Colors.red.shade900.withValues(alpha: 0.85);
        textColor = Colors.white;
        text = 'BLEED';
        break;
      case 'molten_armor':
        bgColor = Colors.deepOrange.shade700.withValues(alpha: 0.85);
        textColor = Colors.white;
        text = 'MOLT';
        break;
      case 'mirage':
        bgColor = Colors.orange.shade300.withValues(alpha: 0.85);
        textColor = Colors.black;
        text = 'MIR';
        break;
      case 'submerged':
        bgColor = Colors.blue.shade800.withValues(alpha: 0.85);
        textColor = Colors.white;
        text = 'SINK';
        break;
      case 'banished':
        bgColor = Colors.deepPurple.shade700.withValues(alpha: 0.85);
        textColor = Colors.white;
        text = 'VOID';
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.8);
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
        bgColor = Colors.red.withValues(alpha: 0.8);
        textColor = Colors.white;
        text = 'ATK ↑';
        break;
      case 'attack_down':
        bgColor = Colors.red.shade300.withValues(alpha: 0.8);
        textColor = Colors.white;
        text = 'ATK ↓';
        break;
      case 'defense_up':
        bgColor = Colors.blue.withValues(alpha: 0.8);
        textColor = Colors.white;
        text = 'DEF ↑';
        break;
      case 'defense_down':
        bgColor = Colors.blue.shade300.withValues(alpha: 0.8);
        textColor = Colors.white;
        text = 'DEF ↓';
        break;
      case 'speed_up':
        bgColor = Colors.yellow.withValues(alpha: 0.8);
        textColor = Colors.black;
        text = 'SPD ↑';
        break;
      case 'speed_down':
        bgColor = Colors.yellow.shade700.withValues(alpha: 0.8);
        textColor = Colors.white;
        text = 'SPD ↓';
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.8);
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
    game.post(() => game.add(fx));

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
      paint: Paint()..color = flashColor.withValues(alpha: 0.50),
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
      game.post(() {
        game.add(critLabel);
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

    game.post(() {
      game.add(damageText);

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

class TurnStateChangedEvent extends BattleGameEvent {
  final BattleState state;
  TurnStateChangedEvent(this.state);
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
