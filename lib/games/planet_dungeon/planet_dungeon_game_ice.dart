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

/// Ptolemy, sighting the thirteenth star.
const String kIceStarWalkerMaxim =
    '"When I trace the circling courses of the stars, my feet no longer '
    'touch the earth."';

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
      return 'The melt-fall runs — nothing climbs running water';
    }
    return switch (_flue(flue.id)) {
      RimeFlueState.scoured => 'Bare glass, and no snow left to take frost',
      _ => 'Loose snow — it will not hold a step',
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
          'The rimefall carries you out — and behind you the whole shaft '
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
        _setHint('The drift brakes you onto a ledge — and goes with you', 3.4);
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
    _setHint('Light drinks the black ice — the floor opens its mouths');
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
          _setBlockedHint('Bare glass — frost finds nothing to hold');
        case RimeFlueState.drift:
          flueState[f.id] = RimeFlueState.stair;
          _setHint('The fall sets — a stair, and the shelf under it is shut');
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
    _setHint('The rimefall locks — one long stair, all the way to the mouth');
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
        'The font refuses the offering — it answers only a bearer of the '
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
    _setHint('The hoarfrost stands again — and the wyrm slows to look at it');
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
            _setHint('The lodestone takes a light of its own — and keeps it');
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
            _setBlockedHint('This glass takes no frost — it answers Light');
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
    _setHint('A cold sweep goes round the ring — every glass holds again');
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
    _setHint('Twelve glasses hold the chart at once — the sky admits it');
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
      _setHint('A glass clouds over — the ring will not be half-read', 2.6);
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
      _setBlockedHint('The lens shows only frost — nothing is charted yet');
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
      _setBlockedHint('The mount will not hold — the sighting drifts');
      return true;
    }
    _discoverCloud(kIceStarWalkerEggId); // the screen pays the 20 gold
    _setHint('STAR-WALKER — $kIceStarWalkerMaxim', 7.5);
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
      _setHint('Frowyrm roars up the shaft — a stair goes out from under it');
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
      return 'Frowyrm\'s Hollow — the wyrm keeps the last star';
    }
    if (room.rime?.coldFont != null) return 'The Star Font — the rite waits';
    if (room.rime?.rimefall != null) {
      return 'The Cold Sump — the shaft bottoms out here';
    }
    if (room.rime?.telescope != null) {
      return discoveredClouds.contains(kIceStarWalkerEggId)
          ? null
          : 'A niche off the throat — an old lens, pointed at nothing';
    }
    if (room.vaultCache != null) {
      return 'A glass ledge — something is bottled here';
    }
    final ring = room.rime?.mirrors;
    if (ring != null) {
      if (hasStar(room.rime!.starIndex!)) return null;
      return 'The Mirror Gallery — twelve frames, and none of them showing';
    }
    if (room.rime?.orrery != null) {
      if (hasStar(room.rime!.starIndex!)) return null;
      return 'The Standing Orrery — its star-blocks sit off their sockets';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Rime Head — the shaft drops away below'
          : 'The Rime Head — old ice has sealed the floor over';
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
        0 => 'The blocks are frozen sky — stone will not carry them',
        1 =>
          'Glaze a road and a block runs it to the end; a kerbed socket '
              'catches whatever slides in',
        _ =>
          'Lay the run one cell short of the turn: the block stops where '
              'the glass does, and a socket takes it whether it is glazed or '
              'not. Mind your own footing — glass carries you too',
      });
      return;
    }
    if (room.rime?.mirrors != null) {
      _setInsightHint(switch (tier) {
        0 => 'Frost holds a picture in the glass, but not for long',
        1 =>
          'The ring wants every frame showing at once — and one frame '
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
        'The lens wants the chart read first — and a steady, '
        'cold-laying hand on the mount',
      );
      return;
    }
    // Anywhere in the shaft, insight reads the SHAFT — which is the planet.
    _setInsightHint(switch (tier) {
      0 => 'What goes down here does not come back the same way',
      1 =>
        'Fresh snow brakes a fall onto a ledge and is gone; frost turns '
            'the same fall into steps you can climb — one or the other',
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
    _renderFlueMouths(canvas, room);
    _renderOrrery(canvas, room);
    _renderMirrorRing(canvas, room);
    _renderShaftObjects(canvas, room);
  }

  void _renderFlueMouths(Canvas canvas, DungeonRoom room) {
    for (final f in kRimeFlues) {
      if (f.headRoom != room.id) continue;
      if (room.id == layout.entranceRoomId && !entryDoorRevealed) continue;
      final r = Rect.fromCenter(center: f.headPos, width: 118, height: 84);
      final state = f.isThroat && rimefallFrozen
          ? RimeFlueState.stair
          : _flue(f.id);
      switch (state) {
        case RimeFlueState.drift:
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(16)),
            Paint()..color = _kIceWhite.withValues(alpha: 0.5),
          );
          // Heaped snow: three soft mounds, no blur.
          for (var i = 0; i < 3; i++) {
            canvas.drawCircle(
              r.centerLeft + Offset(24.0 + i * 34, 6 - i.isEven.toInt() * 5),
              16,
              Paint()..color = Colors.white.withValues(alpha: 0.34),
            );
          }
        case RimeFlueState.scoured:
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(10)),
            Paint()..color = _kIceDeep.withValues(alpha: 0.86),
          );
          canvas.drawLine(
            r.topLeft + const Offset(14, 12),
            r.bottomRight - const Offset(14, 12),
            Paint()
              ..color = _kIcePale.withValues(alpha: 0.5)
              ..strokeWidth = 2,
          );
        case RimeFlueState.stair:
          // Cut steps: four hard-edged treads with a specular lip.
          for (var i = 0; i < 4; i++) {
            final t = Rect.fromLTWH(
              r.left + 8 + i * 6.0,
              r.top + 10 + i * 16.0,
              r.width - 16 - i * 12.0,
              13,
            );
            canvas.drawRect(
              t,
              Paint()..color = _kIceWhite.withValues(alpha: 0.72),
            );
            canvas.drawLine(
              t.topLeft,
              t.topRight,
              Paint()
                ..color = Colors.white.withValues(alpha: 0.9)
                ..strokeWidth = 1.6,
            );
          }
      }
    }
  }

  void _renderOrrery(Canvas canvas, DungeonRoom room) {
    final g = room.rime?.orrery;
    if (g == null) return;
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        final rect = g.rectAt(c, r).deflate(3);
        final ch = g.art[r][c];
        if (ch == '#') {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(8)),
            Paint()..color = const Color(0xFF2B3A45),
          );
          continue;
        }
        if (ch == 'S') {
          canvas.drawCircle(
            rect.center,
            rect.width * 0.34,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = const Color(0xFFE4C16A).withValues(alpha: 0.8),
          );
        }
        if (_orreryGlazed(g, c, r)) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(6)),
            Paint()..color = _kIcePale.withValues(alpha: 0.34),
          );
          canvas.drawLine(
            rect.topLeft + const Offset(8, 8),
            rect.bottomRight - const Offset(8, 8),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.4)
              ..strokeWidth = 1.4,
          );
        }
      }
    }
    for (final e in orreryBlocks.entries) {
      final c = e.value % g.cols;
      final r = e.value ~/ g.cols;
      final p = g.centerAt(c, r);
      final seated = orrerySeated.contains(e.key);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 52, height: 52),
          const Radius.circular(8),
        ),
        Paint()
          ..color = seated
              ? const Color(0xFFE4C16A).withValues(alpha: 0.8)
              : _kIceWhite.withValues(alpha: 0.82),
      );
      _drawStarGlyph(canvas, p, 12, seated ? Colors.white : _kIceDeep);
    }
  }

  void _renderMirrorRing(Canvas canvas, DungeonRoom room) {
    final ring = room.rime?.mirrors;
    if (ring == null) return;
    // The pool. It is a MIRROR, and what it shows is the whole clue layer for
    // the vault: the shelf's glow hangs in the reflected shaft, though the
    // wall itself is blank (§5.5 — "visible only in a mirror"). Wordless.
    canvas.drawCircle(
      ring.center,
      ring.radius - 34,
      Paint()..color = const Color(0xFF0B1A22).withValues(alpha: 0.85),
    );
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
    for (var i = 0; i < ring.count; i++) {
      final p = ring.frameAt(i);
      final lode = i == ring.lodestoneIndex;
      final showing = lode ? lodestoneLit : silveredMirrors.contains(i);
      final frame = Rect.fromCenter(center: p, width: 46, height: 66);
      canvas.drawRRect(
        RRect.fromRectAndRadius(frame, const Radius.circular(5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF6E5A34),
      );
      if (!showing) {
        canvas.drawRect(
          frame.deflate(4),
          Paint()
            ..color = (lode ? Colors.black : _kIceDeep).withValues(alpha: 0.8),
        );
        continue;
      }
      canvas.drawRect(
        frame.deflate(4),
        Paint()
          ..color = (lode ? const Color(0xFFFFF0C4) : _kIceWhite).withValues(
            alpha: 0.8,
          ),
      );
      // The thaw is READ off the frame, not off a line of prose: the silver
      // drains from the bottom as the hold runs out.
      if (!lode) {
        final left = ((mirrorThaw[i] ?? 0) / _kMirrorHoldSeconds).clamp(
          0.0,
          1.0,
        );
        final inner = frame.deflate(4);
        canvas.drawRect(
          Rect.fromLTWH(
            inner.left,
            inner.bottom - inner.height * (1 - left),
            inner.width,
            inner.height * (1 - left),
          ),
          Paint()..color = _kIceDeep.withValues(alpha: 0.7),
        );
      }
    }
  }

  void _renderShaftObjects(Canvas canvas, DungeonRoom room) {
    final ice = room.rime;
    if (ice == null) return;
    final cap = ice.iceCap;
    if (cap != null && !entryDoorRevealed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: cap, width: 132, height: 46),
          const Radius.circular(10),
        ),
        Paint()..color = const Color(0xFF0A1620).withValues(alpha: 0.92),
      );
      canvas.drawLine(
        cap - const Offset(50, 0),
        cap + const Offset(50, 0),
        Paint()
          ..color = _kIcePale.withValues(alpha: 0.45)
          ..strokeWidth = 2,
      );
    }
    final fall = ice.rimefall;
    if (fall != null) {
      final r = Rect.fromCenter(center: fall, width: 108, height: 132);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(12)),
        Paint()
          ..color = (rimefallFrozen ? _kIceWhite : _kIcePale).withValues(
            alpha: rimefallFrozen ? 0.78 : 0.4,
          ),
      );
      if (!rimefallFrozen) {
        // Running water: three streaks that scroll, cheap and blur-free.
        for (var i = 0; i < 3; i++) {
          final y = r.top + ((_time * 90 + i * 44) % r.height);
          canvas.drawLine(
            Offset(r.left + 20 + i * 30, y),
            Offset(r.left + 20 + i * 30, y + 22),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.5)
              ..strokeWidth = 2.4,
          );
        }
      }
    }
    final font = ice.coldFont;
    if (font != null) {
      canvas.drawCircle(
        font,
        26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = ((conduitEnergy['B'] ?? 0) > 0 ? Colors.white : _kIcePale)
              .withValues(alpha: 0.8),
      );
    }
    final pillar = ice.hoarfrost;
    if (pillar != null) {
      final r = Rect.fromCenter(center: pillar, width: 44, height: 96);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(8)),
        Paint()
          ..color = hoarfrostWhole
              ? _kIceWhite.withValues(alpha: 0.85)
              : const Color(0xFF35505E).withValues(alpha: 0.6),
      );
    }
    final lens = ice.telescope;
    if (lens != null && !discoveredClouds.contains(kIceStarWalkerEggId)) {
      canvas.drawLine(
        lens + const Offset(-26, 20),
        lens + const Offset(26, -22),
        Paint()
          ..color = const Color(0xFF6E5A34)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    }
  }
}

extension on bool {
  int toInt() => this ? 1 : 0;
}
