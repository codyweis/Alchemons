/// Generated asset catalog; metadata below controls runtime mixing.
enum SoundCue {
  uiTap('assets/audio/sounds/sfx_ui_tap.wav'),
  uiConfirm('assets/audio/sounds/sfx_ui_confirm.wav'),
  uiBack('assets/audio/sounds/sfx_ui_back.wav'),
  uiPanelOpen('assets/audio/sounds/sfx_ui_panel_open.wav'),
  uiPanelClose('assets/audio/sounds/sfx_ui_panel_close.wav'),
  uiDenied('assets/audio/sounds/sfx_ui_denied.wav'),
  uiSelect('assets/audio/sounds/sfx_ui_select.wav'),
  rewardCollect('assets/audio/sounds/sfx_reward_collect.wav'),
  currencyGain('assets/audio/sounds/sfx_currency_gain.wav'),
  purchaseSuccess('assets/audio/sounds/sfx_purchase_success.wav'),
  upgradeComplete('assets/audio/sounds/sfx_upgrade_complete.wav'),
  achievementUnlock('assets/audio/sounds/sfx_achievement_unlock.wav'),

  /// A constellation stone reached by a link: the grains run down the link
  /// for ConnectionLine.pourDuration (1.05 s), and the stone seats and
  /// ignites as they land. A stone with no link ignites at once and plays
  /// [upgradeComplete] instead.
  constellationAttune('assets/audio/sounds/sfx_constellation_attune.wav'),

  /// The Mystic Altar's rite, whole (AltarRiteField's summon clock from 0):
  /// the offerings pour in, are crushed into a shivering knot, and it bursts
  /// at knotEnd (2.7 s). One cue so the burst cannot drift from its knot.
  altarRite('assets/audio/sounds/sfx_altar_rite.wav'),

  /// The Mystic stands whole and takes its first breath, as the awake card
  /// comes up.
  altarAwake('assets/audio/sounds/sfx_altar_awake.wav'),

  /// SEAL AND DEPART: the Mystic winds into a sphere of its grains (0.74 s),
  /// is stoppered, and drops away (1.35 s).
  altarSeal('assets/audio/sounds/sfx_altar_seal.wav'),
  cosmicPortalOpen('assets/audio/sounds/cosmic/sfx_cosmic_portal_open.wav'),
  cosmicOrbPickup('assets/audio/sounds/cosmic/sfx_cosmic_orb_pickup.wav'),
  cosmicOrbDeposit('assets/audio/sounds/cosmic/sfx_cosmic_orb_deposit.wav'),
  cosmicMatterCollect('assets/audio/sounds/sfx_cosmic_matter_collect.wav'),
  cosmicAnomalyBurst('assets/audio/sounds/cosmic/sfx_cosmic_anomaly_burst.wav'),
  cosmicStarforgeActivate(
    'assets/audio/sounds/cosmic/sfx_cosmic_starforge_activate.wav',
  ),
  /// The Mystic Altar's heart tearing open into the arcane rift: scored to
  /// its 3.4 s swell (the disk spinning up, the violet flash peaking at
  /// ~3.06 s), where the general portal-open would be over before the tear.
  altarRiftTear('assets/audio/sounds/sfx_altar_rift_tear.wav'),
  cosmicDash('assets/audio/sounds/sfx_cosmic_dash.wav'),
  cosmicPlanetEnter('assets/audio/sounds/sfx_cosmic_planet_enter.wav'),
  cosmicCacheOpen('assets/audio/sounds/sfx_cosmic_cache_open.wav'),
  cosmicDiscovery('assets/audio/sounds/sfx_cosmic_discovery.wav'),
  cosmicScan('assets/audio/sounds/sfx_cosmic_scan.wav'),
  combatProjectile('assets/audio/sounds/sfx_combat_projectile.wav'),

  /// The ship's own gun (open cosmos and Survival): a capacitor crack and
  /// the hull's recoil -- not a creature's launch. Fires 4-8 a second.
  shipBolt('assets/audio/sounds/sfx_ship_bolt.wav'),

  /// The ship's homing missile: a clamp lets go, the motor catches and
  /// tears away.
  shipMissile('assets/audio/sounds/sfx_ship_missile.wav'),
  combatHitLight('assets/audio/sounds/sfx_combat_hit_light.wav'),
  combatHitHeavy('assets/audio/sounds/sfx_combat_hit_heavy.wav'),
  combatPlayerHurt('assets/audio/sounds/sfx_combat_player_hurt.wav'),
  combatEnemyDefeat('assets/audio/sounds/sfx_combat_enemy_defeat.wav'),
  combatShieldHit('assets/audio/sounds/sfx_combat_shield_hit.wav'),
  combatShieldBreak('assets/audio/sounds/sfx_combat_shield_break.wav'),
  combatHeal('assets/audio/sounds/sfx_combat_heal.wav'),
  combatDanger('assets/audio/sounds/sfx_combat_danger.wav'),
  combatVictory('assets/audio/sounds/sfx_combat_victory.wav'),
  combatDefeat('assets/audio/sounds/sfx_combat_defeat.wav'),
  combatSpecialCast('assets/audio/sounds/sfx_combat_special_cast.wav'),

  // Horn: tool/sounds/family_horn.py, scored to its drawn attacks.
  specialHorn('assets/audio/sounds/sfx_special_horn.wav'),
  specialHornHeavy('assets/audio/sounds/sfx_special_horn_heavy.wav'),
  specialHornCircle('assets/audio/sounds/sfx_special_horn_circle.wav'),
  specialHornGather('assets/audio/sounds/sfx_special_horn_gather.wav'),
  specialHornBrace('assets/audio/sounds/sfx_special_horn_brace.wav'),
  specialHornVoid('assets/audio/sounds/sfx_special_horn_void.wav'),
  specialHornBarrier('assets/audio/sounds/sfx_special_horn_barrier.wav'),
  specialHornSlam('assets/audio/sounds/sfx_special_horn_slam.wav'),
  specialHornSlamHeavy('assets/audio/sounds/sfx_special_horn_slam_heavy.wav'),
  specialHornBrew('assets/audio/sounds/sfx_special_horn_brew.wav'),
  specialHornDischarge('assets/audio/sounds/sfx_special_horn_discharge.wav'),

  // Kin: tool/sounds/family_kin.py, scored to its drawn attacks.
  basicKinCharge('assets/audio/sounds/sfx_basic_kin_charge.wav'),
  specialKin('assets/audio/sounds/sfx_special_kin.wav'),
  specialKinEscort('assets/audio/sounds/sfx_special_kin_escort.wav'),
  specialKinRain('assets/audio/sounds/sfx_special_kin_rain.wav'),
  specialKinUpdraft('assets/audio/sounds/sfx_special_kin_updraft.wav'),
  specialKinGarden('assets/audio/sounds/sfx_special_kin_garden.wav'),
  specialKinWall('assets/audio/sounds/sfx_special_kin_wall.wav'),
  specialKinBank('assets/audio/sounds/sfx_special_kin_bank.wav'),
  specialKinDarts('assets/audio/sounds/sfx_special_kin_darts.wav'),
  specialKinCharge('assets/audio/sounds/sfx_special_kin_charge.wav'),
  specialKinIceRelease('assets/audio/sounds/sfx_special_kin_ice_release.wav'),
  specialKinChannel('assets/audio/sounds/sfx_special_kin_channel.wav'),
  specialKinPlate('assets/audio/sounds/sfx_special_kin_plate.wav'),
  specialKinBoiler('assets/audio/sounds/sfx_special_kin_boiler.wav'),
  specialKinSling('assets/audio/sounds/sfx_special_kin_sling.wav'),
  specialKinVeil('assets/audio/sounds/sfx_special_kin_veil.wav'),
  specialKinPact('assets/audio/sounds/sfx_special_kin_pact.wav'),
  specialKinWisp('assets/audio/sounds/sfx_special_kin_wisp.wav'),
  specialKinWispTier('assets/audio/sounds/sfx_special_kin_wisp_tier.wav'),
  specialKinPhoenix('assets/audio/sounds/sfx_special_kin_phoenix.wav'),

  // Let: tool/sounds/family_let.py, scored to its drawn attacks.
  basicLetDeadfall('assets/audio/sounds/sfx_basic_let_deadfall.wav'),
  specialLet('assets/audio/sounds/sfx_special_let.wav'),
  specialLetEarth('assets/audio/sounds/sfx_special_let_earth.wav'),
  specialLetImpact('assets/audio/sounds/sfx_special_let_impact.wav'),
  specialLetImpactEarth('assets/audio/sounds/sfx_special_let_impact_earth.wav'),
  specialLetImpactAiry('assets/audio/sounds/sfx_special_let_impact_airy.wav'),
  specialLetImpactBarrage('assets/audio/sounds/sfx_special_let_impact_barrage.wav'),
  specialLetImpactMinor('assets/audio/sounds/sfx_special_let_impact_minor.wav'),

  // Mane: tool/sounds/family_mane.py, scored to its drawn attacks.
  specialMane('assets/audio/sounds/sfx_special_mane.wav'),
  specialManeGale('assets/audio/sounds/sfx_special_mane_gale.wav'),
  specialManeVolley('assets/audio/sounds/sfx_special_mane_volley.wav'),
  specialManeScatter('assets/audio/sounds/sfx_special_mane_scatter.wav'),
  specialManeStream('assets/audio/sounds/sfx_special_mane_stream.wav'),
  specialManeWard('assets/audio/sounds/sfx_special_mane_ward.wav'),
  specialManeOrbLand('assets/audio/sounds/sfx_special_mane_orb_land.wav'),
  specialManeBurst('assets/audio/sounds/sfx_special_mane_burst.wav'),
  specialManeShatter('assets/audio/sounds/sfx_special_mane_shatter.wav'),
  specialManeQuake('assets/audio/sounds/sfx_special_mane_quake.wav'),

  // Mask: tool/sounds/family_mask.py, scored to its drawn attacks.
  specialMask('assets/audio/sounds/sfx_special_mask.wav'),
  specialMaskSingle('assets/audio/sounds/sfx_special_mask_single.wav'),
  specialMaskFeed('assets/audio/sounds/sfx_special_mask_feed.wav'),
  specialMaskWrap('assets/audio/sounds/sfx_special_mask_wrap.wav'),
  specialMaskSpringLight('assets/audio/sounds/sfx_special_mask_spring_light.wav'),
  specialMaskSpringCrystal('assets/audio/sounds/sfx_special_mask_spring_crystal.wav'),
  specialMaskSpringFire('assets/audio/sounds/sfx_special_mask_spring_fire.wav'),
  specialMaskSpringWater('assets/audio/sounds/sfx_special_mask_spring_water.wav'),
  specialMaskSpringDark('assets/audio/sounds/sfx_special_mask_spring_dark.wav'),

  // Mystic: tool/sounds/family_mystic.py, scored to its drawn attacks.
  specialMystic('assets/audio/sounds/sfx_special_mystic.wav'),
  specialMysticRise('assets/audio/sounds/sfx_special_mystic_rise.wav'),
  specialMysticClose('assets/audio/sounds/sfx_special_mystic_close.wav'),
  specialMysticStrike('assets/audio/sounds/sfx_special_mystic_strike.wav'),
  specialMysticQuake('assets/audio/sounds/sfx_special_mystic_quake.wav'),
  specialMysticVent('assets/audio/sounds/sfx_special_mystic_vent.wav'),
  specialMysticRain('assets/audio/sounds/sfx_special_mystic_rain.wav'),
  specialMysticMeteor('assets/audio/sounds/sfx_special_mystic_meteor.wav'),
  specialMysticDawn('assets/audio/sounds/sfx_special_mystic_dawn.wav'),

  // Pip: tool/sounds/family_pip.py, scored to its drawn attacks.
  specialPip('assets/audio/sounds/sfx_special_pip.wav'),
  specialPipSeeker('assets/audio/sounds/sfx_special_pip_seeker.wav'),
  specialPipHeavy('assets/audio/sounds/sfx_special_pip_heavy.wav'),
  specialPipRicochet('assets/audio/sounds/sfx_special_pip_ricochet.wav'),
  specialPipVoid('assets/audio/sounds/sfx_special_pip_void.wav'),

  // Wing: tool/sounds/family_wing.py, scored to its drawn attacks.
  specialWingCharge('assets/audio/sounds/sfx_special_wing_charge.wav'),
  specialWing('assets/audio/sounds/sfx_special_wing.wav'),
  specialWingRing('assets/audio/sounds/sfx_special_wing_ring.wav'),
  specialWingLong('assets/audio/sounds/sfx_special_wing_long.wav'),
  specialWingRingLong('assets/audio/sounds/sfx_special_wing_ring_long.wav'),
  specialWingLongest('assets/audio/sounds/sfx_special_wing_longest.wav'),
  specialWingRingLongest('assets/audio/sounds/sfx_special_wing_ring_longest.wav'),
  // One per FAMILY, because an alchemon's basic attack is its family's and
  // the eight throw genuinely different things — see createFamilyBasicAttack.
  basicMane('assets/audio/sounds/sfx_basic_mane.wav'),
  basicLet('assets/audio/sounds/sfx_basic_let.wav'),
  basicPip('assets/audio/sounds/sfx_basic_pip.wav'),
  basicHorn('assets/audio/sounds/sfx_basic_horn.wav'),
  basicMask('assets/audio/sounds/sfx_basic_mask.wav'),
  basicWing('assets/audio/sounds/sfx_basic_wing.wav'),
  basicKin('assets/audio/sounds/sfx_basic_kin.wav'),
  basicMystic('assets/audio/sounds/sfx_basic_mystic.wav'),
  survivalWaveStart('assets/audio/sounds/sfx_survival_wave_start.wav'),
  survivalWaveClear('assets/audio/sounds/sfx_survival_wave_clear.wav'),
  survivalBossArrive('assets/audio/sounds/sfx_survival_boss_arrive.wav'),
  survivalPowerupCollect(
    'assets/audio/sounds/sfx_survival_powerup_collect.wav',
  ),
  survivalPowerupChoose('assets/audio/sounds/sfx_survival_powerup_choose.wav'),
  survivalOutbreak('assets/audio/sounds/sfx_survival_outbreak.wav'),
  survivalMilestone('assets/audio/sounds/sfx_survival_milestone.wav'),
  dungeonInteract('assets/audio/sounds/sfx_dungeon_interact.wav'),
  dungeonGateOpen('assets/audio/sounds/sfx_dungeon_gate_open.wav'),
  dungeonSwitch('assets/audio/sounds/sfx_dungeon_switch.wav'),
  dungeonPuzzleSolved('assets/audio/sounds/sfx_dungeon_puzzle_solved.wav'),
  dungeonStarCollect('assets/audio/sounds/sfx_dungeon_star_collect.wav'),
  dungeonSecretReveal('assets/audio/sounds/sfx_dungeon_secret_reveal.wav'),
  dungeonWallBreak('assets/audio/sounds/sfx_dungeon_wall_break.wav'),
  dungeonBlockMove('assets/audio/sounds/sfx_dungeon_block_move.wav'),
  dungeonHazardTrigger('assets/audio/sounds/sfx_dungeon_hazard_trigger.wav'),
  dungeonCheckpoint('assets/audio/sounds/sfx_dungeon_checkpoint.wav'),
  dungeonRelicCollect('assets/audio/sounds/sfx_dungeon_relic_collect.wav'),
  dungeonStepStone('assets/audio/sounds/sfx_dungeon_step_stone.wav'),
  dungeonStepWater('assets/audio/sounds/sfx_dungeon_step_water.wav'),
  creatureSummon('assets/audio/sounds/sfx_creature_summon.wav'),
  /// A harvester chosen, before the field engages.
  captureThrow('assets/audio/sounds/sfx_capture_throw.wav'),

  /// The harvest's seize, its take and its break: played on
  /// [HarvestParticleField.beats], so each lands on its frame. Built by
  /// tool/sounds/harvest.py from the field's own timing.
  captureAttempt('assets/audio/sounds/sfx_capture_attempt.wav'),
  captureSuccess('assets/audio/sounds/sfx_capture_success.wav'),
  captureEscape('assets/audio/sounds/sfx_capture_escape.wav'),

  /// The breed tab's merge (FusionParticleField): the pair turn to grains,
  /// pour over the gap, circle the orb and fall in. Scored from the field's
  /// measured motion by tool/sounds/fusion.py; its tail rings on into the
  /// eruption.
  fusionMerge('assets/audio/sounds/sfx_fusion_merge.wav'),

  /// The fusion cinematic from the moment its particles take over
  /// (FusionBurstField): knot, eruption, gather, the sigil's lock.
  fusionEruption('assets/audio/sounds/sfx_fusion_eruption.wav'),

  /// A wild fusion, which plays the merge in two pieces either side of its
  /// verdict (ParticleFusionEffect): the pair turn to grains and stand, then
  /// pour together -- or the grains run back into them.
  fusionCalibrate('assets/audio/sounds/sfx_fusion_calibrate.wav'),
  fusionPour('assets/audio/sounds/sfx_fusion_pour.wav'),
  fusionRecoil('assets/audio/sounds/sfx_fusion_recoil.wav'),
  harvestCollect('assets/audio/sounds/sfx_harvest_collect.wav'),

  /// The Enhance screen (tool/sounds/enhance.py), each scored to its own
  /// animation: kin coming apart and pouring into the specimen (one take per
  /// kin count, 1-6+, since the pour lengthens with it), a power orb's lob
  /// and climb, a potential soul's rite by roll (1-5: longer and brighter),
  /// and the last level reached.
  enhancePour1('assets/audio/sounds/sfx_enhance_pour_1.wav'),
  enhancePour2('assets/audio/sounds/sfx_enhance_pour_2.wav'),
  enhancePour3('assets/audio/sounds/sfx_enhance_pour_3.wav'),
  enhancePour4('assets/audio/sounds/sfx_enhance_pour_4.wav'),
  enhancePour5('assets/audio/sounds/sfx_enhance_pour_5.wav'),
  enhancePour6('assets/audio/sounds/sfx_enhance_pour_6.wav'),
  enhanceOrb('assets/audio/sounds/sfx_enhance_orb.wav'),
  enhanceSoul1('assets/audio/sounds/sfx_enhance_soul_1.wav'),
  enhanceSoul2('assets/audio/sounds/sfx_enhance_soul_2.wav'),
  enhanceSoul3('assets/audio/sounds/sfx_enhance_soul_3.wav'),
  enhanceSoul4('assets/audio/sounds/sfx_enhance_soul_4.wav'),
  enhanceSoul5('assets/audio/sounds/sfx_enhance_soul_5.wav'),
  enhanceMaxLevel('assets/audio/sounds/sfx_enhance_max_level.wav'),

  /// A reward flying from its card to its total (playRewardCollect): thrown
  /// out, drawn in, every piece arriving at once at 0.98 s. Played by the
  /// flight itself, so every screen that uses it sounds the same.
  rewardFlight('assets/audio/sounds/sfx_reward_flight.wav'),
  extractionComplete('assets/audio/sounds/sfx_extraction_complete.wav'),

  /// The whole hatching ceremony, scored to the shell's own beats rather
  /// than fired as separate hits: the parents' motes, their strands swirling
  /// in, the settle as the shell cinches at 4.25s, and the glass ringing it
  /// open as it unravels at 5.24s; gone before the 6.05s handover cuts it.
  /// One cue, so the ceremony cannot drift out of sync with itself. Built by
  /// tool/sounds/extraction.py, where the beat times live.
  extractionCeremony('assets/audio/sounds/sfx_extraction_ceremony.wav'),
  extractionCreatureReveal(
    'assets/audio/sounds/sfx_extraction_creature_reveal.wav',
  ),
  extractionRareReveal('assets/audio/sounds/sfx_extraction_rare_reveal.wav'),
  elementFire('assets/audio/sounds/sfx_element_fire.wav'),
  elementWater('assets/audio/sounds/sfx_element_water.wav'),
  elementAir('assets/audio/sounds/sfx_element_air.wav'),
  elementEarth('assets/audio/sounds/sfx_element_earth.wav'),
  elementLightning('assets/audio/sounds/sfx_element_lightning.wav'),
  elementSteam('assets/audio/sounds/sfx_element_steam.wav'),
  elementLava('assets/audio/sounds/sfx_element_lava.wav'),
  elementPoison('assets/audio/sounds/sfx_element_poison.wav'),
  elementIce('assets/audio/sounds/sfx_element_ice.wav'),
  elementMud('assets/audio/sounds/sfx_element_mud.wav'),
  elementDust('assets/audio/sounds/sfx_element_dust.wav'),
  elementCrystal('assets/audio/sounds/sfx_element_crystal.wav'),
  elementPlant('assets/audio/sounds/sfx_element_plant.wav'),
  elementSpirit('assets/audio/sounds/sfx_element_spirit.wav'),
  elementDark('assets/audio/sounds/sfx_element_dark.wav'),
  elementLight('assets/audio/sounds/sfx_element_light.wav'),
  elementBlood('assets/audio/sounds/sfx_element_blood.wav');

  const SoundCue(this.asset);
  final String asset;
  static SoundCue? forElement(String element) {
    final key = 'element${element.toLowerCase()}';
    return values.where((cue) => cue.name.toLowerCase() == key).firstOrNull;
  }

  /// The auto-attack cue for a creature's family, or null for a family with
  /// no authored basic (which falls back to the generic launch).
  static SoundCue? forFamilyBasic(String family) {
    final key = 'basic${family.toLowerCase()}';
    return values.where((cue) => cue.name.toLowerCase() == key).firstOrNull;
  }

  /// A creature casting its special: its family's own gesture, scored to
  /// the special as drawn (`tool/sounds/family_<name>.py`), played under the
  /// element accent. Null for Wing, whose beam sounds where the beam starts
  /// -- the only place its length is known (see [forWingBeam]).
  ///
  /// A [garrison] creature rams at once, with no wind-up, lap or brew, so a
  /// garrisoned Horn never takes the gesture of one.
  static SoundCue? forFamilySpecial(
    String family,
    String element, {
    bool garrison = false,
  }) => switch (family.toLowerCase()) {
    'wing' => null,
    'let' => element == 'Earth' ? specialLetEarth : specialLet,
    'pip' => switch (element) {
      'Blood' || 'Spirit' || 'Poison' || 'Plant' => specialPipSeeker,
      'Lava' || 'Earth' || 'Mud' => specialPipHeavy,
      _ => specialPip,
    },
    'mane' => switch (element) {
      'Fire' => specialManeVolley,
      'Lightning' => specialManeScatter,
      'Air' => specialManeGale,
      'Spirit' => specialManeStream,
      'Light' => specialManeWard,
      _ => specialMane,
    },
    'mask' => switch (element) {
      'Light' || 'Dark' || 'Lightning' || 'Blood' || 'Ice' => specialMaskSingle,
      'Plant' => specialMaskFeed,
      'Dust' => specialMaskWrap,
      _ => specialMask,
    },
    'horn' => switch (element) {
      'Lava' || 'Earth' => specialHornHeavy,
      'Light' => specialHornBarrier,
      _ when garrison => specialHorn,
      'Water' => specialHornCircle,
      'Crystal' => specialHornGather,
      'Spirit' => specialHornBrace,
      'Dark' => specialHornVoid,
      _ => specialHorn,
    },
    'kin' => switch (element) {
      'Light' || 'Crystal' => specialKinEscort,
      'Water' => specialKinRain,
      'Air' => specialKinUpdraft,
      'Plant' => specialKinGarden,
      'Earth' => specialKinWall,
      'Dust' => specialKinBank,
      'Poison' => specialKinDarts,
      'Ice' => specialKinCharge,
      'Lightning' => specialKinChannel,
      'Lava' => specialKinPlate,
      'Steam' => specialKinBoiler,
      'Mud' => specialKinSling,
      'Dark' => specialKinVeil,
      'Blood' => specialKinPact,
      'Spirit' => specialKinWisp,
      _ => specialKin,
    },
    'mystic' =>
      element == 'Plant' || element == 'Dark' ? specialMysticRise : specialMystic,
    _ => combatSpecialCast,
  };

  /// A Wing beam starting, by its element and how long it will hold
  /// (duration plus any banked Tracer time): three lengths of held beam or
  /// ring, rendered separately so the hold runs naturally, and Lightning's
  /// fixed 3 s charge-and-blast.
  static SoundCue forWingBeam(String element, double holdSeconds) {
    if (element == 'Lightning') return specialWingCharge;
    final ring = element == 'Fire' || element == 'Poison';
    if (holdSeconds < 2.4) return ring ? specialWingRing : specialWing;
    if (holdSeconds < 3.05) return ring ? specialWingRingLong : specialWingLong;
    return ring ? specialWingRingLongest : specialWingLongest;
  }

  /// Kin poured into a specimen on the Enhance screen, by how many.
  static SoundCue forKinPour(int kin) => switch (kin) {
    <= 1 => enhancePour1,
    2 => enhancePour2,
    3 => enhancePour3,
    4 => enhancePour4,
    5 => enhancePour5,
    _ => enhancePour6,
  };

  /// A potential soul's rite, by its roll (1-5).
  static SoundCue forSoulRoll(int roll) => switch (roll) {
    <= 1 => enhanceSoul1,
    2 => enhanceSoul2,
    3 => enhanceSoul3,
    4 => enhanceSoul4,
    _ => enhanceSoul5,
  };

  /// A Let skyfall touching down. [barrageChild] is one of Dark's kill
  /// bombardment (its projectiles carry effectStacks >= 1).
  static SoundCue forLetImpact(String element, {bool barrageChild = false}) {
    if (element == 'Dark' && barrageChild) return specialLetImpactBarrage;
    return switch (element) {
      'Earth' => specialLetImpactEarth,
      'Air' || 'Spirit' || 'Light' => specialLetImpactAiry,
      _ => specialLetImpact,
    };
  }

  /// A Horn ram landing; null for the elements that do not ram.
  static SoundCue? forHornSlam(String element) => switch (element) {
    'Earth' || 'Lava' => specialHornSlamHeavy,
    'Light' || 'Air' || 'Mud' => null,
    _ => specialHornSlam,
  };

  /// A Mask trap springing; null for the elements whose contact is ongoing
  /// rather than an event (their damage already sounds).
  static SoundCue? forMaskSpring(String element) => switch (element) {
    'Light' => specialMaskSpringLight,
    'Crystal' => specialMaskSpringCrystal,
    'Fire' => specialMaskSpringFire,
    'Water' => specialMaskSpringWater,
    'Dark' => specialMaskSpringDark,
    _ => null,
  };

  /// The eight per-family auto-attacks, as a set — the mixer treats them as
  /// one class for priority and throttling.
  bool get isFamilyBasic => const {
    SoundCue.basicMane,
    SoundCue.basicLet,
    SoundCue.basicPip,
    SoundCue.basicHorn,
    SoundCue.basicMask,
    SoundCue.basicWing,
    SoundCue.basicKin,
    SoundCue.basicMystic,
    // Two basics that are not the family's plain shot: Kin's charge building
    // before its beam, and a Let mastery's falling rock.
    SoundCue.basicKinCharge,
    SoundCue.basicLetDeadfall,
  }.contains(this);

  bool get hasVariants =>
      const {
        SoundCue.combatProjectile,
        SoundCue.shipBolt,
        SoundCue.combatHitLight,
        SoundCue.combatHitHeavy,
        SoundCue.combatEnemyDefeat,
        // A besieged orb's bubble is struck every 200 ms; one take would
        // machine-gun.
        SoundCue.combatShieldHit,
        SoundCue.cosmicOrbPickup,
        SoundCue.cosmicMatterCollect,
        SoundCue.dungeonStepStone,
        SoundCue.dungeonStepWater,
        SoundCue.enhanceOrb,
        SoundCue.specialHorn,
        SoundCue.specialHornHeavy,
        SoundCue.specialHornSlam,
        SoundCue.specialHornSlamHeavy,
        SoundCue.specialLetImpact,
        SoundCue.specialLetImpactEarth,
        SoundCue.specialLetImpactAiry,
        SoundCue.specialLetImpactBarrage,
        SoundCue.specialLetImpactMinor,
        SoundCue.specialMane,
        SoundCue.specialManeGale,
        SoundCue.specialManeVolley,
        SoundCue.specialManeScatter,
        SoundCue.specialManeStream,
        SoundCue.specialManeWard,
        SoundCue.specialManeOrbLand,
        SoundCue.specialManeBurst,
        SoundCue.specialManeQuake,
        SoundCue.specialMaskSpringLight,
        SoundCue.specialMaskSpringCrystal,
        SoundCue.specialMaskSpringFire,
        SoundCue.specialMaskSpringWater,
        SoundCue.specialMaskSpringDark,
        SoundCue.specialMysticStrike,
        SoundCue.specialMysticQuake,
        SoundCue.specialMysticVent,
        SoundCue.specialMysticRain,
        SoundCue.specialMysticMeteor,
        SoundCue.specialPipRicochet,
        SoundCue.specialPipVoid,
        SoundCue.specialWing,
        SoundCue.specialWingLong,
        SoundCue.specialWingLongest,
      }.contains(this) ||
      isFamilyBasic ||
      isElement;

  /// The seventeen element accents (elementFire … elementBlood). A
  /// companion's special fires one every few seconds for a whole wave, so
  /// each has three re-rendered takes (tool/sounds/elements.py).
  bool get isElement => name.startsWith('element');
  String assetForVariant(int index) => hasVariants && index % 4 != 0
      ? asset.replaceFirst('.wav', '_0${index % 4}.wav')
      : asset;

  /// Higher wins a voice when all six are busy.
  ///
  /// The mixer evicts a voice whose priority is strictly LOWER than the
  /// incoming cue's, so a 0 can never take a slot from anything — it is
  /// droppable, not merely cheap. A cue that should still be heard in a busy
  /// scene belongs at 1 even when it is quiet and frequent.
  int get priority => switch (this) {
    SoundCue.combatPlayerHurt ||
    SoundCue.combatDanger ||
    SoundCue.combatDefeat ||
    SoundCue.combatVictory ||
    SoundCue.survivalBossArrive ||
    SoundCue.extractionCeremony ||
    SoundCue.fusionMerge ||
    SoundCue.fusionEruption ||
    SoundCue.fusionCalibrate ||
    SoundCue.fusionPour ||
    SoundCue.fusionRecoil ||
    SoundCue.captureAttempt ||
    SoundCue.captureSuccess ||
    SoundCue.captureEscape ||
    SoundCue.altarRite ||
    SoundCue.altarAwake ||
    SoundCue.extractionCreatureReveal ||
    SoundCue.extractionRareReveal ||
    // A Mystic opens its world once per deployment.
    SoundCue.specialMystic ||
    SoundCue.specialMysticRise => 2,
    SoundCue.combatProjectile ||
    SoundCue.shipBolt ||
    SoundCue.combatHitLight ||
    SoundCue.combatHitHeavy ||
    SoundCue.combatEnemyDefeat ||
    SoundCue.cosmicOrbPickup ||
    SoundCue.dungeonStepStone ||
    SoundCue.dungeonStepWater ||
    // Contacts the damage hit already sounds: texture, droppable.
    SoundCue.specialPipRicochet ||
    SoundCue.specialMaskSpringCrystal ||
    SoundCue.specialMaskSpringFire ||
    SoundCue.specialMaskSpringDark ||
    SoundCue.specialMaskSpringWater => 0,
    // THE SHOT IS DROPPABLE, THE HIT IS NOT. Auto-attacks are the most
    // repeated sound in the game; when the mix runs out of voices these are
    // the first to go, so a crowded fight thins itself down to its impacts
    // rather than to a wall of launches.
    _ when isFamilyBasic => 0,
    _ => 1,
  };
  int get cooldownMs => switch (this) {
    SoundCue.combatPlayerHurt => 650,
    SoundCue.combatDanger => 900,
    SoundCue.combatHeal => 1000,
    SoundCue.combatShieldHit => 200,
    SoundCue.combatProjectile => 160,
    // The machine gun fires every 120 ms: every other shot is heard.
    SoundCue.shipBolt => 110,
    SoundCue.combatHitLight ||
    SoundCue.combatHitHeavy ||
    SoundCue.combatEnemyDefeat => 100,
    SoundCue.cosmicOrbPickup => 90,
    // Matter arrives in streams, not singly — a full meter is a couple of
    // hundred motes. Long enough apart to read as separate pickups, short
    // enough that flying through a field still sounds continuous.
    SoundCue.cosmicMatterCollect => 80,
    SoundCue.dungeonStepStone || SoundCue.dungeonStepWater => 220,
    SoundCue.uiTap || SoundCue.uiSelect => 70,
    // Per-cue, so two different families firing together are still two
    // sounds — it is one family machine-gunning that gets thinned.
    _ when isFamilyBasic => 110,
    SoundCue.combatSpecialCast => 180,
    SoundCue.specialPip ||
    SoundCue.specialPipSeeker ||
    SoundCue.specialPipHeavy => 180,
    SoundCue.specialPipRicochet => 140,
    SoundCue.specialPipVoid => 800,
    // A trap field in a horde would ask for 15-20 springs a second.
    SoundCue.specialMaskSpringLight => 100,
    SoundCue.specialMaskSpringCrystal || SoundCue.specialMaskSpringFire => 140,
    SoundCue.specialMaskSpringWater => 300,
    // 5-10 Lightning orbs land over about a second.
    SoundCue.specialManeOrbLand => 90,
    SoundCue.specialLet || SoundCue.specialLetEarth => 150,
    // A Dark barrage lands every 83 ms; anything longer drops landings.
    SoundCue.specialLetImpact ||
    SoundCue.specialLetImpactEarth ||
    SoundCue.specialLetImpactAiry ||
    SoundCue.specialLetImpactBarrage => 60,
    SoundCue.specialLetImpactMinor => 110,
    _ => 250,
  };
  double get gain => switch (this) {
    SoundCue.combatProjectile => .40,
    // Held down for whole fights: under the hits it causes.
    SoundCue.shipBolt => .55,
    SoundCue.combatHitLight || SoundCue.combatEnemyDefeat => .55,
    SoundCue.dungeonStepStone || SoundCue.dungeonStepWater => .35,
    SoundCue.cosmicOrbPickup => .60,
    // Well under the star-dust plink: this fires many times more often, and
    // its job is to sit under the music rather than on top of it.
    SoundCue.cosmicMatterCollect => .30,
    SoundCue.uiTap || SoundCue.uiSelect || SoundCue.uiBack => .65,
    // Under combatHitLight (.55) on purpose: the hit a shot causes should be
    // louder than the shot (the brief's own rule for frequent launches).
    _ when isFamilyBasic => .34,
    // It layers beneath the caster's element cue, which plays at full gain
    // and is the part that carries any colour.
    SoundCue.combatSpecialCast => .55,
    // Family casts sit under the element accent, which carries the colour.
    SoundCue.specialPip ||
    SoundCue.specialPipSeeker ||
    SoundCue.specialPipHeavy ||
    SoundCue.specialMask ||
    SoundCue.specialMaskSingle ||
    SoundCue.specialMaskFeed ||
    SoundCue.specialMaskWrap => .6,
    SoundCue.specialMane ||
    SoundCue.specialManeGale ||
    SoundCue.specialManeVolley ||
    SoundCue.specialManeScatter ||
    SoundCue.specialManeStream ||
    SoundCue.specialManeWard => .85,
    SoundCue.specialHorn ||
    SoundCue.specialHornHeavy ||
    SoundCue.specialHornCircle ||
    SoundCue.specialHornGather ||
    SoundCue.specialHornBrace ||
    SoundCue.specialHornVoid ||
    SoundCue.specialHornBrew ||
    SoundCue.specialWing ||
    SoundCue.specialWingLong ||
    SoundCue.specialWingLongest ||
    SoundCue.specialWingRing ||
    SoundCue.specialWingRingLong ||
    SoundCue.specialWingRingLongest ||
    SoundCue.specialWingCharge => .8,
    _ when name.startsWith('specialKin') => .8,
    SoundCue.specialPipRicochet => .45,
    SoundCue.specialPipVoid || SoundCue.specialMaskSpringLight => .7,
    SoundCue.specialMaskSpringCrystal ||
    SoundCue.specialMaskSpringFire ||
    SoundCue.specialMaskSpringDark ||
    SoundCue.specialMaskSpringWater => .5,
    SoundCue.specialManeOrbLand => .7,
    SoundCue.specialManeQuake => .6,
    _ => 1.0,
  };
}
