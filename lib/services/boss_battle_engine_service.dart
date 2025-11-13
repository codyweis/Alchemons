// // lib/services/battle_engine.dart
// import 'dart:math';
// import 'package:alchemons/models/boss/boss_model.dart';
// import 'package:alchemons/models/creature.dart';
// import 'package:alchemons/database/alchemons_db.dart';

// /// Represents a combatant (player creature or boss) in battle
// class BattleCombatant {
//   final String id;
//   final String name;
//   final List<String> types; // Element types
//   final String family; // Let, Pip, Mane, etc.

//   // Base stats
//   final double statSpeed;
//   final double statIntelligence;
//   final double statStrength;
//   final double statBeauty;
//   final int level;

//   // Combat stats (calculated)
//   late final int maxHp;
//   late final int physAtk;
//   late final int elemAtk;
//   late final int physDef;
//   late final int elemDef;
//   late final int speed;

//   // Battle state
//   late int currentHp;
//   Map<String, StatusEffect> statusEffects = {};
//   Map<String, StatModifier> statModifiers = {};
//   bool isCharging = false;
//   bool needsRecharge = false;
//   int? shieldHp;

//   BattleCombatant({
//     required this.id,
//     required this.name,
//     required this.types,
//     required this.family,
//     required this.statSpeed,
//     required this.statIntelligence,
//     required this.statStrength,
//     required this.statBeauty,
//     required this.level,
//   }) {
//     _calculateCombatStats();
//     currentHp = maxHp;
//   }

//   void _calculateCombatStats() {
//     // From StatsFormulas.csv
//     maxHp = (level * 10) + (statStrength * 5).toInt();
//     physAtk = statStrength.toInt() + (level * 2);
//     elemAtk = statIntelligence.toInt() + (level * 2);
//     physDef = (statStrength * 0.5 + statBeauty * 0.5).toInt() + level;
//     elemDef = statBeauty.toInt() + (level * 2);
//     speed = statSpeed.toInt();
//   }

//   factory BattleCombatant.fromInstance({
//     required CreatureInstance instance,
//     required Creature creature,
//   }) {
//     return BattleCombatant(
//       id: instance.instanceId,
//       name: instance.nickname ?? creature.name,
//       types: creature.types,
//       family: creature.mutationFamily!,
//       statSpeed: instance.statSpeed,
//       statIntelligence: instance.statIntelligence,
//       statStrength: instance.statStrength,
//       statBeauty: instance.statBeauty,
//       level: instance.level,
//     );
//   }

//   factory BattleCombatant.fromBoss(Boss boss) {
//     // Boss stats are already combat-ready
//     return BattleCombatant(
//         id: boss.id,
//         name: boss.name,
//         types: [boss.element],
//         family: 'Boss',
//         statSpeed: boss.spd.toDouble(),
//         statIntelligence: 50.0, // Bosses use fixed high intelligence
//         statStrength: 50.0, // Bosses use fixed high strength
//         statBeauty: 50.0,
//         level: boss.recommendedLevel,
//       )
//       ..maxHp = boss.hp
//       ..currentHp = boss.hp
//       ..physAtk = boss.atk
//       ..elemAtk = boss.atk
//       ..physDef = boss.def
//       ..elemDef = boss.def
//       ..speed = boss.spd;
//   }

//   bool get isAlive => currentHp > 0;
//   bool get isDead => currentHp <= 0;
//   double get hpPercent => currentHp / maxHp;

//   int getEffectivePhysAtk() {
//     var atk = physAtk;
//     if (statModifiers.containsKey('attack_up')) {
//       atk = (atk * 1.5).toInt();
//     }
//     if (statModifiers.containsKey('attack_down')) {
//       atk = (atk * 0.75).toInt();
//     }
//     return atk;
//   }

//   int getEffectiveElemAtk() {
//     var atk = elemAtk;
//     if (statModifiers.containsKey('attack_up')) {
//       atk = (atk * 1.5).toInt();
//     }
//     if (statModifiers.containsKey('attack_down')) {
//       atk = (atk * 0.75).toInt();
//     }
//     return atk;
//   }

//   int getEffectivePhysDef() {
//     var def = physDef;
//     if (statModifiers.containsKey('defense_up')) {
//       def = (def * 1.5).toInt();
//     }
//     if (statModifiers.containsKey('defense_down')) {
//       def = (def * 0.75).toInt();
//     }
//     return def;
//   }

//   int getEffectiveElemDef() {
//     var def = elemDef;
//     if (statModifiers.containsKey('defense_up')) {
//       def = (def * 1.5).toInt();
//     }
//     if (statModifiers.containsKey('defense_down')) {
//       def = (def * 0.75).toInt();
//     }
//     return def;
//   }

//   int getEffectiveSpeed() {
//     var spd = speed;
//     if (statModifiers.containsKey('speed_up')) {
//       spd = (spd * 1.5).toInt();
//     }
//     if (statModifiers.containsKey('speed_down')) {
//       spd = (spd * 0.75).toInt();
//     }
//     return spd;
//   }

//   void takeDamage(int damage) {
//     // Shield absorbs first
//     if (shieldHp != null && shieldHp! > 0) {
//       if (shieldHp! >= damage) {
//         shieldHp = shieldHp! - damage;
//         damage = 0;
//       } else {
//         damage -= shieldHp!;
//         shieldHp = 0;
//       }
//     }

//     currentHp = max(0, currentHp - damage);
//   }

//   void heal(int amount) {
//     currentHp = min(maxHp, currentHp + amount);
//   }

//   void applyStatusEffect(StatusEffect effect) {
//     statusEffects[effect.type] = effect;
//   }

//   void applyStatModifier(StatModifier modifier) {
//     statModifiers[modifier.type] = modifier;
//   }

//   void tickStatusEffects() {
//     final toRemove = <String>[];

//     for (final entry in statusEffects.entries) {
//       final effect = entry.value;
//       effect.tickDuration();

//       if (effect.isExpired) {
//         toRemove.add(entry.key);
//       }
//     }

//     for (final key in toRemove) {
//       statusEffects.remove(key);
//     }
//   }

//   void tickStatModifiers() {
//     final toRemove = <String>[];

//     for (final entry in statModifiers.entries) {
//       final modifier = entry.value;
//       modifier.tickDuration();

//       if (modifier.isExpired) {
//         toRemove.add(entry.key);
//       }
//     }

//     for (final key in toRemove) {
//       statModifiers.remove(key);
//     }
//   }
// }

// class StatusEffect {
//   final String type; // burn, poison, regen, etc.
//   final int damagePerTurn; // or heal per turn if positive
//   int duration;

//   StatusEffect({
//     required this.type,
//     required this.damagePerTurn,
//     required this.duration,
//   });

//   void tickDuration() => duration--;
//   bool get isExpired => duration <= 0;
// }

// class StatModifier {
//   final String type; // attack_up, defense_down, etc.
//   int duration;

//   StatModifier({required this.type, required this.duration});

//   void tickDuration() => duration--;
//   bool get isExpired => duration <= 0;
// }

// enum MoveType { physical, elemental }

// class BattleMove {
//   final String name;
//   final MoveType type;
//   final String scalingStat; // For display/tracking
//   final bool isSpecial; // True if level 5+ ability
//   final String? family; // Required family for special moves

//   const BattleMove({
//     required this.name,
//     required this.type,
//     required this.scalingStat,
//     this.isSpecial = false,
//     this.family,
//   });

//   // Basic moves from BasicAtks.csv
//   static BattleMove getBasicMove(String family) {
//     switch (family) {
//       case 'Let':
//         return const BattleMove(
//           name: 'Sprite-hit',
//           type: MoveType.physical,
//           scalingStat: 'statSpeed',
//         );
//       case 'Pip':
//         return const BattleMove(
//           name: 'Pip-bite',
//           type: MoveType.physical,
//           scalingStat: 'statStrength',
//         );
//       case 'Mane':
//         return const BattleMove(
//           name: 'Vine-whip',
//           type: MoveType.elemental,
//           scalingStat: 'statIntelligence',
//         );
//       case 'Horn':
//         return const BattleMove(
//           name: 'Horn-bash',
//           type: MoveType.physical,
//           scalingStat: 'statStrength',
//         );
//       case 'Mask':
//         return const BattleMove(
//           name: 'Hex-bolt',
//           type: MoveType.elemental,
//           scalingStat: 'statIntelligence',
//         );
//       case 'Wing':
//         return const BattleMove(
//           name: 'Wing-slash',
//           type: MoveType.physical,
//           scalingStat: 'statSpeed',
//         );
//       case 'Kin':
//         return const BattleMove(
//           name: 'Kin-stomp',
//           type: MoveType.physical,
//           scalingStat: 'statStrength',
//         );
//       case 'Mystic':
//         return const BattleMove(
//           name: 'Mystic-pulse',
//           type: MoveType.elemental,
//           scalingStat: 'statIntelligence',
//         );
//       default:
//         return const BattleMove(
//           name: 'Strike',
//           type: MoveType.physical,
//           scalingStat: 'statStrength',
//         );
//     }
//   }

//   // Special abilities from SpecialAbilities.csv
//   static BattleMove getSpecialMove(String family) {
//     switch (family) {
//       case 'Let':
//         return const BattleMove(
//           name: 'Sprite-strike',
//           type: MoveType.physical,
//           scalingStat: 'statSpeed',
//           isSpecial: true,
//           family: 'Let',
//         );
//       case 'Pip':
//         return const BattleMove(
//           name: 'Pip-fury',
//           type: MoveType.physical,
//           scalingStat: 'statStrength',
//           isSpecial: true,
//           family: 'Pip',
//         );
//       case 'Mane':
//         return const BattleMove(
//           name: "Mane's-trick",
//           type: MoveType.elemental,
//           scalingStat: 'statIntelligence',
//           isSpecial: true,
//           family: 'Mane',
//         );
//       case 'Horn':
//         return const BattleMove(
//           name: 'Horn-guard',
//           type: MoveType.physical,
//           scalingStat: 'statStrength',
//           isSpecial: true,
//           family: 'Horn',
//         );
//       case 'Mask':
//         return const BattleMove(
//           name: "Mask's-curse",
//           type: MoveType.elemental,
//           scalingStat: 'statIntelligence',
//           isSpecial: true,
//           family: 'Mask',
//         );
//       case 'Wing':
//         return const BattleMove(
//           name: 'Wing-assault',
//           type: MoveType.physical,
//           scalingStat: 'statSpeed',
//           isSpecial: true,
//           family: 'Wing',
//         );
//       case 'Kin':
//         return const BattleMove(
//           name: "Kin's-blessing",
//           type: MoveType.elemental,
//           scalingStat: 'statIntelligence',
//           isSpecial: true,
//           family: 'Kin',
//         );
//       case 'Mystic':
//         return const BattleMove(
//           name: 'Mystic-power',
//           type: MoveType.elemental,
//           scalingStat: 'statIntelligence',
//           isSpecial: true,
//           family: 'Mystic',
//         );
//       default:
//         return const BattleMove(
//           name: 'Special Attack',
//           type: MoveType.elemental,
//           scalingStat: 'statIntelligence',
//           isSpecial: true,
//         );
//     }
//   }
// }

// class BattleAction {
//   final BattleCombatant actor;
//   final BattleMove move;
//   final BattleCombatant target;

//   const BattleAction({
//     required this.actor,
//     required this.move,
//     required this.target,
//   });
// }

// class BattleResult {
//   final int damage;
//   final bool isCritical;
//   final double typeMultiplier;
//   final List<String> messages;
//   final bool targetDefeated;

//   const BattleResult({
//     required this.damage,
//     required this.isCritical,
//     required this.typeMultiplier,
//     required this.messages,
//     required this.targetDefeated,
//   });
// }

// /// Main battle engine - handles all combat calculations
// class BattleEngine {
//   static final Random _random = Random();

//   // Type effectiveness from AdvantagesLogic.csv
//   static const Map<String, List<String>> typeChart = {
//     'Fire': ['Plant', 'Ice'],
//     'Water': ['Fire', 'Lava', 'Dust'],
//     'Earth': ['Fire', 'Lightning', 'Poison'],
//     'Air': ['Plant', 'Mud'],
//     'Plant': ['Water', 'Earth', 'Mud'],
//     'Ice': ['Plant', 'Earth', 'Air'],
//     'Lightning': ['Water', 'Air'],
//     'Poison': ['Plant', 'Water'],
//     'Steam': ['Ice', 'Plant'],
//     'Lava': ['Ice', 'Plant', 'Crystal'],
//     'Mud': ['Fire', 'Lightning', 'Poison'],
//     'Dust': ['Fire', 'Lightning'],
//     'Crystal': ['Ice', 'Lightning'],
//     'Spirit': ['Poison', 'Blood'],
//     'Blood': ['Spirit', 'Earth'],
//     'Light': ['Dark', 'Spirit', 'Poison'],
//     'Dark': ['Light', 'Spirit'],
//   };

//   /// Calculate type effectiveness multiplier
//   static double getTypeMultiplier(
//     String attackType,
//     List<String> defenderTypes,
//   ) {
//     for (final defenderType in defenderTypes) {
//       // Super effective (x2)
//       if (typeChart[attackType]?.contains(defenderType) ?? false) {
//         return 2.0;
//       }

//       // Not very effective (x0.5) - reverse lookup
//       if (typeChart[defenderType]?.contains(attackType) ?? false) {
//         return 0.5;
//       }
//     }

//     return 1.0; // Neutral
//   }

//   /// Calculate base damage using formulas from GameplayInfo.csv
//   static int calculateBaseDamage({
//     required BattleMove move,
//     required BattleCombatant attacker,
//     required BattleCombatant defender,
//   }) {
//     int attackStat;
//     int defenseStat;

//     if (move.type == MoveType.physical) {
//       attackStat = attacker.getEffectivePhysAtk();
//       defenseStat = defender.getEffectivePhysDef();
//     } else {
//       attackStat = attacker.getEffectiveElemAtk();
//       defenseStat = defender.getEffectiveElemDef();
//     }

//     // Base_Damage = (Attacker_Atk_Stat * 2) - Defender_Def_Stat
//     final baseDamage = (attackStat * 2) - defenseStat;

//     // Minimum 1 damage
//     return max(baseDamage, 1);
//   }

//   /// Execute a battle action and return results
//   static BattleResult executeAction(BattleAction action) {
//     final messages = <String>[];
//     int damage = 0;
//     bool isCritical = false;
//     double typeMultiplier = 1.0;

//     final attacker = action.actor;
//     final defender = action.target;
//     final move = action.move;

//     messages.add('${attacker.name} used ${move.name}!');

//     // Check if frozen (30% chance to skip turn)
//     if (attacker.statusEffects.containsKey('freeze')) {
//       if (_random.nextDouble() < 0.3) {
//         messages.add('${attacker.name} is frozen solid!');
//         return BattleResult(
//           damage: 0,
//           isCritical: false,
//           typeMultiplier: 1.0,
//           messages: messages,
//           targetDefeated: false,
//         );
//       }
//     }

//     // Special move mechanics
//     if (move.isSpecial) {
//       final specialResult = _handleSpecialMove(action, messages);
//       if (specialResult != null) return specialResult;
//     }

//     // Calculate base damage
//     damage = calculateBaseDamage(
//       move: move,
//       attacker: attacker,
//       defender: defender,
//     );

//     // Type effectiveness
//     if (attacker.types.isNotEmpty) {
//       typeMultiplier = getTypeMultiplier(attacker.types.first, defender.types);

//       if (typeMultiplier == 2.0) {
//         messages.add("It's super effective!");
//       } else if (typeMultiplier == 0.5) {
//         messages.add("It's not very effective...");
//       }

//       damage = (damage * typeMultiplier).toInt();
//     }

//     // Lightning element: 20% higher crit chance
//     bool isLightning = attacker.types.contains('Lightning');
//     double critChance = isLightning ? 0.25 : 0.05;

//     if (_random.nextDouble() < critChance) {
//       isCritical = true;
//       damage = (damage * 1.5).toInt();
//       messages.add('A critical hit!');
//     }

//     // Randomization (±10%)
//     final variance = 0.9 + (_random.nextDouble() * 0.2);
//     damage = (damage * variance).toInt();

//     // Apply elemental effects (30% chance)
//     if (_random.nextDouble() < 0.3) {
//       _applyElementalEffect(attacker, defender, messages);
//     }

//     // Dark element: Lifesteal
//     if (attacker.types.contains('Dark')) {
//       final heal = (damage * 0.2).toInt();
//       attacker.heal(heal);
//       messages.add('${attacker.name} drained ${heal} HP!');
//     }

//     // Blood element: Empower (recoil)
//     if (attacker.types.contains('Blood')) {
//       damage = (damage * 1.25).toInt();
//       final recoil = (attacker.maxHp * 0.05).toInt();
//       attacker.takeDamage(recoil);
//       messages.add('${attacker.name} took ${recoil} recoil damage!');
//     }

//     // Deal damage
//     defender.takeDamage(damage);
//     messages.add('${defender.name} took ${damage} damage!');

//     return BattleResult(
//       damage: damage,
//       isCritical: isCritical,
//       typeMultiplier: typeMultiplier,
//       messages: messages,
//       targetDefeated: defender.isDead,
//     );
//   }

//   static BattleResult? _handleSpecialMove(
//     BattleAction action,
//     List<String> messages,
//   ) {
//     final family = action.move.family;
//     final attacker = action.actor;
//     final defender = action.target;

//     switch (family) {
//       case 'Let': // Sprite-strike: Priority move (handled in turn order)
//         return null;

//       case 'Pip': // Pip-fury: Multi-hit 2-3 times
//         final hits = 2 + _random.nextInt(2); // 2-3 hits
//         int totalDamage = 0;

//         for (int i = 0; i < hits; i++) {
//           final hitDamage =
//               (calculateBaseDamage(
//                         move: action.move,
//                         attacker: attacker,
//                         defender: defender,
//                       ) *
//                       0.4)
//                   .toInt();
//           defender.takeDamage(hitDamage);
//           totalDamage += hitDamage;
//         }

//         messages.add('Hit $hits time${hits > 1 ? 's' : ''}!');
//         messages.add('${defender.name} took $totalDamage total damage!');

//         return BattleResult(
//           damage: totalDamage,
//           isCritical: false,
//           typeMultiplier: 1.0,
//           messages: messages,
//           targetDefeated: defender.isDead,
//         );

//       case 'Mane': // Mane's-trick: Lower stat
//         defender.applyStatModifier(
//           StatModifier(type: 'attack_down', duration: 3),
//         );
//         messages.add("${defender.name}'s Attack fell!");
//         return BattleResult(
//           damage: 0,
//           isCritical: false,
//           typeMultiplier: 1.0,
//           messages: messages,
//           targetDefeated: false,
//         );

//       case 'Horn': // Horn-guard: Team shield
//         // TODO: Apply to all team members
//         attacker.shieldHp = (attacker.maxHp * 0.3).toInt();
//         messages.add('${attacker.name} created a protective shield!');
//         return BattleResult(
//           damage: 0,
//           isCritical: false,
//           typeMultiplier: 1.0,
//           messages: messages,
//           targetDefeated: false,
//         );

//       case 'Mask': // Mask's-curse: DoT
//         defender.applyStatusEffect(
//           StatusEffect(
//             type: 'curse',
//             damagePerTurn: (defender.maxHp * 0.1).toInt(),
//             duration: 3,
//           ),
//         );
//         messages.add("${defender.name} was cursed!");
//         return BattleResult(
//           damage: 0,
//           isCritical: false,
//           typeMultiplier: 1.0,
//           messages: messages,
//           targetDefeated: false,
//         );

//       case 'Wing': // Wing-assault: High damage + recharge
//         if (attacker.needsRecharge) {
//           messages.clear();
//           messages.add('${attacker.name} is recharging...');
//           attacker.needsRecharge = false;
//           return BattleResult(
//             damage: 0,
//             isCritical: false,
//             typeMultiplier: 1.0,
//             messages: messages,
//             targetDefeated: false,
//           );
//         }

//         attacker.needsRecharge = true;
//         return null; // Continue with normal attack at 2x damage

//       case 'Kin': // Kin's-blessing: Team heal
//         final healAmount = (attacker.statIntelligence * 3).toInt();
//         attacker.heal(healAmount);
//         messages.add('${attacker.name} healed ${healAmount} HP!');
//         return BattleResult(
//           damage: 0,
//           isCritical: false,
//           typeMultiplier: 1.0,
//           messages: messages,
//           targetDefeated: false,
//         );

//       case 'Mystic': // Mystic-power: Charge then unleash
//         if (!attacker.isCharging) {
//           attacker.isCharging = true;
//           messages.add('${attacker.name} is charging power!');
//           return BattleResult(
//             damage: 0,
//             isCritical: false,
//             typeMultiplier: 1.0,
//             messages: messages,
//             targetDefeated: false,
//           );
//         } else {
//           attacker.isCharging = false;
//           return null; // Continue with 2.5x damage
//         }
//     }

//     return null;
//   }

//   static void _applyElementalEffect(
//     BattleCombatant attacker,
//     BattleCombatant defender,
//     List<String> messages,
//   ) {
//     if (attacker.types.isEmpty) return;

//     final element = attacker.types.first;

//     switch (element) {
//       case 'Fire':
//         defender.applyStatusEffect(
//           StatusEffect(
//             type: 'burn',
//             damagePerTurn: (defender.maxHp * 0.06).toInt(),
//             duration: 3,
//           ),
//         );
//         messages.add('${defender.name} was burned!');
//         break;

//       case 'Poison':
//         defender.applyStatusEffect(
//           StatusEffect(
//             type: 'poison',
//             damagePerTurn: (defender.maxHp * 0.08).toInt(),
//             duration: 3,
//           ),
//         );
//         messages.add('${defender.name} was poisoned!');
//         break;

//       case 'Lava':
//         defender.applyStatModifier(
//           StatModifier(type: 'defense_down', duration: 3),
//         );
//         messages.add("${defender.name}'s Defense fell!");
//         break;

//       case 'Water':
//       case 'Ice':
//       case 'Mud':
//         defender.applyStatModifier(
//           StatModifier(type: 'speed_down', duration: 3),
//         );
//         messages.add("${defender.name}'s Speed fell!");

//         if (element == 'Ice') {
//           defender.applyStatusEffect(
//             StatusEffect(type: 'freeze', damagePerTurn: 0, duration: 2),
//           );
//           messages.add('${defender.name} was frozen!');
//         }
//         break;

//       case 'Earth':
//         attacker.applyStatModifier(
//           StatModifier(type: 'defense_up', duration: 3),
//         );
//         messages.add("${attacker.name}'s Defense rose!");
//         break;

//       case 'Crystal':
//         attacker.shieldHp = (attacker.maxHp * 0.15).toInt();
//         messages.add('${attacker.name} gained a barrier!');
//         break;

//       case 'Plant':
//         attacker.applyStatusEffect(
//           StatusEffect(
//             type: 'regen',
//             damagePerTurn: -(attacker.maxHp * 0.05).toInt(),
//             duration: 3,
//           ),
//         );
//         messages.add('${attacker.name} will regenerate HP!');
//         break;

//       case 'Light':
//         attacker.applyStatModifier(
//           StatModifier(type: 'attack_up', duration: 2),
//         );
//         messages.add("${attacker.name}'s Attack rose!");
//         break;
//     }
//   }

//   /// Process end-of-turn effects (DoT, regen, etc.)
//   static List<String> processEndOfTurnEffects(BattleCombatant combatant) {
//     final messages = <String>[];

//     // Process status effects
//     for (final effect in combatant.statusEffects.values) {
//       if (effect.damagePerTurn > 0) {
//         combatant.takeDamage(effect.damagePerTurn);
//         messages.add(
//           '${combatant.name} took ${effect.damagePerTurn} ${effect.type} damage!',
//         );
//       } else if (effect.damagePerTurn < 0) {
//         final healing = -effect.damagePerTurn;
//         combatant.heal(healing);
//         messages.add('${combatant.name} recovered ${healing} HP!');
//       }
//     }

//     combatant.tickStatusEffects();
//     combatant.tickStatModifiers();

//     return messages;
//   }

//   /// Determine turn order based on speed
//   static List<BattleCombatant> determineTurnOrder(
//     List<BattleCombatant> combatants,
//   ) {
//     final sorted = List<BattleCombatant>.from(combatants);
//     sorted.sort(
//       (a, b) => b.getEffectiveSpeed().compareTo(a.getEffectiveSpeed()),
//     );
//     return sorted;
//   }
// }

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

  // ✅ Convenience: compute sheet/visuals if the optional refs exist
  SpriteSheetDef? get sheetDef {
    final species = speciesRef;
    if (species == null) return null;
    return sheetFromCreature(species);
  }

  SpriteVisuals? get spriteVisuals {
    final species = speciesRef;
    if (species == null) return null;
    // pass instance if you have prismatic/genes there; otherwise null
    return visualsFromInstance(species, instanceRef);
  }

  void _calculateCombatStats() {
    // From StatsFormulas.csv
    maxHp = (level * 10) + (statStrength * 5).toInt();
    physAtk = statStrength.toInt() + (level * 2);
    elemAtk = statIntelligence.toInt() + (level * 2);
    physDef = (statStrength * 0.5 + statBeauty * 0.5).toInt() + level;
    elemDef = statBeauty.toInt() + (level * 2);
    speed = statSpeed.toInt();
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
      statSpeed: instance.statSpeed,
      statIntelligence: instance.statIntelligence,
      statStrength: instance.statStrength,
      statBeauty: instance.statBeauty,
      level: instance.level,
      // 🔹 store for rendering
      instanceRef: instance,
      speciesRef: creature,
    );
  }

  factory BattleCombatant.fromBoss(Boss boss) {
    return BattleCombatant(
        id: boss.id,
        name: boss.name,
        types: [boss.element],
        family: 'Boss',
        statSpeed: boss.spd.toDouble(),
        statIntelligence: 50.0,
        statStrength: 50.0,
        statBeauty: 50.0,
        level: boss.recommendedLevel,
        // instanceRef/speciesRef can be null for bosses if they don’t use the same pipeline
      )
      ..maxHp = boss.hp
      ..currentHp = boss.hp
      ..physAtk = boss.atk
      ..elemAtk = boss.atk
      ..physDef = boss.def
      ..elemDef = boss.def
      ..speed = boss.spd;
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

  void takeDamage(int damage) {
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
  final int damagePerTurn; // or heal per turn if positive
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
    switch (family) {
      case 'Let':
        return const BattleMove(
          name: 'Sprite-strike',
          type: MoveType.physical,
          scalingStat: 'statSpeed',
          isSpecial: true,
          family: 'Let',
        );
      case 'Pip':
        return const BattleMove(
          name: 'Pip-fury',
          type: MoveType.physical,
          scalingStat: 'statStrength',
          isSpecial: true,
          family: 'Pip',
        );
      case 'Mane':
        return const BattleMove(
          name: "Mane's-trick",
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
          isSpecial: true,
          family: 'Mane',
        );
      case 'Horn':
        return const BattleMove(
          name: 'Horn-guard',
          type: MoveType.physical,
          scalingStat: 'statStrength',
          isSpecial: true,
          family: 'Horn',
        );
      case 'Mask':
        return const BattleMove(
          name: "Mask's-curse",
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
          isSpecial: true,
          family: 'Mask',
        );
      case 'Wing':
        return const BattleMove(
          name: 'Wing-assault',
          type: MoveType.physical,
          scalingStat: 'statSpeed',
          isSpecial: true,
          family: 'Wing',
        );
      case 'Kin':
        return const BattleMove(
          name: "Kin's-blessing",
          type: MoveType.elemental,
          scalingStat: 'statIntelligence',
          isSpecial: true,
          family: 'Kin',
        );
      case 'Mystic':
        return const BattleMove(
          name: 'Mystic-power',
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
    final messages = <String>[];
    int damage = 0;
    bool isCritical = false;
    double typeMultiplier = 1.0;

    final attacker = action.actor;
    final defender = action.target;
    final move = action.move;

    messages.add('${attacker.name} used ${move.name}!');

    // Check if frozen (30% chance to skip turn)
    if (attacker.statusEffects.containsKey('freeze')) {
      if (_random.nextDouble() < 0.3) {
        messages.add('${attacker.name} is frozen solid!');
        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );
      }
    }

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
    bool isLightning = attacker.types.contains('Lightning');
    double critChance = isLightning ? 0.25 : 0.05;

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
      messages.add('${attacker.name} drained ${heal} HP!');
    }

    // Blood element: Empower (recoil)
    if (attacker.types.contains('Blood')) {
      damage = (damage * 1.25).toInt();
      final recoil = (attacker.maxHp * 0.05).toInt();
      attacker.takeDamage(recoil);
      messages.add('${attacker.name} took ${recoil} recoil damage!');
    }

    // Deal damage
    defender.takeDamage(damage);
    messages.add('${defender.name} took ${damage} damage!');

    return BattleResult(
      damage: damage,
      isCritical: isCritical,
      typeMultiplier: typeMultiplier,
      messages: messages,
      targetDefeated: defender.isDead,
    );
  }

  static BattleResult? _handleSpecialMove(
    BattleAction action,
    List<String> messages,
  ) {
    final family = action.move.family;
    final attacker = action.actor;
    final defender = action.target;

    switch (family) {
      case 'Let': // Sprite-strike: Priority move (handled in turn order)
        return null;

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

      case 'Mane': // Mane's-trick: Lower stat
        defender.applyStatModifier(
          StatModifier(type: 'attack_down', duration: 3),
        );
        messages.add("${defender.name}'s Attack fell!");
        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );

      case 'Horn': // Horn-guard: Team shield
        // TODO: Apply to all team members
        attacker.shieldHp = (attacker.maxHp * 0.3).toInt();
        messages.add('${attacker.name} created a protective shield!');
        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );

      case 'Mask': // Mask's-curse: DoT
        defender.applyStatusEffect(
          StatusEffect(
            type: 'curse',
            damagePerTurn: (defender.maxHp * 0.1).toInt(),
            duration: 3,
          ),
        );
        messages.add("${defender.name} was cursed!");
        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );

      case 'Wing': // Wing-assault: High damage + recharge
        if (attacker.needsRecharge) {
          messages.clear();
          messages.add('${attacker.name} is recharging...');
          attacker.needsRecharge = false;
          return BattleResult(
            damage: 0,
            isCritical: false,
            typeMultiplier: 1.0,
            messages: messages,
            targetDefeated: false,
          );
        }

        attacker.needsRecharge = true;
        return null; // Continue with normal attack at 2x damage

      case 'Kin': // Kin's-blessing: Team heal
        final healAmount = (attacker.statIntelligence * 3).toInt();
        attacker.heal(healAmount);
        messages.add('${attacker.name} healed ${healAmount} HP!');
        return BattleResult(
          damage: 0,
          isCritical: false,
          typeMultiplier: 1.0,
          messages: messages,
          targetDefeated: false,
        );

      case 'Mystic': // Mystic-power: Charge then unleash
        if (!attacker.isCharging) {
          attacker.isCharging = true;
          messages.add('${attacker.name} is charging power!');
          return BattleResult(
            damage: 0,
            isCritical: false,
            typeMultiplier: 1.0,
            messages: messages,
            targetDefeated: false,
          );
        } else {
          attacker.isCharging = false;
          return null; // Continue with 2.5x damage
        }
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

    switch (element) {
      case 'Fire':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'burn',
            damagePerTurn: (defender.maxHp * 0.06).toInt(),
            duration: 3,
          ),
        );
        messages.add('${defender.name} was burned!');
        break;

      case 'Poison':
        defender.applyStatusEffect(
          StatusEffect(
            type: 'poison',
            damagePerTurn: (defender.maxHp * 0.08).toInt(),
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
        messages.add('${combatant.name} recovered ${healing} HP!');
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
