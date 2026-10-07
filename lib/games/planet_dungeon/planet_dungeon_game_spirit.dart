// lib/games/planet_dungeon/planet_dungeon_game_spirit.dart
//
// REQUIA — THE UNFINISHED FUNERAL. Spirit's puzzle logic, as a `part of
// planet_dungeon_game.dart`. The layout and the pure rules live in
// planet_dungeon_layout_spirit.dart; the pictures live in
// planet_dungeon_game_spirit_art.dart. Design: docs/dungeons.md, "SPIRIT —
// THE UNFINISHED FUNERAL: BUILD SPEC" (2026-09-28).
//
// World rule: *ashes keep a memory. Crystal gives it form. Blood gives it a
// pulse.* One loop, taught at the bell and used everywhere after it:
//
//   WATCH the past (automatic, in the ghost world) → CRYSTALLIZE the ashes
//   (Dust + Spirit at the urn, living world, every time) → FIT the crystal
//   in its socket → PULSE it with Blood.
//
//  • Entry — the memorial's arch is drifted with grave-dust; Dust shifts it.
//  • Star 1 (Bell) — the keeper's step: treadle, lever, bell, gate.
//  • Star 2 (Bearers) — nine flags on see-saws. The past shows the bearers'
//    four; the present cannot be levelled whole, so the four must be KNOWN.
//  • Rite — the mourners' three stones of five. The party kneels where the
//    past's mourners knelt, and Blood pulses from one of them.
//  • Star 3 (Vigil) — Wraithord's shadow shields it; a Blood Pip rings the
//    warm chime after each attack it finishes and the shadow parts.
//  • Vault — the keeper's niche, drifted with dust.
//  • Lost Maxim — THE EMPTY URN: the last funeral is yours.
//
// Nothing here is timed, walked for accuracy or left to chance.

part of 'planet_dungeon_game.dart';

/// Requia's lost maxim discovery id (the screen pays 20 gold on first find).
const String kSpiritEmptyUrnEgg = kSpiritEmptyUrnEggId;

// ── Device-tunable knobs ───────────────────────────────────

/// How close a creature must stand to an urn, a socket, a flag, the niche,
/// a stone or the chime to work it.
const double _kFuneralReach = 66.0;

/// How close the second body of the crystal pair must stand to the urn.
const double _kUrnPairReach = 130.0;

/// How close a creature must be to a kneeling stone to count as kneeling.
const double _kStoneReach = 40.0;

/// Seconds of the hard cross-fade when the party passes between worlds.
const double _kFuneralReinkSeconds = 0.30;

/// The bell's remembered step: treadle, lever, bell, gate.
const double _kBellLever = 0.6;
const double _kBellSwing = 1.2;
const double _kBellGate = 2.2;
const double _kBellDone = 3.2;

/// The bearers' echo: how fast it wheels the bier, how long it waits at a
/// tipped flag, and how long it takes to fade back to the doorstep.
const double _kBearerSpeed = 120.0;
const double _kBearerWait = 1.2;
const double _kBearerFade = 0.8;

/// The rite: ghosts rise, the bier lifts, it is carried through the door.
const double _kRiteRise = 1.0;
const double _kRiteLift = 1.6;
const double _kRiteDone = 3.6;
const double _kRiteMiss = 2.0;

/// Wraithord: how long an attack takes to finish (the chime warms after
/// each), and the lesson at the door.
const double _kWraithAttackSeconds = 5.0;
const double _kVigilIntro = 2.6;

/// How long a freshly made crystal shimmers, and the name stone's cutting.
const double _kCraftFlash = 1.1;
const double _kNameCut = 2.4;

/// The engine's clocks for one Requia run. The rules are in [FuneralRun].
class Funeral3D {
  final FuneralRun run = FuneralRun();

  double clock = 0;
  double reink = 0;
  String? lastRoom;

  /// The bell's chain, seconds since the pulse (-1 = still).
  double bellT = -1;

  /// The bearers' echo: distance wheeled, where it stops (null = the door),
  /// and the wait/fade at a tipped flag.
  double walkDist = -1;
  double? walkStop;
  double walkWait = 0;

  /// The rite, and a pulse that found the party wrongly placed.
  double riteT = -1;
  double riteMissT = -1;
  final Set<int> riteMissShown = {};

  /// Wraithord at the chime.
  bool chimeWarm = false;
  double chimeWindow = 0;
  double attackT = 0;
  double introT = -1;

  /// A crystal just made, where, and since when.
  String? craftUrn;
  double craftT = -1;

  /// The maxim's name stone, cutting.
  double nameT = -1;

  bool get chimeHeld => chimeWindow > 0;

  void reset() {
    run.reset();
    clock = 0;
    reink = 0;
    lastRoom = null;
    bellT = -1;
    walkDist = -1;
    walkStop = null;
    walkWait = 0;
    riteT = -1;
    riteMissT = -1;
    riteMissShown.clear();
    chimeWarm = false;
    chimeWindow = 0;
    attackT = 0;
    introT = -1;
    craftUrn = null;
    craftT = -1;
    nameT = -1;
  }
}

extension FuneralDungeon on PlanetDungeonGame {
  FuneralRun get _run => funeral.run;

  // ── Lifecycle ────────────────────────────────────────────

  void _resetFuneralState() {
    if (!_isFuneral) return;
    funeral.reset();
    final r = _run;
    // §5.7: what a banked star made is standing on every later descent.
    if (hasStar(0)) {
      r.bellRung = true;
      r.crystals.add('urn_keeper');
      r.fitted.add('sk_treadle');
    }
    if (hasStar(1)) {
      r.bierArrived = true;
      r.crystals.add('urn_bearers');
      r.fitted.add('sk_doorstep');
      r.flags.settle();
    }
    if (discoveredClouds.contains(kSpiritEmptyUrnEgg)) {
      r.urnFilled = true;
      r.crystals.add('urn_empty');
      r.fitted.add('sk_name');
    }
    if (discoveredClouds.contains(_vaultCacheId)) r.nicheCleared = true;
  }

  // ── Per-frame update ─────────────────────────────────────

  void _updateFuneral(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isFuneral) return;
    final f = funeral;
    f.clock += dt;
    if (f.reink > 0) f.reink = max(0.0, f.reink - dt);
    if (f.craftT >= 0) {
      f.craftT += dt;
      if (f.craftT > _kCraftFlash) f.craftT = -1;
    }
    // LEAVING THE ROOM returns an unfitted crystal to its urn, still made.
    if (f.lastRoom != null && f.lastRoom != room.id) {
      f.run.held = null;
      f.walkDist = -1;
      f.riteMissT = -1;
    }
    f.lastRoom = room.id;
    _updateBell(dt);
    _updateBearers(room, dt);
    _updateRite(room, dt);
    _updateNameStone(dt);
    _updateVigil(room, dt);
  }

  void _updateBell(double dt) {
    final f = funeral;
    if (f.bellT < 0) return;
    final was = f.bellT;
    f.bellT += dt;
    if (was < _kBellSwing && f.bellT >= _kBellSwing) {
      _cue(SoundCue.dungeonGateOpen);
    }
    if (f.bellT >= _kBellDone) {
      f.bellT = -1;
      f.run.bellRung = true;
      if (!hasStar(0)) earnStar(0);
      onChanged();
    }
  }

  void _updateBearers(DungeonRoom room, double dt) {
    final f = funeral;
    if (f.walkDist < 0) return;
    final fr = room.funeral;
    if (fr?.doorstep == null) {
      f.walkDist = -1;
      return;
    }
    final total = _pathLength(fr!.bearerPath);
    final end = f.walkStop ?? total;
    if (f.walkDist < end) {
      f.walkDist = min(end, f.walkDist + _kBearerSpeed * dt);
      return;
    }
    if (f.walkStop == null) {
      // THE WALK FINISHES: the bier is at the chapel door.
      f.walkDist = -1;
      f.run.bierArrived = true;
      if (!hasStar(1)) earnStar(1);
      _cue(SoundCue.dungeonPuzzleSolved);
      onChanged();
      return;
    }
    f.walkWait += dt;
    if (f.walkWait >= _kBearerWait + _kBearerFade) {
      f.walkDist = -1;
      f.walkStop = null;
      f.walkWait = 0;
    }
  }

  void _updateRite(DungeonRoom room, double dt) {
    final f = funeral;
    if (f.riteMissT >= 0) {
      f.riteMissT += dt;
      if (f.riteMissT >= _kRiteMiss) {
        f.riteMissT = -1;
        f.riteMissShown.clear();
      }
    }
    if (f.riteT < 0) return;
    f.riteT += dt;
    if (f.riteT >= _kRiteDone) {
      f.riteT = -1;
      f.run.riteDone = true;
      // The engine's altar reads A and B and wakes the guardian (and speaks
      // the layout's wake line).
      conduitEnergy['A'] = double.infinity;
      conduitEnergy['B'] = double.infinity;
      onChanged();
    }
  }

  void _updateNameStone(double dt) {
    final f = funeral;
    if (f.nameT < 0) return;
    f.nameT += dt;
    if (f.nameT >= _kNameCut) {
      f.nameT = -1;
      final at = layout.rooms['quiet_alcove']?.funeral?.nameStone;
      // THE RITE OF THREE pays the maxim out (see `beginMaximRite`).
      if (at != null) beginMaximRite(kSpiritEmptyUrnEgg, at);
    }
  }

  /// §7 — the guardian fights WITH the planet's rule. Wraithord's shadow is
  /// round it and takes two thirds of every blow; each attack it finishes
  /// warms the chime, which stays warm until used. A Blood pulse at a warm
  /// chime parts the shadow for one full lull. A raid arena carries the
  /// chime too, so the raid fights the same way.
  void _updateVigil(DungeonRoom room, double dt) {
    final f = funeral;
    if (room.funeral?.chime == null || room.guardian == null) return;
    if (!guardianAwake) return;
    if (guardianArriving) return;
    if (f.introT < 0 && !hasStar(room.guardian!.starIndex)) {
      f.introT = 0;
    }
    if (f.introT >= 0 && f.introT < _kVigilIntro) f.introT += dt;
    if (f.chimeWindow > 0) {
      f.chimeWindow = max(0.0, f.chimeWindow - dt);
      guardianVulnerable = true;
      return;
    }
    guardianVulnerable = false;
    f.attackT += dt;
    if (f.attackT >= _kWraithAttackSeconds) {
      f.attackT = 0;
      if (!f.chimeWarm) {
        f.chimeWarm = true;
        onChanged();
      }
    }
  }

  /// Held while the chime's window runs: no strikes, no aura.
  bool get _funeralHoldsGuardian => _isFuneral && funeral.chimeHeld;

  double _pathLength(List<Offset> pts) {
    var d = 0.0;
    for (var i = 1; i < pts.length; i++) {
      d += (pts[i] - pts[i - 1]).distance;
    }
    return d;
  }

  /// The point [d] along [pts].
  Offset _pathPoint(List<Offset> pts, double d) {
    var left = d;
    for (var i = 1; i < pts.length; i++) {
      final seg = (pts[i] - pts[i - 1]).distance;
      if (left <= seg) {
        return Offset.lerp(pts[i - 1], pts[i], seg == 0 ? 1 : left / seg)!;
      }
      left -= seg;
    }
    return pts.last;
  }

  /// Where along the bearers' path the echo stops when the route is not
  /// laid: a step off the doorstep, whichever flag is wrong. (It used to
  /// walk up to the first tipped flag, which let the court be solved by
  /// pulsing and never watching the past.)
  double? _bearerStopFor(FuneralRoom fr) {
    if (_run.flags.routeClear) return null;
    return 46;
  }

  // ── Doors ─────────────────────────────────────────────────

  bool _funeralDoorHidden(DungeonRoom room, DungeonDoor door) {
    if (!_isFuneral) return false;
    if (room.id == layout.entranceRoomId && !entryDoorRevealed) return true;
    return false;
  }

  /// The funeral gate under the bell, and the chapel door at the end of the
  /// bearers' walk. Both shut until their star; both stay open after it.
  bool _funeralDoorBlocked(DungeonRoom room, DungeonDoor door) {
    if (!_isFuneral) return false;
    if (room.id == 'bell_court' && door.targetRoomId == 'bearers_court') {
      return !(_run.bellRung || hasStar(0));
    }
    if (room.id == 'bearers_court' && door.targetRoomId == 'vigil_chapel') {
      return !(_run.bierArrived || hasStar(1));
    }
    return false;
  }

  String _funeralDoorHint(DungeonRoom room, DungeonDoor door) {
    if (door.targetRoomId == 'bearers_court') {
      return 'The funeral gate is shut. The bell has not rung';
    }
    if (door.targetRoomId == 'vigil_chapel') {
      return 'The chapel door is shut. The bier never reached it';
    }
    return 'The way is shut';
  }

  // ── Verbs ────────────────────────────────────────────────

  /// Every Requia verb, in priority order. The memorial stone comes last so
  /// a fixture beside one always wins the press.
  bool _tryFuneralVerb(DungeonCreature a) {
    if (!_isFuneral) return false;
    final fr = currentRoom.funeral;
    if (fr == null) return false;
    return _tryDrift(a, fr) ||
        _tryChime(a, fr) ||
        _tryStonePulse(a, fr) ||
        _tryAlcoveVigil(a, fr) ||
        _trySocket(a, fr) ||
        _tryUrn(a, fr) ||
        _tryFlag(a, fr) ||
        _tryNiche(a, fr) ||
        _tryMemorialStone(a, fr);
  }

  bool _near(DungeonCreature a, Offset? at, [double reach = _kFuneralReach]) =>
      at != null && (a.position - at).distance <= reach;

  /// Physical work belongs to the present. One short line in the past.
  bool _refusePast() {
    if (!_run.isGhost) return false;
    _setBlockedHint('Nothing moves in the past');
    return true;
  }

  /// THE ENTRY RITE: grave-dust drifted up the memorial's arch.
  bool _tryDrift(DungeonCreature a, FuneralRoom fr) {
    if (entryDoorRevealed || !_near(a, fr.drift)) return false;
    if (_refusePast()) return true;
    if (a.member.element != 'Dust') {
      _setBlockedHint('Only Dust can shift this');
      return true;
    }
    entryDoorRevealed = true;
    _cue(SoundCue.dungeonGateOpen);
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist it
    _setHint('The drift slides away from the arch');
    _spawnAlchemyBurst(
      fr.drift!,
      producedElement: 'Dust',
      particleCount: 30,
      intensity: 1.2,
    );
    return true;
  }

  /// THE PASSING — free, both ways, unlimited, at a memorial stone. It costs
  /// nothing and draws nothing out of the dark: watching the past is how
  /// this planet is read.
  bool _tryMemorialStone(DungeonCreature a, FuneralRoom fr) {
    if (!_near(a, fr.memorialStone)) return false;
    if (a.member.element != 'Spirit') {
      _setBlockedHint('Only Spirit can use the memorial stone');
      return true;
    }
    _run.passOver();
    funeral.reink = _kFuneralReinkSeconds;
    // THE ALCOVE KEEPS YOUR PAST: passing into it here leaves the party's
    // echoes where they stand, replacing the last ones.
    if (currentRoomId == 'quiet_alcove' && _run.isGhost) {
      _run.echoes
        ..clear()
        ..addAll([
          for (final c in creatures)
            if (c.alive) (c.position, c.member.element),
        ]);
    }
    _cue(SoundCue.elementSpirit);
    _clearHints();
    _setHint(
      _run.isGhost
          ? 'The past. The funeral is still going on'
          : 'The present. The funeral stopped here',
      2.6,
    );
    _spawnAlchemyBurst(
      fr.memorialStone!,
      producedElement: 'Spirit',
      particleCount: 24,
      intensity: 1.0,
    );
    onChanged();
    return true;
  }

  /// The bodies standing at an urn, by element.
  List<String> _elementsNear(Offset at, double reach) => [
    for (final c in creatures)
      if (c.alive && (c.position - at).distance <= reach) c.member.element,
  ];

  /// THE URN: take up its crystal, crystallize its ashes, or — the empty urn
  /// only — give it something of yourself.
  bool _tryUrn(DungeonCreature a, FuneralRoom fr) {
    final id = fr.urnId;
    if (id == null || !_near(a, fr.urn)) return false;
    if (_refusePast()) return true;
    final r = _run;
    final urn = funeralUrnById(id)!;
    if (r.fitted.contains(urn.socketId)) {
      _setBlockedHint('This urn is empty now');
      return true;
    }
    if (r.crystalAtUrn(id)) {
      if (r.held != null) {
        _setBlockedHint('You are already carrying a memory');
        return true;
      }
      r.held = id;
      _cue(SoundCue.dungeonInteract);
      onChanged();
      return true;
    }
    if (r.held == id) return false; // carried; the socket is the press
    if (!r.canCrystallize(id)) {
      _setBlockedHint('The urn is empty');
      return true;
    }
    final e = a.member.element;
    if (!kFuneralCrystalPair.contains(e) ||
        !funeralPairReady(_elementsNear(fr.urn!, _kUrnPairReach))) {
      _setBlockedHint('The ashes don\'t stir');
      return true;
    }
    // CRYSTALLIZE — every time.
    r.crystals.add(id);
    funeral
      ..craftUrn = id
      ..craftT = 0;
    _cue(SoundCue.dungeonSecretReveal);
    _spawnAlchemyBurst(
      fr.urn!,
      producedElement: 'Crystal',
      reagentElements: kFuneralCrystalPair,
      particleCount: 30,
      intensity: 1.2,
    );
    onChanged();
    return true;
  }

  /// THE SOCKET: fit the carried crystal, or pulse a fitted one with Blood.
  bool _trySocket(DungeonCreature a, FuneralRoom fr) {
    final sk = fr.socket;
    if (sk == null || !_near(a, sk.at)) return false;
    if (_refusePast()) return true;
    final r = _run;
    final fitted = r.fitted.contains(sk.id);
    if (!fitted) {
      final held = r.held;
      if (held == null) {
        _setBlockedHint('The socket is empty');
        return true;
      }
      if (funeralUrnById(held)?.socketId != sk.id) {
        _setBlockedHint('This memory doesn\'t fit here');
        return true;
      }
      r
        ..held = null
        ..fitted.add(sk.id);
      _cue(SoundCue.dungeonSwitch);
      onChanged();
      return true;
    }
    // Pulse — Blood only. The bier's socket is pulsed from the stones.
    if (sk.id == 'sk_bier') return false;
    if (a.member.element != 'Blood') {
      _setBlockedHint('Only Blood can wake it');
      return true;
    }
    switch (sk.id) {
      case 'sk_treadle':
        if (r.bellRung || funeral.bellT >= 0) {
          _setBlockedHint('The bell has rung');
          return true;
        }
        funeral.bellT = 0;
      case 'sk_doorstep':
        if (r.bierArrived) {
          _setBlockedHint('The bier is at the chapel');
          return true;
        }
        if (funeral.walkDist >= 0) return true;
        funeral
          ..walkDist = 0
          ..walkWait = 0
          ..walkStop = _bearerStopFor(fr);
      case 'sk_name':
        if (discoveredClouds.contains(kSpiritEmptyUrnEgg) ||
            funeral.nameT >= 0) {
          return true;
        }
        funeral.nameT = 0;
    }
    _cue(SoundCue.elementBlood);
    _spawnAlchemyBurst(
      sk.at,
      producedElement: 'Blood',
      reagentElements: const ['Crystal'],
      particleCount: 22,
      intensity: 1.0,
    );
    onChanged();
    return true;
  }

  /// A BEARERS' FLAG: any body, living world. It levels (and its partner
  /// tips), or tips (and its partner levels).
  bool _tryFlag(DungeonCreature a, FuneralRoom fr) {
    if (fr.flagOrigin == null) return false;
    int? hit;
    for (var i = 0; i < kBearerCols * kBearerCols; i++) {
      if ((a.position - fr.flagCentre(i)).distance <= fr.flagSize * 0.42) {
        hit = i;
      }
    }
    if (hit == null) return false;
    if (_refusePast()) return true;
    if (_run.bierArrived) {
      _setBlockedHint('The bearers have finished their walk');
      return true;
    }
    if (funeral.walkDist >= 0) return true; // not under their feet
    _run.flags.press(hit);
    _cue(SoundCue.dungeonBlockMove);
    onChanged();
    return true;
  }

  /// THE KEEPER'S NICHE: Dust clears it, and the vault cache is there.
  bool _tryNiche(DungeonCreature a, FuneralRoom fr) {
    if (_run.nicheCleared || !_near(a, fr.niche, _kFuneralReach + 30)) {
      return false;
    }
    if (_refusePast()) return true;
    if (a.member.element != 'Dust') {
      _setBlockedHint('Only Dust can shift this');
      return true;
    }
    _run.nicheCleared = true;
    _cue(SoundCue.dungeonSecretReveal);
    _spawnAlchemyBurst(
      fr.niche!,
      producedElement: 'Dust',
      particleCount: 20,
      intensity: 0.9,
    );
    onChanged();
    return true;
  }

  /// Which stone each creature kneels at, by party slot (null = none).
  List<int?> _kneeling(FuneralRoom fr) => [
    for (final c in creatures)
      if (!c.alive)
        null
      else
        () {
          for (var i = 0; i < fr.stones.length; i++) {
            if ((c.position - fr.stones[i]).distance <= _kStoneReach) return i;
          }
          return null;
        }(),
  ];

  /// Each living creature's kneeling stone (null = none) and its element.
  List<(int?, String)> _kneelingBy(FuneralRoom fr) {
    final at = _kneeling(fr);
    return [
      for (var i = 0; i < creatures.length; i++)
        if (creatures[i].alive) (at[i], creatures[i].member.element),
    ];
  }

  /// THE RITE'S PULSE: Blood, kneeling at a stone, with the mourners'
  /// crystal at the bier's head.
  bool _tryStonePulse(DungeonCreature a, FuneralRoom fr) {
    if (!fr.rite) return false;
    int? on;
    for (var i = 0; i < fr.stones.length; i++) {
      if ((a.position - fr.stones[i]).distance <= _kStoneReach) on = i;
    }
    if (on == null) return false;
    if (_refusePast()) return true;
    if (_run.riteDone || funeral.riteT >= 0) {
      _setBlockedHint('The mourners have gone through');
      return true;
    }
    if (a.member.element != 'Blood') {
      _setBlockedHint('Only Blood can wake the stones');
      return true;
    }
    if (!_run.fitted.contains('sk_bier')) {
      _setBlockedHint('The bier holds no memory yet');
      return true;
    }
    final kneel = _kneelingBy(fr);
    _cue(SoundCue.elementBlood);
    if (mournersMisplaced(kneel) == 0) {
      funeral.riteT = 0;
      _spawnAlchemyBurst(
        fr.bier!,
        producedElement: 'Spirit',
        reagentElements: const ['Blood', 'Crystal'],
        particleCount: 34,
        intensity: 1.3,
      );
    } else {
      // Nothing lifts, and nothing says which place was right: the past is
      // where that is read.
      _setBlockedHint('The bier does not lift');
    }
    onChanged();
    return true;
  }

  /// THE MAXIM'S VIGIL: Blood, kneeling at one of the alcove's six, wakes
  /// them. All six held at once — by your bodies or by the echoes the alcove
  /// kept of you — and the empty urn fills with your ashes.
  bool _tryAlcoveVigil(DungeonCreature a, FuneralRoom fr) {
    if (fr.nameStone == null || fr.stones.isEmpty) return false;
    int? on;
    for (var i = 0; i < fr.stones.length; i++) {
      if ((a.position - fr.stones[i]).distance <= _kStoneReach) on = i;
    }
    if (on == null) return false;
    // Any other hand here is only kneeling — and Spirit kneeling at the
    // west kneeler is also standing at the memorial stone, which must get
    // the press.
    if (a.member.element != 'Blood') return false;
    if (_refusePast()) return true;
    final r = _run;
    if (r.urnFilled || discoveredClouds.contains(kSpiritEmptyUrnEgg)) {
      _setBlockedHint('The urn is full');
      return true;
    }
    final held = _alcoveHeld(fr);
    _cue(SoundCue.elementBlood);
    if (held.length == fr.stones.length) {
      r.urnFilled = true;
      _cue(SoundCue.dungeonSecretReveal);
      _spawnAlchemyBurst(
        fr.urn!,
        producedElement: 'Spirit',
        reagentElements: const ['Blood', 'Dust'],
        particleCount: 36,
        intensity: 1.3,
      );
    } else {
      funeral
        ..riteMissT = 0
        ..riteMissShown.clear()
        ..riteMissShown.addAll(held);
      _setBlockedHint('The urn stays empty');
    }
    onChanged();
    return true;
  }

  /// The alcove's kneelers held right now, by body or by echo.
  Set<int> _alcoveHeld(FuneralRoom fr) => kneelersHeld(
    fr.stones,
    [
      for (final c in creatures)
        if (c.alive) c.position,
    ],
    [for (final (p, _) in _run.echoes) p],
  );

  /// THE VIGIL CHIME — Star 3's counter, and the planet's one hard gate.
  bool _tryChime(DungeonCreature a, FuneralRoom fr) {
    if (!_near(a, fr.chime)) return false;
    final gate = layout.familyGateFor('vigil_chime');
    if (gate != null &&
        (a.member.element != gate.element ||
            abilityForFamily(a.member.family) !=
                abilityForFamily(gate.family))) {
      _stampFamilyGate(gate);
      return true;
    }
    final f = funeral;
    if (!guardianAwake || room0Guardian == null) {
      _setBlockedHint('The chime is still');
      return true;
    }
    if (f.chimeHeld) return true; // never a refresh
    if (!f.chimeWarm) {
      _setBlockedHint('The chime is cold');
      return true;
    }
    f
      ..chimeWarm = false
      ..chimeWindow = _guardianLullSeconds
      ..attackT = 0;
    guardianVulnerable = true;
    _cue(SoundCue.dungeonCheckpoint);
    _spawnAlchemyBurst(
      fr.chime!,
      producedElement: 'Blood',
      reagentElements: const ['Spirit'],
      particleCount: 26,
      intensity: 1.2,
    );
    speakConsequence('The note rings. Wraithord\'s shadow parts', 2.4);
    onChanged();
    return true;
  }

  /// The guardian standing in the current room, if any.
  GuardianNode? get room0Guardian => currentRoom.guardian;

  /// Idle bodies hold where they are left on a kneeling stone.
  bool _funeralHoldsBody(Offset pos, DungeonRoom room) {
    for (final s in room.funeral?.stones ?? const <Offset>[]) {
      if ((pos - s).distance <= _kStoneReach) return true;
    }
    return false;
  }

  // ── The vault ────────────────────────────────────────────

  bool get _funeralVaultLive => _run.nicheCleared;

  // ── Readouts, hints, insight (§5.6) ──────────────────────

  DungeonProgressReadout? _funeralProgressReadout() {
    final r = _run;
    final held = r.held;
    if (held != null) {
      final whose = funeralUrnById(held)?.whose ?? '';
      return DungeonProgressReadout(
        label: 'CARRYING',
        value: whose == 'yours'
            ? 'YOUR MEMORY'
            : '${whose.toUpperCase()}\'S MEMORY',
      );
    }
    if (currentRoom.funeral?.chime != null && guardianAwake) {
      return DungeonProgressReadout(
        label: 'CHIME',
        value: funeral.chimeHeld
            ? 'RINGING'
            : funeral.chimeWarm
            ? 'WARM'
            : 'COLD',
      );
    }
    return null;
  }

  /// GOAL only, never method (§5.6).
  String? _funeralObjectiveHint(DungeonRoom room) {
    final r = _run;
    switch (room.id) {
      case 'memorial':
        return entryDoorRevealed
            ? 'The memorial. A funeral here never finished'
            : 'The arch is drifted shut with grave-dust';
      case 'bell_court':
        return r.bellRung || hasStar(0)
            ? 'The Bell Court. The keeper rests'
            : 'The Bell Court. The funeral gate is shut';
      case 'bearers_court':
        return r.bierArrived || hasStar(1)
            ? 'The Bearers\' Court. The bier is at the chapel'
            : 'The Bearers\' Court. The bier never reached the chapel';
      case 'vigil_chapel':
        return r.riteDone || guardianAwake || hasStar(2)
            ? 'The Vigil Chapel. The mourners have gone through'
            : 'The Vigil Chapel. The bier waits for its mourners';
      case 'quiet_alcove':
        return 'A quiet alcove. The urn here is empty';
      case 'wraithord_vigil':
        return 'Wraithord\'s vigil. The last star is here';
    }
    return null;
  }

  /// AMBIENT — atmosphere only.
  void _funeralAmbientHint(DungeonCreature a, DungeonRoom room) {
    final k = (funeral.clock ~/ 17) % 3;
    if (room.id == 'quiet_alcove') {
      _setAmbientHint(
        _run.isGhost
            ? 'Nobody is here, even now'
            : 'The air in here has been waiting',
      );
      return;
    }
    if (_run.isGhost) {
      _setAmbientHint(switch (k) {
        0 => 'Someone is humming a hymn that never ends',
        1 => 'The candles here have been burning for years',
        _ => 'Your own breath is the only warm thing',
      });
      return;
    }
    _setAmbientHint(switch (k) {
      0 => 'The flowers on the stones turned to dust long ago',
      1 => 'Something rings once, very far off',
      _ => 'The field smells of old smoke and cold stone',
    });
  }

  /// INSIGHT — the HINT button, tiered. BARE: each tier says what is wrong,
  /// shorter at each step; never a recipe and never a method.
  void _funeralReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    final r = _run;
    final fr = room.funeral;
    if (room.id == 'quiet_alcove' &&
        !discoveredClouds.contains(kSpiritEmptyUrnEgg)) {
      _setHint('Nobody mourned here. Nobody but you.', 4.4);
      return;
    }
    if (room.guardian != null) {
      _setInsightHint(switch (tier) {
        0 => 'Wraithord\'s shadow shields it',
        1 => 'Its shadow gathers after every attack',
        _ => funeral.chimeWarm ? 'The chime is warm' : 'The chime is cold',
      });
      return;
    }
    switch (room.id) {
      case 'memorial':
        _setInsightHint(
          entryDoorRevealed
              ? 'A funeral here never finished'
              : 'Grave-dust fills the arch',
        );
        return;
      case 'bell_court':
        if (r.bellRung || hasStar(0)) {
          _setInsightHint(
            r.nicheCleared
                ? 'The keeper rests'
                : 'The keeper\'s niche is full of dust',
          );
          return;
        }
        _setInsightHint(switch (tier) {
          0 => 'The bell must ring to open the gate',
          1 => 'The keeper\'s ashes still remember the step',
          _ => _loopState('urn_keeper', 'sk_treadle', 'The treadle'),
        });
        return;
      case 'bearers_court':
        if (r.bierArrived || hasStar(1)) {
          _setInsightHint('The bearers have finished their walk');
          return;
        }
        final n = r.flags.tippedOnRoute;
        _setInsightHint(switch (tier) {
          0 => 'The bearers never finished their walk',
          1 => n > 0 ? 'Their path is tipped' : 'Their path lies level',
          _ =>
            r.fitted.contains('sk_doorstep')
                ? (n == 0
                      ? 'Their path lies level'
                      : '$n ${n == 1 ? 'flag' : 'flags'} on their path '
                            '${n == 1 ? 'is' : 'are'} tipped')
                : _loopState('urn_bearers', 'sk_doorstep', 'The doorstep'),
        });
        return;
      case 'vigil_chapel':
        if (r.riteDone || guardianAwake) {
          _setInsightHint('The mourners have gone through');
          return;
        }
        final wrong = fr == null ? 0 : mournersMisplaced(_kneelingBy(fr));
        _setInsightHint(switch (tier) {
          0 => 'The mourners never took their places',
          1 => 'Three places at the bier are empty',
          _ =>
            r.fitted.contains('sk_bier')
                ? (wrong == 0
                      ? 'Your party kneels where the mourners knelt'
                      : '$wrong of yours ${wrong == 1 ? 'is' : 'are'} not '
                            'where a mourner knelt')
                : _loopState('urn_mourners', 'sk_bier', 'The bier'),
        });
        return;
    }
    _setInsightHint('A funeral here never finished');
  }

  /// The most specific bare line for where an urn's memory stands: what is
  /// still missing, never how to make it.
  String _loopState(String urnId, String socketId, String what) {
    final r = _run;
    if (r.fitted.contains(socketId)) return '$what\'s memory is still';
    if (r.held == urnId) return '$what\'s socket is empty';
    if (r.crystals.contains(urnId)) return 'The memory is waiting at the urn';
    return '$what\'s socket is empty';
  }

  double get _funeralMoodTarget {
    if (currentRoom.guardian != null) return 0.28;
    return _run.isGhost ? 0.22 : 0.50;
  }

  // ── Planning preview (read-only) ─────────────────────────

  /// The bearers' flag the active creature stands on, or null. Read-only:
  /// the preview and the flip highlight both ask it.
  int? get _flagUnderHand {
    final a = active;
    final fr = currentRoom.funeral;
    if (a == null || fr?.flagOrigin == null) return null;
    for (var i = 0; i < kBearerCols * kBearerCols; i++) {
      if ((a.position - fr!.flagCentre(i)).distance <= fr.flagSize * 0.42) {
        return i;
      }
    }
    return null;
  }

  // ── Test seams ───────────────────────────────────────────

  bool get funeralVaultLiveForTest => _funeralVaultLive;
}
