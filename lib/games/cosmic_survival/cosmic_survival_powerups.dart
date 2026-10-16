import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';

enum PowerUpCategory {
  statBoost,
  shipWeapon,
  orbDefense,
  rarePerk,
  mysticWorld,
}

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
  final String? choiceGroup;

  /// Set on the surges that upgrade a Mystic's WORLD. Such a surge is only
  /// ever offered while a Mystic of this element is actually in the party —
  /// it upgrades a specific thing standing on the map, so offering it to a
  /// party that cannot field it would be a dead pick in a three-way draft.
  final String? mysticElement;

  /// Set on a SURGE FUSION ([kFusionPowerUps]): the two upgrades that make
  /// it, each taken as far as it goes.
  final List<String> fusedFrom;

  bool get isFusion => fusedFrom.isNotEmpty;

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
    this.choiceGroup,
    this.mysticElement,
    this.fusedFrom = const [],
  });
}

const kCompanionStatBoosts = [
  PowerUpDef(
    id: 'strength_up',
    name: 'Strength Surge',
    description: "Raise one alchemon's Strength by 10%",
    icon: '⚔️',
    category: PowerUpCategory.statBoost,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [
      PowerUpTag.basicAttack,
      PowerUpTag.chainExecute,
      PowerUpTag.fortress,
    ],
    favoredFamilies: ['horn', 'mane', 'pip'],
    favoredStats: [PowerUpStatFocus.strength],
  ),
  PowerUpDef(
    id: 'intelligence_up',
    name: 'Insight Surge',
    description: "Raise one alchemon's Intelligence by 10%",
    icon: '🧠',
    category: PowerUpCategory.statBoost,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.fortress, PowerUpTag.control, PowerUpTag.sustain],
    favoredFamilies: ['horn', 'kin', 'mask', 'mane'],
    favoredStats: [PowerUpStatFocus.intelligence],
  ),
  PowerUpDef(
    id: 'beauty_up',
    name: 'Radiance Surge',
    description: "Raise one alchemon's Beauty by 10%",
    icon: '🌸',
    category: PowerUpCategory.statBoost,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.specialCast, PowerUpTag.sustain],
    favoredFamilies: ['mystic', 'let', 'wing', 'kin'],
    favoredStats: [PowerUpStatFocus.beauty],
  ),
  PowerUpDef(
    id: 'speed_up',
    name: 'Swiftness Surge',
    description: "Raise one alchemon's Speed by 10%",
    icon: '💨',
    category: PowerUpCategory.statBoost,
    rarity: PowerUpRarity.uncommon,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.tempo, PowerUpTag.control],
    favoredFamilies: ['pip', 'mask', 'mane', 'wing'],
    favoredStats: [PowerUpStatFocus.speed],
  ),
];

const kGlobalStatBoosts = [
  PowerUpDef(
    id: 'command_strength',
    name: 'War Banner',
    description: 'Raise Strength for all alchemons by 5%',
    icon: '🚩',
    category: PowerUpCategory.statBoost,
    maxStacks: 3,
    tags: [PowerUpTag.basicAttack, PowerUpTag.fortress],
    favoredStats: [PowerUpStatFocus.strength],
  ),
  PowerUpDef(
    id: 'command_intelligence',
    name: 'Strategist Banner',
    description: 'Raise Intelligence for all alchemons by 5%',
    icon: '🧱',
    category: PowerUpCategory.statBoost,
    maxStacks: 3,
    tags: [PowerUpTag.fortress, PowerUpTag.control],
    favoredStats: [PowerUpStatFocus.intelligence],
  ),
  PowerUpDef(
    id: 'command_beauty',
    name: 'Resplendent Banner',
    description: 'Raise Beauty for all alchemons by 5%',
    icon: '🎏',
    category: PowerUpCategory.statBoost,
    maxStacks: 3,
    tags: [PowerUpTag.specialCast, PowerUpTag.sustain],
    favoredStats: [PowerUpStatFocus.beauty],
  ),
  PowerUpDef(
    id: 'command_speed',
    name: 'Vanguard Banner',
    description: 'Raise Speed for all alchemons by 5%',
    icon: '🏳️',
    category: PowerUpCategory.statBoost,
    rarity: PowerUpRarity.uncommon,
    maxStacks: 3,
    tags: [PowerUpTag.tempo],
    favoredStats: [PowerUpStatFocus.speed],
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
  PowerUpDef(
    id: 'missile_launcher',
    name: 'Missile Launcher',
    description: 'Ship periodically launches heavy homing missiles',
    icon: '🛰️',
    category: PowerUpCategory.shipWeapon,
    rarity: PowerUpRarity.rare,
    maxStacks: 3,
    choiceGroup: 'ship_arsenal_doctrine',
    tags: [PowerUpTag.basicAttack, PowerUpTag.chainExecute],
  ),
  PowerUpDef(
    id: 'rapid_turret',
    name: 'Fast Turret',
    description: 'Ship auto-turret zaps nearby enemies at high cadence',
    icon: '🛞',
    category: PowerUpCategory.shipWeapon,
    rarity: PowerUpRarity.uncommon,
    maxStacks: 3,
    choiceGroup: 'ship_arsenal_doctrine',
    tags: [PowerUpTag.tempo, PowerUpTag.control],
  ),
  PowerUpDef(
    id: 'kinetic_overdrive',
    name: 'Kinetic Overdrive',
    description: 'Ship rounds gain speed, lifetime, and impact',
    icon: '🧲',
    category: PowerUpCategory.shipWeapon,
    rarity: PowerUpRarity.uncommon,
    maxStacks: 3,
    tags: [PowerUpTag.basicAttack],
  ),
  // The ship's own hull, for a player who flies it into the fight
  // (cosmic_survival_game.dart, _syncShipHull).
  PowerUpDef(
    id: 'ship_hull',
    name: 'Reinforced Hull',
    description: '+50% ship hull, and the ship is rebuilt 6 s sooner',
    icon: '🛡',
    category: PowerUpCategory.shipWeapon,
    maxStacks: 3,
    tags: [PowerUpTag.fortress],
  ),
  // Kills leave surge grains that wait for the ship (surge_grains.dart).
  // Each level widens the ship's pull; the last has a cleared wave send the
  // grains left out to the core.
  PowerUpDef(
    id: 'surge_magnet',
    name: 'Surge Magnet',
    description: 'The ship pulls surge grains from further away',
    icon: '✨',
    category: PowerUpCategory.shipWeapon,
    rarity: PowerUpRarity.uncommon,
    maxStacks: 4,
    tags: [PowerUpTag.tempo],
  ),
  // The ship gathers for itself: let go of it, or watch in CAMERA, and it
  // flies out to the grains lying round the orb and lets the orbit bring it
  // back (cosmic_survival_game.dart, _autopilotGather).
  PowerUpDef(
    id: 'autopilot',
    name: 'Autopilot',
    description: 'When you let go, the ship flies out for surge grains',
    icon: '🛰',
    category: PowerUpCategory.shipWeapon,
    rarity: PowerUpRarity.uncommon,
    maxStacks: 1,
    tags: [PowerUpTag.tempo],
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
    description:
        'Orb turret fires faster, scales into later waves, and hits visibly',
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
    description:
        'Reduce orb collision damage by 25% and release a retaliatory pulse',
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
    description:
        "Kills splash nearby enemies for 25% / 40% / 55% of the killer's elemental attack",
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
    description: 'Fortress path: harden orb and guardians',
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
    description: 'Tempo path: accelerate movement, cadence, and fire',
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
    name: 'Spellbloom',
    description: 'Caster path: amplify spell rhythm and output',
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
    name: 'Warpath',
    description: 'Assault path: amplify frontline pressure',
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

/// One surge per reworked Mystic world, three levels each.
///
/// These exist because a Mystic is the single-slot pick: the player gave up
/// every other option in that slot, and until now nothing in the draft could
/// make that choice pay off any harder. A world surge upgrades the specific
/// thing standing on the map rather than the companion's stats, so it reads as
/// the world deepening rather than as another generic buff.
///
/// Only the nine reworked worlds are here. The other eight Mystics are still
/// projectile ultimates and have nothing on the map to deepen; they get their
/// surges when they get their worlds.
const kMysticWorldPowerUps = [
  PowerUpDef(
    id: 'world_fire',
    name: 'Deepening Ember Season',
    description: 'More embers drift the map, and they burn hotter',
    icon: '🔥',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.specialCast, PowerUpTag.control],
    favoredFamilies: ['mystic'],
    mysticElement: 'Fire',
  ),
  PowerUpDef(
    id: 'world_spirit',
    name: 'Deepening Turning',
    description: 'More of the dead get back up, and they stand longer',
    icon: '👻',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.summonOrbit, PowerUpTag.chainExecute],
    favoredFamilies: ['mystic'],
    mysticElement: 'Spirit',
  ),
  PowerUpDef(
    id: 'world_blood',
    name: 'Deepening Tithe',
    description: 'Every auto attack draws more life back',
    icon: '🩸',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.sustain, PowerUpTag.basicAttack],
    favoredFamilies: ['mystic'],
    mysticElement: 'Blood',
  ),
  PowerUpDef(
    id: 'world_dark',
    name: 'Widening Maw',
    description: 'The hole pulls from further out and bites harder',
    icon: '🕳️',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.control],
    favoredFamilies: ['mystic'],
    mysticElement: 'Dark',
  ),
  PowerUpDef(
    id: 'world_plant',
    name: 'Deepening Grove',
    description: 'The vines reach further and hit harder',
    icon: '🌿',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.summonOrbit, PowerUpTag.control],
    favoredFamilies: ['mystic'],
    mysticElement: 'Plant',
  ),
  PowerUpDef(
    id: 'world_lightning',
    name: 'Gathering Storm',
    description: 'Bolts fall more often and land heavier',
    icon: '⚡',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.tempo, PowerUpTag.chainExecute],
    favoredFamilies: ['mystic'],
    mysticElement: 'Lightning',
  ),
  PowerUpDef(
    id: 'world_poison',
    name: 'Thickening Miasma',
    description: 'The ship spills wider, longer-lasting poison',
    icon: '☠️',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.control, PowerUpTag.tempo],
    favoredFamilies: ['mystic'],
    mysticElement: 'Poison',
  ),
  PowerUpDef(
    id: 'world_mud',
    name: 'Deepening Weight',
    description: 'The mud drags harder on everything, heavy bodies most',
    icon: '🟤',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.control, PowerUpTag.basicAttack],
    favoredFamilies: ['mystic'],
    mysticElement: 'Mud',
  ),
  PowerUpDef(
    id: 'world_earth',
    name: 'Quickening Quake',
    description: 'The ground shakes sooner and shakes harder',
    icon: '⛰️',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.control, PowerUpTag.tempo],
    favoredFamilies: ['mystic'],
    mysticElement: 'Earth',
  ),
  PowerUpDef(
    id: 'world_ice',
    name: 'Deepening Blizzard',
    description: 'The cold bites harder across the whole field',
    icon: '❄️',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.control],
    favoredFamilies: ['mystic'],
    mysticElement: 'Ice',
  ),
  PowerUpDef(
    id: 'world_crystal',
    name: 'Richer Vein',
    description: 'More of the dead crystallise, and shards are worth more',
    icon: '💎',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.tempo, PowerUpTag.sustain],
    favoredFamilies: ['mystic'],
    mysticElement: 'Crystal',
  ),
  PowerUpDef(
    id: 'world_light',
    name: 'Hastened Dawn',
    description: 'The star rises sooner',
    icon: '🌅',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.sustain, PowerUpTag.fortress],
    favoredFamilies: ['mystic'],
    mysticElement: 'Light',
  ),
  PowerUpDef(
    id: 'world_dust',
    name: 'Thickening Haze',
    description: 'More rounds go off in their owners\' faces',
    icon: '🌫️',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.control, PowerUpTag.chainExecute],
    favoredFamilies: ['mystic'],
    mysticElement: 'Dust',
  ),
  PowerUpDef(
    id: 'world_steam',
    name: 'Rising Pressure',
    description: 'The arena vents sooner and throws harder',
    icon: '♨️',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.control, PowerUpTag.tempo],
    favoredFamilies: ['mystic'],
    mysticElement: 'Steam',
  ),
  PowerUpDef(
    id: 'world_lava',
    name: 'Widening Fissures',
    description: 'More cracks, and heavier falls when they break',
    icon: '🌋',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.control, PowerUpTag.chainExecute],
    favoredFamilies: ['mystic'],
    mysticElement: 'Lava',
  ),
  PowerUpDef(
    id: 'world_water',
    name: 'Widening Maelstrom',
    description: 'The whirlpool reaches further and grinds harder',
    icon: '🌀',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.control],
    favoredFamilies: ['mystic'],
    mysticElement: 'Water',
  ),
  PowerUpDef(
    id: 'world_air',
    name: 'Widening Funnel',
    description: 'The tornado reaches further and grinds harder',
    icon: '🌪️',
    category: PowerUpCategory.mysticWorld,
    rarity: PowerUpRarity.rare,
    scope: PowerUpScope.companion,
    maxStacks: 3,
    tags: [PowerUpTag.control, PowerUpTag.tempo],
    favoredFamilies: ['mystic'],
    mysticElement: 'Air',
  ),
];

const kAllPowerUps = [
  ...kMysticWorldPowerUps,
  ...kCompanionStatBoosts,
  ...kGlobalStatBoosts,
  ...kShipWeapons,
  ...kOrbDefenses,
  ...kRarePerks,
];

/// SURGE FUSIONS. Two upgrades, each taken as far as it goes, transmute into
/// a third: from then on every ordinary draft holds it as one of its cards
/// until it is taken or banished. The parents keep working; the fusion adds
/// one bounded extra that makes their two mechanics work together.
///
/// Built only from ship, orb and team upgrades, so none depends on which
/// Alchemon is fielded, and each upgrade is a parent of at most one. None of
/// them reaches for what the families own (piercing, marking, push,
/// vulnerable, stagger, ground lanes, every-Nth-attack cadence).
///
/// Never drawn at random: they are not in [kAllPowerUps].
const kFusionPowerUps = [
  // The spread's side shots were plain; Hunter Salvo only steered the
  // centre one. Fused, each side shot steers too, at the body nearest its
  // own line, so the fan still covers its arc.
  PowerUpDef(
    id: 'fusion_homing_spread',
    name: 'Homing Spread',
    description: 'Side shots home in and hit as hard as the centre shot',
    icon: '🌊',
    category: PowerUpCategory.shipWeapon,
    rarity: PowerUpRarity.legendary,
    maxStacks: 1,
    showLevel: false,
    fusedFrom: ['spread_shot', 'homing_missiles'],
  ),
  // Rocket Barrage loads 1.5x slower than the gun it replaces.
  PowerUpDef(
    id: 'fusion_rapid_rockets',
    name: 'Rapid Rockets',
    description: 'Rockets reload faster than shots',
    icon: '🚀',
    category: PowerUpCategory.shipWeapon,
    rarity: PowerUpRarity.legendary,
    maxStacks: 1,
    showLevel: false,
    fusedFrom: ['rocket_barrage', 'fire_rate'],
  ),
  // Kinetic Overdrive drove the gun's rounds only; the launcher's missiles
  // flew at their own speed and impact.
  PowerUpDef(
    id: 'fusion_heavy_missiles',
    name: 'Heavy Missiles',
    description:
        'Kinetic Overdrive drives the missiles: +75% impact, +36% speed',
    icon: '🛰️',
    category: PowerUpCategory.shipWeapon,
    rarity: PowerUpRarity.legendary,
    maxStacks: 1,
    showLevel: false,
    fusedFrom: ['missile_launcher', 'kinetic_overdrive'],
  ),
  // The ship's turret and the orb's: whatever the ship's turret hits within
  // the orb turret's reach, the orb turret shoots as well.
  PowerUpDef(
    id: 'fusion_linked_turrets',
    name: 'Linked Turrets',
    description: 'The orb turret fires on what the ship turret hits',
    icon: '🔧',
    category: PowerUpCategory.orbDefense,
    rarity: PowerUpRarity.legendary,
    maxStacks: 1,
    showLevel: false,
    fusedFrom: ['rapid_turret', 'auto_turret'],
  ),
  // The orb's two timed defences: the pulse sets off the nova as it goes.
  PowerUpDef(
    id: 'fusion_nova_pulse',
    name: 'Nova Pulse',
    description: 'Every shield pulse sets off the nova',
    icon: '☀️',
    category: PowerUpCategory.orbDefense,
    rarity: PowerUpRarity.legendary,
    maxStacks: 1,
    showLevel: false,
    fusedFrom: ['shield_pulse', 'nova_detonation'],
  ),
  // Regeneration was a flat 2 HP a level; tempering's extra HP left it
  // behind. Fused, it also restores a share of the orb's max HP.
  PowerUpDef(
    id: 'fusion_tempered_field',
    name: 'Tempered Field',
    description: 'Regeneration also restores 1% of orb max HP a second',
    icon: '💚',
    category: PowerUpCategory.orbDefense,
    rarity: PowerUpRarity.legendary,
    maxStacks: 1,
    showLevel: false,
    fusedFrom: ['regen_field', 'orb_vitality'],
  ),
];

/// Tempered Field: the share of the orb's max HP regeneration adds a second,
/// about twice what a full Field gives. On the stat-wall benchmark it moved
/// P70's mean first death about 1.7 waves past its parents and P100 + E10's
/// not at all (0.5% measured about the same).
const double kTemperedFieldShare = 0.01;

/// Rapid Rockets: a rocket's reload against a plain shot's (1.5 without it).
const double kRapidRocketsReload = 0.8;

/// Heavy Missiles: missile impact per Kinetic Overdrive level.
const double kHeavyMissilesImpactPerLevel = 0.25;

/// Linked Turrets: how far from the orb its turret answers the ship's.
const double kLinkedTurretReach = 700;

/// At most this many fusion cards in one draft, so it keeps a drawn card.
const int kMaxFusionCardsPerDraft = 2;

final Map<String, PowerUpDef> _kDrawnPowerUpsById = {
  for (final def in kAllPowerUps) def.id: def,
};

/// The fusion's two parents, as upgrades.
List<PowerUpDef> fusionParents(PowerUpDef fusion) => [
  for (final id in fusion.fusedFrom)
    if (_kDrawnPowerUpsById[id] case final def?) def,
];

/// The fusion [parentId] is a parent of, if any.
PowerUpDef? fusionWithParent(String parentId) {
  for (final fusion in kFusionPowerUps) {
    if (fusion.fusedFrom.contains(parentId)) return fusion;
  }
  return null;
}

/// The draft's two keys, per run: REROLL draws three fresh cards, BANISH
/// takes one upgrade out of the run and puts a fresh card in its place.
/// Tune them here.
const int kSurvivalDraftRerolls = 2;
const int kSurvivalDraftBanishes = 2;

class PowerUpState {
  final Map<String, int> _globalStacks = {};
  final Map<int, Map<String, int>> _companionStacks = {};
  final Set<int> _phoenixUsed = {};
  final List<AppliedPowerUp> _history = [];
  final Map<String, String> _choiceSelections = {};

  int _rerollsLeft = kSurvivalDraftRerolls;
  int _banishesLeft = kSurvivalDraftBanishes;
  final Set<String> _banished = {};

  /// Fusion parents the run has had on a draft card, for the pause panel's
  /// FUSIONS list.
  final Set<String> _seenFusionParents = {};

  List<AppliedPowerUp> get history => List.unmodifiable(_history);

  /// Fusion parents offered on a draft card this run (taken ones count too:
  /// see [hasSeenFusionParent]).
  Set<String> get seenFusionParents => Set.unmodifiable(_seenFusionParents);

  bool hasSeenFusionParent(String id) =>
      _seenFusionParents.contains(id) || getGlobalStacks(id) > 0;

  /// Notes the fusion parents among [choices]: they were put in front of
  /// the player.
  void noteOffered(Iterable<OfferedPowerUpChoice> choices) {
    for (final c in choices) {
      if (fusionWithParent(c.def.id) != null) _seenFusionParents.add(c.def.id);
    }
  }

  /// A continued run's seen parents, as it left them.
  void restoreSeenFusionParents(Iterable<String> ids) {
    _seenFusionParents
      ..clear()
      ..addAll(ids.where((id) => fusionWithParent(id) != null));
  }

  /// Whether [parent] has been taken as far as it goes.
  bool fusionParentDone(PowerUpDef parent) =>
      getGlobalStacks(parent.id) >= parent.maxStacks;

  bool _fusionParentsDone(PowerUpDef fusion) {
    final parents = fusionParents(fusion);
    return parents.length == fusion.fusedFrom.length &&
        parents.every(fusionParentDone);
  }

  /// Whether [fusion] is due a card: both parents done, and it is neither
  /// taken nor banished.
  bool fusionReady(PowerUpDef fusion) =>
      fusion.isFusion &&
      !has(fusion.id) &&
      !isBanished(fusion.id) &&
      _fusionParentsDone(fusion);

  /// Every fusion due a card, in recipe order.
  List<PowerUpDef> get readyFusions => [
    for (final fusion in kFusionPowerUps)
      if (fusionReady(fusion)) fusion,
  ];

  /// Whether [fusion] can still be made this run: not banished, and each
  /// parent done or still to be had (not banished, not shut out by the
  /// other path of an either-or or a weapon it excludes).
  bool fusionStillPossible(PowerUpDef fusion) {
    if (has(fusion.id)) return true;
    if (isBanished(fusion.id)) return false;
    for (final parent in fusionParents(fusion)) {
      if (fusionParentDone(parent)) continue;
      if (isBanished(parent.id) || !canApply(parent)) return false;
    }
    return true;
  }

  /// The other parent of the fusion [parentId] makes, while that fusion can
  /// still be made; null otherwise.
  PowerUpDef? fusionPartnerOf(String parentId) {
    final fusion = fusionWithParent(parentId);
    if (fusion == null || has(fusion.id) || !fusionStillPossible(fusion)) {
      return null;
    }
    for (final parent in fusionParents(fusion)) {
      if (parent.id != parentId) return parent;
    }
    return null;
  }

  /// REROLLs the run has left.
  int get rerollsLeft => _rerollsLeft;

  /// BANISHes the run has left.
  int get banishesLeft => _banishesLeft;

  /// Upgrades banished this run: never offered again.
  Set<String> get banished => Set.unmodifiable(_banished);

  bool isBanished(String id) => _banished.contains(id);

  /// How many fresh draws the keys have made this run, so each one is
  /// seeded apart from the last and a continued run draws the same.
  int get draftRedraws =>
      max(0, kSurvivalDraftRerolls - _rerollsLeft) +
      max(0, kSurvivalDraftBanishes - _banishesLeft);

  /// Spends a REROLL; false with none left.
  bool spendReroll() {
    if (_rerollsLeft <= 0) return false;
    _rerollsLeft--;
    return true;
  }

  /// Spends a BANISH on [id]; false with none left.
  bool spendBanish(String id) {
    if (_banishesLeft <= 0) return false;
    _banishesLeft--;
    _banished.add(id);
    return true;
  }

  /// A continued run's keys, as it left them.
  void restoreDraftKeys({
    required int rerollsLeft,
    required int banishesLeft,
    required Iterable<String> banished,
  }) {
    _rerollsLeft = max(0, rerollsLeft);
    _banishesLeft = max(0, banishesLeft);
    _banished
      ..clear()
      ..addAll(banished);
  }

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
    if (def.choiceGroup != null) {
      final selected = _choiceSelections[def.choiceGroup!];
      if (selected != null && selected != def.id) return false;
    }
    // A fusion only once both its parents are taken as far as they go.
    if (def.isFusion && !_fusionParentsDone(def)) return false;
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
    if (def.choiceGroup != null) {
      final selected = _choiceSelections[def.choiceGroup!];
      if (selected != null && selected != def.id) return false;
      _choiceSelections.putIfAbsent(def.choiceGroup!, () => def.id);
    }
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

  // Stat surges are a share of the companion's OWN stat, so a bred creature
  // gets more out of the same pick than a fresh catch. They used to add flat
  // points (+0.20 a stack): about 4% of an average stat and 2% of a perfect
  // one, which is why three War Banners measured as +0% kills. Companion
  // surges add 10% a stack, banners 5% to the whole team, and keystones their
  // own share, all summed before they multiply. [base] is the companion's raw
  // stat; the result is the points to add to it.
  static const double companionSurgeShare = 0.10;
  static const double bannerSurgeShare = 0.05;

  double strengthBonus(int slotIndex, double base) =>
      base *
      (getCompanionStacks(slotIndex, 'strength_up') * companionSurgeShare +
          getGlobalStacks('command_strength') * bannerSurgeShare +
          (hasWarpathDoctrine ? 0.08 : 0.0) +
          (hasBastionHeart ? 0.02 : 0.0));

  double intelligenceBonus(int slotIndex, double base) =>
      base *
      (getCompanionStacks(slotIndex, 'intelligence_up') * companionSurgeShare +
          getGlobalStacks('command_intelligence') * bannerSurgeShare +
          (hasBastionHeart ? 0.04 : 0.0) +
          (hasSpellbloomEngine ? 0.04 : 0.0));

  double beautyBonus(int slotIndex, double base) =>
      base *
      (getCompanionStacks(slotIndex, 'beauty_up') * companionSurgeShare +
          getGlobalStacks('command_beauty') * bannerSurgeShare +
          (hasSpellbloomEngine ? 0.07 : 0.0) +
          (hasBastionHeart ? 0.04 : 0.0));

  double speedBonus(int slotIndex, double base) =>
      base *
      (getCompanionStacks(slotIndex, 'speed_up') * companionSurgeShare +
          getGlobalStacks('command_speed') * bannerSurgeShare +
          (hasChronoSurge ? 0.10 : 0.0) +
          (hasSpellbloomEngine ? 0.03 : 0.0));

  /// How far this slot's Mystic world has been deepened, 0-3.
  int mysticWorldLevel(int slotIndex, String element) =>
      getCompanionStacks(slotIndex, 'world_${element.toLowerCase()}');

  /// The world surge as a plain multiplier: 1.0 with no picks, 1.75 at three.
  /// A single number so every world scales at the same rate and the surge is
  /// worth the same wherever it lands — what each world SPENDS it on is what
  /// differs.
  double mysticWorldPower(int slotIndex, String element) =>
      1.0 + 0.25 * mysticWorldLevel(slotIndex, element);

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
  int get missileLauncherLevel => getGlobalStacks('missile_launcher');
  int get rapidTurretLevel => getGlobalStacks('rapid_turret');
  int get kineticOverdriveLevel => getGlobalStacks('kinetic_overdrive');
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
  int get surgeMagnetLevel => getGlobalStacks('surge_magnet');
  bool get hasAutopilot => getGlobalStacks('autopilot') > 0;
  int get shipHullLevel => getGlobalStacks('ship_hull');
  double get shipHullMultiplier => 1.0 + shipHullLevel * 0.5;

  // SURGE FUSIONS (kFusionPowerUps).
  bool get hasHomingSpread => has('fusion_homing_spread');
  bool get hasRapidRockets => has('fusion_rapid_rockets');
  bool get hasHeavyMissiles => has('fusion_heavy_missiles');
  bool get hasLinkedTurrets => has('fusion_linked_turrets');
  bool get hasNovaPulse => has('fusion_nova_pulse');
  bool get hasTemperedField => has('fusion_tempered_field');

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
    // What PowerUpState and applyPowerUp actually give: a share of each
    // Alchemon's own stat for the whole team, and the ship and orb figures.
    return switch (def.id) {
      'keystone_bastion_heart' =>
        'Orb max HP +20%, Team Intelligence +4%, Team Beauty +4%, '
            'Team Strength +2%',
      'keystone_chrono_surge' => 'Team Speed +10%, Ship fire rate +20%',
      'keystone_spellbloom' =>
        'Team Beauty +7%, Team Intelligence +4%, Team Speed +3%',
      'keystone_warpath' => 'Team Strength +8%, Ship damage +20%',
      _ => def.description,
    };
  }
  return switch (def.id) {
    'strength_up' => 'Strength increased',
    'intelligence_up' => 'Intelligence increased',
    'beauty_up' => 'Beauty increased',
    'speed_up' => 'Speed increased',
    'command_strength' => 'Team Strength increased',
    'command_intelligence' => 'Team Intelligence increased',
    'command_beauty' => 'Team Beauty increased',
    'command_speed' => 'Team Speed increased',
    'orb_vitality' => '+10% orb max HP',
    'fire_rate' => '+22% ship fire rate',
    'spread_shot' => '+2 side shots',
    'rocket_barrage' => switch (nextLevel) {
      1 => 'Rockets deal 4.0x damage / 70 splash radius',
      2 => 'Rockets deal 5.5x damage / 90 splash radius',
      _ => 'Rockets deal 7.0x damage / 115 radius + twin rockets',
    },
    'ship_damage' => '+18% ship impact scaling',
    'homing_missiles' => 'Ship shots gain homing',
    'missile_launcher' => switch (nextLevel) {
      1 => 'Unlock periodic heavy missile strikes',
      2 => 'Missiles launch faster and hit harder',
      _ => 'Twin missile salvos and larger blast radius',
    },
    'rapid_turret' => switch (nextLevel) {
      1 => 'Unlock rapid auto-turret beam support',
      2 => 'Turret cadence and damage increased',
      _ => 'High cadence beam pressure with heavy hits',
    },
    'kinetic_overdrive' => '+10% ship round impact, speed, and lifetime',
    'surge_magnet' => nextLevel >= 4
        ? 'When a wave ends, every grain left out flows into the orb'
        : 'Ship pulls surge grains from further away (+80)',
    'autopilot' => 'When you let go, the ship flies out for surge grains',
    'ship_hull' => '+50% ship hull, rebuilt 6 s sooner',
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
    'berserker' => 'Double impact output below 30% orb HP',
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
    'orb_vitality' => '+${10 * nextLevel}% total orb max HP',
    'fire_rate' => '+${22 * nextLevel}% total ship fire rate',
    'ship_damage' => '+${18 * nextLevel}% total ship impact scaling',
    'kinetic_overdrive' => '+${10 * nextLevel}% total ballistic scaling',
    'missile_launcher' => switch (nextLevel) {
      2 => 'Missile support: faster cycle + higher burst',
      3 => 'Missile support: twin salvo doctrine online',
      _ => null,
    },
    'rapid_turret' => switch (nextLevel) {
      2 => 'Turret support: faster beam cadence',
      3 => 'Turret support: max cadence + heavy beam',
      _ => null,
    },
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

  final exclusiveFork = _buildExclusiveThisOrThatChoice(
    state,
    wave,
    party,
    rng,
    defeatedCompanionSlots,
  );
  if (exclusiveFork.isNotEmpty) {
    state.noteOffered(exclusiveFork);
    return exclusiveFork;
  }

  // A fusion due a card leads the draft; the rest is drawn as ever.
  final fusions = _fusionCards(state);
  final draft = [
    ...fusions,
    ..._drawPowerUpChoices(
      state,
      wave,
      rng: rng,
      packLeaderRoll: Random(wave * 53 + state.history.length * 7 + 3),
      party: party,
      defeatedCompanionSlots: defeatedCompanionSlots,
      count: 3 - fusions.length,
    ),
  ];
  state.noteOffered(draft);
  return draft;
}

/// A card for each fusion due one (both parents taken as far as they go,
/// not taken or banished), in recipe order, at most
/// [kMaxFusionCardsPerDraft].
List<OfferedPowerUpChoice> _fusionCards(PowerUpState state) => [
  for (final fusion in state.readyFusions.take(kMaxFusionCardsPerDraft))
    OfferedPowerUpChoice(def: fusion, currentLevel: 0),
];

/// Whether a draft offers REROLL and BANISH: every draft but a keystone's.
bool powerUpDraftHasKeys(List<OfferedPowerUpChoice> choices) =>
    choices.isNotEmpty && !choices.any((c) => c.def.isKeystone);

/// REROLL: three fresh cards in place of [current], by every rule a draft
/// is drawn by. It avoids the cards on the table while there are at least
/// three others to draw from. Spends one of [state]'s rerolls; null, with
/// nothing spent, when there are none left, the draft is a keystone's, or
/// there is nothing to draw.
///
/// A this-or-that draft rerolls into an ordinary one: drawing the same pair
/// again would spend the reroll on nothing.
///
/// A fusion due a card stays on the table: only the drawn cards are drawn
/// again.
List<OfferedPowerUpChoice>? rerollPowerUpDraft(
  PowerUpState state,
  int wave, {
  required List<OfferedPowerUpChoice> current,
  List<CosmicPartyMember> party = const [],
  Set<int> defeatedCompanionSlots = const {},
}) {
  if (state.rerollsLeft <= 0 || !powerUpDraftHasKeys(current)) return null;
  final salt = state.draftRedraws + 1;
  final fusions = _fusionCards(state);
  final fresh = _drawPowerUpChoices(
    state,
    wave,
    rng: Random(wave * 37 + 11 + salt * 7919),
    packLeaderRoll: Random(
      wave * 53 + state.history.length * 7 + 3 + salt * 7919,
    ),
    party: party,
    defeatedCompanionSlots: defeatedCompanionSlots,
    avoid: {for (final c in current) c.def.id},
    count: 3 - fusions.length,
  );
  if (fresh.isEmpty || !state.spendReroll()) return null;
  final draft = [...fusions, ...fresh];
  state.noteOffered(draft);
  return draft;
}

/// BANISH: [current]'s card at [index] is never offered again this run, and
/// a fresh card takes its place (one not already on the table). Spends one
/// of [state]'s banishes; null, with nothing spent, when there are none
/// left, the draft is a keystone's, or banishing would leave nothing to
/// take. When nothing is left to draw, the card goes and the draft is one
/// shorter.
List<OfferedPowerUpChoice>? banishFromPowerUpDraft(
  PowerUpState state,
  int wave, {
  required List<OfferedPowerUpChoice> current,
  required int index,
  List<CosmicPartyMember> party = const [],
  Set<int> defeatedCompanionSlots = const {},
}) {
  if (state.banishesLeft <= 0 || !powerUpDraftHasKeys(current)) return null;
  if (index < 0 || index >= current.length) return null;
  final gone = current[index].def.id;
  final salt = state.draftRedraws + 1;
  final kept = [
    for (var i = 0; i < current.length; i++)
      if (i != index) current[i],
  ];
  final replacement = _drawPowerUpChoices(
    state,
    wave,
    rng: Random(wave * 41 + 17 + salt * 7919),
    party: party,
    defeatedCompanionSlots: defeatedCompanionSlots,
    exclude: {gone, for (final c in kept) c.def.id},
    count: 1,
  );
  if (replacement.isEmpty && kept.isEmpty) return null;
  if (!state.spendBanish(gone)) return null;
  final draft = [
    for (var i = 0; i < current.length; i++)
      if (i != index)
        current[i]
      else if (replacement.isNotEmpty)
        replacement.first,
  ];
  state.noteOffered(draft);
  return draft;
}

/// The draw every draft is made by: up to [count] cards from what the run
/// can take (stack limits, either-or groups, Mystic worlds in the party,
/// nothing banished). [exclude] is never drawn; [avoid] is not drawn while
/// at least three others are left. With [packLeaderRoll], half of draws
/// lead with Pack Leader.
List<OfferedPowerUpChoice> _drawPowerUpChoices(
  PowerUpState state,
  int wave, {
  required Random rng,
  Random? packLeaderRoll,
  required List<CosmicPartyMember> party,
  required Set<int> defeatedCompanionSlots,
  Set<String> exclude = const {},
  Set<String> avoid = const {},
  int count = 3,
}) {
  final companionCount = party.length;
  var available = kAllPowerUps
      .where(
        (def) =>
            !state.isBanished(def.id) &&
            !exclude.contains(def.id) &&
            _mysticWorldIsFielded(def, party) &&
            state.canApply(
              def,
              companionCount: companionCount,
              defeatedCompanionSlots: defeatedCompanionSlots,
            ),
      )
      .toList();
  if (avoid.isNotEmpty) {
    final fresh = available.where((d) => !avoid.contains(d.id)).toList();
    if (fresh.length >= 3) available = fresh;
  }
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

  // A draw that lands on a card already on the table draws again (a few
  // tries per place): skipping it left about a quarter of drafts with two
  // cards.
  var attempts = 0;
  while (chosen.length < count &&
      available.isNotEmpty &&
      attempts < count * 8) {
    final i = attempts++;
    // Half of all drafts lead with Pack Leader (while it can still be taken):
    // another alchemon on the field is the pick that changes a run most, so
    // it should be on the table often rather than on a schedule. Rolled on
    // its own seed so the rest of the draft is unchanged by it.
    if (i == 0 && packLeaderRoll != null && packLeaderRoll.nextDouble() < 0.5) {
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

List<OfferedPowerUpChoice> _buildExclusiveThisOrThatChoice(
  PowerUpState state,
  int wave,
  List<CosmicPartyMember> party,
  Random rng,
  Set<int> defeatedCompanionSlots,
) {
  if (wave < 5 || wave % 6 != 0) return const [];

  const group = 'ship_arsenal_doctrine';
  final groupDefs = kAllPowerUps
      .where((def) => def.choiceGroup == group)
      .toList(growable: false);
  if (groupDefs.length < 2) return const [];

  final canOfferAll = groupDefs.every(
    (def) =>
        !state.isBanished(def.id) &&
        state.canApply(
          def,
          companionCount: party.length,
          defeatedCompanionSlots: defeatedCompanionSlots,
        ),
  );
  if (!canOfferAll) return const [];

  final picks = groupDefs
      .map(
        (def) =>
            _buildOfferedChoice(def, state, party, rng, defeatedCompanionSlots),
      )
      .toList();
  picks.shuffle(rng);
  return picks;
}

/// Whether this surge has something in the party to upgrade.
///
/// A world surge names a specific Mystic element. Offering "Deepening Grove"
/// to a party with no Plant Mystic would burn one of the three draft slots on
/// a pick that does nothing, which is worse than offering nothing at all.
bool _mysticWorldIsFielded(PowerUpDef def, List<CosmicPartyMember> party) {
  final element = def.mysticElement;
  if (element == null) return true;
  return party.any(
    (m) => m.family.toLowerCase() == 'mystic' && m.element == element,
  );
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
    // A world surge belongs to the Mystic whose world it is. Without this the
    // weighting could hand "Deepening Grove" to the Horn standing next to the
    // Plant Mystic, and the pick would do nothing.
    if (def.mysticElement != null &&
        (member.family.toLowerCase() != 'mystic' ||
            member.element != def.mysticElement)) {
      continue;
    }
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
