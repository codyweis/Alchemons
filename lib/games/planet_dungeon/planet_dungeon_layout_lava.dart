// lib/games/planet_dungeon/planet_dungeon_layout_lava.dart
//
// THE MOLTEN RELIQUARY — the Lava planet's authored line, its RULES as pure
// data + pure functions, and its DungeonLayout.
//
// docs/dungeons.md §5.5 claims for Lava: topology = "foundry line: one long
// production line the player re-routes"; strategic question = "limited molten
// pours — what do you cast, in what order"; vault trick = "cast a key whose
// mold is hidden elsewhere on the line". §6.2 is the spec this implements.
//
// THE FIVE RULES, and everything else falls out of them:
//   1. A CHANNEL IS NOT A FLOOR. Every trough on this planet idles hot; you
//      cannot walk on running metal. The map is cut by its own plumbing.
//   2. A POUR IS FINITE. The crucible holds [kLavaPourBudget] workable
//      charges for the whole run and never refills. Spending is the game.
//   3. WHAT A POUR BECOMES IS WHERE IT WENT. The north arm runs plain; the
//      south arm's drop-hammer STAMPS it (once the die is woken); the purge
//      vent GASSES it. A mold takes what the line hands it, or spoils.
//   4. COLD METAL IS A BRIDGE — AND A PLUG. Freezing a pour (the chill
//      house's shroud, or an Ice mane's own cold) lays a walkway across the
//      channel where it stands, and the same slug stops everything behind it.
//      That is where "in what order" comes from: the player authors the order
//      from this one physical fact, and is never handed a sequence (Fire owns
//      sequence-execution, §5.5 ledger — nothing here tells you an order).
//   5. THE POURS ARE IRREVERSIBLE; THE WORLD IS NOT. A Lava heart melts any
//      casting back out (plug or spoiled mold), so a misroute costs a POUR,
//      never the run.
//
// Kept out of the engine (like `burn_field.dart`) so the renderer, the verbs
// and the SOLVER all reason about one copy of the rules — and so the
// solvability proof in `test/planet_dungeon_lava_line_test.dart` can walk the
// real line headlessly.

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

// ── Tunables ────────────────────────────────────────────────

/// The crucible's whole charge for one run (§6.2 "a POUR is finite and
/// irreversible — the crucible holds only so many").
///
/// The tightest plan that banks Stars 1 and 2 spends FOUR (proved exhaustively
/// in the line test), so the budget carries exactly one spare: enough that a
/// single misroute is survivable, not enough to cast everything the foundry
/// offers. The Black Glass maxim wants three quenched pours all by itself —
/// which is the point: you cannot have the maxim and the works in one run.
const int kLavaPourBudget = 5;

/// Quenched pours needed for the Lost Maxim (§6 egg 8, "Black Glass").
const int kLavaBlackGlassQuenches = 3;

/// Seconds a pour takes to cross 100px of channel. Slow enough to run ahead of
/// and re-route (that IS the kinetic layer), fast enough not to be a wait.
const double kLavaPourSecondsPer100 = 0.62;

/// Lost-maxim + entry-rite discovery ids ('egg:'/'rune:' ride the persisted
/// cloud-discovery channel; the screen pays the maxim's 20 gold).
const String kLavaBlackGlassEggId = 'egg:lava_black_glass';
const String kLavaTapRuneId = 'rune:lava_tap';

/// Heraclitus, in the cooled spoil of three ruined keys.
const String kLavaBlackGlassMaxim =
    '"All things are an exchange for fire, and fire for all things."';

// ── The line, as a graph ────────────────────────────────────

/// What a node does to (or with) the pour that reaches it.
enum FoundryNodeKind {
  /// The crucible tap: where a pour is born.
  source,

  /// A points lever: the pour leaves by the exit the switch selects.
  junction,

  /// The chill house's shroud. Shroud DOWN freezes the pour in the channel it
  /// arrived by — a walkway across it, and a plug behind it. Shroud UP passes.
  chiller,

  /// The mill's drop-hammer: plain metal leaves it STAMPED (once woken).
  stamper,

  /// The purge vent: whatever passes leaves as firedamp. Nothing casts.
  vent,

  /// A mold cavity: the end of a spur. Takes the form it wants, or spoils.
  mold,

  /// The slag pit: the pour is gone.
  sink,

  /// Plain pass-through (a channel corner with a name).
  relay,
}

/// The state a pour is in as it travels.
enum PourForm {
  /// Straight from the crucible: fills a plain form (a span slab).
  plain,

  /// Warded by the mill's die: the only thing a key mold accepts.
  stamped,

  /// Gassed by the purge. Fills nothing.
  gassed,
}

/// What one beat of the line did — the renderer, the hint channel and the
/// solver all read this, so "where did my pour go" has exactly one answer.
enum PourEvent {
  /// Moved on down the line.
  travelling,

  /// Froze in the channel: a walkway here, a plug behind.
  froze,

  /// Filled a mold with what that mold wanted.
  cast,

  /// Reached a mold that refuses this form (or a mold already full): the
  /// casting is ruined and must be melted out before the mold can take again.
  spoiled,

  /// Ran into the slag pit, or congealed against a plug. Simply gone.
  lost,
}

/// One stretch of trough, drawn as axis-aligned rects (a channel may cross
/// several rooms; only the segments in the current room are drawn).
class FoundrySegment {
  const FoundrySegment(this.roomId, this.rect, {this.reverse = false});

  final String roomId;
  final Rect rect;

  /// False = the metal runs left→right / top→bottom along [rect]'s long axis.
  final bool reverse;

  bool get horizontal => rect.width >= rect.height;
  double get length => horizontal ? rect.width : rect.height;

  /// World position at [t] (0..1) along this segment.
  Offset pointAt(double t) {
    final u = reverse ? 1.0 - t : t;
    return horizontal
        ? Offset(rect.left + rect.width * u, rect.center.dy)
        : Offset(rect.center.dx, rect.top + rect.height * u);
  }
}

class FoundryChannel {
  const FoundryChannel({
    required this.id,
    required this.from,
    required this.to,
    required this.segments,
  });

  final String id;
  final String from;
  final String to;
  final List<FoundrySegment> segments;

  double get length {
    var total = 0.0;
    for (final s in segments) {
      total += s.length;
    }
    return total;
  }

  /// World position (and room) at [t] (0..1) along the whole channel.
  (String, Offset) pointAt(double t) {
    final want = length * t.clamp(0.0, 1.0);
    var walked = 0.0;
    for (final s in segments) {
      if (walked + s.length >= want || identical(s, segments.last)) {
        return (s.roomId, s.pointAt(((want - walked) / s.length).clamp(0, 1)));
      }
      walked += s.length;
    }
    return (segments.last.roomId, segments.last.pointAt(1));
  }
}

class FoundryNode {
  const FoundryNode({
    required this.id,
    required this.roomId,
    required this.position,
    required this.kind,
    this.exits = const [],
    this.switchId,
    this.switchLabels = const [],
    this.leverAt,
    this.leverAccess,
    this.wants,
    this.casts,
  });

  final String id;
  final String roomId;
  final Offset position;
  final FoundryNodeKind kind;

  /// Channel ids leaving this node, in switch order.
  final List<String> exits;

  /// Non-null when a lever selects between [exits] (or, for the chiller and
  /// the mill, arms the station itself).
  final String? switchId;

  /// One short all-caps word per setting, for the lever's own plate.
  final List<String> switchLabels;

  /// Where the lever stands (the switch is thrown from here, not from the
  /// channel — you never reach over running metal).
  final Offset? leverAt;

  /// A token the party must already hold to reach this lever at all (the
  /// catwalk's tail switch hangs over the north channel). Purely a MODEL of
  /// the geometry, so the solver reasons about the same map the player walks.
  final String? leverAccess;

  /// Molds only: the form this cavity accepts.
  final PourForm? wants;

  /// Molds only: the id of the thing cast here.
  final String? casts;
}

/// The authored line: nodes + channels, with lookups.
class FoundryLine {
  const FoundryLine({required this.nodes, required this.channels});

  final List<FoundryNode> nodes;
  final List<FoundryChannel> channels;

  FoundryNode node(String id) => nodes.firstWhere((n) => n.id == id);
  FoundryChannel channel(String id) => channels.firstWhere((c) => c.id == id);

  Iterable<FoundryNode> nodesIn(String roomId) =>
      nodes.where((n) => n.roomId == roomId);

  Iterable<FoundryChannel> channelsIn(String roomId) => channels.where(
    (c) => c.segments.any((s) => s.roomId == roomId),
  );

  /// Every lever on the line, in flow order.
  Iterable<FoundryNode> get levers =>
      nodes.where((n) => n.switchId != null && n.leverAt != null);
}

/// The live pour: where it is and what it has become.
class LivePour {
  LivePour({required this.channelId, required this.form});

  String channelId;
  PourForm form;

  /// 0..1 along [channelId].
  double t = 0;
}

/// A casting sitting in the world: a walkway, and (if it froze in a channel)
/// a plug. Melting it out is free — the POUR it cost is not.
class FoundryCasting {
  const FoundryCasting({
    required this.id,
    required this.roomId,
    required this.rect,
    required this.channelId,
    this.spoiled = false,
  });

  final String id;

  /// Where it lies (a room + the rect it makes walkable).
  final String roomId;
  final Rect rect;

  /// The channel it plugs ('' when it is a mold's casting, which plugs
  /// nothing — a full mold simply cannot take again).
  final String channelId;

  /// True when the mold took the wrong form: junk, and it must be melted out.
  final bool spoiled;
}

/// ONE run's foundry: the switches, what has been cast, what is plugged, and
/// the pour in flight. Everything Lava persists for a run lives here, so the
/// engine holds a single field and the tests can drive the real rules.
class FoundryState {
  FoundryState(this.line) {
    reset();
  }

  final FoundryLine line;

  /// Workable charges left in the crucible.
  int poursLeft = kLavaPourBudget;

  /// nodeId → selected setting.
  final Map<String, int> switches = {};

  /// Castings by id (plugs, spans, filled molds).
  final Map<String, FoundryCasting> castings = {};

  /// Mold id → what it holds ('span_a', 'gantry', 'reliquary'), spoiled molds
  /// included (see [FoundryCasting.spoiled]).
  final Map<String, String> molds = {};

  /// The key in hand, if any.
  String? carried;

  /// Doors whose ward has been turned (permanent).
  final Set<String> wardsTurned = {};

  /// The mill's die: dead until steam drives it, and then forever. An
  /// accumulator, once charged, does not un-charge — which is exactly why
  /// WHEN you wake it is a decision (plain metal is only plain until then).
  bool dieWoken = false;

  /// Black Glass: pours quenched at the font this run.
  int quenches = 0;

  /// True once the crucible has been woken (the entry rite).
  bool tapWoken = false;

  LivePour? pour;

  /// Every pour ever released this run (the readout counts against this).
  int poursSpent = 0;

  void reset() {
    poursLeft = kLavaPourBudget;
    switches
      ..clear()
      ..addAll(kLavaDefaultSwitches);
    castings.clear();
    molds.clear();
    carried = null;
    wardsTurned.clear();
    dieWoken = false;
    quenches = 0;
    tapWoken = false;
    pour = null;
    poursSpent = 0;
  }

  /// A deep copy — the solver walks thousands of hypothetical runs and must
  /// never share a casting map with the one it came from.
  FoundryState clone() {
    final c = FoundryState(line)
      ..poursLeft = poursLeft
      ..carried = carried
      ..dieWoken = dieWoken
      ..quenches = quenches
      ..tapWoken = tapWoken
      ..poursSpent = poursSpent;
    c.switches
      ..clear()
      ..addAll(switches);
    c.castings.addAll(castings);
    c.molds.addAll(molds);
    c.wardsTurned.addAll(wardsTurned);
    return c;
  }

  /// A canonical key for solver dedup: everything that can differ between two
  /// runs, and nothing that cannot (switch settings are free to change before
  /// any pour, so they are not part of the state).
  String get signature {
    final cast = castings.entries.map((e) => '${e.key}${e.value.spoiled ? '!' : ''}').toList()..sort();
    final m = molds.entries.map((e) => '${e.key}=${e.value}').toList()..sort();
    final w = wardsTurned.toList()..sort();
    return '$poursLeft|$dieWoken|${cast.join(',')}|${m.join(',')}|$carried|${w.join(',')}';
  }

  // ── Queries ───────────────────────────────────────────────

  /// Tokens the party has earned the run of: which sides of which channel it
  /// can stand on. The solver and the lever check read the same set.
  Set<String> get access => {
    // The catwalk hangs over the north channel: you reach it by walking the
    // chill house's own frozen span, or across the cast gantry.
    if (castings.containsKey('plug:ch_north') || wardsTurned.contains('gantry'))
      'catwalk',
    if (castings.containsKey('cast:span_a')) 'east_floor',
    if (castings.containsKey('plug:ch_sump')) 'sump',
  };

  bool canSet(String nodeId) {
    final n = line.node(nodeId);
    final need = n.leverAccess;
    return need == null || access.contains(need);
  }

  /// Advance a lever one setting (levers cycle; there is no wrong way to hold
  /// one). Returns false when the lever cannot be reached at all.
  bool cycleSwitch(String nodeId) {
    if (!canSet(nodeId)) return false;
    final n = line.node(nodeId);
    final count = n.kind == FoundryNodeKind.junction
        ? n.exits.length
        : n.switchLabels.length;
    switches[nodeId] = ((switches[nodeId] ?? 0) + 1) % count;
    return true;
  }

  int settingOf(String nodeId) => switches[nodeId] ?? 0;

  bool plugged(String channelId) =>
      castings.containsKey('plug:$channelId') &&
      !(castings['plug:$channelId']!.spoiled);

  /// Is [p] standing on something a casting made walkable?
  bool spanned(Offset p, String roomId) {
    for (final c in castings.values) {
      if (c.roomId != roomId) continue;
      if (c.rect.contains(p)) return true;
    }
    return false;
  }

  bool hasMold(String moldNodeId) => molds.containsKey(moldNodeId);

  bool moldHolds(String moldNodeId, String what) =>
      molds[moldNodeId] == what &&
      !(castings['cast:$what']?.spoiled ?? true) == true;

  /// A finished, un-spoiled casting of [what] exists.
  bool cast(String what) {
    final c = castings['cast:$what'];
    return c != null && !c.spoiled;
  }

  // ── Verbs ─────────────────────────────────────────────────

  /// Wake the crucible (the entry rite). Costs no charge — the tap is opened
  /// once, and after that it pours.
  void wakeTap() => tapWoken = true;

  /// Release a pour. Returns false when the crucible is empty or one is
  /// already running (one charge in the line at a time is what makes routing
  /// a decision rather than a spray).
  bool tap() {
    if (!tapWoken || pour != null || poursLeft <= 0) return false;
    poursLeft--;
    poursSpent++;
    final src = line.node('tap');
    pour = LivePour(channelId: src.exits.first, form: PourForm.plain);
    return true;
  }

  /// The pour reached the end of its channel: resolve the node it arrived at
  /// and set it on its way (or end it).
  PourEvent arrive() {
    final p = pour;
    if (p == null) return PourEvent.lost;
    final ch = line.channel(p.channelId);
    final at = line.node(ch.to);
    switch (at.kind) {
      case FoundryNodeKind.chiller:
        // Shroud down: it sets here — a walkway across this channel, and a
        // plug in the arm behind it (RULE 4).
        if (settingOf(at.id) == 1) {
          _freeze(p.channelId, 1.0, at.roomId, at.position);
          pour = null;
          return PourEvent.froze;
        }
        return _leaveBy(at, p, at.exits.first);
      case FoundryNodeKind.stamper:
        if (dieWoken && p.form == PourForm.plain) p.form = PourForm.stamped;
        return _leaveBy(at, p, at.exits.first);
      case FoundryNodeKind.vent:
        p.form = PourForm.gassed;
        return _leaveBy(at, p, at.exits.first);
      case FoundryNodeKind.relay:
      case FoundryNodeKind.source:
        return _leaveBy(at, p, at.exits.first);
      case FoundryNodeKind.junction:
        final pick = settingOf(at.id).clamp(0, at.exits.length - 1);
        return _leaveBy(at, p, at.exits[pick]);
      case FoundryNodeKind.sink:
        pour = null;
        return PourEvent.lost;
      case FoundryNodeKind.mold:
        final ok = at.wants == p.form && !molds.containsKey(at.id);
        final what = at.casts!;
        molds[at.id] = what;
        castings['cast:$what'] = FoundryCasting(
          id: 'cast:$what',
          roomId: at.roomId,
          rect: kLavaCastRects[what] ?? Rect.fromCircle(center: at.position, radius: 1),
          channelId: '',
          spoiled: !ok,
        );
        pour = null;
        return ok ? PourEvent.cast : PourEvent.spoiled;
    }
  }

  PourEvent _leaveBy(FoundryNode at, LivePour p, String channelId) {
    if (plugged(channelId)) {
      // It congeals against cold metal and is simply gone (RULE 4/5).
      pour = null;
      return PourEvent.lost;
    }
    p
      ..channelId = channelId
      ..t = 0;
    return PourEvent.travelling;
  }

  /// AN ICE MANE'S OWN COLD (the declared §4 hard gate): freeze the running
  /// pour where it stands. Same physics as the shroud — a road across, a plug
  /// behind — but anywhere on the line, which is what makes the sump
  /// crossable at all.
  bool freezeHere() {
    final p = pour;
    if (p == null) return false;
    final (roomId, at) = line.channel(p.channelId).pointAt(p.t);
    _freeze(p.channelId, p.t, roomId, at);
    pour = null;
    return true;
  }

  /// QUENCH THE FONT (the Black Glass rite): kill the running pour where it
  /// stands and count it. The metal still sets — a quench leaves the same cold
  /// plug any other freeze does, so three of them is three pours AND three
  /// castings to melt out.
  bool quench() {
    if (pour == null) return false;
    quenches++;
    freezeHere();
    return true;
  }

  void _freeze(String channelId, double t, String roomId, Offset at) {
    castings['plug:$channelId'] = FoundryCasting(
      id: 'plug:$channelId',
      roomId: roomId,
      rect: Rect.fromCenter(center: at, width: 96, height: 78),
      channelId: channelId,
    );
  }

  /// A LAVA HEART MELTS IT OUT (RULE 5): remove a casting — a plug from a
  /// channel, or the junk from a spoiled mold — so the world is never the
  /// thing that ends a run. Returns the id melted, or null.
  String? remelt(String castingId) {
    final c = castings.remove(castingId);
    if (c == null) return null;
    molds.removeWhere((_, what) => 'cast:$what' == castingId);
    return castingId;
  }

  /// Take a finished key out of its mold.
  bool takeKey(String moldNodeId) {
    final what = molds[moldNodeId];
    if (what == null || carried != null) return false;
    if (!cast(what)) return false;
    carried = what;
    molds.remove(moldNodeId);
    castings.remove('cast:$what');
    return true;
  }

  /// Turn a ward with the key in hand.
  bool turnWard(String wardId) {
    if (carried != wardId) return false;
    carried = null;
    wardsTurned.add(wardId);
    return true;
  }
}

// ── The authored line ───────────────────────────────────────
//
// Read it top to bottom and it is the map: crucible → yard fork → (north arm
// through the chill house · south arm through the mill and its purge) → the
// mold floor's sluice → span form / key form / the tail, and the tail runs
// back the length of the works to the sump under the tap, where the reliquary
// mold has been sitting all along (§5.5's vault trick: the key's mold is
// installed somewhere ELSE on the line).

const Map<String, int> kLavaDefaultSwitches = {
  // Left as the last shift left it: the plain arm, open, aimed at the span
  // form. A first, blind pour therefore casts the road across the runner and
  // teaches the whole line in one go.
  'y_yard': 0, // 0 = NORTH (plain) · 1 = SOUTH (the mill)
  'chiller': 0, // 0 = shroud UP · 1 = shroud DOWN
  'damper': 1, // 0 = SHUT · 1 = PURGE (the works died mid-purge)
  'y_sluice': 0, // 0 = SPAN · 1 = KEY · 2 = ON
  'y_return': 0, // 0 = SLAG · 1 = SUMP
};

/// What each casting makes walkable (mold castings only; frozen plugs size
/// themselves around wherever the metal stopped).
const Map<String, Rect> kLavaCastRects = {
  // The span form lies ACROSS the runner: the mold floor's only crossing.
  'span_a': Rect.fromLTWH(496, 678, 148, 44),
  // Keys are carried, not walked on.
  'gantry': Rect.fromLTWH(0, 0, 0, 0),
  'reliquary': Rect.fromLTWH(0, 0, 0, 0),
};

const FoundryLine kLavaLine = FoundryLine(
  nodes: [
    FoundryNode(
      id: 'tap',
      roomId: 'tap_head',
      position: Offset(170, 54),
      kind: FoundryNodeKind.source,
      exits: ['ch_tap'],
    ),
    FoundryNode(
      id: 'y_yard',
      roomId: 'switch_yard',
      position: Offset(600, 44),
      kind: FoundryNodeKind.junction,
      exits: ['ch_north', 'ch_mill_in'],
      switchId: 'y_yard',
      switchLabels: ['NORTH', 'SOUTH'],
      leverAt: Offset(600, 130),
    ),
    FoundryNode(
      id: 'chiller',
      roomId: 'chill_house',
      position: Offset(430, 347),
      kind: FoundryNodeKind.chiller,
      exits: ['ch_chill_out'],
      switchId: 'chiller',
      switchLabels: ['SHROUD UP', 'SHROUD DOWN'],
      leverAt: Offset(430, 430),
    ),
    FoundryNode(
      id: 'stamper',
      roomId: 'stamp_mill',
      position: Offset(300, 460),
      kind: FoundryNodeKind.stamper,
      exits: ['ch_mill_mid'],
    ),
    FoundryNode(
      id: 'damper',
      roomId: 'stamp_mill',
      position: Offset(620, 460),
      kind: FoundryNodeKind.junction,
      exits: ['ch_damper_clean', 'ch_vent_up'],
      switchId: 'damper',
      switchLabels: ['SHUT', 'PURGE'],
      leverAt: Offset(690, 400),
    ),
    FoundryNode(
      id: 'vent',
      roomId: 'stamp_mill',
      position: Offset(620, 354),
      kind: FoundryNodeKind.vent,
      exits: ['ch_vent_out'],
    ),
    FoundryNode(
      id: 'floor_in',
      roomId: 'mold_floor',
      position: Offset(550, 861),
      kind: FoundryNodeKind.relay,
      exits: ['ch_runner_a'],
    ),
    FoundryNode(
      id: 'y_sluice',
      roomId: 'mold_floor',
      position: Offset(550, 700),
      kind: FoundryNodeKind.junction,
      exits: ['ch_span_form', 'ch_key_form', 'ch_tail'],
      switchId: 'y_sluice',
      switchLabels: ['SPAN', 'KEY', 'ON'],
      leverAt: Offset(452, 730),
    ),
    FoundryNode(
      id: 'mold_span_a',
      roomId: 'mold_floor',
      position: Offset(660, 700),
      kind: FoundryNodeKind.mold,
      wants: PourForm.plain,
      casts: 'span_a',
    ),
    FoundryNode(
      id: 'mold_key',
      roomId: 'mold_floor',
      position: Offset(450, 640),
      kind: FoundryNodeKind.mold,
      wants: PourForm.stamped,
      casts: 'gantry',
    ),
    FoundryNode(
      id: 'y_return',
      roomId: 'chill_house',
      position: Offset(300, 150),
      kind: FoundryNodeKind.junction,
      exits: ['ch_slag', 'ch_return'],
      switchId: 'y_return',
      switchLabels: ['SLAG', 'SUMP'],
      leverAt: Offset(300, 220),
      leverAccess: 'catwalk',
    ),
    FoundryNode(
      id: 'slag_pit',
      roomId: 'chill_house',
      position: Offset(300, 60),
      kind: FoundryNodeKind.sink,
    ),
    FoundryNode(
      id: 'sump_mouth',
      roomId: 'tap_head',
      position: Offset(890, 444),
      kind: FoundryNodeKind.relay,
      exits: ['ch_sump'],
    ),
    // THE HIDDEN MOLD (§5.5 vault trick): installed at the far end of the
    // works, under the tap the player walks past on their way in.
    FoundryNode(
      id: 'mold_reliquary',
      roomId: 'tap_head',
      position: Offset(130, 520),
      kind: FoundryNodeKind.mold,
      wants: PourForm.stamped,
      casts: 'reliquary',
    ),
  ],
  channels: [
    FoundryChannel(
      id: 'ch_tap',
      from: 'tap',
      to: 'y_yard',
      segments: [
        FoundrySegment('tap_head', Rect.fromLTWH(190, 40, 710, 28)),
        FoundrySegment('switch_yard', Rect.fromLTWH(0, 30, 600, 28)),
      ],
    ),
    FoundryChannel(
      id: 'ch_north',
      from: 'y_yard',
      to: 'chiller',
      segments: [
        FoundrySegment('switch_yard', Rect.fromLTWH(586, 0, 28, 44),
            reverse: true),
        FoundrySegment('chill_house', Rect.fromLTWH(0, 330, 430, 34)),
      ],
    ),
    FoundryChannel(
      id: 'ch_chill_out',
      from: 'chiller',
      to: 'floor_in',
      segments: [
        FoundrySegment('chill_house', Rect.fromLTWH(430, 330, 430, 34)),
        FoundrySegment('mold_floor', Rect.fromLTWH(0, 846, 550, 30)),
      ],
    ),
    FoundryChannel(
      id: 'ch_mill_in',
      from: 'y_yard',
      to: 'stamper',
      segments: [
        FoundrySegment('switch_yard', Rect.fromLTWH(600, 30, 160, 28)),
        FoundrySegment('stamp_mill', Rect.fromLTWH(0, 446, 300, 28)),
      ],
    ),
    FoundryChannel(
      id: 'ch_mill_mid',
      from: 'stamper',
      to: 'damper',
      segments: [
        FoundrySegment('stamp_mill', Rect.fromLTWH(300, 446, 320, 28)),
      ],
    ),
    FoundryChannel(
      id: 'ch_damper_clean',
      from: 'damper',
      to: 'floor_in',
      segments: [
        FoundrySegment('stamp_mill', Rect.fromLTWH(620, 446, 320, 28)),
        FoundrySegment('mold_floor', Rect.fromLTWH(0, 846, 550, 30)),
      ],
    ),
    FoundryChannel(
      id: 'ch_vent_up',
      from: 'damper',
      to: 'vent',
      segments: [
        FoundrySegment('stamp_mill', Rect.fromLTWH(606, 340, 28, 106),
            reverse: true),
      ],
    ),
    FoundryChannel(
      id: 'ch_vent_out',
      from: 'vent',
      to: 'floor_in',
      segments: [
        FoundrySegment('stamp_mill', Rect.fromLTWH(620, 340, 320, 28)),
        FoundrySegment('mold_floor', Rect.fromLTWH(0, 846, 550, 30)),
      ],
    ),
    FoundryChannel(
      id: 'ch_runner_a',
      from: 'floor_in',
      to: 'y_sluice',
      segments: [
        FoundrySegment('mold_floor', Rect.fromLTWH(520, 714, 60, 147),
            reverse: true),
      ],
    ),
    FoundryChannel(
      id: 'ch_span_form',
      from: 'y_sluice',
      to: 'mold_span_a',
      segments: [
        FoundrySegment('mold_floor', Rect.fromLTWH(520, 686, 140, 28)),
      ],
    ),
    FoundryChannel(
      id: 'ch_key_form',
      from: 'y_sluice',
      to: 'mold_key',
      segments: [
        FoundrySegment('mold_floor', Rect.fromLTWH(450, 626, 100, 28),
            reverse: true),
      ],
    ),
    FoundryChannel(
      id: 'ch_tail',
      from: 'y_sluice',
      to: 'y_return',
      segments: [
        FoundrySegment('mold_floor', Rect.fromLTWH(520, 0, 60, 686),
            reverse: true),
        FoundrySegment('chill_house', Rect.fromLTWH(300, 136, 560, 28),
            reverse: true),
      ],
    ),
    FoundryChannel(
      id: 'ch_slag',
      from: 'y_return',
      to: 'slag_pit',
      segments: [
        FoundrySegment('chill_house', Rect.fromLTWH(286, 60, 28, 90),
            reverse: true),
      ],
    ),
    FoundryChannel(
      id: 'ch_return',
      from: 'y_return',
      to: 'sump_mouth',
      segments: [
        FoundrySegment('chill_house', Rect.fromLTWH(0, 136, 300, 28),
            reverse: true),
      ],
    ),
    FoundryChannel(
      id: 'ch_sump',
      from: 'sump_mouth',
      to: 'mold_reliquary',
      segments: [
        FoundrySegment('tap_head', Rect.fromLTWH(0, 430, 900, 28),
            reverse: true),
        FoundrySegment('tap_head', Rect.fromLTWH(102, 458, 56, 34)),
      ],
    ),
  ],
);

/// RULE 1, in ONE place so the engine's collision, the renderer and the
/// reachability proof can never drift: is [p] standing on running metal?
bool foundryBlocks(FoundryState s, String roomId, Offset p) {
  for (final ch in s.line.channelsIn(roomId)) {
    for (final seg in ch.segments) {
      if (seg.roomId != roomId) continue;
      if (!seg.rect.contains(p)) continue;
      return !s.spanned(p, roomId);
    }
  }
  return false;
}

// ── The plan solver (used by the layout test to PROVE the budget) ──

/// One programmed pour: every setting the line is left in before the tap is
/// thrown, plus whether an Ice mane freezes it on the way.
class FoundryPlan {
  const FoundryPlan(this.settings, {this.freezeOn, this.wakeDieFirst = false});

  /// switchId → setting.
  final Map<String, int> settings;

  /// Channel id to freeze the pour in as it passes (an Ice mane's cold), or
  /// null to let it run to its end.
  final String? freezeOn;

  /// Wake the mill's die before releasing this pour (irreversible).
  final bool wakeDieFirst;
}

/// Run [plan] against [s]. Returns the event the pour ended on.
PourEvent runFoundryPlan(FoundryState s, FoundryPlan plan) {
  if (plan.wakeDieFirst) s.dieWoken = true;
  plan.settings.forEach((k, v) {
    if (s.canSet(k)) s.switches[k] = v;
  });
  if (!s.tap()) return PourEvent.lost;
  var guard = 0;
  while (s.pour != null && guard++ < 64) {
    if (plan.freezeOn != null && s.pour!.channelId == plan.freezeOn) {
      s.pour!.t = 0.5;
      s.freezeHere();
      return PourEvent.froze;
    }
    final e = s.arrive();
    if (e != PourEvent.travelling) return e;
  }
  return PourEvent.lost;
}

/// Does [s] satisfy everything Stars 1 and 2 need from the line?
///  · the span across the runner (Star 1's crossing),
///  · the reliquary key CAST (Star 2's hidden mold), and
///  · a way to stand beside it (the sump crossing).
bool foundryWorksDone(FoundryState s) =>
    s.cast('span_a') &&
    (s.cast('reliquary') || s.carried == 'reliquary' ||
        s.wardsTurned.contains('reliquary')) &&
    s.access.contains('sump');

/// Where a star stands, and which one. The line IS the puzzle; the star is
/// simply where solving it leaves you standing (§7 — one core mechanic, one
/// consequence, one success, and no extra ceremony bolted on the end).
class FoundryStarSpot {
  const FoundryStarSpot({required this.starIndex, required this.position});

  final int starIndex;
  final Offset position;
}

// ── The layout ──────────────────────────────────────────────

/// Molten Reliquary — Lava. A LINE, not a hub: tap_head → switch_yard →
/// {chill_house · stamp_mill} → mold_floor → slag_reliquary / pour_heart,
/// with the works' own tail running the whole length back to the sump.
const DungeonLayout kLavaLayout = DungeonLayout(
  element: 'Lava',
  entranceRoomId: 'tap_head',
  entranceSpawn: Offset(150, 200),
  title: 'THE MOLTEN RELIQUARY',
  descentTitle: 'Magmora Works',
  stars: [
    DungeonStarSpec(
      name: 'Ember Star',
      earnAnnouncement:
          'The Ember Star is yours — the line cast you a road across itself',
    ),
    DungeonStarSpec(
      name: 'Reliquary Star',
      earnAnnouncement:
          'The Reliquary Star is yours — the hidden mold gave up its key',
    ),
    DungeonStarSpec(name: 'Furnace Star'),
  ],
  entranceRevealDoor: DungeonDoorRef('tap_head', 'switch_yard'),
  finaleDoor: DungeonDoorRef('mold_floor', 'pour_heart'),
  riteAnnouncement:
      'Ember and Reliquary are won — the heart gate draws back off its rails',
  finaleSealedHint:
      'The heart gate is bolted — it draws back only for the Ember and '
      'Reliquary stars',
  guardianSealedHint:
      'The heart gate is bolted — nothing down there stirs until the works '
      'are finished',
  mercyShrineRoomId: 'pour_heart',
  // Ideal: Lavahorn · Earthmask · Icemane — named by VERB, never by body part
  // (§4). Only the last of the three is a hard gate; the other two are the
  // hands the works were built for.
  riddle: [
    'A molten heart with the heaviest grip breaks the crucible\'s seal;',
    'an earthen eye reads the works\' own manifest off the rock;',
    'and a cold that paves a road behind it hardens the running metal.',
  ],
  // ONE hard gate (§4 budget: Air 1 · Earth 1 · Water 1 · Lava 1). Star 1 and
  // the guardian stay earnable by ANY correct-element trio; only the hidden
  // mold's crossing asks for a specific hand, and it asks for the one whose
  // whole fiction is laying a cold road behind itself.
  familyGates: [
    DungeonFamilyGate(
      objectId: 'hand_chill',
      element: 'Ice',
      family: 'Mane',
      hintLine: 'Only an Ice mane\'s cold sets the metal where it runs',
    ),
  ],
  rooms: {
    // ── TAP HEAD ── the crucible, and (unremarked) the sump that the whole
    // works drains back into. The reliquary's mold has been down there the
    // entire time; nothing marks it but the manifest and your own eyes.
    'tap_head': DungeonRoom(
      id: 'tap_head',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(876, 240, 24, 90),
          targetRoomId: 'switch_yard',
          targetSpawn: Offset(60, 280),
        ),
      ],
    ),

    // ── SWITCH YARD ── the fork. North arm runs plain; south arm runs to the
    // mill. No hub: you cannot get anywhere from here except onward.
    'switch_yard': DungeonRoom(
      id: 'switch_yard',
      bounds: Rect.fromLTWH(0, 0, 760, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 240, 24, 90),
          targetRoomId: 'tap_head',
          targetSpawn: Offset(820, 280),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(736, 120, 24, 90),
          targetRoomId: 'chill_house',
          targetSpawn: Offset(60, 500),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(330, 536, 110, 24),
          targetRoomId: 'stamp_mill',
          targetSpawn: Offset(435, 120),
        ),
      ],
    ),

    // ── CHILL HOUSE ── the north arm crosses it, and the shroud over the
    // channel is the foundry's own way of turning a pour into a road. North
    // of that channel: the catwalk, the tail switch, the slag pit.
    'chill_house': DungeonRoom(
      id: 'chill_house',
      bounds: Rect.fromLTWH(0, 0, 860, 720),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 460, 24, 90),
          targetRoomId: 'switch_yard',
          targetSpawn: Offset(700, 165),
        ),
        // THE GANTRY: an overhead walk from the catwalk out to the mold
        // floor, bolted shut until a key is cast to its ward.
        DungeonDoor(
          rect: Rect.fromLTWH(836, 210, 24, 80),
          targetRoomId: 'mold_floor',
          targetSpawn: Offset(60, 340),
        ),
      ],
    ),

    // ── STAMP MILL ── the south arm. The drop-hammer wards a pour; the purge
    // vent past it gasses one. Both are just what the line does to metal.
    'stamp_mill': DungeonRoom(
      id: 'stamp_mill',
      bounds: Rect.fromLTWH(0, 0, 940, 520),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(380, 0, 110, 24),
          targetRoomId: 'switch_yard',
          targetSpawn: Offset(385, 420),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(916, 150, 24, 90),
          targetRoomId: 'mold_floor',
          targetSpawn: Offset(60, 685),
        ),
      ],
    ),

    // ── MOLD FLOOR ── STAR 1. The runner splits the floor top to bottom and
    // the star stands on the far side of it. The sluice throws each pour into
    // the span form, the key form, or on down the tail.
    'mold_floor': DungeonRoom(
      id: 'mold_floor',
      bounds: Rect.fromLTWH(0, 0, 1180, 880),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 640, 24, 90),
          targetRoomId: 'stamp_mill',
          targetSpawn: Offset(880, 195),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 300, 24, 80),
          targetRoomId: 'chill_house',
          targetSpawn: Offset(800, 250),
        ),
        // THE WARD: the reliquary answers only its own cast key.
        DungeonDoor(
          rect: Rect.fromLTWH(1156, 200, 24, 90),
          targetRoomId: 'slag_reliquary',
          targetSpawn: Offset(60, 245),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(800, 0, 110, 24),
          targetRoomId: 'pour_heart',
          targetSpawn: Offset(515, 700),
        ),
      ],
      foundryStar: FoundryStarSpot(starIndex: 0, position: Offset(860, 300)),
    ),

    // ── SLAG RELIQUARY ── the vault. Behind a key whose mold was installed
    // at the other end of the works (§5.5).
    'slag_reliquary': DungeonRoom(
      id: 'slag_reliquary',
      bounds: Rect.fromLTWH(0, 0, 660, 520),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 200, 24, 90),
          targetRoomId: 'mold_floor',
          targetSpawn: Offset(1120, 245),
        ),
      ],
      vaultCache: Offset(330, 330),
      foundryStar: FoundryStarSpot(starIndex: 1, position: Offset(330, 170)),
    ),

    // ── POUR HEART ── STAR 3. Magmara rides the heart's own ring (§7: the
    // guardian fights WITH the planet's rule) and the two heads on the ring
    // are how you stop it — the line's verb, in the fight.
    'pour_heart': DungeonRoom(
      id: 'pour_heart',
      bounds: Rect.fromLTWH(0, 0, 1040, 820),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(460, 796, 110, 24),
          targetRoomId: 'mold_floor',
          targetSpawn: Offset(855, 90),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(520, 300),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Lava',
          mysticId: 'Magmara',
        ),
      ),
    ),
  },
);

/// The heart's two heads (§7 guardian twist): throwing one as Magmara rides
/// past beaches it out of the channel. Fed by the heart's own overflow, so
/// they cost the crucible NOTHING — a spent budget can never strand the fight.
const List<Offset> kLavaHeartHeads = [Offset(250, 380), Offset(790, 380)];

/// Where Magmara rides.
const Offset kLavaHeartCentre = Offset(520, 400);
const double kLavaHeartRadius = 236;

/// The mill's accumulator: Ice+Lava→Steam drives the die (§6.2 "the key recipe
/// drives the piston stations"). Element-only + recipe, never a family gate.
const Offset kLavaAccumulator = Offset(210, 300);
const DungeonInteractionRequirement kLavaDieRequirement =
    DungeonInteractionRequirement(element: 'Steam', allowRecipe: true);

/// The foreman's manifest: what a Mask reads (§5.6 — insight is the only
/// channel allowed to teach method).
const Offset kLavaManifest = Offset(150, 300);
