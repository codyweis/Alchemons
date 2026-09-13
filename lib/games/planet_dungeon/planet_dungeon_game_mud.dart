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

  /// The Lost Maxim's seed: planted, watered, and then let go.
  bool seedPlanted = false;
  bool seedWatered = false;

  /// THE GROUND, BUILT ONCE. A fen floor is pools, hummocks, bog-oak and
  /// cotton-grass, none of it on a grid and none of it changing — so it is
  /// laid out once per room and kept, rather than re-deriving sixty times a
  /// second. Only the sheen on the water moves, and that is a phase.
  final Map<String, FenGround> ground = {};
}

/// One room's worth of fen floor: the standing shapes, in world coordinates.
class FenGround {
  final List<Path> pools = [];
  final List<Offset> poolCentres = [];
  final List<Path> hummocks = [];
  final List<Path> mossCaps = [];
  final List<Offset> bogOak = [];
  final List<double> bogOakLean = [];
  final List<Offset> cotton = [];
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
      ..seedPlanted = false
      ..seedWatered = false;
  }

  // ── Per-frame update ─────────────────────────────────────

  void _updateBog(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isBog) return;
    bog.clock += dt;
    if (bog.smear > 0) bog.smear = max(0.0, bog.smear - dt);
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
        _trySinkPit(a) ||
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

  /// THE LOST MAXIM (§6 easter eggs #9). Plant a seed in the deepest sink-pit,
  /// water it, and let it go all the way down. No hint anywhere teaches this.
  bool _trySinkPit(DungeonCreature a) {
    final pit = currentRoom.fen?.sinkPit;
    if (pit == null) return false;
    if ((a.position - pit).distance > _kFenReach) return false;
    if (discoveredClouds.contains(kMudNoLotusEggId)) return false;
    final e = a.member.element;
    if (!bog.seedPlanted) {
      if (e != 'Plant') return false;
      bog.seedPlanted = true;
      _setHint('A seed goes into the black, and the black takes it');
      _spawnAlchemyBurst(
        pit,
        producedElement: 'Plant',
        particleCount: 16,
        intensity: 0.8,
      );
      return true;
    }
    if (!bog.seedWatered) {
      if (e != 'Water') return false;
      bog.seedWatered = true;
      _setHint('The pit swallows the water and asks for more');
      _spawnAlchemyBurst(
        pit,
        producedElement: 'Water',
        particleCount: 16,
        intensity: 0.8,
      );
      return true;
    }
    if (e != 'Mud') return false;
    // THE RITE OF THREE pays this out (see `beginMaximRite`).
    beginMaximRite(kMudNoLotusEggId, pit);
    _spawnAlchemyBurst(
      pit,
      producedElement: 'Plant',
      reagentElements: const ['Mud', 'Water'],
      particleCount: 40,
      intensity: 1.4,
    );
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
    if (altar != null && !hasStar(altar.moorStarIndex)) {
      return DungeonProgressReadout(
        label: 'BASINS',
        value: '${f.moorsWoken.length}/${kMoorKnollIds.length}',
        fraction: f.moorsWoken.length / kMoorKnollIds.length,
      );
    }
    final sod = f.hardened.length;
    return DungeonProgressReadout(
      label: 'ROADS',
      value: '$sod of ${kBogFords.length}',
      fraction: sod / kBogFords.length,
    );
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
    final altar = room.fen?.altar;
    if (altar != null && !hasStar(altar.sarsenStarIndex)) {
      return 'The Sinking Altar, its socket stands empty';
    }
    if (room.fen?.moor != null) {
      final done = f.moorsWoken.contains(room.id);
      return done ? null : 'A moor-altar, its basin will not keep anything';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Mire Gate, the fen opens out, and the sarsen lies here'
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
    }
  }

  /// INSIGHT is the only channel allowed to teach method (§5.6), tiered by
  /// Intelligence.
  void _bogReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
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
  static const Color _fenSod = Color(0xFF7E8C4B);
  static const Color _fenWater = Color(0xFF0D1A1E);
  static const Color _fenSheen = Color(0xFF9FB6A6);
  static const Color _fenBrass = Color(0xFFE4C16A);

  void _renderBog(Canvas canvas, DungeonRoom room) {
    _renderFordHeads(canvas, room);
    _renderKnollFurniture(canvas, room);
    _renderSmear(canvas, room);
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
      bog.ground.putIfAbsent(room.id, () => _buildBogGround(room));

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

  /// The fen floor, under everything else in the room.
  void _renderBogFloor(Canvas canvas, DungeonRoom room) {
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

    // Standing water, and a single slow sheen crossing each pool.
    for (var i = 0; i < g.pools.length; i++) {
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
    }
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

    switch (state) {
      case BogFordState.mire:
        // QUAKING. A wide soft slurry, a paler skin on it, and ripples
        // travelling out along the crossing: it moves, so it is not to be
        // trusted with anything heavy.
        canvas.drawPath(
          ribbon(30),
          Paint()..color = _fenSlurry.withValues(alpha: 0.42),
        );
        canvas.drawPath(
          ribbon(22),
          Paint()..color = _fenSlurry.withValues(alpha: 0.55),
        );
        for (var i = 0; i < 4; i++) {
          final t = ((bog.clock * 0.28 + i / 4) % 1.0);
          final p = at(t);
          final w = 15.0 * (1 - (t - 0.5).abs());
          canvas.drawLine(
            p + norm * w,
            p - norm * w,
            Paint()
              ..strokeWidth = 2.4
              ..color = _fenSheen.withValues(alpha: 0.13),
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
      // The wallow: a soft dark eye that breathes.
      final r = 26 + sin(bog.clock * 1.1) * 2.5;
      canvas.drawCircle(
        knoll.wallow,
        r,
        Paint()..color = _fenWater.withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        knoll.wallow,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _fenSlurry.withValues(alpha: 0.7),
      );
      // The sarsen, wherever it currently stands.
      if (f.sarsenKnoll == room.id && !f.sarsenSeated) {
        _renderSarsen(canvas, Offset(room.bounds.center.dx, 140));
      }
      if (f.isDry(room.id)) {
        // A drained knoll reads as drained: a dry hairline round its heart.
        canvas.drawCircle(
          room.bounds.center,
          150,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = _fenSod.withValues(alpha: 0.35),
        );
      }
    }

    final moor = fen.moor;
    if (moor != null) {
      final woken = f.moorsWoken.contains(room.id);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: moor.basin, width: 74, height: 26),
          const Radius.circular(12),
        ),
        Paint()
          ..color = (woken ? _fenSheen : _fenPeat).withValues(
            alpha: woken ? 0.6 : 0.9,
          ),
      );
      // The standing stone above it.
      canvas.drawPath(
        Path()
          ..moveTo(moor.basin.dx - 16, moor.basin.dy - 12)
          ..lineTo(moor.basin.dx - 10, moor.basin.dy - 92)
          ..lineTo(moor.basin.dx + 12, moor.basin.dy - 86)
          ..lineTo(moor.basin.dx + 17, moor.basin.dy - 12)
          ..close(),
        Paint()..color = const Color(0xFF4A4740),
      );
      if (woken) {
        canvas.drawCircle(
          moor.basin,
          9 + sin(bog.clock * 2) * 1.6,
          Paint()..color = _fenBrass.withValues(alpha: 0.7),
        );
      }
    }

    final altar = fen.altar;
    if (altar != null) {
      canvas.drawCircle(
        altar.socket,
        34,
        Paint()
          ..color = (f.socketOpen ? _fenWater : const Color(0xFF3A3128))
              .withValues(alpha: 0.92),
      );
      if (f.sarsenSeated) _renderSarsen(canvas, altar.socket);
    }

    final sough = fen.sough;
    if (sough != null) {
      canvas.drawCircle(
        sough,
        30,
        Paint()..color = _fenWater.withValues(alpha: 0.9),
      );
      if (f.soughFreed) {
        // A pulled plug reads as a pull: three curves running inward.
        for (var i = 0; i < 3; i++) {
          final a0 = bog.clock * 1.4 + i * 2.09;
          canvas.drawLine(
            sough + Offset(cos(a0) * 62, sin(a0) * 62),
            sough + Offset(cos(a0) * 30, sin(a0) * 30),
            Paint()
              ..color = _fenSheen.withValues(alpha: 0.4)
              ..strokeWidth = 2.4,
          );
        }
      }
    }

    final pit = fen.sinkPit;
    if (pit != null) {
      canvas.drawCircle(
        pit,
        22,
        Paint()..color = Colors.black.withValues(alpha: 0.85),
      );
      if (discoveredClouds.contains(kMudNoLotusEggId)) {
        canvas.drawCircle(pit, 13, Paint()..color = const Color(0xFFF2D7E6));
      }
    }

    final anchor = fen.anchor;
    if (anchor != null) {
      canvas.drawCircle(
        anchor,
        30,
        Paint()
          ..color = (f.anchorFirm ? _fenSod : _fenSlurry).withValues(
            alpha: f.anchorFirm ? 0.85 : 0.45,
          ),
      );
    }
  }

  void _renderSarsen(Canvas canvas, Offset at) {
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - 22, at.dy + 14)
        ..lineTo(at.dx - 15, at.dy - 62)
        ..lineTo(at.dx + 14, at.dy - 56)
        ..lineTo(at.dx + 22, at.dy + 14)
        ..close(),
      Paint()..color = const Color(0xFF5B5750),
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
