// lib/games/planet_dungeon/planet_dungeon_layout_spirit.dart
//
// REQUIA — THE UNFINISHED FUNERAL. Spirit's authored layout, its pure rules,
// and the puzzle DATA its `part of planet_dungeon_game.dart` module reasons
// about. Design: docs/dungeons.md, "SPIRIT — THE UNFINISHED FUNERAL: BUILD
// SPEC" (2026-09-28). It replaces the Echo Grave (the barrow round, its
// revenants and its sigil), which is kept in the doc as history.
//
// WORLD RULE — *ashes keep a memory. Crystal gives it form. Blood gives it a
// pulse.* A funeral here never finished. In the GHOST world its people replay
// what they were doing when it stopped; in the LIVING world their ashes wait
// in urns beside the things they were working. Dust + Spirit crystallize the
// ashes into the motion they remember, the crystal fits the mechanism, and
// Blood sends a pulse through it: the mechanism does the remembered act, and
// the ghost rests.
//
// THE TWO WORLDS: the past is the answer key, the present is broken. Every
// star needs a look at one and a change to the other. Nothing is timed and
// nothing is walked for accuracy; no reaction is left to chance.
//
//     memorial ── bell_court ── bearers_court ── vigil_chapel ── wraithord_vigil
//     (entrance)   (Star 1,       (Star 2)    ╲     (the rite)       (Star 3)
//                   the niche)                 quiet_alcove (the maxim)

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

// ─────────────────────────────────────────────────────────
// THE TWO WORLDS
// ─────────────────────────────────────────────────────────

/// Which world the party is standing in. The same rooms, the same things in
/// the same places — the past, with its people at work, or the present.
enum FuneralWorld { living, ghost }

FuneralWorld otherFuneralWorld(FuneralWorld w) =>
    w == FuneralWorld.living ? FuneralWorld.ghost : FuneralWorld.living;

// ─────────────────────────────────────────────────────────
// THE LOOP — urns, crystals, sockets
// ─────────────────────────────────────────────────────────

/// The two elements that crystallize ashes. Dungeon recipe table:
/// **Dust + Spirit → Crystal**, and it works every time.
const List<String> kFuneralCrystalPair = ['Dust', 'Spirit'];

/// True when [elements] (the bodies standing at an urn) hold the pair. A
/// third body never spoils it.
bool funeralPairReady(Iterable<String> elements) {
  final have = elements.toSet();
  return have.contains('Dust') &&
      have.contains('Spirit') &&
      dungeonRecipeResult('Dust', 'Spirit') == 'Crystal';
}

/// An urn of somebody's ashes and the socket its crystal belongs in.
class FuneralUrn {
  final String id;

  /// Whose ashes: shown in the crystal and on the chart.
  final String whose;

  /// The socket this memory fits, and only this one.
  final String socketId;

  const FuneralUrn({
    required this.id,
    required this.whose,
    required this.socketId,
  });
}

const List<FuneralUrn> kFuneralUrns = [
  FuneralUrn(id: 'urn_keeper', whose: 'the keeper', socketId: 'sk_treadle'),
  FuneralUrn(id: 'urn_bearers', whose: 'the bearers', socketId: 'sk_doorstep'),
  FuneralUrn(id: 'urn_mourners', whose: 'the mourners', socketId: 'sk_bier'),
  // THE EMPTY URN — the maxim. Nobody's ashes are in it until yours are.
  FuneralUrn(id: 'urn_empty', whose: 'yours', socketId: 'sk_name'),
];

FuneralUrn? funeralUrnById(String id) {
  for (final u in kFuneralUrns) {
    if (u.id == id) return u;
  }
  return null;
}

// ─────────────────────────────────────────────────────────
// STAR 2 — THE BEARERS' FLAGS
// ─────────────────────────────────────────────────────────

/// The court is three flags by three: column 0..2 west→east, row 0..2
/// north→south, index = row * 3 + column.
const int kBearerCols = 3;

/// The bearers' route in the past: four flags, two turns. They come in off
/// the west doorstep onto (0,1), go east to (1,1), north to (1,0), east to
/// (2,0), and out of the court's east door to the chapel.
const List<int> kBearerRoute = [3, 4, 1, 2];

/// THE BEAMS in the present (2026-09-28, deepened): a carved beam under the
/// floor joins two flags, and pressing a flag flips it AND every flag its
/// beams run to. Both pairs of the route are tied — (3,4) and (1,2) — so the
/// route can never be laid by pressing route flags alone: an off-route flag
/// whose beam reaches into one of them is the only way to break a tie. Flag 0
/// reaches both; flag 5 reaches (1,2) alone; (6,7) is a beam that goes
/// nowhere useful. Two shortest solutions from the start, three presses
/// each, and copying the route (pressing its tipped flags) always fails.
/// Proved exhaustively in planet_dungeon_spirit_funeral_test.dart.
const List<(int, int)> kBearerBeams = [
  (0, 1),
  (0, 3),
  (1, 2),
  (2, 5),
  (3, 4),
  (6, 7),
];

/// How the court lies when the run begins: one route flag level, three
/// tipped; the off-route flags as time left them.
const Set<int> kBearerStartLevel = {3, 6, 8};

/// Every flag a press on [flag] flips besides itself.
List<int> bearerLinked(int flag) => [
  for (final (a, b) in kBearerBeams)
    if (a == flag) b else if (b == flag) a,
];

/// The fewest presses that lay the route from [level], or null if none do.
/// Pure and small (512 press-sets): the tests and nothing else use it.
List<int>? bearerSolveFrom(Set<int> level) {
  const n = kBearerCols * kBearerCols;
  List<int>? best;
  for (var x = 0; x < 1 << n; x++) {
    final presses = [
      for (var f = 0; f < n; f++)
        if (x >> f & 1 == 1) f,
    ];
    if (best != null && presses.length >= best.length) continue;
    final flags = BearerFlags()
      ..level.clear()
      ..level.addAll(level);
    for (final f in presses) {
      flags.press(f);
    }
    if (flags.routeClear) best = presses;
  }
  return best;
}

/// The present's flags. Pure: the engine, the renderer and the tests all ask
/// this one object.
class BearerFlags {
  final Set<int> level = {...kBearerStartLevel};

  void reset() {
    level
      ..clear()
      ..addAll(kBearerStartLevel);
  }

  bool isLevel(int f) => level.contains(f);

  /// Press a flag: it flips, and so does every flag its beams run to.
  void press(int f) {
    for (final g in [f, ...bearerLinked(f)]) {
      if (!level.remove(g)) level.add(g);
    }
  }

  /// The first flag on the route that is tipped, or null when the whole
  /// remembered route lies level.
  int? get firstTipped {
    for (final f in kBearerRoute) {
      if (!level.contains(f)) return f;
    }
    return null;
  }

  bool get routeClear => firstTipped == null;

  /// How many of the route's flags are tipped (the third hint tier).
  int get tippedOnRoute => kBearerRoute.where((f) => !level.contains(f)).length;

  /// Lay the route level (a banked star restores the finished court).
  void settle() => level.addAll(kBearerRoute);
}

// ─────────────────────────────────────────────────────────
// THE RITE — THE MOURNERS' STONES
// ─────────────────────────────────────────────────────────

/// The five kneeling stones round the bier, and which mourner knelt at which
/// in the past. Each mourner glows its element's color, and only that
/// element may take its place: the rite reads WHO knelt where, not just
/// where — sixty ways to place three, and one of them is the funeral.
const Map<int, String> kMournerAt = {0: 'Dust', 2: 'Blood', 3: 'Spirit'};

/// The stones the mourners used.
Set<int> get kMournerStones => kMournerAt.keys.toSet();

/// THE MAXIM'S SIX KNEELERS, round the empty urn. The west one (index 3)
/// is the one in front of the alcove's memorial stone.
const List<Offset> kAlcoveKneelers = [
  Offset(490, 320),
  Offset(425, 408),
  Offset(295, 408),
  Offset(228, 320),
  Offset(295, 232),
  Offset(425, 232),
];

/// Which of [kneelers] are held, by living bodies at [living] or by echoes
/// at [echoes], within [reach]. A kneeler held twice counts once.
Set<int> kneelersHeld(
  List<Offset> kneelers,
  Iterable<Offset> living,
  Iterable<Offset> echoes, {
  double reach = 44,
}) => {
  for (var i = 0; i < kneelers.length; i++)
    if ([...living, ...echoes].any((p) => (p - kneelers[i]).distance <= reach))
      i,
};

/// Given the stone each of the party kneels at (null = none) and its
/// element, how many are not where THEIR mourner knelt? Zero, with all three
/// placed, is the rite.
int mournersMisplaced(List<(int?, String)> kneeling) {
  var wrong = 0;
  for (final (s, element) in kneeling) {
    if (s == null || kMournerAt[s] != element) wrong++;
  }
  return wrong;
}

// ─────────────────────────────────────────────────────────
// THE RUN
// ─────────────────────────────────────────────────────────

/// Everything one Requia run decides. Pure; the engine owns the clocks.
class FuneralRun {
  FuneralWorld world = FuneralWorld.living;

  /// Urns whose crystal has been made (it stays made for the run).
  final Set<String> crystals = {};

  /// The crystal the party is carrying, or null. One at a time; switching
  /// creatures never drops it.
  String? held;

  /// Sockets with their crystal in.
  final Set<String> fitted = {};

  /// Star 1: the bell has rung and the keeper rests.
  bool bellRung = false;

  /// Star 2's court, and whether the bier has reached the chapel.
  final BearerFlags flags = BearerFlags();
  bool bierArrived = false;

  /// The rite: the mourners have carried the bier through.
  bool riteDone = false;

  /// The vault: the keeper's niche has been cleared of dust.
  bool nicheCleared = false;

  /// THE MAXIM — the alcove's recorded past. Every other room's past is
  /// somebody else's; the quiet alcove's is empty, so it keeps YOURS: each
  /// time Spirit passes into the past there, where the party stands is kept
  /// as kneeling echoes (position and element), replacing the last record.
  final List<(Offset, String)> echoes = [];

  /// The empty urn has filled — with your ashes — once all six of its
  /// kneelers were held at once.
  bool urnFilled = false;

  int passings = 0;

  bool get isGhost => world == FuneralWorld.ghost;

  void reset() {
    world = FuneralWorld.living;
    crystals.clear();
    held = null;
    fitted.clear();
    bellRung = false;
    flags.reset();
    bierArrived = false;
    riteDone = false;
    nicheCleared = false;
    echoes.clear();
    urnFilled = false;
    passings = 0;
  }

  void passOver() {
    world = otherFuneralWorld(world);
    passings++;
  }

  /// Can this urn be crystallized now? Made crystals never are again; the
  /// empty urn has nothing in it until the six-fold vigil fills it.
  bool canCrystallize(String urnId) {
    if (crystals.contains(urnId)) return false;
    if (urnId == 'urn_empty') return urnFilled;
    return true;
  }

  /// A crystal sits at its urn when it is made, not carried and not fitted.
  bool crystalAtUrn(String urnId) {
    final u = funeralUrnById(urnId);
    if (u == null || !crystals.contains(urnId)) return false;
    return held != urnId && !fitted.contains(u.socketId);
  }
}

// ─────────────────────────────────────────────────────────
// PER-ROOM CONTENT
// ─────────────────────────────────────────────────────────

/// A socket in a room: where a crystal fits and where Blood pulses it.
class FuneralSocket {
  final String id;
  final Offset at;
  const FuneralSocket(this.id, this.at);
}

/// Everything the Unfinished Funeral puts in one room. ONE field on the
/// shared room model, as every planet since Ice has done.
class FuneralRoom {
  /// The star this room banks (null = none).
  final int? starIndex;

  /// Where Spirit passes the party between the two worlds.
  final Offset? memorialStone;

  /// The entry rite: grave-dust drifted up the arch.
  final Offset? drift;

  /// This room's urn (id and place).
  final String? urnId;
  final Offset? urn;

  final FuneralSocket? socket;

  /// STAR 1 — the bell court: the bell over the gate and the lever to it.
  final Offset? bell;

  /// The vault: the keeper's niche in the west wall.
  final Offset? niche;

  /// STAR 2 — the court of nine flags: its north-west corner and one flag's
  /// size, and the west doorstep the bier starts from.
  final Offset? flagOrigin;
  final double flagSize;
  final Offset? doorstep;

  /// The court's way out to the chapel, where the bier ends.
  final Offset? chapelDoor;

  /// THE RITE — the bier and its five kneeling stones.
  final Offset? bier;
  final List<Offset> stones;

  /// STAR 3 — the vigil chime.
  final Offset? chime;

  /// THE MAXIM — the uncut name stone.
  final Offset? nameStone;

  const FuneralRoom({
    this.starIndex,
    this.memorialStone,
    this.drift,
    this.urnId,
    this.urn,
    this.socket,
    this.bell,
    this.niche,
    this.flagOrigin,
    this.flagSize = 130,
    this.doorstep,
    this.chapelDoor,
    this.bier,
    this.stones = const [],
    this.chime,
    this.nameStone,
  });

  bool get rite => bier != null;

  /// The centre of flag [f] in the bearers' court.
  Offset flagCentre(int f) {
    final o = flagOrigin!;
    return o +
        Offset(
          (f % kBearerCols + 0.5) * flagSize,
          (f ~/ kBearerCols + 0.5) * flagSize,
        );
  }

  Rect flagRect(int f) =>
      Rect.fromCenter(center: flagCentre(f), width: flagSize, height: flagSize);

  /// The bearers' remembered route as points: the doorstep, the four flags,
  /// and the chapel door.
  List<Offset> get bearerPath => [
    doorstep!,
    for (final f in kBearerRoute) flagCentre(f),
    chapelDoor!,
  ];
}

// ─────────────────────────────────────────────────────────
// COPY
// ─────────────────────────────────────────────────────────

/// Requia's lost maxim — THE EMPTY URN. A new id: the Undug Grave was a
/// different secret, and a player who found it has not found this.
const String kSpiritEmptyUrnEggId = 'egg:spirit_empty_urn';

// ─────────────────────────────────────────────────────────
// THE LAYOUT
// ─────────────────────────────────────────────────────────

const Offset _kBellGateSpawn = Offset(500, 620);

/// Requia — the Unfinished Funeral.
const DungeonLayout spiritLayout = DungeonLayout(
  element: 'Spirit',
  entranceRoomId: 'memorial',
  entranceSpawn: Offset(380, 420),
  title: 'THE UNFINISHED FUNERAL',
  descentTitle: 'Requia Unfinished Funeral',
  stars: [
    DungeonStarSpec(
      name: 'Bell Star',
      earnAnnouncement: 'The Bell Star is yours. The keeper rests',
    ),
    DungeonStarSpec(
      name: 'Bearers Star',
      earnAnnouncement:
          'The Bearers Star is yours. The bier reaches the chapel',
    ),
    DungeonStarSpec(name: 'Vigil Star'),
  ],
  // The memorial's arch is drifted shut with grave-dust until Dust shifts it.
  entranceRevealDoor: DungeonDoorRef('memorial', 'bell_court'),
  finaleDoor: DungeonDoorRef('vigil_chapel', 'wraithord_vigil'),
  riteAnnouncement:
      'Bell and Bearers are won. The mourners are waiting in the chapel',
  riteWakeLine:
      'The mourners carry the bier through. Wraithord is waiting at the vigil',
  finaleSealedHint:
      'The vigil door stays shut until you have the Bell and Bearers stars',
  guardianSealedHint: 'The bier has not been carried through',
  mercyShrineRoomId: 'memorial',
  // Ideal: Spiritmask · Bloodpip · Dustwing. The riddle names a family only
  // where a gate asks for one (dungeon_riddle_naming_test).
  riddle: [
    'Send me Spirit, to call back what the ashes remember;',
    'a Blood Pip, for the last chime\'s channel is finer than a vein;',
    'and Dust, for every one of them has gone to dust.',
  ],
  // No recipes here, nor in any hint: which bodies make a crystal is the
  // planet's discovery.
  primer: [
    'A funeral here never finished.',
    'Its people still replay it in the world of the dead.',
  ],
  // §4 budget: ONE hard gate, on Star 3. Stars 1 and 2 are element-only, so
  // any Spirit/Blood/Dust trio can take them on a first descent.
  familyGates: [
    DungeonFamilyGate(
      objectId: 'vigil_chime',
      element: 'Blood',
      family: 'Pip',
      hintLine: 'Only a Blood Pip can ring a channel this fine',
    ),
  ],
  rooms: {
    // ── THE MEMORIAL (entrance · mercy shrine) ────────────
    'memorial': DungeonRoom(
      id: 'memorial',
      bounds: Rect.fromLTWH(0, 0, 760, 520),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(325, 0, 110, 24),
          targetRoomId: 'bell_court',
          targetSpawn: _kBellGateSpawn,
        ),
      ],
      funeral: FuneralRoom(
        memorialStone: Offset(200, 330),
        drift: Offset(380, 70),
      ),
    ),

    // ── THE BELL COURT (Star 1 · the keeper's niche) ──────
    'bell_court': DungeonRoom(
      id: 'bell_court',
      bounds: Rect.fromLTWH(0, 0, 900, 680),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 656, 110, 24),
          targetRoomId: 'memorial',
          targetSpawn: Offset(380, 80),
        ),
        // THE FUNERAL GATE, under the bell. Shut until the bell rings.
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'bearers_court',
          targetSpawn: Offset(500, 620),
        ),
      ],
      vaultCache: Offset(70, 300),
      funeral: FuneralRoom(
        starIndex: 0,
        memorialStone: Offset(200, 520),
        urnId: 'urn_keeper',
        urn: Offset(720, 360),
        socket: FuneralSocket('sk_treadle', Offset(610, 250)),
        bell: Offset(450, 96),
        niche: Offset(40, 300),
      ),
    ),

    // ── THE BEARERS' COURT (Star 2) ───────────────────────
    'bearers_court': DungeonRoom(
      id: 'bearers_court',
      bounds: Rect.fromLTWH(0, 0, 1000, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(445, 676, 110, 24),
          targetRoomId: 'bell_court',
          targetSpawn: Offset(450, 80),
        ),
        // The chapel door, where the bearers' walk ends. Shut until then.
        DungeonDoor(
          rect: Rect.fromLTWH(976, 160, 24, 110),
          targetRoomId: 'vigil_chapel',
          targetSpawn: Offset(80, 320),
        ),
        // The quiet alcove: a dead end nobody's funeral uses.
        DungeonDoor(
          rect: Rect.fromLTWH(0, 560, 24, 110),
          targetRoomId: 'quiet_alcove',
          targetSpawn: Offset(680, 280),
        ),
      ],
      funeral: FuneralRoom(
        starIndex: 1,
        memorialStone: Offset(780, 600),
        urnId: 'urn_bearers',
        urn: Offset(150, 470),
        socket: FuneralSocket('sk_doorstep', Offset(230, 345)),
        flagOrigin: Offset(320, 150),
        doorstep: Offset(230, 345),
        chapelDoor: Offset(940, 215),
      ),
    ),

    // ── THE QUIET ALCOVE (the Lost Maxim) ─────────────────
    // The only past on the planet with nobody in it — so it keeps yours.
    // Six kneelers ring the empty urn; the party is three. The memorial
    // stone stands right behind the west kneeler, so Spirit passing over is
    // always kneeling there when its echo is kept.
    'quiet_alcove': DungeonRoom(
      id: 'quiet_alcove',
      bounds: Rect.fromLTWH(0, 0, 760, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(736, 225, 24, 110),
          targetRoomId: 'bearers_court',
          targetSpawn: Offset(80, 615),
        ),
      ],
      funeral: FuneralRoom(
        memorialStone: Offset(146, 320),
        urnId: 'urn_empty',
        urn: Offset(360, 320),
        socket: FuneralSocket('sk_name', Offset(360, 186)),
        nameStone: Offset(360, 100),
        stones: kAlcoveKneelers,
      ),
    ),

    // ── THE VIGIL CHAPEL (the rite) ───────────────────────
    'vigil_chapel': DungeonRoom(
      id: 'vigil_chapel',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      walls: [
        Rect.fromLTWH(380, 290, 140, 40), // the bier on its trestles
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 265, 24, 110),
          targetRoomId: 'bearers_court',
          targetSpawn: Offset(900, 215),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'wraithord_vigil',
          targetSpawn: Offset(480, 620),
        ),
      ],
      funeral: FuneralRoom(
        memorialStone: Offset(760, 540),
        urnId: 'urn_mourners',
        urn: Offset(150, 520),
        socket: FuneralSocket('sk_bier', Offset(450, 262)),
        bier: Offset(450, 310),
        stones: [
          Offset(260, 220),
          Offset(270, 420),
          Offset(450, 470),
          Offset(630, 420),
          Offset(640, 220),
        ],
      ),
    ),

    // ── WRAITHORD'S VIGIL (Star 3) ────────────────────────
    // §7: the guardian fights WITH the planet's rule. Its shadow shields it;
    // a Blood pulse at the warm chime rings the remembered note and parts it.
    'wraithord_vigil': DungeonRoom(
      id: 'wraithord_vigil',
      bounds: Rect.fromLTWH(0, 0, 960, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(425, 676, 110, 24),
          targetRoomId: 'vigil_chapel',
          targetSpawn: Offset(450, 80),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(480, 290),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Spirit',
          mysticId: 'Wraithord',
        ),
      ),
      funeral: FuneralRoom(chime: Offset(190, 520)),
    ),
  },
);
