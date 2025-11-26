// lib/games/survival/survival_debug_teams.dart
import 'package:alchemons/games/survival/survival_engine.dart';

PartyCombatantStats _makeCreature({
  required String id,
  required String name,
  required List<String> types,
  required String family,
  required int level,
  required double speed,
  required double intelligence,
  required double strength,
  required double beauty,
}) {
  return PartyCombatantStats(
    id: id,
    name: name,
    types: types,
    family: family,
    level: level,
    statSpeed: speed,
    statIntelligence: intelligence,
    statStrength: strength,
    statBeauty: beauty,
  );
}

/// Central place for prebuilt test parties.
class DebugTeams {
  // ---------------------------------------------------------------------------
  // NEW TEAMS (Weak, Average, Strong)
  // ---------------------------------------------------------------------------

  /// Weak Team: All stats between 1.5 - 2.5
  static List<PartyMember> makeWeakTeam() {
    return [
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_earth_pip',
          name: 'Earth Pip',
          types: ['Earth'],
          family: 'Pip',
          level: 5,
          speed: 1.5,
          intelligence: 1.6,
          strength: 2.5,
          beauty: 1.5,
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_water_let',
          name: 'Water Let',
          types: ['Water'],
          family: 'Let',
          level: 5,
          speed: 2.0,
          intelligence: 1.8,
          strength: 2.0,
          beauty: 1.8,
        ),
        position: FormationPosition.frontRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_air_wing',
          name: 'Air Wing',
          types: ['Air'],
          family: 'Wing',
          level: 5,
          speed: 2.5,
          intelligence: 1.9,
          strength: 1.6,
          beauty: 2.0,
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_fire_mane',
          name: 'Fire Mane',
          types: ['Fire'],
          family: 'Mane',
          level: 5,
          speed: 2.1,
          intelligence: 1.7,
          strength: 2.4,
          beauty: 1.9,
        ),
        position: FormationPosition.backRight,
      ),
      // Bench
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_plant_horn',
          name: 'Plant Horn',
          types: ['Plant'],
          family: 'Horn',
          level: 5,
          speed: 1.6,
          intelligence: 1.5,
          strength: 2.3,
          beauty: 1.6,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_ice_mask',
          name: 'Ice Mask',
          types: ['Ice'],
          family: 'Mask',
          level: 5,
          speed: 1.8,
          intelligence: 2.2,
          strength: 1.7,
          beauty: 2.0,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_light_kin',
          name: 'Light Kin',
          types: ['Light'],
          family: 'Kin',
          level: 5,
          speed: 2.2,
          intelligence: 2.0,
          strength: 1.5,
          beauty: 2.5,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_poison_wing',
          name: 'Poison Wing',
          types: ['Poison'],
          family: 'Wing',
          level: 5,
          speed: 1.9,
          intelligence: 2.4,
          strength: 1.5,
          beauty: 1.7,
        ),
        position: FormationPosition.backRight,
      ),
    ];
  }

  /// Average Team: All stats between 2.5 - 3.5
  static List<PartyMember> makeAverageTeam() {
    return [
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_crystal_horn',
          name: 'Crystal Horn',
          types: ['Crystal'],
          family: 'Horn',
          level: 10,
          speed: 2.5,
          intelligence: 2.8,
          strength: 3.5,
          beauty: 3.0,
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_lava_let',
          name: 'Lava Let',
          types: ['Lava'],
          family: 'Let',
          level: 10,
          speed: 3.0,
          intelligence: 2.9,
          strength: 3.4,
          beauty: 2.7,
        ),
        position: FormationPosition.frontRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_lightning_wing',
          name: 'Lightning Wing',
          types: ['Lightning'],
          family: 'Wing',
          level: 10,
          speed: 3.5,
          intelligence: 3.1,
          strength: 2.8,
          beauty: 3.2,
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_steam_pip',
          name: 'Steam Pip',
          types: ['Steam'],
          family: 'Pip',
          level: 10,
          speed: 3.2,
          intelligence: 3.3,
          strength: 2.6,
          beauty: 3.4,
        ),
        position: FormationPosition.backRight,
      ),
      // Bench
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_mud_mane',
          name: 'Mud Mane',
          types: ['Mud'],
          family: 'Mane',
          level: 10,
          speed: 2.7,
          intelligence: 3.0,
          strength: 3.3,
          beauty: 2.8,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_spirit_Let',
          name: 'Spirit Let',
          types: ['Spirit'],
          family: 'Let',
          level: 10,
          speed: 2.9,
          intelligence: 3.5,
          strength: 2.5,
          beauty: 3.1,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_dark_mask',
          name: 'Dark Mask',
          types: ['Dark'],
          family: 'Mask',
          level: 10,
          speed: 3.1,
          intelligence: 3.2,
          strength: 2.9,
          beauty: 2.6,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_ice_kin',
          name: 'Ice Kin',
          types: ['Ice'],
          family: 'Kin',
          level: 10,
          speed: 3.3,
          intelligence: 3.0,
          strength: 2.7,
          beauty: 3.5,
        ),
        position: FormationPosition.backRight,
      ),
    ];
  }

  /// Strong Team: All stats 3.0 - 4.5 (some 2s allowed for specialized builds)
  static List<PartyMember> makeStrongTeam() {
    return [
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_iron_horn',
          name: 'Earth Horn',
          types: ['Earth'],
          family: 'Horn',
          level: 15,
          speed: 2.2, // Low speed
          intelligence: 3.0,
          strength: 4.5, // High strength
          beauty: 2.5,
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_dragon_wing',
          name: 'Fire Wing',
          types: ['Fire'],
          family: 'Wing',
          level: 15,
          speed: 4.5,
          intelligence: 3.8,
          strength: 4.2,
          beauty: 4.0,
        ),
        position: FormationPosition.frontRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_void_Wing',
          name: 'Dark Wing',
          types: ['Dark'],
          family: 'Wing',
          level: 15,
          speed: 3.2,
          intelligence: 4.5,
          strength: 2.8,
          beauty: 3.5,
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_radiant_kin',
          name: 'Light Kin',
          types: ['Light'],
          family: 'Kin',
          level: 15,
          speed: 4.0,
          intelligence: 4.2,
          strength: 3.0,
          beauty: 4.5,
        ),
        position: FormationPosition.backRight,
      ),
      // Bench
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_magma_let',
          name: 'Lava Let',
          types: ['Lava'],
          family: 'Let',
          level: 15,
          speed: 3.8,
          intelligence: 3.5,
          strength: 4.4,
          beauty: 3.2,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_toxin_mane',
          name: 'Poison Mane',
          types: ['Poison'],
          family: 'Mane',
          level: 15,
          speed: 3.5,
          intelligence: 3.9,
          strength: 4.0,
          beauty: 3.1,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_storm_pip',
          name: 'Lightning Pip',
          types: ['Lightning'],
          family: 'Pip',
          level: 15,
          speed: 4.3,
          intelligence: 3.6,
          strength: 3.2,
          beauty: 3.8,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_dust_mask',
          name: 'Dust Mask',
          types: ['Dust'],
          family: 'Mask',
          level: 15,
          speed: 3.4,
          intelligence: 4.1,
          strength: 3.5,
          beauty: 2.9,
        ),
        position: FormationPosition.backRight,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // EXISTING TEST TEAMS (Names corrected)
  // ---------------------------------------------------------------------------

  static List<PartyMember> makeTestTeamA() {
    return [
      // front
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_fl_blaze_let',
          name: 'Fire Let',
          types: ['Fire'],
          family: 'Let',
          level: 10,
          speed: 3.2,
          intelligence: 3.8,
          strength: 4.6,
          beauty: 3.0,
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_fr_iron_horn',
          name: 'Earth Horn',
          types: ['Earth'],
          family: 'Horn',
          level: 10,
          speed: 2.6,
          intelligence: 2.8,
          strength: 5.0,
          beauty: 2.6,
        ),
        position: FormationPosition.frontRight,
      ),

      // back
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_bl_storm_wing',
          name: 'Lightning Wing',
          types: ['Lightning'],
          family: 'Wing',
          level: 10,
          speed: 4.5,
          intelligence: 3.6,
          strength: 3.8,
          beauty: 3.4,
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_br_tidal_pip',
          name: 'Water Pip',
          types: ['Water'],
          family: 'Pip',
          level: 10,
          speed: 4.0,
          intelligence: 4.2,
          strength: 3.2,
          beauty: 3.5,
        ),
        position: FormationPosition.backRight,
      ),

      // bench
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_b1_venom_mane',
          name: 'Poison Mane',
          types: ['Poison'],
          family: 'Mane',
          level: 10,
          speed: 3.4,
          intelligence: 3.8,
          strength: 4.0,
          beauty: 3.8,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_b2_aurora_kin',
          name: 'Light Kin',
          types: ['Light'],
          family: 'Kin',
          level: 10,
          speed: 3.9,
          intelligence: 4.5,
          strength: 3.0,
          beauty: 4.8,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_b3_wisp_Wing',
          name: 'Spirit Wing',
          types: ['Spirit'],
          family: 'Wing',
          level: 10,
          speed: 3.1,
          intelligence: 4.6,
          strength: 2.8,
          beauty: 4.0,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_b4_frost_mask',
          name: 'Ice Mask',
          types: ['Ice'],
          family: 'Mask',
          level: 10,
          speed: 3.0,
          intelligence: 4.0,
          strength: 3.0,
          beauty: 3.2,
        ),
        position: FormationPosition.backRight,
      ),
    ];
  }

  static List<PartyMember> makeTestTeamB() {
    return [
      PartyMember(
        combatant: _makeCreature(
          id: 'testB_fl_gale_wing',
          name: 'Air Wing',
          types: ['Air'],
          family: 'Wing',
          level: 10,
          speed: 5.0,
          intelligence: 3.4,
          strength: 4.0,
          beauty: 3.4,
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testB_fr_blood_let',
          name: 'Blood Let',
          types: ['Blood'],
          family: 'Let',
          level: 10,
          speed: 3.8,
          intelligence: 3.2,
          strength: 4.8,
          beauty: 3.0,
        ),
        position: FormationPosition.frontRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testB_bl_spark_pip',
          name: 'Lightning Pip',
          types: ['Lightning'],
          family: 'Pip',
          level: 10,
          speed: 4.6,
          intelligence: 4.1,
          strength: 3.4,
          beauty: 3.7,
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testB_br_shade_Wing',
          name: 'Dark Wing',
          types: ['Dark'],
          family: 'Wing',
          level: 10,
          speed: 3.5,
          intelligence: 4.7,
          strength: 3.0,
          beauty: 4.1,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testB_b1_flare_mane',
          name: 'Lava Mane',
          types: ['Lava'],
          family: 'Mane',
          level: 10,
          speed: 3.7,
          intelligence: 3.6,
          strength: 4.4,
          beauty: 3.5,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testB_b2_blossom_mane',
          name: 'Plant Mane',
          types: ['Plant'],
          family: 'Mane',
          level: 10,
          speed: 3.3,
          intelligence: 4.3,
          strength: 3.6,
          beauty: 4.2,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testB_b3_glimmer_kin',
          name: 'Light Kin',
          types: ['Light'],
          family: 'Kin',
          level: 10,
          speed: 3.9,
          intelligence: 4.4,
          strength: 3.2,
          beauty: 4.6,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testB_b4_mist_mask',
          name: 'Steam Mask',
          types: ['Steam'],
          family: 'Mask',
          level: 10,
          speed: 3.2,
          intelligence: 4.1,
          strength: 3.1,
          beauty: 3.4,
        ),
        position: FormationPosition.backRight,
      ),
    ];
  }

  static List<PartyMember> makeTestTeamC() {
    return [
      PartyMember(
        combatant: _makeCreature(
          id: 'testC_fl_boulder_horn',
          name: 'Mud Horn',
          types: ['Mud'],
          family: 'Horn',
          level: 10,
          speed: 2.2,
          intelligence: 2.6,
          strength: 5.0,
          beauty: 2.4,
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testC_fr_crystal_horn',
          name: 'Crystal Horn',
          types: ['Crystal'],
          family: 'Horn',
          level: 10,
          speed: 2.6,
          intelligence: 3.0,
          strength: 4.8,
          beauty: 3.2,
        ),
        position: FormationPosition.frontRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testC_bl_thorn_mane',
          name: 'Poison Mane',
          types: ['Poison'],
          family: 'Mane',
          level: 10,
          speed: 3.1,
          intelligence: 4.0,
          strength: 3.8,
          beauty: 3.7,
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testC_br_briar_mane',
          name: 'Plant Mane',
          types: ['Plant'],
          family: 'Mane',
          level: 10,
          speed: 3.0,
          intelligence: 4.2,
          strength: 3.6,
          beauty: 3.9,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testC_b1_frost_wing',
          name: 'Ice Wing',
          types: ['Ice'],
          family: 'Wing',
          level: 10,
          speed: 4.0,
          intelligence: 3.8,
          strength: 4.0,
          beauty: 3.5,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testC_b2_ember_let',
          name: 'Fire Let',
          types: ['Fire'],
          family: 'Let',
          level: 10,
          speed: 3.4,
          intelligence: 3.9,
          strength: 4.5,
          beauty: 3.2,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testC_b3_torrent_pip',
          name: 'Water Pip',
          types: ['Water'],
          family: 'Pip',
          level: 10,
          speed: 4.1,
          intelligence: 4.1,
          strength: 3.3,
          beauty: 3.6,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testC_b4_echo_Mane',
          name: 'Spirit Mane',
          types: ['Spirit'],
          family: 'Mane',
          level: 10,
          speed: 3.3,
          intelligence: 4.6,
          strength: 3.0,
          beauty: 4.1,
        ),
        position: FormationPosition.backRight,
      ),
    ];
  }

  static List<PartyMember> makeTestTeamD() {
    return [
      PartyMember(
        combatant: _makeCreature(
          id: 'testD_fl_mask_sand',
          name: 'Dust Mask',
          types: ['Dust'],
          family: 'Mask',
          level: 10,
          speed: 3.1,
          intelligence: 4.0,
          strength: 3.2,
          beauty: 3.1,
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testD_fr_mask_mist',
          name: 'Steam Mask',
          types: ['Steam'],
          family: 'Mask',
          level: 10,
          speed: 3.3,
          intelligence: 4.2,
          strength: 3.1,
          beauty: 3.4,
        ),
        position: FormationPosition.frontRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testD_bl_kin_radiant',
          name: 'Light Kin',
          types: ['Light'],
          family: 'Kin',
          level: 10,
          speed: 3.8,
          intelligence: 4.5,
          strength: 3.0,
          beauty: 4.8,
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testD_br_Mane_void',
          name: 'Dark Mane',
          types: ['Dark'],
          family: 'Mane',
          level: 10,
          speed: 3.4,
          intelligence: 4.7,
          strength: 2.9,
          beauty: 4.0,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testD_b1_tempest_wing',
          name: 'Air Wing',
          types: ['Air'],
          family: 'Wing',
          level: 10,
          speed: 4.7,
          intelligence: 3.6,
          strength: 4.1,
          beauty: 3.5,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testD_b2_rubble_horn',
          name: 'Earth Horn',
          types: ['Earth'],
          family: 'Horn',
          level: 10,
          speed: 2.5,
          intelligence: 2.8,
          strength: 4.9,
          beauty: 2.5,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testD_b3_marsh_mane',
          name: 'Mud Mane',
          types: ['Mud'],
          family: 'Mane',
          level: 10,
          speed: 3.0,
          intelligence: 4.0,
          strength: 3.7,
          beauty: 3.6,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testD_b4_blood_let',
          name: 'Blood Let',
          types: ['Blood'],
          family: 'Let',
          level: 10,
          speed: 3.6,
          intelligence: 3.5,
          strength: 4.6,
          beauty: 3.1,
        ),
        position: FormationPosition.backRight,
      ),
    ];
  }

  static List<PartyMember> makeTestTeamE() {
    return [
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_fl_volcanic_let',
          name: 'Lava Let',
          types: ['Lava'],
          family: 'Let',
          level: 10,
          speed: 3.3,
          intelligence: 3.9,
          strength: 4.7,
          beauty: 3.0,
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_fr_frozen_horn',
          name: 'Ice Horn',
          types: ['Ice'],
          family: 'Horn',
          level: 10,
          speed: 2.7,
          intelligence: 3.3,
          strength: 4.8,
          beauty: 3.2,
        ),
        position: FormationPosition.frontRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_bl_cinder_wing',
          name: 'Fire Wing',
          types: ['Fire'],
          family: 'Wing',
          level: 10,
          speed: 4.4,
          intelligence: 3.7,
          strength: 4.2,
          beauty: 3.6,
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_br_rain_pip',
          name: 'Water Pip',
          types: ['Water'],
          family: 'Pip',
          level: 10,
          speed: 4.2,
          intelligence: 4.2,
          strength: 3.3,
          beauty: 3.8,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_b1_sand_mask',
          name: 'Dust Mask',
          types: ['Dust'],
          family: 'Mask',
          level: 10,
          speed: 3.2,
          intelligence: 4.0,
          strength: 3.1,
          beauty: 3.4,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_b2_grove_mane',
          name: 'Plant Mane',
          types: ['Plant'],
          family: 'Mane',
          level: 10,
          speed: 3.3,
          intelligence: 4.1,
          strength: 3.8,
          beauty: 4.0,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_b3_lumen_kin',
          name: 'Light Kin',
          types: ['Light'],
          family: 'Kin',
          level: 10,
          speed: 3.9,
          intelligence: 4.5,
          strength: 3.1,
          beauty: 4.7,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_b4_umbra_Mane',
          name: 'Dark Mane',
          types: ['Dark'],
          family: 'Mane',
          level: 10,
          speed: 3.5,
          intelligence: 4.7,
          strength: 2.9,
          beauty: 4.2,
        ),
        position: FormationPosition.backRight,
      ),
    ];
  }

  /// Convenience to enumerate all debug parties with labels.
  static List<_DebugTeamInfo> allTeams() => [
    _DebugTeamInfo(
      id: 'weak',
      label: 'Weak Team (1.5-2.5)',
      party: makeWeakTeam(),
    ),
    _DebugTeamInfo(
      id: 'avg',
      label: 'Average Team (2.5-3.5)',
      party: makeAverageTeam(),
    ),
    _DebugTeamInfo(
      id: 'strong',
      label: 'Strong Team (3.0-4.5)',
      party: makeStrongTeam(),
    ),
    _DebugTeamInfo(id: 'A', label: 'Team A – Balanced', party: makeTestTeamA()),
    _DebugTeamInfo(id: 'B', label: 'Team B – Speed', party: makeTestTeamB()),
    _DebugTeamInfo(id: 'C', label: 'Team C – Tank/DoT', party: makeTestTeamC()),
    _DebugTeamInfo(id: 'D', label: 'Team D – Control', party: makeTestTeamD()),
    _DebugTeamInfo(id: 'E', label: 'Team E – Chaos', party: makeTestTeamE()),
  ];
}

class _DebugTeamInfo {
  final String id;
  final String label;
  final List<PartyMember> party;

  const _DebugTeamInfo({
    required this.id,
    required this.label,
    required this.party,
  });
}
