// lib/games/survival/survival_debug_teams.dart
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flame/components.dart'; // REQUIRED for Vector2
import 'package:flutter/material.dart'; // For Color

// Helper function to construct the dynamic sprite sheet path
SpriteSheetDef _getSpriteSheetDef(
  String type,
  String family, {
  required String idPrefix,
  required String category,
  int frames = 4,
  Vector2? frameSize,
}) {
  // Example ID generation: 'weak_earth_pip' -> 'earth_pip'
  // ID format: [TYPE]_[FAMILY]
  // The filename pattern seems to be [FAMILY][ID]_[TYPE][FAMILY]_spritesheet.png
  // Since we don't have the internal ID number, we'll simplify the path naming
  // to match the pattern seen in the file system (e.g., LET13_poisonlet_spritesheet.png)

  // To keep the example working without actual creature data:
  // We'll use a generic placeholder ID for the file name based on the creature name.
  // E.g., Earth Pip -> EARTHPIP
  final baseName = idPrefix.toUpperCase().replaceAll('_', '');

  // Construct the path
  final path =
      'creatures/$category/${baseName.toUpperCase()}_${type.toLowerCase()}${family.toLowerCase()}_spritesheet.png';

  // Return the SpriteSheetDef with requested defaults
  return SpriteSheetDef(
    path: path,
    totalFrames: frames,
    rows: 1,
    frameSize: frameSize ?? Vector2(512, 512),
    stepTime: 0.15,
  );
}

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
  // **ADD NEW FIELDS**
  SpriteSheetDef? sheetDef,
  required SpriteVisuals? visuals,
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
    // **PASS NEW FIELDS TO CONSTRUCTOR**
    sheetDef: sheetDef,
    spriteVisuals: visuals,
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
          name: 'Earthpip',
          types: ['Earth'],
          family: 'Pip',
          level: 5,
          speed: 1.5,
          intelligence: 1.6,
          strength: 2.5,
          beauty: 1.5,
          sheetDef: _getSpriteSheetDef(
            'Earth',
            'Pip',
            idPrefix: 'PIP03',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_water_let',
          name: 'Waterlet',
          types: ['Water'],
          family: 'Let',
          level: 5,
          speed: 2.0,
          intelligence: 1.8,
          strength: 2.0,
          beauty: 1.8,
          sheetDef: _getSpriteSheetDef(
            'Water',
            'Let',
            idPrefix: 'LET02',
            category: 'common',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_air_wing',
          name: 'Airwing',
          types: ['Air'],
          family: 'Wing',
          level: 5,
          speed: 2.5,
          intelligence: 1.9,
          strength: 1.6,
          beauty: 2.0,
          sheetDef: _getSpriteSheetDef(
            frames: 6,
            'Air',
            'Wing',
            idPrefix: 'WNG04',
            category: 'legendary',
            frameSize: Vector2(250, 250),
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_fire_mane',
          name: 'Firemane',
          types: ['Fire'],
          family: 'Mane',
          level: 5,
          speed: 2.1,
          intelligence: 1.7,
          strength: 2.4,
          beauty: 1.9,
          sheetDef: _getSpriteSheetDef(
            'Fire',
            'Mane',
            idPrefix: 'MAN01',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      // Bench
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_plant_horn',
          name: 'Planthorn',
          types: ['Plant'],
          family: 'Horn',
          level: 5,
          speed: 1.6,
          intelligence: 1.5,
          strength: 2.3,
          beauty: 1.6,
          sheetDef: _getSpriteSheetDef(
            'Plant',
            'Horn',
            idPrefix: 'HOR12',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_ice_mask',
          name: 'Icemask',
          types: ['Ice'],
          family: 'Mask',
          level: 5,
          speed: 1.8,
          intelligence: 2.2,
          strength: 1.7,
          beauty: 2.0,
          sheetDef: _getSpriteSheetDef(
            'Ice',
            'Mask',
            idPrefix: 'MSK09',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_light_kin',
          name: 'Lightkin',
          types: ['Light'],
          family: 'Kin',
          level: 5,
          speed: 2.2,
          intelligence: 2.0,
          strength: 1.5,
          beauty: 2.5,
          sheetDef: _getSpriteSheetDef(
            'Light',
            'Kin',
            idPrefix: 'KIN16',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'weak_poison_wing',
          name: 'Poisonwing',
          types: ['Poison'],
          family: 'Wing',
          level: 5,
          speed: 1.9,
          intelligence: 2.4,
          strength: 1.5,
          beauty: 1.7,
          sheetDef: _getSpriteSheetDef(
            'Poison',
            'Wing',
            idPrefix: 'WNG13',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
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
          name: 'Crystalhorn',
          types: ['Crystal'],
          family: 'Horn',
          level: 10,
          speed: 2.5,
          intelligence: 2.8,
          strength: 3.5,
          beauty: 3.0,
          sheetDef: _getSpriteSheetDef(
            'Crystal',
            'Horn',
            idPrefix: 'HOR11',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_lava_let',
          name: 'Lavalet',
          types: ['Lava'],
          family: 'Let',
          level: 10,
          speed: 3.0,
          intelligence: 2.9,
          strength: 3.4,
          beauty: 2.7,
          sheetDef: _getSpriteSheetDef(
            'Lava',
            'Let',
            idPrefix: 'LET06',
            category: 'common',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_lightning_wing',
          name: 'Lightningwing',
          types: ['Lightning'],
          family: 'Wing',
          level: 10,
          speed: 3.5,
          intelligence: 3.1,
          strength: 2.8,
          beauty: 3.2,
          sheetDef: _getSpriteSheetDef(
            'Lightning',
            'Wing',
            idPrefix: 'WNG07',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_steam_pip',
          name: 'Steampip',
          types: ['Steam'],
          family: 'Pip',
          level: 10,
          speed: 3.2,
          intelligence: 3.3,
          strength: 2.6,
          beauty: 3.4,
          sheetDef: _getSpriteSheetDef(
            'Steam',
            'Pip',
            idPrefix: 'PIP05',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      // Bench
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_mud_mane',
          name: 'Mudmane',
          types: ['Mud'],
          family: 'Mane',
          level: 10,
          speed: 2.7,
          intelligence: 3.0,
          strength: 3.3,
          beauty: 2.8,
          sheetDef: _getSpriteSheetDef(
            'Mud',
            'Mane',
            idPrefix: 'MAN08',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_spirit_Let',
          name: 'Spiritlet',
          types: ['Spirit'],
          family: 'Let',
          level: 10,
          speed: 2.9,
          intelligence: 3.5,
          strength: 2.5,
          beauty: 3.1,
          sheetDef: _getSpriteSheetDef(
            'Spirit',
            'Let',
            idPrefix: 'LET14',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_dark_mask',
          name: 'Darkmask',
          types: ['Dark'],
          family: 'Mask',
          level: 10,
          speed: 3.1,
          intelligence: 3.2,
          strength: 2.9,
          beauty: 2.6,
          sheetDef: _getSpriteSheetDef(
            'Dark',
            'Mask',
            idPrefix: 'MSK15',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'avg_ice_kin',
          name: 'Icekin',
          types: ['Ice'],
          family: 'Kin',
          level: 10,
          speed: 3.3,
          intelligence: 3.0,
          strength: 2.7,
          beauty: 3.5,
          sheetDef: _getSpriteSheetDef(
            'Ice',
            'Kin',
            idPrefix: 'KIN09',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
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
          name: 'Earthhorn',
          types: ['Earth'],
          family: 'Horn',
          level: 10,
          speed: 2.2, // Low speed
          intelligence: 4.0,
          strength: 4.5, // High strength
          beauty: 4.5,
          sheetDef: _getSpriteSheetDef(
            'Earth',
            'Horn',
            idPrefix: 'HOR03',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_dragon_wing',
          name: 'Firewing',
          types: ['Fire'],
          family: 'Wing',
          level: 10,
          speed: 4.5,
          intelligence: 3.8,
          strength: 4.2,
          beauty: 4.0,
          sheetDef: _getSpriteSheetDef(
            'Fire',
            'Wing',
            idPrefix: 'WNG01',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_void_Wing',
          name: 'Darkwing',
          types: ['Dark'],
          family: 'Wing',
          level: 10,
          speed: 4.2,
          intelligence: 4.5,
          strength: 2.8,
          beauty: 4.8,
          sheetDef: _getSpriteSheetDef(
            'Dark',
            'Wing',
            idPrefix: 'WNG15',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_radiant_kin',
          name: 'Lightkin',
          types: ['Light'],
          family: 'Kin',
          level: 10,
          speed: 4.0,
          intelligence: 4.2,
          strength: 3.0,
          beauty: 4.5,
          sheetDef: _getSpriteSheetDef(
            'Light',
            'Kin',
            idPrefix: 'KIN16',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      // Bench
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_magma_let',
          name: 'Lavalet',
          types: ['Lava'],
          family: 'Let',
          level: 10,
          speed: 3.8,
          intelligence: 3.5,
          strength: 4.4,
          beauty: 4.2,
          sheetDef: _getSpriteSheetDef(
            'Lava',
            'Let',
            idPrefix: 'LET06',
            category: 'common',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_toxin_mane',
          name: 'Poisonmane',
          types: ['Poison'],
          family: 'Mane',
          level: 10,
          speed: 4.5,
          intelligence: 3.9,
          strength: 4.0,
          beauty: 4.1,
          sheetDef: _getSpriteSheetDef(
            'Poison',
            'Mane',
            idPrefix: 'MAN13',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_storm_pip',
          name: 'Lightningpip',
          types: ['Lightning'],
          family: 'Pip',
          level: 10,
          speed: 4.3,
          intelligence: 4.6,
          strength: 4.2,
          beauty: 3.8,
          sheetDef: _getSpriteSheetDef(
            'Lightning',
            'Pip',
            idPrefix: 'PIP07',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'strong_dust_mask',
          name: 'Dustmask',
          types: ['Dust'],
          family: 'Mask',
          level: 10,
          speed: 3.4,
          intelligence: 4.1,
          strength: 3.5,
          beauty: 4.9,
          sheetDef: _getSpriteSheetDef(
            'Dust',
            'Mask',
            idPrefix: 'MSK10',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
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
          name: 'Firelet',
          types: ['Fire'],
          family: 'Let',
          level: 10,
          speed: 3.2,
          intelligence: 3.8,
          strength: 4.6,
          beauty: 3.0,
          sheetDef: _getSpriteSheetDef(
            'Fire',
            'Let',
            idPrefix: 'LET01',
            category: 'common',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_fr_iron_horn',
          name: 'Earthhorn',
          types: ['Earth'],
          family: 'Horn',
          level: 10,
          speed: 2.6,
          intelligence: 2.8,
          strength: 5.0,
          beauty: 2.6,
          sheetDef: _getSpriteSheetDef(
            'Earth',
            'Horn',
            idPrefix: 'HOR03',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontRight,
      ),

      // back
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_bl_storm_wing',
          name: 'Lightningwing',
          types: ['Lightning'],
          family: 'Wing',
          level: 10,
          speed: 4.5,
          intelligence: 3.6,
          strength: 3.8,
          beauty: 3.4,
          sheetDef: _getSpriteSheetDef(
            'Lightning',
            'Wing',
            idPrefix: 'WNG07',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_br_tidal_pip',
          name: 'Waterpip',
          types: ['Water'],
          family: 'Pip',
          level: 10,
          speed: 4.0,
          intelligence: 4.2,
          strength: 3.2,
          beauty: 3.5,
          sheetDef: _getSpriteSheetDef(
            'Water',
            'Pip',
            idPrefix: 'PIP02',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),

      // bench
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_b1_venom_mane',
          name: 'Poisonmane',
          types: ['Poison'],
          family: 'Mane',
          level: 10,
          speed: 3.4,
          intelligence: 3.8,
          strength: 4.0,
          beauty: 3.8,
          sheetDef: _getSpriteSheetDef(
            'Poison',
            'Mane',
            idPrefix: 'MAN13',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_b2_aurora_kin',
          name: 'Lightkin',
          types: ['Light'],
          family: 'Kin',
          level: 10,
          speed: 3.9,
          intelligence: 4.5,
          strength: 3.0,
          beauty: 4.8,
          sheetDef: _getSpriteSheetDef(
            'Light',
            'Kin',
            idPrefix: 'KIN16',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_b3_wisp_Wing',
          name: 'Spiritwing',
          types: ['Spirit'],
          family: 'Wing',
          level: 10,
          speed: 3.1,
          intelligence: 4.6,
          strength: 2.8,
          beauty: 4.0,
          sheetDef: _getSpriteSheetDef(
            'Spirit',
            'Wing',
            idPrefix: 'WNG14',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testA_b4_frost_mask',
          name: 'Icemask',
          types: ['Ice'],
          family: 'Mask',
          level: 10,
          speed: 3.0,
          intelligence: 4.0,
          strength: 3.0,
          beauty: 3.2,
          sheetDef: _getSpriteSheetDef(
            'Ice',
            'Mask',
            idPrefix: 'MSK09',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
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
          name: 'Lavalet',
          types: ['Lava'],
          family: 'Let',
          level: 10,
          speed: 3.3,
          intelligence: 3.9,
          strength: 4.7,
          beauty: 3.0,
          sheetDef: _getSpriteSheetDef(
            'Lava',
            'Let',
            idPrefix: 'LET06',
            category: 'common',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_fr_frozen_horn',
          name: 'Icehorn',
          types: ['Ice'],
          family: 'Horn',
          level: 10,
          speed: 2.7,
          intelligence: 3.3,
          strength: 4.8,
          beauty: 3.2,
          sheetDef: _getSpriteSheetDef(
            'Ice',
            'Horn',
            idPrefix: 'HOR09',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_bl_cinder_wing',
          name: 'Firewing',
          types: ['Fire'],
          family: 'Wing',
          level: 10,
          speed: 4.4,
          intelligence: 3.7,
          strength: 4.2,
          beauty: 3.6,
          sheetDef: _getSpriteSheetDef(
            'Fire',
            'Wing',
            idPrefix: 'WNG01',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_br_rain_pip',
          name: 'Waterpip',
          types: ['Water'],
          family: 'Pip',
          level: 10,
          speed: 4.2,
          intelligence: 4.2,
          strength: 3.3,
          beauty: 3.8,
          sheetDef: _getSpriteSheetDef(
            'Water',
            'Pip',
            idPrefix: 'PIP02',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_b1_sand_mask',
          name: 'Dustmask',
          types: ['Dust'],
          family: 'Mask',
          level: 10,
          speed: 3.2,
          intelligence: 4.0,
          strength: 3.1,
          beauty: 3.4,
          sheetDef: _getSpriteSheetDef(
            'Dust',
            'Mask',
            idPrefix: 'MSK10',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_b2_grove_mane',
          name: 'Plantmane',
          types: ['Plant'],
          family: 'Mane',
          level: 10,
          speed: 3.3,
          intelligence: 4.1,
          strength: 3.8,
          beauty: 4.0,
          sheetDef: _getSpriteSheetDef(
            'Plant',
            'Mane',
            idPrefix: 'MAN12',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_b3_lumen_kin',
          name: 'Lightkin',
          types: ['Light'],
          family: 'Kin',
          level: 10,
          speed: 3.9,
          intelligence: 4.5,
          strength: 3.1,
          beauty: 4.7,
          sheetDef: _getSpriteSheetDef(
            'Light',
            'Kin',
            idPrefix: 'KIN16',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'testE_b4_umbra_Mane',
          name: 'Darkmane',
          types: ['Dark'],
          family: 'Mane',
          level: 10,
          speed: 3.5,
          intelligence: 4.7,
          strength: 2.9,
          beauty: 4.2,
          sheetDef: _getSpriteSheetDef(
            'Dark',
            'Mane',
            idPrefix: 'MAN15',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
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
