// lib/games/planet_dungeon/planet_dungeon_game_fire.dart
//
// CINDER CATHEDRAL — the Fire planet's puzzle logic + rendering, as a part of
// planet_dungeon_game.dart (shares the engine's private state the same way
// the Air pilot's inline code does, without growing the main file).
//
// World rule: *fire remembers the order it was lit — and so does the wax.*
//  • Entry — the narthex's great hearth is cold; a Fire creature rekindles it
//    and the inner doors part (one-time reveal, persisted like Air's rune).
//  • Star 1 (Ember) — THE FORENSIC RITE (§6.1 REWORK / §9.1 item 3). The
//    choir's SIX braziers must be lit in the order the cathedral remembers,
//    and that order is ROLLED PER RUN — there is no key to read, only
//    EVIDENCE to reason from. Each brazier wears the physical testimony of
//    the last rite:
//       WAX  — melted lowest = lit first, burned longest (three legible
//              tiers: guttered · half-spent · barely touched);
//       SOOT — the shadow leans AWAY from the neighbour that was already
//              burning when this one caught. The brazier lit FIRST had no
//              neighbour to lean from: its soot lies in an even collar;
//       ASH  — the drift piles downwind of the whole sequence, one compass
//              direction streaked across the choir floor.
//    Each channel alone is ambiguous; together they pin the rite down to
//    exactly one answer — GUARANTEED, because every roll is re-rolled until
//    `solveRiteOrder()` (the same evidence the game draws) returns 1. A
//    patient player solves it with NO Mask in the party. Mask insight only
//    ASSISTS: t1 marks which evidence is readable, t2 annotates ONE deduced
//    link. The scriptorium mural is CONFIRMATION — two of the six positions,
//    never the order. The choir floor's ember-walk is a labyrinth: flavour,
//    signalling nothing. A wrong flame still snuffs the rite + ash wisps.
//  • Star 2 (Ash) — THE WIND CARRIES THE REACTION. The cloister garth is open
//    to the sky and holds a CROSSWIND. Plant grows a bed; Fire burns it
//    (Plant+Fire→Dust) — and the reaction's product GOES SOMEWHERE: the burn
//    brands its own bed and throws a plume of ash down the wind onto every bed
//    behind it in the lane. Six grooves are cut in the garth's stone, each for
//    one gift — the DRIFT (ash carried onto it), the BRAND (a burn of its own
//    bed) or NOTHING AT ALL (a swept groove that must stay clean) — and the
//    assignment is ROLLED PER RUN. Any Air creature turns the garth's iron
//    wind-cross a quarter (element-only, exactly like the vesper gust), so the
//    run's question is *which quarter, and in what order*. A bed that catches
//    the wrong deposit is SPOILED; growing it again buries the ruin, which is
//    why nothing here can be softlocked — proved, not asserted, by
//    `ashGardenStrandable()`. Every burn still breathes out cinder wisps,
//    angrier the nearer the garth is to done.
//  • Star 3 (Pyre) — THE ROUTE DECISION. The three ember bells never move,
//    but the censer run to them is a choice made at two stands: the SHORT run
//    over the ash-storm nave (two censers, wide gaps — the flame starves
//    faster and the ash comes up unstable at every ignition) or the LONG way
//    round the calm cloister (two extra censers to keep alight, but every gap
//    is one comfortable gust). Declare it, then the first censer to take
//    flame commits it. Underneath, the relay is unchanged: Fire lights,
//    the flame crawls and starves, Air gusts (ELEMENT-ONLY, Speed-scaled)
//    bear it on, a starved flame spawns a fury wave, three tolls wake the
//    black-flame Simurgh in the sanctum.
//  • The guardian (§7) — Simurgh RE-LIGHTS the rite braziers as it strikes:
//    phantom iron rings the roost in the choir's own arrangement, and it
//    walks THIS RUN'S rolled order, one flare-then-pillar per beat. The order
//    is the bullet pattern; Star 1's knowledge is Star 3's footwork.

part of 'planet_dungeon_game.dart';

/// The physical testimony one brazier carries from the last rite (§6.1). This
/// is the SINGLE source of truth for both the renderer and `solveRiteOrder()`,
/// so the proof of solvability can never drift from what the player sees.
class BrazierTestimony {
  BrazierTestimony({
    required this.brazierIndex,
    required this.waxTier,
    required this.sootLean,
  });

  /// Index into the choir room's `braziers` list.
  final int brazierIndex;

  /// 0 guttered (one of the first pair lit) · 1 half-spent · 2 barely touched.
  /// Deliberately COARSE: two braziers share every tier, so wax alone narrows
  /// the rite to eight candidates and never hands over the answer.
  final int waxTier;

  /// The unit direction the soot shadow leans — away from whichever brazier
  /// was already burning nearest when this one caught. `null` on the brazier
  /// lit FIRST: nothing was alight, so its soot lies in an even collar.
  final Offset? sootLean;

  /// The wax's drawn height fraction. A pure function of [waxTier] — two
  /// braziers in one tier must be visually IDENTICAL, or the tier leaks rank.
  double get waxFill => switch (waxTier) { 0 => 0.16, 1 => 0.54, _ => 1.0 };
}

/// The rite's evidence is read to about this precision (radians ≈ 23°) — a
/// soot plume is a smudge, not a protractor. The roll re-rolls until the
/// evidence is unique AT THIS TOLERANCE, so uniqueness is a promise about
/// human eyes and not about floating point.
const double _kSootTolerance = 0.40;

/// Seconds the rite's own fire takes to eat a brazier's old testimony.
const double _kTestimonyFade = 0.9;

/// Seconds insight's marking takes to bloom over the evidence.
const double _kTestimonyMarkSeconds = 0.7;

/// Seconds the two censer runs take to swap over (eased, never a snap).
const double _kRouteSwapSeconds = 0.8;

// ── Simurgh's brazier telegraph (§7 retrofit) ──────────────
/// Seconds between re-lightings while the guardian strikes.
const double _kTelegraphBeat = 1.15;

/// Of that beat, the share spent flaring (the wind-up you may read and flee).
const double _kTelegraphWindup = 0.62;

/// The flame pillar's reach and its damage per second (progress-scaled).
const double _kTelegraphRadius = 66.0;
const double _kTelegraphDps = 5.5;

// ── STAR 2: THE WIND CARRIES THE REACTION ─────────────────
//
// The cloister garth is open to the sky. Burning a bed does not merely mark
// that bed: the Plant+Fire→Dust reaction BRANDS it and throws its ash down the
// crosswind onto every bed behind it in the lane. Each groove is cut for one
// gift — the drift, the brand, or nothing — so the run's question is *which
// quarter, and in what order*. Everything below is PURE: the interaction
// verbs, the renderer and `solveAshGarden()` all go through these same
// functions, so the proof of solvability can never drift from what is played.

/// What a bed currently holds. `spoiled` = a brand the drift has since fouled;
/// it satisfies no groove at all, and is undone by growing the bed again.
enum AshBedState { barren, green, ash, scorch, spoiled }

/// The verbs a garden plan is made of.
enum AshGardenVerb { grow, burn, turnWind }

/// One move of a garden plan. [bed] is the bed index, or -1 for a turn of the
/// wind-cross.
class AshGardenMove {
  const AshGardenMove(this.verb, this.bed);
  final AshGardenVerb verb;
  final int bed;

  @override
  String toString() => verb == AshGardenVerb.turnWind
      ? 'turnWind'
      : '${verb.name}($bed)';
}

/// The garth's rules, as pure functions over a packed base-5 board (one digit
/// per bed, `AshBedState.index`) and a wind quarter (0 N · 1 E · 2 S · 3 W;
/// a quarter turn is +1, clockwise).
class AshGardenRules {
  AshGardenRules({required this.cols, required this.rows})
    : bedCount = cols * rows {
    var b = 1;
    for (var i = 0; i < bedCount; i++) {
      _pow5.add(b);
      b *= 5;
    }
    boardCount = b;
    _plumes = [
      for (var w = 0; w < 4; w++)
        [for (var i = 0; i < bedCount; i++) _computePlume(i, w)],
    ];
  }

  final int cols;
  final int rows;
  final int bedCount;
  late final int boardCount;
  final List<int> _pow5 = [];
  late final List<List<List<int>>> _plumes;

  int colOf(int bed) => bed % cols;
  int rowOf(int bed) => bed ~/ cols;

  /// The beds a burn at [bed] dusts under [wind] — its whole lane downwind,
  /// nearest first. The ash is a streak, not a single hop.
  List<int> plume(int bed, int wind) => _plumes[wind & 3][bed];

  List<int> _computePlume(int bed, int wind) {
    final c = colOf(bed);
    final r = rowOf(bed);
    final out = <int>[];
    switch (wind & 3) {
      case 0: // north: toward row 0
        for (var rr = r - 1; rr >= 0; rr--) {
          out.add(rr * cols + c);
        }
      case 1: // east: toward the last column
        for (var cc = c + 1; cc < cols; cc++) {
          out.add(r * cols + cc);
        }
      case 2: // south
        for (var rr = r + 1; rr < rows; rr++) {
          out.add(rr * cols + c);
        }
      default: // west
        for (var cc = c - 1; cc >= 0; cc--) {
          out.add(r * cols + cc);
        }
    }
    return out;
  }

  AshBedState cellAt(int board, int bed) =>
      AshBedState.values[(board ~/ _pow5[bed]) % 5];

  int withCell(int board, int bed, AshBedState v) {
    final cur = (board ~/ _pow5[bed]) % 5;
    return board + (v.index - cur) * _pow5[bed];
  }

  /// GROW — Plant. Legal on any bed not already green, whatever lies in it:
  /// the new growth buries ash, brand and ruin alike. This is why the garden
  /// can never be softlocked, and the solver proves it (`ashGardenStrandable`).
  int? grow(int board, int bed) => cellAt(board, bed) == AshBedState.green
      ? null
      : withCell(board, bed, AshBedState.green);

  /// BURN — Fire on grown vines. Brands this bed and lays the reaction's ash
  /// on every bed downwind: bare ground and young vines take the drift, a
  /// standing brand is FOULED by it.
  int? burn(int board, int bed, int wind) {
    if (cellAt(board, bed) != AshBedState.green) return null;
    var next = withCell(board, bed, AshBedState.scorch);
    for (final d in plume(bed, wind)) {
      next = withCell(next, d, switch (cellAt(next, d)) {
        AshBedState.barren ||
        AshBedState.green ||
        AshBedState.ash => AshBedState.ash,
        _ => AshBedState.spoiled,
      });
    }
    return next;
  }

  /// The one groove a bed in this state sits true for (null = none — a spoiled
  /// bed answers nothing until it is grown again).
  GrooveDemand? satisfies(AshBedState s) => switch (s) {
    AshBedState.barren || AshBedState.green => GrooveDemand.clean,
    AshBedState.ash => GrooveDemand.ash,
    AshBedState.scorch => GrooveDemand.scorch,
    AshBedState.spoiled => null,
  };

  bool sitsTrue(int board, int bed, GrooveDemand demand) =>
      satisfies(cellAt(board, bed)) == demand;

  bool solved(int board, List<GrooveDemand> demands) {
    for (var i = 0; i < bedCount; i++) {
      if (satisfies(cellAt(board, i)) != demands[i]) return false;
    }
    return true;
  }

  /// Pack a groove assignment into a base-3 key (the analysis works in keys).
  int demandKey(List<GrooveDemand> demands) {
    var key = 0;
    var pow = 1;
    for (var i = 0; i < bedCount; i++) {
      key += demands[i].index * pow;
      pow *= 3;
    }
    return key;
  }

  List<GrooveDemand> demandsOf(int key) {
    var k = key;
    return [
      for (var i = 0; i < bedCount; i++)
        () {
          final d = GrooveDemand.values[k % 3];
          k ~/= 3;
          return d;
        }(),
    ];
  }

  /// The assignment a board sits true for, or -1 if any bed is spoiled (a
  /// spoiled bed answers no groove, so such a board solves nothing).
  int boardKey(int board) {
    var key = 0;
    var pow = 1;
    for (var i = 0; i < bedCount; i++) {
      final d = satisfies(cellAt(board, i));
      if (d == null) return -1;
      key += d.index * pow;
      pow *= 3;
    }
    return key;
  }

  // ── The proof machinery ─────────────────────────────────

  static final Map<String, AshGardenAnalysis> _analysisCache = {};

  /// Walk the WHOLE state graph once from the empty garth at [startWind] and
  /// report, for every one of the 3^bedCount groove assignments, the shortest
  /// solution and whether it can be done without ever touching the vane. The
  /// graph does not depend on the grooves — only the goal test does — so a
  /// single sweep answers for all of them, and it is cached per wind.
  AshGardenAnalysis analyse(int startWind) {
    final key = '${cols}x$rows@$startWind';
    final cached = _analysisCache[key];
    if (cached != null) return cached;

    // 1. Shortest distances with the vane in play (states = board × wind).
    final states = boardCount * 4;
    final dist = List<int>.filled(states, -1);
    final start = startWind & 3;
    dist[start] = 0;
    final queue = <int>[start];
    for (var head = 0; head < queue.length; head++) {
      final s = queue[head];
      final board = s ~/ 4;
      final wind = s % 4;
      final d = dist[s] + 1;
      void push(int ns) {
        if (dist[ns] < 0) {
          dist[ns] = d;
          queue.add(ns);
        }
      }

      push(board * 4 + ((wind + 1) & 3));
      for (var i = 0; i < bedCount; i++) {
        final g = grow(board, i);
        if (g != null) push(g * 4 + wind);
        final b = burn(board, i, wind);
        if (b != null) push(b * 4 + wind);
      }
    }
    final minActions = <int, int>{};
    for (final s in queue) {
      final k = boardKey(s ~/ 4);
      if (k < 0) continue;
      final d = dist[s];
      final cur = minActions[k];
      if (cur == null || d < cur) minActions[k] = d;
    }

    // 2. The same sweep with the vane NAILED DOWN, once per quarter: any
    //    assignment missing from all four needs a turn of the wind, and that
    //    is a property of the grooves themselves, not of where the wind
    //    happened to start.
    final noTurn = <int>{};
    for (var w = 0; w < 4; w++) {
      final seen = List<bool>.filled(boardCount, false);
      seen[0] = true;
      final q = <int>[0];
      for (var head = 0; head < q.length; head++) {
        final board = q[head];
        for (var i = 0; i < bedCount; i++) {
          final g = grow(board, i);
          if (g != null && !seen[g]) {
            seen[g] = true;
            q.add(g);
          }
          final b = burn(board, i, w);
          if (b != null && !seen[b]) {
            seen[b] = true;
            q.add(b);
          }
        }
      }
      for (final board in q) {
        final k = boardKey(board);
        if (k >= 0) noTurn.add(k);
      }
    }

    final result = AshGardenAnalysis(
      startWind: start,
      states: states,
      reachable: queue.length,
      minActions: Map.unmodifiable(minActions),
      noTurnSolvable: Set.unmodifiable(noTurn),
    );
    _analysisCache[key] = result;
    return result;
  }

  /// The shortest plan for [demands] from the empty garth at [startWind],
  /// walking the real [grow]/[burn]/turn transitions. Returns null when the
  /// grooves cannot all sit true at once (the all-drift garth is the one such
  /// assignment — nothing is left to feed the last groove).
  List<AshGardenMove>? plan(
    List<GrooveDemand> demands,
    int startWind, {
    int board = 0,
    bool allowTurns = true,
  }) {
    final states = boardCount * 4;
    final dist = List<int>.filled(states, -1);
    final prev = List<int>.filled(states, -1);
    final via = List<AshGardenMove?>.filled(states, null);
    final start = board * 4 + (startWind & 3);
    dist[start] = 0;
    final queue = <int>[start];
    for (var head = 0; head < queue.length; head++) {
      final s = queue[head];
      final b = s ~/ 4;
      final w = s % 4;
      if (solved(b, demands)) return _unwind(prev, via, start, s);
      void push(int ns, AshGardenMove move) {
        if (dist[ns] >= 0) return;
        dist[ns] = dist[s] + 1;
        prev[ns] = s;
        via[ns] = move;
        queue.add(ns);
      }

      if (allowTurns) {
        push(b * 4 + ((w + 1) & 3), const AshGardenMove(AshGardenVerb.turnWind, -1));
      }
      for (var i = 0; i < bedCount; i++) {
        final g = grow(b, i);
        if (g != null) push(g * 4 + w, AshGardenMove(AshGardenVerb.grow, i));
        final bu = burn(b, i, w);
        if (bu != null) push(bu * 4 + w, AshGardenMove(AshGardenVerb.burn, i));
      }
    }
    return null;
  }

  List<AshGardenMove> _unwind(
    List<int> prev,
    List<AshGardenMove?> via,
    int start,
    int goal,
  ) {
    final out = <AshGardenMove>[];
    var s = goal;
    while (s != start) {
      out.add(via[s]!);
      s = prev[s];
    }
    return out.reversed.toList();
  }

  /// Reachable states from which NO solution remains — Air's `strandable`
  /// proof, applied to the garth. Structurally this must be 0: growing is
  /// legal on every bed that is not already green, so any ruin can be buried
  /// and begun again. The test asserts it rather than trusting the argument.
  int strandable(List<GrooveDemand> demands, int startWind) {
    final states = boardCount * 4;
    // Forward reachability from the empty garth.
    final seen = List<bool>.filled(states, false);
    final start = startWind & 3;
    seen[start] = true;
    final queue = <int>[start];
    for (var head = 0; head < queue.length; head++) {
      final s = queue[head];
      final b = s ~/ 4;
      final w = s % 4;
      for (final ns in _successors(b, w)) {
        if (!seen[ns]) {
          seen[ns] = true;
          queue.add(ns);
        }
      }
    }
    // Backward: which of them can still reach a solved board?
    final alive = List<bool>.filled(states, false);
    final back = <int>[];
    for (final s in queue) {
      if (solved(s ~/ 4, demands)) {
        alive[s] = true;
        back.add(s);
      }
    }
    // One reverse pass needs the reverse edges; build them over the reachable
    // set only (the graph is small — bedCount is 6).
    final rev = <int, List<int>>{};
    for (final s in queue) {
      for (final ns in _successors(s ~/ 4, s % 4)) {
        (rev[ns] ??= []).add(s);
      }
    }
    for (var head = 0; head < back.length; head++) {
      for (final p in rev[back[head]] ?? const <int>[]) {
        if (!alive[p]) {
          alive[p] = true;
          back.add(p);
        }
      }
    }
    var stranded = 0;
    for (final s in queue) {
      if (!alive[s]) stranded++;
    }
    return stranded;
  }

  List<int> _successors(int board, int wind) {
    final out = <int>[board * 4 + ((wind + 1) & 3)];
    for (var i = 0; i < bedCount; i++) {
      final g = grow(board, i);
      if (g != null) out.add(g * 4 + wind);
      final b = burn(board, i, wind);
      if (b != null) out.add(b * 4 + wind);
    }
    return out;
  }
}

/// One exhaustive sweep of the garth's state graph (see [AshGardenRules.analyse]).
class AshGardenAnalysis {
  const AshGardenAnalysis({
    required this.startWind,
    required this.states,
    required this.reachable,
    required this.minActions,
    required this.noTurnSolvable,
  });

  final int startWind;

  /// board × wind states in the graph, and how many the empty garth reaches.
  final int states;
  final int reachable;

  /// Groove assignment (base-3 key) → shortest solution length.
  final Map<int, int> minActions;

  /// The assignments that can be solved without ever turning the vane.
  final Set<int> noTurnSolvable;
}

/// One rules object per authored garth (they are immutable and their state
/// sweep is cached inside), keyed by room id.
final Map<String, AshGardenRules> _ashRulesCache = {};

/// The band a rolled garden must land in: hard enough to plan, short enough to
/// walk. (Optimal-play action counts — grows, burns and turns of the vane.)
const int _kGardenMinActions = 8;
const int _kGardenMaxActions = 12;

/// Seconds young vines need before they will take flame — the time price of
/// burying a fouled bed and beginning it again.
const double _kGardenGrowSeconds = 1.2;

/// Seconds an ash plume takes to cross to the bed behind (watched, never
/// teleported), and how long the wind-cross takes to swing a quarter.
const double _kPlumeFlightSeconds = 0.55;
const double _kWindSwingSeconds = 0.7;

/// How near a creature must stand to work a bed, or the garth's wind-cross.
const double _kBedReach = 54.0;
const double _kVaneReach = 58.0;

/// A live vesper flame crawling its incense chain (Star 3). Lives in
/// [PlanetDungeonGame._vesperFlames]; advanced by `_updateCathedral`.
class _VesperFlame {
  _VesperFlame({required this.segment, required this.t, required this.life});

  /// Index of the chain segment being crossed (nodes[i] → nodes[i+1]/bell).
  int segment;

  /// 0..1 progress along the current segment.
  double t;

  /// Seconds before the flame starves (censers and gusts refresh it).
  double life;
}

// Tunables for the vesper rite. Self-speed alone can't cross a censer gap
// before the flame starves — the wind has to matter.
const double _kFlameSelfSpeed = 24.0; // px/s unaided
const double _kFlameLife = 2.6; // seconds per feeding
const double _kGustRadius = 85.0;

// ── The Lost Maxims (easter eggs — one per dungeon, 20 gold once) ──
// Discovery ids ride the persisted cloud-discovery channel ('egg:' prefix);
// the screen pays out 20 gold the first time one is found.

// (Air's `kAirFirstWindEggId` moved to planet_dungeon_game_air.dart with the
// rest of the spire's own content — §9.1 item 4.)

/// Fire's maxim — the EMBER EPITAPH. Mask insight in the scriptorium WRITES
/// the maxim into the floor (an ember-quill animates it stroke by stroke) and
/// bares a garden planter beside it; Plant fills the planter, Fire lights it,
/// and three gusts of Air swell the blaze until a burn-front sweeps the
/// script and the words stay lit in fire. Entirely wordless — no hint popups.
const String kFireEpitaphEggId = 'egg:fire_epitaph';

/// Where the epitaph garden sits beside the floor-script.
const Offset kEmberEpitaphPlanter = Offset(170, 390);

/// Epicurus, written in soot, then in fire.
const List<String> kFireEpitaphLines = [
  'Death is nothing to us.',
  'When we exist, death is not;',
  'and when death exists, we are not.',
];

/// The dead words as the quill writes them: an alchemist's mirror-cipher
/// (every word backwards) — scrambled enough to stay hidden, fair enough to
/// be decoded by a determined reader. The fire unscrambles them.
const List<String> kFireEpitaphScrambledLines = [
  'htaeD si gnihton ot su.',
  'nehW ew tsixe, htaed si ton;',
  'dna nehw htaed stsixe, ew era ton.',
];

// Mural-script geometry + animation pacing (the words live IN the soot
// mural panel, where the unread smudges used to be).
const Offset _kEpitaphTextAnchor = Offset(320, 86); // first line's centre
const double _kEpitaphLineHeight = 23.0;
const double _kEpitaphWritePerLine = 1.5; // seconds the quill spends per line
const double _kEpitaphWriteStagger = 1.3; // line i starts at i * stagger
const double _kEpitaphBurnPerLine = 1.6; // the fire takes its time
const double _kEpitaphBurnStagger = 1.2;

extension CinderCathedral on PlanetDungeonGame {
  // ── The rite: rolled per run, proved solvable ───────────

  /// The choir — the room whose braziers carry a star (null off Fire, and in
  /// the generated raid arena).
  DungeonRoom? get _choirRoom {
    for (final r in layout.rooms.values) {
      if (r.brazierStarIndex != null && r.braziers.length >= 2) return r;
    }
    return null;
  }

  /// Roll THIS RUN'S rite and plant its evidence. The order is random, but the
  /// evidence is never noise: a candidate order is kept only when
  /// [solveRiteOrder] can reconstruct it — and reconstruct ONLY it — from the
  /// testimony alone. A wiki cannot spoil the answer; the braziers always can.
  void _rollRiteOrder() {
    final room = _choirRoom;
    if (room == null) return;
    final n = room.braziers.length;
    final rng = Random();
    final candidate = List<int>.generate(n, (i) => i);
    for (var attempt = 0; attempt < 400; attempt++) {
      candidate.shuffle(rng);
      _plantTestimony(room, candidate);
      if (solveRiteOrder().satisfying == 1) return;
    }
    // Unreachable in practice (≈39% of orders qualify — see the Fire test's
    // seed sweep). Fall back to the authored order so the rite is never
    // unplayable, evidence and all.
    final authored = [...room.braziers]..sort((a, b) => a.order - b.order);
    _plantTestimony(room, [
      for (final b in authored) room.braziers.indexOf(b),
    ]);
  }

  /// Generate the testimony an [order] would have LEFT BEHIND, and install it.
  void _plantTestimony(DungeonRoom room, List<int> order) {
    riteOrder
      ..clear()
      ..addAll(order);
    final leans = List<Offset?>.filled(order.length, null);
    final tiers = List<int>.filled(order.length, 0);
    for (var rank = 0; rank < order.length; rank++) {
      final idx = order[rank];
      // WAX: two braziers per tier — coarse on purpose.
      tiers[idx] = rank ~/ 2;
      if (rank == 0) continue;
      // SOOT: leans away from the NEAREST brazier already burning.
      final pred = _nearestAmong(room, idx, order.sublist(0, rank));
      final d = room.braziers[idx].position - room.braziers[pred].position;
      final len = d.distance;
      leans[idx] = len < 1e-6 ? const Offset(1, 0) : d / len;
    }
    riteTestimony
      ..clear()
      ..addAll([
        for (var i = 0; i < order.length; i++)
          BrazierTestimony(brazierIndex: i, waxTier: tiers[i], sootLean: leans[i]),
      ]);
    // ASH: the whole sequence's downwind, quantised to a compass point.
    riteAshDrift = _quantiseDrift(
      room.braziers[order.last].position - room.braziers[order.first].position,
    );
    // The mural CONFIRMS two ranks — never adjacent, so it can never hand over
    // a step of the sequence.
    final rng = Random();
    final a = rng.nextInt(order.length);
    var b = rng.nextInt(order.length);
    var guard = 0;
    while ((b - a).abs() < 2 && guard++ < 40) {
      b = rng.nextInt(order.length);
    }
    riteMuralRanks = [a, b]..sort();
  }

  /// The member of [pool] physically nearest brazier [idx].
  int _nearestAmong(DungeonRoom room, int idx, List<int> pool) {
    var best = pool.first;
    var bestD = double.infinity;
    for (final j in pool) {
      final d = (room.braziers[idx].position - room.braziers[j].position)
          .distance;
      if (d < bestD) {
        bestD = d;
        best = j;
      }
    }
    return best;
  }

  /// Snap a drift vector to one of eight compass points (the ash piles in a
  /// direction, not on a bearing).
  Offset _quantiseDrift(Offset v) {
    if (v.distance < 1e-6) return const Offset(1, 0);
    final step = (atan2(v.dy, v.dx) / (pi / 4)).round() * (pi / 4);
    return Offset(cos(step), sin(step));
  }

  double _angleBetween(Offset a, Offset b) {
    final dot = (a.dx * b.dx + a.dy * b.dy).clamp(-1.0, 1.0);
    return acos(dot);
  }

  /// Brute-force the forensic rite over EVERY ordering of the choir's braziers,
  /// reading only the testimony the game actually renders (wax tiers, soot
  /// leans, the ash drift). An ordering SATISFIES when all three channels
  /// agree with it. The Fire test asserts exactly ONE satisfying ordering
  /// across many rolled seeds — the §6.1 "consistent and sufficient" promise,
  /// checked against the same data the braziers wear, so proof and gameplay
  /// cannot drift apart.
  ///
  /// This is also the deduction a player performs, in the same order: the even
  /// soot collar names the first fire; each later fire's soot points back at
  /// the nearest one already burning; the wax says which pair a fire belongs
  /// to; the ash says which way the whole rite ran.
  ({int searched, int satisfying, List<int>? solution}) solveRiteOrder() {
    final room = _choirRoom;
    if (room == null || riteTestimony.length != room.braziers.length) {
      return (searched: 0, satisfying: 0, solution: null);
    }
    final n = room.braziers.length;
    var searched = 0;
    var satisfying = 0;
    List<int>? solution;

    final current = <int>[];
    final used = List<bool>.filled(n, false);

    void walk() {
      if (current.length == n) {
        searched++;
        // ASH: the drift must match the sequence's own downwind.
        final drift = _quantiseDrift(
          room.braziers[current.last].position -
              room.braziers[current.first].position,
        );
        if ((drift - riteAshDrift).distance < 1e-6) {
          satisfying++;
          solution = [...current];
        }
        return;
      }
      final rank = current.length;
      for (var idx = 0; idx < n; idx++) {
        if (used[idx]) continue;
        final t = riteTestimony[idx];
        // WAX: this brazier's tier must be the tier this rank burns in.
        if (t.waxTier != rank ~/ 2) continue;
        if (rank == 0) {
          // SOOT: only the even collar can be the first fire.
          if (t.sootLean != null) continue;
        } else {
          if (t.sootLean == null) continue;
          // SOOT: the lean must point away from the nearest already-lit.
          final pred = _nearestAmong(room, idx, current);
          final d = room.braziers[idx].position - room.braziers[pred].position;
          final len = d.distance;
          if (len < 1e-6) continue;
          if (_angleBetween(d / len, t.sootLean!) > _kSootTolerance) continue;
        }
        used[idx] = true;
        current.add(idx);
        walk();
        current.removeLast();
        used[idx] = false;
      }
    }

    walk();
    return (searched: searched, satisfying: satisfying, solution: solution);
  }

  /// The rank at which brazier [index] is remembered (0 = lit first).
  int riteRankOf(int index) {
    final r = riteOrder.indexOf(index);
    return r < 0 ? index : r;
  }

  /// The brazier index the rite lights at [rank].
  int riteBrazierAt(int rank) =>
      (rank >= 0 && rank < riteOrder.length) ? riteOrder[rank] : rank;

  /// The testimony brazier [index] wears, or null before the roll lands.
  BrazierTestimony? testimonyFor(int index) =>
      (index >= 0 && index < riteTestimony.length) ? riteTestimony[index] : null;

  /// The ONE link a tier-2 reading has drawn out (null = none yet). Read-only,
  /// for tests/diagnostics.
  int? get testimonyLinkRank => _testimonyLinkRank;

  // ── The ash garden: rolled per run, proved solvable ─────

  /// The cloister — the room whose beds carry a star (null off Fire, and in
  /// the generated raid arena).
  DungeonRoom? get _cloisterRoom {
    for (final r in layout.rooms.values) {
      if (r.vineStarIndex != null && r.vineBeds.isNotEmpty) return r;
    }
    return null;
  }

  /// The garth's rules, sized from the authored bed grid. Public so the solver
  /// proofs, the renderer and the tests all speak the same geometry.
  AshGardenRules? get ashGardenRules {
    final room = _cloisterRoom;
    if (room == null) return null;
    var cols = 0;
    var rows = 0;
    for (final b in room.vineBeds) {
      if (b.col + 1 > cols) cols = b.col + 1;
      if (b.row + 1 > rows) rows = b.row + 1;
    }
    if (cols * rows != room.vineBeds.length) return null;
    return _ashRulesCache[room.id] ??= AshGardenRules(cols: cols, rows: rows);
  }

  /// Roll THIS RUN'S grooves. The wind starts on a random quarter, and the
  /// assignment is drawn only from those the exhaustive sweep says are
  /// (a) solvable at all, (b) NOT solvable without turning the vane — so the
  /// wind is load-bearing every single run — and (c) inside the difficulty
  /// band. A wiki cannot spoil a garden; the grooves always can.
  void _rollAshGarden() {
    final rules = ashGardenRules;
    final room = _cloisterRoom;
    if (rules == null || room == null) return;
    final rng = Random();
    final wind = rng.nextInt(4);
    final analysis = rules.analyse(wind);
    final pool = <int>[
      for (final entry in analysis.minActions.entries)
        if (entry.value >= _kGardenMinActions &&
            entry.value <= _kGardenMaxActions &&
            !analysis.noTurnSolvable.contains(entry.key))
          entry.key,
    ];
    gardenWindStart = wind;
    gardenWind = wind;
    gardenWindFrom = wind;
    gardenWindSwing = 1.0;
    gardenBoard = 0;
    gardenDemands
      ..clear()
      ..addAll(
        pool.isEmpty
            // Unreachable with the authored 3×2 garth (137 assignments qualify
            // — see the Fire test's sweep). A garth with no qualifying roll
            // still gets a playable one rather than an empty one.
            ? rules.demandsOf(
                analysis.minActions.keys.firstWhere(
                  (k) => (analysis.minActions[k] ?? 0) > 0,
                  orElse: () => 0,
                ),
              )
            : rules.demandsOf(pool[rng.nextInt(pool.length)]),
      );
  }

  /// THE PROOF. Walk the garth's real `grow`/`burn`/turn transitions from the
  /// state the run is actually in and return the shortest plan that leaves
  /// every groove sitting true — or null if there is none. The Fire test plays
  /// the returned plan through the ordinary interaction verbs, so the solver
  /// and the game can never drift apart.
  ({int states, int reachable, int? minActions, List<AshGardenMove>? plan})
  solveAshGarden({
    List<GrooveDemand>? demands,
    int? board,
    int? wind,
    bool allowWindTurns = true,
  }) {
    final rules = ashGardenRules;
    final want = demands ?? gardenDemands;
    if (rules == null || want.length != rules.bedCount) {
      return (states: 0, reachable: 0, minActions: null, plan: null);
    }
    final plan = rules.plan(
      want,
      wind ?? gardenWind,
      board: board ?? gardenBoard,
      allowTurns: allowWindTurns,
    );
    return (
      states: rules.boardCount * 4,
      reachable: rules.analyse(wind ?? gardenWindStart).reachable,
      minActions: plan?.length,
      plan: plan,
    );
  }

  /// NO SOFTLOCKS, STRUCTURALLY: reachable states from which no solution
  /// remains. Must be 0 — growing buries any ruin, so every mess is a detour
  /// and never a wall. (Exhaustive; test-only — do not call per frame.)
  int ashGardenStrandable({List<GrooveDemand>? demands, int? startWind}) {
    final rules = ashGardenRules;
    final want = demands ?? gardenDemands;
    if (rules == null || want.length != rules.bedCount) return 0;
    return rules.strandable(want, startWind ?? gardenWindStart);
  }

  /// What bed [index] currently holds.
  AshBedState bedStateAt(int index) {
    final rules = ashGardenRules;
    if (rules == null || index < 0 || index >= rules.bedCount) {
      return AshBedState.barren;
    }
    return rules.cellAt(gardenBoard, index);
  }

  /// What bed [index]'s groove is cut to receive.
  GrooveDemand grooveDemandAt(int index) =>
      (index >= 0 && index < gardenDemands.length)
      ? gardenDemands[index]
      : GrooveDemand.clean;

  /// True when bed [index] currently sits true for its own groove.
  bool grooveSitsTrue(int index) {
    final rules = ashGardenRules;
    if (rules == null) return false;
    return rules.satisfies(bedStateAt(index)) == grooveDemandAt(index);
  }

  /// How many grooves sit true right now (the GROOVES readout).
  int get gardenGroovesTrue {
    final rules = ashGardenRules;
    if (rules == null) return 0;
    var n = 0;
    for (var i = 0; i < rules.bedCount; i++) {
      if (grooveSitsTrue(i)) n++;
    }
    return n;
  }

  /// Vine maturity at bed [index] (0 shoots … 1 ready to take flame).
  double bedGrowthAt(int index) => (_bedGrowth[index] ?? 0).clamp(0.0, 1.0);

  /// The beds a burn at [index] would dust under the wind as it stands — the
  /// forecast the garth draws, and the same list the burn actually uses.
  List<int> plumeTargetsAt(int index) =>
      ashGardenRules?.plume(index, gardenWind) ?? const [];

  /// The compass letter the crosswind runs toward (readout + prose).
  String get gardenWindLabel =>
      const ['N', 'E', 'S', 'W'][gardenWind & 3];

  /// The unit vector the crosswind runs along, EASED across a quarter turn so
  /// the streaks swing round instead of snapping.
  Offset get gardenWindVector {
    const dirs = [
      Offset(0, -1),
      Offset(1, 0),
      Offset(0, 1),
      Offset(-1, 0),
    ];
    final k = Curves.easeInOutCubic.transform(gardenWindSwing.clamp(0.0, 1.0));
    final from = (gardenWindFrom & 3) * pi / 2;
    var delta = (gardenWind & 3) * pi / 2 - from;
    if (delta > pi) delta -= 2 * pi;
    if (delta < -pi) delta += 2 * pi;
    if (k >= 1.0) return dirs[gardenWind & 3];
    final a = from + delta * k - pi / 2; // 0 rad points north
    return Offset(cos(a), sin(a));
  }

  /// The one source→groove link a tier-2 reading drew out, for the renderer
  /// and the tests.
  ({int source, int groove})? get gardenInsightLink => _gardenLink;

  // ── Update ──────────────────────────────────────────────

  void _resetCathedralState() {
    ritualProgress = 0;
    bellsRung.clear();
    _chainCheckpoints.clear();
    _vesperFlames.clear();
    _bedFx.clear();
    _bedPlume.clear();
    _bedGrowth.clear();
    // The GROOVES are stonework — cut long before this run and rolled once
    // per descent; only the beds worked into them are progress. Death re-lays
    // the soil and puts the wind back where it was found.
    gardenBoard = 0;
    gardenWind = gardenWindStart;
    gardenWindFrom = gardenWindStart;
    gardenWindSwing = 1.0;
    _bellTollFx = 0;
    // The rite ORDER and its evidence persist: they are the cathedral's
    // memory of a rite long finished, not this run's progress. Death re-lays
    // the fires, never the history — so a deduction already made still holds.
    _testimonyFade.clear();
    _testimonyMark = _testimonyMarked ? 1.0 : 0.0;
    // Star 3's decision re-opens with the rite (the bells are cold again).
    vesperRouteId = null;
    vesperCommitted = false;
    _routeSwapT = 1.0;
    _simurghRank = 0;
    _simurghBeat = 0;
    _simurghPillars.clear();
    // choirRevealTier survives: the mural, once read, stays read (knowledge
    // persists across death, like cloud discoveries). Same for the bared
    // epitaph planter — but its growth restarts.
    if (epitaphStage > 1) epitaphStage = 1;
    epitaphFans = 0;
  }

  /// The garth's three eased clocks: vines taking, ash crossing the garden,
  /// and the wind-cross swinging round. Three scalar maps, no allocation and
  /// no geometry per frame (memory: keep the render loop cheap).
  void _updateAshGarden(double dt) {
    if (gardenWindSwing < 1.0) {
      gardenWindSwing = (gardenWindSwing + dt / _kWindSwingSeconds).clamp(
        0.0,
        1.0,
      );
    }
    if (_bedGrowth.isNotEmpty) {
      for (final k in _bedGrowth.keys.toList()) {
        final v = _bedGrowth[k]!;
        if (v < 1.0) {
          _bedGrowth[k] = (v + dt / _kGardenGrowSeconds).clamp(0.0, 1.0);
        }
      }
    }
    if (_bedPlume.isNotEmpty) {
      for (final k in _bedPlume.keys.toList()) {
        final v = _bedPlume[k]! + dt / _kPlumeFlightSeconds;
        if (v >= 1.0) {
          _bedPlume.remove(k);
        } else {
          _bedPlume[k] = v;
        }
      }
    }
  }

  // ── Star 3's decision: which censer run carries the flame ──

  /// The declared censer run in [room] (null until a stand is lit).
  VesperRoute? vesperRouteIn(DungeonRoom room) {
    final id = vesperRouteId;
    if (id == null) return null;
    for (final r in room.vesperRoutes) {
      if (r.id == id) return r;
    }
    return null;
  }

  VesperRoute? get _vesperRoute {
    final id = vesperRouteId;
    if (id == null) return null;
    for (final room in layout.rooms.values) {
      for (final r in room.vesperRoutes) {
        if (r.id == id) return r;
      }
    }
    return null;
  }

  /// The censers [chain] actually hangs on THIS run — the declared route's own
  /// path, or the authored nodes (which are the nave run) before one is
  /// declared. Everything downstream (flame travel, checkpoints, ignition,
  /// rendering, the minimap beacon) reads the chain through here.
  List<Offset> chainNodes(IncenseChain chain) =>
      _vesperRoute?.chainNodes[chain.id] ?? chain.nodes;

  /// Seconds a flame holds per feeding on the declared run.
  double get _flameLife => _kFlameLife * (_vesperRoute?.flameLifeScale ?? 1.0);

  /// True once the vesper has BEGUN — the run is committed for this attempt.
  bool get _vesperUnderway =>
      vesperCommitted || bellsRung.isNotEmpty || _vesperFlames.isNotEmpty;

  void _updateCathedral(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isCathedral) return;
    if (_bellTollFx > 0) _bellTollFx -= dt;
    if (_bedFx.isNotEmpty) {
      _bedFx.updateAll((k, v) => v - dt);
      _bedFx.removeWhere((k, v) => v <= 0);
    }
    _updateAshGarden(dt);
    // ANIMATED STATE: insight's marking blooms, a lit brazier's testimony is
    // eaten by its own fire, and a re-declared censer run swings over. Three
    // scalar eases — no allocation, no per-frame geometry.
    if (_testimonyMarked && _testimonyMark < 1.0) {
      _testimonyMark = (_testimonyMark + dt / _kTestimonyMarkSeconds)
          .clamp(0.0, 1.0);
    }
    if (_testimonyFade.isNotEmpty) {
      for (final k in _testimonyFade.keys.toList()) {
        final v = _testimonyFade[k]! - dt / _kTestimonyFade;
        _testimonyFade[k] = v <= 0 ? 0 : v;
      }
    }
    if (_routeSwapT < 1.0) {
      _routeSwapT = (_routeSwapT + dt / _kRouteSwapSeconds).clamp(0.0, 1.0);
    }
    // Epitaph animation clocks (capped — a fresh session that already owns
    // the maxim skips straight to the settled, fully-lit script).
    final epitaphWon = discoveredClouds.contains(kFireEpitaphEggId);
    if ((epitaphStage >= 1 || epitaphWon) && epitaphWriteT < 30) {
      epitaphWriteT += dt;
    }
    if (epitaphWon && epitaphBlazeT < 30) epitaphBlazeT += dt;
    if (room.incenseChains.isEmpty || hasStar(2)) return;
    // Advance live flames only while their gallery is on screen — the rite
    // is tended, not left to run itself.
    for (final chain in room.incenseChains) {
      final flame = _vesperFlames[chain.id];
      if (flame == null) continue;
      _advanceFlame(room, chain, flame, _kFlameSelfSpeed * dt);
      if (!_vesperFlames.containsKey(chain.id)) continue; // rang the bell
      flame.life -= dt;
      if (flame.life <= 0) {
        _vesperFlames.remove(chain.id);
        final pos = _chainPoint(chain, flame.segment, flame.t);
        _spawnAlchemyBurst(
          pos,
          producedElement: 'Dust',
          reagentElements: const ['Fire'],
          particleCount: 14,
          intensity: 0.7,
        );
        // A starved flame angers the ash far worse than a tended one.
        spawnWispWave(
          element: 'Fire',
          center: pos,
          count: 3,
          unstable: true,
          announce: false,
        );
        _setHint('The vesper flame gutters out — its ash rises in fury', 3.0);
        onChanged();
      }
    }
  }

  /// World position along [chain]: censers, then the bell as the final point.
  Offset _chainPoint(IncenseChain chain, int segment, double t) {
    final nodes = chainNodes(chain);
    final from = nodes[segment.clamp(0, nodes.length - 1)];
    final to = segment + 1 < nodes.length
        ? nodes[segment + 1]
        : chain.bellPosition;
    return Offset.lerp(from, to, t.clamp(0.0, 1.0))!;
  }

  int _chainSegmentCount(IncenseChain chain) => chainNodes(chain).length;

  /// Move a flame [distance] px along its chain, refreshing it at censers and
  /// ringing the bell at the end.
  void _advanceFlame(
    DungeonRoom room,
    IncenseChain chain,
    _VesperFlame flame,
    double distance,
  ) {
    final nodes = chainNodes(chain);
    var remaining = distance;
    while (remaining > 0) {
      final from = nodes[flame.segment.clamp(0, nodes.length - 1)];
      final to = flame.segment + 1 < nodes.length
          ? nodes[flame.segment + 1]
          : chain.bellPosition;
      final segLen = (to - from).distance;
      if (segLen <= 0.01) {
        flame.t = 1;
      } else {
        flame.t += remaining / segLen;
      }
      if (flame.t < 1) return;
      // Crossed to the next point.
      remaining = (flame.t - 1) * segLen;
      flame.t = 0;
      flame.segment++;
      if (flame.segment >= _chainSegmentCount(chain)) {
        _ringBell(room, chain);
        return;
      }
      // A censer feeds the flame and banks the re-ignite checkpoint.
      _chainCheckpoints[chain.id] = max(
        _chainCheckpoints[chain.id] ?? 0,
        flame.segment,
      );
      flame.life = max(flame.life, _flameLife * 0.7);
      _spawnAlchemyBurst(
        nodes[flame.segment],
        producedElement: 'Fire',
        particleCount: 8,
        intensity: 0.5,
      );
    }
  }

  void _ringBell(DungeonRoom room, IncenseChain chain) {
    _vesperFlames.remove(chain.id);
    if (!bellsRung.add(chain.id)) return;
    _bellTollFx = 2.2;
    _spawnAlchemyBurst(
      chain.bellPosition,
      producedElement: 'Fire',
      reagentElements: const ['Air'],
      particleCount: 26,
      intensity: 1.2,
    );
    if (bellsRung.length >= room.incenseChains.length) {
      guardianAwake = true;
      guardianHp = PlanetDungeonGame.maxGuardianHp;
      _setHint(
        'The third bell tolls — black flame pours toward the sanctum',
        4.2,
      );
      spawnWispWave(
        element: 'Fire',
        center: room.bounds.center,
        count: 3,
        unstable: true,
        announce: false,
      );
    } else {
      // The tally is STATE — it lives in the BELLS readout (§5.6).
      _setHint('An ember bell tolls through the gallery', 3.2);
    }
    onChanged();
  }

  /// Live flame position for [chainId] (null = no flame). Public for the
  /// minimap beacon and the headless full-run test.
  Offset? vesperFlamePosition(String chainId) {
    for (final room in layout.rooms.values) {
      for (final chain in room.incenseChains) {
        if (chain.id != chainId) continue;
        final flame = _vesperFlames[chainId];
        if (flame == null) return null;
        return _chainPoint(chain, flame.segment, flame.t);
      }
    }
    return null;
  }

  /// The censer where a chain's next ignition takes (its checkpoint).
  Offset chainIgnitionPoint(IncenseChain chain) {
    final nodes = chainNodes(chain);
    return nodes[(_chainCheckpoints[chain.id] ?? 0).clamp(0, nodes.length - 1)];
  }

  // ── Utility interactions ────────────────────────────────

  bool _tryCathedral(DungeonCreature a) {
    if (!_isCathedral) return false;
    final room = currentRoom;
    if (_tryHearthOrBrazier(a, room)) return true;
    if (_tryAshGarden(a, room)) return true;
    if (_tryVesper(a, room)) return true;
    if (_tryEmberEpitaph(a, room)) return true;
    if (_tryNaveCommune(a, room)) return true;
    return false;
  }

  /// The Ember Epitaph easter egg (scriptorium). Entirely WORDLESS: stage 0
  /// gives no response, and every step answers with the world (bursts, the
  /// growing flame, the burning script) — never a hint popup. Only an actual
  /// transition consumes the action; anything else falls through to the
  /// creature's normal ability.
  bool _tryEmberEpitaph(DungeonCreature a, DungeonRoom room) {
    if (room.id != 'scriptorium') return false;
    if (discoveredClouds.contains(kFireEpitaphEggId)) return false;
    if ((a.position - kEmberEpitaphPlanter).distance > 52) return false;
    // The garden only exists once the writing has settled.
    if (epitaphStage >= 1 && epitaphWriteT < _epitaphWriteDuration) {
      return false;
    }
    final element = a.member.element;
    if (epitaphStage == 1 && element == 'Plant') {
      epitaphStage = 2;
      _spawnAlchemyBurst(
        kEmberEpitaphPlanter,
        producedElement: 'Plant',
        particleCount: 14,
        intensity: 0.7,
      );
      return true;
    }
    if (epitaphStage == 2 && element == 'Fire') {
      epitaphStage = 3;
      epitaphFans = 0;
      _spawnAlchemyBurst(
        kEmberEpitaphPlanter,
        producedElement: 'Fire',
        reagentElements: const ['Plant'],
        particleCount: 16,
        intensity: 0.8,
      );
      return true;
    }
    if (epitaphStage == 3 && element == 'Air') {
      epitaphFans++;
      _spawnAlchemyBurst(
        kEmberEpitaphPlanter,
        producedElement: 'Fire',
        reagentElements: const ['Air'],
        particleCount: 12 + epitaphFans * 8,
        intensity: 0.7 + epitaphFans * 0.25,
      );
      if (epitaphFans >= 3) {
        epitaphBlazeT = 0; // the burn-front starts its sweep
        _discoverCloud(kFireEpitaphEggId); // screen pays the 20 gold
      }
      return true;
    }
    return false;
  }

  /// Seconds until the quill finishes the last line.
  double get _epitaphWriteDuration =>
      (kFireEpitaphLines.length - 1) * _kEpitaphWriteStagger +
      _kEpitaphWritePerLine;

  /// The narthex hearth (entry rite) and the choir's ritual braziers.
  bool _tryHearthOrBrazier(DungeonCreature a, DungeonRoom room) {
    if (room.braziers.isEmpty) return false;
    RitualBrazier? nearest;
    var nearestIndex = -1;
    var bestDist = 46.0;
    for (var i = 0; i < room.braziers.length; i++) {
      final b = room.braziers[i];
      final d = (a.position - b.position).distance;
      if (d < bestDist) {
        bestDist = d;
        nearest = b;
        nearestIndex = i;
      }
    }
    if (nearest == null) return false;

    // Standalone hearth (no star index) = the entry rite.
    if (room.brazierStarIndex == null) {
      if (entryDoorRevealed) {
        _setHint('The great hearth burns steady');
        return true;
      }
      if (a.member.element != 'Fire') {
        _setHint('The hearth is stone-cold — only flame wakes it');
        return true;
      }
      entryDoorRevealed = true;
      _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist
      final doorCenter = room.doors.isNotEmpty
          ? room.doors.first.rect.center
          : a.position;
      _setHint('Flame takes the great hearth — the inner doors grind apart');
      _spawnAlchemyBurst(
        nearest.position,
        producedElement: 'Fire',
        particleCount: 32,
        intensity: 1.3,
      );
      _spawnAlchemyBurst(
        doorCenter,
        producedElement: 'Fire',
        particleCount: 24,
        intensity: 1.1,
      );
      return true;
    }

    // The choir rite — against THIS RUN'S rolled order, not the authored one.
    final star = room.brazierStarIndex!;
    if (hasStar(star)) return false;
    final rank = riteRankOf(nearestIndex);
    if (rank < ritualProgress) {
      _setHint('This brazier already burns its remembered turn');
      return true;
    }
    if (a.member.element != 'Fire') {
      // §5.6 BLOCKED: one clause, element-first, on the failed attempt.
      _setBlockedHint('Cold ritual iron — the braziers answer Fire alone');
      return true;
    }
    if (rank == ritualProgress) {
      ritualProgress++;
      // The rite's own fire eats this brazier's testimony (eased, never a pop).
      _testimonyFade[nearestIndex] = 1.0;
      _spawnAlchemyBurst(
        nearest.position,
        producedElement: 'Fire',
        reagentElements: [a.member.element],
        particleCount: 20,
        intensity: 1.0,
      );
      if (ritualProgress >= room.braziers.length) {
        earnStar(star); // the spec's announcement covers the copy
      } else {
        // The count is STATE — it lives in the progress readout (§5.6);
        // the capsule keeps only the rite's answer.
        _setHint('The flame takes its remembered turn');
      }
      onChanged();
    } else {
      ritualProgress = 0;
      // The snuffed rite lays its evidence back down — the wax and soot the
      // fires had begun to eat are legible again, and the deduction stands.
      _testimonyFade.clear();
      _spawnAlchemyBurst(
        nearest.position,
        producedElement: 'Dust',
        reagentElements: const ['Fire'],
        unstable: true,
        particleCount: 22,
      );
      spawnWispWave(
        element: 'Fire',
        center: nearest.position,
        count: 2,
        announce: false,
      );
      _setHint(
        'The fire remembers another order — every brazier snuffs out',
        3.2,
      );
    }
    return true;
  }

  /// THE ASH GARDEN (Star 2) — "the wind carries the reaction". Three verbs,
  /// all element-only at full power: Plant grows a bed, Fire burns it (and the
  /// reaction's ash rides the crosswind onto the beds behind), Air turns the
  /// garth's wind-cross a quarter. The ORDER is never given — it is derived
  /// from the wind and what the grooves are cut for.
  bool _tryAshGarden(DungeonCreature a, DungeonRoom room) {
    final star = room.vineStarIndex;
    final rules = ashGardenRules;
    if (room.vineBeds.isEmpty || star == null || rules == null) return false;
    if (hasStar(star)) return false;
    final element = a.member.element;

    // The wind-cross on the dry fountain, at the heart of the garth.
    final vane = room.windVane;
    if (vane != null && (a.position - vane).distance <= _kVaneReach) {
      if (element != 'Air') {
        // §5.6 BLOCKED: one clause, element-first, never a method.
        _setBlockedHint('Dead iron — the cross turns on Air alone');
        return true;
      }
      // ELEMENT-ONLY, exactly as the vesper gust is (§4 / the planet's own
      // precedent): every Air family swings the cross the same quarter.
      _turnGardenWind(vane);
      return true;
    }

    var index = -1;
    var bestDist = _kBedReach;
    for (var i = 0; i < room.vineBeds.length; i++) {
      final d = (a.position - room.vineBeds[i].position).distance;
      if (d < bestDist) {
        bestDist = d;
        index = i;
      }
    }
    if (index < 0) return false;
    final bed = room.vineBeds[index];
    final state = bedStateAt(index);

    if (element == 'Plant') {
      final grown = rules.grow(gardenBoard, index);
      if (grown == null) {
        _setBlockedHint('The vines are already thick');
        return true;
      }
      // The regrowth BURIES whatever lay here — ash, brand or ruin alike.
      // That is the recovery path, and its price is the time the shoots take.
      final buried = state != AshBedState.barren;
      gardenBoard = grown;
      _bedGrowth[index] = 0;
      _bedFx[index] = 1.2;
      _spawnAlchemyBurst(
        bed.position,
        producedElement: 'Plant',
        reagentElements: [element],
        particleCount: 16,
        intensity: 0.8,
      );
      _setHint(
        buried
            ? 'Green closes over the old bed and buries it'
            : 'Vines surge across the bed in one green breath',
      );
      _afterGardenMove(star);
      return true;
    }

    if (element == 'Fire') {
      if (state != AshBedState.green) {
        _setBlockedHint('Bare ground takes no flame');
        return true;
      }
      if (bedGrowthAt(index) < 1.0) {
        _setBlockedHint('The shoots are still too green to catch');
        return true;
      }
      final targets = plumeTargetsAt(index);
      // ONE transition, through the same pure rule the solver walks.
      gardenBoard = rules.burn(gardenBoard, index, gardenWind)!;
      _bedGrowth.remove(index);
      _bedFx[index] = 1.4;
      for (final t in targets) {
        _bedPlume[t] = 0.0;
      }
      // The alchemy is unchanged: Plant + Fire → Dust. Only now the Dust GOES
      // somewhere.
      _spawnAlchemyBurst(
        bed.position,
        producedElement: 'Dust',
        reagentElements: const ['Plant', 'Fire'],
        particleCount: 24,
        intensity: 1.05,
      );
      for (final t in targets) {
        _spawnAlchemyBurst(
          room.vineBeds[t].position,
          producedElement: 'Dust',
          particleCount: 10,
          intensity: 0.6,
        );
      }
      // The consequence layer: every burning bed breathes out cinders, and
      // the garden grows angrier the closer it is to done.
      final settled = gardenGroovesTrue;
      spawnWispWave(
        element: 'Fire',
        center: bed.position,
        count: 3,
        unstable: settled >= 3,
        announce: false,
      );
      if (!_afterGardenMove(star)) {
        _setHint(
          targets.isEmpty
              ? 'The bed burns down to a black brand — its ash goes over the '
                    'wall'
              : 'The bed burns, and the wind takes its ash across the garth',
          3.2,
        );
      }
      return true;
    }

    // §5.6 BLOCKED: one short clause naming what is missing, never a method.
    _setBlockedHint('This bed answers Plant, and Fire');
    return true;
  }

  /// Swing the wind-cross one quarter (eased, never a snap).
  void _turnGardenWind(Offset vane) {
    gardenWindFrom = gardenWind;
    gardenWind = (gardenWind + 1) & 3;
    gardenWindSwing = 0;
    _spawnAlchemyBurst(
      vane,
      producedElement: 'Air',
      particleCount: 14,
      intensity: 0.7,
    );
    _setHint('The cross grinds round, and the garth\'s air turns with it');
    onChanged();
  }

  /// After any garden move: bank the star the moment every groove sits true.
  /// Returns true when the star landed (the caller then stays quiet — the
  /// star spec's announcement covers it).
  bool _afterGardenMove(int star) {
    final rules = ashGardenRules;
    if (rules != null &&
        gardenDemands.length == rules.bedCount &&
        rules.solved(gardenBoard, gardenDemands)) {
      earnStar(star);
      onChanged();
      return true;
    }
    onChanged();
    return false;
  }

  /// The two censer stands (Star 3's decision). A Fire creature lights one to
  /// declare the run; the choice stays open — walk both, weigh both — until
  /// the first censer of the vesper takes flame, and then it is COMMITTED.
  bool _tryVesperStand(DungeonCreature a, DungeonRoom room) {
    if (room.vesperRoutes.isEmpty || hasStar(2)) return false;
    for (final route in room.vesperRoutes) {
      if ((a.position - route.standPosition).distance > 50) continue;
      if (a.member.element != 'Fire') {
        _setBlockedHint('The stand answers only Fire');
        return true;
      }
      if (vesperRouteId == route.id) {
        _setHint('This run already carries the vesper');
        return true;
      }
      if (_vesperUnderway) {
        _setBlockedHint('The vesper has begun — this run is committed');
        return true;
      }
      vesperRouteId = route.id;
      _routeSwapT = 0;
      _chainCheckpoints.clear(); // a new run starts at its own first censer
      _spawnAlchemyBurst(
        route.standPosition,
        producedElement: 'Fire',
        particleCount: 18,
        intensity: 0.9,
      );
      _setHint('The censers swing round — the vesper will go by the '
          '${route.name.toLowerCase()}');
      onChanged();
      return true;
    }
    return false;
  }

  /// The bell gallery's vesper rite (Star 3): declare the run, ignite, gust.
  bool _tryVesper(DungeonCreature a, DungeonRoom room) {
    if (room.incenseChains.isEmpty || hasStar(2)) return false;
    if (_tryVesperStand(a, room)) return true;
    final element = a.member.element;

    // Fire: light (or re-light) a chain at its checkpoint censer.
    if (element == 'Fire') {
      for (final chain in room.incenseChains) {
        if (bellsRung.contains(chain.id)) continue;
        if (_vesperFlames.containsKey(chain.id)) continue;
        final ignition = chainIgnitionPoint(chain);
        if ((a.position - ignition).distance > 46) continue;
        if (!guardianRiteUnlocked) {
          _setBlockedHint(
            'The censer swallows the flame — the vesper waits on the '
            '${layout.starName(0)} and ${layout.starName(1)}',
          );
          return true;
        }
        final route = vesperRouteIn(room);
        if (route == null && room.vesperRoutes.isNotEmpty) {
          _setBlockedHint('No run is declared — the censers hang idle');
          return true;
        }
        // The rite has begun: the declared run is COMMITTED for this attempt.
        vesperCommitted = true;
        final checkpoint = _chainCheckpoints[chain.id] ?? 0;
        _vesperFlames[chain.id] = _VesperFlame(
          segment: checkpoint.clamp(0, chainNodes(chain).length - 1),
          t: 0,
          life: _flameLife,
        );
        _spawnAlchemyBurst(
          ignition,
          producedElement: 'Fire',
          particleCount: 16,
          intensity: 0.9,
        );
        // The vesper flame draws the ash the moment it lights — the rite is
        // tended under attack, and the ash-storm run draws it heavier.
        spawnWispWave(
          element: 'Fire',
          center: ignition,
          count: route?.igniteWisps ?? 2,
          unstable: route?.unstableWisps ?? false,
          announce: false,
        );
        _setHint(
          checkpoint > 0
              ? 'The flame rekindles — and the ash stirs with it'
              : 'The first censer takes the flame, and the ash rises to '
                    'smother it',
          3.0,
        );
        onChanged();
        return true;
      }
    }

    // Air: gust a live flame onward. ELEMENT-ONLY — every Air carries it the
    // same distance; Speed alone decides how far.
    if (element == 'Air') {
      for (final chain in room.incenseChains) {
        final flame = _vesperFlames[chain.id];
        if (flame == null) continue;
        final pos = _chainPoint(chain, flame.segment, flame.t);
        if ((a.position - pos).distance > _kGustRadius) continue;
        final speedT = normStat(a.member.statSpeed);
        final push = 120.0 + 70.0 * speedT;
        flame.life = max(flame.life, _flameLife);
        _spawnAlchemyBurst(
          pos,
          producedElement: 'Air',
          reagentElements: const ['Fire'],
          particleCount: 12,
          intensity: 0.7,
        );
        _setHint('The gust bears the flame down the chain');
        _advanceFlame(room, chain, flame, push);
        return true;
      }
    }

    // Near a chain but holding neither element — one clause, no method.
    for (final chain in room.incenseChains) {
      if (bellsRung.contains(chain.id)) continue;
      final flame = _vesperFlames[chain.id];
      final anchor = flame != null
          ? _chainPoint(chain, flame.segment, flame.t)
          : chainIgnitionPoint(chain);
      if ((a.position - anchor).distance <= _kGustRadius) {
        _setBlockedHint('The censers answer Fire, the flame rides on Air');
        return true;
      }
    }
    return false;
  }

  /// The 3-star secret: commune beneath the rose window.
  bool _tryNaveCommune(DungeonCreature a, DungeonRoom room) {
    if (room.id != 'nave' || starsEarnedCount < 3) return false;
    if ((a.position - room.bounds.center).distance >= 34) return false;
    _setHint(
      'The rose window stills. Before the ash, the Simurgh sang the first '
      'dawn into these vaults — the cathedral remembers, and now it rests.',
      7.5,
    );
    _spawnAlchemyBurst(
      room.bounds.center,
      producedElement: 'Light',
      reagentElements: const ['Fire'],
      particleCount: 20,
      intensity: 0.8,
    );
    return true;
  }

  // ── Simurgh re-lights the rite (§7 guardian retrofit) ───

  /// Where the sanctum's phantom braziers stand: the CHOIR'S OWN arrangement,
  /// scaled in around the roost. The bullet pattern is the rite, laid out the
  /// way the player already learned it.
  List<Offset> simurghTelegraphSpots(DungeonRoom room) {
    final choir = _choirRoom;
    if (choir == null) return const [];
    final c = room.bounds.center;
    return [
      for (final b in choir.braziers)
        c + (b.position - choir.bounds.center) * 0.62,
    ];
  }

  /// The live telegraph, read-only for tests/diagnostics: rank → 0..1, where
  /// values below [_kTelegraphWindup] are the readable flare and beyond it the
  /// pillar is actually burning.
  Map<int, double> get simurghPillars => Map.unmodifiable(_simurghPillars);

  /// Called from the shared guardian loop (one `_isCathedral`-guarded line in
  /// `_updateAltar`). While the Simurgh STRIKES it walks this run's rolled
  /// rite, re-lighting one phantom brazier per beat: a flare you can read, then
  /// a pillar of flame where it stood. The lull silences the whole ring and
  /// rewinds the rite to its first fire, so the pattern always reads from the
  /// top. Raids are exempt — the generated arena has no choir to remember.
  void _applySimurghTelegraph(
    DungeonCreature a,
    DungeonRoom room,
    double dt,
  ) {
    final g = room.guardian;
    if (g == null || isRaid || hasStar(g.starIndex)) return;
    final spots = simurghTelegraphSpots(room);
    if (spots.isEmpty) return;

    if (guardianVulnerable) {
      // The lull: the ring gutters out and the rite rewinds.
      if (_simurghPillars.isNotEmpty) _simurghPillars.clear();
      _simurghRank = 0;
      _simurghBeat = 0;
      return;
    }

    // Advance every live pillar; the finished ones fall dark.
    if (_simurghPillars.isNotEmpty) {
      for (final rank in _simurghPillars.keys.toList()) {
        final v = _simurghPillars[rank]! + dt / _kTelegraphBeat;
        if (v >= 1.0) {
          _simurghPillars.remove(rank);
        } else {
          _simurghPillars[rank] = v;
        }
      }
    }

    // The next fire in the remembered order takes its turn.
    _simurghBeat -= dt;
    if (_simurghBeat <= 0) {
      _simurghBeat = _kTelegraphBeat;
      _simurghPillars[_simurghRank] = 0.0;
      _simurghRank = (_simurghRank + 1) % spots.length;
    }

    // A pillar burns only AFTER its flare — the wind-up is the fair warning.
    for (final entry in _simurghPillars.entries) {
      if (entry.value < _kTelegraphWindup) continue;
      final idx = riteBrazierAt(entry.key);
      if (idx < 0 || idx >= spots.length) continue;
      if ((a.position - spots[idx]).distance <= _kTelegraphRadius) {
        a.hp = max(0, a.hp - _kTelegraphDps * progressDmgMul * dt);
      }
    }
  }

  // ── Mask insight ────────────────────────────────────────

  void _cathedralReveal(DungeonCreature a, DungeonRoom room) {
    revealFlash = 0.6;
    revealTier = revealHintTier(a.member.statIntelligence);
    switch (room.id) {
      case 'scriptorium':
        // NO hint popups in this room — the mural answers visually: the
        // brazier glyphs draw themselves into the panel per insight tier,
        // and the epitaph cipher writes itself in (and bares the garden).
        choirRevealTier = max(choirRevealTier, revealTier);
        if (epitaphStage == 0 &&
            !discoveredClouds.contains(kFireEpitaphEggId)) {
          epitaphStage = 1;
          epitaphWriteT = 0;
        }
        return;
      case 'choir':
        if (hasStar(room.brazierStarIndex ?? 0)) {
          _setHint('The braziers keep their vigil — the rite is done');
          return;
        }
        // THE FORENSIC RITE (§6.1): insight ASSISTS, it never answers. t0
        // names the shape; t1 MARKS the readable evidence (and says what the
        // three marks mean); t2 additionally annotates ONE deduced link on the
        // floor. The order itself is never spoken, at any tier.
        _testimonyMarked = true;
        if (revealTier >= 2) {
          _testimonyLinkRank = _pickTestimonyLink();
        }
        _setHint(
          revealTier >= 2
              ? 'Wax, soot and drift all read now — and one step of the rite '
                    'draws itself on the floor'
              : revealTier >= 1
              ? 'The evidence stands out: lowest wax burned longest, soot '
                    'leans off whatever was already alight, ash piles downwind'
              : 'The iron still wears the last rite — wax, soot and ash '
                    'have all kept their share of it',
          4.4,
        );
        return;
      case 'cloister':
        if (hasStar(room.vineStarIndex ?? 1)) {
          _setHint('Every groove sits true — the garth is at peace', 3.4);
          return;
        }
        // THE GARTH (§6.1 rework): insight ASSISTS, it never plans. t0 names
        // the shape; t1 teaches the METHOD (what the three cuts want, and
        // that a burn's ash rides the wind onto the beds behind); t2 draws ONE
        // source→groove link out of the shortest plan — a check on a plan in
        // progress, never the plan.
        if (revealTier >= 2) _gardenLink ??= _pickGardenLink();
        _setHint(
          revealTier >= 2
              ? 'The cuts read now — and one groove shows which bed\'s burning '
                    'must feed it'
              : revealTier >= 1
              ? 'Three cuts, three gifts: the shallow bowls want the drift, the '
                    'deep brands want their own fire, and the swept rings want '
                    'nothing at all — and every burn sends its ash downwind'
              : 'Each groove is cut to a different shape, and the garth is '
                    'open to the sky',
          4.4,
        );
        return;
      case 'vestry':
        _setHint(
          'The charred fresco completes — flame walks the hanging chains, '
          'and the wind bears it censer to censer',
          4.0,
        );
        return;
      case 'bell_gallery':
        if (bellsRung.length >= room.incenseChains.length) {
          _setHint('The bells have all spoken', 3.8);
          return;
        }
        // The DECISION, weighed — the method behind the two stands, tiered.
        final declared = vesperRouteIn(room);
        _setHint(
          declared == null
              ? (revealTier >= 1
                    ? 'Two runs to the same three bells: the nave is short and '
                          'the flame starves in its ash-storm; the cloister is '
                          'long and calm, two more censers to keep alight'
                    : 'Two censer runs reach the bells, and they are not the '
                          'same walk')
              : (revealTier >= 1
                    ? 'Light a censer, then gust the flame on before it '
                          'starves — every censer you pass re-lights from there'
                    : 'The censers answer flame, and the flame answers wind'),
          4.2,
        );
        return;
      case 'narthex':
        _setHint(
          entryDoorRevealed
              ? 'The hearth-soot has burned clean'
              : 'The hearth\'s soot spells a single word: burn',
        );
        return;
      case 'nave':
        _setHint(
          'Three lights watch over the chancel gate — ember, ash, and pyre',
          3.6,
        );
        return;
      case 'high_altar':
        _setHint('The black flame defers to the bells', 3.2);
        return;
      case 'sanctum':
        _setHint(
          guardianAwake
              ? 'The Simurgh\'s rage thins in waves — strike in the lull'
              : 'An empty roost above the altar — the bells will fill it',
          3.6,
        );
        return;
    }
    _setHint('Nothing hidden stirs here');
  }

  /// The ONE source→groove link a tier-2 reading draws out of the garth: the
  /// first burn in the shortest plan that actually feeds a drift-groove. STICKY
  /// (see [_gardenLink]) — re-reading must never walk the player through the
  /// whole plan one burn at a time.
  ({int source, int groove})? _pickGardenLink() {
    final rules = ashGardenRules;
    if (rules == null) return null;
    final plan = solveAshGarden().plan;
    if (plan == null) return null;
    var board = gardenBoard;
    var wind = gardenWind;
    for (final move in plan) {
      switch (move.verb) {
        case AshGardenVerb.turnWind:
          wind = (wind + 1) & 3;
        case AshGardenVerb.grow:
          board = rules.grow(board, move.bed) ?? board;
        case AshGardenVerb.burn:
          for (final t in rules.plume(move.bed, wind)) {
            if (grooveDemandAt(t) == GrooveDemand.ash && !grooveSitsTrue(t)) {
              return (source: move.bed, groove: t);
            }
          }
          board = rules.burn(board, move.bed, wind) ?? board;
      }
    }
    return null;
  }

  /// The ONE link a tier-2 reading draws out (rank k → k+1). Deterministic per
  /// run and STICKY: re-reading must never walk the player through link after
  /// link until the whole rite is spent. Deliberately a middle step — a check
  /// on a deduction in progress, not the thread-end that unravels it.
  int _pickTestimonyLink() {
    final held = _testimonyLinkRank;
    if (held != null) return held;
    final n = riteOrder.length;
    if (n < 2) return 0;
    final pick = 1 + (riteOrder.first * 7 + riteOrder.last) % (n - 2).clamp(1, n);
    return pick.clamp(1, n - 2);
  }

  // ── Ambient hints / objectives / mood ───────────────────

  /// Fire's progress readout — STATE, glanceable beside the star tracker,
  /// never a sentence that fades (§5.6 "state leaves the capsule"). The rite's
  /// braziers, the garden's sigils, and the vesper's declared run + bells.
  DungeonProgressReadout? get _cathedralProgressReadout {
    final room = currentRoom;
    // S1 — the rite, brazier by brazier.
    final star = room.brazierStarIndex;
    if (star != null && !hasStar(star) && room.braziers.isNotEmpty) {
      return DungeonProgressReadout(
        label: 'BRAZIERS',
        value: '$ritualProgress/${room.braziers.length}',
        fraction: ritualProgress / room.braziers.length,
      );
    }
    // S2 — NO READOUT. A groove that sits true catches light and burns in its
    // own groove (see _drawVineBeds), and the wind is already legible from the
    // vane and the soot running across the garth. Counting bared grooves in a
    // badge made the player read a number instead of the garden (playtest:
    // "the beds should really glow and aflame when its correct, visually, not
    // number counter badges").
    // S3 — the declared run first (the decision is state too), then the bells.
    if (room.incenseChains.isNotEmpty && !hasStar(2)) {
      final declared = vesperRouteIn(room);
      if (declared == null && room.vesperRoutes.isNotEmpty) {
        return const DungeonProgressReadout(label: 'VESPER', value: 'UNSET');
      }
      final total = room.incenseChains.length;
      return DungeonProgressReadout(
        label: declared == null ? 'BELLS' : 'BELLS · ${declared.name}',
        value: '${bellsRung.length}/$total',
        fraction: bellsRung.length / total,
      );
    }
    return null;
  }

  void _cathedralAmbientHint(DungeonCreature a, DungeonRoom room) {
    // Braziers (hearth + choir).
    for (final b in room.braziers) {
      if ((a.position - b.position).distance > 64) continue;
      if (room.brazierStarIndex == null) {
        if (!entryDoorRevealed) {
          _setAmbientHint(
            a.member.element == 'Fire'
                ? 'The cold hearth leans toward your flame'
                : 'The great hearth lies cold under old ash',
          );
        }
        return;
      }
      if (hasStar(room.brazierStarIndex!)) return;
      // AMBIENT = atmosphere only (§5.6): the iron's age and its old dirt,
      // never what the dirt MEANS. That reading is the puzzle.
      _setAmbientHint('Old wax has run down the iron and set there');
      return;
    }
    // The garth. AMBIENT = atmosphere only (§5.6): the open sky and the state
    // of the soil, never what a groove wants or where the ash will go — that
    // reading is the puzzle, and the stone and the wind both show it in-world.
    if (room.vineStarIndex != null && !hasStar(room.vineStarIndex!)) {
      final vane = room.windVane;
      if (vane != null && (a.position - vane).distance <= 76) {
        _setAmbientHint('The old wind-cross creaks on its pin');
        return;
      }
      for (var i = 0; i < room.vineBeds.length; i++) {
        if ((a.position - room.vineBeds[i].position).distance > 64) continue;
        _setAmbientHint(switch (bedStateAt(i)) {
          AshBedState.barren => 'A scorched bed, bare to the soot',
          AshBedState.green => 'The vines crowd thick over the bed',
          AshBedState.ash => 'Fine pale ash lies banked across the soil',
          AshBedState.scorch => 'The bed is burned down to a black brand',
          AshBedState.spoiled => 'Ash and char lie muddled together here',
        });
        return;
      }
    }
    // Vesper chains — and the two stands the run is declared at.
    if (room.incenseChains.isNotEmpty && !hasStar(2)) {
      for (final route in room.vesperRoutes) {
        if ((a.position - route.standPosition).distance > 62) continue;
        _setAmbientHint('A stand of cold censers, waiting to be swung out');
        return;
      }
      for (final chain in room.incenseChains) {
        final flame = _vesperFlames[chain.id];
        if (flame != null) {
          final pos = _chainPoint(chain, flame.segment, flame.t);
          if ((a.position - pos).distance <= 95) {
            _setAmbientHint('The flame gutters low between censers');
            return;
          }
          continue;
        }
        if (bellsRung.contains(chain.id)) continue;
        if ((a.position - chainIgnitionPoint(chain)).distance <= 60) {
          _setAmbientHint('A cold censer, dark with old incense');
          return;
        }
        if ((a.position - chain.bellPosition).distance <= 60) {
          _setAmbientHint('An ember bell hangs silent');
          return;
        }
      }
    }
  }

  String? _cathedralObjectiveHint(DungeonRoom room) {
    switch (room.id) {
      case 'narthex':
        return entryDoorRevealed
            ? null
            : 'Narthex — the great hearth is cold; flame wakes the way in';
      case 'scriptorium':
        return hasStar(0)
            ? null
            : 'Scriptorium — the soot mural keeps two fires of the old rite';
      case 'choir':
        // WHAT, never HOW (§5.6): the rite's goal only. How to READ the
        // braziers is earned through Mask insight, or found by looking.
        return hasStar(0)
            ? null
            : 'Choir — six braziers, and one order the cathedral still '
                  'remembers';
      case 'cloister':
        // WHAT, never HOW (§5.6): the wind, the grooves and the order they
        // imply are Mask-insight content (_cathedralReveal) — and legible in
        // the stone for anyone patient — never room-entry copy.
        return hasStar(room.vineStarIndex ?? 1)
            ? null
            : 'Cloister — six grooves cut in the garth, and a sky that will '
                  'not sit still';
      case 'vestry':
        return hasStar(2)
            ? null
            : 'Vestry — a charred fresco diagrams the vesper ahead';
      case 'bell_gallery':
        if (hasStar(2)) return null;
        return vesperRouteId == null && room.vesperRoutes.isNotEmpty
            ? 'Bell Gallery — two censer runs, three silent bells; one run '
                  'carries the vesper'
            : 'Bell Gallery — three bells, and a flame that will not keep';
      case 'high_altar':
        return hasStar(2)
            ? null
            : 'High Altar — the black flame waits on the bells';
      case 'sanctum':
        return guardianAwake
            ? 'Sanctum — the Simurgh descends'
            : 'Sanctum — an empty roost; the bells have not rung';
    }
    return null;
  }

  double get _cathedralMoodTarget {
    return switch (currentRoomId) {
      'narthex' => entryDoorRevealed ? 0.55 : 0.40,
      'nave' => 0.52,
      'scriptorium' => 0.46,
      'choir' => 0.50 + ritualProgress * 0.05,
      'cloister' => 0.60,
      'reliquary' => 0.55,
      'vestry' => 0.34,
      'bell_gallery' => 0.30 + bellsRung.length * 0.05,
      'high_altar' => 0.26,
      'sanctum' => guardianAwake ? 0.18 : 0.24,
      _ => 0.5,
    };
  }

  // ── Render: screen-space atmosphere ─────────────────────

  /// Warm gradient fallback when the Fire shader is unavailable.
  void _drawCathedralFallbackSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          const [
            Color(0xFF120A07), // soot vault
            Color(0xFF2A130C), // ember dusk
            Color(0xFF4A2410), // hearth-light horizon
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
  }

  /// Ambient embers: a handful of slow sparks rising on staggered loops —
  /// the cathedral's air, visible in every chamber. 4 glow blits per frame.
  void _drawEmberDrift(Canvas canvas, Size vp) {
    if (!_fx.ready) return;
    for (var i = 0; i < 4; i++) {
      final speed = 26.0 + i * 9;
      final span = vp.height + 120;
      final travel = ((_time * speed + i * 311) % span);
      final y = vp.height + 40 - travel;
      final x =
          vp.width * (0.16 + 0.22 * i) +
          sin(_time * (0.8 + i * 0.23) + i * 2.1) * 30;
      final fade = (travel / span).clamp(0.0, 1.0);
      final alpha = (0.26 * (1 - fade) + 0.04).clamp(0.0, 0.3);
      drawGlow(
        canvas,
        _fx.mote!,
        Offset(x, y),
        3.4 + i * 0.8,
        Color.lerp(
          const Color(0xFFFFB46B),
          const Color(0xFF8A5A48),
          fade,
        )!.withValues(alpha: alpha),
      );
    }
  }

  // ── Render: world-space ─────────────────────────────────

  /// Cathedral stone flooring for plain rooms — replaces the Air island.
  void _renderCathedralFloor(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final rr = RRect.fromRectAndRadius(b.deflate(8), const Radius.circular(26));
    // TRANSLUCENT like the Air islands (alpha ≈ 0.5–0.6): the elemental
    // shader atmosphere must glow through the stone, never be painted over.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, [
          const Color(0xFF1B130E).withValues(alpha: 0.52),
          const Color(0xFF100B08).withValues(alpha: 0.60),
        ]),
    );
    // Flagstone seams — sparse grid, barely-there.
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF4A382C).withValues(alpha: 0.10);
    for (var x = b.left + 90; x < b.right - 20; x += 110) {
      canvas.drawLine(Offset(x, b.top + 18), Offset(x, b.bottom - 18), seam);
    }
    for (var y = b.top + 90; y < b.bottom - 20; y += 110) {
      canvas.drawLine(Offset(b.left + 18, y), Offset(b.right - 18, y), seam);
    }
    // The processional runner: a dark crimson carpet down the long axis.
    final horizontal = b.width >= b.height;
    final runner = horizontal
        ? Rect.fromCenter(center: b.center, width: b.width - 90, height: 86)
        : Rect.fromCenter(center: b.center, width: 86, height: b.height - 90);
    final runnerRR = RRect.fromRectAndRadius(runner, const Radius.circular(8));
    canvas.drawRRect(
      runnerRR,
      Paint()..color = const Color(0xFF541A14).withValues(alpha: 0.30),
    );
    canvas.drawRRect(
      runnerRR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFC4A35A).withValues(alpha: 0.22),
    );
    // Ember veins smouldering in two corners.
    final vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFF8A50).withValues(
        alpha: 0.10 + 0.05 * sin(_time * 1.7),
      );
    final v1 = Path()
      ..moveTo(b.left + 30, b.bottom - 60)
      ..quadraticBezierTo(
        b.left + 110,
        b.bottom - 95,
        b.left + 150,
        b.bottom - 40,
      );
    final v2 = Path()
      ..moveTo(b.right - 36, b.top + 70)
      ..quadraticBezierTo(b.right - 130, b.top + 95, b.right - 170, b.top + 48);
    canvas.drawPath(v1, vein);
    canvas.drawPath(v2, vein);
    // Soot feathering dissolves the hard edges.
    if (_fx.ready) {
      final cols = (b.width / 130).clamp(3, 9).toInt();
      for (var i = 0; i < cols; i++) {
        final x = b.left + (i + 0.5) / cols * b.width;
        drawPuff(
          canvas,
          _fx.puff!,
          Offset(x, b.top + 8),
          120,
          const Color(0xFF17100C).withValues(alpha: 0.55),
        );
        drawPuff(
          canvas,
          _fx.puff!,
          Offset(x, b.bottom - 8),
          120,
          const Color(0xFF120D0A).withValues(alpha: 0.6),
        );
      }
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFC4A35A).withValues(alpha: 0.14),
    );
  }

  /// Per-room landmarks + puzzle objects.
  void _renderCathedral(Canvas canvas, DungeonRoom room) {
    switch (room.id) {
      case 'narthex':
        _drawGreatHearth(canvas, room);
        break;
      case 'nave':
        _drawNave(canvas, room);
        break;
      case 'scriptorium':
        _drawSootMural(canvas, room);
        _drawEmberEpitaph(canvas);
        break;
      case 'choir':
        _drawChoirStalls(canvas, room);
        _drawChoirFloorMural(canvas, room);
        _drawRiteAshDrift(canvas, room); // the drift lies under everything
        _drawRitualBraziers(canvas, room);
        break;
      case 'cloister':
        // The wind lies under everything; the vane stands on the dry fountain
        // at the heart of the garth.
        _drawCrosswind(canvas, room);
        final vane = room.windVane ?? room.bounds.center;
        _drawDryFountain(canvas, vane);
        _drawWindVane(canvas, vane);
        _drawVineBeds(canvas, room);
        break;
      case 'reliquary':
        _drawCinderShrine(canvas, room.bounds.center);
        break;
      case 'vestry':
        _drawVesperFresco(canvas, room);
        break;
      case 'bell_gallery':
        _drawVesperStands(canvas, room);
        _drawIncenseChains(canvas, room);
        break;
      case 'high_altar':
        _drawBlackFlameAltar(canvas, room);
        break;
      case 'sanctum':
        _drawSanctumRoost(canvas, room);
        _drawSimurghTelegraph(canvas, room);
        break;
    }
  }

  /// A small layered flame: two teardrop lobes + a baked glow beneath.
  void _drawFlame(
    Canvas canvas,
    Offset base,
    double h, {
    Color core = const Color(0xFFFFD27A),
    Color outer = const Color(0xFFFF7A3C),
    double phase = 0,
  }) {
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        base - Offset(0, h * 0.35),
        h * 1.5,
        outer.withValues(alpha: 0.30 + 0.08 * sin(_time * 6 + phase)),
      );
    }
    final sway = sin(_time * 5.2 + phase) * h * 0.12;
    Path lobe(double w, double hh, double lean) => Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(
        base.dx - w,
        base.dy - hh * 0.45,
        base.dx + lean,
        base.dy - hh,
      )
      ..quadraticBezierTo(base.dx + w, base.dy - hh * 0.45, base.dx, base.dy);
    canvas.drawPath(
      lobe(h * 0.42, h, sway),
      Paint()..color = outer.withValues(alpha: 0.75),
    );
    canvas.drawPath(
      lobe(h * 0.24, h * 0.62, sway * 0.7),
      Paint()..color = core.withValues(alpha: 0.9),
    );
  }

  void _drawGreatHearth(Canvas canvas, DungeonRoom room) {
    final c = Offset(330, 265);
    // Arched hearth mouth.
    final arch = Path()
      ..moveTo(c.dx - 70, c.dy + 46)
      ..lineTo(c.dx - 70, c.dy - 10)
      ..quadraticBezierTo(c.dx, c.dy - 86, c.dx + 70, c.dy - 10)
      ..lineTo(c.dx + 70, c.dy + 46)
      ..close();
    canvas.drawPath(
      arch,
      Paint()..color = const Color(0xFF0B0705).withValues(alpha: 0.85),
    );
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFF74613A).withValues(alpha: 0.8),
    );
    // Andiron logs.
    final log = Paint()
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3A241A);
    canvas.drawLine(c + const Offset(-34, 36), c + const Offset(30, 28), log);
    canvas.drawLine(c + const Offset(-26, 26), c + const Offset(36, 38), log);
    final k = _entryReveal.clamp(0.0, 1.0); // 0 cold ash → 1 roaring hearth
    // The cold ash heap fades out as the fire catches.
    if (k < 1.0) {
      canvas.drawOval(
        Rect.fromCenter(center: c + const Offset(0, 34), width: 64, height: 18),
        Paint()..color = const Color(0xFF3A332C).withValues(alpha: 0.7 * (1 - k)),
      );
    }
    if (k <= 0.0) {
      // Stone-cold: one stubborn ember waiting for a flame.
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          c + const Offset(8, 30),
          5,
          const Color(0xFFFF8A50).withValues(
            alpha: 0.25 + 0.18 * (0.5 + 0.5 * sin(_time * 2.3)),
          ),
        );
      }
    } else {
      // KINDLE: flames climb out of the embers, the smaller tongues catching a
      // beat behind the main one so it reads as the fire taking hold.
      final kindle = Curves.easeOutCubic.transform(k);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c + const Offset(0, 18),
          30 + 26 * kindle,
          const Color(0xFFFF9A50).withValues(alpha: 0.10 + 0.16 * kindle),
        );
      }
      _drawFlame(canvas, c + const Offset(0, 30), 52 * kindle, phase: 0.4);
      final k2 = ((k - 0.25) / 0.75).clamp(0.0, 1.0);
      final k3 = ((k - 0.5) / 0.5).clamp(0.0, 1.0);
      if (k2 > 0) _drawFlame(canvas, c + const Offset(-20, 34), 30 * k2, phase: 2.1);
      if (k3 > 0) _drawFlame(canvas, c + const Offset(18, 34), 26 * k3, phase: 3.6);
    }
    // Flanking columns by the inner doors.
    final col = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xFF4A382C).withValues(alpha: 0.7);
    canvas.drawLine(const Offset(640, 180), const Offset(640, 360), col);
    canvas.drawLine(const Offset(672, 190), const Offset(672, 350), col);
  }

  void _drawNave(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    // Column rows down both sides.
    final col = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xFF3E2E22).withValues(alpha: 0.62);
    for (var i = 0; i < 4; i++) {
      final x = b.left + 150 + i * 200.0;
      canvas.drawLine(Offset(x, b.top + 120), Offset(x, b.top + 175), col);
      canvas.drawLine(
        Offset(x, b.bottom - 175),
        Offset(x, b.bottom - 120),
        col,
      );
      canvas.drawCircle(
        Offset(x, b.top + 112),
        9,
        Paint()..color = const Color(0xFF4A382C).withValues(alpha: 0.6),
      );
      canvas.drawCircle(
        Offset(x, b.bottom - 112),
        9,
        Paint()..color = const Color(0xFF4A382C).withValues(alpha: 0.6),
      );
      // Candle clusters at the column feet.
      if (_fx.ready) {
        final flick = 0.5 + 0.5 * sin(_time * 5.5 + i * 1.9);
        drawGlow(
          canvas,
          _fx.mote!,
          Offset(x, b.top + 184),
          7,
          const Color(0xFFE4C16A).withValues(alpha: 0.22 + 0.12 * flick),
        );
        drawGlow(
          canvas,
          _fx.mote!,
          Offset(x, b.bottom - 184),
          7,
          const Color(0xFFE4C16A).withValues(alpha: 0.22 + 0.12 * flick),
        );
      }
    }
    // The rose window above the chancel gate.
    _drawRoseWindow(canvas, Offset(b.center.dx + 185, b.top + 88), 56);
    // Star vigil lights over the gate: ember, ash, pyre.
    for (var i = 0; i < 3; i++) {
      final p = Offset(b.center.dx + 120 + i * 50.0, b.top + 170);
      final earnedStar = hasStar(i);
      final col2 = earnedStar
          ? const Color(0xFFE4C16A)
          : const Color(0xFF4A382C);
      if (_fx.ready && earnedStar) {
        drawGlow(canvas, _fx.glow!, p, 16, col2.withValues(alpha: 0.35));
      }
      _drawStarGlyph(canvas, p, 7, col2.withValues(alpha: earnedStar ? 0.95 : 0.5));
    }
  }

  void _drawRoseWindow(Canvas canvas, Offset c, double r) {
    final lit = 0.35 + _skyMood * 0.5;
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        r * 1.5,
        const Color(0xFFFF8A50).withValues(alpha: 0.16 * lit + 0.06),
      );
    }
    final glass = Paint()
      ..color = const Color(0xFF6E2A14).withValues(alpha: 0.5 * lit + 0.18);
    canvas.drawCircle(c, r, glass);
    final tracery = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFC4A35A).withValues(alpha: 0.55);
    canvas.drawCircle(c, r, tracery);
    canvas.drawCircle(c, r * 0.62, tracery);
    canvas.drawCircle(c, r * 0.24, tracery);
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + pi / 8;
      canvas.drawLine(
        c + Offset(cos(a), sin(a)) * r * 0.24,
        c + Offset(cos(a), sin(a)) * r,
        tracery,
      );
      // Petal glow segments.
      if (_fx.ready) {
        final pp = c + Offset(cos(a), sin(a)) * r * 0.8;
        drawGlow(
          canvas,
          _fx.mote!,
          pp,
          5,
          const Color(0xFFFFB46B).withValues(
            alpha: 0.10 + 0.10 * lit * (0.5 + 0.5 * sin(_time * 1.3 + i)),
          ),
        );
      }
    }
  }

  void _drawSootMural(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final panel = Rect.fromCenter(
      center: Offset(b.center.dx, b.top + 130),
      width: 490,
      height: 170,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(10)),
      Paint()..color = const Color(0xFF0D0907).withValues(alpha: 0.8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF74613A).withValues(alpha: 0.7),
    );
    // The panel's upper half belongs to the dead words (_drawEmberEpitaph).
    //
    // The lower band is the mural's own testimony, and it is CONFIRMATION,
    // not a key (§6.1 REWORK): six numbered stations, of which only TWO were
    // ever recorded — and never two in a row, so it can't even hand over a
    // single step of the sequence. Each recorded station names its brazier
    // WORDLESSLY, as a little constellation of the choir with one bowl
    // filled. Bring a deduction here and the mural will tell you whether you
    // are right; bring nothing and it tells you nothing.
    final tier = choirRevealTier;
    if (tier < 0) return;
    // Tier 0 recovers one station from the soot; tier 1+ recovers both.
    final shown = riteMuralRanks.take(tier >= 1 ? 2 : 1).toSet();
    final choir = _choirRoom;
    final glyphY = panel.bottom - 34;
    for (var rank = 0; rank < 6; rank++) {
      final p = Offset(panel.left + 52 + rank * 77.0, glyphY);
      // The station's number, always legible: rank+1 tally pips.
      for (var k = 0; k <= rank; k++) {
        canvas.drawCircle(
          p + Offset(-18 + k * 7.5, 24),
          2.0,
          Paint()..color = const Color(0xFFE4C16A).withValues(alpha: 0.75),
        );
      }
      if (!shown.contains(rank) || choir == null) {
        // Unrecorded: the soot here has flaked away to nothing.
        canvas.drawArc(
          Rect.fromCircle(center: p, radius: 13),
          0.5,
          pi * 0.55,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = const Color(0xFF6E5A46).withValues(alpha: 0.35),
        );
        continue;
      }
      // Recorded: a constellation of the choir's six bowls, the named one
      // filled and burning. No words, no arrows, no order.
      final named = riteBrazierAt(rank);
      for (var i = 0; i < choir.braziers.length; i++) {
        final q = p + (choir.braziers[i].position - choir.bounds.center) * 0.055;
        final isNamed = i == named;
        canvas.drawCircle(
          q,
          isNamed ? 3.4 : 2.0,
          Paint()
            ..style = isNamed ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFFE4C16A).withValues(
              alpha: isNamed ? 0.95 : 0.34,
            ),
        );
        if (isNamed) {
          _drawFlame(
            canvas,
            q + const Offset(0, 2),
            11,
            outer: const Color(0xFFC4703C),
            phase: rank * 1.7,
          );
        }
      }
    }
  }

  /// The Ember Epitaph: invisible at stage 0. Insight WRITES the maxim into
  /// the floor — an ember-quill draws each line in — then the garden planter
  /// settles in beside it. Plant, flame and gusts grow the blaze; when the
  /// third gust lands, a burn-front sweeps the script and the words stay lit
  /// in fire. Text painters are cached once; per-frame work is clip + paint.
  void _drawEmberEpitaph(Canvas canvas) {
    final won = discoveredClouds.contains(kFireEpitaphEggId);
    final stage = won ? 3 : epitaphStage;

    // Ghost cipher: before insight finds it, the dead words sit in the
    // mural's upper half as near-invisible scrambled soot.
    _epitaphGhostLines ??= [
      for (final line in kFireEpitaphScrambledLines)
        TextPainter(
          text: TextSpan(
            text: line,
            style: TextStyle(
              color: const Color(0xFF9A8A74).withValues(alpha: 0.07),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.6,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    // The quill's script stays SCRAMBLED — insight bares the writing, not
    // its meaning. Only the fire unscrambles it.
    _epitaphSootLines ??= [
      for (final line in kFireEpitaphScrambledLines)
        TextPainter(
          text: TextSpan(
            text: line,
            style: TextStyle(
              color: const Color(0xFF9A8A74).withValues(alpha: 0.38),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.6,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    _epitaphFireLines ??= [
      for (final line in kFireEpitaphLines)
        TextPainter(
          text: TextSpan(
            text: line,
            style: const TextStyle(
              color: Color(0xFFFFC07A),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.6,
              shadows: [Shadow(color: Color(0xFFFF7A3C), blurRadius: 7)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];

    Offset lineTopLeft(TextPainter tp, int i) => Offset(
      _kEpitaphTextAnchor.dx - tp.width / 2,
      _kEpitaphTextAnchor.dy + i * _kEpitaphLineHeight - tp.height / 2,
    );

    if (stage == 0) {
      // Unfound: just the ghost cipher, refusing to be read.
      for (var i = 0; i < _epitaphGhostLines!.length; i++) {
        final tp = _epitaphGhostLines![i];
        tp.paint(canvas, lineTopLeft(tp, i));
      }
      return;
    }

    // The scrambled script, written line by line behind an ember-quill.
    // Once the maxim ignites, each line's cipher survives only AHEAD of the
    // advancing burn-front — the fire consumes it as it unscrambles.
    for (var i = 0; i < _epitaphSootLines!.length; i++) {
      final tp = _epitaphSootLines![i];
      final reveal = won
          ? 1.0
          : ((epitaphWriteT - i * _kEpitaphWriteStagger) /
                    _kEpitaphWritePerLine)
                .clamp(0.0, 1.0);
      if (reveal <= 0) continue;
      final burn = won
          ? ((epitaphBlazeT - i * _kEpitaphBurnStagger) / _kEpitaphBurnPerLine)
                .clamp(0.0, 1.0)
          : 0.0;
      if (burn >= 1) continue; // fully consumed by the fire
      final pos = lineTopLeft(tp, i);
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          pos.dx - 3 + (tp.width + 6) * burn,
          pos.dy - 3,
          (tp.width + 6) * (reveal - burn).clamp(0.0, 1.0),
          tp.height + 6,
        ),
      );
      tp.paint(canvas, pos);
      canvas.restore();
      // The quill: a bright ember tracing the stroke being written.
      if (reveal < 1 && _fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          Offset(pos.dx + tp.width * reveal, pos.dy + tp.height * 0.55),
          5,
          const Color(0xFFFFB46B).withValues(
            alpha: 0.55 + 0.25 * sin(_time * 9),
          ),
        );
      }
    }

    // The burn-front: fire-script sweeps over the soot, then stays lit.
    if (won) {
      for (var i = 0; i < kFireEpitaphLines.length; i++) {
        final tp = _epitaphFireLines![i];
        final burn =
            ((epitaphBlazeT - i * _kEpitaphBurnStagger) / _kEpitaphBurnPerLine)
                .clamp(0.0, 1.0);
        if (burn <= 0) continue;
        final pos = Offset(
          _kEpitaphTextAnchor.dx - tp.width / 2,
          _kEpitaphTextAnchor.dy + i * _kEpitaphLineHeight - tp.height / 2,
        );
        canvas.save();
        canvas.clipRect(
          Rect.fromLTWH(
            pos.dx - 3,
            pos.dy - 3,
            (tp.width + 6) * burn,
            tp.height + 6,
          ),
        );
        tp.paint(canvas, pos);
        canvas.restore();
        if (burn < 1 && _fx.ready) {
          // Sparks at the advancing burn-front.
          drawGlow(
            canvas,
            _fx.glow!,
            Offset(pos.dx + tp.width * burn, pos.dy + tp.height * 0.5),
            14,
            const Color(0xFFFF8A50).withValues(alpha: 0.5),
          );
        }
      }
      // Settled: the script breathes with fire-light and keeps tiny flames.
      final settled =
          epitaphBlazeT >
          (kFireEpitaphLines.length - 1) * _kEpitaphBurnStagger +
              _kEpitaphBurnPerLine;
      if (settled) {
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            _kEpitaphTextAnchor + const Offset(0, _kEpitaphLineHeight),
            120,
            const Color(0xFFFF8A50).withValues(
              alpha: 0.10 + 0.05 * sin(_time * 2.4),
            ),
          );
        }
        _drawFlame(
          canvas,
          _kEpitaphTextAnchor + const Offset(-118, 6),
          12,
          phase: 1.7,
        );
        _drawFlame(
          canvas,
          _kEpitaphTextAnchor + const Offset(126, 60),
          12,
          phase: 3.9,
        );
      }
    }

    // The garden planter settles in once the writing finishes.
    final planterIn = won
        ? 1.0
        : ((epitaphWriteT - _epitaphWriteDuration) / 0.8).clamp(0.0, 1.0);
    if (planterIn <= 0) return;
    final p = kEmberEpitaphPlanter;
    final planter = RRect.fromRectAndRadius(
      Rect.fromCenter(center: p, width: 56, height: 22),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      planter,
      Paint()
        ..color = const Color(0xFF15100B).withValues(alpha: 0.9 * planterIn),
    );
    canvas.drawRRect(
      planter,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF74613A).withValues(alpha: 0.65 * planterIn),
    );
    // Vines, once planted.
    if (stage >= 2 && !won) {
      final vine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF6FAF5A).withValues(alpha: 0.85);
      for (var i = 0; i < 3; i++) {
        final ox = -14.0 + i * 14;
        canvas.drawPath(
          Path()
            ..moveTo(p.dx + ox, p.dy + 6)
            ..quadraticBezierTo(
              p.dx + ox - 5,
              p.dy - 6,
              p.dx + ox + 3,
              p.dy - 14 - i * 3.0,
            ),
          vine,
        );
      }
    }
    // The flame, swelling with each gust — and it KEEPS its full height
    // once the maxim is won (a fire that never dims again).
    if (stage >= 3) {
      final h = won ? 46.0 : 15.0 + epitaphFans * 9.0;
      _drawFlame(canvas, p + const Offset(0, 4), h, phase: 4.2);
      if (won && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          p - const Offset(0, 18),
          52,
          const Color(0xFFFF8A50).withValues(
            alpha: 0.16 + 0.06 * sin(_time * 3.1),
          ),
        );
      }
    }
  }

  void _drawChoirStalls(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final stall = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF3E2E22).withValues(alpha: 0.55);
    // Two facing banks of stalls flanking the processional line.
    for (var i = 0; i < 3; i++) {
      final y = b.center.dy - 90 + i * 90.0;
      canvas.drawLine(Offset(b.left + 90, y), Offset(b.left + 240, y), stall);
      canvas.drawLine(Offset(b.right - 240, y), Offset(b.right - 90, y), stall);
    }
  }

  /// The choir floor's ember-walk: a worn soot LABYRINTH at the room's heart,
  /// an ember pacing its circuits for ever. Kept from the old build as pure
  /// flavour (§6.1 REWORK) and deliberately DEFANGED — it is a devotional
  /// path, not a diagram, so it can never lie about a rite it was never told.
  /// The rite is read off the braziers now.
  void _drawChoirFloorMural(Canvas canvas, DungeonRoom room) {
    final star = room.brazierStarIndex;
    if (star == null || room.braziers.length < 2) return;
    final c = room.bounds.center + const Offset(0, 8);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFC4A35A).withValues(alpha: 0.11);
    // Four broken circuits, each opening at a different gate.
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 34.0 + i * 22.0),
        i * 1.35 + 0.4,
        pi * 1.72,
        false,
        ring,
      );
    }
    canvas.drawCircle(
      c,
      104,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF4A382C).withValues(alpha: 0.35),
    );
    if (hasStar(star)) return;
    // The pacing ember: one slow turn inward, endlessly.
    final u = (_time % 17.0) / 17.0;
    final ang = u * pi * 6;
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.mote!,
        c + Offset(cos(ang), sin(ang)) * (100.0 - u * 66.0),
        6,
        const Color(0xFFFFB46B).withValues(alpha: 0.20),
      );
    }
  }

  /// THE ASH DRIFT (evidence channel 3): the whole sequence's downwind, laid
  /// in one direction across the choir floor. With the wax and the soot it
  /// says which way the rite ran — and it is genuinely load-bearing: without
  /// it, barely a tenth of orders are uniquely deducible; with it, two fifths.
  /// Twelve strokes on a fixed lattice; nothing per-frame but the draw.
  void _drawRiteAshDrift(Canvas canvas, DungeonRoom room) {
    final star = room.brazierStarIndex;
    if (star == null || hasStar(star)) return;
    final d = riteAshDrift;
    if (d == Offset.zero) return;
    final b = room.bounds;
    final n = Offset(-d.dy, d.dx); // across the drift
    final mark = _testimonyMark;
    final streak = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF7A6249).withValues(alpha: 0.22 + 0.14 * mark);
    final tail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF9A8168).withValues(alpha: 0.13 + 0.10 * mark);
    for (var i = 0; i < 12; i++) {
      // Scattered, but a fixed lattice — never re-randomised per frame.
      final p = Offset(
        b.left + 90 + (((i * 7) % 11) / 11.0) * (b.width - 180),
        b.top + 80 + (((i * 5) % 7) / 7.0) * (b.height - 160),
      );
      final jog = n * (i.isEven ? 6.0 : -6.0);
      canvas.drawLine(p - d * 14 + jog, p + d * 14 + jog, streak);
      canvas.drawLine(p + d * 14 + jog, p + d * 28 + jog, tail);
    }
  }

  void _drawRitualBraziers(Canvas canvas, DungeonRoom room) {
    final star = room.brazierStarIndex;
    final done = star != null && hasStar(star);
    // The evidence lies UNDER the iron (soot on the floor, then the drift
    // wedge), so a lit brazier's own light falls over its own testimony.
    if (!done && star != null) {
      for (var i = 0; i < room.braziers.length; i++) {
        _drawBrazierTestimony(canvas, room, i);
      }
      _drawTestimonyLink(canvas, room);
    }
    for (var i = 0; i < room.braziers.length; i++) {
      final brz = room.braziers[i];
      final rank = star == null ? brz.order : riteRankOf(i);
      final lit = done || rank < ritualProgress;
      // Animation phase rides the brazier's PLACE, never its rank — a flicker
      // that beat in rite order would leak the answer through the idle loop.
      _drawBrazier(canvas, brz.position, lit: lit, phase: i * 1.3);
      // The WAX rides on the iron itself — drawn over the basin so the melt
      // line reads against the bowl, and eaten by the brazier's own fire.
      if (!done && star != null) _drawBrazierWax(canvas, room, i);
    }
  }

  /// How much of brazier [i]'s testimony still survives: 1 until its own fire
  /// takes it, then eased away over [_kTestimonyFade].
  double _testimonyAlive(int i) => _testimonyFade[i] ?? 1.0;

  /// THE SOOT + THE ASH, on the floor beneath one brazier.
  ///
  ///  • SOOT — an elliptical shadow shoved off-centre along the direction it
  ///    leans, with three fanning streaks: it leans AWAY from whichever
  ///    neighbour was already burning. On the fire lit FIRST there was no
  ///    such neighbour, so its soot lies in an EVEN COLLAR — a closed ring,
  ///    unmistakable at a glance and the thread-end of the whole deduction.
  ///  • ASH — a small drift wedge banked on the downwind side, matching the
  ///    floor streaks.
  ///
  /// Mask insight (t1) only brightens what is already drawn and adds a caret;
  /// it never adds information the iron does not carry.
  void _drawBrazierTestimony(Canvas canvas, DungeonRoom room, int i) {
    final alive = _testimonyAlive(i);
    if (alive <= 0.01) return;
    final t = testimonyFor(i);
    if (t == null) return;
    final p = room.braziers[i].position + const Offset(0, 20);
    final mark = _testimonyMark;
    final soot = Paint()
      ..color = const Color(0xFF15100C).withValues(alpha: (0.62 + 0.16 * mark) * alive);
    final lean = t.sootLean;

    if (lean == null) {
      // THE EVEN COLLAR — nothing was alight, so the soot fell all round.
      canvas.drawOval(
        Rect.fromCenter(center: p, width: 62, height: 30),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = const Color(0xFF15100C).withValues(
            alpha: (0.52 + 0.18 * mark) * alive,
          ),
      );
      canvas.drawOval(
        Rect.fromCenter(center: p, width: 40, height: 19),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF2A2018).withValues(
            alpha: (0.40 + 0.16 * mark) * alive,
          ),
      );
    } else {
      // A LEANING SHADOW — shoved out along the lean, fanning as it goes.
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(atan2(lean.dy, lean.dx));
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(19, 0), width: 74, height: 26),
        soot,
      );
      final streak = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF241A13).withValues(
          alpha: (0.50 + 0.20 * mark) * alive,
        );
      for (final fan in const [-0.30, 0.0, 0.30]) {
        canvas.drawLine(
          Offset(cos(fan), sin(fan)) * 24,
          Offset(cos(fan), sin(fan)) * 54,
          streak,
        );
      }
      canvas.restore();
    }

    // THE ASH WEDGE, banked downwind on the same side as the floor streaks.
    final d = riteAshDrift;
    if (d != Offset.zero) {
      final base = p + d * 26;
      final n = Offset(-d.dy, d.dx);
      canvas.drawPath(
        Path()
          ..moveTo(base.dx - n.dx * 15, base.dy - n.dy * 15)
          ..lineTo(base.dx + n.dx * 15, base.dy + n.dy * 15)
          ..lineTo(base.dx + d.dx * 15, base.dy + d.dy * 15)
          ..close(),
        Paint()
          ..color = const Color(0xFF8A7358).withValues(
            alpha: (0.30 + 0.18 * mark) * alive,
          ),
      );
    }

    // Insight's caret over the readable evidence (t1) — a mark, not an answer.
    if (mark > 0.02) {
      final caret = p - const Offset(0, 46);
      final nib = Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE4C16A).withValues(alpha: 0.42 * mark * alive);
      canvas.drawLine(caret + const Offset(-5, 5), caret, nib);
      canvas.drawLine(caret, caret + const Offset(5, 5), nib);
    }
  }

  /// THE WAX (evidence channel 1): tallow run down the iron and set there.
  /// Lowest = lit first, burned longest. Three tiers, two braziers each, so
  /// the wax narrows the rite to eight candidates and never hands it over —
  /// and two braziers of one tier are drawn IDENTICALLY, or the tier would
  /// leak the rank.
  void _drawBrazierWax(Canvas canvas, DungeonRoom room, int i) {
    final alive = _testimonyAlive(i);
    if (alive <= 0.01) return;
    final t = testimonyFor(i);
    if (t == null) return;
    final p = room.braziers[i].position;
    final h = 6.0 + 26.0 * t.waxFill; // 10 · 20 · 32 px of set tallow
    final mark = _testimonyMark;
    final tallow = Paint()
      ..color = const Color(0xFFD9C7A2).withValues(
        alpha: (0.62 + 0.16 * mark) * alive,
      );
    // The collar of wax banked round the bowl's foot…
    final body = Path()
      ..moveTo(p.dx - 15, p.dy + 22)
      ..lineTo(p.dx - 11, p.dy + 22 - h)
      ..quadraticBezierTo(p.dx, p.dy + 16 - h, p.dx + 11, p.dy + 22 - h)
      ..lineTo(p.dx + 15, p.dy + 22)
      ..close();
    canvas.drawPath(body, tallow);
    // …its melt line, the one edge the eye actually measures…
    canvas.drawLine(
      Offset(p.dx - 12, p.dy + 21 - h),
      Offset(p.dx + 12, p.dy + 21 - h),
      Paint()
        ..strokeWidth = 1.6
        ..color = const Color(0xFFF2E6C8).withValues(
          alpha: (0.55 + 0.25 * mark) * alive,
        ),
    );
    // …and the drips that got that far down before they set.
    final drip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFC9B48D).withValues(alpha: 0.5 * alive);
    for (final dx in const [-8.0, 0.0, 8.0]) {
      canvas.drawLine(
        Offset(p.dx + dx, p.dy + 21 - h * 0.72),
        Offset(p.dx + dx, p.dy + 21),
        drip,
      );
    }
  }

  /// Insight t2's ONE annotated link: a dotted arc drawn from the fire at the
  /// picked rank to the fire that followed it — one step of the deduction,
  /// worked out for you. Never more than one, and always the same one.
  void _drawTestimonyLink(Canvas canvas, DungeonRoom room) {
    final rank = _testimonyLinkRank;
    if (rank == null || _testimonyMark <= 0.02) return;
    if (rank + 1 >= riteOrder.length) return;
    final from = room.braziers[riteBrazierAt(rank)].position;
    final to = room.braziers[riteBrazierAt(rank + 1)].position;
    final a = 0.5 * _testimonyMark;
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE4C16A).withValues(alpha: a);
    // Dashed, so it reads as annotation over the world rather than a wire.
    for (final (f0, f1) in const [
      (0.10, 0.22),
      (0.32, 0.44),
      (0.54, 0.66),
      (0.76, 0.88),
    ]) {
      canvas.drawLine(
        Offset.lerp(from, to, f0)!,
        Offset.lerp(from, to, f1)!,
        ink,
      );
    }
    // An arrowhead at the later fire.
    final dir = to - from;
    final len = dir.distance;
    if (len < 1) return;
    final u = dir / len;
    final n = Offset(-u.dy, u.dx);
    final tip = to - u * 26;
    canvas.drawLine(tip, tip - u * 11 + n * 7, ink);
    canvas.drawLine(tip, tip - u * 11 - n * 7, ink);
  }

  void _drawBrazier(
    Canvas canvas,
    Offset p, {
    required bool lit,
    double phase = 0,
  }) {
    // Light pool under a lit basin.
    if (lit && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        p,
        46,
        const Color(0xFFFF8A50).withValues(alpha: 0.18),
      );
    }
    // Tripod legs.
    final leg = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2E211A);
    canvas.drawLine(p + const Offset(-10, 8), p + const Offset(-16, 22), leg);
    canvas.drawLine(p + const Offset(10, 8), p + const Offset(16, 22), leg);
    canvas.drawLine(p + const Offset(0, 10), p + const Offset(0, 24), leg);
    // Iron basin.
    canvas.drawArc(
      Rect.fromCircle(center: p, radius: 16),
      0,
      pi,
      false,
      Paint()..color = const Color(0xFF241812),
    );
    canvas.drawArc(
      Rect.fromCircle(center: p, radius: 16),
      0,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = (lit ? const Color(0xFFC4A35A) : const Color(0xFF4A382C))
            .withValues(alpha: 0.85),
    );
    if (lit) {
      _drawFlame(canvas, p + const Offset(0, 2), 30, phase: phase);
    } else if (_fx.ready) {
      // A dormant rim-ember so cold braziers still read as interactable.
      drawGlow(
        canvas,
        _fx.mote!,
        p + const Offset(5, -2),
        4,
        const Color(0xFFFF8A50).withValues(
          alpha: 0.16 + 0.12 * (0.5 + 0.5 * sin(_time * 2.0 + phase)),
        ),
      );
    }
  }

  void _drawDryFountain(Canvas canvas, Offset c) {
    final stone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF4A382C).withValues(alpha: 0.7);
    canvas.drawCircle(c, 52, stone);
    canvas.drawCircle(c, 30, stone);
    canvas.drawCircle(
      c,
      8,
      Paint()..color = const Color(0xFF241812).withValues(alpha: 0.9),
    );
    // Cracks radiating from the dry basin.
    final crack = Paint()
      ..strokeWidth = 1.3
      ..color = const Color(0xFF3A2A20).withValues(alpha: 0.7);
    for (var i = 0; i < 5; i++) {
      final a = i * 1.26 + 0.4;
      final p1 = c + Offset(cos(a), sin(a)) * 52;
      final p2 = c + Offset(cos(a + 0.18), sin(a + 0.18)) * 76;
      canvas.drawLine(p1, p2, crack);
    }
  }

  // ── The garth: the wind, the grooves, the drift ─────────

  /// THE CROSSWIND, drawn first and under everything: soot streaking across
  /// the open garth on one scrolling phase. Eight short strokes — the wind has
  /// to be READABLE before a burn is committed, and it must cost nothing.
  void _drawCrosswind(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final dir = gardenWindVector;
    final across = Offset(-dir.dy, dir.dx);
    final c = b.center;
    final span = b.longestSide * 0.5;

    // The air itself: comets running downwind, bright head into a fading
    // tail so the DIRECTION is unmistakable. (These used to sit at alpha
    // 0.05 — present in the code and invisible on the screen.)
    for (var i = 0; i < 14; i++) {
      final lane = (i - 6.5) * (b.shortestSide / 14.5);
      final phase = (_time * 78 + i * 97) % (span * 2);
      final head = c + across * lane + dir * (phase - span);
      if (!b.inflate(60).contains(head)) continue;
      final len = 30.0 + (i.isEven ? 16.0 : 0.0);
      final breathe = 0.60 + 0.40 * sin(_time * 1.4 + i);
      // Tail: several segments, each fainter, so it reads as motion.
      for (var k = 0; k < 4; k++) {
        final t0 = head - dir * (len * k / 4);
        final t1 = head - dir * (len * (k + 1) / 4);
        canvas.drawLine(
          t1,
          t0,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 2.6 - k * 0.5
            ..color = const Color(0xFFBFAE97)
                .withValues(alpha: (0.20 - k * 0.045) * breathe),
        );
      }
    }

    // THE LANES: the ash road. Every bed sits on a lane running downwind, and
    // a burn dusts everything behind it on that lane — so the lanes are drawn
    // through the bed centres as long arrows. This is the single thing that
    // makes the wind mean something instead of just moving.
    if (room.vineBeds.isNotEmpty) {
      final seen = <double>{};
      for (final bed in room.vineBeds) {
        // One arrow per lane: key by the across-axis coordinate.
        final key =
            (bed.position.dx * across.dx + bed.position.dy * across.dy)
                .roundToDouble();
        if (!seen.add(key)) continue;
        final from = bed.position - dir * 150;
        final to = bed.position + dir * 190;
        canvas.drawLine(
          from,
          to,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 1.4
            ..color = const Color(0xFFC4A35A).withValues(alpha: 0.16),
        );
        // Chevrons along the lane, marching downwind.
        for (var k = 0; k < 5; k++) {
          final march = ((_time * 0.35 + k * 0.2) % 1.0);
          final at = from + (to - from) * march;
          final wing = 7.0;
          canvas.drawPath(
            Path()
              ..moveTo((at - dir * 7 + across * wing).dx,
                  (at - dir * 7 + across * wing).dy)
              ..lineTo(at.dx, at.dy)
              ..lineTo((at - dir * 7 - across * wing).dx,
                  (at - dir * 7 - across * wing).dy),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFFC4A35A).withValues(
                alpha: 0.30 * sin(march * pi).clamp(0.0, 1.0),
              ),
          );
        }
      }
    }
  }

  /// The iron wind-cross on the dry fountain: the vane any Air creature swings
  /// a quarter. The pointer EASES round (never a snap) and the four cardinal
  /// pins stay put, so the turn reads as a mechanism and not a teleport.
  void _drawWindVane(Canvas canvas, Offset c) {
    final iron = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF74613A).withValues(alpha: 0.8);
    // The cardinal pins.
    for (var i = 0; i < 4; i++) {
      final a = i * pi / 2 - pi / 2;
      final u = Offset(cos(a), sin(a));
      canvas.drawLine(c + u * 20, c + u * 30, iron);
    }
    // The vane itself, swung to the live quarter.
    final dir = gardenWindVector;
    final across = Offset(-dir.dy, dir.dx);
    final head = c + dir * 34;
    final arrow = Paint()
      ..color = const Color(0xFFC4A35A).withValues(alpha: 0.9);
    canvas.drawLine(
      c - dir * 26,
      head,
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFC4A35A).withValues(alpha: 0.85),
    );
    canvas.drawPath(
      Path()
        ..moveTo(head.dx, head.dy)
        ..lineTo((head - dir * 14 + across * 8).dx, (head - dir * 14 + across * 8).dy)
        ..lineTo((head - dir * 14 - across * 8).dx, (head - dir * 14 - across * 8).dy)
        ..close(),
      arrow,
    );
    // The tail feather, so the quarter reads at a glance.
    canvas.drawLine(
      c - dir * 26 + across * 9,
      c - dir * 26 - across * 9,
      iron,
    );
    if (_fx.ready && gardenWindSwing < 1.0) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        46,
        const Color(0xFFBFD4E0).withValues(alpha: 0.16 * (1 - gardenWindSwing)),
      );
    }
  }

  /// THE FORECAST — where a burn's ash would land, shown BEFORE it is
  /// committed. Every grown bed shows a faint downwind streak (a plume waiting
  /// to happen); the bed the active creature is standing at shows a bright one
  /// with a ring on each groove it would dust.
  /// A low flame standing in a groove that sits true — three tongues on
  /// their own phases so a row of lit beds never flickers in lockstep.
  void _drawGrooveFlame(Canvas canvas, Offset p, int seed) {
    for (var i = 0; i < 3; i++) {
      final ph = _time * 3.1 + i * 2.0 + seed * 0.7;
      final h = 20.0 + 9.0 * sin(ph);
      final x = p.dx + (i - 1) * 13.0 + sin(ph * 0.8) * 2.4;
      final base = Offset(x, p.dy + 16);
      final path = Path()
        ..moveTo(base.dx - 6, base.dy)
        ..quadraticBezierTo(base.dx - 4, base.dy - h * 0.6, base.dx, base.dy - h)
        ..quadraticBezierTo(base.dx + 4, base.dy - h * 0.6, base.dx + 6, base.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xFFFF8A2A).withValues(alpha: 0.55),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFD79A).withValues(alpha: 0.45)
          ..maskFilter = null,
      );
      if (_fx.ready) {
        drawGlow(canvas, _fx.glow!, base - Offset(0, h * 0.5), 16,
            const Color(0xFFFFB25A).withValues(alpha: 0.30));
      }
    }
  }

  void _drawPlumeForecast(Canvas canvas, DungeonRoom room) {
    final rules = ashGardenRules;
    if (rules == null) return;
    final active = creatures.isNotEmpty ? creatures[activeIndex].position : null;
    for (var i = 0; i < room.vineBeds.length; i++) {
      if (bedStateAt(i) != AshBedState.green) continue;
      final from = room.vineBeds[i].position;
      final near =
          active != null && (active - from).distance <= _kBedReach + 22;
      final ready = bedGrowthAt(i) >= 1.0;
      final targets = plumeTargetsAt(i);
      if (targets.isEmpty) continue;
      final alpha = near && ready ? 0.34 : 0.10;
      final streak = Paint()
        ..strokeWidth = near ? 3.0 : 1.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFB9A891).withValues(alpha: alpha);
      var tail = from;
      for (final t in targets) {
        final to = room.vineBeds[t].position;
        canvas.drawLine(tail, to, streak);
        canvas.drawCircle(
          to,
          near ? 26 : 22,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = near ? 2.0 : 1.2
            ..color = const Color(0xFFB9A891).withValues(alpha: alpha * 0.9),
        );
        tail = to;
      }
    }
    // A tier-2 reading draws ONE source→groove link out of the plan.
    final link = _gardenLink;
    if (link != null &&
        link.source < room.vineBeds.length &&
        link.groove < room.vineBeds.length) {
      final a = room.vineBeds[link.source].position;
      final b = room.vineBeds[link.groove].position;
      final pulse = 0.4 + 0.25 * sin(_time * 2.4);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF7FC7E8).withValues(alpha: pulse * 0.7),
      );
      canvas.drawCircle(
        b,
        30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF7FC7E8).withValues(alpha: pulse * 0.6),
      );
    }
  }

  /// The groove cut into a bed's stone kerb. Three unmistakable shapes, always
  /// visible (no Mask required — the rite's own standard): a shallow BOWL of
  /// broken arcs wants the drift · a deep angular BRAND wants its own fire ·
  /// a smooth SWEPT ring, barred, wants nothing at all.
  void _drawGroove(Canvas canvas, Offset p, GrooveDemand demand, bool sitsTrue) {
    // One weight, one radius, one language — the three cuts differ by SHAPE
    // alone, so they read apart at a glance instead of by squinting at
    // decoration. (Playtest: the old marks were fussy and unpolished.)
    const rad = 15.0;
    final lit = sitsTrue;
    final pulse = lit ? 0.70 + 0.30 * sin(_time * 2.2 + p.dx * 0.05) : 0.0;
    final ink = lit
        ? const Color(0xFFFFC98A).withValues(alpha: 0.75 + 0.25 * pulse)
        : const Color(0xFF9A8A66).withValues(alpha: 0.62);
    final cut = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lit ? 2.6 : 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink;

    switch (demand) {
      case GrooveDemand.ash:
        // THE DRIFT — an open bowl: a half-circle with a level line across it,
        // the shape of something waiting to be filled.
        canvas.drawArc(
          Rect.fromCircle(center: p, radius: rad),
          0.15,
          pi - 0.30,
          false,
          cut,
        );
        canvas.drawLine(
          p + const Offset(-rad, -1),
          p + const Offset(rad, -1),
          cut,
        );
        // Three settling flecks above the bowl.
        for (var i = -1; i <= 1; i++) {
          canvas.drawCircle(
            p + Offset(i * 8.0, -rad * 0.62),
            1.7,
            Paint()..color = ink,
          );
        }
      case GrooveDemand.scorch:
        // THE BRAND — a single hard chevron struck downward into the bed,
        // with a short stem: a mark burned in, not a pattern.
        canvas.drawPath(
          Path()
            ..moveTo(p.dx - rad, p.dy - rad * 0.45)
            ..lineTo(p.dx, p.dy + rad * 0.55)
            ..lineTo(p.dx + rad, p.dy - rad * 0.45),
          cut,
        );
        canvas.drawLine(
          p + const Offset(0, -rad * 0.9),
          p + const Offset(0, -rad * 0.1),
          cut,
        );
      case GrooveDemand.clean:
        // THE SWEPT GROOVE — a closed ring struck through: this one keeps
        // nothing, and the bar says so.
        canvas.drawCircle(p, rad * 0.86, cut);
        canvas.drawLine(
          p + Offset(-rad * 0.72, rad * 0.72),
          p + Offset(rad * 0.72, -rad * 0.72),
          cut,
        );
    }
  }

  void _drawVineBeds(Canvas canvas, DungeonRoom room) {
    final rules = ashGardenRules;
    if (rules == null) return;
    _drawPlumeForecast(canvas, room);
    for (var i = 0; i < room.vineBeds.length; i++) {
      final bed = room.vineBeds[i];
      final state = bedStateAt(i);
      final fx = _bedFx[i] ?? 0;
      final p = bed.position;
      // Does this groove have what it asked for, right now?
      final sitsTrue = grooveSitsTrue(i);
      // A groove that HAS what it asked for catches light: the bed breathes
      // ember and stands a low flame in its cut. That is the whole progress
      // display — six lit beds is a solved garth, read at a glance.
      if (sitsTrue) {
        final breathe = 0.72 + 0.28 * sin(_time * 2.4 + p.dx * 0.03);
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            p,
            74 * breathe,
            const Color(0xFFFF9A3C).withValues(alpha: 0.26 * breathe),
          );
        }
      }

      // The bed itself: a soil plot with a scorched kerb.
      final plot = Rect.fromCenter(center: p, width: 112, height: 88);
      final rr = RRect.fromRectAndRadius(plot, const Radius.circular(12));
      canvas.drawRRect(
        rr,
        Paint()
          ..color = switch (state) {
            AshBedState.scorch => const Color(0xFF0C0806),
            AshBedState.ash => const Color(0xFF201C18),
            AshBedState.spoiled => const Color(0xFF17110D),
            _ => const Color(0xFF15100B),
          }.withValues(alpha: 0.88),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF4A382C).withValues(alpha: 0.7),
      );

      switch (state) {
        case AshBedState.barren:
          final scorch = Paint()
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF33261D).withValues(alpha: 0.8);
          canvas.drawLine(
            p + const Offset(-30, -22),
            p + const Offset(-12, -10),
            scorch,
          );
          canvas.drawLine(
            p + const Offset(10, -26),
            p + const Offset(26, -14),
            scorch,
          );
          canvas.drawLine(
            p + const Offset(-8, 26),
            p + const Offset(12, 30),
            scorch,
          );
        case AshBedState.green:
          // Vines TAKING: the shoots climb in over `_kGardenGrowSeconds`, and
          // will not answer flame until they have (the price of a redo).
          final grown = bedGrowthAt(i);
          final vine = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(
              const Color(0xFF4E7C42),
              const Color(0xFF6FAF5A),
              grown,
            )!.withValues(alpha: 0.55 + 0.35 * grown);
          final sway = sin(_time * 1.8) * 3;
          for (var v = 0; v < 3; v++) {
            final ox = -28.0 + v * 26;
            final h = (18.0 + v * 4) * (0.25 + 0.75 * grown);
            canvas.drawPath(
              Path()
                ..moveTo(p.dx + ox, p.dy + 28)
                ..quadraticBezierTo(
                  p.dx + ox - 12 + sway,
                  p.dy + 2,
                  p.dx + ox + 6 + sway,
                  p.dy + 28 - h - 28,
                ),
              vine,
            );
            canvas.drawCircle(
              Offset(p.dx + ox + 6 + sway, p.dy - h),
              3 * (0.4 + 0.6 * grown),
              Paint()..color = const Color(
                0xFF8FCF6A,
              ).withValues(alpha: 0.5 + 0.45 * grown),
            );
          }
        case AshBedState.ash:
          // The drift, banked in pale streaks lying WITH the wind that laid
          // it — and easing in as the plume arrives.
          final land = 1.0 - (_bedPlume[i] ?? 1.0);
          final dir = gardenWindVector;
          // A soft bank of ash lying WITH the wind that laid it — the puff
          // sprite rather than scratched parallel lines, which read as hatching
          // instead of dust.
          if (_fx.ready) {
            for (var s = -1; s <= 1; s++) {
              final off = Offset(-dir.dy, dir.dx) * (s * 16.0);
              drawPuff(
                canvas,
                _fx.puff!,
                p + off + dir * (s.abs() * 4.0),
                62 - s.abs() * 12,
                const Color(0xFFCFC3B0)
                    .withValues(alpha: (0.26 - s.abs() * 0.06) * land),
              );
            }
          }
        case AshBedState.scorch:
          // A black brand, still breathing ember cracks.
          final crack = Paint()
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFB4542A).withValues(
              alpha: 0.34 + 0.16 * sin(_time * 1.9 + p.dx),
            );
          canvas.drawLine(
            p + const Offset(-34, 6),
            p + const Offset(-6, -14),
            crack,
          );
          canvas.drawLine(
            p + const Offset(6, 16),
            p + const Offset(32, -6),
            crack,
          );
        case AshBedState.spoiled:
          // Ash muddled into char: neither one thing nor the other. Grow it
          // again and it is gone — that is the whole recovery.
          final land = 1.0 - (_bedPlume[i] ?? 1.0);
          final smear = Paint()
            ..strokeWidth = 4.0
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF6C6055).withValues(alpha: 0.32 * land);
          canvas.drawLine(
            p + const Offset(-32, -16),
            p + const Offset(30, 12),
            smear,
          );
          canvas.drawLine(
            p + const Offset(-28, 16),
            p + const Offset(26, -12),
            smear,
          );
      }

      _drawGroove(canvas, p, grooveDemandAt(i), sitsTrue);
      if (sitsTrue) _drawGrooveFlame(canvas, p, i);

      if (fx > 0 && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          p,
          52,
          (state == AshBedState.green
                  ? const Color(0xFF6FAF5A)
                  : const Color(0xFFFFD27A))
              .withValues(alpha: 0.20 * fx),
        );
      }
    }
  }

  void _drawCinderShrine(Canvas canvas, Offset c) {
    // Pedestal + flame sigil: the cathedral's quiet treasury.
    final stone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF74613A).withValues(alpha: 0.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 22), width: 76, height: 26),
        const Radius.circular(6),
      ),
      stone,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 2), width: 48, height: 16),
        const Radius.circular(5),
      ),
      stone,
    );
    _drawFlame(canvas, c + const Offset(0, -6), 26, phase: 1.1);
    _drawRuneCircle(
      canvas,
      c,
      66,
      const Color(0xFFC4A35A).withValues(alpha: 0.30),
    );
  }

  void _drawVesperFresco(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final panel = Rect.fromCenter(
      center: Offset(b.center.dx, b.top + 120),
      width: 460,
      height: 130,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(10)),
      Paint()..color = const Color(0xFF0D0907).withValues(alpha: 0.8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF74613A).withValues(alpha: 0.7),
    );
    // Diagram: a sagging chain of censers, a wind spiral, a tolling bell.
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFC4A35A).withValues(alpha: 0.6);
    final y = panel.center.dy;
    final chain = Path()..moveTo(panel.left + 40, y - 10);
    chain.quadraticBezierTo(panel.left + 110, y + 26, panel.left + 180, y - 6);
    chain.quadraticBezierTo(panel.left + 250, y + 26, panel.left + 320, y - 10);
    canvas.drawPath(chain, ink);
    for (final dx in const [40.0, 180.0, 320.0]) {
      canvas.drawCircle(Offset(panel.left + dx, y - 8), 6, ink);
    }
    // Wind spiral mid-chain.
    final sp = Offset(panel.left + 250, y - 30);
    final spiral = Path()..moveTo(sp.dx - 14, sp.dy);
    spiral.quadraticBezierTo(sp.dx, sp.dy - 18, sp.dx + 12, sp.dy - 2);
    spiral.quadraticBezierTo(sp.dx + 2, sp.dy + 10, sp.dx - 4, sp.dy + 2);
    canvas.drawPath(spiral, ink);
    // The bell, rung.
    _drawBellShape(
      canvas,
      Offset(panel.right - 60, y - 4),
      14,
      const Color(0xFFE4C16A).withValues(alpha: 0.8),
    );
    // Vestment hooks along the south wall.
    final hook = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF3E2E22).withValues(alpha: 0.6);
    for (var i = 0; i < 5; i++) {
      final p = Offset(b.left + 130 + i * 140.0, b.bottom - 150);
      canvas.drawLine(p, p + const Offset(0, 18), hook);
      canvas.drawCircle(p + const Offset(0, 22), 4, hook);
    }
  }

  void _drawBellShape(Canvas canvas, Offset c, double r, Color color) {
    final bell = Path()
      ..moveTo(c.dx - r * 0.9, c.dy + r * 0.7)
      ..quadraticBezierTo(c.dx - r * 0.85, c.dy - r * 0.7, c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.85, c.dy - r * 0.7, c.dx + r * 0.9, c.dy + r * 0.7)
      ..close();
    canvas.drawPath(
      bell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
    canvas.drawCircle(c + Offset(0, r * 0.85), r * 0.2, Paint()..color = color);
  }

  /// The two censer stands (Star 3's decision, §6.1 REWORK). Both stand cold
  /// and equal until one is lit; the declared one keeps a live coal and a lit
  /// ring, and the ghost of the run it would swing out to is sketched from it
  /// — so the choice can be WEIGHED by looking, not by committing.
  void _drawVesperStands(Canvas canvas, DungeonRoom room) {
    if (room.vesperRoutes.isEmpty || hasStar(2)) return;
    final declared = vesperRouteId;
    for (final route in room.vesperRoutes) {
      final chosen = route.id == declared;
      final p = route.standPosition;
      // The ghost run: this route's censers, faint, so both paths can be read
      // off the floor before either is chosen.
      final ghost = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFC4A35A).withValues(
          alpha: chosen ? 0.0 : 0.13,
        );
      if (!chosen) {
        for (final chain in room.incenseChains) {
          final nodes = route.chainNodes[chain.id] ?? chain.nodes;
          final pts = [...nodes, chain.bellPosition];
          for (var i = 0; i < pts.length - 1; i++) {
            canvas.drawLine(pts[i], pts[i + 1], ghost);
          }
          for (final n in nodes) {
            canvas.drawCircle(n, 5, ghost);
          }
        }
      }
      // The stand itself: a tripod of hanging censers.
      final iron = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = (chosen ? const Color(0xFFC4A35A) : const Color(0xFF4A382C))
            .withValues(alpha: 0.85);
      canvas.drawLine(p + const Offset(0, 26), p + const Offset(0, -18), iron);
      canvas.drawLine(p + const Offset(-16, -14), p + const Offset(16, -14), iron);
      for (final dx in const [-14.0, 0.0, 14.0]) {
        canvas.drawArc(
          Rect.fromCircle(center: p + Offset(dx, -2), radius: 7),
          0,
          pi,
          false,
          iron,
        );
      }
      if (chosen) {
        // The declared run keeps a live coal, and the swing settles in eased.
        final swing = Curves.easeOutCubic.transform(_routeSwapT.clamp(0.0, 1.0));
        _drawFlame(canvas, p + const Offset(0, 4), 8 + 10 * swing, phase: 2.4);
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            p,
            26 + 10 * swing,
            const Color(0xFFFF8A50).withValues(alpha: 0.18 * swing),
          );
        }
      } else if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          p + const Offset(6, -2),
          4,
          const Color(0xFFFF8A50).withValues(
            alpha: 0.14 + 0.10 * (0.5 + 0.5 * sin(_time * 2.0 + p.dy)),
          ),
        );
      }
    }
  }

  void _drawIncenseChains(Canvas canvas, DungeonRoom room) {
    for (final chain in room.incenseChains) {
      final rung = bellsRung.contains(chain.id) || hasStar(2);
      final checkpoint = _chainCheckpoints[chain.id] ?? 0;
      final flame = _vesperFlames[chain.id];
      // Chain segments: sagging links between the DECLARED run's censers,
      // ending at the bell (which never moves — only the way to it does).
      final nodes = chainNodes(chain);
      final pts = [...nodes, chain.bellPosition];
      final linkPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = (rung ? const Color(0xFFC4A35A) : const Color(0xFF5A463A))
            .withValues(alpha: rung ? 0.55 : 0.45);
      for (var i = 0; i < pts.length - 1; i++) {
        final a = pts[i];
        final bp = pts[i + 1];
        final mid = Offset.lerp(a, bp, 0.5)! + const Offset(0, 20);
        canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..quadraticBezierTo(mid.dx, mid.dy, bp.dx, bp.dy),
          linkPaint,
        );
      }
      // Censers: small swinging cups; reached ones keep a coal alive.
      for (var i = 0; i < nodes.length; i++) {
        final p = nodes[i];
        final reached = rung || i <= checkpoint;
        canvas.drawArc(
          Rect.fromCircle(center: p, radius: 9),
          0,
          pi,
          false,
          Paint()..color = const Color(0xFF241812),
        );
        canvas.drawArc(
          Rect.fromCircle(center: p, radius: 9),
          0,
          pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color =
                (reached ? const Color(0xFFC4A35A) : const Color(0xFF4A382C))
                    .withValues(alpha: 0.85),
        );
        if (reached && _fx.ready && !rung) {
          drawGlow(
            canvas,
            _fx.mote!,
            p,
            5,
            const Color(0xFFFF8A50).withValues(
              alpha: 0.22 + 0.14 * (0.5 + 0.5 * sin(_time * 2.6 + i * 1.4)),
            ),
          );
        }
      }
      // The ember bell.
      final bellColor = rung
          ? const Color(0xFFE4C16A)
          : const Color(0xFF74613A).withValues(alpha: 0.8);
      if (rung && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          chain.bellPosition,
          30,
          const Color(0xFFFFB46B).withValues(alpha: 0.22),
        );
      }
      _drawBellShape(canvas, chain.bellPosition, 16, bellColor);
      // Toll ripples while the last ring still hums.
      if (rung && _bellTollFx > 0) {
        final t = 1 - (_bellTollFx / 2.2);
        canvas.drawCircle(
          chain.bellPosition,
          20 + t * 70,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = const Color(0xFFFFD27A).withValues(
              alpha: (0.5 * (1 - t)).clamp(0.0, 0.5),
            ),
        );
      }
      // The live flame, crawling.
      if (flame != null) {
        final p = _chainPoint(chain, flame.segment, flame.t);
        final starving = flame.life < 1.0;
        _drawFlame(
          canvas,
          p + const Offset(0, 6),
          starving ? 16 : 24,
          outer: starving ? const Color(0xFFB05A2C) : const Color(0xFFFF7A3C),
          phase: chain.id.hashCode.toDouble(),
        );
      }
    }
  }

  void _drawBlackFlameAltar(Canvas canvas, DungeonRoom room) {
    final c = room.bounds.center;
    // Stepped dais.
    final stone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF74613A).withValues(alpha: 0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 16), width: 190, height: 96),
        const Radius.circular(14),
      ),
      stone,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 8), width: 130, height: 58),
        const Radius.circular(10),
      ),
      stone,
    );
    // Candelabra flanks.
    for (final side in const [-1.0, 1.0]) {
      final base = c + Offset(side * 130, 30);
      final pole = Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2E211A);
      canvas.drawLine(base, base + const Offset(0, -42), pole);
      canvas.drawLine(
        base + const Offset(-14, -30),
        base + const Offset(14, -30),
        pole,
      );
      _drawFlame(canvas, base + const Offset(0, -44), 13, phase: side * 2.0);
      _drawFlame(canvas, base + const Offset(-14, -32), 10, phase: side * 3.1);
      _drawFlame(canvas, base + const Offset(14, -32), 10, phase: side * 1.2);
    }
    if (guardianAwake || hasStar(2)) {
      // The black flame: dark violet body, ember-rimmed.
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c - const Offset(0, 16),
          64,
          const Color(0xFF6E2A8A).withValues(alpha: 0.20),
        );
      }
      _drawFlame(
        canvas,
        c + const Offset(0, 4),
        56,
        core: const Color(0xFF35124A),
        outer: const Color(0xFF1A0A26),
        phase: 0.9,
      );
      _drawFlame(
        canvas,
        c + const Offset(0, 4),
        30,
        core: const Color(0xFFFF7A3C),
        outer: const Color(0xFF6E2A14),
        phase: 2.3,
      );
    } else {
      // Dormant: one thin smoke thread rising from the cold altar stone.
      final smoke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF6E5A4A).withValues(alpha: 0.30);
      final path = Path()..moveTo(c.dx, c.dy);
      for (var i = 1; i <= 4; i++) {
        path.quadraticBezierTo(
          c.dx + sin(_time * 1.1 + i * 1.7) * 10,
          c.dy - i * 18.0 + 9,
          c.dx + sin(_time * 1.1 + i * 1.7 + 0.8) * 6,
          c.dy - i * 18.0,
        );
      }
      canvas.drawPath(path, smoke);
    }
  }

  /// SIMURGH'S TELEGRAPH (§7): phantom rite braziers ringing the roost in the
  /// choir's own arrangement, re-lit in this run's remembered order. Each takes
  /// its turn with a readable FLARE (a widening ring and a swelling ember, so
  /// the wind-up is visibly a wind-up) before the pillar of flame actually
  /// lands. The order is the bullet pattern — Star 1's deduction is Star 3's
  /// footwork.
  void _drawSimurghTelegraph(Canvas canvas, DungeonRoom room) {
    if (isRaid || !guardianAwake) return;
    final g = room.guardian;
    if (g == null || hasStar(g.starIndex)) return;
    final spots = simurghTelegraphSpots(room);
    if (spots.isEmpty) return;

    // The cold phantom iron, always present once the Simurgh is up.
    final iron = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF5A3A2A).withValues(alpha: 0.42);
    for (final p in spots) {
      canvas.drawArc(
        Rect.fromCircle(center: p, radius: 13),
        0,
        pi,
        false,
        iron,
      );
      canvas.drawLine(p + const Offset(-8, 7), p + const Offset(-12, 19), iron);
      canvas.drawLine(p + const Offset(8, 7), p + const Offset(12, 19), iron);
    }

    _simurghPillars.forEach((rank, t) {
      final idx = riteBrazierAt(rank);
      if (idx < 0 || idx >= spots.length) return;
      final p = spots[idx];
      if (t < _kTelegraphWindup) {
        // THE FLARE — the fair warning. A ring closing in on the spot, and an
        // ember swelling in the bowl.
        final u = (t / _kTelegraphWindup).clamp(0.0, 1.0);
        canvas.drawCircle(
          p,
          _kTelegraphRadius * (1.35 - 0.35 * u),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 + 1.6 * u
            ..color = const Color(0xFFFF8A50).withValues(alpha: 0.16 + 0.30 * u),
        );
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.mote!,
            p,
            4 + 8 * u,
            const Color(0xFFFFD27A).withValues(alpha: 0.24 + 0.36 * u),
          );
        }
      } else {
        // THE PILLAR — black-flame fire standing where the warning stood.
        final u = ((t - _kTelegraphWindup) / (1 - _kTelegraphWindup))
            .clamp(0.0, 1.0);
        final fade = 1.0 - u * u;
        canvas.drawCircle(
          p,
          _kTelegraphRadius,
          Paint()
            ..color = const Color(0xFF6E2A14).withValues(alpha: 0.20 * fade),
        );
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            p - const Offset(0, 20),
            _kTelegraphRadius * 1.1,
            const Color(0xFF8A2AA0).withValues(alpha: 0.22 * fade),
          );
        }
        _drawFlame(
          canvas,
          p + const Offset(0, 6),
          88 * fade,
          core: const Color(0xFF35124A),
          outer: const Color(0xFF1A0A26),
          phase: rank * 1.7,
        );
        _drawFlame(
          canvas,
          p + const Offset(0, 6),
          46 * fade,
          core: const Color(0xFFFF7A3C),
          outer: const Color(0xFF6E2A14),
          phase: rank * 2.3,
        );
      }
    });
  }

  void _drawSanctumRoost(Canvas canvas, DungeonRoom room) {
    final g = room.guardian;
    final c = g?.position ?? room.bounds.center;
    // Scorched ring where the Simurgh's flame has licked the stone for ages.
    canvas.drawCircle(
      c,
      120,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF33261D).withValues(alpha: 0.8),
    );
    final char = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3A2A20).withValues(alpha: 0.7);
    for (var i = 0; i < 10; i++) {
      final a = i * 0.628 + 0.25;
      canvas.drawLine(
        c + Offset(cos(a), sin(a)) * 112,
        c + Offset(cos(a), sin(a)) * 132,
        char,
      );
    }
    // Broken arch ruins behind the roost.
    final ruin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xFF3E2E22).withValues(alpha: 0.6);
    canvas.drawArc(
      Rect.fromCircle(center: c + const Offset(-150, -110), radius: 56),
      pi * 1.1,
      pi * 0.55,
      false,
      ruin,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c + const Offset(160, -96), radius: 48),
      pi * 1.35,
      pi * 0.5,
      false,
      ruin,
    );
    // Ember updrafts around an awake guardian.
    if (guardianAwake && _fx.ready) {
      for (var i = 0; i < 5; i++) {
        final a = i * 1.256 + _time * 0.5;
        final rr = 70 + 28 * sin(_time * 0.9 + i * 2.0);
        final p = c + Offset(cos(a) * rr, sin(a) * rr * 0.7);
        drawGlow(
          canvas,
          _fx.mote!,
          p,
          4.5,
          const Color(0xFFFFB46B).withValues(
            alpha: 0.18 + 0.12 * (0.5 + 0.5 * sin(_time * 3 + i)),
          ),
        );
      }
    }
  }
}
