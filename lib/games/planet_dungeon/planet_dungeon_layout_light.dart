// lib/games/planet_dungeon/planet_dungeon_layout_light.dart
//
// SOLARIN — the Beacon Archive. Light's authored layout, its pure rules, and
// the puzzle DATA its `part of planet_dungeon_game.dart` module reasons about.
//
// TOPOLOGY (docs/dungeons.md §5.5, structural assignment table): **ONE GREAT
// HALL — NO CORRIDORS. Light beams partition the space into moving "rooms".**
// There is not one connective passage on this planet and not one wall between
// two bays: the archive is a single round hall under a single oculus, and what
// separates one bay of it from the next is nothing but whether there is
// anything to walk on. Every room below is a BAY of that one hall, and every
// "door" is a SILL — a stretch of the hall's broken floor.
//
//     ── the Beacon Archive, ONE hall, five sectors ─────────
//                     sector 0 · THE DOOR
//        catalogue_walk ══ lumen_threshold ══ shadow_court
//          (bc_ledger)   ╷   (bc_narthex)  ╷    (bc_oriel)
//     s.4 │              ╷                 ╷              ║ s.1→2
//     ════╪══ dark_stacks ══ moth_gallery ══╝              ║
//         ║        s.3          s.2                        ║
//         ╷                                                ║
//     ┌───┴──────── THE DARK HEART ──────────────────┐     ║
//     │  reading_floor ╷╴╴ oculus_stair ╴╴╷ sunless_reliquary
//     │      │ s.2 slype        s.0       s.1  (THE VAULT) │
//     │  (stone stair)                                     │
//     │  solarin_oculus                                    │
//     └────────────────────────────────────────────────────┘
//
//     (══  a GLASS LEAF: the archive's floor is glass over a lightwell, and
//          glass is nothing until there is light in it. Lit = a floor. Dark =
//          a hole. Every sill around the RIM is one of these.
//      ╷   a MIRROR SILL: a shelf of the archive's black mirror-stone. Plain
//          walkable stone in the dark; under light it is a sheet of glare
//          nobody crosses. Every sill INTO the heart is one of these.
//      the oculus stair is neither — living stone, and no light has ever
//      reached it.)
//
// WORLD RULE — *the statues lie; their shadows cannot — and every lumen you
// spend is seen.*
//
// THE INVARIANT (§5.5, Light's claimed mechanic): **LIGHT-CONE OCCLUSION +
// EXPOSURE MANAGEMENT.** Three beacons stand on the rim and throw light
// INWARD across the hall. A beacon is set to an ARC (which sectors its cone
// covers) and a PITCH:
//
//   • **LOW** — the beam breaks on the great stacks. In a sector where a stack
//     stands, only the RIM band is lit and everything behind the stack stays
//     in shadow. That shadow is the OCCLUSION, and it is the whole planet:
//     it is how one act of light gives you a road and a shadow at once.
//   • **HIGH** — the beam clears the stacks and floods the sector to its
//     INWARD band as well. Further, brighter, and it fills in exactly the
//     shadow you were standing in.
//
// In a sector with NOTHING standing in it, low and high are the same thing —
// there is no shadow to be had, because a shadow needs something to cast it.
// The two great stacks stand in sectors 1 and 2, and nowhere else.
//
// THE STRATEGIC QUESTION (§5.5): *aiming light builds paths AND exposes you —
// illuminate as little as possible.* Every lumen burning in the hall is one
// the moth-wardens can count, and the archive's own reading cannot be done
// above a HUSH of two. So the run is not "how do I light the road", it is
// "what is the smallest light that is still a road" — and the answer is
// usually a low beam breaking on a stack, because that costs one lumen where
// an open sector costs two.
//
// This is deliberately NOT Lightning's seat. Lightning owns beam
// routing/reflection through rotatable mirrors, where the question is WHERE
// THE BEAM GOES and the beam has a target. Nothing here has a target and
// nothing reflects: a beacon's arc is chosen, not routed, and the thing the
// player is actually placing is the SHADOW — the beam is only how you make
// one. Nor is it Dark's inverting maze: Dark's four quarters are flipped by
// three shadows in a closed zero-sum algebra where one act rewrites two
// quarters and you can never have everything; here nothing is scarce at all
// and you may light the whole archive at once if you dare — the pressure is
// EXPOSURE, not a shortage of light. It is not Steam's budget either (nothing
// is spent: douse a beacon and the lumens come straight back), not Dust's
// conservation, not Plant's observer scale, not Crystal's permuting map, not
// Mud's shape-authoring, not Air's ordering (every setting is freely
// reversible, so order is nothing), and not Fire's sequence.
//
// ── THE ARCHIVE'S ARITHMETIC (all of it, and all provable) ─────
// Five sectors, two bands (RIM and INWARD), two great stacks. A cell is lit
// iff some kindled beacon's arc covers its sector AND (the band is RIM, or
// the beacon is pitched HIGH, or nothing stands in that sector). From that
// one sentence:
//
//   • **A stacked sector costs ONE lumen at low pitch and TWO at high; an
//     empty sector costs TWO at any pitch.** The stacks are the only
//     discount in the archive, and they are the only shadows in it.
//   • **A sector with no stack can never be a road and a shadow at once.**
//     Sector 0 — the door bay — is the clearest case: light it at all and
//     both its bands go, so the undercroft into the heart shuts the instant
//     the doorway brightens. This is what makes Star 0 a journey instead of
//     a button (the effigies are pinned against exactly this).
//   • **THE DARK HEART.** Every sill into the hall's middle is a mirror sill,
//     so with the archive dark the heart is one connected floor and the rim
//     is not there at all. Dark, the whole of the heart — the oculus stair,
//     the reading floor, the reliquary and Solarin's own chamber — is
//     reachable from the door. Lit, the rim is a ring and the heart is shut.
//     The archive is two maps and the beacons choose which one you are in.
//
// THE VAULT TRICK (§5.5): *it stands in plain sight, and it is reachable only
// across un-lit ground.* The sunless reliquary is not hidden. It is a shrine
// on the hall's floor, visible from the doorway across an open room, and the
// player will see it in the first ten seconds — and the only sill onto it is
// the heartway, a mirror shelf in sector 1, which is a floor exactly while
// sector 1's INNER band is not lit. Sector 1 is also the only way onto the rim
// (the narthex leaf), and that is the trick: the beam that opens the archive
// to you is the beam that takes the heart away — unless you throw it LOW, so
// that the great stack standing in sector 1 keeps the shelf behind it in
// shadow. The vault is the planet's own thesis as an errand: a road and a
// shadow out of one act of light. The archive left blazing (the keepers threw
// the narthex beacon HIGH) hides it completely, and a player who never learns
// the pitch never sees the floor appear. The absolute version — everything
// out, and the walk made in total darkness — is how the Lost Maxim is earned
// (§6). No prior planet's trick is this: Dark's room does not exist in the
// light, Plant's is visible-but-too-small, Ice's a mirror plus an
// unrepeatable slide, Dust's a house you bury HARDER, Poison's the ward you
// abandoned, Steam's spending the whole budget, Lightning's a dead trunk
// walked dark, Crystal's a cell that only joins the grid in one
// configuration, Spirit's a grave the living world does not contain.
//
// ── WHY THERE IS NO RESET VALVE, AND WHY THERE CANNOT BE A SOFTLOCK ──
// Ice, Mud, Dust and Plant all shipped a costly full-reset valve. The Beacon
// Archive needs none, and the reason is not a measurement or a lucky
// geometry — **stranding is impossible by construction**:
//
//   **EVERY MOVE IN THIS ARCHIVE HAS AN INVERSE.**
//
//   1. **A step is invertible.** The only thing in the world that changes the
//      light is a hand on a beacon, and every beacon stands on the RIM, in
//      the bay it lights from. So while the party is walking a sill, nothing
//      can be changing — the sill they are on is still a sill when they get
//      off it, and the step straight back is always legal.
//   2. **A beacon press is invertible.** Pressing cycles one beacon through
//      DARK → its four settings → DARK, and the party is standing at the
//      beacon the whole time, so four more presses put it exactly back. A
//      five-cycle is its own undo.
//   3. **Nothing else edits the map.** Reading an effigy, drawing a slip,
//      taking the essence and finding the maxim change no sill at all. The
//      two edits that are one-way — the door-shutter at the entrance and the
//      rite opening the oculus stair — are purely ADDITIVE: a passage opens
//      and never closes, and an additive edit cannot shrink reachability.
//   4. **Solarin never touches the hall.** §7 wants the guardian to fight
//      WITH the planet's rule, and it does — but its glare is ARENA-LOCAL: it
//      lights wedges of its own floor and blinds what stands in them, and it
//      cannot kindle, douse, aim or pitch a single beacon out in the archive.
//      This is the one authoring decision the safety actually rests on, and
//      the counterfactual pins it (let Solarin reach the beacons and states
//      strand). The chamber is also a POCKET behind a phase-free stone stair,
//      so even its own floor cannot shut on the party.
//
//   A move relation in which every edge has an inverse makes reachability an
//   EQUIVALENCE: whatever the archive can put you into, it can take you out
//   of, and every reachable state can reach every other. That is the whole
//   proof, and `solveBeaconArchive` measures it anyway — **0 strandable of
//   the 1,125 states the world can put the party in, with no valve** — plus
//   the counterfactuals that say the safety is designed: make a kindled
//   beacon a RATCHET that cannot be doused (a very natural reading of "every
//   lumen you spend is seen") and the archive strands; let Solarin's glare
//   reach the rim beacons and it strands again; and take the two great stacks
//   out of the hall and the whole exposure star stops being winnable.
//
// Mechanic-ledger note (§5.5): Light claims **light-cone occlusion** — the
// shadow, not the beam, is the thing the player is aiming, and it is aimed by
// choosing what the light BREAKS ON — and **exposure management**, a live
// instantaneous reading of how much of the world is currently visible, which
// is neither Steam's spend-budget (nothing is consumed) nor Poison's triage
// (nothing is abandoned). Under those: **the road and the wall are the same
// object** — a lit cell is a floor on the glass and a wall on the mirror, so
// one act of light is always simultaneously a gift and a theft, without any
// zero-sum bookkeeping to make it so.
//
// VISUAL GRAMMAR (§5.5): Light's soft volumetric cones must read NOTHING like
// Lightning's jagged bolts, and nothing here is drawn as a stroke. A lit cell
// is a WEDGE — a filled fan of pale gold laid on the floor with a soft
// gradient along its length and a hard clean edge across its arc, because the
// edge of a shadow is the only sharp thing in this planet's vocabulary. A
// stack's shadow is drawn as the wedge's BITE: the fan simply stops, and the
// unlit shelf behind it is bare warm grey stone. Glass leaves glow from
// inside when lit and are drawn as an empty outline when not; mirror shelves
// are solid slate when dark and a flat sheet of white glare when lit. No
// bolts, no arcs, no rays, no lens flares — and no blur filters anywhere (the
// game's known jank source).

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

// ─────────────────────────────────────────────────────────
// THE HALL — sectors and bands
// ─────────────────────────────────────────────────────────

/// The five sectors of the one hall, clockwise from the door. Every room lies
/// in exactly one, and every sill is cut across exactly one, so the player can
/// read the whole archive off five words and two bands.
enum HallSector {
  /// 0 — the door bay. NOTHING stands in it, which is the lesson.
  door,

  /// 1 — the court bay. The first of the two great stacks stands here.
  court,

  /// 2 — the arcade bay. The second great stack.
  arcade,

  /// 3 — the shelf bay, out past the stacks.
  shelf,

  /// 4 — the ledger bay, and the long way round.
  ledger,
}

/// How far into the hall a cell lies. A beacon on the rim lights the RIM band
/// of every sector in its arc; whether it also lights the INWARD band is the
/// occlusion question.
enum HallBand {
  /// The outer walk, against the archive's wall. Always lit by any beam.
  rim,

  /// The inner shelf, toward the hall's heart. A stack in this sector keeps
  /// it dark unless the beam is pitched HIGH over the stack.
  inward,
}

/// One cell of the hall: five sectors × two bands = ten, and that is the whole
/// map's lighting state.
class HallCell {
  final HallSector sector;
  final HallBand band;
  const HallCell(this.sector, this.band);

  @override
  bool operator ==(Object other) =>
      other is HallCell && other.sector == sector && other.band == band;

  @override
  int get hashCode => Object.hash(sector, band);
}

/// The archive's own word for a sector, for hints and readings.
String sectorWord(HallSector s) => switch (s) {
  HallSector.door => 'the door bay',
  HallSector.court => 'the court bay',
  HallSector.arcade => 'the arcade',
  HallSector.shelf => 'the shelf bay',
  HallSector.ledger => 'the ledger bay',
};

/// THE TWO GREAT STACKS — and the only two things in the hall tall enough to
/// keep a shadow. Everything the planet can do it can do because these are
/// here, and the counterfactual in `solveBeaconArchive` measures what the
/// archive is without them.
const Set<HallSector> kGreatStacks = {HallSector.court, HallSector.arcade};

bool sectorHasStack(HallSector s) => kGreatStacks.contains(s);

// ─────────────────────────────────────────────────────────
// THE BEACONS
// ─────────────────────────────────────────────────────────

/// How high a beacon is thrown.
enum BeamPitch {
  /// The beam breaks on the stacks. In a stacked sector only the RIM band
  /// lights and the shelf behind stays in shadow — the occlusion the whole
  /// planet is built on, and the cheap setting.
  low,

  /// The beam clears the stacks and fills the sector to its INWARD band. It
  /// reaches further and it costs more, and it fills in the exact shadow the
  /// low beam was giving you.
  high,
}

/// One thing a beacon can be set to.
class BeamSetting {
  /// The sectors this cone covers. Authored as an arc of the hall, never as a
  /// path to a target — nothing in the Beacon Archive is aimed AT anything
  /// (that is Lightning's seat).
  final List<HallSector> arc;
  final BeamPitch pitch;

  /// One clause for the reading and the render.
  final String look;

  const BeamSetting({
    required this.arc,
    required this.pitch,
    required this.look,
  });

  bool covers(HallSector s) => arc.contains(s);

  /// Whether this cone reaches [cell] — the occlusion rule, stated once.
  bool reaches(HallCell cell) {
    if (!covers(cell.sector)) return false;
    if (cell.band == HallBand.rim) return true;
    return pitch == BeamPitch.high || !sectorHasStack(cell.sector);
  }
}

/// A beacon on the archive's rim.
///
/// AUTHORING RULE, and the first half of the no-strand proof: **every beacon
/// stands on the RIM, in a bay of the hall, and there is not one in the
/// heart.** The archive is lit from its edge inward, which is what makes the
/// heart a place where nothing can change under you — and it means the hand
/// that changes the world is always standing in the room it changes.
class Beacon {
  final String id;

  /// The bay it stands in. Always a rim bay.
  final String roomId;

  /// Where in [roomId] the pan sits (the kindle verb's reach).
  final Offset post;

  /// The sector it stands in.
  final HallSector sector;

  /// Its four settings, in the order one press walks them. State 0 is always
  /// DARK, so a press cycles DARK → 1 → 2 → 3 → 4 → DARK: a five-cycle, and
  /// four more presses put any setting back exactly where it was.
  final List<BeamSetting> settings;

  /// One clause of scenery.
  final String look;

  const Beacon({
    required this.id,
    required this.roomId,
    required this.post,
    required this.sector,
    required this.settings,
    required this.look,
  });

  /// How many states this beacon has, DARK included.
  int get stateCount => settings.length + 1;
}

/// The three beacons. Each covers a different reach of the hall and no two
/// can be pressed from the same bay, so which one you are willing to walk to
/// is as much of the decision as what you set it to.
const List<Beacon> kArchiveBeacons = [
  // THE NARTHEX BEACON. It stands in the doorway and is the only light that
  // reaches sector 1, so it is the only thing that opens the rim at all — and
  // sector 1 is where the reliquary's mirror shelf lies, which is the vault
  // trick in one object: the beam that lets you in takes the heart away.
  Beacon(
    id: 'bc_narthex',
    roomId: 'lumen_threshold',
    post: Offset(360, 250),
    sector: HallSector.door,
    settings: [
      BeamSetting(
        arc: [HallSector.court, HallSector.arcade],
        pitch: BeamPitch.low,
        look: 'a low fan across the court and the arcade',
      ),
      BeamSetting(
        arc: [HallSector.court, HallSector.arcade],
        pitch: BeamPitch.high,
        look: 'the same fan, thrown high over the stacks',
      ),
      BeamSetting(
        arc: [HallSector.door, HallSector.court],
        pitch: BeamPitch.low,
        look: 'a low fan back across the doorway',
      ),
      BeamSetting(
        arc: [HallSector.door, HallSector.court],
        pitch: BeamPitch.high,
        look: 'the doorway fan, thrown high',
      ),
    ],
    look: 'the narthex beacon, a brass pan on a tripod of black iron',
  ),
  // THE ORIEL BEACON, in the shadow court. The only light that can hold the
  // arcade on its own, which is what lets the party carry a single small lamp
  // out along the rim instead of the narthex's wide fan.
  Beacon(
    id: 'bc_oriel',
    roomId: 'shadow_court',
    post: Offset(430, 260),
    sector: HallSector.court,
    settings: [
      BeamSetting(
        arc: [HallSector.arcade],
        pitch: BeamPitch.low,
        look: 'one low blade across the arcade',
      ),
      BeamSetting(
        arc: [HallSector.arcade],
        pitch: BeamPitch.high,
        look: 'the arcade blade, thrown high',
      ),
      BeamSetting(
        arc: [HallSector.arcade, HallSector.shelf],
        pitch: BeamPitch.low,
        look: 'a low fan out to the shelves',
      ),
      BeamSetting(
        arc: [HallSector.arcade, HallSector.shelf],
        pitch: BeamPitch.high,
        look: 'the shelf fan, thrown high',
      ),
    ],
    look: 'the oriel beacon, set in the court\'s broken window',
  ),
  // THE LEDGER BEACON, at the far end of the rim. It is the reason the dark
  // stacks can be come at from BEHIND — set it, walk the whole heart in the
  // dark, and come up under the shelves with one lamp burning.
  Beacon(
    id: 'bc_ledger',
    roomId: 'catalogue_walk',
    post: Offset(400, 250),
    sector: HallSector.ledger,
    settings: [
      BeamSetting(
        arc: [HallSector.ledger],
        pitch: BeamPitch.low,
        look: 'one low blade down the ledger walk',
      ),
      BeamSetting(
        arc: [HallSector.ledger],
        pitch: BeamPitch.high,
        look: 'the ledger blade, thrown high',
      ),
      BeamSetting(
        arc: [HallSector.shelf, HallSector.ledger],
        pitch: BeamPitch.low,
        look: 'a low fan back along the shelves',
      ),
      BeamSetting(
        arc: [HallSector.shelf, HallSector.ledger],
        pitch: BeamPitch.high,
        look: 'the shelf fan, thrown high',
      ),
    ],
    look: 'the ledger beacon, a cracked lens on a copper stand',
  ),
];

Beacon? archiveBeaconById(String id) {
  for (final b in kArchiveBeacons) {
    if (b.id == id) return b;
  }
  return null;
}

Beacon? archiveBeaconIn(String roomId) {
  for (final b in kArchiveBeacons) {
    if (b.roomId == roomId) return b;
  }
  return null;
}

// ─────────────────────────────────────────────────────────
// SILLS — the hall's floor, in both states at once
// ─────────────────────────────────────────────────────────

/// What a sill is made of.
enum SillCut {
  /// A GLASS LEAF. The archive's floor is glass laid over its lightwells, and
  /// glass is nothing until there is light in it: lit, it is a floor; dark, it
  /// is a hole. Every sill around the RIM is one of these, so the rim is a
  /// road you build.
  glassLeaf,

  /// A MIRROR SILL. A shelf of the archive's black mirror-stone: plain
  /// walkable stone in the dark, and under light a sheet of glare nobody can
  /// walk into. Every sill into the HEART is one of these, so the heart is a
  /// road you must NOT light.
  mirrorSill,

  /// The one thing in the archive light has never reached: the oculus stair,
  /// cut in living stone under the overhang. Phase-free on purpose — see the
  /// header, reason 4.
  stone,
}

/// One sill of the hall, authored once and read from both ends.
///
/// The layout test enforces that EVERY door has a reciprocal door, statically
/// (§5.5 keeps that invariant for the whole game). A map whose connectivity
/// changes at runtime lives inside that rule the only honest way, the one
/// Crystal established and Plant, Spirit and Dark reused: **the doors are
/// constant and reciprocal, and what varies is whether there is anything to
/// walk on in the state the archive is currently in.**
class HallSill {
  final String id;
  final String from;
  final String to;
  final SillCut cut;

  /// The cell this sill lies in — the one whose light decides it. Null exactly
  /// when [cut] is [SillCut.stone].
  final HallCell? cell;

  /// One clause naming the sill, used by the blocked line and the render.
  final String look;

  const HallSill({
    required this.id,
    required this.from,
    required this.to,
    required this.cut,
    required this.look,
    this.cell,
  });

  bool joins(String a, String b) =>
      (from == a && to == b) || (from == b && to == a);
}

/// The whole hall as sills. Ten, and every room pair appears exactly once — so
/// a door and a sill are one-to-one and the no-strand proof cannot drift from
/// the floor the player actually walks.
///
/// Read the shape off the cuts: every RIM sill is glass (a road you light) and
/// every sill into the HEART is mirror (a road you must not), with the single
/// stone stair down to Solarin. That is the topology stated as data.
const List<HallSill> kArchiveSills = [
  // ── THE RIM · a ring of glass over the lightwells ─────
  // The lightwell, closing the ring back to the doorway. Sector 0 has nothing
  // standing in it, so lighting this leaf also floods the undercroft below and
  // cuts the heart off from the door — the archive's first hard trade.
  HallSill(
    id: 'sl_lightwell',
    from: 'lumen_threshold',
    to: 'catalogue_walk',
    cut: SillCut.glassLeaf,
    cell: HallCell(HallSector.door, HallBand.rim),
    look: 'the lightwell leaf',
  ),
  // The narthex leaf — the only way onto the rim, and the beam that lights it
  // is the beam that shuts the reliquary. See the header's vault trick.
  HallSill(
    id: 'sl_narthex',
    from: 'lumen_threshold',
    to: 'shadow_court',
    cut: SillCut.glassLeaf,
    cell: HallCell(HallSector.court, HallBand.rim),
    look: 'the narthex leaf',
  ),
  HallSill(
    id: 'sl_arcade',
    from: 'shadow_court',
    to: 'moth_gallery',
    cut: SillCut.glassLeaf,
    cell: HallCell(HallSector.arcade, HallBand.rim),
    look: 'the arcade leaf',
  ),
  HallSill(
    id: 'sl_stackwalk',
    from: 'moth_gallery',
    to: 'dark_stacks',
    cut: SillCut.glassLeaf,
    cell: HallCell(HallSector.shelf, HallBand.rim),
    look: 'the stack-walk leaf',
  ),
  HallSill(
    id: 'sl_ledger',
    from: 'dark_stacks',
    to: 'catalogue_walk',
    cut: SillCut.glassLeaf,
    cell: HallCell(HallSector.ledger, HallBand.rim),
    look: 'the ledger leaf',
  ),
  // The down-step: the ledger walk's floor falls away inward into the reading
  // floor, and the fall is glass too. This is the back door into the heart,
  // and the only lit way in.
  HallSill(
    id: 'sl_downstep',
    from: 'catalogue_walk',
    to: 'reading_floor',
    cut: SillCut.glassLeaf,
    cell: HallCell(HallSector.ledger, HallBand.inward),
    look: 'the down-step',
  ),

  // ── THE HEART · black mirror-stone ────────────────────
  // The undercroft, straight in from the door. Sector 0 is empty, so any light
  // at all in the doorway glares this shut.
  HallSill(
    id: 'sl_undercroft',
    from: 'lumen_threshold',
    to: 'oculus_stair',
    cut: SillCut.mirrorSill,
    cell: HallCell(HallSector.door, HallBand.inward),
    look: 'the undercroft shelf',
  ),
  // THE HEARTWAY — the vault's one sill (§5.5). A shelf of mirror-stone in
  // sector 1, walkable exactly while sector 1's inward band is dark. The
  // reliquary is in plain sight from here in every state; it is the FLOOR
  // that comes and goes.
  HallSill(
    id: 'sl_heartway',
    from: 'oculus_stair',
    to: 'sunless_reliquary',
    cut: SillCut.mirrorSill,
    cell: HallCell(HallSector.court, HallBand.inward),
    look: 'the heartway shelf',
  ),
  HallSill(
    id: 'sl_slype',
    from: 'oculus_stair',
    to: 'reading_floor',
    cut: SillCut.mirrorSill,
    cell: HallCell(HallSector.arcade, HallBand.inward),
    look: 'the slype',
  ),

  // ── THE ONE PASSAGE LIGHT NEVER REACHES ───────────────
  HallSill(
    id: 'sl_oculus',
    from: 'reading_floor',
    to: 'solarin_oculus',
    cut: SillCut.stone,
    look: 'the oculus stair',
  ),
];

/// The sill joining these two rooms, or null. One pair, one sill — pinned by
/// the tests.
HallSill? archiveSillBetween(String a, String b) {
  for (final s in kArchiveSills) {
    if (s.joins(a, b)) return s;
  }
  return null;
}

// ─────────────────────────────────────────────────────────
// STAR 0 — THE SHADOW COURT
// ─────────────────────────────────────────────────────────

/// One of the four effigies standing round the shadow court's balustrade.
///
/// §6: *statues claim doors, but a statue's SHADOW shows its true shape.* The
/// stone is a lie and the shadow is not, so an effigy can only be read while
/// the effigy itself STANDS IN LIGHT and the niche it throws its shadow into
/// stands in SHADOW. That is the planet's own rule at object scale — light and
/// occlusion in one act — and it is why this star is the tutorial for
/// everything else in the archive.
///
/// Star 0 is the planet's FIRST-DESCENT star (§4): it is earnable by ANY trio
/// of Light/Crystal/Spirit, uses all three elements at full power, and needs
/// nothing unlocked. §6 put a Crystalmask gate (the beam-split) on this
/// planet's FIRST star; **§4's first-descent guarantee wins**, so that gate has
/// moved onto the rite's prism oriel — exactly as Plant moved its Plantmane
/// gate onto the rood screen and Dark its Darkmask gate onto the reredos.
class Effigy {
  final String id;

  /// Where it stands in the court (the read verb's reach).
  final Offset position;

  /// The cell the effigy itself must be standing in the light of.
  final HallCell stand;

  /// The cell its shadow is thrown into. It must be DARK, or there is no
  /// shadow to read and the stone keeps its lie.
  final HallCell niche;

  /// The element that reads it. Element-only (§4) — any family, full power.
  /// All three of the planet's entry elements appear, so the ideal trio is
  /// not required and any correct-element party finishes the court.
  final String element;

  /// What the stone claims to be, and what the shadow says it is. Flavour for
  /// the reading and the render — the truth is never a puzzle input.
  final String stone;
  final String truth;

  const Effigy({
    required this.id,
    required this.position,
    required this.stand,
    required this.niche,
    required this.element,
    required this.stone,
    required this.truth,
  });
}

/// The four effigies, in the order the balustrade carries them (they may be
/// read in any order — nothing here is a sequence; Fire owns that seat).
///
/// The set is authored so that **no single arrangement of the beacons reads
/// all four**, which is what makes Star 0 a journey rather than a button. The
/// guarantee is structural rather than tuned: the moth wants sector 0's inward
/// band DARK and the sun wants sector 0's rim LIT, and sector 0 has nothing
/// standing in it — so its two bands go together, always, and those two
/// effigies are mutually exclusive by the absence of a stack. The test pins it.
const List<Effigy> kCourtEffigies = [
  Effigy(
    id: 'ef_moth',
    position: Offset(190, 190),
    stand: HallCell(HallSector.court, HallBand.rim),
    niche: HallCell(HallSector.door, HallBand.inward),
    element: 'Light',
    stone: 'a moth with its wings shut',
    truth: 'the shadow has them open, and it is enormous',
  ),
  Effigy(
    id: 'ef_key',
    position: Offset(330, 160),
    stand: HallCell(HallSector.arcade, HallBand.rim),
    niche: HallCell(HallSector.court, HallBand.inward),
    element: 'Crystal',
    stone: 'a scholar holding a key',
    truth: 'the shadow is holding a knife',
  ),
  Effigy(
    id: 'ef_warden',
    position: Offset(470, 190),
    stand: HallCell(HallSector.ledger, HallBand.rim),
    niche: HallCell(HallSector.arcade, HallBand.inward),
    element: 'Spirit',
    stone: 'a warden facing the door',
    truth: 'the shadow is facing the other way',
  ),
  Effigy(
    id: 'ef_sun',
    position: Offset(330, 300),
    stand: HallCell(HallSector.door, HallBand.rim),
    niche: HallCell(HallSector.ledger, HallBand.inward),
    element: 'Light',
    stone: 'a sun on a pole',
    truth: 'the shadow of it is a hole',
  ),
];

Effigy? courtEffigyById(String id) {
  for (final e in kCourtEffigies) {
    if (e.id == id) return e;
  }
  return null;
}

// ─────────────────────────────────────────────────────────
// STAR 1 — THE DARK STACKS
// ─────────────────────────────────────────────────────────

/// The archive's HUSH: the most light the reading will bear, in lumens.
///
/// This is not a budget (Steam owns that seat and nothing here is spent — put
/// a beacon out and the lumens come straight back). It is an instantaneous
/// reading of how much of the hall is currently visible, and the archive
/// simply will not be read while more than this is burning.
///
/// Two is chosen against the geometry, not by feel: a stacked sector at low
/// pitch costs ONE lumen and an empty sector costs TWO, so a hush of two is
/// exactly "one small lamp, and it had better be breaking on a stack."
const int kArchiveHush = 2;

/// A slip lodged in the dark behind the shelves — §6's Dark Stacks.
///
/// Star 1 is the exposure star. Each slip lies in a bay that CANNOT be reached
/// with the archive dark, so the party must light a road to it — and it cannot
/// be drawn unless the whole hall is under the hush when they get there. Light
/// is both the road and the alarm, and the star is the smallest light that is
/// still a road (§5.5's strategic question, scored).
///
/// The one hard family gate on this star (§4: max one per star) is a **Spirit
/// PIP** — small enough to go behind the shelves, and at home in the unlit
/// dark. §6 declared exactly this candidate.
class HushSlip {
  final String id;

  /// The bay it lies in, and where in it.
  final String roomId;
  final Offset position;

  /// One clause of what the slip says, for the popup and the render.
  final String line;

  const HushSlip({
    required this.id,
    required this.roomId,
    required this.position,
    required this.line,
  });
}

/// The three slips. Every one of them is in a bay that is unreachable with the
/// archive dark, and the three are deliberately NOT all reachable under the
/// hush by the same plan: the court and the gallery fall to one narrow low fan
/// off the narthex beacon, and the shelves do not — the only way under the
/// hush at the stacks is to set the ledger beacon first, walk the whole heart
/// in the dark, and come up at them from BEHIND. That is the run's real
/// decision, and the proof measures it.
const List<HushSlip> kArchiveSlips = [
  HushSlip(
    id: 'slip_court',
    roomId: 'shadow_court',
    position: Offset(120, 330),
    line: 'a shelf-slip, in a hand that stopped mid-word',
  ),
  HushSlip(
    id: 'slip_gallery',
    roomId: 'moth_gallery',
    position: Offset(650, 200),
    line: 'a shelf-slip, gnawed at one corner',
  ),
  HushSlip(
    id: 'slip_stacks',
    roomId: 'dark_stacks',
    position: Offset(150, 400),
    line: 'a shelf-slip, and the ink on it is still wet',
  ),
];

HushSlip? archiveSlipById(String id) {
  for (final s in kArchiveSlips) {
    if (s.id == id) return s;
  }
  return null;
}

List<HushSlip> archiveSlipsIn(String roomId) => [
  for (final s in kArchiveSlips)
    if (s.roomId == roomId) s,
];

// ─────────────────────────────────────────────────────────
// THE LIVE STATE — pure rules, no Flutter, no engine
// ─────────────────────────────────────────────────────────

/// Everything the Beacon Archive tracks for one run.
///
/// Kept deliberately small: this planet's whole difficulty is a REACHABILITY
/// question and an EXPOSURE question, so the state is what those two depend on
/// — what each beacon is set to — plus the per-star tallies.
class BeaconArchive {
  BeaconArchive() {
    reset();
  }

  /// What each beacon is set to, keyed by [Beacon.id]: 0 is DARK and 1..4
  /// index into its settings. This IS the map, and it is the exposure meter
  /// too; everything else is derived.
  final Map<String, int> lamp = {};

  /// Effigies whose shadow has been read (Star 0).
  final Set<String> effigiesRead = {};

  /// Slips drawn out of the dark (Star 1).
  final Set<String> slipsDrawn = {};

  /// True while a crossing that has not shown a single lumen is still alive
  /// (the Lost Maxim). Armed at the door in total darkness, killed by any
  /// light at all, paid off at the reliquary.
  bool hushWalk = false;
  bool hushWalked = false;

  /// Seconds left on the last kindle's bloom. Purely visual, and named here so
  /// the render has nowhere else to keep it.
  double bloom = 0;

  /// Where Solarin is looking, in radians. ARENA-LOCAL and deliberately not
  /// part of the hall's lighting at all — the mystic's glare never reaches a
  /// beacon, which is the one authoring decision the no-strand proof rests on
  /// (see the header, reason 4).
  double glare = 0;

  /// How many lumens the archive has shown at once, at its worst. The
  /// readout's second line, and the closest thing this planet has to a bill.
  int worstLumens = 0;

  /// The archive as its keepers left it: the narthex beacon thrown HIGH across
  /// the court and the arcade — blazing, four lumens, twice the hush — and
  /// everything else out. The doorway is dark, so the undercroft into the
  /// heart is open; the court is lit, so the rim is open too — and both the
  /// heartway onto the reliquary and the slype are glared shut by the very
  /// beam that opened the rim. The first thing the archive teaches is that the
  /// same beam thrown LOWER costs half as much and gives the shelves back.
  void reset() {
    lamp
      ..clear()
      ..['bc_narthex'] = 2
      ..['bc_oriel'] = 0
      ..['bc_ledger'] = 0;
    effigiesRead.clear();
    slipsDrawn.clear();
    hushWalk = false;
    hushWalked = false;
    bloom = 0;
    glare = 0;
    worstLumens = 0;
  }

  // ── The light ─────────────────────────────────────────

  /// What [beaconId] is set to right now, or null while it is dark.
  BeamSetting? settingOf(String beaconId) {
    final b = archiveBeaconById(beaconId);
    if (b == null) return null;
    final i = lamp[beaconId] ?? 0;
    if (i <= 0 || i > b.settings.length) return null;
    return b.settings[i - 1];
  }

  bool isKindled(String beaconId) => settingOf(beaconId) != null;

  /// Whether [cell] is lit: some kindled beacon's cone reaches it. Two cones
  /// can cover the same sector at different pitches — the HIGH one wins, which
  /// is the deeper lesson of the planet: a shadow is only a shadow while
  /// nothing else is throwing light past it.
  bool isLit(HallCell cell) {
    for (final b in kArchiveBeacons) {
      final s = settingOf(b.id);
      if (s != null && s.reaches(cell)) return true;
    }
    return false;
  }

  bool isDark(HallCell cell) => !isLit(cell);

  /// Every cell of the hall, in reading order.
  static const List<HallCell> allCells = [
    HallCell(HallSector.door, HallBand.rim),
    HallCell(HallSector.door, HallBand.inward),
    HallCell(HallSector.court, HallBand.rim),
    HallCell(HallSector.court, HallBand.inward),
    HallCell(HallSector.arcade, HallBand.rim),
    HallCell(HallSector.arcade, HallBand.inward),
    HallCell(HallSector.shelf, HallBand.rim),
    HallCell(HallSector.shelf, HallBand.inward),
    HallCell(HallSector.ledger, HallBand.rim),
    HallCell(HallSector.ledger, HallBand.inward),
  ];

  /// THE EXPOSURE METER: how many cells of the hall are lit right now. Not a
  /// budget — it goes up and it comes straight back down — but every lumen of
  /// it is something the moth-wardens can see, and the archive will not be
  /// read above [kArchiveHush].
  int get lumens {
    var n = 0;
    for (final c in allCells) {
      if (isLit(c)) n++;
    }
    return n;
  }

  bool get underHush => lumens <= kArchiveHush;

  /// Press a beacon: it walks DARK → 1 → 2 → 3 → 4 → DARK. A five-cycle, and
  /// the party is standing at it the whole time — reason 2 of the no-strand
  /// proof, and the reason this planet needs no valve.
  ///
  /// Returns the new setting, or null when the beacon has just gone out.
  BeamSetting? press(String beaconId) {
    final b = archiveBeaconById(beaconId);
    if (b == null) return null;
    final next = ((lamp[beaconId] ?? 0) + 1) % b.stateCount;
    lamp[beaconId] = next;
    final l = lumens;
    if (l > worstLumens) worstLumens = l;
    if (l > 0) hushWalk = false;
    return settingOf(beaconId);
  }

  // ── The map, in the state the archive is in ───────────

  /// Whether [sill] is a floor right now. A glass leaf is a floor while its
  /// cell is lit; a mirror shelf while its cell is dark; the oculus stair
  /// always.
  bool sillOpen(HallSill sill) => switch (sill.cut) {
    SillCut.stone => true,
    SillCut.glassLeaf => isLit(sill.cell!),
    SillCut.mirrorSill => isDark(sill.cell!),
  };

  // ── Star 0 ────────────────────────────────────────────

  bool get courtRead => effigiesRead.length >= kCourtEffigies.length;

  /// Whether [e]'s shadow can be read in the arrangement the archive is in:
  /// the stone in light, and the niche it throws into in shadow.
  bool canRead(Effigy e) =>
      !effigiesRead.contains(e.id) && isLit(e.stand) && isDark(e.niche);

  // ── Star 1 ────────────────────────────────────────────

  bool get everySlipDrawn => slipsDrawn.length >= kArchiveSlips.length;
}

// ─────────────────────────────────────────────────────────
// PER-ROOM HALL CONTENT
// ─────────────────────────────────────────────────────────

/// Everything the Beacon Archive put in one bay. Carried on
/// `DungeonRoom.hall` so exactly one field had to be added to the shared room
/// model, and so a bay's star index and its SECTOR are visible to the layout
/// invariants and to the proof.
class ArchiveHall {
  /// The sector this bay lies in. Required — the whole planet is this.
  final HallSector sector;

  /// The star this bay banks (null = a bay that only holds light).
  final int? starIndex;

  /// The entry rite: the archive's door-shutter, folded across the doorway.
  /// Element-only Light (§4).
  final Offset? doorShutter;

  /// Star 0: the court's balustrade, and the four effigies standing on it.
  final Offset? balustrade;

  /// The rite's shutter-ring — element-only Light with **Crystal+Spirit→Light**
  /// as the braid, and the module latches `conduitEnergy['B']` itself.
  ///
  /// The reading floor's other half is conduit 'A', the prism oriel, which is
  /// the planet's Crystal+MASK gate. Authoring the ring as a family-less
  /// Conduit would let the engine's channel verb step over it — the same
  /// reason Ice left its cold font out, Dust its great glass, Plant its
  /// sepulchre and Dark its snuffer.
  final Offset? shutterRing;

  /// Solarin's arena pillars: the three things in the chamber tall enough to
  /// keep a shadow, and the only places its glare does not reach (§7 — the
  /// guardian fights WITH the planet's rule).
  final List<Offset> gazePillars;

  const ArchiveHall({
    required this.sector,
    this.starIndex,
    this.doorShutter,
    this.balustrade,
    this.shutterRing,
    this.gazePillars = const [],
  });
}

/// Every bay's sector, derived from the layout so the module, the render and
/// the proof can never disagree about which sector a room is in.
Map<String, HallSector> archiveSectorOfRoom(DungeonLayout layout) => {
  for (final e in layout.rooms.entries)
    if (e.value.hall != null) e.key: e.value.hall!.sector,
};

// ─────────────────────────────────────────────────────────
// THE LAYOUT
// ─────────────────────────────────────────────────────────

/// Solarin — the Beacon Archive.
const DungeonLayout lightLayout = DungeonLayout(
  element: 'Light',
  entranceRoomId: 'lumen_threshold',
  entranceSpawn: Offset(120, 250),
  title: 'THE BEACON ARCHIVE',
  descentTitle: 'Solarin Archive',
  stars: [
    DungeonStarSpec(
      name: 'Shadow Star',
      earnAnnouncement:
          'The Shadow Star is yours — four stones read by what they throw, '
          'and never two of them in the same light',
    ),
    DungeonStarSpec(
      name: 'Hush Star',
      earnAnnouncement:
          'The Hush Star is yours — three slips drawn, and the archive never '
          'saw you take one',
    ),
    DungeonStarSpec(name: 'Corona Star'),
  ],
  // The archive's own shutter is folded across the doorway until a Light hand
  // draws it back.
  entranceRevealDoor: DungeonDoorRef('lumen_threshold', 'shadow_court'),
  finaleDoor: DungeonDoorRef('reading_floor', 'solarin_oculus'),
  riteAnnouncement:
      'Shadow and Hush are won — the oriel splits, and the stair under the '
      'oculus stops being a stair down to nothing',
  finaleSealedHint:
      'The stair is shut — it answers only the Shadow and Hush stars',
  guardianSealedHint:
      'Nothing under the oculus wakes while the reading floor is still half '
      'in the dark',
  mercyShrineRoomId: 'moth_gallery',
  // Ideal: Lightmask · Crystalmask · Spiritpip — hinted by VERB, never body
  // part (§4): a light that can be small, second sight, and what my smallest
  // doors admit.
  riddle: [
    'Send me a Light — I am read in the dark, and my wardens count every lumen you spend;',
    'a Crystal MASK, to split my one shaft in two;',
    'and a Spirit PIP, because everything worth having lies behind my shelves.',
  ],
  // §4 budget: TWO hard gates, on two different objects and two different
  // entry slots, and never two on one star. Star 0 (the shadow court) is
  // deliberately UNGATED and uses all three elements at full power, so any
  // trio of Light/Crystal/Spirit progresses on a first descent — §6 put a
  // Crystalmask gate (the beam-split) on this planet's FIRST star, and §4's
  // first-descent guarantee wins, so that gate moved onto the rite's prism
  // oriel. The beacons themselves — the planet's whole verb — are element-only
  // Light and always available: an archive you cannot re-light is a softlock,
  // so the light verb is never gated, never one-way, and never on a cooldown.
  familyGates: [
    DungeonFamilyGate(
      objectId: 'hush_slip',
      element: 'Spirit',
      family: 'Pip',
      hintLine:
          'Only a Spirit small enough to go behind the shelves reaches this',
    ),
    DungeonFamilyGate(
      objectId: 'A',
      element: 'Crystal',
      family: 'Mask',
      hintLine: 'Only a Crystal with second sight splits this oriel\'s beam',
    ),
  ],
  rooms: {
    // ── THE LUMEN THRESHOLD (entrance · sector 0) ─────────
    // The doorway, and the whole grammar of the archive in one bay: three ways
    // out of it, and they are of all three kinds. The lightwell leaf west and
    // the narthex leaf east are glass — roads you build. The undercroft south
    // is mirror-stone — a road you must NOT light. And sector 0 has nothing
    // standing in it, so any beam that opens the lightwell also glares the
    // undercroft shut. The player learns the planet here without being told
    // anything.
    'lumen_threshold': DungeonRoom(
      id: 'lumen_threshold',
      bounds: Rect.fromLTWH(0, 0, 720, 480),
      walls: [
        Rect.fromLTWH(250, 80, 200, 26), // the fallen lintel
      ],
      doors: [
        // The narthex leaf, east onto the rim (glass, court · rim).
        DungeonDoor(
          rect: Rect.fromLTWH(696, 185, 24, 110),
          targetRoomId: 'shadow_court',
          targetSpawn: Offset(60, 260),
        ),
        // The lightwell leaf, west round to the ledger walk (glass, door·rim).
        DungeonDoor(
          rect: Rect.fromLTWH(0, 185, 24, 110),
          targetRoomId: 'catalogue_walk',
          targetSpawn: Offset(660, 250),
        ),
        // The undercroft, straight in to the heart (mirror, door · inward).
        DungeonDoor(
          rect: Rect.fromLTWH(305, 456, 110, 24),
          targetRoomId: 'oculus_stair',
          targetSpawn: Offset(360, 120),
        ),
      ],
      hall: ArchiveHall(sector: HallSector.door, doorShutter: Offset(620, 240)),
    ),

    // ── THE SHADOW COURT (Star 0 · sector 1) ──────────────
    // The court under the first great stack. The balustrade carries the four
    // effigies, and one of the three slips lies where the court's shelving
    // fell in. The court has no way out but glass, so it is a place you have
    // to keep lit to be in — and the star in it asks you to make shadows while
    // you stand in light, which is the archive's thesis.
    'shadow_court': DungeonRoom(
      id: 'shadow_court',
      bounds: Rect.fromLTWH(0, 0, 700, 460),
      walls: [
        Rect.fromLTWH(520, 250, 150, 28), // the toppled case
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 205, 24, 110),
          targetRoomId: 'lumen_threshold',
          targetSpawn: Offset(640, 240),
        ),
        // The arcade leaf, on round the rim (glass, arcade · rim).
        DungeonDoor(
          rect: Rect.fromLTWH(676, 175, 24, 110),
          targetRoomId: 'moth_gallery',
          targetSpawn: Offset(60, 250),
        ),
      ],
      hall: ArchiveHall(
        sector: HallSector.court,
        starIndex: 0,
        balustrade: Offset(330, 230),
      ),
    ),

    // ── THE MOTH GALLERY (mercy shrine · sector 2) ────────
    // Under the second great stack, where the wardens roost. Two glass leaves
    // and nothing else: the gallery is a bay you can only be in while a light
    // is holding it, which is exactly why the shrine is here.
    'moth_gallery': DungeonRoom(
      id: 'moth_gallery',
      bounds: Rect.fromLTWH(0, 0, 800, 500),
      walls: [
        Rect.fromLTWH(340, 240, 180, 28), // a run of empty shelving
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 195, 24, 110),
          targetRoomId: 'shadow_court',
          targetSpawn: Offset(640, 235),
        ),
        // The stack-walk leaf (glass, shelf · rim).
        DungeonDoor(
          rect: Rect.fromLTWH(776, 195, 24, 110),
          targetRoomId: 'dark_stacks',
          targetSpawn: Offset(60, 260),
        ),
      ],
      hall: ArchiveHall(sector: HallSector.arcade),
    ),

    // ── THE DARK STACKS (Star 1 · sector 3) ───────────────
    // §6's Dark Stacks, out past both great stacks where nothing occludes for
    // you any more. Its slip is the run's hard one: sector 3 is empty, so a
    // beam that opens the stack-walk from the gallery side lights two cells at
    // once and blows the hush — the only way in under two lumens is the ledger
    // beacon set beforehand and the whole dark heart walked to get behind it.
    'dark_stacks': DungeonRoom(
      id: 'dark_stacks',
      bounds: Rect.fromLTWH(0, 0, 780, 520),
      walls: [
        Rect.fromLTWH(300, 250, 200, 30), // the collapsed stack
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 205, 24, 110),
          targetRoomId: 'moth_gallery',
          targetSpawn: Offset(720, 250),
        ),
        // The ledger leaf (glass, ledger · rim).
        DungeonDoor(
          rect: Rect.fromLTWH(756, 205, 24, 110),
          targetRoomId: 'catalogue_walk',
          targetSpawn: Offset(60, 250),
        ),
      ],
      hall: ArchiveHall(sector: HallSector.shelf, starIndex: 1),
    ),

    // ── THE CATALOGUE WALK (sector 4) ─────────────────────
    // The far end of the rim, and the ledger beacon on it. Three ways out and
    // every one of them glass: the ledger leaf back along the rim, the
    // lightwell home to the door, and the down-step inward into the reading
    // floor — the only LIT way into the heart there is.
    'catalogue_walk': DungeonRoom(
      id: 'catalogue_walk',
      bounds: Rect.fromLTWH(0, 0, 760, 500),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 195, 24, 110),
          targetRoomId: 'dark_stacks',
          targetSpawn: Offset(700, 260),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(736, 195, 24, 110),
          targetRoomId: 'lumen_threshold',
          targetSpawn: Offset(60, 240),
        ),
        // The down-step, inward (glass, ledger · inward).
        DungeonDoor(
          rect: Rect.fromLTWH(325, 476, 110, 24),
          targetRoomId: 'reading_floor',
          targetSpawn: Offset(120, 150),
        ),
      ],
      hall: ArchiveHall(sector: HallSector.ledger),
    ),

    // ── THE OCULUS STAIR (the heart · sector 0) ───────────
    // The hall's middle, and the one bay whose every way out is mirror-stone.
    // No beacon stands here and no beacon ever will (see the header): the
    // archive is lit from its rim inward, so nothing in the heart can change
    // the light, and the heart is therefore a place where the floor you walked
    // in on is still the floor when you turn round.
    'oculus_stair': DungeonRoom(
      id: 'oculus_stair',
      bounds: Rect.fromLTWH(0, 0, 720, 480),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(305, 0, 110, 24),
          targetRoomId: 'lumen_threshold',
          targetSpawn: Offset(360, 400),
        ),
        // The heartway, east onto the reliquary (mirror, court · inward).
        DungeonDoor(
          rect: Rect.fromLTWH(696, 185, 24, 110),
          targetRoomId: 'sunless_reliquary',
          targetSpawn: Offset(60, 170),
        ),
        // The slype, on into the reading floor (mirror, arcade · inward).
        DungeonDoor(
          rect: Rect.fromLTWH(305, 456, 110, 24),
          targetRoomId: 'reading_floor',
          targetSpawn: Offset(400, 130),
        ),
      ],
      hall: ArchiveHall(sector: HallSector.door),
    ),

    // ── THE SUNLESS RELIQUARY (the vault · sector 1) ──────
    // §5.5's trick: it stands in PLAIN SIGHT. There is no wall between this
    // shrine and the rest of the hall and there never was — the player can see
    // the essence burning on it from the doorway on the first descent. What
    // comes and goes is the FLOOR: the heartway is mirror-stone in sector 1,
    // and sector 1 is the one sector the rim cannot be opened without. Put
    // everything out and walk here in the dark, which is also how the maxim is
    // earned (§6).
    //
    // It is a POCKET — one sill, and only the light out on the rim can close
    // it, which nothing in here can change. That is what keeps the trick from
    // being a trap (Ice's shelf rule).
    'sunless_reliquary': DungeonRoom(
      id: 'sunless_reliquary',
      bounds: Rect.fromLTWH(0, 0, 440, 340),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 105, 24, 110),
          targetRoomId: 'oculus_stair',
          targetSpawn: Offset(640, 240),
        ),
      ],
      vaultCache: Offset(260, 170),
      hall: ArchiveHall(sector: HallSector.court),
    ),

    // ── THE READING FLOOR (the rite · sector 2) ───────────
    // Conduit A is the planet's Crystal+MASK gate — the PRISM ORIEL, which
    // gives one beam to a sight that only reads what is already shown and two
    // to a sight that does not. The floor's own half is the SHUTTER-RING:
    // §6's remote kindling, element-only Light with **Crystal+Spirit→Light**
    // authored as the braid for a party whose Light hand is down. The module
    // latches `conduitEnergy['B']` itself.
    'reading_floor': DungeonRoom(
      id: 'reading_floor',
      bounds: Rect.fromLTWH(0, 0, 800, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(345, 0, 110, 24),
          targetRoomId: 'oculus_stair',
          targetSpawn: Offset(360, 400),
        ),
        // Back up the down-step, out to the ledger walk (glass).
        DungeonDoor(
          rect: Rect.fromLTWH(0, 115, 24, 110),
          targetRoomId: 'catalogue_walk',
          targetSpawn: Offset(380, 400),
        ),
        // The oculus stair — the one passage light has never reached.
        DungeonDoor(
          rect: Rect.fromLTWH(345, 516, 110, 24),
          targetRoomId: 'solarin_oculus',
          targetSpawn: Offset(450, 150),
        ),
      ],
      conduits: [
        Conduit(
          id: 'A',
          position: Offset(250, 280),
          requireElement: 'Crystal',
          requiredFamily: DungeonAbility.insight,
        ),
      ],
      hall: ArchiveHall(
        sector: HallSector.arcade,
        shutterRing: Offset(560, 280),
      ),
    ),

    // ── SOLARIN'S OCULUS (Star 2 · sector 2) ──────────────
    // §7 — the mystic fights WITH the planet's rule. Solarin is wounded light:
    // it BLINDS wherever it looks, sweeping a cone across its own floor, and
    // its lull exists only for a party standing in the shadow one of the three
    // pillars is throwing. Occlusion, at the scale of a fight.
    //
    // What it deliberately does NOT do is touch the archive outside. Its glare
    // cannot kindle, douse, aim or pitch a beacon, so nothing out in the hall
    // can move while the party is down here — and the chamber is a POCKET
    // behind the phase-free stone stair besides. That pair of decisions is the
    // one thing the no-strand proof actually rests on, and the counterfactual
    // pins it.
    'solarin_oculus': DungeonRoom(
      id: 'solarin_oculus',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'reading_floor',
          targetSpawn: Offset(400, 420),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(450, 300),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Light',
          mysticId: 'Solarin',
          canCalm: true,
          canDefeat: true,
        ),
      ),
      hall: ArchiveHall(
        sector: HallSector.arcade,
        gazePillars: [Offset(200, 430), Offset(450, 500), Offset(700, 430)],
      ),
    ),
  },
);
