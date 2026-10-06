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
// RESET ROOM (a big labelled button in every captive room; the screen draws
// it in place of the regroup icon) starts that room again with Blood at its
// door — the honest undo. A room never says it has jammed (the author,
// 2026-10-06: they should work out for themselves that it needs a reset);
// the first captive room entered says once where the button is.
//
// THE CAMERA (2026-10-06, the author: "all the rooms are too zoomed out").
// A captive room is played close, at the game's ordinary zoom, following
// Blood. It pulls back to the whole room only to show something: for a
// moment on the way in, and while the Water room turns over and settles.
// The Fire room is the exception: the twin's room is read as one picture,
// held still on every floor square (see [_riteCamera]).
//
// Nothing here is timed and nothing is chance; the shell's element is rolled
// per fight, but bringing the right ally always works.

part of 'planet_dungeon_game.dart';

/// The release and sacrifice read a body out of a square this many world
/// units across, at this many pixels per unit.
const double kRiteSnapBox = 96, kRiteSnapRatio = 3;

/// Seconds between Hemavorn's heartbeats at rest: the portal's beat.
const double kRiteBeatRest = .9;

/// Captives are drawn this much larger than the party (they are the room's
/// subject, and their release has to read).
const double kRiteCaptiveScale = 1.35;

/// THE WATER ROOM'S PACE (2026-10-06, the author: "happens so fast on flip
/// I don't know what's going on"). The room takes [kRiteFlipTurn] seconds to
/// turn over — its runnels slow, stop and run the other way, the slope's
/// shadow swings across the floor, and what is about to fall leans — and
/// only then does anything move. A fall gathers speed: its first square
/// takes [kRiteFallFirst] seconds and each next one [kRiteFallGain] of the
/// one before, down to [kRiteFallFastest]. A melt or a fire going out holds
/// the picture for [kRiteReactHold] while it happens.
const double kRiteFlipTurn = 0.85;
const double kRiteFallFirst = 0.24, kRiteFallGain = 0.82;
const double kRiteFallFastest = 0.11;
const double kRiteReactHold = 0.7;

/// How far into its own square Blood may lean toward one it can't enter
/// (world units). Before, it walked up to the square's edge — half its body
/// over the wall — and nothing said what had stopped it.
const double kRiteLean = 12;

/// Everything the Blood Rites track for one run, plus the clocks the render
/// reads.
class BloodRun {
  BloodRun() {
    resetRooms();
  }

  // ── The heart that beats under every room ──
  /// Where the heart is in its beat (0..1), how long a beat is now, and
  /// when the last one fell (game time).
  double beatPhase = 0, beatPeriod = kRiteBeatRest, beatAt = -9;

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

  /// The pass playing now: how long it takes, whether it has begun, and how
  /// many falling passes came straight before it (a fall gathers speed).
  double waterPassDur = kRiteFallFirst;
  bool waterPassLive = false;
  int waterChain = 0;

  /// The settle playing came from a FLIP (the camera shows the whole room).
  bool waterFromFlip = false;

  /// The frame a settle is leaving (the render slides from it to the next).
  FlipFrame? waterFrom;

  /// When something last happened on a square, keyed 'x,y' — a melt, a fire
  /// put out, a basin square filling, a pit taking something, a block of ice
  /// landing. The render plays each moment from it.
  final Map<String, double> meltT = {},
      douseT = {},
      basinT = {},
      pitT = {},
      landT = {};

  /// How far the blood in the Water room's runnels has run (it runs
  /// downhill, and turns round with the room).
  double runnel = 0;

  // ── The camera (see the header) ──
  /// 0 = close on Blood at the ordinary zoom, 1 = the whole room. [camK] is
  /// the zoom's share, [frameK] the framing's (the Fire room zooms out to
  /// keep the twin in view without leaving Blood).
  double camK = 0, frameK = 0;

  /// Seconds left of the look at the whole room on the way in (moving ends
  /// it), and after a flip has settled.
  double entryHold = 0, flipHold = 0;

  // ── A bump: Blood pressed into something it can't enter ──
  RiteCell? bumpFrom;
  int bumpDir = 0;
  double bumpT = -9;
  String? bumpKey;

  /// Until when the RESET ROOM button is lit (the first captive room says
  /// where it is).
  double resetLitUntil = -9;

  // ── The moments (blood_rite_fx.dart) ──
  final RiteGrainField grains = RiteGrainField();

  /// The Heart, the fifth rite (planet_dungeon_game_blood_heart.dart).
  HeartRunState heart = HeartRunState();
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
    grains.clear();
    earth = TendrilState.start(earthFloor);
    fire = twinStart(fireRoom);
    air = driftStart(airRoom);
    earthAt = kRiteArrival['Earth']!;
    leading = null;
    _resetWater();
    driftT = 1;
    driftPath = const [];
    icePath = const [];
  }

  void _resetWater() {
    water = flipStart(waterRoom);
    waterFrames = [];
    waterFrom = null;
    waterFrameT = 0;
    waterPassLive = false;
    waterChain = 0;
    waterFromFlip = false;
    flipT = 1;
    flipHold = 0;
    meltT.clear();
    douseT.clear();
    basinT.clear();
    pitT.clear();
    landT.clear();
  }

  void resetRoom(String element) {
    switch (element) {
      case 'Earth':
        earth = TendrilState.start(earthFloor);
        earthAt = kRiteArrival['Earth']!;
        leading = null;
      case 'Water':
        _resetWater();
      case 'Fire':
        fire = twinStart(fireRoom);
      case 'Air':
        air = driftStart(airRoom);
        driftT = 1;
        driftPath = const [];
        icePath = const [];
    }
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
    rites.heart = HeartRunState();
    if (riteHeartFreed) rites.heart.freed = true;
    rites.sealT = _riteSealOpen ? -99 : -1;
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
    // The Heart: whoever is being steered stands where it stands.
    _ => _riteBay?.kind == RiteKind.heart && active != null
        ? riteSquareAt(active!.position)
        : null,
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
    // Back up to the Circle: the allies wait below.
    if (kind == RiteKind.circle) _riteAlliesLeave();
    if (kind == RiteKind.heart) {
      _heartArrive();
      rites.camK = rites.frameK = 1;
      return false;
    }
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
      case 'Fire':
        // The twin's room only makes sense from a start: a fresh pair.
        rites.fire = twinStart(rites.fireRoom);
      case 'Air':
        // Drifting has no way back to a square: the room starts again.
        rites.resetRoom('Air');
    }
    // The way in shows the whole room for a moment, then closes in.
    rites.camK = rites.frameK = 1;
    rites.entryHold = 1.1;
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

  /// RESET ROOM (and the regroup button, in a captive room): start that room
  /// again with Blood at its door. True when handled.
  bool _riteRegroup() {
    if (!_isRites) return false;
    if (_riteBay?.kind == RiteKind.heart) {
      if (!_heartReset()) return true;
      rites.resetLitUntil = -9;
      _cue(SoundCue.dungeonBlockMove);
      _clearHints();
      onChanged();
      return true;
    }
    final el = _riteRoomEl;
    if (el == null) return false;
    rites.resetRoom(el);
    final arrive = kRiteArrival[el]!;
    if (el == 'Earth') rites.earthAt = arrive;
    _riteSnapBlood();
    rites.twinShown = riteCentreOf(rites.fire.t.x, rites.fire.t.y);
    rites.bumpKey = null;
    rites.resetLitUntil = -9;
    // The room, whole and as it began, before closing in again.
    rites.entryHold = max(rites.entryHold, .8);
    _cue(SoundCue.dungeonBlockMove);
    _clearHints();
    onChanged();
    return true;
  }

  /// The captive rooms show a large RESET ROOM button (in place of the
  /// regroup icon) while one is being played.
  bool get riteResetShown =>
      _isRites &&
      rites.release == null &&
      (_riteBay?.isGrid == true ||
          (_riteBay?.kind == RiteKind.heart &&
              rites.heart.taken &&
              !rites.heart.freed &&
              rites.heart.captureT < 0));

  /// Lit while the first captive room is saying where it is.
  bool get riteResetLit => riteResetShown && _time < rites.resetLitUntil;

  /// The RESET ROOM button.
  void resetRiteRoom() {
    if (!riteResetShown) return;
    _riteRegroup();
  }

  /// The first captive room entered says, once ever, where the way back to
  /// its start is (alongside the room's own teach). Null once said.
  String? _riteResetTeach(DungeonRoom room) {
    if (room.rite?.isStaged != true) return null;
    const id = 'teach:rite_reset';
    if (discoveredClouds.contains(id)) return null;
    _discoverCloud(id);
    rites.resetLitUntil = _time + 9;
    return 'Stuck? RESET ROOM puts the room back the way it started';
  }

  // ── The camera ───────────────────────────────────────────

  /// The zoom that frames the whole of [room] in the clear part of the view.
  double _riteWholeZoom(DungeonRoom room) =>
      _fitFrame(room.bounds).$2.clamp(PlanetDungeonGame.kMinFitZoom, 1.0);

  /// The zoom in force in a captive room: the ordinary one, pulled back
  /// toward the whole room by [BloodRun.camK]. 1.0 everywhere else.
  double get _riteViewZoom {
    if (!hasLayout || currentRoom.rite?.isStaged != true) return 1.0;
    if (currentRoom.rite?.kind == RiteKind.heart) return rites.heart.camZoom;
    return 1 + (_riteWholeZoom(currentRoom) - 1) * rites.camK;
  }

  /// Where the camera stands in a captive room: following [focus] as any
  /// room does, slid toward the whole-room framing by [BloodRun.frameK].
  Offset _riteCameraTopLeft(DungeonRoom room, Offset focus) {
    final z = viewZoom;
    final vw = size.x / z, vh = size.y / z;
    final b = room.bounds;
    double follow(double lo, double len, double view, double f) => len <= view
        ? lo + len / 2 - view / 2
        : (f - view / 2).clamp(lo, lo + len - view);
    final near = Offset(
      follow(b.left, b.width, vw, focus.dx),
      follow(b.top, b.height, vh, focus.dy),
    );
    if (room.rite?.kind == RiteKind.heart) {
      // The tool column owns the right of the view (all of it, top to
      // bottom, on the folded phone): the stage is framed in what is left.
      final l = 8 / z, r = (size.x - 128) / z;
      final x = b.width <= r - l
          ? b.center.dx - (l + r) / 2
          : (focus.dx - (l + r) / 2).clamp(b.left - l, b.right - r);
      // And it may rise above the room: Blood is bound at its very top, and
      // the open space goes on up there.
      final top = b.top - kRiteCell * 1.5;
      return Offset(x, follow(top, b.bottom - top, vh, focus.dy)) + surveyPan;
    }
    final (frame, _) = _fitFrame(b);
    final whole = b.center - frame.center / z;
    return Offset.lerp(near, whole, rites.frameK)! + surveyPan;
  }

  /// What the camera follows in a rite room (null: whoever is steered).
  Offset? get _riteCamFocus =>
      _isRites && _riteBay?.kind == RiteKind.heart ? rites.heart.camAt : null;

  void _riteCamera(DungeonCreature a, RiteBay? bay, double dt) {
    if (bay == null || !bay.isStaged) {
      rites.camK = rites.frameK = 0;
      rites.entryHold = rites.flipHold = 0;
      return;
    }
    if (bay.kind == RiteKind.heart) {
      rites.camK = rites.frameK = 0;
      _heartCamera(a, dt);
      return;
    }
    // Moving ends the look round on the way in.
    if (joystickDirection.distance > .3) rites.entryHold = 0;
    rites.entryHold = max(0, rites.entryHold - dt);
    final settling =
        bay.kind == RiteKind.water &&
        (rites.flipT < 1 ||
            (rites.waterFromFlip && rites.waterFrames.isNotEmpty));
    rites.flipHold = settling ? .7 : max(0, rites.flipHold - dt);
    final whole = rites.entryHold > 0 || rites.flipHold > 0 ? 1.0 : 0.0;
    var zoom = whole, frame = whole;
    if (bay.kind == RiteKind.fire && hasLayout) {
      // THE TWIN ROOM IS ONE PICTURE (the author, 2026-10-06: "feels a
      // little weird … zoom out a bit more"). Following the pair and
      // zooming just far enough to keep both in view kept the camera
      // breathing with every step, and the far bank's plates and gates
      // were mostly off screen. It holds still instead, framed on the room,
      // as close as it can come with every floor square in view.
      final b = currentRoom.bounds;
      final wz = _riteWholeZoom(currentRoom);
      final floorZ = min(
        1.0,
        min(
          size.x / (b.width - kRiteCell * 1.6),
          size.y / (b.height - kRiteCell * 1.6),
        ),
      );
      if (wz < .999) {
        zoom = max(zoom, ((1 - max(wz, floorZ)) / (1 - wz)).clamp(0.0, 1.0));
      }
      frame = 1;
    }
    final k = 1 - exp(-dt / .3);
    rites.camK += (zoom - rites.camK) * k;
    rites.frameK += (frame - rites.frameK) * k;
  }

  // ── Walking ──────────────────────────────────────────────

  static const String _riteBlockPrefix = 'rite:';

  /// Does Blood's next position leave what the rules allow?
  ///
  /// Inside its own square Blood may lean [kRiteLean] toward a square it
  /// can't enter, and no further: it stops short with its body still on its
  /// own square, and what stopped it shows (see [_riteBump]).
  bool _riteBlocksAt(Offset center, DungeonRoom room) {
    final bay = room.rite;
    if (bay == null) return false;
    if (bay.kind == RiteKind.circle) return _riteCircleBlocks(center);
    if (!bay.isStaged) return false;
    final a = active;
    if (a == null) return false;
    final here = _riteBloodAt!;
    final t = riteSquareAt(center);
    final dx = t.x - here.x, dy = t.y - here.y;
    if (dx == 0 && dy == 0) {
      // Only a move OUTWARD is held: coming in off a step (or settling back
      // to the middle) is always allowed.
      final mid = riteCentreOf(here.x, here.y);
      final off = center - mid, cur = a.position - mid;
      if (off.dx.abs() > kRiteLean &&
          off.dx.abs() > cur.dx.abs() &&
          _riteStepBlocked(room, bay, here, off.dx > 0 ? 1 : 3)) {
        return true;
      }
      if (off.dy.abs() > kRiteLean &&
          off.dy.abs() > cur.dy.abs() &&
          _riteStepBlocked(room, bay, here, off.dy > 0 ? 2 : 0)) {
        return true;
      }
      return false;
    }
    if (dx.abs() + dy.abs() != 1) return true;
    return _riteStepBlocked(room, bay, here, _riteDirTo(here, t));
  }

  /// Can't Blood step from [here] in [dir]? A refusal the player made by
  /// pressing (not one of the room still moving) shows as a bump.
  bool _riteStepBlocked(DungeonRoom room, RiteBay bay, RiteCell here, int dir) {
    if (bay.kind == RiteKind.heart) return _heartStepBlocked(room, here, dir);
    final t = (x: here.x + kRiteDx[dir], y: here.y + kRiteDy[dir]);
    // A doorway square is the way out: let the engine take the door.
    if (_riteDoorSquare(room, t)) return false;
    final bool blocked;
    switch (bay.element) {
      case 'Earth':
        final led = rites.leading;
        blocked = _riteEarthBlocks(t);
        // Walking into the partner joins the tendril: not a bump.
        if (led != null && rites.leading == null) return true;
      case 'Water':
        if (rites.waterFrames.isNotEmpty || rites.flipT < 1) return true;
        if (t.y >= 0 &&
            t.y < rites.water.cells.length &&
            rites.water.cells[t.y][t.x] == 'p') {
          return false; // the dive
        }
        blocked = !flipWalkable(rites.water, t.x, t.y);
      case 'Fire':
        final st = twinStep(rites.fireRoom, rites.fire, dir, freed: _riteFireDone);
        blocked = _riteFireBlocks(dir);
        // The twin stepped (or somebody fell): something happened.
        if (blocked && st.ok) return true;
      default:
        return true; // nobody walks on air
    }
    if (blocked) _riteBump(here, dir);
    return blocked;
  }

  /// Blood pressed into a square it can't enter: the blocker shows itself —
  /// a pool of light on its near face and a little grit off it — and the
  /// phone ticks, once per thing pressed against.
  void _riteBump(RiteCell from, int dir) {
    final key = '${from.x},${from.y}>$dir';
    if (rites.bumpKey == key && _time - rites.bumpT < 1.2) return;
    rites.bumpKey = key;
    rites.bumpFrom = from;
    rites.bumpDir = dir;
    rites.bumpT = _time;
    _haptic(DungeonHaptic.refuse);
    final n = Offset(kRiteDx[dir].toDouble(), kRiteDy[dir].toDouble());
    final edge = riteCentreOf(from.x, from.y) + n * (kRiteCell / 2 - 4);
    final along = Offset(-n.dy, n.dx);
    for (var i = 0; i < 7; i++) {
      final s = (_combatRng.nextDouble() - .5) * 34;
      rites.grains.add(
        RiteGrain(
          x: edge.dx + along.dx * s,
          y: edge.dy + along.dy * s,
          vx: -n.dx * (14 + _combatRng.nextDouble() * 16) + along.dx * s * .4,
          vy: -n.dy * (14 + _combatRng.nextDouble() * 16) + along.dy * s * .4,
          life: .45 + _combatRng.nextDouble() * .3,
          color: i.isEven ? const Color(0xFF9A7E78) : const Color(0xFF5E4A48),
          lift: -10,
          wander: 3,
          drag: 3,
        ),
      );
    }
  }

  /// Is (x,y) the square of one of [room]'s wall doors?
  bool _riteDoorSquare(DungeonRoom room, RiteCell t) {
    for (final d in room.doors) {
      if (d.chromeless || _riteDoorHidden(room, d)) continue;
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

  /// The twin room is done: its captive is freed, and every gate in it
  /// stands open so Blood can walk back out (the way out is behind gate b,
  /// which only the twin could hold, and from where the room is solved it
  /// never can again).
  bool get _riteFireDone =>
      riteFreed.contains('Fire') || rites.freedT.containsKey('Fire');

  bool _riteFireBlocks(int dir) {
    final st = twinStep(rites.fireRoom, rites.fire, dir, freed: _riteFireDone);
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
      // The fall and the two of you rising again at the pool say it; no
      // words (the author: "visuals drive the puzzle").
      _cue(SoundCue.dungeonHazardTrigger);
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
        _setBlockedHint(
          r.why == 'Tendrils never cross.'
              ? 'Another tendril lies where you stand'
              : 'That tendril can\'t start here',
        );
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
    _riteWaterCommit(st, before, flip: true);
  }

  /// A settle is taken now (the rules) and played back a pass at a time (the
  /// render slides each thing from square to square, and the moments — a
  /// melt, a fire put out, a basin filling — sound as the picture reaches
  /// them, in [_riteWaterPlay]).
  void _riteWaterCommit(FlipStep st, FlipState before, {bool flip = false}) {
    rites.waterFrom = FlipFrame(before);
    rites.waterFrames = List.of(st.frames);
    rites.waterFrameT = 0;
    rites.waterPassLive = false;
    rites.waterChain = 0;
    rites.waterFromFlip = flip;
    rites.water = st.state!;
    if (flipSolved(rites.water)) _riteFree('Water');
  }

  /// Play a settle back a pass at a time. A falling pass slides everything
  /// that moves one square, each a little quicker than the last; a pass in
  /// which ice melted or a fire went out shows its change at once and holds
  /// while it happens.
  void _riteWaterPlay(double dt) {
    var left = dt;
    while (rites.waterFrames.isNotEmpty) {
      final to = rites.waterFrames.first;
      final react = to.moves.isEmpty && to.gone.isEmpty;
      if (!rites.waterPassLive) {
        rites.waterPassLive = true;
        rites.waterFrameT = 0;
        rites.waterPassDur = react
            ? kRiteReactHold
            : max(
                kRiteFallFastest,
                kRiteFallFirst * pow(kRiteFallGain, rites.waterChain),
              );
        if (react) {
          _riteWaterPass(rites.waterFrom, to);
          rites.waterFrom = to;
        }
      }
      final need = rites.waterPassDur - rites.waterFrameT;
      if (left < need) {
        rites.waterFrameT += left;
        return;
      }
      left -= need;
      rites.waterFrames.removeAt(0);
      rites.waterPassLive = false;
      rites.waterFrameT = 0;
      if (react) {
        rites.waterChain = 0;
      } else {
        _riteWaterPass(rites.waterFrom, to);
        _riteWaterLandings(to, rites.waterFrames.firstOrNull);
        rites.waterFrom = to;
        rites.waterChain++;
      }
    }
    rites.waterFrom = null;
    rites.waterChain = 0;
  }

  /// Whatever slid in [to] and doesn't slide on in [next] has landed: ice
  /// sets down with a knock and a little frost, water splashes.
  void _riteWaterLandings(FlipFrame to, FlipFrame? next) {
    final down = kRiteDy[rites.water.down].toDouble();
    final still = next == null || (next.moves.isEmpty && next.gone.isEmpty);
    var ice = false, water = false;
    for (final e in to.moves.entries) {
      final key = e.key;
      if (!still && next.moves.containsValue(key)) continue;
      if (!still && next.gone.containsKey(key)) continue;
      final kind = to.loose[key];
      final p = key.split(',').map(int.parse).toList();
      final c = riteCentreOf(p[0], p[1]);
      // Which way it was going when it stopped.
      final o = e.value.split(',').map(int.parse).toList();
      final dir = Offset((p[0] - o[0]).toDouble(), (p[1] - o[1]).toDouble());
      final lead = c + dir * (kRiteCell / 2 - 6);
      final side = Offset(-dir.dy, dir.dx);
      if (kind == 'I') {
        ice = true;
        rites.landT[key] = _time;
        for (var i = 0; i < 9; i++) {
          final s = (_combatRng.nextDouble() - .5) * 2;
          rites.grains.add(
            RiteGrain(
              x: lead.dx + side.dx * s * 22,
              y: lead.dy + side.dy * s * 22,
              vx: side.dx * s * 34 - dir.dx * 8,
              vy: side.dy * s * 34 - dir.dy * 8,
              life: .5 + _combatRng.nextDouble() * .35,
              color: i % 3 == 0
                  ? const Color(0xFFE4F6FC)
                  : const Color(0xFF9FD0E2),
              lift: 6,
              wander: 4,
              drag: 3.2,
            ),
          );
        }
      } else if (kind == '~') {
        water = true;
        rites.landT[key] = _time;
        for (var i = 0; i < 12; i++) {
          final s = (_combatRng.nextDouble() - .5) * 2;
          rites.grains.add(
            RiteGrain(
              x: lead.dx + side.dx * s * 18,
              y: lead.dy + side.dy * s * 18,
              vx: side.dx * s * 46 - dir.dx * 14,
              vy: side.dy * s * 46 - dir.dy * 14 - down * 6,
              life: .4 + _combatRng.nextDouble() * .3,
              color: i.isEven
                  ? const Color(0xFF9CCDE6)
                  : const Color(0xFF4E8FB4),
              lift: -down * 40,
              wander: 3,
              drag: 2.4,
            ),
          );
        }
      }
    }
    if (ice) _cue(SoundCue.dungeonBlockMove);
    if (water) _cue(SoundCue.dungeonStepWater);
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
        (dd) =>
            !dd.chromeless &&
            riteSquareAt(dd.rect.center) ==
                (x: at.x + kRiteDx[d], y: at.y + kRiteDy[d]),
      );
      if (door.isNotEmpty) {
        passThroughDoor(door.first);
        return;
      }
      if (r.why != 'blocked') _setBlockedHint(r.why!);
      _riteBump(at, d);
      return;
    }
    rites.air = r.state!;
    rites.driftPath = r.bloodPath;
    rites.icePath = r.icePath;
    rites.iceMelted = r.meltedAt;
    rites.iceIntoBell = r.intoBell;
    rites.driftT = 0;
    _cue(
      r.icePath.isNotEmpty
          ? SoundCue.dungeonBlockMove
          : SoundCue.dungeonStepStone,
    );
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
    final img = ally == null
        ? null
        : _riteSnapshot(ally, scale: kRiteCaptiveScale);
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
    // The ingredients running in, the bands letting go and the blood running
    // home say it all: no words (the author: "visuals drive the puzzle").
    _riteSyncCups();
    // All four freed: the first star (the Heart is the second).
    if (riteFreed.length == 4 && !hasStar(0)) earnStar(0);
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
    final kind = room.rite?.kind;
    // The Circle's seal is a way down only once all four cups are full.
    // The Circle's seal is a way down only once it has opened: all four
    // cups full AND the maxim found.
    if (kind == RiteKind.circle && door.chromeless) return !_riteSealOpen;
    // The Heart's stair up and its floor down exist once Blood is free.
    if (kind == RiteKind.heart) return _heartDoorHidden(door);
    if (kind != RiteKind.water || !door.chromeless) return false;
    return rites.water.cells[kRiteWaterPit.y][kRiteWaterPit.x] != 'p';
  }

  // ── The heart ────────────────────────────────────────────

  /// HEMAVORN'S HEART, FELT (the author, 2026-10-06: "haptic feedback for
  /// the blood planet heart pulse throughout the dungeon"). One heart beats
  /// under every Blood room, in the planet's own rhythm — the portal's
  /// double thump, a LUB and a DUB 0.2s behind it — and the phone gives
  /// each beat to the hand ([DungeonHaptic.heartbeat]; off with the rest of
  /// the haptics in Settings). At rest it beats every 0.9s, the portal's
  /// beat. In the Heart it is quicker; it races while Blood is taken, and
  /// while Blood is made and poured back; once Blood is free it slows. In
  /// Sanguorath's fight it runs, and it runs when the one you steer is
  /// badly hurt. The tempo eases from one to the next, never jumps, and the
  /// beat carries on across doors. The glows that beat with it read
  /// [riteBeat].
  void _riteHeartbeat(DungeonCreature a, double dt) {
    final h = rites.heart;
    var want = kRiteBeatRest;
    switch (_riteBay?.kind) {
      case RiteKind.heart:
        if (h.captureT >= .8 || (h.finaleT >= 1.9 && h.finaleT < 5.6)) {
          want = .5;
        } else if (h.freed) {
          want = 1.15;
        } else {
          want = .78;
        }
      case RiteKind.arena:
        if (guardianAwake && !hasStar(2)) want = .66;
      default:
        break;
    }
    if (a.hp < a.maxHp * .3) want = min(want, .62);
    rites.beatPeriod += (want - rites.beatPeriod) * (1 - exp(-dt / 1.2));
    rites.beatPhase += dt / rites.beatPeriod;
    if (rites.beatPhase >= 1) {
      rites.beatPhase -= rites.beatPhase.floorToDouble();
      rites.beatAt = _time;
      _haptic(DungeonHaptic.heartbeat);
    }
  }

  /// The heart's double thump now, 0 to about 1: a lub as the beat falls
  /// and a smaller dub 0.2s behind it (the portal's shape).
  double get riteBeat {
    final p = _time - rites.beatAt;
    if (p < 0 || p > 1.2) return 0;
    final lub = exp(-p * 14);
    final dub = p < .2 ? 0.0 : .6 * exp(-(p - .2) * 16);
    return lub + dub;
  }

  /// A tap on the room at [world] (see [tapWorld]).
  bool _riteTap(Offset world) =>
      _riteBay?.kind == RiteKind.heart && _heartTap(world);

  // ── The per-frame rules ──────────────────────────────────

  void _updateRites(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isRites) return;
    _riteHeartbeat(a, dt);
    rites.bumpCooldown = max(0, rites.bumpCooldown - dt);
    final bay = room.rite;
    _riteTickMoments(a, room, dt);
    _riteCamera(a, bay, dt);

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
        bay.kind == RiteKind.fire ||
        bay.kind == RiteKind.heart) {
      final j = joystickDirection;
      if (j.distance > 0.2) {
        final sq = riteSquareAt(a.position);
        final mid = riteCentreOf(sq.x, sq.y);
        final k = min(1.0, dt * 12);
        if (j.dx.abs() >= j.dy.abs()) {
          a.position = Offset(
            a.position.dx,
            a.position.dy + (mid.dy - a.position.dy) * k,
          );
        } else {
          a.position = Offset(
            a.position.dx + (mid.dx - a.position.dx) * k,
            a.position.dy,
          );
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
        final wasTurning = rites.flipT < 1;
        rites.flipT = min(1, rites.flipT + dt / kRiteFlipTurn);
        // The runnels run downhill; while the room turns they slow, stop and
        // run back the other way.
        rites.runnel += dt * 38 * _riteWaterSlope;
        // Nothing slides until the room has finished turning over.
        if (rites.flipT >= 1 && (rites.waterFrames.isNotEmpty || wasTurning)) {
          _riteWaterPlay(wasTurning ? 0 : dt);
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
            final st = twinStep(rites.fireRoom, rites.fire, d, freed: _riteFireDone);
            if (st.ok && st.bMoved) _riteFireCommit(st);
          }
          if (rites.fire.b != t && !_riteDoorSquare(room, t)) {
            a.position = riteCentreOf(rites.fire.b.x, rites.fire.b.y);
          }
        }
        final want = riteCentreOf(rites.fire.t.x, rites.fire.t.y);
        rites.twinShown = Offset.lerp(
          rites.twinShown,
          want,
          min(1.0, dt * 14),
        )!;
      case RiteKind.air:
        if (rites.driftT < 1) {
          final n = max(
            1,
            max(rites.driftPath.length, rites.icePath.length) - 1,
          );
          rites.driftT = min(1, rites.driftT + dt * 10 / n);
          if (rites.driftT >= 1) {
            if (rites.iceMelted != null) _riteSublimate();
            if (driftSolved(rites.airRoom, rites.air)) _riteFree('Air');
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
      case RiteKind.heart:
        _heartTick(a, dt);
    }
  }

  /// The Water room's slope: +1 when downhill is south, −1 when north. While
  /// the room turns over it swings from one to the other through level.
  double get _riteWaterSlope {
    final now = rites.water.down == 2 ? 1.0 : -1.0;
    if (rites.flipT >= 1) return now;
    return now * -cos(pi * _riteEase(rites.flipT));
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
    // The seal opens on the Heart once all four cups are full AND the maxim
    // is found (the author, 2026-10-06: "before going to star 2, we should
    // require the maxim to be found to open the door"): the quintessence
    // the four make in the middle is drawn down into the seal, and its
    // leaves draw back. (Sanguorath wakes once Blood is free in the Heart.)
    if (_riteSealOpen && rites.sealT == -1) rites.sealT = _time;
  }

  /// The Circle's seal stands open: all four cups full and the maxim found.
  /// A run that has already been down (Blood taken, or freed) keeps it
  /// open, so nobody is shut out of the Heart or the way to Sanguorath.
  bool get _riteSealOpen =>
      rites.cups.length == 4 &&
      (discoveredClouds.contains(kBloodEggId) ||
          riteHeartFreed ||
          rites.heart.taken);

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
            if (ch == 'c') {
              out.add(([riteCentreOf(x, y) + const Offset(0, 20), at], ice));
            }
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
            rites.grains.add(
              RiteGrain(
                x: c.dx + (_combatRng.nextDouble() - .5) * 26,
                y: c.dy - 6,
                vx: (_combatRng.nextDouble() - .5) * 14,
                vy: -18 - _combatRng.nextDouble() * 20,
                life: 1.4 + _combatRng.nextDouble(),
                color: i % 3 == 0
                    ? const Color(0xFFE8E4E0)
                    : const Color(0xFFB8B0A8),
                lift: 26,
                wander: 22,
                drag: 1.1,
                seed: i * 1.7,
              ),
            );
          }
        } else if (was == 'C' && now == 'c') {
          rites.basinT[k] = _time;
          _cue(SoundCue.dungeonStepWater);
        } else if (was == '_') {
          rites.pitT[k] = _time;
          _cue(
            now == 'p' ? SoundCue.dungeonStepWater : SoundCue.dungeonBlockMove,
          );
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
          rites.grains.add(
            RiteGrain(
              x: c.dx + (_combatRng.nextDouble() - .5) * 40,
              y: c.dy + (_combatRng.nextDouble() - .5) * 30,
              vy: down * (10 + _combatRng.nextDouble() * 20),
              life: .6 + _combatRng.nextDouble() * .5,
              color: i.isEven
                  ? const Color(0xFFBFE8F5)
                  : const Color(0xFF7FC0E8),
              lift: -down * 60,
              wander: 4,
              drag: .6,
            ),
          );
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
      rites.grains.add(
        RiteGrain(
          x: c.dx + cos(a) * r,
          y: c.dy + sin(a) * r,
          vx: cos(a) * 10,
          vy: sin(a) * 10 - 8,
          life: bell != null
              ? 1.3 + _combatRng.nextDouble() * .5
              : 1.6 + _combatRng.nextDouble(),
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
        ),
      );
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
          rites.grains.add(
            RiteGrain(
              x: p.dx + cos(ang) * kRiteCell * 1.5,
              y: p.dy + sin(ang) * kRiteCell * 1.5,
              vx: -sin(ang) * 14 * d.sign,
              vy: cos(ang) * 14 * d.sign,
              life: .7 + _combatRng.nextDouble() * .4,
              color: k.isEven
                  ? const Color(0xFF8A7A70)
                  : const Color(0xFF5E504A),
              lift: -14,
              wander: 6,
              drag: 2.5,
            ),
          );
        }
      }
    } else if (kind == RiteKind.air &&
        rites.driftT < 1 &&
        rites.driftPath.length > 1) {
      // A drift leaves a wake.
      for (var k = 0; k < 2; k++) {
        rites.grains.add(
          RiteGrain(
            x: a.position.dx + (_combatRng.nextDouble() - .5) * 16,
            y: a.position.dy + (_combatRng.nextDouble() - .5) * 16,
            life: .5 + _combatRng.nextDouble() * .4,
            color: k.isEven ? const Color(0xFFDCE6F0) : const Color(0xFFC8283C),
            wander: 10,
            drag: 3,
          ),
        );
      }
    } else if (kind == RiteKind.fire) {
      final r = rites.fireRoom;
      final on = twinPressed(r, rites.fire, freed: _riteFireDone);
      // The gates slide rather than blink.
      for (var y = 0; y < r.h; y++) {
        for (var x = 0; x < r.w; x++) {
          final ch = r.cells[y][x];
          if (!'abc'.contains(ch)) continue;
          final plate = {'a': '1', 'b': '2', 'c': '3'}[ch]!;
          final open =
              on.contains(plate) ||
              rites.fire.b == (x: x, y: y) ||
              rites.fire.t == (x: x, y: y);
          final k = '$x,$y';
          final was = rites.gateShown[k] ?? (open ? 1.0 : 0.0);
          rites.gateShown[k] =
              was + ((open ? 1.0 : 0.0) - was) * min(1.0, dt * 9);
        }
      }
      // The bellows breathe when Blood stands on them.
      rites.puffT -= dt;
      if (r.cells[rites.fire.b.y][rites.fire.b.x] == 'B' && rites.puffT <= 0) {
        rites.puffT = .22;
        final b = riteCentreOf(rites.fire.b.x, rites.fire.b.y);
        final h = _riteCaptiveAt('Fire');
        for (var k = 0; k < 4; k++) {
          rites.grains.add(
            RiteGrain(
              x: b.dx + 20,
              y: b.dy + (_combatRng.nextDouble() - .5) * 10,
              vx: (h.dx - b.dx) * .9,
              vy: (h.dy - b.dy) * .9,
              life: .7,
              color: const Color(0xFFDCEBF2),
              wander: 8,
              drag: 1.4,
            ),
          );
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
        } else if (!_riteSealOpen) {
          _setInsightHint('The seal stays shut');
        } else {
          _setInsightHint('The seal is open');
        }
      case RiteKind.earth:
        // The two element tendrils have no partner of their own colour, so
        // they read as strays (the author, 2026-10-06: "seems random"). Say
        // where they go, and that it is a fusion, before anything else.
        final f = rites.earthFloor;
        final s = rites.earth;
        final jobs = f.jobs(f.grid(s.turns));
        bool joined(String id) => jobs
            .where((j) => j.id == id)
            .every((j) => tendrilJoined(j, s.lines[id]));
        _setInsightHint(
          tendrilSolved(f, s)
              ? 'Every tendril is joined'
              : !joined('d') || !joined('w')
              ? 'Both element tendrils must reach the captive. They fuse there'
              : 'Some tendrils are not joined to their partners',
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
      case RiteKind.heart:
        // What is wrong, and nothing more.
        _setInsightHint(
          rites.heart.freed ? 'Blood is free' : 'Your Blood is bound',
        );
    }
  }

  double get _riteMoodTarget => switch (_riteBay?.kind) {
    RiteKind.arena => 1.0,
    RiteKind.circle => .55,
    _ => .45,
  };
}
