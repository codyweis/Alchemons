// lib/games/survival/survival_combat.dart
import 'dart:math';
import 'package:alchemons/utils/sprite_sheet_def.dart';

class SurvivalRangeProfile {
  final double basicMult;
  final double specialMult;

  const SurvivalRangeProfile({
    required this.basicMult,
    required this.specialMult,
  });
}

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

  late double specialAbilityRange;

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
        statStrength += 0.5;
        statIntelligence -= 0.5; // Melee range
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
        statIntelligence += 0.6;
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

  double _curve(double x) => pow(x / 2.5, 2.4).toDouble();
  void calculateCombatStats() {
    final speedScale = _curve(statSpeed);
    final intScale = _curve(statIntelligence);
    final strScale = _curve(statStrength);
    final beaScale = _curve(statBeauty);

    final sSpd = speedScale * 60;
    final sInt = intScale * 70;
    final sStr = strScale * 80;
    final sBea = beaScale * 80;

    maxHp = (level * 18 + sStr * 2.0).round();

    physAtk = ((sStr * 0.08 + 2) * (level / 5)).round();
    elemAtk = ((sBea * 0.30) * (level / 5)).round();

    physDef = ((sStr + sInt) * 0.20 + level * 0.8).round();
    elemDef = ((sBea + sInt) * 0.20 + level * 0.8).round();

    cooldownReduction = 0.5 + (statSpeed * 0.12);
    critChance = (sStr / 25.0).clamp(0.0, 0.40);

    // --- New, clearer range calculation ---
    final baseRange = 150.0 + statIntelligence * 70.0;

    final profile =
        kFamilyRangeProfiles[family.toLowerCase()] ??
        const SurvivalRangeProfile(basicMult: 1.0, specialMult: 1.0);

    attackRange = baseRange * profile.basicMult;
    specialAbilityRange = baseRange * profile.specialMult;
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

  static const Map<String, double> _statusDamageMultipliers = {
    'Burn': 1.8, // +80% burn damage
    'Poison': 2.2, // +120% poison damage
    // Add more if you create new status types
  };
  static double _getStatusDamageMult(SurvivalStatusEffect eff) {
    return _statusDamageMultipliers[eff.type] ?? 1.0;
  }

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

  static int computeHitDamage(SurvivalAttackContext ctx, {bool debug = false}) {
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
    final baseDamage = damage;

    // 3. Type Effectiveness
    double typeMult = 1.0;
    if (atkUnit.types.isNotEmpty) {
      typeMult = _typeMultiplier(atkUnit.types.first, defUnit.types);
      damage *= typeMult;
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
    final varianceMult = 0.95 + _rng.nextDouble() * 0.1;
    damage *= varianceMult;

    final finalDamage = max(damage.round(), 1);

    // DEBUG OUTPUT
    if (debug) {
      print('═══════════════════════════════════════════════════');
      print('⚔️  DAMAGE CALC: ${atkUnit.name} → ${defUnit.name}');
      print('───────────────────────────────────────────────────');
      print(
        '   Attacker: Lv${atkUnit.level} ${atkUnit.family} | Types: ${atkUnit.types}',
      );
      print(
        '   Defender: Lv${defUnit.level} ${defUnit.family} | Types: ${defUnit.types}',
      );
      print('   Defender HP: ${defUnit.currentHp}/${defUnit.maxHp}');
      print('───────────────────────────────────────────────────');
      print(
        '   Damage Kind: ${ctx.damageKind.name} | isSpecial: ${ctx.isSpecial}',
      );
      print('   Raw Atk: $rawAtk | Raw Def: $rawDef');
      print(
        '   Base Damage (after mitigation): ${baseDamage.toStringAsFixed(1)}',
      );
      print('   Type Multiplier: ${typeMult}x');
      print('   Special Bonus: ${ctx.isSpecial ? "1.5x" : "none"}');
      print(
        '   Crit: ${isCrit ? "YES 1.5x" : "no"} (${(atkUnit.critChance * 100).toStringAsFixed(1)}% chance)',
      );
      print('   Variance: ${varianceMult.toStringAsFixed(2)}x');
      print('   ▶ FINAL DAMAGE: $finalDamage');
      if (finalDamage >= defUnit.currentHp) {
        print('   💀 THIS WILL KILL THE DEFENDER!');
      }
      print('═══════════════════════════════════════════════════');
    }

    return finalDamage;
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
      final mult = _getStatusDamageMult(eff);
      final scaled = (eff.damagePerTick * mult).round();

      if (scaled > 0) {
        unit.takeDamage(scaled);
      } else if (scaled < 0) {
        unit.heal(-scaled);
      }
    }

    unit.tickStatusAndModifiers();
  }
}

// Somewhere near the top or in SurvivalCombat as a static const
const Map<String, SurvivalRangeProfile> kFamilyRangeProfiles = {
  // melee frontline
  'horn': SurvivalRangeProfile(basicMult: 0.5, specialMult: 0.8),

  // long-range DPS, special even longer
  'wing': SurvivalRangeProfile(basicMult: 1.0, specialMult: 2.0),

  // mage-ish, same range
  'let': SurvivalRangeProfile(basicMult: 1.8, specialMult: 1.2),

  // barrage caster: base = 1.0, special = 1.5 (longer)
  'mane': SurvivalRangeProfile(basicMult: 1.3, specialMult: 1.9),

  // sniper: same range
  'pip': SurvivalRangeProfile(basicMult: 1.3, specialMult: 1.3),

  // big support range
  'kin': SurvivalRangeProfile(basicMult: 1.3, specialMult: 1.3),

  // utility spells: same
  'mystic': SurvivalRangeProfile(basicMult: 1.3, specialMult: 1.3),

  // traps & ranged harass: same short range
  'mask': SurvivalRangeProfile(basicMult: 0.8, specialMult: 1.3),
};
