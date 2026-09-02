// lib/games/planet_dungeon/planet_dungeon_data.dart
//
// PLANET DUNGEON — data model + persistence.
//
// Authored, per-planet multi-room layouts the swap-control dungeon scene runs
// on. Slice 2 is the reusable chassis: rooms are generic boxes with walls,
// doorways, a test hazard, and placeholder star pickups. Slice 3 replaces the
// placeholders with each planet's bespoke puzzles. See `project-planet-dungeons`.

import 'dart:math' show cos, pi, sin;
import 'dart:ui';

import 'package:alchemons/games/cosmic/cosmic_data.dart' show PlanetStarState;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_lava.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_poison.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_ice.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_mud.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_crystal.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dust.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_plant.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_spirit.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dark.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_light.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_blood.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart'
    show CosmicPartyMember, DungeonEntryDemand;
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

/// Directional wind that carries creatures — gliders always, and (once woken)
/// walkers and enemies alike. If the rider's Speed is below [requiredSpeed] the
/// current overpowers them (net push backwards).
///
/// **§9.1 AIR REWORK — GALES.** A current carrying a [galeId] is one of the
/// spire's sleeping GALES: it is inert until its gust shrine wakes it, and then
/// it blows for the rest of the run (no timers). Several currents may share one
/// [galeId] — one shrine, one wind, however many rects it takes to draw it.
/// A current with a null [galeId] is plain scenery-wind and always blows.
class WindCurrent {
  final Rect rect;
  final Offset dir; // normalised
  final double strength; // px/sec
  final double requiredSpeed; // 1..5 stat threshold (0 = no gate)
  /// The gale this current belongs to (null = always-on ambient wind).
  final String? galeId;
  const WindCurrent({
    required this.rect,
    required this.dir,
    this.strength = 90,
    this.requiredSpeed = 0,
    this.galeId,
  });
}

/// Star 1 completion zone — the spire crown. Reachable once every gale blows;
/// standing in it earns [starIndex].
class SpireSummit {
  final Rect rect;
  final int starIndex;
  const SpireSummit({required this.rect, required this.starIndex});
}

// ── Air Star 1: WAKE THE WINDS (§6.11 REWORK / §9.1 item 4) ─
// The spire is born CALM. Gust shrines wake its gales one at a time and
// PERMANENTLY; a woken gale is simultaneously a ladder (it carries you where
// footing never could) and an obstacle (it scours the walkways it crosses).
// The puzzle is the waking ORDER — read which ledges each current will help or
// bar BEFORE you wake it.
//
// The traversal graph below is authored DATA, not engine knowledge: ledges are
// named footing, routes are the ways between them, and `PlanetDungeonGame`'s
// public `solveWindWaking()` walks this same graph to prove (a) no wake order
// can ever strand the player and (b) which orders are fall-free.

/// A named piece of footing in the spire's wind graph. Ledges are real
/// platforms: the engine adds every ledge rect to the room's standable ground,
/// so the graph and the collision map can never disagree.
class WindLedge {
  final String id;
  final Rect rect;
  const WindLedge({required this.id, required this.rect});
  Offset get center => rect.center;
}

/// One traversal between two [WindLedge]s.
///
///  • [ridesGale] null → plain footing: a stair, a catwalk, a ledge-hop. The
///    [path] rect is real standable ground.
///  • [ridesGale] non-null → the wind carries you, and only downwind: the route
///    exists only while that gale blows, and is one-way by nature.
///  • [sweptBy] → gales that, once woken, scour this route away. A swept walk
///    is authored so its [path] lies INSIDE the sweeping gale's rects, so the
///    physics (the wind lifts you off the catwalk) produces exactly what the
///    graph claims.
///  • [costly] → the scoured fall-back. It always exists, but taking it means
///    being blown off and climbing back. This is what makes a wrong wake order
///    expensive without ever making it fatal.
class WindRoute {
  final String id;
  final String from;
  final String to;
  final String? ridesGale;
  final List<String> sweptBy;
  final bool twoWay;
  final bool costly;

  /// The corridor the route occupies — walkable footing for a plain route, the
  /// carried corridor for a gale ride.
  final Rect path;

  const WindRoute({
    required this.id,
    required this.from,
    required this.to,
    required this.path,
    this.ridesGale,
    this.sweptBy = const [],
    this.twoWay = false,
    this.costly = false,
  });

  /// Is this route travelable with [woken] gales blowing?
  bool openWith(Set<String> woken) {
    for (final g in sweptBy) {
      if (woken.contains(g)) return false;
    }
    final rides = ridesGale;
    return rides == null || woken.contains(rides);
  }
}

/// A gust shrine. Communing at one wakes exactly one gale — for good.
class GustShrine {
  final String id;

  /// The wind this shrine wakes, spoken in the shrine's own voice.
  final String name;

  /// The ledge the shrine stands on (its approach is what a rival gale bars).
  final String ledgeId;
  final Offset position;
  final String wakesGale;

  const GustShrine({
    required this.id,
    required this.name,
    required this.ledgeId,
    required this.position,
    required this.wakesGale,
  });
}

// ── Air Star 3: STORM-ROD STEERING (§6.11 REWORK) ──────────
// The twin conduits no longer race a decay timer. Conduit A keeps its hard
// Lightning+Horn gate and LATCHES. Conduit B is struck by the storm itself: a
// live cell circles the altar, and when it discharges its leader climbs from
// conductor to conductor — always to the TALLEST one within reach that stands
// STRICTLY TALLER than the one it is on. Rank the rod field into a staircase
// that ends at conduit B and the storm lights it for you; rank it wrong and the
// bolt dies on a rod (wild strike + storm wisps).

/// A storm-rod: raised and lowered by any Air creature (ELEMENT-ONLY — §4).
/// Height cycles 0 → [kStormRodMaxHeight] → 0.
class StormRod {
  final String id;
  final Offset position;
  final int initialHeight;
  const StormRod({
    required this.id,
    required this.position,
    this.initialHeight = 0,
  });
}

/// The live storm-cell's circuit around the altar. The cell is always aloft;
/// gusts shove it along the ring, which is how the leader's starting point —
/// and therefore the staircase it must climb — is chosen.
/// A creature mid-throw, arcing from a riser to wherever the field's head can
/// put it. Held by the game, advanced each frame; the landing is whatever the
/// arc ends on, solid ground or not.
/// The Cinder Forge's casting moat, on the FAR shore.
///
/// One boulder lip at the head of a long channel that runs down to the
/// pedestal at its foot. Earth heaves a rock onto the lip; Fire melts it, and
/// the melt runs DOWN the channel — a little further with every press, and
/// creeping back whenever it is left alone, because the front of a run of
/// lava skins over the moment nobody is feeding it.
///
/// So the far shore is not a row of switches, it is a thing you have to keep
/// going: Fire works the melt while Earth feeds it rock, and if the pair of
/// them stop, the moat cools back up the hill. Steam is the one element that
/// would kill it outright, and Steam is the one that has to stay behind
/// holding the field — which is what makes the party split a decision.
class CastingMoat {
  /// The lip at the head of the channel, where a boulder stands.
  final Offset boulderAt;

  /// The channel itself, head at the top and foot at the pedestal.
  final Rect channel;

  const CastingMoat({required this.boulderAt, required this.channel});
}

class GeyserFlight {
  final Offset from;
  final Offset to;
  double t = 0;
  GeyserFlight(this.from, this.to);

  /// Height of the arc at its peak — taller for a longer throw, so a weak one
  /// visibly lobs and a full-head one visibly flies.
  double get lift => (to - from).distance * 0.30;
}

class StormCellOrbit {
  final Offset center;
  final double radius;

  /// Seconds for one full revolution (the cell drifts; gusts hurry it).
  final double period;

  /// Where the cell sits at run start, in radians.
  final double startAngle;

  /// Seconds between discharges.
  final double strikeInterval;

  const StormCellOrbit({
    required this.center,
    required this.radius,
    this.period = 26.0,
    this.startAngle = 0,
    this.strikeInterval = 4.6,
  });

  Offset positionAt(double angle) =>
      center + Offset(cos(angle) * radius, sin(angle) * radius);
}

/// Rods rank 0..3; conduit B (and the guardian) stand above every rod, so the
/// staircase always ENDS on a conduit — if the leader can climb that far.
const int kStormRodMaxHeight = 3;

/// How far a leader may leap from one conductor to the next.
const double kStormHopReach = 165.0;

/// The conductor rank of a struck conduit — above every rod by one.
const int kConduitConductorHeight = kStormRodMaxHeight + 1;

// ── Air Star 2: THE SPIRAL, COMPOSED (§9.1 spiral rework) ──
// The Gale Eye's echo is not WALKED, it is AUTHORED. A ring of gale vents
// surrounds a still eye; communing with one opens its jet PERMANENTLY for the
// attempt — Star 1's irreversible wind-authoring, in miniature. The eye only
// forms out of jets that COMPOSE: all tangent to the rim, all turning the same
// way. A jet that stabs inward or outward, or one that turns against the coil,
// shears the forming vortex apart — and that is watched, not read.
//
// The vent RING is authored here (below, in `spiral_cloud`); each vent's FLOW
// is rolled per run by `PlanetDungeonGame._rollSpiralVents()` and proved
// solvable by its public `solveSpiralVents()`, so no wiki can spoil it.

/// What a gale vent's jet does relative to the chamber's eye. The two coils are
/// named in the spire's own voice: **sunwise** turns the way the sun crosses
/// the crown, **widdershins** turns against it.
enum GaleVentFlow { sunwise, widdershins, inward, outward }

/// A gale vent in the Gale Eye. Its stone mouth is carved with the way it
/// breathes, so the direction is READABLE BEFORE it is touched — a vent, once
/// opened, cannot be shut until the chamber is left.
class GaleVent {
  final String id;

  /// The vent's voice, used by its "already blows" line.
  final String name;
  final Offset position;
  const GaleVent({
    required this.id,
    required this.name,
    required this.position,
  });
}

/// How many jets the eye needs before it closes into an echo.
const int kSpiralJetsNeeded = 4;

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
/// lit; a wrong brazier snuffs the whole rite (and the ash answers).
///
/// **REWORK (§6.1 / §9.1 item 3):** [order] is now only the AUTHORED FALLBACK.
/// The live rite order is ROLLED PER RUN (`PlanetDungeonGame.riteOrder`) so no
/// wiki can ever spoil it, and each brazier carries generated physical
/// testimony of the last rite — melted wax, a leaning soot shadow, an ash
/// drift — from which the whole order can be DEDUCED without any Mask. A
/// standalone hearth (a room with braziers but no `brazierStarIndex`) keeps
/// using [order] as plain identity.
class RitualBrazier {
  final int order;
  final Offset position;
  const RitualBrazier({required this.order, required this.position});
}

// ── Fire Star 2: the Ash Garden ────────────────────────────
// **REWORK (§9.1 follow-up) — THE WIND CARRIES THE REACTION.** The cloister
// garth is open to the sky and holds a CROSSWIND. Burning a bed no longer only
// marks that bed: the Plant+Fire→Dust reaction throws a PLUME of ash downwind,
// and it settles on every bed behind it in the lane. Each groove is cut for one
// specific gift — the drift (ash), the brand (a burn of its own bed), or
// nothing at all (a swept groove that must stay clean) — so the puzzle is
// choosing a wind quarter and a burn ORDER that leaves all six sitting true at
// once. The order is never handed over; it is DERIVED from the wind and the
// grooves.

/// What one groove is cut to receive (§6.1 rework).
enum GrooveDemand {
  /// The drift: this groove wants ash carried onto it from an upwind burn.
  ash,

  /// The brand: this bed must be burned itself, and never dusted afterwards.
  scorch,

  /// The swept groove: nothing may land here at all.
  clean,
}

/// THE BURN (Fire Star 2): the garth as a field of plantable soil, with the
/// coverage the ember pool demands. Cells are read from [art], one character
/// each, laid left-to-right and top-to-bottom over [bounds]:
///   `.` soil · `#` fallen stone · `~` wet ground · `v` vine already standing
///
/// Stone takes no vine and passes no flame — the maze wall. Wet ground grows
/// vine happily and NEVER catches, which is the trap that teaches the rule it
/// breaks: fuel is not the same as fire.
class BurnGarth {
  final List<String> art;

  /// Cells that must burn before the pool stands full and the star releases.
  /// Layout-tested against the longest chain the real rules permit.
  final int coverageGoal;

  /// The star this garth frees.
  final int starIndex;

  /// The side of one square, in world units.
  ///
  /// The field used to be stretched across the WHOLE room, which made a
  /// square 137x148 — so a phone showed about three columns of a six-column
  /// garden and the chain reaction, the entire point of the puzzle, happened
  /// mostly off-screen. Authored small enough that the board fits a portrait
  /// viewport with the garth's margins showing: 6x5 at 60 is 360x300, which
  /// clears a 390pt portrait screen with the kerb still on it.
  final double cell;

  /// Where the field's middle sits. Defaults to the room's middle.
  ///
  /// The garth is deliberately NOT centred on the wind vane any more: the
  /// vane's progress ring is 108 across, which is very nearly the four
  /// central squares — the ones a chain most often turns on — and it sat on
  /// top of them.
  final Offset? centre;

  const BurnGarth({
    required this.art,
    required this.coverageGoal,
    required this.starIndex,
    this.centre,
    this.cell = 60,
  });

  double get fieldWidth => cols * cell;
  double get fieldHeight => rows * cell;

  int get cols => art.isEmpty ? 0 : art.first.length;
  int get rows => art.length;
}

/// A scorched garden bed, standing on the garth's [col]/[row] grid. Plant
/// grows it over with vines; Fire burns the vines (Plant+Fire→Dust), which
/// brands THIS bed and throws its ash onto every bed downwind in the lane.
/// Growing a bed again buries whatever lies in it — that is the recovery path,
/// and it is why no arrangement of the garden can ever be softlocked.
///
/// The demand each groove carries is NOT authored: it is rolled per run (see
/// `PlanetDungeonGame.gardenDemands`) out of the assignments a brute-force
/// solver has proved solvable, wind-turn-requiring and inside the difficulty
/// band — so no wiki can spoil a garden.
class VineBed {
  final String id;
  final Offset position;

  /// Grid coordinates: [col] rises east, [row] rises south. The plume walks
  /// these, not the pixels.
  final int col;
  final int row;

  const VineBed({
    required this.id,
    required this.position,
    required this.col,
    required this.row,
  });
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

/// One of the two ways the vesper flame can be carried to the bells (§6.1
/// REWORK — "S3 gains one DECISION"). The bells never move; only the CENSER
/// RUN between them does, and each run trades differently:
///
///  • the short run through the ash-storm nave — fewer censers, so the flame
///    starves faster between them ([flameLifeScale] < 1) and the ash comes
///    heavier at every ignition ([igniteWisps] / [unstableWisps]);
///  • the long run round the calm cloister — two extra censers to keep alight,
///    but every gap is a single comfortable gust and the ash stays quiet.
///
/// A Fire creature lights the route's [standPosition] to declare it. The
/// choice stays open until the first censer of the run takes flame; after that
/// the vesper is COMMITTED (the rite has begun).
class VesperRoute {
  final String id;
  final String name;

  /// The censer stand a Fire creature lights to declare this run.
  final Offset standPosition;

  /// Censers per chain id — the run's own path to that chain's bell. A chain
  /// with no entry here keeps its authored [IncenseChain.nodes].
  final Map<String, List<Offset>> chainNodes;

  /// Multiplier on the flame's seconds-per-feeding (< 1 starves faster).
  final double flameLifeScale;

  /// Ash roused at each ignition, and whether it comes up unstable.
  final int igniteWisps;
  final bool unstableWisps;

  const VesperRoute({
    required this.id,
    required this.name,
    required this.standPosition,
    required this.chainNodes,
    this.flameLifeScale = 1.0,
    this.igniteWisps = 2,
    this.unstableWisps = false,
  });
}

// ── Water (Mirror Tide) — the drowned temple's verbs ───────
// World rule: every chamber answers to ONE temple-wide tide (low/mid/high),
// and the tide MOVES — floods and drains are animated, never a teleport.

/// A tide valve. Master valves set the temple to an explicit [level]
/// (0 low · 1 mid · 2 high) and are ELEMENT-ONLY (§4): any Water creature
/// turns one instantly, whatever its family. A [pipOnly] pipe-mouth ([level]
/// null) cycles the tide one step and is the temple's one HARD FAMILY GATE —
/// only a Water Pip fits down the pipes.
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
  const TideSeal({
    required this.id,
    required this.position,
    required this.tides,
  });
}

/// How high the temple's water must stand before a canal channel RUNS
/// (Star 2 — the moon-lantern rework, docs §6.4). Every channel is stone and
/// permanently visible; its sill is cut into the lip and reads at a glance.
/// This is the whole of the hidden information in the gallery: there is none.
enum CanalSill {
  /// Cut to the floor — it runs at every stand of water.
  low,

  /// Raised: it takes the middle water to start running.
  mid,

  /// A crest — only the HIGH water tops it. Dry below, and a lantern caught
  /// in it when the water falls is beached on the stone.
  crest,

  /// A deep cut. It runs at the low and middle water like any floor groove,
  /// but the high water drowns it into a TORRENT that swallows anything
  /// afloat on it. (Spirit's reading names these before you learn them the
  /// expensive way; at high water the churn names them for itself.)
  deep,
}

/// A basin in the gallery's canal network: the spring mouth the lantern is
/// set in, the sea drain that banks the star, or one of the stone basins
/// between them where the water turns and chooses its next groove.
class CanalNode {
  final String id;
  final Offset position;

  /// The spring: the one mouth the lantern can always be (re-)set in, which
  /// is what makes losing it structurally impossible to softlock on.
  final bool isSpring;

  /// The sea drain — the lantern reaching it banks the Current Star.
  final bool isSea;

  const CanalNode({
    required this.id,
    required this.position,
    this.isSpring = false,
    this.isSea = false,
  });

  /// A plain basin: the only kind Ice may plug into a dam.
  bool get isBasin => !isSpring && !isSea;
}

/// A carved channel between two basins. DIRECTED — the stone only falls one
/// way, and the fall is cut into the groove as chevrons the player can read
/// from the doorway. Its [sill] says at which stands of the temple-wide tide
/// it actually runs.
class CanalChannel {
  final String from;
  final String to;
  final CanalSill sill;
  const CanalChannel(this.from, this.to, this.sill);
}

/// A moon-pool (Star 3): at MID tide, Ice freezes it into a bridge-disc
/// (Spirit acting in the water braids the same — Spirit+Water→Ice). Only the
/// TRUE pools (the ones whose reflection holds the moon — Spirit insight
/// tells) take the ice; freezing a false pool shatters and angers the brine.
/// A basin in the moon well that may or may not be listening for the moon.
///
/// WHICH pools listen, and at what phase, is ROLLED PER RUN (see
/// `_rollMoonWell`) — the same rule as the choir's brazier order, so the
/// answer cannot be looked up. The data carries only where the basins are.
class MoonPool {
  final String id;
  final Offset position;
  const MoonPool({required this.id, required this.position});
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
/// (Lightning + Horn, nothing else) and LATCHES once held; 'B' is not channelled
/// by hand at all — the storm strikes it, if the rod field is ranked so the
/// leader can climb that far (§6.11 REWORK).
class Conduit {
  final String id;
  final Offset position;
  final String requireElement;

  /// Family the conduit gates on, or null for ELEMENT-ONLY — any creature of
  /// [requireElement] channels it.
  ///
  /// Null used to mean "not channelled by hand at all"; that meaning now lives
  /// on [struckByStorm], where it belongs. The two were conflated, so dropping
  /// a family gate to make a rite element-only made it unlightable instead.
  final DungeonAbility? requiredFamily;

  /// True for a conduit the storm-cell's leader may terminate on (conduit B).
  /// Struck conduits stand at [kConduitConductorHeight] — above every rod.
  final bool struckByStorm;

  const Conduit({
    required this.id,
    required this.position,
    required this.requireElement,
    this.requiredFamily,
    this.struckByStorm = false,
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
/// A storm-cell echo hiding in the Mirror Gallery.
///
/// THE GALLERY HOLDS NO LIGHT OF ITS OWN. It shares the cloud trunk with the
/// works, so feeding that trunk simply lights the room — and a lit room drowns
/// what the glass carries. Every OTHER wing the dynamo feeds throws its light
/// into the gallery through a pane of storm-glass, and each echo shows only in
/// the light of the one wing that belongs to it.
///
/// And the glass is a mirror, so it lies about the side: what you see standing
/// in the pane is the echo's REFLECTION, and the echo itself waits the same
/// distance the other way. Two readings, both stateable — which wing, and
/// which side — and no sweeping the floor.
class StormCell {
  final String id;
  final String cellType;

  /// Where the echo really waits (never drawn until it is bared).
  final Offset position;

  /// The centre of the pane of storm-glass that carries its light.
  final Offset pane;

  /// The plane the glass stands in — true for a pane you walk around
  /// left/right, false for one you walk around top/bottom.
  final bool paneVertical;

  /// How long the glass is, along its own plane.
  final double paneSpan;

  /// The wing whose borrowed light shows this echo. Feed any other trunk and
  /// the pane stands dark; feed the gallery's OWN (cloud) trunk and the room
  /// lights up and drowns every echo in it.
  final String showsUnderTrunk;

  const StormCell({
    required this.id,
    required this.cellType,
    required this.position,
    required this.pane,
    required this.showsUnderTrunk,
    this.paneVertical = true,
    this.paneSpan = 150,
  });

  /// Where the echo APPEARS — its reflection, mirrored across the glass.
  Offset get reflection => paneVertical
      ? Offset(2 * pane.dx - position.dx, position.dy)
      : Offset(position.dx, 2 * pane.dy - position.dy);

  /// The glass itself (solid — you walk around it, and walking around it is
  /// how you cross to the side the echo is really on).
  Rect get paneRect => paneVertical
      ? Rect.fromCenter(center: pane, width: 12, height: paneSpan)
      : Rect.fromCenter(center: pane, width: paneSpan, height: 12);
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

/// A geyser mouth (Steam, Star 1 — the Geyser Field). Every mouth in a room
/// erupts on ONE shared cycle, so the field breathes together.
///
/// Capping a mouth — a creature standing on it, a rock pushed onto it, or an
/// authored [blockedAtStart] slab — takes it out of the system, and the head
/// that was venting through it goes somewhere: every mouth still open blows
/// HARDER. That is the whole puzzle. Cap them all and the pressure has only
/// one place left to go: the capstone over the [GeyserCapstone] in the middle.
class GeyserMouth {
  final String id;
  final Offset position;

  /// Rubble already sitting on this mouth when the run begins — it counts as
  /// capped from the first frame and can never be cleared.
  final bool blockedAtStart;

  /// A RISER (Star 2): too wide a throat for one body to smother, so standing
  /// on it does not cap it — it THROWS you, and how far depends on how much
  /// of the field is shut. Only the rock is heavy enough to cap a riser.
  final bool isRiser;

  const GeyserMouth({
    required this.id,
    required this.position,
    this.blockedAtStart = false,
    this.isRiser = false,
  });
}

/// The middle mouth, held shut by a slab (Steam Star 1). It bursts — and the
/// star with it — only when every other mouth in the room is capped.
class GeyserCapstone {
  final Offset position;
  final int starIndex;
  const GeyserCapstone({required this.position, required this.starIndex});
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
  // Air Star 1 (WAKE THE WINDS): the wind graph + its shrines.
  final List<WindLedge> windLedges;
  final List<WindRoute> windRoutes;

  /// The four rune pillars ringing the hub compass — the Four Winds.
  ///
  /// Authored rather than computed on a radius so they are a THING IN THE
  /// ROOM: the pad can see them (an empty hub used to offer no action button
  /// at all, which quietly made Air's lost maxim unreachable), and the
  /// interaction and the render agree on where they stand.
  final List<Offset> windRunes;

  final List<GustShrine> gustShrines;
  final SpireSummit? summit;
  // Air Star 2 (THE SPIRAL, COMPOSED): the Gale Eye's ring of vents.
  final List<GaleVent> galeVents;
  // Air Star 3 (STORM-ROD STEERING): the rod field + the cell's circuit.
  final List<StormRod> stormRods;
  final StormCellOrbit? stormOrbit;
  final List<HiddenCloud> clouds;
  final List<LoomAnchor> anchors;
  final int? loomStarIndex; // star awarded when all anchors are satisfied
  final List<Conduit> conduits;
  final GuardianNode? guardian;
  // Fire (Cinder Cathedral) authored interactables:
  /// A one-line teach for the verb this room INTRODUCES, shown once ever on
  /// first entry. Null for rooms that teach nothing new.
  final String? teach;

  /// Corner torches that must ALL be lit before the room's mural can be read
  /// (Fire's scriptorium). Element-only: any Fire hand lights one.
  final List<Offset> muralTorches;

  final List<RitualBrazier> braziers;
  final int? brazierStarIndex; // star awarded for the full lit sequence
  final List<VineBed> vineBeds;
  final int? vineStarIndex; // star awarded when every groove sits true
  /// The garth's iron wind-cross: any Air creature standing here turns the
  /// cloister's crosswind one quarter (element-only, like the vesper gust).
  final Offset? windVane;
  final List<IncenseChain> incenseChains;

  /// The two censer runs the vesper flame may take to those same bells (§6.1
  /// REWORK). Empty = the chains' authored nodes are the only path.
  final List<VesperRoute> vesperRoutes;
  // Water (Mirror Tide) authored interactables:
  final List<TideValve> tideValves;
  final List<TideSeal> tideSeals;
  final int? sealStarIndex; // star awarded when every sluice seal is open
  final List<CanalNode> canalNodes; // spring + basins + the sea drain
  final List<CanalChannel> canalChannels; // the carved grooves, with sills
  final int? canalStarIndex; // star banked when the lantern reaches the sea
  final List<MoonPool> moonPools;

  /// Where Spirit stands to wane the moon (Water's Star 3). Null off the well.
  final Offset? moonDial;
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
  final List<BeamEmitter>
  beamEmitters; // Wind Vents (one emits per stationed Air)
  final List<BeamMirror> beamMirrors;
  final List<Offset>
  beamConverters; // Fire-converter spots (only some on a path)
  final Offset?
  beamReceiver; // the Storm Tower (lit only by the lightning beam)
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
  /// Fire Star 2: the burnable garth (THE BURN).
  final BurnGarth? garth;

  /// Steam Star 1: the geyser field and the capstone at its heart.
  final List<GeyserMouth> geysers;

  /// The Cinder Forge's casting moat, on its far shore.
  final CastingMoat? castingMoat;

  /// The span the finished cast lays across a chasm — the way home, earned.
  /// Impassable until the room's star is banked; it IS the thing you made.
  final Rect? castSpan;
  final GeyserCapstone? capstone;

  final MoltenGrid? molten; // a star room's spreading-lava grid
  final Offset? steamVent; // the entry-gate relief vent (Steam cracks it)
  final List<PressureSeal> pressureSeals; // clamped ring-main junction doors
  final Offset? stokePort; // firebox: Fire stokes the main (+pressure, +wisps)
  final BurstDisc? burstDisc; // vault passage blown open by venting the main

  // Poison (Venom Monastery) authored content — see
  // planet_dungeon_layout_poison.dart, where the fixtures themselves live.
  // Lava (Molten Reliquary) authored content — the line itself lives in
  // planet_dungeon_layout_lava.dart (nodes, channels and rules together), so
  // a room only has to say which star it holds.
  /// The star this stretch of the foundry line banks, and where it stands.
  final FoundryStarSpot? foundryStar;

  /// This room IS a quarantine ward (null = it is not one).
  final WardCell? ward;

  /// The infirmary still, or the crypt's carrion font: four taps of physic.
  final Apothecary? apothecary;

  /// The prior's seal — where the triage is committed, and where Poison
  /// declares its two non-guardian star indices.
  final PriorsSeal? priorsSeal;

  /// Ice (the Frozen Observatory): this level's shaft content — its star, the
  /// orrery/mirror puzzle, and the single objects (cap, rimefall, font,
  /// hoarfrost, telescope). One field, because the shaft's own graph is
  /// authored whole in planet_dungeon_layout_ice.dart rather than per room.
  final IceShaft? rime;

  /// Mud (the Sinking Altar): this room's fen content — the knoll it IS, its
  /// moor-altar, the sinking altar's socket, the sough, the sink-pit, the
  /// hollow's mire anchor. One field, because the fen's own crossing graph is
  /// authored whole in planet_dungeon_layout_mud.dart rather than per room.
  final BogFen? fen;

  /// Plant (the Verdant Crypt): this room's content in the crypt that is one
  /// geometry at two sizes — its star, the boles and mulch pits, and the
  /// single objects (briar, lamp, growth altar, sepulchre, shade seed, the
  /// arena's root-gall). One field, because the crypt's spans and beds are
  /// authored whole in planet_dungeon_layout_plant.dart rather than per room,
  /// exactly as Ice's shaft and Dust's mounds are.
  final CryptGrove? grove;

  /// Dark (the Eclipse Vault): which QUARTER of the eclipse this room lies in,
  /// its star, and the single objects (the pall, the analemma, the snuffer,
  /// the abyss, the arena's shadow-vane). One field, because the vault's
  /// spans, gnomons and anchors are authored whole in
  /// planet_dungeon_layout_dark.dart rather than per room, exactly as Ice's
  /// shaft and Plant's crypt are.
  final EclipseHall? eclipse;

  /// Light (the Beacon Archive): which SECTOR of the one great hall this bay
  /// lies in, its star, and the single objects (the door-shutter, the court's
  /// balustrade, the reading floor's shutter-ring, the arena's pillars). One
  /// field, because the hall's sills, beacons, effigies and slips are authored
  /// whole in planet_dungeon_layout_light.dart rather than per room, exactly
  /// as Ice's shaft and Dark's quarters are.
  final ArchiveHall? hall;

  /// Blood (the Sanguine Orrery): this chamber's content on the figure-eight
  /// of veins — its star, and the single objects (the pericardium, the rite's
  /// balance, the heart-drum, the arena's vagal node). One field, because the
  /// orrery's passages, ostia and collaterals are authored whole in
  /// planet_dungeon_layout_blood.dart rather than per room, exactly as Ice's
  /// shaft, Plant's crypt and Dark's vault are.
  final SanguineChamber? sanguine;

  /// Dust (the Ruins of Time): this room's content on the buried city's two
  /// Z-layers — its star, the drift yard, and the single objects (vane, silt,
  /// armillary, glass, the hollow's cut). One field, because the city's mounds
  /// are authored whole in planet_dungeon_layout_dust.dart rather than per
  /// room, exactly as Ice's shaft is.
  final DustRuins? ruins;

  /// Crystal (the Prism Labyrinth): this room's place in the sliding keep —
  /// the lattice CELL it is, the two stars the oriel declares, the glass face,
  /// a tuning boss, the facet font, Prismalith's shunting floor. One field,
  /// because the keep's chambers and its whole rule set are authored in
  /// planet_dungeon_layout_crystal.dart rather than per room, exactly as
  /// Ice's shaft and Dust's mounds are.
  final PrismHall? prism;

  /// Spirit (the Echo Grave): this room's content in the field's two overlaid
  /// worlds — the barrow it is, the gate's vigil, its lych-stone, the grave
  /// mouth, the drowned cut's brink, its sigil half, the grave-lamp and
  /// Wraithord's stone. One field, because the field's crossing graph is
  /// authored whole in planet_dungeon_layout_spirit.dart rather than per room,
  /// exactly as Plant's spans and Crystal's lattice are.
  final EchoGrave? grave;

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
    this.windLedges = const [],
    this.windRoutes = const [],
    this.windRunes = const [],
    this.gustShrines = const [],
    this.summit,
    this.galeVents = const [],
    this.stormRods = const [],
    this.stormOrbit,
    this.clouds = const [],
    this.anchors = const [],
    this.loomStarIndex,
    this.conduits = const [],
    this.guardian,
    this.teach,
    this.muralTorches = const [],
    this.braziers = const [],
    this.brazierStarIndex,
    this.vineBeds = const [],
    this.vineStarIndex,
    this.windVane,
    this.incenseChains = const [],
    this.vesperRoutes = const [],
    this.tideValves = const [],
    this.tideSeals = const [],
    this.sealStarIndex,
    this.canalNodes = const [],
    this.canalChannels = const [],
    this.canalStarIndex,
    this.moonPools = const [],
    this.moonDial,
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
    this.garth,
    this.geysers = const [],
    this.castingMoat,
    this.castSpan,
    this.capstone,
    this.molten,
    this.steamVent,
    this.pressureSeals = const [],
    this.stokePort,
    this.burstDisc,
    this.foundryStar,
    this.ward,
    this.apothecary,
    this.priorsSeal,
    this.rime,
    this.fen,
    this.ruins,
    this.prism,
    this.grave,
    this.grove,
    this.eclipse,
    this.hall,
    this.sanguine,
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
  /// kCosmicPlanetEntry slots), or [kAnyElement] when the gate is VERB-ONLY —
  /// the family's physical act is the whole requirement and the element is
  /// incidental. A wing asked only to fly, a horn asked only to shove and a
  /// pip asked only to fit answer from ANY element; demanding a particular
  /// one as well is a second lock the fiction never asked for.
  final String element;

  /// True when this gate demands an element as well as a family. Only these
  /// can make a planet unenterable, so the descent gate counts them
  /// separately from the verb-only kind.
  bool get needsElement => element != kAnyElement;

  /// How the requirement reads on the descent panel: 'Lightning HORN' for a
  /// full lock, 'any HORN' when only the verb matters.
  String get label => needsElement
      ? '$element ${family.toUpperCase()}'
      : 'any ${family.toUpperCase()}';

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
  /// A verb-only gate has no element, so it stamps 'gate:any_wing' rather
  /// than 'gate:_wing' — a readable id, and one that cannot collide with a
  /// future element literally named the empty string.
  String get discoveryId =>
      'gate:${needsElement ? element.toLowerCase() : 'any'}'
      '_${family.toLowerCase()}';
}

extension DungeonRoomAffordances on DungeonRoom {
  /// Does this room hold anything the party can ACT on?
  ///
  /// Deliberately about the room's authored contents, not about what is
  /// currently in reach — the HUD uses it to decide whether to show an action
  /// button at all, and a button that blinks in and out as you walk past
  /// objects would be worse than one that is always there.
  ///
  /// Pure geometry is excluded on purpose: walls, doors, hazards, gaps,
  /// platforms and tide zones are things you move through, not things you use.
  bool get hasVerbs => guardian != null || hasVerbsBesidesGuardian;

  /// The same question, with the BOSS ITSELF discounted.
  ///
  /// A guardian is a verb — you strike it, or a Kin calms it — so it belongs
  /// in `hasVerbs`. But it is the one verb the action pad already covers with
  /// its own button, so a boss room holding nothing else shows a utility
  /// control whose only answer is the attack you could already make. During a
  /// fight that is not merely dead, it is a lie about the room: it says look
  /// around, and there is nothing to look at.
  ///
  /// So the fight asks THIS instead, and the utility appears mid-boss exactly
  /// when the room has something in it — the Air altar's conduits, the
  /// Sanguine mouths — and stays away when the arena is bare.
  bool get hasVerbsBesidesGuardian =>
      // Shared furniture
      //
      // CURRENTS COUNT. They look like traversal and mostly are, but a Fire
      // creature acting inside one is a verb — it is Air's entry rite, and
      // leaving currents off this list hid the action cluster in the very
      // first room of the Air dungeon, so the rite could not be performed and
      // the run could not start.
      currents.isNotEmpty ||
      clouds.isNotEmpty ||
      anchors.isNotEmpty ||
      conduits.isNotEmpty ||
      stars.isNotEmpty ||
      vaultCache != null ||
      // Air
      windRunes.isNotEmpty ||
      gustShrines.isNotEmpty ||
      galeVents.isNotEmpty ||
      stormRods.isNotEmpty ||
      summit != null ||
      // Fire
      braziers.isNotEmpty ||
      muralTorches.isNotEmpty ||
      vineBeds.isNotEmpty ||
      incenseChains.isNotEmpty ||
      vesperRoutes.isNotEmpty ||
      windVane != null ||
      garth != null ||
      // Water
      tideValves.isNotEmpty ||
      tideSeals.isNotEmpty ||
      canalNodes.isNotEmpty ||
      moonPools.isNotEmpty ||
      moonDial != null ||
      // Earth
      fossilRibs.isNotEmpty ||
      fossilPillars.isNotEmpty ||
      sternumPlate != null ||
      stoneScale != null ||
      // Lightning
      circuitNodes.isNotEmpty ||
      stormCells.isNotEmpty ||
      cellSockets.isNotEmpty ||
      beamMirrors.isNotEmpty ||
      fulminateVats.isNotEmpty ||
      vaultBolt != null ||
      coreBreaker != null ||
      // Steam
      geysers.isNotEmpty ||
      capstone != null ||
      molten != null ||
      steamVent != null ||
      stokePort != null ||
      burstDisc != null ||
      // The eleven authored since — each carries one payload object.
      foundryStar != null ||
      ward != null ||
      apothecary != null ||
      priorsSeal != null ||
      rime != null ||
      fen != null ||
      grove != null ||
      eclipse != null ||
      hall != null ||
      sanguine != null ||
      ruins != null ||
      prism != null ||
      grave != null;
}

/// Everything [element]'s dungeon will demand of a descent party beyond its
/// three entry elements, derived from the authored family gates.
///
/// Derived rather than hand-listed on purpose: the descent panel and the
/// dungeon then cannot disagree about what is required, which is the failure
/// this whole change exists to remove. A player used to learn a requirement by
/// walking to a locked door with no key.
List<DungeonEntryDemand> dungeonEntryDemands(String element) {
  final layout = kPlanetDungeonLayouts[element];
  if (layout == null) return const [];
  final seen = <String>{};
  final out = <DungeonEntryDemand>[];
  for (final g in layout.familyGates) {
    // Two gates wanting the same key are one demand.
    if (!seen.add('${g.element}/${g.family}')) continue;
    out.add(
      DungeonEntryDemand(
        family: g.family,
        element: g.needsElement ? g.element : null,
        label: g.label,
      ),
    );
  }
  return out;
}

/// The demands [party] cannot currently meet. Empty means the descent can
/// finish everything the planet locks.
List<DungeonEntryDemand> unmetEntryDemands(
  String element,
  Iterable<CosmicPartyMember?> party,
) => [
  for (final d in dungeonEntryDemands(element))
    if (!d.satisfiedBy(party)) d,
];

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

  /// THE PRIMER: the planet's world rule, in one or two lines, shown ONCE
  /// ever on the first descent and never again.
  ///
  /// Not the old objective chatter coming back. That spoke on every room
  /// entry and was dropped for teaching players to ignore the capsule; this
  /// fires once per save, for the one thing a player cannot deduce by looking
  /// — the rule the whole planet runs on.
  final List<String> primer;

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

  /// Hint when a creature leans on the guardian chamber's door before the
  /// planet's rite has roused the mystic. The chamber is SEALED until then —
  /// a boss is walked into on purpose, never wandered into. Names the rite,
  /// never the method (§5.6). Null falls back to a generic line.
  final String? guardianSealedHint;

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
    this.primer = const [],
    this.stars = const [],
    this.entranceRevealDoor,
    this.finaleDoor,
    this.riteAnnouncement,
    this.finaleSealedHint,
    this.guardianSealedHint,
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
      if (room.canalStarIndex != null) seen.add(room.canalStarIndex!);
      if (room.ribStarIndex != null) seen.add(room.ribStarIndex!);
      if (room.pillarStarIndex != null) seen.add(room.pillarStarIndex!);
      if (room.circuitStarIndex != null) seen.add(room.circuitStarIndex!);
      if (room.molten?.starIndex != null) seen.add(room.molten!.starIndex!);
      // The two 2026-08-14 reworks: Fire's burnable garth and Steam's geyser
      // field both carry their planet's star on the object, not on a room flag.
      if (room.garth != null) seen.add(room.garth!.starIndex);
      if (room.capstone != null) seen.add(room.capstone!.starIndex);
      // Lava carries each of its non-guardian stars on the room the line
      // leaves you in.
      if (room.foundryStar != null) seen.add(room.foundryStar!.starIndex);
      // Poison carries BOTH of its non-guardian stars on the prior's seal: a
      // cure can bank Star 1 in any of the four wards, so no ward owns it.
      final seal = room.priorsSeal;
      if (seal != null) {
        seen.add(seal.diagnosisStarIndex);
        seen.add(seal.triageStarIndex);
      }
      // Ice's two puzzle levels carry their star on the room's shaft content.
      if (room.rime?.starIndex != null) seen.add(room.rime!.starIndex!);
      // Mud declares BOTH of its non-guardian stars on the Sinking Altar's
      // socket: the Moor Star completes in whichever of the three moor knolls
      // is dried last, so no knoll owns it.
      final socket = room.fen?.altar;
      if (socket != null) {
        seen.add(socket.sarsenStarIndex);
        seen.add(socket.moorStarIndex);
      }
      // Dust does the same with its two Z-layers: the seal street above and
      // the observatory below.
      if (room.ruins?.starIndex != null) seen.add(room.ruins!.starIndex!);
      // Crystal declares BOTH of its non-guardian stars on the oriel: neither
      // belongs to a room — one is a fact about the keep's middle ROW and the
      // other about the heart cell's four faces, and both can complete while
      // the player stands anywhere in the lattice.
      final keep = room.prism?.keep;
      if (keep != null) {
        seen.add(keep.spectrumStarIndex);
        seen.add(keep.throneStarIndex);
      }
      // Plant does the same with its one geometry at two sizes: the lantern
      // court above and the islet across the rill.
      if (room.grove?.starIndex != null) seen.add(room.grove!.starIndex!);
      // Spirit declares BOTH of its non-guardian stars on the lych gate:
      // neither belongs to a room — one is a fact about the LIVING crossings
      // of the whole grave-field, the other about two halves of a sigil that
      // lie in different worlds.
      final vigil = room.grave?.vigil;
      if (vigil != null) {
        seen.add(vigil.roadStarIndex);
        seen.add(vigil.sigilStarIndex);
      }
      // Dark carries its two non-guardian stars on the quarter a room lies
      // in: the analemma court in the pall, the ossuary ring in the bones.
      if (room.eclipse?.starIndex != null) seen.add(room.eclipse!.starIndex!);
      // Light does the same with the sector a bay lies in: the shadow court in
      // the court bay, the dark stacks out past both great stacks.
      if (room.hall?.starIndex != null) seen.add(room.hall!.starIndex!);
      // Blood carries its two non-guardian stars on the chamber a room is:
      // the vena crossing where the eight crosses itself, and the capillary
      // weave at the far end of the lung.
      if (room.sanguine?.starIndex != null) {
        seen.add(room.sanguine!.starIndex!);
      }
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
  guardianSealedHint:
      'The summit stair is shut — the crown wakes no bird until the twin '
      'conduits sing',
  mercyShrineRoomId: 'storm_altar',
  // Ideal: Airwing · Firemask · Lightninghorn — hinted by VERB, never by
  // body part. §9.1 NOTE: the crown is no longer climbed on wings — a woken
  // gale carries walkers just as well — so the first verse now names the
  // WIND-WORK, not flight, and no longer promises the ground-shy a private
  // road.
  riddle: [
    'Send me Air: my crown is woken, never climbed;',
    'a Lightning Horn, for my storm-walls answer nothing weaker;',
    'and Fire, for my thunder must have somewhere to stay.',
  ],
  primer: [
    'A gale you wake never sleeps again.',
    'Each one is a ladder somewhere and a wall somewhere else, so the order you wake them in is the whole question.',
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
      // THE FOUR WINDS. Ringing the compass at radius 235 from its heart
      // (460, 340) — the same ring the pillars have always been drawn on,
      // written down so the room can be acted on rather than only looked at.
      // Clockwise from the north-east: NE, SE, SW, NW.
      windRunes: [
        Offset(626, 174),
        Offset(626, 506),
        Offset(294, 506),
        Offset(294, 174),
      ],
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

    // Room C — Lower Spire Path. The spire's FIRST BREATH and its RIDGE.
    // Two gales sleep here: the thermal that lifts the west perch (and, once
    // woken, scours the ridge stair) and the riser that carries the ridge to
    // the spire's shoulder.
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
          targetSpawn: Offset(120, 300),
        ),
      ],
      // Footing = the wind graph's ledges, then its PLAIN walkways. A gale
      // ride is wind, not stone, and lays no footing.
      platforms: [
        Rect.fromLTWH(140, 820, 260, 110), // l_base
        Rect.fromLTWH(430, 600, 230, 90), // l_ridge
        Rect.fromLTWH(45, 400, 225, 90), // l_perch
        Rect.fromLTWH(470, 70, 235, 95), // l_high
        Rect.fromLTWH(370, 600, 120, 280), // r_stair
        Rect.fromLTWH(250, 440, 200, 250), // r_ledgewalk
      ],
      windLedges: [
        WindLedge(id: 'l_base', rect: Rect.fromLTWH(140, 820, 260, 110)),
        WindLedge(id: 'l_ridge', rect: Rect.fromLTWH(430, 600, 230, 90)),
        WindLedge(id: 'l_perch', rect: Rect.fromLTWH(45, 400, 225, 90)),
        WindLedge(id: 'l_high', rect: Rect.fromLTWH(470, 70, 235, 95)),
      ],
      windRoutes: [
        // The ridge stair — plain stone, hanging over open sky on both sides.
        // Once the First Breath blows, its spill shoves anything climbing the
        // stair straight off the west lip: the stair is CLOSED, and the ridge
        // shrine behind it must be taken the long way.
        WindRoute(
          id: 'r_stair',
          from: 'l_base',
          to: 'l_ridge',
          path: Rect.fromLTWH(370, 600, 120, 280),
          sweptBy: ['g_thermal'],
          twoWay: true,
        ),
        // The thermal itself: the west perch's only ladder.
        WindRoute(
          id: 'r_column',
          from: 'l_base',
          to: 'l_perch',
          path: Rect.fromLTWH(150, 470, 120, 370),
          ridesGale: 'g_thermal',
        ),
        // The shoulder ledgewalk. Its east end runs through the SAME spill,
        // but there the wind only pushes you back along stone — so it stays
        // passable, and stays expensive. This is the long way to the ridge.
        WindRoute(
          id: 'r_ledgewalk',
          from: 'l_perch',
          to: 'l_ridge',
          path: Rect.fromLTWH(250, 440, 200, 250),
          costly: true,
          twoWay: true,
        ),
        // The ridge riser — the spire's shoulder has no other road.
        WindRoute(
          id: 'r_riser',
          from: 'l_perch',
          to: 'l_high',
          path: Rect.fromLTWH(160, 150, 350, 290),
          ridesGale: 'g_ramp',
        ),
      ],
      gustShrines: [
        GustShrine(
          id: 'shrine_first',
          name: 'the First Breath',
          ledgeId: 'l_base',
          position: Offset(225, 878),
          wakesGale: 'g_thermal',
        ),
        GustShrine(
          id: 'shrine_ridge',
          name: 'the Ridge Riser',
          ledgeId: 'l_ridge',
          position: Offset(575, 645),
          wakesGale: 'g_ramp',
        ),
      ],
      currents: [
        // g_thermal — the west column: the perch's only ladder…
        WindCurrent(
          rect: Rect.fromLTWH(150, 470, 120, 370),
          dir: Offset(0, -1),
          strength: 92,
          galeId: 'g_thermal',
        ),
        // …and the same breath, spilling WEST across the ridge stair and the
        // ledgewalk's east end. 150 is chosen against the 150px/s walk: you
        // can walk straight into it and win slowly (the ledgewalk), but you
        // cannot climb ACROSS it (the stair) — the diagonal loses.
        WindCurrent(
          rect: Rect.fromLTWH(360, 440, 140, 450),
          dir: Offset(-1, -0.2),
          strength: 150,
          galeId: 'g_thermal',
        ),
        // g_ramp — the riser off the perch to the spire's shoulder.
        WindCurrent(
          rect: Rect.fromLTWH(160, 150, 350, 290),
          dir: Offset(0.85, -1),
          strength: 96,
          galeId: 'g_ramp',
        ),
        // THE FLUE — an always-on wild wind up the spire's east face, never
        // part of the wind graph and never needed for the crown. It is a
        // swift flier's shortcut from open sky straight to the shoulder, and
        // its Speed threshold therefore scales a BONUS, not progress (§4:
        // stats scale magnitude; hard stat gates never gate a road).
        WindCurrent(
          rect: Rect.fromLTWH(640, 150, 115, 690),
          dir: Offset(-0.2, -1),
          strength: 132,
          requiredSpeed: 3.5,
        ),
      ],
    ),

    // Room D — Crosswind Hall. The middle pillar stands ABOVE the crosswind's
    // river; the catwalk to it dips through the wind.
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
        Rect.fromLTWH(20, 240, 210, 110), // x_west
        Rect.fromLTWH(400, 150, 180, 110), // x_mid
        Rect.fromLTWH(750, 235, 180, 110), // x_east
        Rect.fromLTWH(215, 215, 200, 60), // r_catwalk
        Rect.fromLTWH(575, 175, 180, 95), // r_scarp
      ],
      windLedges: [
        WindLedge(id: 'x_west', rect: Rect.fromLTWH(20, 240, 210, 110)),
        WindLedge(id: 'x_mid', rect: Rect.fromLTWH(400, 150, 180, 110)),
        WindLedge(id: 'x_east', rect: Rect.fromLTWH(750, 235, 180, 110)),
      ],
      windRoutes: [
        // The catwalk sags into the river's line — once the crosswind blows,
        // nothing walks it in either direction.
        WindRoute(
          id: 'r_catwalk',
          from: 'x_west',
          to: 'x_mid',
          path: Rect.fromLTWH(215, 215, 200, 60),
          sweptBy: ['g_cross'],
          twoWay: true,
        ),
        // The river: it carries you clean past the middle pillar to the east.
        WindRoute(
          id: 'r_river',
          from: 'x_west',
          to: 'x_east',
          path: Rect.fromLTWH(200, 210, 590, 150),
          ridesGale: 'g_cross',
        ),
        // Stepping off the pillar downwind is free.
        WindRoute(
          id: 'r_river_mid',
          from: 'x_mid',
          to: 'x_east',
          path: Rect.fromLTWH(400, 210, 390, 150),
          ridesGale: 'g_cross',
        ),
        // The scarp: claw back up the pillar's east face out of the wind. It
        // always exists; it always costs.
        WindRoute(
          id: 'r_scarp',
          from: 'x_east',
          to: 'x_mid',
          path: Rect.fromLTWH(575, 175, 180, 95),
          costly: true,
        ),
      ],
      gustShrines: [
        GustShrine(
          id: 'shrine_span',
          name: 'the Crosswind',
          ledgeId: 'x_west',
          position: Offset(105, 296),
          wakesGale: 'g_cross',
        ),
        GustShrine(
          id: 'shrine_crown',
          name: 'the Crownwind',
          ledgeId: 'x_mid',
          position: Offset(490, 186),
          wakesGale: 'g_crown',
        ),
      ],
      currents: [
        // g_cross — the crosswind river, running below the middle pillar's
        // crown and straight over the catwalk.
        WindCurrent(
          rect: Rect.fromLTWH(200, 210, 590, 150),
          dir: Offset(1, 0.05),
          strength: 110,
          galeId: 'g_cross',
        ),
      ],
    ),

    // Room E — Cloud Platform Room. The last climb: scree, step, crown.
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
        Rect.fromLTWH(150, 780, 210, 110), // c_low
        Rect.fromLTWH(100, 430, 200, 100), // c_step
        Rect.fromLTWH(315, 55, 220, 100), // c_crown
        Rect.fromLTWH(180, 510, 140, 290), // r_scree
        Rect.fromLTWH(280, 140, 160, 300), // r_crown_drop
      ],
      windLedges: [
        WindLedge(id: 'c_low', rect: Rect.fromLTWH(150, 780, 210, 110)),
        WindLedge(id: 'c_step', rect: Rect.fromLTWH(100, 430, 200, 100)),
        WindLedge(id: 'c_crown', rect: Rect.fromLTWH(315, 55, 220, 100)),
      ],
      windRoutes: [
        WindRoute(
          id: 'r_scree',
          from: 'c_low',
          to: 'c_step',
          path: Rect.fromLTWH(180, 510, 140, 290),
          twoWay: true,
        ),
        WindRoute(
          id: 'r_crownwind',
          from: 'c_step',
          to: 'c_crown',
          path: Rect.fromLTWH(180, 140, 190, 320),
          ridesGale: 'g_crown',
        ),
        WindRoute(
          id: 'r_crown_drop',
          from: 'c_crown',
          to: 'c_step',
          path: Rect.fromLTWH(280, 140, 160, 300),
        ),
      ],
      currents: [
        // g_crown — the last riser, woken far below in the crosswind hall.
        WindCurrent(
          rect: Rect.fromLTWH(180, 140, 190, 320),
          dir: Offset(0.35, -1),
          strength: 118,
          galeId: 'g_crown',
        ),
      ],
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

    // Room G — Spiral Cloud Room, THE GALE EYE (§9.1 spiral rework).
    // Seven vents ring a still eye at radius 210. The ring is authored; which
    // way each vent breathes is rolled per run (`_rollSpiralVents`). Four
    // composing jets close the eye, so three of the seven are always decoys —
    // and the trial is a commitment, not a walk.
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
      galeVents: [
        GaleVent(
          id: 'v_north',
          name: 'the north mouth',
          position: Offset(350, 75),
        ),
        GaleVent(
          id: 'v_dawn',
          name: 'the dawn mouth',
          position: Offset(514, 154),
        ),
        GaleVent(
          id: 'v_east',
          name: 'the east mouth',
          position: Offset(555, 332),
        ),
        GaleVent(
          id: 'v_low',
          name: 'the low mouth',
          position: Offset(441, 474),
        ),
        GaleVent(
          id: 'v_deep',
          name: 'the deep mouth',
          position: Offset(259, 474),
        ),
        GaleVent(
          id: 'v_west',
          name: 'the west mouth',
          position: Offset(145, 332),
        ),
        GaleVent(
          id: 'v_dusk',
          name: 'the dusk mouth',
          position: Offset(186, 154),
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
          targetSpawn: Offset(120, 452),
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
      conduits: [
        Conduit(
          id: 'A',
          position: Offset(140, 330),
          requireElement: 'Lightning',
          // HARD GATE: only a Lightning Horn holds this current. It LATCHES.
          requiredFamily: DungeonAbility.heavyForce,
        ),
        Conduit(
          id: 'B',
          position: Offset(770, 150),
          // Nothing channels B by hand — the storm strikes it, or nothing does.
          // It sits HIGH in the far corner, above and beyond the whole rod
          // field, so the room reads its own rule at a glance: the only way to
          // that pylon is a ladder of iron climbing toward it.
          requireElement: 'Lightning',
          struckByStorm: true,
        ),
      ],
      // The cell's circuit never brings it within a leader's leap of conduit B
      // (nearest approach 224 > kStormHopReach): the bolt only ever arrives up
      // a staircase the player ranked.
      stormOrbit: StormCellOrbit(
        center: Offset(420, 330),
        radius: 170,
        period: 26,
        startAngle: 3.14159,
        strikeInterval: 4.6,
      ),
      stormRods: [
        StormRod(id: 'rod_low', position: Offset(590, 250)),
        StormRod(id: 'rod_deep', position: Offset(585, 425)),
        StormRod(id: 'rod_north', position: Offset(680, 200)),
        StormRod(id: 'rod_axis', position: Offset(665, 335)),
        StormRod(id: 'rod_south', position: Offset(685, 455)),
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
      // §7 retrofit: the Roc DRAGS the storm-cell across this rod field. The
      // orbit's centre is a leash behind the bird, so the cell can never reach
      // it unaided — rank the rods into a staircase and the storm strikes its
      // own guardian, which is the only thing that opens a full lull.
      stormOrbit: StormCellOrbit(
        center: Offset(410, 300),
        radius: 90,
        period: 14,
        strikeInterval: 3.6,
      ),
      // A RING of perch-rods at radius 150 about the bird's ground: neighbours
      // sit 115 apart (inside a leader's leap) so a staircase can be built all
      // the way round, and the whole ring stands inside the Roc's own strike
      // reach — the bolt's last leap into a mountain of feathers is longer than
      // its leap between irons.
      stormRods: [
        StormRod(id: 'perch_e', position: Offset(560, 300)),
        StormRod(id: 'perch_se', position: Offset(516, 406)),
        StormRod(id: 'perch_s', position: Offset(410, 450)),
        StormRod(id: 'perch_sw', position: Offset(304, 406)),
        StormRod(id: 'perch_w', position: Offset(260, 300)),
        StormRod(id: 'perch_nw', position: Offset(304, 194)),
        StormRod(id: 'perch_n', position: Offset(410, 150)),
        StormRod(id: 'perch_ne', position: Offset(516, 194)),
      ],
    ),
  },
);

/// Fire layout: Cinder Cathedral. *Fire remembers the order it was lit.* A
/// soot-black gothic interior on the planet Pyrathis: a cold narthex hearth
/// guards the way in; the nave is the hub under a rose window of ember glass.
/// Star 1 (Ember) — the choir's four braziers must be lit in the order the
/// cathedral remembers (the scriptorium's soot mural diagrams it; a Mask
/// reads it). Star 2 (Ash) — the cloister garth holds a crosswind: Plant grows
/// a bed, Fire burns it (Plant+Fire→Dust), and the reaction's ash rides the
/// wind onto the beds downwind — every groove is cut for a different gift, so
/// the wind quarter and the burn order are the puzzle. Star 3 (Pyre) — beyond
/// the sealed chancel gate, flame
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
  guardianSealedHint:
      'The sanctum door holds fast — nothing in there stirs until every '
      'ember bell has tolled',
  mercyShrineRoomId: 'high_altar',
  // Ideal: Firemask · Plantmane · Airwing — hinted by VERB, never by body
  // part: insight, the trail-leaving passage, flight.
  riddle: [
    'Send me Fire: my choir is ash, and ash is scripture;',
    'Air, to carry my censer-flame the length of the nave;',
    'and Plant, for my garden greens only where something living has passed.',
  ],
  primer: [
    'Fire remembers the order it was lit, and nothing here will tell you that order.',
    'The iron kept the evidence: wax, soot and ash.',
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
      teach:
          'Soot on a dark wall. Light the four corners before you try to read it.',
      bounds: Rect.fromLTWH(0, 0, 640, 520),
      // Four corner torches. The mural is soot on a dark wall in a room with
      // no window: unlit, there is nothing to read, and the panel says so.
      // Lighting all four is what brings the first recorded station up.
      muralTorches: [
        Offset(70, 70),
        Offset(570, 70),
        Offset(70, 450),
        Offset(570, 450),
      ],
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(265, 496, 110, 24),
          targetRoomId: 'nave',
          targetSpawn: Offset(225, 90),
        ),
      ],
    ),

    // Room D — Choir. Star 1: six ritual braziers around the choir stalls.
    // Their remembered order is deliberately NOT spatial, and (REWORK §6.1) it
    // is ROLLED PER RUN — so it can only be DEDUCED, from the physical
    // testimony the last rite left on the iron: wax melted lowest burned
    // longest, soot shadows lean away from whichever neighbour was already
    // alight, and the ash has drifted downwind of the whole sequence. The six
    // positions below are spread wide and unevenly on purpose: the soot leans
    // must point at ONE unmistakable neighbour each.
    'choir': DungeonRoom(
      id: 'choir',
      teach:
          'The rite\'s order is not written anywhere. The iron wears it: wax, soot and drifted ash.',
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

    // Room E — Cloister. Star 2: THE WIND CARRIES THE REACTION. The garth is
    // open to the sky and holds a crosswind; six scorched beds stand on a 3×2
    // grid around the dry fountain, whose iron wind-cross any Air creature
    // turns a quarter at a time. Plant overgrows a bed, Fire burns it — the
    // Plant+Fire→Dust reaction brands THAT bed and throws its ash down the
    // lane onto every bed behind it. Each groove is cut for one gift (drift /
    // brand / nothing), rolled per run, so the wind quarter and the burn ORDER
    // are the whole puzzle. Regrowing buries a fouled bed: nothing is ever
    // lost, only paid for.
    'cloister': DungeonRoom(
      id: 'cloister',
      teach:
          'Lay vine, strike ONCE, and turn the wind to walk the flame — every square must burn from that single fire, and burnt ground never takes vine again.',
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
      // The grid is deliberately WIDER than it is deep: an east/west wind runs
      // a three-bed lane (a chain), a north/south wind only a pair — so the
      // two axes are not interchangeable and a quarter turn really changes the
      // problem.
      // THE BURN (2026-08-14): the garth is now a field you route a fire
      // across, not six beds that ask for things. 9x7 cells over the room.
      // The cloister's fallen columns are the maze; the seep around the dry
      // fountain grows vine that will never catch. The doors sit on the top
      // and bottom edges at cols 3-5, so those lanes are left open.
      // THE GARTH — 6x5, and every square of it must burn from ONE strike.
      //
      // Was 9x7 with a goal of 26 of 56: too many cells to read at a glance,
      // and a target you could nibble at. Smaller is not just tidier here, it
      // is what makes the real goal PROVABLE — "burn the whole garden in one
      // chain" is a Hamiltonian path over the soil, and that is only decidable
      // on a field this size.
      //
      // The four rocks are placed to balance the checkerboard (two on each
      // colour), which is what keeps a full-cover path possible at all: a
      // path over 26 cells alternates colours, so an unbalanced field is
      // impossible no matter how it is played. An earlier staggered layout
      // looked fine and had NO Hamiltonian path from any square.
      //
      // Only 6 of the 26 squares can start a complete burn, so where you
      // strike is as much of the puzzle as which way you turn the wind.
      garth: BurnGarth(
        starIndex: 1,
        coverageGoal: 26, // every dry square — see burn_field_test.dart
        // Up in the room, with the fountain and its vane standing below the
        // garden rather than in the middle of it.
        centre: Offset(410, 310),
        art: ['......', '.#..#.', '......', '.#..#.', '......'],
      ),
      windVane: Offset(410, 596),
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
    //
    // REWORK (§6.1): the bells stand where they always did, but the CENSER RUN
    // between them is now a choice — the short run out over the ash-storm nave
    // arcade, or the long way round the calm cloister walk. Both stands sit by
    // the vestry door; a Fire creature lights one to declare the run, and the
    // choice locks the moment the first censer takes flame. The authored
    // [incenseChains] nodes ARE the nave run (the route just names them).
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
          nodes: [Offset(160, 660), Offset(400, 655)],
          bellPosition: Offset(625, 590),
        ),
        IncenseChain(
          id: 'chain_mid',
          nodes: [Offset(180, 400), Offset(430, 380)],
          bellPosition: Offset(680, 335),
        ),
        IncenseChain(
          id: 'chain_high',
          nodes: [Offset(200, 150), Offset(460, 130)],
          bellPosition: Offset(755, 180),
        ),
      ],
      vesperRoutes: [
        // THE SHORT RUN — two censers per chain, wide gaps, and the ash-storm
        // nave takes the flame's breath (it starves faster) and comes up
        // angry at every ignition.
        VesperRoute(
          id: 'route_nave',
          name: 'NAVE',
          standPosition: Offset(105, 250),
          chainNodes: {},
          // ~1.4s per feeding. One gust never clears a nave gap, so the flame
          // must SURVIVE the walk to the next gust — dawdle and it gutters
          // back to a censer two hundred pixels behind you. Speed pays here.
          flameLifeScale: 0.55,
          igniteWisps: 3,
          unstableWisps: true,
        ),
        // THE LONG RUN — two extra censers per chain to keep alight, but every
        // gap is one comfortable gust and the cloister air stays still.
        VesperRoute(
          id: 'route_cloister',
          name: 'CLOISTER',
          standPosition: Offset(105, 510),
          chainNodes: {
            'chain_low': [
              Offset(160, 660),
              Offset(280, 710),
              Offset(400, 715),
              Offset(520, 660),
            ],
            'chain_mid': [
              Offset(180, 400),
              Offset(300, 450),
              Offset(430, 450),
              Offset(560, 390),
            ],
            'chain_high': [
              Offset(200, 150),
              Offset(330, 90),
              Offset(460, 85),
              Offset(600, 130),
            ],
          },
          // Full 2.6s per feeding — and every cloister gap is short enough
          // that ONE gust carries the flame clean onto the next censer, so it
          // never has to survive a wait at all. The cost is the walking.
          flameLifeScale: 1.0,
          igniteWisps: 2,
          unstableWisps: false,
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
/// each reachable only at one tide stand. Star 2 (Current) — the gallery's
/// CANAL NETWORK: set the moon-lantern in the spring mouth and float it out
/// to the sea drain, steering it by playing the tide (each groove's SILL says
/// which stands it runs at) and by plugging a basin with Ice. Star 3 (Deep) —
/// beyond the sealed mirror gate: at MID tide,
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
      earnAnnouncement: 'The Tide Star is yours — the sluices remember the sea',
    ),
    DungeonStarSpec(
      name: 'Current Star',
      earnAnnouncement:
          'The Current Star is yours — the moon-lantern rides out to sea',
    ),
    DungeonStarSpec(name: 'Deep Star'),
  ],
  entranceRevealDoor: DungeonDoorRef('tide_gate', 'drowned_court'),
  finaleDoor: DungeonDoorRef('drowned_court', 'moon_hall'),
  riteAnnouncement: 'Tide and Current flow in accord — the mirror gate parts',
  finaleSealedHint:
      'The mirror gate is sealed — it parts only for both the Tide and '
      'Current stars',
  guardianSealedHint:
      'The deep gate will not open — the dark below sleeps until the true '
      'moon-pools lie frozen',
  mercyShrineRoomId: 'moon_well',
  // Ideal: Waterpip · Spiritmask · Icemane — hinted by VERB, never by body
  // part: small access, second sight, the road-paving passage.
  riddle: [
    'Send me a Water Pip: my pipes open only to what is small enough;',
    'Spirit, to go where my drowned currents run;',
    'and Ice, for my moon waits on a cold that will hold.',
  ],
  primer: [
    'One tide runs the whole temple, at three stands.',
    'A door only answers a tide that has settled.',
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
          targetSpawn: Offset(110, 424),
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
      // THE SLUICE-BANK. Three wheels on the east wall, beside the gallery
      // door — you come off the canal and they are right there. Placed clear
      // of every HUD panel at this room's camera clamps (the court is 700 deep
      // against a 915 screen, so it never pans vertically and its corners have
      // to be authored clear; see `dungeon_hud_occlusion_test.dart`).
      tideValves: [
        TideValve(position: Offset(845, 120), level: 0),
        TideValve(position: Offset(845, 210), level: 1),
        TideValve(position: Offset(845, 300), level: 2),
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

    // Room D — the Lantern Gallery. Star 2 (the moon-lantern rework, docs
    // §6.4): the room is one CANAL NETWORK, cut in stone and wholly public —
    // ten directed grooves between a spring mouth, five basins and the sea
    // drain, each groove wearing its SILL on its lip. NOTHING here is hidden:
    // the topology, the fall-direction chevrons and the sill notches are all
    // carved, and the only thing Spirit's reading buys is foresight (which
    // grooves are DEEP cuts, and where the water would take the lantern next).
    //
    // THE SILL RULE (one function, `canalChannelLive`, shared by the drift,
    // the render and the proof): a groove runs when the water tops its sill —
    // low at every stand, mid from the middle water up, crest only at the
    // high water — while a DEEP cut runs at low and middle and drowns into a
    // swallowing torrent at high. THE SPILL RULE (`canalSpillFrom`): a basin
    // pours down the LOWEST live groove leaving it, so the tide alone decides
    // most forks; Ice plugging a basin removes it as a destination and forces
    // the next-lowest.
    //
    // The authored network is proved by `solveLanternDrift` (layout test):
    // reachable, `strandable == 0`, NO single stand runs it alone (every road
    // to the sea crosses one crest AND one deep cut, so the tide must be
    // PLAYED), and no dam-free play reaches the sea (the temple's natural fall
    // ends in the blind sump, which is the puzzle's whole thesis).
    'ghost_gallery': DungeonRoom(
      id: 'ghost_gallery',
      // PADDED FOR THE HUD (2026-08-31). Two panels were sitting on this room.
      //
      // The minimap (top-left) covered the SPRING — the one basin that always
      // answers a hand, and the reason a lost lantern can never end a run — so
      // everything in the gallery is inset by (96, 64).
      //
      // The action pad (bottom-right, 230 tall) covered the SEA DRAIN, which is
      // the goal of the whole canal. Insetting could not fix that one: at 784
      // the room was SHORTER than the viewport, so it never panned vertically
      // and the drain's screen position was fixed under the button. The gallery
      // is 1000 deep now — past the viewport, so it pans — and the extra is the
      // lower gallery below the drain. The camera can be pulled off the floor.
      bounds: Rect.fromLTWH(0, 0, 1096, 1000),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 379, 24, 90),
          targetRoomId: 'drowned_court',
          targetSpawn: Offset(880, 350),
        ),
        // The pearl vault's passage drowns above low tide.
        DungeonDoor(
          rect: Rect.fromLTWH(1072, 379, 24, 90),
          targetRoomId: 'pearl_vault',
          targetSpawn: Offset(110, 280),
        ),
      ],
      tideDoorRules: [
        TideDoorRule(targetRoomId: 'pearl_vault', tides: {0}),
      ],
      // THE SLUICE-BANK MOVED OUT (2026-08-31). The gallery used to keep its
      // own wheels on the west wall so that steering the water was a walk you
      // took inside the room, against the lantern's drift. They live in the
      // drowned court now, one door west.
      //
      // KNOW WHAT THIS CHANGED: the lantern only drifts while you are in this
      // room (see `_updateLantern`'s guard — the temple holds its breath
      // behind you), so a walk to the court FREEZES it. The canal is a pure
      // planning puzzle now: set the stand, come back, watch a leg, go again.
      // Nothing about it can be lost to a clock any more, and nothing about it
      // costs a clock either.
      canalNodes: [
        // The spring: a carved lion-mouth high in the north-west wall. It is
        // the one basin that always answers a hand, so a lost lantern can
        // never end a run (§ no-softlock, structural).
        CanalNode(id: 'spring', position: Offset(196, 174), isSpring: true),
        CanalNode(id: 'north_lock', position: Offset(426, 229)),
        CanalNode(id: 'east_shelf', position: Offset(896, 274)),
        CanalNode(id: 'heart_basin', position: Offset(641, 394)),
        // The blind sump: a throatless basin — no groove leaves it, and the
        // temple's natural fall runs straight into it. Visibly a dead end.
        CanalNode(id: 'blind_sump', position: Offset(311, 559)),
        CanalNode(id: 'south_race', position: Offset(696, 604)),
        // The sea drain, low in the south-east corner: the lantern reaching
        // it banks the Current Star.
        CanalNode(id: 'sea', position: Offset(981, 709), isSea: true),
      ],
      canalChannels: [
        CanalChannel('spring', 'north_lock', CanalSill.low),
        CanalChannel('north_lock', 'heart_basin', CanalSill.deep),
        CanalChannel('north_lock', 'blind_sump', CanalSill.mid),
        CanalChannel('north_lock', 'east_shelf', CanalSill.crest),
        CanalChannel('east_shelf', 'heart_basin', CanalSill.mid),
        CanalChannel('east_shelf', 'south_race', CanalSill.deep),
        CanalChannel('heart_basin', 'blind_sump', CanalSill.low),
        CanalChannel('heart_basin', 'south_race', CanalSill.deep),
        CanalChannel('south_race', 'blind_sump', CanalSill.mid),
        CanalChannel('south_race', 'sea', CanalSill.crest),
      ],
      tideZones: [
        // The gallery's own flooded middle: from the middle water up it is
        // swum, so a high stand is not free — it slows every walk to a valve.
        TideZone(rect: Rect.fromLTWH(396, 354, 420, 210), floodedAt: 1),
      ],
      canalStarIndex: 1,
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
          targetSpawn: Offset(1010, 424),
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
        MoonPool(id: 'pool_nw', position: Offset(250, 230)),
        MoonPool(id: 'pool_ne', position: Offset(650, 230)),
        MoonPool(id: 'pool_sw', position: Offset(250, 530)),
        MoonPool(id: 'pool_se', position: Offset(650, 530)),
      ],
      // THE MOON DIAL — Spirit's station, under the oculus. One press wanes
      // the moon a notch; the sky waxes it back on its own, forever.
      moonDial: Offset(450, 470),
      // THE SPOUT — a broken main in the south wall, running the whole time.
      // While it runs the well stands one water ABOVE what the moon calls
      // for, so no basin can ever agree with the sky. A Water PIP is the only
      // thing that fits the mouth, and it plugs it by STANDING there: the pip
      // is not pressing a button, it is holding a place, and it cannot leave
      // while the other two work the moon.
      tideValves: [TideValve(position: Offset(450, 630), pipOnly: true)],
      tideZones: [
        TideZone(rect: Rect.fromLTWH(330, 270, 240, 200), floodedAt: 1),
      ],
    ),

    // Room I — Leviathan Depths. The drowned arena above the well — and the
    // one room where the tide is NOT yours (§7 guardian retrofit): Leviathan
    // hauls the water a stand on every roar, so the fight is played across
    // all three stands. The terrain answers the same tide system every other
    // chamber does — a central sink that becomes swimmable, and two broken
    // pier stubs that are cover until the high water swallows them.
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
      tideZones: [
        // The arena's sink: bare stone at low water, swum from mid up.
        TideZone(rect: Rect.fromLTWH(250, 180, 320, 250), floodedAt: 1),
        // Broken piers: solid cover at low and mid, drowned at high.
        TideZone(
          rect: Rect.fromLTWH(110, 470, 170, 56),
          floodedAt: 2,
          ledge: true,
        ),
        TideZone(
          rect: Rect.fromLTWH(600, 130, 160, 56),
          floodedAt: 2,
          ledge: true,
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
  guardianSealedHint:
      'The heart-way is barred — the bones lie still until the great scale '
      'hangs true',
  mercyShrineRoomId: 'eye_chamber',
  // Ideal: Earthhorn · Lightningpip · Crystalmask — hinted by VERB, never by
  // body part: the mighty shove, small access, insight.
  riddle: [
    'Send me a Earth Horn: my bones grind aside for nothing less;',
    'Lightning, to wake the sockets buried in my veins;',
    'and Crystal, for my eye confides in nothing duller.',
  ],
  primer: [
    'The map is a body, and the bones are the machinery.',
    'What a room asks is answered somewhere else in the giant.',
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
        // FIVE STONES, laid in an arc along the chamber floor. The fifth —
        // the SPINE — is the giant's own centre, and its mark is carved in
        // the sternum court, so the treasure hunt now reaches the hub the
        // player crosses on every trip instead of only the four side rooms.
        // Five also breaks the even split: four stones could sit 2/2 and read
        // as symmetrical, and a balance that looks balanced by default is a
        // worse question than one that plainly is not.
        weights: [
          ScaleWeight(
            id: 'w_skull',
            position: Offset(240, 578),
            truePanRight: true,
          ),
          ScaleWeight(
            id: 'w_root',
            position: Offset(345, 616),
            truePanRight: false,
          ),
          ScaleWeight(
            id: 'w_spine',
            position: Offset(450, 632),
            truePanRight: true,
          ),
          ScaleWeight(
            id: 'w_geode',
            position: Offset(555, 616),
            truePanRight: true,
          ),
          ScaleWeight(
            id: 'w_seed',
            position: Offset(660, 578),
            truePanRight: false,
          ),
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
      // EVERY BREAKER STANDS IN FRONT OF THE DOOR IT FEEDS. They were
      // clustered in a blob around the rotor, so which breaker woke which
      // wing had to be traced along a wire or memorised. Now the geography IS
      // the mapping: walk to the door you want and throw the switch beside it.
      breakerPosition: Offset(225, 118),
      roomIds: ['pylon_hall'],
      freezeLitStarIndex: 0,
    ),
    DynamoTrunk(
      id: 'trunk_cloud',
      name: 'CLOUD TRUNK',
      // This one feeds two rooms — the east door and the south door — so it
      // stands between them rather than at either.
      breakerPosition: Offset(790, 520),
      roomIds: ['cloud_works', 'mirror_gallery'],
      freezeLitStarIndex: 1,
    ),
    DynamoTrunk(
      id: 'trunk_vault',
      name: 'VAULT TRUNK',
      breakerPosition: Offset(815, 118),
      roomIds: ['capacitor_vault'],
    ),
    DynamoTrunk(
      id: 'trunk_core',
      name: 'CORE TRUNK',
      breakerPosition: Offset(480, 118),
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
  guardianSealedHint:
      'The core hatch is dead iron — nothing uncoils in there until the '
      'beam runs latched',
  mercyShrineRoomId: 'storm_core',
  // Ideal: Lightninghorn · Airwing · Firepip — hinted by VERB, never body part:
  // the mighty charge/hold, flight, small access + heat.
  riddle: [
    'Send me Lightning: my dead iron wakes to nothing weaker;',
    'Air, to herd my high storm-cells down to the iron;',
    'and Fire, to weld wind to flame where my iron runs thin.',
  ],
  primer: [
    'Power is zero-sum: feeding one trunk darkens the others.',
    'What you do in the dark is half the dungeon.',
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
          targetSpawn: Offset(380, 86),
        ),
        // FAR RIGHT of the north wall. It used to sit at x 700-810 with the
        // finale's breaker gate at 610-690 — ten pixels apart, a treasury and
        // a locked endgame door reading as one doorway.
        DungeonDoor(
          rect: Rect.fromLTWH(760, 0, 110, 24),
          targetRoomId: 'capacitor_vault',
          targetSpawn: Offset(320, 480),
        ),
        // THE BREAKER GATE, dead centre of the north wall and directly above
        // the dynamo — dead until the Circuit and Storm stars bank. Centre is
        // where a finale belongs, and it puts 145px of wall between it and
        // the pylon door and 225px between it and the vault.
        DungeonDoor(
          rect: Rect.fromLTWH(425, 0, 110, 24),
          targetRoomId: 'overload_maze',
          targetSpawn: Offset(480, 280),
        ),
      ],
    ),

    // Room C — Pylon Hall. Star 1 (§9.2): THE BRAID, TAUGHT SMALL. The hall
    // is live only while the PYLON TRUNK is fed, and the mast at the west end
    // drinks lightning alone — which nothing in the room emits.
    //  • AIR stationed on a vent opens a wind (three vents; only one ever
    //    meets iron).
    //  • FIRE stationed in that wind turns it to lightning AT THE FLAME
    //    (three converters) — so where Fire stands decides how much of the
    //    run is charged.
    //  • LIGHTNING turns the four heavy conductors ('/' or '\'); only the
    //    storm's own can move them.
    // Solver-proven unique — 9 pairings × 16 conductor sets, one answer:
    //   VA(150,150) → pa'\'(880,150) ↓ through FA(880,340) → pb'/'(880,560)
    //   → pc'\'(400,560) ↑ → pd'\'(400,250) → MAST(200,250).
    // THE TEACHING LIE: vent VB(150,470) and converter FC(250,470) lie in a
    // line together, so the tempting pair really does catch — the flame
    // lights, a real bolt is born, and it dies in the east wall. Making
    // lightning is not the puzzle; landing it is.
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
      // An open hall: border iron and one cast pillar the bolt cannot cross.
      walls: [
        Rect.fromLTWH(0, 0, 24, 720),
        Rect.fromLTWH(1016, 0, 24, 720),
        Rect.fromLTWH(0, 0, 1040, 24),
        // The south sill is CUT for the doorway. Border iron laid straight
        // across a door seals it: the walk clamps to 16px of the bounds and
        // stands 16px off any wall, so a door lying inside the sill has no
        // reachable point at all and reads to the player as a wall.
        Rect.fromLTWH(0, 696, 445, 24),
        Rect.fromLTWH(555, 696, 485, 24),
        Rect.fromLTWH(560, 300, 120, 140), // the pillar
      ],
      beamEmitters: [
        // VA: the viable vent — the only one whose wind ever meets iron.
        BeamEmitter(position: Offset(150, 150), dir: Offset(1, 0)),
        // VB: runs the open floor and dies in the east wall.
        BeamEmitter(position: Offset(150, 470), dir: Offset(1, 0)),
        // VC: straight up into the ceiling, past nothing at all.
        BeamEmitter(position: Offset(700, 650), dir: Offset(0, -1)),
      ],
      beamConverters: [
        Offset(880, 340), // FA: on the viable route's first fall
        Offset(700, 300), // FB: off every route
        // FC: the teaching lie — dead in VB's path, so the flame really does
        // catch and the bolt really is born… and then dies in the wall.
        Offset(250, 470),
      ],
      beamMirrors: [
        BeamMirror(id: 'pa', position: Offset(880, 150)), // right→down
        BeamMirror(id: 'pb', position: Offset(880, 560)), // down→left
        BeamMirror(id: 'pc', position: Offset(400, 560)), // left→up
        BeamMirror(id: 'pd', position: Offset(400, 250)), // up→left
      ],
      beamReceiver: Offset(200, 250), // the hall's terminal mast
      // FULMINATE IS HALF-BLIND, and this hall is where you learn it: vat A
      // sits ON the true route's WIND leg, so the correct answer runs wind
      // straight over fulminate and nothing happens. Sixteen of the wrong
      // charged routes cook each of the two.
      fulminateVats: [
        FulminateVat(id: 'vat_a', position: Offset(720, 160)),
        FulminateVat(id: 'vat_b', position: Offset(960, 480)),
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
          targetSpawn: Offset(815, 96),
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
          targetSpawn: Offset(380, 534),
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

    // Room F — The Mirror Gallery (§9.3 rework). The FINDING half of Star 2:
    // three storm-cell echoes hide here; the works below is where they are
    // spent.
    //
    // WHAT THIS REPLACES: the echoes used to be found by walking within 40px
    // of one, or by standing near the middle and using Lightning, which bared
    // everything inside 220px. There was nothing to reason about and nothing
    // that could be got wrong — you swept the floor and the room paid out.
    //
    // THE ROOM ONLY WORKS IN THE DARK. It shares the CLOUD trunk with the
    // works, so feeding that trunk lights it — and its own light drowns what
    // the glass carries. Feed any OTHER wing and the gallery goes dark, and
    // that wing's light reaches it through one pane of storm-glass, showing
    // the one echo that belongs to it. Every echo therefore costs you the wing
    // you were standing in, which is this planet's zero-sum made personal —
    // and dark segments prowl with spark-wisps, so gathering is never free.
    //
    // AND THE GLASS LIES ABOUT THE SIDE. What stands in the pane is the
    // echo's REFLECTION; the echo waits the same distance the other way.
    // Lightning bares it at the TRUE spot, never at the reflection.
    //
    //   Spark ← trunk_pylon · pane x=190 · shows (270,220), waits (110,220)
    //   Veil  ← trunk_vault · pane x=570 · shows (490,220), waits (650,220)
    //   Anvil ← trunk_core  · pane y=440 · shows (240,360), waits (240,520)
    //
    // (The Anvil echo is the one the works wants heated by Fire — so the
    // spire's own light hands you the cell that needs a flame.)
    'mirror_gallery': DungeonRoom(
      id: 'mirror_gallery',
      bounds: Rect.fromLTWH(0, 0, 760, 620),
      // THE GALLERY'S DOORS WERE ON THE WRONG WALLS — exactly swapped, and
      // this is what made the wing read as a loop. The hub lies NORTH of this
      // room (you leave the court through its south door to get here), so the
      // way back is UP; cloud_works lies SOUTH (its north door opens into
      // here), so that way is DOWN. The gallery had them the other way round:
      // you walked south out of the hub, and the door at the top of the room
      // you arrived in took you somewhere else entirely, while the way home
      // sat at the bottom — further from the hub, not nearer it.
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(325, 0, 110, 24),
          targetRoomId: 'dynamo_court',
          targetSpawn: Offset(485, 634),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(325, 596, 110, 24),
          targetRoomId: 'cloud_works',
          targetSpawn: Offset(490, 86),
        ),
      ],
      // The three panes stand as solid glass in iron frames.
      walls: [
        Rect.fromLTWH(184, 145, 12, 150),
        Rect.fromLTWH(564, 145, 12, 150),
        Rect.fromLTWH(140, 434, 200, 12),
      ],
      stormCells: [
        StormCell(
          id: 'cell_spark',
          cellType: 'Spark',
          position: Offset(110, 220),
          pane: Offset(190, 220),
          showsUnderTrunk: 'trunk_pylon',
        ),
        StormCell(
          id: 'cell_veil',
          cellType: 'Veil',
          position: Offset(650, 220),
          pane: Offset(570, 220),
          showsUnderTrunk: 'trunk_vault',
        ),
        StormCell(
          id: 'cell_anvil',
          cellType: 'Anvil',
          position: Offset(240, 520),
          pane: Offset(240, 440),
          paneVertical: false,
          paneSpan: 200,
          showsUnderTrunk: 'trunk_core',
        ),
      ],
    ),

    // Room G — The Storm Spire. Star 3, behind the breaker gate (§9.4).
    //
    // ONE CHAIN, ALL THREE MASTS, AT ONCE. A single bolt must lie on every
    // mast simultaneously — nothing banks between firings, so the room is one
    // answer and you are free to try as many routes as you like reaching it.
    // The last mast STANDS ON THE CORE GATE at (250,540): the bolt drives down
    // into it and the barrier below throws open, so the thing you power and
    // the thing it opens are one object.
    //
    // A SWITCHYARD LATTICE. Columns 250·480·710·940 and rows 170·370·540, with
    // iron allowed on the points AND the half-steps between them (365·595·825
    // across, 270·455 down). The answer is an inward SPIRAL:
    //
    //   VA(90,170) →─────────────────────────────→ A(940,170) '\' ↓
    //                    converts at FA(595,170)
    //   ↓ MAST(940,370) ↓ B(940,540) '/' ←──────────────────────
    //   ← MAST(710,540) ← C(480,540) '\' ↑
    //   ↑ D(480,370) '\' ← E(250,370) '/' ↓ MAST(250,540) ↓ THE GATE
    //
    // AND THE ROOM IS FULL OF CHAINS THAT ARE NOT IT. Three of the eight
    // conductors — F(825,370), G(825,270), H(710,270) — stand nowhere near the
    // true spiral. What they do is give the OTHER vents somewhere to go, so a
    // wrong start does not die in a wall after one bounce; it winds through
    // four, five, eight corners and comes out looking like an answer. Six
    // vents and five converters make thirty pairings, and FOURTEEN of them
    // light a mast. Four light TWO of the three:
    //
    //   VA+FA on a wrong conductor set …… two masts (the near-miss you make)
    //   VA+FC (940,455) ………………………………… two masts (converted too late)
    //   VD+FD, VD+FE ……………………………………… two masts, off an eight-corner chain
    //                                     that begins in a column with no
    //                                     conductor in it at all
    //
    // VD is the honest trap. Its column holds a real mast at (710,540) and a
    // converter above it, so the flame catches and the chain runs a long way
    // and lights things — it simply cannot light all three, because the mast
    // in its own column sits BELOW the converter and only ever sees wind.
    //
    // Solver-proven: thirty pairings × 256 conductor sets, and exactly ONE
    // ROUTE lights all three. (Eight sets satisfy, all tracing that same
    // route — the three decoy conductors are never touched by it, so their
    // orientation is genuinely free. Uniqueness here is of the ROUTE, which is
    // the thing the player actually finds; the layout test asserts it that
    // way rather than counting bitmasks.)
    //
    // THE REAL QUESTION IS HOW EARLY YOU CONVERT. Three converters sit ON the
    // true route at different depths — FA(595,170) early, FC(940,455) most of
    // the way down the east column, FB(365,370) near the end. Every one makes
    // a real bolt; only the earliest leaves enough of the route charged to
    // reach all three, because everything before the flame is merely wind.
    //
    // PLANNING IS FREE. With Air on a vent and nobody on a converter there is
    // no charged half, so the wind draws the whole chain and lights nothing.
    //
    // LANE DISCIPLINE. Cast blocks must never stand in a lane, or they eat a
    // decoy's wind before it leaves the vent and quietly turn a tempting lie
    // into a dead prop. That happened twice while building this room. The
    // three blocks live at x 540-650 and x 960-1070, clear of every column and
    // of the decoy chain's own run along row 270.
    //
    // (A welding rule and a banked-crowns structure both lived here and were
    // removed; docs §9.4 records what they were and why.)
    'overload_maze': DungeonRoom(
      id: 'overload_maze',
      bounds: Rect.fromLTWH(0, 0, 1120, 720),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(40, 40, 80, 24),
          targetRoomId: 'dynamo_court',
          targetSpawn: Offset(480, 86),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(210, 640, 90, 32),
          targetRoomId: 'storm_core',
          targetSpawn: Offset(110, 380),
        ),
      ],
      // Cast blocks in the gaps BETWEEN lanes — never in one.
      walls: [
        Rect.fromLTWH(0, 0, 24, 720),
        Rect.fromLTWH(1096, 0, 24, 720),
        Rect.fromLTWH(0, 0, 1120, 24),
        Rect.fromLTWH(0, 696, 1120, 24),
        Rect.fromLTWH(540, 230, 110, 100),
        Rect.fromLTWH(540, 420, 110, 90),
        Rect.fromLTWH(960, 440, 110, 120),
      ],
      // Six vents. Only one opens the spiral; the rest feed the decoy iron.
      beamEmitters: [
        BeamEmitter(position: Offset(90, 170), dir: Offset(1, 0)), // VA viable
        BeamEmitter(position: Offset(90, 370), dir: Offset(1, 0)), // VB
        BeamEmitter(position: Offset(480, 650), dir: Offset(0, -1)), // VC
        BeamEmitter(position: Offset(710, 650), dir: Offset(0, -1)), // VD trap
        BeamEmitter(position: Offset(1040, 370), dir: Offset(-1, 0)), // VE
        BeamEmitter(position: Offset(480, 90), dir: Offset(0, 1)), // VF
      ],
      beamConverters: [
        Offset(595, 170), // FA — early on the true run: the only one that works
        Offset(365, 370), // FB — on the route, far too late
        Offset(940, 455), // FC — on the route, still too late (lights two)
        Offset(710, 455), // FD — on VD's chain, above its own mast
        Offset(770, 270), // FE — on the decoy chain's westward run
      ],
      // Eight conductors: five carry the spiral, three exist to give the wrong
      // starts somewhere convincing to go.
      beamMirrors: [
        BeamMirror(id: 'A', position: Offset(940, 170)),
        BeamMirror(id: 'B', position: Offset(940, 540)),
        BeamMirror(id: 'C', position: Offset(480, 540)),
        BeamMirror(id: 'D', position: Offset(480, 370)),
        BeamMirror(id: 'E', position: Offset(250, 370)),
        BeamMirror(id: 'F', position: Offset(825, 370)), // decoy net
        BeamMirror(id: 'G', position: Offset(825, 270)), // decoy net
        BeamMirror(id: 'H', position: Offset(710, 270)), // decoy net
      ],
      beamReceivers: [
        Offset(940, 370), // on the east fall
        Offset(710, 540), // on the southern reach — and in VD's column
        Offset(250, 540), // ON THE GATE — the bolt drives down into it
      ],
      poweredBarriers: [
        PoweredBarrier(
          rect: Rect.fromLTWH(200, 600, 120, 22),
          nodeId: 'beam_core',
        ),
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
  guardianSealedHint:
      'The heart valve is clamped — the boiler holds its breath until the '
      'crucible pedestal sinks',
  mercyShrineRoomId: 'boiler_heart',
  // Ideal: Steampip · Firemask · Earthhorn — hinted by VERB, never body part:
  // a cooling breath, a kindling/melting heart, the wall-raising strength.
  riddle: [
    'Send me Steam: my cold breath sets the molten back to stone;',
    'Earth, to raise the walls that dam my flood;',
    'and Fire, to open the rock and let the fire-blood run.',
  ],
  primer: [
    'The main holds forty, and every junction you open costs fifteen.',
    'Cooling lava condenses back — the flood is also fuel.',
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
          // The near shore, low (you came up from the south manifold) — NOT
          // (385,665), which was on the far shore and is the star's own win
          // region, so arriving there banked Star 2 on the first tick.
          targetSpawn: Offset(200, 660),
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
      // STAR 1 — THE GEYSER FIELD (2026-08-14 rework; the tile-lava causeway
      // is retired, and with it the 10x12 dam grid this comment used to
      // describe). Room is 700x840. Five mouths ring the floor and a sixth
      // sits at the heart under a slab. One ring mouth is already choked with
      // rubble, so FOUR blow at the start — which is exactly a three-Alchemon
      // party plus the one rock an Earth hand can raise.
      //
      // Every cap sends its head to the mouths still open, so the field gets
      // angrier the closer you are to solving it: the last mouths blow hard
      // enough to throw a body off the stone, and only the rock is heavy
      // enough to sit on one at full pressure. So the rock has to be RAISED
      // AND PUSHED while the field is still calm — cap first and you can no
      // longer cross your own room to place it.
      geysers: [
        GeyserMouth(id: 'g_north', position: Offset(350, 170)),
        GeyserMouth(id: 'g_east', position: Offset(560, 420)),
        GeyserMouth(id: 'g_south', position: Offset(350, 670)),
        GeyserMouth(id: 'g_west', position: Offset(140, 420)),
        GeyserMouth(
          id: 'g_choked',
          position: Offset(560, 170),
          blockedAtStart: true,
        ),
      ],
      capstone: GeyserCapstone(position: Offset(350, 420), starIndex: 0),
    ),

    // Cinder Forge — the ring's EAST segment, and STAR 2 (its capstone banks
    // index 1): the pedestal sits in a bedrock sanctuary whose ONLY way in is
    // a meltable gate, and the field around it is strewn with sleeping
    // cisterns that all WAKE the moment Fire breaks rock. Wall a bunker
    // around the gate mouth FIRST, then melt, cool the spill, slip inside.
    'cinder_forge': DungeonRoom(
      id: 'cinder_forge',
      bounds: Rect.fromLTWH(0, 0, 700, 840),
      // THE CHASM RUNS NORTH-SOUTH, and both doors open on its WEST shore.
      //
      // It used to split the room top from bottom with a door on each side —
      // so walking in from the south manifold put the whole party down on the
      // FAR shore, which is the platform Star 2 is won by standing on, and the
      // star banked on the first tick without the chasm ever being crossed.
      //
      // Moving the one door was not enough, and the layout test said why: the
      // forge sits BETWEEN the two manifolds on the ring, so it is entered
      // from above and from below, and "travel lands on the matching side"
      // forces those two arrivals to opposite ends of the room. Any chasm
      // splitting it top/bottom therefore has a door on each side, whichever
      // shore holds the pedestal. Turn the chasm ninety degrees and both
      // arrivals sit on the same shore with their travel still reading true.
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(120, 816, 110, 24),
          targetRoomId: 'manifold_south',
          targetSpawn: Offset(915, 110),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(120, 0, 110, 24),
          targetRoomId: 'manifold_north',
          targetSpawn: Offset(915, 310),
        ),
      ],
      pressureSeals: [
        PressureSeal(targetRoomId: 'manifold_south', cost: 15),
        PressureSeal(targetRoomId: 'manifold_north', cost: 15),
      ],
      // STAR 2 — THE LAUNCH. Two mouths can be covered and one cannot, and
      // the one that cannot is how you get across. Cover BOTH — Earth's stone
      // on one, a body on the other — and the field is at full head; ride the
      // wide throat and it throws you clear. Cover one and it throws you into
      // the chasm, which is the room teaching you by letting you watch.
      //
      // WHO STAYS. Two caps and three Alchemons means exactly one body is
      // spent holding the field while the other two ride together, and the
      // stone frees nobody else — so the party SPLITS, and the far shore has
      // to be finished by whoever went. Steam is the one that stays (the
      // casting over there is Earth's and Fire's work), which is why the far
      // side asks for no cooling.
      //
      // A throw is 120 + 55 per mouth held. The riser stands at x=290 and the
      // far shore begins at x=490: full head (2) throws 230 and lands, one
      // mouth (1) throws 175 and falls 25px short into the void, none (0)
      // throws 120 and barely leaves the near shore.
      // THE WAY HOME IS THE THING YOU MADE. Nothing carries a body back across
      // the chasm — the riser is on the near shore — so the finished cast
      // runs out of the moat's foot and sets as a span between the two
      // shores. It is impassable until the star is banked, and it is the
      // room's own answer to "how do we get back", which a door would have
      // been too, but a duller one.
      //
      // Listed in the MIDDLE so `platforms.last` is still the far shore (the
      // greeting and the win region both read it).
      platforms: [
        Rect.fromLTWH(40, 0, 380, 840), // the near shore (both doors)
        Rect.fromLTWH(420, 690, 72, 62), // the cast span (after the star)
        Rect.fromLTWH(490, 40, 170, 760), // the far shore (the casting floor)
      ],
      castSpan: Rect.fromLTWH(420, 690, 72, 62),
      geysers: [
        GeyserMouth(id: 'r_hob_a', position: Offset(110, 200)),
        GeyserMouth(id: 'r_hob_b', position: Offset(110, 640)),
        // THE RISER. Too wide to smother; stand on it and it throws you.
        GeyserMouth(id: 'r_riser', position: Offset(290, 420), isRiser: true),
      ],
      // THE CASTING MOAT, on the far shore. One boulder lip at the head of a
      // channel that runs the length of the shore down to the pedestal at its
      // foot. Earth heaves a rock on; Fire melts it and the melt runs down —
      // further with every press, and creeping back whenever it is left
      // alone. A rock is worth about three presses, and the moat wants more
      // than one rock, so the two who came over have a rhythm to keep: Fire
      // works the melt, Earth feeds it.
      //
      // (It was three separate sockets to fill in any order — a row of
      // switches, and a sequence rather than a puzzle. This is the same two
      // elements doing the same braid, with a clock on it.)
      castingMoat: CastingMoat(
        boulderAt: Offset(575, 150),
        channel: Rect.fromLTWH(545, 190, 60, 450),
      ),
      capstone: GeyserCapstone(position: Offset(575, 690), starIndex: 1),
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
          targetSpawn: Offset(200, 180), // the near shore, high
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

    // The Crucible — the ring's CENTRE, and the rite (null star index):
    // THE POUR. A cold chamber that does not move until you commit to it.
    //
    // Two cisterns sit above the band and the mould waits at the bottom of a
    // fall. Earth's walls are the CHANNEL — built at leisure, with nothing
    // running — and Fire breaking a WET gate releases the melt behind it. It
    // then falls on its own: south while it can, sideways when it cannot, and
    // BOTH ways at once if both are open. It is worth a fixed number of cells
    // before it congeals, and that number is bought with the main.
    //
    // The trade, and it is the whole room:
    //   · LEFT gate, no thought ……… reaches the mould, 16 cells
    //   · RIGHT gate, no walls at all … 10 cells
    //   · LEFT gate, two walls ……… 8 cells
    // A run is 5 cells plus one per 6 of head, so a lean main forces you to
    // plan and a fat one lets you brute-force it. Ledges at rows 5 and 7 are
    // what make the left side need shaping.
    //
    // WHAT THIS REPLACES (twice): a quenching whose win condition was a
    // flood-fill the player could not see, and then a hold-the-needle act —
    // which was simply the wrong KIND of difficulty. Knowing the answer has
    // to be enough; see docs §9.5.
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
          'X..L.......LX',
          'XXX#XXX#XXX#X',
          'X...........X',
          'X..XX...XX..X',
          'X...........X',
          'X.XXX...XXX.X',
          'X.....P.....X',
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
  'Lava': kLavaLayout,
  'Poison': poisonLayout,
  'Ice': iceLayout,
  'Mud': mudLayout,
  'Dust': dustLayout,
  'Crystal': crystalLayout,
  'Plant': plantLayout,
  'Spirit': spiritLayout,
  'Dark': darkLayout,
  'Light': lightLayout,
  'Blood': bloodLayout,
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
/// Raid guardians, derived from the authored dungeon layouts.
///
/// This used to be a second hand-maintained map beside
/// [kPlanetDungeonLayouts], listing the same six mystics by name. Every
/// layout's guardian node already carries its mysticId, so the copy could
/// only ever drift: build a new dungeon, forget this map, and the planet is
/// enterable but silently unraidable. With eleven elements still to author
/// that is eleven chances to miss it.
///
/// Deriving it means a new dungeon brings its raid with it.
final Map<String, String> kRaidGuardianIds = {
  for (final entry in kPlanetDungeonLayouts.entries)
    if (_guardianMysticId(entry.value) != null)
      entry.key: _guardianMysticId(entry.value)!,
};

String? _guardianMysticId(DungeonLayout layout) {
  for (final room in layout.rooms.values) {
    final id = room.guardian?.encounter?.mysticId;
    if (id != null) return id;
  }
  return null;
}

/// Roc drags its storm-cell across a rod field; without rods the drag is a
/// no-op. A ring gives the bird somewhere to be led from any approach, which
/// the authored spire's staircase does not need to do.
List<StormRod> _raidStormRods(String element) {
  if (element != 'Air') return const [];
  const centre = Offset(700, 400);
  const radius = 300.0;
  return [
    for (var i = 0; i < 6; i++)
      StormRod(
        id: 'raid_rod_$i',
        position: Offset(
          centre.dx + radius * cos(i * pi / 3),
          centre.dy + radius * 0.62 * sin(i * pi / 3),
        ),
        // Staggered heights so the field can be ranked, same as the spire.
        initialHeight: i % 3,
      ),
  ];
}

/// Simurgh's telegraph IS the brazier order — it re-lights them as it strikes
/// and the sequence is the bullet pattern. Ordered around the ring so the
/// pattern sweeps rather than jumping across the arena.
List<RitualBrazier> _raidBraziers(String element) {
  if (element != 'Fire') return const [];
  const centre = Offset(700, 400);
  const radius = 320.0;
  return [
    for (var i = 0; i < 6; i++)
      RitualBrazier(
        order: i,
        position: Offset(
          centre.dx + radius * cos(i * pi / 3 - pi / 2),
          centre.dy + radius * 0.60 * sin(i * pi / 3 - pi / 2),
        ),
      ),
  ];
}

/// Leviathan hauls the tide a stand on every roar, and its lull only opens on
/// SETTLED water — so without tide zones the mechanic is inert and the fight
/// is a plain charge.
///
/// The bands leave a dry central corridor at every stand. A raid arena that
/// floods completely would be unplayable, and unlike the temple there are no
/// authored ledges to retreat to. Rising water squeezes the fight inward
/// instead of drowning it.
List<TideZone> _raidTideZones(String element) {
  if (element != 'Water') return const [];
  return const [
    // Mid tide takes the margins.
    TideZone(rect: Rect.fromLTWH(0, 0, 230, 900), floodedAt: 1),
    TideZone(rect: Rect.fromLTWH(1170, 0, 230, 900), floodedAt: 1),
    TideZone(rect: Rect.fromLTWH(230, 0, 940, 130), floodedAt: 1),
    // High tide closes in, leaving roughly 540x770 of standing room around
    // the guardian and the entrance.
    TideZone(rect: Rect.fromLTWH(230, 130, 200, 770), floodedAt: 2),
    TideZone(rect: Rect.fromLTWH(970, 130, 200, 770), floodedAt: 2),
  ];
}

/// A raid is one big open planet-themed arena — no rooms, no puzzles, just
/// the empowered guardian under the storm. Generated, not authored, so every
/// element in [kRaidGuardianIds] gets one for free.
DungeonLayout buildRaidArenaLayout(String element) {
  final mysticId = kRaidGuardianIds[element];
  assert(mysticId != null, 'No raid guardian configured for $element');
  final room = DungeonRoom(
    id: 'raid_arena',
    bounds: const Rect.fromLTWH(0, 0, 1400, 900),
    // The guardian's signature furniture. Each mystic's mechanic is gated on
    // the props its dungeon room carries, so a bare arena reduced every raid
    // to the same charging phantom. Generated per element, ringed around the
    // guardian at (700, 380) rather than laid out for a puzzle — nothing here
    // is solved, it is only what the mechanic reads.
    stormRods: _raidStormRods(element),
    braziers: _raidBraziers(element),
    tideZones: _raidTideZones(element),
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
