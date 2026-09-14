// lib/games/planet_dungeon/planet_dungeon_game_mud.dart
//
// PALUSIA — THE SINKING ALTAR. Mud's puzzle logic + rendering, as a
// `part of planet_dungeon_game.dart` (the treatment every planet after the
// Air pilot gets). The layout, the crossing graph and the pure terraforming
// rules live in planet_dungeon_layout_mud.dart; this file is the engine.
//
// World rule: *the fen is one water table — every path you harden sinks
// another.* See the layout file's header for the full statement of the ford
// trade (mire / sod / drowned), the ledger distinctions and the vault trick.
//
//  • Entry — the fen's face is a skin of floating weed. WATER sluices it and
//    the gate's three crossings show themselves (docs §5.5, the eased entry
//    reveal).
//  • Star 0 (Sarsen) — THE HAUL. The fen's fallen standing stone lies in the
//    gate's silt. It crosses SOD and nothing else, so the road has to be
//    dragged ahead of it, one crossing at a time, and every drag drowns the
//    crossings beside it on the same slough. MUD drags (element-only), or the
//    planet's braid **Plant+Water→Mud** with wisps as the recipe's price. The
//    socket's bog-resin cap wants **Plant+Mud→Poison** (§6.8). UNGATED — this
//    is the star §4 guarantees to any trio of Mud/Plant/Water.
//  • Star 1 (Moor) — THE CHOIR. Three moor-altars on three knolls. A basin
//    holds its offering only while its knoll stands DRY-FOOTED (every
//    crossing that touches it dragged to sod) — sodden ground drinks the
//    water straight out of the bowl, which is how the world teaches the rule
//    without a caption. The three knolls between them demand exactly four
//    fords, and those four are also the long southern sod road to the altar:
//    THE CHOIR TELLS YOU THE ROAD. Every short road kills the choir for that
//    shape, permanently. One of the three basins (the cairn's, under black
//    water) is the planet's Water+MASK gate.
//  • Star 2 (Bogdrya) — MYS08. §7: the guardian fights WITH the planet's
//    rule. Its lull only opens while the hollow's MIRE ANCHOR holds the
//    quaking floor firm, and every strike beat softens the anchor AND
//    swallows one of the sod roads you left in the bog above. It eats the map
//    you made while you fight it.
//  • Vault — ride the Lotus Knoll down (see `_updateFounder`).
//  • Lost Maxim — NO MUD, NO LOTUS: a seed planted in the deepest sink-pit of
//    the drowned fane, watered, and let go all the way down.
//
// NON-STRANDABILITY (the design's one real danger — see `solveFenTerraform`):
// irreversible map editing is a stranding machine, and this fen genuinely is
// one: 47 of its 125 legal shapes leave the bog walk-disconnected. Per the
// Ice precedent the answer is a COSTLY RESET, never a softer mechanic:
// the WALLOW takes a Mud hand down from any knoll at any time, and the SOUGH
// in the drowned fane HEAVES the whole bog back to its opening state on the
// way out. `solveFenTerraform().strandable == 0` rests entirely on that pair,
// and `strandableWithoutSough` is large on purpose.

part of 'planet_dungeon_game.dart';

/// Mud's lost maxim discovery id (the screen pays 20 gold on first find).
const String kMudNoLotusEggId = kMudLotusEggId;

// ── Device-tunable knobs ───────────────────────────────────
// Mud has never been on a device; every number the feel depends on is named
// here so a tuning pass is edit-one-block.

/// How close a creature must stand to a ford head, a basin, the socket, the
/// sough, the sink-pit or the mire anchor to work it.
const double _kFenReach = 72.0;

/// Seconds an adrift knoll takes to go down under the party's weight. Long
/// enough to read as a ride, short enough not to be a wait.
const double _kFounderSeconds = 2.4;

/// Wisps the **Plant+Water→Mud** braid breathes out per drag (§4: a recipe
/// substitutes an ELEMENT and pays its authored downside).
const int _kBraidWisps = 2;

/// Seconds the drag smear stays on screen, travelling out along the slough.
const double _kSmearSeconds = 1.6;

/// Everything one Mud run tracks. ONE field on the engine (the Lava/Poison
/// pattern): the pure fen rules plus the handful of live/visual timers the
/// rules themselves have no business knowing about.
class SinkingFen {
  /// The fen, and everything the player has done to it.
  final BogField field = BogField();

  double clock = 0;

  /// The travelling drag smear: where it started, which fords it is slumping,
  /// and how long it has left (render only).
  double smear = 0;
  Offset smearAt = Offset.zero;
  List<String> smearLost = const [];

  /// THE LOST MAXIM — the Black Lead. `cutsFound` once Water has read the
  /// three peat cuts out of the black water; `seedSet` once Plant has put a
  /// seed in the sink; `poured` the cuts whose lips have been dragged.
  bool cutsFound = false;
  bool seedSet = false;
  final Set<int> poured = {};

  /// How thick the sink is, 0 (clean water) → 1 (peat you could stand a
  /// stone in). Eased toward `poured.length / 3` so a pour READS as an
  /// arrival rather than a value change.
  double sinkThickness = 0;

  /// THE GROUND, BUILT ONCE. A fen floor is pools, hummocks, bog-oak and
  /// cotton-grass, none of it on a grid and none of it changing — so it is
  /// laid out once per room and kept, rather than re-deriving sixty times a
  /// second. Only the sheen on the water moves, and that is a phase.
  final Map<String, FenGround> ground = {};
}

/// One room's worth of ground, in world coordinates: the fen above, or the
/// drowned level under it. Built once, then only read.
class FenGround {
  // ── the fen ──
  final List<Path> pools = [];
  final List<Offset> poolCentres = [];
  final List<Path> hummocks = [];
  final List<Path> mossCaps = [];
  final List<Offset> bogOak = [];
  final List<double> bogOakLean = [];
  final List<Offset> cotton = [];

  // ── the drowned level ──
  final List<Path> flags = [];
  final List<Offset> drums = [];
  final List<double> drumLean = [];
  final List<Offset> roots = [];
  final List<double> rootLength = [];

  // ── the hollow and the bowl: not buildings ──
  final List<Path> pans = [];
  final List<Offset> panCentres = [];
  final List<Offset> bones = [];
  final List<double> boneLean = [];
}

extension SinkingAltarFen on PlanetDungeonGame {
  bool get _isBog => layout.element == 'Mud';

  BogField get _fen => bog.field;

  // ── Lifecycle ────────────────────────────────────────────

  void _resetBogState() {
    if (!_isBog) return;
    // A death re-floods nothing and un-drags nothing by itself — the fen is
    // puzzle state like every other planet's, so it resets with the run.
    _fen.reset();
    bog
      ..clock = 0
      ..smear = 0
      ..smearLost = const []
      ..cutsFound = false
      ..seedSet = false
      ..sinkThickness = 0;
    bog.poured.clear();
  }

  // ── Per-frame update ─────────────────────────────────────

  void _updateBog(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isBog) return;
    bog.clock += dt;
    if (bog.smear > 0) bog.smear = max(0.0, bog.smear - dt);
    // The sink thickens toward what has been poured into it, rather than
    // snapping: a pour has to READ as peat arriving down the lead.
    final want = bog.poured.length / 3.0;
    if ((bog.sinkThickness - want).abs() > 0.001) {
      bog.sinkThickness += (want - bog.sinkThickness) * min(1.0, dt * 1.4);
    }
    _updateFounder(room, dt);
    _updateBogdrya(room, dt);
  }

  /// THE FOUNDER, and the vault (§5.5: "let the vault knoll SINK, ride it
  /// down to the drowned level"). A knoll with no living crossing is ADRIFT:
  /// nothing moors it and it will not hold a body. The lotus is the only
  /// knoll you can ever set foot on in that state — the plank road is laid ON
  /// the water, so it carries a walker and moors nothing — and the moment you
  /// do, it takes you down.
  void _updateFounder(DungeonRoom room, double dt) {
    final f = _fen;
    if (room.id != kLotusKnollId || f.lotusSunk || !f.isAdrift(kLotusKnollId)) {
      if (f.founder != 0) f.founder = 0;
      return;
    }
    if (f.founder == 0) {
      _setHint(
        'The knoll gives under you, nothing is holding it up any more',
        3.0,
      );
    }
    f.founder += dt;
    if (f.founder < _kFounderSeconds) return;
    _rideLotusDown(room);
  }

  /// The ride itself. Walked by the engine, never by the player: the door is
  /// a hole in the world that opens under their feet.
  void _rideLotusDown(DungeonRoom room) {
    final f = _fen;
    f.lotusSunk = true;
    f.founder = 0;
    final door = room.doors.firstWhere((d) => d.targetRoomId == 'sunken_lotus');
    currentRoomId = door.targetRoomId;
    _spreadCreaturesAround(door.targetSpawn);
    _clearHints();
    _setHint(
      'The lotus goes under and takes you with it, and the fen closes over',
      4.4,
    );
  }

  /// Test seam: drive the founder without walking a body onto a knoll.
  void bogFounderTickForTest(double dt) => _updateFounder(currentRoom, dt);

  /// §7 — the guardian fights WITH the planet's rule. Bogdrya DRINKS the fen:
  /// its lull only opens while the mire anchor holds the hollow's quaking
  /// floor firm, and every strike beat softens the anchor AND swallows one of
  /// the sod roads above, spitting it back as open water. Frowyrm's precedent,
  /// in mud: the fight is literally spending the map you made.
  void _updateBogdrya(DungeonRoom room, double dt) {
    if (room.guardian == null || !guardianAwake) return;
    final f = _fen;
    if (!f.anchorFirm) {
      guardianVulnerable = false;
      return;
    }
    if (guardianVulnerable && !f.bitLastFrame) {
      f.bitLastFrame = true;
      return;
    }
    if (!guardianVulnerable && f.bitLastFrame) {
      f.bitLastFrame = false;
      f.anchorFirm = false;
      _swallowOneRoad();
    }
  }

  /// The roar reaches up through the peat and takes a causeway with it. The
  /// ford does not go back to mire — it goes to WATER, because that is the
  /// only thing this planet's rule ever does to a crossing.
  void _swallowOneRoad() {
    final f = _fen;
    for (final ford in kBogFords) {
      if (!f.hardened.contains(ford.id)) continue;
      f.hardened.remove(ford.id);
      // The moor-altars answer to dryness, so a swallowed road can un-wake a
      // basin — Star 1 is only ever lost this way BEFORE it is banked.
      f.moorsWoken.removeWhere((k) => !f.isDry(k));
      _setHint('Bogdrya drinks, a causeway goes out from under the bog');
      return;
    }
  }

  // ── The crossing graph, as the engine sees it ────────────

  /// The ford this door crosses, when it is one. The plank road, the wallows,
  /// the founder hole and the rite doors are not fords and return null.
  BogFord? _fordForDoor(DungeonRoom room, DungeonDoor door) {
    if (_isPlankDoor(room, door)) return null;
    for (final f in kBogFords) {
      if (f.touches(room.id) && f.other(room.id) == door.targetRoomId) {
        return f;
      }
    }
    return null;
  }

  /// The peat-cutters' boardwalk. Two doors join the cairn and the lotus —
  /// the ford `add_tail` and the plank — so the plank is identified by being
  /// the LOWER of the pair (authored second, at the southern lip).
  bool _isPlankDoor(DungeonRoom room, DungeonDoor door) {
    if (room.id != kPlankFromKnoll && room.id != kPlankToKnoll) return false;
    final want = room.id == kPlankFromKnoll ? kPlankToKnoll : kPlankFromKnoll;
    if (door.targetRoomId != want) return false;
    final pair = room.doors.where((d) => d.targetRoomId == want).toList();
    if (pair.length < 2) return false;
    return identical(door, pair.last);
  }

  bool _isWallowDoor(DungeonRoom room, DungeonDoor door) =>
      room.fen?.knoll != null && door.targetRoomId == 'drowned_fane';

  bool _isRisenWallowDoor(DungeonRoom room, DungeonDoor door) =>
      room.id == 'drowned_fane' &&
      layout.rooms[door.targetRoomId]?.fen?.knoll != null;

  /// Hidden doors: the whole gate floor while the weed still lies over it,
  /// the founder hole (the engine walks you through it — it is never a thing
  /// you aim at), and the fane's reciprocal into the bowl, which exists only
  /// so the bowl has a way out (§ layout header).
  bool _bogDoorHidden(DungeonRoom room, DungeonDoor door) {
    if (!_isBog) return false;
    if (room.id == 'drowned_fane' && door.targetRoomId == 'sunken_lotus') {
      return true;
    }
    if (room.id == kLotusKnollId && door.targetRoomId == 'sunken_lotus') {
      return true;
    }
    if (room.id == layout.entranceRoomId && !entryDoorRevealed) {
      return _fordForDoor(room, door) != null;
    }
    return false;
  }

  /// Locked doors — the whole planet, in one function.
  bool _bogDoorBlocked(DungeonRoom room, DungeonDoor door) {
    if (!_isBog) return false;
    final f = _fen;

    // The bowl: you came in through the roof, riding the knoll.
    if (room.id == 'sunken_lotus' && door.targetRoomId == kLotusKnollId) {
      return true;
    }
    // A sunk knoll is not a place any more.
    if (door.targetRoomId == kLotusKnollId && f.lotusSunk) return true;

    // THE WALLOW — always available, and only to a Mud hand.
    if (_isWallowDoor(room, door)) return active?.member.element != 'Mud';

    // THE RISEN WALLOWS — shut until the sough is freed.
    if (_isRisenWallowDoor(room, door)) {
      if (!f.soughFreed) return true;
      return door.targetRoomId == kLotusKnollId && f.lotusSunk;
    }

    // THE PLANK ROAD — Mud MANE (§4 hard gate). Gates no star: it is the
    // vault's approach, and the fords reach the lotus whenever it is moored.
    if (_isPlankDoor(room, door)) return !_plankPasses();

    final ford = _fordForDoor(room, door);
    if (ford == null) return false;
    return f.stateOf(ford.id) == BogFordState.drowned;
  }

  bool _plankPasses() {
    final a = active;
    final gate = layout.familyGateFor('plank_road');
    if (a == null || gate == null) return false;
    return a.member.element == gate.element &&
        abilityForFamily(a.member.family) == abilityForFamily(gate.family);
  }

  /// One short clause naming exactly what is missing (§5.6 BLOCKED) — never a
  /// method. How a ford is dragged is the fen's earned reading (Mask).
  String _bogDoorHint(DungeonRoom room, DungeonDoor door) {
    final f = _fen;
    if (room.id == 'sunken_lotus' && door.targetRoomId == kLotusKnollId) {
      return 'The knoll came down with you, there is only water above';
    }
    if (door.targetRoomId == kLotusKnollId && f.lotusSunk) {
      return 'That knoll is under the fen now';
    }
    if (_isWallowDoor(room, door)) {
      return 'Only Mud lets the bog take it down';
    }
    if (_isRisenWallowDoor(room, door)) {
      return 'The fen holds its roof shut, nothing rises here yet';
    }
    if (_isPlankDoor(room, door)) {
      final gate = layout.familyGateFor('plank_road');
      if (gate != null) {
        _discoverCloud(gate.discoveryId); // THE SEAL REMEMBERS (§4)
        return gate.hintLine;
      }
    }
    return 'Open water, nothing crosses it now';
  }

  /// Bookkeeping on the transit itself: climbing a risen wallow is THE HEAVE.
  void _onBogTransit(DungeonRoom from, DungeonDoor door) {
    if (!_isBog) return;
    if (!_isRisenWallowDoor(from, door)) return;
    _fen.heave();
    _setHint(
      'The sough lets go and the whole fen heaves, every road you dragged '
      'is soup again',
      4.6,
    );
  }

  /// Test seam for the transit bookkeeping (the Ice precedent), so the heave
  /// is proved against the same code the door loop calls.
  void onBogTransitForTest(DungeonRoom from, DungeonDoor door) =>
      _onBogTransit(from, door);

  // ── Verbs ────────────────────────────────────────────────

  /// Every Mud verb, in priority order. Returns true when one was consumed.
  bool _tryBogVerb(DungeonCreature a) {
    if (!_isBog) return false;
    return _tryWeedSkin(a) ||
        _tryMireAnchor(a) ||
        _trySough(a) ||
        _tryBlackLead(a) ||
        _tryMoorBasin(a) ||
        _trySocketCap(a) ||
        _trySeatSarsen(a) ||
        _tryDragFord(a) ||
        _tryHaulSarsen(a);
  }

  /// The entry rite: WATER sluices the skin of floating weed off the fen's
  /// face and the gate's crossings show themselves.
  bool _tryWeedSkin(DungeonCreature a) {
    if (currentRoomId != layout.entranceRoomId || entryDoorRevealed) {
      return false;
    }
    final knoll = currentRoom.fen?.knoll;
    if (knoll == null) return false;
    if ((a.position - const Offset(560, 240)).distance > 220) return false;
    if (a.member.element != 'Water') {
      _setBlockedHint('Only Water washes this weed off the fen');
      return true;
    }
    entryDoorRevealed = true;
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId);
    _setHint('The weed slides away, three crossings, and none of them sure');
    _spawnAlchemyBurst(
      const Offset(560, 240),
      producedElement: 'Water',
      reagentElements: const ['Mud'],
      particleCount: 28,
      intensity: 1.1,
    );
    return true;
  }

  /// THE DRAG — the planet's whole grammar. Element-only MUD, or the braid
  /// **Plant+Water→Mud** at the price of wisps (§4).
  bool _tryDragFord(DungeonCreature a) {
    final f = _fen;
    for (final ford in kBogFords) {
      final head = ford.headIn(currentRoomId);
      if (head == null) continue;
      if ((a.position - head).distance > _kFenReach) continue;
      switch (f.stateOf(ford.id)) {
        case BogFordState.sod:
          // A road that already stands is the HAUL's business, not the
          // drag's: decline so `_tryHaulSarsen` gets the press.
          if (!f.sarsenSeated && f.sarsenKnoll == currentRoomId) return false;
          _setBlockedHint('This crossing already stands');
          return true;
        case BogFordState.drowned:
          _setBlockedHint('Open water, there is nothing left to pull on');
          return true;
        case BogFordState.mire:
          break;
      }
      final braid = a.member.element != 'Mud';
      if (braid && !_bogBraidReady(a)) {
        _setBlockedHint('The mire answers only Mud');
        return true;
      }
      final lost = f.harden(ford.id) ?? const <BogFord>[];
      // The moor-altars answer to dryness, so a drag can wake one outright
      // and drown a neighbour's chance in the same motion.
      _wakeSettledMoors();
      bog
        ..smear = _kSmearSeconds
        ..smearAt = head
        ..smearLost = [for (final l in lost) l.id];
      _setHint(
        lost.isEmpty
            ? 'The mire knits and stands, a road, for good'
            : 'The road stands, and the water it held backs up into '
                  '${kSloughNames[ford.slough] ?? 'the slough'}',
        3.6,
      );
      _spawnAlchemyBurst(
        head,
        producedElement: 'Mud',
        reagentElements: braid ? const ['Plant', 'Water'] : const [],
        unstable: braid,
        particleCount: braid ? 26 : 20,
        intensity: braid ? 1.15 : 0.9,
      );
      if (braid) {
        // The braid's authored downside (§4): the churn draws what lives here.
        spawnWispWave(
          element: 'Mud',
          center: head,
          count: _kBraidWisps,
          unstable: true,
          announce: false,
        );
      }
      return true;
    }
    return false;
  }

  /// Does this creature carry the drag — Mud itself, or the fen's own braid
  /// **Plant+Water→Mud** (§6.8)?
  bool _bogBraidReady(DungeonCreature a) {
    final e = a.member.element;
    if (e != 'Plant' && e != 'Water') return false;
    final want = e == 'Plant' ? 'Water' : 'Plant';
    return creatures.any(
      (c) => c.alive && !identical(c, a) && c.member.element == want,
    );
  }

  /// THE HAUL — Star 0's core. Stand at a crossing's head on the knoll the
  /// sarsen is on and drag it over. A sarsen crosses SOD and nothing else:
  /// mire will not bear it, and water is water.
  bool _tryHaulSarsen(DungeonCreature a) {
    final f = _fen;
    if (f.sarsenSeated) return false;
    if (currentRoomId != f.sarsenKnoll) return false;
    // PRESSING AT THE STONE HAS TO SAY SOMETHING. The haul is worked at a
    // CROSSING, not at the sarsen, so the obvious thing to try — walk up to
    // the big stone and press — did nothing at all and fell through to the
    // wordless element puff. That is the first thing a player does on this
    // planet, and the answer was silence.
    if ((a.position - _sarsenStandsAt()).distance <= _kFenReach) {
      _setBlockedHint(
        'The stone will not be lifted, only pushed — and only onto a road',
      );
      return true;
    }
    for (final ford in kBogFords) {
      final head = ford.headIn(currentRoomId);
      if (head == null) continue;
      if ((a.position - head).distance > _kFenReach * 1.4) continue;
      // Only sod ever bears the stone. Anything else has already been
      // answered by the drag, which runs first.
      if (f.stateOf(ford.id) != BogFordState.sod) continue;
      f.sarsenKnoll = ford.other(currentRoomId)!;
      _setHint('The sarsen grinds across, one crossing nearer', 3.2);
      _spawnAlchemyBurst(
        head,
        producedElement: 'Earth',
        reagentElements: const ['Mud'],
        particleCount: 18,
        intensity: 0.9,
      );
      return true;
    }
    return false;
  }

  /// Where the sarsen stands in the room it is currently on. One copy, so
  /// the renderer and the haul cannot disagree about what you are next to.
  Offset _sarsenStandsAt() {
    final room = layout.rooms[_fen.sarsenKnoll];
    final b = room?.bounds ?? currentRoom.bounds;
    return Offset(b.center.dx, _fen.sarsenKnoll == kSarsenHomeKnoll ? 150 : 140);
  }

  /// The socket's bog-resin cap — **Plant+Mud→Poison** eats it (§6.8). The
  /// braid is the ONLY way: no Poison hand descends here.
  bool _trySocketCap(DungeonCreature a) {
    final altar = currentRoom.fen?.altar;
    final f = _fen;
    if (altar == null || f.socketOpen) return false;
    if ((a.position - altar.cap).distance > _kFenReach) return false;
    final e = a.member.element;
    final want = e == 'Plant' ? 'Mud' : 'Plant';
    final paired =
        (e == 'Plant' || e == 'Mud') &&
        creatures.any(
          (c) => c.alive && !identical(c, a) && c.member.element == want,
        );
    if (!paired) {
      _setBlockedHint('The resin holds, nothing here eats it alone');
      return true;
    }
    f.socketOpen = true;
    _setHint('The resin rots through and the socket opens black');
    _spawnAlchemyBurst(
      altar.cap,
      producedElement: 'Poison',
      reagentElements: const ['Plant', 'Mud'],
      particleCount: 26,
      intensity: 1.15,
    );
    return true;
  }

  /// Seat the sarsen — Star 0's success.
  bool _trySeatSarsen(DungeonCreature a) {
    final altar = currentRoom.fen?.altar;
    final f = _fen;
    if (altar == null || f.sarsenSeated) return false;
    if ((a.position - altar.socket).distance > _kFenReach) return false;
    if (f.sarsenKnoll != kSarsenSocketKnoll) {
      _setBlockedHint('The socket stands empty, the stone is still out there');
      return true;
    }
    if (!f.socketOpen) {
      _setBlockedHint('Old resin caps the socket');
      return true;
    }
    f.sarsenSeated = true;
    _setHint('The sarsen drops home and the altar stops sinking', 4.0);
    _spawnAlchemyBurst(
      altar.socket,
      producedElement: 'Earth',
      reagentElements: const ['Mud'],
      particleCount: 32,
      intensity: 1.3,
    );
    if (!hasStar(altar.sarsenStarIndex)) earnStar(altar.sarsenStarIndex);
    return true;
  }

  /// A MOOR BASIN — Star 1. Element-only WATER, except the cairn's, which is
  /// under black water and takes the planet's Water+MASK gate (§4).
  bool _tryMoorBasin(DungeonCreature a) {
    final moor = currentRoom.fen?.moor;
    final f = _fen;
    if (moor == null) return false;
    if ((a.position - moor.basin).distance > _kFenReach) return false;
    if (f.moorsWoken.contains(currentRoomId)) {
      _setHint('This basin is holding');
      return true;
    }
    if (moor.hidden) {
      final gate = layout.familyGateFor('moor_black');
      if (gate != null &&
          (a.member.element != gate.element ||
              abilityForFamily(a.member.family) !=
                  abilityForFamily(gate.family))) {
        _stampFamilyGate(gate);
        return true;
      }
    } else if (a.member.element != 'Water') {
      _setBlockedHint('The basin answers only Water');
      return true;
    }
    if (!f.isDry(currentRoomId)) {
      // The world teaches the rule: sodden ground drinks the offering.
      _setBlockedHint('The ground drinks it, this knoll still swims');
      _spawnAlchemyBurst(
        moor.basin,
        producedElement: 'Water',
        unstable: true,
        particleCount: 14,
        intensity: 0.7,
      );
      return true;
    }
    f.moorsWoken.add(currentRoomId);
    _setHint('The basin holds, the stone takes up the note', 3.4);
    _spawnAlchemyBurst(
      moor.basin,
      producedElement: 'Water',
      reagentElements: const ['Mud'],
      particleCount: 24,
      intensity: 1.05,
    );
    _bankMoorStarIfWhole();
    return true;
  }

  /// A drag can dry the last knoll a woken basin was waiting on; re-check the
  /// choir whenever the fen changes under it.
  void _wakeSettledMoors() {
    final f = _fen;
    f.moorsWoken.removeWhere((k) => !f.isDry(k));
    _bankMoorStarIfWhole();
  }

  void _bankMoorStarIfWhole() {
    final f = _fen;
    if (!f.choirWhole) return;
    final altar = layout.rooms[kSarsenSocketKnoll]?.fen?.altar;
    if (altar == null || hasStar(altar.moorStarIndex)) return;
    earnStar(altar.moorStarIndex);
  }

  /// THE SOUGH — the fen's outfall, and the anti-strand valve. A Mud hand
  /// pulls its peat plug; climbing out afterwards heaves the whole bog back
  /// to its opening state (see `_onBogTransit`). Always available, from any
  /// state, which is what `solveFenTerraform().strandable == 0` rests on.
  bool _trySough(DungeonCreature a) {
    final pos = currentRoom.fen?.sough;
    final f = _fen;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kFenReach) return false;
    if (a.member.element != 'Mud') {
      _setBlockedHint('Only Mud has a grip on this plug');
      return true;
    }
    if (f.soughFreed) {
      _setBlockedHint('The outfall already runs');
      return true;
    }
    f.soughFreed = true;
    _setHint('The plug comes away, the whole fen starts to move');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Mud',
      reagentElements: const ['Water'],
      particleCount: 28,
      intensity: 1.2,
    );
    return true;
  }

  /// THE LOST MAXIM — NO MUD, NO LOTUS, and it is THE BLACK LEAD.
  ///
  /// What it was: three presses at one coordinate in the fane — Plant, then
  /// Water, then Mud, each answered with a line of narration. Three keys in
  /// one lock. Against §7's maxim standard it kept nothing: no chain (no
  /// step changed anything a later step needed), no braid, no repeated beat,
  /// and its "place" was a dot on a floor you already walk across.
  ///
  /// What it is: **the secret is the fen you are punished for making.**
  ///
  ///  1. THE FEN AT FULL DROWN. The lead is a choked, dry cut until the bog
  ///     above is carrying all the water it can — [BogField.fenAtFullDrown],
  ///     which exactly one shape in the whole fen reaches: all three SHORT
  ///     roads, the three middles, six of nine crossings gone. That is the
  ///     shape the Sarsen road and the choir both forbid, so the secret
  ///     costs you the run's stars for as long as you hold it, and the
  ///     sough's heave is what buys them back. Nothing is pressed for this
  ///     beat: you come down the wallow and the lead is running.
  ///  2. WATER reads the three PEAT CUTS out of the black water — the same
  ///     job Water does at the cairn's basin, on the same planet's terms.
  ///  3. PLANT sets a seed in the sink. It sits in clean water doing
  ///     nothing, because a seed in clean water is not a lotus.
  ///  4. MUD drags each cut's lip in turn — THE REPEATED BEAT, and it is the
  ///     planet's one verb (the braid **Plant+Water→Mud** carries it here
  ///     too, as it does everywhere). Each pour runs down the lead and the
  ///     sink thickens: water → slurry → peat, and the seed goes under.
  ///  5. The third pour buries it utterly, and it blooms.
  ///
  /// Wordless past the HINT button's one line. Nothing is consumed: a wrong
  /// hand gets a burst and a sentence about what it sees, and a heave washes
  /// the lead out so it can always be done again.
  bool _tryBlackLead(DungeonCreature a) {
    final fen = currentRoom.fen;
    final sink = fen?.sinkPit;
    final lead = fen?.leadHead;
    final cuts = fen?.peatCuts;
    if (sink == null || lead == null || cuts == null) return false;
    if (discoveredClouds.contains(kMudNoLotusEggId)) return false;
    // A choked lead is not a thing to press. The fen has to be carrying it.
    if (!_fen.fenAtFullDrown) return false;

    final e = a.member.element;

    // ── 2 · the cuts, read out of the black water ──
    if (!bog.cutsFound) {
      if ((a.position - lead).distance > _kFenReach) return false;
      if (e != 'Water') {
        _spawnAlchemyBurst(lead, producedElement: e, particleCount: 8,
            intensity: 0.5);
        _setHint('Black water, and something under it that will not show');
        return true;
      }
      bog.cutsFound = true;
      _spawnAlchemyBurst(lead, producedElement: 'Water', particleCount: 20,
          intensity: 0.9);
      return true;
    }

    // ── 4 · the pours: the repeated beat, and the planet's own verb ──
    for (var i = 0; i < cuts.length; i++) {
      if ((a.position - cuts[i]).distance > _kFenReach) continue;
      if (bog.poured.contains(i)) return false;
      if (!bog.seedSet) {
        // Pouring into a sink with nothing in it teaches what is missing
        // without naming it: the peat goes down and the hole takes it.
        _spawnAlchemyBurst(cuts[i], producedElement: 'Mud', particleCount: 8,
            intensity: 0.5);
        _setHint('The cut pours, the sink swallows it, and nothing changes');
        return true;
      }
      final braid = e != 'Mud';
      if (braid && !_bogBraidReady(a)) {
        _spawnAlchemyBurst(cuts[i], producedElement: e, particleCount: 8,
            intensity: 0.5);
        _setHint('The lip holds, this hand has no drag in it');
        return true;
      }
      if (braid) {
        spawnWispWave(
          element: 'Mud',
          center: cuts[i],
          count: _kBraidWisps,
          unstable: true,
          announce: false,
        );
      }
      bog.poured.add(i);
      bog.smear = _kSmearSeconds;
      bog.smearAt = cuts[i];
      bog.smearLost = const [];
      _cue(SoundCue.dungeonSwitch);
      _spawnAlchemyBurst(cuts[i], producedElement: 'Mud',
          reagentElements: const ['Water'], particleCount: 22, intensity: 1.0);
      if (bog.poured.length == cuts.length) {
        // ── 5 · buried utterly, and it blooms ──
        beginMaximRite(kMudNoLotusEggId, sink);
        _spawnAlchemyBurst(
          sink,
          producedElement: 'Plant',
          reagentElements: const ['Mud', 'Water'],
          particleCount: 40,
          intensity: 1.4,
        );
      }
      return true;
    }

    // ── 3 · the seed ──
    if ((a.position - sink).distance > _kFenReach) return false;
    if (bog.seedSet) return false;
    if (e != 'Plant') {
      _spawnAlchemyBurst(sink, producedElement: e, particleCount: 8,
          intensity: 0.5);
      _setHint('The sink is clean to the bottom, and holds nothing');
      return true;
    }
    bog.seedSet = true;
    _spawnAlchemyBurst(sink, producedElement: 'Plant', particleCount: 18,
        intensity: 0.8);
    return true;
  }

  /// Bogdrya's mire anchor: a Mud hand firms the hollow's quaking floor so
  /// the mystic can be struck at all. Outranks the guardian's own catch, like
  /// Lightning's spike and Ice's pillar.
  bool _tryMireAnchor(DungeonCreature a) {
    final pos = currentRoom.fen?.anchor;
    final f = _fen;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kFenReach) return false;
    if (a.member.element != 'Mud') {
      _setBlockedHint('Only Mud sets this floor');
      return true;
    }
    if (f.anchorFirm) {
      _setBlockedHint('The floor is firm');
      return true;
    }
    f.anchorFirm = true;
    _setHint('The floor sets hard, there is something to stand on');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Mud',
      reagentElements: const ['Earth'],
      particleCount: 22,
      intensity: 1.0,
    );
    return true;
  }

  // ── Readouts, hints, insight (§5.6) ──────────────────────

  /// STATE LEAVES THE CAPSULE (§5.6): counters live beside the star tracker.
  DungeonProgressReadout? _bogProgressReadout() {
    final f = _fen;
    final altar = layout.rooms[kSarsenSocketKnoll]?.fen?.altar;
    // THE HAUL COMES FIRST while the stone is still out in the fen. It is
    // Star 0, it is the thing a player is doing in the opening minutes, and
    // it is the one quantity here nobody can derive by looking: how many
    // crossings of HARD ground still lie between the stone and the socket,
    // which is a different question from how far apart they are. The basins
    // take the slot once the stone is home; the crossings that used to live
    // here are all nine of them on the fen chart now.
    if (altar != null && !f.sarsenSeated && !hasStar(altar.sarsenStarIndex)) {
      final hops = _sarsenHopsHome();
      return DungeonProgressReadout(
        label: 'SARSEN',
        value: hops == null ? 'no road' : '$hops to go',
        fraction: null,
      );
    }
    if (altar != null && !hasStar(altar.moorStarIndex)) {
      return DungeonProgressReadout(
        label: 'BASINS',
        value: '${f.moorsWoken.length}/${kMoorKnollIds.length}',
        fraction: f.moorsWoken.length / kMoorKnollIds.length,
      );
    }
    return null;
  }

  /// Crossings of SOD between the stone and the socket, or null when no road
  /// of hard ground joins them at all. A plain breadth-first walk of the fen
  /// as it stands right now.
  int? _sarsenHopsHome() {
    final f = _fen;
    if (f.sarsenKnoll == kSarsenSocketKnoll) return 0;
    final seen = <String>{f.sarsenKnoll};
    var frontier = <String>[f.sarsenKnoll];
    var depth = 0;
    while (frontier.isNotEmpty) {
      depth++;
      final next = <String>[];
      for (final knoll in frontier) {
        for (final ford in f.fordsOf(knoll)) {
          if (f.stateOf(ford.id) != BogFordState.sod) continue;
          final other = ford.other(knoll);
          if (other == null || !seen.add(other)) continue;
          if (other == kSarsenSocketKnoll) return depth;
          next.add(other);
        }
      }
      frontier = next;
    }
    return null;
  }

  /// WHAT, never HOW (§5.6). Every method here is Mask's to give.
  String? _bogObjectiveHint(DungeonRoom room) {
    final f = _fen;
    if (room.guardian != null) {
      return 'Bogdrya\'s Hollow, the fen keeps its last star down here';
    }
    if (room.fen?.sough != null) {
      return 'The Drowned Fane, the whole bog drains through this room';
    }
    if (room.vaultCache != null) {
      return 'A bowl under the fen, something is bottled here';
    }
    // WHERE THE STONE IS, AND WHERE IT IS GOING. These two lines used to
    // describe their rooms — "the sarsen lies here", "its socket stands
    // empty" — as two unrelated facts in two rooms you never see at once.
    // Each names the OTHER end now, because a haul is only a goal when you
    // know both ends of it.
    final altar = room.fen?.altar;
    if (altar != null && !hasStar(altar.sarsenStarIndex)) {
      return f.sarsenKnoll == room.id
          ? 'The Sinking Altar, and the stone is here at last'
          : 'The Sinking Altar, its socket wants the fen\'s fallen stone';
    }
    if (room.fen?.knoll != null &&
        f.sarsenKnoll == room.id &&
        !f.sarsenSeated) {
      return 'The stone stands here, and the altar is not this knoll';
    }
    if (room.fen?.moor != null) {
      if (f.moorsWoken.contains(room.id)) return null;
      // The condition, not just the symptom. "Will not keep anything" is
      // true and teaches nothing; a knoll that still swims is the reason.
      return f.isDry(room.id)
          ? 'A moor-altar on drained ground, its basin would hold now'
          : 'A moor-altar, and this knoll still swims';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Mire Gate, three crossings out, and the stone lies here'
          : 'The Mire Gate. Weed lies over everything';
    }
    return null;
  }

  /// AMBIENT is flavour only (§5.6): no mechanics, no elements, no families.
  void _bogAmbientHint(DungeonCreature a, DungeonRoom room) {
    final f = _fen;
    for (final ford in kBogFords) {
      final head = ford.headIn(room.id);
      if (head == null) continue;
      if ((a.position - head).distance > _kFenReach) continue;
      _setAmbientHint(switch (f.stateOf(ford.id)) {
        BogFordState.mire => 'The ground here breathes when you stand on it',
        BogFordState.sod => 'Old roots, holding',
        BogFordState.drowned => 'Black water, and no bottom to it',
      });
      return;
    }
    final knoll = room.fen?.knoll;
    if (knoll != null && (a.position - knoll.wallow).distance < 90) {
      _setAmbientHint('A soft eye in the peat, going down a long way');
      return;
    }
    // THE BLACK LEAD. Flavour only, and the same two lines whether or not
    // anything is going on down there — a secret that announces itself is
    // not one (§5.6 AMBIENT; §7 rule 5, wordless past the first nudge).
    final sink = room.fen?.sinkPit;
    if (sink != null && (a.position - sink).distance < 110) {
      _setAmbientHint(_fen.fenAtFullDrown
          ? 'The cut is running, and it runs away from the fane'
          : 'An old cut, dug for something, going nowhere now');
    }
  }

  /// INSIGHT is the only channel allowed to teach method (§5.6), tiered by
  /// Intelligence.
  void _bogReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    // THE BLACK LEAD'S ONE OBLIQUE LINE (§7 rule 5), and it is the only thing
    // anywhere in the game that speaks about the Lost Maxim. It does not
    // tier, it does not track progress, and it says the same words whether
    // the lead is running or dry: it points at the IDEA — this cut was dug
    // to take the fen's worst, and clean water grows nothing — and every
    // step after it is legible from what is standing there.
    final sink = room.fen?.sinkPit;
    if (sink != null &&
        (a.position - sink).distance < 150 &&
        !discoveredClouds.contains(kMudNoLotusEggId)) {
      _setHint(
        'The cut was dug to take the fen\'s worst. Nothing has ever '
        'bloomed out of clean water.',
        4.0,
      );
      return;
    }
    if (room.fen?.moor != null) {
      _setInsightHint(switch (tier) {
        0 => 'Wet ground will not keep an offering',
        1 =>
          'The basin holds only where the knoll itself stands drained'
              'and a knoll drains when every crossing that touches it is hard',
        _ =>
          'Count this knoll\'s crossings and harden every one; the black '
              'basin on the cairn answers a reading eye rather than a pouring '
              'hand',
      });
      return;
    }
    if (room.fen?.altar != null) {
      _setInsightHint(switch (tier) {
        0 => 'The stone will not travel over anything soft',
        1 =>
          'A road has to stand before the sarsen will cross it, and old '
              'resin caps the socket at the end',
        _ =>
          'Drag the road one crossing ahead of the stone; the socket\'s '
              'resin rots only where root and mire are worked together',
      });
      return;
    }
    if (room.fen?.sough != null) {
      _setInsightHint(switch (tier) {
        0 => 'Everything the fen loses ends up here',
        1 =>
          'The outfall can be opened, and the fen will answer the whole '
              'way up',
        _ =>
          'Free the plug and climb out anywhere, but the heave takes back '
              'every road you dragged, and puts the stone back where it lay',
      });
      return;
    }
    // Anywhere in the bog, insight reads THE FEN — which is the planet.
    _setInsightHint(switch (tier) {
      0 => 'One water table, and it has to go somewhere',
      1 =>
        'Harden a crossing and the water it held backs up into the '
            'crossings beside it on the same watercourse',
      _ =>
        'No two neighbours on one watercourse can ever both stand, in any '
            'order; what already stands is safe, and what has drowned is gone. '
            'A knoll with nothing left holding it will not hold you either',
    });
  }

  /// Per-room sky mood — the fen is low and grey, and the drowned level is
  /// lower and greyer.
  double get _bogMoodTarget => switch (currentRoomId) {
    'mire_gate' => 0.58,
    'hag_knoll' || 'reed_knoll' => 0.5,
    'sedge_knoll' || 'cairn_knoll' => 0.46,
    'lotus_knoll' => 0.42,
    'altar_knoll' => 0.38,
    'sunken_lotus' => 0.2,
    'drowned_fane' => 0.16,
    _ => guardianAwake ? 0.1 : 0.14,
  };

  // ── THE NO-STRAND PROOF ──────────────────────────────────

  /// Exhaustive reachability over the fen's whole state graph.
  ///
  /// A state is (which room you stand in) × (the hardened set — which, per
  /// [BogField], determines every crossing in the fen) × (whether the sough
  /// is freed) × (whether the lotus has been ridden down). Every legal move
  /// is expanded: walking a crossing that is sod or mire, dragging a mire
  /// crossing (which drowns its slough-neighbours), the plank road, the
  /// wallow down from any knoll, freeing the sough, climbing a risen wallow
  /// (which HEAVES the fen back to its opening state), the founder ride into
  /// the vault bowl, and the plain doors of the drowned level.
  ///
  /// Three questions, all answered by construction rather than by argument:
  ///
  ///  1. `strandable` — states from which some room is no longer reachable.
  ///     **It must be zero.** Reachability is checked for EVERY room in the
  ///     layout, which is stronger than the brief asks: not just the exit and
  ///     the unearned stars, but the vault bowl too.
  ///  2. `strandableWithoutSough` — the same audit with the wallow/sough
  ///     valve deleted. It is expected to be LARGE: irreversible terraforming
  ///     really is a stranding machine, and if this ever drops to zero
  ///     somebody has quietly made a drag reversible and the planet has lost
  ///     its identity.
  ///  3. `disconnectedShapes` — hardened sets that leave the bog itself
  ///     walk-disconnected. Non-zero on purpose: that is the strategic
  ///     question ("shape the map you'll have to live with") having teeth.
  ///
  /// `strandable` is the LITERAL two-level search the brief asks for (the Ice
  /// precedent): enumerate every reachable state, then run a fresh forward
  /// BFS out of each one and check that every room legal play can reach at
  /// all is still reachable. `strandableReverse` recomputes the same number
  /// the cheap way — one reverse BFS per room — purely as a cross-check on
  /// the search itself; the test pins the two equal, so a bug in either would
  /// have to be a bug in both, in the same direction.
  ({
    int states,
    int strandable,
    int strandableReverse,
    int strandableWithoutSough,
    int disconnectedShapes,
    int shapes,
  })
  solveFenTerraform({bool plankPassable = true}) {
    final fordIds = [for (final f in kBogFords) f.id];
    final rooms = layout.rooms.keys.toList()..sort();

    // ── the pure fen, recomputed off a hardened bitmask ──
    List<int> neighbourMask() {
      final out = List<int>.filled(fordIds.length, 0);
      for (var i = 0; i < kBogFords.length; i++) {
        for (var j = 0; j < kBogFords.length; j++) {
          if (i == j) continue;
          final a = kBogFords[i], b = kBogFords[j];
          if (a.slough == b.slough && (a.index - b.index).abs() == 1) {
            out[i] |= 1 << j;
          }
        }
      }
      return out;
    }

    final nb = neighbourMask();
    bool isSod(int h, int i) => (h & (1 << i)) != 0;
    bool isDrowned(int h, int i) => !isSod(h, i) && (h & nb[i]) != 0;
    bool passable(int h, int i) => !isDrowned(h, i);
    bool canDrag(int h, int i) => !isSod(h, i) && !isDrowned(h, i);
    bool adrift(int h, String knoll) {
      for (var i = 0; i < kBogFords.length; i++) {
        if (!kBogFords[i].touches(knoll)) continue;
        if (!isDrowned(h, i)) return false;
      }
      return true;
    }

    // Every legal hardened set: an independent set in each slough's chain.
    final shapes = <int>[];
    for (var h = 0; h < (1 << kBogFords.length); h++) {
      var ok = true;
      for (var i = 0; i < kBogFords.length && ok; i++) {
        if (isSod(h, i) && (h & nb[i]) != 0) ok = false;
      }
      if (ok) shapes.add(h);
    }
    final shapeIndex = {for (var i = 0; i < shapes.length; i++) shapes[i]: i};

    // ── the state graph ──
    int enc(int room, int shape, bool sough, bool sunk) =>
        ((room * shapes.length + shapeIndex[shape]!) * 2 + (sough ? 1 : 0)) *
            2 +
        (sunk ? 1 : 0);
    final roomIndex = {for (var i = 0; i < rooms.length; i++) rooms[i]: i};

    List<(String, int, bool, bool)> moves(
      String room,
      int h,
      bool sough,
      bool sunk, {
      required bool valveEnabled,
    }) {
      final out = <(String, int, bool, bool)>[];
      final isKnoll = layout.rooms[room]!.fen?.knoll != null;

      if (isKnoll) {
        // Walk / drag every crossing that touches this knoll.
        for (var i = 0; i < kBogFords.length; i++) {
          final f = kBogFords[i];
          if (!f.touches(room)) continue;
          final far = f.other(room)!;
          if (passable(h, i) && !(far == kLotusKnollId && sunk)) {
            out.add((far, h, sough, sunk));
          }
          if (canDrag(h, i)) out.add((room, h | (1 << i), sough, sunk));
        }
        // The plank road (Mud MANE) — and the founder ride it can trigger.
        if (plankPassable &&
            (room == kPlankFromKnoll || room == kPlankToKnoll)) {
          final far = room == kPlankFromKnoll ? kPlankToKnoll : kPlankFromKnoll;
          if (!(far == kLotusKnollId && sunk)) out.add((far, h, sough, sunk));
        }
        if (room == kLotusKnollId && !sunk && adrift(h, kLotusKnollId)) {
          out.add(('sunken_lotus', h, sough, true));
        }
        // THE WALLOW — a Mud hand, from any knoll, at any time.
        if (valveEnabled) out.add(('drowned_fane', h, sough, sunk));
      }

      if (room == 'drowned_fane') {
        if (valveEnabled) {
          if (!sough) out.add((room, h, true, sunk));
          if (sough) {
            // THE HEAVE — climbing out puts the fen back as it opened.
            for (final k in kBogKnollIds) {
              out.add((k, 0, false, false));
            }
          }
        }
        out.add(('bogdrya_hollow', h, sough, sunk));
      }
      if (room == 'bogdrya_hollow') out.add(('drowned_fane', h, sough, sunk));
      if (room == 'sunken_lotus') out.add(('drowned_fane', h, sough, sunk));
      return out;
    }

    // Forward-enumerate every state legal play can reach from the gate.
    final start = ('mire_gate', 0, false, false);
    final live = <int, (String, int, bool, bool)>{
      enc(roomIndex[start.$1]!, start.$2, start.$3, start.$4): start,
    };
    final queue = [start];
    while (queue.isNotEmpty) {
      final s = queue.removeLast();
      for (final m in moves(s.$1, s.$2, s.$3, s.$4, valveEnabled: true)) {
        final k = enc(roomIndex[m.$1]!, m.$2, m.$3, m.$4);
        if (live.containsKey(k)) continue;
        live[k] = m;
        queue.add(m);
      }
    }

    /// From how many live states is [target] unreachable? One reverse BFS.
    int unreachableCount(String target, {required bool valveEnabled}) {
      // Build the reverse edge set lazily over the live states only.
      final back = <int, List<int>>{};
      for (final s in live.values) {
        final from = enc(roomIndex[s.$1]!, s.$2, s.$3, s.$4);
        for (final m in moves(
          s.$1,
          s.$2,
          s.$3,
          s.$4,
          valveEnabled: valveEnabled,
        )) {
          final to = enc(roomIndex[m.$1]!, m.$2, m.$3, m.$4);
          if (!live.containsKey(to)) continue;
          (back[to] ??= []).add(from);
        }
      }
      final seen = <int>{};
      final q = <int>[];
      for (final s in live.values) {
        if (s.$1 != target) continue;
        final k = enc(roomIndex[s.$1]!, s.$2, s.$3, s.$4);
        if (seen.add(k)) q.add(k);
      }
      while (q.isNotEmpty) {
        final k = q.removeLast();
        for (final p in back[k] ?? const <int>[]) {
          if (seen.add(p)) q.add(p);
        }
      }
      return live.length - seen.length;
    }

    // Only audit rooms legal play can reach AT ALL. With the plank road shut
    // (a party that brought no Mud mane) the vault bowl is simply not part of
    // this run's world — that is a family gate on optional treasure, not a
    // strand — so it drops out of the audit rather than counting against it.
    final everReached = {for (final s in live.values) s.$1};
    final required = [
      for (final r in rooms)
        if (everReached.contains(r)) r,
    ];

    /// LEVEL TWO — the literal search: from ONE state, which rooms are still
    /// reachable? A fresh forward BFS over the state graph, exactly as Ice's
    /// `solveShaftDescent` does it.
    Set<String> roomsReachableFrom(
      (String, int, bool, bool) s, {
      required bool valveEnabled,
    }) {
      final seen = <int>{enc(roomIndex[s.$1]!, s.$2, s.$3, s.$4)};
      final hit = <String>{s.$1};
      final q = [s];
      while (q.isNotEmpty) {
        final cur = q.removeLast();
        for (final m in moves(
          cur.$1,
          cur.$2,
          cur.$3,
          cur.$4,
          valveEnabled: valveEnabled,
        )) {
          final k = enc(roomIndex[m.$1]!, m.$2, m.$3, m.$4);
          if (!seen.add(k)) continue;
          hit.add(m.$1);
          q.add(m);
        }
      }
      return hit;
    }

    var strandable = 0;
    var without = 0;
    for (final s in live.values) {
      final withValve = roomsReachableFrom(s, valveEnabled: true);
      if (required.any((r) => !withValve.contains(r))) strandable++;
      final bare = roomsReachableFrom(s, valveEnabled: false);
      if (required.any((r) => !bare.contains(r))) without++;
    }

    // The cross-check, computed the other way round.
    var reverse = 0;
    for (final r in required) {
      reverse = max(reverse, unreachableCount(r, valveEnabled: true));
    }

    // How many shapes leave the bog itself walk-disconnected?
    var disconnected = 0;
    for (final h in shapes) {
      final seen = <String>{'mire_gate'};
      final q = ['mire_gate'];
      while (q.isNotEmpty) {
        final k = q.removeLast();
        for (var i = 0; i < kBogFords.length; i++) {
          final f = kBogFords[i];
          if (!f.touches(k) || !passable(h, i)) continue;
          final far = f.other(k)!;
          if (seen.add(far)) q.add(far);
        }
      }
      if (seen.length < kBogKnollIds.length) disconnected++;
    }

    return (
      states: live.length,
      strandable: strandable,
      strandableReverse: reverse,
      strandableWithoutSough: without,
      disconnectedShapes: disconnected,
      shapes: shapes.length,
    );
  }

  // ── Rendering ────────────────────────────────────────────
  //
  // VISUAL GRAMMAR (§5.5, and the Steam NOTE at §6.6 — "Mud's reshaping
  // should drag/flow terrain", and it must read NOTHING like Steam's tile
  // floods). There is not a tile anywhere in this planet: a crossing is a
  // long flowing RIBBON drawn as a curve, a drag is a viscous SMEAR that
  // travels out along it, and sod is a raised bank with a tussock fringe.
  // No blur filters anywhere (the game's known jank source).

  static const Color _fenPeat = Color(0xFF241E17);
  static const Color _fenSlurry = Color(0xFF6B5B41);
  static const Color _fenSod = Color(0xFF5E6B37);
  static const Color _fenWater = Color(0xFF0D1A1E);
  static const Color _fenSheen = Color(0xFF9FB6A6);

  // ── READING THE FEN ───────────────────────────────────────
  //
  // Everything in this block exists because of one playtest sentence: *"it's
  // not intuitive, I'm not sure what the goal is, I'm just going around
  // tapping things."* The puzzle was sound and unreadable. Three things were
  // missing and they are all the same thing — the rule's INPUTS were hidden:
  //
  //   · WHICH WATER a crossing sits on. The rule is "hardening drowns its
  //     neighbours on the same slough", and a slough was an id in a table.
  //   · WHAT A DRAG WILL COST, before you pay it. The drag is irreversible
  //     and its victims are usually in another room, so the price was
  //     invisible until it had been paid.
  //   · WHAT THE FEN LOOKS LIKE NOW. Seven knolls seen one at a time, and
  //     the map you are authoring existed only in the player's head.

  /// One tint per watercourse, used on the marker stones and the chart. They
  /// never colour the crossing itself — MIRE / SOD / DROWNED owns that read,
  /// and a second colour system laid over it would fight the first.
  static const List<Color> _sloughInk = [
    Color(0xFF7FA8C9), // the Cormorant
    Color(0xFFC98F6A), // the Adder
    Color(0xFF9C8FC9), // the Tarn
  ];

  Color _sloughColour(String slough) =>
      _sloughInk[(kSloughOrder[slough] ?? 0) % _sloughInk.length];

  /// The crossing the active creature is standing at, if any — the one a
  /// press would drag.
  BogFord? _fordUnderHand() {
    final a = active;
    if (a == null) return null;
    for (final ford in kBogFords) {
      final head = ford.headIn(currentRoomId);
      if (head == null) continue;
      if ((a.position - head).distance <= _kFenReach) return ford;
    }
    return null;
  }

  /// What dragging the crossing under your hand would DROWN. Empty when
  /// there is nothing there, or when that crossing cannot take a drag.
  Set<String> get bogDoomedByHand {
    final ford = _fordUnderHand();
    if (ford == null) return const {};
    if (!_fen.canHarden(ford.id)) return const {};
    return {
      for (final n in _fen.neighbours(ford))
        if (_fen.stateOf(n.id) != BogFordState.drowned) n.id,
    };
  }

  void _renderBog(Canvas canvas, DungeonRoom room) {
    _renderFordHeads(canvas, room);
    _renderPlankRoad(canvas, room);
    _renderKnollFurniture(canvas, room);
    _renderSmear(canvas, room);
  }

  /// THE PLANK ROAD — and it has to look like nothing else on this planet.
  ///
  /// It joins the same two knolls as the ford `add_tail` and does the
  /// opposite thing: a rotten boardwalk laid ON the water carries a walker
  /// and MOORS NOTHING, which is the entire vault trick — cut the lotus's
  /// two crossings and it is adrift, then walk out on the planks and the
  /// knoll founders under you. It drew nothing at all, so the two openings
  /// on that wall were a ford and an unexplained second doorway.
  void _renderPlankRoad(Canvas canvas, DungeonRoom room) {
    if (room.id != kPlankFromKnoll && room.id != kPlankToKnoll) return;
    final want = room.id == kPlankFromKnoll ? kPlankToKnoll : kPlankFromKnoll;
    final pair = room.doors.where((d) => d.targetRoomId == want).toList();
    if (pair.length < 2) return;
    final mouth = pair.last.rect.center;
    // It leaves the knoll where the ground gives up, not at a worked head:
    // there is nothing to work here, which is the point.
    final start = Offset(
      mouth.dx > room.bounds.center.dx ? mouth.dx - 210 : mouth.dx + 210,
      mouth.dy + 12,
    );
    final dir = (mouth - start) / (mouth - start).distance;
    final norm = Offset(-dir.dy, dir.dx);

    // The water it is laid on — the planks moor nothing because there is
    // nothing under them.
    canvas.drawPath(
      Path()
        ..moveTo(start.dx + norm.dx * 34, start.dy + norm.dy * 34)
        ..lineTo(mouth.dx + norm.dx * 34, mouth.dy + norm.dy * 34)
        ..lineTo(mouth.dx - norm.dx * 34, mouth.dy - norm.dy * 34)
        ..lineTo(start.dx - norm.dx * 34, start.dy - norm.dy * 34)
        ..close(),
      Paint()..color = _fenWater.withValues(alpha: 0.85),
    );
    // Two stringers on trestles, and the boards across them: SAWN TIMBER,
    // the only worked wood in the fen, and grey with rot.
    for (var k = -1; k <= 1; k += 2) {
      canvas.drawLine(
        start + norm * (k * 15.0),
        mouth + norm * (k * 15.0),
        Paint()
          ..strokeWidth = 4
          ..color = const Color(0xFF3D3529),
      );
    }
    final len = (mouth - start).distance;
    for (var d = 8.0; d < len - 4; d += 15) {
      final p = start + dir * d;
      // Every third board is gone, and the rest do not lie straight.
      if ((d ~/ 15) % 4 == 2) continue;
      final skew = sin(d * 0.4) * 2.6;
      canvas.drawLine(
        p + norm * (20 + skew),
        p - norm * (20 - skew),
        Paint()
          ..strokeWidth = 8
          ..color = const Color(0xFF6B6250).withValues(alpha: 0.85),
      );
      canvas.drawLine(
        p + norm * (20 + skew),
        p - norm * (20 - skew),
        Paint()
          ..strokeWidth = 1.2
          ..color = const Color(0xFF2A251C).withValues(alpha: 0.6),
      );
    }
    // Trestle posts going down into black water, and not into ground.
    for (var d = 30.0; d < len - 20; d += 62) {
      final p = start + dir * d;
      canvas.drawLine(
        p + norm * 22,
        p + norm * 34,
        Paint()
          ..strokeWidth = 3.5
          ..color = const Color(0xFF2A251C),
      );
    }
  }

  // ── THE GROUND ────────────────────────────────────────────
  //
  // THE FLOOR OF A QUAKING FEN, NOT A LOZENGE. Every room on this planet
  // stood on the generic rounded slab, which is an odd thing for the one
  // dungeon whose entire premise is *what the ground is like under you*. A
  // bog is not a floor with things on it: it is pools lying in low ground,
  // sphagnum hummocks standing between them, the black bog-oak the peat has
  // been keeping for a thousand years, and cotton-grass — the only pale
  // thing in the whole fen — wherever the ground is briefly sure.
  //
  // Nothing here is on a grid and nothing is a tile (the §5.5 grammar, and
  // Steam's NOTE that Mud must read nothing like a tile flood). It is laid
  // out ONCE per room and cached: only the sheen on the water moves.

  static const Color _fenMoss = Color(0xFF4A5733);
  static const Color _fenOak = Color(0xFF16110C);
  static const Color _fenCotton = Color(0xFFD8D2BA);

  FenGround _bogGround(DungeonRoom room) =>
      bog.ground.putIfAbsent(
        room.id,
        () => room.fen?.knoll != null
            ? _buildBogGround(room)
            : _buildDrownedGround(room),
      );

  /// UNDER THE FEN. The fane, the bowl and the hollow are not knolls and had
  /// no business drawing moss caps, cotton-grass and standing pools — this is
  /// the drowned level, and the fane in particular is a building that went
  /// down: flagstones half-swallowed by silt, column drums lying where they
  /// fell, and the underside of the peat overhead letting its roots through.
  FenGround _buildDrownedGround(DungeonRoom room) {
    final b = room.bounds.deflate(10);
    final g = FenGround();
    var seed = (b.width * 23 + b.height * 41).toInt() | 1;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x3FFFFFFF;
      return (seed >> 8) / 0x3FFFFF;
    }

    // THE HOLLOW AND THE BOWL ARE NOT BUILDINGS. Only the FANE went down as
    // architecture; Bogdrya's hollow is a void eaten out of the peat, and
    // the sunken lotus is the underside of a knoll that foundered. Giving
    // all three a flagged temple floor made the wyrm's pit read as a nave
    // and told the player the wrong thing about where it is safe to stand.
    if (room.id != 'drowned_fane') {
      // SOFT PANS — the quaking floor, wherever it has not set.
      final pans = (b.width * b.height / 46000).clamp(3, 9).toInt();
      for (var i = 0; i < pans; i++) {
        final c = Offset(
          b.left + 60 + rnd() * (b.width - 120),
          b.top + 60 + rnd() * (b.height - 120),
        );
        g.pans.add(
          _blobPath(c, 46 + rnd() * 62, 26 + rnd() * 30, rnd, wobble: 0.3),
        );
        g.panCentres.add(c);
      }
      // BONES — what the fen has eaten and kept. The one pale thing down
      // here, and the reason a Plant hand is worth bringing.
      final bones = 3 + (rnd() * 3).floor();
      for (var i = 0; i < bones; i++) {
        g.bones.add(
          Offset(
            b.left + 70 + rnd() * (b.width - 140),
            b.top + 90 + rnd() * (b.height - 170),
          ),
        );
        g.boneLean.add((rnd() - 0.5) * 2.2);
      }
      final roots = (b.width / 130).clamp(4, 12).toInt();
      for (var i = 0; i < roots; i++) {
        g.roots.add(Offset(b.left + 40 + rnd() * (b.width - 80), b.top));
        g.rootLength.add(60 + rnd() * 110);
      }
      return g;
    }

    // FLAGSTONES, in courses, every one tilted and none of them square —
    // a floor that has been settling for a thousand years.
    const fw = 96.0;
    const fh = 58.0;
    for (var y = b.top + 30; y < b.bottom - 30; y += fh + 10) {
      final off = ((y - b.top) ~/ (fh + 10)).isEven ? 0.0 : 46.0;
      for (var x = b.left + 24 + off; x < b.right - 40; x += fw + 12) {
        // Thinning out toward the room's edges, so the floor drowns in silt
        // rather than stopping at a line.
        // Better than half of the floor is gone under silt. A dense, even
        // course of identical slabs is a BRICK WALL laid flat, which is what
        // the first cut of this looked like.
        if (rnd() < 0.58) continue;
        final c = Offset(x + fw / 2, y + fh / 2);
        final tilt = (rnd() - 0.5) * 0.22;
        final sx = fw * (0.62 + rnd() * 0.5);
        final sy = fh * (0.7 + rnd() * 0.5);
        final p = Path();
        final corners = [
          Offset(-sx / 2, -sy / 2),
          Offset(sx / 2, -sy / 2),
          Offset(sx / 2, sy / 2),
          Offset(-sx / 2, sy / 2),
        ];
        for (var i = 0; i < 4; i++) {
          final k = corners[i] + Offset((rnd() - 0.5) * 9, (rnd() - 0.5) * 7);
          final r = Offset(
            k.dx * cos(tilt) - k.dy * sin(tilt),
            k.dx * sin(tilt) + k.dy * cos(tilt),
          );
          final q = c + r;
          i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
        }
        p.close();
        g.flags.add(p);
      }
    }

    // FALLEN COLUMN DRUMS.
    final drums = 2 + (rnd() * 3).floor();
    for (var i = 0; i < drums; i++) {
      g.drums.add(
        Offset(
          b.left + 70 + rnd() * (b.width - 140),
          b.top + 80 + rnd() * (b.height - 160),
        ),
      );
      g.drumLean.add((rnd() - 0.5) * 1.4);
    }

    // ROOTS, coming down out of the peat ceiling.
    final roots = (b.width / 150).clamp(4, 12).toInt();
    for (var i = 0; i < roots; i++) {
      g.roots.add(Offset(b.left + 40 + rnd() * (b.width - 80), b.top));
      g.rootLength.add(50 + rnd() * 90);
    }
    return g;
  }

  /// The drowned level's floor.
  void _renderDrownedFloor(Canvas canvas, DungeonRoom room) {
    _renderPlainFloor(canvas, room.bounds, false);
    final g = _bogGround(room);
    final t = bog.clock;
    final b = room.bounds;

    // Silt lying over everything.
    canvas.drawRRect(
      RRect.fromRectAndRadius(b.deflate(8), const Radius.circular(34)),
      Paint()..color = const Color(0xFF0B0E10).withValues(alpha: 0.45),
    );

    // The hollow and the bowl: soft ground, and bones in it.
    for (var i = 0; i < g.pans.length; i++) {
      canvas.drawPath(
        g.pans[i],
        Paint()..color = _fenSlurry.withValues(alpha: 0.22),
      );
      // Quaking: one travelling ring per pan, so soft ground reads as soft
      // before anything stands on it.
      final c = g.panCentres[i];
      final ph = ((t * 0.35 + i * 0.2) % 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: c,
          width: 28 + ph * 74,
          height: 15 + ph * 38,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _fenSlurry.withValues(alpha: 0.26 * (1 - ph)),
      );
    }
    for (var i = 0; i < g.bones.length; i++) {
      final o = g.bones[i];
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.rotate(g.boneLean[i]);
      // A rib: a curve out of the peat and back into it.
      canvas.drawPath(
        Path()
          ..moveTo(-34, 8)
          ..quadraticBezierTo(0, -40, 34, 6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFB9B096).withValues(alpha: 0.32),
      );
      canvas.drawPath(
        Path()
          ..moveTo(-20, 10)
          ..quadraticBezierTo(0, -22, 21, 9),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFB9B096).withValues(alpha: 0.22),
      );
      canvas.restore();
    }

    for (final f in g.flags) {
      canvas.drawPath(
        f,
        Paint()..color = const Color(0xFF2B2C28).withValues(alpha: 0.55),
      );
      canvas.drawPath(
        f,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF07090A).withValues(alpha: 0.8),
      );
    }

    for (var i = 0; i < g.drums.length; i++) {
      final c = g.drums[i];
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(g.drumLean[i]);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(0, 6), width: 128, height: 40),
          const Radius.circular(8),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.30),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 124, height: 38),
          const Radius.circular(7),
        ),
        Paint()..color = const Color(0xFF3A3A34),
      );
      // The drum joints, so it reads as a column in pieces.
      for (var k = -1; k <= 1; k++) {
        canvas.drawLine(
          Offset(k * 36.0, -18),
          Offset(k * 36.0, 18),
          Paint()
            ..strokeWidth = 2
            ..color = const Color(0xFF23231F),
        );
      }
      canvas.restore();
    }

    // The peat overhead, letting its roots down into the room.
    canvas.drawRect(
      Rect.fromLTRB(b.left, b.top, b.right, b.top + 26),
      Paint()..color = _fenPeat.withValues(alpha: 0.85),
    );
    for (var i = 0; i < g.roots.length; i++) {
      final o = g.roots[i];
      final len = g.rootLength[i];
      final sway = sin(t * 0.4 + i * 1.7) * 5;
      final p = Path()
        ..moveTo(o.dx, o.dy)
        ..quadraticBezierTo(
          o.dx + sway,
          o.dy + len * 0.6,
          o.dx + sway * 1.6,
          o.dy + len,
        );
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _fenOak.withValues(alpha: 0.85),
      );
    }

    // Silt going up through the water, slowly.
    for (var i = 0; i < 10; i++) {
      final ph = ((t * 0.16 + i * 0.1) % 1.0);
      canvas.drawCircle(
        Offset(
          b.left + 60 + (i * 137 % (b.width - 120)),
          b.bottom - 30 - ph * (b.height - 70),
        ),
        1.6,
        Paint()..color = _fenSheen.withValues(alpha: 0.12 * (1 - ph)),
      );
    }
  }

  /// Deterministic from the room's own size, so a room looks the same every
  /// time you walk into it and no two rooms look alike.
  FenGround _buildBogGround(DungeonRoom room) {
    final b = room.bounds.deflate(10);
    final g = FenGround();
    var seed = (b.width * 31 + b.height * 17).toInt() | 1;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x3FFFFFFF;
      return (seed >> 8) / 0x3FFFFF;
    }

    // POOLS. Irregular closed curves lying in the low ground — never round,
    // never rectangular; a pool in peat has a ragged lip.
    final pools = (b.width * b.height / 62000).clamp(4, 11).toInt();
    for (var i = 0; i < pools; i++) {
      final c = Offset(
        b.left + 40 + rnd() * (b.width - 80),
        b.top + 40 + rnd() * (b.height - 80),
      );
      final rx = 34 + rnd() * 58;
      final ry = rx * (0.34 + rnd() * 0.3);
      g.pools.add(_blobPath(c, rx, ry, rnd, wobble: 0.34));
      g.poolCentres.add(c);
    }

    // HUMMOCKS. Sphagnum mounds standing between the water, each with a
    // lighter moss cap sitting on its crown so the ground has relief.
    final mounds = (b.width * b.height / 34000).clamp(6, 20).toInt();
    for (var i = 0; i < mounds; i++) {
      final c = Offset(
        b.left + 30 + rnd() * (b.width - 60),
        b.top + 30 + rnd() * (b.height - 60),
      );
      final rx = 26 + rnd() * 40;
      final ry = rx * (0.42 + rnd() * 0.22);
      g.hummocks.add(_blobPath(c, rx, ry, rnd, wobble: 0.22));
      g.mossCaps.add(
        _blobPath(c.translate(0, -ry * 0.30), rx * 0.72, ry * 0.5, rnd,
            wobble: 0.26),
      );
    }

    // BOG-OAK. Two or three black stumps half-risen out of the peat: the fen
    // keeps what it eats, which is the fiction the whole planet runs on and
    // the reason a Plant hand is worth bringing ("quicken whatever the peat
    // has kept").
    final oaks = 2 + (rnd() * 2).floor();
    for (var i = 0; i < oaks; i++) {
      g.bogOak.add(
        Offset(
          b.left + 60 + rnd() * (b.width - 120),
          b.top + 70 + rnd() * (b.height - 140),
        ),
      );
      g.bogOakLean.add((rnd() - 0.5) * 0.6);
    }

    // COTTON-GRASS. Scattered pale tufts — the only light thing down here.
    final tufts = (b.width * b.height / 17000).clamp(10, 40).toInt();
    for (var i = 0; i < tufts; i++) {
      g.cotton.add(
        Offset(
          b.left + 20 + rnd() * (b.width - 40),
          b.top + 20 + rnd() * (b.height - 40),
        ),
      );
    }
    return g;
  }

  /// A closed, ragged-lipped blob. Eight points round an ellipse, each pushed
  /// in or out a little and joined with quadratics, so nothing in this fen
  /// has a clean edge.
  Path _blobPath(
    Offset c,
    double rx,
    double ry,
    double Function() rnd, {
    required double wobble,
  }) {
    const n = 8;
    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      final a = i / n * pi * 2;
      final k = 1 + (rnd() - 0.5) * 2 * wobble;
      pts.add(Offset(c.dx + cos(a) * rx * k, c.dy + sin(a) * ry * k));
    }
    final path = Path();
    final mid0 = Offset.lerp(pts[n - 1], pts[0], 0.5)!;
    path.moveTo(mid0.dx, mid0.dy);
    for (var i = 0; i < n; i++) {
      final cur = pts[i];
      final nxt = pts[(i + 1) % n];
      final mid = Offset.lerp(cur, nxt, 0.5)!;
      path.quadraticBezierTo(cur.dx, cur.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  /// THE FEN CHART — the map you are authoring, on screen, always.
  ///
  /// Seven knolls are seen one at a time, so the shape of the bog existed
  /// only in the player's head, and a drag's real cost — two crossings
  /// drowning in rooms two doors away — was invisible at the moment it was
  /// paid. This is the planet's progress readout (§5.6 STATE LEAVES THE
  /// CAPSULE, and the Steam/Water precedent for a per-planet canvas HUD):
  /// three watercourses, three crossings each, in stream order.
  ///
  /// It shows STATE, never method. Which crossings are live, which are sod,
  /// which are gone, and — while you stand at a head — which ones this drag
  /// is about to take.
  void _drawFenChart(Canvas canvas, Size vp) {
    const rowH = 16.0;
    const cellW = 21.0;
    const padX = 7.0;
    const padY = 7.0;
    final w = padX * 2 + cellW * 3 + 16;
    final h = padY * 2 + rowH * 3;
    // The screen's mid-right band — the same strip Water hangs its tide gauge
    // in, and the only edge no corner-pinned panel claims (the minimap owns
    // top-left, the joystick bottom-left, the action pad bottom-right).
    final origin = Offset(vp.width - w - 10, vp.height * 0.5 - h / 2);
    final rect = Rect.fromLTWH(origin.dx, origin.dy, w, h);
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFF0B0906).withValues(alpha: 0.72),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFE4C16A).withValues(alpha: 0.34),
    );

    final doomed = bogDoomedByHand;
    final hand = _fordUnderHand();
    // WHICH OF THESE ARE MINE. The chart is grouped by watercourse, because
    // that is what the rule is about — but a moor-altar's condition is about
    // the KNOLL ("every crossing that touches it is sod"), and the two
    // groupings do not line up. Without this, "this knoll still swims" named
    // a condition the player could not locate on the only map they had.
    final here = currentRoom.fen?.knoll == null
        ? const <String>{}
        : {for (final f in _fen.fordsOf(currentRoomId)) f.id};
    final sloughs = kSloughOrder.keys.toList()
      ..sort((a, b) => (kSloughOrder[a] ?? 0).compareTo(kSloughOrder[b] ?? 0));
    for (var r = 0; r < sloughs.length; r++) {
      final slough = sloughs[r];
      final ink = _sloughColour(slough);
      final y = origin.dy + padY + rowH * r + rowH / 2;
      // The watercourse's own mark, so the stones in the world and the rows
      // on the chart are obviously the same three things.
      _drawSloughMark(canvas, Offset(origin.dx + padX + 4, y), ink, r);
      // The water itself, running head to mouth behind its crossings.
      canvas.drawLine(
        Offset(origin.dx + padX + 13, y),
        Offset(origin.dx + w - padX, y),
        Paint()
          ..strokeWidth = 1.1
          ..color = ink.withValues(alpha: 0.30),
      );
      for (var i = 0; i < 3; i++) {
        final ford = kBogFords.firstWhere(
          (f) => f.slough == slough && f.index == i,
        );
        final c = Offset(origin.dx + padX + 20 + cellW * i, y);
        final state = _fen.stateOf(ford.id);
        if (here.contains(ford.id)) {
          // The crossings that moor the knoll you are standing on.
          canvas.drawLine(
            c.translate(-8, 7),
            c.translate(8, 7),
            Paint()
              ..strokeWidth = 1.4
              ..color = const Color(0xFFE4C16A).withValues(alpha: 0.7),
          );
        }
        switch (state) {
          case BogFordState.sod:
            // A road: solid, and the widest thing on its row.
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: c, width: 17, height: 8),
                const Radius.circular(3),
              ),
              Paint()..color = const Color(0xFF9BB05A),
            );
          case BogFordState.mire:
            // Still live, still yours to spend.
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: c, width: 15, height: 7),
                const Radius.circular(3),
              ),
              Paint()..color = const Color(0xFF8A7350).withValues(alpha: 0.75),
            );
          case BogFordState.drowned:
            // Gone. Drawn, because what you have spent is part of the map.
            canvas.drawLine(
              c.translate(-7, 0),
              c.translate(7, 0),
              Paint()
                ..strokeWidth = 1.4
                ..color = const Color(0xFF2A4A52).withValues(alpha: 0.65),
            );
        }
        if (doomed.contains(ford.id)) {
          final pulse = (sin(bog.clock * 4) * 0.5 + 0.5);
          canvas.drawRect(
            Rect.fromCenter(center: c, width: 21, height: 13),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = const Color(
                0xFF8FC8D8,
              ).withValues(alpha: 0.5 + pulse * 0.4),
          );
        } else if (hand != null && ford.id == hand.id) {
          // The one under your hand.
          canvas.drawRect(
            Rect.fromCenter(center: c, width: 21, height: 13),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = const Color(0xFFE4C16A).withValues(alpha: 0.85),
          );
        }
      }
    }
  }

  /// The fen floor, under everything else in the room.
  void _renderBogFloor(Canvas canvas, DungeonRoom room) {
    if (room.fen?.knoll == null) {
      _renderDrownedFloor(canvas, room);
      return;
    }
    _renderPlainFloor(canvas, room.bounds, room.id == layout.entranceRoomId);
    final g = _bogGround(room);
    final t = bog.clock;

    // The peat itself: a dark wash over the generic slab so the ground reads
    // as saturated rather than paved.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        room.bounds.deflate(8),
        const Radius.circular(34),
      ),
      Paint()..color = _fenPeat.withValues(alpha: 0.34),
    );

    // THE POOLS ARE THE KNOLL'S OWN GAUGE. A knoll stands DRY-FOOTED when
    // every crossing that touches it is sod, and that — not a number in the
    // corner of the HUD — is what the moor-altars answer to. So the ground
    // says it: a knoll that still swims lies under standing water, and a
    // drained one has cracked mud where the water was. State lives ON the
    // thing it belongs to (§7.9.2).
    final drained = _fen.isDry(room.id) && room.fen?.knoll != null;
    for (var i = 0; i < g.pools.length; i++) {
      if (drained) {
        canvas.drawPath(
          g.pools[i],
          Paint()..color = _fenSlurry.withValues(alpha: 0.30),
        );
        // Crazing: three cracks across the dry pan.
        final c = g.poolCentres[i];
        for (var k = 0; k < 3; k++) {
          final a = k * 2.1 + i;
          canvas.drawLine(
            c + Offset(cos(a) * 10, sin(a) * 6),
            c + Offset(cos(a) * 34, sin(a) * 18),
            Paint()
              ..strokeWidth = 1.1
              ..color = _fenPeat.withValues(alpha: 0.75),
          );
        }
        continue;
      }
      canvas.drawPath(
        g.pools[i],
        Paint()..color = _fenWater.withValues(alpha: 0.66),
      );
      canvas.drawPath(
        g.pools[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _fenSheen.withValues(alpha: 0.10),
      );
      final c = g.poolCentres[i];
      final phase = sin(t * 0.5 + i * 1.3);
      canvas.drawLine(
        Offset(c.dx - 20, c.dy + phase * 7),
        Offset(c.dx + 22, c.dy + phase * 7 - 2),
        Paint()
          ..strokeWidth = 1.2
          ..color = _fenSheen.withValues(alpha: 0.13),
      );
    }

    // Hummocks: a peat shadow under, the mound, then the moss cap on top.
    for (var i = 0; i < g.hummocks.length; i++) {
      canvas.save();
      canvas.translate(0, 5);
      canvas.drawPath(
        g.hummocks[i],
        Paint()..color = Colors.black.withValues(alpha: 0.28),
      );
      canvas.restore();
      canvas.drawPath(
        g.hummocks[i],
        Paint()..color = _fenPeat.withValues(alpha: 0.9),
      );
      canvas.drawPath(
        g.mossCaps[i],
        Paint()..color = _fenMoss.withValues(alpha: 0.55),
      );
    }

    // Bog-oak: a black root out of the ground, leaning where it fell.
    for (var i = 0; i < g.bogOak.length; i++) {
      final o = g.bogOak[i];
      final lean = g.bogOakLean[i];
      final top = o + Offset(sin(lean) * 40, -46);
      canvas.drawPath(
        Path()
          ..moveTo(o.dx - 13, o.dy + 6)
          ..quadraticBezierTo(o.dx - 6, o.dy - 20, top.dx - 5, top.dy)
          ..lineTo(top.dx + 6, top.dy + 3)
          ..quadraticBezierTo(o.dx + 8, o.dy - 18, o.dx + 14, o.dy + 6)
          ..close(),
        Paint()..color = _fenOak,
      );
      // Two broken limbs, so it reads as a drowned tree and not a post.
      for (var k = -1; k <= 1; k += 2) {
        canvas.drawLine(
          top + Offset(0, 8),
          top + Offset(k * 17.0, -4 + k * 3.0),
          Paint()
            ..strokeWidth = 3
            ..color = _fenOak,
        );
      }
    }

    // THE WEED SKIN — the entry rite, and it drew nothing.
    //
    // The fen's face opens under a mat of floating weed, and Water sluices it
    // off so the gate's three crossings show themselves. Nothing rendered it,
    // so the first room of the planet was a bog with three doorways missing
    // and no reason on screen to press anything — Air's entry rite failed the
    // same way, from the same cause, and it is how a dungeon ends up
    // unstartable.
    if (room.id == layout.entranceRoomId && !entryDoorRevealed) {
      // It lies on the WATER, out where the crossings are — not over the
      // knoll you are standing on. A mat thrown across the whole room hides
      // the sarsen, the wallow and the ground under your own feet, and then
      // sluicing it reads as the room being repainted rather than as the fen
      // showing you its crossings.
      final b = room.bounds.deflate(10);
      final over = Rect.fromLTRB(
        b.left + b.width * 0.44,
        b.top,
        b.right,
        b.bottom,
      );
      // No clip: a clipped mat ends in a straight vertical seam down the
      // middle of the room, which is the one shape a raft of floating weed
      // never has. It thins out westward instead.
      for (var i = 0; i < 18; i++) {
        final fx = (i * 37 % 100) / 100;
        final c = Offset(
          over.left - 120 + (over.width + 120) * fx,
          over.top + over.height * ((i * 53 % 100) / 100),
        );
        final thin = ((c.dx - b.left - b.width * 0.36) / (b.width * 0.26))
            .clamp(0.0, 1.0);
        final drift = sin(t * 0.25 + i) * 4;
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(drift, 0),
            width: 96 + (i % 3) * 34,
            height: 50 + (i % 4) * 16,
          ),
          Paint()
            ..color = const Color(0xFF33401F).withValues(alpha: 0.55 * thin),
        );
      }
      // Fibrous: the weed is a mat of strands, not a green rectangle.
      for (var i = 0; i < 30; i++) {
        final x = over.left + over.width * ((i * 29 % 100) / 100);
        final y = over.top + over.height * ((i * 61 % 100) / 100);
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 22 + (i % 3) * 8, y + 5 - (i % 5) * 3),
          Paint()
            ..strokeWidth = 2
            ..color = const Color(0xFF5D6B33).withValues(alpha: 0.42),
        );
      }
    }

    // Cotton-grass.
    for (var i = 0; i < g.cotton.length; i++) {
      final c = g.cotton[i];
      final sway = sin(t * 0.9 + i * 2.2) * 1.6;
      canvas.drawLine(
        c,
        c + Offset(sway, -9),
        Paint()
          ..strokeWidth = 1.2
          ..color = _fenMoss.withValues(alpha: 0.7),
      );
      canvas.drawCircle(
        c + Offset(sway, -11),
        2.1,
        Paint()..color = _fenCotton.withValues(alpha: 0.55),
      );
    }
  }

  /// A CROSSING, DRAWN AS A CROSSING.
  ///
  /// It used to be a 92px stub of colour at the bank, which put the one thing
  /// this planet is ABOUT — is that ground firm, soft, or gone — into a smudge
  /// mostly hidden behind its own door plate, and made the three states
  /// distinguishable only by fill colour at arm's length. A crossing now runs
  /// from the head you work it at all the way OUT to the doorway it leads
  /// through, so the map you are authoring is legible from the middle of the
  /// room, and the drowned ones read as gone from across it.
  void _renderFordHeads(Canvas canvas, DungeonRoom room) {
    final f = _fen;
    if (room.id == layout.entranceRoomId && !entryDoorRevealed) return;
    for (final door in room.doors) {
      final ford = _fordForDoor(room, door);
      if (ford == null) continue;
      final head = ford.headIn(room.id);
      if (head == null) continue;
      _renderCrossing(canvas, ford, head, door.rect.center, f.stateOf(ford.id));
      _renderFordMarker(canvas, ford, head);
    }
    // THE PRICE, BEFORE YOU PAY IT. Stand at a crossing you could drag and
    // every crossing that drag would drown is marked as doomed — here if it
    // is in this room, and on the fen chart if it is not. The drag is
    // permanent; a player has to be able to SEE what it costs before
    // committing, which is what turns a provably-unique puzzle into one you
    // can steer into instead of search for (§7.9.7).
    final doomed = bogDoomedByHand;
    for (final id in doomed) {
      final ford = f.fordById(id);
      final head = ford?.headIn(room.id);
      if (ford == null || head == null) continue;
      _renderDoomedMark(canvas, head);
    }
  }

  /// A MARKER STONE at the head of a crossing, cut with its watercourse's
  /// mark and scored with how far down that water it lies. Two crossings
  /// wearing the same mark share their water — which is the one fact the
  /// planet's rule turns on and the one fact nothing used to state.
  void _renderFordMarker(Canvas canvas, BogFord ford, Offset head) {
    final ink = _sloughColour(ford.slough);
    final at = head + const Offset(0, -46);
    // A short cut stone, leaning, with a mossy foot.
    canvas.drawOval(
      Rect.fromCenter(center: at.translate(0, 26), width: 34, height: 12),
      Paint()..color = _fenPeat.withValues(alpha: 0.85),
    );
    final stone = Path()
      ..moveTo(at.dx - 11, at.dy + 24)
      ..lineTo(at.dx - 8, at.dy - 20)
      ..lineTo(at.dx + 9, at.dy - 18)
      ..lineTo(at.dx + 12, at.dy + 24)
      ..close();
    canvas.drawPath(stone, Paint()..color = const Color(0xFF4A4740));
    canvas.drawPath(
      stone,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF5E5B52),
    );
    // The watercourse's mark, cut into the face and picked out in its ink.
    _drawSloughMark(canvas, at.translate(0, -2), ink, kSloughOrder[ford.slough] ?? 0);
    // …and the notches: how far down this water the crossing lies.
    for (var i = 0; i <= ford.index; i++) {
      canvas.drawLine(
        Offset(at.dx - 6 + i * 6, at.dy + 16),
        Offset(at.dx - 6 + i * 6, at.dy + 21),
        Paint()
          ..strokeWidth = 1.8
          ..color = ink.withValues(alpha: 0.85),
      );
    }
  }

  /// The three marks, drawn small enough to be a carving and distinct enough
  /// to tell apart at a glance: the Cormorant's hooked neck, the Adder's
  /// wave, the Tarn's ring.
  void _drawSloughMark(Canvas canvas, Offset at, Color ink, int which) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = ink;
    switch (which) {
      case 0:
        canvas.drawPath(
          Path()
            ..moveTo(at.dx - 6, at.dy + 6)
            ..quadraticBezierTo(at.dx - 1, at.dy + 2, at.dx - 1, at.dy - 4)
            ..quadraticBezierTo(at.dx - 1, at.dy - 8, at.dx + 6, at.dy - 7),
          p,
        );
      case 1:
        canvas.drawPath(
          Path()
            ..moveTo(at.dx - 7, at.dy + 4)
            ..quadraticBezierTo(at.dx - 2, at.dy - 6, at.dx + 1, at.dy)
            ..quadraticBezierTo(at.dx + 4, at.dy + 6, at.dx + 7, at.dy - 4),
          p,
        );
      default:
        canvas.drawCircle(at, 5.5, p);
    }
  }

  /// A crossing this drag is about to drown: a ring closing on it, and the
  /// water already showing through.
  void _renderDoomedMark(Canvas canvas, Offset head) {
    final pulse = (sin(bog.clock * 4) * 0.5 + 0.5);
    canvas.drawOval(
      Rect.fromCenter(center: head, width: 92, height: 52),
      Paint()..color = _fenWater.withValues(alpha: 0.30 + pulse * 0.18),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: head,
        width: 92 - pulse * 14,
        height: 52 - pulse * 8,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const Color(0xFF8FC8D8).withValues(alpha: 0.55 + pulse * .3),
    );
  }

  /// One crossing, from [head] (the bank you work it at) to [mouth] (its
  /// doorway). Drawn as a ribbon with a spine, so it curves like water and
  /// never like a corridor.
  void _renderCrossing(
    Canvas canvas,
    BogFord ford,
    Offset head,
    Offset mouth,
    BogFordState state,
  ) {
    final along = mouth - head;
    final len = along.distance;
    if (len < 1) return;
    final dir = along / len;
    final norm = Offset(-dir.dy, dir.dx);
    // The ribbon bows a little to one side, per ford, so no two crossings in
    // a room are parallel lines.
    final bow = sin(ford.index * 2.1 + ford.slough.hashCode % 7) * 16;
    final mid = head + dir * (len / 2) + norm * bow;

    Path ribbon(double halfWidth) {
      final hA = head + norm * halfWidth;
      final hB = head - norm * halfWidth;
      final mA = mouth + norm * halfWidth;
      final mB = mouth - norm * halfWidth;
      return Path()
        ..moveTo(hA.dx, hA.dy)
        ..quadraticBezierTo(
          mid.dx + norm.dx * halfWidth,
          mid.dy + norm.dy * halfWidth,
          mA.dx,
          mA.dy,
        )
        ..lineTo(mB.dx, mB.dy)
        ..quadraticBezierTo(
          mid.dx - norm.dx * halfWidth,
          mid.dy - norm.dy * halfWidth,
          hB.dx,
          hB.dy,
        )
        ..close();
    }

    Offset at(double t) {
      final a = Offset.lerp(head, mid, t)!;
      final b = Offset.lerp(mid, mouth, t)!;
      return Offset.lerp(a, b, t)!;
    }

    /// The same ribbon with a BROKEN EDGE — the half-width wanders along the
    /// run. A constant-width band reads as a built structure (the first cut
    /// of this made every mire crossing look like a boardwalk), and mire is
    /// precisely the crossing nobody built.
    Path ragged(double halfWidth, double seed) {
      const n = 9;
      double w(int i) =>
          halfWidth * (0.72 + 0.5 * (sin(i * 2.3 + seed) * 0.5 + 0.5));
      final path = Path();
      for (var i = 0; i <= n; i++) {
        final p = at(i / n) + norm * w(i);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      for (var i = n; i >= 0; i--) {
        final p = at(i / n) - norm * w(i + 5);
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      return path;
    }

    switch (state) {
      case BogFordState.mire:
        // QUAKING. A wide soft slurry, a paler skin on it, and ripples
        // travelling out along the crossing: it moves, so it is not to be
        // trusted with anything heavy.
        // Wet ground with no edge to it — three broken-edged ribbons, each
        // wandering differently, so the crossing frays into the fen on both
        // sides instead of stopping at a line.
        canvas.drawPath(
          ragged(30, 0.0),
          Paint()..color = _fenPeat.withValues(alpha: 0.55),
        );
        canvas.drawPath(
          ragged(23, 1.7),
          Paint()..color = _fenSlurry.withValues(alpha: 0.26),
        );
        canvas.drawPath(
          ragged(13, 3.4),
          Paint()..color = _fenSlurry.withValues(alpha: 0.22),
        );
        // QUAKING. Wet blisters travelling out along it, not rungs across it:
        // perpendicular strokes at regular spacing are plank joints, which is
        // how the first cut of this turned a bog into a bridge.
        for (var i = 0; i < 4; i++) {
          final t = ((bog.clock * 0.22 + i / 4) % 1.0);
          final p = at(t);
          final s = 1 - (t - 0.5).abs() * 1.4;
          canvas.drawOval(
            Rect.fromCenter(
              center: p + norm * (sin(i * 2.7) * 9),
              width: 26 * s,
              height: 9 * s,
            ),
            Paint()..color = _fenSheen.withValues(alpha: 0.09 * s),
          );
        }
      case BogFordState.sod:
        // A CAUSEWAY. Something built: a peat shadow under it, a raised bank,
        // a lit crown down the middle and a root fringe along both lips. It
        // should read as the only ground here you would put a stone on.
        canvas.save();
        canvas.translate(0, 6);
        canvas.drawPath(
          ribbon(26),
          Paint()..color = Colors.black.withValues(alpha: 0.30),
        );
        canvas.restore();
        canvas.drawPath(
          ribbon(26),
          Paint()..color = _fenPeat.withValues(alpha: 0.95),
        );
        canvas.drawPath(
          ribbon(19),
          Paint()..color = _fenSod.withValues(alpha: 0.80),
        );
        canvas.drawPath(
          ribbon(6),
          Paint()..color = _fenSod.withValues(alpha: 0.95),
        );
        for (var i = 1; i < 10; i++) {
          final p = at(i / 10);
          for (var k = -1; k <= 1; k += 2) {
            canvas.drawLine(
              p + norm * (k * 22.0),
              p + norm * (k * 30.0) + dir * (i.isEven ? 4.0 : -4.0),
              Paint()
                ..strokeWidth = 2
                ..color = _fenMoss.withValues(alpha: 0.55),
            );
          }
        }
      case BogFordState.drowned:
        // OPEN WATER, and it is never coming back. Wider than the crossing
        // ever was — the banks went too — with weed drifting on it and a
        // broken lip where the ground used to run in.
        canvas.drawPath(
          ribbon(34),
          Paint()..color = _fenWater.withValues(alpha: 0.92),
        );
        canvas.drawPath(
          ribbon(34),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _fenSheen.withValues(alpha: 0.12),
        );
        for (var i = 0; i < 3; i++) {
          final t0 = 0.2 + i * 0.28;
          final drift = sin(bog.clock * 0.4 + i * 2.1) * 12;
          final a = at(t0) + norm * (drift * 0.5);
          final w = Path()
            ..moveTo(a.dx - dir.dx * 26, a.dy - dir.dy * 26)
            ..quadraticBezierTo(
              a.dx + norm.dx * drift,
              a.dy + norm.dy * drift,
              a.dx + dir.dx * 26,
              a.dy + dir.dy * 26,
            );
          canvas.drawPath(
            w,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2
              ..color = _fenSheen.withValues(alpha: 0.18),
          );
        }
        // The broken bank at the near end: the ground stops, mid-crossing.
        canvas.drawLine(
          head + norm * 30,
          head - norm * 30,
          Paint()
            ..strokeWidth = 4
            ..color = _fenPeat.withValues(alpha: 0.85),
        );
    }
  }

  void _renderKnollFurniture(Canvas canvas, DungeonRoom room) {
    final f = _fen;
    final fen = room.fen;
    if (fen == null) return;

    final knoll = fen.knoll;
    if (knoll != null) {
      _renderWallow(canvas, knoll.wallow);
      // The sarsen, wherever it currently stands. At the gate it is LYING in
      // the silt where it fell; anywhere else the party has walked it there.
      if (f.sarsenKnoll == room.id && !f.sarsenSeated) {
        _renderSarsen(
          canvas,
          _sarsenStandsAt(),
          fallen: f.sarsenKnoll == kSarsenHomeKnoll,
        );
      }
    }

    final moor = fen.moor;
    if (moor != null) {
      _renderMoorAltar(
        canvas,
        moor.basin,
        holding: f.moorsWoken.contains(room.id),
        dryFooted: f.isDry(room.id),
      );
    }

    final altar = fen.altar;
    if (altar != null) _renderSinkingAltar(canvas, altar);

    final sough = fen.sough;
    if (sough != null) _renderSough(canvas, sough);

    if (fen.sinkPit != null) _renderBlackLead(canvas, fen);

    final anchor = fen.anchor;
    if (anchor != null) _renderMireAnchor(canvas, anchor, firm: f.anchorFirm);
  }

  /// THE WALLOW — the soft eye at a knoll's heart, and the way down from
  /// every one of them. It is a door the player uses more than any other on
  /// this planet and it was a flat dark circle; a hole you let the fen pull
  /// you into should look like it is pulling.
  void _renderWallow(Canvas canvas, Offset at) {
    final breathe = sin(bog.clock * 1.1);
    // The slumped lip: peat sagging inward all round.
    canvas.drawOval(
      Rect.fromCenter(center: at.translate(0, 4), width: 84, height: 46),
      Paint()..color = _fenPeat.withValues(alpha: 0.95),
    );
    canvas.drawOval(
      Rect.fromCenter(center: at, width: 74, height: 38),
      Paint()..color = _fenSlurry.withValues(alpha: 0.45),
    );
    // Three draw-down rings, each one narrower and lower: the pull.
    for (var i = 0; i < 3; i++) {
      final k = 1 - i * 0.28;
      canvas.drawOval(
        Rect.fromCenter(
          center: at.translate(0, i * 2.0),
          width: 60 * k + breathe * 2,
          height: 30 * k + breathe,
        ),
        Paint()
          ..color = Color.lerp(
            _fenSlurry,
            _fenWater,
            0.4 + i * 0.3,
          )!.withValues(alpha: 0.85),
      );
    }
    // Bubbles coming up out of it, because something down there is breathing.
    for (var i = 0; i < 2; i++) {
      final t = ((bog.clock * 0.5 + i * 0.5) % 1.0);
      canvas.drawCircle(
        at.translate((i == 0 ? -9 : 11).toDouble(), 6 - t * 14),
        2.2 * (1 - t),
        Paint()..color = _fenSheen.withValues(alpha: 0.28 * (1 - t)),
      );
    }
  }

  /// A MOOR-ALTAR — a carved standing stone with a peat-black basin cut into
  /// its foot. Its state is drawn ON it, never in the HUD: an empty bowl on
  /// sodden ground, water visibly DRAINING AWAY through the peat when the
  /// knoll still swims, and a full, still bowl when it holds. That draining
  /// bowl is how the world teaches the dry-footed rule without a caption.
  void _renderMoorAltar(
    Canvas canvas,
    Offset basin, {
    required bool holding,
    required bool dryFooted,
  }) {
    // The plinth the bowl is cut into.
    canvas.drawPath(
      Path()
        ..moveTo(basin.dx - 46, basin.dy + 16)
        ..lineTo(basin.dx - 38, basin.dy - 10)
        ..lineTo(basin.dx + 38, basin.dy - 10)
        ..lineTo(basin.dx + 46, basin.dy + 16)
        ..close(),
      Paint()..color = const Color(0xFF3B3830),
    );
    // The standing stone above it, leaning as everything here leans, with
    // three cut grooves down its face.
    final stone = Path()
      ..moveTo(basin.dx - 19, basin.dy - 8)
      ..lineTo(basin.dx - 13, basin.dy - 104)
      ..lineTo(basin.dx + 14, basin.dy - 97)
      ..lineTo(basin.dx + 20, basin.dy - 8)
      ..close();
    canvas.drawPath(stone, Paint()..color = const Color(0xFF4A4740));
    canvas.drawPath(
      stone,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF5E5B52),
    );
    for (var i = 0; i < 3; i++) {
      final y = basin.dy - 30 - i * 22;
      canvas.drawLine(
        Offset(basin.dx - 10, y),
        Offset(basin.dx + 11, y - 3),
        Paint()
          ..strokeWidth = 1.6
          ..color = const Color(0xFF23211C).withValues(alpha: 0.8),
      );
    }
    // Lichen on the weather side.
    canvas.drawCircle(
      Offset(basin.dx - 9, basin.dy - 66),
      5,
      Paint()..color = _fenMoss.withValues(alpha: 0.45),
    );

    // The bowl.
    final bowl = Rect.fromCenter(center: basin, width: 66, height: 24);
    canvas.drawOval(bowl, Paint()..color = _fenPeat.withValues(alpha: 0.95));
    canvas.drawOval(
      bowl.deflate(3),
      Paint()..color = const Color(0xFF17140F),
    );
    if (holding) {
      // Still water, right to the rim, and the sky in it.
      canvas.drawOval(
        bowl.deflate(5),
        Paint()..color = const Color(0xFF2E4A4E),
      );
      canvas.drawOval(
        bowl.deflate(5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _fenSheen.withValues(alpha: 0.5),
      );
      canvas.drawLine(
        Offset(basin.dx - 14, basin.dy - 1),
        Offset(basin.dx + 10, basin.dy - 2),
        Paint()
          ..strokeWidth = 1.4
          ..color = _fenSheen.withValues(alpha: 0.35),
      );
    } else if (!dryFooted) {
      // SODDEN GROUND DRINKS IT. A shallow lick of water in the bottom and
      // a bead running out under the plinth — the bowl is losing it.
      canvas.drawOval(
        Rect.fromCenter(
          center: basin.translate(0, 4),
          width: 34,
          height: 8,
        ),
        Paint()..color = const Color(0xFF2E4A4E).withValues(alpha: 0.55),
      );
      final t = (bog.clock * 0.6) % 1.0;
      canvas.drawCircle(
        Offset(basin.dx + 22, basin.dy + 10 + t * 10),
        2.0 * (1 - t),
        Paint()..color = const Color(0xFF2E4A4E).withValues(alpha: 0.6),
      );
    }
  }

  /// THE SINKING ALTAR — the room the planet is named for, and it was a flat
  /// brown disc. It is a socket cut for the sarsen: a stone collar sunk in
  /// the peat, packed with the bog-resin cap until **Plant+Mud→Poison** eats
  /// it, and then an open throat with nothing in it but the shape of a stone.
  void _renderSinkingAltar(Canvas canvas, SinkingAltarSocket altar) {
    final c = altar.socket;
    // The apron of old, trodden peat round the socket.
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, 6), width: 190, height: 96),
      Paint()..color = _fenPeat.withValues(alpha: 0.55),
    );
    // The collar: eight kerbstones set round the throat.
    for (var i = 0; i < 8; i++) {
      final a = i / 8 * pi * 2 + 0.2;
      final p = Offset(c.dx + cos(a) * 62, c.dy + sin(a) * 33);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + pi / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 30, height: 17),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFF443F37),
      );
      canvas.restore();
    }
    // The throat.
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 96, height: 52),
      Paint()..color = const Color(0xFF120F0B),
    );
    if (!_fen.socketOpen) {
      // THE RESIN CAP: a domed, glossy plug of bog-resin, with the grain of
      // something that set while it was running.
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, -2), width: 92, height: 48),
        Paint()..color = const Color(0xFF5A3F1E),
      );
      for (var i = 0; i < 4; i++) {
        canvas.drawArc(
          Rect.fromCenter(
            center: c.translate(0, -2),
            width: 74 - i * 17.0,
            height: 38 - i * 9.0,
          ),
          pi * 0.15,
          pi * 0.7,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = const Color(0xFF7A5A2C).withValues(alpha: 0.6),
        );
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(-14, -12),
          width: 26,
          height: 11,
        ),
        Paint()..color = const Color(0xFF9A7638).withValues(alpha: 0.35),
      );
    } else if (!_fen.sarsenSeated) {
      // Open, and shaped for one thing. A ledge inside the throat says what
      // goes in it without a word.
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, 5), width: 62, height: 26),
        Paint()..color = const Color(0xFF241E17),
      );
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, 5), width: 62, height: 26),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _fenSlurry.withValues(alpha: 0.5),
      );
    }
    if (_fen.sarsenSeated) _renderSarsen(canvas, c.translate(0, 6));
  }

  /// THE SOUGH — the fen's outfall, and the anti-strand valve. A stone
  /// throat in the fane's wall with the peat-cutters' plug rammed into it;
  /// pulled, the whole bog runs for it.
  void _renderSough(Canvas canvas, Offset at) {
    // The stone throat.
    canvas.drawOval(
      Rect.fromCenter(center: at, width: 96, height: 74),
      Paint()..color = const Color(0xFF2A2620),
    );
    canvas.drawOval(
      Rect.fromCenter(center: at, width: 76, height: 56),
      Paint()..color = const Color(0xFF0A0907),
    );
    // Voussoirs round the mouth, so it reads as built and not as a hole.
    for (var i = 0; i < 9; i++) {
      final a = pi + i / 8 * pi;
      canvas.drawLine(
        at + Offset(cos(a) * 40, sin(a) * 31),
        at + Offset(cos(a) * 50, sin(a) * 39),
        Paint()
          ..strokeWidth = 3
          ..color = const Color(0xFF3E382F),
      );
    }
    if (!_fen.soughFreed) {
      // The plug: a rammed peat bung, banded, with the cutters' iron ring.
      canvas.drawOval(
        Rect.fromCenter(center: at, width: 62, height: 46),
        Paint()..color = const Color(0xFF3A2E1E),
      );
      for (var i = -1; i <= 1; i++) {
        canvas.drawLine(
          at + Offset(-28, i * 12.0),
          at + Offset(28, i * 12.0),
          Paint()
            ..strokeWidth = 2
            ..color = const Color(0xFF23190F),
        );
      }
      canvas.drawCircle(
        at.translate(0, -2),
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF6E6455),
      );
    } else {
      // Pulled. The fen is going down it: streaks running in, and a throat
      // with nothing left to stop it.
      for (var i = 0; i < 5; i++) {
        final a0 = bog.clock * 1.4 + i * 1.26;
        canvas.drawLine(
          at + Offset(cos(a0) * 66, sin(a0) * 52),
          at + Offset(cos(a0) * 28, sin(a0) * 22),
          Paint()
            ..strokeWidth = 2.4
            ..color = _fenSheen.withValues(alpha: 0.35),
        );
      }
    }
  }

  /// BOGDRYA'S MIRE ANCHOR — quaking floor until a Mud hand sets it, and
  /// then a pad of hard ground you can plant a foot on. It was a coloured
  /// circle; firm ground and soft ground have to look like different things
  /// in the one room where standing on the wrong one loses the fight.
  void _renderMireAnchor(Canvas canvas, Offset at, {required bool firm}) {
    if (!firm) {
      // Soft: the surface travelling, with nothing under it.
      for (var i = 0; i < 3; i++) {
        final t = ((bog.clock * 0.5 + i / 3) % 1.0);
        canvas.drawOval(
          Rect.fromCenter(
            center: at,
            width: 30 + t * 60,
            height: 16 + t * 32,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _fenSlurry.withValues(alpha: 0.35 * (1 - t)),
        );
      }
      // Bigger than the ambient pans around it, and ringed: this is the one
      // patch in the hollow that is a FIXTURE rather than weather, and the
      // fight is lost standing anywhere else.
      canvas.drawOval(
        Rect.fromCenter(center: at, width: 112, height: 56),
        Paint()..color = _fenSlurry.withValues(alpha: 0.30),
      );
      canvas.drawOval(
        Rect.fromCenter(center: at, width: 112, height: 56),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _fenPeat.withValues(alpha: 0.9),
      );
      return;
    }
    // Set: a dried pad, crazed across, sitting proud of the mire.
    canvas.drawOval(
      Rect.fromCenter(center: at.translate(0, 6), width: 122, height: 60),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawOval(
      Rect.fromCenter(center: at, width: 118, height: 58),
      Paint()..color = const Color(0xFF6B5B41),
    );
    canvas.drawOval(
      Rect.fromCenter(center: at, width: 118, height: 58),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF8A7856),
    );
    for (var i = 0; i < 5; i++) {
      final a = i * 1.26 + 0.3;
      canvas.drawLine(
        at + Offset(cos(a) * 10, sin(a) * 5),
        at + Offset(cos(a) * 55, sin(a) * 27),
        Paint()
          ..strokeWidth = 1.2
          ..color = const Color(0xFF3A3021),
      );
    }
  }

  /// THE BLACK LEAD — the Lost Maxim's place, and it has to be drawn as a
  /// PLACE: a cut in the fane's floor running away into a corner with no
  /// door at the end of it, choked and dead until the fen above is carrying
  /// all the water it can. Nothing here is labelled and nothing is a gauge:
  /// the lead either runs or it does not, and the sink either is water or is
  /// peat. Those two readings are the whole state of the secret.
  void _renderBlackLead(Canvas canvas, BogFen fen) {
    final sink = fen.sinkPit!;
    final head = fen.leadHead;
    final cuts = fen.peatCuts;
    if (head == null || cuts == null) return;
    final running = _fen.fenAtFullDrown;
    final found = bog.cutsFound;

    // The channel, as one curve head → cuts → sink.
    final spine = Path()..moveTo(head.dx, head.dy);
    var prev = head;
    for (final c in [...cuts, sink]) {
      final mid = Offset((prev.dx + c.dx) / 2, (prev.dy + c.dy) / 2 + 14);
      spine.quadraticBezierTo(mid.dx, mid.dy, c.dx, c.dy);
      prev = c;
    }
    // The cut banks: always here, because the cutters dug this long ago.
    canvas.drawPath(
      spine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 40
        ..strokeCap = StrokeCap.round
        ..color = _fenPeat.withValues(alpha: 0.85),
    );
    canvas.drawPath(
      spine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 27
        ..strokeCap = StrokeCap.round
        ..color = (running ? _fenWater : const Color(0xFF241E17)).withValues(
          alpha: running ? 0.95 : 0.9,
        ),
    );
    if (running) {
      // It RUNS. Three lights travelling down the lead, away from the fen.
      // ONE `computeMetrics` for all three — it allocates, and this is a
      // per-frame painter in the room the player stands in most.
      final metrics = spine.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final m = metrics.first;
        for (var i = 0; i < 3; i++) {
          final t = ((bog.clock * 0.30 + i / 3) % 1.0);
          final along = m.getTangentForOffset(m.length * t)?.position;
          if (along == null) continue;
          canvas.drawCircle(
            along,
            4.5,
            Paint()..color = _fenSheen.withValues(alpha: 0.30),
          );
        }
      }
    } else {
      // Choked: old peat lying in the bottom of a dry cut.
      canvas.drawPath(
        spine,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round
          ..color = _fenSlurry.withValues(alpha: 0.22),
      );
    }

    // THE PEAT CUTS — the cutters' trenches off the lead. Under black water
    // and not there to be found until Water has read them.
    for (var i = 0; i < cuts.length; i++) {
      final c = cuts[i];
      if (!found) continue;
      final poured = bog.poured.contains(i);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-0.5);
      final trench = Rect.fromCenter(
        center: Offset.zero,
        width: 96,
        height: 34,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(trench.inflate(5), const Radius.circular(8)),
        Paint()..color = _fenPeat.withValues(alpha: 0.95),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(trench, const Radius.circular(6)),
        Paint()..color = poured
            ? const Color(0xFF17140F)
            : const Color(0xFF3E3322),
      );
      if (!poured) {
        // Turves still stacked on the lip, and the lip itself unbroken.
        for (var k = -1; k <= 1; k++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(k * 27.0, -26),
                width: 24,
                height: 11,
              ),
              const Radius.circular(3),
            ),
            Paint()..color = _fenSlurry.withValues(alpha: 0.5),
          );
        }
      } else {
        // Poured: the lip dragged away, and a tongue of peat gone downhill.
        canvas.drawPath(
          Path()
            ..moveTo(-18, 14)
            ..lineTo(18, 14)
            ..lineTo(34, 40)
            ..lineTo(-6, 38)
            ..close(),
          Paint()..color = _fenSlurry.withValues(alpha: 0.45),
        );
      }
      canvas.restore();
    }

    // THE SINK. Clean water you can see the bottom of, or peat — and the
    // seed going under as it thickens. This is the only readout the secret
    // has, and it is the thing itself.
    final k = bog.sinkThickness;
    canvas.drawOval(
      Rect.fromCenter(center: sink.translate(0, 5), width: 130, height: 74),
      Paint()..color = _fenPeat.withValues(alpha: 0.9),
    );
    canvas.drawOval(
      Rect.fromCenter(center: sink, width: 116, height: 62),
      Paint()..color = Color.lerp(
        const Color(0xFF10262B),
        const Color(0xFF1B1409),
        k,
      )!,
    );
    if (k < 0.98) {
      // Water still: a sheen, and the bottom showing through.
      canvas.drawOval(
        Rect.fromCenter(center: sink, width: 116, height: 62),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _fenSheen.withValues(alpha: 0.22 * (1 - k)),
      );
      canvas.drawLine(
        sink.translate(-26, -4),
        sink.translate(12, -6),
        Paint()
          ..strokeWidth = 1.4
          ..color = _fenSheen.withValues(alpha: 0.20 * (1 - k)),
      );
    }
    if (bog.seedSet && !discoveredClouds.contains(kMudNoLotusEggId)) {
      // The seed, sinking as the peat comes in. At full thickness it is gone.
      final sunk = (1 - k).clamp(0.0, 1.0);
      if (sunk > 0.02) {
        canvas.drawOval(
          Rect.fromCenter(
            center: sink.translate(0, 8 * k),
            width: 13 * sunk,
            height: 9 * sunk,
          ),
          Paint()..color = const Color(0xFF8FA45E).withValues(alpha: sunk),
        );
      }
    }
    if (discoveredClouds.contains(kMudNoLotusEggId)) {
      // It came up anyway.
      for (var i = 0; i < 8; i++) {
        final a = i / 8 * pi * 2;
        canvas.drawOval(
          Rect.fromCenter(
            center: sink + Offset(cos(a) * 20, sin(a) * 11),
            width: 26,
            height: 13,
          ),
          Paint()..color = const Color(0xFFF2D7E6).withValues(alpha: 0.75),
        );
      }
      canvas.drawCircle(
        sink,
        9,
        Paint()..color = const Color(0xFFF7E9A8),
      );
    }
  }

  /// The sarsen — the fen's fallen standing stone. Lying in the silt where it
  /// went down, or upright once it is being walked.
  void _renderSarsen(Canvas canvas, Offset at, {bool fallen = false}) {
    // A stone lying in silt is pressed into it: the ground goes first, then
    // the stone, or the slab reads as a translucent shard floating on the
    // floor — which is what the fallen one looked like at the gate.
    if (fallen) {
      canvas.drawOval(
        Rect.fromCenter(center: at.translate(4, 10), width: 116, height: 44),
        Paint()..color = Colors.black.withValues(alpha: 0.34),
      );
      canvas.drawOval(
        Rect.fromCenter(center: at.translate(0, 8), width: 128, height: 48),
        Paint()..color = _fenSlurry.withValues(alpha: 0.30),
      );
    }
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (fallen) canvas.rotate(1.36);
    final body = Path()
      ..moveTo(-23, 16)
      ..lineTo(-16, -64)
      ..lineTo(15, -58)
      ..lineTo(23, 16)
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFF5B5750));
    // A lit face and a shadowed one, so it has a side.
    canvas.drawPath(
      Path()
        ..moveTo(-16, -64)
        ..lineTo(15, -58)
        ..lineTo(23, 16)
        ..lineTo(8, 16)
        ..close(),
      Paint()..color = const Color(0xFF6C675E),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF3A362F),
    );
    // Lichen, and the old peat line it stood in.
    canvas.drawCircle(
      const Offset(-6, -40),
      6,
      Paint()..color = _fenMoss.withValues(alpha: 0.4),
    );
    canvas.drawLine(
      const Offset(-20, -4),
      const Offset(21, -6),
      Paint()
        ..strokeWidth = 2
        ..color = const Color(0xFF2F2A22).withValues(alpha: 0.7),
    );
    canvas.restore();
    // It is heavy: the ground under it is pressed down.
    canvas.drawOval(
      Rect.fromCenter(
        center: at.translate(0, fallen ? 4 : 14),
        width: fallen ? 86 : 56,
        height: fallen ? 26 : 18,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.32),
    );
  }

  /// THE SMEAR — the drag, travelling. A viscous streak runs out from the
  /// worked crossing and the ones it drowned visibly slump. This is the
  /// planet's signature and it is deliberately nothing like a tile flood.
  void _renderSmear(Canvas canvas, DungeonRoom room) {
    if (bog.smear <= 0) return;
    final t = 1 - bog.smear / _kSmearSeconds;
    final a = (1 - t) * 0.7;
    canvas.drawCircle(
      bog.smearAt,
      30 + t * 90,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * (1 - t)
        ..color = _fenSlurry.withValues(alpha: a),
    );
    for (final id in bog.smearLost) {
      final ford = _fen.fordById(id);
      final head = ford?.headIn(room.id);
      if (head == null) continue;
      canvas.drawLine(
        bog.smearAt,
        Offset.lerp(bog.smearAt, head, t.clamp(0.0, 1.0))!,
        Paint()
          ..strokeWidth = 7
          ..color = _fenWater.withValues(alpha: a + 0.15),
      );
    }
  }
}
