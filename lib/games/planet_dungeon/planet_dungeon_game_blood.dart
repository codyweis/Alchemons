// lib/games/planet_dungeon/planet_dungeon_game_blood.dart
//
// HEMAVORN — THE BLOOD RITES. Blood's play, as a `part of
// planet_dungeon_game.dart`. The rules are planet_dungeon_blood_rites.dart
// (pure, proved against the prototype); the rooms are
// planet_dungeon_layout_blood.dart; the drawing is
// planet_dungeon_game_blood_art.dart. This file turns a joystick and one pad
// button into the rules' sentences:
//
//   · EARTH — walk to a root and press LEAD: the tendril follows you, square
//     by square; walk back over it and it comes back in; walk into its
//     partner and it joins. Press LET GO to leave it lying. TURN, standing
//     on a plate or beside its axle, turns the plate a quarter (and you with
//     it). Dust and Water both led to the captive frees it.
//   · WATER — walk; every square you step on, the room settles. FLIP turns
//     it over. Step into a flooded pit and you dive (the vault).
//   · FIRE  — walk; the twin takes the mirrored step. Pressing into a wall
//     you cannot pass still steps the twin (once per press-and-hold beat).
//   · AIR   — push the stick and Blood drifts until stopped; push again into
//     ice beside you and the ice drifts instead. Let the stick go between
//     pushes.
//   · THE CIRCLE — walk the round floor; TURN on a ring's band turns that
//     ring an eighth. Freed blood fills its cup unless both rings carry it
//     to the middle; all four in the middle is the quintessence.
//   · SANGUORATH — the four come down with Blood and the player controls all
//     five. At 80/60/40/20% it shells; the shell shows an element, and the
//     OPPOSITE ally walked into it gives itself. The wrong one is thrown
//     back and the boss heals a little. The last fifth is Blood alone.
//
// RESTART: the regroup button, in a captive room, starts that room again
// with Blood at its door — the honest undo, and the way out of a dead end.
//
// Nothing here is timed and nothing is chance; the shell's element is rolled
// per fight, but bringing the right ally always works.

part of 'planet_dungeon_game.dart';

/// The release and sacrifice read a body out of a square this many world
/// units across, at this many pixels per unit.
const double kRiteSnapBox = 96, kRiteSnapRatio = 3;

/// Captives are drawn this much larger than the party (they are the room's
/// subject, and their release has to read).
const double kRiteCaptiveScale = 1.35;

/// Seconds one pass of a Water settle takes on screen.
const double kRiteWaterPass = 0.075;

/// Everything the Blood Rites track for one run, plus the clocks the render
/// reads.
class BloodRun {
  BloodRun() {
    resetRooms();
  }

  // ── The four rooms (the rules' rooms never change; their states do) ──
  final TendrilFloor earthFloor = TendrilFloor(kRiteEarthMap);
  final FlipRoom waterRoom = FlipRoom(kRiteWaterMap);
  final TwinRoom fireRoom = TwinRoom(kRiteFireMap);
  final DriftRoom airRoom = DriftRoom(kRiteAirMap, need: kRiteAirNeed);

  late TendrilState earth;
  late FlipState water;
  late TwinState fire;
  late DriftState air;

  /// Blood's square in the Earth room (the other rooms' states carry it).
  RiteCell earthAt = kRiteArrival['Earth']!;

  /// The tendril Blood is leading, if any.
  String? leading;

  /// The plates' eased angles (radians), for the render.
  List<double> plateAng = [0, 0];

  // Water: a settle being played back, a pass at a time.
  List<FlipFrame> waterFrames = [];
  double waterFrameT = 0;
  double flipT = 1; // 0..1 while the room turns over

  /// The frame a settle is leaving (the render slides from it to the next).
  FlipFrame? waterFrom;

  /// When something last happened on a square, keyed 'x,y' — a melt, a fire
  /// put out, a basin square filling, a pit taking something. The render
  /// plays each moment from it.
  final Map<String, double> meltT = {}, douseT = {}, basinT = {}, pitT = {};

  /// The Water and Air rooms' finishable states (built on first entry).
  Set<String>? waterLive, airLive;
  bool deadSpoken = false;

  // ── The moments (blood_rite_fx.dart) ──
  final RiteGrainField grains = RiteGrainField();
  final RiteGrainBatch batch = RiteGrainBatch();
  RiteReleaseFx? release;
  String? releaseEl;
  RiteSacrificeFx? sacrifice;
  DungeonCreature? sacrificed;

  /// The shell shedding while a sacrifice plays (its element).
  String? shedElement;

  /// When each cup filled (the render pours it), and when the seal opened.
  final Map<String, double> cupT = {};

  /// When the seal opened: −1 not yet, −99 open before this run began.
  double sealT = -1;

  /// The Fire room's gates as SHOWN: 0 shut, 1 open (eased).
  final Map<String, double> gateShown = {};
  double puffT = 0;

  // Fire: the twin's eased position, and the bump clock.
  Offset twinShown = Offset.zero;
  double bumpCooldown = 0;

  // Air: a drift being played back.
  List<RiteCell> driftPath = const [];
  List<RiteCell> icePath = const [];
  RiteCell? iceMelted;
  bool iceIntoBell = false;
  double driftT = 1;
  bool stickArmed = true;

  // ── The Circle ──
  int outerTurn = 0, innerTurn = 0;
  double outerAng = 0, innerAng = 0;
  final Set<String> cups = {};
  String? lastCentre;
  double centreT = -9;

  /// When each captive was freed this run (the dissolve plays from it).
  final Map<String, double> freedT = {};

  // ── Sanguorath ──
  /// Breaks done (0..4); the shell up now, and its element.
  int shellsBroken = 0;
  bool shellUp = false;
  String? shellElement;
  double shellT = -9;

  /// Allies waiting to come down (built at load), and those given.
  final List<DungeonCreature> allies = [];
  final Set<String> given = {};
  bool alliesDown = false;
  final Map<String, double> refusedT = {};

  void resetRooms() {
    waterFrom = null;
    meltT.clear();
    douseT.clear();
    basinT.clear();
    pitT.clear();
    grains.clear();
    earth = TendrilState.start(earthFloor);
    water = flipStart(waterRoom);
    fire = twinStart(fireRoom);
    air = driftStart(airRoom);
    earthAt = kRiteArrival['Earth']!;
    leading = null;
    waterFrames = [];
    flipT = 1;
    driftT = 1;
    driftPath = const [];
    icePath = const [];
    deadSpoken = false;
  }

  void resetRoom(String element) {
    switch (element) {
      case 'Earth':
        earth = TendrilState.start(earthFloor);
        earthAt = kRiteArrival['Earth']!;
        leading = null;
      case 'Water':
        water = flipStart(waterRoom);
        waterFrames = [];
        flipT = 1;
      case 'Fire':
        fire = twinStart(fireRoom);
      case 'Air':
        air = driftStart(airRoom);
        driftT = 1;
        driftPath = const [];
        icePath = const [];
    }
    deadSpoken = false;
  }

  void resetFight() {
    sacrifice = null;
    sacrificed = null;
    shedElement = null;
    shellsBroken = 0;
    shellUp = false;
    shellElement = null;
    given.clear();
    refusedT.clear();
    alliesDown = false;
  }
}

extension BloodRitesDungeon on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetRitesState() {
    if (!_isRites) return;
    rites.resetRooms();
    rites.resetFight();
    rites.cups.clear();
    rites.outerTurn = rites.innerTurn = 0;
    rites.outerAng = rites.innerAng = 0;
    _riteSyncCups();
    // What was already done when the run began is simply there: no pour.
    for (final el in rites.cups) {
      rites.cupT[el] = -99;
    }
    rites.sealT = rites.cups.length == 4 && guardianRiteUnlocked ? -99 : -1;
  }

  /// The captives freed — this run or any before (a freed captive stays
  /// freed: it is a discovery, persisted across descents).
  Set<String> get riteFreed => {
    for (final el in kRiteElements)
      if (discoveredClouds.contains(riteFreedId(el)) || hasStar(0)) el,
  };

  RiteBay? get _riteBay => currentRoom.rite;

  /// The captive room the view is in, as its element.
  String? get _riteRoomEl => _riteBay?.element;

  bool get _riteInArena => _riteBay?.kind == RiteKind.arena;

  /// Build the four allies' bodies (sprites loaded, not yet in the party).
  Future<void> _loadRiteAllies() async {
    if (!_isRites) return;
    rites.allies.clear();
    for (final el in kRiteElements) {
      final m =
          riteCaptives.where((c) => c.element == el).firstOrNull ??
          (party.isEmpty ? null : _riteStandIn(party.first, el));
      if (m == null) continue;
      final c = DungeonCreature(member: m);
      await _loadSprite(c);
      rites.allies.add(c);
    }
  }

  /// A test or a catalog without the species: Blood's own body, renamed.
  CosmicPartyMember _riteStandIn(CosmicPartyMember b, String el) =>
      CosmicPartyMember(
        instanceId: 'rite_captive_$el',
        baseId: b.baseId,
        displayName: '$el captive',
        imagePath: b.imagePath,
        element: el,
        family: b.family,
        level: b.level,
        statSpeed: b.statSpeed,
        statIntelligence: b.statIntelligence,
        statStrength: b.statStrength,
        statBeauty: b.statBeauty,
        slotIndex: -1,
        staminaBars: b.staminaBars,
        staminaMax: b.staminaMax,
        spriteSheet: b.spriteSheet,
      );

  // ── Placement ────────────────────────────────────────────

  /// Blood's square in the grid room the view is in (null elsewhere).
  RiteCell? get _riteBloodAt => switch (_riteRoomEl) {
    'Earth' => rites.earthAt,
    'Water' => rites.water.b,
    'Fire' => rites.fire.b,
    'Air' => rites.air.b,
    _ => null,
  };

  void _riteSnapBlood() {
    final at = _riteBloodAt;
    final a = active;
    if (at == null || a == null) return;
    a
      ..position = riteCentreOf(at.x, at.y)
      ..lastSafe = riteCentreOf(at.x, at.y);
  }

  /// A door into a captive room puts Blood on that room's own square: the
  /// arrival square for a fresh room, or wherever the room's state has it
  /// (rooms keep their state for the run).
  bool _ritePassThroughDoor(DungeonDoor d) {
    if (!_isRites) return false;
    rites.grains.clear();
    rites.release = null;
    rites.releaseEl = null;
    final target = layout.rooms[d.targetRoomId]!;
    final kind = target.rite?.kind;
    // Down to Sanguorath: the freed come with you.
    if (kind == RiteKind.arena) {
      _riteAlliesJoin();
      return false;
    }
    if (_riteInArena) _riteAlliesLeave();
    if (target.rite?.isGrid != true) return false;
    final el = target.rite!.element!;
    final arrive = kRiteArrival[el]!;
    // Blood comes in at the door; a room's puzzle keeps its own state, so
    // Blood's square in the rules moves to the door square (a room's state
    // never puts Blood anywhere it could not walk back from).
    switch (el) {
      case 'Earth':
        rites.leading = null;
        rites.earthAt = arrive;
      case 'Water':
        if (flipWalkable(rites.water, arrive.x, arrive.y) ||
            rites.water.b == arrive) {
          rites.water = FlipState(
            rites.water.down,
            arrive,
            rites.water.cells,
            rites.water.loose,
          );
        } else {
          rites.resetRoom('Water');
        }
        rites.waterLive ??= flipLiveStates(rites.waterRoom).live;
      case 'Fire':
        // The twin's room only makes sense from a start: a fresh pair.
        rites.fire = twinStart(rites.fireRoom);
      case 'Air':
        // Drifting has no way back to a square: the room starts again.
        rites.resetRoom('Air');
        rites.airLive ??= driftGraph(rites.airRoom).live;
    }
    rites.deadSpoken = false;
    return false; // the engine finishes the transit
  }

  /// After the engine has moved Blood into a room: put it on its square.
  void _riteAfterTransit() {
    if (!_isRites) return;
    if (_riteBay?.isGrid == true) {
      _riteSnapBlood();
      rites.twinShown = riteCentreOf(rites.fire.t.x, rites.fire.t.y);
    }
  }

  /// The regroup button: in a captive room, start that room again with
  /// Blood at its door. True when handled.
  bool _riteRegroup() {
    if (!_isRites) return false;
    final el = _riteRoomEl;
    if (el == null) return false;
    rites.resetRoom(el);
    final arrive = kRiteArrival[el]!;
    if (el == 'Earth') rites.earthAt = arrive;
    _riteSnapBlood();
    rites.twinShown = riteCentreOf(rites.fire.t.x, rites.fire.t.y);
    _clearHints();
    _setHint('The room starts again');
    onChanged();
    return true;
  }

  /// Fit the whole room on screen: every captive room and the Circle are
  /// read whole (the rings and all four cups have to be in view at once).
  bool get _riteFitsRoom =>
      _isRites && _riteBay != null && !_riteInArena && _riteBay!.kind != RiteKind.vault;

  // ── Walking ──────────────────────────────────────────────

  static const String _riteBlockPrefix = 'rite:';

  /// Does Blood's next position leave what the rules allow?
  bool _riteBlocksAt(Offset center, DungeonRoom room) {
    final bay = room.rite;
    if (bay == null) return false;
    if (bay.kind == RiteKind.circle) return _riteCircleBlocks(center);
    if (!bay.isGrid) return false;
    final a = active;
    if (a == null) return false;
    final here = _riteBloodAt!;
    final t = riteSquareAt(center);
    final dx = t.x - here.x, dy = t.y - here.y;
    if (dx == 0 && dy == 0) return false;
    if (dx.abs() + dy.abs() != 1) return true;
    final dir = dx == 1
        ? 1
        : dx == -1
        ? 3
        : dy == 1
        ? 2
        : 0;
    // A doorway square is the way out: let the engine take the door.
    if (_riteDoorSquare(room, t)) return false;
    switch (bay.element) {
      case 'Earth':
        return _riteEarthBlocks(t);
      case 'Water':
        if (rites.waterFrames.isNotEmpty || rites.flipT < 1) return true;
        if (rites.water.cells[t.y][t.x] == 'p') return false; // the dive
        return !flipWalkable(rites.water, t.x, t.y);
      case 'Fire':
        return _riteFireBlocks(dir);
      case 'Air':
        return true; // nobody walks on air
    }
    return true;
  }

  /// Is (x,y) the square of one of [room]'s wall doors?
  bool _riteDoorSquare(DungeonRoom room, RiteCell t) {
    for (final d in room.doors) {
      if (d.chromeless) continue;
      if (riteSquareAt(d.rect.center) == t) return true;
    }
    return false;
  }

  /// The round floor: stone outside the circle, but each door's mouth is
  /// open through it.
  bool _riteCircleBlocks(Offset p) {
    final r = (p - kRiteCircleCentre).distance;
    if (r <= kRiteCircleRadius - 18) return false;
    final c = kRiteCircleCentre;
    final inNS = (p.dx - c.dx).abs() < 46;
    final inEW = (p.dy - c.dy).abs() < 46;
    return !(inNS || inEW);
  }

  bool _riteEarthBlocks(RiteCell t) {
    final f = rites.earthFloor;
    final s = rites.earth;
    final g = f.grid(s.turns);
    final id = rites.leading;
    if (id != null) {
      final r = tendrilExtend(f, s, id, t.x, t.y);
      if (r.ok) {
        // The step is taken next frame, when Blood is on the square; a join
        // (walking into the partner) is taken now — nobody stands on a root.
        final pts = r.state!.lines[id];
        final job = f.jobs(g).firstWhere((j) => j.id == id);
        if (tendrilJoined(job, pts)) {
          rites.earth = r.state!;
          rites.leading = null;
          _cue(SoundCue.dungeonSwitch);
          _haptic(DungeonHaptic.success);
          _releaseBlockedExcept(_riteBlockPrefix, const {});
          if (tendrilSolved(f, rites.earth)) _riteFree('Earth');
          return true;
        }
        _releaseBlockedExcept(_riteBlockPrefix, const {});
        return false;
      }
      if (r.why != 'blocked' && r.why != 'One square at a time.') {
        _setBlockedHintOnce('$_riteBlockPrefix${t.x},${t.y}', r.why!);
      }
      return true;
    }
    if (t.y < 0 || t.y >= f.h || t.x < 0 || t.x >= f.w) return true;
    return g[t.y][t.x] != '.';
  }

  bool _riteFireBlocks(int dir) {
    final st = twinStep(rites.fireRoom, rites.fire, dir);
    if (!st.ok) return true;
    if (st.bMoved && st.pit == null) return false; // taken when Blood arrives
    // Blood can't go there, but the twin can (or someone falls): take the
    // step now, once per beat while the stick is held.
    if (rites.bumpCooldown > 0) return true;
    rites.bumpCooldown = 0.3;
    _riteFireCommit(st);
    return true;
  }

  void _riteFireCommit(TwinStepResult st) {
    rites.fire = st.state!;
    if (st.pit != null) {
      _cue(SoundCue.dungeonHazardTrigger);
      speakConsequence(
        st.pit == 'b'
            ? 'Blood fell. You both rise again at the pool'
            : 'The twin fell. You both rise again at the pool',
      );
      _riteSnapBlood();
      rites.twinShown = riteCentreOf(rites.fire.t.x, rites.fire.t.y);
    } else {
      _cue(SoundCue.dungeonStepStone);
    }
    if (twinSolved(rites.fireRoom, rites.fire)) _riteFree('Fire');
  }

  // ── The pad ──────────────────────────────────────────────

  /// What the utility button says here (null: the planet doesn't use it).
  String? get riteUtilityLabel {
    if (!_isRites) return null;
    final a = active;
    if (a == null) return null;
    final bay = _riteBay;
    if (bay == null) return null;
    switch (bay.kind) {
      case RiteKind.circle:
        return _riteRingAt(a.position) == null ? null : 'TURN';
      case RiteKind.earth:
        if (rites.leading != null) return 'LET GO';
        if (_riteEarthLeadTarget() != null) return 'LEAD';
        if (_riteEarthPlateHere() >= 0) return 'TURN';
        return null;
      case RiteKind.water:
        return 'FLIP';
      default:
        return null;
    }
  }

  bool _tryRiteVerb(DungeonCreature a) {
    if (!_isRites) return false;
    final bay = _riteBay;
    if (bay == null) return false;
    switch (bay.kind) {
      case RiteKind.circle:
        final ring = _riteRingAt(a.position);
        if (ring == null) return false;
        _riteTurnRing(ring);
        return true;
      case RiteKind.earth:
        return _riteEarthVerb();
      case RiteKind.water:
        _riteFlip();
        return true;
      default:
        return false;
    }
  }

  // ── Earth ────────────────────────────────────────────────

  /// What LEAD would take: (tendril id, the root it starts from), or the tip
  /// Blood stands on (resume).
  (String, RiteCell?)? _riteEarthLeadTarget() {
    final f = rites.earthFloor;
    final s = rites.earth;
    final at = rites.earthAt;
    // Standing on an unjoined tip: take it up again.
    final g = f.grid(s.turns);
    final jobs = f.jobs(g);
    for (final e in s.lines.entries) {
      final job = jobs.where((j) => j.id == e.key).firstOrNull;
      if (job == null || tendrilJoined(job, e.value)) continue;
      if (e.value.last == at) return (e.key, null);
    }
    // Beside a root: start its tendril from there — the one Blood faces
    // first, if two are within reach.
    final a = active;
    final facing = a == null
        ? 0
        : const [1, 2, 3, 0][((a.aimAngle / (pi / 2)).round() % 4 + 4) % 4];
    for (final d in [facing, 0, 1, 2, 3]) {
      final x = at.x + kRiteDx[d], y = at.y + kRiteDy[d];
      if (y < 0 || y >= f.h || x < 0 || x >= f.w) continue;
      final ch = g[y][x];
      if (!TendrilFloor.isRoot(ch)) continue;
      return (ch, (x: x, y: y));
    }
    return null;
  }

  /// The plate Blood stands on, or whose axle it stands beside (−1: none).
  int _riteEarthPlateHere() {
    final f = rites.earthFloor;
    final at = rites.earthAt;
    final on = f.plateOf(at.x, at.y);
    if (on >= 0) return on;
    for (var i = 0; i < f.plates.length; i++) {
      final p = f.plates[i];
      if ((p.cx - at.x).abs() + (p.cy - at.y).abs() == 1) return i;
    }
    return -1;
  }

  bool _riteEarthVerb() {
    final f = rites.earthFloor;
    if (rites.leading != null) {
      rites.leading = null;
      _cue(SoundCue.dungeonInteract);
      return true;
    }
    final lead = _riteEarthLeadTarget();
    if (lead != null) {
      final (id, root) = lead;
      if (root == null) {
        rites.leading = id;
        _cue(SoundCue.dungeonInteract);
        return true;
      }
      // A fresh tendril from this root, out onto Blood's own square.
      final cleared = rites.earth.cleared(id);
      final r = tendrilExtend(
        f,
        cleared,
        id,
        rites.earthAt.x,
        rites.earthAt.y,
        from: root,
      );
      if (!r.ok) {
        _setBlockedHint(r.why == 'Tendrils never cross.'
            ? 'Another tendril lies where you stand'
            : 'That tendril can\'t start here');
        return true;
      }
      rites.earth = r.state!;
      rites.leading = id;
      _cue(SoundCue.dungeonInteract);
      return true;
    }
    final i = _riteEarthPlateHere();
    if (i >= 0) {
      final r = tendrilTurn(f, rites.earth, i);
      if (!r.ok) {
        _setBlockedHint(r.why!);
        return true;
      }
      rites.earth = r.state!;
      // Standing on the plate, Blood turns with it.
      final p = f.plates[i];
      final at = rites.earthAt;
      if (f.plateOf(at.x, at.y) == i) {
        final dx = at.x - p.cx, dy = at.y - p.cy;
        rites.earthAt = (x: p.cx - dy, y: p.cy + dx);
        _riteSnapBlood();
      }
      _cue(SoundCue.dungeonSwitch);
      return true;
    }
    return false;
  }

  // ── Water ────────────────────────────────────────────────

  void _riteFlip() {
    if (rites.waterFrames.isNotEmpty || rites.flipT < 1) return;
    if (flipSolved(rites.water)) return;
    final before = rites.water;
    final st = flipTurn(rites.waterRoom, rites.water, frames: true);
    rites.flipT = 0;
    _cue(SoundCue.dungeonWallBreak);
    _riteWaterCommit(st, before);
  }

  /// A settle is taken now (the rules) and played back a pass at a time (the
  /// render slides each thing from square to square, and the moments — a
  /// melt, a fire put out, a basin filling — sound as the picture reaches
  /// them, in [_riteWaterPass]).
  void _riteWaterCommit(FlipStep st, FlipState before) {
    rites.waterFrom = FlipFrame(before);
    rites.waterFrames = List.of(st.frames);
    rites.waterFrameT = 0;
    rites.water = st.state!;
    if (flipSolved(rites.water)) {
      _riteFree('Water');
      return;
    }
    _riteSpeakIfDead(rites.waterLive, rites.water.key);
  }

  void _riteSpeakIfDead(Set<String>? live, String key) {
    if (live == null || riteFreed.contains(_riteRoomEl)) return;
    if (live.contains(key)) {
      rites.deadSpoken = false;
      return;
    }
    if (rites.deadSpoken) return;
    rites.deadSpoken = true;
    speakConsequence('This room can\'t be finished from here. Regroup to '
        'start it again');
  }

  // ── Air ──────────────────────────────────────────────────

  void _riteAirInput() {
    final j = joystickDirection;
    if (j.distance < 0.25) {
      rites.stickArmed = true;
      return;
    }
    if (!rites.stickArmed || rites.driftT < 1) return;
    if (j.distance < 0.6) return;
    rites.stickArmed = false;
    final d = j.dx.abs() > j.dy.abs() ? (j.dx > 0 ? 1 : 3) : (j.dy > 0 ? 2 : 0);
    final r = driftPush(rites.airRoom, rites.air, d);
    if (!r.ok) {
      // Pushing off the door's own square, out through it: leave.
      final at = rites.air.b;
      final door = currentRoom.doors.where(
        (dd) => !dd.chromeless && riteSquareAt(dd.rect.center) ==
            (x: at.x + kRiteDx[d], y: at.y + kRiteDy[d]),
      );
      if (door.isNotEmpty) {
        passThroughDoor(door.first);
        return;
      }
      if (r.why != 'blocked') _setBlockedHint(r.why!);
      return;
    }
    rites.air = r.state!;
    rites.driftPath = r.bloodPath;
    rites.icePath = r.icePath;
    rites.iceMelted = r.meltedAt;
    rites.iceIntoBell = r.intoBell;
    rites.driftT = 0;
    _cue(r.icePath.isNotEmpty ? SoundCue.dungeonBlockMove : SoundCue.dungeonStepStone);
    if (r.meltedAt != null && !r.intoBell) {
      speakConsequence('The ice turned to air in the open, and the air is '
          'gone');
    }
  }

  // ── The Circle ───────────────────────────────────────────

  /// 0 = the outer ring, 1 = the inner; null off both bands.
  int? _riteRingAt(Offset p) {
    final r = (p - kRiteCircleCentre).distance;
    if (r >= kRiteOuterBand.$1 && r <= kRiteOuterBand.$2) return 0;
    if (r >= kRiteInnerBand.$1 && r <= kRiteInnerBand.$2) return 1;
    return null;
  }

  void _riteTurnRing(int ring) {
    if (ring == 0) {
      rites.outerTurn = (rites.outerTurn + 1) % 8;
    } else {
      rites.innerTurn = (rites.innerTurn + 1) % 8;
    }
    _cue(SoundCue.dungeonSwitch);
    _riteSyncCups();
    // What the middle makes is drawn there, in grains (the Circle's art).
    onChanged();
  }

  /// Every freed stream that is NOT carried to the middle fills its cup.
  void _riteSyncCups() {
    for (final el in riteFreed) {
      if (!riteStreamToCentre(el, rites.outerTurn, rites.innerTurn)) {
        if (rites.cups.add(el)) rites.cupT[el] = _time;
      }
    }
  }

  // ── Freeing a captive ────────────────────────────────────

  void _riteFree(String el) {
    rites.freedT[el] = _time;
    final already = discoveredClouds.contains(riteFreedId(el)) || hasStar(0);
    if (already) {
      _setHint('The room is done again');
      return;
    }
    _discoverCloud(riteFreedId(el));
    _cue(SoundCue.dungeonPuzzleSolved);
    _haptic(DungeonHaptic.big);
    final (a, b) = _riteBay?.recipe ?? ('', '');
    final at = _riteCaptiveAt(el);
    // THE RELEASE: the ingredients run into the captive, its bands let go,
    // its own body comes apart into grains and runs home as blood.
    final body = RiteBody(elementColor(el));
    final ally = rites.allies.where((c) => c.member.element == el).firstOrNull;
    final img = ally == null ? null : _riteSnapshot(ally, scale: kRiteCaptiveScale);
    if (img != null) {
      body.read(img, kRiteSnapRatio);
    } else {
      body.force();
    }
    rites.release = RiteReleaseFx(
      at: at,
      exit: _riteExitOf(currentRoom),
      sources: _riteSources(el, at),
      body: body,
    );
    rites.releaseEl = el;
    speakConsequence('$a and $b meet. $el is freed, and its blood runs to '
        'the Circle');
    _riteSyncCups();
    if (riteFreed.length == 4) {
      if (!hasStar(0)) earnStar(0);
      if (!hasStar(1)) earnStar(1);
    }
    onChanged();
  }

  /// Where a room's captive lies (world units).
  Offset _riteCaptiveAt(String el) {
    switch (el) {
      case 'Earth':
        final g = rites.earthFloor.grid(rites.earth.turns);
        for (var y = 0; y < g.length; y++) {
          for (var x = 0; x < g[y].length; x++) {
            if (g[y][x] == 'C') return riteCentreOf(x, y);
          }
        }
      case 'Water':
        final r = rites.waterRoom;
        final xs = <int>[];
        var y0 = 0;
        for (var y = 0; y < r.h; y++) {
          for (var x = 0; x < r.w; x++) {
            if (r.fixed[y][x] == 'C') {
              xs.add(x);
              y0 = y;
            }
          }
        }
        if (xs.isNotEmpty) {
          final mx = xs.reduce((a, b) => a + b) / xs.length;
          return Offset((mx + .5) * kRiteCell, (y0 + .5) * kRiteCell);
        }
      case 'Fire':
        for (var y = 0; y < rites.fireRoom.h; y++) {
          for (var x = 0; x < rites.fireRoom.w; x++) {
            if (rites.fireRoom.cells[y][x] == 'H') return riteCentreOf(x, y);
          }
        }
      case 'Air':
        for (var y = 0; y < rites.airRoom.h; y++) {
          for (var x = 0; x < rites.airRoom.w; x++) {
            if (rites.airRoom.cells[y][x] == 'C') return riteCentreOf(x, y);
          }
        }
    }
    return currentRoom.bounds.center;
  }

  // ── Doors ────────────────────────────────────────────────

  /// The pit's way down only exists while the pit is a pool.
  bool _riteDoorHidden(DungeonRoom room, DungeonDoor door) {
    if (room.rite?.kind != RiteKind.water || !door.chromeless) return false;
    return rites.water.cells[kRiteWaterPit.y][kRiteWaterPit.x] != 'p';
  }

  // ── The per-frame rules ──────────────────────────────────

  void _updateRites(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isRites) return;
    rites.bumpCooldown = max(0, rites.bumpCooldown - dt);
    final bay = room.rite;
    _riteTickMoments(a, room, dt);

    // The rings ease to their turns (always forwards).
    double ease(double cur, int turn) {
      final want = turn * pi / 4;
      var d = want - cur;
      while (d < -pi) {
        d += 2 * pi;
      }
      while (d > pi) {
        d -= 2 * pi;
      }
      return cur + d * min(1.0, dt * 8);
    }

    rites.outerAng = ease(rites.outerAng, rites.outerTurn);
    rites.innerAng = ease(rites.innerAng, rites.innerTurn);
    for (var i = 0; i < rites.plateAng.length; i++) {
      final want = rites.earth.turns[i] * pi / 2;
      var d = want - rites.plateAng[i];
      while (d < -pi) {
        d += 2 * pi;
      }
      while (d > pi) {
        d -= 2 * pi;
      }
      rites.plateAng[i] += d * min(1.0, dt * 9);
    }

    if (bay == null) return;
    // On a grid, walking keeps to the middle of the row (or column) you are
    // walking along, so a step lands on its square and a doorway is met
    // square-on.
    if (bay.kind == RiteKind.earth ||
        bay.kind == RiteKind.water ||
        bay.kind == RiteKind.fire) {
      final j = joystickDirection;
      if (j.distance > 0.2) {
        final sq = riteSquareAt(a.position);
        final mid = riteCentreOf(sq.x, sq.y);
        final k = min(1.0, dt * 12);
        if (j.dx.abs() >= j.dy.abs()) {
          a.position = Offset(a.position.dx, a.position.dy + (mid.dy - a.position.dy) * k);
        } else {
          a.position = Offset(a.position.dx + (mid.dx - a.position.dx) * k, a.position.dy);
        }
      }
    }
    switch (bay.kind) {
      case RiteKind.circle:
        _riteSyncCups();
        _riteCircleUpdate(a);
      case RiteKind.earth:
        final t = riteSquareAt(a.position);
        if (t != rites.earthAt) {
          // Only ever one legal step at a time; anything else (a body set
          // down somewhere by the engine) goes back to its square.
          final g = rites.earthFloor.grid(rites.earth.turns);
          final legal =
              _riteDirTo(rites.earthAt, t) >= 0 &&
              t.y >= 0 &&
              t.y < g.length &&
              t.x >= 0 &&
              t.x < g[0].length &&
              g[t.y][t.x] == '.';
          if (!legal) {
            if (!_riteDoorSquare(room, t)) _riteSnapBlood();
            break;
          }
          final id = rites.leading;
          if (id != null) {
            final r = tendrilExtend(
              rites.earthFloor,
              rites.earth,
              id,
              t.x,
              t.y,
            );
            if (r.ok) {
              rites.earth = r.state!;
              final line = r.state!.lines[id];
              // Walked all the way back to the root: it is let go.
              if (line == null) rites.leading = null;
            }
          }
          rites.earthAt = t;
        }
      case RiteKind.water:
        rites.flipT = min(1, rites.flipT + dt * 2.2);
        // Nothing slides until the room has finished turning over.
        if (rites.flipT >= 1 && rites.waterFrames.isNotEmpty) {
          rites.waterFrameT += dt;
          while (rites.waterFrames.isNotEmpty &&
              rites.waterFrameT >= kRiteWaterPass) {
            rites.waterFrameT -= kRiteWaterPass;
            final to = rites.waterFrames.removeAt(0);
            _riteWaterPass(rites.waterFrom, to);
            rites.waterFrom = to;
          }
          if (rites.waterFrames.isEmpty) {
            rites.waterFrom = null;
            rites.waterFrameT = 0;
          }
        }
        final t = riteSquareAt(a.position);
        if (t != rites.water.b && flipWalkable(rites.water, t.x, t.y)) {
          final d = _riteDirTo(rites.water.b, t);
          if (d >= 0) {
            final before = rites.water;
            final st = flipStep(rites.waterRoom, rites.water, d, frames: true);
            if (st.ok) _riteWaterCommit(st, before);
          }
        }
      case RiteKind.fire:
        final t = riteSquareAt(a.position);
        if (t != rites.fire.b) {
          final d = _riteDirTo(rites.fire.b, t);
          if (d >= 0) {
            final st = twinStep(rites.fireRoom, rites.fire, d);
            if (st.ok && st.bMoved) _riteFireCommit(st);
          }
          if (rites.fire.b != t && !_riteDoorSquare(room, t)) {
            a.position = riteCentreOf(rites.fire.b.x, rites.fire.b.y);
          }
        }
        final want = riteCentreOf(rites.fire.t.x, rites.fire.t.y);
        rites.twinShown =
            Offset.lerp(rites.twinShown, want, min(1.0, dt * 14))!;
      case RiteKind.air:
        if (rites.driftT < 1) {
          final n = max(1, max(rites.driftPath.length, rites.icePath.length) - 1);
          rites.driftT = min(1, rites.driftT + dt * 10 / n);
          if (rites.driftT >= 1) {
            if (rites.iceMelted != null) _riteSublimate();
            if (driftSolved(rites.airRoom, rites.air)) {
              _riteFree('Air');
            } else {
              _riteSpeakIfDead(rites.airLive, rites.air.key);
            }
          }
        } else {
          _riteAirInput();
        }
        // Blood rides its drift (the engine doesn't move it here).
        a.position = _riteDriftPos();
        a.lastSafe = a.position;
      case RiteKind.arena:
        _riteArenaUpdate(a, room, dt);
      case RiteKind.vault:
        break;
    }
  }

  int _riteDirTo(RiteCell from, RiteCell to) {
    final dx = to.x - from.x, dy = to.y - from.y;
    if (dx.abs() + dy.abs() != 1) return -1;
    return dx == 1
        ? 1
        : dx == -1
        ? 3
        : dy == 1
        ? 2
        : 0;
  }

  /// Blood's drawn position along its drift (eased).
  Offset _riteDriftPos() {
    final p = rites.driftPath;
    if (p.length < 2 || rites.driftT >= 1) {
      return riteCentreOf(rites.air.b.x, rites.air.b.y);
    }
    final e = 1 - (1 - rites.driftT) * (1 - rites.driftT);
    final f = e * (p.length - 1);
    final i = f.floor().clamp(0, p.length - 2);
    final k = f - i;
    return Offset.lerp(
      riteCentreOf(p[i].x, p[i].y),
      riteCentreOf(p[i + 1].x, p[i + 1].y),
      k,
    )!;
  }

  void _riteCircleUpdate(DungeonCreature a) {
    final c = riteCentre(riteFreed, rites.outerTurn, rites.innerTurn);
    final k = c.ins.join('+');
    if (k != rites.lastCentre) {
      rites.lastCentre = k;
      rites.centreT = _time;
    }
    // THE LOST MAXIM: the quintessence.
    if (c.kind == RiteCentreKind.quintessence &&
        !discoveredClouds.contains(kBloodEggId) &&
        _ritePendingEgg != kBloodEggId) {
      _cue(SoundCue.dungeonSecretReveal);
      soundedSecrets.add(kBloodEggId);
      beginMaximRite(kBloodEggId, kRiteCircleCentre);
    }
    // THE RITE: all four cups full wakes Sanguorath below the seal.
    if (rites.cups.length == 4 &&
        guardianRiteUnlocked &&
        (conduitEnergy['A'] ?? 0) <= 0) {
      conduitEnergy['A'] = double.infinity;
      conduitEnergy['B'] = double.infinity;
      if (rites.sealT == -1) rites.sealT = _time;
    }
  }

  // ═══ SANGUORATH ═══════════════════════════════════════════

  /// The four (who have not given themselves) come down with Blood.
  void _riteAlliesJoin() {
    if (rites.alliesDown) return;
    rites.alliesDown = true;
    for (final c in rites.allies) {
      if (rites.given.contains(c.member.element)) continue;
      if (!riteFreed.contains(c.member.element)) continue;
      if (creatures.contains(c)) continue;
      c
        ..hp = c.maxHp
        ..downHandled = false
        ..respawnTimer = 0;
      creatures.add(c);
      combatCompanions.add(_createCombatCompanion(c.member, Offset.zero));
    }
  }

  /// Back up from the arena: the allies wait at the seal.
  void _riteAlliesLeave() {
    if (!rites.alliesDown) return;
    rites.alliesDown = false;
    _riteDropAllies((c) => rites.allies.contains(c));
  }

  void _riteDropAllies(bool Function(DungeonCreature) which) {
    for (var i = creatures.length - 1; i >= 0; i--) {
      if (!which(creatures[i])) continue;
      if (i < combatCompanions.length) combatCompanions.removeAt(i);
      creatures.removeAt(i);
      if (activeIndex >= creatures.length) activeIndex = 0;
      if (activeIndex > i) activeIndex--;
    }
  }

  /// The allies still standing (not given).
  Set<String> get _riteStanding => {
    for (final c in creatures)
      if (rites.allies.contains(c) && c.alive) c.member.element,
  };

  /// The top of the stretch the fight is in (where a heal stops).
  double get _riteStretchTop =>
      rites.shellsBroken == 0 ? 1.0 : kRiteShellAt[rites.shellsBroken - 1];

  void _riteArenaUpdate(DungeonCreature a, DungeonRoom room, double dt) {
    final g = _guardianEnemy;
    if (g == null) return;
    // Damage over time lands outside the hit paths: hold the shell here too.
    if (rites.shellsBroken < 4 && g.isDead) g.isDead = false;
    _riteHoldShell(g);
    if (g.isDead) return;
    if (rites.shellsBroken >= 4) return;
    final at = kRiteShellAt[rites.shellsBroken];
    if (!rites.shellUp) {
      if (g.hp / max(1, g.maxHp) <= at + 1e-6) {
        g.hp = max(g.hp, g.maxHp * at);
        final standing = _riteStanding;
        if (standing.isEmpty) return; // nobody to give; wait for a revive
        rites.shellUp = true;
        rites.shellElement = riteShellElement(
          standing,
          (n) => _combatRng.nextInt(n),
        );
        rites.shellT = _time;
        _cue(SoundCue.dungeonHazardTrigger);
        speakConsequence(_riteShellLine(rites.shellElement!));
      }
      return;
    }
    // While the shell is up, an ally walked into it gives itself — or is
    // thrown back.
    for (final c in List.of(creatures)) {
      if (!rites.allies.contains(c) || !c.alive) continue;
      if ((c.position - g.position).distance > 74) continue;
      final el = c.member.element;
      final want = kRiteOpposite[rites.shellElement]!;
      if (el == want) {
        _riteGive(c, g);
        return;
      }
      final last = rites.refusedT[el] ?? -9;
      if (_time - last < 1.4) continue;
      rites.refusedT[el] = _time;
      final away = c.position - g.position;
      final dir = away.distance < 1 ? const Offset(0, 1) : away / away.distance;
      c.position = _clampToBounds(g.position + dir * 150, room);
      g.hp = min(g.maxHp * _riteStretchTop, g.hp + g.maxHp * kRiteWrongHeal);
      _cue(SoundCue.dungeonBlockMove);
      _haptic(DungeonHaptic.refuse);
      speakConsequence('The shell throws $el back. Sanguorath mends');
    }
  }

  String _riteShellLine(String el) => switch (el) {
    'Fire' => 'Sanguorath pulls into a shell of flame',
    'Water' => 'Sanguorath pulls into a shell of water',
    'Earth' => 'Sanguorath pulls into a shell of stone',
    'Air' => 'Sanguorath pulls into a shell of wind',
    _ => 'Sanguorath pulls into a shell',
  };

  void _riteGive(DungeonCreature c, CosmicSurvivalEnemy g) {
    final el = c.member.element;
    rites.given.add(el);
    // THE SACRIFICE: its own body, in grains, drawn round into the shell —
    // and the shell sheds as it takes them.
    final body = RiteBody(elementColor(el));
    final img = _riteSnapshot(c);
    if (img != null) {
      body.read(img, kRiteSnapRatio);
    } else {
      body.force();
    }
    rites.sacrifice = RiteSacrificeFx(
      from: c.position,
      body: body,
      allyColor: elementColor(el),
    )..target = g.position;
    rites.sacrificed = c;
    rites.shedElement = rites.shellElement;
    rites.shellUp = false;
    rites.shellElement = null;
    rites.shellsBroken++;
    _cue(SoundCue.dungeonWallBreak);
    _haptic(DungeonHaptic.big);
    final wasActive = identical(active, c);
    _riteDropAllies((o) => identical(o, c));
    if (wasActive) {
      final blood = creatures.indexWhere((o) => !rites.allies.contains(o));
      activeIndex = blood < 0 ? 0 : blood;
    }
    speakConsequence(
      rites.shellsBroken >= 4
          ? '$el gives itself, and the shell breaks. It is you alone now'
          : '$el gives itself, and the shell breaks',
    );
    onChanged();
  }

  /// Damage on Sanguorath: nothing lands on the shell, and a hit can never
  /// carry it past the next break.
  double _riteDamageScale(CosmicSurvivalEnemy enemy) {
    if (!identical(enemy, _guardianEnemy)) return 1;
    return rites.shellUp ? 0 : 1;
  }

  /// Called right after any damage lands on an enemy: Sanguorath's health
  /// never goes below the next break while one is still to come, so no hit —
  /// however big — carries it past a shell (or kills it before the last).
  void _riteHoldShell(CosmicSurvivalEnemy e) {
    if (!_isRites || !identical(e, _guardianEnemy)) return;
    if (rites.shellsBroken >= 4) return;
    final floor = e.maxHp * kRiteShellAt[rites.shellsBroken];
    if (e.hp < floor) e.hp = floor;
  }

  // ═══ THE MOMENTS ═════════════════════════════════════════

  /// A creature as it stands, painted into a [kRiteSnapBox]-unit square at
  /// [kRiteSnapRatio] px per unit — the body a release or a sacrifice reads
  /// into grains. Null when it has no sprite (it is then a disc).
  ui.Image? _riteSnapshot(DungeonCreature c, {double scale = 1}) {
    final ticker = c.ticker;
    if (ticker == null) return null;
    final px = (kRiteSnapBox * kRiteSnapRatio).ceil();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)
      ..scale(kRiteSnapRatio)
      ..translate(kRiteSnapBox / 2, kRiteSnapBox / 2)
      ..scale(c.spriteScale * scale);
    ticker.getSprite().render(canvas, anchor: Anchor.center);
    return rec.endRecording().toImageSync(px, px);
  }

  /// Just outside a room's way back to the Circle: where its blood leaves.
  Offset _riteExitOf(DungeonRoom room) {
    for (final d in room.doors) {
      if (d.chromeless) continue;
      final c = d.rect.center;
      final out = (c - room.bounds.center);
      return c + out / max(1, out.distance) * 40;
    }
    return room.bounds.topCenter;
  }

  /// The room's two ingredients, each as a way to the captive and a colour.
  List<(List<Offset>, Color)> _riteSources(String el, Offset at) {
    const dust = Color(0xFFD4B072), water = Color(0xFF4F9BD8);
    const fire = Color(0xFFF08A3A), ice = Color(0xFFBFE8F5);
    const air = Color(0xFFDCEBF2), lava = Color(0xFFFF7A2A);
    const light = Color(0xFFFFE6A0);
    final out = <(List<Offset>, Color)>[];
    switch (el) {
      case 'Earth':
        for (final (id, col) in const [('d', dust), ('w', water)]) {
          final pts = rites.earth.lines[id];
          if (pts == null) continue;
          out.add(([for (final c in pts) riteCentreOf(c.x, c.y), at], col));
        }
      case 'Water':
        final r = rites.water;
        for (var y = 0; y < r.cells.length; y++) {
          for (var x = 0; x < r.cells[y].length; x++) {
            final ch = r.cells[y][x];
            if (ch == 'f') out.add(([riteCentreOf(x, y), at], fire));
            if (ch == 'c') out.add(([riteCentreOf(x, y) + const Offset(0, 20), at], ice));
          }
        }
      case 'Fire':
        final r = rites.fireRoom;
        for (var y = 0; y < r.h; y++) {
          for (var x = 0; x < r.w; x++) {
            if (r.cells[y][x] == 'B') out.add(([riteCentreOf(x, y), at], air));
            if (r.cells[y][x] == 'L') out.add(([riteCentreOf(x, y), at], lava));
          }
        }
      case 'Air':
        final r = rites.airRoom;
        var i = 0;
        for (var y = 0; y < r.h; y++) {
          for (var x = 0; x < r.w; x++) {
            if (r.cells[y][x] == '*' && r.bellBeside(x, y)) {
              out.add(([riteCentreOf(x, y), at], i.isEven ? ice : light));
              i++;
            }
          }
        }
    }
    return out;
  }

  /// One pass of a Water settle has been shown: what happened in it — a
  /// melt, a fire put out, a basin square filled, a pit taking something —
  /// is heard and seen now, as the picture gets there.
  void _riteWaterPass(FlipFrame? from, FlipFrame to) {
    if (from == null) return;
    final down = kRiteDy[rites.water.down].toDouble();
    for (var y = 0; y < to.cells.length; y++) {
      for (var x = 0; x < to.cells[y].length; x++) {
        final was = from.cells[y][x], now = to.cells[y][x];
        if (was == now) continue;
        final k = '$x,$y';
        final c = riteCentreOf(x, y);
        if (was == 'F' && now == 'f') {
          rites.douseT[k] = _time;
          _cue(SoundCue.dungeonHazardTrigger);
          // Steam off the drowned fire: it lifts and wanders and goes.
          for (var i = 0; i < 22; i++) {
            rites.grains.add(RiteGrain(
              x: c.dx + (_combatRng.nextDouble() - .5) * 26,
              y: c.dy - 6,
              vx: (_combatRng.nextDouble() - .5) * 14,
              vy: -18 - _combatRng.nextDouble() * 20,
              life: 1.4 + _combatRng.nextDouble(),
              color: i % 3 == 0 ? const Color(0xFFE8E4E0) : const Color(0xFFB8B0A8),
              lift: 26,
              wander: 22,
              drag: 1.1,
              seed: i * 1.7,
            ));
          }
        } else if (was == 'C' && now == 'c') {
          rites.basinT[k] = _time;
          _cue(SoundCue.dungeonStepWater);
        } else if (was == '_') {
          rites.pitT[k] = _time;
          _cue(now == 'p' ? SoundCue.dungeonStepWater : SoundCue.dungeonBlockMove);
        }
      }
    }
    for (final e in to.loose.entries) {
      if (e.value == '~' && from.loose[e.key] == 'I') {
        rites.meltT[e.key] = _time;
        _cue(SoundCue.dungeonStepWater);
        final p = e.key.split(',').map(int.parse).toList();
        final c = riteCentreOf(p[0], p[1]);
        // Drips off the melting block, falling the way the room falls.
        for (var i = 0; i < 10; i++) {
          rites.grains.add(RiteGrain(
            x: c.dx + (_combatRng.nextDouble() - .5) * 40,
            y: c.dy + (_combatRng.nextDouble() - .5) * 30,
            vy: down * (10 + _combatRng.nextDouble() * 20),
            life: .6 + _combatRng.nextDouble() * .5,
            color: i.isEven ? const Color(0xFFBFE8F5) : const Color(0xFF7FC0E8),
            lift: -down * 60,
            wander: 4,
            drag: .6,
          ));
        }
      }
    }
  }

  /// Ice turned to air in a shaft of light: it comes apart into vapour that
  /// rises and goes — or, beside the bell, is drawn in.
  void _riteSublimate() {
    final at = rites.iceMelted!;
    final c = riteCentreOf(at.x, at.y);
    Offset? bell;
    if (rites.iceIntoBell) {
      for (var d = 0; d < 4; d++) {
        final x = at.x + kRiteDx[d], y = at.y + kRiteDy[d];
        if (rites.airRoom.cells[y][x] == 'C') bell = riteCentreOf(x, y);
      }
    }
    _cue(SoundCue.dungeonStepWater);
    for (var i = 0; i < 46; i++) {
      final a = _combatRng.nextDouble() * pi * 2;
      final r = _combatRng.nextDouble() * 22;
      rites.grains.add(RiteGrain(
        x: c.dx + cos(a) * r,
        y: c.dy + sin(a) * r,
        vx: cos(a) * 10,
        vy: sin(a) * 10 - 8,
        life: bell != null ? 1.3 + _combatRng.nextDouble() * .5 : 1.6 + _combatRng.nextDouble(),
        color: i % 3 == 0
            ? const Color(0xFFFFE6A0)
            : i.isEven
            ? const Color(0xFFDCEBF2)
            : const Color(0xFFBFE8F5),
        lift: bell != null ? 0 : 22,
        wander: bell != null ? 8 : 16,
        to: bell,
        pull: bell != null ? 5 : 0,
        drag: bell != null ? 2.4 : 1.0,
        seed: i * 0.9,
      ));
    }
  }

  /// Every frame: the moments run, and the small things that feel the room
  /// — dust off a turning plate, a drift's wake, the bellows breathing, the
  /// gates sliding.
  void _riteTickMoments(DungeonCreature a, DungeonRoom room, double dt) {
    rites.grains.update(dt, _time);
    final rel = rites.release;
    if (rel != null) {
      rel.update(dt);
      if (rel.done) {
        rites.release = null;
        rites.releaseEl = null;
      }
    }
    final sac = rites.sacrifice;
    if (sac != null) {
      final g = _guardianEnemy;
      if (g != null && !g.isDead) sac.target = g.position;
      sac.update(dt);
      if (sac.done) {
        rites.sacrifice = null;
        rites.sacrificed = null;
        rites.shedElement = null;
      }
    }
    final kind = room.rite?.kind;
    if (kind == RiteKind.earth) {
      // Stone dust off a plate while it turns.
      final f = rites.earthFloor;
      for (var i = 0; i < f.plates.length; i++) {
        final want = rites.earth.turns[i] * pi / 2;
        var d = want - rites.plateAng[i];
        while (d < -pi) {
          d += 2 * pi;
        }
        while (d > pi) {
          d -= 2 * pi;
        }
        if (d.abs() < .04) continue;
        final p = riteCentreOf(f.plates[i].cx, f.plates[i].cy);
        for (var k = 0; k < 2; k++) {
          final ang = _combatRng.nextDouble() * pi * 2;
          rites.grains.add(RiteGrain(
            x: p.dx + cos(ang) * kRiteCell * 1.5,
            y: p.dy + sin(ang) * kRiteCell * 1.5,
            vx: -sin(ang) * 14 * d.sign,
            vy: cos(ang) * 14 * d.sign,
            life: .7 + _combatRng.nextDouble() * .4,
            color: k.isEven ? const Color(0xFF8A7A70) : const Color(0xFF5E504A),
            lift: -14,
            wander: 6,
            drag: 2.5,
          ));
        }
      }
    } else if (kind == RiteKind.air && rites.driftT < 1 && rites.driftPath.length > 1) {
      // A drift leaves a wake.
      for (var k = 0; k < 2; k++) {
        rites.grains.add(RiteGrain(
          x: a.position.dx + (_combatRng.nextDouble() - .5) * 16,
          y: a.position.dy + (_combatRng.nextDouble() - .5) * 16,
          life: .5 + _combatRng.nextDouble() * .4,
          color: k.isEven ? const Color(0xFFDCE6F0) : const Color(0xFFC8283C),
          wander: 10,
          drag: 3,
        ));
      }
    } else if (kind == RiteKind.fire) {
      final r = rites.fireRoom;
      final on = twinPressed(r, rites.fire);
      // The gates slide rather than blink.
      for (var y = 0; y < r.h; y++) {
        for (var x = 0; x < r.w; x++) {
          final ch = r.cells[y][x];
          if (!'abc'.contains(ch)) continue;
          final plate = {'a': '1', 'b': '2', 'c': '3'}[ch]!;
          final open = on.contains(plate) ||
              rites.fire.b == (x: x, y: y) ||
              rites.fire.t == (x: x, y: y);
          final k = '$x,$y';
          final was = rites.gateShown[k] ?? (open ? 1.0 : 0.0);
          rites.gateShown[k] = was + ((open ? 1.0 : 0.0) - was) * min(1.0, dt * 9);
        }
      }
      // The bellows breathe when Blood stands on them.
      rites.puffT -= dt;
      if (r.cells[rites.fire.b.y][rites.fire.b.x] == 'B' && rites.puffT <= 0) {
        rites.puffT = .22;
        final b = riteCentreOf(rites.fire.b.x, rites.fire.b.y);
        final h = _riteCaptiveAt('Fire');
        for (var k = 0; k < 4; k++) {
          rites.grains.add(RiteGrain(
            x: b.dx + 20,
            y: b.dy + (_combatRng.nextDouble() - .5) * 10,
            vx: (h.dx - b.dx) * .9,
            vy: (h.dy - b.dy) * .9,
            life: .7,
            color: const Color(0xFFDCEBF2),
            wander: 8,
            drag: 1.4,
          ));
        }
      }
    }
  }

  // ── Test seams ───────────────────────────────────────────

  /// Free [el]'s captive as its room would (the release plays).
  @visibleForTesting
  void debugFreeCaptive(String el) => _riteFree(el);

  /// Load a creature's sprite, as onLoad does for the party.
  @visibleForTesting
  Future<void> debugLoadSprite(DungeonCreature c) => _loadSprite(c);

  /// Build the four allies' bodies, as onLoad does.
  @visibleForTesting
  Future<void> debugLoadRiteAllies() => _loadRiteAllies();

  /// The maxim waiting to play (or found).
  @visibleForTesting
  String? get debugMaximPending =>
      _ritePendingEgg ??
      (discoveredClouds.contains(kBloodEggId) ? kBloodEggId : null);

  /// Sanguorath's combat body, once it has landed.
  @visibleForTesting
  CosmicSurvivalEnemy? get debugGuardianBody => _guardianEnemy;

  /// A hit, through the same path a strike takes.
  @visibleForTesting
  void debugDamageEnemy(CosmicSurvivalEnemy e, double amount) =>
      _damageEnemyDirect(e, amount);

  // ── Words ────────────────────────────────────────────────

  String? _riteObjectiveHint(DungeonRoom room) {
    final bay = room.rite;
    if (bay == null) return null;
    final el = bay.element;
    if (el != null && riteFreed.contains(el)) return 'This captive is freed';
    return null;
  }

  /// The HINT button: what is wrong, and nothing more.
  void _riteReveal(DungeonCreature a, DungeonRoom room) {
    final bay = room.rite;
    if (bay == null) return;
    final freed = riteFreed;
    switch (bay.kind) {
      case RiteKind.circle:
        if (freed.length < 4) {
          _setInsightHint(
            freed.isEmpty
                ? 'Four rooms each hold a captive'
                : '${4 - freed.length} of the captives are still held',
          );
        } else if (rites.cups.length < 4) {
          _setInsightHint('Not every cup is full');
        } else {
          _setInsightHint('The seal is open');
        }
      case RiteKind.earth:
        _setInsightHint(
          tendrilSolved(rites.earthFloor, rites.earth)
              ? 'Every tendril is joined'
              : 'Some tendrils are not joined',
        );
      case RiteKind.water:
        _setInsightHint(
          flipSolved(rites.water) ? 'The basin is full' : 'The basin is dry',
        );
      case RiteKind.fire:
        _setInsightHint('The hearth is cold');
      case RiteKind.air:
        _setInsightHint(
          rites.air.air == 0 ? 'The bell is empty' : 'The bell is not full',
        );
      case RiteKind.arena:
        if (rites.shellUp && rites.shellElement != null) {
          _setInsightHint(_riteShellLine(rites.shellElement!));
        }
      case RiteKind.vault:
        break;
    }
  }

  double get _riteMoodTarget => switch (_riteBay?.kind) {
    RiteKind.arena => 1.0,
    RiteKind.circle => .55,
    _ => .45,
  };
}
