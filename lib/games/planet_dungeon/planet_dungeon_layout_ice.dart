// lib/games/planet_dungeon/planet_dungeon_layout_ice.dart
//
// GLACIUS — the Frozen Observatory. Ice's authored layout + the puzzle DATA
// its `part of planet_dungeon_game.dart` module reasons about.
//
// TOPOLOGY (docs/dungeons.md §5.5, structural assignment table): a VERTICAL
// SHAFT. There is no hub and there are no wings. The observatory is a throat
// cut down through the glacier, and the rooms are the LEVELS of it:
//
//     rime_head  (L0, the mouth)        ── the throat ──┐
//        │ flue A ──► shelf_glass  (the vault)          │
//     mirror_gallery (L1, Star 1)                       │ (one-way plunge)
//        │ flue B ──► shelf_lens   (the 13th telescope) │
//     orrery_floor  (L2, Star 0)                        │
//        │ flue C                                       │
//     cold_sump  (the bottom, mercy)  ◄─────────────────┘
//        │  the RIMEFALL climbs back to the mouth
//     star_font (the rite) → frowyrm_hollow (Star 2 · MYS09 Frowyrm)
//
// WORLD RULE — *the shaft only goes down; the way back up is whatever you
// froze on the way.* Every level is joined to the next by a FLUE: a chute of
// snow with meltwater running under it. A flue is, per run, exactly one of
// three things, and the player chooses which:
//
//   • DRIFT (untouched) — ride it and the fresh snow BRAKES you: it sets you
//     down on the flue's SHELF, a pocket off the throat that nothing can
//     climb to. Ice, standing at its head, can instead FREEZE it.
//   • STAIR (frozen) — a two-way ladder, permanent for the run. A stair has
//     no fall, so its SHELF is sealed away for good.
//   • SCOURED (ridden once) — the ride cut the snow away to polished ice.
//     It still drops you (past the shelf now, onto the level floor) and frost
//     will never key onto it again: a scoured flue is one-way forever.
//
// THE STRATEGIC QUESTION (§5.5): *the treasure or the ladder.* Each flue is
// either the way back up or the only way into its shelf — never both — and
// you must decide at its head, on the way down, before you know what is
// below. That is the whole planet.
//
// THE VAULT TRICK (§5.5): the cache sits on flue A's shelf. It is **visible
// only in a mirror** — from the gallery below, the still pool shows the
// shelf's glow hanging in the reflected shaft though the wall itself is
// blank — and **enterable only from a slide you can't repeat**: the drift
// catches you once and is scoured by its own ride.
//
// THE ANTI-STRAND VALVE (and the one place this file deviates from a literal
// reading of the brief — see the module's `solveShaftDescent`): at the very
// bottom stands the RIMEFALL, the melt-fall's own throat. Ice freezes it from
// below — always, at any time — into one long stair back to the mouth, and
// the moment you step off the top the whole shaft THAWS BACK TO ITS OPENING
// STATE: every stair you built is gone, every flue is drift again. It is a
// do-over, not a shortcut, and it is what makes "one-way descent" survivable
// instead of a stranding machine.
//
// Mechanic-ledger note (§5.5): Ice claims *one-way-descent route planning*.
// The freezes look like Air's irreversible wind-authoring and are deliberately
// NOT that — Air's gales are permanent world edits whose ORDER is the whole
// question; Ice's are undone wholesale by the sump, and the question is not
// order but GRAVITY: what you can still get back to. No global numeric budget
// is spent anywhere (that seat is Steam's).

import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

// ─────────────────────────────────────────────────────────
// THE SHAFT — flues
// ─────────────────────────────────────────────────────────

/// What a flue is right now. See the file header for the trade this encodes.
enum RimeFlueState {
  /// Untouched snow. Rides to the SHELF; Ice can freeze it into a stair.
  drift,

  /// Ridden once — bare polished ice. Rides past the shelf to the level
  /// floor, and takes no frost ever again.
  scoured,

  /// Frozen into a two-way stair. Cannot be ridden, so its shelf is sealed.
  stair,
}

/// One chute of the shaft: the head you stand at, the floor it drops to, and
/// (for the two that have one) the shelf its fresh snow brakes you onto.
class RimeFlue {
  final String id;

  /// The level whose floor carries this flue's MOUTH (where you freeze/ride).
  final String headRoom;

  /// The level its fall ends on.
  final String footRoom;

  /// The pocket a DRIFT ride sets you down in — a dead end that climbs back
  /// out to [headRoom], never down to [footRoom]. Null = a plain drop.
  final String? shelfRoom;

  /// Where the mouth sits inside [headRoom] (the freeze verb's reach).
  final Offset headPos;

  /// False for the throat: the melt-fall's own gullet takes no frost from
  /// above. Its counterpart is the rimefall, frozen from BELOW.
  final bool freezable;

  /// The throat + rimefall pair. Climbing it triggers THE THAW (see header).
  final bool isThroat;

  const RimeFlue({
    required this.id,
    required this.headRoom,
    required this.footRoom,
    required this.headPos,
    this.shelfRoom,
    this.freezable = true,
    this.isThroat = false,
  });
}

/// The shaft's chutes, top to bottom. Authored as ONE list rather than
/// per-room so the module's reachability proof walks exactly the graph the
/// doors are built from — the two can never disagree.
const List<RimeFlue> kRimeFlues = [
  RimeFlue(
    id: 'flue_a',
    headRoom: 'rime_head',
    footRoom: 'mirror_gallery',
    shelfRoom: 'shelf_glass',
    headPos: Offset(655, 470),
  ),
  RimeFlue(
    id: 'flue_b',
    headRoom: 'mirror_gallery',
    footRoom: 'orrery_floor',
    shelfRoom: 'shelf_lens',
    headPos: Offset(755, 548),
  ),
  RimeFlue(
    id: 'flue_c',
    headRoom: 'orrery_floor',
    footRoom: 'cold_sump',
    headPos: Offset(450, 610),
  ),
  // The throat: a straight plunge from the mouth to the sump. Never freezable
  // from above; the rimefall is its answer from below.
  RimeFlue(
    id: 'throat',
    headRoom: 'rime_head',
    footRoom: 'cold_sump',
    headPos: Offset(95, 470),
    freezable: false,
    isThroat: true,
  ),
];

/// The flue whose head sits in [roomId] and whose foot is [footRoom].
RimeFlue? rimeFlueBetween(String roomId, String footRoom) {
  for (final f in kRimeFlues) {
    if (f.headRoom == roomId && f.footRoom == footRoom) return f;
  }
  return null;
}

/// The flue whose DRIFT ride lands in shelf room [shelfRoom].
RimeFlue? rimeFlueForShelf(String shelfRoom) {
  for (final f in kRimeFlues) {
    if (f.shelfRoom == shelfRoom) return f;
  }
  return null;
}

// ─────────────────────────────────────────────────────────
// STAR 0 — THE STANDING ORRERY
// ─────────────────────────────────────────────────────────

/// The orrery floor, as a grid of cells.
///
/// A star-block is a lump of frozen sky: **too heavy to move on bare stone.**
/// Ice glazes a cell to GLASS; a block shoved onto glass GLIDES, cell after
/// cell, until the glass runs out or something stops it. Light melts a glaze
/// back to stone. So the player never pushes the block where it should go —
/// they lay the ROAD and let it run, which is why this does not repeat
/// Earth's notch-shoves (there the track is authored and each shove is one
/// discrete step; here the surface is authored by the player and the travel
/// is emergent and unbounded).
///
/// Glass is slick underfoot too: a creature that steps onto it is carried
/// along until it finds stone. Laying ice therefore takes away the footing
/// you need to shove from, which is the whole difficulty.
class OrreryGrid {
  /// Row art, one string per row. `.` stone · `#` pillar · `S` socket ·
  /// `B` a star-block's starting cell (on stone).
  final List<String> art;

  /// Top-left of cell (0,0) in room coordinates.
  final Offset origin;

  /// Cell size in px (square).
  final double cell;

  const OrreryGrid({required this.art, required this.origin, this.cell = 92});

  int get rows => art.length;
  int get cols => art.first.length;
  Rect rectAt(int c, int r) =>
      Rect.fromLTWH(origin.dx + c * cell, origin.dy + r * cell, cell, cell);
  Offset centerAt(int c, int r) => rectAt(c, r).center;
}

// ─────────────────────────────────────────────────────────
// STAR 1 — THE TWELVE MIRRORS
// ─────────────────────────────────────────────────────────

/// The gallery's ring of frames. Ice SILVERS a frame (element-only) and the
/// ceiling's star-chart shows in it — but a silvered frame THAWS and clouds
/// over again, so the star is a lap against your own melt (§6: "solve before
/// mirrors thaw"). One frame, the LODESTONE, is black glass no frost will
/// take: only Light's second sight strikes into it, and it never thaws.
class MirrorRing {
  final Offset center;
  final double radius;
  final int count;

  /// Index of the lodestone (the planet's Light+Mask hard gate).
  final int lodestoneIndex;

  /// Where an Air creature's sweep is cast from — the gallery's cold vent.
  /// A sweep renews every silvered frame at once, once per cooldown.
  final Offset vent;

  const MirrorRing({
    required this.center,
    required this.radius,
    required this.vent,
    this.count = 12,
    this.lodestoneIndex = 0,
  });

  /// Frame [i]'s place on the ring. Index 0 sits at the top and the ring runs
  /// clockwise, so the lodestone is the first thing the room shows you.
  Offset frameAt(int i) {
    final a = -math.pi / 2 + (2 * math.pi * i) / count;
    return center + Offset(radius * math.cos(a), radius * math.sin(a));
  }

  /// Walking distance once round the ring, frame to frame — the number the
  /// thaw window is authored against (see `kMirrorHoldSeconds`).
  double get ringStep => 2 * math.pi * radius / count;
}

// ─────────────────────────────────────────────────────────
// PER-ROOM ICE CONTENT
// ─────────────────────────────────────────────────────────

/// Everything the Frozen Observatory puts in one room. Carried on
/// `DungeonRoom.rime` so exactly one field had to be added to the shared room
/// model, and so a room's star index is visible to the layout invariants.
class IceShaft {
  /// The star this room banks (null = a connective level).
  final int? starIndex;

  final OrreryGrid? orrery;
  final MirrorRing? mirrors;

  /// The entry rite: a plug of old black ice over the mouth of flue A. Light
  /// melts it and the shaft opens.
  final Offset? iceCap;

  /// The sump's melt-fall. Ice freezes it into the climb home (and the shaft
  /// thaws behind you — see the file header).
  final Offset? rimefall;

  /// The rite's second half: the cold font, element-only Ice (conduit 'B').
  final Offset? coldFont;

  /// Frowyrm's hoarfrost pillar. Its lull only opens while the pillar stands;
  /// every strike beat shatters it — and one of your stairs with it.
  final Offset? hoarfrost;

  /// The unmarked thirteenth star's telescope (the Lost Maxim).
  final Offset? telescope;

  const IceShaft({
    this.starIndex,
    this.orrery,
    this.mirrors,
    this.iceCap,
    this.rimefall,
    this.coldFont,
    this.hoarfrost,
    this.telescope,
  });
}

// ─────────────────────────────────────────────────────────
// THE LAYOUT
// ─────────────────────────────────────────────────────────

/// Glacius — the Frozen Observatory.
const DungeonLayout iceLayout = DungeonLayout(
  element: 'Ice',
  entranceRoomId: 'rime_head',
  entranceSpawn: Offset(140, 300),
  title: 'THE FROZEN OBSERVATORY',
  descentTitle: 'Glacius Shaft',
  stars: [
    DungeonStarSpec(
      name: 'Orrery Star',
      earnAnnouncement:
          'The Orrery Star is yours — the sky stands still and true',
    ),
    DungeonStarSpec(
      name: 'Mirror Star',
      earnAnnouncement:
          'The Mirror Star is yours — twelve glasses hold the chart at once',
    ),
    DungeonStarSpec(name: 'Frost Star'),
  ],
  // The mouth is plugged with old black ice until Light melts it.
  entranceRevealDoor: DungeonDoorRef('rime_head', 'mirror_gallery'),
  finaleDoor: DungeonDoorRef('cold_sump', 'star_font'),
  riteAnnouncement:
      'Orrery and Mirror are won — the font grinds open below the sump',
  finaleSealedHint:
      'The font is shut — it answers only the Orrery and Mirror stars',
  guardianSealedHint:
      'The hollow is iced over — nothing in there stirs until the font is sung',
  mercyShrineRoomId: 'cold_sump',
  // Ideal: Icemane · Lightmask · Airwing — hinted by VERB, never body part
  // (§4): the cold road left behind, the sight that reads dark glass, and the
  // one the ground cannot keep.
  riddle: [
    'Send me an Ice — my only ladders are the ones you leave behind you;',
    'a Light MASK, to read what my dark glass keeps;',
    'and an Air WING, to turn my last breath down the throat.',
  ],
  // §4 budget: TWO hard gates, one per star that has one, each on a different
  // entry slot. Star 0 (the orrery) is deliberately UNGATED so any trio of
  // Ice/Light/Air progresses on a first descent. The freeze verb — the
  // planet's whole grammar — is element-only Ice everywhere, always.
  familyGates: [
    DungeonFamilyGate(
      objectId: 'mirror_lodestone',
      element: 'Light',
      family: 'Mask',
      hintLine: 'Only Light\'s second sight strikes into this glass',
    ),
    DungeonFamilyGate(
      objectId: 'A',
      element: 'Air',
      family: 'Wing',
      hintLine: 'Only Air borne on wings turns this breath down the throat',
    ),
  ],
  rooms: {
    // ── L0 · THE RIME HEAD ────────────────────────────────
    // The mouth of the observatory. Two ways down leave this floor: flue A
    // (east) and the throat (west). Nothing comes back up either one unless
    // you make it.
    'rime_head': DungeonRoom(
      id: 'rime_head',
      bounds: Rect.fromLTWH(0, 0, 760, 520),
      walls: [
        Rect.fromLTWH(300, 150, 160, 34), // the old sighting bench
      ],
      doors: [
        // Flue A, ridden past its shelf (scoured) or walked as a stair.
        DungeonDoor(
          rect: Rect.fromLTWH(600, 496, 110, 24),
          targetRoomId: 'mirror_gallery',
          targetSpawn: Offset(760, 120),
        ),
        // Flue A's DRIFT ride — the same mouth. Exactly one of this pair is
        // ever live (the module hides the other), so the lip reads as one
        // hole in the floor that behaves differently depending on its snow.
        DungeonDoor(
          rect: Rect.fromLTWH(600, 496, 110, 24),
          targetRoomId: 'shelf_glass',
          targetSpawn: Offset(210, 110),
        ),
        // The throat — a straight plunge to the sump, always open, never
        // climbable except by freezing the rimefall at the bottom.
        DungeonDoor(
          rect: Rect.fromLTWH(40, 496, 110, 24),
          targetRoomId: 'cold_sump',
          targetSpawn: Offset(115, 140),
        ),
      ],
      rime: IceShaft(iceCap: Offset(655, 420)),
    ),

    // ── L1 · THE MIRROR GALLERY (Star 1) ──────────────────
    // A ring of twelve frames around a still black pool. The pool is the
    // planet's signature: it shows the shaft ABOVE, including the glow of
    // flue A's shelf — a thing that is not on any wall.
    'mirror_gallery': DungeonRoom(
      id: 'mirror_gallery',
      bounds: Rect.fromLTWH(0, 0, 860, 600),
      doors: [
        // Up flue A — a stair only.
        DungeonDoor(
          rect: Rect.fromLTWH(700, 0, 110, 24),
          targetRoomId: 'rime_head',
          targetSpawn: Offset(655, 430),
        ),
        // Down flue B, past its shelf.
        DungeonDoor(
          rect: Rect.fromLTWH(700, 576, 110, 24),
          targetRoomId: 'orrery_floor',
          targetSpawn: Offset(450, 130),
        ),
        // Down flue B, braked onto its shelf.
        DungeonDoor(
          rect: Rect.fromLTWH(700, 576, 110, 24),
          targetRoomId: 'shelf_lens',
          targetSpawn: Offset(210, 110),
        ),
      ],
      rime: IceShaft(
        starIndex: 1,
        mirrors: MirrorRing(
          center: Offset(400, 300),
          radius: 216,
          vent: Offset(400, 300),
        ),
      ),
    ),

    // ── FLUE A'S SHELF · THE GLASS LEDGE (the vault) ──────
    // A dead-end pocket. You fall in; you scramble back out the way you came
    // and nowhere else. Nothing on any level can climb to it.
    'shelf_glass': DungeonRoom(
      id: 'shelf_glass',
      bounds: Rect.fromLTWH(0, 0, 420, 340),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(155, 0, 110, 24),
          targetRoomId: 'rime_head',
          targetSpawn: Offset(655, 430),
        ),
      ],
      vaultCache: Offset(210, 230),
    ),

    // ── FLUE B'S SHELF · THE LENS NICHE (the Lost Maxim) ──
    'shelf_lens': DungeonRoom(
      id: 'shelf_lens',
      bounds: Rect.fromLTWH(0, 0, 420, 340),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(155, 0, 110, 24),
          targetRoomId: 'mirror_gallery',
          targetSpawn: Offset(755, 470),
        ),
      ],
      rime: IceShaft(telescope: Offset(210, 220)),
    ),

    // ── L2 · THE ORRERY FLOOR (Star 0) ────────────────────
    // 8×5 of 92px from (60,150) → 736×460 inside a 900×660 room.
    // `B` blocks start on stone; `S` sockets are kerbed and seat whatever
    // slides into them; `#` pillars stop a glide dead.
    'orrery_floor': DungeonRoom(
      id: 'orrery_floor',
      bounds: Rect.fromLTWH(0, 0, 900, 660),
      doors: [
        // Up flue B — a stair only.
        DungeonDoor(
          rect: Rect.fromLTWH(345, 0, 110, 24),
          targetRoomId: 'mirror_gallery',
          targetSpawn: Offset(755, 470),
        ),
        // Down flue C (no shelf — the next stop is the bottom).
        DungeonDoor(
          rect: Rect.fromLTWH(395, 636, 110, 24),
          targetRoomId: 'cold_sump',
          targetSpawn: Offset(450, 140),
        ),
      ],
      rime: IceShaft(
        starIndex: 0,
        orrery: OrreryGrid(
          origin: Offset(60, 150),
          art: ['..S..S..', '.#....#.', '.B....B.', '.#....#.', '...BS...'],
        ),
      ),
    ),

    // ── THE COLD SUMP (the bottom · mercy · the rimefall) ─
    'cold_sump': DungeonRoom(
      id: 'cold_sump',
      bounds: Rect.fromLTWH(0, 0, 820, 560),
      doors: [
        // THE RIMEFALL — frozen from below, and the shaft thaws behind you.
        DungeonDoor(
          rect: Rect.fromLTWH(60, 0, 110, 24),
          targetRoomId: 'rime_head',
          targetSpawn: Offset(95, 430),
        ),
        // Up flue C — a stair only.
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'orrery_floor',
          targetSpawn: Offset(450, 520),
        ),
        // The rite, behind both stars.
        DungeonDoor(
          rect: Rect.fromLTWH(660, 536, 110, 24),
          targetRoomId: 'star_font',
          targetSpawn: Offset(320, 120),
        ),
      ],
      rime: IceShaft(rimefall: Offset(115, 80)),
    ),

    // ── THE STAR FONT (the rite) ──────────────────────────
    // Conduit A is the planet's Air+Wing gate — the last cold breath turned
    // down the throat. Conduit B is the font itself: element-only Ice, so a
    // party that brought no Wing still learns what it is missing at ONE
    // object rather than being stopped by two.
    'star_font': DungeonRoom(
      id: 'star_font',
      bounds: Rect.fromLTWH(0, 0, 640, 460),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(265, 0, 110, 24),
          targetRoomId: 'cold_sump',
          targetSpawn: Offset(715, 470),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(265, 436, 110, 24),
          targetRoomId: 'frowyrm_hollow',
          targetSpawn: Offset(450, 150),
        ),
      ],
      conduits: [
        Conduit(
          id: 'A',
          position: Offset(200, 250),
          requireElement: 'Air',
          requiredFamily: DungeonAbility.aerialTraversal,
        ),
        // The rite's other half — conduit 'B' — is NOT authored as a Conduit:
        // it is the cold font below, an element-only Ice object the Ice module
        // owns and which latches `conduitEnergy['B']` itself. Authoring it as
        // a family-less Conduit would make the engine's channel verb step over
        // it and the layout invariants read it as a storm-struck pylon with no
        // storm, which it is not.
      ],
      rime: IceShaft(coldFont: Offset(440, 250)),
    ),

    // ── FROWYRM'S HOLLOW (Star 2) ─────────────────────────
    // §7 guardian principle — the mystic fights WITH the planet's rule:
    // Frowyrm's lull only opens while the hoarfrost pillar stands, and every
    // strike beat shatters the pillar AND scours one of the stairs you left
    // in the shaft above. It eats your way home while you fight it.
    'frowyrm_hollow': DungeonRoom(
      id: 'frowyrm_hollow',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'star_font',
          targetSpawn: Offset(320, 330),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(450, 360),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Ice',
          mysticId: 'Frowyrm',
          canCalm: true,
          canDefeat: true,
        ),
      ),
      rime: IceShaft(hoarfrost: Offset(170, 480)),
    ),
  },
);
