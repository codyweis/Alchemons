import 'package:flutter/material.dart';

/// Central configuration for all special abilities
/// Makes it easy to balance and see all abilities at once
class AbilitySystemConfig {
  // ============================================================================
  // ABILITY DESCRIPTIONS
  // ============================================================================

  static String getAbilityDescription(String family, String element, int rank) {
    // rank here is now the "power level":
    // 0 = no element unlock yet
    // 1 = unlock
    // 2 = strengthened
    // 3 = massive upgrade
    if (rank == 0) {
      return _getBaseDescription(family);
    }

    final key = '${family}_$element';
    final ability = _elementalAbilities[key];
    if (ability == null) {
      return 'Elemental upgrade for $element $family';
    }

    return ability.getThreeTierDescription(rank);
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
    // LET ABILITIES - Meteor
    'Let_Fire': ElementalAbility(
      name: 'Flame Meteor',
      ranks: [
        'Unlocks a flaming meteor that crashes into enemies.',
        'Meteor radius and impact damage are increased.',
        'APOCALYPSE: Huge burning crater that scorches enemies over time and restores some HP.',
      ],
    ),
    'Let_Water': ElementalAbility(
      name: 'Tidal Meteor',
      ranks: [
        'Unlocks a water meteor that crashes down and pushes enemies back.',
        'Stronger knockback and heals nearby allies on impact.',
        'TSUNAMI: Massive wave that blasts enemies back and heavily heals allies and the orb.',
      ],
    ),
    'Let_Ice': ElementalAbility(
      name: 'Frost Meteor',
      ranks: [
        'Unlocks an ice meteor that chills enemies at the impact zone.',
        'Larger icy field that heavily slows enemies.',
        'ABSOLUTE ZERO: Wide ice field that greatly slows and briefly freezes impacted enemies.',
      ],
    ),
    'Let_Lightning': ElementalAbility(
      name: 'Thunder Meteor',
      ranks: [
        'Unlocks a lightning meteor that shocks enemies on impact.',
        'Increased impact radius and shock damage.',
        'JUDGMENT: Thunderous impact with intense screen-wide chains of lightning around the strike.',
      ],
    ),
    'Let_Earth': ElementalAbility(
      name: 'Seismic Meteor',
      ranks: [
        'Unlocks an earth meteor that hits with a powerful quake.',
        'Shrapnel rocks damage extra enemies around the crater.',
        'CATACLYSM: Massive quake plus shrapnel and shields granted to the caster and nearby allies.',
      ],
    ),
    'Let_Plant': ElementalAbility(
      name: 'Thorn Meteor',
      ranks: [
        'Unlocks a thorny meteor that seeds a damaging garden.',
        'Garden radius and thorn damage are increased.',
        'WILDSURGE: Thorn garden that slows, shreds enemies, and heals guardians standing inside.',
      ],
    ),
    'Let_Poison': ElementalAbility(
      name: 'Toxic Meteor',
      ranks: [
        'Unlocks a toxic meteor that applies poison on impact.',
        'Poison damage and duration are increased.',
        'PLAGUE STAR: Large toxic blast and lingering clouds that keep poisoning enemies entering the zone.',
      ],
    ),
    'Let_Air': ElementalAbility(
      name: 'Gale Meteor',
      ranks: [
        'Unlocks a wind meteor that creates a shockwave on impact.',
        'Shockwave knockback distance and radius are increased.',
        'HURRICANE IMPACT: Double shockwave that repeatedly blasts enemies away from the crater.',
      ],
    ),
    'Let_Blood': ElementalAbility(
      name: 'Blood Meteor',
      ranks: [
        'Unlocks a blood meteor that drains enemies on impact.',
        'Greatly increased life drain and more healing to the caster and orb.',
        'TRANSFUSION: Huge drain on all struck enemies that also heals nearby guardians.',
      ],
    ),
    'Let_Spirit': ElementalAbility(
      name: 'Spirit Meteor',
      ranks: [
        'Unlocks a spirit meteor that marks enemies for delayed damage.',
        'Marked explosions hit harder and affect a wider area.',
        'ASCENSION: Multiple spirit explosions ripple from marked enemies, shredding clustered foes.',
      ],
    ),
    'Let_Dark': ElementalAbility(
      name: 'Void Meteor',
      ranks: [
        'Unlocks a void meteor that punishes weakened enemies.',
        'Higher bonus damage to low-HP enemies around the impact.',
        'ECLIPSE: Executes very low-HP foes and restores health to the caster from slain targets.',
      ],
    ),
    'Let_Light': ElementalAbility(
      name: 'Holy Meteor',
      ranks: [
        'Unlocks a holy meteor that damages enemies and heals allies.',
        'Larger heal and stronger holy explosion damage.',
        'DIVINITY: Massive holy blast that heals all guardians, the orb, and cleanses their debuffs.',
      ],
    ),
    'Let_Lava': ElementalAbility(
      name: 'Magma Meteor',
      ranks: [
        'Unlocks a magma meteor that leaves a molten pool on impact.',
        'Molten pool radius and damage over time are increased.',
        'VOLCANIC: Enormous lava pool that keeps burning enemies clustered around the crater.',
      ],
    ),
    'Let_Steam': ElementalAbility(
      name: 'Steam Meteor',
      ranks: [
        'Unlocks a steam meteor that scalds and confuses enemies.',
        'Greater scald damage and larger steam cloud.',
        'GEYSER: Wide steam burst that heavily damages, disorients enemies, and blankets the area in mist.',
      ],
    ),
    'Let_Mud': ElementalAbility(
      name: 'Mud Meteor',
      ranks: [
        'Unlocks a mud meteor that creates a slowing pit.',
        'Mud pool radius and slow strength are increased.',
        'QUAGMIRE: Huge mud field that severely hampers enemy advance around the impact zone.',
      ],
    ),
    'Let_Dust': ElementalAbility(
      name: 'Dust Meteor',
      ranks: [
        'Unlocks a dust meteor that creates a blinding sandstorm.',
        'Sandstorm damage and confusion are increased.',
        'SANDSTORM: Expansive storm that repeatedly damages and disorients all enemies inside.',
      ],
    ),
    'Let_Crystal': ElementalAbility(
      name: 'Crystal Meteor',
      ranks: [
        'Unlocks a crystal meteor that shatters into seeking shards.',
        'More shards and higher shard damage.',
        'PRISM FALL: Meteor erupts into a barrage of homing crystal shards that chase enemies across a huge area.',
      ],
    ),

    // PIP ABILITIES - Ricochet
    'Pip_Fire': ElementalAbility(
      name: 'Flame Ricochet',
      ranks: [
        'Unlocks a ricochet shot that bounces between enemies.',
        'Extra bounces and higher damage per hit, with stronger fire splash on each impact.',
        'INFERNO RICOCHET: Rapid, long chains of bounces that scorch clustered enemies with heavy splash fire.',
      ],
    ),
    'Pip_Water': ElementalAbility(
      name: 'Tidal Ricochet',
      ranks: [
        'Unlocks a ricochet shot that splashes water on impact.',
        'More bounces and stronger orb healing with each hit.',
        'TSUNAMI RICOCHET: Long bouncing chains that repeatedly push enemies away from the orb and restore its HP.',
      ],
    ),
    'Pip_Ice': ElementalAbility(
      name: 'Frost Ricochet',
      ranks: [
        'Unlocks a ricochet shot that chills enemies near each hit.',
        'More bounces and heavier slowing around impact points.',
        'ABSOLUTE RICOCHET: Dense chains that blanket packs in repeated frost bursts, heavily slowing advances.',
      ],
    ),
    'Pip_Lightning': ElementalAbility(
      name: 'Thunder Ricochet',
      ranks: [
        'Unlocks a ricochet shot that arcs lightning through enemies.',
        'Extra bounces and stronger bonus lightning chains from each hit.',
        'STORM RICOCHET: Hyper-bouncing bolts that constantly chain lightning through nearby enemies.',
      ],
    ),
    'Pip_Earth': ElementalAbility(
      name: 'Stone Ricochet',
      ranks: [
        'Unlocks a ricochet shot that shakes targets on impact.',
        'More bounces plus knockback shockwaves around each hit.',
        'QUAKE RICOCHET: Long chains that shove enemy packs away while mending the shooter’s defenses.',
      ],
    ),
    'Pip_Plant': ElementalAbility(
      name: 'Thorn Ricochet',
      ranks: [
        'Unlocks a ricochet shot that seeds small thorn bursts.',
        'Extra bounces and stronger thorn patches from early hits.',
        'WILDPATCH RICOCHET: Ricochets trail thorny zones that chew through groups over time.',
      ],
    ),
    'Pip_Poison': ElementalAbility(
      name: 'Toxic Ricochet',
      ranks: [
        'Unlocks a ricochet shot that poisons enemies on hit.',
        'More bounces and heavier poison damage over time.',
        'PLAGUE RICOCHET: Chains of shots that leave long-lasting poison on every enemy they touch.',
      ],
    ),
    'Pip_Air': ElementalAbility(
      name: 'Gale Ricochet',
      ranks: [
        'Unlocks a ricochet shot that bursts with wind on impact.',
        'Extra bounces and greater knockback from each gust.',
        'HURRICANE RICOCHET: Rapid chains that keep packs pushed back and off the orb.',
      ],
    ),
    'Pip_Blood': ElementalAbility(
      name: 'Blood Ricochet',
      ranks: [
        'Unlocks a ricochet shot that drains enemies on hit.',
        'More bounces and stronger life drain shared with the team.',
        'TRANSFUSION RICOCHET: Long chains that massively siphon health to guardians and the orb.',
      ],
    ),
    'Pip_Spirit': ElementalAbility(
      name: 'Spirit Ricochet',
      ranks: [
        'Unlocks a ricochet shot that marks enemies for delayed spirit damage.',
        'Extra bounces and larger delayed spirit bursts.',
        'ASCENSION RICOCHET: Chains that constantly plant spirit marks, causing repeated ghostly explosions in packs.',
      ],
    ),
    'Pip_Dark': ElementalAbility(
      name: 'Void Ricochet',
      ranks: [
        'Unlocks a ricochet shot that deals bonus dark damage.',
        'More bounces and stronger on-hit lifesteal to the shooter.',
        'ECLIPSE RICOCHET: Rapid chains that shred enemies and heavily sustain the attacker.',
      ],
    ),
    'Pip_Light': ElementalAbility(
      name: 'Holy Ricochet',
      ranks: [
        'Unlocks a ricochet shot that sends out small healing light.',
        'Extra bounces and more team healing per hit.',
        'DIVINE RICOCHET: Long chains that shower your whole team with repeated healing flashes.',
      ],
    ),
    'Pip_Lava': ElementalAbility(
      name: 'Magma Ricochet',
      ranks: [
        'Unlocks a ricochet shot that leaves small lava cracks on impact.',
        'More bounces and stronger lingering lava damage zones.',
        'VOLCANIC RICOCHET: Chain of shots that carpets the field with burning magma patches.',
      ],
    ),
    'Pip_Steam': ElementalAbility(
      name: 'Steam Ricochet',
      ranks: [
        'Unlocks a ricochet shot that steams and soft-slows enemies near each hit.',
        'Extra bounces and stronger slow, with small orb regen on big hits.',
        'GEYSER RICOCHET: Dense chains that keep packs hazy, slowed, and trickle-healing the orb.',
      ],
    ),
    'Pip_Mud': ElementalAbility(
      name: 'Mud Ricochet',
      ranks: [
        'Unlocks a ricochet shot that creates sticky mud at impact.',
        'More bounces and stronger slowing mud pools.',
        'QUAGMIRE RICOCHET: Chains that litter the field with sticky zones that bog entire waves down.',
      ],
    ),
    'Pip_Dust': ElementalAbility(
      name: 'Dust Ricochet',
      ranks: [
        'Unlocks a ricochet shot that scatters blinding dust.',
        'Extra bounces and stronger confusion jitters on nearby enemies.',
        'SANDSPARK RICOCHET: Rapid chains that keep packs constantly jittering and mis-stepping.',
      ],
    ),
    'Pip_Crystal': ElementalAbility(
      name: 'Crystal Ricochet',
      ranks: [
        'Unlocks a ricochet shot that can split into crystal shards.',
        'More bounces and stronger shard splits to nearby enemies.',
        'PRISM RICOCHET: Hyper-bouncing shots that keep spawning homing shards into surrounding targets.',
      ],
    ),

    // MANE ABILITIES - Barrage (3-tier rapid-fire cone)
    'Mane_Fire': ElementalAbility(
      name: 'Flame Barrage',
      ranks: [
        'Unleash a cone of rapid fire that ignites enemies on hit.',
        'More projectiles and stronger burn, shredding clustered enemies.',
        'INFERNO BARRAGE: A massive volley that blankets the cone in intense burning damage.',
      ],
    ),
    'Mane_Ice': ElementalAbility(
      name: 'Frost Barrage',
      ranks: [
        'Rapid shots chill enemies, subtly pushing them back from the Orb.',
        'More projectiles and heavier chill, making enemies feel sluggish and controlled.',
        'GLACIER BARRAGE: A huge volley that heavily chills and shoves back whole packs of enemies.',
      ],
    ),
    'Mane_Lightning': ElementalAbility(
      name: 'Storm Barrage',
      ranks: [
        'Shots arc chain lightning from hit enemies to nearby targets.',
        'More projectiles and stronger chains, devastating clustered foes.',
        'TEMPEST BARRAGE: A massive storm of bolts constantly chaining through enemy groups.',
      ],
    ),
    'Mane_Earth': ElementalAbility(
      name: 'Boulder Barrage',
      ranks: [
        'Heavy shots slam enemies, knocking them back on impact.',
        'More projectiles and greater knockback, creating strong zone control.',
        'AVALANCHE BARRAGE: A brutal volley that pummels enemies and hurls them away from the front line.',
      ],
    ),
    'Mane_Plant': ElementalAbility(
      name: 'Thorn Barrage',
      ranks: [
        'Shots inflict bleeding thorns that deal damage over time.',
        'More projectiles and stronger bleed, rapidly stacking damage on priority targets.',
        'BLOOM BARRAGE: A dense hail of thorns that blankets the cone in heavy bleeds.',
      ],
    ),
    'Mane_Poison': ElementalAbility(
      name: 'Toxin Barrage',
      ranks: [
        'Shots poison enemies in the cone, dealing damage over time.',
        'More projectiles and stronger, longer-lasting poison.',
        'PLAGUE BARRAGE: A huge volley that inflicts powerful poison on anything caught in the cone.',
      ],
    ),
    'Mane_Water': ElementalAbility(
      name: 'Torrent Barrage',
      ranks: [
        'Water shots push enemies backward away from the Orb.',
        'More projectiles and stronger knockback, forming a reliable defensive wall.',
        'TSUNAMI BARRAGE: A massive volley that surges forward and throws enemies far from your defenses.',
      ],
    ),
    'Mane_Air': ElementalAbility(
      name: 'Gale Barrage',
      ranks: [
        'Wind shots shove enemies back, disrupting their advance.',
        'More projectiles and stronger wind force, constantly peeling enemies away.',
        'HURRICANE BARRAGE: A roaring cone of shots that violently sweeps enemies out of position.',
      ],
    ),
    'Mane_Blood': ElementalAbility(
      name: 'Hemorrhage Barrage',
      ranks: [
        'Shots drain HP from enemies, healing you slightly on hit.',
        'More projectiles and stronger lifesteal, greatly improving your sustain.',
        'EXSANGUINATION BARRAGE: A massive volley that drains hordes of enemies to massively heal you and the Orb.',
      ],
    ),
    'Mane_Spirit': ElementalAbility(
      name: 'Spectral Barrage',
      ranks: [
        'Ethereal shots pierce through targets, hitting multiple enemies in the cone.',
        'More projectiles and improved piercing, cutting through dense enemy lines.',
        'HAUNTING BARRAGE: A spectral storm of shots that tears through entire waves of foes.',
      ],
    ),
    'Mane_Dark': ElementalAbility(
      name: 'Shadow Barrage',
      ranks: [
        'Shots weaken enemies, dealing extra damage to those already wounded.',
        'More projectiles and a stronger damage boost against low-HP targets.',
        'ECLIPSE BARRAGE: A crushing volley that brutally finishes off weakened enemies across the cone.',
      ],
    ),
    'Mane_Light': ElementalAbility(
      name: 'Radiant Barrage',
      ranks: [
        'Shots damage enemies and heal you slightly on hit.',
        'More projectiles and stronger healing, supporting you during sustained fights.',
        'DIVINITY BARRAGE: A brilliant volley that heavily damages foes while providing strong self-healing.',
      ],
    ),
    'Mane_Lava': ElementalAbility(
      name: 'Magma Barrage',
      ranks: [
        'Molten shots slam enemies, applying extra knockback on impact.',
        'More projectiles and stronger impact, sending enemies flying.',
        'VOLCANIC BARRAGE: A brutal lava hail that pounds enemies and scatters them violently.',
      ],
    ),
    'Mane_Steam': ElementalAbility(
      name: 'Vapor Barrage',
      ranks: [
        'Steam shots scorch and slightly disorient enemies, jittering their movement.',
        'More projectiles and stronger disorientation and damage.',
        'GEYSER BARRAGE: A dense spray of scalding shots that heavily disrupts and burns enemy groups.',
      ],
    ),
    'Mane_Mud': ElementalAbility(
      name: 'Sludge Barrage',
      ranks: [
        'Shots bog enemies down, nudging them backward and slowing their advance.',
        'More projectiles and stronger slowing pushback, clumping enemies in front of you.',
        'QUAGMIRE BARRAGE: A relentless muddy hail that severely hampers and pushes back entire waves.',
      ],
    ),
    'Mane_Dust': ElementalAbility(
      name: 'Dust Barrage',
      ranks: [
        'Dusty shots jostle enemy positions, lightly scrambling their movement.',
        'More projectiles and stronger disruption, throwing off enemy formations.',
        'DESERT BARRAGE: A churning dust volley that keeps enemies stumbling and mispositioned in the cone.',
      ],
    ),
    'Mane_Crystal': ElementalAbility(
      name: 'Shard Barrage',
      ranks: [
        'Every few shots split into extra crystal shards that strike nearby enemies.',
        'More projectiles and stronger shard damage, punishing clustered foes.',
        'PRISM BARRAGE: A massive hail of shots constantly splitting into shards, shredding enemy packs.',
      ],
    ),

    // MASK ABILITIES - Trap Field
    'Mask_Fire': ElementalAbility(
      name: 'Flame Trap',
      ranks: [
        // Rank 1 – unlock
        'Deploy a fire trap that ignites enemies on trigger.',
        // Rank 2 – stronger
        'More traps with larger radius and stronger burning zones.',
        // Rank 3 – ultimate
        'INFERNO GRID: Deploy a cluster of flame traps that chain burning zones across the field.',
      ],
    ),
    'Mask_Ice': ElementalAbility(
      name: 'Freeze Trap',
      ranks: [
        'Deploy an ice trap that freezes or heavily slows enemies on trigger.',
        'More traps and longer freezes; traps leave a lingering chill zone.',
        'PERMAFROST GRID: A field of freeze traps that keep enemies locked and slowed for a long time.',
      ],
    ),
    'Mask_Lightning': ElementalAbility(
      name: 'Shock Trap',
      ranks: [
        'Deploy a trap that zaps enemies and chains lightning on trigger.',
        'More traps, longer chains, and brief stuns on hit.',
        'TESLA GRID: Interlinked shock traps that create a large chain-lightning network.',
      ],
    ),
    'Mask_Earth': ElementalAbility(
      name: 'Spike Trap',
      ranks: [
        'Deploy a trap that erupts stone spikes, damaging enemies.',
        'More traps and stronger eruptions that briefly stun.',
        'FORTRESS GRID: A field of spike traps that control space and protect the Orb with stone barriers.',
      ],
    ),
    'Mask_Plant': ElementalAbility(
      name: 'Vine Trap',
      ranks: [
        'Deploy a trap that roots enemies in place.',
        'More traps, longer roots, and lingering thorn damage in the area.',
        'GARDEN GRID: A web of vine traps that continuously root and bleed enemies in a large area.',
      ],
    ),
    'Mask_Poison': ElementalAbility(
      name: 'Toxin Trap',
      ranks: [
        'Deploy a trap that releases a poison cloud on trigger.',
        'More traps and stronger clouds that heavily poison and slow enemies.',
        'PANDEMIC GRID: A carpet of toxin traps that spread poison rapidly through enemy packs.',
      ],
    ),
    'Mask_Water': ElementalAbility(
      name: 'Geyser Trap',
      ranks: [
        'Deploy a trap that launches enemies and creates slowing water.',
        'More traps, stronger knockup, and better ally healing near geysers.',
        'FOUNTAIN GRID: A field of geyser traps that juggle enemies and pulse healing to allies.',
      ],
    ),
    'Mask_Air': ElementalAbility(
      name: 'Wind Trap',
      ranks: [
        'Deploy a trap that creates a small tornado on trigger.',
        'More traps, stronger pull and more damage over time.',
        'HURRICANE GRID: Multiple large tornado traps that drag enemies into deadly storm zones.',
      ],
    ),
    'Mask_Blood': ElementalAbility(
      name: 'Drain Trap',
      ranks: [
        'Deploy a trap that leeches HP from enemies and heals the team.',
        'More traps and stronger drains; drained enemies leave blood pools that heal allies.',
        'EXSANGUINATE GRID: A network of drain traps that suck life from huge clusters of enemies.',
      ],
    ),
    'Mask_Spirit': ElementalAbility(
      name: 'Ghost Trap',
      ranks: [
        'Deploy a trap that summons an attacking spirit when triggered.',
        'More traps and longer-lasting spirits that weaken enemies.',
        'HAUNTED GRID: A field of ghost traps that maintain a small spirit army harassing enemies.',
      ],
    ),
    'Mask_Dark': ElementalAbility(
      name: 'Void Trap',
      ranks: [
        'Deploy a trap that creates a small black hole, pulling enemies inward.',
        'More traps, stronger pull, and growing damage the longer enemies stay inside.',
        'SINGULARITY GRID: Many void traps forming a deadly gravity field that shreds clustered enemies.',
      ],
    ),
    'Mask_Light': ElementalAbility(
      name: 'Radiance Trap',
      ranks: [
        'Deploy a trap that blinds and damages enemies on trigger.',
        'More traps, stronger blind, and healing pulses for nearby allies.',
        'REVELATION GRID: A field of radiant traps that blind most enemies and constantly heal your team.',
      ],
    ),
    'Mask_Lava': ElementalAbility(
      name: 'Magma Trap',
      ranks: [
        'Deploy a trap that creates a damaging lava pool.',
        'More traps, larger pools, and occasional eruptions that knock enemies back.',
        'VOLCANIC GRID: A lattice of magma traps that turn huge areas of the map into lava.',
      ],
    ),
    'Mask_Steam': ElementalAbility(
      name: 'Pressure Trap',
      ranks: [
        'Deploy a trap that builds pressure then explodes in steam.',
        'More traps, bigger blasts, and steam that heals allies while burning enemies.',
        'BOILER GRID: Chains of pressure traps that cause repeated steam explosions across the area.',
      ],
    ),
    'Mask_Mud': ElementalAbility(
      name: 'Quicksand Trap',
      ranks: [
        'Deploy a trap that creates a mud pit, heavily slowing enemies.',
        'More traps, larger pits, and stronger slow that can briefly root enemies.',
        'QUAGMIRE GRID: A field of quicksand traps that nearly stop enemy movement around the Orb.',
      ],
    ),
    'Mask_Dust': ElementalAbility(
      name: 'Dust Trap',
      ranks: [
        'Deploy a trap that creates a blinding dust cloud on trigger.',
        'More traps, bigger clouds, and damage over time inside the dust.',
        'SANDSTORM GRID: A network of dust traps that cover large areas in debilitating sandstorms.',
      ],
    ),
    'Mask_Crystal': ElementalAbility(
      name: 'Prism Trap',
      ranks: [
        'Deploy a trap that fires crystal shards at enemies.',
        'More traps, more shards, and piercing shots that can hit multiple targets.',
        'CRYSTALLIZE GRID: A fortress of prism traps that barrage enemies with homing crystal shards.',
      ],
    ),

    // HORN ABILITIES - Nova (3-tier elemental nova)
    'Horn_Fire': ElementalAbility(
      name: 'Flame Nova',
      ranks: [
        'Nova ignites all nearby enemies with burning damage over time.',
        'Burn deals more damage and lasts longer as the nova radius and shield grow stronger.',
        'Cataclysmic Flame Nova: huge radius and a lingering fire ring that continuously scorches enemies.',
      ],
    ),
    'Horn_Water': ElementalAbility(
      name: 'Tidal Nova',
      ranks: [
        'Nova damages nearby enemies and heals guardians and the Orb within range.',
        'Healing is increased and affects a larger area as the nova grows in power.',
        'Tidal Nova: a massive, high-impact nova that heavily heals allies in a huge radius and shoves enemies back.',
      ],
    ),
    'Horn_Ice': ElementalAbility(
      name: 'Frost Nova',
      ranks: [
        'Nova creates a chilling zone that slows and pushes enemies away from the Orb.',
        'The freezing zone lasts longer and exerts stronger pushback on enemies caught inside.',
        'Absolute Frost Nova: huge radius, plus briefly freezes enemies hit while maintaining a powerful chill field.',
      ],
    ),
    'Horn_Lightning': ElementalAbility(
      name: 'Thunder Nova',
      ranks: [
        'Nova shocks nearby enemies, sending out lightning that chains between them.',
        'Chain lightning becomes much stronger, greatly increasing damage to clustered enemies.',
        'Judgment Nova: a massive blast that unleashes powerful chains of lightning through enemy packs.',
      ],
    ),
    'Horn_Earth': ElementalAbility(
      name: 'Seismic Nova',
      ranks: [
        'Nova grants you a stone shield while damaging nearby enemies.',
        'Shield value is increased and nearby guardians also gain a portion of the stone shield.',
        'Fortress Nova: huge radius and a powerful earthen bulwark that heavily fortifies you and your allies.',
      ],
    ),
    'Horn_Plant': ElementalAbility(
      name: 'Thorn Nova',
      ranks: [
        'Nova sprays thorns that apply a bleeding damage-over-time effect to nearby enemies.',
        'Thorns deal more damage and a bramble zone forms around you, hindering enemies as they advance.',
        'Blooming Thorn Nova: a large-radius thorn eruption with a stronger root/bramble field that pushes enemies away from the Orb.',
      ],
    ),
    'Horn_Poison': ElementalAbility(
      name: 'Toxic Nova',
      ranks: [
        'Nova releases a toxic wave that heavily poisons nearby enemies.',
        'Poison damage and duration are increased, punishing enemies that stay near you.',
        'Plague Nova: a huge poisonous blast with extremely potent, long-lasting poison on everything it touches.',
      ],
    ),
    'Horn_Air': ElementalAbility(
      name: 'Gale Nova',
      ranks: [
        'Nova creates a strong gust, blasting nearby enemies away from you.',
        'Wind force and effective radius increase, sending enemies flying even farther.',
        'Hurricane Nova: a massive blast with a follow-up shockwave that violently repels enemies twice.',
      ],
    ),
    'Horn_Blood': ElementalAbility(
      name: 'Blood Nova',
      ranks: [
        'Nova drains nearby enemies, converting part of the damage into healing for you and the Orb.',
        'Drain potency is increased, significantly improving your sustain and Orb healing.',
        'Transfusion Nova: a huge radius blood burst that drains many enemies, massively healing you, the Orb, and nearby allies.',
      ],
    ),
    'Horn_Spirit': ElementalAbility(
      name: 'Spirit Nova',
      ranks: [
        'Nova unleashes spirit energy that damages nearby enemies and siphons life to heal you.',
        'Drain damage and self-healing are increased, enhancing your sustain during large waves.',
        'Ascendant Spirit Nova: a cataclysmic spirit burst with huge radius and a powerful self-heal from all drained foes.',
      ],
    ),
    'Horn_Dark': ElementalAbility(
      name: 'Void Nova',
      ranks: [
        'Nova bathes nearby enemies in darkness, executing those on very low health and harming the wounded.',
        'The execute threshold and bonus damage to already-wounded enemies are increased.',
        'Eclipse Nova: a huge void shock that executes low-health enemies in a wide radius and heavily punishes the injured.',
      ],
    ),
    'Horn_Light': ElementalAbility(
      name: 'Holy Nova',
      ranks: [
        'Nova damages nearby enemies while healing your guardians and the Orb.',
        'Healing is greatly increased and affects more allies as the nova grows.',
        'Divine Nova: massive heal and damage in a huge radius, plus it cleanses negative effects from your guardians.',
      ],
    ),
    'Horn_Lava': ElementalAbility(
      name: 'Magma Nova',
      ranks: [
        'Nova erupts with molten force, heavily damaging and knocking back nearby enemies.',
        'Both damage and knockback are increased, sending enemies flying farther.',
        'Volcanic Nova: a massive, high-impact lava blast that slams enemies back with brutal force.',
      ],
    ),
    'Horn_Steam': ElementalAbility(
      name: 'Steam Nova',
      ranks: [
        'Nova releases scalding steam, damaging and disorienting nearby enemies.',
        'Steam damage and the strength of the disorienting scatter are increased.',
        'Geyser Nova: a huge steam eruption that deals heavy damage and violently scatters enemies around you.',
      ],
    ),
    'Horn_Mud': ElementalAbility(
      name: 'Mud Nova',
      ranks: [
        'Nova creates a mud field around you, heavily slowing enemies and pushing them away from the Orb.',
        'Mud field lasts longer and exerts stronger slowing/backward pressure on enemies.',
        'Quagmire Nova: a large-radius mud explosion that severely bogs down and repels advancing enemies.',
      ],
    ),
    'Horn_Dust': ElementalAbility(
      name: 'Dust Nova',
      ranks: [
        'Nova creates a dust burst that jostles enemy positions and disrupts their advance.',
        'Dust cloud lingers, continuously jittering enemies and throwing off their movement.',
        'Sandstorm Nova: a large dust field that heavily disrupts enemy formations and keeps them stumbling around you.',
      ],
    ),
    'Horn_Crystal': ElementalAbility(
      name: 'Crystal Nova',
      ranks: [
        'Nova shatters into seeking crystal shards that strike nearby enemies.',
        'More shards are created and each shard deals increased damage.',
        'Prismatic Nova: a huge crystal eruption with many homing shards that tear through enemies across a wide area.',
      ],
    ),

    // WING ABILITIES - Beam (3-rank specials)
    'Wing_Fire': ElementalAbility(
      name: 'Flame Beam',
      ranks: [
        'Beam scorches a line, igniting all enemies it pierces',
        'Burns last longer and deal increased damage along the beam path',
        'SOLAR FLARE: Devastating wide fire beam that heavily burns and can trigger fiery chain explosions',
      ],
    ),
    'Wing_Water': ElementalAbility(
      name: 'Hydro Beam',
      ranks: [
        'Beam pushes enemies backward in a line',
        'Push strength and self-healing per enemy hit are increased',
        'TSUNAMI BEAM: Massive water beam that shoves back crowds and greatly heals the caster',
      ],
    ),
    'Wing_Ice': ElementalAbility(
      name: 'Cryo Beam',
      ranks: [
        'Beam chills enemies it pierces, slowing their advance',
        'Stronger chill and knockback, making enemies slide further',
        'ABSOLUTE ZERO BEAM: Powerful freeze ray that can briefly lock the first enemy hit in ice',
      ],
    ),
    'Wing_Lightning': ElementalAbility(
      name: 'Thunder Beam',
      ranks: [
        'Beam electrifies enemies, sending out small lightning arcs',
        'Arcs chain farther and hit more nearby enemies for extra damage',
        'TEMPEST BEAM: Storm-powered beam that chains lightning through large enemy groups',
      ],
    ),
    'Wing_Earth': ElementalAbility(
      name: 'Seismic Beam',
      ranks: [
        'Beam slams through enemies, dealing extra impact damage',
        'Impact also weakens enemy defenses and grants a small stone shield',
        'EARTHQUAKE BEAM: Crushing beam that heavily shreds armor and grants a sturdy protective shield',
      ],
    ),
    'Wing_Plant': ElementalAbility(
      name: 'Thorn Beam',
      ranks: [
        'Beam lances through enemies, applying bleed over time',
        'Bleeds grow stronger and last longer on pierced targets',
        'BLOOM BEAM: Brutal thorn ray that inflicts heavy stacking bleed across the whole line',
      ],
    ),
    'Wing_Poison': ElementalAbility(
      name: 'Venom Beam',
      ranks: [
        'Beam poisons all enemies it passes through',
        'Poison damage and duration are increased on pierced enemies',
        'PLAGUE BEAM: Noxious ray whose poison spreads from victims to nearby enemies',
      ],
    ),
    'Wing_Air': ElementalAbility(
      name: 'Gale Beam',
      ranks: [
        'Beam unleashes a fierce gust, pushing enemies away',
        'Wind force increases, heavily disrupting enemy formations',
        'HURRICANE BEAM: Roaring wind beam that blasts crowds back and shakes the battlefield',
      ],
    ),
    'Wing_Blood': ElementalAbility(
      name: 'Hemorrhage Beam',
      ranks: [
        'Beam drains life from enemies, restoring some HP to the caster',
        'Lifesteal grows stronger and partially mends the Orb as well',
        'EXSANGUINATE BEAM: Massive drain that heals you, the Orb, and nearby allies from all pierced foes',
      ],
    ),
    'Wing_Spirit': ElementalAbility(
      name: 'Phantom Beam',
      ranks: [
        'Beam inflicts spiritual damage that siphons energy from enemies',
        'Drain power increases, restoring more health to the caster',
        'HAUNTING BEAM: Spectral ray that heavily drains spirit from all in its path, greatly healing its wielder',
      ],
    ),
    'Wing_Dark': ElementalAbility(
      name: 'Shadow Beam',
      ranks: [
        'Beam curses enemies in a line, harming weakened foes more',
        'Execution threshold and bonus damage vs wounded enemies increase',
        'ECLIPSE BEAM: Grim ray that can execute low HP enemies and ravage all already-injured targets',
      ],
    ),
    'Wing_Light': ElementalAbility(
      name: 'Holy Beam',
      ranks: [
        'Beam damages enemies while gently healing allied guardians',
        'Healing is stronger and reaches more allies along the beam',
        'DIVINITY BEAM: Radiant ray that restores the team and even heals the Orb while smiting enemies',
      ],
    ),
    'Wing_Lava': ElementalAbility(
      name: 'Magma Beam',
      ranks: [
        'Beam leaves molten patches along its path, burning grounded foes',
        'Lava patches last longer and deal heavier damage over time',
        'VOLCANIC BEAM: Superheated ray that carves a long trail of searing lava through the battlefield',
      ],
    ),
    'Wing_Steam': ElementalAbility(
      name: 'Vapor Beam',
      ranks: [
        'Beam scalds enemies and creates small pockets of steam',
        'Steam eruptions deal extra splash damage around hit targets',
        'GEYSER BEAM: Overheated ray that fills the line with violent steam bursts and area damage',
      ],
    ),
    'Wing_Mud': ElementalAbility(
      name: 'Sludge Beam',
      ranks: [
        'Beam coats the ground in mud, heavily slowing enemies it hits',
        'Mud slow grows stronger and makes enemies struggle to advance',
        'QUAGMIRE BEAM: Viscous ray that leaves a line of crippling sludge, nearly rooting enemies in place',
      ],
    ),
    'Wing_Dust': ElementalAbility(
      name: 'Sandblast Beam',
      ranks: [
        'Beam blasts enemies with dust, jostling and disorienting them',
        'Dust grows heavier, causing stronger disruption and confusion',
        'DESERT BEAM: Howling sand ray that wildly scatters enemy positions and ruins their accuracy',
      ],
    ),
    'Wing_Crystal': ElementalAbility(
      name: 'Prism Beam',
      ranks: [
        'Beam shards on impact, sending small crystal projectiles to nearby enemies',
        'More shards spawn and they deal increased damage',
        'REFRACTION BEAM: Brilliant ray that showers the battlefield with homing crystal shards',
      ],
    ),

    // KIN ABILITIES - Blessing
    'Kin_Fire': ElementalAbility(
      name: 'Flame Blessing',
      ranks: [
        // Rank 1 – unlock
        'Heals the Orb and burns nearby enemies.',
        // Rank 2 – stronger numbers
        'Healing and burn power/radius increased.',
        // Rank 3 – ultimate
        'INFERNO: Massive heal plus a wide burning aura around the Orb.',
      ],
    ),
    'Kin_Water': ElementalAbility(
      name: 'Tidal Blessing',
      ranks: [
        'Heals the Orb and applies regeneration to nearby allies.',
        'Stronger regen and larger blessing radius; water aura also slows enemies.',
        'FOUNTAIN: Continuous pulsing heals around the Orb for a long duration.',
      ],
    ),
    'Kin_Ice': ElementalAbility(
      name: 'Frost Blessing',
      ranks: [
        'Heals the Orb and chills nearby enemies.',
        'Higher healing, chance to freeze, and a protective ice aura.',
        'GLACIER: Massive heal plus a freezing zone that protects the Orb.',
      ],
    ),
    'Kin_Lightning': ElementalAbility(
      name: 'Storm Blessing',
      ranks: [
        'Heals the Orb and shocks nearby enemies.',
        'More healing and a chaining electric aura that hits multiple enemies.',
        'TEMPEST: Massive heal plus a persistent lightning field that stuns and zaps enemies.',
      ],
    ),
    'Kin_Earth': ElementalAbility(
      name: 'Stone Blessing',
      ranks: [
        'Heals the Orb and grants a temporary stone shield.',
        'Shield duration and strength increased; stone aura can block projectiles.',
        'FORTRESS: Massive heal plus protective stone walls around the Orb.',
      ],
    ),
    'Kin_Plant': ElementalAbility(
      name: 'Growth Blessing',
      ranks: [
        'Heals the Orb and grants regeneration to all allies.',
        'Much stronger regen and a thorn aura that damages melee attackers.',
        'BLOOM: Massive heal plus vines and thorns covering the Orb’s area.',
      ],
    ),
    'Kin_Poison': ElementalAbility(
      name: 'Venom Blessing',
      ranks: [
        'Heals the Orb and poisons nearby enemies.',
        'More healing and stronger poison that spreads between enemies.',
        'PLAGUE: Massive heal plus a wide toxic aura that infects all nearby enemies.',
      ],
    ),
    'Kin_Air': ElementalAbility(
      name: 'Wind Blessing',
      ranks: [
        'Heals the Orb and pushes nearby enemies away.',
        'More healing plus a wind aura that speeds up allies and deflects some attacks.',
        'HURRICANE: Massive heal plus a powerful wind barrier around the Orb.',
      ],
    ),
    'Kin_Blood': ElementalAbility(
      name: 'Blood Blessing',
      ranks: [
        'Drains nearby enemies to heal the Orb.',
        'Much stronger lifesteal with a blood aura that absorbs damage.',
        'TRANSFUSION: Drain all nearby enemies for a massive team heal.',
      ],
    ),
    'Kin_Spirit': ElementalAbility(
      name: 'Spirit Blessing',
      ranks: [
        'Heals the Orb and damages nearby enemies.',
        'More healing and spirit guardians that protect the Orb.',
        'ASCENSION: Massive heal plus empowered spirit guardians surrounding the Orb.',
      ],
    ),
    'Kin_Dark': ElementalAbility(
      name: 'Void Blessing',
      ranks: [
        'Heals the Orb while draining nearby enemies.',
        'More healing plus a darkness aura that weakens enemy damage.',
        'ECLIPSE: Massive heal plus blinding darkness that cripples nearby enemies.',
      ],
    ),
    'Kin_Light': ElementalAbility(
      name: 'Holy Blessing',
      ranks: [
        'Heals the Orb and nearby allies.',
        'Greatly increased healing and regen; radiant aura damages nearby enemies.',
        'DIVINITY: Huge screen-wide heal, damage burst to enemies, and temporary shields.',
      ],
    ),
    'Kin_Lava': ElementalAbility(
      name: 'Magma Blessing',
      ranks: [
        'Heals the Orb and creates a lava ring around it.',
        'More healing and a larger lava ring that burns enemies longer.',
        'VOLCANIC: Massive heal plus a large lava field surrounding the Orb.',
      ],
    ),
    'Kin_Steam': ElementalAbility(
      name: 'Vapor Blessing',
      ranks: [
        'Heals the Orb and creates a steam cloud around it.',
        'More healing; steam cloud now also heals allies over time.',
        'GEYSER: Continuous healing pulses and steam explosions around the Orb.',
      ],
    ),
    'Kin_Mud': ElementalAbility(
      name: 'Earth Blessing',
      ranks: [
        'Heals the Orb and creates a slowing mud field around it.',
        'More healing and a much heavier slow inside the mud field.',
        'QUAGMIRE: Massive heal plus mud that heavily slows and can root enemies.',
      ],
    ),
    'Kin_Dust': ElementalAbility(
      name: 'Sand Blessing',
      ranks: [
        'Heals the Orb and creates a dust cloud around it.',
        'More healing; dust cloud now blinds and disorients enemies.',
        'SANDSTORM: Massive heal plus a large dust storm that blinds most enemies.',
      ],
    ),
    'Kin_Crystal': ElementalAbility(
      name: 'Prism Blessing',
      ranks: [
        'Heals the Orb and creates a basic crystal shield.',
        'Stronger, longer-lasting shield that can reflect projectiles.',
        'CRYSTALLIZE: Massive heal plus a crystal fortress that fires shards at enemies.',
      ],
    ),

    // MYSTIC ABILITIES - Orbitals
    'Mystic_Fire': ElementalAbility(
      name: 'Flame Orbitals',
      ranks: [
        'Summon fire orbitals that seek enemies',
        'Orbitals gain small burn splash on hit',
        'More orbitals with stronger burn AoE',
        'Burn radius and damage greatly increased',
        'INFERNO SWARM: Many orbitals with huge burn explosions',
      ],
    ),

    'Mystic_Water': ElementalAbility(
      name: 'Tidal Orbitals',
      ranks: [
        'Summon water orbitals that seek enemies',
        'Hits heal nearby allies slightly',
        'Healing in the impact area increased',
        'Larger heal radius around impact',
        'TSUNAMI SWARM: Many orbitals with big team heals',
      ],
    ),

    'Mystic_Ice': ElementalAbility(
      name: 'Frost Orbitals',
      ranks: [
        'Summon ice orbitals that seek enemies',
        'Hits slow enemies around impact',
        'Slow strength and radius increased',
        'Heavy area slow around each impact',
        'ABSOLUTE ZERO SWARM: Many orbitals massively slow packs',
      ],
    ),

    'Mystic_Lightning': ElementalAbility(
      name: 'Storm Orbitals',
      ranks: [
        'Summon lightning orbitals that seek enemies',
        'Hits fire small lightning chains',
        'More chains per impact, extra damage',
        'Chain range and power increased',
        'JUDGMENT SWARM: Many orbitals with brutal chain lightning',
      ],
    ),

    'Mystic_Earth': ElementalAbility(
      name: 'Stone Orbitals',
      ranks: [
        'Summon earth orbitals that seek enemies',
        'Hits deal small AoE damage',
        'AoE damage and radius increased',
        'Hits also grant self shielding heal',
        'FORTRESS SWARM: Many orbitals with big AoE and shielding',
      ],
    ),

    'Mystic_Plant': ElementalAbility(
      name: 'Thorn Orbitals',
      ranks: [
        'Summon plant orbitals that seek enemies',
        'Impacts seed small thorn zones',
        'Thorn damage and zone radius increased',
        'Zones last longer and hurt more',
        'BLOOM SWARM: Many orbitals carpeting thorns',
      ],
    ),

    'Mystic_Poison': ElementalAbility(
      name: 'Toxic Orbitals',
      ranks: [
        'Summon poison orbitals that seek enemies',
        'Hits apply heavy poison to target',
        'Poison also spreads in a small area',
        'Stronger, longer poison on all victims',
        'PLAGUE SWARM: Many orbitals stacking poison everywhere',
      ],
    ),

    'Mystic_Air': ElementalAbility(
      name: 'Gale Orbitals',
      ranks: [
        'Summon air orbitals that seek enemies',
        'Hits push enemies away from impact',
        'Stronger knockback in a wider area',
        'Big shockwave knockback each impact',
        'HURRICANE SWARM: Many orbitals blasting packs apart',
      ],
    ),

    'Mystic_Blood': ElementalAbility(
      name: 'Blood Orbitals',
      ranks: [
        'Summon blood orbitals that seek enemies',
        'Hits grant lifesteal to the caster',
        'Lifesteal amount increased',
        'Large heals from every hit',
        'TRANSFUSION SWARM: Many orbitals with massive lifesteal',
      ],
    ),

    'Mystic_Spirit': ElementalAbility(
      name: 'Spirit Orbitals',
      ranks: [
        'Summon spirit orbitals that seek enemies',
        'Hits deal spectral splash damage',
        'Splash damage and radius increased',
        'Hits also heal the caster',
        'ASCENSION SWARM: Many orbitals with huge spirit blasts and healing',
      ],
    ),

    'Mystic_Dark': ElementalAbility(
      name: 'Void Orbitals',
      ranks: [
        'Summon dark orbitals that seek enemies',
        'Hits drain extra HP from targets',
        'Drain damage and healing increased',
        'Big single-target drains per impact',
        'ECLIPSE SWARM: Many orbitals with massive dark drains',
      ],
    ),

    'Mystic_Light': ElementalAbility(
      name: 'Holy Orbitals',
      ranks: [
        'Summon light orbitals that seek enemies',
        'Hits heal nearby allies slightly',
        'Larger heals around each impact',
        'Hits both heal allies and burn enemies',
        'DIVINITY SWARM: Many orbitals with huge heals and holy damage',
      ],
    ),

    'Mystic_Lava': ElementalAbility(
      name: 'Magma Orbitals',
      ranks: [
        'Summon lava orbitals that seek enemies',
        'Hits cause small explosions with knockback',
        'Explosion radius and damage increased',
        'Big blasts that shove enemies away',
        'VOLCANIC SWARM: Many orbitals causing massive lava explosions',
      ],
    ),

    'Mystic_Steam': ElementalAbility(
      name: 'Steam Orbitals',
      ranks: [
        'Summon steam orbitals that seek enemies',
        'Hits chip enemies and heal the orb slightly',
        'More chip damage in a small area',
        'Extra orb healing when packs are hit',
        'GEYSER SWARM: Many orbitals scalding enemies and feeding the orb',
      ],
    ),

    'Mystic_Mud': ElementalAbility(
      name: 'Mud Orbitals',
      ranks: [
        'Summon mud orbitals that seek enemies',
        'Hits create small slow puddles',
        'Puddles grow larger and slower',
        'Longer-lasting mud fields on impact',
        'QUAGMIRE SWARM: Many orbitals spreading heavy mud control',
      ],
    ),

    'Mystic_Dust': ElementalAbility(
      name: 'Dust Orbitals',
      ranks: [
        'Summon dust orbitals that seek enemies',
        'Hits briefly confuse nearby enemies',
        'Confusion radius and intensity increased',
        'Large packs get heavily scrambled',
        'SANDSTORM SWARM: Many orbitals constantly displacing enemies',
      ],
    ),

    'Mystic_Crystal': ElementalAbility(
      name: 'Crystal Orbitals',
      ranks: [
        'Summon crystal orbitals that seek enemies',
        'Hits fire mini shard chains',
        'More shards to more targets',
        'Shard damage and chain length increased',
        'PRISM SWARM: Many orbitals with relentless crystal chains',
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

/// Represents an elemental ability's progression.
/// Internally we still allow up to 5 design ranks, but the game uses
/// 3 power tiers:
///   1 = unlock
///   2 = strengthened
///   3 = massive upgrade / ultimate
class ElementalAbility {
  final String name;
  final List<String> ranks; // originally written as 5 ranks

  const ElementalAbility({required this.name, required this.ranks});

  /// Old style: if you still call this anywhere with a raw index (1–5),
  /// it will keep working.
  String getDescription(int rank) {
    if (ranks.isEmpty) return 'No description';
    final clamped = rank.clamp(1, ranks.length);
    return ranks[clamped - 1];
  }

  /// New: rank here is power tier 1–3.
  /// We map:
  ///   1 -> early design rank (index 0)
  ///   2 -> mid design rank  (index 2 when possible)
  ///   3 -> late/ultimate    (last entry, usually index 4)
  String getThreeTierDescription(int powerTier) {
    if (ranks.isEmpty) return 'No description';

    // Safety clamp: powerTier must be 1–3
    final tier = powerTier.clamp(1, 3);

    int idx;
    if (ranks.length >= 5) {
      switch (tier) {
        case 1:
          idx = 0; // first line: unlock
          break;
        case 2:
          idx = 2; // middle power: strengthened
          break;
        case 3:
        default:
          idx = ranks.length - 1; // last line: massive upgrade
          break;
      }
    } else if (ranks.length >= 3) {
      // If a definition only has 3 entries, map 1:1.
      idx = tier - 1;
    } else if (ranks.length == 2) {
      // 2 entries: treat second as both strengthened + ultimate.
      idx = tier == 1 ? 0 : 1;
    } else {
      // 1 entry: everything shows the same text.
      idx = 0;
    }

    return ranks[idx];
  }
}
