// lib/games/planet_dungeon/planet_dungeon_layout_blood.dart
//
// HEMAVORN — the Sanguine Orrery. Blood's authored layout, its pure rules, and
// the puzzle DATA its `part of planet_dungeon_game.dart` module reasons about.
//
// TOPOLOGY (docs/dungeons.md §5.5, structural assignment table): **A SYSTOLE
// LOOP — a figure-eight of veins around the heart; surges circle it on the
// beat.** There is no hub and no wings. Seven chambers stand on one figure of
// eight that crosses itself at the sinus, and the heart itself sits INSIDE
// the crossing, reached through the one wall the beat does not move:
//
//     ── the orrery, ONE figure of eight, crossing at the sinus ──
//
//       THE GREATER LOBE (the body's round — it reverses)
//          pericard_gate ──▶ arterial_run ──▶ aortic_arch
//                ▲                                 │
//                └────────── vena_crossing ◀───────┘
//                            ╎  ╎  (the sinus — where the eight crosses)
//       THE LESSER LOBE (the lung's round — it never reverses)
//                            ╎  └──▶ pulmonic_stair ──▶ capillary_weave
//                            ╎                                  │
//                            └──── atrial_gallery ◀─────────────┘
//
//          vena_crossing ══ myocardium ══ sanguorath_systole   (mural: the
//                              (the rite)      (Star 2)         heart wall,
//                                                               phase-free)
//          aortic_arch ~~ auricle_reliquary  (THE VAULT — a valve pocket)
//
//     (──▶  a VEIN. It is a collapsible tube: it is a road only while blood
//           is actually being pushed through it, and only DOWNSTREAM. No
//           creature swims up a heart.
//      ══   a MURAL passage — cut through the heart's own wall, which does
//           not collapse. The only phase-free ways in the orrery, and two of
//           the three legs of the no-strand proof stand on them.
//      ~~   a VALVE. A leaflet is held shut by pressure from EITHER side, so
//           it hangs open only when there is no pressure at all.)
//
// WORLD RULE — *the dungeon is alive, and it beats on a rhythm.*
//
// THE INVARIANT (§5.5, Blood's claimed mechanic): **RHYTHM / TIMING WINDOWS —
// and the state of this planet is the FIRST in the set that the player does
// not author.** Sixteen planets changed when somebody turned, dug, burned or
// froze something. Hemavorn's pulse runs on its own, in one direction, for
// ever, and no verb on the planet can stop it, steer it or slow it. The map
// is therefore a function of the CLOCK, and the strategic question is a
// question about time rather than about space.
//
// ── THE PULSE (all of it, and all provable) ───────────────
// Four phases, always in this order, looping. Nothing branches:
//
//   0 SYSTOLE  (7s) — the squeeze. The GREATER lobe runs FORWARD (gate →
//                     run → arch → crossing → gate). The lesser lobe lies
//                     slack, and a slack vein is a shut vein.
//   1 DICROTIC (4s) — the rebound off the closing valve. The GREATER lobe
//                     runs BACKWARD along the very same veins. This is the
//                     "or against it" of the strategic question, and it is
//                     the only place in the orrery where a road runs both
//                     ways at different times.
//   2 DIASTOLE (7s) — the fill. The LESSER lobe runs FORWARD (crossing →
//                     stair → weave → gallery → crossing). It never
//                     reverses: a vein has valves, and that is the point.
//   3 FLATLINE (5s) — the pause between beats. NOTHING flows, so every vein
//                     in the orrery is shut at once — and every leaflet,
//                     with no pressure holding it, hangs open.
//
// THE STRATEGIC QUESTION (§5.5): *move WITH the pulse or against it — timing
// is the map.* It bites in two authored places. (1) In the greater lobe you
// may ride the long systolic round the whole way about the eight, or stand
// still for one phase and let the four-second dicrotic backwash carry you one
// chamber the SHORT way — speed against distance, paid in beats. (2) The
// lesser lobe never reverses, so entering it COMMITS you: there is no turning
// back out of the lung, only round, and one diastole is not long enough to
// walk the whole round. Choosing which errand in the lesser lobe you spend
// this beat on is the run's sharpest decision.
//
// **PLANNED, NEVER REACTED TO — the authoring rule this planet lives by.**
// Every other planet in the set is a thinking puzzle, and a timing puzzle is
// a DEXTERITY test unless it is built not to be. Three rules keep it honest,
// and the proof measures all three:
//
//   • **A window is a whole PHASE, never a moment.** The shortest window on
//     the planet is the five-second flatline. Nothing anywhere asks for an
//     input at an instant.
//   • **Every chamber is safe to stand in, for ever.** No room damages, no
//     room times out, and nothing is lost by missing a window. The cost of a
//     mistimed arrival is one wait, never a run.
//   • **The requirement is WHERE, not WHEN.** Every phase-locked object asks
//     you to be standing in a particular chamber; the beat then brings the
//     phase to you. Working out which chamber, and how to be in it, is the
//     puzzle. Being there is not a reflex.
//
//   The one deliberate exception is the Lost Maxim (§6 #17: strike the
//   heart-drum in sync for twelve straight beats), which is an optional
//   20-gold secret and is SUPPOSED to be hard. No star touches it.
//
// THE VAULT TRICK (§5.5): *reachable only in the flatline window between
// beats.* The auricle reliquary hangs off the aortic arch behind a valve
// leaflet, and a leaflet is held shut by pressure from either side — so the
// one moment it hangs open is the moment the heart is doing nothing at all.
// No prior planet's trick is this: Dark's room only exists in one state,
// Crystal's cell only joins the grid in one configuration, Plant's is
// visible-but-too-small, Ice's a mirror plus a slide you cannot repeat,
// Dust's a house you bury HARDER, Poison's the ward you abandoned, Steam's
// spending the whole budget, Lightning's a dead trunk walked dark. Hemavorn's
// is the first that is hidden in TIME rather than in space or in state.
//
// ── WHY THERE IS NO RESET VALVE ───────────────────────────
// Ice, Mud, Dust and Plant all shipped a costly full-reset valve; Spirit,
// Dark and Crystal did not. Hemavorn does not either, and its argument is the
// strongest of the three because it is a property of the CLOCK rather than of
// the geometry (the measurement in `solveSanguineOrrery` agrees: **0
// strandable of 3,200 states across all ten rolls of the corruption, with no
// valve**):
//
//   1. **THE BEAT IS PERIODIC AND UNSTOPPABLE.** Phase advance is the world's
//      move, not the player's, and it never branches: from any phase, all
//      four phases recur, for ever, in bounded time. So "wait" is always a
//      legal plan and it always delivers every phase. This is the whole
//      answer to the new hazard — stranding in TIME — and it is the reason
//      the search ranges over (chamber × phase × world state) with the beat
//      advancing whether or not the party acts.
//   2. **WAITING IS SAFE.** Rule 1 is worth nothing if the party cannot
//      afford to wait, so no chamber in the orrery hurts anybody, ever. The
//      hazard on this planet is exclusively the wisps a verb wakes.
//   3. **BOTH LOBES OF THE EIGHT ARE CLOSED CYCLES.** A one-way road is only
//      safe if it comes back round. The greater lobe closes (and reverses on
//      the dicrotic besides); the lesser lobe closes and is one-way, so
//      going round IS coming back. Open either cycle and the planet becomes
//      a trap — the counterfactual measures it, and it is the single most
//      load-bearing line of the layout.
//   4. **THE HEART'S WALL IS PHASE-FREE.** The two mural passages (crossing ↔
//      myocardium ↔ arena) do not collapse, so the rite room and the arena —
//      the two places the world acts on its own while you are in them — can
//      never be shut on you. This is Dark's rood door, restated for a clock.
//   5. **THE VAULT'S LEAFLET IS TWO-WAY.** The reliquary is a POCKET with one
//      way in and out, and that way is the same leaflet in both directions.
//      You enter on a flatline and you leave on a flatline; flatlines recur
//      (rule 1), so the trick is not a trap. Cut the leaflet as a one-way
//      vein instead and the vault swallows the party — measured.
//   6. **NOTHING THE PLAYER DOES SUBTRACTS.** The only world-edits on the
//      planet are the collateral GRAFTS, and a graft only ever adds a
//      passage. An additive edit cannot shrink reachability, so it cannot
//      strand (Dark established this argument; Hemavorn reuses it).
//   7. **THE ARREST IS BOUNDED.** The arena's vagal node lets the party stop
//      the heart — the one hand anybody has on the clock — and it stops it
//      for a few seconds and then lets go. An UNBOUNDED arrest would kill
//      rule 1 outright and take the whole proof with it; the counterfactual
//      measures exactly that.
//
// Mechanic-ledger note (§5.5): Blood claims **rhythm / timing windows**, the
// last seat in the pool, and under it **the autonomous world-clock** — a
// global state that advances on its own, that no verb can touch, and whose
// PERIODICITY is what makes the planet safe. This is deliberately not Water's
// tide (a state machine the player settles), not Crystal's permutation (the
// player slides it), not Dark's inversion (the player flips it), not Air's
// ordering (permanent edits the player authors), not Steam's budget (a
// quantity the player spends) and not Lava's line (a route the player
// programs). Nothing on Hemavorn is counted, ordered, spent or reshaped. The
// only thing that changes is what time it is.
//
// VISUAL GRAMMAR (§5.5): nothing here is drawn like Water's tide line, Dark's
// hard pewter/void inversion or Lightning's jagged bolts. The orrery is drawn
// as a body: a slow dark-crimson SWELL washes the floor on the systole and
// drains on the diastole, veins are drawn as filled TUBES whose lumen visibly
// narrows to a hairline when they collapse, and the phase turn is a single
// wet PULSE ring thrown out from the chamber's centre — never a wipe (Dark's)
// and never a fade. The flatline is drawn by the absence of all of it: the
// swell goes flat and the room goes bone-still. No blur filters anywhere (the
// game's known jank source).

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

// ─────────────────────────────────────────────────────────
// THE PULSE
// ─────────────────────────────────────────────────────────

/// The four phases of one beat. They always run in this order and the order
/// never branches — which is the entire no-strand proof's first premise.
enum PulsePhase {
  /// The squeeze. The greater lobe runs FORWARD.
  systole,

  /// The rebound off the closing valve. The greater lobe runs BACKWARD along
  /// the same veins — the "or against it" of the strategic question.
  dicrotic,

  /// The fill. The lesser lobe runs FORWARD, and it never runs any other way.
  diastole,

  /// The pause between beats. No vein carries; every valve hangs open.
  flatline,
}

/// The two rounds of the figure-eight.
enum HeartLobe {
  /// The body's round: gate → run → arch → crossing → gate. It REVERSES on
  /// the dicrotic, so it is the lobe where the with/against choice lives.
  greater,

  /// The lung's round: crossing → stair → weave → gallery → crossing. One
  /// way, always — a vein has valves. Entering it is a commitment.
  lesser,
}

/// How long each phase lasts, indexed by [PulsePhase.index].
///
/// DEVICE-TUNABLE. Hemavorn has never been on a phone, so every number the
/// feel depends on is named in one place. The authoring constraint these have
/// to satisfy is in the header: the SHORTEST of them is the shortest window
/// on the planet, and it must be long enough to walk through a door you are
/// already standing at without hurrying.
const List<double> kPulsePhaseSeconds = [7.0, 4.0, 7.0, 5.0];

/// One full beat, in seconds. Derived so it can never drift from the phases.
double get kPulseCycleSeconds =>
    kPulsePhaseSeconds.fold(0.0, (a, b) => a + b);

/// Where in the cycle [phase] begins.
double pulsePhaseStart(PulsePhase phase) {
  var t = 0.0;
  for (var i = 0; i < phase.index; i++) {
    t += kPulsePhaseSeconds[i];
  }
  return t;
}

/// Which phase the beat is in [clock] seconds into a cycle.
PulsePhase pulsePhaseAt(double clock) {
  var t = clock % kPulseCycleSeconds;
  if (t < 0) t += kPulseCycleSeconds;
  for (final p in PulsePhase.values) {
    t -= kPulsePhaseSeconds[p.index];
    if (t < 0) return p;
  }
  return PulsePhase.flatline;
}

/// The phase after [p]. Total and cyclic: this single fact is premise one of
/// the no-strand proof, so it is written once, here.
PulsePhase nextPulsePhase(PulsePhase p) =>
    PulsePhase.values[(p.index + 1) % PulsePhase.values.length];

/// The orrery's own name for a phase — hints, the readout and the render all
/// read it from here so they can never disagree.
String phaseWord(PulsePhase p) => switch (p) {
  PulsePhase.systole => 'the systole',
  PulsePhase.dicrotic => 'the backwash',
  PulsePhase.diastole => 'the diastole',
  PulsePhase.flatline => 'the flatline',
};

/// Short all-caps form for the progress readout (§5.6 — state leaves the
/// capsule).
String phaseTag(PulsePhase p) => switch (p) {
  PulsePhase.systole => 'SYSTOLE',
  PulsePhase.dicrotic => 'BACKWASH',
  PulsePhase.diastole => 'DIASTOLE',
  PulsePhase.flatline => 'FLATLINE',
};

String lobeWord(HeartLobe l) =>
    l == HeartLobe.greater ? 'the greater round' : 'the lesser round';

/// Which way a vein of [lobe] carries during [phase]: `1` forward (in the
/// authored [HeartPassage.from] → [HeartPassage.to] sense), `-1` backward,
/// `0` not at all — the tube is slack, and a slack tube is shut.
///
/// THE WHOLE MAP IS THIS FUNCTION. Everything the player meets, everything
/// the render draws and every edge the proof walks comes from these six
/// lines, so the three can never drift apart.
int veinFlow(HeartLobe lobe, PulsePhase phase) => switch (lobe) {
  HeartLobe.greater => switch (phase) {
    PulsePhase.systole => 1,
    PulsePhase.dicrotic => -1,
    _ => 0,
  },
  HeartLobe.lesser => phase == PulsePhase.diastole ? 1 : 0,
};

/// A COLLATERAL fills with whatever its lobe is not using, so it carries
/// exactly when that lobe is slack — and with no pressure in it, it carries
/// BOTH ways. That is why Star 1's reward is the phases the eight denies you:
/// a greater collateral is a road on the diastole and the flatline, a lesser
/// collateral on the systole, the backwash and the flatline.
bool collateralCarries(HeartLobe lobe, PulsePhase phase) =>
    veinFlow(lobe, phase) == 0;

// ─────────────────────────────────────────────────────────
// PASSAGES — the map, in all four phases at once
// ─────────────────────────────────────────────────────────

/// What kind of way between two chambers this is.
enum PassageKind {
  /// A vein: a collapsible tube. A road only while blood is being pushed
  /// through it, and only downstream. Every leg of the figure-eight is one.
  vein,

  /// A collateral: a dead vessel until a cock is opened on it (Star 1). Once
  /// grafted it carries whenever its lobe is slack, in both directions. The
  /// only world-edit on the planet, and purely ADDITIVE.
  collateral,

  /// A valve: a leaflet pocket. Pressure from either side holds it shut, so
  /// it hangs open only on the flatline. Two-way — the same leaflet in and
  /// out, which is what keeps the vault trick from being a trap.
  valve,

  /// A mural way, cut through the heart's own wall. It does not collapse and
  /// the beat does not touch it: the orrery's phase-free passages, and the
  /// safety belt on the two rooms the world acts in.
  mural,
}

/// One way between two chambers, authored once and read from both ends.
///
/// The layout test enforces that EVERY door has a reciprocal door, statically
/// (§5.5 keeps that invariant for the whole game). A map whose connectivity
/// changes at runtime lives inside that rule the only honest way, the one
/// Crystal established and Plant, Spirit, Dark and Light all reused: **the
/// doors are constant and reciprocal, and what varies is whether the passage
/// carries at the moment you try it.** On Hemavorn the moment is a phase.
class HeartPassage {
  final String id;

  /// [from] → [to] is the FORWARD sense: the direction the lobe's own systole
  /// or diastole pushes. For valves and murals the order is arbitrary and the
  /// passage is two-way.
  final String from;
  final String to;
  final PassageKind kind;

  /// The lobe whose beat decides this passage. Required for [PassageKind.vein]
  /// and [PassageKind.collateral]; null for valves and murals, which the beat
  /// does not reach.
  final HeartLobe? lobe;

  /// One clause naming the passage, for the blocked line and the render.
  final String look;

  const HeartPassage({
    required this.id,
    required this.from,
    required this.to,
    required this.kind,
    required this.look,
    this.lobe,
  });

  bool joins(String a, String b) =>
      (from == a && to == b) || (from == b && to == a);

  /// Whether this passage carries FROM [here] during [phase], given whether
  /// it has been grafted (collaterals only). Pure, total, and the single
  /// source of truth for the engine, the render and the proof alike.
  bool carriesFrom(String here, PulsePhase phase, {bool grafted = false}) {
    switch (kind) {
      case PassageKind.mural:
        return true;
      case PassageKind.valve:
        return phase == PulsePhase.flatline;
      case PassageKind.collateral:
        return grafted && collateralCarries(lobe!, phase);
      case PassageKind.vein:
        final flow = veinFlow(lobe!, phase);
        if (flow == 0) return false;
        return flow > 0 ? here == from : here == to;
    }
  }
}

/// The whole orrery as passages. Sixteen, and every chamber pair appears
/// exactly once — so a door and a passage are one-to-one and the no-strand
/// proof cannot drift from the doors the player actually meets.
const List<HeartPassage> kHeartPassages = [
  // ── THE GREATER LOBE — the body's round ───────────────
  // A closed four-cycle. It runs forward on the systole and backward on the
  // backwash, so it is the only part of Hemavorn that is a road in two
  // directions, and it is where the planet teaches the choice.
  HeartPassage(
    id: 'vn_pericard',
    from: 'pericard_gate',
    to: 'arterial_run',
    kind: PassageKind.vein,
    lobe: HeartLobe.greater,
    look: 'the pericardial vein',
  ),
  HeartPassage(
    id: 'vn_run',
    from: 'arterial_run',
    to: 'aortic_arch',
    kind: PassageKind.vein,
    lobe: HeartLobe.greater,
    look: 'the long run',
  ),
  HeartPassage(
    id: 'vn_arch',
    from: 'aortic_arch',
    to: 'vena_crossing',
    kind: PassageKind.vein,
    lobe: HeartLobe.greater,
    look: 'the arch',
  ),
  // THE CLOSING VEIN of the greater lobe. Cut this and the round stops being
  // a round; the counterfactual measures what that costs.
  HeartPassage(
    id: 'vn_return',
    from: 'vena_crossing',
    to: 'pericard_gate',
    kind: PassageKind.vein,
    lobe: HeartLobe.greater,
    look: 'the great return',
  ),

  // ── THE LESSER LOBE — the lung's round ────────────────
  // A closed four-cycle that NEVER reverses. One-way is only safe because it
  // comes back round: going round IS coming back. This is the load-bearing
  // sentence of the whole layout.
  HeartPassage(
    id: 'vn_pulmonic',
    from: 'vena_crossing',
    to: 'pulmonic_stair',
    kind: PassageKind.vein,
    lobe: HeartLobe.lesser,
    look: 'the pulmonic mouth',
  ),
  HeartPassage(
    id: 'vn_weave',
    from: 'pulmonic_stair',
    to: 'capillary_weave',
    kind: PassageKind.vein,
    lobe: HeartLobe.lesser,
    look: 'the fine weave',
  ),
  HeartPassage(
    id: 'vn_atrial',
    from: 'capillary_weave',
    to: 'atrial_gallery',
    kind: PassageKind.vein,
    lobe: HeartLobe.lesser,
    look: 'the atrial run',
  ),
  // THE CLOSING VEIN of the lesser lobe, and the single most important
  // passage on the planet: without it the lung is a one-way chain that never
  // reverses, and anybody who walks in never walks out.
  HeartPassage(
    id: 'vn_sinus',
    from: 'atrial_gallery',
    to: 'vena_crossing',
    kind: PassageKind.vein,
    lobe: HeartLobe.lesser,
    look: 'the sinus mouth',
  ),

  // ── THE COLLATERALS — Star 1's grafts ─────────────────
  // Dead vessels until a cock is opened. Each is a CHORD of the eight — a way
  // the beat never offers — and each carries when its own lobe is slack, so
  // grafting is how a party buys the phases the orrery denies it. Five are
  // authored; only three of them are sound on any given descent, and which
  // three is rolled (see [kSoundCollateralCount]).
  HeartPassage(
    id: 'co_diagonal',
    from: 'aortic_arch',
    to: 'pericard_gate',
    kind: PassageKind.collateral,
    lobe: HeartLobe.greater,
    look: 'the diagonal collateral, thin as a thread',
  ),
  HeartPassage(
    id: 'co_shortcut',
    from: 'arterial_run',
    to: 'vena_crossing',
    kind: PassageKind.collateral,
    lobe: HeartLobe.greater,
    look: 'the short collateral under the run',
  ),
  HeartPassage(
    id: 'co_bypass',
    from: 'pulmonic_stair',
    to: 'atrial_gallery',
    kind: PassageKind.collateral,
    lobe: HeartLobe.lesser,
    look: 'the bypass across the lung',
  ),
  // The two cross-lobe grafts. Each is named for the lobe whose slack FILLS
  // it, not for where it goes — a collateral drains the round beside it.
  HeartPassage(
    id: 'co_shunt',
    from: 'aortic_arch',
    to: 'capillary_weave',
    kind: PassageKind.collateral,
    lobe: HeartLobe.greater,
    look: 'the shunt from the arch into the weave',
  ),
  HeartPassage(
    id: 'co_anastomosis',
    from: 'pericard_gate',
    to: 'atrial_gallery',
    kind: PassageKind.collateral,
    lobe: HeartLobe.lesser,
    look: 'the anastomosis behind the gate',
  ),

  // ── THE VAULT'S LEAFLET (§5.5's trick) ────────────────
  // A leaflet is held shut by pressure from EITHER side, so the one moment it
  // hangs open is the moment nothing is pushing. Two-way on purpose: the same
  // leaflet lets you out as let you in, which is what keeps the trick from
  // being a trap (Ice's shelf rule, restated for a clock).
  HeartPassage(
    id: 'vv_leaflet',
    from: 'aortic_arch',
    to: 'auricle_reliquary',
    kind: PassageKind.valve,
    look: 'the leaflet in the arch\'s inner wall',
  ),

  // ── THE MURAL WAYS — the heart's own wall ─────────────
  // The two passages the beat does not reach. Both lead to a room where the
  // WORLD acts while the party stands in it (the rite, and Sanguorath), so
  // both are safety belts before they are scenery.
  HeartPassage(
    id: 'vn_endocard',
    from: 'vena_crossing',
    to: 'myocardium',
    kind: PassageKind.mural,
    look: 'the endocardial door',
  ),
  HeartPassage(
    id: 'vn_chordae',
    from: 'myocardium',
    to: 'sanguorath_systole',
    kind: PassageKind.mural,
    look: 'the chordae gate',
  ),
];

/// The passage joining these two chambers, or null. One pair, one passage —
/// pinned by the tests.
HeartPassage? heartPassageBetween(String a, String b) {
  for (final p in kHeartPassages) {
    if (p.joins(a, b)) return p;
  }
  return null;
}

HeartPassage? heartPassageById(String id) {
  for (final p in kHeartPassages) {
    if (p.id == id) return p;
  }
  return null;
}

// ─────────────────────────────────────────────────────────
// STAR 0 — THE PRIMING (the four ostia)
// ─────────────────────────────────────────────────────────

/// A mouth in a chamber wall that drinks only when the blood is doing one
/// particular thing.
///
/// Star 0 is the planet's FIRST-DESCENT star (§4): it is earnable by ANY trio
/// of Blood/Dark/Light, uses all three elements at full power, and needs no
/// graft and no gate. It teaches the whole planet in one errand — four
/// mouths, four phases, four different chambers, and no two of them can be
/// primed on the same breath of the heart. Dark's dial could not be finished
/// in one shape of the vault; Hemavorn's cannot be finished in one BEAT.
///
/// §6 put a Bloodkin gate on this planet's FIRST star ("Bloodkin stabilizes
/// heartbeat doors"). §4's first-descent guarantee wins, so the priming is
/// element-only and the Bloodkin requirement moved onto the rite's cannula —
/// exactly as Plant moved its Plantmane gate onto the rood screen and Dark
/// its Darkmask gate onto the reredos. What survives of §6's line is legal
/// v2: a Blood KIN can STEADY a vein it stands beside, holding it open past
/// the turn. That is a family-exclusive BONUS no puzzle requires, which §4
/// permits without reservation.
///
/// AUTHORING RULE, and it is the reason this star is not a reflex test: an
/// ostium's requirement is WHERE, not WHEN. Walk into its chamber — which you
/// may do in any phase you can reach it in — and stand there. The beat brings
/// the phase round in at most one cycle, every chamber is safe to wait in for
/// ever, and missing a window costs one wait and nothing else.
class Ostium {
  final String id;

  /// The chamber the mouth is cut into.
  final String roomId;

  /// The phase it drinks on, and the only one.
  final PulsePhase phase;

  /// The element that primes it. Element-only (§4) — any family, full power.
  /// All three of the planet's entry elements appear, so the ideal trio is
  /// never required and any correct-element party finishes the priming.
  final String element;

  /// Where in the chamber the mouth is (the verb's reach).
  final Offset position;

  /// One clause of scenery, for the reading and the render.
  final String look;

  const Ostium({
    required this.id,
    required this.roomId,
    required this.phase,
    required this.element,
    required this.position,
    required this.look,
  });
}

/// The four mouths. Spread deliberately: one in the chamber you start in, one
/// a systole away, one deep in the lung, and one in the crossing on the
/// flatline — so the star is four separate arrivals across at least two
/// beats, and the last of them is the lesson that the heart stops.
const List<Ostium> kHeartOstia = [
  // THE GATE MOUTH — the first lesson, in the room you arrive in. It drinks
  // on the systole, which is when the road out of the gate opens anyway, so
  // the planet teaches "the beat is the door" before it asks anything.
  Ostium(
    id: 'os_gate',
    roomId: 'pericard_gate',
    phase: PulsePhase.systole,
    element: 'Blood',
    position: Offset(300, 250),
    look: 'the gate mouth, ringed with old stitching',
  ),
  // THE ARCH MOUTH — one chamber and one phase further on. You reach the arch
  // riding the systole and the backwash arrives on its own heels, so the
  // second lesson is that the greater round runs both ways.
  Ostium(
    id: 'os_arch',
    roomId: 'aortic_arch',
    phase: PulsePhase.dicrotic,
    element: 'Dark',
    position: Offset(390, 250),
    look: 'the arch mouth, black inside',
  ),
  // THE WEAVE MOUTH — in the lung, two veins deep, on the diastole. Getting
  // here is the commitment the strategic question is about.
  Ostium(
    id: 'os_weave',
    roomId: 'capillary_weave',
    phase: PulsePhase.diastole,
    element: 'Light',
    position: Offset(250, 160),
    look: 'the weave mouth, fine as lace',
  ),
  // THE SINUS MOUTH — in the crossing, on the flatline. The one that can only
  // be answered while the heart is doing nothing, and the reason the whole
  // priming cannot be done on one beat.
  Ostium(
    id: 'os_sinus',
    roomId: 'vena_crossing',
    phase: PulsePhase.flatline,
    element: 'Blood',
    position: Offset(450, 285),
    look: 'the sinus mouth, at the very crossing of the eight',
  ),
];

Ostium? ostiumById(String id) {
  for (final o in kHeartOstia) {
    if (o.id == id) return o;
  }
  return null;
}

List<Ostium> ostiaIn(String roomId) =>
    [for (final o in kHeartOstia) if (o.roomId == roomId) o];

// ─────────────────────────────────────────────────────────
// STAR 1 — THE GRAFTS (the collateral cocks)
// ─────────────────────────────────────────────────────────

/// The cock that opens one collateral (§6's S2: "route life-flow through
/// correct veins — Darkmask reveals, Lightmask flags corrupted").
///
/// Three things live at a cock, and only one of them is a gate:
///
///  • **Opening it is the planet's one star-level family gate (§4, max one
///    per star): a DARK MASK.** The lumen of a dead vessel is unlit and a
///    graft has to be made by sight; nothing else on Hemavorn is gated.
///  • **A LIGHT hand flags it** — element-only, any family — telling you
///    whether the vessel behind it is sound or thrombosed. This is pure
///    information: you may always open blind. §6 hands the flagging to a
///    Lightmask; v2 makes it element-only, because a family-exclusive
///    *penalty* is never legal and this one gates nothing.
///  • **Opening a THROMBOSED cock is the star's one consequence (§7):** the
///    graft does not take and the chamber fills with clot-wisps. Nothing is
///    subtracted, nothing is closed, and the cock can be left alone
///    afterwards — the price of guessing is a fight, never a road.
class CollateralCock {
  /// The [HeartPassage] this cock opens.
  final String passageId;

  /// The chamber the cock stands in, and where.
  final String roomId;
  final Offset position;

  /// One clause of scenery.
  final String look;

  const CollateralCock({
    required this.passageId,
    required this.roomId,
    required this.position,
    required this.look,
  });
}

/// Five cocks, in four different chambers. The two in the aortic arch stand
/// at opposite ends of it so neither can be reached by accident while working
/// the other.
const List<CollateralCock> kHeartCocks = [
  CollateralCock(
    passageId: 'co_diagonal',
    roomId: 'aortic_arch',
    position: Offset(180, 350),
    look: 'a brass cock sunk in the arch\'s west haunch',
  ),
  CollateralCock(
    passageId: 'co_shunt',
    roomId: 'aortic_arch',
    position: Offset(600, 350),
    look: 'a brass cock sunk in the arch\'s east haunch',
  ),
  CollateralCock(
    passageId: 'co_shortcut',
    roomId: 'arterial_run',
    position: Offset(410, 300),
    look: 'a cock under the run\'s middle span',
  ),
  CollateralCock(
    passageId: 'co_bypass',
    roomId: 'pulmonic_stair',
    position: Offset(370, 250),
    look: 'a cock on the stair\'s inner rail',
  ),
  CollateralCock(
    passageId: 'co_anastomosis',
    roomId: 'atrial_gallery',
    position: Offset(400, 250),
    look: 'a cock behind the gallery\'s third arch',
  ),
];

/// How many of the five collaterals are SOUND on any one descent. The other
/// two are thrombosed and never graft.
///
/// Rolled per descent rather than authored, so the Light flagging is worth
/// something on the second run as well as the first, and so the star is a
/// reading rather than a memory. Fire and Earth already roll their evidence
/// per run; this is the same idea applied to a map. The proof enumerates
/// **every one of the ten possible rolls**, so nothing about safety depends
/// on which one came up.
const int kSoundCollateralCount = 3;

CollateralCock? cockFor(String passageId) {
  for (final c in kHeartCocks) {
    if (c.passageId == passageId) return c;
  }
  return null;
}

List<CollateralCock> cocksIn(String roomId) =>
    [for (final c in kHeartCocks) if (c.roomId == roomId) c];

/// Every roll the corruption can come up as, as sorted sets of sound passage
/// ids. Ten of them. Authored as a derivation rather than a table so it
/// cannot drift from [kHeartCocks] or [kSoundCollateralCount], and used by
/// both the runtime roll and the proof.
List<List<String>> heartCollateralRolls() {
  final ids = [for (final c in kHeartCocks) c.passageId]..sort();
  final out = <List<String>>[];
  void choose(int start, List<String> acc) {
    if (acc.length == kSoundCollateralCount) {
      out.add(List<String>.unmodifiable(acc));
      return;
    }
    for (var i = start; i < ids.length; i++) {
      choose(i + 1, [...acc, ids[i]]);
    }
  }

  choose(0, const []);
  return out;
}

// ─────────────────────────────────────────────────────────
// THE LIVE STATE — pure rules, no Flutter, no engine
// ─────────────────────────────────────────────────────────

/// Everything Hemavorn tracks for one run.
///
/// The one thing that matters for reachability is [clock] — the beat — and it
/// is the only piece of state on the planet the player cannot touch. That
/// asymmetry is the planet.
class SanguineHeart {
  SanguineHeart() {
    reset();
  }

  /// Seconds into the current beat. THIS IS THE MAP: everything about which
  /// way is open is derived from it, and nothing in the game can set it
  /// except the passage of time and the arena's vagal node.
  double clock = 0;

  /// Derived from [clock] and cached only so the render and the hints can
  /// detect the TURN without recomputing it. Never written independently.
  PulsePhase phase = PulsePhase.systole;

  /// Beats completed since the descent began. The readout's second line, and
  /// the closest thing this planet has to a price tag.
  int beats = 0;

  /// Ostia primed (Star 0).
  final Set<String> ostiaPrimed = {};

  /// Which collaterals are SOUND this descent. Rolled in [rollCorruption];
  /// the other two are thrombosed.
  final Set<String> soundCollaterals = {};

  /// Cocks the party has turned — sound or not. A thrombosed cock stays
  /// turned so the planet never asks the same question twice.
  final Set<String> cocksTurned = {};

  /// Collaterals that actually took (Star 1's success). Always a subset of
  /// [soundCollaterals], and the only world-edit on the planet.
  final Set<String> grafted = {};

  /// Cocks a Light hand has flagged. Purely informational — an unflagged cock
  /// can still be opened, you just do not know what is behind it.
  final Set<String> flagged = {};

  /// A Blood KIN's steadying: passage id → seconds it stays open past the
  /// turn, and the direction it was holding when the phase left it.
  ///
  /// A family-exclusive BONUS that no puzzle requires (§4), and purely
  /// ADDITIVE — it only ever leaves a road open longer, so the proof ignores
  /// it and is thereby strictly conservative.
  final Map<String, double> steadied = {};
  final Map<String, int> steadyDir = {};

  /// Seconds of held flatline left on the arena's vagal node. BOUNDED on
  /// purpose: an unbounded arrest would kill the periodicity the whole
  /// no-strand proof rests on (see the layout header, reason 7).
  double arrest = 0;

  /// Seconds until the vagal node answers again.
  double vagalCooldown = 0;

  /// The Lost Maxim: consecutive systole onsets struck in time.
  int drumStreak = 0;
  bool drumHeard = false;

  /// True while this beat's systole onset has already been answered, so one
  /// strike cannot count twice.
  bool drumStruckThisBeat = false;

  /// Whether the drum's window was open on the previous frame, so the module
  /// can see the window CLOSE and break a streak nobody answered.
  bool drumWindowLast = false;

  /// Seconds left on the pulse ring the render throws at a phase turn.
  double turn = 0;

  /// Hemavorn as the heart left it: at the very top of a systole, with the
  /// gate's own vein already carrying. The run begins moving.
  void reset() {
    clock = 0;
    phase = PulsePhase.systole;
    beats = 0;
    ostiaPrimed.clear();
    cocksTurned.clear();
    grafted.clear();
    flagged.clear();
    steadied.clear();
    steadyDir.clear();
    arrest = 0;
    vagalCooldown = 0;
    drumStreak = 0;
    drumHeard = false;
    drumStruckThisBeat = false;
    drumWindowLast = false;
    turn = 0;
    // The corruption is NOT cleared here: a death inside the run must not
    // re-roll which vessels are sound, or the Light flagging would be a lie.
    // `rollCorruption` is called once, when the descent is built.
  }

  /// Roll which collaterals are sound. Called once per descent.
  void rollCorruption(int Function(int) nextInt) {
    final ids = [for (final c in kHeartCocks) c.passageId];
    // Fisher–Yates over a copy, then take the first n — uniform over all ten
    // rolls, and the proof enumerates all ten regardless.
    for (var i = ids.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = ids[i];
      ids[i] = ids[j];
      ids[j] = t;
    }
    soundCollaterals
      ..clear()
      ..addAll(ids.take(kSoundCollateralCount));
  }

  // ── The beat ──────────────────────────────────────────

  /// Advance the world's clock. Returns true on a phase TURN, so the caller
  /// can throw the pulse ring and re-read the doors exactly once.
  ///
  /// This is the only mover on the planet the player has no verb for, and its
  /// unbranching periodicity is premise one of the no-strand proof.
  bool advance(double dt) {
    for (final id in steadied.keys.toList()) {
      final left = steadied[id]! - dt;
      if (left <= 0) {
        steadied.remove(id);
        steadyDir.remove(id);
      } else {
        steadied[id] = left;
      }
    }
    if (vagalCooldown > 0) vagalCooldown -= dt;
    if (turn > 0) turn -= dt;
    if (arrest > 0) {
      // A held flatline. The clock is pinned at the top of the pause and
      // resumes from there — it is a PAUSE, never a rewind, so no phase is
      // ever skipped by an arrest.
      arrest -= dt;
      clock = pulsePhaseStart(PulsePhase.flatline);
      final was = phase;
      phase = PulsePhase.flatline;
      return was != phase;
    }
    final was = phase;
    clock += dt;
    if (clock >= kPulseCycleSeconds) {
      clock -= kPulseCycleSeconds * (clock ~/ kPulseCycleSeconds);
      beats++;
    }
    phase = pulsePhaseAt(clock);
    return was != phase;
  }

  /// Sanguorath's extrasystole: throw the beat forward one whole phase. The
  /// guardian's weapon (§7 — the mystic fights WITH the planet's rule), and
  /// still an ADVANCE, so periodicity survives it untouched.
  void skipPhase() {
    final next = nextPulsePhase(phase);
    clock = pulsePhaseStart(next);
    phase = next;
  }

  /// The vagal node: stop the heart, briefly. Bounded by the caller.
  void arrestFor(double seconds) {
    arrest = seconds;
    clock = pulsePhaseStart(PulsePhase.flatline);
    phase = PulsePhase.flatline;
  }

  /// Seconds until [want] comes round again — what the readout shows and what
  /// makes a window something a player can PLAN for rather than react to.
  double secondsUntil(PulsePhase want) {
    if (arrest > 0) return want == PulsePhase.flatline ? 0 : arrest;
    if (phase == want) return 0;
    var t = pulsePhaseStart(want) - clock;
    if (t < 0) t += kPulseCycleSeconds;
    return t;
  }

  // ── The map, at the moment it is ──────────────────────

  /// Whether [p] carries FROM [here] right now. The steadying is folded in
  /// last, and only ever as an extra yes.
  bool carriesFrom(HeartPassage p, String here) {
    if (p.carriesFrom(here, phase, grafted: grafted.contains(p.id))) {
      return true;
    }
    final dir = steadyDir[p.id];
    if (dir == null || !steadied.containsKey(p.id)) return false;
    return dir > 0 ? here == p.from : here == p.to;
  }

  /// Whether [p] carries in EITHER direction right now — what the render
  /// needs to draw a lumen open or collapsed.
  bool lumenOpen(HeartPassage p) =>
      carriesFrom(p, p.from) || carriesFrom(p, p.to);

  // ── Star 0 ────────────────────────────────────────────

  bool get everyOstiumPrimed => ostiaPrimed.length >= kHeartOstia.length;

  /// Whether [o] can be primed at this instant.
  bool canPrime(Ostium o) =>
      !ostiaPrimed.contains(o.id) && phase == o.phase;

  // ── Star 1 ────────────────────────────────────────────

  bool get everyGraftTaken => grafted.length >= kSoundCollateralCount;

  bool isSound(String passageId) => soundCollaterals.contains(passageId);
}

// ─────────────────────────────────────────────────────────
// PER-ROOM ORRERY CONTENT
// ─────────────────────────────────────────────────────────

/// Everything the Sanguine Orrery put in one chamber. Carried on
/// `DungeonRoom.sanguine` so exactly one field had to be added to the shared
/// room model, and so a room's star index is visible to the layout invariants
/// and to the proof.
class SanguineChamber {
  /// The star this chamber banks (null = a connective vessel).
  final int? starIndex;

  /// The entry rite: the pericardium, a sac stitched shut over the gate.
  /// Element-only Blood (§4).
  final Offset? pericardium;

  /// The rite's second half — the BALANCE, where a dark sconce and a light
  /// one stand either side of the heart (§6's S3). Element-only Blood, with
  /// **Dark+Light→Blood** as the authored braid, and the module latches
  /// `conduitEnergy['B']` itself. Authoring it as a family-less Conduit would
  /// let the engine's channel verb step over it — the same reason Ice left
  /// its cold font out, Dust its great glass, Plant its sepulchre and Dark
  /// its snuffer.
  final Offset? balance;

  /// The Lost Maxim (§6 #17): the heart-drum. Twelve straight beats struck in
  /// sync. The one reaction-timed thing on the planet, and it is optional.
  final Offset? heartDrum;

  /// Sanguorath's arena floor: the VAGAL NODE. It stops the heart for a few
  /// seconds — the party's only hand on the clock, the fight's errand, and
  /// the arena's second safety belt after the phase-free chordae gate.
  final Offset? vagalNode;

  const SanguineChamber({
    this.starIndex,
    this.pericardium,
    this.balance,
    this.heartDrum,
    this.vagalNode,
  });
}

// ─────────────────────────────────────────────────────────
// THE LAYOUT
// ─────────────────────────────────────────────────────────

/// Hemavorn — the Sanguine Orrery.
const DungeonLayout bloodLayout = DungeonLayout(
  element: 'Blood',
  entranceRoomId: 'pericard_gate',
  entranceSpawn: Offset(110, 240),
  title: 'THE SANGUINE ORRERY',
  descentTitle: 'Hemavorn Orrery',
  stars: [
    DungeonStarSpec(
      name: 'Priming Star',
      earnAnnouncement:
          'The Priming Star is yours — four mouths drinking, and never two of '
          'them on the same beat',
    ),
    DungeonStarSpec(
      name: 'Graft Star',
      earnAnnouncement:
          'The Graft Star is yours — three dead vessels carrying, and the '
          'eight has roads the beat never gave it',
    ),
    DungeonStarSpec(name: 'Systole Star'),
  ],
  // The pericardium is stitched over the gate until a Blood hand opens it.
  entranceRevealDoor: DungeonDoorRef('pericard_gate', 'arterial_run'),
  finaleDoor: DungeonDoorRef('myocardium', 'sanguorath_systole'),
  riteAnnouncement:
      'Priming and Graft are won — the cannula seats in the myocardium, and '
      'the chordae gate goes slack',
  finaleSealedHint:
      'The chordae gate is drawn tight — it answers only the Priming and '
      'Graft stars',
  guardianSealedHint:
      'Nothing behind the chordae stirs while the heart is still keeping its '
      'own time',
  mercyShrineRoomId: 'arterial_run',
  // Ideal: Bloodkin · Darkmask · Lightmask — hinted by VERB, never body part
  // (§4): the hand that steadies old engines, the sight that pierces the
  // hidden, and the light that shows a thing for what it is.
  riddle: [
    'Bring me a hand that steadies an old engine, for mine has not kept its '
        'own time in an age;',
    'bring me a sight that pierces the hidden, since the roads I have left '
        'are inside the wall and unlit;',
    'and bring me a light that shows a thing for what it is, because half of '
        'what I will offer you is rotten.',
  ],
  // §4 budget: TWO hard gates, on two different objects and two different
  // entry slots, and never two on one star. Star 0 (the priming) is
  // deliberately UNGATED and uses all three elements at full power, so any
  // trio of Blood/Dark/Light progresses on a first descent — §6 put a
  // Bloodkin gate on this planet's FIRST star, and §4's first-descent
  // guarantee wins, so that gate moved onto the rite's cannula. The pulse
  // itself has no verb at all: a clock you cannot re-shape is only safe
  // because it comes round, and it always does.
  familyGates: [
    DungeonFamilyGate(
      objectId: 'collateral_cock',
      element: 'Dark',
      family: 'Mask',
      hintLine:
          'Only a Dark that sees inside an unlit vessel can graft this cock',
    ),
    DungeonFamilyGate(
      objectId: 'A',
      element: 'Blood',
      family: 'Kin',
      hintLine: 'Only a Blood the heart already knows will steady this cannula',
    ),
  ],
  rooms: {
    // ── THE PERICARD GATE (entrance · greater lobe) ───────
    // The threshold, and the planet's whole grammar in one room: the way out
    // to the run is a vein, and a vein is a road only while the heart is
    // pushing through it. Standing here through one beat teaches the rule
    // without a word of tutorial.
    'pericard_gate': DungeonRoom(
      id: 'pericard_gate',
      bounds: Rect.fromLTWH(0, 0, 760, 480),
      walls: [
        Rect.fromLTWH(240, 96, 180, 26), // a fallen rib of the sac's frame
      ],
      doors: [
        // The pericardial vein, east into the run (greater lobe, forward).
        DungeonDoor(
          rect: Rect.fromLTWH(736, 180, 24, 110),
          targetRoomId: 'arterial_run',
          targetSpawn: Offset(60, 250),
        ),
        // The great return, down into the crossing (greater lobe, the vein
        // that CLOSES the round — see the header, reason 3).
        DungeonDoor(
          rect: Rect.fromLTWH(140, 456, 110, 24),
          targetRoomId: 'vena_crossing',
          targetSpawn: Offset(255, 120),
        ),
        // The diagonal collateral, up to the arch (dead until grafted).
        DungeonDoor(
          rect: Rect.fromLTWH(320, 0, 110, 24),
          targetRoomId: 'aortic_arch',
          targetSpawn: Offset(185, 380),
        ),
        // The anastomosis, down to the gallery (dead until grafted).
        DungeonDoor(
          rect: Rect.fromLTWH(520, 456, 110, 24),
          targetRoomId: 'atrial_gallery',
          targetSpawn: Offset(720, 250),
        ),
      ],
      sanguine: SanguineChamber(pericardium: Offset(620, 235)),
    ),

    // ── THE ARTERIAL RUN (mercy shrine · greater lobe) ────
    'arterial_run': DungeonRoom(
      id: 'arterial_run',
      bounds: Rect.fromLTWH(0, 0, 820, 500),
      walls: [
        Rect.fromLTWH(300, 226, 240, 30), // a collapsed span of the run
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 195, 24, 110),
          targetRoomId: 'pericard_gate',
          targetSpawn: Offset(690, 235),
        ),
        // The long run, east to the arch (greater lobe, forward).
        DungeonDoor(
          rect: Rect.fromLTWH(796, 195, 24, 110),
          targetRoomId: 'aortic_arch',
          targetSpawn: Offset(60, 250),
        ),
        // The short collateral, down to the crossing (dead until grafted).
        DungeonDoor(
          rect: Rect.fromLTWH(355, 476, 110, 24),
          targetRoomId: 'vena_crossing',
          targetSpawn: Offset(645, 120),
        ),
      ],
      sanguine: SanguineChamber(),
    ),

    // ── THE AORTIC ARCH (the vault's chamber · greater) ───
    // The far turn of the greater round, and the chamber the reliquary hangs
    // off. It carries two cocks at opposite haunches and the arch mouth in
    // the middle, so it is the busiest room on the planet — and the one the
    // player learns to arrive at with a plan for what the next phase is.
    'aortic_arch': DungeonRoom(
      id: 'aortic_arch',
      bounds: Rect.fromLTWH(0, 0, 780, 500),
      walls: [
        Rect.fromLTWH(330, 400, 130, 28), // the arch's dropped keystone
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 195, 24, 110),
          targetRoomId: 'arterial_run',
          targetSpawn: Offset(760, 250),
        ),
        // The arch, on into the crossing (greater lobe, forward).
        DungeonDoor(
          rect: Rect.fromLTWH(756, 195, 24, 110),
          targetRoomId: 'vena_crossing',
          targetSpawn: Offset(60, 280),
        ),
        // THE LEAFLET — the vault (§5.5). Held shut by pressure from either
        // side, so it hangs open only on the flatline, and it is the same
        // leaflet coming back out.
        DungeonDoor(
          rect: Rect.fromLTWH(330, 0, 110, 24),
          targetRoomId: 'auricle_reliquary',
          targetSpawn: Offset(210, 230),
        ),
        // The diagonal collateral, back to the gate (dead until grafted).
        DungeonDoor(
          rect: Rect.fromLTWH(130, 476, 110, 24),
          targetRoomId: 'pericard_gate',
          targetSpawn: Offset(375, 70),
        ),
        // The shunt, across into the weave (dead until grafted).
        DungeonDoor(
          rect: Rect.fromLTWH(520, 476, 110, 24),
          targetRoomId: 'capillary_weave',
          targetSpawn: Offset(420, 70),
        ),
      ],
      sanguine: SanguineChamber(),
    ),

    // ── THE VENA CROSSING (Star 0 · where the eight crosses) ──
    // Both rounds pass through here and nowhere else, which is what makes the
    // map a figure of eight rather than two rings. The sinus mouth is the
    // priming's last lesson: it drinks only while the heart is doing nothing,
    // so the party has to be standing in the crossing when the beat dies.
    'vena_crossing': DungeonRoom(
      id: 'vena_crossing',
      bounds: Rect.fromLTWH(0, 0, 900, 560),
      walls: [
        Rect.fromLTWH(360, 380, 180, 30), // the crossing's old baffle
      ],
      doors: [
        // The arch, back west (greater lobe).
        DungeonDoor(
          rect: Rect.fromLTWH(0, 225, 24, 110),
          targetRoomId: 'aortic_arch',
          targetSpawn: Offset(720, 250),
        ),
        // The great return, up to the gate (greater lobe, forward).
        DungeonDoor(
          rect: Rect.fromLTWH(200, 0, 110, 24),
          targetRoomId: 'pericard_gate',
          targetSpawn: Offset(195, 380),
        ),
        // The short collateral, up to the run (dead until grafted).
        DungeonDoor(
          rect: Rect.fromLTWH(590, 0, 110, 24),
          targetRoomId: 'arterial_run',
          targetSpawn: Offset(410, 400),
        ),
        // The pulmonic mouth, east into the lung (lesser lobe, forward). The
        // commitment: past here the round never reverses.
        DungeonDoor(
          rect: Rect.fromLTWH(876, 225, 24, 110),
          targetRoomId: 'pulmonic_stair',
          targetSpawn: Offset(60, 250),
        ),
        // The sinus mouth, out of the gallery (lesser lobe, forward — this
        // door is the lung's EXIT, not its entrance).
        DungeonDoor(
          rect: Rect.fromLTWH(400, 536, 110, 24),
          targetRoomId: 'atrial_gallery',
          targetSpawn: Offset(255, 120),
        ),
        // The endocardial door — mural, phase-free (see the header, reason 4).
        DungeonDoor(
          rect: Rect.fromLTWH(700, 536, 110, 24),
          targetRoomId: 'myocardium',
          targetSpawn: Offset(410, 110),
        ),
      ],
      sanguine: SanguineChamber(starIndex: 0),
    ),

    // ── THE PULMONIC STAIR (lesser lobe) ──────────────────
    'pulmonic_stair': DungeonRoom(
      id: 'pulmonic_stair',
      bounds: Rect.fromLTWH(0, 0, 740, 480),
      doors: [
        // Back down the pulmonic mouth — a door that only carries on the
        // diastole, and only the OTHER way. The lung does not let you back.
        DungeonDoor(
          rect: Rect.fromLTWH(0, 185, 24, 110),
          targetRoomId: 'vena_crossing',
          targetSpawn: Offset(835, 280),
        ),
        // The fine weave, on round (lesser lobe, forward).
        DungeonDoor(
          rect: Rect.fromLTWH(716, 185, 24, 110),
          targetRoomId: 'capillary_weave',
          targetSpawn: Offset(60, 260),
        ),
        // The bypass, across the lung (dead until grafted).
        DungeonDoor(
          rect: Rect.fromLTWH(315, 456, 110, 24),
          targetRoomId: 'atrial_gallery',
          targetSpawn: Offset(615, 120),
        ),
      ],
      sanguine: SanguineChamber(),
    ),

    // ── THE CAPILLARY WEAVE (Star 1 · lesser lobe) ────────
    // The deepest chamber of the lung, and the one the strategic question is
    // written for: you can only be here on somebody else's schedule.
    'capillary_weave': DungeonRoom(
      id: 'capillary_weave',
      bounds: Rect.fromLTWH(0, 0, 840, 520),
      walls: [
        Rect.fromLTWH(340, 250, 150, 32), // a knot of collapsed capillary
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 205, 24, 110),
          targetRoomId: 'pulmonic_stair',
          targetSpawn: Offset(680, 240),
        ),
        // The atrial run, on round (lesser lobe, forward).
        DungeonDoor(
          rect: Rect.fromLTWH(816, 205, 24, 110),
          targetRoomId: 'atrial_gallery',
          targetSpawn: Offset(60, 260),
        ),
        // The shunt, back up to the arch (dead until grafted).
        DungeonDoor(
          rect: Rect.fromLTWH(365, 0, 110, 24),
          targetRoomId: 'aortic_arch',
          targetSpawn: Offset(575, 410),
        ),
      ],
      sanguine: SanguineChamber(starIndex: 1),
    ),

    // ── THE ATRIAL GALLERY (the Lost Maxim · lesser lobe) ─
    'atrial_gallery': DungeonRoom(
      id: 'atrial_gallery',
      bounds: Rect.fromLTWH(0, 0, 800, 500),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 195, 24, 110),
          targetRoomId: 'capillary_weave',
          targetSpawn: Offset(780, 260),
        ),
        // The sinus mouth, out of the lung (lesser lobe, forward — the vein
        // that CLOSES the lesser round, and the reason entering the lung is a
        // commitment rather than a trap).
        DungeonDoor(
          rect: Rect.fromLTWH(200, 0, 110, 24),
          targetRoomId: 'vena_crossing',
          targetSpawn: Offset(455, 450),
        ),
        // The bypass, back across the lung (dead until grafted).
        DungeonDoor(
          rect: Rect.fromLTWH(560, 0, 110, 24),
          targetRoomId: 'pulmonic_stair',
          targetSpawn: Offset(370, 390),
        ),
        // The anastomosis, out to the gate (dead until grafted).
        DungeonDoor(
          rect: Rect.fromLTWH(776, 195, 24, 110),
          targetRoomId: 'pericard_gate',
          targetSpawn: Offset(575, 395),
        ),
      ],
      sanguine: SanguineChamber(heartDrum: Offset(650, 350)),
    ),

    // ── THE MYOCARDIUM (the rite · inside the eight) ──────
    // Conduit A is the planet's Blood+KIN gate — the cannula, which has to be
    // held steady in a wall that will not stop moving. The chamber's other
    // half is the BALANCE: §6's S3, "balance dark/light beams around the
    // heart", element-only Blood with **Dark+Light→Blood** authored as the
    // braid for a party whose Blood hand is down. The module latches
    // `conduitEnergy['B']` itself.
    'myocardium': DungeonRoom(
      id: 'myocardium',
      bounds: Rect.fromLTWH(0, 0, 820, 520),
      doors: [
        // The endocardial door — mural, phase-free.
        DungeonDoor(
          rect: Rect.fromLTWH(355, 0, 110, 24),
          targetRoomId: 'vena_crossing',
          targetSpawn: Offset(755, 450),
        ),
        // The chordae gate — mural, phase-free, and the finale door.
        DungeonDoor(
          rect: Rect.fromLTWH(355, 496, 110, 24),
          targetRoomId: 'sanguorath_systole',
          targetSpawn: Offset(450, 140),
        ),
      ],
      conduits: [
        Conduit(
          id: 'A',
          position: Offset(250, 270),
          requireElement: 'Blood',
          requiredFamily: DungeonAbility.ancientStabilize,
        ),
      ],
      sanguine: SanguineChamber(balance: Offset(560, 270)),
    ),

    // ── THE AURICLE RELIQUARY (the vault) ─────────────────
    // §5.5's trick: reachable only in the flatline window between beats. The
    // leaflet is the pocket's only way, and it is the same way in both
    // directions — so the party can only ever be in here having come through
    // a flatline, and a flatline always comes again. That is what keeps the
    // trick from being a trap (the header, reason 5).
    'auricle_reliquary': DungeonRoom(
      id: 'auricle_reliquary',
      bounds: Rect.fromLTWH(0, 0, 420, 320),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(155, 296, 110, 24),
          targetRoomId: 'aortic_arch',
          targetSpawn: Offset(385, 110),
        ),
      ],
      vaultCache: Offset(210, 150),
      sanguine: SanguineChamber(),
    ),

    // ── SANGUORATH'S SYSTOLE (Star 2) ─────────────────────
    // §7 guardian principle — the mystic fights WITH the planet's rule.
    // Sanguorath IS the arrhythmia: its lull exists only on the FLATLINE, and
    // every strike beat it throws the heart forward a whole phase, so the
    // rhythm the party learned outside will not hold in here. The floor's
    // VAGAL NODE is their own hand on the same clock — stop the heart, take
    // the lull. The chordae gate is phase-free, so nothing in this fight can
    // ever shut the party in.
    'sanguorath_systole': DungeonRoom(
      id: 'sanguorath_systole',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'myocardium',
          targetSpawn: Offset(450, 420),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(450, 300),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Blood',
          mysticId: 'Sanguorath',
          canCalm: true,
          canDefeat: true,
        ),
      ),
      sanguine: SanguineChamber(vagalNode: Offset(450, 510)),
    ),
  },
);
