// lib/games/planet_dungeon/planet_dungeon_game_dust.dart
//
// SABLIS — the Ruins of Time. Dust's puzzle logic + rendering, as a
// `part of planet_dungeon_game.dart` (the treatment every planet after the Air
// pilot gets). The layout, the city graph, the drift yard and the whole
// conservation ledger live in planet_dungeon_layout_dust.dart; this file is
// the rules that drive them.
//
// World rule: *nothing perishes here — dig, and the dust must go somewhere.*
// See the layout file's header for the full statement of the mound trade
// (bared / buried / drifted), the vault trick, and the ledger invariant.
//
//  • Entry — the gate arch is silted to the springing. DUST parts its own
//    element and the city's mouths open (§5.5, the eased entry reveal).
//  • Star 0 (Seal) — THE THREE SEALS, on the seal street. The survey yard is
//    the planet's verb at spade scale: DIG (Dust or Earth) bites the cell in
//    front and throws the spoil over your shoulder; SCOUR (Air) blows the top
//    load off the cell underfoot one square downwind. The yard is authored one
//    load short of full, so every spadeful wants to land on a seal you already
//    cleared. ELEMENT-ONLY, all three elements used: this is the star §4
//    guarantees to any trio of the right elements.
//  • Star 1 (Armillary) — THE OBSERVATORY, under the roof walk. Its roof is
//    the street's only bridge to the court; strip it and the bridge is gone,
//    but the sky comes down and the great armillary can be read at last. The
//    instrument stands on an island across a ROOFLESS SPAN: Air+WING is the
//    marquee gate (§6 "Airwing can cross what the dig destroyed").
//  • Rite (Hourglass Court) — conduit A is Earth+HORN through the false wall
//    (the second gate); the great glass is element-only Dust.
//  • Star 2 (Ash) — MYS10 ASHDJINN. §7: the guardian fights WITH the planet's
//    rule. It rides a rolling sandstorm that shovels the hollow's bank back
//    into your open cut and reaches out into the city to re-bury one of your
//    digs. Its lull exists only while the excavation is held open.
//  • Lost Maxim — NOTHING PERISHES: sweep away (Air) EVERY ancient footprint.
//    A print only shows while its mound is bared, and conservation caps you at
//    two bared mounds at once, so the four of them cannot be done in one pass.
//
// NON-STRANDABILITY (the design's one real danger — see `solveBuriedCity`):
// every dig takes TWO street crossings away and gives one cellar back, which
// is a stranding machine. THE LEVELLING WIND is the valve: an Air creature
// winds any of the city's iron vanes, touches it again, and the sirocco puts
// every load back where Sablis has always kept it. Costly (every cellar, every
// ramp, every spadeful of the yard), always available, and it is what
// `solveBuriedCity().strandable == 0` rests on — 319 of the same 396 states
// are strandable with it deleted.

part of 'planet_dungeon_game.dart';

/// Dust's lost maxim discovery id (the screen pays 20 gold on first find).
const String kDustNothingPerishesEggId = 'egg:dust_nothing_perishes';

// ── Device-tunable knobs ───────────────────────────────────
// Dust has never been on a device; every number the feel depends on is named
// here so a tuning pass is edit-one-block.

/// How close a creature must stand to a mound crown, a vane, the silted arch,
/// the armillary, the glass or the hollow's cut to act on it.
const double _kRuinsReach = 70.0;

/// Seconds a wound vane stays armed for its second touch. The sirocco is the
/// most expensive verb on the planet, so it is never one careless press: the
/// first touch winds the vane and says what it will cost.
const double _kVaneArmSeconds = 4.0;

/// Dust wisps a gust kicks out of the ruins (the seal yard's one consequence).
/// The spade is quiet; the wind is loud, and something in the ash notices.
const int _kScourWisps = 1;

/// Seconds Ashdjinn's shattered cut stays unworkable after a storm beat. Zero:
/// the cut is re-dug by hand and the fight's tempo IS that errand. Kept named
/// so a device pass can add a beat if it plays too busy.
const double _kHollowSettle = 0.0;

extension RuinsOfTimeDungeon on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetRuinsState() {
    if (!_isRuins) return;
    // A death re-buries nothing and un-digs nothing by itself — the city is
    // puzzle state like every other planet's, so it resets with the run.
    ruins.reset();
  }

  // ── The city graph ───────────────────────────────────────

  /// The mound whose paving carries this door, and which leg it is: the street
  /// CROSSING, the hole down into its CELLAR, the climb up its RAMP, or the
  /// PRESSED crack it opens in the undercity. Null when the door is not part
  /// of the city's mutable fabric (the drift tunnels, the rite wing, and the
  /// sunken house's one way out — see the layout header).
  (DustMound, String)? _moundLeg(DungeonRoom room, DungeonDoor door) {
    for (final m in kDustMounds) {
      final to = door.targetRoomId;
      if (m.crossFrom == room.id && m.crossTo == to) return (m, 'cross');
      if (m.crossTo == room.id && m.crossFrom == to) return (m, 'cross');
      if (m.roomId == room.id && m.cellarRoomId == to) return (m, 'cellar');
      // The climb back out is the same hole: fill it in and it is not there
      // any more. A cellar is still never a trap, because the drift tunnels
      // below it never close.
      if (m.cellarRoomId == room.id && m.roomId == to) return (m, 'cellar');
      if (m.roomId == room.id && m.rampRoomId == to) return (m, 'ramp');
      if (m.rampRoomId == room.id && m.roomId == to) return (m, 'ramp');
      // The vault crack is ENTRY-ONLY. The way back out of the sunken house is
      // never blocked, whatever happens to the bump behind you (Ice's shelf
      // rule) — which is exactly what keeps the vault from being a trap.
      if (m.pressedRoomId == to && room.id == 'undercity') {
        return (m, 'pressed');
      }
    }
    return null;
  }

  /// A mound's paving is ONE square, but the engine sees up to three doors on
  /// it (the crossing, the cellar hole, the ramp). Exactly which of them exist
  /// is the mound's load count, so the ground reads as one place that becomes
  /// three different things. The whole gate floor also stays shut until Dust
  /// parts the silted arch.
  bool _ruinsDoorHidden(DungeonRoom room, DungeonDoor door) {
    if (!_isRuins) return false;
    if (room.id == layout.entranceRoomId && !entryDoorRevealed) {
      // The arch is silted: every way out of this room is buried with it.
      return true;
    }
    final leg = _moundLeg(room, door);
    if (leg == null) return false;
    final (mound, which) = leg;
    return switch (which) {
      // The cellar is a hole you made. Before you make it there is no hole.
      'cellar' => ruins.stateOf(mound.id) != MoundState.bared,
      // A ramp is a dune. Before you raise it there is nothing to climb.
      'ramp' => ruins.stateOf(mound.id) != MoundState.drifted,
      // The crack in the party wall only exists under the weight.
      'pressed' => ruins.stateOf(mound.id) != MoundState.drifted,
      _ => false,
    };
  }

  /// A street crossing is walkable only while its mound is plainly BURIED: a
  /// pit stops a foot and so does a dune. This is the conservation cost made
  /// physical — every dig closes two of these.
  bool _ruinsDoorBlocked(DungeonRoom room, DungeonDoor door) {
    if (!_isRuins) return false;
    final leg = _moundLeg(room, door);
    if (leg == null) return false;
    final (mound, which) = leg;
    if (which != 'cross') return false;
    return ruins.stateOf(mound.id) != MoundState.buried;
  }

  /// One short clause naming exactly what is missing (§5.6 BLOCKED) — never a
  /// method. How the ground got this way is the city's earned reading (Mask).
  String _ruinsDoorHint(DungeonRoom room, DungeonDoor door) {
    final (mound, _) = _moundLeg(room, door)!;
    return switch (ruins.stateOf(mound.id)) {
      MoundState.bared => 'Open trench, the paving that crossed here is gone',
      MoundState.drifted => 'A dune stands over the street, crest to crest',
      MoundState.buried => 'The way is clear',
    };
  }

  // ── Verbs ────────────────────────────────────────────────

  /// Every Dust verb, in priority order. Returns true when one was consumed.
  bool _tryRuinsVerb(DungeonCreature a) {
    if (!_isRuins) return false;
    return _tryGateSilt(a) ||
        _tryHollowCut(a) ||
        _tryWindVane(a) ||
        _tryFootprint(a) ||
        _tryArmillary(a) ||
        _tryGlassCourt(a) ||
        _tryMoundDig(a) ||
        _tryDriftYard(a);
  }

  /// The entry rite: Dust parts the silt choking the gate arch.
  bool _tryGateSilt(DungeonCreature a) {
    final pos = currentRoom.ruins?.gateSilt;
    if (pos == null || entryDoorRevealed) return false;
    if ((a.position - pos).distance > _kRuinsReach) return false;
    if (a.member.element != 'Dust') {
      _setBlockedHint('Only Dust parts its own drift');
      return true;
    }
    entryDoorRevealed = true;
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist it
    _setHint('The silt runs off the arch, Sablis opens its mouths');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Dust',
      reagentElements: const ['Earth', 'Air'],
      particleCount: 30,
      intensity: 1.25,
    );
    return true;
  }

  /// THE LEVELLING WIND — the anti-strand valve, in two touches.
  ///
  /// The first winds the vane and says the price out loud; the second calls
  /// the sirocco. Element-only Air: a party without the ideal trio still has
  /// to be able to undo itself.
  bool _tryWindVane(DungeonCreature a) {
    final pos = currentRoom.ruins?.windVane;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kRuinsReach) return false;
    if (a.member.element != 'Air') {
      _setBlockedHint('Only Air turns this vane');
      return true;
    }
    if (ruins.isLevelled) {
      _setBlockedHint('The vane swings free, the city already lies even');
      return true;
    }
    if (ruins.armedVaneRoom != currentRoomId) {
      ruins.armedVaneRoom = currentRoomId;
      ruins.armedVaneTimer = _kVaneArmSeconds;
      // Attempt-edged and explicit: the most expensive verb on the planet
      // never fires on one careless press.
      _setHint(
        'The vane winds up. Touch it again and the sirocco takes back every '
        'spadeful you have moved',
        _kVaneArmSeconds,
      );
      return true;
    }
    ruins.levelCity();
    _setHint(
      'The sirocco comes down the streets, every trench filled, every dune '
      'gone, the city as its dead left it',
      4.6,
    );
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Dust',
      reagentElements: const ['Air'],
      particleCount: 44,
      intensity: 1.4,
    );
    return true;
  }

  /// One spadeful of the buried city — the planet's whole grammar.
  ///
  /// You dig the mound you are standing at and throw its load onto the
  /// neighbour you are FACING, so the decision (which of my neighbours do I
  /// bury?) is made with the body, exactly where the consequence lands.
  bool _tryMoundDig(DungeonCreature a) {
    for (final m in dustMoundsIn(currentRoomId)) {
      if ((a.position - m.streetPos).distance > _kRuinsReach) continue;
      if (!_ruinsHasSpade(a)) {
        _setBlockedHint('Only Dust or Earth shifts a mound');
        return true;
      }
      switch (ruins.stateOf(m.id)) {
        case MoundState.bared:
          _setBlockedHint(
            'Scraped to the flags already, there is nothing '
            'here to move',
          );
          return true;
        case MoundState.drifted:
          _setBlockedHint(
            'Packed hard under its own weight, no spade bites '
            'this',
          );
          return true;
        case MoundState.buried:
          break;
      }
      final target = _facingMound(a, m);
      if (target == null) {
        _setBlockedHint('Nowhere to throw it that way');
        return true;
      }
      if (!ruins.canDig(m.id, target.id)) {
        _setBlockedHint('That heap will not take another load');
        return true;
      }
      ruins.dig(m.id, target.id);
      _setHint(_moundDigLine(m, target));
      _spawnAlchemyBurst(
        m.streetPos,
        producedElement: 'Dust',
        reagentElements: [a.member.element],
        particleCount: 24,
      );
      _spawnAlchemyBurst(
        target.roomId == currentRoomId ? target.streetPos : m.streetPos,
        producedElement: 'Dust',
        reagentElements: const ['Earth'],
        particleCount: 14,
      );
      return true;
    }
    return false;
  }

  /// The planet's verb is element-only Dust-or-Earth (§4). Air+Earth→Dust is
  /// the authored recipe (§6) and stands in as a BRAID — two bodies at the
  /// same square — for a party whose Dust hand is down.
  bool _ruinsHasSpade(DungeonCreature a) {
    final el = a.member.element;
    if (el == 'Dust' || el == 'Earth') return true;
    if (el != 'Air') return false;
    return creatures.any(
      (c) =>
          !identical(c, a) &&
          c.alive &&
          c.member.element == 'Earth' &&
          (c.position - a.position).distance < 150,
    );
  }

  /// The neighbouring mound the body is pointed at. Aim decides where the
  /// spoil lands, so the trade is made with the joystick, not a menu.
  DustMound? _facingMound(DungeonCreature a, DustMound from) {
    final aim = Offset(cos(a.aimAngle), sin(a.aimAngle));
    DustMound? best;
    var bestDot = 0.0;
    for (final id in from.neighbours) {
      final n = dustMoundById(id);
      if (n == null) continue;
      // A neighbour in another room is aimed at through the wall it lies
      // behind: use the direction from THIS mound to that room's door-ward
      // side, approximated by the mound's own crown in city space.
      final delta = _moundBearing(from, n);
      if (delta.distance < 1) continue;
      final dot =
          (delta / delta.distance).dx * aim.dx +
          (delta / delta.distance).dy * aim.dy;
      if (dot > bestDot) {
        bestDot = dot;
        best = n;
      }
    }
    // A loose cone: the player must MEAN a direction, not thread a needle.
    return bestDot >= 0.35 ? best : null;
  }

  /// Direction from one mound to another in CITY space. Sablis's five squares
  /// run west to east in the order they are authored, with the terrace above
  /// the line, so the bearing is derived from that order rather than from
  /// per-room pixels (which live in different coordinate spaces).
  Offset _moundBearing(DustMound from, DustMound to) {
    Offset place(DustMound m) => switch (m.id) {
      'm_gate' => const Offset(0, 1),
      'm_agora' => const Offset(1, 1),
      'm_roof' => const Offset(2, 1),
      'm_bump' => const Offset(3, 1),
      _ => const Offset(2, 0), // the terrace, above the line
    };
    return place(to) - place(from);
  }

  String _moundDigLine(DustMound from, DustMound to) {
    if (to.pressedRoomId != null) {
      return 'The bump takes the spoil and settles. Somewhere below, old '
          'brick gives';
    }
    if (to.rampRoomId != null) {
      return 'The heap crests over the street, and leans against the terrace '
          'wall';
    }
    if (from.cellarRoomId != null) {
      return 'The flags come up, and a dark room opens under your feet';
    }
    return 'The trench opens, and the street beyond it goes under';
  }

  // ── Star 0 · THE THREE SEALS ─────────────────────────────

  DriftField? get _yard => currentRoom.ruins?.field;

  /// The yard room, wherever it is (the solver reads it without walking).
  DungeonRoom? get _yardRoom {
    for (final r in layout.rooms.values) {
      if (r.ruins?.field != null) return r;
    }
    return null;
  }

  (int, int)? _yardCellAt(DriftField g, Offset p) {
    final c = ((p.dx - g.origin.dx) / g.cell).floor();
    final r = ((p.dy - g.origin.dy) / g.cell).floor();
    if (!g.inBounds(c, r)) return null;
    return (c, r);
  }

  /// The quarter a creature is facing, as a grid step. Both yard verbs act on
  /// the cell IN FRONT of you (Steam's `_targetCell` convention, and Ice's
  /// orrery): one unambiguous target means a gust never eats a spadeful you
  /// meant, and it keeps the geometry legible on a phone.
  (int, int) _yardFacing(DungeonCreature a) {
    final dx = cos(a.aimAngle);
    final dy = sin(a.aimAngle);
    return dx.abs() >= dy.abs()
        ? (dx >= 0 ? (1, 0) : (-1, 0))
        : (dy >= 0 ? (0, 1) : (0, -1));
  }

  bool _tryDriftYard(DungeonCreature a) {
    final g = _yard;
    final idx = currentRoom.ruins?.starIndex;
    if (g == null || idx == null || hasStar(idx)) return false;
    final here = _yardCellAt(g, a.position);
    if (here == null) return false;
    if (!g.isGround(here.$1, here.$2)) {
      _setBlockedHint('Broken column, nothing rests here');
      return true;
    }
    final step = _yardFacing(a);
    final fc = here.$1 + step.$1;
    final fr = here.$2 + step.$2;
    final bc = here.$1 - step.$1;
    final br = here.$2 - step.$2;
    final el = a.member.element;

    // SCOUR (Air): the load underfoot goes one square downwind. The only verb
    // on the planet that takes the crest off a dune.
    if (el == 'Air') {
      if (!g.isGround(fc, fr)) {
        _setBlockedHint('The gust has nowhere to lay it');
        return true;
      }
      final from = here.$2 * g.cols + here.$1;
      final to = fr * g.cols + fc;
      if (!ruins.scourDrift(from, to)) {
        _setBlockedHint(
          ruins.driftAt(from) < 1
              ? 'Bare flags, the wind finds nothing to lift'
              : 'That square is heaped as high as it goes',
        );
        return true;
      }
      // THE CONSEQUENCE (§7, one per star): a spade is quiet, a gust is not.
      spawnWispWave(
        element: 'Dust',
        center: g.centerAt(fc, fr),
        count: _kScourWisps,
        unstable: true,
        announce: false,
      );
      _spawnAlchemyBurst(
        g.centerAt(fc, fr),
        producedElement: 'Dust',
        reagentElements: const ['Air'],
        particleCount: 12,
      );
      _checkSealStar();
      return true;
    }

    // DIG (Dust or Earth): bite the cell in front, throw over the shoulder.
    if (!_ruinsHasSpade(a)) return false;
    if (!g.isGround(fc, fr)) {
      _setBlockedHint('Nothing to bite there');
      return true;
    }
    if (!g.isGround(bc, br)) {
      _setBlockedHint('No room behind you for the spoil');
      return true;
    }
    final from = fr * g.cols + fc;
    final to = br * g.cols + bc;
    if (!ruins.digDrift(from, to)) {
      _setBlockedHint(
        ruins.driftAt(from) == 0
            ? 'Bare flags already'
            : ruins.driftAt(from) > 1
            ? 'Packed hard, a spade will not bite a dune'
            : 'The square behind you will not take another load',
      );
      return true;
    }
    _spawnAlchemyBurst(
      g.centerAt(fc, fr),
      producedElement: 'Dust',
      reagentElements: [a.member.element],
      particleCount: 12,
    );
    _checkSealStar();
    return true;
  }

  void _checkSealStar() {
    final room = _yardRoom;
    final idx = room?.ruins?.starIndex;
    if (idx == null || hasStar(idx)) return;
    if (!ruins.sealsBare) return;
    _setHint('Three bronzes bare at once, the old city admits its names');
    earnStar(idx);
  }

  // ── Star 1 · THE OBSERVATORY ─────────────────────────────

  /// The armillary, across the roofless span. Two things have to be true: the
  /// roof above must be OFF (the instrument reads sky, and the only sky in
  /// Sablis is the hole you made), and the hand on it must be a Wing, because
  /// the island is across a span nothing walks (§6, and the §4 marquee gate).
  bool _tryArmillary(DungeonCreature a) {
    final pos = currentRoom.ruins?.armillary;
    final idx = currentRoom.ruins?.starIndex;
    if (pos == null || idx == null || hasStar(idx)) return false;
    if ((a.position - pos).distance > _kRuinsReach) return false;
    if (ruins.stateOf('m_roof') != MoundState.bared) {
      // A GOAL, not a method (§5.6): what is missing, in one clause.
      _setBlockedHint('The rings turn on nothing, this room has no sky');
      return true;
    }
    // VERB-ONLY: the rings turn on a bared roof, and what this asks for is
    // somebody off the ground above them. Air the ELEMENT does nothing here
    // that any other wing could not — so any wing answers.
    final req = const DungeonInteractionRequirement(
      element: kAnyElement,
      requiredFamily: DungeonAbility.aerialTraversal,
    );
    switch (evaluateInteraction(a.member, req)) {
      case InteractionResult.passed:
      case InteractionResult.passedViaRecipe:
        _setHint('The rings come round to the open roof, and hold there');
        _spawnAlchemyBurst(
          pos,
          producedElement: 'Air',
          reagentElements: const ['Dust'],
          particleCount: 34,
          intensity: 1.3,
        );
        earnStar(idx);
      case InteractionResult.blockedFamily:
        // "The seal remembers" (§4): the chip stamps on first refusal.
        final gate = layout.familyGateFor('armillary');
        if (gate != null) {
          _stampFamilyGate(gate);
        } else {
          _setBlockedHint('Only Air borne on wings crosses a roofless span');
        }
      case InteractionResult.blockedElement:
      case InteractionResult.blockedStat:
        _setBlockedHint('The rings are seized with grit, they answer Air');
    }
    return true;
  }

  // ── The rite · THE HOURGLASS COURT ───────────────────────

  /// The rite's second half — element-only Dust, so a party missing the Horn
  /// meets exactly ONE refusal in this court rather than two.
  bool _tryGlassCourt(DungeonCreature a) {
    final pos = currentRoom.ruins?.glassCourt;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kRuinsReach) return false;
    if ((conduitEnergy['B'] ?? 0) > 0) return false;
    if (a.member.element != 'Dust') {
      _setBlockedHint('The glass answers Dust alone');
      return true;
    }
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'The glass will not turn, it answers only a bearer of the '
        '${layout.starName(0)} and ${layout.starName(1)}',
      );
      return true;
    }
    conduitEnergy['B'] = double.infinity;
    _setHint('The great glass turns over, and the court begins to run');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Dust',
      reagentElements: const ['Earth'],
      particleCount: 30,
      intensity: 1.2,
    );
    return true;
  }

  // ── Star 2 · ASHDJINN'S EXCAVATION ───────────────────────

  /// The fight's verb: throw the storm's spoil back out of the open cut.
  bool _tryHollowCut(DungeonCreature a) {
    final pos = currentRoom.ruins?.hollowCut;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kRuinsReach) return false;
    if (ruins.hollowOpen) return false;
    if (_hollowSettle > 0) {
      _setBlockedHint('The sand is still running back in');
      return true;
    }
    if (!_ruinsHasSpade(a)) {
      _setBlockedHint('Only Dust or Earth clears this cut');
      return true;
    }
    ruins.clearHollow();
    _setHint(
      ruins.hollowOpen
          ? 'The cut is open again, and the djinn slows to look into it'
          : 'A load out, and more of it still to move',
    );
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Dust',
      reagentElements: [a.member.element],
      particleCount: 20,
    );
    return true;
  }

  /// §7 — the guardian fights WITH the planet's rule. Ashdjinn's lull only
  /// opens while the excavation is held bare; every strike beat shovels the
  /// bank back into the cut AND reaches into the city to undo one of your
  /// digs. It re-buries your work while you fight it, and — conservation
  /// holding throughout — the load it moves is the same load you moved.
  void _updateAshdjinn(DungeonRoom room, double dt) {
    if (room.guardian == null || !guardianAwake) return;
    if (!ruins.hollowOpen) {
      guardianVulnerable = false;
      return;
    }
    if (guardianVulnerable && !_ashdjinnBitLastFrame) {
      // The window opened: the storm answers by filling the cut back in.
      _ashdjinnBitLastFrame = true;
      return;
    }
    if (!guardianVulnerable && _ashdjinnBitLastFrame) {
      _ashdjinnBitLastFrame = false;
      ruins.buryHollow();
      _hollowSettle = _kHollowSettle;
      final undone = ruins.undoOneDig();
      _setHint(
        undone == null
            ? 'The storm rolls over the cut and fills it'
            : 'The storm rolls out over the streets, and one of your trenches '
                  'is street again',
      );
    }
  }

  // ── The Lost Maxim · NOTHING PERISHES ────────────────────

  /// The ancient footprints. Deliberately beyond what the stars demand
  /// (§ "Easter eggs"): a print shows only while its mound is BARED, and
  /// conservation caps you at two bared mounds at once, so the four of them
  /// cannot be swept without spending at least one sirocco in between.
  bool _tryFootprint(DungeonCreature a) {
    if (discoveredClouds.contains(kDustNothingPerishesEggId)) return false;
    for (final m in dustMoundsIn(currentRoomId)) {
      final pos = m.footprintPos;
      if (pos == null) continue;
      if (ruins.sweptPrints.contains(m.id)) continue;
      if (ruins.stateOf(m.id) != MoundState.bared) continue;
      if ((a.position - pos).distance > _kRuinsReach) continue;
      if (a.member.element != 'Air') {
        _setBlockedHint('Only Air lifts a print off the flags');
        return true;
      }
      ruins.sweptPrints.add(m.id);
      final total = kDustMounds.where((x) => x.footprintPos != null).length;
      if (ruins.sweptPrints.length < total) {
        _setHint(
          'The print goes out from under the broom, and the flags are '
          'blank',
        );
        return true;
      }
      // THE RITE OF THREE pays this out (see `beginMaximRite`).
      beginMaximRite(kDustNothingPerishesEggId, pos);
      _spawnAlchemyBurst(
        pos,
        producedElement: 'Air',
        reagentElements: const ['Dust', 'Earth'],
        particleCount: 40,
        intensity: 1.4,
      );
      return true;
    }
    return false;
  }

  // ── Per-frame ────────────────────────────────────────────

  void _updateRuins(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isRuins) return;
    if (ruins.armedVaneTimer > 0) {
      ruins.armedVaneTimer = max(0.0, ruins.armedVaneTimer - dt);
      if (ruins.armedVaneTimer == 0) ruins.armedVaneRoom = null;
    }
    if (_hollowSettle > 0) _hollowSettle = max(0.0, _hollowSettle - dt);
    _updateAshdjinn(room, dt);
  }

  // ── Readouts, hints, insight (§5.6) ──────────────────────

  /// STATE LEAVES THE CAPSULE (§5.6): the counters live beside the star
  /// tracker, per room, never as prose that fades.
  DungeonProgressReadout? _ruinsProgressReadout() {
    final room = layout.rooms[currentRoomId];
    final yard = room?.ruins?.field;
    if (yard != null && !hasStar(room!.ruins!.starIndex!)) {
      final bare = yard.sealIndices.where((i) => ruins.driftAt(i) == 0).length;
      return DungeonProgressReadout(
        label: 'SEALS',
        value: '$bare/${yard.sealIndices.length} bare',
        fraction: bare / yard.sealIndices.length,
      );
    }
    if (room?.ruins?.hollowCut != null) {
      return DungeonProgressReadout(
        label: 'CUT',
        value: ruins.hollowOpen ? 'open' : 'buried ${ruins.hollowPit}',
        fraction: 1 - ruins.hollowPit / kHollowLoads,
      );
    }
    // Everywhere else, the LEDGER — the number the whole planet is about.
    final bared = kDustMounds
        .where((m) => ruins.stateOf(m.id) == MoundState.bared)
        .length;
    return DungeonProgressReadout(
      label: 'DUG',
      value: '$bared/${kDustMounds.length}',
      fraction: bared / kDustMounds.length,
    );
  }

  /// WHAT, never HOW (§5.6). Every method here is Mask's to give.
  String? _ruinsObjectiveHint(DungeonRoom room) {
    if (room.guardian != null) {
      return 'Ashdjinn\'s Hollow, the djinn keeps the last star';
    }
    if (room.ruins?.glassCourt != null) {
      return 'The Hourglass Court, the rite waits on the glass';
    }
    if (room.ruins?.armillary != null) {
      return hasStar(room.ruins!.starIndex!)
          ? null
          : 'The Observatory, the great rings stand dark';
    }
    if (room.ruins?.field != null) {
      return hasStar(room.ruins!.starIndex!)
          ? null
          : 'The Seal Street, three bronzes lie under the drift';
    }
    if (room.vaultCache != null) {
      return 'A house nobody dug out, something is bottled here';
    }
    if (room.id == 'undercity') {
      return 'The Undercity, the drift tunnels run under every street';
    }
    if (room.ruins?.windVane != null && room.id == 'windcatch') {
      return 'The Windcatch, the tower\'s throat, and it is still breathing';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Ashen Gate, Sablis lies east, under itself'
          : 'The Ashen Gate, the arch is silted to the springing';
    }
    return null;
  }

  /// AMBIENT is flavour only (§5.6): no mechanics, no elements, no families.
  void _ruinsAmbientHint(DungeonCreature a, DungeonRoom room) {
    for (final m in dustMoundsIn(room.id)) {
      if ((a.position - m.streetPos).distance > _kRuinsReach) continue;
      _setAmbientHint(switch (ruins.stateOf(m.id)) {
        MoundState.bared => 'Cold air comes up out of the cut',
        MoundState.drifted => 'The heap ticks and slides, settling',
        MoundState.buried => 'Flagstones, and a hollow sound underfoot',
      });
      return;
    }
    final vane = room.ruins?.windVane;
    if (vane != null && (a.position - vane).distance < 100) {
      _setAmbientHint('The iron turns a little, and stops');
    }
  }

  /// INSIGHT is the only channel allowed to teach method (§5.6), and it is
  /// tiered by Intelligence.
  void _ruinsReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    if (room.ruins?.field != null) {
      _setInsightHint(switch (tier) {
        0 => 'Three bronzes under the drift, and all three must show at once',
        1 =>
          'A spade bites what is in front of you and throws it over your '
              'shoulder; a gust takes the top off the square you stand on',
        _ =>
          'The yard is one load short of full, so every throw lands on a '
              'seal you cleared. A spade will not bite a heap, only wind lifts '
              'a crest, and the west seal is boxed where no spade can reach it',
      });
      return;
    }
    if (room.ruins?.armillary != null) {
      _setInsightHint(switch (tier) {
        0 => 'The rings are cut for a sky this room has not had in an age',
        1 =>
          'It wants the roof off above it, and the island it stands on is '
              'across a span with no floor',
        _ =>
          'Strip the roof mound overhead and the sky comes down; then only '
              'a thing the ground cannot keep reaches the island',
      });
      return;
    }
    if (room.vaultCache != null || room.id == 'undercity') {
      _setInsightHint(switch (tier) {
        0 => 'Somewhere along this wall the brick is younger than the rest',
        1 => 'There is a house on the far side that nobody ever dug out',
        _ =>
          'Its wall only gives under weight: heap the bump on the roof '
              'walk, and the lintels press this partition open',
      });
      return;
    }
    // Anywhere in the ruins, insight reads the LEDGER — which is the planet.
    _setInsightHint(switch (tier) {
      0 =>
        'Nothing leaves Sablis. What comes off one square goes onto '
            'another',
      1 =>
        'A trench and a dune both stop a foot; a trench is a way down and '
            'a dune is a way up. One spadeful makes one of each',
      _ =>
        'Every dig costs you two crossings and buys one cellar, and no hand '
            'undoes it. The tower\'s vanes are the only take-backs, and the '
            'sirocco takes back all of it at once',
    });
  }

  /// Per-room sky mood — the streets are bleached, the excavation is dark.
  double get _ruinsMoodTarget => switch (currentRoomId) {
    'ashen_gate' => 0.82,
    'seal_street' || 'roof_walk' => 0.76,
    'high_terrace' => 0.86,
    'sand_court' => 0.7,
    'windcatch' => 0.34,
    'undercity' => 0.2,
    'granary' || 'kiln_cellar' => 0.24,
    'observatory' => ruins.stateOf('m_roof') == MoundState.bared ? 0.68 : 0.22,
    'sunken_house' => 0.18,
    _ => guardianAwake ? 0.4 : 0.5,
  };

  // ── THE NO-STRAND PROOF ──────────────────────────────────

  /// Exhaustive reachability over the buried city's whole state graph.
  ///
  /// A state is (which room you stand in) × (every mound's load count). Every
  /// legal move is expanded: walking any door that is open in that
  /// arrangement, digging any mound in the room you are standing in onto any
  /// legal neighbour, calling the sirocco at any of the city's vanes — and
  /// Ashdjinn's storm undoing one of your digs, which is not a move the player
  /// chooses at all. Including the storm makes the enumerated set a strict
  /// SUPERSET of what play alone can reach, and reachability is then audited
  /// using only the moves the PLAYER controls. That is the honest form of the
  /// question: from anywhere the world can put you, can you still get out.
  ///
  /// Four answers, all by construction rather than by argument:
  ///
  ///  1. `strandable` — states from which some room is no longer reachable.
  ///     **It must be zero.** "Reachable" is checked for EVERY room in the
  ///     layout, which is stronger than the brief asks: not just the exit and
  ///     the unearned stars, but the vault and both optional cellars too.
  ///  2. `strandableWithoutWind` — the same audit with the vanes deleted. It
  ///     is expected to be LARGE: the sirocco is load-bearing, not decoration,
  ///     and if this ever drops to zero someone has quietly made a dig
  ///     reversible and the planet has lost its identity.
  ///  3. `vaultLosable` — states from which the sunken house can no longer be
  ///     entered WITHOUT paying a sirocco. It must be non-zero, because that
  ///     cost is the vault trick (§5.5).
  ///  4. `conserved` — every arrangement the search ever visits still holds
  ///     exactly [kDustCityLoads]. A leak here would void everything above.
  ({
    int states,
    int arrangements,
    int strandable,
    int strandableWithoutWind,
    int vaultLosable,
    bool conserved,
  })
  solveBuriedCity() {
    final rooms = layout.rooms.keys.toList()..sort();
    final ids = [for (final m in kDustMounds) m.id];
    final start = List.filled(ids.length, 1);
    final vaneRooms = {
      for (final e in layout.rooms.entries)
        if (e.value.ruins?.windVane != null) e.key,
    };

    String enc(String room, List<int> l) => '$room|${l.join()}';
    int at(List<int> l, String id) => l[ids.indexOf(id)];

    /// Which doors are walkable in arrangement [l]. Derived from the SAME
    /// `_moundLeg` rules the engine gates real doors with, so the proof can
    /// never drift from the doors the player actually meets.
    List<String> exits(String room, List<int> l) {
      final out = <String>[];
      for (final d in layout.rooms[room]!.doors) {
        final leg = _moundLeg(layout.rooms[room]!, d);
        if (leg == null) {
          out.add(d.targetRoomId);
          continue;
        }
        final (m, which) = leg;
        final st = moundStateFor(at(l, m.id));
        final open = switch (which) {
          'cross' => st == MoundState.buried,
          'cellar' => st == MoundState.bared,
          'ramp' => st == MoundState.drifted,
          'pressed' => st == MoundState.drifted,
          _ => true,
        };
        if (open) out.add(d.targetRoomId);
      }
      return out;
    }

    List<(String, List<int>)> moves(
      String room,
      List<int> l, {
      required bool windEnabled,
      required bool storm,
    }) {
      final out = <(String, List<int>)>[];
      for (final t in exits(room, l)) {
        out.add((t, l));
      }
      for (final m in dustMoundsIn(room)) {
        if (at(l, m.id) != 1) continue;
        for (final nId in m.neighbours) {
          if (at(l, nId) > 1) continue;
          final next = [...l];
          next[ids.indexOf(m.id)] = 0;
          next[ids.indexOf(nId)] += 1;
          out.add((room, next));
        }
      }
      if (windEnabled && vaneRooms.contains(room)) {
        final level = List.filled(ids.length, 1);
        if (!_sameLoads(l, level)) out.add((layout.entranceRoomId, level));
      }
      if (storm) {
        for (final m in kDustMounds) {
          if (at(l, m.id) != 0) continue;
          for (final nId in m.neighbours) {
            if (at(l, nId) != 2) continue;
            final next = [...l];
            next[ids.indexOf(m.id)] = 1;
            next[ids.indexOf(nId)] = 1;
            out.add((room, next));
          }
        }
      }
      return out;
    }

    Set<String> reach(String room, List<int> l, {required bool windEnabled}) {
      final seen = <String>{enc(room, l)};
      final hit = <String>{room};
      final queue = [(room, l)];
      while (queue.isNotEmpty) {
        final (rm, s) = queue.removeLast();
        for (final m in moves(rm, s, windEnabled: windEnabled, storm: false)) {
          final k = enc(m.$1, m.$2);
          if (!seen.add(k)) continue;
          hit.add(m.$1);
          queue.add(m);
        }
      }
      return hit;
    }

    // Every state the world can put the party in — player moves AND the
    // storm's.
    final live = <String, (String, List<int>)>{
      enc(layout.entranceRoomId, start): (layout.entranceRoomId, start),
    };
    final queue = [(layout.entranceRoomId, start)];
    var conserved = true;
    while (queue.isNotEmpty) {
      final (rm, s) = queue.removeLast();
      if (s.fold<int>(0, (a, b) => a + b) != kDustCityLoads) conserved = false;
      for (final m in moves(rm, s, windEnabled: true, storm: true)) {
        final k = enc(m.$1, m.$2);
        if (live.containsKey(k)) continue;
        live[k] = m;
        queue.add(m);
      }
    }

    var strandable = 0;
    var without = 0;
    var vaultLosable = 0;
    final vaultRoom = layout.rooms.values
        .firstWhere((r) => r.vaultCache != null)
        .id;
    for (final st in live.values) {
      if (reach(st.$1, st.$2, windEnabled: true).length < rooms.length) {
        strandable++;
      }
      final bare = reach(st.$1, st.$2, windEnabled: false);
      if (bare.length < rooms.length) without++;
      if (!bare.contains(vaultRoom)) vaultLosable++;
    }
    return (
      states: live.length,
      arrangements: {for (final s in live.values) s.$2.join()}.length,
      strandable: strandable,
      strandableWithoutWind: without,
      vaultLosable: vaultLosable,
      conserved: conserved,
    );
  }

  bool _sameLoads(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── Rendering ────────────────────────────────────────────
  //
  // SABLIS IS A PLACE, NOT A DIAGRAM.
  //
  // VISUAL GRAMMAR (§5.5): everything here reads as a HEIGHT of dry ground —
  // never as a flooding tile (Steam) or a tide line (Water). A buried mound is
  // a patch of intact paving somebody surveyed; a bared one is an open trench
  // with its cut SECTION showing in strata; a drifted one is a crested dune
  // with a hard slip-face. No blur filters anywhere (the game's known jank
  // source).
  //
  // THE TWO DECKS MUST NOT LOOK ALIKE. This planet's premise is that the same
  // square of ground is a STREET or an EXCAVATION depending on how much dust
  // stands on it — and for that to mean anything, walking down a dig hole has
  // to feel like leaving the sky behind. So the decks are drawn as opposites:
  //
  //   • THE STREET deck is open sky. Bleached limestone paving that the wind
  //     has scoured bare in patches, sand banked in the lee of every standing
  //     thing, ripples combed across the open ground, and a broken SKYLINE of
  //     wall stubs and column drums along the far side of the room.
  //   • THE EXCAVATION deck is under the city. The far wall is a CUT FACE in
  //     strata — the section an archaeologist reads — with pit props and
  //     lagging shoring it up, oil lamps burning in niches, spoil heaps of
  //     everything that came out of the cut, and packed earth underfoot with
  //     duckboards where feet go most.
  //
  // NOTHING IS ON A GRID. Every course of paving is offset, more than half of
  // every course is missing, each flag is tilted and none of them is square.
  // The one lattice on the planet is the seal yard, which is a SURVEY — pegs
  // and chalked string over spoil — and is drawn as one.
  //
  // It is all built ONCE per room, deterministically from the room's own
  // bounds, and kept in `_ruinsGroundCache`. Only a lamp's flicker, the
  // armillary's turn and the vane's blade move per frame.

  static const Color _kDustOchre = Color(0xFFC9A96A);
  static const Color _kDustPale = Color(0xFFEBD9AE);
  static const Color _kDustDeep = Color(0xFF3A2E20);
  static const Color _kDustBronze = Color(0xFFE4C16A);

  /// Sun-bleached limestone: the city's own stone, above ground.
  static const Color _kDustStone = Color(0xFFB3A184);

  /// What the sun has not touched in an age — the cut face, the tunnel roof,
  /// the inside of a trench.
  static const Color _kDustUmber = Color(0xFF251C12);

  /// Pit-prop timber, dried out for a thousand years.
  static const Color _kDustTimber = Color(0xFF5C4527);

  /// Lamp oil burning in a niche: the only warm light below the streets.
  static const Color _kDustLamp = Color(0xFFFFC56B);

  /// Old brick, fired out of this same river mud.
  static const Color _kDustBrick = Color(0xFF6E4B33);

  void _renderRuins(Canvas canvas, DungeonRoom room) {
    final g = _ruinsGround(room);
    _renderRuinsDeck(canvas, room, g);
    _renderRuinsFabric(canvas, room, g);
    _renderRuinsPlace(canvas, room, g);
    _renderDriftYard(canvas, room, g);
    _renderMounds(canvas, room);
    _renderRuinsObjects(canvas, room);
  }

  // ── The ground the whole planet stands on ────────────────

  _RuinsGround _ruinsGround(DungeonRoom room) => _ruinsGroundCache.putIfAbsent(
    room.id,
    () => _buildRuinsGround(room),
  );

  /// THE DECK. Bed, paving, and what the wind has done to it.
  void _renderRuinsDeck(Canvas canvas, DungeonRoom room, _RuinsGround g) {
    final b = room.bounds;
    canvas.save();
    // Clipped to the stage the shared floor drew, so nothing spills past the
    // rounded lip and reads as a second, squarer room underneath.
    final stage = RRect.fromRectAndRadius(
      b.deflate(8),
      const Radius.circular(34),
    );
    canvas.clipRRect(stage);

    // THE BED. Alphas hold the FLOOR TRANSLUCENCY RULE (§8) — the sky shader
    // is the room's mood and has to keep coming through the ground.
    canvas.drawRect(
      b,
      Paint()
        ..color = (g.under ? const Color(0xFF20180F) : const Color(0xFF6B573A))
            .withValues(alpha: g.under ? 0.52 : 0.44),
    );

    // The observatory's floor is not the room: the instrument moat is cut out
    // of it, and NOTHING was drawing the ground that survives the cut — the
    // island the star stands on, and both side aisles, rendered as open void.
    // (The shared island renderer only slices a room into horizontal bands,
    // so an island in the middle of a ring of gaps is invisible to it.)
    if (g.floorCut != null) {
      canvas.drawPath(
        g.floorCut!,
        Paint()..color = const Color(0xFF4A3A26).withValues(alpha: 0.66),
      );
    }

    // PAVING. Courses offset row to row, better than half of every course
    // gone, each flag tilted and none of them square: a floor that has been
    // settling and scouring for a thousand years, not graph paper.
    final flagFill = Paint()
      ..color = (g.under ? _kDustBrick : _kDustStone).withValues(
        alpha: g.under ? 0.24 : 0.30,
      );
    final flagJoint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _kDustUmber.withValues(alpha: g.under ? 0.2 : 0.3);
    for (final f in g.flags) {
      canvas.drawPath(f, flagFill);
      canvas.drawPath(f, flagJoint);
    }

    // SAND BANKED IN THE LEE. Every standing thing on this planet has a
    // crescent of drift behind it; that is what makes the room read as a
    // place the wind has had for centuries rather than a room with sand in it.
    for (var i = 0; i < g.banks.length; i++) {
      canvas.drawPath(
        g.banks[i],
        Paint()
          ..color = (g.under ? _kDustOchre : _kDustPale).withValues(
            alpha: g.under ? 0.13 : 0.23,
          ),
      );
      // A hard wind-lip along the crest: dry sand has an angle of repose and
      // an EDGE. Wet anything does not, which is the Steam/Water separation.
      canvas.drawPath(
        g.bankLips[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: g.under ? 0.06 : 0.16),
      );
      // Combed. A bank with nothing on it is a grey amoeba, which is what the
      // first cut of these looked like from across the room.
      for (var k = 0; k < 2; k++) {
        canvas.drawPath(
          g.bankCombs[i * 2 + k],
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = _kDustUmber.withValues(alpha: g.under ? 0.10 : 0.17),
        );
      }
    }

    // RIPPLES, combed by one prevailing wind but never parallel and never
    // evenly spaced — they bunch where the ground rises and fade out over the
    // bare flags.
    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = _kDustPale.withValues(alpha: g.under ? 0.08 : 0.17);
    for (var i = 0; i < g.ripples.length; i++) {
      canvas.drawPath(g.ripples[i], ripple..strokeWidth = g.rippleWidth[i]);
    }

    // DUCKBOARDS. Below the streets the traffic is diggers' feet, and they
    // walk on planks laid over the spoil.
    for (final d in g.boards) {
      canvas.drawRect(
        d,
        Paint()..color = _kDustTimber.withValues(alpha: 0.42),
      );
      for (var x = d.left + 5; x < d.right - 3; x += 13) {
        canvas.drawLine(
          Offset(x, d.top + 1),
          Offset(x, d.bottom - 1),
          Paint()
            ..strokeWidth = 1.2
            ..color = _kDustUmber.withValues(alpha: 0.5),
        );
      }
    }
    canvas.restore();
  }

  /// THE FABRIC — the built and dug things standing round the edges of the
  /// room. Deliberately edge-weighted: a guardian arena and a five-door hub
  /// have to keep an open middle to walk and fight in (§7.9).
  void _renderRuinsFabric(Canvas canvas, DungeonRoom room, _RuinsGround g) {
    // THE FAR FACE. On the street deck it is a broken skyline of standing
    // masonry; below, it is the section: strata of everything the city has
    // dropped on itself, which is the one picture that says EXCAVATION.
    if (g.under) _renderCutFace(canvas, room, g);

    for (final s in g.stubs) {
      _drawMasonry(canvas, s.rect, s.crown, g.under);
    }

    for (final d in g.drums) {
      _drawDrum(canvas, d.at, d.r, d.lean, d.fallen);
    }

    // SHORING. Two props, a header across them, and lagging boards behind:
    // the excavation is held open by carpentry, and that is why the storm
    // filling one cut back in is frightening.
    for (final s in g.shores) {
      _drawShoring(canvas, s.at, s.w, s.h);
    }

    // SPOIL. Nothing perishes here — everything that came out of a cut is
    // still standing beside it, in a heap, with the basket it came up in.
    for (final h in g.heaps) {
      _drawSpoilHeap(canvas, h.at, h.w, h.h, h.basket);
    }

    // OIL LAMPS. The only warm light below the streets; they flicker, which
    // is the one thing in this room that costs anything per frame.
    for (var i = 0; i < g.lamps.length; i++) {
      final f = 0.82 + 0.18 * sin(_time * 5.3 + i * 2.1) * cos(_time * 2.7 + i);
      _drawLamp(canvas, g.lamps[i], f);
    }

    // SHERDS. Pot, brick-end and bone: the small stuff that tells you people
    // lived here, scattered, never in a line.
    for (final s in g.sherds) {
      canvas.save();
      canvas.translate(s.at.dx, s.at.dy);
      canvas.rotate(s.a);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: s.s * 2.4, height: s.s),
          Radius.circular(s.s * 0.4),
        ),
        Paint()
          ..color = (s.pale ? _kDustPale : _kDustBrick).withValues(alpha: 0.38),
      );
      canvas.restore();
    }
  }

  /// The section an excavation is read off: bands of tip and collapse, with a
  /// ragged lip where the diggers stopped cutting.
  void _renderCutFace(Canvas canvas, DungeonRoom room, _RuinsGround g) {
    final b = room.bounds.deflate(8);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(b, const Radius.circular(34)),
    );
    const bands = [
      (0.0, 0.26, Color(0xFF4C3A24)),
      (0.26, 0.48, Color(0xFF6A5031)),
      (0.48, 0.66, Color(0xFF3E2F1E)),
      (0.66, 0.84, Color(0xFF7B5C39)),
      (0.84, 1.0, Color(0xFF2D2214)),
    ];
    final h = g.faceHeight;
    for (final band in bands) {
      canvas.drawRect(
        Rect.fromLTRB(
          b.left,
          b.top + h * band.$1,
          b.right,
          b.top + h * band.$2,
        ),
        Paint()..color = band.$3.withValues(alpha: 0.62),
      );
    }
    // The lip is cut by hand and it wanders. A straight line here would read
    // as a wall the room was built with, not as a face somebody dug.
    canvas.drawPath(
      g.faceLip,
      Paint()..color = const Color(0xFF1B140C).withValues(alpha: 0.55),
    );
    // Charcoal and sherd flecks in the tip layer — the detail that makes a
    // band of brown read as stratigraphy.
    for (final f in g.faceFlecks) {
      canvas.drawCircle(
        f.at,
        f.r,
        Paint()
          ..color = (f.pale ? _kDustPale : Colors.black).withValues(
            alpha: f.pale ? 0.28 : 0.35,
          ),
      );
    }
    canvas.restore();
  }

  // ── The little vocabulary everything is built from ───────

  void _drawMasonry(Canvas canvas, Rect r, double crown, bool under) {
    // A cast shadow first, so the stub STANDS on the ground rather than
    // floating on it.
    canvas.drawRect(
      r.translate(5, 7),
      Paint()..color = Colors.black.withValues(alpha: 0.30),
    );
    canvas.drawRect(
      r,
      Paint()
        ..color = (under ? _kDustBrick : _kDustStone).withValues(alpha: 0.72),
    );
    // The broken top, catching whatever light there is.
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, crown),
      Paint()
        ..color = (under ? _kDustOchre : _kDustPale).withValues(alpha: 0.55),
    );
    // COURSES, two at most and neither of them reaching the ends. The first
    // cut ruled a line every eleven pixels the full width of the stub, and
    // every piece of standing masonry on the planet read as a LADDER.
    var k = 0;
    for (var y = r.top + crown + 10; y < r.bottom - 8 && k < 2; y += 17) {
      final inset = 3.0 + k * 9;
      canvas.drawLine(
        Offset(r.left + inset, y),
        Offset(r.right - inset - (k.isEven ? 0 : 11), y),
        Paint()
          ..strokeWidth = 1.0
          ..color = _kDustUmber.withValues(alpha: 0.34),
      );
      k++;
    }
    // The break: one corner of the crown is gone, which is what stops a stub
    // reading as a crate.
    canvas.drawPath(
      Path()
        ..moveTo(r.right - r.width * 0.3, r.top)
        ..lineTo(r.right, r.top)
        ..lineTo(r.right, r.top + crown * 1.6)
        ..close(),
      Paint()..color = _kDustUmber.withValues(alpha: 0.45),
    );
  }

  void _drawDrum(Canvas canvas, Offset at, double r, double lean, bool fallen) {
    if (fallen) {
      // A lying cylinder: the body, the end face, and the flutes running
      // along it. Columns in a ruin are almost always on the ground.
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(lean);
      final body = Rect.fromCenter(
        center: Offset.zero,
        width: r * 4.4,
        height: r * 1.7,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(body.translate(3, 5), Radius.circular(r * 0.5)),
        Paint()..color = Colors.black.withValues(alpha: 0.28),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(body, Radius.circular(r * 0.5)),
        Paint()..color = _kDustStone.withValues(alpha: 0.66),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(body.left + r * 0.5, 0),
          width: r * 1.0,
          height: r * 1.6,
        ),
        Paint()..color = _kDustPale.withValues(alpha: 0.42),
      );
      for (var k = -1; k <= 1; k++) {
        canvas.drawLine(
          Offset(body.left + r * 0.9, k * r * 0.45),
          Offset(body.right - r * 0.4, k * r * 0.45),
          Paint()
            ..strokeWidth = 1.0
            ..color = _kDustUmber.withValues(alpha: 0.3),
        );
      }
      canvas.restore();
      return;
    }
    // Standing: a stack of four drums seen from above and a little to the
    // side. Three drums at a third of a radius apart came out as a PANCAKE —
    // the court's whole colonnade read as a row of coins on the floor.
    canvas.drawOval(
      Rect.fromCenter(center: at.translate(5, 10), width: r * 2.4, height: r),
      Paint()..color = Colors.black.withValues(alpha: 0.26),
    );
    for (var i = 3; i >= 0; i--) {
      canvas.drawOval(
        Rect.fromCenter(
          center: at.translate(0, -i * r * 0.52),
          width: r * 2.1,
          height: r * 1.05,
        ),
        Paint()..color = _kDustStone.withValues(alpha: 0.5 + i * 0.1),
      );
      // The joint under each drum, so the shaft has courses like real stone.
      canvas.drawLine(
        at.translate(-r * 0.95, -i * r * 0.52 + r * 0.42),
        at.translate(r * 0.95, -i * r * 0.52 + r * 0.42),
        Paint()
          ..strokeWidth = 1.0
          ..color = _kDustUmber.withValues(alpha: 0.26),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: at.translate(0, -r * 1.56),
        width: r * 1.6,
        height: r * 0.8,
      ),
      Paint()..color = _kDustPale.withValues(alpha: 0.5),
    );
  }

  void _drawShoring(Canvas canvas, Offset at, double w, double h) {
    // Lagging first: the boards the props hold back.
    for (var y = at.dy - h; y < at.dy - 4; y += 9) {
      canvas.drawRect(
        Rect.fromLTWH(at.dx - w / 2, y, w, 6),
        Paint()..color = _kDustTimber.withValues(alpha: 0.34),
      );
    }
    final post = Paint()..color = _kDustTimber.withValues(alpha: 0.88);
    for (final s in [-1.0, 1.0]) {
      canvas.drawRect(
        Rect.fromLTWH(at.dx + s * (w / 2) - 4, at.dy - h, 8, h),
        post,
      );
      // The grain, and a lit inside edge so the prop has a round side.
      canvas.drawLine(
        Offset(at.dx + s * (w / 2) - 2, at.dy - h + 3),
        Offset(at.dx + s * (w / 2) - 2, at.dy - 3),
        Paint()
          ..strokeWidth = 1.4
          ..color = _kDustOchre.withValues(alpha: 0.35),
      );
    }
    // The header across the top, overhanging both props.
    canvas.drawRect(
      Rect.fromLTWH(at.dx - w / 2 - 9, at.dy - h - 8, w + 18, 9),
      post,
    );
    canvas.drawRect(
      Rect.fromLTWH(at.dx - w / 2 - 9, at.dy - h - 8, w + 18, 2.5),
      Paint()..color = _kDustOchre.withValues(alpha: 0.4),
    );
  }

  void _drawSpoilHeap(
    Canvas canvas,
    Offset at,
    double w,
    double h,
    bool basket,
  ) {
    // A heap is a cone seen from the side: a shadowed base, the body, and a
    // bright crest where the last barrowful landed.
    final path = Path()
      ..moveTo(at.dx - w / 2, at.dy)
      ..quadraticBezierTo(at.dx - w * 0.22, at.dy - h, at.dx + w * 0.05, at.dy - h)
      ..quadraticBezierTo(at.dx + w * 0.3, at.dy - h * 0.92, at.dx + w / 2, at.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFF4A3A24).withValues(alpha: 0.85),
    );
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - w * 0.34, at.dy - h * 0.52)
        ..quadraticBezierTo(
          at.dx - w * 0.1,
          at.dy - h * 1.02,
          at.dx + w * 0.06,
          at.dy - h * 0.96,
        )
        ..quadraticBezierTo(
          at.dx - w * 0.06,
          at.dy - h * 0.6,
          at.dx - w * 0.34,
          at.dy - h * 0.52,
        )
        ..close(),
      Paint()..color = _kDustOchre.withValues(alpha: 0.42),
    );
    if (!basket) return;
    // The basket it came up in, tipped on its side at the foot of the heap.
    canvas.save();
    canvas.translate(at.dx + w * 0.42, at.dy - 4);
    canvas.rotate(0.5);
    final bk = Path()
      ..moveTo(-11, -9)
      ..lineTo(11, -9)
      ..lineTo(7, 8)
      ..lineTo(-7, 8)
      ..close();
    canvas.drawPath(bk, Paint()..color = _kDustTimber.withValues(alpha: 0.8));
    canvas.drawLine(
      const Offset(-11, -9),
      const Offset(11, -9),
      Paint()
        ..strokeWidth = 2
        ..color = _kDustOchre.withValues(alpha: 0.55),
    );
    canvas.restore();
  }

  void _drawLamp(Canvas canvas, Offset at, double flicker) {
    // The niche cut into the wall it hangs in.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: at.translate(0, -2), width: 26, height: 30),
        const Radius.circular(11),
      ),
      Paint()..color = const Color(0xFF16100A).withValues(alpha: 0.85),
    );
    // A glow in three flat rings — no MaskFilter.blur anywhere on this
    // planet, and this is the shape that most wants one.
    for (var i = 3; i >= 1; i--) {
      canvas.drawCircle(
        at,
        16.0 * i * flicker,
        Paint()..color = _kDustLamp.withValues(alpha: 0.055 * flicker / i),
      );
    }
    // The lamp itself: a little clay boat with a wick alight in its nose.
    canvas.drawOval(
      Rect.fromCenter(center: at.translate(0, 3), width: 19, height: 9),
      Paint()..color = _kDustBrick.withValues(alpha: 0.95),
    );
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - 3, at.dy)
        ..quadraticBezierTo(at.dx, at.dy - 11 * flicker, at.dx + 3, at.dy)
        ..close(),
      Paint()..color = _kDustLamp.withValues(alpha: 0.95),
    );
  }

  // ── What each room actually IS ───────────────────────────

  void _renderRuinsPlace(Canvas canvas, DungeonRoom room, _RuinsGround g) {
    switch (room.id) {
      case 'ashen_gate':
        _renderAshenGate(canvas, room);
      case 'seal_street':
        _renderSealHouse(canvas, room);
      case 'roof_walk':
        _renderRoofWalk(canvas, room);
      case 'high_terrace':
        _renderHighTerrace(canvas, room);
      case 'sand_court':
        _renderHourglassCourt(canvas, room);
      case 'windcatch':
        _renderWindcatch(canvas, room);
      case 'undercity':
        _renderUndercity(canvas, room);
      case 'granary':
        _renderGranary(canvas, room);
      case 'observatory':
        _renderObservatoryRoom(canvas, room, g);
      case 'kiln_cellar':
        _renderKilnCellar(canvas, room);
      case 'sunken_house':
        _renderSunkenHouse(canvas, room, g);
      case 'ashdjinn_hollow':
        _renderHollow(canvas, room, g);
    }
  }

  /// THE ASHEN GATE. A city's mouth: two piers, the springing of an arch that
  /// no longer meets over the road, and the processional way running east out
  /// of it under the drift.
  void _renderAshenGate(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    // THE ROAD. It runs from where you arrive to the arch, and it is the one
    // thing in the room that says which way the city is.
    // KERBS, not a painted stripe. The road is the paving BETWEEN them, and
    // the kerb stones are laid one at a time and half of them are gone.
    for (final y in [232.0, 322.0]) {
      var x = b.left + 24;
      var i = 0;
      while (x < b.right - 40) {
        // Kerb STONES: set one at a time, every one a different length, and
        // a fifth of them gone. Thin even dashes read as a painted road line,
        // which is what the first cut of this looked like.
        if (i % 5 != 3) {
          final w = 22 + (i % 6) * 7.0;
          final r = Rect.fromLTWH(x, y - 5, w, 11);
          canvas.drawRect(
            r.translate(2, 4),
            Paint()..color = Colors.black.withValues(alpha: 0.24),
          );
          canvas.drawRect(
            r,
            Paint()..color = _kDustStone.withValues(alpha: 0.5),
          );
          canvas.drawRect(
            Rect.fromLTWH(r.left, r.top, r.width, 3),
            Paint()..color = _kDustPale.withValues(alpha: 0.34),
          );
        }
        x += 30 + (i % 4) * 14;
        i++;
      }
    }

    // THE PIERS. The arch is silted to the springing, so what stands is two
    // masses of masonry with the beginning of a curve on each and nothing
    // between them but sky.
    const cx = 636.0;
    for (final side in [-1.0, 1.0]) {
      final pier = Rect.fromLTWH(cx, 245 + side * 60 - 46, 48, 92);
      _drawMasonry(canvas, pier, 10, false);
      // THE SPRINGING. Four voussoirs turning in over the road out of the
      // pier's own top course and stopping where the arch broke — drawn as
      // separate stones, because one detached stroke of an arc read as a
      // crescent floating beside a cabinet.
      for (var v = 0; v < 4; v++) {
        final a = side < 0
            ? pi * 1.5 - 0.30 - v * 0.155
            : pi * 0.5 + 0.30 + v * 0.155;
        final at = Offset(cx + 26, 245) + Offset(cos(a) * 86, sin(a) * 78);
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(a + pi / 2);
        final st = Rect.fromCenter(
          center: Offset.zero,
          width: 26 - v * 1.6,
          height: 22,
        );
        canvas.drawRect(
          st.translate(3, 4),
          Paint()..color = Colors.black.withValues(alpha: 0.24),
        );
        canvas.drawRect(
          st,
          Paint()
            ..color = _kDustStone.withValues(alpha: 0.74 - v * 0.08),
        );
        canvas.drawRect(
          Rect.fromLTWH(st.left, st.top, st.width, 4),
          Paint()..color = _kDustPale.withValues(alpha: 0.34),
        );
        canvas.restore();
      }
    }

    // THE WIND-TOWER, at the head of the stair down into the windcatch. Its
    // vane is already drawn on top of this by `_renderRuinsObjects`; what was
    // missing was anything for the vane to be MOUNTED ON.
    final t = Rect.fromLTWH(84, 62, 78, 112);
    canvas.drawRect(
      t.translate(7, 9),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawRect(t, Paint()..color = _kDustStone.withValues(alpha: 0.74));
    canvas.drawRect(
      Rect.fromLTWH(t.left, t.top, t.width, 12),
      Paint()..color = _kDustPale.withValues(alpha: 0.55),
    );
    // Its throat: ONE tall catch-slot facing the prevailing wind, not a
    // stack of five little ones — which made the tower read as a bookcase.
    canvas.drawRect(
      Rect.fromLTWH(t.left + 12, t.top + 28, t.width - 24, 56),
      Paint()..color = const Color(0xFF0C0906).withValues(alpha: 0.75),
    );
    for (var y = t.top + 36; y < t.top + 80; y += 15) {
      canvas.drawRect(
        Rect.fromLTWH(t.left + 12, y, t.width - 24, 4),
        Paint()..color = _kDustOchre.withValues(alpha: 0.35),
      );
    }
    // And the door at its foot, which is the stair down to the windcatch.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(t.center.dx - 13, t.bottom - 30, 26, 30),
        topLeft: const Radius.circular(12),
        topRight: const Radius.circular(12),
      ),
      Paint()..color = const Color(0xFF0C0906).withValues(alpha: 0.82),
    );
  }

  /// THE SEAL STREET. The house the three bronzes belong to stands along the
  /// north side, and the yard in front of it has been pegged out for survey.
  void _renderSealHouse(Canvas canvas, DungeonRoom room) {
    // THE FACADE. A blind wall with three shallow niches in it — one for each
    // bronze, which is what the seals in the yard were prised out of.
    final f = Rect.fromLTWH(196, 56, 508, 62);
    canvas.drawRect(
      f.translate(6, 9),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawRect(f, Paint()..color = _kDustStone.withValues(alpha: 0.7));
    canvas.drawRect(
      Rect.fromLTWH(f.left, f.top, f.width, 13),
      Paint()..color = _kDustPale.withValues(alpha: 0.5),
    );
    for (var i = 0; i < 3; i++) {
      final n = Rect.fromLTWH(f.left + 54 + i * 168.0, f.top + 22, 62, 34);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          n,
          topLeft: const Radius.circular(28),
          topRight: const Radius.circular(28),
        ),
        Paint()..color = const Color(0xFF1B140D).withValues(alpha: 0.66),
      );
      // The empty peg the bronze hung on.
      canvas.drawCircle(
        n.center.translate(0, 4),
        3,
        Paint()..color = _kDustBronze.withValues(alpha: 0.4),
      );
    }
  }

  /// THE ROOF WALK. A street that runs over the tops of buried buildings —
  /// so the furniture is what pokes THROUGH a roof: vault crowns, a chimney,
  /// and a lightwell you can look down into.
  void _renderRoofWalk(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    // PARAPETS. The walk has edges, and they are what makes it a walk.
    // A parapet is a WALL that has broken in places, not a row of identical
    // blocks 96px apart — which is what the first cut of this was, and it
    // made the busiest street on the planet read as graph paper.
    const north = [(34.0, 128.0), (196.0, 74.0), (300.0, 210.0), (566.0, 92.0)];
    const south = [(52.0, 96.0), (178.0, 246.0), (470.0, 64.0), (600.0, 150.0)];
    for (final run in [(b.top + 40.0, north), (b.bottom - 64.0, south)]) {
      for (final seg in run.$2) {
        _drawMasonry(
          canvas,
          Rect.fromLTWH(b.left + seg.$1, run.$1 + (seg.$1 % 13) - 6, seg.$2, 22),
          6,
          false,
        );
      }
    }
    // VAULT CROWNS breaking the paving — the curve of a roof you are standing
    // ON, which is the single clearest way to say "there is a building under
    // your feet", and the reason this street is called the roof walk. One
    // thin arc was not enough to carry that; there are three now, at three
    // sizes, and each has a keystone.
    for (final cr in [
      Rect.fromCenter(center: const Offset(400, 444), width: 196, height: 66),
      Rect.fromCenter(center: const Offset(140, 196), width: 118, height: 44),
      Rect.fromCenter(center: const Offset(646, 236), width: 146, height: 52),
    ]) {
      canvas.drawArc(
        cr.translate(3, 6),
        pi,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..color = Colors.black.withValues(alpha: 0.22),
      );
      canvas.drawArc(
        cr,
        pi,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..color = _kDustStone.withValues(alpha: 0.62),
      );
      canvas.drawArc(
        cr.deflate(6),
        pi,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _kDustUmber.withValues(alpha: 0.4),
      );
      // The keystone, and the two voussoirs either side of it.
      for (final a in [pi * 1.32, pi * 1.5, pi * 1.68]) {
        canvas.drawLine(
          cr.center + Offset(cos(a) * cr.width * 0.44, sin(a) * cr.height * 0.44),
          cr.center + Offset(cos(a) * cr.width * 0.56, sin(a) * cr.height * 0.56),
          Paint()
            ..strokeWidth = a == pi * 1.5 ? 4 : 2
            ..color = _kDustUmber.withValues(alpha: 0.45),
        );
      }
    }
    // THE LIGHTWELL. A grating over a hole, with the dark of the excavation
    // deck showing through its bars: the two Z-layers, in one object.
    final lw = Rect.fromCenter(center: const Offset(700, 400), width: 66, height: 46);
    canvas.drawRect(
      lw,
      Paint()..color = const Color(0xFF0E0A06).withValues(alpha: 0.9),
    );
    for (var x = lw.left + 8; x < lw.right; x += 11) {
      canvas.drawLine(
        Offset(x, lw.top + 2),
        Offset(x, lw.bottom - 2),
        Paint()
          ..strokeWidth = 3
          ..color = const Color(0xFF4C3B22).withValues(alpha: 0.85),
      );
    }
    canvas.drawRect(
      lw,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _kDustStone.withValues(alpha: 0.55),
    );
  }

  /// THE HIGH TERRACE. You are a storey above the street here, so the room
  /// needs a RETAINING WALL along its low side and a drop beyond it, or there
  /// is nothing on screen to say you climbed.
  void _renderHighTerrace(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    // The drop: the street deck, far below and in shadow.
    canvas.drawRect(
      Rect.fromLTRB(b.left + 10, b.bottom - 40, b.right - 10, b.bottom - 8),
      Paint()..color = const Color(0xFF0F0B07).withValues(alpha: 0.55),
    );
    // The retaining wall, with the batter courses a terrace wall is built in.
    final w = Rect.fromLTRB(b.left + 10, b.bottom - 62, b.right - 10, b.bottom - 38);
    canvas.drawRect(w, Paint()..color = _kDustStone.withValues(alpha: 0.72));
    canvas.drawRect(
      Rect.fromLTWH(w.left, w.top, w.width, 6),
      Paint()..color = _kDustPale.withValues(alpha: 0.5),
    );
    // The joints in a retaining wall are not ruled at one pitch: the stones
    // are whatever size came out of the quarry.
    var jx = w.left + 34;
    var jn = 0;
    while (jx < w.right - 10) {
      canvas.drawLine(
        Offset(jx, w.top + 3),
        Offset(jx - 6, w.bottom),
        Paint()
          ..strokeWidth = 1.1
          ..color = _kDustUmber.withValues(alpha: 0.4),
      );
      jx += 38 + (jn % 4) * 27;
      jn++;
    }
    // THE KILN'S STACK. The cellar under this square is a kiln; its chimney
    // comes up here, and it still has soot on it.
    // A CHIMNEY, tapered, with a flared cap and its mouth open and black.
    // Ruled flat with a joint every thirteen pixels it was a ladder standing
    // in a doorway.
    const sx = 508.0;
    canvas.drawPath(
      Path()
        ..moveTo(sx - 30, 326)
        ..lineTo(sx - 19, 244)
        ..lineTo(sx + 19, 244)
        ..lineTo(sx + 30, 326)
        ..close(),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    canvas.drawPath(
      Path()
        ..moveTo(sx - 34, 322)
        ..lineTo(sx - 22, 240)
        ..lineTo(sx + 16, 240)
        ..lineTo(sx + 26, 322)
        ..close(),
      Paint()..color = _kDustBrick.withValues(alpha: 0.85),
    );
    for (final y in [264.0, 298.0]) {
      canvas.drawLine(
        Offset(sx - 30 + (y - 240) * 0.02, y),
        Offset(sx + 22, y),
        Paint()
          ..strokeWidth = 1.2
          ..color = _kDustUmber.withValues(alpha: 0.45),
      );
    }
    // The cap, and the soot round the mouth.
    canvas.drawRect(
      Rect.fromLTWH(sx - 29, 232, 52, 12),
      Paint()..color = _kDustBrick.withValues(alpha: 0.95),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(sx - 3, 236), width: 34, height: 13),
      Paint()..color = const Color(0xFF0B0806).withValues(alpha: 0.92),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(sx - 3, 236), width: 58, height: 26),
      Paint()..color = const Color(0xFF17130F).withValues(alpha: 0.3),
    );
    // PITHOI half-buried along the wall — storage jars the terrace was for.
    for (var i = 0; i < 4; i++) {
      final at = Offset(128 + i * 63.0 + (i.isEven ? 0 : 14), 120 + (i % 3) * 19.0);
      final rr = 16.0 + (i % 2) * 5;
      canvas.drawOval(
        Rect.fromCenter(center: at.translate(3, 5), width: rr * 2.1, height: rr * 1.5),
        Paint()..color = Colors.black.withValues(alpha: 0.25),
      );
      canvas.drawOval(
        Rect.fromCenter(center: at, width: rr * 2, height: rr * 1.7),
        Paint()..color = _kDustBrick.withValues(alpha: 0.8),
      );
      canvas.drawOval(
        Rect.fromCenter(center: at.translate(0, -rr * 0.45), width: rr * 1.2, height: rr * 0.6),
        Paint()..color = const Color(0xFF150F09).withValues(alpha: 0.8),
      );
    }
  }

  /// THE HOURGLASS COURT. A peristyle with the analemma of a great sand-clock
  /// laid in its floor — and a deliberately EMPTY middle, because the rite is
  /// fought and worked from there.
  void _renderHourglassCourt(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final c = b.center;
    // THE DIAL. A double ring with hour ticks, and the long figure-of-eight
    // the sun traces over a year: the court is a clock, so it says so in its
    // paving instead of in a caption.
    for (final r in [190.0, 150.0]) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r == 190.0 ? 2.4 : 1.2
          ..color = _kDustPale.withValues(alpha: 0.16),
      );
    }
    for (var i = 0; i < 24; i++) {
      final a = i / 24 * pi * 2;
      final long = i % 6 == 0;
      canvas.drawLine(
        c + Offset(cos(a), sin(a)) * 150,
        c + Offset(cos(a), sin(a)) * (long ? 190 : 170),
        Paint()
          ..strokeWidth = long ? 2.4 : 1.2
          ..color = _kDustPale.withValues(alpha: long ? 0.24 : 0.13),
      );
    }
    // THE PERISTYLE. Without it the room was a dial painted on sand: a court
    // is a colonnade with a floor inside it. Stylobate first — the step the
    // columns stand on, broken where the ground has moved — then the columns
    // themselves, at whatever spacing survived, a third of them down.
    for (final run in [b.top + 40, b.bottom - 46]) {
      var x = b.left + 34.0;
      var i = 0;
      while (x < b.right - 52) {
        final w = 54 + (i % 5) * 26.0;
        if (i % 6 != 4) {
          canvas.drawRect(
            Rect.fromLTWH(x, run - 7, w, 13),
            Paint()..color = _kDustStone.withValues(alpha: 0.34),
          );
        }
        x += w + 12 + (i % 3) * 9;
        i++;
      }
      x = b.left + 52.0;
      i = 0;
      while (x < b.right - 66) {
        final down = i % 3 == 1;
        _drawDrum(
          canvas,
          Offset(x, run + (i % 2 == 0 ? 0 : 5)),
          down ? 15 : 19 + (i % 3) * 2.0,
          down ? (i.isEven ? 0.5 : -0.8) : 0,
          down,
        );
        x += 76 + (i % 4) * 31;
        i++;
      }
    }

    final fig = Path();
    for (var i = 0; i <= 60; i++) {
      final t = i / 60 * pi * 2;
      final p = c + Offset(sin(t * 2) * 34, cos(t) * 122);
      i == 0 ? fig.moveTo(p.dx, p.dy) : fig.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      fig,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _kDustBronze.withValues(alpha: 0.2),
    );
  }

  /// THE WINDCATCH. The tower's throat, seen from the bottom: the shaft goes
  /// up out of the room, and the light and the dust come down it.
  void _renderWindcatch(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final c = Offset(310, 210);
    // THE SHAFT. Four walls converging on a bright square a long way up —
    // the only daylight on the excavation deck, and the reason this room is
    // the one vane you can always reach.
    for (var i = 4; i >= 1; i--) {
      final k = i / 4.0;
      canvas.drawRect(
        Rect.fromCenter(
          center: c,
          width: 60 + 230 * k,
          height: 46 + 170 * k,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _kDustStone.withValues(alpha: 0.10 + 0.10 * (1 - k)),
      );
    }
    // The corners, drawn as real converging lines so it reads as perspective
    // rather than as four boxes.
    for (final s in [const Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)]) {
      canvas.drawLine(
        c + Offset(s.dx * 145, s.dy * 108),
        c + Offset(s.dx * 30, s.dy * 23),
        Paint()
          ..strokeWidth = 1.4
          ..color = _kDustStone.withValues(alpha: 0.16),
      );
    }
    // Daylight at the top of the shaft, and the column of it coming down.
    for (var i = 3; i >= 1; i--) {
      canvas.drawRect(
        Rect.fromCenter(center: c, width: 60.0 * i * 0.62, height: 46.0 * i * 0.62),
        Paint()..color = _kDustPale.withValues(alpha: 0.07),
      );
    }
    canvas.drawRect(
      Rect.fromCenter(center: c, width: 54, height: 42),
      Paint()..color = _kDustPale.withValues(alpha: 0.24),
    );
    // LOUVRES cut into two walls: the tower breathes through these, and it is
    // still breathing (the room's own ambient line).
    // Cut in short banks with broken ground between them — a wall of evenly
    // pitched slots down both sides read as a strip of film.
    const banks = [(104.0, 4, 24.0), (204.0, 2, 33.0), (268.0, 3, 21.0)];
    for (final side in [b.left + 22, b.right - 42]) {
      for (final bank in banks) {
        for (var i = 0; i < bank.$2; i++) {
          final y = bank.$1 + i * bank.$3;
          canvas.drawRect(
            Rect.fromLTWH(side, y, 16 + (i % 3) * 3.0, 13.0 + (i % 2) * 6),
            Paint()..color = const Color(0xFF0D0905).withValues(alpha: 0.72),
          );
          canvas.drawLine(
            Offset(side, y),
            Offset(side + 16, y),
            Paint()
              ..strokeWidth = 1.4
              ..color = _kDustOchre.withValues(alpha: 0.28),
          );
        }
      }
    }
  }

  /// THE UNDERCITY. The drift tunnels, and the bare-est room in the game at
  /// 513 edge-pixels: a 960x600 excavation hub with five doors and literally
  /// no furniture in it.
  ///
  /// What it needed was not decoration but ARCHITECTURE — this is the spine
  /// of the lower deck, so every door is now the mouth of a brick tunnel, and
  /// the tunnels are what the room is made of. The middle stays open: it is
  /// the mercy shrine and the crossroads of five ways.
  void _renderUndercity(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    for (final d in room.doors) {
      // Each door is the mouth of a brick barrel running off under the city.
      // Three receding rings, driving INTO the room, so the hub reads as the
      // crossing of five tunnels rather than as a rectangle with holes in it.
      final away = b.center - d.rect.center;
      final n = away.distance < 1 ? const Offset(0, 1) : away / away.distance;
      final wide = d.rect.width > d.rect.height;
      for (var i = 0; i < 3; i++) {
        final k = 1 - i * 0.21;
        final at = d.rect.center + n * (i * 22.0 + 12);
        canvas.drawOval(
          Rect.fromCenter(
            center: at,
            width: (wide ? 128 : 96) * k,
            height: (wide ? 96 : 128) * k,
          ),
          Paint()
            ..color = (i == 0 ? _kDustBrick : const Color(0xFF150F09))
                .withValues(alpha: i == 0 ? 0.55 : 0.4 + i * 0.2),
        );
      }
      // Voussoirs round the mouth, so the bore is BUILT and not melted.
      final mouth = d.rect.center + n * 12;
      final rx = wide ? 64.0 : 48.0;
      final ry = wide ? 48.0 : 64.0;
      for (var v = 0; v < 9; v++) {
        final a = atan2(n.dy, n.dx) + pi + (v - 4) * 0.24;
        canvas.drawLine(
          mouth + Offset(cos(a) * rx * 0.86, sin(a) * ry * 0.86),
          mouth + Offset(cos(a) * rx * 1.08, sin(a) * ry * 1.08),
          Paint()
            ..strokeWidth = 2.4
            ..color = _kDustOchre.withValues(alpha: 0.26),
        );
      }
    }

    // THE TRAMWAY. The hub's middle has to stay open to walk and fight in,
    // so what goes in it is FLAT: the spoil road every barrow in Sablis has
    // run down, from the wind-tower's tunnel out east under the city. It is
    // the one thing that makes a five-door crossroads read as a place with a
    // direction rather than as an empty rectangle.
    final rail = Path()..moveTo(b.left + 30, 226);
    for (var x = b.left + 30.0; x < b.right - 120; x += 120) {
      rail.quadraticBezierTo(x + 60, 226 + sin(x * 0.011) * 26, x + 120, 232 + sin(x * 0.008) * 34);
    }
    // Sleepers first, at whatever spacing they were laid at.
    var sx = b.left + 44.0;
    var sn = 0;
    while (sx < b.right - 110) {
      final sy = 226 + sin(sx * 0.009) * 30;
      canvas.save();
      canvas.translate(sx, sy);
      canvas.rotate(0.1 + sin(sx * 0.02) * 0.12);
      canvas.drawRect(
        const Rect.fromLTWH(-5, -19, 10, 38),
        Paint()..color = _kDustTimber.withValues(alpha: 0.5),
      );
      canvas.restore();
      sx += 22 + (sn % 5) * 7;
      sn++;
    }
    for (final off in [-11.0, 11.0]) {
      canvas.save();
      canvas.translate(0, off);
      canvas.drawPath(
        rail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0xFF8A7657).withValues(alpha: 0.42),
      );
      canvas.restore();
    }
    // A tipper wagon standing where the last shift left it, off the road.
    const wag = Offset(690, 470);
    canvas.drawRect(
      Rect.fromCenter(center: wag.translate(4, 7), width: 74, height: 46),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    canvas.drawRect(
      Rect.fromCenter(center: wag, width: 74, height: 46),
      Paint()..color = _kDustTimber.withValues(alpha: 0.92),
    );
    canvas.drawRect(
      Rect.fromCenter(center: wag, width: 62, height: 34),
      Paint()..color = const Color(0xFF2C2013).withValues(alpha: 0.9),
    );
    canvas.drawPath(
      Path()
        ..moveTo(wag.dx - 24, wag.dy + 4)
        ..quadraticBezierTo(wag.dx, wag.dy - 18, wag.dx + 24, wag.dy + 4)
        ..close(),
      Paint()..color = _kDustOchre.withValues(alpha: 0.55),
    );
    for (final s in [-1.0, 1.0]) {
      canvas.drawCircle(
        wag.translate(s * 24, 26),
        9,
        Paint()..color = const Color(0xFF4A3A24).withValues(alpha: 0.95),
      );
    }

    // THE PARTY WALL. "Somewhere along this wall the brick is younger than
    // the rest" is the room's own insight line, and nothing drew it — the one
    // piece of geography the vault trick turns on was invisible. It is a
    // patch of newer, redder brick in the east wall, with a hairline in it;
    // when the bump above is heaped, the hairline is a crack you fit through.
    final open = ruins.stateOf('m_bump') == MoundState.drifted;
    final pw = Rect.fromLTWH(b.right - 62, 206, 54, 184);
    canvas.drawRect(
      pw,
      Paint()..color = const Color(0xFF7A4B30).withValues(alpha: 0.75),
    );
    for (var y = pw.top + 6; y < pw.bottom; y += 13) {
      canvas.drawLine(
        Offset(pw.left + 2, y),
        Offset(pw.right - 2, y),
        Paint()
          ..strokeWidth = 1
          ..color = const Color(0xFF33200F).withValues(alpha: 0.55),
      );
    }
    final crack = Path()
      ..moveTo(pw.center.dx + 5, pw.top + 8)
      ..lineTo(pw.center.dx - 4, pw.top + 54)
      ..lineTo(pw.center.dx + 6, pw.top + 96)
      ..lineTo(pw.center.dx - 3, pw.bottom - 10);
    canvas.drawPath(
      crack,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = open ? 7 : 1.8
        ..color = open
            ? const Color(0xFF080604).withValues(alpha: 0.95)
            : const Color(0xFF2A1A0D).withValues(alpha: 0.75),
    );
    if (open) {
      // Dust still running out of a wall that gave under the weight.
      canvas.drawPath(
        crack,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _kDustPale.withValues(alpha: 0.3),
      );
    }
  }

  /// THE GRANARY. Sunk storage pits in the floor, most of them still capped.
  void _renderGranary(Canvas canvas, DungeonRoom room) {
    const pits = [
      (Offset(92, 118), 44.0, true),
      (Offset(196, 232), 38.0, false),
      (Offset(330, 128), 50.0, false),
      (Offset(372, 252), 32.0, true),
      (Offset(120, 268), 27.0, false),
    ];
    for (final p in pits) {
      final at = p.$1;
      final r = p.$2;
      // The collar of brick round the mouth of the pit.
      canvas.drawOval(
        Rect.fromCenter(center: at, width: r * 2.2, height: r * 1.7),
        Paint()..color = _kDustBrick.withValues(alpha: 0.7),
      );
      canvas.drawOval(
        Rect.fromCenter(center: at, width: r * 1.8, height: r * 1.34),
        Paint()..color = const Color(0xFF0B0805).withValues(alpha: 0.9),
      );
      if (p.$3) {
        // Still capped: a stone lid with its lifting slot.
        canvas.drawOval(
          Rect.fromCenter(center: at.translate(0, -3), width: r * 1.72, height: r * 1.26),
          Paint()..color = _kDustStone.withValues(alpha: 0.72),
        );
        canvas.drawRect(
          Rect.fromCenter(center: at.translate(0, -3), width: r * 0.5, height: 5),
          Paint()..color = const Color(0xFF140E08).withValues(alpha: 0.8),
        );
      } else {
        // Open: the grain went to chaff a thousand years ago, and what is
        // left has spilled out over the lip in a fan.
        canvas.drawArc(
          Rect.fromCenter(center: at.translate(0, 4), width: r * 1.6, height: r * 1.1),
          0,
          pi,
          true,
          Paint()..color = _kDustOchre.withValues(alpha: 0.35),
        );
        canvas.drawPath(
          Path()
            ..moveTo(at.dx - r * 0.6, at.dy + r * 0.6)
            ..quadraticBezierTo(
              at.dx,
              at.dy + r * 1.9,
              at.dx + r * 0.8,
              at.dy + r * 0.7,
            )
            ..close(),
          Paint()..color = _kDustOchre.withValues(alpha: 0.3),
        );
      }
    }
    // SACKS against the wall, slumped and long since split. Three, at three
    // sizes, leaning on each other the way sacks do.
    for (var i = 0; i < 3; i++) {
      final at = Offset(230 + i * 34.0 + (i % 2) * 9, 62 + (i % 3) * 11.0);
      final w = 26 + (i % 3) * 8.0;
      canvas.drawPath(
        Path()
          ..moveTo(at.dx - w / 2, at.dy + 20)
          ..quadraticBezierTo(at.dx - w * 0.62, at.dy - 14, at.dx, at.dy - 18)
          ..quadraticBezierTo(at.dx + w * 0.6, at.dy - 12, at.dx + w / 2, at.dy + 20)
          ..close(),
        Paint()..color = const Color(0xFF6B5B40).withValues(alpha: 0.85),
      );
      canvas.drawLine(
        at.translate(-w * 0.2, -16),
        at.translate(w * 0.2, -15),
        Paint()
          ..strokeWidth = 2
          ..color = const Color(0xFF2A2114).withValues(alpha: 0.7),
      );
    }
  }

  /// THE OBSERVATORY (Star 1).
  ///
  /// THE ROOM'S WHOLE POINT WAS INVISIBLE. The armillary stands on an island
  /// in a ring-shaped moat, and the shared island renderer only slices rooms
  /// into horizontal bands — so the island, and both side aisles, were drawn
  /// as open sky. The star of the planet's marquee gate was floating in a
  /// void with no ground under it and no roof over it.
  ///
  /// Now: the floor is drawn with the moat cut OUT of it (`floorCut`), the
  /// moat has cut walls with strata so it reads as a trench rather than a
  /// hole in the picture, the island is a stepped plinth, and the ROOF is
  /// drawn — coffered beams in shadow while the mound above is buried, a
  /// ragged hole with the sky pouring in once it is bared. That is Star 1's
  /// whole trade, on screen, without a word.
  void _renderObservatoryRoom(Canvas canvas, DungeonRoom room, _RuinsGround g) {
    final open = ruins.stateOf('m_roof') == MoundState.bared;
    final isle = Rect.fromCenter(
      center: const Offset(440, 300),
      width: 152,
      height: 152,
    );

    // THE ROOF, FIRST. Star 1's whole trade is drawn here, and it has to go
    // UNDER the moat and the island: ruled across the top of them, the beams
    // crossed the hole and the span stopped reading as a hole at all.
    if (!open) {
      // Rafters, in pairs with a wide bay between them — the ceiling that is
      // also the street above, and the reason the rings read nothing.
      for (final y in [64.0, 88.0, 206.0, 230.0, 344.0, 368.0, 470.0]) {
        // A shadow cast DOWN from each beam, so it reads as something over
        // your head and not as a plank lying on the floor.
        canvas.drawRect(
          Rect.fromLTWH(room.bounds.left + 10, y + 11, room.bounds.width - 20, 12),
          Paint()..color = Colors.black.withValues(alpha: 0.16),
        );
        canvas.drawRect(
          Rect.fromLTWH(room.bounds.left + 10, y, room.bounds.width - 20, 11),
          Paint()..color = const Color(0xFF1A1209).withValues(alpha: 0.5),
        );
        canvas.drawRect(
          Rect.fromLTWH(room.bounds.left + 10, y, room.bounds.width - 20, 2.5),
          Paint()..color = _kDustTimber.withValues(alpha: 0.34),
        );
      }
      canvas.drawRect(
        room.bounds,
        Paint()..color = const Color(0xFF0A0806).withValues(alpha: 0.2),
      );
    } else {
      // Bared: the sky comes down through the hole somebody made, and the
      // light lands on the island. The rim is the broken edge of the roof.
      canvas.drawPath(
        g.roofHole,
        Paint()..color = const Color(0xFF9FC4E8).withValues(alpha: 0.13),
      );
      canvas.drawPath(
        g.roofHole,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = _kDustStone.withValues(alpha: 0.45),
      );
      for (var i = 3; i >= 1; i--) {
        canvas.drawCircle(
          isle.center,
          58.0 * i,
          Paint()..color = const Color(0xFFBBD7F2).withValues(alpha: 0.04),
        );
      }
    }

    // THE MOAT. Cut faces on the inner edge of every gap, so the span has
    // depth and a body can see it is a hole and not a painted stripe.
    for (final gap in room.gaps) {
      canvas.drawRect(
        gap.rect,
        Paint()..color = const Color(0xFF07060B).withValues(alpha: 0.55),
      );
      canvas.drawRect(
        Rect.fromLTWH(gap.rect.left, gap.rect.top, gap.rect.width, 9),
        Paint()..color = const Color(0xFF6A5031).withValues(alpha: 0.5),
      );
      canvas.drawRect(
        Rect.fromLTWH(gap.rect.left, gap.rect.top + 9, gap.rect.width, 6),
        Paint()..color = const Color(0xFF3E2F1E).withValues(alpha: 0.55),
      );
      canvas.drawRect(
        gap.rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _kDustUmber.withValues(alpha: 0.8),
      );
    }
    // THE ISLAND. A stepped plinth, because the instrument on it is the most
    // important object in the dungeon and it was standing on nothing.
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          isle.deflate(i * 13.0),
          Radius.circular(24 - i * 5.0),
        ),
        Paint()
          ..color = const Color(0xFF6B5943).withValues(alpha: 0.45 + i * 0.14),
      );
    }
    // A zodiac ring cut into the plinth's top — the instrument's own scale.
    canvas.drawCircle(
      isle.center,
      50,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _kDustBronze.withValues(alpha: open ? 0.5 : 0.2),
    );
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * pi * 2;
      canvas.drawLine(
        isle.center + Offset(cos(a), sin(a)) * 44,
        isle.center + Offset(cos(a), sin(a)) * 50,
        Paint()
          ..strokeWidth = 1.6
          ..color = _kDustBronze.withValues(alpha: open ? 0.55 : 0.22),
      );
    }

    // THE CAUSEWAY THAT IS NOT THERE. Four stubs of the bridge that used to
    // reach the island, broken off over the span — so a player can see that
    // there WAS a way across and that the dig took it, which is the §6 line
    // "Airwing can cross what the dig destroyed", made visible.
    for (final s in [
      (const Offset(440, 226), 26.0, 12.0),
      (const Offset(440, 374), 26.0, 12.0),
      (const Offset(366, 300), 12.0, 26.0),
      (const Offset(514, 300), 12.0, 26.0),
    ]) {
      canvas.drawRect(
        Rect.fromCenter(center: s.$1, width: s.$2, height: s.$3),
        Paint()..color = _kDustStone.withValues(alpha: 0.45),
      );
    }
  }

  /// THE KILN CELLAR. A domed updraught kiln with its stoke-hole still black,
  /// and the wasters stacked round it that never came out right.
  void _renderKilnCellar(Canvas canvas, DungeonRoom room) {
    const c = Offset(150, 214);
    // The dome, in brick courses that narrow as they rise.
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(6, 10), width: 190, height: 130),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 186, height: 128),
      Paint()..color = _kDustBrick.withValues(alpha: 0.85),
    );
    for (var i = 1; i < 5; i++) {
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, -i * 5.0), width: 186.0 - i * 30, height: 128.0 - i * 22),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFF35200F).withValues(alpha: 0.5),
      );
    }
    // The flue at the crown, going up to the stack on the terrace above.
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, -26), width: 38, height: 24),
      Paint()..color = const Color(0xFF0B0704).withValues(alpha: 0.92),
    );
    // The stoke-hole, and the ash fan that has come out of it.
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 22, c.dy + 62)
        ..lineTo(c.dx + 22, c.dy + 62)
        ..lineTo(c.dx + 62, c.dy + 118)
        ..lineTo(c.dx - 58, c.dy + 118)
        ..close(),
      Paint()..color = const Color(0xFF2E2A26).withValues(alpha: 0.5),
    );
    canvas.drawArc(
      Rect.fromCenter(center: c.translate(0, 58), width: 56, height: 40),
      pi,
      pi,
      true,
      Paint()..color = const Color(0xFF090604).withValues(alpha: 0.92),
    );
    // WASTERS — the pots that slumped in the firing, stacked where they were
    // thrown out.
    for (var i = 0; i < 7; i++) {
      final at = Offset(320 + (i % 3) * 42.0 + (i ~/ 3) * 17, 106 + (i ~/ 3) * 66.0 + (i % 3) * 13);
      final rr = 12.0 + (i % 3) * 4;
      canvas.drawOval(
        Rect.fromCenter(center: at, width: rr * 2, height: rr * 1.5),
        Paint()..color = _kDustBrick.withValues(alpha: 0.62),
      );
      canvas.drawArc(
        Rect.fromCenter(center: at.translate(0, -rr * 0.3), width: rr * 1.3, height: rr * 0.8),
        pi,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF120C07).withValues(alpha: 0.7),
      );
    }
    // THE FUEL. A kiln is fed, and a cellar kiln is fed from a stack in the
    // corner — split lengths on end, seen from above, never in a tidy row.
    for (var i = 0; i < 9; i++) {
      final at = Offset(
        62 + (i % 4) * 21.0 + (i ~/ 4) * 11,
        62 + (i ~/ 4) * 23.0 + (i % 4) * 6,
      );
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(0.3 + (i % 5) * 0.22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 34.0 - (i % 3) * 6, height: 9),
          const Radius.circular(4),
        ),
        Paint()..color = _kDustTimber.withValues(alpha: 0.9),
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(-13, 0), width: 7, height: 8),
        Paint()..color = const Color(0xFF9C7F52).withValues(alpha: 0.7),
      );
      canvas.restore();
    }
    // The rake, left where the last firing ended.
    canvas.save();
    canvas.translate(268, 318);
    canvas.rotate(-0.5);
    canvas.drawRect(
      const Rect.fromLTWH(-52, -2, 104, 4),
      Paint()..color = _kDustTimber.withValues(alpha: 0.92),
    );
    canvas.drawRect(
      const Rect.fromLTWH(44, -13, 7, 27),
      Paint()..color = const Color(0xFF3B3128).withValues(alpha: 0.92),
    );
    canvas.restore();
  }

  /// THE SUNKEN HOUSE (the vault). The one room in Sablis nobody ever dug
  /// out — so it is the one room that is NOT an excavation. No shoring, no
  /// spoil, no tool marks: a mosaic floor, a hearth with its ash still in it,
  /// a bench, and shelves of sealed jars, exactly as its owners left them.
  void _renderSunkenHouse(Canvas canvas, DungeonRoom room, _RuinsGround g) {
    final b = room.bounds;
    // THE MOSAIC. A border key and a centre panel — intact, which is the
    // whole reason this room is worth the trick it takes to get in.
    final panel = Rect.fromCenter(center: b.center, width: 250, height: 176);
    canvas.drawRect(
      panel,
      Paint()..color = const Color(0xFF8A7B60).withValues(alpha: 0.34),
    );
    // TESSERAE. First cut drew every single tile as a bright chip on a dark
    // ground, which came out looking like a KEYBOARD. A mosaic is a pale
    // FIELD with a pattern set into it, so the field is laid first, the
    // grout is a whisper, and only the tiles that make the pattern — the
    // rosette and the band round it — are actually drawn.
    canvas.drawRect(
      panel.deflate(18),
      Paint()..color = const Color(0xFFBCA87F).withValues(alpha: 0.5),
    );
    final grout = Paint()
      ..strokeWidth = 1.0
      ..color = const Color(0xFF564A36).withValues(alpha: 0.2);
    final field = panel.deflate(18);
    for (var x = field.left; x < field.right; x += 9) {
      canvas.drawLine(Offset(x, field.top), Offset(x, field.bottom), grout);
    }
    for (var y = field.top; y < field.bottom; y += 9) {
      canvas.drawLine(Offset(field.left, y), Offset(field.right, y), grout);
    }
    for (final t in g.tesserae) {
      canvas.drawRect(
        t.rect,
        Paint()
          ..color = switch (t.tone) {
            0 => const Color(0xFF2B2A33),
            _ => const Color(0xFF8C4A33),
          }.withValues(alpha: 0.7),
      );
    }
    canvas.drawRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = _kDustPale.withValues(alpha: 0.24),
    );

    // THE HEARTH, with a thousand years of undisturbed ash in it.
    final hearth = Rect.fromCenter(center: Offset(b.center.dx, b.top + 52), width: 92, height: 44);
    canvas.drawRect(hearth, Paint()..color = _kDustBrick.withValues(alpha: 0.72));
    canvas.drawRect(
      hearth.deflate(8),
      Paint()..color = const Color(0xFF221C16).withValues(alpha: 0.9),
    );
    canvas.drawOval(
      Rect.fromCenter(center: hearth.center, width: 50, height: 18),
      Paint()..color = const Color(0xFF6A6055).withValues(alpha: 0.45),
    );
    // THE SHELF, with its jars still sealed and still standing in a row —
    // the only orderly row of anything on this planet, and it earns it.
    final shelf = Rect.fromLTWH(b.right - 118, 108, 96, 9);
    canvas.drawRect(shelf, Paint()..color = _kDustTimber.withValues(alpha: 0.85));
    for (var i = 0; i < 4; i++) {
      final at = Offset(shelf.left + 14 + i * 23.0, shelf.top - 12);
      canvas.drawOval(
        Rect.fromCenter(center: at, width: 17, height: 24),
        Paint()..color = _kDustBrick.withValues(alpha: 0.85),
      );
      canvas.drawRect(
        Rect.fromCenter(center: at.translate(0, -13), width: 9, height: 5),
        Paint()..color = _kDustPale.withValues(alpha: 0.4),
      );
    }
    // THE BENCH along the near wall.
    final bench = Rect.fromLTWH(b.left + 40, b.bottom - 74, 112, 22);
    canvas.drawRect(
      bench.translate(4, 6),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    canvas.drawRect(bench, Paint()..color = _kDustStone.withValues(alpha: 0.7));
    canvas.drawRect(
      Rect.fromLTWH(bench.left, bench.top, bench.width, 5),
      Paint()..color = _kDustPale.withValues(alpha: 0.4),
    );
    // THE CRACK you came in by, in the west wall — and the rubble that fell
    // out of it onto this floor, which is the only disturbed thing in here.
    canvas.drawPath(
      Path()
        ..moveTo(b.left + 6, 118)
        ..lineTo(b.left + 26, 148)
        ..lineTo(b.left + 14, 186)
        ..lineTo(b.left + 32, 228)
        ..lineTo(b.left + 6, 246),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFF0A0705).withValues(alpha: 0.85),
    );
  }

  /// ASHDJINN'S HOLLOW. An open cut in the desert with the whole excavation's
  /// bank heaped round it — and the middle left bare, because a guardian
  /// arena has to be walked and fought in (§7.9).
  void _renderHollow(Canvas canvas, DungeonRoom room, _RuinsGround g) {
    final b = room.bounds;
    // THE BANK. A ring of spoil round the cut, drawn as one ragged crest so
    // it reads as one continuous heap and not as a row of hills.
    // The floor of the cut: darker than the ground outside it, because you
    // are standing IN the excavation.
    canvas.drawPath(
      g.bankInner,
      Paint()..color = const Color(0xFF14100A).withValues(alpha: 0.52),
    );
    // The shadow the bank throws down into its own cut.
    canvas.drawPath(
      g.bankInner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..color = const Color(0xFF0B0805).withValues(alpha: 0.28),
    );
    // THE BANK, as overlapping barrowfuls. Two earlier cuts of this were one
    // closed ring path — first a smooth ellipse, then a ragged one — and both
    // read as a COASTLINE drawn round the room rather than as spoil somebody
    // heaped. A bank is a dozen separate heaps that have run together, and
    // each of them has its own crest and its own shadow.
    for (var i = 0; i < g.hollowLobes.length; i++) {
      final lobe = g.hollowLobes[i];
      canvas.save();
      canvas.translate(4, 7);
      canvas.drawPath(
        lobe,
        Paint()..color = Colors.black.withValues(alpha: 0.22),
      );
      canvas.restore();
      canvas.drawPath(
        lobe,
        Paint()
          ..color = (i.isEven
                  ? const Color(0xFF5A472C)
                  : const Color(0xFF4A3A24))
              .withValues(alpha: 0.88),
      );
      canvas.drawPath(
        g.hollowCrests[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = _kDustPale.withValues(alpha: 0.3),
      );
    }
    // SCOUR. The storm has been going round this hollow for a long time, and
    // it has cut the floor into long shallow flutes, all on one bearing.
    for (var i = 0; i < 9; i++) {
      final y = b.top + 96 + i * 52.0 + (i % 3) * 9;
      final p = Path()..moveTo(b.left + 40, y);
      for (var x = b.left + 40.0; x < b.right - 40; x += 70) {
        p.quadraticBezierTo(x + 35, y - 12 - (i % 4) * 3, x + 70, y);
      }
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 + (i % 3) * 0.7
          ..color = _kDustPale.withValues(alpha: 0.07 + (i % 3) * 0.02),
      );
    }
    // WHAT THE STORM HAS UNCOVERED AND RE-BURIED, over and over: the ribs of
    // something that was standing here, mostly still under.
    for (var i = 0; i < 5; i++) {
      final at = Offset(150 + i * 34.0 + (i % 2) * 16, 540 + (i % 3) * 22.0 - i * 7);
      canvas.drawArc(
        Rect.fromCenter(center: at, width: 26, height: 78),
        pi * 1.16,
        pi * 0.52,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = _kDustPale.withValues(alpha: 0.34),
      );
      // Sand over the foot of every rib: the same storm uncovers and
      // re-buries them, endlessly, which is the whole fight.
      canvas.drawOval(
        Rect.fromCenter(center: at.translate(-6, 6), width: 42, height: 20),
        Paint()..color = const Color(0xFF564733).withValues(alpha: 0.62),
      );
    }
  }

  // ── The mounds: the planet's one object ──────────────────

  void _renderMounds(Canvas canvas, DungeonRoom room) {
    final g = _ruinsGround(room);
    for (final m in dustMoundsIn(room.id)) {
      if (room.id == layout.entranceRoomId && !entryDoorRevealed) continue;
      final r = Rect.fromCenter(center: m.streetPos, width: 132, height: 92);
      final geo = g.mounds[m.id]!;
      switch (ruins.stateOf(m.id)) {
        case MoundState.buried:
          // A PLAIN STREET SQUARE — intact paving somebody has pegged out and
          // chalked. It is the only ground on the planet you can walk across,
          // so it has to look solid and worth keeping.
          for (final f in geo.flags) {
            canvas.drawPath(
              f,
              Paint()..color = _kDustStone.withValues(alpha: 0.52),
            );
            canvas.drawPath(
              f,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.1
                ..color = _kDustUmber.withValues(alpha: 0.42),
            );
          }
          // Survey pegs at the corners with the string still run between
          // them — this square has been MEASURED, which is the fiction the
          // whole planet's verb comes out of.
          final peg = Paint()..color = _kDustDeep.withValues(alpha: 0.8);
          for (final c in [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft]) {
            canvas.drawCircle(c, 3.4, peg);
          }
          // Chalked string on two sides only, in dashes. A closed rectangle
          // round the whole square made every buried mound read as a CRATE
          // sitting on the floor rather than as a piece of the floor.
          for (final y in [r.top, r.bottom]) {
            for (var x = r.left; x < r.right - 6; x += 17) {
              canvas.drawLine(
                Offset(x, y),
                Offset(x + 10, y),
                Paint()
                  ..strokeWidth = 1.1
                  ..color = _kDustPale.withValues(alpha: 0.3),
              );
            }
          }
        case MoundState.bared:
          // AN OPEN TRENCH, with the cut section showing in strata down the
          // far side and the spoil rim it threw up round the near lip. The
          // building below is open: that black is a way DOWN.
          canvas.drawPath(
            geo.lip,
            Paint()..color = _kDustOchre.withValues(alpha: 0.42),
          );
          canvas.drawPath(
            geo.pit,
            Paint()..color = const Color(0xFF0B0805).withValues(alpha: 0.92),
          );
          const strata = [
            Color(0xFF6A5031),
            Color(0xFF3E2F1E),
            Color(0xFF7B5C39),
          ];
          // Clipped to the hole. Ruled as full-width bars they stuck out past
          // the ragged lip on both sides, and the trench read as a dark blob
          // with three planks lying across it.
          canvas.save();
          canvas.clipPath(geo.pit);
          for (var i = 0; i < 3; i++) {
            canvas.drawRect(
              Rect.fromLTWH(r.left, r.top + 6.0 + i * 7, r.width, 6),
              Paint()..color = strata[i].withValues(alpha: 0.55 - i * 0.11),
            );
          }
          canvas.restore();
          // The step cut into the side to climb out by.
          for (var i = 0; i < 3; i++) {
            canvas.drawRect(
              Rect.fromLTWH(r.left + 14.0 + i * 6, r.bottom - 26.0 + i * 6, 30, 5),
              Paint()..color = _kDustOchre.withValues(alpha: 0.34),
            );
          }
        case MoundState.drifted:
          // A DUNE, with a windward face the wind has combed and a hard slip
          // face on the lee side. Dry, angular, nothing like a flood.
          canvas.drawPath(
            geo.dune,
            Paint()..color = _kDustPale.withValues(alpha: 0.64),
          );
          canvas.drawPath(
            geo.duneLee,
            Paint()..color = const Color(0xFF7A6238).withValues(alpha: 0.5),
          );
          canvas.drawPath(
            geo.crest,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..color = Colors.white.withValues(alpha: 0.8),
          );
          for (final w in geo.duneRipples) {
            canvas.drawPath(
              w,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2
                ..color = _kDustUmber.withValues(alpha: 0.2),
            );
          }
      }
      // An unswept print, showing only while the ground is open.
      final print = m.footprintPos;
      if (print != null &&
          ruins.stateOf(m.id) == MoundState.bared &&
          !ruins.sweptPrints.contains(m.id) &&
          !discoveredClouds.contains(kDustNothingPerishesEggId)) {
        _drawFootprints(canvas, print);
      }
    }
  }

  /// A bare foot pressed into a floor, twice, walking. It used to be two
  /// plain ovals, which read as stones.
  void _drawFootprints(Canvas canvas, Offset at) {
    for (var i = 0; i < 2; i++) {
      final c = at + Offset(i * 18.0 - 9, i * 13.0);
      final ink = Paint()..color = _kDustDeep.withValues(alpha: 0.55);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i == 0 ? -0.16 : 0.14);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 4), width: 13, height: 19),
        ink,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -8), width: 10, height: 8),
        ink,
      );
      for (var t = 0; t < 4; t++) {
        canvas.drawCircle(Offset(-4.0 + t * 2.8, -13.5 - (t == 0 ? 1 : 0)), 1.5, ink);
      }
      canvas.restore();
    }
  }

  // ── Star 0's survey yard ─────────────────────────────────

  /// THE YARD IS A SURVEY, NOT A CHESSBOARD.
  ///
  /// It was fifteen identical rounded rectangles in three flat colours, which
  /// is the single most schematic object on the planet and the one the player
  /// spends the most time reading. The MECHANIC needs the lattice — a cell's
  /// load count and its neighbours are the puzzle — so the lattice stays, and
  /// what changes is that it is now what the fiction always said it was: a
  /// yard of loose spoil pegged out and chalked into squares by somebody who
  /// was digging it. Depth still reads at a glance in three unmistakable
  /// silhouettes; nothing about the puzzle got quieter.
  void _renderDriftYard(Canvas canvas, DungeonRoom room, _RuinsGround g) {
    final f = room.ruins?.field;
    if (f == null) return;
    final yard = Rect.fromLTWH(
      f.origin.dx,
      f.origin.dy,
      f.cols * f.cell,
      f.rows * f.cell,
    );
    // The flags under the whole yard: this is a street somebody buried.
    canvas.drawRect(
      yard,
      Paint()..color = const Color(0xFF564733).withValues(alpha: 0.42),
    );
    for (final p in g.yardFlags) {
      canvas.drawPath(
        p,
        Paint()..color = _kDustStone.withValues(alpha: 0.3),
      );
    }
    // CHALKED STRING between pegs — the survey grid, drawn as string rather
    // than as cell borders, so it lies OVER the ground instead of dividing it.
    final chalk = Paint()
      ..strokeWidth = 1.0
      ..color = _kDustPale.withValues(alpha: 0.22);
    for (var c = 0; c <= f.cols; c++) {
      final x = yard.left + c * f.cell;
      canvas.drawLine(Offset(x, yard.top - 6), Offset(x, yard.bottom + 6), chalk);
    }
    for (var r = 0; r <= f.rows; r++) {
      final y = yard.top + r * f.cell;
      canvas.drawLine(Offset(yard.left - 6, y), Offset(yard.right + 6, y), chalk);
    }
    final peg = Paint()..color = _kDustDeep.withValues(alpha: 0.75);
    for (var c = 0; c <= f.cols; c++) {
      for (var r = 0; r <= f.rows; r++) {
        canvas.drawCircle(
          Offset(yard.left + c * f.cell, yard.top + r * f.cell),
          2.6,
          peg,
        );
      }
    }

    for (var r = 0; r < f.rows; r++) {
      for (var c = 0; c < f.cols; c++) {
        final i = r * f.cols + c;
        final rect = f.rectAt(c, r);
        if (f.isPillar(c, r)) {
          // A RUBBLE PILLAR: broken drum and blocks, not a grey tile. It
          // holds nothing, blocks a throw, and cannot be stood on — and it
          // has to LOOK like something you could not stand on.
          for (final blk in g.yardRubble[i] ?? const <Path>[]) {
            canvas.drawPath(
              blk,
              Paint()..color = const Color(0xFF564C3E).withValues(alpha: 0.95),
            );
            canvas.drawPath(
              blk,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2
                ..color = _kDustUmber.withValues(alpha: 0.6),
            );
          }
          _drawDrum(canvas, rect.center.translate(0, -6), 15, 0.9, true);
          continue;
        }
        final loads = ruins.driftAt(i);
        if (loads >= 1) {
          canvas.drawPath(
            g.yardDrift[i]!,
            Paint()
              ..color = (loads >= 2 ? _kDustPale : _kDustOchre).withValues(
                alpha: loads >= 2 ? 0.7 : 0.44,
              ),
          );
        }
        if (loads >= 2) {
          // A dune's crest and its hard lee shadow: the one height a spade
          // will not bite, so it must not be mistakable for a plain burial.
          canvas.drawPath(
            g.yardHeap[i]!,
            Paint()..color = Colors.white.withValues(alpha: 0.34),
          );
          canvas.drawPath(
            g.yardCrest[i]!,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2
              ..color = Colors.white.withValues(alpha: 0.7),
          );
        }
        if (loads == 0) {
          // Scraped to the flags: a dark scour ring where the spade went
          // round the edge of the square.
          canvas.drawOval(
            rect.deflate(12),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = _kDustUmber.withValues(alpha: 0.35),
          );
        }
        if (f.isSeal(c, r)) {
          _drawSeal(canvas, rect.center, loads);
        }
      }
    }
  }

  /// A BRONZE OF THE OLD CITY. Buried, it is a green-black disc you can just
  /// make out under the spoil; bare, it is cast metal with its letters
  /// showing, and the star wants all three like this at once.
  void _drawSeal(Canvas canvas, Offset at, int loads) {
    final bare = loads == 0;
    final a = bare ? 1.0 : 0.28;
    canvas.drawCircle(
      at,
      26,
      Paint()..color = const Color(0xFF4A4326).withValues(alpha: 0.55 * a),
    );
    canvas.drawCircle(
      at,
      26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = bare ? 4 : 2
        ..color = _kDustBronze.withValues(alpha: 0.9 * a),
    );
    canvas.drawCircle(
      at,
      18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _kDustBronze.withValues(alpha: 0.6 * a),
    );
    // The legend round the rim: ticks, not letters — legible at phone size
    // and not pretending to be a language.
    for (var i = 0; i < 16; i++) {
      final t = i / 16 * pi * 2;
      canvas.drawLine(
        at + Offset(cos(t), sin(t)) * 19,
        at + Offset(cos(t), sin(t)) * 25,
        Paint()
          ..strokeWidth = 1.2
          ..color = _kDustBronze.withValues(alpha: 0.45 * a),
      );
    }
    if (bare) _drawStarGlyph(canvas, at, 10, _kDustBronze);
  }

  // ── The named objects ────────────────────────────────────

  void _renderRuinsObjects(Canvas canvas, DungeonRoom room) {
    final d = room.ruins;
    if (d == null) return;
    final silt = d.gateSilt;
    if (silt != null && !entryDoorRevealed) {
      // THE SILT. It is not a plank across a doorway: it is the drift that
      // has come in through the arch and stood in it, deeper at the bottom,
      // sloping back into the room.
      final r = Rect.fromCenter(center: silt, width: 96, height: 190);
      canvas.drawPath(
        Path()
          ..moveTo(r.right, r.top)
          ..lineTo(r.right, r.bottom)
          ..lineTo(r.left - 14, r.bottom + 10)
          ..quadraticBezierTo(r.left + 10, r.center.dy, r.left + 4, r.top - 6)
          ..close(),
        Paint()..color = _kDustOchre.withValues(alpha: 0.88),
      );
      for (var i = 0; i < 5; i++) {
        canvas.drawPath(
          Path()
            ..moveTo(r.left + 10 - i * 2, r.top + 14.0 + i * 34)
            ..quadraticBezierTo(
              r.center.dx,
              r.top + 6.0 + i * 34,
              r.right - 4,
              r.top + 18.0 + i * 34,
            ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = _kDustPale.withValues(alpha: 0.35),
        );
      }
    }
    final vane = d.windVane;
    if (vane != null) {
      final armed = ruins.armedVaneRoom == room.id;
      // A MAST ON A FOOTING. It used to be a line with a line across it,
      // planted in nothing — and it is the anti-strand valve, the most
      // expensive verb on the planet.
      canvas.drawOval(
        Rect.fromCenter(center: vane.translate(0, 36), width: 34, height: 14),
        Paint()..color = _kDustStone.withValues(alpha: 0.55),
      );
      canvas.drawLine(
        vane + const Offset(0, 34),
        vane + const Offset(0, -26),
        Paint()
          ..color = const Color(0xFF6E5A34)
          ..strokeWidth = 4,
      );
      // Two guys, so the mast stands against a wind that can take a city.
      for (final s in [-1.0, 1.0]) {
        canvas.drawLine(
          vane + Offset(0, -16),
          vane + Offset(s * 20, 32),
          Paint()
            ..strokeWidth = 1.2
            ..color = const Color(0xFF6E5A34).withValues(alpha: 0.6),
        );
      }
      // The blade spins while armed, so the cost is visible before it lands.
      final spin = armed ? _time * 7.0 : _time * 0.6;
      final tip = Offset(cos(spin) * 22, sin(spin) * 8);
      canvas.drawPath(
        Path()
          ..moveTo(vane.dx + tip.dx, vane.dy - 26 + tip.dy)
          ..lineTo(vane.dx - tip.dy * 0.5, vane.dy - 26 + tip.dx * 0.5)
          ..lineTo(vane.dx - tip.dx, vane.dy - 26 - tip.dy)
          ..lineTo(vane.dx + tip.dy * 0.5, vane.dy - 26 - tip.dx * 0.5)
          ..close(),
        Paint()
          ..color = (armed ? Colors.white : _kDustPale).withValues(
            alpha: armed ? 0.95 : 0.6,
          ),
      );
      if (armed) {
        // Wound up: a ring of the wind it is about to let go.
        canvas.drawCircle(
          vane.translate(0, -26),
          30,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white.withValues(
              alpha: 0.22 + 0.16 * sin(_time * 9),
            ),
        );
      }
    }
    final rings = d.armillary;
    if (rings != null) {
      final live = ruins.stateOf('m_roof') == MoundState.bared;
      // A STAND, then the rings. An armillary sphere is an instrument on a
      // pillar, not three ovals in mid-air.
      canvas.drawRect(
        Rect.fromCenter(center: rings.translate(0, 40), width: 40, height: 12),
        Paint()..color = _kDustStone.withValues(alpha: 0.6),
      );
      canvas.drawRect(
        Rect.fromCenter(center: rings.translate(0, 26), width: 16, height: 34),
        Paint()..color = const Color(0xFF6E5A34).withValues(alpha: 0.9),
      );
      final base = live ? _kDustBronze : const Color(0xFF5A4E3C);
      // The meridian ring stands upright; the others are hung in it and turn
      // a little once there is a sky for them to read.
      final turn = live ? sin(_time * 0.35) * 0.22 : 0.0;
      for (var i = 0; i < 3; i++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: rings,
            width: (96.0 - i * 22) * (i == 2 ? 1 : cos(turn + i).abs() * 0.5 + 0.6),
            height: 40.0 + i * 20,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == 0 ? 3.4 : 2.4
            ..color = base.withValues(alpha: live ? 0.92 : 0.55),
        );
      }
      // The polar axis through it, and the little gilt sun on the ecliptic.
      canvas.drawLine(
        rings + const Offset(-14, -44),
        rings + const Offset(14, 44),
        Paint()
          ..strokeWidth = 2.2
          ..color = base.withValues(alpha: live ? 0.9 : 0.5),
      );
      if (live) {
        canvas.drawCircle(
          rings + Offset(cos(_time * 0.5) * 40, sin(_time * 0.5) * 15),
          4.5,
          Paint()..color = _kDustPale.withValues(alpha: 0.95),
        );
      }
    }
    final glass = d.glassCourt;
    if (glass != null) {
      final turned = (conduitEnergy['B'] ?? 0) > 0;
      // THE GREAT GLASS, in its frame, with sand in it. The frame is what
      // makes it an hourglass rather than a bow-tie.
      for (final y in [-42.0, 42.0]) {
        canvas.drawRect(
          Rect.fromCenter(center: glass.translate(0, y), width: 74, height: 10),
          Paint()..color = const Color(0xFF6E5A34).withValues(alpha: 0.95),
        );
      }
      for (final x in [-33.0, 33.0]) {
        canvas.drawRect(
          Rect.fromCenter(center: glass.translate(x, 0), width: 7, height: 86),
          Paint()..color = const Color(0xFF6E5A34).withValues(alpha: 0.85),
        );
      }
      final body = Path()
        ..moveTo(glass.dx - 26, glass.dy - 34)
        ..lineTo(glass.dx + 26, glass.dy - 34)
        ..lineTo(glass.dx - 26, glass.dy + 34)
        ..lineTo(glass.dx + 26, glass.dy + 34)
        ..close();
      canvas.drawPath(
        body,
        Paint()..color = const Color(0xFF9FB3C4).withValues(alpha: 0.14),
      );
      // The sand: piled in the bottom bulb, and running once the glass turns.
      canvas.drawPath(
        Path()
          ..moveTo(glass.dx - 19, glass.dy + 34)
          ..lineTo(glass.dx + 19, glass.dy + 34)
          ..lineTo(glass.dx, glass.dy + 8)
          ..close(),
        Paint()..color = _kDustOchre.withValues(alpha: 0.85),
      );
      if (turned) {
        canvas.drawLine(
          glass.translate(0, -4),
          glass.translate(0, 14),
          Paint()
            ..strokeWidth = 2.4
            ..color = _kDustPale.withValues(alpha: 0.9),
        );
      }
      canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = (turned ? Colors.white : _kDustPale).withValues(alpha: 0.8),
      );
    }
    final cut = d.hollowCut;
    if (cut != null) {
      // THE OPEN CUT. A trench with a stepped end and its own bank behind it;
      // each load the storm has shovelled back in is one visible course of
      // fill, and the fight's whole verb is getting them out again.
      final r = Rect.fromCenter(center: cut, width: 186, height: 106);
      canvas.drawPath(
        Path()
          ..moveTo(r.left - 16, r.bottom + 8)
          ..quadraticBezierTo(r.center.dx, r.bottom + 26, r.right + 16, r.bottom + 8)
          ..quadraticBezierTo(r.center.dx, r.bottom - 2, r.left - 16, r.bottom + 8)
          ..close(),
        Paint()..color = const Color(0xFF4A3A24).withValues(alpha: 0.7),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(8)),
        Paint()..color = const Color(0xFF0A0705).withValues(alpha: 0.92),
      );
      // The cut section down the far wall, so the trench has a depth you can
      // see filling up.
      const strata = [Color(0xFF6A5031), Color(0xFF3E2F1E), Color(0xFF7B5C39)];
      for (var i = 0; i < 3; i++) {
        canvas.drawRect(
          Rect.fromLTWH(r.left + 6, r.top + 5.0 + i * 6, r.width - 12, 5),
          Paint()..color = strata[i].withValues(alpha: 0.55 - i * 0.12),
        );
      }
      for (var i = 0; i < ruins.hollowPit; i++) {
        canvas.drawRect(
          Rect.fromLTWH(r.left + 8, r.bottom - 16.0 - i * 26, r.width - 16, 22),
          Paint()..color = _kDustPale.withValues(alpha: 0.62),
        );
        canvas.drawLine(
          Offset(r.left + 8, r.bottom - 16.0 - i * 26),
          Offset(r.right - 8, r.bottom - 16.0 - i * 26),
          Paint()
            ..strokeWidth = 1.6
            ..color = Colors.white.withValues(alpha: 0.35),
        );
      }
      if (ruins.hollowOpen) {
        // Held open: the lull, and the one moment the djinn can be hurt.
        canvas.drawRRect(
          RRect.fromRectAndRadius(r.inflate(5), const Radius.circular(11)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _kDustBronze.withValues(
              alpha: 0.4 + 0.25 * sin(_time * 4),
            ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────
// THE GROUND OF SABLIS — built once per room, then only read
// ─────────────────────────────────────────────────────────

/// Which deck a room is on. The streets are open sky; these six are under
/// the city, and nothing about them may look like a street (see the render
/// header's THE TWO DECKS MUST NOT LOOK ALIKE).
bool _isBelowSablis(String roomId) => const {
  'windcatch',
  'undercity',
  'granary',
  'observatory',
  'kiln_cellar',
  'sunken_house',
}.contains(roomId);

/// One mound's static shapes. The mound is the planet's whole grammar and it
/// is redrawn in three completely different silhouettes, so all three are
/// built up front rather than switched on per frame.
class _MoundGeometry {
  final List<Path> flags = [];
  Path pit = Path();
  Path lip = Path();
  Path dune = Path();
  Path duneLee = Path();
  Path crest = Path();
  final List<Path> duneRipples = [];
}

/// Every static shape one room of Sablis stands on.
class _RuinsGround {
  _RuinsGround({required this.under});

  /// True on the excavation deck.
  final bool under;

  /// Paving flags (street) or brick (below).
  final List<Path> flags = [];

  /// Sand banked in the lee of the room's edges, with its hard wind-lip and
  /// the two comb marks that stop it reading as a grey amoeba.
  final List<Path> banks = [];
  final List<Path> bankLips = [];
  final List<Path> bankCombs = [];

  /// Ripples combed across the open ground.
  final List<Path> ripples = [];
  final List<double> rippleWidth = [];

  /// Standing masonry at the room's edge: rect, and how deep its broken
  /// crown catches the light.
  final List<({Rect rect, double crown})> stubs = [];

  /// Column drums, standing in a short stack or lying where they fell.
  final List<({Offset at, double r, double lean, bool fallen})> drums = [];

  /// Sherds, brick ends and bone.
  final List<({Offset at, double a, double s, bool pale})> sherds = [];

  /// Pit props holding the excavation open.
  final List<({Offset at, double w, double h})> shores = [];

  /// Oil lamps burning in niches (excavation deck only).
  final List<Offset> lamps = [];

  /// Spoil heaps, some with the basket still beside them.
  final List<({Offset at, double w, double h, bool basket})> heaps = [];

  /// Duckboards laid over the spoil where feet go most.
  final List<Rect> boards = [];

  /// The excavation's cut face along the far wall.
  double faceHeight = 0;
  Path faceLip = Path();
  final List<({Offset at, double r, bool pale})> faceFlecks = [];

  /// The observatory's floor with the instrument moat cut out of it.
  Path? floorCut;

  /// The hole the stripped roof leaves in the observatory's ceiling.
  Path roofHole = Path();

  /// Ashdjinn's bank of spoil ringing the hollow: the heap, its lit crest,
  /// and the shadowed floor of the cut inside it.
  Path bankRing = Path();
  Path bankCrest = Path();
  Path bankInner = Path();
  final List<Path> hollowLobes = [];
  final List<Path> hollowCrests = [];

  /// The vault's mosaic, tessera by tessera.
  final List<({Rect rect, int tone})> tesserae = [];

  /// The seal yard's static shapes, by row-major cell index.
  final List<Path> yardFlags = [];
  final Map<int, Path> yardDrift = {};
  final Map<int, Path> yardHeap = {};
  final Map<int, Path> yardCrest = {};
  final Map<int, List<Path>> yardRubble = {};

  /// Every mound whose crown stands in this room.
  final Map<String, _MoundGeometry> mounds = {};
}

/// Built ONCE per room and never rebuilt: this runs at 60fps on a phone, so
/// only a lamp's flicker, the armillary's turn and the vane's blade are
/// allowed to cost anything per frame.
final Map<String, _RuinsGround> _ruinsGroundCache = {};

/// A tilted, slightly irregular quad — a paving flag, a brick, a block of
/// rubble. Never square, because nothing in a thousand-year-old floor is.
Path _dustQuad(
  Offset c,
  double w,
  double h,
  double tilt,
  double Function() rnd,
) {
  const corners = [
    Offset(-1, -1),
    Offset(1, -1),
    Offset(1, 1),
    Offset(-1, 1),
  ];
  final p = Path();
  for (var i = 0; i < 4; i++) {
    final o = Offset(
      corners[i].dx * w / 2 + (rnd() - 0.5) * 6,
      corners[i].dy * h / 2 + (rnd() - 0.5) * 5,
    );
    final q = c +
        Offset(
          o.dx * cos(tilt) - o.dy * sin(tilt),
          o.dx * sin(tilt) + o.dy * cos(tilt),
        );
    i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
  }
  return p..close();
}

/// A closed ragged curve — a bank of sand, a heap of spoil, a scoop. Drift
/// has no straight edges and no round ones either.
Path _dustBlob(
  Offset c,
  double rx,
  double ry,
  double Function() rnd, {
  double wobble = 0.3,
  int n = 11,
}) {
  final pts = <Offset>[];
  for (var i = 0; i < n; i++) {
    final a = i / n * pi * 2;
    final k = 1 + (rnd() - 0.5) * wobble * 2;
    pts.add(c + Offset(cos(a) * rx * k, sin(a) * ry * k));
  }
  final p = Path()
    ..moveTo(
      (pts[0].dx + pts[n - 1].dx) / 2,
      (pts[0].dy + pts[n - 1].dy) / 2,
    );
  for (var i = 0; i < n; i++) {
    final nx = pts[(i + 1) % n];
    p.quadraticBezierTo(
      pts[i].dx,
      pts[i].dy,
      (pts[i].dx + nx.dx) / 2,
      (pts[i].dy + nx.dy) / 2,
    );
  }
  return p..close();
}

/// Lay out one room of Sablis, once.
///
/// Deterministic from the room's own bounds, so a room looks the same every
/// time you walk into it and no two rooms look alike — and so none of this
/// costs anything after the first frame.
///
/// The one hard rule is KEEP-OUT: nothing decorative may stand on a door, a
/// mound crown, the instrument moat, a conduit, the survey yard, a named
/// object or the ground a guardian is fought on. Every room's furniture is
/// therefore pushed to the edges by construction rather than by eye, which
/// is also what keeps the hub and the arena walkable through the middle.
_RuinsGround _buildRuinsGround(DungeonRoom room) {
  final b = room.bounds.deflate(14);
  final under = _isBelowSablis(room.id);
  final g = _RuinsGround(under: under);
  var seed = (b.width * 37 + b.height * 19).toInt() | 1;
  double rnd() {
    seed = (seed * 1103515245 + 12345) & 0x3FFFFFFF;
    return (seed >> 8) / 0x3FFFFF;
  }

  final d = room.ruins;
  final keep = <Rect>[
    for (final door in room.doors) door.rect.inflate(46),
    for (final w in room.walls) w.inflate(14),
    for (final gap in room.gaps) gap.rect.inflate(14),
    for (final m in dustMoundsIn(room.id))
      Rect.fromCenter(center: m.streetPos, width: 186, height: 146),
    for (final c in room.conduits)
      Rect.fromCenter(center: c.position, width: 140, height: 140),
    if (room.vaultCache != null)
      Rect.fromCenter(center: room.vaultCache!, width: 160, height: 160),
    if (d?.field != null)
      Rect.fromLTWH(
        d!.field!.origin.dx,
        d.field!.origin.dy,
        d.field!.cols * d.field!.cell,
        d.field!.rows * d.field!.cell,
      ).inflate(34),
    if (d?.gateSilt != null)
      Rect.fromCenter(center: d!.gateSilt!, width: 150, height: 240),
    if (d?.windVane != null)
      Rect.fromCenter(center: d!.windVane!, width: 120, height: 130),
    if (d?.armillary != null)
      Rect.fromCenter(center: d!.armillary!, width: 230, height: 230),
    if (d?.glassCourt != null)
      Rect.fromCenter(center: d!.glassCourt!, width: 160, height: 180),
    if (d?.hollowCut != null)
      Rect.fromCenter(center: d!.hollowCut!, width: 260, height: 200),
  ];

  // Standing things — masonry, drums, props, heaps, lamps — additionally
  // keep out of the middle of a guardian arena and of the five-door hub, so
  // there is always somewhere to walk and fight. The FLOOR is not furniture
  // and is laid right across those, because an open centre with no paving in
  // it is just a hole in the picture — which is exactly how the undercity's
  // middle read on the first pass.
  final keepStanding = <Rect>[
    ...keep,
    if (room.guardian != null)
      Rect.fromCenter(center: room.guardian!.position, width: 520, height: 420),
    ..._ruinsFixtures(room.id, b),
  ];

  bool freeOf(List<Rect> rects, Offset p, double r) {
    final q = Rect.fromCenter(center: p, width: r * 2, height: r * 2);
    for (final k in rects) {
      if (k.overlaps(q)) return false;
    }
    return b.contains(p);
  }

  bool clear(Offset p, double r) => freeOf(keepStanding, p, r);
  bool floorClear(Offset p, double r) => freeOf(keep, p, r);

  /// Claim the ground a standing thing occupies, so the next one cannot be
  /// put on top of it.
  void take(Offset p, double w, double h) => keepStanding.add(
    Rect.fromCenter(center: p, width: w, height: h),
  );

  // ── THE CUT FACE (excavation deck only) ────────────────
  if (under) {
    g.faceHeight = room.id == 'sunken_house' ? 0 : 48;
    if (g.faceHeight > 0) {
      final y = b.top + g.faceHeight;
      // Gently: it is a hand-cut edge, not a skyline. A ±15px wander every
      // 26px turned the top of every excavation room into a mountain range.
      final lip = Path()..moveTo(b.left - 30, y - 5);
      for (var x = b.left - 30.0; x <= b.right + 30; x += 46) {
        lip.quadraticBezierTo(
          x + 23,
          y - 5 + (rnd() - 0.5) * 9,
          x + 46,
          y - 5 + (rnd() - 0.5) * 7,
        );
      }
      g.faceLip = lip
        ..lineTo(b.right + 30, y + 18)
        ..lineTo(b.left - 30, y + 18)
        ..close();
      for (var i = 0; i < 26; i++) {
        g.faceFlecks.add((
          at: Offset(
            b.left + rnd() * b.width,
            b.top + 6 + rnd() * (g.faceHeight - 14),
          ),
          r: 1.2 + rnd() * 2.2,
          pale: rnd() < 0.4,
        ));
      }
    }
  }

  // ── PAVING ─────────────────────────────────────────────
  // Courses offset row to row, every flag tilted, and — the fix that mattered
  // most — CLUSTERED. Scattering flags at an even probability over the whole
  // room gave isolated rectangles floating on a dark ground, which read as
  // cards laid on a table in every single room. Paving survives in PATCHES,
  // wherever the wind or the diggers happened not to strip it, and it fades
  // out at the edge of each patch instead of stopping.
  //
  // Ashdjinn's hollow is deliberately excluded: it is a cut in open sand and
  // never had a street in it.
  final paved = room.id != 'ashdjinn_hollow';
  final patches = <(Offset, double)>[];
  final patchCount = (b.width * b.height / 92000).clamp(3, 7).toInt();
  for (var i = 0; i < patchCount; i++) {
    patches.add((
      Offset(
        b.left + 40 + rnd() * (b.width - 80),
        b.top + g.faceHeight + 30 + rnd() * (b.height - g.faceHeight - 70),
      ),
      92 + rnd() * 132,
    ));
  }
  final fw = under ? 58.0 : 92.0;
  final fh = under ? 30.0 : 54.0;
  var course = 0;
  for (var y = b.top + g.faceHeight + 12; paved && y < b.bottom - 18; y += fh + 9) {
    final off = (course.isEven ? 0.0 : fw * 0.45) + rnd() * 14;
    for (var x = b.left + 14 + off; x < b.right - 30; x += fw + 11) {
      final c = Offset(x + fw / 2, y + fh / 2);
      var density = 0.0;
      for (final patch in patches) {
        final dist = (c - patch.$1).distance;
        if (dist < patch.$2) density = max(density, 1 - dist / patch.$2);
      }
      if (rnd() > density * 1.15) continue;
      if (!floorClear(c, fw * 0.5)) continue;
      g.flags.add(
        _dustQuad(
          c,
          fw * (0.54 + rnd() * 0.62),
          fh * (0.6 + rnd() * 0.56),
          (rnd() - 0.5) * 0.3,
          rnd,
        ),
      );
    }
    course++;
  }

  // ── SAND BANKED IN THE LEE ─────────────────────────────
  // Hugging the room's edges, never in the middle: this is the drift that
  // piles up behind whatever is standing, and it also keeps the centre open.
  final banks = (b.width * b.height / 96000).clamp(3, 7).toInt();
  for (var i = 0; i < banks; i++) {
    final edge = i % 4;
    final along = 0.1 + rnd() * 0.8;
    final c = switch (edge) {
      0 => Offset(b.left + b.width * along, b.top + 26 + rnd() * 24),
      1 => Offset(b.right - 30 - rnd() * 26, b.top + b.height * along),
      2 => Offset(b.left + b.width * along, b.bottom - 28 - rnd() * 24),
      _ => Offset(b.left + 30 + rnd() * 26, b.top + b.height * along),
    };
    final rx = 52 + rnd() * 70;
    final ry = rx * (0.26 + rnd() * 0.18);
    g.banks.add(_dustBlob(c, rx, ry, rnd, wobble: 0.22));
    g.bankLips.add(
      Path()
        ..moveTo(c.dx - rx * 0.78, c.dy + ry * 0.1)
        ..quadraticBezierTo(
          c.dx - rx * 0.1,
          c.dy - ry * 1.05,
          c.dx + rx * 0.8,
          c.dy - ry * 0.15,
        ),
    );
    for (var k = 0; k < 2; k++) {
      final dy = ry * (0.2 + k * 0.42);
      g.bankCombs.add(
        Path()
          ..moveTo(c.dx - rx * (0.6 - k * 0.16), c.dy + dy)
          ..quadraticBezierTo(
            c.dx + rx * 0.05,
            c.dy + dy - ry * 0.55,
            c.dx + rx * (0.62 - k * 0.2),
            c.dy + dy - ry * 0.08,
          ),
      );
    }
  }

  // ── RIPPLES ────────────────────────────────────────────
  // One prevailing wind, but they bunch in threes and fours and never run
  // parallel: a comb, not a ruled page.
  final bearing = (b.width > b.height ? 0.12 : 1.4) + rnd() * 0.3;
  for (var cluster = 0; cluster < 5; cluster++) {
    final ox = b.left + 40 + rnd() * (b.width - 80);
    final oy = b.top + g.faceHeight + 30 + rnd() * (b.height - g.faceHeight - 70);
    final n = 2 + (rnd() * 3).floor();
    for (var i = 0; i < n; i++) {
      final start = Offset(
        ox + (rnd() - 0.5) * 70,
        oy + i * (9 + rnd() * 8) + (rnd() - 0.5) * 10,
      );
      if (!floorClear(start, 16)) continue;
      final len = 60 + rnd() * 150;
      final amp = 5 + rnd() * 9;
      final p = Path()..moveTo(start.dx, start.dy);
      final steps = 2 + (len / 60).floor();
      for (var k = 1; k <= steps; k++) {
        final t = k / steps;
        final mid = start +
            Offset(cos(bearing), sin(bearing)) * (len * (t - 0.5 / steps)) +
            Offset(-sin(bearing), cos(bearing)) * (amp * (k.isEven ? 1 : -1));
        final end = start + Offset(cos(bearing), sin(bearing)) * (len * t);
        p.quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
      }
      g.ripples.add(p);
      g.rippleWidth.add(0.9 + rnd() * 1.5);
    }
  }

  // ── STANDING MASONRY ───────────────────────────────────
  // The street deck's skyline: wall stubs of every length, clustered along
  // the far side and thinning away, none of them the same height.
  if (!under) {
    final stubs = (b.width / 120).clamp(3, 8).toInt();
    var x = b.left + 20 + rnd() * 60;
    for (var i = 0; i < stubs; i++) {
      final w = 46 + rnd() * 96;
      final h = 22 + rnd() * 26;
      final r = Rect.fromLTWH(x, b.top + 8 + rnd() * 22, w, h);
      if (clear(r.center, max(w, h) * 0.5)) {
        g.stubs.add((rect: r, crown: 6 + rnd() * 5));
        take(r.center, w + 24, h + 24);
      }
      x += w + 30 + rnd() * 110; // gaps, not a colonnade
      if (x > b.right - 70) break;
    }
    // A couple more down the sides, so the room has three built edges — but
    // ALTERNATING sides and at wildly different sizes: three coin-flips came
    // up the same wall in the hourglass court and gave it a stack of crates.
    for (var i = 0; i < 3; i++) {
      final left = i.isEven;
      final w = 26 + rnd() * 44;
      final r = Rect.fromLTWH(
        left ? b.left + 6 : b.right - 10 - w,
        b.top + 80 + rnd() * (b.height - 180),
        w,
        38 + rnd() * 84,
      );
      if (!clear(r.center, 40)) continue;
      g.stubs.add((rect: r, crown: 6 + rnd() * 6));
      take(r.center, r.width + 24, r.height + 24);
    }
  } else {
    // Below, the masonry that shows is the tunnel's own brick piers.
    for (var i = 0; i < 3; i++) {
      final left = rnd() < 0.5;
      final r = Rect.fromLTWH(
        left ? b.left + 6 : b.right - 46 - rnd() * 14,
        b.top + g.faceHeight + 40 + rnd() * (b.height - g.faceHeight - 140),
        28 + rnd() * 16,
        60 + rnd() * 70,
      );
      if (!clear(r.center, 36)) continue;
      g.stubs.add((rect: r, crown: 5));
      take(r.center, r.width + 20, r.height + 20);
    }
  }

  // ── COLUMN DRUMS ───────────────────────────────────────
  // Mostly lying down, because in a ruin they are.
  final drums = (b.width * b.height / 78000).clamp(3, 8).toInt();
  for (var i = 0; i < drums; i++) {
    // Pushed out toward the walls: t near 0 or 1 on one axis.
    final hug = rnd() < 0.5;
    final at = Offset(
      hug
          ? b.left + 44 + rnd() * (b.width - 88)
          : (rnd() < 0.5 ? b.left + 40 + rnd() * 60 : b.right - 100 + rnd() * 60),
      hug
          ? (rnd() < 0.5
                ? b.top + g.faceHeight + 30 + rnd() * 60
                : b.bottom - 90 + rnd() * 60)
          : b.top + g.faceHeight + 40 + rnd() * (b.height - g.faceHeight - 80),
    );
    if (!clear(at, 44)) continue;
    final dr = 15 + rnd() * 10;
    g.drums.add((
      at: at,
      r: dr,
      lean: (rnd() - 0.5) * 2.6,
      fallen: rnd() < 0.68,
    ));
    take(at, dr * 5.2, dr * 4.2);
  }

  // ── SHORING, LAMPS, SPOIL, DUCKBOARDS ──────────────────
  if (under) {
    // Props stand against the face and the side walls: the excavation is
    // held open by carpentry, and the storm filling a cut is frightening
    // because you can see what is holding the rest of it up.
    final props = (b.width / 190).clamp(2, 6).toInt();
    for (var i = 0; i < props; i++) {
      final at = Offset(
        b.left + 70 + (i + rnd() * 0.5) * (b.width - 140) / props,
        b.top + g.faceHeight + 14 + rnd() * 10,
      );
      if (clear(at.translate(0, -30), 44)) {
        final sw = 54 + rnd() * 40;
        final sh = 40 + rnd() * 22;
        g.shores.add((at: at, w: sw, h: sh));
        take(at.translate(0, -sh / 2), sw + 40, sh + 30);
      }
    }
    final lamps = (b.width * b.height / 120000).clamp(2, 4).toInt();
    for (var i = 0; i < lamps; i++) {
      final at = Offset(
        b.left + 50 + rnd() * (b.width - 100),
        i.isEven ? b.top + g.faceHeight - 12 : b.bottom - 26 - rnd() * 20,
      );
      if (!clear(at, 26)) continue;
      g.lamps.add(at);
      take(at, 74, 74);
    }
    final boards = (b.width / 420).clamp(1, 3).toInt();
    for (var i = 0; i < boards; i++) {
      final y = b.top + g.faceHeight + 60 + rnd() * (b.height - g.faceHeight - 140);
      final r = Rect.fromLTWH(b.left + 30 + rnd() * 60, y, 120 + rnd() * 180, 24);
      if (!clear(r.center, 40)) continue;
      g.boards.add(r);
      take(r.center, r.width + 20, r.height + 24);
    }
  }

  final heaps = under ? 4 : 2;
  for (var i = 0; i < heaps; i++) {
    final at = Offset(
      b.left + 50 + rnd() * (b.width - 100),
      rnd() < 0.5
          ? b.top + g.faceHeight + 34 + rnd() * 26
          : b.bottom - 34 - rnd() * 30,
    );
    if (!clear(at.translate(0, -20), 42)) continue;
    final hw = 56 + rnd() * 54;
    final hh = 26 + rnd() * 22;
    g.heaps.add((at: at, w: hw, h: hh, basket: rnd() < 0.5));
    take(at.translate(0, -hh / 2), hw + 50, hh + 34);
  }

  // ── SHERDS ─────────────────────────────────────────────
  final sherds = (b.width * b.height / 17000).clamp(10, 26).toInt();
  for (var i = 0; i < sherds; i++) {
    final at = Offset(
      b.left + 20 + rnd() * (b.width - 40),
      b.top + g.faceHeight + 16 + rnd() * (b.height - g.faceHeight - 36),
    );
    if (!clear(at, 10)) continue;
    g.sherds.add((
      at: at,
      a: rnd() * pi,
      s: 4 + rnd() * 6,
      pale: rnd() < 0.35,
    ));
  }

  // ── THE OBSERVATORY'S FLOOR AND ROOF ───────────────────
  if (room.gaps.isNotEmpty) {
    var floor = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          room.bounds.deflate(8),
          const Radius.circular(34),
        ),
      );
    for (final gap in room.gaps) {
      floor = Path.combine(
        ui.PathOperation.difference,
        floor,
        Path()..addRect(gap.rect),
      );
    }
    g.floorCut = floor;
    g.roofHole = _dustBlob(
      const Offset(440, 300),
      230,
      175,
      rnd,
      wobble: 0.16,
      n: 14,
    );
  }

  // ── ASHDJINN'S BANK ────────────────────────────────────
  if (room.guardian != null) {
    final c = room.bounds.center;
    final outer = _dustBlob(c, b.width * 0.56, b.height * 0.56, rnd, wobble: 0.2, n: 13);
    // Gently wobbled: at 0.24 this came out a lopsided amoeba the size of
    // the room, which read as a puddle rather than as the floor of a cut.
    final inner = _dustBlob(c, b.width * 0.40, b.height * 0.38, rnd, wobble: 0.09, n: 17);
    g.bankRing = Path.combine(ui.PathOperation.difference, outer, inner);
    g.bankCrest = inner;
    g.bankInner = inner;
    // Barrowfuls round the rim: uneven in size, uneven in spacing, and
    // overlapping, which is the difference between a bank and a coastline.
    for (var i = 0; i < 15; i++) {
      final a = i / 15 * pi * 2 + rnd() * 0.24;
      final rr = 0.47 + rnd() * 0.06;
      final at = c + Offset(cos(a) * b.width * rr, sin(a) * b.height * rr);
      final w = 62 + rnd() * 72;
      final h = 34 + rnd() * 34;
      g.hollowLobes.add(_dustBlob(at, w / 2, h / 2, rnd, wobble: 0.26));
      g.hollowCrests.add(
        Path()
          ..moveTo(at.dx - w * 0.36, at.dy + h * 0.1)
          ..quadraticBezierTo(
            at.dx - w * 0.04,
            at.dy - h * 0.62,
            at.dx + w * 0.37,
            at.dy - h * 0.04,
          ),
      );
    }
  }

  // ── THE SURVEY YARD ────────────────────────────────────
  final f = d?.field;
  if (f != null) {
    final yard = Rect.fromLTWH(
      f.origin.dx,
      f.origin.dy,
      f.cols * f.cell,
      f.rows * f.cell,
    );
    // The street the yard is dug out of — flags under the whole thing,
    // offset course to course and heavily broken, so the drift lies ON a
    // floor rather than beside one.
    var row = 0;
    for (var y = yard.top + 8; y < yard.bottom - 10; y += 46) {
      for (var x = yard.left + (row.isEven ? 10 : 46); x < yard.right - 24; x += 74) {
        if (rnd() < 0.34) continue;
        g.yardFlags.add(
          _dustQuad(
            Offset(x + 32, y + 20),
            56 + rnd() * 22,
            32 + rnd() * 10,
            (rnd() - 0.5) * 0.14,
            rnd,
          ),
        );
      }
      row++;
    }
    for (var r = 0; r < f.rows; r++) {
      for (var c = 0; c < f.cols; c++) {
        final i = r * f.cols + c;
        final rect = f.rectAt(c, r);
        if (f.isPillar(c, r)) {
          g.yardRubble[i] = [
            for (var k = 0; k < 4; k++)
              _dustQuad(
                rect.center.translate(
                  (rnd() - 0.5) * 44,
                  (rnd() - 0.5) * 44 + 6,
                ),
                18 + rnd() * 22,
                13 + rnd() * 16,
                (rnd() - 0.5) * 1.4,
                rnd,
              ),
          ];
          continue;
        }
        // A cell's load is a HEAP lying in the square, not a coloured tile.
        g.yardDrift[i] = _dustBlob(
          rect.center.translate((rnd() - 0.5) * 7, (rnd() - 0.5) * 7),
          rect.width * 0.38,
          rect.height * 0.34,
          rnd,
          wobble: 0.26,
        );
        // A dune is BIGGER than a burial as well as paler: three heights
        // have to be three silhouettes, not three fills.
        g.yardHeap[i] = _dustBlob(
          rect.center.translate((rnd() - 0.5) * 6, -5),
          rect.width * 0.30,
          rect.height * 0.22,
          rnd,
          wobble: 0.3,
        );
        g.yardCrest[i] = Path()
          ..moveTo(rect.center.dx - rect.width * 0.3, rect.center.dy + 6)
          ..quadraticBezierTo(
            rect.center.dx - rect.width * 0.02,
            rect.center.dy - rect.height * 0.34,
            rect.center.dx + rect.width * 0.31,
            rect.center.dy - 2,
          );
      }
    }
  }

  // ── THE VAULT'S MOSAIC ─────────────────────────────────
  if (room.vaultCache != null) {
    final panel = Rect.fromCenter(
      center: room.bounds.center,
      width: 250,
      height: 176,
    ).deflate(20);
    // Only the tiles that MAKE the pattern are stored: a dark rosette at the
    // centre, a red ring round it, and a dark band two tiles in from the
    // edge. The pale field they sit in is one rectangle, drawn beneath.
    for (var y = panel.top; y < panel.bottom - 7; y += 9) {
      for (var x = panel.left; x < panel.right - 7; x += 9) {
        final dd = Offset(x, y) - panel.center;
        final rad = sqrt(dd.dx * dd.dx + dd.dy * dd.dy * 1.9);
        final edge = min(
          min(x - panel.left, panel.right - x),
          min(y - panel.top, panel.bottom - y),
        );
        final int? tone;
        if (rad < 22) {
          tone = 0;
        } else if (rad < 31) {
          tone = 1;
        } else if (edge > 14 && edge < 24) {
          tone = 0;
        } else if (rnd() < 0.05) {
          tone = 1; // a stray chip of red, so the field is not machine-made
        } else {
          tone = null;
        }
        if (tone == null) continue;
        g.tesserae.add((rect: Rect.fromLTWH(x, y, 7.4, 7.4), tone: tone));
      }
    }
  }

  // ── THE MOUNDS ─────────────────────────────────────────
  for (final m in dustMoundsIn(room.id)) {
    final r = Rect.fromCenter(center: m.streetPos, width: 132, height: 92);
    final geo = _MoundGeometry();
    // BURIED: intact paving, in two offset courses with one flag missing.
    var mrow = 0;
    for (var y = r.top + 6; y < r.bottom - 12; y += 27) {
      for (var x = r.left + (mrow.isEven ? 4 : 27); x < r.right - 22; x += 41) {
        if (rnd() < 0.3) continue; // scoured through in places
        geo.flags.add(
          _dustQuad(
            Offset(x + 19 + (rnd() - 0.5) * 8, y + 13 + (rnd() - 0.5) * 6),
            30 + rnd() * 22,
            17 + rnd() * 13,
            (rnd() - 0.5) * 0.26,
            rnd,
          ),
        );
      }
      mrow++;
    }
    // BARED: the hole, and the rim of spoil the digging threw up round it.
    geo.lip = _dustBlob(r.center, r.width * 0.52, r.height * 0.54, rnd, wobble: 0.16);
    geo.pit = _dustBlob(r.center, r.width * 0.44, r.height * 0.44, rnd, wobble: 0.13);
    // DRIFTED: a dune with a combed windward face and a hard slip face east.
    final k = 0.3 + rnd() * 0.16;
    final peak = Offset(r.left + r.width * k, r.top + 6 + rnd() * 8);
    final shoulder = Offset(r.right - 10 - rnd() * 14, r.top + 22 + rnd() * 10);
    geo.dune = Path()
      ..moveTo(r.left, r.bottom)
      ..quadraticBezierTo(r.left + r.width * k * 0.4, r.top + 30, peak.dx, peak.dy)
      ..quadraticBezierTo(
        (peak.dx + shoulder.dx) / 2,
        peak.dy - 5,
        shoulder.dx,
        shoulder.dy,
      )
      ..quadraticBezierTo(r.right + 4, r.top + 52, r.right, r.bottom)
      ..close();
    geo.duneLee = Path()
      ..moveTo(peak.dx, peak.dy)
      ..quadraticBezierTo(
        (peak.dx + shoulder.dx) / 2,
        peak.dy - 5,
        shoulder.dx,
        shoulder.dy,
      )
      ..quadraticBezierTo(r.right + 4, r.top + 52, r.right, r.bottom)
      ..lineTo(peak.dx + 8, r.bottom)
      ..close();
    geo.crest = Path()
      ..moveTo(peak.dx, peak.dy)
      ..quadraticBezierTo(
        (peak.dx + shoulder.dx) / 2,
        peak.dy - 5,
        shoulder.dx,
        shoulder.dy,
      );
    for (var i = 0; i < 4; i++) {
      final y = r.bottom - 8 - i * 13.0 - rnd() * 5;
      geo.duneRipples.add(
        Path()
          ..moveTo(r.left + 6 + i * 4, y)
          ..quadraticBezierTo(
            r.left + r.width * 0.3,
            y - 8 - i * 2,
            peak.dx + 4 + i * 6,
            y - 3,
          ),
      );
    }
    g.mounds[m.id] = geo;
  }

  return g;
}

/// The architecture each room draws by hand, as keep-out rectangles. Kept
/// beside the drawing code's own coordinates so the scatter can never bury a
/// kiln, a facade, a wind-shaft or the gate's piers.
List<Rect> _ruinsFixtures(String roomId, Rect b) => switch (roomId) {
  'ashen_gate' => [
    const Rect.fromLTWH(600, 150, 130, 200), // the piers and the springing
    const Rect.fromLTWH(78, 52, 92, 136), // the wind-tower
    Rect.fromLTRB(b.left, 228, b.right, 326), // the processional way
  ],
  'seal_street' => [const Rect.fromLTWH(186, 46, 530, 86)], // the facade
  'roof_walk' => [
    const Rect.fromLTWH(320, 400, 194, 70), // the vault crown
    const Rect.fromLTWH(656, 366, 90, 70), // the lightwell
  ],
  'high_terrace' => [
    Rect.fromLTRB(b.left, b.bottom - 70, b.right, b.bottom + 10),
    const Rect.fromLTWH(470, 224, 78, 108), // the kiln stack
    const Rect.fromLTWH(100, 92, 300, 84), // the pithoi
  ],
  'sand_court' => [
    Rect.fromCenter(center: b.center, width: 400, height: 400), // the dial
    Rect.fromLTRB(b.left, b.top + 12, b.right, b.top + 74), // the peristyle
    Rect.fromLTRB(b.left, b.bottom - 78, b.right, b.bottom - 16),
  ],
  'windcatch' => [
    const Rect.fromLTWH(150, 92, 320, 236), // the shaft
  ],
  'granary' => [
    const Rect.fromLTWH(44, 74, 100, 92),
    const Rect.fromLTWH(152, 190, 90, 86),
    const Rect.fromLTWH(274, 74, 114, 110),
    const Rect.fromLTWH(336, 222, 74, 62),
    const Rect.fromLTWH(88, 240, 66, 58),
  ],
  'kiln_cellar' => [
    const Rect.fromLTWH(52, 144, 196, 100), // the kiln dome
    const Rect.fromLTWH(88, 240, 126, 94), // its stoke-hole and ash fan
    const Rect.fromLTWH(306, 90, 148, 186), // the wasters
  ],
  'sunken_house' => [
    Rect.fromCenter(center: b.center, width: 290, height: 216), // the mosaic
    const Rect.fromLTWH(140, 14, 140, 84), // the hearth
    const Rect.fromLTWH(290, 80, 120, 60), // the shelf
    const Rect.fromLTWH(30, 230, 140, 60), // the bench
  ],
  'undercity' => [
    Rect.fromCenter(center: b.center, width: 440, height: 300), // the crossing
    Rect.fromLTRB(b.right - 60, 190, b.right + 10, 400), // the party wall
  ],
  _ => const [],
};
