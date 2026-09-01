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
//  • Star 2 (Current) — FLOAT THE MOON-LANTERN ON THE TIDE (docs §6.4
//    REWORK). The gallery is one CANAL NETWORK: ten directed grooves cut in
//    stone between a spring mouth, five basins and the sea drain. Every
//    groove is permanently visible and wears its SILL on its lip, so the
//    whole problem is public from the doorway — there is no hidden rule to
//    hold, which is exactly what the old ghost-eddy puzzle got wrong.
//      – THE SILL RULE (`canalChannelLive`): a groove runs when the temple's
//        water tops its sill. LOW runs at every stand · MID from the middle
//        water up · CREST only at the high water · and a DEEP cut runs at low
//        and middle but drowns into a swallowing TORRENT at high.
//      – THE SPILL RULE (`canalSpillFrom`): a basin pours down the LOWEST
//        live groove leaving it. So the TIDE decides most forks — and the
//        temple's own natural fall runs, all the way down, into the BLIND
//        SUMP, a throatless basin with no groove out of it.
//      – The two verbs: play the tide at the gallery's own sluice-bank
//        (element-only Water, and the walk there is the commitment), and
//        plug a basin with ICE (element-only, toggled) to remove it as a
//        destination and force the next-lowest groove. A dam can only ever
//        take an option AWAY — nothing but the water opens a dry sill.
//      – Spirit's reading is FORESIGHT, never the answer: t0 names the deep
//        cuts for the rest of the run, t1 shows where the water would take
//        the lantern next, t2 traces the whole fall at the water as it
//        stands. All of it is knowable without a Spirit, the expensive way.
//      – Losing it is cheap and never a softlock: a grounded or sumped
//        lantern is washed back to the last mouth it passed and re-lit by
//        hand, and the spring mouth always answers. `solveLanternDrift`
//        (public) proves the authored stone reachable, `strandable == 0`,
//        unsolvable at any single stand, and unsolvable without a dam.
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


// Tide tunables. The swing is deliberately watchable: a full low↔high flood
// takes ~4.5s, one step ~2.3s.
const double _kTideRate = 0.22; // fraction/s
const double _kSwimSpeedMul = 0.62; // non-Water creatures wade slowly

// ── Moon-lantern tunables (DEVICE-TUNABLE, all of them) ────
/// How fast the lantern eases along a groove (px/s). The authored grooves run
/// 217–472px, so a crossing is ~3.5–7.6s — long enough to walk to the
/// sluice-bank and back, short enough that dithering costs you the fork.
const double _kLanternDrift = 62.0;

/// How long the lantern turns in a basin before it commits to the next
/// groove. It will not leave on MOVING water, so a change begun inside this
/// window still lands — the honest commit deadline, not a stopwatch.
const double _kLanternDwell = 2.2;

/// Seconds for the backwash to carry a lost lantern to the last mouth it
/// passed (ANIMATED-STATE rule: it is never teleported, not even in failure).
const double _kLanternWashSeconds = 0.9;

/// Seconds for a dam's ice to grow in / thaw back out.
const double _kDamEaseSeconds = 0.55;

/// How close a hand must come to a basin to set the lantern or plug the ice.
const double _kCanalReach = 46.0;

/// The water levels at which the raised sills start to run. These match the
/// tide-zone thresholds exactly (`floodedAt / 2 - 0.03`), so a groove starts
/// running on the same frame the chamber it crosses starts to flood.
const double _kSillMid = 0.47;
const double _kSillCrest = 0.97;

/// Cached geometry for one carved channel — a pure function of the const
/// layout, so it is built once per descent and never recomputed per frame.
class _CanalGeom {
  final CanalChannel channel;
  final Offset a;
  final Offset b;
  final Offset unit;
  final double length;
  const _CanalGeom(this.channel, this.a, this.b, this.unit, this.length);
}

/// One leg of a PROVED lantern route: cross from [from] to [to] with the tide
/// standing at [stand] and [dams] plugged. Public because the full-run test
/// plays the solver's own answer with the real verbs — a hand-copied script
/// would be free to drift away from the stone.
class LanternLeg {
  final String from;
  final String to;
  final CanalSill sill;
  final int stand;
  final List<String> dams;
  const LanternLeg({
    required this.from,
    required this.to,
    required this.sill,
    required this.stand,
    required this.dams,
  });

  @override
  String toString() =>
      '$from→$to (${sill.name} at stand $stand'
      '${dams.isEmpty ? '' : ', dam ${dams.join('+')}'})';
}

extension MirrorTide on PlanetDungeonGame {
  // ── State helpers ───────────────────────────────────────

  void _resetTempleState() {
    tideLevel = 0;
    tideAnim = 0;
    openedSeals.clear();
    // The lantern is fished out of wherever it lies and the ice lets go — but
    // the STONE is unchanged, so a death costs the re-float, never the plan.
    lanternNodeId = null;
    lanternChannel = null;
    lanternT = 0;
    lanternDwell = 0;
    lanternLit = false;
    lanternFlare = 0;
    lanternLosses = 0;
    _lanternWashFrom = null;
    _lanternWashT = 0;
    _lanternPrevNodeId = null;
    dammedNodes.clear();
    _damAnim.clear();
    // What Spirit READ, though, survives: a warning you cannot look at twice
    // is only a memory test (the same reason the old baring was permanent).
    canalRevealTimer = 0;
    canalRevealTier = 0;
    poolStates.clear();
    _poolFx.clear();
    // The well's moon and its listening basins are rolled fresh every run.
    _rollMoonWell();
    _leviathanTideDir = 1;
    _leviathanLullPrev = true;
    _leviathanRoars = 0;
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

  // ── Star 2: the moon-lantern on the canals ──────────────
  //
  // THE TWO RULES, entire, and there is nothing else:
  //   1. SILL — a groove runs when the temple's water tops its sill.
  //   2. SPILL — a basin pours down the LOWEST live groove leaving it.
  // Both are carved into the stone in plain sight. Everything the game does
  // with the canals — the drift, the render, Spirit's forecast — and
  // everything the layout test PROVES about them goes through the same two
  // functions below, so the proof can never drift away from the gameplay.

  /// The gallery — the room that owns the canal network (null elsewhere).
  DungeonRoom? get _canalRoom {
    for (final room in layout.rooms.values) {
      if (room.canalNodes.isNotEmpty) return room;
    }
    return null;
  }

  /// Node id → node, built once from the const layout.
  Map<String, CanalNode> _canalNodes(DungeonRoom room) =>
      _canalNodeCache ??= {for (final n in room.canalNodes) n.id: n};

  /// The gallery's node by id (null off-planet or for an unknown id).
  CanalNode? canalNodeById(String id) {
    final room = _canalRoom;
    return room == null ? null : _canalNodes(room)[id];
  }

  /// Per-channel geometry, built once (the render walks it every frame).
  List<_CanalGeom> get _canalGeometry {
    final cached = _canalGeomCache;
    if (cached != null) return cached;
    final room = _canalRoom;
    if (room == null) return const [];
    final nodes = _canalNodes(room);
    final out = <_CanalGeom>[];
    for (final ch in room.canalChannels) {
      final a = nodes[ch.from]?.position, b = nodes[ch.to]?.position;
      if (a == null || b == null) continue;
      final d = b - a;
      final len = d.distance;
      final unit = len < 0.001 ? Offset.zero : Offset(d.dx / len, d.dy / len);
      out.add(_CanalGeom(ch, a, b, unit, len));
    }
    return _canalGeomCache = out;
  }

  _CanalGeom? _canalGeomFor(CanalChannel ch) {
    for (final g in _canalGeometry) {
      if (identical(g.channel, ch)) return g;
    }
    return null;
  }

  /// THE SILL RULE, half one: the water level at which a sill starts to run.
  /// (A deep cut is floor-level like a low groove — its whole difference is
  /// what the HIGH water does to it, below.)
  double canalSillThreshold(CanalSill sill) => switch (sill) {
    CanalSill.low => 0.0,
    CanalSill.deep => 0.0,
    CanalSill.mid => _kSillMid,
    CanalSill.crest => _kSillCrest,
  };

  /// THE SILL RULE, half two: a deep cut drowned by the high water is not a
  /// channel any more, it is a torrent — and it swallows what floats on it.
  bool canalChannelTorrent(CanalSill sill, double water) =>
      sill == CanalSill.deep && water >= _kSillCrest;

  /// THE SILL RULE. True = this groove is running at [water] (0..1, the same
  /// scale as [tideAnim]). Asked by the drift, the render and the solver.
  bool canalChannelLive(CanalSill sill, double water) =>
      water >= canalSillThreshold(sill) && !canalChannelTorrent(sill, water);

  /// Which sill the water reaches for first when it leaves a basin: the
  /// deepest cut, then the floor groove, then the raised ones. (The layout
  /// test forbids two grooves of the same sill leaving one basin, so this
  /// never comes down to a coin toss the player cannot see.)
  int canalSpillRank(CanalSill sill) => switch (sill) {
    CanalSill.deep => 0,
    CanalSill.low => 1,
    CanalSill.mid => 2,
    CanalSill.crest => 3,
  };

  /// THE SPILL RULE — the one route function. The groove the water takes out
  /// of [nodeId] with the temple standing at [water] and [dammed] basins
  /// plugged, or null if nothing runs and the lantern simply turns and waits.
  ///
  /// Note what a dam can and cannot do: it removes a DESTINATION, so the
  /// water reaches past it for the next-lowest sill. It can never make a dry
  /// groove run — only the tide does that.
  CanalChannel? canalSpillFrom(
    String nodeId, {
    required double water,
    required Set<String> dammed,
  }) {
    final room = _canalRoom;
    if (room == null) return null;
    CanalChannel? best;
    for (final ch in room.canalChannels) {
      if (ch.from != nodeId) continue;
      if (!canalChannelLive(ch.sill, water)) continue;
      if (dammed.contains(ch.to)) continue;
      if (best == null || canalSpillRank(ch.sill) < canalSpillRank(best.sill)) {
        best = ch;
      }
    }
    return best;
  }

  /// True when the basin has no groove leaving it at all — the blind sump.
  /// The water backs up there and hands the lantern back to the last mouth
  /// it passed, which is why arriving in one is a cost and never a trap.
  bool canalIsBlind(String nodeId) {
    final room = _canalRoom;
    if (room == null) return true;
    return !room.canalChannels.any((c) => c.from == nodeId);
  }

  // ── The proof ───────────────────────────────────────────

  /// The dams a player must plug to send the water down [ch] at [water] —
  /// every live groove leaving the same basin that the water would otherwise
  /// reach first. Null when that is impossible (a lower groove runs straight
  /// into the spring or the sea, and neither takes ice).
  List<String>? _canalDamsFor(CanalChannel ch, double water) {
    final room = _canalRoom;
    if (room == null) return null;
    final nodes = _canalNodes(room);
    final dams = <String>[];
    for (final other in room.canalChannels) {
      if (other.from != ch.from || identical(other, ch)) continue;
      if (!canalChannelLive(other.sill, water)) continue;
      if (canalSpillRank(other.sill) > canalSpillRank(ch.sill)) continue;
      final node = nodes[other.to];
      if (node == null || !node.isBasin) return null;
      dams.add(other.to);
    }
    return dams;
  }

  /// Every leg the player can actually make the water take out of [from].
  /// The candidates are proposed from the stone, but each one is only kept
  /// when THE REAL SPILL RULE agrees — the solver never re-implements the
  /// mechanic, it interrogates it.
  List<LanternLeg> canalLegsFrom(
    String from, {
    Iterable<int> stands = const [0, 1, 2],
    bool allowDams = true,
  }) {
    final room = _canalRoom;
    if (room == null) return const [];
    final out = <LanternLeg>[];
    for (final stand in stands) {
      final water = stand / 2;
      for (final ch in room.canalChannels) {
        if (ch.from != from) continue;
        final dams = allowDams ? _canalDamsFor(ch, water) : const <String>[];
        if (dams == null) continue;
        if (canalSpillFrom(from, water: water, dammed: dams.toSet()) != ch) {
          continue;
        }
        out.add(
          LanternLeg(
            from: from,
            to: ch.to,
            sill: ch.sill,
            stand: stand,
            dams: List.unmodifiable(dams),
          ),
        );
      }
    }
    return out;
  }

  /// Breadth-first over the legs the rules actually permit.
  List<LanternLeg>? _canalRoute(
    String from,
    String to, {
    required Iterable<int> stands,
    required bool allowDams,
  }) {
    if (from == to) return const [];
    final prev = <String, LanternLeg>{};
    final seen = <String>{from};
    final queue = <String>[from];
    while (queue.isNotEmpty) {
      final at = queue.removeAt(0);
      for (final leg in canalLegsFrom(
        at,
        stands: stands,
        allowDams: allowDams,
      )) {
        if (!seen.add(leg.to)) continue;
        prev[leg.to] = leg;
        if (leg.to == to) {
          final route = <LanternLeg>[];
          var cursor = to;
          while (cursor != from) {
            final leg = prev[cursor]!;
            route.insert(0, leg);
            cursor = leg.from;
          }
          return route;
        }
        queue.add(leg.to);
      }
    }
    return null;
  }

  /// Every node the lantern can be driven to from [from].
  Set<String> _canalReachable(String from) {
    final seen = <String>{from};
    final queue = <String>[from];
    while (queue.isNotEmpty) {
      for (final leg in canalLegsFrom(queue.removeAt(0))) {
        if (seen.add(leg.to)) queue.add(leg.to);
      }
    }
    return seen;
  }

  /// THE SOLVER (public: the layout test's proof engine). It walks the REAL
  /// sill and spill rules — the same two functions the drift and the render
  /// call — over every basin, every tide stand and every dam the player could
  /// plug, and reports what the authored stone actually guarantees:
  ///
  ///  • [solvable] / [route] — the lantern CAN be floated spring → sea, and
  ///    here is a route a player could follow, leg by leg.
  ///  • [strandable] — how many resting places the lantern can reach from
  ///    which the sea is no longer reachable. MUST be 0: no softlock, and
  ///    structurally, not because dying resets it.
  ///  • [singleStandSolvable] — the stands that would carry the lantern out
  ///    on their own. MUST be empty, or the temple's own tide is decoration.
  ///  • [damFree] — whether the water's natural fall ever reaches the sea.
  ///    MUST be false, or the ice is decoration.
  ({
    int basins,
    int channels,
    int states,
    bool solvable,
    int strandable,
    bool damFree,
    int blindBasins,
    List<int> singleStandSolvable,
    List<LanternLeg> route,
  })
  solveLanternDrift() {
    final room = _canalRoom;
    if (room == null) {
      return (
        basins: 0,
        channels: 0,
        states: 0,
        solvable: false,
        strandable: 0,
        damFree: false,
        blindBasins: 0,
        singleStandSolvable: const [],
        route: const [],
      );
    }
    String? springId, seaId;
    for (final n in room.canalNodes) {
      if (n.isSpring) springId = n.id;
      if (n.isSea) seaId = n.id;
    }
    if (springId == null || seaId == null) {
      return (
        basins: 0,
        channels: room.canalChannels.length,
        states: 0,
        solvable: false,
        strandable: 0,
        damFree: false,
        blindBasins: 0,
        singleStandSolvable: const [],
        route: const [],
      );
    }
    final route =
        _canalRoute(
          springId,
          seaId,
          stands: const [0, 1, 2],
          allowDams: true,
        ) ??
        const <LanternLeg>[];
    final solvable = route.isNotEmpty;
    final damFree =
        _canalRoute(
          springId,
          seaId,
          stands: const [0, 1, 2],
          allowDams: false,
        ) !=
        null;
    final singleStand = <int>[
      for (var s = 0; s < 3; s++)
        if (_canalRoute(springId, seaId, stands: [s], allowDams: true) != null)
          s,
    ];
    // A RESTING PLACE is anywhere the lantern can end up waiting for a hand:
    // the spring (which always answers) and every reachable basin that has a
    // groove leaving it. A blind basin is never one — the backwash gives the
    // lantern straight back to the mouth before it.
    final reachable = _canalReachable(springId);
    var strandable = 0;
    for (final id in reachable) {
      if (id == seaId) continue;
      if (id != springId && canalIsBlind(id)) continue;
      if (_canalRoute(id, seaId, stands: const [0, 1, 2], allowDams: true) ==
          null) {
        strandable++;
      }
    }
    final basins = room.canalNodes.where((n) => n.isBasin).length;
    return (
      basins: basins,
      channels: room.canalChannels.length,
      states: room.canalNodes.length * 3,
      solvable: solvable,
      strandable: strandable,
      damFree: damFree,
      blindBasins: room.canalNodes
          .where((n) => n.isBasin && canalIsBlind(n.id))
          .length,
      singleStandSolvable: singleStand,
      route: route,
    );
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

    if (canalRevealTimer > 0) canalRevealTimer -= dt;
    if (_poolFx.isNotEmpty) {
      _poolFx.updateAll((k, v) => v - dt);
      _poolFx.removeWhere((k, v) => v <= 0);
    }
    // Star 2: the moon-lantern rides the canals. It only drifts while the
    // player is in the gallery — the temple holds its breath behind you, so
    // nothing is ever lost off-screen to a valve turned three rooms away.
    if (room.canalNodes.isNotEmpty) _updateLantern(room, dt);
    // Star 3: the moon waxes, and the water follows it. Same rule — the sky
    // does not turn behind the player's back.
    _updateMoonWell(dt);
  }

  /// The dam ice easing in and out (ANIMATED-STATE rule: never a flip).
  void _updateDamAnim(double dt) {
    if (_damAnim.isEmpty && dammedNodes.isEmpty) return;
    for (final id in dammedNodes) {
      _damAnim[id] = min(1.0, (_damAnim[id] ?? 0) + dt / _kDamEaseSeconds);
    }
    _damAnim.updateAll(
      (id, v) =>
          dammedNodes.contains(id) ? v : max(0.0, v - dt / _kDamEaseSeconds),
    );
    _damAnim.removeWhere((id, v) => v <= 0 && !dammedNodes.contains(id));
  }

  /// THE DRIFT. The lantern eases along a groove; at a basin it turns until
  /// the water is SETTLED and then commits to whatever [canalSpillFrom] says
  /// — the same function the render forecasts with and the solver proves on.
  void _updateLantern(DungeonRoom room, double dt) {
    _updateDamAnim(dt);
    if (lanternFlare > 0) lanternFlare = max(0.0, lanternFlare - dt);
    // The backwash: a lost lantern is carried back to the last mouth it
    // passed. Even failure eases.
    if (_lanternWashT > 0) {
      _lanternWashT = max(0.0, _lanternWashT - dt / _kLanternWashSeconds);
      final home = canalNodeById(lanternNodeId ?? '')?.position;
      final from = _lanternWashFrom;
      if (home != null && from != null) {
        lanternPos = Offset.lerp(
          home,
          from,
          Curves.easeOutCubic.transform(_lanternWashT),
        )!;
      }
      if (_lanternWashT <= 0) _lanternWashFrom = null;
    }
    final star = room.canalStarIndex;
    if (star == null || hasStar(star)) return;
    final atId = lanternNodeId;
    if (!lanternLit || atId == null) return;

    final channel = lanternChannel;
    if (channel == null) {
      // Turning in the basin.
      lanternDwell += dt;
      final at = canalNodeById(atId);
      if (at == null) return;
      lanternPos =
          at.position +
          Offset(sin(_time * 1.7) * 3.6, sin(_time * 2.3 + 1.1) * 2.7);
      if (canalIsBlind(atId)) {
        // The blind sump: no throat, so the water backs up and gives the
        // lantern back. A cost, never a trap.
        _loseLantern(
          _lanternPrevNodeId ?? atId,
          sumped: false,
          message:
              'The sump has no throat — the backwash gives the lantern '
              'up again, dark',
        );
        return;
      }
      // It will not leave on moving water: a change begun before the dwell
      // runs out still lands, and the departure always reads the settled
      // stand the player committed to.
      if (lanternDwell < _kLanternDwell || !tideSettled) return;
      final next = canalSpillFrom(atId, water: tideAnim, dammed: dammedNodes);
      // Nothing runs: the lantern simply keeps turning and waits on the water.
      if (next == null) return;
      lanternChannel = next;
      lanternT = 0;
      onChanged();
      return;
    }

    // Crossing. This is where a mistimed wheel costs you: the groove can
    // drown or dry out with the lantern still in it.
    if (canalChannelTorrent(channel.sill, tideAnim)) {
      _loseLantern(
        atId,
        sumped: true,
        message: 'The high water takes the deep cut — the lantern goes under',
      );
      return;
    }
    if (!canalChannelLive(channel.sill, tideAnim)) {
      _loseLantern(
        atId,
        sumped: false,
        message: 'The groove runs dry — the lantern grounds on the sill',
      );
      return;
    }
    final geom = _canalGeomFor(channel);
    if (geom == null) return;
    lanternT = min(1.0, lanternT + _kLanternDrift * dt / max(1.0, geom.length));
    lanternPos = Offset.lerp(geom.a, geom.b, lanternT)!;
    if (lanternT < 1) return;

    _lanternPrevNodeId = channel.from;
    lanternNodeId = channel.to;
    lanternChannel = null;
    lanternDwell = 0;
    lanternFlare = 0.55;
    final arrived = canalNodeById(channel.to);
    lanternPos = arrived?.position ?? lanternPos;
    if (arrived != null && arrived.isSea) {
      _spawnAlchemyBurst(
        arrived.position,
        producedElement: 'Water',
        reagentElements: const ['Light'],
        particleCount: 26,
        intensity: 1.2,
      );
      earnStar(star);
    } else {
      _spawnAlchemyBurst(
        lanternPos,
        producedElement: 'Water',
        particleCount: 8,
        intensity: 0.5,
      );
    }
    onChanged();
  }

  /// A grounded or swallowed lantern: washed back to [toNodeId], dark, and
  /// waiting for a hand. The stone is untouched, so nothing about the plan is
  /// lost — only the float.
  void _loseLantern(
    String toNodeId, {
    required bool sumped,
    required String message,
  }) {
    _lanternWashFrom = lanternPos;
    _lanternWashT = 1.0;
    lanternChannel = null;
    lanternT = 0;
    lanternDwell = 0;
    lanternLit = false;
    lanternLosses++;
    lanternFlare = 0.5;
    lanternNodeId = toNodeId;
    _lanternPrevNodeId = null;
    if (sumped) {
      // The consequence layer, and only for the sump: the torrent is loud,
      // and the temple's old brine hears it. A dry grounding costs nothing
      // but the walk (§ fail state, real but not punishing).
      _spawnAlchemyBurst(
        _lanternWashFrom ?? lanternPos,
        producedElement: 'Water',
        unstable: true,
        particleCount: 20,
      );
      spawnWispWave(
        element: 'Water',
        center: _lanternWashFrom ?? lanternPos,
        count: 2,
        announce: false,
      );
    }
    _setHint(message, 3.2);
    onChanged();
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
    // Order matters at the canal basins: a hand on the lantern always means
    // the lantern; then Spirit READS (it never plugs, so the temple's own
    // Spirit+Water→Ice braid can't hijack the reading verb); then Ice PLUGS.
    if (_tryLantern(a, room)) return true;
    if (_tryCanalReveal(a, room)) return true;
    if (_tryCanalDam(a, room)) return true;
    if (_tryMoonDial(a)) return true;
    if (_tryMoonBasin(a, room)) return true;
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
      // THE STILL. In the well the pipe-mouth does not cycle the tide — the
      // moon owns the water up here, and a wheel fighting the moon would make
      // the room a tug-of-war with itself. It calms instead.
      //
      // It is placed AFTER the requirement check on purpose: this mouth is
      // the only Pip-gated object in the temple, so the calm inherits that
      // lock rather than dissolving it, and the Water pip keeps a job in the
      // finale — a better one than a tide shortcut it can no longer use.
      if (_atWell && _tryMoonStill(a, valve)) return true;
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

  /// True while the lantern lies dark somewhere, waiting to be re-lit.
  bool get lanternAground => lanternNodeId != null && !lanternLit;

  /// Set (or re-set) the moon-lantern. ANY creature may do it — floating a
  /// lamp is not an elemental act, and making it one would let a bad swap or
  /// a downed slot end a run. The SPRING always answers, wherever the lantern
  /// currently lies: that is the structural reason losing it can never
  /// softlock, and the solver's `strandable == 0` is the stronger claim on
  /// top of it, not the mechanism.
  bool _tryLantern(DungeonCreature a, DungeonRoom room) {
    final star = room.canalStarIndex;
    if (room.canalNodes.isEmpty || star == null || hasStar(star)) return false;
    for (final node in room.canalNodes) {
      if ((a.position - node.position).distance > _kCanalReach) continue;
      if (node.isSea) {
        _setHint('The grate breathes; somewhere below it, the sea');
        return true;
      }
      if (lanternLit && lanternNodeId == node.id) {
        // An ICE hand at the lantern's own basin means the ice — let the dam
        // speak its own refusal rather than swallowing the press here.
        if (a.member.element == 'Ice') return false;
        _setHint('The lantern rides already — the water has it');
        return true;
      }
      // A basin that is neither the spring nor the lantern's own resting
      // place has nothing to set: fall through to the ice and the reading.
      if (!node.isSpring && !(lanternAground && lanternNodeId == node.id)) {
        return false;
      }
      final relit = lanternNodeId != null;
      lanternNodeId = node.id;
      _lanternPrevNodeId = null;
      lanternChannel = null;
      lanternT = 0;
      lanternDwell = 0;
      lanternLit = true;
      lanternFlare = 0.8;
      _lanternWashFrom = null;
      _lanternWashT = 0;
      lanternPos = node.position;
      _spawnAlchemyBurst(
        node.position,
        producedElement: 'Light',
        reagentElements: const ['Water'],
        particleCount: 16,
        intensity: 0.9,
      );
      _setHint(
        relit && !node.isSpring
            ? 'The wick catches again — the lantern turns and waits on the water'
            : 'The moon-lantern takes the spill, and the water takes the '
                  'lantern',
        3.0,
      );
      onChanged();
      return true;
    }
    return false;
  }

  /// Star 2's ICE verb: plug a basin so the water reaches past it for the
  /// next-lowest sill. ELEMENT-ONLY (§4) — every Ice family plugs identically
  /// — and deliberately NOT recipe-able: the temple's Spirit+Water→Ice braid
  /// already has a job three chambers away, and letting it plug basins would
  /// put the reading verb and the damming verb on the same stone for the same
  /// creature. Toggled, so no configuration of ice can ever be a dead end.
  bool _tryCanalDam(DungeonCreature a, DungeonRoom room) {
    final star = room.canalStarIndex;
    if (room.canalNodes.isEmpty || star == null || hasStar(star)) return false;
    for (final node in room.canalNodes) {
      if (!node.isBasin) continue;
      if ((a.position - node.position).distance > _kCanalReach) continue;
      if (a.member.element != 'Ice') {
        // §5.6 BLOCKED: one clause, element-first, no how-to.
        _setBlockedHint('Only Ice plugs a basin');
        return true;
      }
      if (dammedNodes.contains(node.id)) {
        dammedNodes.remove(node.id);
        _spawnAlchemyBurst(
          node.position,
          producedElement: 'Water',
          reagentElements: const ['Ice'],
          particleCount: 12,
          intensity: 0.7,
        );
        _setHint('The plug lets go — the basin runs again', 2.8);
        onChanged();
        return true;
      }
      if (lanternLit && lanternNodeId == node.id && lanternChannel == null) {
        _setBlockedHint('The lantern turns here — the ice will not take');
        return true;
      }
      dammedNodes.add(node.id);
      _spawnAlchemyBurst(
        node.position,
        producedElement: 'Ice',
        reagentElements: [a.member.element],
        particleCount: 18,
        intensity: 0.9,
      );
      _setHint('The basin takes the ice, and holds', 2.8);
      onChanged();
      return true;
    }
    return false;
  }

  /// Star 2's reading: ANY Spirit creature (element-only). What it buys is
  /// FORESIGHT, never the answer — every word of it is knowable by watching
  /// the water instead, the expensive way.
  ///   t0 — the DEEP cuts are named, permanently for the run.
  ///   t1 — …and the groove the water would take next is drawn.
  ///   t2 — …and the whole fall is traced, at the water as it stands now.
  bool _tryCanalReveal(DungeonCreature a, DungeonRoom room) {
    final star = room.canalStarIndex;
    if (room.canalNodes.isEmpty || star == null) return false;
    if (a.member.element != 'Spirit') return false;
    if (hasStar(star)) {
      _setHint('The canals lie quiet — the lantern is away');
      return true;
    }
    canalRevealTier = revealHintTier(a.member.statIntelligence);
    canalRevealTimer = 4.0 + 6.0 * normStat(a.member.statIntelligence);
    sumpsRead = true; // the deep cuts stay named for the rest of the run
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
      canalRevealTier >= 2
          ? 'The whole fall lies bare, basin to basin, for the water as it '
                'stands'
          : canalRevealTier >= 1
          ? 'The deep cuts stand named — and the water shows which groove it '
                'would take next'
          : 'The deep cuts stand named: they run low and middle, and drown '
                'into a torrent at the high water',
      4.2,
    );
    return true;
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
    // THE RITE OF THREE pays this out (see `beginMaximRite`).
    beginMaximRite(kWaterFrozenMoonEggId, glint);
    _spawnAlchemyBurst(
      glint,
      producedElement: 'Ice',
      reagentElements: const ['Light'],
      particleCount: 26,
      intensity: 1.1,
    );
    _setHint('The moon stands frozen', 4.0);
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
    // Raids used to be excluded here. The empty-zone check already covers an
    // arena without a tide, so the raid guard was redundant once the arena
    // started generating one. The tide settles on a timer, needing no verb
    // from the party — which is what makes this safe for a raid squad picked
    // with no element requirement.
    if (g == null || room.tideZones.isEmpty) return;
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
    final canalStar = room.canalStarIndex;
    if (room.canalNodes.isNotEmpty &&
        canalStar != null &&
        !hasStar(canalStar)) {
      return DungeonProgressReadout(
        label: 'LANTERN',
        value: lanternNodeId == null
            ? 'UNSET'
            : !lanternLit
            ? 'AGROUND'
            : 'ADRIFT',
      );
    }
    return null;
  }

  // ── Mask insight ────────────────────────────────────────

  void _templeReveal(DungeonCreature a, DungeonRoom room) {
    if (room.moonDial != null) {
      revealFlash = 0.6;
      revealTier = revealHintTier(a.member.statIntelligence);
      _setInsightHint(_moonWellInsight(revealTier));
      return;
    }
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
        // The gallery's frieze is where the temple wrote its own two rules
        // down. A Mask of any element can read them — the rules were never
        // the secret; only the foresight is, and that is Spirit's.
        final star = room.canalStarIndex;
        if (star != null && hasStar(star)) {
          _setHint('The canals lie quiet — the lantern is away');
          return;
        }
        _setHint(
          revealTier >= 1
              ? 'The frieze reads plain: water spills down the LOWEST groove '
                    'a basin offers it, and a groove only runs once the tide '
                    'tops its sill'
              : 'A frieze of grooves and sills — the temple explaining how '
                    'its own water falls',
          4.4,
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
    _setHint(_nothingHiddenLine());
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
    // Atmosphere ONLY at the gallery's two ends: a named stone thing, no
    // mechanic, no element requirement (§5.6 AMBIENT).
    for (final node in room.canalNodes) {
      if ((a.position - node.position).distance > 70) continue;
      if (node.isSpring) {
        _setAmbientHint('A carved mouth weeps brine into the dark');
        return;
      }
      if (node.isSea) {
        _setAmbientHint('The grate breathes; somewhere below, the sea');
        return;
      }
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
        // Was a three-step procedure read out at the door: turn, stand,
        // open. State only — the valves and the tide they want are the
        // frieze's to explain.
        return 'Tide-Works — three sluices, and the tide standing wrong';
      case 'ghost_gallery':
        // WHAT, never HOW (§5.6): the sills, the spill and the ice are the
        // frieze's and Spirit's to give, not the doorway's.
        return 'Lantern Gallery — the moon-lantern must reach the sea drain';
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
      paint.color = const Color(
        0xFF8FE0EC,
      ).withValues(alpha: (0.22 * (1 - fade) + 0.04).clamp(0.0, 0.26));
      canvas.drawCircle(Offset(x, y), r, paint);
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(x - r * 0.25, y - r * 0.25),
          radius: r * 0.45,
        ),
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
        ..color = const Color(
          0xFF4AB8D8,
        ).withValues(alpha: settled ? 0.55 : 0.75),
    );
    // Stand notches.
    for (var i = 0; i < 3; i++) {
      final y = rect.bottom - h * (0.16 + 0.34 * i);
      canvas.drawLine(
        Offset(rect.left - 3, y),
        Offset(rect.left, y),
        Paint()
          ..strokeWidth = 1.4
          ..color = const Color(
            0xFFE4C16A,
          ).withValues(alpha: i == tideLevel ? 0.9 : 0.3),
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
    // THE WHEELS ARE DRAWN WHEREVER THEY STAND, not by one room's painter.
    //
    // `_drawTideWheels` was called from `_drawTideWorks` alone, while its own
    // doc comment claimed it was "shared by the tide-works and the gallery's
    // own bank" — so the gallery's three wheels were AUTHORED, INTERACTIVE AND
    // INVISIBLE, and the bank moved to the court would have been too. A room
    // with a wheel in it shows the wheel; that is the rule now, and it cannot
    // be broken by adding a bank to a room whose painter forgot to ask.
    if (room.tideValves.any((v) => !v.pipOnly)) {
      _drawTideWheels(canvas, room);
    }
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
        _drawCanalGallery(canvas, room);
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
              ..color = const Color(
                0xFF4A8AB8,
              ).withValues(alpha: wallAlpha.clamp(0.0, 0.7)),
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
          ..color = const Color(
            0xFF1E6884,
          ).withValues(alpha: 0.20 + 0.16 * wet),
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
          ..color = const Color(
            0xFF8FE0EC,
          ).withValues(alpha: 0.5 + 0.2 * sin(_time * 3.0)),
      );
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c,
          30 * rise,
          const Color(
            0xFF8FE0EC,
          ).withValues(alpha: (0.18 + 0.06 * sin(_time * 2.2)) * rise),
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
    // (The rune-marked wheels themselves are drawn by `_renderTemple`, for
    // every room that has a bank — see the note there.)
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
              ..color = const Color(
                0xFF8FE0EC,
              ).withValues(alpha: 0.4 + 0.2 * sin(_time * 2 + i)),
          );
        }
      }
    }
  }

  /// The master sluice wheels. Called from `_renderTemple` for EVERY room
  /// that carries a bank, so the tide-works and the court read identically
  /// and no bank can be added to a room that then fails to paint it.
  void _drawTideWheels(Canvas canvas, DungeonRoom room) {
    for (final valve in room.tideValves) {
      if (valve.pipOnly) continue;
      final p = valve.position;
      final isCurrent = valve.level == tideLevel;
      final wheel = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color =
            (isCurrent ? const Color(0xFF8FE0EC) : const Color(0xFF4A7080))
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
      // Stand mark beneath: 1-3 wave ticks.
      final ticks = (valve.level ?? 0) + 1;
      for (var i = 0; i < ticks; i++) {
        canvas.drawLine(
          p + Offset(-9 + i * 9.0, 24),
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
  }

  /// The Lantern Gallery. EVERY line of this is public information — the
  /// grooves, the fall chevrons, the sill notches, the blind sump's missing
  /// throat — because the puzzle is a thing you reason over, and reasoning
  /// needs something honest to look at. The only things drawn conditionally
  /// are the LIVE water in the running grooves (which is just the tide made
  /// legible) and Spirit's tiered foresight overlay.
  ///
  /// Per-frame cost: the whole network is 10 channels and 7 basins, and all
  /// of the geometry is cached in [_canalGeometry] — nothing here scans the
  /// room or allocates a map.
  void _drawCanalGallery(Canvas canvas, DungeonRoom room) {
    final star = room.canalStarIndex;
    final done = star != null && hasStar(star);
    final geoms = _canalGeometry;

    // 1) The grooves themselves: cut stone, always there.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF071319).withValues(alpha: 0.6);
    final grooveLip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF4A7080).withValues(alpha: 0.34);
    for (final g in geoms) {
      if (g.channel.sill == CanalSill.deep) {
        // A deep cut is CUT DEEPER, and it looks it: a wider, darker throat
        // under the ordinary groove. Nothing about it is hidden — Spirit's
        // reading only saves you finding out at the high water.
        canvas.drawLine(
          g.a,
          g.b,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF040C12).withValues(alpha: 0.55),
        );
      }
      canvas.drawLine(g.a, g.b, groove);
      canvas.drawLine(g.a, g.b, grooveLip);
    }

    // 2) The live water, and the fall it runs in. This IS the tide gauge for
    //    the puzzle: what runs, and which way.
    for (final g in geoms) {
      final live = canalChannelLive(g.channel.sill, tideAnim);
      final torrent = canalChannelTorrent(g.channel.sill, tideAnim);
      if (torrent) {
        _drawTorrent(canvas, g);
      } else if (live) {
        _drawLiveChannel(canvas, g);
      }
      // The fall chevrons are carved, so they show wet or dry — a dry groove
      // still tells you which way it would run.
      _drawFallChevrons(canvas, g, live: live && !torrent);
      _drawSillMark(canvas, g);
    }

    // 3) Spirit's foresight, on its timer, over the top of all of it.
    if (!done) _drawCanalForesight(canvas, room);

    // 4) The basins.
    for (final node in room.canalNodes) {
      _drawCanalNode(canvas, node);
    }

    // 5) The lantern itself.
    if (!done) _drawMoonLantern(canvas);
  }

  /// A running groove: a band of water with two travelling glints sliding
  /// downstream, so "this one is live, and it runs THAT way" reads at a
  /// glance from across the room.
  void _drawLiveChannel(Canvas canvas, _CanalGeom g) {
    canvas.drawLine(
      g.a,
      g.b,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2A88A8).withValues(alpha: 0.42),
    );
    final glint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8FE0EC).withValues(alpha: 0.42);
    for (var i = 0; i < 2; i++) {
      final travel = ((_time * 44 + i * g.length * 0.5) % g.length);
      final head = g.a + g.unit * travel;
      final tail = g.a + g.unit * max(0.0, travel - 16);
      canvas.drawLine(tail, head, glint);
    }
  }

  /// A deep cut drowned by the high water: not a channel any more, a torrent.
  /// It churns, it runs no glints, and it is unmistakable.
  void _drawTorrent(Canvas canvas, _CanalGeom g) {
    final normal = Offset(-g.unit.dy, g.unit.dx);
    final churn = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB8D8E8).withValues(alpha: 0.34);
    final steps = (g.length / 26).clamp(2, 18).toInt();
    for (var i = 0; i < steps; i++) {
      final t = (i + 0.5) / steps;
      final at = g.a + g.unit * (g.length * t);
      final wob = sin(_time * 7 + i * 1.9) * 5.5;
      canvas.drawLine(at - normal * wob, at + normal * wob * 0.4, churn);
    }
  }

  /// Which way the stone falls — carved chevrons along the groove. Brighter
  /// while the groove is running, but never absent: the direction is stone.
  void _drawFallChevrons(Canvas canvas, _CanalGeom g, {required bool live}) {
    final normal = Offset(-g.unit.dy, g.unit.dx);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8FE0EC).withValues(alpha: live ? 0.5 : 0.22);
    final count = (g.length / 90).clamp(1, 6).toInt();
    for (var i = 0; i < count; i++) {
      final at = g.a + g.unit * (g.length * (i + 0.5) / count);
      canvas.drawLine(at, at - g.unit * 7 + normal * 5, paint);
      canvas.drawLine(at, at - g.unit * 7 - normal * 5, paint);
    }
  }

  /// The sill, cut into the groove's lip at the basin it leaves: one notch
  /// low, two mid, three crest — and a deep cut wears a downward hook
  /// instead, brightened once Spirit has named the deep cuts.
  void _drawSillMark(Canvas canvas, _CanalGeom g) {
    final normal = Offset(-g.unit.dy, g.unit.dx);
    final at = g.a + g.unit * 34;
    if (g.channel.sill == CanalSill.deep) {
      final named = sumpsRead;
      final hook = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = named ? 2.2 : 1.6
        ..strokeCap = StrokeCap.round
        ..color = (named ? const Color(0xFFB8D8E8) : const Color(0xFF4A7080))
            .withValues(alpha: named ? 0.7 : 0.5);
      canvas.drawArc(
        Rect.fromCircle(center: at, radius: 7),
        atan2(normal.dy, normal.dx),
        pi,
        false,
        hook,
      );
      return;
    }
    final notches = switch (g.channel.sill) {
      CanalSill.low => 1,
      CanalSill.mid => 2,
      _ => 3,
    };
    final tick = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE4C16A).withValues(alpha: 0.55);
    for (var i = 0; i < notches; i++) {
      final base = at + g.unit * (i * 6.0);
      canvas.drawLine(base - normal * 7, base - normal * 12, tick);
    }
  }

  /// A basin: cut stone with a still surface, an ice cap when it is dammed,
  /// and — for the blind sump — a visibly missing throat.
  void _drawCanalNode(Canvas canvas, CanalNode node) {
    final p = node.position;
    final r = node.isBasin ? 21.0 : 15.0;
    canvas.drawCircle(
      p,
      r,
      Paint()..color = const Color(0xFF07141B).withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const Color(0xFF4A7080).withValues(alpha: 0.85),
    );
    if (node.isSpring) {
      // The spring: a mouth with water spilling from it, always running.
      final spill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(
          0xFF8FE0EC,
        ).withValues(alpha: 0.4 + 0.2 * sin(_time * 3.1));
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
    if (node.isSea) {
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
      return;
    }
    // A basin's water, turning slowly.
    canvas.drawArc(
      Rect.fromCircle(center: p, radius: 13),
      _time * 0.55 + p.dx,
      pi * 1.1,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF8FE0EC).withValues(alpha: 0.22),
    );
    if (canalIsBlind(node.id)) {
      // The blind sump: an X of old iron over a throat that goes nowhere.
      // Drawn, not hinted — the dead end is a thing you can SEE.
      final iron = Paint()
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8A6E48).withValues(alpha: 0.55);
      canvas.drawLine(p + const Offset(-9, -9), p + const Offset(9, 9), iron);
      canvas.drawLine(p + const Offset(9, -9), p + const Offset(-9, 9), iron);
    }
    final ice = _damAnim[node.id] ?? 0;
    if (ice > 0) {
      // The dam: an ice cap that GROWS in and thaws back out.
      final grow = Curves.easeOutBack.transform(ice.clamp(0.0, 1.0));
      canvas.drawCircle(
        p,
        r * 0.92 * grow,
        Paint()..color = const Color(0xFFCFE4EE).withValues(alpha: 0.6 * ice),
      );
      canvas.drawCircle(
        p,
        r * 0.92 * grow,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.6 * ice),
      );
      final crack = Paint()
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.4 * ice);
      canvas.drawLine(
        p + const Offset(-11, -5) * 1.0,
        p + const Offset(6, 8),
        crack,
      );
      canvas.drawLine(p + const Offset(3, -13), p + const Offset(8, 5), crack);
    }
  }

  /// The moon-lantern: a small warm lamp on cold water, bobbing where it
  /// floats and guttered dark where it does not.
  void _drawMoonLantern(Canvas canvas) {
    if (lanternNodeId == null) return;
    final p = lanternPos;
    final lit = lanternLit;
    final warm = lit ? const Color(0xFFE4C16A) : const Color(0xFF6A6455);
    if (lit && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        p,
        30 + lanternFlare * 26,
        warm.withValues(
          alpha: 0.22 + 0.08 * sin(_time * 2.6) + lanternFlare * 0.2,
        ),
      );
    }
    // The float: a little ring of pale wood on the water.
    canvas.drawCircle(
      p,
      9,
      Paint()..color = const Color(0xFF10222C).withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      p,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = warm.withValues(alpha: lit ? 0.85 : 0.5),
    );
    // The flame.
    canvas.drawCircle(
      p,
      lit ? 4.4 + sin(_time * 5.3) * 0.5 : 2.4,
      Paint()..color = warm.withValues(alpha: lit ? 0.9 : 0.4),
    );
    if (!lit) return;
    // A reflection smeared under it, so it reads as floating, not pasted on.
    canvas.drawArc(
      Rect.fromCenter(center: p + const Offset(0, 12), width: 26, height: 8),
      0,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = warm.withValues(alpha: 0.3),
    );
  }

  /// Spirit's foresight overlay. t1 draws the ONE groove the water would take
  /// next out of the lantern's basin; t2 follows that fall all the way to
  /// wherever it ends at the water as it stands. Neither is the answer: both
  /// describe the CURRENT stand, and the whole puzzle is which stands to hold
  /// and when.
  void _drawCanalForesight(Canvas canvas, DungeonRoom room) {
    if (canalRevealTimer <= 0 || canalRevealTier < 1) return;
    final start = lanternNodeId;
    if (start == null) return;
    final fade = (canalRevealTimer / 2.5).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB8D8E8).withValues(alpha: 0.5 * fade);
    final hops = canalRevealTier >= 2 ? room.canalNodes.length : 1;
    var at = start;
    final walked = <String>{start};
    for (var i = 0; i < hops; i++) {
      final ch = canalSpillFrom(at, water: tideAnim, dammed: dammedNodes);
      if (ch == null) break;
      final g = _canalGeomFor(ch);
      if (g == null) break;
      canvas.drawLine(g.a, g.b, paint);
      if (!walked.add(ch.to)) break;
      at = ch.to;
    }
    // Where that fall ENDS, marked — including, pointedly, when it ends in
    // the blind sump.
    final endNode = canalNodeById(at);
    if (endNode != null && at != start) {
      canvas.drawCircle(
        endNode.position,
        26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFFDCE8F0).withValues(alpha: 0.55 * fade),
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
        const Color(
          0xFFE8F0F4,
        ).withValues(alpha: 0.2 + 0.08 * sin(_time * 1.8)),
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
          const Color(
            0xFFDCE8F0,
          ).withValues(alpha: 0.22 + 0.06 * sin(_time * 1.6)),
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
      canvas.drawLine(
        c + const Offset(-14, -6),
        c + const Offset(8, 10),
        crack,
      );
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
          const Color(
            0xFFDCE8F0,
          ).withValues(alpha: 0.30 + 0.12 * sin(_time * 2.8)),
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

  // ── THE MOON WELL · render ─────────────────────────────────
  //
  // The room is one image: a moon standing in an oculus, its light falling
  // down a shaft into black water, and four basins waiting to catch it. Every
  // piece of state the player needs is IN that image — the moon's phase is
  // the target, the shaft's width is the phase, the water's height is the
  // consequence, and a locked basin holds a little moon of its own forever.
  // Nothing here is a gauge, a bar or a number.

  /// The moon over the oculus: a lit disc with a real terminator, maria, a
  /// halo, and an earthshine ghost of the dark limb so a thin moon still
  /// reads as a SPHERE rather than a crescent-shaped hole.
  void _drawTheMoon(Canvas canvas, Offset c, double r, double phase) {
    // Halo — three soft rings rather than a blur, because blur in a paint
    // loop is the one thing this game cannot afford (see the perf notes).
    for (var i = 3; i >= 1; i--) {
      canvas.drawCircle(
        c,
        r + i * 9.0 + _moonWaxFx * 4,
        Paint()
          ..color = const Color(0xFFDCE8F0)
              .withValues(alpha: (0.045 + 0.02 * _moonWaxFx) / i),
      );
    }
    // The dark body first, so the lit part is laid ON a sphere.
    canvas.drawCircle(
      c,
      r,
      Paint()..color = const Color(0xFF14202C).withValues(alpha: 0.96),
    );
    // Earthshine: the unlit limb, barely there.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF6E86A0).withValues(alpha: 0.30),
    );

    // THE LIT FACE. phase 0 = dark, 1 = full. The terminator is an ellipse
    // whose x-radius runs r → 0 → r as the moon fills, which is what a real
    // terminator does and what makes the half-moon read as a half and not as
    // a chord.
    if (phase > 0.02) {
      final lit = Path();
      final k = (phase - 0.5) * 2; // -1 waning-dark … +1 full
      // The bright limb is always on the right here (the oculus faces east).
      lit.addArc(Rect.fromCircle(center: c, radius: r), -pi / 2, pi);
      // Back up the terminator to the top. Sweeping CLOCKWISE from the
      // bottom takes the ellipse's left half and the moon reads gibbous;
      // anticlockwise takes its right half and cuts into the bright limb,
      // which is a crescent. Getting this backwards renders a new moon as a
      // nearly full one, which is exactly what it did.
      lit.arcTo(
        Rect.fromCenter(center: c, width: 2 * r * k.abs(), height: 2 * r),
        pi / 2,
        k >= 0 ? pi : -pi,
        false,
      );
      lit.close();
      // Clip to the LIT path, not to the disc: the maria are features of the
      // sunlit face, and clipped to the whole circle they printed grey blots
      // across the dark limb where nothing should be visible at all.
      canvas.save();
      canvas.clipPath(lit);
      canvas.drawPath(lit, Paint()..color = const Color(0xFFEAF2F8));
      // Maria — the moon's own darker seas, so the face is a face.
      final sea = Paint()..color = const Color(0xFFC3D2DE).withValues(alpha: 0.55);
      canvas.drawCircle(c + Offset(-r * 0.22, -r * 0.28), r * 0.26, sea);
      canvas.drawCircle(c + Offset(r * 0.30, -r * 0.05), r * 0.17, sea);
      canvas.drawCircle(c + Offset(-r * 0.05, r * 0.34), r * 0.21, sea);
      canvas.drawCircle(c + Offset(r * 0.12, r * 0.12), r * 0.10, sea);
      canvas.restore();
    }

    // A cold rim on the lit side.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withValues(alpha: 0.10 + 0.35 * phase),
    );
  }

  /// The oculus: an eye of cut stone the moon sits in, with the shaft of
  /// light falling out of it. The shaft's WIDTH is the phase, so the room is
  /// brighter when the water is higher — the two readings agree.
  void _drawOculus(Canvas canvas, Offset moon, double r, double phase, Rect b) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = const Color(0xFF2A4453).withValues(alpha: 0.85);
    canvas.drawCircle(moon, r + 26, ring);
    // Voussoirs — sixteen cut stones around the eye.
    final joint = Paint()
      ..strokeWidth = 1.4
      ..color = const Color(0xFF0A1620).withValues(alpha: 0.7);
    for (var i = 0; i < 16; i++) {
      final a = i * pi / 8;
      final u = Offset(cos(a), sin(a));
      canvas.drawLine(moon + u * (r + 22), moon + u * (r + 30), joint);
    }
    // THE SHAFT. Two long quads of pale light spreading down into the well.
    if (phase > 0.03) {
      final spread = 0.10 + 0.20 * phase;
      final reach = b.bottom - moon.dy;
      final top = r + 20;
      // Three nested wedges rather than one, so the beam has a soft edge
      // without a blur — the same trick the halo uses, and for the same
      // reason (blur in a paint loop is this game's worst jank source).
      for (var s = 3; s >= 1; s--) {
        final f = s / 3;
        final shaft = Path()
          ..moveTo(moon.dx - top * f, moon.dy)
          ..lineTo(moon.dx + top * f, moon.dy)
          ..lineTo(moon.dx + top * f + reach * spread * f, b.bottom)
          ..lineTo(moon.dx - top * f - reach * spread * f, b.bottom)
          ..close();
        canvas.drawPath(
          shaft,
          Paint()
            ..color = const Color(0xFFBFD9E8)
                .withValues(alpha: (0.010 + 0.018 * phase)),
        );
      }
      // Motes riding the beam — slow, few, and cheap.
      for (var i = 0; i < 7; i++) {
        final t = ((_time * 0.06 + i * 0.143) % 1.0);
        final y = moon.dy + reach * t;
        final w = top + reach * t * spread;
        final x = moon.dx + sin(i * 2.1 + _time * 0.5) * w * 0.7;
        canvas.drawCircle(
          Offset(x, y),
          1.6,
          Paint()
            ..color = const Color(0xFFEAF2F8)
                .withValues(alpha: (0.30 * (1 - t) * phase).clamp(0.0, 0.3)),
        );
      }
    }
  }

  /// The dial Spirit stands on: a plinth ringed with the seven notches, the
  /// standing one lit. It is a phase ring, not a slider — the shape of the
  /// mark IS the shape of the moon it asks for.
  void _drawMoonDial(Canvas canvas, Offset p) {
    canvas.drawCircle(
      p,
      30,
      Paint()..color = const Color(0xFF0B1C26).withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      p,
      30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + _moonDialFx * 1.6
        ..color = const Color(0xFF8FE0EC)
            .withValues(alpha: 0.45 + 0.45 * _moonDialFx),
    );
    for (var i = 0; i < kMoonNotches; i++) {
      // Laid out along the TOP arc, waning left to waxing right, so the ring
      // reads the way the sky moves rather than as a clock face.
      final a = -pi + pi * (i / (kMoonNotches - 1));
      final at = p + Offset(cos(a), sin(a)) * 22;
      final here = i == moonNotch;
      final ph = i / (kMoonNotches - 1);
      canvas.drawCircle(
        at,
        here ? 5.0 : 3.0,
        Paint()
          ..color = const Color(0xFFEAF2F8)
              .withValues(alpha: here ? 0.95 : 0.16 + 0.24 * ph),
      );
      if (here) {
        canvas.drawCircle(
          at,
          8.0 + _moonDialFx * 3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withValues(alpha: 0.5),
        );
      }
    }
    // The calm, while the still holds: a glassy sheen over the plinth.
    if (moonCalmLeft > 0) {
      final u = (moonCalmLeft / _kCalmSeconds).clamp(0.0, 1.0);
      canvas.drawCircle(
        p,
        34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0xFF4AB8D8).withValues(alpha: 0.5 * u),
      );
    }
  }

  void _drawMoonWell(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final dial = room.moonDial;
    final phase = moonNotch / (kMoonNotches - 1);
    final moonAt = Offset(b.center.dx, b.top + 118);

    // Sky first, then the room it falls into.
    _drawOculus(canvas, moonAt, 46, phase, b);
    _drawTheMoon(canvas, moonAt, 46, phase);

    final c = b.center;
    // The well itself: a dark depth ringed in old stone, and the moon lying
    // on the black water at the bottom of it.
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
    // THE REFLECTION — the same moon, wrong way up and never quite still.
    // It is the honest reading of the phase for a player who cannot see the
    // sky from where they are standing.
    if (phase > 0.03) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: 50)));
      // The same moon, upside down and never quite still. Drawn as three
      // horizontal slices offset against each other, which is what a
      // reflection on moving water actually does — and costs three cheap
      // clips instead of a blur.
      for (var i = 0; i < 3; i++) {
        final wob = sin(_time * 0.9 + i * 1.9) * 4.0;
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(c.dx - 52, c.dy - 26 + i * 17.0, 104, 17));
        canvas.save();
        canvas.translate(c.dx + wob, c.dy);
        canvas.scale(1, -1);
        canvas.translate(-c.dx, -c.dy);
        _drawTheMoon(canvas, c, 24, phase);
        canvas.restore();
        canvas.restore();
      }
      // and the black water over it
      canvas.drawCircle(
        c,
        50,
        Paint()..color = const Color(0xFF04101A).withValues(alpha: 0.45),
      );
      canvas.restore();
    }
    if (guardianAwake || hasStar(2)) {
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c,
          66,
          const Color(
            0xFF4AB8D8,
          ).withValues(alpha: 0.18 + 0.08 * sin(_time * 2.0)),
        );
      }
    }

    if (dial != null) _drawMoonDial(canvas, dial);

    // THE BASINS.
    for (final pool in room.moonPools) {
      final frozen = (poolStates[pool.id] ?? 0) == 1 || hasStar(2);
      final fx = _poolFx[pool.id] ?? 0;
      final want = poolWants[pool.id];
      final p = pool.position;
      canvas.drawCircle(
        p,
        30,
        Paint()
          ..color = (frozen ? const Color(0xFFCFE4EE) : const Color(0xFF0C2A38))
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
        // A held moon, forever — the basin's own little full disc, with the
        // frost that took it.
        _drawTheMoon(canvas, p, 15, 1.0);
        final crack = Paint()
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.45);
        canvas.drawLine(p + const Offset(-22, -10), p + const Offset(-9, -2), crack);
        canvas.drawLine(p + const Offset(20, 12), p + const Offset(8, 4), crack);
        canvas.drawLine(p + const Offset(-4, 24), p + const Offset(2, 12), crack);
        continue;
      }

      // AN UNLOCKED BASIN SHOWS WHAT IT IS WAITING FOR, and shows it as a
      // MOON — the mark is the shape of the thing it wants, so there is
      // nothing to decode and no legend to learn. A deaf basin shows still
      // black water and never pretends otherwise.
      if (want != null) {
        final wantPhase = want / (kMoonNotches - 1);
        _drawTheMoon(canvas, p, 13, wantPhase);
        // And how close the sky is to it: a ring that closes as the moon
        // approaches, complete and bright the moment the basin would take it.
        final off = (moonNotch - want).abs();
        final near = (1 - off / 3).clamp(0.0, 1.0);
        final ready = off == 0 && moonHoldT >= _kPoolHold;
        canvas.drawArc(
          Rect.fromCircle(center: p, radius: 24),
          -pi / 2,
          pi * 2 * (ready ? 1.0 : near),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ready ? 2.6 : 1.6
            ..strokeCap = StrokeCap.round
            ..color = (ready ? Colors.white : const Color(0xFF8FE0EC))
                .withValues(alpha: ready ? 0.9 : 0.22 + 0.3 * near),
        );
        if (ready && _fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            p,
            42,
            const Color(0xFFDCE8F0)
                .withValues(alpha: 0.16 + 0.10 * sin(_time * 3.4)),
          );
        }
      } else {
        // Deaf water: a shiver of reflected light and nothing in it.
        final shimmer = 0.5 + 0.5 * sin(_time * 1.3 + p.dx * 0.01);
        canvas.drawCircle(
          p,
          19,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFF8FE0EC)
                .withValues(alpha: 0.10 + 0.06 * shimmer),
        );
      }

      if (fx > 0) {
        // A refusal: rings pushing back out of the water.
        canvas.drawCircle(
          p,
          30 + (1 - fx) * 18,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = const Color(0xFF8FE0EC).withValues(alpha: 0.5 * fx),
        );
      }
    }

    // The pipe-mouth in the south wall — THE STILL.
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
      // While the well is calm, still rings stand off the mouth.
      if (moonCalmLeft > 0) {
        final u = (moonCalmLeft / _kCalmSeconds).clamp(0.0, 1.0);
        for (var i = 1; i <= 3; i++) {
          canvas.drawCircle(
            p,
            11.0 + i * 9,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = const Color(0xFF4AB8D8).withValues(alpha: 0.30 * u / i),
          );
        }
      }
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          p,
          4,
          const Color(
            0xFF8FE0EC,
          ).withValues(alpha: 0.2 + 0.14 * (0.5 + 0.5 * sin(_time * 2.4))),
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
        const Color(
          0xFF2A88A8,
        ).withValues(alpha: 0.14 + 0.08 * sin(_time * 1.8)),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════
// THE MOON WELL — Water's Star 3 (docs §6)
// ═══════════════════════════════════════════════════════════
//
// WHAT THIS REPLACES. Four pools, two of them true, frozen at settled mid
// tide. You read the room, you pick two, you are done — a one-shot
// identification check with no play in it, and it wasted the room: an oculus
// open to the sky with a moon standing in it, used as a backdrop.
//
// THE REVEAL IT IS BUILT AROUND. The whole temple is wheels. Every sluice,
// every master valve, every pipe-mouth — the tide is a thing you crank. Here
// you find out the wheels were only ever bleeding water off: the MOON moves
// the sea, and under an open oculus it moves it directly.
//
// THE LOOP. The moon waxes on its own and never stops, so the drift is the
// clock — no timer is drawn, because the moon is the timer and it is what the
// player is already looking at. Three stations, one per element, and
// swap-control means only one of them is ever in your hands:
//
//   SPIRIT at the dial wanes the moon a notch (its first verb on this planet).
//   WATER at the still calms the well, halving the wax for a few seconds.
//   ICE at a pool locks it, if the moon is sitting at the notch that pool
//   wants and has HELD there.
//
// And the coupling that makes it a puzzle rather than a chore: the notch you
// must hit also decides how hard that pool is to reach. A fat moon floods the
// room and a non-Water creature swims at 0.62x, so setting the value
// lengthens the walk you have to make while it drifts away from you. Neither
// pool is hard alone; the pair pulls in opposite directions.

/// Notches the moon can stand at: new (0) through full (6).
const int kMoonNotches = 7;

/// Seconds per notch of unattended waxing. THE clock of the room.
const double _kMoonWaxSeconds = 4.5;

/// Seconds the still holds, and what it does to the wax while it lasts.
const double _kCalmSeconds = 6.0;
const double _kCalmFactor = 0.5;

/// How long the moon must SIT at a notch before a basin will take it. A pool
/// wants the moon still, not merely passing through.
const double _kPoolHold = 1.2;

/// Reach for the dial, the still and a basin.
const double _kDialReach = 54.0;
const double _kPoolReach = 50.0;

/// The notches a basin may ask for. Deliberately off the ends: notch 0 and 6
/// are where the drift PARKS (0 is where waning bottoms out, 6 is where the
/// sky pushes to), and a target you can hold by doing nothing is not a target.
const List<int> kMoonWantable = [1, 2, 4, 5];

/// The tide stand each notch calls for. Two notches per stand at the ends and
/// three in the middle, so the water is a coarse read of the moon and the
/// moon is the fine one — you cannot solve the room off the water alone.
int moonStandFor(int notch) => notch <= 1 ? 0 : (notch <= 4 ? 1 : 2);

extension PlanetDungeonMoonWell on PlanetDungeonGame {
  DungeonRoom? get _wellRoom {
    for (final r in layout.rooms.values) {
      if (r.moonDial != null) return r;
    }
    return null;
  }

  bool get _atWell => _isTemple && currentRoom.moonDial != null;

  /// Has the ice bridge been laid — both listening basins locked?
  bool get moonBridgeWhole =>
      poolWants.isNotEmpty &&
      poolWants.keys.every((id) => (poolStates[id] ?? 0) == 1);

  /// Roll this run's listening basins and what each wants.
  ///
  /// Two of the four, and their notches at least 2 apart — so the pair always
  /// pulls the moon (and the water, and the length of the walk) in opposite
  /// directions, which is the whole design. Everything about the room is
  /// re-rolled on death: the stone is unchanged, the reading is not.
  void _rollMoonWell() {
    poolWants.clear();
    moonNotch = 3;
    moonWaxT = 0;
    moonHoldT = 0;
    moonCalmLeft = 0;
    _moonDialFx = 0;
    _moonWaxFx = 0;
    _moonSynced = false;
    final room = _wellRoom;
    if (room == null || room.moonPools.length < 2) return;
    final rng = Random();
    final pools = [...room.moonPools]..shuffle(rng);
    final notches = [...kMoonWantable]..shuffle(rng);
    int a = notches.first;
    int b = notches.firstWhere(
      (n) => (n - a).abs() >= 2,
      orElse: () => a >= 4 ? 1 : 5,
    );
    poolWants[pools[0].id] = a;
    poolWants[pools[1].id] = b;
  }

  /// The moon's own turning. Runs only in the well: the sky does not wax
  /// behind the player's back, for the same reason the lantern does not drift
  /// behind it — nothing in this temple is lost off-screen.
  void _updateMoonWell(double dt) {
    if (!_atWell) {
      _moonSynced = false;
      return;
    }
    if (moonBridgeWhole || hasStar(2)) return;
    // THE MOON AND THE WATER MUST AGREE THE MOMENT YOU WALK IN. The tide is
    // temple-wide and set by wheels three rooms away, so the well can be
    // entered at any stand — and a moon that disagreed with it dragged the
    // water to a new stand on its very first wax, without anyone touching
    // anything. The moon takes the standing water as its own, which is only
    // the fiction told straight: the sky was always what the wheels were
    // bleeding against.
    if (!_moonSynced) {
      _moonSynced = true;
      moonNotch = switch (tideLevel) { 0 => 1, 1 => 3, _ => 5 };
      moonWaxT = 0;
      moonHoldT = 0;
    }
    if (moonCalmLeft > 0) moonCalmLeft = max(0, moonCalmLeft - dt);
    if (_moonDialFx > 0) _moonDialFx -= dt * 1.6;
    if (_moonWaxFx > 0) _moonWaxFx -= dt * 1.1;
    moonHoldT += dt;
    if (moonNotch >= kMoonNotches - 1) {
      // Full, and it stays full until someone pulls it back. The sky is not
      // a wheel that spins round: it is a weight that always rolls one way.
      moonWaxT = 0;
      return;
    }
    moonWaxT += dt * (moonCalmLeft > 0 ? _kCalmFactor : 1.0);
    if (moonWaxT >= _kMoonWaxSeconds) {
      moonWaxT = 0;
      moonNotch++;
      moonHoldT = 0;
      _moonWaxFx = 1.0;
      _syncTideToMoon();
    }
  }

  /// The water follows the moon, easing exactly as it does everywhere else.
  void _syncTideToMoon() {
    final want = moonStandFor(moonNotch);
    if (want != tideLevel) _setTide(want);
  }

  /// SPIRIT at the dial: one press wanes the moon a notch.
  bool _tryMoonDial(DungeonCreature a) {
    final dial = currentRoom.moonDial;
    if (dial == null || hasStar(2) || moonBridgeWhole) return false;
    if ((a.position - dial).distance > _kDialReach) return false;
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'The well sleeps — it answers only a bearer of both the '
        '${layout.starName(0)} and ${layout.starName(1)}',
      );
      return true;
    }
    if (a.member.element != 'Spirit') {
      _setBlockedHint('Only Spirit has any purchase on the moon');
      return true;
    }
    if (moonNotch <= 0) {
      _setBlockedHint('The moon is dark — there is nothing left to take');
      return true;
    }
    moonNotch--;
    moonWaxT = 0;
    moonHoldT = 0;
    _moonDialFx = 1.0;
    _syncTideToMoon();
    _spawnAlchemyBurst(
      dial,
      producedElement: 'Spirit',
      reagentElements: const ['Water'],
      particleCount: 10,
      intensity: 0.6,
    );
    return true;
  }

  /// WATER at the still: calm the well and halve the wax for a while.
  bool _tryMoonStill(DungeonCreature a, TideValve valve) {
    if (!_atWell || hasStar(2) || moonBridgeWhole) return false;
    if (a.member.element != 'Water') return false;
    if (moonCalmLeft > 0) {
      _setHint('The well is already still');
      return true;
    }
    moonCalmLeft = _kCalmSeconds;
    _spawnAlchemyBurst(
      valve.position,
      producedElement: 'Water',
      particleCount: 12,
      intensity: 0.55,
    );
    _setHint('The well goes glassy — the moon slows in it', 2.6);
    return true;
  }

  /// ICE at a basin: lock it, if the moon is standing where it wants.
  bool _tryMoonBasin(DungeonCreature a, DungeonRoom room) {
    if (room.moonPools.isEmpty || hasStar(2)) return false;
    for (final pool in room.moonPools) {
      if ((a.position - pool.position).distance > _kPoolReach) continue;
      if (!guardianRiteUnlocked) {
        _setBlockedHint(
          'The pools sleep — they answer only a bearer of both the '
          '${layout.starName(0)} and ${layout.starName(1)}',
        );
        return true;
      }
      if ((poolStates[pool.id] ?? 0) == 1) {
        _setHint('This basin holds its moon already');
        return true;
      }
      final r = evaluateInteraction(
        a.member,
        const DungeonInteractionRequirement(element: 'Ice', allowRecipe: true),
        recipeAvailable: a.member.element == 'Spirit',
      );
      final viaRecipe = r == InteractionResult.passedViaRecipe;
      if (!interactionSucceeded(r)) {
        _setBlockedHint(
          'Ice would take this basin — or Spirit standing in the water',
        );
        return true;
      }
      final want = poolWants[pool.id];
      if (want == null) {
        // A DEAF BASIN COSTS NOTHING. The old version shattered a false pool
        // and threw fury wisps — a consumed attempt in a finale, and the only
        // thing in the room that could strand a run.
        _poolFx[pool.id] = 0.8;
        _setHint('Nothing looks back out of this water', 2.4);
        return true;
      }
      if (moonNotch != want) {
        _poolFx[pool.id] = 0.6;
        _setHint(
          moonNotch < want
              ? 'The moon is too thin for this basin'
              : 'The moon is too full for this basin',
          2.4,
        );
        return true;
      }
      if (moonHoldT < _kPoolHold) {
        _setBlockedHint('The moon is still moving — let it settle');
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
        // The RECIPE's downside, unchanged: braiding Spirit through the water
        // is a loud way to make ice, and the brine hears it.
        spawnWispWave(
          element: 'Water',
          center: pool.position,
          count: 2,
          announce: false,
        );
      }
      if (moonBridgeWhole) {
        guardianAwake = true;
        guardianHp = PlanetDungeonGame.maxGuardianHp;
        _setHint(
          'Two moons stand frozen in the well — the bridge holds, and the '
          'deep stirs beyond',
          4.2,
        );
        spawnWispWave(
          element: 'Water',
          center: room.bounds.center,
          count: 3,
          unstable: true,
        );
      } else {
        _setHint('The basin takes the moon and holds it', 3.0);
      }
      return true;
    }
    return false;
  }

  /// What insight says about the well, by tier. It never gives both notches.
  String _moonWellInsight(int tier) {
    if (hasStar(2) || moonBridgeWhole) {
      return 'The bridge stands — the well keeps nothing back now';
    }
    final wants = poolWants.values.toList()..sort();
    if (wants.length < 2) return 'The well is quiet';
    String phase(int n) => switch (n) {
      0 => 'a dark moon',
      1 => 'a thin crescent',
      2 => 'a half moon',
      3 => 'a half moon',
      4 => 'a swelling moon',
      5 => 'a near-full moon',
      _ => 'a full moon',
    };
    return switch (tier) {
      <= 0 =>
        'Two of these basins are listening — one for a thin moon, one for a '
            'fat one',
      1 =>
        'Two basins are listening, and one of them wants ${phase(wants.first)}',
      _ =>
        'Two basins are listening: one wants ${phase(wants.first)}, the other '
            '${phase(wants.last)}',
    };
  }
}
