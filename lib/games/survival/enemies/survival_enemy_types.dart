// lib/games/survival/survival_enemy_types.dart
import 'dart:math';

import 'package:alchemons/games/survival/scaling_system.dart';
import 'package:alchemons/games/survival/survival_combat.dart';

// ════════════════════════════════════════════════════════════════════════════
// DAMAGE AFFINITY SYSTEM - Makes enemy types feel different
// ════════════════════════════════════════════════════════════════════════════

/// Damage affinities for soft counters
/// Enemies resist some types (67% damage) and are vulnerable to others (150% damage)
enum DamageAffinity {
  physical, // Horn, basic attacks
  magical, // Mask, Mystic
  elemental, // Let, Mane, Wing
  status, // DOT effects (fire, poison, etc)
}

/// Maps guardian families to their primary damage affinity
const Map<String, DamageAffinity> guardianAffinities = {
  'Horn': DamageAffinity.physical,
  'Pip': DamageAffinity.physical,
  'Mask': DamageAffinity.magical,
  'Mystic': DamageAffinity.magical,
  'Kin': DamageAffinity.magical,
  'Let': DamageAffinity.elemental,
  'Mane': DamageAffinity.elemental,
  'Wing': DamageAffinity.elemental,
};

enum EnemyRole { charger, shooter, bomber, leecher }

enum BossArchetype { juggernaut, summoner, artillery, hydra }

/// Creature families (not guardian families)
enum CreatureFamily {
  // Tier 1 - Swarm (Physical blobs - weak to magic)
  gloop,
  skitter,
  wisp,
  mote,
  speck,

  // Tier 2 - Grunt / Brute (Tough - weak to DOT)
  crawler,
  shambler,
  lurker,
  creep,

  // Tier 3 - Elite (Varied)
  ravager,
  stalker,
  howler,
  shade,

  // Tier 4 - Champion / MiniBoss
  brute,
  terror,
  dread,
  blight,

  // Tier 5 - Titan / Boss
  colossus,
  leviathan,
  behemoth,
  apex;

  /// Get resistances for this creature family (takes 67% damage)
  List<DamageAffinity> get resistances {
    switch (this) {
      // Physical blobs - resist physical
      case CreatureFamily.gloop:
      case CreatureFamily.shambler:
      case CreatureFamily.crawler:
        return [DamageAffinity.physical];

      // Ethereal creatures - resist magical/elemental
      case CreatureFamily.wisp:
      case CreatureFamily.shade:
      case CreatureFamily.mote:
        return [DamageAffinity.magical, DamageAffinity.elemental];

      // Armored brutes - resist physical and elemental
      case CreatureFamily.ravager:
      case CreatureFamily.brute:
        return [DamageAffinity.physical, DamageAffinity.elemental];

      // Fast bugs - no resistances (weak to everything)
      case CreatureFamily.skitter:
      case CreatureFamily.stalker:
        return [];

      default:
        return [];
    }
  }

  /// Get vulnerabilities for this creature family (takes 150% damage)
  List<DamageAffinity> get vulnerabilities {
    switch (this) {
      // Physical blobs - vulnerable to magic
      case CreatureFamily.gloop:
      case CreatureFamily.shambler:
      case CreatureFamily.crawler:
        return [DamageAffinity.magical];

      // Ethereal creatures - vulnerable to physical
      case CreatureFamily.wisp:
      case CreatureFamily.shade:
      case CreatureFamily.mote:
        return [DamageAffinity.physical];

      // Armored brutes - vulnerable to status/DOT
      case CreatureFamily.ravager:
      case CreatureFamily.brute:
        return [DamageAffinity.status];

      // Fast bugs - vulnerable to AOE (Mask, Horn)
      case CreatureFamily.skitter:
      case CreatureFamily.stalker:
        return [DamageAffinity.magical]; // Traps work great on fast enemies

      default:
        return [];
    }
  }
}

enum EnemyTier {
  // Tier 1 - fodder / swarm
  swarm(1, 'Swarm', 0.6, 0.6),

  // Tier 2 - "brute" units: fewer, tougher than swarm
  grunt(2, 'Brute', 0.7, 0.7),

  // Tier 3 - elites: small packs, noticeable threat
  elite(3, 'Elite', 0.8, 0.8),

  // Tier 4/5 are reserved for mini-boss/boss scaling, not regular trash
  champion(4, 'MiniBoss', 1.0, 0.9),
  titan(5, 'Boss', 1.4, 1.2);

  final int tier;
  final String name;
  final double statMultiplier;
  final double hpMultiplier;

  const EnemyTier(this.tier, this.name, this.statMultiplier, this.hpMultiplier);
}

/// Calculate damage multiplier based on affinity
/// Returns 0.67 if resistant, 1.5 if vulnerable, 1.0 if neutral
double getAffinityMultiplier(
  DamageAffinity attackAffinity,
  CreatureFamily defenderFamily,
) {
  if (defenderFamily.vulnerabilities.contains(attackAffinity)) {
    return 1.5; // SUPER EFFECTIVE
  }
  if (defenderFamily.resistances.contains(attackAffinity)) {
    return 0.67; // NOT VERY EFFECTIVE
  }
  return 1.0; // NEUTRAL
}

const List<String> allElements = [
  'Fire',
  'Water',
  'Earth',
  'Air',
  'Ice',
  'Lightning',
  'Plant',
  'Poison',
  'Steam',
  'Lava',
  'Mud',
  'Dust',
  'Crystal',
  'Spirit',
  'Dark',
  'Light',
  'Blood',
];

class SurvivalEnemyTemplate {
  final EnemyTier tier;
  final String element;
  final CreatureFamily creatureFamily;

  const SurvivalEnemyTemplate({
    required this.tier,
    required this.element,
    required this.creatureFamily,
  });

  String get name => '${creatureFamily.name.capitalize()} ${element}ling';
  String get id =>
      '${element.toLowerCase()}_${tier.name.toLowerCase()}_${creatureFamily.name}';
  String get family => creatureFamily.name;
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

class SurvivalEnemyCatalog {
  static final Random _rng = Random();
  static final List<SurvivalEnemyTemplate> _allTemplates =
      _generateAllTemplates();

  static List<SurvivalEnemyTemplate> _generateAllTemplates() {
    final templates = <SurvivalEnemyTemplate>[];
    for (final tier in EnemyTier.values) {
      for (final element in allElements) {
        final families = _getFamiliesForTier(tier);
        for (final family in families) {
          templates.add(
            SurvivalEnemyTemplate(
              tier: tier,
              element: element,
              creatureFamily: family,
            ),
          );
        }
      }
    }
    return templates;
  }

  /// Map tiers to visual "families".
  ///  - swarm  = fodder blobs (lots of them)
  ///  - grunt  = "brute" blobs (tougher frontliners)
  ///  - elite  = rare elite packs
  ///  - champion/titan = mini-boss / boss visuals
  static List<CreatureFamily> _getFamiliesForTier(EnemyTier tier) {
    switch (tier) {
      case EnemyTier.swarm:
        return [
          CreatureFamily.gloop,
          CreatureFamily.skitter,
          CreatureFamily.wisp,
          CreatureFamily.mote,
          CreatureFamily.speck,
        ];
      case EnemyTier.grunt:
        return [
          CreatureFamily.crawler,
          CreatureFamily.shambler,
          CreatureFamily.lurker,
          CreatureFamily.creep,
        ];
      case EnemyTier.elite:
        return [
          CreatureFamily.ravager,
          CreatureFamily.stalker,
          CreatureFamily.howler,
          CreatureFamily.shade,
        ];
      case EnemyTier.champion:
        return [
          CreatureFamily.brute,
          CreatureFamily.terror,
          CreatureFamily.dread,
          CreatureFamily.blight,
        ];
      case EnemyTier.titan:
        return [
          CreatureFamily.colossus,
          CreatureFamily.leviathan,
          CreatureFamily.behemoth,
          CreatureFamily.apex,
        ];
    }
  }

  static SurvivalEnemyTemplate? getTemplate(String element, int tierNum) {
    try {
      final tier = EnemyTier.values.firstWhere((t) => t.tier == tierNum);
      return _allTemplates.firstWhere(
        (t) => t.element == element && t.tier == tier,
      );
    } catch (_) {
      return null;
    }
  }

  static SurvivalEnemyTemplate getRandomTemplateForTier(int tierNum) {
    final tier = EnemyTier.values.firstWhere((t) => t.tier == tierNum);
    final tieredTemplates = _allTemplates.where((t) => t.tier == tier).toList();
    return tieredTemplates[_rng.nextInt(tieredTemplates.length)];
  }

  static SurvivalUnit buildEnemy({
    required SurvivalEnemyTemplate template,
    required int tier,
    required int wave,
    bool isShooter = false,
  }) {
    return ImprovedScalingSystem.buildScaledEnemy(
      template: template,
      tier: tier,
      wave: wave,
      isShooter: isShooter,
    );
  }

  static SurvivalUnit buildMiniBoss({
    required SurvivalEnemyTemplate template,
    required int wave,
  }) {
    return ImprovedScalingSystem.buildMiniBoss(template: template, wave: wave);
  }

  static SurvivalUnit buildMegaBoss({
    required SurvivalEnemyTemplate template,
    required int wave,
  }) {
    return ImprovedScalingSystem.buildMegaBoss(template: template, wave: wave);
  }

  /// Build a Hydra boss with scaled stats based on split generation
  static SurvivalUnit buildHydraBoss({
    required SurvivalEnemyTemplate template,
    required int wave,
    required int generation,
  }) {
    // Generation 0 = original (massive), each split reduces stats
    //  baseMult:    1.0 -> 0.45 -> 0.20 -> 0.09 -> 0.04 ...
    final baseMult = pow(0.45, generation).toDouble();
    // Gen 0 gets extra HP to feel like a real “phase 1”
    final hpMult = baseMult * (generation == 0 ? 2.5 : 1.0);

    final baseUnit = ImprovedScalingSystem.buildMegaBoss(
      template: template,
      wave: wave,
    );

    final shardNames = ['Alpha', 'Beta', 'Gamma', 'Delta'];
    final displayName = generation == 0
        ? 'Hydra Primordial'
        : 'Hydra Shard ${shardNames[generation.clamp(0, 3)]}';

    // Start from the same *core* stats as the mega boss
    final unit = SurvivalUnit(
      id: '${template.id}_hydra_g$generation',
      name: displayName,
      types: baseUnit.types,
      family: baseUnit.family,
      level: baseUnit.level,
      statSpeed: baseUnit.statSpeed,
      statIntelligence: baseUnit.statIntelligence,
      statStrength: baseUnit.statStrength,
      statBeauty: baseUnit.statBeauty,
      sheetDef: baseUnit.sheetDef,
      spriteVisuals: baseUnit.spriteVisuals,
    );

    // Scale core stats → then re-derive combat stats
    unit.statStrength *= baseMult;
    unit.statBeauty *= baseMult;
    unit.statSpeed *= (1.0 + generation * 0.15); // smaller = faster
    // We leave statIntelligence alone so its range/crit feel like the base boss

    unit.calculateCombatStats();

    // Now apply Hydra-specific multipliers on derived stats
    unit.maxHp = (unit.maxHp * hpMult).round().clamp(50, 999999); // tanky gen 0
    unit.currentHp = unit.maxHp;

    unit.physAtk = (unit.physAtk * baseMult).round().clamp(5, 9999);
    unit.elemAtk = (unit.elemAtk * baseMult).round().clamp(5, 9999);

    unit.physDef = (unit.physDef * baseMult).round().clamp(1, 9999);
    unit.elemDef = (unit.elemDef * baseMult).round().clamp(1, 9999);

    // Keep the same cooldown reduction curve as the base unit,
    // but you could optionally tweak it per generation if needed:
    unit.cooldownReduction = baseUnit.cooldownReduction;

    return unit;
  }
}
