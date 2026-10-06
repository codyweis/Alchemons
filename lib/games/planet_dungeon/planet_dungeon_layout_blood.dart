// lib/games/planet_dungeon/planet_dungeon_layout_blood.dart
//
// HEMAVORN — THE BLOOD RITES (rebuilt 2026-10-05; it replaces the Sanguine
// Orrery whole). Blood's layout: the Circle, the four captive rooms, the
// vault and Sanguorath's arena. The rules live in
// planet_dungeon_blood_rites.dart; the play in planet_dungeon_game_blood.dart;
// the drawing in planet_dungeon_game_blood_art.dart.
//
// The author's design (docs/dungeons.md, "BLOOD — THE BLOOD RITES"):
//
//   · ONE Blood Alchemon goes down, alone.
//   · Four rooms — Earth, Water, Fire, Air — each hold a captive of that
//     element. Solve the room and its two ingredients meet at the captive
//     (the game's own recipes); it dissolves into blood that runs home to
//     the Circle and fills its cup.
//   · All four freed: two stars at once, and the seal in the middle of the
//     Circle opens on Sanguorath.
//   · Sanguorath fights in stages: the four come down with Blood, the player
//     controls all five, and at each fifth of its health one of them gives
//     itself. The last fifth is Blood alone.
//   · The Lost Maxim is in the Circle: turn its two rings so all four
//     streams meet in the middle — the quintessence.
//   · The vault is in the Water room, hidden in its commonest mistake: water
//     that pours into the pit makes a pool you can dive through.
//
// THE GEOGRAPHY. The Circle's doors stand at the compass points its rings
// were proved with (Air north, Fire east, Earth south, Water west), and every
// room's own door faces back at it. The Water room is the prototype's
// mirrored left to right so that its door is on its east wall; it was
// re-proved mirrored (3 flips, half its states dead ends, the vault 4 moves
// in). The Air room's way in is its south wall, and Blood arrives at (4,7);
// re-proved from there (19 pushes, 74% dead ends).

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_blood_rites.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

// ─────────────────────────────────────────────────────────
// THE GRID
// ─────────────────────────────────────────────────────────

/// One square of a captive room's floor, in world units.
const double kRiteCell = 64;

Offset riteCentreOf(int x, int y) =>
    Offset((x + 0.5) * kRiteCell, (y + 0.5) * kRiteCell);

RiteCell riteSquareAt(Offset p) =>
    (x: (p.dx / kRiteCell).floor(), y: (p.dy / kRiteCell).floor());

// ─────────────────────────────────────────────────────────
// THE CIRCLE
// ─────────────────────────────────────────────────────────

const double kRiteCircleSize = 900;
const Offset kRiteCircleCentre = Offset(450, 450);

/// The circle floor's radius (outside it is stone).
const double kRiteCircleRadius = 410;

/// The two rings' bands (inner edge, outer edge), in world units from the
/// centre. Standing on a band, the pad turns that ring.
const (double, double) kRiteOuterBand = (224, 300);
const (double, double) kRiteInnerBand = (122, 198);

/// The cups sit just inside each door.
const double kRiteCupRadius = 352;

/// The boss seal in the middle (a door in the floor).
const double kRiteSealRadius = 64;

/// Where an element's door (and cup) stands, as a unit vector from centre.
Offset riteDoorDir(String element) {
  final s = kRiteDoorSector[element]!;
  const d = [Offset(0, -1), Offset(1, 0), Offset(0, 1), Offset(-1, 0)];
  return d[s ~/ 2];
}

// ─────────────────────────────────────────────────────────
// PER-ROOM CONTENT
// ─────────────────────────────────────────────────────────

enum RiteKind { circle, earth, water, fire, air, vault, arena }

/// What the Blood Rites put in one room. Carried on `DungeonRoom.rite`.
class RiteBay {
  final RiteKind kind;
  const RiteBay(this.kind);

  /// The captive room's element, or null.
  String? get element => switch (kind) {
    RiteKind.earth => 'Earth',
    RiteKind.water => 'Water',
    RiteKind.fire => 'Fire',
    RiteKind.air => 'Air',
    _ => null,
  };

  /// The two ingredients that meet at this room's captive.
  (String, String)? get recipe => switch (kind) {
    RiteKind.earth => ('Dust', 'Water'),
    RiteKind.water => ('Fire', 'Ice'),
    RiteKind.fire => ('Air', 'Lava'),
    RiteKind.air => ('Ice', 'Light'),
    _ => null,
  };

  bool get isGrid => element != null;

  /// Blood declares BOTH of its non-guardian stars on the Circle: freeing
  /// the fourth captive banks the pair, wherever it was freed.
  List<int> get starIndices =>
      kind == RiteKind.circle ? const [0, 1] : const [];

  /// The first of them, for the map's star marks.
  int? get starIndex => kind == RiteKind.circle ? 0 : null;

  /// The room's grid, as the rules read it.
  List<String>? get map => switch (kind) {
    RiteKind.earth => kRiteEarthMap,
    RiteKind.water => kRiteWaterMap,
    RiteKind.fire => kRiteFireMap,
    RiteKind.air => kRiteAirMap,
    _ => null,
  };
}

/// The room id of each element's captive room.
const Map<String, String> kRiteRoomOf = {
  'Earth': 'rite_earth',
  'Water': 'rite_water',
  'Fire': 'rite_fire',
  'Air': 'rite_air',
};

/// The square inside each captive room's door (where Blood arrives).
const Map<String, RiteCell> kRiteArrival = {
  'Earth': (x: 7, y: 1),
  'Water': (x: 7, y: 6),
  'Fire': (x: 1, y: 1),
  'Air': (x: 4, y: 7),
};

/// The Water room's pit — the way down to the vault once it is flooded.
const RiteCell kRiteWaterPit = (x: 5, y: 5);

/// Discovery ids: each freed captive persists across descents (the 'gate:'
/// channel is quiet — no secret cue, no gold).
String riteFreedId(String element) => 'gate:rite_freed_$element';

/// The Lost Maxim: the quintessence.
const String kBloodEggId = 'egg:blood_quintessence';

// ─────────────────────────────────────────────────────────
// THE LAYOUT
// ─────────────────────────────────────────────────────────

/// Hemavorn — the Blood Rites.
const DungeonLayout bloodLayout = DungeonLayout(
  element: 'Blood',
  entranceRoomId: 'rite_circle',
  entranceSpawn: Offset(450, 690),
  title: 'THE BLOOD RITES',
  descentTitle: 'Hemavorn Rites',
  stars: [
    DungeonStarSpec(
      name: 'Solve Star',
      earnAnnouncement: 'The Solve Star is yours',
    ),
    DungeonStarSpec(
      name: 'Coagula Star',
      earnAnnouncement: 'The Coagula Star is yours',
    ),
    DungeonStarSpec(name: 'Sanguine Star'),
  ],
  finaleDoor: DungeonDoorRef('rite_circle', 'sanguorath_heart'),
  riteAnnouncement:
      'All four are freed. The seal in the middle of the Circle is open',
  riteWakeLine: 'All four cups are full. Sanguorath wakes below the seal',
  finaleSealedHint: 'The seal stays shut until all four captives are freed',
  guardianSealedHint: 'Sanguorath won\'t wake until all four cups are full',
  mercyShrineRoomId: 'rite_circle',
  // One line per entry slot, and Blood has one.
  riddle: [
    'Send me one Blood, alone: the four old elements wait below to go down '
        'with it.',
  ],
  primer: [
    'One Blood goes down alone. Four rooms each hold a captive.',
    'Free all four and they fight beside you.',
  ],
  rooms: {
    // ── THE CIRCLE (entrance, hub, the maxim) ─────────────
    'rite_circle': DungeonRoom(
      id: 'rite_circle',
      bounds: Rect.fromLTWH(0, 0, kRiteCircleSize, kRiteCircleSize),
      doors: [
        // North → Air.
        DungeonDoor(
          rect: Rect.fromLTWH(410, 0, 80, 24),
          targetRoomId: 'rite_air',
          targetSpawn: Offset(288, 480),
        ),
        // East → Fire.
        DungeonDoor(
          rect: Rect.fromLTWH(876, 410, 24, 80),
          targetRoomId: 'rite_fire',
          targetSpawn: Offset(96, 96),
        ),
        // South → Earth.
        DungeonDoor(
          rect: Rect.fromLTWH(410, 876, 80, 24),
          targetRoomId: 'rite_earth',
          targetSpawn: Offset(480, 96),
        ),
        // West → Water.
        DungeonDoor(
          rect: Rect.fromLTWH(0, 410, 24, 80),
          targetRoomId: 'rite_water',
          targetSpawn: Offset(480, 416),
        ),
        // The seal in the middle: a door in the floor, down to Sanguorath.
        DungeonDoor(
          rect: Rect.fromLTWH(420, 420, 60, 60),
          targetRoomId: 'sanguorath_heart',
          targetSpawn: Offset(450, 120),
          chromeless: true,
        ),
      ],
      rite: RiteBay(RiteKind.circle),
    ),

    // ── EARTH — the tendril floor ── 11×9 ─────────────────
    'rite_earth': DungeonRoom(
      id: 'rite_earth',
      bounds: Rect.fromLTWH(0, 0, 704, 576),
      doors: [
        // (7,0) north → back to the Circle, above its south door.
        DungeonDoor(
          rect: Rect.fromLTWH(448, 0, 64, 24),
          targetRoomId: 'rite_circle',
          targetSpawn: Offset(450, 800),
        ),
      ],
      teach: 'Lead each tendril to its partner',
      rite: RiteBay(RiteKind.earth),
    ),

    // ── WATER — the turning room ── 9×8 ───────────────────
    'rite_water': DungeonRoom(
      id: 'rite_water',
      bounds: Rect.fromLTWH(0, 0, 576, 512),
      doors: [
        // (8,6) east → back to the Circle, beside its west door.
        DungeonDoor(
          rect: Rect.fromLTWH(552, 384, 24, 64),
          targetRoomId: 'rite_circle',
          targetSpawn: Offset(100, 450),
        ),
        // The pit (5,5), once flooded: dive down to the vault.
        DungeonDoor(
          rect: Rect.fromLTWH(320, 320, 64, 64),
          targetRoomId: 'rite_vault',
          targetSpawn: Offset(224, 96),
          chromeless: true,
        ),
      ],
      teach: 'Flip turns the room over',
      rite: RiteBay(RiteKind.water),
    ),

    // ── FIRE — the twin ── 11×8 ───────────────────────────
    'rite_fire': DungeonRoom(
      id: 'rite_fire',
      bounds: Rect.fromLTWH(0, 0, 704, 512),
      doors: [
        // (0,1) west → back to the Circle, beside its east door.
        DungeonDoor(
          rect: Rect.fromLTWH(0, 64, 24, 64),
          targetRoomId: 'rite_circle',
          targetSpawn: Offset(800, 450),
        ),
      ],
      teach: 'Your twin takes the mirror of every step',
      rite: RiteBay(RiteKind.fire),
    ),

    // ── AIR — the weightless room ── 9×9 ──────────────────
    'rite_air': DungeonRoom(
      id: 'rite_air',
      bounds: Rect.fromLTWH(0, 0, 576, 576),
      doors: [
        // (4,8) south → back to the Circle, below its north door.
        DungeonDoor(
          rect: Rect.fromLTWH(256, 552, 64, 24),
          targetRoomId: 'rite_circle',
          targetSpawn: Offset(450, 100),
        ),
      ],
      teach: 'Push off and you drift',
      rite: RiteBay(RiteKind.air),
    ),

    // ── THE VAULT — under the Water room's flooded pit ────
    'rite_vault': DungeonRoom(
      id: 'rite_vault',
      bounds: Rect.fromLTWH(0, 0, 448, 320),
      doors: [
        // Up the shaft, back out at the Water room's door.
        DungeonDoor(
          rect: Rect.fromLTWH(192, 0, 64, 24),
          targetRoomId: 'rite_water',
          targetSpawn: Offset(480, 416),
        ),
      ],
      vaultCache: Offset(224, 200),
      rite: RiteBay(RiteKind.vault),
    ),

    // ── SANGUORATH (Star 3) — the staged fight ────────────
    'sanguorath_heart': DungeonRoom(
      id: 'sanguorath_heart',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'rite_circle',
          targetSpawn: Offset(450, 560),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(450, 360),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Blood',
          mysticId: 'Sanguorath',
          canCalm: false,
          canDefeat: true,
        ),
      ),
      rite: RiteBay(RiteKind.arena),
    ),
  },
);
