// lib/games/planet_dungeon/planet_dungeon_data.dart
//
// PLANET DUNGEON — data model + persistence.
//
// Authored, per-planet multi-room layouts the swap-control dungeon scene runs
// on. Slice 2 is the reusable chassis: rooms are generic boxes with walls,
// doorways, a test hazard, and placeholder star pickups. Slice 3 replaces the
// placeholders with each planet's bespoke puzzles. See `project-planet-dungeons`.

import 'dart:ui';

import 'package:alchemons/games/cosmic/cosmic_data.dart'
    show PlanetStarState;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

// ─────────────────────────────────────────────────────────
// LAYOUT MODEL
// ─────────────────────────────────────────────────────────

/// Points at one specific door: the room it sits in and the room its passage
/// leads to. Layouts use these to declare which doors are hidden behind a
/// star, the entry reveal, or the guardian-rite lock — so the engine never
/// hardcodes room ids.
class DungeonDoorRef {
  final String roomId;
  final String targetRoomId;
  const DungeonDoorRef(this.roomId, this.targetRoomId);

  bool matches(DungeonRoom room, DungeonDoor door) =>
      room.id == roomId && door.targetRoomId == targetRoomId;
}

/// Per-star authored identity: the star's name (composed into engine copy),
/// the hint shown when it banks, and the hidden doors its earn reveals.
class DungeonStarSpec {
  final String name; // e.g. 'Wind Star'
  final String? earnAnnouncement; // hint when the star banks (null = none)
  final List<DungeonDoorRef> revealDoors; // hidden until this star is earned
  const DungeonStarSpec({
    required this.name,
    this.earnAnnouncement,
    this.revealDoors = const [],
  });
}

/// A doorway region in a room. When the active creature overlaps [rect], the
/// scene transitions to [targetRoomId], placing creatures at [targetSpawn].
class DungeonDoor {
  final Rect rect;
  final String targetRoomId;
  final Offset targetSpawn;

  const DungeonDoor({
    required this.rect,
    required this.targetRoomId,
    required this.targetSpawn,
  });
}

/// A placeholder reward kept for the chassis / future planets. (The Air pilot
/// now earns stars from real puzzles instead.) Walking onto it banks star
/// [starIndex].
class DungeonStarPickup {
  final int starIndex;
  final Offset position;

  const DungeonStarPickup({required this.starIndex, required this.position});
}

// ── Star 1: Wind Spire ─────────────────────────────────────

/// Impassable void — blocks walking; only a gliding creature may cross.
class DungeonGap {
  final Rect rect;
  const DungeonGap(this.rect);
}

/// Directional wind that carries gliding creatures. If the glider's Speed is
/// below [requiredSpeed] the current overpowers them (net push backwards).
class WindCurrent {
  final Rect rect;
  final Offset dir; // normalised
  final double strength; // px/sec
  final double requiredSpeed; // 1..5 stat threshold (0 = no gate)
  const WindCurrent({
    required this.rect,
    required this.dir,
    this.strength = 90,
    this.requiredSpeed = 0,
  });
}

/// A hoop flown through in [order] (0,1,2…) to advance the spire sequence.
class SkyRing {
  final int order;
  final Offset position;
  const SkyRing({required this.order, required this.position});
}

/// Star 1 completion zone — entering while gliding (after the ring sequence)
/// earns [starIndex].
class SpireSummit {
  final Rect rect;
  final int starIndex;
  const SpireSummit({required this.rect, required this.starIndex});
}

// ── Star 2: Sky Loom ───────────────────────────────────────

/// A wonder-cloud (Spiral/Ring/Anvil/Feather/Veil). Discovered via Mask reveal
/// or proximity, then carried to its matching loom anchor.
class HiddenCloud {
  final String id;
  final String cloudType;
  final Offset position;
  const HiddenCloud({
    required this.id,
    required this.cloudType,
    required this.position,
  });
}

/// A loom slot that accepts a specific [requiredCloudType]. One anchor may
/// require a Thundercloud (an Anvil charged via the air+fire combo). [clue] is
/// shown when Mask intelligence is too low to reveal the exact type.
class LoomAnchor {
  final String id;
  final String requiredCloudType;
  final Offset position;
  final String clue;
  const LoomAnchor({
    required this.id,
    required this.requiredCloudType,
    required this.position,
    this.clue = '',
  });
}

// ── Fire Star 1: Ritual of First Flame ─────────────────────

/// A ritual brazier. The cathedral remembers the order its fires were first
/// lit: braziers must be ignited in [order] (0,1,2…). A wrong brazier snuffs
/// the whole rite (and the ash answers). The order is NOT spatial — a soot
/// mural elsewhere diagrams it for a Mask to read.
class RitualBrazier {
  final int order;
  final Offset position;
  const RitualBrazier({required this.order, required this.position});
}

// ── Fire Star 2: Ash Garden ────────────────────────────────

/// A scorched garden bed. Plant grows it over with vines; Fire burns the
/// vines to ash (Plant+Fire→Dust); the settling ash fills an old floor groove
/// and reveals the sigil cut beneath. All beds revealed → the garden's star.
class VineBed {
  final String id;
  final Offset position;
  const VineBed({required this.id, required this.position});
}

// ── Fire Star 3: Vesper of Embers ──────────────────────────

/// A hanging incense chain: censers strung between [nodes], ending at an
/// ember bell at [bellPosition]. Fire lights the first censer; the flame
/// crawls censer to censer but starves between them — an Air creature's gust
/// (Wing = strongest) carries it on. The flame reaching the bell rings it.
/// All bells rung → the guardian wakes.
class IncenseChain {
  final String id;
  final List<Offset> nodes;
  final Offset bellPosition;
  const IncenseChain({
    required this.id,
    required this.nodes,
    required this.bellPosition,
  });
}

// ── Water (Mirror Tide) — the drowned temple's verbs ───────
// World rule: every chamber answers to ONE temple-wide tide (low/mid/high),
// and the tide MOVES — floods and drains are animated, never a teleport.

/// A tide valve. Master valves set the temple to an explicit [level]
/// (0 low · 1 mid · 2 high) and answer any Water creature (Pip = instant,
/// others sluggish). A [pipOnly] pipe-mouth ([level] null) cycles the tide
/// one step and only a smallAccess creature can slip inside.
class TideValve {
  final Offset position;
  final int? level; // null = cycle (pipe-mouth)
  final bool pipOnly;
  const TideValve({required this.position, this.level, this.pipOnly = false});
}

/// A sluice seal (Star 1): openable only while the tide stands settled at one
/// of [tides] — one seal lives in a drained basin, one on a mid ledge, one
/// beyond a wall that must be swum over at high tide.
class TideSeal {
  final String id;
  final Offset position;
  final Set<int> tides;
  const TideSeal({required this.id, required this.position, required this.tides});
}

/// A ghost-current eddy (Star 2): invisible until Spirit insight reveals the
/// current; waded through in [order] like the spire's rings.
class GhostEddy {
  final int order;
  final Offset position;
  const GhostEddy({required this.order, required this.position});
}

/// A moon-pool (Star 3): at MID tide, Ice freezes it into a bridge-disc
/// (Spirit acting in the water braids the same — Spirit+Water→Ice). Only the
/// TRUE pools (the ones whose reflection holds the moon — Spirit insight
/// tells) take the ice; freezing a false pool shatters and angers the brine.
class MoonPool {
  final String id;
  final Offset position;
  final bool isTrue;
  const MoonPool({
    required this.id,
    required this.position,
    required this.isTrue,
  });
}

/// Tide-shaped terrain. A basin ([ledge] false) is always passable — drained
/// floor below [floodedAt], swimmable water at/above it. A ledge ([ledge]
/// true) is a solid wall below [floodedAt] and is swum OVER once the water
/// climbs that high.
class TideZone {
  final Rect rect;
  final int floodedAt; // 1 = floods at mid, 2 = floods only at high
  final bool ledge;
  const TideZone({
    required this.rect,
    required this.floodedAt,
    this.ledge = false,
  });
}

/// A door that only opens while the tide stands settled at one of [tides]
/// (drowned or dry passages). Matched by the door's target room id.
class TideDoorRule {
  final String targetRoomId;
  final Set<int> tides;
  const TideDoorRule({required this.targetRoomId, required this.tides});
}

// ── Earth (Buried Giant) — the barrow's verbs ──────────────
// World rule: the dungeon IS a buried body — its bones are the machinery.

/// A fossil rib on a carved track of [notches] (track-notch shoves, never
/// free physics). A shove slides it one notch with an animated grind; the
/// LAST notch drops it into the chasm groove where it becomes WALKWAY.
/// Anywhere else the rib is a solid wall.
class FossilRib {
  final String id;
  final List<Offset> notches; // ≥2; last = the bridging groove
  final double width;
  final double height;
  const FossilRib({
    required this.id,
    required this.notches,
    this.width = 170,
    this.height = 30,
  });
}

/// A fossil pillar (Star 2): a buried socket that a Lightning creature arcs
/// (Earth+Lightning→Crystal — the lock grows as crystal). PARITY: a Crystal
/// creature sets the lock directly.
class FossilPillar {
  final String id;
  final Offset position;
  const FossilPillar({required this.id, required this.position});
}

/// A weight on the giant's stone scale (Star 3): toggled between the left
/// and right pans; [truePanRight] is its hidden correct side (the giant's
/// eye knows — Crystal insight reads it).
class ScaleWeight {
  final String id;
  final Offset position;
  final bool truePanRight;
  const ScaleWeight({
    required this.id,
    required this.position,
    required this.truePanRight,
  });
}

/// The stone scale itself: centrepiece [position], its weights, and the
/// bare [plinth] in the eye's sightline. The eye is BLIND until the player
/// builds it a lens there — stone raised by Earth, crystallised by
/// Lightning's arc (Earth+Lightning→Crystal; Crystal sets it directly) —
/// and it only speaks its count when communed with at the standing prism.
/// NOTE: [ScaleWeight.truePanRight] is the authored sample only — at run
/// time the solution is RANDOMISED per run (the eye remembers differently
/// each burial).
class StoneScale {
  final Offset position;
  final Offset plinth;
  final List<ScaleWeight> weights;
  const StoneScale({
    required this.position,
    required this.plinth,
    required this.weights,
  });
}

// ── Star 3: Storm Altar ────────────────────────────────────

/// A conduit that must be energized. [id] 'A' = channelled behind a HARD GATE
/// (Lightning + Horn, nothing else); 'B' = arc-lit by a Fire creature acting
/// inside the crossing wind current (the Air+Fire→Lightning recipe).
class Conduit {
  final String id;
  final Offset position;
  final String requireElement;

  /// Family the conduit gates on. null = not channelled at all (arc/recipe
  /// only) — those conduits are skipped by the channel verb.
  final DungeonAbility? requiredFamily;
  const Conduit({
    required this.id,
    required this.position,
    required this.requireElement,
    this.requiredFamily,
  });

  DungeonInteractionRequirement get requirement =>
      DungeonInteractionRequirement(
        element: requireElement,
        requiredFamily: requiredFamily,
      );
}

/// A planet guardian (a Mystic). Awakens once its puzzle is solved; resolved by
/// calm or defeat per [encounter]. Kept separate from the family-ability model.
class GuardianNode {
  final Offset position;
  final int starIndex;
  final GuardianEncounterRequirement? encounter;
  const GuardianNode({
    required this.position,
    required this.starIndex,
    this.encounter,
  });
}

// ── Lightning (Storm Circuit): the living circuit ──────────
// World rule: the dungeon IS a living circuit. Charge floods from energized
// SOURCE pylons across conductive links each tick; MIRRORS route it (only the
// links of their current orientation conduct); SINKS bank a star when every
// sink in a room is powered together; powered barriers open, unpowered close.

/// What a [CircuitNode] does in the power graph.
enum CircuitNodeKind {
  /// A pylon. Charged by any Lightning creature (element-only) — holds a
  /// DECAYING charge window; while charged it floods power into its links.
  source,

  /// A relay; always conducts all its links.
  bus,

  /// A rotatable conductor. Only the neighbour ids in its CURRENT orientation
  /// conduct; [orientationLinks] lists each rotation's conducting neighbours.
  mirror,

  /// A terminal. When every sink in a room is powered at once the room's
  /// [DungeonRoom.circuitStarIndex] banks (or it gates a barrier/door).
  sink,
}

/// One node in a room's power graph (all room-local coordinates).
class CircuitNode {
  final String id;
  final CircuitNodeKind kind;
  final Offset position;

  /// Every wired neighbour (drives rendering + conduction for non-mirrors).
  final List<String> links;

  /// Mirrors only: per-rotation conducting neighbour ids. Empty for other
  /// kinds. `orientations == orientationLinks.length` (min 1).
  final List<List<String>> orientationLinks;

  /// Source nodes: the element allowed to charge it (defaults to Lightning).
  final String? requireElement;

  /// Source nodes energized PERMANENTLY by a storm-cell socket (S2) rather than
  /// a decaying Horn channel — set true so the engine never decays them.
  final bool latching;

  const CircuitNode({
    required this.id,
    required this.kind,
    required this.position,
    this.links = const [],
    this.orientationLinks = const [],
    this.requireElement,
    this.latching = false,
  });

  int get orientations =>
      orientationLinks.isEmpty ? 1 : orientationLinks.length;
}

/// A wall that exists only while its [nodeId] is UNPOWERED. Powering the node
/// opens the gap — the overload maze: powered doors open, unpowered close.
class PoweredBarrier {
  final Rect rect;
  final String nodeId;
  const PoweredBarrier({required this.rect, required this.nodeId});
}

/// The overload maze's power beam: it fires from [position] in [dir] (a unit
/// axis vector) and reflects 90° off each [BeamMirror] until it leaves the room
/// or reaches the core receiver. A Lightning Horn fires it (a decaying window).
class BeamEmitter {
  final Offset position;
  final Offset dir; // unit axis vector, e.g. Offset(1, 0)
  const BeamEmitter({required this.position, required this.dir});
}

/// A rotatable 45° conductor in the beam's path. Its state lives in the engine's
/// `mirrorOrient` map: 0 = '/', 1 = '\\'. '/' swaps right↔up & left↔down; '\\'
/// swaps right↔down & left↔up.
class BeamMirror {
  final String id;
  final Offset position;
  const BeamMirror({required this.id, required this.position});
}

/// A storm-cell echo (Spark/Veil/Anvil flavour) discovered in a side room via
/// insight or proximity, then herded by an Airwing gust onto a [CellSocket].
class StormCell {
  final String id;
  final String cellType;
  final Offset position;
  const StormCell({
    required this.id,
    required this.cellType,
    required this.position,
  });
}

/// A socket an Airwing drops a storm-cell into. A filled socket energizes
/// [energizesNodeId] as a latching circuit source. A [requiresHeat] socket
/// (the anvil) ignites only once a Fire creature heats the cell sitting on it
/// (Air+Fire→Lightning births the Thundercloud).
class CellSocket {
  final String id;
  final Offset position;
  final String energizesNodeId;
  final bool requiresHeat;
  const CellSocket({
    required this.id,
    required this.position,
    required this.energizesNodeId,
    this.requiresHeat = false,
  });
}

/// A fulminate vat (S1's negative constraint): a cauldron of volatile
/// charge-salts the pylon-hall bolt must NEVER cross. A beam lying on a vat
/// cooks it — after a short seething fuse it detonates (spark wisps) and the
/// dynamo TRIPS dark for safety. The vats are what make the four-conductor
/// threading provably unique (a brute-force solver in the layout test
/// asserts exactly one satisfying orientation set).
class FulminateVat {
  final String id;
  final Offset position;
  const FulminateVat({required this.id, required this.position});
}

/// One selectable output trunk of the ZERO-SUM dynamo (Lightning rework,
/// docs §6.3): the dynamo feeds exactly ONE trunk at a time. Charging a
/// trunk's breaker at the dynamo latches its wing live and de-latches every
/// other — powered barriers, lights and door states follow, and unpowered
/// wings stay walkable but dark (spark wisps prowl the dead segments).
class DynamoTrunk {
  final String id;

  /// Short all-caps label for the progress readout ('PYLON TRUNK').
  final String name;

  /// The breaker pylon's position in the dynamo room (room-local).
  final Offset breakerPosition;

  /// The wing rooms this trunk lights.
  final List<String> roomIds;

  /// Once this star banks the wing freezes LIT forever (solved is solved —
  /// the same rule the circuit rooms already obey). Null = never freezes
  /// (the vault trunk stays zero-sum for good).
  final int? freezeLitStarIndex;

  const DynamoTrunk({
    required this.id,
    required this.name,
    required this.breakerPosition,
    required this.roomIds,
    this.freezeLitStarIndex,
  });
}

// ── Steam (the Molten Labyrinth): a spreading-lava containment puzzle ────────
// The Steam planet's signature. Each star room is a tile grid the trio reshapes:
//   • FIRE melts a rock wall → LAVA. This IS the Earth+Fire→Lava braid — a
//     Fire heart breaks the earthen rock and its fire-blood runs free.
//   • STEAM cools LAVA → standing rock you can walk on (and HALTS its creep).
//   • EARTH raises a wall on open floor → DAMS the flood.
// Every beat, each LAVA cell creeps into its open neighbours. The strategy is
// the ORDER: dam before you melt, cool ahead of the creep, or the flood reaches
// the pedestal (or you) first.

/// A molten-labyrinth grid for one room. Authored as [rows] of equal-length
/// strings (one char per cell); the engine sizes the cells to fill the room's
/// bounds. Legend:
///   '.' open floor   '#' meltable rock wall   'X' bedrock (never melts)
///   'L' lava (molten at start)   'P' the goal pedestal (open)
/// Reaching the pedestal banks [starIndex]; a null [starIndex] instead performs
/// the guardian RITE (the engine-room grid that wakes the guardian).
class MoltenGrid {
  final List<String> rows;
  final int? starIndex;
  const MoltenGrid({required this.rows, this.starIndex});
  int get cols => rows.isEmpty ? 0 : rows.first.length;
  int get rowCount => rows.length;
}

/// A clamped ring-main junction (Steam): the door from this room to
/// [targetRoomId] stays sealed until [cost] boiler pressure is spent to
/// unclamp it. Paid seals stay open for the run; death re-clamps them.
/// Declared on BOTH sides of the junction — paying either side opens both.
class PressureSeal {
  final String targetRoomId;
  final int cost;
  const PressureSeal({required this.targetRoomId, required this.cost});
}

/// The burst-disc wall (Steam) hiding the vault: venting the main dumps ALL
/// current pressure into the disc; at or above [threshold] it blows and the
/// passage to [targetRoomId] stands open for the run.
class BurstDisc {
  final Offset position;
  final int threshold;
  final String targetRoomId;
  const BurstDisc({
    required this.position,
    required this.threshold,
    required this.targetRoomId,
  });
}

/// A single room. All coordinates are room-local world space (origin top-left).
class DungeonRoom {
  final String id;
  final Rect bounds; // playable area; creatures are clamped inside
  final List<Rect> walls; // solid obstacles (AABB collision)
  final List<DungeonDoor> doors;
  final List<Rect> hazards; // contact damages the active creature
  final List<DungeonStarPickup> stars; // legacy placeholder rewards
  // Slice-3 authored interactables:
  final List<DungeonGap> gaps;
  // Open-sky rooms: solid landing islands; everything else is sky (fly-only).
  final List<Rect> platforms;
  final List<WindCurrent> currents;
  final List<SkyRing> rings;
  final SpireSummit? summit;
  final List<HiddenCloud> clouds;
  final List<LoomAnchor> anchors;
  final int? loomStarIndex; // star awarded when all anchors are satisfied
  final List<Conduit> conduits;
  final GuardianNode? guardian;
  // Fire (Cinder Cathedral) authored interactables:
  final List<RitualBrazier> braziers;
  final int? brazierStarIndex; // star awarded for the full lit sequence
  final List<VineBed> vineBeds;
  final int? vineStarIndex; // star awarded when every bed's sigil is revealed
  final List<IncenseChain> incenseChains;
  // Water (Mirror Tide) authored interactables:
  final List<TideValve> tideValves;
  final List<TideSeal> tideSeals;
  final int? sealStarIndex; // star awarded when every sluice seal is open
  final List<GhostEddy> ghostEddies;
  final int? eddyStarIndex; // star awarded for riding the full current
  final List<MoonPool> moonPools;
  final List<TideZone> tideZones;
  final List<TideDoorRule> tideDoorRules;
  /// The vault cache: every dungeon's treasure room holds one — walking to
  /// it makes the planet's essence FIZZLE into the air and grants 5 gold,
  /// once ever (persisted via the `cache:` discovery channel).
  final Offset? vaultCache;
  // Earth (Buried Giant) authored interactables:
  final List<FossilRib> fossilRibs;
  final Rect? ribChasm; // impassable marrow pit, bridged by settled ribs
  final Rect? sternumPlate; // Star 1 banks here once the bridge is whole
  final int? ribStarIndex;
  final List<FossilPillar> fossilPillars;
  final int? pillarStarIndex; // star awarded when every socket is locked
  final StoneScale? stoneScale;
  // Lightning (Storm Circuit) authored interactables:
  final List<CircuitNode> circuitNodes;
  final int? circuitStarIndex; // banked when every sink in this room is live
  final List<PoweredBarrier> poweredBarriers;
  final List<StormCell> stormCells;
  final List<CellSocket> cellSockets;
  // Storm-Spire beam puzzle:
  final List<BeamEmitter> beamEmitters; // Wind Vents (one emits per stationed Air)
  final List<BeamMirror> beamMirrors;
  final List<Offset> beamConverters; // Fire-converter spots (only some on a path)
  final Offset? beamReceiver; // the Storm Tower (lit only by the lightning beam)
  final List<Offset> beamReceivers; // S1 terminals: ALL must lie on the beam
  final List<FulminateVat> fulminateVats; // S1 negative constraints
  /// The vault bolt (zero-sum rework): a barrier that stands while this
  /// room's trunk is POWERED and falls open in the dark — the treasury
  /// answers only to a dead trunk, walked in the dark.
  final Rect? vaultBolt;
  /// The grounding spike (storm core): a Lightning creature grounds the
  /// core trunk here mid-fight — Raikuma FEEDS on its powered trunk and
  /// only offers the lull while the trunk is dead.
  final Offset? coreBreaker;
  // Steam (the Molten Labyrinth) authored content:
  final MoltenGrid? molten; // a star room's spreading-lava grid
  final Offset? steamVent; // the entry-gate relief vent (Steam cracks it)
  final List<PressureSeal> pressureSeals; // clamped ring-main junction doors
  final Offset? stokePort; // firebox: Fire stokes the main (+pressure, +wisps)
  final BurstDisc? burstDisc; // vault passage blown open by venting the main

  const DungeonRoom({
    required this.id,
    required this.bounds,
    this.walls = const [],
    this.doors = const [],
    this.hazards = const [],
    this.stars = const [],
    this.gaps = const [],
    this.platforms = const [],
    this.currents = const [],
    this.rings = const [],
    this.summit,
    this.clouds = const [],
    this.anchors = const [],
    this.loomStarIndex,
    this.conduits = const [],
    this.guardian,
    this.braziers = const [],
    this.brazierStarIndex,
    this.vineBeds = const [],
    this.vineStarIndex,
    this.incenseChains = const [],
    this.tideValves = const [],
    this.tideSeals = const [],
    this.sealStarIndex,
    this.ghostEddies = const [],
    this.eddyStarIndex,
    this.moonPools = const [],
    this.tideZones = const [],
    this.tideDoorRules = const [],
    this.vaultCache,
    this.fossilRibs = const [],
    this.ribChasm,
    this.sternumPlate,
    this.ribStarIndex,
    this.fossilPillars = const [],
    this.pillarStarIndex,
    this.stoneScale,
    this.circuitNodes = const [],
    this.circuitStarIndex,
    this.poweredBarriers = const [],
    this.stormCells = const [],
    this.cellSockets = const [],
    this.beamEmitters = const [],
    this.beamMirrors = const [],
    this.beamConverters = const [],
    this.beamReceiver,
    this.beamReceivers = const [],
    this.fulminateVats = const [],
    this.vaultBolt,
    this.coreBreaker,
    this.molten,
    this.steamVent,
    this.pressureSeals = const [],
    this.stokePort,
    this.burstDisc,
  });
}

/// A hard family gate: the object needs element + a SPECIFIC family, not just
/// any creature of that element (§4 "FAMILY-GATED interactions" in
/// docs/dungeons.md). Declared here — rather than inline in the engine — so
/// the overworld descent panel can name the requirement without importing
/// engine internals, and so "the seal remembers" can derive a stable,
/// human-readable discovery id.
class DungeonFamilyGate {
  /// Cross-reference to the underlying puzzle object (a Conduit's id 'A', the
  /// logical 'rib' track, the 'pipe_mouth' valve) — for engine lookup and
  /// docs/debug, never persisted.
  final String objectId;

  /// The element this gate answers to (one of the planet's three
  /// kCosmicPlanetEntry slots).
  final String element;

  /// The required family, matching CreatureFamily / FamilyColors keys
  /// ('Horn', 'Pip', 'Wing', 'Mane', 'Mask', 'Kin', 'Let').
  final String family;

  /// The §5.6 BLOCKED line spoken on a wrong-family attempt — one short
  /// clause naming exactly what is missing, element-first.
  final String hintLine;

  const DungeonFamilyGate({
    required this.objectId,
    required this.element,
    required this.family,
    required this.hintLine,
  });

  /// The cloud-discovery id this gate stamps on first contact ("the seal
  /// remembers"). Lower-cased element+family only — stable even if
  /// [objectId]/[hintLine] are later re-authored, and safe under
  /// PlanetStarState's serialisation separators (`,` `=` `.` `|`), which no
  /// discovery id may contain.
  String get discoveryId =>
      'gate:${element.toLowerCase()}_${family.toLowerCase()}';
}

/// A whole planet dungeon: its rooms, where the run begins, and the authored
/// identity the engine composes its copy and door gating from.
class DungeonLayout {
  final String element;
  final Map<String, DungeonRoom> rooms;
  final String entranceRoomId;
  final Offset entranceSpawn;

  /// Full-map header, e.g. 'WIND-CROWN SPIRE'.
  final String title;

  /// Descent intro card, e.g. 'Zephyria Spire'.
  final String descentTitle;

  /// Authored star identities, indexed by star index (length 3).
  final List<DungeonStarSpec> stars;

  /// Door hidden until the entrance puzzle reveals it (null = none).
  final DungeonDoorRef? entranceRevealDoor;

  /// Door locked until the guardian rite unlocks (stars 0+1 banked).
  final DungeonDoorRef? finaleDoor;

  /// Hint when the second of stars 0/1 lands and [finaleDoor] parts.
  final String? riteAnnouncement;

  /// Hint when a creature touches the still-locked [finaleDoor].
  final String? finaleSealedHint;

  /// Room whose centre mends the party once per run (null = none).
  final String? mercyShrineRoomId;

  /// The descent riddle: a short verse shown at the planet (overworld chip +
  /// descend HUD) that cryptically names the IDEAL family for each entry
  /// slot — bringing the right species is a puzzle the player can reason
  /// about BEFORE descending, never a guess.
  final List<String> riddle;

  /// Hard family gates in this dungeon (§4 "the seal remembers"): max one per
  /// star, 1–3 per planet, each tied to a distinct entry slot. First contact
  /// with one permanently stamps its element+family chip onto the overworld
  /// descent panel.
  final List<DungeonFamilyGate> familyGates;

  /// Zero-sum dynamo (Lightning): the hub room holding the trunk breakers.
  final String? dynamoRoomId;

  /// The dynamo's selectable trunks (empty = no zero-sum system; the raid
  /// arena and every other planet leave this empty, so all rooms read lit).
  final List<DynamoTrunk> dynamoTrunks;

  /// The trunk fed when a run begins (the treasury hoards the storm by
  /// default — every star wing starts dark).
  final String? initialTrunkId;

  const DungeonLayout({
    required this.element,
    required this.rooms,
    required this.entranceRoomId,
    required this.entranceSpawn,
    this.title = '',
    this.descentTitle = '',
    this.stars = const [],
    this.entranceRevealDoor,
    this.finaleDoor,
    this.riteAnnouncement,
    this.finaleSealedHint,
    this.mercyShrineRoomId,
    this.riddle = const [],
    this.familyGates = const [],
    this.dynamoRoomId,
    this.dynamoTrunks = const [],
    this.initialTrunkId,
  });

  DungeonRoom get entranceRoom => rooms[entranceRoomId]!;

  /// The declared family gate for puzzle object [objectId], or null when the
  /// object is not gated (or this layout — e.g. a raid arena — has none).
  DungeonFamilyGate? familyGateFor(String objectId) {
    for (final g in familyGates) {
      if (g.objectId == objectId) return g;
    }
    return null;
  }

  /// Star-spec name for [index] ('Star n+1' when unauthored).
  String starName(int index) =>
      index < stars.length ? stars[index].name : 'Star ${index + 1}';

  /// Distinct star indices discoverable in this dungeon (from any source).
  Set<int> get starIndices {
    final seen = <int>{};
    for (final room in rooms.values) {
      for (final s in room.stars) {
        seen.add(s.starIndex);
      }
      if (room.summit != null) seen.add(room.summit!.starIndex);
      if (room.loomStarIndex != null) seen.add(room.loomStarIndex!);
      if (room.guardian != null) seen.add(room.guardian!.starIndex);
      if (room.brazierStarIndex != null) seen.add(room.brazierStarIndex!);
      if (room.vineStarIndex != null) seen.add(room.vineStarIndex!);
      if (room.sealStarIndex != null) seen.add(room.sealStarIndex!);
      if (room.eddyStarIndex != null) seen.add(room.eddyStarIndex!);
      if (room.ribStarIndex != null) seen.add(room.ribStarIndex!);
      if (room.pillarStarIndex != null) seen.add(room.pillarStarIndex!);
      if (room.circuitStarIndex != null) seen.add(room.circuitStarIndex!);
      if (room.molten?.starIndex != null) seen.add(room.molten!.starIndex!);
    }
    return seen;
  }

  /// Number of distinct stars discoverable in this dungeon (≤ 3).
  int get totalStars => starIndices.length;
}

// ─────────────────────────────────────────────────────────
// AUTHORED LAYOUTS
// ─────────────────────────────────────────────────────────

/// Air pilot layout: Wind-Crown Spire. The authored room graph follows the
/// "hub + vertical ascent + optional cloud branches + ritual chamber + storm
/// summit" brief. Gameplay lists stay intentionally simple: platforms/currents
/// drive collision and traversal; clouds/anchors/conduits/guardian drive puzzle
/// logic; rendering interprets the same data procedurally.
const DungeonLayout _airLayout = DungeonLayout(
  element: 'Air',
  entranceRoomId: 'entry',
  entranceSpawn: Offset(220, 290),
  title: 'WIND-CROWN SPIRE',
  descentTitle: 'Zephyria Spire',
  stars: [
    DungeonStarSpec(
      name: 'Wind Star',
      earnAnnouncement:
          'The Wind Star is yours — a passage to the Sky Loom parts below',
      revealDoors: [
        DungeonDoorRef('spire_summit', 'sky_loom'),
        DungeonDoorRef('sky_loom', 'spire_summit'),
      ],
    ),
    DungeonStarSpec(name: 'Loom Star'),
    DungeonStarSpec(name: 'Storm Star'),
  ],
  entranceRevealDoor: DungeonDoorRef('entry', 'hub'),
  finaleDoor: DungeonDoorRef('sky_loom', 'storm_rune_hall'),
  riteAnnouncement:
      'Wind and Loom sing in accord — the storm door in the loom parts',
  finaleSealedHint:
      'The storm door is sealed — it parts only for both the Wind and '
      'Loom stars',
  mercyShrineRoomId: 'storm_altar',
  // Ideal: Airwing · Firemask · Lightninghorn — hinted by VERB, never by
  // body part: flight, insight, the strength to hold a charge.
  riddle: [
    'My crown belongs to those the ground cannot keep;',
    'my storm-walls confide only in sight that pierces the hidden;',
    'and my thunder stays only where the grip is strongest.',
  ],
  // The one marquee lock (§4): Storm-Altar conduit A channels only for a
  // Lightning Horn. First refusal stamps ⚡ HORN onto the descent panel.
  familyGates: [
    DungeonFamilyGate(
      objectId: 'A',
      element: 'Lightning',
      family: 'Horn',
      hintLine: 'Only a Lightning horn\'s grip holds this current',
    ),
  ],
  rooms: {
    // Room A — Entry Island.
    'entry': DungeonRoom(
      id: 'entry',
      bounds: Rect.fromLTWH(0, 0, 720, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(696, 230, 24, 90),
          targetRoomId: 'hub',
          targetSpawn: Offset(120, 330),
        ),
      ],
      currents: [
        WindCurrent(
          rect: Rect.fromLTWH(292, 242, 136, 136),
          dir: Offset(0, -1),
          strength: 0,
        ),
      ],
    ),

    // Room B — Wind Hub / Compass.
    'hub': DungeonRoom(
      id: 'hub',
      bounds: Rect.fromLTWH(0, 0, 920, 680),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 285, 24, 90),
          targetRoomId: 'entry',
          targetSpawn: Offset(650, 280),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(896, 285, 24, 90),
          targetRoomId: 'lower_spire',
          targetSpawn: Offset(250, 850),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(365, 0, 120, 24),
          targetRoomId: 'spiral_cloud',
          targetSpawn: Offset(350, 520),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(580, 0, 120, 24),
          targetRoomId: 'ring_cloud',
          targetSpawn: Offset(350, 520),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(408, 656, 120, 24),
          targetRoomId: 'sky_loom',
          targetSpawn: Offset(500, 100),
        ),
      ],
    ),

    // Room C — Lower Spire Path.
    'lower_spire': DungeonRoom(
      id: 'lower_spire',
      bounds: Rect.fromLTWH(0, 0, 760, 980),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(190, 900, 120, 30),
          targetRoomId: 'hub',
          targetSpawn: Offset(845, 330),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(40, 430, 30, 120),
          targetRoomId: 'feather_cloud',
          targetSpawn: Offset(620, 270),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(560, 70, 120, 30),
          targetRoomId: 'crosswind_hall',
          targetSpawn: Offset(90, 300),
        ),
      ],
      platforms: [
        Rect.fromLTWH(140, 820, 260, 110),
        Rect.fromLTWH(95, 620, 210, 80),
        Rect.fromLTWH(415, 430, 210, 80),
        Rect.fromLTWH(485, 70, 220, 95),
      ],
      currents: [
        WindCurrent(
          rect: Rect.fromLTWH(205, 610, 220, 300),
          dir: Offset(0, -1),
          strength: 70,
        ),
        WindCurrent(
          rect: Rect.fromLTWH(170, 410, 360, 180),
          dir: Offset(0.5, -1),
          strength: 78,
        ),
        // Thermal column up the west face: walkers ride it from platform 1
        // to the feather-chamber door (which floats over open sky).
        WindCurrent(
          rect: Rect.fromLTWH(50, 430, 130, 430),
          dir: Offset(0, -1),
          strength: 85,
        ),
      ],
      rings: [SkyRing(order: 0, position: Offset(310, 735))],
    ),

    // Room D — Crosswind Hall.
    'crosswind_hall': DungeonRoom(
      id: 'crosswind_hall',
      bounds: Rect.fromLTWH(0, 0, 980, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 250, 30, 100),
          targetRoomId: 'lower_spire',
          targetSpawn: Offset(560, 120),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(900, 250, 30, 100),
          targetRoomId: 'cloud_platforms',
          targetSpawn: Offset(245, 820),
        ),
      ],
      platforms: [
        Rect.fromLTWH(55, 255, 180, 85),
        Rect.fromLTWH(285, 235, 180, 85),
        Rect.fromLTWH(520, 270, 180, 85),
        Rect.fromLTWH(760, 245, 180, 85),
      ],
      currents: [
        WindCurrent(
          rect: Rect.fromLTWH(210, 120, 610, 110),
          dir: Offset(1, 0.1),
          strength: 92,
          requiredSpeed: 2.5,
        ),
        WindCurrent(
          rect: Rect.fromLTWH(180, 360, 640, 95),
          dir: Offset(-1, -0.1),
          strength: 88,
          requiredSpeed: 2.5,
        ),
      ],
      rings: [SkyRing(order: 1, position: Offset(490, 280))],
    ),

    // Room E — Cloud Platform Room.
    'cloud_platforms': DungeonRoom(
      id: 'cloud_platforms',
      bounds: Rect.fromLTWH(0, 0, 720, 940),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(185, 850, 120, 30),
          targetRoomId: 'crosswind_hall',
          targetSpawn: Offset(840, 290),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(360, 60, 120, 30),
          targetRoomId: 'spire_summit',
          targetSpawn: Offset(380, 470),
        ),
      ],
      platforms: [
        Rect.fromLTWH(150, 780, 210, 90),
        Rect.fromLTWH(420, 600, 170, 76),
        Rect.fromLTWH(100, 430, 185, 76),
        Rect.fromLTWH(380, 240, 170, 76),
        Rect.fromLTWH(315, 60, 220, 86),
      ],
      currents: [
        WindCurrent(
          rect: Rect.fromLTWH(255, 535, 240, 300),
          dir: Offset(0, -1),
          strength: 105,
          requiredSpeed: 3.0,
        ),
        WindCurrent(
          rect: Rect.fromLTWH(245, 155, 260, 300),
          dir: Offset(0, -1),
          strength: 130,
          requiredSpeed: 3.5,
        ),
      ],
      rings: [SkyRing(order: 2, position: Offset(420, 205))],
    ),

    // Room F — Spire Summit.
    'spire_summit': DungeonRoom(
      id: 'spire_summit',
      bounds: Rect.fromLTWH(0, 0, 760, 620),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(320, 560, 120, 30),
          targetRoomId: 'cloud_platforms',
          targetSpawn: Offset(405, 115),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(700, 255, 30, 110),
          targetRoomId: 'sky_loom',
          targetSpawn: Offset(115, 390),
        ),
      ],
      summit: SpireSummit(
        rect: Rect.fromLTWH(275, 225, 210, 130),
        starIndex: 0,
      ),
    ),

    // Room G — Spiral Cloud Room.
    'spiral_cloud': DungeonRoom(
      id: 'spiral_cloud',
      bounds: Rect.fromLTWH(0, 0, 700, 620),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(290, 586, 120, 30),
          targetRoomId: 'hub',
          targetSpawn: Offset(425, 70),
        ),
      ],
      clouds: [
        HiddenCloud(
          id: 'c_spiral',
          cloudType: 'Spiral',
          position: Offset(350, 285),
        ),
      ],
    ),

    // Room H — Ring Cloud Room.
    'ring_cloud': DungeonRoom(
      id: 'ring_cloud',
      bounds: Rect.fromLTWH(0, 0, 700, 620),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(290, 586, 120, 30),
          targetRoomId: 'hub',
          targetSpawn: Offset(640, 70),
        ),
      ],
      clouds: [
        HiddenCloud(
          id: 'c_ring',
          cloudType: 'Ring',
          position: Offset(350, 285),
        ),
      ],
    ),

    // Room I — Anvil Cloud Room. Entered DOWNWARD from the loom, so its
    // return door sits on the TOP edge (descend → arrive at the top).
    'anvil_cloud': DungeonRoom(
      id: 'anvil_cloud',
      bounds: Rect.fromLTWH(0, 0, 760, 620),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(320, 0, 120, 24),
          targetRoomId: 'sky_loom',
          targetSpawn: Offset(295, 670),
        ),
      ],
      clouds: [
        HiddenCloud(
          id: 'c_anvil',
          cloudType: 'Anvil',
          position: Offset(380, 285),
        ),
      ],
      currents: [
        WindCurrent(
          rect: Rect.fromLTWH(525, 210, 150, 100),
          dir: Offset(1, 0),
          strength: 0,
        ),
      ],
    ),

    // Room J — Feather Cloud Room.
    'feather_cloud': DungeonRoom(
      id: 'feather_cloud',
      bounds: Rect.fromLTWH(0, 0, 760, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(730, 250, 30, 100),
          targetRoomId: 'lower_spire',
          targetSpawn: Offset(505, 470),
        ),
      ],
      platforms: [Rect.fromLTWH(80, 215, 575, 95)],
      clouds: [
        HiddenCloud(
          id: 'c_feather',
          cloudType: 'Feather',
          position: Offset(320, 255),
        ),
      ],
    ),

    // Room K — Veil Cloud Room. Entered DOWNWARD from the loom, so its
    // return door sits on the TOP edge (descend → arrive at the top).
    'veil_cloud': DungeonRoom(
      id: 'veil_cloud',
      bounds: Rect.fromLTWH(0, 0, 760, 620),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(320, 0, 120, 24),
          targetRoomId: 'sky_loom',
          targetSpawn: Offset(715, 670),
        ),
      ],
      clouds: [
        HiddenCloud(
          id: 'c_veil',
          cloudType: 'Veil',
          position: Offset(380, 285),
        ),
      ],
    ),

    // Room S — Sky Loom Chamber.
    'sky_loom': DungeonRoom(
      id: 'sky_loom',
      bounds: Rect.fromLTWH(0, 0, 1000, 760),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(445, 0, 120, 24),
          targetRoomId: 'hub',
          targetSpawn: Offset(465, 610),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 335, 24, 100),
          targetRoomId: 'spire_summit',
          targetSpawn: Offset(660, 305),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(235, 736, 120, 24),
          targetRoomId: 'anvil_cloud',
          targetSpawn: Offset(380, 86),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(655, 736, 120, 24),
          targetRoomId: 'veil_cloud',
          targetSpawn: Offset(380, 86),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(976, 220, 24, 100),
          targetRoomId: 'relic_chamber',
          targetSpawn: Offset(110, 310),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(976, 445, 24, 100),
          targetRoomId: 'storm_rune_hall',
          targetSpawn: Offset(90, 280),
        ),
      ],
      currents: [
        // The weaving stream — charge an Anvil here (air+fire) into a
        // Thundercloud. Strength 0: it's the medium, not a push.
        WindCurrent(
          rect: Rect.fromLTWH(405, 515, 220, 90),
          dir: Offset(1, 0),
          strength: 0,
        ),
      ],
      clouds: [
        HiddenCloud(
          id: 'c_spiral',
          cloudType: 'Spiral',
          position: Offset(175, 585),
        ),
        HiddenCloud(
          id: 'c_ring',
          cloudType: 'Ring',
          position: Offset(825, 585),
        ),
        HiddenCloud(
          id: 'c_anvil',
          cloudType: 'Anvil',
          position: Offset(505, 650),
        ),
        HiddenCloud(
          id: 'c_feather',
          cloudType: 'Feather',
          position: Offset(255, 350),
        ),
        HiddenCloud(
          id: 'c_veil',
          cloudType: 'Veil',
          position: Offset(745, 350),
        ),
      ],
      anchors: [
        LoomAnchor(
          id: 'a_spiral',
          requiredCloudType: 'Spiral',
          position: Offset(240, 160),
          clue: 'the eye of the gale',
        ),
        LoomAnchor(
          id: 'a_ring',
          requiredCloudType: 'Ring',
          position: Offset(370, 118),
          clue: 'the endless orbit',
        ),
        LoomAnchor(
          id: 'a_feather',
          requiredCloudType: 'Feather',
          position: Offset(500, 95),
          clue: 'the weightless wing',
        ),
        LoomAnchor(
          id: 'a_veil',
          requiredCloudType: 'Veil',
          position: Offset(630, 118),
          clue: 'the hidden shroud',
        ),
        LoomAnchor(
          id: 'a_thunder',
          requiredCloudType: 'Thundercloud',
          position: Offset(760, 160),
          clue: 'the storm-heart — charge an anvil',
        ),
      ],
      loomStarIndex: 1,
    ),

    // Relic Chamber — Star 2 reward space.
    'relic_chamber': DungeonRoom(
      id: 'relic_chamber',
      bounds: Rect.fromLTWH(0, 0, 640, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 265, 24, 90),
          targetRoomId: 'sky_loom',
          targetSpawn: Offset(930, 270),
        ),
      ],
      vaultCache: Offset(320, 280),
    ),

    // Room L — Storm Rune Hall.
    'storm_rune_hall': DungeonRoom(
      id: 'storm_rune_hall',
      bounds: Rect.fromLTWH(0, 0, 840, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 240, 24, 100),
          targetRoomId: 'sky_loom',
          targetSpawn: Offset(930, 495),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(816, 240, 24, 100),
          targetRoomId: 'twin_conduit',
          targetSpawn: Offset(90, 330),
        ),
      ],
    ),

    // Room M — Twin Conduit Room.
    'twin_conduit': DungeonRoom(
      id: 'twin_conduit',
      bounds: Rect.fromLTWH(0, 0, 900, 660),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 285, 24, 100),
          targetRoomId: 'storm_rune_hall',
          targetSpawn: Offset(760, 290),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(876, 285, 24, 100),
          targetRoomId: 'storm_altar',
          targetSpawn: Offset(100, 350),
        ),
      ],
      currents: [
        // The stream crossing conduit B — a Fire creature acting here lights
        // the arc.
        WindCurrent(
          rect: Rect.fromLTWH(570, 285, 210, 90),
          dir: Offset(-1, 0),
          strength: 0,
        ),
      ],
      conduits: [
        Conduit(
          id: 'A',
          position: Offset(230, 330),
          requireElement: 'Lightning',
          // HARD GATE: only a Lightning Horn holds this current.
          requiredFamily: DungeonAbility.heavyForce,
        ),
        Conduit(
          id: 'B',
          position: Offset(670, 330),
          requireElement: 'Fire', // arc-lit by Fire in the wind current
        ),
      ],
    ),

    // Room N — Storm Altar Arena.
    'storm_altar': DungeonRoom(
      id: 'storm_altar',
      bounds: Rect.fromLTWH(0, 0, 820, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 310, 24, 100),
          targetRoomId: 'twin_conduit',
          targetSpawn: Offset(820, 335),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(360, 0, 120, 24),
          targetRoomId: 'guardian_summit',
          targetSpawn: Offset(390, 590),
        ),
      ],
    ),

    // Room O — Guardian Summit.
    'guardian_summit': DungeonRoom(
      id: 'guardian_summit',
      bounds: Rect.fromLTWH(0, 0, 820, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(360, 676, 120, 24),
          targetRoomId: 'storm_altar',
          targetSpawn: Offset(410, 70),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(410, 300),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Air',
          mysticId: 'Roc',
          canCalm: true,
          canDefeat: true,
        ),
      ),
    ),
  },
);

/// Fire layout: Cinder Cathedral. *Fire remembers the order it was lit.* A
/// soot-black gothic interior on the planet Pyrathis: a cold narthex hearth
/// guards the way in; the nave is the hub under a rose window of ember glass.
/// Star 1 (Ember) — the choir's four braziers must be lit in the order the
/// cathedral remembers (the scriptorium's soot mural diagrams it; a Mask
/// reads it). Star 2 (Ash) — the cloister's scorched beds: Plant grows vines,
/// Fire burns them, the settling ash reveals the sigils cut beneath
/// (Plant+Fire→Dust). Star 3 (Pyre) — beyond the sealed chancel gate, flame
/// is carried along hanging incense chains by gusts of Air until all three
/// ember bells toll, waking the black-flame Simurgh in the sanctum.
const DungeonLayout _fireLayout = DungeonLayout(
  element: 'Fire',
  entranceRoomId: 'narthex',
  entranceSpawn: Offset(180, 270),
  title: 'CINDER CATHEDRAL',
  descentTitle: 'Pyrathis Cathedral',
  stars: [
    DungeonStarSpec(
      name: 'Ember Star',
      earnAnnouncement:
          'The Ember Star is yours — the braziers keep their ancient vigil',
    ),
    DungeonStarSpec(
      name: 'Ash Star',
      earnAnnouncement:
          'The Ash Star is yours — every sigil burns in its groove',
    ),
    DungeonStarSpec(name: 'Pyre Star'),
  ],
  entranceRevealDoor: DungeonDoorRef('narthex', 'nave'),
  finaleDoor: DungeonDoorRef('nave', 'vestry'),
  riteAnnouncement:
      'Ember and Ash burn in accord — the chancel gate swings wide',
  finaleSealedHint:
      'The chancel gate is sealed — it parts only for both the Ember and '
      'Ash stars',
  mercyShrineRoomId: 'high_altar',
  // Ideal: Firemask · Plantmane · Airwing — hinted by VERB, never by body
  // part: insight, the trail-leaving passage, flight.
  riddle: [
    'My choir answers the one who reads ash as scripture;',
    'my garden greens only along a wild thing\'s passing;',
    'and my censer-flame follows whoever shepherds the wind.',
  ],
  rooms: {
    // Room A — Narthex. The cathedral's cold porch: the great hearth has not
    // burned in an age. A Fire creature rekindling it parts the inner doors
    // (the one-time entry reveal, persisted like Air's entry rune).
    'narthex': DungeonRoom(
      id: 'narthex',
      bounds: Rect.fromLTWH(0, 0, 720, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(696, 225, 24, 90),
          targetRoomId: 'nave',
          targetSpawn: Offset(120, 330),
        ),
      ],
      // A brazier with no star index = a standalone hearth (the entry rite).
      braziers: [RitualBrazier(order: 0, position: Offset(330, 265))],
    ),

    // Room B — Nave (hub). Columns, candle rows, the rose window. The sealed
    // chancel gate (finale) is visible from here from the first minute.
    'nave': DungeonRoom(
      id: 'nave',
      bounds: Rect.fromLTWH(0, 0, 960, 680),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 285, 24, 90),
          targetRoomId: 'narthex',
          targetSpawn: Offset(630, 270),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(170, 0, 110, 24),
          targetRoomId: 'scriptorium',
          targetSpawn: Offset(320, 415),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(936, 285, 24, 90),
          targetRoomId: 'choir',
          targetSpawn: Offset(110, 320),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(425, 656, 110, 24),
          targetRoomId: 'cloister',
          targetSpawn: Offset(410, 120),
        ),
        // The chancel gate — locked until both the Ember and Ash stars bank.
        DungeonDoor(
          rect: Rect.fromLTWH(610, 0, 110, 24),
          targetRoomId: 'vestry',
          targetSpawn: Offset(420, 430),
        ),
      ],
    ),

    // Room C — Scriptorium. The soot mural: the order the first fires were
    // lit, drawn in ash strokes only insight can stabilise. (Render + Mask
    // logic; no collidables needed.)
    'scriptorium': DungeonRoom(
      id: 'scriptorium',
      bounds: Rect.fromLTWH(0, 0, 640, 520),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(265, 496, 110, 24),
          targetRoomId: 'nave',
          targetSpawn: Offset(225, 90),
        ),
      ],
    ),

    // Room D — Choir. Star 1: six ritual braziers around the choir stalls.
    // Their remembered order is deliberately NOT spatial: the rite walks the
    // floor like a flame dancing between the stalls. A cryptic soot mural on
    // the choir floor diagrams it (a faint ember walks the true order); the
    // scriptorium's mural is the explicit key (Mask reads it whole).
    'choir': DungeonRoom(
      id: 'choir',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 275, 24, 90),
          targetRoomId: 'nave',
          targetSpawn: Offset(880, 330),
        ),
      ],
      braziers: [
        RitualBrazier(order: 5, position: Offset(450, 145)),
        RitualBrazier(order: 3, position: Offset(260, 205)),
        RitualBrazier(order: 1, position: Offset(640, 205)),
        RitualBrazier(order: 0, position: Offset(195, 430)),
        RitualBrazier(order: 4, position: Offset(705, 430)),
        RitualBrazier(order: 2, position: Offset(450, 535)),
      ],
      brazierStarIndex: 0,
    ),

    // Room E — Cloister. Star 2: the ash garden. Four scorched beds around a
    // dry fountain; Plant overgrows a bed, Fire burns it to ash, and the ash
    // settles into the groove of a buried sigil (Plant+Fire→Dust).
    'cloister': DungeonRoom(
      id: 'cloister',
      bounds: Rect.fromLTWH(0, 0, 820, 740),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(355, 0, 110, 24),
          targetRoomId: 'nave',
          targetSpawn: Offset(478, 580),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(796, 330, 24, 90),
          targetRoomId: 'reliquary',
          targetSpawn: Offset(110, 280),
        ),
      ],
      vineBeds: [
        VineBed(id: 'bed_nw', position: Offset(195, 215)),
        VineBed(id: 'bed_ne', position: Offset(625, 215)),
        VineBed(id: 'bed_sw', position: Offset(195, 565)),
        VineBed(id: 'bed_se', position: Offset(625, 565)),
      ],
      vineStarIndex: 1,
    ),

    // Room F — Reliquary. The cathedral's quiet treasury (reward space).
    'reliquary': DungeonRoom(
      id: 'reliquary',
      bounds: Rect.fromLTWH(0, 0, 640, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 235, 24, 90),
          targetRoomId: 'cloister',
          targetSpawn: Offset(700, 375),
        ),
      ],
      vaultCache: Offset(320, 280),
    ),

    // Room G — Vestry. The finale wing's reading room: a charred fresco
    // diagrams the vesper (flame carried along the chains by wind).
    'vestry': DungeonRoom(
      id: 'vestry',
      bounds: Rect.fromLTWH(0, 0, 840, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(370, 536, 110, 24),
          targetRoomId: 'nave',
          targetSpawn: Offset(665, 110),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(816, 245, 24, 90),
          targetRoomId: 'bell_gallery',
          targetSpawn: Offset(100, 380),
        ),
      ],
    ),

    // Room H — Bell Gallery. Star 3's rite: three incense chains hang across
    // the gallery, each ending at an ember bell. Fire lights a chain's first
    // censer; gusts of Air carry the crawling flame censer to censer; the
    // flame reaching the bell rings it. Three tolls wake the sanctum.
    'bell_gallery': DungeonRoom(
      id: 'bell_gallery',
      bounds: Rect.fromLTWH(0, 0, 1000, 760),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 335, 24, 90),
          targetRoomId: 'vestry',
          targetSpawn: Offset(740, 290),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(976, 335, 24, 90),
          targetRoomId: 'high_altar',
          targetSpawn: Offset(105, 310),
        ),
      ],
      incenseChains: [
        IncenseChain(
          id: 'chain_low',
          nodes: [Offset(180, 615), Offset(330, 655), Offset(480, 620)],
          bellPosition: Offset(625, 590),
        ),
        IncenseChain(
          id: 'chain_mid',
          nodes: [Offset(200, 385), Offset(360, 335), Offset(520, 375)],
          bellPosition: Offset(680, 335),
        ),
        IncenseChain(
          id: 'chain_high',
          nodes: [Offset(220, 155), Offset(400, 115), Offset(580, 155)],
          bellPosition: Offset(755, 180),
        ),
      ],
    ),

    // Room I — High Altar. The black-flame altar; its mercy mends the party
    // once per run before the sanctum above.
    'high_altar': DungeonRoom(
      id: 'high_altar',
      bounds: Rect.fromLTWH(0, 0, 820, 620),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 270, 24, 90),
          targetRoomId: 'bell_gallery',
          targetSpawn: Offset(880, 380),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(355, 0, 110, 24),
          targetRoomId: 'sanctum',
          targetSpawn: Offset(410, 560),
        ),
      ],
    ),

    // Room J — Sanctum. The Simurgh's roost above the high altar.
    'sanctum': DungeonRoom(
      id: 'sanctum',
      bounds: Rect.fromLTWH(0, 0, 820, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(355, 676, 110, 24),
          targetRoomId: 'high_altar',
          targetSpawn: Offset(410, 110),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(410, 290),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Fire',
          mysticId: 'Simurgh',
          canCalm: true,
          canDefeat: true,
        ),
      ),
    ),
  },
);

/// Water layout: the Mirror-Tide Temple on Aquathos. *Every chamber answers
/// to one temple-wide tide* — low, mid or high — and the tide MOVES: floods
/// and drains are animated, reshaping walkways, walls and doors while you
/// watch. Star 1 (Tide) — restore the tide-works: open three sluice seals,
/// each reachable only at one tide stand. Star 2 (Current) — the ghost
/// gallery: Spirit insight bares an invisible current; wade its five eddies
/// in order. Star 3 (Deep) — beyond the sealed mirror gate: at MID tide,
/// freeze the two TRUE moon-pools (Ice directly, or Spirit acting in the
/// water — Spirit+Water→Ice) into bridge-discs; the well wakes Leviathan.
const DungeonLayout _waterLayout = DungeonLayout(
  element: 'Water',
  entranceRoomId: 'tide_gate',
  entranceSpawn: Offset(180, 270),
  title: 'MIRROR-TIDE TEMPLE',
  descentTitle: 'Aquathos Temple',
  stars: [
    DungeonStarSpec(
      name: 'Tide Star',
      earnAnnouncement:
          'The Tide Star is yours — the sluices remember the sea',
    ),
    DungeonStarSpec(
      name: 'Current Star',
      earnAnnouncement:
          'The Current Star is yours — the ghost-water knows its course',
    ),
    DungeonStarSpec(name: 'Deep Star'),
  ],
  entranceRevealDoor: DungeonDoorRef('tide_gate', 'drowned_court'),
  finaleDoor: DungeonDoorRef('drowned_court', 'moon_hall'),
  riteAnnouncement:
      'Tide and Current flow in accord — the mirror gate parts',
  finaleSealedHint:
      'The mirror gate is sealed — it parts only for both the Tide and '
      'Current stars',
  mercyShrineRoomId: 'moon_well',
  // Ideal: Waterpip · Spiritmask · Icemane — hinted by VERB, never by body
  // part: small access, second sight, the road-paving passage.
  riddle: [
    'My pipes open only to what my smallest doors admit;',
    'my drowned currents bare themselves to second sight;',
    'and my moon waits on a cold that paves a road behind it.',
  ],
  // The one marquee lock (§4): the moon-well pipe-mouth admits only a Water
  // Pip. First refusal stamps the requirement onto the descent panel.
  familyGates: [
    DungeonFamilyGate(
      objectId: 'pipe_mouth',
      element: 'Water',
      family: 'Pip',
      hintLine: 'Only a Water pip slips down this pipe-mouth',
    ),
  ],
  rooms: {
    // Room A — Tide Gate. The temple's outer porch: a dry offering-bowl.
    // A Water creature filling it parts the inner doors (one-time reveal).
    'tide_gate': DungeonRoom(
      id: 'tide_gate',
      bounds: Rect.fromLTWH(0, 0, 720, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(696, 225, 24, 90),
          targetRoomId: 'drowned_court',
          targetSpawn: Offset(120, 330),
        ),
      ],
    ),

    // Room B — Drowned Court (hub). The flooded forum under the moon; the
    // sealed mirror gate (finale) is visible from the first minute.
    'drowned_court': DungeonRoom(
      id: 'drowned_court',
      bounds: Rect.fromLTWH(0, 0, 960, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 285, 24, 90),
          targetRoomId: 'tide_gate',
          targetSpawn: Offset(630, 270),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(170, 0, 110, 24),
          targetRoomId: 'tide_works',
          targetSpawn: Offset(450, 560),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(936, 305, 24, 90),
          targetRoomId: 'ghost_gallery',
          targetSpawn: Offset(110, 360),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(425, 676, 110, 24),
          targetRoomId: 'reflection_court',
          targetSpawn: Offset(320, 120),
        ),
        // The mirror gate — locked until the Tide and Current stars bank.
        DungeonDoor(
          rect: Rect.fromLTWH(610, 0, 110, 24),
          targetRoomId: 'moon_hall',
          targetSpawn: Offset(420, 430),
        ),
      ],
      // The court's central basin: drained mosaic floor at low tide,
      // shallows from mid up.
      tideZones: [
        TideZone(rect: Rect.fromLTWH(300, 250, 360, 220), floodedAt: 1),
      ],
    ),

    // Room C — Tide-Works. Star 1: three master valves command the temple
    // tide; three sluice seals each yield at exactly one stand of water.
    'tide_works': DungeonRoom(
      id: 'tide_works',
      bounds: Rect.fromLTWH(0, 0, 900, 680),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 656, 110, 24),
          targetRoomId: 'drowned_court',
          targetSpawn: Offset(225, 90),
        ),
      ],
      tideValves: [
        TideValve(position: Offset(160, 190), level: 0),
        TideValve(position: Offset(250, 165), level: 1),
        TideValve(position: Offset(340, 190), level: 2),
      ],
      tideSeals: [
        // In the deep basin — touchable only on the drained floor.
        TideSeal(id: 'seal_low', position: Offset(230, 470), tides: {0}),
        // On the mid walkway east.
        TideSeal(id: 'seal_mid', position: Offset(760, 560), tides: {1}),
        // Past the north ledge — swum over only at high water.
        TideSeal(id: 'seal_high', position: Offset(620, 95), tides: {2}),
      ],
      tideZones: [
        // The great basin (drained floor ↔ shallows ↔ swim).
        TideZone(rect: Rect.fromLTWH(90, 350, 320, 250), floodedAt: 1),
        // The north ledge wall guarding seal_high: solid until high tide.
        TideZone(
          rect: Rect.fromLTWH(480, 150, 300, 70),
          floodedAt: 2,
          ledge: true,
        ),
      ],
      sealStarIndex: 0,
    ),

    // Room D — Ghost Gallery. Star 2: an invisible current circles the
    // gallery; Spirit insight bares it, and its five eddies must be waded
    // in the order the water remembers.
    'ghost_gallery': DungeonRoom(
      id: 'ghost_gallery',
      bounds: Rect.fromLTWH(0, 0, 1000, 720),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 315, 24, 90),
          targetRoomId: 'drowned_court',
          targetSpawn: Offset(880, 350),
        ),
        // The pearl vault's passage drowns above low tide.
        DungeonDoor(
          rect: Rect.fromLTWH(976, 315, 24, 90),
          targetRoomId: 'pearl_vault',
          targetSpawn: Offset(110, 280),
        ),
      ],
      tideDoorRules: [
        TideDoorRule(targetRoomId: 'pearl_vault', tides: {0}),
      ],
      ghostEddies: [
        GhostEddy(order: 0, position: Offset(200, 200)),
        GhostEddy(order: 1, position: Offset(480, 140)),
        GhostEddy(order: 2, position: Offset(760, 240)),
        GhostEddy(order: 3, position: Offset(620, 480)),
        GhostEddy(order: 4, position: Offset(300, 560)),
      ],
      tideZones: [
        TideZone(rect: Rect.fromLTWH(250, 300, 500, 200), floodedAt: 1),
      ],
      eddyStarIndex: 1,
    ),

    // Room E — Pearl Vault. The temple's quiet treasury, dry only at low
    // tide (reward space).
    'pearl_vault': DungeonRoom(
      id: 'pearl_vault',
      bounds: Rect.fromLTWH(0, 0, 640, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 235, 24, 90),
          targetRoomId: 'ghost_gallery',
          targetSpawn: Offset(880, 360),
        ),
      ],
      vaultCache: Offset(320, 280),
    ),

    // Room F — Reflection Court. A still moon-pool (and, at mid tide, a
    // certain glint patient eyes might freeze…).
    'reflection_court': DungeonRoom(
      id: 'reflection_court',
      bounds: Rect.fromLTWH(0, 0, 640, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(265, 0, 110, 24),
          targetRoomId: 'drowned_court',
          targetSpawn: Offset(478, 580),
        ),
      ],
      tideZones: [
        TideZone(rect: Rect.fromLTWH(200, 240, 240, 180), floodedAt: 1),
      ],
    ),

    // Room G — Moon Hall. The finale wing's reading room: a tide-mural
    // diagrams the rite (Spirit insight reads it whole).
    'moon_hall': DungeonRoom(
      id: 'moon_hall',
      bounds: Rect.fromLTWH(0, 0, 840, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(370, 536, 110, 24),
          targetRoomId: 'drowned_court',
          targetSpawn: Offset(665, 110),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(816, 245, 24, 90),
          targetRoomId: 'moon_well',
          targetSpawn: Offset(100, 360),
        ),
      ],
    ),

    // Room H — Moon Well. Star 3's rite: four moon-pools ring the well; at
    // MID tide the TRUE two take the ice and bridge the deep. The well's
    // mercy mends the party once per run.
    'moon_well': DungeonRoom(
      id: 'moon_well',
      bounds: Rect.fromLTWH(0, 0, 900, 720),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 315, 24, 90),
          targetRoomId: 'moon_hall',
          targetSpawn: Offset(740, 290),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'leviathan_depths',
          targetSpawn: Offset(410, 560),
        ),
      ],
      moonPools: [
        MoonPool(id: 'pool_nw', position: Offset(250, 230), isTrue: true),
        MoonPool(id: 'pool_ne', position: Offset(650, 230), isTrue: false),
        MoonPool(id: 'pool_sw', position: Offset(250, 530), isTrue: false),
        MoonPool(id: 'pool_se', position: Offset(650, 530), isTrue: true),
      ],
      // A pipe-mouth so a Pip can retune the tide without the long walk
      // back to the tide-works (cycles one step per slip).
      tideValves: [
        TideValve(position: Offset(450, 640), pipOnly: true),
      ],
      tideZones: [
        TideZone(rect: Rect.fromLTWH(330, 270, 240, 200), floodedAt: 1),
      ],
    ),

    // Room I — Leviathan Depths. The drowned arena above the well.
    'leviathan_depths': DungeonRoom(
      id: 'leviathan_depths',
      bounds: Rect.fromLTWH(0, 0, 820, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(355, 676, 110, 24),
          targetRoomId: 'moon_well',
          targetSpawn: Offset(450, 110),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(410, 290),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Water',
          mysticId: 'Leviathan',
          canCalm: true,
          canDefeat: true,
        ),
      ),
    ),
  },
);

/// Earth layout: the Buried Giant under Terragrim. *The dungeon IS a buried
/// body* — its rooms are anatomy and its bones are the machinery. Star 1
/// (Marrow) — the rib hall: shove three fossil ribs along their carved
/// tracks (track-notch slides, Horn = clean and instant) until they drop
/// into the marrow chasm and become the bridge to the sternum plate. Star 2
/// (Crystal) — the pillar crypt: arc Lightning into four buried sockets
/// (**Earth+Lightning→Crystal** grows each lock; a Crystal creature sets it
/// directly). Star 3 (Heart) — beyond the rite-shut jaw: the giant's crystal
/// eye watches a stone scale; set every weight on its true pan (Crystal
/// insight reads the eye) and Terradon stirs in the heart-chamber.
const DungeonLayout _earthLayout = DungeonLayout(
  element: 'Earth',
  entranceRoomId: 'barrow_gate',
  entranceSpawn: Offset(180, 270),
  title: 'THE BURIED GIANT',
  descentTitle: 'Terragrim Barrow',
  stars: [
    DungeonStarSpec(
      name: 'Marrow Star',
      earnAnnouncement:
          'The Marrow Star is yours — the giant\'s ribs hold the road',
    ),
    DungeonStarSpec(
      name: 'Crystal Star',
      earnAnnouncement:
          'The Crystal Star is yours — every socket burns with new stone',
    ),
    DungeonStarSpec(name: 'Heart Star'),
  ],
  entranceRevealDoor: DungeonDoorRef('barrow_gate', 'sternum_court'),
  finaleDoor: DungeonDoorRef('sternum_court', 'skull_antechamber'),
  riteAnnouncement:
      'Marrow and Crystal wake in accord — the skull\'s jaw grinds open',
  finaleSealedHint:
      'The skull\'s jaw is shut — it opens only for both the Marrow and '
      'Crystal stars',
  mercyShrineRoomId: 'eye_chamber',
  // Ideal: Earthhorn · Lightningpip · Crystalmask — hinted by VERB, never by
  // body part: the mighty shove, small access, insight.
  riddle: [
    'My bones grind aside for nothing less than the mightiest shove;',
    'my buried sockets spark only for what my smallest veins admit;',
    'and my eye confides only in sight that pierces the hidden.',
  ],
  // The one marquee lock (§4): the giant's ribs grind only for an Earth Horn
  // (one logical gate shared by all three ribs on the track).
  familyGates: [
    DungeonFamilyGate(
      objectId: 'rib',
      element: 'Earth',
      family: 'Horn',
      hintLine: 'Only an Earth horn\'s force shifts this bone',
    ),
  ],
  rooms: {
    // Room A — Barrow Gate. The mound's mouth, lintel collapsed; an Earth
    // creature raises the fallen stones (one-time entry reveal).
    'barrow_gate': DungeonRoom(
      id: 'barrow_gate',
      bounds: Rect.fromLTWH(0, 0, 720, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(696, 225, 24, 90),
          targetRoomId: 'sternum_court',
          targetSpawn: Offset(120, 330),
        ),
      ],
    ),

    // Room B — Sternum Court (hub). The chest cavity, ribs arching overhead;
    // the rite-shut skull jaw is visible from the first minute.
    'sternum_court': DungeonRoom(
      id: 'sternum_court',
      bounds: Rect.fromLTWH(0, 0, 960, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 285, 24, 90),
          targetRoomId: 'barrow_gate',
          targetSpawn: Offset(630, 270),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(170, 0, 110, 24),
          targetRoomId: 'rib_hall',
          targetSpawn: Offset(500, 640),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(936, 305, 24, 90),
          targetRoomId: 'pillar_crypt',
          targetSpawn: Offset(110, 340),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(425, 676, 110, 24),
          targetRoomId: 'palm_hollow',
          targetSpawn: Offset(320, 120),
        ),
        // The skull's jaw — shut until the Marrow and Crystal stars bank.
        DungeonDoor(
          rect: Rect.fromLTWH(610, 0, 110, 24),
          targetRoomId: 'skull_antechamber',
          targetSpawn: Offset(420, 430),
        ),
      ],
    ),

    // Room C — Rib Hall. Star 1: three fossil ribs on carved tracks; the
    // marrow chasm swallows the east half until the ribs settle into its
    // groove and become the bridge to the sternum plate (and the vault).
    'rib_hall': DungeonRoom(
      id: 'rib_hall',
      bounds: Rect.fromLTWH(0, 0, 1000, 720),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(445, 696, 110, 24),
          targetRoomId: 'sternum_court',
          targetSpawn: Offset(225, 90),
        ),
        // The marrow vault lies BEYOND the chasm — the bridge is its key.
        DungeonDoor(
          rect: Rect.fromLTWH(976, 315, 24, 90),
          targetRoomId: 'marrow_vault',
          targetSpawn: Offset(110, 280),
        ),
      ],
      fossilRibs: [
        FossilRib(
          id: 'rib_high',
          notches: [Offset(350, 180), Offset(520, 180), Offset(700, 180)],
        ),
        FossilRib(
          id: 'rib_mid',
          notches: [Offset(350, 360), Offset(520, 360), Offset(700, 360)],
        ),
        FossilRib(
          id: 'rib_low',
          notches: [Offset(350, 540), Offset(520, 540), Offset(700, 540)],
        ),
      ],
      ribChasm: Rect.fromLTWH(620, 60, 160, 600),
      sternumPlate: Rect.fromLTWH(830, 300, 120, 120),
      ribStarIndex: 0,
    ),

    // Room D — Marrow Vault. The treasury inside the bone (reward space).
    'marrow_vault': DungeonRoom(
      id: 'marrow_vault',
      bounds: Rect.fromLTWH(0, 0, 640, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 235, 24, 90),
          targetRoomId: 'rib_hall',
          targetSpawn: Offset(900, 360),
        ),
      ],
      vaultCache: Offset(320, 280),
    ),

    // Room E — Pillar Crypt. Star 2: four fossil pillars with buried
    // sockets; Lightning arcs them and the locks grow as crystal.
    'pillar_crypt': DungeonRoom(
      id: 'pillar_crypt',
      bounds: Rect.fromLTWH(0, 0, 900, 680),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 295, 24, 90),
          targetRoomId: 'sternum_court',
          targetSpawn: Offset(880, 350),
        ),
      ],
      fossilPillars: [
        FossilPillar(id: 'pillar_nw', position: Offset(220, 200)),
        FossilPillar(id: 'pillar_ne', position: Offset(680, 200)),
        FossilPillar(id: 'pillar_sw', position: Offset(220, 520)),
        FossilPillar(id: 'pillar_se', position: Offset(680, 520)),
      ],
      pillarStarIndex: 1,
    ),

    // Room F — Palm Hollow. The giant's open hand lies here, empty (and a
    // certain crystal might one day take root in it…).
    'palm_hollow': DungeonRoom(
      id: 'palm_hollow',
      bounds: Rect.fromLTWH(0, 0, 640, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(265, 0, 110, 24),
          targetRoomId: 'sternum_court',
          targetSpawn: Offset(478, 580),
        ),
      ],
    ),

    // Room G — Skull Antechamber. Inside the jaw: a bone-etched mural
    // diagrams the eye and its scale (Crystal insight reads it whole).
    'skull_antechamber': DungeonRoom(
      id: 'skull_antechamber',
      bounds: Rect.fromLTWH(0, 0, 840, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(370, 536, 110, 24),
          targetRoomId: 'sternum_court',
          targetSpawn: Offset(665, 110),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(816, 245, 24, 90),
          targetRoomId: 'eye_chamber',
          targetSpawn: Offset(100, 360),
        ),
      ],
    ),

    // Room H — Eye Chamber. Star 3's rite: the giant's crystal eye watches
    // its stone scale; every weight must sit on its TRUE pan. The eye's
    // mercy mends the party once per run.
    'eye_chamber': DungeonRoom(
      id: 'eye_chamber',
      bounds: Rect.fromLTWH(0, 0, 900, 720),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 315, 24, 90),
          targetRoomId: 'skull_antechamber',
          targetSpawn: Offset(740, 290),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'heart_chamber',
          targetSpawn: Offset(410, 560),
        ),
      ],
      stoneScale: StoneScale(
        position: Offset(450, 400),
        plinth: Offset(450, 282),
        weights: [
          ScaleWeight(id: 'w_skull', position: Offset(250, 580), truePanRight: true),
          ScaleWeight(id: 'w_root', position: Offset(383, 612), truePanRight: false),
          ScaleWeight(id: 'w_geode', position: Offset(517, 612), truePanRight: true),
          ScaleWeight(id: 'w_seed', position: Offset(650, 580), truePanRight: false),
        ],
      ),
    ),

    // Room I — Heart Chamber. The still heart of the giant; Terradon coils
    // around it.
    'heart_chamber': DungeonRoom(
      id: 'heart_chamber',
      bounds: Rect.fromLTWH(0, 0, 820, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(355, 676, 110, 24),
          targetRoomId: 'eye_chamber',
          targetSpawn: Offset(450, 110),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(410, 290),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Earth',
          mysticId: 'Terradon',
          canCalm: true,
          canDefeat: true,
        ),
      ),
    ),
  },
);

/// Lightning layout: VOLTARA — the Storm Circuit, reworked to the ZERO-SUM
/// DYNAMO (docs §6.3 REWORK / §9.1 item 1). The dungeon is a living circuit
/// with ONE heart: the hub dynamo feeds exactly one trunk at a time. Charging
/// a trunk breaker (any Lightning, element-only) routes the whole output down
/// that wing — and darkens every other wing (walkable but dark, spark wisps
/// prowling). The run-long question: where does the power go, and what must
/// be done in the dark?
///  • S1 (pylon_hall): with its trunk fed, one bolt must thread ALL THREE
///    terminals via FOUR conductor mirrors — and never cross a fulminate vat
///    (a cooked vat detonates and trips the dynamo dark). Provably unique.
///  • S2 (cloud_works): storm-cells bared in the mirror gallery are herded
///    onto sockets; the anvil socket needs Fire heat (Air+Fire→Lightning).
///    The works only sing — and the star only banks — while their trunk burns.
///  • Vault (capacitor_vault): the bolt holds while the trunk is POWERED and
///    falls open in the dark — cut the very trunk you stand in, walk back in
///    the dark, and the treasury is yours.
///  • S3 (overload_maze): element stationing — Air on the true vent, Fire in
///    the beam's path, Lightning turning the conductors — lights the Storm
///    Tower (one dead-aligned decoy pair is geometrically impossible: no
///    conductor waits beyond its converter). Beyond: Raikuma FEEDS on the
///    powered core trunk — ground it at the spike to force the lull.
/// Egg = light the tower with a Lightning HORN among the conductors
/// (Thunderbolt, Heraclitus).
const DungeonLayout _lightningLayout = DungeonLayout(
  element: 'Lightning',
  entranceRoomId: 'arc_gate',
  entranceSpawn: Offset(170, 270),
  title: 'STORM CIRCUIT',
  descentTitle: 'Voltara Circuit',
  dynamoRoomId: 'dynamo_court',
  initialTrunkId: 'trunk_vault',
  dynamoTrunks: [
    DynamoTrunk(
      id: 'trunk_pylon',
      name: 'PYLON TRUNK',
      breakerPosition: Offset(360, 250),
      roomIds: ['pylon_hall'],
      freezeLitStarIndex: 0,
    ),
    DynamoTrunk(
      id: 'trunk_cloud',
      name: 'CLOUD TRUNK',
      breakerPosition: Offset(620, 440),
      roomIds: ['cloud_works', 'mirror_gallery'],
      freezeLitStarIndex: 1,
    ),
    DynamoTrunk(
      id: 'trunk_vault',
      name: 'VAULT TRUNK',
      breakerPosition: Offset(640, 290),
      roomIds: ['capacitor_vault'],
    ),
    DynamoTrunk(
      id: 'trunk_core',
      name: 'CORE TRUNK',
      breakerPosition: Offset(505, 235),
      roomIds: ['overload_maze', 'storm_core'],
      freezeLitStarIndex: 2,
    ),
  ],
  stars: [
    DungeonStarSpec(
      name: 'Circuit Star',
      earnAnnouncement:
          'The Circuit Star is yours — power runs true through every conductor',
    ),
    DungeonStarSpec(
      name: 'Storm Star',
      earnAnnouncement:
          'The Storm Star is yours — the anvil\'s thunder feeds the grid',
    ),
    DungeonStarSpec(name: 'Overload Star'),
  ],
  entranceRevealDoor: DungeonDoorRef('arc_gate', 'dynamo_court'),
  finaleDoor: DungeonDoorRef('dynamo_court', 'overload_maze'),
  riteAnnouncement:
      'Circuit and Storm answer as one — the breaker gate throws open',
  finaleSealedHint:
      'The breaker gate is dead — it powers only for both the Circuit and '
      'Storm stars',
  mercyShrineRoomId: 'storm_core',
  // Ideal: Lightninghorn · Airwing · Firepip — hinted by VERB, never body part:
  // the mighty charge/hold, flight, small access + heat.
  riddle: [
    'Where the grip is strongest, my dead iron wakes to fire;',
    'what the ground cannot keep must herd my high storm-cells;',
    'and a spark, coaxed through the smallest vent, weds wind to flame.',
  ],
  rooms: {
    // Room A — Arc Gate. The way in is a dead bus; a Lightning Horn charges
    // the gate pylon and the passage lights open (one-time entry reveal).
    'arc_gate': DungeonRoom(
      id: 'arc_gate',
      bounds: Rect.fromLTWH(0, 0, 720, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(696, 225, 24, 90),
          targetRoomId: 'dynamo_court',
          targetSpawn: Offset(120, 360),
        ),
      ],
      circuitNodes: [
        CircuitNode(
          id: 'g_src',
          kind: CircuitNodeKind.source,
          position: Offset(250, 270),
          links: ['g_sink'],
        ),
        CircuitNode(
          id: 'g_sink',
          kind: CircuitNodeKind.sink,
          position: Offset(470, 270),
          links: ['g_src'],
        ),
      ],
    ),

    // Room B — Dynamo Court (hub). The great rotor turns overhead; the
    // rite-shut breaker gate to the overload maze is visible from minute one.
    'dynamo_court': DungeonRoom(
      id: 'dynamo_court',
      bounds: Rect.fromLTWH(0, 0, 980, 720),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 315, 24, 90),
          targetRoomId: 'arc_gate',
          targetSpawn: Offset(630, 270),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(170, 0, 110, 24),
          targetRoomId: 'pylon_hall',
          targetSpawn: Offset(500, 660),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(956, 315, 24, 90),
          targetRoomId: 'cloud_works',
          targetSpawn: Offset(110, 360),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(430, 696, 110, 24),
          targetRoomId: 'mirror_gallery',
          targetSpawn: Offset(320, 110),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(700, 0, 110, 24),
          targetRoomId: 'capacitor_vault',
          targetSpawn: Offset(320, 480),
        ),
        // The breaker gate — dead until the Circuit and Storm stars bank.
        DungeonDoor(
          rect: Rect.fromLTWH(610, 0, 80, 24),
          targetRoomId: 'overload_maze',
          targetSpawn: Offset(480, 280),
        ),
      ],
    ),

    // Room C — Pylon Hall. Star 1 (zero-sum rework): the hall's emitter is
    // live only while the PYLON TRUNK is fed. One bolt must thread ALL THREE
    // terminals via FOUR conductor mirrors ('/' or '\\') — and it must NEVER
    // cross a fulminate vat (a cooked vat detonates + trips the dynamo dark).
    // Geometry (solver-proven unique — see the layout test's brute force):
    //   E(140,150)→ pa'\\'(520,150) ↓ T1 → pd'\\'(520,560) → T2 →
    //   pc'/'(960,560) ↑ T3 → pb'/'(960,150) → out right.
    // The tempting alternative pb='\\' (back along the top) crosses vat A —
    // the vat is the constraint that makes the threading unique; vat B
    // punishes the wrong turn at pd (down→left runs straight over it).
    'pylon_hall': DungeonRoom(
      id: 'pylon_hall',
      bounds: Rect.fromLTWH(0, 0, 1040, 720),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(445, 696, 110, 24),
          targetRoomId: 'dynamo_court',
          targetSpawn: Offset(225, 110),
        ),
      ],
      beamEmitters: [
        BeamEmitter(position: Offset(140, 150), dir: Offset(1, 0)),
      ],
      beamMirrors: [
        BeamMirror(id: 'pa', position: Offset(520, 150)), // right→down ('\')
        BeamMirror(id: 'pb', position: Offset(960, 150)), // up→right   ('/')
        BeamMirror(id: 'pc', position: Offset(960, 560)), // right→up   ('/')
        BeamMirror(id: 'pd', position: Offset(520, 560)), // down→right ('\')
      ],
      beamReceivers: [
        Offset(520, 360), // T1 — on the down leg (pa→pd)
        Offset(760, 560), // T2 — on the right leg (pd→pc)
        Offset(960, 360), // T3 — on the up leg (pc→pb)
      ],
      fulminateVats: [
        FulminateVat(id: 'vat_a', position: Offset(740, 150)),
        FulminateVat(id: 'vat_b', position: Offset(300, 560)),
      ],
      circuitStarIndex: 0,
    ),

    // Room D — Capacitor Vault (the §5.5 vault re-hide, delivered). The
    // treasury sits inside an inner sanctum whose only mouth is barred by the
    // VAULT BOLT — a breaker that holds while the vault trunk is POWERED and
    // falls open in the dark. The dynamo starts latched to this trunk (the
    // treasury hoards the storm), so the player must deliberately route the
    // power AWAY and walk the dead segment in the dark to claim the cache.
    'capacitor_vault': DungeonRoom(
      id: 'capacitor_vault',
      bounds: Rect.fromLTWH(0, 0, 640, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(265, 536, 110, 24),
          targetRoomId: 'dynamo_court',
          targetSpawn: Offset(745, 110),
        ),
      ],
      // The sanctum: a walled cell around the cache with one south mouth.
      walls: [
        Rect.fromLTWH(180, 160, 24, 240), // west wall
        Rect.fromLTWH(436, 160, 24, 240), // east wall
        Rect.fromLTWH(180, 160, 280, 24), // north wall
        Rect.fromLTWH(180, 376, 80, 24), // south wall, west stub
        Rect.fromLTWH(380, 376, 80, 24), // south wall, east stub
      ],
      vaultBolt: Rect.fromLTWH(260, 376, 120, 24),
      vaultCache: Offset(320, 280),
    ),

    // Room E — Cloud Works. Star 2: storm-cell echoes (discovered next door)
    // are herded by an Airwing onto sockets; the anvil socket ignites only
    // when a Fire creature heats its cell (Air+Fire→Lightning → Thundercloud).
    // Every energized socket births a latching source feeding the sinks.
    'cloud_works': DungeonRoom(
      id: 'cloud_works',
      bounds: Rect.fromLTWH(0, 0, 980, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 315, 24, 90),
          targetRoomId: 'dynamo_court',
          targetSpawn: Offset(900, 360),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(435, 0, 110, 24),
          targetRoomId: 'mirror_gallery',
          targetSpawn: Offset(320, 560),
        ),
      ],
      cellSockets: [
        CellSocket(
          id: 'sock_a',
          position: Offset(260, 200),
          energizesNodeId: 'c_src_a',
        ),
        CellSocket(
          id: 'sock_b',
          position: Offset(260, 500),
          energizesNodeId: 'c_src_b',
        ),
        CellSocket(
          id: 'sock_anvil',
          position: Offset(560, 350),
          energizesNodeId: 'c_src_anvil',
          requiresHeat: true,
        ),
      ],
      circuitNodes: [
        CircuitNode(
          id: 'c_src_a',
          kind: CircuitNodeKind.source,
          position: Offset(260, 200),
          links: ['c_bus'],
          latching: true,
        ),
        CircuitNode(
          id: 'c_src_b',
          kind: CircuitNodeKind.source,
          position: Offset(260, 500),
          links: ['c_bus'],
          latching: true,
        ),
        CircuitNode(
          id: 'c_src_anvil',
          kind: CircuitNodeKind.source,
          position: Offset(560, 350),
          links: ['c_bus'],
          latching: true,
        ),
        CircuitNode(
          id: 'c_bus',
          kind: CircuitNodeKind.bus,
          position: Offset(760, 350),
          links: ['c_src_a', 'c_src_b', 'c_src_anvil', 'c_s1', 'c_s2'],
        ),
        CircuitNode(
          id: 'c_s1',
          kind: CircuitNodeKind.sink,
          position: Offset(900, 230),
          links: ['c_bus'],
        ),
        CircuitNode(
          id: 'c_s2',
          kind: CircuitNodeKind.sink,
          position: Offset(900, 470),
          links: ['c_bus'],
        ),
      ],
      circuitStarIndex: 1,
    ),

    // Room F — Mirror Gallery. Storm-cell echoes hide here, bared by insight
    // (Mask) or close approach; discovering one unlocks its echo at the cloud
    // works (no dragging across rooms). A Mask also reads the maze's true path.
    'mirror_gallery': DungeonRoom(
      id: 'mirror_gallery',
      bounds: Rect.fromLTWH(0, 0, 760, 620),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(325, 596, 110, 24),
          targetRoomId: 'dynamo_court',
          targetSpawn: Offset(485, 110),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(325, 0, 110, 24),
          targetRoomId: 'cloud_works',
          targetSpawn: Offset(120, 360),
        ),
      ],
      stormCells: [
        StormCell(id: 'cell_spark', cellType: 'Spark', position: Offset(170, 200)),
        StormCell(id: 'cell_veil', cellType: 'Veil', position: Offset(590, 200)),
        StormCell(id: 'cell_anvil', cellType: 'Anvil', position: Offset(380, 430)),
      ],
    ),

    // Room G — The Storm Spire. Star 3, behind the breaker gate: an open-arena
    // beam puzzle that needs all three creatures stationed/used at once — and
    // there are MULTIPLE vents and converters, only the right combination works.
    //  • Station AIR on a Wind Vent → that vent emits a power beam (but only one
    //    vent's beam can actually be routed; the others die into walls/pillars).
    //  • Station FIRE on a Converter spot → IF the beam passes through it the
    //    beam becomes LIGHTNING there (a real arc — Air+Fire→Lightning). You must
    //    thread the beam THROUGH a converter on its way to the tower.
    //  • LIGHTNING roams and turns the heavy conductor mirrors (only the storm's
    //    own can move them) to bounce the beam around the pillars, through a
    //    converter, and onto the central STORM TOWER. Only the lightning portion
    //    lights it → the gate to Raikuma throws open.
    // The one viable chain spirals inward through FIVE conductors: vent VA →
    // A(right→down) → B(down→left) → C(left→up) → D(up→left) → E(left→down) →
    // through converter FA → tower. Mirror solution A='\\' B='/' C='\\' D='\\'
    // E='/' (three flipped off the default '/'). The Thunderbolt egg lights it
    // with a Lightning Horn among the conductors.
    // DECOY PAIR (rework): vent VD + converter FD stand dead-aligned on the
    // east wall — the only vent/converter pair that line up perfectly, and a
    // lie: no conductor waits beyond FD on that column, so the born bolt can
    // only die in the ceiling. Its elimination is pure mirror-geometry
    // reasoning (the layout test brute-forces all 32 orientations to prove
    // it impossible).
    'overload_maze': DungeonRoom(
      id: 'overload_maze',
      bounds: Rect.fromLTWH(0, 0, 1120, 720),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(40, 40, 80, 24),
          targetRoomId: 'dynamo_court',
          targetSpawn: Offset(650, 90),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(210, 640, 90, 32),
          targetRoomId: 'storm_core',
          targetSpawn: Offset(110, 380),
        ),
      ],
      // An open arena — border + two obstacle pillars the beam can't cross.
      walls: [
        Rect.fromLTWH(0, 0, 24, 720), // left border
        Rect.fromLTWH(1096, 0, 24, 720), // right border
        Rect.fromLTWH(0, 0, 1120, 24), // top border
        Rect.fromLTWH(0, 696, 1120, 24), // bottom border
        Rect.fromLTWH(420, 380, 110, 130), // obstacle pillar 1
        Rect.fromLTWH(700, 380, 90, 130), // obstacle pillar 2
      ],
      beamEmitters: [
        BeamEmitter(position: Offset(160, 160), dir: Offset(1, 0)), // VA: viable
        BeamEmitter(position: Offset(160, 460), dir: Offset(1, 0)), // VB: → pillar
        BeamEmitter(position: Offset(560, 640), dir: Offset(0, -1)), // VC: → ceiling
        // VD: the DECOY — dead-aligned with FD, but no conductor beyond it.
        BeamEmitter(position: Offset(1000, 640), dir: Offset(0, -1)),
      ],
      beamConverters: [
        Offset(260, 420), // FA: on the viable beam path (the last leg)
        Offset(700, 200), // FB: off any path
        Offset(500, 560), // FC: off the viable path
        Offset(1000, 300), // FD: the decoy pair's converter (see above)
      ],
      beamMirrors: [
        BeamMirror(id: 'A', position: Offset(900, 160)), // right→down ('\')
        BeamMirror(id: 'B', position: Offset(900, 560)), // down→left  ('/')
        BeamMirror(id: 'C', position: Offset(620, 560)), // left→up    ('\')
        BeamMirror(id: 'D', position: Offset(620, 300)), // up→left    ('\')
        BeamMirror(id: 'E', position: Offset(260, 300)), // left→down  ('/')
      ],
      beamReceiver: Offset(260, 500), // the Storm Tower
      poweredBarriers: [
        // The gate to the storm core — thrown when the tower is lit
        // (nodeId 'beam_core', held live by the engine).
        PoweredBarrier(rect: Rect.fromLTWH(200, 600, 120, 22), nodeId: 'beam_core'),
      ],
    ),

    // Room H — Storm Core. Raikuma coils at the heart of the grid — and
    // FEEDS on the powered core trunk (docs §7): while the trunk burns it
    // never offers the lull. The grounding spike by the west door cuts the
    // trunk (Lightning only) and forces the vulnerability window; Raikuma
    // seizes the trunk back when the window closes. The core's mercy mends
    // the party once per run.
    'storm_core': DungeonRoom(
      id: 'storm_core',
      bounds: Rect.fromLTWH(0, 0, 820, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 335, 24, 90),
          targetRoomId: 'overload_maze',
          targetSpawn: Offset(255, 545),
        ),
      ],
      coreBreaker: Offset(170, 545),
      guardian: GuardianNode(
        position: Offset(410, 300),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Lightning',
          mysticId: 'Raikuma',
          canCalm: true,
          canDefeat: true,
        ),
      ),
    ),
  },
);

/// Steam layout: VAPORIS — the Molten Labyrinth, rebuilt per the §5.5
/// anti-template mandate as the PRESSURE RING-MAIN. Topology: NO hub — a
/// closed loop of four segments (south manifold → west causeway → north
/// manifold → east forge → back to south) around the central Crucible, with
/// the furnace-heart beyond it and the burst-disc vault hanging off the ring.
/// Strategic question: THE BOILER HOLDS ONLY SO MUCH PRESSURE — every ring
/// junction costs pressure to unclamp (4 × 15 vs a starting head of 40, so
/// the whole ring can't be opened up front). Steam's cooling CONDENSES: every
/// lava cell cooled returns condensate to the main (+4), so the flood is also
/// fuel; Fire can STOKE a firebox (+20) but the roar draws wisps. The vault
/// hides behind a burst-disc that only yields to DUMPING ≥60 pressure at once
/// — the whole remaining budget, sacrificed. Tile mechanics unchanged: FIRE
/// melts rock to lava (Earth+Fire→Lava), STEAM cools lava to stone, EARTH
/// dams. Egg = the whole labyrinth without one scald (Hidden Harmony).
const DungeonLayout _steamLayout = DungeonLayout(
  element: 'Steam',
  entranceRoomId: 'boiler_gate',
  entranceSpawn: Offset(170, 270),
  title: 'THE MOLTEN LABYRINTH',
  descentTitle: 'Vaporis Foundry',
  stars: [
    DungeonStarSpec(
      name: 'Causeway Star',
      earnAnnouncement:
          'The Causeway Star is yours — you walked the cooled molten road',
    ),
    DungeonStarSpec(
      name: 'Cinder Star',
      earnAnnouncement:
          'The Cinder Star is yours — you dammed the flood and crossed dry',
    ),
    DungeonStarSpec(name: 'Crucible Star'),
  ],
  entranceRevealDoor: DungeonDoorRef('boiler_gate', 'manifold_south'),
  finaleDoor: DungeonDoorRef('manifold_north', 'crucible'),
  riteAnnouncement:
      'Causeway and Cinder are won — the crucible gate grinds open',
  finaleSealedHint:
      'The crucible gate is sealed — it yields only to the Causeway and Cinder '
      'stars',
  mercyShrineRoomId: 'boiler_heart',
  // Ideal: Steampip · Firemask · Earthhorn — hinted by VERB, never body part:
  // a cooling breath, a kindling/melting heart, the wall-raising strength.
  riddle: [
    'My smallest breath cools the running molten back to standing stone;',
    'a kindled heart melts the rock and lets the fire-blood run;',
    'and the strongest arms raise walls to dam the flood.',
  ],
  rooms: {
    // Boiler Gate — the way in. A Steam creature cracks the relief vent and
    // the clamped seal hisses open (entry rite), tapping into the ring's
    // south manifold.
    'boiler_gate': DungeonRoom(
      id: 'boiler_gate',
      bounds: Rect.fromLTWH(0, 0, 720, 540),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(696, 225, 24, 90),
          targetRoomId: 'manifold_south',
          targetSpawn: Offset(120, 230),
        ),
      ],
      steamVent: Offset(460, 180),
    ),

    // South Manifold — the ring's bottom segment (NOT a hub: it is one arc of
    // the loop). The great pressure gauge lives here, with the two clamped
    // junctions west (causeway) and east (forge), a stoke firebox, and the
    // burst-disc wall over the vault shaft in the floor's south edge.
    'manifold_south': DungeonRoom(
      id: 'manifold_south',
      bounds: Rect.fromLTWH(0, 0, 1100, 460),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 185, 24, 90),
          targetRoomId: 'boiler_gate',
          targetSpawn: Offset(630, 270),
        ),
        // West junction — clamped: 15 pressure to unclamp.
        DungeonDoor(
          rect: Rect.fromLTWH(130, 0, 110, 24),
          targetRoomId: 'ember_causeway',
          targetSpawn: Offset(245, 595),
        ),
        // East junction — clamped: 15 pressure to unclamp.
        DungeonDoor(
          rect: Rect.fromLTWH(860, 0, 110, 24),
          targetRoomId: 'cinder_forge',
          targetSpawn: Offset(385, 665),
        ),
        // The vault shaft — hidden behind the burst-disc until it blows.
        DungeonDoor(
          rect: Rect.fromLTWH(495, 436, 110, 24),
          targetRoomId: 'burst_vault',
          targetSpawn: Offset(320, 110),
        ),
      ],
      pressureSeals: [
        PressureSeal(targetRoomId: 'ember_causeway', cost: 15),
        PressureSeal(targetRoomId: 'cinder_forge', cost: 15),
      ],
      stokePort: Offset(760, 330),
      burstDisc: BurstDisc(
        position: Offset(550, 380),
        threshold: 60,
        targetRoomId: 'burst_vault',
      ),
    ),

    // Ember Causeway — the ring's WEST segment, and Star 0 (choose your
    // breach): a bedrock dam band crosses the room with three identical
    // meltable faces on its south side. Two are WET — molten pockets sealed
    // behind them glow with ember cracks; breaching one releases the
    // reservoir into your own chamber and the slot still dead-ends in
    // bedrock. Only the dry, quiet face threads through (two melts with a
    // hollow between — cool your doorway as you go). The pedestal waits on
    // the far field. Read the wall before you burn it.
    'ember_causeway': DungeonRoom(
      id: 'ember_causeway',
      bounds: Rect.fromLTWH(0, 0, 700, 840),
      doors: [
        // Ring: down to the south manifold.
        DungeonDoor(
          rect: Rect.fromLTWH(295, 816, 110, 24),
          targetRoomId: 'manifold_south',
          targetSpawn: Offset(185, 110),
        ),
        // Ring: up to the north manifold — clamped junction.
        DungeonDoor(
          rect: Rect.fromLTWH(295, 0, 110, 24),
          targetRoomId: 'manifold_north',
          targetSpawn: Offset(185, 310),
        ),
      ],
      pressureSeals: [
        PressureSeal(targetRoomId: 'manifold_south', cost: 15),
        PressureSeal(targetRoomId: 'manifold_north', cost: 15),
      ],
      // 10×12 grid (cells 70×70). South field = entry from the manifold;
      // dam band rows 4-6; wet pocket slots at cols 2/8 (sealed — pure
      // traps), the dry passage at col 5. Pedestal on the north field.
      molten: MoltenGrid(
        starIndex: 0,
        rows: [
          'XXXXXXXXXX',
          'X........X',
          'X....P...X',
          'X........X',
          'XXXXX#XXXX',
          'XXLXX.XXLX',
          'XX#XX#XX#X',
          'X........X',
          'X........X',
          'X........X',
          'X........X',
          'XXXXXXXXXX',
        ],
      ),
    ),

    // Cinder Forge — the ring's EAST segment, and Star 1 (bunker before you
    // breach): the pedestal sits in a bedrock sanctuary whose ONLY way in is
    // a meltable gate, and the field around it is strewn with sleeping
    // cisterns that all WAKE the moment Fire breaks rock. Wall a bunker
    // around the gate mouth FIRST, then melt, cool the spill, slip inside.
    'cinder_forge': DungeonRoom(
      id: 'cinder_forge',
      bounds: Rect.fromLTWH(0, 0, 700, 840),
      doors: [
        // Ring: down to the south manifold.
        DungeonDoor(
          rect: Rect.fromLTWH(295, 816, 110, 24),
          targetRoomId: 'manifold_south',
          targetSpawn: Offset(915, 110),
        ),
        // Ring: up to the north manifold — clamped junction.
        DungeonDoor(
          rect: Rect.fromLTWH(295, 0, 110, 24),
          targetRoomId: 'manifold_north',
          targetSpawn: Offset(915, 310),
        ),
      ],
      pressureSeals: [
        PressureSeal(targetRoomId: 'manifold_south', cost: 15),
        PressureSeal(targetRoomId: 'manifold_north', cost: 15),
      ],
      // 10×12 grid (cells 70×70). Sanctuary pocket rows 4-6 cols 0-4 with
      // its gate '#' at (4,5); pedestal inside at (1,5); cisterns at (4,2),
      // (6,6), (3,8) wake on any melt in this room.
      molten: MoltenGrid(
        starIndex: 1,
        rows: [
          'XXXXXXXXXX',
          'X........X',
          'X...L....X',
          'X........X',
          'XXXXX....X',
          'XP..#....X',
          'XXXXX.L..X',
          'X........X',
          'X..L.....X',
          'X........X',
          'X........X',
          'XXXXXXXXXX',
        ],
      ),
    ),

    // North Manifold — the ring's top segment. The rite-sealed crucible gate
    // drops from its floor into the ring's centre; a second stoke firebox
    // burns here for runs that arrive with an empty main.
    'manifold_north': DungeonRoom(
      id: 'manifold_north',
      bounds: Rect.fromLTWH(0, 0, 1100, 420),
      doors: [
        // Ring: down the west side to the causeway — clamped junction.
        DungeonDoor(
          rect: Rect.fromLTWH(130, 396, 110, 24),
          targetRoomId: 'ember_causeway',
          targetSpawn: Offset(175, 175),
        ),
        // Ring: down the east side to the forge — clamped junction.
        DungeonDoor(
          rect: Rect.fromLTWH(860, 396, 110, 24),
          targetRoomId: 'cinder_forge',
          targetSpawn: Offset(105, 175),
        ),
        // The crucible gate — rite-sealed until Causeway + Cinder bank.
        DungeonDoor(
          rect: Rect.fromLTWH(495, 396, 110, 24),
          targetRoomId: 'crucible',
          targetSpawn: Offset(455, 105),
        ),
      ],
      pressureSeals: [
        PressureSeal(targetRoomId: 'ember_causeway', cost: 15),
        PressureSeal(targetRoomId: 'cinder_forge', cost: 15),
      ],
      stokePort: Offset(550, 140),
    ),

    // The Crucible — the ring's CENTRE, and the rite (null star index): a
    // bedrock band walls the pedestal off; its only doors are the meltable
    // gates, flanked by sleeping cisterns on BOTH sides. Bunker your gate,
    // break through, quench the spill at its source, take the pedestal —
    // Boilrog heaves up from the furnace beyond.
    'crucible': DungeonRoom(
      id: 'crucible',
      bounds: Rect.fromLTWH(0, 0, 910, 700),
      doors: [
        // Up to the north manifold.
        DungeonDoor(
          rect: Rect.fromLTWH(400, 0, 110, 24),
          targetRoomId: 'manifold_north',
          targetSpawn: Offset(550, 310),
        ),
        // Down to the furnace-heart — beyond the rite.
        DungeonDoor(
          rect: Rect.fromLTWH(400, 676, 110, 24),
          targetRoomId: 'boiler_heart',
          targetSpawn: Offset(410, 110),
        ),
      ],
      // 13×10 grid (cells 70×70). Entry field on top; band row 5 with the
      // twin '##' gates; pedestal field below with its own cisterns.
      molten: MoltenGrid(
        starIndex: null,
        rows: [
          'XXXXXXXXXXXXX',
          'X...........X',
          'X...........X',
          'X....LLL....X',
          'X...........X',
          'XXXX##X##XXXX',
          'X..L.....L..X',
          'X.....P.....X',
          'X...........X',
          'XXXXXXXXXXXXX',
        ],
      ),
    ),

    // Burst Vault — the treasury behind the burst-disc. There is no key and
    // no gate rite: the only way in is to VENT THE MAIN — dump every unit of
    // pressure you carry into the disc, and if the surge is great enough
    // (≥60) it blows. The bottled essence waits below.
    'burst_vault': DungeonRoom(
      id: 'burst_vault',
      bounds: Rect.fromLTWH(0, 0, 640, 480),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(265, 0, 110, 24),
          targetRoomId: 'manifold_south',
          targetSpawn: Offset(550, 350),
        ),
      ],
      vaultCache: Offset(320, 260),
    ),

    // Boiler Heart — Boilrog broods in the furnace-heart beneath the
    // crucible; the heart's mercy mends the party once per run.
    'boiler_heart': DungeonRoom(
      id: 'boiler_heart',
      bounds: Rect.fromLTWH(0, 0, 820, 700),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(355, 0, 110, 24),
          targetRoomId: 'crucible',
          targetSpawn: Offset(455, 595),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(410, 300),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Steam',
          mysticId: 'Boilrog',
          canCalm: true,
          canDefeat: true,
        ),
      ),
    ),
  },
);

/// Authored dungeon layouts keyed by planet element. A planet is only enterable
/// if it appears here.
const Map<String, DungeonLayout> kPlanetDungeonLayouts = {
  'Air': _airLayout,
  'Fire': _fireLayout,
  'Water': _waterLayout,
  'Earth': _earthLayout,
  'Lightning': _lightningLayout,
  'Steam': _steamLayout,
};

/// Save-compat migration for "the seal remembers" (§9.0 ruling, 2026-08-10):
/// auto-stamp a planet's family-gate chips ONLY when that planet is fully
/// cleared (all 3 stars). A solved puzzle short-circuits before its
/// interaction check ever runs again, so a veteran could never re-trigger the
/// stamp in-world — and there is nothing left to spoil on a finished planet.
/// Partial clears do NOT auto-stamp: those gates are still live content.
///
/// Returns [state] unchanged (identical instance) when nothing needed
/// stamping, so callers can cheaply detect whether to re-persist.
PlanetStarState stampClearedPlanetFamilyGates(PlanetStarState state) {
  var out = state;
  for (final layout in kPlanetDungeonLayouts.values) {
    if (state.starsEarned(layout.element) < 3) continue;
    for (final gate in layout.familyGates) {
      if (out.discoveredCloudsFor(layout.element).contains(gate.discoveryId)) {
        continue;
      }
      out = out.withDiscoveredCloud(layout.element, gate.discoveryId);
    }
  }
  return out;
}

// ─────────────────────────────────────────────────────────
// RAID ARENAS
// ─────────────────────────────────────────────────────────

/// Elements whose mystic guardian can host a raid, mapped to the mystic id the
/// arena spawns. Add an element here only after its spritesheet is wired into
/// the game's guardian sheet map.
const Map<String, String> kRaidGuardianIds = {
  'Air': 'Roc',
  'Fire': 'Simurgh',
  'Water': 'Leviathan',
  'Earth': 'Terradon',
  'Lightning': 'Raikuma',
  'Steam': 'Boilrog',
};

/// A raid is one big open planet-themed arena — no rooms, no puzzles, just
/// the empowered guardian under the storm. Generated, not authored, so every
/// element in [kRaidGuardianIds] gets one for free.
DungeonLayout buildRaidArenaLayout(String element) {
  final mysticId = kRaidGuardianIds[element];
  assert(mysticId != null, 'No raid guardian configured for $element');
  final room = DungeonRoom(
    id: 'raid_arena',
    bounds: const Rect.fromLTWH(0, 0, 1400, 900),
    // Element-flavored crosswinds give gliders play without gating walkers.
    currents: const [
      WindCurrent(
        rect: Rect.fromLTWH(0, 80, 360, 740),
        dir: Offset(0, -1),
        strength: 70,
      ),
      WindCurrent(
        rect: Rect.fromLTWH(1040, 80, 360, 740),
        dir: Offset(0, -1),
        strength: 70,
      ),
    ],
    guardian: GuardianNode(
      position: const Offset(700, 380),
      starIndex: 2, // unused in raid mode; keeps the node shape uniform
      encounter: GuardianEncounterRequirement(
        element: element,
        mysticId: mysticId!,
        canCalm: false,
        canDefeat: true,
      ),
    ),
  );
  final authored = kPlanetDungeonLayouts[element];
  return DungeonLayout(
    element: element,
    rooms: {'raid_arena': room},
    entranceRoomId: 'raid_arena',
    entranceSpawn: const Offset(700, 740),
    title: authored?.title ?? element.toUpperCase(),
    descentTitle: authored?.descentTitle ?? element,
    stars: authored?.stars ?? const [],
  );
}
