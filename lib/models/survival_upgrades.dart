// lib/models/survival_upgrades.dart
//
// Persistent survival upgrade data model.
// Stores orb base selection, guardian stat upgrades, and base ability levels.
// Persisted via Settings DAO key-value store.

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ORB BASE SKINS
// ─────────────────────────────────────────────────────────────────────────────

enum OrbBaseSkin {
  defaultOrb,
  voidforgeOrb,
  celestialOrb,
  infernalOrb,
  frozenNexusOrb,
  phantomWispOrb,
  prismHeartOrb,
  verdantBloomOrb,
}

class OrbBaseDef {
  final OrbBaseSkin skin;
  final String name;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final Color glowColor;
  final int cost; // gold
  final String shopId;

  const OrbBaseDef({
    required this.skin,
    required this.name,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.glowColor,
    required this.cost,
    required this.shopId,
  });

  /// Base HP bonus multiplier for this orb skin.
  double get hpMultiplier {
    switch (skin) {
      case OrbBaseSkin.defaultOrb:
        return 1.0;
      case OrbBaseSkin.voidforgeOrb:
        return 1.0;
      case OrbBaseSkin.celestialOrb:
        return 1.0;
      case OrbBaseSkin.infernalOrb:
        return 1.0;
      case OrbBaseSkin.frozenNexusOrb:
        return 1.0;
      case OrbBaseSkin.phantomWispOrb:
        return 1.0;
      case OrbBaseSkin.prismHeartOrb:
        return 1.0;
      case OrbBaseSkin.verdantBloomOrb:
        return 1.0;
    }
  }
}

const List<OrbBaseDef> kOrbBases = [
  OrbBaseDef(
    skin: OrbBaseSkin.defaultOrb,
    name: 'Standard Orb',
    description: 'The default alchemy orb. Reliable and balanced.',
    icon: Icons.blur_circular_rounded,
    primaryColor: Color(0xFF00BCD4),
    secondaryColor: Color(0xFF3F51B5),
    glowColor: Color(0xFF00E5FF),
    cost: 0,
    shopId: 'survival.orb.default',
  ),
  OrbBaseDef(
    skin: OrbBaseSkin.voidforgeOrb,
    name: 'Voidforge Core',
    description:
        'Forged in the Void — an orb crackling with dark energy runes.',
    icon: Icons.nightlight_round,
    primaryColor: Color(0xFF6A0DAD),
    secondaryColor: Color(0xFF1A0033),
    glowColor: Color(0xFFBB00FF),
    cost: 200,
    shopId: 'survival.orb.voidforge',
  ),
  OrbBaseDef(
    skin: OrbBaseSkin.celestialOrb,
    name: 'Celestial Beacon',
    description: 'A radiant sphere of starlight — pulsing with cosmic power.',
    icon: Icons.auto_awesome_rounded,
    primaryColor: Color(0xFFFFD700),
    secondaryColor: Color(0xFFFF8C00),
    glowColor: Color(0xFFFFF176),
    cost: 200,
    shopId: 'survival.orb.celestial',
  ),
  OrbBaseDef(
    skin: OrbBaseSkin.infernalOrb,
    name: 'Infernal Engine',
    description:
        'Molten iron and dragonfire — enemies take burn damage near the orb.',
    icon: Icons.local_fire_department_rounded,
    primaryColor: Color(0xFFFF4500),
    secondaryColor: Color(0xFF8B0000),
    glowColor: Color(0xFFFF6347),
    cost: 200,
    shopId: 'survival.orb.infernal',
  ),
  OrbBaseDef(
    skin: OrbBaseSkin.frozenNexusOrb,
    name: 'Frozen Nexus',
    description:
        'An ancient ice crystal — jagged frost shards orbit its frozen core.',
    icon: Icons.ac_unit_rounded,
    primaryColor: Color(0xFF88DDFF),
    secondaryColor: Color(0xFF1A3A5C),
    glowColor: Color(0xFFB0EAFF),
    cost: 300,
    shopId: 'survival.orb.frozen',
  ),
  OrbBaseDef(
    skin: OrbBaseSkin.phantomWispOrb,
    name: 'Phantom Wisp',
    description:
        'A ghostly sphere that phases between realms — flickering and ethereal.',
    icon: Icons.blur_on_rounded,
    primaryColor: Color(0xFF7BFFCE),
    secondaryColor: Color(0xFF0A2A2A),
    glowColor: Color(0xFF50FFB0),
    cost: 300,
    shopId: 'survival.orb.phantom',
  ),
  OrbBaseDef(
    skin: OrbBaseSkin.prismHeartOrb,
    name: 'Prism Heart',
    description:
        'A crystalline prism refracting all light — shifts through every color.',
    icon: Icons.diamond_rounded,
    primaryColor: Color(0xFFFF69B4),
    secondaryColor: Color(0xFF4400AA),
    glowColor: Color(0xFFFFFFFF),
    cost: 400,
    shopId: 'survival.orb.prism',
  ),
  OrbBaseDef(
    skin: OrbBaseSkin.verdantBloomOrb,
    name: 'Verdant Bloom',
    description:
        'A living orb of tangled vines and blossoms — pulses with nature\'s rhythm.',
    icon: Icons.eco_rounded,
    primaryColor: Color(0xFF32CD32),
    secondaryColor: Color(0xFF0B3D0B),
    glowColor: Color(0xFF7FFF00),
    cost: 300,
    shopId: 'survival.orb.verdant',
  ),
];

OrbBaseDef getOrbBaseDef(OrbBaseSkin skin) {
  return kOrbBases.firstWhere((d) => d.skin == skin);
}

// ─────────────────────────────────────────────────────────────────────────────
// GUARDIAN STAT UPGRADES (5 levels each)
// ─────────────────────────────────────────────────────────────────────────────

enum GuardianUpgrade { cooldown, defense, attack, critChance, range }

class GuardianUpgradeDef {
  final GuardianUpgrade upgrade;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int maxLevel;
  final List<int> costPerLevel; // gold cost at each level
  final List<double> valuePerLevel; // bonus value at each level

  const GuardianUpgradeDef({
    required this.upgrade,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.maxLevel = 5,
    required this.costPerLevel,
    required this.valuePerLevel,
  });

  String bonusLabel(int level) {
    if (level == 0) return '—';
    final v = valuePerLevel[level - 1];
    switch (upgrade) {
      case GuardianUpgrade.cooldown:
        return '-${(v * 100).toStringAsFixed(0)}%';
      case GuardianUpgrade.defense:
        return '+${(v * 100).toStringAsFixed(0)}%';
      case GuardianUpgrade.attack:
        return '+${(v * 100).toStringAsFixed(0)}%';
      case GuardianUpgrade.critChance:
        return '+${(v * 100).toStringAsFixed(0)}%';
      case GuardianUpgrade.range:
        return '+${(v * 100).toStringAsFixed(0)}%';
    }
  }
}

const List<GuardianUpgradeDef> kGuardianUpgrades = [
  GuardianUpgradeDef(
    upgrade: GuardianUpgrade.cooldown,
    name: 'Swift Alchemy',
    description: 'Reduces all guardian attack cooldowns.',
    icon: Icons.speed_rounded,
    color: Color(0xFF0EA5E9),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    valuePerLevel: [0.03, 0.06, 0.10, 0.15, 0.20],
  ),
  GuardianUpgradeDef(
    upgrade: GuardianUpgrade.defense,
    name: 'Fortified Shell',
    description: 'Increases all guardian physical and elemental defense.',
    icon: Icons.shield_rounded,
    color: Color(0xFF22C55E),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    valuePerLevel: [0.05, 0.10, 0.16, 0.22, 0.30],
  ),
  GuardianUpgradeDef(
    upgrade: GuardianUpgrade.attack,
    name: 'Empowered Strikes',
    description: 'Boosts all guardian attack damage.',
    icon: Icons.keyboard_double_arrow_up_rounded,
    color: Color(0xFFEF4444),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    valuePerLevel: [0.04, 0.08, 0.14, 0.20, 0.28],
  ),
  GuardianUpgradeDef(
    upgrade: GuardianUpgrade.critChance,
    name: 'Precision Runes',
    description: 'Increases guardian critical hit chance.',
    icon: Icons.gps_fixed_rounded,
    color: Color(0xFFF59E0B),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    valuePerLevel: [0.02, 0.04, 0.07, 0.10, 0.15],
  ),
  GuardianUpgradeDef(
    upgrade: GuardianUpgrade.range,
    name: 'Extended Reach',
    description: 'Extends guardian attack and ability range.',
    icon: Icons.radar_rounded,
    color: Color(0xFFA855F7),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    valuePerLevel: [0.03, 0.06, 0.10, 0.16, 0.22],
  ),
];

GuardianUpgradeDef getGuardianUpgradeDef(GuardianUpgrade u) {
  return kGuardianUpgrades.firstWhere((d) => d.upgrade == u);
}

// ─────────────────────────────────────────────────────────────────────────────
// BASE ABILITIES (5 levels each)
// ─────────────────────────────────────────────────────────────────────────────

enum BaseAbility { health, detonation, turret, shieldPulse, healingAura }

class BaseAbilityDef {
  final BaseAbility ability;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int maxLevel;
  final List<int> costPerLevel;
  final List<String> levelDescriptions;

  const BaseAbilityDef({
    required this.ability,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.maxLevel = 5,
    required this.costPerLevel,
    required this.levelDescriptions,
  });
}

const List<BaseAbilityDef> kBaseAbilities = [
  BaseAbilityDef(
    ability: BaseAbility.health,
    name: 'Reinforced Core',
    description: 'Increases the orb\'s maximum HP.',
    icon: Icons.favorite_rounded,
    color: Color(0xFFEF4444),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    levelDescriptions: [
      '+50 HP (450)',
      '+120 HP (520)',
      '+200 HP (600)',
      '+300 HP (700)',
      '+420 HP (820)',
    ],
  ),
  BaseAbilityDef(
    ability: BaseAbility.detonation,
    name: 'Nova Detonation',
    description:
        'A detonation button appears — tap to blast all enemies on screen.',
    icon: Icons.offline_bolt_rounded,
    color: Color(0xFFFF6B35),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    levelDescriptions: [
      '100 damage, 120s cooldown',
      '180 damage, 105s cooldown',
      '280 damage, 90s cooldown',
      '400 damage, 75s cooldown',
      '550 damage, 60s cooldown',
    ],
  ),
  BaseAbilityDef(
    ability: BaseAbility.turret,
    name: 'Auto-Turret',
    description:
        'Mounts a rapid-fire turret on the orb that shoots the nearest enemy.',
    icon: Icons.gps_fixed_rounded,
    color: Color(0xFF3B82F6),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    levelDescriptions: [
      '5 dmg/shot, 0.6s fire rate',
      '9 dmg/shot, 0.5s fire rate',
      '14 dmg/shot, 0.4s fire rate',
      '20 dmg/shot, 0.35s fire rate',
      '28 dmg/shot, 0.3s fire rate',
    ],
  ),
  BaseAbilityDef(
    ability: BaseAbility.shieldPulse,
    name: 'Shield Pulse',
    description:
        'Periodically emits a shockwave that pushes enemies back and stuns briefly.',
    icon: Icons.security_rounded,
    color: Color(0xFF06B6D4),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    levelDescriptions: [
      'Pushback every 25s, 0.5s stun',
      'Pushback every 22s, 0.8s stun',
      'Pushback every 19s, 1.2s stun',
      'Pushback every 16s, 1.5s stun',
      'Pushback every 13s, 2.0s stun',
    ],
  ),
  BaseAbilityDef(
    ability: BaseAbility.healingAura,
    name: 'Regeneration Field',
    description: 'The orb slowly regenerates its own HP over time.',
    icon: Icons.spa_rounded,
    color: Color(0xFF10B981),
    costPerLevel: [1000, 5000, 10000, 20000, 50000],
    levelDescriptions: ['+1 HP/s', '+3 HP/s', '+5 HP/s', '+8 HP/s', '+12 HP/s'],
  ),
];

BaseAbilityDef getBaseAbilityDef(BaseAbility a) {
  return kBaseAbilities.firstWhere((d) => d.ability == a);
}

// ─────────────────────────────────────────────────────────────────────────────
// COMBINED UPGRADE STATE
// ─────────────────────────────────────────────────────────────────────────────

class SurvivalUpgradeState {
  OrbBaseSkin equippedSkin;
  Set<OrbBaseSkin> ownedSkins;
  Map<GuardianUpgrade, int> guardianLevels;
  Map<BaseAbility, int> abilityLevels;

  SurvivalUpgradeState({
    this.equippedSkin = OrbBaseSkin.defaultOrb,
    Set<OrbBaseSkin>? ownedSkins,
    Map<GuardianUpgrade, int>? guardianLevels,
    Map<BaseAbility, int>? abilityLevels,
  }) : ownedSkins = ownedSkins ?? {OrbBaseSkin.defaultOrb},
       guardianLevels =
           guardianLevels ?? {for (final u in GuardianUpgrade.values) u: 0},
       abilityLevels =
           abilityLevels ?? {for (final a in BaseAbility.values) a: 0};

  int getGuardianLevel(GuardianUpgrade u) => guardianLevels[u] ?? 0;
  int getAbilityLevel(BaseAbility a) => abilityLevels[a] ?? 0;

  /// Total extra HP from the Reinforced Core ability.
  int get bonusOrbHp {
    final level = getAbilityLevel(BaseAbility.health);
    if (level <= 0) return 0;
    const hpBonus = [50, 120, 200, 300, 420];
    return hpBonus[(level - 1).clamp(0, 4)];
  }

  /// Detonation damage at current level (0 = disabled).
  int get detonationDamage {
    final level = getAbilityLevel(BaseAbility.detonation);
    if (level <= 0) return 0;
    const dmg = [100, 180, 280, 400, 550];
    return dmg[(level - 1).clamp(0, 4)];
  }

  /// Detonation cooldown in seconds.
  double get detonationCooldown {
    final level = getAbilityLevel(BaseAbility.detonation);
    if (level <= 0) return double.infinity;
    const cd = [120.0, 105.0, 90.0, 75.0, 60.0];
    return cd[(level - 1).clamp(0, 4)];
  }

  /// Turret damage per shot.
  int get turretDamage {
    final level = getAbilityLevel(BaseAbility.turret);
    if (level <= 0) return 0;
    const dmg = [5, 9, 14, 20, 28];
    return dmg[(level - 1).clamp(0, 4)];
  }

  /// Turret fire rate (seconds between shots).
  double get turretFireRate {
    final level = getAbilityLevel(BaseAbility.turret);
    if (level <= 0) return double.infinity;
    const rate = [0.6, 0.5, 0.4, 0.35, 0.3];
    return rate[(level - 1).clamp(0, 4)];
  }

  /// Shield pushback interval in seconds.
  double get shieldPulseInterval {
    final level = getAbilityLevel(BaseAbility.shieldPulse);
    if (level <= 0) return double.infinity;
    const interval = [25.0, 22.0, 19.0, 16.0, 13.0];
    return interval[(level - 1).clamp(0, 4)];
  }

  /// Shield stun duration in seconds.
  double get shieldStunDuration {
    final level = getAbilityLevel(BaseAbility.shieldPulse);
    if (level <= 0) return 0;
    const stun = [0.5, 0.8, 1.2, 1.5, 2.0];
    return stun[(level - 1).clamp(0, 4)];
  }

  /// Healing aura HP per second.
  double get healingPerSecond {
    final level = getAbilityLevel(BaseAbility.healingAura);
    if (level <= 0) return 0;
    const hps = [1.0, 3.0, 5.0, 8.0, 12.0];
    return hps[(level - 1).clamp(0, 4)];
  }

  /// Guardian cooldown reduction multiplier (applied on top of base CDR).
  double get guardianCDRBonus {
    final level = getGuardianLevel(GuardianUpgrade.cooldown);
    if (level <= 0) return 0;
    return kGuardianUpgrades
        .firstWhere((d) => d.upgrade == GuardianUpgrade.cooldown)
        .valuePerLevel[level - 1];
  }

  double get guardianDefenseBonus {
    final level = getGuardianLevel(GuardianUpgrade.defense);
    if (level <= 0) return 0;
    return kGuardianUpgrades
        .firstWhere((d) => d.upgrade == GuardianUpgrade.defense)
        .valuePerLevel[level - 1];
  }

  double get guardianAttackBonus {
    final level = getGuardianLevel(GuardianUpgrade.attack);
    if (level <= 0) return 0;
    return kGuardianUpgrades
        .firstWhere((d) => d.upgrade == GuardianUpgrade.attack)
        .valuePerLevel[level - 1];
  }

  double get guardianCritBonus {
    final level = getGuardianLevel(GuardianUpgrade.critChance);
    if (level <= 0) return 0;
    return kGuardianUpgrades
        .firstWhere((d) => d.upgrade == GuardianUpgrade.critChance)
        .valuePerLevel[level - 1];
  }

  double get guardianRangeBonus {
    final level = getGuardianLevel(GuardianUpgrade.range);
    if (level <= 0) return 0;
    return kGuardianUpgrades
        .firstWhere((d) => d.upgrade == GuardianUpgrade.range)
        .valuePerLevel[level - 1];
  }
}
