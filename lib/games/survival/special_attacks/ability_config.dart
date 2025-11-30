import 'package:flutter/material.dart';

/// Central configuration for all special abilities
/// Makes it easy to balance and see all abilities at once
///
/// 3-TIER SYSTEM:
///   Rank 1 = Unlock (basic elemental effect)
///   Rank 2 = Strengthened (better numbers, larger radius, etc.)
///   Rank 3 = Ultimate (massive upgrade with powerful effects)
class AbilitySystemConfig {
  // ============================================================================
  // ABILITY DESCRIPTIONS
  // ============================================================================

  static String getAbilityDescription(String family, String element, int rank) {
    // rank here is the power level: 0 = locked, 1 = unlock, 2 = strengthened, 3 = ultimate
    if (rank == 0) {
      return _getBaseDescription(family);
    }

    final key = '${family}_$element';
    final ability = _elementalAbilities[key];
    if (ability == null) {
      return 'Elemental upgrade for $element $family';
    }

    return ability.getDescription(rank);
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
  // ELEMENTAL ABILITY DEFINITIONS (3-TIER)
  // ============================================================================

  static final Map<String, ElementalAbility> _elementalAbilities = {
    // ══════════════════════════════════════════════════════════════════════════
    // LET ABILITIES - Meteor
    // ══════════════════════════════════════════════════════════════════════════
    'Let_Fire': ElementalAbility(
      name: 'Flame Meteor',
      ranks: [
        'Meteor leaves a burning crater that damages enemies over time.',
        'Larger crater with increased burn damage and duration.',
        'APOCALYPSE: Massive burning crater that scorches enemies and restores HP to the caster.',
      ],
    ),
    'Let_Water': ElementalAbility(
      name: 'Tidal Meteor',
      ranks: [
        'Meteor crashes down and pushes enemies back from impact.',
        'Stronger knockback and heals nearby allies on impact.',
        'TSUNAMI: Massive wave that blasts enemies back and heavily heals allies and the Orb.',
      ],
    ),
    'Let_Ice': ElementalAbility(
      name: 'Frost Meteor',
      ranks: [
        'Meteor creates an icy zone that chills and slows enemies.',
        'Larger ice field with heavier slow effect.',
        'ABSOLUTE ZERO: Wide ice field that greatly slows and pushes enemies away from the Orb.',
      ],
    ),
    'Let_Lightning': ElementalAbility(
      name: 'Thunder Meteor',
      ranks: [
        'Meteor strike sends chain lightning to nearby enemies.',
        'More chains with increased damage to clustered foes.',
        'JUDGMENT: Thunderous impact with intense chains of lightning arcing through enemy packs.',
      ],
    ),
    'Let_Earth': ElementalAbility(
      name: 'Seismic Meteor',
      ranks: [
        'Meteor hits with a powerful quake that damages and stuns.',
        'Shrapnel rocks damage extra enemies around the crater.',
        'CATACLYSM: Massive quake plus shrapnel, granting shields to the caster and nearby allies.',
      ],
    ),
    'Let_Plant': ElementalAbility(
      name: 'Thorn Meteor',
      ranks: [
        'Meteor seeds a damaging thorn garden at impact.',
        'Larger garden radius with increased thorn damage.',
        'WILDSURGE: Thorn garden that slows, damages enemies, and heals guardians standing inside.',
      ],
    ),
    'Let_Poison': ElementalAbility(
      name: 'Toxic Meteor',
      ranks: [
        'Meteor applies heavy poison to all enemies hit.',
        'Stronger and longer-lasting poison effect.',
        'PLAGUE STAR: Large toxic blast with lingering clouds that poison enemies entering the zone.',
      ],
    ),
    'Let_Air': ElementalAbility(
      name: 'Gale Meteor',
      ranks: [
        'Meteor creates a shockwave that blasts enemies away.',
        'Increased shockwave knockback distance and radius.',
        'HURRICANE IMPACT: Double shockwave that repeatedly blasts enemies away from the crater.',
      ],
    ),
    'Let_Blood': ElementalAbility(
      name: 'Blood Meteor',
      ranks: [
        'Meteor drains life from enemies on impact.',
        'Greatly increased life drain to caster and Orb.',
        'TRANSFUSION: Huge drain on all struck enemies that also heals nearby guardians.',
      ],
    ),
    'Let_Spirit': ElementalAbility(
      name: 'Spirit Meteor',
      ranks: [
        'Meteor marks enemies for delayed spirit damage.',
        'Larger delayed explosions affecting a wider area.',
        'ASCENSION: Multiple spirit explosions ripple from marked enemies, shredding clustered foes.',
      ],
    ),
    'Let_Dark': ElementalAbility(
      name: 'Void Meteor',
      ranks: [
        'Meteor deals bonus damage to weakened enemies.',
        'Higher bonus damage to low-HP targets around impact.',
        'ECLIPSE: Executes very low-HP foes and restores health to the caster from slain targets.',
      ],
    ),
    'Let_Light': ElementalAbility(
      name: 'Holy Meteor',
      ranks: [
        'Meteor damages enemies and heals all guardians.',
        'Larger heal and stronger holy explosion damage.',
        'DIVINITY: Massive holy blast that heals all guardians, the Orb, and cleanses debuffs.',
      ],
    ),
    'Let_Lava': ElementalAbility(
      name: 'Magma Meteor',
      ranks: [
        'Meteor leaves a molten pool that burns over time.',
        'Larger molten pool with increased damage.',
        'VOLCANIC: Enormous lava pool with knockback that keeps burning clustered enemies.',
      ],
    ),
    'Let_Steam': ElementalAbility(
      name: 'Steam Meteor',
      ranks: [
        'Meteor scalds enemies and creates a disorienting steam cloud.',
        'Greater scald damage and larger steam cloud.',
        'GEYSER: Wide steam burst that heavily damages, disorients enemies, and blankets the area.',
      ],
    ),
    'Let_Mud': ElementalAbility(
      name: 'Mud Meteor',
      ranks: [
        'Meteor creates a slowing mud pit at impact.',
        'Larger mud pool with stronger slow effect.',
        'QUAGMIRE: Huge mud field that severely hampers enemy advance around the impact zone.',
      ],
    ),
    'Let_Dust': ElementalAbility(
      name: 'Dust Meteor',
      ranks: [
        'Meteor creates a blinding sandstorm that damages and confuses.',
        'Stronger sandstorm damage and longer confusion.',
        'SANDSTORM: Expansive storm that repeatedly damages and disorients all enemies inside.',
      ],
    ),
    'Let_Crystal': ElementalAbility(
      name: 'Crystal Meteor',
      ranks: [
        'Meteor shatters into seeking crystal shards.',
        'More shards with higher damage.',
        'PRISM FALL: Meteor erupts into a barrage of homing crystal shards chasing enemies.',
      ],
    ),

    // ══════════════════════════════════════════════════════════════════════════
    // PIP ABILITIES - Ricochet
    // ══════════════════════════════════════════════════════════════════════════
    'Pip_Fire': ElementalAbility(
      name: 'Flame Ricochet',
      ranks: [
        'Ricochet shot splashes fire damage to nearby enemies on each hit.',
        'Extra bounces with stronger fire splash on each impact.',
        'INFERNO RICOCHET: Rapid, long chains that scorch clustered enemies with heavy splash fire.',
      ],
    ),
    'Pip_Water': ElementalAbility(
      name: 'Tidal Ricochet',
      ranks: [
        'Ricochet shot splashes water on impact, pushing enemies.',
        'More bounces with Orb healing on each hit.',
        'TSUNAMI RICOCHET: Long bouncing chains that repeatedly push enemies away and restore Orb HP.',
      ],
    ),
    'Pip_Ice': ElementalAbility(
      name: 'Frost Ricochet',
      ranks: [
        'Ricochet shot chills enemies near each hit.',
        'More bounces with heavier slowing around impact points.',
        'ABSOLUTE RICOCHET: Dense chains that blanket packs in repeated frost bursts.',
      ],
    ),
    'Pip_Lightning': ElementalAbility(
      name: 'Thunder Ricochet',
      ranks: [
        'Ricochet shot arcs chain lightning to nearby enemies.',
        'Extra bounces with stronger bonus lightning chains.',
        'STORM RICOCHET: Hyper-bouncing bolts that constantly chain lightning through enemies.',
      ],
    ),
    'Pip_Earth': ElementalAbility(
      name: 'Stone Ricochet',
      ranks: [
        'Ricochet shot creates knockback shockwaves on impact.',
        'More bounces plus stronger shockwaves and self-healing.',
        'QUAKE RICOCHET: Long chains that shove enemy packs away while mending the shooter.',
      ],
    ),
    'Pip_Plant': ElementalAbility(
      name: 'Thorn Ricochet',
      ranks: [
        'Ricochet shot seeds small thorn patches on early hits.',
        'Extra bounces with stronger, longer-lasting thorn zones.',
        'WILDPATCH RICOCHET: Ricochets trail thorny zones that chew through groups over time.',
      ],
    ),
    'Pip_Poison': ElementalAbility(
      name: 'Toxic Ricochet',
      ranks: [
        'Ricochet shot poisons enemies on each hit.',
        'More bounces with heavier poison damage over time.',
        'PLAGUE RICOCHET: Chains of shots that leave long-lasting poison on every enemy touched.',
      ],
    ),
    'Pip_Air': ElementalAbility(
      name: 'Gale Ricochet',
      ranks: [
        'Ricochet shot bursts with wind, pushing enemies on impact.',
        'Extra bounces with greater knockback from each gust.',
        'HURRICANE RICOCHET: Rapid chains that keep packs pushed back and off the Orb.',
      ],
    ),
    'Pip_Blood': ElementalAbility(
      name: 'Blood Ricochet',
      ranks: [
        'Ricochet shot drains HP from enemies on each hit.',
        'More bounces with stronger life drain shared with the team.',
        'TRANSFUSION RICOCHET: Long chains that massively siphon health to guardians and the Orb.',
      ],
    ),
    'Pip_Spirit': ElementalAbility(
      name: 'Spirit Ricochet',
      ranks: [
        'Ricochet shot marks enemies for delayed spirit damage.',
        'Extra bounces with larger delayed spirit bursts.',
        'ASCENSION RICOCHET: Chains that constantly plant spirit marks, causing repeated explosions.',
      ],
    ),
    'Pip_Dark': ElementalAbility(
      name: 'Void Ricochet',
      ranks: [
        'Ricochet shot deals bonus damage and grants lifesteal.',
        'More bounces with stronger lifesteal to the shooter.',
        'ECLIPSE RICOCHET: Rapid chains that shred enemies and heavily sustain the attacker.',
      ],
    ),
    'Pip_Light': ElementalAbility(
      name: 'Holy Ricochet',
      ranks: [
        'Ricochet shot sends out healing light to all guardians.',
        'Extra bounces with more team healing per hit.',
        'DIVINE RICOCHET: Long chains that shower your whole team with repeated healing flashes.',
      ],
    ),
    'Pip_Lava': ElementalAbility(
      name: 'Magma Ricochet',
      ranks: [
        'Ricochet shot leaves small lava cracks on impact.',
        'More bounces with stronger lingering lava damage zones.',
        'VOLCANIC RICOCHET: Chain of shots that carpets the field with burning magma patches.',
      ],
    ),
    'Pip_Steam': ElementalAbility(
      name: 'Steam Ricochet',
      ranks: [
        'Ricochet shot steams and slows enemies near each hit.',
        'Extra bounces with stronger slow and small Orb regen.',
        'GEYSER RICOCHET: Dense chains that keep packs hazy, slowed, and trickle-healing the Orb.',
      ],
    ),
    'Pip_Mud': ElementalAbility(
      name: 'Mud Ricochet',
      ranks: [
        'Ricochet shot creates sticky mud pools at impact.',
        'More bounces with stronger slowing mud pools.',
        'QUAGMIRE RICOCHET: Chains that litter the field with sticky zones bogging entire waves.',
      ],
    ),
    'Pip_Dust': ElementalAbility(
      name: 'Dust Ricochet',
      ranks: [
        'Ricochet shot scatters blinding dust, jittering enemies.',
        'Extra bounces with stronger confusion on nearby enemies.',
        'SANDSPARK RICOCHET: Rapid chains that keep packs constantly jittering and mis-stepping.',
      ],
    ),
    'Pip_Crystal': ElementalAbility(
      name: 'Crystal Ricochet',
      ranks: [
        'Ricochet shot can split into crystal shards hitting nearby enemies.',
        'More bounces with stronger shard splits.',
        'PRISM RICOCHET: Hyper-bouncing shots that keep spawning homing shards into targets.',
      ],
    ),

    // ══════════════════════════════════════════════════════════════════════════
    // MANE ABILITIES - Barrage
    // ══════════════════════════════════════════════════════════════════════════
    'Mane_Fire': ElementalAbility(
      name: 'Flame Barrage',
      ranks: [
        'Rapid fire cone that ignites enemies with stacking burn.',
        'More projectiles with stronger, longer-lasting burns.',
        'INFERNO BARRAGE: Massive volley that blankets the cone in intense burning damage.',
      ],
    ),
    'Mane_Ice': ElementalAbility(
      name: 'Frost Barrage',
      ranks: [
        'Rapid shots chill enemies and push them back slightly.',
        'More projectiles with heavier chill and pushback.',
        'GLACIER BARRAGE: Huge volley that heavily chills and shoves back whole packs of enemies.',
      ],
    ),
    'Mane_Lightning': ElementalAbility(
      name: 'Storm Barrage',
      ranks: [
        'Shots arc chain lightning from hit enemies to nearby targets.',
        'More projectiles with stronger chains devastating clustered foes.',
        'TEMPEST BARRAGE: Massive storm of bolts constantly chaining through enemy groups.',
      ],
    ),
    'Mane_Earth': ElementalAbility(
      name: 'Boulder Barrage',
      ranks: [
        'Heavy shots slam enemies with knockback on impact.',
        'More projectiles with greater knockback for zone control.',
        'AVALANCHE BARRAGE: Brutal volley that pummels enemies and hurls them away.',
      ],
    ),
    'Mane_Plant': ElementalAbility(
      name: 'Thorn Barrage',
      ranks: [
        'Shots inflict bleeding thorns that deal damage over time.',
        'More projectiles with stronger, rapidly stacking bleed.',
        'BLOOM BARRAGE: Dense hail of thorns blankets the cone in heavy bleeds.',
      ],
    ),
    'Mane_Poison': ElementalAbility(
      name: 'Toxin Barrage',
      ranks: [
        'Shots poison enemies in the cone.',
        'More projectiles with stronger, longer-lasting poison.',
        'PLAGUE BARRAGE: Huge volley inflicting powerful poison on anything in the cone.',
      ],
    ),
    'Mane_Water': ElementalAbility(
      name: 'Torrent Barrage',
      ranks: [
        'Water shots push enemies backward away from the Orb.',
        'More projectiles with stronger knockback forming a defensive wall.',
        'TSUNAMI BARRAGE: Massive volley that surges forward, throwing enemies far away.',
      ],
    ),
    'Mane_Air': ElementalAbility(
      name: 'Gale Barrage',
      ranks: [
        'Wind shots shove enemies back, disrupting their advance.',
        'More projectiles with stronger wind force peeling enemies away.',
        'HURRICANE BARRAGE: Roaring cone of shots that violently sweeps enemies out of position.',
      ],
    ),
    'Mane_Blood': ElementalAbility(
      name: 'Hemorrhage Barrage',
      ranks: [
        'Shots drain HP from enemies, healing you slightly.',
        'More projectiles with stronger lifesteal improving sustain.',
        'EXSANGUINATION BARRAGE: Massive volley draining hordes to massively heal you and the Orb.',
      ],
    ),
    'Mane_Spirit': ElementalAbility(
      name: 'Spectral Barrage',
      ranks: [
        'Ethereal shots deal spirit damage and siphon energy.',
        'More projectiles with improved piercing and drain.',
        'HAUNTING BARRAGE: Spectral storm that tears through waves while healing the caster.',
      ],
    ),
    'Mane_Dark': ElementalAbility(
      name: 'Shadow Barrage',
      ranks: [
        'Shots weaken enemies, dealing extra damage to wounded targets.',
        'More projectiles with stronger damage boost against low-HP targets.',
        'ECLIPSE BARRAGE: Crushing volley that brutally finishes off weakened enemies.',
      ],
    ),
    'Mane_Light': ElementalAbility(
      name: 'Radiant Barrage',
      ranks: [
        'Shots damage enemies and heal you slightly on hit.',
        'More projectiles with stronger healing during sustained fights.',
        'DIVINITY BARRAGE: Brilliant volley that heavily damages foes while providing strong self-healing.',
      ],
    ),
    'Mane_Lava': ElementalAbility(
      name: 'Magma Barrage',
      ranks: [
        'Molten shots slam enemies with extra knockback on impact.',
        'More projectiles with stronger impact sending enemies flying.',
        'VOLCANIC BARRAGE: Brutal lava hail that pounds enemies and scatters them violently.',
      ],
    ),
    'Mane_Steam': ElementalAbility(
      name: 'Vapor Barrage',
      ranks: [
        'Steam shots scorch and slightly disorient enemies.',
        'More projectiles with stronger disorientation and damage.',
        'GEYSER BARRAGE: Dense spray of scalding shots heavily disrupting and burning enemy groups.',
      ],
    ),
    'Mane_Mud': ElementalAbility(
      name: 'Sludge Barrage',
      ranks: [
        'Shots bog enemies down, slowing their advance.',
        'More projectiles with stronger slowing pushback clumping enemies.',
        'QUAGMIRE BARRAGE: Relentless muddy hail that severely hampers and pushes back waves.',
      ],
    ),
    'Mane_Dust': ElementalAbility(
      name: 'Dust Barrage',
      ranks: [
        'Dusty shots jostle enemy positions, scrambling movement.',
        'More projectiles with stronger disruption throwing off formations.',
        'DESERT BARRAGE: Churning dust volley keeping enemies stumbling and mispositioned.',
      ],
    ),
    'Mane_Crystal': ElementalAbility(
      name: 'Shard Barrage',
      ranks: [
        'Every few shots split into extra crystal shards hitting nearby enemies.',
        'More projectiles with stronger shard damage punishing clustered foes.',
        'PRISM BARRAGE: Massive hail constantly splitting into shards, shredding enemy packs.',
      ],
    ),

    // ══════════════════════════════════════════════════════════════════════════
    // MASK ABILITIES - Trap Field
    // ══════════════════════════════════════════════════════════════════════════
    'Mask_Fire': ElementalAbility(
      name: 'Flame Trap',
      ranks: [
        'Deploy fire traps that ignite enemies on trigger.',
        'More traps with larger radius and stronger burning zones.',
        'INFERNO GRID: Deploy a cluster of flame traps that chain burning zones across the field.',
      ],
    ),
    'Mask_Ice': ElementalAbility(
      name: 'Freeze Trap',
      ranks: [
        'Deploy ice traps that freeze or heavily slow enemies.',
        'More traps with longer freezes and lingering chill zones.',
        'PERMAFROST GRID: Field of freeze traps keeping enemies locked and slowed.',
      ],
    ),
    'Mask_Lightning': ElementalAbility(
      name: 'Shock Trap',
      ranks: [
        'Deploy traps that zap enemies and chain lightning.',
        'More traps with longer chains and brief stuns.',
        'TESLA GRID: Interlinked shock traps creating a large chain-lightning network.',
      ],
    ),
    'Mask_Earth': ElementalAbility(
      name: 'Spike Trap',
      ranks: [
        'Deploy traps that erupt stone spikes, damaging and stunning.',
        'More traps with stronger eruptions and ally shielding.',
        'FORTRESS GRID: Field of spike traps that control space and shield nearby allies.',
      ],
    ),
    'Mask_Plant': ElementalAbility(
      name: 'Vine Trap',
      ranks: [
        'Deploy traps that root enemies in place.',
        'More traps with longer roots and lingering thorn damage.',
        'GARDEN GRID: Web of vine traps continuously rooting and bleeding enemies.',
      ],
    ),
    'Mask_Poison': ElementalAbility(
      name: 'Toxin Trap',
      ranks: [
        'Deploy traps that release poison clouds on trigger.',
        'More traps with stronger clouds that heavily poison and slow.',
        'PANDEMIC GRID: Carpet of toxin traps spreading poison rapidly through packs.',
      ],
    ),
    'Mask_Water': ElementalAbility(
      name: 'Geyser Trap',
      ranks: [
        'Deploy traps that launch enemies and create slowing water.',
        'More traps with stronger knockup and ally healing near geysers.',
        'FOUNTAIN GRID: Field of geyser traps that juggle enemies and pulse healing to allies.',
      ],
    ),
    'Mask_Air': ElementalAbility(
      name: 'Wind Trap',
      ranks: [
        'Deploy traps that create tornados on trigger.',
        'More traps with stronger pull and damage over time.',
        'HURRICANE GRID: Multiple large tornado traps dragging enemies into deadly storm zones.',
      ],
    ),
    'Mask_Blood': ElementalAbility(
      name: 'Drain Trap',
      ranks: [
        'Deploy traps that leech HP from enemies and heal the team.',
        'More traps with stronger drains leaving healing blood pools.',
        'EXSANGUINATE GRID: Network of drain traps sucking life from huge clusters of enemies.',
      ],
    ),
    'Mask_Spirit': ElementalAbility(
      name: 'Ghost Trap',
      ranks: [
        'Deploy traps that summon attacking spirits when triggered.',
        'More traps with longer-lasting spirits that weaken enemies.',
        'HAUNTED GRID: Field of ghost traps maintaining a small spirit army harassing enemies.',
      ],
    ),
    'Mask_Dark': ElementalAbility(
      name: 'Void Trap',
      ranks: [
        'Deploy traps that create black holes pulling enemies inward.',
        'More traps with stronger pull and growing damage.',
        'SINGULARITY GRID: Many void traps forming a deadly gravity field shredding clustered enemies.',
      ],
    ),
    'Mask_Light': ElementalAbility(
      name: 'Radiance Trap',
      ranks: [
        'Deploy traps that blind and damage enemies on trigger.',
        'More traps with stronger blind and healing pulses for allies.',
        'REVELATION GRID: Field of radiant traps blinding enemies and constantly healing your team.',
      ],
    ),
    'Mask_Lava': ElementalAbility(
      name: 'Magma Trap',
      ranks: [
        'Deploy traps that create damaging lava pools.',
        'More traps with larger pools and occasional eruptions.',
        'VOLCANIC GRID: Lattice of magma traps turning huge areas into lava.',
      ],
    ),
    'Mask_Steam': ElementalAbility(
      name: 'Pressure Trap',
      ranks: [
        'Deploy traps that build pressure then explode in steam.',
        'More traps with bigger blasts healing allies and burning enemies.',
        'BOILER GRID: Chains of pressure traps causing repeated steam explosions.',
      ],
    ),
    'Mask_Mud': ElementalAbility(
      name: 'Quicksand Trap',
      ranks: [
        'Deploy traps that create mud pits heavily slowing enemies.',
        'More traps with larger pits and stronger slow that can root.',
        'QUAGMIRE GRID: Field of quicksand traps nearly stopping enemy movement around the Orb.',
      ],
    ),
    'Mask_Dust': ElementalAbility(
      name: 'Dust Trap',
      ranks: [
        'Deploy traps that create blinding dust clouds.',
        'More traps with bigger clouds and damage over time.',
        'SANDSTORM GRID: Network of dust traps covering large areas in debilitating sandstorms.',
      ],
    ),
    'Mask_Crystal': ElementalAbility(
      name: 'Prism Trap',
      ranks: [
        'Deploy traps that fire crystal shards at enemies.',
        'More traps with more piercing shards hitting multiple targets.',
        'CRYSTALLIZE GRID: Fortress of prism traps barraging enemies with homing crystal shards.',
      ],
    ),

    // ══════════════════════════════════════════════════════════════════════════
    // HORN ABILITIES - Nova
    // ══════════════════════════════════════════════════════════════════════════
    'Horn_Fire': ElementalAbility(
      name: 'Flame Nova',
      ranks: [
        'Nova ignites all nearby enemies with burning damage over time.',
        'Burn deals more damage and lasts longer with larger radius.',
        'CATACLYSMIC FLAME NOVA: Huge radius with a lingering fire ring that continuously scorches.',
      ],
    ),
    'Horn_Water': ElementalAbility(
      name: 'Tidal Nova',
      ranks: [
        'Nova damages enemies and heals guardians and Orb within range.',
        'Increased healing affecting a larger area.',
        'TIDAL NOVA: Massive, high-impact nova that heavily heals allies and shoves enemies back.',
      ],
    ),
    'Horn_Ice': ElementalAbility(
      name: 'Frost Nova',
      ranks: [
        'Nova creates a chilling zone that slows and pushes enemies away.',
        'Freezing zone lasts longer with stronger pushback.',
        'ABSOLUTE FROST NOVA: Huge radius, briefly freezes enemies while maintaining a powerful chill field.',
      ],
    ),
    'Horn_Lightning': ElementalAbility(
      name: 'Thunder Nova',
      ranks: [
        'Nova shocks nearby enemies, sending out chain lightning.',
        'Chain lightning becomes much stronger, devastating clustered enemies.',
        'JUDGMENT NOVA: Massive blast unleashing powerful chains of lightning through enemy packs.',
      ],
    ),
    'Horn_Earth': ElementalAbility(
      name: 'Seismic Nova',
      ranks: [
        'Nova grants you a stone shield while damaging nearby enemies.',
        'Shield value increased and nearby guardians also gain shielding.',
        'FORTRESS NOVA: Huge radius with a powerful earthen bulwark that heavily fortifies allies.',
      ],
    ),
    'Horn_Plant': ElementalAbility(
      name: 'Thorn Nova',
      ranks: [
        'Nova sprays thorns applying bleeding to nearby enemies.',
        'Thorns deal more damage and a bramble zone forms around you.',
        'BLOOMING THORN NOVA: Large-radius thorn eruption with a stronger root field pushing enemies away.',
      ],
    ),
    'Horn_Poison': ElementalAbility(
      name: 'Toxic Nova',
      ranks: [
        'Nova releases a toxic wave heavily poisoning nearby enemies.',
        'Poison damage and duration increased, punishing lingering enemies.',
        'PLAGUE NOVA: Huge poisonous blast with extremely potent, long-lasting poison.',
      ],
    ),
    'Horn_Air': ElementalAbility(
      name: 'Gale Nova',
      ranks: [
        'Nova creates a strong gust blasting nearby enemies away.',
        'Wind force and effective radius increase sending enemies flying.',
        'HURRICANE NOVA: Massive blast with a follow-up shockwave violently repelling enemies twice.',
      ],
    ),
    'Horn_Blood': ElementalAbility(
      name: 'Blood Nova',
      ranks: [
        'Nova drains nearby enemies, converting damage into healing.',
        'Drain potency increased, significantly improving sustain.',
        'TRANSFUSION NOVA: Huge radius blood burst draining many enemies, massively healing the team.',
      ],
    ),
    'Horn_Spirit': ElementalAbility(
      name: 'Spirit Nova',
      ranks: [
        'Nova unleashes spirit energy that damages and siphons life.',
        'Drain damage and self-healing increased for better sustain.',
        'ASCENDANT SPIRIT NOVA: Cataclysmic spirit burst with huge radius and powerful self-heal.',
      ],
    ),
    'Horn_Dark': ElementalAbility(
      name: 'Void Nova',
      ranks: [
        'Nova bathes enemies in darkness, executing those on very low health.',
        'Execute threshold and bonus damage to wounded enemies increased.',
        'ECLIPSE NOVA: Huge void shock executing low-health enemies and ravaging the injured.',
      ],
    ),
    'Horn_Light': ElementalAbility(
      name: 'Holy Nova',
      ranks: [
        'Nova damages nearby enemies while healing guardians and Orb.',
        'Healing greatly increased affecting more allies.',
        'DIVINE NOVA: Massive heal and damage in huge radius, plus cleanses negative effects.',
      ],
    ),
    'Horn_Lava': ElementalAbility(
      name: 'Magma Nova',
      ranks: [
        'Nova erupts with molten force, heavily damaging and knocking back.',
        'Both damage and knockback increased sending enemies flying farther.',
        'VOLCANIC NOVA: Massive, high-impact lava blast slamming enemies back with brutal force.',
      ],
    ),
    'Horn_Steam': ElementalAbility(
      name: 'Steam Nova',
      ranks: [
        'Nova releases scalding steam, damaging and disorienting enemies.',
        'Steam damage and disorienting scatter strength increased.',
        'GEYSER NOVA: Huge steam eruption dealing heavy damage and violently scattering enemies.',
      ],
    ),
    'Horn_Mud': ElementalAbility(
      name: 'Mud Nova',
      ranks: [
        'Nova creates a mud field heavily slowing and pushing enemies.',
        'Mud field lasts longer with stronger slowing pressure.',
        'QUAGMIRE NOVA: Large-radius mud explosion severely bogging down and repelling enemies.',
      ],
    ),
    'Horn_Dust': ElementalAbility(
      name: 'Dust Nova',
      ranks: [
        'Nova creates a dust burst jostling enemy positions.',
        'Dust cloud lingers, continuously jittering and confusing enemies.',
        'SANDSTORM NOVA: Large dust field heavily disrupting enemy formations.',
      ],
    ),
    'Horn_Crystal': ElementalAbility(
      name: 'Crystal Nova',
      ranks: [
        'Nova shatters into seeking crystal shards striking nearby enemies.',
        'More shards created with increased damage.',
        'PRISMATIC NOVA: Huge crystal eruption with many homing shards tearing through enemies.',
      ],
    ),

    // ══════════════════════════════════════════════════════════════════════════
    // WING ABILITIES - Beam
    // ══════════════════════════════════════════════════════════════════════════
    'Wing_Fire': ElementalAbility(
      name: 'Flame Beam',
      ranks: [
        'Beam scorches a line, igniting all enemies it pierces.',
        'Burns last longer and deal increased damage.',
        'SOLAR FLARE: Devastating wide fire beam that heavily burns and triggers chain explosions.',
      ],
    ),
    'Wing_Water': ElementalAbility(
      name: 'Hydro Beam',
      ranks: [
        'Beam pushes enemies backward in a line.',
        'Push strength and self-healing per enemy hit increased.',
        'TSUNAMI BEAM: Massive water beam shoving back crowds and greatly healing the caster.',
      ],
    ),
    'Wing_Ice': ElementalAbility(
      name: 'Cryo Beam',
      ranks: [
        'Beam chills enemies it pierces, slowing their advance.',
        'Stronger chill and knockback making enemies slide further.',
        'ABSOLUTE ZERO BEAM: Powerful freeze ray that can briefly lock the first enemy in ice.',
      ],
    ),
    'Wing_Lightning': ElementalAbility(
      name: 'Thunder Beam',
      ranks: [
        'Beam electrifies enemies, sending out small lightning arcs.',
        'Arcs chain farther hitting more nearby enemies.',
        'TEMPEST BEAM: Storm-powered beam chaining lightning through large enemy groups.',
      ],
    ),
    'Wing_Earth': ElementalAbility(
      name: 'Seismic Beam',
      ranks: [
        'Beam slams through enemies dealing extra impact damage.',
        'Impact weakens enemy defenses and grants a small stone shield.',
        'EARTHQUAKE BEAM: Crushing beam heavily shredding armor and granting a sturdy shield.',
      ],
    ),
    'Wing_Plant': ElementalAbility(
      name: 'Thorn Beam',
      ranks: [
        'Beam lances through enemies applying bleed over time.',
        'Bleeds grow stronger and last longer on pierced targets.',
        'BLOOM BEAM: Brutal thorn ray inflicting heavy stacking bleed across the whole line.',
      ],
    ),
    'Wing_Poison': ElementalAbility(
      name: 'Venom Beam',
      ranks: [
        'Beam poisons all enemies it passes through.',
        'Poison damage and duration increased, spreading to nearby enemies.',
        'PLAGUE BEAM: Noxious ray whose poison spreads from victims to nearby enemies.',
      ],
    ),
    'Wing_Air': ElementalAbility(
      name: 'Gale Beam',
      ranks: [
        'Beam unleashes a fierce gust pushing enemies away.',
        'Wind force increases heavily disrupting enemy formations.',
        'HURRICANE BEAM: Roaring wind beam blasting crowds back and shaking the battlefield.',
      ],
    ),
    'Wing_Blood': ElementalAbility(
      name: 'Hemorrhage Beam',
      ranks: [
        'Beam drains life from enemies, restoring HP to the caster.',
        'Lifesteal grows stronger and partially mends the Orb.',
        'EXSANGUINATE BEAM: Massive drain healing you, the Orb, and allies from all pierced foes.',
      ],
    ),
    'Wing_Spirit': ElementalAbility(
      name: 'Phantom Beam',
      ranks: [
        'Beam inflicts spiritual damage siphoning energy from enemies.',
        'Drain power increases restoring more health to the caster.',
        'HAUNTING BEAM: Spectral ray heavily draining spirit from all in its path.',
      ],
    ),
    'Wing_Dark': ElementalAbility(
      name: 'Shadow Beam',
      ranks: [
        'Beam curses enemies in a line, harming weakened foes more.',
        'Execution threshold and bonus damage to wounded increased.',
        'ECLIPSE BEAM: Grim ray executing low HP enemies and ravaging injured targets.',
      ],
    ),
    'Wing_Light': ElementalAbility(
      name: 'Holy Beam',
      ranks: [
        'Beam damages enemies while gently healing allied guardians.',
        'Healing stronger and reaches more allies.',
        'DIVINITY BEAM: Radiant ray restoring the team and healing the Orb while smiting enemies.',
      ],
    ),
    'Wing_Lava': ElementalAbility(
      name: 'Magma Beam',
      ranks: [
        'Beam leaves molten patches along its path burning enemies.',
        'Lava patches last longer with heavier damage over time.',
        'VOLCANIC BEAM: Superheated ray carving a long trail of searing lava.',
      ],
    ),
    'Wing_Steam': ElementalAbility(
      name: 'Vapor Beam',
      ranks: [
        'Beam scalds enemies creating small pockets of steam.',
        'Steam eruptions deal extra splash damage around hit targets.',
        'GEYSER BEAM: Overheated ray filling the line with violent steam bursts.',
      ],
    ),
    'Wing_Mud': ElementalAbility(
      name: 'Sludge Beam',
      ranks: [
        'Beam coats the ground in mud heavily slowing enemies.',
        'Mud slow grows stronger making enemies struggle to advance.',
        'QUAGMIRE BEAM: Viscous ray leaving a line of crippling sludge nearly rooting enemies.',
      ],
    ),
    'Wing_Dust': ElementalAbility(
      name: 'Sandblast Beam',
      ranks: [
        'Beam blasts enemies with dust jostling and disorienting them.',
        'Dust grows heavier causing stronger disruption and confusion.',
        'DESERT BEAM: Howling sand ray wildly scattering enemy positions and ruining accuracy.',
      ],
    ),
    'Wing_Crystal': ElementalAbility(
      name: 'Prism Beam',
      ranks: [
        'Beam shards on impact sending crystal projectiles to nearby enemies.',
        'More shards spawn with increased damage.',
        'REFRACTION BEAM: Brilliant ray showering the battlefield with homing crystal shards.',
      ],
    ),

    // ══════════════════════════════════════════════════════════════════════════
    // KIN ABILITIES - Blessing
    // ══════════════════════════════════════════════════════════════════════════
    'Kin_Fire': ElementalAbility(
      name: 'Flame Blessing',
      ranks: [
        'Heals the Orb and grants allies a burning aura damaging nearby enemies.',
        'Larger aura radius with increased burn damage.',
        'INFERNO: Massive heal plus a wide burning aura around the Orb.',
      ],
    ),
    'Kin_Water': ElementalAbility(
      name: 'Tidal Blessing',
      ranks: [
        'Heals the Orb and pushes nearby enemies, cleansing ally debuffs.',
        'Stronger pushback with bigger Orb heal.',
        'FOUNTAIN: Big heal to allies and Orb with continuous enemy pushback.',
      ],
    ),
    'Kin_Ice': ElementalAbility(
      name: 'Frost Blessing',
      ranks: [
        'Heals the Orb and creates a protective ice zone slowing enemies.',
        'Larger ice zone with stronger slow effect.',
        'GLACIER: Massive heal plus a freezing zone that protects the Orb.',
      ],
    ),
    'Kin_Lightning': ElementalAbility(
      name: 'Storm Blessing',
      ranks: [
        'Heals the Orb and strikes random enemies with lightning.',
        'More lightning strikes with chain damage to nearby enemies.',
        'TEMPEST: Massive heal plus a persistent lightning field stunning and zapping enemies.',
      ],
    ),
    'Kin_Earth': ElementalAbility(
      name: 'Stone Blessing',
      ranks: [
        'Heals the Orb and grants shields to all allies in range.',
        'Larger shields with wider radius.',
        'FORTRESS: Massive heal plus protective stone shields for all allies.',
      ],
    ),
    'Kin_Plant': ElementalAbility(
      name: 'Growth Blessing',
      ranks: [
        'Heals the Orb and creates a healing garden that damages enemies.',
        'Larger garden with stronger regen and thorn damage.',
        'BLOOM: Massive heal plus vines and thorns covering the Orb\'s area.',
      ],
    ),
    'Kin_Poison': ElementalAbility(
      name: 'Venom Blessing',
      ranks: [
        'Heals the Orb and poisons all nearby enemies.',
        'Stronger poison with longer duration.',
        'PLAGUE: Massive heal plus a wide toxic aura infecting all nearby enemies.',
      ],
    ),
    'Kin_Air': ElementalAbility(
      name: 'Wind Blessing',
      ranks: [
        'Heals the Orb and blasts all nearby enemies away.',
        'Stronger knockback with wider radius.',
        'HURRICANE: Massive heal plus a powerful wind barrier around the Orb.',
      ],
    ),
    'Kin_Blood': ElementalAbility(
      name: 'Blood Blessing',
      ranks: [
        'Drains nearby enemies to heal the Orb and applies heal over time.',
        'Stronger drain with longer HoT duration.',
        'TRANSFUSION: Drain all nearby enemies for a massive team heal.',
      ],
    ),
    'Kin_Spirit': ElementalAbility(
      name: 'Spirit Blessing',
      ranks: [
        'Drains enemies to heal the Orb and allies.',
        'Increased drain damage with more healing distribution.',
        'ASCENSION: Massive drain plus empowered healing for the whole team.',
      ],
    ),
    'Kin_Dark': ElementalAbility(
      name: 'Void Blessing',
      ranks: [
        'Heals the Orb while executing very low health enemies.',
        'Higher execute threshold with attacker healing per execute.',
        'ECLIPSE: Massive heal plus blinding darkness that executes weak enemies.',
      ],
    ),
    'Kin_Light': ElementalAbility(
      name: 'Holy Blessing',
      ranks: [
        'Heals all guardians and the Orb while damaging nearby enemies.',
        'Greatly increased healing affecting all guardians.',
        'DIVINITY: Huge screen-wide heal, damage burst to enemies, and debuff cleanse.',
      ],
    ),
    'Kin_Lava': ElementalAbility(
      name: 'Magma Blessing',
      ranks: [
        'Heals the Orb and damages nearby enemies with knockback.',
        'Increased damage and knockback radius.',
        'VOLCANIC: Massive heal plus a large lava field surrounding the Orb.',
      ],
    ),
    'Kin_Steam': ElementalAbility(
      name: 'Vapor Blessing',
      ranks: [
        'Heals the Orb and damages nearby enemies with steam.',
        'Larger steam burst with more damage.',
        'GEYSER: Continuous healing pulses and steam explosions around the Orb.',
      ],
    ),
    'Kin_Mud': ElementalAbility(
      name: 'Earth Blessing',
      ranks: [
        'Heals the Orb and creates a slowing mud field pushing enemies back.',
        'Larger mud field with stronger slow and pushback.',
        'QUAGMIRE: Massive heal plus mud that heavily slows and can root enemies.',
      ],
    ),
    'Kin_Dust': ElementalAbility(
      name: 'Sand Blessing',
      ranks: [
        'Heals the Orb and jitters enemy positions with dust.',
        'Stronger confusion with wider effect.',
        'SANDSTORM: Massive heal plus a large dust storm that disorients enemies.',
      ],
    ),
    'Kin_Crystal': ElementalAbility(
      name: 'Prism Blessing',
      ranks: [
        'Heals the Orb and grants allies auto-targeting crystal shards.',
        'More shards with longer duration.',
        'CRYSTALLIZE: Massive heal plus a crystal fortress firing shards at enemies.',
      ],
    ),

    // ══════════════════════════════════════════════════════════════════════════
    // MYSTIC ABILITIES - Orbitals
    // ══════════════════════════════════════════════════════════════════════════
    'Mystic_Fire': ElementalAbility(
      name: 'Flame Orbitals',
      ranks: [
        'Summon fire orbitals that seek enemies with burn splash on hit.',
        'More orbitals with stronger burn AoE and increased damage.',
        'INFERNO SWARM: Many orbitals with huge burn explosions.',
      ],
    ),
    'Mystic_Water': ElementalAbility(
      name: 'Tidal Orbitals',
      ranks: [
        'Summon water orbitals that heal nearby allies on hit.',
        'More orbitals with larger healing radius.',
        'TSUNAMI SWARM: Many orbitals with big team heals.',
      ],
    ),
    'Mystic_Ice': ElementalAbility(
      name: 'Frost Orbitals',
      ranks: [
        'Summon ice orbitals that slow enemies around impact.',
        'More orbitals with stronger slow radius.',
        'ABSOLUTE ZERO SWARM: Many orbitals massively slowing packs.',
      ],
    ),
    'Mystic_Lightning': ElementalAbility(
      name: 'Storm Orbitals',
      ranks: [
        'Summon lightning orbitals that fire small lightning chains.',
        'More orbitals with more chains and extra damage.',
        'JUDGMENT SWARM: Many orbitals with brutal chain lightning.',
      ],
    ),
    'Mystic_Earth': ElementalAbility(
      name: 'Stone Orbitals',
      ranks: [
        'Summon earth orbitals that deal AoE damage and grant self-healing.',
        'More orbitals with larger AoE and stronger shield-heal.',
        'FORTRESS SWARM: Many orbitals with big AoE and shielding.',
      ],
    ),
    'Mystic_Plant': ElementalAbility(
      name: 'Thorn Orbitals',
      ranks: [
        'Summon plant orbitals that seed small thorn zones.',
        'More orbitals with larger, longer-lasting thorn zones.',
        'BLOOM SWARM: Many orbitals carpeting thorns.',
      ],
    ),
    'Mystic_Poison': ElementalAbility(
      name: 'Toxic Orbitals',
      ranks: [
        'Summon poison orbitals that apply heavy poison and spread to nearby.',
        'More orbitals with stronger, longer poison spreading wider.',
        'PLAGUE SWARM: Many orbitals stacking poison everywhere.',
      ],
    ),
    'Mystic_Air': ElementalAbility(
      name: 'Gale Orbitals',
      ranks: [
        'Summon air orbitals that push enemies away from impact.',
        'More orbitals with stronger knockback in wider area.',
        'HURRICANE SWARM: Many orbitals blasting packs apart.',
      ],
    ),
    'Mystic_Blood': ElementalAbility(
      name: 'Blood Orbitals',
      ranks: [
        'Summon blood orbitals that grant heavy lifesteal on hit.',
        'More orbitals with stronger lifesteal amount.',
        'TRANSFUSION SWARM: Many orbitals with massive lifesteal.',
      ],
    ),
    'Mystic_Spirit': ElementalAbility(
      name: 'Spirit Orbitals',
      ranks: [
        'Summon spirit orbitals that deal spectral splash and heal caster.',
        'More orbitals with larger splash and stronger healing.',
        'ASCENSION SWARM: Many orbitals with huge spirit blasts and healing.',
      ],
    ),
    'Mystic_Dark': ElementalAbility(
      name: 'Void Orbitals',
      ranks: [
        'Summon dark orbitals that drain extra HP from targets.',
        'More orbitals with stronger drain and healing.',
        'ECLIPSE SWARM: Many orbitals with massive dark drains.',
      ],
    ),
    'Mystic_Light': ElementalAbility(
      name: 'Holy Orbitals',
      ranks: [
        'Summon light orbitals that heal nearby allies and damage enemies.',
        'More orbitals with larger heals and stronger damage.',
        'DIVINITY SWARM: Many orbitals with huge heals and holy damage.',
      ],
    ),
    'Mystic_Lava': ElementalAbility(
      name: 'Magma Orbitals',
      ranks: [
        'Summon lava orbitals that cause explosions with knockback.',
        'More orbitals with larger explosion radius and damage.',
        'VOLCANIC SWARM: Many orbitals causing massive lava explosions.',
      ],
    ),
    'Mystic_Steam': ElementalAbility(
      name: 'Steam Orbitals',
      ranks: [
        'Summon steam orbitals that chip enemies and heal the Orb.',
        'More orbitals with area chip damage and stronger Orb healing.',
        'GEYSER SWARM: Many orbitals scalding enemies and feeding the Orb.',
      ],
    ),
    'Mystic_Mud': ElementalAbility(
      name: 'Mud Orbitals',
      ranks: [
        'Summon mud orbitals that create small slow puddles on impact.',
        'More orbitals with larger, longer-lasting mud fields.',
        'QUAGMIRE SWARM: Many orbitals spreading heavy mud control.',
      ],
    ),
    'Mystic_Dust': ElementalAbility(
      name: 'Dust Orbitals',
      ranks: [
        'Summon dust orbitals that briefly confuse nearby enemies.',
        'More orbitals with larger confusion radius and intensity.',
        'SANDSTORM SWARM: Many orbitals constantly displacing enemies.',
      ],
    ),
    'Mystic_Crystal': ElementalAbility(
      name: 'Crystal Orbitals',
      ranks: [
        'Summon crystal orbitals that fire mini shard chains to nearby.',
        'More orbitals with more shards and increased damage.',
        'PRISM SWARM: Many orbitals with relentless crystal chains.',
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

/// Represents an elemental ability's progression (3-tier system)
class ElementalAbility {
  final String name;
  final List<String> ranks; // exactly 3 entries: [rank1, rank2, rank3]

  const ElementalAbility({required this.name, required this.ranks});

  /// Get description for power tier 1–3
  String getDescription(int rank) {
    if (ranks.isEmpty) return 'No description';
    final clamped = rank.clamp(1, ranks.length);
    return ranks[clamped - 1];
  }
}
