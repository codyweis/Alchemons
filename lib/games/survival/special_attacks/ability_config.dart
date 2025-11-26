import 'package:flutter/material.dart';

/// Central configuration for all special abilities
/// Makes it easy to balance and see all abilities at once
class AbilitySystemConfig {
  // ============================================================================
  // ABILITY DESCRIPTIONS
  // ============================================================================

  static String getAbilityDescription(String family, String element, int rank) {
    if (rank == 0) {
      return _getBaseDescription(family);
    }

    final key = '${family}_$element';
    return _elementalAbilities[key]?.getDescription(rank) ??
        'Elemental upgrade for $element $family';
  }

  static String _getBaseDescription(String family) {
    switch (family) {
      case 'Let':
        return 'Meteor: Call down a devastating meteor strike';
      case 'Pip':
        return 'Ricochet: Fire bouncing projectiles that chain between enemies';
      case 'Mane':
        return 'Barrage: Unleash rapid-fire elemental volleys';
      case 'Mask':
        return 'Trap Field: Deploy strategic hazard zones';
      case 'Horn':
        return 'Nova: Detonate a protective burst around you';
      case 'Wing':
        return 'Beam: Channel a piercing ray of energy';
      case 'Kin':
        return 'Blessing: Empower the Orb and nearby allies';
      case 'Mystic':
        return 'Orbitals: Summon circling projectiles that seek enemies';
      default:
        return 'Unknown ability';
    }
  }

  // ============================================================================
  // ELEMENTAL ABILITY DEFINITIONS
  // ============================================================================

  static final Map<String, ElementalAbility> _elementalAbilities = {
    // LET ABILITIES - Meteor Strike
    'Let_Fire': ElementalAbility(
      name: 'Inferno Meteor',
      ranks: [
        'Meteor leaves burning crater that damages over time',
        'Burn duration +50%, Meteor splits on impact',
        'Burning enemies explode on death',
        'Meteor becomes fire tornado after impact',
        'PYROCLASM: Massive AOE burn + periodic fire waves',
      ],
    ),
    'Let_Water': ElementalAbility(
      name: 'Tidal Meteor',
      ranks: [
        'Meteor creates slowing puddle, pushes enemies',
        'Puddle size +50%, heals allies who pass through',
        'Meteor bounces once before impact',
        'Creates healing rain after impact',
        'TSUNAMI: Giant wave pushes all enemies + massive slow',
      ],
    ),
    'Let_Earth': ElementalAbility(
      name: 'Seismic Meteor',
      ranks: [
        'Meteor shatters into damaging crystals',
        'Stuns enemies near impact +0.5s',
        'Creates temporary wall segments',
        'Crystals orbit impact site, blocking projectiles',
        'EARTHQUAKE: Map-wide damage + creates barriers',
      ],
    ),
    'Let_Air': ElementalAbility(
      name: 'Storm Meteor',
      ranks: [
        'Meteor falls faster, creates shockwave knockback',
        'Shockwave range +50%, pulls enemies toward center',
        'Leaves tornado that moves randomly',
        'Tornado homes on enemy clusters',
        'HURRICANE: Multiple meteors + persistent storm',
      ],
    ),
    'Let_Lightning': ElementalAbility(
      name: 'Thunder Meteor',
      ranks: [
        'Meteor chains lightning to nearby enemies',
        'Lightning chains +2 times, each stronger',
        'Electrified zone stuns enemies',
        'Creates lightning storm above impact',
        'JUDGMENT: Screen-wide lightning + paralysis',
      ],
    ),
    'Let_Ice': ElementalAbility(
      name: 'Glacier Meteor',
      ranks: [
        'Meteor freezes ground, slowing enemies 80%',
        'Frozen enemies take +30% damage',
        'Chance to fully freeze enemies in zone',
        'Creates ice spikes that erupt periodically',
        'ABSOLUTE ZERO: Freezes all enemies briefly',
      ],
    ),
    'Let_Plant': ElementalAbility(
      name: 'Spore Meteor',
      ranks: [
        'Meteor spawns thorn patch with strong DoT',
        'Thorns spread to nearby areas',
        'Spawns 2 vine allies that root enemies',
        'Vines pull enemies toward center',
        'OVERGROWTH: Massive thorns + permanent vines',
      ],
    ),
    'Let_Poison': ElementalAbility(
      name: 'Toxic Meteor',
      ranks: [
        'Meteor creates poison cloud with heavy DoT',
        'Poison spreads enemy-to-enemy on hit',
        'Poisoned enemies move slower',
        'Cloud persists and follows enemy clusters',
        'PLAGUE: All enemies poisoned + damage multiplier',
      ],
    ),
    'Let_Blood': ElementalAbility(
      name: 'Crimson Meteor',
      ranks: [
        'Meteor drains HP, converts to team heal',
        'Lifesteal +50%, creates blood pool',
        'Blood pool damages enemies, heals allies',
        'Victims bleed, leaving damaging trails',
        'EXSANGUINATE: Drains all visible enemies',
      ],
    ),
    'Let_Spirit': ElementalAbility(
      name: 'Soul Meteor',
      ranks: [
        'Meteor executes low HP enemies (<20%)',
        'Execute threshold +10%, spawns soul fragments',
        'Souls seek enemies, dealing spirit damage',
        'Killing blow releases nova',
        'REAPER: Executes <40% HP + giant soul explosion',
      ],
    ),
    'Let_Dark': ElementalAbility(
      name: 'Void Meteor',
      ranks: [
        'Meteor creates black hole, pulling enemies',
        'Black hole lasts +2s, stronger pull',
        'Enemies in black hole take increasing damage',
        'Creates void rifts that shoot enemies',
        'SINGULARITY: Massive black hole + time dilation',
      ],
    ),
    'Let_Light': ElementalAbility(
      name: 'Holy Meteor',
      ranks: [
        'Meteor damages enemies, heals allies in area',
        'Heal amount +50%, applies regen',
        'Creates light beacon that pulses healing',
        'Allies gain damage buff in beacon',
        'DIVINE WRATH: Huge heal + damage to all enemies',
      ],
    ),
    'Let_Lava': ElementalAbility(
      name: 'Magma Meteor',
      ranks: [
        'Meteor creates lava pools, heavy DoT',
        'Lava spreads outward slowly',
        'Enemies leave lava trails',
        'Lava occasionally erupts upward',
        'VOLCANIC: Entire map becomes lava',
      ],
    ),
    'Let_Steam': ElementalAbility(
      name: 'Vapor Meteor',
      ranks: [
        'Meteor creates steam cloud, blinds enemies',
        'Steam heals allies, damages enemies',
        'Steam applies burn + slow',
        'Pressure builds, creating explosions',
        'GEYSER: Continuous steam eruptions',
      ],
    ),
    'Let_Mud': ElementalAbility(
      name: 'Sludge Meteor',
      ranks: [
        'Meteor creates mud pit, heavily slows enemies',
        'Enemies stuck in mud take +damage',
        'Mud hardens, rooting enemies',
        'Mud spreads to nearby areas',
        'QUICKSAND: All enemies slowed + periodic pulls',
      ],
    ),
    'Let_Dust': ElementalAbility(
      name: 'Sandstorm Meteor',
      ranks: [
        'Meteor creates dust cloud, reducing accuracy',
        'Dust deals chip damage over time',
        'Dust blinds enemies, reducing their range',
        'Creates dust devils that chase enemies',
        'DESERT: Massive sandstorm covers battlefield',
      ],
    ),
    'Let_Crystal': ElementalAbility(
      name: 'Prismatic Meteor',
      ranks: [
        'Meteor shatters into seeking crystal shards',
        'Shards +3, deal more damage',
        'Shards explode on enemy death',
        'Creates crystal prison around enemies',
        'CRYSTALLIZE: Petrifies enemies, shatters for AoE',
      ],
    ),

    // PIP ABILITIES - Ricochet
    'Pip_Fire': ElementalAbility(
      name: 'Ember Ricochet',
      ranks: [
        'Shots leave burning marks on each bounce',
        'Burns stack, +1 bounce',
        'Burning enemies spread fire to nearby',
        'Each bounce creates mini explosion',
        'WILDFIRE: Bounces infinitely, auto-ignites all',
      ],
    ),
    'Pip_Water': ElementalAbility(
      name: 'Splash Ricochet',
      ranks: [
        'Bounces create healing splashes',
        'Heals +50%, slows enemies hit',
        'Creates water trails between bounces',
        '+2 bounces, seeks lowest HP ally',
        'FOUNTAIN: Continuous bouncing healing orbs',
      ],
    ),
    'Pip_Ice': ElementalAbility(
      name: 'Frost Ricochet',
      ranks: [
        'Each bounce slows enemy +20%',
        'Fully frozen enemies after 3 hits',
        'Frozen enemies become bounce targets',
        'Bounces create ice spikes',
        'BLIZZARD: Screen-wide freezing ricochets',
      ],
    ),
    'Pip_Lightning': ElementalAbility(
      name: 'Volt Ricochet',
      ranks: [
        'Bounces chain lightning to +2 targets',
        'Chain damage increases per jump',
        '+2 bounces, increased speed',
        'Creates electric field between bounces',
        'TESLA: Unlimited bounces, massive chain network',
      ],
    ),
    'Pip_Earth': ElementalAbility(
      name: 'Boulder Ricochet',
      ranks: [
        'Heavy shots knock back harder',
        'Creates stone spike on each bounce',
        'Bounces stun briefly (0.3s)',
        'Stone spikes become walls',
        'AVALANCHE: Massive boulders cascade',
      ],
    ),
    'Pip_Plant': ElementalAbility(
      name: 'Thorn Ricochet',
      ranks: [
        'Shots apply bleed DoT',
        'Bounces leave thorn patches',
        'Thorns root enemies briefly',
        '+3 bounces, creates vine network',
        'ENTANGLE: All enemies rooted + continuous thorns',
      ],
    ),
    'Pip_Poison': ElementalAbility(
      name: 'Venom Ricochet',
      ranks: [
        'Poison spreads on each bounce',
        'Poison lasts +50%, damages over time',
        'Poisoned enemies become bounce targets',
        'Poison pools form at bounce points',
        'PANDEMIC: All enemies auto-poisoned + spreading',
      ],
    ),
    'Pip_Air': ElementalAbility(
      name: 'Gust Ricochet',
      ranks: [
        'Bounces travel faster, push enemies',
        '+3 bounces, creates wind currents',
        'Wind currents buff ally speed',
        'Bounces create small tornadoes',
        'CYCLONE: Tornado pulls all enemies to center',
      ],
    ),
    'Pip_Blood': ElementalAbility(
      name: 'Vampiric Ricochet',
      ranks: [
        'Each bounce heals based on damage',
        'Healing +50%, creates blood link',
        'Blood link shares damage between enemies',
        'Low HP enemies become prioritized',
        'TRANSFUSION: Drains all enemies, massive heal',
      ],
    ),
    'Pip_Spirit': ElementalAbility(
      name: 'Phantom Ricochet',
      ranks: [
        'Bounces phase through walls',
        '+2 bounces, leaves spirit marks',
        'Spirit marks explode when enemy dies',
        'Bounces summon ghost copies',
        'HAUNTING: Spirits bounce infinitely',
      ],
    ),
    'Pip_Dark': ElementalAbility(
      name: 'Shadow Ricochet',
      ranks: [
        'Bounces drain enemy speed',
        'Each bounce adds entropy debuff',
        'Dark shots create blind zones',
        '+4 bounces, prioritizes strongest enemy',
        'ECLIPSE: All enemies slowed + continuous dark bounces',
      ],
    ),
    'Pip_Light': ElementalAbility(
      name: 'Radiant Ricochet',
      ranks: [
        'Bounces heal allies they pass near',
        'Heal +50%, applies regen buff',
        'Light shots reveal stealthed enemies',
        'Each bounce creates light orb ally',
        'REVELATION: Massive healing + damage pulses',
      ],
    ),
    'Pip_Lava': ElementalAbility(
      name: 'Molten Ricochet',
      ranks: [
        'Bounces leave lava puddles',
        'Lava damage +50%, spreads',
        '+2 bounces, enemies leave lava trails',
        'Lava occasionally shoots projectiles',
        'INFERNO: Entire path becomes lava river',
      ],
    ),
    'Pip_Steam': ElementalAbility(
      name: 'Pressure Ricochet',
      ranks: [
        'Bounces create steam puffs',
        'Steam heals allies, burns enemies',
        '+2 bounces, steam builds pressure',
        'Pressure releases in explosions',
        'BOILER: Continuous pressure explosions',
      ],
    ),
    'Pip_Mud': ElementalAbility(
      name: 'Bog Ricochet',
      ranks: [
        'Bounces slow enemies significantly',
        '+2 bounces, creates mud puddles',
        'Mud roots enemies periodically',
        'Rooted enemies take +damage',
        'SWAMP: All movement heavily slowed',
      ],
    ),
    'Pip_Dust': ElementalAbility(
      name: 'Sandblast Ricochet',
      ranks: [
        'Bounces reduce enemy accuracy',
        '+3 bounces, creates dust clouds',
        'Dust damages over time',
        'Clouds blind enemies completely',
        'SANDSTORM: Screen-wide dust damage',
      ],
    ),
    'Pip_Crystal': ElementalAbility(
      name: 'Shard Ricochet',
      ranks: [
        'Bounces split into smaller shards',
        'Shards +2, deal crit damage',
        '+3 bounces, shards seek enemies',
        'Shards explode on contact',
        'PRISM: Infinite splitting shards',
      ],
    ),

    // MANE ABILITIES - Barrage (Damage Dealers)
    'Mane_Fire': ElementalAbility(
      name: 'Flame Barrage',
      ranks: [
        'Rapid fire creates burning field forward',
        '+3 projectiles, burns last longer',
        'Burning field pulses damage',
        'Each shot has chance to ignite all nearby',
        'INFERNO BARRAGE: Massive damage wave + ignition',
      ],
    ),
    'Mane_Ice': ElementalAbility(
      name: 'Frost Barrage',
      ranks: [
        'Rapid shots slow enemies progressively',
        '+3 projectiles, freeze on 3rd hit',
        'Frozen enemies shatter on death',
        'Creates ice wall after barrage',
        'GLACIER BARRAGE: Screen freeze + ice walls',
      ],
    ),
    'Mane_Lightning': ElementalAbility(
      name: 'Storm Barrage',
      ranks: [
        'Shots chain to +1 nearby enemy',
        '+4 projectiles, chains +2 times',
        'Lightning marks enemies for focus fire',
        'Marked enemies take +50% damage',
        'TEMPEST BARRAGE: Unlimited chains',
      ],
    ),
    'Mane_Earth': ElementalAbility(
      name: 'Boulder Barrage',
      ranks: [
        'Heavy shots pierce first enemy',
        '+3 projectiles, knockback increased',
        'Pierces all enemies in line',
        'Creates stone spikes on impact',
        'AVALANCHE BARRAGE: Giant boulders crush all',
      ],
    ),
    'Mane_Plant': ElementalAbility(
      name: 'Thorn Barrage',
      ranks: [
        'Shots apply bleed and slow',
        '+5 projectiles, bleeds stack',
        'Creates thorny zone forward',
        'Thorns root enemies periodically',
        'BLOOM BARRAGE: Covers field in thorns',
      ],
    ),
    'Mane_Poison': ElementalAbility(
      name: 'Toxin Barrage',
      ranks: [
        'Shots poison in cone area',
        '+4 projectiles, poison spreads faster',
        'Poison cloud forms after barrage',
        'Cloud follows enemy clusters',
        'PLAGUE BARRAGE: All enemies poisoned instantly',
      ],
    ),
    'Mane_Water': ElementalAbility(
      name: 'Torrent Barrage',
      ranks: [
        'Shots push enemies backward',
        '+4 projectiles, creates wave',
        'Wave slows and damages',
        'Allies in wave get speed buff',
        'TSUNAMI BARRAGE: Massive wave clears field',
      ],
    ),
    'Mane_Air': ElementalAbility(
      name: 'Gale Barrage',
      ranks: [
        'Rapid wind shots push enemies',
        '+6 projectiles, creates tornado',
        'Tornado pulls enemies to center',
        'Tornado lasts after barrage',
        'HURRICANE BARRAGE: Multiple tornadoes',
      ],
    ),
    'Mane_Blood': ElementalAbility(
      name: 'Hemorrhage Barrage',
      ranks: [
        'Shots drain HP, heal Orb',
        '+4 projectiles, lifesteal +50%',
        'Creates blood fountain that heals allies',
        'Drained enemies bleed trails',
        'EXSANGUINATION: All enemies drained',
      ],
    ),
    'Mane_Spirit': ElementalAbility(
      name: 'Spectral Barrage',
      ranks: [
        'Shots phase through first enemy',
        '+5 projectiles, hit multiple targets',
        'Summons ghost that mimics barrage',
        'Ghost lasts 10s, auto-targets',
        'HAUNTING: Multiple permanent ghosts',
      ],
    ),
    'Mane_Dark': ElementalAbility(
      name: 'Shadow Barrage',
      ranks: [
        'Shots reduce enemy speed and damage',
        '+4 projectiles, creates darkness zone',
        'Zone blinds enemies, buffs allies',
        'Darkness spreads outward',
        'ECLIPSE: Screen-wide darkness + debuff',
      ],
    ),
    'Mane_Light': ElementalAbility(
      name: 'Radiant Barrage',
      ranks: [
        'Shots damage enemies, heal nearby allies',
        '+5 projectiles, healing +50%',
        'Creates light beam that pierces',
        'Beam applies regen to allies',
        'DIVINITY: Massive heal + damage beam',
      ],
    ),
    'Mane_Lava': ElementalAbility(
      name: 'Magma Barrage',
      ranks: [
        'Shots create lava puddles',
        '+4 projectiles, puddles spread',
        'Enemies in lava burn longer',
        'Lava occasionally erupts',
        'VOLCANIC: All ground becomes lava',
      ],
    ),
    'Mane_Steam': ElementalAbility(
      name: 'Vapor Barrage',
      ranks: [
        'Shots create steam that obscures',
        '+5 projectiles, steam heals allies',
        'Steam builds pressure, explodes',
        'Continuous steam field',
        'GEYSER: Massive steam explosions',
      ],
    ),
    'Mane_Mud': ElementalAbility(
      name: 'Sludge Barrage',
      ranks: [
        'Shots slow and cover ground in mud',
        '+4 projectiles, mud spreads faster',
        'Enemies stuck take +30% damage',
        'Mud hardens, rooting enemies',
        'QUAGMIRE: Entire field becomes mud',
      ],
    ),
    'Mane_Dust': ElementalAbility(
      name: 'Dust Barrage',
      ranks: [
        'Shots create blinding dust clouds',
        '+6 projectiles, clouds last longer',
        'Dust damages over time',
        'Creates sandstorm that moves',
        'DESERT: Entire screen dust storm',
      ],
    ),
    'Mane_Crystal': ElementalAbility(
      name: 'Shard Barrage',
      ranks: [
        'Shots shatter into smaller projectiles',
        '+4 projectiles, +3 shards each',
        'Shards crit for double damage',
        'Creates crystal field that reflects shots',
        'PRISM: Infinite shard cascade',
      ],
    ),

    // MASK ABILITIES - Trap Field (Changed from pull to traps)
    'Mask_Fire': ElementalAbility(
      name: 'Flame Trap',
      ranks: [
        'Deploy fire trap that ignites on trigger',
        '+2 traps, burn lasts longer',
        'Burning enemies trigger nearby traps',
        'Traps leave permanent fire zones',
        'INFERNO GRID: All traps interconnected fire',
      ],
    ),
    'Mask_Ice': ElementalAbility(
      name: 'Freeze Trap',
      ranks: [
        'Deploy ice trap that freezes on trigger',
        '+2 traps, freeze duration +50%',
        'Frozen enemies explode, damaging nearby',
        'Traps create ice walls',
        'PERMAFROST: Freezes entire areas',
      ],
    ),
    'Mask_Lightning': ElementalAbility(
      name: 'Shock Trap',
      ranks: [
        'Deploy trap that chains lightning',
        '+3 traps, chains to more targets',
        'Chained enemies stunned briefly',
        'Traps create electric fence',
        'TESLA GRID: Unlimited chain network',
      ],
    ),
    'Mask_Earth': ElementalAbility(
      name: 'Spike Trap',
      ranks: [
        'Deploy trap that creates spike pillars',
        '+2 traps, spikes knock up',
        'Knocked enemies stunned on landing',
        'Traps create barrier walls',
        'FORTRESS: Massive spike maze',
      ],
    ),
    'Mask_Plant': ElementalAbility(
      name: 'Vine Trap',
      ranks: [
        'Deploy trap that roots enemies',
        '+3 traps, root duration +50%',
        'Rooted enemies take DoT',
        'Vines spread between traps',
        'GARDEN: Entire field covered in roots',
      ],
    ),
    'Mask_Poison': ElementalAbility(
      name: 'Toxin Trap',
      ranks: [
        'Deploy trap releasing poison cloud',
        '+2 traps, poison spreads enemy-to-enemy',
        'Poisoned enemies slow significantly',
        'Clouds merge into mega-cloud',
        'PANDEMIC: Auto-poison all enemies',
      ],
    ),
    'Mask_Water': ElementalAbility(
      name: 'Geyser Trap',
      ranks: [
        'Deploy trap that launches enemies up',
        '+2 traps, creates water puddles',
        'Puddles slow and heal allies',
        'Geysers erupt periodically',
        'FOUNTAIN: Continuous eruptions',
      ],
    ),
    'Mask_Air': ElementalAbility(
      name: 'Wind Trap',
      ranks: [
        'Deploy trap that creates tornado',
        '+2 traps, tornadoes pull harder',
        'Pulled enemies take damage',
        'Tornadoes move toward enemies',
        'HURRICANE: Multiple mega-tornadoes',
      ],
    ),
    'Mask_Blood': ElementalAbility(
      name: 'Drain Trap',
      ranks: [
        'Deploy trap that leeches HP',
        '+3 traps, lifesteal converts to heal',
        'Drained enemies leave blood pools',
        'Pools damage and heal simultaneously',
        'EXSANGUINATE: All enemies drained',
      ],
    ),
    'Mask_Spirit': ElementalAbility(
      name: 'Ghost Trap',
      ranks: [
        'Deploy trap that spawns attacking spirit',
        '+2 traps, spirits last longer',
        'Spirits drain enemy damage',
        'Multiple spirits link attacks',
        'HAUNTED: Permanent spirit army',
      ],
    ),
    'Mask_Dark': ElementalAbility(
      name: 'Void Trap',
      ranks: [
        'Deploy trap creating mini black hole',
        '+2 traps, pull strength +50%',
        'Pulled enemies take increasing damage',
        'Black holes merge when close',
        'SINGULARITY: Mega black hole center',
      ],
    ),
    'Mask_Light': ElementalAbility(
      name: 'Radiance Trap',
      ranks: [
        'Deploy trap that blinds and damages',
        '+3 traps, heals nearby allies',
        'Blind enemies miss attacks',
        'Traps create light beacon',
        'REVELATION: Screen-wide blind + heal',
      ],
    ),
    'Mask_Lava': ElementalAbility(
      name: 'Magma Trap',
      ranks: [
        'Deploy trap creating lava pool',
        '+2 traps, pools spread slowly',
        'Pools erupt occasionally',
        'Eruptions knock back enemies',
        'VOLCANIC: All ground becomes lava',
      ],
    ),
    'Mask_Steam': ElementalAbility(
      name: 'Pressure Trap',
      ranks: [
        'Deploy trap building steam pressure',
        '+3 traps, explode when full',
        'Steam heals allies, burns enemies',
        'Explosions chain to nearby traps',
        'BOILER: Continuous chain explosions',
      ],
    ),
    'Mask_Mud': ElementalAbility(
      name: 'Quicksand Trap',
      ranks: [
        'Deploy trap creating mud pit',
        '+2 traps, heavily slows enemies',
        'Slowed enemies take +30% damage',
        'Mud hardens, rooting completely',
        'QUAGMIRE: Entire field mud',
      ],
    ),
    'Mask_Dust': ElementalAbility(
      name: 'Dust Trap',
      ranks: [
        'Deploy trap creating dust cloud',
        '+3 traps, reduces enemy accuracy',
        'Clouds deal chip damage',
        'Clouds blind enemies',
        'SANDSTORM: Screen-wide dust',
      ],
    ),
    'Mask_Crystal': ElementalAbility(
      name: 'Prism Trap',
      ranks: [
        'Deploy trap shooting crystal shards',
        '+2 traps, shards pierce enemies',
        'Shards reflect between traps',
        'Creates crystal prison',
        'CRYSTALLIZE: Petrifies all enemies',
      ],
    ),

    // HORN ABILITIES - Nova
    'Horn_Fire': ElementalAbility(
      name: 'Flame Nova',
      ranks: [
        'Nova ignites all nearby enemies',
        'Ignited enemies burn longer, +range',
        'Burning enemies explode on death',
        'Nova creates fire shield',
        'SUPERNOVA: Map-wide burn + shield all allies',
      ],
    ),
    'Horn_Water': ElementalAbility(
      name: 'Tidal Nova',
      ranks: [
        'Nova pushes enemies and slows',
        'Push +50%, creates water shield',
        'Shield heals allies inside',
        'Wave knocks down enemies',
        'TSUNAMI: Massive push + team heal',
      ],
    ),
    'Horn_Ice': ElementalAbility(
      name: 'Frost Nova',
      ranks: [
        'Nova freezes ground and slows',
        'Frozen ground lasts longer, full freeze chance',
        'Creates ice armor (+defense)',
        'Ice shards shoot outward',
        'ABSOLUTE ZERO: Full freeze + ice fortress',
      ],
    ),
    'Horn_Lightning': ElementalAbility(
      name: 'Thunder Nova',
      ranks: [
        'Nova chains lightning to all nearby',
        'Chains stun briefly, +damage',
        'Creates electric barrier',
        'Barrier shocks attacking enemies',
        'JUDGMENT: Screen-wide lightning + paralysis',
      ],
    ),
    'Horn_Earth': ElementalAbility(
      name: 'Seismic Nova',
      ranks: [
        'Nova creates stone shield, damages enemies',
        'Shield lasts longer, reflects projectiles',
        'Creates spike ring around you',
        'Spikes stun on contact',
        'FORTRESS: Massive walls + permanent shield',
      ],
    ),
    'Horn_Plant': ElementalAbility(
      name: 'Thorn Nova',
      ranks: [
        'Nova shoots thorns, applies bleed',
        'Thorns +50%, creates thorn barrier',
        'Barrier damages melee attackers',
        'Thorns root enemies briefly',
        'BLOOM: Screen-wide thorns + healing',
      ],
    ),
    'Horn_Poison': ElementalAbility(
      name: 'Toxic Nova',
      ranks: [
        'Nova releases poison cloud',
        'Cloud lasts longer, spreads',
        'Creates poison shield',
        'Shield infects attackers',
        'PLAGUE: All enemies poisoned + mega cloud',
      ],
    ),
    'Horn_Air': ElementalAbility(
      name: 'Gale Nova',
      ranks: [
        'Nova creates strong wind push',
        'Wind +50% range, lifts enemies',
        'Creates wind barrier',
        'Barrier pushes projectiles back',
        'HURRICANE: Massive tornado + flight',
      ],
    ),
    'Horn_Blood': ElementalAbility(
      name: 'Blood Nova',
      ranks: [
        'Nova drains nearby enemies, heals you',
        'Lifesteal +50%, creates blood shield',
        'Shield absorbs damage, converts to healing',
        'Drained enemies weakened',
        'TRANSFUSION: Drain all + massive heal',
      ],
    ),
    'Horn_Spirit': ElementalAbility(
      name: 'Spirit Nova',
      ranks: [
        'Nova damages and creates spirit shield',
        'Shield +50%, blocks projectiles',
        'Summons spirit guardians',
        'Guardians attack nearby enemies',
        'ASCENSION: Invulnerable + spirit army',
      ],
    ),
    'Horn_Dark': ElementalAbility(
      name: 'Void Nova',
      ranks: [
        'Nova creates darkness, slows enemies',
        'Darkness +range, enemies deal less damage',
        'Creates void shield that absorbs damage',
        'Shield releases damage absorbed',
        'ECLIPSE: All enemies blinded + massive debuff',
      ],
    ),
    'Horn_Light': ElementalAbility(
      name: 'Holy Nova',
      ranks: [
        'Nova damages enemies, heals allies',
        'Heal +50%, applies regen',
        'Creates light shield that reflects',
        'Shield damages attackers',
        'DIVINITY: Massive heal + damage + resurrect',
      ],
    ),
    'Horn_Lava': ElementalAbility(
      name: 'Magma Nova',
      ranks: [
        'Nova creates lava ring around you',
        'Lava +duration, spreads outward',
        'Creates molten shield',
        'Shield burns melee attackers',
        'VOLCANIC: Lava field + fire armor',
      ],
    ),
    'Horn_Steam': ElementalAbility(
      name: 'Steam Nova',
      ranks: [
        'Nova releases steam, obscures and heals',
        'Steam +size, burns enemies',
        'Creates pressure shield',
        'Shield explodes when broken',
        'GEYSER: Continuous steam + explosions',
      ],
    ),
    'Horn_Mud': ElementalAbility(
      name: 'Mud Nova',
      ranks: [
        'Nova creates mud field, heavily slows',
        'Mud +range, enemies stuck',
        'Creates mud armor (+defense)',
        'Armor slows attackers',
        'QUAGMIRE: Entire field mud + root',
      ],
    ),
    'Horn_Dust': ElementalAbility(
      name: 'Dust Nova',
      ranks: [
        'Nova creates dust cloud, reduces accuracy',
        'Cloud +size, deals DoT',
        'Creates dust shield that blinds',
        'Shield damages over time',
        'SANDSTORM: Massive cloud + blind all',
      ],
    ),
    'Horn_Crystal': ElementalAbility(
      name: 'Crystal Nova',
      ranks: [
        'Nova shoots crystal shards outward',
        'Shards +amount, pierce enemies',
        'Creates crystal shield that reflects',
        'Shield shatters for AoE damage',
        'PRISM: Infinite shards + fortress',
      ],
    ),

    // WING ABILITIES - Beam
    'Wing_Fire': ElementalAbility(
      name: 'Flame Beam',
      ranks: [
        'Beam leaves burning line',
        'Burn +duration, beam wider',
        'Burning enemies take +50% beam damage',
        'Beam splits into three',
        'SOLAR FLARE: Screen-wide fire beam',
      ],
    ),
    'Wing_Water': ElementalAbility(
      name: 'Hydro Beam',
      ranks: [
        'Beam pushes enemies backward',
        'Push +50%, heals allies near path',
        'Creates water trail that slows',
        'Beam splits and seeks enemies',
        'TSUNAMI: Massive wave beam',
      ],
    ),
    'Wing_Ice': ElementalAbility(
      name: 'Cryo Beam',
      ranks: [
        'Beam freezes enemies progressively',
        'Full freeze faster, +width',
        'Frozen enemies shatter',
        'Beam creates ice walls on sides',
        'GLACIER: Massive freeze beam',
      ],
    ),
    'Wing_Lightning': ElementalAbility(
      name: 'Thunder Beam',
      ranks: [
        'Beam chains to nearby enemies',
        'Chains +2 times, stuns briefly',
        'Creates electric field along path',
        'Field damages over time',
        'JUDGMENT: Screen-wide lightning',
      ],
    ),
    'Wing_Earth': ElementalAbility(
      name: 'Seismic Beam',
      ranks: [
        'Beam knocks enemies back heavily',
        'Knockback +50%, creates stone trail',
        'Trail blocks enemy movement',
        'Beam pierces all enemies',
        'EARTHQUAKE: Map-wide shockwave',
      ],
    ),
    'Wing_Plant': ElementalAbility(
      name: 'Thorn Beam',
      ranks: [
        'Beam applies strong bleed',
        'Bleed +duration, creates thorn path',
        'Path roots enemies',
        'Rooted enemies take +damage',
        'OVERGROWTH: Massive thorn beam',
      ],
    ),
    'Wing_Poison': ElementalAbility(
      name: 'Venom Beam',
      ranks: [
        'Beam poisons all hit enemies',
        'Poison spreads to nearby, +damage',
        'Creates poison trail',
        'Trail persists and spreads',
        'PLAGUE: All enemies auto-poisoned',
      ],
    ),
    'Wing_Air': ElementalAbility(
      name: 'Gale Beam',
      ranks: [
        'Beam pushes enemies strongly',
        'Creates wind tunnel, buffs allies',
        'Tunnel damages enemies inside',
        'Beam curves toward enemies',
        'HURRICANE: Tornado beam',
      ],
    ),
    'Wing_Blood': ElementalAbility(
      name: 'Hemorrhage Beam',
      ranks: [
        'Beam drains HP, converts to healing',
        'Lifesteal +50%, beam wider',
        'Creates blood river that heals allies',
        'River damages enemies',
        'EXSANGUINATE: Massive drain beam',
      ],
    ),
    'Wing_Spirit': ElementalAbility(
      name: 'Phantom Beam',
      ranks: [
        'Beam phases through enemies, hits all',
        'Summons spirit that mimics beam',
        'Spirit beam seeks enemies',
        'Multiple spirits channel together',
        'HAUNTING: Permanent spirit beams',
      ],
    ),
    'Wing_Dark': ElementalAbility(
      name: 'Shadow Beam',
      ranks: [
        'Beam reduces enemy damage output',
        'Creates darkness zone, blind enemies',
        'Zone expands slowly',
        'Blinded enemies take +damage',
        'ECLIPSE: Screen-wide darkness',
      ],
    ),
    'Wing_Light': ElementalAbility(
      name: 'Holy Beam',
      ranks: [
        'Beam damages enemies, heals allies',
        'Heal +50%, applies regen',
        'Creates light path that buffs allies',
        'Path reveals hidden enemies',
        'DIVINITY: Massive heal + damage beam',
      ],
    ),
    'Wing_Lava': ElementalAbility(
      name: 'Magma Beam',
      ranks: [
        'Beam creates lava trail',
        'Trail +duration, spreads wider',
        'Lava erupts along path',
        'Eruptions knock back',
        'VOLCANIC: Entire path lava river',
      ],
    ),
    'Wing_Steam': ElementalAbility(
      name: 'Vapor Beam',
      ranks: [
        'Beam creates steam, obscures enemies',
        'Steam heals allies, burns enemies',
        'Steam builds pressure',
        'Pressure explodes periodically',
        'GEYSER: Continuous steam explosions',
      ],
    ),
    'Wing_Mud': ElementalAbility(
      name: 'Sludge Beam',
      ranks: [
        'Beam creates mud trail, slows heavily',
        'Trail +width, enemies stuck',
        'Stuck enemies take +damage',
        'Mud hardens, roots enemies',
        'QUAGMIRE: All enemies rooted',
      ],
    ),
    'Wing_Dust': ElementalAbility(
      name: 'Sandblast Beam',
      ranks: [
        'Beam creates dust, reduces accuracy',
        'Dust +size, deals DoT',
        'Creates sandstorm along path',
        'Storm blinds completely',
        'DESERT: Massive sandstorm beam',
      ],
    ),
    'Wing_Crystal': ElementalAbility(
      name: 'Prism Beam',
      ranks: [
        'Beam splits into multiple crystal rays',
        'Rays +3, seek enemies',
        'Creates crystal field that reflects',
        'Reflected beams crit',
        'REFRACTION: Infinite beam network',
      ],
    ),

    // KIN ABILITIES - Blessing
    'Kin_Fire': ElementalAbility(
      name: 'Flame Blessing',
      ranks: [
        'Heals Orb, burns nearby enemies',
        'Heal +50%, burn +range',
        'Burning enemies spread fire',
        'Creates fire aura around Orb',
        'INFERNO: Massive heal + map burn',
      ],
    ),
    'Kin_Water': ElementalAbility(
      name: 'Tidal Blessing',
      ranks: [
        'Heals Orb, applies regen to allies',
        'Regen +50%, creates water aura',
        'Aura slows nearby enemies',
        'Aura pulses healing waves',
        'FOUNTAIN: Continuous massive healing',
      ],
    ),
    'Kin_Ice': ElementalAbility(
      name: 'Frost Blessing',
      ranks: [
        'Heals Orb, slows nearby enemies',
        'Heal +50%, freeze chance',
        'Creates ice aura that shields',
        'Shield reflects projectiles',
        'GLACIER: Massive heal + freeze field',
      ],
    ),
    'Kin_Lightning': ElementalAbility(
      name: 'Storm Blessing',
      ranks: [
        'Heals Orb, shocks nearby enemies',
        'Heal +50%, chains to more enemies',
        'Creates electric aura',
        'Aura stuns on contact',
        'TEMPEST: Massive heal + lightning field',
      ],
    ),
    'Kin_Earth': ElementalAbility(
      name: 'Stone Blessing',
      ranks: [
        'Heals Orb, grants temporary shield',
        'Shield +duration, blocks projectiles',
        'Creates stone aura that reflects',
        'Aura creates spike barriers',
        'FORTRESS: Massive heal + walls',
      ],
    ),
    'Kin_Plant': ElementalAbility(
      name: 'Growth Blessing',
      ranks: [
        'Heals Orb, applies regen to all allies',
        'Regen +100%, creates thorn aura',
        'Aura damages melee attackers',
        'Spawns vine allies',
        'BLOOM: Massive heal + vine army',
      ],
    ),
    'Kin_Poison': ElementalAbility(
      name: 'Venom Blessing',
      ranks: [
        'Heals Orb, poisons nearby enemies',
        'Heal +50%, poison spreads faster',
        'Creates toxic aura',
        'Aura infects attackers',
        'PLAGUE: Massive heal + all poisoned',
      ],
    ),
    'Kin_Air': ElementalAbility(
      name: 'Wind Blessing',
      ranks: [
        'Heals Orb, pushes nearby enemies',
        'Heal +50%, creates wind aura',
        'Aura buffs ally speed +30%',
        'Wind pushes projectiles away',
        'HURRICANE: Massive heal + tornado shield',
      ],
    ),
    'Kin_Blood': ElementalAbility(
      name: 'Blood Blessing',
      ranks: [
        'Drains nearby enemies, heals Orb',
        'Lifesteal +100%, creates blood aura',
        'Aura absorbs damage',
        'Absorbed damage converts to healing',
        'TRANSFUSION: Drain all + mega heal',
      ],
    ),
    'Kin_Spirit': ElementalAbility(
      name: 'Spirit Blessing',
      ranks: [
        'Heals Orb, damages nearby enemies',
        'Heal +50%, summons spirit guardians',
        'Guardians protect Orb',
        'Guardian count +2',
        'ASCENSION: Massive heal + spirit army',
      ],
    ),
    'Kin_Dark': ElementalAbility(
      name: 'Void Blessing',
      ranks: [
        'Heals Orb, drains nearby enemies',
        'Heal +50%, creates darkness aura',
        'Aura reduces enemy damage',
        'Aura blinds enemies',
        'ECLIPSE: Massive heal + all blind',
      ],
    ),
    'Kin_Light': ElementalAbility(
      name: 'Holy Blessing',
      ranks: [
        'Massive Orb + ally heal',
        'Heal +100%, applies regen',
        'Creates light aura that damages enemies',
        'Aura resurrects dead allies (once)',
        'DIVINITY: Screen heal + damage + shield',
      ],
    ),
    'Kin_Lava': ElementalAbility(
      name: 'Magma Blessing',
      ranks: [
        'Heals Orb, creates lava ring',
        'Heal +50%, ring spreads',
        'Creates molten aura',
        'Aura burns melee attackers',
        'VOLCANIC: Massive heal + lava field',
      ],
    ),
    'Kin_Steam': ElementalAbility(
      name: 'Vapor Blessing',
      ranks: [
        'Heals Orb, creates steam cloud',
        'Heal +50%, steam heals allies',
        'Creates pressure aura',
        'Aura explodes when attacked',
        'GEYSER: Continuous healing + explosions',
      ],
    ),
    'Kin_Mud': ElementalAbility(
      name: 'Earth Blessing',
      ranks: [
        'Heals Orb, creates mud field',
        'Heal +50%, heavily slows enemies',
        'Creates mud aura',
        'Aura roots attackers',
        'QUAGMIRE: Massive heal + all rooted',
      ],
    ),
    'Kin_Dust': ElementalAbility(
      name: 'Sand Blessing',
      ranks: [
        'Heals Orb, creates dust cloud',
        'Heal +50%, cloud blinds enemies',
        'Creates dust aura that damages',
        'Aura reduces accuracy',
        'SANDSTORM: Massive heal + blind all',
      ],
    ),
    'Kin_Crystal': ElementalAbility(
      name: 'Prism Blessing',
      ranks: [
        'Heals Orb, creates crystal shield',
        'Shield reflects projectiles, +duration',
        'Creates crystal aura',
        'Aura shoots shards',
        'CRYSTALLIZE: Massive heal + fortress',
      ],
    ),

    // MYSTIC ABILITIES - Orbitals
    'Mystic_Fire': ElementalAbility(
      name: 'Ember Orbitals',
      ranks: [
        'Orbitals leave burn on hit',
        '+1 orbital, burn spreads',
        'Burning enemies take +damage from orbitals',
        'Orbitals explode on contact',
        'INFERNO: Many orbitals + fire trails',
      ],
    ),
    'Mystic_Water': ElementalAbility(
      name: 'Aqua Orbitals',
      ranks: [
        'Orbitals heal allies they pass',
        '+1 orbital, heal +50%',
        'Creates water trail that slows enemies',
        'Trail heals continuously',
        'FOUNTAIN: Many orbitals + healing field',
      ],
    ),
    'Mystic_Ice': ElementalAbility(
      name: 'Frost Orbitals',
      ranks: [
        'Orbitals slow enemies hit',
        '+1 orbital, freeze on 3rd hit',
        'Frozen enemies shatter spreading damage',
        'Orbitals create ice trail',
        'BLIZZARD: Many orbitals + freeze field',
      ],
    ),
    'Mystic_Lightning': ElementalAbility(
      name: 'Volt Orbitals',
      ranks: [
        'Orbitals chain lightning',
        '+2 orbitals, chain +2 times',
        'Chains stun briefly',
        'Orbitals connect with electric arcs',
        'TEMPEST: Many orbitals + lightning web',
      ],
    ),
    'Mystic_Earth': ElementalAbility(
      name: 'Stone Orbitals',
      ranks: [
        'Orbitals knock back enemies',
        '+1 orbital, create spike on hit',
        'Spikes stun enemies',
        'Orbitals leave stone trails',
        'FORTRESS: Many orbitals + barriers',
      ],
    ),
    'Mystic_Plant': ElementalAbility(
      name: 'Thorn Orbitals',
      ranks: [
        'Orbitals apply bleed DoT',
        '+2 orbitals, bleed stacks',
        'Bleeding enemies rooted briefly',
        'Orbitals spawn mini vine allies',
        'BLOOM: Many orbitals + vine army',
      ],
    ),
    'Mystic_Poison': ElementalAbility(
      name: 'Toxic Orbitals',
      ranks: [
        'Orbitals poison on hit',
        '+1 orbital, poison spreads',
        'Poisoned enemies slow',
        'Orbitals create poison cloud',
        'PLAGUE: Many orbitals + poison field',
      ],
    ),
    'Mystic_Air': ElementalAbility(
      name: 'Wind Orbitals',
      ranks: [
        'Orbitals push enemies away',
        '+2 orbitals, speed +50%',
        'Create wind current around you',
        'Current buffs ally speed',
        'HURRICANE: Many orbitals + tornado',
      ],
    ),
    'Mystic_Blood': ElementalAbility(
      name: 'Crimson Orbitals',
      ranks: [
        'Orbitals drain HP, heal you',
        '+1 orbital, lifesteal +50%',
        'Create blood link between orbitals',
        'Link damages enemies crossing',
        'TRANSFUSION: Many orbitals + drain field',
      ],
    ),
    'Mystic_Spirit': ElementalAbility(
      name: 'Phantom Orbitals',
      ranks: [
        'Orbitals phase through enemies',
        '+2 orbitals, leave spirit mark',
        'Marked enemies take +damage',
        'Orbitals spawn ghost copies',
        'HAUNTING: Infinite ghost orbitals',
      ],
    ),
    'Mystic_Dark': ElementalAbility(
      name: 'Shadow Orbitals',
      ranks: [
        'Orbitals drain enemy speed',
        '+1 orbital, reduce enemy damage',
        'Create darkness field',
        'Field blinds enemies',
        'ECLIPSE: Many orbitals + void field',
      ],
    ),
    'Mystic_Light': ElementalAbility(
      name: 'Radiant Orbitals',
      ranks: [
        'Orbitals damage and heal',
        '+2 orbitals, heal +50%',
        'Create light aura around you',
        'Aura damages enemies, buffs allies',
        'DIVINITY: Many orbitals + blessing field',
      ],
    ),
    'Mystic_Lava': ElementalAbility(
      name: 'Magma Orbitals',
      ranks: [
        'Orbitals leave lava puddles',
        '+1 orbital, puddles spread',
        'Lava deals heavy DoT',
        'Orbitals occasionally erupt',
        'VOLCANIC: Many orbitals + lava field',
      ],
    ),
    'Mystic_Steam': ElementalAbility(
      name: 'Vapor Orbitals',
      ranks: [
        'Orbitals create steam puffs',
        '+2 orbitals, steam heals allies',
        'Steam builds pressure',
        'Pressure explodes periodically',
        'GEYSER: Many orbitals + steam field',
      ],
    ),
    'Mystic_Mud': ElementalAbility(
      name: 'Sludge Orbitals',
      ranks: [
        'Orbitals slow enemies significantly',
        '+1 orbital, create mud patches',
        'Mud roots enemies',
        'Rooted enemies take +damage',
        'QUAGMIRE: Many orbitals + mud field',
      ],
    ),
    'Mystic_Dust': ElementalAbility(
      name: 'Sand Orbitals',
      ranks: [
        'Orbitals create dust clouds',
        '+2 orbitals, reduce enemy accuracy',
        'Clouds deal DoT',
        'Clouds blind completely',
        'SANDSTORM: Many orbitals + dust field',
      ],
    ),
    'Mystic_Crystal': ElementalAbility(
      name: 'Prism Orbitals',
      ranks: [
        'Orbitals split into shards on hit',
        '+1 orbital, +3 shards each',
        'Shards seek enemies',
        'Shards reflect between orbitals',
        'REFRACTION: Many orbitals + shard storm',
      ],
    ),
  };

  // ============================================================================
  // STAT DESCRIPTIONS
  // ============================================================================

  static String getStatDescription(String stat) {
    switch (stat) {
      case 'maxHp':
        return 'Increases maximum health';
      case 'strength':
        return 'Increases physical damage and attack power';
      case 'intelligence':
        return 'Increases range and elemental effectiveness';
      case 'beauty':
        return 'Increases elemental damage and special ability power';
      default:
        return 'Unknown stat';
    }
  }

  // ============================================================================
  // PASSIVE EFFECT DESCRIPTIONS
  // ============================================================================

  static String getPassiveEffectDescription(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
        return 'Burn: Damage over time that stacks';
      case 'Ice':
      case 'Water':
      case 'Steam':
        return 'Chill: Slows enemies and minor knockback';
      case 'Poison':
      case 'Dark':
        return 'Poison: Long duration damage over time';
      case 'Lightning':
      case 'Crystal':
      case 'Light':
        return 'Shock: Chance for bonus critical damage';
      case 'Earth':
      case 'Plant':
      case 'Dust':
        return 'Impact: Chance to stun briefly';
      case 'Air':
        return 'Gust: Pushes enemies away';
      case 'Blood':
        return 'Drain: Steals small amount of HP';
      case 'Spirit':
        return 'Haunt: Reduces enemy speed';
      case 'Mud':
        return 'Bog: Heavy slow effect';
      default:
        return 'No special passive effect';
    }
  }
}

/// Represents an elemental ability's progression
class ElementalAbility {
  final String name;
  final List<String> ranks; // 5 ranks: 1-5

  const ElementalAbility({required this.name, required this.ranks});

  String getDescription(int rank) {
    if (rank < 1 || rank > 5) return 'Invalid rank';
    return ranks[rank - 1];
  }
}
