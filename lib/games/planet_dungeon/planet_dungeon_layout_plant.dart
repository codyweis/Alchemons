// lib/games/planet_dungeon/planet_dungeon_layout_plant.dart
//
// VERDANTHOS — the Verdant Crypt. Plant's authored layout, its pure rules, and
// the puzzle DATA its `part of planet_dungeon_game.dart` module reasons about.
//
// TOPOLOGY (docs/dungeons.md §5.5, structural assignment table): **NESTED
// SCALES — the same map at tiny and huge, overlaid.** There is no hub, there
// are no wings, and — this is the point — there is only ONE set of rooms. The
// crypt is a single funerary garden grown so old that its plants are its
// architecture. What changes is not the world but the BODY looking at it:
//
//     ── the crypt, ONE geometry ───────────────────────────
//               crypt_niche ·N·
//        (b1 worm-run)╵    ╵(b2 grate)    ╵(b3 thread)
//     fern_gallery ── mosswalk ── root_porch
//         ╵tread        ╵rill        ╵(b3 flag-gap)
//     pollen_stair ── lantern_court        islet ── gourd_hollow
//                          ╵                 ╵chancel
//                          └──── bloom_hall ──── botanica_heart
//
// WORLD RULE — *the crypt never changes size; you do.*
//
// THE INVARIANT (§5.5, Plant's claimed mechanic): **SCALE-DETERMINED
// AUTHORSHIP.** Every passage in the crypt exists at exactly one size, or at
// both. At HUGE a rill is a step and a fallen tread is a stair, but a crack is
// a hairline. At TINY every crack is a corridor and every rill is a river. You
// change size ONLY at a BOLE — a hollow seed-gall that three rooms in ten
// carry — so the run is a route-planning problem over (room × scale), and
// "which scale to be, where" is a DECISION, not an execution.
//
// This is deliberately NOT Dust's seat. Dust owns the Z-LAYER reading of
// layer-swap: two decks of rooms, and which deck you are on is a CONSEQUENCE
// of a load ledger. Here there is one deck and the ledger does not exist — the
// world is constant and the OBSERVER is the variable. Nor is it Crystal's
// permuting map (nothing here rearranges), Air's ordering (order barely
// matters; the SIZE of arrival is everything), Fire's handed-down sequence,
// Poison's triage, Ice's one-way descent, Steam's budget, or Mud's
// shape-authoring.
//
// ── HOW A SEED BED WORKS ──────────────────────────────────
// A BED is a place in the crypt where something can still be made to grow. It
// takes exactly one seed, ever, and WHAT it becomes is dictated by the size of
// the hand that plants it — which is to say, by the road that got you there:
//
//   • planted while HUGE — a giant's hand can only press a seed into the
//     surface. A shallow seed comes up a CREEPER: a green thread. To you it is
//     litter underfoot; to a small body it is a rope bridge, and it opens a
//     TINY-only span.
//   • planted while TINY — a small body climbs down inside the fissure and
//     sets the seed at the root. A deep seed comes up a TRUNK: to you it is a
//     bough you can walk, and it opens a HUGE-only span — and it **fills the
//     fissure it grew in**, so the very crack that let you plant it is gone.
//
// So each product is a road for the size you were NOT, and every trunk is an
// irreversible closure. Both edits are permanent for the run, exactly as Ice's
// flues and Mud's hardening are.
//
// THE STRATEGIC QUESTION (§5.5): *which scale to be, where — and each bed's
// product is decided by the size that could reach it, so committing a bed
// spends the very approach that reached it.* The sharpest instance is authored
// on purpose at the giant root (b1): its creeper is the ONLY small road to the
// islet — which Star 1's seeding and the vault both need — and its trunk is a
// bough into the lantern court that costs you the worm-run into the niche. One
// seed, and you commit standing at the size that brought you.
//
// THE VAULT TRICK (§5.5): *visible at huge scale, enterable only at tiny.* The
// growth altar on the islet is a stone bowl. Standing over it at huge you can
// SEE a little door cut in its rim, with the crypt's essence bottled behind
// it — and no hand of that size will ever open it. At tiny the same bowl is a
// walled court and the rim door is an arch you walk through. No prior planet's
// trick is this: Ice's is a mirror plus an unrepeatable slide, Dust's is a
// house you bury HARDER, Poison's is the ward you abandoned, Steam's is
// spending the whole budget, Lightning's is a dead trunk walked in the dark.
//
// THE ANTI-STRAND VALVE — THE WITHERING. A trunk deletes a crack, and the
// crypt's small graph is made of cracks: this is a stranding machine of the
// same family as Ice's flues (120/122), Mud's fen (1200/1284) and Dust's
// mounds (319/396). Verdanthos's answer is its leaf-litter: a MUD creature at
// any mulch pit turns it once to arm it and once more to call THE WITHERING —
// the crypt's season turns, every vine in it sloughs to mould, every bed is
// bare again, and the garden puts you out at its own gate at your own size. It
// costs every road you grew. A do-over, not a shortcut. Element-only Mud and
// authored in every room the party can stand in bar the guardian's, because a
// valve you cannot reach is not a valve.
//
// Mechanic-ledger note (§5.5): Plant claims **scale shift tiny/huge** and,
// under it, **scale-determined authorship** — the world-edit an object accepts
// is fixed by the size you arrived at, and each product serves the other size.
// That is what keeps it clear of Ice's treasure-or-ladder exclusivity: nothing
// here is committed blind. You always know which product you want; the puzzle
// is whether the crypt will let you arrive at the size that makes it.
//
// VISUAL GRAMMAR (§5.5): nothing here is drawn like Dust's mound heights or
// Water's tide line. Scale is rendered as a change of REFERENCE — at tiny the
// room's own furniture is redrawn as terrain (moss as a canopy, a flagstone
// joint as a ravine, dew as standing water) and the party's rendered radius
// halves; at huge the same furniture is trim. A creeper is a single hairline
// filament with leaf nodes; a trunk is a broad barked column with a crown.

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

// ─────────────────────────────────────────────────────────
// SCALE
// ─────────────────────────────────────────────────────────

/// The two bodies the crypt can be walked in. There is no third state and no
/// in-between: a span either takes you or it does not, so the player can read
/// the map without arithmetic.
enum PlantScale {
  /// A small body. Cracks, worm-runs and grates are corridors; rills are
  /// rivers, treads are cliffs, and a creeper is a rope bridge.
  tiny,

  /// A body of ordinary size — the size the crypt's mourners were. Rills are
  /// a step and treads are a stair; every small way is shut.
  huge,
}

PlantScale otherScale(PlantScale s) =>
    s == PlantScale.tiny ? PlantScale.huge : PlantScale.tiny;

String scaleWord(PlantScale s) => s == PlantScale.tiny ? 'tiny' : 'huge';

// ─────────────────────────────────────────────────────────
// SEED BEDS
// ─────────────────────────────────────────────────────────

/// What a bed is holding. A bed takes ONE seed for the whole run; only the
/// withering empties it.
enum VineState {
  /// Nothing planted. The bed's fissure (if it has one) is open to a small
  /// body, and the bed will still take either seed.
  bare,

  /// A shallow seed, set by a huge hand. A green thread: a TINY-only road.
  creeper,

  /// A deep seed, set by a tiny hand. A bough: a HUGE-only road — and the
  /// fissure it grew in is filled.
  trunk,
}

/// One place in the crypt where something can still be made to grow.
///
/// Authored as ONE list rather than per-room so the module's reachability
/// proof walks exactly the graph the doors are built from — the two can never
/// disagree. (Ice's flue list and Dust's mound list are the same idea for the
/// same reason.)
class SeedBed {
  final String id;

  /// The room you stand in to plant it.
  final String roomId;

  /// Where the bed sits inside [roomId] (the plant verb's reach).
  final Offset crown;

  /// One clause of scenery, for the reading and the render.
  final String look;

  const SeedBed({
    required this.id,
    required this.roomId,
    required this.crown,
    required this.look,
  });
}

/// Verdanthos's three beds. Every one starts [VineState.bare].
const List<SeedBed> kCryptBeds = [
  // THE GIANT ROOT. The planet's sharpest trade lives on this one bed: its
  // creeper is the only small road to the islet (Star 1's seeding AND the
  // vault), and its trunk is a bough into the court that fills the worm-run.
  SeedBed(
    id: 'b_root',
    roomId: 'fern_gallery',
    crown: Offset(400, 300),
    look: 'the split under the giant root',
  ),
  // THE CRACKED URN, in the lantern court. No fissure of its own — it costs
  // nothing but the other product, which is how the crypt teaches the choice
  // before it charges for it.
  SeedBed(
    id: 'b_urn',
    roomId: 'lantern_court',
    crown: Offset(620, 380),
    look: 'the cracked urn behind the sconce',
  ),
  // UNDER THE BROKEN TREAD. The repair bed: its creeper is a thread up the
  // stair wall into the niche — the way back to the third lamp when both of
  // the niche's cracks have been grown shut.
  SeedBed(
    id: 'b_tread',
    roomId: 'pollen_stair',
    crown: Offset(380, 280),
    look: 'the sifted soil under the broken tread',
  ),
];

SeedBed? cryptBedById(String id) {
  for (final b in kCryptBeds) {
    if (b.id == id) return b;
  }
  return null;
}

List<SeedBed> cryptBedsIn(String roomId) => [
  for (final b in kCryptBeds)
    if (b.roomId == roomId) b,
];

// ─────────────────────────────────────────────────────────
// SPANS — the map, at both sizes at once
// ─────────────────────────────────────────────────────────

/// Which body a span takes.
enum SpanSize {
  /// An ordinary arch or walk. Either body passes.
  both,

  /// A crack, a worm-run, a grate, a thread. Only a small body fits.
  tinyOnly,

  /// A stride over a rill, a giant's step onto a broken tread, a bough. Only
  /// a long leg and a heavy hand.
  hugeOnly,
}

/// What a span needs from its bed to exist at all.
enum SpanNeed {
  /// The bed's own FISSURE. Open while the bed is bare or holds a creeper;
  /// a trunk fills it, permanently.
  fissure,

  /// Exists only while the bed holds a creeper.
  creeper,

  /// Exists only while the bed holds a trunk.
  trunk,
}

/// One passage of the crypt, authored once and read from both ends.
///
/// The layout test enforces that EVERY door has a reciprocal door, statically
/// (docs §5.5 keeps that invariant for the whole game). A map whose
/// connectivity changes at runtime lives inside that rule the only honest
/// way: the doors are constant, and what varies is whether the body standing
/// at one is the size the passage was cut for.
class CryptSpan {
  final String id;
  final String from;
  final String to;
  final SpanSize size;

  /// The bed this span is a product of, or null for a permanent passage.
  final String? bedId;

  /// What [bedId] must hold. Null exactly when [bedId] is null.
  final SpanNeed? need;

  /// One clause naming the passage, used by the blocked line and the render.
  final String look;

  const CryptSpan({
    required this.id,
    required this.from,
    required this.to,
    required this.size,
    required this.look,
    this.bedId,
    this.need,
  });

  bool joins(String a, String b) =>
      (from == a && to == b) || (from == b && to == a);
}

/// The whole crypt as passages. Seventeen, and every room pair appears once —
/// so a door and a span are one-to-one and the proof cannot drift from the
/// doors the player actually meets.
const List<CryptSpan> kCryptSpans = [
  // ── permanent ────────────────────────────────────────
  CryptSpan(
    id: 'sp_lichgate',
    from: 'root_porch',
    to: 'mosswalk',
    size: SpanSize.both,
    look: 'the lich-gate arch',
  ),
  CryptSpan(
    id: 'sp_mosswalk',
    from: 'mosswalk',
    to: 'fern_gallery',
    size: SpanSize.both,
    look: 'the moss walk',
  ),
  CryptSpan(
    id: 'sp_rill',
    from: 'mosswalk',
    to: 'islet',
    size: SpanSize.hugeOnly,
    look: 'the sunken rill, one stride, or a river',
  ),
  CryptSpan(
    id: 'sp_tread',
    from: 'fern_gallery',
    to: 'pollen_stair',
    size: SpanSize.hugeOnly,
    look: 'the broken tread, one step down, or a cliff',
  ),
  CryptSpan(
    id: 'sp_landing',
    from: 'pollen_stair',
    to: 'lantern_court',
    size: SpanSize.both,
    look: 'the stair landing',
  ),
  // THE VAULT (§5.5): the little door cut in the growth altar's rim. Visible
  // from above at huge and impossible at that size; an arch at tiny. Its one
  // door is never blocked by anything — a pocket you walked into small, you
  // can always walk out of small (Ice's shelf rule), which is what keeps the
  // vault trick from being a trap.
  CryptSpan(
    id: 'sp_rim',
    from: 'islet',
    to: 'gourd_hollow',
    size: SpanSize.tinyOnly,
    look: 'the little door in the altar\'s rim',
  ),
  CryptSpan(
    id: 'sp_chancel',
    from: 'islet',
    to: 'bloom_hall',
    size: SpanSize.hugeOnly,
    look: 'the flooded chancel step',
  ),
  CryptSpan(
    id: 'sp_rood',
    from: 'bloom_hall',
    to: 'botanica_heart',
    size: SpanSize.both,
    look: 'the rood door',
  ),

  // ── b_root · the giant root ──────────────────────────
  CryptSpan(
    id: 'sp_wormrun',
    from: 'fern_gallery',
    to: 'crypt_niche',
    size: SpanSize.tinyOnly,
    bedId: 'b_root',
    need: SpanNeed.fissure,
    look: 'the worm-run under the giant root',
  ),
  CryptSpan(
    id: 'sp_ropebridge',
    from: 'fern_gallery',
    to: 'islet',
    size: SpanSize.tinyOnly,
    bedId: 'b_root',
    need: SpanNeed.creeper,
    look: 'a green thread over the rill',
  ),
  CryptSpan(
    id: 'sp_rootbough',
    from: 'fern_gallery',
    to: 'lantern_court',
    size: SpanSize.hugeOnly,
    bedId: 'b_root',
    need: SpanNeed.trunk,
    look: 'a bough over the gallery wall',
  ),

  // ── b_urn · the cracked urn ──────────────────────────
  CryptSpan(
    id: 'sp_grate',
    from: 'lantern_court',
    to: 'crypt_niche',
    size: SpanSize.tinyOnly,
    bedId: 'b_urn',
    need: SpanNeed.fissure,
    look: 'the grate\'s mesh',
  ),
  CryptSpan(
    id: 'sp_wallthread',
    from: 'lantern_court',
    to: 'mosswalk',
    size: SpanSize.tinyOnly,
    bedId: 'b_urn',
    need: SpanNeed.creeper,
    look: 'a thread along the crypt wall',
  ),
  CryptSpan(
    id: 'sp_urnbough',
    from: 'lantern_court',
    to: 'bloom_hall',
    size: SpanSize.hugeOnly,
    bedId: 'b_urn',
    need: SpanNeed.trunk,
    look: 'a bough over the chancel wall',
  ),

  // ── b_tread · under the broken tread ─────────────────
  CryptSpan(
    id: 'sp_flaggap',
    from: 'pollen_stair',
    to: 'root_porch',
    size: SpanSize.tinyOnly,
    bedId: 'b_tread',
    need: SpanNeed.fissure,
    look: 'the gap between two heaved flagstones',
  ),
  CryptSpan(
    id: 'sp_stairthread',
    from: 'pollen_stair',
    to: 'crypt_niche',
    size: SpanSize.tinyOnly,
    bedId: 'b_tread',
    need: SpanNeed.creeper,
    look: 'a thread up the stair wall',
  ),
  CryptSpan(
    id: 'sp_treadbough',
    from: 'pollen_stair',
    to: 'mosswalk',
    size: SpanSize.hugeOnly,
    bedId: 'b_tread',
    need: SpanNeed.trunk,
    look: 'a bough across to the moss walk',
  ),
];

/// The span joining these two rooms, or null. One pair, one span — pinned by
/// the tests.
CryptSpan? cryptSpanBetween(String a, String b) {
  for (final s in kCryptSpans) {
    if (s.joins(a, b)) return s;
  }
  return null;
}

// ─────────────────────────────────────────────────────────
// STAR 0 — THE GRAVE-LAMPS
// ─────────────────────────────────────────────────────────

/// One of the crypt's dead grave-lamps.
///
/// Star 0 is the planet's FIRST-DESCENT star (§4): it is earnable by ANY trio
/// of Plant/Light/Mud, uses all three elements at full power, and needs no bed
/// committed and no vine grown. It teaches the whole planet in one errand —
/// two of the lamps are giant wall sconces a small body cannot reach, and one
/// is a thumb-sized wick in a niche no large hand fits, so the only way to
/// light all three is to change size on the way.
class GraveLamp {
  final String id;

  /// The body that can reach it. The lamp is why the size matters.
  final PlantScale reach;

  final Offset position;

  const GraveLamp({
    required this.id,
    required this.reach,
    required this.position,
  });
}

/// Every lamp in the crypt. Two huge, one tiny — and the tiny one stands in
/// the niche, which no huge span ever reaches.
const List<GraveLamp> kGraveLamps = [
  GraveLamp(
    id: 'lamp_walk',
    reach: PlantScale.huge,
    position: Offset(450, 150),
  ),
  GraveLamp(
    id: 'lamp_court',
    reach: PlantScale.huge,
    position: Offset(440, 190),
  ),
  GraveLamp(
    id: 'lamp_niche',
    reach: PlantScale.tiny,
    position: Offset(260, 180),
  ),
];

// ─────────────────────────────────────────────────────────
// STAR 1 — THE GROWTH ALTAR
// ─────────────────────────────────────────────────────────

/// The three things the crypt's heart-seed wants, in the order physics puts
/// them in — and the sizes those three things can only be done at (§6: "relic
/// needs both scales").
///
/// The islet carries NO bole. Each step is therefore a separate journey at a
/// separate size, and the tiny one has no road at all until a creeper is grown
/// for it. That is the star: not three verbs, but three arrivals.
enum BloomStep {
  /// The bowl is dry. A MUD hand fills it with loam — and only a large one
  /// can carry loam enough to fill what is, to a small body, a lake bed.
  loam,

  /// A PLANT hand walks down into the bowl and sets the seed in the loam.
  /// Only a small body gets down there at all.
  seed,

  /// The crypt has no sky. A LIGHT MASK shows the seed a sun that is not
  /// there — the planet's marquee family gate (§4).
  sun,
}

/// Which body each step of the waking needs.
PlantScale bloomStepScale(BloomStep s) => switch (s) {
  BloomStep.loam => PlantScale.huge,
  BloomStep.seed => PlantScale.tiny,
  BloomStep.sun => PlantScale.huge,
};

/// The element each step answers. All element-only bar the sun, which is the
/// star's ONE hard family gate (§4: max one per star).
String bloomStepElement(BloomStep s) => switch (s) {
  BloomStep.loam => 'Mud',
  BloomStep.seed => 'Plant',
  BloomStep.sun => 'Light',
};

// ─────────────────────────────────────────────────────────
// THE LIVE STATE — pure rules, no Flutter, no engine
// ─────────────────────────────────────────────────────────

/// Everything Verdanthos tracks for one run.
///
/// Kept deliberately small: this planet's whole difficulty is a REACHABILITY
/// question, so the state is the two things reachability depends on — what
/// size you are, and what every bed is holding — plus the per-star tallies.
class VerdantCrypt {
  VerdantCrypt() {
    reset();
  }

  /// The body the party is walking in. Party-wide: three creatures share one
  /// crypt and one size.
  PlantScale scale = PlantScale.huge;

  /// What each bed holds, keyed by [SeedBed.id].
  final Map<String, VineState> bed = {};

  /// Grave-lamps already burning (Star 0).
  final Set<String> lampsLit = {};

  /// How far the heart-seed's waking has got (Star 1). Steps are consumed in
  /// order — loam before seed before sun — because that is the order the
  /// physics puts them in, never because a plaque said so.
  int bloomStep = 0;

  /// Which elements have tended the hidden seed under the giant root (the
  /// Lost Maxim). Needs all three, at tiny, and then a look from above.
  final Set<String> tendedBy = {};

  /// The unseen shade, once it has towered.
  bool shadeRisen = false;

  /// How many times THE WITHERING has run — the valve's price tag, and a
  /// readout.
  int witherings = 0;

  /// Mulch pit armed for its second touch, and the seconds left on it.
  String? armedPitRoom;
  double armedPitTimer = 0;

  /// The crypt as its dead left it: nothing grown, and your own size.
  void reset() {
    scale = PlantScale.huge;
    bed.clear();
    for (final b in kCryptBeds) {
      bed[b.id] = VineState.bare;
    }
    lampsLit.clear();
    bloomStep = 0;
    tendedBy.clear();
    shadeRisen = false;
    witherings = 0;
    armedPitRoom = null;
    armedPitTimer = 0;
  }

  // ── Beds ──────────────────────────────────────────────

  VineState stateOf(String bedId) => bed[bedId] ?? VineState.bare;

  bool get isTiny => scale == PlantScale.tiny;

  /// A bed takes one seed and only one. Both products are permanent for the
  /// run; only the withering empties a bed.
  bool canPlant(String bedId) => stateOf(bedId) == VineState.bare;

  /// What a seed set by a body of [size] becomes. A giant can only press a
  /// seed into the surface; a small body climbs down and sets it at the root.
  VineState productFor(PlantScale size) =>
      size == PlantScale.huge ? VineState.creeper : VineState.trunk;

  /// Plant the one seed this bed will ever take. Returns what grew, or null
  /// when the bed is already spent.
  VineState? plant(String bedId) {
    if (!canPlant(bedId)) return null;
    final grown = productFor(scale);
    bed[bedId] = grown;
    return grown;
  }

  // ── The map, at the size you are ──────────────────────

  /// Whether [span] EXISTS at all in the current world — i.e. whether the bed
  /// behind it has grown the thing the span is made of. Size is not consulted
  /// here: a passage the wrong size for you is still a passage, and the
  /// player must be able to see it and be told so (§5.6 BLOCKED).
  bool spanExists(CryptSpan span) {
    final id = span.bedId;
    if (id == null) return true;
    return switch (span.need!) {
      // A trunk fills the crack it grew in. That is the irreversible closure
      // the whole no-strand proof is about.
      SpanNeed.fissure => stateOf(id) != VineState.trunk,
      SpanNeed.creeper => stateOf(id) == VineState.creeper,
      SpanNeed.trunk => stateOf(id) == VineState.trunk,
    };
  }

  /// Whether the body you are in fits [span].
  bool spanFits(CryptSpan span, PlantScale size) => switch (span.size) {
    SpanSize.both => true,
    SpanSize.tinyOnly => size == PlantScale.tiny,
    SpanSize.hugeOnly => size == PlantScale.huge,
  };

  /// Walkable right now.
  bool spanOpen(CryptSpan span) => spanExists(span) && spanFits(span, scale);

  // ── Star 0 ────────────────────────────────────────────

  bool get allLampsLit => lampsLit.length >= kGraveLamps.length;

  // ── Star 1 ────────────────────────────────────────────

  BloomStep? get nextBloomStep =>
      bloomStep >= BloomStep.values.length ? null : BloomStep.values[bloomStep];

  bool get bloomWoken => bloomStep >= BloomStep.values.length;

  // ── THE WITHERING (the anti-strand valve) ─────────────

  /// True when nothing has been grown and the party already stands at its own
  /// size — the season has nothing to turn, so the verb declines rather than
  /// burning a pit.
  bool get isFallow {
    if (scale != PlantScale.huge) return false;
    for (final b in kCryptBeds) {
      if (stateOf(b.id) != VineState.bare) return false;
    }
    return true;
  }

  /// THE WITHERING. Every vine sloughs to mould, every bed is bare, and the
  /// crypt puts you back in your own body. It costs every road you grew — see
  /// the header. Banked stars, the lamps and the bloom's progress all survive:
  /// the season takes the garden, never the work.
  void wither() {
    for (final b in kCryptBeds) {
      bed[b.id] = VineState.bare;
    }
    scale = PlantScale.huge;
    armedPitRoom = null;
    armedPitTimer = 0;
    witherings++;
  }
}

// ─────────────────────────────────────────────────────────
// PER-ROOM CRYPT CONTENT
// ─────────────────────────────────────────────────────────

/// Everything the Verdant Crypt put in one room. Carried on
/// `DungeonRoom.grove` so exactly one field had to be added to the shared room
/// model, and so a room's star index is visible to the layout invariants.
class CryptGrove {
  /// The star this room banks (null = a connective walk).
  final int? starIndex;

  /// A hollow seed-gall: the ONLY place the party changes size. Element-only
  /// Plant (Mud+Light→Plant braids for a party whose Plant hand is down), and
  /// deliberately rare — three in ten rooms is what makes "which scale to be,
  /// where" a route-planning DECISION rather than a button.
  final Offset? bole;

  /// Leaf-litter. A MUD hand turns it twice and calls THE WITHERING — the
  /// anti-strand valve. Authored in every room the party can stand in bar the
  /// guardian's arena, because a valve you cannot reach is not a valve.
  final Offset? mulchPit;

  /// The entry rite: the lich-gate is knotted shut with dead briar. A PLANT
  /// hand unknots its own element and the crypt opens.
  final Offset? briarGate;

  /// Star 0: this room's grave-lamp.
  final String? lampId;

  /// Star 1: the growth altar on the islet — the bowl, the rim door, and the
  /// crypt's heart-seed.
  final Offset? growthAltar;

  /// The rite's second half: the hall's clay-sealed sepulchre (element-only
  /// Mud; latches conduit 'B').
  final Offset? sepulchre;

  /// The Lost Maxim: the seed nobody planted, hidden under the giant root and
  /// visible only to a body small enough to be under there.
  final Offset? shadeSeed;

  /// Botanica's own root-gall — the arena's shrink point, and the fight's
  /// whole verb (§7).
  final Offset? rootBole;

  const CryptGrove({
    this.starIndex,
    this.bole,
    this.mulchPit,
    this.briarGate,
    this.lampId,
    this.growthAltar,
    this.sepulchre,
    this.shadeSeed,
    this.rootBole,
  });
}

// ─────────────────────────────────────────────────────────
// THE LAYOUT
// ─────────────────────────────────────────────────────────

/// Verdanthos — the Verdant Crypt.
const DungeonLayout plantLayout = DungeonLayout(
  element: 'Plant',
  entranceRoomId: 'root_porch',
  entranceSpawn: Offset(120, 240),
  title: 'THE VERDANT CRYPT',
  descentTitle: 'Verdanthos Crypt',
  stars: [
    DungeonStarSpec(
      name: 'Lamp Star',
      earnAnnouncement:
          'The Lamp Star is yours, three graves lit, and none of them by the '
          'same body',
    ),
    DungeonStarSpec(
      name: 'Bloom Star',
      earnAnnouncement:
          'The Bloom Star is yours, the heart-seed wakes, loam and dark and '
          'a borrowed sun',
    ),
    DungeonStarSpec(name: 'Shade Star'),
  ],
  // The lich-gate is knotted shut until a Plant hand parts the briar.
  entranceRevealDoor: DungeonDoorRef('root_porch', 'mosswalk'),
  finaleDoor: DungeonDoorRef('bloom_hall', 'botanica_heart'),
  riteAnnouncement:
      'Lamp and Bloom are won, the clay cracks off the sepulchre in the hall',
  finaleSealedHint:
      'The rood door is shut, it answers only the Lamp and Bloom stars',
  guardianSealedHint:
      'The heart lies under a mat of root, nothing in there stirs until the '
      'sepulchre is opened',
  mercyShrineRoomId: 'mosswalk',
  // Ideal: Plantmane · Lightmask · Mudpip — hinted by VERB, never body part
  // (§4): the green that follows a wild thing's passing, the sight that
  // pierces the hidden, and what my smallest doors admit.
  riddle: [
    'Send me a Plant Mane: my rood screen has been dead a long age;',
    'a Light Mask, for I keep no sun and my seed still wants one;',
    'and Mud, because half of me was never built for you.',
  ],
  primer: [
    'The crypt is one place at two sizes, and every passage was cut for one of them.',
    'What you plant becomes a road for the size you were not.',
  ],
  // §4 budget: TWO hard gates, on two different stars/objects and two
  // different entry slots. Star 0 (the grave-lamps) is deliberately UNGATED
  // and uses all three elements at full power, so any trio of Plant/Light/Mud
  // progresses on a first descent — §6 put a Plantmane gate on this planet's
  // FIRST star, and §4's first-descent guarantee wins, so that gate has been
  // moved onto the rite's rood screen. The scale verb itself (the boles) and
  // the valve (the mulch pits) are element-only and always available.
  familyGates: [
    DungeonFamilyGate(
      objectId: 'altar_sun',
      element: 'Light',
      family: 'Mask',
      hintLine: 'Only a Light that can show what is not there passes for a sun',
    ),
    DungeonFamilyGate(
      objectId: 'A',
      element: 'Plant',
      family: 'Mane',
      hintLine:
          'Only green that follows a wild thing\'s passing wakes this '
          'screen',
    ),
  ],
  rooms: {
    // ── THE ROOT PORCH (entrance) ─────────────────────────
    // The crypt's threshold under an arch of root. Two ways on: the lich-gate
    // west into the moss walk, and — for a small body only — the gap between
    // two heaved flagstones down to the pollen stair. Both are knotted shut
    // until a Plant hand parts the briar.
    'root_porch': DungeonRoom(
      id: 'root_porch',
      bounds: Rect.fromLTWH(0, 0, 700, 460),
      walls: [
        Rect.fromLTWH(240, 70, 170, 28), // a toppled lintel
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(676, 175, 24, 110),
          targetRoomId: 'mosswalk',
          targetSpawn: Offset(60, 280),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(140, 436, 110, 24),
          targetRoomId: 'pollen_stair',
          targetSpawn: Offset(255, 120),
        ),
      ],
      grove: CryptGrove(
        briarGate: Offset(600, 215),
        bole: Offset(200, 240),
        mulchPit: Offset(110, 380),
      ),
    ),

    // ── THE MOSS WALK (the mercy shrine) ──────────────────
    // The crypt's long walk, and its first grave-lamp: a sconce set at the
    // height of a mourner, which is to say far out of a small body's world.
    'mosswalk': DungeonRoom(
      id: 'mosswalk',
      bounds: Rect.fromLTWH(0, 0, 900, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 225, 24, 110),
          targetRoomId: 'root_porch',
          targetSpawn: Offset(640, 230),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(876, 225, 24, 110),
          targetRoomId: 'fern_gallery',
          targetSpawn: Offset(60, 260),
        ),
        // The sunken rill: one stride at your own size, a river at the other.
        DungeonDoor(
          rect: Rect.fromLTWH(390, 536, 110, 24),
          targetRoomId: 'islet',
          targetSpawn: Offset(375, 90),
        ),
        // The urn's thread along the crypt wall (tiny; b_urn creeper).
        DungeonDoor(
          rect: Rect.fromLTWH(300, 0, 110, 24),
          targetRoomId: 'lantern_court',
          targetSpawn: Offset(355, 500),
        ),
        // The tread's bough across (huge; b_tread trunk).
        DungeonDoor(
          rect: Rect.fromLTWH(620, 0, 110, 24),
          targetRoomId: 'pollen_stair',
          targetSpawn: Offset(375, 420),
        ),
      ],
      grove: CryptGrove(lampId: 'lamp_walk', mulchPit: Offset(120, 470)),
    ),

    // ── THE FERN GALLERY (the giant root) ─────────────────
    // The planet's sharpest bed stands here, and so does the Lost Maxim's
    // hidden seed — which only exists for a body small enough to be under the
    // root at all.
    'fern_gallery': DungeonRoom(
      id: 'fern_gallery',
      bounds: Rect.fromLTWH(0, 0, 820, 520),
      walls: [
        Rect.fromLTWH(180, 180, 40, 200), // a buttress of root
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 205, 24, 110),
          targetRoomId: 'mosswalk',
          targetSpawn: Offset(840, 280),
        ),
        // Down the broken tread (huge).
        DungeonDoor(
          rect: Rect.fromLTWH(120, 496, 110, 24),
          targetRoomId: 'pollen_stair',
          targetSpawn: Offset(175, 130),
        ),
        // The worm-run up into the niche (tiny; b_root fissure).
        DungeonDoor(
          rect: Rect.fromLTWH(330, 0, 110, 24),
          targetRoomId: 'crypt_niche',
          targetSpawn: Offset(385, 300),
        ),
        // The root's own bough over the gallery wall (huge; b_root trunk).
        DungeonDoor(
          rect: Rect.fromLTWH(620, 0, 110, 24),
          targetRoomId: 'lantern_court',
          targetSpawn: Offset(675, 490),
        ),
        // The green thread over the rill (tiny; b_root creeper).
        DungeonDoor(
          rect: Rect.fromLTWH(796, 205, 24, 110),
          targetRoomId: 'islet',
          targetSpawn: Offset(60, 270),
        ),
      ],
      grove: CryptGrove(
        shadeSeed: Offset(620, 400),
        mulchPit: Offset(120, 440),
      ),
    ),

    // ── THE POLLEN STAIR ──────────────────────────────────
    // The crypt's middle transfer station: a bole, and the repair bed whose
    // creeper is the way back into the niche when both its cracks are gone.
    'pollen_stair': DungeonRoom(
      id: 'pollen_stair',
      bounds: Rect.fromLTWH(0, 0, 760, 500),
      doors: [
        // The flagstone gap up to the porch (tiny; b_tread fissure).
        DungeonDoor(
          rect: Rect.fromLTWH(200, 0, 110, 24),
          targetRoomId: 'root_porch',
          targetSpawn: Offset(195, 400),
        ),
        // Back up the broken tread (huge).
        DungeonDoor(
          rect: Rect.fromLTWH(480, 0, 110, 24),
          targetRoomId: 'fern_gallery',
          targetSpawn: Offset(175, 440),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(736, 195, 24, 110),
          targetRoomId: 'lantern_court',
          targetSpawn: Offset(60, 290),
        ),
        // The thread up the stair wall into the niche (tiny; b_tread creeper).
        DungeonDoor(
          rect: Rect.fromLTWH(0, 195, 24, 110),
          targetRoomId: 'crypt_niche',
          targetSpawn: Offset(60, 190),
        ),
        // The tread's bough across to the moss walk (huge; b_tread trunk).
        DungeonDoor(
          rect: Rect.fromLTWH(320, 476, 110, 24),
          targetRoomId: 'mosswalk',
          targetSpawn: Offset(675, 120),
        ),
      ],
      grove: CryptGrove(bole: Offset(140, 120), mulchPit: Offset(640, 420)),
    ),

    // ── THE CRYPT NICHE (the third lamp) ──────────────────
    // Every way in is a crack, so this room only exists for a small body — and
    // two of the three cracks are bed fissures a trunk can fill for good. It
    // is the planet's stranding hazard, drawn in one room.
    'crypt_niche': DungeonRoom(
      id: 'crypt_niche',
      bounds: Rect.fromLTWH(0, 0, 520, 380),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(200, 356, 110, 24),
          targetRoomId: 'fern_gallery',
          targetSpawn: Offset(255, 90),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(496, 135, 24, 110),
          targetRoomId: 'lantern_court',
          targetSpawn: Offset(195, 70),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 135, 24, 110),
          targetRoomId: 'pollen_stair',
          targetSpawn: Offset(60, 250),
        ),
      ],
      grove: CryptGrove(lampId: 'lamp_niche', mulchPit: Offset(260, 310)),
    ),

    // ── THE LANTERN COURT (Star 0) ────────────────────────
    // The second sconce, the cracked urn, and the room the Lamp Star banks in.
    'lantern_court': DungeonRoom(
      id: 'lantern_court',
      bounds: Rect.fromLTWH(0, 0, 880, 580),
      walls: [
        Rect.fromLTWH(330, 250, 220, 34), // the fallen catafalque
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 235, 24, 110),
          targetRoomId: 'pollen_stair',
          targetSpawn: Offset(700, 250),
        ),
        // The grate's mesh into the niche (tiny; b_urn fissure).
        DungeonDoor(
          rect: Rect.fromLTWH(140, 0, 110, 24),
          targetRoomId: 'crypt_niche',
          targetSpawn: Offset(455, 190),
        ),
        // The root's bough down into the gallery (huge; b_root trunk).
        DungeonDoor(
          rect: Rect.fromLTWH(250, 556, 110, 24),
          targetRoomId: 'fern_gallery',
          targetSpawn: Offset(675, 100),
        ),
        // The urn's thread back along the wall (tiny; b_urn creeper).
        DungeonDoor(
          rect: Rect.fromLTWH(560, 556, 110, 24),
          targetRoomId: 'mosswalk',
          targetSpawn: Offset(355, 110),
        ),
        // The urn's bough over the chancel wall (huge; b_urn trunk).
        DungeonDoor(
          rect: Rect.fromLTWH(856, 235, 24, 110),
          targetRoomId: 'bloom_hall',
          targetSpawn: Offset(60, 270),
        ),
      ],
      grove: CryptGrove(
        starIndex: 0,
        lampId: 'lamp_court',
        mulchPit: Offset(140, 480),
      ),
    ),

    // ── THE ISLET (Star 1) ────────────────────────────────
    // The Tiny-Huge Island (§6). It carries NO bole on purpose: every step of
    // the heart-seed's waking is a separate arrival at a separate size, and
    // the small one has no road at all until a creeper is grown for it.
    'islet': DungeonRoom(
      id: 'islet',
      bounds: Rect.fromLTWH(0, 0, 760, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(320, 0, 110, 24),
          targetRoomId: 'mosswalk',
          targetSpawn: Offset(445, 470),
        ),
        // The little door in the altar's rim — the vault (tiny).
        DungeonDoor(
          rect: Rect.fromLTWH(736, 215, 24, 110),
          targetRoomId: 'gourd_hollow',
          targetSpawn: Offset(60, 160),
        ),
        // The flooded chancel step (huge).
        DungeonDoor(
          rect: Rect.fromLTWH(325, 516, 110, 24),
          targetRoomId: 'bloom_hall',
          targetSpawn: Offset(385, 110),
        ),
        // The green thread back over the rill (tiny; b_root creeper).
        DungeonDoor(
          rect: Rect.fromLTWH(0, 215, 24, 110),
          targetRoomId: 'fern_gallery',
          targetSpawn: Offset(760, 260),
        ),
      ],
      grove: CryptGrove(
        starIndex: 1,
        growthAltar: Offset(380, 270),
        mulchPit: Offset(120, 450),
      ),
    ),

    // ── THE GOURD HOLLOW (the vault) ──────────────────────
    // Inside the growth altar's own rim. A pocket, and the planet's cache: you
    // came in small and the arch you came through is never blocked by
    // anything, whatever happens outside (Ice's shelf rule) — which is what
    // keeps the vault trick from being a trap (see the no-strand proof).
    'gourd_hollow': DungeonRoom(
      id: 'gourd_hollow',
      bounds: Rect.fromLTWH(0, 0, 420, 320),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 105, 24, 110),
          targetRoomId: 'islet',
          targetSpawn: Offset(700, 270),
        ),
      ],
      vaultCache: Offset(210, 160),
      grove: CryptGrove(mulchPit: Offset(330, 250)),
    ),

    // ── THE BLOOM HALL (the rite) ─────────────────────────
    // Conduit A is the planet's Plant+MANE gate — the dead rood screen of
    // briar, which only greens along a wild thing's passing. The hall's own
    // half is the clay-sealed sepulchre, an element-only Mud object the module
    // owns and which latches `conduitEnergy['B']` itself (authoring it as a
    // family-less Conduit would make the engine's channel verb step over it —
    // the same reason Ice left its cold font out and Dust its great glass).
    'bloom_hall': DungeonRoom(
      id: 'bloom_hall',
      bounds: Rect.fromLTWH(0, 0, 780, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(330, 0, 110, 24),
          targetRoomId: 'islet',
          targetSpawn: Offset(380, 450),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 215, 24, 110),
          targetRoomId: 'lantern_court',
          targetSpawn: Offset(820, 290),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(335, 516, 110, 24),
          targetRoomId: 'botanica_heart',
          targetSpawn: Offset(450, 150),
        ),
      ],
      conduits: [
        Conduit(
          id: 'A',
          position: Offset(250, 270),
          requireElement: 'Plant',
          requiredFamily: DungeonAbility.terrainTrail,
        ),
      ],
      grove: CryptGrove(
        sepulchre: Offset(540, 270),
        bole: Offset(140, 420),
        mulchPit: Offset(660, 110),
      ),
    ),

    // ── BOTANICA'S HEART (Star 2) ─────────────────────────
    // §7 guardian principle — the mystic fights WITH the planet's rule.
    // Botanica does not shrink the crypt; it SWELLS YOU. Every strike beat
    // bursts spores that put the party back in its own body, and the lull
    // exists only while you are small enough to be in among the roots at the
    // flower's stem. The same beat reaches out into the crypt and rots one
    // vine you grew, so it un-makes your roads while you fight it. The arena's
    // own root-gall is the shrink point, and the rood door is scale-free, so
    // nothing here can ever shut you in.
    'botanica_heart': DungeonRoom(
      id: 'botanica_heart',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'bloom_hall',
          targetSpawn: Offset(390, 450),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(450, 300),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Plant',
          mysticId: 'Botanica',
          canCalm: true,
          canDefeat: true,
        ),
      ),
      grove: CryptGrove(rootBole: Offset(450, 490)),
    ),
  },
);
