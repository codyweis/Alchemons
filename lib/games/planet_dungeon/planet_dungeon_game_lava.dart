// lib/games/planet_dungeon/planet_dungeon_game_lava.dart
//
// THE MOLTEN RELIQUARY — the Lava planet's puzzle logic + rendering, as a part
// of planet_dungeon_game.dart. The RULES and the authored line live next door
// in planet_dungeon_layout_lava.dart (pure, no engine), which is what lets
// test/planet_dungeon_lava_line_test.dart brute-force the whole thing.
//
// World rule: *the line still runs — what comes off it is what you routed it
// to be.*
//
//  • Entry — a Lava creature breaks the crucible's seal and the works wake.
//  • STAR 1 (Ember) — THE RUNNER. The mold floor is split top to bottom by
//    the line's own runner, and the star stands on the far side of it. There
//    is no bridge: you have to CAST one, which means programming the line so
//    a pour arrives at the span form as plain metal. Consequence: the mill's
//    purge is standing open, so a pour sent the wrong way comes out as
//    firedamp — a wasted charge and a room full of gas.
//  • STAR 2 (Reliquary) — THE HIDDEN MOLD (§5.5's vault trick). The key to
//    the reliquary has a mold, and it is not on the mold floor: it is
//    installed in the sump under the crucible, at the far end of the works,
//    where the tail dumps whatever the floor refused. Two pours, and the
//    ORDER of them is the puzzle: fill the mold first, because the moment you
//    lay a cold road across the sump you have plugged the very channel that
//    feeds it. Nobody tells the player that. It falls out of what cold metal
//    is (§5.5 ledger: Fire owns handed sequences — this one is DERIVED).
//  • STAR 3 (Furnace) — MAGMARA rides the heart's ring and no clock opens a
//    lull. The two heads on the ring are the line's own verb, brought into
//    the fight: throw one as it comes past and it beaches out of the channel.
//  • Egg — Black Glass: quench three pours at the font in one run; the
//    spoiled keys cool into a mirror (Heraclitus).
//
// WHY A WASTED POUR IS NOT A DEAD RUN (the deliberate call): a POUR is
// irreversible — that is the whole economy and the crucible never refills —
// but the WORLD is not. A Lava heart melts any casting back out, plug or
// ruined mold, so no misroute can ever wall the run off; it can only make it
// poorer. The budget (5) sits one clear pour above the tightest full plan (4),
// so one blunder is survivable and two is not — and stars bank the moment
// they are earned, so a spent run re-descends with its progress kept.

part of 'planet_dungeon_game.dart';

// ── Tunables (device-tunable knobs in one place) ────────────

/// How far a creature can be from a fixture and still work it.
const double _kWorksReach = 70.0;

/// How close a creature must be to the running pour to set it by hand.
const double _kChillReach = 104.0;

/// Pour travel, px/s.
const double _kPourSpeed = 100.0 / kLavaPourSecondsPer100;

/// Seconds of firedamp in the mill after a purged pour.
const double _kFiredampSeconds = 14.0;

/// Magmara's ride, radians/sec, and the window a beaching buys.
const double _kRideSpeed = 0.72;
const double _kBeachSeconds = 3.4;
const double _kHeadReach = 86.0;
const double _kHeadCatch = 170.0;
const double _kHeadCooldown = 2.2;

// ── Palette ─────────────────────────────────────────────────
//
// VISUAL GRAMMAR (§5.5): a Lava screenshot must not read as Fire. The
// cathedral is candlelight — soft warm circles, wax, drifting ash, parchment.
// The works are MACHINERY: near-black basalt, straight brick-lined troughs
// with iron sleepers laid across them, a white-hot core rather than an amber
// glow, cold castings in Ice-blue, and slag in a dead grey-green. Everything
// here is a hard edge or a right angle; nothing flickers like a candle.

/// What a runner is doing: carrying, gated off at its junction, or set solid.
enum _RunState { live, shut, plugged }

const Color _worksIron = Color(0xFF39424C);
const Color _worksIronLit = Color(0xFF5E6B78);
const Color _worksCore = Color(0xFFFFF1CF); // white-hot metal
const Color _worksEdge = Color(0xFFFF6A18); // the run's cooling edge
const Color _worksCold = Color(0xFF9FBCCC); // a set casting
const Color _worksSlag = Color(0xFF6C7A68); // dead, spoiled, wasted
const Color _worksDamp = Color(0xFFBFE07A); // firedamp

/// Everything one Lava run tracks. ONE field on the engine (like Poison's
/// monastery): the pure line state plus the handful of live/visual timers the
/// rules themselves have no business knowing about.
class MoltenWorks {
  /// The line, and everything it has been programmed into doing.
  final FoundryState line = FoundryState(kLavaLine);

  double clock = 0;

  /// Seconds of gas left in the stamp mill after a purge.
  double firedamp = 0;

  /// Magmara's angle around the heart ring, and the beaching that stops it.
  double ride = -pi / 2;
  double beached = 0;
  Offset beachedAt = Offset.zero;
  double headCool = 0;

  /// Flash on the last casting/lever touched, purely for the render.
  double flash = 0;
  Offset flashAt = Offset.zero;
}

extension MoltenReliquary on PlanetDungeonGame {
  bool get _isFoundry => layout.element == 'Lava';

  // ── Lifecycle ────────────────────────────────────────────

  void _resetFoundryState() {
    if (!_isFoundry) return;
    works.line.reset();
    works
      ..clock = 0
      ..firedamp = 0
      ..ride = -pi / 2
      ..beached = 0
      ..headCool = 0
      ..flash = 0;
  }

  // ── Per-frame update ─────────────────────────────────────

  void _updateFoundry(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isFoundry) return;
    final w = works;
    w.clock += dt;
    if (w.firedamp > 0) w.firedamp = max(0.0, w.firedamp - dt);
    if (w.headCool > 0) w.headCool -= dt;
    if (w.flash > 0) w.flash = max(0.0, w.flash - dt * 1.6);
    _advancePour(dt);
    _maybeWakeMagmara();

    // The star is simply where the line leaves you: no extra ceremony (§7).
    final spot = room.foundryStar;
    if (spot != null &&
        !hasStar(spot.starIndex) &&
        (a.position - spot.position).distance < 36) {
      earnStar(spot.starIndex);
    }
  }

  /// Walk the running pour down its channel, resolving every node it reaches.
  void _advancePour(double dt) {
    final s = works.line;
    var guard = 0;
    while (s.pour != null && guard++ < 8) {
      final p = s.pour!;
      final ch = s.line.channel(p.channelId);
      p.t += dt * _kPourSpeed / max(1.0, ch.length);
      if (p.t < 1.0) return;
      final dest = s.line.node(ch.to);
      final wasGas = p.form == PourForm.gassed;
      final event = s.arrive();
      _announcePour(
        event,
        dest,
        ch,
        gassedNow: !wasGas && dest.kind == FoundryNodeKind.vent,
      );
      if (event != PourEvent.travelling) return;
    }
  }

  void _announcePour(
    PourEvent event,
    FoundryNode dest,
    FoundryChannel via, {
    required bool gassedNow,
  }) {
    if (gassedNow) {
      // THE CONSEQUENCE (§7): the purge does exactly what a purge does, and
      // the gas it makes stays in the room with you.
      works.firedamp = _kFiredampSeconds;
      spawnWispWave(
        element: 'Steam',
        center: dest.position,
        count: 2,
        unstable: true,
        announce: false,
      );
      _setHint('The purge takes it — the charge goes off as firedamp', 3.2);
    }
    switch (event) {
      case PourEvent.travelling:
        return;
      case PourEvent.froze:
        works
          ..flash = 1.0
          ..flashAt = dest.position;
        _setHint(
          'The metal sets where it stood — a road, and a plug behind '
          'it',
        );
        _spawnAlchemyBurst(
          dest.position,
          producedElement: 'Ice',
          reagentElements: const ['Lava'],
          particleCount: 16,
          intensity: 0.7,
        );
      case PourEvent.cast:
        works
          ..flash = 1.0
          ..flashAt = dest.position;
        _setHint(switch (dest.casts) {
          'span_a' => 'The span form fills — a road across the runner',
          'gantry' => 'A key stands cast in the gantry form',
          _ => 'A key stands cast in the sump',
        }, 3.4);
        _spawnAlchemyBurst(
          dest.position,
          producedElement: 'Lava',
          particleCount: 20,
          intensity: 0.9,
        );
      case PourEvent.spoiled:
        _setHint('The form spits it back — the casting is ruined', 3.2);
        _spawnAlchemyBurst(
          dest.position,
          producedElement: 'Lava',
          unstable: true,
          particleCount: 14,
          intensity: 0.7,
        );
      case PourEvent.lost:
        _setHint(
          dest.kind == FoundryNodeKind.sink
              ? 'The charge runs off into the slag'
              : 'The charge congeals against cold metal',
          3.0,
        );
        if (via.segments.isNotEmpty) {
          _spawnAlchemyBurst(
            dest.position,
            producedElement: 'Lava',
            particleCount: 10,
            intensity: 0.5,
          );
        }
    }
    onChanged();
  }

  /// The rite is the works themselves: both stars banked and the heart gate
  /// draws back off its rails. Room-independent on purpose — the second star
  /// is banked in the reliquary, not standing in the heart.
  void _maybeWakeMagmara() {
    if (guardianAwake || hasStar(2) || !guardianRiteUnlocked) return;
    guardianAwake = true;
    guardianHp = PlanetDungeonGame.maxGuardianHp;
    _setHint('Something enormous turns over in the heart of the line', 4.2);
  }

  /// §7 GUARDIAN PRINCIPLE — Magmara fights WITH the planet's rule.
  ///
  /// It never leaves the heart's ring: the body is held on the conveyor every
  /// frame, so it can only come at you AROUND the loop, and the shared
  /// lull/rage clock never opens for it. The two heads on the ring — the same
  /// chiller and die the works are made of, fed by the heart's own overflow
  /// and costing the crucible NOTHING — are the only thing that stops it.
  /// Cast against it and it beaches; that is the window.
  void _applyMagmaraRide(DungeonRoom room, double dt) {
    final g = room.guardian;
    if (g == null || isRaid || hasStar(g.starIndex)) return;
    final e = _guardianEnemy;
    if (e == null || e.isDead) return;
    final w = works;
    if (w.beached > 0) {
      w.beached -= dt;
      e.position = w.beachedAt;
      guardianVulnerable = true; // the cast IS the lull
      return;
    }
    // Riding: no clock ever bares it.
    guardianVulnerable = false;
    final d = e.position - kLavaHeartCentre;
    w.ride = d.distance < 1 ? w.ride + dt * _kRideSpeed : atan2(d.dy, d.dx);
    e.position =
        kLavaHeartCentre + Offset(cos(w.ride), sin(w.ride)) * kLavaHeartRadius;
  }

  // ── Collision: a channel is not a floor ──────────────────

  /// RULE 1. Every trough on this planet idles hot — you cannot walk on
  /// running metal, and gliding over it is no better, so the map is cut by
  /// its own plumbing until you cast something across it.
  bool _foundryBlocksAt(Offset p, DungeonRoom room) =>
      foundryBlocks(works.line, room.id, p);

  // ── Doors ────────────────────────────────────────────────

  /// The gantry and the reliquary ward both want a key CAST to their shape.
  bool _foundryDoorLocked(DungeonRoom room, DungeonDoor door) {
    final ward = _wardIdFor(room, door);
    return ward != null && !works.line.wardsTurned.contains(ward);
  }

  /// §5.6 BLOCKED: one clause, naming what is missing — never the method.
  String _foundryDoorHint(DungeonRoom room, DungeonDoor door) =>
      _wardIdFor(room, door) == 'gantry'
      ? 'The gantry is bolted — its ward wants a key cast to it'
      : 'The reliquary ward wants a key cast to it';

  /// Which ward (if any) a door answers to, from either side.
  String? _wardIdFor(DungeonRoom room, DungeonDoor door) {
    final pair = {room.id, door.targetRoomId};
    if (pair.containsAll({'chill_house', 'mold_floor'})) return 'gantry';
    if (pair.containsAll({'mold_floor', 'slag_reliquary'})) return 'reliquary';
    return null;
  }

  // ── Verbs ────────────────────────────────────────────────

  bool _tryFoundry(DungeonCreature a) {
    if (!_isFoundry) return false;
    final room = currentRoom;
    final s = works.line;

    // 1) The crucible: the entry rite, then every charge this run — and the
    //    font, where an Ice heart can quench one mid-pour (the Black Glass).
    if (room.id == 'tap_head') {
      final tap = s.line.node('tap');
      if ((a.position - tap.position).distance <= _kWorksReach + 44) {
        return _tryCrucible(a, tap);
      }
    }

    // 2) An Ice mane sets the running metal wherever it stands. HARD GATE
    //    (§4, the planet's one) — checked before the levers so a mane racing
    //    the pour is never told about points instead.
    if (_tryHandChill(a)) return true;

    // 3) The points. Slag-seized iron: earthen strength throws them, and it
    //    is element-only — routing is the puzzle, never a family lock.
    for (final n in s.line.levers) {
      if (n.roomId != room.id) continue;
      if ((a.position - n.leverAt!).distance > _kWorksReach) continue;
      return _throwPoints(a, n);
    }

    // 4) The mill's accumulator: Ice+Lava→Steam drives the dead die (§6.2).
    if (room.id == 'stamp_mill' &&
        (a.position - kLavaAccumulator).distance <= _kWorksReach) {
      return _tryWakeDie(a);
    }

    // 5) A Lava heart melts a casting back out (RULE 5 — the world is never
    //    what ends a run).
    if (_tryRemelt(a, room)) return true;

    // 6) Take a finished key out of its form.
    for (final n in s.line.nodesIn(room.id)) {
      if (n.kind != FoundryNodeKind.mold) continue;
      if ((a.position - n.position).distance > _kWorksReach) continue;
      if (_tryTakeKey(a, n)) return true;
    }

    // 7) Turn a ward with the key in hand.
    for (final d in room.doors) {
      final ward = _wardIdFor(room, d);
      if (ward == null || s.wardsTurned.contains(ward)) continue;
      if ((a.position - d.rect.center).distance > _kWorksReach + 30) continue;
      if (s.carried != ward) continue;
      s.turnWard(ward);
      _setHint('The ward turns and the bolts run back');
      _queueDoorReveal(room.id, d.targetRoomId);
      _spawnAlchemyBurst(
        d.rect.center,
        producedElement: 'Lava',
        reagentElements: const ['Earth'],
        particleCount: 18,
        intensity: 0.8,
      );
      return true;
    }
    return false;
  }

  bool _tryCrucible(DungeonCreature a, FoundryNode tap) {
    final s = works.line;
    final el = a.member.element;

    // THE BLACK GLASS RITE (§6 egg 8): quench the font mid-pour. It costs the
    // charge AND leaves the same cold plug any other freeze does — three of
    // them is a run given up on purpose, which is the point of the maxim.
    if (s.pour != null && s.pour!.channelId == 'ch_tap') {
      if (el != 'Ice') {
        _setBlockedHint('Only Ice quenches a running font');
        return true;
      }
      s.quench();
      works
        ..flash = 1.0
        ..flashAt = tap.position;
      _spawnAlchemyBurst(
        tap.position,
        producedElement: 'Ice',
        reagentElements: const ['Lava'],
        particleCount: 20,
        intensity: 0.9,
      );
      if (s.quenches >= kLavaBlackGlassQuenches &&
          !discoveredClouds.contains(kLavaBlackGlassEggId)) {
        // THE RITE OF THREE pays this out (see `beginMaximRite`).
        _setHint('Three spoiled keys cool into one black mirror', 4.0);
        beginMaximRite(kLavaBlackGlassEggId, tap.position);
      } else {
        _setHint('The font goes black — the charge dies in the channel');
      }
      return true;
    }

    if (el != 'Lava') {
      _setBlockedHint(
        s.tapWoken
            ? 'Only Lava\'s own heat draws a charge'
            : 'Only Lava\'s own heat breaks the crucible seal',
      );
      return true;
    }
    if (!s.tapWoken) {
      s.wakeTap();
      entryDoorRevealed = true;
      _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId);
      _discoverCloud(kLavaTapRuneId);
      _setHint('The seal breaks and the whole line takes light', 4.0);
      _spawnAlchemyBurst(
        tap.position,
        producedElement: 'Lava',
        particleCount: 28,
        intensity: 1.2,
      );
      return true;
    }
    if (s.pour != null) {
      _setBlockedHint('A charge is already down the line');
      return true;
    }
    if (!s.tap()) {
      _setBlockedHint('The crucible is dry');
      return true;
    }
    _setHint('A charge runs into the line');
    _spawnAlchemyBurst(
      tap.position,
      producedElement: 'Lava',
      particleCount: 14,
      intensity: 0.7,
    );
    return true;
  }

  /// THE ONE HARD GATE (§4). An Ice MANE — the family whose whole fiction is
  /// "a cold that paves a road behind it" — sets the running pour anywhere on
  /// the line. It gates Star 2 only; Star 1 and the guardian stay earnable by
  /// any correct-element trio.
  bool _tryHandChill(DungeonCreature a) {
    final s = works.line;
    final p = s.pour;
    if (p == null) return false;
    final (roomId, at) = s.line.channel(p.channelId).pointAt(p.t);
    if (roomId != currentRoomId) return false;
    if ((a.position - at).distance > _kChillReach) return false;
    final r = evaluateInteraction(
      a.member,
      const DungeonInteractionRequirement(
        element: 'Ice',
        requiredFamily: DungeonAbility.terrainTrail,
      ),
    );
    if (r == InteractionResult.blockedFamily) {
      final gate = layout.familyGateFor('hand_chill');
      if (gate != null) {
        _stampFamilyGate(gate); // "the seal remembers" (§4)
      } else {
        _setBlockedHint(
          'Only an Ice mane\'s cold sets the metal where it '
          'runs',
        );
      }
      return true;
    }
    if (!interactionSucceeded(r)) return false; // not Ice: let other verbs try
    s.freezeHere();
    works
      ..flash = 1.0
      ..flashAt = at;
    _setHint('The pour sets under the cold — a road, and a plug behind it');
    _spawnAlchemyBurst(
      at,
      producedElement: 'Ice',
      reagentElements: const ['Lava'],
      particleCount: 18,
      intensity: 0.8,
    );
    return true;
  }

  bool _throwPoints(DungeonCreature a, FoundryNode n) {
    if (a.member.element != 'Earth') {
      _setBlockedHint('Only Earth\'s strength frees these slag-seized points');
      return true;
    }
    final s = works.line;
    if (!s.cycleSwitch(n.switchId!)) {
      _setBlockedHint('This lever hangs out over the channel');
      return true;
    }
    works
      ..flash = 1.0
      ..flashAt = n.leverAt!;
    // CONTROL FEEDBACK, not narrative: the lever says what it is set to and
    // nothing else (§5.6 — no method, no hand-holding).
    _setHint(n.switchLabels[s.settingOf(n.switchId!)], 1.6);
    return true;
  }

  bool _tryWakeDie(DungeonCreature a) {
    final s = works.line;
    if (s.dieWoken) {
      _setHint('The die is falling — it does not stop now');
      return true;
    }
    // Ice+Lava→Steam: the braid is TWO bodies at the accumulator, which is
    // what makes it a party verb rather than a keyword.
    final el = a.member.element;
    final wants = el == 'Ice' ? 'Lava' : 'Ice';
    final braid =
        (el == 'Ice' || el == 'Lava') &&
        creatures.any(
          (c) =>
              !identical(c, a) &&
              c.alive &&
              c.member.element == wants &&
              (c.position - a.position).distance < 150,
        );
    final r = evaluateInteraction(
      a.member,
      kLavaDieRequirement,
      recipeAvailable: braid,
    );
    if (!interactionSucceeded(r)) {
      _setBlockedHint('The accumulator wants steam');
      return true;
    }
    s.dieWoken = true;
    _setHint('Steam floods the accumulator — the die begins to fall', 3.4);
    _spawnAlchemyBurst(
      kLavaAccumulator,
      producedElement: 'Steam',
      reagentElements: const ['Ice', 'Lava'],
      particleCount: 24,
      intensity: 1.0,
    );
    return true;
  }

  bool _tryRemelt(DungeonCreature a, DungeonRoom room) {
    final s = works.line;
    for (final c in s.castings.values.toList()) {
      if (c.roomId != room.id) continue;
      final centre = c.rect.width > 0 ? c.rect.center : Offset.zero;
      if (c.rect.width <= 0) continue; // a carried key has no footprint
      if ((a.position - centre).distance > _kWorksReach + 20) continue;
      if (a.member.element != 'Lava') {
        _setBlockedHint('Only Lava melts a casting back out');
        return true;
      }
      s.remelt(c.id);
      works
        ..flash = 1.0
        ..flashAt = centre;
      _setHint('The casting goes back to running metal — the charge does not');
      _spawnAlchemyBurst(
        centre,
        producedElement: 'Lava',
        particleCount: 18,
        intensity: 0.8,
      );
      return true;
    }
    return false;
  }

  bool _tryTakeKey(DungeonCreature a, FoundryNode mold) {
    final s = works.line;
    final what = s.molds[mold.id];
    if (what == null) return false;
    if (what == 'span_a') return false; // a road is not carried
    // A ruined key has no footprint on the floor for the re-melt sweep to
    // find, so the form itself is where a Lava hand takes it back out.
    if (!s.cast(what)) {
      if (a.member.element != 'Lava') {
        _setBlockedHint('Only slag in this form — and only Lava melts it out');
        return true;
      }
      s.remelt('cast:$what');
      _setHint('The ruined key goes back to running metal');
      _spawnAlchemyBurst(
        mold.position,
        producedElement: 'Lava',
        particleCount: 16,
        intensity: 0.7,
      );
      return true;
    }
    if (s.carried != null) {
      _setBlockedHint('Your hands are already full');
      return true;
    }
    s.takeKey(mold.id);
    _setHint(
      what == 'gantry'
          ? 'The gantry key comes out of the sand, still ticking'
          : 'The reliquary key comes out of the sand, still ticking',
    );
    return true;
  }

  /// THE FIGHT'S VERB (§7). Throwing a head as Magmara comes past beaches it;
  /// throwing it into empty channel just clangs. Costs no charge — the heart
  /// feeds these off its own overflow, so an empty crucible can never strand
  /// the finale.
  bool _tryHeartHead(DungeonCreature a) {
    if (!_isFoundry) return false;
    final room = currentRoom;
    final g = room.guardian;
    if (g == null || !guardianAwake || hasStar(g.starIndex)) return false;
    for (final head in kLavaHeartHeads) {
      if ((a.position - head).distance > _kHeadReach) continue;
      final w = works;
      if (w.headCool > 0) {
        _setHint('The head is still coming back up');
        return true;
      }
      w.headCool = _kHeadCooldown;
      final e = _guardianEnemy;
      final beast = e != null && !e.isDead ? e.position : g.position;
      if ((beast - head).distance > _kHeadCatch) {
        _setHint('The head falls on empty channel');
        return true;
      }
      w
        ..beached = _kBeachSeconds
        ..beachedAt = beast
        ..flash = 1.0
        ..flashAt = head;
      guardianVulnerable = true;
      _setHint('The head catches it — Magmara beaches out of the channel', 3.0);
      _spawnAlchemyBurst(
        beast,
        producedElement: 'Ice',
        reagentElements: const ['Lava'],
        particleCount: 22,
        intensity: 1.0,
      );
      return true;
    }
    return false;
  }

  // ── Hints (§5.6) ─────────────────────────────────────────

  /// OBJECTIVE — one line on room entry, WHAT and never HOW.
  /// WHAT YOU ARE TRYING TO DO HERE — and it has to be a goal, not a view.
  ///
  /// Every one of these used to be an observation: *"the line forks under the
  /// foreman's board"*, *"the north channel cuts the house in two"*. All true,
  /// all scenery. Reported from play as knowing what everything WAS and not
  /// what any of it was FOR. A room can be perfectly legible and still leave
  /// you with no idea why you are standing in it.
  ///
  /// So they name the thing you want, they change as you get it, and the
  /// first one you ever read frames the whole planet. Still no method: what
  /// you want, never how — that is the hint button's job (§5.6).
  String? _foundryObjectiveHint(DungeonRoom room) {
    final s = works.line;
    switch (room.id) {
      case 'tap_head':
        // The entrance, so this is the planet's own statement of purpose.
        if (!s.tapWoken) {
          return 'Nothing leaves this works that was not cast here — and '
              'you have five pours to cast it';
        }
        if (s.carried == 'reliquary') {
          return 'You have the reliquary key — its ward is on the mould floor';
        }
        if (s.molds.containsKey('mold_reliquary')) {
          return 'Something has filled the form on the far side of the sump';
        }
        return hasStar(1)
            ? null
            : 'The works drain into a sump you cannot cross';
      case 'switch_yard':
        return 'Set the whole road before you spend a pour — there are five, '
            'and the line gives none back';
      case 'chill_house':
        return s.wardsTurned.contains('gantry')
            ? 'The gantry stands open to the mould floor'
            : 'The gantry to the mould floor is bolted — its ward wants a key';
      case 'stamp_mill':
        return s.dieWoken
            ? 'The die falls on everything that passes down this arm'
            : 'The mill\'s die hangs dead — nothing here can ward a pour yet';
      case 'mold_floor':
        if (!hasStar(0)) {
          return s.cast('span_a')
              ? 'The span is laid — the Ember Star is across it'
              : 'The Ember Star stands across the runner, and nothing walks '
                    'on running metal';
        }
        if (!s.wardsTurned.contains('reliquary')) {
          return 'The reliquary ward is bolted, and no key on this floor '
              'was ever cut for it';
        }
        return null;
      case 'slag_reliquary':
        return hasStar(1)
            ? null
            : 'The Reliquary Star, and what it was kept for';
      case 'pour_heart':
        return 'Something enormous rides the heart\'s ring';
    }
    return null;
  }

  /// AMBIENT — atmosphere only: no mechanics, no stats, no families (§5.6).
  void _foundryAmbientHint(DungeonCreature a, DungeonRoom room) {
    switch (room.id) {
      case 'tap_head':
        _setAmbientHint('The crucible ticks, and never quite cools');
      case 'chill_house':
        _setAmbientHint('Frost climbs the rails a little way, then gives up');
      case 'mold_floor':
        _setAmbientHint('The runner throws its light along the ceiling');
      case 'stamp_mill':
        _setAmbientHint('Somewhere in the dark the mill is counting');
      case 'slag_reliquary':
        _setAmbientHint('Cold sand, and the smell of old iron');
      case 'pour_heart':
        _setAmbientHint('The floor is warm straight through your feet');
    }
  }

  /// INSIGHT — the earned how-to, and the ONLY channel allowed to teach
  /// method (§5.6). Tier 0 says a thing is true; tier 1 says what it means;
  /// tier 2 names the consequence you would otherwise learn by losing a pour.
  void _foundryReveal(DungeonCreature a, DungeonRoom room) {
    revealFlash = 0.6;
    revealTier = revealHintTier(a.member.statIntelligence);
    final t = revealTier;
    switch (room.id) {
      case 'switch_yard':
        // The foreman's manifest: the works' own tectonic inventory. This is
        // where Star 2 stops being a secret and starts being a plan.
        _setInsightHint(switch (t) {
          0 => 'The manifest counts one more mold than this floor holds',
          1 =>
            'The die wards whatever takes the MILL arm; the chill arm '
                'runs plain',
          _ =>
            'The missing form is installed in the sump under the crucible, '
                'and only the tail feeds it',
        });
      case 'tap_head':
        _setInsightHint(switch (t) {
          0 => 'The sump takes back everything the floor refuses',
          1 => 'There is a form at the end of it, cut for a key',
          _ =>
            'Fill it before you lay any road across the sump — cold metal '
                'stops everything behind it',
        });
      case 'chill_house':
        _setInsightHint(
          t < 1
              ? 'Cold metal is a road'
              : 'A road, and a plug: nothing follows it up this arm',
        );
      case 'stamp_mill':
        _setInsightHint(
          t < 1
              ? 'The die is dead iron, and the purge is standing open'
              : 'Steam drives the die, and once driven it never sleeps again',
        );
      case 'mold_floor':
        _setInsightHint(
          t < 1
              ? 'Every form wants one kind of metal'
              : 'Plain metal fills the span; only warded metal makes a key',
        );
      case 'pour_heart':
        _setInsightHint(
          'It cannot leave the ring — and the heads on the ring '
          'are the works\' own hands',
        );
      default:
        _setInsightHint('Nothing here reads back');
    }
  }

  /// PROGRESS READOUT (§5.6) — state leaves the capsule and stands where the
  /// player can check it at will. The pour budget is the run's whole economy,
  /// so it is never allowed to be a line that fades.
  DungeonProgressReadout? get _foundryProgressReadout {
    final s = works.line;
    if (!s.tapWoken) return null;
    final key = s.carried;
    if (key != null) {
      return DungeonProgressReadout(
        label: 'KEY',
        value: key == 'gantry' ? 'GANTRY' : 'RELIQUARY',
      );
    }
    final p = s.pour;
    if (p != null) {
      return DungeonProgressReadout(
        label: 'POUR',
        value: switch (p.form) {
          PourForm.plain => 'PLAIN',
          PourForm.stamped => 'WARDED',
          PourForm.gassed => 'GAS',
        },
      );
    }
    return DungeonProgressReadout(
      label: 'POURS',
      value: '${s.poursLeft} of $kLavaPourBudget',
      fraction: (s.poursLeft / kLavaPourBudget).clamp(0.0, 1.0),
    );
  }

  double get _foundryMoodTarget => switch (currentRoomId) {
    'pour_heart' => 0.14,
    'slag_reliquary' => 0.2,
    'mold_floor' => 0.3,
    _ => 0.26,
  };

  // ── Render ───────────────────────────────────────────────
  //
  // See the palette note above: hard-edged machinery, white-hot cores, iron
  // sleepers. Nothing here is drawn with a blur (the per-frame MaskFilter
  // rule) and nothing off-screen is drawn at all.

  void _renderFoundry(Canvas canvas, DungeonRoom room) {
    _renderWorksFloor(canvas, room);
    _renderChannels(canvas, room);
    _renderWorksBridges(canvas, room);
    _renderCastings(canvas, room);
    _renderFixtures(canvas, room);
    _renderPourBead(canvas, room);
    if (room.id == 'stamp_mill' && works.firedamp > 0) {
      _renderFiredamp(canvas, room);
    }
    if (room.guardian != null) _renderHeartRing(canvas, room);
    final spot = room.foundryStar;
    if (spot != null && !hasStar(spot.starIndex)) {
      _renderWorksStar(canvas, spot.position);
    }
  }

  /// A CRUST WITH SOMETHING UNDER IT. The floor of this works is not a floor
  /// that was laid — it is the top of a flow that stopped, and it has not
  /// finished cooling. Black basalt, split by a network of fissures with heat
  /// still in them, breathing.
  ///
  /// It has been wrong twice, the same way both times. First a 96px ruled
  /// GRID; then cast-iron plates in running bond, which was better material
  /// and still a lattice — reported from play as *"too tiley"*, and the note
  /// that matters with it: **it needs to look dangerous.** Regular anything
  /// reads as safe, because regularity is what people build. A room you are
  /// meant to be careful in cannot be tiled.
  void _renderWorksFloor(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    // Heat from below: the ground is darkest where it is thickest, and the
    // glow rises toward the bottom of the room where the flow is shallow.
    canvas.drawRect(
      b,
      Paint()
        ..shader = ui.Gradient.linear(
          b.topCenter,
          b.bottomCenter,
          const [Color(0xFF0A0907), Color(0xFF16100C), Color(0xFF241410)],
          const [0.0, 0.55, 1.0],
        ),
    );

    // Deterministic per room, so nothing crawls between frames.
    var seed = room.id.codeUnits.fold<int>(97, (a, c) => (a * 131 + c) % 65521);
    double rnd() {
      seed = (seed * 1103515245 + 12345) % 2147483648;
      return seed / 2147483648;
    }

    final pulse = 0.5 + 0.5 * sin(works.clock * 0.8);

    // COOLED PLATES OF CRUST — irregular polygons, not tiles. Each is a
    // slightly different black, and none of them share an edge direction.
    for (var i = 0; i < 26; i++) {
      final cx = b.left + rnd() * b.width;
      final cy = b.top + rnd() * b.height;
      final rx = 70 + rnd() * 130;
      final ry = 50 + rnd() * 90;
      final rot = rnd() * pi;
      final sides = 5 + (rnd() * 3).floor();
      final path = Path();
      for (var k = 0; k <= sides; k++) {
        final a = rot + k * 2 * pi / sides;
        final wob = 0.72 + rnd() * 0.5;
        final pt = Offset(cx + cos(a) * rx * wob, cy + sin(a) * ry * wob);
        k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF15120F),
            const Color(0xFF0B0A09),
            rnd(),
          )!,
      );
    }

    // THE FISSURES. Wandering cracks with heat in them — parted dark
    // shoulders, a bright seam, each breathing on its own phase.
    //
    // The first cut of these ran nearly straight and nearly as long as the
    // room, which came out as a game of pick-up-sticks: rock does not split
    // in straight lines that long. They meander now, over more and shorter
    // steps, and the big ones throw off branches, because a crack that
    // forks is the difference between a fissure and a scratch.
    void crack(Offset from, double len, double angle, double heat, int idx) {
      final steps = 7;
      var at = from;
      var a = angle;
      final pts = <Offset>[at];
      for (var k = 0; k < steps; k++) {
        a += (rnd() - 0.5) * 0.8; // it wanders as it goes
        at = at + Offset(cos(a), sin(a)) * (len / steps);
        pts.add(at);
      }
      final breath = 0.55 + 0.45 * sin(works.clock * (0.5 + heat) + idx * 1.3);
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final pt in pts.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      // Thin and mostly DEAD. Uniformly thick, uniformly bright cracks
      // read as painted worms; a crust is mostly cold, and what makes the
      // hot ones frightening is that they are the exception.
      final w = 1.6 + 4.2 * heat * heat;
      // The parted shoulders.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w + 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF070605).withValues(alpha: 0.9),
      );
      // The bloom, faked with a wide low-alpha pass — no blur filter, which
      // is this repo's main source of per-frame jank.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w + 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _worksEdge.withValues(alpha: 0.05 + 0.09 * heat * breath),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Color.lerp(
            const Color(0xFF3A1304),
            _worksEdge,
            heat * heat * breath,
          )!.withValues(alpha: 0.42 + 0.42 * heat),
      );
      if (heat > 0.55) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(
              _worksEdge,
              _worksCore,
              0.5 * breath,
            )!.withValues(alpha: 0.45 * heat),
        );
      }
      // A branch off the middle of the bigger ones.
      if (len > 120 && idx % 3 != 2) {
        // Recurses exactly one level: a branch is 0.45 of its parent and
        // the longest parent is 200, so the child is always under the 120
        // that gates this.
        crack(
          pts[3],
          len * 0.45,
          a + (rnd() < 0.5 ? 1.1 : -1.1),
          heat * 0.7,
          idx + 41,
        );
      }
    }

    for (var i = 0; i < 34; i++) {
      crack(
        Offset(b.left + rnd() * b.width, b.top + rnd() * b.height),
        70 + rnd() * 130,
        rnd() * 2 * pi,
        // Skewed low: a few fissures carry real heat and most are scars.
        pow(rnd(), 1.7).toDouble(),
        i,
      );
    }

    // ASH AND CINDER on top of it all, so the crust is not clean.
    for (var i = 0; i < 30; i++) {
      final at = Offset(b.left + rnd() * b.width, b.top + rnd() * b.height);
      canvas.drawCircle(
        at,
        2.0 + rnd() * 5,
        Paint()
          ..color = const Color(
            0xFF2A241E,
          ).withValues(alpha: 0.35 + rnd() * 0.3),
      );
    }

    // The runs are hotter than anything around them, and the ground knows.
    for (final ch in works.line.line.channelsIn(room.id)) {
      for (final seg in ch.segments) {
        if (seg.roomId != room.id) continue;
        canvas.drawRect(
          seg.rect.inflate(34),
          Paint()..color = const Color(0xFF491A08).withValues(alpha: 0.18),
        );
        canvas.drawRect(
          seg.rect.inflate(15),
          Paint()..color = const Color(0xFF5E2109).withValues(alpha: 0.22),
        );
      }
    }

    // EMBERS drifting up off the crust. A handful, cheap, and the thing that
    // makes a still image of this floor read as a place that is still burning.
    for (var i = 0; i < 16; i++) {
      final ex = b.left + rnd() * b.width;
      final base = b.top + rnd() * b.height;
      final t = ((works.clock * (0.10 + 0.06 * (i % 4)) + i / 16) % 1.0);
      canvas.drawCircle(
        Offset(ex + sin(t * 5 + i) * 9, base - 54 * t),
        1.6 + 1.4 * (1 - t),
        Paint()
          ..color = Color.lerp(
            _worksCore,
            _worksEdge,
            t,
          )!.withValues(alpha: 0.42 * (1 - t) * pulse),
      );
    }
  }

  /// THE WALKWAYS. A plate laid over a runner, with handrails, so the party
  /// crosses where the works meant them to.
  ///
  /// These are why the line can be laid out honestly at all. Without them a
  /// channel is an absolute wall and every arm that reaches a wall fences off
  /// part of it — which is what made the switch yard's fork unreadable
  /// through three separate re-plumbings, each one trading one confusion for
  /// another. With a crossing, the junction can sit in the MIDDLE of the room
  /// and each arm can run to the wall its own door is in. Signs were the
  /// wrong answer to that; this is the right one.
  void _renderWorksBridges(Canvas canvas, DungeonRoom room) {
    for (final b in works.line.line.bridgesIn(room.id)) {
      final r = b.rect;
      final acrossX = r.width >= r.height;
      // The deck.
      _ironPlate(canvas, r, radius: 2);
      final grate = Paint()
        ..strokeWidth = 2
        ..color = const Color(0xFF10141A).withValues(alpha: 0.7);
      if (acrossX) {
        for (var x = r.left + 7; x < r.right - 4; x += 9) {
          canvas.drawLine(Offset(x, r.top + 4), Offset(x, r.bottom - 4), grate);
        }
      } else {
        for (var y = r.top + 7; y < r.bottom - 4; y += 9) {
          canvas.drawLine(Offset(r.left + 4, y), Offset(r.right - 4, y), grate);
        }
      }
      // Handrails down the two long sides — the thing that says WALK HERE
      // rather than "a lid someone left on the trough".
      final rail = Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = _worksIronLit;
      final posts = Paint()..color = const Color(0xFF8898A6);
      if (acrossX) {
        for (final y in [r.top - 5.0, r.bottom + 5.0]) {
          canvas.drawLine(Offset(r.left + 3, y), Offset(r.right - 3, y), rail);
          for (var x = r.left + 5; x < r.right - 2; x += 18) {
            canvas.drawCircle(Offset(x, y), 2.2, posts);
          }
        }
      } else {
        for (final x in [r.left - 5.0, r.right + 5.0]) {
          canvas.drawLine(Offset(x, r.top + 3), Offset(x, r.bottom - 3), rail);
          for (var y = r.top + 5; y < r.bottom - 2; y += 18) {
            canvas.drawCircle(Offset(x, y), 2.2, posts);
          }
        }
      }
    }
  }

  /// Is this channel actually going to carry metal right now?
  ///
  /// Three states, and the room used to draw all three identically — every
  /// channel hot, flowing and glowing whether or not a pour could ever go
  /// down it. That is the worst thing this planet did to a player: a plugged
  /// arm silently EATS a pour (`_leaveBy`: "it congeals against cold metal
  /// and is simply gone"), one of only five, and the floor said the arm was
  /// open right up until the metal vanished into it.
  ///
  /// State, not method (§5.6). The reading still teaches what cold metal DOES;
  /// the floor now shows where it already is.
  _RunState _runStateOf(FoundryChannel ch) {
    final s = works.line;
    if (s.plugged(ch.id)) return _RunState.plugged;
    final from = s.line.node(ch.from);
    final sw = from.switchId;
    if (sw != null && from.exits.length > 1) {
      final pick = s.settingOf(sw).clamp(0, from.exits.length - 1);
      if (from.exits[pick] != ch.id) return _RunState.shut;
    }
    return _RunState.live;
  }

  /// A RUNNER, and it RUNS. Refractory lip, a crust with the bright body
  /// showing through it, and bands travelling the way the metal actually
  /// goes — the segment model already knows (`reverse`), and until now that
  /// knowledge never reached the screen.
  ///
  /// That direction is the single most useful thing this planet can draw. The
  /// whole puzzle is re-routing a line; a player who can see which way each
  /// runner carries can read the route off the floor instead of guessing it
  /// at a lever. It replaces flat fill plus tick marks, which said "channel"
  /// and nothing else.
  void _renderChannels(Canvas canvas, DungeonRoom room) {
    final s = works.line;
    final pulse = 0.5 + 0.5 * sin(works.clock * 1.4);
    for (final ch in s.line.channelsIn(room.id)) {
      final state = _runStateOf(ch);
      for (final seg in ch.segments) {
        if (seg.roomId != room.id) continue;
        final r = seg.rect;
        final horiz = seg.horizontal;

        // REFRACTORY LIP — firebrick, laid in courses along the run, with a
        // lit inner edge where the heat has glazed it.
        canvas.drawRect(r.inflate(9), Paint()..color = const Color(0xFF15181B));
        canvas.drawRect(r.inflate(7), Paint()..color = const Color(0xFF2C2620));
        final course = Paint()
          ..strokeWidth = 1
          ..color = const Color(0xFF15110D).withValues(alpha: 0.8);
        final span = horiz ? r.width : r.height;
        for (var k = 22.0; k < span; k += 26) {
          if (horiz) {
            canvas.drawLine(
              Offset(r.left + k, r.top - 7),
              Offset(r.left + k, r.top - 1),
              course,
            );
            canvas.drawLine(
              Offset(r.left + k, r.bottom + 1),
              Offset(r.left + k, r.bottom + 7),
              course,
            );
          } else {
            canvas.drawLine(
              Offset(r.left - 7, r.top + k),
              Offset(r.left - 1, r.top + k),
              course,
            );
            canvas.drawLine(
              Offset(r.right + 1, r.top + k),
              Offset(r.right + 7, r.top + k),
              course,
            );
          }
        }
        // The glaze: hot brick right at the metal.
        canvas.drawRect(
          r.inflate(2),
          Paint()..color = const Color(0xFF6B3411).withValues(alpha: 0.85),
        );

        // PLUGGED: set solid, and it looks it. Cold blue-grey metal filling
        // the trough end to end, with the shrinkage crack down the middle
        // that cooling metal always leaves. Nothing runs here again.
        if (state == _RunState.plugged) {
          canvas.drawRect(r, Paint()..color = const Color(0xFF3C4A55));
          canvas.drawRect(
            horiz
                ? Rect.fromLTWH(r.left, r.center.dy - 1.5, r.width, 3)
                : Rect.fromLTWH(r.center.dx - 1.5, r.top, 3, r.height),
            Paint()..color = const Color(0xFF232C34),
          );
          canvas.drawRect(
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = _worksCold.withValues(alpha: 0.55),
          );
          continue;
        }

        // THE METAL. A dark crust with the body burning through it, not a
        // flat orange bar.
        canvas.drawRect(r, Paint()..color = const Color(0xFF6E2408));
        canvas.save();
        canvas.clipRect(r);
        canvas.drawRect(
          r,
          Paint()
            ..shader = ui.Gradient.linear(
              horiz ? r.topCenter : r.centerLeft,
              horiz ? r.bottomCenter : r.centerRight,
              [
                const Color(0xFF4E1704),
                const Color(0xFF9C3A0A),
                Color.lerp(_worksEdge, _worksCore, 0.52 + 0.22 * pulse)!,
                const Color(0xFF9C3A0A),
                const Color(0xFF4E1704),
              ],
              // A NARROW hot core with cooling shoulders. An even three-stop
              // ramp made the whole runner one mid-orange, which reads as
              // copper pipe rather than as metal that is burning.
              const [0.0, 0.30, 0.5, 0.70, 1.0],
            ),
        );

        // TRAVELLING BANDS — the flow, and its DIRECTION. `reverse` means the
        // metal runs the other way down this segment, so the bands do too.
        // A SHUT branch has none: its junction is not sending anything this
        // way, and a still runner beside a moving one is the clearest thing
        // this planet can say about which route is set.
        final dir = seg.reverse ? -1.0 : 1.0;
        for (var i = 0; state == _RunState.live && i < 6; i++) {
          final t = ((works.clock * 0.22 * dir + i / 6) % 1.0 + 1.0) % 1.0;
          final at = span * t;
          final a = 0.30 * sin(t * pi).clamp(0.0, 1.0);
          final band = Paint()
            ..color = _worksCore.withValues(alpha: a)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round;
          if (horiz) {
            canvas.drawLine(
              Offset(r.left + at, r.top + 2),
              Offset(r.left + at + 9 * dir, r.bottom - 2),
              band,
            );
          } else {
            canvas.drawLine(
              Offset(r.left + 2, r.top + at),
              Offset(r.right - 2, r.top + at + 9 * dir),
              band,
            );
          }
        }
        // CRUST: cooled skin riding the surface. Evenly spaced slabs of one
        // length read as conveyor treads — a ladder laid in the trough — so
        // the spacing and the length both vary, deterministically, and the
        // skin never covers the same fraction twice running.
        final skin = Paint()
          ..color = const Color(0xFF23100A).withValues(alpha: 0.62);
        // Slabs that do not all reach both banks: some ride the near side,
        // some the far, some the whole width. Full-width pills of one length
        // read as sausage links; skin breaks unevenly and the metal shows
        // past it, which is the whole reason to draw skin at all.
        final thick = horiz ? r.height : r.width;
        var k = 10.0;
        var i = 0;
        while (k < span) {
          final len = 8.0 + ((i * 37) % 9) * 4.0;
          final side = (i * 29) % 3; // 0 near bank, 1 far bank, 2 full
          final near = side == 1 ? thick * 0.42 : 3.0;
          final far = side == 0 ? thick * 0.42 : 3.0;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              horiz
                  ? Rect.fromLTWH(
                      r.left + k,
                      r.top + near,
                      len,
                      thick - near - far,
                    )
                  : Rect.fromLTWH(
                      r.left + near,
                      r.top + k,
                      thick - near - far,
                      len,
                    ),
              const Radius.circular(2.5),
            ),
            skin,
          );
          k += len + 9.0 + ((i * 53) % 7) * 5.0;
          i++;
        }
        // A shut arm is standing metal: darker, and no longer glowing.
        if (state == _RunState.shut) {
          canvas.drawRect(
            r,
            Paint()..color = const Color(0xFF120A06).withValues(alpha: 0.55),
          );
        }
        canvas.restore();

        // The hot rim, brightest where the metal meets its brick.
        canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _worksCore.withValues(
              alpha: state == _RunState.live ? 0.28 + 0.14 * pulse : 0.10,
            ),
        );
        if (state == _RunState.live && _fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            r.center,
            (horiz ? r.width : r.height) * 0.42,
            _worksEdge.withValues(alpha: 0.10),
          );
        }
      }
    }
  }

  /// Castings: cold, blue-grey, hard-edged. A spoiled one is slag.
  void _renderCastings(Canvas canvas, DungeonRoom room) {
    for (final c in works.line.castings.values) {
      if (c.roomId != room.id || c.rect.width <= 0) continue;
      final body = c.spoiled ? _worksSlag : _worksCold;
      canvas.drawRRect(
        RRect.fromRectAndRadius(c.rect, const Radius.circular(5)),
        Paint()..color = body,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(c.rect.deflate(4), const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = c.spoiled
              ? const Color(0xFF3E463C)
              : const Color(0xFFD6EEF8).withValues(alpha: 0.55),
      );
      if (!c.spoiled && _fx.ready) {
        drawGlow(canvas, _fx.glow!, c.rect.center, 34, const Color(0x2288D8F0));
      }
    }
  }

  /// A PLATE OF IRON with a bevel, which is what every fixture on this planet
  /// is made of. Flat single-colour rectangles read as placeholder geometry;
  /// a lit top lip and a shadowed foot are the whole difference between a
  /// grey box and a thing cast in a works.
  void _ironPlate(
    Canvas canvas,
    Rect r, {
    double radius = 3,
    bool lit = false,
  }) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(rr, Paint()..color = lit ? _worksIronLit : _worksIron);
    canvas.drawRect(
      Rect.fromLTWH(r.left + 2, r.top, r.width - 4, 2.5),
      Paint()
        ..color = const Color(0xFF7C8B99).withValues(alpha: lit ? 0.8 : 0.5),
    );
    canvas.drawRect(
      Rect.fromLTWH(r.left + 2, r.bottom - 2.5, r.width - 4, 2.5),
      Paint()..color = const Color(0xFF0C0F12).withValues(alpha: 0.7),
    );
  }

  void _rivets(Canvas canvas, Rect r, {double inset = 7}) {
    final paint = Paint()
      ..color = const Color(0xFF778796).withValues(alpha: 0.6);
    for (final o in [
      Offset(r.left + inset, r.top + inset),
      Offset(r.right - inset, r.top + inset),
      Offset(r.left + inset, r.bottom - inset),
      Offset(r.right - inset, r.bottom - inset),
    ]) {
      canvas.drawCircle(o, 2.0, paint);
    }
  }

  /// The stations, the molds and the levers — each with its own silhouette so
  /// the line can be read at a glance instead of memorised.
  ///
  /// The silhouettes were right from the start and are untouched. What they
  /// had no trace of was MATERIAL: a crucible, a drop hammer, a purge cowl
  /// and an accumulator were four flat grey rectangles and one flat green
  /// triangle, which is a diagram of a foundry rather than a foundry.
  void _renderFixtures(Canvas canvas, DungeonRoom room) {
    final s = works.line;
    final iron = Paint()..color = _worksIron;
    for (final n in s.line.nodesIn(room.id)) {
      final p = n.position;
      switch (n.kind) {
        case FoundryNodeKind.source:
          // THE CRUCIBLE: a bellied vessel hung in a trunnion frame, with a
          // pouring lip. The frame is what says it can be TIPPED, which is
          // what a crucible is for.
          for (final side in const [-1.0, 1.0]) {
            _ironPlate(
              canvas,
              Rect.fromLTWH(p.dx + side * 56 - 5, p.dy - 76, 10, 82),
            );
          }
          final belly = Rect.fromCenter(
            center: p - const Offset(0, 34),
            width: 96,
            height: 60,
          );
          canvas.drawPath(
            Path()
              ..moveTo(belly.left, belly.top)
              ..lineTo(belly.right, belly.top)
              ..lineTo(belly.right - 9, belly.bottom)
              ..lineTo(belly.left + 9, belly.bottom)
              ..close(),
            iron,
          );
          canvas.drawRect(
            Rect.fromLTWH(belly.left - 4, belly.top - 7, belly.width + 8, 9),
            Paint()..color = _worksIronLit,
          );
          _rivets(canvas, belly, inset: 13);
          // Trunnion pins.
          for (final side in const [-1.0, 1.0]) {
            canvas.drawCircle(
              Offset(p.dx + side * 52, belly.center.dy),
              6,
              Paint()..color = _worksIronLit,
            );
          }
          // The spout, and what comes out of it.
          canvas.drawRect(
            Rect.fromCenter(
              center: p - const Offset(0, 4),
              width: 26,
              height: 30,
            ),
            Paint()..color = s.tapWoken ? _worksCore : const Color(0xFF1B2026),
          );
          if (s.tapWoken) {
            canvas.drawRect(
              Rect.fromCenter(
                center: p + const Offset(0, 14),
                width: 14,
                height: 26,
              ),
              Paint()..color = _worksEdge.withValues(alpha: 0.85),
            );
            if (_fx.ready) {
              drawGlow(canvas, _fx.glow!, p, 52, const Color(0x55FF7A22));
            }
          }
        case FoundryNodeKind.chiller:
          // THE SHROUD: a corrugated hood on two rails, with stops. Down, it
          // frosts; up, it is just iron in the roof.
          final down = s.settingOf('chiller') == 1;
          for (final side in const [-56.0, 50.0]) {
            _ironPlate(canvas, Rect.fromLTWH(p.dx + side, p.dy - 84, 7, 84));
            for (var y = p.dy - 76.0; y < p.dy; y += 18) {
              canvas.drawRect(
                Rect.fromLTWH(p.dx + side - 3, y, 13, 3),
                Paint()
                  ..color = const Color(0xFF6E7C89).withValues(alpha: 0.55),
              );
            }
          }
          final hood = Rect.fromCenter(
            center: Offset(p.dx, p.dy - (down ? 6 : 46)),
            width: 112,
            height: 34,
          );
          _ironPlate(canvas, hood, radius: 5, lit: down);
          final corr = Paint()
            ..strokeWidth = 2
            ..color = const Color(0xFF10141A).withValues(alpha: 0.55);
          for (var x = hood.left + 9; x < hood.right - 4; x += 11) {
            canvas.drawLine(
              Offset(x, hood.top + 5),
              Offset(x, hood.bottom - 5),
              corr,
            );
          }
          if (down) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                hood.inflate(4),
                const Radius.circular(7),
              ),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = _worksCold.withValues(alpha: 0.85),
            );
            // Frost feathering off the lip — the only cold thing on the planet.
            for (var i = 0; i < 7; i++) {
              final x = hood.left + 12 + i * (hood.width - 24) / 6;
              canvas.drawLine(
                Offset(x, hood.bottom),
                Offset(x + (i.isEven ? 4 : -4), hood.bottom + 9),
                Paint()
                  ..strokeWidth = 2
                  ..color = _worksCold.withValues(alpha: 0.5),
              );
            }
          }
        case FoundryNodeKind.stamper:
          // THE DROP HAMMER: two guide columns with collars, a crown, and a
          // tup that rides between them.
          for (final side in const [-44.0, 36.0]) {
            _ironPlate(canvas, Rect.fromLTWH(p.dx + side, p.dy - 104, 8, 104));
            canvas.drawRect(
              Rect.fromLTWH(p.dx + side - 3, p.dy - 62, 14, 6),
              Paint()..color = _worksIronLit,
            );
          }
          final crown = Rect.fromLTWH(p.dx - 52, p.dy - 116, 104, 14);
          _ironPlate(canvas, crown, radius: 3);
          _rivets(canvas, crown, inset: 9);
          final lift = s.dieWoken
              ? 10 * (0.5 + 0.5 * sin(works.clock * 6))
              : 0.0;
          final tup = Rect.fromCenter(
            center: Offset(p.dx, p.dy - 44 + lift),
            width: 74,
            height: 46,
          );
          _ironPlate(canvas, tup, radius: 2, lit: s.dieWoken);
          _rivets(canvas, tup, inset: 10);
          // The die face — the part that actually hits metal.
          canvas.drawRect(
            Rect.fromLTWH(tup.left + 8, tup.bottom - 5, tup.width - 16, 5),
            Paint()
              ..color = s.dieWoken
                  ? const Color(0xFFBFD4E2)
                  : const Color(0xFF1A1F24),
          );
          // THE ACCUMULATOR: a riveted pressure vessel with hoop bands.
          final acc = Rect.fromCenter(
            center: kLavaAccumulator,
            width: 46,
            height: 66,
          );
          _ironPlate(canvas, acc, radius: 10);
          for (var y = acc.top + 14; y < acc.bottom - 8; y += 17) {
            canvas.drawRect(
              Rect.fromLTWH(acc.left - 3, y, acc.width + 6, 4),
              Paint()..color = _worksIronLit.withValues(alpha: 0.8),
            );
          }
          canvas.drawCircle(
            Offset(acc.center.dx, acc.top + 9),
            5,
            Paint()
              ..color = s.dieWoken
                  ? const Color(0xFFBFE0EA)
                  : const Color(0xFF12161A),
          );
          if (s.dieWoken && _fx.ready) {
            drawGlow(
              canvas,
              _fx.glow!,
              kLavaAccumulator,
              30,
              const Color(0x44BFE0EA),
            );
          }
        case FoundryNodeKind.vent:
          // THE PURGE COWL: a hooded stack with louvres, not a flat triangle
          // — which is what it was, and it read as a Christmas tree.
          final open = s.settingOf('damper') == 1;
          canvas.drawPath(
            Path()
              ..moveTo(p.dx - 40, p.dy + 20)
              ..lineTo(p.dx - 17, p.dy - 30)
              ..lineTo(p.dx + 17, p.dy - 30)
              ..lineTo(p.dx + 40, p.dy + 20)
              ..close(),
            iron,
          );
          _ironPlate(
            canvas,
            Rect.fromLTWH(p.dx - 19, p.dy - 62, 38, 34),
            radius: 2,
          );
          // Louvres: shut they are dark slots, open they show the flue.
          for (var i = 0; i < 4; i++) {
            final y = p.dy - 24 + i * 11.0;
            final half = 34 - i * 5.0;
            canvas.drawRect(
              Rect.fromLTRB(p.dx - half, y, p.dx + half, y + 5),
              Paint()
                ..color = open
                    ? _worksDamp.withValues(alpha: 0.55)
                    : const Color(0xFF12161A),
            );
          }
          canvas.drawRect(
            Rect.fromLTWH(p.dx - 44, p.dy + 20, 88, 7),
            Paint()..color = _worksIronLit,
          );
        case FoundryNodeKind.mold:
          _renderMold(canvas, n);
        case FoundryNodeKind.sink:
          // THE SLAG PIT: a ragged crusted rim round a dark hole. An oval on
          // an oval read as a puddle; slag cools in lumps.
          final rim = Path();
          for (var i = 0; i <= 16; i++) {
            final a = i * 2 * pi / 16;
            final wob = 1.0 + 0.12 * sin(i * 2.7);
            final pt = p + Offset(cos(a) * 62 * wob, sin(a) * 38 * wob);
            i == 0 ? rim.moveTo(pt.dx, pt.dy) : rim.lineTo(pt.dx, pt.dy);
          }
          rim.close();
          canvas.drawPath(
            rim,
            Paint()..color = _worksSlag.withValues(alpha: 0.9),
          );
          canvas.drawPath(
            rim,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFF3D473C),
          );
          canvas.drawOval(
            Rect.fromCenter(center: p, width: 88, height: 48),
            Paint()..color = const Color(0xFF171C18),
          );
          // Lumps of cold slag on the rim.
          for (var i = 0; i < 6; i++) {
            final a = i * 2 * pi / 6 + 0.4;
            canvas.drawCircle(
              p + Offset(cos(a) * 56, sin(a) * 34),
              4.0 + (i % 3),
              Paint()..color = const Color(0xFF525E50),
            );
          }
        case FoundryNodeKind.junction:
          // THE GATE ITSELF. A junction used to be nothing on the floor —
          // just a place two troughs met, with the answer only on the lever's
          // plate a few paces away. It is a real switch now: a pivot on the
          // rock and a paddle swung ACROSS the mouth of every arm it is not
          // feeding, so the route is a thing you see rather than a word you
          // read.
          canvas.drawCircle(p, 9, Paint()..color = _worksIron);
          canvas.drawCircle(
            p,
            9,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = _worksIronLit,
          );
          final pick = s
              .settingOf(n.switchId ?? '')
              .clamp(0, max(0, n.exits.length - 1));
          for (var e = 0; e < n.exits.length; e++) {
            final ch = s.line.channel(n.exits[e]);
            final seg = ch.segments.first;
            // The direction the arm LEAVES IN, taken along the segment
            // itself. Measuring from the node to the segment's start point
            // gave a zero vector whenever an arm begins exactly on its
            // junction — which is most of them — so the shut paddle was
            // skipped on precisely the arms it most needed to appear on.
            final a0 = seg.pointAt(0.0);
            final a1 = seg.pointAt(0.12);
            final d = a1 - a0;
            if (d.distance < 1) continue;
            final u = d / d.distance;
            final at = a0 + u * 22;
            if (e == pick) {
              // Open: the paddle is swung back along the arm, out of the way.
              canvas.drawLine(
                at - Offset(-u.dy, u.dx) * 3,
                at + u * 16 - Offset(-u.dy, u.dx) * 3,
                Paint()
                  ..strokeWidth = 5
                  ..strokeCap = StrokeCap.round
                  ..color = _worksIronLit,
              );
            } else {
              // Shut: the paddle lies ACROSS the mouth, and it is cold iron
              // against a dead arm.
              final n2 = Offset(-u.dy, u.dx);
              canvas.drawLine(
                at - n2 * 17,
                at + n2 * 17,
                Paint()
                  ..strokeWidth = 8
                  ..strokeCap = StrokeCap.round
                  ..color = _worksIron,
              );
              canvas.drawLine(
                at - n2 * 17,
                at + n2 * 17,
                Paint()
                  ..strokeWidth = 3
                  ..strokeCap = StrokeCap.round
                  ..color = const Color(0xFF7C8B99).withValues(alpha: 0.7),
              );
            }
          }
        case FoundryNodeKind.relay:
          break;
      }
      // THE LEVER, if this node has one: a cast stand, a notched quadrant
      // with one notch per setting, and a handle in the notch it is actually
      // in. The quadrant is the point — you can see how many ways this switch
      // goes, and which way it is set, without throwing it to find out.
      final lever = n.leverAt;
      if (lever != null) {
        final set = s.settingOf(n.switchId!);
        final ways = max(1, n.switchLabels.length);
        _ironPlate(
          canvas,
          Rect.fromCenter(
            center: lever + const Offset(0, 15),
            width: 40,
            height: 14,
          ),
        );
        final quad = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = _worksIron;
        canvas.drawArc(
          Rect.fromCircle(center: lever + const Offset(0, 10), radius: 26),
          pi + 0.45,
          pi - 0.9,
          false,
          quad,
        );
        for (var i = 0; i < ways; i++) {
          final a = pi + 0.45 + (pi - 0.9) * (ways == 1 ? 0.5 : i / (ways - 1));
          final at = lever + const Offset(0, 10) + Offset(cos(a), sin(a)) * 26;
          canvas.drawCircle(
            at,
            3.0,
            Paint()
              ..color = i == set
                  ? const Color(0xFFFFC98A)
                  : _worksIronLit.withValues(alpha: 0.7),
          );
        }
        final ang =
            pi + 0.45 + (pi - 0.9) * (ways == 1 ? 0.5 : set / (ways - 1));
        final tip =
            lever + const Offset(0, 10) + Offset(cos(ang), sin(ang)) * 32;
        canvas.drawLine(
          lever + const Offset(0, 10),
          tip,
          Paint()
            ..color = _worksIronLit
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(tip, 5, Paint()..color = const Color(0xFF8E5A34));
        _drawTinyLabel(
          canvas,
          lever + const Offset(0, 34),
          n.switchLabels[set.clamp(0, n.switchLabels.length - 1)],
        );
      }
    }
  }

  void _renderMold(Canvas canvas, FoundryNode n) {
    final s = works.line;
    final held = s.molds[n.id];
    final cavity = Rect.fromCenter(center: n.position, width: 76, height: 52);
    // THE FLASK: the two-part box a sand mold is rammed up in, with corner
    // clamps holding the halves together. A plain dark rect said nothing
    // about how casting works.
    _ironPlate(canvas, cavity.inflate(7), radius: 2);
    canvas.drawRect(cavity, Paint()..color = const Color(0xFF2A2119)); // sand
    // The parting line across the middle of the flask.
    canvas.drawLine(
      Offset(cavity.left - 7, cavity.center.dy),
      Offset(cavity.right + 7, cavity.center.dy),
      Paint()
        ..strokeWidth = 1.5
        ..color = const Color(0xFF11151A).withValues(alpha: 0.8),
    );
    for (final o in [
      cavity.topLeft,
      cavity.topRight,
      cavity.bottomLeft,
      cavity.bottomRight,
    ]) {
      canvas.drawRect(
        Rect.fromCenter(center: o, width: 10, height: 10),
        Paint()..color = _worksIronLit.withValues(alpha: 0.75),
      );
    }
    if (held == null) {
      // AN EMPTY CAVITY, CUT TO THE SHAPE IT ACCEPTS.
      //
      // Both molds used to draw the same dark rectangle, so a form that
      // takes PLAIN metal and a form that takes WARDED metal were visually
      // identical — standing between them you could not tell which was
      // which, and a puzzle whose whole question is "what do you cast, and
      // in what order" felt like guessing. The insight line has always said
      // *"every form wants one kind of metal"*; the floor never showed WHICH.
      //
      // Now the cavity is cut to its form and tinted the colour that form
      // runs down the channel as, so the bead you are watching and the mold
      // it is heading for are the same colour.
      final want = n.wants ?? PourForm.plain;
      final tint = switch (want) {
        PourForm.plain => _worksCore,
        PourForm.stamped => const Color(0xFFFFD98A),
        PourForm.gassed => _worksDamp,
      };
      final inner = cavity.deflate(10);
      canvas.drawRect(inner, Paint()..color = const Color(0xFF15110C));
      if (want == PourForm.stamped) {
        // A KEY'S WARDS: teeth cut into the cavity. Warded metal is the only
        // thing shaped like this, and it looks like the thing it makes.
        final tooth = Paint()..color = const Color(0xFF15110C);
        final lit = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = tint.withValues(alpha: 0.6);
        final bit = Rect.fromLTWH(
          inner.left,
          inner.center.dy - 7,
          inner.width,
          14,
        );
        canvas.drawRect(bit, tooth);
        canvas.drawRect(bit, lit);
        for (var k = 0; k < 3; k++) {
          final tx = inner.left + 10 + k * 15.0;
          final t = Rect.fromLTWH(tx, inner.center.dy - 18, 9, 12);
          canvas.drawRect(t, tooth);
          canvas.drawRect(t, lit);
        }
        canvas.drawOval(
          Rect.fromCircle(
            center: Offset(inner.right - 9, inner.center.dy),
            radius: 9,
          ),
          tooth,
        );
        canvas.drawOval(
          Rect.fromCircle(
            center: Offset(inner.right - 9, inner.center.dy),
            radius: 9,
          ),
          lit,
        );
      } else {
        // A PLAIN SLAB: a smooth bar, which is what a span is.
        canvas.drawRect(
          inner.deflate(4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = tint.withValues(alpha: 0.55),
        );
      }
      canvas.drawRect(
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = tint.withValues(alpha: 0.34),
      );
      // The sprue — where the metal would come in.
      canvas.drawRect(
        Rect.fromLTWH(cavity.center.dx - 4, cavity.top - 7, 8, 9),
        Paint()..color = const Color(0xFF15110C),
      );
      return;
    }
    final spoiled = !s.cast(held);
    canvas.drawRect(
      cavity.deflate(8),
      Paint()..color = spoiled ? _worksSlag : _worksCold,
    );
    canvas.drawRect(
      cavity.deflate(8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = spoiled
            ? const Color(0xFF3E463C)
            : const Color(0xFFDCF0FA).withValues(alpha: 0.7),
    );
    if (!spoiled && _fx.ready) {
      drawGlow(canvas, _fx.glow!, n.position, 30, const Color(0x3388D8F0));
    }
  }

  void _renderPourBead(Canvas canvas, DungeonRoom room) {
    final s = works.line;
    final p = s.pour;
    if (p == null) return;
    final ch = s.line.channel(p.channelId);
    final (roomId, at) = ch.pointAt(p.t);
    if (roomId != room.id) return;
    final colour = switch (p.form) {
      PourForm.plain => _worksCore,
      PourForm.stamped => const Color(0xFFFFD98A),
      PourForm.gassed => _worksDamp,
    };
    // The tail: three fading beads back along the channel.
    for (var k = 3; k >= 1; k--) {
      final (r2, back) = ch.pointAt((p.t - k * 0.018).clamp(0.0, 1.0));
      if (r2 != room.id) continue;
      canvas.drawCircle(
        back,
        10.0 - k * 1.6,
        Paint()..color = colour.withValues(alpha: 0.20 * (4 - k)),
      );
    }
    canvas.drawCircle(at, 12, Paint()..color = colour);
    if (_fx.ready) {
      drawGlow(canvas, _fx.glow!, at, 46, colour.withValues(alpha: 0.42));
    }
  }

  void _renderFiredamp(Canvas canvas, DungeonRoom room) {
    if (!_fx.ready) return;
    final a = (works.firedamp / _kFiredampSeconds).clamp(0.0, 1.0);
    final vent = works.line.line.node('vent').position;
    for (var i = 0; i < 5; i++) {
      final t = works.clock * 0.5 + i * 1.3;
      final p =
          vent +
          Offset(sin(t) * (40 + i * 26), -((works.clock * 16 + i * 60) % 190));
      drawGlow(
        canvas,
        _fx.glow!,
        p,
        34 + i * 4.0,
        _worksDamp.withValues(alpha: 0.10 * a),
      );
    }
  }

  /// The heart: one ring conveyor, and the two heads that stop what rides it.
  /// THE HEART: a circular runner, and it runs the same way every other
  /// runner on this planet does. It was drawn in the old flat style — one
  /// orange stroke with grey ticks laid across it — which by the end of the
  /// art pass was the only thing left in the works that still looked like a
  /// diagram, in the one room the player fights in.
  void _renderHeartRing(Canvas canvas, DungeonRoom room) {
    final pulse = 0.5 + 0.5 * sin(works.clock * 1.6);
    const r = kLavaHeartRadius;
    final c = kLavaHeartCentre;

    // Refractory ring, and the courses of brick that make it up.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 42
        ..color = const Color(0xFF15181B),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 36
        ..color = const Color(0xFF2C2620),
    );
    final course = Paint()
      ..strokeWidth = 1
      ..color = const Color(0xFF15110D).withValues(alpha: 0.85);
    for (var k = 0; k < 64; k++) {
      final a = k * pi / 32;
      final d = Offset(cos(a), sin(a));
      canvas.drawLine(c + d * (r + 11), c + d * (r + 18), course);
      canvas.drawLine(c + d * (r - 18), c + d * (r - 11), course);
    }
    // The glaze where brick meets metal.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..color = const Color(0xFF6B3411),
    );

    // The metal: cooling shoulders, a narrow burning core.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..color = const Color(0xFF6E2408),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..color = const Color(0xFF9C3A0A),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Color.lerp(_worksEdge, _worksCore, 0.52 + 0.22 * pulse)!,
    );

    // Broken crust riding round, uneven, some of it only on one bank.
    final skin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFF23100A).withValues(alpha: 0.62);
    for (var i = 0; i < 22; i++) {
      final a0 = i * 2 * pi / 22;
      final span = 0.05 + ((i * 37) % 7) * 0.012;
      skin.strokeWidth = (i % 3 == 2) ? 20 : 10;
      final off = (i % 3 == 0) ? 5.0 : ((i % 3 == 1) ? -5.0 : 0.0);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r + off),
        a0,
        span,
        false,
        skin,
      );
    }

    // And it FLOWS — bands travelling round the ring, so the heart reads as
    // circulating metal rather than as a drawn circle.
    for (var i = 0; i < 9; i++) {
      final t = ((works.clock * 0.06 + i / 9) % 1.0);
      final a = t * 2 * pi;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a,
        0.10,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 16
          ..color = _worksCore.withValues(alpha: 0.16),
      );
    }

    // THE POUR HEADS: launders on the rim, live or cooling.
    for (final head in kLavaHeartHeads) {
      final live = works.headCool <= 0;
      final body = Rect.fromCenter(center: head, width: 84, height: 34);
      _ironPlate(canvas, body, radius: 3, lit: live);
      _rivets(canvas, body, inset: 9);
      _ironPlate(
        canvas,
        Rect.fromCenter(
          center: head - const Offset(0, 30),
          width: 24,
          height: 36,
        ),
        radius: 2,
      );
      // The lip: bright while it can pour, dark while it is cooling off.
      canvas.drawRect(
        Rect.fromLTWH(body.left + 6, body.bottom - 5, body.width - 12, 5),
        Paint()..color = live ? _worksCore : const Color(0xFF1A1F24),
      );
      if (live && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          head,
          40,
          _worksEdge.withValues(alpha: 0.22),
        );
      }
    }
    if (works.beached > 0 && _fx.ready) {
      drawGlow(canvas, _fx.glow!, works.beachedAt, 90, const Color(0x3AA8E6F5));
    }
  }

  /// THE STAR IS AN INGOT — the thing this works exists to make, still hot,
  /// stamped, standing on a pallet. It was a flat trapezoid, which is the
  /// SHAPE of an ingot and none of the substance: no top face, no thickness,
  /// no heat. On a planet whose entire fiction is casting, the reward has to
  /// look like the product.
  void _renderWorksStar(Canvas canvas, Offset at) {
    final pulse = 0.5 + 0.5 * sin(works.clock * 2.2);
    if (_fx.ready) {
      drawGlow(canvas, _fx.glow!, at, 58 + 10 * pulse, const Color(0x55FFB24A));
    }
    // The pallet it was set down on.
    _ironPlate(
      canvas,
      Rect.fromCenter(center: at + const Offset(0, 22), width: 62, height: 10),
    );

    final hot = Color.lerp(_worksEdge, _worksCore, 0.34 + 0.22 * pulse)!;
    // The near face: a wedge, wider at the foot, as a cast bar is.
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - 26, at.dy + 17)
        ..lineTo(at.dx - 19, at.dy - 7)
        ..lineTo(at.dx + 19, at.dy - 7)
        ..lineTo(at.dx + 26, at.dy + 17)
        ..close(),
      Paint()..color = hot,
    );
    // The top face, brighter and set back — this is what makes it a SOLID.
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - 19, at.dy - 7)
        ..lineTo(at.dx - 11, at.dy - 19)
        ..lineTo(at.dx + 27, at.dy - 19)
        ..lineTo(at.dx + 19, at.dy - 7)
        ..close(),
      Paint()..color = Color.lerp(hot, _worksCore, 0.55)!,
    );
    // The far side, in shadow.
    canvas.drawPath(
      Path()
        ..moveTo(at.dx + 19, at.dy - 7)
        ..lineTo(at.dx + 27, at.dy - 19)
        ..lineTo(at.dx + 33, at.dy + 12)
        ..lineTo(at.dx + 26, at.dy + 17)
        ..close(),
      Paint()..color = Color.lerp(hot, const Color(0xFF6E2408), 0.55)!,
    );
    // The founder's mark, stamped into the top while it was soft.
    canvas.drawCircle(
      at + const Offset(4, -13),
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF7A3208).withValues(alpha: 0.8),
    );
    // Heat coming off it.
    for (var i = 0; i < 3; i++) {
      final t = ((works.clock * 0.5 + i / 3) % 1.0);
      canvas.drawLine(
        Offset(at.dx - 14 + i * 14, at.dy - 22 - 14 * t),
        Offset(at.dx - 11 + i * 14, at.dy - 32 - 14 * t),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = _worksCore.withValues(alpha: 0.30 * (1 - t)),
      );
    }
  }
}
