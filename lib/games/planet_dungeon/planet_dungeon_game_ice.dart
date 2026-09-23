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
//  • Star 1 (Mirror) — THE MIRROR GALLERY, on L1. WHAT YOU CAN SEE DEPENDS
//    ON WHERE YOU STAND: the chart is on a ceiling of glacier ice and is
//    never read directly, only in the still pool — which shows the quarter of
//    sky OPPOSITE the party and etches it on the frame that quarter belongs
//    to, across the ring. Walk the rim and the whole sky comes up on the
//    walls; the chart carries every figure twice save ONE, and ICE silvers
//    the stranger's frame to bank it. The LODESTONE takes no frost:
//    Light+MASK strikes it (the planet's marquee gate) and that is what wakes
//    the water at all. AIR's sweep off the cold vent stills the pool wide
//    enough to read three quarters at once — it saves walking and can never
//    fail you. Nothing in this room melts, and nothing in it is timed.
//  • Rite (Star Font) — THE ROOF OF THE HOLLOW (2026-09-20). The room's floor
//    is the ice over the wyrm's lair, in panes under snow. Snow bears all and
//    shows nothing; Light bares a pane, and bare ice over the hollow bears
//    ONE body. The wyrm sleeps under it (rolled per run) and every bared pane
//    says which way its head lies. Open the glass over the head and that is
//    the THROAT: Air+WING turns the last breath down it (the second gate),
//    Ice sings the font on its pier (conduit 'B'), the wyrm wakes, and the
//    party goes down the throat together.
//  • Star 2 (Frost) — MYS09 FROWYRM. §7: the guardian fights WITH the
//    planet's rule. Its lull only opens while the hollow's hoarfrost pillar
//    stands, and every strike beat shatters the pillar AND SCOURS ONE OF YOUR
//    STAIRS in the shaft above — it eats your way home while you fight it.
//  • Lost Maxim — STAR-WALKER: THE STRANGER. A shaft ridden bare is a
//    mirror, and the pool under it sees the sky: one star hangs there that
//    no frame charts, on a bearing. Carry the bearing down chute B, turn the
//    lens to it with Air, and lock the sighting with Ice.
//    Built on the state the primer tells you never to make.
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

/// How long the wyrm is, in panes of the roof.
const int kIceWyrmLength = 5;

/// How close to the throat's centre a body counts as AT ITS EDGE — on one of
/// its neighbouring panes, wherever on that pane it stands.
const double _kRoofEdge = 140.0;

/// What a bared pane of the roof shows: what the ice lies on, wyrm included.
enum IceRoofUnder { rock, pier, hollow, body, head }

/// Said ONCE in a lifetime, the first time bare ice shows the hollow.
const String kIceRoofTeachId = 'teach:ice_roof';

/// How long the chart's light-up runs when the Mirror Star is banked.
const double _kChartTriumphSeconds = 3.2;

/// Stars in the gallery's chart: TWO TO A FRAME, so every frame shares stars
/// with its neighbours and no frame can ever be judged on its own. That
/// overlap is the whole engine of the room — evidence about a PAIR.
const int kIceChartStars = 24;

// ── Device-tunable knobs ───────────────────────────────────
// Ice has never been on a device; every number the feel depends on is named
// here so a tuning pass is edit-one-block.

/// How close a creature must stand to a flue mouth, the cap, the rimefall,
/// the font or the hoarfrost pillar to act on it.
const double _kShaftReach = 66.0;

/// Air's sweep off the vent is a FLASH, not a reveal (2026-09-20): the rime
/// lifts, the whole chart shows for half a second, and it fades back to
/// whatever the lamp was reading. It used to still the water for 12s, which
/// made the sweep the way to read the room and the lamp a formality. The
/// sweep re-arms quickly because a glimpse is all it gives; nothing about
/// the gallery can time out.
const double _kMirrorSweepCooldown = 4.0;
const double _kPoolFlashHoldSeconds = 0.5;
const double _kPoolFlashFadeSeconds = 1.2;

/// How close a creature must stand to a mirror frame to work it.
const double _kMirrorReach = 60.0;

/// Seconds a star-block takes to cross one cell of glass. It used to arrive
/// instantly, which made the one moving thing on the floor a teleport.
const double _kSlidePerCell = 0.13;

/// How many cells of road one glaze throws down the way you are facing.
const int _kGlazeReach = 3;

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
    // Knowledge, not run state: a plate Light has drunk stays drunk, across a
    // death and across a session (the engine's own entry reveal, per mouth).
    meltedCaps
      ..clear()
      ..addAll(
        discoveredClouds
            .where((c) => c.startsWith(_kCapDiscoveryPrefix))
            .map((c) => c.substring(_kCapDiscoveryPrefix.length)),
      );
    rimefallFrozen = false;
    shaftThaws = 0;
    mirrorChart.clear();
    frameOffset.clear();
    silveredFrames.clear();
    chartTriumph = 0;
    lodestoneLit = false;
    mirrorSweep = 0;
    poolStill = 0;
    orreryGlass.clear();
    orreryBlocks.clear();
    orrerySeated.clear();
    _seedOrrery();
    hoarfrostWhole = false;
    _hoarfrostDown = 0;
    // THE STRANGER hangs on a fresh bearing each run, never the lodestone's
    // (the lens rests on that one, and a secret the rest position solves is
    // no secret). The water has shown nobody anything yet.
    final ring = _mirrorRingRoom?.rime?.mirrors;
    final frames = ring?.count ?? 12;
    final lode = ring?.lodestoneIndex ?? 0;
    strangerFrame = (lode + 1 + Random().nextInt(frames - 1)) % frames;
    strangerSeen = false;
    telescopeNotch = lode;
    telescopeSwing = 0;
    _seedRoof();
    _roofBlockReason = null;
    _roofBlockCooldown = 0;
  }

  /// The shaft, back to the state it opened in. Called by THE THAW when the
  /// rimefall carries you out at the top — and only there.
  ///
  /// THE ORRERY GOES WITH IT. The valve is the planet's anti-softlock (§5.5:
  /// "costly full-state reset valve"), and a shaft whose STAIRS reset while
  /// its star-blocks stayed where a bad shove left them was only half a
  /// valve. An earned star is never given back — once the orrery stands, the
  /// thaw leaves it standing.
  void _thawShaft() {
    for (final f in kRimeFlues) {
      flueState[f.id] = RimeFlueState.drift;
    }
    rimefallFrozen = false;
    shaftThaws++;
    final orreryStar = _orreryRoom?.rime?.starIndex;
    if (orreryStar != null && !hasStar(orreryStar)) {
      orreryGlass.clear();
      orreryBlocks.clear();
      orrerySeated.clear();
      _seedOrrery();
    }
  }

  // ── The flue graph ───────────────────────────────────────

  RimeFlueState _flue(String id) => flueState[id] ?? RimeFlueState.drift;

  static const String _kCapDiscoveryPrefix = 'rune:ice_cap:';

  /// Every opening in a room's floor, as (id, where it is). A head carries
  /// its SHAFT and, where there is a ledge, that ledge's own CHUTE.
  List<(String, Offset)> _iceMouths(String roomId) => [
    for (final f in kRimeFlues)
      if (f.headRoom == roomId) ...[
        ('${f.id}:shaft', f.headPos),
        if (f.chutePos != null) ('${f.id}:chute', f.chutePos!),
      ],
  ];

  /// The mouth a door belongs to, so a plate hides exactly its own hole.
  String? _mouthIdFor(DungeonRoom room, DungeonDoor door) {
    final leg = _flueLeg(room, door);
    if (leg == null) return null;
    final (flue, which) = leg;
    return switch (which) {
      'down' => '${flue.id}:shaft',
      'shelf' => '${flue.id}:chute',
      _ => null,
    };
  }

  bool _capMelted(String mouthId) => meltedCaps.contains(mouthId);

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
  /// EVERY HOLE IS ITS OWN HOLE. A plate of black ice hides exactly the mouth
  /// it froze over, and that is the only reason a mouth is ever not there.
  /// A ledge chute's snow HOLDS: ride it as often as you like (2026-09-20 —
  /// the one-ride chute was a commitment that gated nothing, since a ledge's
  /// only door scrambles back out anyway, and a niche you can set foot in
  /// once a run made the lens a one-shot).
  bool _iceDoorHidden(DungeonRoom room, DungeonDoor door) {
    if (!_isShaft) return false;
    // THE WAY INTO THE HOLLOW IS THROUGH THE ROOF, never a door on a wall:
    // the module takes this door itself when the party goes down the throat.
    if (room.rime?.roof != null &&
        layout.rooms[door.targetRoomId]?.guardian != null) {
      return true;
    }
    final mouth = _mouthIdFor(room, door);
    if (mouth == null) return false;
    return room.rime?.iceCap != null && !_capMelted(mouth);
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
      return 'Running water. You can\'t climb it';
    }
    return switch (_flue(flue.id)) {
      RimeFlueState.scoured => 'Bare ice. This shaft can\'t be frozen into steps now',
      _ => 'Loose snow. Freeze it into steps to climb',
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
        _cue(SoundCue.dungeonWallBreak);
        // A TRANSIT line, not a hint: set as a hint it was wiped by the door
        // it was reporting on, and this planet's one world-scale act has
        // been silent since it was built.
        _announceTransit(
          'The rimefall carries you out. The whole shaft resets: every '
          'stair is gone and the orrery is back as it started',
          7.0,
        );
      }
      return;
    }
    // THE LEDGE CHUTE SPENDS NOTHING. Its snow holds under a rider and the
    // pocket is a place you can go back to; only a SHAFT ride scours.
    if (which == 'shelf') return;
    // A ride spends the snow of THE MOUTH YOU RODE, and nothing else.
    if (_flue(flue.id) == RimeFlueState.drift) {
      flueState[flue.id] = RimeFlueState.scoured;
      _cue(SoundCue.dungeonHazardTrigger); // the snow going out from under you
      // THE MOMENT THE HOLE CHANGES IS THE MOMENT TO SAY SO. This is where a
      // player learns that a ridden chute is a different chute, and it is the
      // one beat where the lesson cannot be missed.
      _announceTransit(
        'You ride the snow down. This shaft is bare now and can\'t be frozen '
        'into steps',
        5.5,
      );
    }
  }

  /// Test seam: what the roof (and the orrery) refuse a body at [p].
  bool shaftBlocksAtForTest(Offset p) => _shaftBlocksAt(p, currentRoom);

  /// Test seam for the transit bookkeeping — the shaft's rules are proved
  /// against the same code the door loop calls, without having to walk a body
  /// onto a 24px door rect.
  void onShaftTransitForTest(DungeonRoom from, DungeonDoor door) =>
      _onShaftTransit(from, door);

  // ── Verbs ────────────────────────────────────────────────

  /// Every Ice verb, in priority order. Returns true when one was consumed.
  bool _tryShaftVerb(DungeonCreature a) {
    if (!_isShaft) return false;
    // A BODY STANDING ON THE ORRERY IS WORKING THE ORRERY. Flue C's mouth is
    // a verb target 66px wide in the same corner of the room as the last
    // row's socket: standing on the kerb to glaze or shove, Ice froze the
    // flue instead and every other element was told "only Ice sets this fall
    // into a stair" and lost its shove. The floor wins inside its own edge;
    // the mouth is worked from the margin, where it is the only thing there.
    final g = _orrery;
    if (g != null && _tryOrreryCrank(a)) return true;
    if (g != null && _orreryCellAt(g, a.position) != null && _tryOrrery(a)) {
      return true;
    }
    return _tryIceCap(a) ||
        _tryRimefall(a) ||
        _tryFreezeFlue(a) ||
        _tryHoarfrost(a) ||
        _tryRoofVerb(a) ||
        _tryColdFont(a) ||
        _tryMirrorFrame(a) ||
        _tryMirrorSweep(a) ||
        _tryTelescope(a) ||
        _tryOrrery(a);
  }

  /// The entry rite: Light drinks the black ice off ONE hole at a time.
  ///
  /// EVERY MOUTH IS PLATED SEPARATELY (2026-09-15, from play). One press used
  /// to open the whole floor — which is the opposite of what the first room
  /// has to teach, because the planet's first lesson is that these holes are
  /// not the same hole. You open the one you are standing at, and the others
  /// stay black until you go and open them too.
  bool _tryIceCap(DungeonCreature a) {
    if (currentRoom.rime?.iceCap == null) return false;
    String? mouth;
    for (final m in _iceMouths(currentRoomId)) {
      if (_capMelted(m.$1)) continue;
      if ((a.position - m.$2).distance <= _kShaftReach) {
        mouth = m.$1;
        break;
      }
    }
    if (mouth == null) return false;
    if (a.member.element != 'Light') {
      // WHAT is missing, in one clause (§5.6) — the WHY is the floor's own
      // one-time teach and Mask's to repeat.
      _setBlockedHint('Frost only thickens black ice. It needs Light');
      return true;
    }
    meltedCaps.add(mouth);
    _discoverCloud('$_kCapDiscoveryPrefix$mouth'); // per mouth, and persisted
    if (!entryDoorRevealed) {
      entryDoorRevealed = true;
      _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId);
    }
    _cue(SoundCue.dungeonGateOpen);
    final left = _iceMouths(
      currentRoomId,
    ).where((m) => !_capMelted(m.$1)).length;
    _setHint(
      left == 0
          ? 'Light drinks the last of the black ice, the floor is open'
          : 'Light drinks the plate, and this hole is open. $left more are not',
    );
    final at = _iceMouths(currentRoomId).firstWhere((m) => m.$1 == mouth).$2;
    _spawnAlchemyBurst(
      at,
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
        _setBlockedHint('The water runs too hard to freeze from above');
        return true;
      }
      if (a.member.element != 'Ice') {
        _setBlockedHint('Only Ice can freeze this into steps');
        return true;
      }
      switch (_flue(f.id)) {
        case RimeFlueState.stair:
          _setBlockedHint('Already frozen into steps');
        case RimeFlueState.scoured:
          _setBlockedHint('Bare ice. No snow left to freeze');
        case RimeFlueState.drift:
          flueState[f.id] = RimeFlueState.stair;
          _cue(SoundCue.elementIce);
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
      _setBlockedHint('Only Ice can freeze this fall');
      return true;
    }
    if (rimefallFrozen) {
      _setBlockedHint('The rimefall is already frozen');
      return true;
    }
    rimefallFrozen = true;
    _cue(SoundCue.elementIce);
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

  /// The rite's second half — element-only Ice, on the roof's pier. The
  /// first half is the breath down the throat (`_tryRoofBreath`).
  bool _tryColdFont(DungeonCreature a) {
    final pos = currentRoom.rime?.coldFont;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kShaftReach) return false;
    if ((conduitEnergy['B'] ?? 0) > 0) return false;
    if (a.member.element != 'Ice') {
      _setBlockedHint('Only Ice can sing the font');
      return true;
    }
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'The font needs the ${layout.starName(0)} and '
        '${layout.starName(1)} first',
      );
      return true;
    }
    conduitEnergy['B'] = double.infinity;
    _cue(SoundCue.dungeonSwitch);
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
      _setBlockedHint('The pillar needs a moment to regrow');
      return true;
    }
    if (a.member.element != 'Ice') {
      _setBlockedHint('Only Ice can raise this pillar');
      return true;
    }
    hoarfrostWhole = true;
    _cue(SoundCue.elementIce);
    _setHint('The hoarfrost stands again, and the wyrm slows to look at it');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Ice',
      reagentElements: [a.member.element],
      particleCount: 22,
    );
    return true;
  }

  // ── Star 1 · THE MIRROR GALLERY ──────────────────────────
  //
  // THE CHART ASSEMBLES IN THE WATER.
  //
  // The ceiling's chart is ONE closed figure running right around the ring,
  // and it is never seen directly. Silvering a frame throws that frame's
  // stretch of it into the pool; frost comes off as easily as it goes on, so
  // the water is a workbench you rearrange for nothing.
  //
  // Neighbouring frames OVERLAP, and that is the whole engine. Where two
  // silvered frames cover the same star they either put it in the same place
  // or they do not, and a disagreement FORKS in the water — two lines out of
  // one star. A fork says *one of the frames covering this star is hung
  // false*; it never says which. So no single look answers a frame: you chain
  // out from the LODESTONE, which is the one frame known true, by choosing
  // what to put in the water and what to take out.
  //
  // The star is the chart covered end to end with nothing forking.
  //
  // (Three earlier cuts of this room: a lap against a melt clock — walking
  // speed as a puzzle, and Blood's ledger seat; then "silver the figure that
  // has no twin", which played as *"I just tap every one with Ice"*; then
  // per-frame claim-versus-sky, which was eleven independent comparisons —
  // a checklist, not a puzzle. Evidence about a PAIR rather than an item is
  // what finally made the parts talk to each other.)

  MirrorRing? get _mirrorRing => currentRoom.rime?.mirrors;

  /// Which stars frame [i] covers: its own two, and one either side of them.
  /// Five apiece, so a frame left out of the water is still covered by its
  /// neighbours — which is what makes "leave the false ones out" a workable
  /// answer rather than a hole in the chart.
  List<int> chartStarsOf(int i) => [
    for (var k = -2; k <= 2; k++) (2 * i + k + kIceChartStars) % kIceChartStars,
  ];

  /// This run's chart, and which frames are hung false.
  void _rollMirrorChart(MirrorRing ring) {
    final rng = Random();
    mirrorChart
      ..clear()
      ..addAll([
        for (var k = 0; k < kIceChartStars; k++) 0.42 + rng.nextDouble() * 0.46,
      ]);
    frameOffset.clear();
    for (var i = 0; i < ring.count; i++) {
      frameOffset[i] = 0;
    }
    // THE FALSE FRAMES. Never the lodestone (it is the anchor the whole room
    // is chained from) and NEVER TWO SIDE BY SIDE — two adjacent frames left
    // out would leave a stretch of chart nothing covers, and the puzzle would
    // have no answer at all.
    final want = 3 + rng.nextInt(3);
    final placed = <int>{};
    var guard = 0;
    while (placed.length < want && guard++ < 200) {
      final i = 1 + rng.nextInt(ring.count - 1);
      if (i == ring.lodestoneIndex) continue;
      if (placed.contains((i - 1) % ring.count)) continue;
      if (placed.contains((i + 1) % ring.count)) continue;
      placed.add(i);
      // How far off it is hung. Always enough to see, never so far that the
      // fork leaves the water.
      frameOffset[i] = 1 + rng.nextInt(3);
    }
    silveredFrames
      ..clear()
      ..add(ring.lodestoneIndex);
  }

  /// Frames hung false — the set the star is won by leaving OUT.
  Set<int> get mirrorFalseFrames => {
    for (final e in frameOffset.entries)
      if (e.value != 0) e.key,
  };

  /// Where frame [i] puts star [k], as a fraction of the pool's radius. A
  /// frame hung true puts it where it belongs; a false one puts it out.
  double chartRadiusFor(int i, int k) {
    if (mirrorChart.isEmpty) return 0.5;
    final base = mirrorChart[k % kIceChartStars];
    final off = frameOffset[i] ?? 0;
    return off == 0 ? base : (base + 0.16 * off).clamp(0.30, 1.0);
  }

  /// The frames in the water that cover star [k].
  List<int> _coversOf(int k) => [
    for (final i in silveredFrames)
      if (chartStarsOf(i).contains(k)) i,
  ];

  /// Is star [k] held in one place by everything that can see it?
  bool chartStarAgreed(int k) {
    final covers = _coversOf(k);
    if (covers.isEmpty) return false;
    final first = chartRadiusFor(covers.first, k);
    return covers.every((i) => (chartRadiusFor(i, k) - first).abs() < 0.001);
  }

  /// How much of the chart is whole — the readout, and the win condition.
  int get chartStarsWhole {
    var n = 0;
    for (var k = 0; k < kIceChartStars; k++) {
      if (chartStarAgreed(k)) n++;
    }
    return n;
  }

  void _updateMirrors(DungeonRoom room, double dt) {
    if (mirrorSweep > 0) mirrorSweep = max(0.0, mirrorSweep - dt);
    if (poolStill > 0) poolStill = max(0.0, poolStill - dt);
    if (chartTriumph > 0) chartTriumph = max(0.0, chartTriumph - dt);
    final ring = room.rime?.mirrors;
    final idx = room.rime?.starIndex;
    if (ring == null || idx == null) return;
    if (hasStar(idx)) {
      // THE TROPHY STANDS ON RE-ENTRY. The banked chart used to stay lit only
      // for the run it was won in: a later descent found the pool dead black
      // and every frame dark, as if the room had never been solved. The
      // water holds the whole chart now, true end to end, every frame in it.
      if (mirrorChart.isEmpty) _restoreSolvedChart(ring);
    } else if (mirrorChart.isEmpty) {
      _rollMirrorChart(ring);
    }
    _watchForStranger(ring);
  }

  /// The chart as a finished thing: every frame hung true and in the water,
  /// the lodestone lit. What a solved gallery looks like when you walk back
  /// into it.
  void _restoreSolvedChart(MirrorRing ring) {
    final rng = Random();
    mirrorChart
      ..clear()
      ..addAll([
        for (var k = 0; k < kIceChartStars; k++) 0.42 + rng.nextDouble() * 0.46,
      ]);
    frameOffset.clear();
    silveredFrames.clear();
    for (var i = 0; i < ring.count; i++) {
      frameOffset[i] = 0;
      silveredFrames.add(i);
    }
    lodestoneLit = true;
  }

  /// THE LIGHT HAND IS A LAMP, AND THE LAMP IS WHERE YOU LEFT IT.
  ///
  /// The pool is black glass. What reads it is the LIGHT creature — wherever
  /// it is standing, active or not — and what it reads is the stretch ACROSS
  /// the ring from it, because that is what a reflection does. Park it
  /// somewhere and it keeps showing you that stretch while you take Ice round
  /// the frames; to look elsewhere, go back and walk the lamp.
  ///
  /// Returns how brightly star [k] is read, 0..1, easing off at the edge of
  /// the lamp's reach so the water does not snap open and shut as it walks.
  /// An Air sweep's flash lays over the top of it, whole, and fades away.
  double chartStarLight(MirrorRing ring, int k) =>
      max(sweepLight, _lampStarLight(ring, k));

  /// How much of the whole chart an Air sweep is showing right now, 0..1:
  /// held for the flash, then fading back to nothing.
  double get sweepLight {
    if (poolStill <= 0) return 0;
    if (poolStill >= _kPoolFlashFadeSeconds) return 1;
    return poolStill / _kPoolFlashFadeSeconds;
  }

  double _lampStarLight(MirrorRing ring, int k) {
    // SOLVED, AND IT STAYS LIT. The chart you put together is the trophy, and
    // a trophy you have to keep walking a lamp round is not one.
    final idx = currentRoom.rime?.starIndex;
    if (chartTriumph > 0 || (idx != null && hasStar(idx))) return 1.0;
    DungeonCreature? lamp;
    for (final c in creatures) {
      if (c.alive && c.member.element == 'Light') {
        lamp = c;
        break;
      }
    }
    if (lamp == null) return 0;
    final d = lamp.position - ring.center;
    // OVER THE WATER ITSELF, NOTHING. A lamp standing on the pool has no far
    // side to be reflected from, and the room may not hand you the whole
    // chart for standing in the middle of it.
    if (d.distance < ring.radius * 0.5) return 0;
    final look = atan2(-d.dy, -d.dx);
    final ang = -pi / 2 + (2 * pi * k) / kIceChartStars;
    var diff = (ang - look).abs() % (2 * pi);
    if (diff > pi) diff = 2 * pi - diff;
    const inner = pi * 42 / 180;
    const outer = pi * 62 / 180;
    if (diff <= inner) return 1;
    if (diff >= outer) return 0;
    return 1 - (diff - inner) / (outer - inner);
  }

  /// Whether the water shows star [k] at all — the rule the room is reasoned
  /// about with; the render uses the brightness above.
  bool chartStarVisible(MirrorRing ring, int k) => chartStarLight(ring, k) > 0;

  bool _tryMirrorFrame(DungeonCreature a) {
    final ring = _mirrorRing;
    if (ring == null || hasStar(currentRoom.rime!.starIndex!)) return false;
    for (var i = 0; i < ring.count; i++) {
      if ((a.position - ring.frameAt(i)).distance > _kMirrorReach) continue;
      if (i == ring.lodestoneIndex) return _strikeLodestone(a, ring, i);
      if (a.member.element != 'Ice') {
        _setBlockedHint('Only Ice can silver a frame');
        return true;
      }
      if (!lodestoneLit) {
        _setBlockedHint('The pool is dark. Wake it first');
        return true;
      }
      // NOTHING IS SPENT. The water is a workbench: put a stretch of chart in
      // it, take it out again, cost nothing either way.
      _cue(SoundCue.dungeonSwitch);
      if (!silveredFrames.add(i)) {
        silveredFrames.remove(i);
      } else {
        _spawnAlchemyBurst(
          ring.frameAt(i),
          producedElement: 'Ice',
          reagentElements: [a.member.element],
          particleCount: 12,
        );
      }
      _checkMirrorStar(ring);
      return true;
    }
    return false;
  }

  /// The chart, covered end to end, with nothing forking.
  void _checkMirrorStar(MirrorRing ring) {
    final idx = currentRoom.rime?.starIndex;
    if (idx == null || hasStar(idx)) return;
    if (chartStarsWhole < kIceChartStars) return;
    // THE LIGHT-UP. Twelve frames, a lamp walked round and round, and the
    // answer is a picture — so the room shows you the picture, whole, once.
    chartTriumph = _kChartTriumphSeconds;
    _setHint('The chart closes, and every star stands in one place');
    earnStar(idx);
  }

  /// The lodestone: black glass no frost will take, and the planet's marquee
  /// gate. Struck, it lights the water and puts the one stretch of chart you
  /// can trust into it — the anchor everything else is chained from.
  bool _strikeLodestone(DungeonCreature a, MirrorRing ring, int i) {
    if (lodestoneLit) {
      _setAmbientHint('Black glass, holding a light of its own');
      return true;
    }
    const req = DungeonInteractionRequirement(
      element: 'Light',
      requiredFamily: DungeonAbility.insight,
    );
    switch (evaluateInteraction(a.member, req)) {
      case InteractionResult.passed:
      case InteractionResult.passedViaRecipe:
        lodestoneLit = true;
        if (mirrorChart.isEmpty) _rollMirrorChart(ring);
        silveredFrames.add(i);
        _cue(SoundCue.dungeonGateOpen);
        _inHintChannel(
          DungeonHintChannel.insight,
          () => _forceHint(
            'The pool wakes. It shows the part of the chart across from '
            'where you stand.',
            5.0,
          ),
        );
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
          _setBlockedHint('Only a Light Mask can strike this glass');
        }
      case InteractionResult.blockedElement:
      case InteractionResult.blockedStat:
        _setBlockedHint('Frost does nothing here. It needs Light');
    }
    return true;
  }

  /// Air's sweep off the cold vent: the rime lifts and the whole chart shows
  /// at once, for a breath, then the water closes back to what the lamp
  /// reads. A glimpse of where to walk the lamp, never a substitute for it.
  bool _tryMirrorSweep(DungeonCreature a) {
    final ring = _mirrorRing;
    if (ring == null || hasStar(currentRoom.rime!.starIndex!)) return false;
    if ((a.position - ring.vent).distance > _kShaftReach) return false;
    if (a.member.element != 'Air') {
      _setBlockedHint('Only Air can use this vent');
      return true;
    }
    if (mirrorSweep > 0) {
      _setBlockedHint('The vent needs a moment');
      return true;
    }
    mirrorSweep = _kMirrorSweepCooldown;
    poolStill = _kPoolFlashHoldSeconds + _kPoolFlashFadeSeconds;
    _cue(SoundCue.elementAir);
    _setHint('The rime lifts for a breath, and the whole sky shows at once');
    _spawnAlchemyBurst(
      ring.vent,
      producedElement: 'Air',
      reagentElements: const ['Ice'],
      particleCount: 26,
      intensity: 1.15,
    );
    return true;
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

  /// A socket, and the one direction of travel its kerb opens to.
  bool _orrerySocket(OrreryGrid g, int c, int r) =>
      _orrerySocketDir(g, c, r) != null;

  (int, int)? _orrerySocketDir(OrreryGrid g, int c, int r) =>
      switch (g.art[r][c]) {
        '>' => (1, 0),
        '<' => (-1, 0),
        '^' => (0, -1),
        'v' => (0, 1),
        'S' => (0, 0), // a legacy any-way kerb; no planet authors one now
        _ => null,
      };

  /// Will this kerb take block [id] arriving travelling [dir]? It wants its
  /// OWN block, running WITH its orbit. Anything else stops at the lip.
  bool _orreryKerbOpens(OrreryGrid g, int c, int r, (int, int) dir, {int? id}) {
    final want = _orrerySocketDir(g, c, r);
    if (want == null) return false;
    final owner = g.kerbOwner[r * g.cols + c];
    if (owner != null && id != null && owner != id) return false;
    if (want.$1 == 0 && want.$2 == 0) return true;
    return want == dir;
  }

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

  /// The cell a creature is ACTING FROM, which is not the same question as
  /// which cell it is standing on: the floor has a margin all the way round
  /// and a body may stand in it.
  ///
  /// THE HALO IS LOAD-BEARING, NOT A CONVENIENCE. While a pusher had to stand
  /// ON the grid, a block in column 0 could only ever be shoved along column
  /// 0 — there is no cell west of it to push from — and neither edge column
  /// carries a socket. One shove was enough to put a star-block somewhere it
  /// could never leave, with no reset but a party wipe: 1,718 of the 2,330
  /// reachable boards could never be solved. Standing one cell off the floor
  /// (which the room's margin has always allowed) takes that to 0 of 7,140 —
  /// see `solveOrreryBoards`, which pins exactly that.
  (int, int)? _orreryStandCell(OrreryGrid g, Offset p) {
    final c = ((p.dx - g.origin.dx) / g.cell).floor();
    final r = ((p.dy - g.origin.dy) / g.cell).floor();
    if (c < -1 || r < -1 || c > g.cols || r > g.rows) return null;
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

  /// Where the floor's CRANK stands: off the board entirely, in the margin at
  /// the east wall. It was first put in the MIDDLE of the grid, which laid
  /// its 66px reach over four playable cells — so Ice glazing near the centre
  /// was told "the crank answers Light", and Light melting there reset the
  /// whole floor instead of trimming one cell off a road. A lever that
  /// overlaps the board is a lever you pull by accident.
  Offset _orreryCrankAt(OrreryGrid g) => Offset(
    g.origin.dx + g.cols * g.cell + 50,
    g.origin.dy + g.rows * g.cell / 2,
  );

  /// THE CRANK — and the reason star-blocks can be SOLID at all.
  ///
  /// Blocks used to be walk-through. Made solid (a thing you push should not
  /// be a floor decal), three of them can be shoved into a corner where each
  /// one blocks the only square the next would be pushed from: 151 of the
  /// 7,140 reachable boards are jammed like that, and a jam that costs the
  /// run is the exact thing this game does not do. Light at the armature
  /// sends every unseated block back to its standard and takes the glass up.
  /// Free, instant, local — a re-plan, never a re-descent. Seated blocks stay
  /// seated: it undoes your working, not your progress.
  bool _tryOrreryCrank(DungeonCreature a) {
    final g = _orrery;
    final room = currentRoom;
    if (g == null || room.rime?.starIndex == null) return false;
    if (hasStar(room.rime!.starIndex!)) return false;
    // A BODY ON THE FLOOR IS WORKING THE FLOOR: the crank only answers from
    // the margin, where nothing else does.
    if (_orreryCellAt(g, a.position) != null) return false;
    final hub = _orreryCrankAt(g);
    if ((a.position - hub).distance > _kShaftReach) return false;
    if (a.member.element != 'Light') {
      _setBlockedHint('Only Light can turn the crank');
      return true;
    }
    final seatedCells = {for (final id in orrerySeated) orreryBlocks[id]!};
    orreryGlass.clear();
    var id = 0;
    final home = <int, int>{};
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (g.art[r][c] == 'B') home[id++] = r * g.cols + c;
      }
    }
    for (final e in home.entries) {
      if (orrerySeated.contains(e.key)) continue;
      if (seatedCells.contains(e.value)) continue;
      orreryBlocks[e.key] = e.value;
    }
    orrerySlideId = null;
    _cue(SoundCue.dungeonSwitch);
    _setHint('The crank turns, and the loose sky goes back to its standards');
    _spawnAlchemyBurst(
      hub,
      producedElement: 'Light',
      reagentElements: const ['Ice'],
      particleCount: 24,
    );
    return true;
  }

  bool _tryOrrery(DungeonCreature a) {
    final g = _orrery;
    final idx = currentRoom.rime?.starIndex;
    if (g == null || idx == null || hasStar(idx)) return false;
    final here = _orreryStandCell(g, a.position);
    if (here == null) return false;
    final step = _orreryFacing(a);
    var c = here.$1 + step.$1;
    var r = here.$2 + step.$2;
    // Facing off the edge of the floor: fall back to the cell underfoot, so a
    // creature pinned against the wall is never verbless. A body standing in
    // the margin has no cell underfoot to fall back to, so it simply has no
    // orrery verb from there — it can still reach ONTO the floor, which is
    // the whole point of the halo.
    if (c < 0 || r < 0 || c >= g.cols || r >= g.rows) {
      c = here.$1;
      r = here.$2;
      if (c < 0 || r < 0 || c >= g.cols || r >= g.rows) return false;
    }
    final block = _orreryBlockAt(g, c, r);
    if (block != null && !orrerySeated.contains(block)) {
      return _shoveBlock(g, block, step);
    }
    if (_orreryPillar(g, c, r) || _orrerySocket(g, c, r)) {
      _setBlockedHint(
        _orreryPillar(g, c, r)
            ? 'Iron pillar. Nothing to do here'
            : 'A socket kerb. It can\'t be glazed',
      );
      return true;
    }
    if (a.member.element == 'Ice') {
      // THE COLD RUNS OUT ACROSS THE FLOOR. One cell per press turned the
      // long routes into a pressing grind, so a glaze throws a road up to
      // `_kGlazeReach` cells in the direction you face, stopping at anything
      // solid. Light still melts ONE cell, which is how a road is trimmed to
      // stop a block exactly where you want it.
      var laid = 0;
      var cc = c, rr = r;
      for (var n = 0; n < _kGlazeReach; n++) {
        if (cc < 0 || rr < 0 || cc >= g.cols || rr >= g.rows) break;
        if (_orreryPillar(g, cc, rr) || _orrerySocket(g, cc, rr)) break;
        if (_orreryBlockAt(g, cc, rr) != null) break;
        if (orreryGlass.add(rr * g.cols + cc)) laid++;
        cc += step.$1;
        rr += step.$2;
      }
      if (laid == 0) {
        _setBlockedHint('Already glass');
        return true;
      }
      _cue(SoundCue.elementIce);
      _spawnAlchemyBurst(
        g.centerAt(c, r),
        producedElement: 'Ice',
        reagentElements: [a.member.element],
        particleCount: 10,
      );
      return true;
    }
    final key = r * g.cols + c;
    if (a.member.element == 'Light') {
      if (!orreryGlass.contains(key)) {
        _setBlockedHint('Bare stone. Nothing to melt');
        return true;
      }
      // THE WHOLE SHEET GOES. Melting ONE cell let you lay any road at all
      // and then trim it to the exact length you wanted, which meant the
      // question "where does this road END" — the only real question on this
      // floor — never had to be answered before you laid it. Light takes the
      // whole connected sheet now: a road is planned, not whittled.
      final gone = <int>{};
      final queue = [key];
      while (queue.isNotEmpty) {
        final k = queue.removeLast();
        if (!orreryGlass.contains(k) || !gone.add(k)) continue;
        final kc = k % g.cols, kr = k ~/ g.cols;
        for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final nc = kc + d.$1, nr = kr + d.$2;
          if (nc < 0 || nr < 0 || nc >= g.cols || nr >= g.rows) continue;
          queue.add(nr * g.cols + nc);
        }
      }
      orreryGlass.removeAll(gone);
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
  /// Half the width of a star-block's body, for walking into it. The drawn
  /// lump is ~52px across in a 92px cell, so the solid part is the lump and
  /// not the cell: you can still squeeze past a block along the cell's edge.
  static const double _kBlockHalf = 24;

  /// STAR-BLOCKS ARE SOLID (2026-09-15, from play). They were walk-through,
  /// kept that way because an authored solution stood on a block's own cell
  /// to glaze past it — which no player would ever think to do, and which
  /// made the one thing you push feel like a floor decal. Nothing in the
  /// solution needs it (every glaze and every shove is made from an open
  /// neighbour), and `solveOrreryBoards` is re-proved with bodies that cannot
  /// stand in a block.
  bool _shaftBlocksAt(Offset center, DungeonRoom room) {
    final refusal = _roofRefusal(center, room);
    if (refusal != null) {
      if (refusal.isNotEmpty) _roofBlockReason = refusal;
      return true;
    }
    final g = room.rime?.orrery;
    if (g == null) return false;
    final reach = _kBlockHalf + PlanetDungeonGame._radius;
    for (final cell in orreryBlocks.values) {
      final p = g.centerAt(cell % g.cols, cell ~/ g.cols);
      if ((center.dx - p.dx).abs() < reach &&
          (center.dy - p.dy).abs() < reach) {
        return true;
      }
    }
    return false;
  }

  /// A block that slides onto a body puts the body out of its way, into the
  /// cell it just left — the one place on the board guaranteed to be clear.
  void _clearBodiesOffBlock(OrreryGrid g, int fromCell, int toCell) {
    final to = g.centerAt(toCell % g.cols, toCell ~/ g.cols);
    final from = g.centerAt(fromCell % g.cols, fromCell ~/ g.cols);
    final reach = _kBlockHalf + PlanetDungeonGame._radius;
    for (final c in creatures) {
      if ((c.position.dx - to.dx).abs() < reach &&
          (c.position.dy - to.dy).abs() < reach) {
        c
          ..position = from
          ..lastSafe = from;
      }
    }
  }

  /// Where block [id] would END UP if it were shoved [dir], given the glass
  /// that is down right now. ONE walk, used by the shove and by the preview
  /// the floor draws under your feet — they cannot disagree about the run,
  /// because they are the same run.
  ({List<int> travelled, int cell, bool seats, bool moved}) _orreryRun(
    OrreryGrid g,
    int id,
    (int, int) dir,
  ) {
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
      // A KERB OPENS ONE WAY. Running with the orbit, the block drops in and
      // seats, glazed or not; running against it, the lip stops it dead in
      // the cell before — which is what makes the APPROACH the puzzle.
      if (_orrerySocket(g, nc, nr)) {
        if (!_orreryKerbOpens(g, nc, nr, dir, id: id)) break;
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
    return (
      travelled: travelled,
      cell: r * g.cols + c,
      seats: seated,
      moved: moved,
    );
  }

  bool _shoveBlock(OrreryGrid g, int id, (int, int) dir) {
    final startCell = orreryBlocks[id]!;
    final run = _orreryRun(g, id, dir);
    final travelled = run.travelled;
    final moved = run.moved;
    final seated = run.seats;
    final c = run.cell % g.cols;
    final r = run.cell ~/ g.cols;
    if (!moved) {
      _setBlockedHint('Too heavy to push on stone. It needs ice under it');
      return true;
    }
    orreryBlocks[id] = r * g.cols + c;
    // IT SLIDES. The board moves at once (nothing can desync off a render),
    // and the drawing runs the block along its road.
    orrerySlideId = id;
    orrerySlideFrom = startCell;
    orrerySlideTo = orreryBlocks[id]!;
    orrerySlideT = 0;
    _clearBodiesOffBlock(g, startCell, orreryBlocks[id]!);
    _cue(SoundCue.dungeonBlockMove);
    if (seated) {
      orrerySeated.add(id);
      _setHint('The block takes the kerb and settles into its socket');
      _spawnAlchemyBurst(
        g.centerAt(c, r),
        producedElement: 'Light',
        reagentElements: const ['Ice'],
        particleCount: 20,
      );
      _cue(SoundCue.dungeonSwitch);
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

  // ── THE ROOF OF THE HOLLOW · the rite (2026-09-20) ──────
  //
  // The rite used to be two presses on two plinths. It is a ROOM now, and
  // the room is the ice over the wyrm's lair:
  //
  //   · SNOW bears all and shows nothing. LIGHT bares the pane ahead of it,
  //     and bare ice shows what it lies on: stone is white and thick; the
  //     hollow is black and THIN — it bears one body — and the black drifts
  //     away from the wyrm's head, so every bared pane is a bearing.
  //   · Under the wyrm's body the scales run one way: toward the head. Over
  //     the head, an eye, and hoarfrost blooming on the glass above it.
  //   · LIGHT melts bare ice over the hollow into water; over the head that
  //     is THE THROAT. ICE freezes water ahead of it back to thin glass.
  //   · The AIR WING turns the last breath down the open throat (the hard
  //     gate); ICE sings the font on its pier; both, and the wyrm wakes.
  //   · Awake, the throat is the way in — for the three of you together.
  //
  // Nothing here is timed, nothing cracks under you, nothing is spent: a
  // pane bared stays bared, water can always be frozen back, and Ice can
  // reach anything (it makes its own footing), so no body is ever stranded.
  // The cost of looking is footing — every bared pane over the hollow is a
  // pane only one of you can stand on — and the reward for reading the drift
  // instead of baring everything is a roof you can still walk.

  IceRoof? get _roof => currentRoom.rime?.roof;

  DungeonRoom? get _roofRoom {
    for (final r in layout.rooms.values) {
      if (r.rime?.roof != null) return r;
    }
    return null;
  }

  /// Roll the wyrm under a fresh roof: every authored 'W' is water, nothing is
  /// bared, and the body is a connected line of [kIceWyrmLength] hollow
  /// panes, head first, never touching water or the pier.
  void _seedRoof([Random? rnd]) {
    roofWyrm.clear();
    roofBare.clear();
    roofWater.clear();
    roofThroat = null;
    final roof = _roofRoom?.rime?.roof;
    if (roof == null) return;
    final free = <int>[];
    for (var c = 0; c < roof.count; c++) {
      if (roof.waterAt(c)) {
        roofWater.add(c);
      } else if (roof.bedAt(c) == IceRoofBed.hollow) {
        free.add(c);
      }
    }
    final r = rnd ?? Random();
    for (var attempt = 0; attempt < 400; attempt++) {
      final path = <int>[free[r.nextInt(free.length)]];
      while (path.length < kIceWyrmLength) {
        final opts = roof
            .neighbours(path.last)
            .where((n) => free.contains(n) && !path.contains(n))
            .toList();
        if (opts.isEmpty) break;
        path.add(opts[r.nextInt(opts.length)]);
      }
      if (path.length == kIceWyrmLength) {
        roofWyrm.addAll(path);
        return;
      }
    }
    roofWyrm.addAll(free.take(kIceWyrmLength)); // cannot happen on this art
  }

  /// Test seam: lay the wyrm exactly here (head first).
  void seedRoofForTest(List<int> cells) {
    roofWyrm
      ..clear()
      ..addAll(cells);
  }

  /// What pane [c] lies on, wyrm included.
  IceRoofUnder roofUnder(IceRoof roof, int c) {
    if (roofWyrm.isNotEmpty && roofWyrm.first == c) return IceRoofUnder.head;
    if (roofWyrm.contains(c)) return IceRoofUnder.body;
    return switch (roof.bedAt(c)) {
      IceRoofBed.rock => IceRoofUnder.rock,
      IceRoofBed.pier => IceRoofUnder.pier,
      IceRoofBed.hollow => IceRoofUnder.hollow,
    };
  }

  bool roofIsWater(int c) => roofWater.contains(c);
  bool roofIsThroat(int c) => roofThroat == c;
  bool roofIsBare(int c) => roofBare.contains(c);

  /// THIN: bare glass over the hollow (or the wyrm). It bears one body.
  bool roofIsThin(IceRoof roof, int c) =>
      roofIsBare(c) &&
      !roofIsWater(c) &&
      !roofIsThroat(c) &&
      roof.bedAt(c) == IceRoofBed.hollow;

  /// Which way the hollow's water drifts under pane [c] — AWAY from the head,
  /// which is the whole tell. Zero when there is nothing to drift from.
  Offset roofDrift(IceRoof roof, int c) {
    if (roofWyrm.isEmpty) return Offset.zero;
    final d = roof.centerAt(c) - roof.centerAt(roofWyrm.first);
    return d.distance == 0 ? Offset.zero : d / d.distance;
  }

  /// Under a body pane, which way the scales run: toward the head.
  Offset roofScaleRun(IceRoof roof, int c) {
    final i = roofWyrm.indexOf(c);
    if (i <= 0) return Offset.zero;
    final d = roof.centerAt(roofWyrm[i - 1]) - roof.centerAt(c);
    return d.distance == 0 ? Offset.zero : d / d.distance;
  }

  int _roofBodiesOn(IceRoof roof, int c, {DungeonCreature? except}) {
    var n = 0;
    for (final b in creatures) {
      if (b.alive && b != except && roof.cellAt(b.position) == c) n++;
    }
    return n;
  }

  /// The four-way direction [a] is facing, as a unit step.
  Offset _roofFacing(DungeonCreature a) {
    final dx = cos(a.aimAngle), dy = sin(a.aimAngle);
    return dx.abs() >= dy.abs()
        ? Offset(dx.sign == 0 ? 1 : dx.sign, 0)
        : Offset(0, dy.sign);
  }

  /// THE PANE AHEAD — what Light and Ice work on: the neighbour of the pane
  /// you stand on in the direction you face (or, from a shore, the first
  /// pane of the roof in front of you). Never the pane under your own feet.
  int? roofTargetCell(DungeonCreature a) {
    final roof = _roof;
    if (roof == null) return null;
    final dir = _roofFacing(a);
    final under = roof.cellAt(a.position);
    final probe = roof.cellAt(a.position + dir * 56);
    if (probe != null && probe != under) return probe;
    if (under == null) return null;
    final x = under % roof.cols + dir.dx.round();
    final y = under ~/ roof.cols + dir.dy.round();
    if (x < 0 || y < 0 || x >= roof.cols || y >= roof.rows) return null;
    return y * roof.cols + x;
  }

  /// Why the roof refuses a body at [p] — a line to say, '' to refuse in
  /// silence (open water needs no announcing), or null when it bears you.
  String? _roofRefusal(Offset p, DungeonRoom room) {
    final roof = room.rime?.roof;
    if (roof == null) return null;
    final c = roof.cellAt(p);
    if (c == null) return null;
    final a = active;
    if (a != null && roof.cellAt(a.position) == c) return null; // standing
    if (roofIsThroat(c)) {
      if (!guardianAwake && !hasStar(2)) return layout.guardianSealedHint;
      if (a != null) {
        for (final b in creatures) {
          if (!b.alive || b == a) continue;
          if ((b.position - roof.centerAt(c)).distance > _kRoofEdge) {
            return 'Go down together. Gather the party at the edge first';
          }
        }
      }
      return null; // step in — the drop (see `_updateRoof`)
    }
    if (roofIsWater(c)) return '';
    if (roofIsThin(roof, c) &&
        a != null &&
        _roofBodiesOn(roof, c, except: a) > 0) {
      return 'This ice only holds one creature';
    }
    return null;
  }

  void _updateRoof(DungeonCreature a, DungeonRoom room, double dt) {
    final roof = room.rime?.roof;
    if (roof == null) return;
    // One refusal at a time, and not sixty times a second.
    if (_roofBlockCooldown > 0) _roofBlockCooldown -= dt;
    final reason = _roofBlockReason;
    _roofBlockReason = null;
    if (reason != null && _roofBlockCooldown <= 0) {
      _setBlockedHint(reason);
      _roofBlockCooldown = 2.6;
    }
    // BOTH HALVES SUNG, AND THE WYRM WAKES UNDER YOU.
    if (!altarOpen &&
        (conduitEnergy['A'] ?? 0) > 0 &&
        (conduitEnergy['B'] ?? 0) > 0) {
      _wakeFrowyrm(roof);
    }
    // THE DROP: a body on the open throat, with the others at its edge (the
    // refusal above is what keeps a lone body off it).
    final t = roofThroat;
    if (t != null &&
        (guardianAwake || hasStar(2)) &&
        _doorCooldown <= 0 &&
        roof.cellAt(a.position) == t) {
      _roofDrop(room);
    }
  }

  /// The altar's own wake, done here because the rite's two halves are the
  /// module's objects (the throat and the font), not authored Conduits.
  void _wakeFrowyrm(IceRoof roof) {
    altarOpen = true;
    guardianAwake = true;
    guardianHp = PlanetDungeonGame.maxGuardianHp;
    _shake = PlanetDungeonGame._kArrivalShake;
    _cue(SoundCue.dungeonGateOpen);
    speakConsequence(
      'The wyrm stirs under the ice',
    );
    final t = roofThroat;
    _spawnAlchemyBurst(
      t == null ? roof.bounds.center : roof.centerAt(t),
      producedElement: 'Ice',
      reagentElements: const ['Air'],
      particleCount: 40,
      intensity: 1.4,
    );
    onChanged();
  }

  /// Down the throat, all three together. The hidden door does the transit
  /// (anchor, regroup point, arrival, the wyrm's own descent), so a fall
  /// through the roof is bookkept exactly like every other way into a room.
  void _roofDrop(DungeonRoom room) {
    DungeonDoor? down;
    for (final d in room.doors) {
      if (layout.rooms[d.targetRoomId]?.guardian != null) down = d;
    }
    if (down == null) return;
    _cue(SoundCue.dungeonWallBreak);
    _announceTransit(
      'The ice gives way and the party drops into the hollow',
      6.0,
    );
    passThroughDoor(down);
  }

  /// Every roof verb, in priority order. Near the font it yields to the font
  /// whenever it has nothing of its own to do, so Ice on the pier can both
  /// freeze the water round it and sing.
  bool _tryRoofVerb(DungeonCreature a) {
    final roof = _roof;
    if (roof == null) return false;
    // A BODY STANDING ON THE PIER IS WORKING THE FONT (the orrery's lesson):
    // the water round it is frozen from the roof, not from the plinth.
    if (roof.cellAt(a.position) == roof.pierCell) return false;
    final font = currentRoom.rime?.coldFont;
    final nearFont =
        font != null && (a.position - font).distance <= _kShaftReach;
    final t = roofThroat;
    final atThroat =
        t != null && (a.position - roof.centerAt(t)).distance <= _kRoofEdge;
    switch (a.member.element) {
      case 'Air':
        if (atThroat) return _tryRoofBreath(a, roof, t);
        if (nearFont) return false;
        _setBlockedHint('Open the ice over the wyrm\'s head first');
        return true;
      case 'Light':
        return _tryRoofLight(a, roof, roofTargetCell(a), nearFont: nearFont);
      case 'Ice':
        return _tryRoofIce(a, roof, roofTargetCell(a), nearFont: nearFont);
    }
    return false;
  }

  /// THE BREATH — the planet's second hard gate, Air+WING, at the open
  /// throat. A wrong family stamps the chip (§4: the seal remembers).
  bool _tryRoofBreath(DungeonCreature a, IceRoof roof, int throat) {
    if ((conduitEnergy['A'] ?? 0) > 0) return false;
    final p = roof.centerAt(throat);
    if (a.ability != DungeonAbility.aerialTraversal) {
      final gate = layout.familyGateFor('A');
      if (gate != null) {
        _stampFamilyGate(gate);
      } else {
        _setBlockedHint('Only an Air Wing can turn this breath down');
      }
      _spawnAlchemyBurst(
        p,
        producedElement: 'Air',
        reagentElements: [a.member.element],
        unstable: true,
      );
      return true;
    }
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'This needs the ${layout.starName(0)} and '
        '${layout.starName(1)} first',
      );
      return true;
    }
    conduitEnergy['A'] = double.infinity;
    _cue(SoundCue.elementAir);
    _setHint('The last breath goes down the wyrm\'s throat, and holds');
    _spawnAlchemyBurst(
      p,
      producedElement: 'Air',
      reagentElements: const ['Ice'],
      particleCount: 30,
      intensity: 1.2,
    );
    return true;
  }

  /// LIGHT bares the pane ahead; bared, it melts it.
  bool _tryRoofLight(
    DungeonCreature a,
    IceRoof roof,
    int? target, {
    required bool nearFont,
  }) {
    if (target == null) {
      if (nearFont) return false;
      _setBlockedHint('Nothing ahead but stone');
      return true;
    }
    final p = roof.centerAt(target);
    if (roofIsWater(target) || roofIsThroat(target)) {
      if (nearFont) return false;
      _setBlockedHint('Already open water');
      return true;
    }
    final under = roofUnder(roof, target);
    if (!roofIsBare(target)) {
      // BARE IT, and the ice says what it lies on.
      roofBare.add(target);
      _cue(SoundCue.elementLight);
      _spawnAlchemyBurst(
        p,
        producedElement: 'Light',
        particleCount: 14,
        intensity: 0.7,
      );
      // A READING: the line IS the payload, so it is remembered for the hint
      // button (§5.6) — the picture under the glass says the same thing.
      final read = switch (under) {
        IceRoofUnder.rock ||
        IceRoofUnder.pier => 'Stone under this ice',
        IceRoofUnder.hollow =>
          'Dark water under this ice, drifting away from something',
        IceRoofUnder.body => 'The wyrm\'s body is under this ice',
        IceRoofUnder.head =>
          'The wyrm\'s head is under this ice',
      };
      if (under != IceRoofUnder.rock &&
          under != IceRoofUnder.pier &&
          !discoveredClouds.contains(kIceRoofTeachId)) {
        // THE RULE, ONCE, the first time the hollow shows through.
        _discoverCloud(kIceRoofTeachId);
        _forceHint(
          '$read. Bare ice over the hollow holds only one creature',
          6.0,
        );
      } else {
        _setInsightHint(read);
      }
      return true;
    }
    // BARE ALREADY: melt it.
    if (under == IceRoofUnder.rock || under == IceRoofUnder.pier) {
      _setBlockedHint('Stone under this ice. Nothing to open');
      return true;
    }
    if (_roofBodiesOn(roof, target) > 0) {
      _setBlockedHint('Someone is standing on that ice');
      return true;
    }
    if (under == IceRoofUnder.head) {
      roofThroat = target;
      _cue(SoundCue.dungeonGateOpen);
      _setHint('The glass goes over the wyrm\'s throat, and cold comes up it');
      _spawnAlchemyBurst(
        p,
        producedElement: 'Ice',
        reagentElements: const ['Light'],
        particleCount: 26,
        intensity: 1.1,
      );
      return true;
    }
    roofWater.add(target);
    _cue(SoundCue.dungeonWallBreak);
    _setHint('The glass goes, and black water takes its place');
    _spawnAlchemyBurst(
      p,
      producedElement: 'Light',
      reagentElements: const ['Ice'],
      particleCount: 16,
      intensity: 0.8,
    );
    return true;
  }

  /// ICE freezes the water ahead back into thin glass. Never the throat.
  bool _tryRoofIce(
    DungeonCreature a,
    IceRoof roof,
    int? target, {
    required bool nearFont,
  }) {
    if (target != null && roofIsWater(target)) {
      roofWater.remove(target);
      roofBare.add(target);
      _cue(SoundCue.elementIce);
      _setHint('Frost takes the still water, thin, and one body\'s worth');
      _spawnAlchemyBurst(
        roof.centerAt(target),
        producedElement: 'Ice',
        particleCount: 18,
        intensity: 0.8,
      );
      return true;
    }
    if (target != null && roofIsThroat(target)) {
      _setBlockedHint('The wyrm\'s breath stops this from freezing');
      return true;
    }
    if (nearFont) return false;
    _setBlockedHint(
      target == null ? 'Nothing ahead but stone' : 'Already frozen',
    );
    return true;
  }

  /// AMBIENT on the roof is what is under your feet (§5.6: flavour only).
  void _roofAmbientHint(DungeonCreature a, IceRoof roof) {
    final c = roof.cellAt(a.position);
    if (c == null) {
      _setAmbientHint('Stone, and the snow field starting at its edge');
      return;
    }
    if (roofIsThin(roof, c)) {
      _setAmbientHint('The glass creaks, and the dark moves under it');
      return;
    }
    if (roofIsBare(c)) {
      _setAmbientHint('Bare ice, white to the stone');
      return;
    }
    for (final n in roof.neighbours(c)) {
      if (roofIsWater(n) || roofIsThroat(n)) {
        _setAmbientHint('Black water beside you, breathing');
        return;
      }
    }
    _setAmbientHint('Snow, deep and quiet, and no telling what is under it');
  }

  // ── The roof, drawn ──────────────────────────────────────

  /// Every pane that is not snow (the snow is the static ground), and the
  /// pane the active hand would work on. Flat fills and a few strokes; the
  /// only motion is the drift under bared hollow — three dots a pane.
  void _renderRoof(Canvas canvas, DungeonRoom room) {
    final roof = room.rime?.roof;
    if (roof == null) return;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _kIcePale.withValues(alpha: 0.35);
    for (var c = 0; c < roof.count; c++) {
      final r = roof.rectOf(c).deflate(3);
      if (roofIsThroat(c)) {
        _drawRoofThroat(canvas, r);
        continue;
      }
      if (roofIsWater(c)) {
        // OPEN WATER: a hole, pitch black, its edge broken where the glass
        // went, and two slow rings on it so it never reads as glass.
        canvas.drawRect(r, Paint()..color = const Color(0xFF020609));
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _kIcePale.withValues(alpha: 0.28);
        final ph = ((_time * 0.35 + c * 0.13) % 1.0);
        canvas.drawCircle(r.center, 6 + ph * 22, ring);
        canvas.drawCircle(
          r.center,
          6 + ((ph + 0.5) % 1.0) * 22,
          ring..color = _kIcePale.withValues(alpha: 0.16),
        );
        canvas.drawRect(
          r.inflate(1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = _kShaftMilk.withValues(alpha: 0.5),
        );
        continue;
      }
      if (!roofIsBare(c)) continue;
      switch (roofUnder(roof, c)) {
        case IceRoofUnder.rock:
        case IceRoofUnder.pier:
          canvas.drawRect(
            r,
            Paint()..color = _kShaftMilk.withValues(alpha: 0.5),
          );
          final crack = Path()
            ..moveTo(r.left + 10, r.bottom - 12)
            ..lineTo(r.center.dx - 6, r.center.dy + 4)
            ..lineTo(r.right - 14, r.top + 10);
          canvas.drawPath(
            crack,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = Colors.white.withValues(alpha: 0.45),
          );
        case IceRoofUnder.hollow:
          // GLASS over the hollow: dark, but blue and lit — never the black
          // of open water beside it.
          canvas.drawRect(
            r,
            Paint()..color = const Color(0xFF0E2A3C).withValues(alpha: 0.9),
          );
          _drawRoofSheen(canvas, r);
          _drawRoofDrift(canvas, r, roofDrift(roof, c), c);
          canvas.drawRect(r, rim);
        case IceRoofUnder.body:
          canvas.drawRect(
            r,
            Paint()..color = const Color(0xFF10263A).withValues(alpha: 0.92),
          );
          _drawRoofSheen(canvas, r);
          _drawRoofScales(canvas, r, roofScaleRun(roof, c));
          canvas.drawRect(r, rim);
        case IceRoofUnder.head:
          canvas.drawRect(
            r,
            Paint()..color = const Color(0xFF10263A).withValues(alpha: 0.92),
          );
          _drawRoofSheen(canvas, r);
          _drawRoofHead(canvas, r);
          canvas.drawRect(r, rim);
      }
    }
    // WHAT THE HAND WOULD WORK ON, before it does (plan, then commit).
    final a = active;
    if (a != null &&
        (a.member.element == 'Light' || a.member.element == 'Ice')) {
      final t = roofTargetCell(a);
      if (t != null) {
        final want = a.member.element == 'Light'
            ? !roofIsWater(t) && !roofIsThroat(t)
            : roofIsWater(t);
        canvas.drawRect(
          roof.rectOf(t).deflate(6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color =
                (a.member.element == 'Light'
                        ? const Color(0xFFFFE9A8)
                        : _kIceWhite)
                    .withValues(alpha: want ? 0.7 : 0.22),
        );
      }
    }
  }

  /// One diagonal of light across a pane of glass: what says GLASS rather
  /// than hole, at any size.
  void _drawRoofSheen(Canvas canvas, Rect r) {
    canvas.drawLine(
      Offset(r.left + 8, r.top + r.height * 0.62),
      Offset(r.left + r.width * 0.5, r.top + 8),
      Paint()
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.16),
    );
  }

  /// The hollow's water, drifting AWAY from the head: four motes a pane,
  /// each with a tail behind it, wrapping along the drift. The direction is
  /// the tell, so the motes are big enough to read on a phone.
  void _drawRoofDrift(Canvas canvas, Rect r, Offset dir, int seed) {
    if (dir == Offset.zero) return;
    final perp = Offset(-dir.dy, dir.dx);
    final span = r.width - 18;
    final mote = Paint()..color = _kIceWhite.withValues(alpha: 0.85);
    final tail = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = _kIcePale.withValues(alpha: 0.4);
    for (var i = 0; i < 4; i++) {
      final phase = (seed * 7 + i * 13) % 11 / 11.0;
      final along = ((_time * 26 + phase * span) % span) - span / 2;
      final off = (i - 1.5) * (r.width * 0.2);
      final p = r.center + dir * along + perp * off;
      canvas.drawLine(p - dir * 14, p, tail);
      canvas.drawCircle(p, 2.6, mote);
    }
  }

  /// The wyrm's flank: chevrons of scale, all pointing the same way — toward
  /// the head.
  void _drawRoofScales(Canvas canvas, Rect r, Offset dir) {
    if (dir == Offset.zero) return;
    final perp = Offset(-dir.dy, dir.dx);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = _kShaftIce.withValues(alpha: 0.55);
    final path = Path();
    for (var i = -1; i <= 1; i++) {
      final c = r.center + dir * (i * 16.0);
      path
        ..moveTo(
          c.dx - dir.dx * 9 - perp.dx * 12,
          c.dy - dir.dy * 9 - perp.dy * 12,
        )
        ..lineTo(c.dx, c.dy)
        ..lineTo(
          c.dx - dir.dx * 9 + perp.dx * 12,
          c.dy - dir.dy * 9 + perp.dy * 12,
        );
    }
    canvas.drawPath(path, p);
  }

  /// The head: one pale slit of an eye, and hoarfrost blooming on the glass
  /// above it — the breath, frozen where it touched.
  void _drawRoofHead(Canvas canvas, Rect r) {
    final c = r.center;
    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(0, 6), width: 30, height: 9),
      Paint()..color = const Color(0xFFE6F6FF).withValues(alpha: 0.85),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(0, 6), width: 6, height: 9),
      Paint()..color = _kShaftDark,
    );
    final breath = 0.5 + 0.5 * sin(_time * 1.4);
    final fern = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.35 + 0.3 * breath);
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = -pi / 2 + (i - 2.5) * 0.42;
      final tip = c + Offset(cos(a), sin(a)) * (14 + 12 * breath);
      path
        ..moveTo(c.dx, c.dy - 4)
        ..lineTo(tip.dx, tip.dy);
    }
    canvas.drawPath(path, fern);
  }

  /// The open throat: black, and the cold coming up it.
  void _drawRoofThroat(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = const Color(0xFF010305));
    final cold = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = _kIceWhite.withValues(alpha: 0.35);
    for (var i = 0; i < 3; i++) {
      final x = r.left + r.width * (0.25 + i * 0.25);
      final rise = ((_time * 30 + i * 21) % (r.height - 10));
      final y = r.bottom - 5 - rise;
      canvas.drawLine(Offset(x, y), Offset(x, y - 10), cold);
    }
    final awake = guardianAwake || hasStar(2);
    canvas.drawRect(
      r.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = awake ? 3 : 2
        ..color = (awake ? Colors.white : _kIcePale).withValues(
          alpha: awake ? 0.6 + 0.3 * sin(_time * 3) : 0.4,
        ),
    );
  }

  // ── The Lost Maxim · STAR-WALKER ─────────────────────────
  //
  // THE STRANGER, AND THE SHAFT YOU WERE TOLD NEVER TO MAKE (2026-09-19; the
  // §7 maxim standard, and Mud's lesson that the best place to hide a secret
  // is the state your own stars punish).
  //
  // Star-Walker used to be one press: a telescope on the shelf, gated on the
  // Mirror Star, answering Ice. It is a CHAIN now, and every link is a thing
  // this planet already taught:
  //
  //   1. RIDE FLUE A BARE. Snow shows the water nothing and cut steps show
  //      it nothing; a shaft ridden to polished ice is a MIRROR, and the pool
  //      under it sees past the mouth to the sky. That is the one state the
  //      primer spends its first sentence steering you away from, and it
  //      costs you the way back up until the rimefall.
  //   2. WAKE THE WATER AND WALK THE LAMP. Read like everything else here —
  //      the Light hand across the ring, or Air's sweep — and one star hangs
  //      out past the chart that no frame puts anywhere. It hangs on a
  //      BEARING, and the bearing is the whole secret.
  //   3. RIDE CHUTE B. The niche is on a shelf you can only fall onto; you
  //      carry the bearing down with you, and can come back for another go.
  //   4. TURN THE WHEEL — Air, a notch a breath, twelve notches round. The
  //      repeated beat, and the tube swings to say where it looks.
  //   5. LOCK THE SIGHTING — Ice, on the stranger's bearing. Empty sky is a
  //      sentence and a puff of frost; nothing is ever spent.
  //
  // Nothing here asks for a family the riddle did not name, and the star
  // path never passes it: a clean three-star run freezes A and never sees
  // the stranger at all.

  /// Which chart-star index sits on frame [i]'s bearing (star k = 2i).
  int strangerStarIndex() => 2 * strangerFrame;

  /// The shaft over the gallery, as the water sees it: only BARE ICE is a
  /// mirror. Drift is snow, a stair is cut steps; neither shows the sky.
  bool get shaftAboveIsMirror {
    final above = rimeFlueBetween(layout.entranceRoomId, 'mirror_gallery');
    return above != null && _flue(above.id) == RimeFlueState.scoured;
  }

  /// How brightly the stranger is read in the water, 0..1 — the shaft above
  /// must be a mirror, the water awake, and the lamp (or a sweep, or the
  /// banked chart) reading that bearing.
  double strangerLight(MirrorRing ring) {
    if (!shaftAboveIsMirror || !lodestoneLit) return 0;
    if (discoveredClouds.contains(kIceStarWalkerEggId)) return 0;
    return chartStarLight(ring, strangerStarIndex());
  }

  /// Said ONCE in a lifetime, the first time the water shows the stranger.
  static const String kIceStrangerTeachId = 'teach:ice_stranger';

  /// The water has shown the stranger: from here the lens can be set on it.
  void _watchForStranger(MirrorRing ring) {
    if (strangerSeen || strangerLight(ring) <= 0.5) return;
    strangerSeen = true;
    _cue(SoundCue.cosmicDiscovery);
    if (discoveredClouds.contains(kIceStrangerTeachId)) return;
    _discoverCloud(kIceStrangerTeachId);
    _forceHint(
      'Through the bare shaft the pool shows the sky, with one star no '
      'frame charts',
      6.0,
    );
  }

  /// The lens on the shelf. Air turns it a notch; Ice takes the sighting.
  bool _tryTelescope(DungeonCreature a) {
    final pos = currentRoom.rime?.telescope;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kShaftReach) return false;
    if (discoveredClouds.contains(kIceStarWalkerEggId)) return false;
    final ring = _mirrorRingRoom?.rime?.mirrors;
    if (ring == null) return false;
    switch (a.member.element) {
      case 'Air':
        // THE REPEATED BEAT: a breath turns the wheel one notch, always the
        // same way round, and the tube swings to show where it looks now.
        telescopeNotch = (telescopeNotch + 1) % ring.count;
        telescopeSwing = 1;
        _cue(SoundCue.dungeonSwitch);
        _spawnAlchemyBurst(
          pos,
          producedElement: 'Air',
          particleCount: 8,
          intensity: 0.5,
        );
        return true;
      case 'Ice':
        if (!strangerSeen) {
          // WHAT is missing (§5.6), never how to get it.
          _setBlockedHint('The lens shows nothing. Point it where the water saw a star');
          return true;
        }
        if (telescopeNotch != strangerFrame) {
          // Empty sky: a sentence and a puff of frost. Nothing is spent.
          _spawnAlchemyBurst(
            pos,
            producedElement: 'Ice',
            particleCount: 8,
            intensity: 0.5,
          );
          _setHint('Frost on the glass, and empty sky behind it');
          return true;
        }
        // THE RITE OF THREE pays this out (see `beginMaximRite`).
        _cue(SoundCue.dungeonGateOpen);
        beginMaximRite(kIceStarWalkerEggId, pos);
        _spawnAlchemyBurst(
          pos,
          producedElement: 'Light',
          reagentElements: const ['Ice', 'Air'],
          particleCount: 40,
          intensity: 1.4,
        );
        return true;
      default:
        _spawnAlchemyBurst(
          pos,
          producedElement: a.member.element,
          particleCount: 8,
          intensity: 0.5,
        );
        _setBlockedHint('Light in the lens just shows your reflection');
        return true;
    }
  }

  DungeonRoom? get _mirrorRingRoom {
    for (final r in layout.rooms.values) {
      if (r.rime?.mirrors != null) return r;
    }
    return null;
  }

  // ── Per-frame ────────────────────────────────────────────

  /// The plate over the mouth, named ONCE in a lifetime, at the hole.
  static const String kIceBlackIceId = 'teach:ice_black_ice';

  /// WHY WILL NOTHING I DO TOUCH THIS?
  ///
  /// The entry rite is the one puzzle a player meets before they have learned
  /// a single rule of this planet, and the room answered that question with
  /// silence: an unasked refusal is held back for the hint button (§5.6), and
  /// the plate itself cannot say what it wants. So the floor says it, once,
  /// when you first walk up to a hole — not on arrival, where it would talk
  /// over the primer, which is the rule of the whole shaft and outranks it.
  void _teachBlackIce(DungeonCreature a, DungeonRoom room) {
    final cap = room.rime?.iceCap;
    if (cap == null || entryDoorRevealed) return;
    if (discoveredClouds.contains(kIceBlackIceId)) return;
    final near =
        (a.position - cap).distance < 120 ||
        kRimeFlues.any(
          (f) =>
              f.headRoom == room.id && (a.position - f.headPos).distance < 120,
        );
    if (!near) return;
    _discoverCloud(kIceBlackIceId);
    _forceHint(
      'Each hole in this floor is sealed with black ice. Frost only '
      'thickens it. Light melts it, one hole at a time.',
      6.0,
    );
  }

  /// The price of the rimefall, said ONCE in a lifetime, at the foot of it.
  static const String kIceRimefallPriceId = 'teach:ice_rimefall_price';

  /// THE PRICE IS TOLD BEFORE IT IS PAID, not after.
  ///
  /// The rimefall is one step through a doorway and it resets the whole
  /// shaft. The line that says so fires on the way THROUGH — the right moment
  /// to learn what happened and the wrong one to decide — so a party standing
  /// at the foot of it with work behind them is told while they can still
  /// walk away.
  ///
  /// It is a TEACH, not a refusal: §5.6's silence rule holds every unasked
  /// blocked line back until the hint button asks for it, and a warning
  /// nobody is shown is not a warning. A one-time teach is the one exception
  /// the rule makes, and this is exactly the shape it is for — once ever,
  /// persisted, never a nag.
  void _warnRimefallPrice(DungeonCreature a, DungeonRoom room) {
    if (room.rime?.rimefall == null || !rimefallFrozen) return;
    if (discoveredClouds.contains(kIceRimefallPriceId)) return;
    final door = room.doors
        .where((d) => d.targetRoomId == layout.entranceRoomId)
        .firstOrNull;
    if (door == null || !door.rect.inflate(130).contains(a.position)) return;
    // Nothing cut, nothing to lose: the one climb that is free says nothing,
    // and the line is saved for the first time it actually costs.
    final standing = kRimeFlues.any((f) => _flue(f.id) != RimeFlueState.drift);
    if (!standing && orreryGlass.isEmpty && orrerySeated.isEmpty) return;
    _discoverCloud(kIceRimefallPriceId);
    _forceHint(
      'Climbing out here resets the whole shaft: every stair, and the '
      'orrery too.',
      6.0,
    );
  }

  void _updateShaft(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isShaft) return;
    if (orrerySlideId != null) {
      final g = room.rime?.orrery;
      final cells = g == null
          ? 1
          : ((orrerySlideTo % g.cols - orrerySlideFrom % g.cols).abs() +
                    (orrerySlideTo ~/ g.cols - orrerySlideFrom ~/ g.cols).abs())
                .clamp(1, 99);
      orrerySlideT += dt / (_kSlidePerCell * cells);
      if (orrerySlideT >= 1) {
        orrerySlideT = 0;
        orrerySlideId = null;
      }
    }
    _teachBlackIce(a, room);
    _warnRimefallPrice(a, room);
    _updateMirrors(room, dt);
    _updateGlideFooting(a, room, dt);
    if (telescopeSwing > 0) telescopeSwing = max(0.0, telescopeSwing - dt * 3);
    if (_hoarfrostDown > 0) _hoarfrostDown = max(0.0, _hoarfrostDown - dt);
    _updateRoof(a, room, dt);
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
  ///
  /// AND IF THERE IS NO STAIR, IT TAKES THE RIMEFALL. The roar used to cost
  /// nothing at all to a party that had ridden everything down, so the only
  /// player it ever punished was the one who had done what the planet asks
  /// and built the ladder home. A party with no stairs is standing on the
  /// valve instead, so that is what the wyrm breaks: the fall runs again and
  /// has to be re-frozen. Never a strand — Ice re-freezes it from the sump
  /// at any time, which is the whole point of it.
  void _shatterOneStair() {
    for (final f in kRimeFlues) {
      if (_flue(f.id) != RimeFlueState.stair) continue;
      flueState[f.id] = RimeFlueState.scoured;
      _cue(SoundCue.elementIce);
      // A closing announces itself (§5.7). This runs from update, where a
      // plain line is dropped unasked — and the roar was therefore silent.
      speakConsequence(
        'Frowyrm roars, and one of your stairs in the shaft breaks',
      );
      return;
    }
    if (rimefallFrozen) {
      rimefallFrozen = false;
      _cue(SoundCue.elementIce);
      speakConsequence(
        'Frowyrm roars, and the rimefall far above breaks',
      );
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
        label: 'CHART',
        value: '$chartStarsWhole/$kIceChartStars',
        fraction: chartStarsWhole / kIceChartStars,
      );
    }
    if (room?.rime?.roof != null && !hasStar(2)) {
      final sung =
          ((conduitEnergy['A'] ?? 0) > 0 ? 1 : 0) +
          ((conduitEnergy['B'] ?? 0) > 0 ? 1 : 0);
      return DungeonProgressReadout(
        label: 'RITE',
        value: '$sung/2',
        fraction: sung / 2,
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
      return 'Frowyrm\'s Hollow. The last star is here';
    }
    if (room.rime?.roof != null) {
      return guardianAwake || hasStar(2)
          ? 'The Star Font. The wyrm is awake below'
          : 'The Star Font, on the ice over the wyrm\'s hollow';
    }
    if (room.rime?.rimefall != null) {
      return 'The Cold Sump, the bottom of the shaft';
    }
    if (room.rime?.telescope != null) {
      return discoveredClouds.contains(kIceStarWalkerEggId)
          ? null
          : 'A niche with an old lens, pointed at nothing';
    }
    if (room.vaultCache != null) {
      return 'A glass ledge. Something is stored here';
    }
    final ring = room.rime?.mirrors;
    if (ring != null) {
      if (hasStar(room.rime!.starIndex!)) return null;
      return 'The Mirror Gallery. A star chart shows in the pool';
    }
    if (room.rime?.orrery != null) {
      if (hasStar(room.rime!.starIndex!)) return null;
      return 'The Standing Orrery. Its star-blocks are off their sockets';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Rime Head. The shaft drops away below'
          : 'The Rime Head. Old black ice seals the floor';
    }
    return null;
  }

  /// AMBIENT is flavour only (§5.6): no mechanics, no elements, no families.
  void _shaftAmbientHint(DungeonCreature a, DungeonRoom room) {
    final roof = room.rime?.roof;
    if (roof != null) {
      _roofAmbientHint(a, roof);
      return;
    }
    final cap = room.rime?.iceCap;
    if (cap != null && !entryDoorRevealed) {
      final near =
          (a.position - cap).distance < 110 ||
          kRimeFlues.any(
            (f) =>
                f.headRoom == room.id &&
                (a.position - f.headPos).distance < 110,
          );
      if (near) {
        _setAmbientHint('Black ice, old enough to have gone the colour of it');
        return;
      }
    }
    for (final f in kRimeFlues) {
      if (f.headRoom != room.id) continue;
      final chute = f.chutePos;
      if (chute != null && (a.position - chute).distance <= _kShaftReach) {
        _setAmbientHint(
          'Snow banked to the lip, and spilling away over the side',
        );
        return;
      }
      if ((a.position - f.headPos).distance > _kShaftReach) continue;
      if (f.isThroat) {
        // The gullet the whole glacier drains through. It says WHAT it is;
        // what that costs you is the shaft's earned reading.
        _setAmbientHint(
          rimefallFrozen
              ? 'The gullet stands white, top to bottom'
              : 'Meltwater, pouring away into the dark',
        );
        return;
      }
      // Flavour that carries the SHAPE of the fall (§5.6 allows no mechanics
      // here, but what the snow is like is what the snow is like).
      _setAmbientHint(switch (_flue(f.id)) {
        RimeFlueState.drift => 'Soft snow, heaped deep enough to catch a body',
        RimeFlueState.scoured =>
          'Swept to bare ice, nothing left in it to catch on',
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
      return;
    }
    final pillar = room.rime?.hoarfrost;
    if (pillar != null && (a.position - pillar).distance < 110) {
      _setAmbientHint(
        hoarfrostWhole
            ? 'Feathered rime, grown taller than a man'
            : 'A broken stump, and its shards all round it',
      );
    }
  }

  /// INSIGHT is the only channel allowed to teach method (§5.6), and it is
  /// tiered by Intelligence.
  void _shaftReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    if (room.rime?.orrery != null) {
      _setInsightHint(switch (tier) {
        0 => 'The blocks only slide on ice. Ice glazes the floor, Light melts it',
        1 =>
          'A shoved block slides until the ice ends. Each kerb only opens '
              'one way, shown by its arrow',
        _ =>
          'Stand behind a block to see where it would slide. The crank on '
              'the east wall resets every block',
      });
      return;
    }
    if (room.rime?.mirrors != null) {
      _setInsightHint(switch (tier) {
        0 => 'The pool is dark until the black glass is struck with Light',
        1 =>
          'The pool shows the part of the chart across from where you stand. '
              'Walk the rim to see it all',
        _ =>
          'Every figure on the chart appears twice except one. Find the odd '
              'one out and have Ice silver its frame',
      });
      return;
    }
    if (room.rime?.telescope != null) {
      // ONE OBLIQUE LINE and nothing after it (the §7 maxim standard). It
      // does not tier and it does not track progress.
      _setInsightHint(
        'A shaft ridden bare of snow reflects the sky. The lens wants to '
        'point where the water saw something',
      );
      return;
    }
    // THE SEALED MOUTH READS THE PLATE. Insight here fell through to the
    // shaft line, which is about flues — and there is no flue to be had until
    // the floor is open, so the one question the player actually has ("why
    // will nothing I do touch this?") went unanswered by the hint button too.
    if (room.rime?.iceCap != null && !entryDoorRevealed) {
      _setInsightHint(switch (tier) {
        0 => 'Old black ice covers the holes in this floor',
        1 => 'Frost only thickens black ice. It needs Light to melt',
        _ =>
          'Light melts one plate at a time. Each hole leads somewhere '
              'different',
      });
      return;
    }
    // THE ROOF READS THE ROOF: snow, glass, and what the glass lies on.
    if (room.rime?.roof != null) {
      _setInsightHint(switch (tier) {
        0 => 'The wyrm sleeps under this floor',
        1 =>
          'Light clears the snow to show what\'s under the ice. The dark '
              'water drifts away from the wyrm\'s head',
        _ =>
          'Bare ice over the hollow holds one creature at a time. Follow the '
              'drift to the head, open the ice there, then turn the breath '
              'down and sing the font',
      });
      return;
    }
    // THE HOLLOW READS THE FIGHT, not the shaft. Insight here used to fall
    // through to the flue line, so the one room whose verb is not a flue was
    // the one room the hint button would not talk about.
    if (room.rime?.hoarfrost != null) {
      _setInsightHint(switch (tier) {
        0 => 'The hoarfrost pillar is the key to this fight',
        1 => 'Frowyrm can only be hit while the hoarfrost pillar stands',
        _ =>
          'Ice raises the pillar. Each hit Frowyrm lands shatters it and '
              'destroys one of your stairs in the shaft above',
      });
      return;
    }
    // Anywhere in the shaft, insight reads the SHAFT — which is the planet.
    _setInsightHint(switch (tier) {
      0 => 'The shafts only go down unless you freeze steps into them',
      1 =>
        'Ice freezes a snowy shaft into steps you can climb. Ride it down '
            'instead and it\'s bare for good',
      _ =>
        'Freeze steps before riding down, or you can\'t come back up. The '
            'fall at the very bottom resets the whole shaft if you get stuck',
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
  ///     WITHOUT paying a thaw. It must be non-zero: a ledge is entered from
  ///     the level above it, so once you are below with no stair back up,
  ///     the ledge is gone until the rimefall. That is gravity, the planet's
  ///     whole idea — not the chute, which is a ramp you may ride again.
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

    // A state is 'room|shaft states|rimefall'. The ledge chutes carry no
    // state: their snow holds, and riding one changes nothing but the room.
    String enc(String room, List<RimeFlueState> st, bool fall) =>
        '$room|${st.map((s) => s.index).join()}|${fall ? 1 : 0}';

    /// Every move out of one state. TWO MOUTHS PER HEAD and nothing couples
    /// them: the shaft always goes down (and its snow decides only whether
    /// you can come back up), and the chute always goes to its ledge.
    List<(String, List<RimeFlueState>, bool)> moves(
      String room,
      List<RimeFlueState> st,
      bool fall, {
      required bool rimefallEnabled,
    }) {
      final out = <(String, List<RimeFlueState>, bool)>[];
      for (var i = 0; i < flues.length; i++) {
        final f = flues[i];
        if (f.headRoom == room) {
          // The shaft, down. Always possible; a drift is spent by the ride.
          if (st[i] == RimeFlueState.drift) {
            out.add((f.footRoom, [...st]..[i] = RimeFlueState.scoured, fall));
            if (f.freezable) {
              out.add((room, [...st]..[i] = RimeFlueState.stair, fall));
            }
          } else {
            out.add((f.footRoom, st, fall));
          }
          // The ledge chute, a ramp every time.
          if (f.shelfRoom != null) out.add((f.shelfRoom!, st, fall));
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
      // Plain doors that are not part of the shaft at all: the ledges'
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

  // ── THE ORRERY IS NEVER A DEAD BOARD ─────────────────────

  /// Exhaustive search over every board the orrery can be shoved into.
  ///
  /// The shaft has a proof that it cannot strand a PARTY (`solveShaftDescent`)
  /// and had none that it cannot strand a STAR, which is the same fault in a
  /// smaller room: a star-block shoved somewhere it can never leave is a run
  /// ended, quietly, with the suite green over it. It reports the number of
  /// reachable boards and how many of them can no longer be solved. **`dead`
  /// must be zero.**
  ///
  /// Glass is treated as free, because it is: Ice lays it and Light takes it
  /// back, anywhere, at no cost, so the reachable boards are decided by the
  /// SHOVES alone.
  ///
  /// `dead` IS NO LONGER ZERO, and that is deliberate: with star-blocks made
  /// solid, three of them can be packed into a corner where each blocks the
  /// square the next would be pushed from (151 of 7,140 boards). The answer
  /// is not to forbid the jam — it is the armature, which puts every loose
  /// block back on its standard for nothing. What must hold is `startDead ==
  /// false`: the board the armature restores is always solvable. What a shove can do is [_orreryRuns] — the same walk
  /// `_shoveBlock` performs, minus the glass that decides where it stops.
  ({int boards, int dead, bool startDead}) solveOrreryBoards() {
    final g = _orreryRoom?.rime?.orrery;
    if (g == null) return (boards: 0, dead: 0, startDead: false);
    final start = <int>[
      for (var r = 0; r < g.rows; r++)
        for (var c = 0; c < g.cols; c++)
          if (g.art[r][c] == 'B') r * g.cols + c,
    ];

    // A board is the blocks' cells plus which of them are seated, normalised
    // so two boards that differ only in which block is which are one board.
    String enc(List<int> cells, Set<int> seated) {
      final pairs = [
        for (var i = 0; i < cells.length; i++)
          '${cells[i]}${seated.contains(i) ? 'S' : ''}',
      ]..sort();
      return pairs.join(',');
    }

    List<(List<int>, Set<int>)> moves(List<int> cells, Set<int> seated) {
      final out = <(List<int>, Set<int>)>[];
      for (var i = 0; i < cells.length; i++) {
        if (seated.contains(i)) continue;
        final c = cells[i] % g.cols;
        final r = cells[i] ~/ g.cols;
        for (final dir in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          // The pusher stands on the far side — on the floor or in its halo,
          // and never inside an iron standard (they are walls).
          final pc = c - dir.$1, pr = r - dir.$2;
          if (pc < -1 || pr < -1 || pc > g.cols || pr > g.rows) continue;
          if (pc >= 0 &&
              pr >= 0 &&
              pc < g.cols &&
              pr < g.rows &&
              (_orreryPillar(g, pc, pr) || cells.contains(pr * g.cols + pc))) {
            continue; // standards and star-blocks are both solid now
          }
          for (final run in _orreryRuns(g, cells, seated, i, dir)) {
            // Every cell of glass that run needs has to be LAYABLE: Ice must
            // be able to stand in an open neighbour of it, facing it.
            if (!_orreryRunLayable(g, cells, run.$1, i, dir)) continue;
            final next = [...cells]..[i] = run.$1;
            out.add((next, run.$2 ? {...seated, i} : seated));
          }
        }
      }
      return out;
    }

    final startSeated = <int>{};
    final live = <String, (List<int>, Set<int>)>{
      enc(start, startSeated): (start, startSeated),
    };
    final edges = <String, List<String>>{};
    final queue = [(start, startSeated)];
    while (queue.isNotEmpty) {
      final (cells, seated) = queue.removeLast();
      final key = enc(cells, seated);
      final outs = <String>[];
      for (final m in moves(cells, seated)) {
        final k = enc(m.$1, m.$2);
        outs.add(k);
        if (live.containsKey(k)) continue;
        live[k] = m;
        queue.add(m);
      }
      edges[key] = outs;
    }

    // Walk the graph backwards from every solved board: anything the reverse
    // search never reaches can never be solved again.
    final back = <String, List<String>>{};
    for (final e in edges.entries) {
      for (final to in e.value) {
        (back[to] ??= []).add(e.key);
      }
    }
    final good = <String>{
      for (final e in live.entries)
        if (e.value.$2.length == e.value.$1.length) e.key,
    };
    final fringe = [...good];
    while (fringe.isNotEmpty) {
      for (final from in back[fringe.removeLast()] ?? const <String>[]) {
        if (good.add(from)) fringe.add(from);
      }
    }
    return (
      boards: live.length,
      dead: live.length - good.length,
      startDead: !good.contains(enc(start, startSeated)),
    );
  }

  /// Whether every cell of glass a run to [endCell] needs can actually be
  /// laid, with all the star-blocks where they are and solid.
  bool _orreryRunLayable(
    OrreryGrid g,
    List<int> cells,
    int endCell,
    int i,
    (int, int) dir,
  ) {
    bool standable(int c, int r) {
      if (c < -1 || r < -1 || c > g.cols || r > g.rows) return false;
      if (c < 0 || r < 0 || c >= g.cols || r >= g.rows) return true; // margin
      if (_orreryPillar(g, c, r)) return false;
      return !cells.contains(r * g.cols + c);
    }

    var c = cells[i] % g.cols;
    var r = cells[i] ~/ g.cols;
    while (true) {
      c += dir.$1;
      r += dir.$2;
      final k = r * g.cols + c;
      if (_orrerySocket(g, c, r)) return true; // a kerb needs no glass
      final ok =
          standable(c + 1, r) ||
          standable(c - 1, r) ||
          standable(c, r + 1) ||
          standable(c, r - 1);
      if (!ok) return false;
      if (k == endCell) return true;
    }
  }

  /// Every cell a shove of block [i] in [dir] can END on, with whether that
  /// end is a socket. One entry per length of glass the player might lay.
  List<(int, bool)> _orreryRuns(
    OrreryGrid g,
    List<int> cells,
    Set<int> seated,
    int i,
    (int, int) dir,
  ) {
    final out = <(int, bool)>[];
    var c = cells[i] % g.cols;
    var r = cells[i] ~/ g.cols;
    while (true) {
      final nc = c + dir.$1, nr = r + dir.$2;
      if (nc < 0 || nr < 0 || nc >= g.cols || nr >= g.rows) break;
      if (_orreryPillar(g, nc, nr)) break;
      if (cells.contains(nr * g.cols + nc)) break;
      if (_orrerySocket(g, nc, nr)) {
        // A kerb that does not open to THIS block, THIS way, is a wall.
        if (_orreryKerbOpens(g, nc, nr, dir, id: i)) {
          out.add((nr * g.cols + nc, true));
        }
        break;
      }
      out.add((nr * g.cols + nc, false));
      c = nc;
      r = nr;
    }
    return out;
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
    _renderRoof(canvas, room);
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
    // THE LEDGE CHUTES FIRST — a different kind of hole, drawn differently,
    // and never the same hole as the shaft beside it.
    for (final f in kRimeFlues) {
      if (f.headRoom != room.id || f.chutePos == null) continue;
      if (room.rime?.iceCap != null && !_capMelted('${f.id}:chute')) continue;
      _drawLedgeChute(canvas, f.chutePos!);
    }
    for (final f in kRimeFlues) {
      if (f.headRoom != room.id) continue;
      // The collar is masonry and is always there; what is IN it is the
      // planet's whole state, so the cap hides the hole and not the kerb.
      if (room.rime?.iceCap != null && !_capMelted('${f.id}:shaft')) continue;
      final r = Rect.fromCenter(center: f.headPos, width: 118, height: 84);
      final state = f.isThroat && rimefallFrozen
          ? RimeFlueState.stair
          : _flue(f.id);
      // The dark of the drop, under everything: a mouth is a hole first.
      canvas.drawOval(
        r.deflate(2),
        Paint()..color = const Color(0xFF050D14).withValues(alpha: 0.92),
      );
      // THE THROAT IS NOT A FLUE AND MUST NEVER LOOK LIKE ONE. Both holes in
      // the mouth's floor were heaped snow: one is a ride you can freeze into
      // your way home, the other is the melt-fall's own gullet, takes no
      // frost from above and plunges past every level to the bottom. Drawn as
      // what it is — running water going down a wet black pipe — so the
      // difference is on screen before you step in it, not after.
      if (f.isThroat && !rimefallFrozen) {
        canvas.save();
        canvas.clipPath(Path()..addOval(r.deflate(2)));
        final water = Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.2;
        for (var i = 0; i < 13; i++) {
          final x = r.left + 10 + i * (r.width - 20) / 12;
          final t = (_time * 1.9 + i * 0.37) % 1.0;
          final y = r.top + 6 + t * (r.height - 12);
          water.color = _kIcePale.withValues(alpha: 0.16 + (1 - t) * 0.5);
          canvas.drawLine(Offset(x, y), Offset(x, y + 16), water);
        }
        canvas.drawArc(
          r.deflate(8),
          -2.7,
          1.9,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white.withValues(alpha: 0.34),
        );
        canvas.restore();
        // The kerb, and nothing else: no snow, no steps, no polish.
        canvas.drawOval(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..color = _kShaftStone.withValues(alpha: 0.85),
        );
        continue;
      }
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

  /// OLD BLACK ICE — a plate that froze in place over a mouth, not a
  /// lozenge. Irregular, near-black, crazed white where it has been working
  /// against the kerb for a few centuries.
  void _drawBlackIce(Canvas canvas, Offset p) {
    // OLD BLACK ICE — a plate that froze in place over the mouth, not a
    // lozenge. Irregular, near-black, crazed white where it has been
    // working against the kerb for a few centuries.
    final plate = Path();
    for (var i = 0; i < 11; i++) {
      final a = i * pi * 2 / 11;
      final k = 1 + sin(i * 2.7) * 0.16;
      final q = p + Offset(cos(a) * 78 * k, sin(a) * 40 * k);
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
        ..moveTo(p.dx, p.dy)
        ..lineTo(p.dx + cos(a) * 70, p.dy + sin(a) * 34)
        ..moveTo(p.dx + cos(a) * 34, p.dy + sin(a) * 17)
        ..lineTo(p.dx + cos(a + 0.9) * 52, p.dy + sin(a + 0.9) * 26);
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

  /// A LEDGE CHUTE. Deliberately not a shaft: narrower, canted, and with its
  /// snow visibly running OFF to one side into the pocket it feeds, so the
  /// two holes at a head can never be mistaken for one hole in two moods.
  /// The snow is always in it: a chute is a ramp every time.
  void _drawLedgeChute(Canvas canvas, Offset p) {
    final r = Rect.fromCenter(center: p, width: 86, height: 58);
    canvas.drawOval(
      r.deflate(2),
      Paint()..color = const Color(0xFF050D14).withValues(alpha: 0.92),
    );
    // The snow, heaped to the lip and spilling away downhill.
    final ramp = Path()
      ..moveTo(r.left + 6, r.bottom - 8)
      ..quadraticBezierTo(r.center.dx - 10, r.top + 8, r.right - 10, r.top + 20)
      ..lineTo(r.right - 6, r.bottom - 10)
      ..close();
    canvas.drawPath(ramp, Paint()..color = _kIceWhite.withValues(alpha: 0.6));
    canvas.drawPath(
      ramp,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.7),
    );
    // The tongue of snow going over the lip, which is where you go.
    final tongue = Path()
      ..moveTo(r.right - 14, r.top + 22)
      ..lineTo(r.right + 26, r.top + 34)
      ..lineTo(r.right + 22, r.bottom - 4)
      ..lineTo(r.right - 10, r.bottom - 10)
      ..close();
    canvas.drawPath(
      tongue,
      Paint()..color = _kIceWhite.withValues(alpha: 0.34),
    );
    canvas.drawOval(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = _kShaftStone.withValues(alpha: 0.85),
    );
  }

  /// WHAT THE FLOOR SHOWS YOU FROM WHERE YOU STAND — the orrery's half of
  /// this planet's one idea (the gallery's is the pool). Stand behind a block
  /// and the road it would take is drawn in front of it, with the cell it
  /// would stop on marked, before you spend a thing.
  ///
  /// Not a hint and not a tier of Mask's reading: it is the same
  /// deterministic walk the shove performs, shown early. That is what
  /// plan-then-commit means — knowing the answer and having it are the same.
  ({int block, List<int> path, int stop, bool seats})? _orreryPreview(
    OrreryGrid g,
  ) {
    final a = active;
    if (a == null) return null;
    final here = _orreryStandCell(g, a.position);
    if (here == null) return null;
    final step = _orreryFacing(a);
    final c = here.$1 + step.$1;
    final r = here.$2 + step.$2;
    if (c < 0 || r < 0 || c >= g.cols || r >= g.rows) return null;
    final id = _orreryBlockAt(g, c, r);
    if (id == null || orrerySeated.contains(id)) return null;
    final run = _orreryRun(g, id, step);
    if (!run.moved) return null;
    return (block: id, path: run.travelled, stop: run.cell, seats: run.seats);
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

    // THE RUN, FROM WHERE YOU ARE STANDING. Drawn under the furniture, so the
    // sockets and the blocks stay the loudest things in the room (§7.9).
    final preview = hasStar(room.rime?.starIndex ?? -1)
        ? null
        : _orreryPreview(g);
    if (preview != null) {
      final cell = orreryBlocks[preview.block]!;
      final from = g.centerAt(cell % g.cols, cell ~/ g.cols);
      final to = g.centerAt(preview.stop % g.cols, preview.stop ~/ g.cols);
      final col = preview.seats ? const Color(0xFFE9C46A) : _kIcePale;
      // A dashed road, so it reads as a projection and never as laid glass.
      final d = to - from;
      final len = d.distance;
      if (len > 1) {
        final unit = d / len;
        final dash = Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3
          ..color = col.withValues(alpha: preview.seats ? 0.75 : 0.42);
        for (var t = 14.0; t < len - 10; t += 26) {
          canvas.drawLine(from + unit * t, from + unit * (t + 13), dash);
        }
      }
      // Where it stops: a kerb-ring if it seats, an open mark if it does not.
      canvas.drawCircle(
        to,
        preview.seats ? 30 : 22,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = preview.seats ? 3.5 : 2.2
          ..color = col.withValues(alpha: preview.seats ? 0.9 : 0.5),
      );
      if (!preview.seats) {
        // The road it would crack behind it, marked as loss, not as gain.
        final crack = Paint()
          ..strokeWidth = 1.6
          ..color = const Color(0xFFC0392B).withValues(alpha: 0.38);
        for (final k in preview.path) {
          final p = g.centerAt(k % g.cols, k ~/ g.cols);
          canvas.drawLine(
            p + const Offset(-9, -9),
            p + const Offset(9, 9),
            crack,
          );
          canvas.drawLine(
            p + const Offset(9, -9),
            p + const Offset(-9, 9),
            crack,
          );
        }
      }
    }

    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        final ch = g.art[r][c];
        final p = g.centerAt(c, r);
        if (ch == '#') {
          _drawIronStandard(canvas, p);
        } else {
          final dir = _orrerySocketDir(g, c, r);
          if (dir != null) {
            _drawOrrerySocket(canvas, p, g.cell, dir);
            // WHOSE KERB THIS IS, cut into the stone inside the ring — the
            // same figure the block carries.
            final owner = g.kerbOwner[r * g.cols + c];
            if (owner != null) {
              _drawStarFigure(
                canvas,
                Rect.fromCenter(center: p, width: 26, height: 26),
                owner,
                _kShaftBrassLit.withValues(alpha: 0.75),
                1.6,
              );
            }
          }
        }
      }
    }

    _drawOrreryCrank(canvas, _orreryCrankAt(g));

    for (final e in orreryBlocks.entries) {
      final c = e.value % g.cols;
      final r = e.value ~/ g.cols;
      var at = g.centerAt(c, r);
      if (orrerySlideId == e.key) {
        // Running its road: eased, so it leaves heavily and settles.
        final from = g.centerAt(
          orrerySlideFrom % g.cols,
          orrerySlideFrom ~/ g.cols,
        );
        at = Offset.lerp(
          from,
          at,
          Curves.easeOutCubic.transform(orrerySlideT.clamp(0.0, 1.0)),
        )!;
        // Spray off the leading edge while it runs.
        final d = (at - from);
        if (d.distance > 1) {
          final u = d / d.distance;
          for (var i = 0; i < 3; i++) {
            canvas.drawCircle(
              at - u * (26 + i * 9.0) + Offset(u.dy, -u.dx) * (i - 1) * 7,
              2.6 - i * 0.6,
              Paint()..color = Colors.white.withValues(alpha: 0.4 - i * 0.11),
            );
          }
        }
      }
      // IN REACH, AND IT SAYS SO. A star-block is the one thing on this floor
      // you take hold of, and it looked exactly the same whether you could
      // work it or were standing across the room from it. Near: a cold ring
      // under it. The one your facing would actually shove: brighter, and
      // breathing, because that is the block the press will take.
      final act = active;
      if (act != null && !orrerySeated.contains(e.key)) {
        final near = (act.position - at).distance;
        if (near < 150) {
          final targeted = preview?.block == e.key;
          final k = targeted
              ? 0.85 + 0.15 * sin(_time * 4.2)
              : (1 - (near / 150)).clamp(0.0, 1.0) * 0.5;
          canvas.drawCircle(
            at + const Offset(0, 6),
            30 + (targeted ? 5 : 0),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = targeted ? 3 : 2
              ..color = (targeted ? Colors.white : _kIcePale).withValues(
                alpha: 0.7 * k,
              ),
          );
          canvas.drawCircle(
            at + const Offset(0, 6),
            38 + (targeted ? 6 : 0),
            Paint()
              ..color = const Color(0xFF9FE9FF).withValues(alpha: 0.10 * k),
          );
        }
      }
      _drawStarBlock(canvas, at, e.key, orrerySeated.contains(e.key));
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
  void _drawOrrerySocket(Canvas canvas, Offset p, double cell, (int, int) dir) {
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

    // WHICH WAY THE KERB OPENS. The lip is cut away on one side only — the
    // side a block running with the orbit comes in on — and the orbit's own
    // direction is scored on the floor beside it. Without this the rule is
    // invisible and the room is a guessing game.
    if (dir.$1 == 0 && dir.$2 == 0) return;
    final d = Offset(dir.$1.toDouble(), dir.$2.toDouble());
    final gate = p - d * (r + 2);
    // The gap in the kerb: erase the rim on the approach side.
    canvas.drawCircle(
      gate,
      9,
      Paint()..color = _kShaftDark.withValues(alpha: 0.95),
    );
    // And the arrow, pointing the way the sky turns here.
    final tail = gate - d * 15;
    final head = gate + d * 3;
    final wing = Offset(-d.dy, d.dx) * 7;
    final arrow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6
      ..color = _kShaftBrassLit.withValues(alpha: 0.9);
    canvas.drawLine(tail, head, arrow);
    canvas.drawLine(head, head - d * 7 + wing, arrow);
    canvas.drawLine(head, head - d * 7 - wing, arrow);
  }

  /// A star-block is a lump of FROZEN SKY, so it must not be a white box: a
  /// faceted chunk with a shadow under it, one lit face, and the star showing
  /// through from inside. Seated, it takes the sockets' brass.
  /// The floor's crank: a squat iron pedestal with a brass handle, standing
  /// off the board at the east wall. Pulled by Light, it puts every loose
  /// star-block back on its standard.
  /// THE FIGURE ALPHABET. Six little star-shapes, used wherever this planet
  /// has to say "this one and that one are the same one" — the orrery's
  /// blocks and the kerbs cut for them. Ordinary shapes on purpose: they are
  /// identity, never difficulty.
  static const List<List<Offset>> _kStarFigures = [
    [Offset(0.14, 0.18), Offset(0.52, 0.42), Offset(0.24, 0.84)],
    [
      Offset(0.10, 0.30),
      Offset(0.32, 0.66),
      Offset(0.52, 0.26),
      Offset(0.76, 0.64),
      Offset(0.92, 0.22),
    ],
    [
      Offset(0.12, 0.72),
      Offset(0.40, 0.78),
      Offset(0.66, 0.60),
      Offset(0.84, 0.24),
    ],
    [
      Offset(0.50, 0.10),
      Offset(0.50, 0.86),
      Offset(0.16, 0.48),
      Offset(0.86, 0.48),
    ],
    [
      Offset(0.18, 0.80),
      Offset(0.22, 0.44),
      Offset(0.50, 0.18),
      Offset(0.82, 0.36),
    ],
    [
      Offset(0.46, 0.12),
      Offset(0.80, 0.46),
      Offset(0.48, 0.88),
      Offset(0.16, 0.48),
    ],
  ];

  /// Figure [f] drawn to fill [box].
  void _drawStarFigure(
    Canvas canvas,
    Rect box,
    int f,
    Color color,
    double stroke,
  ) {
    final n = f % _kStarFigures.length;
    final pts = [
      for (final q in _kStarFigures[n])
        Offset(box.left + q.dx * box.width, box.top + q.dy * box.height),
    ];
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: (color.a * 0.75).clamp(0.0, 1.0));
    final path = Path();
    if (n == 3) {
      path
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..moveTo(pts[2].dx, pts[2].dy)
        ..lineTo(pts[3].dx, pts[3].dy);
    } else {
      path.moveTo(pts.first.dx, pts.first.dy);
      for (final q in pts.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      if (n == 5) path.close();
    }
    canvas.drawPath(path, line);
    for (final q in pts) {
      canvas.drawCircle(q, stroke * 1.4, Paint()..color = color);
    }
  }

  void _drawOrreryCrank(Canvas canvas, Offset p) {
    canvas.drawOval(
      Rect.fromCenter(center: p + const Offset(0, 26), width: 62, height: 18),
      Paint()..color = _kShaftDark.withValues(alpha: 0.4),
    );
    canvas.drawPath(
      Path()
        ..moveTo(p.dx - 22, p.dy + 26)
        ..lineTo(p.dx - 14, p.dy - 10)
        ..lineTo(p.dx + 14, p.dy - 10)
        ..lineTo(p.dx + 22, p.dy + 26)
        ..close(),
      Paint()..color = _kShaftStone.withValues(alpha: 0.95),
    );
    canvas.drawLine(
      Offset(p.dx - 14, p.dy - 10),
      Offset(p.dx + 14, p.dy - 10),
      Paint()
        ..color = _kShaftStoneLit.withValues(alpha: 0.7)
        ..strokeWidth = 2,
    );
    final handle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.5
      ..color = _kShaftBrassLit.withValues(alpha: 0.95);
    canvas.drawLine(Offset(p.dx, p.dy - 10), Offset(p.dx, p.dy - 34), handle);
    canvas.drawLine(
      Offset(p.dx, p.dy - 34),
      Offset(p.dx + 20, p.dy - 42),
      handle,
    );
    canvas.drawCircle(
      Offset(p.dx + 20, p.dy - 42),
      5,
      Paint()..color = _kShaftBrassLit,
    );
  }

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
    // THE BLOCK'S OWN FIGURE — the same one cut into the kerb it belongs to.
    // Every block used to carry the same generic star, so "which socket is
    // this one's" was unanswerable by looking.
    _drawStarFigure(
      canvas,
      Rect.fromCenter(center: p + const Offset(0, 1), width: 26, height: 26),
      id,
      (seated ? _kShaftDark : _kIceDeep).withValues(alpha: 0.9),
      1.7,
    );
  }

  void _renderMirrorRing(Canvas canvas, DungeonRoom room) {
    final ring = room.rime?.mirrors;
    if (ring == null) return;
    final ground = _shaftGround(room);

    // THE POOL. It is a MIRROR: the chart of the ceiling this gallery exists
    // to read, and the two walls of the shaft converging away above. It used
    // to also carry a cyan glow for the vault ledge ("visible only in a
    // mirror"); that went on 2026-09-20 — played, it read as an unexplained
    // blue star, and with the ledge chute a ramp every time the vault needs
    // no tell.
    final pool = ring.radius - 34;
    canvas.drawCircle(
      ring.center,
      pool,
      Paint()..color = const Color(0xFF060F16).withValues(alpha: 0.86),
    );
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: ring.center, radius: pool)),
    );
    for (final s in ground.reflection) {
      canvas.drawPath(s.path, s.paint);
    }
    // THE SHAFT ABOVE, AS THE WATER SEES IT. Snow and cut steps are dull;
    // a shaft ridden to bare ice is a mirror, and the reflected mouth of it
    // goes pale with sky — the one wordless tell that the stranger can be
    // read here at all.
    if (shaftAboveIsMirror) {
      final c = ring.center;
      final sky = Path()
        ..moveTo(c.dx - 40, c.dy - 190)
        ..lineTo(c.dx + 62, c.dy - 190)
        ..lineTo(c.dx + 40, c.dy - 96)
        ..lineTo(c.dx - 18, c.dy - 96)
        ..close();
      canvas.drawPath(sky, Paint()..color = _kIcePale.withValues(alpha: 0.24));
      // The bare walls themselves, catching light all the way up.
      canvas.drawLine(
        Offset(c.dx - 40, c.dy - 190),
        Offset(c.dx - 18, c.dy - 96),
        Paint()
          ..strokeWidth = 2.6
          ..color = _kIceWhite.withValues(alpha: 0.5),
      );
      canvas.drawLine(
        Offset(c.dx + 62, c.dy - 190),
        Offset(c.dx + 40, c.dy - 96),
        Paint()
          ..strokeWidth = 2.6
          ..color = _kIceWhite.withValues(alpha: 0.5),
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

    // THE CHART, AS FAR AS THE WATER HAS IT. Every silvered frame draws its
    // own five stars and the strokes between them; where two frames disagree
    // about where a star hangs, BOTH are drawn and the line forks. A fork is
    // the whole evidence of this room and it names a pair, never a frame.
    final a = active;
    if (lodestoneLit && a != null && mirrorChart.isNotEmpty) {
      canvas.drawCircle(
        ring.center,
        pool,
        Paint()..color = const Color(0xFF040A10).withValues(alpha: 0.55),
      );
      Offset star(int i, int k) {
        final ang = -pi / 2 + (2 * pi * k) / kIceChartStars;
        final rad = chartRadiusFor(i, k) * pool;
        return ring.center + Offset(cos(ang) * rad, sin(ang) * rad);
      }

      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.2;
      for (final f in silveredFrames) {
        final own = chartStarsOf(f);
        for (var n = 0; n < own.length - 1; n++) {
          final k = own[n], k2 = own[n + 1];
          // THE LAMP'S REACH EASES. A stretch of chart comes up and goes down
          // as the light walks instead of snapping on and off at a hard edge.
          final lit = min(chartStarLight(ring, k), chartStarLight(ring, k2));
          if (lit <= 0.01) continue;
          final agreed = chartStarAgreed(k) && chartStarAgreed(k2);
          line.color = (agreed ? _kIceWhite : _kIcePale).withValues(
            alpha: (agreed ? 0.9 : 0.75) * lit,
          );
          canvas.drawLine(star(f, k), star(f, k2), line);
        }
        for (final k in own) {
          final lit = chartStarLight(ring, k);
          if (lit <= 0.01) continue;
          final agreed = chartStarAgreed(k);
          canvas.drawCircle(
            star(f, k),
            agreed ? 3.4 : 4.2,
            Paint()
              ..color = (agreed ? Colors.white : _kShaftBrassLit).withValues(
                alpha: 0.95 * lit,
              ),
          );
        }
      }
    }

    // THE STRANGER. Out past the chart's band, on one frame's bearing, and
    // nothing like a chart star: warm where they are cold, flared where they
    // are points, and breathing. It is only ever here when the shaft above
    // is bare ice and the water is reading that way (`strangerLight`).
    final stranger = lodestoneLit ? strangerLight(ring) : 0.0;
    if (stranger > 0.01) {
      final ang = -pi / 2 + (2 * pi * strangerFrame) / ring.count;
      final p = ring.center + Offset(cos(ang), sin(ang)) * (pool * 0.90);
      final breath = 0.5 + 0.5 * sin(_time * 2.1);
      // A spiked bloom, not a blur (the planet's rule): sixteen points.
      final bloom = Path();
      for (var i = 0; i < 16; i++) {
        final a2 = i * pi / 8;
        final r = i.isEven ? 22.0 + breath * 5 : 8.0;
        final q = p + Offset(cos(a2), sin(a2)) * r;
        if (i == 0) {
          bloom.moveTo(q.dx, q.dy);
        } else {
          bloom.lineTo(q.dx, q.dy);
        }
      }
      bloom.close();
      canvas.drawPath(
        bloom,
        Paint()
          ..color = const Color(
            0xFFFFE9B0,
          ).withValues(alpha: (0.30 + breath * 0.12) * stranger),
      );
      // Four long rays, so it reads as the brightest thing in the water.
      final ray = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.2
        ..color = const Color(0xFFFFF3CC).withValues(alpha: 0.8 * stranger);
      for (var i = 0; i < 4; i++) {
        final a2 = i * pi / 2 + pi / 4;
        canvas.drawLine(
          p + Offset(cos(a2), sin(a2)) * 8,
          p + Offset(cos(a2), sin(a2)) * (36 + breath * 8),
          ray,
        );
      }
      canvas.drawCircle(
        p,
        9,
        Paint()
          ..color = const Color(0xFFFFE9B0).withValues(alpha: 0.55 * stranger),
      );
      canvas.drawCircle(
        p,
        5.6,
        Paint()..color = Colors.white.withValues(alpha: 0.97 * stranger),
      );
    }

    // THE LIGHT-UP. The Mirror Star is a PICTURE you assembled out of
    // twelve frames and a walked lamp, and it was banked with a line of
    // prose and nothing else. A cold fire runs once round the ring, each
    // star taking it as the sweep reaches it, and the whole chart holds
    // bright behind it — the only moment in this room where the water
    // shows everything without being asked.
    if (chartTriumph > 0) {
      final t = 1 - (chartTriumph / _kChartTriumphSeconds);
      final sweep =
          -pi / 2 +
          2 * pi * Curves.easeInOutCubic.transform((t / 0.72).clamp(0.0, 1.0));
      for (var k = 0; k < kIceChartStars; k++) {
        final ang = -pi / 2 + (2 * pi * k) / kIceChartStars;
        var passed = (sweep - ang) % (2 * pi);
        if (passed < 0) passed += 2 * pi;
        if (passed > pi * 1.98) continue; // not reached yet
        // Each star flares as the fire arrives and settles to a hold.
        final age = (passed / (pi * 0.5)).clamp(0.0, 1.0);
        final flare = (1 - age) * (1 - age);
        final p =
            ring.center +
            Offset(
              cos(ang) * mirrorChart[k] * pool,
              sin(ang) * mirrorChart[k] * pool,
            );
        canvas.drawCircle(
          p,
          4 + flare * 13,
          Paint()
            ..color = const Color(
              0xFFBFF3FF,
            ).withValues(alpha: 0.10 + flare * 0.5),
        );
        canvas.drawCircle(
          p,
          3.2,
          Paint()..color = Colors.white.withValues(alpha: 0.75 + 0.25 * flare),
        );
      }
      // The fire itself, running the rim of the water.
      if (t < 0.74) {
        canvas.drawArc(
          Rect.fromCircle(center: ring.center, radius: pool * 0.92),
          sweep - 0.34,
          0.34,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 3.4
            ..color = const Color(0xFFDFF6FF).withValues(alpha: 0.85),
        );
      }
      // And one slow ring outward as it closes.
      if (t > 0.7) {
        final k = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
        canvas.drawCircle(
          ring.center,
          pool * (0.2 + k * 0.95),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * (1 - k)
            ..color = const Color(0xFFDFF6FF).withValues(alpha: 0.55 * (1 - k)),
        );
      }
    }

    for (var i = 0; i < ring.count; i++) {
      final p = ring.frameAt(i);
      final lode = i == ring.lodestoneIndex;
      // Sized so the etched figure survives the SURVEY (0.62 zoom): the ring
      // is compared by standing still and looking at the whole room, and a
      // glyph you cannot resolve from there is not a clue.
      final frame = Rect.fromCenter(center: p, width: 54, height: 76);
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
      // WHAT A FRAME SHOWS, and it is two different things at once:
      //  · its ENGRAVING, cut into the stone plate under the glass, which is
      //    its claim about the sky and is legible from anywhere in the room;
      //  · its GLASS, which is black until the water has shown you the sky
      //    over it, then holds that sky — and which you SILVER to call the
      //    frame a liar.
      final glass = frame.deflate(4);
      if (lode) {
        canvas.drawRect(
          glass,
          Paint()
            ..color = (lodestoneLit ? const Color(0xFFFFF0C4) : Colors.black)
                .withValues(alpha: lodestoneLit ? 0.82 : 0.9),
        );
        if (lodestoneLit) {
          // A LAMP, NOT A CLUE. It used to hold two figures side by side as a
          // worked example of the rule, and a frame carrying figures in a
          // room whose whole puzzle is figures reads as DATA — the player
          // hunts for what it means, and it means nothing. It is the thing
          // that lights the water and it looks like it: a warm face, a glow,
          // no chart, and no engraved plate under it either.
          canvas.drawCircle(
            glass.center,
            glass.width * 0.32,
            Paint()..color = const Color(0xFFFFF6DA).withValues(alpha: 0.95),
          );
          for (var k = 3; k >= 1; k--) {
            canvas.drawCircle(
              glass.center,
              glass.width * (0.32 + k * 0.1),
              Paint()..color = const Color(0xFFFFE9A8).withValues(alpha: 0.10),
            );
          }
        }
      } else {
        // A FRAME IS A SWITCH NOW, not a second place to read the chart: it
        // is either throwing its stretch into the water or it is not. The
        // reading all happens in the pool, which is where this room's one
        // idea lives.
        final silvered = silveredFrames.contains(i);
        canvas.drawRect(
          glass,
          Paint()
            ..color = (silvered ? _kIceWhite : const Color(0xFF0A1A22))
                .withValues(alpha: silvered ? 0.88 : 0.9),
        );
        if (silvered) {
          // Frost, and the cold running off it toward the water.
          canvas.drawRect(
            glass,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.white.withValues(alpha: 0.9),
          );
          for (var n = 0; n < 3; n++) {
            final y = glass.top + glass.height * (n + 1) / 4;
            canvas.drawLine(
              Offset(glass.left + 5, y),
              Offset(glass.right - 5, y - 4),
              Paint()
                ..strokeWidth = 1.3
                ..color = _kIcePale.withValues(alpha: 0.55),
            );
          }
        } else {
          // Dark glass still catches the room: one cold slash, no picture.
          canvas.drawLine(
            glass.topLeft + const Offset(4, 18),
            glass.topRight + const Offset(-6, 40),
            Paint()
              ..color = _kIcePale.withValues(alpha: 0.18)
              ..strokeWidth = 2,
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

    if (ice.iceCap != null) {
      // One plate per hole, and each is drunk on its own.
      for (final m in _iceMouths(room.id)) {
        if (!_capMelted(m.$1)) _drawBlackIce(canvas, m.$2);
      }
    }
    final fall = ice.rimefall;
    if (fall != null) _drawRimefall(canvas, fall);

    final font = ice.coldFont;
    if (font != null) {
      _drawColdFont(canvas, font, (conduitEnergy['B'] ?? 0) > 0);
    }

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
        final x =
            r.center.dx +
            (r.left + 16 + i * 14.0 - r.center.dx) * (1 + t * 0.5);
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
        Paint()
          ..color = (i.isEven ? _kShaftStone : _kShaftStoneLit).withValues(
            alpha: 0.55 + i * 0.1,
          ),
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
    if (!whole) {
      // A SHATTERED PILLAR IS STILL THE LOUDEST THING IN THIS ROOM. It used
      // to be five 16px stumps in wall-colour, which in a dark hollow is a
      // smudge — and it is the only thing in the boss room you can press.
      // What stands in for it: the socket it grew out of, lit; the broken
      // shafts, bright, with their fracture faces showing; and the GHOST of
      // the pillar that belongs here, so the room says what it is missing.
      final ghost = Path()
        ..moveTo(p.dx - 34, p.dy + 48)
        ..lineTo(p.dx - 16, p.dy - 62)
        ..lineTo(p.dx + 10, p.dy - 74)
        ..lineTo(p.dx + 30, p.dy + 48)
        ..close();
      canvas.drawPath(
        ghost,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _kIceWhite.withValues(alpha: 0.26),
      );
      canvas.drawOval(
        Rect.fromCenter(center: p + const Offset(0, 46), width: 78, height: 22),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _kIceWhite.withValues(alpha: 0.5),
      );
    }
    for (var i = 0; i < 5; i++) {
      final h = whole ? heights[i] : 44.0 + (i % 3) * 12;
      final x = p.dx + offsets[i] * (whole ? 1.0 : 1.35);
      final w = whole ? 12.0 + (i % 3) * 4 : 17.0;
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
              : _kIcePale.withValues(alpha: 0.82 - (i % 3) * 0.1),
      );
      if (!whole) {
        // The fracture face: where the shaft was taken off, catching light.
        canvas.drawLine(
          Offset(x - w, p.dy + 48 - h),
          Offset(x + w * 0.5, p.dy + 48 - h * 0.86),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.85)
            ..strokeWidth = 2.4,
        );
      }
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
    canvas.drawCircle(p + const Offset(0, 4), 9, Paint()..color = _kShaftBrass);
    final axis = p + const Offset(0, 4);
    final ring = _mirrorRingRoom?.rime?.mirrors;
    final notches = ring?.count ?? 12;

    // THE AZIMUTH RING, cut into the floor round the mount: twelve notches,
    // one for each frame's bearing on the gallery below, and the one the
    // tube is set to lit. The instrument's whole question is WHICH WAY, so
    // the graduations are laid flat where the tube's direction can be read
    // against them (the old declination arc graded an angle nothing here
    // ever changes).
    const ringR = 46.0;
    canvas.drawOval(
      Rect.fromCenter(center: axis, width: ringR * 2, height: ringR * 1.44),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = _kShaftBrassLit.withValues(alpha: 0.7),
    );
    final ticks = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < notches; i++) {
      final a = -pi / 2 + (2 * pi * i) / notches;
      final set = i == telescopeNotch;
      ticks.color = (set ? _kIceWhite : _kShaftBrassLit).withValues(
        alpha: set ? 0.95 : 0.6,
      );
      final out = Offset(cos(a) * ringR, sin(a) * ringR * 0.72);
      final inn = Offset(
        cos(a) * (ringR - (set ? 12 : 6)),
        sin(a) * (ringR - (set ? 12 : 6)) * 0.72,
      );
      canvas.drawLine(axis + out, axis + inn, ticks);
    }

    // THE TUBE, swung to the notch. It eases through its last turn so the
    // press is seen to do something, and the board is already at the new
    // notch underneath (nothing can desync off the drawing).
    final to = -pi / 2 + (2 * pi * telescopeNotch) / notches;
    final from = -pi / 2 + (2 * pi * (telescopeNotch - 1)) / notches;
    final ease = Curves.easeOutCubic.transform(1 - telescopeSwing);
    final ang = from + (to - from) * ease;
    Offset along(double d) => axis + Offset(cos(ang) * d, sin(ang) * d * 0.72);
    Offset across(double d, double w) {
      final n = Offset(-sin(ang), cos(ang) * 0.72);
      return along(d) + n * w;
    }

    // Raised off the mount: the tube stands a little above the floor's
    // ring, so it reads as an instrument on a tripod and not as a pointer
    // painted on the ground.
    const lift = Offset(0, -14);
    final tube = Path()
      ..moveTo(across(-30, 7).dx + lift.dx, across(-30, 7).dy + lift.dy)
      ..lineTo(across(54, 10).dx + lift.dx, across(54, 10).dy + lift.dy)
      ..lineTo(across(54, -10).dx + lift.dx, across(54, -10).dy + lift.dy)
      ..lineTo(across(-30, -7).dx + lift.dx, across(-30, -7).dy + lift.dy)
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
    final eye = along(54) + lift;
    canvas.drawCircle(eye, 11, Paint()..color = const Color(0xFF0B2733));
    canvas.drawCircle(
      eye,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _kIcePale.withValues(alpha: 0.7),
    );
    // A brass pointer from the axis to the set notch, so the tube and the
    // ring agree to the eye even mid-swing.
    canvas.drawLine(
      axis,
      axis + Offset(cos(to) * (ringR - 4), sin(to) * (ringR - 4) * 0.72),
      Paint()
        ..strokeWidth = 1.2
        ..color = _kIceWhite.withValues(alpha: 0.35),
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
      pts.add(
        c + Offset(x * cos(rot) - y * sin(rot), x * sin(rot) + y * cos(rot)),
      );
    }
    g.fill(_shaftPoly(pts), _kShaftMilk.withValues(alpha: 0.07));
    g.stroke(
      Path()..addArc(
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
      return (
        Offset(rnd.range(b.left, b.right), b.top + rnd.range(4, band)),
        0,
      );
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
      return (
        Offset(b.left + rnd.range(4, band), rnd.range(b.top, b.bottom)),
        3,
      );
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
    final q =
        c + Offset(x * cos(rot) - y * sin(rot), x * sin(rot) + y * cos(rot));
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
  g.stroke(
    lines,
    _kShaftIce.withValues(alpha: alpha * 0.45),
    1.0,
    layer: layer,
  );
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
      _groundStarFont(g, b, rnd, room.rime!.roof!);
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
      Offset(
        rnd.range(b.left + 16, b.right - 16),
        rnd.range(b.top + 16, b.bottom - 16),
      ),
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
  _shaftArc(
    g,
    q,
    62,
    -pi + 0.1,
    pi / 2 - 0.2,
    ticks: 18,
    width: 2.4,
    color: _kShaftBrassLit,
    alpha: 0.6,
  );
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
      ..arcTo(
        Rect.fromCircle(center: ring.center, radius: pr),
        k,
        k1 - k,
        false,
      )
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

/// THE STAR FONT — THE ROOF OF THE HOLLOW. Two stone shores, a glacier rim
/// either side, and between them the roof: a field of snow over panes of
/// ice, the seams of the panes just showing through, and the font's pier
/// standing up out of it. Everything a pane SHOWS is drawn live by
/// `_renderRoof`; this is only what never changes.
void _groundStarFont(_ShaftGround g, Rect b, _ShaftRnd rnd, IceRoof roof) {
  final field = roof.bounds;
  _shaftFoliation(g, b, rnd, 0.16);

  // THE SHORES: stone, the near one under the sump's door and the far one
  // where the hollow's own way up comes out.
  for (final shore in [
    Rect.fromLTRB(b.left, b.top, b.right, field.top),
    Rect.fromLTRB(b.left, field.bottom, b.right, b.bottom),
  ]) {
    g.fill(Path()..addRect(shore), _kShaftStone.withValues(alpha: 0.55));
    final courses = Path();
    for (var i = 0; i < 5; i++) {
      final y = shore.top + rnd.range(8, shore.height - 8);
      courses
        ..moveTo(shore.left + rnd.range(10, 60), y)
        ..lineTo(shore.right - rnd.range(10, 60), y + rnd.range(-3, 3));
    }
    g.stroke(courses, _kShaftDark.withValues(alpha: 0.28), 1.3);
  }
  // Their kerbs, along the roof's edge, lit where they meet the snow.
  g.stroke(
    Path()
      ..moveTo(field.left, field.top)
      ..lineTo(field.right, field.top)
      ..moveTo(field.left, field.bottom)
      ..lineTo(field.right, field.bottom),
    _kShaftStoneLit.withValues(alpha: 0.7),
    3.0,
  );

  // THE RIMS: the glacier coming down to the roof's edge either side.
  for (final rim in [
    Rect.fromLTRB(b.left, field.top, field.left, field.bottom),
    Rect.fromLTRB(field.right, field.top, b.right, field.bottom),
  ]) {
    g.fill(Path()..addRect(rim), _kShaftGlacier.withValues(alpha: 0.7));
    final lit = Path();
    final x = rim.left < field.left ? rim.right - 2 : rim.left + 2;
    lit
      ..moveTo(x, rim.top)
      ..lineTo(x, rim.bottom);
    g.stroke(lit, _kShaftIce.withValues(alpha: 0.6), 2.0);
  }

  // THE SNOW FIELD. One sheet, drifted, with the pane seams under it — the
  // seams are what let the roof be reasoned about as panes at all.
  g.fill(Path()..addRect(field), _kShaftMilk.withValues(alpha: 0.26));
  final drifts = Path();
  for (var i = 0; i < 22; i++) {
    drifts.addOval(
      Rect.fromCenter(
        center: Offset(
          rnd.range(field.left + 20, field.right - 20),
          rnd.range(field.top + 14, field.bottom - 14),
        ),
        width: rnd.range(40, 120),
        height: rnd.range(14, 34),
      ),
    );
  }
  g.fill(drifts, _kShaftMilk.withValues(alpha: 0.12));
  final seams = Path();
  for (var c = 1; c < roof.cols; c++) {
    final x = field.left + c * roof.cell;
    seams
      ..moveTo(x, field.top)
      ..lineTo(x, field.bottom);
  }
  for (var r = 1; r < roof.rows; r++) {
    final y = field.top + r * roof.cell;
    seams
      ..moveTo(field.left, y)
      ..lineTo(field.right, y);
  }
  g.stroke(seams, _kShaftDark.withValues(alpha: 0.2), 1.2);
  _shaftCraze(g, field, rnd, 5, 0.1);

  // THE PIER: the one thing standing up out of the snow. A block, top face
  // and near face, the bright line along the edge where they meet (§7.10).
  final pier = roof.rectOf(roof.pierCell).deflate(8);
  g.fill(
    Path()..addOval(
      Rect.fromCenter(
        center: pier.bottomCenter + const Offset(0, 4),
        width: pier.width + 16,
        height: 18,
      ),
    ),
    _kShaftDark.withValues(alpha: 0.32),
  );
  g.fill(
    Path()..addRect(
      Rect.fromLTRB(pier.left, pier.center.dy, pier.right, pier.bottom),
    ),
    _kShaftStone.withValues(alpha: 0.9),
  );
  g.fill(
    Path()
      ..moveTo(pier.left, pier.center.dy)
      ..lineTo(pier.left + 8, pier.top)
      ..lineTo(pier.right - 8, pier.top)
      ..lineTo(pier.right, pier.center.dy)
      ..close(),
    _kShaftStoneLit.withValues(alpha: 0.85),
  );
  g.stroke(
    Path()
      ..moveTo(pier.left, pier.center.dy)
      ..lineTo(pier.right, pier.center.dy),
    _kShaftMilk.withValues(alpha: 0.6),
    2.0,
  );

  // The chart this font answers to, cut into the near shore.
  _shaftStarfield(
    g,
    Rect.fromLTRB(b.left + 60, b.top + 30, b.right - 60, field.top - 20),
    rnd,
    16,
    _ShaftLayer.base,
    0.3,
  );
  _shaftIcicles(g, b.deflate(10), rnd, n: 11, maxLen: 30);
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
    scour.addArc(
      Rect.fromCircle(center: c, radius: r),
      a0,
      rnd.range(0.5, 1.4),
    );
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
    column(
      b.right - rnd.range(14, 56),
      y,
      rnd.range(12, 26),
      rnd.range(50, 92),
    );
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
void _groundShelf(
  _ShaftGround g,
  Rect b,
  _ShaftRnd rnd, {
  required bool vault,
}) {
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
    ..addRect(
      Rect.fromLTRB(b.left + 10, b.bottom - 40, b.right - 10, b.bottom),
    );
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
      ..arcToPoint(
        Offset(n.dx + 62, n.dy - 16),
        radius: const Radius.circular(62),
      )
      ..lineTo(n.dx + 62, n.dy + 62)
      ..close();
    g.fill(arch, _kShaftDark.withValues(alpha: 0.6));
    g.stroke(arch, _kShaftStoneLit.withValues(alpha: 0.45), 3.0);
    g.fill(
      Path()..addOval(
        Rect.fromCenter(
          center: n + const Offset(0, 58),
          width: 118,
          height: 26,
        ),
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
      g.fill(
        Path()..addRect(r),
        const Color(0xFF3B3222).withValues(alpha: 0.7),
      );
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
      g.fill(
        Path()..addRect(r),
        const Color(0xFF3B3222).withValues(alpha: 0.75),
      );
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
