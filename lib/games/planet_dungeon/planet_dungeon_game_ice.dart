// lib/games/planet_dungeon/planet_dungeon_game_ice.dart
//
// GLACIUS — the Frozen Observatory. Ice's puzzle logic + rendering, as a
// `part of planet_dungeon_game.dart` (the same treatment every planet after
// the Air pilot gets). The layout, the shaft graph and the puzzle DATA live
// in planet_dungeon_layout_ice.dart; this file is the rules.
//
// World rule: *the shaft only goes down; the way back up is whatever you
// froze on the way.* See the layout file's header for the full statement of
// the flue trade (drift / stair / scoured) and the vault trick.
//
//  • Entry — the mouth is glazed shut with old black ice. LIGHT melts the cap
//    and the floor's three holes open (docs §5.5: the eased entry reveal).
//  • Star 0 (Orrery) — THE STANDING ORRERY, on L2. Star-blocks are too heavy
//    to move on bare stone; ICE glazes a cell to glass and a block shoved
//    onto glass GLIDES until the glass runs out. LIGHT melts a glaze back.
//    You never push the block where it should go — you lay the road and let
//    it run. Glass is slick underfoot too, so the road you lay takes away the
//    footing you need to shove from. ELEMENT-ONLY, all three elements used:
//    this is the star §4 guarantees to any trio of the right elements.
//  • Star 1 (Mirror) — THE TWELVE MIRRORS, on L1. ICE silvers a frame and the
//    ceiling's chart shows in it; a silvered frame THAWS and clouds over
//    again (§6: "solve before mirrors thaw"). The star wants all twelve
//    showing AT ONCE, so it is a lap against your own melt. AIR's sweep from
//    the cold vent renews every silvered frame at a cooldown. The LODESTONE
//    takes no frost: Light+MASK strikes into it (the planet's marquee gate)
//    and it never thaws again.
//  • Rite (Star Font) — conduit A is Air+WING (the second gate), conduit B is
//    the cold font, element-only Ice.
//  • Star 2 (Frost) — MYS09 FROWYRM. §7: the guardian fights WITH the
//    planet's rule. Its lull only opens while the hollow's hoarfrost pillar
//    stands, and every strike beat shatters the pillar AND SCOURS ONE OF YOUR
//    STAIRS in the shaft above — it eats your way home while you fight it.
//  • Lost Maxim — STAR-WALKER: the thirteenth telescope, on flue B's shelf.
//
// NON-STRANDABILITY (the design's one real danger — see `solveShaftDescent`):
// one-way descent plus an unrepeatable slide is a stranding machine. The
// RIMEFALL is the valve: Ice freezes it from the sump at any time, it climbs
// to the mouth, and stepping off the top THAWS THE WHOLE SHAFT back to its
// opening state. Costly (every stair you built is gone), always available,
// and it is what `solveShaftDescent().strandable == 0` rests on.

part of 'planet_dungeon_game.dart';

/// Ice's lost maxim discovery id (the screen pays 20 gold on first find).
const String kIceStarWalkerEggId = 'egg:ice_star_walker';

// ── Device-tunable knobs ───────────────────────────────────
// Ice has never been on a device; every number the feel depends on is named
// here so a tuning pass is edit-one-block.

/// How close a creature must stand to a flue mouth, the cap, the rimefall,
/// the font or the hoarfrost pillar to act on it.
const double _kShaftReach = 66.0;

/// Seconds a silvered mirror holds before it clouds over. Authored against
/// the ring: 11 frames at ~113px apart is ~8.3s of walking at 150px/s, so a
/// clean lap fits with margin and a wandering one does not.
const double _kMirrorHoldSeconds = 13.0;

/// Seconds an Air sweep takes to re-arm. Long enough that the sweep is a
/// decision, short enough that it is never the reason you failed.
const double _kMirrorSweepCooldown = 9.0;

/// How close a creature must stand to a mirror frame to work it.
const double _kMirrorReach = 60.0;

/// px/sec a body is carried while it stands on glazed floor. Slick, not
/// violent: you can fight it, you just cannot stop on it.
const double _kGlideDrift = 96.0;

/// Rime wisps a botched glide breathes out (the orrery's one consequence).
const int _kOrreryWisps = 1;

/// Seconds Frowyrm's shattered pillar stays down before it can be re-frozen.
/// Zero: the pillar is re-frozen by hand, and the fight's tempo IS that
/// errand. Kept named so a device pass can add a beat if it plays too busy.
const double _kHoarfrostRegrow = 0.0;

extension FrozenObservatory on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetShaftState() {
    if (!_isShaft) return;
    // A death re-freezes nothing and un-scours nothing by itself — the shaft
    // is puzzle state like every other planet's, so it resets with the run.
    flueState.clear();
    for (final f in kRimeFlues) {
      flueState[f.id] = RimeFlueState.drift;
    }
    rimefallFrozen = false;
    shaftThaws = 0;
    silveredMirrors.clear();
    mirrorThaw.clear();
    lodestoneLit = false;
    mirrorSweep = 0;
    orreryGlass.clear();
    orreryBlocks.clear();
    orrerySeated.clear();
    _seedOrrery();
    hoarfrostWhole = false;
    _hoarfrostDown = 0;
  }

  /// The shaft, back to the state it opened in. Called by THE THAW when the
  /// rimefall carries you out at the top — and only there.
  void _thawShaft() {
    for (final f in kRimeFlues) {
      flueState[f.id] = RimeFlueState.drift;
    }
    rimefallFrozen = false;
    shaftThaws++;
  }

  // ── The flue graph ───────────────────────────────────────

  RimeFlueState _flue(String id) => flueState[id] ?? RimeFlueState.drift;

  /// The flue this door travels, and whether the door is the DOWN leg, the
  /// SHELF leg, or the UP leg. Null when the door is not part of the shaft
  /// (the shelves' scramble-out, the rite doors).
  (RimeFlue, String)? _flueLeg(DungeonRoom room, DungeonDoor door) {
    for (final f in kRimeFlues) {
      if (f.headRoom == room.id && f.footRoom == door.targetRoomId) {
        return (f, 'down');
      }
      if (f.headRoom == room.id && f.shelfRoom == door.targetRoomId) {
        return (f, 'shelf');
      }
      if (f.footRoom == room.id && f.headRoom == door.targetRoomId) {
        return (f, 'up');
      }
    }
    return null;
  }

  /// A flue mouth is ONE hole in the floor, but the engine sees two doors
  /// (the shelf landing and the long drop). Exactly one is ever live, so the
  /// lip reads as a single hole that behaves differently depending on its
  /// snow. The whole head floor also stays shut until Light melts the cap.
  bool _iceDoorHidden(DungeonRoom room, DungeonDoor door) {
    if (!_isShaft) return false;
    if (room.id == layout.entranceRoomId && !entryDoorRevealed) {
      // The mouth is glazed over: every hole in this floor is invisible.
      return _flueLeg(room, door) != null;
    }
    final leg = _flueLeg(room, door);
    if (leg == null) return false;
    final (flue, which) = leg;
    final state = _flue(flue.id);
    if (which == 'shelf') return state != RimeFlueState.drift;
    if (which == 'down') {
      // While the drift still stands, the fall is braked onto the shelf —
      // the long drop does not exist yet.
      return flue.shelfRoom != null && state == RimeFlueState.drift;
    }
    return false;
  }

  /// The UP leg of a flue is the whole planet: it exists only if you made it.
  bool _iceDoorBlocked(DungeonRoom room, DungeonDoor door) {
    if (!_isShaft) return false;
    final leg = _flueLeg(room, door);
    if (leg == null) return false;
    final (flue, which) = leg;
    if (which != 'up') return false;
    if (flue.isThroat) return !rimefallFrozen;
    return _flue(flue.id) != RimeFlueState.stair;
  }

  /// One short clause naming exactly what is missing (§5.6 BLOCKED) — never a
  /// method. How a flue is frozen is the shaft's earned reading (Mask).
  String _iceDoorHint(DungeonRoom room, DungeonDoor door) {
    final (flue, _) = _flueLeg(room, door)!;
    if (flue.isThroat) {
      return 'The melt-fall runs, nothing climbs running water';
    }
    return switch (_flue(flue.id)) {
      RimeFlueState.scoured => 'Bare glass, and no snow left to take frost',
      _ => 'Loose snow, it will not hold a step',
    };
  }

  /// Bookkeeping the moment a shaft door is used: the ride SCOURS the flue,
  /// and the rimefall THAWS the shaft behind you.
  void _onShaftTransit(DungeonRoom from, DungeonDoor door) {
    if (!_isShaft) return;
    final leg = _flueLeg(from, door);
    if (leg == null) return;
    final (flue, which) = leg;
    if (which == 'up') {
      if (flue.isThroat) {
        // THE THAW — the price of the only ladder that is always there.
        _thawShaft();
        _setHint(
          'The rimefall carries you out, and behind you the whole shaft '
          'lets go: every stair you cut is water again',
          4.6,
        );
      }
      return;
    }
    // A ride. The first one cuts the snow away for good.
    if (_flue(flue.id) == RimeFlueState.drift) {
      flueState[flue.id] = RimeFlueState.scoured;
      if (which == 'shelf') {
        _setHint('The drift brakes you onto a ledge, and goes with you', 3.4);
      }
    }
  }

  /// Test seam for the transit bookkeeping — the shaft's rules are proved
  /// against the same code the door loop calls, without having to walk a body
  /// onto a 24px door rect.
  void onShaftTransitForTest(DungeonRoom from, DungeonDoor door) =>
      _onShaftTransit(from, door);

  // ── Verbs ────────────────────────────────────────────────

  /// Every Ice verb, in priority order. Returns true when one was consumed.
  bool _tryShaftVerb(DungeonCreature a) {
    if (!_isShaft) return false;
    return _tryIceCap(a) ||
        _tryRimefall(a) ||
        _tryFreezeFlue(a) ||
        _tryHoarfrost(a) ||
        _tryColdFont(a) ||
        _tryMirrorFrame(a) ||
        _tryMirrorSweep(a) ||
        _tryTelescope(a) ||
        _tryOrrery(a);
  }

  /// The entry rite: Light melts the cap of old black ice over the mouth.
  bool _tryIceCap(DungeonCreature a) {
    final cap = currentRoom.rime?.iceCap;
    if (cap == null || entryDoorRevealed) return false;
    if ((a.position - cap).distance > _kShaftReach) return false;
    if (a.member.element != 'Light') {
      _setBlockedHint('Only Light thaws this cap');
      return true;
    }
    entryDoorRevealed = true;
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist it
    _setHint('Light drinks the black ice, the floor opens its mouths');
    _spawnAlchemyBurst(
      cap,
      producedElement: 'Water',
      reagentElements: const ['Light', 'Ice'],
      particleCount: 30,
      intensity: 1.25,
    );
    return true;
  }

  /// Freeze a flue at its head: the drift becomes a stair, for the run.
  bool _tryFreezeFlue(DungeonCreature a) {
    for (final f in kRimeFlues) {
      if (f.headRoom != currentRoomId) continue;
      if ((a.position - f.headPos).distance > _kShaftReach) continue;
      if (!f.freezable) {
        _setBlockedHint('The throat runs too hard to take frost from above');
        return true;
      }
      if (a.member.element != 'Ice') {
        _setBlockedHint('Only Ice sets this fall into a stair');
        return true;
      }
      switch (_flue(f.id)) {
        case RimeFlueState.stair:
          _setBlockedHint('This fall already stands');
        case RimeFlueState.scoured:
          _setBlockedHint('Bare glass. Frost finds nothing to hold');
        case RimeFlueState.drift:
          flueState[f.id] = RimeFlueState.stair;
          _setHint('The fall sets, a stair, and the shelf under it is shut');
          _spawnAlchemyBurst(
            f.headPos,
            producedElement: 'Ice',
            reagentElements: [a.member.element],
            particleCount: 24,
          );
      }
      return true;
    }
    return false;
  }

  /// The sump's melt-fall. Freezing it is always possible — it is the reason
  /// no descent can ever be a dead run (see `solveShaftDescent`).
  bool _tryRimefall(DungeonCreature a) {
    final pos = currentRoom.rime?.rimefall;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kShaftReach) return false;
    if (a.member.element != 'Ice') {
      _setBlockedHint('Only Ice will hold this fall');
      return true;
    }
    if (rimefallFrozen) {
      _setBlockedHint('The rimefall already stands');
      return true;
    }
    rimefallFrozen = true;
    _setHint('The rimefall locks, one long stair, all the way to the mouth');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Ice',
      reagentElements: [a.member.element],
      particleCount: 30,
      intensity: 1.2,
    );
    return true;
  }

  /// The rite's second half — element-only Ice, so a party missing the Wing
  /// still meets exactly ONE refusal at the font rather than two.
  bool _tryColdFont(DungeonCreature a) {
    final pos = currentRoom.rime?.coldFont;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kShaftReach) return false;
    if ((conduitEnergy['B'] ?? 0) > 0) return false;
    if (a.member.element != 'Ice') {
      _setBlockedHint('The font answers Ice alone');
      return true;
    }
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'The font refuses the offering, it answers only a bearer of the '
        '${layout.starName(0)} and ${layout.starName(1)}',
      );
      return true;
    }
    conduitEnergy['B'] = double.infinity;
    _setHint('The cold font takes the frost and holds it');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Ice',
      reagentElements: [a.member.element],
    );
    return true;
  }

  /// Frowyrm's hoarfrost pillar — the fight's verb.
  bool _tryHoarfrost(DungeonCreature a) {
    final pos = currentRoom.rime?.hoarfrost;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kShaftReach) return false;
    if (hoarfrostWhole) return false;
    if (_hoarfrostDown > 0) {
      _setBlockedHint('The stump is still shivering');
      return true;
    }
    if (a.member.element != 'Ice') {
      _setBlockedHint('Only Ice raises this pillar');
      return true;
    }
    hoarfrostWhole = true;
    _setHint('The hoarfrost stands again, and the wyrm slows to look at it');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Ice',
      reagentElements: [a.member.element],
      particleCount: 22,
    );
    return true;
  }

  // ── Star 1 · THE TWELVE MIRRORS ──────────────────────────

  MirrorRing? get _mirrorRing => currentRoom.rime?.mirrors;

  /// Frames that are showing the chart right now.
  int get mirrorsShowing => silveredMirrors.length + (lodestoneLit ? 1 : 0);

  bool _tryMirrorFrame(DungeonCreature a) {
    final ring = _mirrorRing;
    if (ring == null || hasStar(currentRoom.rime!.starIndex!)) return false;
    for (var i = 0; i < ring.count; i++) {
      if ((a.position - ring.frameAt(i)).distance > _kMirrorReach) continue;
      if (i == ring.lodestoneIndex) {
        if (lodestoneLit) return false;
        final req = const DungeonInteractionRequirement(
          element: 'Light',
          requiredFamily: DungeonAbility.insight,
        );
        switch (evaluateInteraction(a.member, req)) {
          case InteractionResult.passed:
          case InteractionResult.passedViaRecipe:
            lodestoneLit = true;
            _setHint('The lodestone takes a light of its own, and keeps it');
            _spawnAlchemyBurst(
              ring.frameAt(i),
              producedElement: 'Light',
              reagentElements: const ['Ice'],
              particleCount: 26,
            );
          case InteractionResult.blockedFamily:
            // "The seal remembers" (§4): the chip stamps on first refusal.
            final gate = layout.familyGateFor('mirror_lodestone');
            if (gate != null) {
              _stampFamilyGate(gate);
            } else {
              _setBlockedHint('Only Light\'s second sight strikes this glass');
            }
          case InteractionResult.blockedElement:
          case InteractionResult.blockedStat:
            _setBlockedHint('This glass takes no frost, it answers Light');
        }
        return true;
      }
      if (a.member.element != 'Ice') {
        _setBlockedHint('Only Ice silvers a frame');
        return true;
      }
      silveredMirrors.add(i);
      mirrorThaw[i] = _kMirrorHoldSeconds;
      _spawnAlchemyBurst(
        ring.frameAt(i),
        producedElement: 'Ice',
        reagentElements: [a.member.element],
        particleCount: 12,
      );
      _checkMirrorStar();
      return true;
    }
    return false;
  }

  /// Air's sweep off the cold vent: every silvered frame is renewed at once.
  bool _tryMirrorSweep(DungeonCreature a) {
    final ring = _mirrorRing;
    if (ring == null || hasStar(currentRoom.rime!.starIndex!)) return false;
    if ((a.position - ring.vent).distance > _kShaftReach) return false;
    if (a.member.element != 'Air') {
      _setBlockedHint('Only Air stirs this vent');
      return true;
    }
    if (mirrorSweep > 0) {
      _setBlockedHint('The vent is still drawing breath');
      return true;
    }
    mirrorSweep = _kMirrorSweepCooldown;
    for (final i in silveredMirrors) {
      mirrorThaw[i] = _kMirrorHoldSeconds;
    }
    _setHint('A cold sweep goes round the ring, every glass holds again');
    _spawnAlchemyBurst(
      ring.vent,
      producedElement: 'Air',
      reagentElements: const ['Ice'],
      particleCount: 26,
      intensity: 1.15,
    );
    return true;
  }

  void _checkMirrorStar() {
    final ring = _mirrorRing;
    final idx = currentRoom.rime?.starIndex;
    if (ring == null || idx == null || hasStar(idx)) return;
    if (mirrorsShowing < ring.count) return;
    _setHint('Twelve glasses hold the chart at once, the sky admits it');
    earnStar(idx);
  }

  /// The thaw clock. Frames cloud over one by one; the ring's own resentment
  /// (a rime wisp) only shows up once the gallery is nearly read, so an early
  /// fumble is quiet and a late one costs.
  void _updateMirrors(DungeonRoom room, double dt) {
    if (mirrorSweep > 0) mirrorSweep = max(0.0, mirrorSweep - dt);
    final ring = room.rime?.mirrors;
    final idx = room.rime?.starIndex;
    if (ring == null || idx == null || hasStar(idx)) return;
    if (silveredMirrors.isEmpty) return;
    final lost = <int>[];
    for (final i in silveredMirrors) {
      final left = (mirrorThaw[i] ?? 0) - dt;
      mirrorThaw[i] = left;
      if (left <= 0) lost.add(i);
    }
    if (lost.isEmpty) return;
    final wasNearly = mirrorsShowing >= ring.count - 3;
    for (final i in lost) {
      silveredMirrors.remove(i);
      mirrorThaw.remove(i);
    }
    if (wasNearly) {
      spawnWispWave(
        element: 'Ice',
        center: ring.frameAt(lost.first),
        count: 1,
        unstable: true,
        announce: false,
      );
      _setHint('A glass clouds over, the ring will not be half-read', 2.6);
    }
  }

  // ── Star 0 · THE STANDING ORRERY ─────────────────────────

  OrreryGrid? get _orrery => currentRoom.rime?.orrery;

  /// The orrery room, wherever it is (the solver reads it without walking).
  DungeonRoom? get _orreryRoom {
    for (final r in layout.rooms.values) {
      if (r.rime?.orrery != null) return r;
    }
    return null;
  }

  void _seedOrrery() {
    final g = _orreryRoom?.rime?.orrery;
    if (g == null) return;
    var id = 0;
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (g.art[r][c] == 'B') orreryBlocks[id++] = r * g.cols + c;
      }
    }
  }

  bool _orreryPillar(OrreryGrid g, int c, int r) => g.art[r][c] == '#';
  bool _orrerySocket(OrreryGrid g, int c, int r) => g.art[r][c] == 'S';
  bool _orreryGlazed(OrreryGrid g, int c, int r) =>
      orreryGlass.contains(r * g.cols + c);

  int? _orreryBlockAt(OrreryGrid g, int c, int r) {
    final idx = r * g.cols + c;
    for (final e in orreryBlocks.entries) {
      if (e.value == idx) return e.key;
    }
    return null;
  }

  (int, int)? _orreryCellAt(OrreryGrid g, Offset p) {
    final c = ((p.dx - g.origin.dx) / g.cell).floor();
    final r = ((p.dy - g.origin.dy) / g.cell).floor();
    if (c < 0 || r < 0 || c >= g.cols || r >= g.rows) return null;
    return (c, r);
  }

  /// The quarter a creature is facing, as a grid step. The orrery's verbs all
  /// act on the cell IN FRONT of you (Steam's `_targetCell` convention): one
  /// unambiguous target means glazing never eats a shove you meant, and it
  /// keeps you off the ice you just laid.
  (int, int) _orreryFacing(DungeonCreature a) {
    final dx = cos(a.aimAngle);
    final dy = sin(a.aimAngle);
    return dx.abs() >= dy.abs()
        ? (dx >= 0 ? (1, 0) : (-1, 0))
        : (dy >= 0 ? (0, 1) : (0, -1));
  }

  bool _tryOrrery(DungeonCreature a) {
    final g = _orrery;
    final idx = currentRoom.rime?.starIndex;
    if (g == null || idx == null || hasStar(idx)) return false;
    final here = _orreryCellAt(g, a.position);
    if (here == null) return false;
    final step = _orreryFacing(a);
    var c = here.$1 + step.$1;
    var r = here.$2 + step.$2;
    // Facing off the edge of the floor: fall back to the cell underfoot, so a
    // creature pinned against the wall is never verbless.
    if (c < 0 || r < 0 || c >= g.cols || r >= g.rows) {
      c = here.$1;
      r = here.$2;
    }
    final block = _orreryBlockAt(g, c, r);
    if (block != null && !orrerySeated.contains(block)) {
      return _shoveBlock(g, block, step);
    }
    if (_orreryPillar(g, c, r) || _orrerySocket(g, c, r)) {
      _setBlockedHint(
        _orreryPillar(g, c, r)
            ? 'Old iron \u2014 nothing takes here'
            : 'A socket\'s kerb, cut too deep for frost',
      );
      return true;
    }
    final key = r * g.cols + c;
    if (a.member.element == 'Ice') {
      if (orreryGlass.contains(key)) {
        _setBlockedHint('Already glass');
        return true;
      }
      orreryGlass.add(key);
      _spawnAlchemyBurst(
        g.centerAt(c, r),
        producedElement: 'Ice',
        reagentElements: [a.member.element],
        particleCount: 10,
      );
      return true;
    }
    if (a.member.element == 'Light') {
      if (!orreryGlass.remove(key)) {
        _setBlockedHint('Bare stone \u2014 there is nothing here to melt');
        return true;
      }
      _spawnAlchemyBurst(
        g.centerAt(c, r),
        producedElement: 'Water',
        reagentElements: const ['Light', 'Ice'],
        particleCount: 10,
      );
      return true;
    }
    return false;
  }

  /// Send block [id] running in grid direction [dir]. The whole puzzle is in
  /// this loop: a star-block is frozen sky, so it only crosses GLASS, and it
  /// keeps going until the glass runs out. A socket's kerb catches it whether
  /// the socket is glazed or not.
  bool _shoveBlock(OrreryGrid g, int id, (int, int) dir) {
    final cell = orreryBlocks[id]!;
    var c = cell % g.cols;
    var r = cell ~/ g.cols;
    final travelled = <int>[];
    var moved = false;
    var seated = false;
    while (true) {
      final nc = c + dir.$1;
      final nr = r + dir.$2;
      if (nc < 0 || nr < 0 || nc >= g.cols || nr >= g.rows) break;
      if (_orreryPillar(g, nc, nr)) break;
      if (_orreryBlockAt(g, nc, nr) != null) break;
      // A socket's kerb catches whatever slides into it, glazed or not.
      if (_orrerySocket(g, nc, nr)) {
        c = nc;
        r = nr;
        moved = true;
        seated = true;
        break;
      }
      // Bare stone is the end of the road: a star-block is frozen sky and
      // will not be pushed across it.
      if (!_orreryGlazed(g, nc, nr)) break;
      c = nc;
      r = nr;
      moved = true;
      travelled.add(nr * g.cols + nc);
    }
    if (!moved) {
      _setBlockedHint('Too heavy for bare stone');
      return true;
    }
    orreryBlocks[id] = r * g.cols + c;
    if (seated) {
      orrerySeated.add(id);
      _setHint('The block takes the kerb and settles into its socket');
      _spawnAlchemyBurst(
        g.centerAt(c, r),
        producedElement: 'Light',
        reagentElements: const ['Ice'],
        particleCount: 20,
      );
      if (orrerySeated.length >= orreryBlocks.length) {
        _setHint(
          'Every socket is filled \u2014 the orrery stands still and true',
        );
        earnStar(currentRoom.rime!.starIndex!);
      }
      return true;
    }
    // THE CONSEQUENCE (\u00a77, one per star): a run that ends anywhere but a
    // socket cracks the road it just used \u2014 you get the block back, never
    // the ice.
    for (final k in travelled) {
      orreryGlass.remove(k);
    }
    if (travelled.isNotEmpty) {
      spawnWispWave(
        element: 'Ice',
        center: g.centerAt(c, r),
        count: _kOrreryWisps,
        unstable: true,
        announce: false,
      );
      _setHint('It runs out of road \u2014 and the road cracks behind it', 2.8);
    }
    return true;
  }

  /// Glass is slick underfoot: a body standing on a glazed cell is carried
  /// on in whatever direction it was already going. This is what makes the
  /// road you lay a cost as well as a tool.
  void _updateGlideFooting(DungeonCreature a, DungeonRoom room, double dt) {
    final g = room.rime?.orrery;
    if (g == null || flightActive) return;
    final cell = _orreryCellAt(g, a.position);
    if (cell == null) return;
    if (!_orreryGlazed(g, cell.$1, cell.$2)) return;
    final dir = joystickDirection;
    final push = dir.distanceSquared > 0.0001
        ? dir / dir.distance
        : Offset(cos(a.angle), 0);
    a.position = _moveWithCollision(a.position, push * _kGlideDrift * dt, room);
  }

  // ── The Lost Maxim · STAR-WALKER ─────────────────────────

  /// The unmarked thirteenth star. Deliberately beyond what the stars demand
  /// (§ "Easter eggs"): the ring must already have been read whole, the niche
  /// is on a shelf you can only fall onto, and the sighting itself wants the
  /// one hand that lays cold behind it.
  bool _tryTelescope(DungeonCreature a) {
    final pos = currentRoom.rime?.telescope;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kShaftReach) return false;
    if (discoveredClouds.contains(kIceStarWalkerEggId)) return false;
    final ring = _mirrorRingRoom?.rime?.mirrors;
    final ringStar = _mirrorRingRoom?.rime?.starIndex;
    if (ring == null || ringStar == null || !hasStar(ringStar)) {
      _setBlockedHint('The lens shows only frost, nothing is charted yet');
      return true;
    }
    // ELEMENT-ONLY. This wanted an Ice MANE, and nothing anywhere said so:
    // the shaft declares two gates (the lodestone and the rite) and the
    // entrance verse names neither a Mane nor a reason to bring one. A run
    // must never need a creature the riddle did not ask for — least of all
    // for optional treasure, where the player has no way to find out they
    // were short until the lens refuses them.
    final req = const DungeonInteractionRequirement(element: 'Ice');
    if (!interactionSucceeded(evaluateInteraction(a.member, req))) {
      _setBlockedHint('The mount will not hold, the sighting drifts');
      return true;
    }
    // THE RITE OF THREE pays this out (see `beginMaximRite`).
    beginMaximRite(kIceStarWalkerEggId, pos);
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Light',
      reagentElements: const ['Ice', 'Air'],
      particleCount: 40,
      intensity: 1.4,
    );
    return true;
  }

  DungeonRoom? get _mirrorRingRoom {
    for (final r in layout.rooms.values) {
      if (r.rime?.mirrors != null) return r;
    }
    return null;
  }

  // ── Per-frame ────────────────────────────────────────────

  void _updateShaft(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isShaft) return;
    _updateMirrors(room, dt);
    _updateGlideFooting(a, room, dt);
    if (_hoarfrostDown > 0) _hoarfrostDown = max(0.0, _hoarfrostDown - dt);
    _updateFrowyrm(room, dt);
  }

  /// §7 — the guardian fights WITH the planet's rule. Frowyrm's lull only
  /// opens while the hoarfrost pillar stands; each strike beat shatters the
  /// pillar and SCOURS one stair in the shaft above, so the fight is
  /// literally spending your way home.
  void _updateFrowyrm(DungeonRoom room, double dt) {
    if (room.guardian == null || !guardianAwake) return;
    if (!hoarfrostWhole) {
      guardianVulnerable = false;
      return;
    }
    if (guardianVulnerable && !_frowyrmBitLastFrame) {
      // The window opened: the wyrm answers by taking the pillar back.
      _frowyrmBitLastFrame = true;
      return;
    }
    if (!guardianVulnerable && _frowyrmBitLastFrame) {
      _frowyrmBitLastFrame = false;
      hoarfrostWhole = false;
      _hoarfrostDown = _kHoarfrostRegrow;
      _shatterOneStair();
    }
  }

  /// The roar reaches up the shaft and takes a stair with it. Scoured, not
  /// thawed: what Frowyrm breaks stays broken — the rimefall is the answer.
  void _shatterOneStair() {
    for (final f in kRimeFlues) {
      if (_flue(f.id) != RimeFlueState.stair) continue;
      flueState[f.id] = RimeFlueState.scoured;
      _cue(SoundCue.elementIce);
      _setHint('Frowyrm roars up the shaft, a stair goes out from under it');
      return;
    }
  }

  // ── Readouts, hints, insight (§5.6) ──────────────────────

  /// STATE LEAVES THE CAPSULE (§5.6): the counters live beside the star
  /// tracker, per room, never as prose that fades.
  DungeonProgressReadout? _shaftProgressReadout() {
    final room = layout.rooms[currentRoomId];
    final ring = room?.rime?.mirrors;
    if (ring != null && !hasStar(room!.rime!.starIndex!)) {
      return DungeonProgressReadout(
        label: 'MIRRORS',
        value: '$mirrorsShowing/${ring.count}',
        fraction: mirrorsShowing / ring.count,
      );
    }
    if (room?.rime?.orrery != null && !hasStar(room!.rime!.starIndex!)) {
      final total = orreryBlocks.length;
      return DungeonProgressReadout(
        label: 'SOCKETS',
        value: '${orrerySeated.length}/$total',
        fraction: total == 0 ? 0 : orrerySeated.length / total,
      );
    }
    final stairs = kRimeFlues
        .where((f) => _flue(f.id) == RimeFlueState.stair)
        .length;
    final climbable = kRimeFlues.where((f) => f.freezable).length;
    return DungeonProgressReadout(
      label: 'STAIRS',
      value: '$stairs/$climbable',
      fraction: climbable == 0 ? 0 : stairs / climbable,
    );
  }

  /// WHAT, never HOW (§5.6). Every method here is Mask's to give.
  String? _shaftObjectiveHint(DungeonRoom room) {
    if (room.guardian != null) {
      return 'Frowyrm\'s Hollow, the wyrm keeps the last star';
    }
    if (room.rime?.coldFont != null) return 'The Star Font, the rite waits';
    if (room.rime?.rimefall != null) {
      return 'The Cold Sump, the shaft bottoms out here';
    }
    if (room.rime?.telescope != null) {
      return discoveredClouds.contains(kIceStarWalkerEggId)
          ? null
          : 'A niche off the throat, an old lens, pointed at nothing';
    }
    if (room.vaultCache != null) {
      return 'A glass ledge, something is bottled here';
    }
    final ring = room.rime?.mirrors;
    if (ring != null) {
      if (hasStar(room.rime!.starIndex!)) return null;
      return 'The Mirror Gallery. Twelve frames, and none of them showing';
    }
    if (room.rime?.orrery != null) {
      if (hasStar(room.rime!.starIndex!)) return null;
      return 'The Standing Orrery, its star-blocks sit off their sockets';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Rime Head, the shaft drops away below'
          : 'The Rime Head. Old ice has sealed the floor over';
    }
    return null;
  }

  /// AMBIENT is flavour only (§5.6): no mechanics, no elements, no families.
  void _shaftAmbientHint(DungeonCreature a, DungeonRoom room) {
    for (final f in kRimeFlues) {
      if (f.headRoom != room.id) continue;
      if ((a.position - f.headPos).distance > _kShaftReach) continue;
      _setAmbientHint(switch (_flue(f.id)) {
        RimeFlueState.drift => 'Soft snow, heaped over a long dark',
        RimeFlueState.scoured =>
          'Polished to a shine, and going nowhere but down',
        RimeFlueState.stair => 'Cut steps, holding',
      });
      return;
    }
    final fall = room.rime?.rimefall;
    if (fall != null && (a.position - fall).distance < 90) {
      _setAmbientHint(
        rimefallFrozen
            ? 'The fall stands, white and silent'
            : 'Water comes down here without ever stopping',
      );
    }
  }

  /// INSIGHT is the only channel allowed to teach method (§5.6), and it is
  /// tiered by Intelligence.
  void _shaftReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    if (room.rime?.orrery != null) {
      _setInsightHint(switch (tier) {
        0 => 'The blocks are frozen sky. Stone will not carry them',
        1 =>
          'Glaze a road and a block runs it to the end; a kerbed socket '
              'catches whatever slides in',
        _ =>
          'Lay the run one cell short of the turn: the block stops where '
              'the glass does, and a socket takes it whether it is glazed or '
              'not. Mind your own footing. Glass carries you too',
      });
      return;
    }
    if (room.rime?.mirrors != null) {
      _setInsightHint(switch (tier) {
        0 => 'Frost holds a picture in the glass, but not for long',
        1 =>
          'The ring wants every frame showing at once, and one frame '
              'will never take frost at all',
        _ =>
          'Silver the ring in one lap; the black frame answers a reading '
              'eye, not a cold hand, and once lit it never clouds. A cold '
              'sweep off the vent renews the whole ring',
      });
      return;
    }
    if (room.rime?.telescope != null) {
      _setInsightHint(
        'The lens wants the chart read first, and a steady, '
        'cold-laying hand on the mount',
      );
      return;
    }
    // Anywhere in the shaft, insight reads the SHAFT — which is the planet.
    _setInsightHint(switch (tier) {
      0 => 'What goes down here does not come back the same way',
      1 =>
        'Fresh snow brakes a fall onto a ledge and is gone; frost turns '
            'the same fall into steps you can climb, one or the other',
      _ =>
        'A ridden flue is bare for good and takes no frost. The fall at '
            'the very bottom is the exception: it freezes from below, climbs '
            'to the mouth, and the whole shaft lets go behind you',
    });
  }

  /// Per-room sky mood — the shaft gets darker the deeper you are.
  double get _shaftMoodTarget => switch (currentRoomId) {
    'rime_head' => 0.72,
    'mirror_gallery' => 0.5,
    'shelf_glass' || 'shelf_lens' => 0.4,
    'orrery_floor' => 0.36,
    'cold_sump' => 0.24,
    'star_font' => 0.2,
    _ => guardianAwake ? 0.12 : 0.18,
  };

  // ── THE NO-STRAND PROOF ──────────────────────────────────

  /// Exhaustive reachability over the shaft's whole state graph.
  ///
  /// A state is (which room you stand in) × (every flue's drift/stair/scoured
  /// state) × (whether the rimefall is frozen). Every legal move is expanded:
  /// riding a flue (which scours a drift), walking a stair either way,
  /// freezing a drift at its head, plunging the throat, freezing the rimefall
  /// from the sump, and climbing it (which THAWS the shaft back to its
  /// opening state).
  ///
  /// Three questions, all answered by construction rather than by argument:
  ///
  ///  1. `strandable` — states from which some room is no longer reachable.
  ///     **It must be zero.** "Reachable" is checked for EVERY room in the
  ///     layout, which is stronger than the brief asks: not just the exit and
  ///     the unearned stars, but the vault shelf and the maxim niche too.
  ///  2. `strandableWithoutRimefall` — the same audit with the sump's valve
  ///     deleted. It is expected to be LARGE: the rimefall is load-bearing,
  ///     not decoration, and if this ever drops to zero someone has quietly
  ///     made the descent two-way and the planet has lost its identity.
  ///  3. `shelfLosable` — states in which a shelf can no longer be entered
  ///     WITHOUT paying a thaw. It must be non-zero, because that loss is the
  ///     vault trick (§5.5: "enterable only from a slide you can't repeat").
  ({
    int states,
    int strandable,
    int strandableWithoutRimefall,
    int shelfLosable,
  })
  solveShaftDescent() {
    final flues = kRimeFlues;
    final rooms = layout.rooms.keys.toList()..sort();
    final head = layout.entranceRoomId;

    // A state is encoded as 'room|f0f1f2f3|R'.
    String enc(String room, List<RimeFlueState> st, bool fall) =>
        '$room|${st.map((s) => s.index).join()}|${fall ? 1 : 0}';

    /// Every move out of one state, as (room, flueStates, rimefallFrozen).
    List<(String, List<RimeFlueState>, bool)> moves(
      String room,
      List<RimeFlueState> st,
      bool fall, {
      required bool rimefallEnabled,
    }) {
      final out = <(String, List<RimeFlueState>, bool)>[];
      for (var i = 0; i < flues.length; i++) {
        final f = flues[i];
        // Down / shelf, from the head.
        if (f.headRoom == room) {
          if (st[i] == RimeFlueState.drift) {
            final next = [...st]..[i] = RimeFlueState.scoured;
            out.add((f.shelfRoom ?? f.footRoom, next, fall));
            if (f.freezable) {
              out.add((room, [...st]..[i] = RimeFlueState.stair, fall));
            }
          } else {
            out.add((f.footRoom, st, fall));
          }
        }
        // Up, from the foot.
        if (f.footRoom == room) {
          if (f.isThroat) {
            if (rimefallEnabled && fall) {
              // THE THAW: the shaft returns to its opening state.
              out.add((
                f.headRoom,
                List.filled(flues.length, RimeFlueState.drift),
                false,
              ));
            }
          } else if (st[i] == RimeFlueState.stair) {
            out.add((f.headRoom, st, fall));
          }
        }
      }
      // Freeze the rimefall (Ice, at the sump — always available).
      if (rimefallEnabled && !fall) {
        for (final f in flues) {
          if (f.isThroat && f.footRoom == room) out.add((room, st, true));
        }
      }
      // Plain doors that are not part of the shaft at all: the shelves'
      // scramble-out and the rite/guardian wing, both two-way in the layout.
      final r = layout.rooms[room]!;
      for (final d in r.doors) {
        var isFlue = false;
        for (final f in flues) {
          if ((f.headRoom == room &&
                  (f.footRoom == d.targetRoomId ||
                      f.shelfRoom == d.targetRoomId)) ||
              (f.footRoom == room && f.headRoom == d.targetRoomId)) {
            isFlue = true;
          }
        }
        if (!isFlue) out.add((d.targetRoomId, st, fall));
      }
      return out;
    }

    /// Which rooms can be reached from one state.
    Set<String> reach(
      String room,
      List<RimeFlueState> st,
      bool fall, {
      required bool rimefallEnabled,
    }) {
      final seen = <String>{enc(room, st, fall)};
      final hit = <String>{room};
      final queue = [(room, st, fall)];
      while (queue.isNotEmpty) {
        final (rm, s, fl) = queue.removeLast();
        for (final m in moves(rm, s, fl, rimefallEnabled: rimefallEnabled)) {
          final k = enc(m.$1, m.$2, m.$3);
          if (!seen.add(k)) continue;
          hit.add(m.$1);
          queue.add(m);
        }
      }
      return hit;
    }

    // Enumerate every state the player can actually get into from the mouth.
    final start = (head, List.filled(flues.length, RimeFlueState.drift), false);
    final live = <String, (String, List<RimeFlueState>, bool)>{
      enc(start.$1, start.$2, start.$3): start,
    };
    final queue = [start];
    while (queue.isNotEmpty) {
      final (rm, s, fl) = queue.removeLast();
      for (final m in moves(rm, s, fl, rimefallEnabled: true)) {
        final k = enc(m.$1, m.$2, m.$3);
        if (live.containsKey(k)) continue;
        live[k] = m;
        queue.add(m);
      }
    }

    var strandable = 0;
    var without = 0;
    var shelfLosable = 0;
    final shelves = [
      for (final f in flues)
        if (f.shelfRoom != null) f.shelfRoom!,
    ];
    for (final st in live.values) {
      final all = reach(st.$1, st.$2, st.$3, rimefallEnabled: true);
      if (all.length < rooms.length) strandable++;
      final bare = reach(st.$1, st.$2, st.$3, rimefallEnabled: false);
      if (bare.length < rooms.length) without++;
      if (shelves.any((s) => !bare.contains(s))) shelfLosable++;
    }
    return (
      states: live.length,
      strandable: strandable,
      strandableWithoutRimefall: without,
      shelfLosable: shelfLosable,
    );
  }

  // ── Rendering ────────────────────────────────────────────
  //
  // VISUAL GRAMMAR (§5.5): the shaft's language is VERTICAL SURFACES, not
  // streamlines — nothing here may read like Air's wind arcs or Water's
  // horizontal tide lines. A running flue is a pale column with a soft moving
  // sheen down it; a stair is stepped white glass with a hard specular lip; a
  // scoured flue is a flat blue-black slot with one cold highlight. No blur
  // filters anywhere (they are the game's known jank source).

  static const Color _kIceWhite = Color(0xFFDCEEF7);
  static const Color _kIcePale = Color(0xFF9FC8DC);
  static const Color _kIceDeep = Color(0xFF16303F);

  void _renderShaft(Canvas canvas, DungeonRoom room) {
    final ground = _shaftGround(room);
    // Everything the glacier and the observatory are made of is clipped to
    // the same stage the plain floor draws, so a bloom or an icicle can run
    // off the edge of the room without spilling into the sky.
    final floor = RRect.fromRectAndRadius(
      room.bounds.deflate(8),
      const Radius.circular(34),
    );

    canvas.save();
    canvas.clipRRect(floor);
    for (final s in ground.base) {
      canvas.drawPath(s.path, s.paint);
    }
    canvas.restore();

    _renderFlueMouths(canvas, room);
    _renderOrrery(canvas, room);
    _renderMirrorRing(canvas, room);
    _renderShaftObjects(canvas, room);

    canvas.save();
    canvas.clipRRect(floor);
    // The overlay is what hangs IN FRONT of the furniture — the icicle fringe
    // off the lip you fell through, and the cold coming down the shaft.
    for (final s in ground.overlay) {
      canvas.drawPath(s.path, s.paint);
    }
    _renderShaftWeather(canvas, room, ground);
    canvas.restore();
  }

  /// This room's static picture, built once and kept (see `_ShaftGround`).
  _ShaftGround _shaftGround(DungeonRoom room) =>
      _shaftGroundCache.putIfAbsent(room.id, () => _buildShaftGround(room));

  /// The only things in a room that are allowed to cost anything per frame: a
  /// handful of glints where the ice catches the light, and the rime that is
  /// always coming down a shaft cut through a glacier. Both are two-stroke
  /// primitives — no blur, no sprites, no allocation in the loop.
  void _renderShaftWeather(Canvas canvas, DungeonRoom room, _ShaftGround g) {
    final glint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;
    for (var i = 0; i < g.glints.length; i++) {
      final s = sin(_time * 1.15 + g.glintPhase[i]);
      // Most glints are dark most of the time: a floor where every spark is
      // lit at once reads as a string of fairy lights, not as ice.
      if (s <= 0.6) continue;
      final k = (s - 0.6) / 0.4;
      final p = g.glints[i];
      final r = 2.5 + k * 3.5;
      glint.color = Colors.white.withValues(alpha: 0.08 + k * 0.28);
      canvas.drawLine(p - Offset(r, 0), p + Offset(r, 0), glint);
      canvas.drawLine(p - Offset(0, r), p + Offset(0, r), glint);
    }

    final b = room.bounds;
    final rime = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.24);
    for (var i = 0; i < g.motes.length; i++) {
      final m = g.motes[i];
      final y = b.top + (m.dy + _time * g.moteSpeed[i]) % b.height;
      final drift = sin(_time * 0.6 + i) * 2.2;
      canvas.drawLine(
        Offset(m.dx + drift, y),
        Offset(m.dx + drift * 0.4, y + 6),
        rime,
      );
    }
  }

  void _renderFlueMouths(Canvas canvas, DungeonRoom room) {
    for (final f in kRimeFlues) {
      if (f.headRoom != room.id) continue;
      // The collar is masonry and is always there; what is IN it is the
      // planet's whole state, so the cap hides the hole and not the kerb.
      if (room.id == layout.entranceRoomId && !entryDoorRevealed) continue;
      final r = Rect.fromCenter(center: f.headPos, width: 118, height: 84);
      final state = f.isThroat && rimefallFrozen
          ? RimeFlueState.stair
          : _flue(f.id);
      // The dark of the drop, under everything: a mouth is a hole first.
      canvas.drawOval(
        r.deflate(2),
        Paint()..color = const Color(0xFF050D14).withValues(alpha: 0.92),
      );
      switch (state) {
        case RimeFlueState.drift:
          // HEAPED SNOW filling the hole to its lip. Drawn as ONE wind-blown
          // silhouette with a scoured lee side, not as a row of circles: four
          // overlapping bright ovals came out as a puff of cotton wool, which
          // is a poor look for the thing that decides whether you ever get
          // back up this shaft.
          final snow = Path()..moveTo(r.left + 4, r.bottom - 6);
          for (var i = 0; i <= 8; i++) {
            final t = i / 8;
            final x = r.left + 4 + (r.width - 8) * t;
            final crest =
                r.top + 30 + sin(t * 5.1 + 1.2) * 8 + (1 - t) * (1 - t) * 12;
            snow.lineTo(x, crest);
          }
          snow
            ..lineTo(r.right - 4, r.bottom - 6)
            ..close();
          canvas.drawPath(
            snow,
            Paint()..color = _kIceWhite.withValues(alpha: 0.5),
          );
          // The crest catches the light; the lee face is in its own shadow.
          final crestLine = Path()..moveTo(r.left + 4, r.bottom - 6);
          for (var i = 0; i <= 8; i++) {
            final t = i / 8;
            crestLine.lineTo(
              r.left + 4 + (r.width - 8) * t,
              r.top + 30 + sin(t * 5.1 + 1.2) * 8 + (1 - t) * (1 - t) * 12,
            );
          }
          canvas.drawPath(
            crestLine,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2
              ..color = Colors.white.withValues(alpha: 0.75),
          );
          canvas.drawPath(
            Path()
              ..moveTo(r.center.dx - 6, r.bottom - 6)
              ..lineTo(r.right - 4, r.top + 38)
              ..lineTo(r.right - 4, r.bottom - 6)
              ..close(),
            Paint()..color = _kIceDeep.withValues(alpha: 0.22),
          );
        case RimeFlueState.scoured:
          // Bare polished ice: the hole is open, and the one thing in it is a
          // single hard highlight running down the far wall of the chute.
          canvas.drawArc(
            r.deflate(6),
            0.5,
            2.2,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = _kIcePale.withValues(alpha: 0.55),
          );
          canvas.drawLine(
            r.center + const Offset(-18, -16),
            r.center + const Offset(10, 24),
            Paint()
              ..color = _kIcePale.withValues(alpha: 0.4)
              ..strokeWidth = 2,
          );
        case RimeFlueState.stair:
          // CUT STEPS seen down a hole: treads narrowing into the dark, each
          // with a hard specular lip. Trapezoids, not rectangles, because the
          // stair is going AWAY from you.
          for (var i = 3; i >= 0; i--) {
            final t = i / 3.0;
            final w = r.width * (0.86 - t * 0.42);
            final y = r.top + 14 + i * 15.0;
            final tread = Path()
              ..moveTo(r.center.dx - w / 2, y)
              ..lineTo(r.center.dx + w / 2, y)
              ..lineTo(r.center.dx + w / 2 - 5, y + 13)
              ..lineTo(r.center.dx - w / 2 + 5, y + 13)
              ..close();
            canvas.drawPath(
              tread,
              Paint()..color = _kIceWhite.withValues(alpha: 0.78 - t * 0.22),
            );
            canvas.drawLine(
              Offset(r.center.dx - w / 2, y),
              Offset(r.center.dx + w / 2, y),
              Paint()
                ..color = Colors.white.withValues(alpha: 0.9 - t * 0.3)
                ..strokeWidth = 1.8,
            );
          }
      }
      // The kerb last, so the collar always sits over whatever fills it.
      canvas.drawOval(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = _kShaftStone.withValues(alpha: 0.85),
      );
      canvas.drawArc(
        r.deflate(3),
        -2.9,
        2.2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _kShaftStoneLit.withValues(alpha: 0.6),
      );
    }
  }

  void _renderOrrery(Canvas canvas, DungeonRoom room) {
    final g = room.rime?.orrery;
    if (g == null) return;

    // GLAZE IS A ROAD, NOT A CHECKERBOARD. Each glazed cell used to be its
    // own rounded rectangle with its own diagonal scratch, so a run of five
    // read as five tiles rather than as one sheet of ice you had laid — which
    // is the entire mechanic. The cells are filled edge to edge into ONE path
    // now, only the outer boundary is drawn, and the specular runs across the
    // whole sheet instead of once per cell.
    final glaze = Path();
    final rim = Path();
    var any = false;
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (!_orreryGlazed(g, c, r)) continue;
        any = true;
        final rect = g.rectAt(c, r);
        glaze.addRect(rect);
        bool ice(int dc, int dr) {
          final nc = c + dc, nr = r + dr;
          if (nc < 0 || nr < 0 || nc >= g.cols || nr >= g.rows) return false;
          return _orreryGlazed(g, nc, nr);
        }

        if (!ice(0, -1)) {
          rim
            ..moveTo(rect.left, rect.top)
            ..lineTo(rect.right, rect.top);
        }
        if (!ice(0, 1)) {
          rim
            ..moveTo(rect.left, rect.bottom)
            ..lineTo(rect.right, rect.bottom);
        }
        if (!ice(-1, 0)) {
          rim
            ..moveTo(rect.left, rect.top)
            ..lineTo(rect.left, rect.bottom);
        }
        if (!ice(1, 0)) {
          rim
            ..moveTo(rect.right, rect.top)
            ..lineTo(rect.right, rect.bottom);
        }
      }
    }
    if (any) {
      canvas.drawPath(
        glaze,
        Paint()..color = _kIcePale.withValues(alpha: 0.30),
      );
      canvas.save();
      canvas.clipPath(glaze);
      final sheen = Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..strokeWidth = 3;
      for (var i = 0; i < 7; i++) {
        final x = g.origin.dx - 260 + i * 150.0;
        canvas.drawLine(
          Offset(x, g.origin.dy - 20),
          Offset(x + 300, g.origin.dy + g.rows * g.cell + 20),
          sheen,
        );
      }
      canvas.restore();
      canvas.drawPath(
        rim,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.42),
      );
    }

    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        final ch = g.art[r][c];
        final p = g.centerAt(c, r);
        if (ch == '#') {
          _drawIronStandard(canvas, p);
        } else if (ch == 'S') {
          _drawOrrerySocket(canvas, p, g.cell);
        }
      }
    }

    for (final e in orreryBlocks.entries) {
      final c = e.value % g.cols;
      final r = e.value ~/ g.cols;
      _drawStarBlock(
        canvas,
        g.centerAt(c, r),
        e.key,
        orrerySeated.contains(e.key),
      );
    }
  }

  /// A pillar of the orrery's armature. It was a grey rounded square: the
  /// heaviest thing on the floor, standing on nothing. It is a bolted iron
  /// standard now — bed plate, column, brass collar — so a glide that dies
  /// against one has visibly hit a machine.
  ///
  /// The first draft tapered the column and put a wide oval cap on it, which
  /// from above read as a TOP HAT. A standard seen from overhead is a column
  /// with a plate under it, and the cap has to be narrower than the base or
  /// the eye reads a brim.
  void _drawIronStandard(Canvas canvas, Offset p) {
    // The bed plate is LIGHTER than the column standing on it. When it was
    // darker the two fused into one silhouette and read as a top hat.
    canvas.drawOval(
      Rect.fromCenter(center: p + const Offset(0, 20), width: 70, height: 28),
      Paint()..color = _kShaftStoneLit.withValues(alpha: 0.55),
    );
    canvas.drawOval(
      Rect.fromCenter(center: p + const Offset(0, 20), width: 70, height: 28),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _kShaftStoneLit.withValues(alpha: 0.8),
    );
    // Four hold-down bolts round the plate — it is fixed to the floor.
    for (var i = 0; i < 4; i++) {
      final a = pi / 4 + i * pi / 2;
      canvas.drawCircle(
        p + Offset(cos(a) * 27, 20 + sin(a) * 10),
        2.6,
        Paint()..color = _kShaftStoneLit.withValues(alpha: 0.7),
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(p.dx - 17, p.dy + 22)
        ..lineTo(p.dx - 15, p.dy - 26)
        ..lineTo(p.dx + 15, p.dy - 26)
        ..lineTo(p.dx + 17, p.dy + 22)
        ..close(),
      Paint()..color = const Color(0xFF2B3A45),
    );
    canvas.drawLine(
      p + const Offset(-11, -22),
      p + const Offset(-12, 18),
      Paint()
        ..color = _kShaftStoneLit.withValues(alpha: 0.55)
        ..strokeWidth = 2.6,
    );
    canvas.drawLine(
      p + const Offset(12, -22),
      p + const Offset(13, 18),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..strokeWidth = 3,
    );
    canvas.drawRect(
      Rect.fromCenter(center: p + const Offset(0, 0), width: 38, height: 8),
      Paint()..color = _kShaftBrassLit.withValues(alpha: 0.8),
    );
    // The end of the post, seen from above — the thing that says "column"
    // rather than "hat".
    canvas.drawOval(
      Rect.fromCenter(center: p + const Offset(0, -26), width: 30, height: 13),
      Paint()..color = const Color(0xFF52646F),
    );
    canvas.drawOval(
      Rect.fromCenter(center: p + const Offset(0, -27), width: 18, height: 7),
      Paint()..color = const Color(0xFF16212B),
    );
  }

  /// A socket was a gold circle. Something is meant to be SEATED in one, so
  /// it is a kerbed cup: a stone rim proud of the floor, three brass seating
  /// lugs, and a dark bed the block drops into.
  void _drawOrrerySocket(Canvas canvas, Offset p, double cell) {
    final r = cell * 0.34;
    canvas.drawCircle(
      p,
      r + 5,
      Paint()..color = _kShaftStone.withValues(alpha: 0.7),
    );
    // A brass kerb, proud of the floor: this is the thing that CATCHES a
    // block, so its lip has to be the brightest edge in the cell.
    canvas.drawCircle(
      p,
      r + 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _kShaftBrassLit.withValues(alpha: 0.75),
    );
    canvas.drawCircle(
      p,
      r,
      Paint()..color = const Color(0xFF12222C).withValues(alpha: 0.9),
    );
    // The bed, and the alignment cross cut into it: a socket is a SEAT, and
    // a flat black disc read as another hole in the floor.
    canvas.drawCircle(
      p,
      r * 0.52,
      Paint()..color = _kShaftStone.withValues(alpha: 0.8),
    );
    final cross = Paint()
      ..color = _kShaftBrassLit.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    canvas.drawLine(p - Offset(r * 0.7, 0), p + Offset(r * 0.7, 0), cross);
    canvas.drawLine(p - Offset(0, r * 0.7), p + Offset(0, r * 0.7), cross);
    final brass = Paint()
      ..color = const Color(0xFFE4C16A).withValues(alpha: 0.85)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final a = -pi / 2 + i * 2 * pi / 3;
      canvas.drawLine(
        p + Offset(cos(a) * (r - 3), sin(a) * (r - 3)),
        p + Offset(cos(a) * (r + 7), sin(a) * (r + 7)),
        brass,
      );
    }
  }

  /// A star-block is a lump of FROZEN SKY, so it must not be a white box: a
  /// faceted chunk with a shadow under it, one lit face, and the star showing
  /// through from inside. Seated, it takes the sockets' brass.
  void _drawStarBlock(Canvas canvas, Offset p, int id, bool seated) {
    // Deterministic per block, so a given block always has the same facets.
    final t = id * 1.7;
    final pts = <Offset>[];
    for (var i = 0; i < 7; i++) {
      final a = -pi / 2 + i * 2 * pi / 7;
      final k = 26.0 + sin(t + i * 2.3) * 4.5;
      pts.add(p + Offset(cos(a) * k, sin(a) * k * 0.98));
    }
    final body = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final q in pts.skip(1)) {
      body.lineTo(q.dx, q.dy);
    }
    body.close();
    canvas.save();
    canvas.translate(0, 6);
    canvas.drawPath(body, Paint()..color = Colors.black.withValues(alpha: 0.3));
    canvas.restore();
    canvas.drawPath(
      body,
      Paint()
        ..color = seated
            ? const Color(0xFFE4C16A).withValues(alpha: 0.85)
            : _kIceWhite.withValues(alpha: 0.86),
    );
    // Two facet seams, so the chunk has volume rather than being a blob.
    canvas.drawPath(
      Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(p.dx - 4, p.dy + 5)
        ..lineTo(pts[4].dx, pts[4].dy)
        ..moveTo(p.dx - 4, p.dy + 5)
        ..lineTo(pts[2].dx, pts[2].dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = (seated ? Colors.white : _kIceDeep).withValues(alpha: 0.4),
    );
    _drawStarGlyph(canvas, p, 11, seated ? Colors.white : _kIceDeep);
  }

  void _renderMirrorRing(Canvas canvas, DungeonRoom room) {
    final ring = room.rime?.mirrors;
    if (ring == null) return;
    final ground = _shaftGround(room);

    // THE POOL. It is a MIRROR, and what it shows is the whole clue layer for
    // the vault: the shelf's glow hangs in the reflected shaft, though the
    // wall itself is blank (§5.5 — "visible only in a mirror"). Wordless.
    //
    // It used to be a flat black disc with one cyan dot floating in it, which
    // gave the glow nothing to hang IN. The reflection is built now — the
    // chart of the ceiling this gallery exists to read, and the two walls of
    // the shaft converging away above — so the dot reads as a light up there
    // rather than as a marker down here.
    final pool = ring.radius - 34;
    canvas.drawCircle(
      ring.center,
      pool,
      Paint()..color = const Color(0xFF060F16).withValues(alpha: 0.86),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: ring.center, radius: pool)));
    for (final s in ground.reflection) {
      canvas.drawPath(s.path, s.paint);
    }
    if (!discoveredClouds.contains(_vaultCacheId)) {
      final bob = sin(_time * 1.2) * 4;
      final glow = ring.center + Offset(ring.radius * 0.52, -46 + bob);
      canvas.drawCircle(
        glow,
        13,
        Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.34),
      );
      canvas.drawCircle(
        glow,
        5,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
    }
    canvas.restore();
    // The water's own surface: one slow shear of light across the black.
    canvas.drawArc(
      Rect.fromCircle(center: ring.center, radius: pool - 12),
      -2.2 + sin(_time * 0.3) * 0.2,
      1.1,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _kIcePale.withValues(alpha: 0.16),
    );

    // THE COLD VENT, in the middle of the pool: an iron rose over the draught
    // that comes up out of the glacier, with frost growing off it onto the
    // water. Air's sweep is cast from here and it used to be nothing at all.
    _drawColdVent(canvas, ring.vent);

    for (var i = 0; i < ring.count; i++) {
      final p = ring.frameAt(i);
      final lode = i == ring.lodestoneIndex;
      final showing = lode ? lodestoneLit : silveredMirrors.contains(i);
      final frame = Rect.fromCenter(center: p, width: 46, height: 66);
      // A stand. A mirror that stands in a gallery stands on something; these
      // were floating outlines.
      canvas.drawPath(
        Path()
          ..moveTo(p.dx - 24, frame.bottom + 16)
          ..lineTo(p.dx - 13, frame.bottom - 2)
          ..lineTo(p.dx + 13, frame.bottom - 2)
          ..lineTo(p.dx + 24, frame.bottom + 16)
          ..close(),
        Paint()..color = _kShaftStone.withValues(alpha: 0.85),
      );
      canvas.drawLine(
        Offset(p.dx - 24, frame.bottom + 16),
        Offset(p.dx + 24, frame.bottom + 16),
        Paint()
          ..color = _kShaftStoneLit.withValues(alpha: 0.55)
          ..strokeWidth = 2.4,
      );
      if (!showing) {
        canvas.drawRect(
          frame.deflate(4),
          Paint()
            ..color = (lode ? Colors.black : _kIceDeep).withValues(alpha: 0.8),
        );
      } else {
        canvas.drawRect(
          frame.deflate(4),
          Paint()
            ..color = (lode ? const Color(0xFFFFF0C4) : _kIceWhite).withValues(
              alpha: 0.8,
            ),
        );
        // The chart, showing: three points and a joining line, so a silvered
        // frame is visibly holding a PICTURE and not just a lit panel.
        final inner = frame.deflate(8);
        final chart = Paint()
          ..color = _kIceDeep.withValues(alpha: 0.55)
          ..strokeWidth = 1.2;
        canvas.drawLine(inner.topLeft + const Offset(3, 12), inner.center, chart);
        canvas.drawLine(
          inner.center,
          inner.bottomRight - const Offset(5, 14),
          chart,
        );
        for (final q in [
          inner.topLeft + const Offset(3, 12),
          inner.center,
          inner.bottomRight - const Offset(5, 14),
        ]) {
          canvas.drawCircle(q, 2.2, Paint()..color = _kIceDeep);
        }
        // The thaw is READ off the frame, not off a line of prose: the silver
        // drains from the bottom as the hold runs out.
        if (!lode) {
          final left = ((mirrorThaw[i] ?? 0) / _kMirrorHoldSeconds).clamp(
            0.0,
            1.0,
          );
          final in2 = frame.deflate(4);
          canvas.drawRect(
            Rect.fromLTWH(
              in2.left,
              in2.bottom - in2.height * (1 - left),
              in2.width,
              in2.height * (1 - left),
            ),
            Paint()..color = _kIceDeep.withValues(alpha: 0.72),
          );
        }
      }
      // The frame itself, over the glass, with a lit inner bead.
      canvas.drawRRect(
        RRect.fromRectAndRadius(frame, const Radius.circular(5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = lode ? const Color(0xFF3A3320) : const Color(0xFF6E5A34),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(frame.deflate(3.5), const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFC9A85C).withValues(alpha: 0.5),
      );
    }
  }

  /// The gallery's cold vent — an iron rose set in the floor with hoar
  /// growing off its spokes.
  void _drawColdVent(Canvas canvas, Offset c) {
    canvas.drawCircle(
      c,
      27,
      Paint()..color = _kShaftStone.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      c,
      21,
      Paint()..color = const Color(0xFF040B10).withValues(alpha: 0.9),
    );
    final bar = Paint()
      ..color = const Color(0xFF46586A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 6;
      canvas.drawLine(
        c + Offset(cos(a) * 20, sin(a) * 20),
        c - Offset(cos(a) * 20, sin(a) * 20),
        bar,
      );
    }
    canvas.drawCircle(
      c,
      27,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = _kShaftStoneLit.withValues(alpha: 0.6),
    );
    // Frost off the grille — a few short spicules, drawn with geometry (never
    // blur). Fourteen long ones made a dandelion in the middle of the pool.
    final frost = Paint()
      ..color = Colors.white.withValues(alpha: 0.26)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final a = i * pi * 2 / 7 + 0.2;
      final l = 6.0 + (i % 3) * 4;
      canvas.drawLine(
        c + Offset(cos(a) * 28, sin(a) * 28),
        c + Offset(cos(a) * (28 + l), sin(a) * (28 + l)),
        frost,
      );
    }
  }

  void _renderShaftObjects(Canvas canvas, DungeonRoom room) {
    final ice = room.rime;
    if (ice == null) return;

    final cap = ice.iceCap;
    if (cap != null && !entryDoorRevealed) {
      // OLD BLACK ICE — a plate that froze in place over the mouth, not a
      // lozenge. Irregular, near-black, crazed white where it has been
      // working against the kerb for a few centuries.
      final plate = Path();
      for (var i = 0; i < 11; i++) {
        final a = i * pi * 2 / 11;
        final k = 1 + sin(i * 2.7) * 0.16;
        final q = cap + Offset(cos(a) * 78 * k, sin(a) * 40 * k);
        i == 0 ? plate.moveTo(q.dx, q.dy) : plate.lineTo(q.dx, q.dy);
      }
      plate.close();
      canvas.drawPath(
        plate,
        Paint()..color = const Color(0xFF060D14).withValues(alpha: 0.94),
      );
      final craze = Path();
      for (var i = 0; i < 5; i++) {
        final a = i * 1.31;
        craze
          ..moveTo(cap.dx, cap.dy)
          ..lineTo(cap.dx + cos(a) * 70, cap.dy + sin(a) * 34)
          ..moveTo(cap.dx + cos(a) * 34, cap.dy + sin(a) * 17)
          ..lineTo(cap.dx + cos(a + 0.9) * 52, cap.dy + sin(a + 0.9) * 26);
      }
      canvas.drawPath(
        craze,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = _kIcePale.withValues(alpha: 0.4),
      );
      canvas.drawPath(
        plate,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _kIcePale.withValues(alpha: 0.3),
      );
    }

    final fall = ice.rimefall;
    if (fall != null) _drawRimefall(canvas, fall);

    final font = ice.coldFont;
    if (font != null) _drawColdFont(canvas, font, (conduitEnergy['B'] ?? 0) > 0);

    final pillar = ice.hoarfrost;
    if (pillar != null) _drawHoarfrost(canvas, pillar, hoarfrostWhole);

    final lens = ice.telescope;
    if (lens != null && !discoveredClouds.contains(kIceStarWalkerEggId)) {
      _drawTelescope(canvas, lens);
    }
  }

  /// THE RIMEFALL — the shaft's one guaranteed ladder, and the object the
  /// no-strand proof rests on. It was a pale rounded rectangle with three
  /// scrolling ticks in it. It is a FALL now: a dark throat cut in the wall,
  /// water or ice coming down it, and a fan of what it has been building at
  /// its foot, so the two states read from across the sump.
  void _drawRimefall(Canvas canvas, Offset fall) {
    final r = Rect.fromCenter(center: fall, width: 116, height: 150);
    // The throat behind it.
    canvas.drawPath(
      Path()
        ..moveTo(r.left - 6, r.top - 30)
        ..lineTo(r.right + 6, r.top - 30)
        ..lineTo(r.right - 4, r.bottom)
        ..lineTo(r.left + 4, r.bottom)
        ..close(),
      Paint()..color = const Color(0xFF07131B).withValues(alpha: 0.85),
    );
    // The chute's own walls, broken away in teeth.
    final teeth = Path();
    for (var i = 0; i < 6; i++) {
      final y = r.top - 26 + i * (r.height + 26) / 6;
      final h = (r.height + 26) / 6;
      teeth
        ..moveTo(r.left - 6, y)
        ..lineTo(r.left + 12 - (i % 2) * 5, y + h * 0.5)
        ..lineTo(r.left - 4, y + h)
        ..moveTo(r.right + 6, y)
        ..lineTo(r.right - 12 + (i % 2) * 5, y + h * 0.5)
        ..lineTo(r.right + 4, y + h);
    }
    canvas.drawPath(teeth, Paint()..color = _kIcePale.withValues(alpha: 0.3));
    if (rimefallFrozen) {
      // Fluted ice: five columns of different width fused together, with a
      // hard lip where each one catches the light.
      for (var i = 0; i < 5; i++) {
        final w = 14.0 + (i % 3) * 7;
        final x = r.left + 10 + i * 21.0;
        final foot = r.bottom - (i % 2) * 12;
        canvas.drawPath(
          Path()
            ..moveTo(x, r.top - 24)
            ..lineTo(x + w, r.top - 24)
            ..lineTo(x + w * 0.72, foot)
            ..lineTo(x + w * 0.18, foot)
            ..close(),
          Paint()..color = _kIceWhite.withValues(alpha: 0.72 - (i % 3) * 0.1),
        );
        canvas.drawLine(
          Offset(x + 2, r.top - 20),
          Offset(x + w * 0.26, foot - 4),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.75)
            ..strokeWidth = 1.6,
        );
      }
      // The fan it froze into at the bottom.
      canvas.drawPath(
        Path()
          ..moveTo(r.left - 24, r.bottom + 26)
          ..lineTo(r.left + 14, r.bottom - 10)
          ..lineTo(r.right - 14, r.bottom - 10)
          ..lineTo(r.right + 26, r.bottom + 26)
          ..close(),
        Paint()..color = _kIceWhite.withValues(alpha: 0.5),
      );
    } else {
      // RUNNING. Water coming down a chute spreads as it falls, so the column
      // widens toward its foot and the streaks in it are not all the same
      // length — a flat pale rectangle with three even ticks in it read as a
      // grey panel, which is a bad look for the one object the whole
      // no-strand proof rests on.
      canvas.drawPath(
        Path()
          ..moveTo(r.left + 22, r.top - 24)
          ..lineTo(r.right - 22, r.top - 24)
          ..lineTo(r.right - 6, r.bottom)
          ..lineTo(r.left + 6, r.bottom)
          ..close(),
        Paint()..color = _kIcePale.withValues(alpha: 0.34),
      );
      for (var i = 0; i < 7; i++) {
        final y = r.top - 24 + ((_time * 150 + i * 33) % (r.height + 34));
        final t = ((y - r.top + 24) / (r.height + 24)).clamp(0.0, 1.0);
        final x = r.center.dx + (r.left + 16 + i * 14.0 - r.center.dx) * (1 + t * 0.5);
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + 22 + t * 20),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.2 + t * 0.3)
            ..strokeWidth = 1.6 + t * 1.6,
        );
      }
      // The plunge: a scatter of broken water at the foot, never still.
      for (var i = 0; i < 7; i++) {
        final a = 0.4 + i * 0.33;
        final k = 12 + (sin(_time * 3 + i) + 1) * 9;
        canvas.drawCircle(
          Offset(fall.dx + cos(a) * k * 2.2, r.bottom + sin(a).abs() * 8),
          2.2,
          Paint()..color = Colors.white.withValues(alpha: 0.34),
        );
      }
    }
  }

  /// The star font: a kerbed basin on a stepped plinth. It was a 26px circle
  /// outline — the object a whole rite is spent on, drawn as a ring.
  void _drawColdFont(Canvas canvas, Offset p, bool charged) {
    for (var i = 2; i >= 0; i--) {
      canvas.drawPath(
        _shaftOctagon(p + Offset(0, i * 5.0), 54.0 - i * 9, 30.0 - i * 5),
        Paint()..color = (i.isEven ? _kShaftStone : _kShaftStoneLit)
            .withValues(alpha: 0.55 + i * 0.1),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 62, height: 40),
      Paint()..color = _kShaftStone.withValues(alpha: 0.95),
    );
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 48, height: 28),
      Paint()
        ..color = (charged ? Colors.white : const Color(0xFF07141C)).withValues(
          alpha: charged ? 0.8 : 0.9,
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 62, height: 40),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = (charged ? Colors.white : _kIcePale).withValues(alpha: 0.75),
    );
    if (charged) {
      _drawStarGlyph(canvas, p, 13, Colors.white);
    }
  }

  /// Frowyrm's hoarfrost pillar: a cluster of hoar blades off a rimed base,
  /// not a white capsule. Shattered, the stumps and the shards stay on the
  /// floor — the fight's clock has to be legible from anywhere in the arena.
  void _drawHoarfrost(Canvas canvas, Offset p, bool whole) {
    canvas.drawOval(
      Rect.fromCenter(center: p + const Offset(0, 48), width: 92, height: 26),
      Paint()..color = _kIceWhite.withValues(alpha: 0.28),
    );
    const heights = [96.0, 70.0, 118.0, 58.0, 84.0];
    const offsets = [-26.0, -8.0, 6.0, 22.0, 34.0];
    for (var i = 0; i < 5; i++) {
      final h = whole ? heights[i] : 16.0 + i * 3;
      final x = p.dx + offsets[i];
      final w = whole ? 12.0 + (i % 3) * 4 : 14.0;
      canvas.drawPath(
        Path()
          ..moveTo(x - w, p.dy + 48)
          ..lineTo(x - w * 0.3, p.dy + 48 - h)
          ..lineTo(x + w * 0.5, p.dy + 48 - h * 0.86)
          ..lineTo(x + w, p.dy + 48)
          ..close(),
        Paint()
          ..color = whole
              ? _kIceWhite.withValues(alpha: 0.86 - (i % 3) * 0.12)
              : const Color(0xFF35505E).withValues(alpha: 0.7),
      );
      if (whole) {
        canvas.drawLine(
          Offset(x - w * 0.6, p.dy + 44),
          Offset(x - w * 0.25, p.dy + 52 - h),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.8)
            ..strokeWidth = 1.6,
        );
      }
    }
    if (!whole) {
      // Shards, where it went.
      for (var i = 0; i < 7; i++) {
        final a = i * 0.9;
        final q = p + Offset(cos(a) * (40 + i * 9), 48 + sin(a) * 16);
        canvas.drawPath(
          Path()
            ..moveTo(q.dx, q.dy)
            ..lineTo(q.dx + 11, q.dy - 5)
            ..lineTo(q.dx + 5, q.dy + 6)
            ..close(),
          Paint()..color = _kIceWhite.withValues(alpha: 0.4),
        );
      }
    }
  }

  /// THE THIRTEENTH TELESCOPE. It was one brown diagonal line — the payoff of
  /// the planet's Lost Maxim, drawn as a stick. A mount now: tripod, yoke,
  /// a graduated declination arc, and the tube pointed at nothing.
  void _drawTelescope(Canvas canvas, Offset p) {
    final wood = Paint()
      ..color = const Color(0xFF4A3C22)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (final dx in [-30.0, 0.0, 30.0]) {
      canvas.drawLine(p + Offset(dx, 62), p + const Offset(0, 4), wood);
    }
    canvas.drawCircle(
      p + const Offset(0, 4),
      9,
      Paint()..color = _kShaftBrass,
    );
    // The declination arc: the instrument's graduations, which is what makes
    // this an observatory's telescope and not a spyglass on a stand.
    final arcRect = Rect.fromCircle(center: p + const Offset(0, 4), radius: 40);
    canvas.drawArc(
      arcRect,
      -2.5,
      1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _kShaftBrassLit.withValues(alpha: 0.8),
    );
    final ticks = Paint()
      ..color = _kShaftBrassLit.withValues(alpha: 0.7)
      ..strokeWidth = 1.4;
    for (var i = 0; i <= 10; i++) {
      final a = -2.5 + 1.5 * i / 10;
      final c = p + const Offset(0, 4);
      final l = i % 5 == 0 ? 9.0 : 5.0;
      canvas.drawLine(
        c + Offset(cos(a) * 40, sin(a) * 40),
        c + Offset(cos(a) * (40 - l), sin(a) * (40 - l)),
        ticks,
      );
    }
    // The tube.
    final axis = p + const Offset(0, 4);
    const ang = -0.82;
    final tube = Path()
      ..moveTo(axis.dx + cos(ang) * -44 + 9, axis.dy + sin(ang) * -44 + 6)
      ..lineTo(axis.dx + cos(ang) * 52 + 7, axis.dy + sin(ang) * 52 + 5)
      ..lineTo(axis.dx + cos(ang) * 52 - 11, axis.dy + sin(ang) * 52 - 8)
      ..lineTo(axis.dx + cos(ang) * -44 - 7, axis.dy + sin(ang) * -44 - 5)
      ..close();
    canvas.drawPath(tube, Paint()..color = const Color(0xFF6E5A34));
    canvas.drawPath(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _kShaftBrassLit.withValues(alpha: 0.65),
    );
    // The objective, with a cold gleam in it.
    canvas.drawCircle(
      axis + Offset(cos(ang) * 52, sin(ang) * 52),
      11,
      Paint()..color = const Color(0xFF0B2733),
    );
    canvas.drawCircle(
      axis + Offset(cos(ang) * 52, sin(ang) * 52),
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _kIcePale.withValues(alpha: 0.7),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// THE GROUND — the observatory, and the glacier over it
// ═══════════════════════════════════════════════════════════
//
// Every room of Glacius used to stand on the generic tinted slab with its
// fixtures floating on it, which is a strange thing for the one dungeon that
// IS a scientific instrument. The place is an observatory that froze
// mid-use, so its ground has to be two things at once: dressed stone, brass
// inlay and graduated arcs underneath, and the glacier that has been growing
// over them ever since.
//
// Two rules govern everything below, and both were learned the hard way:
//
//  • NOTHING IS ON A GRID. Ice does not fracture in squares, and instrument
//    work is radial and graduated rather than ruled. The glacier reads as
//    STRATA (long bowed bands of one year's snow lying on the next, pinched
//    where the ice moved), branching crazes, conchoidal flakes and rime
//    blooms; the observatory reads as azimuth circles, orbits, meridians and
//    a perimeter kerb of irregular blocks. The one authored grid on the
//    planet — the orrery's cells — is deliberately never drawn as cells.
//  • NO `MaskFilter.blur`, ANYWHERE. Frost is the most blur-tempting thing in
//    the game and blur is the game's known jank source. Everything soft here
//    is geometry and alpha: a bloom is a spiked sixteen-point polygon, a
//    fern is a stem with barbs, a glint is two crossed strokes.
//
// It is all built ONCE per room, deterministically from the room's own
// bounds, and cached below. Only the glints and the falling rime move.

/// Every room's static picture, keyed by room id. Built once per process;
/// the geometry depends on nothing but the room's own size.
final Map<String, _ShaftGround> _shaftGroundCache = {};

const Color _kShaftMilk = Color(0xFFE8F4FB);
const Color _kShaftIce = Color(0xFF9FC8DC);
const Color _kShaftGlacier = Color(0xFF2E6377);
const Color _kShaftDark = Color(0xFF061119);
const Color _kShaftBrass = Color(0xFF8C6F36);
const Color _kShaftBrassLit = Color(0xFFE4C16A);
const Color _kShaftStone = Color(0xFF2C3A46);
const Color _kShaftStoneLit = Color(0xFF5C7080);

/// One prebuilt piece of scenery. Paths of the same paint are merged as they
/// are added, so a whole room costs tens of `drawPath` calls and not hundreds.
class _ShaftShape {
  final Path path;
  final Paint paint;
  _ShaftShape(this.path, this.paint);
}

class _ShaftGround {
  /// Drawn under the room's furniture.
  final List<_ShaftShape> base = [];

  /// Drawn over it — the icicle fringe you fell in past, mostly.
  final List<_ShaftShape> overlay = [];

  /// Drawn inside the mirror gallery's pool, clipped to it: the ceiling this
  /// gallery exists to read, and the shaft above, upside down.
  final List<_ShaftShape> reflection = [];

  /// Where the ice catches the light, and each one's own phase.
  final List<Offset> glints = [];
  final List<double> glintPhase = [];

  /// Rime coming down the shaft: a start point and a fall speed each.
  final List<Offset> motes = [];
  final List<double> moteSpeed = [];

  final List<String> _keys = [];
  final List<String> _overKeys = [];
  final List<String> _reflKeys = [];

  void _push(
    List<_ShaftShape> into,
    List<String> keys,
    Path p,
    Paint paint,
    String key,
  ) {
    if (keys.isNotEmpty && keys.last == key) {
      into.last.path.addPath(p, Offset.zero);
      return;
    }
    keys.add(key);
    into.add(_ShaftShape(p, paint));
  }

  void fill(Path p, Color c, {_ShaftLayer layer = _ShaftLayer.base}) {
    final paint = Paint()..color = c;
    switch (layer) {
      case _ShaftLayer.base:
        _push(base, _keys, p, paint, 'f$c');
      case _ShaftLayer.overlay:
        _push(overlay, _overKeys, p, paint, 'f$c');
      case _ShaftLayer.reflection:
        _push(reflection, _reflKeys, p, paint, 'f$c');
    }
  }

  void stroke(
    Path p,
    Color c,
    double w, {
    _ShaftLayer layer = _ShaftLayer.base,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    final key = 's${c}_$w';
    switch (layer) {
      case _ShaftLayer.base:
        _push(base, _keys, p, paint, key);
      case _ShaftLayer.overlay:
        _push(overlay, _overKeys, p, paint, key);
      case _ShaftLayer.reflection:
        _push(reflection, _reflKeys, p, paint, key);
    }
  }
}

enum _ShaftLayer { base, overlay, reflection }

/// The tiny LCG every piece of this planet's scenery is laid out with. Seeded
/// from the room's own size, so a room looks the same every time you walk
/// into it, no two rooms look alike, and nothing has to be hand-placed.
class _ShaftRnd {
  int _s;
  _ShaftRnd(int seed) : _s = (seed & 0x3FFFFFFF) | 1;

  double next() {
    _s = (_s * 1103515245 + 12345) & 0x3FFFFFFF;
    return (_s >> 8) / 0x3FFFFF;
  }

  double range(double a, double b) => a + next() * (b - a);
  int i(int n) => (next() * n).floor().clamp(0, n - 1);
  bool chance(double p) => next() < p;
  double sign() => next() < 0.5 ? -1.0 : 1.0;
}

/// A smooth closed ribbon between a top edge and a bottom edge.
Path _shaftBand(List<Offset> top, List<Offset> bottom) {
  final p = Path()..moveTo(top.first.dx, top.first.dy);
  void run(List<Offset> pts) {
    for (var i = 1; i < pts.length - 1; i++) {
      final m = Offset.lerp(pts[i], pts[i + 1], 0.5)!;
      p.quadraticBezierTo(pts[i].dx, pts[i].dy, m.dx, m.dy);
    }
    p.lineTo(pts.last.dx, pts.last.dy);
  }

  run(top);
  final rev = bottom.reversed.toList();
  p.lineTo(rev.first.dx, rev.first.dy);
  run(rev);
  p.close();
  return p;
}

Path _shaftPoly(List<Offset> pts) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final q in pts.skip(1)) {
    p.lineTo(q.dx, q.dy);
  }
  p.close();
  return p;
}

/// A closed blob with no straight edges and no clean corners — for the things
/// that water made. Built from quadratics through the midpoints, so a pool
/// never comes out as the faceted polygon the first sump did.
Path _shaftBlob(Offset c, double rx, double ry, _ShaftRnd rnd, double wobble) {
  const n = 12;
  final pts = <Offset>[];
  for (var i = 0; i < n; i++) {
    final a = i * pi * 2 / n;
    final k = 1 + (rnd.next() - 0.5) * 2 * wobble;
    pts.add(c + Offset(cos(a) * rx * k, sin(a) * ry * k));
  }
  final path = Path();
  final m0 = Offset.lerp(pts[n - 1], pts[0], 0.5)!;
  path.moveTo(m0.dx, m0.dy);
  for (var i = 0; i < n; i++) {
    final m = Offset.lerp(pts[i], pts[(i + 1) % n], 0.5)!;
    path.quadraticBezierTo(pts[i].dx, pts[i].dy, m.dx, m.dy);
  }
  path.close();
  return path;
}

Path _shaftOctagon(Offset c, double rx, double ry) {
  final pts = <Offset>[];
  for (var i = 0; i < 8; i++) {
    final a = pi / 8 + i * pi / 4;
    pts.add(c + Offset(cos(a) * rx, sin(a) * ry));
  }
  return _shaftPoly(pts);
}

// ── The glacier ──────────────────────────────────────────

/// FOLIATION — the grain of glacier ice.
///
/// THE FIRST ATTEMPT AT THIS WAS WRONG AND IT WAS ONLY WRONG IN A PICTURE.
/// It drew the ice's annual layering as thick bowed ribbons running ACROSS
/// the room, which is what glacier banding does in a photograph and which on
/// a top-down floor read as exactly one thing: Water's horizontal tide lines,
/// the single grammar §5.5 forbids this planet to borrow. Every room came out
/// looking like a pond.
///
/// What is drawn instead is the ice's grain seen from ABOVE and STEEPLY —
/// long fine near-vertical planes, irregularly spaced, most of them barely
/// there, with a few fatter slivers of denser ice between. Vertical surfaces
/// are the shaft's whole visual language, it is cheaper than the bands were,
/// and nothing about it is parallel to a wall or evenly spaced.
/// SECOND FAULT, ALSO ONLY VISIBLE IN A PICTURE: the first fix drew the
/// planes as continuous hairlines from the top of the room to the bottom, and
/// forty of those at once is not ice grain, it is RAIN. Every room came out
/// looking like weather.
///
/// A plane of ice is a BODY, not a line: what is drawn is short overlapping
/// slivers of denser ice, each covering part of the room's height and each
/// carrying one hairline down its lit side. They stop and start, they are
/// nowhere near evenly spaced, and at these alphas a room reads as ice that
/// has a direction rather than as a floor someone hatched.
/// AMBIENT IS TEXTURE, NOT CONTENT.
///
/// The art passes were steered by an "emptiness ranking" — edge-pixels per
/// room — with a note that under ~600 is a box. A metric that rewards ink
/// gets you ink: rooms went from 400 edge-pixels to eleven thousand, and the
/// result, played, is that you cannot tell what you are meant to touch. The
/// orrery floor had three brass orbits crossing the whole room at the same
/// visual weight as the sockets you actually seat blocks in.
///
/// So the decorative layers are thinned and faded at ONE knob apiece, rather
/// than by re-authoring twenty call sites: the relative weights the pass
/// chose are kept, and the whole ambient bed sits back behind the furniture.
/// The room keeps its material and loses its clutter.
///
/// Raise these to get the busy version back; they are the whole lever.
const double _kAmbientThin = 0.42; // how many of them there are
const double _kAmbientFade = 0.55; // how much they assert themselves

int _ambientCount(int n) => (n * _kAmbientThin).round().clamp(1, n);

void _shaftFoliation(_ShaftGround g, Rect b, _ShaftRnd rnd, double alpha) {
  alpha *= _kAmbientFade;
  final skew = rnd.range(0.14, 0.38) * rnd.sign();
  final slivers = Path();
  final edges = Path();
  var x = b.left - b.height * skew.abs() - 40;
  var i = 0;
  while (x < b.right + b.height * skew.abs() + 40) {
    // Each plane covers a run of the room, not all of it.
    final y0 = b.top + rnd.range(-40, b.height * 0.45);
    final y1 = min(b.bottom + 40, y0 + b.height * rnd.range(0.3, 0.8));
    final w = rnd.range(5, 30);
    final wob = rnd.range(0.8, 2.2);
    final amp = rnd.range(2, 9);
    List<Offset> edge(double off) => [
      for (var k = 0; k <= 5; k++)
        Offset(
          x + off + skew * ((y1 - y0) * k / 5) + sin(k * wob + i) * amp,
          y0 + (y1 - y0) * k / 5,
        ),
    ];
    final left = edge(0);
    slivers.addPath(_shaftBand(left, edge(w)), Offset.zero);
    final line = Path()..moveTo(left.first.dx, left.first.dy);
    for (var k = 1; k < left.length - 1; k++) {
      final m = Offset.lerp(left[k], left[k + 1], 0.5)!;
      line.quadraticBezierTo(left[k].dx, left[k].dy, m.dx, m.dy);
    }
    line.lineTo(left.last.dx, left.last.dy);
    edges.addPath(line, Offset.zero);
    x += rnd.range(30, 104);
    i++;
  }
  g.fill(slivers, _kShaftGlacier.withValues(alpha: alpha * 0.4));
  g.stroke(edges, _kShaftMilk.withValues(alpha: alpha * 0.34), 1.1);
}

/// CRAZING. Ice fractures irregularly and it BRANCHES; a fracture that
/// forked and forked again is the single cheapest way to say "this is ice
/// and not a painted floor".
void _shaftCraze(_ShaftGround g, Rect b, _ShaftRnd rnd, int seeds, double a) {
  seeds = _ambientCount(seeds);
  a *= _kAmbientFade;
  final main = Path();
  final hair = Path();
  void crack(Offset from, double ang, double len, int depth) {
    var p = from;
    var t = ang;
    final segs = 3 + rnd.i(4);
    final into = depth == 2 ? main : hair;
    for (var i = 0; i < segs; i++) {
      t += rnd.range(-0.45, 0.45);
      final l = len * rnd.range(0.45, 1.0);
      final q = p + Offset(cos(t) * l, sin(t) * l);
      into
        ..moveTo(p.dx, p.dy)
        ..lineTo(q.dx, q.dy);
      if (depth > 0 && rnd.chance(0.4)) {
        crack(q, t + rnd.sign() * rnd.range(0.5, 1.15), len * 0.62, depth - 1);
      }
      p = q;
    }
  }

  for (var i = 0; i < seeds; i++) {
    crack(
      Offset(rnd.range(b.left, b.right), rnd.range(b.top, b.bottom)),
      rnd.range(0, pi * 2),
      rnd.range(26, 62),
      2,
    );
  }
  g.stroke(main, _kShaftMilk.withValues(alpha: a), 1.7);
  g.stroke(hair, _kShaftMilk.withValues(alpha: a * 0.6), 0.9);
}

/// CONCHOIDAL FLAKES. Where something struck the ice it came away in a shell
/// — a shallow lens with one bright rim. Small, scattered, never repeated at
/// the same size twice.
void _shaftChips(_ShaftGround g, Rect b, _ShaftRnd rnd, int n) {
  n = _ambientCount(n);
  for (var i = 0; i < n; i++) {
    final c = Offset(rnd.range(b.left, b.right), rnd.range(b.top, b.bottom));
    final rx = rnd.range(14, 44);
    final ry = rx * rnd.range(0.32, 0.62);
    final rot = rnd.range(0, pi);
    final pts = <Offset>[];
    for (var k = 0; k < 9; k++) {
      final a = k * pi * 2 / 9;
      final kk = 1 + sin(k * 2.3 + i) * 0.18;
      final x = cos(a) * rx * kk, y = sin(a) * ry * kk;
      pts.add(c + Offset(x * cos(rot) - y * sin(rot), x * sin(rot) + y * cos(rot)));
    }
    g.fill(_shaftPoly(pts), _kShaftMilk.withValues(alpha: 0.07));
    g.stroke(
      Path()
        ..addArc(
          Rect.fromCenter(center: c, width: rx * 2, height: ry * 2),
          rot + 3.3,
          2.2,
        ),
      _kShaftMilk.withValues(alpha: 0.22),
      1.3,
    );
  }
}

/// A RIME BLOOM — frost that grew outward from one point on the floor. A
/// ragged twenty-two-point disc, because a bloom drawn as a soft circle is a
/// blur and blur is the thing this planet is forbidden.
///
/// The first version alternated full and half radius, which made a SNOWFLAKE:
/// a dozen six-pointed stickers scattered over every floor, easily the most
/// cartoon thing in the dungeon. The lobes are shallow now and no two points
/// share a radius, so what reads is a patch of frost with a broken lip.
Path _shaftBloom(Offset c, double r, _ShaftRnd rnd) {
  final pts = <Offset>[];
  for (var i = 0; i < 22; i++) {
    final a = i * pi / 11;
    final k = (1 - (i % 2) * 0.16) * rnd.range(0.8, 1.16);
    pts.add(c + Offset(cos(a) * r * k, sin(a) * r * k * rnd.range(0.82, 1.1)));
  }
  return _shaftPoly(pts);
}

/// A point somewhere in the room's perimeter band, and which wall it is on.
(Offset, int) _shaftEdgePoint(Rect b, _ShaftRnd rnd, double band) {
  final side = rnd.i(4);
  switch (side) {
    case 0:
      return (Offset(rnd.range(b.left, b.right), b.top + rnd.range(4, band)), 0);
    case 1:
      return (
        Offset(b.right - rnd.range(4, band), rnd.range(b.top, b.bottom)),
        1,
      );
    case 2:
      return (
        Offset(rnd.range(b.left, b.right), b.bottom - rnd.range(4, band)),
        2,
      );
    default:
      return (Offset(b.left + rnd.range(4, band), rnd.range(b.top, b.bottom)), 3);
  }
}

/// Frost at the edges of a room, where the cold comes in. Kept OFF the middle
/// deliberately: the guardian arena and every hub floor has to stay open to
/// walk and fight in, so detail lives at the walls.
void _shaftBlooms(_ShaftGround g, Rect b, _ShaftRnd rnd, int n, double band) {
  n = _ambientCount(n);
  for (var i = 0; i < n; i++) {
    final (p, _) = _shaftEdgePoint(b, rnd, band);
    g.fill(
      _shaftBloom(p, rnd.range(20, 62), rnd),
      Colors.white.withValues(alpha: rnd.range(0.035, 0.075)),
    );
  }
}

/// FROST FERNS creeping in off the walls: a stem with barbs, each barb
/// shorter than the last. Nothing in nature grows this on a lattice.
void _shaftFerns(_ShaftGround g, Rect b, _ShaftRnd rnd, int n, double band) {
  n = _ambientCount(n);
  final path = Path();
  for (var f = 0; f < n; f++) {
    final (root, side) = _shaftEdgePoint(b, rnd, band * 0.5);
    final inward = switch (side) {
      0 => pi / 2,
      1 => pi,
      2 => -pi / 2,
      _ => 0.0,
    };
    final ang = inward + rnd.range(-0.5, 0.5);
    final len = rnd.range(22, 54);
    final tip = root + Offset(cos(ang) * len, sin(ang) * len);
    path
      ..moveTo(root.dx, root.dy)
      ..lineTo(tip.dx, tip.dy);
    final barbs = 4 + rnd.i(4);
    for (var i = 1; i <= barbs; i++) {
      final t = i / (barbs + 1);
      final at = Offset.lerp(root, tip, t)!;
      final bl = len * 0.30 * (1 - t * 0.8);
      for (final s in const [-1.0, 1.0]) {
        final ba = ang + s * rnd.range(0.55, 0.85);
        path
          ..moveTo(at.dx, at.dy)
          ..lineTo(at.dx + cos(ba) * bl, at.dy + sin(ba) * bl);
      }
    }
  }
  g.stroke(path, Colors.white.withValues(alpha: 0.15), 1.1);
}

/// The icicle fringe off the lip above. Every room of this shaft is under
/// something, and in the two shelves it is the whole reason the pocket reads
/// as a pocket rather than as a small room.
void _shaftIcicles(
  _ShaftGround g,
  Rect b,
  _ShaftRnd rnd, {
  required int n,
  required double maxLen,
  _ShaftLayer layer = _ShaftLayer.overlay,
}) {
  n = _ambientCount(n);
  final body = Path();
  final lit = Path();
  var x = b.left + rnd.range(4, 30);
  for (var i = 0; i < n && x < b.right; i++) {
    final w = rnd.range(7, 19);
    final l = rnd.range(maxLen * 0.3, maxLen);
    body
      ..moveTo(x, b.top)
      ..lineTo(x + w, b.top)
      ..lineTo(x + w * 0.5 + rnd.range(-3, 3), b.top + l)
      ..close();
    lit
      ..moveTo(x + w * 0.28, b.top + 3)
      ..lineTo(x + w * 0.5, b.top + l * 0.85);
    x += w + rnd.range(6, 42);
  }
  g.fill(body, _kShaftMilk.withValues(alpha: 0.30), layer: layer);
  g.stroke(lit, Colors.white.withValues(alpha: 0.4), 1.2, layer: layer);
}

/// Broken ice on the floor — angular chunks with a lit top facet, piled
/// thickest at [c]. Nothing about a fall of ice is round.
void _shaftRubble(
  _ShaftGround g,
  Offset c,
  double spread,
  _ShaftRnd rnd,
  int n,
) {
  final body = Path();
  final lit = Path();
  for (var i = 0; i < n; i++) {
    final a = rnd.range(0, pi * 2);
    final d = spread * sqrt(rnd.next());
    final p = c + Offset(cos(a) * d, sin(a) * d * 0.62);
    final s = rnd.range(9, 26);
    final pts = <Offset>[];
    for (var k = 0; k < 5; k++) {
      final t = k * pi * 2 / 5 + rnd.range(-0.2, 0.2);
      pts.add(p + Offset(cos(t) * s, sin(t) * s * 0.72));
    }
    body.addPath(_shaftPoly(pts), Offset.zero);
    lit
      ..moveTo(pts[3].dx, pts[3].dy)
      ..lineTo(pts[4].dx, pts[4].dy)
      ..lineTo(pts[0].dx, pts[0].dy);
  }
  g.fill(body, _kShaftIce.withValues(alpha: 0.34));
  g.stroke(lit, Colors.white.withValues(alpha: 0.35), 1.5);
}

// ── The observatory ──────────────────────────────────────

/// A course of dressed blocks round the room, of irregular length — the
/// observatory's own masonry showing under the ice. Irregular ON PURPOSE: a
/// ring of identical blocks is the same failure as a tile floor with the
/// corners rounded off.
void _shaftKerb(_ShaftGround g, Rect b, _ShaftRnd rnd, double depth) {
  final o = b.deflate(10);
  final body = Path();
  final lit = Path();
  void run(Offset from, Offset to, Offset inward) {
    final span = (to - from).distance;
    final dir = (to - from) / span;
    var t = 0.0;
    while (t < span - 8) {
      final l = min(rnd.range(46, 118), span - t - 3);
      final d = depth * rnd.range(0.78, 1.12);
      final a = from + dir * t;
      final bpt = from + dir * (t + l);
      body.addPath(
        _shaftPoly([a, bpt, bpt + inward * d, a + inward * d]),
        Offset.zero,
      );
      lit
        ..moveTo(a.dx + inward.dx * d, a.dy + inward.dy * d)
        ..lineTo(bpt.dx + inward.dx * d, bpt.dy + inward.dy * d);
      t += l + rnd.range(2, 6);
    }
  }

  run(o.topLeft, o.topRight, const Offset(0, 1));
  run(o.bottomRight, o.bottomLeft, const Offset(0, -1));
  run(o.topRight, o.bottomRight, const Offset(-1, 0));
  run(o.bottomLeft, o.topLeft, const Offset(1, 0));
  g.fill(body, _kShaftStone.withValues(alpha: 0.5));
  g.stroke(lit, _kShaftStoneLit.withValues(alpha: 0.45), 1.8);
}

/// A GRADUATED ARC — the observatory's signature mark, and the reason this
/// planet's architecture can be dense without ever becoming graph paper:
/// instrument work is radial and scaled, never ruled in squares.
void _shaftArc(
  _ShaftGround g,
  Offset c,
  double r,
  double a0,
  double sweep, {
  int ticks = 24,
  double width = 2.0,
  double tickLen = 10,
  Color color = _kShaftBrass,
  double alpha = 0.5,
}) {
  g.stroke(
    Path()..addArc(Rect.fromCircle(center: c, radius: r), a0, sweep),
    color.withValues(alpha: alpha),
    width,
  );
  final t = Path();
  for (var i = 0; i <= ticks; i++) {
    final a = a0 + sweep * i / ticks;
    final l = i % 5 == 0 ? tickLen : tickLen * 0.45;
    t
      ..moveTo(c.dx + cos(a) * r, c.dy + sin(a) * r)
      ..lineTo(c.dx + cos(a) * (r - l), c.dy + sin(a) * (r - l));
  }
  g.stroke(t, color.withValues(alpha: alpha * 0.85), 1.4);
}

/// An orbit: a tilted ellipse inlaid in the floor. Drawn by hand rather than
/// with `addOval` so it can be rotated, which is the whole point — a nest of
/// ellipses at different tilts is an orrery, a nest of concentric circles is
/// a target.
void _shaftOrbit(
  _ShaftGround g,
  Offset c,
  double rx,
  double ry,
  double rot,
  double alpha,
  double width,
) {
  final p = Path();
  for (var i = 0; i <= 48; i++) {
    final a = i * pi * 2 / 48;
    final x = cos(a) * rx, y = sin(a) * ry;
    final q = c + Offset(
      x * cos(rot) - y * sin(rot),
      x * sin(rot) + y * cos(rot),
    );
    i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
  }
  p.close();
  g.stroke(p, _kShaftBrass.withValues(alpha: alpha), width);
}

/// A scatter of stars. Used both on the floors that carry a chart and — the
/// point of the whole planet — in the pool that reflects the ceiling.
void _shaftStarfield(
  _ShaftGround g,
  Rect area,
  _ShaftRnd rnd,
  int n,
  _ShaftLayer layer,
  double alpha,
) {
  final small = Path();
  final big = Path();
  final pts = <Offset>[];
  for (var i = 0; i < n; i++) {
    final p = Offset(
      rnd.range(area.left, area.right),
      rnd.range(area.top, area.bottom),
    );
    pts.add(p);
    final r = rnd.range(1.1, 2.9);
    (r > 2.1 ? big : small).addOval(Rect.fromCircle(center: p, radius: r));
  }
  g.fill(small, _kShaftIce.withValues(alpha: alpha * 0.7), layer: layer);
  g.fill(big, _kShaftMilk.withValues(alpha: alpha), layer: layer);
  // A couple of joined figures, so it reads as a CHART and not as noise.
  final lines = Path();
  for (var f = 0; f < 3 && pts.length > 6; f++) {
    var i = rnd.i(pts.length);
    lines.moveTo(pts[i].dx, pts[i].dy);
    for (var k = 0; k < 3; k++) {
      i = rnd.i(pts.length);
      lines.lineTo(pts[i].dx, pts[i].dy);
    }
  }
  g.stroke(lines, _kShaftIce.withValues(alpha: alpha * 0.45), 1.0, layer: layer);
}

// ── Per-room construction ────────────────────────────────

_ShaftGround _buildShaftGround(DungeonRoom room) {
  final b = room.bounds;
  final g = _ShaftGround();
  final rnd = _ShaftRnd((b.width * 131 + b.height * 37).round());

  switch (room.id) {
    case 'mirror_gallery':
      _groundMirrorGallery(g, b, rnd, room.rime!.mirrors!);
    case 'orrery_floor':
      _groundOrreryFloor(g, b, rnd, room.rime!.orrery!);
    case 'cold_sump':
      _groundColdSump(g, b, rnd);
    case 'star_font':
      _groundStarFont(g, b, rnd);
    case 'frowyrm_hollow':
      _groundFrowyrmHollow(g, b, rnd);
    case 'shelf_glass':
      _groundShelf(g, b, rnd, vault: true);
    case 'shelf_lens':
      _groundShelf(g, b, rnd, vault: false);
    default:
      _groundRimeHead(g, b, rnd, room.id);
  }

  // The weather, everywhere: a few glints and a thin fall of rime. Both are
  // capped low on purpose — this runs at 60fps on a phone, and the per-frame
  // budget of a room is meant to be a rounding error.
  for (var i = 0; i < 14; i++) {
    g.glints.add(
      Offset(rnd.range(b.left + 16, b.right - 16), rnd.range(b.top + 16, b.bottom - 16)),
    );
    g.glintPhase.add(rnd.range(0, pi * 2));
  }
  for (var i = 0; i < 16; i++) {
    g.motes.add(Offset(rnd.range(b.left, b.right), rnd.range(0, b.height)));
    g.moteSpeed.add(rnd.range(14, 46));
  }
  return g;
}

/// L0 — THE RIME HEAD. The one room of the shaft that is still a ROOM: the
/// observing floor itself, open to the sky, with the great azimuth circle
/// laid into it, the old sighting bench across the middle, and the two mouths
/// cut through the stone at its southern wall.
void _groundRimeHead(_ShaftGround g, Rect b, _ShaftRnd rnd, String roomId) {
  _shaftFoliation(g, b, rnd, 0.30);
  _shaftKerb(g, b, rnd, 30);
  _shaftCraze(g, b, rnd, 7, 0.14);
  _shaftChips(g, b, rnd, 8);

  // THE AZIMUTH CIRCLE. The floor's own instrument, and the thing that says
  // "observatory" before any fixture does. Laid as two broken runs rather
  // than a closed ring: what the ice has taken, it has taken.
  final c = Offset(b.center.dx - 8, b.center.dy + 34);
  _shaftArc(g, c, 212, -2.72, 2.05, ticks: 30, width: 2.6);
  _shaftArc(g, c, 212, 0.42, 1.5, ticks: 20, width: 2.6);
  _shaftArc(g, c, 166, -2.3, 1.2, ticks: 12, width: 1.5, tickLen: 7);

  // THE MERIDIAN. One brass strip through the centre with its own scale —
  // the line an observatory is built around.
  final mer = Path()
    ..addRect(Rect.fromLTRB(c.dx - 3, b.top + 22, c.dx + 3, b.bottom - 22));
  g.fill(mer, _kShaftBrass.withValues(alpha: 0.38));
  final ticks = Path();
  for (var y = b.top + 34.0; y < b.bottom - 30; y += 24) {
    final long = ((y - b.top) ~/ 24) % 5 == 0;
    ticks
      ..moveTo(c.dx - (long ? 11 : 6), y)
      ..lineTo(c.dx + (long ? 11 : 6), y);
  }
  g.stroke(ticks, _kShaftBrassLit.withValues(alpha: 0.32), 1.2);

  // THE OLD SIGHTING BENCH carries a quadrant — a graduated quarter circle
  // with its plumb arm still hanging. The layout puts a wall there and it had
  // nothing on it; this is what the wall is FOR.
  final q = Offset(b.left + 380, b.top + 184);
  _shaftArc(g, q, 62, -pi + 0.1, pi / 2 - 0.2,
      ticks: 18, width: 2.4, color: _kShaftBrassLit, alpha: 0.6);
  g.stroke(
    Path()
      ..moveTo(q.dx, q.dy)
      ..lineTo(q.dx - 58, q.dy - 22)
      ..moveTo(q.dx, q.dy)
      ..lineTo(q.dx, q.dy + 30),
    _kShaftBrassLit.withValues(alpha: 0.5),
    2.0,
  );

  // SNOW BLOWN IN at the north lip, heaped against the kerb: this floor is
  // the one place on the planet that is open to the weather.
  final drift = Path();
  for (var i = 0; i < 7; i++) {
    final x = b.left + rnd.range(20, b.width - 20);
    drift.addOval(
      Rect.fromCenter(
        center: Offset(x, b.top + rnd.range(4, 34)),
        width: rnd.range(90, 210),
        height: rnd.range(28, 60),
      ),
    );
  }
  g.fill(drift, _kShaftMilk.withValues(alpha: 0.16));

  _shaftBlooms(g, b, rnd, 9, 90);
  _shaftFerns(g, b, rnd, 13, 100);
  _shaftIcicles(g, b.deflate(10), rnd, n: 16, maxLen: 40);
  if (roomId != 'rime_head') return;
}

/// L1 — THE MIRROR GALLERY. A ring of twelve frames round a still black pool,
/// standing on RADIAL paving: wedges struck from the pool's own centre, which
/// is how a room built around one instrument is actually floored, and which
/// could not be further from a lattice.
void _groundMirrorGallery(
  _ShaftGround g,
  Rect b,
  _ShaftRnd rnd,
  MirrorRing ring,
) {
  _shaftFoliation(g, b, rnd, 0.22);

  // RADIAL PAVING — flags struck from the pool's own centre, which is how a
  // room built around one instrument is actually floored, and which could not
  // be further from a lattice.
  //
  // The first attempt filled alternate wedges light and dark. At this scale a
  // pale wedge 200px long is not a flagstone, it is a SPOTLIGHT CONE: two of
  // them landed next to each other and the gallery looked lit from above by
  // something that is not in the room. It is the JOINTS that make paving
  // read, so the fills are nearly flat now and the cuts between them carry
  // the drawing.
  final flags = Path();
  final joints = Path();
  var a = rnd.range(0, 0.4);
  var flip = false;
  const courses = [196.0, 262.0, 330.0, 420.0];
  while (a < pi * 2) {
    final w = rnd.range(0.17, 0.36);
    final a1 = min(a + w, pi * 2);
    for (var ci = 0; ci < courses.length - 1; ci++) {
      final r0 = courses[ci], r1 = courses[ci + 1];
      final wedge = Path()
        ..moveTo(ring.center.dx + cos(a) * r0, ring.center.dy + sin(a) * r0)
        ..arcTo(
          Rect.fromCircle(center: ring.center, radius: r0),
          a,
          a1 - a,
          false,
        )
        ..lineTo(ring.center.dx + cos(a1) * r1, ring.center.dy + sin(a1) * r1)
        ..arcTo(
          Rect.fromCircle(center: ring.center, radius: r1),
          a1,
          a - a1,
          false,
        )
        ..close();
      if (flip) flags.addPath(wedge, Offset.zero);
      flip = !flip;
      // The radial cut, staggered course by course so the joints never line
      // up into a spoke.
      final off = (ci.isEven ? 0.0 : w * 0.5);
      joints
        ..moveTo(
          ring.center.dx + cos(a + off) * r0,
          ring.center.dy + sin(a + off) * r0,
        )
        ..lineTo(
          ring.center.dx + cos(a + off) * r1,
          ring.center.dy + sin(a + off) * r1,
        );
    }
    a = a1;
  }
  g.fill(flags, _kShaftStoneLit.withValues(alpha: 0.07));
  for (final r in courses.skip(1)) {
    joints.addOval(Rect.fromCircle(center: ring.center, radius: r));
  }
  g.stroke(joints, _kShaftDark.withValues(alpha: 0.4), 1.6);

  // THE POOL'S KERB: dressed blocks following the circle, irregular lengths.
  final kerb = Path();
  final kerbLit = Path();
  final pr = ring.radius - 34;
  var k = 0.0;
  while (k < pi * 2) {
    final w = rnd.range(0.2, 0.42);
    final k1 = min(k + w, pi * 2);
    kerb
      ..moveTo(ring.center.dx + cos(k) * pr, ring.center.dy + sin(k) * pr)
      ..arcTo(Rect.fromCircle(center: ring.center, radius: pr), k, k1 - k, false)
      ..lineTo(
        ring.center.dx + cos(k1) * (pr + 15),
        ring.center.dy + sin(k1) * (pr + 15),
      )
      ..arcTo(
        Rect.fromCircle(center: ring.center, radius: pr + 15),
        k1,
        k - k1,
        false,
      )
      ..close();
    kerbLit
      ..moveTo(
        ring.center.dx + cos(k + 0.02) * (pr + 15),
        ring.center.dy + sin(k + 0.02) * (pr + 15),
      )
      ..arcTo(
        Rect.fromCircle(center: ring.center, radius: pr + 15),
        k + 0.02,
        k1 - k - 0.04,
        false,
      );
    k = k1 + 0.03;
  }
  g.fill(kerb, _kShaftStone.withValues(alpha: 0.85));
  g.stroke(kerbLit, _kShaftStoneLit.withValues(alpha: 0.5), 2.0);

  // THE READING CIRCLE outside the frames: the graduations the twelve are
  // set against.
  _shaftArc(g, ring.center, ring.radius + 44, -2.9, 5.6, ticks: 48, width: 1.6);

  // THE REFLECTION — the planet's whole signature. Inside the pool: the
  // ceiling's chart, and the shaft above it converging away, so the vault's
  // glow has somewhere to hang. It used to be a dot on flat black.
  final pool = Rect.fromCircle(center: ring.center, radius: pr);
  g.fill(
    _shaftPoly([
      ring.center + const Offset(-112, 190),
      ring.center + const Offset(-40, -190),
      ring.center + const Offset(62, -190),
      ring.center + const Offset(150, 190),
    ]),
    _kShaftGlacier.withValues(alpha: 0.20),
    layer: _ShaftLayer.reflection,
  );
  g.stroke(
    Path()
      ..moveTo(ring.center.dx - 112, ring.center.dy + 190)
      ..lineTo(ring.center.dx - 40, ring.center.dy - 190)
      ..moveTo(ring.center.dx + 150, ring.center.dy + 190)
      ..lineTo(ring.center.dx + 62, ring.center.dy - 190),
    _kShaftIce.withValues(alpha: 0.3),
    2.0,
    layer: _ShaftLayer.reflection,
  );
  _shaftStarfield(g, pool, rnd, 34, _ShaftLayer.reflection, 0.5);

  _shaftBlooms(g, b, rnd, 8, 80);
  _shaftFerns(g, b, rnd, 14, 90);
  _shaftCraze(g, b, rnd, 5, 0.10);
}

/// L2 — THE STANDING ORRERY. The floor is the machine: a hub where the sun
/// would stand, brass orbits at four different tilts running out under the
/// star-blocks, and armature arms to the iron standards. The authored grid is
/// never drawn AS a grid — nothing here lines up with a cell edge except the
/// glaze the player lays, which is the one thing that should.
void _groundOrreryFloor(_ShaftGround g, Rect b, _ShaftRnd rnd, OrreryGrid o) {
  _shaftFoliation(g, b, rnd, 0.20);
  final hub = o.origin + Offset(o.cols * o.cell / 2, o.rows * o.cell / 2);

  // The orbits, at four different tilts. A nest of tilted ellipses is an
  // orrery; a nest of concentric circles is a target.
  //
  // AND THEY ARE INLAY, NOT FURNITURE. At their first weight they were brass
  // lines as bright and as thick as the socket rims — three of them crossing
  // the whole floor, at the same visual pitch as the four things you actually
  // seat a block in. The room read as a diagram of itself and the puzzle
  // hid inside its own decoration. They are sunk into the floor now: thinner,
  // dimmer, and falling away outward, so the machine is legible as a MACHINE
  // and the brightest brass in the room is the brass you can use.
  _shaftOrbit(g, hub, 118, 74, 0.32, 0.26, 1.5);
  _shaftOrbit(g, hub, 196, 128, -0.22, 0.21, 1.3);
  _shaftOrbit(g, hub, 288, 176, 0.44, 0.16, 1.1);
  _shaftOrbit(g, hub, 360, 232, -0.12, 0.11, 1.0);

  // THE ARMATURE, SHORT. The first pass ran a brass arm from the hub all the
  // way out to each of the four standards — and because the layout puts them
  // at four symmetrical corners, what it actually drew was an enormous
  // SALTIRE across the middle of the room. A machine's arms are stubs off its
  // hub; the standards get their own brackets pointing back at it instead, so
  // the geometry still says "these four belong to that machine" without
  // painting an X over the puzzle the player has to read.
  final arms = Path();
  final beads = Path();
  for (var r = 0; r < o.rows; r++) {
    for (var c = 0; c < o.cols; c++) {
      if (o.art[r][c] != '#') continue;
      final p = o.centerAt(c, r);
      final d = p - hub;
      final u = d / d.distance;
      final n = Offset(-u.dy, u.dx);
      final a0 = hub + u * 24;
      final a1 = hub + u * (d.distance * 0.38);
      arms.addPath(
        _shaftPoly([a0 + n * 6, a1 + n * 3, a1 - n * 3, a0 - n * 6]),
        Offset.zero,
      );
      final b0 = p - u * 40;
      arms.addPath(
        _shaftPoly([b0 + n * 3, p + n * 5, p - n * 5, b0 - n * 3]),
        Offset.zero,
      );
      beads
        ..moveTo(a0.dx, a0.dy)
        ..lineTo(a1.dx, a1.dy);
    }
  }
  g.fill(arms, _kShaftBrass.withValues(alpha: 0.6));
  g.stroke(beads, _kShaftBrassLit.withValues(alpha: 0.4), 1.4);

  // The hub boss — where the sun would stand if this machine still ran.
  g.fill(
    Path()..addOval(Rect.fromCircle(center: hub, radius: 30)),
    _kShaftStone.withValues(alpha: 0.8),
  );
  g.fill(
    Path()..addOval(Rect.fromCircle(center: hub, radius: 20)),
    _kShaftBrass.withValues(alpha: 0.7),
  );
  final rays = Path();
  for (var i = 0; i < 12; i++) {
    final a = i * pi / 6;
    rays
      ..moveTo(hub.dx + cos(a) * 21, hub.dy + sin(a) * 21)
      ..lineTo(hub.dx + cos(a) * 31, hub.dy + sin(a) * 31);
  }
  g.stroke(rays, _kShaftBrassLit.withValues(alpha: 0.6), 2.0);

  // The margins: the ice the machine froze under, and the meridian scale run
  // along the room's northern wall above the sockets.
  _shaftArc(
    g,
    Offset(hub.dx, b.top - 250),
    400,
    pi / 2 - 0.5,
    1.0,
    ticks: 32,
    width: 1.6,
    color: _kShaftBrassLit,
    alpha: 0.3,
  );
  _shaftKerb(g, b, rnd, 26);
  _shaftCraze(g, b, rnd, 6, 0.11);
  _shaftChips(g, b, rnd, 7);
  _shaftBlooms(g, b, rnd, 8, 74);
  _shaftFerns(g, b, rnd, 14, 80);
  _shaftIcicles(g, b.deflate(10), rnd, n: 14, maxLen: 34);
}

/// THE COLD SUMP — the bottom, where everything the shaft melts ends up. A
/// plunge basin under the rimefall, the fan of ice it has thrown, and a
/// staff gauge on the wall that nobody has read for a very long time.
void _groundColdSump(_ShaftGround g, Rect b, _ShaftRnd rnd) {
  _shaftFoliation(g, b, rnd, 0.26);

  // THE MELTWATER. Ragged-lipped, lying in the low ground, with two shore
  // lines inside it where the level has stood and dropped.
  final basin = Offset(b.left + 300, b.top + 330);
  for (final (k, alpha, wob) in const [
    (1.0, 0.44, 0.13),
    (0.74, 0.20, 0.17),
    (0.5, 0.14, 0.2),
  ]) {
    g.fill(
      _shaftBlob(basin, 258 * k, 156 * k, rnd, wob),
      (alpha > 0.3 ? _kShaftDark : _kShaftGlacier).withValues(alpha: alpha),
    );
  }
  // The lip, where the ice shelf breaks down into the water.
  g.stroke(
    _shaftBlob(basin, 262, 159, rnd, 0.12),
    _kShaftMilk.withValues(alpha: 0.16),
    2.0,
  );

  // The fan of broken ice under the fall, and rubble along the east wall.
  _shaftRubble(g, Offset(b.left + 130, b.top + 200), 110, rnd, 16);
  _shaftRubble(g, Offset(b.right - 90, b.bottom - 120), 90, rnd, 10);

  // THE STAFF GAUGE: a graduated depth scale down the wall beside the fall.
  // An observatory measures things; this is the sump's one instrument.
  final gx = b.left + 34;
  g.fill(
    Path()..addRect(Rect.fromLTRB(gx - 4, b.top + 150, gx + 4, b.bottom - 60)),
    _kShaftBrass.withValues(alpha: 0.5),
  );
  final gt = Path();
  var n = 0;
  for (var y = b.top + 158.0; y < b.bottom - 66; y += 14) {
    // Ticks on ONE side only and mostly stubs. Rungs crossing a rail made a
    // ladder, and a ladder is the last thing this planet should hand you for
    // free at the bottom of the shaft.
    final long = n % 5 == 0;
    gt
      ..moveTo(gx + 4, y)
      ..lineTo(gx + (long ? 15 : 8), y);
    n++;
  }
  g.stroke(gt, _kShaftBrassLit.withValues(alpha: 0.45), 1.2);

  _shaftCraze(g, b, rnd, 7, 0.12);
  _shaftBlooms(g, b, rnd, 10, 86);
  _shaftFerns(g, b, rnd, 16, 92);
  // Everything drips at the bottom of a shaft: the deepest fringe on the
  // planet hangs here.
  _shaftIcicles(g, b.deflate(10), rnd, n: 22, maxLen: 66);
}

/// THE STAR FONT — the rite room. Its floor carries an ANALEMMA: the figure
/// the sun draws over a year, inlaid in brass with its own graduations. The
/// two halves of the rite stand on its two lobes, which is why the room does
/// not need a symmetry axis drawn down the middle to look composed.
void _groundStarFont(_ShaftGround g, Rect b, _ShaftRnd rnd) {
  _shaftFoliation(g, b, rnd, 0.26);
  _shaftKerb(g, b, rnd, 24);

  // THE FIRST DRAFT OF THIS FLOOR HAD A FACE ON IT. A wide brass lemniscate
  // across the middle, an octagonal plinth inside each of its two lobes, and
  // a graduated arc curving along below — which is a pair of SPECTACLES over
  // a SMILE, and once seen it cannot be unseen. The analemma is upright and
  // narrow now (which is what one actually looks like: tall and pinched, not
  // a lazy eight), it runs down the room's noon line rather than across it,
  // and the arc below it is gone. What carries the floor instead is the
  // thing an observatory floor should carry: A DIAL.
  final gnomon = Offset(b.left + 320, b.bottom - 46);

  // Hour lines fanning up from the gnomon's socket to the graduated limb.
  final hours = Path();
  for (var i = 0; i <= 12; i++) {
    final a = -pi * 0.93 + i * (pi * 0.86) / 12;
    hours
      ..moveTo(gnomon.dx + cos(a) * 58, gnomon.dy + sin(a) * 58)
      ..lineTo(gnomon.dx + cos(a) * 292, gnomon.dy + sin(a) * 292);
  }
  g.stroke(hours, _kShaftBrass.withValues(alpha: 0.34), 1.6);
  _shaftArc(g, gnomon, 300, -pi * 0.95, pi * 0.9,
      ticks: 36, width: 2.2, tickLen: 12);
  g.fill(
    Path()..addOval(Rect.fromCenter(center: gnomon, width: 62, height: 30)),
    _kShaftStone.withValues(alpha: 0.8),
  );
  g.fill(
    Path()..addOval(Rect.fromCenter(center: gnomon, width: 26, height: 13)),
    _kShaftDark.withValues(alpha: 0.85),
  );

  // THE ANALEMMA, upright: narrow, and laid along the dial's noon line.
  final c = Offset(b.left + 320, b.top + 232);
  final lem = Path();
  final marks = Path();
  for (var i = 0; i <= 96; i++) {
    final t = i * pi * 2 / 96;
    final d = 1 + sin(t) * sin(t);
    final p = c + Offset(52 * sin(t) * cos(t) / d, 150 * cos(t) / d);
    i == 0 ? lem.moveTo(p.dx, p.dy) : lem.lineTo(p.dx, p.dy);
    if (i % 8 == 0) {
      marks
        ..moveTo(p.dx - 7, p.dy)
        ..lineTo(p.dx + 7, p.dy);
    }
  }
  g.stroke(lem, _kShaftBrassLit.withValues(alpha: 0.55), 2.4);
  g.stroke(marks, _kShaftBrassLit.withValues(alpha: 0.4), 1.3);

  // The two plinths the rite stands on: stepped stone, not octagonal discs —
  // a disc beside a disc is what made the lobes read as lenses.
  for (final p in [
    Offset(b.left + 200, b.top + 250),
    Offset(b.left + 440, b.top + 250),
  ]) {
    for (var i = 1; i >= 0; i--) {
      final r = Rect.fromCenter(
        center: p + Offset(0, i * 6.0),
        width: 108 - i * 22,
        height: 66 - i * 14,
      );
      g.fill(
        Path()..addRect(r),
        (i == 0 ? _kShaftStoneLit : _kShaftStone).withValues(alpha: 0.4),
      );
      g.stroke(
        Path()..addRect(r),
        _kShaftStoneLit.withValues(alpha: 0.4),
        1.6,
      );
    }
  }

  // The chart on the ceiling this font answers to, cut into its floor.
  _shaftStarfield(
    g,
    Rect.fromLTRB(b.left + 40, b.top + 30, b.right - 40, b.top + 110),
    rnd,
    18,
    _ShaftLayer.base,
    0.32,
  );

  _shaftCraze(g, b, rnd, 6, 0.12);
  _shaftBlooms(g, b, rnd, 8, 70);
  _shaftFerns(g, b, rnd, 12, 80);
  _shaftIcicles(g, b.deflate(10), rnd, n: 13, maxLen: 36);
}

/// FROWYRM'S HOLLOW — not a room at all, a cavity melted into the glacier and
/// refrozen. Fluted ice columns round the walls, the wyrm's own scour marks
/// sweeping across the floor, rubble in the corners — and a wide OPEN CENTRE,
/// because this is a guardian arena and a fight needs ground.
void _groundFrowyrmHollow(_ShaftGround g, Rect b, _ShaftRnd rnd) {
  _shaftFoliation(g, b, rnd, 0.22);

  // SCOUR MARKS: long sweeping gouges, each a partial arc of a different
  // circle, so they read as something huge having turned in here rather than
  // as a pattern.
  final scour = Path();
  for (var i = 0; i < 9; i++) {
    final c = b.center + Offset(rnd.range(-260, 260), rnd.range(-180, 180));
    final r = rnd.range(180, 460);
    final a0 = rnd.range(0, pi * 2);
    scour.addArc(Rect.fromCircle(center: c, radius: r), a0, rnd.range(0.5, 1.4));
  }
  g.stroke(scour, _kShaftMilk.withValues(alpha: 0.10), 3.0);

  // FLUTED ICE COLUMNS round the walls, where the melt ran down and refroze.
  //
  // The first pass tapered them hard and stood them all on one line, which
  // produced a row of identical TENTS along the top of the arena and another
  // along the bottom — a picket fence, and the exact repeating-silhouette
  // failure this planet is not allowed. They barely taper now, no two stand
  // on the same baseline, and each has a dark side, so what reads is a wall
  // of ice columns receding rather than a pattern stamped along an edge.
  final body = Path();
  final dark = Path();
  final lit = Path();
  final flute = Path();
  void column(double x, double y, double w, double h) {
    final top = y - h * 0.5, bot = y + h * 0.5;
    body.addPath(
      _shaftPoly([
        Offset(x - w, bot),
        Offset(x - w * 0.82, top),
        Offset(x + w * 0.84, top),
        Offset(x + w, bot),
      ]),
      Offset.zero,
    );
    dark.addPath(
      _shaftPoly([
        Offset(x + w * 0.36, bot),
        Offset(x + w * 0.3, top),
        Offset(x + w * 0.84, top),
        Offset(x + w, bot),
      ]),
      Offset.zero,
    );
    lit
      ..moveTo(x - w * 0.74, bot - 2)
      ..lineTo(x - w * 0.6, top + 2);
    for (var i = -1; i <= 1; i++) {
      flute
        ..moveTo(x + i * w * 0.3, bot - 3)
        ..lineTo(x + i * w * 0.26, top + 3);
    }
  }

  var x = b.left + rnd.range(20, 70);
  while (x < b.right - 30) {
    column(x, b.top + rnd.range(10, 70), rnd.range(13, 30), rnd.range(54, 128));
    x += rnd.range(48, 150);
  }
  x = b.left + rnd.range(20, 90);
  while (x < b.right - 30) {
    column(
      x,
      b.bottom - rnd.range(6, 66),
      rnd.range(12, 28),
      rnd.range(48, 116),
    );
    x += rnd.range(54, 168);
  }
  var y = b.top + rnd.range(110, 170);
  while (y < b.bottom - 110) {
    column(b.left + rnd.range(14, 56), y, rnd.range(12, 26), rnd.range(50, 92));
    y += rnd.range(88, 150);
  }
  y = b.top + rnd.range(130, 200);
  while (y < b.bottom - 110) {
    column(b.right - rnd.range(14, 56), y, rnd.range(12, 26), rnd.range(50, 92));
    y += rnd.range(88, 150);
  }
  g.fill(body, _kShaftIce.withValues(alpha: 0.26));
  g.fill(dark, _kShaftDark.withValues(alpha: 0.22));
  g.stroke(flute, _kShaftMilk.withValues(alpha: 0.14), 1.3);
  g.stroke(lit, Colors.white.withValues(alpha: 0.30), 2.0);

  // Kept clear of the hoarfrost pillar at (170, 480): the first pass piled
  // rubble straight on top of it and buried the fight's own clock.
  _shaftRubble(g, Offset(b.left + 130, b.top + 190), 84, rnd, 9);
  _shaftRubble(g, Offset(b.right - 150, b.bottom - 140), 80, rnd, 8);
  _shaftCraze(g, b, rnd, 8, 0.11);
  _shaftFerns(g, b, rnd, 18, 86);
  _shaftBlooms(g, b, rnd, 9, 78);
  _shaftIcicles(g, b.deflate(10), rnd, n: 18, maxLen: 52);
}

/// A SHELF off the throat: not a small room, a POCKET you fell into. The lip
/// you came through fringes the top, the ice is clear enough to see the
/// fractures deep in it, and the outer edge has broken away — which is the
/// whole reason nothing can climb to one of these.
void _groundShelf(_ShaftGround g, Rect b, _ShaftRnd rnd, {required bool vault}) {
  _shaftFoliation(g, b, rnd, 0.34);
  _shaftCraze(g, b, rnd, 9, 0.18);
  _shaftChips(g, b, rnd, 10);

  // The back wall: a dressed face, because a shelf in an observatory's throat
  // is a built niche and not just a hole.
  final wall = Path()
    ..addRect(Rect.fromLTRB(b.left + 12, b.top + 10, b.right - 12, b.top + 54));
  g.fill(wall, _kShaftStone.withValues(alpha: 0.5));
  final joints = Path();
  var jx = b.left + rnd.range(30, 70);
  while (jx < b.right - 20) {
    joints
      ..moveTo(jx, b.top + 10)
      ..lineTo(jx + rnd.range(-5, 5), b.top + 54);
    jx += rnd.range(48, 96);
  }
  joints
    ..moveTo(b.left + 12, b.top + 54)
    ..lineTo(b.right - 12, b.top + 54);
  g.stroke(joints, _kShaftStoneLit.withValues(alpha: 0.4), 1.6);

  // THE BROKEN LIP. The outer edge of the shelf is a row of ice teeth over
  // the dark of the throat — it is falling away, and it is why a drift ride
  // is the only way in.
  final teeth = Path();
  final void_ = Path()
    ..addRect(Rect.fromLTRB(b.left + 10, b.bottom - 40, b.right - 10, b.bottom));
  g.fill(void_, _kShaftDark.withValues(alpha: 0.55));
  var tx = b.left + 10;
  while (tx < b.right - 10) {
    final w = rnd.range(18, 52);
    teeth
      ..moveTo(tx, b.bottom - 42)
      ..lineTo(tx + w * 0.5, b.bottom - 42 + rnd.range(6, 34))
      ..lineTo(tx + w, b.bottom - 42);
    tx += w;
  }
  teeth.close();
  g.fill(teeth, _kShaftIce.withValues(alpha: 0.4));
  g.stroke(teeth, Colors.white.withValues(alpha: 0.3), 1.4);

  if (vault) {
    // THE GLASS LEDGE. An arched recess in the back wall with the cache set
    // in it — a vault should look like somewhere a thing was PUT.
    final n = Offset(b.left + 210, b.top + 232);
    final arch = Path()
      ..moveTo(n.dx - 62, n.dy + 62)
      ..lineTo(n.dx - 62, n.dy - 16)
      ..arcToPoint(Offset(n.dx + 62, n.dy - 16), radius: const Radius.circular(62))
      ..lineTo(n.dx + 62, n.dy + 62)
      ..close();
    g.fill(arch, _kShaftDark.withValues(alpha: 0.6));
    g.stroke(arch, _kShaftStoneLit.withValues(alpha: 0.45), 3.0);
    g.fill(
      Path()
        ..addOval(
          Rect.fromCenter(center: n + const Offset(0, 58), width: 118, height: 26),
        ),
      _kShaftStone.withValues(alpha: 0.7),
    );
    // Old crates the ice has taken, stacked to one side.
    for (final (dx, dy, w, h) in const [
      (-150.0, 40.0, 54.0, 42.0),
      (-140.0, -6.0, 44.0, 36.0),
      (146.0, 36.0, 62.0, 46.0),
    ]) {
      final r = Rect.fromCenter(
        center: n + Offset(dx, dy),
        width: w,
        height: h,
      );
      g.fill(Path()..addRect(r), const Color(0xFF3B3222).withValues(alpha: 0.7));
      g.stroke(
        Path()
          ..addRect(r.deflate(5))
          ..moveTo(r.left, r.center.dy)
          ..lineTo(r.right, r.center.dy),
        _kShaftBrass.withValues(alpha: 0.5),
        1.4,
      );
    }
  } else {
    // THE LENS NICHE. A bracket shelf of stowed instrument cases on the west
    // wall — the thirteenth telescope's own kit, left where it was set down.
    final sy = b.top + 128.0;
    g.fill(
      Path()..addRect(Rect.fromLTRB(b.left + 18, sy, b.left + 128, sy + 9)),
      _kShaftStone.withValues(alpha: 0.8),
    );
    for (var i = 0; i < 3; i++) {
      final r = Rect.fromLTWH(b.left + 24 + i * 34.0, sy - 30, 26, 30);
      g.fill(Path()..addRect(r), const Color(0xFF3B3222).withValues(alpha: 0.75));
      g.stroke(
        Path()
          ..moveTo(r.left + 3, r.top + 9)
          ..lineTo(r.right - 3, r.top + 9),
        _kShaftBrassLit.withValues(alpha: 0.5),
        1.4,
      );
    }
    // A chart pinned to the back wall, half rimed over.
    g.fill(
      Path()..addRect(Rect.fromLTWH(b.right - 132, b.top + 78, 100, 74)),
      _kShaftDark.withValues(alpha: 0.5),
    );
    _shaftStarfield(
      g,
      Rect.fromLTWH(b.right - 128, b.top + 82, 92, 66),
      rnd,
      12,
      _ShaftLayer.base,
      0.45,
    );
  }

  _shaftBlooms(g, b, rnd, 7, 64);
  _shaftFerns(g, b, rnd, 12, 70);
  // A pocket is UNDER something: the densest fringe on the planet.
  _shaftIcicles(g, b.deflate(10), rnd, n: 20, maxLen: 62);
}
