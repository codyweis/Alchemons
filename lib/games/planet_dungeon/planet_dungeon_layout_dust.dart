// lib/games/planet_dungeon/planet_dungeon_layout_dust.dart
//
// SABLIS — the Ruins of Time. Dust's authored layout, its pure rules, and the
// puzzle DATA its `part of planet_dungeon_game.dart` module reasons about.
//
// TOPOLOGY (docs/dungeons.md §5.5, structural assignment table): a BURIED CITY
// on TWO Z-LAYERS. There is no hub and there are no wings. The streets run
// above; the excavation runs below; and the same square of ground is one or
// the other depending on how much dust is standing on it.
//
//     ── the STREET layer ──────────────────────────────────
//     ashen_gate ──m_gate── seal_street ──m_agora── roof_walk ──m_roof── sand_court
//          │                     ╵ramp                  ╵                    │
//          │                high_terrace ──m_kiln───────╯                    │
//          │                                                        ashdjinn_hollow
//     ── the EXCAVATION layer (permanent drift tunnels) ────
//     windcatch ── undercity ── granary · observatory · kiln_cellar · sunken_house
//
// WORLD RULE — *nothing perishes here: dig, and the dust must go somewhere.*
//
// THE INVARIANT (§5.5, Dust's claimed mechanic): **CONSERVATION.** The city
// holds a fixed number of dust LOADS and no verb in this planet ever creates
// or destroys one. Every verb is a TRANSFER between two holders. That is not
// flavour — it is the load-bearing rule, and a leak in it silently voids every
// puzzle stacked on top, so it is enforced structurally by [RuinsOfTime]
// (nothing outside this file may write a load) and asserted in the tests.
//
// This is deliberately NOT Mud's seat. Mud owns terraforming-as-map-authoring,
// where the question is the SHAPE you are left living in. Dust's question is
// the LEDGER: dust taken from here has arrived there, always, and the cost of
// every uncovering is a burial you had to choose. Nor is it Air's irreversible
// wind-authoring (whose question is ORDER) — here order barely matters and the
// ledger is everything.
//
// ── HOW A MOUND WORKS ─────────────────────────────────────
// A MOUND is one square of the buried city: a building's worth of dust with a
// street running over its top. Its load count is the whole planet:
//
//   • 0 · BARED  — the street across it is a PIT (nothing walks it), and the
//     building UNDER it is open: a hole in the ground you climb down.
//   • 1 · BURIED — a plain street square. Walk across; nothing below.
//   • 2 · DRIFTED — the street across it is a DUNE (nothing walks it), and the
//     heap's weight presses the old lintels down and cracks the party wall
//     open in the undercity below (see THE VAULT TRICK).
//
// DIGGING is one atomic transfer: a mound at 1 goes to 0 and a neighbour of
// your choosing goes from ≤1 to +1. So **every dig bares one thing and buries
// another, and costs you two street crossings to gain one cellar.** A bared
// mound can never be re-heaped by hand and a drifted mound is packed too hard
// for a spade: both edits are IRREVERSIBLE for the run, exactly as Ice's flues
// and Mud's hardening are.
//
// THE STRATEGIC QUESTION (§5.5): *conservation — uncovering one thing buries
// another.* The sharpest instance is authored on purpose: the observatory's
// roof is the street's only bridge to the court, and the spoil that comes off
// it must land either on the roof bump (which cracks the vault open below) or
// on the agora (which raises the ramp to the terrace). One spadeful, three
// consequences, and you commit before you have seen the far side.
//
// THE VAULT TRICK (§5.5): the SUNKEN HOUSE. It is *a fully buried building
// visible only as a roof bump on the streets* — no door, no marker, just a
// swell in the paving of the roof walk. And it is the one thing on this planet
// you do NOT get by digging: baring the bump only shows you its tiles. You get
// in by burying it HARDER — heap a second load onto the bump and the weight
// cracks the party wall in the undercity, and you walk in from below. The
// planet's own verb, inverted. (No prior planet's trick is this: Ice's is a
// mirror + an unrepeatable slide, Poison's is the ward you abandoned, Steam's
// is spending the whole budget, Lightning's is a dead trunk walked in the
// dark.)
//
// THE ANTI-STRAND VALVE — THE LEVELLING WIND. Blocking two crossings per dig
// is a stranding machine (Ice measured 120/122, Mud 1200/1284; this planet
// measures 319/396 — see `solveBuriedCity`). Sablis's answer is its wind-tower:
// an AIR creature at any of the city's iron vanes winds it, and on the second
// touch the SIROCCO comes through the ruins and puts every load back where the
// city has always kept it. Element-only, always available, and it costs you
// every cellar you opened, every ramp you raised, and every spadeful of the
// drift field. A do-over, not a shortcut — and conservation survives it
// because a restoration is a permutation of the same loads.
//
// Mechanic-ledger note (§5.5): Dust claims **conservation** and the
// **two-overlaid-worlds layer swap** in its Z-layer/excavation reading only.
// Spirit's living/ghost reading of that seat is untouched and still free.
// VISUAL GRAMMAR: nothing here is drawn like Steam's tile floods or Water's
// tide regating — a mound reads as a HEIGHT (a flat paving stone, a scooped
// trench with its section showing, or a crested dune with a wind-lip), and the
// drift field reads as a survey grid of pale chalk lines over ochre spoil.

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

// ─────────────────────────────────────────────────────────
// THE CITY — mounds
// ─────────────────────────────────────────────────────────

/// The three states a mound's load count can be in. Kept as an enum for
/// readability at call sites; the LOADS themselves are integers, because the
/// conservation invariant is arithmetic and must stay arithmetic.
enum MoundState {
  /// 0 loads. The street across it is a pit; the building below is open.
  bared,

  /// 1 load. A plain street square.
  buried,

  /// 2 loads. The street across it is a dune; the weight cracks the cellar
  /// wall below (the vault) or raises a ramp (the terrace).
  drifted,
}

MoundState moundStateFor(int loads) => switch (loads) {
  <= 0 => MoundState.bared,
  1 => MoundState.buried,
  _ => MoundState.drifted,
};

/// One square of the buried city.
///
/// Authored as ONE list rather than per-room so the module's reachability
/// proof walks exactly the graph the doors are built from — the two can never
/// disagree. (Ice's flue list is the same idea for the same reason.)
class DustMound {
  final String id;

  /// The street room you stand in to work this mound.
  final String roomId;

  /// Where the mound's crown sits inside [roomId] (the dig verb's reach).
  final Offset streetPos;

  /// The two street rooms this mound's paving joins. Walkable only while the
  /// mound is BURIED: a pit or a dune both stop a foot. Null for the roof
  /// bump, which carries no street at all.
  final String? crossFrom;
  final String? crossTo;

  /// The building underneath. Its door out of [roomId] opens while the mound
  /// is BARED — you climb down through the hole you made.
  final String? cellarRoomId;

  /// The high ground this mound's DUNE lets you climb to (two-way: you can
  /// always walk back down a dune you raised).
  final String? rampRoomId;

  /// The undercity room whose party wall CRACKS while this mound is DRIFTED —
  /// the vault trick. Entry only: see [DungeonRoom] `sunken_house`, whose one
  /// door out is never blocked (a crack you crawled through stays crawlable,
  /// so the vault can never become a trap — Ice's shelf rule).
  final String? pressedRoomId;

  /// Mounds a spadeful from here can reach. Symmetric by authoring; the
  /// layout test pins that.
  final List<String> neighbours;

  /// An ancient footprint pressed into the floor of the building below, shown
  /// the moment this mound is BARED. Sweeping every one of them is the Lost
  /// Maxim (see the module). Null = no print here.
  final Offset? footprintPos;

  const DustMound({
    required this.id,
    required this.roomId,
    required this.streetPos,
    required this.neighbours,
    this.crossFrom,
    this.crossTo,
    this.cellarRoomId,
    this.rampRoomId,
    this.pressedRoomId,
    this.footprintPos,
  });
}

/// Sablis's five mounds, west to east. Every one starts BURIED (1 load), so
/// `kDustCityLoads == kDustMounds.length` and the opening ledger is trivially
/// even — the city as its dead left it.
const List<DustMound> kDustMounds = [
  // The gate square. Bared, it drops into the granary; it raises no ramp.
  DustMound(
    id: 'm_gate',
    roomId: 'ashen_gate',
    streetPos: Offset(430, 300),
    crossFrom: 'ashen_gate',
    crossTo: 'seal_street',
    cellarRoomId: 'granary',
    neighbours: ['m_agora'],
    footprintPos: Offset(430, 388),
  ),
  // The agora. No cellar — but heaped, its dune is the climb to the terrace.
  DustMound(
    id: 'm_agora',
    roomId: 'seal_street',
    streetPos: Offset(790, 470),
    crossFrom: 'seal_street',
    crossTo: 'roof_walk',
    rampRoomId: 'high_terrace',
    neighbours: ['m_gate', 'm_roof', 'm_kiln'],
    footprintPos: Offset(790, 360),
  ),
  // THE OBSERVATORY ROOF. Star 1's whole trade lives on this one square: its
  // paving is the street's only bridge to the court, and its underside is the
  // observatory's ceiling. Take the one and you have deleted the other.
  DustMound(
    id: 'm_roof',
    roomId: 'roof_walk',
    streetPos: Offset(250, 280),
    crossFrom: 'roof_walk',
    crossTo: 'sand_court',
    cellarRoomId: 'observatory',
    neighbours: ['m_agora', 'm_bump'],
    footprintPos: Offset(250, 388),
  ),
  // THE ROOF BUMP (the vault). Carries no street and hides no ramp: bare it
  // and you have uncovered nothing but tiles. Heap it and the weight cracks
  // the party wall in the undercity — see THE VAULT TRICK in the header.
  DustMound(
    id: 'm_bump',
    roomId: 'roof_walk',
    streetPos: Offset(580, 300),
    pressedRoomId: 'sunken_house',
    neighbours: ['m_roof', 'm_kiln'],
  ),
  // The kiln square, up on the terrace, joining it to the court.
  DustMound(
    id: 'm_kiln',
    roomId: 'high_terrace',
    streetPos: Offset(360, 250),
    crossFrom: 'high_terrace',
    crossTo: 'sand_court',
    cellarRoomId: 'kiln_cellar',
    neighbours: ['m_agora', 'm_bump'],
    footprintPos: Offset(360, 340),
  ),
];

/// The mound with this id, or null.
DustMound? dustMoundById(String id) {
  for (final m in kDustMounds) {
    if (m.id == id) return m;
  }
  return null;
}

/// Every mound whose crown stands in [roomId].
List<DustMound> dustMoundsIn(String roomId) =>
    [for (final m in kDustMounds) if (m.roomId == roomId) m];

/// Loads in the city at the opening of a run: one per mound.
const int kDustCityLoads = 5;

// ─────────────────────────────────────────────────────────
// STAR 0 — THE THREE SEALS (the drift field)
// ─────────────────────────────────────────────────────────

/// The street outside the seal house, as a survey grid of loose drift.
///
/// The same conservation rule as the city, at spade scale. Each cell holds
/// 0, 1 or 2 loads; three of them are the bronze SEALS of the old city, and
/// a seal only shows when its cell is scraped to 0. The star wants all three
/// bare AT ONCE (§6) — and the field is authored one single load short of
/// full, so **there is exactly one spare slot in the whole yard**: every
/// spadeful you throw wants to land on a seal you already cleared.
///
/// Two verbs, two geometries, one ledger:
///   • DIG (Dust or Earth, element-only) — bite the cell IN FRONT of you and
///     throw the spoil over your shoulder, onto the cell BEHIND. A load moves
///     two cells, across your own body. A spade only bites a plain burial: a
///     dune is packed and a pit is empty.
///   • SCOUR (Air, element-only) — blow the top load off the cell you are
///     STANDING on, one cell downwind. Wind takes a dune's crest where a spade
///     cannot, which is the only reason some of this yard moves at all.
///
/// A rubble PILLAR (`#`) holds nothing, blocks a throw and cannot be stood on.
/// The seal at the yard's west edge is boxed by the pillar and the wall so no
/// spade can ever reach it: that one answers the wind alone, and it is how the
/// room teaches its second verb without a word of tutorial.
class DriftField {
  /// Row art, one string per row.
  /// `.` one load · `^` two loads · `o` empty · `S` a seal (one load) ·
  /// `#` a rubble pillar (holds nothing).
  final List<String> art;

  /// Top-left of cell (0,0) in room coordinates.
  final Offset origin;

  /// Cell size in px (square).
  final double cell;

  const DriftField({required this.art, required this.origin, this.cell = 92});

  int get rows => art.length;
  int get cols => art.first.length;

  Rect rectAt(int c, int r) =>
      Rect.fromLTWH(origin.dx + c * cell, origin.dy + r * cell, cell, cell);
  Offset centerAt(int c, int r) => rectAt(c, r).center;

  bool isPillar(int c, int r) => art[r][c] == '#';
  bool isSeal(int c, int r) => art[r][c] == 'S';
  bool inBounds(int c, int r) => c >= 0 && r >= 0 && c < cols && r < rows;

  /// A cell a body may stand on and a load may rest on.
  bool isGround(int c, int r) => inBounds(c, r) && !isPillar(c, r);

  /// Authored load count of cell (c,r); -1 for a pillar (holds nothing).
  int loadsAt(int c, int r) => switch (art[r][c]) {
    '#' => -1,
    '^' => 2,
    'o' => 0,
    _ => 1,
  };

  /// Row-major indices of the three seals.
  List<int> get sealIndices => [
    for (var r = 0; r < rows; r++)
      for (var c = 0; c < cols; c++)
        if (isSeal(c, r)) r * cols + c,
  ];

  /// The authored opening ledger, flattened row-major (-1 at pillars).
  List<int> get openingLoads => [
    for (var r = 0; r < rows; r++)
      for (var c = 0; c < cols; c++) loadsAt(c, r),
  ];

  /// Total loose drift in the yard. Invariant for the whole run.
  int get totalLoads {
    var n = 0;
    for (final d in openingLoads) {
      if (d > 0) n += d;
    }
    return n;
  }
}

/// The authored yard. 5×3, one pillar, three seals, 21 loads in 11 cells of
/// capacity 22 — one spare slot, and the shortest solution is eight verbs.
/// Proved solvable, and proved never to deadlock, in
/// `test/planet_dungeon_dust_seals_test.dart`.
const DriftField kSealYard = DriftField(
  origin: Offset(220, 150),
  art: ['^S^^.', 'S#..^', '^S^^.'],
);

// ─────────────────────────────────────────────────────────
// STAR 2 — ASHDJINN'S EXCAVATION
// ─────────────────────────────────────────────────────────

/// Loads in the guardian hollow's own little ledger: the open cut, and the
/// bank of spoil heaped beside it. Ashdjinn's storm shovels the bank back into
/// the cut; you shovel it out again. `pit + bank` never changes.
const int kHollowLoads = 3;

// ─────────────────────────────────────────────────────────
// THE LEDGER — every load in Sablis
// ─────────────────────────────────────────────────────────

/// Total dust in the run, across all three ledgers. **Nothing may ever change
/// this number.** See [RuinsOfTime.conserved].
final int kDustTotalLoads =
    kDustCityLoads + kSealYard.totalLoads + kHollowLoads;

// ─────────────────────────────────────────────────────────
// THE LIVE STATE — pure rules, no Flutter, no engine
// ─────────────────────────────────────────────────────────

/// Everything Sablis tracks for one run, and the ONLY thing allowed to write a
/// load anywhere on the planet.
///
/// Conservation is enforced STRUCTURALLY, not by convention: every mutator
/// below is a transfer that decrements one holder and increments another in
/// the same statement, and the fields themselves are private to this object's
/// API. Callers ask for a move and are told whether the rules allowed it.
class RuinsOfTime {
  RuinsOfTime() {
    reset();
  }

  /// Loads standing on each mound, keyed by [DustMound.id].
  final Map<String, int> mound = {};

  /// Loads in each cell of the drift yard, row-major. -1 marks a pillar.
  final List<int> drift = [];

  /// The guardian hollow's cut, and the spoil bank beside it.
  int hollowPit = 0;
  int hollowBank = kHollowLoads;

  /// Which mound each drifted mound's extra load came from — the storm needs
  /// the provenance to shovel it back (§7: the guardian fights WITH the rule).
  final Map<String, String> spoilFrom = {};

  /// Footprints already swept away (the Lost Maxim).
  final Set<String> sweptPrints = {};

  /// How many times the sirocco has been called. A readout, and the price tag
  /// on the anti-strand valve.
  int levellings = 0;

  /// Vane armed for its second touch, and the seconds left on that window.
  String? armedVaneRoom;
  double armedVaneTimer = 0;

  /// The city as its dead left it: every mound buried, the yard as authored.
  void reset() {
    mound.clear();
    for (final m in kDustMounds) {
      mound[m.id] = 1;
    }
    drift
      ..clear()
      ..addAll(kSealYard.openingLoads);
    hollowPit = 0;
    hollowBank = kHollowLoads;
    spoilFrom.clear();
    sweptPrints.clear();
    levellings = 0;
    armedVaneRoom = null;
    armedVaneTimer = 0;
  }

  // ── The ledger ────────────────────────────────────────

  int get cityLoads {
    var n = 0;
    for (final v in mound.values) {
      n += v;
    }
    return n;
  }

  int get driftLoads {
    var n = 0;
    for (final d in drift) {
      if (d > 0) n += d;
    }
    return n;
  }

  int get hollowLoads => hollowPit + hollowBank;

  /// Every load in Sablis, right now.
  int get dustTotal => cityLoads + driftLoads + hollowLoads;

  /// THE INVARIANT (§5.5). Nothing perishes here. If this is ever false the
  /// planet's whole design is void, so it is asserted after every verb in the
  /// tests and guarded inside every mutator below.
  bool get conserved => dustTotal == kDustTotalLoads;

  // ── The city ──────────────────────────────────────────

  int loadsOn(String moundId) => mound[moundId] ?? 0;
  MoundState stateOf(String moundId) => moundStateFor(loadsOn(moundId));

  /// Whether a spade may bite [from] and throw its load onto [to].
  ///
  /// A spade only bites a plain BURIAL — a bared square has nothing in it and
  /// a drifted one is packed harder than a shovel. Nothing takes a third load.
  /// Both of those rules are what makes every city edit irreversible.
  bool canDig(String from, String to) {
    final m = dustMoundById(from);
    if (m == null || !m.neighbours.contains(to)) return false;
    return loadsOn(from) == 1 && loadsOn(to) <= 1;
  }

  /// One spadeful: [from] loses its load, [to] gains it. Conservation is
  /// structural — the two writes are one statement apart and always paired.
  bool dig(String from, String to) {
    if (!canDig(from, to)) return false;
    mound[from] = mound[from]! - 1;
    mound[to] = mound[to]! + 1;
    spoilFrom[to] = from;
    return true;
  }

  /// Ashdjinn's storm shovelling one of your digs back in (§7). The load
  /// returns to the mound it was thrown from — a transfer, like everything
  /// else. Returns the pair it undid, or null when there is nothing to undo.
  (String from, String to)? undoOneDig() {
    for (final entry in spoilFrom.entries) {
      final to = entry.key;
      final from = entry.value;
      if (loadsOn(to) != 2 || loadsOn(from) != 0) continue;
      mound[to] = mound[to]! - 1;
      mound[from] = mound[from]! + 1;
      spoilFrom.remove(to);
      return (from, to);
    }
    return null;
  }

  // ── The drift yard ────────────────────────────────────

  int driftAt(int index) => index < 0 || index >= drift.length ? -1 : drift[index];

  /// A spade bites [from] (a plain burial) and throws over the shoulder onto
  /// [to] (which must have room). Caller supplies the geometry.
  bool digDrift(int from, int to) {
    if (driftAt(from) != 1 || driftAt(to) < 0 || driftAt(to) > 1) return false;
    drift[from] -= 1;
    drift[to] += 1;
    return true;
  }

  /// A gust takes the top load off [from] (a burial OR a dune's crest — this
  /// is the one thing wind does that a spade cannot) and lays it on [to].
  bool scourDrift(int from, int to) {
    if (driftAt(from) < 1 || driftAt(to) < 0 || driftAt(to) > 1) return false;
    drift[from] -= 1;
    drift[to] += 1;
    return true;
  }

  /// True when every seal in the yard is scraped bare at once (Star 0).
  bool get sealsBare {
    for (final i in kSealYard.sealIndices) {
      if (driftAt(i) != 0) return false;
    }
    return true;
  }

  // ── The guardian hollow ───────────────────────────────

  /// The storm shovels one load off the bank into the open cut.
  bool buryHollow() {
    if (hollowBank <= 0) return false;
    hollowBank -= 1;
    hollowPit += 1;
    return true;
  }

  /// A hand throws one load back out of the cut, onto the bank.
  bool clearHollow() {
    if (hollowPit <= 0) return false;
    hollowPit -= 1;
    hollowBank += 1;
    return true;
  }

  /// The excavation is held open — Ashdjinn's lull only exists here (§7).
  bool get hollowOpen => hollowPit == 0;

  // ── THE LEVELLING WIND (the anti-strand valve) ────────

  /// True when the whole city already stands as it was authored — the sirocco
  /// has nothing to move, and the verb declines rather than burning a vane.
  bool get isLevelled {
    for (final m in kDustMounds) {
      if (loadsOn(m.id) != 1) return false;
    }
    final opening = kSealYard.openingLoads;
    for (var i = 0; i < drift.length; i++) {
      if (drift[i] != opening[i]) return false;
    }
    return true;
  }

  /// THE SIROCCO. Every load in the city and the yard goes back where Sablis
  /// has always kept it. Conservation survives trivially: a restoration is a
  /// permutation of the same multiset, and the hollow's own pair is untouched.
  ///
  /// It costs everything you dug. That is the point — see the header.
  void levelCity() {
    for (final m in kDustMounds) {
      mound[m.id] = 1;
    }
    final opening = kSealYard.openingLoads;
    for (var i = 0; i < drift.length; i++) {
      drift[i] = opening[i];
    }
    spoilFrom.clear();
    armedVaneRoom = null;
    armedVaneTimer = 0;
    levellings++;
  }
}

// ─────────────────────────────────────────────────────────
// PER-ROOM DUST CONTENT
// ─────────────────────────────────────────────────────────

/// Everything the Ruins of Time put in one room. Carried on
/// `DungeonRoom.ruins` so exactly one field had to be added to the shared room
/// model, and so a room's star index is visible to the layout invariants.
class DustRuins {
  /// The star this room banks (null = a connective street or tunnel).
  final int? starIndex;

  /// Star 0's survey grid (only the seal street has one).
  final DriftField? field;

  /// An iron weather-vane. AIR winds it, and a second touch calls the
  /// SIROCCO — the anti-strand valve. Authored in every street room and at the
  /// tower's foot, because a valve you cannot reach is not a valve.
  final Offset? windVane;

  /// The entry rite: the gate arch is silted to the springing. A DUST hand
  /// parts its own element and the city opens.
  final Offset? gateSilt;

  /// Star 1: the great armillary on its island, across the roofless span.
  final Offset? armillary;

  /// The rite's second half: the hourglass court's great glass (element-only
  /// Dust; latches conduit 'B').
  final Offset? glassCourt;

  /// Ashdjinn's open cut. Held bare, it is the fight's whole verb (§7).
  final Offset? hollowCut;

  const DustRuins({
    this.starIndex,
    this.field,
    this.windVane,
    this.gateSilt,
    this.armillary,
    this.glassCourt,
    this.hollowCut,
  });
}

// ─────────────────────────────────────────────────────────
// THE LAYOUT
// ─────────────────────────────────────────────────────────

/// Sablis — the Ruins of Time.
const DungeonLayout dustLayout = DungeonLayout(
  element: 'Dust',
  entranceRoomId: 'ashen_gate',
  entranceSpawn: Offset(120, 280),
  title: 'THE RUINS OF TIME',
  descentTitle: 'Sablis Ruins',
  stars: [
    DungeonStarSpec(
      name: 'Seal Star',
      earnAnnouncement:
          'The Seal Star is yours — three bronzes bare at once, and the '
          'street holds',
    ),
    DungeonStarSpec(
      name: 'Armillary Star',
      earnAnnouncement:
          'The Armillary Star is yours — the sky comes down through the roof '
          'you took',
    ),
    DungeonStarSpec(name: 'Ash Star'),
  ],
  // The arch is silted to the springing until a Dust hand parts it.
  entranceRevealDoor: DungeonDoorRef('ashen_gate', 'seal_street'),
  finaleDoor: DungeonDoorRef('sand_court', 'ashdjinn_hollow'),
  riteAnnouncement:
      'Seal and Armillary are won — the great glass grinds loose in the court',
  finaleSealedHint:
      'The court is shut — it answers only the Seal and Armillary stars',
  guardianSealedHint:
      'The hollow lies drifted over — nothing in there stirs until the glass '
      'is turned',
  mercyShrineRoomId: 'undercity',
  // Ideal: Dustmask · Airwing · Earthhorn — hinted by VERB, never body part
  // (§4): the sight that reads ash, the one the ground cannot keep, and the
  // strongest grip.
  riddle: [
    'Bring me the sight that reads ash as scripture — my streets keep their '
        'dead beneath them;',
    'bring me one the ground cannot keep, for I will take my own bridges '
        'away;',
    'and bring me where the grip is strongest, to put a shoulder through a '
        'wall that was never there.',
  ],
  // §4 budget: TWO hard gates, one per star that has one, each on a different
  // entry slot. Star 0 (the three seals) is deliberately UNGATED and uses all
  // three elements at full power, so any trio of Dust/Air/Earth progresses on
  // a first descent. The dig verb — the planet's whole grammar — is
  // element-only Dust-or-Earth everywhere, always, and the valve is
  // element-only Air.
  familyGates: [
    DungeonFamilyGate(
      objectId: 'armillary',
      element: 'Air',
      family: 'Wing',
      hintLine: 'Only Air borne on wings crosses a roofless span',
    ),
    DungeonFamilyGate(
      objectId: 'A',
      element: 'Earth',
      family: 'Horn',
      hintLine: 'Only an Earth horn puts a shoulder through this wall',
    ),
  ],
  rooms: {
    // ── STREET · THE ASHEN GATE (entrance) ────────────────
    // The city's mouth. Two ways out: the gate square east (m_gate) and the
    // wind-tower's stair down to the windcatch. Both are under the silt until
    // a Dust hand parts the arch.
    'ashen_gate': DungeonRoom(
      id: 'ashen_gate',
      bounds: Rect.fromLTWH(0, 0, 720, 480),
      walls: [
        Rect.fromLTWH(200, 60, 150, 30), // a fallen architrave
      ],
      doors: [
        // The gate square's paving — walkable only while m_gate is buried.
        DungeonDoor(
          rect: Rect.fromLTWH(696, 190, 24, 110),
          targetRoomId: 'seal_street',
          targetSpawn: Offset(40, 300),
        ),
        // The wind-tower's stair.
        DungeonDoor(
          rect: Rect.fromLTWH(100, 456, 110, 24),
          targetRoomId: 'windcatch',
          targetSpawn: Offset(310, 120),
        ),
        // The hole into the granary, right under the gate square's crown —
        // only while m_gate is bared.
        DungeonDoor(
          rect: Rect.fromLTWH(375, 456, 110, 24),
          targetRoomId: 'granary',
          targetSpawn: Offset(230, 90),
        ),
      ],
      ruins: DustRuins(
        gateSilt: Offset(640, 245),
        windVane: Offset(120, 90),
      ),
    ),

    // ── STREET · THE SEAL STREET (Star 0) ─────────────────
    // The survey yard. 5×3 of 92px from (220,150) → 460×276 inside 900×560.
    'seal_street': DungeonRoom(
      id: 'seal_street',
      bounds: Rect.fromLTWH(0, 0, 900, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 240, 24, 110),
          targetRoomId: 'ashen_gate',
          targetSpawn: Offset(660, 245),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(876, 240, 24, 110),
          targetRoomId: 'roof_walk',
          targetSpawn: Offset(40, 290),
        ),
        // Up the agora's dune — only while m_agora is drifted.
        DungeonDoor(
          rect: Rect.fromLTWH(780, 0, 110, 24),
          targetRoomId: 'high_terrace',
          targetSpawn: Offset(330, 330),
        ),
      ],
      ruins: DustRuins(
        starIndex: 0,
        field: kSealYard,
        windVane: Offset(110, 490),
      ),
    ),

    // ── STREET · THE ROOF WALK ────────────────────────────
    // Two mounds stand here: the observatory's roof (west) and the nameless
    // bump (east) that is the only sign of the sunken house.
    'roof_walk': DungeonRoom(
      id: 'roof_walk',
      bounds: Rect.fromLTWH(0, 0, 820, 520),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 235, 24, 110),
          targetRoomId: 'seal_street',
          targetSpawn: Offset(840, 290),
        ),
        // The roof's paving — the street's ONLY bridge to the court.
        DungeonDoor(
          rect: Rect.fromLTWH(796, 200, 24, 110),
          targetRoomId: 'sand_court',
          targetSpawn: Offset(40, 260),
        ),
        // Down through the stripped roof — only while m_roof is bared.
        DungeonDoor(
          rect: Rect.fromLTWH(195, 496, 110, 24),
          targetRoomId: 'observatory',
          targetSpawn: Offset(150, 110),
        ),
      ],
      ruins: DustRuins(windVane: Offset(690, 80)),
    ),

    // ── STREET · THE HIGH TERRACE ─────────────────────────
    'high_terrace': DungeonRoom(
      id: 'high_terrace',
      bounds: Rect.fromLTWH(0, 0, 680, 440),
      doors: [
        // Back down the agora's dune.
        DungeonDoor(
          rect: Rect.fromLTWH(70, 416, 110, 24),
          targetRoomId: 'seal_street',
          targetSpawn: Offset(830, 90),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(656, 165, 24, 110),
          targetRoomId: 'sand_court',
          targetSpawn: Offset(370, 130),
        ),
        // Down into the kiln, right under the square's crown — only while
        // m_kiln is bared.
        DungeonDoor(
          rect: Rect.fromLTWH(305, 416, 110, 24),
          targetRoomId: 'kiln_cellar',
          targetSpawn: Offset(240, 100),
        ),
      ],
      ruins: DustRuins(windVane: Offset(590, 80)),
    ),

    // ── STREET · THE HOURGLASS COURT (the rite) ───────────
    // Conduit A is the planet's Earth+HORN gate — the false wall across the
    // glass. The court's own half is the great glass below, an element-only
    // Dust object the module owns and which latches `conduitEnergy['B']`
    // itself (authoring it as a family-less Conduit would make the engine's
    // channel verb step over it — the same reason Ice left its cold font out).
    'sand_court': DungeonRoom(
      id: 'sand_court',
      bounds: Rect.fromLTWH(0, 0, 760, 520),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 205, 24, 110),
          targetRoomId: 'roof_walk',
          targetSpawn: Offset(760, 255),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(325, 0, 110, 24),
          targetRoomId: 'high_terrace',
          targetSpawn: Offset(620, 220),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(325, 496, 110, 24),
          targetRoomId: 'ashdjinn_hollow',
          targetSpawn: Offset(450, 150),
        ),
      ],
      conduits: [
        Conduit(
          id: 'A',
          position: Offset(230, 280),
          requireElement: 'Earth',
          requiredFamily: DungeonAbility.heavyForce,
        ),
      ],
      ruins: DustRuins(
        glassCourt: Offset(530, 280),
        windVane: Offset(110, 100),
      ),
    ),

    // ── EXCAVATION · THE WINDCATCH (the tower's foot) ─────
    // The sirocco's own throat. The vane here is the one you can always get
    // to: every tunnel in the undercity runs to this room and none of them
    // ever closes.
    'windcatch': DungeonRoom(
      id: 'windcatch',
      bounds: Rect.fromLTWH(0, 0, 620, 420),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(255, 0, 110, 24),
          targetRoomId: 'ashen_gate',
          targetSpawn: Offset(355, 400),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(596, 155, 24, 110),
          targetRoomId: 'undercity',
          targetSpawn: Offset(60, 215),
        ),
      ],
      ruins: DustRuins(windVane: Offset(310, 210)),
    ),

    // ── EXCAVATION · THE UNDERCITY (the drift tunnels) ────
    // The lower Z-layer's spine, and the mercy shrine. Nothing here is ever
    // mutated: the tunnels are what make a cellar a place you can leave.
    'undercity': DungeonRoom(
      id: 'undercity',
      bounds: Rect.fromLTWH(0, 0, 960, 600),
      walls: [
        Rect.fromLTWH(300, 250, 360, 40), // a collapsed vault rib
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 160, 24, 110),
          targetRoomId: 'windcatch',
          targetSpawn: Offset(560, 210),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(140, 0, 110, 24),
          targetRoomId: 'granary',
          targetSpawn: Offset(230, 170),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(420, 0, 110, 24),
          targetRoomId: 'observatory',
          targetSpawn: Offset(150, 300),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(700, 0, 110, 24),
          targetRoomId: 'kiln_cellar',
          targetSpawn: Offset(240, 200),
        ),
        // The cracked party wall — open only while the bump is DRIFTED.
        DungeonDoor(
          rect: Rect.fromLTWH(936, 240, 24, 110),
          targetRoomId: 'sunken_house',
          targetSpawn: Offset(60, 175),
        ),
      ],
    ),

    // ── EXCAVATION · THE GRANARY ──────────────────────────
    'granary': DungeonRoom(
      id: 'granary',
      bounds: Rect.fromLTWH(0, 0, 460, 340),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(175, 0, 110, 24),
          targetRoomId: 'ashen_gate',
          targetSpawn: Offset(155, 400),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(175, 316, 110, 24),
          targetRoomId: 'undercity',
          targetSpawn: Offset(195, 120),
        ),
      ],
    ),

    // ── EXCAVATION · THE OBSERVATORY (Star 1) ─────────────
    // The prize under the roof walk. The armillary stands on an island inside
    // a ROOFLESS SPAN — the instrument moat — which is why the star is the
    // planet's Air+WING gate (§6: "Airwing can cross what the dig destroyed").
    // It reads nothing while the roof is on: the sky only comes down through
    // the hole you made, so Star 1 needs m_roof BARED, and baring it deletes
    // the street's only bridge to the court. That is the whole star.
    'observatory': DungeonRoom(
      id: 'observatory',
      bounds: Rect.fromLTWH(0, 0, 880, 560),
      gaps: [
        Rect.fromLTWH(280, 140, 320, 80),
        Rect.fromLTWH(280, 380, 320, 80),
        Rect.fromLTWH(280, 140, 80, 320),
        Rect.fromLTWH(520, 140, 80, 320),
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(95, 0, 110, 24),
          targetRoomId: 'roof_walk',
          targetSpawn: Offset(250, 400),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(95, 536, 110, 24),
          targetRoomId: 'undercity',
          targetSpawn: Offset(475, 130),
        ),
      ],
      ruins: DustRuins(starIndex: 1, armillary: Offset(440, 300)),
    ),

    // ── EXCAVATION · THE KILN CELLAR ──────────────────────
    'kiln_cellar': DungeonRoom(
      id: 'kiln_cellar',
      bounds: Rect.fromLTWH(0, 0, 480, 360),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(185, 0, 110, 24),
          targetRoomId: 'high_terrace',
          targetSpawn: Offset(125, 360),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(185, 336, 110, 24),
          targetRoomId: 'undercity',
          targetSpawn: Offset(755, 130),
        ),
      ],
    ),

    // ── EXCAVATION · THE SUNKEN HOUSE (the vault) ─────────
    // A pocket, and the planet's cache. You come in through the crack the
    // heaped bump opened above — and you can always crawl back out the same
    // way, whatever happens to the bump behind you. That one-door-never-
    // blocked rule is Ice's shelf rule, and it is what keeps the vault trick
    // from being a trap (see the no-strand proof).
    'sunken_house': DungeonRoom(
      id: 'sunken_house',
      bounds: Rect.fromLTWH(0, 0, 420, 320),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 120, 24, 110),
          targetRoomId: 'undercity',
          targetSpawn: Offset(900, 295),
        ),
      ],
      vaultCache: Offset(230, 175),
    ),

    // ── ASHDJINN'S HOLLOW (Star 2) ────────────────────────
    // §7 guardian principle — the mystic fights WITH the planet's rule.
    // Ashdjinn rides a rolling sandstorm: every strike beat shovels one load
    // off the bank into the open cut, and its lull exists ONLY while the cut
    // is held bare. It also reaches out into the city and shovels one of your
    // digs back in — it re-buries your work while you fight it.
    'ashdjinn_hollow': DungeonRoom(
      id: 'ashdjinn_hollow',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'sand_court',
          targetSpawn: Offset(380, 400),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(450, 300),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Dust',
          mysticId: 'Ashdjinn',
          canCalm: true,
          canDefeat: true,
        ),
      ),
      ruins: DustRuins(hollowCut: Offset(450, 470)),
    ),
  },
);
