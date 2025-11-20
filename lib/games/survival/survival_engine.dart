// lib/services/gameengines/survival_engine.dart
import 'dart:math';

import 'package:alchemons/games/survival/survival_enemies.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';

class SurvivalWave {
  final int waveNumber;
  final List<BattleCombatant> enemies;

  const SurvivalWave({required this.waveNumber, required this.enemies});

  bool get allEnemiesDefeated => enemies.every((e) => e.isDead);
}

class SurvivalRunState {
  final List<BattleCombatant> team;
  int waveNumber;
  int score;
  int totalKills;
  Duration timeElapsed;

  SurvivalRunState({
    required this.team,
    this.waveNumber = 0,
    this.score = 0,
    this.totalKills = 0,
    this.timeElapsed = Duration.zero,
  });

  bool get isTeamWiped => team.every((c) => c.isDead);

  void recoverBetweenWaves({double healPercent = 0.15}) {
    for (final c in team) {
      if (!c.isDead) {
        final healAmount = (c.maxHp * healPercent).round();
        c.heal(healAmount);
      }
    }
  }
}

/// One fully-resolved action: actor + move + target + result.
class BattleEvent {
  final BattleAction action;
  final BattleResult result;

  BattleEvent({required this.action, required this.result});
}

class SurvivalEngine {
  final Random _rng = Random();

  final SurvivalRunState state;

  SurvivalEngine({required List<BattleCombatant> team})
    : state = SurvivalRunState(team: team);

  bool get isGameOver => state.isTeamWiped;

  /// How many enemies in this wave?
  int _enemyCountForWave(int wave) {
    final base = 2 + wave; // start at 3 enemies, scale up
    return base.clamp(3, 12);
  }

  /// Generate a new wave with survival-specific enemies.
  SurvivalWave startNextWave() {
    state.waveNumber += 1;
    final wave = state.waveNumber;

    final enemies = <BattleCombatant>[];

    final count = _enemyCountForWave(wave);

    for (var i = 0; i < count; i++) {
      final template = SurvivalEnemyCatalog.pickTemplateForWave(wave);
      final enemy = SurvivalEnemyCatalog.buildEnemyForWave(
        template: template,
        wave: wave,
      );

      enemies.add(enemy);
    }

    return SurvivalWave(waveNumber: wave, enemies: enemies);
  }

  void completeWave(SurvivalWave wave) {
    final kills = wave.enemies.where((e) => e.isDead).length;
    state.totalKills += kills;

    final waveBase = wave.waveNumber * 100;
    final killBonus = kills * 5;

    state.score += waveBase + killBonus;
  }

  void addTimeElapsed(Duration delta) {
    state.timeElapsed += delta;
  }

  BattleCombatant? _pickRandomTarget(List<BattleCombatant> candidates) {
    final alive = candidates.where((c) => c.isAlive).toList();
    if (alive.isEmpty) return null;
    return alive[_rng.nextInt(alive.length)];
  }

  /// Runs a "round" where each living combatant acts once (at most).
  /// Returns BattleEvents that you can use in Flame to spawn animations.
  List<BattleEvent> runOneRound(SurvivalWave wave) {
    final events = <BattleEvent>[];

    final field = [
      ...state.team.where((c) => c.isAlive),
      ...wave.enemies.where((c) => c.isAlive),
    ];

    final turnOrder = BattleEngine.determineTurnOrder(field);

    for (final actor in turnOrder) {
      if (!actor.isAlive) continue;

      final isPlayerSide = state.team.contains(actor);
      final targets = isPlayerSide ? wave.enemies : state.team;
      final target = _pickRandomTarget(targets);
      if (target == null) continue;

      final move = (actor.level >= 5)
          ? BattleMove.getSpecialMove(actor.family)
          : BattleMove.getBasicMove(actor.family);

      final action = BattleAction(actor: actor, move: move, target: target);
      final result = BattleEngine.executeAction(action);

      events.add(BattleEvent(action: action, result: result));

      // End-of-turn effects for actor
      final endMessages = BattleEngine.processEndOfTurnEffects(actor);
      if (endMessages.isNotEmpty) {
        events.add(
          BattleEvent(
            action: action,
            result: BattleResult(
              damage: 0,
              isCritical: false,
              typeMultiplier: 1.0,
              messages: endMessages,
              targetDefeated: false,
            ),
          ),
        );
      }

      if (wave.allEnemiesDefeated || state.isTeamWiped) {
        break;
      }
    }

    return events;
  }
}
