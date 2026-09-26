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
    // A WON STAR DRAWS WON: the sigil stays set after a fall or on a new
    // descent. (The Cold Road is a fact about the field and banks once.)
    final spec = _graveVigil;
    if (spec != null && hasStar(spec.sigilStarIndex)) {
      _field.sigilStamped = true;
    }
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
      // A CONSEQUENCE (§5.7): this runs from update, where a plain line is
      // dropped unasked — and whether it can be hit is the whole fight.
      speakConsequence(
        wake.wraithWorld == _field.world
            ? 'Wraithord steps into your world. You can hit it, and it can '
                  'hit you'
            : 'Wraithord steps out of your world. Pass over at the stone to '
                  'follow it',
        2.4,
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
    if (x.cut == GraveCut.livingOnly) {
      return 'Salted. Only the living can cross';
    }
    if (x.cut == GraveCut.ghostOnly) {
      return 'This road only exists in the world of the dead';
    }
    if (x.cut == GraveCut.revenant) {
      return _field.isGhost
          ? 'This road has closed to the dead'
          : 'A fallen stone blocks it. Lay its ghost to rest first';
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
      _setBlockedHint('Only Water can drain this');
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
      _setBlockedHint('Only Spirit can use this lych-stone');
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
        _setBlockedHint('${r.name} is at rest');
        return true;
      }
      if (!f.isGhost) {
        _setBlockedHint('${r.name} only speaks in the world of the dead');
        return true;
      }
      if (a.member.element != 'Spirit') {
        _setBlockedHint('Only Spirit can hear a ghost out');
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
      _setBlockedHint('The cut is already frozen');
      return true;
    }
    final direct = a.member.element == 'Ice';
    final braid = _graveBraidReady(a, 'Spirit', 'Water');
    if (!direct && !braid) {
      _setBlockedHint('This needs Ice, or Spirit and Water together');
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
      _setBlockedHint('The sigil is already complete');
      return true;
    }
    if (f.isGhost) {
      _setBlockedHint('Only the living can set the mark');
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
      _setBlockedHint('The halves don\'t add up here. Try another barrow');
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
      _setBlockedHint('Only Crystal can light the lamp');
      return true;
    }
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'The lamp needs the ${layout.starName(0)} and '
        '${layout.starName(1)} first',
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
      _setBlockedHint('Only Spirit can use this lych-stone');
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
        _spawnAlchemyBurst(
          pos,
          producedElement: e,
          particleCount: 8,
          intensity: 0.5,
        );
        _setBlockedHint('Black water fills this unfinished grave');
        return true;
      }
      wake.undugDrawn = true;
      _spawnAlchemyBurst(
        pos,
        producedElement: 'Water',
        particleCount: 22,
        intensity: 0.9,
      );
      return true;
    }
    if (!wake.undugLit) {
      if (e != 'Crystal') {
        _spawnAlchemyBurst(
          pos,
          producedElement: e,
          particleCount: 8,
          intensity: 0.5,
        );
        _setBlockedHint('Too dark in there to read anything');
        return true;
      }
      wake.undugLit = true;
      _spawnAlchemyBurst(
        pos,
        producedElement: 'Crystal',
        particleCount: 22,
        intensity: 0.9,
      );
      return true;
    }
    if (e != 'Spirit') {
      _spawnAlchemyBurst(
        pos,
        producedElement: e,
        particleCount: 8,
        intensity: 0.5,
      );
      _setBlockedHint('There\'s no name here to tell');
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
      _setBlockedHint('It needs one name from each of your three');
      return true;
    }
    final next = here
        .map((c) => c.member.slotIndex)
        .firstWhere((i) => !wake.namesTold.contains(i), orElse: () => -1);
    if (next < 0) return false;
    wake.namesTold.add(next);
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Spirit',
      particleCount: 26,
      intensity: 1.0,
    );
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
      if (!entryDoorRevealed) return 'The gate arch is full of black water';
      return hasStar(_graveVigil?.roadStarIndex ?? 0)
          ? 'The Lych Gate. The bier stands empty'
          : 'The Lych Gate. The bier needs a living road to the cairn';
    }
    if (room.grave?.graveLamp != null) {
      return 'The Mourners\' Walk. The rite happens here';
    }
    if (room.guardian != null) {
      return 'Wraithord\'s grave. The last star is here';
    }
    if (room.vaultCache != null) {
      return 'An unused grave. Something is stored here';
    }
    if (room.grave?.barrow != true) return null;
    if (graveRevenantsIn(room.id).any((r) => !f.isRested(r.id))) {
      return f.isGhost
          ? 'A ghost here is still reliving its death'
          : 'Someone died here. Their ghost is still here';
    }
    if (!f.sigilStamped && room.grave?.sigilStone != null) {
      return 'Half a sigil is cut into the floor';
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
        'Six were buried and named here. This grave has no name, so only '
        'whoever it was dug for can tell it.',
        4.4,
      );
      return;
    }
    if (room.guardian != null) {
      _setInsightHint(switch (tier) {
        0 => 'Wraithord is only solid in one world at a time',
        1 => 'It switches worlds on a steady count',
        _ =>
          'Neither of you can hit the other from different worlds. Use the '
              'lych-stone to match its world, then strike',
      });
      return;
    }
    if (room.grave?.graveLamp != null) {
      _setInsightHint(switch (tier) {
        0 => 'The rite needs the name stone and the lamp',
        1 => 'A Spirit Mask reads the stone. Crystal lights the lamp',
        _ =>
          'A Spirit Mask reads the nameless stone. Any Crystal lights the '
              'lamp once you have both stars',
      });
      return;
    }
    if (room.vaultCache != null) {
      _setInsightHint(switch (tier) {
        0 => 'Nobody was ever buried here',
        1 => 'Every other grave has a name-slot. This one doesn\'t',
        _ => 'An empty slot takes any mark set in it',
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
          '${r.name}\'s ghost is still here. The stone that killed it blocks '
              'the living road',
        _ =>
          'In the world of the dead, have Spirit hear ${r.name} out. '
              '${graveCrossingById(r.crossingId)!.look} then opens to the '
              'living and closes to the dead, for good',
      });
      return;
    }
    if (room.grave?.sigilStone != null && !f.sigilStamped) {
      _setInsightHint(switch (tier) {
        0 => 'Half a sigil. The other half is in the world of the dead',
        1 =>
          'The dead see one big arc over the whole field. Your half and '
              'theirs must close the ring',
        _ =>
          'Their arc is $kGraveFieldBearing and this floor is '
              '${kBarrowSigilHalf[room.id] ?? 0}. Only a barrow that adds up '
              'to 12 takes the mark, set by a living Water Pip',
      });
      return;
    }
    // Anywhere in the field, insight reads the RULE — which is the planet.
    _setInsightHint(switch (tier) {
      0 => 'This field exists in two worlds, living and dead',
      1 =>
        'Each road belongs to the living or the dead, never both. Lych-stones '
            'move you between worlds',
      _ =>
        'Six roads are blocked by ghosts. Laying one to rest gives its road '
            'to the living for good. The mere is worth reaching in both '
            'worlds first',
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

  // MOONLIT, NOT MUDDY (2026-09-25, from the author: "spirit's colors don't
  // look mystical"). The living field was khaki stone and olive moss on
  // brown sod — an overcast afternoon. It is a field under the moon now:
  // blue-slate ground, silver stone, blue-green moss; and the cold is a
  // luminous aqua rather than a greyed cyan. Warm accents (the sigil's
  // ember, the lamp) stay gold, and are the only warm things here.
  static const Color _graveSod = Color(0xFF131926);
  static const Color _graveStone = Color(0xFF7A8294);
  static const Color _graveMoss = Color(0xFF1E383C);
  static const Color _graveCold = Color(0xFF7FE0DA);
  static const Color _graveVoid = Color(0xFF04050C);
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
    // The churchyard wall, baked (planet_dungeon_game_spirit_art.dart).
    _renderGraveShell(canvas, room);
    _renderGlassDoorPlugs(canvas, room);
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

  static const Color _graveTurf = Color(0xFF1D2A34);
  static const Color _graveCut = Color(0xFF070910);

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
        // THE CLEARING (2026-09-25 review): a field of sixty graves nobody
        // could use was clutter. A few stay, against the walls, so the two
        // worlds still show one place before and after (fallen here,
        // standing there) — and so the undug grave's blank stone still has
        // named ones to be blank among.
        if (at.dy > b.top + 70 && at.dy < b.bottom - 70) continue;
        if (g.cuts.length >= 4) continue;
        g.cuts.add(
          Rect.fromLTWH(x, y + (rnd() - 0.5) * 16, cw, ch * (0.8 + rnd() * .4)),
        );
        g.cutAngle.add((rnd() - 0.5) * 0.22);
        g.fallen.add(rnd() < 0.62);
      }
    }
    // (The kerb stones along the edge and the grass tufts are gone: the
    // churchyard wall is the edge, and nothing else on the ground is used.)
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
    // A glass doorway says open or shut itself, and the other world's road
    // is drawn over it (`_renderGraveOverDoors`).
    if (_isGlassPlanet) return;
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
      // A HILL, lit from above: dark at its foot, turf, a lit crown — and
      // ribs of turf running down its flanks so it has a shape, not a fill.
      canvas.drawOval(mound, Paint()..color = const Color(0xFF111B22));
      canvas.drawOval(
        mound
            .deflate(mound.height * 0.08)
            .shift(Offset(0, -mound.height * .06)),
        Paint()..color = _graveMoss,
      );
      canvas.drawOval(
        mound
            .deflate(mound.height * 0.24)
            .shift(Offset(0, -mound.height * .16)),
        Paint()..color = Color.lerp(_graveMoss, const Color(0xFF4F8284), 0.45)!,
      );
      for (var i = 0; i < 9; i++) {
        final a = pi + (i + 0.5) / 9 * pi;
        canvas.drawLine(
          c +
              Offset(
                cos(a) * mound.width * 0.18,
                sin(a) * mound.height * 0.12 - mound.height * .16,
              ),
          c + Offset(cos(a) * mound.width * 0.47, sin(a) * mound.height * 0.44),
          Paint()
            ..strokeWidth = 1.4
            ..color = const Color(0xFF0A1218).withValues(alpha: 0.5),
        );
      }
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
              alpha: 0.5 + 0.4 * (sin(a) * 0.5 + 0.5),
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
    // THE COLD BARROW: the same hill as a held breath of light — filled,
    // brightest at its crown, gone at its foot. (It was a doubled hairline
    // oval, which read as a selection ring.)
    canvas.drawOval(
      mound,
      Paint()
        ..shader = ui.Gradient.radial(
          mound.center.translate(0, -mound.height * 0.12),
          mound.width * 0.5,
          [
            _graveCold.withValues(alpha: 0.20),
            _graveCold.withValues(alpha: 0.08),
            _graveCold.withValues(alpha: 0.0),
          ],
          const [0.0, 0.6, 1.0],
        ),
    );
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
    _renderUndugGraveBody(canvas, at, ghost);
    // STUFF OF DREAMS, kept: the blank stone becomes a window, in either
    // world, once the maxim is found (planet_dungeon_game_spirit_art.dart).
    if (_dreamShown > 0) _drawDreamWindow(canvas, Offset(at.dx, at.dy - 26));
  }

  void _renderUndugGraveBody(Canvas canvas, Offset at, bool ghost) {
    final cut = Rect.fromCenter(center: at, width: 86, height: 40);
    if (!ghost) {
      // Set out and abandoned: a rectangle of turf cut and lifted, lying a
      // shade darker than the field, with its lip catching the light.
      final rr = RRect.fromRectAndRadius(cut, const Radius.circular(4));
      canvas.drawRRect(
        rr.shift(const Offset(0, -2)),
        Paint()..color = _graveTurf.withValues(alpha: 0.45),
      );
      canvas.drawRRect(rr, Paint()..color = _graveCut.withValues(alpha: 0.42));
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
        Paint()..color = const Color(0xFF050A12).withValues(alpha: 0.92),
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
    // A BAND of cold light, not a hairline: wide and faint, fading off both
    // of its ends, with the twelve points of the ring as studs and the
    // bearing it is struck from as the one bright one.
    final rect = Rect.fromCircle(center: c, radius: radius);
    canvas.drawArc(
      rect,
      start,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.sweep(
          c,
          [
            _graveCold.withValues(alpha: 0.0),
            _graveCold.withValues(alpha: 0.34),
            _graveCold.withValues(alpha: 0.34),
            _graveCold.withValues(alpha: 0.0),
          ],
          const [0.0, 0.12, 0.88, 1.0],
          TileMode.clamp,
          start,
          start + pi,
        ),
    );
    for (var i = 0; i < 12; i++) {
      final a = (i / 12.0) * pi * 2;
      final at = c + Offset(cos(a), sin(a)) * radius;
      final mark = i == kGraveFieldBearing;
      canvas.drawCircle(
        at,
        mark ? 5.5 : 2.2,
        Paint()..color = _graveCold.withValues(alpha: mark ? 0.95 : 0.35),
      );
    }
  }

  void _renderGraveFixtures(Canvas canvas, DungeonRoom room, bool ghost) {
    final g = room.grave;
    if (g == null) return;
    final ink = ghost ? _graveCold : _graveStone;
    if (g.undugGrave != null) _renderUndugGrave(canvas, g.undugGrave!, ghost);

    // THE LYCH-STONE: a stone bier long enough to lie on, with a figure of
    // wraith glass laid in its top — frosted to a warm eye, lit in the cold.
    // THE BIER, on the lych gate's trestles (the room's one wall): a
    // shrouded body until the Cold Road opens and the procession takes it,
    // then the trestles, empty.
    if (g.vigil != null) {
      final road = hasStar(g.vigil!.roadStarIndex);
      for (final w in room.walls) {
        _drawBier(canvas, w, ghost, carried: road);
      }
    }
    final stone = g.lychStone ?? g.wraithStone;
    if (stone != null) _drawLychStone(canvas, stone, ghost);

    // THE SIGIL STONE: the living half only, and only to a warm eye.
    final sig = g.sigilStone;
    if (sig != null) {
      // A rondel of twelve panes; the living half lit ember to a warm eye,
      // the whole ring gold once the mark has taken (§7.11).
      _drawSigilGlass(
        canvas,
        sig,
        kBarrowSigilHalf[room.id] ?? 0,
        warm: !ghost,
        stamped: _field.sigilStamped || _sigilWon,
      );
    }

    // THE DEAD, where they are still dying.
    for (final r in graveRevenantsIn(room.id)) {
      _drawRevenant(canvas, room, r, ghost);
    }

    // THE DROWNED BRINK: black water with the cold moving on it, or ice.
    final brink = g.drownedBrink;
    if (brink != null) _drawDrownedBrink(canvas, brink);
    final mouth = g.graveMouth;
    if (mouth != null && !entryDoorRevealed) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: mouth, width: 150, height: 40),
        const Radius.circular(10),
      );
      canvas.drawRRect(r, Paint()..color = _graveVoid.withValues(alpha: 0.92));
      final sheen = sin(wake.clock * 0.7) * 4;
      canvas.drawOval(
        Rect.fromCenter(
          center: mouth.translate(sheen, -4),
          width: 90,
          height: 5,
        ),
        Paint()..color = _graveCold.withValues(alpha: 0.18),
      );
    }
    final lamp = g.graveLamp;
    if (lamp != null) _drawGraveLamp(canvas, lamp, ink);
  }

  bool get _sigilWon {
    final spec = _graveVigil;
    return spec != null && hasStar(spec.sigilStarIndex);
  }

  void _drawBier(Canvas canvas, Rect w, bool ghost, {required bool carried}) {
    final wood = ghost
        ? _graveCold.withValues(alpha: 0.5)
        : const Color(0xFF26222E);
    // Two trestles and the board across them.
    for (final x in [w.left + 18, w.right - 18]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, w.center.dy + 6),
          width: 8,
          height: w.height + 8,
        ),
        Paint()..color = wood,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(w.deflate(4), const Radius.circular(3)),
      Paint()..color = wood,
    );
    if (carried) return;
    // The shroud, and the shape under it: a body with its head toward the
    // gate, the cloth falling in two folds, lit by the moon on its top.
    final shroud = ghost ? _graveCold : const Color(0xFFA8B2C2);
    final a = ghost ? 0.5 : 0.92;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(w.left + 26, w.top - 3, w.right - 14, w.bottom - 1),
      Radius.circular(w.height / 2),
    );
    final head = Rect.fromCircle(
      center: Offset(w.left + 22, w.center.dy - 2),
      radius: w.height * 0.42,
    );
    final paint = Paint()
      ..shader = ui.Gradient.linear(w.topCenter, w.bottomCenter, [
        shroud.withValues(alpha: a),
        Color.lerp(shroud, Colors.black, 0.45)!.withValues(alpha: a),
      ]);
    canvas.drawRRect(body, paint);
    canvas.drawOval(head, paint);
    for (final t in const [0.38, 0.68]) {
      final x = body.left + body.width * t;
      canvas.drawLine(
        Offset(x, body.top + 4),
        Offset(x + 6, body.bottom - 3),
        Paint()
          ..strokeWidth = 1.4
          ..color = Colors.black.withValues(alpha: 0.18),
      );
    }
  }

  void _drawLychStone(Canvas canvas, Offset at, bool ghost) {
    final top = Rect.fromCenter(center: at, width: 96, height: 30);
    paintCarvedBlock(canvas, top, 8, _kWraithGlass, radius: 4);
    // The figure lying in it: a body and a head, leaded.
    final figure = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at.translate(6, 0), width: 56, height: 14),
          const Radius.circular(7),
        ),
      )
      ..addOval(Rect.fromCircle(center: at.translate(-30, 0), radius: 7));
    paintPane(
      canvas,
      figure,
      ghost
          ? _kWraithGlass.live.withValues(
              alpha: 0.75 + 0.15 * sin(wake.clock * 1.1),
            )
          : _kWraithGlass.frostAt(1).withValues(alpha: 0.55),
      _kWraithGlass,
      lead: 1.6,
    );
  }

  /// ONE OF THE DEAD, and the crossing it is holding.
  ///
  /// The 2026-09-25 review: telling is the planet's one IRREVERSIBLE act,
  /// and nothing said which crossing a revenant decides — you found out by
  /// committing it. Now, in the cold, a ribbon of cold light runs from each
  /// restless dead one to the doorway it is holding up; standing at it with
  /// a Spirit hand, the ribbon brightens and the doorway shows, ghosted, the
  /// lintel that will fall across it for the dead when the telling is done.
  /// (Its living half — the stone that comes off — is the fallen slab the
  /// living already see across that doorway.)
  void _drawRevenant(Canvas canvas, DungeonRoom room, Revenant r, bool ghost) {
    final ink = ghost ? _graveCold : _graveStone;
    if (_field.isRested(r.id)) {
      // At rest: a small stone laid flat where they were.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: r.seat.translate(0, 10),
            width: 26,
            height: 12,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = ink.withValues(alpha: 0.45),
      );
      return;
    }
    if (!ghost) {
      // Only the dead SEE the dead. A warm eye gets a cold patch and no more.
      canvas.drawCircle(
        r.seat,
        26,
        Paint()
          ..shader = ui.Gradient.radial(r.seat, 26, [
            _graveCold.withValues(alpha: 0.16),
            _graveCold.withValues(alpha: 0.0),
          ]),
      );
      return;
    }
    final a = active;
    final hearing =
        a != null &&
        a.member.element == 'Spirit' &&
        (a.position - r.seat).distance <= _kGraveReach;
    DungeonDoor? held;
    for (final d in room.doors) {
      if (_graveCrossingFor(room, d)?.id == r.crossingId) held = d;
    }
    if (held != null) _drawTether(canvas, r.seat, held.rect.center, hearing);
    final bob = sin(wake.clock * 1.6 + r.seat.dx) * 3.0;
    final at = r.seat + Offset(0, bob - 6);
    final sway = sin(wake.clock * 1.1 + r.seat.dy) * 4;
    // A hooded shape, drawn as MATERIAL: filled, brightest at the hood,
    // thinning to a wisp where its feet would be.
    final body = Path()
      ..moveTo(at.dx, at.dy - 26)
      ..quadraticBezierTo(at.dx + 11, at.dy - 25, at.dx + 12, at.dy - 8)
      ..quadraticBezierTo(at.dx + 13, at.dy + 8, at.dx + 5 + sway, at.dy + 24)
      ..quadraticBezierTo(
        at.dx + sway * 0.5,
        at.dy + 18,
        at.dx - 5 + sway,
        at.dy + 24,
      )
      ..quadraticBezierTo(at.dx - 13, at.dy + 8, at.dx - 12, at.dy - 8)
      ..quadraticBezierTo(at.dx - 11, at.dy - 25, at.dx, at.dy - 26)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader =
            ui.Gradient.linear(at.translate(0, -26), at.translate(0, 24), [
              _graveCold.withValues(alpha: hearing ? 0.9 : 0.7),
              _graveCold.withValues(alpha: 0.0),
            ]),
    );
    // The face in the hood: nothing.
    canvas.drawOval(
      Rect.fromCenter(center: at.translate(0, -15), width: 10, height: 12),
      Paint()..color = _graveVoid.withValues(alpha: 0.85),
    );
  }

  /// A ribbon of cold light, filled and tapered, from [from] to [to], with a
  /// slow brighter swell running along it toward the doorway.
  void _drawTether(Canvas canvas, Offset from, Offset to, bool bright) {
    final v = to - from;
    final n = Offset(-v.dy, v.dx) / max(1.0, v.distance);
    final ctrl = (from + to) / 2 + n * v.distance * 0.18;
    Offset at(double t) =>
        from * ((1 - t) * (1 - t)) + ctrl * (2 * t * (1 - t)) + to * (t * t);
    const steps = 18;
    final left = <Offset>[], right = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final w = 4.5 * (1 - t) + 1.2;
      final p = at(t);
      final q = at(min(1.0, t + 0.02));
      final dir = q - p;
      final nn = Offset(-dir.dy, dir.dx) / max(0.001, dir.distance);
      left.add(p + nn * w);
      right.add(p - nn * w);
    }
    canvas.drawPath(
      Path()..addPolygon([...left, ...right.reversed], true),
      Paint()..color = _graveCold.withValues(alpha: bright ? 0.40 : 0.16),
    );
    final swell = (wake.clock * 0.35) % 1.0;
    canvas.drawCircle(
      at(swell),
      bright ? 6 : 4,
      Paint()
        ..shader = ui.Gradient.radial(at(swell), bright ? 6 : 4, [
          _graveCold.withValues(alpha: bright ? 0.8 : 0.45),
          _graveCold.withValues(alpha: 0.0),
        ]),
    );
  }

  /// A slab of stone lying across a doorway — a road the world has shut
  /// for this body (the fallen stone the living see, the lintel that falls
  /// for the dead). [ghosted] draws it as the preview of one still to fall.
  void _drawFallenLintel(
    Canvas canvas,
    Rect door, {
    required bool cold,
    bool ghosted = false,
  }) {
    final c = door.center;
    final along = door.width > door.height;
    final len = (along ? door.width : door.height) * 0.9;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate((along ? 0.0 : pi / 2) + 0.28);
    final slab = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: len, height: 16),
      const Radius.circular(3),
    );
    final breathe = ghosted ? 0.35 + 0.15 * sin(wake.clock * 3) : 1.0;
    final base = cold ? _graveCold : _graveStone;
    canvas.drawRRect(
      slab.shift(const Offset(0, 5)),
      Paint()..color = Colors.black.withValues(alpha: 0.4 * breathe),
    );
    canvas.drawRRect(
      slab,
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, -8), const Offset(0, 8), [
          Color.lerp(
            base,
            Colors.white,
            0.25,
          )!.withValues(alpha: 0.95 * breathe),
          Color.lerp(
            base,
            Colors.black,
            0.35,
          )!.withValues(alpha: 0.95 * breathe),
        ]),
    );
    canvas.restore();
  }

  void _drawDrownedBrink(Canvas canvas, Offset at) {
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: 130, height: 26),
      const Radius.circular(12),
    );
    if (_field.cutFrozen) {
      // Ice: pale plates with dark seams between them and one glint.
      canvas.drawRRect(
        r,
        Paint()..color = const Color(0xFF9EC6D4).withValues(alpha: 0.6),
      );
      for (var k = 0; k < 3; k++) {
        final x = at.dx - 36 + k * 36.0;
        canvas.drawLine(
          Offset(x + 6, at.dy - 12),
          Offset(x - 4, at.dy + 12),
          Paint()
            ..strokeWidth = 1.4
            ..color = const Color(0xFF2E4A55).withValues(alpha: 0.6),
        );
      }
      canvas.drawOval(
        Rect.fromCenter(center: at.translate(-28, -5), width: 22, height: 4),
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
      return;
    }
    canvas.drawRRect(
      r,
      Paint()..color = const Color(0xFF040810).withValues(alpha: 0.9),
    );
    for (var k = 0; k < 3; k++) {
      final ph = (wake.clock * 0.25 + k / 3) % 1.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: at.translate(-40 + 80 * ph, (k - 1) * 5.0),
          width: 28,
          height: 3,
        ),
        Paint()..color = _graveCold.withValues(alpha: 0.22 * sin(ph * pi)),
      );
    }
  }

  void _drawGraveLamp(Canvas canvas, Offset at, Color ink) {
    final lit = (conduitEnergy['B'] ?? 0) > 0;
    // A post, a lantern on it, and a flame that moves when it is lit.
    canvas.drawRect(
      Rect.fromCenter(center: at.translate(0, 16), width: 4, height: 28),
      Paint()..color = const Color(0xFF1E1C26),
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: 18, height: 22),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = lit ? const Color(0xFF5A4424) : ink.withValues(alpha: 0.45),
    );
    paintPane(
      canvas,
      Path()..addRRect(body.deflate(3)),
      lit ? _graveEmber : _kWraithGlass.smoke,
      _kWraithGlass,
      lead: 1.4,
    );
    if (lit) {
      final f = 0.85 + 0.15 * sin(wake.clock * 9);
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy - 8 * f)
          ..quadraticBezierTo(at.dx + 4, at.dy - 1, at.dx, at.dy + 5)
          ..quadraticBezierTo(at.dx - 4, at.dy - 1, at.dx, at.dy - 8 * f)
          ..close(),
        Paint()..color = const Color(0xFFFFF0C8),
      );
      canvas.drawCircle(
        at,
        40,
        Paint()
          ..shader = ui.Gradient.radial(at, 40, [
            _graveEmber.withValues(alpha: 0.22),
            _graveEmber.withValues(alpha: 0.0),
          ]),
      );
    }
  }
}
