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

/// Ovid, on the ruins of cities.
const String kDustNothingPerishesMaxim =
    '"All things change; nothing perishes."';

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
      MoundState.bared => 'Open trench — the paving that crossed here is gone',
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
    _setHint('The silt runs off the arch — Sablis opens its mouths');
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
      _setBlockedHint('The vane swings free — the city already lies even');
      return true;
    }
    if (ruins.armedVaneRoom != currentRoomId) {
      ruins.armedVaneRoom = currentRoomId;
      ruins.armedVaneTimer = _kVaneArmSeconds;
      // Attempt-edged and explicit: the most expensive verb on the planet
      // never fires on one careless press.
      _setHint(
        'The vane winds up — touch it again and the sirocco takes back every '
        'spadeful you have moved',
        _kVaneArmSeconds,
      );
      return true;
    }
    ruins.levelCity();
    _setHint(
      'The sirocco comes down the streets — every trench filled, every dune '
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
            'Scraped to the flags already — there is nothing '
            'here to move',
          );
          return true;
        case MoundState.drifted:
          _setBlockedHint(
            'Packed hard under its own weight — no spade bites '
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
      return 'The bump takes the spoil and settles — somewhere below, old '
          'brick gives';
    }
    if (to.rampRoomId != null) {
      return 'The heap crests over the street — and leans against the terrace '
          'wall';
    }
    if (from.cellarRoomId != null) {
      return 'The flags come up, and a dark room opens under your feet';
    }
    return 'The trench opens — and the street beyond it goes under';
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
      _setBlockedHint('Broken column — nothing rests here');
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
              ? 'Bare flags — the wind finds nothing to lift'
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
            ? 'Packed hard — a spade will not bite a dune'
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
    _setHint('Three bronzes bare at once — the old city admits its names');
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
      _setBlockedHint('The rings turn on nothing — this room has no sky');
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
        _setHint('The rings come round to the open roof — and hold there');
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
        _setBlockedHint('The rings are seized with grit — they answer Air');
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
        'The glass will not turn — it answers only a bearer of the '
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
          ? 'The cut is open again — and the djinn slows to look into it'
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
            : 'The storm rolls out over the streets — and one of your trenches '
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
          'The print goes out from under the broom — and the flags are '
          'blank',
        );
        return true;
      }
      _discoverCloud(kDustNothingPerishesEggId); // the screen pays the 20 gold
      _setHint('NOTHING PERISHES — $kDustNothingPerishesMaxim', 7.5);
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
      return 'Ashdjinn\'s Hollow — the djinn keeps the last star';
    }
    if (room.ruins?.glassCourt != null) {
      return 'The Hourglass Court — the rite waits on the glass';
    }
    if (room.ruins?.armillary != null) {
      return hasStar(room.ruins!.starIndex!)
          ? null
          : 'The Observatory — the great rings stand dark';
    }
    if (room.ruins?.field != null) {
      return hasStar(room.ruins!.starIndex!)
          ? null
          : 'The Seal Street — three bronzes lie under the drift';
    }
    if (room.vaultCache != null) {
      return 'A house nobody dug out — something is bottled here';
    }
    if (room.id == 'undercity') {
      return 'The Undercity — the drift tunnels run under every street';
    }
    if (room.ruins?.windVane != null && room.id == 'windcatch') {
      return 'The Windcatch — the tower\'s throat, and it is still breathing';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Ashen Gate — Sablis lies east, under itself'
          : 'The Ashen Gate — the arch is silted to the springing';
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
              'seal you cleared. A spade will not bite a heap — only wind lifts '
              'a crest, and the west seal is boxed where no spade can reach it',
      });
      return;
    }
    if (room.ruins?.armillary != null) {
      _setInsightHint(switch (tier) {
        0 => 'The rings are cut for a sky this room has not had in an age',
        1 =>
          'It wants the roof off above it — and the island it stands on is '
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
            'undoes it. The tower\'s vanes are the only take-backs — and the '
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
  // VISUAL GRAMMAR (§5.5): everything here reads as a HEIGHT of dry ground —
  // never as a flooding tile (Steam) or a tide line (Water). A buried mound is
  // flat ochre paving with chalk survey lines; a bared one is a scooped trench
  // with its cut SECTION showing in bands; a drifted one is a crested dune
  // with a hard wind-lip. No blur filters anywhere (the game's known jank
  // source).

  static const Color _kDustOchre = Color(0xFFC9A96A);
  static const Color _kDustPale = Color(0xFFEBD9AE);
  static const Color _kDustDeep = Color(0xFF3A2E20);
  static const Color _kDustBronze = Color(0xFFE4C16A);

  void _renderRuins(Canvas canvas, DungeonRoom room) {
    _renderDriftYard(canvas, room);
    _renderMounds(canvas, room);
    _renderRuinsObjects(canvas, room);
  }

  void _renderMounds(Canvas canvas, DungeonRoom room) {
    for (final m in dustMoundsIn(room.id)) {
      if (room.id == layout.entranceRoomId && !entryDoorRevealed) continue;
      final r = Rect.fromCenter(center: m.streetPos, width: 132, height: 92);
      switch (ruins.stateOf(m.id)) {
        case MoundState.buried:
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(6)),
            Paint()..color = _kDustOchre.withValues(alpha: 0.5),
          );
          // Chalk survey lines: this is a square somebody once measured.
          for (var i = 1; i < 3; i++) {
            canvas.drawLine(
              Offset(r.left + r.width * i / 3, r.top + 6),
              Offset(r.left + r.width * i / 3, r.bottom - 6),
              Paint()
                ..color = _kDustPale.withValues(alpha: 0.3)
                ..strokeWidth = 1.2,
            );
          }
        case MoundState.bared:
          // A scooped trench, with the cut section showing in bands.
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(4)),
            Paint()..color = _kDustDeep.withValues(alpha: 0.88),
          );
          for (var i = 0; i < 3; i++) {
            canvas.drawLine(
              Offset(r.left + 10, r.top + 20.0 + i * 18),
              Offset(r.right - 10, r.top + 20.0 + i * 18),
              Paint()
                ..color = _kDustOchre.withValues(alpha: 0.32 - i * 0.07)
                ..strokeWidth = 2.4,
            );
          }
        case MoundState.drifted:
          // A crest with a hard wind-lip — dry, angular, nothing like a flood.
          final path = Path()
            ..moveTo(r.left, r.bottom)
            ..lineTo(r.left + r.width * 0.34, r.top + 10)
            ..lineTo(r.right - 12, r.top + 26)
            ..lineTo(r.right, r.bottom)
            ..close();
          canvas.drawPath(
            path,
            Paint()..color = _kDustPale.withValues(alpha: 0.72),
          );
          canvas.drawLine(
            Offset(r.left + r.width * 0.34, r.top + 10),
            Offset(r.right - 12, r.top + 26),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.85)
              ..strokeWidth = 2.2,
          );
      }
      // An unswept print, showing only while the ground is open.
      final print = m.footprintPos;
      if (print != null &&
          ruins.stateOf(m.id) == MoundState.bared &&
          !ruins.sweptPrints.contains(m.id) &&
          !discoveredClouds.contains(kDustNothingPerishesEggId)) {
        for (var i = 0; i < 2; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: print + Offset(i * 16.0 - 8, i * 10.0),
              width: 15,
              height: 24,
            ),
            Paint()..color = _kDustDeep.withValues(alpha: 0.5),
          );
        }
      }
    }
  }

  void _renderDriftYard(Canvas canvas, DungeonRoom room) {
    final g = room.ruins?.field;
    if (g == null) return;
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        final rect = g.rectAt(c, r).deflate(3);
        if (g.isPillar(c, r)) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(8)),
            Paint()..color = const Color(0xFF4A4034),
          );
          continue;
        }
        final loads = ruins.driftAt(r * g.cols + c);
        // The depth is READ off the square, not off a line of prose: three
        // heights, three unmistakable silhouettes.
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()
            ..color = switch (loads) {
              0 => _kDustDeep.withValues(alpha: 0.8),
              1 => _kDustOchre.withValues(alpha: 0.4),
              _ => _kDustPale.withValues(alpha: 0.66),
            },
        );
        if (loads >= 2) {
          canvas.drawLine(
            rect.bottomLeft + const Offset(6, -10),
            rect.topRight + const Offset(-6, 16),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.6)
              ..strokeWidth = 2,
          );
        }
        if (g.isSeal(c, r)) {
          // Bronze under the drift: a ring, brighter the barer it gets.
          canvas.drawCircle(
            rect.center,
            rect.width * 0.3,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = loads == 0 ? 4 : 2
              ..color = _kDustBronze.withValues(alpha: loads == 0 ? 0.95 : 0.3),
          );
          if (loads == 0) {
            _drawStarGlyph(canvas, rect.center, 10, _kDustBronze);
          }
        }
      }
    }
  }

  void _renderRuinsObjects(Canvas canvas, DungeonRoom room) {
    final d = room.ruins;
    if (d == null) return;
    final silt = d.gateSilt;
    if (silt != null && !entryDoorRevealed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: silt, width: 60, height: 150),
          const Radius.circular(8),
        ),
        Paint()..color = _kDustOchre.withValues(alpha: 0.9),
      );
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          silt + Offset(-26, -50.0 + i * 40),
          silt + Offset(26, -42.0 + i * 40),
          Paint()
            ..color = _kDustPale.withValues(alpha: 0.4)
            ..strokeWidth = 2,
        );
      }
    }
    final vane = d.windVane;
    if (vane != null) {
      final armed = ruins.armedVaneRoom == room.id;
      canvas.drawLine(
        vane + const Offset(0, 34),
        vane + const Offset(0, -26),
        Paint()
          ..color = const Color(0xFF6E5A34)
          ..strokeWidth = 4,
      );
      // The blade spins while armed, so the cost is visible before it lands.
      final spin = armed ? _time * 7.0 : _time * 0.6;
      canvas.drawLine(
        vane + Offset(cos(spin) * 22, -26 + sin(spin) * 8),
        vane + Offset(-cos(spin) * 22, -26 - sin(spin) * 8),
        Paint()
          ..color = (armed ? Colors.white : _kDustPale).withValues(
            alpha: armed ? 0.95 : 0.6,
          )
          ..strokeWidth = 3,
      );
    }
    final rings = d.armillary;
    if (rings != null) {
      final live = ruins.stateOf('m_roof') == MoundState.bared;
      for (var i = 0; i < 3; i++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: rings,
            width: 96.0 - i * 22,
            height: 40.0 + i * 20,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = (live ? _kDustBronze : const Color(0xFF5A4E3C))
                .withValues(alpha: live ? 0.9 : 0.55),
        );
      }
    }
    final glass = d.glassCourt;
    if (glass != null) {
      final turned = (conduitEnergy['B'] ?? 0) > 0;
      final path = Path()
        ..moveTo(glass.dx - 26, glass.dy - 34)
        ..lineTo(glass.dx + 26, glass.dy - 34)
        ..lineTo(glass.dx - 26, glass.dy + 34)
        ..lineTo(glass.dx + 26, glass.dy + 34)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = (turned ? Colors.white : _kDustPale).withValues(alpha: 0.8),
      );
    }
    final cut = d.hollowCut;
    if (cut != null) {
      final r = Rect.fromCenter(center: cut, width: 150, height: 84);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        Paint()
          ..color = ruins.hollowOpen
              ? _kDustDeep.withValues(alpha: 0.9)
              : _kDustOchre.withValues(alpha: 0.6),
      );
      // Each load still in the cut is one visible bar of fill.
      for (var i = 0; i < ruins.hollowPit; i++) {
        canvas.drawRect(
          Rect.fromLTWH(r.left + 8, r.bottom - 14.0 - i * 22, r.width - 16, 16),
          Paint()..color = _kDustPale.withValues(alpha: 0.66),
        );
      }
    }
  }
}
