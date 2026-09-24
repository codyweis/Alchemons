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
  double get waxFill => switch (waxTier) {
    0 => 0.16,
    1 => 0.54,
    _ => 1.0,
  };
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
  String toString() =>
      verb == AshGardenVerb.turnWind ? 'turnWind' : '${verb.name}($bed)';
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
        push(
          b * 4 + ((w + 1) & 3),
          const AshGardenMove(AshGardenVerb.turnWind, -1),
        );
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

/// How close a hand must stand to a scriptorium corner torch.
const double _kMuralTorchReach = 54.0;
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

  /// Gust distance still to be paid out, in px. See [_kGustGlideSpeed].
  double gust = 0;
}

// Tunables for the vesper rite. Self-speed alone can't cross a censer gap
// before the flame starves — the wind has to matter.
//
// PLAYTEST 2026-08-31: the crawl was hurried and the fuse short, so the room
// played as a scramble rather than as a rite. The flame creeps now and holds
// its breath for longer; the relay's shape is unchanged, because what makes
// the two routes different is the RATIO of gap to gust, and both sides of
// that moved together.
const double _kFlameSelfSpeed = 15.0; // px/s unaided
const double _kFlameLife = 4.0; // seconds per feeding
const double _kGustRadius = 85.0;

/// How fast a gust's push is paid out, in px/s.
///
/// The gust used to TELEPORT the flame its whole distance on the frame you
/// pressed it — which is what made a shove read as "too far": you never saw
/// the travel, only the arrival, two censers away. It glides now, and the
/// same distance reads as a nudge.
const double _kGustGlideSpeed = 260.0;

// ── The Lost Maxims (easter eggs — one per dungeon, 20 gold once) ──
// Discovery ids ride the persisted cloud-discovery channel ('egg:' prefix);
// the screen pays out 20 gold the first time one is found.

// (Air's `kAirFirstWindEggId` moved to planet_dungeon_game_air.dart with the
// rest of the spire's own content — §9.1 item 4.)

/// Fire's maxim — the EMBER EPITAPH. Lighting the fourth corner torch in the
/// scriptorium WRITES the maxim into the floor (an ember-quill animates it stroke by stroke) and
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

/// Seconds between the flame taking one cell and the next (device-tunable).
const double _kBurnBeat = 1.35;

/// How close a creature must stand to a garth cell to work it.
const double _kGarthReach = 62.0;

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
    _plantTestimony(room, [for (final b in authored) room.braziers.indexOf(b)]);
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
          BrazierTestimony(
            brazierIndex: i,
            waxTier: tiers[i],
            sootLean: leans[i],
          ),
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
      final d =
          (room.braziers[idx].position - room.braziers[j].position).distance;
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
      (index >= 0 && index < riteTestimony.length)
      ? riteTestimony[index]
      : null;

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
  String get gardenWindLabel => const ['N', 'E', 'S', 'W'][gardenWind & 3];

  /// The unit vector the crosswind runs along, EASED across a quarter turn so
  /// the streaks swing round instead of snapping.
  Offset get gardenWindVector {
    const dirs = [Offset(0, -1), Offset(1, 0), Offset(0, 1), Offset(-1, 0)];
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
    // Light is not knowledge: choirRevealTier survives a death (what you read
    // stays read), but the torches themselves burn out and must be relit.
    litMuralTorches.clear();
    // The rite's testimony is physical — wax, soot and ash on the iron. It is
    // there whether or not anybody has asked about it, so it is marked from
    // the start rather than switched on by a reading.
    _testimonyLinkRank = null;
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
    _testimonyMark = PlanetDungeonGame.testimonyMarked ? 1.0 : 0.0;
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

  // ── STAR 2 · THE BURN ────────────────────────────────────
  //
  // The garth is plantable soil. Plant lays vine, Fire lights one cell, Air
  // swings the vane — and the flame walks ITSELF, one cell per beat, downwind.
  // Every rule lives in BurnField; this is only the wiring: where a creature
  // stands, when the beat falls, and what the room says about it.

  /// Seconds between the flame taking one cell and the next.

  /// How close a creature must stand to a cell to work it.

  /// The live field for [room], built from its authored garth on first entry.
  BurnField? burnFieldFor(DungeonRoom room) {
    final g = room.garth;
    if (g == null) return null;
    final built = burnFields[room.id] ??= BurnField.parse(
      g.art,
      coverageGoal: g.coverageGoal,
    );
    // Keep the drawn crosswind pointing at the wind the burn actually uses.
    _syncCrosswindTo(built.wind);
    return built;
  }

  /// Whether the current room is a garth that can be re-laid.
  bool get _canRestartGarth => _isCathedral && currentRoom.garth != null;

  /// Wipe the garth back to its authored soil and put the party at the door.
  ///
  /// THE BURN NEEDS THIS. Ash takes no vine and the pool now answers to a
  /// SINGLE chain, so a fire that dies three cells short leaves ground that
  /// can never carry the route again — without a re-lay that is a dead run in
  /// a room you can still walk around in, which is the worst kind of stuck.
  /// Earned stars are untouched.
  void _restartGarth() {
    if (!_canRestartGarth) return;
    burnFields.remove(currentRoomId);
    garthWipeIn = 0; // a hand on the board beats a pending auto-wipe
    final spawn = _roomEntrySpawn(currentRoomId);
    for (final c in creatures) {
      c
        ..position = spawn
        ..lastSafe = spawn;
    }
    _setHint('The garth is turned over. Bare soil again');
    onChanged();
  }

  /// The garth's own patch of the cloister.
  ///
  /// The field used to BE the room, which is why a square came out 137x148
  /// and a phone could hold three columns of six. Now it is a garden with
  /// paths around it, and the whole board reads at once.
  Rect garthField(DungeonRoom room, BurnGarth g) => Rect.fromCenter(
    center: g.centre ?? room.bounds.center,
    width: g.fieldWidth,
    height: g.fieldHeight,
  );

  /// The cell index under [p], or -1 outside the field.
  int _garthAt(Offset p, DungeonRoom room, BurnGarth g) {
    final f = garthField(room, g);
    final c = ((p.dx - f.left) / g.cell).floor();
    final r = ((p.dy - f.top) / g.cell).floor();
    if (c < 0 || r < 0 || c >= g.cols || r >= g.rows) return -1;
    return r * g.cols + c;
  }

  Offset garthCentre(DungeonRoom room, BurnGarth g, int i) {
    final f = garthField(room, g);
    return Offset(
      f.left + (i % g.cols + 0.5) * g.cell,
      f.top + (i ~/ g.cols + 0.5) * g.cell,
    );
  }

  String _burnWindName(BurnWind w) => switch (w) {
    BurnWind.north => 'north',
    BurnWind.east => 'east',
    BurnWind.south => 'south',
    BurnWind.west => 'west',
  };

  /// Plant / light / swing — the three verbs, element-only at full power.

  /// Point the on-screen crosswind at the burn's ACTUAL wind.
  ///
  /// There are two winds in this file. The burn keeps its own on
  /// [BurnField.wind]; `gardenWind` belonged to the vine-bed garden that THE
  /// BURN replaced, and is only turned by _turnGardenWind — which sits behind
  /// an `if (room.vineBeds.isEmpty) return false` that is now always true.
  ///
  /// The arrow renders gardenWindVector, so it sat on its default east
  /// forever while the wind the puzzle actually uses swung freely underneath.
  /// Keeping the two in step here means the existing eased swing animation
  /// still drives the arrow, rather than snapping.
  ///
  /// BurnWind is index-for-index the same quarter order (0 N, 1 E, 2 S, 3 W).
  void _syncCrosswindTo(BurnWind w) {
    if (gardenWind == w.index) return;
    gardenWindFrom = gardenWind;
    gardenWind = w.index;
    gardenWindSwing = 0;
  }

  bool _tryBurn(DungeonCreature a) {
    if (!_isCathedral) return false;
    final room = currentRoom;
    final g = room.garth;
    final field = burnFieldFor(room);
    if (g == null || field == null) return false;
    if (hasStar(g.starIndex)) return false;

    // AIR swings the vane wherever it stands — the wind is the whole room's.
    if (a.member.element == 'Air') {
      field.wind = field.wind.quarterRight;
      _syncCrosswindTo(field.wind);
      _setHint('The vane swings, the wind runs ${_burnWindName(field.wind)}');
      onChanged();
      return true;
    }

    final i = _garthAt(a.position, room, g);
    if (i < 0) return false;
    final at = garthCentre(room, g, i);
    if ((a.position - at).distance > _kGarthReach) return false;

    switch (a.member.element) {
      case 'Plant':
        if (field.plant(i)) {
          _setHint(
            field.at(i) == BurnCell.wetVine
                ? 'Vine takes in the wet ground. Green, and it will never catch'
                : 'Vine takes in the soil',
          );
          _spawnAlchemyBurst(
            at,
            producedElement: 'Plant',
            particleCount: 10,
            intensity: 0.5,
          );
          onChanged();
          return true;
        }
        _setBlockedHint(switch (field.at(i)) {
          BurnCell.ash => 'Vines won\'t grow on burnt ground',
          BurnCell.stone => 'Nothing grows on fallen stone',
          _ => 'A vine already grows here',
        });
        return true;
      case 'Fire':
        if (field.alight) {
          _setBlockedHint('A fire is already burning. Only one at a time');
          return true;
        }
        if (field.light(i)) {
          burnBeat = _kBurnBeat;
          burnFlash = 0.35;
          _setHint('The vine catches, it runs with the wind', 3.0);
          _spawnAlchemyBurst(
            at,
            producedElement: 'Fire',
            reagentElements: const ['Plant'],
            particleCount: 20,
            intensity: 1.0,
          );
          onChanged();
          return true;
        }
        _setBlockedHint(switch (field.at(i)) {
          BurnCell.wetVine => 'Wet vines won\'t burn',
          BurnCell.soil => 'Bare soil has nothing to burn',
          BurnCell.ash => 'Already burnt',
          _ => 'Nothing here will catch',
        });
        return true;
    }
    return false;
  }

  /// How long a dead fire is left on the board before it is turned over.
  static const double _kGarthWipeDelay = 1.3;

  /// THE BEAT: the flame takes its next cell, or smoulders, or goes out.
  void _updateBurn(DungeonRoom room, double dt) {
    if (!_isCathedral) return;
    final g = room.garth;
    final field = burnFieldFor(room);
    if (g == null || field == null) return;
    if (burnFlash > 0) burnFlash -= dt;
    poolShown += (field.poolFraction - poolShown) * min(1.0, dt * 2.6);

    // A fire that died short turns the board over on its own, a beat later.
    if (garthWipeIn > 0) {
      garthWipeIn -= dt;
      if (garthWipeIn <= 0) {
        garthWipeIn = 0;
        burnFields.remove(room.id);
        burnBeat = 0;
        _setHint('Bare soil again. Plant your run, then strike once', 3.0);
        onChanged();
      }
      return;
    }
    if (hasStar(g.starIndex) || !field.alight) return;

    burnBeat -= dt;
    if (burnBeat > 0) return;
    burnBeat = _kBurnBeat;

    switch (field.step()) {
      case BurnStep.advanced:
        burnFlash = 0.35;
        _spawnAlchemyBurst(
          garthCentre(room, g, field.head!),
          producedElement: 'Dust',
          reagentElements: const ['Plant', 'Fire'],
          particleCount: 8,
          intensity: 0.5,
        );
        if (field.poolFull && !hasStar(g.starIndex)) {
          _setHint('The pool stands full, the cloister gives up its star', 4);
          earnStar(g.starIndex);
        }
      case BurnStep.smouldered:
        _setHint('The flame gutters, nothing downwind to take', 1.6);
      case BurnStep.died:
        // The goal is ONE chain, so a chain that stops short has already
        // failed — there is nothing to salvage from the ash it left, and
        // leaving the player to notice that themselves and press the re-lay
        // button is a chore, not a decision. The garth turns itself over.
        _setHint('The fire is out, the garth turns itself over', 3.4);
        garthWipeIn = _kGarthWipeDelay;
      case BurnStep.idle:
        break;
    }
    onChanged();
  }

  /// How near the aisle you must pass for a pier's candles to catch.
  ///
  /// Measured ACROSS the nave only, and applied to both stands at once: the
  /// pair of piers is one bay of the church, and walking the runner between
  /// them should light the bay. A radius around each stand meant you had to
  /// detour up to the wall and back for every candle, twice per bay, which is
  /// not walking down a nave — it is mowing it.
  static const double _kCandleReach = 130.0;

  /// The candle stands at the feet of the nave's piers: one per pier, in
  /// pier order (top row and bottom row interleaved).
  List<Offset> naveCandleStands(DungeonRoom room) {
    final b = room.bounds;
    return [
      for (var i = 0; i < 4; i++) ...[
        Offset(b.left + 150 + i * 200.0, b.top + 188),
        Offset(b.left + 150 + i * 200.0, b.bottom - 114),
      ],
    ];
  }

  void _updateNaveCandles(DungeonCreature a, DungeonRoom room, double dt) {
    final stands = naveCandleStands(room);
    for (var i = 0; i < stands.length; i++) {
      final lit = naveCandles[i] ?? 0;
      if (lit >= 1) continue;
      if ((a.position.dx - stands[i].dx).abs() > _kCandleReach) continue;
      // Half a second to take, so a candle catches visibly rather than
      // snapping on as you cross an invisible line.
      naveCandles[i] = (lit + dt / 0.5).clamp(0.0, 1.0);
      onChanged();
    }
  }

  void _updateCathedral(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isCathedral) return;
    _updateCathedralGlass(room, dt);
    if (_bellTollFx > 0) _bellTollFx -= dt;
    if (_bedFx.isNotEmpty) {
      _bedFx.updateAll((k, v) => v - dt);
      _bedFx.removeWhere((k, v) => v <= 0);
    }
    if (room.id == 'nave') _updateNaveCandles(a, room, dt);
    _updateAshGarden(dt);
    // ANIMATED STATE: insight's marking blooms, a lit brazier's testimony is
    // eaten by its own fire, and a re-declared censer run swings over. Three
    // scalar eases — no allocation, no per-frame geometry.
    if (PlanetDungeonGame.testimonyMarked && _testimonyMark < 1.0) {
      _testimonyMark = (_testimonyMark + dt / _kTestimonyMarkSeconds).clamp(
        0.0,
        1.0,
      );
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
      // Its own crawl, plus whatever a gust still owes it.
      var step = _kFlameSelfSpeed * dt;
      if (flame.gust > 0) {
        final paid = min(flame.gust, _kGustGlideSpeed * dt);
        flame.gust -= paid;
        step += paid;
      }
      _advanceFlame(room, chain, flame, step);
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
        _setHint('The vesper flame gutters out, its ash rises in fury', 3.0);
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
        'The third bell tolls. Black flame pours toward the sanctum',
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
    if (_tryMuralTorch(a, room)) return true;
    if (_tryHearthOrBrazier(a, room)) return true;
    if (_tryAshGarden(a, room)) return true;
    if (_tryVesper(a, room)) return true;
    if (_tryEmberEpitaph(a, room)) return true;
    if (_tryNaveCommune(a, room)) return true;
    return false;
  }

  /// The scriptorium's four corner torches.
  ///
  /// Element-only (§4): any Fire hand lights one, and nothing else does. The
  /// mural is soot on a dark wall in a windowless room — until all four are
  /// burning there is genuinely nothing to read, and the panel says so rather
  /// than sitting blank. The fourth torch is what brings the first recorded
  /// station up out of the dark.
  bool _tryMuralTorch(DungeonCreature a, DungeonRoom room) {
    if (room.muralTorches.isEmpty) return false;
    for (var i = 0; i < room.muralTorches.length; i++) {
      if ((a.position - room.muralTorches[i]).distance > _kMuralTorchReach) {
        continue;
      }
      if (litMuralTorches.contains(i)) {
        // Already burning. Say nothing and let the action fall through to the
        // creature's own verb — a lit torch is not an obstacle.
        return false;
      }
      if (a.member.element != 'Fire') {
        _setBlockedHint('Only Fire can light this pitch');
        return true;
      }
      litMuralTorches.add(i);
      _cue(SoundCue.elementFire);
      _spawnAlchemyBurst(
        room.muralTorches[i],
        producedElement: 'Fire',
        particleCount: 10,
      );
      if (muralLit(room)) {
        // THE TORCHES DO THE WORK, not the HINT button. Asking for a hint must
        // never change the world — it is a question, and a question that
        // quietly advances a puzzle is a trap for anyone who presses it out of
        // curiosity. So lighting the fourth corner performs the whole
        // scriptorium reading: the soot comes up at the reader's own tier and
        // the epitaph starts writing, exactly as pressing HINT used to.
        choirRevealTier = max(
          choirRevealTier,
          revealHintTier(a.member.statIntelligence),
        );
        revealFlash = 0.6;
        if (epitaphStage == 0 &&
            !discoveredClouds.contains(kFireEpitaphEggId)) {
          epitaphStage = 1;
          epitaphWriteT = 0;
        }
        _setHint('The four corners take, and the soot gives up its stations');
      } else {
        final left = room.muralTorches.length - litMuralTorches.length;
        _setHint(
          left == 1
              ? 'It catches, one corner still dark'
              : 'It catches, $left corners still dark',
        );
      }
      return true;
    }
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
        _setHint('The hearth is stone-cold, only flame wakes it');
        return true;
      }
      entryDoorRevealed = true;
      _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist
      final doorCenter = room.doors.isNotEmpty
          ? room.doors.first.rect.center
          : a.position;
      _setHint('Flame takes the great hearth, the inner doors grind apart');
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
      _setBlockedHint('Only Fire can light the braziers');
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
        'The fire remembers another order, every brazier snuffs out',
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
        _setBlockedHint('Only Air can turn this cross');
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
        _setBlockedHint('Nothing here to burn');
        return true;
      }
      if (bedGrowthAt(index) < 1.0) {
        _setBlockedHint('The shoots are too green to burn yet');
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
              ? 'The bed burns down to a black brand, its ash goes over the '
                    'wall'
              : 'The bed burns, and the wind takes its ash across the garth',
          3.2,
        );
      }
      return true;
    }

    // §5.6 BLOCKED: one short clause naming what is missing, never a method.
    _setBlockedHint('Only Plant or Fire can work this bed');
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
        _setBlockedHint('Only Fire can light this stand');
        return true;
      }
      if (vesperRouteId == route.id) {
        _setHint('This run already carries the vesper');
        return true;
      }
      if (_vesperUnderway) {
        _setBlockedHint('The vesper has started on the other run');
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
      _setHint(
        'The censers swing round, the vesper will go by the '
        '${route.name.toLowerCase()}',
      );
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
            'The vesper needs the ${layout.starName(0)} and '
            '${layout.starName(1)} first',
          );
          return true;
        }
        final route = vesperRouteIn(room);
        if (route == null && room.vesperRoutes.isNotEmpty) {
          _setBlockedHint('Choose a run first at one of the stands');
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
              ? 'The flame rekindles, and the ash stirs with it'
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
        // Enough to carry the flame onto the next cloister censer and no
        // further; a nave gap still needs the flame to survive the walk to a
        // second gust. That relationship is the whole route trade, and it is
        // measured in the Fire full-run test rather than asserted here.
        final push = 110.0 + 60.0 * speedT;
        flame.life = max(flame.life, _flameLife);
        _spawnAlchemyBurst(
          pos,
          producedElement: 'Air',
          reagentElements: const ['Fire'],
          particleCount: 12,
          intensity: 0.7,
        );
        _setHint('The gust bears the flame down the chain');
        flame.gust += push;
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
        _setBlockedHint('Fire lights the censers. Air carries the flame');
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
      'dawn into these vaults, the cathedral remembers, and now it rests.',
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
    // A raid arena carries its own braziers and has no authored choir room to
    // borrow the pattern from. Deliberately not given a brazierStarIndex —
    // that is the puzzle's plumbing, and a raid has no puzzle to solve; the
    // braziers are here only because the telegraph reads them.
    final choir = _choirRoom ?? (room.braziers.length >= 2 ? room : null);
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
  void _applySimurghTelegraph(DungeonCreature a, DungeonRoom room, double dt) {
    final g = room.guardian;
    // Raids used to be excluded here. The spots lookup already returns empty
    // when there are no braziers, so that guard was redundant once the arena
    // started carrying them.
    if (g == null || hasStar(g.starIndex)) return;
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

  // ── The room's reading (the HINT button, not a family verb) ──
  //
  // Insight stopped being a Mask verb in the §9.0 refit: it was the one verb
  // that dispensed INFORMATION, and information must not depend on who you
  // brought. Intelligence still buys the TIER where a room has tiers.

  void _cathedralReveal(DungeonCreature a, DungeonRoom room) {
    revealFlash = 0.6;
    revealTier = revealHintTier(a.member.statIntelligence);
    switch (room.id) {
      case 'scriptorium':
        // READ-ONLY. Everything this used to DO now happens when the fourth
        // torch takes; all that is left here is describing what is on the wall.
        if (!muralLit(room)) {
          _setBlockedHint('Too dark to read, the corners are unlit');
          return;
        }
        _setInsightHint(
          'The mural keeps two of the six stations, and they aren\'t next to '
          'each other',
        );
        return;
      case 'choir':
        if (hasStar(room.brazierStarIndex ?? 0)) {
          _setHint('The braziers keep their vigil, the rite is done');
          return;
        }
        // THE FORENSIC RITE (§6.1): the reading ASSISTS, it never answers,
        // and it no longer MARKS anything either — a question must not edit
        // the floor. The wax, soot and drift are physical evidence lying on
        // the iron, so they are marked from the moment you walk in (see
        // _resetCathedralState); this only says what they mean.
        // The deduced link is likewise gone: annotating a step of the rite is
        // the strongest thing insight ever did, and it did it invisibly on a
        // button press. If it comes back it should be a world verb.

        _setHint(
          revealTier >= 1
              ? 'Clues: the lowest wax burned longest, soot leans away from '
                    'what was already lit, and ash piles downwind'
              : 'The braziers still show the last rite\'s wax, soot and ash',
          4.4,
        );
        return;
      case 'cloister':
        if (hasStar(room.vineStarIndex ?? 1)) {
          _setHint('Every groove sits true, the garth is at peace', 3.4);
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
              ? 'One groove now shows which bed\'s burning must feed it'
              : revealTier >= 1
              ? 'Shallow bowls want drifting ash, deep brands want their own '
                    'fire, and swept rings want nothing. Every burn blows ash '
                    'downwind'
              : 'Each groove is a different shape, and the wind carries ash',
          4.4,
        );
        return;
      case 'vestry':
        _setHint(
          'The fresco shows flame travelling along the hanging chains, blown '
          'from censer to censer',
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
                    ? 'Two runs reach the bells. The nave is short but ash '
                          'smothers the flame. The cloister is long and calm, '
                          'with two more censers to keep lit'
                    : 'Two censer runs reach the bells, and they play very '
                          'differently')
              : (revealTier >= 1
                    ? 'Light a censer, then blow the flame on with Air before '
                          'it dies. Each censer it reaches relights it'
                    : 'Fire lights the censers. Air carries the flame'),
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
          'Three lights watch over the chancel gate. Ember, ash, and pyre',
          3.6,
        );
        return;
      case 'high_altar':
        _setHint('The black flame won\'t answer until the bells ring', 3.2);
        return;
      case 'sanctum':
        _setHint(
          guardianAwake
              ? 'The Simurgh\'s rage comes in waves. Strike in the lull'
              : 'An empty roost. Ringing the bells will call its guardian',
          3.6,
        );
        return;
    }
    _setHint(_nothingHiddenLine());
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
        return entryDoorRevealed ? null : 'Narthex. The great hearth is cold';
      case 'scriptorium':
        return hasStar(0)
            ? null
            : 'Scriptorium. The soot mural records part of the old rite';
      case 'choir':
        // WHAT, never HOW (§5.6): the rite's goal only. How to READ the
        // braziers is earned through Mask insight, or found by looking.
        return hasStar(0)
            ? null
            : 'Choir. Six braziers, lit in the order of the old rite';
      case 'cloister':
        // WHAT, never HOW (§5.6): the wind, the grooves and the order they
        // imply are Mask-insight content (_cathedralReveal) — and legible in
        // the stone for anyone patient — never room-entry copy.
        return hasStar(room.vineStarIndex ?? 1)
            ? null
            : 'Cloister. Six grooves in the garden, and a shifting wind';
      case 'vestry':
        return hasStar(2)
            ? null
            : 'Vestry. A charred fresco shows the vesper ahead';
      case 'bell_gallery':
        if (hasStar(2)) return null;
        return vesperRouteId == null && room.vesperRoutes.isNotEmpty
            ? 'Bell Gallery. Two censer runs lead to three silent bells'
            : 'Bell Gallery. Three bells, and a flame that keeps dying';
      case 'high_altar':
        return hasStar(2)
            ? null
            : 'High Altar. The black flame waits for the bells';
      case 'sanctum':
        return guardianAwake
            ? 'Sanctum. The Simurgh descends'
            : 'Sanctum. An empty roost. The bells haven\'t rung';
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
}
