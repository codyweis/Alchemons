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
//     mirror_gallery (L1, Star 0)                       │ (one-way plunge)
//        │ flue B ──► shelf_lens   (the 13th telescope) │
//     orrery_floor  (L2, Star 1)                        │
//        │ flue C                                       │
//     cold_sump  (the bottom, mercy)  ◄─────────────────┘
//        │  the RIMEFALL climbs back to the mouth
//     star_font (the rite: THE ROOF OF THE HOLLOW) ↓ drop through the roof
//     frowyrm_hollow (Star 2 · MYS09 Frowyrm)
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
// THE VAULT TRICK (§5.5): the cache sits on flue A's shelf, **enterable only
// by falling onto its ledge**: nothing climbs to it, and its only door
// scrambles back out the way you came. The chute is a ramp every time
// (2026-09-20): a shelf you could enter once a run was a commitment that
// gated nothing and made the lens niche a one-shot. The pool below used to
// show the shelf's glow ("visible only in a mirror"); that tell is gone too —
// it read as an unexplained blue star.
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

  /// Where the SHAFT's mouth sits inside [headRoom] — the hole that goes
  /// down a level, and the one the freeze verb works on.
  final Offset headPos;

  /// Where the LEDGE CHUTE's mouth sits, for the two flues that have a ledge.
  ///
  /// TWO MOUTHS, NEVER ONE (2026-09-15, from play). The shaft and the chute
  /// used to be the same hole with two doors on one rect, of which the module
  /// kept one live — *"you go through the same door and end up in 2 spots"*.
  /// They are separate openings now, each with ONE destination for the whole
  /// run and its own snow, and nothing couples them.
  final Offset? chutePos;

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
    this.chutePos,
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
    chutePos: Offset(445, 470),
  ),
  RimeFlue(
    id: 'flue_b',
    headRoom: 'mirror_gallery',
    footRoom: 'orrery_floor',
    shelfRoom: 'shelf_lens',
    headPos: Offset(755, 548),
    chutePos: Offset(555, 548),
  ),
  RimeFlue(
    id: 'flue_c',
    headRoom: 'orrery_floor',
    footRoom: 'cold_sump',
    headPos: Offset(450, 620),
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
// STAR 1 (index 1) — THE STANDING ORRERY
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
  /// Row art, one string per row. `.` stone · `#` pillar · `B` a star-block's
  /// starting cell (on stone) · and a SOCKET as the direction its kerb opens
  /// to: `>` east · `<` west · `^` north · `v` south.
  ///
  /// THE SKY TURNS ONE WAY (2026-09-15). A kerb takes a block only if the
  /// block is running WITH the orbit it sits on — east along the top, west
  /// along the bottom — and stops it dead at the lip otherwise. Sockets used
  /// to take anything from any side, which made the whole floor a five-shove
  /// formality: the nearest block was always already lined up with the
  /// nearest kerb. Now the approach is the puzzle.
  final List<String> art;

  /// WHICH BLOCK EACH KERB IS CUT FOR, as `row * cols + col` → block index
  /// (blocks are numbered in the order their `B` cells are read, row by row).
  ///
  /// A kerb takes ONLY its own block, and only from the direction its orbit
  /// turns. Both halves are cut into the stone — the figure on the kerb is
  /// the figure on the block — because a rule you cannot see is not a puzzle,
  /// it is a secret. Any-block sockets made the floor a five-shove
  /// formality; owned ones make the shortest solution TEN.
  final Map<int, int> kerbOwner;

  /// Top-left of cell (0,0) in room coordinates.
  final Offset origin;

  /// Cell size in px (square).
  final double cell;

  const OrreryGrid({
    required this.art,
    required this.origin,
    this.kerbOwner = const {},
    this.cell = 92,
  });

  int get rows => art.length;
  int get cols => art.first.length;
  Rect rectAt(int c, int r) =>
      Rect.fromLTWH(origin.dx + c * cell, origin.dy + r * cell, cell, cell);
  Offset centerAt(int c, int r) => rectAt(c, r).center;
}

// ─────────────────────────────────────────────────────────
// STAR 0 (index 0) — THE MIRROR GALLERY
// ─────────────────────────────────────────────────────────

/// The gallery's ring of frames, and the still pool they stand around.
///
/// THE CHART ASSEMBLES IN THE WATER. The ceiling's chart is one closed figure
/// of 24 stars running right around the ring, and it is never seen directly.
/// Silvering a frame throws that frame's stretch of it into the pool, and
/// frost comes off as easily as it goes on, so the water is a workbench.
///
/// Neighbouring frames OVERLAP — two stars apiece, five covered — so no frame
/// can be judged on its own. Where two silvered frames disagree about where a
/// star hangs, the line FORKS, and a fork names a PAIR, never a frame. The
/// answer is chained out from the LODESTONE, the one frame known true, by
/// choosing what to put in the water and what to take out. Some frames are
/// hung false and the star is won by leaving exactly those out; no two of
/// them are ever side by side, or a stretch of chart would have no cover.
///
/// And the water answers a LIGHT hand and nothing else: standing at the rim
/// it shows that hand the stretch ACROSS the ring, and the water closes again
/// behind it. Reading is therefore a thing you are DOING, with the one hand
/// the entrance and the lodestone also want — walk it to see, switch to Ice
/// to work the frames, switch back to check. Air's sweep off the cold vent
/// FLASHES the whole surface for a breath and fades: a glimpse of where to
/// walk the lamp, never a way round walking it.
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
  /// It stands on the roof's one pier (see [roof]).
  final Offset? coldFont;

  /// THE ROOF OF THE HOLLOW — the rite room's floor is the ice over the
  /// wyrm's lair, in panes (2026-09-20).
  final IceRoof? roof;

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
    this.roof,
    this.hoarfrost,
    this.telescope,
  });
}

/// What a pane of the roof lies on. Authored per cell, and hidden under snow
/// until Light bares it.
enum IceRoofBed {
  /// Solid glacier. Bare ice over rock is THICK: it bears everyone.
  rock,

  /// The hollow. Bare ice over the hollow is THIN: it bears one body.
  hollow,

  /// The pier the font stands on — rock, drawn as a plinth above the snow.
  pier,
}

/// THE ROOF OF THE HOLLOW (2026-09-20) — the Star Font room's floor.
///
/// A grid of ice panes over Frowyrm's lair, snow on every one of them. Snow
/// bears all and shows nothing; Light bares a pane and the ice shows what it
/// lies on. Over ROCK it is thick and holds the party; over the HOLLOW it is
/// thin and holds ONE body. Somewhere under it the wyrm sleeps, its body a
/// line of cells rolled per run, and the pane over its HEAD is the throat the
/// last breath goes down — and, once it is awake, the way in.
///
/// The `art` rows are authored: 'R' rock · '.' hollow · 'W' open water (the
/// wyrm's warmth melted through) · 'F' the font's pier (rock).
class IceRoof {
  final Offset origin;
  final double cell;
  final List<String> art;

  const IceRoof({required this.origin, required this.cell, required this.art});

  int get cols => art.first.length;
  int get rows => art.length;
  int get count => cols * rows;

  Rect get bounds =>
      Rect.fromLTWH(origin.dx, origin.dy, cols * cell, rows * cell);

  IceRoofBed bedAt(int c) => switch (art[c ~/ cols][c % cols]) {
    'R' => IceRoofBed.rock,
    'F' => IceRoofBed.pier,
    _ => IceRoofBed.hollow,
  };

  /// Open water from the start.
  bool waterAt(int c) => art[c ~/ cols][c % cols] == 'W';

  /// The pier's cell (exactly one, layout-test enforced).
  int get pierCell => [
    for (var c = 0; c < count; c++)
      if (art[c ~/ cols][c % cols] == 'F') c,
  ].single;

  Offset centerAt(int c) => Offset(
    origin.dx + (c % cols) * cell + cell / 2,
    origin.dy + (c ~/ cols) * cell + cell / 2,
  );

  Rect rectOf(int c) => Rect.fromLTWH(
    origin.dx + (c % cols) * cell,
    origin.dy + (c ~/ cols) * cell,
    cell,
    cell,
  );

  /// The pane under [p], or null off the roof (the shores, the rims).
  int? cellAt(Offset p) {
    final cx = ((p.dx - origin.dx) / cell).floor();
    final cy = ((p.dy - origin.dy) / cell).floor();
    if (cx < 0 || cy < 0 || cx >= cols || cy >= rows) return null;
    return cy * cols + cx;
  }

  /// Four-neighbours of [c] that exist.
  List<int> neighbours(int c) {
    final x = c % cols, y = c ~/ cols;
    return [
      if (y > 0) c - cols,
      if (y < rows - 1) c + cols,
      if (x > 0) c - 1,
      if (x < cols - 1) c + 1,
    ];
  }

  bool adjacent(int a, int b) => neighbours(a).contains(b);
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
  // STARS NUMBER IN THE ORDER YOU MEET THEM (2026-09-15, from play). The
  // gallery is L1 and the orrery L2, but the orrery was Star 0 — so the first
  // pip lit for the room you reached second. It had been ordered that way by
  // a house habit of making Star 0 the ungated one; §4's actual rule is only
  // that SOME star is earnable by any trio, and the orrery is that star at
  // either index.
  stars: [
    DungeonStarSpec(
      name: 'Mirror Star',
      earnAnnouncement:
          'The Mirror Star is yours. You found the odd star out',
    ),
    DungeonStarSpec(
      name: 'Orrery Star',
      earnAnnouncement:
          'The Orrery Star is yours. Every block is on its socket',
    ),
    DungeonStarSpec(name: 'Frost Star'),
  ],
  // The mouth is plugged with old black ice until Light melts it.
  entranceRevealDoor: DungeonDoorRef('rime_head', 'mirror_gallery'),
  finaleDoor: DungeonDoorRef('cold_sump', 'star_font'),
  riteAnnouncement:
      'Mirror and Orrery are won. The Star Font over the hollow opens',
  finaleSealedHint:
      'This stays shut until you have the Mirror and Orrery stars',
  guardianSealedHint:
      'Frowyrm won\'t wake until the font is sung and the breath is turned '
      'down',
  mercyShrineRoomId: 'cold_sump',
  // Ideal: Icemane · Lightmask · Airwing — hinted by VERB, never body part
  // (§4): the cold road left behind, the sight that reads dark glass, and the
  // one the ground cannot keep.
  riddle: [
    'Send me Ice: my only ladders are the ones you leave behind you;',
    'a Light Mask, to read what my dark glass keeps;',
    'and a Air Wing, to turn my last breath down the throat.',
  ],
  // THE PRIMER HAS TO TEACH THE STATES, not just the trade. It said what the
  // choice COSTS and never that a hole has three conditions — so a player who
  // rode the same mouth twice and landed in two different rooms read it as
  // one door with two exits, which is unreadable and is not what it is: only
  // one destination is ever live, and which one is written on the snow.
  // Three sentences, one per thing you can see. Nothing here is a hidden
  // resource and nothing is coupled to anything else (2026-09-15): a shaft
  // is a shaft, a chute is a chute, and what they do is written on them.
  primer: [
    'Shafts only go down, unless Ice freezes their snow into steps.',
    'Ride a shaft down and it\'s bare ice for good. It can\'t be frozen after.',
    'A ledge has its own chute, and its snow comes down with you.',
  ],
  // §4 budget: TWO hard gates, one per star that has one, each on a different
  // entry slot. The ORRERY (Star 1, index 1) is deliberately UNGATED so any
  // trio of Ice/Light/Air progresses on a first descent. The freeze verb — the
  // planet's whole grammar — is element-only Ice everywhere, always.
  familyGates: [
    DungeonFamilyGate(
      objectId: 'mirror_lodestone',
      element: 'Light',
      family: 'Mask',
      hintLine: 'Only a Light Mask can strike this glass',
    ),
    DungeonFamilyGate(
      objectId: 'A',
      element: 'Air',
      family: 'Wing',
      hintLine: 'Only an Air Wing can turn this breath down',
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
        // THE SHAFT — down a level, always. Ridden it is bare for good;
        // frozen it is a stair you can climb.
        DungeonDoor(
          rect: Rect.fromLTWH(600, 496, 110, 24),
          targetRoomId: 'mirror_gallery',
          targetSpawn: Offset(760, 120),
        ),
        // THE LEDGE CHUTE — its own mouth, its own snow, and it goes exactly
        // one place. The snow is what makes it a ramp, and it holds: ride it
        // as often as you like.
        DungeonDoor(
          rect: Rect.fromLTWH(390, 496, 110, 24),
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
    // planet's signature: it shows the shaft ABOVE.
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
        // The shaft, down a level.
        DungeonDoor(
          rect: Rect.fromLTWH(700, 576, 110, 24),
          targetRoomId: 'orrery_floor',
          targetSpawn: Offset(450, 62),
        ),
        // The lens niche's own chute, 90px clear of it.
        DungeonDoor(
          rect: Rect.fromLTWH(500, 576, 110, 24),
          targetRoomId: 'shelf_lens',
          targetSpawn: Offset(210, 110),
        ),
      ],
      rime: IceShaft(
        starIndex: 0,
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
          targetSpawn: Offset(445, 420),
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
          targetSpawn: Offset(555, 498),
        ),
      ],
      rime: IceShaft(telescope: Offset(210, 220)),
    ),

    // ── L2 · THE ORRERY FLOOR (Star 0) ────────────────────
    // 8×5 of 92px from (60,110) → 736×460 inside a 900×660 room, which
    // leaves a margin on all four sides: the floor is reached ACROSS its
    // edge (see the module's `_orreryStandCell`), and the bottom margin is
    // wide enough that flue C's mouth no longer sits on top of the socket
    // in the last row — the hole you fall down and the kerb you seat a
    // block in were drawn over one another and answered the same button.
    // `B` blocks start on stone; `S` sockets are kerbed and seat whatever
    // slides into them; `#` pillars stop a glide dead.
    'orrery_floor': DungeonRoom(
      id: 'orrery_floor',
      bounds: Rect.fromLTWH(0, 0, 900, 660),
      // The four iron standards, as SOLID. They stop a sliding star-block
      // dead, and a body walked straight through them — a cast-iron column
      // you can stand inside is not a pillar, it is a decal. Inset inside
      // their cells so the floor's own squares stay walkable round them.
      walls: [
        Rect.fromLTWH(162, 212, 72, 72), // cell (1,1)
        Rect.fromLTWH(622, 212, 72, 72), // cell (6,1)
        Rect.fromLTWH(162, 396, 72, 72), // cell (1,3)
        Rect.fromLTWH(622, 396, 72, 72), // cell (6,3)
      ],
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
        starIndex: 1,
        orrery: OrreryGrid(
          origin: Offset(60, 110),
          art: ['..>..>..', '.#....#.', '.B....B.', '.#....#.', '...B<...'],
          // (2,0) is the west block's, (5,0) the east block's, (4,4) the
          // south block's — each one the socket you would think was "its"
          // nearest, and each one reachable only the long way round.
          kerbOwner: {2: 0, 5: 1, 36: 2},
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
          targetSpawn: Offset(560, 598),
        ),
        // The rite, behind both stars. You come out on the near shore of
        // the roof.
        DungeonDoor(
          rect: Rect.fromLTWH(660, 536, 110, 24),
          targetRoomId: 'star_font',
          targetSpawn: Offset(400, 70),
        ),
      ],
      rime: IceShaft(rimefall: Offset(115, 80)),
    ),

    // ── THE STAR FONT · THE ROOF OF THE HOLLOW (the rite) ─
    // The rite room's floor is the ICE OVER FROWYRM'S LAIR, in panes under
    // snow (2026-09-20 — it was two plinths and two presses). Snow bears all
    // and shows nothing. Light bares a pane; over rock the ice is thick and
    // holds everyone, over the hollow it is thin and holds ONE body. The
    // wyrm sleeps under it, its body rolled per run, and every bared pane
    // over the hollow says which way its head lies. Open the glass over the
    // head and that is the throat: the Air Wing turns the last breath down
    // it (the planet's second hard gate), Ice sings the font on its pier,
    // and the wyrm wakes. Then the party goes down the throat together.
    //
    // Two shores: the near one at the top (from the sump) and the far one at
    // the bottom (where you come back up out of the hollow). The rims either
    // side are glacier, and walls.
    'star_font': DungeonRoom(
      id: 'star_font',
      bounds: Rect.fromLTWH(0, 0, 800, 620),
      walls: [
        Rect.fromLTWH(0, 130, 40, 400), // the west rim
        Rect.fromLTWH(760, 130, 40, 400), // the east rim
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(345, 0, 110, 24),
          targetRoomId: 'cold_sump',
          targetSpawn: Offset(715, 470),
        ),
        // THE WAY DOWN IS THROUGH THE ROOF. This door is never shown and
        // never walked: the module takes it when the party goes down the
        // throat (`_roofDrop`). It exists so the layout is honest about the
        // hollow having a way in, and so the invariant "every door has a way
        // back" holds for the hollow's own door up.
        DungeonDoor(
          rect: Rect.fromLTWH(60, 596, 110, 24),
          targetRoomId: 'frowyrm_hollow',
          targetSpawn: Offset(450, 150),
        ),
      ],
      rime: IceShaft(
        // The font stands on the pier: 'F' in the art below, which is
        // (col 5, row 2) — its centre.
        coldFont: Offset(480, 330),
        roof: IceRoof(
          origin: Offset(40, 130),
          cell: 80,
          // The pier is an island: water on three sides, so the font is
          // reached from the far side of the roof, or by Ice freezing a way.
          // The four rock corners are where the glacier comes through.
          art: [
            'R...W...R',
            '.....W...',
            '....WFW..',
            '......W..',
            'R.......R',
          ],
        ),
      ),
    ),

    // ── FROWYRM'S HOLLOW (Star 2) ─────────────────────────
    // §7 guardian principle — the mystic fights WITH the planet's rule:
    // Frowyrm's lull only opens while the hoarfrost pillar stands, and every
    // strike beat shatters the pillar AND scours one of the stairs you left
    // in the shaft above. It eats your way home while you fight it.
    'frowyrm_hollow': DungeonRoom(
      id: 'frowyrm_hollow',
      // The fight's whole verb is a pillar of hoarfrost standing in the room,
      // and it is DOWN when you walk in — so the room taught itself nothing
      // and drew almost nothing. One line, once, on the insight channel.
      teach:
          'Frowyrm can only be hit while the hoarfrost pillar stands, and '
          'every hit it lands knocks the pillar down.',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        // Back up through the broken roof, onto its far shore.
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'star_font',
          targetSpawn: Offset(400, 575),
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
