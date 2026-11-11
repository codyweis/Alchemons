// lib/models/survival_upgrades.dart
//
// Persistent survival upgrade data model.
// Stores orb base selection, the five Specials, and base ability levels.
// Persisted via Settings DAO key-value store.

import 'package:flutter/material.dart';
import 'package:alchemons/widgets/app_icons.dart';

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
  final String ability;
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
    required this.ability,
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
        return 0.90; // glass cannon trade-off
      case OrbBaseSkin.celestialOrb:
        return 1.0;
      case OrbBaseSkin.infernalOrb:
        return 1.0;
      case OrbBaseSkin.frozenNexusOrb:
        return 1.05;
      case OrbBaseSkin.phantomWispOrb:
        return 0.95;
      case OrbBaseSkin.prismHeartOrb:
        return 1.10;
      case OrbBaseSkin.verdantBloomOrb:
        return 1.15; // tankiest orb
    }
  }
}

const List<OrbBaseDef> kOrbBases = [
  OrbBaseDef(
    skin: OrbBaseSkin.defaultOrb,
    name: 'Standard Orb',
    description: 'The default alchemy orb. Reliable and balanced.',
    ability: 'No special ability.',
    icon: AppIcons.blur_circular_rounded,
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
    ability: '+12% guardian damage · −10% orb HP',
    icon: AppIcons.nightlight_round,
    primaryColor: Color(0xFF6A0DAD),
    secondaryColor: Color(0xFF1A0033),
    glowColor: Color(0xFFBB00FF),
    cost: 25,
    shopId: 'survival.orb.voidforge',
  ),
  OrbBaseDef(
    skin: OrbBaseSkin.celestialOrb,
    name: 'Celestial Beacon',
    description: 'A radiant sphere of starlight — pulsing with cosmic power.',
    ability: 'Heals guardians & ship 3% every 8s',
    icon: AppIcons.auto_awesome_rounded,
    primaryColor: Color(0xFFFFD700),
    secondaryColor: Color(0xFFFF8C00),
    glowColor: Color(0xFFFFF176),
    cost: 25,
    shopId: 'survival.orb.celestial',
  ),
  OrbBaseDef(
    skin: OrbBaseSkin.infernalOrb,
    name: 'Infernal Engine',
    description:
        'Molten iron and dragonfire — enemies take burn damage near the orb.',
    ability: 'Burn aura deals damage to nearby enemies every 0.5s',
    icon: AppIcons.local_fire_department_rounded,
    primaryColor: Color(0xFFFF4500),
    secondaryColor: Color(0xFF8B0000),
    glowColor: Color(0xFFFF6347),
    cost: 25,
    shopId: 'survival.orb.infernal',
  ),
  OrbBaseDef(
    skin: OrbBaseSkin.frozenNexusOrb,
    name: 'Frozen Nexus',
    description:
        'An ancient ice crystal — jagged frost shards orbit its frozen core.',
    ability: 'Slows enemies near the orb · +5% orb HP',
    icon: AppIcons.ac_unit_rounded,
    primaryColor: Color(0xFF88DDFF),
    secondaryColor: Color(0xFF1A3A5C),
    glowColor: Color(0xFFB0EAFF),
    cost: 50,
    shopId: 'survival.orb.frozen',
  ),
  OrbBaseDef(
    skin: OrbBaseSkin.phantomWispOrb,
    name: 'Phantom Wisp',
    description:
        'A ghostly sphere that phases between realms — flickering and ethereal.',
    ability: '10% chance to dodge enemy projectiles · −5% orb HP',
    icon: AppIcons.blur_on_rounded,
    primaryColor: Color(0xFF7BFFCE),
    secondaryColor: Color(0xFF0A2A2A),
    glowColor: Color(0xFF50FFB0),
    cost: 50,
    shopId: 'survival.orb.phantom',
  ),
  OrbBaseDef(
    skin: OrbBaseSkin.prismHeartOrb,
    name: 'Prism Heart',
    description:
        'A crystalline prism refracting all light — shifts through every color.',
    ability: '+10% orb HP · passive regen +0.3 HP/s',
    icon: AppIcons.diamond_rounded,
    primaryColor: Color(0xFFFF69B4),
    secondaryColor: Color(0xFF4400AA),
    glowColor: Color(0xFFFFFFFF),
    cost: 75,
    shopId: 'survival.orb.prism',
  ),
  OrbBaseDef(
    skin: OrbBaseSkin.verdantBloomOrb,
    name: 'Verdant Bloom',
    description:
        'A living orb of tangled vines and blossoms — pulses with nature\'s rhythm.',
    ability: '+15% orb HP · passive regen +1 HP/s',
    icon: AppIcons.eco_rounded,
    primaryColor: Color(0xFF32CD32),
    secondaryColor: Color(0xFF0B3D0B),
    glowColor: Color(0xFF7FFF00),
    cost: 75,
    shopId: 'survival.orb.verdant',
  ),
];

OrbBaseDef getOrbBaseDef(OrbBaseSkin skin) {
  return kOrbBases.firstWhere((d) => d.skin == skin);
}

// ─────────────────────────────────────────────────────────────────────────────
// SPECIALS (bought once, with silver, kept for good)
// ─────────────────────────────────────────────────────────────────────────────
//
// Five permanent upgrades, each owned or not. They took the place of the
// Guardian stat upgrades (cooldown, defense, attack, range) on 2026-11-11.
// What each one does in a run lives with the run: PowerUpState reads the
// ship's damage and fire rate, Autopilot and the extra draft keys, and
// CosmicSurvivalGame the ship's speed and its shield. The numbers are here so
// the card, the lobby and the run all say the same thing.

enum SurvivalSpecial {
  autopilot,
  shipOverhaul,
  shipSpeed,
  shipShield,
  refreshBanish,
}

/// What each Special costs, in silver.
const int kSurvivalSpecialCost = 100000;

/// Ship Overhaul: the ship's damage, and how fast it fires, are each
/// multiplied by this.
const double kShipOverhaulDamage = 5.0;
const double kShipOverhaulFireRate = 5.0;

/// Ship Speed: the ship's flying speed is multiplied by this.
const double kShipSpeedBoost = 3.0;

/// Ship Shield: what it holds, as a share of the ship's hull, and how many
/// seconds after it breaks it comes back.
const double kShipShieldHullShare = 1.0;
const double kShipShieldRegenSeconds = 30.0;

/// Refresh & Banish: the keys a run starts with on top of the draft's own.
const int kRefreshBanishRerolls = 1;
const int kRefreshBanishBanishes = 1;

class SurvivalSpecialDef {
  final SurvivalSpecial special;
  final String name;

  /// The lobby's name for it, short enough for a reading.
  final String label;
  final String description;

  /// What the lobby's reading shows once it is owned.
  final String readout;
  final IconData icon;
  final Color color;
  final int cost; // silver

  const SurvivalSpecialDef({
    required this.special,
    required this.name,
    required this.label,
    required this.description,
    required this.readout,
    required this.icon,
    required this.color,
    this.cost = kSurvivalSpecialCost,
  });
}

const List<SurvivalSpecialDef> kSurvivalSpecials = [
  SurvivalSpecialDef(
    special: SurvivalSpecial.autopilot,
    name: 'Autopilot',
    label: 'AUTOPILOT',
    description:
        'When you let go of the ship, it flies out and gathers the surge '
        'grains kills leave behind, then flies back to the core.',
    readout: 'ON',
    icon: AppIcons.navigation_rounded,
    color: Color(0xFF9A7CEB),
  ),
  SurvivalSpecialDef(
    special: SurvivalSpecial.shipOverhaul,
    name: 'Ship Overhaul',
    label: 'OVERHAUL',
    description: 'The ship deals 5× damage and fires 5× as fast.',
    readout: '5×',
    icon: AppIcons.bolt_rounded,
    color: Color(0xFFE0703A),
  ),
  SurvivalSpecialDef(
    special: SurvivalSpecial.shipSpeed,
    name: 'Ship Speed',
    label: 'SPEED',
    description: 'The ship flies 3× as fast.',
    readout: '3×',
    icon: AppIcons.speed_rounded,
    color: Color(0xFF8FC9D6),
  ),
  SurvivalSpecialDef(
    special: SurvivalSpecial.shipShield,
    name: 'Ship Shield',
    label: 'SHIELD',
    description:
        'The ship carries a shield as strong as its hull. When the shield '
        'breaks, it comes back after 30 seconds.',
    readout: 'ON',
    icon: AppIcons.shield_rounded,
    color: Color(0xFFCDB07A),
  ),
  SurvivalSpecialDef(
    special: SurvivalSpecial.refreshBanish,
    name: 'Refresh & Banish',
    label: 'REFRESH',
    description:
        'Every run starts with 1 extra reroll and 1 extra banish for '
        'upgrade drafts.',
    readout: '+1',
    icon: AppIcons.refresh_rounded,
    color: Color(0xFF8FB38A),
  ),
];

SurvivalSpecialDef getSurvivalSpecialDef(SurvivalSpecial s) {
  return kSurvivalSpecials.firstWhere((d) => d.special == s);
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
    icon: AppIcons.favorite_rounded,
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
    icon: AppIcons.offline_bolt_rounded,
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
    icon: AppIcons.gps_fixed_rounded,
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
    icon: AppIcons.security_rounded,
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
    icon: AppIcons.spa_rounded,
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
  Set<SurvivalSpecial> ownedSpecials;
  Map<BaseAbility, int> abilityLevels;

  SurvivalUpgradeState({
    this.equippedSkin = OrbBaseSkin.defaultOrb,
    Set<OrbBaseSkin>? ownedSkins,
    Set<SurvivalSpecial>? ownedSpecials,
    Map<BaseAbility, int>? abilityLevels,
  }) : ownedSkins = ownedSkins ?? {OrbBaseSkin.defaultOrb},
       ownedSpecials = ownedSpecials ?? {},
       abilityLevels =
           abilityLevels ?? {for (final a in BaseAbility.values) a: 0};

  bool ownsSpecial(SurvivalSpecial s) => ownedSpecials.contains(s);
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
}
