// lib/games/planet_dungeon/planet_dungeon_data.dart
//
// PLANET DUNGEON — data model + persistence.
//
// Authored, per-planet multi-room layouts the swap-control dungeon scene runs
// on. Slice 2 is the reusable chassis: rooms are generic boxes with walls,
// doorways, a test hazard, and placeholder star pickups. Slice 3 replaces the
// placeholders with each planet's bespoke puzzles. See `project-planet-dungeons`.

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

// ─────────────────────────────────────────────────────────
// LAYOUT MODEL
// ─────────────────────────────────────────────────────────

/// A doorway region in a room. When the active creature overlaps [rect], the
/// scene transitions to [targetRoomId], placing creatures at [targetSpawn].
class DungeonDoor {
  final Rect rect;
  final String targetRoomId;
  final Offset targetSpawn;

  const DungeonDoor({
    required this.rect,
    required this.targetRoomId,
    required this.targetSpawn,
  });
}

/// A placeholder reward kept for the chassis / future planets. (The Air pilot
/// now earns stars from real puzzles instead.) Walking onto it banks star
/// [starIndex].
class DungeonStarPickup {
  final int starIndex;
  final Offset position;

  const DungeonStarPickup({required this.starIndex, required this.position});
}

// ── Star 1: Wind Spire ─────────────────────────────────────

/// Impassable void — blocks walking; only a gliding creature may cross.
class DungeonGap {
  final Rect rect;
  const DungeonGap(this.rect);
}

/// Directional wind that carries gliding creatures. If the glider's Speed is
/// below [requiredSpeed] the current overpowers them (net push backwards).
class WindCurrent {
  final Rect rect;
  final Offset dir; // normalised
  final double strength; // px/sec
  final double requiredSpeed; // 1..5 stat threshold (0 = no gate)
  const WindCurrent({
    required this.rect,
    required this.dir,
    this.strength = 90,
    this.requiredSpeed = 0,
  });
}

/// A hoop flown through in [order] (0,1,2…) to advance the spire sequence.
class SkyRing {
  final int order;
  final Offset position;
  const SkyRing({required this.order, required this.position});
}

/// Star 1 completion zone — entering while gliding (after the ring sequence)
/// earns [starIndex].
class SpireSummit {
  final Rect rect;
  final int starIndex;
  const SpireSummit({required this.rect, required this.starIndex});
}

// ── Star 2: Sky Loom ───────────────────────────────────────

/// A wonder-cloud (Spiral/Ring/Anvil/Feather/Veil). Discovered via Mask reveal
/// or proximity, then carried to its matching loom anchor.
class HiddenCloud {
  final String id;
  final String cloudType;
  final Offset position;
  const HiddenCloud({
    required this.id,
    required this.cloudType,
    required this.position,
  });
}

/// A loom slot that accepts a specific [requiredCloudType]. One anchor may
/// require a Thundercloud (an Anvil charged via the air+fire combo). [clue] is
/// shown when Mask intelligence is too low to reveal the exact type.
class LoomAnchor {
  final String id;
  final String requiredCloudType;
  final Offset position;
  final String clue;
  const LoomAnchor({
    required this.id,
    required this.requiredCloudType,
    required this.position,
    this.clue = '',
  });
}

// ── Star 3: Storm Altar ────────────────────────────────────

/// A conduit that must be energized. [id] 'A' = channelled (Perfect: Lightning
/// Horn; Valid: any Lightning, slower); 'B' = arc-lit by a Fire creature acting
/// inside the crossing wind current (the Air+Fire→Lightning recipe).
class Conduit {
  final String id;
  final Offset position;
  final String requireElement;
  final DungeonAbility?
  preferred; // best family ability (null = arc/recipe only)
  const Conduit({
    required this.id,
    required this.position,
    required this.requireElement,
    this.preferred,
  });

  DungeonInteractionRequirement get requirement =>
      DungeonInteractionRequirement(
        element: requireElement,
        preferred: preferred,
      );
}

/// A planet guardian (a Mystic). Awakens once its puzzle is solved; resolved by
/// calm or defeat per [encounter]. Kept separate from the family-ability model.
class GuardianNode {
  final Offset position;
  final int starIndex;
  final GuardianEncounterRequirement? encounter;
  const GuardianNode({
    required this.position,
    required this.starIndex,
    this.encounter,
  });
}

/// A single room. All coordinates are room-local world space (origin top-left).
class DungeonRoom {
  final String id;
  final Rect bounds; // playable area; creatures are clamped inside
  final List<Rect> walls; // solid obstacles (AABB collision)
  final List<DungeonDoor> doors;
  final List<Rect> hazards; // contact damages the active creature
  final List<DungeonStarPickup> stars; // legacy placeholder rewards
  // Slice-3 authored interactables:
  final List<DungeonGap> gaps;
  // Open-sky rooms: solid landing islands; everything else is sky (fly-only).
  final List<Rect> platforms;
  final List<WindCurrent> currents;
  final List<SkyRing> rings;
  final SpireSummit? summit;
  final List<HiddenCloud> clouds;
  final List<LoomAnchor> anchors;
  final int? loomStarIndex; // star awarded when all anchors are satisfied
  final List<Conduit> conduits;
  final GuardianNode? guardian;

  const DungeonRoom({
    required this.id,
    required this.bounds,
    this.walls = const [],
    this.doors = const [],
    this.hazards = const [],
    this.stars = const [],
    this.gaps = const [],
    this.platforms = const [],
    this.currents = const [],
    this.rings = const [],
    this.summit,
    this.clouds = const [],
    this.anchors = const [],
    this.loomStarIndex,
    this.conduits = const [],
    this.guardian,
  });
}

/// A whole planet dungeon: its rooms and where the run begins.
class DungeonLayout {
  final String element;
  final Map<String, DungeonRoom> rooms;
  final String entranceRoomId;
  final Offset entranceSpawn;

  const DungeonLayout({
    required this.element,
    required this.rooms,
    required this.entranceRoomId,
    required this.entranceSpawn,
  });

  DungeonRoom get entranceRoom => rooms[entranceRoomId]!;

  /// Distinct star indices discoverable in this dungeon (from any source).
  Set<int> get starIndices {
    final seen = <int>{};
    for (final room in rooms.values) {
      for (final s in room.stars) {
        seen.add(s.starIndex);
      }
      if (room.summit != null) seen.add(room.summit!.starIndex);
      if (room.loomStarIndex != null) seen.add(room.loomStarIndex!);
      if (room.guardian != null) seen.add(room.guardian!.starIndex);
    }
    return seen;
  }

  /// Number of distinct stars discoverable in this dungeon (≤ 3).
  int get totalStars => starIndices.length;
}

// ─────────────────────────────────────────────────────────
// AUTHORED LAYOUTS
// ─────────────────────────────────────────────────────────

/// Air pilot layout: Wind-Crown Spire. The authored room graph follows the
/// "hub + vertical ascent + optional cloud branches + ritual chamber + storm
/// summit" brief. Gameplay lists stay intentionally simple: platforms/currents
/// drive collision and traversal; clouds/anchors/conduits/guardian drive puzzle
/// logic; rendering interprets the same data procedurally.
const DungeonLayout _airLayout = DungeonLayout(
  element: 'Air',
  entranceRoomId: 'entry',
  entranceSpawn: Offset(220, 290),
  rooms: {
    // Room A — Entry Island.
    'entry': DungeonRoom(
      id: 'entry',
      bounds: Rect.fromLTWH(0, 0, 720, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(696, 230, 24, 90),
          targetRoomId: 'hub',
          targetSpawn: Offset(120, 330),
        ),
      ],
      currents: [
        WindCurrent(
          rect: Rect.fromLTWH(292, 242, 136, 136),
          dir: Offset(0, -1),
          strength: 0,
        ),
      ],
    ),

    // Room B — Wind Hub / Compass.
    'hub': DungeonRoom(
      id: 'hub',
      bounds: Rect.fromLTWH(0, 0, 920, 680),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 285, 24, 90),
          targetRoomId: 'entry',
          targetSpawn: Offset(650, 280),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(896, 285, 24, 90),
          targetRoomId: 'lower_spire',
          targetSpawn: Offset(250, 850),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(365, 0, 120, 24),
          targetRoomId: 'spiral_cloud',
          targetSpawn: Offset(350, 520),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(580, 0, 120, 24),
          targetRoomId: 'ring_cloud',
          targetSpawn: Offset(350, 520),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(408, 656, 120, 24),
          targetRoomId: 'sky_loom',
          targetSpawn: Offset(500, 100),
        ),
      ],
    ),

    // Room C — Lower Spire Path.
    'lower_spire': DungeonRoom(
      id: 'lower_spire',
      bounds: Rect.fromLTWH(0, 0, 760, 980),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(190, 900, 120, 30),
          targetRoomId: 'hub',
          targetSpawn: Offset(845, 330),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(40, 430, 30, 120),
          targetRoomId: 'feather_cloud',
          targetSpawn: Offset(620, 270),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(560, 70, 120, 30),
          targetRoomId: 'crosswind_hall',
          targetSpawn: Offset(90, 300),
        ),
      ],
      platforms: [
        Rect.fromLTWH(140, 820, 260, 110),
        Rect.fromLTWH(95, 620, 210, 80),
        Rect.fromLTWH(415, 430, 210, 80),
        Rect.fromLTWH(485, 70, 220, 95),
      ],
      currents: [
        WindCurrent(
          rect: Rect.fromLTWH(205, 610, 220, 300),
          dir: Offset(0, -1),
          strength: 70,
        ),
        WindCurrent(
          rect: Rect.fromLTWH(170, 410, 360, 180),
          dir: Offset(0.5, -1),
          strength: 78,
        ),
        // Thermal column up the west face: walkers ride it from platform 1
        // to the feather-chamber door (which floats over open sky).
        WindCurrent(
          rect: Rect.fromLTWH(50, 430, 130, 430),
          dir: Offset(0, -1),
          strength: 85,
        ),
      ],
      rings: [SkyRing(order: 0, position: Offset(310, 735))],
    ),

    // Room D — Crosswind Hall.
    'crosswind_hall': DungeonRoom(
      id: 'crosswind_hall',
      bounds: Rect.fromLTWH(0, 0, 980, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 250, 30, 100),
          targetRoomId: 'lower_spire',
          targetSpawn: Offset(560, 120),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(900, 250, 30, 100),
          targetRoomId: 'cloud_platforms',
          targetSpawn: Offset(245, 820),
        ),
      ],
      platforms: [
        Rect.fromLTWH(55, 255, 180, 85),
        Rect.fromLTWH(285, 235, 180, 85),
        Rect.fromLTWH(520, 270, 180, 85),
        Rect.fromLTWH(760, 245, 180, 85),
      ],
      currents: [
        WindCurrent(
          rect: Rect.fromLTWH(210, 120, 610, 110),
          dir: Offset(1, 0.1),
          strength: 92,
          requiredSpeed: 2.5,
        ),
        WindCurrent(
          rect: Rect.fromLTWH(180, 360, 640, 95),
          dir: Offset(-1, -0.1),
          strength: 88,
          requiredSpeed: 2.5,
        ),
      ],
      rings: [SkyRing(order: 1, position: Offset(490, 280))],
    ),

    // Room E — Cloud Platform Room.
    'cloud_platforms': DungeonRoom(
      id: 'cloud_platforms',
      bounds: Rect.fromLTWH(0, 0, 720, 940),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(185, 850, 120, 30),
          targetRoomId: 'crosswind_hall',
          targetSpawn: Offset(840, 290),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(360, 60, 120, 30),
          targetRoomId: 'spire_summit',
          targetSpawn: Offset(380, 470),
        ),
      ],
      platforms: [
        Rect.fromLTWH(150, 780, 210, 90),
        Rect.fromLTWH(420, 600, 170, 76),
        Rect.fromLTWH(100, 430, 185, 76),
        Rect.fromLTWH(380, 240, 170, 76),
        Rect.fromLTWH(315, 60, 220, 86),
      ],
      currents: [
        WindCurrent(
          rect: Rect.fromLTWH(255, 535, 240, 300),
          dir: Offset(0, -1),
          strength: 105,
          requiredSpeed: 3.0,
        ),
        WindCurrent(
          rect: Rect.fromLTWH(245, 155, 260, 300),
          dir: Offset(0, -1),
          strength: 130,
          requiredSpeed: 3.5,
        ),
      ],
      rings: [SkyRing(order: 2, position: Offset(420, 205))],
    ),

    // Room F — Spire Summit.
    'spire_summit': DungeonRoom(
      id: 'spire_summit',
      bounds: Rect.fromLTWH(0, 0, 760, 620),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(320, 560, 120, 30),
          targetRoomId: 'cloud_platforms',
          targetSpawn: Offset(405, 115),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(700, 255, 30, 110),
          targetRoomId: 'sky_loom',
          targetSpawn: Offset(115, 390),
        ),
      ],
      summit: SpireSummit(
        rect: Rect.fromLTWH(275, 225, 210, 130),
        starIndex: 0,
      ),
    ),

    // Room G — Spiral Cloud Room.
    'spiral_cloud': DungeonRoom(
      id: 'spiral_cloud',
      bounds: Rect.fromLTWH(0, 0, 700, 620),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(290, 586, 120, 30),
          targetRoomId: 'hub',
          targetSpawn: Offset(425, 70),
        ),
      ],
      clouds: [
        HiddenCloud(
          id: 'c_spiral',
          cloudType: 'Spiral',
          position: Offset(350, 285),
        ),
      ],
    ),

    // Room H — Ring Cloud Room.
    'ring_cloud': DungeonRoom(
      id: 'ring_cloud',
      bounds: Rect.fromLTWH(0, 0, 700, 620),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(290, 586, 120, 30),
          targetRoomId: 'hub',
          targetSpawn: Offset(640, 70),
        ),
      ],
      clouds: [
        HiddenCloud(
          id: 'c_ring',
          cloudType: 'Ring',
          position: Offset(350, 285),
        ),
      ],
    ),

    // Room I — Anvil Cloud Room. Entered DOWNWARD from the loom, so its
    // return door sits on the TOP edge (descend → arrive at the top).
    'anvil_cloud': DungeonRoom(
      id: 'anvil_cloud',
      bounds: Rect.fromLTWH(0, 0, 760, 620),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(320, 0, 120, 24),
          targetRoomId: 'sky_loom',
          targetSpawn: Offset(295, 670),
        ),
      ],
      clouds: [
        HiddenCloud(
          id: 'c_anvil',
          cloudType: 'Anvil',
          position: Offset(380, 285),
        ),
      ],
      currents: [
        WindCurrent(
          rect: Rect.fromLTWH(525, 210, 150, 100),
          dir: Offset(1, 0),
          strength: 0,
        ),
      ],
    ),

    // Room J — Feather Cloud Room.
    'feather_cloud': DungeonRoom(
      id: 'feather_cloud',
      bounds: Rect.fromLTWH(0, 0, 760, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(730, 250, 30, 100),
          targetRoomId: 'lower_spire',
          targetSpawn: Offset(505, 470),
        ),
      ],
      platforms: [Rect.fromLTWH(80, 215, 575, 95)],
      clouds: [
        HiddenCloud(
          id: 'c_feather',
          cloudType: 'Feather',
          position: Offset(320, 255),
        ),
      ],
    ),

    // Room K — Veil Cloud Room. Entered DOWNWARD from the loom, so its
    // return door sits on the TOP edge (descend → arrive at the top).
    'veil_cloud': DungeonRoom(
      id: 'veil_cloud',
      bounds: Rect.fromLTWH(0, 0, 760, 620),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(320, 0, 120, 24),
          targetRoomId: 'sky_loom',
          targetSpawn: Offset(715, 670),
        ),
      ],
      clouds: [
        HiddenCloud(
          id: 'c_veil',
          cloudType: 'Veil',
          position: Offset(380, 285),
        ),
      ],
    ),

    // Room S — Sky Loom Chamber.
    'sky_loom': DungeonRoom(
      id: 'sky_loom',
      bounds: Rect.fromLTWH(0, 0, 1000, 760),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(445, 0, 120, 24),
          targetRoomId: 'hub',
          targetSpawn: Offset(465, 610),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 335, 24, 100),
          targetRoomId: 'spire_summit',
          targetSpawn: Offset(660, 305),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(235, 736, 120, 24),
          targetRoomId: 'anvil_cloud',
          targetSpawn: Offset(380, 86),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(655, 736, 120, 24),
          targetRoomId: 'veil_cloud',
          targetSpawn: Offset(380, 86),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(976, 220, 24, 100),
          targetRoomId: 'relic_chamber',
          targetSpawn: Offset(110, 310),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(976, 445, 24, 100),
          targetRoomId: 'storm_rune_hall',
          targetSpawn: Offset(90, 280),
        ),
      ],
      currents: [
        // The weaving stream — charge an Anvil here (air+fire) into a
        // Thundercloud. Strength 0: it's the medium, not a push.
        WindCurrent(
          rect: Rect.fromLTWH(405, 515, 220, 90),
          dir: Offset(1, 0),
          strength: 0,
        ),
      ],
      clouds: [
        HiddenCloud(
          id: 'c_spiral',
          cloudType: 'Spiral',
          position: Offset(175, 585),
        ),
        HiddenCloud(
          id: 'c_ring',
          cloudType: 'Ring',
          position: Offset(825, 585),
        ),
        HiddenCloud(
          id: 'c_anvil',
          cloudType: 'Anvil',
          position: Offset(505, 650),
        ),
        HiddenCloud(
          id: 'c_feather',
          cloudType: 'Feather',
          position: Offset(255, 350),
        ),
        HiddenCloud(
          id: 'c_veil',
          cloudType: 'Veil',
          position: Offset(745, 350),
        ),
      ],
      anchors: [
        LoomAnchor(
          id: 'a_spiral',
          requiredCloudType: 'Spiral',
          position: Offset(240, 160),
          clue: 'the eye of the gale',
        ),
        LoomAnchor(
          id: 'a_ring',
          requiredCloudType: 'Ring',
          position: Offset(370, 118),
          clue: 'the endless orbit',
        ),
        LoomAnchor(
          id: 'a_feather',
          requiredCloudType: 'Feather',
          position: Offset(500, 95),
          clue: 'the weightless wing',
        ),
        LoomAnchor(
          id: 'a_veil',
          requiredCloudType: 'Veil',
          position: Offset(630, 118),
          clue: 'the hidden shroud',
        ),
        LoomAnchor(
          id: 'a_thunder',
          requiredCloudType: 'Thundercloud',
          position: Offset(760, 160),
          clue: 'the storm-heart — charge an anvil',
        ),
      ],
      loomStarIndex: 1,
    ),

    // Relic Chamber — Star 2 reward space.
    'relic_chamber': DungeonRoom(
      id: 'relic_chamber',
      bounds: Rect.fromLTWH(0, 0, 640, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 265, 24, 90),
          targetRoomId: 'sky_loom',
          targetSpawn: Offset(930, 270),
        ),
      ],
    ),

    // Room L — Storm Rune Hall.
    'storm_rune_hall': DungeonRoom(
      id: 'storm_rune_hall',
      bounds: Rect.fromLTWH(0, 0, 840, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 240, 24, 100),
          targetRoomId: 'sky_loom',
          targetSpawn: Offset(930, 495),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(816, 240, 24, 100),
          targetRoomId: 'twin_conduit',
          targetSpawn: Offset(90, 330),
        ),
      ],
    ),

    // Room M — Twin Conduit Room.
    'twin_conduit': DungeonRoom(
      id: 'twin_conduit',
      bounds: Rect.fromLTWH(0, 0, 900, 660),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 285, 24, 100),
          targetRoomId: 'storm_rune_hall',
          targetSpawn: Offset(760, 290),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(876, 285, 24, 100),
          targetRoomId: 'storm_altar',
          targetSpawn: Offset(100, 350),
        ),
      ],
      currents: [
        // The stream crossing conduit B — a Fire creature acting here lights
        // the arc.
        WindCurrent(
          rect: Rect.fromLTWH(570, 285, 210, 90),
          dir: Offset(-1, 0),
          strength: 0,
        ),
      ],
      conduits: [
        Conduit(
          id: 'A',
          position: Offset(230, 330),
          requireElement: 'Lightning',
          preferred: DungeonAbility.heavyForce, // best: Lightning Horn
        ),
        Conduit(
          id: 'B',
          position: Offset(670, 330),
          requireElement: 'Fire', // arc-lit by Fire in the wind current
        ),
      ],
    ),

    // Room N — Storm Altar Arena.
    'storm_altar': DungeonRoom(
      id: 'storm_altar',
      bounds: Rect.fromLTWH(0, 0, 820, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 310, 24, 100),
          targetRoomId: 'twin_conduit',
          targetSpawn: Offset(820, 335),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(360, 0, 120, 24),
          targetRoomId: 'guardian_summit',
          targetSpawn: Offset(390, 590),
        ),
      ],
    ),

    // Room O — Guardian Summit.
    'guardian_summit': DungeonRoom(
      id: 'guardian_summit',
      bounds: Rect.fromLTWH(0, 0, 820, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(360, 676, 120, 24),
          targetRoomId: 'storm_altar',
          targetSpawn: Offset(410, 70),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(410, 300),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Air',
          mysticId: 'Roc',
          canCalm: true,
          canDefeat: true,
        ),
      ),
    ),
  },
);

/// Authored dungeon layouts keyed by planet element. A planet is only enterable
/// if it appears here.
const Map<String, DungeonLayout> kPlanetDungeonLayouts = {'Air': _airLayout};

// ─────────────────────────────────────────────────────────
// RAID ARENAS
// ─────────────────────────────────────────────────────────

/// Elements whose mystic guardian can host a raid, mapped to the mystic id the
/// arena spawns. Add an element here only after its spritesheet is wired into
/// the game's guardian sheet map.
const Map<String, String> kRaidGuardianIds = {'Air': 'Roc'};

/// A raid is one big open planet-themed arena — no rooms, no puzzles, just
/// the empowered guardian under the storm. Generated, not authored, so every
/// element in [kRaidGuardianIds] gets one for free.
DungeonLayout buildRaidArenaLayout(String element) {
  final mysticId = kRaidGuardianIds[element];
  assert(mysticId != null, 'No raid guardian configured for $element');
  final room = DungeonRoom(
    id: 'raid_arena',
    bounds: const Rect.fromLTWH(0, 0, 1400, 900),
    // Element-flavored crosswinds give gliders play without gating walkers.
    currents: const [
      WindCurrent(
        rect: Rect.fromLTWH(0, 80, 360, 740),
        dir: Offset(0, -1),
        strength: 70,
      ),
      WindCurrent(
        rect: Rect.fromLTWH(1040, 80, 360, 740),
        dir: Offset(0, -1),
        strength: 70,
      ),
    ],
    guardian: GuardianNode(
      position: const Offset(700, 380),
      starIndex: 2, // unused in raid mode; keeps the node shape uniform
      encounter: GuardianEncounterRequirement(
        element: element,
        mysticId: mysticId!,
        canCalm: false,
        canDefeat: true,
      ),
    ),
  );
  return DungeonLayout(
    element: element,
    rooms: {'raid_arena': room},
    entranceRoomId: 'raid_arena',
    entranceSpawn: const Offset(700, 740),
  );
}
