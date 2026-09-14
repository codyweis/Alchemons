// lib/games/planet_dungeon/planet_dungeon_game_spirit.dart
//
// REQUIA — THE ECHO GRAVE. Spirit's puzzle logic + rendering, as a
// `part of planet_dungeon_game.dart`. The layout, the crossing graph, the six
// dead and the pure rules live in planet_dungeon_layout_spirit.dart; this file
// is the engine.
//
// World rule: *the past replays here, and it cannot be changed. It can only be
// finished.* See the layout header for the full statement of the two worlds,
// the ledger distinctions, the vault trick and the two geometric rules that
// make this the first mutable-world planet since Crystal to need no valve.
//
//  • Entry — the gate arch stands full of black water. WATER draws it off and
//    the field shows (docs §5.5, the eased entry reveal).
//  • Star 0 (Cold Road) — THE BIER. The grave's own funeral has never been
//    able to leave: no LIVING road runs from the lych gate to the cairn.
//    Finishing a death clears the stone off its crossing, and the moment a
//    living road exists end to end the procession walks it. UNGATED — this is
//    the star §4 guarantees to any trio of Spirit/Water/Crystal, because the
//    passing and the telling are both element-only Spirit and the one
//    alternative road is the planet's own braid **Spirit+Water→Ice**.
//  • Star 1 (Hourglass) — THE SIGIL. Each barrow's living floor carries half a
//    sigil on the field's twelve-point ring; the dead see the other half as
//    one great arc struck over the whole round. Exactly one barrow closes the
//    ring, and the mark only takes from a LIVING hand. The answer is in
//    neither world by itself. The mark is the planet's Water+PIP gate (§4).
//  • Star 2 (Wraithord) — MYS14. §7: the guardian fights WITH the planet's
//    rule. Wraithord walks both worlds and is solid in only one at a time; it
//    crosses over on its own beat. While it is in your world it can be struck
//    and it strikes; while it is in the other, nothing either of you does
//    lands. Its arena's lych-stone is the only weapon in the room.
//  • Vault — THE HOLLOW GRAVE, behind a door the living wall does not have,
//    marked only by a name-slot in the mere's living floor.
//  • Lost Maxim — STUFF OF DREAMS: set the mark on your own position, in the
//    UNDUG GRAVE at the far end of the mourners' walk: drawn off by Water,
//    lit by Crystal, and three Spirit tellings — one name per body, because
//    the slot was never cut and there is no name there to tell but your own.
//
// NO VALVE, AND WHY (the design's one real danger). Death as a puzzle verb is
// a stranding machine, and the four mutable-world planets before this one all
// bought their way out with a costly full reset (Ice 120/122, Mud 1200/1284,
// Dust 319/396, Plant 142/448). Requia measures 0 of 2,276 and pays nothing,
// because the field's data satisfies two rules by construction:
//   RULE 1 — the lych road and the drowned cut can never be told, so the ghost
//     world always contains a connected spine carrying three lych-stones;
//   RULE 2 — every one of the six dead is heard out from a barrow ON that
//     spine, so a body can never be standing in the pendant barrow whose last
//     ghost crossing it is closing.
// Both are proved exhaustively over (room × world × state) in
// test/planet_dungeon_spirit_grave_test.dart, together with the counterfactual
// (54 of 369 strandable) that shows the rules are load-bearing, not decoration.

part of 'planet_dungeon_game.dart';

/// Requia's lost maxim discovery id (the screen pays 20 gold on first find).
const String kSpiritStuffOfDreamsEgg = kSpiritStuffOfDreamsEggId;

// ── Device-tunable knobs ───────────────────────────────────
// Spirit has never been on a device; every number the feel depends on is named
// here so a tuning pass is edit-one-block.

/// How close a creature must stand to a lych-stone, a revenant, the grave
/// mouth, the drowned brink, a sigil stone or the grave-lamp to work it.
const double _kGraveReach = 66.0;

/// How close the second body of a braid must stand (§6.14's recipes —
/// they substitute the ELEMENT, never a family).
const double _kGraveBraidReach = 150.0;

/// Seconds the re-ink runs when the party passes over. Short and HARD: §5.5's
/// visual grammar rule — the grave does not transform, it is re-inked, and
/// nothing here may read as a dissolve or a tide.
const double _kGraveReinkSeconds = 0.30;

/// One of the grave's own is drawn out of the dark every this-many passings.
/// The consequence layer (§7: core + consequence + success). It is NOT a
/// budget — nothing runs out, and a run may pass over forever; the field
/// simply notices.
const int _kPassingsPerWisp = 4;

/// How many the field looses at a time.
const int _kWispsPerPassing = 1;

/// Wisps the grave-lamp wakes. Light in a grave is not free (§6.14: "make
/// Light → spirit wisps").
const int _kLampWisps = 2;

/// Seconds Wraithord stays in one world before it crosses over again. Its
/// whole telegraph.
const double _kWraithCrossSeconds = 4.5;

/// Everything one Requia run tracks. ONE field on the engine (the Lava/Poison/
/// Mud/Crystal/Plant pattern): the pure grave rules plus the handful of live
/// timers the rules themselves have no business knowing about.
class EchoGrave3D {
  /// The grave-field, and everything the party has done to it.
  final EchoGraveField field = EchoGraveField();

  double clock = 0;

  /// The re-ink: seconds left on the hard cross-fade between the two inks.
  double reink = 0;

  /// Which world Wraithord is solid in, and its crossing clock.
  GraveWorld wraithWorld = GraveWorld.ghost;
  double wraithCross = 0;

  /// The beat-edge the mystic's strike is detected on.
  bool bitLastFrame = false;

  /// THE UNDUG GRAVE — the Lost Maxim. Drawn off, lit, and the names told
  /// into it (by party slot, so three different bodies are required and one
  /// creature cannot say the same name three times).
  bool undugDrawn = false;
  bool undugLit = false;
  final Set<int> namesTold = {};

  /// THE FIELD, LAID OUT ONCE. A grave-field is grave-cuts, kerbs, fallen
  /// markers and tussocks, none of it on a grid and none of it moving. Built
  /// per room and kept; only the cold light on it changes.
  final Map<String, GraveGround> ground = {};

  void reset() {
    field.reset();
    clock = 0;
    reink = 0;
    wraithWorld = GraveWorld.ghost;
    wraithCross = 0;
    bitLastFrame = false;
    undugDrawn = false;
    undugLit = false;
    namesTold.clear();
  }
}

/// One room's worth of burial ground, in world coordinates.
///
/// THE TWO WORLDS SHARE IT, which is the whole point: the same graves, the
/// same stones, in the same places — and what differs is their CONDITION.
/// In the living field the markers have fallen and the cuts are grassed over;
/// in the cold one the past is intact and the graves are the bright things.
/// A player comparing two worlds needs them to be recognisably one place.
class GraveGround {
  final List<Rect> cuts = [];
  final List<double> cutAngle = [];
  /// Which of the cuts have lost their marker in the living world.
  final List<bool> fallen = [];
  final List<Offset> tussocks = [];
  final List<Offset> kerb = [];
}

extension EchoGraveDungeon on PlanetDungeonGame {
  EchoGraveField get _field => wake.field;

  /// The lych gate's declaration of the two non-guardian stars.
  GraveVigil? get _graveVigil =>
      layout.rooms[layout.entranceRoomId]?.grave?.vigil;

  // ── Lifecycle ────────────────────────────────────────────

  void _resetGraveState() {
    if (!_isWake) return;
    // A creature going down finishes nobody's death and un-tells nothing — the
    // grave is puzzle state like every other planet's, so it resets with the
    // run.
    wake.reset();
  }

  // ── Per-frame update ─────────────────────────────────────

  void _updateGrave(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isWake) return;
    wake.clock += dt;
    if (wake.reink > 0) wake.reink = max(0.0, wake.reink - dt);
    _checkColdRoad();
    _updateWraithord(room, dt);
  }

  /// The Cold Road is a fact about the WORLD STATE, not about a room, so it is
  /// re-asked whenever anything could have changed — a telling two barrows
  /// away opens it just as well as one underfoot.
  void _checkColdRoad() {
    final spec = _graveVigil;
    if (spec == null) return;
    if (_field.coldRoadOpen && !hasStar(spec.roadStarIndex)) {
      earnStar(spec.roadStarIndex);
    }
  }

  /// §7 — the guardian fights WITH the planet's rule. Wraithord is solid in
  /// one world at a time and crosses over on its own beat; the lull only opens
  /// while the party is wearing the same body it is. Nothing else about the
  /// shared lull/strike grammar changes — this narrows WHEN it applies, the
  /// way Prismalith's gap and Bogdrya's quaking floor do.
  void _updateWraithord(DungeonRoom room, double dt) {
    if (room.guardian == null || !guardianAwake) return;
    wake.wraithCross += dt;
    if (wake.wraithCross >= _kWraithCrossSeconds) {
      wake.wraithCross = 0;
      wake.wraithWorld = otherWorld(wake.wraithWorld);
      _setHint(
        wake.wraithWorld == _field.world
            ? 'Wraithord steps into your world, it is solid, and so are you'
            : 'Wraithord steps out of your world, nothing you do reaches it',
        2.2,
      );
    }
    // Out of phase: no lull. The two one-line hooks in planet_dungeon_game.dart
    // do the rest — an out-of-phase Wraithord is frozen (it never acts) and
    // takes no damage, so the fight is harmless in BOTH directions.
    if (!_wraithInPhase) guardianVulnerable = false;
  }

  /// True while the mystic and the party are wearing the same body. The shared
  /// strike path asks this before it lands, so a fight in the wrong world is
  /// harmless in BOTH directions — you cannot hurt it and it cannot hurt you.
  bool get _wraithInPhase => !_isWake || wake.wraithWorld == _field.world;

  // ── The map, in the world you are in ─────────────────────

  /// The crossing a door IS. One room pair, one crossing (pinned by the
  /// tests), so the door the player walks and the edge the proof walks are the
  /// same object and can never drift apart.
  GraveCrossing? _graveCrossingFor(DungeonRoom room, DungeonDoor door) =>
      graveCrossingBetween(room.id, door.targetRoomId);

  /// A ghost-only crossing is not a shut door in the living world — there is
  /// no door there at all. That is literally the vault trick (§5.5: the hollow
  /// grave *exists only in the ghost layer*), and it is also how the two
  /// worlds read as two worlds rather than as one world with locks: the living
  /// grave has never heard of the lych road.
  ///
  /// Everything the two worlds SHARE, they show — a crossing the dead may not
  /// take is visible and refuses out loud, because being told what your body
  /// cannot do is the teaching layer (§5.6 BLOCKED).
  bool _graveDoorHidden(DungeonRoom room, DungeonDoor door) {
    if (!_isWake) return false;
    if (room.id == layout.entranceRoomId && !entryDoorRevealed) return true;
    final x = _graveCrossingFor(room, door);
    if (x == null) return false;
    if (x.cut != GraveCut.ghostOnly) return false;
    if (x.freezable && _field.cutFrozen) return false;
    return !_field.isGhost;
  }

  bool _graveDoorBlocked(DungeonRoom room, DungeonDoor door) {
    if (!_isWake) return false;
    final x = _graveCrossingFor(room, door);
    if (x == null) return false;
    return !_field.crossingOpen(x);
  }

  /// One short clause naming exactly what is missing (§5.6 BLOCKED) — never a
  /// method. How the grave got this way is Mask's earned reading.
  String _graveDoorHint(DungeonRoom room, DungeonDoor door) {
    final x = _graveCrossingFor(room, door)!;
    if (x.cut == GraveCut.livingOnly) return 'Salted, the dead do not cross';
    if (x.cut == GraveCut.ghostOnly) {
      return 'Only a memory of a road, and you are too warm for it';
    }
    if (x.cut == GraveCut.revenant) {
      return _field.isGhost
          ? 'Nothing holds this lintel up any more'
          : 'The stone that killed somebody still lies across it';
    }
    return 'This way is shut';
  }

  // ── Verbs ────────────────────────────────────────────────

  /// Every Spirit verb, in priority order. Returns true when one was consumed.
  /// The lych-stone comes near the end so a fixture standing beside one always
  /// wins the press — except in Wraithord's grave, where the stone IS the
  /// fight and outranks everything (the Ice-pillar / Crystal-plate precedent).
  bool _tryGraveVerb(DungeonCreature a) {
    if (!_isWake) return false;
    return _tryGraveMouth(a) ||
        _tryWraithStone(a) ||
        _tryTelling(a) ||
        _tryDrownedBrink(a) ||
        _tryUndugGrave(a) ||
        _tryGraveSigil(a) ||
        _tryGraveLamp(a) ||
        _tryLychStone(a);
  }

  /// The entry rite: the gate arch stands full of black water, and only Water
  /// draws water.
  bool _tryGraveMouth(DungeonCreature a) {
    final pos = currentRoom.grave?.graveMouth;
    if (pos == null || entryDoorRevealed) return false;
    if ((a.position - pos).distance > _kGraveReach) return false;
    if (a.member.element != 'Water') {
      _setBlockedHint('Only Water draws this off');
      return true;
    }
    entryDoorRevealed = true;
    _cue(SoundCue.dungeonGateOpen);
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist it
    _setHint('The arch drains, and a field of barrows behind it');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Water',
      reagentElements: const ['Spirit'],
      particleCount: 32,
      intensity: 1.25,
    );
    return true;
  }

  /// THE PASSING — the planet's free verb, and the one that makes it a planet.
  /// A Spirit hand at a lych-stone lays the party down, or calls it back. Both
  /// directions, unlimited, no cost: the difficulty of this dungeon lives
  /// entirely in the COMMITMENTS, never in the toggle, and a toggle you can
  /// run out of is a stranding hazard nobody needs (see the file header).
  ///
  /// Where the stones ARE is a different matter — three in the field, at the
  /// gate, the urn and the cairn — and that placement is half the no-strand
  /// proof.
  bool _tryLychStone(DungeonCreature a) {
    final pos = currentRoom.grave?.lychStone;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kGraveReach) return false;
    if (a.member.element != 'Spirit') {
      _setBlockedHint('Only Spirit passes anyone over this stone');
      return true;
    }
    _passOver(pos);
    return true;
  }

  void _passOver(Offset at) {
    final f = _field;
    f.passOver();
    // The single most sensory thing that happens on this planet: the room
    // you are standing in becomes the other world. It gets the wavering
    // Spirit tone rather than the generic interact chirp.
    _cue(SoundCue.elementSpirit);
    wake.reink = _kGraveReinkSeconds;
    _clearHints();
    _setHint(
      f.isGhost
          ? 'You lie down, and get up colder, the grave has more roads than '
                'the field does'
          : 'You are called back warm, and half of what you were walking on '
                'is gone',
      3.0,
    );
    _spawnAlchemyBurst(
      at,
      producedElement: 'Spirit',
      reagentElements: f.isGhost ? const [] : const ['Crystal'],
      particleCount: 26,
      intensity: 1.1,
    );
    // THE CONSEQUENCE (§7). The field notices the traffic. Nothing is spent;
    // the grave simply gets less pleasant to thrash.
    if (f.passings % _kPassingsPerWisp == 0) {
      spawnWispWave(
        element: 'Spirit',
        center: at,
        count: _kWispsPerPassing,
        unstable: true,
        announce: false,
      );
    }
    _checkColdRoad();
    onChanged();
  }

  /// THE TELLING — the planet's one world-edit, and the doc's sentence made
  /// mechanical: *deaths in one open doors in the other.* A Spirit hand in the
  /// COLD world hears out how somebody died, and the death finishes: the stone
  /// comes off the living crossing, and the lintel the dead one was holding
  /// falls in.
  ///
  /// Irreversible for the run. Element-only Spirit, so Star 0 stays inside
  /// §4's first-descent guarantee.
  bool _tryTelling(DungeonCreature a) {
    for (final r in graveRevenantsIn(currentRoomId)) {
      if ((a.position - r.seat).distance > _kGraveReach) continue;
      final f = _field;
      if (f.isRested(r.id)) {
        _setBlockedHint('${r.name} is finished');
        return true;
      }
      if (!f.isGhost) {
        _setBlockedHint('${r.name} does not speak to the warm');
        return true;
      }
      if (a.member.element != 'Spirit') {
        _setBlockedHint('Only Spirit hears one of these out');
        return true;
      }
      f.tell(r.id);
      _cue(SoundCue.dungeonCheckpoint);
      _clearHints();
      _setHint(
        '${r.name} finishes dying, and lets go of the arch it was holding',
        4.0,
      );
      _spawnAlchemyBurst(
        r.seat,
        producedElement: 'Spirit',
        particleCount: 30,
        intensity: 1.2,
      );
      _checkColdRoad();
      onChanged();
      return true;
    }
    return false;
  }

  /// THE DROWNED CUT — §6.14's **Spirit+Water→Ice**, "freeze ghost bridges".
  /// The cut is a road the dead still walk and the living cannot; the cold
  /// settles it into one both of them can. Permanent, and purely additive, so
  /// it can never take a road away from anybody.
  ///
  /// Workable from either world: the cold reaches both, which is the most
  /// Spirit thing on the planet and also the reason it is never a trap.
  bool _tryDrownedBrink(DungeonCreature a) {
    final pos = currentRoom.grave?.drownedBrink;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kGraveReach) return false;
    final f = _field;
    if (f.cutFrozen) {
      _setBlockedHint('The cut is already standing hard');
      return true;
    }
    final direct = a.member.element == 'Ice';
    final braid = _graveBraidReady(a, 'Spirit', 'Water');
    if (!direct && !braid) {
      _setBlockedHint('Only a cold this deep settles black water');
      return true;
    }
    f.cutFrozen = true;
    _cue(SoundCue.elementIce);
    _setHint('The cut goes hard, and the road under it comes up to meet you');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Ice',
      reagentElements: direct ? const [] : const ['Spirit', 'Water'],
      unstable: braid && !direct,
      particleCount: 32,
      intensity: 1.25,
    );
    _checkColdRoad();
    onChanged();
    return true;
  }

  /// Does this creature carry one of Requia's braids, with a live partner near
  /// enough to hand it over? Recipes substitute a missing ELEMENT only (§4).
  bool _graveBraidReady(DungeonCreature a, String left, String right) {
    final e = a.member.element;
    if (e != left && e != right) return false;
    final want = e == left ? right : left;
    return creatures.any(
      (c) =>
          c.alive &&
          !identical(c, a) &&
          c.member.element == want &&
          (c.position - a.position).distance <= _kGraveBraidReach,
    );
  }

  /// THE SIGIL — Star 1, and the planet's Water+PIP hard gate (§4).
  ///
  /// The living half is under your feet; the other half is the great arc the
  /// dead see over the whole round, and the ring only closes in one barrow.
  /// A refused mark costs nothing but the walk: this is a deduction, not a
  /// trap, and brute-forcing all seven is possible and expensive rather than
  /// forbidden (the Earth clue-hunt precedent).
  ///
  /// The mark never takes from a dead hand. That is the star's whole cost —
  /// the answer is read in one world and set in the other.
  bool _tryGraveSigil(DungeonCreature a) {
    final pos = currentRoom.grave?.sigilStone;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kGraveReach) return false;
    final f = _field;
    if (f.sigilStamped) {
      _setBlockedHint('The ring is already closed');
      return true;
    }
    if (f.isGhost) {
      _setBlockedHint('A dead hand leaves no mark');
      return true;
    }
    final gate = layout.familyGateFor('grave_sigil');
    if (gate != null &&
        (a.member.element != gate.element ||
            abilityForFamily(a.member.family) !=
                abilityForFamily(gate.family))) {
      _stampFamilyGate(gate);
      return true;
    }
    f.stampsTried++;
    if (!graveSigilCloses(currentRoomId)) {
      _setBlockedHint('The mark slides off, the halves do not close here');
      onChanged();
      return true;
    }
    f.sigilStamped = true;
    _cue(SoundCue.dungeonPuzzleSolved);
    final spec = _graveVigil;
    if (spec != null && !hasStar(spec.sigilStarIndex)) {
      earnStar(spec.sigilStarIndex);
    }
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Spirit',
      reagentElements: const ['Water'],
      particleCount: 36,
      intensity: 1.35,
    );
    onChanged();
    return true;
  }

  /// THE GRAVE-LAMP — the rite's second half, element-only Crystal, so a party
  /// that brought no Mask meets exactly ONE refusal in the mourners' walk
  /// rather than two (the Ice/Crystal precedent). Lighting it is
  /// **Crystal+Spirit→Light** by fiction and by particle, and light in a grave
  /// wakes what has been sitting in the dark (§6.14).
  bool _tryGraveLamp(DungeonCreature a) {
    final pos = currentRoom.grave?.graveLamp;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kGraveReach) return false;
    if ((conduitEnergy['B'] ?? 0) > 0) return false;
    if (a.member.element != 'Crystal') {
      _setBlockedHint('The lamp answers Crystal alone');
      return true;
    }
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'The lamp will not take, it answers only a bearer of the '
        '${layout.starName(0)} and ${layout.starName(1)}',
      );
      return true;
    }
    conduitEnergy['B'] = double.infinity;
    _cue(SoundCue.dungeonSwitch);
    _setHint('The lamp takes, and something in the dark sits up');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Light',
      reagentElements: const ['Crystal', 'Spirit'],
      particleCount: 30,
      intensity: 1.2,
    );
    spawnWispWave(
      element: 'Spirit',
      center: pos,
      count: _kLampWisps,
      unstable: true,
      announce: false,
    );
    return true;
  }

  /// Wraithord's own stone. In its grave the lych-stone outranks every other
  /// verb, because passing over IS the fight: the mystic is only ever solid in
  /// one world, and matching it is the only way to open a lull. It also holds
  /// the Lost Maxim lives at the far end of the mourners' walk now, not here.
  bool _tryWraithStone(DungeonCreature a) {
    final pos = currentRoom.grave?.wraithStone;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kGraveReach) return false;
    if (a.member.element != 'Spirit') {
      _setBlockedHint('Only Spirit passes anyone over this stone');
      return true;
    }
    _passOver(pos);
    return true;
  }

  /// THE LOST MAXIM — STUFF OF DREAMS, and it is THE UNDUG GRAVE.
  ///
  /// What it was: stand all three bodies anywhere inside the vault room in
  /// the cold world and press. One press, one condition, no chain, no braid,
  /// no repeated beat — and its "place" was the vault's own room, so the
  /// secret and the treasure diluted each other. §7's table graded it ⬜
  /// *"one press"*, which was right.
  ///
  /// What it is: **the seventh funeral, and it is yours.**
  ///
  /// Six dead are heard out on this planet and pass on. At the far end of the
  /// mourners' walk, down 260px of spur no door uses, is a grave somebody
  /// scored out and never dug. In the living world it is bare marked ground.
  /// In the cold one it is open, standing full of black water, with nothing
  /// beside it and — this is the point — NO NAME CUT ANYWHERE ON IT, so the
  /// telling that finishes all six cannot finish this one.
  ///
  ///  1. BE DEAD. The spur is only a grave in the cold world; warm, there is
  ///     nothing there to work. Nothing is pressed for this beat.
  ///  2. WATER draws the black water off — the same job it does at the gate
  ///     arch to open the planet.
  ///  3. CRYSTAL sets a grave-lamp at its head, exactly as the rite's own
  ///     lamp is set, and the light shows the slot is uncut.
  ///  4. SPIRIT, THREE TIMES, ONE BODY EACH — the repeated beat. You cannot
  ///     tell a name that was never cut, so each of the three tells its OWN
  ///     into the grave instead. Slot-tracked, so it is three bodies and not
  ///     one body three times.
  ///  5. The third name lands and the field takes all three.
  ///
  /// Wordless past the HINT button's one line. Nothing is consumed: a wrong
  /// hand gets a burst and a sentence, and dying resets the run's state along
  /// with everything else, never the secret alone.
  bool _tryUndugGrave(DungeonCreature a) {
    final pos = currentRoom.grave?.undugGrave;
    if (pos == null) return false;
    if (discoveredClouds.contains(kSpiritStuffOfDreamsEgg)) return false;
    if ((a.position - pos).distance > _kGraveReach) return false;
    // Warm, there is nothing here but scored turf.
    if (!_field.isGhost) return false;
    final e = a.member.element;

    if (!wake.undugDrawn) {
      if (e != 'Water') {
        _spawnAlchemyBurst(pos, producedElement: e, particleCount: 8,
            intensity: 0.5);
        _setBlockedHint('Black water, standing in a hole nobody finished');
        return true;
      }
      wake.undugDrawn = true;
      _spawnAlchemyBurst(pos, producedElement: 'Water', particleCount: 22,
          intensity: 0.9);
      return true;
    }
    if (!wake.undugLit) {
      if (e != 'Crystal') {
        _spawnAlchemyBurst(pos, producedElement: e, particleCount: 8,
            intensity: 0.5);
        _setBlockedHint('It is too dark in there to read anything');
        return true;
      }
      wake.undugLit = true;
      _spawnAlchemyBurst(pos, producedElement: 'Crystal', particleCount: 22,
          intensity: 0.9);
      return true;
    }
    if (e != 'Spirit') {
      _spawnAlchemyBurst(pos, producedElement: e, particleCount: 8,
          intensity: 0.5);
      _setBlockedHint('The slot is uncut, there is no name here to tell');
      return true;
    }
    // THREE NAMES, ONE PER BODY — but the TELLING is Spirit's verb, as it is
    // for all six of the dead, so the Spirit hand speaks each of them in
    // turn. Demanding three Spirit hands instead would put this secret
    // outside the ideal trio (Spirit · Water · Crystal, one Spirit), and §4
    // guarantees that trio the planet; a maxim may ask for more thought, but
    // never for a party the dungeon told you not to bring.
    final here = [
      for (final c in creatures)
        if (c.alive && (c.position - pos).distance <= _kGraveReach * 2.2) c,
    ];
    if (here.length < 3) {
      _setBlockedHint('A name apiece, and there are not three of you here');
      return true;
    }
    final next = here
        .map((c) => c.member.slotIndex)
        .firstWhere((i) => !wake.namesTold.contains(i), orElse: () => -1);
    if (next < 0) return false;
    wake.namesTold.add(next);
    _spawnAlchemyBurst(pos, producedElement: 'Spirit', particleCount: 26,
        intensity: 1.0);
    _cue(SoundCue.dungeonSwitch);
    if (wake.namesTold.length >= 3) {
      // THE RITE OF THREE pays this out (see `beginMaximRite`).
      beginMaximRite(kSpiritStuffOfDreamsEgg, pos);
      _spawnAlchemyBurst(
        pos,
        producedElement: 'Spirit',
        reagentElements: const ['Water', 'Crystal'],
        particleCount: 42,
        intensity: 1.5,
      );
    }
    return true;
  }

  // ── The vault's one world ────────────────────────────────

  /// The bottled essence is in a room the living world does not contain, so it
  /// can only ever be found by the dead. Guarded in the engine's own cache
  /// check and glow (a party that somehow stood here warm would find nothing,
  /// because there is nothing there).
  bool get _graveVaultLive => _field.isGhost;

  /// Test seam for the vault gate — the cache's whole trick is that only one
  /// of the two worlds holds it, so the proof has to be able to ask.
  bool get graveVaultLiveForTest => _graveVaultLive;

  // ── Readouts, hints, insight (§5.6) ──────────────────────

  /// STATE LEAVES THE CAPSULE (§5.6): counters live beside the star tracker.
  /// The world you are in is not here — it is the whole screen's ink, which is
  /// a stronger readout than any label.
  DungeonProgressReadout? _graveProgressReadout() {
    final spec = _graveVigil;
    final f = _field;
    if (spec != null && !hasStar(spec.roadStarIndex)) {
      return DungeonProgressReadout(
        label: 'FINISHED',
        value: '${f.told}/${kGraveRevenants.length}',
        fraction: f.told / kGraveRevenants.length,
      );
    }
    if (spec != null && !hasStar(spec.sigilStarIndex) && f.stampsTried > 0) {
      return DungeonProgressReadout(
        label: 'MARKS TRIED',
        value: '${f.stampsTried}',
      );
    }
    if (f.passings > 0) {
      return DungeonProgressReadout(label: 'PASSINGS', value: '${f.passings}');
    }
    return null;
  }

  /// GOAL only, never method (§5.6's solution-leak rule). What a telling costs,
  /// which barrow closes the ring and what the mere's blank name-slot is for
  /// are all Mask-insight content.
  String? _graveObjectiveHint(DungeonRoom room) {
    final f = _field;
    if (room.id == layout.entranceRoomId) {
      if (!entryDoorRevealed) return 'The gate arch stands full of water';
      return hasStar(_graveVigil?.roadStarIndex ?? 0)
          ? 'The bier is gone up, and the field is quiet'
          : 'The bier has never left this gate';
    }
    if (room.grave?.graveLamp != null) {
      return 'The mourners\' walk waits on a name and a light';
    }
    if (room.guardian != null) {
      return 'Wraithord is here, and is not always here';
    }
    if (room.vaultCache != null) return 'A grave that was cut and never used';
    if (room.grave?.barrow != true) return null;
    if (graveRevenantsIn(room.id).any((r) => !f.isRested(r.id))) {
      return f.isGhost
          ? 'Somebody here is still dying'
          : 'Somebody died here, and it did not take';
    }
    if (!f.sigilStamped && room.grave?.sigilStone != null) {
      return 'Half a sigil, cut in the floor';
    }
    return null;
  }

  /// AMBIENT — atmosphere only, no mechanics, no families, no requirements.
  void _graveAmbientHint(DungeonCreature a, DungeonRoom room) {
    if (room.guardian != null) {
      _setAmbientHint('The room is holding two of everything');
      return;
    }
    if (_field.isGhost) {
      switch ((wake.clock ~/ 17) % 3) {
        case 0:
          _setAmbientHint('The grass here has not moved in a long time');
        case 1:
          _setAmbientHint('Somebody is walking a road that is not there');
        default:
          _setAmbientHint('Your own breath is the only warm thing left');
      }
      return;
    }
    switch ((wake.clock ~/ 17) % 3) {
      case 0:
        _setAmbientHint('The stones lean the way the wind used to');
      case 1:
        _setAmbientHint('Something goes past, on the other side of the air');
      default:
        _setAmbientHint('The field smells of turned earth and cold water');
    }
  }

  /// INSIGHT — Mask's earned how-to, and the only channel allowed to teach
  /// method (§5.6). §6.14 gave Spirit's Mask the job of reading the hidden
  /// route; §4 forbids gating the first-descent star, so it reads the field
  /// HERE instead of standing at a lock (see the layout's familyGates note).
  void _graveReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    final f = _field;
    // THE UNDUG GRAVE'S ONE OBLIQUE LINE (§7 rule 5) — the only thing in the
    // game that speaks about this secret at all. It does not tier and it
    // does not track progress; it points at the idea and stops. Everything
    // after it is legible from the blank stone standing there.
    final undug = room.grave?.undugGrave;
    if (undug != null &&
        (a.position - undug).distance < 150 &&
        !discoveredClouds.contains(kSpiritStuffOfDreamsEgg)) {
      _setHint(
        'Six were buried here and told. This one was never cut a name, so '
        'nobody can tell it but the one it was dug for.',
        4.4,
      );
      return;
    }
    if (room.guardian != null) {
      _setInsightHint(switch (tier) {
        0 => 'It is never quite in the room with you',
        1 => 'It is solid in one world at a time, and it changes on a count',
        _ =>
          'Nothing lands out of phase, either way. Match the world it is '
              'standing in, and strike in that one. The stone behind you is '
              'the only weapon in here',
      });
      return;
    }
    if (room.grave?.graveLamp != null) {
      _setInsightHint(switch (tier) {
        0 => 'Two things, and the walk wants both',
        1 => 'One is a stone with no name on it; the other is an unlit lamp',
        _ =>
          'Only a second sight reads a nameless stone; the lamp answers any '
              'Crystal, once both stars are yours',
      });
      return;
    }
    if (room.vaultCache != null) {
      _setInsightHint(switch (tier) {
        0 => 'Nobody was ever put in here',
        1 =>
          'Every other grave in the field carries a name-slot. This one '
              'does not',
        _ =>
          'An empty slot takes whatever mark is set in it, and there are '
              'three of you standing in it',
      });
      return;
    }
    final restless = graveRevenantsIn(
      room.id,
    ).where((r) => !f.isRested(r.id)).toList();
    if (restless.isNotEmpty) {
      final r = restless.first;
      _setInsightHint(switch (tier) {
        0 => r.restlessLook,
        1 =>
          '${r.name} is holding up the arch that fell on it, and the '
              'stone that did it is still lying across the warm road',
        _ =>
          'Hear ${r.name} out and it lets go: ${graveCrossingById(r.crossingId)!.look} '
              'opens to the living for good, and shuts to the dead for good. '
              'It does not come back',
      });
      return;
    }
    if (room.grave?.sigilStone != null && !f.sigilStamped) {
      _setInsightHint(switch (tier) {
        0 => 'Half a ring, and half a ring is nothing',
        1 =>
          'The dead carry the other half, one great arc over the whole '
              'field, on a bearing of its own. The two must close the circle',
        _ =>
          'The arc runs on $kGraveFieldBearing; this floor runs on '
              '${kBarrowSigilHalf[room.id] ?? 0}, and only a barrow whose floor '
              'makes twelve of it will take the mark, and only from a warm hand',
      });
      return;
    }
    // Anywhere in the field, insight reads the RULE — which is the planet.
    _setInsightHint(switch (tier) {
      0 => 'There are two of this field, and you are only ever in one',
      1 =>
        'Every road here belongs to the living or to the dead, and never '
            'to both. The stones pass you between them',
      _ =>
        'Six of the roads have not decided yet, and the dead standing on '
            'them are the decision: finish one and it becomes the living\'s '
            'forever. Nothing here is ever lost, but the mere is worth having '
            'in both worlds, and it only has two dead',
    });
  }

  double get _graveMoodTarget {
    if (currentRoom.guardian != null) return _field.isGhost ? 0.14 : 0.26;
    return _field.isGhost ? 0.20 : 0.52;
  }

  // ── Rendering (§5.5 visual grammar) ──────────────────────
  // ONE drawing in TWO INKS. The living grave is warm stone and moss on solid
  // fills; the ghost grave is the same geometry re-struck in cold outline —
  // every surface hollow, every edge doubled a half-pixel out of true. Passing
  // over is a hard cross-fade with no dissolve, no wipe and no blur (the
  // game's known jank source is MaskFilter.blur; there is none here). Nothing
  // in this file may read like Dust's mound heights, Water's tide line or
  // Plant's re-scaled furniture.

  static const Color _graveSod = Color(0xFF2A2A24);
  static const Color _graveStone = Color(0xFF6B6455);
  static const Color _graveMoss = Color(0xFF3E4A33);
  static const Color _graveCold = Color(0xFF8FB6C4);
  static const Color _graveVoid = Color(0xFF090C10);
  static const Color _graveEmber = Color(0xFFD9A24C);

  void _renderGrave(Canvas canvas, DungeonRoom room) {
    final ghost = _field.isGhost;
    // The re-ink: the incoming world comes up hard over the outgoing one.
    final t = wake.reink > 0 ? 1.0 - (wake.reink / _kGraveReinkSeconds) : 1.0;

    // TRANSLUCENT, not opaque (FLOOR TRANSLUCENCY RULE, §8). This was a solid
    // fill, which hid the sky shader completely and left the grave-field a
    // flat brown rectangle — the doubled-world background this planet is
    // built around was being painted over every frame.
    //
    // The two worlds are separated by HOW MUCH they let through, which does
    // the storytelling for free: the living sod is the more solid of the two,
    // and in the ghost world the ground barely exists.
    canvas.drawRect(
      room.bounds,
      Paint()
        ..color = ghost
            ? _graveVoid.withValues(alpha: 0.42)
            : _graveSod.withValues(alpha: 0.58),
    );
    _renderGraveGround(canvas, room, ghost);

    _renderGraveCrossings(canvas, room, ghost, t);
    if (room.grave?.barrow == true) _renderBarrowMound(canvas, room, ghost);
    _renderGraveFixtures(canvas, room, ghost);
  }

  // ── THE BURIAL GROUND ─────────────────────────────────────
  //
  // The floor of this planet was ONE drawRect. A translucent rectangle, one
  // colour per world — which is an odd thing for a dungeon whose entire
  // premise is *two worlds you stand in one at a time and compare*, and it
  // is why its guardian arena measured as the barest room in the game: a
  // wash, a grey bar, and nothing else.
  //
  // The two worlds share the same ground, and that is the device. Same
  // graves, same stones, same places — what differs is their CONDITION. In
  // the LIVING field the markers have fallen, the cuts are grassed over and
  // the turf has closed; in the COLD one the past is intact, the fallen
  // stones are standing again, and the graves are the brightest thing in the
  // room. Crossing over is therefore not a palette swap: it is walking into
  // the same field before it was ruined.

  static const Color _graveTurf = Color(0xFF3A4033);
  static const Color _graveCut = Color(0xFF14140F);

  GraveGround _graveGround(DungeonRoom room) =>
      wake.ground.putIfAbsent(room.id, () => _buildGraveGround(room));

  GraveGround _buildGraveGround(DungeonRoom room) {
    final b = room.bounds.deflate(16);
    final g = GraveGround();
    var seed = (b.width * 29 + b.height * 13).toInt() | 1;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x3FFFFFFF;
      return (seed >> 8) / 0x3FFFFF;
    }

    // GRAVE-CUTS. A burial ground is laid out by people, so there are rows —
    // but it is also mostly EMPTY GROUND, and the first cut of this tiled the
    // room with sixty identical rectangles in visible columns, which is the
    // same graph-paper fault Lightning's floor had and unfightable besides.
    //
    // Two rules fix it. Cuts thin out toward the middle of the room, so every
    // room keeps an open centre to walk and fight in and the graves read as
    // the EDGE of a field rather than its tiling. And no two are the same
    // size: a grave is cut for a body.
    const ch = 34.0;
    final centre = b.center;
    final reach = (b.shortestSide / 2).clamp(1.0, 9999.0);
    for (var y = b.top + 40; y < b.bottom - 40; y += ch + 56) {
      final off = rnd() * 70;
      for (var x = b.left + 26 + off; x < b.right - 90; x += 96 + rnd() * 70) {
        final cw = 56 + rnd() * 34;
        final at = Offset(x + cw / 2, y + ch / 2);
        // Nearer the middle, likelier to be bare ground.
        final open = 1 - ((at - centre).distance / reach).clamp(0.0, 1.0);
        if (rnd() < 0.20 + open * 0.72) continue;
        g.cuts.add(
          Rect.fromLTWH(x, y + (rnd() - 0.5) * 16, cw, ch * (0.8 + rnd() * .4)),
        );
        g.cutAngle.add((rnd() - 0.5) * 0.22);
        g.fallen.add(rnd() < 0.62);
      }
    }
    // The kerb: a low wall of set stones round the round's edge.
    final kerbs = (b.width / 90).clamp(4, 14).toInt();
    for (var i = 0; i < kerbs; i++) {
      g.kerb.add(Offset(b.left + 20 + (b.width - 40) * i / (kerbs - 1), b.bottom));
    }
    final tufts = (b.width * b.height / 24000).clamp(6, 28).toInt();
    for (var i = 0; i < tufts; i++) {
      g.tussocks.add(
        Offset(
          b.left + rnd() * b.width,
          b.top + rnd() * b.height,
        ),
      );
    }
    return g;
  }

  void _renderGraveGround(Canvas canvas, DungeonRoom room, bool ghost) {
    final g = _graveGround(room);
    final t = wake.clock;

    for (var i = 0; i < g.cuts.length; i++) {
      final cut = g.cuts[i];
      final c = cut.center;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(g.cutAngle[i]);
      final local = Rect.fromCenter(
        center: Offset.zero,
        width: cut.width,
        height: cut.height,
      );
      if (ghost) {
        // THE COLD FIELD. The grave is the lit thing — the dead are what is
        // solid here — and it breathes very slowly.
        final glow = 0.16 + 0.05 * sin(t * 0.7 + i);
        canvas.drawRect(
          local,
          Paint()..color = _graveCold.withValues(alpha: glow),
        );
        canvas.drawRect(
          local,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = _graveCold.withValues(alpha: 0.55),
        );
      } else {
        // THE LIVING FIELD. The cut has grassed over; what is left is a
        // depression in the turf with a shadow in it.
        canvas.drawRRect(
          RRect.fromRectAndRadius(local, const Radius.circular(5)),
          Paint()..color = _graveCut.withValues(alpha: 0.38),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(local.deflate(5), const Radius.circular(4)),
          Paint()..color = _graveTurf.withValues(alpha: 0.34),
        );
      }
      canvas.restore();

      // THE MARKER. Fallen in the living world and standing in the cold one —
      // the same stone, before and after. This is the comparison the planet
      // is made of, said without a word.
      final head = Offset(c.dx, cut.top - 4);
      if (ghost) {
        final stone = Path()
          ..moveTo(head.dx - 9, head.dy)
          ..lineTo(head.dx - 7, head.dy - 26)
          ..quadraticBezierTo(head.dx, head.dy - 33, head.dx + 8, head.dy - 25)
          ..lineTo(head.dx + 10, head.dy)
          ..close();
        canvas.drawPath(
          stone,
          Paint()..color = _graveCold.withValues(alpha: 0.30),
        );
        canvas.drawPath(
          stone,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = _graveCold.withValues(alpha: 0.7),
        );
        // A NAME, CUT. Two or three scratches is all it takes to read as
        // lettering at this size — and it has to be there, because the Lost
        // Maxim's whole tell is one headstone in the field that is BLANK.
        // A blank stone among blank stones says nothing at all.
        for (var k = 0; k < 2 + (i % 2); k++) {
          canvas.drawLine(
            Offset(head.dx - 5, head.dy - 20 + k * 6),
            Offset(head.dx + 5, head.dy - 20.5 + k * 6),
            Paint()
              ..strokeWidth = 1.1
              ..color = _graveCold.withValues(alpha: 0.45),
          );
        }
      } else if (g.fallen[i]) {
        // Down in the grass, face up, half swallowed.
        canvas.save();
        canvas.translate(head.dx, head.dy - 3);
        canvas.rotate(1.3 + g.cutAngle[i]);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 26, height: 17),
            const Radius.circular(3),
          ),
          Paint()..color = _graveStone.withValues(alpha: 0.34),
        );
        canvas.restore();
      } else {
        // Still up, but leaning.
        canvas.save();
        canvas.translate(head.dx, head.dy);
        canvas.rotate(g.cutAngle[i] * 2.2);
        canvas.drawPath(
          Path()
            ..moveTo(-8, 0)
            ..lineTo(-6, -24)
            ..quadraticBezierTo(0, -30, 7, -23)
            ..lineTo(9, 0)
            ..close(),
          Paint()..color = _graveStone.withValues(alpha: 0.42),
        );
        canvas.restore();
      }
    }

    // THE SPUR. Where a room carries the undug grave, its last stretch is a
    // dead cut nobody finished: the field's verge closes in past the last
    // fixture and simply stops, so the walk reads as somewhere that goes
    // nowhere rather than as more room (§9.6 — a maxim has to be a PLACE,
    // and a place has edges).
    final undug = room.grave?.undugGrave;
    if (undug != null) {
      final b = room.bounds;
      final mouth = undug.dx - 150;
      for (final side in [-1.0, 1.0]) {
        final y0 = b.center.dy + side * b.height * 0.42;
        final y1 = b.center.dy + side * b.height * 0.20;
        canvas.drawPath(
          Path()
            ..moveTo(mouth, y0)
            ..quadraticBezierTo(mouth + 90, y0, undug.dx + 60, y1)
            ..lineTo(b.right - 14, y1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = (ghost ? _graveCold : _graveStone).withValues(
              alpha: ghost ? 0.28 : 0.34,
            ),
        );
      }
    }

    // The kerb round the field's edge.
    for (final k in g.kerb) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: k, width: 46, height: 13),
          const Radius.circular(3),
        ),
        Paint()
          ..color = (ghost ? _graveCold : _graveStone).withValues(
            alpha: ghost ? 0.22 : 0.3,
          ),
      );
    }

    // Living grass, or the cold drifting through where it used to be.
    for (var i = 0; i < g.tussocks.length; i++) {
      final o = g.tussocks[i];
      if (ghost) {
        final ph = ((t * 0.12 + i * 0.09) % 1.0);
        canvas.drawCircle(
          o.translate(0, -ph * 26),
          1.5,
          Paint()..color = _graveCold.withValues(alpha: 0.18 * (1 - ph)),
        );
        continue;
      }
      final sway = sin(t * 0.8 + i * 1.9) * 2;
      for (var k = -1; k <= 1; k++) {
        canvas.drawLine(
          o,
          o + Offset(sway + k * 3.5, -8 - (k == 0 ? 3 : 0)),
          Paint()
            ..strokeWidth = 1.2
            ..color = _graveTurf.withValues(alpha: 0.75),
        );
      }
    }
  }

  /// The crossings, drawn on the wall they pierce. A road the other world owns
  /// is drawn as a GHOST OF ITSELF — hairline, doubled, out of true — so the
  /// player can always see what the other body would have had.
  void _renderGraveCrossings(
    Canvas canvas,
    DungeonRoom room,
    bool ghost,
    double t,
  ) {
    for (final door in room.doors) {
      final x = _graveCrossingFor(room, door);
      if (x == null) continue;
      final open = _field.crossingOpen(x);
      final other = _field.openTo(x, otherWorld(_field.world));
      final r = door.rect.inflate(3);
      if (open) {
        canvas.drawRect(
          r,
          Paint()
            ..color = (ghost ? _graveCold : _graveEmber).withValues(
              alpha: 0.30 * t,
            ),
        );
        continue;
      }
      // Shut here. If the other world has it, show that — doubled and cold.
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = (other ? _graveCold : _graveStone).withValues(
          alpha: other ? 0.55 : 0.25,
        );
      canvas.drawRect(r, p);
      if (other) canvas.drawRect(r.shift(const Offset(1.5, -1.5)), p);
    }
  }

  /// The barrow itself: a long mound with a kerb. Solid and mossed in the
  /// living ink; hollow and doubled in the cold one.
  void _renderBarrowMound(Canvas canvas, DungeonRoom room, bool ghost) {
    final c = room.bounds.center;
    final mound = Rect.fromCenter(
      center: c,
      width: room.bounds.width * 0.52,
      height: room.bounds.height * 0.34,
    );
    if (!ghost) {
      // A BARROW IS A HILL, and this was a flat olive ellipse lying on the
      // floor — the biggest thing in the room, with no height in it at all.
      // Shadow, body, a lit crown where the turf catches the sky, and the
      // kerb of set stones that holds the whole mound in.
      canvas.drawOval(
        mound.shift(const Offset(0, 9)),
        Paint()..color = Colors.black.withValues(alpha: 0.30),
      );
      canvas.drawOval(mound, Paint()..color = _graveMoss);
      canvas.drawOval(
        mound.deflate(mound.height * 0.18).shift(Offset(0, -mound.height * .12)),
        Paint()..color = Color.lerp(_graveMoss, _graveTurf, 0.45)!,
      );
      // The kerb: stones set on end round the foot, thinning at the sides.
      for (var i = 0; i < 18; i++) {
        final a = i / 18 * pi * 2;
        final p = Offset(
          c.dx + cos(a) * mound.width / 2,
          c.dy + sin(a) * mound.height / 2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: p, width: 15, height: 11),
            const Radius.circular(3),
          ),
          Paint()
            ..color = _graveStone.withValues(
              alpha: 0.18 + 0.22 * (sin(a) * 0.5 + 0.5),
            ),
        );
      }
      // The mouth: every barrow has a way in, and it is shut.
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 22, c.dy + mound.height * 0.42)
          ..lineTo(c.dx - 17, c.dy + mound.height * 0.14)
          ..lineTo(c.dx + 17, c.dy + mound.height * 0.14)
          ..lineTo(c.dx + 22, c.dy + mound.height * 0.42)
          ..close(),
        Paint()..color = _graveCut.withValues(alpha: 0.75),
      );
      return;
    }
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = _graveCold.withValues(alpha: 0.5);
    canvas.drawOval(mound, p);
    canvas.drawOval(mound.shift(const Offset(2, -2)), p);
    // The great arc the dead see over the whole round (Star 1's other half).
    if (!_field.sigilStamped) _renderFieldArc(canvas, room);
  }

  /// THE UNDUG GRAVE — the Lost Maxim's place, and it has to look like
  /// somewhere nobody finished rather than like a puzzle.
  ///
  /// Warm: four scoring marks in the turf where a grave was set out, and
  /// nothing else. Cold: the same outline, open, standing full of black
  /// water until Water draws it off — and with an UNCUT HEADSTONE, blank
  /// where every other marker in the field carries a name. That blank is the
  /// whole secret stated in one object: the telling that finishes all six of
  /// the dead has nothing here to work on.
  void _renderUndugGrave(Canvas canvas, Offset at, bool ghost) {
    final cut = Rect.fromCenter(center: at, width: 86, height: 40);
    if (!ghost) {
      // Scored out and abandoned: four corner marks, no grave.
      for (var i = 0; i < 4; i++) {
        final c = [
          cut.topLeft,
          cut.topRight,
          cut.bottomRight,
          cut.bottomLeft,
        ][i];
        final dx = i == 0 || i == 3 ? 13.0 : -13.0;
        final dy = i < 2 ? 13.0 : -13.0;
        canvas.drawLine(
          c,
          c.translate(dx, 0),
          Paint()
            ..strokeWidth = 1.6
            ..color = _graveStone.withValues(alpha: 0.35),
        );
        canvas.drawLine(
          c,
          c.translate(0, dy),
          Paint()
            ..strokeWidth = 1.6
            ..color = _graveStone.withValues(alpha: 0.35),
        );
      }
      return;
    }
    // Open, and deeper than the others.
    canvas.drawRect(cut, Paint()..color = _graveCut.withValues(alpha: 0.9));
    canvas.drawRect(
      cut,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _graveCold.withValues(alpha: 0.6),
    );
    if (!wake.undugDrawn) {
      // Black water, with the cold barely moving on it.
      final sheen = sin(wake.clock * 0.6) * 3;
      canvas.drawRect(
        cut.deflate(4),
        Paint()..color = const Color(0xFF0A1418).withValues(alpha: 0.92),
      );
      canvas.drawLine(
        Offset(cut.left + 12, at.dy + sheen),
        Offset(cut.right - 14, at.dy + sheen - 1),
        Paint()
          ..strokeWidth = 1.2
          ..color = _graveCold.withValues(alpha: 0.22),
      );
    }
    // THE UNCUT HEADSTONE. Every other marker in this field carries a name;
    // this one is blank, and that is the secret said in one object.
    final head = Offset(at.dx, cut.top - 6);
    final stone = Path()
      ..moveTo(head.dx - 12, head.dy)
      ..lineTo(head.dx - 10, head.dy - 34)
      ..quadraticBezierTo(head.dx, head.dy - 43, head.dx + 11, head.dy - 33)
      ..lineTo(head.dx + 13, head.dy)
      ..close();
    canvas.drawPath(
      stone,
      Paint()..color = _graveCold.withValues(alpha: wake.undugLit ? .40 : .26),
    );
    canvas.drawPath(
      stone,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _graveCold.withValues(alpha: wake.undugLit ? 0.95 : 0.6),
    );
    if (wake.undugLit) {
      // The lamp at its head, and the light it throws up the blank face.
      canvas.drawCircle(
        head.translate(-26, -8),
        5,
        Paint()..color = const Color(0xFFE4C16A).withValues(alpha: 0.9),
      );
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          head.translate(-26, -8),
          head.translate(-14 + i * 10.0, -34.0),
          Paint()
            ..strokeWidth = 1
            ..color = const Color(0xFFE4C16A).withValues(alpha: 0.16),
        );
      }
    }
    // One mark per name already given, cut into the face as they land.
    for (var i = 0; i < wake.namesTold.length; i++) {
      canvas.drawLine(
        Offset(head.dx - 7, head.dy - 26 + i * 8),
        Offset(head.dx + 7, head.dy - 27 + i * 8),
        Paint()
          ..strokeWidth = 1.8
          ..color = const Color(0xFFE4C16A).withValues(alpha: 0.85),
      );
    }
  }

  /// The GHOST half of the sigil: one arc struck over the field on
  /// [kGraveFieldBearing], legible from any barrow because the dead do not
  /// have to be near a thing to see it.
  void _renderFieldArc(Canvas canvas, DungeonRoom room) {
    final c = room.bounds.center;
    final radius = room.bounds.shortestSide * 0.40;
    final start = (kGraveFieldBearing / 12.0) * pi * 2;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = _graveCold.withValues(alpha: 0.75);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      start,
      pi,
      false,
      p,
    );
    for (var i = 0; i < 12; i++) {
      final a = (i / 12.0) * pi * 2;
      final tick = Offset(cos(a), sin(a));
      canvas.drawLine(
        c + tick * (radius - 6),
        c + tick * radius,
        Paint()
          ..strokeWidth = 1
          ..color = _graveCold.withValues(
            alpha: i == kGraveFieldBearing ? 0.9 : 0.28,
          ),
      );
    }
  }

  void _renderGraveFixtures(Canvas canvas, DungeonRoom room, bool ghost) {
    final g = room.grave;
    if (g == null) return;
    final ink = ghost ? _graveCold : _graveStone;
    if (g.undugGrave != null) _renderUndugGrave(canvas, g.undugGrave!, ghost);

    // THE LYCH-STONE: a low kerbed slab, long enough to lie on.
    final stone = g.lychStone ?? g.wraithStone;
    if (stone != null) {
      final r = Rect.fromCenter(center: stone, width: 96, height: 34);
      canvas.drawRect(r, Paint()..color = ink.withValues(alpha: 0.8));
      canvas.drawRect(
        r.deflate(5),
        Paint()
          ..color = (ghost ? _graveVoid : _graveSod).withValues(alpha: 0.6),
      );
    }

    // THE SIGIL STONE: the living half only, and only to a warm eye.
    final sig = g.sigilStone;
    if (sig != null && !ghost && !_field.sigilStamped) {
      final half = kBarrowSigilHalf[room.id] ?? 0;
      final a = (half / 12.0) * pi * 2;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = _graveEmber.withValues(alpha: 0.75);
      canvas.drawArc(Rect.fromCircle(center: sig, radius: 26), a, pi, false, p);
    }

    // THE DEAD, where they are still dying.
    for (final r in graveRevenantsIn(room.id)) {
      final rested = _field.isRested(r.id);
      if (rested) {
        canvas.drawCircle(
          r.seat,
          10,
          Paint()..color = ink.withValues(alpha: 0.35),
        );
        continue;
      }
      // Only the dead SEE the dead. Warm eyes get a cold spot and no more.
      final alpha = ghost ? 0.85 : 0.22;
      final bob = sin(wake.clock * 1.6 + r.seat.dx) * 3.0;
      final at = r.seat + Offset(0, bob);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _graveCold.withValues(alpha: alpha);
      canvas.drawCircle(at, 16, p);
      canvas.drawCircle(
        at,
        22,
        p..color = _graveCold.withValues(alpha: alpha * 0.45),
      );
    }

    // THE DROWNED BRINK, and the grave mouth, and the lamp.
    final brink = g.drownedBrink;
    if (brink != null) {
      final r = Rect.fromCenter(center: brink, width: 130, height: 26);
      canvas.drawRect(
        r,
        Paint()
          ..color = _field.cutFrozen
              ? _graveCold.withValues(alpha: 0.55)
              : _graveVoid.withValues(alpha: 0.85),
      );
    }
    final mouth = g.graveMouth;
    if (mouth != null && !entryDoorRevealed) {
      canvas.drawRect(
        Rect.fromCenter(center: mouth, width: 150, height: 40),
        Paint()..color = _graveVoid.withValues(alpha: 0.9),
      );
    }
    final lamp = g.graveLamp;
    if (lamp != null) {
      final lit = (conduitEnergy['B'] ?? 0) > 0;
      canvas.drawCircle(
        lamp,
        13,
        Paint()..color = lit ? _graveEmber : ink.withValues(alpha: 0.55),
      );
    }
  }
}
