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
//    unmarked grave, with all three bodies standing in it.
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

  void reset() {
    field.reset();
    clock = 0;
    reink = 0;
    wraithWorld = GraveWorld.ghost;
    wraithCross = 0;
    bitLastFrame = false;
  }
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
            ? 'Wraithord steps into your world — it is solid, and so are you'
            : 'Wraithord steps out of your world — nothing you do reaches it',
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
    if (x.cut == GraveCut.livingOnly) return 'Salted — the dead do not cross';
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
        _tryHollowMark(a) ||
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
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist it
    _setHint('The arch drains — and a field of barrows behind it');
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
    wake.reink = _kGraveReinkSeconds;
    _clearHints();
    _setHint(
      f.isGhost
          ? 'You lie down, and get up colder — the grave has more roads than '
                'the field does'
          : 'You are called back warm — and half of what you were walking on '
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
      _clearHints();
      _setHint(
        '${r.name} finishes dying — and lets go of the arch it was holding',
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
      _setBlockedHint('The mark slides off — the halves do not close here');
      onChanged();
      return true;
    }
    f.sigilStamped = true;
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
        'The lamp will not take — it answers only a bearer of the '
        '${layout.starName(0)} and ${layout.starName(1)}',
      );
      return true;
    }
    conduitEnergy['B'] = double.infinity;
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
  /// the Lost Maxim's cousin verb — see [_tryHollowMark].
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

  /// THE HOLLOW GRAVE'S MARK — the Lost Maxim (§6 easter eggs #14). The one
  /// grave in Requia with no name-slot cut in it is the one you can put your
  /// own in. All three bodies, in it, as the dead. Wordless: nothing on the
  /// planet hints at it.
  bool _tryHollowMark(DungeonCreature a) {
    if (currentRoom.vaultCache == null) return false;
    if (discoveredClouds.contains(kSpiritStuffOfDreamsEgg)) return false;
    if (!_field.isGhost) return false;
    final live = creatures.where((c) => c.alive).toList();
    if (live.length < 3) return false;
    for (final c in live) {
      if (!currentRoom.bounds.contains(c.position)) return false;
    }
    _discoverCloud(kSpiritStuffOfDreamsEgg);
    _setHint(kSpiritStuffOfDreamsMaxim, 7.0);
    _spawnAlchemyBurst(
      a.position,
      producedElement: 'Spirit',
      reagentElements: const ['Water', 'Crystal'],
      particleCount: 42,
      intensity: 1.5,
    );
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
    if (room.guardian != null) {
      _setInsightHint(switch (tier) {
        0 => 'It is never quite in the room with you',
        1 => 'It is solid in one world at a time, and it changes on a count',
        _ => 'Nothing lands out of phase, either way — match the world it is '
            'standing in, and strike in that one. The stone behind you is '
            'the only weapon in here',
      });
      return;
    }
    if (room.grave?.graveLamp != null) {
      _setInsightHint(switch (tier) {
        0 => 'Two things, and the walk wants both',
        1 => 'One is a stone with no name on it; the other is an unlit lamp',
        _ => 'Only a second sight reads a nameless stone; the lamp answers any '
            'Crystal, once both stars are yours',
      });
      return;
    }
    if (room.vaultCache != null) {
      _setInsightHint(switch (tier) {
        0 => 'Nobody was ever put in here',
        1 => 'Every other grave in the field carries a name-slot. This one '
            'does not',
        _ => 'An empty slot takes whatever mark is set in it, and there are '
            'three of you standing in it',
      });
      return;
    }
    final restless = graveRevenantsIn(room.id)
        .where((r) => !f.isRested(r.id))
        .toList();
    if (restless.isNotEmpty) {
      final r = restless.first;
      _setInsightHint(switch (tier) {
        0 => r.restlessLook,
        1 => '${r.name} is holding up the arch that fell on it — and the '
            'stone that did it is still lying across the warm road',
        _ => 'Hear ${r.name} out and it lets go: ${graveCrossingById(r.crossingId)!.look} '
            'opens to the living for good, and shuts to the dead for good. '
            'It does not come back',
      });
      return;
    }
    if (room.grave?.sigilStone != null && !f.sigilStamped) {
      _setInsightHint(switch (tier) {
        0 => 'Half a ring, and half a ring is nothing',
        1 => 'The dead carry the other half — one great arc over the whole '
            'field, on a bearing of its own. The two must close the circle',
        _ => 'The arc runs on $kGraveFieldBearing; this floor runs on '
            '${kBarrowSigilHalf[room.id] ?? 0}, and only a barrow whose floor '
            'makes twelve of it will take the mark — and only from a warm hand',
      });
      return;
    }
    // Anywhere in the field, insight reads the RULE — which is the planet.
    _setInsightHint(switch (tier) {
      0 => 'There are two of this field, and you are only ever in one',
      1 => 'Every road here belongs to the living or to the dead, and never '
          'to both. The stones pass you between them',
      _ => 'Six of the roads have not decided yet, and the dead standing on '
          'them are the decision: finish one and it becomes the living\'s '
          'forever. Nothing here is ever lost — but the mere is worth having '
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

    canvas.drawRect(
      room.bounds,
      Paint()..color = ghost ? _graveVoid : _graveSod,
    );

    _renderGraveCrossings(canvas, room, ghost, t);
    if (room.grave?.barrow == true) _renderBarrowMound(canvas, room, ghost);
    _renderGraveFixtures(canvas, room, ghost);
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
          Paint()..color = (ghost ? _graveCold : _graveEmber).withValues(
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
      canvas.drawOval(mound, Paint()..color = _graveMoss);
      canvas.drawOval(
        mound.deflate(9),
        Paint()..color = _graveStone.withValues(alpha: 0.22),
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
          ..color = _graveCold.withValues(alpha: i == kGraveFieldBearing
              ? 0.9
              : 0.28),
      );
    }
  }

  void _renderGraveFixtures(Canvas canvas, DungeonRoom room, bool ghost) {
    final g = room.grave;
    if (g == null) return;
    final ink = ghost ? _graveCold : _graveStone;

    // THE LYCH-STONE: a low kerbed slab, long enough to lie on.
    final stone = g.lychStone ?? g.wraithStone;
    if (stone != null) {
      final r = Rect.fromCenter(center: stone, width: 96, height: 34);
      canvas.drawRect(r, Paint()..color = ink.withValues(alpha: 0.8));
      canvas.drawRect(
        r.deflate(5),
        Paint()..color = (ghost ? _graveVoid : _graveSod).withValues(
          alpha: 0.6,
        ),
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
      canvas.drawArc(
        Rect.fromCircle(center: sig, radius: 26),
        a,
        pi,
        false,
        p,
      );
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
      canvas.drawCircle(at, 22, p..color = _graveCold.withValues(
        alpha: alpha * 0.45,
      ));
    }

    // THE DROWNED BRINK, and the grave mouth, and the lamp.
    final brink = g.drownedBrink;
    if (brink != null) {
      final r = Rect.fromCenter(center: brink, width: 130, height: 26);
      canvas.drawRect(
        r,
        Paint()..color = _field.cutFrozen
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
        Paint()..color = lit
            ? _graveEmber
            : ink.withValues(alpha: 0.55),
      );
    }
  }
}
