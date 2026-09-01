// lib/games/planet_dungeon/planet_dungeon_game_air.dart
//
// ZEPHYRIA — the Wind-Crown Spire, reworked (docs §6.11 REWORK / §9.1 item 4).
// Air was the pilot, so for five planets its puzzle logic lived loose in the
// shared engine. This file is the same `part of` treatment the other five
// planets get: Air's PUZZLE LOGIC (Star 1, Star 2's loom + trials, Star 3, the
// Roc retrofit) and its rework rendering live here; the fields stay in
// `PlanetDungeonGame` behind the `_isSpire` guard, and the chassis rendering
// Air bequeathed to every planet (room themes, floors, doors, the compass hub)
// stays in the engine where the other planets read it.
//
// World rule: *the spire is CALM, and the winds are yours to wake.*
//
//  • Star 1 (Wind) — WAKE THE WINDS. Nothing blows at the start. Each gust
//    shrine wakes one gale PERMANENTLY, and a woken gale pushes everything —
//    you, the wisps, the storm — so it is simultaneously the ladder to a ledge
//    footing could never reach and the wind that scours the walkway beside it.
//    The puzzle is the ORDER: wake the Ridge Riser before the First Breath and
//    you walk up the stair; wake them the other way round and the First
//    Breath's spill has scoured that stair away, and the ridge shrine is only
//    reachable the long way — up the thermal and back along the ledgewalk,
//    grinding into the same wind. NO ORDER CAN EVER STRAND YOU: every state
//    the player can reach still has a next move, proved exhaustively by
//    `solveWindWaking()` (`strandable == 0`) — and death resets the winds
//    besides, as redundancy rather than as the mechanism.
//  • Star 2 (Loom) — the five wonder-cloud trials and the Sky Loom. The SPIRAL
//    trial is reworked (§9.1): THE SPIRAL IS COMPOSED, NOT WALKED. Seven gale
//    vents ring a still eye; communing with one opens its jet PERMANENTLY for
//    the attempt — Star 1's irreversible wind-authoring, in miniature. Four
//    jets close the eye, but only if they COMPOSE: all tangent to the rim, all
//    turning the same way. Open a mouth that stabs inward or outward, or one
//    that turns against the coil, and the forming vortex is sheared apart in
//    front of you. Which way each mouth breathes is ROLLED PER RUN (so no wiki
//    can spoil it) and carved on its stone (so the choice is read, not
//    guessed); `solveSpiralVents()` proves every roll has exactly one answer.
//  • Star 3 (Storm) — STORM-ROD STEERING. Conduit A keeps its hard
//    Lightning+Horn gate and now LATCHES (the decay timers are gone, and with
//    them the Wing-only stabilize that existed only to beat them). Conduit B is
//    struck by the storm itself: a live cell circles the altar, and when it
//    discharges its leader climbs the rod field — leaping to the tallest iron
//    in reach that stands exactly ONE RANK above the iron it is on (see
//    `stormLeaderFrom` for why that clause is what makes it a puzzle). Rank the
//    field into a staircase that ends at B and the storm lights it for you.
//    Rank it wrong and the bolt dies on a rod: wild strike, storm wisps. Gusts
//    herd the cell so you choose where the climb begins.
//  • The Roc (§7) — the guardian DRAGS the cell across its own rod field. The
//    shared lull still turns, but only a bolt led into the bird opens a full
//    window: the fight is Star 3's vocabulary, played against something that
//    moves the storm on purpose.
//  • Lost Maxim — the FIRST WIND: with all three stars banked, commune at the
//    compass heart. Permanent, and it stays permanent.

part of 'planet_dungeon_game.dart';

/// Air's lost maxim discovery id (screen pays 20 gold on first find).
const String kAirFirstWindEggId = 'egg:air_first_wind';

// ── Star 1 · device-tunable knobs ──────────────────────────
// Air has never been device-tuned; every number the feel depends on is named
// here so a tuning pass is edit-one-file.

/// Seconds a woken gale takes to swell from stillness to full strength.
/// ANIMATED-STATE RULE: a wind never snaps on.
const double _kGaleWakeSeconds = 1.35;

/// How close a creature must stand to a gust shrine to commune with it.
const double _kShrineReach = 48.0;

/// Fraction of a gale's authored strength that a WALKER feels. Walkers are
/// carried, not flung; gliders take the full push.
const double _kGaleWalkerScale = 0.82;

/// Fraction a wisp/enemy feels — the gale pushes friend and foe alike, but the
/// spire does not want the consequence layer pinned against a wall.
const double _kGaleEnemyScale = 0.55;

/// Grace after a gale releases you before the fall begins (matches the thermal
/// coyote so both winds feel the same underfoot).
const double _kGaleCoyote = 0.35;

// ── Star 2 · the Gale Eye · device-tunable knobs ───────────

/// How close a creature must stand to a gale vent to commune with it. The
/// vents answer ANY hand (§4: no gate here — Air's one family gate is Star 3's
/// conduit A, and this trial keeps at least one echo open to every trio).
const double _kVentReach = 46.0;

/// Seconds an opened jet takes to swell to full. A wind never snaps on.
const double _kJetSwellSeconds = 0.9;

/// Seconds the shearing plays out for. The failure is WATCHED, not read.
const double _kSpiralTearSeconds = 1.6;

// ── Star 3 · device-tunable knobs ──────────────────────────

/// Radius within which an Air creature's gust shoves the storm-cell.
const double _kCellGustReach = 130.0;

/// Radians the cell is shoved along its ring per gust.
const double _kCellGustShove = 0.62;

/// How close you must stand to a storm-rod to crank it.
const double _kRodReach = 46.0;

/// Seconds a rod takes to grind up or down one rank (eased, never snapped).
const double _kRodEaseSeconds = 0.42;

/// Seconds the drawn leader-bolt stays on screen after a discharge.
const double _kLeaderFlashSeconds = 0.85;

/// Storm wisps spawned by a bolt that dies on a rod instead of a conduit.
const int _kWildStrikeWisps = 2;

/// How far behind the Roc its dragged storm-cell trails. Chosen against the
/// arena's rod ring: far enough that herding the cell is real work, close
/// enough that the ring can always take it somewhere.
const double _kRocLeash = 280.0;

/// The bolt's LAST leap, into the guardian. Longer than a leap between irons:
/// the Roc is a mountain of feathers with a storm already sitting on it. (The
/// one-rank rule still forbids the cell striking the bird directly — a leader
/// always begins on rank-0 iron.)
const double _kRocStrikeReach = 265.0;

/// How fast the dragged leash follows the bird (px/sec).
const double _kRocLeashSpeed = 210.0;

/// The forced vulnerability window a bolt led into the Roc buys.
const double _kRocStun = 3.2;
const double _kRocStunEnraged = 2.3;

/// A conductor's identity in the leader walk — a rod, a conduit, or the bird.
const String _kGuardianConductorId = 'guardian';

extension WindCrownSpire on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetSpireState() {
    if (!_isSpire) return;
    // Death resets the winds — the spire falls calm again, which is the
    // belt-and-braces behind `solveWindWaking()`'s no-strand proof.
    wokenGales.clear();
    galeRamp.clear();
    totalGales = allGaleIds.length;
    summitOpen = false;
    _galeRiding = false;
    rodHeight.clear();
    _rodRaise.clear();
    for (final room in layout.rooms.values) {
      for (final rod in room.stormRods) {
        rodHeight[rod.id] = rod.initialHeight;
        _rodRaise[rod.id] = rod.initialHeight.toDouble();
      }
    }
    stormCellAngle =
        layout.rooms.values
            .firstWhere(
              (r) => r.stormOrbit != null && r.conduits.isNotEmpty,
              orElse: () => layout.rooms.values.first,
            )
            .stormOrbit
            ?.startAngle ??
        0;
    stormStrikeTimer = 0;
    lastLeaderPath.clear();
    _leaderFlash = 0;
    latchedLeaderPath.clear();
    _latchedLeaderOrigin = null;
    _rocLeash = Offset.zero;
    _rocStunLeft = 0;
    // The Gale Eye's ring is authored; its winds are rolled fresh every run.
    _rollSpiralVents();
  }

  // ── Star 2 · THE GALE EYE (the Spiral, composed) ─────────

  /// The chamber that carries the vent ring (null off Air / in a raid arena).
  DungeonRoom? get _spiralChamber {
    for (final r in layout.rooms.values) {
      if (r.galeVents.isNotEmpty) return r;
    }
    return null;
  }

  /// The still point the vents ring — where the echo forms.
  Offset _spiralEye(DungeonRoom room) =>
      room.clouds.isNotEmpty ? room.clouds.first.position : room.bounds.center;

  /// The unit direction a vent breathes, given the eye it rings. Screen space
  /// (y down), so `(-r.dy, r.dx)` turns the way the sun crosses the crown.
  Offset spiralVentDirection(GaleVent v, Offset eye, GaleVentFlow flow) {
    final d = v.position - eye;
    final len = d.distance;
    final r = len < 1e-6 ? const Offset(1, 0) : d / len;
    return switch (flow) {
      GaleVentFlow.sunwise => Offset(-r.dy, r.dx),
      GaleVentFlow.widdershins => Offset(r.dy, -r.dx),
      GaleVentFlow.inward => -r,
      GaleVentFlow.outward => r,
    };
  }

  /// THE COMPOSITION RULE, in one place so the game and the proof can never
  /// differ: an eye braids only out of jets that all run TANGENT to the rim and
  /// all turn the SAME WAY. A radial jet (inward or outward) stabs the coil; a
  /// counter-turning jet shears it. Either one tears the forming vortex apart.
  ///
  /// Note what this is NOT: an order. The jets compose as a SET, so the trial
  /// can never be reduced to a memorised walk (§5.5 hands sequence-execution to
  /// Fire alone) — what it asks is which four winds you are willing to commit
  /// to, knowing none of them can be taken back.
  bool spiralComposes(Iterable<String> ventIds) {
    GaleVentFlow? coil;
    for (final id in ventIds) {
      final f = spiralVentFlow[id];
      if (f == null) return false;
      if (f != GaleVentFlow.sunwise && f != GaleVentFlow.widdershins) {
        return false;
      }
      if (coil == null) {
        coil = f;
      } else if (coil != f) {
        return false;
      }
    }
    return true;
  }

  /// Do these open jets close the eye? (Composing is necessary; four is the
  /// price.)
  bool spiralVortexClosed(Iterable<String> ventIds) =>
      ventIds.length >= kSpiralJetsNeeded && spiralComposes(ventIds);

  /// The coil the OPEN jets have already committed to (null while nothing
  /// tangential is blowing).
  GaleVentFlow? get spiralCoil {
    for (final id in spiralOpenJets) {
      final f = spiralVentFlow[id];
      if (f == GaleVentFlow.sunwise || f == GaleVentFlow.widdershins) return f;
    }
    return null;
  }

  /// The one coil this ring can actually braid — the handedness that owns at
  /// least [kSpiralJetsNeeded] mouths. Tier-2 Mask insight names it.
  GaleVentFlow? get spiralComposableCoil {
    var sun = 0;
    var wid = 0;
    for (final f in spiralVentFlow.values) {
      if (f == GaleVentFlow.sunwise) sun++;
      if (f == GaleVentFlow.widdershins) wid++;
    }
    if (sun >= kSpiralJetsNeeded) return GaleVentFlow.sunwise;
    if (wid >= kSpiralJetsNeeded) return GaleVentFlow.widdershins;
    return null;
  }

  // ── Star 2 · the roll, and the proof it is always solvable ──

  /// Roll THIS RUN'S vent ring. The shape is fixed and fair — [kSpiralJetsNeeded]
  /// mouths breathe the winning coil, two breathe against it (the near-miss you
  /// have to count past), one is radial (the mouth that tears the eye the
  /// instant it opens) — but WHICH mouth is which is random, so the answer
  /// cannot be written down anywhere but on the stone. A candidate is kept only
  /// when [solveSpiralVents] proves it admits exactly ONE answering set and
  /// that both named failures really do fail.
  void _rollSpiralVents() {
    spiralVentFlow.clear();
    _armGaleEye();
    _spiralLastRoom = null;
    final room = _spiralChamber;
    if (room == null) return;
    final vents = room.galeVents;
    if (vents.length <= kSpiralJetsNeeded) return;
    final rng = Random();
    for (var attempt = 0; attempt < 200; attempt++) {
      _plantSpiralFlows(vents, rng);
      final proof = solveSpiralVents();
      if (proof.solutions == 1 &&
          proof.coldVents > 0 &&
          proof.counterTears > 0) {
        return;
      }
    }
    // Unreachable in practice: every roll the planter can produce is valid by
    // construction (the test sweeps all 420 of them). Kept so the chamber can
    // never be left unplayable.
    spiralVentFlow.clear();
    for (var i = 0; i < vents.length; i++) {
      spiralVentFlow[vents[i].id] = i < kSpiralJetsNeeded
          ? GaleVentFlow.sunwise
          : i < vents.length - 1
          ? GaleVentFlow.widdershins
          : GaleVentFlow.inward;
    }
  }

  void _plantSpiralFlows(List<GaleVent> vents, Random rng) {
    final coil = rng.nextBool()
        ? GaleVentFlow.sunwise
        : GaleVentFlow.widdershins;
    final counter = coil == GaleVentFlow.sunwise
        ? GaleVentFlow.widdershins
        : GaleVentFlow.sunwise;
    final order = List<int>.generate(vents.length, (i) => i)..shuffle(rng);
    spiralVentFlow.clear();
    for (var i = 0; i < order.length; i++) {
      final id = vents[order[i]].id;
      spiralVentFlow[id] = i < kSpiralJetsNeeded
          ? coil
          : i < order.length - 1
          ? counter
          : (rng.nextBool() ? GaleVentFlow.inward : GaleVentFlow.outward);
    }
  }

  /// THE SPIRAL PROOF (§5.5 "prove it solvable" — the precedent of
  /// [solveWindWaking] and [solveRodRanking]).
  ///
  /// Brute-forces every ORDERED way to spend the four openings an attempt is
  /// worth, judged by the REAL mechanic functions ([spiralComposes] /
  /// [spiralVortexClosed]) — the same calls the vents make under a hand, so
  /// proof and gameplay cannot drift apart. Reports:
  ///  • `sequences` — ordered selections examined (`n·(n-1)·…`, k deep);
  ///  • `closing` — sequences that reach a closed eye without ever shearing;
  ///  • `solutions` — DISTINCT vent SETS that close it (must be exactly 1);
  ///  • `torn` / `radialTears` / `counterTears` — the sequences that shear, split
  ///    by which named failure did it (a mouth that stabs in or out, versus one
  ///    that turns against the coil);
  ///  • `coldVents` — mouths that shear the eye the instant they open, with
  ///    nothing yet blowing (the radial ones, and only those).
  ({
    int vents,
    int needed,
    int sequences,
    int closing,
    int solutions,
    int torn,
    int radialTears,
    int counterTears,
    int coldVents,
    List<String>? solution,
  })
  solveSpiralVents() {
    final room = _spiralChamber;
    if (room == null || spiralVentFlow.length != room.galeVents.length) {
      return (
        vents: 0,
        needed: kSpiralJetsNeeded,
        sequences: 0,
        closing: 0,
        solutions: 0,
        torn: 0,
        radialTears: 0,
        counterTears: 0,
        coldVents: 0,
        solution: null,
      );
    }
    final ids = [for (final v in room.galeVents) v.id];
    var sequences = 0;
    var closing = 0;
    var torn = 0;
    var radialTears = 0;
    var counterTears = 0;
    final sets = <String>{};
    List<String>? solution;

    void walk(List<String> chosen, List<String> left) {
      if (chosen.length == kSpiralJetsNeeded) {
        sequences++;
        var shearedAt = -1;
        for (var i = 1; i <= chosen.length; i++) {
          if (!spiralComposes(chosen.take(i))) {
            shearedAt = i - 1;
            break;
          }
        }
        if (shearedAt < 0 && spiralVortexClosed(chosen)) {
          closing++;
          final key = (List.of(chosen)..sort()).join(',');
          if (sets.add(key)) solution = List.of(chosen)..sort();
          return;
        }
        torn++;
        final f = spiralVentFlow[chosen[shearedAt < 0 ? 0 : shearedAt]];
        if (f == GaleVentFlow.inward || f == GaleVentFlow.outward) {
          radialTears++;
        } else {
          counterTears++;
        }
        return;
      }
      for (var i = 0; i < left.length; i++) {
        walk([...chosen, left[i]], [...left]..removeAt(i));
      }
    }

    walk(const [], ids);

    // The mouths that tear a coil that has not yet begun — asked of the real
    // rule, never assumed from the roll's shape.
    var coldVents = 0;
    for (final id in ids) {
      if (!spiralComposes([id])) coldVents++;
    }

    return (
      vents: ids.length,
      needed: kSpiralJetsNeeded,
      sequences: sequences,
      closing: closing,
      solutions: sets.length,
      torn: torn,
      radialTears: radialTears,
      counterTears: counterTears,
      coldVents: coldVents,
      solution: solution,
    );
  }

  // ── Star 2 · play ────────────────────────────────────────

  /// Shut every jet and let the eye settle — a fresh attempt. NO SOFTLOCK IS
  /// STRUCTURALLY POSSIBLE: the only irreversible thing here is irreversible
  /// *within the room*, and the chamber's one door is never locked, so walking
  /// out and back in always re-arms the trial. Death re-rolls it besides.
  void _armGaleEye() {
    spiralOpenJets.clear();
    spiralJetRamp.clear();
    _spiralShearedVent = null;
    spiralTorn = false;
    _spiralTearFlash = 0;
  }

  /// Per-frame: swell the open jets, run the tear animation, and re-arm the
  /// chamber whenever it is ENTERED. Cheap — one map walk over at most four
  /// ids, and nothing at all outside the chamber.
  void _updateSpiralChamber(DungeonRoom room, double dt) {
    if (_spiralLastRoom != room.id) {
      _spiralLastRoom = room.id;
      // Entering is the edge: the vents were shut behind you when you left.
      if (room.galeVents.isNotEmpty) _armGaleEye();
    }
    if (_spiralTearFlash > 0) _spiralTearFlash -= dt;
    if (spiralOpenJets.isEmpty) return;
    final step = dt / _kJetSwellSeconds;
    for (final id in spiralOpenJets) {
      final v = spiralJetRamp[id] ?? 0.0;
      if (v < 1.0) spiralJetRamp[id] = min(1.0, v + step);
    }
  }

  /// Commune with the gale vent underfoot. ANY hand opens it — the mouths are
  /// the chamber's own voice, exactly like Star 1's shrines.
  bool _trySpiralVent(DungeonCreature a, HiddenCloud sealed) {
    final room = currentRoom;
    if (room.galeVents.isEmpty) return false;
    for (final v in room.galeVents) {
      if ((a.position - v.position).distance > _kVentReach) continue;
      if (spiralTorn) {
        // §5.6 BLOCKED: one clause, naming the state, never the method.
        _setBlockedHint('The eye is unmade — this air is spent');
        return true;
      }
      if (spiralOpenJets.contains(v.id)) {
        _setHint('${_capitalise(v.name)} already blows', 2.2);
        return true;
      }
      _openSpiralJet(room, v, sealed);
      return true;
    }
    return false;
  }

  void _openSpiralJet(DungeonRoom room, GaleVent v, HiddenCloud sealed) {
    spiralOpenJets.add(v.id);
    spiralJetRamp[v.id] = 0.0;
    _spawnAlchemyBurst(
      v.position,
      producedElement: 'Air',
      reagentElements: const ['Air', 'Spirit'],
      particleCount: 18,
      intensity: 0.85,
    );
    if (!spiralComposes(spiralOpenJets)) {
      // The failure you WATCH: the coil comes apart at the eye.
      spiralTorn = true;
      _spiralShearedVent = v.id;
      _spiralTearFlash = _kSpiralTearSeconds;
      _setBlockedHint('The eye shears apart');
      _spawnAlchemyBurst(
        _spiralEye(room),
        producedElement: 'Air',
        reagentElements: const ['Spirit'],
        unstable: true,
        particleCount: 26,
        intensity: 1.15,
      );
      onChanged();
      return;
    }
    if (spiralVortexClosed(spiralOpenJets)) {
      _completeWonderTrial(
        sealed,
        'Four winds braid one eye — the Spiral echo awakens',
      );
    } else {
      // Progress is STATE, not speech (§5.6): the count lives in the readout.
      _setHint('${_capitalise(v.name)} opens — and will not shut', 2.6);
    }
    onChanged();
  }

  /// Mask insight for the Gale Eye — the only channel allowed to teach method.
  String _spiralInsight(int tier) {
    if (tier >= 2) {
      final coil = spiralComposableCoil;
      if (coil == null) return 'Nothing in this ring will hold an eye';
      final hand = coil == GaleVentFlow.sunwise ? 'sunwise' : 'widdershins';
      return 'Four of these mouths breathe $hand — the rest will shear the eye';
    }
    if (tier >= 1) {
      return 'An eye braids only from jets that skirt the rim the same way, '
          'and no mouth you open will shut again';
    }
    return 'Seven mouths, one eye — and the eye is particular';
  }

  // ── Star 1 · the wind graph ──────────────────────────────

  /// Every gust shrine in the spire, in no particular order.
  List<GustShrine> get allGustShrines => [
    for (final r in layout.rooms.values) ...r.gustShrines,
  ];

  /// Gales the spire can be taught to blow.
  Set<String> get allGaleIds => {for (final s in allGustShrines) s.wakesGale};

  /// How far a woken gale has swelled (0 = still, 1 = full). Eased.
  double _galeFactor(WindCurrent c) {
    final id = c.galeId;
    if (id == null) return 1.0;
    return galeRamp[id] ?? 0.0;
  }

  /// Is [c] a gale that is at least stirring?
  bool _currentLive(WindCurrent c) => _galeFactor(c) > 0.01;

  /// Stone that a live SIDEWAYS gale is sweeping. Standable, but never
  /// remembered as safe footing: a fall-recovery target inside the wind that
  /// caused the fall is a loop, not a consequence.
  bool _onScouredFooting(Offset p, DungeonRoom room) {
    for (final cur in room.currents) {
      if (cur.strength <= 0 || _galeFactor(cur) <= 0.01) continue;
      final len = cur.dir.distance;
      if (len <= 0 || cur.dir.dy / len <= -0.5) continue; // a lift, not a shove
      if (cur.rect.contains(p)) return true;
    }
    return false;
  }

  void _updateGaleRamps(double dt) {
    if (wokenGales.isEmpty) return;
    final step = dt / _kGaleWakeSeconds;
    for (final id in wokenGales) {
      final v = galeRamp[id] ?? 0.0;
      if (v < 1.0) galeRamp[id] = min(1.0, v + step);
    }
  }

  // ── Star 1 · the solver (the proof the design cannot drift) ──

  /// Door edges derived from the layout itself: a door standing on ledge X
  /// whose target spawn lands on ledge Y is an edge X → Y. Derived, never
  /// authored, so a moved door can never silently break the proof.
  List<(String, String)> get _windDoorEdges {
    final edges = <(String, String)>[];
    for (final room in layout.rooms.values) {
      if (room.windLedges.isEmpty) continue;
      for (final door in room.doors) {
        final from = room.windLedges
            .where((l) => l.rect.overlaps(door.rect))
            .firstOrNull;
        if (from == null) continue;
        final target = layout.rooms[door.targetRoomId];
        if (target == null) continue;
        final to = target.windLedges
            .where((l) => l.rect.inflate(2).contains(door.targetSpawn))
            .firstOrNull;
        if (to == null) continue;
        edges.add((from.id, to.id));
      }
    }
    return edges;
  }

  List<WindRoute> get _allWindRoutes => [
    for (final r in layout.rooms.values) ...r.windRoutes,
  ];

  /// The ledge the descent starts from — the one carrying the door back to the
  /// hub, i.e. the ledge the spire is entered on.
  String get windEntryLedgeId {
    for (final room in layout.rooms.values) {
      for (final door in room.doors) {
        if (door.targetRoomId != 'hub') continue;
        final l = room.windLedges
            .where((x) => x.rect.overlaps(door.rect))
            .firstOrNull;
        if (l != null) return l.id;
      }
    }
    return layout.rooms.values
        .firstWhere((r) => r.windLedges.isNotEmpty)
        .windLedges
        .first
        .id;
  }

  /// Every ledge reachable with [woken] gales blowing, and whether reaching it
  /// forced a COSTLY route (a scoured slide or scarp — a fall and a climb).
  ///
  /// This is the whole model the game plays by: the plain walkways are real
  /// footing, the gale rides exist only while their wind blows, and a swept
  /// route is authored so the sweeping gale's own rects lie over it — so the
  /// physics produce exactly what this walk claims.
  ({Set<String> reachable, Set<String> free}) windReachability(
    Set<String> woken, {
    String? from,
  }) {
    final start = from ?? windEntryLedgeId;
    final routes = _allWindRoutes;
    final doors = _windDoorEdges;
    final reachable = <String>{start};
    final free = <String>{start};
    var grew = true;
    while (grew) {
      grew = false;
      void link(String a, String b, bool costly) {
        if (!reachable.contains(a)) return;
        if (reachable.add(b)) grew = true;
        if (!costly && free.contains(a) && free.add(b)) grew = true;
      }

      for (final r in routes) {
        if (!r.openWith(woken)) continue;
        link(r.from, r.to, r.costly);
        if (r.twoWay) link(r.to, r.from, r.costly);
      }
      for (final (a, b) in doors) {
        link(a, b, false);
      }
    }
    return (reachable: reachable, free: free);
  }

  /// THE NO-STRAND PROOF (§6.11: "never a softlock").
  ///
  /// Two separate questions, both answered exhaustively:
  ///
  ///  1. **Can any wake order strand you?** `strandable` counts reachable
  ///     part-woken states from which NOTHING can be done — no un-woken shrine
  ///     is reachable and the crown is not reachable either. **It must be
  ///     zero.** (A state where some shrine is out of reach is fine as long as
  ///     another one isn't: the spire always offers a next move.) Death resets
  ///     the winds besides, but a design that relies on dying is not a design.
  ///  2. **Does the order matter?** `achievable` counts the permutations you
  ///     could actually perform (the rest are impossible, not fatal — the ledge
  ///     simply isn't reachable yet), and `fallFree` counts those that never
  ///     force a COSTLY route. A wrong order is never lethal; it is expensive.
  ({
    int orders,
    int achievable,
    int fallFree,
    int strandable,
    List<List<String>> fallFreeOrders,
  })
  solveWindWaking() {
    final shrines = allGustShrines;
    final ids = [for (final s in shrines) s.id]..sort();
    final byId = {for (final s in shrines) s.id: s};
    final crown = _crownDoorLedgeId;

    var orders = 0;
    var achievable = 0;
    var fallFree = 0;
    var strandable = 0;
    final fallFreeOrders = <List<String>>[];

    void walk(List<String> order, List<String> left) {
      if (left.isEmpty) {
        orders++;
        final woken = <String>{};
        var ok = true;
        var clean = true;
        for (final id in order) {
          final s = byId[id]!;
          final reach = windReachability(woken);
          if (!reach.reachable.contains(s.ledgeId)) {
            ok = false;
            break;
          }
          if (!reach.free.contains(s.ledgeId)) clean = false;
          woken.add(s.wakesGale);
        }
        if (ok) {
          final end = windReachability(woken);
          ok = crown == null || end.reachable.contains(crown);
          if (crown != null && !end.free.contains(crown)) clean = false;
        }
        if (ok) {
          achievable++;
          if (clean) {
            fallFree++;
            fallFreeOrders.add(List.of(order));
          }
        }
        return;
      }
      for (var i = 0; i < left.length; i++) {
        walk([...order, left[i]], [...left]..removeAt(i));
      }
    }

    walk(const [], ids);

    // The strand audit. Explores every state the player can actually get into
    // (a woken-set is reachable only if some legal sequence produced it) and
    // asks the only question that matters: is there a NEXT MOVE?
    final seen = <String>{};
    void explore(Set<String> woken) {
      final key = (woken.toList()..sort()).join(',');
      if (!seen.add(key)) return;
      final reach = windReachability(woken);
      var moved = false;
      for (final s in shrines) {
        if (woken.contains(s.wakesGale)) continue;
        if (!reach.reachable.contains(s.ledgeId)) continue;
        moved = true;
        explore({...woken, s.wakesGale});
      }
      // No shrine left to wake is fine ONLY if the crown is standing open and
      // reachable; anything else with no next move is a strand.
      if (!moved) {
        final done = woken.length >= shrines.length;
        final crownOk =
            crown == null || (done && reach.reachable.contains(crown));
        if (!crownOk) strandable++;
      }
    }

    explore(<String>{});

    return (
      orders: orders,
      achievable: achievable,
      fallFree: fallFree,
      strandable: strandable,
      fallFreeOrders: fallFreeOrders,
    );
  }

  /// The ledge carrying the door up to the crown room (Star 1's goal).
  String? get _crownDoorLedgeId {
    final summitRoom = layout.rooms.values
        .where((r) => r.summit != null)
        .firstOrNull;
    if (summitRoom == null) return null;
    for (final room in layout.rooms.values) {
      if (room.windLedges.isEmpty) continue;
      for (final door in room.doors) {
        if (door.targetRoomId != summitRoom.id) continue;
        final l = room.windLedges
            .where((x) => x.rect.overlaps(door.rect))
            .firstOrNull;
        if (l != null) return l.id;
      }
    }
    return null;
  }

  // ── Star 1 · play ────────────────────────────────────────

  /// Commune with the gust shrine underfoot. ELEMENT-ONLY in the strongest
  /// sense: the spire answers ANYONE — the shrines are the planet's own voice,
  /// not a family lock.
  bool _tryGustShrine(DungeonCreature a) {
    if (!_isSpire || hasStar(0)) return false;
    for (final s in currentRoom.gustShrines) {
      if ((a.position - s.position).distance > _kShrineReach) continue;
      if (wokenGales.contains(s.wakesGale)) {
        _setHint('${_capitalise(s.name)} already blows', 2.2);
        return true;
      }
      _wakeGale(s);
      return true;
    }
    return false;
  }

  void _wakeGale(GustShrine s) {
    wokenGales.add(s.wakesGale);
    galeRamp[s.wakesGale] = 0.0;
    _setHint('${_capitalise(s.name)} wakes — and will not sleep again', 3.4);
    _spawnAlchemyBurst(
      s.position,
      producedElement: 'Air',
      reagentElements: const ['Air', 'Spirit'],
      particleCount: 26,
      intensity: 1.0,
    );
    if (wokenGales.length >= totalGales && !summitOpen) {
      summitOpen = true;
      _setObjectiveHint('Every wind blows — the crown stands open', 3.4);
    }
    onChanged();
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _updateWinds(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isSpire) return;
    _updateGaleRamps(dt);
    if (_roomCleared(room)) return;

    // The crown: every wind blowing, and a creature standing in it.
    final summit = room.summit;
    if (summit != null &&
        summitOpen &&
        summit.rect.contains(a.position) &&
        !hasStar(summit.starIndex)) {
      earnStar(summit.starIndex);
    }
  }

  /// A woken gale carries WALKERS too — that is what makes it a ladder. Called
  /// from the shared `_applyCurrents` for the non-updraft gales (the rising
  /// columns are already handled by the thermal path).
  void _applyGaleToWalker(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isSpire) return;
    var carried = false;
    for (final cur in room.currents) {
      if (cur.strength <= 0) continue;
      final f = _galeFactor(cur);
      if (f <= 0.01) continue;
      final len = cur.dir.distance;
      if (len <= 0) continue;
      // Rising columns are the thermal's business (`_updraftAt`).
      if (cur.dir.dy / len <= -0.5) continue;
      if (!cur.rect.contains(a.position)) continue;
      final push = (cur.dir / len) * cur.strength * f * _kGaleWalkerScale * dt;
      a.position = _moveDashing(a.position, push, room);
      carried = true;
    }
    _galeRiding = carried;
    if (carried) _updraftCoyote = _kGaleCoyote;
  }

  /// The gale pushes FRIEND AND FOE. Wisps drift on the spire's winds exactly
  /// as the party does — one loop, no per-frame allocation.
  void _applyGalesToEnemies(DungeonRoom room, double dt) {
    if (!_isSpire || combatEnemies.isEmpty) return;
    for (final cur in room.currents) {
      if (cur.strength <= 0) continue;
      final f = _galeFactor(cur);
      if (f <= 0.01) continue;
      final len = cur.dir.distance;
      if (len <= 0) continue;
      final step = cur.strength * f * _kGaleEnemyScale * dt;
      final dx = cur.dir.dx / len * step;
      final dy = cur.dir.dy / len * step;
      for (final e in combatEnemies) {
        if (e.isDead) continue;
        if (!cur.rect.contains(e.position)) continue;
        e.position = Offset(e.position.dx + dx, e.position.dy + dy);
      }
    }
  }

  // ── Star 3 · the storm-cell and the rod field ────────────

  /// Where the cell hangs right now in [room].
  Offset? stormCellPosition(DungeonRoom room) {
    final orbit = room.stormOrbit;
    if (orbit == null) return null;
    final centre = (room.guardian != null && _rocLeash != Offset.zero)
        ? _rocLeash
        : orbit.center;
    return centre +
        Offset(
          cos(stormCellAngle) * orbit.radius,
          sin(stormCellAngle) * orbit.radius,
        );
  }

  /// Every conductor the leader may climb in [room], as (id, position, rank).
  /// Rods rank 0..3; a struck conduit — and the guardian, which is a mountain
  /// of feathers with a storm on it — stand one rank above every rod.
  List<(String, Offset, int)> _conductors(
    DungeonRoom room, {
    Map<String, int>? heights,
    Offset? guardianAt,
  }) {
    final out = <(String, Offset, int)>[];
    for (final rod in room.stormRods) {
      final h = heights?[rod.id] ?? rodHeight[rod.id] ?? 0;
      out.add((rod.id, rod.position, h));
    }
    for (final c in room.conduits) {
      if (!c.struckByStorm) continue;
      out.add((c.id, c.position, kConduitConductorHeight));
    }
    if (guardianAt != null) {
      out.add((_kGuardianConductorId, guardianAt, kConduitConductorHeight));
    }
    return out;
  }

  /// THE LEADER RULE, in one place so the game and the proof can never differ:
  /// from where it stands, the bolt leaps to the TALLEST conductor within
  /// [kStormHopReach] — but it can only climb ONE RANK at a time, because that
  /// is all the potential a single leap can bridge. So the candidates at each
  /// step are the conductors exactly one rank above the current one, and the
  /// leader takes the nearest of those. It stops where nothing one rank higher
  /// is in reach, and it begins on rank 0 (the storm comes down to the low
  /// iron first, then climbs).
  ///
  /// That "one rank at a time" clause is what makes the rod field a PUZZLE
  /// rather than a formality: with a plain tallest-in-reach rule any rod
  /// adjacent to conduit B would hand the storm the conduit for free, whatever
  /// you did with the rest of the field. Ranked wrong, the bolt strands on a
  /// plateau — which is exactly the wild strike the design wants.
  ///
  /// Returns the ids it climbed, in order. The LAST id is what it struck.
  List<String> stormLeaderFrom(
    Offset from,
    DungeonRoom room, {
    Map<String, int>? heights,
    Offset? guardianAt,
  }) {
    final conductors = _conductors(
      room,
      heights: heights,
      guardianAt: guardianAt,
    );
    final path = <String>[];
    var at = from;
    var rank = -1;
    while (true) {
      String? bestId;
      Offset? bestPos;
      var bestDist = double.infinity;
      final want = rank + 1;
      for (final (id, pos, h) in conductors) {
        if (h != want) continue;
        if (path.contains(id)) continue;
        final d = (pos - at).distance;
        final reach = id == _kGuardianConductorId
            ? _kRocStrikeReach
            : kStormHopReach;
        if (d > reach) continue;
        if (d < bestDist) {
          bestId = id;
          bestPos = pos;
          bestDist = d;
        }
      }
      if (bestId == null) break;
      path.add(bestId);
      at = bestPos!;
      rank = want;
    }
    return path;
  }

  /// THE ROD PROOF (§6.11: "prove it with a public solver").
  ///
  /// Brute-forces every rod ranking (`(max+1)^rods`) against every quantised
  /// cell position on the orbit, using the real [stormLeaderFrom]. Reports:
  ///  • `routing` — (ranking, angle) pairs whose leader terminates on conduit B;
  ///  • `solvable` — rankings that route from SOME angle (the valid family);
  ///  • `flatRouting` / `plateauRouting` — the two mis-rankings the design
  ///    claims must fail everywhere: all rods down, and all rods at full height
  ///    (a plateau the leader cannot climb).
  /// `example` is the cheapest valid ranking (fewest total cranks).
  ({
    int rankings,
    int angles,
    int routing,
    int solvable,
    int flatRouting,
    int plateauRouting,
    Map<String, int>? example,
    int exampleCranks,
  })
  solveRodRanking({int angleSteps = 72}) {
    final room = layout.rooms.values.firstWhere(
      (r) => r.stormRods.isNotEmpty && r.conduits.any((c) => c.struckByStorm),
    );
    final orbit = room.stormOrbit!;
    final rods = room.stormRods;
    final target = room.conduits.firstWhere((c) => c.struckByStorm).id;
    final steps = kStormRodMaxHeight + 1;
    var rankings = 1;
    for (var i = 0; i < rods.length; i++) {
      rankings *= steps;
    }

    var routing = 0;
    var solvable = 0;
    var flatRouting = 0;
    var plateauRouting = 0;
    Map<String, int>? example;
    var exampleCranks = 1 << 30;

    final heights = <String, int>{};
    for (var mask = 0; mask < rankings; mask++) {
      var m = mask;
      var cranks = 0;
      var allFlat = true;
      var allMax = true;
      for (final rod in rods) {
        final h = m % steps;
        m ~/= steps;
        heights[rod.id] = h;
        cranks += h;
        if (h != 0) allFlat = false;
        if (h != kStormRodMaxHeight) allMax = false;
      }
      var hits = 0;
      for (var s = 0; s < angleSteps; s++) {
        final angle = s * 2 * pi / angleSteps;
        final from = orbit.positionAt(angle);
        final path = stormLeaderFrom(from, room, heights: heights);
        if (path.isNotEmpty && path.last == target) hits++;
      }
      routing += hits;
      if (hits > 0) {
        solvable++;
        if (cranks < exampleCranks) {
          exampleCranks = cranks;
          example = Map.of(heights);
        }
      }
      if (allFlat) flatRouting = hits;
      if (allMax) plateauRouting = hits;
    }

    return (
      rankings: rankings,
      angles: angleSteps,
      routing: routing,
      solvable: solvable,
      flatRouting: flatRouting,
      plateauRouting: plateauRouting,
      example: example,
      exampleCranks: example == null ? 0 : exampleCranks,
    );
  }

  /// Crank the storm-rod underfoot one rank (wrapping at the top). ELEMENT-ONLY
  /// (§4): any Air creature works the rods, at full power.
  bool _tryStormRod(DungeonCreature a) {
    if (!_isSpire) return false;
    final room = currentRoom;
    if (room.stormRods.isEmpty) return false;
    for (final rod in room.stormRods) {
      if ((a.position - rod.position).distance > _kRodReach) continue;
      if (a.member.element != 'Air') {
        _setBlockedHint('The rods answer Air alone');
        return true;
      }
      final next = ((rodHeight[rod.id] ?? 0) + 1) % (kStormRodMaxHeight + 1);
      rodHeight[rod.id] = next;
      _spawnAlchemyBurst(
        rod.position,
        producedElement: 'Air',
        reagentElements: const ['Lightning'],
        particleCount: 12,
        intensity: 0.6,
      );
      onChanged();
      return true;
    }
    return false;
  }

  /// Herd the storm-cell with a gust — Air's own verb, the same one that bears
  /// a flame down a censer chain. The cell is shoved along its ring, away from
  /// the gust, so YOU choose where the leader begins its climb.
  bool _tryHerdCell(DungeonCreature a) {
    if (!_isSpire) return false;
    final room = currentRoom;
    final cell = stormCellPosition(room);
    if (cell == null) return false;
    if ((a.position - cell).distance > _kCellGustReach) return false;
    if (a.member.element != 'Air') {
      _setBlockedHint('Only Air can shove the storm');
      return true;
    }
    final orbit = room.stormOrbit!;
    final centre = (room.guardian != null && _rocLeash != Offset.zero)
        ? _rocLeash
        : orbit.center;
    // Shove it the way it is already leaning away from the gust.
    final toCell = cell - a.position;
    final tangent = Offset(-(cell - centre).dy, (cell - centre).dx);
    final sign = (toCell.dx * tangent.dx + toCell.dy * tangent.dy) >= 0
        ? 1
        : -1;
    stormCellAngle += _kCellGustShove * sign;
    _spawnAlchemyBurst(
      cell,
      producedElement: 'Air',
      reagentElements: const ['Lightning'],
      particleCount: 14,
      intensity: 0.7,
    );
    onChanged();
    return true;
  }

  void _updateStormCell(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isSpire) return;
    final orbit = room.stormOrbit;
    if (orbit == null || _roomCleared(room)) return;
    if (_leaderFlash > 0) _leaderFlash -= dt;

    // Rods grind toward their rank — eased, never snapped.
    if (room.stormRods.isNotEmpty) {
      final step = dt / _kRodEaseSeconds;
      for (final rod in room.stormRods) {
        final want = (rodHeight[rod.id] ?? 0).toDouble();
        final have = _rodRaise[rod.id] ?? want;
        _rodRaise[rod.id] = have < want
            ? min(want, have + step)
            : max(want, have - step);
      }
    }

    // At the altar the storm only wakes once the rite is unsealed; in the
    // guardian's arena it is the bird's own weather and always turns.
    final atAltar = room.guardian == null;
    if (atAltar && (!guardianRiteUnlocked || altarOpen)) return;
    if (!atAltar && !guardianAwake) return;

    stormCellAngle += dt * 2 * pi / max(0.5, orbit.period);
    stormStrikeTimer += dt;
    if (stormStrikeTimer < orbit.strikeInterval) return;
    stormStrikeTimer = 0;
    _dischargeStorm(room);
  }

  void _dischargeStorm(DungeonRoom room) {
    final from = stormCellPosition(room);
    if (from == null) return;
    final g = room.guardian;
    final guardianAt = (g != null && guardianAwake && !hasStar(g.starIndex))
        ? _guardianPosition(g)
        : null;
    final path = stormLeaderFrom(from, room, guardianAt: guardianAt);
    lastLeaderPath
      ..clear()
      ..addAll(path);
    _leaderFlash = _kLeaderFlashSeconds;
    if (path.isEmpty) {
      // Nothing in reach — the bolt gutters out over open air.
      _spawnAlchemyBurst(
        from,
        producedElement: 'Lightning',
        reagentElements: const ['Air'],
        particleCount: 10,
        intensity: 0.45,
      );
      onChanged();
      return;
    }
    final struck = path.last;
    final conduit = room.conduits
        .where((c) => c.struckByStorm && c.id == struck)
        .firstOrNull;
    if (conduit != null) {
      _energizeConduit(conduit.id);
      // The winning ladder LATCHES with the conduit it fed: from here the
      // chain keeps burning, so the room shows the answer it was given.
      latchedLeaderPath
        ..clear()
        ..addAll(path);
      _latchedLeaderOrigin = from;
      _setHint(
        'The storm finds the ladder — conduit ${conduit.id} takes the '
        'bolt',
      );
      _spawnAlchemyBurst(
        conduit.position,
        producedElement: 'Lightning',
        reagentElements: const ['Air', 'Fire'],
        particleCount: 30,
        intensity: 1.25,
      );
      onChanged();
      return;
    }
    if (struck == _kGuardianConductorId) {
      _rocStunLeft = _rocEnraged ? _kRocStunEnraged : _kRocStun;
      _setHint('The bolt climbs into the Roc — it reels', 2.6);
      _spawnAlchemyBurst(
        guardianAt ?? from,
        producedElement: 'Lightning',
        reagentElements: const ['Air'],
        unstable: true,
        particleCount: 28,
        intensity: 1.2,
      );
      onChanged();
      return;
    }
    // A wild strike: the bolt died on a rod. The consequence layer answers.
    final rod = room.stormRods.where((r) => r.id == struck).firstOrNull;
    final at = rod?.position ?? from;
    _spawnAlchemyBurst(
      at,
      producedElement: 'Lightning',
      reagentElements: const ['Air'],
      unstable: true,
      particleCount: 20,
      intensity: 0.95,
    );
    spawnWispWave(
      element: 'Lightning',
      center: at,
      count: _kWildStrikeWisps,
      unstable: true,
      announce: false,
    );
    onChanged();
  }

  // ── The Roc (§7): it drags the storm across its own rod field ──

  void _applyRocDrag(DungeonRoom room, double dt) {
    final g = room.guardian;
    // Raids used to be excluded here. The empty-rod-field check already
    // covers any arena without a field, so the raid guard was redundant once
    // the arena started generating one.
    if (g == null || room.stormRods.isEmpty) return;
    if (hasStar(g.starIndex)) return;
    final bird = _guardianPosition(g);
    // The cell trails the bird on a leash: it can never reach the Roc unaided.
    final want =
        bird +
        (_rocLeash == Offset.zero
            ? const Offset(-_kRocLeash, 0)
            : ((_rocLeash - bird).distance < 1
                  ? const Offset(-_kRocLeash, 0)
                  : (_rocLeash - bird) /
                        (_rocLeash - bird).distance *
                        _kRocLeash));
    if (_rocLeash == Offset.zero) {
      _rocLeash = want;
    } else {
      final d = want - _rocLeash;
      final len = d.distance;
      final step = _kRocLeashSpeed * dt;
      _rocLeash = len <= step ? want : _rocLeash + d / len * step;
    }
    // A bolt led into the bird forces a window the shared cycle never would.
    if (_rocStunLeft > 0) {
      _rocStunLeft -= dt;
      guardianVulnerable = true;
    }
  }

  // ── Hints (§5.6) ─────────────────────────────────────────

  /// Goal only — never method. The method lives behind Mask insight.
  String? _spireObjectiveHint(DungeonRoom room) {
    if (room.gustShrines.isNotEmpty && !hasStar(0)) {
      return 'A gust shrine sleeps here';
    }
    if (room.summit != null && !hasStar(0)) {
      return summitOpen
          ? 'The crown stands open'
          : 'The crown waits on every wind';
    }
    if (room.guardian != null) {
      return hasStar(2) ? null : 'Something enormous is riding the storm';
    }
    if (room.stormRods.isNotEmpty) {
      return 'The twin conduits sleep';
    }
    return null;
  }

  void _spireAmbientHint(DungeonCreature a, DungeonRoom room) {
    if (room.gustShrines.isNotEmpty) {
      _setAmbientHint(
        wokenGales.isEmpty
            ? 'The spire holds its breath'
            : 'Somewhere above, the spire is breathing',
      );
      return;
    }
    if (room.stormRods.isNotEmpty) {
      _setAmbientHint('The iron up here hums before it rains');
    }
  }

  /// Mask insight, tiered — the ONLY channel allowed to teach method.
  String _spireWindInsight(DungeonRoom room, int tier) {
    if (tier < 1) {
      return 'The shrines answer, but the winds keep their order secret';
    }
    if (tier >= 2) {
      // Tier 2 marks the answer: which walk each sleeping wind will scour.
      final threats = <String>[];
      for (final r in _allWindRoutes) {
        for (final g in r.sweptBy) {
          if (wokenGales.contains(g)) continue;
          final shrine = allGustShrines
              .where((s) => s.wakesGale == g)
              .firstOrNull;
          if (shrine == null) continue;
          threats.add(
            '${_capitalise(shrine.name)} will scour a walk you '
            'still need',
          );
        }
      }
      return threats.isEmpty
          ? 'Nothing left to wake will bar your road'
          : threats.first;
    }
    return 'Every wind you wake blows for good — and blows on the walkways '
        'too';
  }

  String _spireStormInsight(DungeonRoom room, int tier) => tier >= 2
      ? 'The bolt climbs: from where it hangs it leaps to the tallest iron '
            'in reach, then to taller iron still, and stops where nothing '
            'rises above it'
      : tier >= 1
      ? 'The storm will not come to the conduit — build it a ladder of rising '
            'iron, and shove the cell to the ladder\'s foot'
      : 'The storm chooses for itself, and the rods know why';

  DungeonProgressReadout? _spireProgressReadout() {
    final room = currentRoom;
    // The winds: the RINGS counter's replacement (the ring sequence retired).
    final total = totalGales;
    if (total > 0 && !hasStar(0)) {
      final onSpire =
          room.gustShrines.isNotEmpty ||
          room.summit != null ||
          room.windLedges.isNotEmpty;
      if (onSpire) {
        return DungeonProgressReadout(
          label: 'WINDS',
          value: '${wokenGales.length}/$total',
          fraction: wokenGales.length / total,
        );
      }
    }
    // The Gale Eye: how much of the coil is committed, glanceable at will.
    if (room.galeVents.isNotEmpty && _sealedWonderCloud(room) != null) {
      final open = spiralOpenJets.length;
      return DungeonProgressReadout(
        label: 'JETS',
        value: spiralTorn ? 'TORN' : '$open/$kSpiralJetsNeeded',
        fraction: spiralTorn ? 0 : (open / kSpiralJetsNeeded).clamp(0.0, 1.0),
      );
    }
    final loomStar = room.loomStarIndex;
    if (loomStar != null && !hasStar(loomStar) && room.anchors.isNotEmpty) {
      return DungeonProgressReadout(
        label: 'ANCHORS',
        value: '${filledAnchors.length}/${room.anchors.length}',
        fraction: filledAnchors.length / room.anchors.length,
      );
    }
    if (room.conduits.isNotEmpty && !altarOpen && guardianRiteUnlocked) {
      final live = room.conduits
          .where((c) => (conduitEnergy[c.id] ?? 0) > 0)
          .length;
      return DungeonProgressReadout(
        label: 'CONDUITS',
        value: '$live/${room.conduits.length}',
        fraction: live / max(1, room.conduits.length),
      );
    }
    return null;
  }

  // ── Rendering ────────────────────────────────────────────
  // Budget note (§ per-frame cost): gales and rods are ALWAYS-ON visuals, so
  // everything here is flat strokes and baked-glow blits — no blur, no
  // per-frame list allocation, no path rebuild per particle.

  void _renderSpireWinds(Canvas canvas, DungeonRoom room) {
    if (_roomCleared(room)) return;
    if (!hasStar(0)) {
      _drawGustShrines(canvas, room);
      _drawWindLedgeMarks(canvas, room);
    }
    _drawSummitCrown(canvas, room);
    _drawStormRodField(canvas, room);
    _drawStormCellAndLeader(canvas, room);
  }

  /// The chalk on a walkway, and the wind that scours it off.
  ///
  /// This used to draw each route as a rounded-rect OUTLINE the size of the
  /// whole path — a big empty box hanging over the terrain, five or six per
  /// room, which read as UI cards laid on the sky rather than as anything
  /// marked on the rock. The information is the same and it belongs on the
  /// SURFACE: a dashed chalk line down the middle of the walk, chevrons
  /// pointing the way it is walked, and both eaten away where a woken gale
  /// has scoured them.
  void _drawWindLedgeMarks(Canvas canvas, DungeonRoom room) {
    if (room.windRoutes.isEmpty) return;
    for (final r in room.windRoutes) {
      if (r.ridesGale != null) continue;
      final swept = r.sweptBy.any(wokenGales.contains);
      final col = swept ? const Color(0xFF6B5330) : const Color(0xFFCBB27A);
      final alpha = swept ? 0.30 : 0.62;

      // The walk itself: the top band of the path, where feet would go.
      final path = r.path;
      final y = path.top + path.height * 0.34;
      final chalk = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = swept ? 1.4 : 2.2
        ..color = col.withValues(alpha: alpha);

      // Dashes, scuffed and uneven — chalk, not a border.
      const dash = 15.0;
      const gap = 11.0;
      for (var x = path.left + 10; x < path.right - 10; x += dash + gap) {
        final end = (x + dash).clamp(path.left, path.right - 10);
        // A swept walk loses whole segments rather than fading evenly.
        if (swept && ((x ~/ 26) % 3 == 0)) continue;
        final wobble = sin(x * 0.07) * 1.4;
        canvas.drawLine(
          Offset(x, y + wobble),
          Offset(end.toDouble(), y + wobble),
          chalk,
        );
      }

      // Chevrons: which way this walk is walked.
      final toRight = _routeRunsRight(room, r);
      final nib = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = swept ? 1.2 : 1.8
        ..color = col.withValues(alpha: alpha * 0.85);
      for (var i = 0; i < 3; i++) {
        final t = 0.28 + i * 0.22;
        final cx = path.left + path.width * t;
        final d = toRight ? 1.0 : -1.0;
        canvas.drawLine(
          Offset(cx - 5 * d, y - 12),
          Offset(cx + 5 * d, y - 6),
          nib,
        );
        canvas.drawLine(
          Offset(cx + 5 * d, y - 6),
          Offset(cx - 5 * d, y),
          nib,
        );
      }

      // Scoured: the gale's own streaks run across what is left of the chalk.
      if (!swept) continue;
      final scour = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.1
        ..color = const Color(0xFF8FE6FF).withValues(alpha: 0.22);
      for (var i = 0; i < 5; i++) {
        final sy = path.top + 8 + i * (path.height - 16) / 4;
        final sx = path.left + ((_time * 90 + i * 61) % (path.width + 60)) - 30;
        canvas.drawLine(
          Offset(sx, sy),
          Offset((sx + 34).clamp(path.left, path.right), sy - 3),
          scour,
        );
      }
    }
  }

  /// Which way a route reads, from the ledges it joins.
  bool _routeRunsRight(DungeonRoom room, WindRoute r) {
    Rect? ledge(String id) {
      for (final l in room.windLedges) {
        if (l.id == id) return l.rect;
      }
      return null;
    }

    final a = ledge(r.from);
    final b = ledge(r.to);
    if (a == null || b == null) return true;
    return b.center.dx >= a.center.dx;
  }

  void _drawGustShrines(Canvas canvas, DungeonRoom room) {
    for (final s in room.gustShrines) {
      final woken = wokenGales.contains(s.wakesGale);
      final swell = woken ? (galeRamp[s.wakesGale] ?? 0.0) : 0.0;
      final col = woken
          ? Color.lerp(const Color(0xFF74613A), const Color(0xFF8FE6FF), swell)!
          : const Color(0xFFE4C16A);
      final pulse = woken ? 1.0 : 0.72 + 0.28 * sin(_time * 2.4);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          s.position,
          woken ? 26 + 12 * swell : 30,
          col.withValues(alpha: (woken ? 0.30 : 0.34) * pulse),
        );
      }
      // The shrine: a squat cairn with a breath-slot cut through it.
      final body = Rect.fromCenter(center: s.position, width: 22, height: 30);
      canvas.drawRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(4)),
        Paint()..color = const Color(0xFF241F18).withValues(alpha: 0.86),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = col.withValues(alpha: 0.9 * pulse),
      );
      final slot = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = col.withValues(alpha: 0.85 * pulse);
      for (var i = 0; i < 3; i++) {
        final y = s.position.dy - 8 + i * 8.0;
        final lean = woken ? 6.0 * swell * sin(_time * 3 + i) : 0.0;
        canvas.drawLine(
          Offset(s.position.dx - 6 + lean, y),
          Offset(s.position.dx + 6 + lean, y),
          slot,
        );
      }
    }
  }

  void _drawSummitCrown(Canvas canvas, DungeonRoom room) {
    final summit = room.summit;
    if (summit == null || room.id == 'spire_summit') return;
    final open = summitOpen;
    final col = open ? const Color(0xFFE4C16A) : const Color(0xFF3A352B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(summit.rect, const Radius.circular(6)),
      Paint()..color = col.withValues(alpha: open ? 0.16 : 0.08),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(summit.rect, const Radius.circular(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = col.withValues(alpha: open ? 0.9 : 0.4),
    );
    if (open) _drawStarGlyph(canvas, summit.rect.center, 11, col);
  }

  void _drawStormRodField(Canvas canvas, DungeonRoom room) {
    if (room.stormRods.isEmpty || _roomCleared(room)) return;
    const unit = 17.0; // px of iron per rank
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final cap = Paint()..style = PaintingStyle.fill;
    for (final rod in room.stormRods) {
      final h = _rodRaise[rod.id] ?? 0.0;
      final top = rod.position - Offset(0, 12 + h * unit);
      final rank = rodHeight[rod.id] ?? 0;
      final col = Color.lerp(
        const Color(0xFF6E6350),
        const Color(0xFF8FE6FF),
        (rank / kStormRodMaxHeight).clamp(0.0, 1.0),
      )!;
      // Socket.
      canvas.drawCircle(
        rod.position + const Offset(0, 4),
        7,
        Paint()..color = const Color(0xFF1B1712).withValues(alpha: 0.85),
      );
      base.color = col.withValues(alpha: 0.92);
      canvas.drawLine(rod.position + const Offset(0, 4), top, base);
      // Rank notches — the ordering IS the puzzle, so it must be countable.
      final notch = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = col.withValues(alpha: 0.55);
      for (var i = 1; i <= rank; i++) {
        final y = rod.position.dy + 4 - i * unit;
        canvas.drawLine(
          Offset(rod.position.dx - 6, y),
          Offset(rod.position.dx + 6, y),
          notch,
        );
      }
      cap.color = col.withValues(alpha: 0.95);
      canvas.drawCircle(top, 4.2, cap);
      if (_fx.ready && rank > 0) {
        drawGlow(
          canvas,
          _fx.glow!,
          top,
          10 + rank * 3.0,
          col.withValues(alpha: 0.22),
        );
      }
    }
  }

  void _drawStormCellAndLeader(Canvas canvas, DungeonRoom room) {
    final cell = stormCellPosition(room);
    if (cell == null || _roomCleared(room)) return;
    final orbit = room.stormOrbit!;
    final centre = (room.guardian != null && _rocLeash != Offset.zero)
        ? _rocLeash
        : orbit.center;
    // The ring the cell rides — a thin, honest circle: prediction needs it.
    canvas.drawCircle(
      centre,
      orbit.radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF8FE6FF).withValues(alpha: 0.16),
    );
    final charge = (stormStrikeTimer / max(0.2, orbit.strikeInterval)).clamp(
      0.0,
      1.0,
    );
    final col = Color.lerp(
      const Color(0xFF6E7C8C),
      const Color(0xFFB9E6FF),
      charge,
    )!;
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        cell,
        24 + 14 * charge,
        col.withValues(alpha: 0.30 + 0.28 * charge),
      );
    }
    canvas.drawCircle(cell, 11, Paint()..color = col.withValues(alpha: 0.75));
    // The charge ring: the fair warning before every discharge.
    canvas.drawArc(
      Rect.fromCircle(center: cell, radius: 17),
      -pi / 2,
      charge * 2 * pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE4C16A).withValues(alpha: 0.8),
    );

    // The latched ladder burns first and always — under the live flash, so a
    // fresh strike still reads as the brighter event.
    _drawLatchedLeader(canvas, room, cell);

    if (_leaderFlash <= 0 || lastLeaderPath.isEmpty) return;
    final fade = (_leaderFlash / _kLeaderFlashSeconds).clamp(0.0, 1.0);
    _drawLeaderChain(canvas, room, lastLeaderPath, cell, 0.85 * fade);
  }

  /// The chain that lit a conduit, kept alight. Anchored to the spot the bolt
  /// came down from — but only while the cell is still standing there; once it
  /// has drifted on, the chain starts at the first iron instead of trailing an
  /// arc into empty air.
  void _drawLatchedLeader(Canvas canvas, DungeonRoom room, Offset cell) {
    if (latchedLeaderPath.isEmpty) return;
    if ((conduitEnergy[latchedLeaderPath.last] ?? 0) <= 0) return;
    final origin = _latchedLeaderOrigin;
    final anchored = origin != null && (cell - origin).distance < 8;
    final path = anchored ? latchedLeaderPath : latchedLeaderPath.skip(1);
    final from = anchored
        ? origin
        : _conductorPosition(room, latchedLeaderPath.first);
    if (from == null) return;
    // A slow breath, not a strobe: the circuit is holding, not striking.
    _drawLeaderChain(canvas, room, path, from, 0.60 + 0.14 * sin(_time * 2.1));
  }

  void _drawLeaderChain(
    Canvas canvas,
    DungeonRoom room,
    Iterable<String> path,
    Offset origin,
    double alpha,
  ) {
    var from = origin;
    for (final id in path) {
      final to = _conductorPosition(room, id);
      if (to == null) break;
      _drawLightningArc(
        canvas,
        from,
        to,
        const Color(0xFFB9E6FF).withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
      from = to;
    }
  }

  Offset? _conductorPosition(DungeonRoom room, String id) {
    for (final rod in room.stormRods) {
      if (rod.id == id) {
        return rod.position - Offset(0, 12 + (_rodRaise[rod.id] ?? 0) * 17.0);
      }
    }
    for (final c in room.conduits) {
      if (c.id == id) return c.position;
    }
    if (id == _kGuardianConductorId) {
      final g = room.guardian;
      return g == null ? null : _guardianPosition(g);
    }
    return null;
  }

  // ── Rendering · the Gale Eye ─────────────────────────────
  // Same stonework as the gust shrines (squat cairn, breath-slot, amber when
  // asleep, cyan when blowing) so the borrowed verb is legible at a glance.
  // Budget: flat strokes only — ~7 cairns, ~21 chaff motes and one 26-segment
  // coil path per frame, and only inside this one small chamber.

  void _drawGaleEye(Canvas canvas, DungeonRoom room) {
    if (room.galeVents.isEmpty) return;
    final eye = _spiralEye(room);
    final rim = (room.galeVents.first.position - eye).distance;
    // The rim the mouths ring — thin and honest, like the storm-cell's circuit.
    canvas.drawCircle(
      eye,
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF8FE6FF).withValues(alpha: 0.10),
    );
    _drawFormingEye(canvas, eye);
    final marked = revealTier >= 2 ? spiralComposableCoil : null;
    for (final v in room.galeVents) {
      _drawGaleVent(canvas, v, eye, marked);
    }
  }

  /// The coil at the eye: it tightens with every jet that composes, and comes
  /// apart on screen when one does not.
  void _drawFormingEye(Canvas canvas, Offset eye) {
    final jets = spiralOpenJets.length;
    final tear = (_spiralTearFlash / _kSpiralTearSeconds).clamp(0.0, 1.0);
    if (jets == 0 && tear <= 0) return;
    final coil = spiralCoil;
    final spin = coil == GaleVentFlow.widdershins ? -1.0 : 1.0;
    final grip = spiralTorn ? tear : (jets / kSpiralJetsNeeded).clamp(0.0, 1.0);
    if (grip <= 0.01) return;
    // Torn: the coil flies apart outward as it fades. Whole: it draws tighter.
    final burst = spiralTorn ? (1.0 - tear) * 70.0 : 0.0;
    final path = Path();
    for (var i = 0; i <= 26; i++) {
      final t = i / 26;
      final a = spin * (t * pi * 2.6 + _time * (0.8 + 1.4 * grip));
      final r = 24 + t * (34 + 52 * grip) + burst * t;
      final p = eye + Offset(cos(a), sin(a)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    final col = spiralTorn
        ? const Color(0xFFD07A4A)
        : Color.lerp(const Color(0xFF8FE6FF), const Color(0xFFE4C16A), grip)!;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = col.withValues(
          alpha: (0.30 + 0.5 * grip) * (spiralTorn ? tear : 1.0),
        ),
    );
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        eye,
        26 + 26 * grip,
        col.withValues(alpha: 0.22 * (spiralTorn ? tear : 1.0)),
      );
    }
  }

  void _drawGaleVent(
    Canvas canvas,
    GaleVent v,
    Offset eye,
    GaleVentFlow? marked,
  ) {
    final flow = spiralVentFlow[v.id] ?? GaleVentFlow.inward;
    final dir = spiralVentDirection(v, eye, flow);
    final open = spiralOpenJets.contains(v.id);
    final swell = open ? (spiralJetRamp[v.id] ?? 0.0) : 0.0;
    final culprit = _spiralShearedVent == v.id;
    final col = culprit
        ? const Color(0xFFD07A4A)
        : open
        ? Color.lerp(const Color(0xFF74613A), const Color(0xFF8FE6FF), swell)!
        : const Color(0xFFE4C16A);
    final pulse = open ? 1.0 : 0.74 + 0.26 * sin(_time * 2.2);
    if (_fx.ready && (open || culprit)) {
      drawGlow(
        canvas,
        _fx.glow!,
        v.position,
        22 + 12 * swell,
        col.withValues(alpha: 0.28),
      );
    }
    // The mouth: the gust shrine's cairn, turned to face the way it breathes.
    final body = Rect.fromCenter(center: v.position, width: 24, height: 24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(5)),
      Paint()..color = const Color(0xFF241F18).withValues(alpha: 0.86),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = col.withValues(alpha: 0.9 * pulse),
    );
    // THE CARVING — the direction, readable BEFORE the mouth is ever touched:
    // a shaft cut through the stone and a chevron at its head.
    final carve = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..color = col.withValues(alpha: 0.92 * pulse);
    final head = v.position + dir * 15;
    canvas.drawLine(v.position - dir * 13, head, carve);
    final wing = Offset(-dir.dy, dir.dx);
    canvas.drawLine(head, head - dir * 8 + wing * 6, carve);
    canvas.drawLine(head, head - dir * 8 - wing * 6, carve);
    // THE CHAFF — loose grit already drifting the way the mouth breathes, so
    // the carving is never the only signal.
    final chaff = Paint()
      ..color = col.withValues(alpha: (open ? 0.75 : 0.45) * pulse);
    final speed = open ? 52.0 + 40 * swell : 20.0;
    for (var i = 0; i < 3; i++) {
      final u = ((_time * speed / 60 + i / 3) % 1.0);
      canvas.drawCircle(
        v.position + dir * (16 + u * (open ? 74 : 30)),
        open ? 2.4 : 1.6,
        chaff,
      );
    }
    // Tier-2 Mask: the mouths that can actually braid stand marked.
    if (marked != null && flow == marked) {
      canvas.drawCircle(
        v.position,
        20,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = const Color(0xFFE4C16A).withValues(alpha: 0.55),
      );
    }
  }

  /// A wind hoop. Star 1's sky-ring SEQUENCE retired (§5.5 hands
  /// sequence-execution to Fire alone), but the glyph itself still draws the
  /// entry ignition gust and the Spiral trial's eddies.
  void _drawWindRing(
    Canvas canvas,
    Offset c,
    double r,
    Color color, {
    required bool active,
  }) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = color;
    final rect = Rect.fromCircle(center: c, radius: r);
    final rot = active ? _time * 1.35 : _time * 0.18;
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(rect, rot + i * pi / 2, pi * 0.34, false, ringPaint);
    }
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: color.a * 0.72);
    for (var i = 0; i < 12; i++) {
      final a = -rot * 0.7 + i * pi * 2 / 12;
      final p1 = c + Offset(cos(a), sin(a)) * (r + 5);
      final p2 = c + Offset(cos(a), sin(a)) * (r + (i % 3 == 0 ? 14 : 10));
      canvas.drawLine(p1, p2, tickPaint);
    }
    if (!active) return;
    final streakPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFBFD2E6).withValues(alpha: 0.28);
    for (var i = 0; i < 5; i++) {
      final y = c.dy - 16 + i * 8.0;
      final x = c.dx - 20 + ((_time * 52 + i * 17) % 40);
      canvas.drawLine(Offset(x - 18, y), Offset(x + 14, y - 4), streakPaint);
    }
  }
}
