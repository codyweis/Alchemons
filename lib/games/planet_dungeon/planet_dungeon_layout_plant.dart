// lib/games/planet_dungeon/planet_dungeon_layout_plant.dart
//
// VERDANTHOS — THE CONSERVATORY. Plant's authored layout, its pure rules, and
// the puzzle DATA its `part of planet_dungeon_game.dart` module reasons about.
// Design: docs/dungeons.md §9.20 (2026-09-27; supersedes the Verdant Crypt).
//
//     ── the Conservatory ─────────────────────────────
//                    botanica_heart          (Star 3)
//                          ╵ (sealed until the rite)
//                    rootbound_door          (the rite)
//                          ╵ (opens with the Bud Star)
//                    trellis_garden ··hatch·· root_cellar (vault)
//                          ╵ (the great plant opens it)
//        hothouse ── CONSERVATORY ── shadehouse
//                          ╵
//                       dry_bed
//
// WORLD RULE — *every plant here thrives in a different climate, and yours is
// the hand that makes it.* One verb runs the planet: the TENDING CIRCLE, a
// leaded-glass ring on the floor. Each creature standing in it lights its
// element's pane; with the right bodies inside, a press applies the climate
// they make. Water alone waters; Water + Spirit make Ice; Spirit + Crystal make
// Light. That is the whole vocabulary, and every room is one idea spoken in it.
//
// NOTHING HERE CAN STRAND. There are no one-way passages, no spent resources
// and no timers: watered soil and frozen crossings stay for the run, a healed
// wing stays healed, and every ring is reached by plain walking. The rite's
// sun-burst can thaw its frost bud, which costs one press to put back.
//
// This file is pure: the trellis's tendril rule, the rite's root lattice and the
// recipe table are plain functions over plain state, tested without the
// engine (test/planet_dungeon_plant_conservatory_test.dart).

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

/// Plant's lost maxim discovery id (the screen pays 20 gold on first find).
const String kPlantOppositeSeedEggId = 'egg:plant_opposite_seed';

// ─────────────────────────────────────────────────────────
// CLIMATES AND THEIR RECIPES
// ─────────────────────────────────────────────────────────

/// What is wrong with a room. Each has exactly one fix, and the fix is always
/// the same pair of hands wherever it is asked for.
enum Climate { dry, warm, dark }

/// The element that corrects [c].
String climateFix(Climate c) => switch (c) {
  Climate.dry => 'Water',
  Climate.warm => 'Ice',
  Climate.dark => 'Light',
};

/// The room's complaint, in plain words (§5.6).
String climateComplaint(Climate c) => switch (c) {
  Climate.dry => 'This room is too dry',
  Climate.warm => 'This room is too warm',
  Climate.dark => 'This room is too dark',
};

/// The adjective, for the arena's readout.
String climateWord(Climate c) => switch (c) {
  Climate.dry => 'DRY',
  Climate.warm => 'WARM',
  Climate.dark => 'DARK',
};

/// The bodies a tending circle needs for each product. Water is carried as
/// itself; Ice and Light are the game's own recipes (Spirit+Water → Ice,
/// Crystal+Spirit → Light — `planet_dungeon_verbs.dart`). Spirit sits in both,
/// and the rite is built on that.
const Map<String, List<String>> kTendRecipes = {
  'Water': ['Water'],
  'Ice': ['Water', 'Spirit'],
  'Light': ['Spirit', 'Crystal'],
};

/// Which of [product]'s bodies are missing from [present] (the elements of
/// every creature standing in the ring). Extra bodies never invalidate the
/// set, and a creature that IS the product counts on its own.
List<String> tendMissing(String product, Iterable<String> present) {
  final have = present.toSet();
  if (have.contains(product)) return const [];
  return [
    for (final e in kTendRecipes[product] ?? const <String>[])
      if (!have.contains(e)) e,
  ];
}

/// The element [a] and [b] make together, if the game has a recipe for it.
String? tendBraid(String a, String b) => dungeonRecipeResult(a, b);

/// A refused press says only that it did not take — never who is missing,
/// nor what the ring wants (the user, 2026-09-27: hints stay bare).
String tendMissingLine(String product, List<String> missing) =>
    missing.isEmpty ? '' : 'Not yet';

// ─────────────────────────────────────────────────────────
// THE TENDING CIRCLE
// ─────────────────────────────────────────────────────────

/// How far from its centre a body counts as standing IN a ring. Drawn at
/// [kTendRingDrawn]; the hit is a little wider, so standing on the lead reads
/// as in.
const double kTendRingReach = 66.0;
const double kTendRingDrawn = 58.0;

/// One tending circle: where it lies and the product it is set to make. A
/// ring with a null [product] (the arena's and the rite's twin ring) takes
/// whatever the bodies in it make.
class TendRing {
  final String id;
  final Offset at;
  final String? product;
  const TendRing({required this.id, required this.at, this.product});
}

/// A Star 1 wing: its complaint, its ring, and its wilted plant.
class ClimateWing {
  final Climate climate;
  final Offset ring;

  /// Where the plant stands, in its raised glass-rimmed planter.
  final Offset plant;

  /// Where this wing's door into the Conservatory is, in the HUB's space —
  /// the cutscene's mote flies in through it.
  final Offset hubDoor;
  const ClimateWing({
    required this.climate,
    required this.ring,
    required this.plant,
    required this.hubDoor,
  });
}

// ─────────────────────────────────────────────────────────
// STAR 2 — THE TRELLIS GARDEN
// ─────────────────────────────────────────────────────────
//
// One fork on a 7×5 board. Columns run west to east, rows north to south,
// zero-based. The root is (3,4) and enters the fork at (3,3). The west bed
// runs (2,3) to a stone-ended (1,3); the east bed runs (4,3), (5,3), north
// across the pond tile (5,2) to the bud's island (5,1). Lamps stand off the
// beds at (0,3) and (6,3), and each fork exit points straight at its lamp —
// there is no tie-break and no hidden pathfinding.

/// A board cell.
typedef TrellisCell = (int col, int row);

const int kTrellisCols = 7;
const int kTrellisRows = 5;
const double kTrellisTile = 92.0;
const Offset kTrellisOrigin = Offset(150, 120);

Offset trellisCellCentre(TrellisCell c) => Offset(
  kTrellisOrigin.dx + kTrellisTile * (c.$1 + 0.5),
  kTrellisOrigin.dy + kTrellisTile * (c.$2 + 0.5),
);

Rect trellisCellRect(TrellisCell c) => Rect.fromLTWH(
  kTrellisOrigin.dx + kTrellisTile * c.$1,
  kTrellisOrigin.dy + kTrellisTile * c.$2,
  kTrellisTile,
  kTrellisTile,
);

Rect get kTrellisBoard => Rect.fromLTWH(
  kTrellisOrigin.dx,
  kTrellisOrigin.dy,
  kTrellisTile * kTrellisCols,
  kTrellisTile * kTrellisRows,
);

const TrellisCell kTrellisRoot = (3, 4);
const TrellisCell kTrellisFork = (3, 3);
const List<TrellisCell> kTrellisWestBed = [(2, 3), (1, 3)];
const List<TrellisCell> kTrellisEastBed = [(4, 3), (5, 3), (5, 2), (5, 1)];
const TrellisCell kTrellisPondCrossing = (5, 2);
const TrellisCell kTrellisIsland = (5, 1);
const TrellisCell kTrellisWestLamp = (0, 3);
const TrellisCell kTrellisEastLamp = (6, 3);

/// The pond: the 3×3 block around the island. Only [kTrellisPondCrossing] is
/// on a bed; the rest is the water the island stands in.
bool trellisIsPond(TrellisCell c) =>
    c.$1 >= 4 && c.$1 <= 6 && c.$2 >= 0 && c.$2 <= 2 && c != kTrellisIsland;

/// The soil the one Water ring irrigates: the root approach and BOTH branches.
/// The island's own last tile is already moist.
const List<TrellisCell> kTrellisIrrigated = [
  (3, 4),
  (3, 3),
  (2, 3),
  (1, 3),
  (4, 3),
  (5, 3),
];

enum TrellisLamp { west, east }

/// Why a tendril stopped where it did. Every one is visible on the board.
enum TendrilStop {
  /// It reached the bud. The star.
  bud,

  /// The next tile is dry earth.
  dry,

  /// The next tile is open water.
  water,

  /// The bed ended in stone (the west branch).
  bedEnd,

  /// No lamp is lit, so it waits at the fork.
  noLight,
}

/// The garden as the player has set it up. Nothing here ever un-sets: soil
/// stays wet and the crossing stays frozen for the run. Only the lamp moves,
/// because lighting one draws the glow out of the other.
class TrellisState {
  bool watered = false;
  bool frozen = false;

  /// The east lamp starts lit (the user, 2026-09-27) — the light already
  /// points at the bud, and the west branch's dead end (and the vault under
  /// it) is found by choosing to light the other lamp.
  TrellisLamp? lit = TrellisLamp.east;

  void reset() {
    watered = false;
    frozen = false;
    lit = TrellisLamp.east;
  }
}

/// THE TENDRIL'S RULE, as a pure function: the tiles it will occupy, in
/// growth order starting at the root, and why it stops.
///
/// It follows the planted beds through WATERED soil; at the fork it takes the
/// branch toward the LIT lamp; it never crosses open water, though it crosses
/// ICE; it never backtracks or jumps between beds. The same function draws the
/// ghost and grows the real thing, so the preview cannot lie.
({List<TrellisCell> path, TendrilStop stop}) growTendril(TrellisState s) {
  bool moist(TrellisCell c) =>
      c == kTrellisIsland || (s.watered && kTrellisIrrigated.contains(c));
  final path = <TrellisCell>[];
  if (!moist(kTrellisRoot)) return (path: path, stop: TendrilStop.dry);
  path.add(kTrellisRoot);
  if (!moist(kTrellisFork)) return (path: path, stop: TendrilStop.dry);
  path.add(kTrellisFork);
  final branch = switch (s.lit) {
    TrellisLamp.west => kTrellisWestBed,
    TrellisLamp.east => kTrellisEastBed,
    null => null,
  };
  if (branch == null) return (path: path, stop: TendrilStop.noLight);
  for (final c in branch) {
    if (c == kTrellisPondCrossing) {
      if (!s.frozen) return (path: path, stop: TendrilStop.water);
    } else if (!moist(c)) {
      return (path: path, stop: TendrilStop.dry);
    }
    path.add(c);
  }
  return (
    path: path,
    stop: path.last == kTrellisIsland ? TendrilStop.bud : TendrilStop.bedEnd,
  );
}

/// The trellis garden's controls, all on its perimeter walkway.
const TendRing kTrellisWaterRing = TendRing(
  id: 'trellis_water',
  at: Offset(300, 668),
  product: 'Water',
);
const TendRing kTrellisIceRing = TendRing(
  id: 'trellis_ice',
  at: Offset(872, 258),
  product: 'Ice',
);
const TendRing kTrellisWestLightRing = TendRing(
  id: 'trellis_light_w',
  at: Offset(74, 442),
  product: 'Light',
);
const TendRing kTrellisEastLightRing = TendRing(
  id: 'trellis_light_e',
  at: Offset(872, 442),
  product: 'Light',
);
const List<TendRing> kTrellisRings = [
  kTrellisWaterRing,
  kTrellisIceRing,
  kTrellisWestLightRing,
  kTrellisEastLightRing,
];

/// Where the great plant's root comes in under the south wall: GROW and PULL
/// are pressed here.
const Offset kTrellisRootKnuckle = Offset(472, 628);

/// THE VAULT'S DOOR (the trick): the west bed's stone end is a lid. The
/// preview shows the west branch as a dead end — and for the TENDRIL it is.
/// Grow it all the way there and its tip prises the stone up, and under it are
/// steps down into the root cellar. The dead end is a dead end for the plant,
/// not for you.
Rect get kTrellisHatch => Rect.fromCenter(
  center: trellisCellCentre(kTrellisWestBed.last),
  width: 56,
  height: 56,
);

// ─────────────────────────────────────────────────────────
// THE RITE — THE ROOTBOUND DOOR
// ─────────────────────────────────────────────────────────
//
// Botanica's roots hang over the door from a knot: two roots, four tips, a
// bud at every joint. A tending ring under each tip feeds a climate in at it.
// The door opens when every bud matches the great plant's crown — which
// flowers, in this same shape, the moment the Bud Star bursts. The door
// itself never shows the target: the tree is the clue.
//
//                ( K )             the knot
//               /     \
//           ( A )     ( B )
//           /   \     /   \
//        (C)   (D)  (E)   (F)      tips — a ring under each
//
// THE THREE RULES, shown by animation and never stated:
//  · WATER poured at a tip RISES up that root toward the knot. It douses a
//    lit bud and stops at a frozen one — ice is a dam.
//  · FROST crawls through WET buds in every direction, across into the other
//    root too. On a dry bud it freezes that bud alone; it cannot take on a
//    lit one.
//  · LIGHT climbs DRY bark from its tip upward, lighting it, and stops at
//    wet. It thaws the first frozen bud it meets, and only that one.
//
// The target (7 moves at best — test/planet_dungeon_plant_conservatory_test)
// asks for three ideas that each contradict an instinct: the knot can only be
// frozen by wetting a path to it and freezing from below; that freezes the
// whole way up, so you thaw your way back down one bud per climb; and the
// frozen knot then dams the water that re-wets A. Most states cannot reach
// the target any more, so the stump PRUNES the roots bare, free, forever.

enum RootState { dry, wet, frozen, lit }

/// The lattice's buds, knot first.
const List<String> kRootNodes = ['K', 'A', 'B', 'C', 'D', 'E', 'F'];

/// Each bud's parent (toward the knot).
const Map<String, String> kRootParent = {
  'A': 'K',
  'B': 'K',
  'C': 'A',
  'D': 'A',
  'E': 'B',
  'F': 'B',
};

const List<String> kRootTips = ['C', 'D', 'E', 'F'];

/// What the great plant's crown shows, and so what the door wants.
const Map<String, RootState> kRootTarget = {
  'K': RootState.frozen,
  'A': RootState.wet,
  'B': RootState.lit,
  'C': RootState.wet,
  'D': RootState.wet,
  'E': RootState.lit,
  'F': RootState.lit,
};

/// Where each bud hangs in the rite room.
const Map<String, Offset> kRootAt = {
  'K': Offset(450, 118),
  'A': Offset(290, 205),
  'B': Offset(610, 205),
  'C': Offset(210, 320),
  'D': Offset(370, 320),
  'E': Offset(530, 320),
  'F': Offset(690, 320),
};

/// The ring under each tip, in a row under the door.
const Map<String, TendRing> kRootRings = {
  'C': TendRing(id: 'root_C', at: Offset(210, 462)),
  'D': TendRing(id: 'root_D', at: Offset(370, 462)),
  'E': TendRing(id: 'root_E', at: Offset(530, 462)),
  'F': TendRing(id: 'root_F', at: Offset(690, 462)),
};

/// The stump: PRUNE sheds every climate off the roots, free, as often as you
/// like.
const Offset kRootStump = Offset(90, 560);

/// A tip up to the knot, inclusive.
List<String> rootPath(String tip) {
  final out = [tip];
  while (kRootParent[out.last] != null) {
    out.add(kRootParent[out.last]!);
  }
  return out;
}

Iterable<String> rootNeighbours(String n) sync* {
  final p = kRootParent[n];
  if (p != null) yield p;
  for (final e in kRootParent.entries) {
    if (e.value == n) yield e.key;
  }
}

/// What a ring's bodies make, or null when they make nothing; [both] when
/// they make Light and Ice at once, which the ring refuses.
({String? product, bool both}) ringProduct(Iterable<String> present) {
  final light = tendMissing('Light', present).isEmpty;
  final ice = tendMissing('Ice', present).isEmpty;
  if (light && ice) return (product: null, both: true);
  if (light) return (product: 'Light', both: false);
  if (ice) return (product: 'Ice', both: false);
  if (tendMissing('Water', present).isEmpty) {
    return (product: 'Water', both: false);
  }
  return (product: null, both: false);
}

/// The door's roots.
class RootLattice {
  final Map<String, RootState> state = {
    for (final n in kRootNodes) n: RootState.dry,
  };

  void reset() {
    for (final n in kRootNodes) {
      state[n] = RootState.dry;
    }
  }

  bool get bare => state.values.every((s) => s == RootState.dry);

  bool get matches => kRootNodes.every((n) => state[n] == kRootTarget[n]);

  void setAll(Map<String, RootState> to) => state.addAll(to);

  /// What feeding [product] in at [tip] WOULD do: the buds it changes, in
  /// the order it reaches them, each with its new state. Empty = nothing
  /// takes. Never mutates — the ghost and the press share it.
  List<(String, RootState)> preview(String tip, String product) {
    final s = Map.of(state);
    final out = <(String, RootState)>[];
    void set(String n, RootState to) {
      if (s[n] == to) return;
      s[n] = to;
      out.add((n, to));
    }

    switch (product) {
      case 'Water':
        for (final n in rootPath(tip)) {
          if (s[n] == RootState.frozen) break;
          set(n, RootState.wet);
        }
      case 'Light':
        for (final n in rootPath(tip)) {
          final at = s[n]!;
          if (at == RootState.wet) break;
          if (at == RootState.frozen) {
            set(n, RootState.wet);
            break;
          }
          set(n, RootState.lit);
        }
      case 'Ice':
        final at = s[tip]!;
        if (at == RootState.dry) {
          set(tip, RootState.frozen);
        } else if (at == RootState.wet) {
          final seen = {tip};
          final q = [tip];
          while (q.isNotEmpty) {
            final n = q.removeAt(0);
            set(n, RootState.frozen);
            for (final m in rootNeighbours(n)) {
              if (!seen.contains(m) && s[m] == RootState.wet) {
                seen.add(m);
                q.add(m);
              }
            }
          }
        }
    }
    return out;
  }

  /// Feed [product] in at [tip]. Returns what changed (empty = nothing took).
  List<(String, RootState)> apply(String tip, String product) {
    final out = preview(tip, product);
    for (final (n, to) in out) {
      state[n] = to;
    }
    return out;
  }
}

// ─────────────────────────────────────────────────────────
// THE LOST MAXIM — THE SEED THAT WANTED THE OPPOSITE
// ─────────────────────────────────────────────────────────

/// One channel from the great plant to the grey seed: what it carries, and
/// the creature whose element draws it back.
enum SeedChannel { moisture, light, frost }

String seedChannelElement(SeedChannel c) => switch (c) {
  SeedChannel.moisture => 'Water',
  SeedChannel.light => 'Crystal',
  SeedChannel.frost => 'Spirit',
};

SeedChannel? seedChannelFor(String element) {
  for (final c in SeedChannel.values) {
    if (seedChannelElement(c) == element) return c;
  }
  return null;
}

// ─────────────────────────────────────────────────────────
// THE RUN STATE
// ─────────────────────────────────────────────────────────

/// Everything the Conservatory remembers during a run. Plain state: every
/// change is made by the module (planet_dungeon_game_plant.dart), and every
/// picture eases toward it (planet_dungeon_game_plant_art.dart).
class Conservatory {
  /// Star 1: the wings whose plant has bloomed.
  final Set<Climate> healed = {};

  /// Star 2: the garden as set up, and whether the tendril is grown.
  final TrellisState trellis = TrellisState();
  bool grown = false;

  /// The west bed's stone, prised up by a tendril that went all the way
  /// there. Stays up for the run once it is up.
  bool hatchOpen = false;

  /// The rite: the door's roots, and whether they have let go.
  final RootLattice roots = RootLattice();
  bool rootsOpen = false;

  /// Botanica's arena: the climate it has made (null = none held).
  Climate? arena;

  /// The last climate it made, so the next strike makes a different one.
  Climate? lastArena;

  /// The maxim: the channels drawn back from the grey seed.
  final Set<SeedChannel> drawn = {};

  bool get wingsHealed => healed.length == Climate.values.length;

  void reset() {
    healed.clear();
    trellis.reset();
    grown = false;
    hatchOpen = false;
    roots.reset();
    rootsOpen = false;
    arena = null;
    lastArena = null;
    drawn.clear();
  }
}

// ─────────────────────────────────────────────────────────
// THE PER-ROOM PAYLOAD
// ─────────────────────────────────────────────────────────

/// Everything the Conservatory puts in one room. Carried on `DungeonRoom.grove`
/// so exactly one field serves the shared room model, and so a room's star
/// index is visible to the layout invariants.
class ConservatoryPlot {
  /// The star this room banks (null = none).
  final int? starIndex;

  /// A Star 1 wing.
  final ClimateWing? wing;

  /// The hub: the great central planter, and the fourth, empty one the grey
  /// seed falls into.
  final Offset? greatPlanter;
  final Offset? seedPlanter;

  /// True in the Trellis Garden (the board itself is authored above).
  final bool trellis;

  /// True at the Rootbound Door.
  final bool rite;

  /// Botanica's arena: its two equivalent tending circles.
  final List<Offset> arenaRings;

  const ConservatoryPlot({
    this.starIndex,
    this.wing,
    this.greatPlanter,
    this.seedPlanter,
    this.trellis = false,
    this.rite = false,
    this.arenaRings = const [],
  });
}

/// The wings, by room id.
const Map<String, String> kConservatoryWingRooms = {
  'dry_bed': 'dry',
  'hothouse': 'warm',
  'shadehouse': 'dark',
};

// ─────────────────────────────────────────────────────────
// THE LAYOUT
// ─────────────────────────────────────────────────────────

const Offset _kHubPlanter = Offset(520, 360);

/// Verdanthos — the Conservatory.
const DungeonLayout plantLayout = DungeonLayout(
  element: 'Plant',
  entranceRoomId: 'conservatory',
  entranceSpawn: Offset(330, 610),
  title: 'THE CONSERVATORY',
  descentTitle: 'Verdanthos Conservatory',
  stars: [
    DungeonStarSpec(
      name: 'Bloom Star',
      // The cutscene says it: three motes, one great plant, and its roots
      // prising the north door. No line would add anything.
      revealDoors: [
        DungeonDoorRef('conservatory', 'trellis_garden'),
        DungeonDoorRef('trellis_garden', 'conservatory'),
      ],
    ),
    DungeonStarSpec(
      name: 'Bud Star',
      // No line: the bud's opening and the crown's flowering say it.
      revealDoors: [
        DungeonDoorRef('trellis_garden', 'rootbound_door'),
        DungeonDoorRef('rootbound_door', 'trellis_garden'),
      ],
    ),
    DungeonStarSpec(name: 'Heart Star'),
  ],
  finaleDoor: DungeonDoorRef('rootbound_door', 'botanica_heart'),
  // TRUE lines only (the hint audit): the engine speaks this when the second
  // star lands, and the rite room is exactly one door on from there.
  riteAnnouncement:
      'Bloom and Bud are won. North of the trellis, roots hold the door to '
      'Botanica shut',
  riteWakeLine: 'The roots match the crown. They let go, and Botanica is awake',
  finaleSealedHint:
      'The roots hold this door until you have the Bloom and Bud stars',
  guardianSealedHint: 'The roots are knotted over the door',
  mercyShrineRoomId: 'conservatory',
  // Ideal: Crystal Mask · Spirit Kin · Water Mane — hinted by VERB (§4): the
  // sight that focuses light, the hand that tends, and the water that runs
  // where its bearer has gone.
  riddle: [
    'Send me a Crystal Mask: my roots take no light that is not focused;',
    'Spirit that tends, for my rooms have gone too long untended;',
    'and Water that runs where it goes, for everything here is thirsty.',
  ],
  // No recipes here, nor in any hint (the user, 2026-09-27): which bodies
  // make Ice or Light is the planet's discovery.
  primer: ['Every plant here wants a different climate.'],
  // §4 budget: ONE hard gate, on the rite (light fed to the door's roots). Stars 1 and 2 are
  // element-only, so any Crystal/Spirit/Water trio can progress on a first
  // descent.
  familyGates: [
    DungeonFamilyGate(
      objectId: 'root_light',
      element: 'Crystal',
      family: 'Mask',
      hintLine: 'Only a Crystal Mask can focus the light',
    ),
  ],
  rooms: {
    // ── THE CONSERVATORY (entrance, hub, mercy shrine) ────
    // A domed glasshouse gone grey. A great empty planter in the middle, a
    // fourth small planter by the east wall, and three wings off it.
    'conservatory': DungeonRoom(
      id: 'conservatory',
      bounds: Rect.fromLTWH(0, 0, 1040, 760),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(465, 0, 110, 24),
          targetRoomId: 'trellis_garden',
          targetSpawn: Offset(472, 720),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 325, 24, 110),
          targetRoomId: 'hothouse',
          targetSpawn: Offset(760, 270),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(1016, 325, 24, 110),
          targetRoomId: 'shadehouse',
          targetSpawn: Offset(60, 270),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(465, 736, 110, 24),
          targetRoomId: 'dry_bed',
          targetSpawn: Offset(410, 72),
        ),
      ],
      // Star 1 banks here, on the bind, whichever wing was healed last.
      grove: ConservatoryPlot(
        starIndex: 0,
        greatPlanter: _kHubPlanter,
        seedPlanter: Offset(840, 600),
      ),
    ),

    // ── THE DRY BED (Water) ───────────────────────────────
    // The gentle wing that teaches the circle: one body, one press.
    'dry_bed': DungeonRoom(
      id: 'dry_bed',
      bounds: Rect.fromLTWH(0, 0, 820, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(355, 0, 110, 24),
          targetRoomId: 'conservatory',
          targetSpawn: Offset(520, 690),
        ),
      ],
      grove: ConservatoryPlot(
        wing: ClimateWing(
          climate: Climate.dry,
          ring: Offset(410, 350),
          plant: Offset(410, 190),
          hubDoor: Offset(520, 748),
        ),
      ),
    ),

    // ── THE HOTHOUSE (Ice) ────────────────────────────────
    'hothouse': DungeonRoom(
      id: 'hothouse',
      bounds: Rect.fromLTWH(0, 0, 820, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(796, 215, 24, 110),
          targetRoomId: 'conservatory',
          targetSpawn: Offset(70, 380),
        ),
      ],
      grove: ConservatoryPlot(
        wing: ClimateWing(
          climate: Climate.warm,
          ring: Offset(370, 350),
          plant: Offset(370, 190),
          hubDoor: Offset(12, 380),
        ),
      ),
    ),

    // ── THE SHADEHOUSE (Light) ────────────────────────────
    'shadehouse': DungeonRoom(
      id: 'shadehouse',
      bounds: Rect.fromLTWH(0, 0, 820, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 215, 24, 110),
          targetRoomId: 'conservatory',
          targetSpawn: Offset(970, 380),
        ),
      ],
      grove: ConservatoryPlot(
        wing: ClimateWing(
          climate: Climate.dark,
          ring: Offset(450, 350),
          plant: Offset(450, 190),
          hubDoor: Offset(1028, 380),
        ),
      ),
    ),

    // ── THE TRELLIS GARDEN (Star 2) ───────────────────────
    // The fork, the pond and the bud, all on one screen's worth of board, and
    // a walkway round it that reaches every ring without the tendril.
    'trellis_garden': DungeonRoom(
      id: 'trellis_garden',
      bounds: Rect.fromLTWH(0, 0, 944, 780),
      walls: [
        // The pond, with the island standing in it (the tendril is the only
        // thing that ever crosses).
        Rect.fromLTWH(518, 120, 276, 276),
        // The two lamp standards.
        Rect.fromLTWH(182, 428, 28, 28),
        Rect.fromLTWH(734, 428, 28, 28),
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(417, 756, 110, 24),
          targetRoomId: 'conservatory',
          targetSpawn: Offset(520, 70),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(380, 0, 110, 24),
          targetRoomId: 'rootbound_door',
          targetSpawn: Offset(450, 570),
        ),
        // The stair under the west bed's stone (hidden until prised).
        DungeonDoor(
          rect: Rect.fromLTWH(260, 414, 56, 56),
          targetRoomId: 'root_cellar',
          targetSpawn: Offset(210, 190),
          chromeless: true,
        ),
      ],
      grove: ConservatoryPlot(starIndex: 1, trellis: true),
    ),

    // ── THE ROOT CELLAR (the vault) ───────────────────────
    'root_cellar': DungeonRoom(
      id: 'root_cellar',
      bounds: Rect.fromLTWH(0, 0, 560, 380),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(62, 162, 56, 56),
          targetRoomId: 'trellis_garden',
          targetSpawn: Offset(288, 540),
          chromeless: true,
        ),
      ],
      vaultCache: Offset(420, 190),
      grove: ConservatoryPlot(),
    ),

    // ── THE ROOTBOUND DOOR (the rite) ─────────────────────
    'rootbound_door': DungeonRoom(
      id: 'rootbound_door',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 616, 110, 24),
          targetRoomId: 'trellis_garden',
          targetSpawn: Offset(435, 72),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'botanica_heart',
          targetSpawn: Offset(480, 620),
        ),
      ],
      grove: ConservatoryPlot(rite: true),
    ),

    // ── BOTANICA'S HEART (Star 3) ─────────────────────────
    // §7: the guardian fights WITH the planet's rule. Each strike wrecks the
    // arena's climate, and its lull opens only once the climate is fixed.
    'botanica_heart': DungeonRoom(
      id: 'botanica_heart',
      bounds: Rect.fromLTWH(0, 0, 960, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(425, 676, 110, 24),
          targetRoomId: 'rootbound_door',
          targetSpawn: Offset(450, 80),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(480, 290),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Plant',
          mysticId: 'Botanica',
        ),
      ),
      grove: ConservatoryPlot(arenaRings: [Offset(200, 470), Offset(760, 470)]),
    ),
  },
);
