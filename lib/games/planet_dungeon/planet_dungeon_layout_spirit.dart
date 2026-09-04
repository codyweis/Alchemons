// lib/games/planet_dungeon/planet_dungeon_layout_spirit.dart
//
// REQUIA — the Echo Grave. Spirit's authored layout, its pure rules, and the
// puzzle DATA its `part of planet_dungeon_game.dart` module reasons about.
//
// TOPOLOGY (docs/dungeons.md §5.5, structural assignment table, Spirit row):
// **TWO OVERLAID WORLDS — living/ghost layers, same geometry, different
// doors.** There is no hub and there are no wings. There is ONE grave-field —
// seven barrows on a corpse round with two cuts across it — and there are two
// ways of being in it. Every crossing of that field is cut for exactly one
// kind of body, and which kind you are is something you choose at a
// lych-stone.
//
//     ── the grave-field, ONE geometry ─────────────────────
//                        mourners_walk ── wraithord_grave
//                              ╵ rood
//        bell ──── veil ─────── mere ─────── cairn ──── ash
//         ╵         ╵ ╲drowned cut╵ hollow      ╵         ╵
//         ╵         ╵  ╲          ╵ grave       ╵         ╵ salt
//         └── urn ──┘   ╲─────────────────────┘        watch
//              ╵ lych road (urn–veil)                     ╵
//           lych_gate ─────────────────────────────────────┘
//
//   (the ring, in order: urn · bell · veil · mere · cairn · ash · watch · urn.
//    The two chords are the LYCH ROAD urn–veil and the DROWNED CUT veil–cairn;
//    the hollow grave hangs off the mere and the rood off the cairn.)
//
// WORLD RULE — *the past replays here, and it cannot be changed. It can only
// be finished.*
//
// ─────────────────────────────────────────────────────────
// THE INVARIANT — ONE CROSSING, ONE WORLD, FOREVER
// ─────────────────────────────────────────────────────────
// Requia's claimed mechanic (§5.5 open pool: "two-overlaid-worlds layer swap —
// Spirit, the LIVING/GHOST reading only") is stated in a single rule:
//
//   **EVERY CROSSING OF THE FIELD IS WALKABLE IN EXACTLY ONE WORLD, AND SIX OF
//   THEM HAVE NOT YET DECIDED WHICH.**
//
// A crossing is one of four things:
//   • BOTH        — the gate arch, the rood, the guardian's door. Frame stone.
//   • LIVING-ONLY — salted, consecrated ground. The dead may not walk it.
//   • GHOST-ONLY  — a road that fell, or drowned, long ago. Only a memory of
//     it still stands, and only the dead can stand on a memory.
//   • A REVENANT  — an undecided crossing, and the whole planet.
//
// A REVENANT is somebody who died at that crossing and is still dying there.
//   • RESTLESS (how every one of them starts) — the dead one is still holding
//     up the lintel it fell under, so the GHOST crossing is open; and the
//     stone that killed it still lies across the LIVING one, so that is shut.
//   • AT REST — a Spirit hand in the ghost world hears out how it died, and
//     the death FINISHES. The dead one lies down: the living crossing is
//     clear at last, and the ghost crossing has nothing holding it up any
//     more and falls in.
//
// So THE TELLING is the planet's one world-edit, and it is exactly the doc's
// sentence: *deaths in one open doors in the other.* It is IRREVERSIBLE — a
// death that has been finished does not resume — and it is ORDER-FREE: telling
// A then B leaves the identical grave-field as telling B then A, which is what
// keeps this out of Air's ordering seat (pinned in the test).
//
// THE STRATEGIC QUESTION (§5.5): *which layer to cross each junction in.* Each
// of the six revenants is a permanent commitment of one crossing to one world,
// and the field's demands pull in both directions at once. The sharpest
// instance is authored on purpose at THE MERE: to stand there ALIVE (Star 1's
// sigil will not take a dead hand's mark) you must tell one of its two dead;
// to stand there DEAD (the hollow grave beyond it opens on no living wall) you
// must leave one of them restless. Tell both and you have the mere forever and
// the grave behind it never. Tell neither and you have it only as a ghost.
//
// LEDGER (§5.5). Requia takes the living/ghost reading of layer-swap and
// nothing else. It is deliberately NOT:
//   · Dust's Z-layer/excavation reading — the doc splits this seat by name.
//     Dust has two DECKS of rooms and which deck you stand on is a CONSEQUENCE
//     of a load ledger. Requia has one deck, no ledger and no quantity: both
//     worlds are the same seven rooms at all times, and the variable is which
//     of the two bodies you are wearing.
//   · Plant's observer-scale — Plant's world is constant and the OBSERVER
//     changes size. Here the observer is constant (three creatures, one grave)
//     and it is the WORLD that is doubled. Plant's beds author a road for the
//     size you were not; Requia's tellings never author anything — every
//     crossing already exists in both worlds and a telling only decides which
//     copy of it survives.
//   · Dark's inverting maze — Dark flips ONE GLOBAL state and the whole map
//     inverts, so every flip made for a door closes another somewhere else.
//     Requia never flips anything globally: both worlds stand at once, all the
//     time, and each junction is committed once, by itself, forever. Nothing a
//     telling does is felt anywhere but at that crossing.
//   · Mud's terraforming-as-map-authoring — Mud DESTROYS edges and asks what
//     shape you are left in. Requia destroys nothing: after every telling the
//     field still has exactly the same crossings it started with, and every
//     one of them is still crossable. The question is never "is there a way"
//     but "which of me can take it".
//   · Air's irreversible wind-authoring (whose question is ORDER — here order
//     is unobservable), Fire's handed-down sequence, Ice's one-way descent
//     (nothing here consumes the route behind you), Steam's global budget
//     (nothing is spent; you may tell all six), Poison's forced sacrifice
//     (nothing is abandoned — every crossing stays open in one world),
//     Crystal's permuting map (no room ever moves).
//
// ─────────────────────────────────────────────────────────
// THE VAULT TRICK (§5.5: "exists only in the ghost layer, marked only in the
// living one")
// ─────────────────────────────────────────────────────────
// THE HOLLOW GRAVE hangs off the mere behind a GHOST-ONLY crossing: in the
// living world its wall is unbroken and the door is not merely shut, it is not
// there. The only sign of it anywhere is cut into the MERE'S LIVING FLOOR — an
// unmarked grave's mark, a name-slot with no name in it, which a dead hand
// cannot read because the dead read no stones. So the cache demands the one
// thing the mere makes expensive: you must stand there in BOTH worlds, which
// means committing exactly one of its two dead and no more. Nothing about it
// is a side room behind a signature-gated door — it is a room that only one of
// the two worlds contains, marked only in the one that does not.
//
// ─────────────────────────────────────────────────────────
// THE HAZARD, AND WHY THIS PLANET NEEDS NO VALVE
// ─────────────────────────────────────────────────────────
// Death as a puzzle verb is a stranding machine: shut the last ghost crossing
// out of a barrow while a body is standing in it and the run is over. Ice
// (120/122), Mud (1200/1284), Dust (319/396) and Plant (142/448) all measured
// as stranding machines and all bought their way out with a costly full reset.
// Requia measures **0 strandable of 2,276** — and it is designed out rather
// than paid for, by two geometric rules that this file's data satisfies by
// construction and test/planet_dungeon_spirit_grave_test.dart proves
// exhaustively:
//
//   RULE 1 — THE GHOST SPINE. The crossings gate→urn (both), urn→veil (the
//     lych road) and veil→cairn (the drowned cut) can never be told, so the
//     set {lych_gate, urn, veil, cairn, mourners_walk, wraithord_grave} is
//     connected in the ghost world in EVERY world state, and it carries a
//     lych-stone (three of them).
//   RULE 2 — EVERY REVENANT IS TOLD FROM THE SPINE. All six of them are heard
//     out from the urn, the veil or the cairn. A body therefore CANNOT be
//     standing in the pendant barrow whose last ghost crossing it is closing —
//     it had to walk out of that barrow to do the telling. So the ghost world
//     can only ever shrink away from where you are not.
//
// The living world needs no rule at all: telling and freezing only ever ADD
// living crossings, so a living body can always retrace the crossing it
// arrived by. And a lych-stone is a one-way door DOWN from anywhere (dying is
// easy; it is the only easy thing here), so from any living position the ghost
// spine — and with it a wake — is one press away.
//
// Break either rule and the planet becomes what its neighbours were: moving
// every telling to the pendant side of its own crossing measures **54 of the
// 369** states such a run can still reach — the counterfactual the test pins,
// so the two rules cannot be quietly edited out later.
//
// VISUAL GRAMMAR (§5.5): nothing here reads like Dust's mound heights, Water's
// tide line or Plant's re-scaled furniture. The two worlds are one drawing in
// two INKS — the living grave is warm stone, moss and lamp-black on solid
// fills; the ghost grave is the same geometry re-struck in cold outline, every
// surface hollow, every edge doubled a half-pixel out of true, and the party's
// own bodies drawn as their own outlines. Passing over is a single hard
// cross-fade between the two inks with no dissolve, no wipe and no blur — the
// grave does not transform, it is simply re-inked.

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

// ─────────────────────────────────────────────────────────
// THE TWO WORLDS
// ─────────────────────────────────────────────────────────

/// The two bodies the grave-field can be walked in. There is no third state
/// and no in-between: a crossing either takes you or it does not, so the
/// player reads the map without arithmetic.
enum GraveWorld {
  /// Warm. Salt and consecrated ground carry you; fallen arches do not.
  living,

  /// Cold. You are walking as your own echo. Every road that ever stood here
  /// still does — and every road the living keep is shut against you.
  ghost,
}

GraveWorld otherWorld(GraveWorld w) =>
    w == GraveWorld.living ? GraveWorld.ghost : GraveWorld.living;

String worldWord(GraveWorld w) => w == GraveWorld.living ? 'living' : 'ghost';

// ─────────────────────────────────────────────────────────
// CROSSINGS — the map, in both worlds at once
// ─────────────────────────────────────────────────────────

/// Which world a crossing is cut for.
enum GraveCut {
  /// Frame stone — the gate arch, the rood, the guardian's door. Either body.
  both,

  /// Salted, consecrated, or simply too much in the world. The dead may not
  /// walk it.
  livingOnly,

  /// A road that fell or drowned. Only its memory stands, and only the dead
  /// can stand on a memory.
  ghostOnly,

  /// Undecided. A revenant is still dying at it: ghost-open while restless,
  /// living-open once its death is finished. See [kGraveRevenants].
  revenant,
}

/// One passage of the grave-field, authored once and read from both ends.
///
/// The layout test enforces that EVERY door has a reciprocal door, statically
/// (docs §5.5 keeps that invariant for the whole game, and Crystal's keep and
/// Plant's crypt both live inside it). A map whose connectivity changes at
/// runtime lives inside that rule the only honest way: **the doors are
/// constant and reciprocal, and what varies is whether the body standing at
/// one can use it.** No door on this planet is ever created or destroyed.
class GraveCrossing {
  final String id;
  final String from;
  final String to;
  final GraveCut cut;

  /// The revenant that has not decided this crossing yet, or null for a
  /// permanent one. Non-null exactly when [cut] is [GraveCut.revenant].
  final String? revenantId;

  /// True for the drowned cut — the one crossing the cold can settle. Freezing
  /// it makes it [GraveCut.both] for the rest of the run (§6.14's
  /// **Spirit+Water→Ice**, "freeze ghost bridges"). Additive and therefore
  /// harmless to the no-strand proof: it only ever GIVES the living a road.
  final bool freezable;

  /// One clause naming the passage, for the blocked line and the render.
  final String look;

  const GraveCrossing({
    required this.id,
    required this.from,
    required this.to,
    required this.cut,
    required this.look,
    this.revenantId,
    this.freezable = false,
  });

  bool joins(String a, String b) =>
      (from == a && to == b) || (from == b && to == a);
}

/// The whole grave-field as passages. Thirteen, and every room pair appears
/// exactly once — so a door and a crossing are one-to-one and the proof can
/// never drift from the doors the player actually meets (Plant's precedent,
/// pinned in the test).
const List<GraveCrossing> kGraveCrossings = [
  // ── frame stone: cut in both worlds, never decided ────
  GraveCrossing(
    id: 'x_gate',
    from: 'lych_gate',
    to: 'barrow_urn',
    cut: GraveCut.both,
    look: 'the lych gate\'s arch',
  ),
  GraveCrossing(
    id: 'x_rood',
    from: 'barrow_cairn',
    to: 'mourners_walk',
    cut: GraveCut.both,
    look: 'the rood door',
  ),
  GraveCrossing(
    id: 'x_choir',
    from: 'mourners_walk',
    to: 'wraithord_grave',
    cut: GraveCut.both,
    look: 'the last door',
  ),

  // ── THE GHOST SPINE (no-strand RULE 1) ────────────────
  // Two cuts across the round that the living have never been able to take.
  // They can never be told, so the ghost world is connected across the whole
  // spine in every state the run can reach.
  GraveCrossing(
    id: 'x_lychroad',
    from: 'barrow_urn',
    to: 'barrow_veil',
    cut: GraveCut.ghostOnly,
    look: 'the lych road. Worn to nothing, and still walked',
  ),
  GraveCrossing(
    id: 'x_drowned',
    from: 'barrow_veil',
    to: 'barrow_cairn',
    cut: GraveCut.ghostOnly,
    freezable: true,
    look: 'the drowned cut. Black water, and a road under it',
  ),

  // ── the salted step: the living keep it, the dead cannot
  GraveCrossing(
    id: 'x_salt',
    from: 'barrow_ash',
    to: 'barrow_watch',
    cut: GraveCut.livingOnly,
    look: 'the salted step',
  ),

  // ── THE VAULT (§5.5) ──────────────────────────────────
  // In the living world the mere's north wall is unbroken. There is no door
  // there to be shut — there is no door there.
  GraveCrossing(
    id: 'x_hollow',
    from: 'barrow_mere',
    to: 'hollow_grave',
    cut: GraveCut.ghostOnly,
    look: 'a grave-mouth that the living wall does not have',
  ),

  // ── the six undecided crossings ───────────────────────
  GraveCrossing(
    id: 'x_bell',
    from: 'barrow_urn',
    to: 'barrow_bell',
    cut: GraveCut.revenant,
    revenantId: 'r_bellman',
    look: 'the bell walk',
  ),
  GraveCrossing(
    id: 'x_veil',
    from: 'barrow_bell',
    to: 'barrow_veil',
    cut: GraveCut.revenant,
    revenantId: 'r_chandler',
    look: 'the veil steps',
  ),
  GraveCrossing(
    id: 'x_mere',
    from: 'barrow_veil',
    to: 'barrow_mere',
    cut: GraveCut.revenant,
    revenantId: 'r_keener',
    look: 'the mere path',
  ),
  GraveCrossing(
    id: 'x_sill',
    from: 'barrow_mere',
    to: 'barrow_cairn',
    cut: GraveCut.revenant,
    revenantId: 'r_sexton',
    look: 'the sill between mere and cairn',
  ),
  GraveCrossing(
    id: 'x_ash',
    from: 'barrow_cairn',
    to: 'barrow_ash',
    cut: GraveCut.revenant,
    revenantId: 'r_wright',
    look: 'the ash gate',
  ),
  GraveCrossing(
    id: 'x_watch',
    from: 'barrow_watch',
    to: 'barrow_urn',
    cut: GraveCut.revenant,
    revenantId: 'r_watcher',
    look: 'the watch stair',
  ),
];

GraveCrossing? graveCrossingBetween(String a, String b) {
  for (final x in kGraveCrossings) {
    if (x.joins(a, b)) return x;
  }
  return null;
}

GraveCrossing? graveCrossingById(String id) {
  for (final x in kGraveCrossings) {
    if (x.id == id) return x;
  }
  return null;
}

// ─────────────────────────────────────────────────────────
// THE DEAD
// ─────────────────────────────────────────────────────────

/// One of the grave's own, still dying at the crossing that killed them.
///
/// [toldAt] is load-bearing, not flavour: it is no-strand RULE 2. Every
/// revenant is heard out from a barrow on the permanent ghost spine, which is
/// why a body can never be standing in the pendant barrow whose last ghost
/// crossing it is closing. See the file header, and the counterfactual the
/// test measures against it.
class Revenant {
  final String id;
  final String name;

  /// The crossing this death has not decided yet.
  final String crossingId;

  /// The barrow you must be standing in — DEAD — to hear it out. Always on
  /// the ghost spine.
  final String toldAt;

  /// Where in [toldAt] the dead one is, for the verb's reach and the render.
  final Offset seat;

  /// How it reads when you find it, and how it reads once it is finished.
  final String restlessLook;
  final String restedLook;

  const Revenant({
    required this.id,
    required this.name,
    required this.crossingId,
    required this.toldAt,
    required this.seat,
    required this.restlessLook,
    required this.restedLook,
  });
}

/// Requia's six. Told from the urn (2), the veil (2) and the cairn (2) — the
/// three spine barrows of the field — which is the whole no-strand argument.
const List<Revenant> kGraveRevenants = [
  Revenant(
    id: 'r_bellman',
    name: 'the Bellman',
    crossingId: 'x_bell',
    toldAt: 'barrow_urn',
    seat: Offset(400, 120),
    restlessLook: 'a shape by the urn, ringing a bell that makes no sound',
    restedLook: 'a bell laid down on its side, and quiet',
  ),
  Revenant(
    id: 'r_watcher',
    name: 'the Watcher',
    crossingId: 'x_watch',
    toldAt: 'barrow_urn',
    seat: Offset(120, 280),
    restlessLook: 'somebody at the stair-head, still looking the wrong way',
    restedLook: 'a hollow in the step where somebody sat a long time',
  ),
  Revenant(
    id: 'r_chandler',
    name: 'the Chandler',
    crossingId: 'x_veil',
    toldAt: 'barrow_veil',
    seat: Offset(110, 130),
    restlessLook: 'a candle-maker guarding a light that went out first',
    restedLook: 'a stub of tallow, cold and finished',
  ),
  Revenant(
    id: 'r_keener',
    name: 'the Keener',
    crossingId: 'x_mere',
    toldAt: 'barrow_veil',
    seat: Offset(410, 290),
    restlessLook:
        'a mourner keening for a funeral that never reached the '
        'water',
    restedLook: 'a wet mark on the flags, drying',
  ),
  Revenant(
    id: 'r_sexton',
    name: 'the Sexton',
    crossingId: 'x_sill',
    toldAt: 'barrow_cairn',
    seat: Offset(130, 320),
    restlessLook:
        'a grave-digger leaning on a spade in a hole he never '
        'finished',
    restedLook: 'a spade stood upright in filled ground',
  ),
  Revenant(
    id: 'r_wright',
    name: 'the Cairnwright',
    crossingId: 'x_ash',
    toldAt: 'barrow_cairn',
    seat: Offset(440, 140),
    restlessLook: 'a stone-setter holding up a lintel that fell on him',
    restedLook: 'a lintel set square at last, and nobody under it',
  ),
];

Revenant? graveRevenantById(String id) {
  for (final r in kGraveRevenants) {
    if (r.id == id) return r;
  }
  return null;
}

List<Revenant> graveRevenantsIn(String roomId) => [
  for (final r in kGraveRevenants)
    if (r.toldAt == roomId) r,
];

// ─────────────────────────────────────────────────────────
// THE PHANTOM HOURGLASS (Star 1)
// ─────────────────────────────────────────────────────────
// §6.14: *a room shows half a sigil, the minimap the other half — stamp at the
// right spot.* Requia's two worlds ARE the two halves, which is the only way
// this star belongs to this planet rather than to any planet with a map:
//
//   · the LIVING half is cut in each barrow's own floor — a bearing on the
//     grave-field's twelve-point ring, readable only by a hand warm enough to
//     touch a stone.
//   · the GHOST half is the field seen from above, the way the dead carry it:
//     one great arc struck across the whole round on a bearing of its own.
//     It is legible from any barrow, in the ghost world, and from nowhere
//     else — the dead do not need to be near a thing to see it.
//
// The sigil CLOSES where the two bearings make the ring whole, and the mark
// only takes from a living hand (the dead leave no marks). So the star's answer
// exists in neither world by itself — it is a fact about the pair — and its
// cost is the planet's own trade: to stamp the mere you must have told one of
// its dead.
//
// Exactly one barrow closes the ring. Proved by exhaustion in the test rather
// than asserted here (Crystal's kRoseHue precedent).

/// The bearing of the great arc the dead see over the whole field.
const int kGraveFieldBearing = 7;

/// The bearing cut in each barrow's living floor. Twelve-point ring.
const Map<String, int> kBarrowSigilHalf = {
  'barrow_urn': 1,
  'barrow_bell': 3,
  'barrow_veil': 9,
  'barrow_mere': 5,
  'barrow_cairn': 2,
  'barrow_ash': 8,
  'barrow_watch': 11,
};

/// Does [roomId]'s floor half close the ring with the field's arc?
bool graveSigilCloses(String roomId) {
  final half = kBarrowSigilHalf[roomId];
  if (half == null) return false;
  return (half + kGraveFieldBearing) % 12 == 0;
}

/// The one barrow the mark takes in, computed rather than typed so the data
/// and the answer can never disagree.
String get kGraveSigilBarrow {
  for (final id in kBarrowSigilHalf.keys) {
    if (graveSigilCloses(id)) return id;
  }
  return '';
}

// ─────────────────────────────────────────────────────────
// THE LIVE STATE — pure rules, no Flutter, no engine
// ─────────────────────────────────────────────────────────

/// Everything Requia tracks for one run.
///
/// Deliberately tiny: this planet's whole difficulty is a REACHABILITY
/// question over (room × world × commitments), so the state is exactly the
/// three things reachability depends on — which world you are in, which deaths
/// are finished, and whether the cut is frozen — plus the per-star tallies.
class EchoGraveField {
  EchoGraveField() {
    reset();
  }

  /// The body the party is walking in. Party-wide: three creatures share one
  /// grave and one world.
  GraveWorld world = GraveWorld.living;

  /// Deaths that have been finished. Irreversible for the run — a death that
  /// has been heard out does not resume.
  final Set<String> rested = {};

  /// The drowned cut, settled to ice (**Spirit+Water→Ice**, §6.14). Permanent,
  /// and purely additive: it gives the living a road and takes nothing.
  bool cutFrozen = false;

  /// Star 1: the mark, and how many places it has been tried. A refused stamp
  /// costs nothing but the walk — this is a deduction, not a trap.
  bool sigilStamped = false;
  int stampsTried = 0;

  /// How many times the party has passed over. Not a budget (nothing runs out
  /// — that seat is Steam's); a readout, and the count the grave's company is
  /// drawn off.
  int passings = 0;

  /// The grave-field as its dead left it: nobody finished, nothing frozen, and
  /// the party still warm.
  void reset() {
    world = GraveWorld.living;
    rested.clear();
    cutFrozen = false;
    sigilStamped = false;
    stampsTried = 0;
    passings = 0;
  }

  // ── The two worlds ────────────────────────────────────

  bool get isGhost => world == GraveWorld.ghost;

  /// THE PASSING. Free, both ways, unlimited — at a lych-stone only. Dying is
  /// easy here; it is deliberately the only easy thing, because the planet's
  /// difficulty must live in the COMMITMENTS and never in the toggle.
  void passOver() {
    world = otherWorld(world);
    passings++;
  }

  // ── The dead ──────────────────────────────────────────

  bool isRested(String revenantId) => rested.contains(revenantId);

  bool canTell(String revenantId) => !rested.contains(revenantId);

  /// Finish a death. Returns false when it was already finished.
  bool tell(String revenantId) => rested.add(revenantId);

  int get told => rested.length;

  // ── The map, in the world you are in ──────────────────

  /// Is [x] walkable by a LIVING body right now?
  ///
  /// Note what this never does: close. Telling and freezing only ever ADD to
  /// this set, which is half of why the living world can never strand you.
  bool openToLiving(GraveCrossing x) => switch (x.cut) {
    GraveCut.both => true,
    GraveCut.livingOnly => true,
    GraveCut.ghostOnly => x.freezable && cutFrozen,
    GraveCut.revenant => isRested(x.revenantId!),
  };

  /// Is [x] walkable by a DEAD body right now?
  ///
  /// A restless dead is holding its lintel up; a finished one has let go.
  bool openToGhost(GraveCrossing x) => switch (x.cut) {
    GraveCut.both => true,
    GraveCut.livingOnly => false,
    GraveCut.ghostOnly => true,
    GraveCut.revenant => !isRested(x.revenantId!),
  };

  bool openTo(GraveCrossing x, GraveWorld w) =>
      w == GraveWorld.living ? openToLiving(x) : openToGhost(x);

  /// Walkable by the body you are in right now.
  bool crossingOpen(GraveCrossing x) => openTo(x, world);

  /// Every crossing is walkable in exactly one world at any moment — except
  /// the frame stone (both) and a frozen cut (both). THE POINT: nothing is
  /// ever LOST from this map. A telling moves a crossing from one world to the
  /// other; it never deletes it. Asserted in the test.
  bool crossableSomewhere(GraveCrossing x) => openToLiving(x) || openToGhost(x);

  // ── Star 0 · THE COLD ROAD ────────────────────────────

  /// Requia's first star is a fact about the WORLD STATE, not about a room:
  /// *can the grave's own funeral leave?* The bier at the lych gate has stood
  /// unlifted since the cut drowned, because no LIVING road has run from the
  /// gate to the cairn at the head of the field. The moment one does, the
  /// procession walks it.
  ///
  /// Declared on the gate (Crystal's oriel precedent) because it belongs to no
  /// room, computed here so the engine, the renderer and the proof all ask the
  /// same question of the same code.
  bool get coldRoadOpen => livingReach().contains('barrow_cairn');

  /// Every room a living body can reach from the lych gate in this state.
  Set<String> livingReach() => _reach('lych_gate', GraveWorld.living);

  /// Every room a dead body can reach from [start].
  Set<String> ghostReach(String start) => _reach(start, GraveWorld.ghost);

  Set<String> _reach(String start, GraveWorld w) {
    final seen = <String>{start};
    final stack = <String>[start];
    while (stack.isNotEmpty) {
      final at = stack.removeLast();
      for (final x in kGraveCrossings) {
        if (x.from != at && x.to != at) continue;
        if (!openTo(x, w)) continue;
        final next = x.from == at ? x.to : x.from;
        if (seen.add(next)) stack.add(next);
      }
    }
    return seen;
  }
}

// ─────────────────────────────────────────────────────────
// PER-ROOM GRAVE CONTENT
// ─────────────────────────────────────────────────────────

/// The lych gate's declaration of the two non-guardian stars.
///
/// Neither belongs to a room: the Cold Road is a fact about the living
/// crossings of the whole field, and the Hourglass is a fact about two halves
/// of a sigil that are in different worlds. Declared once, on the gate — as
/// Crystal declares both of its on the oriel and Mud both of its on the
/// altar's socket.
class GraveVigil {
  final int roadStarIndex;
  final int sigilStarIndex;

  const GraveVigil({required this.roadStarIndex, required this.sigilStarIndex});
}

/// Everything the Echo Grave puts in one room. ONE field on the shared room
/// model (the Ice/Mud/Dust/Crystal/Plant precedent), because the field's own
/// crossing graph is authored whole above rather than per room.
class EchoGrave {
  /// This room is one of the seven barrows of the round.
  final bool barrow;

  /// The gate's declaration of the two non-guardian stars.
  final GraveVigil? vigil;

  /// A LYCH-STONE: the only place the party passes over. Element-only Spirit,
  /// both directions, unlimited. Five in the dungeon, three of them in the
  /// field — and their placement is half the no-strand proof, so they are not
  /// scenery and must not be moved without re-running it.
  final Offset? lychStone;

  /// The entry rite: the gate arch is choked with black water. Element-only
  /// Water draws it off and the field shows.
  final Offset? graveMouth;

  /// The drowned cut's brink, where the cold can settle it. Authored in the
  /// two rooms the cut joins.
  final Offset? drownedBrink;

  /// Star 1: the sigil half cut in this barrow's living floor.
  final Offset? sigilStone;

  /// The rite's first half is the name stone (conduit 'A', the Spirit+MASK
  /// gate); this is its second — the grave-lamp, element-only Crystal.
  final Offset? graveLamp;

  /// Wraithord's own lych-stone: the fight's whole verb (§7).
  final Offset? wraithStone;

  const EchoGrave({
    this.barrow = false,
    this.vigil,
    this.lychStone,
    this.graveMouth,
    this.drownedBrink,
    this.sigilStone,
    this.graveLamp,
    this.wraithStone,
  });
}

// ─────────────────────────────────────────────────────────
// COPY
// ─────────────────────────────────────────────────────────

/// Requia's lost maxim discovery id and its verse (§6 easter eggs #14 — *stamp
/// the minimap on your OWN position: the grave that replays is yours*).
const String kSpiritStuffOfDreamsEggId = 'egg:spirit_stuff_of_dreams';

// ─────────────────────────────────────────────────────────
// THE LAYOUT
// ─────────────────────────────────────────────────────────

/// Requia — the Echo Grave.
const DungeonLayout spiritLayout = DungeonLayout(
  element: 'Spirit',
  entranceRoomId: 'lych_gate',
  entranceSpawn: Offset(380, 380),
  title: 'THE ECHO GRAVE',
  descentTitle: 'Requia Grave',
  stars: [
    DungeonStarSpec(
      name: 'Cold Road Star',
      earnAnnouncement:
          'The Cold Road Star is yours, the bier goes up to the cairn at '
          'last, and something walks behind it',
    ),
    DungeonStarSpec(
      name: 'Hourglass Star',
      earnAnnouncement:
          'The Hourglass Star is yours, the ring closes, and the grave-field '
          'remembers where you stood',
    ),
    DungeonStarSpec(name: 'Wraith Star'),
  ],
  // The gate arch stands full of black water until a Water hand draws it off.
  entranceRevealDoor: DungeonDoorRef('lych_gate', 'barrow_urn'),
  finaleDoor: DungeonDoorRef('barrow_cairn', 'mourners_walk'),
  riteAnnouncement:
      'Road and Hourglass are won, the rood door grinds back off the '
      'mourners\' walk',
  finaleSealedHint:
      'The rood door is shut, it answers the Cold Road and the Hourglass',
  guardianSealedHint:
      'The last door will not own you, nothing behind it wakes until the '
      'lamp is lit',
  mercyShrineRoomId: 'lych_gate',
  // Ideal: Spiritmask · Waterpip · Crystalwing — hinted by VERB, never by body
  // part (§4): the sight that pierces the hidden, what the smallest doors
  // admit, and one the ground cannot keep.
  riddle: [
    'Send me Spirit: nothing in me was given a name you could read;',
    'a Water Pip, to set a mark finer than a grave-cutter\'s hand;',
    'and Crystal, for half of my roads are only remembered.',
  ],
  primer: [
    'One field, two worlds, and every crossing belongs to only one of them.',
    'A death finished in the cold world opens a road in the warm one.',
  ],
  // §4 budget: ONE hard gate (the grave sigil's Water Pip). The rite's name
  // stone was a Spirit MASK and is element-only now — the cold world is
  // what answers there, and any Spirit hand stands in it.
  // Superseded lines below describe the old pair:
  // §4 budget: TWO hard gates, on two different stars and two different entry
  // slots.
  //
  // §6.14 nominally hangs a SPIRITMASK gate on this planet's FIRST star (the
  // ghost route). §4's first-descent guarantee wins and that gate is MOVED
  // onto the rite's name stone: Star 0 — the Cold Road — is earnable by ANY
  // trio of Spirit/Water/Crystal, because the telling and the passing are both
  // element-only Spirit and the freeze is the planet's own braid
  // **Spirit+Water→Ice**. Spirit's Mask keeps its §6.14 job of reading the
  // hidden, but as tiered INSIGHT (§5.6), which is never a gate.
  //
  // The Crystal slot carries no hard gate — three gates would put two on one
  // star, which §4 forbids — but it is not decoration: the grave-lamp is
  // element-only Crystal and the braid **Crystal+Spirit→Light** is what makes
  // a light in a place that has none.
  familyGates: [
    DungeonFamilyGate(
      objectId: 'grave_sigil',
      element: 'Water',
      family: 'Pip',
      hintLine: 'Only the smallest hand sets a mark this fine',
    ),
  ],
  rooms: {
    // ── THE LYCH GATE (entrance · mercy · the vigil) ──────
    // The field's threshold, and the only room in Requia that is neither a
    // barrow nor behind the rood. The grave's own bier stands here, unlifted
    // since the cut drowned. Both non-guardian stars are declared from it.
    'lych_gate': DungeonRoom(
      id: 'lych_gate',
      bounds: Rect.fromLTWH(0, 0, 760, 520),
      walls: [
        Rect.fromLTWH(300, 250, 160, 30), // the bier's trestles
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(325, 0, 110, 24),
          targetRoomId: 'barrow_urn',
          targetSpawn: Offset(260, 300),
        ),
      ],
      grave: EchoGrave(
        vigil: GraveVigil(roadStarIndex: 0, sigilStarIndex: 1),
        graveMouth: Offset(380, 90),
        lychStone: Offset(150, 400),
      ),
    ),

    // ── THE URN BARROW (spine · lych-stone · two dead) ────
    // Where the field starts and where two of its six deaths are heard out.
    // Permanently ghost-joined to the veil by the lych road, which is
    // no-strand RULE 1 (see the header).
    'barrow_urn': DungeonRoom(
      id: 'barrow_urn',
      bounds: Rect.fromLTWH(0, 0, 520, 400),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(205, 376, 110, 24),
          targetRoomId: 'lych_gate',
          targetSpawn: Offset(380, 130),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(496, 145, 24, 110),
          targetRoomId: 'barrow_bell',
          targetSpawn: Offset(70, 180),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 145, 24, 110),
          targetRoomId: 'barrow_watch',
          targetSpawn: Offset(400, 180),
        ),
        // THE LYCH ROAD — ghost-only, and never decided.
        DungeonDoor(
          rect: Rect.fromLTWH(205, 0, 110, 24),
          targetRoomId: 'barrow_veil',
          targetSpawn: Offset(260, 300),
        ),
      ],
      grave: EchoGrave(
        barrow: true,
        lychStone: Offset(260, 210),
        sigilStone: Offset(260, 320),
      ),
    ),

    // ── THE BELL BARROW (pendant) ─────────────────────────
    // Off the spine on both sides: the bell walk and the veil steps are both
    // undecided. You can only ever be here as the dead while at least one of
    // them is restless, and neither is heard out from this room — RULE 2.
    'barrow_bell': DungeonRoom(
      id: 'barrow_bell',
      bounds: Rect.fromLTWH(0, 0, 460, 360),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 125, 24, 110),
          targetRoomId: 'barrow_urn',
          targetSpawn: Offset(450, 200),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(436, 125, 24, 110),
          targetRoomId: 'barrow_veil',
          targetSpawn: Offset(70, 200),
        ),
      ],
      grave: EchoGrave(barrow: true, sigilStone: Offset(230, 250)),
    ),

    // ── THE VEIL BARROW (spine · two dead · the cut's brink)
    'barrow_veil': DungeonRoom(
      id: 'barrow_veil',
      bounds: Rect.fromLTWH(0, 0, 520, 400),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 145, 24, 110),
          targetRoomId: 'barrow_bell',
          targetSpawn: Offset(400, 200),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(496, 145, 24, 110),
          targetRoomId: 'barrow_mere',
          targetSpawn: Offset(70, 210),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(205, 376, 110, 24),
          targetRoomId: 'barrow_urn',
          targetSpawn: Offset(260, 100),
        ),
        // THE DROWNED CUT — ghost-only until the cold settles it.
        DungeonDoor(
          rect: Rect.fromLTWH(205, 0, 110, 24),
          targetRoomId: 'barrow_cairn',
          targetSpawn: Offset(280, 330),
        ),
      ],
      grave: EchoGrave(
        barrow: true,
        drownedBrink: Offset(260, 70),
        sigilStone: Offset(260, 300),
      ),
    ),

    // ── THE MERE BARROW (the planet's sharpest trade) ─────
    // Pendant on both sides — the mere path and the sill are both undecided —
    // and the only door onto the hollow grave is cut in the ghost world alone.
    // The unmarked grave's MARK is the sigil stone's neighbour here, and only
    // a living hand reads a stone (§5.5 vault trick).
    'barrow_mere': DungeonRoom(
      id: 'barrow_mere',
      bounds: Rect.fromLTWH(0, 0, 560, 420),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 155, 24, 110),
          targetRoomId: 'barrow_veil',
          targetSpawn: Offset(450, 200),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(536, 155, 24, 110),
          targetRoomId: 'barrow_cairn',
          targetSpawn: Offset(70, 210),
        ),
        // THE HOLLOW GRAVE — there is no such door in the living wall.
        DungeonDoor(
          rect: Rect.fromLTWH(225, 0, 110, 24),
          targetRoomId: 'hollow_grave',
          targetSpawn: Offset(210, 225),
        ),
      ],
      grave: EchoGrave(barrow: true, sigilStone: Offset(280, 240)),
    ),

    // ── THE CAIRN BARROW (spine · lych-stone · the rood) ──
    // The head of the field, and the Cold Road's destination. Two dead are
    // heard out here, and the rood door onto the mourners' walk is frame
    // stone, so the rite is never behind a world.
    'barrow_cairn': DungeonRoom(
      id: 'barrow_cairn',
      bounds: Rect.fromLTWH(0, 0, 560, 440),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 165, 24, 110),
          targetRoomId: 'barrow_mere',
          targetSpawn: Offset(490, 210),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(536, 165, 24, 110),
          targetRoomId: 'barrow_ash',
          targetSpawn: Offset(70, 180),
        ),
        // THE DROWNED CUT, from the north bank.
        DungeonDoor(
          rect: Rect.fromLTWH(225, 416, 110, 24),
          targetRoomId: 'barrow_veil',
          targetSpawn: Offset(260, 100),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(225, 0, 110, 24),
          targetRoomId: 'mourners_walk',
          targetSpawn: Offset(320, 345),
        ),
      ],
      grave: EchoGrave(
        barrow: true,
        lychStone: Offset(280, 220),
        drownedBrink: Offset(280, 386),
        sigilStone: Offset(280, 90),
      ),
    ),

    // ── THE ASH BARROW (pendant) ──────────────────────────
    // One undecided crossing (the ash gate, heard out at the cairn) and one
    // salted step the dead may not take.
    'barrow_ash': DungeonRoom(
      id: 'barrow_ash',
      bounds: Rect.fromLTWH(0, 0, 460, 360),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 125, 24, 110),
          targetRoomId: 'barrow_cairn',
          targetSpawn: Offset(490, 220),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(436, 125, 24, 110),
          targetRoomId: 'barrow_watch',
          targetSpawn: Offset(60, 180),
        ),
      ],
      grave: EchoGrave(barrow: true, sigilStone: Offset(230, 250)),
    ),

    // ── THE WATCH BARROW (pendant) ────────────────────────
    'barrow_watch': DungeonRoom(
      id: 'barrow_watch',
      bounds: Rect.fromLTWH(0, 0, 460, 360),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 125, 24, 110),
          targetRoomId: 'barrow_ash',
          targetSpawn: Offset(400, 180),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(436, 125, 24, 110),
          targetRoomId: 'barrow_urn',
          targetSpawn: Offset(70, 200),
        ),
      ],
      grave: EchoGrave(barrow: true, sigilStone: Offset(230, 250)),
    ),

    // ── THE HOLLOW GRAVE (the vault) ──────────────────────
    // A grave that was cut and never used, and that the living world does not
    // contain. Its one door is never blocked by anything: a pocket you walked
    // into dead you can always walk out of dead (Plant's rim-door rule), which
    // is what keeps the vault trick from being a trap.
    'hollow_grave': DungeonRoom(
      id: 'hollow_grave',
      bounds: Rect.fromLTWH(0, 0, 420, 300),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(155, 276, 110, 24),
          targetRoomId: 'barrow_mere',
          targetSpawn: Offset(280, 105),
        ),
      ],
      vaultCache: Offset(210, 150),
      grave: EchoGrave(),
    ),

    // ── THE MOURNERS' WALK (the rite) ─────────────────────
    // Conduit A is the planet's Spirit+MASK gate — the name stone, which has
    // never had a name on it. The grave-lamp is the rite's other half:
    // element-only Crystal, so a party that brought no Mask meets exactly ONE
    // refusal here rather than two (the Ice/Crystal precedent).
    'mourners_walk': DungeonRoom(
      id: 'mourners_walk',
      bounds: Rect.fromLTWH(0, 0, 640, 460),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(265, 436, 110, 24),
          targetRoomId: 'barrow_cairn',
          targetSpawn: Offset(280, 110),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(265, 0, 110, 24),
          targetRoomId: 'wraithord_grave',
          targetSpawn: Offset(450, 480),
        ),
      ],
      conduits: [
        Conduit(
          id: 'A',
          position: Offset(190, 250),
          // ELEMENT-ONLY. This was a Spirit MASK gate; the name stone answers
          // the cold world itself, and any Spirit hand stands in it.
          requireElement: 'Spirit',
        ),
        // Conduit 'B' is NOT authored as a Conduit: it is the grave-lamp
        // below, an element-only Crystal object this planet's module owns and
        // which latches `conduitEnergy['B']` itself (the Ice/Crystal
        // precedent — authoring it family-less would make the shared channel
        // verb step over it and the layout invariants read it as a
        // storm-struck pylon with no storm).
      ],
      grave: EchoGrave(
        graveLamp: Offset(450, 250),
        lychStone: Offset(320, 380),
      ),
    ),

    // ── WRAITHORD'S GRAVE (Star 2) ────────────────────────
    // §7 — the guardian fights WITH the planet's rule. MYS14 walks both worlds
    // and is only ever solid in one of them; it crosses over on its own beat.
    // While it is in the world you are in, it can be struck and it strikes;
    // while it is in the other, nothing you do reaches it and nothing it does
    // reaches you. The arena's lych-stone is the only weapon in the room.
    'wraithord_grave': DungeonRoom(
      id: 'wraithord_grave',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 616, 110, 24),
          targetRoomId: 'mourners_walk',
          targetSpawn: Offset(320, 115),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(450, 300),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Spirit',
          mysticId: 'Wraithord',
          canCalm: true,
          canDefeat: true,
        ),
      ),
      grave: EchoGrave(
        wraithStone: Offset(450, 540),
        lychStone: Offset(450, 540),
      ),
    ),
  },
);
