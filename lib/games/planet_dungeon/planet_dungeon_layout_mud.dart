// lib/games/planet_dungeon/planet_dungeon_layout_mud.dart
//
// PALUSIA — THE SINKING ALTAR. Mud's authored layout AND its pure, headless
// terraforming rules (the burn_field.dart / WardTriage treatment: the engine,
// the renderer and the no-strand proof all reason about ONE copy of
// [BogField], so "can this run still be finished" is answered by the shipped
// code and never by a model of it).
//
// ─────────────────────────────────────────────────────────
// WHAT docs/dungeons.md CLAIMS FOR MUD, AND HOW THIS ANSWERS IT
// ─────────────────────────────────────────────────────────
// §5.5 structural assignment table, Mud row:
//   topology  — "Shifting field: one huge open bog, no fixed rooms — islands
//               whose connections you terraform"
//   question  — "every path you harden sinks another — shape the map you'll
//               have to live with"
//   vault     — "let the vault knoll SINK, ride it down to the drowned level"
//   mechanic  — "irreversible sacrifice choice" (shared with Poison)
// §6.8 fixes the flavour: *Sinking Altar · Mud+Plant+Water ·
// Mudmane/Plantpip/Watermask · ground firmness changes everything*, with
// "Water softens / roots harden", the three altars, and **Plant+Mud→Poison**
// dissolving seals.
//
// TOPOLOGY — THE QUAKING FIELD. The convention this planet breaks is not
// that rooms exist; it is that the EDGES are constants. Every other planet
// hands you a room graph and asks you to walk it. Palusia hands you seven
// knolls floating on one continuous fen and NO given connections worth the
// name: the fen is crossed at FORDS, and what a ford is — wadeable mire,
// dragged sod, or open water — is authored by the player, once, for the run.
// There is no hub, no wing, no corridor and no door frame anywhere in the
// bog: every "door" between knolls is a crossing of open ground, and the map
// you are walking at minute twenty is one you made.
//
// THE WORLD RULE — *the fen is one water table.* Dragging a ford solid
// squeezes the water it held out along its own SLOUGH (its watercourse), and
// it rises in the crossings immediately up- and downstream. So:
//
//   • MIRE (untouched) — wadeable by anybody, and it will bear a walker but
//     never a load.
//   • SOD (dragged)    — a raised, root-knit causeway. It bears the sarsen.
//     Permanent: the mud that made it came from somewhere and is not coming
//     back.
//   • DROWNED          — open water. Nothing crosses it, ever again.
//
// Hardening a ford drowns the SOFT fords adjacent to it along its slough. A
// ford already dragged to sod is immune (sod stands; the water goes round).
// Two consequences fall straight out, and they are the whole planet:
//   1. The set of fords you can ever harden is an INDEPENDENT SET in each
//      slough's chain — no two neighbours, ever, in any order.
//   2. ORDER IS IRRELEVANT. Hardening A then B reaches exactly the same fen
//      as B then A. This is the deliberate, load-bearing distinction from
//      Air's claimed row (§5.5: "irreversible wind-authoring — a permanent
//      world-edit whose ORDERING is the whole question"). Here ordering is
//      nothing and SHAPE is everything: which set, and what the fen looks
//      like once you have to live in it.
//
// LEDGER (§5.5 "irreversible sacrifice choice", shared with Poison — BUILT).
// Poison's triage is a COUNT: three cures, four wards, pick the one you
// abandon; the objects are interchangeable and the geometry is irrelevant.
// Mud's sacrifice is STRUCTURAL and local: you never choose what to give up,
// you choose what to KEEP, and the fen's own drainage decides what dies for
// it. Nor is it Steam's budget (no global number is spent anywhere), Dust's
// conservation (nothing is relocated — the water is not a resource you place)
// or Fire's consuming process (nothing eats your trail; the cost lands
// somewhere else on the map, at once).
//
// VISUAL GRAMMAR (§5.5, and the Steam NOTE at §6.6: "Mud's reshaping should
// drag/flow terrain" and must read NOTHING like Steam's tile floods). There
// is not a tile anywhere in this planet. A slough is a long flowing ribbon
// drawn as a bezier through the fen; a drag is a viscous SMEAR that travels
// out along that ribbon and visibly SLUMPS its neighbours; sod is a raised
// bank with tussock fringe. Everything is strokes and curves, nothing is a
// grid cell, and no MaskFilter.blur is used anywhere (the game's known jank
// source).
//
// THE VAULT TRICK (§5.5: "let the vault knoll SINK, ride it down to the
// drowned level"). A knoll floats on the peat and the fords are what moor it.
// Drown every ford that touches a knoll and it is ADRIFT — nothing holds it,
// and it will not hold you. The Lotus Knoll is moored by two fords and also
// reached by the peat-cutters' PLANK ROAD, a rotten boardwalk laid ON the
// water: a plank road carries a walker but moors nothing. So the vault is an
// INDUCED MAP STATE — cut the lotus's two fords (one hardening does it), walk
// the plank, and the knoll founders under your weight and carries you down to
// the bowl in the drowned fane, where the bottled essence lies. It is not a
// side room behind a signature door, and it is not Ice's unrepeatable slide:
// it is a configuration of the map that you have to want, and it COSTS the
// Moor Star for that shape (proved in the test) — the two demands are exact
// opposites of one another.
//
// THE ANTI-STRAND VALVE, and the one place this file adds to the brief.
// Irreversible map editing is a stranding machine — 47 of the 125 legal fen
// shapes leave the bog walk-disconnected (pinned in the test). Per the Ice
// precedent, the answer is a COSTLY RESET rather than a softer mechanic:
//   · THE WALLOW — every knoll has a soft eye at its heart. A Mud creature
//     going limp in it lets the fen swallow the party down into the DROWNED
//     FANE. Always available, on every knoll, from any state.
//   · THE SOUGH — the fen's own outfall, in the fane. A Mud hand pulls its
//     peat plug and the whole bog HEAVES: every ford you dragged is soup
//     again, every drowned channel runs clear, the lotus rises, and the
//     sarsen washes back to the mire gate. You climb out at whichever wallow
//     you like — and you climb out into a fen with nothing in it that you
//     made. A do-over, never a shortcut.
// The mechanic stays exactly as harsh as the brief demands; the fen simply
// cannot lock you out of the run.
//
// The fixture classes live here (rather than in planet_dungeon_data.dart with
// the older planets') so this planet's diff against shared files stays to a
// handful of additive lines while other elements are built in parallel.

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart'
    show GuardianEncounterRequirement;

// ─────────────────────────────────────────────────────────
// THE FEN — fords and sloughs
// ─────────────────────────────────────────────────────────

/// What a crossing is right now. See the file header for the trade.
enum BogFordState {
  /// Untouched quaking mire. Wadeable; will not bear the sarsen.
  mire,

  /// Dragged into a root-knit causeway. Bears anything. Permanent.
  sod,

  /// Open water. Impassable, and it never comes back.
  drowned,
}

/// One crossing of the fen: which two knolls it joins, which watercourse it
/// sits on, and where you stand on each bank to work it.
class BogFord {
  final String id;

  /// The two knolls (room ids) this crossing joins.
  final String knollA;
  final String knollB;

  /// The watercourse this crossing sits on. Hardening a ford backs its water
  /// up into the crossings adjacent to it ON THIS SLOUGH and nowhere else.
  final String slough;

  /// Position along [slough], head to mouth. Adjacent indices are neighbours.
  final int index;

  /// Where the drag verb is worked, standing on [knollA] / [knollB].
  final Offset headA;
  final Offset headB;

  const BogFord({
    required this.id,
    required this.knollA,
    required this.knollB,
    required this.slough,
    required this.index,
    required this.headA,
    required this.headB,
  });

  String? other(String knollId) => knollId == knollA
      ? knollB
      : knollId == knollB
      ? knollA
      : null;

  Offset? headIn(String knollId) => knollId == knollA
      ? headA
      : knollId == knollB
      ? headB
      : null;

  bool touches(String knollId) => knollId == knollA || knollId == knollB;
}

/// The names the fen's three watercourses wear, for copy and rendering.
const Map<String, String> kSloughNames = {
  'cor': 'the Cormorant',
  'add': 'the Adder',
  'tarn': 'the Tarn',
};

/// The fen's nine crossings, authored as ONE list rather than per room, so
/// the no-strand proof walks exactly the graph the doors are built from and
/// the two can never disagree (the Ice precedent).
///
/// THE SHAPE, and why it is this shape. Each knoll touches at most one
/// crossing per slough, so no knoll is structurally undryable; the three
/// moor-altars (sedge, cairn, lotus) between them demand exactly
/// {cor_tail, add_tail, tarn_head, tarn_tail} — and those four fords are also
/// a continuous sod road from the mire gate to the Sinking Altar. **The choir
/// tells you the road.** Every SHORT road (add_neck, or cor_neck) drowns a
/// ford the choir needs and kills the Moor Star for that shape, permanently.
/// That is the strategic question, stated in geometry.
const List<BogFord> kBogFords = [
  // ── the Cormorant, head to mouth ──
  BogFord(
    id: 'cor_head',
    knollA: 'mire_gate',
    knollB: 'hag_knoll',
    slough: 'cor',
    index: 0,
    headA: Offset(620, 105),
    headB: Offset(70, 125),
  ),
  BogFord(
    id: 'cor_neck',
    knollA: 'reed_knoll',
    knollB: 'altar_knoll',
    slough: 'cor',
    index: 1,
    headA: Offset(570, 215),
    headB: Offset(70, 305),
  ),
  BogFord(
    id: 'cor_tail',
    knollA: 'sedge_knoll',
    knollB: 'lotus_knoll',
    slough: 'cor',
    index: 2,
    headA: Offset(530, 220),
    headB: Offset(70, 220),
  ),
  // ── the Adder, head to mouth ──
  BogFord(
    id: 'add_head',
    knollA: 'mire_gate',
    knollB: 'reed_knoll',
    slough: 'add',
    index: 0,
    headA: Offset(620, 240),
    headB: Offset(70, 215),
  ),
  BogFord(
    id: 'add_neck',
    knollA: 'hag_knoll',
    knollB: 'altar_knoll',
    slough: 'add',
    index: 1,
    headA: Offset(570, 155),
    headB: Offset(70, 125),
  ),
  BogFord(
    id: 'add_tail',
    knollA: 'cairn_knoll',
    knollB: 'lotus_knoll',
    slough: 'add',
    index: 2,
    headA: Offset(530, 165),
    headB: Offset(530, 140),
  ),
  // ── the Tarn, head to mouth ──
  BogFord(
    id: 'tarn_head',
    knollA: 'mire_gate',
    knollB: 'sedge_knoll',
    slough: 'tarn',
    index: 0,
    headA: Offset(620, 375),
    headB: Offset(70, 220),
  ),
  BogFord(
    id: 'tarn_neck',
    knollA: 'hag_knoll',
    knollB: 'reed_knoll',
    slough: 'tarn',
    index: 1,
    headA: Offset(570, 325),
    headB: Offset(70, 345),
  ),
  BogFord(
    id: 'tarn_tail',
    knollA: 'altar_knoll',
    knollB: 'cairn_knoll',
    slough: 'tarn',
    index: 2,
    headA: Offset(690, 215),
    headB: Offset(70, 220),
  ),
];

/// The knolls, in the order the fen's readouts name them.
const List<String> kBogKnollIds = [
  'mire_gate',
  'hag_knoll',
  'reed_knoll',
  'altar_knoll',
  'sedge_knoll',
  'cairn_knoll',
  'lotus_knoll',
];

/// The three knolls that carry a moor-altar (§6.8's "three altars").
const List<String> kMoorKnollIds = [
  'sedge_knoll',
  'cairn_knoll',
  'lotus_knoll',
];

/// The vault knoll — the one moored thinly enough to be cut adrift.
const String kLotusKnollId = 'lotus_knoll';

/// The plank road: a rotten boardwalk laid ON the water, so it carries a
/// walker and moors nothing. Mud MANE only (§4 hard gate) — it is the vault's
/// approach and blocks no star.
const String kPlankFromKnoll = 'cairn_knoll';
const String kPlankToKnoll = 'lotus_knoll';

/// Where the sarsen lies when a run opens (and where the heave washes it
/// back to).
const String kSarsenHomeKnoll = 'mire_gate';

/// Where the sarsen must end up.
const String kSarsenSocketKnoll = 'altar_knoll';

// ─────────────────────────────────────────────────────────
// THE FIELD — the pure, headless rules
// ─────────────────────────────────────────────────────────

/// Palusia's whole terraform, as rules with no engine in them.
///
/// THE ONE INVARIANT, and the reason this is testable in isolation: the
/// hardened set is always an INDEPENDENT SET in each slough's chain, and the
/// hardened set alone determines the whole fen ([stateOf] derives everything).
/// So a fen state is a legal hardened set, order is unobservable, and the
/// reachability search in the module can enumerate the state space exactly.
class BogField {
  /// Fords dragged to sod, by id. Grows only; never shrinks except on a heave.
  final Set<String> hardened = {};

  /// Which knoll the sarsen stands on.
  String sarsenKnoll = kSarsenHomeKnoll;

  /// The socket's bog-resin cap, eaten by **Plant+Mud→Poison** (§6.8).
  bool socketOpen = false;

  /// The sarsen, seated (Star 0's success).
  bool sarsenSeated = false;

  /// Moor-altars whose basin holds clean water (Star 1's progress).
  final Set<String> moorsWoken = {};

  /// The fen's outfall, unplugged — the way back up out of the drowned fane.
  bool soughFreed = false;

  /// The lotus knoll, ridden down. Gone until a heave raises it.
  bool lotusSunk = false;

  /// How many times THE HEAVE has run (the reset's price, and a readout).
  int heaves = 0;

  /// Seconds the lotus knoll has been going down under the party's weight.
  double founder = 0;

  /// Bogdrya's mire anchor: the hollow's floor firmed under it.
  bool anchorFirm = false;
  bool bitLastFrame = false;

  BogFord? fordById(String id) {
    for (final f in kBogFords) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// The crossings that touch [knollId].
  List<BogFord> fordsOf(String knollId) => [
    for (final f in kBogFords)
      if (f.touches(knollId)) f,
  ];

  /// The crossings immediately up- and downstream of [f] on its own slough.
  List<BogFord> neighbours(BogFord f) => [
    for (final o in kBogFords)
      if (o.slough == f.slough && (o.index - f.index).abs() == 1) o,
  ];

  /// The whole fen, derived from [hardened] alone.
  BogFordState stateOf(String fordId) {
    if (hardened.contains(fordId)) return BogFordState.sod;
    final f = fordById(fordId);
    if (f == null) return BogFordState.mire;
    for (final n in neighbours(f)) {
      if (hardened.contains(n.id)) return BogFordState.drowned;
    }
    return BogFordState.mire;
  }

  /// Can [fordId] still be dragged? Only untouched mire takes a drag: sod is
  /// already sod, and open water has nothing left to pull on.
  bool canHarden(String fordId) => stateOf(fordId) == BogFordState.mire;

  /// Drag a ford to sod. Returns the crossings it DROWNED (for the smear
  /// animation and the hint), or null when the ford would not take it.
  List<BogFord>? harden(String fordId) {
    if (!canHarden(fordId)) return null;
    final f = fordById(fordId);
    if (f == null) return null;
    final lost = [
      for (final n in neighbours(f))
        if (!hardened.contains(n.id)) n,
    ];
    hardened.add(fordId);
    return lost;
  }

  /// Passable on foot: sod or mire. Open water is not.
  bool walkable(String fordId) => stateOf(fordId) != BogFordState.drowned;

  /// A knoll stands DRY-FOOTED when every crossing that touches it is sod:
  /// properly moored and properly drained, so the ground will hold water in
  /// a basin instead of drinking it. This is the moor-altars' whole condition.
  bool isDry(String knollId) =>
      fordsOf(knollId).every((f) => hardened.contains(f.id));

  /// A knoll with no living crossing is ADRIFT — nothing moors it, and it
  /// will not hold a body. Only the lotus is ever reachable in this state
  /// (the plank road), which is what makes the vault an induced map state.
  bool isAdrift(String knollId) =>
      fordsOf(knollId).every((f) => stateOf(f.id) == BogFordState.drowned);

  /// Star 1 lands when all three moor-altars hold water at once.
  bool get choirWhole => kMoorKnollIds.every(moorsWoken.contains);

  /// THE HEAVE — the sough's price. The fen returns to the state it opened
  /// in: every drag gone, every drowned channel running, the lotus risen and
  /// the sarsen washed back to the gate. Banked stars are not touched.
  void heave() {
    hardened.clear();
    moorsWoken.clear();
    sarsenKnoll = kSarsenHomeKnoll;
    lotusSunk = false;
    soughFreed = false;
    founder = 0;
    heaves++;
  }

  /// A clean fen, for a new run.
  void reset() {
    hardened.clear();
    moorsWoken.clear();
    sarsenKnoll = kSarsenHomeKnoll;
    socketOpen = false;
    sarsenSeated = false;
    soughFreed = false;
    lotusSunk = false;
    heaves = 0;
    founder = 0;
    anchorFirm = false;
    bitLastFrame = false;
  }
}

// ─────────────────────────────────────────────────────────
// FIXTURES
// ─────────────────────────────────────────────────────────

/// One island of peat in the fen. The knoll carries only geometry — what its
/// crossings ARE is the player's business, per run.
class BogKnoll {
  /// Stable id, also the room id.
  final String id;

  /// The fen's own name for it, used in copy.
  final String name;

  /// The soft eye at its heart: the WALLOW, the always-available way down.
  final Offset wallow;

  const BogKnoll({required this.id, required this.name, required this.wallow});
}

/// A moor-altar: a peat-black basin on a standing stone. It answers WATER —
/// but only while its knoll stands dry-footed, because sodden ground drinks
/// the offering straight out of the bowl. The world teaches the rule.
class MoorAltar {
  final Offset basin;

  /// The cairn's basin lies under black water and is not there to be found
  /// without Water's second sight (§4 hard gate, object id `moor_black`).
  final bool hidden;

  const MoorAltar({required this.basin, this.hidden = false});
}

/// THE SINKING ALTAR — the dungeon's namesake, and where Palusia declares
/// BOTH of its non-guardian star indices. Carrying them here (rather than on
/// a room flag) keeps the moor knolls star-free: the Moor Star can complete
/// in whichever of the three is dried last, so no knoll owns it.
class SinkingAltarSocket {
  /// Where the sarsen seats.
  final Offset socket;

  /// The bog-resin cap over it — **Plant+Mud→Poison** eats it (§6.8).
  final Offset cap;

  /// Star banked when the sarsen stands in the socket (the Sarsen Star).
  final int sarsenStarIndex;

  /// Star banked when all three moor basins hold at once (the Moor Star).
  final int moorStarIndex;

  const SinkingAltarSocket({
    required this.socket,
    required this.cap,
    required this.sarsenStarIndex,
    required this.moorStarIndex,
  });
}

/// Everything the Sinking Altar puts in one room. Carried on `DungeonRoom.fen`
/// so exactly one field had to be added to the shared room model.
class BogFen {
  /// The knoll this room IS (null = it is not a knoll — the fane, the bowl,
  /// the hollow).
  final BogKnoll? knoll;

  /// This knoll's moor-altar, if it has one.
  final MoorAltar? moor;

  /// The Sinking Altar itself (altar_knoll only).
  final SinkingAltarSocket? altar;

  /// The fen's outfall, in the drowned fane: the anti-strand valve.
  final Offset? sough;

  /// The deepest sink-pit — the Lost Maxim (§6 easter eggs #9).
  final Offset? sinkPit;

  /// Bogdrya's mire anchor: the quaking floor firmed under it, so the mystic
  /// can be struck at all (§7 — the guardian fights WITH the planet's rule).
  final Offset? anchor;

  const BogFen({
    this.knoll,
    this.moor,
    this.altar,
    this.sough,
    this.sinkPit,
    this.anchor,
  });
}

// ─────────────────────────────────────────────────────────
// THE LAYOUT
// ─────────────────────────────────────────────────────────

/// Mud's lost maxim (§6 easter eggs #9, "No Mud, No Lotus").
const String kMudLotusEggId = 'egg:mud_no_lotus';

/// The maxim itself, over a seed that went all the way down and came back.
const String kMudLotusMaxim = '"From the deepest mud grows the lotus."';

/// PALUSIA — THE SINKING ALTAR, the Mud dungeon.
///
/// Stars (§7: one core mechanic + one consequence + one success, each):
///  0 · **Sarsen Star** — core: haul the fen's fallen standing stone from the
///      mire gate to the Sinking Altar. A sarsen crosses SOD and nothing else,
///      so the road has to be dragged ahead of it. Consequence: every drag
///      drowns the crossings beside it, so the road you build deletes
///      crossings — including ones you were going to need. Success: the resin
///      cap eaten and the stone standing in its socket.
///      UNGATED — this is the star §4 guarantees to any trio of the right
///      elements.
///  1 · **Moor Star** — core: three moor-altars, on three knolls; a basin
///      holds its offering only while its knoll stands DRY-FOOTED (every
///      crossing that touches it dragged to sod). Consequence: drying one
///      knoll floods the channels beside it and can make a neighbour
///      impossible to dry, for the run. Success: all three basins holding.
///  2 · **Bogdrya** — MYS08, in the hollow under the drowned fane.
///
/// Family gates (§4 — two, on two different entry slots, neither one the
/// thing that stops a first descent):
///  · `moor_black` — **Water MASK**. The cairn's basin lies under black water.
///    One of Star 1's three; the other two are element-only.
///  · `plank_road` — **Mud MANE**. The peat-cutters' boardwalk out to the
///    lotus. It is the vault's approach and gates no star at all: the gate
///    SHAPES what a party can take home, exactly as Poison's brick does.
const DungeonLayout mudLayout = DungeonLayout(
  element: 'Mud',
  entranceRoomId: 'mire_gate',
  entranceSpawn: Offset(150, 240),
  title: 'THE SINKING ALTAR',
  descentTitle: 'Palusia Fen',
  stars: [
    DungeonStarSpec(
      name: 'Sarsen Star',
      earnAnnouncement:
          'The Sarsen Star is yours — the stone stands where the fen wanted it',
    ),
    DungeonStarSpec(
      name: 'Moor Star',
      earnAnnouncement:
          'The Moor Star is yours — three basins hold, and the fen is quiet',
    ),
    DungeonStarSpec(name: 'Bogdrya\'s Star'),
  ],
  // The fen's face is a skin of floating weed; Water sluices it and the
  // crossings show themselves (the eased entry reveal, §5.5).
  entranceRevealDoor: DungeonDoorRef('mire_gate', 'hag_knoll'),
  finaleDoor: DungeonDoorRef('drowned_fane', 'bogdrya_hollow'),
  riteAnnouncement: 'Stone and choir agree — the peat parts under the fane',
  finaleSealedHint:
      'The peat will not part — it answers only the Sarsen and Moor stars',
  guardianSealedHint:
      'The hollow lies shut under the fen — nothing down there stirs until '
      'the stone stands and the basins hold',
  mercyShrineRoomId: 'drowned_fane',
  // Ideal: Mudmane · Plantpip · Watermask — hinted by VERB, never by body
  // part (§4 THE DESCENT RIDDLE): the hard trail left behind, the small door,
  // the sight that reads black water.
  riddle: [
    'Send me a Mud Mane — my rot will bear nothing that leaves no road;',
    'Plant, to quicken whatever the peat has kept;',
    'and a Water Mask, for I keep my best beneath black water.',
  ],
  familyGates: [
    DungeonFamilyGate(
      objectId: 'moor_black',
      element: 'Water',
      family: 'Mask',
      hintLine: 'Only Water\'s second sight finds a basin under black water',
    ),
    DungeonFamilyGate(
      objectId: 'plank_road',
      element: 'Mud',
      family: 'Mane',
      hintLine: 'Only a Mud mane lays ground enough to cross these planks',
    ),
  ],
  rooms: {
    // ── THE MIRE GATE — the fen's near shore, and a knoll like any other.
    // Three crossings leave it, all of them under a skin of weed until Water
    // washes it off. The sarsen lies here in the silt.
    'mire_gate': DungeonRoom(
      id: 'mire_gate',
      bounds: Rect.fromLTWH(0, 0, 720, 480),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(696, 60, 24, 90),
          targetRoomId: 'hag_knoll',
          targetSpawn: Offset(60, 125),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(696, 195, 24, 90),
          targetRoomId: 'reed_knoll',
          targetSpawn: Offset(60, 215),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(696, 330, 24, 90),
          targetRoomId: 'sedge_knoll',
          targetSpawn: Offset(60, 220),
        ),
        // THE WALLOW — always available to a Mud hand, from every knoll.
        DungeonDoor(
          rect: Rect.fromLTWH(140, 300, 54, 54),
          targetRoomId: 'drowned_fane',
          targetSpawn: Offset(150, 340),
        ),
      ],
      fen: BogFen(
        knoll: BogKnoll(
          id: 'mire_gate',
          name: 'The Mire Gate',
          wallow: Offset(167, 327),
        ),
      ),
    ),

    // ── HAG KNOLL — the fen's memory, north of the gate.
    'hag_knoll': DungeonRoom(
      id: 'hag_knoll',
      bounds: Rect.fromLTWH(0, 0, 640, 460),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 80, 24, 90),
          targetRoomId: 'mire_gate',
          targetSpawn: Offset(630, 105),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(616, 110, 24, 90),
          targetRoomId: 'altar_knoll',
          targetSpawn: Offset(60, 125),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(616, 280, 24, 90),
          targetRoomId: 'reed_knoll',
          targetSpawn: Offset(60, 345),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(300, 380, 54, 54),
          targetRoomId: 'drowned_fane',
          targetSpawn: Offset(330, 340),
        ),
      ],
      fen: BogFen(
        knoll: BogKnoll(
          id: 'hag_knoll',
          name: 'Hag Knoll',
          wallow: Offset(327, 407),
        ),
      ),
    ),

    // ── REED KNOLL — the fen's crossroads: three crossings and no answers.
    'reed_knoll': DungeonRoom(
      id: 'reed_knoll',
      bounds: Rect.fromLTWH(0, 0, 640, 460),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 170, 24, 90),
          targetRoomId: 'mire_gate',
          targetSpawn: Offset(630, 240),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 300, 24, 90),
          targetRoomId: 'hag_knoll',
          targetSpawn: Offset(570, 325),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(616, 170, 24, 90),
          targetRoomId: 'altar_knoll',
          targetSpawn: Offset(60, 305),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(300, 380, 54, 54),
          targetRoomId: 'drowned_fane',
          targetSpawn: Offset(510, 340),
        ),
      ],
      fen: BogFen(
        knoll: BogKnoll(
          id: 'reed_knoll',
          name: 'Reed Knoll',
          wallow: Offset(327, 407),
        ),
      ),
    ),

    // ── ALTAR KNOLL — THE SINKING ALTAR. Star 0 seats here, and the fen's
    // two non-guardian star indices are declared on the socket.
    'altar_knoll': DungeonRoom(
      id: 'altar_knoll',
      bounds: Rect.fromLTWH(0, 0, 760, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 80, 24, 90),
          targetRoomId: 'hag_knoll',
          targetSpawn: Offset(570, 155),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 260, 24, 90),
          targetRoomId: 'reed_knoll',
          targetSpawn: Offset(570, 215),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(736, 170, 24, 90),
          targetRoomId: 'cairn_knoll',
          targetSpawn: Offset(70, 220),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(360, 440, 54, 54),
          targetRoomId: 'drowned_fane',
          targetSpawn: Offset(690, 340),
        ),
      ],
      fen: BogFen(
        knoll: BogKnoll(
          id: 'altar_knoll',
          name: 'The Altar Knoll',
          wallow: Offset(387, 467),
        ),
        altar: SinkingAltarSocket(
          socket: Offset(400, 250),
          cap: Offset(400, 250),
          sarsenStarIndex: 0,
          moorStarIndex: 1,
        ),
      ),
    ),

    // ── SEDGE KNOLL — the first moor-altar. Two crossings, so it is dryable.
    'sedge_knoll': DungeonRoom(
      id: 'sedge_knoll',
      bounds: Rect.fromLTWH(0, 0, 600, 440),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 175, 24, 90),
          targetRoomId: 'mire_gate',
          targetSpawn: Offset(620, 375),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(576, 175, 24, 90),
          targetRoomId: 'lotus_knoll',
          targetSpawn: Offset(70, 220),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(275, 350, 54, 54),
          targetRoomId: 'drowned_fane',
          targetSpawn: Offset(870, 340),
        ),
      ],
      fen: BogFen(
        knoll: BogKnoll(
          id: 'sedge_knoll',
          name: 'Sedge Knoll',
          wallow: Offset(302, 377),
        ),
        moor: MoorAltar(basin: Offset(300, 165)),
      ),
    ),

    // ── CAIRN KNOLL — the second moor-altar (the one under black water, §4
    // Water MASK), and the landward end of the plank road.
    'cairn_knoll': DungeonRoom(
      id: 'cairn_knoll',
      bounds: Rect.fromLTWH(0, 0, 600, 440),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 175, 24, 90),
          targetRoomId: 'altar_knoll',
          targetSpawn: Offset(690, 215),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(576, 95, 24, 90),
          targetRoomId: 'lotus_knoll',
          targetSpawn: Offset(530, 140),
        ),
        // THE PLANK ROAD — Mud MANE. Not a ford: it moors nothing.
        DungeonDoor(
          rect: Rect.fromLTWH(576, 270, 24, 90),
          targetRoomId: 'lotus_knoll',
          targetSpawn: Offset(530, 315),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(275, 350, 54, 54),
          targetRoomId: 'drowned_fane',
          targetSpawn: Offset(1050, 340),
        ),
      ],
      fen: BogFen(
        knoll: BogKnoll(
          id: 'cairn_knoll',
          name: 'Cairn Knoll',
          wallow: Offset(302, 377),
        ),
        moor: MoorAltar(basin: Offset(300, 165), hidden: true),
      ),
    ),

    // ── LOTUS KNOLL — the third moor-altar AND the vault knoll. Moored by
    // two crossings; cut them both and it is adrift, and the plank road is
    // the only way to set foot on it (§5.5 vault trick).
    'lotus_knoll': DungeonRoom(
      id: 'lotus_knoll',
      bounds: Rect.fromLTWH(0, 0, 600, 440),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 175, 24, 90),
          targetRoomId: 'sedge_knoll',
          targetSpawn: Offset(530, 220),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(576, 95, 24, 90),
          targetRoomId: 'cairn_knoll',
          targetSpawn: Offset(530, 165),
        ),
        // The plank road's far end.
        DungeonDoor(
          rect: Rect.fromLTWH(576, 270, 24, 90),
          targetRoomId: 'cairn_knoll',
          targetSpawn: Offset(530, 315),
        ),
        // THE FOUNDER — the knoll going down under your weight. The engine
        // walks the party through this door itself; it is never touched.
        DungeonDoor(
          rect: Rect.fromLTWH(274, 340, 54, 54),
          targetRoomId: 'sunken_lotus',
          targetSpawn: Offset(230, 120),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(120, 340, 54, 54),
          targetRoomId: 'drowned_fane',
          targetSpawn: Offset(1230, 340),
        ),
      ],
      fen: BogFen(
        knoll: BogKnoll(
          id: 'lotus_knoll',
          name: 'Lotus Knoll',
          wallow: Offset(147, 367),
        ),
        moor: MoorAltar(basin: Offset(300, 150)),
      ),
    ),

    // ── THE SUNKEN LOTUS — the bowl the vault knoll becomes. The bottled
    // essence lies here, and there is no climbing back into it: you came in
    // through the roof, riding the knoll (§5.5).
    'sunken_lotus': DungeonRoom(
      id: 'sunken_lotus',
      bounds: Rect.fromLTWH(0, 0, 460, 380),
      doors: [
        // Reciprocal only. The knoll came down WITH you; there is nothing
        // above the bowl now but water, and the engine keeps this shut.
        DungeonDoor(
          rect: Rect.fromLTWH(175, 0, 110, 24),
          targetRoomId: 'lotus_knoll',
          targetSpawn: Offset(300, 240),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(175, 356, 110, 24),
          targetRoomId: 'drowned_fane',
          targetSpawn: Offset(680, 300),
        ),
      ],
      vaultCache: Offset(230, 230),
    ),

    // ── THE DROWNED FANE — the fen's underside. Every wallow lands here, the
    // SOUGH is here, the deepest sink-pit is here, and the hollow lies under
    // it. This is the room the anti-strand valve lives in.
    'drowned_fane': DungeonRoom(
      id: 'drowned_fane',
      bounds: Rect.fromLTWH(0, 0, 1360, 760),
      doors: [
        // The risen wallows — shut until the sough is freed. Climbing one is
        // THE HEAVE (see the header): the fen resets behind you.
        DungeonDoor(
          rect: Rect.fromLTWH(120, 330, 54, 54),
          targetRoomId: 'mire_gate',
          targetSpawn: Offset(167, 260),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(300, 330, 54, 54),
          targetRoomId: 'hag_knoll',
          targetSpawn: Offset(327, 330),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(490, 330, 54, 54),
          targetRoomId: 'reed_knoll',
          targetSpawn: Offset(327, 330),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(670, 330, 54, 54),
          targetRoomId: 'altar_knoll',
          targetSpawn: Offset(387, 390),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(850, 330, 54, 54),
          targetRoomId: 'sedge_knoll',
          targetSpawn: Offset(302, 300),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(1030, 330, 54, 54),
          targetRoomId: 'cairn_knoll',
          targetSpawn: Offset(302, 300),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(1210, 330, 54, 54),
          targetRoomId: 'lotus_knoll',
          targetSpawn: Offset(147, 290),
        ),
        // Reciprocal only: the bowl lies under the fane's own silt and is
        // never climbed into from here (the engine keeps it hidden).
        DungeonDoor(
          rect: Rect.fromLTWH(640, 690, 54, 54),
          targetRoomId: 'sunken_lotus',
          targetSpawn: Offset(230, 110),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(625, 736, 110, 24),
          targetRoomId: 'bogdrya_hollow',
          targetSpawn: Offset(450, 150),
        ),
      ],
      fen: BogFen(sough: Offset(680, 180), sinkPit: Offset(170, 640)),
    ),

    // ── BOGDRYA'S HOLLOW — Star 2. §7: the mystic fights WITH the planet's
    // rule. Bogdrya DRINKS the fen: its lull only opens while the mire anchor
    // holds the quaking floor firm under it, and every strike beat softens
    // the anchor AND swallows one of the sod roads you left in the bog above,
    // spitting it back as open water. It eats the map you made while you
    // fight it — and the sough behind you is still the way out.
    'bogdrya_hollow': DungeonRoom(
      id: 'bogdrya_hollow',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'drowned_fane',
          targetSpawn: Offset(680, 600),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(450, 340),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Mud',
          mysticId: 'Bogdrya',
          canCalm: true,
          canDefeat: true,
        ),
      ),
      fen: BogFen(anchor: Offset(170, 480)),
    ),
  },
);
