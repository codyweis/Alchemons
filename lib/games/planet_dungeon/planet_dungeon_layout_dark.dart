// lib/games/planet_dungeon/planet_dungeon_layout_dark.dart
//
// NYTHRALOR — the Eclipse Vault. Dark's authored layout, its pure rules, and
// the puzzle DATA its `part of planet_dungeon_game.dart` module reasons about.
//
// TOPOLOGY (docs/dungeons.md §5.5, structural assignment table): **AN
// INVERTING MAZE — light/dark flips swap walls and doors.** There is no hub,
// no wings, and no room that keeps the same doors for a whole run. The vault
// is one geometry cut into four QUARTERS, and each quarter is either in
// UMBRA (shadow) or in CORONA (light). Which it is decides, for every
// passage in it, whether that passage is a door or a wall:
//
//     ── the vault, ONE geometry, four quarters ─────────────
//      I  THE PALL      pall_porch ·gnomon· ── analemma_court
//                          ╵pall(u.II)          ╵lych-way(u.II)
//      II THE GALLERY   shade_gallery ────── penumbral_walk ·gnomon·
//                          ╵shaft(u.III)        ╵stair head(u.III)
//      III THE OSSUARY  ossuary_ring ─────── gnomon_stair ·gnomon·
//                          ╵causeway(u.IV)      ╵gulf(u.IV)
//      IV THE DEEP      eclipse_nave ─────── abyssal_font ── umbral_reliquary
//                          ╵rood                                (THE VAULT)
//                       noctryos_totality
//
//     (a horizontal pairing inside a quarter is a LIGHT-WALK — it exists only
//      while that quarter stands in the light. Every vertical crossing is a
//      SHADOW-WAY — it exists only while the quarter BELOW lies in shadow.)
//
// WORLD RULE — *a lamp here does not light the room; it turns it inside out.*
//
// THE INVARIANT (§5.5, Dark's claimed mechanic): **STATE-FLIP MAZE
// INVERSION, and it is ZERO-SUM BY GEOMETRY.** The player never sets a
// quarter's state directly. Nythralor's shadow is thrown by three GNOMONS —
// stone fingers standing at the quarter-lines — and *a shadow is a physical
// thing that can only be in one place*. Each gnomon's shadow lies in ONE of
// the two quarters it stands between. Turn it and the shadow crosses over:
// the quarter it leaves comes up into the light, the quarter it enters goes
// dark. One turn rewrites both quarters at once — half the vault — and it
// gives you nothing it does not also take.
//
// THE STRATEGIC QUESTION (§5.5): *every flip you make for a door closes one
// elsewhere — a gnomon's shadow has to be in one of its two quarters, so the
// road you open downward is usually the road you came in by.* The sharpest
// instance is authored on purpose at the deep line: the gulf into the abyssal
// font wants the DEEP in shadow, and the vault's own slot wants the same
// shadow one room further in — but the way DOWN to the stair wants the
// OSSUARY in shadow, and one gnomon cannot hold both. You must have brought
// the ossuary's shadow off the OTHER gnomon before you ever came down.
//
// This is deliberately NOT Spirit's seat. Spirit's two worlds COEXIST and the
// player picks which one to be in at each junction; here there is one world
// and one act — a global inversion that rewrites the whole maze at once, with
// nothing to opt out of. It is not Lightning's zero-sum either: Lightning's
// is electrical (power here is dark there, along a circuit); Nythralor's is
// purely spatial — a shadow has a POSITION, and it has only one. Nor is it
// Dust's Z-layer (there is no second deck and no ledger), Plant's observer
// scale (the vault changes, not you), Crystal's permuting map (nothing here
// moves), Air's ordering (a turn is freely reversible, so order is nothing —
// ARRANGEMENT is everything), Mud's shape-authoring, or Steam's budget. No
// quantity is counted anywhere on this planet; the zero-sum is the geometry.
//
// ── THE ECLIPSE ALGEBRA (all of it, and all provable) ─────
// Three gnomons over four quarters, chained: the porch gnomon holds PALL or
// GALLERY, the walk gnomon GALLERY or OSSUARY, the stair gnomon OSSUARY or
// DEEP. A quarter is dark iff some gnomon's shadow lies in it. That gives
// eight arrangements, and these facts fall straight out of them (pinned by
// test/planet_dungeon_dark_vault_test.dart):
//
//   • **Never fewer than two quarters in shadow, and never more than two in
//     the light.** Three shadows, and every one of them is somewhere.
//   • **No two NEIGHBOURING quarters are ever lit together** — the gnomon
//     between them has to put its shadow in one of them. Only {PALL,
//     OSSUARY}, {PALL, DEEP} and {GALLERY, DEEP} can ever share the light.
//   • **All four quarters are never dark at once.** This is what makes Star 0
//     a journey instead of a button.
//   • **THE GNOMON'S PROMISE:** for each gnomon, at least one of its two
//     quarters is in shadow, always. Every safe road in the vault is built on
//     this one sentence.
//
// THE VAULT TRICK (§5.5): *the vault room only EXISTS in the dark state.* The
// umbral reliquary is not a room you have not found — while the DEEP stands
// in light it is not there at all, and the slot in the font's wall is a
// blank face of stone with nothing to see. No prior planet's trick is this:
// Plant's is visible-but-too-small, Ice's a mirror plus an unrepeatable
// slide, Dust's a house you bury HARDER, Poison's the ward you abandoned,
// Steam's spending the whole budget, Lightning's a dead trunk walked dark,
// Crystal's a cell that only joins the grid in one configuration.
//
// ── WHY THERE IS NO RESET VALVE ───────────────────────────
// Ice, Mud, Dust and Plant all shipped a costly full-reset valve. Nythralor
// does not need one, and the reason is structural rather than measured (the
// measurement is in `solveEclipseVault`, and it agrees: **0 strandable of 542
// reachable states**):
//
//   1. **A turn is its own undo.** You turn a gnomon by standing at it, and
//      you are still standing at it afterwards — so every turn can be turned
//      straight back. The walk/turn relation is symmetric, so reachability
//      over it is an equivalence: whatever the vault can put you in, it can
//      take you out of.
//   2. **A room with no gnomon can never be shut on you.** Nothing but a
//      gnomon changes a quarter's state, so while you stand in a gnomon-less
//      room the doors you walked in by are still the doors you have. The
//      umbral reliquary and the analemma court are exactly this, and it is
//      why the vault trick is not a trap (Ice's shelf rule).
//   3. **A gnomon room is rescued by its own gnomon** — every gnomon stands
//      in the UPPER of the two quarters it commands, never behind the door it
//      opens. This is the one placement the geometry actually depends on: put
//      the stair's gnomon down in the deep instead, where it would be behind
//      the very gulf it opens, and the whole lower half of the vault becomes
//      a one-way trip (the counterfactual is pinned in the test, and it is
//      not a near miss — it strands from EVERY state).
//   4. **The one thing that can flip the vault while you are not at a gnomon
//      is Noctryos**, and the arena is proofed against it twice: the rood
//      door is the vault's only phase-free passage, and the arena floor
//      carries a VANE that turns the stair gnomon from where you stand. Pull
//      the vane and phase-cut the rood door and 28 states strand — which is
//      the number that says the arena's two belts are load-bearing.
//
// So the anchors (below) are the only irreversible edits on the planet, and
// they are purely ADDITIVE — a portal opens and never closes. An additive
// edit cannot shrink reachability, so it cannot strand either.
//
// Mechanic-ledger note (§5.5): Dark claims **state-flip maze inversion** and,
// under it, **the shadow as a positional zero-sum** — one shadow, two
// quarters, and the act of taking it out of one IS the act of putting it in
// the other. Nothing is counted, nothing is spent, and nothing is ordered.
//
// VISUAL GRAMMAR (§5.5): nothing here is drawn like Lightning's jagged bolts
// or Water's tide line. A quarter in UMBRA is rendered as an absence — its
// architecture is drawn as negative space, edges only, and its shadow-ways
// read as gaps in the wall with no threshold. A quarter in CORONA is drawn in
// full: a cold pewter light, hard-edged, and its light-walks are pale
// causeways with a visible floor. The inversion animates as a WIPE across the
// room, never a fade, so the player reads it as the world turning over rather
// than a lamp going out. No blur filters anywhere (the game's known jank
// source).

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

// ─────────────────────────────────────────────────────────
// THE QUARTERS
// ─────────────────────────────────────────────────────────

/// The four leaves of the eclipse. Nythralor is cut into these and nothing
/// else: every room lies in exactly one, and every passage is cut through
/// exactly one. There is no fifth state and no in-between, so the player can
/// read the whole map off four words.
enum EclipseLeaf {
  /// I — the threshold quarter. The porch and the analemma court.
  pall,

  /// II — the long gallery quarter. The shade gallery and the penumbral walk.
  gallery,

  /// III — the bone quarter. The gnomon stair and the ossuary ring.
  ossuary,

  /// IV — everything under the vault: the abyssal font, the reliquary, the
  /// nave, and Noctryos.
  deep,
}

/// The vault's own name for each quarter, for hints and the readout.
String leafWord(EclipseLeaf l) => switch (l) {
  EclipseLeaf.pall => 'the Pall',
  EclipseLeaf.gallery => 'the Gallery',
  EclipseLeaf.ossuary => 'the Ossuary',
  EclipseLeaf.deep => 'the Deep',
};

/// Short all-caps form for the progress readout (§5.6 — state leaves the
/// capsule).
String leafTag(EclipseLeaf l) => switch (l) {
  EclipseLeaf.pall => 'PALL',
  EclipseLeaf.gallery => 'GALL',
  EclipseLeaf.ossuary => 'OSS',
  EclipseLeaf.deep => 'DEEP',
};

// ─────────────────────────────────────────────────────────
// THE GNOMONS
// ─────────────────────────────────────────────────────────

/// A stone finger standing at a quarter-line, throwing one shadow.
///
/// AUTHORING RULE, and the whole no-strand proof rests on it: a gnomon stands
/// in the UPPER of its two quarters — never behind the door it commands. A
/// gnomon you can only reach through the passage it controls is a one-way
/// trip, and the test pins what happens if anyone moves one (see the header).
class Gnomon {
  final String id;

  /// The room the finger stands in. Always a room of [upper].
  final String roomId;

  /// Where in [roomId] the shaft is (the turn verb's reach).
  final Offset shaft;

  /// The quarter this gnomon stands in, and the quarter below it. The shadow
  /// is in one of these two, always, and never in both.
  final EclipseLeaf upper;
  final EclipseLeaf lower;

  /// One clause of scenery, for the reading and the render.
  final String look;

  const Gnomon({
    required this.id,
    required this.roomId,
    required this.shaft,
    required this.upper,
    required this.lower,
    required this.look,
  });

  /// True when this gnomon can put its shadow into [leaf].
  bool serves(EclipseLeaf leaf) => leaf == upper || leaf == lower;
}

/// Nythralor's three gnomons, chained down the vault. Three shadows over four
/// quarters is what makes the whole thing zero-sum: there are never enough
/// shadows to darken everything and never few enough to light it.
const List<Gnomon> kVaultGnomons = [
  // THE PORCH GNOMON. Stands in the entrance, and the planet teaches itself
  // here in one object: the porch's two ways out are the two quarters this
  // finger stands between, so it can never give you both at once by itself.
  Gnomon(
    id: 'gn_porch',
    roomId: 'pall_porch',
    shaft: Offset(360, 250),
    upper: EclipseLeaf.pall,
    lower: EclipseLeaf.gallery,
    look: 'the porch gnomon, black glass on a bronze collar',
  ),
  // THE WALK GNOMON. It commands the gallery/ossuary line from ABOVE it —
  // which is what keeps the lower half of the vault from being a one-way
  // trip, since nothing down there can reach back up to set the ossuary's
  // shadow.
  Gnomon(
    id: 'gn_walk',
    roomId: 'penumbral_walk',
    shaft: Offset(420, 270),
    upper: EclipseLeaf.gallery,
    lower: EclipseLeaf.ossuary,
    look: 'the walk gnomon, leaning where the colonnade breaks',
  ),
  // THE STAIR GNOMON. The deep quarter's only control, and it deliberately
  // does NOT stand in the deep. Noctryos is the one thing that can turn it
  // from below, through the arena's vane.
  Gnomon(
    id: 'gn_stair',
    roomId: 'gnomon_stair',
    shaft: Offset(380, 250),
    upper: EclipseLeaf.ossuary,
    lower: EclipseLeaf.deep,
    look: 'the stair gnomon, taller than the stair it stands on',
  ),
];

Gnomon? vaultGnomonById(String id) {
  for (final g in kVaultGnomons) {
    if (g.id == id) return g;
  }
  return null;
}

Gnomon? vaultGnomonIn(String roomId) {
  for (final g in kVaultGnomons) {
    if (g.roomId == roomId) return g;
  }
  return null;
}

// ─────────────────────────────────────────────────────────
// SPANS — the map, in both states at once
// ─────────────────────────────────────────────────────────

/// How the eclipse cut a passage.
enum SpanCut {
  /// A shadow-way. There is no threshold and no door — it is a hole in the
  /// dark, and where there is light there is no hole. Every crossing between
  /// two quarters is one of these, cut through the LOWER quarter, which is
  /// why you only ever go DOWN into Nythralor through shadow.
  shadowWay,

  /// A light-walk. A pale causeway with a floor you can see. Every passage
  /// INSIDE a quarter is one of these, so a quarter in shadow is split from
  /// itself and a quarter in light is whole.
  lightWalk,

  /// The one passage the eclipse does not reach: the rood door. It is
  /// phase-free on purpose — see the header, reason 4.
  unmoved,
}

/// One passage of the vault, authored once and read from both ends.
///
/// The layout test enforces that EVERY door has a reciprocal door, statically
/// (§5.5 keeps that invariant for the whole game). A map whose connectivity
/// changes at runtime lives inside that rule the only honest way, the one
/// Crystal established and Plant reused: **the doors are constant and
/// reciprocal, and what varies is whether the passage exists in the state the
/// vault is currently in.**
class VaultSpan {
  final String id;
  final String from;
  final String to;
  final SpanCut cut;

  /// The quarter this passage is cut through — the one whose state decides
  /// it. Null exactly when [cut] is [SpanCut.unmoved].
  final EclipseLeaf? leaf;

  /// One clause naming the passage, used by the blocked line and the render.
  final String look;

  const VaultSpan({
    required this.id,
    required this.from,
    required this.to,
    required this.cut,
    required this.look,
    this.leaf,
  });

  bool joins(String a, String b) =>
      (from == a && to == b) || (from == b && to == a);
}

/// The whole vault as passages. Twelve, and every room pair appears exactly
/// once — so a door and a span are one-to-one and the no-strand proof cannot
/// drift from the doors the player actually meets.
const List<VaultSpan> kVaultSpans = [
  // ── QUARTER I · THE PALL ─────────────────────────────
  VaultSpan(
    id: 'sp_glimmer',
    from: 'pall_porch',
    to: 'analemma_court',
    cut: SpanCut.lightWalk,
    leaf: EclipseLeaf.pall,
    look: 'the glimmer along the porch wall',
  ),
  // The entrance's other way out, and the vault's first lesson: one of these
  // two is always shut, and the finger that decides stands between them.
  VaultSpan(
    id: 'sp_pall',
    from: 'pall_porch',
    to: 'shade_gallery',
    cut: SpanCut.shadowWay,
    leaf: EclipseLeaf.gallery,
    look: 'the pall arch',
  ),
  VaultSpan(
    id: 'sp_lychway',
    from: 'analemma_court',
    to: 'penumbral_walk',
    cut: SpanCut.shadowWay,
    leaf: EclipseLeaf.gallery,
    look: 'the lych-way',
  ),

  // ── QUARTER II · THE GALLERY ─────────────────────────
  VaultSpan(
    id: 'sp_colonnade',
    from: 'shade_gallery',
    to: 'penumbral_walk',
    cut: SpanCut.lightWalk,
    leaf: EclipseLeaf.gallery,
    look: 'the colonnade',
  ),
  VaultSpan(
    id: 'sp_shaft',
    from: 'shade_gallery',
    to: 'ossuary_ring',
    cut: SpanCut.shadowWay,
    leaf: EclipseLeaf.ossuary,
    look: 'the dry well shaft',
  ),
  VaultSpan(
    id: 'sp_stairhead',
    from: 'penumbral_walk',
    to: 'gnomon_stair',
    cut: SpanCut.shadowWay,
    leaf: EclipseLeaf.ossuary,
    look: 'the stair head',
  ),

  // ── QUARTER III · THE OSSUARY ────────────────────────
  VaultSpan(
    id: 'sp_ambulatory',
    from: 'gnomon_stair',
    to: 'ossuary_ring',
    cut: SpanCut.lightWalk,
    leaf: EclipseLeaf.ossuary,
    look: 'the ambulatory',
  ),
  VaultSpan(
    id: 'sp_gulf',
    from: 'gnomon_stair',
    to: 'abyssal_font',
    cut: SpanCut.shadowWay,
    leaf: EclipseLeaf.deep,
    look: 'the gulf under the last step',
  ),
  VaultSpan(
    id: 'sp_causeway',
    from: 'ossuary_ring',
    to: 'eclipse_nave',
    cut: SpanCut.shadowWay,
    leaf: EclipseLeaf.deep,
    look: 'the causeway',
  ),

  // ── QUARTER IV · THE DEEP ────────────────────────────
  VaultSpan(
    id: 'sp_undercroft',
    from: 'abyssal_font',
    to: 'eclipse_nave',
    cut: SpanCut.lightWalk,
    leaf: EclipseLeaf.deep,
    look: 'the undercroft',
  ),
  // THE VAULT (§5.5): while the deep stands in light there is no slot and no
  // room — not a door you have not opened, a room that is not there. The
  // party can only ever be inside it while the deep lies in shadow, and
  // nothing in the reliquary can change that, which is what keeps the trick
  // from being a trap (Ice's shelf rule; see the header, reason 2).
  VaultSpan(
    id: 'sp_slot',
    from: 'abyssal_font',
    to: 'umbral_reliquary',
    cut: SpanCut.shadowWay,
    leaf: EclipseLeaf.deep,
    look: 'the slot in the font\'s west wall',
  ),
  // The one passage the eclipse never touches.
  VaultSpan(
    id: 'sp_rood',
    from: 'eclipse_nave',
    to: 'noctryos_totality',
    cut: SpanCut.unmoved,
    look: 'the rood door',
  ),
];

/// The span joining these two rooms, or null. One pair, one span — pinned by
/// the tests.
VaultSpan? vaultSpanBetween(String a, String b) {
  for (final s in kVaultSpans) {
    if (s.joins(a, b)) return s;
  }
  return null;
}

// ─────────────────────────────────────────────────────────
// STAR 0 — THE ANALEMMA
// ─────────────────────────────────────────────────────────

/// One of the four shadow-stones standing on the analemma court's floor dial.
///
/// Star 0 is the planet's FIRST-DESCENT star (§4): it is earnable by ANY trio
/// of Dark/Poison/Spirit, uses all three elements at full power, and needs no
/// anchor unlocked and no portal walked. It teaches the whole planet in one
/// errand — a stone can only be seated while its OWN quarter lies in shadow,
/// and the eclipse never leaves all four quarters in shadow at once, so the
/// dial cannot be finished in one shape of the vault. It is not four verbs;
/// it is at least two arrangements, and a walk to a gnomon and back between
/// them.
///
/// §6 put a Darkmask gate on this planet's FIRST star (flipping room states).
/// §4's first-descent guarantee wins: the flipping verb is element-only Dark
/// and the Darkmask gate has moved onto the rite's reredos, exactly as Plant
/// moved its Plantmane gate off Star 0 and onto the rood screen.
class ShadowStone {
  final String id;

  /// The quarter this stone reads. It seats only while that quarter is dark.
  final EclipseLeaf leaf;

  /// The element that seats it. Element-only (§4) — any family, full power.
  /// All three of the planet's entry elements appear, so the ideal trio is
  /// not required and any correct-element party finishes the dial.
  final String element;

  /// Where on the dial it stands.
  final Offset position;

  const ShadowStone({
    required this.id,
    required this.leaf,
    required this.element,
    required this.position,
  });
}

/// The four stones, in the order the dial reads them (they may be seated in
/// any order — nothing here is a sequence; Fire owns that seat).
const List<ShadowStone> kShadowStones = [
  ShadowStone(
    id: 'stone_pall',
    leaf: EclipseLeaf.pall,
    element: 'Dark',
    position: Offset(250, 200),
  ),
  ShadowStone(
    id: 'stone_gallery',
    leaf: EclipseLeaf.gallery,
    element: 'Spirit',
    position: Offset(350, 150),
  ),
  ShadowStone(
    id: 'stone_ossuary',
    leaf: EclipseLeaf.ossuary,
    element: 'Poison',
    position: Offset(450, 200),
  ),
  ShadowStone(
    id: 'stone_deep',
    leaf: EclipseLeaf.deep,
    element: 'Dark',
    position: Offset(350, 260),
  ),
];

ShadowStone? shadowStoneById(String id) {
  for (final s in kShadowStones) {
    if (s.id == id) return s;
  }
  return null;
}

// ─────────────────────────────────────────────────────────
// STAR 1 — THE SHADOW-PORTALS
// ─────────────────────────────────────────────────────────

/// A shadow-anchor: an iron ring driven into the dark, one at each end of a
/// portal (§6's "shadow-portal maze — Spirit reveals destinations, Poisonpip
/// unlocks anchors").
///
/// The ring is rusted into its socket. A **Poison PIP** — the planet's one
/// star-level family gate (§4: max one per star) — is small enough to work
/// inside the ring and its venom is what eats the rust. Once unlocked the
/// portal is permanent for the run.
///
/// A portal is a hole in the dark, so it carries you only while **BOTH its
/// ends lie in shadow** — which is the mechanic folded back into the eclipse
/// rather than bolted beside it. Note what this does NOT do: it never removes
/// a passage. Anchors are the only irreversible edits on the planet and they
/// are purely additive, which is why they cannot strand (see the header).
class ShadowAnchor {
  final String id;

  /// The two rooms the portal joins, and where each ring hangs. Either end
  /// unlocks the pair — a rusted ring is a rusted ring from both sides.
  final String near;
  final String far;
  final Offset nearRing;
  final Offset farRing;

  /// One clause of scenery for the render and the blocked line.
  final String look;

  const ShadowAnchor({
    required this.id,
    required this.near,
    required this.far,
    required this.nearRing,
    required this.farRing,
    required this.look,
  });

  bool touches(String roomId) => roomId == near || roomId == far;

  String? other(String roomId) => roomId == near
      ? far
      : roomId == far
      ? near
      : null;

  Offset? ringIn(String roomId) => roomId == near
      ? nearRing
      : roomId == far
      ? farRing
      : null;
}

/// The three anchors. Each joins two quarters that are NOT neighbours, so a
/// portal is always a real short-cut and never a duplicate of a span — and
/// each wants a different pair of quarters in shadow, so no single
/// arrangement of the gnomons walks all three. Star 1 is therefore a
/// planning problem over the eclipse, not an errand.
const List<ShadowAnchor> kVaultAnchors = [
  // PALL ↔ OSSUARY. Wants the pall and the ossuary both dark.
  ShadowAnchor(
    id: 'an_court',
    near: 'analemma_court',
    far: 'ossuary_ring',
    nearRing: Offset(120, 380),
    farRing: Offset(140, 420),
    look: 'the ring under the dial\'s north stone',
  ),
  // GALLERY ↔ DEEP. Its far ring hangs inside the reliquary, so once this one
  // is open the vault has a second mouth — never the only one, though: the
  // slot is open in every arrangement this portal is.
  ShadowAnchor(
    id: 'an_walk',
    near: 'penumbral_walk',
    far: 'umbral_reliquary',
    nearRing: Offset(660, 430),
    farRing: Offset(120, 250),
    look: 'the ring in the walk\'s broken pier',
  ),
  // DEEP ↔ PALL. The long one, and the way back up out of the nave.
  ShadowAnchor(
    id: 'an_nave',
    near: 'eclipse_nave',
    far: 'pall_porch',
    nearRing: Offset(660, 440),
    farRing: Offset(140, 380),
    look: 'the ring behind the nave\'s cold stoup',
  ),
];

ShadowAnchor? vaultAnchorById(String id) {
  for (final a in kVaultAnchors) {
    if (a.id == id) return a;
  }
  return null;
}

List<ShadowAnchor> vaultAnchorsIn(String roomId) =>
    [for (final a in kVaultAnchors) if (a.touches(roomId)) a];

// ─────────────────────────────────────────────────────────
// THE LIVE STATE — pure rules, no Flutter, no engine
// ─────────────────────────────────────────────────────────

/// Everything Nythralor tracks for one run.
///
/// Kept deliberately small: this planet's whole difficulty is a REACHABILITY
/// question, so the state is the one thing reachability depends on — where
/// each gnomon's shadow lies — plus the per-star tallies.
class EclipseVault {
  EclipseVault() {
    reset();
  }

  /// Which of its two quarters each gnomon's shadow lies in, keyed by
  /// [Gnomon.id]. This IS the map: everything else is derived.
  final Map<String, EclipseLeaf> shadow = {};

  /// Shadow-stones seated on the analemma (Star 0).
  final Set<String> stonesSeated = {};

  /// Anchors whose rust a Poison pip has eaten (Star 1's prerequisite).
  final Set<String> anchorsOpen = {};

  /// Anchors whose far end a Spirit hand has read. Purely informational —
  /// walking an unread portal works, you just do not know where it goes.
  final Set<String> anchorsRead = {};

  /// Portals actually WALKED (Star 1's success). Unlocking is not enough;
  /// the star is the transit, which is what makes it an eclipse problem.
  final Set<String> portalsWalked = {};

  /// Seconds the party has stood perfectly still in the abyssal font while
  /// the deep lay in shadow (the Lost Maxim).
  double abyssStillness = 0;
  bool abyssGazed = false;

  /// How many times the vault has been turned inside out — the readout's
  /// second line, and the closest thing this planet has to a price tag.
  int inversions = 0;

  /// Nythralor as the eclipse left it: the pall, the gallery and the ossuary
  /// in shadow, and only the deep in light. The porch's one open road is the
  /// pall arch, so the run begins with a single choice of direction and the
  /// court shut behind the porch's own gnomon — the planet, in one room.
  void reset() {
    shadow
      ..clear()
      ..['gn_porch'] = EclipseLeaf.pall
      ..['gn_walk'] = EclipseLeaf.gallery
      ..['gn_stair'] = EclipseLeaf.ossuary;
    stonesSeated.clear();
    anchorsOpen.clear();
    anchorsRead.clear();
    portalsWalked.clear();
    abyssStillness = 0;
    abyssGazed = false;
    inversions = 0;
  }

  // ── The eclipse ───────────────────────────────────────

  /// Where [gnomonId]'s shadow lies right now.
  EclipseLeaf shadowOf(String gnomonId) =>
      shadow[gnomonId] ?? vaultGnomonById(gnomonId)!.upper;

  /// A quarter is dark iff SOME gnomon's shadow lies in it. Two gnomons can
  /// both point at the same quarter — which is the deeper lesson of the
  /// planet: a quarter's shadow can come off either finger that touches it,
  /// so "which shadow do I spend here" is a real question.
  bool isDark(EclipseLeaf leaf) => shadow.values.contains(leaf);

  bool isLit(EclipseLeaf leaf) => !isDark(leaf);

  /// The quarters standing in light. Never more than two, and never two that
  /// share a gnomon (see the header's algebra).
  List<EclipseLeaf> get litLeaves =>
      [for (final l in EclipseLeaf.values) if (isLit(l)) l];

  /// Turn a gnomon: its shadow crosses to the other quarter it serves. The
  /// leaf it leaves comes up, the leaf it enters goes down. Always legal,
  /// always reversible — reason 1 of the no-strand proof.
  ///
  /// Returns the quarter the shadow moved INTO, or null if there is no such
  /// gnomon.
  EclipseLeaf? turn(String gnomonId) {
    final g = vaultGnomonById(gnomonId);
    if (g == null) return null;
    final next = shadowOf(gnomonId) == g.upper ? g.lower : g.upper;
    shadow[gnomonId] = next;
    inversions++;
    return next;
  }

  // ── The map, in the state the vault is in ─────────────

  /// Whether [span] EXISTS right now. A shadow-way is there while its quarter
  /// lies in shadow; a light-walk while its quarter stands in light; the rood
  /// door always.
  bool spanOpen(VaultSpan span) => switch (span.cut) {
    SpanCut.unmoved => true,
    SpanCut.shadowWay => isDark(span.leaf!),
    SpanCut.lightWalk => isLit(span.leaf!),
  };

  /// Whether a portal carries right now: unlocked, and BOTH ends in shadow.
  bool portalOpen(ShadowAnchor a, Map<String, EclipseLeaf> leafOfRoom) {
    if (!anchorsOpen.contains(a.id)) return false;
    final n = leafOfRoom[a.near];
    final f = leafOfRoom[a.far];
    if (n == null || f == null) return false;
    return isDark(n) && isDark(f);
  }

  // ── Star 0 ────────────────────────────────────────────

  bool get analemmaWoken => stonesSeated.length >= kShadowStones.length;

  /// Whether [stone] can be seated in the arrangement the vault is in.
  bool canSeat(ShadowStone stone) =>
      !stonesSeated.contains(stone.id) && isDark(stone.leaf);

  // ── Star 1 ────────────────────────────────────────────

  bool get everyPortalWalked => portalsWalked.length >= kVaultAnchors.length;
}

// ─────────────────────────────────────────────────────────
// PER-ROOM VAULT CONTENT
// ─────────────────────────────────────────────────────────

/// Everything the Eclipse Vault put in one room. Carried on
/// `DungeonRoom.eclipse` so exactly one field had to be added to the shared
/// room model, and so a room's star index and its QUARTER are visible to the
/// layout invariants and to the proof.
class EclipseHall {
  /// The quarter this room lies in. Required — the whole planet is this.
  final EclipseLeaf leaf;

  /// The star this room banks (null = a connective walk).
  final int? starIndex;

  /// The entry rite: the pall itself, a curtain of shadow-cloth knotted
  /// across the arch. Element-only Dark (§4).
  final Offset? pallCurtain;

  /// Star 0: the analemma dial, and the four stones standing on it.
  final Offset? analemma;

  /// The rite's black-glass reredos — the planet's Dark+MASK gate, authored
  /// as conduit 'A' in the nave.
  ///
  /// The nave's other half is [snuffer]: an element-only Dark object the
  /// module owns and which latches `conduitEnergy['B']` itself. Authoring it
  /// as a family-less Conduit would let the engine's channel verb step over
  /// it — the same reason Ice left its cold font out, Dust its great glass,
  /// and Plant its sepulchre.
  final Offset? snuffer;

  /// The Lost Maxim: the abyss in the font's floor. §6 — stand utterly still
  /// in total darkness for a full minute, casting no light.
  final Offset? abyss;

  /// Noctryos's arena floor-vane: it turns the stair gnomon from down here.
  /// The deep quarter has no gnomon of its own on purpose (see the header),
  /// so this is the fight's verb AND the arena's safety belt.
  final Offset? shadowVane;

  const EclipseHall({
    required this.leaf,
    this.starIndex,
    this.pallCurtain,
    this.analemma,
    this.snuffer,
    this.abyss,
    this.shadowVane,
  });
}

/// Every room's quarter, derived from the layout so the module, the render
/// and the proof can never disagree about which quarter a room is in.
Map<String, EclipseLeaf> vaultLeafOfRoom(DungeonLayout layout) => {
  for (final e in layout.rooms.entries)
    if (e.value.eclipse != null) e.key: e.value.eclipse!.leaf,
};

// ─────────────────────────────────────────────────────────
// THE LAYOUT
// ─────────────────────────────────────────────────────────

/// Nythralor — the Eclipse Vault.
const DungeonLayout darkLayout = DungeonLayout(
  element: 'Dark',
  entranceRoomId: 'pall_porch',
  entranceSpawn: Offset(120, 240),
  title: 'THE ECLIPSE VAULT',
  descentTitle: 'Nythralor Vault',
  stars: [
    DungeonStarSpec(
      name: 'Analemma Star',
      earnAnnouncement:
          'The Analemma Star is yours — four stones seated, and never two of '
          'them in the same vault',
    ),
    DungeonStarSpec(
      name: 'Anchor Star',
      earnAnnouncement:
          'The Anchor Star is yours — three holes walked, and the dark holds '
          'them open',
    ),
    DungeonStarSpec(name: 'Totality Star'),
  ],
  // The pall is knotted across the arch until a Dark hand draws it.
  entranceRevealDoor: DungeonDoorRef('pall_porch', 'shade_gallery'),
  finaleDoor: DungeonDoorRef('eclipse_nave', 'noctryos_totality'),
  riteAnnouncement:
      'Analemma and Anchor are won — the reredos goes black in the nave, and '
      'the pall lamps gutter',
  finaleSealedHint:
      'The rood door is shut — it answers only the Analemma and Anchor stars',
  guardianSealedHint:
      'Nothing behind the rood is awake while a single lamp still burns in '
      'the nave',
  mercyShrineRoomId: 'shade_gallery',
  // Ideal: Darkmask · Poisonpip · Spiritmane — hinted by VERB, never body
  // part (§4): the sight that pierces the hidden, what my smallest doors
  // admit, and the road a walker leaves behind it.
  riddle: [
    'Bring me a sight that pierces the hidden, for nothing in me is where the '
        'light says it is;',
    'bring me what my smallest doors admit, since every ring in me is rusted '
        'shut and my ways are holes;',
    'and bring me a walker that leaves a road behind it, because I keep no '
        'lamp to find you by.',
  ],
  // §4 budget: TWO hard gates, on two different objects and two different
  // entry slots, and never two on one star. Star 0 (the analemma) is
  // deliberately UNGATED and uses all three elements at full power, so any
  // trio of Dark/Poison/Spirit progresses on a first descent — §6 put a
  // Darkmask gate on this planet's FIRST star (flipping room states), and
  // §4's first-descent guarantee wins, so that gate moved onto the rite's
  // reredos. The gnomons themselves — the planet's whole verb — are
  // element-only Dark and always available: a maze you cannot re-shape is a
  // softlock, so the inversion verb is never gated and never one-way.
  familyGates: [
    DungeonFamilyGate(
      objectId: 'anchor_ring',
      element: 'Poison',
      family: 'Pip',
      hintLine: 'Only a Poison small enough to work inside the ring eats this '
          'rust',
    ),
    DungeonFamilyGate(
      objectId: 'A',
      element: 'Dark',
      family: 'Mask',
      hintLine: 'Only a Dark that sees what is not shown reads this reredos',
    ),
  ],
  rooms: {
    // ── THE PALL PORCH (entrance · quarter I) ─────────────
    // The vault's threshold, and its whole grammar in one room: two ways out,
    // and they are the two quarters the porch gnomon stands between. The
    // glimmer runs west to the court while the PALL stands in light; the pall
    // arch runs east to the gallery while the GALLERY lies in shadow. Turning
    // the finger here always buys one and sells the other — unless the walk
    // gnomon downstairs has already paid for the gallery's shadow, which is
    // the lesson the planet spends the rest of the run on.
    'pall_porch': DungeonRoom(
      id: 'pall_porch',
      bounds: Rect.fromLTWH(0, 0, 720, 460),
      walls: [
        Rect.fromLTWH(250, 90, 180, 26), // the fallen tympanum
      ],
      doors: [
        // The pall arch, east into the gallery (shadow-way, quarter II).
        DungeonDoor(
          rect: Rect.fromLTWH(696, 175, 24, 110),
          targetRoomId: 'shade_gallery',
          targetSpawn: Offset(60, 260),
        ),
        // The glimmer, up into the court (light-walk, quarter I).
        DungeonDoor(
          rect: Rect.fromLTWH(300, 0, 110, 24),
          targetRoomId: 'analemma_court',
          targetSpawn: Offset(355, 330),
        ),
      ],
      eclipse: EclipseHall(
        leaf: EclipseLeaf.pall,
        pallCurtain: Offset(620, 220),
      ),
    ),

    // ── THE ANALEMMA COURT (Star 0 · quarter I) ───────────
    // The dial, and the four stones. The court carries NO gnomon on purpose:
    // every seating is a separate arrival in a separate arrangement, and the
    // walk out to a finger and back is the star. It is also the clearest case
    // of the header's reason 2 — nothing can shut this room on you, because
    // nothing in it can change the vault.
    'analemma_court': DungeonRoom(
      id: 'analemma_court',
      bounds: Rect.fromLTWH(0, 0, 700, 480),
      doors: [
        // Back down the glimmer (light-walk, quarter I).
        DungeonDoor(
          rect: Rect.fromLTWH(300, 456, 110, 24),
          targetRoomId: 'pall_porch',
          targetSpawn: Offset(355, 140),
        ),
        // The lych-way, east to the penumbral walk (shadow-way, quarter II).
        DungeonDoor(
          rect: Rect.fromLTWH(676, 185, 24, 110),
          targetRoomId: 'penumbral_walk',
          targetSpawn: Offset(60, 400),
        ),
      ],
      eclipse: EclipseHall(
        leaf: EclipseLeaf.pall,
        starIndex: 0,
        analemma: Offset(350, 205),
      ),
    ),

    // ── THE SHADE GALLERY (mercy shrine · quarter II) ─────
    'shade_gallery': DungeonRoom(
      id: 'shade_gallery',
      bounds: Rect.fromLTWH(0, 0, 860, 520),
      walls: [
        Rect.fromLTWH(300, 240, 240, 30), // a toppled bier
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 205, 24, 110),
          targetRoomId: 'pall_porch',
          targetSpawn: Offset(640, 230),
        ),
        // The colonnade (light-walk, quarter II).
        DungeonDoor(
          rect: Rect.fromLTWH(836, 205, 24, 110),
          targetRoomId: 'penumbral_walk',
          targetSpawn: Offset(60, 170),
        ),
        // The dry well shaft, down into the ossuary (shadow-way, quarter III).
        DungeonDoor(
          rect: Rect.fromLTWH(380, 496, 110, 24),
          targetRoomId: 'ossuary_ring',
          targetSpawn: Offset(395, 120),
        ),
      ],
      eclipse: EclipseHall(leaf: EclipseLeaf.gallery),
    ),

    // ── THE PENUMBRAL WALK (quarter II) ───────────────────
    // The walk gnomon stands here, one quarter ABOVE the line it commands —
    // the placement the whole lower half of the vault depends on. Nothing
    // down in the ossuary or the deep can reach back up to set the ossuary's
    // shadow, so if this finger stood down there the descent would be a
    // one-way trip (the test pins exactly that).
    'penumbral_walk': DungeonRoom(
      id: 'penumbral_walk',
      bounds: Rect.fromLTWH(0, 0, 820, 540),
      doors: [
        // Back along the colonnade (light-walk, quarter II).
        DungeonDoor(
          rect: Rect.fromLTWH(0, 120, 24, 110),
          targetRoomId: 'shade_gallery',
          targetSpawn: Offset(820, 260),
        ),
        // The lych-way back to the court (shadow-way, quarter II).
        DungeonDoor(
          rect: Rect.fromLTWH(0, 340, 24, 110),
          targetRoomId: 'analemma_court',
          targetSpawn: Offset(640, 245),
        ),
        // The stair head, down (shadow-way, quarter III).
        DungeonDoor(
          rect: Rect.fromLTWH(355, 516, 110, 24),
          targetRoomId: 'gnomon_stair',
          targetSpawn: Offset(380, 120),
        ),
      ],
      eclipse: EclipseHall(leaf: EclipseLeaf.gallery),
    ),

    // ── THE GNOMON STAIR (quarter III) ────────────────────
    // The stair gnomon: the deep quarter's only control, standing one quarter
    // above it. Turning it down opens the gulf and, one room further in, the
    // reliquary's slot — and takes the ossuary's shadow away with it, which
    // is the run's sharpest single trade: the stair head you came down by
    // shuts the moment the deep opens, unless the walk gnomon is already
    // holding the ossuary dark for you.
    'gnomon_stair': DungeonRoom(
      id: 'gnomon_stair',
      bounds: Rect.fromLTWH(0, 0, 760, 500),
      doors: [
        // Back up the stair head (shadow-way, quarter III).
        DungeonDoor(
          rect: Rect.fromLTWH(325, 0, 110, 24),
          targetRoomId: 'penumbral_walk',
          targetSpawn: Offset(410, 440),
        ),
        // The ambulatory, round to the ring (light-walk, quarter III).
        DungeonDoor(
          rect: Rect.fromLTWH(736, 195, 24, 110),
          targetRoomId: 'ossuary_ring',
          targetSpawn: Offset(60, 270),
        ),
        // The gulf, down into the deep (shadow-way, quarter IV).
        DungeonDoor(
          rect: Rect.fromLTWH(200, 476, 110, 24),
          targetRoomId: 'abyssal_font',
          targetSpawn: Offset(255, 110),
        ),
      ],
      eclipse: EclipseHall(leaf: EclipseLeaf.ossuary),
    ),

    // ── THE OSSUARY RING (Star 1 · quarter III) ───────────
    // The ring of shadow-anchors. No gnomon here either — the ring is a place
    // you arrive at in an arrangement you chose somewhere else.
    'ossuary_ring': DungeonRoom(
      id: 'ossuary_ring',
      bounds: Rect.fromLTWH(0, 0, 800, 540),
      walls: [
        Rect.fromLTWH(330, 230, 150, 32), // a stack of long bones
      ],
      doors: [
        // Back up the dry well shaft (shadow-way, quarter III).
        DungeonDoor(
          rect: Rect.fromLTWH(340, 0, 110, 24),
          targetRoomId: 'shade_gallery',
          targetSpawn: Offset(435, 430),
        ),
        // The ambulatory (light-walk, quarter III).
        DungeonDoor(
          rect: Rect.fromLTWH(0, 215, 24, 110),
          targetRoomId: 'gnomon_stair',
          targetSpawn: Offset(700, 250),
        ),
        // The causeway, down into the nave (shadow-way, quarter IV).
        DungeonDoor(
          rect: Rect.fromLTWH(350, 516, 110, 24),
          targetRoomId: 'eclipse_nave',
          targetSpawn: Offset(405, 120),
        ),
      ],
      eclipse: EclipseHall(leaf: EclipseLeaf.ossuary, starIndex: 1),
    ),

    // ── THE ABYSSAL FONT (quarter IV) ─────────────────────
    // The Lost Maxim's room (§6, "The Abyss"). The font's floor is a hole
    // with no bottom, and it only answers a party that does nothing at all.
    'abyssal_font': DungeonRoom(
      id: 'abyssal_font',
      bounds: Rect.fromLTWH(0, 0, 700, 480),
      doors: [
        // Back up the gulf (shadow-way, quarter IV).
        DungeonDoor(
          rect: Rect.fromLTWH(250, 0, 110, 24),
          targetRoomId: 'gnomon_stair',
          targetSpawn: Offset(255, 400),
        ),
        // The undercroft, across to the nave (light-walk, quarter IV).
        DungeonDoor(
          rect: Rect.fromLTWH(676, 185, 24, 110),
          targetRoomId: 'eclipse_nave',
          targetSpawn: Offset(60, 280),
        ),
        // The slot — the vault (shadow-way, quarter IV). While the deep
        // stands in light this wall has nothing on it.
        DungeonDoor(
          rect: Rect.fromLTWH(0, 185, 24, 110),
          targetRoomId: 'umbral_reliquary',
          targetSpawn: Offset(350, 160),
        ),
      ],
      eclipse: EclipseHall(leaf: EclipseLeaf.deep, abyss: Offset(350, 250)),
    ),

    // ── THE UMBRAL RELIQUARY (the vault · quarter IV) ─────
    // §5.5's trick: the room only EXISTS in the dark state. You can only ever
    // be standing in it while the deep lies in shadow, and nothing in here
    // can change that — so the slot you came through is the slot you leave
    // by, whatever happens outside (Ice's shelf rule). That is what keeps the
    // trick from being a trap; see the no-strand proof.
    'umbral_reliquary': DungeonRoom(
      id: 'umbral_reliquary',
      bounds: Rect.fromLTWH(0, 0, 420, 320),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(396, 105, 24, 110),
          targetRoomId: 'abyssal_font',
          targetSpawn: Offset(60, 240),
        ),
      ],
      vaultCache: Offset(250, 160),
      eclipse: EclipseHall(leaf: EclipseLeaf.deep),
    ),

    // ── THE ECLIPSE NAVE (the rite · quarter IV) ──────────
    // Conduit A is the planet's Dark+MASK gate — the reredos of black glass,
    // which shows nothing to a sight that only sees what is lit. The nave's
    // own half is the SNUFFER: §6's S3, "extinguish every light", element-only
    // Dark with **Poison+Spirit→Dark** authored as the braid for a party whose
    // Dark hand is down. The module latches `conduitEnergy['B']` itself.
    'eclipse_nave': DungeonRoom(
      id: 'eclipse_nave',
      bounds: Rect.fromLTWH(0, 0, 820, 560),
      doors: [
        // Back up the causeway (shadow-way, quarter IV).
        DungeonDoor(
          rect: Rect.fromLTWH(355, 0, 110, 24),
          targetRoomId: 'ossuary_ring',
          targetSpawn: Offset(405, 440),
        ),
        // The undercroft (light-walk, quarter IV).
        DungeonDoor(
          rect: Rect.fromLTWH(0, 225, 24, 110),
          targetRoomId: 'abyssal_font',
          targetSpawn: Offset(640, 240),
        ),
        // The rood door — the one passage the eclipse never touches.
        DungeonDoor(
          rect: Rect.fromLTWH(355, 536, 110, 24),
          targetRoomId: 'noctryos_totality',
          targetSpawn: Offset(450, 140),
        ),
      ],
      conduits: [
        Conduit(
          id: 'A',
          position: Offset(250, 270),
          requireElement: 'Dark',
          requiredFamily: DungeonAbility.insight,
        ),
      ],
      eclipse: EclipseHall(leaf: EclipseLeaf.deep, snuffer: Offset(560, 270)),
    ),

    // ── NOCTRYOS' TOTALITY (Star 2 · quarter IV) ──────────
    // §7 guardian principle — the mystic fights WITH the planet's rule.
    // Noctryos does not darken the arena; it THROWS THE VAULT'S SHADOW. Every
    // strike beat it turns the stair gnomon from where it stands, so the maze
    // outside inverts while you fight, and its lull exists only while the
    // DEEP lies in shadow — the one arrangement its own beat keeps taking
    // away. The arena's floor-vane is your hand on the same finger, and the
    // rood door is phase-free, so nothing here can ever shut you in.
    'noctryos_totality': DungeonRoom(
      id: 'noctryos_totality',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'eclipse_nave',
          targetSpawn: Offset(410, 450),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(450, 300),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Dark',
          mysticId: 'Noctryos',
          canCalm: true,
          canDefeat: true,
        ),
      ),
      eclipse: EclipseHall(
        leaf: EclipseLeaf.deep,
        shadowVane: Offset(450, 500),
      ),
    ),
  },
);
