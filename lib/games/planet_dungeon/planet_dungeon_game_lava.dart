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

const Color _worksBasalt = Color(0xFF14181C);
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
        _discoverCloud(kLavaBlackGlassEggId); // the screen pays the 20 gold
        _setHint(
          'Three spoiled keys cool into one black mirror. $kLavaBlackGlassMaxim',
          7.5,
        );
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
  String? _foundryObjectiveHint(DungeonRoom room) {
    final s = works.line;
    switch (room.id) {
      case 'tap_head':
        if (!s.tapWoken) return 'The crucible sits sealed and cold';
        return hasStar(1)
            ? null
            : 'The works drain into a sump you cannot cross';
      case 'switch_yard':
        return 'The line forks under the foreman\'s board';
      case 'chill_house':
        return 'The north channel cuts the house in two';
      case 'stamp_mill':
        return s.dieWoken
            ? 'The die falls on everything that passes'
            : 'The mill\'s die hangs dead over the channel';
      case 'mold_floor':
        return 'The Ember Star stands across the runner';
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
            'The die wards whatever takes the south arm; the north arm '
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

  /// Basalt flags with an iron grid — a floor that was poured, not laid.
  void _renderWorksFloor(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    canvas.drawRect(
      b,
      Paint()
        ..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, const [
          Color(0xFF191E24),
          Color(0xFF0E1216),
        ]),
    );
    final seam = Paint()
      ..color = const Color(0x18708090)
      ..strokeWidth = 1.0;
    const step = 96.0;
    for (var x = b.left + step; x < b.right; x += step) {
      canvas.drawLine(Offset(x, b.top + 10), Offset(x, b.bottom - 10), seam);
    }
    for (var y = b.top + step; y < b.bottom; y += step) {
      canvas.drawLine(Offset(b.left + 10, y), Offset(b.right - 10, y), seam);
    }
  }

  /// A trough: black brick lip, white-hot run, iron sleepers laid across it.
  void _renderChannels(Canvas canvas, DungeonRoom room) {
    final s = works.line;
    final pulse = 0.5 + 0.5 * sin(works.clock * 1.4);
    for (final ch in s.line.channelsIn(room.id)) {
      for (final seg in ch.segments) {
        if (seg.roomId != room.id) continue;
        final r = seg.rect;
        canvas.drawRect(r.inflate(5), Paint()..color = _worksBasalt);
        canvas.drawRect(
          r.deflate(3),
          Paint()
            ..color = Color.lerp(_worksEdge, _worksCore, 0.25 + 0.2 * pulse)!,
        );
        canvas.drawRect(
          seg.horizontal
              ? Rect.fromLTWH(r.left, r.center.dy - 3, r.width, 6)
              : Rect.fromLTWH(r.center.dx - 3, r.top, 6, r.height),
          Paint()..color = _worksCore.withValues(alpha: 0.75),
        );
        // Sleepers: the geometry that makes this read as plant, not lava-flow.
        final bars = Paint()
          ..color = _worksIron
          ..strokeWidth = 3;
        final span = seg.horizontal ? r.width : r.height;
        final n = (span / 44).floor().clamp(1, 40);
        for (var k = 1; k < n; k++) {
          if (seg.horizontal) {
            final x = r.left + span * k / n;
            canvas.drawLine(
              Offset(x, r.top - 4),
              Offset(x, r.bottom + 4),
              bars,
            );
          } else {
            final y = r.top + span * k / n;
            canvas.drawLine(
              Offset(r.left - 4, y),
              Offset(r.right + 4, y),
              bars,
            );
          }
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

  /// The stations, the molds and the levers — each with its own silhouette so
  /// the line can be read at a glance instead of memorised.
  void _renderFixtures(Canvas canvas, DungeonRoom room) {
    final s = works.line;
    final iron = Paint()..color = _worksIron;
    final lit = Paint()..color = _worksIronLit;
    for (final n in s.line.nodesIn(room.id)) {
      final p = n.position;
      switch (n.kind) {
        case FoundryNodeKind.source:
          // The crucible: a squat iron vessel over the font.
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: p - const Offset(0, 34),
                width: 96,
                height: 56,
              ),
              const Radius.circular(8),
            ),
            iron,
          );
          canvas.drawRect(
            Rect.fromCenter(
              center: p - const Offset(0, 4),
              width: 22,
              height: 26,
            ),
            Paint()..color = s.tapWoken ? _worksCore : _worksIronLit,
          );
          if (s.tapWoken && _fx.ready) {
            drawGlow(canvas, _fx.glow!, p, 44, const Color(0x40FF7A22));
          }
        case FoundryNodeKind.chiller:
          // The shroud: a hood on rails, down or up.
          final down = s.settingOf('chiller') == 1;
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(p.dx, p.dy - (down ? 6 : 44)),
              width: 108,
              height: 30,
            ),
            down ? (Paint()..color = _worksCold) : iron,
          );
          canvas.drawRect(Rect.fromLTWH(p.dx - 56, p.dy - 78, 6, 78), lit);
          canvas.drawRect(Rect.fromLTWH(p.dx + 50, p.dy - 78, 6, 78), lit);
        case FoundryNodeKind.stamper:
          // The die: a hammer block over the channel, live or dead.
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(
                p.dx,
                p.dy -
                    44 +
                    (s.dieWoken ? 10 * (0.5 + 0.5 * sin(works.clock * 6)) : 0),
              ),
              width: 74,
              height: 46,
            ),
            s.dieWoken ? lit : iron,
          );
          canvas.drawRect(Rect.fromLTWH(p.dx - 46, p.dy - 96, 92, 10), iron);
          if (!s.dieWoken) {
            canvas.drawRect(
              Rect.fromCenter(center: kLavaAccumulator, width: 46, height: 62),
              iron,
            );
          } else if (_fx.ready) {
            drawGlow(
              canvas,
              _fx.glow!,
              kLavaAccumulator,
              26,
              const Color(0x33BFE0EA),
            );
          }
        case FoundryNodeKind.vent:
          // The purge cowl, always audibly open or shut.
          final open = s.settingOf('damper') == 1;
          canvas.drawPath(
            Path()
              ..moveTo(p.dx - 34, p.dy + 16)
              ..lineTo(p.dx, p.dy - 34)
              ..lineTo(p.dx + 34, p.dy + 16)
              ..close(),
            open ? (Paint()..color = _worksDamp.withValues(alpha: 0.8)) : iron,
          );
        case FoundryNodeKind.mold:
          _renderMold(canvas, n);
        case FoundryNodeKind.sink:
          canvas.drawOval(
            Rect.fromCenter(center: p, width: 120, height: 74),
            Paint()..color = _worksSlag.withValues(alpha: 0.85),
          );
          canvas.drawOval(
            Rect.fromCenter(center: p, width: 92, height: 52),
            Paint()..color = const Color(0xFF2B322B),
          );
        case FoundryNodeKind.junction:
        case FoundryNodeKind.relay:
          break;
      }
      // The lever, if this node has one.
      final lever = n.leverAt;
      if (lever != null) {
        final set = s.settingOf(n.switchId!);
        canvas.drawRect(
          Rect.fromCenter(
            center: lever + const Offset(0, 12),
            width: 30,
            height: 12,
          ),
          iron,
        );
        final ang = -pi / 2 + (set - 1) * 0.5;
        canvas.drawLine(
          lever + const Offset(0, 10),
          lever + Offset(cos(ang), sin(ang)) * 30,
          Paint()
            ..color = _worksIronLit
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
        _drawTinyLabel(
          canvas,
          lever + const Offset(0, 30),
          n.switchLabels[set.clamp(0, n.switchLabels.length - 1)],
        );
      }
    }
  }

  void _renderMold(Canvas canvas, FoundryNode n) {
    final s = works.line;
    final held = s.molds[n.id];
    final cavity = Rect.fromCenter(center: n.position, width: 76, height: 52);
    canvas.drawRect(cavity.inflate(4), Paint()..color = _worksBasalt);
    canvas.drawRect(
      cavity,
      Paint()..color = const Color(0xFF241E18), // sand
    );
    if (held == null) {
      canvas.drawRect(
        cavity.deflate(10),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _worksIronLit.withValues(alpha: 0.7),
      );
      return;
    }
    final spoiled = !s.cast(held);
    canvas.drawRect(
      cavity.deflate(8),
      Paint()..color = spoiled ? _worksSlag : _worksCold,
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
  void _renderHeartRing(Canvas canvas, DungeonRoom room) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 34
      ..color = _worksBasalt;
    canvas.drawCircle(kLavaHeartCentre, kLavaHeartRadius, ring);
    canvas.drawCircle(
      kLavaHeartCentre,
      kLavaHeartRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..color = Color.lerp(
          _worksEdge,
          _worksCore,
          0.3 + 0.2 * sin(works.clock * 1.6),
        )!,
    );
    // Sleepers around the ring.
    final bars = Paint()
      ..color = _worksIron
      ..strokeWidth = 4;
    for (var k = 0; k < 40; k++) {
      final a = k * pi / 20;
      final d = Offset(cos(a), sin(a));
      canvas.drawLine(
        kLavaHeartCentre + d * (kLavaHeartRadius - 20),
        kLavaHeartCentre + d * (kLavaHeartRadius + 20),
        bars,
      );
    }
    for (final head in kLavaHeartHeads) {
      final live = works.headCool <= 0;
      canvas.drawRect(
        Rect.fromCenter(center: head, width: 84, height: 34),
        Paint()..color = live ? _worksIronLit : _worksIron,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: head - const Offset(0, 30),
          width: 22,
          height: 34,
        ),
        Paint()..color = _worksIron,
      );
    }
    if (works.beached > 0 && _fx.ready) {
      drawGlow(canvas, _fx.glow!, works.beachedAt, 90, const Color(0x3AA8E6F5));
    }
  }

  /// The star, drawn as a cast ingot standing on end — the works' own idea of
  /// treasure.
  void _renderWorksStar(Canvas canvas, Offset at) {
    final pulse = 0.5 + 0.5 * sin(works.clock * 2.2);
    if (_fx.ready) {
      drawGlow(canvas, _fx.glow!, at, 52 + 8 * pulse, const Color(0x55FFB24A));
    }
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - 20, at.dy + 16)
        ..lineTo(at.dx - 13, at.dy - 16)
        ..lineTo(at.dx + 13, at.dy - 16)
        ..lineTo(at.dx + 20, at.dy + 16)
        ..close(),
      Paint()..color = Color.lerp(_worksEdge, _worksCore, 0.4 + 0.3 * pulse)!,
    );
  }
}
