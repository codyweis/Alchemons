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
  bool needsRecharge = false;
  int? shieldHp;

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
      battleSpecialName: 'Meteor',
      summary: 'Heavy elemental burst that slams a single target.',
    ),
    'Pip': FamilyMoveStyle(
      family: 'Pip',
      survivalArchetype: 'Ricochet',
      battleSpecialName: 'Ricochet',
      summary: 'Multi-hit chain strike that can hit 2-3 times.',
    ),
    'Mane': FamilyMoveStyle(
      family: 'Mane',
      survivalArchetype: 'Barrage',
      battleSpecialName: 'Barrage',
      summary: 'Rapid elemental volleys that pressure the enemy.',
    ),
    'Mask': FamilyMoveStyle(
      family: 'Mask',
      survivalArchetype: 'Trap Field',
      battleSpecialName: 'Trap Field',
      summary: 'Applies lingering curse pressure and control.',
    ),
    'Horn': FamilyMoveStyle(
      family: 'Horn',
      survivalArchetype: 'Nova',
      battleSpecialName: 'Nova',
      summary: 'Protective burst that fortifies and retaliates.',
    ),
    'Wing': FamilyMoveStyle(
      family: 'Wing',
      survivalArchetype: 'Beam',
      battleSpecialName: 'Beam',
      summary: 'Piercing burst with high impact and short cooldown cycle.',
    ),
    'Kin': FamilyMoveStyle(
      family: 'Kin',
      survivalArchetype: 'Blessing',
      battleSpecialName: 'Blessing',
      summary: 'Restorative support burst with stat empowerment.',
    ),
    'Mystic': FamilyMoveStyle(
      family: 'Mystic',
      survivalArchetype: 'Orbitals',
      battleSpecialName: 'Orbitals',
      summary: 'Arcane orbital strikes that hit repeatedly.',
    ),
  };

  static FamilyMoveStyle styleForFamily(String family) {
    return _familyStyles[family] ??
        const FamilyMoveStyle(
          family: 'Unknown',
          survivalArchetype: 'Special',
          battleSpecialName: 'Special Attack',
          summary: 'Family special move.',
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
  static BattleResult executeAction(BattleAction action) {
    final blocked = resolveTurnBlock(action.actor, action.move);
    if (blocked != null) return blocked;

    final messages = <String>[];
    int damage = 0;
    bool isCritical = false;
    double typeMultiplier = 1.0;

    final attacker = action.actor;
    final defender = action.target;
    final move = action.move;

    messages.add('${attacker.name} used ${move.name}!');

    // Special move mechanics
    if (move.isSpecial) {
      final specialResult = _handleSpecialMove(action, messages);
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

    // Wing cooldown: using a non-special attack consumes the recharge turn
    // and makes special available again.
    if (attacker.needsRecharge && !move.isSpecial) {
      attacker.needsRecharge = false;
    }

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
    List<String> messages,
  ) {
    final family = action.move.family;
    final attacker = action.actor;
    final defender = action.target;

    switch (family) {
      case 'Let': // Meteor
        final meteorDamage =
            (calculateBaseDamage(
                      move: action.move,
                      attacker: attacker,
                      defender: defender,
                    ) *
                    1.4)
                .round();
        defender.takeDamage(meteorDamage);
        messages.add('Meteor impact!');
        messages.add('${defender.name} took $meteorDamage damage!');
        return BattleResult(
          damage: meteorDamage,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: defender.isDead,
        );

      case 'Pip': // Pip-fury: Multi-hit 2-3 times
        final hits = 2 + _random.nextInt(2); // 2-3 hits
        int totalDamage = 0;

        for (int i = 0; i < hits; i++) {
          final hitDamage =
              (calculateBaseDamage(
                        move: action.move,
                        attacker: attacker,
                        defender: defender,
                      ) *
                      0.4)
                  .toInt();
          defender.takeDamage(hitDamage);
          totalDamage += hitDamage;
        }

        messages.add('Hit $hits time${hits > 1 ? 's' : ''}!');
        messages.add('${defender.name} took $totalDamage total damage!');

        return BattleResult(
          damage: totalDamage,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: defender.isDead,
        );

      case 'Mane': // Barrage
        final hitA =
            (calculateBaseDamage(
                      move: action.move,
                      attacker: attacker,
                      defender: defender,
                    ) *
                    0.6)
                .toInt();
        final hitB =
            (calculateBaseDamage(
                      move: action.move,
                      attacker: attacker,
                      defender: defender,
                    ) *
                    0.6)
                .toInt();
        final total = hitA + hitB;
        defender.takeDamage(total);
        messages.add('Barrage landed 2 hits!');
        messages.add('${defender.name} took $total total damage!');
        return BattleResult(
          damage: total,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: defender.isDead,
        );

      case 'Horn': // Nova
        attacker.shieldHp = (attacker.maxHp * 0.3).toInt();
        final novaDamage =
            (calculateBaseDamage(
                      move: action.move,
                      attacker: attacker,
                      defender: defender,
                    ) *
                    0.7)
                .toInt();
        defender.takeDamage(novaDamage);
        messages.add('${attacker.name} unleashed Nova and gained a shield!');
        messages.add('${defender.name} took $novaDamage damage!');
        return BattleResult(
          damage: novaDamage,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: defender.isDead,
        );

      case 'Mask': // Trap Field
        defender.applyStatusEffect(
          StatusEffect(
            type: 'curse',
            damagePerTurn: (defender.maxHp * 0.1).toInt(),
            duration: 3,
          ),
        );
        defender.applyStatModifier(
          StatModifier(type: 'speed_down', duration: 2),
        );
        messages.add('Trap Field ensnared ${defender.name}!');
        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );

      case 'Wing': // Beam: triggers cooldown after use
        attacker.needsRecharge = true;
        return null;

      case 'Kin': // Blessing
        final healAmount = (attacker.statIntelligence * 3).toInt();
        attacker.heal(healAmount);
        attacker.applyStatModifier(
          StatModifier(type: 'attack_up', duration: 2),
        );
        messages.add('${attacker.name} healed $healAmount HP!');
        messages.add("${attacker.name}'s Attack rose!");
        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );

      case 'Mystic': // Orbitals
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
        messages.add('Orbitals struck $hits times!');
        messages.add('${defender.name} took $totalDamage total damage!');
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
    }
  }

  /// Process end-of-turn effects (DoT, regen, etc.)
  static List<String> processEndOfTurnEffects(BattleCombatant combatant) {
    final messages = <String>[];

    // Process status effects
    for (final effect in combatant.statusEffects.values) {
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
