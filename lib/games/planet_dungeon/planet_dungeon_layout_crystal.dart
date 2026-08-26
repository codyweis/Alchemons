// lib/games/planet_dungeon/planet_dungeon_layout_crystal.dart
//
// VITREA — THE PRISM LABYRINTH. Crystal's authored layout AND its pure,
// headless sliding rules (the burn_field.dart / BogField treatment: the
// engine, the renderer and the reachability proof all reason about ONE copy
// of [PrismKeepField], so "can this arrangement ever be reached" is answered
// by the shipped code and never by a model of it).
//
// ─────────────────────────────────────────────────────────
// WHAT docs/dungeons.md CLAIMS FOR CRYSTAL, AND HOW THIS ANSWERS IT
// ─────────────────────────────────────────────────────────
// §5.5 structural assignment table, Crystal row:
//   topology  — "Rearranging 3×3 sliding grid — sliding moves rooms AND you"
//   question  — "every slide solves one adjacency and breaks another"
//   vault     — "a room that only ENTERS the grid in one configuration"
//   mechanic  — "self-rearranging map / sliding rooms" (the open-pool row
//               reserved for Crystal)
// §6.10 fixes the flavour: *Prism Labyrinth · Crystal+Lightning+Spirit ·
// Crystalmask/Lightninghorn/Spiritpip · rooms can be rearranged*, with beam
// colours, the mirror crack, the Sky Keep, and the two recipes
// **Lightning+Crystal→Spirit** and **Crystal+Spirit→Light**.
//
// (§6.10 was written before §5.5 existed and puts the sliding grid on Star 3
// only, with "Crystalmask ROTATES prisms" on Star 1. Both are corrected here
// for the reasons the doc itself gives: §5.5 makes the slide the whole
// planet's TOPOLOGY, not one room's gimmick, and the Lightning ledger row
// already OWNS "beam routing/reflection via rotatable mirrors" — a rotating
// prism on Crystal would be a reskin of a claimed seat. Crystal never rotates
// anything. It TRANSLATES. Every star here is asked of the arrangement.)
//
// ─────────────────────────────────────────────────────────
// TOPOLOGY — THE KEEP IS A PUZZLE, AND THE PUZZLE IS THE MAP
// ─────────────────────────────────────────────────────────
// Nine CELLS are cut in the keep's stone frame in a 3×3 lattice. The frame
// never moves: the lattice, its twelve arch-mouths, the threshold at the
// south, the north arch to the tuning hall, the west lamp and the east rose
// are all fixed geography. What moves is what STANDS in the cells — eight
// glass CHAMBERS and one HOLLOW, the empty socket the whole keep turns on.
//
//   • The rooms of this dungeon are the CELLS (fixed, statically doored —
//     which is why the layout test's reciprocal-door invariant holds without
//     a word of special pleading: no door is ever created or destroyed).
//   • The CHAMBERS permute across them. A chamber carries its own four
//     FACETS — which of its walls is cut with a doorway — so a lattice arch
//     is walkable only when the two chambers meeting there BOTH have a
//     doorway on that face. Slide one chamber and a dozen adjacencies change
//     at once, none of them by opening or closing a door: the doors were
//     always there, and now the glass either lines up or it does not.
//   • THE SHUNT is the planet's only verb, and it is one rule: A CHAMBER AND
//     THE HOLLOW TRADE PLACES, AND SO DOES WHOEVER IS STANDING AT THE
//     BOUNDARY. From inside a chamber you RIDE it across; from inside the
//     bare socket you HAUL a neighbour in and stay with the hollow. Either
//     way the body ends up in the other cell of the pair, which is the doc's
//     "sliding moves rooms AND you", literally: the screen slides, and your
//     feet do not move on the floor they are standing on.
//   • THE HOLLOW IS NOT NOTHING. It is the keep's bare socket — the frame's
//     own stone with the works showing through a grille — so it can be walked
//     into (an empty socket has no glass to disagree with, so only the
//     chamber's own facet is asked for) and shunted from. That makes the
//     socket the keep's one free-moving place, and it is not a convenience:
//     the reachability search measured a first draft WITHOUT it at 2 reachable
//     arrangements out of 181,440. See the test.
//
// THE STRATEGIC QUESTION (§5.5): *every slide solves one adjacency and breaks
// another.* Pinned in geometry, not in prose. The Throne Star wants the Shard
// Hearth in the middle cell with three named thrones on three of its four
// faces at once; the Prism Star wants three particular chambers standing in
// the middle ROW, and the hearth is not one of them. The two demands are
// mutually exclusive arrangements of the same eight objects — you cannot hold
// both, and you do not have to, because a banked star stays banked. That is
// the whole planet said in one sentence.
//
// LEDGER (§5.5). Crystal takes "self-rearranging map / sliding rooms" and
// nothing else. It is deliberately NOT:
//   · Mud's terraforming-as-map-authoring — Mud AUTHORS edges that never come
//     back and asks what SHAPE you are left in. Crystal creates and destroys
//     no edge at all: the twelve arches are constant, and every slide is
//     undone by sliding back. Nothing here is permanent.
//   · Dust's conservation — nothing is relocated from one place to another as
//     a quantity; the chambers are not a substance.
//   · Air's irreversible wind-authoring — Air's question is ORDER, because
//     each edit is permanent. Crystal's moves are a group, so order is
//     recoverable and the question is the DESTINATION.
//   · Steam's global spend — no budget is consumed anywhere. Slides are free.
//     (They are not costless: the keep rings, and the ringing draws shards.
//     That is a consequence, not a currency — nothing runs out.)
//   · Poison's forced sacrifice — nothing is abandoned; the exclusivity
//     between the two stars is temporal, not terminal.
//   · Ice's one-way traversal — the route behind you is never consumed.
//   · Water's tide regating — the closest surface resemblance, and the one
//     §5.5's VISUAL GRAMMAR RULE names by name. Water's tide OPENS AND CLOSES
//     passages in a map that stands still; a tide is a global scalar and the
//     rooms never move. Vitrea's rooms MOVE, bodily, across the screen, and
//     no passage is ever opened or closed — only mis-aligned. Rendering
//     follows: no water, no level, no gauge, no dissolve. A shunt is a hard
//     translation of a whole chamber's furniture along one axis with a glass
//     shear at its leading edge, and the keep's state is legible at a glance
//     from a 3×3 index plate carved into every cell's frame.
//
// ─────────────────────────────────────────────────────────
// THE HAZARD THIS PLANET IS BUILT AROUND — PARITY
// ─────────────────────────────────────────────────────────
// A 3×3 sliding grid is the 8-puzzle, and the 8-puzzle's arrangements split
// into TWO classes that cannot reach one another. Of the 9! = 362,880 ways to
// lay eight chambers and a hollow in nine cells, exactly 181,440 can ever be
// reached from any given start. Author a target in the wrong half and the
// dungeon is not hard, it is IMPOSSIBLE — and no amount of playtesting can
// find that out, because a player who fails simply assumes they are bad at
// it.
//
// The invariant, stated exactly: label the arrangement as a permutation π of
// the nine items (eight chambers + the hollow) over the nine cells. Every
// legal shunt transposes the hollow with one orthogonal neighbour, so it
// flips sgn(π) AND moves the hollow one step on a bipartite lattice. So
//
//     sgn(π) · (−1)^(row+col of the hollow)
//
// is conserved by every move, and the reachable orbit is exactly the set of
// arrangements sharing the start's value of it. With the hollow returned to
// its home cell the achievable permutations of the eight chambers are the
// ALTERNATING GROUP A₈ (order 20,160) — Wilson's theorem: the 3×3 grid graph
// is 2-connected, is not a cycle, is not the exceptional θ₀ graph, and IS
// bipartite, which is precisely the case in which the puzzle group is the
// alternating rather than the symmetric group. 20,160 × 9 hollow positions =
// 181,440 = 9!/2, as above.
//
// Every arrangement this planet requires is therefore PROVED reachable by
// exhaustive BFS over the real state graph — the one in this file, walked by
// the shipped code, with the player's own position and the facet-gated
// walking included (see test/planet_dungeon_crystal_keep_test.dart). It is
// not enough to check the arrangement: the player must be able to BE
// somewhere that can make the last move, and walking between chambers is
// itself facet-gated. The search covers both.
//
// ─────────────────────────────────────────────────────────
// THE VAULT TRICK (§5.5: "a room that only ENTERS the grid in one
// configuration")
// ─────────────────────────────────────────────────────────
// A ninth chamber — THE WAITING FACET — stands outside the keep in a berth
// cut in the east frame, level with the middle row. It is not in the puzzle
// and cannot be shunted. It enters on exactly one condition: the HOLLOW must
// come to rest in the mouth cell (the middle-east cell), and then the berth
// chain draws the facet in and the hollow goes out to the berth in its place.
//
// Three consequences, and they are the design:
//   1. The keep is FULL while the facet stands in it — no hollow, no shunt,
//      the whole map set solid. Everything else you meant to do, you must
//      have done first.
//   2. The facet is cut with ONE doorway, on its west face. So it is only
//      ever enterable from the middle cell, and only if the chamber standing
//      there is cut with an east doorway.
//   3. Leaving the hollow at the mouth means SHUNTING OUT of the mouth, which
//      puts you on the cell you rode to. Ride west and you are exactly where
//      the vault can be entered from; ride north or south and you have opened
//      a door you cannot reach, and must draw the facet back out to move
//      again.
// It is not a side room behind a signature-gated door, it is not Ice's
// unrepeatable slide, and it is not Mud's induced collapse: it is a tenth
// room that is not part of the map until the map is in one specific state.
//
// ─────────────────────────────────────────────────────────
// THE ANTI-DEADLOCK VALVE — THE ANNEAL
// ─────────────────────────────────────────────────────────
// Because every slide is reversible, this planet cannot strand you by an
// irreversible edit the way Ice (120/122), Mud (1200/1284) and Dust (319/396)
// can: there is no arrangement the slides cannot undo. It has one other way to
// WEDGE, and only one — a body standing on glass whose cut faces both happen
// to give onto the outer frame, or onto neighbours whose glass does not agree,
// with the hollow out of reach. The Black Cell in a corner is the clean case,
// and it is not rare: 7,404 of the 1,592,585 reachable states are jams,
// counted by name in the test.
//
// THE ANNEAL answers it. The keep's frame is one tuned instrument, and a
// Crystal hand on any tuning boss (there is one in every cell, in the oriel,
// in the tuning hall and in the choir) RINGS THE KEEP BACK to the arrangement
// it opened in, pushes the waiting facet back to its berth — and PUTS THE
// RINGER OUT, on the oriel below the south face.
//
// Being thrown clear is the load-bearing half, and it was not the first draft.
// A ring that carries you along with your own chamber sets you back down in
// the very trap you rang it to escape, forever; the reachability search caught
// exactly that, on the opening arrangement's north-west corner. Throwing the
// ringer out makes the valve total: from ANY state whatsoever, one ring
// returns the run to the exact state it began in. A do-over, never a shortcut
// — it costs every slide you made.
//
// The fixture classes live here (rather than in planet_dungeon_data.dart with
// the older planets') so this planet's diff against shared files stays to a
// handful of additive lines while other elements are built in parallel.

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart'
    show DungeonAbility, GuardianEncounterRequirement, kAnyElement;

// ─────────────────────────────────────────────────────────
// THE LATTICE — nine cells, fixed forever
// ─────────────────────────────────────────────────────────

/// Cell index → room id, row-major:
///
///     0 1 2      nw  n  ne
///     3 4 5   =  w  core e
///     6 7 8      sw  s  se
///
/// The frame is geography and never changes; only what stands in it does.
const List<String> kKeepCellRooms = [
  'keep_nw',
  'keep_n',
  'keep_ne',
  'keep_w',
  'keep_core',
  'keep_e',
  'keep_sw',
  'keep_s',
  'keep_se',
];

/// The cell the south threshold opens on (the oriel's arch).
const int kKeepThresholdCell = 7;

/// The cell the north arch opens on (the tuning hall, and the rite).
const int kKeepNorthCell = 1;

/// The cell the berth's mouth opens on — the ONE cell the waiting facet can
/// ever stand in (§5.5 vault trick).
const int kKeepMouthCell = 5;

/// The middle row, west to east: the lamp's beam runs along it and nowhere
/// else. Star 0 is a question about exactly these three cells.
const List<int> kKeepBeamRow = [3, 4, 5];

/// The cell the Throne Star demands the Shard Hearth stand in. The centre is
/// the only cell in a 3×3 with four faces, which is what makes "three thrones
/// served at once" a real constraint instead of a walk.
const int kKeepHeartCell = 4;

/// The hue, on the keep's twelve-step wheel, the east rose was cut to read.
/// Ten — reachable by exactly ONE set of three chambers (proved in the test).
const int kRoseHue = 10;

/// Every chamber's facet mask uses these bits.
const int kFacetN = 1;
const int kFacetE = 2;
const int kFacetS = 4;
const int kFacetW = 8;

/// The hollow — the empty socket. Not a chamber; the thing chambers move into.
const int kHollow = -1;

/// The waiting facet's index in [kPrismChambers]. It is chamber 8: never in
/// the opening arrangement, never shuntable, and the only one that carries
/// the vault.
const int kWaitingFacet = 8;

bool _adjacent(int a, int b) {
  if (a < 0 || b < 0 || a > 8 || b > 8) return false;
  final ra = a ~/ 3, ca = a % 3, rb = b ~/ 3, cb = b % 3;
  return (ra - rb).abs() + (ca - cb).abs() == 1;
}

/// The facet bit on cell [from]'s side of the arch it shares with [to].
int keepFacetToward(int from, int to) {
  if (!_adjacent(from, to)) return 0;
  if (to == from - 3) return kFacetN;
  if (to == from + 3) return kFacetS;
  if (to == from - 1) return kFacetW;
  return kFacetE;
}

/// The cell on the other side of [cell]'s [facet] wall, or −1 when that wall
/// is the keep's outer frame and carries no arch (and so no shove-plate).
int keepNeighbourToward(int cell, int facet) {
  if (cell < 0 || cell > 8) return -1;
  final r = cell ~/ 3, c = cell % 3;
  return switch (facet) {
    kFacetN => r > 0 ? cell - 3 : -1,
    kFacetS => r < 2 ? cell + 3 : -1,
    kFacetW => c > 0 ? cell - 1 : -1,
    kFacetE => c < 2 ? cell + 1 : -1,
    _ => -1,
  };
}

/// The cells orthogonally adjacent to [cell], ascending.
List<int> keepNeighbours(int cell) => [
  for (var i = 0; i < 9; i++)
    if (_adjacent(cell, i)) i,
];

// ─────────────────────────────────────────────────────────
// THE CHAMBERS — what stands in the cells
// ─────────────────────────────────────────────────────────

/// One glass chamber of the keep. Everything a chamber IS lives here, because
/// a chamber's identity has to travel with it from cell to cell: its cut
/// doorways, what it does to a light passing through, and whether it is one
/// of the three shard thrones.
class PrismChamber {
  final String id;
  final String name;

  /// Which of the four walls is cut with a doorway (bitmask of kFacet*).
  /// An arch between two cells is walkable only when BOTH chambers are cut on
  /// the face they meet at — no door is ever opened or closed, only aligned.
  final int facets;

  /// How far round the keep's twelve-step wheel this glass bends a light that
  /// crosses it, west to east. Bends ADD, so the beam's colour depends on
  /// WHICH chambers stand in the middle row and not on their order — a
  /// deliberate order-independence that keeps Star 0 out of Air's ordering
  /// seat and Fire's sequence seat (§5.5).
  final int bend;

  /// One of the three shard thrones the Throne Star must see served at once.
  final bool throne;

  /// The glass's own colour, for the renderer.
  final int argb;

  const PrismChamber({
    required this.id,
    required this.name,
    required this.facets,
    required this.bend,
    required this.argb,
    this.throne = false,
  });

  bool cut(int facet) => (facets & facet) != 0;

  /// A light only crosses glass cut on BOTH the west and east faces. Five of
  /// the eight are; the other three are walls as far as the lamp is concerned,
  /// which is what makes the beam row a choice and not an accident.
  bool get clear => cut(kFacetE) && cut(kFacetW);
}

/// The keep's nine chambers. Indices 0..7 stand in the lattice; index 8, the
/// waiting facet, stands outside it in the east berth (§5.5 vault trick).
///
/// The facet masks and bends are AUTHORED AGAINST THE TWO STARS and proved in
/// the test, not decorated afterwards:
///   · clear glass (E and W both cut) is exactly {hearth, beryl, lazuli,
///     citrine, amethyst}; of the ten three-chamber sets that could stand in
///     the beam row, exactly ONE bends to the rose's hue of 10 —
///     {beryl, lazuli, citrine} — and the hearth is not in it.
///   · the three thrones can each face the heart cell only from certain
///     sides (cinnabar from N/S/E-of-centre, beryl from W/E-of-centre, lazuli
///     from S/W/E-of-centre), which leaves exactly seven ways to serve all
///     three at once.
const List<PrismChamber> kPrismChambers = [
  PrismChamber(
    id: 'hearth',
    name: 'the Shard Hearth',
    facets: kFacetN | kFacetE | kFacetS | kFacetW,
    bend: 0,
    argb: 0xFFE0A44C,
  ),
  PrismChamber(
    id: 'cinnabar',
    name: 'the Crimson Throne',
    facets: kFacetN | kFacetS | kFacetW,
    bend: 3,
    argb: 0xFF9E3B2E,
    throne: true,
  ),
  PrismChamber(
    id: 'beryl',
    name: 'the Verdant Throne',
    facets: kFacetE | kFacetW,
    bend: 4,
    argb: 0xFF3E7A5A,
    throne: true,
  ),
  PrismChamber(
    id: 'lazuli',
    name: 'the Azure Throne',
    facets: kFacetN | kFacetE | kFacetW,
    bend: 5,
    argb: 0xFF34558C,
    throne: true,
  ),
  PrismChamber(
    id: 'citrine',
    name: 'the Amber Cell',
    facets: kFacetE | kFacetS | kFacetW,
    bend: 1,
    argb: 0xFFB98A2E,
  ),
  PrismChamber(
    id: 'selenite',
    name: 'the Pale Cell',
    facets: kFacetN | kFacetE | kFacetS,
    bend: 2,
    argb: 0xFFAEB7BC,
  ),
  PrismChamber(
    id: 'amethyst',
    name: 'the Violet Cell',
    facets: kFacetN | kFacetE | kFacetW,
    bend: 7,
    argb: 0xFF6B4A8C,
  ),
  PrismChamber(
    id: 'onyx',
    name: 'the Black Cell',
    facets: kFacetN | kFacetW,
    bend: 11,
    argb: 0xFF2A2733,
  ),
  // ── outside the lattice ──
  PrismChamber(
    id: 'waiting',
    name: 'the Waiting Facet',
    // ONE doorway, west. This is the vault trick's whole geometry: the facet
    // can only ever be walked into from the middle cell.
    facets: kFacetW,
    bend: 0,
    argb: 0xFFD8C48A,
  ),
];

int _chamberIndex(String id) {
  for (var i = 0; i < kPrismChambers.length; i++) {
    if (kPrismChambers[i].id == id) return i;
  }
  return -1;
}

/// The arrangement the keep opens in, and the one THE ANNEAL rings back to.
///
/// Chosen so that neither star is already half-solved on arrival (the beam is
/// blocked at the west cell by opaque cinnabar; the hearth stands in the
/// heart cell but not one of its three thrones can face it), and so that the
/// threshold cell carries a chamber, which is what lets a first descent walk
/// in at all.
const List<int> kKeepOpeningCells = [
  7, 4, 5, // onyx     citrine   selenite
  1, 0, 6, // cinnabar hearth    amethyst
  3, 2, kHollow, // lazuli   beryl     ·
];

// ─────────────────────────────────────────────────────────
// THE FIELD — the pure, headless rules
// ─────────────────────────────────────────────────────────

/// Vitrea's whole sliding rule set, as rules with no engine in them.
///
/// THE ONE INVARIANT, and the reason this is testable in isolation: the keep's
/// entire state is [cells] plus [hollowBerthed]. Everything else — which
/// arches are walkable, whether the beam reaches the rose, whether the thrones
/// are served, whether the vault can be called — is DERIVED. So a state is a
/// nine-slot arrangement, and the reachability search in the test can
/// enumerate the state space exactly, against this class and no model of it.
class PrismKeepField {
  /// What stands in each cell: a [kPrismChambers] index, or [kHollow].
  final List<int> cells = List<int>.from(kKeepOpeningCells);

  /// The hollow has gone out to the east berth and the waiting facet has come
  /// in to the mouth cell. While this is true the keep is FULL and no shunt
  /// is legal anywhere — the map is set solid (§5.5 vault trick).
  bool hollowBerthed = false;

  /// The west lamp, kindled (**Crystal+Spirit→Light**, §6.10). No lamp, no
  /// beam, no Prism Star.
  bool lampLit = false;

  /// The hearth's shard, struck warm — the planet's Lightning+HORN gate.
  bool hearthKindled = false;

  /// How many shunts this run has cost. Not a budget (nothing runs out — that
  /// seat is Steam's); a readout, and the counter the ringing draws off.
  int shunts = 0;

  /// How many times THE ANNEAL has run (the valve's price, and a readout).
  int anneals = 0;

  void reset() {
    cells
      ..clear()
      ..addAll(kKeepOpeningCells);
    hollowBerthed = false;
    lampLit = false;
    hearthKindled = false;
    shunts = 0;
    anneals = 0;
  }

  /// The cell the hollow stands in, or −1 while it is out in the berth.
  int get hollowCell {
    if (hollowBerthed) return -1;
    return cells.indexOf(kHollow);
  }

  /// Which cell [chamberIndex] stands in, or −1 if it is not in the lattice.
  int cellOf(int chamberIndex) => cells.indexOf(chamberIndex);

  PrismChamber? chamberAt(int cell) {
    if (cell < 0 || cell > 8) return null;
    final c = cells[cell];
    return c == kHollow ? null : kPrismChambers[c];
  }

  // ── THE SHUNT ────────────────────────────────────────────

  /// A chamber trades places with the hollow, and so does whoever is standing
  /// at the boundary — from inside the chamber (you ride it across) or from
  /// inside the socket (you stay with the hollow). One rule, stated once: THE
  /// PAIR EXCHANGES, AND SO DO YOU. This is the whole move set, and it is why
  /// the reachable arrangements are an orbit of the alternating group rather
  /// than all of them (see the file header's parity note).
  bool canShunt(int fromCell) {
    final h = hollowCell;
    return h >= 0 && _adjacent(fromCell, h);
  }

  /// Trade the chamber standing in [chamberCell] with the hollow. Returns the
  /// cell the hollow ends up in, or −1 if the move is illegal.
  int shunt(int chamberCell) {
    final h = hollowCell;
    if (h < 0 || !_adjacent(chamberCell, h)) return -1;
    cells[h] = cells[chamberCell];
    cells[chamberCell] = kHollow;
    shunts++;
    return h;
  }

  // ── WALKING — the adjacency the whole planet is about ────

  /// Is the arch between [a] and [b] walkable right now?
  ///
  /// Between two CHAMBERS: both must be cut on the face they meet at. No door
  /// is opened or closed by a slide — only aligned or mis-aligned, which is
  /// §5.5's "every slide solves one adjacency and breaks another", and it is
  /// the whole difficulty of the planet.
  ///
  /// Between a chamber and THE HOLLOW: only the chamber's own facet is asked
  /// for. The hollow is not nothing — it is the keep's bare socket, the frame's
  /// stone floor with the works showing through a grille — and an empty socket
  /// has no glass to disagree with. That is also why the socket is the one
  /// place in the keep a body can move freely from: standing in it, you can
  /// haul any neighbour in and stay with the hollow as it goes. The 15-puzzle's
  /// oldest interaction, and without it a first descent is locked into
  /// oscillating between two arrangements (measured: 2 of 181,440 — the search
  /// in the test caught exactly this).
  bool passable(int a, int b) {
    if (!_adjacent(a, b)) return false;
    final ca = chamberAt(a), cb = chamberAt(b);
    if (ca == null && cb == null) return false; // cannot happen: one hollow
    if (ca == null) return cb!.cut(keepFacetToward(b, a));
    if (cb == null) return ca.cut(keepFacetToward(a, b));
    return ca.cut(keepFacetToward(a, b)) && cb.cut(keepFacetToward(b, a));
  }

  /// The south threshold and the north arch are cut in the keep's own FRAME,
  /// not in any chamber's glass, so they never shut: they open onto whatever
  /// is in the cell, chamber or bare socket alike. Kept as a named rule
  /// because it is the reason the party can never be locked out of the keep
  /// by Prismalith's beats moving the hollow while they are downstairs.
  bool frameArchOpen(int cell) => cell >= 0 && cell <= 8;

  // ── STAR 0 · THE PRISM — the lamp, the row, the rose ─────

  /// The beam crosses the middle row west to east and stops at the first
  /// glass that is not cut on both of those faces.
  bool get beamLive {
    if (!lampLit) return false;
    for (final c in kKeepBeamRow) {
      final ch = chamberAt(c);
      if (ch == null || !ch.clear) return false;
    }
    return true;
  }

  /// How far the beam has been bent by the time it reaches the rose. Bends
  /// add, so this is a question about WHICH chambers stand in the row, never
  /// about the order they stand in.
  int get beamHue {
    var h = 0;
    for (final c in kKeepBeamRow) {
      final ch = chamberAt(c);
      if (ch == null) continue;
      h += ch.bend;
    }
    return h % 12;
  }

  bool get spectrumSolved => beamLive && beamHue == kRoseHue;

  // ── STAR 1 · THE THRONES — one hearth, three faces ───────

  /// Every throne, served: the Shard Hearth stands in the heart cell, its
  /// shard struck warm, and all three thrones stand on faces of it that are
  /// open. The heart is the only cell with four neighbours, so three at once
  /// is the tightest thing this keep can be asked for.
  bool get thronesServed {
    if (!hearthKindled) return false;
    if (cells[kKeepHeartCell] != _hearthIndex) return false;
    for (var i = 0; i < kPrismChambers.length - 1; i++) {
      if (!kPrismChambers[i].throne) continue;
      final at = cellOf(i);
      if (at < 0 || !passable(kKeepHeartCell, at)) return false;
    }
    return true;
  }

  static final int _hearthIndex = _chamberIndex('hearth');

  /// How many thrones currently stand served (the progress readout).
  int get thronesStanding {
    if (cells[kKeepHeartCell] != _hearthIndex) return 0;
    var n = 0;
    for (var i = 0; i < kPrismChambers.length - 1; i++) {
      if (!kPrismChambers[i].throne) continue;
      final at = cellOf(i);
      if (at >= 0 && passable(kKeepHeartCell, at)) n++;
    }
    return n;
  }

  // ── THE BERTH — the vault's one configuration ────────────

  /// The berth chain bites only when the hollow has come to rest in the mouth
  /// cell and somebody stands next to it to pull. Leaving the hollow there
  /// means shunting OUT of the mouth, so the puller is always one of the
  /// mouth's neighbours — and only the one to the WEST can then walk in.
  bool canCallFacet(int fromCell) =>
      !hollowBerthed &&
      hollowCell == kKeepMouthCell &&
      _adjacent(fromCell, kKeepMouthCell);

  /// Draw the waiting facet in. The hollow goes out to the berth in its place
  /// and the keep is set solid until it is sent back.
  bool callFacet(int fromCell) {
    if (!canCallFacet(fromCell)) return false;
    cells[kKeepMouthCell] = kWaitingFacet;
    hollowBerthed = true;
    return true;
  }

  /// Send it back. Legal from the facet itself or from any cell beside the
  /// mouth, which is why the vault can never wedge a run: whatever you walked
  /// to get in, you can walk back, and from there the keep moves again.
  bool canWithdrawFacet(int fromCell) =>
      hollowBerthed &&
      (fromCell == kKeepMouthCell || _adjacent(fromCell, kKeepMouthCell));

  bool withdrawFacet(int fromCell) {
    if (!canWithdrawFacet(fromCell)) return false;
    cells[kKeepMouthCell] = kHollow;
    hollowBerthed = false;
    return true;
  }

  bool get facetStanding => hollowBerthed;

  // ── THE ANNEAL — the valve ───────────────────────────────

  /// Ring the keep back to the arrangement it opened in — and put the ringer
  /// OUT, on the oriel below the south face.
  ///
  /// Being set down outside is not flavour, it is the whole point of the
  /// valve. Vitrea's one way to jam is a body standing in a chamber whose cut
  /// faces both happen to give onto the outer frame — the Black Cell in a
  /// corner does exactly that — with the hollow out of reach. An anneal that
  /// carried the ringer with their own chamber would set them back down in the
  /// same trap forever (measured: the reachability search caught precisely
  /// this, on the opening arrangement's north-west corner). Throwing them
  /// clear makes the valve total: from any state whatsoever, one ring returns
  /// the run to the exact state it began in.
  void anneal() {
    cells
      ..clear()
      ..addAll(kKeepOpeningCells);
    hollowBerthed = false;
    anneals++;
  }

  /// Prismalith's beat (§7): the keep above shunts itself one step. Picks the
  /// lowest-indexed neighbour of the hollow so the fight is deterministic and
  /// testable. No-op while the waiting facet has the keep set solid.
  int guardianShunt() {
    final h = hollowCell;
    if (h < 0) return -1;
    final n = keepNeighbours(h).first;
    shunt(n);
    return n;
  }

  /// A snapshot of the arrangement, for tests and the reachability search.
  List<int> snapshot() => List<int>.from(cells);

  void restore(List<int> snap, {bool berthed = false}) {
    cells
      ..clear()
      ..addAll(snap);
    hollowBerthed = berthed;
  }
}

// ─────────────────────────────────────────────────────────
// PER-ROOM CRYSTAL CONTENT
// ─────────────────────────────────────────────────────────

/// This room IS one of the keep's nine cells.
class PrismCell {
  /// 0..8, row-major (see [kKeepCellRooms]).
  final int index;

  const PrismCell(this.index);
}

/// Where Vitrea declares its two non-guardian stars.
///
/// Neither star belongs to a room: the Prism Star is a fact about the middle
/// ROW and the Throne Star a fact about the heart cell's four faces, and both
/// can complete while the player stands anywhere in the keep. So they are
/// declared once, on the oriel — the balcony the whole keep is seen from —
/// exactly as Poison declares both of its on the prior's seal and Mud both of
/// its on the sinking altar's socket.
class PrismKeep {
  final int spectrumStarIndex;
  final int throneStarIndex;

  const PrismKeep({
    required this.spectrumStarIndex,
    required this.throneStarIndex,
  });
}

/// Prismalith's choir floor (§7 — the guardian fights WITH the planet's rule).
/// Nine glass plates and one missing one, laid out exactly like the keep. The
/// mystic's root is only exposed over the gap, and every strike beat the floor
/// shunts itself and the keep upstairs shunts with it.
class ChoirFloor {
  final Offset origin;
  final double plateWidth;
  final double plateHeight;

  const ChoirFloor({
    required this.origin,
    this.plateWidth = 260,
    this.plateHeight = 170,
  });

  Rect plateRect(int cell) => Rect.fromLTWH(
    origin.dx + (cell % 3) * plateWidth,
    origin.dy + (cell ~/ 3) * plateHeight,
    plateWidth,
    plateHeight,
  );

  Offset plateCentre(int cell) => plateRect(cell).center;

  /// Which plate [p] stands on, or −1 when it is off the floor.
  int cellAt(Offset p) {
    for (var i = 0; i < 9; i++) {
      if (plateRect(i).contains(p)) return i;
    }
    return -1;
  }
}

/// Everything the Prism Labyrinth puts in one room. ONE field on the shared
/// room model (the Ice/Mud precedent), because the keep's own lattice is
/// authored whole in this file rather than per room.
class PrismHall {
  /// This room is a keep cell.
  final PrismCell? cell;

  /// This room declares the keep's two non-guardian stars.
  final PrismKeep? keep;

  /// The keep's unbroken face — the entry rite. Lightning cracks it.
  final Offset? glassFace;

  /// A tuning boss: THE ANNEAL, the valve. Authored for the rooms outside the
  /// lattice; every cell has one at a fixed place in its frame, so the cells
  /// do not repeat it nine times.
  final Offset? annealRing;

  /// The rite's second half — the facet font, element-only Crystal.
  final Offset? facetFont;

  /// Prismalith's shunting floor.
  final ChoirFloor? choir;

  const PrismHall({
    this.cell,
    this.keep,
    this.glassFace,
    this.annealRing,
    this.facetFont,
    this.choir,
  });
}

// ─────────────────────────────────────────────────────────
// CELL FURNITURE — fixed in the FRAME, so it does not travel
// ─────────────────────────────────────────────────────────
// Every cell room is the same 420×340 box, so a chamber's furniture can be
// drawn at chamber-relative coordinates and simply appear in whichever cell
// the chamber now stands in. The FRAME's furniture — the shove-plates, the
// tuning boss, the berth chain — stays with the cell. That split is the
// clearest possible statement of the rule, and the player reads it in about
// four seconds.

const Size kKeepCellSize = Size(420, 340);

/// Where a chamber's own fixture stands (hearth shard, throne, and the
/// centre of the light band).
const Offset kChamberHeart = Offset(210, 170);

/// The shove-plates, one per wall. A Crystal hand on the plate facing the
/// hollow shoves this chamber that way — and rides it.
const Offset kPlateN = Offset(210, 40);
const Offset kPlateE = Offset(380, 170);
const Offset kPlateS = Offset(210, 300);
const Offset kPlateW = Offset(40, 170);

/// The frame's tuning boss (THE ANNEAL), in every cell's south-west corner.
const Offset kCellTuningBoss = Offset(60, 300);

/// The berth chain, in the three cells that can see the berth's mouth.
const Offset kBerthChain = Offset(340, 300);

/// The west lamp, on the frame outside the west-middle cell.
const Offset kWestLamp = Offset(26, 170);

/// The east rose, on the frame outside the east-middle cell.
const Offset kEastRose = Offset(394, 170);

/// The band the lamp's light lies in, across a middle-row cell.
const Rect kBeamBand = Rect.fromLTWH(0, 148, 420, 44);

/// The plate the shove-plate for [facet] stands on.
Offset keepPlateFor(int facet) => switch (facet) {
  kFacetN => kPlateN,
  kFacetE => kPlateE,
  kFacetS => kPlateS,
  _ => kPlateW,
};

// ─────────────────────────────────────────────────────────
// COPY
// ─────────────────────────────────────────────────────────

/// Vitrea's lost maxim discovery id and its verse (§6 easter eggs #11).
const String kCrystalKnowThyselfEggId = 'egg:crystal_know_thyself';
const String kCrystalKnowThyselfMaxim =
    'KNOW THYSELF — the split throws back three shapes, and all of them '
    'are yours';

// ─────────────────────────────────────────────────────────
// THE LAYOUT
// ─────────────────────────────────────────────────────────

/// Vitrea — the Prism Labyrinth.
const DungeonLayout crystalLayout = DungeonLayout(
  element: 'Crystal',
  entranceRoomId: 'facet_gate',
  entranceSpawn: Offset(140, 300),
  title: 'THE PRISM LABYRINTH',
  descentTitle: 'Vitrea Keep',
  stars: [
    DungeonStarSpec(
      name: 'Prism Star',
      earnAnnouncement:
          'The Prism Star is yours — the rose reads the hue it was cut for',
    ),
    DungeonStarSpec(
      name: 'Throne Star',
      earnAnnouncement:
          'The Throne Star is yours — three thrones stand served at once',
    ),
    DungeonStarSpec(name: 'Facet Star'),
  ],
  // The keep's face is one unbroken sheet until Lightning cracks it.
  entranceRevealDoor: DungeonDoorRef('facet_gate', 'keep_s'),
  finaleDoor: DungeonDoorRef('keep_n', 'tuning_hall'),
  riteAnnouncement:
      'Prism and Throne are won — the north arch grinds open on the tuning '
      'hall',
  finaleSealedHint:
      'The north arch is shut — it answers the Prism and the Throne',
  guardianSealedHint:
      'The choir is dark glass — nothing in there wakes until the font is '
      'struck',
  mercyShrineRoomId: 'facet_gate',
  // Ideal: Crystalmask · Lightninghorn · Spiritpip — hinted by VERB, never by
  // body part (§4): the second sight that reads which glass will pass a light,
  // the strongest grip, and what the smallest doors admit.
  riddle: [
    'Send me a Crystal MASK, to read which of my glasses will pass a light;',
    'a Lightning HORN, to strike a cold shard warm;',
    'and a Spirit PIP, to slip the crack behind the keep.',
  ],
  // §4 budget: TWO hard gates, on two different entry slots.
  //
  // §6.10 nominally hung a Crystalmask gate on its first star. §4 wins and the
  // gate is MOVED: at least one star per planet must be earnable by ANY trio
  // of the correct elements, and the Prism Star is that star here — the lamp
  // is kindled by the planet's own braid **Crystal+Spirit→Light**, which any
  // Crystal/Lightning/Spirit trio can make, and everything else about it is
  // the element-only shunt. Crystal's Mask keeps its §6.10 job as the reader
  // of glass, but as tiered INSIGHT (§5.6), which is never a gate.
  familyGates: [
    DungeonFamilyGate(
      objectId: 'shard_hearth',
      element: 'Lightning',
      family: 'Horn',
      hintLine: 'Only a horn\'s strike will kindle this shard',
    ),
    DungeonFamilyGate(
      objectId: 'A',
      element: kAnyElement,
      family: 'Pip',
      hintLine: 'Only the smallest slips into this crack',
    ),
  ],
  rooms: {
    // ── THE ORIEL (entrance · mercy · the whole keep in view) ─
    // A balcony under the keep's south face. From here the lattice is one
    // picture, which is the only tutorial this planet gets.
    'facet_gate': DungeonRoom(
      id: 'facet_gate',
      bounds: Rect.fromLTWH(0, 0, 760, 520),
      walls: [
        Rect.fromLTWH(280, 190, 200, 30), // the old sighting bench
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(325, 0, 110, 24),
          targetRoomId: 'keep_s',
          targetSpawn: Offset(210, 250),
        ),
      ],
      prism: PrismHall(
        keep: PrismKeep(spectrumStarIndex: 0, throneStarIndex: 1),
        glassFace: Offset(380, 70),
        annealRing: Offset(110, 420),
      ),
    ),

    // ── THE NINE CELLS ────────────────────────────────────
    // ── CELL 0 · NW ──
    'keep_nw': DungeonRoom(
      id: 'keep_nw',
      bounds: Rect.fromLTWH(0, 0, 420, 340),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(155, 316, 110, 24),
          targetRoomId: 'keep_w',
          targetSpawn: Offset(210, 90),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(396, 128, 24, 110),
          targetRoomId: 'keep_n',
          targetSpawn: Offset(64, 170),
        ),
      ],
      prism: PrismHall(cell: PrismCell(0)),
    ),

    // ── CELL 1 · N ──
    'keep_n': DungeonRoom(
      id: 'keep_n',
      bounds: Rect.fromLTWH(0, 0, 420, 340),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(155, 316, 110, 24),
          targetRoomId: 'keep_core',
          targetSpawn: Offset(210, 90),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 128, 24, 110),
          targetRoomId: 'keep_nw',
          targetSpawn: Offset(356, 170),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(396, 128, 24, 110),
          targetRoomId: 'keep_ne',
          targetSpawn: Offset(64, 170),
        ),
        // THE NORTH ARCH — likewise frame-cut. The rite lies beyond it.
        DungeonDoor(
          rect: Rect.fromLTWH(155, 0, 110, 24),
          targetRoomId: 'tuning_hall',
          targetSpawn: Offset(320, 330),
        ),
      ],
      prism: PrismHall(cell: PrismCell(1)),
    ),

    // ── CELL 2 · NE ──
    'keep_ne': DungeonRoom(
      id: 'keep_ne',
      bounds: Rect.fromLTWH(0, 0, 420, 340),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(155, 316, 110, 24),
          targetRoomId: 'keep_e',
          targetSpawn: Offset(210, 90),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 128, 24, 110),
          targetRoomId: 'keep_n',
          targetSpawn: Offset(356, 170),
        ),
      ],
      prism: PrismHall(cell: PrismCell(2)),
    ),

    // ── CELL 3 · W ──
    'keep_w': DungeonRoom(
      id: 'keep_w',
      bounds: Rect.fromLTWH(0, 0, 420, 340),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(155, 0, 110, 24),
          targetRoomId: 'keep_nw',
          targetSpawn: Offset(210, 250),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(155, 316, 110, 24),
          targetRoomId: 'keep_sw',
          targetSpawn: Offset(210, 90),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(396, 128, 24, 110),
          targetRoomId: 'keep_core',
          targetSpawn: Offset(64, 170),
        ),
      ],
      prism: PrismHall(cell: PrismCell(3)),
    ),

    // ── CELL 4 · CORE (the heart) ──
    'keep_core': DungeonRoom(
      id: 'keep_core',
      bounds: Rect.fromLTWH(0, 0, 420, 340),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(155, 0, 110, 24),
          targetRoomId: 'keep_n',
          targetSpawn: Offset(210, 250),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(155, 316, 110, 24),
          targetRoomId: 'keep_s',
          targetSpawn: Offset(210, 90),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 128, 24, 110),
          targetRoomId: 'keep_w',
          targetSpawn: Offset(356, 170),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(396, 128, 24, 110),
          targetRoomId: 'keep_e',
          targetSpawn: Offset(64, 170),
        ),
      ],
      prism: PrismHall(cell: PrismCell(4)),
    ),

    // ── CELL 5 · E (the berth's mouth) ──
    'keep_e': DungeonRoom(
      id: 'keep_e',
      bounds: Rect.fromLTWH(0, 0, 420, 340),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(155, 0, 110, 24),
          targetRoomId: 'keep_ne',
          targetSpawn: Offset(210, 250),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(155, 316, 110, 24),
          targetRoomId: 'keep_se',
          targetSpawn: Offset(210, 90),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 128, 24, 110),
          targetRoomId: 'keep_core',
          targetSpawn: Offset(356, 170),
        ),
      ],
      prism: PrismHall(cell: PrismCell(5)),
      // The vault's essence rides in the WAITING FACET, and the facet can
      // only ever stand in this one cell (§5.5). The engine keeps the cache
      // dark and unclaimable until the facet is actually standing here —
      // see `_keepVaultLive` in planet_dungeon_game_crystal.dart.
      vaultCache: Offset(210, 232),
    ),

    // ── CELL 6 · SW ──
    'keep_sw': DungeonRoom(
      id: 'keep_sw',
      bounds: Rect.fromLTWH(0, 0, 420, 340),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(155, 0, 110, 24),
          targetRoomId: 'keep_w',
          targetSpawn: Offset(210, 250),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(396, 128, 24, 110),
          targetRoomId: 'keep_s',
          targetSpawn: Offset(64, 170),
        ),
      ],
      prism: PrismHall(cell: PrismCell(6)),
    ),

    // ── CELL 7 · S (the threshold) ──
    'keep_s': DungeonRoom(
      id: 'keep_s',
      bounds: Rect.fromLTWH(0, 0, 420, 340),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(155, 0, 110, 24),
          targetRoomId: 'keep_core',
          targetSpawn: Offset(210, 250),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 128, 24, 110),
          targetRoomId: 'keep_sw',
          targetSpawn: Offset(356, 170),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(396, 128, 24, 110),
          targetRoomId: 'keep_se',
          targetSpawn: Offset(64, 170),
        ),
        // THE THRESHOLD — the oriel's own arch, cut in the keep's FRAME and
        // not in any chamber's glass, so crossing it asks only that something
        // stands here to be walked onto.
        DungeonDoor(
          rect: Rect.fromLTWH(155, 316, 110, 24),
          targetRoomId: 'facet_gate',
          targetSpawn: Offset(380, 120),
        ),
      ],
      prism: PrismHall(cell: PrismCell(7)),
    ),

    // ── CELL 8 · SE ──
    'keep_se': DungeonRoom(
      id: 'keep_se',
      bounds: Rect.fromLTWH(0, 0, 420, 340),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(155, 0, 110, 24),
          targetRoomId: 'keep_e',
          targetSpawn: Offset(210, 250),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 128, 24, 110),
          targetRoomId: 'keep_s',
          targetSpawn: Offset(356, 170),
        ),
      ],
      prism: PrismHall(cell: PrismCell(8)),
    ),

    // ── THE TUNING HALL (the rite) ────────────────────────
    // Conduit A is the planet's Spirit+PIP gate — the hairline crack behind
    // the keep, which only the smallest body slips into. The font is the
    // rite's other half: element-only Crystal, so a party that brought no Pip
    // meets exactly ONE refusal here rather than two (the Ice precedent).
    'tuning_hall': DungeonRoom(
      id: 'tuning_hall',
      bounds: Rect.fromLTWH(0, 0, 640, 460),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(265, 436, 110, 24),
          targetRoomId: 'keep_n',
          targetSpawn: Offset(210, 90),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(265, 0, 110, 24),
          targetRoomId: 'prismalith_choir',
          targetSpawn: Offset(450, 460),
        ),
      ],
      conduits: [
        Conduit(
          id: 'A',
          position: Offset(200, 250),
          // VERB-ONLY: the crack admits a small body; spirit is not
          // what fits through it.
          requireElement: kAnyElement,
          requiredFamily: DungeonAbility.smallAccess,
        ),
        // Conduit 'B' is NOT authored as a Conduit: it is the facet font
        // below, an element-only Crystal object this planet's module owns and
        // which latches `conduitEnergy['B']` itself (the Ice precedent —
        // authoring it family-less would make the shared channel verb step
        // over it and the layout invariants read it as a storm-struck pylon
        // with no storm).
      ],
      prism: PrismHall(
        facetFont: Offset(440, 250),
        annealRing: Offset(80, 400),
      ),
    ),

    // ── PRISMALITH'S CHOIR (Star 2) ───────────────────────
    // §7 — the guardian fights WITH the planet's rule. The choir floor is the
    // keep in miniature: nine plates and one gap. Prismalith's root only
    // shows over the gap, so the lull opens when the gap stands under it —
    // and every strike beat the floor shunts itself away AND the keep
    // upstairs shunts with it. It spends the map you made while you fight.
    'prismalith_choir': DungeonRoom(
      id: 'prismalith_choir',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 616, 110, 24),
          targetRoomId: 'tuning_hall',
          targetSpawn: Offset(320, 150),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(450, 315),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Crystal',
          mysticId: 'Prismalith',
          canCalm: true,
          canDefeat: true,
        ),
      ),
      prism: PrismHall(
        choir: ChoirFloor(origin: Offset(60, 60)),
        annealRing: Offset(830, 596),
      ),
    ),
  },
);
