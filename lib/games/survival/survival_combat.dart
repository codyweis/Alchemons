// lib/games/survival/survival_combat.dart
import 'dart:math';
import 'package:alchemons/utils/sprite_sheet_def.dart';

/// Minimal stats container for survival mode.
class SurvivalUnit {
  final String id;
  final String name;
  final List<String> types;
  final String family;
  final int level;

  // Base Stats (0.0 - 5.0 range)
  double statSpeed;
  double statIntelligence; // Now: Range & Precision
  double statStrength; // Now: Physical Power & Health
  double statBeauty; // Now: Special Ability Power

  // Derived Combat Stats
  late int maxHp;
  late int currentHp;
  int? shieldHp;

  // Offense
  late int physAtk; // Basic Attacks (Strength)
  late int elemAtk; // Special Abilities (Beauty)

  // Defense
  late int physDef;
  late int elemDef;

  // New Gameplay Mechanics
  late double cooldownReduction; // Speed
  late double critChance; // Intelligence (Precision)
  late double attackRange; // Intelligence (Range)

  Map<String, SurvivalStatusEffect> statusEffects = {};
  Map<String, SurvivalStatModifier> statModifiers = {};

  final SpriteSheetDef? sheetDef;
  final SpriteVisuals? spriteVisuals;

  SurvivalUnit({
    required this.id,
    required this.name,
    required this.types,
    required this.family,
    required this.level,
    required this.statSpeed,
    required this.statIntelligence,
    required this.statStrength,
    required this.statBeauty,
    this.sheetDef,
    this.spriteVisuals,
  }) {
    _applyFamilyFlavor();
    calculateCombatStats();
    currentHp = maxHp;
  }

  void _applyFamilyFlavor() {
    // Re-balanced for new stat roles:
    // Int = Range/Crit, Beauty = Special Power.

    switch (family.toLowerCase()) {
      case 'horn':
        // Frontline tank: High HP/Str, Low Range (Int).
        statStrength += 1.0;
        statIntelligence -= 1.0; // Melee range
        statBeauty += 0.2;
        break;

      case 'wing':
        // Fast Ranged DPS.
        statSpeed += 0.6;
        statIntelligence += 0.4; // High Range
        statBeauty += 0.2; // Decent Special
        statStrength -= 0.3;
        break;

      case 'let':
        // Meteor mage: High Special Power (Beauty).
        statIntelligence += 0.2; // Decent range
        statStrength -= 0.3;
        break;

      case 'pip':
        // Sniper/Skill-shot: High Range/Crit (Int).
        statSpeed += 0.8;
        break;

      case 'mane':
        // AoE Caster: Balance of Range (Int) and Power (Beauty).
        statBeauty += 0.4;
        statIntelligence += 0.3;
        statStrength -= 0.2;
        break;

      case 'kin':
        break;

      case 'mystic':
        break;

      case 'mask':
        break;
    }

    // Clamp so we don't go crazy or negative
    statSpeed = statSpeed.clamp(0.2, 10.0);
    statIntelligence = statIntelligence.clamp(0.2, 10.0);
    statStrength = statStrength.clamp(0.2, 10.0);
    statBeauty = statBeauty.clamp(0.2, 10.0);
  }

  void calculateCombatStats() {
    // Scale 0-5 range to useful integers
    final sSpd = statSpeed * 20;
    final sInt = statIntelligence * 20;
    final sStr = statStrength * 20;
    final sBea = statBeauty * 20;

    // HP: Strength gives bulk
    maxHp = (level * 15 + sStr * 2.0).round();

    // Basic Attacks (Strength)
    physAtk = (sStr * 0.6 + level * 3).round();

    // Special Abilities (Beauty)
    // CHANGED: Now uses Beauty instead of Intelligence
    elemAtk = (sBea * 0.6 + level * 3).round();

    // Defenses
    // Phys Def: Strength (Bulk) + Intelligence (Parry/Read moves)
    physDef = ((sStr + sInt) * 0.2 + level).round();

    // Elem Def: Beauty (Magic Resist) + Intelligence (Mental Fortitude)
    elemDef = ((sBea + sInt) * 0.2 + level).round();

    // --- NEW MECHANICS ---

    // Speed: Reduces cooldowns.
    cooldownReduction = 1.0 + (statSpeed * 0.12);

    // Intelligence: Critical Hit Chance.
    // CHANGED: Moved from Beauty. "Precision" logic.
    // 5.0 Int = ~25% Crit Chance.
    critChance = (statIntelligence / 20.0).clamp(0.0, 0.40);

    // Intelligence: Attack Range.
    // CHANGED: Intelligence directly scales range.
    // 0.2 Int (Dumb) = ~160 Range (Melee)
    // 5.0 Int (Smart) = ~500 Range (Sniper)
    attackRange = 150.0 + (statIntelligence * 70.0);
  }

  bool get isAlive => currentHp > 0;
  bool get isDead => currentHp <= 0;
  double get hpPercent => currentHp / maxHp;

  // --- Effective Stat Getters ---

  int getEffectivePhysAtk() => _applyMods(physAtk, 'attack');
  int getEffectiveElemAtk() => _applyMods(elemAtk, 'attack');
  int getEffectivePhysDef() => _applyMods(physDef, 'defense');
  int getEffectiveElemDef() => _applyMods(elemDef, 'defense');

  int _applyMods(int base, String type) {
    double val = base.toDouble();
    if (statModifiers.containsKey('${type}_up')) val *= 1.5;
    if (statModifiers.containsKey('${type}_down')) val *= 0.75;
    return val.round();
  }

  void takeDamage(int rawDamage) {
    var dmg = rawDamage;

    if (shieldHp != null && shieldHp! > 0) {
      if (shieldHp! >= dmg) {
        shieldHp = shieldHp! - dmg;
        dmg = 0;
      } else {
        dmg -= shieldHp!;
        shieldHp = 0;
      }
    }

    if (dmg <= 0) return;
    currentHp = max(0, currentHp - dmg);
  }

  void heal(int amount) {
    currentHp = min(maxHp, currentHp + amount);
  }

  void applyStatusEffect(SurvivalStatusEffect effect) {
    statusEffects[effect.type] = effect;
  }

  void applyStatModifier(SurvivalStatModifier modifier) {
    statModifiers[modifier.type] = modifier;
  }

  void tickStatusAndModifiers() {
    final toRemoveStatus = <String>[];
    final toRemoveMods = <String>[];

    for (final entry in statusEffects.entries) {
      final effect = entry.value;
      effect.tickDuration();
      if (effect.isExpired) toRemoveStatus.add(entry.key);
    }
    for (final key in toRemoveStatus) statusEffects.remove(key);

    for (final entry in statModifiers.entries) {
      final mod = entry.value;
      mod.tickDuration(1.0);
      if (mod.isExpired) toRemoveMods.add(entry.key);
    }
    for (final key in toRemoveMods) statModifiers.remove(key);
  }
}

// --- Supporting Classes ---

class SurvivalStatusEffect {
  final String type;
  final int damagePerTick;
  double tickAccumulator = 0;
  final double tickInterval;
  int ticksRemaining;

  SurvivalStatusEffect({
    required this.type,
    required this.damagePerTick,
    required this.ticksRemaining,
    this.tickInterval = 1.0,
  });

  void tickDuration() => ticksRemaining--;
  bool get isExpired => ticksRemaining <= 0;
}

class SurvivalStatModifier {
  final String type;
  double remainingSeconds;

  SurvivalStatModifier({required this.type, required this.remainingSeconds});

  void tickDuration(double dt) => remainingSeconds -= dt;
  bool get isExpired => remainingSeconds <= 0;
}

enum SurvivalMoveKind { basic, special }

enum SurvivalDamageKind { physical, elemental }

class SurvivalAttackContext {
  final SurvivalUnit attacker;
  final SurvivalUnit defender;
  final SurvivalDamageKind damageKind;
  final bool isSpecial;

  const SurvivalAttackContext({
    required this.attacker,
    required this.defender,
    required this.damageKind,
    this.isSpecial = false,
  });
}

class SurvivalCombat {
  static final Random _rng = Random();

  // Type Chart
  static const Map<String, List<String>> _typeChart = {
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

  static double _typeMultiplier(String attackType, List<String> defenderTypes) {
    for (final defType in defenderTypes) {
      if (_typeChart[attackType]?.contains(defType) ?? false) return 2.0;
      if (_typeChart[defType]?.contains(attackType) ?? false) return 0.5;
    }
    return 1.0;
  }

  static int computeHitDamage(SurvivalAttackContext ctx) {
    final atkUnit = ctx.attacker;
    final defUnit = ctx.defender;

    // 1. Determine Base Stats
    int rawAtk = ctx.damageKind == SurvivalDamageKind.physical
        ? atkUnit.getEffectivePhysAtk()
        : atkUnit.getEffectiveElemAtk();

    int rawDef = ctx.damageKind == SurvivalDamageKind.physical
        ? defUnit.getEffectivePhysDef()
        : defUnit.getEffectiveElemDef();

    // 2. Damage Formula (Standard % Mitigation)
    // Damage = Attack * (100 / (100 + Defense))
    double damage = rawAtk * (100.0 / (100.0 + rawDef));

    // 3. Type Effectiveness
    if (atkUnit.types.isNotEmpty) {
      final mult = _typeMultiplier(atkUnit.types.first, defUnit.types);
      damage *= mult;
    }

    // 4. Special Ability Bonus
    if (ctx.isSpecial) {
      damage *= 1.5;
    }

    // 5. Critical Hit (Using Intelligence/Precision)
    final isCrit = _rng.nextDouble() < atkUnit.critChance;
    if (isCrit) {
      damage *= 1.5; // 150% Damage on Crit
    }

    // 6. Variance
    damage *= (0.95 + _rng.nextDouble() * 0.1);

    return max(damage.round(), 1);
  }

  static void tickRealtimeStatuses(SurvivalUnit unit, double dt) {
    final toApply = <SurvivalStatusEffect>[];

    for (final effect in unit.statusEffects.values) {
      effect.tickAccumulator += dt;
      while (effect.tickAccumulator >= effect.tickInterval &&
          !effect.isExpired) {
        effect.tickAccumulator -= effect.tickInterval;
        toApply.add(effect);
        effect.tickDuration();
      }
    }

    for (final eff in toApply) {
      if (eff.damagePerTick > 0) {
        unit.takeDamage(eff.damagePerTick);
      } else if (eff.damagePerTick < 0) {
        unit.heal(-eff.damagePerTick);
      }
    }
    unit.tickStatusAndModifiers();
  }
}
