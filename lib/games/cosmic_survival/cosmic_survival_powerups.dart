import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';

enum PowerUpCategory { statBoost, shipWeapon, orbDefense, rarePerk }

enum PowerUpRarity { common, uncommon, rare, legendary }

enum PowerUpScope { global, companion }

enum PowerUpTag {
  tempo,
  basicAttack,
  specialCast,
  control,
  fortress,
  chainExecute,
  summonOrbit,
  sustain,
}

enum PowerUpStatFocus { speed, strength, beauty, intelligence }

class PowerUpDef {
  final String id;
  final String name;
  final String description;
  final String icon;
  final PowerUpCategory category;
  final PowerUpRarity rarity;
  final PowerUpScope scope;
  final int maxStacks;
  final bool requiresDefeatedTarget;
  final bool ignoresStackLimit;
  final bool showLevel;
  final List<PowerUpTag> tags;
  final List<String> favoredFamilies;
  final List<PowerUpStatFocus> favoredStats;
  final bool isKeystone;

  const PowerUpDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    this.rarity = PowerUpRarity.common,
    this.scope = PowerUpScope.global,
    this.maxStacks = 5,
    this.requiresDefeatedTarget = false,
    this.ignoresStackLimit = false,
    this.showLevel = true,
    this.tags = const [],
    this.favoredFamilies = const [],
    this.favoredStats = const [],
    this.isKeystone = false,
  });
}

const kCompanionStatBoosts = [
  PowerUpDef(
    id: 'attack_boost',
    name: 'Forged Strikes',
    description: '+18% attack for one alchemon',
    icon: '⚔️',
    category: PowerUpCategory.statBoost,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.basicAttack, PowerUpTag.chainExecute],
    favoredFamilies: ['horn', 'mane', 'pip'],
    favoredStats: [PowerUpStatFocus.strength],
  ),
  PowerUpDef(
    id: 'defense_boost',
    name: 'Forgeplate',
    description: '+16% defense for one alchemon',
    icon: '🛡️',
    category: PowerUpCategory.statBoost,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.fortress, PowerUpTag.sustain],
    favoredFamilies: ['horn', 'kin', 'mask', 'mane'],
    favoredStats: [PowerUpStatFocus.strength, PowerUpStatFocus.intelligence],
  ),
  PowerUpDef(
    id: 'speed_boost',
    name: 'Quicksilver Step',
    description: '+14% move speed for one alchemon',
    icon: '💨',
    category: PowerUpCategory.statBoost,
    rarity: PowerUpRarity.uncommon,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.tempo, PowerUpTag.control],
    favoredFamilies: ['pip', 'mask', 'mane', 'wing'],
    favoredStats: [PowerUpStatFocus.speed],
  ),
  PowerUpDef(
    id: 'hp_boost',
    name: 'Vital Ember',
    description: '+22% max HP for one alchemon',
    icon: '❤️',
    category: PowerUpCategory.statBoost,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.fortress, PowerUpTag.sustain],
    favoredFamilies: ['horn', 'kin', 'mane', 'let'],
    favoredStats: [PowerUpStatFocus.strength, PowerUpStatFocus.beauty],
  ),
  PowerUpDef(
    id: 'cooldown_reduction',
    name: 'Chrono Grit',
    description: '-8% cooldown for one alchemon',
    icon: '⏱️',
    category: PowerUpCategory.statBoost,
    rarity: PowerUpRarity.uncommon,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.tempo, PowerUpTag.specialCast, PowerUpTag.control],
    favoredFamilies: ['pip', 'wing', 'kin', 'mystic', 'mask', 'let'],
    favoredStats: [PowerUpStatFocus.speed, PowerUpStatFocus.intelligence],
  ),
];

const kGlobalStatBoosts = [
  PowerUpDef(
    id: 'command_attack',
    name: 'War Banner',
    description: '+6% attack to all alchemons',
    icon: '🚩',
    category: PowerUpCategory.statBoost,
    maxStacks: 3,
    tags: [PowerUpTag.basicAttack, PowerUpTag.specialCast],
    favoredStats: [PowerUpStatFocus.strength, PowerUpStatFocus.beauty],
  ),
  PowerUpDef(
    id: 'command_defense',
    name: 'Bulwark Orders',
    description: '+6% defense to all alchemons',
    icon: '🧱',
    category: PowerUpCategory.statBoost,
    maxStacks: 3,
    tags: [PowerUpTag.fortress, PowerUpTag.sustain],
    favoredStats: [PowerUpStatFocus.strength, PowerUpStatFocus.intelligence],
  ),
  PowerUpDef(
    id: 'orb_vitality',
    name: 'Orb Tempering',
    description: '+10% orb max HP and restore orb durability',
    icon: '🔮',
    category: PowerUpCategory.statBoost,
    rarity: PowerUpRarity.uncommon,
    maxStacks: 3,
    tags: [PowerUpTag.fortress, PowerUpTag.sustain],
    favoredFamilies: ['horn', 'kin', 'mask'],
  ),
];

const kShipWeapons = [
  PowerUpDef(
    id: 'fire_rate',
    name: 'Rapid Cannons',
    description: '+22% ship fire rate',
    icon: '🔫',
    category: PowerUpCategory.shipWeapon,
    maxStacks: 4,
    tags: [PowerUpTag.tempo],
  ),
  PowerUpDef(
    id: 'spread_shot',
    name: 'Spread Shot',
    description: 'Add two extra side shots',
    icon: '🌊',
    category: PowerUpCategory.shipWeapon,
    rarity: PowerUpRarity.uncommon,
    maxStacks: 3,
    tags: [PowerUpTag.basicAttack, PowerUpTag.chainExecute],
  ),
  PowerUpDef(
    id: 'rocket_barrage',
    name: 'Rocket Barrage',
    description: 'Replace shots with homing rockets that explode on impact',
    icon: '🚀',
    category: PowerUpCategory.shipWeapon,
    rarity: PowerUpRarity.rare,
    maxStacks: 3,
    tags: [PowerUpTag.basicAttack],
  ),
  PowerUpDef(
    id: 'ship_damage',
    name: 'Overcharged Cores',
    description: '+18% ship damage',
    icon: '💥',
    category: PowerUpCategory.shipWeapon,
    rarity: PowerUpRarity.uncommon,
    maxStacks: 4,
    tags: [PowerUpTag.basicAttack],
  ),
  PowerUpDef(
    id: 'homing_missiles',
    name: 'Hunter Salvo',
    description: 'Ship shots gain light homing',
    icon: '🎯',
    category: PowerUpCategory.shipWeapon,
    rarity: PowerUpRarity.rare,
    maxStacks: 1,
    tags: [PowerUpTag.control],
  ),
];

const kOrbDefenses = [
  PowerUpDef(
    id: 'shield_pulse',
    name: 'Shield Pulse',
    description: 'Orb pulse knocks enemies back and recharges faster',
    icon: '🔵',
    category: PowerUpCategory.orbDefense,
    rarity: PowerUpRarity.uncommon,
    maxStacks: 3,
    tags: [PowerUpTag.fortress, PowerUpTag.control],
    favoredFamilies: ['horn', 'kin', 'mask'],
  ),
  PowerUpDef(
    id: 'auto_turret',
    name: 'Auto-Turret',
    description: 'Orb turret fires faster, scales into later waves, and hits visibly',
    icon: '🔧',
    category: PowerUpCategory.orbDefense,
    maxStacks: 3,
    tags: [PowerUpTag.fortress],
    favoredFamilies: ['horn', 'kin'],
  ),
  PowerUpDef(
    id: 'regen_field',
    name: 'Regeneration Field',
    description: 'Orb restores more HP each second',
    icon: '💚',
    category: PowerUpCategory.orbDefense,
    maxStacks: 3,
    tags: [PowerUpTag.sustain, PowerUpTag.fortress],
    favoredFamilies: ['kin', 'horn', 'mane'],
  ),
  PowerUpDef(
    id: 'nova_detonation',
    name: 'Nova Detonation',
    description: 'Orb nova deals more damage and charges faster',
    icon: '☀️',
    category: PowerUpCategory.orbDefense,
    rarity: PowerUpRarity.rare,
    maxStacks: 3,
    tags: [PowerUpTag.control, PowerUpTag.specialCast],
  ),
];

const kRarePerks = [
  PowerUpDef(
    id: 'revive_half',
    name: 'Soul Rekindle',
    description: 'Revive one fallen alchemon at 50% HP',
    icon: '💠',
    category: PowerUpCategory.rarePerk,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 1,
    requiresDefeatedTarget: true,
    ignoresStackLimit: true,
    showLevel: false,
    tags: [PowerUpTag.sustain],
    favoredFamilies: ['kin', 'horn', 'mane'],
  ),
  PowerUpDef(
    id: 'pack_leader',
    name: 'Pack Leader',
    description: '+1 active alchemon slot, up to 5',
    icon: '👥',
    category: PowerUpCategory.rarePerk,
    maxStacks: 4,
    tags: [PowerUpTag.fortress, PowerUpTag.summonOrbit],
    favoredFamilies: ['kin', 'horn'],
  ),
  PowerUpDef(
    id: 'lifesteal',
    name: 'Blood Pact',
    description: 'Kills heal the orb for 5% / 8% / 12% of this alchemon max HP',
    icon: '🩸',
    category: PowerUpCategory.rarePerk,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.sustain],
    favoredFamilies: ['horn', 'kin', 'mane'],
    favoredStats: [PowerUpStatFocus.strength, PowerUpStatFocus.beauty],
  ),
  PowerUpDef(
    id: 'time_dilation',
    name: 'Time Dilation',
    description: 'Wave start slow: 10% / 18% / 28% for longer durations',
    icon: '⏳',
    category: PowerUpCategory.rarePerk,
    rarity: PowerUpRarity.rare,
    maxStacks: 3,
    tags: [PowerUpTag.control],
  ),
  PowerUpDef(
    id: 'double_cast',
    name: 'Double Cast',
    description: 'One alchemon echoes its special ability for extra burst',
    icon: '✨',
    category: PowerUpCategory.rarePerk,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 1,
    tags: [PowerUpTag.specialCast],
    favoredFamilies: ['mystic', 'let', 'wing', 'kin'],
    favoredStats: [PowerUpStatFocus.beauty, PowerUpStatFocus.intelligence],
  ),
  PowerUpDef(
    id: 'chain_lightning',
    name: 'Chain Lightning',
    description: 'One alchemon arcs attacks into nearby enemies',
    icon: '⚡',
    category: PowerUpCategory.rarePerk,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 1,
    tags: [PowerUpTag.chainExecute, PowerUpTag.control],
    favoredFamilies: ['pip', 'wing', 'mask'],
    favoredStats: [PowerUpStatFocus.speed, PowerUpStatFocus.intelligence],
  ),
  PowerUpDef(
    id: 'mirror_shield',
    name: 'Mirror Shield',
    description: 'Reduce orb collision damage by 25% and release a retaliatory pulse',
    icon: '🪞',
    category: PowerUpCategory.rarePerk,
    rarity: PowerUpRarity.rare,
    maxStacks: 1,
    tags: [PowerUpTag.fortress],
  ),
  PowerUpDef(
    id: 'berserker',
    name: 'Berserker',
    description: 'Orb under 30% HP doubles your outgoing damage',
    icon: '🔥',
    category: PowerUpCategory.rarePerk,
    rarity: PowerUpRarity.rare,
    maxStacks: 1,
    tags: [PowerUpTag.basicAttack, PowerUpTag.specialCast],
  ),
  PowerUpDef(
    id: 'elemental_fury',
    name: 'Elemental Fury',
    description: 'Kills erupt for escalating elemental splash damage',
    icon: '🌋',
    category: PowerUpCategory.rarePerk,
    rarity: PowerUpRarity.rare,
    maxStacks: 3,
    tags: [PowerUpTag.chainExecute, PowerUpTag.specialCast],
    favoredFamilies: ['pip', 'mystic', 'wing', 'let'],
  ),
  PowerUpDef(
    id: 'phoenix_rebirth',
    name: 'Rebirth',
    description: 'One alchemon revives once at full HP',
    icon: '🦅',
    category: PowerUpCategory.rarePerk,
    rarity: PowerUpRarity.legendary,
    scope: PowerUpScope.companion,
    maxStacks: 1,
    tags: [PowerUpTag.sustain],
    favoredFamilies: ['horn', 'kin', 'mystic'],
  ),
];

const kKeystonePowerUps = [
  PowerUpDef(
    id: 'keystone_bastion_heart',
    name: 'Bastion Heart',
    description:
        'Orb fortress run: heavy orb and guardian scaling for defense cores',
    icon: '🏛️',
    category: PowerUpCategory.rarePerk,
    rarity: PowerUpRarity.legendary,
    maxStacks: 1,
    showLevel: false,
    isKeystone: true,
    tags: [PowerUpTag.fortress, PowerUpTag.sustain],
    favoredFamilies: ['horn', 'kin', 'mask'],
    favoredStats: [PowerUpStatFocus.strength, PowerUpStatFocus.intelligence],
  ),
  PowerUpDef(
    id: 'keystone_chrono_surge',
    name: 'Chrono Surge',
    description:
        'Tempo run: faster companions, faster casts, faster ship pressure',
    icon: '🕰️',
    category: PowerUpCategory.rarePerk,
    rarity: PowerUpRarity.legendary,
    maxStacks: 1,
    showLevel: false,
    isKeystone: true,
    tags: [PowerUpTag.tempo, PowerUpTag.control],
    favoredFamilies: ['pip', 'mask', 'wing', 'mane'],
    favoredStats: [PowerUpStatFocus.speed, PowerUpStatFocus.intelligence],
  ),
  PowerUpDef(
    id: 'keystone_spellbloom',
    name: 'Spellbloom Engine',
    description:
        'Caster run: stronger alchemon output with amplified spell cadence',
    icon: '🌌',
    category: PowerUpCategory.rarePerk,
    rarity: PowerUpRarity.legendary,
    maxStacks: 1,
    showLevel: false,
    isKeystone: true,
    tags: [PowerUpTag.specialCast, PowerUpTag.summonOrbit],
    favoredFamilies: ['mystic', 'let', 'wing', 'kin'],
    favoredStats: [PowerUpStatFocus.beauty, PowerUpStatFocus.intelligence],
  ),
  PowerUpDef(
    id: 'keystone_warpath',
    name: 'Warpath Doctrine',
    description:
        'Assault run: boosted pressure for attack-forward teams and carry lines',
    icon: '⚔️',
    category: PowerUpCategory.rarePerk,
    rarity: PowerUpRarity.legendary,
    maxStacks: 1,
    showLevel: false,
    isKeystone: true,
    tags: [PowerUpTag.basicAttack, PowerUpTag.chainExecute],
    favoredFamilies: ['horn', 'mane', 'pip'],
    favoredStats: [PowerUpStatFocus.strength, PowerUpStatFocus.speed],
  ),
];

const kAllPowerUps = [
  ...kCompanionStatBoosts,
  ...kGlobalStatBoosts,
  ...kShipWeapons,
  ...kOrbDefenses,
  ...kRarePerks,
];

class PowerUpState {
  final Map<String, int> _globalStacks = {};
  final Map<int, Map<String, int>> _companionStacks = {};
  final Set<int> _phoenixUsed = {};
  final List<AppliedPowerUp> _history = [];

  List<AppliedPowerUp> get history => List.unmodifiable(_history);

  int getGlobalStacks(String id) => _globalStacks[id] ?? 0;

  int getCompanionStacks(int slotIndex, String id) =>
      _companionStacks[slotIndex]?[id] ?? 0;

  int getStacks(String id, {int? slotIndex}) {
    return slotIndex == null
        ? getGlobalStacks(id)
        : getCompanionStacks(slotIndex, id);
  }

  bool has(String id, {int? slotIndex}) =>
      getStacks(id, slotIndex: slotIndex) > 0;

  bool canApply(
    PowerUpDef def, {
    int? targetSlot,
    int companionCount = 0,
    Set<int> defeatedCompanionSlots = const {},
  }) {
    // Mutual exclusion: spread shot and rocket barrage are separate weapon paths
    if (def.id == 'spread_shot' && getGlobalStacks('rocket_barrage') > 0) {
      return false;
    }
    if (def.id == 'rocket_barrage' && getGlobalStacks('spread_shot') > 0) {
      return false;
    }
    // Homing missiles are redundant if rocket barrage already provides homing
    if (def.id == 'homing_missiles' && getGlobalStacks('rocket_barrage') > 0) {
      return false;
    }
    if (def.scope == PowerUpScope.companion) {
      if (companionCount <= 0) return false;
      if (targetSlot != null) {
        if (def.requiresDefeatedTarget &&
            !defeatedCompanionSlots.contains(targetSlot)) {
          return false;
        }
        return def.ignoresStackLimit ||
            getCompanionStacks(targetSlot, def.id) < def.maxStacks;
      }
      for (var i = 0; i < companionCount; i++) {
        if (def.requiresDefeatedTarget && !defeatedCompanionSlots.contains(i)) {
          continue;
        }
        if (def.ignoresStackLimit ||
            getCompanionStacks(i, def.id) < def.maxStacks) {
          return true;
        }
      }
      return false;
    }
    return def.ignoresStackLimit || getGlobalStacks(def.id) < def.maxStacks;
  }

  bool apply(PowerUpDef def, {int? targetSlot, String? targetName}) {
    if (def.scope == PowerUpScope.companion) {
      if (targetSlot == null) return false;
      final slotStacks = _companionStacks.putIfAbsent(targetSlot, () => {});
      final current = slotStacks[def.id] ?? 0;
      if (!def.ignoresStackLimit && current >= def.maxStacks) return false;
      slotStacks[def.id] = current + 1;
      _history.add(
        AppliedPowerUp(
          def: def,
          targetSlot: targetSlot,
          targetName: targetName,
        ),
      );
      return true;
    }

    final current = _globalStacks[def.id] ?? 0;
    if (!def.ignoresStackLimit && current >= def.maxStacks) return false;
    _globalStacks[def.id] = current + 1;
    _history.add(AppliedPowerUp(def: def));
    return true;
  }

  double companionAttackMultiplier(int slotIndex) =>
      (1.0 +
          getGlobalStacks('command_attack') * 0.06 +
          (hasSpellbloomEngine ? 0.16 : 0.0) +
          (hasWarpathDoctrine ? 0.22 : 0.0)) *
      (1.0 + getCompanionStacks(slotIndex, 'attack_boost') * 0.18);

  double companionDefenseMultiplier(int slotIndex) =>
      (1.0 +
          getGlobalStacks('command_defense') * 0.06 +
          (hasBastionHeart ? 0.12 : 0.0)) *
      (1.0 + getCompanionStacks(slotIndex, 'defense_boost') * 0.16);

  double companionSpeedMultiplier(int slotIndex) =>
      1.0 +
      getCompanionStacks(slotIndex, 'speed_boost') * 0.14 +
      (hasChronoSurge ? 0.16 : 0.0);

  double companionHpMultiplier(int slotIndex) =>
      1.0 +
      getCompanionStacks(slotIndex, 'hp_boost') * 0.22 +
      (hasBastionHeart ? 0.14 : 0.0);
  double companionCooldownReduction(int slotIndex) =>
      getCompanionStacks(slotIndex, 'cooldown_reduction') * 0.08 +
      (hasChronoSurge ? 0.10 : 0.0) +
      (hasSpellbloomEngine ? 0.12 : 0.0);

  double companionBloodPactHealPercent(int slotIndex) =>
      switch (getCompanionStacks(slotIndex, 'lifesteal')) {
        1 => 0.05,
        2 => 0.08,
        3 => 0.12,
        _ => 0.0,
      };

  bool companionHasDoubleCast(int slotIndex) =>
      has('double_cast', slotIndex: slotIndex);

  bool companionHasChainLightning(int slotIndex) =>
      has('chain_lightning', slotIndex: slotIndex);

  bool companionHasPhoenixRebirth(int slotIndex) =>
      has('phoenix_rebirth', slotIndex: slotIndex) &&
      !_phoenixUsed.contains(slotIndex);

  bool get hasKeystone =>
      kKeystonePowerUps.any((def) => getGlobalStacks(def.id) > 0);

  bool get hasBastionHeart => has('keystone_bastion_heart');
  bool get hasChronoSurge => has('keystone_chrono_surge');
  bool get hasSpellbloomEngine => has('keystone_spellbloom');
  bool get hasWarpathDoctrine => has('keystone_warpath');

  void consumePhoenixRebirth(int slotIndex) {
    _phoenixUsed.add(slotIndex);
  }

  double get orbHpMultiplier =>
      1.0 +
      getGlobalStacks('orb_vitality') * 0.10 +
      (hasBastionHeart ? 0.20 : 0.0);
  double get fireRateMultiplier =>
      1.0 + getGlobalStacks('fire_rate') * 0.22 + (hasChronoSurge ? 0.20 : 0.0);
  bool get hasHomingMissiles => has('homing_missiles');
  int get spreadShotLevel => getGlobalStacks('spread_shot');
  int get rocketBarrageLevel => getGlobalStacks('rocket_barrage');
  bool get hasRocketBarrage => rocketBarrageLevel > 0;
  double get shipDamageMultiplier =>
      1.0 +
      getGlobalStacks('ship_damage') * 0.18 +
      (hasWarpathDoctrine ? 0.20 : 0.0);
  int get shieldPulseLevel => getGlobalStacks('shield_pulse');
  int get autoTurretLevel => getGlobalStacks('auto_turret');
  int get regenFieldLevel => getGlobalStacks('regen_field');
  int get novaDetonationLevel => getGlobalStacks('nova_detonation');
  bool get hasMirrorShield => has('mirror_shield');
  bool get hasBerserker => has('berserker');
  bool get hasElementalFury => has('elemental_fury');
  int get elementalFuryLevel => getGlobalStacks('elemental_fury');
  int get timeDilationLevel => getGlobalStacks('time_dilation');
  int get maxActiveCompanions =>
      (1 + getGlobalStacks('pack_leader')).clamp(1, 5);
  int get orbVitalityLevel => getGlobalStacks('orb_vitality');

  int displayedLevel(PowerUpDef def, {int? slotIndex}) => getStacks(
    def.id,
    slotIndex: def.scope == PowerUpScope.companion ? slotIndex : null,
  );
}

class AppliedPowerUp {
  final PowerUpDef def;
  final int? targetSlot;
  final String? targetName;

  const AppliedPowerUp({required this.def, this.targetSlot, this.targetName});
}

class OfferedPowerUpChoice {
  final PowerUpDef def;
  final int? targetSlot;
  final String? targetName;
  final int currentLevel;

  const OfferedPowerUpChoice({
    required this.def,
    this.targetSlot,
    this.targetName,
    required this.currentLevel,
  });
}

String powerUpIncrementLabel(OfferedPowerUpChoice choice) {
  final def = choice.def;
  final nextLevel = choice.currentLevel + 1;
  if (def.isKeystone) {
    return switch (def.id) {
      'keystone_bastion_heart' =>
        '+20% orb HP, +12% companion defense, +14% companion HP',
      'keystone_chrono_surge' =>
        '+16% companion speed, +10% cooldown reduction, +20% ship fire rate',
      'keystone_spellbloom' =>
        '+16% companion attack, +12% cooldown reduction',
      'keystone_warpath' =>
        '+22% companion attack and +20% ship damage',
      _ => def.description,
    };
  }
  return switch (def.id) {
    'attack_boost' => '+18% power boost',
    'defense_boost' => '+16% defense boost',
    'speed_boost' => '+14% speed boost',
    'hp_boost' => '+22% max HP boost',
    'cooldown_reduction' => '-8% cooldown',
    'command_attack' => '+6% team power boost',
    'command_defense' => '+6% team defense boost',
    'orb_vitality' => '+10% orb max HP',
    'fire_rate' => '+22% ship fire rate',
    'spread_shot' => '+2 side shots',
    'rocket_barrage' => switch (nextLevel) {
      1 => 'Rockets deal 4.0x damage / 70 splash radius',
      2 => 'Rockets deal 5.5x damage / 90 splash radius',
      _ => 'Rockets deal 7.0x damage / 115 radius + twin rockets',
    },
    'ship_damage' => '+18% ship damage',
    'homing_missiles' => 'Ship shots gain homing',
    'shield_pulse' => '+1 shield pulse level',
    'auto_turret' => '+1 auto-turret level',
    'regen_field' => '+1 regeneration field level',
    'nova_detonation' => '+1 nova detonation level',
    'revive_half' => 'Revive at 50% HP',
    'pack_leader' => '+1 active alchemon slot',
    'lifesteal' => switch (nextLevel) {
      1 => 'Kills heal orb for 5% max HP',
      2 => 'Kills heal orb for 8% max HP',
      _ => 'Kills heal orb for 12% max HP',
    },
    'time_dilation' => switch (nextLevel) {
      1 => 'Wave start slow: 10%',
      2 => 'Wave start slow: 18%',
      _ => 'Wave start slow: 28%',
    },
    'double_cast' => 'Special ability casts twice',
    'chain_lightning' => 'Attacks chain to nearby enemies',
    'mirror_shield' => 'Reduce orb collision damage and retaliate',
    'berserker' => 'Double damage below 30% orb HP',
    'elemental_fury' => '+1 elemental splash level',
    'phoenix_rebirth' => 'Revive once at full HP',
    _ => def.description,
  };
}

String? powerUpTotalLabel(OfferedPowerUpChoice choice) {
  final def = choice.def;
  final nextLevel = choice.currentLevel + 1;
  if (def.isKeystone) return 'Keystone: only one can be claimed.';
  if (choice.currentLevel <= 0 || def.maxStacks <= 1) return null;
  return switch (def.id) {
    'attack_boost' => '+${18 * nextLevel}% total power',
    'defense_boost' => '+${16 * nextLevel}% total defense',
    'speed_boost' => '+${14 * nextLevel}% total speed',
    'hp_boost' => '+${22 * nextLevel}% total max HP',
    'cooldown_reduction' => '-${8 * nextLevel}% total cooldown',
    'command_attack' => '+${6 * nextLevel}% total team power',
    'command_defense' => '+${6 * nextLevel}% total team defense',
    'orb_vitality' => '+${10 * nextLevel}% total orb max HP',
    'fire_rate' => '+${22 * nextLevel}% total ship fire rate',
    'ship_damage' => '+${18 * nextLevel}% total ship damage',
    'rocket_barrage' => switch (nextLevel) {
      2 => 'Rockets: 5.5x damage, 90 splash radius',
      3 => 'Rockets: 7.0x damage, 115 radius, twin launch',
      _ => null,
    },
    'lifesteal' => switch (nextLevel) {
      2 => 'Total orb heal on kill: 8% max HP',
      3 => 'Total orb heal on kill: 12% max HP',
      _ => null,
    },
    'time_dilation' => switch (nextLevel) {
      2 => 'Total wave start slow: 18%',
      3 => 'Total wave start slow: 28%',
      _ => null,
    },
    _ => null,
  };
}

double _survivalStatPremium(double value) {
  return ((value - 2.0) / 2.5).clamp(0.0, 1.2).toDouble();
}

double powerUpDraftWeightForMember(PowerUpDef def, CosmicPartyMember member) {
  var score = 1.0;
  final family = member.family.toLowerCase();
  if (def.favoredFamilies.contains(family)) {
    score += 0.75;
  }

  for (final focus in def.favoredStats) {
    final statValue = switch (focus) {
      PowerUpStatFocus.speed => member.statSpeed,
      PowerUpStatFocus.strength => member.statStrength,
      PowerUpStatFocus.beauty => member.statBeauty,
      PowerUpStatFocus.intelligence => member.statIntelligence,
    };
    score += _survivalStatPremium(statValue) * 0.65;
  }

  if (def.tags.contains(PowerUpTag.tempo) &&
      member.statSpeed >= max(member.statBeauty, member.statStrength)) {
    score += 0.18;
  }
  if (def.tags.contains(PowerUpTag.specialCast) && member.statBeauty >= 3.2) {
    score += 0.20;
  }
  if (def.tags.contains(PowerUpTag.control) && member.statIntelligence >= 3.2) {
    score += 0.20;
  }
  if (def.tags.contains(PowerUpTag.basicAttack) && member.statStrength >= 3.2) {
    score += 0.20;
  }
  if (def.tags.contains(PowerUpTag.fortress) &&
      max(member.statStrength, member.statIntelligence) >= 3.4) {
    score += 0.15;
  }

  return score;
}

double powerUpDraftWeightForParty(
  PowerUpDef def,
  List<CosmicPartyMember> party,
) {
  if (party.isEmpty) return 1.0;
  final memberScores = party
      .map((member) => powerUpDraftWeightForMember(def, member))
      .toList();
  final averageScore =
      memberScores.fold<double>(0, (sum, value) => sum + value) /
      memberScores.length;
  final bestScore = memberScores.reduce(max);

  var teamScore = averageScore * 0.75 + bestScore * 0.25;
  if (def.scope == PowerUpScope.global) {
    teamScore +=
        def.favoredFamilies
            .where(
              (family) =>
                  party.any((member) => member.family.toLowerCase() == family),
            )
            .length *
        0.08;
  }
  return teamScore;
}

List<OfferedPowerUpChoice> generateKeystoneChoices(
  PowerUpState state,
  int wave, {
  List<CosmicPartyMember> party = const [],
}) {
  if (state.hasKeystone) return const [];
  final rng = Random(wave * 97 + 23);
  final pool = List<PowerUpDef>.of(kKeystonePowerUps);
  pool.sort((a, b) {
    final aScore = powerUpDraftWeightForParty(a, party);
    final bScore = powerUpDraftWeightForParty(b, party);
    return bScore.compareTo(aScore);
  });

  final weightedTop = pool.take(min(pool.length, 3)).toList();
  weightedTop.shuffle(rng);
  return weightedTop
      .map(
        (def) => OfferedPowerUpChoice(
          def: def,
          currentLevel: state.displayedLevel(def),
        ),
      )
      .toList();
}

List<OfferedPowerUpChoice> generatePowerUpChoices(
  PowerUpState state,
  int wave, {
  List<CosmicPartyMember> party = const [],
  Set<int> defeatedCompanionSlots = const {},
}) {
  final rng = Random(wave * 37 + 11);
  final companionCount = party.length;
  final available = kAllPowerUps
      .where(
        (def) => state.canApply(
          def,
          companionCount: companionCount,
          defeatedCompanionSlots: defeatedCompanionSlots,
        ),
      )
      .toList();
  final chosen = <OfferedPowerUpChoice>[];
  final usedKeys = <String>{};

  final rarityWeights = <PowerUpRarity, double>{
    PowerUpRarity.common: max(0.35, 0.68 - wave * 0.012),
    PowerUpRarity.uncommon: min(0.34, 0.20 + wave * 0.008),
    PowerUpRarity.rare: min(0.22, 0.10 + wave * 0.005),
    PowerUpRarity.legendary: min(0.10, max(0.0, (wave - 8) * 0.0035)),
  };

  PowerUpRarity pickRarity() {
    final roll = rng.nextDouble();
    var total = 0.0;
    for (final rarity in PowerUpRarity.values) {
      total += rarityWeights[rarity] ?? 0;
      if (roll <= total) return rarity;
    }
    return PowerUpRarity.common;
  }

  for (var i = 0; i < 3 && available.isNotEmpty; i++) {
    // Every 5 picks, guarantee Pack Leader in the first slot (if still upgradable)
    if (i == 0 &&
        state.history.isNotEmpty &&
        (state.history.length + 1) % 5 == 0) {
      final packLeader = available.firstWhere(
        (d) => d.id == 'pack_leader',
        orElse: () => available.first, // fallback if maxed
      );
      if (packLeader.id == 'pack_leader') {
        final offer = OfferedPowerUpChoice(
          def: packLeader,
          currentLevel: state.displayedLevel(packLeader),
        );
        chosen.add(offer);
        usedKeys.add('pack_leader:global');
        continue;
      }
    }

    final targetRarity = pickRarity();
    var pool = available.where((def) => def.rarity == targetRarity).toList();
    if (pool.isEmpty) {
      pool = List.of(available);
    }
    if (pool.isEmpty) break;

    pool.sort((a, b) {
      final aLevel = state.displayedLevel(a);
      final bLevel = state.displayedLevel(b);
      final aScore =
          (a.maxStacks - aLevel) +
          (a.rarity.index * 0.15) +
          powerUpDraftWeightForParty(a, party);
      final bScore =
          (b.maxStacks - bLevel) +
          (b.rarity.index * 0.15) +
          powerUpDraftWeightForParty(b, party);
      return bScore.compareTo(aScore);
    });

    final bound = min(pool.length, 4);
    final pick = pool[rng.nextInt(bound)];
    final offer = _buildOfferedChoice(
      pick,
      state,
      party,
      rng,
      defeatedCompanionSlots,
    );
    final offerKey = '${offer.def.id}:${offer.targetSlot ?? 'global'}';
    if (usedKeys.contains(offerKey)) {
      continue;
    }
    chosen.add(offer);
    usedKeys.add(offerKey);
  }

  return chosen;
}

OfferedPowerUpChoice _buildOfferedChoice(
  PowerUpDef def,
  PowerUpState state,
  List<CosmicPartyMember> party,
  Random rng,
  Set<int> defeatedCompanionSlots,
) {
  if (def.scope != PowerUpScope.companion) {
    return OfferedPowerUpChoice(
      def: def,
      currentLevel: state.displayedLevel(def),
    );
  }

  final candidates = <({int slot, String name, int level, double weight})>[];
  for (var i = 0; i < party.length; i++) {
    if (!state.canApply(
      def,
      targetSlot: i,
      companionCount: party.length,
      defeatedCompanionSlots: defeatedCompanionSlots,
    )) {
      continue;
    }
    final level = state.getCompanionStacks(i, def.id);
    final member = party[i];
    final weight = def.requiresDefeatedTarget
        ? 2.0 + rng.nextDouble() * 0.5
        : level > 0
        ? 1.8 + (level * 1.35) + rng.nextDouble() * 0.35
        : 0.9 + rng.nextDouble() * 1.1;
    candidates.add((
      slot: i,
      name: member.displayName,
      level: level,
      weight: weight * powerUpDraftWeightForMember(def, member),
    ));
  }

  if (candidates.isEmpty) {
    return OfferedPowerUpChoice(def: def, currentLevel: 0);
  }

  final totalWeight = candidates.fold<double>(0, (sum, c) => sum + c.weight);
  var roll = rng.nextDouble() * totalWeight;
  var selected = candidates.first;
  for (final candidate in candidates) {
    roll -= candidate.weight;
    if (roll <= 0) {
      selected = candidate;
      break;
    }
  }

  return OfferedPowerUpChoice(
    def: def,
    targetSlot: selected.slot,
    targetName: selected.name,
    currentLevel: selected.level,
  );
}
