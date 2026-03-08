// lib/games/survival/survival_debug_teams.dart
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flame/components.dart'; // REQUIRED for Vector2
// For Color

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

class DebugTeams {
  // ---------------------------------------------------------------------------
  // TEAM 1: NATURE & PHYSICAL (Earth, Plant, Water, Mud, Air, Dust, Blood)
  // ---------------------------------------------------------------------------
  static List<PartyMember> makeTeamOne() {
    return [
      // 1. Horn (Active Requirement) - Earth
      PartyMember(
        combatant: _makeCreature(
          id: 't1_earth_horn',
          name: 'Earthhorn',
          types: ['Earth'],
          family: 'Horn',
          level: 10,
          speed: 2.6,
          intelligence: 2.8,
          strength: 3.5,
          beauty: 2.5,
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
      // 2. Kin (Active Requirement) - Plant
      PartyMember(
        combatant: _makeCreature(
          id: 't1_plant_kin',
          name: 'Plantkin',
          types: ['Plant'],
          family: 'Kin',
          level: 10,
          speed: 3.1,
          intelligence: 3.3,
          strength: 2.6,
          beauty: 3.4,
          sheetDef: _getSpriteSheetDef(
            'Plant',
            'Kin',
            idPrefix: 'KIN12',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontRight,
      ),
      // 3. Water Let
      PartyMember(
        combatant: _makeCreature(
          id: 't1_water_let',
          name: 'Waterlet',
          types: ['Water'],
          family: 'Let',
          level: 10,
          speed: 2.9,
          intelligence: 2.7,
          strength: 2.8,
          beauty: 3.0,
          sheetDef: _getSpriteSheetDef(
            'Water',
            'Let',
            idPrefix: 'LET02',
            category: 'common',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backLeft,
      ),
      // 4. Mud Mane
      PartyMember(
        combatant: _makeCreature(
          id: 't1_mud_mane',
          name: 'Mudmane',
          types: ['Mud'],
          family: 'Mane',
          level: 10,
          speed: 2.7,
          intelligence: 2.9,
          strength: 3.3,
          beauty: 2.6,
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
      // Bench
      PartyMember(
        combatant: _makeCreature(
          id: 't1_air_wing',
          name: 'Airwing',
          types: ['Air'],
          family: 'Wing',
          level: 10,
          speed: 3.5,
          intelligence: 3.0,
          strength: 2.5,
          beauty: 3.2,
          sheetDef: _getSpriteSheetDef(
            frameSize: Vector2(250, 250),
            'Air',
            'Wing',
            idPrefix: 'WNG04',
            category: 'legendary',
            frames: 6,
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 't1_dust_mask',
          name: 'Dustmask',
          types: ['Dust'],
          family: 'Mask',
          level: 10,
          speed: 2.8,
          intelligence: 3.2,
          strength: 2.7,
          beauty: 2.9,
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
          id: 't1_blood_pip',
          name: 'Bloodpip',
          types: ['Blood'],
          family: 'Pip',
          level: 10,
          speed: 3.3,
          intelligence: 3.1,
          strength: 3.0,
          beauty: 2.5,
          sheetDef: _getSpriteSheetDef(
            'Blood',
            'Pip',
            idPrefix: 'PIP17',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 't1_poison_let',
          name: 'Poisonlet',
          types: ['Poison'],
          family: 'Let',
          level: 10,
          speed: 2.9,
          intelligence: 3.4,
          strength: 2.6,
          beauty: 2.7,
          sheetDef: _getSpriteSheetDef(
            'Poison',
            'Let',
            idPrefix: 'LET13',
            category: 'common',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // TEAM 2: ENERGY & ELEMENTAL (Fire, Lightning, Lava, Steam, Ice, Crystal)
  // ---------------------------------------------------------------------------
  static List<PartyMember> makeTeamTwo() {
    return [
      // 1. Horn (Active Requirement) - Fire
      PartyMember(
        combatant: _makeCreature(
          id: 't2_fire_horn',
          name: 'Firehorn',
          types: ['Fire'],
          family: 'Horn',
          level: 10,
          speed: 3.0,
          intelligence: 2.6,
          strength: 3.4,
          beauty: 2.8,
          sheetDef: _getSpriteSheetDef(
            'Fire',
            'Horn',
            idPrefix: 'HOR01',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontLeft,
      ),
      // 2. Kin (Active Requirement) - Lightning
      PartyMember(
        combatant: _makeCreature(
          id: 't2_lightning_kin',
          name: 'Lightningkin',
          types: ['Lightning'],
          family: 'Kin',
          level: 10,
          speed: 3.5,
          intelligence: 3.1,
          strength: 2.7,
          beauty: 3.2,
          sheetDef: _getSpriteSheetDef(
            'Lightning',
            'Kin',
            idPrefix: 'KIN07',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontRight,
      ),
      // 3. Lava Let
      PartyMember(
        combatant: _makeCreature(
          id: 't2_lava_let',
          name: 'Lavalet',
          types: ['Lava'],
          family: 'Let',
          level: 10,
          speed: 2.9,
          intelligence: 2.8,
          strength: 3.3,
          beauty: 2.6,
          sheetDef: _getSpriteSheetDef(
            'Lava',
            'Let',
            idPrefix: 'LET06',
            category: 'common',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backLeft,
      ),
      // 4. Steam Pip
      PartyMember(
        combatant: _makeCreature(
          id: 't2_steam_pip',
          name: 'Steampip',
          types: ['Steam'],
          family: 'Pip',
          level: 10,
          speed: 3.2,
          intelligence: 3.0,
          strength: 2.5,
          beauty: 3.3,
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
          id: 't2_ice_mask',
          name: 'Icemask',
          types: ['Ice'],
          family: 'Mask',
          level: 10,
          speed: 2.8,
          intelligence: 3.3,
          strength: 2.9,
          beauty: 3.1,
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
          id: 't2_crystal_mane',
          name: 'Crystalmane',
          types: ['Crystal'],
          family: 'Mane',
          level: 10,
          speed: 2.7,
          intelligence: 3.2,
          strength: 3.4,
          beauty: 3.5,
          sheetDef: _getSpriteSheetDef(
            'Crystal',
            'Mane',
            idPrefix: 'MAN11',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 't2_spirit_wing',
          name: 'Spiritwing',
          types: ['Spirit'],
          family: 'Wing',
          level: 10,
          speed: 3.1,
          intelligence: 3.4,
          strength: 2.5,
          beauty: 3.5,
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
          id: 't2_light_let',
          name: 'Lightlet',
          types: ['Light'],
          family: 'Let',
          level: 10,
          speed: 3.3,
          intelligence: 3.0,
          strength: 2.6,
          beauty: 3.4,
          sheetDef: _getSpriteSheetDef(
            'Light',
            'Let',
            idPrefix: 'LET16',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // TEAM 3: DARK & MYSTIC (Dark, Spirit, Poison, Blood, Water, Steam)
  // ---------------------------------------------------------------------------
  static List<PartyMember> makeTeamThree() {
    return [
      // 1. Kin (Active Requirement) - Spirit
      PartyMember(
        combatant: _makeCreature(
          id: 't3_spirit_kin',
          name: 'Spiritkin',
          types: ['Spirit'],
          family: 'Kin',
          level: 10,
          speed: 3.2,
          intelligence: 3.5,
          strength: 2.5,
          beauty: 3.4,
          sheetDef: _getSpriteSheetDef(
            'Spirit',
            'Kin',
            idPrefix: 'KIN14',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontLeft,
      ),
      // 2. Horn (Active Requirement) - Dark
      PartyMember(
        combatant: _makeCreature(
          id: 't3_dark_horn',
          name: 'Darkhorn',
          types: ['Dark'],
          family: 'Horn',
          level: 10,
          speed: 2.9,
          intelligence: 3.3,
          strength: 3.4,
          beauty: 2.8,
          sheetDef: _getSpriteSheetDef(
            'Dark',
            'Horn',
            idPrefix: 'HOR15',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontRight,
      ),
      // 3. Poison Mane
      PartyMember(
        combatant: _makeCreature(
          id: 't3_poison_mane',
          name: 'Poisonmane',
          types: ['Poison'],
          family: 'Mane',
          level: 10,
          speed: 3.0,
          intelligence: 3.1,
          strength: 3.2,
          beauty: 2.7,
          sheetDef: _getSpriteSheetDef(
            'Poison',
            'Mane',
            idPrefix: 'MAN13',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backLeft,
      ),
      // 4. Blood Mask
      PartyMember(
        combatant: _makeCreature(
          id: 't3_blood_mask',
          name: 'Bloodmask',
          types: ['Blood'],
          family: 'Mask',
          level: 10,
          speed: 3.1,
          intelligence: 3.4,
          strength: 3.0,
          beauty: 2.9,
          sheetDef: _getSpriteSheetDef(
            'Blood',
            'Mask',
            idPrefix: 'MSK17',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      // Bench
      PartyMember(
        combatant: _makeCreature(
          id: 't3_water_wing',
          name: 'Waterwing',
          types: ['Water'],
          family: 'Wing',
          level: 10,
          speed: 3.4,
          intelligence: 3.0,
          strength: 2.8,
          beauty: 3.3,
          sheetDef: _getSpriteSheetDef(
            'Water',
            'Wing',
            idPrefix: 'WNG02',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 't3_earth_pip',
          name: 'Earthpip',
          types: ['Earth'],
          family: 'Pip',
          level: 10,
          speed: 2.6,
          intelligence: 2.8,
          strength: 2.7,
          beauty: 2.5,
          sheetDef: _getSpriteSheetDef(
            'Earth',
            'Pip',
            idPrefix: 'PIP03',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 't3_steam_horn',
          name: 'Steamhorn',
          types: ['Steam'],
          family: 'Horn',
          level: 10,
          speed: 2.8,
          intelligence: 2.9,
          strength: 3.3,
          beauty: 2.9,
          sheetDef: _getSpriteSheetDef(
            'Steam',
            'Horn',
            idPrefix: 'HOR05',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 't3_plant_let',
          name: 'Leaflet',
          types: ['Plant'],
          family: 'Let',
          level: 10,
          speed: 2.7,
          intelligence: 2.8,
          strength: 2.6,
          beauty: 3.1,
          sheetDef: _getSpriteSheetDef(
            'Leaf',
            'Let',
            idPrefix: 'LET12',
            category: 'common',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // TEAM 4: CRYSTAL & CHAOS (Crystal, Air, Dust, Mud, Fire, Ice)
  // ---------------------------------------------------------------------------
  static List<PartyMember> makeTeamFour() {
    return [
      // 1. Horn (Active Requirement) - Crystal
      PartyMember(
        combatant: _makeCreature(
          id: 't4_crystal_horn',
          name: 'Crystalhorn',
          types: ['Crystal'],
          family: 'Horn',
          level: 10,
          speed: 2.7,
          intelligence: 3.2,
          strength: 3.5,
          beauty: 3.3,
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
      // 2. Kin (Active Requirement) - Air
      PartyMember(
        combatant: _makeCreature(
          id: 't4_air_kin',
          name: 'Airkin',
          types: ['Air'],
          family: 'Kin',
          level: 10,
          speed: 3.5,
          intelligence: 3.1,
          strength: 2.6,
          beauty: 3.0,
          sheetDef: _getSpriteSheetDef(
            'Air',
            'Kin',
            idPrefix: 'KIN04',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.frontRight,
      ),
      // 3. Dust Mane
      PartyMember(
        combatant: _makeCreature(
          id: 't4_dust_mane',
          name: 'Dustmane',
          types: ['Dust'],
          family: 'Mane',
          level: 10,
          speed: 2.9,
          intelligence: 3.0,
          strength: 3.2,
          beauty: 2.7,
          sheetDef: _getSpriteSheetDef(
            'Dust',
            'Mane',
            idPrefix: 'MAN10',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backLeft,
      ),
      // 4. Mud Pip
      PartyMember(
        combatant: _makeCreature(
          id: 't4_mud_pip',
          name: 'Mudpip',
          types: ['Mud'],
          family: 'Pip',
          level: 10,
          speed: 2.6,
          intelligence: 2.8,
          strength: 2.9,
          beauty: 2.5,
          sheetDef: _getSpriteSheetDef(
            'Mud',
            'Pip',
            idPrefix: 'PIP08',
            category: 'uncommon',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      // Bench
      PartyMember(
        combatant: _makeCreature(
          id: 't4_fire_wing',
          name: 'Firewing',
          types: ['Fire'],
          family: 'Wing',
          level: 10,
          speed: 3.4,
          intelligence: 3.1,
          strength: 2.8,
          beauty: 3.3,
          sheetDef: _getSpriteSheetDef(
            'Fire',
            'Wing',
            idPrefix: 'WNG01',
            category: 'legendary',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 't4_lightning_mask',
          name: 'Lightningmask',
          types: ['Lightning'],
          family: 'Mask',
          level: 10,
          speed: 3.3,
          intelligence: 3.4,
          strength: 2.8,
          beauty: 3.0,
          sheetDef: _getSpriteSheetDef(
            'Lightning',
            'Mask',
            idPrefix: 'MSK07',
            category: 'rare',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 't4_ice_let',
          name: 'Icelet',
          types: ['Ice'],
          family: 'Let',
          level: 10,
          speed: 3.0,
          intelligence: 3.0,
          strength: 2.7,
          beauty: 3.1,
          sheetDef: _getSpriteSheetDef(
            'Ice',
            'Let',
            idPrefix: 'LET09',
            category: 'common',
          ),
          visuals: const SpriteVisuals(),
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 't4_lava_mane',
          name: 'Lavamane',
          types: ['Lava'],
          family: 'Mane',
          level: 10,
          speed: 2.8,
          intelligence: 2.9,
          strength: 3.5,
          beauty: 2.7,
          sheetDef: _getSpriteSheetDef(
            'Lava',
            'Mane',
            idPrefix: 'MAN06',
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
      id: 'team1',
      label: 'Test Squad (Nature/Physical)',
      party: makeTeamOne(),
    ),
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
