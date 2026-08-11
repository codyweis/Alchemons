// lib/games/planet_dungeon/planet_dungeon_game_water.dart
//
// MIRROR-TIDE TEMPLE — the Water planet's puzzle logic + rendering, as a part
// of planet_dungeon_game.dart (shares the engine's private state the same way
// the Fire cathedral does).
//
// World rule: *every chamber answers to one temple-wide tide* — and the tide
// MOVES. Floods and drains are ANIMATED (tideAnim eases toward tideLevel/2):
// basins fill while you watch, ledge walls sink under the swell, drowned
// passages gurgle shut. Doors and seals only answer a SETTLED tide.
//  • Entry — a Water creature fills the temple's dry offering-bowl and the
//    inner doors part (one-time reveal, persisted like the other planets').
//  • Star 1 (Tide) — the tide-works: three master valves command the water
//    (ELEMENT-ONLY: any Water creature, instantly — while the pipe-mouth
//    valve elsewhere is a HARD GATE that answers ONLY a Water Pip). Three
//    sluice seals each yield at exactly one stand: drained floor, mid
//    walkway, swum-over high ledge.
//  • Star 2 (Current) — the ghost gallery, DERIVED not memorised (docs §6.4
//    REWORK / §9.1 item 2). Carved channels between a spring, five eddies
//    and a sea drain are stone and always visible; which way the ghost-water
//    runs down each one is the run's secret. A Spirit creature's insight
//    bares each eddy's SPIN — and an eddy rolls the way its upstream feeder
//    drives it (feeder to the WEST → sunwise, to the EAST → widdershins).
//    Read the spins, reconstruct the flow, wade it SPRING→SEA. The twelve
//    channels allow exactly six routes and all six are pinned uniquely by
//    their spins, so the current is ROLLED PER RUN and stays provably
//    deducible (`solveGhostCurrent`, layout-test enforced). Int re-cuts the
//    reveal: t0 spins only · t1 flow arrows · t2 the order pips. A wrong
//    eddy mid-wade still scatters the current and rouses ghost wisps.
//  • Star 3 (Deep) — beyond the mirror gate: at MID tide the two TRUE
//    moon-pools take the ice (any Ice family, clean — or a Spirit
//    creature acting in the water: Spirit+Water→Ice, the recipe's downside
//    being roused brine). Freezing a false pool SHATTERS. Both true pools
//    bridged → Leviathan stirs in the depths.
//  • The Leviathan turns the tide (§7 retrofit): the deep hauls the water one
//    stand on every roar, so the fight is played across all three stands —
//    and its lull only opens on SETTLED water. Raids are exempt.
//  • Lost Maxim — the FROZEN MOON: at mid tide a faint glint drifts on the
//    reflection-court pool; Ice laid exactly on it freezes the moon's
//    reflection forever. (Lao Tzu, +20 gold once.)

part of 'planet_dungeon_game.dart';

/// Water's lost maxim discovery id (screen pays 20 gold on first find).
const String kWaterFrozenMoonEggId = 'egg:water_frozen_moon';

/// The dry offering-bowl in the tide gate (entry rite).
const Offset kTideGateBowl = Offset(330, 265);

/// Reflection-court pool centre — the frozen-moon glint drifts around it.
const Offset _kMoonPoolCentre = Offset(320, 330);

/// Lao Tzu, frozen into the pool.
const String kWaterFrozenMoonMaxim =
    '"Nothing is softer than water, yet nothing better overcomes the hard."';

// Tide tunables. The swing is deliberately watchable: a full low↔high flood
// takes ~4.5s, one step ~2.3s.
const double _kTideRate = 0.22; // fraction/s
const double _kSwimSpeedMul = 0.62; // non-Water creatures wade slowly

/// Seconds for the bared ghost-current to bloom up out of the dark (and to
/// fade back when the run resets). Nothing snaps.
const double _kGhostBareSeconds = 0.9;

/// How close a creature must come to an eddy to wade it.
const double _kEddyWadeRadius = 30.0;

extension MirrorTide on PlanetDungeonGame {
  // ── State helpers ───────────────────────────────────────

  void _resetTempleState() {
    tideLevel = 0;
    tideAnim = 0;
    openedSeals.clear();
    eddyProgress = 0;
    eddyRevealTimer = 0;
    eddyRevealTier = 0;
    eddiesBared = false;
    _ghostBare = 0;
    poolStates.clear();
    _poolFx.clear();
    _leviathanTideDir = 1;
    _leviathanLullPrev = true;
    _leviathanRoars = 0;
    // The CURRENT itself is not rerolled — the ghost-water keeps its course
    // for the whole descent (the Buried Giant's scale answer does the same),
    // so a death costs you the walk back, never the deduction.
  }

  /// Visual flood threshold for a zone (floodedAt 1 → 0.47 · 2 → 0.97).
  double _zoneThreshold(TideZone z) => z.floodedAt / 2 - 0.03;

  bool _zoneFlooded(TideZone z) => tideAnim >= _zoneThreshold(z);

  /// Solid tide-ledges block movement until the water swallows them.
  bool _templeLedgeBlocks(Offset center, DungeonRoom room) {
    for (final z in room.tideZones) {
      if (!z.ledge || _zoneFlooded(z)) continue;
      if (center.dx > z.rect.left - 16 &&
          center.dx < z.rect.right + 16 &&
          center.dy > z.rect.top - 16 &&
          center.dy < z.rect.bottom + 16) {
        return true;
      }
    }
    return false;
  }

  /// Is this position over ANY ledge rect (flooded or not)? Used to keep
  /// lastSafe off ground that can turn into a wall.
  bool _templeOverLedge(Offset p, DungeonRoom room) {
    for (final z in room.tideZones) {
      if (z.ledge && z.rect.inflate(4).contains(p)) return true;
    }
    return false;
  }

  /// Swimming through flooded water slows everyone but Water itself.
  double _templeSpeedMul(DungeonCreature a) {
    for (final z in currentRoom.tideZones) {
      if (!_zoneFlooded(z) || !z.rect.contains(a.position)) continue;
      return a.member.element == 'Water' ? 1.0 : _kSwimSpeedMul;
    }
    return 1.0;
  }

  /// Tide-gated doors are passable only while the water stands SETTLED at
  /// one of the rule's levels.
  bool _tideDoorBlocked(DungeonRoom room, DungeonDoor door) {
    for (final rule in room.tideDoorRules) {
      if (rule.targetRoomId != door.targetRoomId) continue;
      return !(tideSettled && rule.tides.contains(tideLevel));
    }
    return false;
  }

  String _tideDoorHint(DungeonRoom room, DungeonDoor door) {
    if (!tideSettled) return 'The brine still moves — let the tide settle';
    for (final rule in room.tideDoorRules) {
      if (rule.targetRoomId != door.targetRoomId) continue;
      final wantsLower = rule.tides.every((t) => t < tideLevel);
      return wantsLower
          ? 'The passage lies drowned — a lower tide would bare it'
          : 'The passage hangs dry above you — a higher tide would reach it';
    }
    return 'The way refuses the tide as it stands';
  }

  String _tideName(int level) => switch (level) {
    0 => 'low',
    1 => 'middle',
    _ => 'high',
  };

  void _setTide(int level) {
    if (level == tideLevel) return;
    tideLevel = level.clamp(0, 2);
    _setHint(
      'The temple groans — the ${_tideName(tideLevel)} water comes',
      3.2,
    );
    _spawnAlchemyBurst(
      active?.position ?? currentRoom.bounds.center,
      producedElement: 'Water',
      particleCount: 18,
      intensity: 0.9,
    );
    onChanged();
  }

  /// The frozen-moon glint: only adrift while the tide stands settled at MID
  /// (and only until it is frozen). Public for the headless full-run test.
  Offset? frozenMoonGlint() {
    if (!_isTemple) return null;
    if (discoveredClouds.contains(kWaterFrozenMoonEggId)) return null;
    if (!(tideSettled && tideLevel == 1)) return null;
    return _kMoonPoolCentre +
        Offset(sin(_time * 0.21) * 52, sin(_time * 0.33 + 1.7) * 36);
  }

  // ── Star 2: the ghost current, DERIVED ──────────────────
  //
  // THE RULE, entire: an eddy turns the way its upstream feeder drives it.
  // Water reaching it from the WEST rolls it sunwise (clockwise); water from
  // the EAST rolls it widdershins. Nothing else is hidden — the channels are
  // stone, the spring and the sea drain are stone, and the spins are what
  // Spirit bares. Everything the game does with the current — the render, the
  // run's roll — and everything the layout test proves about it go through
  // ONE rule function and ONE route enumerator below, so the proof can never
  // drift away from the gameplay.

  /// The gallery — the room that owns the eddies (null on other planets).
  DungeonRoom? get _ghostGallery {
    for (final room in layout.rooms.values) {
      if (room.ghostEddies.isNotEmpty) return room;
    }
    return null;
  }

  /// Every node in the gallery's flow network by id: the spring, the five
  /// eddies, the sea drain. Built once — the layout is const, and the render
  /// asks for this several times a frame.
  Map<String, Offset> _ghostNodes(DungeonRoom room) =>
      _ghostNodeCache ??= {
        for (final m in room.ghostMouths) m.id: m.position,
        for (final e in room.ghostEddies) e.id: e.position,
      };

  /// THE RULE. True = sunwise (clockwise): the water reaches [eddy] from the
  /// west. The game's render, the run's roll and the solver all ask this.
  bool _spinSunwise(Offset eddy, Offset feeder) => feeder.dx < eddy.dx;

  /// The spin the gallery is SHOWING for [eddyId] right now — the one thing
  /// a Spirit reveal bares. Null before the current is rolled.
  bool? eddySpinSunwise(String eddyId) {
    final room = _ghostGallery;
    final feeder = eddyFeeder[eddyId];
    if (room == null || feeder == null) return null;
    final nodes = _ghostNodes(room);
    final at = nodes[eddyId], from = nodes[feeder];
    if (at == null || from == null) return null;
    return _spinSunwise(at, from);
  }

  /// Every route the carved channels allow: spring → all five eddies → sea,
  /// each node once. This is the whole space of currents the gallery's stone
  /// could ever carry, and it is what both the roll and the solver search.
  List<List<String>> ghostRoutes() {
    final room = _ghostGallery;
    if (room == null) return const [];
    String? sourceId, seaId;
    for (final m in room.ghostMouths) {
      if (m.isSource) {
        sourceId = m.id;
      } else {
        seaId = m.id;
      }
    }
    if (sourceId == null || seaId == null) return const [];
    final adj = <String, Set<String>>{};
    for (final ch in room.ghostChannels) {
      adj.putIfAbsent(ch.a, () => {}).add(ch.b);
      adj.putIfAbsent(ch.b, () => {}).add(ch.a);
    }
    final eddyIds = {for (final e in room.ghostEddies) e.id};
    final routes = <List<String>>[];
    void walk(List<String> path, Set<String> seen) {
      if (seen.length == eddyIds.length) {
        if (adj[path.last]?.contains(seaId) ?? false) {
          routes.add([...path, seaId!]);
        }
        return;
      }
      for (final next in adj[path.last] ?? const <String>{}) {
        if (!eddyIds.contains(next) || seen.contains(next)) continue;
        walk([...path, next], {...seen, next});
      }
    }

    walk([sourceId], {});
    return routes;
  }

  /// The spins a given route would put on the water, as a per-eddy map.
  Map<String, bool> _routeSpins(DungeonRoom room, List<String> route) {
    final nodes = _ghostNodes(room);
    return {
      for (var i = 1; i < route.length - 1; i++)
        route[i]: _spinSunwise(nodes[route[i]]!, nodes[route[i - 1]]!),
    };
  }

  String _spinKey(Map<String, bool> spins) {
    final ids = spins.keys.toList()..sort();
    return [for (final id in ids) spins[id]! ? 's' : 'w'].join();
  }

  /// THE SOLVER (public: the layout test's proof engine, and the run's own
  /// roll). Derives the wade order from the SPINS alone — exactly the
  /// reasoning the player must do — by walking every route the carved
  /// channels allow and keeping the ones whose spins match what the water
  /// shows. [searched] = routes the stone permits; [satisfying] must be
  /// exactly 1 (docs §6.4: "the spins uniquely determine one wade order").
  ({int searched, int satisfying, List<String>? order}) solveGhostCurrent([
    Map<String, bool>? spins,
  ]) {
    final room = _ghostGallery;
    if (room == null) return (searched: 0, satisfying: 0, order: null);
    final observed =
        spins ??
        {
          for (final e in room.ghostEddies)
            if (eddySpinSunwise(e.id) != null) e.id: eddySpinSunwise(e.id)!,
        };
    final routes = ghostRoutes();
    var satisfying = 0;
    List<String>? order;
    for (final route in routes) {
      final produced = _routeSpins(room, route);
      var matches = produced.length == observed.length;
      if (matches) {
        for (final entry in produced.entries) {
          if (observed[entry.key] != entry.value) {
            matches = false;
            break;
          }
        }
      }
      if (matches) {
        satisfying++;
        order = route.sublist(1, route.length - 1);
      }
    }
    return (searched: routes.length, satisfying: satisfying, order: order);
  }

  /// Roll the run's current (constructor-time, like the Buried Giant's scale)
  /// — and roll ONLY from the routes whose spins pin them uniquely. A current
  /// the spins cannot single out is not a puzzle, it is a coin toss, so the
  /// gallery simply never runs one.
  void _rollGhostCurrent() {
    eddyOrder.clear();
    eddyFeeder.clear();
    if (!_isTemple) return;
    final room = _ghostGallery;
    if (room == null) return;
    final routes = ghostRoutes();
    if (routes.isEmpty) return;
    final tally = <String, int>{};
    for (final route in routes) {
      final key = _spinKey(_routeSpins(room, route));
      tally[key] = (tally[key] ?? 0) + 1;
    }
    final deducible = [
      for (final route in routes)
        if (tally[_spinKey(_routeSpins(room, route))] == 1) route,
    ];
    final pool = deducible.isEmpty ? routes : deducible;
    adoptGhostRoute(pool[Random().nextInt(pool.length)]);
  }

  /// Adopt [route] (`[springId, …eddyIds, seaId]`) as this run's current.
  /// Public so tests can pin a known current instead of fighting the roll.
  void adoptGhostRoute(List<String> route) {
    eddyOrder.clear();
    eddyFeeder.clear();
    for (var i = 1; i < route.length - 1; i++) {
      eddyOrder[route[i]] = i - 1;
      eddyFeeder[route[i]] = route[i - 1];
    }
  }

  /// The eddy ids in wade order (empty before the roll).
  List<String> get ghostWadeOrder {
    final ids = eddyOrder.keys.toList()
      ..sort((a, b) => eddyOrder[a]! - eddyOrder[b]!);
    return ids;
  }

  // ── Update ──────────────────────────────────────────────

  void _updateTemple(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isTemple) return;

    // The ANIMATED tide: ease the visual water toward the target stand.
    final target = tideLevel / 2;
    if ((tideAnim - target).abs() > 0.0005) {
      final prev = tideAnim;
      final dirn = (target - tideAnim).sign;
      tideAnim += dirn * _kTideRate * dt;
      if ((target - tideAnim).sign != dirn) tideAnim = target; // arrived
      _handleLedgeEmergence(room, prev, tideAnim);
    }

    if (eddyRevealTimer > 0) eddyRevealTimer -= dt;
    // The bared current blooms up (and never snaps): ANIMATED-STATE rule.
    final bareTarget = eddiesBared ? 1.0 : 0.0;
    if ((_ghostBare - bareTarget).abs() > 0.001) {
      final step = dt / _kGhostBareSeconds;
      _ghostBare = _ghostBare < bareTarget
          ? min(bareTarget, _ghostBare + step)
          : max(bareTarget, _ghostBare - step);
    }
    if (_poolFx.isNotEmpty) {
      _poolFx.updateAll((k, v) => v - dt);
      _poolFx.removeWhere((k, v) => v <= 0);
    }

    // Star 2: wade the current SPRING→SEA in the order the spins describe.
    // A later eddy taken mid-wade scatters the whole thing (the consequence
    // the rework keeps) — and stepping into the wrong FIRST eddy costs
    // nothing, so a course can always be started over cleanly.
    final eddyStar = room.eddyStarIndex;
    if (room.ghostEddies.isNotEmpty &&
        eddyStar != null &&
        !hasStar(eddyStar)) {
      for (final eddy in room.ghostEddies) {
        if ((a.position - eddy.position).distance > _kEddyWadeRadius) continue;
        final ord = eddyOrder[eddy.id];
        if (ord == null) continue;
        if (ord == eddyProgress) {
          eddyProgress++;
          _spawnAlchemyBurst(
            eddy.position,
            producedElement: 'Spirit',
            reagentElements: const ['Water'],
            particleCount: 12,
            intensity: 0.7,
          );
          if (eddyProgress >= room.ghostEddies.length) {
            earnStar(eddyStar);
          } else {
            // The tally itself lives in the progress readout now (§5.6);
            // the capsule only says the water took you.
            _setHint('The ghost-water gathers you and carries on');
          }
          onChanged();
        } else if (ord > eddyProgress && eddyProgress != 0) {
          eddyProgress = 0;
          _spawnAlchemyBurst(
            eddy.position,
            producedElement: 'Spirit',
            unstable: true,
            particleCount: 18,
          );
          spawnWispWave(
            element: 'Spirit',
            center: eddy.position,
            count: 2,
            announce: false,
          );
          _setHint('The current scatters — the ghost-water rises angry', 3.0);
          onChanged();
        }
      }
    }
  }

  /// When a draining tide bares a ledge, nothing may be left standing inside
  /// the new wall — drift any caught creature back to its last footing.
  void _handleLedgeEmergence(DungeonRoom room, double prev, double now) {
    for (final z in room.tideZones) {
      if (!z.ledge) continue;
      final thr = _zoneThreshold(z);
      if (!(prev >= thr && now < thr)) continue; // didn't just emerge
      for (final c in creatures) {
        if (!c.alive || !z.rect.inflate(8).contains(c.position)) continue;
        if (identical(c, active)) {
          _beginFallRecovery(
            c,
            c.lastSafe,
            hint: 'The water falls away — scrambling back to footing',
          );
        } else {
          c.position = c.lastSafe;
        }
      }
    }
  }

  // ── Utility interactions ────────────────────────────────

  bool _tryTemple(DungeonCreature a) {
    if (!_isTemple) return false;
    final room = currentRoom;
    if (_tryOfferingBowl(a, room)) return true;
    if (_tryTideValve(a, room)) return true;
    if (_trySluiceSeal(a, room)) return true;
    if (_tryGhostReveal(a, room)) return true;
    if (_tryMoonPool(a, room)) return true;
    if (_tryFrozenMoon(a, room)) return true;
    if (_tryCourtCommune(a, room)) return true;
    return false;
  }

  /// The entry rite: Water fills the temple's dry offering-bowl.
  bool _tryOfferingBowl(DungeonCreature a, DungeonRoom room) {
    if (room.id != 'tide_gate') return false;
    if ((a.position - kTideGateBowl).distance > 46) return false;
    if (entryDoorRevealed) {
      _setHint('The offering-bowl brims, mirror-still');
      return true;
    }
    if (a.member.element != 'Water') {
      _setHint('A dry stone bowl — it thirsts for Water');
      return true;
    }
    entryDoorRevealed = true;
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist
    final doorCenter = room.doors.isNotEmpty
        ? room.doors.first.rect.center
        : a.position;
    _setHint('Water takes the bowl — the drowned doors swing inward');
    _spawnAlchemyBurst(
      kTideGateBowl,
      producedElement: 'Water',
      particleCount: 30,
      intensity: 1.2,
    );
    _spawnAlchemyBurst(
      doorCenter,
      producedElement: 'Water',
      particleCount: 22,
      intensity: 1.0,
    );
    return true;
  }

  /// Tide valves. The master wheels are ELEMENT-ONLY: any Water creature sets
  /// a stand outright. The pipe-mouth is a HARD GATE — Water + Pip, nothing
  /// else fits down the pipes.
  bool _tryTideValve(DungeonCreature a, DungeonRoom room) {
    for (final valve in room.tideValves) {
      if ((a.position - valve.position).distance > 46) continue;
      final r = evaluateInteraction(
        a.member,
        DungeonInteractionRequirement(
          element: 'Water',
          requiredFamily: valve.pipOnly ? DungeonAbility.smallAccess : null,
        ),
      );
      if (r == InteractionResult.blockedFamily) {
        // The refusal stamps the pipe-mouth's Water+Pip chip onto the descent
        // panel — once, forever ("the seal remembers", §4).
        final gate = layout.familyGateFor('pipe_mouth');
        if (gate != null) {
          _stampFamilyGate(gate);
        } else {
          _setBlockedHint('Only a Water pip slips down this pipe-mouth');
        }
        return true;
      }
      if (!interactionSucceeded(r)) {
        _setHint('The valve answers Water alone');
        return true;
      }
      final targetLevel = valve.level ?? (tideLevel + 1) % 3;
      if (targetLevel == tideLevel && tideSettled) {
        _setHint(
          'The tide already stands ${_tideName(tideLevel)} — the valve '
          'idles',
        );
        return true;
      }
      _spawnAlchemyBurst(
        valve.position,
        producedElement: 'Water',
        reagentElements: [a.member.element],
        particleCount: 14,
        intensity: 0.8,
      );
      _setTide(targetLevel);
      return true;
    }
    return false;
  }

  /// Star 1: the sluice seals, each yielding at exactly one settled stand.
  bool _trySluiceSeal(DungeonCreature a, DungeonRoom room) {
    final star = room.sealStarIndex;
    if (room.tideSeals.isEmpty || star == null || hasStar(star)) return false;
    for (final seal in room.tideSeals) {
      if ((a.position - seal.position).distance > 46) continue;
      if (openedSeals.contains(seal.id)) {
        _setHint('This sluice already runs free');
        return true;
      }
      if (!tideSettled) {
        _setHint('The brine still moves — let the tide settle');
        return true;
      }
      if (!seal.tides.contains(tideLevel)) {
        final wantsLower = seal.tides.every((t) => t < tideLevel);
        _setHint(
          wantsLower
              ? 'The seal lies drowned — it yields only to a lower tide'
              : 'The seal sits beyond this water — it wants a higher tide',
        );
        return true;
      }
      openedSeals.add(seal.id);
      _spawnAlchemyBurst(
        seal.position,
        producedElement: 'Water',
        reagentElements: [a.member.element],
        particleCount: 20,
        intensity: 1.0,
      );
      // The consequence layer: every opened sluice exhales old brine.
      spawnWispWave(
        element: 'Water',
        center: seal.position,
        count: 2,
        announce: false,
      );
      if (openedSeals.length >= room.tideSeals.length) {
        earnStar(star);
      } else {
        _setHint(
          'The sluice grinds open — ${openedSeals.length} of '
          '${room.tideSeals.length}',
          3.0,
        );
      }
      return true;
    }
    return false;
  }

  /// Star 2's reveal: ANY Spirit creature bares the ghost current. What it
  /// bares at tier 0 is the SPINS — the evidence, not the answer — and the
  /// baring is PERMANENT for the run: a deduction you cannot look at twice
  /// is only a memory test. Intelligence buys the shortcuts on top of it:
  /// t1 draws the flow along the channels, t2 numbers the wade outright.
  bool _tryGhostReveal(DungeonCreature a, DungeonRoom room) {
    if (room.ghostEddies.isEmpty) return false;
    final star = room.eddyStarIndex;
    if (a.member.element != 'Spirit') {
      // A Mask still reads the gallery's frieze for the RULE (_templeReveal);
      // anyone else gets one clause of refusal and nothing else.
      if (a.ability == DungeonAbility.insight) return false;
      if (star != null && hasStar(star)) return false;
      _setBlockedHint('Only Spirit bares the ghost-water');
      return true;
    }
    if (star != null && hasStar(star)) {
      _setHint('The current rests — its course is run');
      return true;
    }
    eddyRevealTier = revealHintTier(a.member.statIntelligence);
    eddyRevealTimer = 4.0 + 6.0 * normStat(a.member.statIntelligence);
    eddiesBared = true; // the spins stay bare for the rest of the run
    revealFlash = 0.6;
    _spawnAlchemyBurst(
      a.position,
      producedElement: 'Spirit',
      particleCount: 16,
      intensity: 0.8,
    );
    // INSIGHT is the only channel allowed to teach method (§5.6), and it is
    // priority-protected so the reading is never stomped mid-read.
    _setInsightHint(
      eddyRevealTier >= 2
          ? 'The water counts its own course — wade the eddies as they number'
          : eddyRevealTier >= 1
          ? 'The flow bares itself along the channels — follow it spring to sea'
          : 'Each eddy rolls the way its feeder drives it — sunwise when the '
                'water comes from the west, widdershins from the east',
      4.2,
    );
    return true;
  }

  /// Star 3: freeze the TRUE moon-pools at mid tide (Ice direct; PARITY —
  /// a Spirit creature acting in the water braids the same ice, angrier).
  bool _tryMoonPool(DungeonCreature a, DungeonRoom room) {
    if (room.moonPools.isEmpty || hasStar(2)) return false;
    for (final pool in room.moonPools) {
      if ((a.position - pool.position).distance > 50) continue;
      if (!guardianRiteUnlocked) {
        _setHint(
          'The pools sleep — they answer only a bearer of both the '
          '${layout.starName(0)} and ${layout.starName(1)}',
        );
        return true;
      }
      if ((poolStates[pool.id] ?? 0) == 1) {
        _setHint('This pool already stands as ice');
        return true;
      }
      if (!(tideSettled && tideLevel == 1)) {
        _setHint(
          'The pools only hold the moon at the settled MIDDLE water',
        );
        return true;
      }
      final r = evaluateInteraction(
        a.member,
        const DungeonInteractionRequirement(
          element: 'Ice',
          allowRecipe: true,
        ),
        recipeAvailable: a.member.element == 'Spirit',
      );
      final viaRecipe = r == InteractionResult.passedViaRecipe;
      if (!interactionSucceeded(r)) {
        _setHint('Ice would take this pool — or Spirit standing in the water');
        return true;
      }
      if (!pool.isTrue) {
        // The false pools never held the moon: the ice takes, then SHATTERS.
        _poolFx[pool.id] = 1.4;
        _spawnAlchemyBurst(
          pool.position,
          producedElement: 'Ice',
          unstable: true,
          particleCount: 24,
        );
        spawnWispWave(
          element: 'Water',
          center: pool.position,
          count: 3,
          unstable: true,
          announce: false,
        );
        _setHint(
          'The ice takes — and SHATTERS. This pool never held the moon',
          3.4,
        );
        return true;
      }
      poolStates[pool.id] = 1;
      _poolFx[pool.id] = 1.4;
      _spawnAlchemyBurst(
        pool.position,
        producedElement: 'Ice',
        reagentElements: viaRecipe
            ? const ['Spirit', 'Water']
            : [a.member.element],
        particleCount: 22,
        intensity: 1.0,
      );
      if (viaRecipe) {
        // The RECIPE's downside (not a family penalty): braiding Spirit through
        // the water is a loud way to make ice, and the brine hears it. Ice laid
        // direct — by ANY family — is silent.
        spawnWispWave(
          element: 'Water',
          center: pool.position,
          count: 2,
          announce: false,
        );
      }
      final trueTotal = room.moonPools.where((p) => p.isTrue).length;
      final frozen = room.moonPools
          .where((p) => p.isTrue && (poolStates[p.id] ?? 0) == 1)
          .length;
      if (frozen >= trueTotal) {
        guardianAwake = true;
        guardianHp = PlanetDungeonGame.maxGuardianHp;
        _setHint(
          'The bridge of ice stands over the well — the deep stirs beyond',
          4.2,
        );
        spawnWispWave(
          element: 'Water',
          center: room.bounds.center,
          count: 3,
          unstable: true,
          announce: false,
        );
      } else {
        _setHint(
          viaRecipe
              ? 'Spirit and Water braid into ice — and the brine stirs at it'
              : 'The pool takes the ice clean — the moon stands frozen in it',
          3.2,
        );
      }
      onChanged();
      return true;
    }
    return false;
  }

  /// The Lost Maxim: freeze the moon's drifting reflection (Ice, exactly on
  /// the glint, mid tide only). Wordless until won; the maxim is the fanfare.
  bool _tryFrozenMoon(DungeonCreature a, DungeonRoom room) {
    if (room.id != 'reflection_court') return false;
    if (discoveredClouds.contains(kWaterFrozenMoonEggId)) return false;
    final glint = frozenMoonGlint();
    if (glint == null) return false;
    if (a.member.element != 'Ice') return false;
    if ((a.position - glint).distance > 28) return false;
    _discoverCloud(kWaterFrozenMoonEggId); // screen pays the 20 gold
    _spawnAlchemyBurst(
      glint,
      producedElement: 'Ice',
      reagentElements: const ['Light'],
      particleCount: 26,
      intensity: 1.1,
    );
    _setHint('$kWaterFrozenMoonMaxim — the moon stands frozen', 9.0);
    return true;
  }

  /// The 3-star secret: commune at the drowned court's heart.
  bool _tryCourtCommune(DungeonCreature a, DungeonRoom room) {
    if (room.id != 'drowned_court' || starsEarnedCount < 3) return false;
    if ((a.position - room.bounds.center).distance >= 34) return false;
    _setHint(
      'The water stills to a perfect mirror. Before the flood, the '
      'Leviathan sang the first tide through these halls — the temple '
      'remembers, and now it rests.',
      7.5,
    );
    _spawnAlchemyBurst(
      room.bounds.center,
      producedElement: 'Light',
      reagentElements: const ['Water'],
      particleCount: 20,
      intensity: 0.8,
    );
    return true;
  }

  // ── The Leviathan turns the tide (§7 retrofit) ──────────
  //
  // The guardian grammar stays engine-shared: the same lull/strike cycle
  // every mystic rides. What Leviathan adds is the PLANET'S OWN RULE turned
  // against you — on every roar (the beat the lull shuts) the deep hauls the
  // water one stand, so the arena's footing, swim speed and pier cover are
  // never the same twice; and the lull only opens on SETTLED water, so the
  // swell itself is the guardian's shield. Raids are exempt: the generated
  // arena has no tide zones, and the shared cycle carries the fight there.

  /// Called from the shared guardian loop (one `_isTemple`-guarded line in
  /// `_updateAltar`), AFTER the cycle has set [guardianVulnerable].
  void _applyLeviathanTide(DungeonRoom room, double dt) {
    final g = room.guardian;
    if (g == null || isRaid || room.tideZones.isEmpty) return;
    if (hasStar(g.starIndex)) return;
    // The roar rides the SHUT of the lull — the raw cycle's falling edge, so
    // it fires on a fixed beat and always has a full strike phase in which
    // to settle before the next window opens.
    final cycleLull = guardianVulnerable;
    if (_leviathanLullPrev && !cycleLull) _leviathanRoar();
    _leviathanLullPrev = cycleLull;
    // The swell is its armour: nothing touches Leviathan on moving water.
    if (!tideSettled) guardianVulnerable = false;
  }

  /// One roar: the deep hauls the water a stand, rolling low→mid→high→mid→…
  /// so the fight is played across every stand instead of parking on one.
  void _leviathanRoar() {
    var next = tideLevel + _leviathanTideDir;
    if (next > 2) {
      next = 1;
      _leviathanTideDir = -1;
    } else if (next < 0) {
      next = 1;
      _leviathanTideDir = 1;
    }
    _leviathanRoars++;
    _setTide(next);
    _setHint(
      'Leviathan roars — the deep hauls the ${_tideName(tideLevel)} water in',
      2.8,
    );
  }

  // ── Progress readout (§5.6 STATE LEAVES THE CAPSULE) ────

  /// Water's persistent, glanceable counters, beside the star tracker: the
  /// sluice tally (migrated out of the capsule, where it used to fade after
  /// three seconds) and the wade. The tide GAUGE is a canvas HUD of its own
  /// and deliberately stays one.
  DungeonProgressReadout? _templeProgressReadout() {
    final room = currentRoom;
    final sealStar = room.sealStarIndex;
    if (room.tideSeals.isNotEmpty && sealStar != null && !hasStar(sealStar)) {
      final total = room.tideSeals.length;
      final open = room.tideSeals
          .where((s) => openedSeals.contains(s.id))
          .length;
      return DungeonProgressReadout(
        label: 'SLUICES',
        value: '$open/$total',
        fraction: total == 0 ? null : open / total,
      );
    }
    final eddyStar = room.eddyStarIndex;
    if (room.ghostEddies.isNotEmpty && eddyStar != null && !hasStar(eddyStar)) {
      final total = room.ghostEddies.length;
      return DungeonProgressReadout(
        label: 'EDDIES',
        value: '$eddyProgress/$total',
        fraction: total == 0 ? null : eddyProgress / total,
      );
    }
    return null;
  }

  // ── Mask insight ────────────────────────────────────────

  void _templeReveal(DungeonCreature a, DungeonRoom room) {
    revealFlash = 0.6;
    revealTier = revealHintTier(a.member.statIntelligence);
    switch (room.id) {
      case 'tide_works':
        _setHint(
          'Three stands of water, three sluices — each seal yields at '
          'exactly one',
          3.8,
        );
        return;
      case 'ghost_gallery':
        // A non-Spirit Mask cannot bare the water, but it CAN read the
        // gallery's frieze — and the frieze is where the rule is written.
        // (Spirit creatures never reach here: _tryGhostReveal catches them.)
        final star = room.eddyStarIndex;
        if (star != null && hasStar(star)) {
          _setHint('The current rests — its course is run');
          return;
        }
        _setHint(
          revealTier >= 1
              ? 'The frieze reads plain: an eddy rolls the way its feeder '
                    'drives it — sunwise from the west, widdershins from the east'
              : 'Carved channels, and eddies that turn between them — only '
                    'Spirit bares which way',
          4.2,
        );
        return;
      case 'moon_hall':
        _setHint(
          'The tide-mural completes — at the settled MIDDLE water, the '
          'true pools take the ice and bridge the well',
          4.2,
        );
        return;
      case 'moon_well':
        // Tiered (§5.6): tier 1 narrows the method, tier 2 marks the answer.
        if (revealTier >= 2) {
          // (The moon-well reading is the moon-well's; it no longer bleeds
          // into the gallery's eddy tier — that would hand a room away from
          // three chambers off.)
          _poolFx['truth'] = 3.0 + revealTier * 1.5; // true pools glow
          _setHint(
            'The moon rides the northwest and southeast pools — the '
            'others lie',
            4.2,
          );
        } else if (revealTier >= 1) {
          _setHint(
            'At the settled middle water, only the true pools take the ice',
            3.8,
          );
        } else {
          _setHint(
            'Two of the four pools hold the moon; sharper insight would '
            'name them',
            3.8,
          );
        }
        return;
      case 'reflection_court':
        // The egg's single oblique hint.
        _setHint(
          'The pool remembers the moon best when the tide stands between',
          3.6,
        );
        return;
      case 'tide_gate':
        _setHint(
          entryDoorRevealed
              ? 'The bowl brims; the way is open'
              : 'The dry bowl asks a simple offering',
        );
        return;
      case 'leviathan_depths':
        _setHint(
          guardianAwake
              ? 'The Leviathan\'s rage ebbs in waves — strike in the lull'
              : 'An empty deep above the well — the ice bridge will fill it',
          3.6,
        );
        return;
    }
    _setHint('Nothing hidden stirs here');
  }

  // ── Ambient hints / objectives / mood ───────────────────

  void _templeAmbientHint(DungeonCreature a, DungeonRoom room) {
    for (final valve in room.tideValves) {
      if ((a.position - valve.position).distance > 64) continue;
      _setAmbientHint(
        valve.pipOnly
            ? 'A narrow pipe-mouth breathes brine'
            : a.member.element == 'Water'
            ? 'The valve hums against your current'
            : 'A great tide-valve, crusted with salt',
      );
      return;
    }
    if (room.sealStarIndex != null && !hasStar(room.sealStarIndex!)) {
      for (final seal in room.tideSeals) {
        if ((a.position - seal.position).distance > 64) continue;
        if (openedSeals.contains(seal.id)) return;
        _setAmbientHint('A sluice seal, shut fast beneath the brine');
        return;
      }
    }
    if (room.moonPools.isNotEmpty && !hasStar(2)) {
      for (final pool in room.moonPools) {
        if ((a.position - pool.position).distance > 64) continue;
        if ((poolStates[pool.id] ?? 0) == 1) return;
        _setAmbientHint(
          a.member.element == 'Ice'
              ? 'The pool\'s surface leans toward your cold'
              : 'A moon-pool, still as dark glass',
        );
        return;
      }
    }
    if (room.id == 'tide_gate' && !entryDoorRevealed) {
      if ((a.position - kTideGateBowl).distance <= 70) {
        _setAmbientHint('The offering-bowl stands dry — it thirsts');
      }
      return;
    }
    // Atmosphere ONLY at the gallery's mouths: a named stone thing, no
    // mechanic, no element requirement (§5.6 AMBIENT).
    for (final mouth in room.ghostMouths) {
      if ((a.position - mouth.position).distance > 70) continue;
      _setAmbientHint(
        mouth.isSource
            ? 'A carved mouth weeps brine into the dark'
            : 'The grate breathes; somewhere below, the sea',
      );
      return;
    }
  }

  String? _templeObjectiveHint(DungeonRoom room) {
    switch (room.id) {
      case 'tide_gate':
        return entryDoorRevealed
            ? null
            : 'Tide Gate — the offering-bowl stands dry; Water wakes the '
                  'way in';
      case 'tide_works':
        return 'Tide-Works — turn the valves, stand the tide, open all '
            'three sluices';
      case 'ghost_gallery':
        // WHAT, never HOW (§5.6): the rule and the reading are the frieze's
        // and Spirit's to give, not the doorway's.
        return 'Ghost Gallery — an unseen current still runs spring to sea';
      case 'reflection_court':
        return null; // the egg keeps its silence
      case 'moon_hall':
        return hasStar(2)
            ? null
            : 'Moon Hall — the tide-mural diagrams the rite ahead';
      case 'moon_well':
        // WHAT, never HOW (§5.6): the tide condition and pool-truth are the
        // tide-mural's earned reading (_templeReveal), not room-entry copy.
        return 'Moon Well — the moon rides the water here, unheld';
      case 'leviathan_depths':
        return guardianAwake
            ? 'The Depths — the Leviathan rises'
            : 'The Depths — silence; the well is not yet bridged';
    }
    return null;
  }

  double get _templeMoodTarget {
    final base = switch (currentRoomId) {
      'tide_gate' => entryDoorRevealed ? 0.55 : 0.44,
      'drowned_court' => 0.55,
      'tide_works' => 0.5,
      'ghost_gallery' => 0.4,
      'pearl_vault' => 0.56,
      'reflection_court' => 0.6,
      'moon_hall' => 0.36,
      'moon_well' => 0.3,
      'leviathan_depths' => guardianAwake ? 0.18 : 0.26,
      _ => 0.5,
    };
    // High water darkens every chamber a shade.
    return (base - tideAnim * 0.06).clamp(0.1, 1.0);
  }

  // ── Render: screen-space atmosphere ─────────────────────

  void _drawTempleFallbackSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          const [
            Color(0xFF050E18), // abyssal ceiling
            Color(0xFF0B2836), // deep teal
            Color(0xFF14485A), // sun-warmed shallows
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
  }

  /// Ambient bubbles: a handful rising on staggered loops — the temple's
  /// breath, visible in every chamber. 4 stroked circles per frame.
  void _drawBubbleDrift(Canvas canvas, Size vp) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 4; i++) {
      final speed = 34.0 + i * 11;
      final span = vp.height + 100;
      final travel = (_time * speed + i * 277) % span;
      final y = vp.height + 30 - travel;
      final x =
          vp.width * (0.2 + 0.2 * i) +
          sin(_time * (0.9 + i * 0.27) + i * 1.8) * 22;
      final fade = (travel / span).clamp(0.0, 1.0);
      final r = 2.4 + i * 0.9 + sin(_time * 3 + i) * 0.5;
      paint.color = const Color(0xFF8FE0EC).withValues(
        alpha: (0.22 * (1 - fade) + 0.04).clamp(0.0, 0.26),
      );
      canvas.drawCircle(Offset(x, y), r, paint);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(x - r * 0.25, y - r * 0.25), radius: r * 0.45),
        -2.6,
        1.2,
        false,
        paint,
      );
    }
  }

  /// The tide gauge: a slim screen-edge column with the LIVE waterline —
  /// the flood and drain made legible at a glance.
  void _drawTideGauge(Canvas canvas, Size vp) {
    const w = 10.0;
    const h = 86.0;
    final rect = Rect.fromLTWH(vp.width - 22, vp.height * 0.5 - h / 2, w, h);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    canvas.drawRRect(
      rr,
      Paint()..color = const Color(0xFF06141C).withValues(alpha: 0.6),
    );
    // The water column, breathing while it moves.
    final settled = tideSettled;
    final waterH = h * (0.16 + 0.68 * tideAnim);
    final ripple = settled ? 0.0 : sin(_time * 7) * 2.0;
    final waterRect = Rect.fromLTRB(
      rect.left + 1.5,
      rect.bottom - waterH + ripple,
      rect.right - 1.5,
      rect.bottom - 1.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(waterRect, const Radius.circular(4)),
      Paint()
        ..color = const Color(0xFF4AB8D8).withValues(
          alpha: settled ? 0.55 : 0.75,
        ),
    );
    // Stand notches.
    for (var i = 0; i < 3; i++) {
      final y = rect.bottom - h * (0.16 + 0.34 * i);
      canvas.drawLine(
        Offset(rect.left - 3, y),
        Offset(rect.left, y),
        Paint()
          ..strokeWidth = 1.4
          ..color = const Color(0xFFE4C16A).withValues(
            alpha: i == tideLevel ? 0.9 : 0.3,
          ),
      );
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF8FE0EC).withValues(alpha: 0.35),
    );
  }

  // ── Render: world-space ─────────────────────────────────

  /// Drowned-temple flooring: teal-slate flags, a mosaic ring, salt stains.
  void _renderTempleFloor(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final rr = RRect.fromRectAndRadius(b.deflate(8), const Radius.circular(26));
    // TRANSLUCENT like the Air islands (alpha ≈ 0.5–0.6): the caustic
    // shader atmosphere must glow through the flags, never be painted over.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, [
          const Color(0xFF12222A).withValues(alpha: 0.50),
          const Color(0xFF0A161D).withValues(alpha: 0.58),
        ]),
    );
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF2A4A56).withValues(alpha: 0.12);
    for (var x = b.left + 90; x < b.right - 20; x += 110) {
      canvas.drawLine(Offset(x, b.top + 18), Offset(x, b.bottom - 18), seam);
    }
    for (var y = b.top + 90; y < b.bottom - 20; y += 110) {
      canvas.drawLine(Offset(b.left + 18, y), Offset(b.right - 18, y), seam);
    }
    // Mosaic ring at the chamber's heart.
    canvas.drawCircle(
      b.center,
      88,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF3A7080).withValues(alpha: 0.22),
    );
    canvas.drawCircle(
      b.center,
      66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF3A7080).withValues(alpha: 0.14),
    );
    // Old salt lines where past tides stood.
    final salt = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF8FA8B0).withValues(alpha: 0.08);
    canvas.drawLine(
      Offset(b.left + 26, b.top + 110),
      Offset(b.right - 26, b.top + 102),
      salt,
    );
    canvas.drawLine(
      Offset(b.left + 30, b.top + 180),
      Offset(b.right - 30, b.top + 174),
      salt,
    );
    if (_fx.ready) {
      final cols = (b.width / 130).clamp(3, 9).toInt();
      for (var i = 0; i < cols; i++) {
        final x = b.left + (i + 0.5) / cols * b.width;
        drawPuff(
          canvas,
          _fx.puff!,
          Offset(x, b.top + 8),
          120,
          const Color(0xFF0C1A22).withValues(alpha: 0.55),
        );
        drawPuff(
          canvas,
          _fx.puff!,
          Offset(x, b.bottom - 8),
          120,
          const Color(0xFF0A161D).withValues(alpha: 0.6),
        );
      }
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF8FE0EC).withValues(alpha: 0.12),
    );
  }

  /// Per-room landmarks + puzzle objects (water surfaces first, under
  /// everything that stands in them).
  void _renderTemple(Canvas canvas, DungeonRoom room) {
    _renderTideWater(canvas, room);
    switch (room.id) {
      case 'tide_gate':
        _drawOfferingBowl(canvas);
        break;
      case 'drowned_court':
        _drawDrownedCourt(canvas, room);
        break;
      case 'tide_works':
        _drawTideWorks(canvas, room);
        break;
      case 'ghost_gallery':
        _drawGhostGallery(canvas, room);
        break;
      case 'pearl_vault':
        _drawPearlShrine(canvas, room.bounds.center);
        break;
      case 'reflection_court':
        _drawReflectionCourt(canvas, room);
        break;
      case 'moon_hall':
        _drawTideMural(canvas, room);
        break;
      case 'moon_well':
        _drawMoonWell(canvas, room);
        break;
      case 'leviathan_depths':
        _drawLeviathanDepths(canvas, room);
        break;
    }
  }

  /// The animated water itself: every tide zone fills and drains with the
  /// live tideAnim — alpha and ripple swell as the water climbs.
  void _renderTideWater(Canvas canvas, DungeonRoom room) {
    for (final z in room.tideZones) {
      final thr = _zoneThreshold(z);
      // How "wet" the zone is right now (starts rising a little early so
      // the flood reads as approaching, not popping).
      final wet = ((tideAnim - (thr - 0.22)) / 0.22).clamp(0.0, 1.0);
      if (z.ledge) {
        if (wet < 1) {
          // The ledge wall, sinking as the water climbs.
          final wallAlpha = (1 - wet) * 0.85;
          canvas.drawRRect(
            RRect.fromRectAndRadius(z.rect, const Radius.circular(8)),
            Paint()
              ..color = const Color(0xFF24404C).withValues(alpha: wallAlpha),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(z.rect, const Radius.circular(8)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = const Color(0xFF4A8AB8).withValues(
                alpha: wallAlpha.clamp(0.0, 0.7),
              ),
          );
        }
        if (wet > 0) {
          // Submerged: the drowned wall's ghost under the swell.
          canvas.drawRRect(
            RRect.fromRectAndRadius(z.rect, const Radius.circular(8)),
            Paint()
              ..color = const Color(0xFF2A6478).withValues(alpha: 0.18 * wet),
          );
        }
        continue;
      }
      // Basins: drained mosaic floor → live water.
      if (wet <= 0) {
        // Drained: the basin reads as a sunken floor.
        canvas.drawRRect(
          RRect.fromRectAndRadius(z.rect, const Radius.circular(10)),
          Paint()..color = const Color(0xFF081218).withValues(alpha: 0.5),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(z.rect, const Radius.circular(10)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFF2A4A56).withValues(alpha: 0.5),
        );
        continue;
      }
      // Water body.
      canvas.drawRRect(
        RRect.fromRectAndRadius(z.rect, const Radius.circular(10)),
        Paint()
          ..color = const Color(0xFF1E6884).withValues(alpha: 0.20 + 0.16 * wet),
      );
      // Two travelling surface highlights.
      final r = z.rect;
      final shine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8FE0EC).withValues(alpha: 0.22 * wet);
      for (var i = 0; i < 2; i++) {
        final phase = _time * (0.5 + i * 0.3) + i * 2.2;
        final y = r.top + r.height * (0.3 + 0.4 * i) + sin(phase) * 6;
        final path = Path()..moveTo(r.left + 12, y);
        var x = r.left + 12.0;
        while (x < r.right - 12) {
          final nx = min(x + 46, r.right - 12);
          path.quadraticBezierTo(
            (x + nx) / 2,
            y + sin(phase + x * 0.05) * 4,
            nx,
            y,
          );
          x = nx;
        }
        canvas.drawPath(path, shine);
      }
      // Rim sparkle while the tide is actively moving.
      if (!tideSettled && _fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          Offset(
            r.left + (r.width) * (0.5 + 0.4 * sin(_time * 2.4)),
            r.top + 6,
          ),
          5,
          const Color(0xFF8FE0EC).withValues(alpha: 0.5),
        );
      }
    }
  }

  void _drawOfferingBowl(Canvas canvas) {
    const c = kTideGateBowl;
    final stone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF4A7080).withValues(alpha: 0.8);
    canvas.drawCircle(c, 30, stone);
    canvas.drawCircle(c, 18, stone..strokeWidth = 1.6);
    final fill = _entryReveal.clamp(0.0, 1.0); // 0 dry-cracked → 1 brimming
    if (fill < 1.0) {
      // Dry: a cracked basin floor, fading as the water rises over it.
      final crack = Paint()
        ..strokeWidth = 1.2
        ..color = const Color(0xFF2A4048).withValues(alpha: 0.8 * (1 - fill));
      canvas.drawLine(c + const Offset(-9, -4), c + const Offset(6, 7), crack);
      canvas.drawLine(c + const Offset(2, -9), c + const Offset(8, 3), crack);
    }
    if (fill > 0.0) {
      // The water rises as a growing pool with a gently swelling surface, then
      // settles mirror-still and luminous when full.
      final rise = Curves.easeOutCubic.transform(fill);
      final radius = 16.0 * rise;
      canvas.drawCircle(
        c,
        radius,
        Paint()..color = const Color(0xFF2A88A8).withValues(alpha: 0.55),
      );
      // A brighter meniscus rim on the rising surface.
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFF8FE0EC).withValues(
            alpha: 0.5 + 0.2 * sin(_time * 3.0),
          ),
      );
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c,
          30 * rise,
          const Color(0xFF8FE0EC).withValues(
            alpha: (0.18 + 0.06 * sin(_time * 2.2)) * rise,
          ),
        );
      }
    }
    // Flanking columns by the inner doors.
    final col = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xFF2A4A56).withValues(alpha: 0.7);
    canvas.drawLine(const Offset(640, 180), const Offset(640, 360), col);
    canvas.drawLine(const Offset(672, 190), const Offset(672, 350), col);
  }

  void _drawDrownedCourt(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    // The moon, vast and pale over the court.
    final moon = Offset(b.center.dx + 190, b.top + 92);
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        moon,
        72,
        const Color(0xFFDCE8F0).withValues(alpha: 0.16 + 0.04 * _skyMood),
      );
    }
    canvas.drawCircle(
      moon,
      34,
      Paint()..color = const Color(0xFFC8DCE8).withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      moon + const Offset(-9, -6),
      6,
      Paint()..color = const Color(0xFF9FB8C8).withValues(alpha: 0.4),
    );
    canvas.drawCircle(
      moon + const Offset(10, 8),
      4,
      Paint()..color = const Color(0xFF9FB8C8).withValues(alpha: 0.35),
    );
    // Broken colonnade down both flanks.
    final col = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xFF22404C).withValues(alpha: 0.62);
    for (var i = 0; i < 4; i++) {
      final x = b.left + 150 + i * 200.0;
      final brokenTop = (i % 2 == 0) ? 50.0 : 30.0;
      canvas.drawLine(
        Offset(x, b.top + 120 + brokenTop),
        Offset(x, b.top + 185),
        col,
      );
      canvas.drawLine(
        Offset(x, b.bottom - 185),
        Offset(x, b.bottom - 120),
        col,
      );
    }
    // Star vigil lights over the mirror gate: tide, current, deep.
    for (var i = 0; i < 3; i++) {
      final p = Offset(b.center.dx + 120 + i * 50.0, b.top + 170);
      final earnedStar = hasStar(i);
      final col2 = earnedStar
          ? const Color(0xFF8FE0EC)
          : const Color(0xFF2A4A56);
      if (_fx.ready && earnedStar) {
        drawGlow(canvas, _fx.glow!, p, 16, col2.withValues(alpha: 0.35));
      }
      _drawStarGlyph(
        canvas,
        p,
        7,
        col2.withValues(alpha: earnedStar ? 0.95 : 0.5),
      );
    }
  }

  void _drawTideWorks(Canvas canvas, DungeonRoom room) {
    // Pipework along the north wall.
    final pipe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xFF2A5868).withValues(alpha: 0.7);
    canvas.drawLine(const Offset(90, 110), const Offset(820, 110), pipe);
    for (final x in const [160.0, 250.0, 340.0]) {
      canvas.drawLine(Offset(x, 110), Offset(x, 165), pipe);
    }
    // Valves: rune-marked wheels (low / mid / high).
    for (final valve in room.tideValves) {
      final p = valve.position;
      final isCurrent = valve.level == tideLevel;
      final wheel = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = (isCurrent
                ? const Color(0xFF8FE0EC)
                : const Color(0xFF4A7080))
            .withValues(alpha: 0.85);
      canvas.drawCircle(p, 16, wheel);
      for (var i = 0; i < 4; i++) {
        final a = i * pi / 2 + (isCurrent ? _time * 0.4 : 0.6);
        canvas.drawLine(
          p + Offset(cos(a), sin(a)) * 6,
          p + Offset(cos(a), sin(a)) * 15,
          wheel,
        );
      }
      // Stand mark beneath: 1–3 wave ticks.
      final ticks = (valve.level ?? 0) + 1;
      for (var i = 0; i < ticks; i++) {
        canvas.drawLine(
          p + Offset(-9 + i * 9.0 - (ticks - 1) * 0.0, 24),
          p + Offset(-3 + i * 9.0, 24),
          Paint()
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF8FE0EC).withValues(alpha: 0.6),
        );
      }
      if (isCurrent && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          p,
          26,
          const Color(0xFF4AB8D8).withValues(alpha: 0.2),
        );
      }
    }
    // Sluice seals: round hatches that glow open.
    final star = room.sealStarIndex;
    final done = star != null && hasStar(star);
    for (final seal in room.tideSeals) {
      final open = done || openedSeals.contains(seal.id);
      final p = seal.position;
      canvas.drawCircle(
        p,
        15,
        Paint()..color = const Color(0xFF0E222A).withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        p,
        15,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = (open ? const Color(0xFF6FE0C0) : const Color(0xFF4A7080))
              .withValues(alpha: 0.9),
      );
      if (open) {
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            p,
            24,
            const Color(0xFF6FE0C0).withValues(alpha: 0.22),
          );
        }
      } else {
        // The seal's tide-mark: which stand it wants (1–3 wave ticks).
        final want = seal.tides.first + 1;
        for (var i = 0; i < want; i++) {
          canvas.drawLine(
            p + Offset(-8 + i * 8.0, -1 + 0.0),
            p + Offset(-2 + i * 8.0, -1),
            Paint()
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFF8FE0EC).withValues(
                alpha: 0.4 + 0.2 * sin(_time * 2 + i),
              ),
          );
        }
      }
    }
  }

  /// The ghost gallery. The STONE is always there — the carved channels, the
  /// spring's mouth, the sea grate — because the flow network is the thing
  /// the player reasons over and reasoning needs something to look at. What
  /// Spirit bares is the WATER: five eddies, each rolling the way its feeder
  /// drives it. High insight adds the flow arrows (t1) and the pips (t2) on
  /// top, on a timer, while the spins themselves stay bare for the run.
  void _drawGhostGallery(Canvas canvas, DungeonRoom room) {
    final star = room.eddyStarIndex;
    final done = star != null && hasStar(star);
    final nodes = _ghostNodes(room);

    // 1) The channels — grooves cut in the mosaic, stone and unhidden.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF071319).withValues(alpha: 0.55);
    final grooveLip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF4A7080).withValues(alpha: 0.34);
    for (final ch in room.ghostChannels) {
      final a = nodes[ch.a], b = nodes[ch.b];
      if (a == null || b == null) continue;
      canvas.drawLine(a, b, groove);
      canvas.drawLine(a, b, grooveLip);
    }

    // 2) The two fixed ends the whole deduction hangs from.
    for (final mouth in room.ghostMouths) {
      _drawGhostMouth(canvas, mouth);
    }
    if (done) return; // the course is run; the water rests

    final bare = _ghostBare.clamp(0.0, 1.0);
    final tiered = eddyRevealTimer > 0;
    final fade = tiered ? (eddyRevealTimer / 2.5).clamp(0.0, 1.0) : 0.0;

    // 3) TIER 1 — the flow itself, an arrow along each live channel.
    if (tiered && eddyRevealTier >= 1) {
      final flow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFB8D8E8).withValues(alpha: 0.55 * fade);
      eddyFeeder.forEach((id, from) {
        final to = nodes[id], src = nodes[from];
        if (to == null || src == null) return;
        _drawFlowArrow(canvas, src, to, flow);
      });
      // …and on out to the sea, so the end of the course reads too.
      String? last;
      eddyOrder.forEach((id, ord) {
        if (ord == room.ghostEddies.length - 1) last = id;
      });
      if (last != null) {
        final from = nodes[last];
        for (final mouth in room.ghostMouths) {
          if (mouth.isSource || from == null) continue;
          _drawFlowArrow(canvas, from, mouth.position, flow);
        }
      }
    }

    // 4) The eddies.
    for (final eddy in room.ghostEddies) {
      final ord = eddyOrder[eddy.id];
      final waded = ord != null && ord < eddyProgress;
      final next = ord != null && ord == eddyProgress;
      final show = waded ? 1.0 : bare;
      if (show <= 0.02) continue;
      // The same rule the solver uses, read straight off the cached nodes
      // (this runs five times a frame — no room scan, no allocation).
      final from = nodes[eddyFeeder[eddy.id]];
      final sunwise = from == null || _spinSunwise(eddy.position, from);
      final col = waded
          ? const Color(0xFF6FE0C0)
          : next && tiered && eddyRevealTier >= 2
          ? const Color(0xFFDCE8F0)
          : const Color(0xFFB8D8E8);
      final swirl = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = col.withValues(alpha: (waded ? 0.62 : 0.52) * show);
      // Three arcs winding inward, TURNING the way the feeder drives them —
      // this rotation IS the puzzle's evidence, so it must read at a glance.
      final spin = sunwise ? 1.0 : -1.0;
      final phase = _time * 1.15 * spin;
      for (var i = 0; i < 3; i++) {
        final r = 19.0 - i * 5.5;
        canvas.drawArc(
          Rect.fromCircle(center: eddy.position, radius: r),
          phase + i * 1.5,
          pi * 1.25,
          false,
          swirl,
        );
      }
      // A chevron riding the outer arc's leading edge — the direction, said
      // twice, because a slow spiral alone is easy to misread.
      _drawSpinChevron(canvas, eddy.position, 19.0, phase + pi * 1.25, spin,
          swirl);
      if (waded && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          eddy.position,
          24,
          const Color(0xFF6FE0C0).withValues(alpha: 0.18),
        );
      }
      // 5) TIER 2 — the water counts itself.
      if (tiered && eddyRevealTier >= 2 && !waded && ord != null) {
        final pip = Paint()
          ..color = const Color(0xFFDCE8F0).withValues(alpha: 0.7 * fade);
        for (var k = 0; k <= ord; k++) {
          canvas.drawCircle(
            eddy.position + Offset(-10 + k * 5.0, -27),
            1.7,
            pip,
          );
        }
      }
    }
  }

  /// A single arrowhead at the far end of a channel (the shaft is the groove
  /// already drawn beneath it) — one chevron, two lines.
  void _drawFlowArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final d = to - from;
    final len = d.distance;
    if (len < 24) return;
    final u = Offset(d.dx / len, d.dy / len);
    final tip = to - u * 24.0;
    final n = Offset(-u.dy, u.dx);
    canvas.drawLine(tip, tip - u * 11 + n * 6, paint);
    canvas.drawLine(tip, tip - u * 11 - n * 6, paint);
  }

  /// The chevron on an eddy's outer arc, pointing the way it turns.
  void _drawSpinChevron(
    Canvas canvas,
    Offset centre,
    double radius,
    double angle,
    double spin,
    Paint paint,
  ) {
    final at = centre + Offset(cos(angle), sin(angle)) * radius;
    // Tangent in the direction of travel.
    final t = Offset(-sin(angle), cos(angle)) * spin;
    final n = Offset(-t.dy, t.dx);
    canvas.drawLine(at, at - t * 7 + n * 4, paint);
    canvas.drawLine(at, at - t * 7 - n * 4, paint);
  }

  /// The spring's carved mouth (source) or the sea grate (drain) — stone, so
  /// both are visible from the first step into the gallery.
  void _drawGhostMouth(Canvas canvas, GhostMouth mouth) {
    final p = mouth.position;
    final stone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF4A7080).withValues(alpha: 0.85);
    canvas.drawCircle(
      p,
      15,
      Paint()..color = const Color(0xFF07141B).withValues(alpha: 0.9),
    );
    canvas.drawCircle(p, 15, stone);
    if (mouth.isSource) {
      // The spring: a mouth with water spilling from it, always running.
      final spill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8FE0EC).withValues(
          alpha: 0.4 + 0.2 * sin(_time * 3.1),
        );
      for (var i = 0; i < 3; i++) {
        final y = p.dy + 6 + ((_time * 26 + i * 11) % 22);
        canvas.drawLine(
          Offset(p.dx - 5 + i * 5.0, y),
          Offset(p.dx - 5 + i * 5.0, y + 6),
          spill,
        );
      }
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          p,
          6,
          const Color(0xFF8FE0EC).withValues(alpha: 0.3),
        );
      }
      return;
    }
    // The sea drain: three bars over a dark throat.
    final bar = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF4A8AB8).withValues(alpha: 0.8);
    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(p.dx + i * 6.0, p.dy - 9),
        Offset(p.dx + i * 6.0, p.dy + 9),
        bar,
      );
    }
  }

  void _drawPearlShrine(Canvas canvas, Offset c) {
    final stone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF4A7080).withValues(alpha: 0.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 22), width: 76, height: 26),
        const Radius.circular(6),
      ),
      stone,
    );
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c - const Offset(0, 4),
        30,
        const Color(0xFFE8F0F4).withValues(
          alpha: 0.2 + 0.08 * sin(_time * 1.8),
        ),
      );
    }
    canvas.drawCircle(
      c - const Offset(0, 4),
      10,
      Paint()..color = const Color(0xFFDCE8F0).withValues(alpha: 0.8),
    );
    canvas.drawCircle(
      c - const Offset(3, 7),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
    _drawRuneCircle(
      canvas,
      c,
      66,
      const Color(0xFF8FE0EC).withValues(alpha: 0.25),
    );
  }

  void _drawReflectionCourt(Canvas canvas, DungeonRoom room) {
    final won = discoveredClouds.contains(kWaterFrozenMoonEggId);
    // The still pool's rim.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(200, 240, 240, 180).inflate(6),
        const Radius.circular(14),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF4A7080).withValues(alpha: 0.6),
    );
    if (won) {
      // The frozen moon, forever: a bright ice disc in the pool.
      final c = _kMoonPoolCentre;
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c,
          54,
          const Color(0xFFDCE8F0).withValues(
            alpha: 0.22 + 0.06 * sin(_time * 1.6),
          ),
        );
      }
      canvas.drawCircle(
        c,
        26,
        Paint()..color = const Color(0xFFCfe4ee).withValues(alpha: 0.65),
      );
      canvas.drawCircle(
        c,
        26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.7),
      );
      // Frost cracks across the disc.
      final crack = Paint()
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.45);
      canvas.drawLine(c + const Offset(-14, -6), c + const Offset(8, 10), crack);
      canvas.drawLine(c + const Offset(4, -16), c + const Offset(10, 6), crack);
      return;
    }
    // The drifting glint, only at the settled middle water — faint, patient.
    final glint = frozenMoonGlint();
    if (glint != null) {
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          glint,
          7,
          const Color(0xFFDCE8F0).withValues(
            alpha: 0.30 + 0.12 * sin(_time * 2.8),
          ),
        );
      }
      canvas.drawCircle(
        glint,
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFDCE8F0).withValues(alpha: 0.28),
      );
    }
  }

  void _drawTideMural(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final panel = Rect.fromCenter(
      center: Offset(b.center.dx, b.top + 120),
      width: 470,
      height: 130,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(10)),
      Paint()..color = const Color(0xFF081820).withValues(alpha: 0.8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF4A7080).withValues(alpha: 0.7),
    );
    // Three carved tide-lines with the moon riding the middle one.
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF8FE0EC).withValues(alpha: 0.5);
    for (var i = 0; i < 3; i++) {
      final y = panel.top + 36.0 + i * 28;
      final path = Path()..moveTo(panel.left + 36, y);
      var x = panel.left + 36.0;
      while (x < panel.right - 120) {
        path.quadraticBezierTo(x + 14, y - 7, x + 28, y);
        x += 28;
      }
      canvas.drawPath(path, ink);
    }
    // The moon glyph on the MIDDLE line; ice diamonds flanking it.
    final moonP = Offset(panel.right - 80, panel.top + 64);
    canvas.drawCircle(
      moonP,
      11,
      Paint()..color = const Color(0xFFDCE8F0).withValues(alpha: 0.6),
    );
    final dia = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFB8E8F0).withValues(alpha: 0.6);
    for (final dx in const [-30.0, 30.0]) {
      final p = moonP + Offset(dx, 0);
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - 7)
          ..lineTo(p.dx + 6, p.dy)
          ..lineTo(p.dx, p.dy + 7)
          ..lineTo(p.dx - 6, p.dy)
          ..close(),
        dia,
      );
    }
  }

  void _drawMoonWell(Canvas canvas, DungeonRoom room) {
    final c = room.bounds.center;
    // The well: a dark depth ringed in old stone.
    canvas.drawCircle(
      c,
      54,
      Paint()..color = const Color(0xFF04101A).withValues(alpha: 0.92),
    );
    canvas.drawCircle(
      c,
      54,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF4A7080).withValues(alpha: 0.8),
    );
    if (guardianAwake || hasStar(2)) {
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c,
          66,
          const Color(0xFF4AB8D8).withValues(
            alpha: 0.18 + 0.08 * sin(_time * 2.0),
          ),
        );
      }
    }
    final truthGlow = _poolFx['truth'] ?? 0;
    for (final pool in room.moonPools) {
      final frozen = (poolStates[pool.id] ?? 0) == 1 || hasStar(2);
      final fx = _poolFx[pool.id] ?? 0;
      final p = pool.position;
      canvas.drawCircle(
        p,
        30,
        Paint()
          ..color = (frozen
                  ? const Color(0xFFCFE4EE)
                  : const Color(0xFF0C2A38))
              .withValues(alpha: frozen ? 0.6 : 0.85),
      );
      canvas.drawCircle(
        p,
        30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = (frozen ? Colors.white : const Color(0xFF4A7080))
              .withValues(alpha: frozen ? 0.65 : 0.7),
      );
      if (frozen) {
        // Frost cracks + a held moon.
        final crack = Paint()
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.45);
        canvas.drawLine(
          p + const Offset(-16, -7),
          p + const Offset(9, 11),
          crack,
        );
        canvas.drawLine(
          p + const Offset(5, -18),
          p + const Offset(11, 7),
          crack,
        );
        canvas.drawCircle(
          p + const Offset(4, -4),
          7,
          Paint()..color = const Color(0xFFDCE8F0).withValues(alpha: 0.7),
        );
        if (fx > 0 && _fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            p,
            48,
            const Color(0xFFB8E8F0).withValues(alpha: 0.25 * fx),
          );
        }
      } else {
        // Liquid: a slow shimmer; insight's truth-glow marks the real two.
        final shimmer = 0.5 + 0.5 * sin(_time * 1.4 + p.dx);
        canvas.drawArc(
          Rect.fromCircle(center: p, radius: 20),
          _time * 0.5,
          pi * 0.8,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFF8FE0EC).withValues(
              alpha: 0.18 + 0.1 * shimmer,
            ),
        );
        if (truthGlow > 0 && pool.isTrue && _fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            p,
            40,
            const Color(0xFFDCE8F0).withValues(
              alpha: (0.28 * (truthGlow / 3)).clamp(0.0, 0.3),
            ),
          );
        }
        if (fx > 0) {
          // A false pool's shatter: flying shards.
          final shard = Paint()
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.5 * fx);
          for (var i = 0; i < 5; i++) {
            final a = i * 1.256 + p.dx;
            final d = 32 + (1.4 - fx) * 26;
            canvas.drawLine(
              p + Offset(cos(a), sin(a)) * d,
              p + Offset(cos(a), sin(a)) * (d + 8),
              shard,
            );
          }
        }
      }
    }
    // The pipe-mouth in the south wall.
    for (final valve in room.tideValves) {
      if (!valve.pipOnly) continue;
      final p = valve.position;
      canvas.drawCircle(
        p,
        11,
        Paint()..color = const Color(0xFF0A1C24).withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        p,
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF4A8AB8).withValues(alpha: 0.8),
      );
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          p,
          4,
          const Color(0xFF8FE0EC).withValues(
            alpha: 0.2 + 0.14 * (0.5 + 0.5 * sin(_time * 2.4)),
          ),
        );
      }
    }
  }

  void _drawLeviathanDepths(Canvas canvas, DungeonRoom room) {
    final g = room.guardian;
    final c = g?.position ?? room.bounds.center;
    // The drowned arena: a worn ring and kelp fronds swaying at its edge.
    canvas.drawCircle(
      c,
      120,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF24505C).withValues(alpha: 0.8),
    );
    final kelp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2A6858).withValues(alpha: 0.6);
    for (var i = 0; i < 7; i++) {
      final a = i * 0.9 + 0.3;
      final base = c + Offset(cos(a), sin(a)) * 150;
      final sway = sin(_time * 1.1 + i * 1.7) * 8;
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy + 16)
          ..quadraticBezierTo(
            base.dx - 6 + sway,
            base.dy - 8,
            base.dx + sway,
            base.dy - 30 - (i % 3) * 8,
          ),
        kelp,
      );
    }
    // Deep glow beneath an awake guardian.
    if (guardianAwake && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        96,
        const Color(0xFF2A88A8).withValues(
          alpha: 0.14 + 0.08 * sin(_time * 1.8),
        ),
      );
    }
  }
}
