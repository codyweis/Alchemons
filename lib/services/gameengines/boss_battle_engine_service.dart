// lib/services/battle_engine.dart
import 'dart:math';
import 'package:alchemons/models/boss/boss_model.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';

/// Represents a combatant (player creature or boss) in battle
class BattleCombatant {
  final String id;
  final String name;
  final List<String> types; // Element types
  final String family; // Let, Pip, Mane, etc.
  final List<BossMove> bossMoveset;

  /// Optional references used for rendering
  final CreatureInstance? instanceRef;
  final Creature? speciesRef;

  // Base stats
  final double statSpeed;
  final double statIntelligence;
  final double statStrength;
  final double statBeauty;
  final int level;

  // Combat stats (calculated)
  late int maxHp;
  late int physAtk;
  late int elemAtk;
  late int physDef;
  late int elemDef;
  late int speed;

  // Battle state
  late int currentHp;
  Map<String, StatusEffect> statusEffects = {};
  Map<String, StatModifier> statModifiers = {};
  bool isCharging = false;
  int specialCooldown = 0; // Turns until special can be used again
  int actionCooldown = 0; // Turns until this creature can act again
  String? tauntTargetId; // If set (on boss), must target this creature
  int? shieldHp;
  int totalDamageDealt = 0; // Runtime telemetry for tactical boss targeting

  /// Backward compat: true when special is on cooldown
  bool get needsRecharge => specialCooldown > 0;
  set needsRecharge(bool v) => specialCooldown = v ? 1 : 0;

  BattleCombatant({
    required this.id,
    required this.name,
    required this.types,
    required this.family,
    this.bossMoveset = const [],
    required this.statSpeed,
    required this.statIntelligence,
    required this.statStrength,
    required this.statBeauty,
    required this.level,
    this.instanceRef,
    this.speciesRef,
  }) {
    _calculateCombatStats();
    currentHp = maxHp;
  }

  // ── Visual helpers ───────────────────────────────────────

  /// Lazily compute the sprite sheet definition from the species, if available.
  SpriteSheetDef? get sheetDef {
    final species = speciesRef;
    if (species == null) return null;
    return sheetFromCreature(species);
  }

  /// Lazily compute the per-instance visuals (hue, scale, tint, etc.).
  /// Return type is dynamic to stay compatible with whatever your
  /// CreatureSpriteComponent expects from visualsFromInstance().
  dynamic get spriteVisuals {
    final species = speciesRef;
    final inst = instanceRef;
    if (species == null) return null;
    return visualsFromInstance(species, inst);
  }

  void _calculateCombatStats() {
    final sSpd = statSpeed * 10; // 0–50
    final sInt = statIntelligence * 10;
    final sStr = statStrength * 10;
    final sBea = statBeauty * 10;

    maxHp = (level * 10 + sStr * 0.5).round(); // STR strongly affects HP
    physAtk = (sStr * 0.4 + level * 2).round();
    elemAtk = (sInt * 0.4 + level * 2).round();
    physDef = ((sStr + sBea) * 0.2 + level).round();
    elemDef = (sBea * 0.4 + level * 2).round();
    speed = (sSpd * 0.4).round();
  }

  // --- factories ---

  factory BattleCombatant.fromInstance({
    required CreatureInstance instance,
    required Creature creature,
  }) {
    return BattleCombatant(
      id: instance.instanceId,
      name: instance.nickname ?? creature.name,
      types: creature.types,
      family: creature.mutationFamily!,
      bossMoveset: const [],
      statSpeed: instance.statSpeed,
      statIntelligence: instance.statIntelligence,
      statStrength: instance.statStrength,
      statBeauty: instance.statBeauty,
      level: instance.level,
      instanceRef: instance,
      speciesRef: creature,
    );
  }

  factory BattleCombatant.fromBoss(Boss boss, {Creature? mysticSpecies}) {
    // Bosses don’t use the same sprite pipeline, so instance/species refs are null.
    final bc = BattleCombatant(
      id: boss.id,
      name: mysticSpecies?.name ?? boss.name,
      types: mysticSpecies?.types ?? [boss.element],
      family: mysticSpecies?.mutationFamily ?? 'Mystic',
      bossMoveset: boss.moveset,
      statSpeed: boss.spd.toDouble(),
      statIntelligence: 50.0,
      statStrength: 50.0,
      statBeauty: 50.0,
      level: boss.recommendedLevel,
      instanceRef: null,
      speciesRef: mysticSpecies,
    );

    // Override calculated stats with boss-defined stats
    bc.maxHp = boss.hp;
    bc.currentHp = boss.hp;
    bc.physAtk = boss.atk;
    bc.elemAtk = boss.atk;
    bc.physDef = boss.def;
    bc.elemDef = boss.def;
    bc.speed = boss.spd;

    return bc;
  }

  bool get isAlive => currentHp > 0;
  bool get isDead => currentHp <= 0;
  double get hpPercent => currentHp / maxHp;

  int getEffectivePhysAtk() {
    var atk = physAtk;
    if (statModifiers.containsKey('attack_up')) {
      atk = (atk * 1.5).toInt();
    }
    if (statModifiers.containsKey('attack_down')) {
      atk = (atk * 0.75).toInt();
    }
    return atk;
  }

  int getEffectiveElemAtk() {
    var atk = elemAtk;
    if (statModifiers.containsKey('attack_up')) {
      atk = (atk * 1.5).toInt();
    }
    if (statModifiers.containsKey('attack_down')) {
      atk = (atk * 0.75).toInt();
    }
    return atk;
  }

  int getEffectivePhysDef() {
    var def = physDef;
    if (statModifiers.containsKey('defense_up')) {
      def = (def * 1.5).toInt();
    }
    if (statModifiers.containsKey('defense_down')) {
      def = (def * 0.75).toInt();
    }
    return def;
  }

  int getEffectiveElemDef() {
    var def = elemDef;
    if (statModifiers.containsKey('defense_up')) {
      def = (def * 1.5).toInt();
    }
    if (statModifiers.containsKey('defense_down')) {
      def = (def * 0.75).toInt();
    }
    return def;
  }

  int getEffectiveSpeed() {
    var spd = speed;
    if (statModifiers.containsKey('speed_up')) {
      spd = (spd * 1.5).toInt();
    }
    if (statModifiers.containsKey('speed_down')) {
      spd = (spd * 0.75).toInt();
    }
    return spd;
  }

  void takeDamage(int rawDamage) {
    var damage = rawDamage;

    // Shield absorbs first
    if (shieldHp != null && shieldHp! > 0) {
      if (shieldHp! >= damage) {
        shieldHp = shieldHp! - damage;
        damage = 0;
      } else {
        damage -= shieldHp!;
        shieldHp = 0;
      }
    }

    if (damage <= 0) return;
    currentHp = max(0, currentHp - damage);
  }

  void heal(int amount) {
    currentHp = min(maxHp, currentHp + amount);
  }

  void applyStatusEffect(StatusEffect effect) {
    statusEffects[effect.type] = effect;
  }

  void applyStatModifier(StatModifier modifier) {
    statModifiers[modifier.type] = modifier;
  }

  void tickStatusEffects() {
    final toRemove = <String>[];

    for (final entry in statusEffects.entries) {
      final effect = entry.value;
      effect.tickDuration();

      if (effect.isExpired) {
        toRemove.add(entry.key);
      }
    }

    for (final key in toRemove) {
      statusEffects.remove(key);
    }
  }

  void tickStatModifiers() {
    final toRemove = <String>[];

    for (final entry in statModifiers.entries) {
      final modifier = entry.value;
      modifier.tickDuration();

      if (modifier.isExpired) {
        toRemove.add(entry.key);
      }
    }

    for (final key in toRemove) {
      statModifiers.remove(key);
    }
  }

  /// Tick down action cooldown (called at start of each player turn phase).
  void tickActionCooldown() {
    if (actionCooldown > 0) actionCooldown--;
  }

  /// Tick down special cooldown (called at start of each player turn phase).
  void tickSpecialCooldown() {
    if (specialCooldown > 0) specialCooldown--;
  }

  /// Tick down taunt duration (called at end of each turn cycle).
  void tickTaunt() {
    if (tauntTargetId != null) {
      final taunt = statusEffects['taunt'];
      if (taunt == null || taunt.isExpired) {
        tauntTargetId = null;
      }
    }
  }

  bool get isBanished => statusEffects.containsKey('banished');
  bool get canBeTargeted => isAlive && !isBanished;

  /// Whether this creature can be selected to act this turn.
  bool get canAct => isAlive && !isBanished && actionCooldown <= 0;
}

class StatusEffect {
  final String type; // burn, poison, regen, etc.
  final int damagePerTurn; // or heal per turn if negative
  int duration;

  StatusEffect({
    required this.type,
    required this.damagePerTurn,
    required this.duration,
  });

  void tickDuration() => duration--;
  bool get isExpired => duration <= 0;
}

class StatModifier {
  final String type; // attack_up, defense_down, etc.
  int duration;

  StatModifier({required this.type, required this.duration});

  void tickDuration() => duration--;
  bool get isExpired => duration <= 0;
}

enum MoveType { physical, elemental }

class FamilyMoveStyle {
  final String family;
  final String survivalArchetype;
  final String battleSpecialName;
  final String summary;

  const FamilyMoveStyle({
    required this.family,
    required this.survivalArchetype,
    required this.battleSpecialName,
    required this.summary,
  });
}

class BattleMove {
  final String name;
  final MoveType type;
  final String scalingStat; // For display/tracking
  final bool isSpecial; // True if level 5+ ability
  final String? family; // Required family for special moves

  const BattleMove({
    required this.name,
    required this.type,
    required this.scalingStat,
    this.isSpecial = false,
    this.family,
  });

  static const Map<String, FamilyMoveStyle> _familyStyles = {
    'Let': FamilyMoveStyle(
      family: 'Let',
      survivalArchetype: 'Meteor',
      battleSpecialName: 'Meteor Strike',
      summary:
          'Heavy elemental burst that scorches a single target with lingering damage.',
    ),
    'Pip': FamilyMoveStyle(
      family: 'Pip',
      survivalArchetype: 'Frenzy',
      battleSpecialName: 'Frenzy',
      summary:
          'Relentless multi-hit assault with escalating critical strike chance.',
    ),
    'Mane': FamilyMoveStyle(
      family: 'Mane',
      survivalArchetype: 'Entangle',
      battleSpecialName: 'Entangle',
      summary:
          'Ensnares the enemy, weakening them while nourishing allies with regen.',
    ),
    'Mask': FamilyMoveStyle(
      family: 'Mask',
      survivalArchetype: 'Hex Field',
      battleSpecialName: 'Hex Field',
      summary:
          'Curses and debilitates the enemy; detonates existing curses for burst damage.',
    ),
    'Horn': FamilyMoveStyle(
      family: 'Horn',
      survivalArchetype: 'Fortress',
      battleSpecialName: 'Fortress',
      summary:
          'Raises protective shields for the team and taunts the enemy to draw fire.',
    ),
    'Wing': FamilyMoveStyle(
      family: 'Wing',
      survivalArchetype: 'Piercing Beam',
      battleSpecialName: 'Piercing Beam',
      summary: 'Devastating focused beam that tears through defenses.',
    ),
    'Kin': FamilyMoveStyle(
      family: 'Kin',
      survivalArchetype: 'Sanctuary',
      battleSpecialName: 'Sanctuary',
      summary:
          'Restores health to all allies, cleanses ailments, and bolsters defenses.',
    ),
    'Mystic': FamilyMoveStyle(
      family: 'Mystic',
      survivalArchetype: 'Arcane Orbitals',
      battleSpecialName: 'Arcane Orbitals',
      summary:
          'Summons arcane projectiles that strike repeatedly with unpredictable elemental effects.',
    ),
  };

  /// Cooldown turns for each family's special ability.
  static int specialCooldownForFamily(String? family) {
    switch (family) {
      case 'Let':
        return 2;
      case 'Pip':
        return 2;
      case 'Mane':
        return 3;
      case 'Horn':
        return 3;
      case 'Mask':
        return 4;
      case 'Wing':
        return 4;
      case 'Kin':
        return 3;
      case 'Mystic':
        return 3;
      default:
        return 2;
    }
  }

  static FamilyMoveStyle styleForFamily(String family) {
    return _familyStyles[family] ??
        const FamilyMoveStyle(
          family: 'Unknown',
          survivalArchetype: 'Special',
          battleSpecialName: 'Special Attack',
          summary: 'Family special move.',
        );
  }

  /// Human-readable boss-mode summary that matches implemented behavior.
  static String specialSummaryForCombatant(BattleCombatant combatant) {
    final family = combatant.family;
    final element = combatant.types.isNotEmpty
        ? combatant.types.first
        : 'Normal';

    switch (family) {
      case 'Let':
        return 'Heavy burst (1.4x) with $element rider effects from elemental status logic.';
      case 'Pip':
        return 'Frenzy combo: 2-4 rapid hits with escalating critical chance per hit.';
      case 'Mane':
        return 'Entangle: applies Speed/Defense debuffs to target and grants team regen for 2 turns.';
      case 'Horn':
        return 'Fortress: grants all allies shields (15% max HP) and taunts the boss for 2 turns.';
      case 'Mask':
        return 'Hex Field: applies curse/debuffs, and detonates existing curse for burst damage.';
      case 'Wing':
        switch (element) {
          case 'Ice':
            return 'Glacial Lance: focused beam with higher defense retention and freeze/slow rider.';
          case 'Dust':
            return 'Sandstorm Beam: deeper defense pierce plus blind-style attack/speed debuffs.';
          case 'Lightning':
            return 'Stormrail Beam: charged beam with bonus overcharge crit chance and speed jolt.';
          default:
            return 'Piercing Beam: high single-target damage that partially ignores defense with elemental rider.';
        }
      case 'Kin':
        return 'Sanctuary: heals team (20%), cleanses negative effects, and grants defense-up.';
      case 'Mystic':
        return 'Arcane Orbitals: 3-hit burst plus a random elemental rider effect.';
      default:
        return styleForFamily(family).summary;
    }
  }

  /// Boss-only gimmick summary keyed to the current implemented mechanics.
  static String bossGimmickSummaryForCombatant(BattleCombatant combatant) {
    switch (combatant.id) {
      case 'boss_001':
        return 'Inferno Execution: attacks deal double damage to burned targets.';
      case 'boss_002':
        return 'Undertow Control: slows targets, then Aqua-jet punishes slowed enemies.';
      case 'boss_003':
        return 'Stone Bastion: repeatedly stacks defense and temporary shielding.';
      case 'boss_004':
        return 'Jetstream Evasion: speed buffs grant a dodge window against attacks.';
      case 'boss_005':
        return 'Overgrowth Sustain: regeneration pressure with teamwide slows.';
      case 'boss_006':
        return 'Shatter Pattern: frozen targets take bonus burst damage.';
      case 'boss_007':
        return 'Charge Engine: Charge-up stores a doubled next damaging strike.';
      case 'boss_008':
        return 'Toxic Execution: poisoned targets take heavy bonus damage.';
      case 'boss_009':
        return 'Scalding Tempo: steam attacks spread burns and keep offensive pace.';
      case 'boss_010':
        return 'Molten Armor: attackers are burned while lava debuffs shred defenses.';
      case 'boss_011':
        return 'Sink Cycle: submerges for a turn, then returns with a boosted ambush.';
      case 'boss_012':
        return 'Mirage Screen: creates copies that absorb incoming hits.';
      case 'boss_013':
        return 'Prism Retaliation: elemental hits are reflected while shielded.';
      case 'boss_014':
        return 'Ethereal Purge: curses enemies and periodically self-cleanses.';
      case 'boss_015':
        return 'Void Banish: Eclipse banishes the highest damage dealer for 5 turns.';
      case 'boss_016':
        return 'Radiant Aegis: on first drop below 50% HP, gains a holy barrier.';
      case 'boss_017':
        return 'Blood Frenzy: damage scales up as HP drops, with bleed pressure.';
      default:
        return 'No unique boss special configured.';
    }
  }

  static String _formatElementalSpecialName(
    String family,
    String element,
    String baseName,
  ) {
    switch (family) {
      case 'Wing':
        switch (element) {
          case 'Ice':
            return 'Glacial Lance';
          case 'Dust':
            return 'Sandstorm Beam';
          case 'Lightning':
            return 'Stormrail Beam';
          case 'Fire':
            return 'Flare Lance';
          default:
            return '$element $baseName';
        }
      case 'Mask':
        return '$element Hex Field';
      case 'Mystic':
        return '$element Orbitals';
      default:
        return '$element $baseName';
    }
  }

  /// Element-aware special move (used for both move labels and behavior routing).
  static BattleMove getSpecialMoveForCombatant(BattleCombatant combatant) {
    final base = getSpecialMove(combatant.family);
    final element = combatant.types.isNotEmpty ? combatant.types.first : '';
    if (element.isEmpty) return base;
    return BattleMove(
      name: _formatElementalSpecialName(combatant.family, element, base.name),
      type: base.type,
      scalingStat: base.scalingStat,
      isSpecial: base.isSpecial,
      family: base.family,
    );
  }

  // Basic moves from BasicAtks.csv
  static BattleMove getBasicMove(String family) {
    switch (family) {
      case 'Let':
        return const BattleMove(
          name: 'Sprite-hit',
          type: MoveType.physical,
          scalingStat: 'statSpeed',
        );
      case 'Pip':
        return const BattleMove(
          name: 'Pip-bite',
          type: MoveType.physical,
          scalingStat: 'statStrength',
        );
      case 'Mane':
        return const BattleMove(
          name: 'Vine-whip',
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
        );
      case 'Horn':
        return const BattleMove(
          name: 'Horn-bash',
          type: MoveType.physical,
          scalingStat: 'statStrength',
        );
      case 'Mask':
        return const BattleMove(
          name: 'Hex-bolt',
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
        );
      case 'Wing':
        return const BattleMove(
          name: 'Wing-slash',
          type: MoveType.physical,
          scalingStat: 'statSpeed',
        );
      case 'Kin':
        return const BattleMove(
          name: 'Kin-stomp',
          type: MoveType.physical,
          scalingStat: 'statStrength',
        );
      case 'Mystic':
        return const BattleMove(
          name: 'Mystic-pulse',
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
        );
      default:
        return const BattleMove(
          name: 'Strike',
          type: MoveType.physical,
          scalingStat: 'statStrength',
        );
    }
  }

  // Special abilities from SpecialAbilities.csv
  static BattleMove getSpecialMove(String family) {
    final style = styleForFamily(family);
    switch (family) {
      case 'Let':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.physical,
          scalingStat: 'statSpeed',
          isSpecial: true,
          family: 'Let',
        );
      case 'Pip':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.physical,
          scalingStat: 'statStrength',
          isSpecial: true,
          family: 'Pip',
        );
      case 'Mane':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
          isSpecial: true,
          family: 'Mane',
        );
      case 'Horn':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.physical,
          scalingStat: 'statStrength',
          isSpecial: true,
          family: 'Horn',
        );
      case 'Mask':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
          isSpecial: true,
          family: 'Mask',
        );
      case 'Wing':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.physical,
          scalingStat: 'statSpeed',
          isSpecial: true,
          family: 'Wing',
        );
      case 'Kin':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
          isSpecial: true,
          family: 'Kin',
        );
      case 'Mystic':
        return BattleMove(
          name: style.battleSpecialName,
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
          isSpecial: true,
          family: 'Mystic',
        );
      default:
        return const BattleMove(
          name: 'Special Attack',
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
          isSpecial: true,
        );
    }
  }
}

class BattleAction {
  final BattleCombatant actor;
  final BattleMove move;
  final BattleCombatant target;

  const BattleAction({
    required this.actor,
    required this.move,
    required this.target,
  });
}

class BattleResult {
  final int damage;
  final bool isCritical;
  final double typeMultiplier;
  final List<String> messages;
  final bool targetDefeated;

  const BattleResult({
    required this.damage,
    required this.isCritical,
    required this.typeMultiplier,
    required this.messages,
    required this.targetDefeated,
  });
}

/// Main battle engine - handles all combat calculations
class BattleEngine {
  static bool isSurvivalMode = false;
  static final Random _random = Random();

  // Type effectiveness from AdvantagesLogic.csv
  static const Map<String, List<String>> typeChart = {
    'Fire': ['Plant', 'Ice'],
    'Water': ['Fire', 'Lava', 'Dust'],
    'Earth': ['Fire', 'Lightning', 'Poison'],
    'Air': ['Plant', 'Mud'],
    'Plant': ['Water', 'Earth', 'Mud'],
    'Ice': ['Plant', 'Earth', 'Air'],
    'Lightning': ['Water', 'Air'],
    'Poison': ['Plant', 'Water'],
    'Steam': ['Ice', 'Plant'],
    'Lava': ['Ice', 'Plant', 'Crystal'],
    'Mud': ['Fire', 'Lightning', 'Poison'],
    'Dust': ['Fire', 'Lightning'],
    'Crystal': ['Ice', 'Lightning'],
    'Spirit': ['Poison', 'Blood'],
    'Blood': ['Spirit', 'Earth'],
    'Light': ['Dark', 'Spirit', 'Poison'],
    'Dark': ['Light', 'Spirit'],
  };

  /// Calculate type effectiveness multiplier
  static double getTypeMultiplier(
    String attackType,
    List<String> defenderTypes,
  ) {
    for (final defenderType in defenderTypes) {
      // Super effective (x2)
      if (typeChart[attackType]?.contains(defenderType) ?? false) {
        return 2.0;
      }

      // Not very effective (x0.5) - reverse lookup
      if (typeChart[defenderType]?.contains(attackType) ?? false) {
        return 0.5;
      }
    }

    return 1.0; // Neutral
  }

  /// Calculate base damage using formulas from GameplayInfo.csv
  static int calculateBaseDamage({
    required BattleMove move,
    required BattleCombatant attacker,
    required BattleCombatant defender,
  }) {
    int attackStat;
    int defenseStat;

    if (move.type == MoveType.physical) {
      attackStat = attacker.getEffectivePhysAtk();
      defenseStat = defender.getEffectivePhysDef();
    } else {
      attackStat = attacker.getEffectiveElemAtk();
      defenseStat = defender.getEffectiveElemDef();
    }

    // Base_Damage = (Attacker_Atk_Stat * 2) - Defender_Def_Stat
    final baseDamage = (attackStat * 2) - defenseStat;

    // Minimum 1 damage
    return max(baseDamage, 1);
  }

  /// Execute a battle action and return results
  static BattleResult executeAction(
    BattleAction action, {
    List<BattleCombatant>? allyTeam,
  }) {
    final attacker = action.actor;
    final defender = action.target;
    final move = action.move;

    final blocked = resolveTurnBlock(attacker, move);
    if (blocked != null) return blocked;

    if (!defender.canBeTargeted) {
      return BattleResult(
        damage: 0,
        isCritical: false,
        typeMultiplier: 1.0,
        messages: [
          '${attacker.name} used ${move.name}!',
          '${defender.name} cannot be targeted right now.',
        ],
        targetDefeated: false,
      );
    }

    final messages = <String>[];
    int damage = 0;
    bool isCritical = false;
    double typeMultiplier = 1.0;

    messages.add('${attacker.name} used ${move.name}!');

    // Special move mechanics
    if (move.isSpecial) {
      // Set cooldown for all specials
      attacker.specialCooldown = BattleMove.specialCooldownForFamily(
        move.family,
      );

      final specialResult = _handleSpecialMove(
        action,
        messages,
        allyTeam: allyTeam,
      );
      if (specialResult != null) return specialResult;
    }

    // Calculate base damage
    damage = calculateBaseDamage(
      move: move,
      attacker: attacker,
      defender: defender,
    );

    // Type effectiveness
    if (attacker.types.isNotEmpty) {
      typeMultiplier = getTypeMultiplier(attacker.types.first, defender.types);

      if (typeMultiplier == 2.0) {
        messages.add("It's super effective!");
      } else if (typeMultiplier == 0.5) {
        messages.add("It's not very effective...");
      }

      damage = (damage * typeMultiplier).toInt();
    }

    // Lightning element: 20% higher crit chance
    final isLightning = attacker.types.contains('Lightning');
    final critChance = isLightning ? 0.25 : 0.05;

    if (_random.nextDouble() < critChance) {
      isCritical = true;
      damage = (damage * 1.5).toInt();
      messages.add('A critical hit!');
    }

    // Randomization (±10%)
    final variance = 0.9 + (_random.nextDouble() * 0.2);
    damage = (damage * variance).toInt();

    // Apply elemental effects (30% chance)
    if (_random.nextDouble() < 0.3) {
      _applyElementalEffect(attacker, defender, messages);
    }

    // Dark element: Lifesteal
    if (attacker.types.contains('Dark')) {
      final heal = (damage * 0.2).toInt();
      attacker.heal(heal);
      messages.add('${attacker.name} drained $heal HP!');
    }

    // Blood element: Empower (recoil)
    if (attacker.types.contains('Blood')) {
      damage = (damage * 1.25).toInt();
      final recoil = (attacker.maxHp * 0.05).toInt();
      attacker.takeDamage(recoil);
      messages.add('${attacker.name} took $recoil recoil damage!');
    }

    // Deal damage
    defender.takeDamage(damage);
    messages.add('${defender.name} took $damage damage!');

    return BattleResult(
      damage: damage,
      isCritical: isCritical,
      typeMultiplier: typeMultiplier,
      messages: messages,
      targetDefeated: defender.isDead,
    );
  }

  /// Resolves effects that prevent taking a turn (for now: freeze).
  /// Returns a prebuilt result when action is blocked, else null.
  static BattleResult? resolveTurnBlock(
    BattleCombatant actor,
    BattleMove move,
  ) {
    if (actor.isBanished) {
      return BattleResult(
        damage: 0,
        isCritical: false,
        typeMultiplier: 1.0,
        messages: [
          '${actor.name} used ${move.name}!',
          '${actor.name} is trapped in the void and cannot act!',
        ],
        targetDefeated: false,
      );
    }

    // Frozen: 30% chance to lose turn
    if (actor.statusEffects.containsKey('freeze')) {
      if (_random.nextDouble() < 0.3) {
        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: [
            '${actor.name} used ${move.name}!',
            '${actor.name} is frozen solid!',
          ],
          targetDefeated: false,
        );
      }
    }

    return null;
  }

  static BattleResult? _handleSpecialMove(
    BattleAction action,
    List<String> messages, {
    List<BattleCombatant>? allyTeam,
  }) {
    final family = action.move.family;
    final attacker = action.actor;
    final defender = action.target;

    switch (family) {
      case 'Let': // Meteor Strike — Heavy burst + element-flavored DOT
        final meteorDamage =
            (calculateBaseDamage(
                      move: action.move,
                      attacker: attacker,
                      defender: defender,
                    ) *
                    1.4)
                .round();
        defender.takeDamage(meteorDamage);
        messages.add('Meteor Strike!');
        messages.add('${defender.name} took $meteorDamage damage!');
        // Apply element-specific lingering effect
        if (attacker.types.isNotEmpty) {
          _applyElementalEffect(attacker, defender, messages);
        }
        return BattleResult(
          damage: meteorDamage,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: defender.isDead,
        );

      case 'Pip': // Frenzy — Multi-hit 2-4 times with escalating crit chance
        final hits = 2 + _random.nextInt(3); // 2-4 hits
        int totalDamage = 0;
        bool anyCrit = false;

        for (int i = 0; i < hits; i++) {
          var hitDamage =
              (calculateBaseDamage(
                        move: action.move,
                        attacker: attacker,
                        defender: defender,
                      ) *
                      0.35)
                  .toInt();

          // Each subsequent hit has higher crit chance: 10%, 20%, 30%, 40%
          final critChance = 0.10 + (i * 0.10);
          if (_random.nextDouble() < critChance) {
            hitDamage = (hitDamage * 1.5).toInt();
            anyCrit = true;
          }

          defender.takeDamage(hitDamage);
          totalDamage += hitDamage;
        }

        messages.add('Hit $hits time${hits > 1 ? 's' : ''}!');
        if (anyCrit) messages.add('Critical strikes landed!');
        messages.add('${defender.name} took $totalDamage total damage!');

        return BattleResult(
          damage: totalDamage,
          isCritical: anyCrit,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: defender.isDead,
        );

      case 'Mane': // Entangle — Debuff boss + give allies regen
        // Slow and weaken the boss
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 3),
        );
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 2),
        );
        messages.add('${defender.name} is entangled!');
        messages.add("${defender.name}'s Speed and Defense fell!");

        // Give all alive allies regen
        final allies = allyTeam ?? [attacker];
        for (final ally in allies) {
          if (ally.isAlive) {
            ally.applyStatusEffect(
              StatusEffect(
                type: 'regen',
                damagePerTurn: -(ally.maxHp * 0.08).toInt(),
                duration: 2,
              ),
            );
          }
        }
        messages.add('Allies are nourished — HP will regenerate!');

        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );

      case 'Horn': // Fortress — Team shield + taunt
        // Shield all alive allies
        final allies = allyTeam ?? [attacker];
        final shieldAmount = (attacker.maxHp * 0.15).toInt();
        for (final ally in allies) {
          if (ally.isAlive) {
            ally.shieldHp = (ally.shieldHp ?? 0) + shieldAmount;
          }
        }
        messages.add('${attacker.name} raised Fortress!');
        messages.add('All allies gained $shieldAmount shield!');

        // Apply taunt: boss must target this creature
        defender.tauntTargetId = attacker.id;
        defender.applyStatusEffect(
          StatusEffect(type: 'taunt', damagePerTurn: 0, duration: 2),
        );
        messages.add('${attacker.name} taunted ${defender.name}!');

        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );

      case 'Mask': // Hex Field — curse/debuff; detonates existing curse
        final alreadyCursed = defender.statusEffects.containsKey('curse');

        if (alreadyCursed) {
          // Detonate: deal burst damage based on remaining curse DOT
          final curseEffect = defender.statusEffects['curse']!;
          final burstDamage =
              (curseEffect.damagePerTurn * curseEffect.duration * 1.5).toInt();
          defender.statusEffects.remove('curse');
          defender.takeDamage(burstDamage);
          messages.add('Hex Field detonated the curse!');
          messages.add('${defender.name} took $burstDamage burst damage!');

          // Re-apply fresh curse
          defender.applyStatusEffect(
            StatusEffect(
              type: 'curse',
              damagePerTurn: (defender.maxHp * 0.08).toInt(),
              duration: 3,
            ),
          );
          messages.add('A new curse grips ${defender.name}!');

          return BattleResult(
            damage: burstDamage,
            isCritical: false,
            typeMultiplier: 1.0,
            messages: messages,
            targetDefeated: defender.isDead,
          );
        } else {
          // Fresh curse + attack down + speed down
          defender.applyStatusEffect(
            StatusEffect(
              type: 'curse',
              damagePerTurn: (defender.maxHp * 0.10).toInt(),
              duration: 3,
            ),
          );
          defender.applyStatModifier(
            StatModifier(type: 'attack_down', duration: 2),
          );
          defender.applyStatModifier(
            StatModifier(type: 'speed_down', duration: 2),
          );
          messages.add('Hex Field curses ${defender.name}!');
          messages.add("${defender.name}'s Attack and Speed fell!");

          return BattleResult(
            damage: 0,
            isCritical: false,
            typeMultiplier: 1.0,
            messages: messages,
            targetDefeated: false,
          );
        }

      case 'Wing': // Piercing Beam — Massive damage, partially ignores defense
        final element = attacker.types.isNotEmpty ? attacker.types.first : '';
        var defenseRetained = 0.50;
        var beamMultiplier = 1.60;
        var bonusCritChance = 0.0;

        switch (element) {
          case 'Ice':
            defenseRetained = 0.55;
            beamMultiplier = 1.45;
            messages.add('Glacial lance pins the target in place!');
            break;
          case 'Dust':
            defenseRetained = 0.42;
            beamMultiplier = 1.35;
            messages.add('Sandstorm beam blots out vision!');
            break;
          case 'Lightning':
            defenseRetained = 0.50;
            beamMultiplier = 1.50;
            bonusCritChance = 0.22;
            messages.add('Stormrail beam crackles with charged force!');
            break;
          default:
            break;
        }

        // Calculate damage with element-specific defense piercing profile.
        final attackStat = action.move.type == MoveType.physical
            ? attacker.getEffectivePhysAtk()
            : attacker.getEffectiveElemAtk();
        final defStat = action.move.type == MoveType.physical
            ? defender.getEffectivePhysDef()
            : defender.getEffectiveElemDef();
        final reducedDef = (defStat * defenseRetained).toInt();
        var beamDamage = max(1, (attackStat * 2) - reducedDef);
        beamDamage = (beamDamage * beamMultiplier).toInt();

        // Variance
        final variance = 0.9 + (_random.nextDouble() * 0.2);
        beamDamage = (beamDamage * variance).toInt();

        if (bonusCritChance > 0 && _random.nextDouble() < bonusCritChance) {
          beamDamage = (beamDamage * 1.35).toInt();
          messages.add('Overcharge critical!');
        }

        defender.takeDamage(beamDamage);
        messages.add('Piercing Beam tears through defenses!');
        messages.add('${defender.name} took $beamDamage damage!');
        _applyElementalEffect(attacker, defender, messages);

        return BattleResult(
          damage: beamDamage,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: defender.isDead,
        );

      case 'Kin': // Sanctuary — Team heal + cleanse negative effects + defense up
        final allies = allyTeam ?? [attacker];
        for (final ally in allies) {
          if (ally.isAlive) {
            final healAmount = (ally.maxHp * 0.20).toInt();
            ally.heal(healAmount);

            // Cleanse negative status effects
            final toRemove = <String>[];
            for (final e in ally.statusEffects.entries) {
              if (e.value.damagePerTurn > 0) toRemove.add(e.key); // DOTs
              if (e.key == 'freeze') toRemove.add(e.key);
            }
            for (final key in toRemove) {
              ally.statusEffects.remove(key);
            }

            // Remove negative stat modifiers
            ally.statModifiers.remove('attack_down');
            ally.statModifiers.remove('defense_down');
            ally.statModifiers.remove('speed_down');

            // Grant defense up
            ally.applyStatModifier(
              StatModifier(type: 'defense_up', duration: 2),
            );
          }
        }
        messages.add('${attacker.name} invoked Sanctuary!');
        messages.add('All allies healed and cleansed!');
        messages.add("Team defense rose!");

        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );

      case 'Mystic': // Arcane Orbitals — 3 hits + random elemental effect
        attacker.isCharging = false;
        final hits = 3;
        int totalDamage = 0;
        for (int i = 0; i < hits; i++) {
          final hit =
              (calculateBaseDamage(
                        move: action.move,
                        attacker: attacker,
                        defender: defender,
                      ) *
                      0.45)
                  .toInt();
          defender.takeDamage(hit);
          totalDamage += hit;
        }
        messages.add('Arcane Orbitals struck $hits times!');
        messages.add('${defender.name} took $totalDamage total damage!');

        // Apply a random elemental effect
        final randomElements = ['Fire', 'Ice', 'Poison', 'Lightning', 'Earth'];
        final fakeAttacker = BattleCombatant(
          id: 'arcane_effect',
          name: attacker.name,
          types: [randomElements[_random.nextInt(randomElements.length)]],
          family: attacker.family,
          statSpeed: attacker.statSpeed,
          statIntelligence: attacker.statIntelligence,
          statStrength: attacker.statStrength,
          statBeauty: attacker.statBeauty,
          level: attacker.level,
        );
        _applyElementalEffect(fakeAttacker, defender, messages);

        return BattleResult(
          damage: totalDamage,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: defender.isDead,
        );
    }

    return null;
  }

  static void _applyElementalEffect(
    BattleCombatant attacker,
    BattleCombatant defender,
    List<String> messages,
  ) {
    if (attacker.types.isEmpty) return;

    final element = attacker.types.first;
    final statusScale = isSurvivalMode ? 0.5 : 1.0; // 50% in survival

    switch (element) {
      case 'Fire':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: (defender.maxHp * 0.06 * statusScale)
                .toInt(), // was 0.06
            duration: 3,
          ),
        );
        messages.add('${defender.name} was burned!');
        break;

      case 'Poison':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'poison',
            damagePerTurn: (defender.maxHp * 0.08 * statusScale)
                .toInt(), // was 0.08
            duration: 3,
          ),
        );
        messages.add('${defender.name} was poisoned!');
        break;

      case 'Lava':
        defender.applyStatModifier(
          StatModifier(type: 'defense_down', duration: 3),
        );
        messages.add("${defender.name}'s Defense fell!");
        break;

      case 'Water':
      case 'Ice':
      case 'Mud':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 3),
        );
        messages.add("${defender.name}'s Speed fell!");

        if (element == 'Ice') {
          defender.applyStatusEffect(
            StatusEffect(type: 'freeze', damagePerTurn: 0, duration: 2),
          );
          messages.add('${defender.name} was frozen!');
        }
        break;

      case 'Earth':
        attacker.applyStatModifier(
          StatModifier(type: 'defense_up', duration: 3),
        );
        messages.add("${attacker.name}'s Defense rose!");
        break;

      case 'Crystal':
        attacker.shieldHp = (attacker.maxHp * 0.15).toInt();
        messages.add('${attacker.name} gained a barrier!');
        break;

      case 'Plant':
        attacker.applyStatusEffect(
          StatusEffect(
            type: 'regen',
            damagePerTurn: -(attacker.maxHp * 0.05).toInt(),
            duration: 3,
          ),
        );
        messages.add('${attacker.name} will regenerate HP!');
        break;

      case 'Light':
        attacker.applyStatModifier(
          StatModifier(type: 'attack_up', duration: 2),
        );
        messages.add("${attacker.name}'s Attack rose!");
        break;

      case 'Lightning':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        messages.add('${defender.name} was jolted!');
        break;

      case 'Air':
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        messages.add('${defender.name} was battered by gale force!');
        break;

      case 'Steam':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: (defender.maxHp * 0.04 * statusScale).toInt(),
            duration: 2,
          ),
        );
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 1),
        );
        messages.add('${defender.name} was scalded by steam!');
        break;

      case 'Dust':
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 2),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 1),
        );
        messages.add('${defender.name} was blinded by dust!');
        break;

      case 'Spirit':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'curse',
            damagePerTurn: (defender.maxHp * 0.07 * statusScale).toInt(),
            duration: 2,
          ),
        );
        messages.add('${defender.name} was haunted!');
        break;
    }
  }

  /// Process end-of-turn effects (DoT, regen, etc.)
  static List<String> processEndOfTurnEffects(BattleCombatant combatant) {
    final messages = <String>[];

    // Banished units are out of phase: do not process incoming/outgoing
    // periodic damage while in the void, but timers still tick below.
    if (combatant.isBanished) {
      combatant.tickStatusEffects();
      combatant.tickStatModifiers();
      combatant.tickTaunt();
      return messages;
    }

    // Process status effects
    for (final effect in combatant.statusEffects.values) {
      if (effect.type == 'taunt') continue; // Taunt is not DoT
      if (effect.damagePerTurn > 0) {
        combatant.takeDamage(effect.damagePerTurn);
        messages.add(
          '${combatant.name} took ${effect.damagePerTurn} ${effect.type} damage!',
        );
      } else if (effect.damagePerTurn < 0) {
        final healing = -effect.damagePerTurn;
        combatant.heal(healing);
        messages.add('${combatant.name} recovered $healing HP!');
      }
    }

    combatant.tickStatusEffects();
    combatant.tickStatModifiers();
    combatant.tickTaunt();

    return messages;
  }

  /// Determine turn order based on speed
  static List<BattleCombatant> determineTurnOrder(
    List<BattleCombatant> combatants,
  ) {
    final sorted = List<BattleCombatant>.from(combatants);
    sorted.sort(
      (a, b) => b.getEffectiveSpeed().compareTo(a.getEffectiveSpeed()),
    );
    return sorted;
  }
}

extension BattleCombatantScaling on BattleCombatant {
  /// Returns a *copy* with scaled combat stats (HP, atk, def, speed).
  /// Visual refs (speciesRef / instanceRef) are preserved so sprites still work.
  BattleCombatant scaledCopy({
    required String newId,
    String? newName,
    double hpScale = 1.0,
    double atkScale = 1.0,
    double defScale = 1.0,
    double spdScale = 1.0,
  }) {
    final copy = BattleCombatant(
      id: newId,
      name: newName ?? name,
      types: types,
      family: family,
      statSpeed: statSpeed,
      statIntelligence: statIntelligence,
      statStrength: statStrength,
      statBeauty: statBeauty,
      level: level,
      instanceRef: instanceRef,
      speciesRef: speciesRef,
    );

    // Override the calculated combat stats
    copy.maxHp = (maxHp * hpScale).round();
    copy.currentHp = copy.maxHp;
    copy.physAtk = (physAtk * atkScale).round();
    copy.elemAtk = (elemAtk * atkScale).round();
    copy.physDef = (physDef * defScale).round();
    copy.elemDef = (elemDef * defScale).round();
    copy.speed = (speed * spdScale).round();

    return copy;
  }
}
