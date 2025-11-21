import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/survival/survival_enemies.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';

/// Formation positions for strategic gameplay
enum FormationPosition {
  frontLeft(0, true),
  frontRight(1, true),
  backLeft(2, false),
  backRight(3, false);

  final int i;
  final bool isFrontRow;

  const FormationPosition(this.i, this.isFrontRow);

  bool get isBackRow => !isFrontRow;
}

/// Party member with formation position
class PartyMember {
  final BattleCombatant combatant;
  final FormationPosition position;

  PartyMember({required this.combatant, required this.position});
}

class SurvivalWave {
  final int waveNumber;
  final List<BattleCombatant> enemies;

  const SurvivalWave({required this.waveNumber, required this.enemies});

  bool get allEnemiesDefeated => enemies.every((e) => e.isDead);
}

class SurvivalRunState {
  final List<PartyMember> party;
  int waveNumber;
  int score;
  int totalKills;
  Duration timeElapsed;

  SurvivalRunState({
    required this.party,
    this.waveNumber = 0,
    this.score = 0,
    this.totalKills = 0,
    this.timeElapsed = Duration.zero,
  });

  List<BattleCombatant> get team => party.map((m) => m.combatant).toList();
  bool get isTeamWiped => team.every((c) => c.isDead);

  List<BattleCombatant> get frontRow => party
      .where((m) => m.position.isFrontRow)
      .map((m) => m.combatant)
      .toList();

  List<BattleCombatant> get backRow =>
      party.where((m) => m.position.isBackRow).map((m) => m.combatant).toList();

  void recoverBetweenWaves({double healPercent = 0.20}) {
    for (final member in party) {
      if (!member.combatant.isDead) {
        final healAmount = (member.combatant.maxHp * healPercent).round();
        member.combatant.heal(healAmount);
      }
    }
  }
}

class BattleEvent {
  final BattleAction action;
  final BattleResult result;

  BattleEvent({required this.action, required this.result});
}

/// Enhanced survival engine with formation-based targeting
class SurvivalEngine {
  final Random _rng = Random();
  final SurvivalRunState state;

  SurvivalEngine({required List<PartyMember> party})
    : state = SurvivalRunState(
        party: party
            .map(
              (m) => PartyMember(
                combatant: m.combatant.scaledCopy(
                  newId: m.combatant.id, // keep same id for sprites
                  hpScale: 2.0, // more HP for survival
                  atkScale: 0.9, // slightly lower damage to slow attrition
                  defScale: 1.5, // better defenses
                  spdScale: 1.0, // same tempo
                ),
                position: m.position,
              ),
            )
            .toList(),
      );

  bool get isGameOver => state.isTeamWiped;

  /// Generate wave with tiered enemy distribution
  SurvivalWave startNextWave() {
    state.waveNumber += 1;
    final wave = state.waveNumber;

    final enemies = <BattleCombatant>[];
    final distribution = _calculateEnemyDistribution(wave);

    print('Wave $wave enemy distribution: $distribution');

    // Spawn enemies based on tier distribution
    for (var tier = 1; tier <= 5; tier++) {
      final count = distribution[tier] ?? 0;
      for (var i = 0; i < count; i++) {
        final template = SurvivalEnemyCatalog.getRandomTemplateForTier(tier);
        final enemy = SurvivalEnemyCatalog.buildEnemy(
          template: template,
          tier: tier,
          wave: wave,
        );
        enemies.add(enemy);
      }
    }

    if (enemies.isNotEmpty) {
      final e = enemies.first;
      print(
        'ENEMY: ${e.name} lvl=${e.level} hp=${e.maxHp} '
        'atk=${e.physAtk}/${e.elemAtk} def=${e.physDef}/${e.elemDef}',
      );
    }

    // Shuffle for variety
    enemies.shuffle(_rng);

    return SurvivalWave(waveNumber: wave, enemies: enemies);
  }

  /// More realtime-feeling tick with formation-based targeting
  List<BattleEvent> runRealtimeTick(
    SurvivalWave wave, {
    int maxActionsPerTick = 2,
  }) {
    final events = <BattleEvent>[];

    final field = [
      ...state.team.where((c) => c.isAlive),
      ...wave.enemies.where((c) => c.isAlive),
    ];

    if (field.isEmpty) return events;

    // Shuffle so different actors get priority each tick
    field.shuffle(_rng);

    // Limit how many actually act this tick
    final actors = field.take(maxActionsPerTick);

    for (final actor in actors) {
      if (!actor.isAlive) continue;

      final isPlayerSide = state.team.contains(actor);

      BattleCombatant? target;
      if (isPlayerSide) {
        // Player attacks enemies randomly
        target = _pickRandomTarget(wave.enemies);
      } else {
        // Enemies use formation-based targeting
        target = _pickFormationBasedTarget();
      }

      if (target == null) continue;

      final move = (actor.level >= 5)
          ? BattleMove.getSpecialMove(actor.family)
          : BattleMove.getBasicMove(actor.family);

      final action = BattleAction(actor: actor, move: move, target: target);
      final result = BattleEngine.executeAction(action);

      events.add(BattleEvent(action: action, result: result));

      // Process end-of-turn effects
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

      if (wave.allEnemiesDefeated || state.isTeamWiped) break;
    }

    return events;
  }

  /// Formation-based targeting: Front row gets hit 75% of the time
  BattleCombatant? _pickFormationBasedTarget() {
    final frontAlive = state.frontRow.where((c) => c.isAlive).toList();
    final backAlive = state.backRow.where((c) => c.isAlive).toList();

    // If no front row, always hit back row
    if (frontAlive.isEmpty) {
      return backAlive.isEmpty
          ? null
          : backAlive[_rng.nextInt(backAlive.length)];
    }

    // If no back row, always hit front row
    if (backAlive.isEmpty) {
      return frontAlive[_rng.nextInt(frontAlive.length)];
    }

    // 75% chance to hit front row, 25% to hit back row
    final hitFront = _rng.nextDouble() < 0.75;
    final targetList = hitFront ? frontAlive : backAlive;
    return targetList[_rng.nextInt(targetList.length)];
  }

  /// Calculate how many of each tier to spawn
  Map<int, int> _calculateEnemyDistribution(int wave) {
    final totalEnemies = _getTotalEnemyCount(wave);

    // Weights tuned for long survival
    final tier1Weight = (1.0 - wave * 0.02).clamp(0.2, 1.0);
    final tier2Weight = (0.1 + wave * 0.02).clamp(0.2, 1.0);
    final tier3Weight = wave < 15 ? 0.0 : ((wave - 15) * 0.015).clamp(0.0, 0.6);
    final tier4Weight = wave < 25 ? 0.0 : ((wave - 25) * 0.01).clamp(0.0, 0.4);
    final tier5Weight = wave < 35 ? 0.0 : ((wave - 35) * 0.008).clamp(0.0, 0.3);

    final totalWeight =
        tier1Weight + tier2Weight + tier3Weight + tier4Weight + tier5Weight;

    double alloc(double w) => totalEnemies * (w / totalWeight);

    int tier1 = alloc(tier1Weight).round();
    int tier2 = alloc(tier2Weight).round();
    int tier3 = alloc(tier3Weight).round();
    int tier4 = alloc(tier4Weight).round();

    int used = tier1 + tier2 + tier3 + tier4;
    int tier5 = (totalEnemies - used).clamp(0, totalEnemies);

    return {1: tier1, 2: tier2, 3: tier3, 4: tier4, 5: tier5};
  }

  int _getTotalEnemyCount(int wave) {
    if (wave <= 3) return 8 + _rng.nextInt(5); // 8-12 (was 4-7)
    if (wave <= 5) return 10 + _rng.nextInt(5); // 10-14 (was 5-8)
    if (wave <= 10) return 12 + _rng.nextInt(6); // 12-17 (was 6-10)
    if (wave <= 20) return 15 + _rng.nextInt(6); // 15-20 (was 8-12)
    if (wave <= 30) return 18 + _rng.nextInt(7); // 18-24 (was 10-14)
    if (wave <= 40) return 22 + _rng.nextInt(8); // 22-29 (was 12-16)
    return 26 + _rng.nextInt(9); // 26-34 (was 14-18)
  }

  void completeWave(SurvivalWave wave) {
    final kills = wave.enemies.where((e) => e.isDead).length;
    state.totalKills += kills;

    // Score calculation
    final waveBase = wave.waveNumber * 150;
    final killBonus = kills * 10;

    // Tier bonuses
    var tierBonus = 0;
    for (final enemy in wave.enemies) {
      if (enemy.isDead) {
        final tier = _getEnemyTierFromLevel(enemy.level);
        tierBonus += tier * 20;
      }
    }

    state.score += waveBase + killBonus + tierBonus;
  }

  int _getEnemyTierFromLevel(int level) {
    if (level <= 3) return 1;
    if (level <= 7) return 2;
    if (level <= 12) return 3;
    if (level <= 18) return 4;
    return 5;
  }

  void addTimeElapsed(Duration delta) {
    state.timeElapsed += delta;
  }

  BattleCombatant? _pickRandomTarget(List<BattleCombatant> candidates) {
    final alive = candidates.where((c) => c.isAlive).toList();
    if (alive.isEmpty) return null;
    return alive[_rng.nextInt(alive.length)];
  }

  /// Run one combat round with formation-based targeting
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

      BattleCombatant? target;
      if (isPlayerSide) {
        target = _pickRandomTarget(wave.enemies);
      } else {
        target = _pickFormationBasedTarget();
      }

      if (target == null) continue;

      final move = (actor.level >= 5)
          ? BattleMove.getSpecialMove(actor.family)
          : BattleMove.getBasicMove(actor.family);

      final action = BattleAction(actor: actor, move: move, target: target);
      final result = BattleEngine.executeAction(action);

      events.add(BattleEvent(action: action, result: result));

      // End-of-turn effects
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

      if (wave.allEnemiesDefeated || state.isTeamWiped) break;
    }

    return events;
  }
}

class DebugTeams {
  /// "God" team: 4 creatures with formation positions
  static List<PartyMember> makeGodTeam() {
    return [
      PartyMember(
        combatant: _makeCreature(
          id: 'debug_tank',
          name: 'Obsidian Horn',
          types: ['Earth'],
          family: 'Horn',
          level: 10,
          speed: 3.2,
          intelligence: 2.5,
          strength: 5.0,
          beauty: 2.0,
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'debug_dps_fire',
          name: 'Solar Let',
          types: ['Fire'],
          family: 'Let',
          level: 10,
          speed: 3.8,
          intelligence: 3.0,
          strength: 5.0,
          beauty: 3.0,
        ),
        position: FormationPosition.frontRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'debug_dps_lightning',
          name: 'Storm Wing',
          types: ['Lightning'],
          family: 'Wing',
          level: 10,
          speed: 5.0,
          intelligence: 3.5,
          strength: 4.2,
          beauty: 2.5,
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'debug_support',
          name: 'Aurora Mystic',
          types: ['Light'],
          family: 'Mystic',
          level: 10,
          speed: 3.5,
          intelligence: 5.0,
          strength: 3.0,
          beauty: 4.5,
        ),
        position: FormationPosition.backRight,
      ),
    ];
  }

  static BattleCombatant _makeCreature({
    required String id,
    required String name,
    required List<String> types,
    required String family,
    required int level,
    required double speed,
    required double intelligence,
    required double strength,
    required double beauty,
  }) {
    return BattleCombatant(
      id: id,
      name: name,
      types: types,
      family: family,
      statSpeed: speed,
      statIntelligence: intelligence,
      statStrength: strength,
      statBeauty: beauty,
      level: level,
    );
  }
}

/// Helper class to convert formation data to combat-ready party
class SurvivalFormationHelper {
  /// Convert formation slots to PartyMember list for the engine
  static Future<List<PartyMember>> buildPartyFromFormation({
    required Map<int, String> formationSlots,
    required AlchemonsDatabase db,
    required CreatureCatalog catalog,
  }) async {
    final party = <PartyMember>[];
    final instances = await db.creatureDao.getAllInstances();

    for (var positionIndex = 0; positionIndex < 4; positionIndex++) {
      final instanceId = formationSlots[positionIndex];
      if (instanceId == null) continue;

      final instance = instances
          .where((inst) => inst.instanceId == instanceId)
          .firstOrNull;

      if (instance == null) continue;

      final species = catalog.getCreatureById(instance.baseId);
      if (species == null) continue;

      // Convert creature instance to battle combatant
      final combatant = BattleCombatant(
        id: instance.instanceId,
        name: instance.nickname ?? species.name,
        types: species.types,
        family: species.mutationFamily!,
        statSpeed: instance.statSpeed,
        statIntelligence: instance.statIntelligence,
        statStrength: instance.statStrength,
        statBeauty: instance.statBeauty,
        level: instance.level,
        speciesRef: species,
        instanceRef: instance,
      );

      // Map position index to FormationPosition
      final position = FormationPosition.values[positionIndex];

      party.add(PartyMember(combatant: combatant, position: position));
    }

    return party;
  }

  /// Validate that formation is complete and valid
  static bool isFormationValid(Map<int, String> formationSlots) {
    if (formationSlots.length != 4) return false;

    // Check all positions are filled
    for (var i = 0; i < 4; i++) {
      if (!formationSlots.containsKey(i)) return false;
    }

    // Check no duplicate instances
    final uniqueInstances = formationSlots.values.toSet();
    return uniqueInstances.length == 4;
  }

  /// Get formation slot labels for UI display
  static String getPositionLabel(FormationPosition position) {
    switch (position) {
      case FormationPosition.frontLeft:
        return 'Front Left';
      case FormationPosition.frontRight:
        return 'Front Right';
      case FormationPosition.backLeft:
        return 'Back Left';
      case FormationPosition.backRight:
        return 'Back Right';
    }
  }

  /// Get abbreviated position label
  static String getPositionShortLabel(FormationPosition position) {
    switch (position) {
      case FormationPosition.frontLeft:
        return 'FL';
      case FormationPosition.frontRight:
        return 'FR';
      case FormationPosition.backLeft:
        return 'BL';
      case FormationPosition.backRight:
        return 'BR';
    }
  }
}
