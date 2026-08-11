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
//  • Star 2 (Ash) — the cloister's scorched beds: Plant grows vines, Fire
//    burns them (Plant+Fire→Dust), the settling ash reveals the sigil cut in
//    the groove beneath; each burn breathes out cinder wisps, angrier as the
//    garden bares. PARITY RULE: anything the Plant+Fire braid renders to
//    ash, a Dust creature lays directly.
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

/// Air's maxim: commune at the hub compass heart with all three stars.
const String kAirFirstWindEggId = 'egg:air_first_wind';

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

  // ── Update ──────────────────────────────────────────────

  void _resetCathedralState() {
    ritualProgress = 0;
    bedStates.clear();
    bellsRung.clear();
    _chainCheckpoints.clear();
    _vesperFlames.clear();
    _bedFx.clear();
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

  /// The cloister's ash garden (Star 2).
  bool _tryAshGarden(DungeonCreature a, DungeonRoom room) {
    final star = room.vineStarIndex;
    if (room.vineBeds.isEmpty || star == null || hasStar(star)) return false;
    VineBed? bed;
    var bestDist = 50.0;
    for (final b in room.vineBeds) {
      final d = (a.position - b.position).distance;
      if (d < bestDist) {
        bestDist = d;
        bed = b;
      }
    }
    if (bed == null) return false;
    final state = bedStates[bed.id] ?? 0;
    final element = a.member.element;

    if (state == 2) {
      _setHint('This sigil already burns in its groove');
      return true;
    }
    if (element == 'Plant' && state == 0) {
      bedStates[bed.id] = 1;
      _bedFx[bed.id] = 1.2;
      // ELEMENT-ONLY: any Plant lays the growth clean and silent.
      _setHint('Vines surge across the bed in one green breath');
      _spawnAlchemyBurst(
        bed.position,
        producedElement: 'Plant',
        reagentElements: [element],
        particleCount: 16,
        intensity: 0.8,
      );
      return true;
    }
    if (element == 'Fire' && state == 1) {
      bedStates[bed.id] = 2;
      _bedFx[bed.id] = 1.4;
      _spawnAlchemyBurst(
        bed.position,
        producedElement: 'Dust',
        reagentElements: const ['Plant', 'Fire'],
        particleCount: 24,
        intensity: 1.05,
      );
      final revealed = room.vineBeds
          .where((b) => (bedStates[b.id] ?? 0) == 2)
          .length;
      // The consequence layer: every burning bed breathes out cinders, and
      // the garden grows angrier with each sigil bared.
      spawnWispWave(
        element: 'Fire',
        center: bed.position,
        count: 3,
        unstable: revealed >= 3,
        announce: false,
      );
      if (revealed >= room.vineBeds.length) {
        earnStar(star);
      } else {
        // The count is STATE — it lives in the SIGILS readout (§5.6).
        _setHint('The vines char to ash — a sigil glows in its groove', 3.2);
      }
      return true;
    }
    // PARITY RULE: what the Plant+Fire braid renders to ash, Dust lays
    // directly — no growth, no burning.
    if (element == 'Dust') {
      bedStates[bed.id] = 2;
      _bedFx[bed.id] = 1.4;
      _spawnAlchemyBurst(
        bed.position,
        producedElement: 'Dust',
        particleCount: 20,
        intensity: 0.9,
      );
      final revealed = room.vineBeds
          .where((b) => (bedStates[b.id] ?? 0) == 2)
          .length;
      if (revealed >= room.vineBeds.length) {
        earnStar(star);
      } else {
        _setHint('Ash needs no fire — it settles straight into the groove', 3.2);
      }
      return true;
    }
    // §5.6 BLOCKED: one short clause naming what is missing, never a method.
    if (element == 'Fire' && state == 0) {
      _setBlockedHint('Bare scorched earth — nothing here will take');
      return true;
    }
    if (element == 'Plant' && state == 1) {
      _setBlockedHint('The vines are already thick');
      return true;
    }
    _setBlockedHint('This bed answers Plant, or Dust');
    return true;
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
        final hidden = room.vineBeds
            .where((b) => (bedStates[b.id] ?? 0) != 2)
            .length;
        _setHint(
          hidden > 0
              ? (revealTier >= 1
                    ? 'Grow the beds green, then give them to flame — the ash '
                          'settles into the groove and bares the sigil'
                    : 'Sigils lie cut beneath the beds, waiting on the ash')
              : 'Every groove burns — the garden has told all it knows',
          3.8,
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
    // S2 — the garden's bared sigils.
    final vine = room.vineStarIndex;
    if (vine != null && !hasStar(vine) && room.vineBeds.isNotEmpty) {
      final bared = room.vineBeds
          .where((b) => (bedStates[b.id] ?? 0) == 2)
          .length;
      return DungeonProgressReadout(
        label: 'SIGILS',
        value: '$bared/${room.vineBeds.length}',
        fraction: bared / room.vineBeds.length,
      );
    }
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
    // Garden beds.
    if (room.vineStarIndex != null && !hasStar(room.vineStarIndex!)) {
      for (final bed in room.vineBeds) {
        if ((a.position - bed.position).distance > 64) continue;
        final state = bedStates[bed.id] ?? 0;
        if (state == 0) {
          _setAmbientHint(
            a.member.element == 'Plant'
                ? 'The scorched bed tugs at your green'
                : 'A scorched bed, bare to the soot',
          );
        } else if (state == 1) {
          _setAmbientHint(
            a.member.element == 'Fire'
                ? 'The vines lean toward your flame'
                : 'The vines crowd thick over the bed',
          );
        }
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
        // WHAT, never HOW (§5.6): the grow-burn-read rite is Mask-insight
        // content (_cathedralReveal), not room-entry copy.
        return 'Cloister — the scorched beds keep their sigils';
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
        _drawDryFountain(canvas, room.bounds.center);
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

  void _drawVineBeds(Canvas canvas, DungeonRoom room) {
    final star = room.vineStarIndex;
    final done = star != null && hasStar(star);
    for (final bed in room.vineBeds) {
      final state = done ? 2 : (bedStates[bed.id] ?? 0);
      final fx = _bedFx[bed.id] ?? 0;
      final p = bed.position;
      // The bed itself: a soil plot with a scorched border.
      final plot = Rect.fromCenter(center: p, width: 110, height: 84);
      canvas.drawRRect(
        RRect.fromRectAndRadius(plot, const Radius.circular(12)),
        Paint()..color = const Color(0xFF15100B).withValues(alpha: 0.85),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(plot, const Radius.circular(12)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF4A382C).withValues(alpha: 0.7),
      );
      switch (state) {
        case 0:
          // Barren: scorch marks.
          final scorch = Paint()
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF33261D).withValues(alpha: 0.8);
          canvas.drawLine(p + const Offset(-26, -8), p + const Offset(-8, 6), scorch);
          canvas.drawLine(p + const Offset(6, -12), p + const Offset(22, 2), scorch);
          canvas.drawLine(p + const Offset(-4, 14), p + const Offset(14, 18), scorch);
          break;
        case 1:
          // Overgrown: vine curls.
          final vine = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF6FAF5A).withValues(alpha: 0.85);
          final sway = sin(_time * 1.8) * 3;
          for (var i = 0; i < 3; i++) {
            final ox = -28.0 + i * 26;
            final path = Path()
              ..moveTo(p.dx + ox, p.dy + 28)
              ..quadraticBezierTo(
                p.dx + ox - 12 + sway,
                p.dy + 2,
                p.dx + ox + 6 + sway,
                p.dy - 18 - i * 4,
              );
            canvas.drawPath(path, vine);
            canvas.drawCircle(
              Offset(p.dx + ox + 6 + sway, p.dy - 18 - i * 4),
              3,
              Paint()..color = const Color(0xFF8FCF6A).withValues(alpha: 0.9),
            );
          }
          if (fx > 0 && _fx.ready) {
            drawGlow(
              canvas,
              _fx.glow!,
              p,
              40,
              const Color(0xFF6FAF5A).withValues(alpha: 0.18 * fx),
            );
          }
          break;
        case 2:
          // Revealed: the ash-filled sigil glowing in its groove.
          final glowA = 0.5 + 0.22 * sin(_time * 2.2 + p.dx);
          if (_fx.ready) {
            drawGlow(
              canvas,
              _fx.glow!,
              p,
              44,
              const Color(0xFFFF8A50).withValues(alpha: 0.16 + 0.08 * glowA),
            );
          }
          final sig = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFFFB46B).withValues(alpha: 0.55 + 0.3 * glowA);
          canvas.drawCircle(p, 18, sig);
          final d = 18.0;
          canvas.drawPath(
            Path()
              ..moveTo(p.dx, p.dy - d)
              ..lineTo(p.dx + d, p.dy)
              ..lineTo(p.dx, p.dy + d)
              ..lineTo(p.dx - d, p.dy)
              ..close(),
            sig,
          );
          if (fx > 0 && _fx.ready) {
            drawGlow(
              canvas,
              _fx.glow!,
              p,
              58,
              const Color(0xFFFFD27A).withValues(alpha: 0.22 * fx),
            );
          }
          break;
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
