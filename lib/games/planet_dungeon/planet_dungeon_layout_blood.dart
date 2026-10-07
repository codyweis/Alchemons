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
//   · All four freed: the first star, and the seal in the middle of the
//     Circle opens on THE HEART (2026-10-06): Blood is taken and bound there,
//     and the four it freed fuse their way up the recipe table to Blood
//     (Light + Dark) to free it — the second star. Its floor then opens on
//     Sanguorath. Rules: planet_dungeon_blood_heart.dart.
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

enum RiteKind { circle, earth, water, fire, air, vault, heart, arena }

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

  /// A room played as one held picture with its own RESET ROOM: the four
  /// captive rooms and the Heart.
  bool get isStaged => isGrid || kind == RiteKind.heart;

  /// The first star is declared on the Circle (freeing the fourth captive
  /// banks it, wherever it was freed); the second is the Heart's.
  List<int> get starIndices => switch (kind) {
    RiteKind.circle => const [0],
    RiteKind.heart => const [1],
    _ => const [],
  };

  int? get starIndex => switch (kind) {
    RiteKind.circle => 0,
    RiteKind.heart => 1,
    _ => null,
  };

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

/// Discovery id: Blood freed in the Heart (persists across descents).
const String kRiteHeartFreedId = 'gate:rite_heart_freed';

/// The Heart is 14 × 9 squares: an open space above, the stage along the
/// bottom. Blood comes down from the seal by the stair in the stage's west
/// post and arrives beside it, here; once it is freed it stands again in
/// the middle of the stage, under where it was bound, and the stage opens
/// on Sanguorath at [kRiteHeartWayDown].
const RiteCell kRiteHeartArrival = (x: 1, y: 6);
const RiteCell kRiteHeartFreedAt = (x: 7, y: 7);
const RiteCell kRiteHeartWayDown = (x: 7, y: 6);

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
  finaleDoor: DungeonDoorRef('rite_heart', 'sanguorath_heart'),
  riteAnnouncement: 'Blood is free. The floor of the Heart opens',
  riteWakeLine: 'Blood is free. Sanguorath wakes below the Heart',
  finaleSealedHint: 'The way down stays shut until Blood is free',
  guardianSealedHint: 'Sanguorath won\'t wake until Blood is free',
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
        // The seal in the middle: a door in the floor, down to the Heart
        // (it is there once all four cups are full).
        DungeonDoor(
          rect: Rect.fromLTWH(420, 420, 60, 60),
          targetRoomId: 'rite_heart',
          targetSpawn: Offset(96, 416),
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

    // ── THE HEART (Star 2) — the fifth rite ── 14×9 ───────
    'rite_heart': DungeonRoom(
      id: 'rite_heart',
      bounds: Rect.fromLTWH(0, 0, 896, 576),
      doors: [
        // (0,7) west: the stair back up to the Circle (once Blood is free).
        DungeonDoor(
          rect: Rect.fromLTWH(0, 448, 24, 64),
          targetRoomId: 'rite_circle',
          targetSpawn: Offset(450, 540),
        ),
        // (7,6): the stage opens on Sanguorath once Blood is free.
        DungeonDoor(
          rect: Rect.fromLTWH(456, 392, 48, 48),
          targetRoomId: 'sanguorath_heart',
          targetSpawn: Offset(450, 120),
          chromeless: true,
        ),
      ],
      teach:
          'Two on an altar fuse, and what they make rises to what hangs '
          'above it. The split stage takes anything apart. Make Blood to '
          'free your Blood',
      rite: RiteBay(RiteKind.heart),
    ),

    // ── SANGUORATH (Star 3) — the staged fight ────────────
    'sanguorath_heart': DungeonRoom(
      id: 'sanguorath_heart',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'rite_heart',
          targetSpawn: Offset(480, 480),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(450, 360),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Blood',
          mysticId: 'Sanguorath',
        ),
      ),
      rite: RiteBay(RiteKind.arena),
    ),
  },
);
